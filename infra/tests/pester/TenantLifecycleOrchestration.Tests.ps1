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
        $digestInput = Copy-ApprovalValue $script:ApprovalManifest
        $digestInput.PSObject.Properties.Remove('digest')
        $script:ApprovalManifest.digest = Get-RunbookContentDigest -InputObject $digestInput
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
        @{ Field = 'machine' }
        @{ Field = 'sourceCommit' }
        @{ Field = 'intentDigest' }
        @{ Field = 'stateDigest' }
        @{ Field = 'toolIdentities' }
        @{ Field = 'providerContexts' }
        @{ Field = 'prerequisites' }
        @{ Field = 'actions' }
        @{ Field = 'evidenceRoot' }
    ) {
        switch ($Field) {
            'machine' { $script:CurrentBinding.machine.machineId = 'machine-synthetic-002' }
            'sourceCommit' { $script:CurrentBinding.sourceCommit = 'b' * 40 }
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
