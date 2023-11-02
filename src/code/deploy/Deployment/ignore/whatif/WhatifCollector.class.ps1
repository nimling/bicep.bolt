using namespace System.Collections.Generic
class whatifResultProperty{
    [string]$name
    [string]$parent
    $oldValue
    $newvalue
}
class WhatifResult{
    [string]$Name
    [string]$Path
    [string]$parent
    [string]$scope
    [string]$RelativeId
    [string]$changeType
    [string]$status
    [hashtable]$Properties
}



class WhatIfCollector {
    [list[WhatifResult]]$results = [list[WhatifResult]]::new()
    Add([WhatifResult]$Result){
        $this.results.Add($Result)
    }
}