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
            Write-BaduWarning "$($_.code): $($_.message)"
            Write-BaduWarning $($_ | ConvertTo-Json -Depth 10)
        }
        return ([bool]$TestResult)
    }
}
