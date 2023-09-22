Describe "Test-BicepInstallation" {
    BeforeAll{
    }
    
    It "should throw if bicep is not installed" {
        mock Get-Command {throw "not found"}
        {Test-BicepInstallation} | Should -Throw
    }

    It "should throw if bicep version is too low" {
        mock Get-Command {return @{}} -ParameterFilter { $Name -eq 'bicep' }
        mock bicep {return "Bicep CLI version 0.1.4 (1620479ac6)"}
        {Test-BicepInstallation -configVersion '1.1.1'} | Should -Throw
    }
}