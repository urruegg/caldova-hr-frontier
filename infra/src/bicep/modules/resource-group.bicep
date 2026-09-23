targetScope = 'subscription'

@description('Reviewed platform resource group name for the tenant baseline.')
param resourceGroupName string

@description('Primary Azure region for the tenant baseline resources.')
param location string

@description('Non-secret metadata tags for the tenant baseline resources.')
param tags object

resource platformResourceGroup 'Microsoft.Resources/resourceGroups@2024-11-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

output resourceGroupName string = platformResourceGroup.name
output resourceGroupId string = platformResourceGroup.id
