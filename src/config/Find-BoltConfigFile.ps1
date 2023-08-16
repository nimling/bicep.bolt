function Find-BoltConfigFile {
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo])]
    param (
        [System.IO.DirectoryInfo]$SearchFrom = (Get-Location).Path
    )

    $ConfigFileName = "bolt.json"
    $ConfigPath = ""
    while(!$ConfigPath) {
        Write-BoltLog "searching for $configFileName in $SearchFrom" -level verbose
        $ConfigPath = (Get-ChildItem -Path $SearchFrom -Filter "bolt.json" -ErrorAction SilentlyContinue).FullName
        if($ConfigPath -eq "") {
            if($null -eq $SearchFrom.Parent) {
                throw "Could not find $ConfigFileName in $SearchFrom or any parent directory"
            }
            $SearchFrom = $SearchFrom.Parent
        }
    }
    Write-BoltLog "Found $ConfigPath" -level verbose
    return [System.IO.FileInfo]$ConfigPath
}
