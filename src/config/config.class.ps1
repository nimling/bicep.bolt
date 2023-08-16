using namespace System.Collections.Generic
using namespace System.io
using namespace System

class boltConfigRegistry {
    [string]$type = "acr"

    [ValidateNotNullOrEmpty()]
    [string]$name

    [ValidateNotNullOrEmpty()]
    [string]$subscriptionId
    
    [ValidateNotNullOrEmpty()]
    [string]$tenantId

    Validate() {
        Test-BoltConfigRegistry -RegistryConfig $this
    }

    [String]ToString() {
        return "$($this.type):$($this.name)"
    }
}

class boltConfigModuleStyle{
    [ValidateSet(
        'SingleModuleFolder',
        'MultiModuleFolder'
    )]
    [string]$Type
    [string]$Filter
    [string]$exclude

    [string]ToString() {
        return "$($this.Type):?$($this.Filter):-$($this.exclude)"
    }
}

class boltConfigModule {
    [ValidateNotNullOrEmpty()]
    [string]$folder
    [boltConfigModuleStyle]$organisationStyle

    validate() {
        Test-BoltConfigModule -Config $this
    }

    [string]ToString() {
        return "$($this.folder):$($this.style)"
    }
}

class Config_Docs {
    [bool]$enable
    [string]$folder
    [List[string]]$items
    validate() {
        
    }
    [string]ToString() {
        return "$($this.enable):$($this.folder)"
    }
}
class boltConfigVersion {
    [string]$branch = ""
    [string]$type = ""
    [string]$value = ""
    [string]$prefix = ""
    validate() {}
    [string]ToString() {
        return "$($this.branch):$($this.type)"
    }
}
class boltConfigRelease {
    [string]$name
    [string]$trigger
    [string]$value = ""
    [string]$prefix = ""
}
class boltConfigReleaseTriggerItem {
    [List[string]]$update
    [List[string]]$major
    [List[string]]$minor
    [List[string]]$patch
}

class boltConfigReleaseTrigger {
    [boltConfigReleaseTriggerItem]$static
    [boltConfigReleaseTriggerItem]$semantic
}

class boltConfigPublish{
    [boltConfigReleaseTrigger] $releaseTrigger
    [string]$defaultRelease
    [boltConfigRelease[]]$releases
}

enum bicepInstallType{
    install
    upgrade
}

class boltConfig {
    #weird thing to handle dollar sign in variable
    [string]${$schema}
    [string]$bicepVersion
    [boltConfigRegistry]$registry
    [boltConfigModule]$module
    [boltConfigPublish]$publish
    # [Config_Remote]$remote
    # [Config_Module]$module
    # [Config_Docs]$docs
    # [string]$defaultbranch
    # [List[Bolt_Version]]$versioning
    # Bolt_Config(){}
    # Bolt_Config([FileInfo]$Path,[hashtable]$Config){
    #     $this.path = $Path
    #     $this.registry = 
    # }
    # Validate() {
    #     $this.remote.Validate()
    #     $this.module.validate()
    #     $this.docs.validate()

    #     $branches = $this.versioning.branch | Select-Object -Unique
    #     if ($this.defaultbranch -notin $branches) {
    #         throw "Could not find default branch '$($this.defaultbranch)' in $($branches|%{"'$_'"} -join ", ")"
    #     }

    #     #versioning
    #     $this.versioning | ForEach-Object {
    #         $_.validate()
    #     }
    # }   
    [void]Validate()
    {
        $this.VaildateBicep()
    }

    [void]VaildateBicep()
    {
        #check if bicep is installed
        $bicep = Get-Command bicep -ea SilentlyContinue
        if (!$bicep) {
            Write-BicepInstallInfo -InstallInfo install
            # $this.MessageBicepInstall([bicepInstallType]::install)
            throw "Could not find bicep in path. Please install bicep"
        }

        #check if bicep version is correct
        #returns Bicep CLI version 0.18.4 (1620479ac6)
        $ver = bicep --version
        $ver = $ver -replace '.*version ', ''
        $InstalledVersion = ($ver -replace ' .*', '').trim()
        if ($InstalledVersion -lt $this.bicepVersion) {
            Write-BicepInstallInfo -InstallInfo upgrade
            # $this.MessageBicepInstall([bicepInstallType]::upgrade)
            throw "Bicep version is too low. Expected $($this.bicepVersion) but found $($InstalledVersion)"
        }

        #give warning if the bicep version defined is really low
        # $lowestRecomendedVersion = "10.0.0"#$this.GetLowestRecomendedBicepVersion()
        # if($this.bicepVersion -lt $lowestRecomendedVersion)
        # {
        #     Write-BoltLog -level warning -message "config Bicep version very is low ($($this.bicepVersion)). you should set it to atleast $lowestRecomendedVersion for best performance and conversion handling"
        # }
        # $this.bicepVersion
    }
}

