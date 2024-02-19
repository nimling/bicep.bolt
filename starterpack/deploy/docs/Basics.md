# The basics

Normally when you deploy bicep you write it all as one big file. this way you can handle all the resources in one go.
For any larger uses this cna get tedious and hard to maintain. This is where bolt comes in.

Bolt is a tool that will help you to split up the deployment into many chunks and deploy them in the correct order.
this means that you can have a file specifically for "storage" related deployments and one for "keyvault" and have them run in the order YOU want.


