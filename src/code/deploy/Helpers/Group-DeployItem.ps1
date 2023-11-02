using namespace System.Collections.Generic
using namespace System.IO
<#
.SYNOPSIS
Groups inputitems in a folder by sort

.DESCRIPTION
Groups items in a folder by sort. This is defined by setting a sort file in same directory as items.
if no file is found, the default sort is used and all items would be grouped in a bucket called '...'
if file is found and any sorting is defined, each line would create its own bucket, and any items that wildcard match the line would be added to that bucket.
you should end up with a dictionary of buckets, where each bucket contains a list of items that match the bucket name.

the output of this sort can be used to determine the order of deployment of items.
foreach $item in $output.keys {
    foreach file in $output[$item] {
        #deploy file
    }
}
.EXAMPLE
for sorting without sort-file, if files is:
* item1.txt
* item2.txt
* item3.txt

gci -Recurse -File | Group-DeployItems

#output:
@{
    '...' = @(item1, item2, item3)
}

.EXAMPLE
for sorting with sort-file, if files is:
* item1.txt
* item2.txt
* item3.txt

and sort file is:
item3*

gci -Recurse -File | Group-DeployItems

#output:
@{
    'item3*' = @(item3)
    '...' = @(item1, item2)
}
.NOTES
General notes
#>
function Group-DeployItem {
    [CmdletBinding()]
    [OutputType([Dictionary[string, List[FileSystemInfo]]])]
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
        $map = [Dictionary[string, List[FileSystemInfo]]]::new()
        $parent = ""
        $deploysort = @()
        $deploysort_filename = "sort"
    }
    
    process {
        #concatonate so i dont have to process several variables
        $item = @($inputFolder, $InputFile) | Where-Object { $_ }

        $parentDir = [System.IO.Path]::GetDirectoryName($item.FullName)
        
        #init map if not already done
        if ($map.count -eq 0) {
            #get sorting file based on current item parent folder, else generate default '...'
            $deploysort_path = (join-path $parentDir $deploysort_filename)
            
            if (test-path $deploysort_path) {
                Write-BaduVerb "$($PSCmdlet.ParameterSetName) sort-file: $deploysort_path`: $($map.Keys -join ', ')"
                $deploysort = @(get-content $deploysort_path)
            } else {
                $deploysort += '...'
            }

            #create buckets from deploysort
            $deploysort | ForEach-Object {
                $map.Add($_, [List[FileSystemInfo]]::new())
            }
        }

        #'...' needs to be processed last as its the "the rest of the items" bucket
        $ItemAdded = $false
        foreach ($key in $map.Keys | Where-Object { $_ -ne '...' }) {
            if ($item.basename -like $key) {
                Write-BaduDebug "Added $($item.name) to bucket '$key'"
                $map.$key += $item

                #stop processing current item.
                #even if all items are returned, end will still be called
                $ItemAdded = $true
                return
            }
        }

        Write-BaduDebug "Added $($item.name) to bucket '...'"
        $map.'...' += $item
        # if (!$itemadded) {
        # }

    }
    end {
        return $map
    }
}