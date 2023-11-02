Describe "Convertto-ParamObject"{
    BeforeDiscovery{


        #psobject representing a arm deployment parameter
        # $ParamObject = [pscustomobject]@{
        #     $schema = "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#"
        #     contentVersion = ""
        #     parameters = @{
        #         strtest = [pscustomobject]@{
        #             value = "test"
        #         }
        #         param2 = @{
        #             value = "test"
        #         }
        #     }
        # }


        # $Tests = 
    }
    # beforeAll{
    #     Mock Test-ValueIsVariableReference {param($value) return $value -like "(*)" }
    #     # Mock Get-DeployConfig {}
    # }
    # it "will return a hashtable"{
    #     $result = ConvertTo-ParamObject -
    #     $result | Should -Be "test
}