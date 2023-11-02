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

Function New-PSDynamicParameter {
<#
.Synopsis
Create a PowerShell dynamic parameter
.Description
This command will create the code for a dynamic parameter that you can insert into your PowerShell script file.
.Link
about_Functions_Advanced_Parameters

#>

    [cmdletbinding()]
    [alias("ndp")]
    [outputtype([System.String[]])]
    Param(
        [Parameter(Position = 0, Mandatory, HelpMessage = "Enter the name of your dynamic parameter.`nThis is a required value.")]
        [ValidateNotNullOrEmpty()]
        [alias("Name")]
        [string[]]$ParameterName,
        [Parameter(Mandatory, HelpMessage = "Enter an expression that evaluates to True or False.`nThis is code that will go inside an IF statement.`nIf using variables, wrap this in single quotes.`nYou can also enter a placeholder like '`$True' and edit it later.`nThis is a required value.")]
        [ValidateNotNullOrEmpty()]
        [string]$Condition,
        [Parameter(HelpMessage = "Is this dynamic parameter mandatory?")]
        [switch]$Mandatory,
        [Parameter(HelpMessage = "Enter an optional default value.")]
        [object[]]$DefaultValue,
        [Parameter(HelpMessage = "Enter an optional parameter alias.`nSpecify multiple aliases separated by commas.")]
        [string[]]$Alias,
        [Parameter(HelpMessage = "Enter the parameter value type such as String or Int32.`nUse a value like string[] to indicate an array.")]
        [type]$ParameterType = "string",
        [Parameter(HelpMessage = "Enter an optional help message.")]
        [ValidateNotNullOrEmpty()]
        [string]$HelpMessage,
        [Parameter(HelpMessage = "Does this dynamic parameter take pipeline input by property name?")]
        [switch]$ValueFromPipelineByPropertyName,
        [Parameter(HelpMessage = "Enter an optional parameter set name.")]
        [ValidateNotNullOrEmpty()]
        [string]$ParameterSetName,
        [Parameter(HelpMessage = "Enter an optional comment for your dynamic parameter.`nIt will be inserted into your code as a comment.")]
        [ValidateNotNullOrEmpty()]
        [string]$Comment,
        [Parameter(HelpMessage = "Validate that the parameter is not NULL or empty.")]
        [switch]$ValidateNotNullOrEmpty,
        [Parameter(HelpMessage = "Enter a minimum and maximum string length for this parameter value`nas an array of comma-separated set values.")]
        [ValidateNotNullOrEmpty()]
        [int[]]$ValidateLength,
        [Parameter(HelpMessage = "Enter a set of parameter validations values")]
        [ValidateNotNullOrEmpty()]
        [object[]]$ValidateSet,
        [Parameter(HelpMessage = "Enter a set of parameter range validations values as a`ncomma-separated list from minimum to maximum")]
        [ValidateNotNullOrEmpty()]
        [int[]]$ValidateRange,
        [Parameter(HelpMessage = "Enter a set of parameter count validations values as a`ncomma-separated list from minimum to maximum")]
        [ValidateNotNullOrEmpty()]
        [int[]]$ValidateCount,
        [Parameter(HelpMessage = "Enter a parameter validation regular expression pattern")]
        [ValidateNotNullOrEmpty()]
        [string]$ValidatePattern,
        [Parameter(HelpMessage = "Enter a parameter validation scriptblock.`nIf using the form, enter the scriptblock text.")]
        [ValidateNotNullOrEmpty()]
        [scriptblock]$ValidateScript
    )

    Begin {
        Write-Verbose "[$((Get-Date).TimeofDay) BEGIN  ] Starting $($myinvocation.mycommand)"
        $out = @"
    DynamicParam {
    $(If ($comment) { "$([char]35) $comment"})
        If ($Condition) {

        `$paramDictionary = New-Object -Type System.Management.Automation.RuntimeDefinedParameterDictionary

"@

    } #begin

    Process {
        if (-Not $($PSBoundParameters.ContainsKey("ParameterSetName"))) {
            $PSBoundParameters.Add("ParameterSetName", "__AllParameterSets")
        }

        #get validation tests
        $Validations = $PSBoundParameters.GetEnumerator().Where({ $_.key -match "^Validate" })

        #this is structured for future development where you might need to create
        #multiple dynamic parameters. This feature is incomplete at this time
        Foreach ($Name in $ParameterName) {
            Write-Verbose "[$((Get-Date).TimeofDay) PROCESS] Defining dynamic parameter $Name [$($parametertype.name)]"
            $out += "`n        # Defining parameter attributes`n"
            $out += "        `$attributeCollection = New-Object -Type System.Collections.ObjectModel.Collection[System.Attribute]`n"
            $out += "        `$attributes = New-Object System.Management.Automation.ParameterAttribute`n"
            #add attributes
            $attributeProperties = 'ParameterSetName', 'Mandatory', 'ValueFromPipeline', 'ValueFromPipelineByPropertyName', 'ValueFromRemainingArguments', 'HelpMessage'
            foreach ($item in $attributeProperties) {
                if ($PSBoundParameters.ContainsKey($item)) {
                    Write-Verbose "[$((Get-Date).TimeofDay) PROCESS] Defining $item"
                    if ( $PSBoundParameters[$item] -is [string]) {
                        $value = "'$($PSBoundParameters[$item])'"
                    }
                    else {
                        $value = "`$$($PSBoundParameters[$item])"
                    }

                    $out += "        `$attributes.$item = $value`n"
                }
            }

            #add parameter validations
            if ($validations) {
                Write-Verbose "[$((Get-Date).TimeofDay) PROCESS] Processing validations"
                foreach ($validation in $Validations) {
                    Write-Verbose "[$((Get-Date).TimeofDay) PROCESS] ... $($validation.key)"
                    $out += "`n        # Adding $($validation.key) parameter validation`n"
                    Switch ($Validation.key) {
                        "ValidateNotNullOrEmpty" {
                            $out += "        `$v = New-Object System.Management.Automation.ValidateNotNullOrEmptyAttribute`n"
                            $out += "        `$AttributeCollection.Add(`$v)`n"
                        }
                        "ValidateLength" {
                            $out += "        `$value = @($($Validation.Value[0]),$($Validation.Value[1]))`n"
                            $out += "        `$v = New-Object System.Management.Automation.ValidateLengthAttribute(`$value)`n"
                            $out += "        `$AttributeCollection.Add(`$v)`n"
                        }
                        "ValidateSet" {
                            # $Valida
                            Write-Verbose "validation is $($validation.value[0].gettype())"
                            if($validation.value[0] -is [scriptblock])
                            {
                                $out += '$value = ' + $validation.value[0] + "`n"
                            }
                            else{
                                $join = "'$($Validation.Value -join "','")'"
                                $out += "        `$value = @($join) `n"
                            }
                            $out += "        `$v = New-Object System.Management.Automation.ValidateSetAttribute(`$value)`n"
                            $out += "        `$AttributeCollection.Add(`$v)`n"
                        }
                        "ValidateRange" {
                            $out += "        `$value = @($($Validation.Value[0]),$($Validation.Value[1]))`n"
                            $out += "        `$v = New-Object System.Management.Automation.ValidateRangeAttribute(`$value)`n"
                            $out += "        `$AttributeCollection.Add(`$v)`n"
                        }
                        "ValidatePattern" {
                            $out += "        `$value = '$($Validation.value)'`n"
                            $out += "        `$v = New-Object System.Management.Automation.ValidatePatternAttribute(`$value)`n"
                            $out += "        `$AttributeCollection.Add(`$v)`n"
                        }
                        "ValidateScript" {
                            $out += "        `$value = {$($Validation.value)}`n"
                            $out += "        `$v = New-Object System.Management.Automation.ValidateScriptAttribute(`$value)`n"
                            $out += "        `$AttributeCollection.Add(`$v)`n"
                        }
                        "ValidateCount" {
                            $out += "        `$value = @($($Validation.Value[0]),$($Validation.Value[1]))`n"
                            $out += "        `$v = New-Object System.Management.Automation.ValidateCountAttribute(`$value)`n"
                            $out += "        `$AttributeCollection.Add(`$v)`n"
                        }
                    } #close switch
                } #foreach validation
            } #validations

            $out += "        `$attributeCollection.Add(`$attributes)`n"

            if ($Alias) {
                Write-Verbose "[$((Get-Date).TimeofDay) PROCESS] Adding parameter alias $($alias -join ',')"
                Foreach ($item in $alias) {
                    $out += "`n        # Adding a parameter alias`n"
                    $out += "        `$dynalias = New-Object System.Management.Automation.AliasAttribute -ArgumentList '$Item'`n"
                    $out += "        `$attributeCollection.Add(`$dynalias)`n"
                }
            }

            $out += "`n        # Defining the runtime parameter`n"

            #handle the Switch parameter since it uses a slightly different name
            if ($ParameterType.Name -match "Switch") {
                $paramType = "Switch"
            }
            else {
                $paramType = $ParameterType.Name
            }

            $out += "        `$dynParam1 = New-Object -Type System.Management.Automation.RuntimeDefinedParameter('$Name', [$paramType], `$attributeCollection)`n"
            if ($DefaultValue) {
                Write-Verbose "[$((Get-Date).TimeofDay) PROCESS] Using default value $($DefaultValue)"
                if ( $DefaultValue[0] -is [string]) {
                    $value = "'$($DefaultValue)'"
                }
                else {
                    $value = "`$$($DefaultValue)"
                }
                $out += "        `$dynParam1.Value = $value`n"
            }
            $Out += @"
        `$paramDictionary.Add('$Name', `$dynParam1)


"@
        } #foreach dynamic parameter name

    }
    End {
        $out += @"
        return `$paramDictionary
    } # end if
} #end DynamicParam
"@
        $out
        Write-Verbose "[$((Get-Date).TimeofDay) END    ] Ending $($myinvocation.mycommand)"
    } #end
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