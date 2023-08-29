function Get-BoltConfig {
    [CmdletBinding()]
    [OutputType([boltconfig])]
    param ()

    if(!$Global:BoltConfig){
        $param = @{
            SearchFrom = $pwd.Path
        }
        if($Global:boltconfig_search_path)
        {
            $param.SearchFrom = $Global:boltconfig_search_path
        }
        $Global:BoltConfig = New-BoltConfig @param
    }

    return $Global:BoltConfig
}