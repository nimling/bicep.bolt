function Get-AcrRepository {
    [CmdletBinding()]
    [OutputType([Microsoft.Azure.Commands.ContainerRegistry.Models.PSTagList])]
    param (
        [string]$Name,
        [string]$Registry
    )
    
    begin {
        if(!$Registry){
            $Registry = (get-acrContext).registry
        }
        
        if($Registry -like "*azurecr.io"){
            $Registry = $Registry -replace "\.azurecr\.io",""
        }
    }
    
    process {
        if(!$name){
            return Get-AzContainerRegistryRepository -RegistryName $Registry|ForEach-Object -ThrottleLimit 10 -Parallel {
                Get-AzContainerRegistryTag -RegistryName $using:Registry -RepositoryName $_
            }
        }
        Get-AzContainerRegistryTag -RegistryName $Registry -RepositoryName $Name
    }
    
    end {
        
    }
}