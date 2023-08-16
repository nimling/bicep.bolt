function Test-BoltConfigRegistry {
    [CmdletBinding()]
    param (
        [boltConfigRegistry]$Config
    )
    
    New-BoltLogContext -command 'validate.config.registry'

    switch($Config.type){
        'acr'{
            # Test-BoltConfigRegistryAcr -Config $Config
            Write-BoltLog -level verbose -message "Testing registry tenant $($Config.tenantId)"
            if ($null -eq (get-aztenant -tenantid $Config.tenantId)) {
                Throw "Could not find defined tenantId '$($Config.tenantId)'"
            }
            Write-BoltLog -level verbose -message "Testing registry subscription $($Config.subscriptionId)"
            $Subscription = (get-azsubscription -tenantid $Config.tenantId -SubscriptionId $Config.subscriptionId -ea SilentlyContinue)
            if (!$Subscription) {
                Throw "Could not find defined subscriptionId '$($Config.subscriptionId)'"
            }

            # if ((get-azcontext).Subscription.Id -ne $Subscription.Id) {
            #     Write-BoltLog -level verbose -message "Setting context to subscription $($Subscription.Name)"
            #     $Subscription | Set-AzContext -WarningAction SilentlyContinue -ErrorAction Stop -WhatIf:$false | Out-Null
            # }
        
            Write-BoltLog -level verbose -message "Testing registry $($Config.type) $($Config.name)"
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
            Write-BoltLog -level verbose -message "check if registry exists $($Uri -join '')"
            try{
                $k = Invoke-AzRest -Path $uri
                $resource = ($k.Content | ConvertFrom-Json).value
                if($resource.count -lt 1){
                    throw "Could not find defined registry"
                }
            }
            catch{
                # Write-BoltLog -level verbose -message $_
                throw "error tyrying to find $($Config.type) '$($Config.name)' in subscription'$($Config.subscriptionId)': $_"
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