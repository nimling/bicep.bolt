class bConfBicep{
    [string]$version
    []
}

class boltConfig{
    hidden [string] $Path
    [string]$tenant
    [bconfBicep]$bicep
    [bconfRemote]$remote
    [bconfDeploy]$deploy
    [bconfPublish]$publish

    boltConfig(){
    }

    validate(){
        Test-Tenant:ConfValidate -Config $this
        $this.bicep.validate()
        $this.remote.validate()
        $this.deploy.validate()
        $this.publish.validate()
    }
}