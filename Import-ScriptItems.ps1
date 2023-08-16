[cmdletbinding()]
param()
get-command | 
Where-Object { $_.CommandType -eq 'function' } | 
Where-Object { $_.ScriptBlock.File -like "$PSScriptRoot*.ps1" } |
ForEach-Object {
    remove-item "Function:\$($_.Name)"
}

Get-ChildItem "$PSScriptRoot/src/code/*.ps1" -Recurse -Exclude "*.tests.ps1"| ForEach-Object {
    Write-Verbose "importing $($_.basename) \$([System.IO.Path]::GetRelativePath("$PSScriptRoot/src/code",$_.FullName))"
    . $_.FullName
}