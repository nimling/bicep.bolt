function Test-BoltTriggerOnOutput {
    [CmdletBinding()]
    [OutputType([ModuleUpdateReason])]
    param (
        [hashtable]$LocalObject,
        [hashtable]$RemoteObject,
        [string]$Rule,
        [switch]$LogEverything
    )
    New-BoltLogContext -command "outputTest $rule"
    # Write-BoltLog "OUTPUT RULE: $rule" -level 'dev'
    <#
        "outputsAdded",
        "outputsRemoved",
        "outputsModified",
    #>
    $RemoteOutputs = $RemoteObject.outputs
    $LocalOutputs = $LocalObject.outputs
    if ($Rule -eq 'outputsRemoved') {
        foreach ($remoteKey in $RemoteOutputs.keys) {
            if ($remoteKey -notin $LocalOutputs.keys) {
                Write-Output ([ModuleUpdateReason]::Removed("output", $remoteKey))
            }
        }
    }

    :outputsearch foreach ($localKey in $LocalOutputs.keys) {

        if ($localKey -notin $RemoteOutputs.keys -and $Rule -eq 'outputsAdded') {
            Write-Output ([ModuleUpdateReason]::Added("output", $localKey))
            continue :outputsearch
        }

        if($rule -eq 'outputsModified'){
            $localOutput = $LocalOutputs[$localKey]|Convert-HashtableToArray -excludeTypes array,object
            $remoteOutput = $RemoteOutputs[$localKey]|Convert-HashtableToArray -excludeTypes array,object
            foreach($out in $localOutput.keys){
                if($localOutput[$out] -ne $remoteOutput[$out]){
                    if($LogEverything){
                        Write-BoltLog "output $localKey.$out has changed" -level 'dev'
                        Write-BoltLog "local: $($localOutput[$out])" -level 'dev'
                        Write-BoltLog "remote: $($remoteOutput[$out])" -level 'dev'
                    }
                    $name = $localKey + "." + $out
                    Write-Output ([ModuleUpdateReason]::Modified($name, $remoteOutput[$out], $localOutput[$out]))
                    continue :outputsearch
                }
            }
        }
    }
}