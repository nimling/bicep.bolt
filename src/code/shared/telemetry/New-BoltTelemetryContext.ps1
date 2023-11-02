function New-BoltTelemetryContext {
    [CmdletBinding()]
    param (
        $Name = (Get-PSCallStack)[-1].Command
    )
    
    begin {
        
    }
    
    process {
        $CallstackFrame = (Get-PSCallStack)[-1]
        $context = @{
            name = $Name
            # id = (Get-PSCallStack)[-1].GetHashCode()
            actions = @{
                internal = [System.Collections.Generic.List[String]]::new()
                external = [System.Collections.Generic.List[String]]::new()
            }
            called = 1
            time = [System.Diagnostics.Stopwatch]::new()
            started = [System.DateTime]::Now
            # startedByAction = $Action
        
        }
    }
    
    end {
        
    }
}

<#
want 
current caller 
caller invoker (the one who called the caller)

#>

function one{
    two
}

function two{
    three
}

function three{
    get-pscallstack
}

one