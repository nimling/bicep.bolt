function Get-VariableReferenceInString {
    [CmdletBinding()]
    [OutputType([System.Text.RegularExpressions.Group])]
    param (
        [string]$String
    )
    
    begin {
        
    }
    
    process {
        $DryConfig = (Get-DeployConfig).dry
        $start = $DryConfig.style[0]
        $end = $DryConfig.style[1]

        #explanation (using {}): 
        #\$start = match the $start character, example {
        #[^\$end]* = match any character that is not $end, 0 or more times -> while the character is not }
        #\$end = match the $end character example }
        $regex = "\$start(?'var'[^\$start\$end]*)\$end"
        Write-BaduDebug "Regex: $regex -> where string starts with '$start' and ends with '$end'. grab anything in between that is not '$start' or '$end'"
        $match = [regex]::matches($string, $regex)
        Write-BaduVerb "Found $($match.count) matches on string '$string'"
        return $match.groups | Where-Object { $_.name -eq 'var' }
    }
    
    end {
        
    }
}