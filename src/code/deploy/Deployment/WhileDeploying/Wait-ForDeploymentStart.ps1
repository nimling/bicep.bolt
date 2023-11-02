function Wait-ForDeploymentStart {
    [CmdletBinding()]
    param (
        [String]$DeploymentId,
        [string]$Context,
        [Microsoft.Azure.Commands.Common.AzureLongRunningJob]$Job,
        [hashtable]$Progress
    )
    
    begin {
        $deployparam = @{
            id = $DeploymentId
            context = $Context
        }
        $Deployment = Get-Deployment @deployparam -Scope Current
    }
    process {
        $VerboseCount = 0
        :wait do {
            if ($job) {
                $status = $job.verbose | Select-Object -Skip $VerboseCount
                $status | ForEach-Object {
                    Write-BaduVerb $_
                    if ($_ -like "*provisioning status is running*") {
                        break :wait
                    }
                    $VerboseCount++
                }
            }

            $Deployment = Get-Deployment @deployparam -Scope Current
            Write-BaduVerb "Deployment status: $($Deployment.ProvisioningState)"
            $Progress.Status = "Waiting for $context deployment to start running in azure. Status: $($Deployment.ProvisioningState)"

            Write-Progress @Progress
            start-sleep -Milliseconds 200
        }while ($Deployment.ProvisioningState -notin 'Running', 'Accepted')

        $Progress.Status = "Deployment started running in azure"

        Write-progress @Progress -Completed 
    }
    end {}
}