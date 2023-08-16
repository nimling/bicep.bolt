Properties {
    $SourceDir = "$PSScriptRoot/src"
    $Build = "0.2"
    $Target_ScriptName = "Bolt.ps1"
    $Target = [System.IO.Path]::GetFullPath("$PSScriptRoot/../starterpack")
    $Target_Items = @{
        doc = [System.IO.Path]::GetFullPath("$PSScriptRoot/../docs")
    }
    $FolderTemplate = [System.IO.Path]::GetFullPath("$PSScriptRoot/../templates")
    #note fix generation of array items before going 'all'
    [ValidateSet(
        "minimal",
        "all"
    )]
    $deployconfig_size = "minimal"
    
    $BuildDir = "$PSScriptRoot/.build"
    $GithubRaw = "https://raw.githubusercontent.com/nimling/badu/main/"
}

Include "$PSScriptRoot/psakefile.functions.ps1"

Task default -depends Test, setup, build, Teardown

Task Test -depends ScriptAnalyzer, pester_tests #-> done before any copy
# Task Setup -depends copy_to_build_dir #-> copy and prep
# Task GenerateDocs #-> generate docs
# Task Collect -depends collect_using_statements, collect_functions, collect_main, collect_classes #-> collect all functions
# Task Generate -depends Collect, compress_starterpack, generate_target
# Task Build -depends Setup, Collect, Generate #-> build, generate docs
# Task Teardown -depends remove_build_folder  #-> after build

Task clean_build_dir {
    if (test-path $buildDir) {
        Get-ChildItem $buildDir | remove-item -Force -Recurse
    }
}

Task copy_to_build_dir -depends clean_build_dir {
    Get-ChildItem $sourceDir | copy-item -Recurse -Destination $buildDir -Force -Exclude "*.tests.ps1", "*.json?", "*.md"
}

Task verify_properties {
    Assert ($Target -like "*.ps1") '$Target must be a powershell file' 
}

Task pester_tests {
    $files = Get-ChildItem "$SourceDir/code/*.ps1" -Recurse -Exclude "*.tests.ps1" | ? { $_.FullName -notlike '*ignore*' }
    Write-host  "Importing $($files.count) files"
    $files | ForEach-Object {
        $item = $_
        try {
            . $item.FullName
        } catch {
            Write-Warning "Error loading $($item.FullName):`n$_"
            throw $_
        }
    }

    $Tests = @("General", "Unit", "Integration")
    $results = 0
    $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    foreach ($test in $Tests) {
        $pester = Invoke-Pester -Path $SourceDir -PassThru -TagFilter $test 
        if ($pester.FailedCount -gt 0) {
            throw "$($pester.FailedCount) $test tests failed"
        }
        $result += $pester.PassedCount
    }

    $pester = Invoke-Pester -Path $SourceDir -PassThru -ExcludeTagFilter $Tests
    if ($pester.FailedCount -gt 0) {
        throw "$($pester.FailedCount) untagged tests failed"
        $result += $pester.PassedCount
    }
    Write-Host "Took $($Stopwatch.Elapsed.TotalSeconds) seconds, $result tests passed"
}

Task ScriptAnalyzer {
    $scriptAnalyzer = Get-ChildItem -Path $SourceDir -Filter "*.ps1" -Exclude "*.tests.ps1" -Recurse | ? { $_.FullName -notlike '*ignore*' } | Invoke-ScriptAnalyzer -Settings (join-path $PSScriptRoot "PSScriptAnalyzerSettings.psd1") -Verbose:$false 
    # $scriptAnalyzer = Invoke-ScriptAnalyzer -Path $SourceDir -Settings (join-path $PSScriptRoot "PSScriptAnalyzerSettings.psd1") -Verbose:$false 
    $scriptAnalyzer | Format-Table -AutoSize
    if ($scriptAnalyzer.Count -gt 0) {
        throw "ScriptAnalyzer failed"
    }
}

task collect_using_statements -action {
    $script:UsingStatements = @{}
    Get-ScriptFiles -Directory "$BuildDir" -Kind scripts | ForEach-Object {
        (get-command $_.fullname).ScriptBlock.Ast.UsingStatements | ForEach-Object {
            $statement = $_
            switch ($statement.UsingStatementKind) {
                'Namespace' {
                    $script:UsingStatements[$statement.name] = $statement.UsingStatementKind
                }
                default {
                    throw "Unknown using statement: $_"
                }
            }
        }
    }
    Write-host "found $($script:UsingStatements.count) using statements"
}

task collect_functions -action {
    $script:Functions = @{}

    gci "$BuildDir" -Filter "*.ps1" -Exclude "*.class.ps1", "main.ps1" -Recurse | % {
        $Path = $_.fullname
        (get-command $Path).ScriptBlock.Ast.FindAll(
            {
                param($ast)
                $ast -is [System.Management.Automation.Language.FunctionDefinitionAst]
            }, $true
        ) | % {
            $script:Functions[$_.name] = @{
                path   = $Path
                script = $_.extent.text
            }
        }
    }

    if ($script:Functions.count -eq 0) {
        throw "No functions found"
    }
    write-host "found $($script:Functions.count) functions"
}

task collect_classes -action {
    $script:Classes = [ordered]@{}

    gci "$BuildDir" -Filter "*.class.ps1" -Recurse | % {
        $Path = $_.fullname
        (get-command $Path).ScriptBlock.Ast.FindAll(
            {
                param($ast)
                $ast -is [System.Management.Automation.Language.TypeDefinitionAst]
            }, $true
        ) | % {
            $script:Classes[$_.name] = @{
                path   = $Path
                script = $_.extent.text
            }
        }
    }

    if ($script:Classes.count -eq 0) {
        throw "No classes found"
    }
    write-host "found $($script:Classes.count) classes"
}

task collect_main {
    #cannot find comments via AST. need to use the old way
    $path = get-item "$buildDir/main.ps1"
    $Main = Get-Content $path
    Get-ScriptRegions -ScriptContent ($Main -join "`n") -RegionName 'remove_on_build' | ForEach-Object {
        Write-host "Removing lines $($_.start) to $($_.end) in main"
        for ($i = $_.start; $i -le $_.end; $i++) {
            $Main[$i - 1] = $null
        }
    }
    $script:Main = $Main | Where-Object { $_ -ne $null }
}

#region starterpack
task clean_starterpack {
    if (test-path $Target) {
        Get-ChildItem $Target | remove-item -Force -Recurse
    } else {
        New-Item $Target -ItemType Directory -Force | out-null
    }
}

task collect_schema -depends clean_starterpack -action {
    get-item (join-path $PSScriptRoot "schema/deployconfig.schema.json") | copy-item -Destination $Target -Force
}

task generate_config -depends collect_schema -action {
    $schemaPath = "/starterpack/deployconfig.schema.json"
    $schema = $GithubRaw + $schemaPath
    $param = @{
        Schema              = (join-path $Target 'deployconfig.schema.json')
        outputPath          = (join-path $Target 'deployconfig.json')
        size                = $deployconfig_size
        referenceSchemaPath = "./deployconfig.schema.json"#$schema
    }
    New-JsonFromSchema @param -Verbose:$false
}

task collect_docs{
    get-item (join-path $PSScriptRoot "docs") | copy-item -Destination $Target -Force -Recurse
}

task compress_starterpack -depends clean_starterpack,collect_schema,generate_config,collect_docs,generate_target {
    $ZipPath = (join-path $Target "starterpack.zip")
    Write-host "Compressing starterpack -> $ZipPath"
    Get-ChildItem $target|Compress-Archive -DestinationPath $ZipPath -Force
}
#endregions

task generate_target {
    $BuildId = (get-date).tostring("$Build.yyMMdd")
    @(
        @{
            name    = "using"
            content = $script:UsingStatements.getEnumerator() | ForEach-Object {
                "using $($_.value) $($_.key)".tolower()
            } | select -Unique
        }
        @{
            name    = "functions"
            content = $script:Functions.getEnumerator() | ForEach-Object {
                $Path = [System.IO.Path]::GetRelativePath($buildDir, $_.value.path)
                # $path = $Path -replace "\.ps1$",""
                (@("#region $Path", $_.value.script, "#endregion", ""))
            }
        }
        @{
            name    = "class"
            content = $script:Classes.getEnumerator() | ForEach-Object {
                $Path = [System.IO.Path]::GetRelativePath($buildDir, $_.value.path)
                # $path = $Path -replace "\.ps1$",""
                (@("#region $Path", $_.value.script, "#endregion", ""))
            }
        }
        @{
            name    = "buildId"
            content = @('$buildId = "' + $buildId + '"')
        }
    ) | % {
        $region_definition = $_
        $content = $region_definition.content

        Write-host "handling region $($region_definition.name). found $($content.count) lines"

        #getting region in main.ps1
        $region = Get-ScriptRegions -ScriptContent ($script:Main -join "`n") -RegionName $region_definition.name
        if (!$region) {
            Write-Verbose (($script:Main | select -first 100) -join "`n")
            throw "missing '#region $($region_definition.name)' in main.ps1"
        }

        $Start = $script:Main[0..($region.start - 1)]
        $end = $script:Main[($region.end - 1)..($script:Main.count - 1)]
        $script:Main = $Start + $content + $end
    }

    
    $script:Main = (@("#BUILD $BuildId") + $script:Main) -join [System.Environment]::NewLine
    $targetFile = join-path $Target $Target_ScriptName
    Write-host "Creating target file $targetFile ($(($script:Main  -split "`n").count) lines including empty lines and regions))"
    $script:Main | Out-File $targetFile -Force
    get-item $targetFile
}

#region remove 
task remove_build_folder -precondition { test-path $buildDir } -action {
    get-item $buildDir | remove-item -Force -Recurse
}
#endregion