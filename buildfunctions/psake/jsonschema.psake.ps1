using namespace System.IO

Include "$PSScriptRoot/jsonschema.functions.ps1"

task generate_json_schema -precondition { $json_schema.enabled } -depends json_schema_build, json_schema_docs

task verify_json_schema -precondition { $json_schema.enabled } -description 'verify json schema settings' {
    param(
        $SchemaDirectory = $json_schema.directory,
        $Schemapath = (Join-Path $json_schema.directory $json_schema.path),
        $TargetPath = $json_schema.target_path,
        $GenerateDocs = $json_schema.generate_docs,
        $DocsPath = $json_schema.target_docs_path,
        $GenerateExample = $json_schema.generate_example,
        $ExamplePath = $json_schema.target_example_path,
        [hashtable]$ExtraSchemaFiles = $json_schema.extra_schemas,
        [array]$VerifyFiles = $json_schema.verify_files
    )
    
    Write-verbose "Testing json schema directory '$SchemaDirectory'"
    Assert (test-path -Path $SchemaDirectory) "json schema directory '$SchemaDirectory' must exist"

    Write-verbose "Testing json schema file '$Schemapath'"
    Assert (test-path -path $Schemapath) "json schema file '$Schemapath' must exist"

    Write-verbose "Testing target path '$TargetPath'"
    Assert (-not [string]::IsNullOrEmpty($TargetPath)) 'target path for json schema must be defined'

    Write-verbose "Testing target path extension"
    Assert ($TargetPath -like "*.json" -or $TargetPath -like "*.jsonc") 'target path for json schema must end in .json or .jsonc'
    
    if ($GenerateDocs) {
        write-verbose "Testing json schema docs path '$DocsPath'"
        Assert (-not [string]::IsNullOrEmpty($DocsPath)) 'json_schema.schema.target_docs_path must be defined if you want to generate documentation'
    }
    if ($GenerateExample) {
        write-verbose "Testing json schema example path '$ExamplePath'"
        Assert (-not [string]::IsNullOrEmpty($ExamplePath)) 'json_schema.schema.target_example_path must be defined if you want to generate documentation'
    }

    if($ExtraSchemaFiles.count){
        foreach ($key in $ExtraSchemaFiles.Keys) {
            # $value = $ExtraSchemaFiles[$key]
            Write-verbose "Testing extra schema file '$key' with target '$($ExtraSchemaFiles.$key)'"
            $ExtraSchemaPath = Join-Path $SchemaDirectory $key
            Write-Verbose "Full path to extra schema file '$ExtraSchemaPath'"
            Assert (test-path -path $ExtraSchemaPath) "extra schema file '$key' must exist in '$SchemaDirectory'"
            # Assert (test-path -path $value) "extra schema target '$value' must exist"
        }
    }

    foreach ($file in $VerifyFiles) {
        Write-verbose "Testing source json schema file '$file'"
        $ThisSchemaPath = Join-Path $json_schema.directory $file
        Assert (test-path $ThisSchemaPath) "source json schema file '$ThisSchemaPath' must exist"
        $Async = [NJsonSchema.JsonSchema]::FromFileAsync($ThisSchemaPath)
        while (-not $Async.IsCompleted) {
            Start-Sleep -Milliseconds 100
        }
        if ($Async.IsFaulted) {
            Write-warning "Error while generating '$file' From Njsonschema:"
            $Async.Exception | % {
                Write-Warning $_.Message
            }
            throw "Error while building schema from $file"
        }

    }
}

task json_schema_build -depends verify_json_schema, prepare_starterpack {
    param(
        [DirectoryInfo]$JsonSchemaDirectory = $json_schema.directory, #(join-path $json_schema.directory $json_schema.path),
        [string]$JsonSchemaName = $json_schema.path,
        [DirectoryInfo]$Target = $Target.path,
        [string]$TargetName = $json_schema.target_path,
        [hashtable]$ExtraSchemaFiles = $json_schema.extra_schemas
    )

    $JsonToProcess = @{
        $JsonSchemaName = $TargetName
    }
    if($ExtraSchemaFiles.count){
        $JsonToProcess += $ExtraSchemaFiles
    }
    
    foreach($JsonSchemaItem in $JsonToProcess.GetEnumerator())
    {
        Write-Verbose "processing json schema '$($JsonSchemaItem.Key)'"
        $JsonSchemaPath = Join-Path $JsonSchemaDirectory $JsonSchemaItem.Key -Resolve
        $Async = [NJsonSchema.JsonSchema]::FromFileAsync($JsonSchemaPath)

        while (-not $Async.IsCompleted) {
            Start-Sleep -Milliseconds 100
        }
        if ($Async.IsFaulted) {
            Write-warning "Error while generating From Njsonschema:"
            $Async.Exception | % {
                Write-Warning $_.Message
            }
            throw "Error while generating From Njsonschema"
        }
        $OutSchema = $Async.Result

        $TargetPath = Join-Path $Target $JsonSchemaItem.Value
        $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
        [System.IO.File]::WriteAllLines($TargetPath, $OutSchema.ToJson(), $Utf8NoBomEncoding)
    }
}

task json_schema_docs -precondition { $json_schema.generate_docs -and $json_schema.enabled } -depends json_schema_build, prepare_starterpack {
    param(
        [System.IO.FileInfo]$schemaPath = (join-path $json_schema.directory $json_schema.path)
    )
    $outFile = join-path $target.path $json_schema.target_docs_path
    New-JsonSchemaDoc -OutFile $outFile -title $json_schema.docs_title -Schema $schemaPath
}

task json_schema_example -precondition { $json_schema.generate_example -and $json_schema.enabled } {

}
