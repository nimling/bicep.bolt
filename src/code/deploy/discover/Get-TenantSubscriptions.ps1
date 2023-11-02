function Get-TenantSubscription {
    [CmdletBinding()]
    param (
    )
    
    $DeployConfig = Get-DeployConfig
    Get-AzSubscription -TenantId $DeployConfig.getTenantId() -WarningAction SilentlyContinue
}