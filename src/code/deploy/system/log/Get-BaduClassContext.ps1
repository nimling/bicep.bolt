function Get-BaduClassContext {
    [CmdletBinding()]
    param (
        [string]$ScriptPath,
        [int]$LineNumber
    )
    
    $Classes = ($Global:BaduLogContext._.class[$ScriptPath].getEnumerator().where{
        $_.Value[0] -le $LineNumber -and $_.Value[1] -ge $LineNumber
    })
    if(!$Classes)
    {
        throw "Could not find class for line $LineNumber in $ScriptPath"
    }
    $return = ($Classes | select -first 1).key 
    return $return
}