
#hopefully this is fast enought to be used throughout the codebase. average time is 0.22ms when i tested. 
#TODO: test with many more items in callstack
function Get-CurrentRunHash {
    [CmdletBinding()]
    param ()
    Set-BoltMetricpoint Start
    Write-Output (get-pscallstack)[-1].GetHashCode()
    Set-BoltMetricpoint End
}

# Get-CurrentRunHash