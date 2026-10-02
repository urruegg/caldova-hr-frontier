Set-StrictMode -Version Latest

Describe 'Tenant lifecycle prerequisite graph' {
    BeforeAll {
        $script:RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
        $script:ModulePath = Join-Path $script:RepositoryRoot 'infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1'
        Import-Module $script:ModulePath -Force

        $script:DigestA = 'a' * 64
        $script:DigestB = 'b' * 64
        $script:DigestC = 'c' * 64

        if ($null -eq ('TenantLifecycleGraphCodePropertyAccessor' -as [type])) {
            Add-Type -TypeDefinition @'
using System;
using System.Management.Automation;

public static class TenantLifecycleGraphCodePropertyAccessor
{
    public static object Get(PSObject instance)
    {
        throw new InvalidOperationException();
    }
}
'@
        }
        $script:HiddenCodePropertyGetter = [TenantLifecycleGraphCodePropertyAccessor].GetMethod('Get')

        function New-GraphNode {
            param(
                [Parameter(Mandatory)][string]$Id,
                [string[]]$PrerequisiteIds = @(),
                [string]$RequiredOutcome = 'Passed',
                [string]$InputDigest = $script:DigestA,
                [string]$Kind = 'Action',
                [string]$Stage = 'Synthetic'
            )

            [pscustomobject][ordered]@{
                id = $Id
                kind = $Kind
                prerequisiteIds = @($PrerequisiteIds)
                requiredOutcome = $RequiredOutcome
                inputDigest = $InputDigest
                stage = $Stage
            }
        }

        function New-GraphOutcome {
            param(
                [Parameter(Mandatory)][string]$Id,
                [Parameter(Mandatory)][string]$Classification,
                [string]$Status = 'Passed',
                [string]$InputDigest = $script:DigestA,
                [AllowNull()][object]$ReadBackDigest = $null
            )

            [pscustomobject][ordered]@{
                id = $Id
                classification = $Classification
                status = $Status
                inputDigest = $InputDigest
                readBackDigest = $ReadBackDigest
            }
        }
    }

    It 'uses ordinal IDs for deterministic topological order for input permutation <InputOrder>' -ForEach @(
        @{ InputOrder = 'deploy,zeta,a,A' }
        @{ InputOrder = 'deploy,zeta,A,a' }
        @{ InputOrder = 'deploy,a,zeta,A' }
        @{ InputOrder = 'deploy,a,A,zeta' }
        @{ InputOrder = 'deploy,A,zeta,a' }
        @{ InputOrder = 'deploy,A,a,zeta' }
        @{ InputOrder = 'zeta,deploy,a,A' }
        @{ InputOrder = 'zeta,deploy,A,a' }
        @{ InputOrder = 'zeta,a,deploy,A' }
        @{ InputOrder = 'zeta,a,A,deploy' }
        @{ InputOrder = 'zeta,A,deploy,a' }
        @{ InputOrder = 'zeta,A,a,deploy' }
        @{ InputOrder = 'a,deploy,zeta,A' }
        @{ InputOrder = 'a,deploy,A,zeta' }
        @{ InputOrder = 'a,zeta,deploy,A' }
        @{ InputOrder = 'a,zeta,A,deploy' }
        @{ InputOrder = 'a,A,deploy,zeta' }
        @{ InputOrder = 'a,A,zeta,deploy' }
        @{ InputOrder = 'A,deploy,zeta,a' }
        @{ InputOrder = 'A,deploy,a,zeta' }
        @{ InputOrder = 'A,zeta,deploy,a' }
        @{ InputOrder = 'A,zeta,a,deploy' }
        @{ InputOrder = 'A,a,deploy,zeta' }
        @{ InputOrder = 'A,a,zeta,deploy' }
    ) {
        $nodes = foreach ($id in ($InputOrder -split ',')) {
            switch -CaseSensitive ($id) {
                'deploy' { New-GraphNode -Id 'deploy' -PrerequisiteIds @('zeta', 'a', 'A') }
                'zeta' { New-GraphNode -Id 'zeta' }
                'a' { New-GraphNode -Id 'a' }
                'A' { New-GraphNode -Id 'A' }
            }
        }

        $result = @(Resolve-TenantLifecycleGraph -Nodes $nodes -ObservedOutcomes @())

        ($result.id -join ',') | Should -BeExactly 'A,a,zeta,deploy'
        ($result[-1].blockingPrerequisiteIds -join ',') | Should -BeExactly 'A,a,zeta'
        $result[-1].canExecute | Should -BeFalse
    }

    It 'rejects a node with fields outside the closed node contract' {
        $node = New-GraphNode -Id 'assessment'
        $node | Add-Member -NotePropertyName providerCommand -NotePropertyValue 'not-allowed'

        {
            Resolve-TenantLifecycleGraph -Nodes @($node) -ObservedOutcomes @()
        } | Should -Throw -ExpectedMessage 'TenantLifecycle.Graph.InvalidNode'
    }

    It 'rejects a hidden <MemberType> outside the closed node contract' -ForEach @(
        @{ MemberType = 'ScriptProperty' }
        @{ MemberType = 'CodeProperty' }
    ) {
        $node = New-GraphNode -Id 'assessment'
        if ($MemberType -ceq 'ScriptProperty') {
            $node | Add-Member -MemberType ScriptProperty -Name providerCommand -Value {
                throw 'hidden getter executed'
            }
        }
        else {
            $node | Add-Member -MemberType CodeProperty -Name providerCommand -Value $script:HiddenCodePropertyGetter
        }

        {
            Resolve-TenantLifecycleGraph -Nodes @($node) -ObservedOutcomes @()
        } | Should -Throw -ExpectedMessage 'TenantLifecycle.Graph.InvalidNode'
    }

    It 'rejects caller-controlled Failed as the required outcome even when the outcome failed' {
        $nodes = @(
            New-GraphNode -Id 'assessment' -RequiredOutcome 'Failed'
            New-GraphNode -Id 'deploy' -PrerequisiteIds @('assessment')
        )
        $outcomes = @(
            New-GraphOutcome -Id 'assessment' -Classification 'NoChange' -Status 'Failed'
        )

        {
            Resolve-TenantLifecycleGraph -Nodes $nodes -ObservedOutcomes $outcomes
        } | Should -Throw -ExpectedMessage 'TenantLifecycle.Graph.InvalidNode'
    }

    It 'blocks a graph with an ordinal duplicate node ID' {
        $nodes = @(
            New-GraphNode -Id 'assessment'
            New-GraphNode -Id 'assessment'
        )

        {
            Resolve-TenantLifecycleGraph -Nodes $nodes -ObservedOutcomes @()
        } | Should -Throw -ExpectedMessage 'TenantLifecycle.Graph.DuplicateNodeId'
    }

    It 'blocks a graph with a missing prerequisite' {
        $nodes = @(
            New-GraphNode -Id 'deploy' -PrerequisiteIds @('assessment')
        )

        {
            Resolve-TenantLifecycleGraph -Nodes $nodes -ObservedOutcomes @()
        } | Should -Throw -ExpectedMessage 'TenantLifecycle.Graph.MissingPrerequisite'
    }

    It 'blocks a cyclic graph with a stable failure' {
        $nodes = @(
            New-GraphNode -Id 'assessment' -PrerequisiteIds @('deploy')
            New-GraphNode -Id 'deploy' -PrerequisiteIds @('assessment')
        )

        {
            Resolve-TenantLifecycleGraph -Nodes $nodes -ObservedOutcomes @()
        } | Should -Throw -ExpectedMessage 'TenantLifecycle.Graph.Cycle'
    }

    It 'rejects a classification outside the six-value allowlist' {
        $nodes = @(New-GraphNode -Id 'assessment')
        $outcomes = @(
            New-GraphOutcome -Id 'assessment' -Classification 'Skipped'
        )

        {
            Resolve-TenantLifecycleGraph -Nodes $nodes -ObservedOutcomes $outcomes
        } | Should -Throw -ExpectedMessage 'TenantLifecycle.Graph.InvalidClassification'
    }

    It 'rejects duplicate observed outcome IDs' {
        $nodes = @(New-GraphNode -Id 'assessment')
        $outcomes = @(
            New-GraphOutcome -Id 'assessment' -Classification 'NoChange'
            New-GraphOutcome -Id 'assessment' -Classification 'NoChange'
        )

        {
            Resolve-TenantLifecycleGraph -Nodes $nodes -ObservedOutcomes $outcomes
        } | Should -Throw -ExpectedMessage 'TenantLifecycle.Graph.DuplicateOutcomeId'
    }

    It 'rejects a malformed independent read-back digest' {
        $nodes = @(New-GraphNode -Id 'consent' -Kind 'ManualGate')
        $outcomes = @(
            New-GraphOutcome -Id 'consent' -Classification 'Manual' -ReadBackDigest 'not-a-digest'
        )

        {
            Resolve-TenantLifecycleGraph -Nodes $nodes -ObservedOutcomes $outcomes
        } | Should -Throw -ExpectedMessage 'TenantLifecycle.Graph.InvalidOutcome'
    }

    It 'marks a stale digest and blocks its dependent' {
        $nodes = @(
            New-GraphNode -Id 'deploy' -PrerequisiteIds @('assessment') -InputDigest $script:DigestB
            New-GraphNode -Id 'assessment' -InputDigest $script:DigestA
        )
        $outcomes = @(
            New-GraphOutcome -Id 'assessment' -Classification 'NoChange' -InputDigest $script:DigestC
        )

        $result = @(Resolve-TenantLifecycleGraph -Nodes $nodes -ObservedOutcomes $outcomes)

        $result[0].status | Should -BeExactly 'Stale'
        $result[1].status | Should -BeExactly 'Blocked'
        $result[1].canExecute | Should -BeFalse
        ($result[1].blockingPrerequisiteIds -join ',') | Should -BeExactly 'assessment'
    }

    It 'does not treat an absent outcome as fresh success' {
        $nodes = @(
            New-GraphNode -Id 'deploy' -PrerequisiteIds @('assessment')
            New-GraphNode -Id 'assessment'
        )

        $result = @(Resolve-TenantLifecycleGraph -Nodes $nodes -ObservedOutcomes @())

        $result[0].status | Should -BeExactly 'NotRun'
        $result[1].status | Should -BeExactly 'Blocked'
        $result[1].canExecute | Should -BeFalse
    }

    It 'keeps Manual non-success without passed independent read-back' {
        $nodes = @(
            New-GraphNode -Id 'consent' -Kind 'ManualGate'
            New-GraphNode -Id 'deploy' -PrerequisiteIds @('consent')
        )
        $outcomes = @(
            New-GraphOutcome -Id 'consent' -Classification 'Manual'
        )

        $result = @(Resolve-TenantLifecycleGraph -Nodes $nodes -ObservedOutcomes $outcomes)

        $result[0].status | Should -BeExactly 'Manual'
        $result[1].canExecute | Should -BeFalse
        ($result[1].blockingPrerequisiteIds -join ',') | Should -BeExactly 'consent'
    }

    It 'accepts Manual only after passed independent read-back' {
        $nodes = @(
            New-GraphNode -Id 'consent' -Kind 'ManualGate'
            New-GraphNode -Id 'deploy' -PrerequisiteIds @('consent')
        )
        $outcomes = @(
            New-GraphOutcome -Id 'consent' -Classification 'Manual' -ReadBackDigest $script:DigestA
        )

        $result = @(Resolve-TenantLifecycleGraph -Nodes $nodes -ObservedOutcomes $outcomes)

        $result[0].status | Should -BeExactly 'Passed'
        $result[1].canExecute | Should -BeTrue
        @($result[1].blockingPrerequisiteIds).Count | Should -Be 0
    }

    It 'propagates <Classification> as a blocking prerequisite' -ForEach @(
        @{ Classification = 'Blocked' }
        @{ Classification = 'Refused' }
    ) {
        $nodes = @(
            New-GraphNode -Id 'deploy' -PrerequisiteIds @('assessment')
            New-GraphNode -Id 'assessment'
        )
        $outcomes = @(
            New-GraphOutcome -Id 'assessment' -Classification $Classification
        )

        $result = @(Resolve-TenantLifecycleGraph -Nodes $nodes -ObservedOutcomes $outcomes)

        $result[0].status | Should -BeExactly $Classification
        $result[1].status | Should -BeExactly 'Blocked'
        $result[1].canExecute | Should -BeFalse
    }

    It 'blocks a dependent after a failed prerequisite' {
        $nodes = @(
            New-GraphNode -Id 'deploy' -PrerequisiteIds @('assessment')
            New-GraphNode -Id 'assessment'
        )
        $outcomes = @(
            New-GraphOutcome -Id 'assessment' -Classification 'NoChange' -Status 'Failed'
        )

        $result = @(Resolve-TenantLifecycleGraph -Nodes $nodes -ObservedOutcomes $outcomes)

        $result[0].status | Should -BeExactly 'Failed'
        $result[1].status | Should -BeExactly 'Blocked'
        $result[1].canExecute | Should -BeFalse
        ($result[1].blockingPrerequisiteIds -join ',') | Should -BeExactly 'assessment'
    }

    It 'requires exact post-read for completed <Classification>' -ForEach @(
        @{ Classification = 'Create' }
        @{ Classification = 'Update' }
    ) {
        $nodes = @(
            New-GraphNode -Id 'foundation'
            New-GraphNode -Id 'deploy' -PrerequisiteIds @('foundation')
        )
        $outcomes = @(
            New-GraphOutcome -Id 'foundation' -Classification $Classification
        )

        $result = @(Resolve-TenantLifecycleGraph -Nodes $nodes -ObservedOutcomes $outcomes)

        $result[0].status | Should -BeExactly 'Unverified'
        $result[1].canExecute | Should -BeFalse
    }

    It 'accepts completed <Classification> with exact post-read' -ForEach @(
        @{ Classification = 'Create' }
        @{ Classification = 'Update' }
    ) {
        $nodes = @(
            New-GraphNode -Id 'foundation'
            New-GraphNode -Id 'deploy' -PrerequisiteIds @('foundation')
        )
        $outcomes = @(
            New-GraphOutcome -Id 'foundation' -Classification $Classification -ReadBackDigest $script:DigestA
        )

        $result = @(Resolve-TenantLifecycleGraph -Nodes $nodes -ObservedOutcomes $outcomes)

        $result[0].status | Should -BeExactly 'Passed'
        $result[1].canExecute | Should -BeTrue
    }

    It 'keeps <Classification> unverified when its valid read-back digest differs from input' -ForEach @(
        @{ Classification = 'Create' }
        @{ Classification = 'Update' }
        @{ Classification = 'Manual' }
    ) {
        $nodes = @(
            New-GraphNode -Id 'foundation'
            New-GraphNode -Id 'deploy' -PrerequisiteIds @('foundation')
        )
        $outcomes = @(
            New-GraphOutcome -Id 'foundation' -Classification $Classification -ReadBackDigest $script:DigestB
        )

        $result = @(Resolve-TenantLifecycleGraph -Nodes $nodes -ObservedOutcomes $outcomes)

        $result[0].status | Should -BeExactly 'Unverified'
        $result[1].status | Should -BeExactly 'Blocked'
        $result[1].canExecute | Should -BeFalse
        ($result[1].blockingPrerequisiteIds -join ',') | Should -BeExactly 'foundation'
    }

    It 'does not trust a passed dependent outcome when its prerequisite failed' {
        $nodes = @(
            New-GraphNode -Id 'assessment'
            New-GraphNode -Id 'deploy' -PrerequisiteIds @('assessment')
        )
        $outcomes = @(
            New-GraphOutcome -Id 'assessment' -Classification 'NoChange' -Status 'Failed'
            New-GraphOutcome -Id 'deploy' -Classification 'NoChange'
        )

        $result = @(Resolve-TenantLifecycleGraph -Nodes $nodes -ObservedOutcomes $outcomes)

        $result[1].status | Should -BeExactly 'Blocked'
        $result[1].canExecute | Should -BeFalse
    }

    It 'passes a complete all-NoChange path' {
        $nodes = @(
            New-GraphNode -Id 'acceptance' -PrerequisiteIds @('deploy') -InputDigest $script:DigestC
            New-GraphNode -Id 'assessment' -InputDigest $script:DigestA
            New-GraphNode -Id 'deploy' -PrerequisiteIds @('assessment') -InputDigest $script:DigestB
        )
        $outcomes = @(
            New-GraphOutcome -Id 'acceptance' -Classification 'NoChange' -InputDigest $script:DigestC
            New-GraphOutcome -Id 'deploy' -Classification 'NoChange' -InputDigest $script:DigestB
            New-GraphOutcome -Id 'assessment' -Classification 'NoChange' -InputDigest $script:DigestA
        )

        $result = @(Resolve-TenantLifecycleGraph -Nodes $nodes -ObservedOutcomes $outcomes)

        ($result.id -join ',') | Should -BeExactly 'assessment,deploy,acceptance'
        ($result.status -join ',') | Should -BeExactly 'Passed,Passed,Passed'
        ($result.canExecute -contains $false) | Should -BeFalse
        (@($result | ForEach-Object { @($_.blockingPrerequisiteIds).Count }) -join ',') | Should -BeExactly '0,0,0'
    }
}

Describe 'Tenant lifecycle approval expiry and drift' {
    BeforeAll {
        $script:ApprovalRepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
        $script:ApprovalModulePath = Join-Path $script:ApprovalRepositoryRoot 'infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1'
        $fixturePath = Join-Path $script:ApprovalRepositoryRoot 'infra\tests\fixtures\runbooks\tenant-lifecycle.synthetic.json'
        $script:ApprovalFixture = Get-Content -Raw -LiteralPath $fixturePath | ConvertFrom-Json
        Import-Module $script:ApprovalModulePath -Force

        function Copy-ApprovalValue {
            param([Parameter(Mandatory)][object]$InputObject)
            $InputObject | ConvertTo-Json -Depth 30 | ConvertFrom-Json
        }

        function New-ApprovalManifest {
            New-TenantLifecycleExecutionManifest `
                -RunId ([guid]'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee') `
                -SourceCommit ('a' * 40) `
                -EvidenceRoot 'C:\evidence-root-synthetic' `
                -PublicTenantKey tenant1 `
                -IntentDigest ('1' * 64) `
                -StateDigest ('2' * 64) `
                -Machine (Copy-ApprovalValue $script:ApprovalFixture.executionManifest.machine) `
                -Operator (Copy-ApprovalValue $script:ApprovalFixture.executionManifest.operator) `
                -ToolIdentities @(Copy-ApprovalValue $script:ApprovalFixture.executionManifest.toolIdentities) `
                -ProviderContexts @(Copy-ApprovalValue $script:ApprovalFixture.executionManifest.providerContexts) `
                -Prerequisites @(Copy-ApprovalValue $script:ApprovalFixture.executionManifest.prerequisites) `
                -Actions @(Copy-ApprovalValue $script:ApprovalFixture.executionManifest.actions) `
                -GeneratedAtUtc ([datetime]'2026-10-02T12:05:00Z') `
                -ExpiresAtUtc ([datetime]'2026-10-02T12:35:00Z')
        }

        function New-ApprovalRecord {
            param([Parameter(Mandatory)][object]$Manifest)

            [pscustomobject][ordered]@{
                schemaVersion = '1.0'
                runId = $Manifest.runId
                executionManifestDigest = $Manifest.digest
                approverRole = 'TenantLifecycleApprover'
                approvedAtUtc = '2026-10-02T12:06:00.0000000Z'
                expiresAtUtc = '2026-10-02T12:35:00.0000000Z'
                scope = @($Manifest.actions | ForEach-Object id)
                status = 'Approved'
            }
        }
    }

    Describe 'Provider-neutral tenant lifecycle orchestrator' {
            BeforeAll {
                $script:OrchestratorRepositoryRoot = (
                    Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
                ).Path
                $script:OrchestratorModulePath = Join-Path $script:OrchestratorRepositoryRoot (
                    'infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\' +
                    'Caldova.HrFrontier.Bootstrap.psd1'
                )
                $script:OrchestratorPath = Join-Path $script:OrchestratorRepositoryRoot (
                    'infra\src\scripts\runbooks\Invoke-TenantLifecycle.ps1'
                )
                $fixturePath = Join-Path $script:OrchestratorRepositoryRoot (
                    'infra\tests\fixtures\runbooks\tenant-lifecycle.synthetic.json'
                )
                $script:OrchestratorFixture = Get-Content -Raw -LiteralPath $fixturePath |
                    ConvertFrom-Json
                Import-Module $script:OrchestratorModulePath -Force

                $script:SyntheticRepositoryRoot = Join-Path $TestDrive 'orchestrator-repository'
                $script:SyntheticTenantRoot = Join-Path $script:SyntheticRepositoryRoot (
                    'infra\src\config\tenants'
                )
                [IO.Directory]::CreateDirectory($script:SyntheticTenantRoot) | Out-Null

                $script:IntentPath = Join-Path $script:SyntheticTenantRoot 'tenant1.local.psd1'
                $script:StatePath = Join-Path $script:SyntheticTenantRoot (
                    'tenant1.state.local.json'
                )
                $intent = Get-Content -Raw -LiteralPath (
                    Join-Path $script:OrchestratorRepositoryRoot (
                        'infra\src\config\tenants\_template.psd1'
                    )
                )
                $intent = $intent.Replace(
                    '    Components = @{}',
                    "    Components = @{$([Environment]::NewLine)" +
                    "        SyntheticResource = @{ Mode = 'Existing'; " +
                    "Id = 'stable-synthetic-001' }$([Environment]::NewLine)    }"
                )
                [IO.File]::WriteAllText(
                    $script:IntentPath,
                    $intent,
                    [Text.UTF8Encoding]::new($false)
                )
                [IO.File]::WriteAllText(
                    $script:StatePath,
                    (($script:OrchestratorFixture.state | ConvertTo-Json -Depth 30 -Compress) + "`n"),
                    [Text.UTF8Encoding]::new($false)
                )
                [IO.File]::WriteAllText(
                    (Join-Path $script:SyntheticRepositoryRoot '.gitignore'),
                    (
                        "/infra/src/config/tenants/tenant1.local.psd1`n" +
                        "/infra/src/config/tenants/tenant1.state.local.json`n"
                    ),
                    [Text.UTF8Encoding]::new($false)
                )
                [IO.File]::WriteAllText(
                    (Join-Path $script:SyntheticRepositoryRoot 'tracked.txt'),
                    "synthetic`n",
                    [Text.UTF8Encoding]::new($false)
                )

                & git -C $script:SyntheticRepositoryRoot init --quiet
                if ($LASTEXITCODE -ne 0) {
                    throw 'Could not initialize the synthetic orchestrator repository.'
                }
                & git -C $script:SyntheticRepositoryRoot config user.email 'synthetic@example.invalid'
                & git -C $script:SyntheticRepositoryRoot config user.name 'Synthetic Test'
                & git -C $script:SyntheticRepositoryRoot add .gitignore tracked.txt
                & git -C $script:SyntheticRepositoryRoot commit --quiet -m 'synthetic source'
                if ($LASTEXITCODE -ne 0) {
                    throw 'Could not commit the synthetic orchestrator repository.'
                }
                $script:SyntheticSourceCommit = (
                    & git -C $script:SyntheticRepositoryRoot rev-parse HEAD
                ).Trim().ToLowerInvariant()
                $script:EvidenceRoot = Join-Path $TestDrive 'orchestrator-evidence'
                $script:NowUtc = [datetime]'2026-10-02T19:05:00Z'

                function New-SyntheticPassedInvoker {
                    param(
                        [Parameter(Mandatory)]
                        [AllowEmptyCollection()]
                        [Collections.Generic.List[string]]$Calls,

                        [Parameter(Mandatory)]
                        [AllowEmptyCollection()]
                        [Collections.Generic.List[object]]$ControlRecords
                    )

                    {
                        param([string]$Stage, [string]$Mode, [object]$ControlRecord)

                        [void]$Calls.Add($Stage)
                        [void]$ControlRecords.Add($ControlRecord)
                        $inputDigest = Get-RunbookContentDigest -InputObject (
                            [pscustomobject][ordered]@{
                                stage = $Stage
                                mode = $Mode
                                controlRecord = $ControlRecord
                            }
                        )
                        [pscustomobject][ordered]@{
                            id = $Stage
                            stage = $Stage
                            classification = 'NoChange'
                            status = 'Passed'
                            inputDigest = $inputDigest
                            readBackDigest = $null
                            evidenceRelativePath = "actions/$Stage.json"
                        }
                    }.GetNewClosure()
                }

                function New-OrchestratorManifest {
                    param(
                        [Parameter(Mandatory)][guid]$RunId,
                        [Parameter(Mandatory)][string]$RunDirectory
                    )

                    $manifest = New-TenantLifecycleExecutionManifest `
                        -RunId $RunId `
                        -SourceCommit $script:SyntheticSourceCommit `
                        -EvidenceRoot $RunDirectory `
                        -PublicTenantKey tenant1 `
                        -IntentDigest ('1' * 64) `
                        -StateDigest ('2' * 64) `
                        -Machine ([pscustomobject][ordered]@{
                            machineId = 'machine-synthetic-001'
                            platform = 'Windows 11'
                        }) `
                        -Operator ([pscustomobject][ordered]@{
                            operatorId = 'operator-synthetic-001'
                            role = 'RunbookOperator'
                        }) `
                        -ToolIdentities @([pscustomobject][ordered]@{
                            id = 'PowerShell'
                            version = '5.1'
                            digest = '3' * 64
                        }) `
                        -ProviderContexts @(
                            $script:OrchestratorFixture.executionManifest.providerContexts
                        ) `
                        -Prerequisites @(
                            $script:OrchestratorFixture.executionManifest.prerequisites
                        ) `
                        -Actions @($script:OrchestratorFixture.executionManifest.actions[0]) `
                        -GeneratedAtUtc ([datetime]'2026-10-02T19:00:00Z') `
                        -ExpiresAtUtc ([datetime]'2026-10-02T19:30:00Z')
                    $manifestPath = Join-Path $TestDrive "manifest-$($RunId.ToString('D')).json"
                    Write-CanonicalJson -InputObject $manifest -Path $manifestPath | Out-Null
                    [pscustomobject]@{
                        Manifest = $manifest
                        Path = $manifestPath
                    }
                }

                function Invoke-SyntheticOrchestrator {
                    param(
                        [Parameter(Mandatory)][guid]$RunId,
                        [Parameter(Mandatory)][string[]]$Stages,
                        [scriptblock]$SubsystemInvoker,
                        [ValidateSet('Assess', 'Plan', 'Invoke')][string]$Mode = 'Assess',
                        [string]$ExecutionManifestPath,
                        [string]$ApprovedDigest,
                        [switch]$Apply,
                        [switch]$WhatIf
                    )

                    $parameters = @{
                        RunId = $RunId
                        EvidenceRoot = $script:EvidenceRoot
                        RepositoryRoot = $script:SyntheticRepositoryRoot
                        ExpectedSourceCommit = $script:SyntheticSourceCommit
                        PublicTenantKey = 'tenant1'
                        TenantConfigurationPath = $script:IntentPath
                        TenantStatePath = $script:StatePath
                        Stages = $Stages
                        Mode = $Mode
                        NowUtc = $script:NowUtc
                        Confirm = $false
                    }
                    if ($PSBoundParameters.ContainsKey('SubsystemInvoker')) {
                        $parameters.SubsystemInvoker = $SubsystemInvoker
                    }
                    if ($PSBoundParameters.ContainsKey('ExecutionManifestPath')) {
                        $parameters.ExecutionManifestPath = $ExecutionManifestPath
                    }
                    if ($PSBoundParameters.ContainsKey('ApprovedDigest')) {
                        $parameters.ApprovedDigest = $ApprovedDigest
                    }
                    if ($Apply) {
                        $parameters.Apply = $true
                    }
                    if ($WhatIf) {
                        $parameters.WhatIf = $true
                    }

                    & $script:OrchestratorPath @parameters
                }
            }

            It 'orders every selected stage and passes only the closed non-secret control record' {
                $runId = [guid]'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee'
                $calls = [Collections.Generic.List[string]]::new()
                $records = [Collections.Generic.List[object]]::new()
                $invoker = New-SyntheticPassedInvoker -Calls $calls -ControlRecords $records

                $result = @(Invoke-SyntheticOrchestrator `
                    -RunId $runId `
                    -Stages @(
                        'TenantReplica',
                        'Acceptance',
                        'ReadBack',
                        'DevDelivery',
                        'Foundation',
                        'PrivateBoundary',
                        'Workstation'
                    ) `
                    -SubsystemInvoker $invoker)

                ($calls -join ',') | Should -BeExactly (
                    'Workstation,PrivateBoundary,Foundation,DevDelivery,' +
                    'ReadBack,Acceptance,TenantReplica'
                )
                $result.Count | Should -Be 7
                ($records[0].PSObject.Properties.Name -join ',') | Should -BeExactly (
                    'runId,runDirectoryLabel,publicTenantKey,sourceCommit,' +
                    'machineLabel,operatorLabel,toolIdentities,approvedDigest,' +
                    'prerequisiteOutcomes'
                )
                [string]$records[0].runId | Should -BeExactly $runId.ToString('D')
                $records[0].runDirectoryLabel | Should -BeExactly $runId.ToString('D')
                $records[0].publicTenantKey | Should -BeExactly 'tenant1'
                $records[0].sourceCommit | Should -BeExactly $script:SyntheticSourceCommit
                @($records[0].toolIdentities).Count | Should -Be 0
                $records[0].approvedDigest | Should -BeNullOrEmpty
                @($records[0].prerequisiteOutcomes).Count | Should -Be 0
                @($records[1].prerequisiteOutcomes).Count | Should -Be 1
                $records[1].prerequisiteOutcomes[0].id | Should -BeExactly 'Workstation'
                ($records | ConvertTo-Json -Depth 20) |
                    Should -Not -Match '(?i)token|secret|credential|providerPayload|commandLine'
            }

            It 'runs an independently selected subsystem without forcing omitted predecessors' {
                $calls = [Collections.Generic.List[string]]::new()
                $records = [Collections.Generic.List[object]]::new()
                $invoker = New-SyntheticPassedInvoker -Calls $calls -ControlRecords $records

                $result = @(Invoke-SyntheticOrchestrator `
                    -RunId ([guid]::NewGuid()) `
                    -Stages @('TenantReplica') `
                    -SubsystemInvoker $invoker)

                ($calls -join ',') | Should -BeExactly 'TenantReplica'
                $result.Count | Should -Be 1
                @($records[0].prerequisiteOutcomes).Count | Should -Be 0
            }

            It 'does not invoke a dependent stage after a failed prerequisite outcome' {
                $calls = [Collections.Generic.List[string]]::new()
                $invoker = {
                    param([string]$Stage, [string]$Mode, [object]$ControlRecord)

                    [void]$calls.Add($Stage)
                    $inputDigest = Get-RunbookContentDigest -InputObject (
                        [pscustomobject][ordered]@{
                            stage = $Stage
                            mode = $Mode
                            controlRecord = $ControlRecord
                        }
                    )
                    [pscustomobject][ordered]@{
                        id = $Stage
                        stage = $Stage
                        classification = 'NoChange'
                        status = 'Failed'
                        inputDigest = $inputDigest
                        readBackDigest = $null
                        evidenceRelativePath = "actions/$Stage.json"
                    }
                }.GetNewClosure()

                $result = @(Invoke-SyntheticOrchestrator `
                    -RunId ([guid]::NewGuid()) `
                    -Stages @('Workstation', 'Foundation') `
                    -SubsystemInvoker $invoker)

                ($calls -join ',') | Should -BeExactly 'Workstation'
                $result.Count | Should -Be 1
                $result[0].status | Should -BeExactly 'Failed'
            }

            It 'refuses Apply without an approved digest before any subsystem invocation' {
                $calls = [Collections.Generic.List[string]]::new()
                $records = [Collections.Generic.List[object]]::new()
                $invoker = New-SyntheticPassedInvoker -Calls $calls -ControlRecords $records

                {
                    Invoke-SyntheticOrchestrator `
                        -RunId ([guid]::NewGuid()) `
                        -Stages @('Foundation') `
                        -Mode Invoke `
                        -SubsystemInvoker $invoker `
                        -Apply
                } | Should -Throw -ExpectedMessage 'TenantLifecycle.Approval.Required'
                $calls.Count | Should -Be 0
            }

            It 'lets WhatIf dominate Apply without invocation or evidence mutation' {
                $runId = [guid]::NewGuid()
                $runDirectory = Join-Path $script:EvidenceRoot $runId.ToString('D')
                $manifestRecord = New-OrchestratorManifest `
                    -RunId $runId `
                    -RunDirectory $runDirectory
                $calls = [Collections.Generic.List[string]]::new()
                $records = [Collections.Generic.List[object]]::new()
                $invoker = New-SyntheticPassedInvoker -Calls $calls -ControlRecords $records

                $result = @(Invoke-SyntheticOrchestrator `
                    -RunId $runId `
                    -Stages @('Foundation') `
                    -Mode Invoke `
                    -ExecutionManifestPath $manifestRecord.Path `
                    -ApprovedDigest $manifestRecord.Manifest.digest `
                    -SubsystemInvoker $invoker `
                    -Apply `
                    -WhatIf)

                $result.Count | Should -Be 0
                $calls.Count | Should -Be 0
                $runDirectory | Should -Not -Exist
            }

            It 'does not invoke a later stage when an injected stage returns unresolved Manual' {
                $calls = [Collections.Generic.List[string]]::new()
                $invoker = {
                    param([string]$Stage, [string]$Mode, [object]$ControlRecord)

                    [void]$calls.Add($Stage)
                    $inputDigest = Get-RunbookContentDigest -InputObject (
                        [pscustomobject][ordered]@{
                            stage = $Stage
                            mode = $Mode
                            controlRecord = $ControlRecord
                        }
                    )
                    [pscustomobject][ordered]@{
                        id = $Stage
                        stage = $Stage
                        classification = 'Manual'
                        status = 'Passed'
                        inputDigest = $inputDigest
                        readBackDigest = $null
                        evidenceRelativePath = "actions/$Stage.json"
                    }
                }.GetNewClosure()

                $result = @(Invoke-SyntheticOrchestrator `
                    -RunId ([guid]::NewGuid()) `
                    -Stages @('PrivateBoundary', 'Foundation') `
                    -SubsystemInvoker $invoker)

                ($calls -join ',') | Should -BeExactly 'PrivateBoundary'
                $result.Count | Should -Be 1
                $result[0].classification | Should -BeExactly 'Manual'
            }

            It 'fails closed when no subsystem invoker is injected' {
                {
                    Invoke-SyntheticOrchestrator `
                        -RunId ([guid]::NewGuid()) `
                        -Stages @('Workstation')
                } | Should -Throw -ExpectedMessage 'TenantLifecycle.SubsystemInvoker.Required'
            }

            It 'writes an exact consolidated summary through the accepted evidence writer' {
                $runId = [guid]::NewGuid()
                $runDirectory = Join-Path $script:EvidenceRoot $runId.ToString('D')
                $manifestRecord = New-OrchestratorManifest `
                    -RunId $runId `
                    -RunDirectory $runDirectory
                $calls = [Collections.Generic.List[string]]::new()
                $records = [Collections.Generic.List[object]]::new()
                $invoker = New-SyntheticPassedInvoker -Calls $calls -ControlRecords $records

                $result = @(Invoke-SyntheticOrchestrator `
                    -RunId $runId `
                    -Stages @('Foundation', 'ReadBack') `
                    -Mode Invoke `
                    -ExecutionManifestPath $manifestRecord.Path `
                    -ApprovedDigest $manifestRecord.Manifest.digest `
                    -SubsystemInvoker $invoker `
                    -Apply)

                $result.Count | Should -Be 2
                $summaryPath = Join-Path $runDirectory 'summary.json'
                $summaryPath | Should -Exist
                $summary = Get-Content -Raw -LiteralPath $summaryPath | ConvertFrom-Json
                Test-TenantLifecycleContract -Kind Summary -InputObject $summary |
                    Should -BeTrue
                $summary.runId | Should -BeExactly $runId.ToString('D')
                $summary.sourceCommit | Should -BeExactly $script:SyntheticSourceCommit
                $summary.manifestDigest |
                    Should -BeExactly $manifestRecord.Manifest.digest
                $summary.status | Should -BeExactly 'Passed'
                $summary.counts.NoChange | Should -Be 2
                ($summary.actions.id -join ',') |
                    Should -BeExactly 'Foundation,ReadBack'
                ($summary.actions.evidenceRelativePath -join ',') |
                    Should -BeExactly 'actions/Foundation.json,actions/ReadBack.json'
            }
        }

    BeforeAll {
        $script:ApprovalRepositoryRoot = (
            Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
        ).Path
        $script:ApprovalModulePath = Join-Path $script:ApprovalRepositoryRoot (
            'infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\' +
            'Caldova.HrFrontier.Bootstrap.psd1'
        )
        $approvalFixturePath = Join-Path $script:ApprovalRepositoryRoot (
            'infra\tests\fixtures\runbooks\tenant-lifecycle.synthetic.json'
        )
        $script:ApprovalFixture = Get-Content -Raw -LiteralPath $approvalFixturePath |
            ConvertFrom-Json
        Import-Module $script:ApprovalModulePath -Force

        function Copy-ApprovalValue {
            param([Parameter(Mandatory)][object]$InputObject)
            $InputObject | ConvertTo-Json -Depth 30 | ConvertFrom-Json
        }

        function New-ApprovalManifest {
            New-TenantLifecycleExecutionManifest `
                -RunId ([guid]'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee') `
                -SourceCommit ('a' * 40) `
                -EvidenceRoot 'C:\evidence-root-synthetic' `
                -PublicTenantKey tenant1 `
                -IntentDigest ('1' * 64) `
                -StateDigest ('2' * 64) `
                -Machine (Copy-ApprovalValue $script:ApprovalFixture.executionManifest.machine) `
                -Operator (Copy-ApprovalValue $script:ApprovalFixture.executionManifest.operator) `
                -ToolIdentities @(Copy-ApprovalValue $script:ApprovalFixture.executionManifest.toolIdentities) `
                -ProviderContexts @(Copy-ApprovalValue $script:ApprovalFixture.executionManifest.providerContexts) `
                -Prerequisites @(Copy-ApprovalValue $script:ApprovalFixture.executionManifest.prerequisites) `
                -Actions @(Copy-ApprovalValue $script:ApprovalFixture.executionManifest.actions) `
                -GeneratedAtUtc ([datetime]'2026-10-02T12:05:00Z') `
                -ExpiresAtUtc ([datetime]'2026-10-02T12:35:00Z')
        }

        function New-ApprovalRecord {
            param([Parameter(Mandatory)][object]$Manifest)

            [pscustomobject][ordered]@{
                schemaVersion = '1.0'
                runId = $Manifest.runId
                executionManifestDigest = $Manifest.digest
                approverRole = 'TenantLifecycleApprover'
                approvedAtUtc = '2026-10-02T12:06:00.0000000Z'
                expiresAtUtc = '2026-10-02T12:35:00.0000000Z'
                scope = @($Manifest.actions | ForEach-Object id)
                status = 'Approved'
            }
        }

        function New-CurrentApprovalBinding {
            param([Parameter(Mandatory)][object]$Manifest)

            [pscustomobject][ordered]@{
                runId = $Manifest.runId
                generatedAtUtc = $Manifest.generatedAtUtc
                expiresAtUtc = $Manifest.expiresAtUtc
                sourceCommit = $Manifest.sourceCommit
                evidenceRoot = $Manifest.evidenceRoot
                publicTenantKey = $Manifest.publicTenantKey
                intentDigest = $Manifest.intentDigest
                stateDigest = $Manifest.stateDigest
                machine = Copy-ApprovalValue $Manifest.machine
                operator = Copy-ApprovalValue $Manifest.operator
                toolIdentities = @(Copy-ApprovalValue $Manifest.toolIdentities)
                providerContexts = @(Copy-ApprovalValue $Manifest.providerContexts)
                prerequisites = @(Copy-ApprovalValue $Manifest.prerequisites)
                actions = @(Copy-ApprovalValue $Manifest.actions)
                sessionId = [string]$PID
            }
        }
    }

    BeforeEach {
        $script:ApprovalManifest = New-ApprovalManifest
        $script:Approval = New-ApprovalRecord -Manifest $script:ApprovalManifest
        $script:CurrentBinding = New-CurrentApprovalBinding -Manifest $script:ApprovalManifest
        $script:ApprovalNow = [datetime]'2026-10-02T12:07:00Z'
    }

    It 'accepts an exact evidence approval binding within the expiry window' {
        Test-TenantLifecycleApproval `
            -Manifest $script:ApprovalManifest `
            -Approval $script:Approval `
            -CurrentBinding $script:CurrentBinding `
            -NowUtc $script:ApprovalNow |
            Should -BeTrue
    }

    It 'rejects evidence approval status <Status> with a stable ordinal error' -ForEach @(
        @{ Status = 'Pending' }
        @{ Status = 'Rejected' }
        @{ Status = 'approved' }
        @{ Status = 'APPROVED' }
    ) {
        $script:Approval.status = $Status

        {
            Test-TenantLifecycleApproval `
                -Manifest $script:ApprovalManifest `
                -Approval $script:Approval `
                -CurrentBinding $script:CurrentBinding `
                -NowUtc $script:ApprovalNow
        } | Should -Throw -ExpectedMessage 'TenantLifecycle.Approval.Status'
    }

    It 'rejects an evidence approval digest mismatch' {
        $script:Approval.executionManifestDigest = 'f' * 64

        {
            Test-TenantLifecycleApproval `
                -Manifest $script:ApprovalManifest `
                -Approval $script:Approval `
                -CurrentBinding $script:CurrentBinding `
                -NowUtc $script:ApprovalNow
        } | Should -Throw -ExpectedMessage 'TenantLifecycle.Approval.Digest'
    }

    It 'rejects an evidence manifest whose approval window exceeds thirty minutes' {
        $script:ApprovalManifest.expiresAtUtc = '2026-10-02T12:35:00.0010000Z'
        $digestInput = [ordered]@{}
        foreach ($property in @(
            $script:ApprovalManifest.PSObject.Properties |
                Where-Object Name -CNE 'digest'
        )) {
            $digestInput[$property.Name] = $property.Value
        }
        $script:ApprovalManifest.digest =
            Get-RunbookContentDigest -InputObject ([pscustomobject]$digestInput)
        $script:Approval.executionManifestDigest = $script:ApprovalManifest.digest
        $script:Approval.expiresAtUtc = $script:ApprovalManifest.expiresAtUtc
        $script:CurrentBinding = New-CurrentApprovalBinding -Manifest $script:ApprovalManifest

        {
            Test-TenantLifecycleApproval `
                -Manifest $script:ApprovalManifest `
                -Approval $script:Approval `
                -CurrentBinding $script:CurrentBinding `
                -NowUtc $script:ApprovalNow
        } | Should -Throw -ExpectedMessage 'TenantLifecycle.Approval.Expiry'
    }

    It 'rejects stale evidence approval continuation after expiry' {
        {
            Test-TenantLifecycleApproval `
                -Manifest $script:ApprovalManifest `
                -Approval $script:Approval `
                -CurrentBinding $script:CurrentBinding `
                -NowUtc ([datetime]'2026-10-02T12:35:00.001Z')
        } | Should -Throw -ExpectedMessage 'TenantLifecycle.Approval.Expired'
    }

    It 'expires evidence approval at its exact expiry boundary' {
        $script:Approval.expiresAtUtc = '2026-10-02T12:34:00.0000000Z'

        {
            Test-TenantLifecycleApproval `
                -Manifest $script:ApprovalManifest `
                -Approval $script:Approval `
                -CurrentBinding $script:CurrentBinding `
                -NowUtc ([datetime]'2026-10-02T12:34:00Z')
        } | Should -Throw -ExpectedMessage 'TenantLifecycle.Approval.Expired'
    }

    It 'expires evidence approval at the exact manifest expiry boundary' {
        {
            Test-TenantLifecycleApproval `
                -Manifest $script:ApprovalManifest `
                -Approval $script:Approval `
                -CurrentBinding $script:CurrentBinding `
                -NowUtc ([datetime]'2026-10-02T12:35:00Z')
        } | Should -Throw -ExpectedMessage 'TenantLifecycle.Approval.Expired'
    }

    It 'rejects evidence approval whose expiry is not later than approval time' {
        $script:Approval.expiresAtUtc = $script:Approval.approvedAtUtc

        {
            Test-TenantLifecycleApproval `
                -Manifest $script:ApprovalManifest `
                -Approval $script:Approval `
                -CurrentBinding $script:CurrentBinding `
                -NowUtc $script:ApprovalNow
        } | Should -Throw -ExpectedMessage 'TenantLifecycle.Approval.Expiry'
    }

    It 'rejects an evidence approval expiry later than the manifest expiry' {
        $script:Approval.expiresAtUtc = '2026-10-02T12:35:00.0010000Z'

        {
            Test-TenantLifecycleApproval `
                -Manifest $script:ApprovalManifest `
                -Approval $script:Approval `
                -CurrentBinding $script:CurrentBinding `
                -NowUtc $script:ApprovalNow
        } | Should -Throw -ExpectedMessage 'TenantLifecycle.Approval.Expiry'
    }

    It 'rejects an evidence approval scope that differs from the ordered actions' {
        $script:Approval.scope = @('other-action')

        {
            Test-TenantLifecycleApproval `
                -Manifest $script:ApprovalManifest `
                -Approval $script:Approval `
                -CurrentBinding $script:CurrentBinding `
                -NowUtc $script:ApprovalNow
        } | Should -Throw -ExpectedMessage 'TenantLifecycle.Approval.Scope'
    }

    It 'rejects evidence approval reuse after a process-session restart' {
        $script:CurrentBinding.sessionId = "$PID-restarted"

        {
            Test-TenantLifecycleApproval `
                -Manifest $script:ApprovalManifest `
                -Approval $script:Approval `
                -CurrentBinding $script:CurrentBinding `
                -NowUtc $script:ApprovalNow
        } | Should -Throw -ExpectedMessage 'TenantLifecycle.Approval.Drift.sessionId'
    }

    It 'invalidates evidence approval on <Field> drift' -ForEach @(
        @{ Field = 'runId' }
        @{ Field = 'generatedAtUtc' }
        @{ Field = 'expiresAtUtc' }
        @{ Field = 'machine' }
        @{ Field = 'operator' }
        @{ Field = 'sourceCommit' }
        @{ Field = 'publicTenantKey' }
        @{ Field = 'intentDigest' }
        @{ Field = 'stateDigest' }
        @{ Field = 'toolIdentities' }
        @{ Field = 'providerContexts' }
        @{ Field = 'prerequisites' }
        @{ Field = 'actions' }
        @{ Field = 'evidenceRoot' }
    ) {
        switch ($Field) {
            'runId' { $script:CurrentBinding.runId = 'bbbbbbbb-cccc-4ddd-8eee-ffffffffffff' }
            'generatedAtUtc' { $script:CurrentBinding.generatedAtUtc = '2026-10-02T12:05:01.0000000Z' }
            'expiresAtUtc' { $script:CurrentBinding.expiresAtUtc = '2026-10-02T12:34:59.0000000Z' }
            'machine' { $script:CurrentBinding.machine.machineId = 'machine-synthetic-002' }
            'operator' { $script:CurrentBinding.operator.operatorId = 'operator-synthetic-002' }
            'sourceCommit' { $script:CurrentBinding.sourceCommit = 'b' * 40 }
            'publicTenantKey' { $script:CurrentBinding.publicTenantKey = 'tenant2' }
            'intentDigest' { $script:CurrentBinding.intentDigest = '3' * 64 }
            'stateDigest' { $script:CurrentBinding.stateDigest = '4' * 64 }
            'toolIdentities' { $script:CurrentBinding.toolIdentities[0].digest = '5' * 64 }
            'providerContexts' { $script:CurrentBinding.providerContexts[0].digest = '6' * 64 }
            'prerequisites' { $script:CurrentBinding.prerequisites[0].evidenceDigest = '8' * 64 }
            'actions' { $script:CurrentBinding.actions[0].desiredPropertiesDigest = '7' * 64 }
            'evidenceRoot' { $script:CurrentBinding.evidenceRoot = 'C:\other-evidence-root' }
        }

        {
            Test-TenantLifecycleApproval `
                -Manifest $script:ApprovalManifest `
                -Approval $script:Approval `
                -CurrentBinding $script:CurrentBinding `
                -NowUtc $script:ApprovalNow
        } | Should -Throw -ExpectedMessage "TenantLifecycle.Approval.Drift.$Field"
    }
}
