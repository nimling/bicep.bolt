# deployment Variables

## Table of contents

- [deployment Variables](#deployment-variables)
  - [Table of contents](#table-of-contents)
  - [The basics](#the-basics)
    - [reference in string](#reference-in-string)
  - [it's getting tricky (aka. how we have thought)](#its-getting-tricky-aka-how-we-have-thought)
  - [variable scope clarity](#variable-scope-clarity)
  - [variable definition and assignment clarity](#variable-definition-and-assignment-clarity)
  - [variable value simplicity](#variable-value-simplicity)
    - [static](#static)
      - [Static example](#static-example)
    - [keyvault](#keyvault)
      - [Keyvault Example - static](#keyvault-example---static)
      - [Keyvault Example - dynamic](#keyvault-example---dynamic)
    - [identity variable](#identity-variable)

## The basics

the usage of variables is defined within your `{deployment}.parameters.json` file with special characters around a key that you want to be replaced when deploying.

``` json
{
  "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "location": {
      "value": "<location>"
    },
    "resource_group":{
      "value": "rsg-<env-param>-<project_name>"
    }
  }
}
```

this in turn is looked up within your `deployConfig.json` file, and the value is replaced with the value of the variable:

``` json
{
  "location": {
      "type": "static",
      "description": "Location",
      "value": "NorwayEast"
  },
  "env-param": {
      "type": "static",
      "description": "environment parameter",
      "value": "dev"
  },
  "project_name": {
      "type": "static",
      "description": "project name",
      "value": "badu"
  }
}
```

this means that the value of the location parameter will be `NorwayEast` when the deployment is run and resource_group would be `rsg-dev-badu`.

### reference in string

As you see above, it supports having variables in the middle of a string, and it will replace the variable with the value of the variable.
there is not really any limitations, here, but at once i see the "end" of variable, i will stop processing:

- `rsg-<env-param>-<project_name>` will be replaced with `rsg-dev-badu`
- `rsg>-<env-param>-<project_name>` will be replaced with `rsg>-dev-badu`
- `rsg-<env-param>-<project_name` will be replaced with `rsg-dev-<project_name`
- `rsg-<env->param>-<project_name>-` will fail, because `env-` is not defined (using the config above).

The only real limitation here is that the variable have to be defined on parameter.value level, so there is no support for having variable references inside arrays or objects.

even though BADU can handle variable names with several different delimiter characters, we recommend using the same delimiter character for all variables in a deployment. IE: if you use `-` as a delimiter for one, you should use it for all.

NOTE:  
we recomend using the delimiter underscore `_` as its easier to "select all" (double click the actual string in json) for copying than space or dash `-`. camel case might also help, but generally when reading json its easier to read with underscore: `someMassiveVariableName` vs `some_massive_variable_name`.

## it's getting tricky (aka. how we have thought)

You want to make sure that you have the right variables in the right place, but also not muddy the waters with too many variations of how to write a variable.
With the notion of variables, comes the concept of DRY (dont repeat yourself). the whole point of variables is to make sure that you dont have to repeat yourself, and likewise we have tried to make sure that you dont have to repeat yourself when defining variables.

with this in mind, we have a few rules for how we have thought about and defined variables within our deployConfig.json:

1. variable scope should be clear
2. both definition and assignment of variables should be easy to understand.
3. there should not be too many variations of how to write a variable value.

## variable scope clarity

The problem, with some DRY configurations is that it can be hard to pinpoint WHEN a variable is being used.
for example if you have a variable that have the same name, but different values in multiple environments, it can be hard to see wich one is active at any given time.
because of this we have decided to tie the variable handling directly to our environment handling, with 2 rules:

1. Only one active scoped enviroment at any given time.
2. Scoped variables always have priority over non-scoped variables.

take a look at [environments](environments.md) doc for more info on how to set up environments, but i will give you a small example:

``` json
{
"environments": [
    {
      "name": "dev",
      "isScoped": true,
      "variables": {}
    },
    {
      "name": "prod",
      "isScoped": true,
      "variables": {
        "location": {
          "type": "static",
          "description": "Location for resource",
          "value": "NorwayEast",
        }
      }
    },
    {
      "name": "any",
        "isScoped": false,
        "variables": {
          "location": {
              "description": "Location for resource",
              "type": "static",
              "value": "WestEurope",
          }
        }
    }
]
```

if the deployment was run with `-env dev` or without `-env`, the location variable would be `WestEurope`, but if it was run with `-env prod`, the location variable would be `NorwayEast`.

NOTE:  
THIS ALSO MEANS ANY SHARED RESOURCE THE USES `<location>` WILL BE SET TO `NorwayEast` WHEN THE DEPLOYMENT IS RUN WITH `-env prod`. YES, I HAVE MADE THIS MISTAKE BEFORE, AND ITS WHY IM YELLING. DONT BE LIKE ME. This will be fixed in a future release, but for now, be aware of this.

this is also backed up when you take a look at the output of the deployment as it will tell you where the specific variable was found:

``` powershell
#replacing 'location':'<location>' with type:'string', description:'Location for resource' from 'any'
```

## variable definition and assignment clarity

In order to make sure that a variable stands out within your `parameters.json` we have added a 'tag' that you can append to your parameter value.
The setting for exactly what tag you want to use is defined within deployconfig:`dry.style`. the currently supported tags are: `<>`, `[]` and `{}`, but in the examples i will use `<>`

in this case `location`, `tags`, `env` and `project` are all refrences to variables that are defined within the config file.

``` json
{
  "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "location": {
      "value": "<location>"
    },
    "tags": {
      "value": "<tags>"
    },
    "env": {
      "value": "<env>"
    },
    "project": {
      "value": "<project>"
    },
    "names": {
      "value": [
        "service1",
        "service2",
        "service3"
      ]
    }
  }
}
```

NOTE  
while one style of tag might be active at any given time, we know that there is a possibility that you might want to use a different style of tags over time. and want to make sure you dont have any "stragglers".  
**This is something that is currently in the pipeline, however is not yet implemented.**

## variable value simplicity

while we do need to support a few different types of variables, we have tried to make sure that the syntax for defining them is as simple as possible.
the currently supported types are:

- [static](#static)
- [identity](#identity)
- [keyvault](#keyvault)

all variables have these 2 i common:
key|type|description|mandatory
---|---|---|---
type|string|the type of variable|yes
description|string|a description of the variable|no

### static

it does pretty much what you expect. the value set in the variable is the value you can expect back when the deployment is run.

key|type|description|mandatory
---|---|---|---
value|any|the value of the variable|yes

#### Static example

``` json
//deployConfig.json/environments/*/variables
{
  "stringvar":{
      "type": "static",
      "description": "string variable",
      "value": "mystring",
  },
  "arrayvar": {
      "type": "static",
      "description": "array Variable",
      "value": [
        "val1",
        "val2"
      ]
  },
  "objectvar": {
      "type": "static",
      "description": "object Variable",
      "value": {
        "key1":"val",
        "key2":"val2"
      }
  },
  "boolvar": {
      "type": "static",
      "description": "bool Variable",
      "value": false
  },
  "intvar": {
      "type": "static",
      "description": "int Variable",
      "value": 1234
  }
}
```

``` json
//mydeploy.parameters.json
{
  {
  "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "str": {
      "value": "<stringvar>"
    },
    "arr": {
      "value": "<arrayvar>"
    },
    "obj": {
      "value": "<objectvar>"
    },
    "bool": {
      "value": "<boolvar>"
    },
    "int": {
      "value": "<intvar>"
    }
  }
}
```

``` powershell
#actual values that are sent when deploying:
$Deployparameters = @{
    "str" = "mystring"
    "arr" = @("val1","val2")
    "obj" = @{
        "key1" = "val"
        "key2" = "val2"
    }
    "bool" = $false
    "int" = 1234
}
```

### keyvault

more complex deployments will need to use keyvaults to store secrets, and we have made sure to support and simplify this as it is a type of handling that is currently missing in standard ARM templates.

normally; while you can deliver static keyvault references as a part of ARM parameter, it does need the the full resource id of the keyvault, and the secret name.

the kevault in question have to be within the same subscription as your deployment, and you have to have access to it, and the resource must be enabled on the property `properties.enabledForTemplateDeployment`

key|type|description|mandatory
---|---|---|---
secret|string|the name of the secret|yes
vault|string|the name of the keyvault|yes
version|string|the version of the secret. if nothing is defined, its getting the latest|no

#### Keyvault Example - static

this is a basic example of how to use a keyvault secret as a static value. notice that the value you put in the parameters file is not a "keyvault reference" [as defined by Microsoft](https://learn.microsoft.com/en-us/azure/azure-resource-manager/templates/key-vault-parameter?tabs=azure-cli#reference-secrets-with-static-id), but rather just "value" as you would use on any other static variable.

``` json
//deployConfig.json/environments/*/variables
{
  "keyvault":{
    "type": "keyvaultSecret",
    "secret": "mysecret",
    "vault": "myvault",
    //"version": "version" -> not mandatory
  },
}
```

``` json
//mydeploy.parameters.json
{
  "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "mysecret": {
      "value": "<keyvaultSecret>"
    }
  }
}
```

``` powershell
#these are valued handled by the deployer, and not the user, this is just psuedocode to show how the values are handled
#actual values that are sent when deploying:
$Deployparameters = @{
  mysecret = @{
    reference= @{
      keyVault = @{
          id: "/subscriptions/<curren-context-subscription-id>/resourceGroups/<keyvault-resourceGroupName>/providers/Microsoft.KeyVault/vaults/myvault"
      }
      secretName = "mysecret"
    }
  }
}
```

#### Keyvault Example - dynamic

this variable again supports usage of static variables, so you can create a 'keyvault' variable in non-scoped environment, and specify some of the details within a scoped environment.

``` json
//deployconfig.json/environments
[
  {
      "name": "dev",
      "isScoped": true,
      "variables": {
      }
  },
  {
      "name": "test",
      "isScoped": true,
      "variables": {
          "deploysecret": {
              "type": "static",
              "description": "the value specifically for test",
              "value": "mysecret-test"
          }
      }
  },
  {
      "name": "prod",
      "isScoped": true,
      "variables": {
          "deploysecret": {
              "type": "static",
              "description": "the value specifically for prod",
              "value": "mysecret-production"
          },
          "deployvault": {
              "type": "static",
              "description": "the keyvault for prod",
              "value": "prod-vault"
          }
      }
  },
  {
      "name": "any",
      "isScoped": false,
      "variables": {
          "keyvault":{
              "type": "keyvault",
              "secret": "<deploysecret>",
              "vault": "<deployvault>",
          },
          "deployvault": {
              "type": "static",
              "description": "the keyvault for any env",
              "value": "non-prod-vault"
          }
      }
  }
]
```

``` json
//mydeploy.parameters.json
{
  "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "mysecret": {
      "value": "<keyvaultSecret>"
    }
  }
}
```

``` powershell
#these are valued handled by the deployer, and not the user, this is just psuedocode to show how the values are handled
#actual values that are sent when deploying with -env 'prod':
$Deployparameters = @{
  mysecret = @{
    reference= @{
      keyVault = @{
          id = "/subscriptions/<curren-context-subscription-id>/resourceGroups/<keyvault-resourceGroupName>/providers/Microsoft.KeyVault/vaults/prod-vault"
      }
      secretName = "mysecret-production"
    }
  }
}

#actual values that are sent when deploying with -env 'test':
$Deployparameters = @{
  mysecret = @{
    reference= @{
      keyVault = @{
          id: "/subscriptions/<curren-context-subscription-id>/resourceGroups/<keyvault-resourceGroupName>/providers/Microsoft.KeyVault/vaults/non-prod-vault"
      }
      secretName = "mysecret-test"
    }
  }
}

#actual values that are sent when deploying with -env 'dev': this will throw an error, as deploysecret is not defined in the environment
Error: variable 'deploysecret' is not defined in environment 'dev'
```

### identity variable

this is a special type of variable that gets the current identity of the caller and process in order to easily be able to assign permissions to the deployment identity.

as of now we support the following types of outputs:

- principalId -> currentiy identity object id
- name -> current identity name
- type -> current identity type (user, service principal, managed identity)
- ip -> current identity ip address using ipinfo.io
  
Note: 
If you have any suggestions of what other outputs you would like to see, please create an issue on the github repo.
