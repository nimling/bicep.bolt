function Test-BoltTriggerOnParam {
    [CmdletBinding()]
    [OutputType([ModuleUpdateReason])]
    param (
        [hashtable]$LocalObject,
        [hashtable]$RemoteObject,
        [System.IO.FileInfo]$LocalTemplate,
        [System.IO.FileInfo]$RemoteTemplate,
        [string]$Rule
    )
    Write-BoltLog "PARAMETER RULE: $rule" -level 'dev'
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
    $RemoteParamKeys = $RemoteObject.parameters.Keys
    $LocalParamKeys = $LocalObject.parameters.Keys

    Switch ($Rule) {
        "paramAdded" {
            $LocalParamKeys | Where-Object { $_ -notin $RemoteParamKeys } | ForEach-Object {
                Write-Output ([ModuleUpdateReason]::Added($_, "$($LocalObject.parameters[$_].type)"))
            }
        }
        "paramAddedWithoutDefaultValue" {
            $LocalParamKeys | Where-Object { $_ -notin $RemoteParamKeys } | ForEach-Object {
                if ([string]::IsNullOrEmpty($LocalObject.parameters[$_].defaultValue)) {
                    Write-Output ([ModuleUpdateReason]::Added($_, "$($LocalObject.parameters[$_].type) w/o default value"))
                }
            }
        }
        "paramRemoved" {
            $RemovedKeys = $RemoteParamKeys | Where-Object { $_ -notin $LocalParamKeys }
            $RemovedKeys | ? { $_ } | ForEach-Object {
                Write-Output ([ModuleUpdateReason]::Removed("param", $_))
            }
        }
    }

    if($null -ne $LocalObject.parameters)
    {
        $LocalParams = $LocalObject.parameters.GetEnumerator()
    }
    else{
        $LocalParams = @{}.GetEnumerator()
    }
    # foreach local parameter that exists in the remote object
    foreach ($_LocalParam in $LocalParams | Where-Object { $_.key -in $RemoteParamKeys }) {
        Write-boltLog "parameter: $($_LocalParam.key)" -level 'dev'
        $LocalParam = $_LocalParam.value
        $LocalParamName = $_LocalParam.key
        $RemoteParamName = $RemoteParamKeys | ? { $_ -eq $LocalParamName } | Select-Object -First 1
        $RemoteParam = $RemoteObject.parameters[$RemoteParamName]

        Switch ($Rule) {
            "paramCaseModified" {
                Write-BoltLog " local: $LocalParamName" -level 'dev'
                Write-BoltLog "remote: $RemoteParamName" -level 'dev'
                if ($LocalParamName -cne $RemoteParamName) {
                    Write-Output ([ModuleUpdateReason]::Modified(
                            "parameter." + $LocalParamName + ".case",
                            $LocalParamName,
                            $RemoteParamName
                        ))
                }
            }
            "paramTypeModified" {
                Write-BoltLog " local: $($LocalParam.type|ConvertTo-Json -Compress @ignorewarn)" -level 'dev'
                Write-BoltLog "remote: $($RemoteParam.type|ConvertTo-Json -Compress @ignorewarn)" -level 'dev'
                if ($LocalParam.type -ne $RemoteParam.type) {
                    Write-Output ([ModuleUpdateReason]::Modified(
                            "parameter." + $LocalParamName + ".type",
                            $RemoteParam.type,
                            $LocalParam.type
                        ))
                }
            }
            {
                $_ -in "paramAllowedValueRemoved", "paramAllowedValueModified"
            } {
                Write-BoltLog " local: $($LocalParam.allowedValues|ConvertTo-Json -Compress @ignorewarn)" -level 'dev'
                Write-BoltLog "remote: $($RemoteParam.allowedValues|ConvertTo-Json -Compress @ignorewarn)" -level 'dev'
                $RemoteParam.allowedValues | Where-Object { $_ -notin $LocalParam.allowedValues } | ForEach-Object {
                    Write-Output ([ModuleUpdateReason]::Removed(
                            "$LocalParamName.allowValues",
                            $_
                        ))
                }
            }
            {
                $_ -in "paramAllowedValueAdded", "paramAllowedValueModified"
            } {
                Write-BoltLog " local: $($LocalParam.allowedValues|ConvertTo-Json -Compress @ignorewarn)" -level 'dev'
                Write-BoltLog "remote: $($RemoteParam.allowedValues|ConvertTo-Json -Compress @ignorewarn)" -level 'dev'
                if ($LocalParam.allowedValues -ne $RemoteParam.allowedValues) {
                    $LocalParam.allowedValues | Where-Object { $_ -notin $RemoteParam.allowedValues } | ForEach-Object {
                        Write-Output ([ModuleUpdateReason]::Added(
                                "$LocalParamName.allowValues",
                                $_
                            ))
                    }
                }

            }
            "paramDefaultValueModified" {
                Write-BoltLog " local: $($LocalParam.defaultValue|ConvertTo-Json -Compress @ignorewarn)" -level 'dev'
                Write-BoltLog "remote: $($RemoteParam.defaultValue|ConvertTo-Json -Compress @ignorewarn)" -level 'dev'
                if (($LocalParam.defaultValue|ConvertTo-Json) -ne ($RemoteParam.defaultValue|ConvertTo-Json)) {
                    Write-Output ([ModuleUpdateReason]::Modified(
                            "parameter." + $LocalParamName + ".defaultValue",
                            $LocalParam.defaultValue,
                            $RemoteParam.defaultValue
                        ))
                }
            }
        }
    }
}