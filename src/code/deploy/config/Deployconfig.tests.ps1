using namespace System.Collections.Generic
Describe "deployconfig" -Tag unit {
    context "new - no parameters" {
        it "should init without errors" {
            {[deployconfig]::new()} | should -Not -Throw # -Be $null
        }

        it "should set default values"{
            $deployConfig = [deployconfig]::new()
            $deployConfig.tenant | should -Be $null
            $deployConfig.deployLocation | should -Be $null
            $deployConfig.workingPath | should -Be $null
            $deployConfig.InstanceId | should -Be 0

            $deployConfig.environments | should -HaveCount 0
            $null -ne $deployConfig.environments | should -BeTrue
            $deployConfig.dry | should -not -BeNullOrEmpty
            $deployConfig.bicep | should -not -BenullOrEmpty
            $deployConfig.dev | should -not -BenullOrEmpty

        }
    }

    context "Initialisation - with parameters" {

    }

    context "Public Methods" {
        beforeAll {}

        context "getTenantId" {
            it "should throw if class does not have tenantId" {
                
                $deployConfig = [deployconfig]::new()
                { $deployConfig.getTenantId() } | should -Throw
            }

            it "should return tenantid" -TestCases @(
                @{
                    tenant = "nim.io"
                    id     = "ecabee7b-8606-4ae2-9f69-d63203bc23d5"
                }
                @{
                    tenant = "nimtech.no"
                    id     = "ecabee7b-8606-4ae2-9f69-d63203bc23d5"
                }
                @{
                    tenant = "samna.io"
                    id     = "ecabee7b-8606-4ae2-9f69-d63203bc23d5"
                }
                @{
                    tenant = "ecabee7b-8606-4ae2-9f69-d63203bc23d5"
                    id     = "ecabee7b-8606-4ae2-9f69-d63203bc23d5"
                }
            ) {
                param(
                    [string]$tenant,
                    [string]$id
                )
                $deployConfig = [deployconfig]::new()
                $deployConfig.tenant = $tenant
                $deployConfig.getTenantId() | should -Be $id
            }

            it "should throw if a non tenant id is provided" {
                $deployConfig = [deployconfig]::new()
                $deployConfig.tenant = "nontenatid"
                { $deployConfig.getTenantId() } | should -Throw
            }
        }

    }
}