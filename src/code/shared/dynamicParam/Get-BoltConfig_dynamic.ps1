function Get-BoltConfig:Dynamic {
    [CmdletBinding()]
    param ()
    
    $path = gci $pwd.path -filter "bolt.json?" -file -recurse | select -first 1
    if (!$path) {
        throw "Could not find bolt.json in $($pwd.path)"
    }
    return get-content $path.fullname | convertfrom-json -AsHashtable
}