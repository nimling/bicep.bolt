function Test-BoltConfigModule {
    [CmdletBinding()]
    param (
        [boltConfigModule]$Config
    )

    New-BoltLogContext -command "validate.config.module"

    if ($Config.folder -like "./*" -or $Config.folder -like "/*") {
        throw "module.folder cannot start with './' or '/'"
    }

    $ModulePath = join-path (Get-GitRoot) $Config.folder
    if ((test-path $ModulePath) -eq $false) {
        throw "Cannot find defined modulepath '$($ModulePath)'"
    }
}