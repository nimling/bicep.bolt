function Write-ModuleUpdateStatus {
    [CmdletBinding()]
    param (
        [parameter(Mandatory,ValueFromPipeline)]
        [ModuleUpdateTest]$Test
    )
    
    begin {
        $defaultLogLevel = "Info"
    }
    
    process {
        # $global:t = 
        # Write-BoltLog "$($Test.type): $($Test.reasons.count)" -level $defaultLogLevel
        #foreach in dictionary
        Foreach($ReasonList in $Test.reasons.GetEnumerator()){
            $TestType = $Test.type.ToString().toupper()
            $ReasonListName = $ReasonList.key
            #foreach in list
            Foreach($Reason in $ReasonList.Value)
            {
                # Write-BoltLog ($Reason| ConvertTo-Json -Depth 3)
                $ReasonInfo = (@("$($Reason.key)", $($Reason.detail)) | Where-Object { $_ }) -join "."
                switch ($Reason.type) {
                    ([ModuleUpdateType]::added) {
                        Write-BoltLog "$($TestType):    add '$reasonListName'-> $reasonInfo $($Reason.newValue)" -level $defaultLogLevel
                    }
                    ([ModuleUpdateType]::removed) {
                        Write-BoltLog "$($TestType): remove '$reasonListName'-> $reasonInfo $($Reason.oldValue)" -level $defaultLogLevel
                    }
                    ([ModuleUpdateType]::modified) {
                        Write-BoltLog "$($TestType): modify '$reasonListName'-> $reasonInfo old: $($reason.oldValue) new: $($reason.newValue)" -level $defaultLogLevel
                    }
                    ([ModuleUpdateType]::other) {
                        Write-BoltLog "$($TestType):  other '$reasonListName'-> $reasonInfo $($reason.message)" -level $defaultLogLevel
                    }
                    default{
                        Write-BoltLog "$($TestType):default '$reasonListName'-> $reasonInfo $($reason.message)" -level $defaultLogLevel
                    }
                }
            }
        }
    }
    
    end {
        
    }
}