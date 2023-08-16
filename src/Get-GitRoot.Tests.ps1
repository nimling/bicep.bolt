Describe 'Get-GitRoot' {
    BeforeDiscovery{
        #mock git rev-parse --show-toplevel
        Mock git { 
            return "Pester"
        }
    }
    It 'Returns the root of the git repository' {
        $root = Get-GitRoot
        $root | Should -Be "Pester"
    }
}