
please use the code in /starterpack, as this is the most up to date version.
this version handles all the requests suncronously, and is slower than i like. The new version handles all requests async, and is much faster. however, it is not yet ready for public use, as it is not fully tested.

please contact me ([philip@nimtech](mailto:Philip@nimtech.no)) or write a issue here if you want to contribute.

# Bicep Arm Deployment Utility (BADU)
----

BADU makes Bicep deployment easy by providing a clear and intuitive folder structure.  
Instead of specifying a configuration file to define the context for a deployment, BAD uses folders to achieve the same result:

``` text
In azure:
----
Tenant
ManagementGroups
|---Subscription
    |---Resourcegroup
        |----Resource

***********************

Locally:
----
deployConfig.json
|---Folder with subscription name / id
    |---Bicep files for subscription deployment
    |---Folder with resourcegroup name
        |---Bicep files for resource deployment
```

The tenant + MG folder is omitted as it is unnecessary. You can either log in to the correct tenant or set the correct tenant using devops pipeline/github actions.  
However, the tenant still have to be defined in `deployConfig.json` file to ensure that you connect to the correct subscription in case you have access to multiple subscriptions in different tenants that are named the same thing.

also notice the first scope is subscription. badu so far is only created for Subscription/Rg deployments. however its in the pipeline to handle Mg's aswell

## Folder Structure

### Root

* Deploy.ps is used to handle everything. just start this and it will figure itself out, if your folder structure and config is correct
* deployConfig.json can only have this name. there is future plant to handle several tenants/configs, but for now it only handles one tenant/config per 'root'

### /Subscription

The name of this folder can be either the name or ID of the subscription.
This folder can contain any number of Bicep scripts that you need to run in the subscription context.

You can also have any number of resource groups that you want to deploy to.

NOTE: Remember to set the bicep scripts with `targetScope = 'subscription'` at top of the bicep document. its a bicep preference and not BADU preference.

### /Resourcegroup

The name of this folder needs to be the name of the resource group that you are deploying to.  
Any folder that includes the name ".ignore" will be ignored.

Add any Bicep files that should be part of the resource group deployment, and they will all be deployed within the rg context

## Environment configuration

more info about this is here: [Environment configuration](docs/environment.md)

TLDR: 

In the case where you want to define multiple environments, you can do so by:

1. appending the environment name to either
   1. the subscription folder -> "mysubscription.env"
   2. resource group folder -> "myrg.env"
   3. bicep definition -> "myscript.env.bicep"
2. define the environment in the `deployConfig.json` file

note that any environment set at a higher level will be inherited by the lower levels, so if you have set `mysubscription.dev` at subscription level, you dont have to define `.dev` at resource group or bicep definition level.

## Varaiables

It does not support the new bicepParam yet
more info about this is here: [Variables](variables.md)

this is connected to the usage of environment, and can make your deployment DRY.

TLDR:  
After you have defined your environment, you can define variables used in that environment
this again can be called using `tags` or `tokens` inside your `.parameters.json` file.

example:
``` json
// deployconfig
{
    "dry":{
        "style":"<>"
        //...
    },
    //...
    "environments": [
        {
            "name": "dev",
            "isScoped": true,
            "variables": {
                "env": {
                    "type":"static",
                    "value":"dev"
                }
            }
        }
    ]
}
```

``` json
// .parameters.json
{
    "myparam"{
        "value": "<env>"
    }
}
```

when deploying `myparam` would be set to 'dev'

Supported types are:

* static -> just a static value
* keyvault  -> Keyvault secret reference (best practice for deploying secrets. [Microsoft Docs](https://learn.microsoft.com/en-us/azure/azure-resource-manager/templates/key-vault-parameter?tabs=azure-cli#reference-secrets-with-static-id))
* identity -> current identity type, objectid (principal id), name, ip
