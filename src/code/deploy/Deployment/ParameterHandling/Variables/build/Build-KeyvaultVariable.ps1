function Build-KeyvaultVariable {
    [CmdletBinding()]
    param (
        [envVariable_keyvault]$variable
    )
    
    $vault_error = $null
    $sec_error = $null
    Write-BaduVerb "Getting secret $($variable.secret) from keyvault $($variable.vault)"
    $azVault = Get-AzKeyVault -VaultName $variable.vault -ErrorAction SilentlyContinue -ErrorVariable vault_error
    if (!$azVault -or $vault_error) {
        throw "Keyvault '$($variable.vault)' not found: $vault_error"
    }
    if($azVault.EnabledForTemplateDeployment -eq $false){
        throw "Keyvault '$($variable.vault)' is not enabled for template deployment"
    }

    if ($variable.version) {
        $azSecret = $azVault|Get-AzKeyVaultSecret -Name $variable.secret -Version $variable.version -ErrorAction SilentlyContinue -ErrorVariable sec_error
    } else {
        $azSecret = $azVault|Get-AzKeyVaultSecret -Name $variable.secret -ErrorAction SilentlyContinue -ErrorVariable sec_error
    }
    
    if (!$azSecret -or $sec_error) {
        throw "Secret '$($variable.secret)' not found in keyvault '$($variable.vault)': $sec_error"
    }

    return @{
        reference = @{
            keyVault   = @{
                id = $azVault.ResourceId
            }
            secretName = $this.secret
        }
    }
}