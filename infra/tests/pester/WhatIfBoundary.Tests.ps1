Set-StrictMode -Version Latest

Describe 'Task 6 what-if boundary validation' {
    BeforeAll {
        $script:RepositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
        $script:SourceValidatorScriptPath = Join-Path $script:RepositoryRoot 'infra\src\scripts\Test-WhatIfBoundary.ps1'
        $script:ValidatorScriptPath = $script:SourceValidatorScriptPath
        $script:FixtureRoot = Join-Path $script:RepositoryRoot 'infra\tests\fixtures\what-if'
        $script:AllowedFixturePath = Join-Path $script:FixtureRoot 'allowed.json'
        $script:UnexpectedTypeFixturePath = Join-Path $script:FixtureRoot 'unexpected-type.json'
        $script:WrongScopeFixturePath = Join-Path $script:FixtureRoot 'wrong-scope.json'
        $script:ExpectedPrincipalObjectId = '55555555-5555-5555-5555-555555555555'
        $script:gitPath = (
          Get-Command git.exe -CommandType Application -ErrorAction Stop |
            Select-Object -First 1
        ).Source

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

        function script:New-DerivedBoundaryFixture {
          param(
            [Parameter(Mandatory)][string]$TenantAlias,
            [Parameter(Mandatory)][string]$RootName
          )

          $root = Join-Path $TestDrive $RootName
          $scriptRoot = Join-Path $root 'infra\src\scripts'
          $moduleParent = Join-Path $scriptRoot 'modules'
          $schemaRoot = Join-Path $root 'infra\src\config\schemas'
          $tenantRoot = Join-Path $root 'infra\src\config\tenants'
          New-Item -ItemType Directory -Path $moduleParent, $schemaRoot, $tenantRoot -Force | Out-Null

          Copy-Item -LiteralPath (
            Join-Path $script:RepositoryRoot 'infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap'
          ) -Destination $moduleParent -Recurse
          Copy-Item -LiteralPath $script:SourceValidatorScriptPath -Destination $scriptRoot
          Copy-Item -LiteralPath (
            Join-Path $script:RepositoryRoot 'infra\src\config\schemas\tenant.schema.json'
          ) -Destination $schemaRoot

          $configuration = Get-Content -Raw -LiteralPath (
            Join-Path $script:RepositoryRoot 'infra\src\config\tenants\_template.psd1'
          )
          $configuration = $configuration.Replace(
            "TenantAlias = 'example123456'",
            "TenantAlias = '$TenantAlias'"
          ).Replace(
            "DisplayName = 'Example123456'",
            "DisplayName = '$TenantAlias'"
          ).Replace(
            "SubscriptionId = '22222222-2222-2222-2222-222222222222'",
            "SubscriptionId = '11111111-1111-1111-1111-111111111111'"
          ).Replace(
            "UniqueSuffix = 'a1b2c3'",
            "UniqueSuffix = 'abc123'"
          ).Replace(
            "CompanyTla = 'exa'",
            "CompanyTla = 'syn'"
          ).Replace(
            "NamingRoot = 'exa-hr-agentic-a1b2c3'",
            "NamingRoot = 'syn-hr-agentic-abc123'"
          ).Replace(
            'bootstrap-example123456',
            "bootstrap-$TenantAlias"
          )
          $tenantPath = Join-Path $tenantRoot 'tenant1.local.psd1'
          [IO.File]::WriteAllText($tenantPath, $configuration, [Text.UTF8Encoding]::new($false))
          [IO.File]::WriteAllText(
            (Join-Path $root '.gitignore'),
            "infra/src/config/tenants/*.local.psd1`n",
            [Text.UTF8Encoding]::new($false)
          )
          & $script:gitPath -C $root init --quiet
          if ($LASTEXITCODE -ne 0) {
            throw 'Cannot initialize the derived-boundary fixture.'
          }

          $compiledParameters = [pscustomobject]@{
            parameters = [pscustomobject]@{
              tenant = [pscustomobject]@{
                value = [pscustomobject]@{
                  tenantAlias = $TenantAlias
                  location = 'switzerlandnorth'
                  namingRoot = 'syn-hr-agentic-abc123'
                  platformResourceGroupName = 'rg-syn-hr-agentic-abc123-platform'
                  logAnalyticsWorkspaceName = 'log-syn-hr-agentic-abc123'
                  policyAssignments = @()
                }
              }
            }
          }
          [pscustomobject]@{
            ValidatorPath = Join-Path $scriptRoot 'Test-WhatIfBoundary.ps1'
            TenantPath = $tenantPath
            CompiledParameters = $compiledParameters
          }
        }

        $script:BoundaryFixture = New-DerivedBoundaryFixture `
          -TenantAlias 'fixturetenant42' `
          -RootName 'default-boundary'
        $script:ValidatorScriptPath = $script:BoundaryFixture.ValidatorPath

        function script:Invoke-TestBoundaryValidator {
          param(
            [Parameter(Mandatory)][string]$WhatIfPayloadPath,
            [Parameter(Mandatory)][string]$ExpectedPrincipalObjectId
          )

          & $script:ValidatorScriptPath `
            -WhatIfPayloadPath $WhatIfPayloadPath `
            -PublicTenantKey tenant1 `
            -TenantConfigurationPath $script:BoundaryFixture.TenantPath `
            -CompiledParameters $script:BoundaryFixture.CompiledParameters
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
        { Invoke-TestBoundaryValidator -WhatIfPayloadPath $script:AllowedFixturePath -ExpectedPrincipalObjectId $script:ExpectedPrincipalObjectId } | Should -Not -Throw
    }

    It 'derives the expected tenant alias from validated local configuration and compiled parameters' {
      $fixture = New-DerivedBoundaryFixture `
        -TenantAlias 'fixturetenant99' `
        -RootName 'alternate-boundary'
      $payload = Read-AllowedPayload
      foreach ($change in @($payload.properties.changes)) {
        if ($change.after.PSObject.Properties.Name -contains 'tags') {
          $change.after.tags.tenantAlias = 'fixturetenant99'
        }
      }
      $payloadPath = Write-TempPayload -Payload $payload

      {
        & $fixture.ValidatorPath `
          -WhatIfPayloadPath $payloadPath `
          -PublicTenantKey tenant1 `
          -TenantConfigurationPath $fixture.TenantPath `
          -CompiledParameters $fixture.CompiledParameters
      } | Should -Not -Throw
    }

    It 'rejects a missing top-level status even when every resource is exact' {
      $payload = Read-AllowedPayload
      $payload.PSObject.Properties.Remove('status')
      $path = Write-TempPayload -Payload $payload

      {
        Invoke-TestBoundaryValidator -WhatIfPayloadPath $path -ExpectedPrincipalObjectId $script:ExpectedPrincipalObjectId
      } | Should -Throw '*status*Succeeded*'
    }

    It 'rejects a failed top-level status even when every resource is exact' {
      $payload = Read-AllowedPayload
      $payload.status = 'Failed'
      $path = Write-TempPayload -Payload $payload

      {
        Invoke-TestBoundaryValidator -WhatIfPayloadPath $path -ExpectedPrincipalObjectId $script:ExpectedPrincipalObjectId
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
        Invoke-TestBoundaryValidator -WhatIfPayloadPath $path -ExpectedPrincipalObjectId $script:ExpectedPrincipalObjectId
      } | Should -Throw '*top-level error*'
    }

    It 'rejects an empty changes array' {
      $payload = Read-AllowedPayload
      $payload.properties.changes = @()
      $path = Write-TempPayload -Payload $payload

      {
        Invoke-TestBoundaryValidator -WhatIfPayloadPath $path -ExpectedPrincipalObjectId $script:ExpectedPrincipalObjectId
      } | Should -Throw '*at least one change*'
    }

    It 'rejects a non-array changes value' {
      $payload = Read-AllowedPayload
      $payload.properties.changes = $payload.properties.changes[0]
      $path = Write-TempPayload -Payload $payload

      {
        Invoke-TestBoundaryValidator -WhatIfPayloadPath $path -ExpectedPrincipalObjectId $script:ExpectedPrincipalObjectId
      } | Should -Throw '*changes must be an array*'
    }

    It 'rejects malformed change entries before resource evaluation' {
      $payload = Read-AllowedPayload
      $payload.properties.changes[0] = 'malformed-change-entry'
      $path = Write-TempPayload -Payload $payload

      {
        Invoke-TestBoundaryValidator -WhatIfPayloadPath $path -ExpectedPrincipalObjectId $script:ExpectedPrincipalObjectId
      } | Should -Throw '*Change entry 0 must be an object*'
    }

    It 'rejects Create changes with a non-null before payload' {
      $payload = Read-AllowedPayload
      $payload.properties.changes[0].before = Copy-JsonValue -Value $payload.properties.changes[0].after
      $path = Write-TempPayload -Payload $payload

      {
        Invoke-TestBoundaryValidator -WhatIfPayloadPath $path -ExpectedPrincipalObjectId $script:ExpectedPrincipalObjectId
      } | Should -Throw '*Create*before must be null*'
    }

    It 'rejects Modify changes without an object before payload' {
      $payload = Read-AllowedPayload
      $payload.properties.changes[0].changeType = 'Modify'
      $path = Write-TempPayload -Payload $payload

      {
        Invoke-TestBoundaryValidator -WhatIfPayloadPath $path -ExpectedPrincipalObjectId $script:ExpectedPrincipalObjectId
      } | Should -Throw '*Modify*before must be an object*'
    }

    It 'rejects NoChange changes without an object before payload' {
      $payload = Read-AllowedPayload
      $payload.properties.changes[0].changeType = 'NoChange'
      $path = Write-TempPayload -Payload $payload

      {
        Invoke-TestBoundaryValidator -WhatIfPayloadPath $path -ExpectedPrincipalObjectId $script:ExpectedPrincipalObjectId
      } | Should -Throw '*NoChange*before must be an object*'
    }

    It 'rejects accepted changes without an object after payload' {
      $payload = Read-AllowedPayload
      $payload.properties.changes[0].changeType = 'Modify'
      $payload.properties.changes[0].before = Copy-JsonValue -Value $payload.properties.changes[0].after
      $payload.properties.changes[0].after = $null
      $path = Write-TempPayload -Payload $payload

      {
        Invoke-TestBoundaryValidator -WhatIfPayloadPath $path -ExpectedPrincipalObjectId $script:ExpectedPrincipalObjectId
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
          Invoke-TestBoundaryValidator -WhatIfPayloadPath $path -ExpectedPrincipalObjectId $script:ExpectedPrincipalObjectId | Out-Null
        } | Should -Not -Throw
      }
    }

    It 'rejects <ChangeType> for authorization <ResourceKind> explicitly' -TestCases @(
      @{ ChangeType = 'Create'; ResourceKind = 'roleDefinitions' }
      @{ ChangeType = 'Modify'; ResourceKind = 'roleDefinitions' }
      @{ ChangeType = 'Delete'; ResourceKind = 'roleDefinitions' }
      @{ ChangeType = 'Create'; ResourceKind = 'roleAssignments' }
      @{ ChangeType = 'Modify'; ResourceKind = 'roleAssignments' }
      @{ ChangeType = 'Delete'; ResourceKind = 'roleAssignments' }
    ) {
      param([string]$ChangeType, [string]$ResourceKind)

      $payload = Read-AllowedPayload
      $resourceId = "/subscriptions/11111111-1111-1111-1111-111111111111/providers/Microsoft.Authorization/$ResourceKind/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
      $resource = [pscustomobject]@{
        apiVersion = '2022-04-01'
        id = $resourceId
        type = "Microsoft.Authorization/$ResourceKind"
        name = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
        properties = [pscustomobject]@{}
      }
      $payload.properties.changes = @(
        [pscustomobject]@{
          resourceId = $resourceId
          changeType = $ChangeType
          before = if ($ChangeType -eq 'Create') { $null } else { Copy-JsonValue -Value $resource }
          after = if ($ChangeType -eq 'Delete') { $null } else { Copy-JsonValue -Value $resource }
        }
      )
      $path = Write-TempPayload -Payload $payload

      {
        Invoke-TestBoundaryValidator `
          -WhatIfPayloadPath $path `
          -ExpectedPrincipalObjectId $script:ExpectedPrincipalObjectId
      } | Should -Throw '*Authorization role definition and assignment changes are prohibited*'
    }

    It 'rejects duplicate resource IDs' {
      $payload = Read-AllowedPayload
      $duplicate = Copy-JsonValue -Value $payload.properties.changes[0]
      $payload.properties.changes = @($payload.properties.changes) + @($duplicate)
      $path = Write-TempPayload -Payload $payload

      {
        Invoke-TestBoundaryValidator -WhatIfPayloadPath $path -ExpectedPrincipalObjectId $script:ExpectedPrincipalObjectId
      } | Should -Throw '*Duplicate resourceId*/resourceGroups/rg-syn-hr-agentic-abc123-platform*'
    }

    It 'rejects wrong resource IDs and resource name disagreements' {
      $payload = Read-AllowedPayload
      $wrongResourceGroupId = '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-cal-hr-agentic-wrong'
      $wrongWorkspaceId = '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-syn-hr-agentic-abc123-platform/providers/Microsoft.OperationalInsights/workspaces/log-cal-hr-agentic-wrong'
      $payload.properties.changes[0].resourceId = $wrongResourceGroupId
      $payload.properties.changes[0].after.id = $wrongResourceGroupId
      $payload.properties.changes[0].after.name = 'rg-cal-hr-agentic-wrong'
      $payload.properties.changes[1].resourceId = $wrongWorkspaceId
      $payload.properties.changes[1].after.id = $wrongWorkspaceId
      $path = Write-TempPayload -Payload $payload

      {
        Invoke-TestBoundaryValidator -WhatIfPayloadPath $path -ExpectedPrincipalObjectId $script:ExpectedPrincipalObjectId
      } | Should -Throw '*rg-cal-hr-agentic-wrong*log-cal-hr-agentic-wrong*'
    }

    It 'rejects diagnostic setting name and workspace target drift' {
      $payload = Read-AllowedPayload
      $payload.properties.changes[2].after.name = 'activity-log-wrong'
      $payload.properties.changes[2].after.properties.workspaceId = '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-syn-hr-agentic-abc123-platform/providers/Microsoft.OperationalInsights/workspaces/log-cal-hr-agentic-wrong'
      $path = Write-TempPayload -Payload $payload

      {
        Invoke-TestBoundaryValidator -WhatIfPayloadPath $path -ExpectedPrincipalObjectId $script:ExpectedPrincipalObjectId
      } | Should -Throw '*activity-log-wrong*workspaceId*log-cal-hr-agentic-wrong*'
    }

    It 'rejects drift in every resource relevant property contract' {
      $payload = Read-AllowedPayload
      $payload.properties.changes[0].after.tags.baseline = 'wrong-baseline'
      $payload.properties.changes[1].after.properties.retentionInDays = 31
      $payload.properties.changes[2].after.properties.logs[0].categoryGroup = 'audit'
      $path = Write-TempPayload -Payload $payload

      {
        Invoke-TestBoundaryValidator -WhatIfPayloadPath $path -ExpectedPrincipalObjectId $script:ExpectedPrincipalObjectId
      } | Should -Throw '*resourceGroups/rg-syn-hr-agentic-abc123-platform*workspaces/log-syn-hr-agentic-abc123*diagnosticSettings/activity-log-to-log-analytics*'
    }

    It 'reports resource id type scope and location for each exact-resource offense' {
      $payload = Read-AllowedPayload
      $workspaceId = [string]$payload.properties.changes[1].resourceId
      $resourceGroupId = [string]$payload.properties.changes[0].resourceId
      $payload.properties.changes[1].after.properties.retentionInDays = 31
      $path = Write-TempPayload -Payload $payload

      {
        Invoke-TestBoundaryValidator -WhatIfPayloadPath $path -ExpectedPrincipalObjectId $script:ExpectedPrincipalObjectId
      } | Should -Throw ("*id={0}*type=Microsoft.OperationalInsights/workspaces*scope={1}*location=switzerlandnorth*" -f $workspaceId, $resourceGroupId)
    }

    It 'rejects unsupported resource types with named offending resources' {
        {
            Invoke-TestBoundaryValidator -WhatIfPayloadPath $script:UnexpectedTypeFixturePath -ExpectedPrincipalObjectId $script:ExpectedPrincipalObjectId
        } | Should -Throw '*Microsoft.Storage/storageAccounts*/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-syn-hr-agentic-abc123-platform/providers/Microsoft.Storage/storageAccounts/stcalhragenticabc123*'
    }

    It 'rejects foreign scopes with named offending resources' {
        {
            Invoke-TestBoundaryValidator -WhatIfPayloadPath $script:WrongScopeFixturePath -ExpectedPrincipalObjectId $script:ExpectedPrincipalObjectId
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
            Invoke-TestBoundaryValidator -WhatIfPayloadPath $path -ExpectedPrincipalObjectId $script:ExpectedPrincipalObjectId
        } | Should -Throw '*Delete*/providers/Microsoft.OperationalInsights/workspaces/log-syn-hr-agentic-abc123*Ignore*/providers/Microsoft.Insights/diagnosticSettings/activity-log-to-log-analytics*Error*'
    }

    It 'rejects unsupported locations policy assignment changes and malformed payload shape' {
        $badLocationPath = New-TempJsonFile -Json @'
{
  "status": "Succeeded",
  "properties": {
    "changes": [
      {
        "resourceId": "/subscriptions/11111111-1111-1111-1111-111111111111/providers/Microsoft.Authorization/policyAssignments/44444444-4444-4444-4444-444444444444",
        "changeType": "Create",
        "before": null,
        "after": {
          "apiVersion": "2022-06-01",
          "id": "/subscriptions/11111111-1111-1111-1111-111111111111/providers/Microsoft.Authorization/policyAssignments/44444444-4444-4444-4444-444444444444",
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
            Invoke-TestBoundaryValidator -WhatIfPayloadPath $badLocationPath -ExpectedPrincipalObjectId $script:ExpectedPrincipalObjectId
        } | Should -Throw '*policyAssignments*44444444-4444-4444-4444-444444444444*westeurope*'

        $malformedPath = New-TempJsonFile -Json '{"status":"Succeeded","properties":{}}'
        {
            Invoke-TestBoundaryValidator -WhatIfPayloadPath $malformedPath -ExpectedPrincipalObjectId $script:ExpectedPrincipalObjectId
        } | Should -Throw '*changes*'

        $nonObjectPropertiesPath = New-TempJsonFile -Json '{"status":"Succeeded","properties":[]}'
        {
            Invoke-TestBoundaryValidator -WhatIfPayloadPath $nonObjectPropertiesPath -ExpectedPrincipalObjectId $script:ExpectedPrincipalObjectId
        } | Should -Throw '*properties must be an object*'
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
            Invoke-TestBoundaryValidator -WhatIfPayloadPath $path -ExpectedPrincipalObjectId $script:ExpectedPrincipalObjectId
        } | Should -Throw '*Unsupported*Warning*'
    }
}