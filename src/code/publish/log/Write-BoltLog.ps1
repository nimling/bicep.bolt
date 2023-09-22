function Write-BoltLog {
    [CmdletBinding()]
    param (
        $message,
        [ValidateSet("info", "warning", "error", "success", "verbose","dev")]
        [string]$level = "info",
        [switch]$AlwaysWrite
    )
    
    begin {
        $colors = @{
            info    = "Cyan"
            warning = "DarkYellow"
            error   = "Red"
            success = "Green"
            verbose = "yellow"
            dev     = 'DarkMagenta'
        }

        $levelshort = @{
            info    = "Inf"
            warning = "Wrn"
            error   = "Err"
            success = "Suc"
            verbose = "Ver"
            dev     = 'dev'
        }
    }
    process {
        $msg = $message -join ""
        $ContextString = ""
        if ($Global:logContext) {
            $ContextString = $Global:logContext.ToString()
        }


        # if verbose is set to silent and $alwayswrite isnt activated , don't write verbose messages
        if (!$AlwaysWrite -and $level -eq "verbose" -and $VerbosePreference -eq "SilentlyContinue") {
            return
        }
        if (($Level -eq 'dev' -and $global:boltDev -ne $true) -or $global:pester_enabled) {
            return
        }

        Write-Host "[$($levelshort[$level])]$ContextString - $msg" -ForegroundColor $colors[$level]
    }
    end {}
}