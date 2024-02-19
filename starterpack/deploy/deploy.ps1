#BUILD 0.3.101123
#region using
using namespace system.drawing
using namespace system.collections.generic
using namespace system.io
#endregion

[cmdletbinding(SupportsShouldProcess)]
param(
    [parameter(
        HelpMessage = "Only needed if you make a diff on the different environment"
    )]
    [string]$env,
    [parameter(
        HelpMessage = "Only start files with this name. supports wildcards"
    )]
    [string]$name,

    [parameter(
        HelpMessage = "
        this will set badu in a special state meant to get a quick overview of what will happen.
        list: will list all deployments that will be made
        dryrun: this is a mix of whatif and list, it will list what deployents it should have made and what parameters to use"
    )]
    [ValidateSet(
        "list",
        "dryRun",
        "default"
    )]
    [string[]]$action = "default"
)


#region BuildID
$buildId = "0.3.101123"
#endregion


#region class
#region config\Deployconfig.class.ps1
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
#endregion

#region config\Deployconfig.class.ps1
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
        Write-Verbose "Getting secret $($this.secret) from keyvault $($this.vault)"
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
#endregion

#region config\Deployconfig.class.ps1
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
#endregion

#region config\Deployconfig.class.ps1
class envVariable_identity:envVariable {
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
#endregion

#region config\Deployconfig.class.ps1
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
        if (!$this.isScoped) {
            throw "isScoped is required"
        }
    }

    # [string]ToString(){
    #     return $this|fl|out-string
    # }
}
#endregion

#region config\Deployconfig.class.ps1
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
#endregion

#region config\Deployconfig.class.ps1
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
#endregion

#region config\Deployconfig.class.ps1
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
            Write-Verbose "the 'latest' version of bicep is set to '$($this.minimumVersion)"
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

    # [string]ToString(){
    #     return ($this|Format-List|out-string)
    # }
}
#endregion

#region config\Deployconfig.class.ps1
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
        if ($this.enabled) {
            Write-Warning "DEV MODE ENABLED! this setting should only for deployment of BADU"
            Write-Verbose "**dev settings**"
            $MaxLength = ($this.psobject.properties.name | Measure-Object -Maximum length).Maximum
            $this.psobject.properties | ForEach-Object {
                $NameWithPad = $_.Name.padright($MaxLength, " ")
                Write-Verbose "$NameWithPad : $($_.Value)"
            }
            Write-Verbose ""
        }
    }
    # [string]toString(){
    #     return ($this|Format-List|out-string)
    # }
}
#endregion

#region config\Deployconfig.class.ps1
class deployConfig {
    [string]$tenant
    [string]$deployLocation
    [string]$workingPath
    [List[deployEnvironment]] $environments = [List[deployEnvironment]]::new()
    [deployConfigDry]$dry = [deployConfigDry]::new()
    [deployConfigBicep]$bicep = [deployConfigBicep]::new()
    [deployConfigDev]$dev = [deployConfigDev]::new()
    [deployWorkflow]$workflow = [deployWorkflow]::new()
    [int]$InstanceId 
    hidden [string]$_tenantid = $null
    hidden [string]$_setTenant = $null
    hidden [List[string]]$environmentPresedence = [List[string]]::new()

    static [deployConfig]get() {
        #if deployconfig isnt set, throw
        if (!$global:deployConfig) {
            throw "Failed to get the proper deployConfig. it is not initialized yet (file has not been loaded yet)"
        }
    
        $CurrentInstance = (get-pscallstack)[-1].GetHashCode()
        #if the instance id is not the same as the current instance, throw. except if its a developer
        if ($global:deployConfig.InstanceId -ne $CurrentInstance -and !$global:deployConfig.dev.ignoreInstance -and $global:deployConfig.dev.enabled) {
            throw "Failed to get the proper config. please make sure you have it instanced within the same callstack. If you are a developer, add dev.ignoreinstance = true to your deployconfig.json"
        }

        return $global:deployConfig
    }

    deployConfig() {}

    deployConfig($Config, [string]$ActiveEnvironment) {
        Write-Verbose $config.gettype()
        if ($config -isnot [hashtable] -and $config -isnot [pscustomobject]) {
            throw "parameter 'config' needs to be hashtable or pscustomobject (json converted to object)"
        }

        if (!$config.tenant) {
            throw "deployconig needs to have a 'tenant' property"
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
                Write-Verbose "- env '$($env.name)'"
                continue :loadenv
            }

            if ($env.name -in $this.environments.name) {
                throw "environment '$($env.name)' is defined more than once"
            }

            Write-Verbose "+ env '$($env.name)'"
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
        if ($Config.workflow) {
            $this.workflow = [deployWorkflow]::new($Config.workflow)
        }

        $this.validate()
    }

    hidden validate() {
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
            Write-verbose "tenant '$($this.tenant)' found in azure with id '$TenantId'"
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
        # Write-Verbose "tenantid set: $tenantIdSet, tenant is different: $TenantIsDifferent"
        if ($tenantIdSet -eq $false -or $TenantIsDifferent) {
            Write-Verbose "Validating tenant $($this.tenant)"
            $this.validateTenant()
        }
        
        return $this._tenantid
    }

    [deployEnvironment]getEnvironment([string]$Name) {
        $ret = $this.environments | Where-Object { $_.name -eq $Name } | Select-Object -first 1
        return $ret
    }
}
#endregion

#region Deployment\ignore\whatif\WhatifCollector.class.ps1
class whatifResultProperty {
    [string]$name
    [string]$parent
    $oldValue
    $newvalue
}
#endregion

#region Deployment\ignore\whatif\WhatifCollector.class.ps1
class WhatifResult {
    [string]$Name
    [string]$Path
    [string]$parent
    [string]$scope
    [string]$RelativeId
    [string]$changeType
    [string]$status
    [hashtable]$Properties
}
#endregion

#region Deployment\ignore\whatif\WhatifCollector.class.ps1
class WhatIfCollector {
    [list[WhatifResult]]$results = [list[WhatifResult]]::new()
    Add([WhatifResult]$Result) {
        $this.results.Add($Result)
    }
}
#endregion

#endregion

#region functions
#region Deployment\AzData\Get-DeploymentOperation.ps1
function Get-DeploymentOperation {
    [CmdletBinding()]
    param (
        [parameter(Mandatory)]
        [string]$id,

        [parameter(Mandatory)]
        [ValidateSet(
            "ResourceGroup",
            "Subscription"
        )]
        [string]$context
    )
    
    begin {}
    process {
        switch ($context) {
            "ResourceGroup" {
                #match subscription and resourcegroup
                $regex = "\w+\/(?'subid'[^\/]+)\/\w+\/(?'rg'[^\/]+)"
            }
            "Subscription" {
                #match subscription
                $regex = "\w+\/(?'subid'[^\/]+)"
            }
        }

        $match = $id -match "$regex\/providers\/Microsoft\.Resources\/deployments\/(?'name'.+)$"
        if (!$match) {
            throw "id '$id' is not a valid deployment id"
        }

        switch ($context) {
            "ResourceGroup" {
                return Get-AzResourceGroupDeploymentOperation -ResourceGroupName $matches.rg -DeploymentName $matches.name  # -id $id -ErrorAction SilentlyContinue
            }
            "Subscription" {
                return Get-AzDeploymentOperation -DeploymentName $matches.name -ErrorAction SilentlyContinue
            }
        }
    }
    end {}
}
#endregion

#region Deployment\ignore\whatif\Get-DeployWhatifResultProperties.ps1
function Get-DeployWhatifResultProperties {
    [CmdletBinding()]
    [outputtype([whatifResultProperty])]
    param (
        [parameter(ValueFromPipeline)]
        [pscustomobject]$properties,
        [string]$parent = ""
    )
    
    begin {
        
    }
    
    process {
        foreach ($item in $properties.psobject.properties) {
            if ($item -is [pscustomobject]) {
                $item | Get-DeployWhatifResultProperties
                $whatifProp = [whatifResultProperty]::new()
                $whatifProp.name = $item.Name
                $whatifProp.parent = $parent
                $whatifProp.newvalue = $item.value
            } else {
                $whatifProp = [whatifResultProperty]::new()
                $whatifProp.name = $item.Name
                $whatifProp.parent = $parent
                $whatifProp.newvalue = $item.value
                Write-output $whatifProp
            }
        }
    }
    
    end {
        
    }
}
#endregion

#region Deployment\ignore\whatif\Add-DeployWhatifresult.ps1
function Add-DeployWhatifresult {
    [CmdletBinding()]
    param (
        $inputObject,
        [string]$Name,
        [string]$Path,
        [ValidateSet(
            "ResourceGroup",
            "Subscription"
        )]
        [string]$Scope
    )
    
    begin {
        <#
        class WhatifResult{
            [string]$Name
            [string]$Path
            [string]$scope
            [string]$resourceId
            [string]$changeType
            [string]$status
        }
        #>
    }
    
    process {
        if ($inputObject -is [Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.Deployments.PSWhatIfOperationResult]) {
            [Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.Deployments.PSWhatIfOperationResult]$inputObject = $inputObject
            foreach ($change in $inputObject.Changes) {
                #its easier to deal with pscustomobject whan whatever the over enginered shitstack newtonsoft json is doing...
                $_change = $change | convertto-json | convertfrom-json

                $whatifobject = [WhatifResult]::new()
                $whatifobject.Name = $Name
                $whatifobject.path = $Path
                $whatifobject.scope = $Scope
                $whatifobject.RelativeId = $_change.RelativeResourceId
                $whatifobject.changeType = $_change.ChangeType
                $whatifobject.status = $inputObject.Status
                switch ($_change.ChangeType) {
                    "Create" {
                        foreach ($property in $change.after.psobject.properties) {
                            $whatifProp = [whatifResultProperty]::new()
                            $whatifProp.name = $property.Name
                            if ($value -is [pscustomobject]) {
                                
                            }
                            $whatifProp.newvalue = $property.value
                        }
                    }
                }
            }
            
            $global:whatifResult.add()
        }
    }
    
    end {
        
    }
}
#endregion

#region Deployment\ParameterHandling\Variables\Remove-VariableReferenceToken.ps1
function Remove-VariableReferenceToken {
    [CmdletBinding()]
    param (
        [string]$Value
    )
    
    if (Test-ValueIsVariableReference -value $Value) {
        $Value = $Value.Substring(1, $Value.Length - 2)
    }
    return $Value
}
#endregion

#region Env\Get-DeploymentFiles.ps1
function Get-DeploymentFile {
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo])]
    param (
        [parameter(Mandatory)]
        [string]$path
    )
    begin {}
    process {
        $items = Get-ChildItem -Path $path -file | Where-Object { $_.name -like "*.json*" -or $_.name -like "*.bicep" }
        :itemsearch foreach ($item in $items) {
            if ($item.name -like "*.bicep") {
                Write-Output $item
                continue :itemsearch
            }
            if ($item.name -like "*.json*") {
                $json = Get-Content -Path $item.FullName -Raw
                # Write-Verbose $item.FullName
                $jsonitem = $json | ConvertFrom-Json
                if ($jsonitem.'$schema' -like '*schema.management.azure.com*DeploymentTemplate*') {
                    Write-Output $item
                    continue :itemsearch
                }
            }
        }
    }
    end {
    }
}
#endregion

#region config\Get-DeployConfig.ps1
function Get-DeployConfig {
    [CmdletBinding()]
    [OutputType([deployconfig])]
    param ()
    
    if (!$global:deployConfig) {
        throw "Failed to get deployConfig. it is not initialized yet (New-DeployConfig is not called yet)"
    }

    $CurrentInstance = (get-pscallstack)[-1].GetHashCode()
    #if the instance id is not the same as the current instance, throw. except if its a developer
    if ($global:deployConfig.dev.ignoreInstance -eq $false -and $global:deployConfig.dev.enabled) {
        if ($global:deployConfig.InstanceId -ne $CurrentInstance) {
            throw "Failed to get the proper deployConfig. please make sure you have it instanced within the same callstack. If you are a developer, add dev.ignoreinstance = true to your deployconfig.json"
        }
    }

    return $global:deployConfig
}
#endregion

#region Helpers\Write-BaduHeader.ps1
function Write-BaduHeader {
    [CmdletBinding()]
    param (
        
    )
    
    $header = @'
oooooooooo.        .o.       oooooooooo.   ooooo     ooo 
`888'   `Y8b      .888.      `888'   `Y8b  `888'     `8' 
 888    .888     .8"888.      888      888  888       8  
 888oooo888     .8' `888.     888      888  888       8  
 888    `88b   .88ooo8888.    888      888  888       8  
 888    .88P  .8'     `888.   888     d88'  `88.    .8'  
o888bood8P'  o88o     o8888  o888bood8P'      `YbodP'    
---------------------------------------------------------
Bicep Arm Deployment Utility
The Utility that won't leave you dis-ARM-ed!
'@
    Write-host $header
}
#endregion

#region Helpers\Get-ParamType.ps1
function Get-ParamType {
    param(
        $value
    )
    #get correct name for each value type: object, array, string, int
    $type = $value.GetType().Name
    switch ($type) {
        "String" {
            $type = "string"
        }
        "Int32" {
            $type = "int"
        }
        "Object[]" {
            $type = "array"
        }
        "Object" {
            $type = "object"
        }
        "Hashtable" {
            $type = "object"
        }
        "Boolean" {
            $type = "bool"
        }
        default {
            $type = "string"
        }
    }
    return $type
}
#endregion

#region Deployment\ParameterHandling\Variables\Get-VariableReferenceInString.ps1
function Get-VariableReferenceInString {
    [CmdletBinding()]
    [OutputType([System.Text.RegularExpressions.Group])]
    param (
        [string]$String
    )
    
    begin {
        
    }
    
    process {
        $DryConfig = (Get-DeployConfig).dry
        $start = $DryConfig.style[0]
        $end = $DryConfig.style[1]

        #explanation (using {}): 
        #\$start = match the $start character, example {
        #[^\$end]* = match any character that is not $end, 0 or more times -> while the character is not }
        #\$end = match the $end character example }
        $regex = "\$start(?'var'[^\$start\$end]*)\$end"
        Write-Debug "Regex: $regex -> where string starts with '$start' and ends with '$end'. grab anything in between that is not '$start' or '$end'"
        $match = [regex]::matches($string, $regex)
        Write-verbose "Found $($match.count) matches on string '$string'"
        return $match.groups | Where-Object { $_.name -eq 'var' }
    }
    
    end {
        
    }
}
#endregion

#region Deployment\WhileDeploying\Show-DeploymentProgress.ps1
function Show-DeploymentProgress {
    [CmdletBinding()]
    param (
        [parameter(Mandatory)]
        [string]$Name,
        
        # [ValidateNotNullOrEmpty()]
        [parameter(Mandatory)]
        [string]$Folder,
        
        # [ValidateNotNullOrEmpty()]
        [parameter(Mandatory)]
        [ValidateSet(
            "ResourceGroup",
            "Subscription"
        )]
        [string]$Context,
        [Microsoft.Azure.Commands.Common.AzureLongRunningJob]$Job,
        [switch]$DontWait,
        [string]$tab = ""
    )
    begin {
        $global:DeployProgress = @{}
    }
    process {
        #generate deployment object. each context has a different way to get the deployment operations.
        #they are functionally the same, but different commands are used
        # $deployment = @{}
        Write-Verbose "Getting deploytarget for $context"
        switch ($context) {
            "ResourceGroup" {
                $DeployTarget = (Get-AzResourceGroup -Name $Folder).ResourceId
            }
            "Subscription" {
                $DeployTarget = "/subscriptions/" + (Get-AzContext).Subscription.Id
            }
            default {
                throw "Context '$_' not supported"
            }
        }

        $DeploymentId = "$($DeployTarget)/providers/Microsoft.Resources/deployments/$name"

        $DeployProgress.($DeploymentId) = @{
            id       = 0
            status   = "Waiting for $context deployment to start running in azure"
            Activity = "deployments/$name"
        }

        try {

            if (!$DontWait) {
                Write-Verbose "Waiting for deployment to start"
                Wait-ForDeploymentStart -DeploymentId $DeploymentId -Context $context -Job $job -Progress $DeployProgress.($DeploymentId)
            }

            #region check operations while deployments is running (asuming that deployment is not failed at)
            Write-Verbose "Deployment is starting.."
            do {
                $Deployment = Get-Deployment -id $DeploymentId -Context $context -Scope Current
                $SubDeployments = Get-Deployment -id $DeploymentId -Context $context -Scope Children
                foreach ($SubDeployment in $SubDeployments) {

                    #generate deployment id, as azure does not provide it
                    $SubDeployId = $DeployTarget + "/providers/Microsoft.Resources/deployments/" + $SubDeployment.DeploymentName

                    #append deployment to progress, if it is not already there
                    if (!$DeployProgress.ContainsKey($SubDeployId)) {
                        $DeployProgress.$SubDeployId = @{
                            id       = $DeployProgress.Count
                            status   = $SubDeployment.ProvisioningState
                            Activity = "deployments/$($SubDeployment.DeploymentName)"
                        }
                    }

                    $DeploymentProgress = $DeployProgress.$SubDeployId.clone()
                    #get operations for current deployment
                    $DeploymentOperations = Get-DeploymentOperation -id $SubDeployId -Context $context

                    #calculate percentage of operations that is done
                    # if ($DeploymentOperations.count -ne 0) {
                    #     $CountOperations = @($DeploymentOperations).count
                    #     $RunninOperationsCount = @($DeployOperation | Where-Object { $_.ProvisioningState -notin 'Succeeded', 'Failed' }).count
                    # }
                    
                    $DeploymentProgress.PercentComplete = 100
                    $DeploymentProgress.status = $SubDeployment.ProvisioningState
                    # Write-Verbose "status: $($SubDeployment.ProvisioningState)"
                    $UseColor = Get-StatusColor -provisioningState $SubDeployment.ProvisioningState
                    $DeploymentProgress.Activity = $usecolor + $($DeploymentProgress.Activity)

                    #handle deployment status
                    Write-Progress @DeploymentProgress

                    #region handle operations that is not a deployment (ie deployment of a actual resource, not a invokation of arm template)
                    #get operations that is not a deployment
                    $resourceDeployOperations = $DeploymentOperations | Where-Object { $_.TargetResource } | Where-Object { $_.TargetResource -notlike "*Microsoft.Resources/deployments*" }
                    #handle operations
                    foreach ($DeployOperation in $resourceDeployOperations) {
                        $ref = $DeployOperation.TargetResource.replace($DeployTarget, "")

                        #append operation to progress, if it is not already there
                        if (!$DeployProgress.ContainsKey($ref)) {
                            $DeployProgress.$ref = @{
                                id       = $DeployProgress.Count
                                status   = $DeployOperation.ProvisioningState
                                Activity = $DeployOperation.TargetResource.split("/")[-2..-1] -join "/"
                                ParentId = $DeploymentProgress.id
                            }
                        }

                        #The cololor jumps for some reason. trying to mitigate by only allowing color to be set once per status
                        if ($DeployProgress.$ref.status -ne $DeployOperation.ProvisioningState) {
                            $DeployOperationProgress = $DeployProgress.$ref.clone()
                            $DeployOperationProgress.status = "$($DeployOperation.ProvisioningState)/$($DeployOperation.StatusCode)"

                            $UseColor = Get-StatusColor -provisioningState $DeployOperation.ProvisioningState
                            $DeployOperationProgress.Activity = $usecolor + $DeployOperationProgress.Activity
                            # Write-Verbose ($DeployOperationProgress|ConvertTo-Json -Depth 3)
                            Write-Progress @DeployOperationProgress
                        }

                    }
                    #endregion
                }
                start-sleep -Seconds 1
            }while ($Deployment.ProvisioningState -in 'Running', 'Accepted')
            Write-Verbose $Deployment.ProvisioningState
            #endregion
        } catch {
            Write-Verbose "catch"
            throw $_
        } finally {
            Write-Verbose "Finally"
            #region finish up progressbars
            $global:DeployProgress.GetEnumerator() | ForEach-Object {
                $_.value.completed = $true 
                Write-Progress -Activity "done" -Status "done" -Completed -id $_.value.id 
            }
            #endregion
    
            #region handle errors
            $FinishedDeployments = Get-Deployment -Id $DeploymentId -Context $Context -Scope All
            $global:finishedDeployments = $FinishedDeployments
            $FinishedDeployments | ForEach-Object {
                Write-Verbose "$($_.DeploymentName) - $($_.ProvisioningState)"
            }
            $FailedDeployments = $FinishedDeployments | Where-Object { $_.ProvisioningState -eq 'Failed' }
            $CompletedDeployments = $FinishedDeployments | Where-Object { $_.ProvisioningState -ne 'Failed' }
            if ($FailedDeployments) {

                $FailedDeployments | ForEach-Object {
                    $SubDeployment = $_
                    $SubDeployId = $DeployTarget + "/providers/Microsoft.Resources/deployments/" + $SubDeployment.DeploymentName

                    $DeploymentOperations = Get-DeploymentOperation -id $SubDeployId -Context $context
    
                    Write-warning $(("-" * 10) + " deployment:deployments/" + $SubDeployment.DeploymentName + " " + ("-" * 10))
                    Write-warning "$(($DeploymentOperations|Where-Object{$_.ProvisioningState -eq 'Failed'}).count) errors"
    
                    #enumerate failed operations
                    $DeploymentOperations | Where-Object { $_.ProvisioningState -eq 'Failed' } | ForEach-Object {
                        $FailedOp = $_
                        # Write-Verbose "Failed: $($FailedOp|ConvertTo-Json)"
                        if ($FailedOp.TargetResource) {
                            Write-Warning $(("-" * 10) + " operation:" + ($FailedOp.TargetResource.split("/")[-2..-1] -join "/") + " " + ("-" * 10))
                            Write-Warning "$($FailedOp.TargetResource)"
                        }
                        Write-Warning "$($FailedOp.StatusCode): $($FailedOp.StatusMessage)"
                    }
                }
    
                throw "$($FailedDeployments.count) deployments failed: see warning for details"
            }
            if ($CompletedDeployments) {
                Write-Host "$tab`deployments completed: $($CompletedDeployments.count)"
            }

            #endregion
        }
    }
    end {
        
    }
}
#endregion

#region Deployment\ParameterHandling\Variables\Build-KeyvaultVariable.ps1
function Build-KeyvaultVariable {
    [CmdletBinding()]
    param (
        [envVariable_keyvault]$variable
    )
    
    $vault_error = $null
    $sec_error = $null
    Write-Verbose "Getting secret $($variable.secret) from keyvault $($variable.vault)"
    $azVault = Get-AzKeyVault -VaultName $variable.vault -ErrorAction SilentlyContinue -ErrorVariable vault_error
    if (!$azVault -or $vault_error) {
        throw "Keyvault '$($variable.vault)' not found: $vault_error"
    }
    if ($azVault.EnabledForTemplateDeployment -eq $false) {
        throw "Keyvault '$($variable.vault)' is not enabled for template deployment"
    }

    if ($variable.version) {
        $azSecret = $azVault | Get-AzKeyVaultSecret -Name $variable.secret -Version $variable.version -ErrorAction SilentlyContinue -ErrorVariable sec_error
    } else {
        $azSecret = $azVault | Get-AzKeyVaultSecret -Name $variable.secret -ErrorAction SilentlyContinue -ErrorVariable sec_error
    }
    
    if (!$azSecret -or $sec_error) {
        throw "Secret '$($variable.secret)' not found in keyvault '$($variable.vault)': $sec_error"
    }

    return @{
        reference = @{
            keyVault   = @{
                id = $azVault.ResourceId
            }
            secretName = $azSecret.Name
        }
    }
}
#endregion

#region config\Get-DeployConfigVariable.ps1
function Get-DeployConfigVariable {
    [CmdletBinding()]
    param (
        [parameter(
            ValueFromPipeline,
            HelpMessage = "The name of the variable to get. expects clean value"
        )]
        [string]$value
    )
    process {
        # $Value = Remove-VariableReferenceToken -Value $value
        $config = Get-DeployConfig
        $Variables = @()
        Foreach ($EnvName in $config.environmentPresedence) {
            $env = $config.environments | Where-Object { $_.name -eq $envName }
            if ($env.variables.ContainsKey($Value)) {
                $Variables += $env.variables[$Value]
            }
        }
        $out = $Variables | Select-Object -first 1
        if (!$out) {
            throw "Could not find variable with value '$value'"
        }
        return $out
    }
}
#endregion

#region Deployment\ParameterHandling\Build-DeployVariable.ps1
function Build-DeployVariable {
    [CmdletBinding()]
    param (
        [ValidateNotNullOrEmpty()]
        $val,
        [System.Text.RegularExpressions.Group[]]$VarRefs

    )
    
    begin {
        $deployconfig = Get-DeployConfig
    }
    
    process {
        if (!$VarRefs) {
            $VarRefs = Get-VariableReferenceInString -String $val | Select-Object -Unique
            Write-Verbose "Found $($References.count) variable references in '$ParamName'"
        }

        foreach ($VarRef in $VarRefs) {
            Write-Verbose "handling variable '$($VarRef.value)'"
            $deployEnvVariable = Get-DeployConfigVariable -value $VarRef.Value
            Write-verbose "$($tab)replacing '$($VarRef.value)' with $($deployEnvVariable.type)` value from '$($deployEnvVariable.source)'"
            
            switch ($deployEnvVariable.type) {
                'static' {
                    $replace = Build-StaticVariable -Variable $deployEnvVariable
                    $originalString = @($($deployConfig.dry.style[0]), $VarRef, $($deployConfig.dry.style[1])) -join ''
                        
                    #decide if i should replace in string or replace the whole object
                    # Write-Verbose "val:$paramValue, orig:$originalString, rep:$replace"
                    if ($val -eq $originalString) {
                        Write-verbose "Replacing whole object"
                        $val = $replace
                    } else {
                        Write-Verbose "Replacing value in string"
                        $val = $val.replace($originalString, $replace)
                    }
                }
                'keyvault' {
                    if (@($References).count -gt 1) {
                        throw "keyvault variables can not be called upon in combination with multiple other variables in same reference."
                    }
                    $deployEnvVariable.secret = Build-DeployVariable -val $deployEnvVariable.secret
                    $deployEnvVariable.vault = Build-DeployVariable -val $deployEnvVariable.vault

                    $val = Build-KeyvaultVariable -variable $deployEnvVariable
                }
                'identity' {
                    if (@($References).count -gt 1) {
                        throw "identity variables can not be called upon in combination with multiple other variables."
                    }
                    $val = Build-IdentityVariable -variable $deployEnvVariable
                }
                default {
                    throw "Unknown variable type '$($deployEnvVariable.type)'"
                }
            }
        }

        return $val
    }
    
    end {
        
    }
}
#endregion

#region Deployment\invoke-BicepDeployment.ps1
function Invoke-BicepDeployment {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [parameter(
            ValueFromPipeline
        )]
        [System.IO.FileInfo]$BicepFile,
        [ValidateSet(
            "ResourceGroup",
            "Subscription"
        )]
        [string]$Context,
        [ValidateSet(
            "list",
            "dryRun",
            "default"
        )]
        [string[]]$action = "default"
    )
    
    begin {
        switch ($Context) {
            "ResourceGroup" {
                $tab = "  " * 2
            }
            "Subscription" {
                $tab = "  " * 1
            }
        }
    }
    process {
        # if($action -eq 'dryRun'){
        #     Write-Host "$tab$context`:$($BicepFile.Directory.BaseName)/$($BicepFile.BaseName)"
        # }
        $deployConfig = Get-DeployConfig
        Write-Information "$("->".Padleft($tab.Length," "))$context deployment`: $($BicepFile.Directory.BaseName)/$($BicepFile.BaseName)"
        if ($action -eq 'list') {
            return #"$tab$context`:$($BicepFile.Directory.BaseName)/$($BicepFile.BaseName)"
        }

        $_Param = @{
            # TemplateFile                = $BicepFile.FullName
            SkipTemplateParameterPrompt = $true
            WarningAction               = "SilentlyContinue"
        }
        $_deployParam = @{
            # DeploymentDebugLogLevel = 'All'
            WhatIfResultFormat = 'FullResourcePayloads'
        }

        #region find param file
        $ParamName = "$($BicepFile.BaseName).parameters.json"
        $ParamFile = Get-ChildItem $BicepFile.Directory.FullName -Filter $ParamName | Select-Object -first 1

        if ($ParamFile) {
            Write-Information "$tab`Found parameterfile '$($ParamFile.Name)'"
            $_paramObject =  ConvertTo-ParamObject -ParamFile $ParamFile.FullName -tab "$tab`t"
            $paramtemp = [Path]::GetTempFileName()
            $paramToFile =  @{}
            $_paramObject.GetEnumerator()|ForEach-Object{
                $key = $_.key
                $value = $_.value

                # if reference is set and is a object, its a keyvault reference, meaning we set it as "reference" and not "value"
                if($value.reference -and $value.reference -is [hashtable] ){
                    $paramToFile[$key] = $value
                }
                else {
                    $paramToFile[$key] = @{
                        value = $value
                    }
                }
            }
            $paramToFile | ConvertTo-Json -Depth 10 | Set-Content -Path $paramtemp -WhatIf:$false
            $_param.TemplateParameterFile = $paramtemp
        } else {
            Write-Information "$tab`No parameterfile found. create one with name '$ParamName' if you need"
        }
        # return $_Param.TemplateParameterObject
        #endregion
        if ($WhatIfPreference -or $action -eq 'dryRun') {
            if (!$action -eq 'dryRun') {
                Write-Host "$tab`WHATIF Deploy parameters:"
            } else {
                Write-Host "$tab`DryRun parameters:"
            }

            Get-Content $paramtemp|%{
                Write-Host "$tab$_"
            }
            # Write-Host(gc $paramtemp -Raw)
            # ($_paramObject | convertto-json -Depth 10).split("`n") | ForEach-Object {
            #     Write-host "$tab$_"
            # }
            Write-host "$tab`-----"
            if ($action -eq 'dryRun') {
                return 
            }
        }
        $global:__deploy = $null
        $global:_BaduOutput = [ordered]@{}

        # #convert to bicep before deploying
        # #TODO: make proper bicep convert function.. used by badu and bolt
        if ($BicepFile.Extension -eq '.bicep') {
            #make temp file, ouput converted bicep to temp file, import it, delete temp file
            # this is to make sure "conversion" stream and "warning/err" steam is not mixed
            Write-Information "$tab`Converting bicep to arm template"¨
            $Temp = [system.io.Path]::GetTempFileName()
            $LogTemp = [system.io.Path]::GetTempFileName()
            
            Write-Verbose "Temp file: $Temp"
            Write-Verbose "Log file: $LogTemp"

            $wi = $WhatIfPreference
            $WhatIfPreference = $false
            try{
                bicep build $BicepFile.FullName --outfile $Temp --diagnostics-format sarif *>$LogTemp


                $log = gc $LogTemp
                $StartJon = $log.IndexOf('{')
                $logobject = $Log|select -Skip $StartJon|Convertfrom-json
                $ErrorLogs =  $logobject.runs.results | Where-Object { $_.level -eq 'error' }
                Write-Verbose "exe ok? $? -> has err? $haserror"
                if($? -eq $false -or ($null -ne $ErrorLogs)){
                    throw "Something went wrong converting bicep. (exitcode $LASTEXITCODE)"
                }

                $logobject.runs.results|ForEach-Object{
                    Write-Verbose ($bicepfile.BaseName + " " + $_.level +": " + $_.message.text)
                }
    
                $_param.TemplateObject = gc $temp|ConvertFrom-Json -AsHashtable
                
            }
            catch{
                $ErrorLogs | ForEach-Object {
                    $msg = @(
                        $BicepFile.BaseName
                        $_.ruleId
                        $_.level
                    )
                    Write-Warning (($msg -join " -> ") + ": "+ $_.message.text)
                }
                throw "$_ look at warnings for details ($($bicepfile.FullName))"
            }
            finally{
                $WhatIfPreference = $wi
            }


        } else {
            $_param.TemplateFile = $BicepFile.FullName
        }

        switch ($Context) {
            "ResourceGroup" {
                #todo: add settings for deployment
                $_Param.Mode = "Incremental"
                $_Param.ResourceGroupName = $BicepFile.Directory.Name | Remove-EnvNotation -Env $env
                $deployName = ((@($env, $BicepFile.BaseName).where{ $_ }) -join "-").Replace(" ", "-")
                if ($WhatIfPreference) {
                    if (!(Get-AzResourceGroup -Name $_Param.ResourceGroupName -ea SilentlyContinue)) {
                        Write-Warning "ResourceGroup '$($_Param.ResourceGroupName)' does not exist. Not testing deployment as it would result in 'ResourceGroupNotFound'"
                        # $global:whatifResult += "deploy '$deployName' to $($_Param.ResourceGroupName)"
                        return
                    }
                }

                Write-Information "$tab`Testing rg deployment '$($BicepFile.BaseName)'"
                Write-Verbose "File: $($BicepFile.FullName)"
                Write-Verbose  ($_Param|ConvertTo-Json -Depth 10)

                $DeployTest = Test-AzResourceGroupDeployment @_Param 
                if (($DeployTest | Get-DeploymentTestResult)) {
                    throw "$($BicepFile.Directory.BaseName)/$($BicepFile.BaseName) failed. please look at warnings for details"
                }

                #not setting it on param before now, cause test-azresourcegroupdeployment does not support it
                $_Param.Name = $deployName

                Write-Information "$tab`Deploying with name '$($_Param.Name)'"
                if ($WhatIfPreference) {
                    try {
                        New-AzResourceGroupDeployment @_Param @_deployParam -WhatIf #-WhatIfResultFormat FullResourcePayloads
                        # Get-AzResourceGroupDeploymentWhatIfResult @_param|Add-DeployWhatifresult -Name $deployName -Path $BicepFile.FullName
                        return
                    } catch {
                        throw $_
                    }
                }

                $global:__deploy = New-AzResourceGroupDeployment @_Param @_deployParam -AsJob
                Show-DeploymentProgress -job $global:__deploy -Context ResourceGroup -Name $_param.Name -Folder $_Param.ResourceGroupName -tab $tab
            }
            "Subscription" {
                $_param.Location = $deployConfig.deployLocation

                Write-Information "$tab`Testing $context Deployment '$($BicepFile.BaseName)'"
                Write-Verbose "File: $($BicepFile.FullName)"
                $DeployTest = Test-AzSubscriptionDeployment @_Param
                if ($DeployTest | Get-DeploymentTestResult) {
                    throw "Test of $($BicepFile.Directory.BaseName)/$($BicepFile.BaseName) failed: $($DeployTest)"
                }

                $_Param.Name = $BicepFile.BaseName.Replace(" ", "-")
                Write-Information "$tab`Deploying at $context with name '$($_Param.Name)'"
                if ($WhatIfPreference) {
                    New-AzSubscriptionDeployment @_Param @_deployParam -WhatIf -WhatIfResultFormat FullResourcePayloads
                    # $global:whatifResult += Get-AzSubscriptionDeploymentWhatIfResult @_param
                    return
                }

                $global:__deploy = New-AzSubscriptionDeployment @_Param @_deployParam -AsJob #-DeploymentDebugLogLevel All 
                Show-DeploymentProgress -job $global:__deploy -Context Subscription -Name $_Param.name -Folder (get-azcontext).subscription.name -tab $tab
            }
        }

        if ($global:__deploy) {
            # $global:__deploy | Wait-Job
            $global:_out = $global:__deploy | Receive-Job -wait
            $global:_out | 
            Where-Object { $_ -is [Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.PSResourceGroupDeployment] -or $_ -is [Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.PSDeployment] } | 
            ForEach-Object {
                $deploy = $_
                $global:_BaduOutput.($deploy.DeploymentName) = $deploy.Outputs
                if ($deployConfig.workflow.deployoutput_enabled -and $deploy.Outputs) {
                    switch ($deployConfig.workflow.deployoutput_style) {
                        'json' {
                            $deploy.Outputs | ConvertTo-Json
                        }
                        'object' {
                            $deploy.Outputs
                        }
                    }
                }
            }
        }
    }
    end {
    }
}
#endregion

#region Deployment\AzData\Get-Deployment.ps1
function Get-Deployment {
    [CmdletBinding()]
    param (
        [parameter(Mandatory)]
        [string]$Id,

        [parameter(Mandatory)]
        [ValidateSet(
            "ResourceGroup",
            "Subscription"
        )]
        [string]$Context,

        # [parameter(Mandatory)]
        [ValidateSet(
            "Current",
            "Children",
            "All"
        )]
        [string]$Scope = "Current"
    )
    
    begin {}
    process {
        Write-Verbose "Getting $Context deployment with id '$id'"
        switch ($context) {
            "ResourceGroup" {
                $Deployment = Get-AzResourceGroupDeployment -id $id -ErrorAction SilentlyContinue
                if ($Scope -eq 'Current') {
                    return $Deployment
                }
                
                # if resourcegroup deployment is not found, return nothing
                if(!$deployment){
                    return
                }

                $Deployments = Get-AzResourceGroupDeployment -ResourceGroupName $Deployment.ResourceGroupName -ErrorAction SilentlyContinue | Where-Object { $_.CorrelationId -eq $Deployment.CorrelationId }
                if ($Scope -eq "Children") {
                    $Deployments = $Deployments | Where-Object { $_.Id -ne $id }
                }
                return $Deployments
            }
            "Subscription" {
                $Deployment = Get-AzSubscriptionDeployment -Id $id -ErrorAction SilentlyContinue
                if ($Scope -eq 'Current') {
                    return $Deployment
                }

                $Deployments = (Get-AzSubscriptionDeployment | Where-Object { $_.CorrelationId -eq $Deployment.CorrelationId })
                if ($Scope -eq "Children") {
                    $Deployments = $Deployments | Where-Object { $_.Id -ne $id }
                }
                return $Deployments
            }
        }
    }
    end {}
}
#endregion

#region Deployment\ignore\whatif\New-DeployWhatIfCollector.ps1
function New-WhatIfCollector {
    [CmdletBinding()]
    param (
        
    )
    
    begin {
        
    }
    
    process {
        $global:whatifResult = [WhatIfCollector]::new()
    }
    
    end {
        
    }
}
#endregion

#region Env\Remove-EnvNotation.ps1
function Remove-EnvNotation {
    [CmdletBinding()]
    param (
        [parameter(ValueFromPipeline, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$string,

        [string[]]$Env
    )
    begin {

    }
    Process {
        $env | Where-Object { $string -like "*.$_" } | ForEach-Object {
            $_env = $_
            #split the string on the env notation and join it again
            $Newstring = ($string.split(".") | Where-Object { $_ -ne $_env }) -join "."
            Write-Verbose "Updated: $string to $newstring"
            $string = $Newstring
        }
    
        return $string
    }
}
#endregion

#region Deployment\ParameterHandling\Variables\Build-IndentityVariable.ps1
function Build-IdentityVariable {
    [CmdletBinding()]
    param (
        [envvariable_identity]$variable
    )
    
    begin {
        $outputs = @{
            principalId = ""
            name        = ""
            type        = ""
            ip          = ""
        }
        # Write-Host ($variable|Convertto-json -Compress)
    }
    
    process {
        $account = (get-azcontext).account
        switch ($account.Type) {
            'User' {
                $user = Get-AzADUser -Filter "userprincipalname eq '$($account.id)' or mail eq '$($account.id)'"
                if (@($user).count -gt 1) {
                    Write-Verbose "Found $($user.count) users with id $($account.id). trying to find the right one"
                    $upnuser = $user | Where-Object { $_.UserPrincipalName -eq $account.id }
                    if (!$upnuser) {
                        Write-Verbose "Found none with the correct upn. trying to find one with the correct mail"
                        $upnuser = $user | Where-Object { $_.Mail -eq $account.id }
                        if (!$upnuser) {
                            throw "Found $($user.count) users with id $($account.id), but none with the correct upn or mail"
                        }
                    }
                    $user = $upnuser
                } elseif (!$user) {
                    $tenantId = (get-azcontext).tenantid
                    $tenantName = (Get-AzTenant -TenantId $tenantId).Name
                    throw "Could not find user with upn or mail '$($account.id)' in tenant '$tenantName'"
                }
                $outputs.principalId = $user.Id
                $outputs.name = $user.DisplayName
                $outputs.type = 'User'
            }
            default {
                throw "Account type '$_' not supported, yet: $($account|convertto-json -depth 1)"
            }
        }

        if ($variable.value -eq 'ip') {
            $outputs.ip = (Invoke-RestMethod -Uri 'http://ipinfo.io/json').ip
        }
        
        if ([string]::IsNullOrEmpty($outputs.$($variable.value))) {
            throw "Could not find value for $($variable.value) in $($account.Type) $($account.id)"
        }

        return $outputs.$($variable.value)
    }
    
    end {
        
    }
}
#endregion

#region config\New-DeployConfig.ps1
function New-DeployConfig {
    # [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", Scope="Function", Target="*")]
    # [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", Scope="Function", Target="*")]
    [CmdletBinding()]
    param (
        [DirectoryInfo]$WorkingPath,
        [string]$ActiveEnvironment
    )
    
    begin { 
        #region load the config file contents
        $deployconfigFile = Get-ChildItem $WorkingPath.FullName -File -filter 'deployconfig.json?' | Select-Object -first 1
        if (!$deployconfigFile) {
            throw "could not find a deployconfig.json/jsonc in '$WorkingPath'"
        }

        Write-Verbose "Loading deployConfig from '$deployconfigFile'"
        $deployConfigContent = Get-Content $deployconfigFile

        #clean up jsonc file (remove comments)
        if ($deployconfigFile.Extension -eq '.jsonc') {
            Write-Debug "Fixing jsonc file before parsing"
            $deployConfigContent = $deployConfigContent | Where-Object { $_ -notmatch '^\s*//' }
        }
        $deployConfigObject = $deployConfigContent | ConvertFrom-Json  #-Depth 90
        #endregion
    }
    
    process {
        Write-Verbose $deployConfigObject.gettype()
        $Config = [deployconfig]::new($deployConfigObject, $ActiveEnvironment)
        $config.workingPath = $deployconfigFile.Directory.FullName

        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Used for global config singleton')]
        $Global:deployConfig = $Config
    }
    
    end {
        
    }
}
#endregion

#region Deployment\WhileDeploying\Get-StatusColor.ps1
function Get-StatusColor {
    [CmdletBinding()]
    param (
        [string]$provisioningState
    )
    #write as ansi codes using rgb
    # $Colors = @{
    #     red   = "`e[38;2;220;20;60m" #crimson
    #     blue  = "`e[38;2;0;191;255m" #deep skye blue
    #     green = "`e[38;2;0;255;0m" #lime
    # }
    $Colors = @{
        red   = [KnownColor]::Crimson
        blue  = [KnownColor]::DeepSkyBlue
        green = [KnownColor]::Lime
    }

    $colorName = $null
    switch ($provisioningState) {
        'Succeeded' {
            $colorName = $Colors.green
        }
        'Failed' {
            $colorName = $Colors.red
        }
        default {
            $colorName = $Colors.blue
        }
    }

    $color = [color]::FromName($colorName.ToString())
    return "`e[38;2;{0};{1};{2}m" -f $Color.R, $Color.G, $Color.B
}
#endregion

#region Deployment\WhileDeploying\Wait-ForDeploymentStart.ps1
function Wait-ForDeploymentStart {
    [CmdletBinding()]
    param (
        [String]$DeploymentId,
        [string]$Context,
        [Microsoft.Azure.Commands.Common.AzureLongRunningJob]$Job,
        [hashtable]$Progress
    )
    
    begin {
        $deployparam = @{
            id      = $DeploymentId
            context = $Context
        }
        $Deployment = Get-Deployment @deployparam -Scope Current
    }
    process {
        $VerboseCount = 0
        :wait do {
            if ($job) {
                $status = $job.verbose | Select-Object -Skip $VerboseCount
                $status | ForEach-Object {
                    Write-Verbose $_
                    if ($_ -like "*provisioning status is running*") {
                        break :wait
                    }
                    $VerboseCount++
                }
            }

            $Deployment = Get-Deployment @deployparam -Scope Current
            Write-Verbose "Deployment status: $($Deployment.ProvisioningState)"
            $Progress.Status = "Waiting for $context deployment to start running in azure. Status: $($Deployment.ProvisioningState)"

            Write-Progress @Progress
            start-sleep -Milliseconds 200
        }while ($Deployment.ProvisioningState -notin 'Running', 'Accepted')

        $Progress.Status = "Deployment started running in azure"

        Write-progress @Progress -Completed 
    }
    end {}
}
#endregion

#region Deployment\ParameterHandling\Variables\Build-StaticVariable.ps1
function Build-StaticVariable {
    [CmdletBinding()]
    param (
        [envVariable_static]$Variable
    )
    
    begin {
        
    }
    
    process {
        if ($Variable.value -is [psobject]) {
            $Variable.value = $Variable.value | ConvertTo-Hashtable
        }
        return $Variable.value
    }
    
    end {
        
    }
}
#endregion

#region Env\Select-ByEnvironment.ps1
function Select-ByEnvironment {
    param(
        # [Parameter(Mandatory)]
        [List[deployEnvironment]]$environments,

        [switch]$All,

        [parameter(
            ValueFromPipeline,
            Mandatory,
            ParameterSetName = "folders")]
        [System.IO.DirectoryInfo]$InputFolders,

        [parameter(
            ValueFromPipeline,
            Mandatory,
            ParameterSetName = "files")]
        [System.IO.FileInfo]$InputFiles
    )
    begin {
        $return = @()
        $envHasValues = $environments.Count -gt 0
        $envHasScopedValues = ($environments | Where-Object { $_.isScoped -eq $true }).count -gt 0
        if (!$envHasValues) {
            Write-Warning "No environments is set in deployconfig.json. Please use environments for better control over what is deployed."
        }
    }
    process {
        $InputItems = @($InputFolders, $InputFiles) | Where-Object { $_ }

        #remove ignored files/folders
        $InputItems = $InputItems | Where-Object { $_.basename -notlike "*.ignore" }

        # switch ($PSCmdlet.ParameterSetName) {
        #     "folders" {
        #         $InputFolders = $InputFolders | Where-Object { $_.name -notlike "*.ignore" }
        #     }
        #     "files" {
        #         $InputFiles = $InputFiles | Where-Object { $_.basename -notlike "*.ignore" }
        #     }
        # }

        #if env has scoped values, meaning script has started with -env parameter, 
        #only search for files/folders that matches the env name of both scoped and unscoped environments
        if ($envHasScopedValues) {
            $Environments | ForEach-Object {
                $envName = $_.name
                
                switch ($PSCmdlet.ParameterSetName) {
                    "folders" {
                        $InputFolders | Where-Object { $_.name -like "*.$envName" } | ForEach-Object {
                            $return += $_
                        }
                    }
                    "files" {
                        #wildcard.{env}{.extension}
                        $InputFiles | Where-Object { $_.BaseName -like "*.$envName" } | ForEach-Object {
                            $return += $_
                        }
                    }
                }
            }
        }
        #if environment contains unscoped environments, search for files/folders that matches the env name of unscoped environments
        elseif ($envHasValues) {
            $Environments | Where-Object { $_.isScoped -eq $false } | ForEach-Object {
                $envName = $_.name
                switch ($PSCmdlet.ParameterSetName) {
                    "folders" {
                        $InputFolders | Where-Object { $_.name -like "*.$envName" } | ForEach-Object {
                            $return += $_
                        }
                    }
                    "files" {
                        #wildcard.{env}{.extension}
                        $InputFiles | Where-Object { $_.name -like "*.$envName$($_.Extension)" } | ForEach-Object {
                            $return += $_
                        }
                    }
                }
            }
        }

        #if environment does not contain a scoped environment, return all items without environment suffix
        if (!$envHasScopedValues -or $all) {
            switch ($PSCmdlet.ParameterSetName) {
                "folders" {
                    $InputFolders | Where-Object { $_.name -notlike "*.*" } | ForEach-Object {
                        $return += $_
                    }
                }
                "files" {
                    $InputFiles | Where-Object { $_.name -notlike "*.*$($_.Extension)" } | ForEach-Object {
                        $return += $_
                    }
                }
            }
        }
    }
    end {
        return ($return | Select-Object -Unique)
    }
}
#endregion

#region Deployment\Get-DeploymentTestResult.ps1
function Get-DeploymentTestResult {
    [CmdletBinding()]
    [outputtype([bool])]
    param (
        [parameter(
            ValueFromPipeline
        )]
        $TestResult
    )
    
    begin {}    
    process {
        $TestResult | ForEach-Object {
            Write-Warning "$($_.code): $($_.message)"
            write-warning $($_ | ConvertTo-Json -Depth 10)
        }
        return ([bool]$TestResult)
    }
}
#endregion

#region Helpers\Update-DeploySorting.ps1
function Update-DeploySorting {
    [CmdletBinding()]
    param (
        [parameter(
            ValueFromPipeline,
            ParameterSetName = 'file',
            Mandatory
        )]
        [FileInfo]$InputFile,
        [parameter(
            ValueFromPipeline,
            ParameterSetName = 'folder',
            Mandatory
        )]
        [DirectoryInfo]$inputFolder
    )
    
    begin {
        $map = [ordered]@{}
        $parent = ""
        $deploysort = @()
        $deploysort_filename = "sort"
    }
    
    process {
        #get and initate deployorder map from deployorder file (only once)
        if ($map.count -eq 0) {
            switch ($PSCmdlet.ParameterSetName) {
                "folder" {
                    $parent = $InputFolder.Parent.FullName
                }
                "file" {
                    $parent = $InputFile.Directory.FullName
                }
            }
            #get sorting file based on current item parent folder
            $deploysort_path = (join-path $parent $deploysort_filename)
            if (test-path $deploysort_path) {
                $deploysort = @(Get-Content $deploysort_path)
            } else {
                Write-debug "Order file not found, creating working object"
                $deploysort = @()
            }

            if ('...' -notin $deploysort) {
                $deploysort += '...'
            }

            foreach ($line in $deploysort) {
                $map.$line = @()
            }

            Write-verbose "$($PSCmdlet.ParameterSetName) sort-file in /$(split-path $parent -leaf): $($map.Keys -join ', ')"
        }

        #concatonate so i dont have to process several variables
        $item = @($inputFolder, $InputFile) | Where-Object { $_ }

        :itemsearch foreach ($key in $map.Keys | Where-Object { $_ -ne '...' }) {
            if ($item.basename -like $key) {
                $map.$key += $item
                #stop processing current item. even if all items are returned, end will still be called
                return
            }
        }

        $map.'...' += $item

    }
    
    end {
        $map.GetEnumerator() | ForEach-Object {
            # Write-Verbose "output '$($_.Name)'"
            $_.value | ForEach-Object {
                Write-Output $_
            }
        }
    }
}
#endregion

#region Deployment\ParameterHandling\Variables\Test-ValueIsVariableReference.ps1
function Test-ValueIsVariableReference {
    [CmdletBinding()]
    param (
        $value
    )

    
    if ($value -isnot [string]) {
        return $false
    }

    return @(Get-VariableReferenceInString -String $value).Count -gt 0
}
#endregion

#region Deployment\ParameterHandling\ConvertTo-Hashtable.ps1
function ConvertTo-Hashtable {
    [CmdletBinding()]
    [outputtype([hashtable])]
    param (
        [parameter(ValueFromPipeline)]
        [psobject]$InputItem
    )
    
    begin {
        $OutValue = @{}
    }
    
    process {
        $InputItem.psobject.properties | ForEach-Object {
            $val = $_.value
            $key = $_.name
            if ($val -is [psobject]) {
                Write-Verbose "$key is psobject, converting to hashtable"
                $val = $val | ConvertTo-Hashtable
            }
            $OutValue.$key = $val
        }
    }
    
    end {
        return $OutValue
    }
}
#endregion

#region Deployment\ParameterHandling\ConvertTo-ParamObject.ps1
function ConvertTo-ParamObject {
    param(
        [System.IO.FileInfo]$ParamFile
        # [string]$tab = ""
    )
    begin {
        $return = @{}
        # $deployConfig = Get-DeployConfig
    }
    process {

        $ParamItem = Get-Content -raw $ParamFile | ConvertFrom-Json

        $params = $paramItem.Parameters
        foreach ($parameter in $params.psobject.properties) {
            $ParamName = $parameter.Name
            $ParamVal = $parameter.Value
            Write-Verbose "ParamName: $ParamName, ParamVal: $ParamVal"
            if ($ParamVal.value -is [string]) {
                $ParamValue = $parameter.Value.value
                #find replacement if value is a variable reference
                Write-Verbose "Handling parameter '$ParamName'"
                $ParamValue = Build-DeployVariable -val $ParamValue
                # $References = Get-VariableReferenceInString -String $ParamValue | select -Unique
                # if($References.count -gt 0) {
                #     Write-Verbose "Found $($References.count) variable references in '$ParamName'"
                #     $ParamValue = Build-DeployVariable -VarRefs $References -val $ParamValue
                # }
            } elseif ($null -ne $ParamVal.value) {
                # Write-Verbose "$($parameter.name) value.value"
                # Write-Verbose ($ParamVal.value|ConvertTo-Json -Depth 10)
                $ParamValue = $parameter.value.value
            } else {
                # Write-Verbose "value"
                # Write-Verbose ($ParamVal|ConvertTo-Json -Depth 10)
                $ParamValue = $parameter.value
            }
            $return.Add($ParamName, $ParamValue)
        }
    }
    end {
        return $return
    }
}
#endregion

#endregion funtions

#Main
Write-BaduHeader
Write-Verbose "env: $env"
Write-Verbose "name: $name"
Write-Verbose "action: $action"
Write-host $BuildId

# $global:_Output = @{}

if ($WhatIfPreference) {
    Write-Warning "THIS IS WHATIF BUILD. NO CHANGES WILL HAPPEN"
    # $global:whatifResult = @()
}

$InformationPreference = "continue"

#validating that the subfolder have bicep files in them
if ($null -eq (Get-ChildItem $PSScriptRoot -Recurse -File -Filter "*.bicep")) {
    throw "There are no bicep files defined whithin this deployment. Please define a subscription/resourcegroup/file.bicep folder structure"
}

New-DeployConfig -WorkingPath $psscriptroot -ActiveEnvironment $env
$DeployConfig = Get-DeployConfig
$AvailableSubscriptions = Get-AzSubscription -TenantId $DeployConfig.getTenantId() -WarningAction SilentlyContinue
# Write-Verbose "tenant: $($DeployConfig.getTenantId()), subscriptions: $(($AvailableSubscriptions.Name|%{"'$_'"}) -join ", ")"

Write-verbose "active environments: $($DeployConfig.environments.name -join ", ")"

$SubFolders = Get-ChildItem $PSScriptRoot -Directory | Select-ByEnvironment -Environments $DeployConfig.Environments -All
$subFolders = $subFolders | Update-DeploySorting
$UsingSubFolders = $subFolders | Where-Object { ($_.name | Remove-EnvNotation -Env $DeployConfig.environments.name) -in $AvailableSubscriptions.Name }

$SubFolders | Where-Object { $_.name -notin $UsingSubFolders.name } | ForEach-Object {
    Write-Warning "Skipping subscrpition folder $($_.name) (subscription '$(($_.name|Remove-EnvNotation -Env $DeployConfig.environments.name))') because it is not found within your tenant"
}

$commonparameters = @{
    Erroraction = "stop"
}

Write-Information "processing $($SubFolders.count) subscriptions"
if ($WhatIfPreference -and $SubFolders.count) {
    Write-Verbose "whatif: processing $($SubFolders.count) subscription folders: $($SubFolders.name -join ", ")"
}

:subFolderSearch foreach ($subFolder in $UsingSubFolders) {
    Write-Verbose "Processing subscription folder '$($subFolder.name)'"
    $subscriptionName = $subFolder.name | Remove-EnvNotation -Env $DeployConfig.Environments.name
    $subscriptionId = ($AvailableSubscriptions | Where-Object { $_.Name -eq $SubscriptionName }).id

    #has name changed? meaning the subscription folder has an env notation
    #this means that i can ignore any search for env notation inside the folder
    $SubscriptionHasEnvNotation = $subFolder.name -ne $SubscriptionName

    if ((get-azcontext).Subscription.id -ne $subscriptionId) {
        Write-Information "updating context to subscription '$subscriptionName'"
        Set-AzContext -Subscription $SubscriptionName -ErrorAction Stop -WhatIf:$false -Debug:$false -Verbose:$false -WarningAction SilentlyContinue | Out-Null
    }

    #get bicep files in subscription folder
    # $SubBicepFiles = Get-ChildItem $subFolder.FullName -Filter "*.bicep" -File | Update-DeploySorting
    $SubBicepFiles = Get-DeploymentFile $subFolder.FullName | Update-DeploySorting
    $SubBicepFiles = $SubBicepFiles | Select-ByEnvironment -Environments $DeployConfig.Environments -all:$subscriptionHasEnvNotation
    Write-Verbose "Found $($SubBicepFiles.count) bicep files in subscription folder '$($subFolder.name)'"
    #Deploy bicep files within subscription scope
    if ($name) {
        $FilteredFiles = $SubBicepFiles | Where-Object { $_.basename -like $name }
        #report what files where filtered away
        $SubBicepFiles | Where-Object { $_.Name -notin $FilteredFiles.Name } | ForEach-Object {
            Write-Verbose "Skipping file $($_.FullName) because it does not match the filter '$name'"
        }
        $subBicepFiles = $FilteredFiles
    }
    $SubBicepFiles | Invoke-BicepDeployment -Context 'Subscription' @commonparameters -action $action

    #get folders and sort them if sort file exists. having multiple commands give better error handling, instead of one long pipe
    $RgFolders = Get-ChildItem $subFolder.FullName -Directory
    $RgFolders = $RgFolders | Where-Object { Get-ChildItem $_.fullname -filter "*.bicep" -file } 
    if (@($RgFolders).count -eq 0 ) {
        break :subFolderSearch
    }
    $RgFolders = $RgFolders | Update-DeploySorting
    $RgFolders = $RgFolders | Select-ByEnvironment -Environments $DeployConfig.Environments -all:$subscriptionHasEnvNotation

    # "-----------------"
    # $RgFolders
    # #only process resource groups that have bicep files
    foreach ($Folder in $RgFolders) {
        Write-Verbose "Processing resource group folder '$($Folder.name)'"
        $resourceGroupName = $Folder.name | Remove-EnvNotation -Env $DeployConfig.Environments.name
        $resourceGroupHasEnvNotation = $subFolder.name -ne $SubscriptionName

        #Validate that rg exists
        $Rg = Get-AzResourceGroup -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
        if (-not $Rg -and $WhatIfPreference -eq $false) {
            throw "Could not find Resource group '$ResourceGroupName'"
        }
        
        $RgBicepFiles = Get-DeploymentFile $Folder.FullName
        # $RgBicepFiles = Get-ChildItem $Folder.FullName -Filter "*.bicep" -File
        $RgBicepFiles = $RgBicepFiles | Select-ByEnvironment -Environments $DeployConfig.Environments -all:$($resourceGroupHasEnvNotation -or $subscriptionHasEnvNotation)
        $RgBicepFiles = $RgBicepFiles | Update-DeploySorting
        if ($name) {
            $FilteredFiles = $RgBicepFiles | Where-Object { $_.basename -like $name }
            $RgBicepFiles | Where-Object { $_.Name -notin $FilteredFiles.Name } | ForEach-Object {
                Write-Verbose "Skipping file $($_.Name) because it does not match the name filter '$name'"
            }
            $RgBicepFiles = $FilteredFiles
        }

        $RgBicepFiles | Invoke-BicepDeployment -Context ResourceGroup @commonparameters -action $action
    }
}
