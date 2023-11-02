using namespace system.drawing
function Get-StatusColor {
    [CmdletBinding()]
    param (
        [string]$provisioningState
    )
    #write as ansi codes using rgb
    # $Colors = @{
    #     red   = "`e[38;2;220;20;60m" #crimson
    #     blue  = "`e[38;2;0;191;255m" #deep skye blue
    #     green = "`e[38;2;0;255;0m" #lime
    # }
    $Colors = @{
        red   = [KnownColor]::Crimson
        blue  = [KnownColor]::DeepSkyBlue
        green = [KnownColor]::Lime
    }

    $colorName = $null
    switch ($provisioningState) {
        'Succeeded' {
            $colorName = $Colors.green
        }
        'Failed' {
            $colorName = $Colors.red
        }
        default {
            $colorName = $Colors.blue
        }
    }

    $color = [color]::FromName($colorName.ToString())
    return "`e[38;2;{0};{1};{2}m" -f $Color.R, $Color.G, $Color.B
}