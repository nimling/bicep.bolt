

@description('Name of Key vault to add access policy to')
param keyVaultName string 

@description('ObjectId of identity which is to be granted permission')
param objectId string

@description('Id of tenant. Defaults to tenant of deployment')
param tenantId string = subscription().tenantId

@description('Array of secret permissions')
param secretPermission array = ['get']

@description('Array of key permissions')
param keyPermission array = []

@description('Array of secret permissions')
param certificatePermission array = []

@allowed([
  'add'
  'remove'
  'replace'
])
@description('Policy action.')
param policyAction string

var _kvPolicyName= '${keyVaultName}/${policyAction}'


resource keyVaultPolicies 'Microsoft.KeyVault/vaults/accessPolicies@2022-11-01' = {
  name: _kvPolicyName
  properties: {    
    accessPolicies: [
      {
        objectId: objectId
        permissions: {
          secrets: secretPermission
          keys: keyPermission
          certificates: certificatePermission
        }
        tenantId: tenantId
      }
    ]
  }
}  
