function Get-BicepVersion {
    [CmdletBinding(
        # defaultParameterSetName = '__AllParameterSets'
    )]
    param (
        [ValidateSet(
            'All',
            'Latest',
            'Lowest'
        )]
        [string]$What = 'All'
    )

    $releases = Invoke-WebRequest -uri 'https://github.com/Azure/bicep/tags'
    $releases = $releases.Content -split '\n' | Where-Object { $_ -match 'a class="Link--muted" href="/Azure/bicep/releases/tag/.*"' }
    $VersionList = $releases | Select-Object -Unique | ForEach-Object {
        $out = $_ -replace '.*tag/', '' -replace '".*', ''
        $out.trim().Substring(1)
    }

    if ($What -eq 'Lowest') {
        return $VersionList | Select-Object -Last 1
    }
    if ($What -eq 'Latest') {
        return $VersionList | Select-Object -First 1
    }

    return $VersionList
}
