Describe "Get-DeploymentTestResult"{
    BeforeAll {
        $testResult = @(
            [PSCustomObject]@{
                code = "test1"
                message = "test1"
            },
            [PSCustomObject]@{
                code = "test2"
                message = "test2"
            }
        )
    }
    It "should return false if test result is empty" -Tag 'unit'{
        $testResult = @()
        $result = Get-DeploymentTestResult -TestResult $testResult -WarningAction SilentlyContinue
        $result | Should -Be $false
    }
    It "should return false if test result is not empty" -Tag 'unit' {
        $result = Get-DeploymentTestResult -TestResult $testResult -WarningAction SilentlyContinue
        $result | Should -Be $true
    }
    it "should write warning if test result is not empty" -Tag 'unit' {
        $result = Get-DeploymentTestResult -TestResult $testResult -WarningVariable test -WarningAction SilentlyContinue
        $test | Should -Not -BeNullOrEmpty
        # $result | Should -Be $true
    }
}