function Write-BaduHeader {
    [CmdletBinding()]
    param (
        
    )
    
$header = @'
oooooooooo.        .o.       oooooooooo.   ooooo     ooo 
`888'   `Y8b      .888.      `888'   `Y8b  `888'     `8' 
 888    .888     .8"888.      888      888  888       8  
 888oooo888     .8' `888.     888      888  888       8  
 888    `88b   .88ooo8888.    888      888  888       8  
 888    .88P  .8'     `888.   888     d88'  `88.    .8'  
o888bood8P'  o88o     o8888  o888bood8P'      `YbodP'    
---------------------------------------------------------
Bicep Arm Deployment Utility
The Utility that won't leave you dis-ARM-ed!
'@
Write-host $header
}