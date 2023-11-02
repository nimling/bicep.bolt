Describe "Get-Deployment" {
    BeforeAll {
        $SubscriptionId = "/subscriptions/00000000-0000-0000-0000-000000000000"
        $ResourcegroupNameMock = "rg"
        $ResourceGroupId = "$SubscriptionId/resourceGroups/$ResourcegroupName"
        $deploymentSuffix = "providers/Microsoft.Resources/deployments"
        $correlationids = @(
            "00000000-0000-0000-0000-000000000000",
            "00000000-0000-0000-0000-000000000001"
        )

        $mockData = @(
            [PSCustomObject]@{
                Id                = "$ResourceGroupId/$deploymentSuffix/deployment"
                CorrelationId     = "00000000-0000-0000-0000-000000000000"
                ResourceGroupName = $ResourcegroupNameMock
            },
            [PSCustomObject]@{
                Id                = "$ResourceGroupId/$deploymentSuffix/deployment-child"
                CorrelationId     = "00000000-0000-0000-0000-000000000000"
                ResourceGroupName = $ResourcegroupNameMock
            }
            #another deployement with same correlation id
            [PSCustomObject]@{
                Id                = "$ResourceGroupId/$deploymentSuffix/deployment2"
                CorrelationId     = "00000000-0000-0000-0000-000000000000"
                ResourceGroupName = $ResourcegroupNameMock
            }
            #another deployement with differnt correlation id
            [PSCustomObject]@{
                Id                = "$ResourceGroupId/$deploymentSuffix/deployment3"
                CorrelationId     = "00000000-0000-0000-0000-000000000001"
                ResourceGroupName = $ResourcegroupNameMock
            }
        )
        Mock Get-AzResourceGroupDeployment -MockWith { 
            param(
                [string]$id,
                [string]$ResourceGroupName
            )
            $items = $mockData

            if ($id) {
                return $items | Where-Object { $_.Id -eq $id } | select -first 1
            }
            return $items | Where-Object { $_.ResourceGroupName -eq $ResourceGroupName }
        }

        Mock Get-AzSubscriptionDeployment -MockWith { 
            param(
                [string]$id
            )
            $items = $mockData

            if ($id) {
                return $items | Where-Object { $_.Id -eq $id } | select -first 1
            }
            return $items
        }
    }
    context 'unit' -Tag unit{
        BeforeDiscovery {
            $testcases = @(
                @{ Context = "ResourceGroup" }
                @{ Context = "Subscription" }
            )
        }
        it "should return the asked for <context> deployment when scope is 'current'"  -TestCases $testcases {
            param($Context)
            $deployment = Get-Deployment -Id "$ResourceGroupId/$deploymentSuffix/deployment" -Context $Context
            $deployment | Should -Not -BeNullOrEmpty
        }
    
        it "should return <context> deployment with children if scope is 'All'"  -TestCases $testcases {
            param($Context)
            $deployment = Get-Deployment -Id "$ResourceGroupId/$deploymentSuffix/deployment" -Context $Context -Scope 'All'
            $deployment | Should -Not -BeNullOrEmpty
            $deployment | Should -HaveCount 3
        }
    
        it "should return <context> deployment with only children if scope is 'Children'" -TestCases $testcases {
            param($Context)
            $deployment = Get-Deployment -Id "$ResourceGroupId/$deploymentSuffix/deployment" -Context $Context -Scope 'Children'
            $deployment | Should -Not -BeNullOrEmpty
            $deployment | Should -HaveCount 2
        }
    
        it "should throw if input scope is not part of validateset <context>" -TestCases $testcases {
            param($Context)
            { Get-Deployment -Id "$ResourceGroupId/$deploymentSuffix/deployment" -Context $Context -Scope 'other' } | Should -Throw 
        }
    }
}
