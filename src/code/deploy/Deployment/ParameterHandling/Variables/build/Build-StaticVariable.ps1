function Build-StaticVariable {
    [CmdletBinding()]
    param (
        [envVariable_static]$Variable
    )
    
    begin {
        
    }
    
    process {
        if($Variable.value -is [psobject]){
            $Variable.value = $Variable.value| ConvertTo-Hashtable
        }
        return $Variable.value
    }
    
    end {
        
    }
}