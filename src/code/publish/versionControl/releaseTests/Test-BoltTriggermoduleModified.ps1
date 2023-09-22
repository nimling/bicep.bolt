function Test-BoltmoduleModified {
    [CmdletBinding()]
    [OutputType([ModuleUpdateReason])]
    param (
        [System.IO.FileInfo]$LocalTemplate,
        [System.IO.FileInfo]$RemoteTemplate,
        [switch]$LogEverything
    )
    $LocalDigest = New-DigestHash -Item $LocalTemplate -Algorithm SHA256
    $RemoteDigest = New-DigestHash -Item $RemoteTemplate -Algorithm SHA256
    if($LocalDigest -ne $RemoteDigest){
        if($LogEverything)
        {
            Write-BoltLog "Template file has changed" -level "dev"
        }
        Write-Output ([ModuleUpdateReason]::Modified('file digest', "$($LocalDigest.split(":")[1].Substring(0, 10))..", "$($RemoteDigest.split(":")[1].Substring(0, 10)).."))
    }
}