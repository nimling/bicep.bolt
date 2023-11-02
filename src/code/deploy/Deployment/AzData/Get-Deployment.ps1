function Get-Deployment {
    [CmdletBinding()]
    param (
        [parameter(Mandatory)]
        [string]$Id,

        [parameter(Mandatory)]
        [ValidateSet(
            "ResourceGroup",
            "Subscription"
        )]
        [string]$Context,

        # [parameter(Mandatory)]
        [ValidateSet(
            "Current",
            "Children",
            "All"
        )]
        [string]$Scope = "Current"
    )
    
    begin {}
    process {
        switch ($context) {
            "ResourceGroup" {
                $Deployment = Get-AzResourceGroupDeployment -id $id -ErrorAction SilentlyContinue
                if ($Scope -eq 'Current') {
                    return $Deployment
                }

                $Deployments = Get-AzResourceGroupDeployment -ResourceGroupName $Deployment.ResourceGroupName | Where-Object { $_.CorrelationId -eq $Deployment.CorrelationId }
                if ($Scope -eq "Children") {
                    $Deployments = $Deployments | Where-Object { $_.Id -ne $id }
                }
                return $Deployments
            }
            "Subscription" {
                $Deployment = Get-AzSubscriptionDeployment -Id $id -ErrorAction SilentlyContinue
                if ($Scope -eq 'Current') {
                    return $Deployment
                }

                $Deployments = (Get-AzSubscriptionDeployment | Where-Object { $_.CorrelationId -eq $Deployment.CorrelationId })
                if ($Scope -eq "Children") {
                    $Deployments = $Deployments | Where-Object { $_.Id -ne $id }
                }
                return $Deployments
            }
        }
    }
    end {}
}