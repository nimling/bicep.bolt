enum deploymentScope{
    Subscription
    ResourceGroup
    ManagementGroup
    Tenant
}

class deploymentScopeInfo{
    [string]$Name
    [string]$Id
    [deploymentScope]$Scope
    [string[]]$Parents #array of parent scope ids
}

class deploymentItem{
    [deploymentScope]$deployScope #mg, rg, sub, tenant
    [string]$id
    [string]$name
    # [string]$scopeName #subscriptions/{id}
    [string]$filePath
    [string]$parameterFilePath
    [string]$basename
    [string]$environment
    [string]$type
}
<#
    scope = subscription
    id = subscription id
    name = subscription name
    filePath = path to the deployment file
    parameterFilePath = path to the parameter file
    basename = name of the deployment file
    environment = environment name
    type = deployment type (arm, bicep)
#>

