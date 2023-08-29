# BOLT - Bicep Operations and Lifecycle Tool

Everything you need to manage your bicep modules to azure container registry.  
Upload multiple bicep modules at the same time with automatic verisioning!

---

## What is Bolt?

Bolt is a tool to help you manage your bicep modules. It will take a folder, you define and upload all of the bicep files (within a filter you defined) to an azure container registry.

To help you manage the versions of your modules, Bolt will automatically create a new version for each module you upload depending on the versioning strategy you defined.

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
