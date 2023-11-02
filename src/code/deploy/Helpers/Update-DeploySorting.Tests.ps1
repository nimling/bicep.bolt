Describe "Update-DeploySorting" -tag "unit"{
    BeforeDiscovery {
        $TestCase = @(
            @{
                Name = "Directory"
            }
            @{
                Name = "File"
            }
        )
    }

    BeforeAll {
        "aa", "zz", "random1", "random2", "random3" | % {
            New-Item "$TestDrive\$_`Test" -ItemType Directory -force    
            New-Item "$TestDrive\$_`Test.file" -ItemType File -force
        }
        function Get-TestDriveItems {
            Param(
                $Name
            )

            $param = @{}
            $param.$Name = $true
            return (Get-ChildItem $testdrive @param)
        }
    }

    AfterAll {
        Get-ChildItem $TestDrive | Remove-Item -Recurse -Force
    }

    AfterEach {
        Get-ChildItem $TestDrive -filter "sort" | Remove-Item -Recurse -Force
    }

    it "should accept <name> items via pipeline" -TestCases $TestCase {
        param(
            [string]$name
        )
        $items = Get-TestDriveItems -Name $Name
        $items | Update-DeploySorting -verbose:$false | Should -Be $items
    }

    It "should not sort '<Name>' when order file is not present" -TestCases $TestCase {
        param(
            [string]$name
        )
        $items = Get-TestDriveItems -Name $Name
        $Order = $items | Update-DeploySorting -verbose:$false
        0..($Order.Count - 1) | % {
            $Order[$_].Name | Should -Be $items[$_].Name
        }
    }

    it "should not sort '<Name>' when order only has '...'" -TestCases $TestCase {
        param(
            [string]$name
        )
        New-Item -Path $testdrive -Name "sort" -ItemType File -Value "..."
        $items = Get-TestDriveItems -Name $Name
        $Order = $items | Update-DeploySorting -verbose:$false
        0..($Order.Count - 1) | % {
            $Order[$_].Name | Should -Be $items[$_].Name
        }
    }

    it "should not sort rest of '<Name>' if an item is defined first" -TestCases $TestCase {
        param(
            [string]$name
        )
        New-Item -Path $testdrive -Name "sort" -ItemType File -Value "aa*`n..."
        $items = Get-TestDriveItems -Name $Name
        $Order = $items | Update-DeploySorting -verbose:$false
        $Neworder = @($items | Where-Object { $_.Name -like "aa*" })
        $items | Where-Object { $_.Name -notlike "aa*" } | % {
            $Neworder += $_
        }
        0..($Order.Count - 1) | % {
            $Order[$_].Name | Should -Be $Neworder[$_].Name
        }
    }

    it "should put zz <name> first when order has 'zz*' at top" -TestCases $TestCase {
        param(
            [string]$name
        )
        New-Item -Path $testdrive -Name "sort" -ItemType File -Value "zz*" -Force
        $items = Get-TestDriveItems -Name $Name 
        $Order = $items | Update-DeploySorting -verbose:$false
        $Order[0].Name | Should -BeLike "zz*"
    }

    it "should put zz <name> at bottom when order has 'zz*' after '...'" -TestCases $TestCase {
        param(
            [string]$name
        )
        New-Item -Path $testdrive -Name "sort" -ItemType File -Value "...`nzz*" -Force
        $items = Get-TestDriveItems -Name $Name
        $Order = $items | Update-DeploySorting -verbose:$false
        $Order[-1].Name | Should -BeLike "zz*"
    }

    it "should put zz then aa <name> before anything else if defined" -TestCases $TestCase {
        param(
            [string]$name
        )
        New-Item -Path $testdrive -Name "sort" -ItemType File -Value "zz*`naa*" -Force
        $items = Get-TestDriveItems -Name $Name
        $Order = $items | Update-DeploySorting -verbose:$false
        $Order[0].Name | Should -BeLike "zz*"
        $Order[1].Name | Should -BeLike "aa*"
    }

    it "should delived the same amount of items it received" -TestCases $TestCase {
        param(
            [string]$name
        )
        New-Item -Path $testdrive -Name "sort" -ItemType File -Value "zz*`naa*" -Force
        $items = Get-TestDriveItems -Name $Name
        $Order = $items | Update-DeploySorting  -verbose:$false
        $Order.Count | Should -Be $items.Count
    }


}