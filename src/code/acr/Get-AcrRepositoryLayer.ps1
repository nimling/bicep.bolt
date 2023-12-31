using namespace System.Collections.Generic
<#
.SYNOPSIS
Gets files from a acr repository

.PARAMETER Repository
PSTagList that represents the repository contents

.PARAMETER Tag
Tag to get info from

.PARAMETER AssumeCount
assume minimum amount of items

.PARAMETER IncludeContent
downloads items to temp folder and adds the path to the object

.EXAMPLE
An example

.NOTES
General notes
#>
function Get-AcrRepositoryLayer {
    [CmdletBinding()]
    [Outputtype([AcrRepositoryLayer])]
    param (
        [parameter(mandatory)]
        [Microsoft.Azure.Commands.ContainerRegistry.Models.PSTagList]$Repository,
        [string]$Tag,
        [int]$AssumeCount = 0,

        # [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', Justification = 'well it is used..so.. i dunno?')]
        [switch]$IncludeContent
    )
    begin {}
    process {
        $Call = Invoke-AcrCall -Repository $Repository -Path "manifests/$Tag" -Method GET -ea Stop
        if($call.layers.count -eq 0){
            throw "Got no layers in acr repo. this is not supported."
        }
        if($AssumeCount -gt 0){
            if($Call.layers.count -gt $assumeCount){
                throw "Got more than $assumecount layers in acr repo. this is not supported."
            }
        }

        foreach($Layer in $Call.layers|Where-Object{$_}){
            $out = [AcrRepositoryLayer]@{
                repository = $Repository.ImageName
                tag        = $tag
                digest     = $Layer.digest
                size       = $Layer.size
                mediaType  = $Layer.mediaType
                contentPath = ""
            }
            # $Layer.digest = $Layer.digest.replace("sha256:","")
            if($IncludeContent -eq $true){
                # Write-BoltLog "Downloading layer $($_.digest) from $Repository"
                $tempFilePath = join-path $env:TEMP $Layer.digest.replace(":","_")
                # $tempFile = New-Item -Path $Path -ItemType File -Force
                Write-BoltLog "Downloading layer $($Layer.digest) from $($Repository.ImageName):$tag to $tempFilePath" -level verbose
                Invoke-AcrCall -Repository $Repository -Path "blobs/$($Layer.digest)" -Method GET -ContentType "application/octet-stream" -OutFile $tempFilePath|out-null
                $out.ContentPath = $tempFilePath
            }
            Write-Output $out
        }
        # $Call.layers |?{$_}| % {
        #     $out = [AcrRepositoryLayer]@{
        #         repository = $Repository.ImageName
        #         tag        = $tag
        #         digest     = $_.digest
        #         size       = $_.size
        #         mediaType  = $_.mediaType
        #         contentPath = ""
        #     }
        #     # Write-BoltLog ($_|ConvertTo-Json -Depth 10 -Compress)
        #     # $contentPath = ""
        #     if($IncludeContent -eq $true){
        #         # Write-BoltLog "Downloading layer $($_.digest) from $Repository"
        #         $tempFilePath = join-path $env:TEMP $_.digest.replace(":","_")
        #         # $tempFile = New-Item -Path $Path -ItemType File -Force
        #         Write-BoltLog "Downloading layer $($_.digest) from $($Repository.ImageName):$tag to $tempFilePath" -level verbose
        #         Invoke-AcrCall -Repository $Repository -Path "blobs/$($_.digest)" -Method GET -ContentType "application/octet-stream" -OutFile $tempFilePath|out-null
        #         $out.ContentPath = $tempFilePath
        #     }
        #     Write-Output $out
        # }
    }
    
    end {
        # $OutList|%{
        #     Write-Output $_
        # }
        # return $OutList
    }
}