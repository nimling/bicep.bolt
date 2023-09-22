<#
.SYNOPSIS
Test if installed bicep version is greater than or equal to the required version

.PARAMETER BicepVersion
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>
function Test-BicepCli {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [string]$BicepVersion
    )

    $bicep = Get-Command bicep -ea SilentlyContinue
    if (!$bicep) {
        Write-Warning "Bicep not found"
        return $false
    }

    $(bicep --version) -match "(?'ver'\d+\.\d+\.\d+)" | Out-Null
    if ($matches.ver -lt $bicepVersion) {
        Write-Warning "the installed bicep version ($($matches.ver)) is less than the required version ($($config.bicepVersion)). please update"
        return $false
    }
    return $true
}