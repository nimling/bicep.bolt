function Test-BicepInstallation {
    [CmdletBinding()]
    param (
        
    )
    
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
    if ($InstalledVersion -ge $this.bicepVersion) {
        Write-BicepInstallInfo -InstallInfo upgrade
        # $this.MessageBicepInstall([bicepInstallType]::upgrade)
        throw "Bicep version is too low. Expected $($this.bicepVersion) but found $($InstalledVersion)"
    }

    #give warning if the bicep version defined is really low
    $lowestRecomendedVersion = $this.GetLowestRecomendedBicepVersion()
    if ($this.bicepVersion -lt $lowestRecomendedVersion) {
        Write-BoltLog -level warning -message "config Bicep version very is low. you should set it to atleast $lowestRecomendedVersion for best performance and conversion handling"
    }
    $this.bicepVersion
}