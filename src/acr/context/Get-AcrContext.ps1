function Get-AcrContext {
    [CmdletBinding()]
    param ()
    
    begin {
        
    }
    
    process {
        if(!$global:_acr){
            throw "Acr context not set. Please run Set-AcrContext before, not using the -Registry parameter"
        }
        return $global:_acr
    }
    
    end {
        
    }
}