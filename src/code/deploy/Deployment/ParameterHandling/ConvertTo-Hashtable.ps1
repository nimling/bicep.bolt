function ConvertTo-Hashtable {
    [CmdletBinding()]
    [outputtype([hashtable])]
    param (
        [parameter(ValueFromPipeline)]
        [psobject]$InputItem
    )
    
    begin {
        $OutValue = @{}
    }
    
    process {
        $InputItem.psobject.properties | ForEach-Object {
            $val = $_.value
            $key = $_.name
            if($val -is [psobject]){
                Write-BaduVerb "$key is psobject, converting to hashtable"
                $val = $val| ConvertTo-Hashtable
            }
            $OutValue.$key = $val
        }
    }
    
    end {
        return $OutValue
    }
}