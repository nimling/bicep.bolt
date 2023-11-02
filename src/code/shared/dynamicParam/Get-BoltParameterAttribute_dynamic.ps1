function Get-BoltParameterAttribute:Dynamic {
    [CmdletBinding()]
    param (
        [ValidateSet(
            "deploy-env",
            "deploy-name"
        )]
        [string]$parameter
    )
    
    begin {
        
    }
    
    process {
        #env
        if ($parameter -eq 'deploy-env') {
            # $keys = @(,'.')
            $configKeys = (Get-BoltConfig:Dynamic).deploy.environments.keys
            $keys = [string[]]::new($configKeys.count + 1)
            $keys[0] = '.'
            #easiest method of adding an array to another array
            $configKeys.CopyTo($keys, 1)
            Write-Debug "DynamicParam:Env: Environments count: $($keys.Count)"
            # $l =  
            # $l.ValidValues.AddRange($keys)  
            return [System.Management.Automation.ValidateSetAttribute]::new($keys)
        } elseif ($parameter -eq 'deploy-name') {
            $items = gci $pwd.path -filter "*.bicep" -file -recurse -Exclude "*.ignore.bicep"
            Write-Debug "DynamicParam:Name: Bicep files count: $($items.count)"
            return [System.Management.Automation.ValidateSetAttribute]::new(@($items.BaseName))
        }
    }
    
    end {
        
    }
}