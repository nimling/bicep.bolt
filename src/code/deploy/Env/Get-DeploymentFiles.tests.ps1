Describe "Get-DeploymanetFiles" {
    BeforeDiscovery {
        $testcases = @(
            @{
                name      = "SubscriptionJson"
                content   = @{'$schema' = 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#' } | convertto-json
                extension = "json"
                count     = 1
            }
            @{
                name      = "ResourcegroupJson"
                content   = @{'$schema' = 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#' } | convertto-json
                extension = "json"
                count     = 1
            }
            @{
                name      = "bicep"
                content   = ""
                extension = "bicep"
                count     = 1
            }
        )
    }
    BeforeEach {
        #Generate random files
        for ($i = 0; $i -lt 4; $i++) {
            "" | out-file -FilePath "$testdrive/$([System.IO.Path]::GetRandomFileName())" -Encoding utf8
        }
    }
    AfterEach {
        #clean out testdrive for next test
        Get-ChildItem $testdrive | Remove-Item -Force -Recurse
    }
    context Unit -Tag 'Unit' {
        it "it should find <name> files" -TestCases $testcases {
            param(
                [string]$name,
                [string]$content,
                [string]$extension,
                [int]$count
            )
            for ($i = 0; $i -lt $count; $i++) {
                $random = [System.IO.Path]::GetRandomFileName().Replace(".","")
                $content | out-file -FilePath "$testdrive/$name$random.$extension" -Encoding utf8
            }
            $result = Get-DeploymentFile -Path $testdrive
            $result.count | Should -Be $count
            $result|ForEach-Object{
                $_.Extension| Should -Be ".$extension"
            }
        }
    }
}