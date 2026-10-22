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

    It 'requires literal Passed dependency success for <Status>/<Classification>' -ForEach @(
        @{ Status = 'Failed'; Classification = 'NoChange' }
        @{ Status = 'Failed'; Classification = 'Changed' }
        @{ Status = 'Manual'; Classification = 'Manual' }
        @{ Status = 'Blocked'; Classification = 'Blocked' }
        @{ Status = 'Refused'; Classification = 'Refused' }
    ) {
        $runId = [guid]'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee'
        $first = New-TenantLifecycleStageResult `
            -RunId $runId `
            -Stage Workstation `
            -SourceCommit ('a' * 40) `
            -PublicTenantKey tenant1 `
            -IntentDigest ('1' * 64) `
            -StateDigest ('2' * 64) `
            -PhaseManifestDigest ('3' * 64) `
            -PhaseSummaryDigest ('4' * 64) `
            -Status $Status `
            -Classification $Classification `
            -EvidenceRelativePath 'phases/Workstation/summary.json' `
            -CompletedAtUtc ([datetime]'2026-10-03T08:31:00Z')
        $second = New-TenantLifecycleStageResult `
            -RunId $runId `
            -Stage Foundation `
            -SourceCommit ('a' * 40) `
            -PublicTenantKey tenant1 `
            -IntentDigest ('1' * 64) `
            -StateDigest ('2' * 64) `
            -PhaseManifestDigest ('5' * 64) `
            -PhaseSummaryDigest ('6' * 64) `
            -Status Passed `
            -Classification NoChange `
            -EvidenceRelativePath 'phases/Foundation/summary.json' `
            -CompletedAtUtc ([datetime]'2026-10-03T08:32:00Z')
        $nodes = @(
            New-GraphNode `
                -Id Workstation `
                -Kind Stage `
                -Stage Workstation `
                -InputDigest $first.phaseManifestDigest
            New-GraphNode `
                -Id Foundation `
                -Kind Stage `
                -Stage Foundation `
                -PrerequisiteIds @('Workstation') `
                -InputDigest $second.phaseManifestDigest
        )

        $resolved = @(
            Resolve-TenantLifecycleGraph `
                -Nodes $nodes `
                -ObservedOutcomes @($first, $second)
        )

        $resolved[0].status | Should -BeExactly $Status
        $resolved[1].status | Should -BeExactly 'Blocked'
        $resolved[1].canExecute | Should -BeFalse
        ($resolved[1].blockingPrerequisiteIds -join ',') |
            Should -BeExactly 'Workstation'
    }

    It 'accepts literal Passed dependency success for <Classification>' -ForEach @(
        @{ Classification = 'NoChange' }
        @{ Classification = 'Changed' }
    ) {
        $runId = [guid]'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee'
        $first = New-TenantLifecycleStageResult `
            -RunId $runId `
            -Stage Workstation `
            -SourceCommit ('a' * 40) `
            -PublicTenantKey tenant1 `
            -IntentDigest ('1' * 64) `
            -StateDigest ('2' * 64) `
            -PhaseManifestDigest ('3' * 64) `
            -PhaseSummaryDigest ('4' * 64) `
            -Status Passed `
            -Classification $Classification `
            -EvidenceRelativePath 'phases/Workstation/summary.json' `
            -CompletedAtUtc ([datetime]'2026-10-03T08:31:00Z')
        $second = New-TenantLifecycleStageResult `
            -RunId $runId `
            -Stage Foundation `
            -SourceCommit ('a' * 40) `
            -PublicTenantKey tenant1 `
            -IntentDigest ('1' * 64) `
            -StateDigest ('2' * 64) `
            -PhaseManifestDigest ('5' * 64) `
            -PhaseSummaryDigest ('6' * 64) `
            -Status Passed `
            -Classification NoChange `
            -EvidenceRelativePath 'phases/Foundation/summary.json' `
            -CompletedAtUtc ([datetime]'2026-10-03T08:32:00Z')
        $nodes = @(
            New-GraphNode `
                -Id Workstation `
                -Kind Stage `
                -Stage Workstation `
                -InputDigest $first.phaseManifestDigest
            New-GraphNode `
                -Id Foundation `
                -Kind Stage `
                -Stage Foundation `
                -PrerequisiteIds @('Workstation') `
                -InputDigest $second.phaseManifestDigest
        )

        $resolved = @(
            Resolve-TenantLifecycleGraph `
                -Nodes $nodes `
                -ObservedOutcomes @($first, $second)
        )

        ($resolved.status -join ',') | Should -BeExactly 'Passed,Passed'
        $resolved[1].canExecute | Should -BeTrue
    }
}

Describe 'Tenant lifecycle cross-host coordinate-only golden orchestration' {
    BeforeAll {
        $script:CrossHostRepositoryRoot = (
            Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
        ).Path
        $script:CrossHostModulePath = Join-Path (
            $script:CrossHostRepositoryRoot
        ) (
            'infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\' +
            'Caldova.HrFrontier.Bootstrap.psd1'
        )
        $script:CrossHostOrchestratorPath = Join-Path (
            $script:CrossHostRepositoryRoot
        ) 'infra\src\scripts\runbooks\Invoke-TenantLifecycle.ps1'
        $script:CrossHostFixturePath = Join-Path (
            $script:CrossHostRepositoryRoot
        ) 'infra\tests\fixtures\runbooks\tenant-lifecycle.synthetic.json'
        $script:CrossHostIntentTemplatePath = Join-Path (
            $script:CrossHostRepositoryRoot
        ) 'infra\src\config\tenants\_template.psd1'
        Import-Module $script:CrossHostModulePath -Force
    }

    It 'cross-host coordinate-only golden preserves source private drift error IDs and exact ordered dependency outcomes' {
        $runnerPath = Join-Path $TestDrive 'cross-host-orchestration-golden.ps1'
        $runner = @'
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ModulePath,
    [Parameter(Mandatory)][string]$OrchestratorPath,
    [Parameter(Mandatory)][string]$FixturePath,
    [Parameter(Mandatory)][string]$IntentTemplatePath,
    [Parameter(Mandatory)][string]$OutputRoot
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Import-Module $ModulePath -Force

function Write-GoldenCanonicalFile {
    param(
        [Parameter(Mandatory)][object]$InputObject,
        [Parameter(Mandatory)][string]$Path
    )

    [IO.Directory]::CreateDirectory((Split-Path -Parent $Path)) |
        Out-Null
    [IO.File]::WriteAllText(
        $Path,
        (ConvertTo-TenantLifecycleCanonicalJson -InputObject $InputObject),
        [Text.UTF8Encoding]::new($false)
    )
}

function New-GoldenGraphNode {
    param(
        [Parameter(Mandatory)][string]$Id,
        [string[]]$PrerequisiteIds = @()
    )

    [pscustomobject][ordered]@{
        id = $Id
        kind = 'Action'
        prerequisiteIds = @($PrerequisiteIds)
        requiredOutcome = 'Passed'
        inputDigest = 'a' * 64
        stage = 'Synthetic'
    }
}

function New-GoldenGraphOutcome {
    param(
        [Parameter(Mandatory)][string]$Classification,
        [Parameter(Mandatory)][string]$Status
    )

    [pscustomobject][ordered]@{
        id = 'Root'
        classification = $Classification
        status = $Status
        inputDigest = 'a' * 64
        readBackDigest = $null
    }
}

$sourceRoot = Join-Path $OutputRoot 'source'
$tenantRoot = Join-Path $sourceRoot 'infra\src\config\tenants'
[IO.Directory]::CreateDirectory($tenantRoot) | Out-Null
$intentPath = Join-Path $tenantRoot 'tenant1.local.psd1'
$statePath = Join-Path $tenantRoot 'tenant1.state.local.json'
$intent = [IO.File]::ReadAllText(
    $IntentTemplatePath,
    [Text.UTF8Encoding]::new($false, $true)
)
$intent = $intent.Replace(
    '    Components = @{}',
    "    Components = @{$([Environment]::NewLine)" +
    "        SyntheticResource = @{$([Environment]::NewLine)" +
    "            Provider = 'Synthetic'$([Environment]::NewLine)" +
    "            ResourceType = 'SyntheticResource'$([Environment]::NewLine)" +
    "            LogicalName = 'component-001'$([Environment]::NewLine)" +
    "            Mode = 'Existing'$([Environment]::NewLine)" +
    "            Id = 'stable-synthetic-001'$([Environment]::NewLine)" +
    "        }$([Environment]::NewLine)" +
    "    }"
)
[IO.File]::WriteAllText(
    $intentPath,
    $intent,
    [Text.UTF8Encoding]::new($false)
)
$fixture = ConvertFrom-TenantLifecycleJson -InputObject (
    [IO.File]::ReadAllText(
        $FixturePath,
        [Text.UTF8Encoding]::new($false, $true)
    )
)
Write-GoldenCanonicalFile -InputObject $fixture.state -Path $statePath
[IO.File]::WriteAllText(
    (Join-Path $sourceRoot '.gitignore'),
    (
        "/infra/src/config/tenants/tenant1.local.psd1`n" +
        "/infra/src/config/tenants/tenant1.state.local.json`n"
    ),
    [Text.UTF8Encoding]::new($false)
)
[IO.File]::WriteAllText(
    (Join-Path $sourceRoot 'tracked.txt'),
    "synthetic`n",
    [Text.UTF8Encoding]::new($false)
)
& git -C $sourceRoot init --quiet
& git -C $sourceRoot config user.email synthetic@example.invalid
& git -C $sourceRoot config user.name 'Synthetic Test'
& git -C $sourceRoot config core.autocrlf false
& git -C $sourceRoot add .gitignore tracked.txt
& git -C $sourceRoot commit --quiet -m 'synthetic source'
if ($LASTEXITCODE -ne 0) {
    throw 'Could not create the synthetic golden repository.'
}
$sourceCommit = (& git -C $sourceRoot rev-parse HEAD).Trim().ToLowerInvariant()
$pristineIntent = [IO.File]::ReadAllText(
    $intentPath,
    [Text.UTF8Encoding]::new($false, $true)
)
$pristineState = [IO.File]::ReadAllText(
    $statePath,
    [Text.UTF8Encoding]::new($false, $true)
)
$evidenceRoot = Join-Path $OutputRoot 'evidence'

function Get-GoldenDriftError {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Source', 'Intent', 'State')]
        [string]$Target
    )

    [IO.File]::WriteAllText(
        $intentPath,
        $pristineIntent,
        [Text.UTF8Encoding]::new($false)
    )
    [IO.File]::WriteAllText(
        $statePath,
        $pristineState,
        [Text.UTF8Encoding]::new($false)
    )
    $expectedCommit = $sourceCommit
    $breakpoint = $null
    if ($Target -ceq 'Source') {
        $expectedCommit = 'f' * 40
    }
    else {
        $bindingLine = @(
            Select-String `
                -LiteralPath $OrchestratorPath `
                -Pattern (
                    '^\s*\$verifiedCoordinates\s*=\s*' +
                    'Assert-TenantLifecycleBindings\s*$'
                ) |
                Select-Object -First 1
        ).LineNumber
        if ($null -eq $bindingLine) {
            throw 'Could not locate the Verify binding checkpoint.'
        }
        $triggered = $false
        $driftTarget = $Target
        $driftIntentPath = $intentPath
        $driftStatePath = $statePath
        $action = {
            if (-not $triggered) {
                $triggered = $true
                if ($driftTarget -ceq 'Intent') {
                    $content = [IO.File]::ReadAllText(
                        $driftIntentPath,
                        [Text.UTF8Encoding]::new($false, $true)
                    )
                    $content = $content.Replace(
                        "DisplayName = 'Example123456'",
                        "DisplayName = 'Example123456 Drift'"
                    )
                    [IO.File]::WriteAllText(
                        $driftIntentPath,
                        $content,
                        [Text.UTF8Encoding]::new($false)
                    )
                }
                else {
                    $content = [IO.File]::ReadAllText(
                        $driftStatePath,
                        [Text.UTF8Encoding]::new($false, $true)
                    )
                    $content = $content.Replace(
                        '2026-10-02T12:09:00.0000000Z',
                        '2026-10-02T12:10:00.0000000Z'
                    )
                    [IO.File]::WriteAllText(
                        $driftStatePath,
                        $content,
                        [Text.UTF8Encoding]::new($false)
                    )
                }
            }
        }.GetNewClosure()
        $breakpoint = Set-PSBreakpoint `
            -Script $OrchestratorPath `
            -Line $bindingLine `
            -Action $action
    }

    try {
        & $OrchestratorPath `
            -RunId ([guid]::NewGuid()) `
            -EvidenceRoot $evidenceRoot `
            -RepositoryRoot $sourceRoot `
            -ExpectedSourceCommit $expectedCommit `
            -PublicTenantKey tenant1 `
            -TenantConfigurationPath $intentPath `
            -TenantStatePath $statePath `
            -Stages @('Foundation') `
            -Mode Verify `
            -NowUtc ([datetime]'2026-10-03T08:00:00Z')
        throw "Expected $Target drift was accepted."
    }
    catch {
        if ($_.Exception.Message -clike 'Expected * drift was accepted.') {
            throw
        }
        [string]$_.Exception.Message
    }
    finally {
        if ($null -ne $breakpoint) {
            Remove-PSBreakpoint -Breakpoint $breakpoint
        }
    }
}

$nodes = @(
    New-GoldenGraphNode -Id Root
    New-GoldenGraphNode -Id Dependent -PrerequisiteIds @('Root')
)
$dependencyOutcomes = @(
    foreach ($case in @(
        @{ Name = 'Passed'; Classification = 'NoChange'; Status = 'Passed' }
        @{ Name = 'Failed'; Classification = 'NoChange'; Status = 'Failed' }
        @{ Name = 'Manual'; Classification = 'Manual'; Status = 'Passed' }
        @{ Name = 'Blocked'; Classification = 'Blocked'; Status = 'Passed' }
        @{ Name = 'Refused'; Classification = 'Refused'; Status = 'Passed' }
    )) {
        $resolved = @(
            Resolve-TenantLifecycleGraph `
                -Nodes $nodes `
                -ObservedOutcomes @(
                    New-GoldenGraphOutcome `
                        -Classification $case.Classification `
                        -Status $case.Status
                )
        )
        [pscustomobject][ordered]@{
            case = $case.Name
            statuses = [string[]]@($resolved.status)
            canExecute = [bool[]]@($resolved.canExecute)
            blockingPrerequisiteIds = [string[]]@(
                $resolved[1].blockingPrerequisiteIds
            )
        }
    }
)
$golden = [pscustomobject][ordered]@{
    driftErrorIds = [pscustomobject][ordered]@{
        Source = Get-GoldenDriftError -Target Source
        Intent = Get-GoldenDriftError -Target Intent
        State = Get-GoldenDriftError -Target State
    }
    dependencyOutcomes = $dependencyOutcomes
}
[IO.File]::WriteAllText(
    (Join-Path $OutputRoot 'golden-orchestration.json'),
    (ConvertTo-TenantLifecycleCanonicalJson -InputObject $golden),
    [Text.UTF8Encoding]::new($false)
)
'@
        [IO.File]::WriteAllText(
            $runnerPath,
            $runner,
            [Text.UTF8Encoding]::new($false)
        )

        $outputs = @{}
        foreach ($hostName in @('powershell.exe', 'pwsh.exe')) {
            $hostCommand = Get-Command `
                $hostName `
                -CommandType Application `
                -ErrorAction Stop |
                Select-Object -First 1
            $hostPath = $hostCommand.Source
            $hostKey = [IO.Path]::GetFileNameWithoutExtension($hostName)
            $outputRoot = Join-Path $TestDrive $hostKey
            [IO.Directory]::CreateDirectory($outputRoot) | Out-Null
            $hostOutput = @(
                & $hostPath `
                    -NoProfile `
                    -NonInteractive `
                    -ExecutionPolicy Bypass `
                    -File $runnerPath `
                    -ModulePath $script:CrossHostModulePath `
                    -OrchestratorPath $script:CrossHostOrchestratorPath `
                    -FixturePath $script:CrossHostFixturePath `
                    -IntentTemplatePath $script:CrossHostIntentTemplatePath `
                    -OutputRoot $outputRoot 2>&1
            )
            $LASTEXITCODE |
                Should -Be 0 -Because ($hostOutput -join [Environment]::NewLine)
            $outputs[$hostKey] = $outputRoot
        }

        $windowsBytes = [IO.File]::ReadAllBytes((
            Join-Path $outputs.powershell 'golden-orchestration.json'
        ))
        $coreBytes = [IO.File]::ReadAllBytes((
            Join-Path $outputs.pwsh 'golden-orchestration.json'
        ))
        [Convert]::ToBase64String($windowsBytes) |
            Should -BeExactly ([Convert]::ToBase64String($coreBytes))

        $golden = ConvertFrom-TenantLifecycleJson -InputObject (
            [Text.UTF8Encoding]::new($false, $true).GetString($windowsBytes)
        )
        $golden.driftErrorIds.Source |
            Should -BeExactly 'TenantLifecycle.Source.Drift'
        $golden.driftErrorIds.Intent |
            Should -BeExactly 'TenantLifecycle.Intent.Drift'
        $golden.driftErrorIds.State |
            Should -BeExactly 'TenantLifecycle.State.Drift'
        (
            @($golden.dependencyOutcomes | ForEach-Object {
                (
                    '{0}:{1}:{2}:{3}' -f
                        $_.case,
                        ($_.statuses -join ','),
                        ($_.canExecute -join ','),
                        ($_.blockingPrerequisiteIds -join ',')
                )
            }) -join ';'
        ) | Should -BeExactly (
            'Passed:Passed,NotRun:True,True:;' +
            'Failed:Failed,Blocked:True,False:Root;' +
            'Manual:Manual,Blocked:True,False:Root;' +
            'Blocked:Blocked,Blocked:True,False:Root;' +
            'Refused:Refused,Blocked:True,False:Root'
        )
    }
}

$coordinateMixedCaseProhibitedCases = @(
    @{
        Family = 'token'
        PropertyName = 'ToKeN'
    }
    @{
        Family = 'credential'
        PropertyName = 'CrEdEnTiAl'
    }
    @{
        Family = 'raw'
        PropertyName = 'RaWoUtPuT'
    }
    @{
        Family = 'private'
        PropertyName = 'PrIvAtEpAtH'
    }
    @{
        Family = 'output'
        PropertyName = 'CoMmAnDoUtPuT'
    }
)
$coordinateMixedCasePrerequisiteCases = @(
    foreach ($case in $coordinateMixedCaseProhibitedCases) {
        foreach ($mode in @('Assess', 'Plan')) {
            @{
                Family = $case.Family
                PropertyName = $case.PropertyName
                Mode = $mode
            }
        }
    }
)

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
                -SelectedStages @(
                    $script:ApprovalFixture.executionManifest.selectedStages
                ) `
                -PrerequisiteResults @(
                    $script:ApprovalFixture.executionManifest.prerequisiteResults
                ) `
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

    Describe 'Coordinate-only tenant lifecycle dispatch' {
                BeforeAll {
                    $script:CoordinateRepositoryRoot = (
                        Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
                    ).Path
                    $script:CoordinateModulePath = Join-Path $script:CoordinateRepositoryRoot (
                        'infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\' +
                        'Caldova.HrFrontier.Bootstrap.psd1'
                    )
                    $script:CoordinateOrchestratorPath = Join-Path $script:CoordinateRepositoryRoot (
                        'infra\src\scripts\runbooks\Invoke-TenantLifecycle.ps1'
                    )
                    $fixturePath = Join-Path $script:CoordinateRepositoryRoot (
                        'infra\tests\fixtures\runbooks\tenant-lifecycle.synthetic.json'
                    )
                    $script:CoordinateFixture = Get-Content -Raw -LiteralPath $fixturePath |
                        ConvertFrom-Json

                    function Get-CoordinatePrivateDigests {
                        $intentValue = Import-TenantConfiguration `
                            -Path $script:CoordinateIntentPath `
                            -ValidationStage Discovery `
                            -ExpectedPublicTenantKey tenant1
                        $intentDigestInput = $intentValue |
                            ConvertTo-Json -Depth 30 -Compress |
                            ConvertFrom-Json
                        $stateValue = Import-TenantLifecycleState `
                            -Path $script:CoordinateStatePath `
                            -PublicTenantKey tenant1

                        [pscustomobject][ordered]@{
                            intent = Get-RunbookContentDigest -InputObject $intentDigestInput
                            state = Get-RunbookContentDigest -InputObject $stateValue
                        }
                    }

                    function Write-CoordinateCanonicalFile {
                        param(
                            [Parameter(Mandatory)][object]$InputObject,
                            [Parameter(Mandatory)][string]$Path
                        )

                        $directory = Split-Path -Parent $Path
                        [IO.Directory]::CreateDirectory($directory) | Out-Null
                        $json = ConvertTo-TenantLifecycleCanonicalJson -InputObject $InputObject
                        [IO.File]::WriteAllText(
                            $Path,
                            $json,
                            [Text.UTF8Encoding]::new($false)
                        )
                    }

                    function Get-CoordinateExactFileDigest {
                        param([Parameter(Mandatory)][string]$Path)

                        $algorithm = [Security.Cryptography.SHA256]::Create()
                        try {
                            -join @(
                                $algorithm.ComputeHash(
                                    [IO.File]::ReadAllBytes($Path)
                                ) |
                                    ForEach-Object { $_.ToString('x2') }
                            )
                        }
                        finally {
                            $algorithm.Dispose()
                        }
                    }

                    function Write-CoordinateStageResult {
                        param(
                            [Parameter(Mandatory)][guid]$RunId,
                            [Parameter(Mandatory)][string]$Stage,
                            [string[]]$SelectedStages,
                            [ValidateSet('Passed', 'Failed')][string]$Status = 'Passed'
                        )

                        if ($null -eq $SelectedStages) {
                            $SelectedStages = [string[]]@($Stage)
                        }
                        $digests = Get-CoordinatePrivateDigests
                        $classification = if ($Status -ceq 'Passed') {
                            'NoChange'
                        }
                        else {
                            'Changed'
                        }
                        $runDirectory = Join-Path (
                            $script:CoordinateEvidenceRoot
                        ) $RunId.ToString('D').ToLowerInvariant()
                        $phaseDirectory = Join-Path $runDirectory (
                            "phases\$Stage"
                        )
                        $stageIndex = [Array]::IndexOf(
                            [string[]]$SelectedStages,
                            $Stage
                        )
                        if ($stageIndex -lt 0) {
                            throw 'Stage must be present in SelectedStages.'
                        }
                        [object[]]$prerequisiteResults = @()
                        if ($stageIndex -gt 0) {
                            $prerequisiteStage = [string]$SelectedStages[
                                $stageIndex - 1
                            ]
                            $prerequisitePath = Join-Path $runDirectory (
                                "stage-results\$prerequisiteStage.json"
                            )
                            $prerequisite = Get-Content `
                                -Raw `
                                -LiteralPath $prerequisitePath |
                                ConvertFrom-Json
                            $prerequisiteResults = @(
                                [pscustomobject][ordered]@{
                                    stage = [string]$prerequisite.stage
                                    status = [string]$prerequisite.status
                                    classification =
                                        [string]$prerequisite.classification
                                    phaseManifestDigest =
                                        [string]$prerequisite.phaseManifestDigest
                                    phaseSummaryDigest =
                                        [string]$prerequisite.phaseSummaryDigest
                                    intentDigest =
                                        [string]$prerequisite.intentDigest
                                    stateDigest =
                                        [string]$prerequisite.stateDigest
                                }
                            )
                        }
                        $action = (
                            $script:CoordinateFixture.executionManifest.actions[0] |
                                ConvertTo-Json -Depth 30 |
                                ConvertFrom-Json
                        )
                        $action.id = $Stage
                        $action.prerequisiteActionIds = [string[]]@()
                        $manifest = New-TenantLifecycleExecutionManifest `
                            -RunId $RunId `
                            -SourceCommit $script:CoordinateSourceCommit `
                            -EvidenceRoot $phaseDirectory `
                            -PublicTenantKey tenant1 `
                            -IntentDigest $digests.intent `
                            -StateDigest $digests.state `
                            -SelectedStages $SelectedStages `
                            -PrerequisiteResults $prerequisiteResults `
                            -Machine (
                                $script:CoordinateFixture.executionManifest.machine
                            ) `
                            -Operator (
                                $script:CoordinateFixture.executionManifest.operator
                            ) `
                            -ToolIdentities @(
                                $script:CoordinateFixture.executionManifest.toolIdentities
                            ) `
                            -ProviderContexts @(
                                $script:CoordinateFixture.executionManifest.providerContexts
                            ) `
                            -Prerequisites @(
                                $script:CoordinateFixture.executionManifest.prerequisites
                            ) `
                            -Actions @($action) `
                            -GeneratedAtUtc ([datetime]'2026-10-03T08:00:00Z') `
                            -ExpiresAtUtc ([datetime]'2026-10-03T08:30:00Z')
                        $manifestPath = Join-Path $phaseDirectory (
                            'execution-manifest.json'
                        )
                        $manifestPath = Write-TenantLifecycleEvidence `
                            -RunDirectory $phaseDirectory `
                            -RelativePath 'execution-manifest.json' `
                            -Kind ExecutionManifest `
                            -InputObject $manifest
                        $manifestDigest = Get-CoordinateExactFileDigest `
                            -Path $manifestPath
                        $summary = (
                            $script:CoordinateFixture.phaseSummary |
                                ConvertTo-Json -Depth 30 |
                                ConvertFrom-Json
                        )
                        $summary.runId =
                            $RunId.ToString('D').ToLowerInvariant()
                        $summary.stage = $Stage
                        $summary.sourceCommit =
                            $script:CoordinateSourceCommit
                        $summary.publicTenantKey = 'tenant1'
                        $summary.intentDigest = $digests.intent
                        $summary.stateDigest = $digests.state
                        $summary.phaseManifestDigest = $manifestDigest
                        $summary.status = $Status
                        $summary.classification = $classification
                        $summary.startedAtUtc =
                            '2026-10-03T08:30:00.0000000Z'
                        $summary.completedAtUtc =
                            '2026-10-03T08:31:00.000Z'
                        $summary.actions[0].id = $Stage
                        $summary.actions[0].classification = if (
                            $classification -ceq 'Changed'
                        ) {
                            'Update'
                        }
                        else {
                            $classification
                        }
                        $summary.actions[0].status = $Status
                        $summary.actions[0].evidenceRelativePath =
                            "actions/$Stage.json"
                        $summaryPath = Write-TenantLifecycleEvidence `
                            -RunDirectory $phaseDirectory `
                            -RelativePath 'summary.json' `
                            -Kind Summary `
                            -InputObject $summary
                        $summaryDigest = Get-CoordinateExactFileDigest `
                            -Path $summaryPath
                        $result = New-TenantLifecycleStageResult `
                            -RunId $RunId `
                            -Stage $Stage `
                            -SourceCommit $script:CoordinateSourceCommit `
                            -PublicTenantKey tenant1 `
                            -IntentDigest $digests.intent `
                            -StateDigest $digests.state `
                            -PhaseManifestDigest $manifestDigest `
                            -PhaseSummaryDigest $summaryDigest `
                            -Status $Status `
                            -Classification $classification `
                            -EvidenceRelativePath "phases/$Stage/summary.json" `
                            -CompletedAtUtc (
                                [datetime]'2026-10-03T08:31:00Z'
                            )
                        Write-TenantLifecycleStageResult `
                            -RunDirectory $runDirectory `
                            -StageResult $result |
                            Out-Null
                    }

                    function Set-CoordinateSummaryEnvelopeMismatch {
                        param(
                            [Parameter(Mandatory)][guid]$RunId,
                            [Parameter(Mandatory)][string]$Stage
                        )

                        $runDirectory = Join-Path (
                            $script:CoordinateEvidenceRoot
                        ) $RunId.ToString('D').ToLowerInvariant()
                        $summaryPath = Join-Path $runDirectory (
                            "phases\$Stage\summary.json"
                        )
                        $summary =
                            ConvertFrom-TenantLifecycleJson -InputObject (
                                Get-Content `
                                    -Raw `
                                    -LiteralPath $summaryPath
                            )
                        $summary.runId =
                            'bbbbbbbb-cccc-4ddd-8eee-ffffffffffff'
                        Write-CoordinateCanonicalFile `
                            -InputObject $summary `
                            -Path $summaryPath

                        $resultPath = Join-Path $runDirectory (
                            "stage-results\$Stage.json"
                        )
                        $result =
                            ConvertFrom-TenantLifecycleJson -InputObject (
                                Get-Content `
                                    -Raw `
                                    -LiteralPath $resultPath
                            )
                        $result.phaseSummaryDigest =
                            Get-CoordinateExactFileDigest `
                                -Path $summaryPath
                        Write-CoordinateCanonicalFile `
                            -InputObject $result `
                            -Path $resultPath
                    }

                    function Add-CoordinateOpaqueProviderExtras {
                        param(
                            [Parameter(Mandatory)][guid]$RunId,
                            [Parameter(Mandatory)][string]$Stage
                        )

                        $runDirectory = Join-Path (
                            $script:CoordinateEvidenceRoot
                        ) $RunId.ToString('D').ToLowerInvariant()
                        $summaryPath = Join-Path $runDirectory (
                            "phases\$Stage\summary.json"
                        )
                        $summary =
                            ConvertFrom-TenantLifecycleJson -InputObject (
                                Get-Content `
                                    -Raw `
                                    -LiteralPath $summaryPath
                            )
                        $summary |
                            Add-Member `
                                -NotePropertyName opaqueProviderExtras `
                                -NotePropertyValue (
                                    [pscustomobject][ordered]@{
                                        providerId =
                                            'provider-id-synthetic-001'
                                        providerName =
                                            'Synthetic Provider'
                                        providerUrl = (
                                            'https://provider.example.invalid/' +
                                            'resources/synthetic-001'
                                        )
                                        actions = @('inspect', 'report')
                                        nested = [pscustomobject][ordered]@{
                                            values = @(
                                                'nested-provider-value-synthetic'
                                            )
                                        }
                                    }
                                )
                        Write-CoordinateCanonicalFile `
                            -InputObject $summary `
                            -Path $summaryPath

                        $resultPath = Join-Path $runDirectory (
                            "stage-results\$Stage.json"
                        )
                        $result =
                            ConvertFrom-TenantLifecycleJson -InputObject (
                                Get-Content `
                                    -Raw `
                                    -LiteralPath $resultPath
                            )
                        $result.phaseSummaryDigest =
                            Get-CoordinateExactFileDigest `
                                -Path $summaryPath
                        Write-CoordinateCanonicalFile `
                            -InputObject $result `
                            -Path $resultPath
                        $result.phaseSummaryDigest |
                            Should -BeExactly (
                                Get-CoordinateExactFileDigest `
                                    -Path $summaryPath
                            )
                    }

                    function Set-CoordinateMixedCaseProhibitedSummary {
                        param(
                            [Parameter(Mandatory)][guid]$RunId,
                            [Parameter(Mandatory)][string]$Stage,
                            [Parameter(Mandatory)][string]$PropertyName,
                            [Parameter(Mandatory)][string]$Marker
                        )

                        $runDirectory = Join-Path (
                            $script:CoordinateEvidenceRoot
                        ) $RunId.ToString('D').ToLowerInvariant()
                        $summaryPath = Join-Path $runDirectory (
                            "phases\$Stage\summary.json"
                        )
                        $summary =
                            ConvertFrom-TenantLifecycleJson -InputObject (
                                Get-Content `
                                    -Raw `
                                    -LiteralPath $summaryPath
                            )
                        $summary |
                            Add-Member `
                                -NotePropertyName syntheticBoundaryMutation `
                                -NotePropertyValue (
                                    [pscustomobject][ordered]@{
                                        safe = 'Synthetic'
                                    }
                                )
                        $summary.syntheticBoundaryMutation |
                            Add-Member `
                                -NotePropertyName $PropertyName `
                                -NotePropertyValue $Marker
                        Write-CoordinateCanonicalFile `
                            -InputObject $summary `
                            -Path $summaryPath

                        $resultPath = Join-Path $runDirectory (
                            "stage-results\$Stage.json"
                        )
                        $result =
                            ConvertFrom-TenantLifecycleJson -InputObject (
                                Get-Content `
                                    -Raw `
                                    -LiteralPath $resultPath
                            )
                        $result.phaseSummaryDigest =
                            Get-CoordinateExactFileDigest `
                                -Path $summaryPath
                        Write-CoordinateCanonicalFile `
                            -InputObject $result `
                            -Path $resultPath
                        $result.phaseSummaryDigest |
                            Should -BeExactly (
                                Get-CoordinateExactFileDigest `
                                    -Path $summaryPath
                            )
                    }

                    function Set-CoordinateCoordinatedSummarySubstitution {
                        param(
                            [Parameter(Mandatory)][guid]$RunId,
                            [Parameter(Mandatory)][string]$Stage
                        )

                        $foreignRunId =
                            'bbbbbbbb-cccc-4ddd-8eee-ffffffffffff'
                        $runDirectory = Join-Path (
                            $script:CoordinateEvidenceRoot
                        ) $RunId.ToString('D').ToLowerInvariant()
                        $summaryPath = Join-Path $runDirectory (
                            "phases\$Stage\summary.json"
                        )
                        $summary =
                            ConvertFrom-TenantLifecycleJson -InputObject (
                                Get-Content `
                                    -Raw `
                                    -LiteralPath $summaryPath
                            )
                        $summary.runId = $foreignRunId
                        Write-CoordinateCanonicalFile `
                            -InputObject $summary `
                            -Path $summaryPath

                        $resultPath = Join-Path $runDirectory (
                            "stage-results\$Stage.json"
                        )
                        $result =
                            ConvertFrom-TenantLifecycleJson -InputObject (
                                Get-Content `
                                    -Raw `
                                    -LiteralPath $resultPath
                            )
                        $result.runId = $foreignRunId
                        $result.phaseSummaryDigest =
                            Get-CoordinateExactFileDigest `
                                -Path $summaryPath
                        Write-CoordinateCanonicalFile `
                            -InputObject $result `
                            -Path $resultPath
                        $result.phaseSummaryDigest |
                            Should -BeExactly (
                                Get-CoordinateExactFileDigest `
                                    -Path $summaryPath
                            )
                    }

                    function Set-CoordinateDrift {
                        param(
                            [Parameter(Mandatory)]
                            [ValidateSet('Source', 'Intent', 'State')]
                            [string]$Target,
                            [Parameter(Mandatory)][string]$RepositoryRoot,
                            [Parameter(Mandatory)][string]$IntentPath,
                            [Parameter(Mandatory)][string]$StatePath
                        )

                        switch ($Target) {
                            'Source' {
                                [IO.File]::AppendAllText(
                                    (Join-Path $RepositoryRoot 'tracked.txt'),
                                    "drift`n",
                                    [Text.UTF8Encoding]::new($false)
                                )
                                & git -C $RepositoryRoot add tracked.txt
                                & git -C $RepositoryRoot commit --quiet -m 'drift'
                                if ($LASTEXITCODE -ne 0) {
                                    throw 'Could not create synthetic source drift.'
                                }
                            }
                            'Intent' {
                                $content = [IO.File]::ReadAllText(
                                    $IntentPath,
                                    [Text.UTF8Encoding]::new($false, $true)
                                )
                                $content = [regex]::Replace(
                                    $content,
                                    "(?m)^\s*DisplayName\s*=\s*'[^']+'\s*$",
                                    "    DisplayName = 'Example123456 Drift'"
                                )
                                [IO.File]::WriteAllText(
                                    $IntentPath,
                                    $content,
                                    [Text.UTF8Encoding]::new($false)
                                )
                            }
                            'State' {
                                $state = Get-Content `
                                    -Raw `
                                    -LiteralPath $StatePath |
                                    ConvertFrom-Json
                                $state.resources[0].lastVerifiedAtUtc =
                                    '2026-10-03T08:31:01.0000000Z'
                                Write-CoordinateCanonicalFile `
                                    -InputObject $state `
                                    -Path $StatePath
                            }
                        }
                    }

                    function Install-CoordinateValidationDriftHook {
                        param(
                            [Parameter(Mandatory)]
                            [ValidateSet('Assessment', 'StageResult')]
                            [string]$ContractKind,
                            [Parameter(Mandatory)]
                            [ValidateSet('Source', 'Intent', 'State')]
                            [string]$DriftTarget,
                            [Parameter(Mandatory)][string]$RepositoryRoot,
                            [Parameter(Mandatory)][string]$IntentPath,
                            [Parameter(Mandatory)][string]$StatePath
                        )

                        $bindingLines = @(
                            Select-String `
                                -LiteralPath $script:CoordinateOrchestratorPath `
                                -Pattern (
                                    '^\s*\$verifiedCoordinates\s*=\s*' +
                                    'Assert-TenantLifecycleBindings\s*$'
                                ) |
                                ForEach-Object LineNumber
                        )
                        if ($bindingLines.Count -lt 3) {
                            throw 'Synthetic drift breakpoint could not be located.'
                        }
                        $bindingLines = @(
                            $bindingLines |
                                Select-Object -Last 3
                        )
                        $line = if ($ContractKind -ceq 'Assessment') {
                            $bindingLines[2]
                        }
                        else {
                            (
                                Select-String `
                                    -LiteralPath $script:CoordinateOrchestratorPath `
                                    -Pattern (
                                        '^\s*Read-TenantLifecyclePrerequisite\s+' +
                                        '-Stage\s+\$prerequisiteStage\s*$'
                                    )
                            ).LineNumber
                        }
                        $drifter = ${function:Set-CoordinateDrift}
                        $triggered = $false
                        $action = {
                            if (-not $triggered) {
                                $triggered = $true
                                & $drifter `
                                    -Target $DriftTarget `
                                    -RepositoryRoot $RepositoryRoot `
                                    -IntentPath $IntentPath `
                                    -StatePath $StatePath
                            }
                        }.GetNewClosure()
                        $breakpoint = Set-PSBreakpoint `
                            -Script $script:CoordinateOrchestratorPath `
                            -Line $line `
                            -Action $action
                        $script:CoordinateBreakpoints.Add($breakpoint)
                    }

                    function Install-CoordinateEvidenceMutationHook {
                        param(
                            [Parameter(Mandatory)]
                            [ValidateSet(
                                'Result',
                                'Manifest',
                                'Summary',
                                'Extra',
                                'Missing',
                                'Path'
                            )]
                            [string]$Mutation,
                            [Parameter(Mandatory)][guid]$RunId,
                            [string]$Stage = 'Foundation'
                        )

                        $line = (
                            Select-String `
                                -LiteralPath $script:CoordinateOrchestratorPath `
                                -Pattern (
                                    '^\s*\$stageNodes\s*=\s*' +
                                    '\[Collections[.]Generic[.]List\[object\]\]'
                                )
                        ).LineNumber
                        if (@($line).Count -ne 1) {
                            throw (
                                'Synthetic evidence mutation breakpoint ' +
                                'could not be located.'
                            )
                        }
                        $runDirectory = Join-Path (
                            $script:CoordinateEvidenceRoot
                        ) $RunId.ToString('D').ToLowerInvariant()
                        $writer =
                            ${function:Write-CoordinateCanonicalFile}
                        $triggered = $false
                        $action = {
                            if ($triggered) {
                                return
                            }
                            $triggered = $true
                            $resultDirectory = Join-Path $runDirectory (
                                'stage-results'
                            )
                            $resultPath = Join-Path $resultDirectory (
                                "$Stage.json"
                            )
                            $manifestPath = Join-Path $runDirectory (
                                "phases\$Stage\execution-manifest.json"
                            )
                            $summaryPath = Join-Path $runDirectory (
                                "phases\$Stage\summary.json"
                            )
                            switch ($Mutation) {
                                'Result' {
                                    $result = Get-Content `
                                        -Raw `
                                        -LiteralPath $resultPath |
                                        ConvertFrom-Json
                                    $result.completedAtUtc =
                                        '2026-10-03T08:31:00.001Z'
                                    & $writer `
                                        -InputObject $result `
                                        -Path $resultPath
                                }
                                'Manifest' {
                                    [IO.File]::AppendAllText(
                                        $manifestPath,
                                        ' ',
                                        [Text.UTF8Encoding]::new($false)
                                    )
                                }
                                'Summary' {
                                    [IO.File]::AppendAllText(
                                        $summaryPath,
                                        ' ',
                                        [Text.UTF8Encoding]::new($false)
                                    )
                                }
                                'Extra' {
                                    [IO.File]::WriteAllText(
                                        (Join-Path $resultDirectory (
                                            'extra.json'
                                        )),
                                        "{}`n",
                                        [Text.UTF8Encoding]::new($false)
                                    )
                                }
                                'Missing' {
                                    Remove-Item `
                                        -LiteralPath $resultPath `
                                        -Force
                                }
                                'Path' {
                                    $temporaryPath = Join-Path $runDirectory (
                                        '.case-stage-results'
                                    )
                                    Move-Item `
                                        -LiteralPath $resultDirectory `
                                        -Destination $temporaryPath
                                    Move-Item `
                                        -LiteralPath $temporaryPath `
                                        -Destination (
                                            Join-Path $runDirectory (
                                                'Stage-Results'
                                            )
                                        )
                                }
                            }
                        }.GetNewClosure()
                        $breakpoint = Set-PSBreakpoint `
                            -Script $script:CoordinateOrchestratorPath `
                            -Line $line `
                            -Action $action
                        $script:CoordinateBreakpoints.Add($breakpoint)
                    }

                    function Install-CoordinateVerifyPassCounter {
                        param([Parameter(Mandatory)][guid]$RunId)

                        $lines = @(
                            Select-String `
                                -LiteralPath $script:CoordinateOrchestratorPath `
                                -Pattern (
                                    '^\s*Test-TenantLifecycleStageResultSet\s*'
                                ) |
                                ForEach-Object LineNumber
                        )
                        if ($lines.Count -ne 2) {
                            throw (
                                'Synthetic Verify pass breakpoints ' +
                                'could not be located.'
                            )
                        }
                        $runDirectory = Join-Path (
                            $script:CoordinateEvidenceRoot
                        ) $RunId.ToString('D').ToLowerInvariant()
                        $counterPath = Join-Path $runDirectory (
                            '.test-observation\verify-passes.txt'
                        )
                        foreach ($line in $lines) {
                            $action = {
                                [IO.Directory]::CreateDirectory(
                                    (Split-Path -Parent $counterPath)
                                ) | Out-Null
                                [IO.File]::AppendAllText(
                                    $counterPath,
                                    "pass`n",
                                    [Text.UTF8Encoding]::new($false)
                                )
                            }.GetNewClosure()
                            $breakpoint = Set-PSBreakpoint `
                                -Script $script:CoordinateOrchestratorPath `
                                -Line $line `
                                -Action $action
                            $script:CoordinateBreakpoints.Add($breakpoint)
                        }
                        $counterPath
                    }

                    function Get-CoordinateObservedCalls {
                        param([Parameter(Mandatory)][guid]$RunId)

                        $path = Join-Path $script:CoordinateEvidenceRoot (
                            Join-Path $RunId.ToString('D') (
                                '.test-observation\calls.txt'
                            )
                        )
                        if (-not [IO.File]::Exists($path)) {
                            return @()
                        }
                        @([IO.File]::ReadAllLines(
                            $path,
                            [Text.UTF8Encoding]::new($false, $true)
                        ))
                    }

                    function Get-CoordinateObservedRecords {
                        param(
                            [Parameter(Mandatory)][guid]$RunId,
                            [Parameter(Mandatory)][string[]]$Stages
                        )

                        $records = [Collections.Generic.List[object]]::new()
                        foreach ($stage in $Stages) {
                            $path = Join-Path $script:CoordinateEvidenceRoot (
                                Join-Path $RunId.ToString('D') (
                                    ".test-observation\record-$stage.json"
                                )
                            )
                            if ([IO.File]::Exists($path)) {
                                $records.Add((
                                    [IO.File]::ReadAllText(
                                        $path,
                                        [Text.UTF8Encoding]::new($false, $true)
                                    ) | ConvertFrom-Json
                                ))
                            }
                        }
                        @($records.ToArray())
                    }

                    function Test-CoordinateProviderMarker {
                        param([Parameter(Mandatory)][guid]$RunId)

                        $path = Join-Path $script:CoordinateEvidenceRoot (
                            Join-Path $RunId.ToString('D') (
                                '.test-observation\provider-call.txt'
                            )
                        )
                        [IO.File]::Exists($path)
                    }

                    function New-CoordinateArtifactInvoker {
                        param(
                            [ValidateSet('None', 'Assess', 'Plan')]
                            [string]$ArtifactMode = 'None',
                            [ValidateSet('None', 'Source', 'Intent', 'State')]
                            [string]$DuringDrift = 'None',
                            [string]$ArtifactStage,
                            [switch]$ReturnProviderData,
                            [switch]$TamperDynamicScope,
                            [switch]$TamperAuthoritativeScope,
                            [switch]$SpawnInheritedHandleDescendant,
                            [switch]$WriteDirectOutput,
                            [ValidateSet(
                                'None',
                                'SelectedStages',
                                'PrerequisiteResults'
                            )]
                            [string]$PlanBindingMutation = 'None'
                        )

                        $settings = [pscustomobject][ordered]@{
                            artifactMode = $ArtifactMode
                            duringDrift = $DuringDrift
                            artifactStage = $ArtifactStage
                            returnProviderData = [bool]$ReturnProviderData
                            tamperDynamicScope = [bool]$TamperDynamicScope
                            tamperAuthoritativeScope = [bool]$TamperAuthoritativeScope
                            spawnInheritedHandleDescendant =
                                [bool]$SpawnInheritedHandleDescendant
                            writeDirectOutput = [bool]$WriteDirectOutput
                            planBindingMutation = $PlanBindingMutation
                            fixture = $script:CoordinateFixture
                            modulePath = $script:CoordinateModulePath
                            repositoryRoot = $script:CoordinateSyntheticRepository
                            intentPath = $script:CoordinateIntentPath
                            statePath = $script:CoordinateStatePath
                        }
                        $settingsBase64 = [Convert]::ToBase64String(
                            [Text.Encoding]::UTF8.GetBytes((
                                $settings |
                                    ConvertTo-Json -Depth 30 -Compress
                            ))
                        )
                        $invokerText = @'
                            param(
                                [Parameter(Mandatory)][string]$Stage,
                                [Parameter(Mandatory)][string]$Mode,
                                [Parameter(Mandatory)][object]$ControlRecord
                            )

                            $settings = [Text.Encoding]::UTF8.GetString(
                                [Convert]::FromBase64String(
                                    '__SETTINGS_BASE64__'
                                )
                            ) | ConvertFrom-Json
                            Import-Module ([string]$settings.modulePath) -Force
                            $runDirectory = [IO.Path]::GetFullPath((
                                [IO.Path]::Combine(
                                    [Environment]::CurrentDirectory,
                                    [string]$ControlRecord.evidenceRunRelativePath
                                )
                            ))
                            $observationDirectory = [IO.Path]::Combine(
                                $runDirectory,
                                '.test-observation'
                            )
                            [IO.Directory]::CreateDirectory(
                                $observationDirectory
                            ) | Out-Null
                            [IO.File]::AppendAllText(
                                [IO.Path]::Combine(
                                    $observationDirectory,
                                    'calls.txt'
                                ),
                                "$Stage|$Mode`n",
                                [Text.UTF8Encoding]::new($false)
                            )
                            [IO.File]::WriteAllText(
                                [IO.Path]::Combine(
                                    $observationDirectory,
                                    "record-$Stage.json"
                                ),
                                (
                                    $ControlRecord |
                                        ConvertTo-Json -Depth 30 -Compress
                                ),
                                [Text.UTF8Encoding]::new($false)
                            )
                            if (
                                [bool]$settings.spawnInheritedHandleDescendant
                            ) {
                                $descendantMarker = [IO.Path]::Combine(
                                    $observationDirectory,
                                    'descendant-completed.txt'
                                )
                                $markerBase64 = [Convert]::ToBase64String(
                                    [Text.Encoding]::UTF8.GetBytes(
                                        $descendantMarker
                                    )
                                )
                                $descendantScript = @(
                                    'Start-Sleep -Seconds 4'
                                    (
                                        '$markerPath = ' +
                                        '[Text.Encoding]::UTF8.GetString('
                                    )
                                    (
                                        '    [Convert]::FromBase64String(' +
                                        "'$markerBase64')"
                                    )
                                    ')'
                                    '[IO.File]::WriteAllText('
                                    '    $markerPath,'
                                    "    'completed',"
                                    (
                                        '    [Text.UTF8Encoding]::new(' +
                                        '$false)'
                                    )
                                    ')'
                                ) -join "`n"
                                $descendantHostName = if (
                                    $PSVersionTable.PSEdition -ceq 'Core'
                                ) {
                                    'pwsh.exe'
                                }
                                else {
                                    'powershell.exe'
                                }
                                $descendantStartInfo =
                                    [Diagnostics.ProcessStartInfo]::new()
                                $descendantStartInfo.FileName = Join-Path (
                                    $PSHOME
                                ) $descendantHostName
                                $descendantStartInfo.Arguments = (
                                    '-NoLogo -NoProfile -NonInteractive ' +
                                    '-EncodedCommand ' +
                                    [Convert]::ToBase64String(
                                        [Text.Encoding]::Unicode.GetBytes(
                                            $descendantScript
                                        )
                                    )
                                )
                                $descendantStartInfo.UseShellExecute = $false
                                $descendantStartInfo.CreateNoWindow = $true
                                $descendant =
                                    [Diagnostics.Process]::Start(
                                        $descendantStartInfo
                                    )
                                [IO.File]::WriteAllText(
                                    [IO.Path]::Combine(
                                        $observationDirectory,
                                        'descendant-pid.txt'
                                    ),
                                    ([string]$descendant.Id),
                                    [Text.UTF8Encoding]::new($false)
                                )
                                $descendant.Dispose()
                            }
                            if ([bool]$settings.writeDirectOutput) {
                                $stdoutBytes = [Text.Encoding]::UTF8.GetBytes(
                                    'UNEXPECTED_INVOKER_STDOUT'
                                )
                                $stderrBytes = [Text.Encoding]::UTF8.GetBytes(
                                    'UNEXPECTED_INVOKER_STDERR'
                                )
                                $stdoutStream =
                                    [Console]::OpenStandardOutput()
                                $stderrStream =
                                    [Console]::OpenStandardError()
                                $stdoutStream.Write(
                                    $stdoutBytes,
                                    0,
                                    $stdoutBytes.Length
                                )
                                $stderrStream.Write(
                                    $stderrBytes,
                                    0,
                                    $stderrBytes.Length
                                )
                                $stdoutStream.Flush()
                                $stderrStream.Flush()
                            }

                            $modeToWrite = if (
                                [string]$settings.artifactMode -ceq 'None'
                            ) {
                                $Mode
                            }
                            else {
                                [string]$settings.artifactMode
                            }
                            $artifactStage = if (
                                [string]::IsNullOrEmpty(
                                    [string]$settings.artifactStage
                                )
                            ) {
                                $Stage
                            }
                            else {
                                [string]$settings.artifactStage
                            }
                            $phaseDirectory = [IO.Path]::Combine(
                                $runDirectory,
                                'phases',
                                $Stage
                            )
                            [IO.Directory]::CreateDirectory(
                                $phaseDirectory
                            ) | Out-Null
                            if ($modeToWrite -ceq 'Assess') {
                                $assessment = (
                                    $settings.fixture.assessment |
                                        ConvertTo-Json -Depth 30 |
                                        ConvertFrom-Json
                                )
                                $assessment.runId = [string]$ControlRecord.runId
                                $assessment.sourceCommit =
                                    [string]$ControlRecord.sourceCommit
                                $assessment.publicTenantKey =
                                    [string]$ControlRecord.publicTenantKey
                                $assessment.intentDigest =
                                    [string]$ControlRecord.intentDigest
                                $assessment.stateDigest =
                                    [string]$ControlRecord.stateDigest
                                $assessment.kind = $artifactStage
                                $unsigned = [ordered]@{}
                                foreach (
                                    $property in $assessment.PSObject.Properties
                                ) {
                                    if ($property.Name -cne 'digest') {
                                        $unsigned[$property.Name] =
                                            $property.Value
                                    }
                                }
                                $assessment.digest =
                                    Get-RunbookContentDigest -InputObject (
                                        [pscustomobject]$unsigned
                                    )
                                $artifact = $assessment
                                $artifactPath = [IO.Path]::Combine(
                                    $phaseDirectory,
                                    'assessment.json'
                                )
                            }
                            else {
                                $action = (
                                    $settings.fixture.executionManifest.actions[0] |
                                        ConvertTo-Json -Depth 30 |
                                        ConvertFrom-Json
                                )
                                $action.id = $artifactStage
                                $action.prerequisiteActionIds = [string[]]@()
                                $artifact = New-TenantLifecycleExecutionManifest `
                                    -RunId ([guid]$ControlRecord.runId) `
                                    -SourceCommit (
                                        [string]$ControlRecord.sourceCommit
                                    ) `
                                    -EvidenceRoot $phaseDirectory `
                                    -PublicTenantKey (
                                        [string]$ControlRecord.publicTenantKey
                                    ) `
                                    -IntentDigest (
                                        [string]$ControlRecord.intentDigest
                                    ) `
                                    -StateDigest (
                                        [string]$ControlRecord.stateDigest
                                    ) `
                                    -SelectedStages @(
                                        $ControlRecord.selectedStages
                                    ) `
                                    -PrerequisiteResults @(
                                        $ControlRecord.prerequisiteResults
                                    ) `
                                    -Machine (
                                        $settings.fixture.executionManifest.machine
                                    ) `
                                    -Operator (
                                        $settings.fixture.executionManifest.operator
                                    ) `
                                    -ToolIdentities @(
                                        $settings.fixture.executionManifest.toolIdentities
                                    ) `
                                    -ProviderContexts @(
                                        $settings.fixture.executionManifest.providerContexts
                                    ) `
                                    -Prerequisites @(
                                        $settings.fixture.executionManifest.prerequisites
                                    ) `
                                    -Actions @($action) `
                                    -GeneratedAtUtc (
                                        [datetime]'2026-10-03T08:00:00Z'
                                    ) `
                                    -ExpiresAtUtc (
                                        [datetime]'2026-10-03T08:30:00Z'
                                    )
                                switch (
                                    [string]$settings.planBindingMutation
                                ) {
                                    'SelectedStages' {
                                        $artifact.selectedStages =
                                            [string[]]@(
                                                'Foundation',
                                                'ReadBack'
                                            )
                                    }
                                    'PrerequisiteResults' {
                                        if (
                                            @(
                                                $artifact.prerequisiteResults
                                            ).Count -gt 0
                                        ) {
                                            $artifact.prerequisiteResults[
                                                0
                                            ].stateDigest = 'f' * 64
                                        }
                                    }
                                }
                                if (
                                    [string]$settings.planBindingMutation -cne
                                    'None'
                                ) {
                                    $unsignedManifest = [ordered]@{}
                                    foreach (
                                        $property in
                                            $artifact.PSObject.Properties
                                    ) {
                                        if ($property.Name -cne 'digest') {
                                            $unsignedManifest[
                                                $property.Name
                                            ] = $property.Value
                                        }
                                    }
                                    $artifact.digest =
                                        Get-RunbookContentDigest `
                                            -InputObject (
                                                [pscustomobject]$unsignedManifest
                                            )
                                }
                                $artifactPath = [IO.Path]::Combine(
                                    $phaseDirectory,
                                    'execution-manifest.json'
                                )
                            }
                            [IO.File]::WriteAllText(
                                $artifactPath,
                                (
                                    ConvertTo-TenantLifecycleCanonicalJson `
                                        -InputObject $artifact
                                ),
                                [Text.UTF8Encoding]::new($false)
                            )

                            switch ([string]$settings.duringDrift) {
                                'Source' {
                                    [IO.File]::AppendAllText(
                                        [IO.Path]::Combine(
                                            [string]$settings.repositoryRoot,
                                            'tracked.txt'
                                        ),
                                        "drift`n",
                                        [Text.UTF8Encoding]::new($false)
                                    )
                                }
                                'Intent' {
                                    $content = [IO.File]::ReadAllText(
                                        [string]$settings.intentPath,
                                        [Text.UTF8Encoding]::new(
                                            $false,
                                            $true
                                        )
                                    )
                                    $content = [regex]::Replace(
                                        $content,
                                        "(?m)^\s*DisplayName\s*=\s*'[^']+'\s*$",
                                        (
                                            "    DisplayName = " +
                                            "'Example123456 Drift'"
                                        )
                                    )
                                    [IO.File]::WriteAllText(
                                        [string]$settings.intentPath,
                                        $content,
                                        [Text.UTF8Encoding]::new($false)
                                    )
                                }
                                'State' {
                                    $state = [IO.File]::ReadAllText(
                                        [string]$settings.statePath,
                                        [Text.UTF8Encoding]::new(
                                            $false,
                                            $true
                                        )
                                    ) | ConvertFrom-Json
                                    $state.resources[0].lastVerifiedAtUtc =
                                        '2026-10-03T08:31:01.0000000Z'
                                    [IO.File]::WriteAllText(
                                        [string]$settings.statePath,
                                        (
                                            ConvertTo-TenantLifecycleCanonicalJson `
                                                -InputObject $state
                                        ),
                                        [Text.UTF8Encoding]::new($false)
                                    )
                                }
                            }

                            if ([bool]$settings.tamperDynamicScope) {
                                Set-Variable `
                                    -Name stage `
                                    -Scope 1 `
                                    -Value 'TenantReplica'
                                Set-Variable `
                                    -Name sourceCommit `
                                    -Scope 1 `
                                    -Value ('f' * 40)
                                Set-Variable `
                                    -Name controlRecord `
                                    -Scope 1 `
                                    -Value ([pscustomobject]@{ providerPayload = 'forged' })
                            }
                            if ([bool]$settings.tamperAuthoritativeScope) {
                                foreach ($authoritativeName in @(
                                    'RunId',
                                    'EvidenceRoot',
                                    'RepositoryRoot',
                                    'ExpectedSourceCommit',
                                    'PublicTenantKey',
                                    'TenantConfigurationPath',
                                    'TenantStatePath',
                                    'Stages',
                                    'Mode',
                                    'SubsystemInvoker',
                                    'NowUtc',
                                    'canonicalStageOrder',
                                    'selectedStageSet',
                                    'lastSelectedStageIndex',
                                    'trustedRunId',
                                    'trustedRunIdText',
                                    'trustedExpectedSourceCommit',
                                    'trustedPublicTenantKey',
                                    'trustedTenantConfigurationPath',
                                    'trustedTenantStatePath',
                                    'trustedStages',
                                    'trustedMode',
                                    'modulePath',
                                    'repository',
                                    'trustedEvidenceRoot',
                                    'expectedRunDirectory',
                                    'runDirectory',
                                    'gitPath',
                                    'gitBoundaryRunner',
                                    'baselineSourceCommit',
                                    'baselinePrivateBinding',
                                    'baselineIntentDigest',
                                    'baselineStateDigest',
                                    'stageIndex',
                                    'stage',
                                    'prerequisiteResults',
                                    'verifiedCoordinates',
                                    'freshControlRecord'
                                )) {
                                    Set-Variable `
                                        -Name $authoritativeName `
                                        -Scope 1 `
                                        -Value 'forged'
                                }
                            }
                            if ([bool]$settings.returnProviderData) {
                                $providerMarker = [IO.Path]::Combine(
                                    $observationDirectory,
                                    'provider-call.txt'
                                )
                                $returnValue = [pscustomobject][ordered]@{
                                    status = 'Passed'
                                    providerId = 'provider-private-id'
                                    action = 'Apply'
                                    payload = @{ token = 'provider-private-token' }
                                }
                                $returnValue | Add-Member `
                                    -MemberType ScriptProperty `
                                    -Name rawReadBack `
                                    -Value {
                                        [IO.File]::WriteAllText(
                                            $providerMarker,
                                            'called',
                                            [Text.UTF8Encoding]::new($false)
                                        )
                                        throw 'The invoker return value was read.'
                                    }.GetNewClosure()
                                return $returnValue
                            }
'@
                        [scriptblock]::Create((
                            $invokerText.Replace(
                                '__SETTINGS_BASE64__',
                                $settingsBase64
                            )
                        ))
                    }

                    function Invoke-CoordinateOrchestrator {
                        param(
                            [Parameter(Mandatory)][guid]$RunId,
                            [Parameter(Mandatory)][string[]]$Stages,
                            [ValidateSet('Assess', 'Plan', 'Verify')]
                            [string]$Mode = 'Assess',
                            [scriptblock]$SubsystemInvoker,
                            [string]$RepositoryRoot = $script:CoordinateSyntheticRepository,
                            [string]$EvidenceRoot = $script:CoordinateEvidenceRoot,
                            [string]$ExpectedSourceCommit = $script:CoordinateSourceCommit,
                            [string]$TenantConfigurationPath = $script:CoordinateIntentPath,
                            [string]$TenantStatePath = $script:CoordinateStatePath
                        )

                        $parameters = @{
                            RunId = $RunId
                            EvidenceRoot = $EvidenceRoot
                            RepositoryRoot = $RepositoryRoot
                            ExpectedSourceCommit = $ExpectedSourceCommit
                            PublicTenantKey = 'tenant1'
                            TenantConfigurationPath = $TenantConfigurationPath
                            TenantStatePath = $TenantStatePath
                            Stages = $Stages
                            Mode = $Mode
                            NowUtc = [datetime]'2026-10-03T08:00:00Z'
                        }
                        if ($PSBoundParameters.ContainsKey('SubsystemInvoker')) {
                            $parameters.SubsystemInvoker = $SubsystemInvoker
                        }
                        & $script:CoordinateOrchestratorPath @parameters
                    }
                }

                BeforeEach {
                    Remove-Module Caldova.HrFrontier.Bootstrap -Force -ErrorAction SilentlyContinue
                    Import-Module $script:CoordinateModulePath -Force
                    Remove-Item `
                        -Path function:global:Test-TenantLifecycleContract `
                        -Force `
                        -ErrorAction SilentlyContinue
                    Import-Module $script:CoordinateModulePath -Force

                    $script:CoordinateSyntheticRepository = Join-Path (
                        $TestDrive
                    ) ([guid]::NewGuid().ToString('N'))
                    $tenantRoot = Join-Path $script:CoordinateSyntheticRepository (
                        'infra\src\config\tenants'
                    )
                    [IO.Directory]::CreateDirectory($tenantRoot) | Out-Null
                    $script:CoordinateIntentPath = Join-Path $tenantRoot (
                        'tenant1.local.psd1'
                    )
                    $script:CoordinateStatePath = Join-Path $tenantRoot (
                        'tenant1.state.local.json'
                    )
                    $intent = Get-Content -Raw -LiteralPath (
                        Join-Path $script:CoordinateRepositoryRoot (
                            'infra\src\config\tenants\_template.psd1'
                        )
                    )
                    $intent = $intent.Replace(
                        '    Components = @{}',
                        "    Components = @{$([Environment]::NewLine)" +
                        "        SyntheticResource = @{$([Environment]::NewLine)" +
                        "            Provider = 'Synthetic'$([Environment]::NewLine)" +
                        "            ResourceType = 'SyntheticResource'$([Environment]::NewLine)" +
                        "            LogicalName = 'component-001'$([Environment]::NewLine)" +
                        "            Mode = 'Existing'$([Environment]::NewLine)" +
                        "            Id = 'stable-synthetic-001'$([Environment]::NewLine)" +
                        "        }$([Environment]::NewLine)" +
                        "    }"
                    )
                    [IO.File]::WriteAllText(
                        $script:CoordinateIntentPath,
                        $intent,
                        [Text.UTF8Encoding]::new($false)
                    )
                    Write-CoordinateCanonicalFile `
                        -InputObject $script:CoordinateFixture.state `
                        -Path $script:CoordinateStatePath
                    [IO.File]::WriteAllText(
                        (Join-Path $script:CoordinateSyntheticRepository '.gitignore'),
                        (
                            "/infra/src/config/tenants/tenant1.local.psd1`n" +
                            "/infra/src/config/tenants/tenant1.state.local.json`n"
                        ),
                        [Text.UTF8Encoding]::new($false)
                    )
                    [IO.File]::WriteAllText(
                        (Join-Path $script:CoordinateSyntheticRepository 'tracked.txt'),
                        "synthetic`n",
                        [Text.UTF8Encoding]::new($false)
                    )
                    & git -C $script:CoordinateSyntheticRepository init --quiet
                    & git -C $script:CoordinateSyntheticRepository config user.email (
                        'synthetic@example.invalid'
                    )
                    & git -C $script:CoordinateSyntheticRepository config user.name (
                        'Synthetic Test'
                    )
                    & git -C $script:CoordinateSyntheticRepository config core.autocrlf false
                    & git -C $script:CoordinateSyntheticRepository add .gitignore tracked.txt
                    & git -C $script:CoordinateSyntheticRepository commit --quiet -m (
                        'synthetic source'
                    )
                    if ($LASTEXITCODE -ne 0) {
                        throw 'Could not initialize the coordinate-only test repository.'
                    }
                    $script:CoordinateSourceCommit = (
                        & git -C $script:CoordinateSyntheticRepository rev-parse HEAD
                    ).Trim().ToLowerInvariant()
                    $script:CoordinateEvidenceRoot = Join-Path (
                        $TestDrive
                    ) ('evidence-' + [guid]::NewGuid().ToString('N'))
                    $script:CoordinateProviderRunnerCalls =
                        [Collections.Generic.List[string]]::new()
                    $script:CoordinateBreakpoints =
                        [Collections.Generic.List[object]]::new()
                }

                AfterEach {
                    $script:CoordinateProviderRunnerCalls.Count | Should -Be 0
                    foreach ($breakpoint in $script:CoordinateBreakpoints) {
                        Remove-PSBreakpoint -Breakpoint $breakpoint
                    }
                    Remove-Item `
                        -Path function:global:Test-TenantLifecycleContract `
                        -Force `
                        -ErrorAction SilentlyContinue
                }

                Context 'coordinate-only Assess and Plan entry guards' {
                    It 'rejects case drift in mode <Mode> before invoker and filesystem access' -ForEach @(
                        @{ Mode = 'assess' }
                        @{ Mode = 'plan' }
                        @{ Mode = 'verify' }
                    ) {
                        {
                            Invoke-CoordinateOrchestrator `
                                -RunId ([guid]::NewGuid()) `
                                -Stages @('Workstation') `
                                -Mode $Mode `
                                -RepositoryRoot 'Z:\not-a-repository' `
                                -EvidenceRoot 'Z:\not-evidence' `
                                -TenantConfigurationPath 'Z:\not-intent.psd1' `
                                -TenantStatePath 'Z:\not-state.json'
                        } | Should -Throw -ExpectedMessage (
                            'TenantLifecycle.Mode.Invalid'
                        )
                    }

                    It 'rejects case drift in every stage before invoker and filesystem access' -ForEach @(
                        @{ Stage = 'workstation' }
                        @{ Stage = 'privateBoundary' }
                        @{ Stage = 'foundation' }
                        @{ Stage = 'devDelivery' }
                        @{ Stage = 'readBack' }
                        @{ Stage = 'acceptance' }
                        @{ Stage = 'tenantReplica' }
                    ) {
                        {
                            Invoke-CoordinateOrchestrator `
                                -RunId ([guid]::NewGuid()) `
                                -Stages @($Stage) `
                                -RepositoryRoot 'Z:\not-a-repository' `
                                -EvidenceRoot 'Z:\not-evidence' `
                                -TenantConfigurationPath 'Z:\not-intent.psd1' `
                                -TenantStatePath 'Z:\not-state.json'
                        } | Should -Throw -ExpectedMessage (
                            'TenantLifecycle.Stages.Invalid'
                        )
                    }

                    It 'requires an invoker in <Mode>' -ForEach @(
                        @{ Mode = 'Assess' }
                        @{ Mode = 'Plan' }
                    ) {
                        {
                            Invoke-CoordinateOrchestrator `
                                -RunId ([guid]::NewGuid()) `
                                -Stages @('Workstation') `
                                -Mode $Mode
                        } | Should -Throw -ExpectedMessage (
                            'TenantLifecycle.SubsystemInvoker.Required'
                        )
                    }

                    It 'rejects an invoker in Verify without invoking it' {
                        $calls = [Collections.Generic.List[string]]::new()
                        $invoker = {
                            [void]$calls.Add('invoked')
                        }.GetNewClosure()

                        {
                            Invoke-CoordinateOrchestrator `
                                -RunId ([guid]::NewGuid()) `
                                -Stages @('Workstation') `
                                -Mode Verify `
                                -SubsystemInvoker $invoker
                        } | Should -Throw -ExpectedMessage (
                            'TenantLifecycle.SubsystemInvoker.NotAllowed'
                        )
                        $calls.Count | Should -Be 0
                    }

                    It 'fails Verify closed when its canonical result set is absent' {
                        {
                            Invoke-CoordinateOrchestrator `
                                -RunId ([guid]::NewGuid()) `
                                -Stages @('Workstation') `
                                -Mode Verify
                        } | Should -Throw -ExpectedMessage (
                            'TenantLifecycle.StageResultSet.Invalid'
                        )
                    }

                    It 'uses the first deterministic Git application when PATH exposes aliases' {
                        $gitSource = (
                            Get-Command git.exe `
                                -CommandType Application `
                                -ErrorAction Stop |
                                Select-Object -First 1
                        ).Source
                        $gitRoot = Split-Path -Parent (
                            Split-Path -Parent $gitSource
                        )
                        $junctionRoot = Join-Path (
                            $TestDrive
                        ) ([guid]::NewGuid().ToString('N'))
                        [IO.Directory]::CreateDirectory(
                            $junctionRoot
                        ) | Out-Null
                        $gitOne = Join-Path $junctionRoot 'git-one'
                        $gitTwo = Join-Path $junctionRoot 'git-two'
                        New-Item `
                            -ItemType Junction `
                            -Path $gitOne `
                            -Target $gitRoot |
                            Out-Null
                        New-Item `
                            -ItemType Junction `
                            -Path $gitTwo `
                            -Target $gitRoot |
                            Out-Null
                        $originalPath = $env:PATH

                        try {
                            $env:PATH = (
                                (Join-Path $gitOne 'cmd'),
                                (Join-Path $gitTwo 'cmd'),
                                $originalPath
                            ) -join ';'
                            @(
                                Get-Command git.exe `
                                    -CommandType Application `
                                    -ErrorAction Stop
                            ).Count | Should -BeGreaterThan 1

                            $runId = [guid]::NewGuid()
                            $invoker = New-CoordinateArtifactInvoker
                            {
                                Invoke-CoordinateOrchestrator `
                                    -RunId $runId `
                                    -Stages @('Workstation') `
                                    -Mode Assess `
                                    -SubsystemInvoker $invoker
                            } | Should -Not -Throw
                            (
                                Get-CoordinateObservedCalls -RunId $runId
                            ) | Should -BeExactly @('Workstation|Assess')
                        }
                        finally {
                            $env:PATH = $originalPath
                            [IO.Directory]::Delete($gitOne, $false)
                            [IO.Directory]::Delete($gitTwo, $false)
                        }
                    }

                    It 'classifies child invocation failures without disclosing their message' {
                        $errorRecord = try {
                            Invoke-CoordinateOrchestrator `
                                -RunId ([guid]::NewGuid()) `
                                -Stages @('Workstation') `
                                -Mode Assess `
                                -SubsystemInvoker {
                                    throw [IO.DirectoryNotFoundException]::new(
                                        'private-provider-path-marker'
                                    )
                                }
                            $null
                        }
                        catch {
                            $_
                        }

                        $errorRecord.Exception.Message |
                            Should -BeExactly (
                                'TenantLifecycle.SubsystemInvoker.Failed'
                            )
                        $messages =
                            [Collections.Generic.List[string]]::new()
                        $exception = $errorRecord.Exception
                        while ($null -ne $exception) {
                            [void]$messages.Add($exception.Message)
                            $exception = $exception.InnerException
                        }
                        ($messages -join '|') | Should -Match (
                            'TenantLifecycle[.]SubsystemInvoker[.]' +
                            'Child[.]Invocation[.]Path'
                        )
                        ($messages -join '|') | Should -Not -Match (
                            'private-provider-path-marker'
                        )
                    }

                    It 'rejects an empty selected stage set before dispatch' {
                        {
                            Invoke-CoordinateOrchestrator `
                                -RunId ([guid]::NewGuid()) `
                                -Stages @() `
                                -SubsystemInvoker {}
                        } | Should -Throw
                    }

                    It 'rejects a <Case> selected stage set before filesystem access' -ForEach @(
                        @{
                            Case = 'duplicate'
                            Stages = @('Workstation', 'Workstation')
                        }
                        @{
                            Case = 'case drift'
                            Stages = @('workstation')
                        }
                        @{
                            Case = 'unknown'
                            Stages = @('Unknown')
                        }
                        @{
                            Case = 'graph-incompatible order'
                            Stages = @('Foundation', 'Workstation')
                        }
                    ) {
                        $calls = [Collections.Generic.List[string]]::new()
                        $invoker = {
                            [void]$calls.Add('invoked')
                        }.GetNewClosure()

                        {
                            Invoke-CoordinateOrchestrator `
                                -RunId ([guid]::NewGuid()) `
                                -Stages $Stages `
                                -RepositoryRoot 'Z:\not-a-repository' `
                                -EvidenceRoot 'Z:\not-evidence' `
                                -TenantConfigurationPath 'Z:\not-intent.psd1' `
                                -TenantStatePath 'Z:\not-state.json' `
                                -SubsystemInvoker $invoker
                        } | Should -Throw
                        $calls.Count | Should -Be 0
                    }
                }

                Context 'closed control record contract' {
                    It 'passes exact named arguments and a fresh nine-field control record' {
                        $runId = [guid]::NewGuid()
                        Write-CoordinateStageResult `
                            -RunId $runId `
                            -Stage Workstation `
                            -SelectedStages @(
                                'Workstation',
                                'Foundation'
                            )
                        $invoker = New-CoordinateArtifactInvoker

                        $output = @(
                            Invoke-CoordinateOrchestrator `
                                -RunId $runId `
                                -Stages @('Workstation', 'Foundation') `
                                -Mode Assess `
                                -SubsystemInvoker $invoker
                        )

                        $output.Count | Should -Be 0
                        $calls = Get-CoordinateObservedCalls -RunId $runId
                        $records = Get-CoordinateObservedRecords `
                            -RunId $runId `
                            -Stages @('Workstation', 'Foundation')
                        ($calls -join ',') |
                            Should -BeExactly 'Workstation|Assess,Foundation|Assess'
                        $records.Count | Should -Be 2
                        foreach ($record in $records) {
                            ($record.PSObject.Properties.Name -join ',') |
                                Should -BeExactly (
                                    'schemaVersion,runId,sourceCommit,publicTenantKey,' +
                                    'intentDigest,stateDigest,selectedStages,' +
                                    'prerequisiteResults,evidenceRunRelativePath'
                                )
                            $record.schemaVersion | Should -BeExactly '1.0'
                            $record.runId | Should -BeExactly (
                                $runId.ToString('D').ToLowerInvariant()
                            )
                            $record.sourceCommit |
                                Should -BeExactly $script:CoordinateSourceCommit
                            $record.publicTenantKey | Should -BeExactly 'tenant1'
                            ($record.selectedStages -join ',') |
                                Should -BeExactly 'Workstation,Foundation'
                            $record.evidenceRunRelativePath |
                                Should -BeExactly $runId.ToString('D').ToLowerInvariant()
                        }
                        @($records[0].prerequisiteResults).Count | Should -Be 0
                        @($records[1].prerequisiteResults).Count | Should -Be 1
                        ($records[1].prerequisiteResults[0].PSObject.Properties.Name -join ',') |
                            Should -BeExactly (
                                'stage,status,classification,phaseManifestDigest,' +
                                'phaseSummaryDigest,intentDigest,stateDigest'
                            )
                        $records[1].prerequisiteResults[0].stage |
                            Should -BeExactly 'Workstation'
                    }

                    It 'transports the control envelope independently of console input encoding' {
                        $runId = [guid]::NewGuid()
                        $invoker = New-CoordinateArtifactInvoker
                        $originalInputEncoding = [Console]::InputEncoding
                        try {
                            [Console]::InputEncoding =
                                [Text.UTF8Encoding]::new($true)
                            $errorRecord = try {
                                Invoke-CoordinateOrchestrator `
                                    -RunId $runId `
                                    -Stages @('Workstation') `
                                    -Mode Assess `
                                    -SubsystemInvoker $invoker
                                $null
                            }
                            catch {
                                $_
                            }
                        }
                        finally {
                            [Console]::InputEncoding =
                                $originalInputEncoding
                        }
                        $because = if ($null -eq $errorRecord) {
                            'the raw Base64 transport is encoding-independent'
                        }
                        else {
                            $errorRecord.Exception.ToString()
                        }
                        $errorRecord |
                            Should -BeNullOrEmpty -Because $because
                        (
                            Get-CoordinateObservedCalls -RunId $runId
                        ) | Should -BeExactly @('Workstation|Assess')
                    }

                    It 'excludes every private path value and provider authority' {
                        $runId = [guid]::NewGuid()
                        $invoker = New-CoordinateArtifactInvoker

                        Invoke-CoordinateOrchestrator `
                            -RunId $runId `
                            -Stages @('Workstation') `
                            -Mode Assess `
                            -SubsystemInvoker $invoker

                        $records = Get-CoordinateObservedRecords `
                            -RunId $runId `
                            -Stages @('Workstation')
                        $json = $records[0] | ConvertTo-Json -Depth 20 -Compress
                        $json | Should -Not -Match (
                            [regex]::Escape($script:CoordinateIntentPath) + '|' +
                            [regex]::Escape($script:CoordinateStatePath)
                        )
                        $json | Should -Not -Match (
                            '(?i)(Example123456|stable-synthetic|password|credential|' +
                            'token|approval|providerContext|https?://|\bactions?\b|payload|' +
                            'read.?back|private-id)'
                        )
                    }

                    It 'isolates every authoritative coordinator variable from invoker scope tampering' {
                        $runId = [guid]::NewGuid()
                        $invoker = New-CoordinateArtifactInvoker `
                            -TamperAuthoritativeScope

                        {
                            Invoke-CoordinateOrchestrator `
                                -RunId $runId `
                                -Stages @('Workstation') `
                                -Mode Assess `
                                -SubsystemInvoker $invoker
                        } | Should -Not -Throw
                        (
                            Get-CoordinateObservedCalls -RunId $runId
                        ) | Should -BeExactly @('Workstation|Assess')
                    }

                    It 'terminates an invoker descendant without waiting for its inherited stream handles' {
                        $runId = [guid]::NewGuid()
                        $invoker = New-CoordinateArtifactInvoker `
                            -SpawnInheritedHandleDescendant
                        $observationDirectory = Join-Path (
                            Join-Path $script:CoordinateEvidenceRoot (
                                $runId.ToString('D')
                            )
                        ) '.test-observation'
                        $markerPath = Join-Path $observationDirectory (
                            'descendant-completed.txt'
                        )
                        $pidPath = Join-Path $observationDirectory (
                            'descendant-pid.txt'
                        )
                        $descendantProcess = $null

                        try {
                            Invoke-CoordinateOrchestrator `
                                -RunId $runId `
                                -Stages @('Workstation') `
                                -Mode Assess `
                                -SubsystemInvoker $invoker

                            $pidPath | Should -Exist
                            $markerPath | Should -Not -Exist
                            $descendantId = [int](
                                Get-Content -Raw -LiteralPath $pidPath
                            )
                            $deadline = [datetime]::UtcNow.AddSeconds(2)
                            do {
                                $descendantProcess = Get-Process `
                                    -Id $descendantId `
                                    -ErrorAction SilentlyContinue
                                if ($null -eq $descendantProcess) {
                                    break
                                }
                                Start-Sleep -Milliseconds 50
                            } while ([datetime]::UtcNow -lt $deadline)
                            $descendantProcess | Should -BeNullOrEmpty
                        }
                        finally {
                            if (
                                $null -ne $descendantProcess -and
                                -not $descendantProcess.HasExited
                            ) {
                                Stop-Process `
                                    -Id $descendantProcess.Id `
                                    -Force
                            }
                        }
                    }

                    It 'discards direct invoker stdout and stderr outside PowerShell streams' {
                            $runId = [guid]::NewGuid()
                            $invoker = New-CoordinateArtifactInvoker `
                                -WriteDirectOutput
                            $wrapperPayload = [pscustomobject][ordered]@{
                                orchestratorPath =
                                    $script:CoordinateOrchestratorPath
                                runId = $runId.ToString('D')
                                evidenceRoot = $script:CoordinateEvidenceRoot
                                repositoryRoot =
                                    $script:CoordinateSyntheticRepository
                                sourceCommit = $script:CoordinateSourceCommit
                                intentPath = $script:CoordinateIntentPath
                                statePath = $script:CoordinateStatePath
                                invoker = [Convert]::ToBase64String(
                                    [Text.Encoding]::UTF8.GetBytes(
                                        $invoker.ToString()
                                    )
                                )
                            }
                            $wrapperPayloadJson = $wrapperPayload |
                                ConvertTo-Json -Depth 30 -Compress
                            $wrapperPayloadTransport =
                                [Convert]::ToBase64String(
                                    [Text.Encoding]::UTF8.GetBytes(
                                        $wrapperPayloadJson
                                    )
                                )
                            $wrapperPayloadBytes =
                                [Text.Encoding]::ASCII.GetBytes(
                                    $wrapperPayloadTransport
                                )
                            $wrapperScript = @'
$ErrorActionPreference = 'Stop'
$inputBuffer = [IO.MemoryStream]::new()
try {
    [Console]::OpenStandardInput().CopyTo($inputBuffer)
    [byte[]]$inputBytes = $inputBuffer.ToArray()
}
finally {
    $inputBuffer.Dispose()
}
$inputOffset = if (
    $inputBytes.Length -ge 3 -and
    $inputBytes[0] -eq 0xEF -and
    $inputBytes[1] -eq 0xBB -and
    $inputBytes[2] -eq 0xBF
) {
    3
}
elseif (
    $inputBytes.Length -ge 2 -and
    (
        (
            $inputBytes[0] -eq 0xFF -and
            $inputBytes[1] -eq 0xFE
        ) -or
        (
            $inputBytes[0] -eq 0xFE -and
            $inputBytes[1] -eq 0xFF
        )
    )
) {
    2
}
else {
    0
}
$payloadTransport = [Text.Encoding]::ASCII.GetString(
    $inputBytes,
    $inputOffset,
    $inputBytes.Length - $inputOffset
)
$payloadJson = [Text.Encoding]::UTF8.GetString(
    [Convert]::FromBase64String($payloadTransport)
)
$payload = $payloadJson | ConvertFrom-Json
$invokerText = [Text.Encoding]::UTF8.GetString(
    [Convert]::FromBase64String([string]$payload.invoker)
)
$invoker = [scriptblock]::Create($invokerText)
& ([string]$payload.orchestratorPath) `
    -RunId ([guid]$payload.runId) `
    -EvidenceRoot ([string]$payload.evidenceRoot) `
    -RepositoryRoot ([string]$payload.repositoryRoot) `
    -ExpectedSourceCommit ([string]$payload.sourceCommit) `
    -PublicTenantKey tenant1 `
    -TenantConfigurationPath ([string]$payload.intentPath) `
    -TenantStatePath ([string]$payload.statePath) `
    -Stages @('Workstation') `
    -Mode Assess `
    -SubsystemInvoker $invoker `
    -NowUtc ([datetime]'2026-10-03T08:00:00Z')
'@
                            $wrapperStartInfo =
                                [Diagnostics.ProcessStartInfo]::new()
                            $wrapperHostName = if (
                                $PSVersionTable.PSEdition -ceq 'Core'
                            ) {
                                'pwsh.exe'
                            }
                            else {
                                'powershell.exe'
                            }
                            $wrapperStartInfo.FileName = Join-Path (
                                $PSHOME
                            ) $wrapperHostName
                            $wrapperStartInfo.Arguments = (
                                '-NoLogo -NoProfile -NonInteractive ' +
                                '-EncodedCommand ' +
                                [Convert]::ToBase64String(
                                    [Text.Encoding]::Unicode.GetBytes(
                                        $wrapperScript
                                    )
                                )
                            )
                            $wrapperStartInfo.UseShellExecute = $false
                            $wrapperStartInfo.CreateNoWindow = $true
                            $wrapperStartInfo.RedirectStandardInput = $true
                            $wrapperStartInfo.RedirectStandardOutput = $true
                            $wrapperStartInfo.RedirectStandardError = $true
                            $wrapper = [Diagnostics.Process]::new()
                            $wrapper.StartInfo = $wrapperStartInfo
                            $wrapperStarted = $false

                            try {
                                $wrapperStarted = $wrapper.Start()
                                $wrapperStarted | Should -BeTrue
                                $wrapper.StandardInput.BaseStream.Write(
                                    $wrapperPayloadBytes,
                                    0,
                                    $wrapperPayloadBytes.Length
                                )
                                $wrapper.StandardInput.BaseStream.Close()
                                $stdoutTask =
                                    $wrapper.StandardOutput.ReadToEndAsync()
                                $stderrTask =
                                    $wrapper.StandardError.ReadToEndAsync()
                                $wrapper.WaitForExit(60000) | Should -BeTrue
                                $stdout = $stdoutTask.GetAwaiter().GetResult()
                                $stderr = $stderrTask.GetAwaiter().GetResult()

                                $wrapper.ExitCode | Should -Be 0
                                $stdout | Should -Not -Match (
                                    'UNEXPECTED_INVOKER_STDOUT|' +
                                    'UNEXPECTED_INVOKER_STDERR'
                                )
                                $stderr | Should -Not -Match (
                                    'UNEXPECTED_INVOKER_STDOUT|' +
                                    'UNEXPECTED_INVOKER_STDERR'
                                )
                            }
                            finally {
                                if (
                                    $wrapperStarted -and
                                    -not $wrapper.HasExited
                                ) {
                                    Stop-Process -Id $wrapper.Id -Force
                                }
                                $wrapper.Dispose()
                            }
                        }
                }

                Context 'coordinate-only Assess artifact authority' {
                    It 'invokes only Assess and validates only its canonical assessment path' {
                        $runId = [guid]::NewGuid()
                        $invoker = New-CoordinateArtifactInvoker

                        {
                            Invoke-CoordinateOrchestrator `
                                -RunId $runId `
                                -Stages @('Foundation') `
                                -Mode Assess `
                                -SubsystemInvoker $invoker
                        } | Should -Not -Throw
                        $calls = Get-CoordinateObservedCalls -RunId $runId
                        ($calls -join ',') | Should -BeExactly 'Foundation|Assess'
                    }

                    It 'rejects a Plan artifact substituted for the assessment' {
                        $invoker = New-CoordinateArtifactInvoker `
                            -ArtifactMode Plan

                        {
                            Invoke-CoordinateOrchestrator `
                                -RunId ([guid]::NewGuid()) `
                                -Stages @('Foundation') `
                                -Mode Assess `
                                -SubsystemInvoker $invoker
                        } | Should -Throw -ExpectedMessage (
                            'TenantLifecycle.ChildArtifact.Invalid'
                        )
                    }

                    It 'rejects a canonical assessment bound to another stage' {
                        $invoker = New-CoordinateArtifactInvoker `
                            -ArtifactStage Workstation

                        {
                            Invoke-CoordinateOrchestrator `
                                -RunId ([guid]::NewGuid()) `
                                -Stages @('Foundation') `
                                -Mode Assess `
                                -SubsystemInvoker $invoker
                        } | Should -Throw -ExpectedMessage (
                            'TenantLifecycle.ChildArtifact.Invalid'
                        )
                    }

                    It 'discards provider IDs actions payloads and executable return members' {
                        $runId = [guid]::NewGuid()
                        $invoker = New-CoordinateArtifactInvoker `
                            -ReturnProviderData

                        $output = @(
                            Invoke-CoordinateOrchestrator `
                                -RunId $runId `
                                -Stages @('Foundation') `
                                -Mode Assess `
                                -SubsystemInvoker $invoker
                        )
                        $output.Count | Should -Be 0
                        $script:CoordinateProviderRunnerCalls.Count | Should -Be 0
                        Test-CoordinateProviderMarker -RunId $runId |
                            Should -BeFalse
                    }

                    It 'rejects a returned Passed claim without a canonical child phase' {
                        $invoker = {
                            [pscustomobject][ordered]@{
                                status = 'Passed'
                                providerId = 'forged-provider-id'
                                action = 'Apply'
                                payload = @{ token = 'forged-token' }
                            }
                        }

                        {
                            Invoke-CoordinateOrchestrator `
                                -RunId ([guid]::NewGuid()) `
                                -Stages @('Foundation') `
                                -Mode Assess `
                                -SubsystemInvoker $invoker
                        } | Should -Throw -ExpectedMessage (
                            'TenantLifecycle.ChildArtifact.Invalid'
                        )
                    }
                }

                Context 'coordinate-only Plan artifact authority' {
                    It 'invokes only Plan and validates only its canonical execution manifest path' {
                        $runId = [guid]::NewGuid()
                        $invoker = New-CoordinateArtifactInvoker

                        {
                            Invoke-CoordinateOrchestrator `
                                -RunId $runId `
                                -Stages @('Foundation') `
                                -Mode Plan `
                                -SubsystemInvoker $invoker
                        } | Should -Not -Throw
                        $calls = Get-CoordinateObservedCalls -RunId $runId
                        ($calls -join ',') | Should -BeExactly 'Foundation|Plan'
                    }

                    It 'rejects an Assess artifact substituted for the execution manifest' {
                        $invoker = New-CoordinateArtifactInvoker `
                            -ArtifactMode Assess

                        {
                            Invoke-CoordinateOrchestrator `
                                -RunId ([guid]::NewGuid()) `
                                -Stages @('Foundation') `
                                -Mode Plan `
                                -SubsystemInvoker $invoker
                        } | Should -Throw -ExpectedMessage (
                            'TenantLifecycle.ChildArtifact.Invalid'
                        )
                    }

                    It 'rejects a canonical execution manifest bound to another stage action' {
                        $invoker = New-CoordinateArtifactInvoker `
                            -ArtifactStage Workstation

                        {
                            Invoke-CoordinateOrchestrator `
                                -RunId ([guid]::NewGuid()) `
                                -Stages @('Foundation') `
                                -Mode Plan `
                                -SubsystemInvoker $invoker
                        } | Should -Throw -ExpectedMessage (
                            'TenantLifecycle.ChildArtifact.Invalid'
                        )
                    }

                    It 'rejects Plan selectedStages substituted from its fresh control record' {
                        $invoker = New-CoordinateArtifactInvoker `
                            -PlanBindingMutation SelectedStages

                        {
                            Invoke-CoordinateOrchestrator `
                                -RunId ([guid]::NewGuid()) `
                                -Stages @('Foundation') `
                                -Mode Plan `
                                -SubsystemInvoker $invoker
                        } | Should -Throw -ExpectedMessage (
                            'TenantLifecycle.ChildArtifact.Invalid'
                        )
                    }

                    It 'rejects Plan prerequisiteResults substituted from its fresh control record' {
                        $runId = [guid]::NewGuid()
                        $selectedStages = @('Workstation', 'Foundation')
                        Write-CoordinateStageResult `
                            -RunId $runId `
                            -Stage Workstation `
                            -SelectedStages $selectedStages
                        $invoker = New-CoordinateArtifactInvoker `
                            -PlanBindingMutation PrerequisiteResults

                        {
                            Invoke-CoordinateOrchestrator `
                                -RunId $runId `
                                -Stages $selectedStages `
                                -Mode Plan `
                                -SubsystemInvoker $invoker
                        } | Should -Throw -ExpectedMessage (
                            'TenantLifecycle.ChildArtifact.Invalid'
                        )
                    }
                }

                Context 'source and private drift gates' {
                    It 'fails closed on <Target> drift <Timing>' -ForEach @(
                        @{
                            Target = 'Source'
                            Timing = 'before a later invocation'
                            Expected = 'TenantLifecycle.Source.Drift'
                        }
                        @{
                            Target = 'Intent'
                            Timing = 'before a later invocation'
                            Expected = 'TenantLifecycle.Intent.Drift'
                        }
                        @{
                            Target = 'State'
                            Timing = 'before a later invocation'
                            Expected = 'TenantLifecycle.State.Drift'
                        }
                        @{
                            Target = 'Source'
                            Timing = 'during invocation'
                            Expected = 'TenantLifecycle.Source.Drift'
                        }
                        @{
                            Target = 'Intent'
                            Timing = 'during invocation'
                            Expected = 'TenantLifecycle.Intent.Drift'
                        }
                        @{
                            Target = 'State'
                            Timing = 'during invocation'
                            Expected = 'TenantLifecycle.State.Drift'
                        }
                        @{
                            Target = 'Source'
                            Timing = 'after artifact validation'
                            Expected = 'TenantLifecycle.Source.Drift'
                        }
                        @{
                            Target = 'Intent'
                            Timing = 'after artifact validation'
                            Expected = 'TenantLifecycle.Intent.Drift'
                        }
                        @{
                            Target = 'State'
                            Timing = 'after artifact validation'
                            Expected = 'TenantLifecycle.State.Drift'
                        }
                    ) {
                        $runId = [guid]::NewGuid()
                        $parameters = @{}
                        $stages = @('Foundation')
                        if ($Timing -ceq 'before a later invocation') {
                            $stages = @('Workstation', 'Foundation')
                            Write-CoordinateStageResult `
                                -RunId $runId `
                                -Stage Workstation `
                                -SelectedStages $stages
                            Install-CoordinateValidationDriftHook `
                                -ContractKind StageResult `
                                -DriftTarget $Target `
                                -RepositoryRoot $script:CoordinateSyntheticRepository `
                                -IntentPath $script:CoordinateIntentPath `
                                -StatePath $script:CoordinateStatePath
                        }
                        elseif ($Timing -ceq 'during invocation') {
                            $parameters.DuringDrift = $Target
                        }
                        else {
                            Install-CoordinateValidationDriftHook `
                                -ContractKind Assessment `
                                -DriftTarget $Target `
                                -RepositoryRoot $script:CoordinateSyntheticRepository `
                                -IntentPath $script:CoordinateIntentPath `
                                -StatePath $script:CoordinateStatePath
                        }
                        $invoker = New-CoordinateArtifactInvoker @parameters

                        {
                            Invoke-CoordinateOrchestrator `
                                -RunId $runId `
                                -Stages $stages `
                                -Mode Assess `
                                -SubsystemInvoker $invoker
                        } | Should -Throw -ExpectedMessage $Expected
                        $calls = Get-CoordinateObservedCalls -RunId $runId
                        if ($Timing -ceq 'before a later invocation') {
                            ($calls -join ',') | Should -BeExactly 'Workstation|Assess'
                        }
                        else {
                            ($calls -join ',') | Should -BeExactly 'Foundation|Assess'
                        }
                    }

                    It 'blocks a prerequisite summary envelope mismatch before later <Mode> dispatch' -ForEach @(
                        @{ Mode = 'Assess' }
                        @{ Mode = 'Plan' }
                    ) {
                        $runId = [guid]::NewGuid()
                        $selectedStages = @(
                            'Workstation',
                            'Foundation'
                        )
                        Write-CoordinateStageResult `
                            -RunId $runId `
                            -Stage Workstation `
                            -SelectedStages $selectedStages
                        Set-CoordinateSummaryEnvelopeMismatch `
                            -RunId $runId `
                            -Stage Workstation
                        $invoker = New-CoordinateArtifactInvoker
                        $projectionPath = Join-Path (
                            Join-Path $script:CoordinateEvidenceRoot (
                                $runId.ToString('D').ToLowerInvariant()
                            )
                        ) 'summary.json'

                        {
                            Invoke-CoordinateOrchestrator `
                                -RunId $runId `
                                -Stages $selectedStages `
                                -Mode $Mode `
                                -SubsystemInvoker $invoker
                        } | Should -Throw -ExpectedMessage (
                            'TenantLifecycle.ChildArtifact.Invalid'
                        )
                        (
                            Get-CoordinateObservedCalls -RunId $runId
                        ) -join ',' | Should -BeExactly (
                            "Workstation|$Mode"
                        )
                        $projectionPath | Should -Not -Exist
                        $script:CoordinateProviderRunnerCalls.Count |
                            Should -Be 0
                    }

                    It 'blocks mixed-case prohibited <Family> summary data before later <Mode> dispatch without disclosure or projection' -ForEach $coordinateMixedCasePrerequisiteCases {
                        $runId = [guid]::NewGuid()
                        $selectedStages = @(
                            'Workstation',
                            'Foundation'
                        )
                        Write-CoordinateStageResult `
                            -RunId $runId `
                            -Stage Workstation `
                            -SelectedStages $selectedStages
                        $marker =
                            "private-$Family-prerequisite-marker-do-not-disclose"
                        Set-CoordinateMixedCaseProhibitedSummary `
                            -RunId $runId `
                            -Stage Workstation `
                            -PropertyName $PropertyName `
                            -Marker $marker
                        $invoker = New-CoordinateArtifactInvoker
                        $projectionPath = Join-Path (
                            Join-Path $script:CoordinateEvidenceRoot (
                                $runId.ToString('D').ToLowerInvariant()
                            )
                        ) 'summary.json'
                        $caught = $null

                        try {
                            Invoke-CoordinateOrchestrator `
                                -RunId $runId `
                                -Stages $selectedStages `
                                -Mode $Mode `
                                -SubsystemInvoker $invoker
                        }
                        catch {
                            $caught = $_
                        }

                        $caught | Should -Not -BeNullOrEmpty
                        $caught.Exception.Message |
                            Should -BeExactly (
                                'TenantLifecycle.ChildArtifact.Invalid'
                            )
                        $caught.Exception.InnerException |
                            Should -BeNullOrEmpty
                        $caught.Exception.Message |
                            Should -Not -Match (
                                [regex]::Escape($PropertyName) + '|' +
                                [regex]::Escape($marker)
                            )
                        (
                            Get-CoordinateObservedCalls -RunId $runId
                        ) -join ',' | Should -BeExactly (
                            "Workstation|$Mode"
                        )
                        $projectionPath | Should -Not -Exist
                        $script:CoordinateProviderRunnerCalls.Count |
                            Should -Be 0
                    }

                    It 'rejects a <Mutation> prerequisite artifact before later dispatch' -ForEach @(
                        @{ Mutation = 'missing result'; Target = 'Result'; Change = 'Missing' }
                        @{ Mutation = 'substituted result'; Target = 'Result'; Change = 'Substituted' }
                        @{ Mutation = 'tampered result'; Target = 'Result'; Change = 'Tampered' }
                        @{ Mutation = 'case-drifted result path'; Target = 'Result'; Change = 'Path' }
                        @{ Mutation = 'missing manifest'; Target = 'Manifest'; Change = 'Missing' }
                        @{ Mutation = 'substituted manifest'; Target = 'Manifest'; Change = 'Substituted' }
                        @{ Mutation = 'tampered manifest'; Target = 'Manifest'; Change = 'Tampered' }
                        @{ Mutation = 'missing summary'; Target = 'Summary'; Change = 'Missing' }
                        @{ Mutation = 'substituted summary'; Target = 'Summary'; Change = 'Substituted' }
                        @{ Mutation = 'tampered summary'; Target = 'Summary'; Change = 'Tampered' }
                    ) {
                        $runId = [guid]::NewGuid()
                        $selectedStages = @('Workstation', 'Foundation')
                        Write-CoordinateStageResult `
                            -RunId $runId `
                            -Stage Workstation `
                            -SelectedStages $selectedStages
                        $runDirectory = Join-Path (
                            $script:CoordinateEvidenceRoot
                        ) $runId.ToString('D').ToLowerInvariant()
                        $resultPath = Join-Path $runDirectory (
                            'stage-results\Workstation.json'
                        )
                        $manifestPath = Join-Path $runDirectory (
                            'phases\Workstation\execution-manifest.json'
                        )
                        $summaryPath = Join-Path $runDirectory (
                            'phases\Workstation\summary.json'
                        )
                        $targetPath = switch ($Target) {
                            'Result' { $resultPath }
                            'Manifest' { $manifestPath }
                            'Summary' { $summaryPath }
                        }
                        switch ($Change) {
                            'Missing' {
                                Remove-Item -LiteralPath $targetPath -Force
                            }
                            'Tampered' {
                                [IO.File]::AppendAllText(
                                    $targetPath,
                                    ' ',
                                    [Text.UTF8Encoding]::new($false)
                                )
                            }
                            'Path' {
                                $temporaryPath = Join-Path (
                                    Split-Path -Parent $targetPath
                                ) '.case-prerequisite-result'
                                Move-Item `
                                    -LiteralPath $targetPath `
                                    -Destination $temporaryPath
                                Move-Item `
                                    -LiteralPath $temporaryPath `
                                    -Destination (
                                        Join-Path (
                                            Split-Path -Parent $targetPath
                                        ) 'workstation.json'
                                    )
                            }
                            'Substituted' {
                                $value = Get-Content `
                                    -Raw `
                                    -LiteralPath $targetPath |
                                    ConvertFrom-Json
                                if ($Target -ceq 'Result') {
                                    $value.runId = (
                                        [guid]::NewGuid()
                                    ).ToString('D').ToLowerInvariant()
                                }
                                elseif ($Target -ceq 'Manifest') {
                                    $value.runId = (
                                        [guid]::NewGuid()
                                    ).ToString('D').ToLowerInvariant()
                                    $unsigned = [ordered]@{}
                                    foreach (
                                        $property in
                                            $value.PSObject.Properties
                                    ) {
                                        if ($property.Name -cne 'digest') {
                                            $unsigned[$property.Name] =
                                                $property.Value
                                        }
                                    }
                                    $value.digest =
                                        Get-RunbookContentDigest `
                                            -InputObject (
                                                [pscustomobject]$unsigned
                                            )
                                }
                                else {
                                    $value.runId = (
                                        [guid]::NewGuid()
                                    ).ToString('D').ToLowerInvariant()
                                }
                                Write-CoordinateCanonicalFile `
                                    -InputObject $value `
                                    -Path $targetPath
                                if ($Target -ceq 'Manifest') {
                                    $result = Get-Content `
                                        -Raw `
                                        -LiteralPath $resultPath |
                                        ConvertFrom-Json
                                    $result.phaseManifestDigest =
                                        Get-CoordinateExactFileDigest `
                                            -Path $manifestPath
                                    Write-CoordinateCanonicalFile `
                                        -InputObject $result `
                                        -Path $resultPath
                                }
                            }
                        }
                        $invoker = New-CoordinateArtifactInvoker

                        {
                            Invoke-CoordinateOrchestrator `
                                -RunId $runId `
                                -Stages $selectedStages `
                                -Mode Assess `
                                -SubsystemInvoker $invoker
                        } | Should -Throw -ExpectedMessage (
                            'TenantLifecycle.ChildArtifact.Invalid'
                        )
                        (
                            Get-CoordinateObservedCalls -RunId $runId
                        ) -join ',' | Should -BeExactly 'Workstation|Assess'
                    }

                    It 'stops before later dispatch on the first invalid prerequisite' {
                        $runId = [guid]::NewGuid()
                        $selectedStages = @(
                            'Workstation',
                            'Foundation',
                            'DevDelivery'
                        )
                        Write-CoordinateStageResult `
                            -RunId $runId `
                            -Stage Workstation `
                            -SelectedStages $selectedStages `
                            -Status Failed
                        $invoker = New-CoordinateArtifactInvoker

                        {
                            Invoke-CoordinateOrchestrator `
                                -RunId $runId `
                                -Stages $selectedStages `
                                -Mode Assess `
                                -SubsystemInvoker $invoker
                        } | Should -Throw
                        $calls = Get-CoordinateObservedCalls -RunId $runId
                        ($calls -join ',') | Should -BeExactly 'Workstation|Assess'
                    }

                    It 'opaque provider extras stay out of <Mode> prerequisite control records and permit later dispatch' -ForEach @(
                        @{ Mode = 'Assess' }
                        @{ Mode = 'Plan' }
                    ) {
                        $runId = [guid]::NewGuid()
                        $selectedStages = @(
                            'Workstation',
                            'Foundation'
                        )
                        Write-CoordinateStageResult `
                            -RunId $runId `
                            -Stage Workstation `
                            -SelectedStages $selectedStages
                        Add-CoordinateOpaqueProviderExtras `
                            -RunId $runId `
                            -Stage Workstation
                        $invoker = New-CoordinateArtifactInvoker
                        $projectionPath = Join-Path (
                            Join-Path $script:CoordinateEvidenceRoot (
                                $runId.ToString('D').ToLowerInvariant()
                            )
                        ) 'summary.json'

                        {
                            Invoke-CoordinateOrchestrator `
                                -RunId $runId `
                                -Stages $selectedStages `
                                -Mode $Mode `
                                -SubsystemInvoker $invoker
                        } | Should -Not -Throw
                        (
                            Get-CoordinateObservedCalls -RunId $runId
                        ) -join ',' | Should -BeExactly (
                            "Workstation|$Mode,Foundation|$Mode"
                        )
                        $controlRecordPath = Join-Path (
                            Split-Path -Parent $projectionPath
                        ) '.test-observation\record-Foundation.json'
                        $controlRecord = Get-Content `
                            -Raw `
                            -LiteralPath $controlRecordPath
                        $controlRecord |
                            Should -Not -Match (
                                'opaqueProviderExtras|' +
                                'provider-id-synthetic-001|' +
                                'Synthetic Provider|' +
                                'provider[.]example[.]invalid|' +
                                'nested-provider-value-synthetic'
                            )
                        $projectionPath | Should -Not -Exist
                        $script:CoordinateProviderRunnerCalls.Count |
                            Should -Be 0
                    }

                    It 'coordinated summary substitution fails closed before later <Mode> dispatch without disclosure or projection' -ForEach @(
                        @{ Mode = 'Assess' }
                        @{ Mode = 'Plan' }
                    ) {
                        $runId = [guid]::NewGuid()
                        $selectedStages = @(
                            'Workstation',
                            'Foundation'
                        )
                        Write-CoordinateStageResult `
                            -RunId $runId `
                            -Stage Workstation `
                            -SelectedStages $selectedStages
                        Add-CoordinateOpaqueProviderExtras `
                            -RunId $runId `
                            -Stage Workstation
                        Set-CoordinateCoordinatedSummarySubstitution `
                            -RunId $runId `
                            -Stage Workstation
                        $invoker = New-CoordinateArtifactInvoker
                        $runDirectory = Join-Path (
                            $script:CoordinateEvidenceRoot
                        ) $runId.ToString('D').ToLowerInvariant()
                        $projectionPath = Join-Path $runDirectory 'summary.json'
                        $caught = $null

                        try {
                            Invoke-CoordinateOrchestrator `
                                -RunId $runId `
                                -Stages $selectedStages `
                                -Mode $Mode `
                                -SubsystemInvoker $invoker
                        }
                        catch {
                            $caught = $_
                        }

                        $caught | Should -Not -BeNullOrEmpty
                        $caught.Exception.Message |
                            Should -BeExactly (
                                'TenantLifecycle.ChildArtifact.Invalid'
                            )
                        $caught.Exception.Message |
                            Should -Not -Match (
                                'opaqueProviderExtras|' +
                                'provider-id-synthetic-001|' +
                                'Synthetic Provider|' +
                                'provider[.]example[.]invalid|' +
                                'nested-provider-value-synthetic'
                            )
                        (
                            Get-CoordinateObservedCalls -RunId $runId
                        ) -join ',' | Should -BeExactly (
                            "Workstation|$Mode"
                        )
                        $controlRecord = Get-Content `
                            -Raw `
                            -LiteralPath (
                                Join-Path $runDirectory (
                                    '.test-observation\' +
                                    'record-Workstation.json'
                                )
                            )
                        $controlRecord |
                            Should -Not -Match (
                                'opaqueProviderExtras|' +
                                'provider-id-synthetic-001|' +
                                'Synthetic Provider|' +
                                'provider[.]example[.]invalid|' +
                                'nested-provider-value-synthetic'
                            )
                        $projectionPath | Should -Not -Exist
                        $script:CoordinateProviderRunnerCalls.Count |
                            Should -Be 0
                    }
                }

                Context 'canonical Verify evidence authority' {
                    BeforeAll {
                        function Write-CoordinateVerifySet {
                            param(
                                [Parameter(Mandatory)][guid]$RunId,
                                [string[]]$Stages = @('Foundation'),
                                [string[]]$InputStateDigests,
                                [string[]]$OutputStateDigests,
                                [string[]]$Statuses,
                                [string[]]$Classifications
                            )

                            $digests = Get-CoordinatePrivateDigests
                            if ($null -eq $InputStateDigests) {
                                $InputStateDigests = @(
                                    foreach ($stage in $Stages) {
                                        $digests.state
                                    }
                                )
                            }
                            if ($null -eq $OutputStateDigests) {
                                $OutputStateDigests = @($InputStateDigests)
                            }
                            if ($null -eq $Statuses) {
                                $Statuses = @(
                                    foreach ($stage in $Stages) { 'Passed' }
                                )
                            }
                            if ($null -eq $Classifications) {
                                $Classifications = @(
                                    foreach ($stage in $Stages) { 'NoChange' }
                                )
                            }

                            $runDirectory = Join-Path (
                                $script:CoordinateEvidenceRoot
                            ) $RunId.ToString('D').ToLowerInvariant()
                            $artifacts = [Collections.Generic.List[object]]::new()
                            for (
                                $index = 0;
                                $index -lt $Stages.Count;
                                $index++
                            ) {
                                $stage = [string]$Stages[$index]
                                $phaseDirectory = Join-Path $runDirectory (
                                    "phases\$stage"
                                )
                                $action = (
                                    $script:CoordinateFixture.executionManifest.actions[0] |
                                        ConvertTo-Json -Depth 30 |
                                        ConvertFrom-Json
                                )
                                $action.id = $stage
                                if ($index -eq 0) {
                                    $action.prerequisiteActionIds =
                                        [string[]]@()
                                }
                                else {
                                    $action.prerequisiteActionIds =
                                        [string[]]@($Stages[$index - 1])
                                }
                                [object[]]$manifestPrerequisites = @()
                                if ($index -gt 0) {
                                    $previousResult =
                                        $artifacts[$index - 1].Result
                                    $manifestPrerequisites = @(
                                        [pscustomobject][ordered]@{
                                            stage =
                                                [string]$previousResult.stage
                                            status =
                                                [string]$previousResult.status
                                            classification =
                                                [string]$previousResult.classification
                                            phaseManifestDigest =
                                                [string]$previousResult.phaseManifestDigest
                                            phaseSummaryDigest =
                                                [string]$previousResult.phaseSummaryDigest
                                            intentDigest =
                                                [string]$previousResult.intentDigest
                                            stateDigest =
                                                [string]$previousResult.stateDigest
                                        }
                                    )
                                }
                                $manifest = New-TenantLifecycleExecutionManifest `
                                    -RunId $RunId `
                                    -SourceCommit $script:CoordinateSourceCommit `
                                    -EvidenceRoot $phaseDirectory `
                                    -PublicTenantKey tenant1 `
                                    -IntentDigest $digests.intent `
                                    -StateDigest (
                                        [string]$InputStateDigests[$index]
                                    ) `
                                    -SelectedStages $Stages `
                                    -PrerequisiteResults $manifestPrerequisites `
                                    -Machine (
                                        $script:CoordinateFixture.executionManifest.machine
                                    ) `
                                    -Operator (
                                        $script:CoordinateFixture.executionManifest.operator
                                    ) `
                                    -ToolIdentities @(
                                        $script:CoordinateFixture.executionManifest.toolIdentities
                                    ) `
                                    -ProviderContexts @(
                                        $script:CoordinateFixture.executionManifest.providerContexts
                                    ) `
                                    -Prerequisites @(
                                        $script:CoordinateFixture.executionManifest.prerequisites
                                    ) `
                                    -Actions @($action) `
                                    -GeneratedAtUtc (
                                        [datetime]'2026-10-03T08:00:00Z'
                                    ) `
                                    -ExpiresAtUtc (
                                        [datetime]'2026-10-03T08:30:00Z'
                                    )
                                $manifestPath = Join-Path $phaseDirectory (
                                    'execution-manifest.json'
                                )
                                $manifestPath = Write-TenantLifecycleEvidence `
                                    -RunDirectory $phaseDirectory `
                                    -RelativePath 'execution-manifest.json' `
                                    -Kind ExecutionManifest `
                                    -InputObject $manifest
                                $phaseManifestDigest =
                                    Get-CoordinateExactFileDigest `
                                        -Path $manifestPath

                                $summary = (
                                    $script:CoordinateFixture.phaseSummary |
                                        ConvertTo-Json -Depth 30 |
                                        ConvertFrom-Json
                                )
                                $summary.runId =
                                    $RunId.ToString('D').ToLowerInvariant()
                                $summary.stage = $stage
                                $summary.sourceCommit =
                                    $script:CoordinateSourceCommit
                                $summary.publicTenantKey = 'tenant1'
                                $summary.intentDigest = $digests.intent
                                $summary.stateDigest =
                                    [string]$OutputStateDigests[$index]
                                $summary.phaseManifestDigest =
                                    $phaseManifestDigest
                                $summary.status =
                                    [string]$Statuses[$index]
                                $summary.classification =
                                    [string]$Classifications[$index]
                                $summary.startedAtUtc =
                                    '2026-10-03T08:30:00.0000000Z'
                                $summary.completedAtUtc =
                                    '2026-10-03T08:31:00.000Z'
                                $summary.actions[0].id = $stage
                                $summary.actions[0].classification = if (
                                    $summary.classification -ceq 'Changed'
                                ) {
                                    'Update'
                                }
                                else {
                                    $summary.classification
                                }
                                $summary.actions[0].status = $summary.status
                                $summary.actions[0].evidenceRelativePath =
                                    "actions/$stage.json"
                                $summary.syntheticProviderEvidence.tenantId =
                                    'tenant-private-identifier'
                                $summary.syntheticProviderEvidence.provider =
                                    'provider-private-identifier'
                                $summary.syntheticProviderEvidence.resourceUrl =
                                    'https://example.invalid/private-resource'
                                $summary.syntheticProviderEvidence.
                                    requestProjection.synthetic =
                                    'provider-private-payload'
                                $summaryPath =
                                    Write-TenantLifecycleEvidence `
                                        -RunDirectory $phaseDirectory `
                                        -RelativePath 'summary.json' `
                                        -Kind Summary `
                                        -InputObject $summary
                                $phaseSummaryDigest =
                                    Get-CoordinateExactFileDigest `
                                        -Path $summaryPath

                                $result = New-TenantLifecycleStageResult `
                                    -RunId $RunId `
                                    -Stage $stage `
                                    -SourceCommit $script:CoordinateSourceCommit `
                                    -PublicTenantKey tenant1 `
                                    -IntentDigest $digests.intent `
                                    -StateDigest (
                                        [string]$OutputStateDigests[$index]
                                    ) `
                                    -PhaseManifestDigest (
                                        $phaseManifestDigest
                                    ) `
                                    -PhaseSummaryDigest (
                                        $phaseSummaryDigest
                                    ) `
                                    -Status ([string]$Statuses[$index]) `
                                    -Classification (
                                        [string]$Classifications[$index]
                                    ) `
                                    -EvidenceRelativePath (
                                        "phases/$stage/summary.json"
                                    ) `
                                    -CompletedAtUtc (
                                        [datetime]'2026-10-03T08:31:00Z'
                                    )
                                $resultPath = Write-TenantLifecycleStageResult `
                                    -RunDirectory $runDirectory `
                                    -StageResult $result
                                $artifacts.Add([pscustomobject]@{
                                    ManifestPath = $manifestPath
                                    SummaryPath = $summaryPath
                                    ResultPath = $resultPath
                                    Result = $result
                                })
                            }
                            @($artifacts.ToArray())
                        }
                    }

                    It 'Verify shared summary envelope enforcement rejects coordinate substitution without invocation or projection' {
                        $runId = [guid]::NewGuid()
                        Write-CoordinateVerifySet -RunId $runId |
                            Out-Null
                        Set-CoordinateSummaryEnvelopeMismatch `
                            -RunId $runId `
                            -Stage Foundation
                        $projectionPath = Join-Path (
                            Join-Path $script:CoordinateEvidenceRoot (
                                $runId.ToString('D').ToLowerInvariant()
                            )
                        ) 'summary.json'

                        {
                            Invoke-CoordinateOrchestrator `
                                -RunId $runId `
                                -Stages @('Foundation') `
                                -Mode Verify
                        } | Should -Throw -ExpectedMessage (
                            'TenantLifecycle.StageResultSet.Invalid'
                        )
                        $projectionPath | Should -Not -Exist
                        $script:CoordinateProviderRunnerCalls.Count |
                            Should -Be 0
                    }

                    It 'Verify rejects mixed-case prohibited <Family> summary data without invocation disclosure or projection' -ForEach $coordinateMixedCaseProhibitedCases {
                        $runId = [guid]::NewGuid()
                        Write-CoordinateVerifySet -RunId $runId |
                            Out-Null
                        $marker =
                            "private-$Family-verify-marker-do-not-disclose"
                        Set-CoordinateMixedCaseProhibitedSummary `
                            -RunId $runId `
                            -Stage Foundation `
                            -PropertyName $PropertyName `
                            -Marker $marker
                        $runDirectory = Join-Path (
                            $script:CoordinateEvidenceRoot
                        ) $runId.ToString('D').ToLowerInvariant()
                        $projectionPath =
                            Join-Path $runDirectory 'summary.json'
                        $caught = $null

                        try {
                            Invoke-CoordinateOrchestrator `
                                -RunId $runId `
                                -Stages @('Foundation') `
                                -Mode Verify
                        }
                        catch {
                            $caught = $_
                        }

                        $caught | Should -Not -BeNullOrEmpty
                        $caught.Exception.Message |
                            Should -BeExactly (
                                'TenantLifecycle.StageResultSet.Invalid'
                            )
                        $caught.Exception.InnerException |
                            Should -BeNullOrEmpty
                        $caught.Exception.Message |
                            Should -Not -Match (
                                [regex]::Escape($PropertyName) + '|' +
                                [regex]::Escape($marker)
                            )
                        $projectionPath | Should -Not -Exist
                        @(
                            Get-CoordinateObservedCalls -RunId $runId
                        ).Count | Should -Be 0
                        Test-CoordinateProviderMarker -RunId $runId |
                            Should -BeFalse
                        $script:CoordinateProviderRunnerCalls.Count |
                            Should -Be 0
                    }

                    It 'Verify second Verify pass validates the stage result set exactly twice on success' {
                        $runId = [guid]::NewGuid()
                        Write-CoordinateVerifySet -RunId $runId |
                            Out-Null
                        $counterPath =
                            Install-CoordinateVerifyPassCounter `
                                -RunId $runId

                        {
                            Invoke-CoordinateOrchestrator `
                                -RunId $runId `
                                -Stages @('Foundation') `
                                -Mode Verify
                        } | Should -Not -Throw
                        [IO.File]::ReadAllLines($counterPath).Count |
                            Should -Be 2
                        $script:CoordinateProviderRunnerCalls.Count |
                            Should -Be 0
                    }

                    It 'Verify never invokes a supplied child invoker' {
                        $counter = 0
                        $invoker = {
                            $counter++
                        }.GetNewClosure()

                        {
                            Invoke-CoordinateOrchestrator `
                                -RunId ([guid]::NewGuid()) `
                                -Stages @('Foundation') `
                                -Mode Verify `
                                -SubsystemInvoker $invoker
                        } | Should -Throw -ExpectedMessage (
                            'TenantLifecycle.SubsystemInvoker.NotAllowed'
                        )
                        $counter | Should -Be 0
                    }

                    It 'Verify writes a stage-only projection without provider-rich phase summary data' {
                        $runId = [guid]::NewGuid()
                        Write-CoordinateVerifySet -RunId $runId | Out-Null

                        $output = @(
                            Invoke-CoordinateOrchestrator `
                                -RunId $runId `
                                -Stages @('Foundation') `
                                -Mode Verify
                        )

                        $output.Count | Should -Be 0
                        $summaryPath = Join-Path (
                            Join-Path $script:CoordinateEvidenceRoot (
                                $runId.ToString('D').ToLowerInvariant()
                            )
                        ) 'summary.json'
                        $summaryPath | Should -Exist
                        $projectionBytes = Get-Content `
                            -Raw `
                            -LiteralPath $summaryPath
                        $projectionBytes |
                            Should -Not -Match (
                                'tenant-private|provider-private|' +
                                'example[.]invalid|action-synthetic|' +
                                'requestPayload|rawReadBack'
                            )
                        $projection = $projectionBytes | ConvertFrom-Json
                        ($projection.stages.stage -join ',') |
                            Should -BeExactly 'Foundation'
                    }

                    It 'opaque provider extras stay out of Verify projection and invoke no child or provider path' {
                        $runId = [guid]::NewGuid()
                        Write-CoordinateVerifySet -RunId $runId | Out-Null
                        Add-CoordinateOpaqueProviderExtras `
                            -RunId $runId `
                            -Stage Foundation

                        $output = @(
                            Invoke-CoordinateOrchestrator `
                                -RunId $runId `
                                -Stages @('Foundation') `
                                -Mode Verify
                        )

                        $output.Count | Should -Be 0
                        $runDirectory = Join-Path (
                            $script:CoordinateEvidenceRoot
                        ) $runId.ToString('D').ToLowerInvariant()
                        $projectionPath = Join-Path $runDirectory 'summary.json'
                        $projectionBytes = Get-Content `
                            -Raw `
                            -LiteralPath $projectionPath
                        $projectionBytes |
                            Should -Not -Match (
                                'opaqueProviderExtras|' +
                                'provider-id-synthetic-001|' +
                                'Synthetic Provider|' +
                                'provider[.]example[.]invalid|' +
                                'nested-provider-value-synthetic'
                            )
                        @(
                            Get-CoordinateObservedCalls -RunId $runId
                        ).Count | Should -Be 0
                        Test-CoordinateProviderMarker -RunId $runId |
                            Should -BeFalse
                        $script:CoordinateProviderRunnerCalls.Count |
                            Should -Be 0
                    }

                    It 'coordinated summary substitution preserves an existing Verify projection and discloses no opaque provider extras' {
                        $runId = [guid]::NewGuid()
                        Write-CoordinateVerifySet -RunId $runId | Out-Null
                        Add-CoordinateOpaqueProviderExtras `
                            -RunId $runId `
                            -Stage Foundation
                        Set-CoordinateCoordinatedSummarySubstitution `
                            -RunId $runId `
                            -Stage Foundation
                        $runDirectory = Join-Path (
                            $script:CoordinateEvidenceRoot
                        ) $runId.ToString('D').ToLowerInvariant()
                        $projectionPath = Join-Path $runDirectory 'summary.json'
                        $sentinel = "sentinel-projection-must-survive`n"
                        [IO.File]::WriteAllText(
                            $projectionPath,
                            $sentinel,
                            [Text.UTF8Encoding]::new($false)
                        )
                        $caught = $null

                        try {
                            Invoke-CoordinateOrchestrator `
                                -RunId $runId `
                                -Stages @('Foundation') `
                                -Mode Verify
                        }
                        catch {
                            $caught = $_
                        }

                        $caught | Should -Not -BeNullOrEmpty
                        $caught.Exception.Message |
                            Should -BeExactly (
                                'TenantLifecycle.StageResultSet.Invalid'
                            )
                        $caught.Exception.Message |
                            Should -Not -Match (
                                'opaqueProviderExtras|' +
                                'provider-id-synthetic-001|' +
                                'Synthetic Provider|' +
                                'provider[.]example[.]invalid|' +
                                'nested-provider-value-synthetic'
                            )
                        [IO.File]::ReadAllText(
                            $projectionPath,
                            [Text.UTF8Encoding]::new($false, $true)
                        ) | Should -BeExactly $sentinel
                        @(
                            Get-CoordinateObservedCalls -RunId $runId
                        ).Count | Should -Be 0
                        Test-CoordinateProviderMarker -RunId $runId |
                            Should -BeFalse
                        $script:CoordinateProviderRunnerCalls.Count |
                            Should -Be 0
                    }

                    It 'Verify second Verify pass rejects <Mutation> evidence drift without writing projection' -ForEach @(
                        @{ Mutation = 'Result' }
                        @{ Mutation = 'Manifest' }
                        @{ Mutation = 'Summary' }
                        @{ Mutation = 'Extra' }
                        @{ Mutation = 'Missing' }
                        @{ Mutation = 'Path' }
                    ) {
                        $runId = [guid]::NewGuid()
                        Write-CoordinateVerifySet -RunId $runId | Out-Null
                        $counterPath =
                            Install-CoordinateVerifyPassCounter `
                                -RunId $runId
                        Install-CoordinateEvidenceMutationHook `
                            -Mutation $Mutation `
                            -RunId $runId
                        $summaryPath = Join-Path (
                            Join-Path $script:CoordinateEvidenceRoot (
                                $runId.ToString('D').ToLowerInvariant()
                            )
                        ) 'summary.json'

                        {
                            Invoke-CoordinateOrchestrator `
                                -RunId $runId `
                                -Stages @('Foundation') `
                                -Mode Verify
                        } | Should -Throw
                        $summaryPath | Should -Not -Exist
                        [IO.File]::ReadAllLines($counterPath).Count |
                            Should -Be 2
                    }

                    It 'Verify rejects a mismatched <Case> phase summary digest' -ForEach @(
                        @{ Case = 'manifest'; Property = 'ManifestPath' }
                        @{ Case = 'summary'; Property = 'SummaryPath' }
                    ) {
                        $runId = [guid]::NewGuid()
                        $artifacts = @(
                            Write-CoordinateVerifySet -RunId $runId
                        )
                        $path = [string]$artifacts[0].$Property
                        $value = Get-Content -Raw -LiteralPath $path |
                            ConvertFrom-Json
                        $value | Add-Member `
                            -NotePropertyName tampered `
                            -NotePropertyValue $true
                        Write-CoordinateCanonicalFile `
                            -InputObject $value `
                            -Path $path

                        {
                            Invoke-CoordinateOrchestrator `
                                -RunId $runId `
                                -Stages @('Foundation') `
                                -Mode Verify
                        } | Should -Throw
                    }

                    It 'Verify accepts an ordered changed stage state digest chain' {
                        $runId = [guid]::NewGuid()
                        $currentState = (Get-CoordinatePrivateDigests).state
                        Write-CoordinateVerifySet `
                            -RunId $runId `
                            -Stages @('Workstation', 'Foundation') `
                            -InputStateDigests @(('8' * 64), ('9' * 64)) `
                            -OutputStateDigests @(
                                ('9' * 64),
                                $currentState
                            ) `
                            -Classifications @('Changed', 'Changed') |
                            Out-Null

                        {
                            Invoke-CoordinateOrchestrator `
                                -RunId $runId `
                                -Stages @('Workstation', 'Foundation') `
                                -Mode Verify
                        } | Should -Not -Throw
                    }

                    It 'Verify rejects an invalid stage state digest chain for <Case>' -ForEach @(
                        @{
                            Case = 'unexplained transition'
                            Inputs = @('8' * 64)
                            Outputs = @('9' * 64)
                            Classifications = @('NoChange')
                        }
                        @{
                            Case = 'final current mismatch'
                            Inputs = @('8' * 64)
                            Outputs = @('9' * 64)
                            Classifications = @('Changed')
                        }
                    ) {
                        $runId = [guid]::NewGuid()
                        Write-CoordinateVerifySet `
                            -RunId $runId `
                            -InputStateDigests $Inputs `
                            -OutputStateDigests $Outputs `
                            -Classifications $Classifications |
                            Out-Null

                        {
                            Invoke-CoordinateOrchestrator `
                                -RunId $runId `
                                -Stages @('Foundation') `
                                -Mode Verify
                        } | Should -Throw
                    }

                    It 'Verify rejects a non-Passed literal dependency outcome <Status>/<Classification>' -ForEach @(
                        @{ Status = 'Failed'; Classification = 'NoChange' }
                        @{ Status = 'Failed'; Classification = 'Changed' }
                        @{ Status = 'Manual'; Classification = 'Manual' }
                        @{ Status = 'Blocked'; Classification = 'Blocked' }
                        @{ Status = 'Refused'; Classification = 'Refused' }
                    ) {
                        $runId = [guid]::NewGuid()
                        $currentState = (Get-CoordinatePrivateDigests).state
                        Write-CoordinateVerifySet `
                            -RunId $runId `
                            -Stages @('Foundation') `
                            -InputStateDigests @($currentState) `
                            -OutputStateDigests @($currentState) `
                            -Statuses @($Status) `
                            -Classifications @($Classification) |
                            Out-Null

                        {
                            Invoke-CoordinateOrchestrator `
                                -RunId $runId `
                                -Stages @('Foundation') `
                                -Mode Verify
                        } | Should -Throw
                    }
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
                -SelectedStages @(
                    $script:ApprovalFixture.executionManifest.selectedStages
                ) `
                -PrerequisiteResults @(
                    $script:ApprovalFixture.executionManifest.prerequisiteResults
                ) `
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
                selectedStages = [string[]]@($Manifest.selectedStages)
                prerequisiteResults =
                    [object[]]@($Manifest.prerequisiteResults)
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
