



#region using
using namespace System.Collections.Generic
using namespace System.io
using namespace System
#endregion using




#region requires
#requires -version 7.2.0
#endregion requires

<#
.DESCRIPTION
Bolt is a tool to help manage the lifecycle of bicep modules.
It is designed to be used in a CI/CD pipeline to help automate the process of publishing bicep modules to a registry.
It can also be used to help manage the lifecycle of bicep modules in a development environment, by setting version based on what changes have been made.

.PARAMETER Deploy
environment to deploy 

.PARAMETER Name(publish)
ONLY AVALIBLE IF 'PUBLISH' IS SELECTED. Name of module to publish. If not specified, all modules will be published


.PARAMETER Env(deploy)

.PARAMETER Dotsource
Sets script in a dot sourced context. This is used by all runspaces to import code from the main script. not used by users.
.NOTES
Author: Philip Meholm
#>
[CmdletBinding(
    SupportsShouldProcess
)]
param(
    [parameter(
        Position = 0,
        parameterSetName = "deploy"
    )]
    [switch]$Deploy,
    [switch]$Dotsource
)
dynamicparam {
    function Get-BoltConfig:Dynamic {
        [CmdletBinding()]
        param ()
        
        $path = gci $pwd.path -filter "bolt.json?" -file -recurse | select -first 1
        if (!$path) {
            throw "Could not find bolt.json in $($pwd.path)"
        }
        return get-content $path.fullname | convertfrom-json -AsHashtable
    }
    function Get-BoltParameterAttribute:Dynamic {
        [CmdletBinding()]
        param (
            [ValidateSet(
                "deploy-env",
                "deploy-name"
            )]
            [string]$parameter
        )
        
        begin {
            
        }
        
        process {
            #env
            if ($parameter -eq 'deploy-env') {
                # $keys = @(,'.')
                $configKeys = (Get-BoltConfig:Dynamic).deploy.environments.keys
                $keys = [string[]]::new($configKeys.count + 1)
                $keys[0] = '.'
                #easiest method of adding an array to another array
                $configKeys.CopyTo($keys, 1)
                Write-Debug "DynamicParam:Env: Environments count: $($keys.Count)"
                # $l =  
                # $l.ValidValues.AddRange($keys)  
                return [System.Management.Automation.ValidateSetAttribute]::new($keys)
            } elseif ($parameter -eq 'deploy-name') {
                $items = gci $pwd.path -filter "*.bicep" -file -recurse -Exclude "*.ignore.bicep"
                Write-Debug "DynamicParam:Name: Bicep files count: $($items.count)"
                return [System.Management.Automation.ValidateSetAttribute]::new(@($items.BaseName))
            }
        }
        
        end {
            
        }
    }

    #return item
    $paramDictionary = [Management.Automation.RuntimeDefinedParameterDictionary]::new()
    $envParamName = "Env"
    $envParamCollection = [System.Collections.ObjectModel.Collection[System.Attribute]]::new()
    $envParamCollection.Add(
        [System.Management.Automation.ParameterAttribute]@{
            Position         = 1
            Mandatory        = $false
            ParameterSetName = "deploy"
        }
    )

    $envParamCollection.Add((Get-BoltParameterAttribute:Dynamic -parameter 'deploy-env'))
    $envParam = [System.Management.Automation.RuntimeDefinedParameter]::new($envParamName, [string], $envParamCollection)
    $paramDictionary.Add($envParamName, $envParam)
    
    #region name-param
    $nameParamName = "Name"
    $nameParamCollection = [System.Collections.ObjectModel.Collection[System.Attribute]]::new()
    $nameParamCollection.Add(
        [System.Management.Automation.ParameterAttribute]@{
            Position         = 2
            Mandatory        = $false
            ParameterSetName = "deploy"
        }
    )   

    $nameParamCollection.Add((Get-BoltParameterAttribute:Dynamic -parameter 'deploy-name'))
    $nameParam = [System.Management.Automation.RuntimeDefinedParameter]::new($nameParamName, [string], $nameParamCollection)
    $paramDictionary.Add($nameParamName, $nameParam)
    return $paramDictionary
    
}

begin {
    if ($PSCmdlet.ParameterSetName -eq '__allParameterSets') {
        throw "No parameter set selected. please enable by adding -deploy or -publish at the start of the command"
    }

    #region build
    $BuildId = "Dev"
    #endregion build

    #region remove_on_build
    $env:bolt_dev = 1
    #endregion remove_on_build

    #region remove_on_build
    $Dev_SourceItems = Get-ChildItem "$PSScriptRoot/code" -Recurse -Filter "*.ps1" -File
    $Dev_SourceItems = $Dev_SourceItems | Where-Object { $_.Directory.name -ne "_ignore" } | where { $_.basename -notlike "*.tests" -and $_.basename -notlike "*.psakefile" }
    # Write-Debug "item count $($Dev_SourceItems.count)"
    $Dev_Import = @()
    $Dev_Import += $Dev_SourceItems | Where-Object { $_.basename -like "*.class" }
    $Dev_Import += $Dev_SourceItems | Where-Object { $_.basename -notlike "*.class" }
    # $Dev_Import
    foreach ($Item in $Dev_Import) {
        # Write-Debug "Importing $($Item.fullname)"
        . $Item.fullname
    }
    #endregion remove_on_build

    #region classes
    #endregion classes

    #region functions
    #endregion functions


    if ($Dotsource) {
        Initialize-BoltTelemetry -InstanceLevel "dotsource"
        return
    }
    else{
        Initialize-BoltTelemetry -InstanceLevel "main"
    }
}
process {
    $Config = New-BoltConfig 
    if($PSCmdlet.ParameterSetName -eq "deploy"){
        Invoke-Bolt:publish @PSBoundParameters
    }
}
end {

}



#region class
#endregion class

#region functions
#endregion functions



# #region MAIN
# Set-Variable -Scope global -Name BoltRoot -Value $PSScriptRoot -Force -WhatIf:$false

# $global:publishAction = @{
#     CreateUpdateData = $false
#     Publish          = $false
#     CleanRegistry    = $false
# }

# if ($Actions -contains "All") {
#     $keys = $publishAction.Clone().keys
#     $keys | ForEach-Object {
#         $publishAction[$_] = $true
#     }
# } else {
#     $Actions | ForEach-Object {
#         $publishAction[$_] = $true
#     }
# }

# if ((get-module az -list | Select-Object -first 1).version -lt "10.0.0") {
#     Throw "Az module version 10.0.0 or higher is required on system. (https://www.powershellgallery.com/packages/Az/10.0.0)"
# }

# $importModules = @(
#     "az.accounts"
#     "az.resources"
#     "Az.ContainerRegistry"
# )

# $verb = $VerbosePreference
# $dbg = $DebugPreference
# $VerbosePreference = "SilentlyContinue"
# $DebugPreference = "SilentlyContinue"
# $importModules | ForEach-Object {
#     Write-Host "Importing module $_"
#     Import-Module $_ -ErrorAction Stop
# }
# $VerbosePreference = $verb
# $DebugPreference = $dbg

# #region remove_on_build
# # import modules with verbose and debug silenced (-debug:$false -verbose:$false does not work)

# #import classes and functions
# $ScriptDependencies = [ordered]@{
#     class    = Get-BoltScriptFile -Type class
#     function = Get-BoltScriptFile -Type cmdlet
# }

# #easiest way to make sure classes are always loaded first
# foreach ($item in $ScriptDependencies.GetEnumerator()) {
#     Write-Verbose "importing $($item.key)"
#     foreach ($_importscript in $item.value) {
#         Write-Verbose "importing $($_importscript)"
#         . $_importscript.FullName
#     }
# }

# #endregion remove_on_build

# if ($Dotsource) {
#     Write-Host -Message "Bolt is dotsourced in. all functions are available in the global scope."
#     return
# }
# # Write-SolutionHeader
# # Write-host "version $BuildId"
# New-BoltLogContext -context "publish_modules" -subContext "main"
# Write-BoltLog "Loading Config"
# $Config = New-BoltConfig

# $Versions = Get-CurrentDeploymentVersion -Versions $Config.publish.releases -Branch $Branch -DefaultBranch $Config.publish.defaultRelease
# Write-BoltLog "Current deployment branch: $($Versions.name|Select-Object -Unique)"


# if (!(Test-BicepCli -BicepVersion $config.bicepVersion)) {
#     throw "Bicep needs to be installed, at least version $($config.bicepVersion)"
# }

# # TODO add a check for .gitignore and that it have a .biceptemp
# $TempFolder = join-path $config.GetConfigDirectory() ".bicepTemp"
# if ((test-path $TempFolder) -eq $false) {
#     New-item -Path $TempFolder -ItemType Directory -WhatIf:$false | Out-Null
# }

# $ModuleRoot = join-path (Get-GitRoot) $config.module.folder

# #Region Process BicepConfig
# $BicepConfig = Get-BicepConfig -path $ModuleRoot
# if($BicepConfig.symbolicNameCodegenEnabled() -eq $false){
#     Write-BoltLog "Symbolic name codegen is disabled. It is highly recomended to enable this under bicepconfig.experimentalfeatures. this enabled " -level warning
# }
# #endregion


# Write-BoltLog "Getting bicep modules from $ModuleRoot"

# $BicepModules = Get-ChildItem -Path $ModuleRoot -Filter "main.bicep" -Recurse | ForEach-Object {
#     $_ | Add-Member -MemberType NoteProperty -Name 'RepoName' -Value ([System.io.path]::GetRelativePath($ModuleRoot, $_.Directory.FullName).Replace("\", "/"))
#     $_
# }

# if ($BicepModules.count -eq 0) {
#     Write-BoltLog "No modules found in $ModuleRoot" -level warning
#     return
# }
# # return

# #Figure out what modules to publish

# if ($Name) {
#     $ModulesToPublish = $BicepModules | Where-Object {
#         $_.RepoName -like $name
#     }
# } else {
#     $ModulesToPublish = @()
# }

# if ($List) {
#     return $BicepModules.RepoName
# }

# New-BoltLogContext -subContext 'verify'

# # $BicepModuleNames = $ModulesToPublish | ForEach-Object { [System.io.path]::GetRelativePath($ModuleRoot, $_.Directory.FullName).Replace("\", "/") }
# $BicepManyModules = $BicepModules.RepoName | Group-Object | Where-Object { $_.count -gt 1 }
# $BicepManyModules | ForEach-Object {
#     Write-BoltLog "$($_.name) has several modules with the same name. This will cause issues when publishing." -level warning
# }
# if ($BicepManyModules) {
#     throw "There are several modules with the same name. This will cause issues when publishing."
# }

# New-BoltLogContext -subContext 'Connect'
# #make sure im in the correct context
# Write-BoltLog "Getting correct az context"
# $context = get-azcontext
# if ($context.Subscription.id -ne $config.registry.subscriptionId) {
#     Write-BoltLog "changing az context from $($context.Subscription.id) to $($config.registry.subscriptionId)"
#     Set-AzContext -Subscription $config.registry.subscriptionId -WhatIf:$false -Tenant $config.registry.tenantId -ea Stop
# }

# #get resource and token for resource
# Write-BoltLog "getting acr resource $($config.registry.name)" -level verbose
# $resource = Get-AzResource -ResourceType 'Microsoft.ContainerRegistry/registries' -Name $Config.registry.name
# if (!$resource) {
#     throw "Could not find remote registry $($config.registry.name)"
# }
# # Write-host ($resource|convertto-json    )
# $remoteRegistry = Get-AzContainerRegistry -SubscriptionId $resource.SubscriptionId -Name $resource.Name -ResourceGroupName $resource.ResourceGroupName
# if (!$remoteRegistry) {
#     throw "Could not find remote registry $($config.registry.name)"
# }

# Write-BoltLog "Setting acr context to $($remoteRegistry.LoginServer)"
# set-acrContext -Registry $remoteRegistry.LoginServer
# # $Repos = Get-AcrRepository


# New-BoltLogContext -subContext 'ProcessModules'

# if ($global:publishAction.Publish -eq $false -and $global:publishAction.CreateUpdateData -eq $false) {
#     $ModulesToPublish = @()
# }
# Write-BoltLog "Processing $($ModulesToPublish.count) modules ($(($publishAction.Keys|Where-Object{$publishAction.$_ -eq $true}) -join ", "))"

# $Timing = @{
#     process     = [System.Diagnostics.Stopwatch]::New()
#     acr_cleanup = [System.Diagnostics.Stopwatch]::New()
# }
# $statistics = [System.Collections.Hashtable]::Synchronized(@{})
# # return
# $ThrottleLimit = 2
# if ($ModulesToPublish.count -gt 1) {
#     $throttleLimit = $ModulesToPublish.count / 2
# }

# # dont run if publish and createupdate is false. 
# # I still need the list for later registry cleanup, so i copy it to a new variable


# #run async
# <#TODO: 
#     make async import functions imported via this script. 
#     i want to be able to contain everything in one script for easier shipping, 
#     but right now, the only way this is possible is to generate a hashtable of classes and function files to import for each runspace.
#     one idea is to possibly have a array of function names, and then import the functions directly using $function: + name, but i dont know if that will work every time
# #>
# $Timing.process.Start()
# $scriptPath = $MyInvocation.MyCommand.ScriptBlock.File
# # $scriptPath
# # return
# $job = $ModulesToPublish | ForEach-Object -ThrottleLimit $throttleLimit -AsJob -Parallel {
#     $BicepFile = $_
#     $ModuleRoot = $using:ModuleRoot
#     $RepoName = [System.io.path]::GetRelativePath($ModuleRoot, $BicepFile.Directory.FullName).Replace("\", "/").ToLower()
#     $global:boltDev = [bool]$using:global:boltDev
#     $scriptPath = $using:scriptPath

#     #adding stats
#     $statistics = $using:statistics
#     $thisStat = [ordered]@{
#         added              = 0
#         updated            = 0
#         skipped            = 0
#         failed_bicep_error = 0
#         failed             = 0
#     }
#     $statistics.Add($RepoName, $thisStat)

#     # Write-host "test"
#     #region inside job
#     try {
#         . $scriptPath -Dotsource
#         # $ScriptDependencies = $using:ScriptDependencies
#         # foreach ($item in $ScriptDependencies.GetEnumerator()) {
#         #     # Write-Host "importing $($item.key)"
#         #     foreach ($_importfile in $item.value) {
#         #         . $_importfile.FullName
#         #     }
#         #     #something is fishy.. sometimes something else in this script just overrides the content inside the script im loading
#         #     $_importfile = $null
#         # }

#         #region init
        

#         #importing modules. for some reason i cant just use -verbose:$false when importing modules
#         # $verb = $VerbosePreference
#         # $dbg = $DebugPreference
#         # $VerbosePreference = "SilentlyContinue"
#         # $DebugPreference = "SilentlyContinue"
#         # $using:importModules | ForEach-Object {
#         #     Import-Module $_ -ErrorAction Stop
#         # }
#         # $VerbosePreference = $verb
#         # $DebugPreference = $dbg

#         #for some reason i cant use 'using' when defining parameters

#         New-BoltLogContext -context $RepoName -subContext "main"



#         Write-BoltLog "Processing $RepoName" -level verbose

#         $TempFolder = $using:TempFolder
#         $config = $using:Config
#         $global:publishAction = $using:publishAction
#         $VerbosePreference = $using:VerbosePreference
#         $DebugPreference = $using:debugPreference
#         $ErrorActionPreference = 'Stop'
#         $WhatIfPreference = $using:WhatIfPreference
#         $global:_acr = $using:global:_acr
#         $global:ModuleActions = $using:golbal:ModuleActions

#         # $AcrRepo = $null


#         $RepoNameLocal = $RepoName.Replace("/", "_")
#         $logfile = @{
#             build  = join-path $TempFolder "$RepoNameLocal`_build.log"
#             deploy = join-path $TempFolder "$RepoNameLocal`_deploy.log"
#         }
#         $hashFile = join-path $TempFolder "$RepoNameLocal`_hashes.json"
#         $armFile = join-path $TempFolder "$RepoNameLocal`_template.json"

#         #validate that there is a cache file
#         if (!(test-path $hashFile)) {
#             New-Item -Path $hashFile -ItemType File -WhatIf:$false | Out-Null
#         }

#         #clear log files, if it exists (most likely from a previous run that failed)
#         $logfile.values | ForEach-Object {
#             if (test-path $_) {
#                 Remove-Item -Path $_ -Force -WhatIf:$false
#             }
#         }
#         #endregion init

#         #region CONVERT
#         #get hash from cache -> will be empty if not already converted
#         #if arm template is not converted or bicep file has changed, convert
#         # $testparam = @{
#         #     BicepFile       = $BicepFile
#         #     HashFile        = $hashFile
#         #     ArmTemplateFile = $armFile
#         # }
#         New-BoltLogContext -subContext "build".PadRight(10)
#         #convert to arm
#         Write-BoltLog "Converting $($BicepFile.FullName) to arm template" -level verbose
#         $param = @{
#             File       = $BicepFile
#             LogFile    = $LogFile.build
#             OutputFile = $armFile
#         }
#         Build-BicepDocument @param
#         if (!(Test-Path $armFile)) {
#             $thisStat.failed_bicep_error++
#             Write-BoltLog "Failed to convert $($BicepFile.FullName) to arm template" -level error
#             return
#         }
#         # if (Test-BicepShouldBuild @testparam) {
#         # } else {
#         #     Write-BoltLog "Skipping conversion, no changes detected" -level verbose
#         # }
#         # $ThisHash.Arm = New-DigestHash -Item $armFile -Algorithm sha256
#         Write-BoltLog "Getting hashes for $($armFile)" -level verbose
#         @{
#             bicep = New-DigestHash -Item $BicepFile -Algorithm sha256
#             arm   = New-DigestHash -Item $armFile -Algorithm sha256
#         } | ConvertTo-Json -Depth 10 | Out-File $hashFile -Force
#         #endregion CONVERT

#         #getting remote repo
#         $AcrRepo = Get-AcrRepository -Name $RepoName -ea SilentlyContinue
#         if (!$AcrRepo) {
#             $thisStat.added++
#             Write-BoltLog "New repo!" -level success
#         }


#         #region UPDATE VERSION
#         :versionUpload foreach ($activeVersion in $($using:Versions)) {
#             New-BoltLogContext -subContext $activeVersion.trigger.padright(10)
#             # Write-BoltLog "Processing version $($activeVersion.trigger)" 
#             # Write-BoltLog "pref = $VerbosePreference, $($using:VerbosePreference)"
#             $target = $null
#             $targetRepo = "br:$($global:_acr.Registry)/$RepoName"

#             # $WriteHostPrefix = "$reponame`:$($activeVersion.type)"
#             switch ($activeVersion.trigger) {
#                 "static" {
#                     #region static
#                     #TODO Make these things into cmdlets for easier script-administration
#                     #check if repo has tag
#                     $VersionValue = $activeVersion.value
#                     if ($activeVersion.prefix) {
#                         $VersionValue = $activeVersion.prefix + $VersionValue
#                     }

#                     #Getting tags from repo
#                     $AcrRepositoryTag = $AcrRepo.tags | Where-Object { $_.name -eq $VersionValue } | Select-Object -first 1
#                     # $param = @{
#                     #     LocalTemplate = $armFile
#                     #     RemoteTemplate = $AcrRepositoryTagLayer.Content
#                     #     Name = "$($activeVersion.trigger):$($AcrRepositoryTag.Name)"
#                     #     Rules = $config.publish.releasetrigger.static.update
#                     # }
#                     # $Trigger = Test-BoltReleaseTrigger @param
#                     # # Write-BoltLog "Count: $($Trigger.Count)"
#                     # Write-ModuleUpdateStatus $Trigger
#                     if (!$AcrRepositoryTag) {
#                         Write-BoltLog "New tag! $($VersionValue)" -level success
#                     } else {
#                         Write-BoltLog "remote repo tag: $($AcrRepositoryTag.Name)"

#                         #if not defined outside of try/catch, it will not be set for some reason
#                         $AcrRepositoryTagLayer = $null

#                         #get layer with content. 
#                         try {
#                             $param = @{
#                                 Repository     = $AcrRepo
#                                 Tag            = $AcrRepositoryTag.Name
#                                 IncludeContent = $true
#                                 AssumeCount    = 1
#                             }
#                             $AcrRepositoryTagLayer = Get-AcrRepositoryLayer @param | Select-Object -first 1
#                         } catch {
#                             $thisStat.skipped++
#                             Write-BoltLog "Skipped! error $_" -level warning
#                             continue :versionUpload
#                         }

#                         $param = @{
#                             LocalTemplate  = $armFile
#                             RemoteTemplate = $AcrRepositoryTagLayer.ContentPath
#                             Name           = "$($activeVersion.trigger):$($AcrRepositoryTag.Name)"
#                             Rules          = $config.publish.releasetrigger.static.update
#                         }
#                         Write-BoltLog "Testing release trigger" -level verbose
#                         $Trigger = Test-BoltReleaseTrigger @param

#                         Write-ModuleUpdateStatus $Trigger

#                         if ($Trigger.ShouldUpdate() -eq $false) {
#                             Write-BoltLog "Skipped! No changes found"
#                             $thisStat.skipped++
#                             continue :versionUpload
#                         }
#                     }

#                     $Target = "$targetRepo`:$($activeVersion.value)"
#                     #endregion static
#                 }
#                 "semantic" {
#                     #region semantic
#                     #TODO Make these things into cmdlets for easier script-administration
#                     $Regex = "(?'major'[0-9]+)\.(?'minor'[0-9]+)\.(?'rev'[0-9]+)"
#                     $BicepDefinedVersionRegex = "^\/\/module_version(\s{0,1})=(\s{0,1})['`"]{0,1}$Regex['`"]{0,1}"

#                     #default value
#                     $UsingVersion = @($activeVersion.prefix, '0.0.1')

#                     <#
#                     tag has not been defined
#                     bicep document has a higher version -> //version=1.0.1
#                     #>
#                     #Bicep defined version
#                     $VersionDefinition = Get-Content $BicepFile.FullName | Select-Object -First 10 | Where-Object { $_ -like "//module_version*" } | ForEach-Object {
#                         $_
#                     } | Select-Object -first 1

#                     #if version is defined, but not in the correct format, skip
#                     if ($VersionDefinition -and $VersionDefinition -notmatch $BicepDefinedVersionRegex) {
#                         $thisStat.skipped++
#                         Write-BoltLog "Skipped! Version found '$VersionDefinition', but it's defined wrong. should be //module_version={major.minor.build/revision}" -level warning
#                     } elseif ($VersionDefinition -match $BicepDefinedVersionRegex) {
#                         $_version = $Matches.major + "." + $Matches.minor + "." + $Matches.rev
#                         Write-BoltLog "Version defined in module: $($_version)" -level info
#                         $UsingVersion[1] = $_version
#                     }

#                     #if you have defined a prefix in current version, match "{prefix}0.0.1"
#                     #TODO: add support to look for 'any' version, is selected by config. helpfull for transition of prefix
#                     if ($activeVersion.prefix) {
#                         $AcrSearch = "^$($activeVersion.prefix)$regex$"
#                     } 
#                     #no prefix defined, only get tags that are scemantic (0.0.1)
#                     else {
#                         $AcrSearch = "^$regex$"
#                     }

#                     #get all tags that match the regex
#                     $AcrRepositoryTag = $AcrRepo.tags | Where-Object { $_.name -match $AcrSearch }

#                     #sort to get the highest version and get that one
#                     $AcrRepositoryTag = $AcrRepositoryTag | Sort-Object name -Descending | Select-Object -first 1

#                     #grab version. it will be in $matches
#                     $AcrRepositoryTag.name -match $regex | out-null

#                     #if its avalaible and the current published version is greater or equal than the locally defined version
#                     if ($AcrRepositoryTag -and $AcrRepositoryTag.name -ge $(($UsingVersion | Where-Object { $_ }) -join '')) {
#                         # Write-BoltLog "remote repo tag: $($AcrRepositoryTag.Name)"
#                         #get the layer
#                         $AcrRepositoryTagLayer = $null
#                         try {
#                             $param = @{
#                                 Repository     = $AcrRepo
#                                 Tag            = $AcrRepositoryTag.Name
#                                 IncludeContent = $true
#                                 AssumeCount    = 1
#                             }
#                             $AcrRepositoryTagLayer = Get-AcrRepositoryLayer @param | Select-Object -first 1
#                         } catch {
#                             $thisStat.skipped++
#                             Write-BoltLog "Skipped! error $_" -level warning
#                             continue :versionUpload
#                         }

#                         #extract regex keys
#                         $versionMap = @{
#                             major = [int]::Parse($Matches.major)
#                             minor = [int]::Parse($Matches.minor)
#                             rev   = [int]::Parse($Matches.rev)
#                         }
#                         $remoteVersion = "{0}.{1}.{2}" -f $versionMap.major, $versionMap.minor, $versionMap.rev
#                         Write-BoltLog "remote repo version tag: $remoteVersion (name: $($AcrRepositoryTag.name))" -level info
#                         # Write-Host "$WriteHostPrefix - remote repo version tag: $acrVersion (name: $($AcrRepositoryTag.name))" -ForegroundColor $color.info

#                         #if remote version is greater or than local version, create new version, using remote version as base
#                         if ($remoteVersion -ge $UsingVersion[1]) {
#                             $changes = @{}

#                             'major', 'minor', 'patch' | ForEach-Object {
#                                 $versionLevel = $_
#                                 $param = @{
#                                     LocalTemplate  = $armFile
#                                     RemoteTemplate = $AcrRepositoryTagLayer.ContentPath
#                                     Name           = "$($activeVersion.trigger):$($versionLevel)"
#                                     Rules          = $config.publish.releasetrigger.semantic.$versionLevel
#                                 }
#                                 Write-BoltLog "Testing release trigger for $versionLevel" -level verbose
#                                 $changes.$versionLevel = Test-BoltReleaseTrigger @param
#                             }

#                             if ($Changes.major.ShouldUpdate()) {
#                                 $Changes.major | Write-ModuleUpdateStatus
#                                 Write-BoltLog "Major version increased (X.0.0)" -level info
#                                 $versionMap.major++
#                                 $versionMap.minor = 0
#                                 $versionMap.rev = 0
#                             } elseif ($changes.minor.ShouldUpdate()) {
#                                 $changes.minor | Write-ModuleUpdateStatus
#                                 Write-BoltLog "Minor version increased (0.X.0)" -level info
#                                 $versionMap.minor++
#                                 $versionMap.rev = 0
#                             } elseif ($changes.patch.ShouldUpdate()) {
#                                 $changes.patch | Write-ModuleUpdateStatus
#                                 Write-BoltLog "Patch version increased (0.0.X)" -level info
#                                 $versionMap.rev++
#                             } else {
#                                 Write-BoltLog "Skipped! No changes found"
#                                 $thisStat.skipped++
#                                 continue :versionUpload
#                             }
#                             $UsingVersion[1] = "{0}.{1}.{2}" -f $versionMap.major, $versionMap.minor, $versionMap.rev
#                         }
#                     } else {
#                         Write-BoltLog "NEW MODULE!" -level info
#                     }

#                     #remove prefix if not defined
#                     $UsingVersion = $UsingVersion | Where-Object { ![string]::IsNullOrEmpty($_) }

#                     $Target = "$targetRepo`:$($UsingVersion -join '')"
#                     #endregion semantic
#                 }
#                 default {
#                     $thisStat.skipped++
#                     Write-BoltLog "Skipped! the version trigger $($activeVersion.trigger) is not supported" -level warning
#                     # Write-Host "$reponame - Skipped! $($activeVersion.branch)/$($activeVersion.type) -> $($activeVersion.value) is not supported" -ForegroundColor $color.warning
#                     continue :versionUpload
#                 }
#             }

#             #the switch beforehand should create a target, but just in case any of the "continue" is not working.
#             if ($target -and $publishAction.Publish) {
#                 $thisStat.updated++
#                 if ($WhatIfPreference) {
#                     Write-BoltLog "WHATIF: should upload $($activeVersion.name)/$($activeVersion.trigger) -> $Target" -level success
#                 } else {
#                     Write-BoltLog "Uploading $($activeVersion.name)/$($activeVersion.trigger) -> $Target" -level success
#                     Publish-AzBicepModule -FilePath $BicepFile.FullName -Target $Target -Force -WarningAction SilentlyContinue 
#                 }
#             }
#         }
#     } catch {
#         # Write-BoltLog ($thisStat|ConvertTo-Json)
#         $thisStat.failed++
#         Write-BoltLog "Error: $($_.Exception.Message)" -level error
#         # $_.ScriptStackTrace.split("`n") | % {
#         #     $out = $_
#         #     if ($out -like "*<scriptblock>*") {
#         #         $line = $out.Split(":")[1].Substring(6)
#         #         $out += " (in bolt.ps1:$([int]$line + 220))"
#         #     }
#         #     $out
#         #     Write-BoltLog -message $out -level error
#         # } 
#         Write-BoltLog $_.ScriptStackTrace -level error
#         throw $_
#     }
#     #endregion inside job
# }

# try {
#     Write-BoltLog "job started, id: $($job.id), childjobs: $($job.childjobs.count)" -level dev
#     $Out = @{}
#     # $global:ChildId = 0
#     while ($job.state -eq 'Running') {
#         Foreach ($Childjob in $job.ChildJobs) {
#             #add to childjob - report list if not already there
#             if (!$out.ContainsKey($Childjob.Id)) {
#                 $out[$Childjob.Id] = @{
#                     timer     = [System.Diagnostics.Stopwatch]::new()
#                     state     = $Childjob.State
#                     processed = $false
#                 }
#             }

#             #get current childjob report
#             $ThisJob = $out[$Childjob.Id]

#             #update state
#             $ThisJob.state = $Childjob.State

#             #start timer if not already started and childjob is running
#             if ($Childjob.State -eq 'running' -and !$ThisJob.timer.IsRunning) {
#                 $ThisJob.timer.Start()
#             }

#             #stop timer if childjob is completed and timer is running
#             if ($Childjob.State -eq 'Completed' -and $ThisJob.timer.IsRunning) {
#                 $ThisJob.timer.Stop()
#             }
#         }
        
#         #all childjobs are completed
#         $progress = ($job.ChildJobs | Where-Object { $_.State -eq 'Completed' }).count

#         #figure out precent (current finished / total)*100
#         $percent = (($progress / $ModulesToPublish.count) * 100)
#         #round for activity to show nice number
#         $percent = [math]::Round($percent, 0)

#         #show childjob states (completed:x running:y failed:z)
#         $states = $job.ChildJobs | Group-Object state | ForEach-Object { $_.name + ":" + $_.count }

#         #calculate average time for completed childjobs
#         $CompletedAverageSeconds = ($out.Values | Where-Object { $_.state -eq 'completed' } | ForEach-Object { $_.timer.elapsed.totalseconds } | Measure-Object -Average).Average

#         #calculate remaining seconds (current not completed * average time for completed)
#         $Seconds = [math]::Round(($ModulesToPublish.count - $progress) * $CompletedAverageSeconds, 0)
#         # if($null -eq $Seconds) {
#         #     $Seconds = 10
#         # }
#         Write-Progress -id 0 -Activity "Processing $($ModulesToPublish.count) modules" -Status "$states ($percent%)" -PercentComplete $percent -SecondsRemaining $Seconds

#         #recevie info from childjobs that are completed and not already processed
#         $job.ChildJobs | Where-Object { $_.State -eq 'completed' -and !$out.($_.id).processed } | ForEach-Object {
#             $out.($_.id).processed = $true
#             $_ | receive-job
#         }

#         Start-Sleep -Milliseconds 10
#     }

#     $job.ChildJobs | Where-Object { !$out[$_.id].processed } | ForEach-Object {
#         $out.($_.id).processed = $true
#         $_ | receive-job
#     }
# } catch {
#     $job.StopJob()
#     Write-BoltLog -message "Error @ job $($job.Id), child $($childjob.Id)" -level error
#     $_
# } finally {
#     $Timing.process.Stop()
#     Write-Progress -id 0 -Activity "Converting modules" -Completed
# }


# #CLEANUP REMOTE REGISTRY
# if ($global:publishAction.CleanRegistry) {
#     $Timing.acr_cleanup.Start()
#     New-BoltLogContext -context 'Cleanup' -subContext 'main'
#     Write-BoltLog "Cleaning up $($remoteRegistry.LoginServer)"

#     Write-BoltLog "Getting remote repos"
#     $Repos = Get-AcrRepository 
#     $thisStat = @{
#         repo_removed = 0
#     }
#     #just giving a random name to not conflict with other stats
#     $statistics.Add("acr_remove_$([guid]::NewGuid().ToString())", $thisStat)
#     Foreach ($repo in $Repos | Where-Object { $_.ImageName -notin $BicepModules.RepoName }) {
#         $thisStat.repo_removed++
#         Write-BoltLog "Removing $($repo.ImageName)"
#         Remove-AzContainerRegistryRepository -RegistryName $remoteRegistry.Name -Name $repo.ImageName | out-null
#     }
#     $Timing.acr_cleanup.Stop()
# }

# New-BoltLogContext -context 'Statistics' -subContext 'main'

# New-BoltLogContext -subContext 'timing'
# Write-BoltLog -message "**Timings**"
# $Timing.keys | ForEach-Object {
#     $msg = ("{0:N0}" -f $Timing.$_.Elapsed.TotalSeconds) + "Sec"
#     switch ($_) {
#         'process' {
#             $perItem = $Timing.$_.Elapsed.TotalSeconds / $ModulesToPublish.Count
#             $msg += "- " + ("{0:N0}" -f $perItem) + "sec/module"
#         }
#     }
#     Write-BoltLog -message "$_`: $msg" -level info
# }

# New-BoltLogContext -subContext 'other'
# Write-BoltLog -message "**Other**"
# $statistics.values.keys | Select-Object -Unique | ForEach-Object {
#     Write-BoltLog -message "$_`: $(($statistics.values.$_|Measure-Object -Sum).Sum)" -level info
# }
