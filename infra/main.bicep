targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unqiue hash used in all resources.')
param name string

@minLength(1)
@description('Primary location for all resources')
param location string

@description('The image name for the Api service')
param apiImage string = ''

@description('The image name for the UI')
param uiImage string = ''


param  resourceToken string = toLower(uniqueString(subscription().id, name, location))

var appName = 'todo'
var defaultApiImage = 'docker.io/bjd145/simple:97a7dd4338986d13d409c43ebb2c9571f6d5b6ed'
var defaultUiImage = 'docker.io/bjd145/simple-ui:97a7dd4338986d13d409c43ebb2c9571f6d5b6ed'
var sqlPassword =  'strong-Password+${resourceToken}'
var managedIdentityName = 'id-${resourceToken}'
var vaultName = 'kv-${resourceToken}'

resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-${name}-${resourceToken}'
  location: location
  tags: {
    'azd-env-name': name
  }
}

module identity 'identity.bicep' = {
  name: 'identity'
  scope: resourceGroup
  params: {
    managedIdentityName: managedIdentityName
    location: location
  }
}

module registry 'registry.bicep' = {
  name: 'registry'
  scope: resourceGroup
  params: {
    environmentName: name
    resourceToken: resourceToken
    location: location
  }
}

module environment 'environment.bicep' = {
  name: 'container-app-environment'
  scope: resourceGroup
  params: {
    environmentName: name
    caeName: 'env-${resourceToken}'
    resourceToken: resourceToken
    location: location
  }
}

module sql 'postgresql.bicep' = {
  name: 'azure-postgresql'
  scope: resourceGroup
  params: {
    environmentName: name
    sqlName: 'sql-${resourceToken}'
    location: location
    administratorLoginPassword: sqlPassword
  }
}

module keyvault 'keyvault.bicep' = {
  name: 'azure-keyvault'
  scope: resourceGroup
  params: {
    vaultName: vaultName
    location: location
    sqlName: 'sql-${resourceToken}'
    sqlPassword: sqlPassword
    managedIdentityName: managedIdentityName
  }
  dependsOn:[
    sql
    identity
  ]
}

module api 'api.bicep' = {
  name: '${appName}-api'
  scope: resourceGroup
  params: {
    location: location
    environmentName: name
    containerImage: apiImage != '' ? apiImage : defaultApiImage
    resourceToken: resourceToken
    managedIdentityName: managedIdentityName
  }
  dependsOn: [
    environment
    registry
    keyvault
  ]
}

module dapr 'dapr.bicep' = {
  name: '${appName}-dapr'
  scope: resourceGroup
  params: {
    location: location
    environmentName: name
    resourceToken: resourceToken
    managedIdentityName: managedIdentityName
    vaultName: vaultName
  }
  dependsOn: [
    environment
    api
  ]
}

module ui 'ui.bicep' = {
  name: '${appName}-ui'
  scope: resourceGroup
  params: {
    location: location
    environmentName: name
    containerImage: uiImage != '' ? uiImage : defaultUiImage
    containerPort: 8080
    resourceToken: resourceToken
  }
  dependsOn: [
    environment
    registry
    sql
  ]
}

output AZURE_CONTAINER_REGISTRY_ENDPOINT string = registry.outputs.AZURE_CONTAINER_REGISTRY_ENDPOINT
output AZURE_CONTAINER_REGISTRY_NAME string = registry.outputs.AZURE_CONTAINER_REGISTRY_NAME
output APP_API_BASE_URL string = api.outputs.API_URI
output APP_UI_BASE_URL string = ui.outputs.UI_URI
output SQL_NAME string = 'sql-${resourceToken}'
output MANAGED_IDENTITY_NAME string = managedIdentityName
output SQL_PASSWORD string = sqlPassword

