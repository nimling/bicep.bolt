function Get-DeploymentFile {
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo])]
    param (
        [parameter(Mandatory)]
        [string]$path
    )
    begin {}
    process {
        $items = Get-ChildItem -Path $path -file|Where-Object{$_.name -like "*.json*" -or $_.name -like "*.bicep"}
        :itemsearch foreach($item in $items){
            if($item.name -like "*.bicep"){
                Write-Output $item
                continue :itemsearch
            }
            if($item.name -like "*.json*"){
                $json = Get-Content -Path $item.FullName -Raw
                # Write-BaduVerb $item.FullName
                $jsonitem = $json|ConvertFrom-Json
                if($jsonitem.'$schema' -like '*schema.management.azure.com*DeploymentTemplate*'){
                    Write-Output $item
                    continue :itemsearch
                }
            }
        }
    }
    end {
    }
}