function New-BoltConfig {
    [CmdletBinding()]
    [OutputType([boltconfig])]
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
            $config.SetConfigDirectory(($ConfigPath|Split-Path -Parent))
            New-Variable -Name boltconfig_search_path -Value $SearchFrom -Scope Global -Force -WhatIf:$false
            New-Variable -Name boltconfig -Value $config -Scope Global -Force -WhatIf:$false

            return $Global:Boltconfig
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