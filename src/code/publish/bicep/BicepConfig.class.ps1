# class bicepConfig_experimental{
#     [bool]$symbolicNameCodegen = $false
# }

class bicepConfig {
    $analyzers
    [string]$cacheRootDirectory
    $cloud
    $formatting
    $moduleAliases
    [hashtable]$experimentalFeaturesEnabled

    [bool] symbolicNameCodegenEnabled(){
        return ($this.experimentalFeaturesEnabled.symbolicNameCodegen -eq $true)
    }
}