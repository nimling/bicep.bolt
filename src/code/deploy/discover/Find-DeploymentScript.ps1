using namespace System.IO
<#
.SYNOPSIS
Finds deploymentScripts 

.NOTES
General notes
#>
function Find-DeploymentItem {
    [CmdletBinding()]
    [OutputType([deploymentItem])]
    param (
        [string]$RelativePath,
        [string]$Root
    )
    begin {
        Set-BaduLogContext -Tag 'Item Discovery' -IsSubFunction
        $DeployConfig = Get-DeployConfig
        $ScopedEnvironmentName = ($DeployConfig.environments | Where-Object { $_.isScoped }).name
    }
    process {
        Write-BaduVerb "Discovering deployment items in $RelativePath"
        $path = Join-Path -Path $Root -ChildPath $RelativePath
        $path = [Path]::GetFullPath($path)
        $All = $false
        if($ScopedEnvironmentName){
            if($RelativePath -like "*.$ScopedEnvironmentName/*"){
                $All = $true
            }
        }

        $files = Get-ChildItem -Path $path -File|?{$_.Extension -eq ".bicep" -or $_.Extension -eq ".json" }
        $Files = $Files|Select-ByEnvironment
        Write-BaduDebug "found $($files.count) files in $RelativePath"


        $folders = Get-ChildItem -Path $path -Directory
        $folders|Select-ByEnvironment|%{
            Find-DeploymentItem -RelativePath (join-path $RelativePath $_.name) -Root $Root
        }
        #Filter items if scoped env is active
        # if($ScopedEnv)
        # {
        #     #check if relative path is within env
        #     $files = $files | Where-Object { 
        #         $rel = [path]::GetRelativePath($Root, $_.FullName);
        #         $rel -like "*.$ScopedEnv.*" -or $rel -like "*.$ScopedEnv/" 
        #     }
        #     Write-BaduDebug "found $($files.count) files in $RelativePath after filtering for environment"
        # }


        # #Check files
        #Filter away any files not within env


        # Get-ChildItem 
        #find Files
    }
    end {
    }
}