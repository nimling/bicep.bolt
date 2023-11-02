function Remove-VariableReferenceToken {
    [CmdletBinding()]
    param (
        [string]$Value
    )
    
    if(Test-ValueIsVariableReference -value $Value)
    {
        $Value = $Value.Substring(1, $Value.Length - 2)
    }
    return $Value
}