function Get-BoltScriptFile {
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo])]
    param (
        [ValidateSet("cmdlet","class","tests")]
        [string]$Type
    )
    
    $scripts = Get-ChildItem "$PSScriptRoot/src" -Recurse -Filter "*.ps1" -File
    $scripts = $scripts | Where-Object { $_.Directory.name -ne "_ignore"}
    switch($Type)
    {
        "cmdlet" {
            $scripts = $scripts | Where-Object { $_.basename -notlike "*.tests" -and $_.basename -notlike "*.class"}
        }
        "class" {
            $scripts = $scripts | Where-Object { $_.basename -like "*.class" }
        }
        "tests" {
            $scripts = $scripts | Where-Object { $_.basename -like "*.tests" }
        }
    }

    return @($scripts)
}

#import classes and functions
$ScriptDependencies = [ordered]@{
    class    = Get-BoltScriptFile -Type class
    function = Get-BoltScriptFile -Type cmdlet
}

#easiest way to make sure classes are always loaded first
foreach ($item in $ScriptDependencies.GetEnumerator()) {
    Write-Verbose "importing $($item.key)"
    foreach ($_importscript in $item.value) {
        Write-Host "importing $($_importscript)"
        . $_importscript.FullName
    }
}