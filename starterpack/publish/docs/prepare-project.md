# prepare your project

* Have a git folder/project with your bicep modules.
* In the root of your project, create a bicepconfig
  * this can also be done though vscode, by having the project open, pressing `Ctrl+Shift+P` and typing `bicepconfig`
   ![bicepconfig option in vscode](./img/bicepconfig.png)
* inside bicepconfig, set `experimentalFeaturesEnabled.symbolicNameCodegen` to `true`
  * this will allow the tool to generate better output as is adds the name of the different resources to the generated code.
  * The tool will work without it, but the output will be less readable and exact, and if you have several resources of the same type, the tool will not be able to check details on them.
* prepare your modules folder [prepare your modules folder](#moduleorganisationalstyle)

# Module Organisational style

Right now, Bicep only supports one module per folder (`SingleModuleFolder`). This means that if you have a module that is called `my/module.bicep` you will have to rename it to `my/module/main.bicep` for the tool to work.

I plan to support `MultiModuleFolder` in the future, but for now, this is the only way to do it.

