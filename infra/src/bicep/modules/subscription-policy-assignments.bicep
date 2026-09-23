targetScope = 'subscription'

type policyAssignmentConfiguration = {
  name: string
  definitionId: string
  displayName: string
  parameters: object
}

@description('Reviewed subscription policy assignments for the tenant baseline.')
param policyAssignments policyAssignmentConfiguration[] = []

resource assignments 'Microsoft.Authorization/policyAssignments@2024-04-01' = [
  for assignment in policyAssignments: {
    name: assignment.name
    properties: {
      displayName: assignment.displayName
      policyDefinitionId: assignment.definitionId
      parameters: assignment.parameters
    }
  }
]

output assignmentNames array = [for assignment in policyAssignments: assignment.name]
