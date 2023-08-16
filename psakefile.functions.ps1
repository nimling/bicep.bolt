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
    
    [System.Management.Automation.Language.Parser]::ParseInput(($Main -join "`n"), [ref]$astTokens, [ref]$astErr) | out-null
    $insideRegion = $false
    $astTokens | Where-Object { $_.kind -eq 'comment' } | ForEach-Object {
        $comment = $_.text
        # Write-Host  $comment
        if (!$insideRegion -and $comment -match "region\s+$RegionName") {
            # Write-host $($_|convertto-json -Depth 1 -Compress)
            $region = [ScriptRegion]::new()
            $region.start = $_.Extent.StartLineNumber
            $insideRegion = $true
        }if ($insideRegion -and $comment -like "*#endregion*") {
            $region.end = $_.Extent.EndLineNumber
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
        if($parent -like "*/"){
            $parent.Substring(0, $parent.Length - 1)
        }

        if($child -like "*/"){
            $child.Substring(1, $child.Length - 1)
        }
    }
    
    end {
        
    }
}
# New-JsonFromSchema -Schema 'C:\git\nim\bicep-toolbox\badu\schema\deployconfig.schema.json' -OutputPath 'C:\git\nim\bicep-toolbox\badu\starterpack\deployconfig.json' -Size minimal -Verbose -ReferenceSchemaPath './deployconfig.schema.json'