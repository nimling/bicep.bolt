param(
    [ValidateSet(
        "Local",
        "starterpack",
        "build"
    )]
    [string]$Type = "local"
)
cd $PSScriptRoot
if($type -like '*Build'){
    if(!(get-module -list psake)){
        throw "psake module not found. install with 'Install-Module psake -Scope CurrentUser'"
    }
    invoke-psake
}

cd "$PSScriptRoot/.dev"
# get-item './../src/main.ps1'
try{
    $arg = @{
        Branch = 'dev'
        whatif = $true
        name = "*"
        Verbose = $true
    }
    $global:boltDev = $true
    switch -wildcard ($Type){
        "starterpack*"{
            & ./../starterpack/bolt.ps1 @arg
        }
        "Local"{
            & ./../src/main.ps1 @arg
        }
    }
    # & ./../src/main.ps1 -Branch dev  -whatif
}
catch{
    write-host "----STACKTRACE:DEV---"
    Write-host $_.ScriptStackTrace -ForegroundColor Red
    write-host "----MESSAGE:DEV---"
    Write-Host $_.Exception.Message -ForegroundColor Red
}
finally{
    cd $PSScriptRoot
    # $global:bolt_dev = $false
}