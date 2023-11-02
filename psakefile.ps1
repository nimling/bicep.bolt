using namespace System.IO

Properties{
    $source = @{
        path = "$PSScriptRoot/src"
        monorepo_basefile = "main.ps1"
    }
    $json_schema = @{
        enabled = $true
        directory = join-path $source.path "schema"

        path = "root.json"
        target_path = "bolt.schema.json"

        #if you need to generate extra schemas, like for environment variables
        #key is the path to the schema file, value is the path to the schema file to generate
        #no docs will be generated for these files
        #keys will be loaded and checked for errors
        extra_schemas = @{
            "deploy/environments.json" = "bolt.env.schema.json"
        }

        #files to load and check for errors before building schema
        verify_files = @(
            "bicep.json",
            "remote.json",
            "deploy/deploy.json"
        )

        #generate example file using schema defaults
        generate_example = $true
        #will be joined with $target.path
        target_example_path = "bolt.json"

        #generate docs using njsonschema
        generate_docs = $true
        docs_title = "Bolt Schema"
        #will be joined with $target.path
        target_docs_path = "bolt-schema.md"
    }

    $scriptAnalyzer = @{
        #version of module
        version      = "1.21.0"
        #settings that can be used to automatically fix issues, like 'PSAvoidUsingCmdletAliases' so ex: % gets converted to foreach-object.
        #will be used before settings is checked
        fix_Settings = "$PSScriptRoot/PSScriptAnalyzerSettings-fix.psd1"
        #normal settings file. if filled in will be used as part of the process
        settings     = "$PSScriptRoot/PSScriptAnalyzerSettings.psd1"
    }

    $monorepo = @{

    }
    
    #starterpack settings
    $target = @{
        #starterpack path
        path = "$PSScriptRoot/starterpack"

        #data that is processed and combined goes here
        data = @{}
        
        # monorepo_basefile = "main.ps1"

    }
    $test = @{

    }
}

include "$PSScriptRoot/buildfunctions/psake/functions.ps1"
Include "$PSScriptRoot/buildfunctions/psake/jsonschema.psake.ps1"
Include "$PSScriptRoot/buildfunctions/psake/starterpack.psake.ps1"

task default -depends pre_flight

task pre_flight -depends verify -description "Pre-flight checks" {
    Write-host "Pre-flight checks completed"
}

task verify -description "Verify that all required properties are set"  -depends verify_json_schema {
    Write-host "Verification completed"
}

task import_modules -depends Import_scriptanalyzer {
    Write-host "Modules imported"
}

Task Import_scriptanalyzer -description "Import PSScriptAnalyzer module" {
    param(
        [string]$Version = $scriptanalyzer.version
    )

    $Module = Get-Module -Name PSScriptAnalyzer -ListAvailable
    $download = [bool]$Module
    if ($Module) {
        $download = $Module.Version -lt $Version
    }

    if ($download) {
        $Module = Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force -AllowClobber -RequiredVersion $Version -ErrorAction SilentlyContinue
    }
}