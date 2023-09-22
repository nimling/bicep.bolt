function Test-BicepShouldBuild {
    [CmdletBinding()]
    param (
        [parameter(Mandatory)]
        [system.io.fileinfo]$BicepFile,
        [system.io.fileinfo]$HashFile,
        [system.io.fileinfo]$ArmTemplateFile
    )
    
    begin {}
    
    process {
        if(!$HashFile.Exists)
        {
            Write-BoltLog "Reason: No hash file found. assuming convert havent happened yet" -level verbose
            return $true
        }

        if(!$ArmTemplateFile.Exists)
        {
            Write-BoltLog "Reason: No arm template found" -level verbose
            return $true
        }
        
        $ExistingHash = Get-Content $HashFile.FullName|ConvertFrom-Json
        
        if([string]::IsNullOrEmpty($ExistingHash.bicep))
        {
            Write-BoltLog "Reason: No digest hash of prevoius bicep build found" -level verbose
            return $true
        }

        $BicepHash = New-DigestHash -Item $BicepFile -Algorithm sha256
        if($BicepHash -eq $ExistingHash.bicep)
        {
            Write-BoltLog "Reason: Bicep file has changed" -level verbose
            return $true
        }

        return $false
    }
    
    end {
        
    }
}