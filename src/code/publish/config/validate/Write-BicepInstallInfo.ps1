function Write-BicepInstallInfo {
    [CmdletBinding()]
    param (
        [ValidateSet(
            "install",
            "upgrade"
        )]
        [String]$InstallInfo
    )

    $methods = @{
        scoop = "scoop $InstallInfo bicep"
        winget = "winget $InstallInfo bicep"
        az = "az bicep $InstallInfo"
    }

    $methods.GetEnumerator() | ForEach-Object {
        $command = $_.Value
        $test = $_.Key
        if (Get-Command $test -ea SilentlyContinue) {
            Write-BoltLog -level warning -message "command: $command"
        }
    }
    Write-BoltLog -level warning -message "manual: download from 'https://github.com/Azure/bicep/releases'"
}