// HCDD 412 Week 7 - Linux App Service web app + Azure AI Language (sentiment PoC)
// Preview: az deployment group what-if -g rg-hcdd412-w7 -f main.bicep -p appName=<yourid>
// Deploy:  az deployment group create  -g rg-hcdd412-w7 -f main.bicep -p appName=<yourid>

@description('Short identifier used in resource names (letters and numbers only).')
@minLength(3)
@maxLength(12)
param appName string

@description('Deployment environment.')
@allowed([
  'dev'
  'staging'
  'prod'
])
param env string = 'dev'

@description('Azure region. Defaults to the resource group location.')
param location string = resourceGroup().location

@description('App Service plan SKU. F1 is free; B1 is the cheapest paid tier.')
@allowed([
  'F1'
  'B1'
])
param planSku string = 'F1'

@description('Azure AI Language SKU. F0 is free (one per subscription); S is pay-per-call.')
@allowed([
  'F0'
  'S'
])
param languageSku string = 'F0'

// Web app names and AI subdomains are globally unique DNS names, so append a
// deterministic 5-char suffix derived from the resource group ID.
var name = toLower(appName)
var suffix = take(uniqueString(resourceGroup().id), 5)
var tags = {
  course: 'hcdd412'
  assignment: 'w7-iac'
  env: env
}

// Linux App Service plan. "reserved: true" is what actually makes the plan Linux.
resource plan 'Microsoft.Web/serverfarms@2025-03-01' = {
  name: 'plan-${name}-${env}'
  location: location
  tags: tags
  kind: 'linux'
  sku: {
    name: planSku
  }
  properties: {
    reserved: true
  }
}

// Web app on the plan. HTTPS only, TLS 1.2 minimum, FTP disabled.
// No app settings, keys or connection strings live in this file.
resource app 'Microsoft.Web/sites@2025-03-01' = {
  name: 'app-${name}-${env}-${suffix}'
  location: location
  tags: tags
  kind: 'app,linux'
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'PYTHON|3.12'
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      alwaysOn: false // F1 does not support Always On
    }
  }
}

// Azure AI Language (resource kind "TextAnalytics") for the sentiment-analysis call.
resource lang 'Microsoft.CognitiveServices/accounts@2025-06-01' = {
  name: 'lang-${name}-${env}-${suffix}'
  location: location
  tags: tags
  kind: 'TextAnalytics'
  sku: {
    name: languageSku
  }
  properties: {
    customSubDomainName: 'lang-${name}-${env}-${suffix}'
    publicNetworkAccess: 'Enabled'
  }
}

output webAppName string = app.name
output webAppUrl string = 'https://${app.properties.defaultHostName}'
output languageAccountName string = lang.name
output languageEndpoint string = lang.properties.endpoint
// Keys are deliberately not output: deployment outputs are stored in plain text
// in the resource group's deployment history.
