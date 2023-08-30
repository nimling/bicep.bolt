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
```
"paramCaseModified",
"paramAddedWithoutDefaultValue",
"paramRemoved",
"paramTypeModified",
"paramAllowedValueModified",
"paramDefaultValueModified",
"resourceAdded",
"resourceRemoved",
"resourceApiVersionModified",
"resourcePropertiesAdded",
"resourcePropertiesRemoved",
"resourcePropertiesModified",
"outputsAdded",
"outputsRemoved",
"outputsModified",
"moduleModified"
```

