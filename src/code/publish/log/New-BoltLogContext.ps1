function New-BoltLogContext {
    [CmdletBinding()]
    param (
        [string]$context,
        [string]$subContext,
        [string]$command
    )
    begin {
        if (!$global:logContext) {
            # $lc = [LogContext]::new("process")
            # $lc.context = "process"
            $global:logContext = [LogContext]::new("process")
        }
        if ($context) {
            $global:logContext.context = $context
        }
        if ($subContext) {
            $global:logContext.subContext = $subContext
        }
        if($command)
        {
            $global:logContext.AddCommandContext($command, (Get-PSCallStack)[1])
        }
    }
    process {
        
    }
    end {
        # $global:logContext = $null
    }
}