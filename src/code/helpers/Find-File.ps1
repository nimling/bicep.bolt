<#
.SYNOPSIS
Searches for a file, from current directory and up (towards root)

.PARAMETER SearchFrom
starting directory

.PARAMETER FileName
name of the file to search for. can be a wildcard. will return the first match

.EXAMPLE
Find-File -SearchFrom (Get-Location).Path -FileName "bicepconfig.json"
#>
function Find-File {
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo])]
    param (
        $SearchFrom,
        [string]$FileName
    )
    if((get-item $SearchFrom) -is [System.IO.FileInfo]){
        Write-BoltLog "SearchFrom is a file, getting parent directory" -level verbose
        $SearchFrom = split-path $SearchFrom -Parent
    }
    $SearchFrom = [System.IO.DirectoryInfo]$SearchFrom
    $startsearchFrom = $SearchFrom
    $ConfigPath = ""
    while(!$ConfigPath) {
        Write-BoltLog "searching for $FileName in $SearchFrom" -level verbose
        $ConfigPath = (Get-ChildItem -Path $SearchFrom -Filter $FileName -ErrorAction SilentlyContinue|Select-Object -first 1).FullName
        if([string]::IsNullOrEmpty($ConfigPath)) {
            if($null -eq $SearchFrom.Parent) {
                throw "Could not find $FileName in $startsearchFrom or any parent directory (stopped at $SearchFrom)"
            }
            $SearchFrom = $SearchFrom.Parent
        }
    }
    Write-BoltLog "Found $ConfigPath" -level verbose
    return [System.IO.FileInfo]$ConfigPath
}