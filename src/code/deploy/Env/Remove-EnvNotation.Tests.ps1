#generate tests for the Remove-EnvNotaion function
Describe "Remove-EnvNotation" {
    Context "Remove-EnvNotation" {
        it "should remove the env notation" -Tag 'unit' {
            $base = "string"
            Remove-EnvNotation -Verbose:$false -string "$base.dev" -Env "dev"| Should -Be $base
        }

        it "should not react if the string does not contain the environment notation" -Tag 'unit' {
            $base = "string"
            Remove-EnvNotation -Verbose:$false -string $base -Env "dev"| Should -Be $base
        }

        it "should not react if env is not specified" -Tag 'unit' {
            $base = "string"
            Remove-EnvNotation -Verbose:$false -string $base| Should -Be $base
        }

        it "should support pipeline" -Tag 'unit' {
            $base = "string"
            $base, "$base.dev" | % {
                $_ | Remove-EnvNotation -Verbose:$false -Env "dev" | Should -Be $base
            }
        }

        it "should support multiple envs" -Tag 'unit' {
            $base = "string"
            Remove-EnvNotation -Verbose:$false -string "$base.dev" -Env "dev", "test" | Should -Be $base
        }

        it "string should be mandatory" -Tag 'unit' {
            get-command Remove-EnvNotation| Should -HaveParameter "string" -Mandatory
        }

        it "should throw is string is null" -Tag 'unit' {
            { Remove-EnvNotation -Verbose:$false -string $null -Env "dev"} | Should -Throw
        }
    }
}