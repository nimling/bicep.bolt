function Reset-BaduVariableUse {
    [CmdletBinding()]
    param ()
    New-Variable -Scope global -Name _baduVariableUse -Value @() -Force
}