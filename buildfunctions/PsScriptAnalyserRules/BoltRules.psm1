gci "$PSScriptRoot/rules/*.ps1" -Exclude "*tests*"|%{
    # Write-host "$_"
    . $_.FullName
}

Export-ModuleMember Measure*
Export-ModuleMember Test*


# {
#     $k = $tru ? $false : $true
# }.Ast
# $result = [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord[]]@{
#     "Message"  = "This is a sample rule"
#     "Extent"   = $ast.Extent
#     "RuleName" = $PSCmdlet.MyInvocation.InvocationName
#     "Severity" = "Warning"
# }