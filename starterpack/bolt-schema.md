
# root

type: `Object`  
Root schema for Bolt  
**Properties**  

Name | Required | Type | Description | Link | Limitation
--- | --- | --- | --- | --- | ---
$schema |No |`String` |Schema to use for validation and autocomplete | |
tenant |No |`String` |Tenant name or id | |
bicep |No |`Object` |Bicep language configuration options |[Link](#bicep) |
remote |No |`Array` |schema for remote items |[Link](#remote) |
deploy |No |`None` |The schema for the bolt deploy config | |

## bicep

type: `Object`  
Bicep language configuration options  
**Properties**  

Name | Required | Type | Description | Link | Limitation
--- | --- | --- | --- | --- | ---
version |No |`String` |The version of the Bicep language to use. Defaults to latest. | |

## remote

type: `Array`  
schema for remote items  
**can be any of the following types:**  
  

Name | Type | Description | Link
--- | --- | --- | ---
remote_acr |`Object` |Azure Container Registry options |[Link](#remoteitem)

## deploy

type: `object`  
The schema for the bolt deploy config  
**Properties**  

Name | Required | Type | Description | Link | Limitation
--- | --- | --- | --- | --- | ---
deployFromLocation |Yes |`String` |The location to deploy from | |enum: `eastus` `eastus2` `southcentralus` `westus2` `westus3` `australiaeast` `southeastasia` `northeurope` `swedencentral` `uksouth` `westeurope` `centralus` `southafricanorth` `centralindia` `eastasia` `japaneast` `koreacentral` `canadacentral` `francecentral` `germanywestcentral` `italynorth` `norwayeast` `polandcentral` `switzerlandnorth` `uaenorth` `brazilsouth` `centraluseuap` `israelcentral` `qatarcentral` `asia` `asiapacific` `australia` `brazil` `canada` `europe` `france` `germany` `global` `india` `japan` `korea` `norway` `singapore` `southafrica` `switzerland` `unitedstates` `northcentralus` `westus` `eastus2euap` `westcentralus` `southafricawest` `australiacentral` `australiacentral2` `australiasoutheast` `japanwest` `koreasouth` `southindia` `westindia` `canadaeast` `francesouth` `germanynorth` `norwaywest` `switzerlandwest` `ukwest` `uaecentral` `brazilsoutheast`
varHandling |Yes |`Object` |Settings for variable handling when running bolt deploy |[Link](#deployvarhandling) |
environments |Yes |`Object` |The environments to deploy to |[Link](#deployenvironments) |

### deploy.varHandling

type: `Object`  
Settings for variable handling when running bolt deploy  
**Properties**  

Name | Required | Type | Description | Link | Limitation
--- | --- | --- | --- | --- | ---
style |Yes |`String` |The tag style to use for dry variables within environments | |enum: `{}` `[]` `<>`
directoryVarStyle |No |`String` |The tag style to use for directory variables within environments | |enum: `{}` `[]` `none` `sameAsStyle`
throwOnUnhandledVariable |Yes |`Boolean` |Whether to throw an error if a parameter with variable tags is not handled | |

### deploy.environments

type: `Object`  
The environments to deploy to  
**Properties**  

Name | Required | Type | Description | Link | Limitation
--- | --- | --- | --- | --- | ---
  
