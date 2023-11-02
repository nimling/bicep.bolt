# solutions

this folder is the index of the solutions you want to use. upper case defines a command you want to use in the terminal. lower case is just a folder. the command will be converted to lowercase

```
bolt:
old:
bolt.ps1 {release} {name} -action {action}
new: 
bolt.ps1 publish {release} {name}

badu:
badu.ps1 {env} {name} {dryrun|list}

bolt.ps1 deploy {env} {name} -action {list,dryrun,variableuse,default}
```
bolt publish 