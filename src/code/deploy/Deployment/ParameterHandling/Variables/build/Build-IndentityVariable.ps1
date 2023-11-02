function Build-IdentityVariable {
    [CmdletBinding()]
    param (
        [envvariable_identity]$variable
    )
    
    begin {
        $outputs = @{
            principalId = ""
            name = ""
            type = ""
            ip = ""
        }
        # Write-BaduInfo ($variable|Convertto-json -Compress)
    }
    
    process {
        $account = (get-azcontext).account
        switch($account.Type){
            'User'{
                $user = Get-AzADUser -Filter "userprincipalname eq '$($account.id)'"
                $outputs.principalId = $user.Id
                $outputs.name = $user.DisplayName
                $outputs.type = 'User'
            }
            default{
                throw "Account type '$_' not supported, yet: $($account|convertto-json -depth 1)"
            }
        }

        if($variable.value -eq 'ip'){
            $outputs.ip = (Invoke-RestMethod -Uri 'http://ipinfo.io/json').ip
        }
        
        if([string]::IsNullOrEmpty($outputs.$($variable.value))){
            throw "Could not find value for $($variable.value) in $($account.Type) $($account.id)"
        }

        return $outputs.$($variable.value)
    }
    
    end {
        
    }
}