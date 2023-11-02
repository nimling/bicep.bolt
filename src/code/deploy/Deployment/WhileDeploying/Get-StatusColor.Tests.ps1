Describe "Get-StatusColor" -Tag 'unit' {
    BeforeDiscovery {
        $TestCases = @(
            #use System.Drawing.KnownColor for colors
            @{provisioningState = "Accepted"; expected = [System.Drawing.KnownColor]::DeepSkyBlue }
            @{provisioningState = "Running"; expected = [System.Drawing.KnownColor]::DeepSkyBlue }
            @{provisioningState = "Succeeded"; expected = [System.Drawing.KnownColor]::Lime }
            @{provisioningState = "Failed"; expected = [System.Drawing.KnownColor]::Crimson }
            @{provisioningState = "random"; expected = [System.Drawing.KnownColor]::DeepSkyBlue }
        )
    }
    It "should return <expected> for the provisioning state <provisioningState>" -TestCases $TestCases {
        param(
            [string]$provisioningState, 
            [System.Drawing.KnownColor]$expected
        )

        $color = [System.Drawing.color]::FromName($expected.ToString())
        $Use_color = "`e[38;2;{0};{1};{2}m" -f $Color.R, $Color.G, $Color.B

        $result = Get-StatusColor -provisioningState $provisioningState
        $result | Should -Be $Use_color
    }
}