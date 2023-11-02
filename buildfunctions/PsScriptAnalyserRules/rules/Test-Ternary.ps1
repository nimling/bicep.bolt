<#
.SYNOPSIS
    Check for ternary expressions
.DESCRIPTION
    This rule checks for ternary expressions
.EXAMPLE
    Test-Ternary -ScriptBlockAst $ScriptBlockAst
.INPUTS
    [System.Management.Automation.Language.ScriptBlockAst]
.OUTPUTS
    [Microsoft.Windows.Powershell.ScriptAnalyzer.Generic.DiagnosticRecord[]]
.NOTES
#>
function Test-Ternary {
    [CmdletBinding()]
    [OutputType([Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord[]])]
    Param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.Language.ScriptBlockAst]
        $ScriptBlockAst
    )
    begin {}
    process {
        $results = @()
        try {
            $ScriptBlockAst.FindAll({
                    param ([System.Management.Automation.Language.Ast]$Ast)
                    $Ast -is [System.Management.Automation.Language.TernaryExpressionAst]
                }, $true) | ForEach-Object {

                $corrections = [System.Collections.ObjectModel.Collection[Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.CorrectionExtent]]::new()
                if ($_.Extent.StartLineNumber -eq $_.Extent.EndLineNumber) {
                    $Message = "Avoid using ternary expressions. use if/else instead"
                    $corrections.Add( [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.CorrectionExtent]::new(
                            $_.Extent.StartLineNumber,
                            $_.Extent.EndLineNumber,
                            $_.Extent.StartColumnNumber,
                            $_.Extent.EndColumnNumber,
                            "if($($_.Condition)){$($_.IfTrue)}else{$($_.IfFalse)}",
                            $_.Extent.File
                        ))
                } else {
                    $Message = "Avoid using ternary expressions. use if/else instead - Multiline"
                    $fix = @(
                        "if($($_.Condition)){",
                        $_.IfTrue,
                        "}else{",
                        $_.IfFalse,
                        "}"
                    )
                    
                    $corrections.Add( [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.CorrectionExtent]::new(
                            $_.Extent.StartLineNumber,
                            $_.Extent.EndLineNumber,
                            $_.Extent.StartColumnNumber,
                            $_.Extent.EndColumnNumber,
                            ($fix -join [System.Environment]::NewLine),
                            $_.Extent.File
                        ))

                }
                $results += [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord]@{
                    "Message"            = "Avoid using ternary expressions. use if/else instead"
                    "Extent"             = $_.Extent
                    "RuleName"           = $PSCmdlet.MyInvocation.InvocationName
                    "Severity"           = "Warning"
                    SuggestedCorrections = $corrections
                }
            }
        } catch {
            $PSCmdlet.ThrowTerminatingError($PsItem)
        }
        return $results
    }
    end {
    }
}