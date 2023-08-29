function Test-BoltConfigReleaseTrigger {
    [CmdletBinding()]
    param (
        [boltConfigReleaseTrigger]$Triggers
    )
    
    begin {
        $AllTests = @(
            "paramCaseModified",
            "paramAddedWithoutDefaultValue",
            "paramRemoved",
            "paramTypeModified",
            "paramAllowedValueModified",
            "paramDefaultValueModified",
            "resourceAdded",
            "resourceRemoved",
            "resourceApiVersionModified",
            "resourcePropertiesAdded",
            "resourcePropertiesRemoved",
            "resourcePropertiesModified",
            "outputsAdded",
            "outputsRemoved",
            "outputsModified",
            "moduleModified"
        )
    }
    
    process {
        $used = @()
        @(
            $triggers.static.update,
            $triggers.semantic.major,
            $triggers.semantic.minor,
            $triggers.semantic.patch
        )|ForEach-Object{
            $used += $_
        }
        $used|ForEach-Object{
            Write-boltlog "Used test: $_" -level 'dev'
        }

        $unused = $AllTests | Where-Object { $used -notcontains $_ }
        if($unused){
            Write-BoltLog "There are release tests that are unused. this might make the release process less robust. please advice if you want to include them." -level 'warning'
            $unused|ForEach-Object {
                Write-BoltLog "Unused test: $_" -level 'warning'
            }
        }
    }
    
    end {
        
    }
}