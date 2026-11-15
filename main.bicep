@description('Environment name: dev or prod')
param env string = 'dev'
param location string = resourceGroup().location
param ownerTag string = 'your-name'

var unique = uniqueString(resourceGroup().id)
var tags = {
  project: 'cakeshop'
  env: env
  owner: ownerTag
  costcenter: 'bakery'
}
var blobReaderRoleId = '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1' // Storage Blob Data Reader

resource log 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'log-cakeshop-${env}'
  location: location
  tags: tags
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
  }
}

resource appi 'Microsoft.Insights/components@2020-02-02' = {
  name: 'appi-cakeshop-${env}'
  location: location
  kind: 'web'
  tags: tags
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: log.id
  }
}

resource sa 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: 'stcake${env}${unique}'
  location: location
  tags: tags
  kind: 'StorageV2'
  sku: { name: 'Standard_LRS' }
  properties: {
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

resource plan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: 'plan-cakeshop-${env}'
  location: location
  tags: tags
  kind: 'linux'
  sku: { name: 'B1' }
  properties: { reserved: true }
}

resource web 'Microsoft.Web/sites@2023-12-01' = {
  name: 'app-cakeshop-${env}-${unique}'
  location: location
  tags: tags
  identity: { type: 'SystemAssigned' }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'PYTHON|3.12'
      appCommandLine: 'gunicorn --bind=0.0.0.0 --timeout 600 app:app'
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      appSettings: [
        { name: 'APP_ENV', value: env }
        { name: 'STORAGE_ACCOUNT', value: sa.name }
        { name: 'SCM_DO_BUILD_DURING_DEPLOYMENT', value: 'true' }
        { name: 'APPLICATIONINSIGHTS_CONNECTION_STRING', value: appi.properties.ConnectionString }
      ]
    }
  }
}

resource blobRead 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(sa.id, web.id, blobReaderRoleId)
  scope: sa
  properties: {
    principalId: web.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', blobReaderRoleId)
  }
}

output webAppName string = web.name
output webAppUrl string = 'https://${web.properties.defaultHostName}'
