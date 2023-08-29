function Test-BicepInstallation {
    [CmdletBinding()]
    param (
        [string]$configVersion = "10.0.0"
    )
    New-BoltLogContext -command 'validate_bicep'
    # $Config = Get-BoltConfig

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
    if ($InstalledVersion -lt $configVersion) {
        Write-BicepInstallInfo -InstallInfo upgrade
        # $this.MessageBicepInstall([bicepInstallType]::upgrade)
        Write-BoltLog -level warning "Bicep version is too low. Expected $($configVersion) but found $($InstalledVersion)"
        throw "Bicep version too low. Expected $($configVersion) but found $($InstalledVersion)"
    }

    #give warning if the bicep version defined is really low
    $lowestRecomendedVersion = Get-BicepVersion -What Lowest
    if ($configVersion -lt $lowestRecomendedVersion) {
        Write-BoltLog -level warning -message "config Bicep version very is low ($configVersion). you should set it to minimum $lowestRecomendedVersion for best performance and conversion handling"
    }
}