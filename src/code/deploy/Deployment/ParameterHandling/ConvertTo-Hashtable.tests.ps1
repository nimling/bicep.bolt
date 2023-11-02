Describe "Convertto-HashTable" -Tag "Unit"{
    BeforeDiscovery{
        #generate pasobject for testing, with some children being psobject
        $testcases = @(
            @{
                Name = "simple"
                Test = [pscustomobject]@{
                    a = "a"
                    b = "b"
                }
                keys = @("a", "b")
            }
            @{
                Name = "nested"
                Test = [pscustomobject]@{
                    a = "a"
                    b = "b"
                    c = [pscustomobject]@{
                        c1 = "c1"
                        c2 = "c2"
                    }
                }
                keys = @("a", "b", "c","c.c1", "c.c2")
            }
            @{
                Name = "nested2"
                Test = [pscustomobject]@{
                    a = "a"
                    b = "b"
                    c = [pscustomobject]@{
                        c1 = "c1"
                        c2 = "c2"
                        c3 = [pscustomobject]@{
                            c31 = "c31"
                            c32 = "c32"
                        }
                    }
                }
                keys = @("a", "b", "c","c.c1", "c.c2", "c.c3", "c.c3.c31", "c.c3.c32")
            }
        )
    }

    It "should convert <name> psobject to hashtable (including children)" -TestCases $testcases{
        param($Name, $Test, $keys)
        $result = ConvertTo-Hashtable -InputItem $Test
        $result | Should -BeOfType [hashtable]
        foreach($key in $keys){
            $curr = $result
            $key -split "\."|%{
                $curr = $curr.$key
            }
            $curr -is ([pscustomobject])| Should -BeFalse -Because "$name -> $key should not be psobject"
        }
    }

    It "should convert <name> psobject to hashtable via pipeline (including children)" -TestCases $testcases{
        param($Name, $Test, $keys)
        $result = $Test|ConvertTo-Hashtable
        $result | Should -BeOfType [hashtable]
        foreach($key in $keys){
            $curr = $result
            $key -split "\."|%{
                $curr = $curr.$key
            }
            $curr -is ([pscustomobject])| Should -BeFalse -Because "$name.$key should not be psobject"
        }
    }
}