# interface functions

notice: This is mostly in the beta phase and any changes may not be backwards compatible,

## the problem

i have some parts of bolt that i want to be able to have different codepaths depending on the circumstance of a object. take the environment varialbes: they all are 'variables' but do contain and process information based on what kind of variable they are. normally i would just create a class and then have a bunch of different classes that inherit from that class. but class in powershell are badly implemented so i want to avoid them as much as possible. i can pretty much get away by only using them as "data container" without any methods. but i still want to be able to have different codepaths for different types of variables.  
Normally this could be supported by running some kind of switch statement, but what if you want the user to be able to add cases and extend your code without having to go into the core of your code? well then you have to make your code extensible.

but how do you extend it? you can use the interface functions.

this is a type of pattern that is kind of stolen from GO (or the simplicity of it is. interfaces themselves are not a golang specific thing).
instead of defining a class and then set that class as a parent if your implementation (hence getting methods through inheritance), you define a set of functions that must be implemented in order to be a valid interface.

just a example of how this works. welcome to Go 101:

``` Golang
interface MyInterface {
    Save()
    Update()
}

struct MyStruct {
    name string
}

func (s MyStruct) Save() {
    // do some save thing
}

func (s MyStruct) Update() {
    // do some update thing
}

func main() {
    var myInterface MyInterface
    myInterface = MyStruct{name: "test"}
    myInterface.save()
}
```

to explain the code above:

- we have a interface called `MyInterface` that has two functions: `save` and `update`
- we have a struct called `MyStruct` that implememts `save()` and `update()` (ie `Mystruct.Save()` and `MyStruct.Update()`)
- in main: because `MyStruct` implements the functions defined in `MyInterface` we can assign a `MyStruct` to a `MyInterface` variable.
- this means that when we define `MyInterface` when coding and know that any struct that implements `MyInterface` can be called with the same functions.

## For powershell

For powershell, what would this look like? we certainly cant do the same thing as in Go, but we can do something with the kind of the same idea with some added complexity/magic.
What i mostly want to do is to have a additional layer where i can say something like `invoke-BoltInterface -scope 'deployvariable' -implement 'static' -command 'run'` and have that call the correct function.

I do realise it might be a bit overkill, but i think it would be a nice way to extend bolt. this way i dont have to go into core to add one of many possible ways to do something. i could care only about the interfaced commands, and the config and the rest would be handled by bolt.

this would also make it simpler to add new 'pre-deploy', 'while-deploy', 'post-deploy' checks for deploy, and 'module version checks' + custom 'company module tests' for the module manager.

for this to work i would need:

- scope -> a name for the interface
- implement -> a tag that represents the implementation (under what sircumstances should this be called)
- command -> a command that is defined in the interface. this would be the same for all implementations of the scope

note: just for clarity, im using 'static' and 'keyvault' as examples of what the implement tag could be. the values would represent a static variable and a keyvault reference variable, both would share the same input variables, return no values (atleast in my case)

## How it works

1. define function with a tag that represents the `implement` name. ie `static` -> `Get-Myfunction:static`.
2. define a interface definition scope by name, and take in a scriptblock.
3. in the scriptblock, have a function that can find commands base on a search term and will return a `command` name + `command` function (defined in step 1).
4. a `implement` needs to add all of the definitions in the interface definition scope to be added as a function to the current scope.

## How it would be defined

``` powershell
#in some file..
function New-DeployVariable:static {
    param(
        $myvar
    )
    #code
}
function Invoke-DeployVariable:static {
    param(
        $myvar
    )
    #code
}

#in another file..
function New-DeployVariable:keyvault {
    param(
        $myvar
    )
    #code
}
function Invoke-DeployVariable:keyvault {
    param(
        $myvar
    )
    #code
}


#at start of main script
New-BoltInterface -Name 'deployVar' -definition {
    New-Definition -name 'run' -command 'Invoke-DeployVariable'
    New-Definition -name 'init' -command 'New-DeployVariable'
}
#in order to be part of the interface, the implement needs to add the interface to the current scope. if it only implemented 'Invoke-DeployVariable' it would not be part of the interface
#i could probably also do a check on the parameters to see if they match the interface definition, but not right now
```

## How it would look

a interface named 'deployVar' that has a function called 'init' and 'run' that is implemented by a functions tagged with `static`

``` powershell
$interface = @{
    deployVar = @{
        static = @{
            init = {cmdlet info for New-DeployVariable:static}
            run = {cmdlet info for Invoke-DeployVariable:static}
        }
        keyvault = @{
            init = {cmdlet info for New-DeployVariable:static}
            run = {cmdlet info for Invoke-DeployVariable:static}
        }
    }
}
```

## how it would run

``` powershell	
$someparam = @{
    myvar = 'somevalue'
}
Invoke-BoltInterface -scope 'deployVar' -implement 'static' -command 'run' -params $someparam
```


