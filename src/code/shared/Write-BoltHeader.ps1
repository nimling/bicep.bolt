function Write-BoltHeader {
    [CmdletBinding()]
    param (
        [string]$Solution,
        [switch]$Dotsource
    )
    
    if (!$Dotsource) {
        $header = @"
▀█████████▄   ▄██████▄   ▄█           ███     
  ███    ███ ███    ███ ███       ▀█████████▄ 
  ███    ███ ███    ███ ███          ▀███▀▀██ 
 ▄███▄▄▄██▀  ███    ███ ███           ███   ▀ 
▀▀███▀▀▀██▄  ███    ███ ███           ███     
  ███    ██▄ ███    ███ ███           ███     
  ███    ███ ███    ███ ███▌    ▄     ███     
▄█████████▀   ▀██████▀  █████▄▄██    ▄████▀   
                        ▀                     
$Solution
----------------------------------------------
Bicep Operations and Lifecycle Tool
Zap Your Bicep Blues, Amp Up Your Azure Moves!
"@
        Write-host $header
    }
}