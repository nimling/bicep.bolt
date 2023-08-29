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
                if ([string]::IsNullOrEmpty($ParamValue.defaultValue)) {
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