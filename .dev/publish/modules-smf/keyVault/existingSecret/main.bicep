param ResourceGroup string = resourceGroup().name
param KeyvaultName string
param SecretName string

resource kv 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: KeyvaultName
  scope: resourceGroup(ResourceGroup)

  resource secret 'secrets' existing = {
    name: SecretName
  }
}

var SecretVersion = last(split(kv::secret.properties.secretUriWithVersion,'/'))

output name string = kv::secret.name
output vault string = kv.name
output version string = string(SecretVersion)

//@Microsoft.KeyVault(VaultName=myvault;SecretName=mysecret) option addon: SecretVersion=secretVersion
output ReferenceAsCs string = '@Microsoft.KeyVault(VaultName=${kv.name};SecretName=${kv::secret.name})'
output ReferenceAsCsWithVersion string = '@Microsoft.KeyVault(VaultName=${kv.name};SecretName=${kv::secret.name};SecretVersion=${SecretVersion})'

//@Microsoft.KeyVault(SecretUri=https://myvault.vault.azure.net/secrets/mysecret/)
output ReferenceAsUri string = '@Microsoft.KeyVault(SecretUri=${kv::secret.properties.secretUri})'
output ReferenceAsUriWithVersion string = '@Microsoft.KeyVault(SecretUri=${kv::secret.properties.secretUriWithVersion})'

output SecretUri string = kv::secret.properties.secretUri
output SecretUriWithVersion string = kv::secret.properties.secretUriWithVersion
