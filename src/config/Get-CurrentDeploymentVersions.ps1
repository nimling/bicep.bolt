using namespace System.Collections.Generic
function Get-CurrentDeploymentVersions {
    [CmdletBinding()]
    param (
        [ValidateNotNullOrEmpty()]
        [System.Collections.Generic.List[boltConfigRelease]]$Versions,

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
        $ret = $Versions|where{$_.name -eq $Branch}
        if(!$ret){
            throw "No versioning config found for branch '$Branch'. avalible: $($Versions.name |select -Unique)"
        }
        return $ret
    }
    
    end {
        
    }
}