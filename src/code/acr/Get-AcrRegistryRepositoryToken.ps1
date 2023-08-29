function Get-AcrRegistryRepositoryToken {
    [CmdletBinding()]
    [Outputtype([string])]
    param (
        [string]$exchangeToken,
        [parameter(ParameterSetName = 'repoName')]
        [string]$registry,
        [parameter(ParameterSetName = 'repoName',Mandatory)]
        [string]$RepositoryName,
        [parameter(ParameterSetName = 'repoObj',Mandatory)]
        [Microsoft.Azure.Commands.ContainerRegistry.Models.PSTagList]$Repository
    )

    if(!$registry){
        $registry = (get-acrContext).registry
    }
    switch($PSCmdlet.ParameterSetName){
        'repoName' {
            $Repository = Get-AcrRepository -registry $registry -name $RepositoryName
        }
        'repoObj' {
        }

    }

    if(!$exchangeToken){
        $exchangeToken = ConvertFrom-SecureString -SecureString (get-acrContext).tokens.refresh_token -AsPlainText
    }

    $Scope = "repository:$($Repository.ImageName)`:*"
    $exchangeUri = "https://$registry/oauth2/token"
    if(!$global:_acrtoken){
        $global:_acrtoken = @{}
    }
    $ScopeAccessToken = $global:_acrtoken[$scope]
    if($ScopeAccessToken){
        # Write-host "acrtoken found for $scope"
        $Jwt = Open-JWTtoken -token $ScopeAccessToken
        # write-host ([DateTime]('1970,1,1')).AddSeconds($Jwt.exp)
        if(([DateTime]('1970,1,1')).AddSeconds($Jwt.exp) -gt (get-date -AsUTC))
        {
            return $ScopeAccessToken
        }
    }
    Write-BoltLog "Getting ACR token for $scope" -level verbose
    $param = @{
        Uri    = $exchangeUri
        Method = "post"
        Body   = @{
            grant_type    = "refresh_token"
            service       = $registry 
            scope         = $scope
            refresh_token = $exchangeToken
        }
        ErrorAction = 'Stop'
    }
    $verb = $VerbosePreference
    try{
        $VerbosePreference = "SilentlyContinue"
        $acr_token = Invoke-RestMethod @param
    }
    finally{
        $VerbosePreference = $verb
    }
    $global:_acrtoken[$scope] = $acr_token.access_token
    return $acr_token.access_token
}