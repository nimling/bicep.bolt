Describe 'Build-IdentityVariable' {
    Context unit -tag unit {
        BeforeAll {
            $mockData = @{
                User    = @{
                    Ip = "0.0.0.0"
                    Id          = "00000000-0000-0000-0000-000000000000"
                    DisplayName = "User"
                    Type        = "User"
                }
                Unkonwn = @{
                    Ip = "0.0.0.0"
                    Id          = "00000000-0000-0000-0000-000000000000"
                    DisplayName = "User"
                    Type        = "Unknown"
                }
            }
    
            mock get-azcontext -MockWith {
                return @{
                    account = $mockdata.$global:_pesterAzContext
                }
            }
    
            Mock Get-AzADUser -MockWith { 
                param(
                    [string]$Filter
                )
                if ($global:_pesterAzContext -eq 'User') {
                    return $mockdata.$global:_pesterAzContext
                }
            }

            Mock Invoke-RestMethod -MockWith {
                param($Uri)
                if ($Uri -eq 'http://ipinfo.io/json') {
                    return @{
                        ip = "0.0.0.0"
                    }
                }
            }
        }
        BeforeDiscovery {
            $properties = @(
                @{
                    val     = 'PrincipalId'
                    val_key = "Id"
                }
                @{
                    val     = 'Name'
                    val_key = "DisplayName"
                }
                @{
                    val     = 'Type'
                    val_key = "Type"
                }
                @{
                    val     = 'ip'
                    val_key = "ip"
                }
            )
            $testcases = @('user') | ForEach-Object {
                $typ = $_
                $properties | ForEach-Object {
                    @{
                        ident_type = $typ
                        val        = $_.val
                        val_key    = $_.val_key
                    }
                }
            }
        }
        It "should return '<val>' from <ident_type> type identity" -TestCases $testcases {
            param(
                [string]$ident_type,
                [string]$val_key,
                [string]$val
            )
            $global:_pesterAzContext = $ident_type
            $variable = [envvariable_identity]@{
                source      = "pester"
                description = "pester test val"
                value       = $val
            }
    
            $result = Build-IdentityVariable -variable $variable
            $result | should -Not -BeNullOrEmpty
            $result | Should -Be $mockdata.$ident_type.$val_key
        }
    
        it 'Should throw if identity type is not recognised' {
            $variable = [envvariable_identity]@{
                source      = "pester"
                description = "pester test val"
                value       = 'PrincipalId'
            }
            $global:_pesterAzContext = 'Unknown'
            { Build-IdentityVariable -variable $variable } | Should -Throw
        }
    
        it "should throw if unknown value is requested" {
            $variable = [envvariable_identity]@{
                source      = "pester"
                description = "pester test val"
                value       = 'Unknown'
            }
            $global:_pesterAzContext = 'User'
            { Build-IdentityVariable -variable $variable } | Should -Throw
        }
    }
}