Describe "Wait-ForDeploymentStart" -tag 'unit' {
    BeforeDiscovery {
        $TestCases = @(
            @{
                ShouldBe = $true
                testName = "return"
                expected = "Running" 
                timeout  = 3000
            }
            @{
                ShouldBe = $true
                testName = "return"
                expected = "Accepted" 
                timeout  = 3000
            }
            @{
                ShouldBe = $false
                testName = "not return"
                expected = "Anything Else" 
                timeout  = 3000
            }
        )


    }
    BeforeEach {
        #create a scritblock to mock the functionality and run it as a job.
        #Running tests for a "waiting" command is not ideal, as i need to test it async, so it doesnt block continued pester tests
        #its easier to say "wait for 3 seconds, then fail" if the cmdlet has errors
        #Get deployment reads from a file, so i can mock that, and then just wait for the cmdlet to return
        $Scriptblock = {
            param(
                [string]$Id,
                [string]$Context,
                [string]$Path
            )

            ipmo Az.Resources

            $VerbosePreference = 'Continue'
            $global:_path = $Path

            function Get-Deployment {
                param(
                    [string]$id, 
                    [string]$context
                )
                return (Gc "$global:_path/$id.json" | ConvertFrom-Json)
            }
            # Write-host $psScriptRoot
            . ".\Wait-ForDeploymentStart.ps1"

            $param = @{
                DeploymentId = $id
                Context      = $Context
                Progress     = @{
                    id       = 0
                    status   = "other"
                    activity = "test" 
                }
            }

            Wait-ForDeploymentStart @param -Verbose 
        }
        $WorkingDirectory = $PSScriptRoot

    }
    It "should <testName> if provisioning state goes to '<expected>'" -TestCases $TestCases {
        param(
            [bool]$shouldBe,
            [string]$expected,
            [string]$testName,
            [int]$timeout = 3000,
            [int]$switchAfter = 200
        )
       
        $ControlJson = join-path $testdrive "$testname.json"
        #create mock json 
        @{ProvisioningState = "Noting"}|convertto-json|out-file $ControlJson

        #start job
        $job = Start-Job -ScriptBlock $Scriptblock -WorkingDirectory $WorkingDirectory -ArgumentList @($testname, "ResourceGroup", $testdrive)

        #wait for internal loop to switch
        Start-Sleep -Milliseconds 600

        #it should now be in a holding pattern waiting for the correct state to show up
        $job.State | should -Be "Running" -Because "scriptblock to test should be working"
        # $job.Verbose|select -last 1|should -BeLike "*Noting" -Because "Verbose should reflect current state"

        #set expected input to make cmdlet stop waiting
        @{ProvisioningState = $expected}|convertto-json|out-file $ControlJson

        #wait for internal loop to switch. maximum $timeout
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        while ($job.State -eq "Running" -and $stopwatch.ElapsedMilliseconds -lt $timeout) {
            Start-Sleep -Milliseconds 100
        }
        Start-Sleep -Milliseconds 100
        $job.state -eq "Completed"|should -Be $shouldBe

        $job|stop-job
    }
}