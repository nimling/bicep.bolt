# Changes coming

Im in the middle of combining 2 projects into one. I will be updating this readme with the new changes soon. 

The biggest change:
BOLT is not just a bicep publishing tool. Its a full fledged deplopyment tool!

I have taken my other project "badu" and deciced that these needs to be combined.

bolt (the publishing tool) will now be "bolt publish"
badu (the deployment tool) will now be "bolt deploy"

they will both be rewritten in GO for better performance and to make it easier to use.

"deploy" is a honestly new and refreshing way to handle deployments. It uses bicep language, but you dont have to write huge files per deployment anymore! you have to put the files in the correct folder, run "deploy {yourenvironment}" and it will deploy the files in the correct order!

read the [deploy docs](./deploy/docs/readme.md) for more info.