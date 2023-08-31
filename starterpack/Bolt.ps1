#BUILD 0.2.230831
#region using
using namespace system.collections.generic
using namespace diagnostics.codeanalysis
using namespace system
using namespace system.io
using namespace system.management.automation
#endregion using

#region requires
#requires -version 7.2.0
#endregion requires

<#
.DESCRIPTION
Bolt is a tool to help manage the lifecycle of bicep modules.
It is designed to be used in a CI/CD pipeline to help automate the process of publishing bicep modules to a registry.
It can also be used to help manage the lifecycle of bicep modules in a development environment, by setting version based on what changes have been made.

.PARAMETER Branch/Release
The Branch/Release Name to use for publish. This is reflected in config.publish.releases
.PARAMETER Name
specific module name to publish. If not specified, all modules will be published.
Supports Wildcard
This is the logical name for the module, not just "filename": path/to/my/module.
If you want to push several modules within the same folder, you can say path/to/my/* and it will push all modules in that folder.
.PARAMETER Actions
The actions to perform. Defaults to 'Publish'.
Publish: Publish the modules to the repository
CreateUpdateData: (NOT ENABLED YET) Creates json with data of what triggered the update. useful for 'whats new' documentation
CleanRegistry: Removes repositories not found during discovery (Not overridden by name parameter)
All: Perform all actions
.PARAMETER List
List all modules that will be published
.PARAMETER Dotsource
Sets script in a dot sourced context. This is used by all runspaces to import code from the main script. not used by users.
.NOTES
Author: Philip Meholm
#>
[CmdletBinding(
    SupportsShouldProcess
)]
param(
    [Alias("Release")]
    [string]$Branch = "prod",
    [string]$Name = "*",
    [ValidateSet("CreateUpdateData", "Publish", "CleanRegistry", "All" )]
    [string[]]$Actions = "Publish",
    [switch]$List,
    [switch]$Dotsource
)
#region build
$BuildId=0.2.230831
#endregion build

if ($whatifpreference -and !$Dotsource) {
    Write-Warning "WHATIF ENABLED. No changes will be made.".ToUpper()
}

if (![string]::IsNullOrEmpty($env:bolt_dev)) {
    $global:boltDev = [bool]::Parse($env:bolt_dev)
}

if ($global:boltDev -eq $true) {
    Write-Warning "Bolt is running in dev mode. This is not recommended for production use.".ToUpper()
} else {
    $global:boltDev = $false
}

if(!$Dotsource){
$header = @'
▀█████████▄   ▄██████▄   ▄█           ███     
  ███    ███ ███    ███ ███       ▀█████████▄ 
  ███    ███ ███    ███ ███          ▀███▀▀██ 
 ▄███▄▄▄██▀  ███    ███ ███           ███   ▀ 
▀▀███▀▀▀██▄  ███    ███ ███           ███     
  ███    ██▄ ███    ███ ███           ███     
  ███    ███ ███    ███ ███▌    ▄     ███     
▄█████████▀   ▀██████▀  █████▄▄██    ▄████▀   
                        ▀                     
----------------------------------------------
Bicep Operations and Lifecycle Tool
Zap Your Bicep Blues, Amp Up Your Azure Moves!
'@
    Write-host $header
}
write-host "version: $BuildId"

#region class
#region ..\.stage\code\versionControl\UpdateTest.model.class.ps1
class ModuleUpdateTest {
    [string] $type
    [Dictionary[string, [List[ModuleUpdateReason]]]] $reasons
    [bool] $result = $true
    ModuleUpdateTest([string]$type) {
        $this.type = $type
        $this.reasons = [Dictionary[string, [List[ModuleUpdateReason]]]]::new()
    }

    #returns as reference, not as value
    [List[ModuleUpdateReason]] NewReasonList([string]$key) {
        $this.Reasons.Add($key, [List[ModuleUpdateReason]]::new())
        return $this.reasons[$key]
    }

    [bool]ShouldUpdate() {
        $return = $false
        $this.reasons.GetEnumerator() | ForEach-Object {
            if ($_.value.Count -gt 0) {
                [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'is is a return key')]
                $return = $true
            }
        }
        return $return
    }
}
#endregion

#region ..\.stage\code\config\config.class.ps1
class boltConfigModuleStyle{
    [ValidateSet(
        'SingleModuleFolder',
        'MultiModuleFolder'
    )]
    [string]$Type
    [string]$Filter
    [string]$exclude

    [string]ToString() {
        return "$($this.Type):?$($this.Filter):-$($this.exclude)"
    }
}
#endregion

#region ..\.stage\code\config\config.class.ps1
class boltConfigVersion {
    [string]$branch = ""
    [string]$type = ""
    [string]$value = ""
    [string]$prefix = ""
    validate() {}
    [string]ToString() {
        return "$($this.branch):$($this.type)"
    }
}
#endregion

#region ..\.stage\code\config\config.class.ps1
class boltConfigReleaseTrigger {
    [boltConfigReleaseTriggerItem]$static
    [boltConfigReleaseTriggerItem]$semantic
}
#endregion

#region ..\.stage\code\config\config.class.ps1
class boltConfigPublish{
    [boltConfigReleaseTrigger] $releaseTrigger
    [string]$defaultRelease
    [boltConfigRelease[]]$releases
}
#endregion

#region ..\.stage\code\config\config.class.ps1
class boltConfig {
    #weird thing to handle dollar sign in variable
    [string]${$schema}
    [string]$bicepVersion
    [boltConfigRegistry]$registry
    [boltConfigModule]$module
    [boltConfigPublish]$publish

    hidden [string]$configDirectory

    [void]Validate()
    {
        Test-BoltConfigRegistry -Config $this.registry
        Test-BicepInstallation -configVersion $this.bicepVersion
        Test-BoltConfigReleaseTrigger -Triggers $this.publish.releaseTrigger
    }

    [void]SetConfigDirectory([string]$directory){
        $this.configDirectory = $directory
    }

    [string]GetConfigDirectory(){
        return $this.configDirectory
    }
}
#endregion

#region ..\.stage\code\config\config.class.ps1
class boltConfigModule {
    [ValidateNotNullOrEmpty()]
    [string]$folder
    [boltConfigModuleStyle]$organisationStyle
    [string]$temp

    boltConfigModule() {
        $this.organisationStyle = [boltConfigModuleStyle]::new()
        $this.temp = ".bicepTemp"
    }

    validate() {
        Test-BoltConfigModule -Config $this
    }

    [string]ToString() {
        return "$($this.folder):$($this.style)"
    }
}
#endregion

#region ..\.stage\code\config\config.class.ps1
class boltConfigReleaseTriggerItem {
    [List[string]]$update
    [List[string]]$major
    [List[string]]$minor
    [List[string]]$patch
}
#endregion

#region ..\.stage\code\log\log.model.class.ps1
class LogContext {
    [ValidateNotNullOrEmpty()]
    [string]$context
    [string]$subContext
 
    #command, what to call it
    [Dictionary[string,string]]$commandMap = [Dictionary[string, string]]::new()

    LogContext([string]$Context){
        $this.context = $Context
    }

    [void]AddCommandContext([string]$command,[CallStackFrame]$frame) {
        if($this.commandMap.ContainsKey($frame.Command)) {
            $this.commandMap[$frame.Command] = $command
            return
        }
        # Write-boltLog "Adding command context '$($frame.Command)':'$($command)'" -level dev
        $this.commandMap.Add($frame.Command,$command)
    }

    [string]ToString() {
        $return = $this.context
        if ($this.subContext) {
            $return += ":$($this.subContext)"
        }

        if($this.commandMap.Count -gt 0)
        {
            :commandsearch foreach($cmd in Get-PSCallStack)
            {
                if($this.commandMap.ContainsKey($cmd.Command))
                {
                    $return += ":$($this.commandMap[$cmd.Command])"
                    break :commandsearch
                }
            }
        }
        
        return $return
    }
}
#endregion

#region ..\.stage\code\acr\models.class.ps1
class AcrRepositoryLayer {
    [string]$repository
    [string]$tag
    [string]$digest
    [string]$mediaType
    [int]$size
    [string]$ContentPath
}
#endregion

#region ..\.stage\code\config\config.class.ps1
class Config_Docs {
    [bool]$enable
    [string]$folder
    [List[string]]$items
    validate() {
        
    }
    [string]ToString() {
        return "$($this.enable):$($this.folder)"
    }
}
#endregion

#region ..\.stage\code\versionControl\UpdateTest.model.class.ps1
enum ModuleUpdateType {
    added
    removed
    modified
    other
}
#endregion

#region ..\.stage\code\bicep\BicepConfig.class.ps1
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
#endregion

#region ..\.stage\code\versionControl\UpdateTest.model.class.ps1
class ModuleUpdateReason {
    [string]$key
    [string]$detail = $null

    [ModuleUpdateType]$type
    [string]$oldValue
    [string]$newValue
    [string]$message
    ModuleUpdateReason() {}
    ModuleUpdateReason([string]$key) {
        $this.key = $key
    }

    static [ModuleUpdateReason] Added([string]$key, $newValue) {
        $reason = [ModuleUpdateReason]::new($key)
        $reason.type = [ModuleUpdateType]::added
        $reason.newValue = $NewValue|ConvertTo-Json -Compress
        return $reason
    }

    static [ModuleUpdateReason] Removed([string]$key, $oldValue) {
        $reason = [ModuleUpdateReason]::new($key)
        $reason.type = [ModuleUpdateType]::removed
        $reason.oldValue = $oldValue|ConvertTo-Json -Compress
        return $reason
    }

    static [ModuleUpdateReason] Modified([string]$key, $oldValue, $newValue) {
        $reason = [ModuleUpdateReason]::new($key)
        $reason.type = [ModuleUpdateType]::modified
        $reason.oldValue = $oldValue|ConvertTo-Json -Compress
        $reason.newValue = $newValue|ConvertTo-Json -Compress
        return $reason
    }

    static [ModuleUpdateReason] Other([string]$key, [string]$message) {
        $reason = [ModuleUpdateReason]::new($key)
        $reason.type = [ModuleUpdateType]::other
        $reason.message = $message
        return $reason
    }
}
#endregion

#region ..\.stage\code\config\config.class.ps1
class boltConfigRegistry {
    [string]$type = "acr"

    [ValidateNotNullOrEmpty()]
    [string]$name

    [ValidateNotNullOrEmpty()]
    [string]$subscriptionId
    
    [ValidateNotNullOrEmpty()]
    [string]$tenantId

    Validate() {
        Test-BoltConfigRegistry -RegistryConfig $this
    }

    [String]ToString() {
        return "$($this.type):$($this.name)"
    }
}
#endregion

#region ..\.stage\code\config\config.class.ps1
enum bicepInstallType{
    install
    upgrade
}
#endregion

#region ..\.stage\code\config\config.class.ps1
class boltConfigRelease {
    [string]$name
    [string]$trigger
    [string]$value = ""
    [string]$prefix = ""
}
#endregion

#endregion class

#region functions
#region ..\.stage\code\acr\New-DigestHash.ps1
function New-DigestHash {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [parameter(Mandatory, ParameterSetName = "Item")]
        [FileInfo]$Item,
        [parameter(Mandatory, ParameterSetName = "Bytes")]
        [byte[]]$Bytes,
        [ValidateSet(
            "sha256",
            "sha512"
        )]
        [string]$Algorithm = "sha256"
    )
    
    begin {
        # if ($item -and $bytes) {
        #     throw "cannot define bytes and item at the same time"
        # }
    }
    process {       
        switch ($Algorithm) {
            "sha256" {
                $Hash = [System.Security.Cryptography.SHA256]::Create()
            }
            "sha512" {
                $Hash = [System.Security.Cryptography.SHA256]::Create()
            }
            default {
                throw "algorithm '$_' is not set up"
            }
        }

        switch ($PSCmdlet.ParameterSetName) {
            "Item" {
                try {
                    if(!(test-path $Item.FullName)){
                        throw "file '$($Item.FullName)' does not exist"
                    }
                    $fileStream = $Item.OpenRead()
                    $hashvalue = $Hash.ComputeHash($fileStream)
                } finally {
                    $fileStream.Close()
                }
            }
            "Bytes" {
                $hashvalue = $Hash.ComputeHash($Bytes)
            }
        }
        # if ($null -ne $bytes) {
        #     $hashvalue = $Hash.ComputeHash($Bytes)
        # } else {
        #     #open read file, create hash from contents
        #     try {
        #         $fileStream = $Item.OpenRead()
                
        #         $hashvalue = $Hash.ComputeHash($fileStream)
        #     } finally {
        #         $fileStream.Close()
        #     }
        # }

        #generate hash string
        $strbuilder = [System.Text.StringBuilder]::new()
        $strbuilder.Append($Algorithm) | Out-Null
        $strbuilder.append(":") | Out-Null
        $hashvalue.ForEach{
            $strbuilder.Append(([byte]$_).ToString("x2")) | Out-Null
        }
        return $strbuilder.ToString()
    }
    end {   
    }
}
#endregion

#region ..\.stage\code\versionControl\releaseTests\Test-BoltTriggerOnResource.ps1
function Test-BoltTriggerOnResource {
    [CmdletBinding()]
    [OutputType([ModuleUpdateReason])]
    param (
        [hashtable]$LocalObject,
        [hashtable]$RemoteObject,
        [string]$Rule,
        [switch]$LogEverything
    )
    New-BoltLogContext -command "resourceTest $rule"
    # Write-BoltLog "RESOURCE RULE: $rule" -level 'dev'
    
    #because i dont know if either the remote or local template has been made with.
    #bicepconfig.experimentalFeaturesEnabled.symbolicNameCodegen enabled, i have to check and convert the resources to the same format
    $res = @{
        _Local = $LocalObject.resources
        _Remote = $RemoteObject.resources
        localIsSymbolic = $LocalObject.resources -is [array]
        remoteIsSymbolic = $RemoteObject.resources -is [array]
        local = @{}
        remote = @{}
    }
    $res.bothIsSymbolic = $res.localIsSymbolic -eq $res.remoteIsSymbolic

    foreach($item in 'local','remote'){
        $Temp = $res["_${item}"]
        if($Temp -is [array]){
            Write-BoltLog "$item template is not symbolic. converting to hashtable" -level 'verbose'
            $Temp |ForEach-Object{
                $resource = $_
                $resourceBase = ($resource.type.split("/") | Select-Object -Skip 1) -join "/"
                $Name = $resourceBase + "@" + $resource.apiVersion
                if($res[$item].containskey($Name)){
                    Write-BoltLog "resource with name $Name already exists in $item template. adding resource name to key" -level 'verbose'
                    $Name = $Name + "_" + $resource.name
                }
                $res[$item][$Name] = $_
            }
        }
        else{
            $res[$item] = $temp
        }
    }
    $localResources = $res.local
    $remoteResources = $res.remote

    <#
    look..
    checking resources is hard-ish IF Bicepconfig.experimentalFeaturesEnabled.symbolicNameCodegen is not enabled:
    i cannot use the bicep-given name as a key, as they are not transferred to the ARM template,
    so i have to use the type and given name as a key. this might be a problem, as there might be 2 resources with the same type, but different names,
    so if one was removed, this would not be easily detected.
    however i think this is the best i can do for now. mabye in the future we can use some bicep magic to get the name of the resource, 
    even if it is not transferred to the ARM template..
    #>

    #check if resources have been removed
    if ($Rule -eq 'resourceRemoved') {
        # $foundresource = @()
        :remoterec foreach ($remoteResource in $remoteResources.GetEnumerator()) {
            $remoteValue = $remoteResource.value
            $remoteKey = $remoteResource.key
            # $name = $remoteKey
            # if($rec.remoteIsSymbolic -eq $false){
            #     $name = "$($remoteValue.type)@$($remoteValue.apiVersion)"
            # }
            #search by type and name first
            if($rec.bothIsSymbolic){
                $localResource = $localResources[$remoteKey]
            }
            else{
                $localResource = $localResources.GetEnumerator() | Where-Object { $_.value.type -eq $remoteValue.type -and $_.value.name -eq $remoteValue.name }
            }
            # $localResources
            # $localResource = $LocalObject.resources | Where-Object { $_.type -eq $remoteResource.type -and $_.name -eq $remoteResource.name }
            if (@($localResource).count -gt 1) {
                #you should never really get here, but if you do, you cannot test. multiple resource with same type and name? nah dude..
                Write-BoltLog "multiple local resources found for $($remoteKey) of type $($remoteValue.type) in local template. cannot test" -level warning
                continue
            }
            #if the resource is there when searched for by name and type, continue
            elseif ($null -ne $localResource) {
                continue :remoterec
            }
            if($LogEverything){
                Write-BoltLog "resource '$remotekey' not found on local template" -level 'dev'
            }
            Write-Output ([ModuleUpdateReason]::Removed('resource', $remoteKey))
        }
    }

    #check each existing resource agains the new resources
    :reccheck Foreach ($localResource in $localResources.GetEnumerator()) {
        $localValue = $localResource.value
        $localKey = $localResource.key
        # $name = $localKey
        # if($rec.localIsSymbolic -eq $false){
        #     $name = "$($localValue.type)@$($localValue.apiVersion)"
        # }
        #check if there are several resources with the same type and name in local.. this makes testing impossible
        # if (@($LocalObject.resources|where{$_.}).count -gt 1) {
        #     Write-BoltLog "multiple local resources found for $($localResource.name) of type $($localResource.type) in local template. cannot test" -level warning
        #     continue :reccheck
        # }
        # $resourceBase = ($localresource.type.split("/") | Select-Object -Skip 1) -join "/"
        # $resourceName = $resourceBase + "@" + $localresource.apiVersion
        Write-BoltLog "checking resource:'$localKey'" -level 'dev'

        if($rec.bothIsSymbolic){
            $remoteValue = $remoteResources[$localKey]
        }
        else{
            $remoteValues = $remoteResources.GetEnumerator() | Where-Object { $_.value.type -eq $localValue.type -and $_.value.name -eq $localValue.name }
        }

        # $remoteResource = $RemoteObject.resources | Where-Object { $_.type -eq $localResource.type -and $_.name -eq $localResource.name }
        # Write-BoltLog "count of remote resources: $(@($remoteResource).count)" -level 'dev'
        if (@($remoteValues).count -gt 1) {
            Write-BoltLog "multiple remote resources found for '$($localKey.name)' of type '$($localValue.type)' in remote template ($($remoteValue.key -join ", ")). cannot test" -level warning
            continue :reccheck
        }

        if ($null -eq $remoteValues) {
            if($logeverything){
                Write-BoltLog "remote resource not found" -level 'dev'
            }
            if ($rule -eq 'resourceAdded') {
                Write-Output ([ModuleUpdateReason]::Added("resource", $localKey))
            }

            #no reason to check any more properties, since the remote resource is not there
            continue :reccheck
        }
        $remoteValue = $remoteValues.value
        $remoteKey = $remoteValues.key
        Write-boltlog "'$localKey' remote resource: $remoteKey" -level 'dev'


        <#
            # "resourceAdded",
            # "resourceRemoved",
            "resourceApiVersionModified",
            "resourcePropertiesAdded",
            "resourcePropertiesRemoved",
            "resourcePropertiesModified",
        #>


        #generate a list of all properties for both resources
        #make all properties of both resources into a array of key-value pairs, removing any properties that are objects or arrays
        $exclude = @(
            "`$schema"
            "*_generator*"
            "*_EXPERIMENTAL_WARNING"
        )
        $localProperties = $localValue | Convert-HashtableToArray -ExcludeKeys $exclude -excludeTypes object,array
        $remoteProperties = $remoteValue | Convert-HashtableToArray -ExcludeKeys $exclude -excludeTypes object,array

        switch ($Rule) {
            "resourceApiVersionModified" {
                if ($localValue.apiVersion -ne $remoteValue.apiVersion) {
                    Write-Output ([ModuleUpdateReason]::Modified($localKey, $remoteValue.apiVersion, $localValue.apiVersion))
                }
            }
            "resourcePropertiesAdded" {
                $localProperties.Keys | Where-Object { $_ -notin $remoteProperties.keys } | ForEach-Object {
                    Write-Output ([ModuleUpdateReason]::Added("$localKey", $_))
                }
            }
            "resourcePropertiesRemoved" {
                $remoteProperties.Keys | Where-Object { $_ -notin $localProperties.keys } | ForEach-Object {
                    Write-Output ([ModuleUpdateReason]::Removed("$localKey", $_))
                }
            }
            "resourcePropertiesModified" {
                #where property exists in both resources, and is not a hashtable or array
                $localProperties.GetEnumerator() | Where-Object { $_.key -in $remoteProperties.keys } | ForEach-Object {
                    $key = $_.key
                    $localProp = $_.value
                    $remoteProp = $remoteProperties[$key]
                    if (($localProp | ConvertTo-Json -Compress) -ne ($remoteProp | ConvertTo-Json -Compress)) {
                        if($LogEverything){
                            write-boltlog "property: $localKey.$($key)" -level 'dev'
                            Write-BoltLog "`t local property: $localProp" -level 'dev'
                            Write-BoltLog "`tremote property: $remoteProp" -level 'dev'
                        }
                        Write-Output ([ModuleUpdateReason]::Modified("$localKey.$key", $remoteProp, $localProp))
                    }
                }
            }
        }
    }
}
#endregion

#region ..\.stage\code\bicep\Test-BicepShouldBuild.ps1
function Test-BicepShouldBuild {
    [CmdletBinding()]
    param (
        [parameter(Mandatory)]
        [system.io.fileinfo]$BicepFile,
        [system.io.fileinfo]$HashFile,
        [system.io.fileinfo]$ArmTemplateFile
    )
    
    begin {}
    
    process {
        if(!$HashFile.Exists)
        {
            Write-BoltLog "Reason: No hash file found. assuming convert havent happened yet" -level verbose
            return $true
        }

        if(!$ArmTemplateFile.Exists)
        {
            Write-BoltLog "Reason: No arm template found" -level verbose
            return $true
        }
        
        $ExistingHash = Get-Content $HashFile.FullName|ConvertFrom-Json
        
        if([string]::IsNullOrEmpty($ExistingHash.bicep))
        {
            Write-BoltLog "Reason: No digest hash of prevoius bicep build found" -level verbose
            return $true
        }

        $BicepHash = New-DigestHash -Item $BicepFile -Algorithm sha256
        if($BicepHash -eq $ExistingHash.bicep)
        {
            Write-BoltLog "Reason: Bicep file has changed" -level verbose
            return $true
        }

        return $false
    }
    
    end {
        
    }
}
#endregion

#region ..\.stage\code\bicep\Get-BicepConfig.ps1
function Get-BicepConfig {
    [CmdletBinding()]
    [OutputType([BicepConfig])]
    param (
        [string]$Path
    )
    
    $ConfigFileName = "bicepconfig.json"
    $configFile = Find-File -SearchFrom $path -FileName $ConfigFileName
    return [BicepConfig](get-content $configFile.FullName | ConvertFrom-Json -AsHashtable)
}
#endregion

#region ..\.stage\code\versionControl\releaseTests\Test-BoltTriggerOnOutput.ps1
function Test-BoltTriggerOnOutput {
    [CmdletBinding()]
    [OutputType([ModuleUpdateReason])]
    param (
        [hashtable]$LocalObject,
        [hashtable]$RemoteObject,
        [string]$Rule,
        [switch]$LogEverything
    )
    New-BoltLogContext -command "outputTest $rule"
    # Write-BoltLog "OUTPUT RULE: $rule" -level 'dev'
    <#
        "outputsAdded",
        "outputsRemoved",
        "outputsModified",
    #>
    $RemoteOutputs = $RemoteObject.outputs
    $LocalOutputs = $LocalObject.outputs
    if ($Rule -eq 'outputsRemoved') {
        foreach ($remoteKey in $RemoteOutputs.keys) {
            if ($remoteKey -notin $LocalOutputs.keys) {
                Write-Output ([ModuleUpdateReason]::Removed("output", $remoteKey))
            }
        }
    }

    :outputsearch foreach ($localKey in $LocalOutputs.keys) {

        if ($localKey -notin $RemoteOutputs.keys -and $Rule -eq 'outputsAdded') {
            Write-Output ([ModuleUpdateReason]::Added("output", $localKey))
            continue :outputsearch
        }

        if($rule -eq 'outputsModified'){
            $localOutput = $LocalOutputs[$localKey]|Convert-HashtableToArray -excludeTypes array,object
            $remoteOutput = $RemoteOutputs[$localKey]|Convert-HashtableToArray -excludeTypes array,object
            foreach($out in $localOutput.keys){
                if($localOutput[$out] -ne $remoteOutput[$out]){
                    if($LogEverything){
                        Write-BoltLog "output $localKey.$out has changed" -level 'dev'
                        Write-BoltLog "local: $($localOutput[$out])" -level 'dev'
                        Write-BoltLog "remote: $($remoteOutput[$out])" -level 'dev'
                    }
                    $name = $localKey + "." + $out
                    Write-Output ([ModuleUpdateReason]::Modified($name, $remoteOutput[$out], $localOutput[$out]))
                    continue :outputsearch
                }
            }
        }
    }
}
#endregion

#region ..\.stage\code\helpers\Find-File.ps1
function Find-File {
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo])]
    param (
        $SearchFrom,
        [string]$FileName
    )
    if((get-item $SearchFrom) -is [System.IO.FileInfo]){
        Write-BoltLog "SearchFrom is a file, getting parent directory" -level verbose
        $SearchFrom = split-path $SearchFrom -Parent
    }
    $SearchFrom = [System.IO.DirectoryInfo]$SearchFrom
    $startsearchFrom = $SearchFrom
    $ConfigPath = ""
    while(!$ConfigPath) {
        Write-BoltLog "searching for $FileName in $SearchFrom" -level verbose
        $ConfigPath = (Get-ChildItem -Path $SearchFrom -Filter $FileName -ErrorAction SilentlyContinue|Select-Object -first 1).FullName
        if([string]::IsNullOrEmpty($ConfigPath)) {
            if($null -eq $SearchFrom.Parent) {
                throw "Could not find $FileName in $startsearchFrom or any parent directory (stopped at $SearchFrom)"
            }
            $SearchFrom = $SearchFrom.Parent
        }
    }
    Write-BoltLog "Found $ConfigPath" -level verbose
    return [System.IO.FileInfo]$ConfigPath
}
#endregion

#region ..\.stage\code\acr\Open-JwtToken.ps1
function Open-JWTtoken {
 
    [cmdletbinding()]
    param([Parameter(Mandatory = $true)][string]$token)
 
    #Validate as per https://tools.ietf.org/html/rfc7519
    #Access and ID tokens are fine, Refresh tokens will not work
    if (!$token.Contains(".") -or !$token.StartsWith("eyJ")) { Write-Error "Invalid token" -ErrorAction Stop }
 
    #Header
    $tokenheader = $token.Split(".")[0].Replace('-', '+').Replace('_', '/')
    #Fix padding as needed, keep adding "=" until string length modulus 4 reaches 0
    while ($tokenheader.Length % 4) { 
        # Write-Verbose "Invalid length for a Base-64 char array or string, adding ="; 
        $tokenheader += "=" 
    }
    # Write-Verbose "Base64 encoded (padded) header:"
    # Write-Verbose $tokenheader
    #Convert from Base64 encoded string to PSObject all at once
    # Write-Verbose "Decoded header:"
    # [System.Text.Encoding]::ASCII.GetString([system.convert]::FromBase64String($tokenheader)) | ConvertFrom-Json | fl | Out-Default|Out-Null
 
    #Payload
    $tokenPayload = $token.Split(".")[1].Replace('-', '+').Replace('_', '/')
    #Fix padding as needed, keep adding "=" until string length modulus 4 reaches 0
    while ($tokenPayload.Length % 4) { 
        # Write-Verbose "Invalid length for a Base-64 char array or string, adding ="
        $tokenPayload += "=" 
    }
    # Write-Verbose "Base64 encoded (padded) payoad:"
    # Write-Verbose $tokenPayload
    #Convert to Byte array
    $tokenByteArray = [System.Convert]::FromBase64String($tokenPayload)
    #Convert to string array
    $tokenArray = [System.Text.Encoding]::ASCII.GetString($tokenByteArray)
    # Write-Verbose "Decoded array in JSON format:"
    # Write-Verbose $tokenArray
    #Convert from JSON to PSObject
    $tokobj = $tokenArray | ConvertFrom-Json
    # Write-Verbose "Decoded Payload:"
    
    return $tokobj
}
#endregion

#region ..\.stage\code\config\validate\Test-BoltConfigModule.ps1
function Test-BoltConfigModule {
    [CmdletBinding()]
    param (
        [boltConfigModule]$Config
    )

    New-BoltLogContext -command "validate.config.module"

    if ($Config.folder -like "./*" -or $Config.folder -like "/*") {
        throw "module.folder cannot start with './' or '/'"
    }

    $ModulePath = join-path (Get-GitRoot) $Config.folder
    if ((test-path $ModulePath) -eq $false) {
        throw "Cannot find defined modulepath '$($ModulePath)'"
    }
}
#endregion

#region ..\.stage\code\config\Get-BoltConfig.ps1
function Get-BoltConfig {
    [CmdletBinding()]
    [OutputType([boltconfig])]
    param ()

    if(!$Global:BoltConfig){
        $param = @{
            SearchFrom = $pwd.Path
        }
        if($Global:boltconfig_search_path)
        {
            $param.SearchFrom = $Global:boltconfig_search_path
        }
        $Global:BoltConfig = New-BoltConfig @param
    }

    return $Global:BoltConfig
}
#endregion

#region ..\.stage\code\acr\Get-AcrRepository.ps1
function Get-AcrRepository {
    [CmdletBinding()]
    [OutputType([Microsoft.Azure.Commands.ContainerRegistry.Models.PSTagList])]
    param (
        [string]$Name,
        [string]$Registry
    )
    
    begin {
        if(!$Registry){
            $Registry = (get-acrContext).registry
        }
        
        if($Registry -like "*azurecr.io"){
            $Registry = $Registry -replace "\.azurecr\.io",""
        }
    }
    
    process {
        if(!$name){
            return Get-AzContainerRegistryRepository -RegistryName $Registry|ForEach-Object -ThrottleLimit 10 -Parallel {
                Get-AzContainerRegistryTag -RegistryName $using:Registry -RepositoryName $_
            }
        }
        Get-AzContainerRegistryTag -RegistryName $Registry -RepositoryName $Name
    }
    
    end {
        
    }
}
#endregion

#region ..\.stage\code\acr\Get-AcrRepositoryLayer.ps1
function Get-AcrRepositoryLayer {
    [CmdletBinding()]
    [Outputtype([AcrRepositoryLayer])]
    param (
        [parameter(mandatory)]
        [Microsoft.Azure.Commands.ContainerRegistry.Models.PSTagList]$Repository,
        [string]$Tag,
        [int]$AssumeCount = 0,

        # [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', Justification = 'well it is used..so.. i dunno?')]
        [switch]$IncludeContent
    )
    begin {}
    process {
        $Call = Invoke-AcrCall -Repository $Repository -Path "manifests/$Tag" -Method GET -ea Stop
        if($call.layers.count -eq 0){
            throw "Got no layers in acr repo. this is not supported."
        }
        if($AssumeCount -gt 0){
            if($Call.layers.count -gt $assumeCount){
                throw "Got more than $assumecount layers in acr repo. this is not supported."
            }
        }

        foreach($Layer in $Call.layers|Where-Object{$_}){
            $out = [AcrRepositoryLayer]@{
                repository = $Repository.ImageName
                tag        = $tag
                digest     = $Layer.digest
                size       = $Layer.size
                mediaType  = $Layer.mediaType
                contentPath = ""
            }
            # $Layer.digest = $Layer.digest.replace("sha256:","")
            if($IncludeContent -eq $true){
                # Write-BoltLog "Downloading layer $($_.digest) from $Repository"
                $tempFilePath = join-path $env:TEMP $Layer.digest.replace(":","_")
                # $tempFile = New-Item -Path $Path -ItemType File -Force
                Write-BoltLog "Downloading layer $($Layer.digest) from $($Repository.ImageName):$tag to $tempFilePath" -level verbose
                Invoke-AcrCall -Repository $Repository -Path "blobs/$($Layer.digest)" -Method GET -ContentType "application/octet-stream" -OutFile $tempFilePath|out-null
                $out.ContentPath = $tempFilePath
            }
            Write-Output $out
        }
        # $Call.layers |?{$_}| % {
        #     $out = [AcrRepositoryLayer]@{
        #         repository = $Repository.ImageName
        #         tag        = $tag
        #         digest     = $_.digest
        #         size       = $_.size
        #         mediaType  = $_.mediaType
        #         contentPath = ""
        #     }
        #     # Write-BoltLog ($_|ConvertTo-Json -Depth 10 -Compress)
        #     # $contentPath = ""
        #     if($IncludeContent -eq $true){
        #         # Write-BoltLog "Downloading layer $($_.digest) from $Repository"
        #         $tempFilePath = join-path $env:TEMP $_.digest.replace(":","_")
        #         # $tempFile = New-Item -Path $Path -ItemType File -Force
        #         Write-BoltLog "Downloading layer $($_.digest) from $($Repository.ImageName):$tag to $tempFilePath" -level verbose
        #         Invoke-AcrCall -Repository $Repository -Path "blobs/$($_.digest)" -Method GET -ContentType "application/octet-stream" -OutFile $tempFilePath|out-null
        #         $out.ContentPath = $tempFilePath
        #     }
        #     Write-Output $out
        # }
    }
    
    end {
        # $OutList|%{
        #     Write-Output $_
        # }
        # return $OutList
    }
}
#endregion

#region ..\.stage\code\log\Write-BoltLog.ps1
function Write-BoltLog {
    [CmdletBinding()]
    param (
        $message,
        [ValidateSet("info", "warning", "error", "success", "verbose","dev")]
        [string]$level = "info",
        [switch]$AlwaysWrite
    )
    
    begin {
        $colors = @{
            info    = "Cyan"
            warning = "DarkYellow"
            error   = "Red"
            success = "Green"
            verbose = "yellow"
            dev     = 'DarkMagenta'
        }

        $levelshort = @{
            info    = "Inf"
            warning = "Wrn"
            error   = "Err"
            success = "Suc"
            verbose = "Ver"
            dev     = 'dev'
        }
    }
    process {
        $msg = $message -join ""
        $ContextString = ""
        if ($Global:logContext) {
            $ContextString = $Global:logContext.ToString()
        }


        # if verbose is set to silent and $alwayswrite isnt activated , don't write verbose messages
        if (!$AlwaysWrite -and $level -eq "verbose" -and $VerbosePreference -eq "SilentlyContinue") {
            return
        }
        if (($Level -eq 'dev' -and $global:boltDev -ne $true) -or $global:pester_enabled) {
            return
        }

        Write-Host "[$($levelshort[$level])]$ContextString - $msg" -ForegroundColor $colors[$level]
    }
    end {}
}
#endregion

#region ..\.stage\code\config\validate\Test-BicepInstallation.ps1
function Test-BicepInstallation {
    [CmdletBinding()]
    param (
        [string]$configVersion = "10.0.0"
    )
    New-BoltLogContext -command 'validate_bicep'
    # $Config = Get-BoltConfig

    #check if bicep is installed
    $bicep = Get-Command bicep -ea SilentlyContinue
    if (!$bicep) {
        Write-BicepInstallInfo -InstallInfo install
        # $this.MessageBicepInstall([bicepInstallType]::install)
        throw "Could not find bicep in path. Please install bicep"
    }

    #check if bicep version is correct
    #returns Bicep CLI version 0.18.4 (1620479ac6)
    $ver = bicep --version
    $ver = $ver -replace '.*version ', ''
    $InstalledVersion = ($ver -replace ' .*', '').trim()
    if ($InstalledVersion -lt $configVersion) {
        Write-BicepInstallInfo -InstallInfo upgrade
        # $this.MessageBicepInstall([bicepInstallType]::upgrade)
        Write-BoltLog -level warning "Bicep version is too low. Expected $($configVersion) but found $($InstalledVersion)"
        throw "Bicep version too low. Expected $($configVersion) but found $($InstalledVersion)"
    }

    #give warning if the bicep version defined is really low
    $lowestRecomendedVersion = Get-BicepVersion -What Lowest
    if ($configVersion -lt $lowestRecomendedVersion) {
        Write-BoltLog -level warning -message "config Bicep version very is low ($configVersion). you should set it to minimum $lowestRecomendedVersion for best performance and conversion handling"
    }
}
#endregion

#region ..\.stage\code\versionControl\Write-ModuleUpdateStatus.ps1
function Write-ModuleUpdateStatus {
    [CmdletBinding()]
    param (
        [parameter(Mandatory,ValueFromPipeline)]
        [ModuleUpdateTest]$Test
    )
    
    begin {
        $defaultLogLevel = "Info"
    }
    
    process {
        # $global:t = 
        # Write-BoltLog "$($Test.type): $($Test.reasons.count)" -level $defaultLogLevel
        #foreach in dictionary
        Foreach($ReasonList in $Test.reasons.GetEnumerator()){
            $TestType = $Test.type.ToString().toupper()
            $ReasonListName = $ReasonList.key
            #foreach in list
            Foreach($Reason in $ReasonList.Value)
            {
                # Write-BoltLog ($Reason| ConvertTo-Json -Depth 3)
                $ReasonInfo = (@("$($Reason.key)", $($Reason.detail)) | Where-Object { $_ }) -join "."
                switch ($Reason.type) {
                    ([ModuleUpdateType]::added) {
                        Write-BoltLog "$($TestType):    add '$reasonListName'-> $reasonInfo $($Reason.newValue)" -level $defaultLogLevel
                    }
                    ([ModuleUpdateType]::removed) {
                        Write-BoltLog "$($TestType): remove '$reasonListName'-> $reasonInfo $($Reason.oldValue)" -level $defaultLogLevel
                    }
                    ([ModuleUpdateType]::modified) {
                        Write-BoltLog "$($TestType): modify '$reasonListName'-> $reasonInfo old: $($reason.oldValue) new: $($reason.newValue)" -level $defaultLogLevel
                    }
                    ([ModuleUpdateType]::other) {
                        Write-BoltLog "$($TestType):  other '$reasonListName'-> $reasonInfo $($reason.message)" -level $defaultLogLevel
                    }
                    default{
                        Write-BoltLog "$($TestType):default '$reasonListName'-> $reasonInfo $($reason.message)" -level $defaultLogLevel
                    }
                }
            }
        }
    }
    
    end {
        
    }
}
#endregion

#region ..\.stage\code\Get-GitRoot.ps1
function Get-GitRoot {
    $err = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'stop'
        $GitRoot = git rev-parse --show-toplevel 2>&1
        if ($GitRoot -like '*not a git repository*') {
            throw 
        }

    } catch {
        throw "This is not designed to function outside a git repo (you are in '$($pwd.Path)'). should possibly be '$($global:BoltRoot)'?)"
    } finally {
        $ErrorActionPreference = $err
    }
    return $GitRoot
}
#endregion

#region ..\.stage\code\config\validate\Get-BicepVersion.ps1
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
#endregion

#region ..\.stage\code\bicep\Build-BicepDocument.ps1
function Build-BicepDocument {
    [CmdletBinding()]
    param (
        [parameter(Mandatory)]
        [System.IO.FileInfo]$File,
        [parameter(Mandatory)]
        [System.IO.FileInfo]$OutputFile,
        [System.IO.FileInfo]$LogFile
    )
    begin {
    }
    process {
        if (!$LogFile) {
            $RandomFileName = "$([System.IO.Path]::GetRandomFileName()).log"
            [System.IO.FileInfo]$LogFile = (join-path $env:TEMP $RandomFileName)
        }
        if($OutputFile.Exists){
            $OutputFile.Delete()
        }
        New-item -Path $LogFile.FullName -ItemType File -Force -WhatIf:$false | Out-Null
        Write-BoltLog " template path $OutputFile" -level verbose
        Write-BoltLog " log path $LogFile" -level verbose
        $cmd = "bicep build '$($file.FullName)' --outfile '$($OutputFile.FullName)' *> $($LogFile.FullName)"#'
        # Write-BoltLog $cmd
        $whatif = $WhatIfPreference
        $whatifpreference = $false

        # [Diagnostics.CodeAnalysis.SuppressMessageAttribute('AvoidUsingInvokeExpression', '', Justification = 'Used for global token hander singleton')]
        [scriptblock]::create($cmd).Invoke() #| Invoke-Expression

        $whatifpreference = $whatif
        # Write-BoltLog "bicep build $($file.FullName) --outfile $($OutputFile.FullName) *>> $($LogFile.FullName)"
        # $ea = $ErrorActionPreference 
        # $ErrorActionPreference = 'SilentlyContinue'
        # bicep build "$($file.FullName)" --outfile $($OutputFile.FullName) |%{
        #     Write-BoltLog $_ -level verbose
        # } # --outfile "$($OutputFile.FullName)" #*> "$($LogFile.FullName)"
        # $ErrorActionPreference = $ea

        if($?){
            Write-BoltLog "bicep build completed successfully" -level verbose
        }
        else{
            Write-BoltLog "bicep build failed" -level verbose
        }
        $ConvertLog = Get-Content $LogFile.FullName
        # $ConvertLog | % {
        #     Write-BoltLog $_ -level info
        # }
        $ConvertLog | Where-Object { $_ -like "*: Warning *" }|ForEach-Object{
            Write-BoltLog $_ -level warning
        }
        $ConvertLog | Where-Object { $_ -like "*: Error *" }|ForEach-Object{
            Write-BoltLog $_ -level error
        }
    }
    
    end {
        
    }
}
#endregion

#region ..\.stage\code\Convert-HashtableToArray.ps1
function Convert-HashtableToArray {
    [CmdletBinding()]
    [OutputType([ordered])]
    param (
        [parameter(ValueFromPipeline)]
        $InputItem,
        [string]$address = "",
        [string[]]$ExcludeKeys = @(),
        [ValidateSet("object", "array")]
        [string[]]$excludeTypes
    )
    process {
        # Write-host "$address = $($InputItem.GetType().name)"
        $Output = [ordered]@{}
        # if([bool]$ExcludeKeys|%{$address -like "*$_*"}){
        #     return
        # }
        if ($InputItem -is [array]) {
            $Output[$address] = $InputItem
            for ($i = 0; $i -lt $_.value.Count; $i++) {
                $ArrAddress = "$address[$i]"
                # Write-Verbose "$ArrAddress is a $($InputItem[$i].gettype())"
                $Output[$ArrAddress] += Convert-HashtableToArray -InputItem $InputItem[$i] -address $ArrAddress
            }
        } elseif ($InputItem -is [hashtable]) {
            if ($address -ne "") {
                $Output[$address] = $inputItem
            }
            foreach ($item in $InputItem.GetEnumerator()) {
                $ThisAddress = (@($address, $item.key) | Where-Object { ![string]::IsNullOrEmpty($_) }) -join "."
                switch ($item) {
                    { $_.value -is [hashtable] } {
                        # Write-Verbose "$ThisAddress is a hashtable"
                        $Output += Convert-HashtableToArray -InputItem $Item.value -address $ThisAddress
                    }
                    { $_.value -is [array] } {
                        for ($i = 0; $i -lt $_.value.Count; $i++) {
                            $ArrAddress = "$ThisAddress[$i]"
                            $Output += Convert-HashtableToArray -address $ArrAddress -InputItem $_.value[$i]
                        }
                    }
                    default {
                        $Output[$ThisAddress] = $item.Value
                    }
                }
            }
        } else {
            # Write-Verbose "$address is a $($InputItem.gettype())"
            $Output[$address] = $item
        }
        
        $keys = $Output.Keys|ForEach-Object{$_}
        foreach($key in $keys){
            $match = $ExcludeKeys|Where-Object{$key -like "$_"}
            if($match){
                # Write-Verbose "removing key $key`: $match"
                $Output.Remove($key)
            }
        }
        $values = $Output.GetEnumerator()|ForEach-Object{$_}
        foreach($val in $values){
            # Write-Verbose "$($val.Key) is a $($val.Value.gettype())"
            if($excludeTypes -eq 'object'){
                if($val.value -is [hashtable] -or $val.value -is [ordered]){
                    # Write-Verbose "!removing value $($val.Key)`: $match"
                    $Output.Remove($val.Key)
                }
            }
            if($excludeTypes -eq 'array'){
                if($val.value -is [array]){
                    # Write-Verbose "!removing value $($val.Key)`: $match"
                    $Output.Remove($val.Key)
                }
            }
        }
        return $Output
    }
}
#endregion

#region ..\.stage\code\acr\context\Get-AcrContext.ps1
function Get-AcrContext {
    [CmdletBinding()]
    param ()
    
    begin {
        
    }
    
    process {
        if(!$global:_acr){
            throw "Acr context not set. Please run Set-AcrContext before, not using the -Registry parameter"
        }
        return $global:_acr
    }
    
    end {
        
    }
}
#endregion

#region ..\.stage\code\acr\Get-AcrRegistryRepositoryToken.ps1
function Get-AcrRegistryRepositoryToken {
    [CmdletBinding()]
    [Outputtype([string])]
    param (
        [string]$exchangeToken,
        [parameter(ParameterSetName = 'repoName')]
        [string]$registry,
        [parameter(ParameterSetName = 'repoName',Mandatory)]
        [string]$RepositoryName,
        [parameter(ParameterSetName = 'repoObj',Mandatory)]
        [Microsoft.Azure.Commands.ContainerRegistry.Models.PSTagList]$Repository
    )

    if(!$registry){
        $registry = (get-acrContext).registry
    }
    switch($PSCmdlet.ParameterSetName){
        'repoName' {
            $Repository = Get-AcrRepository -registry $registry -name $RepositoryName
        }
        'repoObj' {
        }

    }

    if(!$exchangeToken){
        $exchangeToken = ConvertFrom-SecureString -SecureString (get-acrContext).tokens.refresh_token -AsPlainText
    }

    $Scope = "repository:$($Repository.ImageName)`:*"
    $exchangeUri = "https://$registry/oauth2/token"
    if(!$global:_acrtoken){
        $global:_acrtoken = @{}
    }
    $ScopeAccessToken = $global:_acrtoken[$scope]
    if($ScopeAccessToken){
        # Write-host "acrtoken found for $scope"
        $Jwt = Open-JWTtoken -token $ScopeAccessToken
        # write-host ([DateTime]('1970,1,1')).AddSeconds($Jwt.exp)
        if(([DateTime]('1970,1,1')).AddSeconds($Jwt.exp) -gt (get-date -AsUTC))
        {
            return $ScopeAccessToken
        }
    }
    Write-BoltLog "Getting ACR token for $scope" -level verbose
    $param = @{
        Uri    = $exchangeUri
        Method = "post"
        Body   = @{
            grant_type    = "refresh_token"
            service       = $registry 
            scope         = $scope
            refresh_token = $exchangeToken
        }
        ErrorAction = 'Stop'
    }
    $verb = $VerbosePreference
    try{
        $VerbosePreference = "SilentlyContinue"
        $acr_token = Invoke-RestMethod @param
    }
    finally{
        $VerbosePreference = $verb
    }
    $global:_acrtoken[$scope] = $acr_token.access_token
    return $acr_token.access_token
}
#endregion

#region ..\.stage\code\acr\context\Set-AcrContext.ps1
function Set-AcrContext {
    [CmdletBinding()]
    param (
        [string]$Registry,
        [Microsoft.Azure.PowerShell.Cmdlets.ContainerRegistry.Models.Api202301Preview.Registry]$azRegistry
    )
    begin {
    }
    process {
        if($azRegistry){
            $Registry = $azRegistry.LoginServer
        }
        Write-Verbose "Setting ACR context to $Registry"
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Used for global token hander singleton')]

        $global:_acr = @{
            Registry = $Registry
            Tokens = @{
                refresh_token = Get-AcrRegistryExchangeToken -registry $Registry
            }
        }
    }
    
    end {
        
    }
}
#endregion

#region ..\.stage\code\config\Find-BoltConfigFile.ps1
function Find-BoltConfigFile {
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo])]
    param (
        [System.IO.DirectoryInfo]$SearchFrom = (Get-Location).Path
    )

    $ConfigFileName = "bolt.json"
    if($global:pester_enabled) {
        $ConfigFileName = "bolt.pester.json"
    }
    return (Find-File -SearchFrom $SearchFrom -FileName $ConfigFileName)
}
#endregion

#region ..\.stage\code\acr\Invoke-AcrCall.ps1
function Invoke-AcrCall {
    [CmdletBinding()]
    param (
        [ValidateSet('v1', 'v2')]
        [string]$ApiVersion = 'v2',
        
        [parameter(
            parameterSetName = 'repository',
            ValueFromPipeline
        )]
        [Microsoft.Azure.Commands.ContainerRegistry.Models.PSTagList]$Repository,

        [string]$Path,

        [system.io.fileinfo]$OutFile,

        [ValidateNotNullOrEmpty()]
        [ValidateSet('GET', 'POST', 'PUT', 'DELETE')]
        $Method = "GET",
        $ContentType = "application/json"
    )
    
    begin {}
    process {
        $Registry = (get-acrContext).registry
        $RepositoryName = $Repository.ImageName
        $Url = "https://$Registry/$ApiVersion/$RepositoryName/$Path"
        $AcrToken = Get-AcrRegistryRepositoryToken -Repository $Repository

        $Accept = @(
            'application/vnd.cncf.oras.artifact.manifest.v1+json;q=0.3'
            'application/vnd.oci.image.manifest.v1+json;q=0.4'
            'application/vnd.docker.distribution.manifest.v2+json;q=0.5'
            'application/vnd.docker.distribution.manifest.list.v2+json;q=0.6'
        )
        $param = @{
            uri     = $Url
            method  = $Method
            headers = @{
                'Docker-Distribution-Api-Version' = 'registry/2.0'
                Authorization                     = (@("bearer", $AcrToken) -join " ")
                Accept                            = $Accept -join ", "
            }
            ContentType = $ContentType
            ea      = "stop"
        }
        if($OutFile){
            New-item -Path $OutFile.FullName -ItemType File -Force | Out-Null
            $Param.OutFile = $OutFile
        }
        Write-BoltLog "Calling $Url" -level verbose
        # Write-Verbose "Calling $Url"
        $Verb = $VerbosePreference
        $verbosePreference = "SilentlyContinue"
        Invoke-RestMethod @param -ErrorAction Stop -Verbose:$false
        $verbosePreference = $Verb
    }
    
    end {
        
    }
}
#endregion

#region ..\.stage\code\config\validate\Write-BicepInstallInfo.ps1
function Write-BicepInstallInfo {
    [CmdletBinding()]
    param (
        [ValidateSet(
            "install",
            "upgrade"
        )]
        [String]$InstallInfo
    )

    $methods = @{
        scoop = "scoop $InstallInfo bicep"
        winget = "winget $InstallInfo bicep"
        az = "az bicep $InstallInfo"
    }

    $methods.GetEnumerator() | ForEach-Object {
        $command = $_.Value
        $test = $_.Key
        if (Get-Command $test -ea SilentlyContinue) {
            Write-BoltLog -level warning -message "command: $command"
        }
    }
    Write-BoltLog -level warning -message "manual: download from 'https://github.com/Azure/bicep/releases'"
}
#endregion

#region ..\.stage\code\versionControl\Test-BoltReleaseTrigger.ps1
function Test-BoltReleaseTrigger {
    [CmdletBinding()]
    [OutputType([ModuleUpdateTest])]
    param (
        [System.IO.FileInfo]$LocalTemplate,
        [System.IO.FileInfo]$RemoteTemplate,
        [string]$Name,
        [string[]]$Rules,
        [Switch]$LogEverything
    )
    
    begin {
        
    }
    
    process {
        
        <#
        rules:
            "paramAddedWithoutDefaultValue",
            "paramRemoved",
            "paramTypeModified",
            "paramAllowedValueModified",
            "paramDefaultValueModified",
            "resourceAdded",
            "resourceTypeModified",
            "resourceApiVersionModified",
            "resourcePropertiesAdded",
            "resourcePropertiesRemoved",
            "resourcePropertiesModified",
            "moduleModified"
        
        #>
        $VersionTest = [ModuleUpdateTest]::new($Name)

        $Templateparam = @{
            LocalTemplate  = $LocalTemplate
            RemoteTemplate = $RemoteTemplate
        }

        $testcases = @{
            module           = $VersionTest.NewReasonList('module')
            parameter        = $VersionTest.NewReasonList('parameter')
            resources        = $VersionTest.NewReasonList('resources')
            outputs          = $VersionTest.NewReasonList('outputs')
            # resourceProperty = $VersionTest.NewReasonList('resource.properties')
        }

        #general. just to make sure the remote file exists
        # Write-BoltLog "null or empty? $([string]::IsNullOrEmpty($RemoteTemplate))"
        # Write-BoltLog "exists? $(Test-Path $RemoteTemplate)"
        if ([string]::IsNullOrEmpty($RemoteTemplate) -or !(Test-Path $RemoteTemplate)) {
            $reason = [ModuleUpdateReason]::Other('module', "non-existant remote item")
            $testcases.module.Add($reason)
            return $VersionTest
        }

        $rulesString = $($Rules|ForEach-Object{"'$_'"}) -join ','
        Write-BoltLog "Command For Test: Test-BoltReleaseTrigger -LocalTemplate '$($LocalTemplate.FullName)' -RemoteTemplate '$($RemoteTemplate.FullName)' -Name '$Name' -Rules @($rulesString) -LogEverything|Write-ModuleUpdateStatus" -level 'dev'
        # Write-BoltLog "Local template path: $($LocalTemplate.FullName)"
        # Write-BoltLog "Remote template path: $($RemoteTemplate.FullName)"

        $objectParam = @{
            LocalObject    = Get-Content $LocalTemplate.FullName -Raw | ConvertFrom-Json -AsHashtable
            RemoteObject   = Get-Content $RemoteTemplate.FullName -Raw | ConvertFrom-Json -AsHashtable
        }

        $logparam = @{
            LogEverything = $LogEverything.IsPresent
        }

        Write-BoltLog "$($Rules.Count) rules to test" -level 'verbose'
        # New-BoltLogContext -subContext 'releasetrigger'
        switch -wildcard ($Rules) {
            "param*"{
                Test-BoltTriggerOnParam @objectParam -rule $_ @logparam|ForEach-Object{
                    $testcases.parameter.Add($_)
                }
            }
            "resource*"{
                Test-BoltTriggerOnResource @objectParam -rule $_ @logparam|ForEach-Object{
                    $testcases.resources.Add($_)
                }
            }
            "outputs*"{
                Test-BoltTriggerOnOutput @objectParam -rule $_ @logparam|ForEach-Object{
                    $testcases.outputs.Add($_)
                }
            }
            "moduleModified" {
                Test-BoltmoduleModified @Templateparam @logparam| ForEach-Object {
                    $testcases.module.Add($_)
                }
            }
            default {
                Write-BoltLog -Message "Invalid rule: $_" -level 'warning'
            }
        }
        # Write-BoltLog "done testing"
        return $VersionTest
    }
    
    end {
        
    }
}
#endregion

#region ..\.stage\code\versionControl\releaseTests\Test-BoltTriggermoduleModified.ps1
function Test-BoltmoduleModified {
    [CmdletBinding()]
    [OutputType([ModuleUpdateReason])]
    param (
        [System.IO.FileInfo]$LocalTemplate,
        [System.IO.FileInfo]$RemoteTemplate,
        [switch]$LogEverything
    )
    $LocalDigest = New-DigestHash -Item $LocalTemplate -Algorithm SHA256
    $RemoteDigest = New-DigestHash -Item $RemoteTemplate -Algorithm SHA256
    if($LocalDigest -ne $RemoteDigest){
        if($LogEverything)
        {
            Write-BoltLog "Template file has changed" -level "dev"
        }
        Write-Output ([ModuleUpdateReason]::Modified('file digest', "$($LocalDigest.split(":")[1].Substring(0, 10))..", "$($RemoteDigest.split(":")[1].Substring(0, 10)).."))
    }
}
#endregion

#region ..\.stage\code\log\New-BoltLogContext.ps1
function New-BoltLogContext {
    [CmdletBinding()]
    param (
        [string]$context,
        [string]$subContext,
        [string]$command
    )
    begin {
        if (!$global:logContext) {
            # $lc = [LogContext]::new("process")
            # $lc.context = "process"
            $global:logContext = [LogContext]::new("process")
        }
        if ($context) {
            $global:logContext.context = $context
        }
        if ($subContext) {
            $global:logContext.subContext = $subContext
        }
        if($command)
        {
            $global:logContext.AddCommandContext($command, (Get-PSCallStack)[1])
        }
    }
    process {
        
    }
    end {
        # $global:logContext = $null
    }
}
#endregion

#region ..\.stage\code\config\Get-CurrentDeploymentVersions.ps1
function Get-CurrentDeploymentVersion {
    [CmdletBinding()]
    param (
        [ValidateNotNullOrEmpty()]
        [boltConfigRelease[]]$Versions,

        [string]$Branch,

        [ValidateNotNullOrEmpty()]
        [string]$DefaultBranch
    )

    begin {
        if(!$branch -and !$DefaultBranch){
            throw "Either branch or default branch must be specified"
        }elseif(!$Branch){
            $Branch = $DefaultBranch
        }
    }

    process {
        $ret = $Versions|Where-Object{$_.name -eq $Branch}
        if(!$ret){
            throw "No versioning config found for branch '$Branch'. avalible: $($Versions.name |Select-Object -Unique)"
        }
        return $ret
    }

    end {
    }
}
#endregion

#region ..\.stage\code\versionControl\releaseTests\Test-BoltTriggerOnParam.ps1
function Test-BoltTriggerOnParam {
    [CmdletBinding()]
    [OutputType([ModuleUpdateReason])]
    param (
        [hashtable]$LocalObject,
        [hashtable]$RemoteObject,
        [string]$Rule,
        [switch]$LogEverything
    )
    New-BoltLogContext -command "paramTest $rule"
    # Write-BoltLog "PARAMETER RULE: $rule" -level 'dev'
    $ignorewarn = @{
        WarningAction = "SilentlyContinue"
    }
    <#
        "paramAddedWithoutDefaultValue",
        "paramRemoved",
        "paramTypeModified",
        "paramAllowedValueModified",
        "paramDefaultValueModified",
    #>
    #region General Param checks
    $RemoteParamKeys = $RemoteObject.parameters.Keys
    $LocalParamKeys = $LocalObject.parameters.Keys
    $LocalParamKeysInRemote = $LocalParamKeys | Where-Object { $_ -notin $RemoteParamKeys }
    Switch ($Rule) {
        "paramAdded" {
            $LocalParamKeysInRemote | ForEach-Object {
                Write-Output ([ModuleUpdateReason]::Added($_, "$($LocalObject.parameters[$_].type)"))
            }
        }
        "paramAddedWithoutDefaultValue" {
            $LocalParamKeysInRemote | ForEach-Object {
                $ParamValue = $LocalObject.parameters[$_]
                if ([string]::IsNullOrEmpty($ParamValue.defaultValue) -and $ParamValue.nullable -ne $true) {
                    Write-Output ([ModuleUpdateReason]::Added($_, "$($ParamValue.type) w/o default value"))
                }
            }
        }
        "paramRemoved" {
            $RemovedKeys = $RemoteParamKeys | Where-Object { $_ -notin $LocalParamKeys }

            $RemovedKeys | Where-Object { $_ } | ForEach-Object {
                Write-Output ([ModuleUpdateReason]::Removed("param", $_))
            }
        }
    }
    #endregion General Param checks

    #region foreach param checks
    if ($null -ne $LocalObject.parameters) {
        $LocalParams = $LocalObject.parameters.GetEnumerator()
    } else {
        $LocalParams = @{}.GetEnumerator()
    }
    # foreach local parameter that exists in the remote object
    foreach ($_LocalParam in $LocalParams | Where-Object { $_.key -in $RemoteParamKeys }) {
        if ($LogEverything) {
            Write-boltLog "parameter: $($_LocalParam.key)" -level 'dev'
        }
        $LocalParam = $_LocalParam.value
        $LocalParamName = $_LocalParam.key
        $RemoteParamName = $RemoteParamKeys | Where-Object { $_ -eq $LocalParamName } | Select-Object -First 1
        $RemoteParam = $RemoteObject.parameters[$RemoteParamName]

        Switch ($Rule) {
            #check if the parameter name has changed, case sensitive
            "paramCaseModified" {
                if ($LogEverything) {
                    Write-BoltLog " local: $LocalParamName" -level 'dev'
                    Write-BoltLog "remote: $RemoteParamName" -level 'dev'
                }
                if ($LocalParamName -cne $RemoteParamName) {
                    Write-Output ([ModuleUpdateReason]::Modified(
                            "parameter." + $LocalParamName + ".case",
                            $LocalParamName,
                            $RemoteParamName
                        ))
                }
            }
            #check if the parameter type has changed
            "paramTypeModified" {
                if ($LogEverything) {
                    Write-BoltLog " local: $($LocalParam.type|ConvertTo-Json -Compress @ignorewarn)" -level 'dev'
                    Write-BoltLog "remote: $($RemoteParam.type|ConvertTo-Json -Compress @ignorewarn)" -level 'dev'
                }
                if ($LocalParam.type -ne $RemoteParam.type) {
                    Write-Output ([ModuleUpdateReason]::Modified(
                            "parameter." + $LocalParamName + ".type",
                            $RemoteParam.type,
                            $LocalParam.type
                        ))
                }
            }
            #check if the parameter allowedValue has changed or removed
            {
                $_ -in "paramAllowedValueRemoved", "paramAllowedValueModified"
            } {
                if ($LogEverything) {
                    Write-BoltLog " local: $($LocalParam.allowedValues|ConvertTo-Json -Compress @ignorewarn)" -level 'dev'
                    Write-BoltLog "remote: $($RemoteParam.allowedValues|ConvertTo-Json -Compress @ignorewarn)" -level 'dev'
                }
                $RemoteParam.allowedValues | Where-Object { $_ -notin $LocalParam.allowedValues } | ForEach-Object {
                    Write-Output ([ModuleUpdateReason]::Removed(
                            "$LocalParamName.allowValues",
                            $_
                        ))
                }
            }
            #check if the parameter allowedValue has changed or added
            {
                $_ -in "paramAllowedValueAdded", "paramAllowedValueModified"
            } {
                if ($LogEverything) {
                    Write-BoltLog " local: $($LocalParam.allowedValues|ConvertTo-Json -Compress @ignorewarn)" -level 'dev'
                    Write-BoltLog "remote: $($RemoteParam.allowedValues|ConvertTo-Json -Compress @ignorewarn)" -level 'dev'
                }
                if ($LocalParam.allowedValues -ne $RemoteParam.allowedValues) {
                    $LocalParam.allowedValues | Where-Object { $_ -notin $RemoteParam.allowedValues } | ForEach-Object {
                        Write-Output ([ModuleUpdateReason]::Added(
                                "$LocalParamName.allowValues",
                                $_
                            ))
                    }
                }

            }
            #check if the parameter defaultValue has changed
            "paramDefaultValueModified" {
                if ($LogEverything) {
                    Write-BoltLog " local: $($LocalParam.defaultValue|ConvertTo-Json -Compress @ignorewarn)" -level 'dev'
                    Write-BoltLog "remote: $($RemoteParam.defaultValue|ConvertTo-Json -Compress @ignorewarn)" -level 'dev'
                }
                if (($LocalParam.defaultValue | ConvertTo-Json) -ne ($RemoteParam.defaultValue | ConvertTo-Json)) {
                    Write-Output ([ModuleUpdateReason]::Modified(
                            "parameter." + $LocalParamName + ".defaultValue",
                            $LocalParam.defaultValue,
                            $RemoteParam.defaultValue
                        ))
                }
            }
        }
    }
    #endregion foreach param checks
}
#endregion

#region ..\.stage\code\config\New-BoltConfig.ps1
function New-BoltConfig {
    [CmdletBinding()]
    [OutputType([boltconfig])]
    param (
        $SearchFrom = $pwd.Path
    )
    begin {
        $ConfigPath = Find-BoltConfigFile -SearchFrom $SearchFrom
    }
    process {
        $ConfigContent = Get-Content -Path $ConfigPath

        #TODO: insert validate schema here
        $ConfigObject = $ConfigContent|ConvertFrom-Json -AsHashtable

        try{
            $config = [boltconfig]$ConfigObject
            $config.validate()
            $config.SetConfigDirectory(($ConfigPath|Split-Path -Parent))
            New-Variable -Name boltconfig_search_path -Value $SearchFrom -Scope Global -Force -WhatIf:$false
            New-Variable -Name boltconfig -Value $config -Scope Global -Force -WhatIf:$false

            return $Global:Boltconfig
        }
        catch{
            Write-boltlog -level verbose -message "STACKTRACE:"
            Write-boltlog -level verbose -message $_.ScriptStackTrace
            Write-boltlog -level error -message "Could not convert object to boltConfig: $_"
            throw $_
        }
    }
    end {
    }
}
#endregion

#region ..\.stage\code\config\validate\Test-BoltPublishTrigger.ps1
function Test-BoltConfigReleaseTrigger {
    [CmdletBinding()]
    param (
        [boltConfigReleaseTrigger]$Triggers
    )
    
    begin {
        $AllTests = @(
            "paramCaseModified",
            "paramAddedWithoutDefaultValue",
            "paramRemoved",
            "paramTypeModified",
            "paramAllowedValueModified",
            "paramDefaultValueModified",
            "resourceAdded",
            "resourceRemoved",
            "resourceApiVersionModified",
            "resourcePropertiesAdded",
            "resourcePropertiesRemoved",
            "resourcePropertiesModified",
            "outputsAdded",
            "outputsRemoved",
            "outputsModified",
            "moduleModified"
        )
    }
    
    process {
        $used = @()
        @(
            $triggers.static.update,
            $triggers.semantic.major,
            $triggers.semantic.minor,
            $triggers.semantic.patch
        )|ForEach-Object{
            $used += $_
        }
        $used|ForEach-Object{
            Write-boltlog "Used test: $_" -level 'dev'
        }

        $unused = $AllTests | Where-Object { $used -notcontains $_ }
        if($unused){
            Write-BoltLog "There are release tests that are unused. this might make the release process less robust. please advice if you want to include them." -level 'warning'
            $unused|ForEach-Object {
                Write-BoltLog "Unused test: $_" -level 'warning'
            }
        }
    }
    
    end {
        
    }
}
#endregion

#region ..\.stage\code\Test-BicepCli.ps1
function Test-BicepCli {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [string]$BicepVersion
    )

    $bicep = Get-Command bicep -ea SilentlyContinue
    if (!$bicep) {
        Write-Warning "Bicep not found"
        return $false
    }

    $(bicep --version) -match "(?'ver'\d+\.\d+\.\d+)" | Out-Null
    if ($matches.ver -lt $bicepVersion) {
        Write-Warning "the installed bicep version ($($matches.ver)) is less than the required version ($($config.bicepVersion)). please update"
        return $false
    }
    return $true
}
#endregion

#region ..\.stage\code\config\validate\Test-BoltConfigRegistry.ps1
function Test-BoltConfigRegistry {
    [CmdletBinding()]
    param (
        [boltConfigRegistry]$Config
    )
    New-BoltLogContext -command 'validate_registry'

    switch($Config.type){
        'acr'{
            # Test-BoltConfigRegistryAcr -Config $Config
            Write-BoltLog -level verbose -message "Testing registry tenant $($Config.tenantId)"
            try{
                Invoke-RestMethod -Uri "https://login.microsoftonline.com/$($Config.tenantId)/v2.0/.well-known/openid-configuration" -ea stop -verbose:$false|out-null
            }
            catch{
                throw "tenant id '$($Config.tenantId)' is not a tenant in microsoft azure/entra"
            }

            if ($null -eq (get-aztenant -tenantid $Config.tenantId)) {
                Throw "Could not find defined tenantId '$($Config.tenantId)' (are you logged in?)"
            }
            Write-BoltLog -level verbose -message "Testing registry subscription $($Config.subscriptionId)"

            $guid = [guid]'00000000-0000-0000-0000-000000000000'
            if(![guid]::TryParse($Config.subscriptionId, [ref]$guid)) {
                throw "registry.subscriptionid needs to be a guid, not a name"
            }
            $tenant = get-aztenant -tenantid $Config.tenantId
            $Subscription = (get-azsubscription -tenantid $tenant.id -SubscriptionId $Config.subscriptionId -ea SilentlyContinue)
            if (!$Subscription) {
                Throw "Could not find defined subscriptionId '$($Config.subscriptionId)'"
            }
            # $context = get-azcontext
            if($context.Tenant.Id -ne $tenant.id){
                Write-BoltLog "setting context from tenant $($context.Tenant.Id) to tenant $($Config.tenantId)"
                Set-AzContext -TenantId $tenant.Id -Subscription $config.subscriptionId -WarningAction SilentlyContinue -ErrorAction Stop -WhatIf:$false | Out-Null
            }
            # $context = get-azcontext

            # if ((get-azcontext).Subscription.Id -ne $Subscription.Id) {
            #     Write-BoltLog -level verbose -message "Setting context to subscription $($Subscription.Name)"
            #     $Subscription | Set-AzContext -WarningAction SilentlyContinue -ErrorAction Stop -WhatIf:$false | Out-Null
            # }

            Write-BoltLog -level verbose -message "Testing registry '$($Config.type)' '$($Config.name)'"
            $filter = "resourceType EQ 'Microsoft.ContainerRegistry/registries' AND name EQ '$($Config.name)'"
            $ApiVersion = '2021-04-01'
            $_Uri = @(
                "subscriptions"
                "/"
                $($Config.subscriptionId)
                "/"
                "resources?`$filter=$filter&api-version=$ApiVersion"
            )
            $uri = $_Uri -join ""
            Write-BoltLog -level verbose -message "check if registry exists:'$($Uri -join '')'"
            try{
                $k = Invoke-AzRest -Path $uri -Verbose:$false -ErrorAction Stop
                $resource = ($k.Content | ConvertFrom-Json).value
                if($resource.count -lt 1){
                    throw "Could not find defined registry"
                }
            }
            catch{
                # Write-BoltLog -level verbose -message $_
                throw "error tyrying to find $($Config.type) '$($Config.name)' in subscription '$($Config.subscriptionId)': $_"
            }
            # $Resource = Get-AzResource - #-ResourceType 'Microsoft.ContainerRegistry/registries' -Name $Config.name 
            # if (!$Resource) {
            # }
        }
        default{
            throw "Unknown registry type '$($config.type)'"
        }
    }


}
#endregion

#region ..\.stage\code\acr\Get-AcrRegistryExchangeToken.ps1
function Get-AcrRegistryExchangeToken {
    [CmdletBinding()]
    [Outputtype([securestring])]
    param (
        [string]$registry
    )
    
    $token = Get-AzAccessToken -Verbose:$false
    if($registry -like "https://*") {
        $registry = $registry -replace "https://", ""
    }
    
    $registryUrl = "https://$registry"
    $exchangeUri = "$RegistryUrl/oauth2/exchange"
    $param = @{
        Uri         = $exchangeUri
        Method      = 'post'
        Headers     = @{
            Authorization = (@("bearer", $token.Token) -join " ")
        }
        Body        = @{
            grant_type   = "access_token"
            service      = $registry 
            tenant       = (get-azcontext).tenant.id
            access_token = $token.Token
        }
        ErrorAction = 'Stop'
    }
    $verb = $VerbosePreference
    try{
        $VerbosePreference = "SilentlyContinue"
        $acr_token = Invoke-RestMethod @param -Verbose:$false
    }
    finally{
        $VerbosePreference = $verb
    }
    #convert to secure string
    $Secure = [securestring]::new()
    $acr_token.refresh_token -split ''|Where-Object{![string]::IsNullOrEmpty($_)} | ForEach-Object {
        $Secure.AppendChar($_)
    }
    
    return $Secure #$acr_token.refresh_token
}
#endregion

#endregion functions


#region MAIN
Set-Variable -Scope global -Name BoltRoot -Value $PSScriptRoot -Force -WhatIf:$false

$global:publishAction = @{
    CreateUpdateData = $false
    Publish          = $false
    CleanRegistry    = $false
}

if ($Actions -contains "All") {
    $keys = $publishAction.Clone().keys
    $keys | ForEach-Object {
        $publishAction[$_] = $true
    }
} else {
    $Actions | ForEach-Object {
        $publishAction[$_] = $true
    }
}

if ((get-module az -list | Select-Object -first 1).version -lt "10.0.0") {
    Throw "Az module version 10.0.0 or higher is required on system. (https://www.powershellgallery.com/packages/Az/10.0.0)"
}

$importModules = @(
    "az.accounts"
    "az.resources"
    "Az.ContainerRegistry"
)

$verb = $VerbosePreference
$dbg = $DebugPreference
$VerbosePreference = "SilentlyContinue"
$DebugPreference = "SilentlyContinue"
$importModules | ForEach-Object {
    Write-Host "Importing module $_"
    Import-Module $_ -ErrorAction Stop
}
$VerbosePreference = $verb
$DebugPreference = $dbg


if ($Dotsource) {
    Write-Host -Message "Bolt is dotsourced in. all functions are available in the global scope."
    return
}
# Write-SolutionHeader
# Write-host "version $BuildId"
New-BoltLogContext -context "publish_modules" -subContext "main"
Write-BoltLog "Loading Config"
$Config = New-BoltConfig

$Versions = Get-CurrentDeploymentVersion -Versions $Config.publish.releases -Branch $Branch -DefaultBranch $Config.publish.defaultRelease
Write-BoltLog "Current deployment branch: $($Versions.name|Select-Object -Unique)"


if (!(Test-BicepCli -BicepVersion $config.bicepVersion)) {
    throw "Bicep needs to be installed, at least version $($config.bicepVersion)"
}

# TODO add a check for .gitignore and that it have a .biceptemp
$TempFolder = join-path $config.GetConfigDirectory() ".bicepTemp"
if ((test-path $TempFolder) -eq $false) {
    New-item -Path $TempFolder -ItemType Directory -WhatIf:$false | Out-Null
}

$ModuleRoot = join-path (Get-GitRoot) $config.module.folder

#Region Process BicepConfig
$BicepConfig = Get-BicepConfig -path $ModuleRoot
if($BicepConfig.symbolicNameCodegenEnabled() -eq $false){
    Write-BoltLog "Symbolic name codegen is disabled. It is highly recomended to enable this under bicepconfig.experimentalfeatures. this enabled " -level warning
}
#endregion


Write-BoltLog "Getting bicep modules from $ModuleRoot"

$BicepModules = Get-ChildItem -Path $ModuleRoot -Filter "main.bicep" -Recurse | ForEach-Object {
    $_ | Add-Member -MemberType NoteProperty -Name 'RepoName' -Value ([System.io.path]::GetRelativePath($ModuleRoot, $_.Directory.FullName).Replace("\", "/"))
    $_
}

if ($BicepModules.count -eq 0) {
    Write-BoltLog "No modules found in $ModuleRoot" -level warning
    return
}
# return

#Figure out what modules to publish

if ($Name) {
    $ModulesToPublish = $BicepModules | Where-Object {
        $_.RepoName -like $name
    }
} else {
    $ModulesToPublish = @()
}

if ($List) {
    return $BicepModules.RepoName
}

New-BoltLogContext -subContext 'verify'

# $BicepModuleNames = $ModulesToPublish | ForEach-Object { [System.io.path]::GetRelativePath($ModuleRoot, $_.Directory.FullName).Replace("\", "/") }
$BicepManyModules = $BicepModules.RepoName | Group-Object | Where-Object { $_.count -gt 1 }
$BicepManyModules | ForEach-Object {
    Write-BoltLog "$($_.name) has several modules with the same name. This will cause issues when publishing." -level warning
}
if ($BicepManyModules) {
    throw "There are several modules with the same name. This will cause issues when publishing."
}

New-BoltLogContext -subContext 'Connect'
#make sure im in the correct context
Write-BoltLog "Getting correct az context"
$context = get-azcontext
if ($context.Subscription.id -ne $config.registry.subscriptionId) {
    Write-BoltLog "changing az context from $($context.Subscription.id) to $($config.registry.subscriptionId)"
    Set-AzContext -Subscription $config.registry.subscriptionId -WhatIf:$false -Tenant $config.registry.tenantId -ea Stop
}

#get resource and token for resource
Write-BoltLog "getting acr resource $($config.registry.name)" -level verbose
$resource = Get-AzResource -ResourceType 'Microsoft.ContainerRegistry/registries' -Name $Config.registry.name
if (!$resource) {
    throw "Could not find remote registry $($config.registry.name)"
}
# Write-host ($resource|convertto-json    )
$remoteRegistry = Get-AzContainerRegistry -SubscriptionId $resource.SubscriptionId -Name $resource.Name -ResourceGroupName $resource.ResourceGroupName
if (!$remoteRegistry) {
    throw "Could not find remote registry $($config.registry.name)"
}

Write-BoltLog "Setting acr context to $($remoteRegistry.LoginServer)"
set-acrContext -Registry $remoteRegistry.LoginServer
# $Repos = Get-AcrRepository


New-BoltLogContext -subContext 'ProcessModules'

if ($global:publishAction.Publish -eq $false -and $global:publishAction.CreateUpdateData -eq $false) {
    $ModulesToPublish = @()
}
Write-BoltLog "Processing $($ModulesToPublish.count) modules ($(($publishAction.Keys|Where-Object{$publishAction.$_ -eq $true}) -join ", "))"

$Timing = @{
    process     = [System.Diagnostics.Stopwatch]::New()
    acr_cleanup = [System.Diagnostics.Stopwatch]::New()
}
$statistics = [System.Collections.Hashtable]::Synchronized(@{})
# return
$ThrottleLimit = 2
if ($ModulesToPublish.count -gt 1) {
    $throttleLimit = $ModulesToPublish.count / 2
}

# dont run if publish and createupdate is false. 
# I still need the list for later registry cleanup, so i copy it to a new variable


#run async
<#TODO: 
    make async import functions imported via this script. 
    i want to be able to contain everything in one script for easier shipping, 
    but right now, the only way this is possible is to generate a hashtable of classes and function files to import for each runspace.
    one idea is to possibly have a array of function names, and then import the functions directly using $function: + name, but i dont know if that will work every time
#>
$Timing.process.Start()
$scriptPath = $MyInvocation.MyCommand.ScriptBlock.File
# $scriptPath
# return
$job = $ModulesToPublish | ForEach-Object -ThrottleLimit $throttleLimit -AsJob -Parallel {
    $BicepFile = $_
    $ModuleRoot = $using:ModuleRoot
    $RepoName = [System.io.path]::GetRelativePath($ModuleRoot, $BicepFile.Directory.FullName).Replace("\", "/").ToLower()
    $global:boltDev = [bool]$using:global:boltDev
    $scriptPath = $using:scriptPath

    #adding stats
    $statistics = $using:statistics
    $thisStat = [ordered]@{
        added              = 0
        updated            = 0
        skipped            = 0
        failed_bicep_error = 0
        failed             = 0
    }
    $statistics.Add($RepoName, $thisStat)

    # Write-host "test"
    #region inside job
    try {
        . $scriptPath -Dotsource
        # $ScriptDependencies = $using:ScriptDependencies
        # foreach ($item in $ScriptDependencies.GetEnumerator()) {
        #     # Write-Host "importing $($item.key)"
        #     foreach ($_importfile in $item.value) {
        #         . $_importfile.FullName
        #     }
        #     #something is fishy.. sometimes something else in this script just overrides the content inside the script im loading
        #     $_importfile = $null
        # }

        #region init
        

        #importing modules. for some reason i cant just use -verbose:$false when importing modules
        # $verb = $VerbosePreference
        # $dbg = $DebugPreference
        # $VerbosePreference = "SilentlyContinue"
        # $DebugPreference = "SilentlyContinue"
        # $using:importModules | ForEach-Object {
        #     Import-Module $_ -ErrorAction Stop
        # }
        # $VerbosePreference = $verb
        # $DebugPreference = $dbg

        #for some reason i cant use 'using' when defining parameters

        New-BoltLogContext -context $RepoName -subContext "main"



        Write-BoltLog "Processing $RepoName" -level verbose

        $TempFolder = $using:TempFolder
        $config = $using:Config
        $global:publishAction = $using:publishAction
        $VerbosePreference = $using:VerbosePreference
        $DebugPreference = $using:debugPreference
        $ErrorActionPreference = 'Stop'
        $WhatIfPreference = $using:WhatIfPreference
        $global:_acr = $using:global:_acr
        $global:ModuleActions = $using:golbal:ModuleActions

        # $AcrRepo = $null


        $RepoNameLocal = $RepoName.Replace("/", "_")
        $logfile = @{
            build  = join-path $TempFolder "$RepoNameLocal`_build.log"
            deploy = join-path $TempFolder "$RepoNameLocal`_deploy.log"
        }
        $hashFile = join-path $TempFolder "$RepoNameLocal`_hashes.json"
        $armFile = join-path $TempFolder "$RepoNameLocal`_template.json"

        #validate that there is a cache file
        if (!(test-path $hashFile)) {
            New-Item -Path $hashFile -ItemType File -WhatIf:$false | Out-Null
        }

        #clear log files, if it exists (most likely from a previous run that failed)
        $logfile.values | ForEach-Object {
            if (test-path $_) {
                Remove-Item -Path $_ -Force -WhatIf:$false
            }
        }
        #endregion init

        #region CONVERT
        #get hash from cache -> will be empty if not already converted
        #if arm template is not converted or bicep file has changed, convert
        # $testparam = @{
        #     BicepFile       = $BicepFile
        #     HashFile        = $hashFile
        #     ArmTemplateFile = $armFile
        # }
        New-BoltLogContext -subContext "build".PadRight(10)
        #convert to arm
        Write-BoltLog "Converting $($BicepFile.FullName) to arm template" -level verbose
        $param = @{
            File       = $BicepFile
            LogFile    = $LogFile.build
            OutputFile = $armFile
        }
        Build-BicepDocument @param
        if (!(Test-Path $armFile)) {
            $thisStat.failed_bicep_error++
            Write-BoltLog "Failed to convert $($BicepFile.FullName) to arm template" -level error
            return
        }
        # if (Test-BicepShouldBuild @testparam) {
        # } else {
        #     Write-BoltLog "Skipping conversion, no changes detected" -level verbose
        # }
        # $ThisHash.Arm = New-DigestHash -Item $armFile -Algorithm sha256
        Write-BoltLog "Getting hashes for $($armFile)" -level verbose
        @{
            bicep = New-DigestHash -Item $BicepFile -Algorithm sha256
            arm   = New-DigestHash -Item $armFile -Algorithm sha256
        } | ConvertTo-Json -Depth 10 | Out-File $hashFile -Force
        #endregion CONVERT

        #getting remote repo
        $AcrRepo = Get-AcrRepository -Name $RepoName -ea SilentlyContinue
        if (!$AcrRepo) {
            $thisStat.added++
            Write-BoltLog "New repo!" -level success
        }


        #region UPDATE VERSION
        :versionUpload foreach ($activeVersion in $($using:Versions)) {
            New-BoltLogContext -subContext $activeVersion.trigger.padright(10)
            # Write-BoltLog "Processing version $($activeVersion.trigger)" 
            # Write-BoltLog "pref = $VerbosePreference, $($using:VerbosePreference)"
            $target = $null
            $targetRepo = "br:$($global:_acr.Registry)/$RepoName"

            # $WriteHostPrefix = "$reponame`:$($activeVersion.type)"
            switch ($activeVersion.trigger) {
                "static" {
                    #region static
                    #TODO Make these things into cmdlets for easier script-administration
                    #check if repo has tag
                    $VersionValue = $activeVersion.value
                    if ($activeVersion.prefix) {
                        $VersionValue = $activeVersion.prefix + $VersionValue
                    }

                    #Getting tags from repo
                    $AcrRepositoryTag = $AcrRepo.tags | Where-Object { $_.name -eq $VersionValue } | Select-Object -first 1
                    # $param = @{
                    #     LocalTemplate = $armFile
                    #     RemoteTemplate = $AcrRepositoryTagLayer.Content
                    #     Name = "$($activeVersion.trigger):$($AcrRepositoryTag.Name)"
                    #     Rules = $config.publish.releasetrigger.static.update
                    # }
                    # $Trigger = Test-BoltReleaseTrigger @param
                    # # Write-BoltLog "Count: $($Trigger.Count)"
                    # Write-ModuleUpdateStatus $Trigger
                    if (!$AcrRepositoryTag) {
                        Write-BoltLog "New tag! $($VersionValue)" -level success
                    } else {
                        Write-BoltLog "remote repo tag: $($AcrRepositoryTag.Name)"

                        #if not defined outside of try/catch, it will not be set for some reason
                        $AcrRepositoryTagLayer = $null

                        #get layer with content. 
                        try {
                            $param = @{
                                Repository     = $AcrRepo
                                Tag            = $AcrRepositoryTag.Name
                                IncludeContent = $true
                                AssumeCount    = 1
                            }
                            $AcrRepositoryTagLayer = Get-AcrRepositoryLayer @param | Select-Object -first 1
                        } catch {
                            $thisStat.skipped++
                            Write-BoltLog "Skipped! error $_" -level warning
                            continue :versionUpload
                        }

                        $param = @{
                            LocalTemplate  = $armFile
                            RemoteTemplate = $AcrRepositoryTagLayer.ContentPath
                            Name           = "$($activeVersion.trigger):$($AcrRepositoryTag.Name)"
                            Rules          = $config.publish.releasetrigger.static.update
                        }
                        Write-BoltLog "Testing release trigger" -level verbose
                        $Trigger = Test-BoltReleaseTrigger @param

                        Write-ModuleUpdateStatus $Trigger

                        if ($Trigger.ShouldUpdate() -eq $false) {
                            Write-BoltLog "Skipped! No changes found"
                            $thisStat.skipped++
                            continue :versionUpload
                        }
                    }

                    $Target = "$targetRepo`:$($activeVersion.value)"
                    #endregion static
                }
                "semantic" {
                    #region semantic
                    #TODO Make these things into cmdlets for easier script-administration
                    $Regex = "(?'major'[0-9]+)\.(?'minor'[0-9]+)\.(?'rev'[0-9]+)"
                    $BicepDefinedVersionRegex = "^\/\/module_version(\s{0,1})=(\s{0,1})['`"]{0,1}$Regex['`"]{0,1}"

                    #default value
                    $UsingVersion = @($activeVersion.prefix, '0.0.1')

                    <#
                    tag has not been defined
                    bicep document has a higher version -> //version=1.0.1
                    #>
                    #Bicep defined version
                    $VersionDefinition = Get-Content $BicepFile.FullName | Select-Object -First 10 | Where-Object { $_ -like "//module_version*" } | ForEach-Object {
                        $_
                    } | Select-Object -first 1

                    #if version is defined, but not in the correct format, skip
                    if ($VersionDefinition -and $VersionDefinition -notmatch $BicepDefinedVersionRegex) {
                        $thisStat.skipped++
                        Write-BoltLog "Skipped! Version found '$VersionDefinition', but it's defined wrong. should be //module_version={major.minor.build/revision}" -level warning
                    } elseif ($VersionDefinition -match $BicepDefinedVersionRegex) {
                        $_version = $Matches.major + "." + $Matches.minor + "." + $Matches.rev
                        Write-BoltLog "Version defined in module: $($_version)" -level info
                        $UsingVersion[1] = $_version
                    }

                    #if you have defined a prefix in current version, match "{prefix}0.0.1"
                    #TODO: add support to look for 'any' version, is selected by config. helpfull for transition of prefix
                    if ($activeVersion.prefix) {
                        $AcrSearch = "^$($activeVersion.prefix)$regex$"
                    } 
                    #no prefix defined, only get tags that are scemantic (0.0.1)
                    else {
                        $AcrSearch = "^$regex$"
                    }

                    #get all tags that match the regex
                    $AcrRepositoryTag = $AcrRepo.tags | Where-Object { $_.name -match $AcrSearch }

                    #sort to get the highest version and get that one
                    $AcrRepositoryTag = $AcrRepositoryTag | Sort-Object name -Descending | Select-Object -first 1

                    #grab version. it will be in $matches
                    $AcrRepositoryTag.name -match $regex | out-null

                    #if its avalaible and the current published version is greater or equal than the locally defined version
                    if ($AcrRepositoryTag -and $AcrRepositoryTag.name -ge $(($UsingVersion | Where-Object { $_ }) -join '')) {
                        # Write-BoltLog "remote repo tag: $($AcrRepositoryTag.Name)"
                        #get the layer
                        $AcrRepositoryTagLayer = $null
                        try {
                            $param = @{
                                Repository     = $AcrRepo
                                Tag            = $AcrRepositoryTag.Name
                                IncludeContent = $true
                                AssumeCount    = 1
                            }
                            $AcrRepositoryTagLayer = Get-AcrRepositoryLayer @param | Select-Object -first 1
                        } catch {
                            $thisStat.skipped++
                            Write-BoltLog "Skipped! error $_" -level warning
                            continue :versionUpload
                        }

                        #extract regex keys
                        $versionMap = @{
                            major = [int]::Parse($Matches.major)
                            minor = [int]::Parse($Matches.minor)
                            rev   = [int]::Parse($Matches.rev)
                        }
                        $remoteVersion = "{0}.{1}.{2}" -f $versionMap.major, $versionMap.minor, $versionMap.rev
                        Write-BoltLog "remote repo version tag: $remoteVersion (name: $($AcrRepositoryTag.name))" -level info
                        # Write-Host "$WriteHostPrefix - remote repo version tag: $acrVersion (name: $($AcrRepositoryTag.name))" -ForegroundColor $color.info

                        #if remote version is greater or than local version, create new version, using remote version as base
                        if ($remoteVersion -ge $UsingVersion[1]) {
                            $changes = @{}

                            'major', 'minor', 'patch' | ForEach-Object {
                                $versionLevel = $_
                                $param = @{
                                    LocalTemplate  = $armFile
                                    RemoteTemplate = $AcrRepositoryTagLayer.ContentPath
                                    Name           = "$($activeVersion.trigger):$($versionLevel)"
                                    Rules          = $config.publish.releasetrigger.semantic.$versionLevel
                                }
                                Write-BoltLog "Testing release trigger for $versionLevel" -level verbose
                                $changes.$versionLevel = Test-BoltReleaseTrigger @param
                            }

                            if ($Changes.major.ShouldUpdate()) {
                                $Changes.major | Write-ModuleUpdateStatus
                                Write-BoltLog "Major version increased (X.0.0)" -level info
                                $versionMap.major++
                                $versionMap.minor = 0
                                $versionMap.rev = 0
                            } elseif ($changes.minor.ShouldUpdate()) {
                                $changes.minor | Write-ModuleUpdateStatus
                                Write-BoltLog "Minor version increased (0.X.0)" -level info
                                $versionMap.minor++
                                $versionMap.rev = 0
                            } elseif ($changes.patch.ShouldUpdate()) {
                                $changes.patch | Write-ModuleUpdateStatus
                                Write-BoltLog "Patch version increased (0.0.X)" -level info
                                $versionMap.rev++
                            } else {
                                Write-BoltLog "Skipped! No changes found"
                                $thisStat.skipped++
                                continue :versionUpload
                            }
                            $UsingVersion[1] = "{0}.{1}.{2}" -f $versionMap.major, $versionMap.minor, $versionMap.rev
                        }
                    } else {
                        Write-BoltLog "NEW MODULE!" -level info
                    }

                    #remove prefix if not defined
                    $UsingVersion = $UsingVersion | Where-Object { ![string]::IsNullOrEmpty($_) }

                    $Target = "$targetRepo`:$($UsingVersion -join '')"
                    #endregion semantic
                }
                default {
                    $thisStat.skipped++
                    Write-BoltLog "Skipped! the version trigger $($activeVersion.trigger) is not supported" -level warning
                    # Write-Host "$reponame - Skipped! $($activeVersion.branch)/$($activeVersion.type) -> $($activeVersion.value) is not supported" -ForegroundColor $color.warning
                    continue :versionUpload
                }
            }

            #the switch beforehand should create a target, but just in case any of the "continue" is not working.
            if ($target -and $publishAction.Publish) {
                $thisStat.updated++
                if ($WhatIfPreference) {
                    Write-BoltLog "WHATIF: should upload $($activeVersion.name)/$($activeVersion.trigger) -> $Target" -level success
                } else {
                    Write-BoltLog "Uploading $($activeVersion.name)/$($activeVersion.trigger) -> $Target" -level success
                    Publish-AzBicepModule -FilePath $BicepFile.FullName -Target $Target -Force -WarningAction SilentlyContinue 
                }
            }
        }
    } catch {
        # Write-BoltLog ($thisStat|ConvertTo-Json)
        $thisStat.failed++
        Write-BoltLog "Error: $($_.Exception.Message)" -level error
        # $_.ScriptStackTrace.split("`n") | % {
        #     $out = $_
        #     if ($out -like "*<scriptblock>*") {
        #         $line = $out.Split(":")[1].Substring(6)
        #         $out += " (in bolt.ps1:$([int]$line + 220))"
        #     }
        #     $out
        #     Write-BoltLog -message $out -level error
        # } 
        Write-BoltLog $_.ScriptStackTrace -level error
        throw $_
    }
    #endregion inside job
}

try {
    Write-BoltLog "job started, id: $($job.id), childjobs: $($job.childjobs.count)" -level dev
    $Out = @{}
    # $global:ChildId = 0
    while ($job.state -eq 'Running') {
        Foreach ($Childjob in $job.ChildJobs) {
            #add to childjob - report list if not already there
            if (!$out.ContainsKey($Childjob.Id)) {
                $out[$Childjob.Id] = @{
                    timer     = [System.Diagnostics.Stopwatch]::new()
                    state     = $Childjob.State
                    processed = $false
                }
            }

            #get current childjob report
            $ThisJob = $out[$Childjob.Id]

            #update state
            $ThisJob.state = $Childjob.State

            #start timer if not already started and childjob is running
            if ($Childjob.State -eq 'running' -and !$ThisJob.timer.IsRunning) {
                $ThisJob.timer.Start()
            }

            #stop timer if childjob is completed and timer is running
            if ($Childjob.State -eq 'Completed' -and $ThisJob.timer.IsRunning) {
                $ThisJob.timer.Stop()
            }
        }
        
        #all childjobs are completed
        $progress = ($job.ChildJobs | Where-Object { $_.State -eq 'Completed' }).count

        #figure out precent (current finished / total)*100
        $percent = (($progress / $ModulesToPublish.count) * 100)
        #round for activity to show nice number
        $percent = [math]::Round($percent, 0)

        #show childjob states (completed:x running:y failed:z)
        $states = $job.ChildJobs | Group-Object state | ForEach-Object { $_.name + ":" + $_.count }

        #calculate average time for completed childjobs
        $CompletedAverageSeconds = ($out.Values | Where-Object { $_.state -eq 'completed' } | ForEach-Object { $_.timer.elapsed.totalseconds } | Measure-Object -Average).Average

        #calculate remaining seconds (current not completed * average time for completed)
        $Seconds = [math]::Round(($ModulesToPublish.count - $progress) * $CompletedAverageSeconds, 0)
        # if($null -eq $Seconds) {
        #     $Seconds = 10
        # }
        Write-Progress -id 0 -Activity "Processing $($ModulesToPublish.count) modules" -Status "$states ($percent%)" -PercentComplete $percent -SecondsRemaining $Seconds

        #recevie info from childjobs that are completed and not already processed
        $job.ChildJobs | Where-Object { $_.State -eq 'completed' -and !$out.($_.id).processed } | ForEach-Object {
            $out.($_.id).processed = $true
            $_ | receive-job
        }

        Start-Sleep -Milliseconds 10
    }

    $job.ChildJobs | Where-Object { !$out[$_.id].processed } | ForEach-Object {
        $out.($_.id).processed = $true
        $_ | receive-job
    }
} catch {
    $job.StopJob()
    Write-BoltLog -message "Error @ job $($job.Id), child $($childjob.Id)" -level error
    $_
} finally {
    $Timing.process.Stop()
    Write-Progress -id 0 -Activity "Converting modules" -Completed
}


#CLEANUP REMOTE REGISTRY
if ($global:publishAction.CleanRegistry) {
    $Timing.acr_cleanup.Start()
    New-BoltLogContext -context 'Cleanup' -subContext 'main'
    Write-BoltLog "Cleaning up $($remoteRegistry.LoginServer)"

    Write-BoltLog "Getting remote repos"
    $Repos = Get-AcrRepository 
    $thisStat = @{
        repo_removed = 0
    }
    #just giving a random name to not conflict with other stats
    $statistics.Add("acr_remove_$([guid]::NewGuid().ToString())", $thisStat)
    Foreach ($repo in $Repos | Where-Object { $_.ImageName -notin $BicepModules.RepoName }) {
        $thisStat.repo_removed++
        Write-BoltLog "Removing $($repo.ImageName)"
        Remove-AzContainerRegistryRepository -RegistryName $remoteRegistry.Name -Name $repo.ImageName | out-null
    }
    $Timing.acr_cleanup.Stop()
}

New-BoltLogContext -context 'Statistics' -subContext 'main'

New-BoltLogContext -subContext 'timing'
Write-BoltLog -message "**Timings**"
$Timing.keys | ForEach-Object {
    $msg = ("{0:N0}" -f $Timing.$_.Elapsed.TotalSeconds) + "Sec"
    switch ($_) {
        'process' {
            $perItem = $Timing.$_.Elapsed.TotalSeconds / $ModulesToPublish.Count
            $msg += "- " + ("{0:N0}" -f $perItem) + "sec/module"
        }
    }
    Write-BoltLog -message "$_`: $msg" -level info
}

New-BoltLogContext -subContext 'other'
Write-BoltLog -message "**Other**"
$statistics.values.keys | Select-Object -Unique | ForEach-Object {
    Write-BoltLog -message "$_`: $(($statistics.values.$_|Measure-Object -Sum).Sum)" -level info
}
