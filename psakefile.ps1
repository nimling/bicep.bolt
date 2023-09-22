properties {
    $source_dir = "$PSScriptRoot/src"
    $Source = @{
        #directory
        dir             = $source_dir

        # all items that will be used to generate the monoscript. this is the file that contains all of the functions used in conjuction with monoscript_base
        # ex: all code in the folder /code
        items           = Get-ChildItem "$source_dir/code/*.ps1" -Recurse -Exclude "*.tests.ps1"

        #filter to use when collecting functions. this is useful for ignoring files that are not functions. this will also be used to remove items from the stage folder
        where_filter    = { $_.FullName -notlike '*ignore*' }

        #Filter to identity class files. these will be loaded before anything is loaded from the monoscript and when i run pester tests
        class_filter    = "*.class.ps1"

        #the base file that will be filled in to create the monoscript. usually the main script.
        #starting at source_dir
        monoScript_base = "/main.ps1"
    }
    $source_monoscript_path = join-path $source_dir $source.monoscript_base

    if ($source.where_filter) {
        $source.items = $source.items | Where-Object $source.where_filter
    }

    $Stage = @{
        #TODO figure out a way 

        dir           = "$PSScriptRoot/.stage"
        # #will tidy up items in stage.dir. this is useful for removing items that are not needed in the final product
        # remove_items_scriptblock = {Get-ChildItem "$PSScriptRoot/src/code/*.ps1" -Recurse -Exclude "*.tests.ps1" | Where-Object { $_.FullName -notlike '*ignore*' }}

        #all items from source.dir will be copied to stage.dir
        #items to exclude from copy
        exlude_filter = @(
            "*.tests.ps1"
            "*.json?"
            "*.md"
        )
    }
    $pester = @{
        #if set, it will set this as a global before importing and testing code.
        #this is useful for assuring no unintended side effects from code (ie loading another config if switch is set or disabling certain features)
        pester_switch = "pester_enabled"

        #tags to run. it will also run tests that have no tags, but it can help to identity issues with specific tests
        tags          = @(
            "general"
        )
    }
    $scriptAnalyzer = @{
        #version of module
        version      = "1.21.0"
        #settings that can be used to automatically fix issues, like 'PSAvoidUsingCmdletAliases' so ex: % gets converted to foreach-object.
        #will be used before settings is checked
        fix_Settings = "$PSScriptRoot/PSScriptAnalyzerSettings.psd1"
        #normal settings file. if filled in will be used as part of the process
        settings     = "$PSScriptRoot/PSScriptAnalyzerSettings.psd1"
    }

    #settings for the monoscript. this is the file that contains all of the other code. it will be added to target.folder using the name in monoscript_settings.name
    $monoscript_settings = @{
        name                     = "Bolt.ps1"
        collect_using_statements = $true

        #will add requires at top when generating monoscript
        assure_requires          = @{
            region_name = "requires"
            version     = "7.2"
            modules     = @()
            runAsAdmin  = $false
        }
        #if defined, will remove all items that are within regions with this name. 
        #can be used to define a "import feature" when you develop a module and want to remove it when you build the monoscript
        remove_tag               = "remove_on_build"

        #where in the monoscript to import items. 
        #you have to define a region with this name in the monoscript_base file
        #using items
        using_tag                = "using"
        #function items
        functions_tag            = "function"
        #class items
        class_tag                = "class"
        #buildversion item
        buildversion_tag         = "build"
        buildversion_variable    = "BuildId"
    }
    $target = @{
        version      = (get-date).tostring("0.2.yyMMdd")
        folder       = "$PSScriptRoot/starterpack"
        template     = "$PSScriptRoot/template"
        make_zip     = $true
        import_items = @{
            docs = "$PSScriptRoot/docs"
        }
        schema       = @{
            path                         = "$PSScriptRoot/bolt.schema.json"
            include_schema_in_target     = $true
            #generate example file
            generate_example             = $true
            example_name                 = "bolt.json"
            #if set to to true, will add $schema to the example file.
            set_schema_in_example        = $true
            #if set to true, will link to external path, else it will link to local file
            link_schema_to_external_path = $false
            external_path                = 'https://raw.githubusercontent.com/nimling/bicep.bolt/main/starterpack/bolt.schema.json'

            #will create markdown file with schema documentation.
            #this will either be put in target.import_items.docs or in target.folder (depending on if target.import_items.docs is set)
            generate_docs                = $true
            #title of the documentation. if not set, it will use basename of docs_name
            docs_title                   = "Bolt"
            docs_file_name               = "bolt-schema.md"

            #if defined, will will also save the documentation to this path (good to update project docs)
            docs_added_save_locations = "$PSScriptRoot/docs"
        }
    }
}

Include "$PSScriptRoot/psakefile.functions.ps1"

Task default -depends pre_flight_checks, Test, stage, collect, make_target, remove_stage_folder  #, setup, build, Teardown

Task test -depends ScriptAnalyzer, pester #-> done before any copy'
# Task Setup -depends stage  #-> copy and prep

# Task GenerateDocs #-> generate docs
# Task Collect -depends collect_using_statements, collect_functions, collect_main, collect_classes #-> collect all functions
# Task Generate -depends Collect, compress_starterpack, generate_target
# Task Build -depends Setup, Collect, Generate #-> build, generate docs
# Task Teardown -depends remove_build_folder  #-> after build


#region pre-flight-checks
Task pre_flight_checks -depends verfy_target, verify_source, verify_stage, verify_monoscript_regions , verify_properties, Import_scriptanalyzer

Task verify_source {
    param(
        [System.IO.FileInfo]$sourceDir = $source.dir
    )
    Assert (test-path $sourceDir) "source.dir ($($sourceDir)) must exist"
    Assert ($source.items.Count -gt 0) 'source.items must have at least one item'
    Assert (Test-Path $source_monoscript_path) 'source.monoScript_base must exist'
    Assert ($source.monoScript_base -like "*.ps1") 'source.monoScript_base be a .ps1 file'
}

Task verify_stage {
    #verify exlude filter doesn't exclude everything
    # if ($Stage.exlude_filter) {
    #     Assert (get-)
    # }
}

Task verfy_target {
    $schema = $traget.schema
    if ($schema.generate_docs) {
        Assert (test-path $schema.path) 'target.schema.path must exist if you want to generate documentation'
        Assert (-not [string]::IsNullOrEmpty($schema.docs_file_name)) 'target.schema.docs_file_name must be defined if you want to generate documentation'
    }
}

Task verify_monoscript_regions {
    $script_content = get-item (join-path $source.dir $source.monoScript_base) | get-content -raw

    foreach ($item in $monoscript_settings.GetEnumerator() | where { $_.key -like "*_tag" }) {
        if (!$item.Value) {
            throw "you need to define a value for $($item.key)"
        }
        $region = Get-ScriptRegions -ScriptContent $script_content -RegionName $item.value
        if (!$region) {
            # Write-Verbose (($script:Main | select -first 100) -join "`n")
            write-warning "missing '#region $($item.value)' in $(split-path $source.monoScript_base -leaf)"
            throw "missing region. check warning above"
        }
    }
}

Task verify_properties {
    Assert ($monoscript_settings.name -like "*.ps1") 'monoscript_settings.name must end in .ps1' 
}

Task Import_scriptanalyzer {
    $Module = Get-Module -Name PSScriptAnalyzer -ListAvailable
    $download = [bool]$Module
    if ($Module) {
        $download = $Module.Version -lt $scriptanalyzer.version
    }

    if ($download) {
        $Module = Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force -AllowClobber -RequiredVersion $scriptanalyzer.version -ErrorAction SilentlyContinue
    }
}
#endregion pre-flight checks

#region scriptanalyzer
Task scriptAnalyzer -depends scriptAnalyzer_fix_common_issues, scriptAnalyzer_run

# fixes common isses, like % -> foreach-object, if settings is filled in
Task scriptAnalyzer_fix_common_issues -precondition { -not [string]::IsNullOrEmpty($scriptanalyzer.fix_settings) } {
    $items = @(
        $source.items
        get-item $source_monoscript_path
    )
    $l = $items | Invoke-ScriptAnalyzer -settings $ScriptAnalyzer.fix_Settings -Fix
}

# runs scriptanalyzer, if settings is filled in
Task scriptAnalyzer_run { -not [string]::IsNullOrEmpty($scriptanalyzer.settings) } {
    $items = @(
        $source.items
        get-item $source_monoscript_path
    )

    $scriptAnalyzer_result = $items | Invoke-ScriptAnalyzer -Settings $scriptAnalyzer.settings -Verbose:$false

    $scriptAnalyzer_result | Format-Table -AutoSize
    if ($scriptAnalyzer_result.Count -gt 0) {
        throw "ScriptAnalyzer failed"
    }
}
#endregion scriptanalyzer'

#region pester
Task pester {
    if ($pester.pester_switch) {
        Write-Verbose "Setting global switch '$($pester.pester_switch)'"
        Set-Variable -Scope Global -Name $pester.pester_switch -Value $true
    }

    $Load = [ordered]@{}

    #add class files first
    if ($source.class_filter) {
        $load.class = $source.items | Where-Object { $_.name -like $source.class_filter }
    }

    #then the rest
    $load.script = $source.items | Where-Object { $_.name -notlike $source.class_filter }

    #import items (they will be loaded only in this task)
    $load.GetEnumerator() | ForEach-Object {
        Write-verbose "Loading $($_.key)"
        $_.value | ForEach-Object {
            try {
                . $_.FullName
            } catch {
                if ($pester.pester_switch) {
                    Write-Verbose "Setting global switch '$($pester.pester_switch)' to false"
                    Set-Variable -Scope Global -Name $pester.pester_switch -Value $false
                }
                Write-Warning "Error loading $($_.FullName):`n$_"
                throw $_
            }
        }
    }

    $Monoscript_path = join-path $Source.dir $Source.monoScript_base

    #Find all cmdlets inside monoscript
    (get-command $Monoscript_path).ScriptBlock.Ast.FindAll(
        {
            param($ast)
            $ast -is [System.Management.Automation.Language.FunctionDefinitionAst]
        }, $true
    )|ForEach-Object{
        #Create scriptblock of cmdlets extent
        $cmdlet = [scriptblock]::Create($_.extent.text)
        Write-verbose "dot-sourcing $($_.name) from monoscript"
        #dotsource it into the current scope
        . $cmdlet
    }
    # Write-verbose

    $results = 0
    $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    foreach ($tag in $pester.tags) {
        Write-Host "Running $test tests"
        $pester_result = Invoke-Pester -Path $SourceDir -PassThru -TagFilter $tag 
        if ($pester_result.FailedCount -gt 0) {
            if ($pester.pester_switch) {
                Write-Verbose "Setting global switch '$($pester.pester_switch)' to false"
                Set-Variable -Scope Global -Name $pester.pester_switch -Value $false
            }
            throw "$($pester.FailedCount) '$tag' tests failed"
        }
        $result += $pester_result.PassedCount
    }

    Write-verbose "Running untagged tests"
    $pester_result = Invoke-Pester -Path $SourceDir -PassThru -ExcludeTagFilter $pester.tags
    if ($pester_result.FailedCount -gt 0) {
        if ($pester.pester_switch) {
            Write-Verbose "Setting global switch '$($pester.pester_switch)' to false"
            Set-Variable -Scope Global -Name $pester.pester_switch -Value $false
        }
        throw "$($pester_result.FailedCount) untagged tests failed"
    }
    $results += $pester_result.PassedCount
    Write-Verbose "Took $($Stopwatch.Elapsed.TotalSeconds) seconds, $results tests passed"

    if ($pester.pester_switch) {
        Write-Verbose "Setting global switch '$($pester.pester_switch)' to false"
        Set-Variable -Scope Global -Name $pester.pester_switch -Value $false
    }
}
#endregion pester

#region stage
task stage -depends prep_stage_dir, copy_to_stage_dir

Task prep_stage_dir {
    if (test-path $stage.dir) {
        Write-Verbose "cleaning stage dir"
        Get-ChildItem $stage.dir | remove-item -Force -Recurse
    } else {
        Write-Verbose "creating stage dir"
        New-Item -Path $stage.dir -ItemType Directory
    }
}

Task copy_to_stage_dir -depends prep_stage_dir {
    $param = @{
        Destination = $stage.dir
        Force       = $true
        Recurse     = $true
    }
    if ($stage.exlude_filter.count -gt 0) {
        $param.Exclude = $stage.exlude_filter
    }
    Get-ChildItem $source.dir | copy-item @param
}

task clean_stage_environment {}

task remove_stage_folder -precondition { test-path $stage.dir } -action {
    Write-Verbose "removing stage dir"
    get-item $stage.dir | remove-item -Force -Recurse
}
#endregion stage

#region collect
task collect -depends collect_init, collect_using_statements, collect_functions, collect_classes, collect_main

task collect_init -action {
    $global:collections = @{
        using     = @{}
        functions = @{}
        classes   = @{}
        main      = @{}
    }
}

task collect_using_statements -action {
    $using = $global:collections.using
    # $script:UsingStatements = @{}
    Get-ScriptFiles -Directory $stage.dir -Kind scripts | ForEach-Object {
        (get-command $_.fullname).ScriptBlock.Ast.UsingStatements | ForEach-Object {
            $statement = $_
            switch ($statement.UsingStatementKind) {
                'Namespace' {
                    $using[$statement.name] = $statement.UsingStatementKind
                }
                default {
                    throw "Unknown using statement (you should update build script, dude): $_"
                }
            }
        }
    }

    Write-host "found $($using.count) using statements"
}

task collect_functions -action {
    $functions = $global:collections.functions
    Get-ChildItem $stage.dir -Filter "*.ps1" -Exclude "*.class.ps1", "main.ps1" -Recurse | % {
        $Path = $_.fullname
        (get-command $Path).ScriptBlock.Ast.FindAll(
            {
                param($ast)
                $ast -is [System.Management.Automation.Language.FunctionDefinitionAst]
            }, $true
        ) | ForEach-Object {
            $functions[$_.name] = @{
                path   = $Path
                script = $_.extent.text
            }
        }
    }

    if ($functions.count -eq 0) {
        throw "No functions found"
    }
    write-host "found $($functions.count) functions"
}

task collect_classes -precondition { $source.class_filter } -action {
    $classes = $global:collections.classes

    gci $stage.dir -Filter $source.class_filter -Recurse | % {
        $Path = $_.fullname
        (get-command $Path).ScriptBlock.Ast.FindAll(
            {
                param($ast)
                $ast -is [System.Management.Automation.Language.TypeDefinitionAst]
            }, $true
        ) | % {
            $classes[$_.name] = @{
                path   = $Path
                script = $_.extent.text
            }
        }
    }

    if ($classes.count -eq 0) {
        throw "No classes found"
    }
    write-host "found $($classes.count) classes"
}

task collect_main {
    #cannot find comments via AST. need to use the old way
    $base_name = (get-item (join-path $stage.dir $source.monoScript_base)).name
    $path = gci -Path $stage.dir -Filter $base_name -Recurse | Select-Object -First 1 -ExpandProperty fullname
    if (!$path) {
        throw "Cannot find main script '$($base_name)' in stage.dir '$($stage.dir)'"
    }
    $Main = Get-Content $path
    if ($monoscript_settings.remove_tag) {
        Get-ScriptRegions -ScriptContent ($Main -join "`n") -RegionName $monoscript_settings.remove_tag | ForEach-Object {
            Write-host "Removing lines $($_.start) to $($_.end) in main"
            for ($i = $_.start; $i -le $_.end; $i++) {
                $Main[$i - 1] = $null
            }
        }
    }
    $global:Monoscript = $Main | Where-Object { $_ -ne $null }
}
#endregion collect


#region target
task make_target -depends init_target, copy_items, generate_schema_example, generate_target, generate_json_schema_doc, compress_starterpack
task copy_items -depends copy_template_to_target, copy_import_items_to_target, copy_schema_to_target


task init_target {
    if (test-path $target.folder) {
        Get-ChildItem $target.folder | remove-item -Force -Recurse
    } else {
        New-Item $target.folder -ItemType Directory -Force | out-null
    }
}

task copy_schema_to_target -precondition { $target.schema.include_schema_in_target } -action {
    get-item $target.schema.path | copy-item -Destination $target.folder -Force
}

task generate_schema_example -precondition { $target.schema.generate_example } -action {
    $example_path = join-path $target.folder $target.schema.example_name
    $schema_item = get-item $target.schema.path
    $import = [NJsonSchema.JsonSchema]::FromFileAsync($schema_item.FullName)
    $schema = $import.Result
    $json = $schema.ToSampleJson().ToString()
    
    #if im gonna set schema
    if ($target.schema.set_schema_in_example) {
        Write-host "setting `$schema in json document"
        $object = $json | Convertfrom-json -AsHashtable

        #create a new object to make sure $shema is the first property
        $newobj = [ordered]@{}
        #if the schema is external
        if ($target.schema.link_example_to_external_path) {
            Write-host "linking to external schema"
            $newobj.'$schema' = $target.schema.external_path
        }
        #link to the imported schema
        elseif ($target.schema.include_schema_in_target) {
            Write-host "linking to local schema"
            $newobj.'$schema' = "./$($schema_item.Name)"
        } else {
            throw "You need to set either link_example_to_external_path or include_schema_in_target to true. cant set `$schema to something that is not imported in target"
        }
        $object.getenumerator() | ForEach-Object {
            $newobj[$_.key] = $_.value
        }

        $json = $newobj | ConvertTo-Json -Depth 100
    }

    $json | out-file (join-path $target.folder $target.schema.example_name) -Force
}

task compress_starterpack -precondition { $target.make_zip } -action {
    $Name = (get-item $target.folder).Name
    $ZipPath = (join-path $Target.folder "$Name.zip")
    Write-host "Compressing starterpack -> $ZipPath"
    Get-ChildItem $target.folder | Compress-Archive -DestinationPath $ZipPath -Force
}

task copy_template_to_target -precondition { $target.template } {
    Get-ChildItem $target.template | copy-item -Destination $target.folder -Force -Recurse
}

task copy_import_items_to_target -precondition { $target.import_items } {
    foreach ($item in $target.import_items.GetEnumerator()) {
        $item_name = $item.key
        $item_path = $item.value
        if (test-path $item_path) {
            Write-host "copying $item_name to $($target.folder)"
            Get-item $item_path | copy-item -Destination $target.folder -Force -Recurse
        } else {
            Write-Warning "Cannot find $item_name at $item_path"
        }
    }
    start-sleep -Milliseconds 300
}


Task generate_json_schema_doc -precondition { (test-path $target.schema.path) -and ($target.schema.generate_docs) } -action {
    $targetFolder = $target.folder

    Write-Host "Generating json schema documentation"
    $TargetMd = join-path $targetFolder $target.schema.docs_file_name
    $Title = $target.schema.docs_title? $target.schema.docs_title : ([fileinfo]$target.schema.docs_file_name).BaseName
    New-JsonSchemaDoc -Schema $target.schema.path -Title $Title -OutFile $TargetMd
    $target.schema.docs_added_save_locations|%{
        Get-Item $TargetMd | Copy-Item -Destination $_ -Force
    }
}

task generate_target {
    $BuildId = (get-date).tostring("$Build.yyMMdd")
    $import = @(
        @{
            name    = $monoscript_settings.using_tag
            content = $global:collections.using.getEnumerator() | ForEach-Object {
                "using $($_.value) $($_.key)".tolower()
            } | select -Unique
        }
        @{
            name    = $monoscript_settings.functions_tag
            content = $global:collections.functions.getEnumerator() | ForEach-Object {
                $Path = [System.IO.Path]::GetRelativePath($Source.dir, $_.value.path)
                # $path = $Path -replace "\.ps1$",""
                (@("#region $Path", $_.value.script, "#endregion", ""))
            }
        }
        @{
            name    = $monoscript_settings.class_tag
            content = $global:collections.classes.getEnumerator() | ForEach-Object {
                $Path = [System.IO.Path]::GetRelativePath($Source.dir, $_.value.path)
                # $path = $Path -replace "\.ps1$",""
                (@("#region $Path", $_.value.script, "#endregion", ""))
            }
        }
        @{
            name    = $monoscript_settings.buildversion_tag
            content = @('$' + $monoscript_settings.buildversion_variable + "=" + "'"+$target.version+"'")
        }
    )

    foreach ($region_definition in $import) {
        $content = $region_definition.content

        Write-host "handling region $($region_definition.name). found $($content.count) lines"

        #getting region in main.ps1
        $region = Get-ScriptRegions -ScriptContent ($global:Monoscript -join "`n") -RegionName $region_definition.name
        if (!$region) {
            Write-Verbose (($global:Monoscript | Select-Object -first 100) -join "`n")
            throw "missing '#region $($region_definition.name)' in main.ps1"
        }

        if ($region.start -lt 1) {
            $start = $global:Monoscript[0]
        } else {
            $Start = $global:Monoscript[0..($region.start - 1)]
        }
        $end = $global:Monoscript[($region.end - 1)..($global:Monoscript.count - 1)]
        $global:Monoscript = $Start + $content + $end
    }

    $global:Monoscript = (@("#BUILD $($target.version)") + $global:Monoscript) -join [System.Environment]::NewLine
    $targetFile = join-path $Target.folder $monoscript_settings.name
    Write-host "Creating target file $targetFile ($(($global:Monoscript  -split "`n").count) lines including empty lines and regions))"
    $global:Monoscript | Out-File $targetFile -Force
    get-item $targetFile
}

#endregion target
