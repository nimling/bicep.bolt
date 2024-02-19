# Environments

A annoyance that have been with me for a long time is the lack of a good way to handle different environments in a iac project.
Not because you have many tasks that is specific for an environment, but  becuse you sometimes have shared resources that you want to deploy / make sure are within the correct specs to all environments.

If you dont feel the need to have any environment control, thats totally fine. you can just ignore this part, set up the files and folders without setting environment and you are good to go. you will however get a warning when running the deploy.ps file, but you can ignore that.

if you care to use environments OR want to use shared variables across your projects, then read on.

lets talk about how BADU handles environments:

In order to create your first environment, go to deployconfig.json and add a new environment to the environments array.

```json
{
    //...
    "environments": [
        {
            "name": "dev",
            "isScoped": true,
            "variables":{}
        }
        {
            "name": "prod",
            "isScoped": true,
            "variables":{}
        }
        {
            "name": "shared",
            "isScoped": false,
            "variables":{}
        }
    ]
}
```

| name|type|description|
|---|---|---|
|name|string|the name of the environment. this is used to find the correct files and folders for the environment|
|isScoped|boolean|if this is set to true, then the environment needs to be specifically called in order to use the files tagged with this environment.|
|variables|object|this is a object that can contain any number of variables that you want to use in your deployment. [more on variables](variables.md)|

## simple? yes. but what does it do?

the name you defined needs to be reflected in the folder structure. so if you have a file or folder with the suffix "dev" (ie: `deploy.dev.bicep`) in the project, then BADU will know that this is the file or folder that should be used for the dev environment.

the isScoped property is used to define if the environment should be specifically called. if this is set to true, then you need to call the environment in order to use it. this is done by adding the environment name to the deploy command. ie: `deploy.ps dev` will deploy the dev environment.
On the flipside, a non-scoped environment will be appended regardless, so you technically would deploy to both `dev` and `shared` if you ran `deploy.ps dev` using the config abover.

NOTE:  
Because of the nature of this setup, only one environment can be used at a time. this is to avoid any confusion of what environment is being deployed and code-complexity.

## Recursive environments

If you have not yet realized, setting up environment if you specifically have to tag all of the files, can be a bit of a hazzle, thats why BADU is recursive. this means that if you have a folder higher up in your setup, that are tagged with a environment, BADU will assume every other file under this folder is this same environment with the name of the environment. this means that you can have a folder structure like this:

### example deployment with subscription level environment

``` text
deployconfig.json
|---mysubscription.shared -> Shared environment
    |---deploy.bicep
    |---rsg-shared
        |---keyvault.bicep
        |---database.bicep
        |---website.bicep
|---mysubscription.dev -> Dev environment
    |---deploy.bicep
    |---rsg-dev
        |---keyvault.bicep
        |---database.bicep
        |---website.bicep
|---mysubscription.prod -> Prod environment
    |---deploy.bicep
    |---rsg-prod
        |---keyvault.bicep
        |---database.bicep
        |---website.bicep
```

### example deployment with resourcegroup level environment

``` text
deployconfig.json
|---mysubscription
    |---deploy.bicep
    |---rsg-shared.shared
        |---dns.bicep
        |---network.bicep
        |---cert-keyvault.bicep
    |---rsg-dev.dev
        |---testresource.bicep
        |---keyvault.bicep
        |---database.bicep
        |---website.bicep
    |---rsg-prod.prod
        |---keyvault.bicep
        |---database.bicep
        |---website.bicep
```
