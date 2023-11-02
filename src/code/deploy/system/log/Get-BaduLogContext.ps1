using namespace System.Management.Automation
function Get-BaduLogContext {
    [CmdletBinding()]
    [OutputType([Hashtable])]
    param (
        [CallStackFrame[]]$CallStack
    )
    begin {
        if (!$Global:BaduLogContext) {
            $Global:BaduLogContext = @{}
        }
    }
    process {
        #Get first caller of callstack
        $Caller = $CallStack | Select-Object -First 1
        $CallerName = $Caller.Command

        if (!$CallerName) {
            $CallerName = Get-BaduClassContext -ScriptPath $caller.ScriptName -LineNumber $Caller.ScriptLineNumber
        }

        if (!$Global:BaduLogContext.ContainsKey($CallerName)) {
            $return = @{
                Tag           = $CallerName
                IsSubFunction = $false
            }
        } else {
            $return = $Global:BaduLogContext[$CallerName].Clone()
        }


        #Get the tab level
        $TabLevel = 0
        foreach ($CallstackItem in $CallStack) {
            $CallStackItemName = $CallstackItem.Command
            if (!$CallStackItemName) {
                $CallStackItemName = $CallstackItem.FunctionName
            }

            if ($Global:BaduLogContext.ContainsKey($CallStackItemName)) {
                if ($Global:BaduLogContext[$CallStackItemName].IsSubFunction) {
                    $TabLevel++
                }
            }
        }

        $return.Tab = $TabLevel
        return $return
    }
    end {
    }
}

# function tes{
#     test
# }
# function test{
#     (Get-PSCallStack)[-1]
# }

# tes