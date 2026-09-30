Set-StrictMode -Version Latest

Describe 'Tenant 1 attended what-if orchestration' {
    BeforeAll {
        $script:RepositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
        $script:SourceBootstrapScriptPath = Join-Path $script:RepositoryRoot 'infra\src\scripts\Invoke-TenantBootstrap.ps1'
        $script:FixturePath = Join-Path $script:RepositoryRoot 'infra\tests\fixtures\what-if\allowed.json'
        $script:TenantId = '22222222-2222-2222-2222-222222222222'
        $script:SubscriptionId = '11111111-1111-1111-1111-111111111111'
        $script:PrincipalObjectId = '55555555-5555-5555-5555-555555555555'
        $script:GroupObjectId = '77777777-7777-7777-7777-777777777777'
        $script:Scope = "/subscriptions/$($script:SubscriptionId)"
        $script:RoleName = 'syn-hr-agentic-abc123-deployment-validation'
        $script:RoleDefinitionId = "$($script:Scope)/providers/Microsoft.Authorization/roleDefinitions/4d518f04-8692-59e4-b791-5fbfbb405e86"
        $script:RoleAssignmentId = "$($script:Scope)/providers/Microsoft.Authorization/roleAssignments/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
        $script:RoleActions = @(
            '*/read'
            'Microsoft.Resources/deployments/read'
            'Microsoft.Resources/deployments/validate/action'
            'Microsoft.Resources/deployments/whatIf/action'
        )

        $script:HarnessRoot = Join-Path $TestDrive 'bootstrap-harness'
        foreach ($relativePath in @(
            'infra\src\scripts\Invoke-TenantBootstrap.ps1',
            'infra\src\scripts\Test-WhatIfBoundary.ps1',
            'infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap',
            'infra\src\config\schemas\tenant.schema.json',
            'infra\src\bicep'
        )) {
            $sourcePath = Join-Path $script:RepositoryRoot $relativePath
            $targetPath = Join-Path $script:HarnessRoot $relativePath
            $targetParent = Split-Path -Parent $targetPath
            [void](New-Item -ItemType Directory -Path $targetParent -Force)
            if (Test-Path -LiteralPath $sourcePath -PathType Container) {
                Copy-Item -LiteralPath $sourcePath -Destination $targetParent -Recurse -Force
            }
            else {
                Copy-Item -LiteralPath $sourcePath -Destination $targetPath -Force
            }
        }
        [System.IO.File]::WriteAllText(
            (Join-Path $script:HarnessRoot '.gitignore'),
            "infra/src/config/tenants/*.local.psd1$([Environment]::NewLine)",
            [System.Text.UTF8Encoding]::new($false)
        )
        & git -C $script:HarnessRoot init --quiet
        if ($LASTEXITCODE -ne 0) {
            throw 'Could not initialize the isolated bootstrap repository.'
        }
        $script:BootstrapScriptPath = Join-Path $script:HarnessRoot 'infra\src\scripts\Invoke-TenantBootstrap.ps1'

        function script:New-TenantConfigurationFile {
            $path = Join-Path $script:HarnessRoot 'infra\src\config\tenants\tenant1.local.psd1'
            [void](New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force)
            $content = @"
@{
    SchemaVersion = '1.0'
    PublicTenantKey = 'tenant1'
    TenantAlias = 'fixturetenant42'
    DisplayName = 'Fixture Tenant 42'
    TenantId = '$($script:TenantId)'
    AdminUpn = 'operator@fixture.example'
    SubscriptionId = '$($script:SubscriptionId)'
    PrimaryLocation = 'switzerlandnorth'
    CompanyTla = 'syn'
    WorkloadName = 'hr-agentic'
    UniqueSuffix = 'abc123'
    NamingRoot = 'syn-hr-agentic-abc123'
    LifecycleState = 'IntentReviewed'
    GitHub = @{
        Owner = 'urruegg'
        OwnerId = '46865858'
        Repository = 'caldova-hr-frontier'
        RepositoryId = '1371297722'
        EnvironmentName = 'bootstrap-fixturetenant42'
    }
    AzureDevOps = @{
        OrganizationUrl = 'https://dev.azure.com/synthetic/'
        ProjectName = 'Synthetic HR Frontier'
    }
    PowerPlatform = @{
        DevUrl = 'https://fixture-dev.example.test/'
        TestUrl = 'https://fixture-test.example.test/'
        ProdUrl = 'https://fixture-prod.example.test/'
    }
    Components = @{
        EntraServicePrincipal = @{
            Mode = 'Existing'
            Id = '$($script:PrincipalObjectId)'
        }
    }
}
"@
            [System.IO.File]::WriteAllText($path, $content, [System.Text.UTF8Encoding]::new($false))
            $path
        }

        function script:New-PrivateFile {
            param(
                [Parameter(Mandatory)]
                [string]$Name,

                [Parameter(Mandatory)]
                [string]$Content
            )

            $path = Join-Path $TestDrive $Name
            [System.IO.File]::WriteAllText($path, $Content, [System.Text.UTF8Encoding]::new($false))
            $path
        }

        function script:New-AccessEvidence {
            param(
                [string]$PrincipalObjectId = $script:PrincipalObjectId,
                [string]$AssignmentId = $script:RoleAssignmentId,
                [string]$AssignmentPrincipalObjectId = $PrincipalObjectId,
                [ValidateSet('User', 'Group')]
                [string]$PrincipalType = 'User',
                [string]$Scope = $script:Scope,
                [string]$AssigneeObjectId = $PrincipalObjectId,
                [string]$RoleDefinitionId = $script:RoleDefinitionId,
                [string]$RoleName = $script:RoleName,
                [string[]]$Actions = $script:RoleActions
            )

            [pscustomobject][ordered]@{
                SchemaVersion = '1.0'
                TenantId = $script:TenantId
                SubscriptionId = $script:SubscriptionId
                PrincipalObjectId = $PrincipalObjectId
                AssigneeObjectId = $AssigneeObjectId
                IncludeGroups = $true
                Scope = $Scope
                Assignments = @(
                    [pscustomobject][ordered]@{
                        Id = $AssignmentId
                        PrincipalObjectId = $AssignmentPrincipalObjectId
                        PrincipalType = $PrincipalType
                        Scope = $Scope
                        RoleDefinitionId = $RoleDefinitionId
                        RoleName = $RoleName
                        RoleType = 'CustomRole'
                        PermissionBlockCount = 1
                        AssignableScopes = @($Scope)
                        Actions = @($Actions)
                        NotActions = @()
                        DataActions = @()
                        NotDataActions = @()
                    }
                )
            }
        }

        function script:Get-ValidInvocation {
            param(
                [scriptblock]$AttendedUserContextValidator,
                [scriptblock]$AccessPreflightValidator,
                [scriptblock]$NativeCommandRunner,
                [scriptblock]$WhatIfBoundaryValidator
            )

            if (-not $AttendedUserContextValidator) {
                $principalObjectId = $script:PrincipalObjectId
                $AttendedUserContextValidator = { $principalObjectId }.GetNewClosure()
            }
            if (-not $AccessPreflightValidator) {
                $defaultAccessEvidence = New-AccessEvidence
                $AccessPreflightValidator = { $defaultAccessEvidence }.GetNewClosure()
            }
            if (-not $NativeCommandRunner) {
                $fixturePath = $script:FixturePath
                $NativeCommandRunner = {
                    param([string]$FilePath, [string[]]$ArgumentList)
                    if (($ArgumentList -join ' ') -match '^deployment sub what-if ') {
                        return [pscustomobject]@{
                            ExitCode = 0
                            StdOut = (Get-Content -Raw -LiteralPath $fixturePath)
                            StdErr = ''
                        }
                    }
                    throw "Unexpected native command: $FilePath $($ArgumentList -join ' ')"
                }.GetNewClosure()
            }
            if (-not $WhatIfBoundaryValidator) {
                $WhatIfBoundaryValidator = { }
            }
            $compiledParameters = [pscustomobject]@{
                parameters = [pscustomobject]@{
                    tenant = [pscustomobject]@{
                        value = [pscustomobject]@{
                            tenantAlias = 'fixturetenant42'
                            location = 'switzerlandnorth'
                            namingRoot = 'syn-hr-agentic-abc123'
                            platformResourceGroupName = 'rg-syn-hr-agentic-abc123-platform'
                            logAnalyticsWorkspaceName = 'log-syn-hr-agentic-abc123'
                            policyAssignments = @()
                        }
                    }
                }
            }
            $BicepValidator = { $compiledParameters }.GetNewClosure()

            @{
                PublicTenantKey = 'tenant1'
                TenantConfigurationPath = (New-TenantConfigurationFile)
                EvidencePath = (New-PrivateFile -Name 'discovery.json' -Content '{}')
                ParameterFile = (New-PrivateFile -Name 'main.bicepparam' -Content "using '../src/bicep/main.bicep'")
                WhatIfOnly = $true
                DiscoveryEvidenceValidator = { [pscustomobject]@{} }
                IntentValidator = { }
                AttendedUserContextValidator = $AttendedUserContextValidator
                AccessPreflightValidator = $AccessPreflightValidator
                BicepValidator = $BicepValidator
                NativeCommandRunner = $NativeCommandRunner
                WhatIfBoundaryValidator = $WhatIfBoundaryValidator
            }
        }
    }

    It 'defines the bootstrap orchestration surface before implementation' {
        $script:SourceBootstrapScriptPath | Should -Exist
    }

    It 'requires attended minimum access and has no role-mutation OIDC or deployment-create path' {
        $content = Get-Content -Raw -LiteralPath $script:BootstrapScriptPath
        $content | Should -Match 'user\.type.+user'
        $content | Should -Match 'AttendedUserContextValidator'
        $content | Should -Match 'AccessPreflightValidator'
        $content | Should -Match "'deployment',\s*'sub',\s*'what-if'"
        $content | Should -Not -Match 'role.+assignment.+(create|delete)'
        $content | Should -Not -Match 'OidcContextValidator|AZURE_CLIENT_ID|federated'
        $content | Should -Not -Match "'deployment',\s*'sub',\s*'create'|New-AzSubscriptionDeployment"
    }

    It 'removes every historical authorization-mutation parameter from the public interface' {
        $tokens = $null
        $parseErrors = $null
        $entryPointAst = [System.Management.Automation.Language.Parser]::ParseFile(
            $script:SourceBootstrapScriptPath,
            [ref]$tokens,
            [ref]$parseErrors
        )
        $parseErrors.Count | Should -Be 0
        $parameterNames = @($entryPointAst.ParamBlock.Parameters.Name.VariablePath.UserPath)

        foreach ($required in @(
            'PublicTenantKey',
            'TenantConfigurationPath',
            'EvidencePath',
            'ParameterFile',
            'WhatIfOnly',
            'AttendedUserContextValidator',
            'AccessPreflightValidator'
        )) {
            $parameterNames | Should -Contain $required
        }
        foreach ($retired in @(
            'TemporaryRoleStatePath',
            'ConfirmRoleCleanup',
            'BootstrapRunId',
            'ApprovedRoleAssignmentIds',
            'RoleStateLoader',
            'CleanupRunner'
        )) {
            $parameterNames | Should -Not -Contain $retired
        }
    }

    It 'rejects a malformed attended principal before access validation or native execution' {
        $accessCalls = 0
        $nativeCalls = 0
        $invocation = Get-ValidInvocation `
            -AttendedUserContextValidator { 'not-a-guid' } `
            -AccessPreflightValidator { $accessCalls++; New-AccessEvidence } `
            -NativeCommandRunner { $nativeCalls++; throw 'native execution must not be reached' }

        { & $script:BootstrapScriptPath @invocation } | Should -Throw '*must return a GUID*'
        $accessCalls | Should -Be 0
        $nativeCalls | Should -Be 0
    }

    It 'rejects access evidence with no separately approved effective assignment before what-if' {
        $nativeCalls = 0
        $evidence = New-AccessEvidence
        $evidence.Assignments = @()
        $invocation = Get-ValidInvocation `
            -AccessPreflightValidator ({ $evidence }.GetNewClosure()) `
            -NativeCommandRunner { $nativeCalls++; throw 'native execution must not be reached' }

        { & $script:BootstrapScriptPath @invocation } | Should -Throw '*effective assignment*what-if*'
        $nativeCalls | Should -Be 0
    }

    It 'accepts the exact approved validation role through an assignee group query' {
        $evidence = New-AccessEvidence `
            -AssignmentPrincipalObjectId $script:GroupObjectId `
            -PrincipalType Group
        $invocation = Get-ValidInvocation -AccessPreflightValidator ({ $evidence }.GetNewClosure())

        $result = & $script:BootstrapScriptPath @invocation

        $result.PrincipalObjectId | Should -BeExactly $script:PrincipalObjectId
    }

    It 'rejects <Case> access evidence' -ForEach @(
        @{ Case = 'wildcard action'; Kind = 'Wildcard'; Expected = '*approved validation role*' }
        @{ Case = 'Owner'; Kind = 'Owner'; Expected = '*approved validation role*' }
        @{ Case = 'Contributor'; Kind = 'Contributor'; Expected = '*approved validation role*' }
        @{ Case = 'User Access Administrator'; Kind = 'UserAccessAdministrator'; Expected = '*approved validation role*' }
        @{ Case = 'Role Based Access Control Administrator'; Kind = 'RbacAdministrator'; Expected = '*approved validation role*' }
        @{ Case = 'extra write action'; Kind = 'ExtraWrite'; Expected = '*approved validation role*' }
        @{ Case = 'extra delete action'; Kind = 'ExtraDelete'; Expected = '*approved validation role*' }
        @{ Case = 'foreign role definition'; Kind = 'ForeignRoleDefinition'; Expected = '*approved validation role*' }
        @{ Case = 'ambiguous duplicate assignment'; Kind = 'Ambiguous'; Expected = '*exactly one*approved*assignment*' }
        @{ Case = 'foreign assignee group query'; Kind = 'ForeignAssignee'; Expected = '*assignee query*attended principal*' }
        @{ Case = 'foreign group scope'; Kind = 'ForeignGroupScope'; Expected = '*exact subscription scope*' }
    ) {
        param($Case, $Kind, $Expected)

        $evidence = New-AccessEvidence
        switch ($Kind) {
            'Wildcard' {
                $evidence.Assignments[0].Actions = @('*')
            }
            'Owner' {
                $evidence.Assignments[0].RoleName = 'Owner'
                $evidence.Assignments[0].RoleDefinitionId = "$($script:Scope)/providers/Microsoft.Authorization/roleDefinitions/8e3af657-a8ff-443c-a75c-2fe8c4bcb635"
            }
            'Contributor' {
                $evidence.Assignments[0].RoleName = 'Contributor'
                $evidence.Assignments[0].RoleDefinitionId = "$($script:Scope)/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c"
            }
            'UserAccessAdministrator' {
                $evidence.Assignments[0].RoleName = 'User Access Administrator'
                $evidence.Assignments[0].RoleDefinitionId = "$($script:Scope)/providers/Microsoft.Authorization/roleDefinitions/18d7d88d-0ab5-4642-9ea2-65de77e3224f"
            }
            'RbacAdministrator' {
                $evidence.Assignments[0].RoleName = 'Role Based Access Control Administrator'
                $evidence.Assignments[0].RoleDefinitionId = "$($script:Scope)/providers/Microsoft.Authorization/roleDefinitions/f58310d9-a9f6-439a-9e8d-f62e7b41a168"
            }
            'ExtraWrite' {
                $evidence.Assignments[0].Actions = @($script:RoleActions) + 'Microsoft.Resources/deployments/write'
            }
            'ExtraDelete' {
                $evidence.Assignments[0].Actions = @($script:RoleActions) + 'Microsoft.Resources/deployments/delete'
            }
            'ForeignRoleDefinition' {
                $evidence.Assignments[0].RoleDefinitionId = "$($script:Scope)/providers/Microsoft.Authorization/roleDefinitions/22222222-2222-2222-2222-222222222222"
            }
            'Ambiguous' {
                $duplicate = New-AccessEvidence `
                    -AssignmentId "$($script:Scope)/providers/Microsoft.Authorization/roleAssignments/bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
                $evidence.Assignments = @($evidence.Assignments) + @($duplicate.Assignments)
            }
            'ForeignAssignee' {
                $evidence.AssigneeObjectId = '66666666-6666-6666-6666-666666666666'
                $evidence.Assignments[0].PrincipalObjectId = $script:GroupObjectId
                $evidence.Assignments[0].PrincipalType = 'Group'
            }
            'ForeignGroupScope' {
                $foreignScope = '/subscriptions/00000000-0000-0000-0000-000000000000'
                $evidence.Assignments[0].PrincipalObjectId = $script:GroupObjectId
                $evidence.Assignments[0].PrincipalType = 'Group'
                $evidence.Assignments[0].Scope = $foreignScope
                $evidence.Assignments[0].AssignableScopes = @($foreignScope)
            }
        }
        $invocation = Get-ValidInvocation -AccessPreflightValidator ({ $evidence }.GetNewClosure())

        { & $script:BootstrapScriptPath @invocation } | Should -Throw $Expected
    }

    It 'keeps the WhatIfOnly guard as a hard failure before deployment API execution' {
        $nativeCalls = 0
        $invocation = Get-ValidInvocation -NativeCommandRunner {
            $nativeCalls++
            throw 'deployment API execution must not be reached'
        }
        $invocation.WhatIfOnly = $false

        { & $script:BootstrapScriptPath @invocation } | Should -Throw '*only supports -WhatIfOnly*'
        $nativeCalls | Should -Be 0
    }

    It 'rejects attended context drift after what-if' {
        $state = [pscustomobject]@{ ContextCalls = 0 }
        $principalObjectId = $script:PrincipalObjectId
        $invocation = Get-ValidInvocation -AttendedUserContextValidator ({
            $state.ContextCalls++
            if ($state.ContextCalls -eq 1) {
                return $principalObjectId
            }
            '66666666-6666-6666-6666-666666666666'
        }.GetNewClosure())

        { & $script:BootstrapScriptPath @invocation } | Should -Throw '*Attended context drift*'
        $state.ContextCalls | Should -Be 2
    }

    It 'rejects access drift after what-if' {
        $state = [pscustomobject]@{ AccessCalls = 0 }
        $scope = $script:Scope
        $preflightEvidence = New-AccessEvidence
        $readBackEvidence = New-AccessEvidence -AssignmentId "$scope/providers/Microsoft.Authorization/roleAssignments/bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
        $invocation = Get-ValidInvocation -AccessPreflightValidator ({
            $state.AccessCalls++
            if ($state.AccessCalls -eq 1) {
                return $preflightEvidence
            }
            $readBackEvidence
        }.GetNewClosure())

        { & $script:BootstrapScriptPath @invocation } | Should -Throw '*Access drift*'
        $state.AccessCalls | Should -Be 2
    }

    It 'runs what-if once and persists preflight and read-back evidence outside Git' {
        $state = [pscustomobject]@{
            ContextCalls = 0
            AccessCalls = 0
            WhatIfCalls = 0
            BoundaryCalls = 0
        }
        $principalObjectId = $script:PrincipalObjectId
        $fixturePath = $script:FixturePath
        $accessEvidence = New-AccessEvidence
        $invocation = Get-ValidInvocation `
            -AttendedUserContextValidator ({ $state.ContextCalls++; $principalObjectId }.GetNewClosure()) `
            -AccessPreflightValidator ({ $state.AccessCalls++; $accessEvidence }.GetNewClosure()) `
            -NativeCommandRunner ({
                param([string]$FilePath, [string[]]$ArgumentList)
                $state.WhatIfCalls++
                $ArgumentList[0..2] | Should -Be @('deployment', 'sub', 'what-if')
                [pscustomobject]@{
                    ExitCode = 0
                    StdOut = (Get-Content -Raw -LiteralPath $fixturePath)
                    StdErr = ''
                }
            }.GetNewClosure()) `
            -WhatIfBoundaryValidator ({
                param([string]$Path, [string]$PrincipalObjectId)
                $state.BoundaryCalls++
                $Path | Should -Exist
                $PrincipalObjectId | Should -BeExactly $principalObjectId
            }.GetNewClosure())

        $result = & $script:BootstrapScriptPath @invocation

        $state.ContextCalls | Should -Be 2
        $state.AccessCalls | Should -Be 2
        $state.WhatIfCalls | Should -Be 1
        $state.BoundaryCalls | Should -Be 1
        @($result.PSObject.Properties.Name) | Should -Be @(
            'TenantAlias',
            'WhatIfOnly',
            'PrincipalObjectId',
            'AccessEvidencePath',
            'WhatIfOutputPath'
        )
        $result.TenantAlias | Should -BeExactly 'fixturetenant42'
        $result.PrincipalObjectId | Should -BeExactly $script:PrincipalObjectId
        $result.AccessEvidencePath | Should -Exist
        $result.WhatIfOutputPath | Should -Exist
        Split-Path -Parent $result.AccessEvidencePath | Should -BeExactly (Split-Path -Parent $invocation.EvidencePath)
        Split-Path -Parent $result.WhatIfOutputPath | Should -BeExactly (Split-Path -Parent $invocation.EvidencePath)

        $record = Get-Content -Raw -LiteralPath $result.AccessEvidencePath | ConvertFrom-Json
        $record.Preflight.PrincipalObjectId | Should -BeExactly $script:PrincipalObjectId
        $record.ReadBack.PrincipalObjectId | Should -BeExactly $script:PrincipalObjectId
        @($record.Preflight.Assignments).Count | Should -Be 1
        @($record.ReadBack.Assignments).Count | Should -Be 1
    }

    It 'accepts the exact approved direct-user role through the default group-aware Azure CLI query' {
        $tenantConfigurationPath = New-TenantConfigurationFile
        $evidencePath = New-PrivateFile -Name 'default-discovery.json' -Content '{}'
        $parameterFile = New-PrivateFile -Name 'default-main.bicepparam' -Content "using '../src/bicep/main.bicep'"
        $nativeCalls = [System.Collections.Generic.List[object]]::new()
        $whatIfPayload = Get-Content -Raw -LiteralPath $script:FixturePath
        $compiledParameters = [ordered]@{
            parametersJson = ([ordered]@{
                parameters = [ordered]@{
                    tenant = [ordered]@{
                        value = [ordered]@{
                            tenantAlias = 'fixturetenant42'
                            location = 'switzerlandnorth'
                            namingRoot = 'syn-hr-agentic-abc123'
                            platformResourceGroupName = 'rg-syn-hr-agentic-abc123-platform'
                            logAnalyticsWorkspaceName = 'log-syn-hr-agentic-abc123'
                            policyAssignments = @()
                        }
                    }
                }
            } | ConvertTo-Json -Depth 10 -Compress)
        } | ConvertTo-Json -Depth 10 -Compress
        $accountPayload = [ordered]@{
            id = $script:SubscriptionId
            tenantId = $script:TenantId
            user = [ordered]@{
                name = 'operator@caldova.example'
                type = 'user'
            }
        } | ConvertTo-Json -Depth 10 -Compress
        $assignmentPayload = ConvertTo-Json -InputObject @(
            [ordered]@{
                id = $script:RoleAssignmentId
                principalId = $script:PrincipalObjectId
                principalType = 'User'
                roleDefinitionId = $script:RoleDefinitionId
                roleDefinitionName = $script:RoleName
                scope = $script:Scope
            }
        ) -Depth 10 -Compress
        $roleDefinitionPayload = ConvertTo-Json -InputObject @(
            [ordered]@{
                id = $script:RoleDefinitionId
                roleName = $script:RoleName
                roleType = 'CustomRole'
                assignableScopes = @($script:Scope)
                permissions = @(
                    [ordered]@{
                        actions = @($script:RoleActions)
                        notActions = @()
                        dataActions = @()
                        notDataActions = @()
                    }
                )
            }
        ) -Depth 10 -Compress

        $nativeRunner = {
            param([string]$FilePath, [string[]]$ArgumentList)

            $nativeCalls.Add([pscustomobject]@{
                FilePath = $FilePath
                ArgumentList = @($ArgumentList)
            }) | Out-Null
            $joined = $ArgumentList -join ' '
            switch -Regex ($joined) {
                '^account show --output json$' {
                    return [pscustomobject]@{ ExitCode = 0; StdOut = $accountPayload; StdErr = '' }
                }
                '^ad signed-in-user show --output json$' {
                    return [pscustomobject]@{ ExitCode = 0; StdOut = '{"id":"55555555-5555-5555-5555-555555555555"}'; StdErr = '' }
                }
                '^role assignment list --assignee-object-id .+ --include-groups --scope .+ --output json$' {
                    return [pscustomobject]@{ ExitCode = 0; StdOut = $assignmentPayload; StdErr = '' }
                }
                '^role definition list --name .+ --output json$' {
                    return [pscustomobject]@{ ExitCode = 0; StdOut = $roleDefinitionPayload; StdErr = '' }
                }
                '^bicep build --file .+main\.bicep --stdout$' {
                    return [pscustomobject]@{ ExitCode = 0; StdOut = '{"template":"ok"}'; StdErr = '' }
                }
                '^bicep build-params --file .+default-main\.bicepparam --stdout$' {
                    return [pscustomobject]@{ ExitCode = 0; StdOut = $compiledParameters; StdErr = '' }
                }
                '^deployment sub what-if ' {
                    return [pscustomobject]@{ ExitCode = 0; StdOut = $whatIfPayload; StdErr = '' }
                }
                default {
                    throw "Unexpected native command: $FilePath $joined"
                }
            }
        }

        $result = & $script:BootstrapScriptPath `
            -PublicTenantKey tenant1 `
            -TenantConfigurationPath $tenantConfigurationPath `
            -EvidencePath $evidencePath `
            -ParameterFile $parameterFile `
            -WhatIfOnly `
            -DiscoveryEvidenceValidator { [pscustomobject]@{} } `
            -IntentValidator { } `
            -NativeCommandRunner $nativeRunner `
            -WhatIfBoundaryValidator { }

        $result.PrincipalObjectId | Should -BeExactly $script:PrincipalObjectId
        $nativeCalls.Count | Should -Be 11
        @($nativeCalls | Where-Object {
            $_.ArgumentList.Count -ge 3 -and
            $_.ArgumentList[0] -ceq 'role' -and
            $_.ArgumentList[1] -ceq 'assignment' -and
            $_.ArgumentList[2] -cne 'list'
        }).Count | Should -Be 0
        @($nativeCalls | Where-Object {
            $_.ArgumentList.Count -ge 3 -and
            $_.ArgumentList[0] -ceq 'deployment' -and
            $_.ArgumentList[1] -ceq 'sub' -and
            $_.ArgumentList[2] -cne 'what-if'
        }).Count | Should -Be 0
        @($nativeCalls | Where-Object {
            $_.ArgumentList[0..2] -join ' ' -ceq 'role assignment list'
        }).Count | Should -Be 2
        foreach ($accessCall in @($nativeCalls | Where-Object {
            $_.ArgumentList[0..2] -join ' ' -ceq 'role assignment list'
        })) {
            $accessCall.ArgumentList | Should -Contain '--include-groups'
            $accessCall.ArgumentList | Should -Contain '--assignee-object-id'
            $accessCall.ArgumentList | Should -Contain $script:PrincipalObjectId
            $accessCall.ArgumentList | Should -Contain $script:Scope
        }
    }

    It 'requires explicit local configuration and keeps every private path outside the repository' {
        $tenantConfigurationPath = New-TenantConfigurationFile
        $insideEvidencePath = Join-Path $script:HarnessRoot 'private-evidence.json'
        $invocation = Get-ValidInvocation
        $invocation.TenantConfigurationPath = $tenantConfigurationPath
        $invocation.EvidencePath = $insideEvidencePath

        { & $script:BootstrapScriptPath @invocation } | Should -Throw '*outside the repository*'
    }
}
