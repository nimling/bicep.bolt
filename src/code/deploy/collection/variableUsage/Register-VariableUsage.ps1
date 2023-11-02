function Register-BaduVariableUse {
    [CmdletBinding()]
    param (
        [string]$Name,
        [envVariable]$Variable,
        [string]$Usage,
        [string]$ParameterString
    )
    begin {}
    process {
        $Global:_baduVariableUse += [pscustomobject]@{
            Name            = $Name
            ParameterString = $ParameterString
            Source          = $Variable.Source
            Description     = $Variable.Description
            Variable        = $Variable
            Usage           = $Usage
        }
    }
    end {}
}