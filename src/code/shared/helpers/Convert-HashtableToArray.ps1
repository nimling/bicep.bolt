<#
.SYNOPSIS
Generates a list of all the properties inside a hashtable, recursively

.PARAMETER InputItem
item to convert

.PARAMETER address
address of the item. root is "". only defined if you you have a sopecific path you want to start at.


.PARAMETER ExcludeKeys
keys to exclude from the output. can be a string or an array of strings. if the key contains the string, it will be excluded. case sensitive.

.PARAMETER excludeTypes
types to exclude from the output. can be a string or an array of strings. if the type matches, it will be excluded. case sensitive. items inside the type will still be present

.EXAMPLE
gc somejson.json|ConvertFrom-Json -AsHashtable|Convert-HashtableToArray
#>
function Convert-HashtableToArray {
    [CmdletBinding()]
    [OutputType([ordered])]
    param (
        [parameter(ValueFromPipeline)]
        $InputItem,
        [string]$address = "",
        [string[]]$ExcludeKeys = @(),
        [ValidateSet("object", "array")]
        [string[]]$excludeTypes
    )
    process {
        $Output = [ordered]@{}

        #on Arrays
        if ($InputItem -is [array]) {
            $Output[$address] = $InputItem
            for ($i = 0; $i -lt $_.value.Count; $i++) {
                $ArrAddress = "$address[$i]"
                # Write-Verbose "$ArrAddress is a $($InputItem[$i].gettype())"
                $Output[$ArrAddress] += Convert-HashtableToArray -InputItem $InputItem[$i] -address $ArrAddress
            }
        }
        #on Hashtables (or ordered hashtables) 
        elseif ($InputItem -is [System.Collections.ICollection]) {
            if ($address -ne "") {
                $Output[$address] = $inputItem
            }
            foreach ($item in $InputItem.GetEnumerator()) {
                $ThisAddress = (@($address, $item.key) | Where-Object { ![string]::IsNullOrEmpty($_) }) -join "."
                switch ($item) {
                    { $_.value -is [System.Collections.ICollection] } {
                        # Write-Verbose "$ThisAddress is a hashtable"
                        $Output += Convert-HashtableToArray -InputItem $Item.value -address $ThisAddress
                    }
                    { $_.value -is [array] } {
                        for ($i = 0; $i -lt $_.value.Count; $i++) {
                            $ArrAddress = "$ThisAddress[$i]"
                            $Output += Convert-HashtableToArray -address $ArrAddress -InputItem $_.value[$i]
                        }
                    }
                    default {
                        $Output[$ThisAddress] = $item.Value
                    }
                }
            }
        } 
        #on everything else 
        #TODO: Add other types or generalized 
        else {
            # Write-Verbose "$address is a $($InputItem.gettype())"
            $Output[$address] = $item
        }
        $keys = $Output.Keys|ForEach-Object{$_}
        foreach($key in $keys){
            $match = $ExcludeKeys|Where-Object{$key -like "$_"}
            if($match){
                # Write-Verbose "removing key $key`: $match"
                $Output.Remove($key)
            }
        }
        $values = $Output.GetEnumerator()|ForEach-Object{$_}
        foreach($val in $values){
            # Write-Verbose "$($val.Key) is a $($val.Value.gettype())"
            if($excludeTypes -eq 'object'){
                if($val.value -is [hashtable] -or $val.value -is [ordered]){
                    # Write-Verbose "!removing value $($val.Key)`: $match"
                    $Output.Remove($val.Key)
                }
            }
            if($excludeTypes -eq 'array'){
                if($val.value -is [array]){
                    # Write-Verbose "!removing value $($val.Key)`: $match"
                    $Output.Remove($val.Key)
                }
            }
        }
        return $Output
    }
}