# Bolt.ps1

## Description

## Requirements

Powershell 7.2

Modules:

- az version (Recomended Version 10.0.0) ([Gallery Link](https://www.powershellgallery.com/packages/Az/10.0.0))
  - Az.Accounts
  - Az.Resources
  - Az.ContainerRegistry

## Parameters

- **Branch** (Alias 'Release') `[string]`: The branch to use for the build. This is reflected in config.publish.releases
- **Name** `[string]`: if you a specific module name to push. 
  - supports wildcard. 
  - This is the logical name for the module, not just "filename" `path/to/my/module`. so if you want to push several modules within the same folder, you can say `path/to/my/*` and it will push all modules in that folder.
- **Actions** `[string[]]`: The actions to run. 
  - Publish: Publish the modules to the repository
  - CreateUpdateData: (NOT ENABLED YET) Creates json with data of what triggered the update-. useful for documentation (whats new in this release)
- **List** `[switch]`: if you want to list the modules that will be published.
