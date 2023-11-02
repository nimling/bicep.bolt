using namespace System.Collections.Generic
using namespace System.IO
class envVariable {
    [string]$type
    [string]$description
    [string]$source
    envVariable() {}
    envVariable([psobject]$object, [string]$source) {
        $this.description = $object.description
        $this.source = $source

        $this.validate()
    }

    [object]getValue() {
        throw "This is the basic env variable class. it should not be used directly"
    }

    validate() {
        throw "This is the basic env variable class. it should not be used directly"
    }

    # [string]toString() {
    #     return "$($this.type):$($this.description)"
    # }
}

class envVariable_keyvault:envVariable {
    [string]$type = "keyvault"
    [string]$description
    [string]$secret
    [string]$vault
    [string]$version
    [string]$source
    envVariable_keyvault() {}
    envVariable_keyvault([psobject]$object, [string]$source) {
        $this.description = $object.description
        $this.source = $source
        $this.secret = $object.secret
        $this.vault = $object.vault
        $this.version = $object.version
        $this.validate()
    }

    [hashtable]getValue() {
        $vault_error = $null
        $sec_error = $null
        Write-BaduVerb "Getting secret $($this.secret) from keyvault $($this.vault)"
        $azVault = Get-AzKeyVault -VaultName $this.vault -ErrorAction SilentlyContinue -ErrorVariable vault_error
        if (!$azVault -or $vault_error) {
            throw "Keyvault '$($this.vault)' not found: $vault_error"
        }

        if ($this.version) {
            $azSecret = Get-AzKeyVaultSecret -VaultName $this.vault -Name $this.secret -ErrorAction SilentlyContinue -ErrorVariable sec_error
        } else {
            $azSecret = Get-AzKeyVaultSecret -VaultName $this.vault -Name $this.secret -ErrorAction SilentlyContinue -ErrorVariable sec_error
        }
        
        if (!$azSecret -or $sec_error) {
            throw "Secret '$($this.secret)' not found in keyvault '$($this.vault)': $sec_error"
        }

        return @{
            reference = @{
                keyVault   = @{
                    id = $azVault.ResourceId
                }
                secretName = $this.secret
            }
        }
    }

    validate() {
        if (!$this.secret) {
            throw "secret is required"
        }
        if (!$this.vault) {
            throw "vault is required"
        }
    }
}

class envVariable_static:envVariable {
    [string]$type = "static"
    [string]$description
    $value
    [string]$source
    envVariable_static() {}
    envVariable_static([psobject]$object, [string]$source) {
        $this.description = $object.description
        $this.value = $object.value
        $this.source = $source
        $this.validate()
    }

    [string]getValue() {
        return $this.value
    }

    validate() {
        if (!$this.value) {
            throw "value is required"
        }
    }
}

class envVariable_identity:envVariable{
    [string]$type = "identity"
    [string]$description
    [string]$source
    [string]$value
    envVariable_identity() {}
    envVariable_identity([psobject]$object, [string]$source) {
        $this.description = $object.description
        $this.source = $source
        $this.value = $object.value
        $this.validate()
    }

    [string]getValue() {
        return $this.value
    }

    validate() {
        if (!$this.value) {
            throw "value is required"
        }
    }
}


class deployEnvironment {
    [string]$name = $null
    [bool]$isScoped = $false
    [Dictionary[string, envVariable]] $variables = [Dictionary[string, envVariable]]::new() 
    deployEnvironment() {}
    deployEnvironment([psobject]$Object) {
        $this.name = $Object.name
        $this.isScoped = $Object.isScoped

        #if environment has defined attribute variables, add them to the environment
        if ($Object.variables) {
            #for each variable in the environment, create a new environment variable object
            foreach ($variable in $Object.variables.psobject.properties) {
                try {
                    $var = $null
                    switch ($variable.value.type) {
                        "static" {
                            $var = [envVariable_static]::new($variable.value, $this.name)
                        }
                        "keyvault" {
                            $var = [envVariable_keyvault]::new($variable.value, $this.name)
                        }
                        'identity' {
                            $var = [envVariable_identity]::new($variable.value, $this.name)
                        }
                        default {
                            throw "variable type '$($variable.value.type)' is not supported"
                        }
                    }
                    $this.variables.Add($variable.Name, $var)
                } catch {
                    throw "environment '$($this.name)' has invalid variable '$($variable.Name)': $_"
                }
            }
        }
    }

    validate() {
        if (!$this.name) {
            throw "name is required"
        }
        if ($null -eq $this.isScoped) {
            throw "$($this.name) -> isScoped is required"
        }
        if ($this.variables) {
            foreach ($variable in $this.variables.getEnumerator()) {
                try{
                    $variable.value.validate()
                }
                catch{
                    throw "environment '$($this.name)' has invalid variable '$($variable.Name)': $_"
                }
            }
        }
    }
}

class deployWorkflow {
    [bool]$deployoutput_enabled = $false
    [string]$deployoutput_style = "json"
    [string]$scope = "subscription" #not used yet, and not handled, but will be used to scope the deployment in the future
    deployWorkflow() {}
    deployWorkflow([psobject]$object) {
        if ($object.deployoutput.enabled) {
            $this.deployoutput_enabled = [bool]$object.deployoutput.enabled
            $this.deployoutput_style = $object.deployoutput.style
        }
    }
}

class deployConfigDry {
    [string]$style = "<>"
    [bool]$throwOnUnhandledParameter = $true
    deployConfigDry() {}
    deployConfigDry([psobject]$object) {
        $this.style = $object.style
        $this.throwOnUnhandledParameter = $object.throwOnUnhandledParameter
    }
    [bool]isTagValue($value) {
        return $value -is [string] -and $value[0] -eq $this.style[0] -and $value[-1] -eq $this.style[-1]
    }

    [string]cleanTagValue([string]$value) {
        if (!$this.isTagValue($value)) {
            return $value
        }
        return $value.substring(1, $value.length - 2)
    }
}

class deployConfigBicep {
    [string]$minimumVersion = '0.4.0'
    deployConfigBicep() { 
        $this.init() 
        $this.validate()
    }
    deployConfigBicep([psobject]$object) {
        $this.minimumVersion = $object.minimumVersion
        $this.init()

        $this.validate()
    }

    init() {
        if ($this.minimumVersion -eq 'latest') {
            $this.minimumVersion = $this.getLatestVersion()
            Write-BaduVerb "the 'latest' version of bicep is set to '$($this.minimumVersion)"
        }
    }

    validate() {
        #Check bicep precence
        if (!(Get-command bicep -ea SilentlyContinue)) {
            throw "Bicep is not installed. it needs to be installed (at least version $($this.minimumVersion))"
        }

        #check bicep version against required config
        $(bicep --version) -match "(?'ver'\d+\.\d+\.\d+)" | Out-Null
        if (([version]$matches.ver) -lt ([version]$this.minimumVersion)) {
            throw "the installed bicep version ($($matches.ver)) is less than the required version ($($this.minimumVersion)). please update"
        }
    }

    [string]getLatestVersion() {
        #get response and read the return url to get the latest version
        #avoid using the api as it rate limited per ip
        $url = "https://github.com/Azure/bicep/releases/latest"
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing
        $returnUrl = $response.BaseResponse.RequestMessage.RequestUri
        $version = $returnUrl.Segments[-1]
        return $version.Substring(1)
    }
}

class deployConfigDev {
    [bool]$ignoreInstance = $false
    [bool]$enabled = $false
    deployConfigDev() {
        $this.init()
    }
    deployConfigDev([psobject]$object) {
        $this.ignoreInstance = $object.ignoreInstance
        $this.enabled = $object.enabled
        $this.init()
    }

    init() {
        Set-BaduLogContext -Tag 'devconfig init' -IsSubFunction
        # Write-BaduInfo (Get-PSCallStack|select -First 1|ConvertTo-Json -Depth 1)
        # Write-BaduInfo (Get-PSCallStack|select -First 1).GetHashCode()

        if ($this.enabled) {
            Write-BaduWarning "DEV MODE ENABLED! this setting should only for deployment of BADU"
            Write-BaduVerb "**dev settings**"
            $MaxLength = ($this.psobject.properties.name | Measure-Object -Maximum length).Maximum
            Foreach($Prop in $this.psobject.properties) {
                $NameWithPad = $Prop.Name.padright($MaxLength, " ")
                Write-BaduVerb "$NameWithPad : $($Prop.Value)"
            }
            # Write-BaduVerb ""
        }
    }
}

class deployConfig {
    #region properties
    [string]$tenant
    [string]$deployLocation
    [string]$workingPath
    [List[deployEnvironment]] $environments = [List[deployEnvironment]]::new()
    [deployConfigDry]$dry = [deployConfigDry]::new()
    [deployConfigBicep]$bicep = [deployConfigBicep]::new()
    [deployConfigDev]$dev = [deployConfigDev]::new()
    [deployWorkflow]$workflow = [deployWorkflow]::new()

    #used to handle singleton-ish? its loaded into global and can only be retreived if the root instance id is the same as the one that is trying to get it (2 runs of the same script will have different instance ids)
    [int]$InstanceId

    #proper guid tenant id
    hidden [string]$_tenantid = $null
    hidden [string]$_setTenant = $null
    hidden [List[string]]$environmentPresedence = [List[string]]::new()
    #endregion properties

    static [deployConfig]get() {
        #if deployconfig isnt set, throw
        if (!$global:deployConfig) {
            $Msg = "Failed to get the proper deployConfig. it is not initialized yet (file has not been loaded yet)"
            Write-BaduError $Msg
            throw $Msg
        }
    
        $CurrentInstance = (get-pscallstack)[-1].GetHashCode()
        #if the instance id is not the same as the current instance, throw. except if its a developer
        if ($global:deployConfig.InstanceId -ne $CurrentInstance -and !$global:deployConfig.dev.ignoreInstance -and $global:deployConfig.dev.enabled) {
            $Msg = "Failed to get the proper config. please make sure you have it instanced within the same callstack. If you are a developer, add dev.ignoreinstance = true to your deployconfig.json"
            Write-BaduError $Msg
            throw $Msg
        }

        return $global:deployConfig
    }

    deployConfig() {}

    deployConfig($Config, [string]$ActiveEnvironment) {
        # Write-BaduInfo (Get-PSCallStack|select -first 1|ConvertTo-Json -Depth 1)
        Set-BaduLogContext -Tag "config init"
        # Write-BaduVerb $config.gettype()
        if ($config -isnot [hashtable] -and $config -isnot [pscustomobject]) {
            $Msg = "parameter 'config' needs to be hashtable or pscustomobject (json converted to object)"
            Write-BaduError $Msg
            throw $Msg
        }

        if (!$config.tenant) {
            $Msg = "deployconig needs to have a 'tenant' property"
            Write-BaduError $Msg
            throw $Msg
        }

        $this.tenant = $Config.tenant
        $this.deployLocation = $Config.deployLocation
        #handle dev
        $this.dev = [deployConfigDev]::new($Config.dev)

        $this.InstanceId = (get-pscallstack)[-1].GetHashCode()

        #assign environments
        :loadenv foreach ($configEnv in $Config.environments) {
            $env = [deployEnvironment]::new($configEnv)
            #if its not the current environment and its scoped, skip it
            if ($env.name -ne $ActiveEnvironment -and $env.isScoped) {
                $EnvFeedback = "- env '$($env.name)'"
                if($env.isScoped){
                    $EnvFeedback = ($EnvFeedback + " (scoped)")
                }

                Write-BaduVerb $EnvFeedback
                continue :loadenv
            }

            if ($env.name -in $this.environments.name) {
                throw "environment '$($env.name)' is defined more than once"
            }

            $EnvFeedback = "+ env '$($env.name)'"
            if($env.isScoped){
                $EnvFeedback = ($EnvFeedback + " (scoped)")
            }
            Write-BaduVerb $EnvFeedback

            $this.environments.Add($env)
        }

        #handle active environments. i need to add scoped environments to the list first, 
        #becaue is want variables from scoped environments to be available first (in case of duplicates)
        $this.environments | sort-object isScoped -Descending | ForEach-Object {
            $this.environmentPresedence.Add($_.name)
        }

        #handle dry
        $this.dry = [deployConfigDry]::new($Config.dry)

        #handle bicep
        $this.bicep = [deployConfigBicep]::new($Config.bicep)

        #handle workflow
        if($Config.workflow)
        {
            $this.workflow = [deployWorkflow]::new($Config.workflow)
        }

        $this.validate()
    }

    hidden validate() {
        $this.bicep.validate()
        $this.environments|ForEach-Object {
            $_.validate()
        }

        $this.validateTenant()
        $this.validateDeployLocation()
    }

    hidden validateEnvironments() {
        if (!$this.environments) {
            throw "environments is required"
        }
        if ($this.environments.count -eq 0) {
            throw "environments must have at least one environment"
        }
        $this.environments | ForEach-Object {
            $_.validate()
        }
    }

    validateTenant() {
        if ([string]::IsNullOrEmpty($this.tenant)) {
            throw "tenant is required"
        }
        $url = "https://login.microsoftonline.com/$($this.tenant)/.well-known/openid-configuration"
        try {
            $response = Invoke-WebRequest -Uri $url -UseBasicParsing -Verbose:$false
            if ($response.StatusCode -ne 200) {
                throw
            }
            $TenantId = ($response.Content | ConvertFrom-Json).issuer | Split-Path -leaf
            Write-BaduVerb "tenant '$($this.tenant)' found in azure with id '$TenantId'"
            $this._tenantid = $TenantId
            $this._setTenant = $this.tenant
        } catch {
            throw "tenant '$($this.tenant)' could not be found in azure. please confirm that 'tenant' property is correct in deployConfig.json"
        }
    }

    #validate that the deploy location is valid. handled in json schema
    hidden validateDeployLocation() {
        if (!$this.deployLocation) {
            throw "deployLocation is required"
        }
    }

    [string] getTenantId() {
        $tenantIdSet = ![string]::IsNullOrEmpty($this._tenantid)
        $TenantIsDifferent = $this._setTenant -ne $this.tenant
        # Write-BaduVerb "tenantid set: $tenantIdSet, tenant is different: $TenantIsDifferent"
        if ($tenantIdSet -eq $false -or $TenantIsDifferent) {
            Write-BaduVerb "Validating tenant $($this.tenant)"
            $this.validateTenant()
        }
        
        return $this._tenantid
    }

    [deployEnvironment]getEnvironment([string]$Name) {
        $ret = $this.environments | Where-Object { $_.name -eq $Name } | Select-Object -first 1
        return $ret
    }
}