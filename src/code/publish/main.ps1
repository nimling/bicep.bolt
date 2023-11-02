using namespace System.Collections.Generic
using namespace System.io
using namespace System

function Invoke-Bolt:publish {
    [CmdletBinding(

    )]
    param (
        # region uncomment_on_publish
        [string]$Release,
        [string]$Name = "*",
        [ValidateSet("CreateUpdateData", "Publish", "CleanRegistry", "All" )]
        [string[]]$Actions = "Publish",
        [switch]$List
        #enregion uncomment_on_publish
    )

    dynamicparam{
        #region remove_on_publish
        $paramDictionary = New-Object -Type System.Management.Automation.RuntimeDefinedParameterDictionary
        #endregion remove_on_publish

        #region tag:publish:
        # Defining parameter attributes
        $attributeCollection = New-Object -Type System.Collections.ObjectModel.Collection[System.Attribute]
        $attributes = New-Object System.Management.Automation.ParameterAttribute
        $attributes.ParameterSetName = 'publish'
        $attributes.Mandatory = $True

        # Adding ValidateSet parameter validation
        $releases = resolve-configvalue -address 'publish.releases'
        $v = New-Object System.Management.Automation.ValidateSetAttribute($releases.keys)
        $AttributeCollection.Add($v)
        $attributeCollection.Add($attributes)

        # Defining the runtime parameter
        $dynParam1 = New-Object -Type System.Management.Automation.RuntimeDefinedParameter('release', [String], $attributeCollection)
        $paramDictionary.Add('release', $dynParam1)

        #region remove_on_publish
        return $paramDictionary
        #region remove_on_publish


    }
    begin {
        
    }
    
    process {
        
    }
    
    end {
        
    }
}