Describe "Test-Ternary" {
    InModuleScope 'BoltRules' {
        BeforeDiscovery {
            $TestCases = @(
                @{
                    Name        = "Simple Ternary"
                    ScriptBlock = { $tru ? $false : $true }
                    ShouldBe    = 'if($tru){$false}else{$true}'
                }
                @{
                    Name        = "Simple Ternary with multiple lines"
                    ScriptBlock = {
                        $tru ? 
                        $false : 
                        $true
                    }
                    ShouldBe    = (@(
                        "if(`$tru){",
                        '$false',
                        "}else{",
                        '$true',
                        "}"
                    ) -join [System.Environment]::NewLine)
                }
            )
        }
        it "should trigger on <name>" -TestCases $TestCases {
            param(
                $Name,
                $ScriptBlock,
                $ShouldBe
            )
            $results = Test-Ternary -ScriptBlockAst $ScriptBlock.Ast
            $results | Should -Not -BeNullOrEmpty
            $results | should -BeOfType 'Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord'
        }
    
        it "should suggest you use if with example: <name>" -TestCases $TestCases {
            param(
                $Name,
                $ScriptBlock,
                $ShouldBe
            )
            $results = Test-Ternary -ScriptBlockAst $ScriptBlock.Ast
            $results.SuggestedCorrections.Text | Should -Be $ShouldBe
        }
    }
}