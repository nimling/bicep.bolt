function Invoke-BicepDeployment {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [parameter(
            ValueFromPipeline
        )]
        [System.IO.FileInfo]$BicepFile,
        [ValidateSet(
            "ResourceGroup",
            "Subscription"
        )]
        [string]$Context,
        [ValidateSet(
            "list",
            "dryRun",
            "default"
        )]
        [string[]]$action = "default"
    )
    
    begin {
        switch ($Context) {
            "ResourceGroup" {
                $tab = "  " * 2
            }
            "Subscription" {
                $tab = "  " * 1
            }
        }
    }
    process {
        # if($action -eq 'dryRun'){
        #     Write-BaduInfo "$tab$context`:$($BicepFile.Directory.BaseName)/$($BicepFile.BaseName)"
        # }
        $deployConfig = Get-DeployConfig
        Write-Information "$("->".Padleft($tab.Length," "))$context deployment`: $($BicepFile.Directory.BaseName)/$($BicepFile.BaseName)"
        if ($action -eq 'list') {
            return #"$tab$context`:$($BicepFile.Directory.BaseName)/$($BicepFile.BaseName)"
        }

        $_Param = @{
            TemplateFile                = $BicepFile.FullName
            SkipTemplateParameterPrompt = $true
            WarningAction               = "SilentlyContinue"
        }
        $_deployParam = @{
            # DeploymentDebugLogLevel = 'All'
            WhatIfResultFormat = 'FullResourcePayloads'
        }

        #region find param file
        $ParamName = "$($BicepFile.BaseName).parameters.json"
        $ParamFile = Get-ChildItem $BicepFile.Directory.FullName -Filter $ParamName | Select-Object -first 1

        if ($ParamFile) {
            Write-Information "$tab`Found parameterfile '$($ParamFile.Name)'"
            $_Param.TemplateParameterObject = ConvertTo-ParamObject -ParamFile $ParamFile.FullName -tab "$tab`t"
        } else {
            Write-Information "$tab`No parameterfile found. create one with name '$ParamName' if you need"
        }

        #endregion
        if ($WhatIfPreference -or $action -eq 'dryRun') {
            if (!$action -eq 'dryRun') {
                Write-BaduInfo "$tab`WHATIF Deploy parameters:"
            } else {
                Write-BaduInfo "$tab`DryRun parameters:"
            }
            ($_Param.TemplateParameterObject | convertto-json -Depth 10).split("`n") | ForEach-Object {
                Write-BaduInfo "$tab$_"
            }
            Write-BaduInfo "$tab`-----"
            if ($action -eq 'dryRun') {
                return
            }
        }
        $global:__deploy = $null
        $global:_BaduOutput = [ordered]@{}
        switch ($Context) {
            "ResourceGroup" {
                #todo: add settings for deployment
                $_Param.Mode = "Incremental"
                $_Param.ResourceGroupName = $BicepFile.Directory.Name | Remove-EnvNotation -Env $deployConfig.Environments.name
                $deployName = ((@($env, $BicepFile.BaseName).where{ $_ }) -join "-").Replace(" ", "-")
                if ($WhatIfPreference) {
                    if (!(Get-AzResourceGroup -Name $_Param.ResourceGroupName -ea SilentlyContinue)) {
                        Write-BaduWarning "ResourceGroup '$($_Param.ResourceGroupName)' does not exist. Not testing deployment as it would result in 'ResourceGroupNotFound'"
                        # $global:whatifResult += "deploy '$deployName' to $($_Param.ResourceGroupName)"
                        return
                    }
                }

                Write-Information "$tab`Testing rg deployment '$($BicepFile.BaseName)'"
                Write-BaduVerb "File: $($BicepFile.FullName)"
                

                $DeployTest = Test-AzResourceGroupDeployment @_Param
                if (($DeployTest | Get-DeploymentTestResult)) {
                    throw "$($BicepFile.Directory.BaseName)/$($BicepFile.BaseName) failed. please look at warnings for details"
                }

                #not setting it on param before now, cause test-azresourcegroupdeployment does not support it
                $_Param.Name = $deployName

                Write-Information "$tab`Deploying with name '$($_Param.Name)'"
                if ($WhatIfPreference) {
                    try {
                        New-AzResourceGroupDeployment @_Param @_deployParam -WhatIf #-WhatIfResultFormat FullResourcePayloads
                        # Get-AzResourceGroupDeploymentWhatIfResult @_param|Add-DeployWhatifresult -Name $deployName -Path $BicepFile.FullName
                        return
                    } catch {
                        throw $_
                    }
                }

                $global:__deploy = New-AzResourceGroupDeployment @_Param @_deployParam -AsJob
                Show-DeploymentProgress -job $global:__deploy -Context ResourceGroup -Name $_param.Name -Folder $_Param.ResourceGroupName -tab $tab
            }
            "Subscription" {
                $_param.Location = $deployConfig.deployLocation

                Write-Information "$tab`Testing $context Deployment '$($BicepFile.BaseName)'"
                Write-BaduVerb "File: $($BicepFile.FullName)"
                $DeployTest = Test-AzSubscriptionDeployment @_Param
                if ($DeployTest | Get-DeploymentTestResult) {
                    throw "Test of $($BicepFile.Directory.BaseName)/$($BicepFile.BaseName) failed: $($DeployTest)"
                }

                $_Param.Name = $BicepFile.BaseName.Replace(" ", "-")
                Write-Information "$tab`Deploying at $context with name '$($_Param.Name)'"
                if ($WhatIfPreference) {
                    New-AzSubscriptionDeployment @_Param @_deployParam -WhatIf -WhatIfResultFormat FullResourcePayloads
                    # $global:whatifResult += Get-AzSubscriptionDeploymentWhatIfResult @_param
                    return
                }

                $global:__deploy = New-AzSubscriptionDeployment @_Param @_deployParam -AsJob #-DeploymentDebugLogLevel All 
                Show-DeploymentProgress -job $global:__deploy -Context Subscription -Name $_Param.name -Folder (get-azcontext).subscription.name -tab $tab
            }
        }

        if ($global:__deploy) {
            # $global:__deploy | Wait-Job
            $global:_out = $global:__deploy | Receive-Job -wait
            $global:_out | 
            Where-Object { $_ -is [Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.PSResourceGroupDeployment] -or $_ -is [Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.PSDeployment] } | 
            ForEach-Object {
                $deploy = $_
                $global:_BaduOutput.($deploy.DeploymentName) = $deploy.Outputs
                if ($deployConfig.workflow.deployoutput_enabled -and $deploy.Outputs) {
                    switch ($deployConfig.workflow.deployoutput_style) {
                        'json' {
                            $deploy.Outputs | ConvertTo-Json
                        }
                        'object' {
                            $deploy.Outputs
                        }
                    }
                }
            }
        }
    }
    end {
    }
}