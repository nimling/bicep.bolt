# BOLT

Bicep Operations and Lifecycle Tool

BOLT: Zap Your Bicep Blues, Amp Up Your Azure Moves!

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
