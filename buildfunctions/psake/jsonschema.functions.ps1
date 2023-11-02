using namespace System.IO

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
            ParameterSetName = 'SchemaItem'
        )]
        [ValidateNotNullOrEmpty()]
        [String]$Address,

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
            if (!$Title -and $SchemaItem.Title) {
                $Title = $SchemaItem.Title
            } else {
                $Title = $Schema.basename
            }
            if (!$OutFile) {
                $OutFile = join-path $Schema.Directory "$($Schema.basename).md"
            }
            Write-Verbose "Outfile: $OutFile"
        }
    }
    process {
        $SchemaType = $SchemaItem | Get-JsonSchemaType
        if ($title) {
            Write-Verbose "Processing Title: $Title"
        } else {
            $title = $Address
            Write-Verbose "Processing address: $Address, type: $SchemaType"
        }

        $markdown = @()
        if ($SchemaType -in 'object', 'array') {

            $Markdown += $title | New-MarkdownPart -TitlePart -Level $TitleLevel 

            $Markdown += New-MarkdownPart -KeyValPart -Value $SchemaType -format Code -Key 'type'
        }

        if ($SchemaItem.Description) {
            $Markdown += $SchemaItem.Description | New-MarkdownPart -TextPart
        }
        
        
        Write-Verbose "'$address' is type $SchemaType"
        if ($SchemaType -eq "Object") {
            if ($SchemaItem.MaxProperties) {
                $Markdown += $SchemaItem.MaxProperties | New-MarkdownPart -KeyValPart -Key 'Max Properties' -format Code
            }

            if ($SchemaItem.MinProperties) {
                $Markdown += $SchemaItem.MinProperties | New-MarkdownPart -KeyValPart -Key 'Min Properties' -format Code
            }
            if ($SchemaItem.ActualProperties) {

                $Markdown += "Properties" | New-MarkdownPart -TextPart -Format Bold

                $markdown += New-MarkdownPart -TablePart -Value @("Name", "Required", "Type", "Description", "Link", "Limitation") -TableRowsDefinition {
                    foreach ($property in $SchemaItem.ActualProperties.GetEnumerator()) {
                        $val = $property.value.ActualObject
                        $linkVal = (@($address, $property.Key) | ? { $_ } | % { $_.tolower() }) -join ""
                        @{
                            Name        = $property.Key
                            Required    = if ($true -in $property.Value.IsRequired, $val.IsRequired) { "Yes" }else { "No" }
                            Type        = '`' + $val.Type + '`' 
                            Description = if ($property.value.Description) { $property.value.Description } else { $val.Description }
                            Link        = if ($val.Type -in @("object", "array")) { "[Link](#$linkVal)" }else { "" }
                            Limitation  = @(Get-JsonSchemaPropertyLimitations -SchemaItem $val) -join "<br />"
                        }
                    }
                }

                $SchemaItem.ActualProperties.Values | ? { ($_ | Get-JsonSchemaType) -in @("object", "array") } | ForEach-Object {
                    Write-Verbose "Calling $($_.name)"
                    $addr = (@($address, $_.name) | ? { $_ }) -join "."
                    $Markdown += New-JsonSchemaDoc -SchemaItem $_.ActualObject -Address $addr -TitleLevel ($TitleLevel + 1)
                }
            }
            
        } elseif ($SchemaType -eq "Array") {
            $items = @()
            if ($SchemaItem.MaxItems) {
                $Markdown += $SchemaItem.MaxItems | New-MarkdownPart -KeyValPart -Key 'Max Items' -format Code
            }

            if ($SchemaItem.MinItems) {
                $Markdown += $SchemaItem.MinItems | New-MarkdownPart -KeyValPart -Key 'Min Items' -format Code
            }

            if ($SchemaItem.Item) {
                $items += $SchemaItem.Item
            }
            elseif($SchemaItem.Items){
                $items += $SchemaItem.Items
            }


            foreach ($ArrayItem in $SchemaItem.Item, $SchemaItem.items | ? { $_ }) {
                $anyofReturn = $ArrayItem | Get-AnyOfMarkdown 
                if ($anyofReturn) {
                    $Markdown += $anyofReturn.markdown
                    $items += $anyofReturn.items
                    Continue
                }
                else{
                    $items += $ArrayItem
                }
            }

            

        } else {
            Write-Verbose "ignore '$($address)', type $SchemaType"
        }
        # if($SchemaItem.Type -in "object", "array" ){
        #     $Typ = if ($_ -eq "object") { "Properties" } else { "Accepted Values" }
        #     $Markdown += ""
        #     $Markdown += "**$Typ**", ""
        #     $Table = @()
        #     $enumerator = @()
        #     if ($_ -eq "object") {
        #         $enumerator = $SchemaItem.Properties.GetEnumerator()
        #     } elseif ($_ -eq "array" -and $SchemaItem.item) {
        #         $coll = [System.Collections.Generic.Dictionary[string, NJsonSchema.JsonSchema]]::new() #ICollection[NJsonSchema.JsonSchema]]::new(1)
        #         $coll.Add("item", $SchemaItem.item)
        #         $enumerator = $coll.GetEnumerator()
        #     } elseif ($_ -eq "array") {
        #         $coll = [System.Collections.Generic.Dictionary[string, NJsonSchema.JsonSchema]]::new() #ICollection[NJsonSchema.JsonSchema]]::new(1)
        #         # $coll.Add("item", $SchemaItem.item)
        #         $SchemaItem.items.ForEach{
        #             $coll.Add("item", $_)
        #         }
        #         $enumerator = $coll.GetEnumerator()
        #     }
    
        #     foreach ($Item in $enumerator) {
        #         $val = $item.value.ActualSchema
        #         $ItemName = if($null -eq $val.name){$item.Key}else{$val.name}
        #         $ThisAddress = ($Address, $ItemName | ? { $_ }) -join "."
        #         $Limitations = @{
        #             pattern       = $val.pattern
        #             minimum       = $val.minimum
        #             maximum       = $val.maximum
        #             minLength     = $val.minLength
        #             maxLength     = $val.maxLength
        #             minItems      = $val.minItems
        #             maxItems      = $val.maxItems
        #             minProperties = $val.minProperties
        #             maxProperties = $val.maxProperties
        #             enum          = ($val.Enumeration -join ", ")
        #             format        = $val.format
        #         }.GetEnumerator() | Where-Object { $_.value } | ForEach-Object { "$($_.key): ``$($_.value)``" }
        #         # $LimitationMap
        #         if (!$val.Type) {
        #             Throw "Type is missing for $ThisAddress"
        #         }
        #         $Table += @{
        #             Name        = $ItemName
        #             Required    = if($val.IsRequired){"Yes"}else{"No"}
        #             Type        = $val.type
        #             Description = $val.description
        #             Link        = if($val.type -in @("object", "array")){"[Link](#$ThisAddress)"}else{""}
        #             Limitation  = $Limitations -join "<br />"
        #             _SchemaItem = $val
        #             _Address    = $ThisAddress
        #         }
        #     }
    
        #     $Markdown += "| Name |Required| Type | Description |Link |Limitation|"
        #     $Markdown += "|--|--|--|--|--|--|"
        #     $Table | ForEach-Object {
        #         $Markdown += "| $($_.Name) | $($_.Required) | $($_.Type) | $($_.Description) | $($_.Link) | $($_.Limitation) |"
        #     }
        #     if ($SchemaItem.ExtensionData.examples) {
        #         $Markdown += "**Example**", ""
        #         $Markdown += "``````json"
        #         $Markdown += $SchemaItem.ExtensionData.examples | ConvertTo-Json -Depth 10
        #         $Markdown += "``````", ""
        #     }
        #     $Markdown += "", "-----", ""
            
        #     $Table | ? { $_.type -in @("object", "array") } | ForEach-Object {
        #         Write-Verbose "Calling $($_.name)"
        #         $Markdown += New-JsonSchemaDoc -SchemaItem $_._SchemaItem -Address $_._Address -TitleLevel ($TitleLevel + 1)
        #     }
        # }
        # elseif($SchemaItem.type -eq 'none'){
        #     $addr = if($Address -eq ''){"root"}else{$Address}
        #     throw "Type is none for $addr"
        # }
        # else{
        #     Write-Verbose "ignore '$($address)', type $_"
        # }
    }
    end {
        if ($PSCmdlet.ParameterSetName -eq 'SchemaFile') {
            $Markdown += @{
                Type = "Line"
            }
            $Markdown += @{
                Type  = "Text"
                Value = "This markdown was automactially generated from the schema file. it may not be 100% correct. please file an issue if you find a problem."
            }

            Write-Verbose "Generating markdown for '$OutFile'"
            $OutMarkdown = $markdown | Build-MarkdownDocument
        
            Write-Verbose "Writing to '$OutFile'"
            # $OutMarkdown += "", "-----", ""
            # $Markdown += "This markdown was automactially generated from the schema file. it may not be 100% correct. please "
            $OutMarkdown | out-file $OutFile -Encoding utf8 -Force
        } else {
            $Markdown
        }
    }
}

function Build-MarkdownDocument {
    [CmdletBinding()]
    param (
        [parameter(
            ValueFromPipeline
        )]
        [array]$MarkdownParts
    )
    process {
        $MarkdownParts | ForEach-Object {
            $part = $_
            # Write-verbose ($_.type + "->" + ($_ | ConvertTo-Json))
            switch ($part.Type) {
                "Title" {
                    Write-Output ""
                    Write-Output (("#" * $part.Level) + " $($part.Value)")
                    Write-Output ""
                }
                "Text" {
                    Write-Output (($part.format -f $part.value) + "  ")
                }
                "KeyVal" {
                    Write-Output "$($part.Key): $($part.format -f $part.Value)  "
                }
                "Table" {
                    Write-Output ""
                    Write-Output ($part.Headers -join " | ")
                    Write-Output ($part.Headers.ForEach({ "---" }) -join " | ")
                    $part.Rows | ForEach-Object {
                        $row = $_

                        #return data where it can find the key, otherwise return empty string
                        $LineParts = $part.Headers | % {
                            if ($row.containskey($_)) {
                                $row.$_
                            } else {
                                ""
                            }
                        }

                        #write the row of table
                        Write-Output ($LineParts -join " |")
                    }
                }
                "Line" {
                    $OutMarkdown += "-----"
                }
            }
        }
    }
}

function Get-AnyOfMarkdown {
    [CmdletBinding()]
    param (
        #the item that contains the anyof, allof, or oneof
        [parameter(
            ValueFromPipeline
        )]
        [NJsonSchema.JsonSchema]$ParentOfAnyOf
    )
    process {
        $return = @{
            items    = @()
            markdown = @()
        }
        if ($ParentOfAnyOf.anyof) {
            $ParentOfAnyOf.anyof | % {
                $return.items += $_
            }
            Write-Verbose "Writing info for AnyOf"
            $return.markdown += "can be any of the following types:" | New-MarkdownPart -TextPart -Format Bold
        } elseif ($_.allof) {
            $ParentOfAnyOf.allof | % {
                $return.items += $_
            }
            Write-Verbose "Writing info for AllOf"
            $return.markdown += "must be all of the following types:" | New-MarkdownPart -TextPart -Format Bold
        } elseif ($_.oneof) {
            $ParentOfAnyOf.oneof | % {
                $return.items += $_
            }
            Write-Verbose "Writing info for OneOf"
            $return.markdown += "must be one of the following types:" | New-MarkdownPart -TextPart -Format Bold
        }

        if (!$return.items) {
            return
        } else {
            $return.Markdown += New-MarkdownPart -EmptyLinePart
            $return.Markdown += New-MarkdownPart -TablePart -Value @("Name", "Type", "Description", "Link") -TableRowsDefinition {
                foreach ($item in $return.items) {
                    $val = $item.ActualObject
                    $name = $item | Get-JsonSchemaItemName
                    $linkVal = (@($address, "item") | ? { $_ } | % { $_.tolower() }) -join ""
                    @{
                        Name        = $name
                        Type        = '`' + $val.Type + '`' 
                        Description = if ($_.Description) { $_.Description } else { $val.Description }
                        Link        = if ($val.Type -in @("object", "array")) { "[Link](#$linkVal)" }else { "" }
                    }
                }
            }
        }
        return $return
    }
}
function Get-JsonSchemaItemName {
    [CmdletBinding()]
    param (
        [parameter(
            ValueFromPipeline
        )]
        [NJsonSchema.JsonSchema]$SchemaItem
    )
    process {
        if ($SchemaItem.name) {
            return $SchemaItem.name
        }
        if ($SchemaItem.HasReference) {
            $parent = $SchemaItem.Reference.parent
            if ($parent.Definitions) {
                return $parent.Definitions.Keys | ? { $parent.Definitions.$_.GetHashCode() -eq $SchemaItem.Reference.GetHashCode() } | ForEach-Object { return $_ } | select -first 1
            }
        }
        throw "Unable to determine name for $($SchemaItem|ConvertTo-Json -Depth 1)"
    }
}

function New-MarkdownPart {
    [CmdletBinding()]
    param (
        [parameter(
            ParameterSetName = "Title"
        )]
        [switch]$TitlePart,

        [parameter(
            ParameterSetName = "Text"
        )]
        [switch]$TextPart,

        [parameter(
            ParameterSetName = "Keyval"
        )]
        [switch]$KeyValPart,

        [parameter(
            ParameterSetName = "Table"
        )]
        [switch]$TablePart,

        [parameter(
            ParameterSetName = "Line"
        )]
        [switch]$LinePart,
        
        [parameter(
            ParameterSetName = "EmptyLine"
        )]
        [switch]$EmptyLinePart,

        [parameter(
            ValueFromPipeline
        )]
        $Value,

        [parameter(
            ParameterSetName = "Keyval"
        )]
        [string]$Key,

        [parameter(
            ParameterSetName = "Keyval"
        )]
        [parameter(
            ParameterSetName = "Text"
        )]
        [ValidateSet("Bold", "Italic", "Underline", "Code")]
        [string]$Format,

        [parameter(
            ParameterSetName = "Title"
        )]
        [int]$Level = 1,

        [parameter(
            ParameterSetName = "Table"
        )]
        [scriptblock]$TableRowsDefinition
    )
    
    begin {
        
    }
    
    process {

        $fmt = switch ($Format) {
            "Bold" {
                "**{0}**"
            }
            "Italic" {
                "*{0}*"
            }
            "Underline" {
                "__{0}__"
            }
            "Code" {
                '`{0}`'
            }
            default {
                "{0}"
            }
        }

        switch ($PSCmdlet.ParameterSetName) {
            "EmptyLine" {
                return (New-MarkdownPart -TextPart -Value "")
            }
            "Title" {
                return @{
                    Type  = $PSCmdlet.ParameterSetName
                    Value = $Value.tostring()
                    Level = $Level
                }
            }
            "KeyVal" {
                return @{
                    Type   = $PSCmdlet.ParameterSetName
                    Key    = $Key
                    Value  = $Value
                    Format = $fmt
                }
            }
            "Text" {
                return @{
                    Type   = $PSCmdlet.ParameterSetName
                    Value  = $Value
                    Format = $fmt
                }
            }
            "Table" {
                return @{
                    Type    = $PSCmdlet.ParameterSetName
                    Headers = @($Value)
                    Rows    = & $TableRowsDefinition
                }
            }
            default {
                Throw "type $_ is not handled yet"
            }
        }
    }
    end {}
}

function Get-JsonSchemaPropertyLimitations {
    [CmdletBinding()]
    param (
        [parameter(
            ValueFromPipeline
        )]
        [NJsonSchema.JsonSchema]$SchemaItem
    )
    
    begin {
        
    }
    
    process {
        $return = @{
            pattern       = $SchemaItem.pattern
            minimum       = $SchemaItem.minimum
            maximum       = $SchemaItem.maximum
            minLength     = $SchemaItem.minLength
            maxLength     = $SchemaItem.maxLength
            minItems      = $SchemaItem.minItems
            maxItems      = $SchemaItem.maxItems
            minProperties = $SchemaItem.minProperties
            maxProperties = $SchemaItem.maxProperties
            enum          = $SchemaItem.Enumeration
            format        = $SchemaItem.format
        }
        $return.GetEnumerator() | Where-Object { $_.value } | ForEach-Object { "$($_.key): $($_.value|%{'`'+$_+'`'})" }
    }
    
    end {
        
    }
}
function Get-JsonSchemaType {
    [CmdletBinding()]
    param (
        [parameter(
            ValueFromPipeline
        )]
        [NJsonSchema.JsonSchema]$SchemaItem
    )
    
    process {
        if ($SchemaItem.Type) {
            return $SchemaItem.Type
        }
    
        if ($SchemaItem.ActualProperties) {
            return "object"
        }
    
        if ($SchemaItem.ActualSchema) {
            return Get-JsonSchemaType -SchemaItem $SchemaItem.ActualSchema
        }
    
        if ($SchemaItem.item) {
            return "array"
        }
    
        throw "Unable to determine type for $($SchemaItem|ConvertTo-Json -Depth 1)"
    }
}

$DebugPreference = "Continue"
New-JsonSchemaDoc -Schema 'C:\git\nim\bicep.bolt\src\schema\root.json' -OutFile 'C:\git\nim\bicep.bolt\starterpack\bolt-schema.md' -Verbose