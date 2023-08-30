# BOLT - Bicep Operations and Lifecycle Tool

Everything you need to manage your bicep modules to azure container registry.  
Upload multiple bicep modules at the same time with automatic verisioning!

---

## What is Bolt?

Bolt is a tool to help you manage your bicep modules. It will take a folder, you define and upload all of the bicep files (within a filter you defined) to an azure container registry.

To help you manage the versions of your modules, Bolt will automatically create a new version for each module you upload depending on the versioning strategy you defined.  
Bolt supports 2 modes of versioning: `static` and `semantic`.  
`static` will upload with the same defined version every time (ex: `latest` or `beta`)  
`semantic` will set major, minor and patch version depending on what you think should trigger the next version. read more about Module release tests and triggers [here](./docs/versionTrigger.md)

To speed up the upload process bolt will build, check and upload all files asynchronously. This means that if you have 10 modules, it will build all of them, then check all of them, then upload all of them. This will speed up the process significantly.

## How do i start?

### Prerequisites

Install atleast powershell 7.2. You can download it below:

* [Windows](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.3)
* [Linux](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-linux?view=powershell-7.3)
* [macOs](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-macos?view=powershell-7.3)
* [Arm](https://learn.microsoft.com/en-us/powershell/scripting/install/powershell-on-arm?view=powershell-7.3)
* [Docker](https://learn.microsoft.com/en-us/powershell/scripting/install/powershell-in-docker?view=powershell-7.3)

Install az module version 10 (official microsoft azure powershell module). You can install it with:  
`Find-Module az -MinimumVersion 10.0.0|Install-Module -Force -Scope CurrentUser`

Install bicep, version 17+, but the latest is very stable. [link](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/install)

Install [Git](https://git-scm.com/downloads) (I use git to figure out the root of your project, so you can use the tool from anywhere in your project)

### Prepare your project

* Have a git folder/project with your bicep modules.
* In the root of your project, create a bicepconfig
  * this can also be done though vscode, by having the project open, pressing `Ctrl+Shift+P` and typing `bicepconfig`
   ![bicepconfig option in vscode](./docs/img/bicepconfig.png)
* inside bicepconfig, set `experimentalFeaturesEnabled.symbolicNameCodegen` to `true`
  * this will allow the tool to generate better output as is adds the name of the different resources to the generated code.
  * The tool will work without it, but the output will be less readable and exact, and if you have several resources of the same type, i will not be able to check details on them.
* have a folder ready with your modules.
  * NOTE: Right now, im only supporting what i call `Single Module Folder`, meaning one folder = 1 modules.
  * the modules have to be set up with a shared name where the parent folder defines the name of the module.
  * example: if you have a module called `my/module.bicep` the new path for the module will be `my/module/main.bicep`

### Install Bolt

Go into the 'starterpack' folder and download the zip file. Extract it to a folder of your choice (preferably a folder above your modules folder).

``` text
|root
    |modules
        |module1
        |module2
        |module3
    |bolt.ps1
    |bolt.json
```


NOTE: It is higly recommended to enable bicepconfig.experimentalFeaturesEnabled.symbolicNameCodegen
This will allow this tool to generate better output as is adds the name of the different resources to the generated code.
The tool will work without it, but the output will be less readable and exact, and if you have several resources of the same type, i will not be able to check details on them.

oci spec: <https://github.com/opencontainers/distribution-spec/blob/main/spec.md#checking-if-content-exists-in-the-registry>
layers is the files inside a repository:
tag. its like a zip file, you have a metadata element that explains what is inside.
digest is the hash of the file contents + what hash is used.
to grab the actual content you need to call the blob endpoint with the hash of the layer. {reponame}/blobs/{digest of layer}

``` text
example:
someimage:tag:
    layers:
        - digest of layer (no name is present)
        mediatype
        size
```

bicep deployments ususally only have one layer: the bicep file, converted to arm
