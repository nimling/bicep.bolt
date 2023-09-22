using namespace System.IO
<#
.SYNOPSIS
Generate OCI type hash. used by container registry.

.PARAMETER Item
path to file or system.io.fileinfo object

.PARAMETER Algorithm
algorithm to use. sha256 or 512

.NOTES
it generally creates another type of info than get-filehash. dont know why, but it generates it in the same way as container registry would
#>
function New-DigestHash {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [parameter(Mandatory, ParameterSetName = "Item")]
        [FileInfo]$Item,
        [parameter(Mandatory, ParameterSetName = "Bytes")]
        [byte[]]$Bytes,
        [ValidateSet(
            "sha256",
            "sha512"
        )]
        [string]$Algorithm = "sha256"
    )
    
    begin {
        # if ($item -and $bytes) {
        #     throw "cannot define bytes and item at the same time"
        # }
    }
    process {       
        switch ($Algorithm) {
            "sha256" {
                $Hash = [System.Security.Cryptography.SHA256]::Create()
            }
            "sha512" {
                $Hash = [System.Security.Cryptography.SHA256]::Create()
            }
            default {
                throw "algorithm '$_' is not set up"
            }
        }

        switch ($PSCmdlet.ParameterSetName) {
            "Item" {
                try {
                    if(!(test-path $Item.FullName)){
                        throw "file '$($Item.FullName)' does not exist"
                    }
                    $fileStream = $Item.OpenRead()
                    $hashvalue = $Hash.ComputeHash($fileStream)
                } finally {
                    $fileStream.Close()
                }
            }
            "Bytes" {
                $hashvalue = $Hash.ComputeHash($Bytes)
            }
        }
        # if ($null -ne $bytes) {
        #     $hashvalue = $Hash.ComputeHash($Bytes)
        # } else {
        #     #open read file, create hash from contents
        #     try {
        #         $fileStream = $Item.OpenRead()
                
        #         $hashvalue = $Hash.ComputeHash($fileStream)
        #     } finally {
        #         $fileStream.Close()
        #     }
        # }

        #generate hash string
        $strbuilder = [System.Text.StringBuilder]::new()
        $strbuilder.Append($Algorithm) | Out-Null
        $strbuilder.append(":") | Out-Null
        $hashvalue.ForEach{
            $strbuilder.Append(([byte]$_).ToString("x2")) | Out-Null
        }
        return $strbuilder.ToString()
    }
    end {   
    }
}