function Test-BoltConfigRegistry {
    [CmdletBinding()]
    param (
        [boltConfigRegistry]$Config
    )
    New-BoltLogContext -command 'validate_registry'

    switch($Config.type){
        'acr'{
            # Test-BoltConfigRegistryAcr -Config $Config
            Write-BoltLog -level verbose -message "Testing registry tenant $($Config.tenantId)"
            try{
                Invoke-RestMethod -Uri "https://login.microsoftonline.com/$($Config.tenantId)/v2.0/.well-known/openid-configuration" -ea stop -verbose:$false|out-null
            }
            catch{
                throw "tenant id '$($Config.tenantId)' is not a tenant in microsoft azure/entra"
            }

            if ($null -eq (get-aztenant -tenantid $Config.tenantId)) {
                Throw "Could not find defined tenantId '$($Config.tenantId)' (are you logged in?)"
            }
            Write-BoltLog -level verbose -message "Testing registry subscription $($Config.subscriptionId)"

            $guid = [guid]'00000000-0000-0000-0000-000000000000'
            if(![guid]::TryParse($Config.subscriptionId, [ref]$guid)) {
                throw "registry.subscriptionid needs to be a guid, not a name"
            }
            $tenant = get-aztenant -tenantid $Config.tenantId
            $Subscription = (get-azsubscription -tenantid $tenant.id -SubscriptionId $Config.subscriptionId -ea SilentlyContinue)
            if (!$Subscription) {
                Throw "Could not find defined subscriptionId '$($Config.subscriptionId)'"
            }
            # $context = get-azcontext
            if($context.Tenant.Id -ne $tenant.id){
                Write-BoltLog "setting context from tenant $($context.Tenant.Id) to tenant $($Config.tenantId)"
                Set-AzContext -TenantId $tenant.Id -Subscription $config.subscriptionId -WarningAction SilentlyContinue -ErrorAction Stop -WhatIf:$false | Out-Null
            }
            # $context = get-azcontext

            # if ((get-azcontext).Subscription.Id -ne $Subscription.Id) {
            #     Write-BoltLog -level verbose -message "Setting context to subscription $($Subscription.Name)"
            #     $Subscription | Set-AzContext -WarningAction SilentlyContinue -ErrorAction Stop -WhatIf:$false | Out-Null
            # }

            Write-BoltLog -level verbose -message "Testing registry '$($Config.type)' '$($Config.name)'"
            $filter = "resourceType EQ 'Microsoft.ContainerRegistry/registries' AND name EQ '$($Config.name)'"
            $ApiVersion = '2021-04-01'
            $_Uri = @(
                "subscriptions"
                "/"
                $($Config.subscriptionId)
                "/"
                "resources?`$filter=$filter&api-version=$ApiVersion"
            )
            $uri = $_Uri -join ""
            Write-BoltLog -level verbose -message "check if registry exists:'$($Uri -join '')'"
            try{
                $k = Invoke-AzRestMethod -Path $uri -Verbose:$false -ErrorAction Stop
                $resource = ($k.Content | ConvertFrom-Json).value
                if($resource.count -lt 1){
                    throw "Could not find defined registry"
                }
            }
            catch{
                # Write-BoltLog -level verbose -message $_
                throw "error tyrying to find $($Config.type) '$($Config.name)' in subscription '$($Config.subscriptionId)': $_"
            }
            # $Resource = Get-AzResource - #-ResourceType 'Microsoft.ContainerRegistry/registries' -Name $Config.name 
            # if (!$Resource) {
            # }
        }
        default{
            throw "Unknown registry type '$($config.type)'"
        }
    }


}