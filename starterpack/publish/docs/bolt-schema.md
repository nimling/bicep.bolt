# Bolt

type: `Object`  
Configuration for bicep publish  

**Properties**

| Name |Required| Type | Description |Link |Limitation|
|--|--|--|--|--|--|
| bicepVersion | Yes | String | The required version of bicep. written as version (example: 1.0.1) |  | pattern: `\d+\.\d+\.\d+` |
| registry | Yes | Object |  | [Link](#registry) |  |
| module | Yes | Object | module configuration | [Link](#module) |  |
| publish | Yes | Object |  | [Link](#publish) |  |

-----

## registry

type: `Object`  

**Properties**

| Name |Required| Type | Description |Link |Limitation|
|--|--|--|--|--|--|
| name | Yes | String | name of container registy. url not needed |  |  |
| subscriptionId | Yes | String | Subscription ID |  |  |
| tenantId | Yes | String | Tenant ID of tenant domain |  |  |

-----

## module

type: `Object`  
module configuration  

**Properties**

| Name |Required| Type | Description |Link |Limitation|
|--|--|--|--|--|--|
| temp | No | String | where to store temporary files. default is 'bicepTemp'. path is relative to config file |  |  |
| folder | Yes | String | Location of modules in relation to config file |  |  |
| organisationStyle | Yes | Object | how modules are organised | [Link](#module.organisationStyle) |  |

-----

### module.organisationStyle

type: `Object`  
how modules are organised  

**Properties**

| Name |Required| Type | Description |Link |Limitation|
|--|--|--|--|--|--|
| type | Yes | String | the style of your module repository. SingleModuleFolder for a single module per folder (./mymodule/main.bicep) or MultiModuleFolder for multiple modules in a single folder (./mymodule.bicep) |  | enum: `SingleModuleFolder` |
| filter | Yes | String | only deploy modules that match this filter. this is wildcard. if you have defined SingleModuleFolder type, this is used to define what that single module should be named. |  |  |
| exclude | No | String | exclude modules that match this filter. this is wildcard. default is empty |  |  |

-----

## publish

type: `Object`  

**Properties**

| Name |Required| Type | Description |Link |Limitation|
|--|--|--|--|--|--|
| releaseTrigger | Yes | Object | what should trigger a publish | [Link](#publish.releaseTrigger) | minProperties: `1` |
| defaultRelease | Yes | String |  |  |  |
| releases | Yes | Array |  | [Link](#publish.releases) | minItems: `1` |
**Example**

```json
{
  "releaseTrigger": {
    "static": {
      "update": [
        "moduleModified"
      ]
    },
    "semantic": {
      "major": [
        "paramAddedWithoutDefaultValue"
      ],
      "minor": [
        "resourceAdded"
      ],
      "patch": [
        "moduleModified"
      ]
    }
  },
  "defaultRelease": "dev",
  "releases": [
    {
      "name": "dev",
      "trigger": "static",
      "value": "beta"
    }
  ]
}
```


-----

### publish.releaseTrigger

type: `Object`  
what should trigger a publish  

**Properties**

| Name |Required| Type | Description |Link |Limitation|
|--|--|--|--|--|--|
| static | No | Object |  | [Link](#publish.releaseTrigger.static) |  |
| semantic | No | Object |  | [Link](#publish.releaseTrigger.semantic) |  |

-----

#### publish.releaseTrigger.static

type: `Object`  

**Properties**

| Name |Required| Type | Description |Link |Limitation|
|--|--|--|--|--|--|
| update | No | Array |  | [Link](#publish.releaseTrigger.static.update) |  |

-----

##### publish.releaseTrigger.static.update

type: `Array`  

**Accepted Values**

| Name |Required| Type | Description |Link |Limitation|
|--|--|--|--|--|--|
| item | No | String |  |  | enum: `paramCaseModified, paramAddedWithoutDefaultValue, paramRemoved, paramTypeModified, paramAllowedValueModified, paramDefaultValueModified, resourceAdded, resourceRemoved, resourceApiVersionModified, resourcePropertiesAdded, resourcePropertiesRemoved, resourcePropertiesModified, outputsAdded, outputsRemoved, outputsModified, moduleModified` |

-----

#### publish.releaseTrigger.semantic

type: `Object`  

**Properties**

| Name |Required| Type | Description |Link |Limitation|
|--|--|--|--|--|--|
| major | No | Array |  | [Link](#publish.releaseTrigger.semantic.major) |  |
| minor | No | Array |  | [Link](#publish.releaseTrigger.semantic.minor) |  |
| patch | No | Array |  | [Link](#publish.releaseTrigger.semantic.patch) |  |

-----

##### publish.releaseTrigger.semantic.major

type: `Array`  

**Accepted Values**

| Name |Required| Type | Description |Link |Limitation|
|--|--|--|--|--|--|
| item | No | String |  |  | enum: `paramCaseModified, paramAddedWithoutDefaultValue, paramRemoved, paramTypeModified, paramAllowedValueModified, paramDefaultValueModified, resourceAdded, resourceRemoved, resourceApiVersionModified, resourcePropertiesAdded, resourcePropertiesRemoved, resourcePropertiesModified, outputsAdded, outputsRemoved, outputsModified, moduleModified` |

-----

##### publish.releaseTrigger.semantic.minor

type: `Array`  

**Accepted Values**

| Name |Required| Type | Description |Link |Limitation|
|--|--|--|--|--|--|
| item | No | String |  |  | enum: `paramCaseModified, paramAddedWithoutDefaultValue, paramRemoved, paramTypeModified, paramAllowedValueModified, paramDefaultValueModified, resourceAdded, resourceRemoved, resourceApiVersionModified, resourcePropertiesAdded, resourcePropertiesRemoved, resourcePropertiesModified, outputsAdded, outputsRemoved, outputsModified, moduleModified` |

-----

##### publish.releaseTrigger.semantic.patch

type: `Array`  

**Accepted Values**

| Name |Required| Type | Description |Link |Limitation|
|--|--|--|--|--|--|
| item | No | String |  |  | enum: `paramCaseModified, paramAddedWithoutDefaultValue, paramRemoved, paramTypeModified, paramAllowedValueModified, paramDefaultValueModified, resourceAdded, resourceRemoved, resourceApiVersionModified, resourcePropertiesAdded, resourcePropertiesRemoved, resourcePropertiesModified, outputsAdded, outputsRemoved, outputsModified, moduleModified` |

-----

### publish.releases

type: `Array`  

**Accepted Values**

| Name |Required| Type | Description |Link |Limitation|
|--|--|--|--|--|--|
| item | No | Object |  | [Link](#publish.releases.item) |  |

-----

#### publish.releases.item

type: `Object`  

**Properties**

| Name |Required| Type | Description |Link |Limitation|
|--|--|--|--|--|--|
| name | No | String |  |  |  |
| trigger | No | String |  |  | enum: `static, semantic` |
| value | No | String | will be used as the value when released. ignored for semantic version |  |  |
| prefix | No | String | will be used as the prefix when released. version '1.2.3' would be 'v1.2.3' if prefix is 'v' |  |  |

-----


-----

This markdown was automactially generated from the schema file. it may not be 100% correct. please 
