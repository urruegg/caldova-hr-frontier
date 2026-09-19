targetScope = 'resourceGroup'

@description('Reviewed Log Analytics workspace name for the tenant baseline.')
param workspaceName string

@description('Primary Azure region for the workspace.')
param location string

@description('Non-secret metadata tags for the workspace.')
param tags object

resource workspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: workspaceName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

output workspaceResourceId string = workspace.id
