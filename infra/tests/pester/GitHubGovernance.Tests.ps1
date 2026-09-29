Set-StrictMode -Version Latest

Describe 'Lean GitHub governance activation' {
    BeforeAll {
        $script:RepositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
        $script:ScriptPath = Join-Path $script:RepositoryRoot 'infra\src\scripts\Enable-GitHubGovernance.ps1'
        $script:DesiredStatePath = Join-Path $script:RepositoryRoot 'infra\src\config\github\main-ruleset.json'
        $script:SchemaPath = Join-Path $script:RepositoryRoot 'infra\src\config\schemas\github-ruleset.schema.json'
        $script:Repository = 'urruegg/caldova-hr-frontier'
        $script:ValidatorRunId = [long]101
        $script:MainSha = '1111111111111111111111111111111111111111'

        $tokens = $null
        $parseErrors = $null
        $scriptAst = [System.Management.Automation.Language.Parser]::ParseFile(
            $script:ScriptPath,
            [ref]$tokens,
            [ref]$parseErrors
        )
        if ($parseErrors.Count -gt 0) {
            throw ($parseErrors | ForEach-Object Message | Out-String)
        }
        foreach ($statement in @($scriptAst.EndBlock.Statements)) {
            if ($statement -is [System.Management.Automation.Language.FunctionDefinitionAst]) {
                Invoke-Expression $statement.Extent.Text
            }
        }

        function script:Copy-TestData {
            param([Parameter(Mandatory)][object]$Value)

            $Value | ConvertTo-Json -Depth 30 | ConvertFrom-Json
        }

        function script:Write-TestJson {
            param([Parameter(Mandatory)][object]$Value)

            $path = Join-Path $TestDrive "$([guid]::NewGuid()).json"
            [System.IO.File]::WriteAllText(
                $path,
                ($Value | ConvertTo-Json -Depth 30),
                [System.Text.UTF8Encoding]::new($false)
            )
            $path
        }

        function script:New-ExpectedPayload {
            [ordered]@{
                name = 'main'
                target = 'branch'
                enforcement = 'active'
                bypass_actors = @()
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
                            require_code_owner_review = $false
                            require_last_push_approval = $false
                            required_approving_review_count = 0
                            required_review_thread_resolution = $true
                            allowed_merge_methods = @('squash')
                        }
                    },
                    [ordered]@{
                        type = 'required_status_checks'
                        parameters = [ordered]@{
                            do_not_enforce_on_create = $false
                            required_status_checks = @(
                                [ordered]@{
                                    context = 'Repository setup validation'
                                    integration_id = 15368
                                }
                            )
                            strict_required_status_checks_policy = $true
                        }
                    }
                )
            }
        }

        function script:New-ExactRulesetDetail {
            param(
                [long]$Id = 321,
                [string]$Name = 'main'
            )

            $payload = New-ExpectedPayload
            $payload.name = $Name
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

        function script:New-TestState {
            [ordered]@{
                MainSha = $script:MainSha
                MainReadCount = 0
                ValidatorReadCount = 0
                BeforeSecondSnapshot = $null
                RepositorySettings = [ordered]@{
                    default_branch = 'main'
                    allow_merge_commit = $false
                    allow_rebase_merge = $false
                    allow_squash_merge = $true
                    delete_branch_on_merge = $true
                    has_projects = $false
                }
                ValidatorRun = [ordered]@{
                    id = $script:ValidatorRunId
                    path = '.github/workflows/validate-repository.yml'
                    head_branch = 'main'
                    head_sha = $script:MainSha
                    status = 'completed'
                    conclusion = 'success'
                }
                ValidatorJobs = @(
                    [ordered]@{
                        id = 7001
                        name = 'Repository setup validation'
                        status = 'completed'
                        conclusion = 'success'
                    }
                )
                Codeowners = "* @urruegg`n"
                Rulesets = @()
                AdditionalRulesetPages = @()
                RulesetDetails = [ordered]@{}
                NextRulesetId = [long]321
                DependabotSecurityUpdates = $false
                PreserveRepositoryDrift = $false
                PreserveRulesetDrift = $false
                PreserveDependabotDrift = $false
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
            $repository = $script:Repository
            $validatorRunId = $script:ValidatorRunId
            $runner = {
                param(
                    [Parameter(Mandatory)][string]$FilePath,
                    [Parameter(Mandatory)][string[]]$ArgumentList
                )

                if ($FilePath -cne 'gh') {
                    throw "Unexpected native executable: $FilePath"
                }
                if (($ArgumentList -join '/') -match 'actions/environments') {
                    throw 'GitHub Environment APIs are forbidden.'
                }

                $record = [ordered]@{
                    FilePath = $FilePath
                    ArgumentList = @($ArgumentList)
                    BodyText = $null
                    BodyHasBom = $null
                }
                $inputIndex = [array]::IndexOf($ArgumentList, '--input')
                $body = $null
                if ($inputIndex -ge 0) {
                    $inputPath = [string]$ArgumentList[$inputIndex + 1]
                    $bytes = [System.IO.File]::ReadAllBytes($inputPath)
                    $record.BodyText = [System.Text.Encoding]::UTF8.GetString($bytes)
                    $record.BodyHasBom = $bytes.Length -ge 3 -and
                        $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191
                    $body = $record.BodyText | ConvertFrom-Json
                }
                $calls.Add([pscustomobject]$record) | Out-Null

                $mainArguments = @('api', "repos/$repository/git/ref/heads/main")
                if (& $testExactArguments -Actual $ArgumentList -Expected $mainArguments) {
                    $State.MainReadCount++
                    if ($State.MainReadCount -eq 2 -and $null -ne $State.BeforeSecondSnapshot) {
                        & $State.BeforeSecondSnapshot $State
                    }
                    return [pscustomobject]@{
                        ExitCode = 0
                        StdOut = ([ordered]@{ object = [ordered]@{ sha = $State.MainSha } } | ConvertTo-Json -Compress)
                        StdErr = ''
                    }
                }

                $runArguments = @('api', "repos/$repository/actions/runs/$validatorRunId")
                if (& $testExactArguments -Actual $ArgumentList -Expected $runArguments) {
                    $State.ValidatorReadCount++
                    return [pscustomobject]@{
                        ExitCode = 0
                        StdOut = ($State.ValidatorRun | ConvertTo-Json -Depth 10 -Compress)
                        StdErr = ''
                    }
                }

                $jobsArguments = @('api', "repos/$repository/actions/runs/$validatorRunId/jobs?per_page=100")
                if (& $testExactArguments -Actual $ArgumentList -Expected $jobsArguments) {
                    return [pscustomobject]@{
                        ExitCode = 0
                        StdOut = ([ordered]@{
                            total_count = @($State.ValidatorJobs).Count
                            jobs = @($State.ValidatorJobs)
                        } | ConvertTo-Json -Depth 10 -Compress)
                        StdErr = ''
                    }
                }

                $ownersArguments = @(
                    'api',
                    '-H',
                    'Accept: application/vnd.github.raw+json',
                    "repos/$repository/contents/.github/CODEOWNERS?ref=$($State.MainSha)"
                )
                if (& $testExactArguments -Actual $ArgumentList -Expected $ownersArguments) {
                    return [pscustomobject]@{ ExitCode = 0; StdOut = [string]$State.Codeowners; StdErr = '' }
                }

                $repositoryArguments = @('api', "repos/$repository")
                if (& $testExactArguments -Actual $ArgumentList -Expected $repositoryArguments) {
                    return [pscustomobject]@{
                        ExitCode = 0
                        StdOut = ($State.RepositorySettings | ConvertTo-Json -Depth 10 -Compress)
                        StdErr = ''
                    }
                }

                $rulesetsArguments = @(
                    'api',
                    '--paginate',
                    '--slurp',
                    "repos/$repository/rulesets?includes_parents=true&per_page=100"
                )
                if (& $testExactArguments -Actual $ArgumentList -Expected $rulesetsArguments) {
                    $pageTexts = [System.Collections.Generic.List[string]]::new()
                    $pageTexts.Add((ConvertTo-Json -InputObject @($State.Rulesets) -Depth 20 -Compress))
                    foreach ($page in @($State.AdditionalRulesetPages)) {
                        $pageTexts.Add((ConvertTo-Json -InputObject @($page) -Depth 20 -Compress))
                    }
                    return [pscustomobject]@{
                        ExitCode = 0
                        StdOut = '[' + ($pageTexts -join ',') + ']'
                        StdErr = ''
                    }
                }

                if ($ArgumentList.Count -eq 2 -and
                    $ArgumentList[0] -ceq 'api' -and
                    $ArgumentList[1] -match '/rulesets/(\d+)$') {
                    $id = $Matches[1]
                    if (-not $State.RulesetDetails.Contains($id)) {
                        throw "Missing ruleset detail for $id."
                    }
                    return [pscustomobject]@{
                        ExitCode = 0
                        StdOut = ($State.RulesetDetails[$id] | ConvertTo-Json -Depth 30 -Compress)
                        StdErr = ''
                    }
                }

                $dependabotArguments = @(
                    'api',
                    '--include',
                    "repos/$repository/automated-security-fixes"
                )
                if (& $testExactArguments -Actual $ArgumentList -Expected $dependabotArguments) {
                    if ($State.DependabotSecurityUpdates) {
                        return [pscustomobject]@{ ExitCode = 0; StdOut = "HTTP/2.0 204 No Content`n"; StdErr = '' }
                    }
                    return [pscustomobject]@{ ExitCode = 1; StdOut = "HTTP/2.0 404 Not Found`n"; StdErr = 'gh: Not Found (HTTP 404)' }
                }

                if ($ArgumentList.Count -eq 6 -and
                    $ArgumentList[0] -ceq 'api' -and
                    $ArgumentList[1] -ceq '--method' -and
                    $ArgumentList[2] -ceq 'PATCH' -and
                    $ArgumentList[3] -ceq "repos/$repository" -and
                    $ArgumentList[4] -ceq '--input') {
                    if (-not $State.PreserveRepositoryDrift) {
                        foreach ($property in @(
                            'allow_merge_commit',
                            'allow_rebase_merge',
                            'allow_squash_merge',
                            'delete_branch_on_merge',
                            'has_projects'
                        )) {
                            $State.RepositorySettings[$property] = $body.$property
                        }
                    }
                    return [pscustomobject]@{ ExitCode = 0; StdOut = '{}'; StdErr = '' }
                }

                if ($ArgumentList.Count -eq 6 -and
                    $ArgumentList[0] -ceq 'api' -and
                    $ArgumentList[1] -ceq '--method' -and
                    $ArgumentList[2] -cin @('POST', 'PUT') -and
                    $ArgumentList[3] -match '/rulesets(?:/(\d+))?$' -and
                    $ArgumentList[4] -ceq '--input') {
                    $id = if ($Matches[1]) { [long]$Matches[1] } else { [long]$State.NextRulesetId }
                    if (-not $Matches[1]) {
                        $State.Rulesets = @(
                            $State.Rulesets
                            [ordered]@{
                                id = $id
                                name = $body.name
                                target = $body.target
                                source_type = 'Repository'
                                source = $repository
                                enforcement = $body.enforcement
                            }
                        )
                    }
                    if (-not $State.PreserveRulesetDrift) {
                        $State.RulesetDetails[[string]$id] = [ordered]@{
                            id = $id
                            name = $body.name
                            target = $body.target
                            source_type = 'Repository'
                            source = $repository
                            enforcement = $body.enforcement
                            bypass_actors = @($body.bypass_actors)
                            conditions = $body.conditions
                            rules = @($body.rules)
                        }
                    }
                    return [pscustomobject]@{
                        ExitCode = 0
                        StdOut = ([ordered]@{ id = $id } | ConvertTo-Json -Compress)
                        StdErr = ''
                    }
                }

                $enableArguments = @(
                    'api',
                    '--method',
                    'PUT',
                    "repos/$repository/automated-security-fixes"
                )
                if (& $testExactArguments -Actual $ArgumentList -Expected $enableArguments) {
                    if (-not $State.PreserveDependabotDrift) {
                        $State.DependabotSecurityUpdates = $true
                    }
                    return [pscustomobject]@{ ExitCode = 0; StdOut = ''; StdErr = '' }
                }

                throw "Unexpected gh argument array: $($ArgumentList | ConvertTo-Json -Compress)"
            }.GetNewClosure()

            [pscustomobject]@{
                State = $State
                Calls = $calls
                Runner = $runner
            }
        }

        function script:Get-MutationCalls {
            param([Parameter(Mandatory)][object]$Harness)

            @($Harness.Calls | Where-Object {
                $methodIndex = [array]::IndexOf($_.ArgumentList, '--method')
                $methodIndex -ge 0 -and $_.ArgumentList[$methodIndex + 1] -cin @('POST', 'PUT', 'PATCH', 'DELETE')
            })
        }

        function script:Invoke-TestGovernance {
            param(
                [Parameter(Mandatory)][object]$Harness,
                [string]$DesiredStatePath = $script:DesiredStatePath,
                [switch]$WhatIf
            )

            Invoke-GitHubGovernanceCore `
                -Repository $script:Repository `
                -ValidatorRunId $script:ValidatorRunId `
                -DesiredStatePath $DesiredStatePath `
                -NativeCommandRunner $Harness.Runner `
                -ShouldProcess { param([string]$Target, [string]$Action) $true } `
                -IsWhatIf ([bool]$WhatIf)
        }

        function script:Assert-ClosedSchemaNode {
            param([Parameter(Mandatory)][object]$Node)

            if ($null -eq $Node -or $Node -is [string] -or $Node -is [ValueType]) {
                return
            }
            if ($Node -is [System.Array]) {
                foreach ($item in @($Node)) {
                    Assert-ClosedSchemaNode -Node $item
                }
                return
            }

            if ([string]$Node.type -ceq 'object') {
                $Node.additionalProperties | Should -BeFalse
            }
            foreach ($property in @($Node.PSObject.Properties)) {
                Assert-ClosedSchemaNode -Node $property.Value
            }
        }
    }

    It 'requires only repository validator and desired state inputs' {
        $command = Get-Command $script:ScriptPath
        @($command.Parameters.Keys) | Should -Contain 'Repository'
        @($command.Parameters.Keys) | Should -Contain 'ValidatorRunId'
        @($command.Parameters.Keys) | Should -Contain 'DesiredStatePath'
        foreach ($removed in @('BootstrapRunId', 'BootstrapEvidencePath', 'PublicTenantKey', 'TenantConfigurationPath')) {
            @($command.Parameters.Keys) | Should -Not -Contain $removed
        }
    }

    It 'ships the exact lean repository settings and single required check' {
        $state = Get-Content -Raw -LiteralPath $script:DesiredStatePath | ConvertFrom-Json
        $state.repositorySettings.defaultBranch | Should -BeExactly 'main'
        $state.repositorySettings.allowMergeCommit | Should -BeFalse
        $state.repositorySettings.allowRebaseMerge | Should -BeFalse
        $state.repositorySettings.allowSquashMerge | Should -BeTrue
        $state.repositorySettings.deleteBranchOnMerge | Should -BeTrue
        $state.repositorySettings.hasProjects | Should -BeFalse
        $state.security.dependabotSecurityUpdates | Should -BeTrue
        @($state.rulesets[0].bypassActors).Count | Should -Be 0
        $pullRequest = @($state.rulesets[0].rules | Where-Object type -eq 'pull_request')[0]
        $pullRequest.parameters.allowedMergeMethods | Should -Be @('squash')
        $pullRequest.parameters.requiredApprovingReviewCount | Should -Be 0
        $pullRequest.parameters.requireCodeOwnerReview | Should -BeFalse
        $pullRequest.parameters.requiredReviewThreadResolution | Should -BeTrue
        $checks = @($state.rulesets[0].rules | Where-Object type -eq 'required_status_checks')[0]
        @($checks.parameters.requiredStatusChecks.context) | Should -Be @('Repository setup validation')

        $schema = Get-Content -Raw -LiteralPath $script:SchemaPath | ConvertFrom-Json
        $schema.'$schema' | Should -BeExactly 'https://json-schema.org/draft/2020-12/schema'
        Assert-ClosedSchemaNode -Node $schema
    }

    It 'returns a closed WhatIf proposal and performs zero mutations' {
        $state = New-TestState
        $state.RepositorySettings.allow_merge_commit = $true
        $harness = New-NativeHarness -State $state

        $result = Invoke-TestGovernance -Harness $harness -WhatIf

        @($result.PSObject.Properties.Name) | Should -Be @(
            'Repository',
            'ValidatorRunId',
            'DesiredStatePath',
            'CurrentMainSha',
            'RepositorySettingsAction',
            'RulesetAction',
            'RulesetMethod',
            'RulesetEndpoint',
            'DependabotSecurityUpdatesAction',
            'RulesetPayload',
            'PreviousState',
            'DesiredState',
            'Status'
        )
        $result.RepositorySettingsAction | Should -BeExactly 'Update'
        $result.RulesetAction | Should -BeExactly 'Create'
        $result.DependabotSecurityUpdatesAction | Should -BeExactly 'Enable'
        ($result.RulesetPayload | ConvertTo-Json -Depth 30 -Compress) |
            Should -BeExactly ((New-ExpectedPayload) | ConvertTo-Json -Depth 30 -Compress)
        @(Get-MutationCalls -Harness $harness) | Should -HaveCount 0
    }

    It 'applies only the five drifted settings exact ruleset and Dependabot update then verifies read-back' {
        $state = New-TestState
        $state.RepositorySettings.allow_merge_commit = $true
        $state.RepositorySettings.allow_rebase_merge = $true
        $state.RepositorySettings.allow_squash_merge = $false
        $state.RepositorySettings.delete_branch_on_merge = $false
        $state.RepositorySettings.has_projects = $true
        $harness = New-NativeHarness -State $state

        $result = Invoke-TestGovernance -Harness $harness

        $result.Status | Should -BeExactly 'Verified'
        $mutations = @(Get-MutationCalls -Harness $harness)
        $mutations | Should -HaveCount 3
        $repositoryMutation = @($mutations | Where-Object { $_.ArgumentList -contains 'PATCH' })[0]
        @((($repositoryMutation.BodyText | ConvertFrom-Json).PSObject.Properties.Name)) | Should -Be @(
            'allow_merge_commit',
            'allow_rebase_merge',
            'allow_squash_merge',
            'delete_branch_on_merge',
            'has_projects'
        )
        $repositoryMutation.BodyHasBom | Should -BeFalse
        @($harness.Calls | Where-Object FilePath -ne 'gh') | Should -HaveCount 0
        @($harness.Calls | Where-Object { ($_.ArgumentList -join '/') -match 'actions/environments' }) |
            Should -HaveCount 0
    }

    It 'updates the existing stable ruleset id and is idempotent after verification' {
        $state = New-TestState
        $state.DependabotSecurityUpdates = $true
        $state.Rulesets = @(
            [ordered]@{
                id = 321
                name = 'main'
                target = 'branch'
                source_type = 'Repository'
                source = $script:Repository
                enforcement = 'active'
            }
        )
        $state.RulesetDetails['321'] = New-ExactRulesetDetail
        $state.RulesetDetails['321'].rules[2].parameters.required_approving_review_count = 1
        $harness = New-NativeHarness -State $state

        $first = Invoke-TestGovernance -Harness $harness
        $first.Status | Should -BeExactly 'Verified'
        $ruleMutation = @(Get-MutationCalls -Harness $harness)
        $ruleMutation | Should -HaveCount 1
        $ruleMutation[0].ArgumentList | Should -Contain 'repos/urruegg/caldova-hr-frontier/rulesets/321'

        $callCount = $harness.Calls.Count
        $second = Invoke-TestGovernance -Harness $harness
        $second.Status | Should -BeExactly 'Verified'
        $second.RepositorySettingsAction | Should -BeExactly 'None'
        $second.RulesetAction | Should -BeExactly 'None'
        $second.DependabotSecurityUpdatesAction | Should -BeExactly 'None'
        @(Get-MutationCalls -Harness $harness | Select-Object -Skip 1) | Should -HaveCount 0
        $harness.Calls.Count | Should -BeGreaterThan $callCount
    }

    It 'rejects an invalid validator run before mutation' -ForEach @(
        @{ Name = 'not completed'; Property = 'status'; Value = 'in_progress' },
        @{ Name = 'not successful'; Property = 'conclusion'; Value = 'failure' },
        @{ Name = 'wrong branch'; Property = 'head_branch'; Value = 'feature' },
        @{ Name = 'wrong sha'; Property = 'head_sha'; Value = '2222222222222222222222222222222222222222' },
        @{ Name = 'wrong workflow'; Property = 'path'; Value = '.github/workflows/other.yml' }
    ) {
        $state = New-TestState
        $state.ValidatorRun[$Property] = $Value
        $harness = New-NativeHarness -State $state

        { Invoke-TestGovernance -Harness $harness -WhatIf } |
            Should -Throw '*successful completed current-main validate-repository workflow*'
        @(Get-MutationCalls -Harness $harness) | Should -HaveCount 0
    }

    It 'requires exactly one successful Repository setup validation job' -ForEach @(
        @{ Name = 'missing'; Jobs = @() },
        @{ Name = 'duplicate'; Jobs = @(
            [ordered]@{ name = 'Repository setup validation'; conclusion = 'success' },
            [ordered]@{ name = 'Repository setup validation'; conclusion = 'success' }
        ) },
        @{ Name = 'wrong name'; Jobs = @([ordered]@{ name = 'Other'; conclusion = 'success' }) },
        @{ Name = 'failed'; Jobs = @([ordered]@{ name = 'Repository setup validation'; conclusion = 'failure' }) }
    ) {
        $state = New-TestState
        $state.ValidatorJobs = $Jobs
        $harness = New-NativeHarness -State $state

        { Invoke-TestGovernance -Harness $harness -WhatIf } |
            Should -Throw '*exactly one successful*Repository setup validation*'
        @(Get-MutationCalls -Harness $harness) | Should -HaveCount 0
    }

    It 'requires a non-empty current-main CODEOWNERS ownership map' -ForEach @(
        @{ Name = 'empty'; Value = '' },
        @{ Name = 'comments only'; Value = "# owner map pending`n" }
    ) {
        $state = New-TestState
        $state.Codeowners = $Value
        $harness = New-NativeHarness -State $state

        { Invoke-TestGovernance -Harness $harness -WhatIf } | Should -Throw '*CODEOWNERS*ownership map*'
        @(Get-MutationCalls -Harness $harness) | Should -HaveCount 0
    }

    It 'rejects a non-integer GitHub Actions integration id before native calls' {
        $desired = Get-Content -Raw -LiteralPath $script:DesiredStatePath | ConvertFrom-Json
        $desired.rulesets[0].rules[3].parameters.requiredStatusChecks[0].integrationId = '15368'
        $desiredPath = Write-TestJson -Value $desired
        $state = New-TestState
        $harness = New-NativeHarness -State $state

        { Invoke-TestGovernance -Harness $harness -DesiredStatePath $desiredPath -WhatIf } |
            Should -Throw '*integrationId*integer*'
        $harness.Calls | Should -HaveCount 0
    }

    It 'rejects current-main movement immediately before mutation' {
        $state = New-TestState
        $state.BeforeSecondSnapshot = {
            param($currentState)
            $currentState.MainSha = '2222222222222222222222222222222222222222'
            $currentState.ValidatorRun.head_sha = $currentState.MainSha
        }
        $harness = New-NativeHarness -State $state

        { Invoke-TestGovernance -Harness $harness } | Should -Throw '*current main*changed*'
        @(Get-MutationCalls -Harness $harness) | Should -HaveCount 0
    }

    It 'rejects a duplicate main-applicable ruleset found on a later page' {
        $state = New-TestState
        $state.AdditionalRulesetPages = @(
            @(
                [ordered]@{
                    id = 654
                    name = 'legacy-main'
                    target = 'branch'
                    source_type = 'Repository'
                    source = $script:Repository
                    enforcement = 'active'
                }
            )
        )
        $state.RulesetDetails['654'] = New-ExactRulesetDetail -Id 654 -Name 'legacy-main'
        $harness = New-NativeHarness -State $state

        { Invoke-TestGovernance -Harness $harness -WhatIf } | Should -Throw '*additional active*main*'
        @(Get-MutationCalls -Harness $harness) | Should -HaveCount 0
    }

    It 'rejects an inherited active ruleset that also applies to main' {
        $state = New-TestState
        $state.Rulesets = @(
            [ordered]@{
                id = 655
                name = 'organization-main'
                target = 'branch'
                source_type = 'Organization'
                source = 'urruegg'
                enforcement = 'active'
            }
        )
        $state.RulesetDetails['655'] = New-ExactRulesetDetail -Id 655 -Name 'organization-main'
        $state.RulesetDetails['655'].source_type = 'Organization'
        $state.RulesetDetails['655'].source = 'urruegg'
        $harness = New-NativeHarness -State $state

        { Invoke-TestGovernance -Harness $harness -WhatIf } | Should -Throw '*additional active*main*'
        @(Get-MutationCalls -Harness $harness) | Should -HaveCount 0
    }

    It 'rejects repository setting drift after mutation' {
        $state = New-TestState
        $state.RepositorySettings.allow_merge_commit = $true
        $state.PreserveRepositoryDrift = $true
        $harness = New-NativeHarness -State $state

        { Invoke-TestGovernance -Harness $harness } | Should -Throw '*repository settings*read-back*'
    }

    It 'rejects ruleset drift after mutation' {
        $state = New-TestState
        $state.DependabotSecurityUpdates = $true
        $state.Rulesets = @(
            [ordered]@{
                id = 321
                name = 'main'
                target = 'branch'
                source_type = 'Repository'
                source = $script:Repository
                enforcement = 'active'
            }
        )
        $state.RulesetDetails['321'] = New-ExactRulesetDetail
        $state.RulesetDetails['321'].rules[2].parameters.required_approving_review_count = 1
        $state.PreserveRulesetDrift = $true
        $harness = New-NativeHarness -State $state

        { Invoke-TestGovernance -Harness $harness } | Should -Throw '*ruleset*read-back*'
    }

    It 'rejects Dependabot security update drift after mutation' {
        $state = New-TestState
        $state.PreserveDependabotDrift = $true
        $harness = New-NativeHarness -State $state

        { Invoke-TestGovernance -Harness $harness } | Should -Throw '*Dependabot security updates*read-back*'
    }

    It 'preserves paginated ruleset enumeration' {
        $runner = {
            param([string]$FilePath, [string[]]$ArgumentList)
            [pscustomobject]@{
                ExitCode = 0
                StdOut = '[[{"id":1}],[{"id":2}]]'
                StdErr = ''
            }
        }

        $items = Invoke-GhPagedJson -Runner $runner -Endpoint 'example' -Context 'Paged example'

        @($items.id) | Should -Be @(1, 2)
    }

    It 'preserves supported main-target fnmatch behavior' -ForEach @(
        @{ Name = 'all'; Pattern = '~ALL'; Expected = $true },
        @{ Name = 'default'; Pattern = '~DEFAULT_BRANCH'; Expected = $true },
        @{ Name = 'globstar'; Pattern = 'refs/**/main'; Expected = $true },
        @{ Name = 'single star boundary'; Pattern = 'refs/heads/*/*'; Expected = $false },
        @{ Name = 'class'; Pattern = 'refs/heads/[m]ain'; Expected = $true }
    ) {
        Test-RefPatternMatchesMain -Pattern $Pattern -DefaultBranch 'main' | Should -Be $Expected
    }
}
