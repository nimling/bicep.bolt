Describe "Remove-VariableReferenceTokens" -Tag 'unit' {
    BeforeAll{
        Mock Test-ValueIsVariableReference {param($value) return ($value -like "(*)") }
    }
    It "should remove the variable reference tokens from a string" {
        $result = Remove-VariableReferenceToken -Value '(test)'
        $result | Should -Be 'test'
    }
    It "should not remove the variable reference tokens from a string that does not have them" {
        $result = Remove-VariableReferenceToken -Value 'test'
        $result | Should -Be 'test'
    }
}