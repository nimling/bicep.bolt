function Add-DeployWhatifresult {
    [CmdletBinding()]
    param (
        $inputObject,
        [string]$Name,
        [string]$Path,
        [ValidateSet(
            "ResourceGroup",
            "Subscription"
        )]
        [string]$Scope
    )
    
    begin {
        <#
        class WhatifResult{
            [string]$Name
            [string]$Path
            [string]$scope
            [string]$resourceId
            [string]$changeType
            [string]$status
        }
        #>
    }
    
    process {
        if($inputObject -is [Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.Deployments.PSWhatIfOperationResult])
        {
            [Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.Deployments.PSWhatIfOperationResult]$inputObject = $inputObject
            foreach($change in $inputObject.Changes)
            {
                #its easier to deal with pscustomobject whan whatever the over enginered shitstack newtonsoft json is doing...
                $_change = $change|convertto-json|convertfrom-json

                $whatifobject = [WhatifResult]::new()
                $whatifobject.Name = $Name
                $whatifobject.path = $Path
                $whatifobject.scope = $Scope
                $whatifobject.RelativeId = $_change.RelativeResourceId
                $whatifobject.changeType = $_change.ChangeType
                $whatifobject.status = $inputObject.Status
                switch($_change.ChangeType){
                    "Create"{
                        foreach($property in $change.after.psobject.properties){
                            $whatifProp = [whatifResultProperty]::new()
                            $whatifProp.name = $property.Name
                            if($value -is [pscustomobject]){
                                
                            }
                            $whatifProp.newvalue = $property.value
                        }
                    }
                }
            }
            
            $global:whatifResult.add()
        }
    }
    
    end {
        
    }
}

<#
subscription ->
    + relativeId
        location
        type
        tags     : 

    + relativeid
        -> location

#>