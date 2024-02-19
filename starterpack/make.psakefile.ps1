Properties {
    $products = @(
        @{
            name="publish"
            script = "bolt.ps1"
        }
        @{
            name="deploy"
            script = "deploy.ps1"
        }
    )
}

Task default -depends generateHash, compress

task generateHash {
    $products | ForEach-Object {
        $folder = join-path $psake.build_script_dir $_.name
        $item = join-path $folder $_.script
        $hash = Get-FileHash -Path $item -Algorithm SHA256|select -ExcludeProperty Path
        $hash|convertto-json|Out-File (join-path $folder "hash.json") -Force
    }
}

task compress -depends generateHash {
    $products | ForEach-Object {
        $folder = $_.name
        Write-host "generating zip for $folder in $($psake.build_script_dir)"
        $zip = join-path $psake.build_script_dir "$folder.zip"
        if (Test-Path $zip) {
            Remove-Item $zip
        }
        Compress-Archive -Path $folder -DestinationPath $zip
    }
}