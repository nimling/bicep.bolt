Describe 'Trigger on param' -Tags 'releaseTests','publish' {
    Context "General" {
        it "should not throw"{
            $param = @{
                LocalObject = @{}
                RemoteObject = @{}
                Rule = 'paramAdded'
                LogEverything = $true
            }
            {Test-BoltTriggerOnParam @param} | Should -Not -Throw
        }
    }
    context "classes"{
        it "ModuleUpdateReason class should be possible to create"{
            {[ModuleUpdateReason]::new()} | Should -Not -Throw
            [ModuleUpdateReason]::new() | Should -Not -BeNullOrEmpty
        }
    }
    context "TestCase -> 'paramAdded'" {
    }
    Context "TestCase -> 'Added Without Default Value'" {
        BeforeEach {
            $env:pester_enabled = $null
        }
        AfterAll {
            $env:pester_enabled = $true
        }
        it "Should trigger if param is added without default value" {
            $param = @{
                LocalObject = @{
                    parameters = @{
                        existing = @{
                            type = 'string'
                        }
                        new = @{
                            type = 'string'
                        }
                    }
                }
                RemoteObject = @{
                    parameters = @{
                        existing = @{
                            type = 'string'
                        }
                    }
                }
                Rule = 'paramAddedWithoutDefaultValue'
                LogEverything = $true
            }
            $result = Test-BoltTriggerOnParam @param
            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType [ModuleUpdateReason]
            $result.type | Should -Be 'added'
            $result.key | Should -Be 'new'
        }
        it "Should trigger if default value is defined, but null" {
            $param = @{
                LocalObject = @{
                    parameters = @{
                        existing = @{
                            type = 'string'
                        }
                        new = @{
                            type = 'string'
                            defaultValue = $null
                        }
                    }
                }
                RemoteObject = @{
                    parameters = @{
                        existing = @{
                            type = 'string'
                        }
                    }
                }
                Rule = 'paramAddedWithoutDefaultValue'
                LogEverything = $true
            }
            $result = Test-BoltTriggerOnParam @param
            $result | Should -BeOfType [ModuleUpdateReason]
            $result.type | Should -Be 'added'
            $result.key | Should -Be 'new'
        }
        it "Should not trigger if default value is defined" {
            $param = @{
                LocalObject = @{
                    parameters = @{
                        existing = @{
                            type = 'string'
                        }
                        new = @{
                            type = 'string'
                            defaultValue = 'test'
                        }
                    }
                }
                RemoteObject = @{
                    parameters = @{
                        existing = @{
                            type = 'string'
                        }
                    }
                }
                Rule = 'paramAddedWithoutDefaultValue'
                LogEverything = $true
            }
            $result = Test-BoltTriggerOnParam @param
            $result | Should -BeNullOrEmpty
        }
        it "Should not trigger if default value is defined, but empty (not null)" {
            $param = @{
                LocalObject = @{
                    parameters = @{
                        existing = @{
                            type = 'string'
                        }
                        new = @{
                            type = 'string'
                            defaultValue = ''
                        }
                    }
                }
                RemoteObject = @{
                    parameters = @{
                        existing = @{
                            type = 'string'
                        }
                    }
                }
                Rule = 'paramAddedWithoutDefaultValue'
                LogEverything = $true
            }
            $result = Test-BoltTriggerOnParam @param
            $result | Should -BeNullOrEmpty
        }
        it "Should not trigger if param is nullable" {
            $param = @{
                LocalObject = @{
                    parameters = @{
                        existing = @{
                            type = 'string'
                        }
                        new = @{
                            type = 'string'
                            nullable = $true
                        }
                    }
                }
                RemoteObject = @{
                    parameters = @{
                        existing = @{
                            type = 'string'
                        }
                    }
                }
                Rule = 'paramAddedWithoutDefaultValue'
                LogEverything = $true
            }
            $result = Test-BoltTriggerOnParam @param
            $result | Should -BeNullOrEmpty
        }
        it "Should not trigger if param is nullable and default value is null" {
            $param = @{
                LocalObject = @{
                    parameters = @{
                        existing = @{
                            type = 'string'
                        }
                        new = @{
                            type = 'string'
                            nullable = $true
                            defaultValue = $null
                        }
                    }
                }
                RemoteObject = @{
                    parameters = @{
                        existing = @{
                            type = 'string'
                        }
                    }
                }
                Rule = 'paramAddedWithoutDefaultValue'
                LogEverything = $true
            }
            $result = Test-BoltTriggerOnParam @param
            $result | Should -BeNullOrEmpty
        }
    }
    Context "TestCase -> 'paramRemoved'" {
    }
    Context "TestCase -> 'paramCaseModified'" {
    }
    Context "TestCase -> 'paramTypeModified'" {
    }
    Context "TestCase -> 'paramAllowedValueRemoved'" {
    }
    Context "TestCase -> 'paramAllowedValueAdded'" {
    }
    Context "TestCase -> 'paramAllowedValueModified'" {
    }
    Context "TestCase -> 'paramDefaultValueModified'" {
    }
}