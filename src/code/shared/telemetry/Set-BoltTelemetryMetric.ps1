<#
.SYNOPSIS
Basic Telemetry function to track actions and time spent on them

.DESCRIPTION
Basic Telemetry function to track actions and time spent on them

.PARAMETER Action
What action to make. Can be Start, End, Internal or External

.PARAMETER ClassName
Only needed when used from class. ps classes are not easy to get the name of, so you need to pass it in (will be fixed in future versions)

.PARAMETER AddedInfo
If calling Internal or External, you can pass in a string to add to the list of actions

.EXAMPLE
Set-BoltMetricpoint Start
##... do stuff
Set-BoltMetricpoint End

.EXAMPLE
Set-BoltMetricpoint Internal "Other-Command"

.EXAMPLE
Set-BoltMetricpoint External "https://google.com"

.NOTES
This is a very basic telemetry function. It is not meant to be used for anything other than basic tracking of actions and time spent on them.
#>
function Set-BoltTelemetryMetric {
    [CmdletBinding()]
    param (
        [ValidateSet(
            "Start",
            "End",
            "Internal",
            "External"
        )]
        [string]$Action,
        [string]$ClassName,
        [string]$AddedInfo
    )

    #init new if not already instanced
    if($null -eq $global:boltTelemetry)
    {
        Initialize-BoltTelemetry
    }

    #Get caller info
    $Caller = (get-pscallstack)[1]
    $CallerId = $Caller.GetHashCode()
    $CallerName = $Caller.Command
    if($ClassName){
        $CallerName = $ClassName
    }

    #init map for caller if not already instanced
    if($null -eq $global:boltTelemetry.$CallerName)
    {
        $global:boltTelemetry.$CallerName = @{}
    }

    $CallerTelemetryMap = $global:boltTelemetry.$CallerName

    #init the unique instance of caller if not already instanced
    if($null -eq $CallerTelemetryMap.$CallerId)
    {
        $CallerTelemetryMap.$CallerId = @{
            actions = @{
                Internal = [System.Collections.Generic.List[String]]::new()
                External = [System.Collections.Generic.List[String]]::new()
            }
            Called = 0
            Time = [System.Diagnostics.Stopwatch]::new()
            Started = [System.DateTime]::Now
            StartedByAction = $Action
        }
    }

    $CallerTelemetry = $global:boltTelemetry.$CallerName.$CallerId

    #set data based on action
    switch($Action){
        "Start" {
            $CallerTelemetry.Time.Start()
            $CallerTelemetry.Called++
            Write-BoltLog -message "Started $CallerName" -level "dev"
        }
        "End" {
            $CallerTelemetry.Time.Stop()
        }
        "Internal" {
            $CallerTelemetry.actions.Internal.Add($AddedInfo)
        }
        "External" {
            $CallerTelemetry.actions.External.Add($AddedInfo)
        }
    }
}