targetScope = 'subscription'

@description('Reviewed custom deployment validation role name.')
param roleName string

@description('Service principal object identifier that receives the validation role assignment.')
param principalId string

var roleDefinitionGuid = guid(subscription().id, roleName)
var roleAssignmentGuid = guid(subscription().id, roleDefinitionGuid, principalId)

resource deploymentValidationRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: roleDefinitionGuid
  properties: {
    roleName: roleName
    description: 'Read-only deployment validation role for reviewed tenant subscription baselines.'
    type: 'CustomRole'
    permissions: [
      {
        actions: [
          '*/read'
          'Microsoft.Resources/deployments/read'
          'Microsoft.Resources/deployments/validate/action'
          'Microsoft.Resources/deployments/whatIf/action'
        ]
        notActions: []
        dataActions: []
        notDataActions: []
      }
    ]
    assignableScopes: [
      subscription().id
    ]
  }
}

resource deploymentValidationAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: roleAssignmentGuid
  properties: {
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: deploymentValidationRole.id
  }
}

output roleDefinitionResourceId string = deploymentValidationRole.id
output roleAssignmentResourceId string = deploymentValidationAssignment.id
