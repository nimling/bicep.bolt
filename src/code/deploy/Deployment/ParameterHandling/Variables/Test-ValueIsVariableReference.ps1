function Test-ValueIsVariableReference {
    [CmdletBinding()]
    param (
        $value
    )

    
    if($value -isnot [string])
    {
        return $false
    }

    return @(Get-VariableReferenceInString -String $value).Count -gt 0
}