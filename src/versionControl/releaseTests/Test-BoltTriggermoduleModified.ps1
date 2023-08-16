function Test-BoltmoduleModified {
    [CmdletBinding()]
    [OutputType([ModuleUpdateReason])]
    param (
        [hashtable]$LocalObject,
        [hashtable]$RemoteObject,
        [System.IO.FileInfo]$LocalTemplate,
        [System.IO.FileInfo]$RemoteTemplate
    )
    
    #write all incoming parameters
    # $PSCmdlet.MyInvocation.BoundParameters.GetEnumerator() | % {
    #     Write-BoltLog -message "$($_.key) = $($_.value)" -level verbose
    # }

    $LocalDigest = New-DigestHash -Item $LocalTemplate -Algorithm SHA256
    $RemoteDigest = New-DigestHash -Item $RemoteTemplate -Algorithm SHA256
    if($LocalDigest -ne $RemoteDigest){
        Write-Output ([ModuleUpdateReason]::Modified('file digest', "$($LocalDigest.split(":")[1].Substring(0, 10))..", "$($RemoteDigest.split(":")[1].Substring(0, 10)).."))
    }
}