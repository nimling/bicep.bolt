function Get-DeployConfigVariable {
    [CmdletBinding()]
    param (
        [parameter(
            ValueFromPipeline,
            HelpMessage = "The name of the variable to get. expects clean value"
        )]
        [string]$value
    )
    process {
        # $Value = Remove-VariableReferenceToken -Value $value
        $config = Get-DeployConfig
        $Variables = @()
        Foreach($EnvName in $config.environmentPresedence){
            $env = $config.environments | Where-Object { $_.name -eq $envName }
            if($env.variables.ContainsKey($Value))
            {
                $Variables += $env.variables[$Value]
            }
        }
        $out = $Variables | Select-Object -first 1
        if (!$out) {
            throw "Could not find variable with value '$value'"
        }
        return $out
    }
}