<#
.SYNOPSIS
Get git root
#>
function Get-GitRoot {
    $err = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'stop'
        $GitRoot = git rev-parse --show-toplevel 2>&1
        if ($GitRoot -like '*not a git repository*') {
            throw 
        }

    } catch {
        throw "This is not designed to function outside a git repo (you are in '$($pwd.Path)'). should possibly be '$($global:BoltRoot)'?)"
    } finally {
        $ErrorActionPreference = $err
    }
    return $GitRoot
}