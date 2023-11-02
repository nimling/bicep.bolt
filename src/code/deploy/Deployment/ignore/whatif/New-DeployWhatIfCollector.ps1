function New-WhatIfCollector {
    [CmdletBinding()]
    param (
        
    )
    
    begin {
        
    }
    
    process {
        $global:whatifResult = [WhatIfCollector]::new()
    }
    
    end {
        
    }
}