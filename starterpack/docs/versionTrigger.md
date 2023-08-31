# Module release tests and triggers

A core part of how Bolt deciedes if it should update your modules or not, is the release testing and triggers.

Without talking too much about exacly how it works, here is a short summary (this is if bolt finds a module in the registry):

- Download the latest version of the module from the registry and convert it to a workable object
  - if its a static release it will look for the static name
  - if its a semantic release it will look for the latest semantic version
- Build local bicep script to Arm template, import it as an workable object
- Compare the two objects (with the tests you select in config) and see if there is any difference
  - if there is a difference, it will upload the new version to the registry
  - if there is no difference, it will skip the upload

the currently defined tests are:

name|description|link
---|---|---
paramCaseModified|if the name of any parameter is changed|[link](#paramcasemodified)
paramAddedWithoutDefaultValue|if any parameter is added without a default value|[link](#paramaddedwithoutdefaultvalue)
paramRemoved|if any parameter is removed|[link](#paramRemoved)
paramTypeModified|if the type of any parameter is changed|[link](#paramTypeModified)
paramAllowedValueModified|if the allowed values of any parameter is changed|[link](#paramAllowedValueModified)
paramDefaultValueModified|if the default value of any parameter is changed|[link](#paramDefaultValueModified)
resourceAdded|if any resource is added|[link](#resourceAdded)
resourceRemoved|if any resource is removed|[link](#resourceRemoved)
resourceApiVersionModified|if the api version of any resource is changed|[link](#resourceApiVersionModified)
resourcePropertiesAdded|if any properties are added to any resource|[link](#resourcePropertiesAdded)
resourcePropertiesRemoved|if any properties are removed from any resource|[link](#resourcePropertiesRemoved)
resourcePropertiesModified|if any properties are modified on any resource|[link](#resourcePropertiesModified)
outputsAdded|if any outputs are added|[link](#outputsAdded)
outputsRemoved|if any outputs are removed|[link](#outputsRemoved)
outputsModified|if any outputs are modified|[link](#outputsModified)
moduleModified|if the module is modified|[link](#moduleModified)

## paramCaseModified

if the name of any parameter is changed.

the check is a case sensitive check, so if you change the name of a parameter from `myParam` to `MyParam` it will trigger this test.

bicep itself is case sensitive, so this is a breaking change.

## paramAddedWithoutDefaultValue

if any parameter is added without a default value or nullable case.

``` bicep
// this will trigger the test
param myParam string

// this will not trigger the test
param myParam string = 'myValue'
param myParam string?
```

adding a parameter without a default value is usually a breaking change, as it will require the user to add a value to continue using the module.

## paramRemoved

if any parameter is removed.

``` bicep
// baseline
param myParam string

// this will trigger the test
// param removed
param myParams string

// this will not trigger the test
param MyParam string
param myParam string?
```

removing a parameter is a breaking change, as it will require the user to remove the parameter from their module.

## paramTypeModified

if the type of any parameter is changed.

``` bicep
// baseline
param myParam string

// this will trigger the test
// param removed
param myParam int

// this will not trigger the test
param myParam string?
```

changing the type of a parameter is a breaking change, as it will require the user to change the type of the parameter in their implementaion.

## paramAllowedValueModified

if the allowed values of any parameter is changed.

changing the allowed values of a parameter is a potential breaking change, as it may require the user to change input values in their implementation.

## paramDefaultValueModified

if the default value of any parameter is changed.

changing the default value of a parameter is not a breaking change, as it will still work, but it may influence the deployment.

## resourceAdded

if any resource is added.

adding a resource is not a breaking change, as it will still work, but it may influence the deployment.

## resourceRemoved

if any resource is removed.

removing a resource is not a breaking change, as it will still work, but it may influence the deployment.

## resourceApiVersionModified

if the api version of any resource is changed.

changing the api version of a resource is not a breaking change, as it will still work, but it may influence the deployment.

## resourcePropertiesAdded

if any properties are added to any resource.

adding properties to a resource is not a breaking change, as it will still work, but it may influence the deployment.

## resourcePropertiesRemoved

if any properties are removed from any resource.

removing properties from a resource is not a breaking change, as it will still work, but it may influence the deployment.

## resourcePropertiesModified

if any properties are modified on any resource.

modifying properties on a resource is not a breaking change, as it will still work, but it may influence the deployment.

## outputsAdded

if any outputs are added.

adding outputs might be a breaking change, depending on your workflow. do you use alot of outputs in your implementaions?

## outputsRemoved

if any outputs are removed.

removing outputs might be a breaking change, depending on your workflow. do you use alot of outputs in your implementaions?

## outputsModified

if any outputs are modified.

modifying outputs might be a breaking change, depending on your workflow. do you use alot of outputs in your implementaions?

## moduleModified

if the module is modified.

checks the acr hash against the local template hash. if they are different, it will trigger this test.

this is a catch all test. if you dont want to use any of the other tests, you can use this one. it will trigger on any change to the module