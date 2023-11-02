Describe "Test-ValueIsVariableReference" -tag unit {
    BeforeAll{
        Mock Get-DeployConfig { return @{ dry = @{ style = '()' } } }
    }
    It "should return true if the value is a variable reference" {
        $result = Test-ValueIsVariableReference -Value '(test)'
        $result | Should -Be $true
    }
    It "should return false if the value is not a variable reference" {
        $result = Test-ValueIsVariableReference -Value 'test'
        $result | Should -Be $false
    }
}