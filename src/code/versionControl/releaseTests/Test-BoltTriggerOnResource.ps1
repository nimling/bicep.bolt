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
            $Temp |%{
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