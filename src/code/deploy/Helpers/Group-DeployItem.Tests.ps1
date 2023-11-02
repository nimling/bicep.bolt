Describe "Update-DeploySorting"-tag "unit" {
    BeforeDiscovery {
        $TestCases = @(
            @{
                ItemType = "Directory"
            }
            @{
                ItemType = "File"
            }
        )
    }

    BeforeAll {
        "aa", "bb", "cc" | % {
            New-Item "$TestDrive\$($_)Test" -ItemType Directory -force
            New-Item "$TestDrive\$($_)Test.file" -ItemType File -force
        }
        function Get-TestDriveItem {
            Param(
                $ItemType
            )

            $param = @{}
            $param.$ItemType = $true
            return (get-childitem $TestDrive @param)
        }
    }

    AfterAll {
        Get-ChildItem $TestDrive | Remove-Item -Recurse -Force
    }

    AfterEach {
        Get-ChildItem $TestDrive -filter "sort" | Remove-Item -Recurse -Force
    }

    it "should accept <ItemType> items via pipeline" -TestCases $TestCases {
        param(
            [string]$ItemType
        )

        $items = Get-TestDriveItem -ItemType $ItemType
        {$items | Group-DeployItem -verbose:$false}|should -not -throw
        ($items | Group-DeployItem -verbose:$false).'...'|should -HaveCount $items.count
    }

    It "should add all '<ItemType>' in default bucket if sort file is not present" -TestCases $TestCase {
        param(
            [string]$ItemType
        )
        $items = Get-TestDriveItem -ItemType $ItemType
        $Order = ($items | Group-DeployItem -verbose:$false)

        0..($Order.Count - 1) | % {
            $Order.'...'[$_] | Should -Be $items[$_].ItemType
        }
    }

    it "should add all '<ItemType>' in default bucket if sort file only has '...'" -TestCases $TestCase {
        param(
            [string]$ItemType
        )
        New-Item -Path $testdrive -ItemType "sort" -ItemType File -Value "..."
        $items = Get-TestDriveItem -ItemType $ItemType
        $Order = $items | Group-DeployItem -verbose:$false
        0..($Order.Count - 1) | % {
            $Order.'...'[$_].name | Should -Be $items[$_].name
        }
    }

    it "should create a bucket before default if an filter has been defined" -TestCases $TestCase {
        param(
            [string]$ItemType
        )
        $filter = 'aa*'
        New-Item -Path $testdrive -ItemType "sort" -ItemType File -Value @($filter)
        $items = Get-TestDriveItem -ItemType $ItemType
        $Order = $items | Group-DeployItem -verbose:$false
        $filterItems = $items | ? { $_.name -like $filter }

        $Order.Keys[0]|should -Be 'aa*'
        $order.'aa'.count|should -Be $filterItems.count
    }

    it "should create a bucket after default if an filter has been defined after '...'" -TestCases $TestCase {
        param(
            [string]$ItemType
        )
        $filter = 'aa*'
        New-Item -Path $testdrive -ItemType "sort" -ItemType File -Value (@("...",$filter) -join "`n")
        $items = Get-TestDriveItem -ItemType $ItemType
        $Order = $items | Group-DeployItem -verbose:$false
        $filterItems = $items | ? { $_.name -like $filter }

        $Order.Keys[1]|should -Be 'aa*'
        $order.'aa'.count|should -Be $filterItems.count
    }

    # it "should put aa <ItemType> first when order has 'zz*' at top" -TestCases $TestCase {
    #     param(
    #         [string]$ItemType
    #     )
    #     New-Item -Path $testdrive -ItemType "sort" -ItemType File -Value "zz*" -Force
    #     $items = Get-TestDriveItem -ItemType $ItemType 
    #     $Order = $items | Update-DeploySorting -verbose:$false
    #     $Order[0].ItemType | Should -BeLike "zz*"
    # }

    # it "should put zz <ItemType> at bottom when order has 'zz*' after '...'" -TestCases $TestCase {
    #     param(
    #         [string]$ItemType
    #     )
    #     New-Item -Path $testdrive -ItemType "sort" -ItemType File -Value "...`nzz*" -Force
    #     $items = Get-TestDriveItem -ItemType $ItemType
    #     $Order = $items | Update-DeploySorting -verbose:$false
    #     $Order[-1].ItemType | Should -BeLike "zz*"
    # }

    # it "should put zz then aa <ItemType> before anything else if defined" -TestCases $TestCase {
    #     param(
    #         [string]$ItemType
    #     )
    #     New-Item -Path $testdrive -ItemType "sort" -ItemType File -Value "zz*`naa*" -Force
    #     $items = Get-TestDriveItem -ItemType $ItemType
    #     $Order = $items | Update-DeploySorting -verbose:$false
    #     $Order[0].ItemType | Should -BeLike "zz*"
    #     $Order[1].ItemType | Should -BeLike "aa*"
    # }

    # it "should delived the same amount of items it received" -TestCases $TestCase {
    #     param(
    #         [string]$ItemType
    #     )
    #     New-Item -Path $testdrive -ItemType "sort" -ItemType File -Value "zz*`naa*" -Force
    #     $items = Get-TestDriveItem -ItemType $ItemType
    #     $Order = $items | Update-DeploySorting  -verbose:$false
    #     $Order.Count | Should -Be $items.Count
    # }


}