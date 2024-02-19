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
        $hash = Get-FileHash -Path $item -Algorithm SHA256
        $hash|convertto-json|Out-File (join-path $psake.build_script_dir $_.name -AdditionalChildPath "hash.json")
    }
}

task compress -depends generateHash {
    $Folders | ForEach-Object {
        $folder = $_
        $zip = "$folder.zip"
        $path = join-path $psake.build_script_dir $zip
        if (Test-Path $zip) {
            Remove-Item $zip
        }
        Compress-Archive -Path $folder -DestinationPath $zip
    }
}