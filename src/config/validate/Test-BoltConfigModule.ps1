function Test-BoltConfigModule {
    [CmdletBinding()]
    param (
        [boltConfigModule]$Config
    )
    
    New-BoltLogContext -command "validate.config.module"


    if ($this.folder -like "./*" -or $this.folder -like "/*") {
        throw "module.folder cannot start with './' or '/'"
    }

    $ModulePath = join-path (Get-GitRoot) $this.folder
    if ((test-path $ModulePath) -eq $false) {
        throw "Cannot find defined modulepath '$($ModulePath)'"
    }
}