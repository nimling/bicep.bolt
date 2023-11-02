function Initialize-BoltTelemetry {
    [CmdletBinding()]
    param (
        [ValidateSet("main","dotsource")]
        $InstanceLevel = "main"
    )
    #if its not null
    if(!$global:boltTelemetry){
        #if the same instance already have been initialized
        if($global:boltTelemetry._.instance -eq (get-pscallstack)[-1].GetHashCode()){
            return
        }
    }

    $global:boltTelemetry = @{
        _ = @{
            instance = (get-pscallstack)[-1].GetHashCode()
            level = $InstanceLevel
            dev = [bool]$env:bolt_dev
            #[ValidateSet("info", "warning", "error", "success", "verbose","dev")]
            defaultLogLevel = "info"
            # level,message,context,global($global:boltTelemetry._)
            log_template = {
                "[{0}]{1} {2} - {3}" -f $_.level,$_.global.stopwatch.elapsed.tostring('hh\:mm\:ss'),$_.context,$_.message
            }
            levels = @{
                info    = @{
                    alias = "Inf"
                    color = [System.Drawing.KnownColor]::Cyan
                    canWrite = {$true}
                }
                warning = @{
                    alias = "Wrn"
                    color = [System.Drawing.KnownColor]::DarkYellow
                    canWrite = {$WarningPreference -ne "SilentlyContinue"}
                }
                error   = @{
                    alias = "Err"
                    color = [System.Drawing.KnownColor]::Red
                    canWrite = {$ErrorActionPreference -ne "SilentlyContinue"}
                }
                success = @{
                    alias = "Suc"
                    color = [System.Drawing.KnownColor]::Green
                    canWrite = {$true}
                }
                verbose = @{
                    alias = "Ver"
                    color = [System.Drawing.KnownColor]::Yellow
                    canWrite = {$VerbosePreference -ne "SilentlyContinue"}
                }
                dev     = @{
                    alias = "dev"
                    color = [System.Drawing.KnownColor]::DarkMagenta
                    canWrite = {[bool]$env:bolt_dev}
                }
            }
            stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        }
        <#
        callstackhash = @{
            name
            callers = @()
            
        }
        #>
    }
}