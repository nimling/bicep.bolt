function Test-BoltTriggerOnResource {
    [CmdletBinding()]
    [OutputType([ModuleUpdateReason])]
    param (
        [hashtable]$LocalObject,
        [hashtable]$RemoteObject,
        [System.IO.FileInfo]$LocalTemplate,
        [System.IO.FileInfo]$RemoteTemplate,
        [string]$Rule
    )
    Write-BoltLog "RESOURCE RULE: $rule" -level 'dev'
    $JsonDepth = 2
    $ignorewarn = @{
        WarningAction = "SilentlyContinue"
    }
    if ($Rule -eq 'resourceAdded') {
        Write-BoltLog "local : $($LocalObject.resources.Keys|convertto-json -depth 1 @ignorewarn)" -level 'dev'
        Write-BoltLog "remote: $($RemoteObject.resources.Keys|convertto-json -depth 1 @ignorewarn)" -level 'dev'
        $LocalObject.resources.Keys | Where-Object { $_ -notin $RemoteObject.resources.Keys } | ForEach-Object {
            Write-BoltLog (($LocalObject.resources.$_.type + " " + $LocalObject.resources.$_.apiVersion))
            Write-Output ([ModuleUpdateReason]::Added($_, ($LocalObject.resources.$_.type + " " + $LocalObject.resources.$_.apiVersion)))
        }
        return
    }

    #check each existing resource agains the new resources
    $LocalKeys = $LocalObject.resources.Keys
    $RemoteKeys = $RemoteObject.resources.Keys
    $LocalKeys | Where-Object { $_ -in $RemoteKeys } | ForEach-Object {
        Write-BoltLog "resource: $_" -level 'dev'
        # $name = $_
        $localResource = $LocalObject.resources.$_
        $remoteResource = $RemoteObject.resources.$_

        switch ($rule) {
            'resourceTypeModified' {
                Write-BoltLog " local: $($localResource.type|convertto-json @ignorewarn)" -level 'dev'
                Write-BoltLog "remote: $($remoteResource.type|convertto-json @ignorewarn)" -level 'dev'

                if ($localResource.type -ne $remoteResource.type) {
                    Write-Output ([ModuleUpdateReason]::Modified(
                            $_, 
                            $remoteResource.type, 
                            $localResource.type
                        ))
                }
            }
            'resourceApiVersionModified' {
                Write-BoltLog " local: $($localResource.apiVersion|convertto-json @ignorewarn)" -level 'dev'
                Write-BoltLog "remote: $($remoteResource.apiVersion|convertto-json @ignorewarn)" -level 'dev'

                if ($localResource.apiVersion -ne $remoteResource.apiVersion) {
                    Write-Output ([ModuleUpdateReason]::Modified(
                            $_, 
                            $remoteResource.apiVersion, 
                            $localResource.apiVersion
                        ))
                }
            }
            'resourcePropertiesAdded' {
                Write-BoltLog " local: $($LocalKeys|convertto-json @ignorewarn)" -level 'dev'
                Write-BoltLog "remote: $($RemoteKeys|convertto-json @ignorewarn)" -level 'dev'

                $LocalKeys | Where-Object { $_ -notin $RemoteKeys } | ForEach-Object {
                    Write-Output ([ModuleUpdateReason]::Added($_, $localResource.properties.$_.type))
                }
            }
            'resourcePropertiesRemoved' {
                Write-BoltLog " local: $($LocalKeys|convertto-json @ignorewarn)" -level 'dev'
                Write-BoltLog "remote: $($RemoteKeys|convertto-json @ignorewarn)" -level 'dev'

                $RemoteKeys | ? { $_ -notin $LocalKeys } | % {
                    Write-Output ([ModuleUpdateReason]::Removed($_, $remoteResource.properties.$_.type))
                }
            }
            'resourcePropertiesModified' {
                if ($null -ne $localResource.properties) {
                    Write-BoltLog " local: $($localResource.properties|convertto-json @ignorewarn)" -level 'dev'
                    Write-BoltLog "remote: $($remoteResource.properties|convertto-json @ignorewarn)" -level 'dev'

                    if ($localResource.properties -is [hashtable]) {
                        :propSearch foreach ($localProp in $localResource.properties.GetEnumerator()) {
                            if ($localProp.key -notin $remoteResource.properties.Keys ) {
                                continue :propSearch
                            }
                            $remoteProp = $remoteResource.properties[$localProp.key]
    
                            #prop type changed
                            if ($localProp.value.type -ne $remoteProp.type) {
                                Write-Output ([ModuleUpdateReason]::Modified(
                                        "property." + $localProp.key + ".type",
                                        $remoteProp.type,
                                        $localProp.value.type
                                    ))
                                # $thisResourceReason.Add($reason)
                            }
                
                            #prop defaultValue changed
                            if ($localProp.value.defaultValue -ne $remoteProp.defaultValue) {
                                Write-Output [ModuleUpdateReason]::Modified(
                                    "property." + $localProp.key + ".defaultValue",
                                    $remoteProp.defaultValue,
                                    $localProp.value.defaultValue
                                )
                            }
                        }
                    } elseif ($localResource.properties -ne $remoteResource.properties) {
                        Write-Output [ModuleUpdateReason]::Modified(
                            "property." + $localProp.key,
                            $remoteResource.properties,
                            $localResource.properties
                        )
                    }
                }
            }
        }
    }
}