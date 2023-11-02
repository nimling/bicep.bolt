function Find-BoltConfigFile {
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo])]
    param (
        [System.IO.DirectoryInfo]$SearchFrom = (Get-Location).Path
    )

    $ConfigFileName = "bolt.json"
    if($global:pester_enabled) {
        $ConfigFileName = "bolt_pester.json"
    }
    
    return (Find-File -SearchFrom $SearchFrom -FileName $ConfigFileName)
}
