using namespace system.io
function Get-ScriptFiles {
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo])]
    param (
        [DirectoryInfo]$Directory,
        [ValidateSet(
            "scripts",
            "tests",
            "scripts and tests",
            "any"
        )]
        [string]$Kind
    )
    
    switch ($Kind) {
        "scripts" {
            return Get-ChildItem $Directory -Recurse -File -Filter "*.ps1" -Exclude "*.tests.ps1"
        }
        "tests" {
            return Get-ChildItem $Directory -Recurse -File -Filter "*.tests.ps1"
        }
        "scripts and tests" {
            return Get-ChildItem $Directory -Recurse -File -Filter "*.ps1"
        }
        "any" {
            return Get-ChildItem $Directory -Recurse -File
        }
    }
}

class ScriptRegion {
    [int]$start
    [int]$end
}
function Get-ScriptRegions {
    [CmdletBinding()]
    [Outputtype([ScriptRegion])]
    param (
        [parameter(
            Mandatory = $true
        )]
        [string]$ScriptContent,
        [string]$RegionName
    )

    New-Variable astTokens -force
    New-Variable astErr -force
    
    [System.Management.Automation.Language.Parser]::ParseInput($ScriptContent, [ref]$astTokens, [ref]$astErr) | out-null
    $insideRegion = $false
    foreach ($token in $astTokens | Where-Object { $_.kind -eq 'comment' }) {
        $comment = $token.text
        # Write-Host  $comment
        if (!$insideRegion -and $comment -match "region\s+$RegionName") {
            # Write-host $($_|convertto-json -Depth 1 -Compress)
            $region = [ScriptRegion]::new()
            $region.start = $token.Extent.StartLineNumber
            $insideRegion = $true
        }if ($insideRegion -and $comment -like "*#endregion*") {
            $region.end = $token.Extent.EndLineNumber
            Write-Verbose "Found region $regionname`: $($region.start) - $($region.end)"
            Write-Output $region
            $insideRegion = $false
        }
    }
    # Write-Host "found $($script:RemoveOnBuildRegions.count) remove_on_build regions : $($script:RemoveOnBuildRegions|ConvertTo-Json -Depth 10 -compress))"
}

function New-JsonFromSchema {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Schema,
        [Parameter(Mandatory)]
        [string]$OutputPath,
        [ValidateSet(
            "minimal",
            "all"
        )]
        [string]$Size,
        [string]$ReferenceSchemaPath
    )
    $schemaContent = Get-Content $Schema -Raw
    $schemaObject = ConvertFrom-Json $schemaContent -AsHashtable
    Write-Host "Generating schema from '$Schema', size: $Size, output: '$OutputPath'"
    $OutObject = ($schemaObject | Convert-SchemaObjectToObject -Size $size)
    if ($ReferenceSchemaPath) {
        $OutObject.'$schema' = $ReferenceSchemaPath
    }
    # return $return
    $OutObject | ConvertTo-Json -Depth 10 | Out-File $OutputPath -Encoding utf8
}

function Convert-SchemaObjectToObject {
    [CmdletBinding()]
    param (
        [parameter(
            ValueFromPipeline,
            Mandatory
        )]
        $obj,
        [ValidateSet(
            "minimal",
            "all"
        )]
        [string]$Size,
        [string]$address = "#"
    )
    
    begin {
    }
    
    process {
        if ([string]::IsNullOrEmpty($obj.type)) {
            throw "property 'type' is required"
        }
        Write-Verbose "$address, type: $($obj.type)"
        switch ($obj.type) {
            "object" {
                $countProperties = $obj.properties.count
                $countrequired = $obj.required.count
                $hasdefault = $null -ne $obj.default
                Write-Verbose "--> properties: $countProperties, required: $countrequired, has default: $hasdefault "

                $out = @{}
                if ($null -ne $obj.default) {
                    $out = $obj.default
                } elseif ($null -ne $obj.properties) {
                    # Write-Verbose ($obj.properties.keys -join ", ")
                    foreach ($property in $obj.properties.getEnumerator()) {
                        $thisAddress = (@("$address", "$($property.key)") -join ".")
                        Write-verbose "! calling $thisAddress"
                        $val = $property.value | Convert-SchemaObjectToObject -Size $Size -address $thisAddress
                        
                        #fix for array returns.. empty array return = null?  what the actual fuck..
                        if ($null -eq $val -and $property.value.type -eq 'array') {
                            Write-Verbose "Arr workaround"
                            $val = @()
                        }
                        $out.$($property.key) = $val
                        Write-Verbose "! $thisAddress = $( $val.gettype())"
                    }
                } else {
                    $out = @{}
                }

                if ($obj.required) {
                    $required_err = $false
                    @($obj.required) | % {
                        if ($null -eq $out.$_) {
                            $required_err = $true
                            Write-warning "$address`: required property $_ is missing"
                        }
                    }
                    if ($required_err) {
                        throw "required properties are missing. check warning"
                    }
                }
                if ($Size -eq 'minimal') {
                    #avoiding having keys set at a linked item to hashtable
                    $outKeys = $out.keys | ? { "$_" }

                    foreach ($key in $outKeys) {
                        if ($key -notin @($obj.required)) {
                            $out.Remove($key)
                        }
                    }
                }

                return $out
            }
            "array" {
                $hasItems = $null -ne $obj.items
                $hasdefault = $null -ne $obj.default
                Write-Verbose "--> items: $hasItems, has default: $hasdefault"
                $out = @()
                if ($null -ne $obj.default) {
                    $out = $obj.default
                } else {
                    if ($obj.items -is [array]) {
                        for ($i = 0; $i -lt $_.items.Count; $i++) {
                            $thisAddress = (@("$address", "$i") -join ".")
                            $out += @($obj.items[$i] | Convert-SchemaObjectToObject -Size $Size -address $thisAddress)
                        }
                    } elseif ($obj.items -is [hashtable]) {
                        $out += @($obj.items | Convert-SchemaObjectToObject -Size $Size -address $thisAddress)
                    } else {
                        $out += @()
                    }
                }
                # Write-Verbose "type: $($out.gettype())"
                return @($out)
            }
            "string" {
                $hasdefault = $null -ne $obj.default
                $hasenum = $null -ne $obj.enum
                Write-Verbose "--> has default: $hasdefault, has enum: $hasenum"
                if ($null -ne $obj.default) {
                    return $obj.default
                } else {
                    if ($_.enum) {
                        return $_.enum[0]
                    }
                    
                    return ""
                }
            }
            "boolean" {
                $hasdefault = $null -ne $obj.default
                Write-Verbose "--> has default: $hasdefault"
                if ($null -ne $obj.default) {
                    return $obj.default
                } else {
                    return $false
                }
            }
            { $_ -in @("integer", "number") } {
                $hasdefault = $null -ne $obj.default
                Write-Verbose "--> has default: $hasdefault"
                if ($null -ne $obj.default) {
                    return $obj.default
                } else {
                    return 0
                }
            }
            default {
                Write-Warning "Unknown type '$($_.type)'"
                $hasdefault = $null -ne $obj.default
                Write-Verbose "--> has default: $hasdefault"
                if ($null -ne $obj.default) {
                    return $obj.default
                } else {
                    return $null
                }
            }
        }
    }
    end {}
}


function Join-Url {
    [CmdletBinding()]
    param (
        [string]$Parent,
        [string]$Child
    )
    
    begin {
        
    }
    
    process {
        if ($parent -like "*/") {
            $parent.Substring(0, $parent.Length - 1)
        }

        if ($child -like "*/") {
            $child.Substring(1, $child.Length - 1)
        }
    }
    
    end {
        
    }
}


function New-JsonSchemaDoc {
    [CmdletBinding()]
    param (
        [parameter(
            ParameterSetName = 'SchemaFile',
            Mandatory = $true
        )]
        [FileInfo]$Schema,

        [parameter(
            ParameterSetName = 'SchemaItem'
        )]
        [NJsonSchema.JsonSchema]$SchemaItem,

        [parameter(
            ParameterSetName = 'SchemaFile'
        )]
        [string]$Title,

        [parameter(
            ParameterSetName = 'SchemaItem',
            Mandatory = $true
        )]
        [String]$Address = "",

        [parameter(
            ParameterSetName = 'SchemaFile'
        )]
        [Fileinfo]$OutFile,

        [parameter(
            ParameterSetName = 'SchemaItem'
        )]
        [int]$TitleLevel = 1
    )
    begin {
        if ($PSCmdlet.ParameterSetName -eq 'SchemaFile') {
            $Import = [NJsonSchema.JsonSchema]::FromFileAsync($Schema.FullName)
            $SchemaItem = $Import.Result
            if (!$Title) {
                $Title = $Schema.basename
            }
            if (!$OutFile) {
                $OutFile = join-path $Schema.Directory "$($Schema.basename).md"
            }
        }
    }
    process {
        if($title)
        {
            Write-Verbose "Processing Title: $Title"
        }
        else{
            $title = $Address
            Write-Verbose "Processing address: $Address, type: $($SchemaItem.Type)"
        }

        $Markdown = @(
            ('#' * $TitleLevel) + " " + $Title
            ""
            "type: ``{0}``  " -f $SchemaItem.Type
        )
        if ($SchemaItem.Description) {
            $Markdown += $SchemaItem.Description + "  "
        }

        switch ($SchemaItem.Type) {
            { "object", "array" -eq $_ } {
                # Write-Verbose "Processing '$address', Type: $_"
                $Typ = $_ -eq "object"? "Properties" : "Accepted Values"
                $Markdown += ""
                $Markdown += "**$Typ**", ""
                $Table = @()
                $enumerator = @()
                if($_ -eq "object"){
                    $enumerator = $SchemaItem.Properties.GetEnumerator()
                }
                elseif($_ -eq "array" -and $SchemaItem.item){
                    $coll = [System.Collections.Generic.Dictionary[string,NJsonSchema.JsonSchema]]::new() #ICollection[NJsonSchema.JsonSchema]]::new(1)
                    $coll.Add("item", $SchemaItem.item)
                    $enumerator= $coll.GetEnumerator()
                }
                elseif($_ -eq "array")
                {
                    $coll = [System.Collections.Generic.Dictionary[string,NJsonSchema.JsonSchema]]::new() #ICollection[NJsonSchema.JsonSchema]]::new(1)
                    # $coll.Add("item", $SchemaItem.item)
                    $SchemaItem.items.ForEach{
                        $coll.Add("item", $_)
                    }
                    $enumerator= $coll.GetEnumerator()
                }

                foreach ($Item in $enumerator) {
                    $val = $item.value.ActualSchema
                    $ItemName = $null -eq $val.name ? $item.Key : $val.name
                    $ThisAddress = ($Address, $ItemName | ? { $_ }) -join "."
                    $Limitations = @{
                        pattern = $val.pattern
                        minimum = $val.minimum
                        maximum = $val.maximum
                        minLength = $val.minLength
                        maxLength = $val.maxLength
                        minItems = $val.minItems
                        maxItems = $val.maxItems
                        minProperties = $val.minProperties
                        maxProperties = $val.maxProperties
                        enum = ($val.Enumeration -join ", ")
                        format = $val.format
                    }.GetEnumerator() | Where-Object { $_.value } | ForEach-Object { "$($_.key): ``$($_.value)``" }
                    # $LimitationMap
                    if(!$val.Type)
                    {
                        Throw "Type is missing for $ThisAddress"
                    }
                    $Table += @{
                        Name        = $ItemName
                        Required    = $val.IsRequired? "Yes" : "No"
                        Type        = $val.type
                        Description = $val.description
                        Link        = $val.type -in @("object", "array")? "[Link](#$ThisAddress)" : ""
                        Limitation  = $Limitations -join "<br />"
                        _SchemaItem = $val
                        _Address = $ThisAddress
                    }
                }

                $Markdown += "| Name |Required| Type | Description |Link |Limitation|"
                $Markdown += "|--|--|--|--|--|--|"
                $Table | ForEach-Object {
                    $Markdown += "| $($_.Name) | $($_.Required) | $($_.Type) | $($_.Description) | $($_.Link) | $($_.Limitation) |"
                }
                if($SchemaItem.ExtensionData.examples){
                    $Markdown += "**Example**", ""
                    $Markdown += "``````json"
                    $Markdown += $SchemaItem.ExtensionData.examples|ConvertTo-Json -Depth 10
                    $Markdown += "``````", ""
                }
                $Markdown += "","-----",""
                
                $Table|?{$_.type -in @("object", "array")} | ForEach-Object {
                    Write-Verbose "Calling $($_.name)"
                    $Markdown += New-JsonSchemaDoc -SchemaItem $_._SchemaItem -Address $_._Address -TitleLevel ($TitleLevel + 1)
                }
                
            }
            default {
                Write-Verbose "ignore $($address), type $_"
                Write-Verbose ($SchemaItem|ConvertTo-Json -Depth 10 -Compress)
            }
        }
    }
    end {
        if($PSCmdlet.ParameterSetName -eq 'SchemaFile')
        {
            $Markdown += "","-----",""
            $Markdown += "This markdown was automactially generated from the schema file. it may not be 100% correct. please "
            $Markdown|out-file $OutFile -Encoding utf8 -Force
        }
        else{
            $Markdown
        }
    }
}



# New-JsonFromSchema -Schema 'C:\git\nim\bicep-toolbox\badu\schema\deployconfig.schema.json' -OutputPath 'C:\git\nim\bicep-toolbox\badu\starterpack\deployconfig.json' -Size minimal -Verbose -ReferenceSchemaPath './deployconfig.schema.json'