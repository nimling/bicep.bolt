using namespace System.Collections.Generic

Describe "Select-ByEnvironment" -Tag "Unit"{
    BeforeDiscovery {
        $environments = @{
            dev    = [deployEnvironment]::new(@{
                    Name      = "dev"
                    isScoped  = $true
                    variables = @()
                })
            test   = [deployEnvironment]::new(@{
                    Name      = "test"
                    isScoped  = $true
                    variables = @()
                })
            prod   = [deployEnvironment]::new(@{
                    Name      = "prod"
                    isScoped  = $true
                    variables = @()
                })
            global = [deployEnvironment]::new(@{
                    Name      = "global"
                    isScoped  = $false
                    variables = @()
                })
        }

        $testcases = @(
            @{
                #should return all items without environment
                name         = "Not Set"
                environments = [List[deployEnvironment]]::new(0)
                expect_files = 4
                expect_folders = 2
            },
            @{
                #should return both .dev and .global
                name         = "Set to dev"
                environments = [List[deployEnvironment]]@($environments.dev, $environments.global)
                expect_files = 4 * 2
                expect_folders = 2 * 2
            },
            @{
                #should return both .test and .global
                name         = "Set to test"
                environments = [List[deployEnvironment]]@($environments.test, $environments.global)
                expect_files = 4 * 2
                expect_folders = 2 * 2
            },
            @{
                #should return both .prod and .global
                name         = "Set to prod"
                environments = [List[deployEnvironment]]@($environments.prod, $environments.global)
                expect_files = 4 * 2
                expect_folders = 2 * 2
            },
            @{
                #should return both .global and those without environment
                name         = "Set to global"
                environments = [List[deployEnvironment]]@($environments.global)
                expect_files = 4 * 2
                expect_folders = 2 * 2
            }
        )


    }

    BeforeAll {
        "dev", "test", "prod", "global", "" | ForEach-Object {
            $env = $_
            0..1 | ForEach-Object {
                $i = $_
                $name = (@("item$i", $env) | ? { $_ }) -join "."
                $Folder = Join-Path $testdrive $name
                new-item $Folder -ItemType Directory
                "bicep", "json" | ForEach-Object {
                    $ext = $_
                    $Item = Join-Path $testdrive "$name.$ext"
                    new-item $Item -ItemType File
                }
            }
        }
    }

    AfterAll {
        Get-ChildItem -Path "TestDrive:\" -Recurse -Force | Remove-Item -Recurse -Force
    }

    it "can get correct items for environment <name>" -TestCases $testcases {
        param(
            $name,
            $environments,
            $expect_files,
            $expect_folders
        )
        $files = Get-ChildItem -Path "TestDrive:\" -file
        $folders = Get-ChildItem -Path "TestDrive:\" -directory
        $folders | Select-ByEnvironment -Environments $environments -WarningAction SilentlyContinue | Should -HaveCount $expect_folders
        $files | Select-ByEnvironment -Environments $environments -WarningAction SilentlyContinue | Should -HaveCount $expect_files
    }

    it "returns both non-environment and current-scoped <case> when -All is set" -TestCases @(
        @{
            case      = "File"
        }
        @{
            case      = "Directory"
        }
    ) {
        param(
            $case,
            $inputitem
        )
        $param = @{
            $case = $true
        }
        $inputitem = Get-ChildItem $testdrive @param
        $env = @(
            [deployEnvironment]::new(@{
                Name      = "dev"
                isScoped  = $true
                variables = @()
            })
        )
        $expect = ($inputitem|?{$_.BaseName -like "*dev" -or $_.BaseName -notlike "*.*"}|Measure-Object).Count
        $inputitem | Select-ByEnvironment -Environments $env -All | Should -HaveCount $expect 
    }
}