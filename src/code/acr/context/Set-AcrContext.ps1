function Set-AcrContext {
    [CmdletBinding()]
    param (
        [string]$Registry,
        [Microsoft.Azure.PowerShell.Cmdlets.ContainerRegistry.Models.Api202301Preview.Registry]$azRegistry
    )
    begin {
    }
    process {
        if($azRegistry){
            $Registry = $azRegistry.LoginServer
        }
        Write-Verbose "Setting ACR context to $Registry"
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Used for global token hander singleton')]

        $global:_acr = @{
            Registry = $Registry
            Tokens = @{
                refresh_token = Get-AcrRegistryExchangeToken -registry $Registry
            }
        }
    }
    
    end {
        
    }
}