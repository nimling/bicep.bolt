param location string = resourceGroup().location
param tags object = resourceGroup().tags

param keyvaultName string
param name string

@secure()
param content string

param contentType string = 'secret'

@description('Id to a identity that have enough access to both read and write secrets to the defined keyvault')
param userAssignedIdentityId string

@description('''
Generates a deploymentscript that contacts keyvault, and adds the defined secret, if it doesnt already exists
''')
resource setSecret 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  kind: 'AzurePowerShell'
  location: location
  tags: tags
  name: 'oneTimeSecret-${keyvaultName}-secret-${name}'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityId}':{}
    }
  }
  properties: {
    forceUpdateTag: name
    azPowerShellVersion: '9.1'
    cleanupPreference: 'Always'
    retentionInterval: 'PT1H'
    arguments: format(' -vaultName {0} -secretName {1}',keyvaultName,name)
    environmentVariables: [
      {
        name: 'content'
        secureValue: content 
      }
      {
        name: 'contentType'
        value: contentType
      }
    ]
    scriptContent: '''
      param(
        [parameter(Mandatory)]
        [string]$vaultName,
        [parameter(Mandatory)]
        [string]$secretName
      )
          
      $DeploymentScriptOutputs = @{}
      $DeploymentScriptOutputs.created = $false
      
      #search for azure resource 
      Write-Host "searching for KeyVault resource $vaultName"
      $param = @{
          Name         = $vaultName
          ResourceType = 'Microsoft.KeyVault/vaults'
      }
      $kvrec = Get-AzResource @param -ErrorAction SilentlyContinue
      if (!$kvrec) {
          throw "Cannot find the KeyKault resource $vaultName within subscription $((get-azcontext).Subscription.Name)"
      }
      
      #get correct object for vault
      $Vault = Get-AzKeyVault -VaultName $kvrec.Name -ResourceGroupName $kvrec.ResourceGroupName
      
      #get all secrets. filter so only the defined one is shown. returns empty if its not found
      Write-Host "Searching keyvault for secret '$secretName'"
      $Secret = $vault | Get-AzKeyVaultSecret | Where-Object { $_.name -eq $secretName } | Select-Object -first 1
      
      if (!$Secret) {
          if (!$env:content) {
              throw "Cannot find any secret to set in keyvault"
          }
      
          $secretValue = $env:content
          $secretType = $env:contentType
          Write-host "Secret not found. Creating.."
          $secret = $vault | Set-AzKeyVaultSecret -SecretValue (ConvertTo-SecureString -AsPlainText -Force -String $secretValue) -ContentType $secretType
          $DeploymentScriptOutputs.created = $true 
      }
      else{
        Write-host "Secret already set"
      }
    '''
  }
}

module ref '../existingSecret/main.bicep' = {
  name: 'kvref'
  params: {
    KeyvaultName: keyvaultName
    SecretName: name
    ResourceGroup: resourceGroup().name
  }
  dependsOn: [
    setSecret
  ]
}

@description('secret name')
output name string = name
@description('keyVault name')
output vault string = keyvaultName
@description('current version of secret')
output version string = ref.outputs.version

//@Microsoft.KeyVault(VaultName=myvault;SecretName=mysecret) option addon: SecretVersion=secretVersion
@description('reference to the secret defined as a connection string')
output ReferenceAsCs string = ref.outputs.ReferenceAsCs
@description('reference to the secret defined as a connection string with versioning')
output ReferenceAsCsWithVersion string = ref.outputs.ReferenceAsCsWithVersion

//@Microsoft.KeyVault(SecretUri=https://myvault.vault.azure.net/secrets/mysecret/)
@description('reference to the secret defined as a url')
output ReferenceAsUri string = ref.outputs.ReferenceAsUri
@description('reference to the secret defined as a url with version')
output ReferenceAsUriWithVersion string = ref.outputs.ReferenceAsUriWithVersion

@description('url to the secret')
output SecretUri string = ref.outputs.SecretUri
@description('url to the secret with version')
output SecretUriWithVersion string = ref.outputs.SecretUriWithVersion
