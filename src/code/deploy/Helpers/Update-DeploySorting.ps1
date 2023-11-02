using namespace system.io
using namespace System.Collections.Generic
function Update-DeploySorting {
    [CmdletBinding()]
    param (
        [parameter(
            ValueFromPipeline,
            ParameterSetName = 'file',
            Mandatory
        )]
        [FileInfo]$InputFile,
        [parameter(
            ValueFromPipeline,
            ParameterSetName = 'folder',
            Mandatory
        )]
        [DirectoryInfo]$inputFolder
    )
    begin {
        #could use arraylist, but its only to contian a few items
        $items = @()
    }
    process {
        # $item = @($inputFolder, $InputFile) | Where-Object { $_ }
        # $map = $item
        switch ($PSCmdlet.ParameterSetName) {
            "folder" {
                $items += $inputFolder
            }
            "file" {
                $items += $InputFile
            }
        }
        # #get sorting file based on current item parent folder
        # $deploysort_path = (join-path $parent $deploysort_filename)
        # if (!(test-path $deploysort_path)){
        #     return (@($inputFolder, $InputFile)|Where-Object { $_ })
        # }
        # #get and initate deployorder map from deployorder file (only once)
        # if ($map.count -eq 0) {
        #     if (test-path $deploysort_path) {
        #         $deploysort = @(Get-Content $deploysort_path)
        #     } else {
        #         Write-BaduDebug "Order file not found, creating working object"
        #         $deploysort = @()
        #     }

        #     if ('...' -notin $deploysort) {
        #         $deploysort += '...'
        #     }

        #     foreach ($line in $deploysort) {
        #         $map.$line = @()
        #     }

        #     Write-BaduVerb "$($PSCmdlet.ParameterSetName) sort-file in /$(split-path $parent -leaf): $($map.Keys -join ', ')"
        # }

        # #concatonate so i dont have to process several variables
        # $item = @($inputFolder, $InputFile) | Where-Object { $_ }

        # :itemsearch foreach ($key in $map.Keys | Where-Object { $_ -ne '...' }) {
        #     if ($item.basename -like $key) {
        #         $map.$key += $item
        #         #stop processing current item. even if all items are returned, end will still be called
        #         return
        #     }
        # }

        # $map.'...' += $item

    }
    
    end {
        # if($AsMap){
        #     return $map
        # }
        $map = $items|Group-DeployItem
        $map.GetEnumerator() | ForEach-Object {
            $_.value | ForEach-Object {
                Write-Output $_
            }
        }
    }
}