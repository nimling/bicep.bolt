# BOLT - A Really fast lifecycle tool for bicep

Hi there, Philip here!
Today i will talk about bicep modules and how to deploy them.

Before i do that however im going to give you a some introduction about what/how/why.

## the what

For about 8 years, one of the very building-blocks for azure have been ARM templates. this have been used to define what kind of resource you want, how many, their names etc etc. The general thought of this was very neat, as its created with json and ingested by the azure management services, and mostly you'd have all your resources avalible within a couple minutes. this makes a lot of sense to do as json is pretty much the standard when talking to a web-api using rest nowdays. even if you go to their portal, defining a resource with Microsoft's wizard, you are essentially filling out a json-form, that gets sent in.

However, with time and scale these ARM templates became really unbearable and huge to work with. So much so, that very few even wanted to work directly with it, and you only did it if you HAD to (yes i was one of those) and normal procedure was to "click-ops" (click around the website) a default set of resources you wanted, export the template and then edit down that json to fit your needs afterwards.

Because of this round-about way, this led many professionals to not use the ARM-system at all, and just use Terraform instead. Terraform talks directly to the Azure Management API instead of using ARM as the "medium of communication". It gave the terraform language a clearer path from fingertips to api-hits.
It even has a official "Microsoft Azure" plugin.

However.. there is a catch to using Terraform: because Terraform uses the api to handle any changes, essentially making it a client-side system, they will never show up as a deployment in the azure activity log, and any actions derived from the Terraform-deployment is handled as separate events rather than events spawned from one action. this means that figuring out what changes was made with Terraform and what was made via portal pretty challenging (Unless you are using terraform itself to check it, as it has a built in resource-state-management system). In addition, any configuration scripts stays with the team that created it. Not bad if you don't want to work cross teams. This is not the case for ARM:

Because if the way azure handles ARM deployments, you have to deliver all the changes you want done, having microsoft verify the setup and deploying it. This means each time a deployment is made, you essensially upload a copy of your deployment-configuration making it avalible on the portal website for your coworkers/customer to easily redeploy if your deployed resources has any issues due to human error, or you need to get it back to a known state. Its all done directly from the portal by going to the resource group, selecting deployments, pick the resources you want to redeploy, re-enter some of the deployment parameters, wait some a couple seconds and you should have your changes completed.

### Enter Bicep

Bicep is a DSL (domain specific language) created by Microsoft in the hopes of simplifying the creation of ARM deployments. and i personally think they deliver on this. The main statements are simple:

- `param` = parameter
- `var` = variable
- `resource` = resource
- `module` = reference to another bicep deployment
- `Output` = what you want your deployment to show

If you have used terraform, this might feel really similar, but the main difference is; generally you dont have to care about WHERE the resources are going, this is defined when you deploy them, however when refrencing modules you can optionally do this.

Now im not going to delve too deep into this topic as how bicep works is already covered by many other blogs. insted im going to jump forward a few steps.

## The how

Say you have created a really nice set of resources you want to share with your team or coworkers to use, how are you going to do that?
If your first thought is to save them in a git for your team to access, you are about halfway there, but realistically, you have to do some more work to make it easier to handle cross git-repositories. This is where Azure Container Registry comes in.

### Enter: Azure Container Registry

the usage for Azure Container Registry (Acr) pretty self-named: it stores and can deliver container images.

It supports dockerfiles, helm charts and any image built with [OCI Image format](https://github.com/opencontainers/image-spec/blob/main/spec.md).  
the last part here is important for bicep, because the Bicep team figured out that in order deliver the correct module to your coworker is THE most important thing, even if you have made any changes later on.  
Imagine your coworkers using a bicep config you created 2 weeks ago, and then you add some new parameters or resources essentially breaking their setup. not a good time, so you need some kind of version control for your resource-definition.

Normally you would use docker to control the push and pull of images and could be handled directly with this, however as a part of the OCI spec every type of content needs to be delivered with metadata that tells the Registry what kind of content to expect. this is kind of like how its handled on the web generally (header value `content-type`), but in the oci-spec its called `media type`. Well, the media type that is generated for bicep is not supported by docker. remember; dockers main function is to generate containers from images and serve as a hypervisor for containers. not JUST to handle stuff in container registries.  

No sweat, because this handling is built into bicep:

`bicep publish your/module.bicep 'br:yourregistry.azurecr.io/your/module:v1'`

this single commands takes your document, converts it to ARM, packages it as a OCI image and pushes it to your registry.

Now this is all fine and dandy if you dont have a lot of modules, create a short script to update whenever you make changes and badabing badaboom you are done!  
...   
But how do you know when to update to v2? 
Is v2 a breaking change or did you justy make an ajustment (making it a potentially v1.1?)  
what if there are several other people working on the same repo? don't you want to know what might have changed, without reading the code?  
to extend on that, what if you have "customers", either as colleagues or actual customers, that are using your modules? dont you want to show them what you have done?
and what if you have 10 modules?  
20?  
100?  
1000?

Well the i have a solution for you!

## BOLT

"Bolt" stands for Bicep Operations and Lifecycle Tool and its whole purpose is to make it easier for you, an IT proffesional to version-handle your bicep modules.

### How does it work?

In simple terms, it checks your local modules against your azure container registry and compares the data signatures (hashes/digest). If the local signature is different from the remote signature, it means the module is supposed to be updated.  

The neat thing here is in order to check if the module is supposed to be updated, i have to convert the bicep document to ARM using `bicep.exe`, and by that process you can also take advantage of bicep's powerfull static-analyser/linter tool defined with [bicepconfig.json](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/bicep-config). this config file is used to define what kind of rules you want to enforce on your bicep documents.


### But you talked about versioning?

