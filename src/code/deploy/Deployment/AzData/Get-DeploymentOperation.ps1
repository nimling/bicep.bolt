function Get-DeploymentOperation {
    [CmdletBinding()]
    param (
        [parameter(Mandatory)]
        [string]$id,

        [parameter(Mandatory)]
        [ValidateSet(
            "ResourceGroup",
            "Subscription"
        )]
        [string]$context
    )
    
    begin {}
    process {
        switch ($context) {
            "ResourceGroup" {
                #match subscription and resourcegroup
                $regex = "\w+\/(?'subid'[^\/]+)\/\w+\/(?'rg'[^\/]+)"
            }
            "Subscription" {
                #match subscription
                $regex = "\w+\/(?'subid'[^\/]+)"
            }
        }

        $match = $id -match "$regex\/providers\/Microsoft\.Resources\/deployments\/(?'name'.+)$"
        if (!$match) {
            throw "id '$id' is not a valid deployment id"
        }

        switch ($context) {
            "ResourceGroup" {
                return Get-AzResourceGroupDeploymentOperation -ResourceGroupName $matches.rg -DeploymentName $matches.name  # -id $id -ErrorAction SilentlyContinue
            }
            "Subscription" {
                return Get-AzDeploymentOperation -DeploymentName $matches.name -ErrorAction SilentlyContinue
            }
        }
    }
    end {}
}