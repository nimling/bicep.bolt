<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.PARAMETER Name
deployment name

.PARAMETER Folder
deployment resource group

.PARAMETER Context
deployment context

.PARAMETER DontWait
don't wait for deployment to start, this will show the last status of the deployment

.EXAMPLE
An example

.NOTES
General notes
#>
function Show-DeploymentProgress {
    [CmdletBinding()]
    param (
        [parameter(Mandatory)]
        [string]$Name,
        
        # [ValidateNotNullOrEmpty()]
        [parameter(Mandatory)]
        [string]$Folder,
        
        # [ValidateNotNullOrEmpty()]
        [parameter(Mandatory)]
        [ValidateSet(
            "ResourceGroup",
            "Subscription"
        )]
        [string]$Context,
        [Microsoft.Azure.Commands.Common.AzureLongRunningJob]$Job,
        [switch]$DontWait,
        [string]$tab = ""
    )
    begin {
        $global:DeployProgress = @{}
    }
    process {
        #generate deployment object. each context has a different way to get the deployment operations.
        #they are functionally the same, but different commands are used
        # $deployment = @{}
        Write-BaduVerb "Getting deploytarget for $context"
        switch ($context) {
            "ResourceGroup" {
                $DeployTarget = (Get-AzResourceGroup -Name $Folder).ResourceId
            }
            "Subscription" {
                $DeployTarget = "/subscriptions/" + (Get-AzContext).Subscription.Id
            }
            default {
                throw "Context '$_' not supported"
            }
        }

        $DeploymentId = "$($DeployTarget)/providers/Microsoft.Resources/deployments/$name"

        $DeployProgress.($DeploymentId) = @{
            id       = 0
            status   = "Waiting for $context deployment to start running in azure"
            Activity = "deployments/$name"
        }

        try {

            if (!$DontWait) {
                Write-BaduVerb "Waiting for deployment to start"
                Wait-ForDeploymentStart -DeploymentId $DeploymentId -Context $context -Job $job -Progress $DeployProgress.($DeploymentId)
            }

            #region check operations while deployments is running (asuming that deployment is not failed at)
            Write-BaduVerb "Deployment is starting.."
            do {
                $Deployment = Get-Deployment -id $DeploymentId -Context $context -Scope Current
                $SubDeployments = Get-Deployment -id $DeploymentId -Context $context -Scope Children
                foreach ($SubDeployment in $SubDeployments) {

                    #generate deployment id, as azure does not provide it
                    $SubDeployId = $DeployTarget + "/providers/Microsoft.Resources/deployments/" + $SubDeployment.DeploymentName

                    #append deployment to progress, if it is not already there
                    if (!$DeployProgress.ContainsKey($SubDeployId)) {
                        $DeployProgress.$SubDeployId = @{
                            id       = $DeployProgress.Count
                            status   = $SubDeployment.ProvisioningState
                            Activity = "deployments/$($SubDeployment.DeploymentName)"
                        }
                    }

                    $DeploymentProgress = $DeployProgress.$SubDeployId.clone()
                    #get operations for current deployment
                    $DeploymentOperations = Get-DeploymentOperation -id $SubDeployId -Context $context

                    #calculate percentage of operations that is done
                    # if ($DeploymentOperations.count -ne 0) {
                    #     $CountOperations = @($DeploymentOperations).count
                    #     $RunninOperationsCount = @($DeployOperation | Where-Object { $_.ProvisioningState -notin 'Succeeded', 'Failed' }).count
                    # }
                    
                    $DeploymentProgress.PercentComplete = 100
                    $DeploymentProgress.status = $SubDeployment.ProvisioningState
                    # Write-BaduVerb "status: $($SubDeployment.ProvisioningState)"
                    $UseColor = Get-StatusColor -provisioningState $SubDeployment.ProvisioningState
                    $DeploymentProgress.Activity = $usecolor + $($DeploymentProgress.Activity)

                    #handle deployment status
                    Write-Progress @DeploymentProgress

                    #region handle operations that is not a deployment (ie deployment of a actual resource, not a invokation of arm template)
                    #get operations that is not a deployment
                    $resourceDeployOperations = $DeploymentOperations | Where-Object { $_.TargetResource } | Where-Object { $_.TargetResource -notlike "*Microsoft.Resources/deployments*" }
                    #handle operations
                    foreach ($DeployOperation in $resourceDeployOperations) {
                        $ref = $DeployOperation.TargetResource.replace($DeployTarget, "")

                        #append operation to progress, if it is not already there
                        if (!$DeployProgress.ContainsKey($ref)) {
                            $DeployProgress.$ref = @{
                                id       = $DeployProgress.Count
                                status   = $DeployOperation.ProvisioningState
                                Activity = $DeployOperation.TargetResource.split("/")[-2..-1] -join "/"
                                ParentId = $DeploymentProgress.id
                            }
                        }

                        #The cololor jumps for some reason. trying to mitigate by only allowing color to be set once per status
                        if ($DeployProgress.$ref.status -ne $DeployOperation.ProvisioningState) {
                            $DeployOperationProgress = $DeployProgress.$ref.clone()
                            $DeployOperationProgress.status = "$($DeployOperation.ProvisioningState)/$($DeployOperation.StatusCode)"

                            $UseColor = Get-StatusColor -provisioningState $DeployOperation.ProvisioningState
                            $DeployOperationProgress.Activity = $usecolor + $DeployOperationProgress.Activity
                            # Write-BaduVerb ($DeployOperationProgress|ConvertTo-Json -Depth 3)
                            Write-Progress @DeployOperationProgress
                        }

                    }
                    #endregion
                }
                start-sleep -Seconds 1
            }while ($Deployment.ProvisioningState -in 'Running', 'Accepted')
            Write-BaduVerb $Deployment.ProvisioningState
            #endregion
        } catch {
            Write-BaduVerb "catch"
            throw $_
        } finally {
            Write-BaduVerb "Finally"
            #region finish up progressbars
            $global:DeployProgress.GetEnumerator() | ForEach-Object {
                $_.value.completed = $true 
                Write-Progress -Activity "done" -Status "done" -Completed -id $_.value.id 
            }
            #endregion
    
            #region handle errors
            $FinishedDeployments = Get-Deployment -Id $DeploymentId -Context $Context -Scope All
            $global:finishedDeployments = $FinishedDeployments
            $FinishedDeployments | ForEach-Object {
                Write-BaduVerb "$($_.DeploymentName) - $($_.ProvisioningState)"
            }
            $FailedDeployments = $FinishedDeployments | Where-Object { $_.ProvisioningState -eq 'Failed' }
            $CompletedDeployments = $FinishedDeployments | Where-Object { $_.ProvisioningState -ne 'Failed' }
            if ($FailedDeployments) {

                $FailedDeployments | ForEach-Object {
                    $SubDeployment = $_
                    $SubDeployId = $DeployTarget + "/providers/Microsoft.Resources/deployments/" + $SubDeployment.DeploymentName

                    $DeploymentOperations = Get-DeploymentOperation -id $SubDeployId -Context $context
    
                    Write-BaduWarning $(("-" * 10) + " deployment:deployments/" + $SubDeployment.DeploymentName + " " + ("-" * 10))
                    Write-BaduWarning "$(($DeploymentOperations|Where-Object{$_.ProvisioningState -eq 'Failed'}).count) errors"
    
                    #enumerate failed operations
                    $DeploymentOperations | Where-Object { $_.ProvisioningState -eq 'Failed' } | ForEach-Object {
                        $FailedOp = $_
                        # Write-BaduVerb "Failed: $($FailedOp|ConvertTo-Json)"
                        if ($FailedOp.TargetResource) {
                            Write-BaduWarning $(("-" * 10) + " operation:" + ($FailedOp.TargetResource.split("/")[-2..-1] -join "/") + " " + ("-" * 10))
                            Write-BaduWarning "$($FailedOp.TargetResource)"
                        }
                        Write-BaduWarning "$($FailedOp.StatusCode): $($FailedOp.StatusMessage)"
                    }
                }
    
                throw "$($FailedDeployments.count) deployments failed: see warning for details"
            }
            if ($CompletedDeployments) {
                Write-BaduInfo "$tab`deployments completed: $($CompletedDeployments.count)"
            }

            #endregion
        }
    }
    end {
        
    }
}