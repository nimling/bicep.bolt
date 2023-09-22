Describe "Get-BicepVersion" {
    BeforeDiscovery {
        $cases = @(
            @{
                name = 'All'
            }
            @{
                name = 'Latest'
            }
            @{
                name = 'Lowest'
            }
        )
    }
    BeforeAll {
        $global:pester_Get_BicepVersion = @{}
        
        #normal request but im caching the result for faster tests
        Mock -CommandName 'Invoke-WebRequest' {
            param(
                $uri
            )

            if ($global:pester_Get_BicepVersion.ContainsKey($uri)) {
                return $global:pester_Get_BicepVersion[$uri]
            }
            try {
                $cli = [System.Net.WebClient]::new()
                $ret = @{
                    content = $cli.DownloadString($uri)
                }
                $global:pester_Get_BicepVersion[$uri] = $ret
                return $ret

            } catch {
                Write-Output "Status Code : $($_.Exception.Response.StatusCode.Value__)"
            }
        }
    }
    It "should return string (arg <name>)" -TestCases $cases {
        $result = Get-BicepVersion -What Latest
        $result | Should -BeOfType System.String
    }

    it "should return version (arg <name>)" -TestCases $cases {
        $result = Get-BicepVersion -What Latest
        $result | Should -Match "^[0-9]+\.[0-9]+\.[0-9]+$"
    }
}