# Bolt.ps1

## Description

## Requirements

Powershell 7.2

Modules:

- powershell az module. (Minimum Version 10.0.0) ([Gallery Link](https://www.powershellgallery.com/packages/Az/10.0.0))
  - I'm importing the following modules from az, so you need to have them installed:
  - Az.Accounts
  - Az.Resources
  - Az.ContainerRegistry

- Azure Container registry with Admin credentials allowed. ([Docs](https://docs.microsoft.com/en-us/azure/container-registry/container-registry-authentication#admin-account))

## Parameters

- **Branch** (Alias '`Release`') `[string]`: The branch to use for the build. This is reflected in config.publish.releases
- **Name** `[string]`: if you a specific module name to push. 
  - supports wildcard. 
  - This is the logical name for the module, not just "filename" `path/to/my/module`. so if you want to push several modules within the same folder, you can say `path/to/my/*` and it will push all modules in that folder.
- **Actions** `[string[]]`: The actions to run. 
  - Publish: Publish the modules to the repository
  - CreateUpdateData: (NOT ENABLED YET) Creates json with data of what triggered the update-. useful for documentation (whats new in this release)
- **List** `[switch]`: if you want to list the modules that will be published.
- **DotSource** `[switch]`: only used by its child processes. imports bolt functions and classes without running it. not intended to be used by the user.

## so what happens?

1. import all functions and classes it uses
2. load the config file
3. search for bicep modules
4. get acr admin credentials
5. for each module ->
   1. build the module to ARM template
   2. check acr if module is different
   3. for each version ->
      1. check release differences to figure out if we need to publish
      2. if different -> push to acr
