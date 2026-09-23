targetScope = 'subscription'

@description('Deterministic diagnostic settings name for the subscription Activity Log.')
param diagnosticSettingsName string

@description('Destination Log Analytics workspace resource identifier.')
param workspaceResourceId string

resource activityLogDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: diagnosticSettingsName
  properties: {
    workspaceId: workspaceResourceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
  }
}

output diagnosticSettingsResourceId string = activityLogDiagnostics.id
