<#
.SYNOPSIS
Tests if a release trigger should be run

.DESCRIPTION
Picking from a list of rules, this function will test if a release trigger should be run

.PARAMETER LocalTemplate
Path to the local template

.PARAMETER RemoteTemplate
Path to the remote template

.PARAMETER Name
Name of the test

.PARAMETER Rules
List of rules to test

.EXAMPLE
$LocalTemplate = Get-Item -Path "C:\Users\user\Documents\GitHub\azure-bicep\src\azuredeploy.json"
$RemoteTemplate = Get-Item -Path "C:\Users\user\Documents\GitHub\azure-bicep\src\azuredeploy_download.json"
Test-BoltReleaseTrigger -LocalTemplate $LocalTemplate -RemoteTemplate $RemoteTemplate -Name "Test" -Rules @("paramAddedWithoutDefaultValue")
#will return a object that contains the test results

.NOTES
Used to find out if a module should be released. Not for testing the module itself (pester could be a better option for that)
#>
function Test-BoltReleaseTrigger {
    [CmdletBinding()]
    [OutputType([ModuleUpdateTest])]
    param (
        [System.IO.FileInfo]$LocalTemplate,
        [System.IO.FileInfo]$RemoteTemplate,
        [string]$Name,
        [string[]]$Rules
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
        $testparam = @{
            LocalObject    = $LocalObject
            RemoteObject   = $RemoteObject
            LocalTemplate  = $LocalTemplate
            RemoteTemplate = $RemoteTemplate
            # Rules = $Rules
        }
        $testcases = @{
            module           = $VersionTest.NewReasonList('module')
            parameter        = $VersionTest.NewReasonList('parameter')
            resources        = $VersionTest.NewReasonList('resources')
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

        $testparam.LocalObject = Get-Content $LocalTemplate.FullName -Raw | ConvertFrom-Json -AsHashtable
        $testparam.RemoteObject = Get-Content $RemoteTemplate.FullName -Raw | ConvertFrom-Json -AsHashtable
        Write-BoltLog "$($Rules.Count) rules to test" -level 'verbose'
        # New-BoltLogContext -subContext 'releasetrigger'
        switch -wildcard ($Rules) {
            "param*"{
                Test-BoltTriggerOnParam @testparam -rule $_ |ForEach-Object{
                    $testcases.parameter.Add($_)
                }
            }
            "resource*"{
                Test-BoltTriggerOnResource @testparam -rule $_ |ForEach-Object{
                    $testcases.resources.Add($_)
                }
            }
            "moduleModified" {
                Test-BoltmoduleModified @testparam | ForEach-Object {
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