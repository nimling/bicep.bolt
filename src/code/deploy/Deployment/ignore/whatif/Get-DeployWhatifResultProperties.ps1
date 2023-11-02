function Get-DeployWhatifResultProperties {
    [CmdletBinding()]
    [outputtype([whatifResultProperty])]
    param (
        [parameter(ValueFromPipeline)]
        [pscustomobject]$properties,
        [string]$parent = ""
    )
    
    begin {
        
    }
    
    process {
        foreach($item in $properties.psobject.properties){
            if($item -is [pscustomobject]){
                $item|Get-DeployWhatifResultProperties
                $whatifProp = [whatifResultProperty]::new()
                $whatifProp.name = $item.Name
                $whatifProp.parent = $parent
                $whatifProp.newvalue = $item.value
            }
            else{
                $whatifProp = [whatifResultProperty]::new()
                $whatifProp.name = $item.Name
                $whatifProp.parent = $parent
                $whatifProp.newvalue = $item.value
                Write-output $whatifProp
            }
        }
    }
    
    end {
        
    }
}