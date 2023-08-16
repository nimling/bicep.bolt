function New-BoltConfig {
    [CmdletBinding()]
    param (
        $SearchFrom = $pwd.Path
    )
    
    begin {
        $ConfigPath = Find-BoltConfigFile -SearchFrom $SearchFrom
    }
    
    process {
        $ConfigContent = Get-Content -Path $ConfigPath

        #TODO: insert validate schema here
        
        $ConfigObject = $ConfigContent|ConvertFrom-Json -AsHashtable

        try{
            $config = [boltconfig]$ConfigObject
            $config.validate()
            return $config
        }
        catch{
            Write-boltlog -level verbose -message "STACKTRACE:"
            Write-boltlog -level verbose -message $_.ScriptStackTrace
            Write-boltlog -level error -message "Could not convert object to boltConfig: $_"
            throw $_
        }
        
    }
    
    end {
        
    }
}