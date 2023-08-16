function Get-BicepVersions {
    [CmdletBinding()]
    param (
        
        [switch]$Latest,
        [switch]$Lowest
    )

    $releases = Invoke-WebRequest -uri 'https://github.com/Azure/bicep/tags'
    $releases = $releases.Content -split '\n' | Where-Object { $_ -match 'a class="Link--muted" href="/Azure/bicep/releases/tag/.*"' }
    $VersionList = $releases | select -Unique | ForEach-Object {
        $out = $_ -replace '.*tag/', '' -replace '".*', ''
        $out.trim().Substring(1)
    }

    if ($Lowest) {
        return $VersionList | Select-Object -Last 1
    }
    if ($Latest) {
        return $VersionList | Select-Object -First 1
    }

    return $VersionList
}
