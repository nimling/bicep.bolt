function Write-BoltLog {
    [CmdletBinding()]
    param (
        $message,
        [ValidateSet("info", "warning", "error", "success", "verbose", "dev")]
        [string]$level = $global:boltTelemetry.defaultLogLevel
    )
    begin {
    }
    process {
        $LevelConfig = $global:boltTelemetry._.levels.$level

        try{
            $msg = @{
                level   = $level
                message = $message
                context = $Global:logContext
                global  = $global:boltTelemetry._
            } | % { $global:boltTelemetry._.log_template.invoke() }
        }catch{
            Throw "Error writing log: $($_.Exception.Message)"
        }

        #check if we can write this level
        if ([bool]$LevelConfig.canWrite.Invoke() -eq $false) {
            return
        }

        Write-Host $msg -ForegroundColor $LevelConfig.color
    }
    end {}
}