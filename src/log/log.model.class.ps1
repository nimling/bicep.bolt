using namespace System.Collections.Generic
using namespace System.Management.Automation
class LogContext {
    [ValidateNotNullOrEmpty()]
    [string]$context
    [string]$subContext
 
    #command, what to call it
    [Dictionary[string,CallStackFrame]]$commandMap = [Dictionary[string, string]]::new()

    [void]AddCommandContext([string]$command,[CallStackFrame]$frame) {
        $this.commandMap.Add($frame.Command,$command)
    }

    [string]ToString() {
        $return = $this.context
        if ($this.subContext) {
            $return += ":$($this.subContext)"
        }

        if($this.commandMap.Count -gt 0)
        {
            :commandsearch foreach($cmd in Get-PSCallStack)
            {
                if($this.commandMap.ContainsKey($cmd.Command))
                {
                    $return += ":$($this.commandMap[$cmd.Command])"
                    break :commandsearch
                }
            }
        }
        
        return $return
    }
}