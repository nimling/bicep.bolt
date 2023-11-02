function ConvertTo-ParamObject {
    param(
        [System.IO.FileInfo]$ParamFile
        # [string]$tab = ""
    )
    begin {
        $return = @{}
        # $deployConfig = Get-DeployConfig
    }
    process {

        $ParamItem = Get-Content -raw $ParamFile | ConvertFrom-Json

        $params = $paramItem.Parameters
        foreach ($parameter in $params.psobject.properties) {
            $ParamName = $parameter.Name
            if ($parameter.Value.value -is [string]) {
                $ParamValue = $parameter.Value.value
                #find replacement if value is a variable reference
                Write-BaduVerb "Handling parameter '$ParamName'"
                $ParamValue = Build-DeployVariable -val $ParamValue
                # $References = Get-VariableReferenceInString -String $ParamValue | select -Unique
                # if($References.count -gt 0) {
                #     Write-BaduVerb "Found $($References.count) variable references in '$ParamName'"
                #     $ParamValue = Build-DeployVariable -VarRefs $References -val $ParamValue
                # }
            }
            elseif(![string]::IsNullOrEmpty($parameter.Value.value))
            {
                $ParamValue = $parameter.Value.value
            }
            else{
                $ParamValue = $parameter.Value
            }
            $return.Add($ParamName, $ParamValue)
        }
    }
    end {
        return $return
    }
}