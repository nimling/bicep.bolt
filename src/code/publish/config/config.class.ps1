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
    [string]$temp

    boltConfigModule() {
        $this.organisationStyle = [boltConfigModuleStyle]::new()
        $this.temp = ".bicepTemp"
    }

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

    hidden [string]$configDirectory

    [void]Validate()
    {
        Test-BoltConfigRegistry -Config $this.registry
        Test-BicepInstallation -configVersion $this.bicepVersion
        Test-BoltConfigReleaseTrigger -Triggers $this.publish.releaseTrigger
    }

    [void]SetConfigDirectory([string]$directory){
        $this.configDirectory = $directory
    }

    [string]GetConfigDirectory(){
        return $this.configDirectory
    }
}

