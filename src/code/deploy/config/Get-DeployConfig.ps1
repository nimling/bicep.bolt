function Get-DeployConfig {
    [CmdletBinding()]
    [OutputType([deployconfig])]
    param ()
    
    if(!$global:deployConfig){
        throw "Failed to get deployConfig. it is not initialized yet (New-DeployConfig is not called yet)"
    }

    $CurrentInstance = (get-pscallstack)[-1].GetHashCode()
    #if the instance id is not the same as the current instance, throw. except if its a developer
    if($global:deployConfig.dev.ignoreInstance -eq $false -and $global:deployConfig.dev.enabled)
    {
        if($global:deployConfig.InstanceId -ne $CurrentInstance){
            throw "Failed to get the proper deployConfig. please make sure you have it instanced within the same callstack. If you are a developer, add dev.ignoreinstance = true to your deployconfig.json"
        }
    }

    return $global:deployConfig
}