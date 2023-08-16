function Invoke-AcrCall {
    [CmdletBinding()]
    param (
        [ValidateSet('v1', 'v2')]
        [string]$ApiVersion = 'v2',
        
        [parameter(
            parameterSetName = 'repository',
            ValueFromPipeline
        )]
        [Microsoft.Azure.Commands.ContainerRegistry.Models.PSTagList]$Repository,

        [string]$Path,

        [system.io.fileinfo]$OutFile,

        [ValidateNotNullOrEmpty()]
        [ValidateSet('GET', 'POST', 'PUT', 'DELETE')]
        $Method = "GET",
        $ContentType = "application/json"
    )
    
    begin {}
    process {
        $Registry = (get-acrContext).registry
        $RepositoryName = $Repository.ImageName
        $Url = "https://$Registry/$ApiVersion/$RepositoryName/$Path"
        $AcrToken = Get-AcrRegistryRepositoryToken -Repository $Repository

        $param = @{
            uri     = $Url
            method  = $Method
            headers = @{
                'Docker-Distribution-Api-Version' = 'registry/2.0'
                Authorization                     = (@("bearer", $AcrToken) -join " ")
                Accept                            = 'application/vnd.cncf.oras.artifact.manifest.v1+json;q=0.3, application/vnd.oci.image.manifest.v1+json;q=0.4, application/vnd.docker.distribution.manifest.v2+json;q=0.5, application/vnd.docker.distribution.manifest.list.v2+json;q=0.6'
            }
            ContentType = $ContentType
            ea      = "stop"
        }
        if($OutFile){
            New-item -Path $OutFile.FullName -ItemType File -Force | Out-Null
            $Param.OutFile = $OutFile
        }
        Write-BoltLog "Calling $Url" -level verbose
        # Write-Verbose "Calling $Url"
        $Verb = $VerbosePreference
        $verbosePreference = "SilentlyContinue"
        Invoke-RestMethod @param -ErrorAction Stop -Verbose:$false
        $verbosePreference = $Verb
    }
    
    end {
        
    }
}