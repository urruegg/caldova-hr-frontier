Set-StrictMode -Version Latest

Describe 'Task 6 temporary role cleanup' {
    BeforeAll {
        $script:RepositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
        $script:ModuleManifestPath = Join-Path $script:RepositoryRoot 'infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1'
        $script:GrantScriptPath = Join-Path $script:RepositoryRoot 'infra\src\scripts\Grant-TemporaryBootstrapRoles.ps1'
        $script:StateScriptPath = Join-Path $script:RepositoryRoot 'infra\src\scripts\Get-TemporaryBootstrapRoleState.ps1'
        $script:BootstrapResultSchemaPath = Join-Path $script:RepositoryRoot 'infra\src\config\schemas\bootstrap-result.schema.json'
        Import-Module $script:ModuleManifestPath -Force

        function script:New-BootstrapResult {
            param(
                [string]$ContributorId = '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/providers/Microsoft.Authorization/roleAssignments/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
                [string]$RbacId = '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/providers/Microsoft.Authorization/roleAssignments/bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
            )

            [pscustomobject]@{
                SchemaVersion = '1.0'
                RunId = '44444444-4444-4444-4444-444444444444'
                TenantAlias = 'caldova25156897'
                TenantId = 'e2312862-df63-440c-8bcf-007a2c52859d'
                SubscriptionId = 'edb45a24-408d-47c4-bbc7-685b9b3fc017'
                PrincipalObjectId = '55555555-5555-5555-5555-555555555555'
                Scope = '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017'
                CreatedUtc = '2026-09-19T10:00:00Z'
                Assignments = @(
                    [pscustomobject]@{
                        Id = $ContributorId
                        RoleName = 'Contributor'
                        RoleDefinitionId = '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'
                        PrincipalObjectId = '55555555-5555-5555-5555-555555555555'
                        Scope = '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017'
                        CreatedUtc = '2026-09-19T10:00:00Z'
                    }
                    [pscustomobject]@{
                        Id = $RbacId
                        RoleName = 'Role Based Access Control Administrator'
                        RoleDefinitionId = '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/providers/Microsoft.Authorization/roleDefinitions/f58310d9-a9f6-439a-9e8d-f62e7b41a168'
                        PrincipalObjectId = '55555555-5555-5555-5555-555555555555'
                        Scope = '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017'
                        CreatedUtc = '2026-09-19T10:00:01Z'
                    }
                )
            }
        }

        function script:New-TenantConfigurationFile {
            $path = Join-Path $TestDrive ([guid]::NewGuid().ToString() + '.psd1')
            $content = @"
@{
    SchemaVersion = '1.0'
    TenantAlias = 'caldova25156897'
    DisplayName = 'Caldova25156897'
    TenantId = 'e2312862-df63-440c-8bcf-007a2c52859d'
    AdminUpn = 'admin@Caldova25156897.onmicrosoft.com'
    SubscriptionId = 'edb45a24-408d-47c4-bbc7-685b9b3fc017'
    PrimaryLocation = 'switzerlandnorth'
    CompanyTla = 'cal'
    WorkloadName = 'hr-agentic'
    UniqueSuffix = 'bc8rbt'
    NamingRoot = 'cal-hr-agentic-bc8rbt'
    LifecycleState = 'IntentReviewed'
    GitHub = @{
        Owner = 'urruegg'
        OwnerId = '46865858'
        Repository = 'caldova-hr-frontier'
        RepositoryId = '1371297722'
        EnvironmentName = 'bootstrap-caldova25156897'
    }
    AzureDevOps = @{
        OrganizationUrl = 'https://dev.azure.com/caldova25156897/'
        ProjectName = 'Caldova HR Frontier'
    }
    PowerPlatform = @{
        DevUrl = 'https://hrfrontierdev.crm17.dynamics.com/'
        TestUrl = 'https://hrfrontiertest.crm17.dynamics.com/'
        ProdUrl = 'https://hrfrontier.crm17.dynamics.com/'
    }
    Components = @{
        EntraServicePrincipal = @{
            Mode = 'Existing'
            Id = '55555555-5555-5555-5555-555555555555'
        }
    }
}
"@
            [System.IO.File]::WriteAllText($path, $content, [System.Text.UTF8Encoding]::new($false))
            $path
        }

        function script:New-AssignmentObject {
            param(
                [Parameter(Mandatory)]
                [string]$Id,

                [Parameter(Mandatory)]
                [string]$RoleName,

                [string]$RoleDefinitionId,

                [string]$PrincipalObjectId = '55555555-5555-5555-5555-555555555555',

                [string]$Scope = '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017'
            )

            if ([string]::IsNullOrWhiteSpace($RoleDefinitionId)) {
                $RoleDefinitionId = if ($RoleName -eq 'Contributor') {
                    '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'
                }
                else {
                    '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/providers/Microsoft.Authorization/roleDefinitions/f58310d9-a9f6-439a-9e8d-f62e7b41a168'
                }
            }

            [pscustomobject]@{
                Id = $Id
                RoleName = $RoleName
                RoleDefinitionId = $RoleDefinitionId
                PrincipalObjectId = $PrincipalObjectId
                Scope = $Scope
            }
        }
    }

    It 'defines the tracked Task 6 cleanup surface before implementation' {
        @(
            $script:BootstrapResultSchemaPath,
            $script:GrantScriptPath,
            $script:StateScriptPath,
            (Join-Path $script:RepositoryRoot 'infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Public\Remove-TemporaryRoleAssignments.ps1')
        ) | ForEach-Object {
            Test-Path -LiteralPath $_ | Should -BeTrue
        }
    }

    It 'returns exact temporary assignment ids for only Contributor and RBAC Administrator at subscription scope' {
        $tenantConfigurationPath = New-TenantConfigurationFile
        $outputPath = Join-Path $TestDrive 'bootstrap-result.json'
        $recordedOperations = [System.Collections.Generic.List[string]]::new()
        $azRequest = {
            param(
                [string]$Operation,
                [System.Collections.Specialized.OrderedDictionary]$Arguments
            )

            $recordedOperations.Add($Operation) | Out-Null

            switch ($Operation) {
                'GetRoleDefinitionByName' {
                    $definitionId = if ([string]$Arguments['RoleName'] -eq 'Contributor') {
                        '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'
                    }
                    else {
                        '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/providers/Microsoft.Authorization/roleDefinitions/f58310d9-a9f6-439a-9e8d-f62e7b41a168'
                    }

                    return [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = [pscustomobject]@{ Id = $definitionId; Name = [string]$Arguments['RoleName'] } }
                }
                'CreateRoleAssignment' {
                    $assignmentId = if ([string]$Arguments['RoleName'] -eq 'Contributor') {
                        '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/providers/Microsoft.Authorization/roleAssignments/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
                    }
                    else {
                        '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/providers/Microsoft.Authorization/roleAssignments/bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
                    }

                    return [pscustomobject]@{
                        StatusCode = 201
                        Headers = @{}
                        Body = [pscustomobject]@{
                            Id = $assignmentId
                            RoleName = [string]$Arguments['RoleName']
                            RoleDefinitionId = [string]$Arguments['RoleDefinitionId']
                            PrincipalObjectId = [string]$Arguments['PrincipalObjectId']
                            Scope = [string]$Arguments['Scope']
                            CreatedUtc = '2026-09-19T10:00:00Z'
                        }
                    }
                }
                default {
                    throw "Unexpected operation $Operation."
                }
            }
        }

        $result = & $script:GrantScriptPath -TenantAlias 'caldova25156897' -TenantConfigurationPath $tenantConfigurationPath -OutputPath $outputPath -AzRequest $azRequest -Confirm:$false

        $result.Assignments.Count | Should -Be 2
        @($result.Assignments.RoleName) | Should -Be @('Contributor', 'Role Based Access Control Administrator')
        foreach ($assignment in @($result.Assignments)) {
            $assignment.Scope | Should -Be '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017'
            $assignment.Id | Should -Match '^/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/providers/Microsoft.Authorization/roleAssignments/'
        }

        $recordedOperations | Should -Be @('GetRoleDefinitionByName', 'CreateRoleAssignment', 'GetRoleDefinitionByName', 'CreateRoleAssignment')
        Test-Path -LiteralPath $outputPath | Should -BeTrue
    }

    It 'requires exactly one assignment for each temporary role' {
        $tenantConfigurationPath = New-TenantConfigurationFile
        $statePath = Join-Path $TestDrive 'role-state.json'
        $duplicateContributor = New-AssignmentObject -Id '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/providers/Microsoft.Authorization/roleAssignments/cccccccc-cccc-cccc-cccc-cccccccccccc' -RoleName 'Contributor'
        $azRequest = {
            param(
                [string]$Operation,
                [System.Collections.Specialized.OrderedDictionary]$Arguments
            )

            $Operation | Should -Be 'ListRoleAssignments'
            [pscustomobject]@{
                StatusCode = 200
                Headers = @{}
                Body = @(
                    (New-AssignmentObject -Id '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/providers/Microsoft.Authorization/roleAssignments/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -RoleName 'Contributor'),
                    $duplicateContributor
                )
            }
        }

        {
            & $script:StateScriptPath -TenantAlias 'caldova25156897' -TenantConfigurationPath $tenantConfigurationPath -OutputPath $statePath -AzRequest $azRequest
        } | Should -Throw '*exactly one*Contributor*'
    }

    It 'rejects foreign scopes in temporary bootstrap state discovery' {
        $tenantConfigurationPath = New-TenantConfigurationFile
        $statePath = Join-Path $TestDrive 'role-state-foreign-scope.json'
        $foreignScope = New-AssignmentObject -Id '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/providers/Microsoft.Authorization/roleAssignments/dddddddd-dddd-dddd-dddd-dddddddddddd' -RoleName 'Role Based Access Control Administrator' -Scope '/subscriptions/00000000-0000-0000-0000-000000000000'
        $azRequest = {
            param(
                [string]$Operation,
                [System.Collections.Specialized.OrderedDictionary]$Arguments
            )

            $Operation | Should -Be 'ListRoleAssignments'
            [pscustomobject]@{
                StatusCode = 200
                Headers = @{}
                Body = @(
                    (New-AssignmentObject -Id '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/providers/Microsoft.Authorization/roleAssignments/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -RoleName 'Contributor'),
                    $foreignScope
                )
            }
        }

        {
            & $script:StateScriptPath -TenantAlias 'caldova25156897' -TenantConfigurationPath $tenantConfigurationPath -OutputPath $statePath -AzRequest $azRequest
        } | Should -Throw '*Unexpected scope*00000000-0000-0000-0000-000000000000*'
    }

    It 'rejects role ids not produced by the current run' {
        $result = New-BootstrapResult
        $readRoleAssignment = {
            param([string]$Id)

            New-AssignmentObject -Id $Id -RoleName 'Contributor' -PrincipalObjectId '99999999-9999-9999-9999-999999999999'
        }

        {
            Remove-TemporaryRoleAssignments -BootstrapResult $result -ExpectedRunId $result.RunId -ApprovedRoleAssignmentIds @($result.Assignments.Id) -ExpectedPrincipalObjectId $result.PrincipalObjectId -ExpectedScope $result.Scope -ReadRoleAssignment $readRoleAssignment -RemoveRoleAssignment { throw 'should not delete' } -Sleep { } -Clock { Get-Date '2026-09-19T10:00:00Z' } -TimeoutSeconds 1 -Confirm:$false
        } | Should -Throw '*PrincipalObjectId*'
    }

    It 'rejects a stale cleanup run id before any native call' {
        $result = New-BootstrapResult
        $nativeCallCount = 0

        {
            Remove-TemporaryRoleAssignments -BootstrapResult $result -ExpectedRunId '33333333-3333-3333-3333-333333333333' -ApprovedRoleAssignmentIds @($result.Assignments.Id) -ExpectedPrincipalObjectId $result.PrincipalObjectId -ExpectedScope $result.Scope -NativeCommandRunner {
                $nativeCallCount++
                throw 'native runner must not be reached'
            } -Confirm:$false
        } | Should -Throw '*BootstrapResult.RunId must match the reviewed run id*'

        $nativeCallCount | Should -Be 0
    }

    It 'rejects <Case> cleanup provenance before any native call' -ForEach @(
        @{
            Case = 'an unapproved assignment id'
            Mutate = { param([object]$Result) }
            ApprovedIds = {
                param([object]$Result)
                @(
                    [string]$Result.Assignments[0].Id,
                    '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/providers/Microsoft.Authorization/roleAssignments/cccccccc-cccc-cccc-cccc-cccccccccccc'
                )
            }
            ExpectedError = '*approved role-assignment ids must exactly match*'
        },
        @{
            Case = 'a malformed approved assignment id'
            Mutate = { param([object]$Result) }
            ApprovedIds = {
                param([object]$Result)
                @([string]$Result.Assignments[0].Id, 'not-an-assignment-id')
            }
            ExpectedError = '*ApprovedRoleAssignmentIds must contain well-formed exact assignment ids*'
        },
        @{
            Case = 'duplicate approved assignment ids'
            Mutate = { param([object]$Result) }
            ApprovedIds = {
                param([object]$Result)
                @([string]$Result.Assignments[0].Id, [string]$Result.Assignments[0].Id)
            }
            ExpectedError = '*ApprovedRoleAssignmentIds must be unique*'
        },
        @{
            Case = 'an extra top-level property'
            Mutate = { param([object]$Result) $Result | Add-Member -NotePropertyName Unexpected -NotePropertyValue 'not allowed' }
            ExpectedError = '*BootstrapResult contains unsupported properties: Unexpected*'
        },
        @{
            Case = 'an extra assignment property'
            Mutate = { param([object]$Result) $Result.Assignments[0] | Add-Member -NotePropertyName Unexpected -NotePropertyValue 'not allowed' }
            ExpectedError = '*BootstrapResult.Assignments*contains unsupported properties: Unexpected*'
        },
        @{
            Case = 'a wrong assignment principal'
            Mutate = { param([object]$Result) $Result.Assignments[0].PrincipalObjectId = '99999999-9999-9999-9999-999999999999' }
            ExpectedError = '*BootstrapResult assignment PrincipalObjectId must match the reviewed principal*'
        },
        @{
            Case = 'a wrong assignment scope'
            Mutate = { param([object]$Result) $Result.Assignments[0].Scope = '/subscriptions/00000000-0000-0000-0000-000000000000' }
            ExpectedError = '*BootstrapResult assignment Scope must match the reviewed subscription scope*'
        },
        @{
            Case = 'a wrong pinned role definition'
            Mutate = { param([object]$Result) $Result.Assignments[0].RoleDefinitionId = '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7' }
            ExpectedError = '*BootstrapResult assignment RoleDefinitionId is not the pinned built-in definition for Contributor*'
        },
        @{
            Case = 'a malformed assignment id'
            Mutate = { param([object]$Result) $Result.Assignments[0].Id = 'not-an-assignment-id' }
            ApprovedIds = {
                param([object]$Result)
                @(
                    '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/providers/Microsoft.Authorization/roleAssignments/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
                    '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/providers/Microsoft.Authorization/roleAssignments/bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
                )
            }
            ExpectedError = '*BootstrapResult assignments require well-formed exact Id values*'
        },
        @{
            Case = 'an invalid assignment timestamp'
            Mutate = { param([object]$Result) $Result.Assignments[0].CreatedUtc = 'not-a-timestamp' }
            ExpectedError = '*BootstrapResult assignment CreatedUtc must be a timestamp*'
        }
    ) {
        param($Case, $Mutate, $ApprovedIds, $ExpectedError)

        $result = New-BootstrapResult
        & $Mutate $result
        $approved = if ($ApprovedIds) { @(& $ApprovedIds $result) } else { @($result.Assignments.Id) }
        $nativeCalls = [System.Collections.Generic.List[string]]::new()

        {
            Remove-TemporaryRoleAssignments -BootstrapResult $result -ExpectedRunId $result.RunId -ApprovedRoleAssignmentIds $approved -ExpectedPrincipalObjectId '55555555-5555-5555-5555-555555555555' -ExpectedScope '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017' -NativeCommandRunner {
                param([string]$FilePath, [string[]]$ArgumentList)
                $nativeCalls.Add($FilePath) | Out-Null
                throw 'native runner must not be reached'
            } -Confirm:$false
        } | Should -Throw $ExpectedError

        $nativeCalls.Count | Should -Be 0
    }

    It 'deletes Contributor first and RBAC Administrator last then polls exact ids until absent' {
        $result = New-BootstrapResult
        $removed = [System.Collections.Generic.List[string]]::new()
        $state = @{}
        foreach ($assignment in @($result.Assignments)) {
            $state[$assignment.Id] = $true
        }

        $readRoleAssignment = {
            param([string]$Id)

            if (-not $state.ContainsKey($Id) -or -not $state[$Id]) {
                return $null
            }

            $assignment = @($result.Assignments | Where-Object { $_.Id -eq $Id })[0]
            New-AssignmentObject -Id $assignment.Id -RoleName $assignment.RoleName
        }

        $removeRoleAssignment = {
            param([object]$Assignment)

            $removed.Add([string]$Assignment.RoleName) | Out-Null
            $state[[string]$Assignment.Id] = $false
        }

        $cleanup = Remove-TemporaryRoleAssignments -BootstrapResult $result -ExpectedRunId $result.RunId -ApprovedRoleAssignmentIds @($result.Assignments.Id) -ExpectedPrincipalObjectId $result.PrincipalObjectId -ExpectedScope $result.Scope -ReadRoleAssignment $readRoleAssignment -RemoveRoleAssignment $removeRoleAssignment -Sleep { } -Clock { Get-Date '2026-09-19T10:00:00Z' } -TimeoutSeconds 5 -Confirm:$false

        $removed | Should -Be @('Contributor', 'Role Based Access Control Administrator')
        $cleanup.AbsentAssignmentIds | Should -Be @(
            '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/providers/Microsoft.Authorization/roleAssignments/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
            '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/providers/Microsoft.Authorization/roleAssignments/bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
        )
    }

    It 'fails on bounded timeout when exact ids remain present' {
        $result = New-BootstrapResult
        $clockTicks = @(
            (Get-Date '2026-09-19T10:00:00Z')
            (Get-Date '2026-09-19T10:00:01Z')
            (Get-Date '2026-09-19T10:00:02Z')
            (Get-Date '2026-09-19T10:00:03Z')
        )
        $index = 0
        $readRoleAssignment = {
            param([string]$Id)

            $assignment = @($result.Assignments | Where-Object { $_.Id -eq $Id })[0]
            New-AssignmentObject -Id $assignment.Id -RoleName $assignment.RoleName
        }

        {
            Remove-TemporaryRoleAssignments -BootstrapResult $result -ExpectedRunId $result.RunId -ApprovedRoleAssignmentIds @($result.Assignments.Id) -ExpectedPrincipalObjectId $result.PrincipalObjectId -ExpectedScope $result.Scope -ReadRoleAssignment $readRoleAssignment -RemoveRoleAssignment { } -Sleep { } -Clock {
                $tick = $clockTicks[$index]
                if ($index -lt ($clockTicks.Count - 1)) {
                    $index++
                }

                $tick
            } -TimeoutSeconds 2 -Confirm:$false
        } | Should -Throw '*timeout*'
    }

    It 'treats already absent exact ids as success' {
        $result = New-BootstrapResult
        $cleanup = Remove-TemporaryRoleAssignments -BootstrapResult $result -ExpectedRunId $result.RunId -ApprovedRoleAssignmentIds @($result.Assignments.Id) -ExpectedPrincipalObjectId $result.PrincipalObjectId -ExpectedScope $result.Scope -ReadRoleAssignment { param([string]$Id) $null } -RemoveRoleAssignment { throw 'should not delete' } -Sleep { } -Clock { Get-Date '2026-09-19T10:00:00Z' } -TimeoutSeconds 1 -Confirm:$false

        $cleanup.RemovedAssignments.Count | Should -Be 0
        $cleanup.AbsentAssignmentIds.Count | Should -Be 2
    }

    It 'uses exact-id Azure CLI cleanup defaults with only a low-level native runner' {
        $result = New-BootstrapResult
        $calls = [System.Collections.Generic.List[object]]::new()
        $assignmentPresent = @{}
        foreach ($assignment in @($result.Assignments)) {
            $assignmentPresent[$assignment.Id] = $true
        }

        $nativeRunner = {
            param(
                [string]$FilePath,
                [string[]]$ArgumentList
            )

            $calls.Add([pscustomobject]@{ FilePath = $FilePath; ArgumentList = @($ArgumentList) }) | Out-Null

            if ($ArgumentList.Count -eq 7 -and $ArgumentList[0] -ceq 'rest' -and $ArgumentList[1] -ceq '--method' -and $ArgumentList[2] -ceq 'get' -and $ArgumentList[3] -ceq '--url' -and $ArgumentList[5] -ceq '--output' -and $ArgumentList[6] -ceq 'json') {
                $id = [string]$ArgumentList[4] -replace '\?api-version=2022-04-01$', ''
                if (-not $assignmentPresent[$id]) {
                    return [pscustomobject]@{ ExitCode = 3; StatusCode = 404; ErrorCode = 'RoleAssignmentNotFound'; StdOut = ''; StdErr = 'opaque failure text' }
                }

                $assignment = @($result.Assignments | Where-Object { $_.Id -eq $id })[0]
                $payload = [pscustomobject]@{
                    id = $assignment.Id
                    properties = [pscustomobject]@{
                        principalId = $assignment.PrincipalObjectId
                        roleDefinitionId = $assignment.RoleDefinitionId
                        scope = $assignment.Scope
                    }
                } | ConvertTo-Json -Compress
                return [pscustomobject]@{ ExitCode = 0; StdOut = $payload; StdErr = '' }
            }

            if ($ArgumentList.Count -eq 7 -and $ArgumentList[0] -ceq 'role' -and $ArgumentList[1] -ceq 'assignment' -and $ArgumentList[2] -ceq 'delete' -and $ArgumentList[3] -ceq '--ids' -and $ArgumentList[5] -ceq '--output' -and $ArgumentList[6] -ceq 'none') {
                $assignmentPresent[[string]$ArgumentList[4]] = $false
                return [pscustomobject]@{ ExitCode = 0; StdOut = ''; StdErr = '' }
            }

            throw "Unexpected native command: $FilePath $($ArgumentList -join ' ')"
        }

        $cleanup = Remove-TemporaryRoleAssignments -BootstrapResult $result -ExpectedRunId $result.RunId -ApprovedRoleAssignmentIds @($result.Assignments.Id) -ExpectedPrincipalObjectId $result.PrincipalObjectId -ExpectedScope $result.Scope -NativeCommandRunner $nativeRunner -Sleep { } -Clock { Get-Date '2026-09-19T10:00:00Z' } -TimeoutSeconds 2 -Confirm:$false

        $cleanup.RemovedAssignments.RoleName | Should -Be @('Contributor', 'Role Based Access Control Administrator')
        $calls.Count | Should -Be 6
        $calls[0].FilePath | Should -BeExactly 'az'
        $calls[0].ArgumentList | Should -Be @('rest', '--method', 'get', '--url', '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/providers/Microsoft.Authorization/roleAssignments/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa?api-version=2022-04-01', '--output', 'json')
        $calls[1].ArgumentList | Should -Be @('role', 'assignment', 'delete', '--ids', '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/providers/Microsoft.Authorization/roleAssignments/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '--output', 'none')
        $calls[2].ArgumentList | Should -Be @('rest', '--method', 'get', '--url', '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/providers/Microsoft.Authorization/roleAssignments/bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb?api-version=2022-04-01', '--output', 'json')
        $calls[3].ArgumentList | Should -Be @('role', 'assignment', 'delete', '--ids', '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/providers/Microsoft.Authorization/roleAssignments/bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '--output', 'none')
        $calls[4].ArgumentList | Should -Be $calls[0].ArgumentList
        $calls[5].ArgumentList | Should -Be $calls[2].ArgumentList
        @($calls | Where-Object { $_.ArgumentList -contains '--assignee' }).Count | Should -Be 0
        @($calls | Where-Object { $_.ArgumentList -contains '--role' }).Count | Should -Be 0
    }

    It 'does not treat generic not-found text as an absent exact assignment' {
        $result = New-BootstrapResult

        {
            Remove-TemporaryRoleAssignments -BootstrapResult $result -ExpectedRunId $result.RunId -ApprovedRoleAssignmentIds @($result.Assignments.Id) -ExpectedPrincipalObjectId $result.PrincipalObjectId -ExpectedScope $result.Scope -NativeCommandRunner {
                [pscustomobject]@{ ExitCode = 1; StdOut = ''; StdErr = 'Not found' }
            } -Sleep { } -Clock { Get-Date '2026-09-19T10:00:00Z' } -TimeoutSeconds 2 -Confirm:$false
        } | Should -Throw '*Failed to read role assignment*'
    }

    It 'uses production default grant checks through only a low-level native runner' {
        $tenantConfigurationPath = New-TenantConfigurationFile
        $outputPath = Join-Path $TestDrive 'bootstrap-result-default.json'
        $calls = [System.Collections.Generic.List[object]]::new()
        $createdAssignments = @{}
        $nativeRunner = {
            param(
                [string]$FilePath,
                [string[]]$ArgumentList
            )

            $calls.Add([pscustomobject]@{ FilePath = $FilePath; ArgumentList = @($ArgumentList) }) | Out-Null

            if (@($ArgumentList).Count -eq 4 -and $ArgumentList[0] -ceq 'account' -and $ArgumentList[1] -ceq 'show') {
                return [pscustomobject]@{ ExitCode = 0; StdOut = '{"tenantId":"e2312862-df63-440c-8bcf-007a2c52859d","id":"edb45a24-408d-47c4-bbc7-685b9b3fc017","user":{"type":"user","name":"admin@caldova25156897.onmicrosoft.com"}}'; StdErr = '' }
            }

            if (@($ArgumentList).Count -eq 5 -and $ArgumentList[0] -ceq 'ad' -and $ArgumentList[1] -ceq 'signed-in-user') {
                return [pscustomobject]@{ ExitCode = 0; StdOut = '{"id":"99999999-9999-9999-9999-999999999999"}'; StdErr = '' }
            }

            if (@($ArgumentList).Count -eq 9 -and $ArgumentList[0] -ceq 'role' -and $ArgumentList[1] -ceq 'assignment' -and $ArgumentList[2] -ceq 'list') {
                $payload = @(
                    [pscustomobject]@{
                        id = '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/providers/Microsoft.Authorization/roleAssignments/cccccccc-cccc-cccc-cccc-cccccccccccc'
                        roleDefinitionName = 'Owner'
                        scope = '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017'
                    }
                ) | ConvertTo-Json -Compress
                return [pscustomobject]@{ ExitCode = 0; StdOut = $payload; StdErr = '' }
            }

            if (@($ArgumentList).Count -eq 9 -and $ArgumentList[0] -ceq 'role' -and $ArgumentList[1] -ceq 'definition' -and $ArgumentList[2] -ceq 'list') {
                $roleName = [string]$ArgumentList[4]
                $roleDefinitionId = if ($roleName -eq 'Contributor') {
                    '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'
                }
                else {
                    '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/providers/Microsoft.Authorization/roleDefinitions/f58310d9-a9f6-439a-9e8d-f62e7b41a168'
                }

                $payload = @([pscustomobject]@{ id = $roleDefinitionId; roleName = $roleName }) | ConvertTo-Json -Compress
                return [pscustomobject]@{ ExitCode = 0; StdOut = $payload; StdErr = '' }
            }

            if (@($ArgumentList).Count -eq 13 -and $ArgumentList[0] -ceq 'role' -and $ArgumentList[1] -ceq 'assignment' -and $ArgumentList[2] -ceq 'create') {
                $roleDefinitionId = [string]$ArgumentList[8]
                $roleName = if ($roleDefinitionId -match 'b24988ac-6180-42a0-ab88-20f7382dd24c$') { 'Contributor' } else { 'Role Based Access Control Administrator' }
                $assignmentId = if ($roleName -eq 'Contributor') {
                    '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/providers/Microsoft.Authorization/roleAssignments/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
                }
                else {
                    '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/providers/Microsoft.Authorization/roleAssignments/bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
                }

                $createdAssignments[$assignmentId] = $roleName
                $payload = [pscustomobject]@{ id = $assignmentId } | ConvertTo-Json -Compress
                return [pscustomobject]@{ ExitCode = 0; StdOut = $payload; StdErr = '' }
            }

            if (@($ArgumentList).Count -eq 7 -and $ArgumentList[0] -ceq 'rest' -and $ArgumentList[1] -ceq '--method' -and $ArgumentList[2] -ceq 'get' -and $ArgumentList[3] -ceq '--url') {
                $assignmentId = [string]$ArgumentList[4] -replace '\?api-version=2022-04-01$', ''
                $roleName = [string]$createdAssignments[$assignmentId]
                $roleDefinitionId = if ($roleName -eq 'Contributor') {
                    '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'
                }
                else {
                    '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/providers/Microsoft.Authorization/roleDefinitions/f58310d9-a9f6-439a-9e8d-f62e7b41a168'
                }

                $payload = [pscustomobject]@{
                    id = $assignmentId
                    properties = [pscustomobject]@{
                        principalId = '55555555-5555-5555-5555-555555555555'
                        principalType = 'ServicePrincipal'
                        roleDefinitionId = $roleDefinitionId
                        scope = '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017'
                    }
                } | ConvertTo-Json -Compress
                return [pscustomobject]@{ ExitCode = 0; StdOut = $payload; StdErr = '' }
            }

            throw "Unexpected native command: $FilePath $($ArgumentList -join ' ')"
        }

        $result = & $script:GrantScriptPath -TenantAlias 'caldova25156897' -TenantConfigurationPath $tenantConfigurationPath -OutputPath $outputPath -NativeCommandRunner $nativeRunner -Confirm:$false

        $result.Assignments.Count | Should -Be 2
        $calls[0].FilePath | Should -BeExactly 'az'
        $calls[0].ArgumentList | Should -Be @('account', 'show', '--output', 'json')
        $calls[1].ArgumentList | Should -Be @('ad', 'signed-in-user', 'show', '--output', 'json')
        $calls[2].ArgumentList | Should -Be @('role', 'assignment', 'list', '--assignee-object-id', '99999999-9999-9999-9999-999999999999', '--scope', '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017', '--output', 'json')
        $calls[3].ArgumentList | Should -Be @('role', 'definition', 'list', '--name', 'Contributor', '--scope', '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017', '--output', 'json')
        $calls[4].ArgumentList | Should -Be @('role', 'assignment', 'create', '--assignee-object-id', '55555555-5555-5555-5555-555555555555', '--assignee-principal-type', 'ServicePrincipal', '--role', '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c', '--scope', '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017', '--output', 'json')
        $calls[5].ArgumentList | Should -Be @('rest', '--method', 'get', '--url', '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/providers/Microsoft.Authorization/roleAssignments/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa?api-version=2022-04-01', '--output', 'json')
        $calls[6].ArgumentList | Should -Be @('role', 'definition', 'list', '--name', 'Role Based Access Control Administrator', '--scope', '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017', '--output', 'json')
        $calls[7].ArgumentList | Should -Be @('role', 'assignment', 'create', '--assignee-object-id', '55555555-5555-5555-5555-555555555555', '--assignee-principal-type', 'ServicePrincipal', '--role', '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/providers/Microsoft.Authorization/roleDefinitions/f58310d9-a9f6-439a-9e8d-f62e7b41a168', '--scope', '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017', '--output', 'json')
        $calls[8].ArgumentList | Should -Be @('rest', '--method', 'get', '--url', '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/providers/Microsoft.Authorization/roleAssignments/bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb?api-version=2022-04-01', '--output', 'json')
        $calls[6].ArgumentList[4] | Should -BeExactly 'Role Based Access Control Administrator'
    }

    It 'rejects a role lookup that redefines a pinned built-in role before mutation' {
        $tenantConfigurationPath = New-TenantConfigurationFile
        $outputPath = Join-Path $TestDrive 'bootstrap-result-wrong-definition.json'
        $mutationCalls = [System.Collections.Generic.List[string]]::new()

        {
            & $script:GrantScriptPath -TenantAlias 'caldova25156897' -TenantConfigurationPath $tenantConfigurationPath -OutputPath $outputPath -NativeCommandRunner {
                param([string]$FilePath, [string[]]$ArgumentList)

                if ($ArgumentList[0] -ceq 'account') {
                    return [pscustomobject]@{ ExitCode = 0; StdOut = '{"tenantId":"e2312862-df63-440c-8bcf-007a2c52859d","id":"edb45a24-408d-47c4-bbc7-685b9b3fc017","user":{"type":"user","name":"admin@Caldova25156897.onmicrosoft.com"}}'; StdErr = '' }
                }
                if ($ArgumentList[0] -ceq 'ad') {
                    return [pscustomobject]@{ ExitCode = 0; StdOut = '{"id":"99999999-9999-9999-9999-999999999999"}'; StdErr = '' }
                }
                if ($ArgumentList[0] -ceq 'role' -and $ArgumentList[1] -ceq 'assignment' -and $ArgumentList[2] -ceq 'list') {
                    return [pscustomobject]@{ ExitCode = 0; StdOut = '[{"roleDefinitionName":"Owner","scope":"/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017"}]'; StdErr = '' }
                }
                if ($ArgumentList[0] -ceq 'role' -and $ArgumentList[1] -ceq 'definition') {
                    return [pscustomobject]@{ ExitCode = 0; StdOut = '[{"id":"/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7","roleName":"Contributor"}]'; StdErr = '' }
                }

                $mutationCalls.Add(($ArgumentList -join ' ')) | Out-Null
                throw 'mutation must not be reached'
            } -Confirm:$false
        } | Should -Throw '*Contributor must resolve to its pinned built-in role definition id*'

        $mutationCalls.Count | Should -Be 0
    }

    It 'rejects polluted production default role state instead of filtering it away' {
        $tenantConfigurationPath = New-TenantConfigurationFile
        $statePath = Join-Path $TestDrive 'role-state-default.json'
        $nativeRunner = {
            param(
                [string]$FilePath,
                [string[]]$ArgumentList
            )

            $joined = $ArgumentList -join ' '
            if ($joined -eq 'account show --output json') {
                return [pscustomobject]@{ ExitCode = 0; StdOut = '{"tenantId":"e2312862-df63-440c-8bcf-007a2c52859d","id":"edb45a24-408d-47c4-bbc7-685b9b3fc017","user":{"type":"servicePrincipal"}}'; StdErr = '' }
            }

            if ($joined -match 'role assignment list --assignee-object-id 55555555-5555-5555-5555-555555555555 --scope /subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017 --output json$') {
                $payload = @(
                    [pscustomobject]@{
                        id = '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/providers/Microsoft.Authorization/roleAssignments/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
                        principalId = '55555555-5555-5555-5555-555555555555'
                        roleDefinitionId = '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'
                        roleDefinitionName = 'Contributor'
                        scope = '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017'
                    },
                    [pscustomobject]@{
                        id = '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/providers/Microsoft.Authorization/roleAssignments/dddddddd-dddd-dddd-dddd-dddddddddddd'
                        principalId = '55555555-5555-5555-5555-555555555555'
                        roleDefinitionId = '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7'
                        roleDefinitionName = 'Reader'
                        scope = '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017'
                    }
                ) | ConvertTo-Json -Compress
                return [pscustomobject]@{ ExitCode = 0; StdOut = $payload; StdErr = '' }
            }

            throw "Unexpected native command: $FilePath $joined"
        }

        {
            & $script:StateScriptPath -TenantAlias 'caldova25156897' -TenantConfigurationPath $tenantConfigurationPath -OutputPath $statePath -NativeCommandRunner $nativeRunner
        } | Should -Throw '*Unexpected role assignment Reader*'
    }
}