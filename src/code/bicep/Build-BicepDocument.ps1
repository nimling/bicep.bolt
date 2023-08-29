using namespace Diagnostics.CodeAnalysis
function Build-BicepDocument {
    [CmdletBinding()]
    param (
        [parameter(Mandatory)]
        [System.IO.FileInfo]$File,
        [parameter(Mandatory)]
        [System.IO.FileInfo]$OutputFile,
        [System.IO.FileInfo]$LogFile
    )
    begin {
    }
    process {
        if (!$LogFile) {
            $RandomFileName = "$([System.IO.Path]::GetRandomFileName()).log"
            [System.IO.FileInfo]$LogFile = (join-path $env:TEMP $RandomFileName)
        }
        if($OutputFile.Exists){
            $OutputFile.Delete()
        }
        New-item -Path $LogFile.FullName -ItemType File -Force -WhatIf:$false | Out-Null
        Write-BoltLog " template path $OutputFile" -level verbose
        Write-BoltLog " log path $LogFile" -level verbose
        $cmd = "bicep build '$($file.FullName)' --outfile '$($OutputFile.FullName)' *> $($LogFile.FullName)"#'
        # Write-BoltLog $cmd
        $whatif = $WhatIfPreference
        $whatifpreference = $false

        # [Diagnostics.CodeAnalysis.SuppressMessageAttribute('AvoidUsingInvokeExpression', '', Justification = 'Used for global token hander singleton')]
        [scriptblock]::create($cmd).Invoke() #| Invoke-Expression

        $whatifpreference = $whatif
        # Write-BoltLog "bicep build $($file.FullName) --outfile $($OutputFile.FullName) *>> $($LogFile.FullName)"
        # $ea = $ErrorActionPreference 
        # $ErrorActionPreference = 'SilentlyContinue'
        # bicep build "$($file.FullName)" --outfile $($OutputFile.FullName) |%{
        #     Write-BoltLog $_ -level verbose
        # } # --outfile "$($OutputFile.FullName)" #*> "$($LogFile.FullName)"
        # $ErrorActionPreference = $ea

        if($?){
            Write-BoltLog "bicep build completed successfully" -level verbose
        }
        else{
            Write-BoltLog "bicep build failed" -level verbose
        }
        $ConvertLog = Get-Content $LogFile.FullName
        # $ConvertLog | % {
        #     Write-BoltLog $_ -level info
        # }
        $ConvertLog | Where-Object { $_ -like "*: Warning *" }|ForEach-Object{
            Write-BoltLog $_ -level warning
        }
        $ConvertLog | Where-Object { $_ -like "*: Error *" }|ForEach-Object{
            Write-BoltLog $_ -level error
        }
    }
    
    end {
        
    }
}