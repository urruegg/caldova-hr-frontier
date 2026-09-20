Set-StrictMode -Version Latest

Describe 'Final GitHub governance activation' {
    BeforeAll {
        $script:RepositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
        $script:ScriptPath = Join-Path $script:RepositoryRoot 'infra\src\scripts\Enable-GitHubGovernance.ps1'
        $script:DesiredStatePath = Join-Path $script:RepositoryRoot 'infra\src\config\github\main-ruleset.json'
        $script:SchemaPath = Join-Path $script:RepositoryRoot 'infra\src\config\schemas\github-ruleset.schema.json'
        $script:Repository = 'urruegg/caldova-hr-frontier'
        $script:ValidatorRunId = [long]101
        $script:BootstrapRunId = [long]202
        $script:UserId = [long]46865858
        $script:PrincipalObjectId = '55555555-5555-5555-5555-555555555555'
        $script:SubscriptionId = 'edb45a24-408d-47c4-bbc7-685b9b3fc017'
        $script:Scope = '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017'

        function script:Write-TestJson {
            param(
                [Parameter(Mandatory)]
                [object]$Value,

                [string]$Name = ([guid]::NewGuid().ToString() + '.json')
            )

            $path = Join-Path $TestDrive $Name
            $json = $Value | ConvertTo-Json -Depth 30 -Compress
            [System.IO.File]::WriteAllText($path, $json, [System.Text.UTF8Encoding]::new($false))
            $path
        }

        function script:Copy-TestData {
            param([Parameter(Mandatory)][object]$Value)

            $Value | ConvertTo-Json -Depth 30 | ConvertFrom-Json
        }

        function script:New-TestBootstrapEvidence {
            $verifiedUtc = [datetime]::UtcNow.AddMinutes(-1).ToString('o')
            [ordered]@{
                SchemaVersion = '1.0'
                BootstrapRunId = $script:BootstrapRunId
                TenantAlias = 'caldova25156897'
                SubscriptionId = $script:SubscriptionId
                PrincipalObjectId = $script:PrincipalObjectId
                Scope = $script:Scope
                VerifiedUtc = $verifiedUtc
                Assignments = @(
                    [ordered]@{
                        Id = "$($script:Scope)/providers/Microsoft.Authorization/roleAssignments/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
                        RoleName = 'Contributor'
                        RoleDefinitionId = "$($script:Scope)/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c"
                        PrincipalObjectId = $script:PrincipalObjectId
                        Scope = $script:Scope
                        ReadBackStatus = 'Absent'
                        VerifiedUtc = $verifiedUtc
                    },
                    [ordered]@{
                        Id = "$($script:Scope)/providers/Microsoft.Authorization/roleAssignments/bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
                        RoleName = 'Role Based Access Control Administrator'
                        RoleDefinitionId = "$($script:Scope)/providers/Microsoft.Authorization/roleDefinitions/f58310d9-a9f6-439a-9e8d-f62e7b41a168"
                        PrincipalObjectId = $script:PrincipalObjectId
                        Scope = $script:Scope
                        ReadBackStatus = 'Absent'
                        VerifiedUtc = $verifiedUtc
                    }
                )
            }
        }

        function script:New-ExpectedPayload {
            [ordered]@{
                name = 'main'
                target = 'branch'
                enforcement = 'active'
                bypass_actors = @(
                    [ordered]@{
                        actor_id = $script:UserId
                        actor_type = 'User'
                        bypass_mode = 'pull_request'
                    }
                )
                conditions = [ordered]@{
                    ref_name = [ordered]@{
                        include = @('refs/heads/main')
                        exclude = @()
                    }
                }
                rules = @(
                    [ordered]@{ type = 'deletion' },
                    [ordered]@{ type = 'non_fast_forward' },
                    [ordered]@{
                        type = 'pull_request'
                        parameters = [ordered]@{
                            dismiss_stale_reviews_on_push = $true
                            require_code_owner_review = $true
                            require_last_push_approval = $false
                            required_approving_review_count = 1
                            required_review_thread_resolution = $true
                            allowed_merge_methods = @('merge', 'squash', 'rebase')
                        }
                    },
                    [ordered]@{
                        type = 'required_status_checks'
                        parameters = [ordered]@{
                            do_not_enforce_on_create = $false
                            required_status_checks = @(
                                [ordered]@{ context = 'Repository setup validation' }
                            )
                            strict_required_status_checks_policy = $true
                        }
                    }
                )
            }
        }

        function script:New-ExactRulesetDetail {
            param([long]$Id = 321)

            $payload = New-ExpectedPayload
            [ordered]@{
                id = $Id
                name = $payload.name
                target = $payload.target
                source_type = 'Repository'
                source = $script:Repository
                enforcement = $payload.enforcement
                bypass_actors = $payload.bypass_actors
                conditions = $payload.conditions
                rules = $payload.rules
            }
        }

        function script:New-TestGovernanceState {
            [ordered]@{
                UserIdText = [string]$script:UserId
                AdminText = 'true'
                Runs = [ordered]@{
                    '101' = [ordered]@{
                        id = $script:ValidatorRunId
                        head_branch = 'main'
                        status = 'completed'
                        conclusion = 'success'
                        path = '.github/workflows/validate-repository.yml'
                        name = 'Validate repository'
                        repository = [ordered]@{ full_name = $script:Repository }
                    }
                    '202' = [ordered]@{
                        id = $script:BootstrapRunId
                        head_branch = 'main'
                        status = 'completed'
                        conclusion = 'success'
                        path = '.github/workflows/bootstrap-tenant.yml'
                        name = 'Validate tenant bootstrap'
                        repository = [ordered]@{ full_name = $script:Repository }
                    }
                }
                Rulesets = @()
                RulesetDetails = [ordered]@{}
                NextRulesetId = [long]321
                PreserveRulesetReadBackDrift = $false
                Environment = [ordered]@{
                    id = 91234
                    name = 'bootstrap-caldova25156897'
                    protection_rules = @(
                        [ordered]@{
                            id = 7001
                            type = 'required_reviewers'
                            prevent_self_review = $false
                            reviewers = @(
                                [ordered]@{
                                    type = 'User'
                                    reviewer = [ordered]@{
                                        id = $script:UserId
                                        login = 'urruegg'
                                    }
                                }
                            )
                        }
                    )
                    deployment_branch_policy = [ordered]@{
                        protected_branches = $false
                        custom_branch_policies = $true
                    }
                }
                DeploymentBranchPolicies = [ordered]@{
                    total_count = 1
                    branch_policies = @(
                        [ordered]@{ id = 8001; name = 'main'; type = 'branch' }
                    )
                }
                EnvironmentVariables = [ordered]@{
                    total_count = 3
                    variables = @(
                        [ordered]@{ name = 'AZURE_CLIENT_ID'; value = 'client-id' },
                        [ordered]@{ name = 'AZURE_TENANT_ID'; value = 'tenant-id' },
                        [ordered]@{ name = 'AZURE_SUBSCRIPTION_ID'; value = $script:SubscriptionId }
                    )
                }
            }
        }

        function script:Test-ExactArguments {
            param(
                [Parameter(Mandatory)][string[]]$Actual,
                [Parameter(Mandatory)][string[]]$Expected
            )

            if ($Actual.Count -ne $Expected.Count) {
                return $false
            }

            for ($index = 0; $index -lt $Expected.Count; $index++) {
                if ($Actual[$index] -cne $Expected[$index]) {
                    return $false
                }
            }

            $true
        }

        function script:New-NativeHarness {
            param([Parameter(Mandatory)][System.Collections.IDictionary]$State)

            $calls = [System.Collections.Generic.List[object]]::new()
            $testExactArguments = ${function:script:Test-ExactArguments}

            $runner = {
                param(
                    [Parameter(Mandatory)][string]$FilePath,
                    [Parameter(Mandatory)][string[]]$ArgumentList
                )

                $record = [ordered]@{
                    FilePath = $FilePath
                    ArgumentList = @($ArgumentList)
                    BodyText = $null
                    BodyHasBom = $null
                    InputPath = $null
                }

                $inputIndex = [array]::IndexOf($ArgumentList, '--input')
                if ($inputIndex -ge 0) {
                    $inputPath = [string]$ArgumentList[$inputIndex + 1]
                    $bytes = [System.IO.File]::ReadAllBytes($inputPath)
                    $record.InputPath = $inputPath
                    $record.BodyText = [System.Text.Encoding]::UTF8.GetString($bytes)
                    $record.BodyHasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191
                }

                $calls.Add([pscustomobject]$record) | Out-Null

                if ($FilePath -cne 'gh') {
                    throw "Unexpected native executable: $FilePath"
                }

                if (& $testExactArguments -Actual $ArgumentList -Expected @('api', 'users/urruegg', '--jq', '.id')) {
                    return [pscustomobject]@{ ExitCode = 0; StdOut = [string]$State.UserIdText; StdErr = '' }
                }

                if (& $testExactArguments -Actual $ArgumentList -Expected @('api', 'repos/urruegg/caldova-hr-frontier/collaborators/urruegg/permission', '--jq', '.user.permissions.admin')) {
                    return [pscustomobject]@{ ExitCode = 0; StdOut = [string]$State.AdminText; StdErr = '' }
                }

                if ($ArgumentList.Count -eq 2 -and $ArgumentList[0] -ceq 'api' -and $ArgumentList[1] -match '^repos/urruegg/caldova-hr-frontier/actions/runs/([0-9]+)$') {
                    $runId = $Matches[1]
                    if (-not $State.Runs.Contains($runId)) {
                        return [pscustomobject]@{ ExitCode = 1; StdOut = ''; StdErr = 'run not found' }
                    }

                    return [pscustomobject]@{ ExitCode = 0; StdOut = ($State.Runs[$runId] | ConvertTo-Json -Depth 20 -Compress); StdErr = '' }
                }

                if (& $testExactArguments -Actual $ArgumentList -Expected @('api', 'repos/urruegg/caldova-hr-frontier/rulesets?includes_parents=false')) {
                    return [pscustomobject]@{ ExitCode = 0; StdOut = (ConvertTo-Json -InputObject @($State.Rulesets) -Depth 20 -Compress); StdErr = '' }
                }

                if ($ArgumentList.Count -eq 2 -and $ArgumentList[0] -ceq 'api' -and $ArgumentList[1] -match '^repos/urruegg/caldova-hr-frontier/rulesets/([0-9]+)$') {
                    $rulesetId = $Matches[1]
                    if (-not $State.RulesetDetails.Contains($rulesetId)) {
                        return [pscustomobject]@{ ExitCode = 1; StdOut = ''; StdErr = 'ruleset not found' }
                    }

                    return [pscustomobject]@{ ExitCode = 0; StdOut = ($State.RulesetDetails[$rulesetId] | ConvertTo-Json -Depth 30 -Compress); StdErr = '' }
                }

                if (& $testExactArguments -Actual $ArgumentList -Expected @('api', 'repos/urruegg/caldova-hr-frontier/environments/bootstrap-caldova25156897')) {
                    return [pscustomobject]@{ ExitCode = 0; StdOut = ($State.Environment | ConvertTo-Json -Depth 20 -Compress); StdErr = '' }
                }

                if (& $testExactArguments -Actual $ArgumentList -Expected @('api', 'repos/urruegg/caldova-hr-frontier/environments/bootstrap-caldova25156897/deployment-branch-policies')) {
                    return [pscustomobject]@{ ExitCode = 0; StdOut = ($State.DeploymentBranchPolicies | ConvertTo-Json -Depth 20 -Compress); StdErr = '' }
                }

                if (& $testExactArguments -Actual $ArgumentList -Expected @('api', 'repos/urruegg/caldova-hr-frontier/environments/bootstrap-caldova25156897/variables')) {
                    return [pscustomobject]@{ ExitCode = 0; StdOut = ($State.EnvironmentVariables | ConvertTo-Json -Depth 20 -Compress); StdErr = '' }
                }

                $isCreate = $ArgumentList.Count -eq 6 -and $ArgumentList[0] -ceq 'api' -and $ArgumentList[1] -ceq '--method' -and $ArgumentList[2] -ceq 'POST' -and $ArgumentList[3] -ceq 'repos/urruegg/caldova-hr-frontier/rulesets' -and $ArgumentList[4] -ceq '--input'
                $isUpdate = $ArgumentList.Count -eq 6 -and $ArgumentList[0] -ceq 'api' -and $ArgumentList[1] -ceq '--method' -and $ArgumentList[2] -ceq 'PUT' -and $ArgumentList[3] -match '^repos/urruegg/caldova-hr-frontier/rulesets/([0-9]+)$' -and $ArgumentList[4] -ceq '--input'
                if ($isCreate -or $isUpdate) {
                    $rulesetId = if ($isCreate) { [long]$State.NextRulesetId } else { [long]([regex]::Match($ArgumentList[3], '/([0-9]+)$').Groups[1].Value) }
                    $payload = $record.BodyText | ConvertFrom-Json
                    $detail = [ordered]@{
                        id = $rulesetId
                        name = [string]$payload.name
                        target = [string]$payload.target
                        source_type = 'Repository'
                        source = 'urruegg/caldova-hr-frontier'
                        enforcement = [string]$payload.enforcement
                        bypass_actors = @($payload.bypass_actors)
                        conditions = $payload.conditions
                        rules = @($payload.rules)
                    }
                    if ([bool]$State.PreserveRulesetReadBackDrift) {
                        $detail.enforcement = 'evaluate'
                    }

                    $State.RulesetDetails[[string]$rulesetId] = $detail
                    return [pscustomobject]@{ ExitCode = 0; StdOut = ([ordered]@{ id = $rulesetId } | ConvertTo-Json -Compress); StdErr = '' }
                }

                throw "Unexpected gh argument array: $($ArgumentList | ConvertTo-Json -Compress)"
            }.GetNewClosure()

            [pscustomobject]@{
                Calls = $calls
                Runner = $runner
            }
        }

        function script:Get-MutationCalls {
            param([Parameter(Mandatory)][object]$Harness)

            @(
                $Harness.Calls | Where-Object {
                    $_.ArgumentList.Count -ge 3 -and
                    $_.ArgumentList[0] -ceq 'api' -and
                    $_.ArgumentList[1] -ceq '--method' -and
                    $_.ArgumentList[2] -in @('POST', 'PUT', 'PATCH', 'DELETE')
                }
            )
        }

        function script:Invoke-TestGovernance {
            param(
                [Parameter(Mandatory)][object]$Harness,
                [Parameter(Mandatory)][string]$EvidencePath,
                [string]$DesiredStatePath = $script:DesiredStatePath,
                [object]$Repository = $script:Repository,
                [object]$ValidatorRunId = $script:ValidatorRunId,
                [object]$BootstrapRunId = $script:BootstrapRunId,
                [switch]$WhatIf
            )

            $parameters = @{
                Repository = $Repository
                ValidatorRunId = $ValidatorRunId
                BootstrapRunId = $BootstrapRunId
                BootstrapEvidencePath = $EvidencePath
                DesiredStatePath = $DesiredStatePath
                NativeCommandRunner = $Harness.Runner
                Confirm = $false
            }
            if ($WhatIf) {
                $parameters.WhatIf = $true
            }

            & $script:ScriptPath @parameters
        }

        function script:Set-ExactExistingRuleset {
            param([Parameter(Mandatory)][System.Collections.IDictionary]$State)

            $State.Rulesets = @(
                [ordered]@{
                    id = 321
                    name = 'main'
                    target = 'branch'
                    source_type = 'Repository'
                    source = $script:Repository
                    enforcement = 'active'
                }
            )
            $State.RulesetDetails['321'] = New-ExactRulesetDetail -Id 321
        }

        function script:Assert-ClosedSchemaNode {
            param([AllowNull()][object]$Node)

            if ($null -eq $Node -or $Node -is [string] -or $Node -is [ValueType]) {
                return
            }

            $properties = @($Node.PSObject.Properties)
            $typeProperty = $properties | Where-Object Name -CEQ 'type' | Select-Object -First 1
            if ($null -ne $typeProperty -and [string]$typeProperty.Value -ceq 'object') {
                $additional = $properties | Where-Object Name -CEQ 'additionalProperties' | Select-Object -First 1
                $additional | Should -Not -BeNullOrEmpty
                [bool]$additional.Value | Should -BeFalse
            }

            foreach ($property in $properties) {
                if ($property.Name -in @('properties', '$defs')) {
                    foreach ($child in @($property.Value.PSObject.Properties)) {
                        Assert-ClosedSchemaNode -Node $child.Value
                    }
                }
                elseif ($property.Name -ceq 'items' -and $property.Value -isnot [bool]) {
                    Assert-ClosedSchemaNode -Node $property.Value
                }
                elseif ($property.Name -ceq 'prefixItems') {
                    foreach ($child in @($property.Value)) {
                        Assert-ClosedSchemaNode -Node $child
                    }
                }
            }
        }
    }

    It 'ships the exact reviewed desired state and a recursively closed Draft 2020-12 schema' {
        Test-Path -LiteralPath $script:DesiredStatePath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $script:SchemaPath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $script:ScriptPath -PathType Leaf | Should -BeTrue

        $desired = Get-Content -Raw -LiteralPath $script:DesiredStatePath | ConvertFrom-Json
        $schema = Get-Content -Raw -LiteralPath $script:SchemaPath | ConvertFrom-Json

        $schema.'$schema' | Should -BeExactly 'https://json-schema.org/draft/2020-12/schema'
        Assert-ClosedSchemaNode -Node $schema
        $desired.schemaVersion | Should -BeExactly '1.0'
        $desired.repository | Should -BeExactly $script:Repository
        @($desired.rulesets) | Should -HaveCount 1
        $ruleset = $desired.rulesets[0]
        $ruleset.name | Should -BeExactly 'main'
        $ruleset.target | Should -BeExactly 'branch'
        $ruleset.enforcement | Should -BeExactly 'active'
        @($ruleset.conditions.refName.include) | Should -Be @('refs/heads/main')
        @($ruleset.conditions.refName.exclude) | Should -HaveCount 0
        @($ruleset.bypassActors) | Should -HaveCount 1
        $ruleset.bypassActors[0].actorType | Should -BeExactly 'User'
        $ruleset.bypassActors[0].login | Should -BeExactly 'urruegg'
        $ruleset.bypassActors[0].bypassMode | Should -BeExactly 'pull_request'
        @($ruleset.rules.type) | Should -Be @('deletion', 'non_fast_forward', 'pull_request', 'required_status_checks')
        $ruleset.rules[2].parameters.requiredApprovingReviewCount | Should -Be 1
        $ruleset.rules[2].parameters.dismissStaleReviewsOnPush | Should -BeTrue
        $ruleset.rules[2].parameters.requireCodeOwnerReview | Should -BeTrue
        $ruleset.rules[2].parameters.requireLastPushApproval | Should -BeFalse
        $ruleset.rules[2].parameters.requiredReviewThreadResolution | Should -BeTrue
        $ruleset.rules[3].parameters.requiredStatusChecks[0].context | Should -BeExactly 'Repository setup validation'
        $ruleset.rules[3].parameters.strictRequiredStatusChecksPolicy | Should -BeTrue
    }

    It 'returns the exact create proposal under WhatIf and performs zero mutation calls' {
        $state = New-TestGovernanceState
        $harness = New-NativeHarness -State $state
        $evidencePath = Write-TestJson -Value (New-TestBootstrapEvidence)

        $result = Invoke-TestGovernance -Harness $harness -EvidencePath $evidencePath -WhatIf

        $result.Action | Should -BeExactly 'Create'
        $result.Method | Should -BeExactly 'POST'
        $result.Endpoint | Should -BeExactly 'repos/urruegg/caldova-hr-frontier/rulesets'
        ($result.Payload | ConvertTo-Json -Depth 30 -Compress) | Should -BeExactly ((New-ExpectedPayload) | ConvertTo-Json -Depth 30 -Compress)
        @(Get-MutationCalls -Harness $harness) | Should -HaveCount 0
        @($harness.Calls | ForEach-Object { $_.ArgumentList -join [char]31 }) | Should -Be @(
            (@('api', 'users/urruegg', '--jq', '.id') -join [char]31),
            (@('api', 'repos/urruegg/caldova-hr-frontier/collaborators/urruegg/permission', '--jq', '.user.permissions.admin') -join [char]31),
            (@('api', 'repos/urruegg/caldova-hr-frontier/actions/runs/101') -join [char]31),
            (@('api', 'repos/urruegg/caldova-hr-frontier/actions/runs/202') -join [char]31),
            (@('api', 'repos/urruegg/caldova-hr-frontier/rulesets?includes_parents=false') -join [char]31),
            (@('api', 'repos/urruegg/caldova-hr-frontier/environments/bootstrap-caldova25156897') -join [char]31),
            (@('api', 'repos/urruegg/caldova-hr-frontier/environments/bootstrap-caldova25156897/deployment-branch-policies') -join [char]31),
            (@('api', 'repos/urruegg/caldova-hr-frontier/environments/bootstrap-caldova25156897/variables') -join [char]31)
        )
    }

    It 'creates the absent ruleset with one exact BOM-free POST body and verifies read-back' {
        $state = New-TestGovernanceState
        $harness = New-NativeHarness -State $state
        $evidencePath = Write-TestJson -Value (New-TestBootstrapEvidence)

        $result = Invoke-TestGovernance -Harness $harness -EvidencePath $evidencePath

        $mutations = @(Get-MutationCalls -Harness $harness)
        $mutations | Should -HaveCount 1
        $mutation = $mutations[0]
        $mutation.ArgumentList | Should -Be @('api', '--method', 'POST', 'repos/urruegg/caldova-hr-frontier/rulesets', '--input', $mutation.InputPath)
        $mutation.BodyText | Should -BeExactly ((New-ExpectedPayload) | ConvertTo-Json -Depth 30 -Compress)
        $mutation.BodyHasBom | Should -BeFalse
        Test-Path -LiteralPath $mutation.InputPath | Should -BeFalse
        $result.Action | Should -BeExactly 'Create'
        $result.Status | Should -BeExactly 'Verified'
        $harness.Calls[-1].ArgumentList | Should -Be @('api', 'repos/urruegg/caldova-hr-frontier/rulesets/321')
    }

    It 'updates one drifted repository ruleset with PUT and no other mutation method' {
        $state = New-TestGovernanceState
        $state.Rulesets = @([ordered]@{ id = 321; name = 'main'; target = 'branch'; source_type = 'Repository'; source = $script:Repository; enforcement = 'evaluate' })
        $state.RulesetDetails['321'] = New-ExactRulesetDetail -Id 321
        $state.RulesetDetails['321'].enforcement = 'evaluate'
        $harness = New-NativeHarness -State $state
        $evidencePath = Write-TestJson -Value (New-TestBootstrapEvidence)

        $result = Invoke-TestGovernance -Harness $harness -EvidencePath $evidencePath

        $mutations = @(Get-MutationCalls -Harness $harness)
        $mutations | Should -HaveCount 1
        $mutations[0].ArgumentList | Should -Be @('api', '--method', 'PUT', 'repos/urruegg/caldova-hr-frontier/rulesets/321', '--input', $mutations[0].InputPath)
        $mutations[0].BodyText | Should -BeExactly ((New-ExpectedPayload) | ConvertTo-Json -Depth 30 -Compress)
        $result.Action | Should -BeExactly 'Update'
        $result.Status | Should -BeExactly 'Verified'
    }

    It 'is idempotent when the detailed ruleset and Environment contract are already exact' {
        $state = New-TestGovernanceState
        Set-ExactExistingRuleset -State $state
        $harness = New-NativeHarness -State $state
        $evidencePath = Write-TestJson -Value (New-TestBootstrapEvidence)

        $result = Invoke-TestGovernance -Harness $harness -EvidencePath $evidencePath

        @(Get-MutationCalls -Harness $harness) | Should -HaveCount 0
        $result.Action | Should -BeExactly 'None'
        $result.Status | Should -BeExactly 'Verified'
        @($harness.Calls | Where-Object { $_.ArgumentList[1] -ceq 'repos/urruegg/caldova-hr-frontier/rulesets/321' }) | Should -HaveCount 1
    }

    It 'fails after mutation when detailed ruleset read-back still drifts' {
        $state = New-TestGovernanceState
        $state.PreserveRulesetReadBackDrift = $true
        $harness = New-NativeHarness -State $state
        $evidencePath = Write-TestJson -Value (New-TestBootstrapEvidence)

        { Invoke-TestGovernance -Harness $harness -EvidencePath $evidencePath } | Should -Throw '*ruleset read-back*'
        @(Get-MutationCalls -Harness $harness) | Should -HaveCount 1
    }

    It 'rejects a duplicate desired ruleset name before any native command' {
        $desired = Get-Content -Raw -LiteralPath $script:DesiredStatePath | ConvertFrom-Json
        $desired.rulesets = @($desired.rulesets[0], (Copy-TestData -Value $desired.rulesets[0]))
        $desiredPath = Write-TestJson -Value $desired
        $state = New-TestGovernanceState
        $harness = New-NativeHarness -State $state
        $evidencePath = Write-TestJson -Value (New-TestBootstrapEvidence)

        { Invoke-TestGovernance -Harness $harness -EvidencePath $evidencePath -DesiredStatePath $desiredPath -WhatIf } | Should -Throw '*duplicate*ruleset*name*'
        $harness.Calls | Should -HaveCount 0
    }

    It 'rejects ambiguous repository-source ruleset matches without mutation' {
        $state = New-TestGovernanceState
        $state.Rulesets = @(
            [ordered]@{ id = 321; name = 'main'; target = 'branch'; source_type = 'Repository'; source = $script:Repository; enforcement = 'active' },
            [ordered]@{ id = 322; name = 'main'; target = 'branch'; source_type = 'Repository'; source = $script:Repository; enforcement = 'active' }
        )
        $harness = New-NativeHarness -State $state
        $evidencePath = Write-TestJson -Value (New-TestBootstrapEvidence)

        { Invoke-TestGovernance -Harness $harness -EvidencePath $evidencePath -WhatIf } | Should -Throw '*ambiguous*ruleset*'
        @(Get-MutationCalls -Harness $harness) | Should -HaveCount 0
    }

    It 'rejects a desired-name match from a non-repository source' {
        $state = New-TestGovernanceState
        $state.Rulesets = @([ordered]@{ id = 321; name = 'main'; target = 'branch'; source_type = 'Organization'; source = 'urruegg'; enforcement = 'active' })
        $harness = New-NativeHarness -State $state
        $evidencePath = Write-TestJson -Value (New-TestBootstrapEvidence)

        { Invoke-TestGovernance -Harness $harness -EvidencePath $evidencePath -WhatIf } | Should -Throw '*repository source*'
        @(Get-MutationCalls -Harness $harness) | Should -HaveCount 0
    }

    It 'rejects malformed invocation identifiers and the wrong repository before native calls' -ForEach @(
        @{ Name = 'wrong repository'; RepositoryValue = 'other/repository'; ValidatorValue = [long]101; BootstrapValue = [long]202 },
        @{ Name = 'malformed validator id'; RepositoryValue = 'urruegg/caldova-hr-frontier'; ValidatorValue = 'not-a-number'; BootstrapValue = [long]202 },
        @{ Name = 'non-positive validator id'; RepositoryValue = 'urruegg/caldova-hr-frontier'; ValidatorValue = [long]0; BootstrapValue = [long]202 },
        @{ Name = 'non-positive bootstrap id'; RepositoryValue = 'urruegg/caldova-hr-frontier'; ValidatorValue = [long]101; BootstrapValue = [long]-1 },
        @{ Name = 'same run ids'; RepositoryValue = 'urruegg/caldova-hr-frontier'; ValidatorValue = [long]101; BootstrapValue = [long]101 }
    ) {
        $state = New-TestGovernanceState
        $harness = New-NativeHarness -State $state
        $evidencePath = Write-TestJson -Value (New-TestBootstrapEvidence)

        { Invoke-TestGovernance -Harness $harness -EvidencePath $evidencePath -Repository $RepositoryValue -ValidatorRunId $ValidatorValue -BootstrapRunId $BootstrapValue -WhatIf } | Should -Throw
        $harness.Calls | Should -HaveCount 0
    }

    It 'rejects user resolution and administrator permission mismatches without mutation' -ForEach @(
        @{ Name = 'non-numeric user id'; UserIdText = 'not-a-number'; AdminText = 'true'; Error = '*user id*' },
        @{ Name = 'non-positive user id'; UserIdText = '0'; AdminText = 'true'; Error = '*user id*' },
        @{ Name = 'not an administrator'; UserIdText = '46865858'; AdminText = 'false'; Error = '*administrator*' },
        @{ Name = 'malformed permission'; UserIdText = '46865858'; AdminText = 'True'; Error = '*administrator*' }
    ) {
        $state = New-TestGovernanceState
        $state.UserIdText = $UserIdText
        $state.AdminText = $AdminText
        $harness = New-NativeHarness -State $state
        $evidencePath = Write-TestJson -Value (New-TestBootstrapEvidence)

        { Invoke-TestGovernance -Harness $harness -EvidencePath $evidencePath -WhatIf } | Should -Throw $Error
        @(Get-MutationCalls -Harness $harness) | Should -HaveCount 0
    }

    It 'rejects every validator workflow prerequisite mismatch' -ForEach @(
        @{ Name = 'run id'; Property = 'id'; Value = [long]999; Error = '*run id*' },
        @{ Name = 'branch'; Property = 'head_branch'; Value = 'pull/42/merge'; Error = '*main*' },
        @{ Name = 'status'; Property = 'status'; Value = 'in_progress'; Error = '*completed*' },
        @{ Name = 'conclusion'; Property = 'conclusion'; Value = 'failure'; Error = '*success*' },
        @{ Name = 'path'; Property = 'path'; Value = '.github/workflows/other.yml'; Error = '*workflow path*' },
        @{ Name = 'name'; Property = 'name'; Value = 'Other workflow'; Error = '*workflow name*' },
        @{ Name = 'repository'; Property = 'repository'; Value = ([ordered]@{ full_name = 'other/repository' }); Error = '*repository*' }
    ) {
        $state = New-TestGovernanceState
        $state.Runs['101'][$Property] = $Value
        $harness = New-NativeHarness -State $state
        $evidencePath = Write-TestJson -Value (New-TestBootstrapEvidence)

        { Invoke-TestGovernance -Harness $harness -EvidencePath $evidencePath -WhatIf } | Should -Throw $Error
        @(Get-MutationCalls -Harness $harness) | Should -HaveCount 0
    }

    It 'rejects every bootstrap workflow prerequisite mismatch' -ForEach @(
        @{ Name = 'run id'; Property = 'id'; Value = [long]999; Error = '*run id*' },
        @{ Name = 'branch'; Property = 'head_branch'; Value = 'feature/governance'; Error = '*main*' },
        @{ Name = 'status'; Property = 'status'; Value = 'queued'; Error = '*completed*' },
        @{ Name = 'conclusion'; Property = 'conclusion'; Value = 'cancelled'; Error = '*success*' },
        @{ Name = 'path'; Property = 'path'; Value = '.github/workflows/validate-repository.yml'; Error = '*workflow path*' },
        @{ Name = 'name'; Property = 'name'; Value = 'Validate repository'; Error = '*workflow name*' },
        @{ Name = 'repository'; Property = 'repository'; Value = ([ordered]@{ full_name = 'other/repository' }); Error = '*repository*' }
    ) {
        $state = New-TestGovernanceState
        $state.Runs['202'][$Property] = $Value
        $harness = New-NativeHarness -State $state
        $evidencePath = Write-TestJson -Value (New-TestBootstrapEvidence)

        { Invoke-TestGovernance -Harness $harness -EvidencePath $evidencePath -WhatIf } | Should -Throw $Error
        @(Get-MutationCalls -Harness $harness) | Should -HaveCount 0
    }

    It 'rejects each closed desired-state or allowlist mismatch before native calls' -ForEach @(
        @{ Name = 'unknown top property'; Configure = { param($value) $value | Add-Member -NotePropertyName unexpected -NotePropertyValue $true }; Error = '*unknown*property*' },
        @{ Name = 'unknown nested property'; Configure = { param($value) $value.rulesets[0].rules[2].parameters | Add-Member -NotePropertyName directPush -NotePropertyValue $true }; Error = '*unknown*property*' },
        @{ Name = 'wrong repository'; Configure = { param($value) $value.repository = 'other/repository' }; Error = '*repository*' },
        @{ Name = 'wrong target'; Configure = { param($value) $value.rulesets[0].target = 'tag' }; Error = '*target*' },
        @{ Name = 'inactive enforcement'; Configure = { param($value) $value.rulesets[0].enforcement = 'evaluate' }; Error = '*enforcement*' },
        @{ Name = 'organization administrator actor'; Configure = { param($value) $value.rulesets[0].bypassActors[0].actorType = 'OrganizationAdmin' }; Error = '*actor*' },
        @{ Name = 'repository role actor'; Configure = { param($value) $value.rulesets[0].bypassActors[0].actorType = 'RepositoryRole' }; Error = '*actor*' },
        @{ Name = 'team actor'; Configure = { param($value) $value.rulesets[0].bypassActors[0].actorType = 'Team' }; Error = '*actor*' },
        @{ Name = 'always bypass'; Configure = { param($value) $value.rulesets[0].bypassActors[0].bypassMode = 'always' }; Error = '*bypass*' },
        @{ Name = 'exempt bypass'; Configure = { param($value) $value.rulesets[0].bypassActors[0].bypassMode = 'exempt' }; Error = '*bypass*' },
        @{ Name = 'wrong status context'; Configure = { param($value) $value.rulesets[0].rules[3].parameters.requiredStatusChecks[0].context = 'validate' }; Error = '*status*context*' },
        @{ Name = 'string approval count'; Configure = { param($value) $value.rulesets[0].rules[2].parameters.requiredApprovingReviewCount = '1' }; Error = '*approval*count*' }
    ) {
        $desired = Get-Content -Raw -LiteralPath $script:DesiredStatePath | ConvertFrom-Json
        & $Configure $desired
        $desiredPath = Write-TestJson -Value $desired
        $state = New-TestGovernanceState
        $harness = New-NativeHarness -State $state
        $evidencePath = Write-TestJson -Value (New-TestBootstrapEvidence)

        { Invoke-TestGovernance -Harness $harness -EvidencePath $evidencePath -DesiredStatePath $desiredPath -WhatIf } | Should -Throw $Error
        $harness.Calls | Should -HaveCount 0
    }

    It 'rejects each cleanup evidence mismatch or extra property before native calls' -ForEach @(
        @{ Name = 'unknown top property'; Configure = { param($value) $value['Unexpected'] = $true }; Error = '*unknown*property*' },
        @{ Name = 'unknown assignment property'; Configure = { param($value) $value.Assignments[0]['Unexpected'] = $true }; Error = '*unknown*property*' },
        @{ Name = 'numeric schema version'; Configure = { param($value) $value.SchemaVersion = 1.0 }; Error = '*SchemaVersion*' },
        @{ Name = 'wrong bootstrap run'; Configure = { param($value) $value.BootstrapRunId = [long]999 }; Error = '*BootstrapRunId*' },
        @{ Name = 'string bootstrap run'; Configure = { param($value) $value.BootstrapRunId = '202' }; Error = '*BootstrapRunId*' },
        @{ Name = 'wrong tenant alias'; Configure = { param($value) $value.TenantAlias = 'other' }; Error = '*TenantAlias*' },
        @{ Name = 'wrong subscription'; Configure = { param($value) $value.SubscriptionId = '00000000-0000-0000-0000-000000000000' }; Error = '*SubscriptionId*' },
        @{ Name = 'malformed principal'; Configure = { param($value) $value.PrincipalObjectId = 'not-a-guid' }; Error = '*PrincipalObjectId*' },
        @{ Name = 'wrong scope'; Configure = { param($value) $value.Scope = '/subscriptions/00000000-0000-0000-0000-000000000000' }; Error = '*Scope*' },
        @{ Name = 'malformed verification time'; Configure = { param($value) $value.VerifiedUtc = 'not-a-time' }; Error = '*VerifiedUtc*' },
        @{ Name = 'verification time without UTC designator'; Configure = { param($value) $value.VerifiedUtc = '2026-09-20T12:00:00.0000000' }; Error = '*VerifiedUtc*' },
        @{ Name = 'stale verification time'; Configure = { param($value) $value.VerifiedUtc = [datetime]::UtcNow.AddHours(-25).ToString('o') }; Error = '*current*' },
        @{ Name = 'future verification time'; Configure = { param($value) $value.VerifiedUtc = [datetime]::UtcNow.AddMinutes(1).ToString('o') }; Error = '*current*' },
        @{ Name = 'one assignment'; Configure = { param($value) $value.Assignments = @($value.Assignments[0]) }; Error = '*exactly two*' },
        @{ Name = 'duplicate assignment id'; Configure = { param($value) $value.Assignments[1].Id = $value.Assignments[0].Id }; Error = '*unique*' },
        @{ Name = 'duplicate role'; Configure = { param($value) $value.Assignments[1].RoleName = 'Contributor'; $value.Assignments[1].RoleDefinitionId = $value.Assignments[0].RoleDefinitionId }; Error = '*exactly once*' },
        @{ Name = 'wrong role definition'; Configure = { param($value) $value.Assignments[0].RoleDefinitionId = "$($script:Scope)/providers/Microsoft.Authorization/roleDefinitions/00000000-0000-0000-0000-000000000000" }; Error = '*RoleDefinitionId*' },
        @{ Name = 'wrong assignment principal'; Configure = { param($value) $value.Assignments[0].PrincipalObjectId = '66666666-6666-6666-6666-666666666666' }; Error = '*principal*' },
        @{ Name = 'wrong assignment scope'; Configure = { param($value) $value.Assignments[0].Scope = '/subscriptions/00000000-0000-0000-0000-000000000000' }; Error = '*scope*' },
        @{ Name = 'present assignment'; Configure = { param($value) $value.Assignments[0].ReadBackStatus = 'Present' }; Error = '*Absent*' },
        @{ Name = 'malformed assignment id'; Configure = { param($value) $value.Assignments[0].Id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' }; Error = '*assignment Id*' },
        @{ Name = 'assignment resource id with malformed GUID'; Configure = { param($value) $value.Assignments[0].Id = "$($script:Scope)/providers/Microsoft.Authorization/roleAssignments/------------------------------------" }; Error = '*assignment Id*' },
        @{ Name = 'stale assignment verification'; Configure = { param($value) $value.Assignments[0].VerifiedUtc = [datetime]::UtcNow.AddHours(-25).ToString('o') }; Error = '*current*' }
    ) {
        $evidence = New-TestBootstrapEvidence
        & $Configure $evidence
        $evidencePath = Write-TestJson -Value $evidence
        $state = New-TestGovernanceState
        $harness = New-NativeHarness -State $state

        { Invoke-TestGovernance -Harness $harness -EvidencePath $evidencePath -WhatIf } | Should -Throw $Error
        $harness.Calls | Should -HaveCount 0
    }

    It 'rejects every Environment trust-contract mismatch before ruleset mutation' -ForEach @(
        @{ Name = 'environment name'; Configure = { param($state) $state.Environment.name = 'bootstrap-other' }; Error = '*Environment name*' },
        @{ Name = 'protected branches enabled'; Configure = { param($state) $state.Environment.deployment_branch_policy.protected_branches = $true }; Error = '*branch policy*' },
        @{ Name = 'custom branches disabled'; Configure = { param($state) $state.Environment.deployment_branch_policy.custom_branch_policies = $false }; Error = '*branch policy*' },
        @{ Name = 'missing reviewer rule'; Configure = { param($state) $state.Environment.protection_rules = @() }; Error = '*reviewer*' },
        @{ Name = 'self review prevented'; Configure = { param($state) $state.Environment.protection_rules[0].prevent_self_review = $true }; Error = '*self-review*' },
        @{ Name = 'wrong reviewer type'; Configure = { param($state) $state.Environment.protection_rules[0].reviewers[0].type = 'Team' }; Error = '*reviewer*' },
        @{ Name = 'wrong reviewer id'; Configure = { param($state) $state.Environment.protection_rules[0].reviewers[0].reviewer.id = 999 }; Error = '*reviewer*' },
        @{ Name = 'wrong reviewer login'; Configure = { param($state) $state.Environment.protection_rules[0].reviewers[0].reviewer.login = 'other' }; Error = '*reviewer*' },
        @{ Name = 'extra branch policy'; Configure = { param($state) $state.DeploymentBranchPolicies.total_count = 2; $state.DeploymentBranchPolicies.branch_policies += [ordered]@{ id = 8002; name = 'dev'; type = 'branch' } }; Error = '*deployment branch*' },
        @{ Name = 'tag policy'; Configure = { param($state) $state.DeploymentBranchPolicies.branch_policies[0].type = 'tag' }; Error = '*deployment branch*' },
        @{ Name = 'wrong branch'; Configure = { param($state) $state.DeploymentBranchPolicies.branch_policies[0].name = 'dev' }; Error = '*deployment branch*' },
        @{ Name = 'missing variable'; Configure = { param($state) $state.EnvironmentVariables.total_count = 2; $state.EnvironmentVariables.variables = @($state.EnvironmentVariables.variables[0..1]) }; Error = '*variable names*' },
        @{ Name = 'extra variable'; Configure = { param($state) $state.EnvironmentVariables.total_count = 4; $state.EnvironmentVariables.variables += [ordered]@{ name = 'EXTRA'; value = 'x' } }; Error = '*variable names*' },
        @{ Name = 'duplicate variable'; Configure = { param($state) $state.EnvironmentVariables.variables[2].name = 'AZURE_TENANT_ID' }; Error = '*variable names*' }
    ) {
        $state = New-TestGovernanceState
        & $Configure $state
        $harness = New-NativeHarness -State $state
        $evidencePath = Write-TestJson -Value (New-TestBootstrapEvidence)

        { Invoke-TestGovernance -Harness $harness -EvidencePath $evidencePath } | Should -Throw $Error
        @(Get-MutationCalls -Harness $harness) | Should -HaveCount 0
    }

    It 'never issues PATCH or DELETE and never mutates an Environment or Environment variable' {
        $state = New-TestGovernanceState
        $harness = New-NativeHarness -State $state
        $evidencePath = Write-TestJson -Value (New-TestBootstrapEvidence)

        $null = Invoke-TestGovernance -Harness $harness -EvidencePath $evidencePath

        @($harness.Calls | Where-Object { $_.ArgumentList -contains 'PATCH' -or $_.ArgumentList -contains 'DELETE' }) | Should -HaveCount 0
        @($harness.Calls | Where-Object {
            $_.ArgumentList -contains '--method' -and
            ($_.ArgumentList -join '/') -match '/environments/'
        }) | Should -HaveCount 0
    }
}