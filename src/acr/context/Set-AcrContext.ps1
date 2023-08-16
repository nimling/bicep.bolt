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
        $global:_acr = @{
            Registry = $Registry
            Tokens = @{
                refresh_token = ConvertTo-SecureString -String (Get-AcrRegistryExchangeToken -registry $Registry) -AsPlainText -force
            }
        }
    }
    
    end {
        
    }
}