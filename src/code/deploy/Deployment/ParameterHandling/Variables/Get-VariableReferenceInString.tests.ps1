Describe "Get-VariableReferenceInString" -tag 'unit' {
    context "unit" -Tag 'unit' {
        BeforeDiscovery {
            $Delimiters = @(
                @{
                    Name  = "Parenthesis"
                    Token = "()"
                }
                @{
                    Name  = "Curly Braces"
                    Token = "{}"
                }
                @{
                    Name  = "Chevrons"
                    Token = "<>"
                }
            )
        }
    
        BeforeEach{
            Mock Get-DeployConfig { return @{ dry = @{ style = $global:Delimiter } } }
        }

        it "should handle variable with double delimiter - <name>" -TestCases $Delimiters{
            param(
                [string]$name,
                [string]$token
            )
            $global:Delimiter = $token
            $Test = "((pester))"
            $result = "pester"

            $Test = $Test.Replace("(",$token[0]).Replace(")",$token[1])
            $res = Get-VariableReferenceInString -String $Test -Verbose:$false
            $res | Should -Be $result
        }

        it "should handle variable with double start delimiter - <name>" -TestCases $Delimiters{
            param(
                [string]$name,
                [string]$token
            )
            $global:Delimiter = $token
            $Test = "((pester)"
            $result = "pester"

            $Test = $Test.Replace("(",$token[0]).Replace(")",$token[1])
            $res = Get-VariableReferenceInString -String $Test -Verbose:$false
            $res | Should -Be $result
        }

        it "should handle variable in the middle of a string - <name>" -TestCases $Delimiters {
            param(
                [string]$name,
                [string]$token
            )
            $global:Delimiter = $token
            $Test = "somevalue-(pester)-someothervalue"
            $result = "pester"

            $Test = $Test.Replace("(",$token[0]).Replace(")",$token[1])
            $res = Get-VariableReferenceInString -String $Test -Verbose:$false
            $res | Should -Be $result
        }

        it "should handler just the variable - <name>" -TestCases $Delimiters {
            param(
                [string]$name,
                [string]$token
            )
            $global:Delimiter = $token
            $Test = "(pester)"
            $result = "pester"

            $Test = $Test.Replace("(",$token[0]).Replace(")",$token[1])
            $res = Get-VariableReferenceInString -String $Test -Verbose:$false
            $res | Should -Be $result
        }

        it "should handler just the variable with spaces - <name>" -TestCases $Delimiters {
            param(
                [string]$name,
                [string]$token
            )
            $global:Delimiter = $token
            $Test = "  (pester)  "
            $result = "pester"

            $Test = $Test.Replace("(",$token[0]).Replace(")",$token[1])
            $res = Get-VariableReferenceInString -String $Test -Verbose:$false
            $res | Should -Be $result
        }

        it "should return nothing if variable is not there" {
            $Test = "pester"
            $global:Delimiter = "()"
            $res = Get-VariableReferenceInString -String $Test -Verbose:$false

            $res | Should -Be $null
        }

        it "should return System.Text.RegularExpressions.Group"{

            $Test = "(pester)"
            $global:Delimiter = "()"

            $Test = $Test.Replace("(",$global:Delimiter[0]).Replace(")",$global:Delimiter[1])
            $res = Get-VariableReferenceInString -String $Test -Verbose:$false
            $res | Should -BeOfType [System.Text.RegularExpressions.Group]
        }
    }
}