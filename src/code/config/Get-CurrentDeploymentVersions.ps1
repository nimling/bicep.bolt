using namespace System.Collections.Generic
function Get-CurrentDeploymentVersion {
    [CmdletBinding()]
    param (
        [ValidateNotNullOrEmpty()]
        [boltConfigRelease[]]$Versions,

        [string]$Branch,

        [ValidateNotNullOrEmpty()]
        [string]$DefaultBranch
    )

    begin {
        if(!$branch -and !$DefaultBranch){
            throw "Either branch or default branch must be specified"
        }elseif(!$Branch){
            $Branch = $DefaultBranch
        }
    }

    process {
        $ret = $Versions|Where-Object{$_.name -eq $Branch}
        if(!$ret){
            throw "No versioning config found for branch '$Branch'. avalible: $($Versions.name |Select-Object -Unique)"
        }
        return $ret
    }

    end {
    }
}