@description('name of keyvault')
param keyvaultName string

param name string

@description('''
ISO 8601 dateTime or duration: if set, will set expiration for the secret. supports both a duration and a specific time.
Default is never.
''')
param expiration string = ''

@description('''
ISO 8601 dateTime or duration: 
if set, will set 'not before' for the secret. supports both a duration and a specific time.
Default is now.
''')
@minLength(3)
param notBefore string = utcNow('u')

param enabled bool = true

@secure()
param value string

@description('''
  what should the secret be identified as within keyvault? some content types will enable different features in keyvault. 
  optional, but highly recomended
''')
param contentType string = ''

@description('any template selected here will be used instead of param "contentTypes"')
@allowed([
  ''
  'username'
  'password'
  'secret'
  'salt'
  'application/x-pkcs12'
  'connectionString'
])
param contentTypeTemplate string = ''

@description('Dont set. used as a base for figuring out ISO 8601 duration')
param baseTime string  = utcNow()

// var _now  = utcNow('u')
var _exp = empty(expiration)?'':startsWith(toUpper(expiration),'P')?dateTimeAdd(baseTime, expiration):expiration
var _nbf = startsWith(toUpper(notBefore),'P')?dateTimeAdd(baseTime, notBefore):notBefore
output iso string = dateTimeAdd(baseTime, 'P1Y')

var _contentType = empty(contentTypeTemplate)?contentType:contentTypeTemplate

resource kv 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyvaultName
  resource secret 'secrets' = {
    name: name
    properties: {
      attributes: {
        enabled: enabled
        exp: empty(_exp)?null:dateTimeToEpoch(_exp)
        nbf: dateTimeToEpoch(_nbf)
      }

      value: value
      contentType: _contentType
    }
  }
}

resource secret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  name: '${kv::secret.name}-2'
  properties:{
    // value: 'helloo'
    contentType: 'application/x-pkcs12'
  }
  parent: kv
}

var SecretVersion = last(split(kv::secret.properties.secretUriWithVersion,'/'))

output name string = expiration
output vault string = kv.name
output version string = string(SecretVersion)

//@Microsoft.KeyVault(VaultName=myvault;SecretName=mysecret) option addon: SecretVersion=secretVersion
output ReferenceAsCs string = '@Microsoft.KeyVault(VaultName=${kv.name};SecretName=${name})'
output ReferenceAsCsWithVersion string = '@Microsoft.KeyVault(VaultName=${kv.name};SecretName=${name};SecretVersion=${SecretVersion})'

//@Microsoft.KeyVault(SecretUri=https://myvault.vault.azure.net/secrets/mysecret/)
output ReferenceAsUri string = '@Microsoft.KeyVault(SecretUri=${kv::secret.properties.secretUri})'
output ReferenceAsUriWithVersion string = '@Microsoft.KeyVault(SecretUri=${kv::secret.properties.secretUriWithVersion})'

output SecretUri string = kv::secret.properties.secretUri
output SecretUriWithVersion string = kv::secret.properties.secretUriWithVersion

