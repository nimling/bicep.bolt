using namespace System.Collections.Generic
<#
.SYNOPSIS
returns a list of files or folders that matches the given environment

.DESCRIPTION
returns a list of files or folders that matches the given environment set in deployconfig.json. 
If no environment is set, all files and folders that are not tagged are returned (non-environment files).
If you have set a an environment, only files and folders that are tagged with that environment are returned.
There are two types of environments: scoped and non-scoped.
scoped environments are environments that are only valid in a specific scope, like dev, test, prod, etc.
non-scoped environments are environments that are valid in all scopes, like global, common, etc. as long as these are present, they will always be returned.
the matching happens on file/directory name. generally a "name.{environment}" notation is used, but this is not required if no environment is set in config.
if the file or folder name does not contain a dot, it is assumed to be a non-environment, meaning it is returned only when there are no active scoped environments.

if all is set, all non-enviornment items along with current environment items are returned. this is useful for situations where environment has been decided on a higher level, so you know everything is valid.

.PARAMETER environments
list of deploymented environments. from deployconfig.environments

.PARAMETER All
if set, all files and folders are returned. useful for situations where environment has been decided on a higher level, so you know everything is valid

.PARAMETER InputFolders
items of type System.IO.DirectoryInfo

.PARAMETER InputFiles
items of type System.IO.FileInfo

.EXAMPLE
gci $path -directory|Select-ByEnvironment -environments $deployconfig.environments

.NOTES
General notes
#>
function Select-ByEnvironment {
    param(
        # # [Parameter(Mandatory)]
        # [List[deployEnvironment]]$environments,

        # [switch]$All,

        [parameter(
            ValueFromPipeline,
            Mandatory,
            ParameterSetName = "folder")]
        [System.IO.DirectoryInfo]$InputFolders,

        [parameter(
            ValueFromPipeline,
            Mandatory,
            ParameterSetName = "file")]
        [System.IO.FileInfo]$InputFiles
    )
    begin {
        $environments = (Get-DeployConfig).environments
        $return = @()
        $envHasValues = $environments.Count -gt 0
        $hasScopedEnv = ($environments | Where-Object { $_.isScoped -eq $true }).count -gt 0
        if(!$envHasValues) {
            Write-BaduWarning "No environments is set in deployconfig.json. Please use environments for better control over what is deployed."
        }


        <#
        if has only nonscoped env: get all files/folders that does not have a dot in the name
        if has env, has scoped: get all files/folders that matches the env name and items that does not have a dot in the name
        either way. always ignore files/folders that ends with .ignore
        #>
    }
    process {
        #concat input files and folders. easier to work with
        $InputItems = @($InputFolders, $InputFiles)|Where-Object { $_}

        #either way. always ignore files/folders that ends with .ignore
        $InputItems = $InputItems | Where-Object { $_.basename -notlike "*.ignore" }

        #if no env values is present in deployconfig.json, return all items
        if(!$envHasValues){
            $return += $InputItems
            return
        }

        #always get items that are within the active scopes "whatever.{env}"
        $Environments | ForEach-Object {
            $envName = $_.name
            $InputItems | Where-Object { $_.basename -like "*.$envName" } | ForEach-Object {
                $return += $_
            }
        }

        #always get items that do not have a dot in the name
        $InputItems | Where-Object { $_.basename -notlike "*.*" } | ForEach-Object {
            $return += $_
        }
    }
    end {
        return $return |%{
            Write-BaduDebug "Select Env: $($PSCmdlet.ParameterSetName) '$($_.basename)' matches env filter"
            $_
        }| Select-Object -Unique
    }
}