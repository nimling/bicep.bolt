<#
.SYNOPSIS
remove the environment notation from a string

.DESCRIPTION
remove the environment notation from a string

.PARAMETER string
input string

.PARAMETER Env
the environment notation to remove

.EXAMPLE
Remove-EnvNotation -string "string.dev" -Env "dev"
#>
function Remove-EnvNotation {
    [CmdletBinding()]
    param (
        [parameter(ValueFromPipeline,Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$string,

        [string[]]$Env
    )
    begin{

    }
    Process{
        $env | Where-Object { $string -like "*.$_" } | ForEach-Object {
            $_env = $_
            #split the string on the env notation and join it again
            $Newstring = ($string.split(".") | Where-Object { $_ -ne $_env }) -join "."
            Write-BaduVerb "Updated: $string to $newstring"
            $string = $Newstring
        }
    
        return $string
    }
}