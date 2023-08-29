function Get-BicepConfig {
    [CmdletBinding()]
    [OutputType([BicepConfig])]
    param (
        [string]$Path
    )
    
    $ConfigFileName = "bicepconfig.json"
    $configFile = Find-File -SearchFrom $path -FileName $ConfigFileName
    return [BicepConfig](get-content $configFile.FullName | ConvertFrom-Json -AsHashtable)
}