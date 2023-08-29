Describe 'Get-GitRoot' {
    BeforeDiscovery{
        #mock git rev-parse --show-toplevel
        # Mock git {
        #     return "Pester"
        # }
    }
    It 'Returns the root of the git repository' {
        # $root = Git
        $root = Get-GitRoot
        $root | Should -Be $(git rev-parse --show-toplevel)
    }
}