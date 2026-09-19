Set-StrictMode -Version Latest

Describe 'Task 6 what-if boundary validation' {
    BeforeAll {
        $script:RepositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
        $script:ValidatorScriptPath = Join-Path $script:RepositoryRoot 'infra\src\scripts\Test-WhatIfBoundary.ps1'
        $script:FixtureRoot = Join-Path $script:RepositoryRoot 'infra\tests\fixtures\what-if'
        $script:AllowedFixturePath = Join-Path $script:FixtureRoot 'allowed.json'
        $script:UnexpectedTypeFixturePath = Join-Path $script:FixtureRoot 'unexpected-type.json'
        $script:WrongScopeFixturePath = Join-Path $script:FixtureRoot 'wrong-scope.json'
        $script:ExpectedPrincipalObjectId = '55555555-5555-5555-5555-555555555555'

        function script:New-TempJsonFile {
            param([Parameter(Mandatory)][string]$Json)

            $path = Join-Path $TestDrive ([guid]::NewGuid().ToString() + '.json')
            [System.IO.File]::WriteAllText($path, $Json, [System.Text.UTF8Encoding]::new($false))
            $path
        }

        function script:Read-AllowedPayload {
          Get-Content -Raw -LiteralPath $script:AllowedFixturePath | ConvertFrom-Json
        }

        function script:Copy-JsonValue {
          param([Parameter(Mandatory)][object]$Value)

          $Value | ConvertTo-Json -Depth 32 | ConvertFrom-Json
        }

        function script:Write-TempPayload {
          param([Parameter(Mandatory)][object]$Payload)

          New-TempJsonFile -Json ($Payload | ConvertTo-Json -Depth 32)
        }
    }

    It 'defines the boundary validator surface before implementation' {
        @(
            $script:ValidatorScriptPath,
            $script:AllowedFixturePath,
            $script:UnexpectedTypeFixturePath,
            $script:WrongScopeFixturePath
        ) | ForEach-Object {
            Test-Path -LiteralPath $_ | Should -BeTrue
        }
    }

    It 'allows only the approved Tenant 1 what-if payload' {
        { & $script:ValidatorScriptPath -WhatIfPayloadPath $script:AllowedFixturePath -ExpectedPrincipalObjectId $script:ExpectedPrincipalObjectId } | Should -Not -Throw
    }

    It 'rejects a missing top-level status even when every resource is exact' {
      $payload = Read-AllowedPayload
      $payload.PSObject.Properties.Remove('status')
      $path = Write-TempPayload -Payload $payload

      {
        & $script:ValidatorScriptPath -WhatIfPayloadPath $path -ExpectedPrincipalObjectId $script:ExpectedPrincipalObjectId
      } | Should -Throw '*status*Succeeded*'
    }

    It 'rejects a failed top-level status even when every resource is exact' {
      $payload = Read-AllowedPayload
      $payload.status = 'Failed'
      $path = Write-TempPayload -Payload $payload

      {
        & $script:ValidatorScriptPath -WhatIfPayloadPath $path -ExpectedPrincipalObjectId $script:ExpectedPrincipalObjectId
      } | Should -Throw '*status*Succeeded*'
    }

    It 'rejects a top-level error even when status is Succeeded' {
      $payload = Read-AllowedPayload
      $payload | Add-Member -MemberType NoteProperty -Name error -Value ([pscustomobject]@{
        code = 'DeploymentWhatIfFailed'
        message = 'The what-if operation did not complete cleanly.'
      })
      $path = Write-TempPayload -Payload $payload

      {
        & $script:ValidatorScriptPath -WhatIfPayloadPath $path -ExpectedPrincipalObjectId $script:ExpectedPrincipalObjectId
      } | Should -Throw '*top-level error*'
    }

    It 'rejects an empty changes array' {
      $payload = Read-AllowedPayload
      $payload.properties.changes = @()
      $path = Write-TempPayload -Payload $payload

      {
        & $script:ValidatorScriptPath -WhatIfPayloadPath $path -ExpectedPrincipalObjectId $script:ExpectedPrincipalObjectId
      } | Should -Throw '*at least one change*'
    }

    It 'rejects a non-array changes value' {
      $payload = Read-AllowedPayload
      $payload.properties.changes = $payload.properties.changes[0]
      $path = Write-TempPayload -Payload $payload

      {
        & $script:ValidatorScriptPath -WhatIfPayloadPath $path -ExpectedPrincipalObjectId $script:ExpectedPrincipalObjectId
      } | Should -Throw '*changes must be an array*'
    }

    It 'rejects malformed change entries before resource evaluation' {
      $payload = Read-AllowedPayload
      $payload.properties.changes[0] = 'malformed-change-entry'
      $path = Write-TempPayload -Payload $payload

      {
        & $script:ValidatorScriptPath -WhatIfPayloadPath $path -ExpectedPrincipalObjectId $script:ExpectedPrincipalObjectId
      } | Should -Throw '*Change entry 0 must be an object*'
    }

    It 'rejects Create changes with a non-null before payload' {
      $payload = Read-AllowedPayload
      $payload.properties.changes[0].before = Copy-JsonValue -Value $payload.properties.changes[0].after
      $path = Write-TempPayload -Payload $payload

      {
        & $script:ValidatorScriptPath -WhatIfPayloadPath $path -ExpectedPrincipalObjectId $script:ExpectedPrincipalObjectId
      } | Should -Throw '*Create*before must be null*'
    }

    It 'rejects Modify changes without an object before payload' {
      $payload = Read-AllowedPayload
      $payload.properties.changes[0].changeType = 'Modify'
      $path = Write-TempPayload -Payload $payload

      {
        & $script:ValidatorScriptPath -WhatIfPayloadPath $path -ExpectedPrincipalObjectId $script:ExpectedPrincipalObjectId
      } | Should -Throw '*Modify*before must be an object*'
    }

    It 'rejects NoChange changes without an object before payload' {
      $payload = Read-AllowedPayload
      $payload.properties.changes[0].changeType = 'NoChange'
      $path = Write-TempPayload -Payload $payload

      {
        & $script:ValidatorScriptPath -WhatIfPayloadPath $path -ExpectedPrincipalObjectId $script:ExpectedPrincipalObjectId
      } | Should -Throw '*NoChange*before must be an object*'
    }

    It 'rejects accepted changes without an object after payload' {
      $payload = Read-AllowedPayload
      $payload.properties.changes[0].changeType = 'Modify'
      $payload.properties.changes[0].before = Copy-JsonValue -Value $payload.properties.changes[0].after
      $payload.properties.changes[0].after = $null
      $path = Write-TempPayload -Payload $payload

      {
        & $script:ValidatorScriptPath -WhatIfPayloadPath $path -ExpectedPrincipalObjectId $script:ExpectedPrincipalObjectId
      } | Should -Throw '*Modify*after must be an object*'
    }

    It 'accepts complete resource payloads for every supported change type' {
      foreach ($changeType in @('Create', 'Modify', 'NoChange')) {
        $payload = Read-AllowedPayload
        foreach ($change in @($payload.properties.changes)) {
          $change.changeType = $changeType
          $change.before = if ($changeType -eq 'Create') {
            $null
          }
          else {
            Copy-JsonValue -Value $change.after
          }
        }
        $path = Write-TempPayload -Payload $payload

        {
          & $script:ValidatorScriptPath -WhatIfPayloadPath $path -ExpectedPrincipalObjectId $script:ExpectedPrincipalObjectId | Out-Null
        } | Should -Not -Throw
      }
    }

    It 'rejects duplicate resource IDs' {
      $payload = Read-AllowedPayload
      $duplicate = Copy-JsonValue -Value $payload.properties.changes[0]
      $payload.properties.changes = @($payload.properties.changes) + @($duplicate)
      $path = Write-TempPayload -Payload $payload

      {
        & $script:ValidatorScriptPath -WhatIfPayloadPath $path -ExpectedPrincipalObjectId $script:ExpectedPrincipalObjectId
      } | Should -Throw '*Duplicate resourceId*/resourceGroups/rg-cal-hr-agentic-bc8rbt-platform*'
    }

    It 'rejects wrong resource IDs and resource name disagreements' {
      $payload = Read-AllowedPayload
      $wrongResourceGroupId = '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/resourceGroups/rg-cal-hr-agentic-wrong'
      $wrongWorkspaceId = '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/resourceGroups/rg-cal-hr-agentic-bc8rbt-platform/providers/Microsoft.OperationalInsights/workspaces/log-cal-hr-agentic-wrong'
      $payload.properties.changes[0].resourceId = $wrongResourceGroupId
      $payload.properties.changes[0].after.id = $wrongResourceGroupId
      $payload.properties.changes[0].after.name = 'rg-cal-hr-agentic-wrong'
      $payload.properties.changes[1].resourceId = $wrongWorkspaceId
      $payload.properties.changes[1].after.id = $wrongWorkspaceId
      $path = Write-TempPayload -Payload $payload

      {
        & $script:ValidatorScriptPath -WhatIfPayloadPath $path -ExpectedPrincipalObjectId $script:ExpectedPrincipalObjectId
      } | Should -Throw '*rg-cal-hr-agentic-wrong*log-cal-hr-agentic-wrong*'
    }

    It 'rejects diagnostic setting name and workspace target drift' {
      $payload = Read-AllowedPayload
      $payload.properties.changes[2].after.name = 'activity-log-wrong'
      $payload.properties.changes[2].after.properties.workspaceId = '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/resourceGroups/rg-cal-hr-agentic-bc8rbt-platform/providers/Microsoft.OperationalInsights/workspaces/log-cal-hr-agentic-wrong'
      $path = Write-TempPayload -Payload $payload

      {
        & $script:ValidatorScriptPath -WhatIfPayloadPath $path -ExpectedPrincipalObjectId $script:ExpectedPrincipalObjectId
      } | Should -Throw '*activity-log-wrong*workspaceId*log-cal-hr-agentic-wrong*'
    }

    It 'rejects drift in every resource relevant property contract' {
      $payload = Read-AllowedPayload
      $payload.properties.changes[0].after.tags.baseline = 'wrong-baseline'
      $payload.properties.changes[1].after.properties.retentionInDays = 31
      $payload.properties.changes[2].after.properties.logs[0].categoryGroup = 'audit'
      $payload.properties.changes[3].after.properties.description = 'Wrong role description.'
      $path = Write-TempPayload -Payload $payload

      {
        & $script:ValidatorScriptPath -WhatIfPayloadPath $path -ExpectedPrincipalObjectId $script:ExpectedPrincipalObjectId
      } | Should -Throw '*resourceGroups/rg-cal-hr-agentic-bc8rbt-platform*workspaces/log-cal-hr-agentic-bc8rbt*diagnosticSettings/activity-log-to-log-analytics*roleDefinitions/9535bca5-5fef-5443-acf9-c0e0486562fd*'
    }

    It 'reports resource id type scope and location for each exact-resource offense' {
      $payload = Read-AllowedPayload
      $workspaceId = [string]$payload.properties.changes[1].resourceId
      $resourceGroupId = [string]$payload.properties.changes[0].resourceId
      $payload.properties.changes[1].after.properties.retentionInDays = 31
      $path = Write-TempPayload -Payload $payload

      {
        & $script:ValidatorScriptPath -WhatIfPayloadPath $path -ExpectedPrincipalObjectId $script:ExpectedPrincipalObjectId
      } | Should -Throw ("*id={0}*type=Microsoft.OperationalInsights/workspaces*scope={1}*location=switzerlandnorth*" -f $workspaceId, $resourceGroupId)
    }

    It 'rejects unsupported resource types with named offending resources' {
        {
            & $script:ValidatorScriptPath -WhatIfPayloadPath $script:UnexpectedTypeFixturePath -ExpectedPrincipalObjectId $script:ExpectedPrincipalObjectId
        } | Should -Throw '*Microsoft.Storage/storageAccounts*/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/resourceGroups/rg-cal-hr-agentic-bc8rbt-platform/providers/Microsoft.Storage/storageAccounts/stcalhragenticbc8rbt*'
    }

    It 'rejects foreign scopes with named offending resources' {
        {
            & $script:ValidatorScriptPath -WhatIfPayloadPath $script:WrongScopeFixturePath -ExpectedPrincipalObjectId $script:ExpectedPrincipalObjectId
        } | Should -Throw '*/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-foreign*'
    }

    It 'rejects deletes ignores and diagnostics that are not fully resolved' {
        $payload = Read-AllowedPayload
        $payload.status = 'Failed'
        $payload.properties.changes[1].changeType = 'Delete'
        $payload.properties.changes[1].before = Copy-JsonValue -Value $payload.properties.changes[1].after
        $payload.properties.changes[1].after = $null
        $payload.properties.changes[2].changeType = 'Ignore'
        $payload.properties.diagnostics = @(
            [pscustomobject]@{
                level = 'Error'
                message = 'Unresolved what-if problem.'
            }
        )
        $path = Write-TempPayload -Payload $payload

        {
            & $script:ValidatorScriptPath -WhatIfPayloadPath $path -ExpectedPrincipalObjectId $script:ExpectedPrincipalObjectId
        } | Should -Throw '*Delete*/providers/Microsoft.OperationalInsights/workspaces/log-cal-hr-agentic-bc8rbt*Ignore*/providers/Microsoft.Insights/diagnosticSettings/activity-log-to-log-analytics*Error*'
    }

    It 'rejects unsupported locations policy assignment changes and malformed payload shape' {
        $badLocationPath = New-TempJsonFile -Json @'
{
  "status": "Succeeded",
  "properties": {
    "changes": [
      {
        "resourceId": "/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/providers/Microsoft.Authorization/policyAssignments/44444444-4444-4444-4444-444444444444",
        "changeType": "Create",
        "before": null,
        "after": {
          "apiVersion": "2022-06-01",
          "id": "/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/providers/Microsoft.Authorization/policyAssignments/44444444-4444-4444-4444-444444444444",
          "type": "Microsoft.Authorization/policyAssignments",
          "name": "44444444-4444-4444-4444-444444444444",
          "location": "westeurope",
          "properties": {
            "displayName": "Unexpected policy assignment",
            "policyDefinitionId": "/providers/Microsoft.Authorization/policyDefinitions/55555555-5555-5555-5555-555555555555"
          }
        }
      }
    ],
    "diagnostics": []
  }
}
'@
        {
            & $script:ValidatorScriptPath -WhatIfPayloadPath $badLocationPath -ExpectedPrincipalObjectId $script:ExpectedPrincipalObjectId
        } | Should -Throw '*policyAssignments*44444444-4444-4444-4444-444444444444*westeurope*'

        $malformedPath = New-TempJsonFile -Json '{"status":"Succeeded","properties":{}}'
        {
            & $script:ValidatorScriptPath -WhatIfPayloadPath $malformedPath -ExpectedPrincipalObjectId $script:ExpectedPrincipalObjectId
        } | Should -Throw '*changes*'

        $nonObjectPropertiesPath = New-TempJsonFile -Json '{"status":"Succeeded","properties":[]}'
        {
            & $script:ValidatorScriptPath -WhatIfPayloadPath $nonObjectPropertiesPath -ExpectedPrincipalObjectId $script:ExpectedPrincipalObjectId
        } | Should -Throw '*properties must be an object*'
    }

    It 'rejects deterministic authorization drift in role definition and role assignment resources' {
        $payload = Read-AllowedPayload
        $wrongRoleDefinitionId = '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/providers/Microsoft.Authorization/roleDefinitions/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
        $wrongRoleAssignmentId = '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/providers/Microsoft.Authorization/roleAssignments/bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
        $payload.properties.changes[3].resourceId = $wrongRoleDefinitionId
        $payload.properties.changes[3].after.id = $wrongRoleDefinitionId
        $payload.properties.changes[3].after.name = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
        $payload.properties.changes[3].after.properties.permissions[0].actions = @('*/read')
        $payload.properties.changes[3].after.properties.assignableScopes = @('/subscriptions/00000000-0000-0000-0000-000000000000')
        $payload.properties.changes[4].resourceId = $wrongRoleAssignmentId
        $payload.properties.changes[4].after.id = $wrongRoleAssignmentId
        $payload.properties.changes[4].after.name = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
        $payload.properties.changes[4].after.properties.roleDefinitionId = $wrongRoleDefinitionId
        $payload.properties.changes[4].after.properties.principalId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
        $payload.properties.changes[4].after.properties.principalType = 'User'
        $path = Write-TempPayload -Payload $payload

        {
            & $script:ValidatorScriptPath -WhatIfPayloadPath $path -ExpectedPrincipalObjectId $script:ExpectedPrincipalObjectId
        } | Should -Throw '*roleDefinitions/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa*roleAssignments/bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb*'
    }

    It 'rejects warning diagnostics and unknown change types' {
        $payload = Read-AllowedPayload
        $payload.properties.changes[1].changeType = 'Unsupported'
        $payload.properties.changes[1].before = Copy-JsonValue -Value $payload.properties.changes[1].after
        $payload.properties.diagnostics = @(
            [pscustomobject]@{
                level = 'Warning'
                message = 'Preview warning should fail the gate.'
            }
        )
        $path = Write-TempPayload -Payload $payload

        {
            & $script:ValidatorScriptPath -WhatIfPayloadPath $path -ExpectedPrincipalObjectId $script:ExpectedPrincipalObjectId
        } | Should -Throw '*Unsupported*Warning*'
    }
}