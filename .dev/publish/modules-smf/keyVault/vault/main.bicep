param name string
param location string = resourceGroup().location

@description('Tags for resource')
param tags object = resourceGroup().tags

@description('make keys/secrets/certs persist in a recoverable state for x days after deleting, if set to anything below 7, it will disable soft delete')
@minValue(0)
@maxValue(90)
param softDeleteDays int = 7

@allowed([
  'rbac'
  'accessPolicy'
])
param authType string = 'rbac'

@description('Property to specify whether Azure Virtual Machines are permitted to retrieve certificates stored as secrets from the key vault.')
param enabledForVirtualMachineCertificateAccess bool = false

@description('Property to specify whether Azure Resource Manager is permitted to retrieve secrets from the key vault.')
param enabledForArmDeploymentSecrets bool = false

@description('Property to specify whether Azure Disk Encryption is permitted to retrieve secrets from the vault and unwrap keys.')
param enabledForDiskEncryption bool = false

@description('Optional. Specifies the SKU for the vault.Defaults to standard')
@allowed([
  'premium'
  'standard'
])
param vaultSku string = 'standard'

@description('Optional. Service endpoint object information. For security reasons, it is recommended to set the DefaultAction Deny.')
param networkAcls object = {}

@description('Optional. Whether or not public network access is allowed for this resource. For security reasons it should be disabled. If not specified, it will be disabled by default if private endpoints are set and networkAcls are not set.')
@allowed([
  ''
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = ''

@description('Optional. Configuration details for private endpoints. For security reasons, it is recommended to use private endpoints whenever possible.')
param privateEndpoints array = []

var _enableSoftDelete = softDeleteDays >= 7

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    sku: {
      name: vaultSku
      family: 'A'
    }
    tenantId: tenant().tenantId
    enableRbacAuthorization: authType == 'rbac'
    softDeleteRetentionInDays: _enableSoftDelete? softDeleteDays:0
    enableSoftDelete: _enableSoftDelete
    enabledForDeployment : enabledForVirtualMachineCertificateAccess
    enabledForTemplateDeployment: enabledForArmDeploymentSecrets
    enabledForDiskEncryption: enabledForDiskEncryption
    networkAcls: !empty(networkAcls) ? {
      bypass: contains(networkAcls, 'bypass') ? networkAcls.bypass : null
      defaultAction: contains(networkAcls, 'defaultAction') ? networkAcls.defaultAction : null
      virtualNetworkRules: contains(networkAcls, 'virtualNetworkRules') ? networkAcls.virtualNetworkRules : []
      ipRules: contains(networkAcls, 'ipRules') ? networkAcls.ipRules : []
    } : null
    publicNetworkAccess: !empty(publicNetworkAccess) ? any(publicNetworkAccess) : (!empty(privateEndpoints) && empty(networkAcls) ? 'Disabled' : null)
  }
}



// =========== //
// Outputs     //
// =========== //
@description('The resource ID of the key vault.')
output id string = keyVault.id

@description('The name of the resource group the key vault was created in.')
output resourceGroupName string = resourceGroup().name

@description('The name of the key vault.')
output name string = keyVault.name

@description('The URI of the key vault.')
output uri string = keyVault.properties.vaultUri

@description('The location the resource was deployed into.')
output location string = keyVault.location
