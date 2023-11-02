function New-DeployConfig {
    [CmdletBinding()]
    param (
        [DirectoryInfo]$WorkingPath,
        [string]$ActiveEnvironment
    )
    
    begin { 
        Set-BaduLogContext -Tag "DeployConfig"
        #region load the config file contents
        $deployconfigFile = Get-ChildItem $WorkingPath.FullName -File -filter 'deployconfig.json?' | Select-Object -first 1
        if (!$deployconfigFile) {
            Write-BaduError "could not find a deployconfig.json/jsonc in '$WorkingPath'"
            throw "could not find a deployconfig.json/jsonc in '$WorkingPath'"
        }

        Write-BaduVerb "Loading deployConfig from '$deployconfigFile'"
        $deployConfigContent = Get-Content $deployconfigFile

        #clean up jsonc file (remove comments)
        if ($deployconfigFile.Extension -eq '.jsonc') {
            Write-BaduDebug "Fixing jsonc file before parsing"
            $deployConfigContent = $deployConfigContent | Where-Object { $_ -notmatch '^\s*//' }
        }
        $deployConfigObject = $deployConfigContent | ConvertFrom-Json  #-Depth 90
        #endregion
    }
    
    process {
        # Write-BaduVerb $deployConfigObject.gettype()
        try{
            $Config = [deployconfig]::new($deployConfigObject,$ActiveEnvironment)
            $config.workingPath = $deployconfigFile.Directory.FullName
        }
        catch{
            Write-BaduError "Failed to create deployConfig object : $_"
            throw $_
        }

        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Used for global config singleton')]
        $Global:deployConfig = $Config
    }
    
    end {
        
    }
}