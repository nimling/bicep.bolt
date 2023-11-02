task default -depends pester
task pester {
    ipmo "$PSScriptRoot\BoltRules.psm1" -Force
    invoke-pester $PSScriptRoot
}