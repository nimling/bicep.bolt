function Build-DeployVariable {
    [CmdletBinding()]
    param (
        [parameter(
            ParameterSetName = 'parameterValue'
        )]
        [ValidateNotNullOrEmpty()]
        $val,

        [parameter(
            ParameterSetName = 'parameterValueReference'
        )]
        [System.Text.RegularExpressions.Group[]]$VarRefs
    )
    begin {
        $deployconfig = Get-DeployConfig
    }
    process {
        # if val is provided
        if ($PSCmdlet.ParameterSetName -eq "parameterValue") {
            $VarRefs = @(Get-VariableReferenceInString -String $val | Select-Object -Unique)

            if ($VarRefs.count -ne 0) {
                Write-BaduVerb "Found $($References.count) variable references in '$ParamName'"
            } else {
                Write-BaduDebug "No variable references found in '$ParamName'"
            }
        }

        foreach ($VarRef in $VarRefs) {
            Write-BaduVerb "handling variable '$($VarRef.value)'"
            $deployEnvVariable = Get-DeployConfigVariable -value $VarRef.Value
            Write-BaduVerb "$($tab)replacing '$($VarRef.value)' with $($deployEnvVariable.type)` value from '$($deployEnvVariable.source)'"

            switch ($deployEnvVariable.type) {
                'static' {
                    $replace = Build-StaticVariable -Variable $deployEnvVariable
                    $originalString = @($($deployConfig.dry.style[0]), $VarRef, $($deployConfig.dry.style[1])) -join ''
                    #decide if i should replace in string or replace the whole object
                    # Write-BaduVerb "val:$paramValue, orig:$originalString, rep:$replace"
                    if ($val -eq $originalString) {
                        Write-BaduVerb "Replacing whole object"
                        $val = $replace
                    } else {
                        Write-BaduVerb "Replacing value in string"
                        $val = $val.replace($originalString, $replace)
                    }
                }
                'keyvault' {
                    if (@($References).count -gt 1) {
                        throw "keyvault variables can not be called upon in combination with multiple other variables in same reference."
                    }
                    $deployEnvVariable.secret = Build-DeployVariable -val $deployEnvVariable.secret
                    $deployEnvVariable.vault = Build-DeployVariable -val $deployEnvVariable.vault

                    $val = Build-KeyvaultVariable -variable $deployEnvVariable
                }
                'identity' {
                    if (@($References).count -gt 1) {
                        throw "identity variables can not be called upon in combination with multiple other variables."
                    }
                    $val = Build-IdentityVariable -variable $deployEnvVariable
                }
                default {
                    throw "Unknown variable type '$($deployEnvVariable.type)'"
                }
            }
        }

        return $val
    }
    
    end {
        
    }
}