targetScope = 'subscription'

type policyAssignmentConfiguration = {
  name: string
  definitionId: string
  displayName: string
  parameters: object
}

type tenantConfiguration = {
  tenantAlias: string
  location: string
  namingRoot: string
  platformResourceGroupName: string
  logAnalyticsWorkspaceName: string
  validationRoleName: string
  validationPrincipalId: string
  policyAssignments: policyAssignmentConfiguration[]
}

@description('Reviewed non-secret tenant subscription baseline configuration.')
param tenant tenantConfiguration

var standardTags = {
  tenantAlias: tenant.tenantAlias
  namingRoot: tenant.namingRoot
  baseline: 'subscription-platform'
}

module platformResourceGroup 'modules/resource-group.bicep' = {
  params: {
    resourceGroupName: tenant.platformResourceGroupName
    location: tenant.location
    tags: standardTags
  }
}

module logAnalyticsWorkspace 'modules/log-analytics-workspace.bicep' = {
  scope: resourceGroup(tenant.platformResourceGroupName)
  params: {
    workspaceName: tenant.logAnalyticsWorkspaceName
    location: tenant.location
    tags: standardTags
  }
  dependsOn: [
    platformResourceGroup
  ]
}

module activityLogDiagnostics 'modules/activity-log-diagnostics.bicep' = {
  params: {
    diagnosticSettingsName: 'activity-log-to-log-analytics'
    workspaceResourceId: logAnalyticsWorkspace.outputs.workspaceResourceId
  }
}

module validationRole 'modules/validation-role.bicep' = {
  params: {
    roleName: tenant.validationRoleName
    principalId: tenant.validationPrincipalId
  }
}

module subscriptionPolicyAssignments 'modules/subscription-policy-assignments.bicep' = {
  params: {
    policyAssignments: tenant.policyAssignments
  }
}

output platformResourceGroupName string = platformResourceGroup.outputs.resourceGroupName
output platformResourceGroupId string = platformResourceGroup.outputs.resourceGroupId
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.outputs.workspaceResourceId
output validationRoleDefinitionId string = validationRole.outputs.roleDefinitionResourceId
output validationRoleAssignmentId string = validationRole.outputs.roleAssignmentResourceId
