function Get-AcrRegistryExchangeToken {
    [CmdletBinding()]
    [Outputtype([string])]
    param (
        [string]$registry
    )
    
    $token = Get-AzAccessToken -Verbose:$false
    if($registry -like "https://*") {
        $registry = $registry -replace "https://", ""
    }
    
    $registryUrl = "https://$registry"
    $exchangeUri = "$RegistryUrl/oauth2/exchange"
    $param = @{
        Uri         = $exchangeUri
        Method      = 'post'
        Headers     = @{
            Authorization = (@("bearer", $token.Token) -join " ")
        }
        Body        = @{
            grant_type   = "access_token"
            service      = $registry 
            tenant       = (get-azcontext).tenant.id
            access_token = $token.Token
        }
        ErrorAction = 'Stop'
    }
    $verb = $VerbosePreference
    try{
        $VerbosePreference = "SilentlyContinue"
        $acr_token = Invoke-RestMethod @param -Verbose:$false
    }
    finally{
        $VerbosePreference = $verb
    }

    return $acr_token.refresh_token
}