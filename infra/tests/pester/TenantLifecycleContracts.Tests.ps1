Set-StrictMode -Version Latest

$contractCases = @(
    @{ Name = 'assessment'; Kind = 'Assessment'; FixtureProperty = 'assessment'; SchemaFile = 'tenant-lifecycle-assessment.schema.json'; DigestPath = 'digest' }
    @{ Name = 'stage result'; Kind = 'StageResult'; FixtureProperty = 'stageResult'; SchemaFile = 'tenant-lifecycle-stage-result.schema.json'; DigestPath = 'phaseSummaryDigest' }
    @{ Name = 'execution manifest'; Kind = 'ExecutionManifest'; FixtureProperty = 'executionManifest'; SchemaFile = 'tenant-lifecycle-execution-manifest.schema.json'; DigestPath = 'digest' }
    @{ Name = 'approval'; Kind = 'Approval'; FixtureProperty = 'approval'; SchemaFile = 'tenant-lifecycle-approval.schema.json'; DigestPath = 'executionManifestDigest' }
    @{ Name = 'action evidence'; Kind = 'ActionEvidence'; FixtureProperty = 'actionEvidence'; SchemaFile = 'tenant-lifecycle-action-evidence.schema.json'; DigestPath = 'preReadDigest' }
    @{ Name = 'state'; Kind = 'State'; FixtureProperty = 'state'; SchemaFile = 'tenant-lifecycle-state.schema.json'; DigestPath = 'resources.ownedPropertiesDigest' }
    @{ Name = 'read-back'; Kind = 'ReadBack'; FixtureProperty = 'readBack'; SchemaFile = 'tenant-lifecycle-read-back.schema.json'; DigestPath = 'digest' }
    @{ Name = 'summary'; Kind = 'Summary'; FixtureProperty = 'summary'; SchemaFile = 'tenant-lifecycle-summary.schema.json'; DigestPath = 'manifestDigest' }
)
$statusCases = @(
    @{ Name = 'assessment provider context'; Kind = 'Assessment'; FixtureProperty = 'assessment'; SchemaFile = 'tenant-lifecycle-assessment.schema.json'; FieldPath = 'providerContexts.0.status' }
    @{ Name = 'assessment component'; Kind = 'Assessment'; FixtureProperty = 'assessment'; SchemaFile = 'tenant-lifecycle-assessment.schema.json'; FieldPath = 'components.0.status' }
    @{ Name = 'assessment prerequisite'; Kind = 'Assessment'; FixtureProperty = 'assessment'; SchemaFile = 'tenant-lifecycle-assessment.schema.json'; FieldPath = 'prerequisites.0.status' }
    @{ Name = 'execution manifest provider context'; Kind = 'ExecutionManifest'; FixtureProperty = 'executionManifest'; SchemaFile = 'tenant-lifecycle-execution-manifest.schema.json'; FieldPath = 'providerContexts.0.status' }
    @{ Name = 'execution manifest prerequisite'; Kind = 'ExecutionManifest'; FixtureProperty = 'executionManifest'; SchemaFile = 'tenant-lifecycle-execution-manifest.schema.json'; FieldPath = 'prerequisites.0.status' }
    @{ Name = 'action evidence'; Kind = 'ActionEvidence'; FixtureProperty = 'actionEvidence'; SchemaFile = 'tenant-lifecycle-action-evidence.schema.json'; FieldPath = 'status' }
    @{ Name = 'read-back component'; Kind = 'ReadBack'; FixtureProperty = 'readBack'; SchemaFile = 'tenant-lifecycle-read-back.schema.json'; FieldPath = 'components.0.status' }
    @{ Name = 'read-back root'; Kind = 'ReadBack'; FixtureProperty = 'readBack'; SchemaFile = 'tenant-lifecycle-read-back.schema.json'; FieldPath = 'status' }
    @{ Name = 'summary prerequisite'; Kind = 'Summary'; FixtureProperty = 'summary'; SchemaFile = 'tenant-lifecycle-summary.schema.json'; FieldPath = 'prerequisites.0.status' }
    @{ Name = 'summary action'; Kind = 'Summary'; FixtureProperty = 'summary'; SchemaFile = 'tenant-lifecycle-summary.schema.json'; FieldPath = 'actions.0.status' }
    @{ Name = 'summary root'; Kind = 'Summary'; FixtureProperty = 'summary'; SchemaFile = 'tenant-lifecycle-summary.schema.json'; FieldPath = 'status' }
)
$dateTimeCases = @(
    @{ Name = 'assessment generatedAtUtc'; Kind = 'Assessment'; FixtureProperty = 'assessment'; SchemaFile = 'tenant-lifecycle-assessment.schema.json'; FieldPath = 'generatedAtUtc'; LowercaseValue = '2026-10-02T12:00:00z' }
    @{ Name = 'execution manifest generatedAtUtc'; Kind = 'ExecutionManifest'; FixtureProperty = 'executionManifest'; SchemaFile = 'tenant-lifecycle-execution-manifest.schema.json'; FieldPath = 'generatedAtUtc'; LowercaseValue = '2026-10-02T12:05:00z' }
    @{ Name = 'execution manifest expiresAtUtc'; Kind = 'ExecutionManifest'; FixtureProperty = 'executionManifest'; SchemaFile = 'tenant-lifecycle-execution-manifest.schema.json'; FieldPath = 'expiresAtUtc'; LowercaseValue = '2026-10-02T12:35:00z' }
    @{ Name = 'approval approvedAtUtc'; Kind = 'Approval'; FixtureProperty = 'approval'; SchemaFile = 'tenant-lifecycle-approval.schema.json'; FieldPath = 'approvedAtUtc'; LowercaseValue = '2026-10-02T12:06:00z' }
    @{ Name = 'approval expiresAtUtc'; Kind = 'Approval'; FixtureProperty = 'approval'; SchemaFile = 'tenant-lifecycle-approval.schema.json'; FieldPath = 'expiresAtUtc'; LowercaseValue = '2026-10-02T12:35:00z' }
    @{ Name = 'action evidence startedAtUtc'; Kind = 'ActionEvidence'; FixtureProperty = 'actionEvidence'; SchemaFile = 'tenant-lifecycle-action-evidence.schema.json'; FieldPath = 'startedAtUtc'; LowercaseValue = '2026-10-02T12:07:00z' }
    @{ Name = 'action evidence completedAtUtc'; Kind = 'ActionEvidence'; FixtureProperty = 'actionEvidence'; SchemaFile = 'tenant-lifecycle-action-evidence.schema.json'; FieldPath = 'completedAtUtc'; LowercaseValue = '2026-10-02T12:08:00z' }
    @{ Name = 'state resource lastVerifiedAtUtc'; Kind = 'State'; FixtureProperty = 'state'; SchemaFile = 'tenant-lifecycle-state.schema.json'; FieldPath = 'resources.0.lastVerifiedAtUtc'; LowercaseValue = '2026-10-02T12:09:00z' }
    @{ Name = 'read-back generatedAtUtc'; Kind = 'ReadBack'; FixtureProperty = 'readBack'; SchemaFile = 'tenant-lifecycle-read-back.schema.json'; FieldPath = 'generatedAtUtc'; LowercaseValue = '2026-10-02T12:10:00z' }
    @{ Name = 'summary startedAtUtc'; Kind = 'Summary'; FixtureProperty = 'summary'; SchemaFile = 'tenant-lifecycle-summary.schema.json'; FieldPath = 'startedAtUtc'; LowercaseValue = '2026-10-02T12:00:00z' }
    @{ Name = 'summary completedAtUtc'; Kind = 'Summary'; FixtureProperty = 'summary'; SchemaFile = 'tenant-lifecycle-summary.schema.json'; FieldPath = 'completedAtUtc'; LowercaseValue = '2026-10-02T12:11:00z' }
)
$pythonResult = & python -c 'import jsonschema' 2>&1
$hasJsonSchema = $LASTEXITCODE -eq 0
foreach ($testCase in @($statusCases) + @($dateTimeCases)) {
    $testCase.HasJsonSchema = $hasJsonSchema
}

Describe 'Tenant lifecycle canonical stage result evidence' {
    BeforeAll {
        $script:CanonicalRepositoryRoot = (
            Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
        ).Path
        $script:CanonicalModulePath = Join-Path $script:CanonicalRepositoryRoot (
            'infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\' +
            'Caldova.HrFrontier.Bootstrap.psd1'
        )
        Import-Module $script:CanonicalModulePath -Force
        $fixturePath = Join-Path $script:CanonicalRepositoryRoot (
            'infra\tests\fixtures\runbooks\tenant-lifecycle.synthetic.json'
        )
        $script:CanonicalFixture = ConvertFrom-TenantLifecycleJson -InputObject (
            Get-Content -Raw -LiteralPath $fixturePath
        )
        $script:CanonicalSource = 'a' * 40
        $script:CanonicalIntent = '1' * 64
        $script:CanonicalCurrentState = '2' * 64

        function Copy-CanonicalTestValue {
            param([Parameter(Mandatory)][object]$InputObject)

            ConvertFrom-TenantLifecycleJson -InputObject (
                $InputObject | ConvertTo-Json -Depth 30
            )
        }

        function Write-CanonicalTestFile {
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

        function Get-CanonicalTestFileDigest {
            param([Parameter(Mandatory)][string]$Path)

            $algorithm = [Security.Cryptography.SHA256]::Create()
            try {
                -join @(
                    $algorithm.ComputeHash([IO.File]::ReadAllBytes($Path)) |
                        ForEach-Object { $_.ToString('x2') }
                )
            }
            finally {
                $algorithm.Dispose()
            }
        }

        function New-CanonicalStageSet {
            param(
                [Parameter(Mandatory)][string]$RunDirectory,
                [Parameter(Mandatory)][guid]$RunId,
                [string[]]$Stages = @('Foundation'),
                [string[]]$InputStateDigests,
                [string[]]$OutputStateDigests,
                [string[]]$Statuses,
                [string[]]$Classifications
            )

            if ($null -eq $InputStateDigests) {
                $InputStateDigests = @(
                    foreach ($stage in $Stages) {
                        $script:CanonicalCurrentState
                    }
                )
            }
            if ($null -eq $OutputStateDigests) {
                $OutputStateDigests = @($InputStateDigests)
            }
            if ($null -eq $Statuses) {
                $Statuses = @(foreach ($stage in $Stages) { 'Passed' })
            }
            if ($null -eq $Classifications) {
                $Classifications = @(foreach ($stage in $Stages) { 'NoChange' })
            }

            $results = [Collections.Generic.List[object]]::new()
            $manifestPaths = [Collections.Generic.List[string]]::new()
            $summaryPaths = [Collections.Generic.List[string]]::new()
            for ($index = 0; $index -lt $Stages.Count; $index++) {
                $stage = [string]$Stages[$index]
                $phaseDirectory = Join-Path $RunDirectory "phases\$stage"
                $manifestPath = Join-Path $phaseDirectory 'execution-manifest.json'
                $summaryPath = Join-Path $phaseDirectory 'summary.json'
                [object[]]$prerequisiteResults = @()
                if ($index -gt 0) {
                    $previousResult = $results[$index - 1]
                    $prerequisiteResults = @(
                        [pscustomobject][ordered]@{
                            stage = [string]$previousResult.stage
                            status = [string]$previousResult.status
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
                $manifest = [pscustomobject][ordered]@{
                    schemaVersion = '1.0'
                    runId = $RunId.ToString('D').ToLowerInvariant()
                    sourceCommit = $script:CanonicalSource
                    publicTenantKey = 'tenant1'
                    intentDigest = $script:CanonicalIntent
                    stateDigest = [string]$InputStateDigests[$index]
                    selectedStages = [string[]]@($Stages)
                    prerequisiteResults = $prerequisiteResults
                    providerContexts = @(
                        [pscustomobject][ordered]@{
                            provider = 'Synthetic'
                            contextId = 'provider-context-private'
                        }
                    )
                    actions = @(
                        [pscustomobject][ordered]@{
                            id = 'provider-action-private'
                            payload = 'provider-payload-private'
                        }
                    )
                }
                $summary = Copy-CanonicalTestValue (
                    $script:CanonicalFixture.phaseSummary
                )
                $summary.runId = $RunId.ToString('D').ToLowerInvariant()
                $summary.stage = $stage
                Write-CanonicalTestFile -InputObject $manifest -Path $manifestPath
                Write-CanonicalTestFile -InputObject $summary -Path $summaryPath
                $result = New-TenantLifecycleStageResult `
                    -RunId $RunId `
                    -Stage $stage `
                    -SourceCommit $script:CanonicalSource `
                    -PublicTenantKey tenant1 `
                    -IntentDigest $script:CanonicalIntent `
                    -StateDigest ([string]$OutputStateDigests[$index]) `
                    -PhaseManifestDigest (
                        Get-CanonicalTestFileDigest -Path $manifestPath
                    ) `
                    -PhaseSummaryDigest (
                        Get-CanonicalTestFileDigest -Path $summaryPath
                    ) `
                    -Status ([string]$Statuses[$index]) `
                    -Classification ([string]$Classifications[$index]) `
                    -EvidenceRelativePath "phases/$stage/summary.json" `
                    -CompletedAtUtc ([datetime]'2026-10-03T08:31:00Z')
                Write-TenantLifecycleStageResult `
                    -RunDirectory $RunDirectory `
                    -StageResult $result |
                    Out-Null
                $results.Add($result)
                $manifestPaths.Add($manifestPath)
                $summaryPaths.Add($summaryPath)
            }

            [pscustomobject]@{
                Results = @($results.ToArray())
                ManifestPaths = @($manifestPaths.ToArray())
                SummaryPaths = @($summaryPaths.ToArray())
            }
        }

        function Invoke-CanonicalStageSet {
            param(
                [Parameter(Mandatory)][string]$RunDirectory,
                [Parameter(Mandatory)][guid]$RunId,
                [string[]]$Stages = @('Foundation'),
                [string]$CurrentStateDigest = $script:CanonicalCurrentState
            )

            @(
                Test-TenantLifecycleStageResultSet `
                    -RunDirectory $RunDirectory `
                    -RunId $RunId `
                    -Stages $Stages `
                    -SourceCommit $script:CanonicalSource `
                    -PublicTenantKey tenant1 `
                    -IntentDigest $script:CanonicalIntent `
                    -CurrentStateDigest $CurrentStateDigest
            )
        }
    }

    It 'creates and writes one immutable canonical stage result' {
        $runId = [guid]'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee'
        $runDirectory = Join-Path $TestDrive 'canonical-stage-result'
        $set = New-CanonicalStageSet -RunDirectory $runDirectory -RunId $runId
        $path = Join-Path $runDirectory 'stages\Foundation.json'
        $bytes = [IO.File]::ReadAllBytes($path)
        $text = [Text.UTF8Encoding]::new($false, $true).GetString($bytes)

        ($set.Results[0].PSObject.Properties.Name -join ',') |
            Should -BeExactly (
                'schemaVersion,runId,stage,sourceCommit,publicTenantKey,' +
                'intentDigest,stateDigest,phaseManifestDigest,' +
                'phaseSummaryDigest,status,classification,' +
                'evidenceRelativePath,completedAtUtc'
            )
        ($bytes[0..2] -join ',') | Should -Not -BeExactly '239,187,191'
        $text.EndsWith("`n", [StringComparison]::Ordinal) | Should -BeTrue
        $text.EndsWith("`n`n", [StringComparison]::Ordinal) | Should -BeFalse
        $text.Contains("`r") | Should -BeFalse
        $set.Results[0].phaseManifestDigest |
            Should -Match '^[0-9a-f]{64}$'

        {
            Write-TenantLifecycleStageResult `
                -RunDirectory $runDirectory `
                -StageResult $set.Results[0]
        } | Should -Throw -ExpectedMessage 'TenantLifecycle.Evidence.Exists'
    }

    It 'returns the caller ordered exact stage result set without child summary properties' {
        $runId = [guid]::NewGuid()
        $runDirectory = Join-Path $TestDrive 'exact-stage-result-set'
        New-CanonicalStageSet `
            -RunDirectory $runDirectory `
            -RunId $runId `
            -Stages @('Workstation', 'Foundation') |
            Out-Null

        $actual = @(
            Invoke-CanonicalStageSet `
                -RunDirectory $runDirectory `
                -RunId $runId `
                -Stages @('Workstation', 'Foundation')
        )

        ($actual.stage -join ',') | Should -BeExactly 'Workstation,Foundation'
        foreach ($result in $actual) {
            ($result.PSObject.Properties.Name -join ',') |
                Should -BeExactly (
                    'schemaVersion,runId,stage,sourceCommit,publicTenantKey,' +
                    'intentDigest,stateDigest,phaseManifestDigest,' +
                    'phaseSummaryDigest,status,classification,' +
                    'evidenceRelativePath,completedAtUtc'
                )
        }
        ($actual | ConvertTo-Json -Depth 10) |
            Should -Not -Match 'providerId|resourceUrl|actionId|payload|readBack'
    }

    It 'rejects a wrong manifest envelope from the exact stage result set for <Case>' -ForEach @(
        @{ Case = 'missing selectedStages'; ManifestIndex = 0; Mutation = 'MissingSelected' }
        @{ Case = 'wrong selectedStages'; ManifestIndex = 0; Mutation = 'WrongSelected' }
        @{ Case = 'reordered selectedStages'; ManifestIndex = 0; Mutation = 'ReorderedSelected' }
        @{ Case = 'missing prerequisiteResults'; ManifestIndex = 1; Mutation = 'MissingPrerequisites' }
        @{ Case = 'wrong prerequisiteResults'; ManifestIndex = 1; Mutation = 'WrongPrerequisites' }
        @{ Case = 'extra prerequisiteResults'; ManifestIndex = 0; Mutation = 'ExtraPrerequisites' }
    ) {
        $runId = [guid]::NewGuid()
        $runDirectory = Join-Path $TestDrive (
            "manifest-envelope-$Mutation"
        )
        $stages = @('Workstation', 'Foundation')
        $set = New-CanonicalStageSet `
            -RunDirectory $runDirectory `
            -RunId $runId `
            -Stages $stages
        $manifestPath = [string]$set.ManifestPaths[$ManifestIndex]
        $manifest = Get-Content -Raw -LiteralPath $manifestPath |
            ConvertFrom-Json
        switch ($Mutation) {
            'MissingSelected' {
                $manifest.PSObject.Properties.Remove('selectedStages')
            }
            'WrongSelected' {
                $manifest.selectedStages =
                    [string[]]@('Workstation', 'ReadBack')
            }
            'ReorderedSelected' {
                $manifest.selectedStages =
                    [string[]]@('Foundation', 'Workstation')
            }
            'MissingPrerequisites' {
                $manifest.PSObject.Properties.Remove(
                    'prerequisiteResults'
                )
            }
            'WrongPrerequisites' {
                $manifest.prerequisiteResults[0].stage = 'ReadBack'
            }
            'ExtraPrerequisites' {
                $manifest.prerequisiteResults = @(
                    [pscustomobject][ordered]@{
                        stage = 'Workstation'
                        status = 'Passed'
                        classification = 'NoChange'
                        phaseManifestDigest = '3' * 64
                        phaseSummaryDigest = '4' * 64
                        intentDigest = $script:CanonicalIntent
                        stateDigest = $script:CanonicalCurrentState
                    }
                )
            }
        }
        Write-CanonicalTestFile `
            -InputObject $manifest `
            -Path $manifestPath
        $stage = [string]$stages[$ManifestIndex]
        $resultPath = Join-Path $runDirectory "stages\$stage.json"
        $result = Get-Content -Raw -LiteralPath $resultPath |
            ConvertFrom-Json
        $result.phaseManifestDigest =
            Get-CanonicalTestFileDigest -Path $manifestPath
        Write-CanonicalTestFile -InputObject $result -Path $resultPath

        {
            Invoke-CanonicalStageSet `
                -RunDirectory $runDirectory `
                -RunId $runId `
                -Stages $stages
        } | Should -Throw -ExpectedMessage (
            'TenantLifecycle.StageResultSet.Invalid'
        )
    }

    It 'rejects prerequisiteResults outside the exact control-record success allowlist' {
        $runId = [guid]::NewGuid()
        $runDirectory = Join-Path $TestDrive (
            'manifest-envelope-failed-prerequisite'
        )
        $stages = @('Workstation', 'Foundation')
        New-CanonicalStageSet `
            -RunDirectory $runDirectory `
            -RunId $runId `
            -Stages $stages `
            -Statuses @('Failed', 'Passed') `
            -Classifications @('NoChange', 'NoChange') |
            Out-Null

        {
            Invoke-CanonicalStageSet `
                -RunDirectory $runDirectory `
                -RunId $runId `
                -Stages $stages
        } | Should -Throw -ExpectedMessage (
            'TenantLifecycle.StageResultSet.Invalid'
        )
    }

    It 'rejects actual case drift in exact stage result set path segment <Segment>' -ForEach @(
        @{ Segment = 'stages directory'; RelativePath = 'stages'; DriftedName = 'Stages' }
        @{ Segment = 'result filename'; RelativePath = 'stages\Foundation.json'; DriftedName = 'foundation.json' }
        @{ Segment = 'phases directory'; RelativePath = 'phases'; DriftedName = 'Phases' }
        @{ Segment = 'phase stage directory'; RelativePath = 'phases\Foundation'; DriftedName = 'foundation' }
        @{ Segment = 'manifest filename'; RelativePath = 'phases\Foundation\execution-manifest.json'; DriftedName = 'Execution-Manifest.json' }
        @{ Segment = 'summary filename'; RelativePath = 'phases\Foundation\summary.json'; DriftedName = 'Summary.json' }
    ) {
        $runId = [guid]::NewGuid()
        $runDirectory = Join-Path $TestDrive (
            'case-segment-' + $Segment.Replace(' ', '-')
        )
        New-CanonicalStageSet `
            -RunDirectory $runDirectory `
            -RunId $runId |
            Out-Null
        $sourcePath = Join-Path $runDirectory $RelativePath
        $parent = Split-Path -Parent $sourcePath
        $temporaryPath = Join-Path $parent (
            '.case-' + [guid]::NewGuid().ToString('N')
        )
        $driftedPath = Join-Path $parent $DriftedName
        Move-Item -LiteralPath $sourcePath -Destination $temporaryPath
        Move-Item -LiteralPath $temporaryPath -Destination $driftedPath

        {
            Invoke-CanonicalStageSet `
                -RunDirectory $runDirectory `
                -RunId $runId
        } | Should -Throw -ExpectedMessage (
            'TenantLifecycle.StageResultSet.Invalid'
        )
    }

    It 'rejects a missing or extra entry from the exact stage result set' -ForEach @(
        @{ Case = 'missing'; Mutate = 'Missing' }
        @{ Case = 'extra'; Mutate = 'Extra' }
        @{ Case = 'alternate filename'; Mutate = 'Alternate' }
    ) {
        $runId = [guid]::NewGuid()
        $runDirectory = Join-Path $TestDrive "exact-set-$($Case.Replace(' ', '-'))"
        New-CanonicalStageSet -RunDirectory $runDirectory -RunId $runId |
            Out-Null
        $resultPath = Join-Path $runDirectory 'stages\Foundation.json'
        switch ($Mutate) {
            'Missing' {
                Remove-Item -LiteralPath $resultPath -Force
            }
            'Extra' {
                [IO.File]::WriteAllText(
                    (Join-Path $runDirectory 'stages\extra.json'),
                    "{}`n",
                    [Text.UTF8Encoding]::new($false)
                )
            }
            'Alternate' {
                $temporaryPath = Join-Path $runDirectory 'stages\temporary.json'
                Move-Item -LiteralPath $resultPath -Destination $temporaryPath
                Move-Item `
                    -LiteralPath $temporaryPath `
                    -Destination (Join-Path $runDirectory 'stages\foundation.json')
            }
        }

        {
            Invoke-CanonicalStageSet `
                -RunDirectory $runDirectory `
                -RunId $runId
        } | Should -Throw
    }

    It 'rejects duplicate or reordered selected stages from the exact stage result set' -ForEach @(
        @{ Case = 'duplicate'; Selected = @('Foundation', 'Foundation') }
        @{ Case = 'reordered'; Selected = @('Foundation', 'Workstation') }
    ) {
        $runId = [guid]::NewGuid()
        $runDirectory = Join-Path $TestDrive "stage-order-$Case"
        New-CanonicalStageSet `
            -RunDirectory $runDirectory `
            -RunId $runId `
            -Stages @('Workstation', 'Foundation') |
            Out-Null

        {
            Invoke-CanonicalStageSet `
                -RunDirectory $runDirectory `
                -RunId $runId `
                -Stages $Selected
        } | Should -Throw
    }

    It 'rejects foreign or stale values from the exact stage result set for <Case>' -ForEach @(
        @{ Case = 'run'; Field = 'runId'; Value = 'bbbbbbbb-cccc-4ddd-8eee-ffffffffffff' }
        @{ Case = 'source'; Field = 'sourceCommit'; Value = ('b' * 40) }
        @{ Case = 'intent'; Field = 'intentDigest'; Value = ('3' * 64) }
        @{ Case = 'tenant'; Field = 'publicTenantKey'; Value = 'tenant2' }
        @{ Case = 'stage'; Field = 'stage'; Value = 'ReadBack' }
        @{ Case = 'outcome pair'; Field = 'classification'; Value = 'Manual' }
    ) {
        $runId = [guid]::NewGuid()
        $runDirectory = Join-Path $TestDrive "foreign-$Case"
        $set = New-CanonicalStageSet -RunDirectory $runDirectory -RunId $runId
        $result = Copy-CanonicalTestValue $set.Results[0]
        $result.$Field = $Value
        Write-CanonicalTestFile `
            -InputObject $result `
            -Path (Join-Path $runDirectory 'stages\Foundation.json')

        {
            Invoke-CanonicalStageSet `
                -RunDirectory $runDirectory `
                -RunId $runId
        } | Should -Throw
    }

    It 'rejects noncanonical bytes from the exact stage result set for <Case>' -ForEach @(
        @{ Case = 'UTF-8 BOM'; Mutation = 'Bom' }
        @{ Case = 'CRLF'; Mutation = 'CrLf' }
        @{ Case = 'zero LF'; Mutation = 'ZeroLf' }
        @{ Case = 'two trailing LFs'; Mutation = 'TwoLf' }
        @{ Case = 'key order'; Mutation = 'KeyOrder' }
        @{ Case = 'whitespace'; Mutation = 'Whitespace' }
        @{ Case = 'upper-case digest'; Mutation = 'UpperDigest' }
        @{ Case = 'malformed JSON'; Mutation = 'Malformed' }
        @{ Case = 'non-object root'; Mutation = 'Array' }
        @{ Case = 'additional property'; Mutation = 'Additional' }
        @{ Case = 'duplicate JSON property'; Mutation = 'Duplicate' }
    ) {
        $runId = [guid]::NewGuid()
        $runDirectory = Join-Path $TestDrive "noncanonical-$Mutation"
        $set = New-CanonicalStageSet -RunDirectory $runDirectory -RunId $runId
        $path = Join-Path $runDirectory 'stages\Foundation.json'
        $bytes = [IO.File]::ReadAllBytes($path)
        $text = [Text.UTF8Encoding]::new($false, $true).GetString($bytes)
        switch ($Mutation) {
            'Bom' {
                $bytes = [byte[]]@(0xEF, 0xBB, 0xBF) + $bytes
            }
            'CrLf' {
                $bytes = [Text.UTF8Encoding]::new($false).GetBytes(
                    $text.Replace("`n", "`r`n")
                )
            }
            'ZeroLf' {
                $bytes = [Text.UTF8Encoding]::new($false).GetBytes(
                    $text.TrimEnd("`n")
                )
            }
            'TwoLf' {
                $bytes = [Text.UTF8Encoding]::new($false).GetBytes(
                    $text + "`n"
                )
            }
            'KeyOrder' {
                $bytes = [Text.UTF8Encoding]::new($false).GetBytes(
                    (($set.Results[0] | ConvertTo-Json -Depth 30 -Compress) + "`n")
                )
            }
            'Whitespace' {
                $bytes = [Text.UTF8Encoding]::new($false).GetBytes(
                    (($set.Results[0] | ConvertTo-Json -Depth 30) + "`n")
                )
            }
            'UpperDigest' {
                $value = Copy-CanonicalTestValue $set.Results[0]
                $value.phaseManifestDigest =
                    $value.phaseManifestDigest.ToUpperInvariant()
                $bytes = [Text.UTF8Encoding]::new($false).GetBytes(
                    (
                        ConvertTo-TenantLifecycleCanonicalJson `
                            -InputObject $value
                    )
                )
            }
            'Malformed' {
                $bytes = [Text.UTF8Encoding]::new($false).GetBytes("{`"x`":`n")
            }
            'Array' {
                $bytes = [Text.UTF8Encoding]::new($false).GetBytes("[]`n")
            }
            'Additional' {
                $value = Copy-CanonicalTestValue $set.Results[0]
                $value | Add-Member -NotePropertyName providerId -NotePropertyValue private
                $bytes = [Text.UTF8Encoding]::new($false).GetBytes(
                    (
                        ConvertTo-TenantLifecycleCanonicalJson `
                            -InputObject $value
                    )
                )
            }
            'Duplicate' {
                $duplicate = (
                    '{"schemaVersion":"1.0",' +
                    $text.Substring(1)
                )
                $bytes = [Text.UTF8Encoding]::new($false).GetBytes($duplicate)
            }
        }
        [IO.File]::WriteAllBytes($path, $bytes)

        {
            Invoke-CanonicalStageSet `
                -RunDirectory $runDirectory `
                -RunId $runId
        } | Should -Throw
    }

    It 'rejects path traversal and an outside result from canonical stage result reading' {
        $root = Join-Path $TestDrive 'canonical-containment'
        $external = Join-Path $TestDrive 'outside-result.json'
        [IO.Directory]::CreateDirectory($root) | Out-Null
        [IO.File]::WriteAllText(
            $external,
            "{} `n",
            [Text.UTF8Encoding]::new($false)
        )

        InModuleScope Caldova.HrFrontier.Bootstrap -Parameters @{
            Root = $root
            External = $external
        } {
            param($Root, $External)

            {
                Read-TenantLifecycleCanonicalJsonFile `
                    -Path $External `
                    -ContainmentRoot $Root `
                    -ExpectedRelativePath '../outside-result.json'
            } | Should -Throw
        }
    }

    It 'detects result file stages directory manifest and summary reparse paths' -ForEach @(
        @{ Target = 'stages' }
        @{ Target = 'stages/Foundation.json' }
        @{ Target = 'phases/Foundation/execution-manifest.json' }
        @{ Target = 'phases/Foundation/summary.json' }
    ) {
        $root = 'C:\synthetic-run'
        $targetPath = Join-Path $root $Target.Replace('/', '\')
        InModuleScope Caldova.HrFrontier.Bootstrap -Parameters @{
            Root = $root
            TargetPath = $targetPath
        } {
            param($Root, $TargetPath)

            $probe = {
                param([string]$Candidate)
                [pscustomobject]@{
                    exists = $true
                    isContainer = -not [IO.Path]::HasExtension($Candidate)
                    attributes = if (
                        [StringComparer]::OrdinalIgnoreCase.Equals(
                            $Candidate,
                            $TargetPath
                        )
                    ) {
                        [IO.FileAttributes]::ReparsePoint
                    }
                    else {
                        [IO.FileAttributes]::Normal
                    }
                }
            }.GetNewClosure()

            Test-TenantLifecycleEvidenceReparsePath `
                -Path $TargetPath `
                -FileSystemProbe $probe |
                Should -BeTrue
        }
    }

    It 'accepts a provider-rich opaque phase summary digest without copying properties' {
        $runId = [guid]::NewGuid()
        $runDirectory = Join-Path $TestDrive 'opaque-phase-summary-digest'
        New-CanonicalStageSet -RunDirectory $runDirectory -RunId $runId |
            Out-Null

        $results = @(
            Invoke-CanonicalStageSet `
                -RunDirectory $runDirectory `
                -RunId $runId
        )

        $results.Count | Should -Be 1
        ($results | ConvertTo-Json -Depth 10) |
            Should -Not -Match 'provider-synthetic|example[.]invalid|action-synthetic|payload|readBack'
    }

    It 'rejects tampered manifest or phase summary digest bytes' -ForEach @(
        @{ Case = 'manifest'; Index = 'ManifestPaths' }
        @{ Case = 'summary'; Index = 'SummaryPaths' }
    ) {
        $runId = [guid]::NewGuid()
        $runDirectory = Join-Path $TestDrive "tampered-$Case-digest"
        $set = New-CanonicalStageSet -RunDirectory $runDirectory -RunId $runId
        $path = [string]$set.$Index[0]
        $value = ConvertFrom-TenantLifecycleJson -InputObject (
            Get-Content -Raw -LiteralPath $path
        )
        $value | Add-Member `
            -NotePropertyName tampered `
            -NotePropertyValue $true
        Write-CanonicalTestFile -InputObject $value -Path $path

        {
            Invoke-CanonicalStageSet `
                -RunDirectory $runDirectory `
                -RunId $runId
        } | Should -Throw
    }

    It 'rejects absolute or wrong-stage phase summary digest paths' -ForEach @(
        @{ Case = 'absolute'; Value = 'C:\outside\summary.json' }
        @{ Case = 'wrong stage'; Value = 'phases/ReadBack/summary.json' }
    ) {
        $runId = [guid]::NewGuid()
        $runDirectory = Join-Path $TestDrive "summary-path-$Case"
        $set = New-CanonicalStageSet -RunDirectory $runDirectory -RunId $runId
        $result = Copy-CanonicalTestValue $set.Results[0]
        $result.evidenceRelativePath = $Value
        Write-CanonicalTestFile `
            -InputObject $result `
            -Path (Join-Path $runDirectory 'stages\Foundation.json')

        {
            Invoke-CanonicalStageSet `
                -RunDirectory $runDirectory `
                -RunId $runId
        } | Should -Throw
    }

    It 'accepts a changed stage state digest chain' {
        $runId = [guid]::NewGuid()
        $runDirectory = Join-Path $TestDrive 'changed-stage-state-digest-chain'
        New-CanonicalStageSet `
            -RunDirectory $runDirectory `
            -RunId $runId `
            -Stages @('Workstation', 'Foundation') `
            -InputStateDigests @(('8' * 64), ('9' * 64)) `
            -OutputStateDigests @(('9' * 64), $script:CanonicalCurrentState) `
            -Classifications @('Changed', 'Changed') |
            Out-Null

        @(
            Invoke-CanonicalStageSet `
                -RunDirectory $runDirectory `
                -RunId $runId `
                -Stages @('Workstation', 'Foundation')
        ).Count | Should -Be 2
    }

    It 'rejects an unexplained or final-current-state mismatch in the stage state digest chain' -ForEach @(
        @{
            Case = 'unexplained'
            Input = @('8' * 64)
            Output = @('9' * 64)
            Classification = @('NoChange')
            Current = '9' * 64
        }
        @{
            Case = 'final current'
            Input = @('8' * 64)
            Output = @('9' * 64)
            Classification = @('Changed')
            Current = '2' * 64
        }
    ) {
        $runId = [guid]::NewGuid()
        $runDirectory = Join-Path $TestDrive "invalid-chain-$Case"
        New-CanonicalStageSet `
            -RunDirectory $runDirectory `
            -RunId $runId `
            -InputStateDigests $Input `
            -OutputStateDigests $Output `
            -Classifications $Classification |
            Out-Null

        {
            Invoke-CanonicalStageSet `
                -RunDirectory $runDirectory `
                -RunId $runId `
                -CurrentStateDigest $Current
        } | Should -Throw
    }
}

Describe 'Tenant lifecycle contracts' {
    BeforeAll {
        $script:RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
        $script:ModulePath = Join-Path $script:RepositoryRoot 'infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1'
        Import-Module $script:ModulePath -Force
        $script:SchemaRoot = Join-Path $script:RepositoryRoot 'infra\src\config\schemas'
        $fixturePath = Join-Path $script:RepositoryRoot 'infra\tests\fixtures\runbooks\tenant-lifecycle.synthetic.json'
        $script:Fixture = ConvertFrom-TenantLifecycleJson -InputObject (
            Get-Content -Raw -LiteralPath $fixturePath
        )
        & python -c 'import jsonschema' 2>&1 | Out-Null
        $script:HasJsonSchema = $LASTEXITCODE -eq 0
        if ($null -eq ('TenantLifecycleContractCodePropertyAccessor' -as [type])) {
            Add-Type -TypeDefinition @'
using System;
using System.Management.Automation;

public static class TenantLifecycleContractCodePropertyAccessor
{
    public static object Get(PSObject instance)
    {
        throw new InvalidOperationException("nested getter executed");
    }
}
'@
        }
        $script:ContractCodePropertyGetter = (
            [TenantLifecycleContractCodePropertyAccessor].GetMethod('Get')
        )

        function Copy-ContractObject {
            param([Parameter(Mandatory)][object]$InputObject)
            ConvertFrom-TenantLifecycleJson -InputObject (
                $InputObject | ConvertTo-Json -Depth 30
            )
        }

        function Invoke-JsonSchemaValidation {
            param(
                [Parameter(Mandatory)][string]$SchemaPath,
                [Parameter(Mandatory)][object]$InputObject
            )
            $json = $InputObject | ConvertTo-Json -Depth 30 -Compress
            $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($json))
            $program = "import base64,json,jsonschema,sys; schema=json.load(open(sys.argv[1],encoding='utf-8')); instance=json.loads(base64.b64decode(sys.argv[2]).decode('utf-8')); jsonschema.Draft202012Validator(schema, format_checker=jsonschema.FormatChecker()).validate(instance)"
            $previousErrorActionPreference = $ErrorActionPreference
            try {
                $ErrorActionPreference = 'Continue'
                $output = & python -c $program $SchemaPath $encoded 2>&1
                $exitCode = $LASTEXITCODE
            }
            finally {
                $ErrorActionPreference = $previousErrorActionPreference
            }
            [pscustomobject]@{
                ExitCode = $exitCode
                Output = ($output -join [Environment]::NewLine)
            }
        }

        function Set-ContractPropertyValue {
            param(
                [Parameter(Mandatory)][object]$InputObject,
                [Parameter(Mandatory)][string]$PropertyPath,
                [Parameter(Mandatory)][AllowNull()][object]$Value
            )
            $segments = @($PropertyPath -split '\.')
            $current = $InputObject
            for ($index = 0; $index -lt ($segments.Count - 1); $index++) {
                $segment = $segments[$index]
                if ($segment -match '^\d+$') {
                    $current = @($current)[[int]$segment]
                }
                else {
                    $current = $current.PSObject.Properties[$segment].Value
                }
            }
            $current.PSObject.Properties[$segments[-1]].Value = $Value
        }

        function Set-ContractDigestUppercase {
            param(
                [Parameter(Mandatory)][object]$InputObject,
                [Parameter(Mandatory)][string]$DigestPath
            )
            if ($DigestPath -eq 'resources.ownedPropertiesDigest') {
                $InputObject.resources[0].ownedPropertiesDigest = 'A' * 64
            }
            else {
                $InputObject.$DigestPath = 'A' * 64
            }
        }
    }

    It 'exports Test-TenantLifecycleContract from the module manifest' {
        Get-Command -Name Test-TenantLifecycleContract -Module Caldova.HrFrontier.Bootstrap -ErrorAction SilentlyContinue |
            Should -Not -BeNullOrEmpty
    }

    It 'enforces an ordinal lifecycle stage as the assessment kind' {
        $schemaPath = Join-Path $script:SchemaRoot (
            'tenant-lifecycle-assessment.schema.json'
        )
        $valid = Copy-ContractObject $script:Fixture.assessment
        $valid.kind = 'Foundation'
        Test-TenantLifecycleContract -Kind Assessment -InputObject $valid |
            Should -BeTrue

        foreach ($invalidKind in @('foundation', 'TenantLifecycle')) {
            $invalid = Copy-ContractObject $valid
            $invalid.kind = $invalidKind
            {
                Test-TenantLifecycleContract `
                    -Kind Assessment `
                    -InputObject $invalid
            } | Should -Throw -ExpectedMessage (
                'TenantLifecycle.Contract.Assessment'
            )
            if ($script:HasJsonSchema) {
                $result = Invoke-JsonSchemaValidation `
                    -SchemaPath $schemaPath `
                    -InputObject $invalid
                $result.ExitCode | Should -Not -Be 0
            }
        }
    }

    It 'declares the exact closed stage result schema contract' {
        $schemaPath = Join-Path $script:SchemaRoot 'tenant-lifecycle-stage-result.schema.json'
        $schemaPath | Should -Exist
        $schema = Get-Content -Raw -LiteralPath $schemaPath | ConvertFrom-Json
        $expectedProperties = @(
            'schemaVersion',
            'runId',
            'stage',
            'sourceCommit',
            'publicTenantKey',
            'intentDigest',
            'stateDigest',
            'phaseManifestDigest',
            'phaseSummaryDigest',
            'status',
            'classification',
            'evidenceRelativePath',
            'completedAtUtc'
        )

        $schema.'$schema' |
            Should -BeExactly 'https://json-schema.org/draft/2020-12/schema'
        $schema.type | Should -BeExactly 'object'
        $schema.additionalProperties | Should -BeFalse
        @($schema.required) -join ',' |
            Should -BeExactly ($expectedProperties -join ',')
        @($schema.properties.PSObject.Properties.Name) -join ',' |
            Should -BeExactly ($expectedProperties -join ',')
        $schema.properties.schemaVersion.const | Should -BeExactly '1.0'
        $schema.properties.publicTenantKey.const | Should -BeExactly 'tenant1'
        $schema.properties.sourceCommit.pattern |
            Should -BeExactly '^[0-9a-fA-F]{40}$'
        foreach ($name in @(
            'intentDigest',
            'stateDigest',
            'phaseManifestDigest',
            'phaseSummaryDigest'
        )) {
            $schema.properties.$name.pattern |
                Should -BeExactly '^[0-9a-f]{64}$'
        }
        $schema.properties.evidenceRelativePath.pattern | Should -BeExactly (
            '^phases/(Workstation|PrivateBoundary|Foundation|DevDelivery|' +
            'ReadBack|Acceptance|TenantReplica)/summary[.]json$'
        )
    }

    It 'enforces stage result schema values and ordinal stage path correlation' {
        $value = Copy-ContractObject $script:Fixture.stageResult
        Test-TenantLifecycleContract -Kind StageResult -InputObject $value |
            Should -BeTrue
        if ($script:HasJsonSchema) {
            $result = Invoke-JsonSchemaValidation `
                -SchemaPath (
                    Join-Path $script:SchemaRoot 'tenant-lifecycle-stage-result.schema.json'
                ) `
                -InputObject $value
            $result.ExitCode | Should -Be 0 -Because $result.Output
        }

        foreach ($invalidPath in @(
            'phases/DevDelivery/summary.json',
            'phases/foundation/summary.json',
            'phases/Foundation/Summary.json',
            'phases/Foundation/summary.json/extra',
            'https://example.invalid/phases/Foundation/summary.json'
        )) {
            $invalid = Copy-ContractObject $script:Fixture.stageResult
            $invalid.evidenceRelativePath = $invalidPath
            {
                Test-TenantLifecycleContract `
                    -Kind StageResult `
                    -InputObject $invalid
            } | Should -Throw -ExpectedMessage 'TenantLifecycle.Contract.StageResult'
        }

        foreach ($invalidTimestamp in @(
            '2026-10-02T12:11:00.0000000Z',
            '2026-10-02t12:11:00.000Z',
            '2026-10-02T12:11:00.000z',
            '2026-10-02T14:11:00.000+02:00'
        )) {
            $invalid = Copy-ContractObject $script:Fixture.stageResult
            $invalid.completedAtUtc = $invalidTimestamp
            {
                Test-TenantLifecycleContract `
                    -Kind StageResult `
                    -InputObject $invalid
            } | Should -Throw -ExpectedMessage 'TenantLifecycle.Contract.StageResult'
        }
    }

    It 'accepts only the seven allowed stage result schema outcome pairs' {
        $allowedPairs = @(
            'Passed/NoChange',
            'Passed/Changed',
            'Failed/NoChange',
            'Failed/Changed',
            'Blocked/Blocked',
            'Refused/Refused',
            'Manual/Manual'
        )
        $schemaPath = Join-Path $script:SchemaRoot 'tenant-lifecycle-stage-result.schema.json'
        foreach ($status in @('Passed', 'Failed', 'Blocked', 'Refused', 'Manual')) {
            foreach ($classification in @(
                'NoChange',
                'Changed',
                'Manual',
                'Blocked',
                'Refused'
            )) {
                $pair = "$status/$classification"
                $value = Copy-ContractObject $script:Fixture.stageResult
                $value.status = $status
                $value.classification = $classification

                if ($allowedPairs -ccontains $pair) {
                    Test-TenantLifecycleContract `
                        -Kind StageResult `
                        -InputObject $value |
                        Should -BeTrue -Because $pair
                    if ($script:HasJsonSchema) {
                        $result = Invoke-JsonSchemaValidation `
                            -SchemaPath $schemaPath `
                            -InputObject $value
                        $result.ExitCode |
                            Should -Be 0 -Because "$pair $($result.Output)"
                    }
                }
                else {
                    {
                        Test-TenantLifecycleContract `
                            -Kind StageResult `
                            -InputObject $value
                    } | Should -Throw `
                        -ExpectedMessage 'TenantLifecycle.Contract.StageResult' `
                        -Because $pair
                    if ($script:HasJsonSchema) {
                        $result = Invoke-JsonSchemaValidation `
                            -SchemaPath $schemaPath `
                            -InputObject $value
                        $result.ExitCode | Should -Not -Be 0 -Because $pair
                    }
                }
            }
        }
    }

    It 'final review JSON loader preserves seven-fraction timestamps and digest parity' {
        Get-Command `
            -Name ConvertFrom-TenantLifecycleJson `
            -Module Caldova.HrFrontier.Bootstrap `
            -ErrorAction SilentlyContinue |
            Should -Not -BeNullOrEmpty

        $timestamp = '2026-10-02T12:05:00.1234567Z'
        $expected = [pscustomobject][ordered]@{
            generatedAtUtc = $timestamp
            nested = [pscustomobject][ordered]@{
                expiresAtUtc = '2026-10-02T12:35:00.7654321Z'
            }
        }
        $json = $expected | ConvertTo-Json -Depth 10 -Compress
        $loaded = ConvertFrom-TenantLifecycleJson -InputObject $json

        $loaded.generatedAtUtc | Should -BeOfType [string]
        $loaded.generatedAtUtc | Should -BeExactly $timestamp
        $loaded.nested.expiresAtUtc | Should -BeOfType [string]
        $loaded.nested.expiresAtUtc |
            Should -BeExactly '2026-10-02T12:35:00.7654321Z'
        $digest = Get-RunbookContentDigest -InputObject $loaded
        $digest | Should -BeExactly (
            Get-RunbookContentDigest -InputObject $expected
        )
        $digest | Should -BeExactly (
            '2337364f33d0681cb791e0a666a2f554' +
            'f4dd2f27e52019e78882473c91484073'
        )
        ConvertTo-TenantLifecycleCanonicalJson -InputObject $loaded |
            Should -BeExactly (
                '{"generatedAtUtc":"2026-10-02T12:05:00.1234567Z",' +
                '"nested":{"expiresAtUtc":' +
                '"2026-10-02T12:35:00.7654321Z"}}' + "`n"
            )
    }

    It 'accepts a complete synthetic <Name> contract at runtime' -TestCases $contractCases {
        param($Kind, $FixtureProperty)
        $value = $script:Fixture.PSObject.Properties[$FixtureProperty].Value
        Test-TenantLifecycleContract -Kind $Kind -InputObject $value | Should -BeTrue
    }

    It 'mirrors the complete synthetic <Name> contract in JSON Schema' -TestCases $contractCases -Skip:(-not $hasJsonSchema) {
        param($FixtureProperty, $SchemaFile)
        $schemaPath = Join-Path $script:SchemaRoot $SchemaFile
        Test-Path -LiteralPath $schemaPath -PathType Leaf | Should -BeTrue
        $value = $script:Fixture.PSObject.Properties[$FixtureProperty].Value
        $result = Invoke-JsonSchemaValidation -SchemaPath $schemaPath -InputObject $value
        $result.ExitCode | Should -Be 0 -Because $result.Output
    }

    It 'rejects an unknown property in <Name> without disclosing its value' -TestCases $contractCases {
        param($Kind, $FixtureProperty)
        $value = Copy-ContractObject $script:Fixture.PSObject.Properties[$FixtureProperty].Value
        $value | Add-Member -NotePropertyName unexpectedProperty -NotePropertyValue 'private-marker-do-not-disclose'
        $message = $null
        try {
            Test-TenantLifecycleContract -Kind $Kind -InputObject $value
        }
        catch {
            $message = $_.Exception.Message
        }
        $message | Should -BeExactly "TenantLifecycle.Contract.$Kind"
        $message | Should -Not -Match 'private-marker'
    }

    It 'final review contract rejects nested <MemberType> without invoking getters' -ForEach @(
        @{ MemberType = 'AliasProperty' }
        @{ MemberType = 'ScriptProperty' }
        @{ MemberType = 'CodeProperty' }
    ) {
        $manifest = Copy-ContractObject $script:Fixture.executionManifest
        $getterInvoked = $false
        switch ($MemberType) {
            'AliasProperty' {
                $manifest.machine.PSObject.Properties.Remove('platform')
                $manifest.machine |
                    Add-Member `
                        -MemberType AliasProperty `
                        -Name platform `
                        -Value machineId
            }
            'ScriptProperty' {
                $manifest.machine |
                    Add-Member `
                        -MemberType ScriptProperty `
                        -Name hiddenRuntimeValue `
                        -Value {
                            $getterInvoked = $true
                            throw 'nested getter executed'
                        }
            }
            'CodeProperty' {
                $manifest.machine |
                    Add-Member `
                        -MemberType CodeProperty `
                        -Name hiddenRuntimeValue `
                        -Value $script:ContractCodePropertyGetter
            }
        }

        {
            Test-TenantLifecycleContract `
                -Kind ExecutionManifest `
                -InputObject $manifest
        } | Should -Throw -ExpectedMessage (
            'TenantLifecycle.Contract.ExecutionManifest'
        )
        $getterInvoked | Should -BeFalse
    }

    It 'rejects a missing required property in <Name>' -TestCases $contractCases {
        param($Kind, $FixtureProperty)
        $value = Copy-ContractObject $script:Fixture.PSObject.Properties[$FixtureProperty].Value
        $value.PSObject.Properties.Remove('schemaVersion')
        { Test-TenantLifecycleContract -Kind $Kind -InputObject $value } |
            Should -Throw -ExpectedMessage "TenantLifecycle.Contract.$Kind"
    }

    It 'rejects null input with the stable <Kind> contract error' -TestCases $contractCases {
        param($Kind)
        { Test-TenantLifecycleContract -Kind $Kind -InputObject $null } |
            Should -Throw -ExpectedMessage "TenantLifecycle.Contract.$Kind"
    }

    It 'rejects a non-lowercase digest in <Name>' -TestCases $contractCases {
        param($Kind, $FixtureProperty, $DigestPath)
        $value = Copy-ContractObject $script:Fixture.PSObject.Properties[$FixtureProperty].Value
        Set-ContractDigestUppercase -InputObject $value -DigestPath $DigestPath
        { Test-TenantLifecycleContract -Kind $Kind -InputObject $value } |
            Should -Throw -ExpectedMessage "TenantLifecycle.Contract.$Kind"
    }

    It 'rejects punctuation in the <Name> status at runtime and in JSON Schema' -TestCases $statusCases {
        param($Kind, $FixtureProperty, $SchemaFile, $FieldPath, $HasJsonSchema)
        $value = Copy-ContractObject $script:Fixture.PSObject.Properties[$FixtureProperty].Value
        Set-ContractPropertyValue -InputObject $value -PropertyPath $FieldPath -Value 'Ready-Now'
        { Test-TenantLifecycleContract -Kind $Kind -InputObject $value } |
            Should -Throw -ExpectedMessage "TenantLifecycle.Contract.$Kind"

        if ($HasJsonSchema) {
            $result = Invoke-JsonSchemaValidation `
                -SchemaPath (Join-Path $script:SchemaRoot $SchemaFile) `
                -InputObject $value
            $result.ExitCode | Should -Not -Be 0
        }
    }

    It 'rejects an overlength <Name> status at runtime and in JSON Schema' -TestCases $statusCases {
        param($Kind, $FixtureProperty, $SchemaFile, $FieldPath, $HasJsonSchema)
        $value = Copy-ContractObject $script:Fixture.PSObject.Properties[$FixtureProperty].Value
        Set-ContractPropertyValue -InputObject $value -PropertyPath $FieldPath -Value ('A' * 65)
        { Test-TenantLifecycleContract -Kind $Kind -InputObject $value } |
            Should -Throw -ExpectedMessage "TenantLifecycle.Contract.$Kind"

        if ($HasJsonSchema) {
            $result = Invoke-JsonSchemaValidation `
                -SchemaPath (Join-Path $script:SchemaRoot $SchemaFile) `
                -InputObject $value
            $result.ExitCode | Should -Not -Be 0
        }
    }

    It 'rejects lowercase z in the <Name> date-time at runtime and in JSON Schema' -TestCases $dateTimeCases {
        param($Kind, $FixtureProperty, $SchemaFile, $FieldPath, $LowercaseValue, $HasJsonSchema)
        $value = Copy-ContractObject $script:Fixture.PSObject.Properties[$FixtureProperty].Value
        Set-ContractPropertyValue -InputObject $value -PropertyPath $FieldPath -Value $LowercaseValue
        { Test-TenantLifecycleContract -Kind $Kind -InputObject $value } |
            Should -Throw -ExpectedMessage "TenantLifecycle.Contract.$Kind"

        if ($HasJsonSchema) {
            $result = Invoke-JsonSchemaValidation `
                -SchemaPath (Join-Path $script:SchemaRoot $SchemaFile) `
                -InputObject $value
            $result.ExitCode | Should -Not -Be 0
        }
    }

    It 'rejects a calendar-invalid <Name> date-time through format validation' -TestCases $dateTimeCases {
        param($Kind, $FixtureProperty, $SchemaFile, $FieldPath, $HasJsonSchema)
        $value = Copy-ContractObject $script:Fixture.PSObject.Properties[$FixtureProperty].Value
        Set-ContractPropertyValue -InputObject $value -PropertyPath $FieldPath -Value '2026-02-30T12:00:00Z'
        { Test-TenantLifecycleContract -Kind $Kind -InputObject $value } |
            Should -Throw -ExpectedMessage "TenantLifecycle.Contract.$Kind"

        if ($HasJsonSchema) {
            $result = Invoke-JsonSchemaValidation `
                -SchemaPath (Join-Path $script:SchemaRoot $SchemaFile) `
                -InputObject $value
            $result.ExitCode | Should -Not -Be 0
        }
    }

    It 'keeps each <Name> schema closed' -TestCases $contractCases -Skip:(-not $hasJsonSchema) {
        param($FixtureProperty, $SchemaFile)
        $schemaPath = Join-Path $script:SchemaRoot $SchemaFile
        Test-Path -LiteralPath $schemaPath -PathType Leaf | Should -BeTrue
        $value = Copy-ContractObject $script:Fixture.PSObject.Properties[$FixtureProperty].Value
        $value | Add-Member -NotePropertyName unexpectedProperty -NotePropertyValue 'synthetic'
        $result = Invoke-JsonSchemaValidation -SchemaPath $schemaPath -InputObject $value
        $result.ExitCode | Should -Not -Be 0
    }

    It 'requires every root field in the <Name> schema' -TestCases $contractCases -Skip:(-not $hasJsonSchema) {
        param($FixtureProperty, $SchemaFile)
        $schemaPath = Join-Path $script:SchemaRoot $SchemaFile
        Test-Path -LiteralPath $schemaPath -PathType Leaf | Should -BeTrue
        $value = Copy-ContractObject $script:Fixture.PSObject.Properties[$FixtureProperty].Value
        $value.PSObject.Properties.Remove('schemaVersion')
        $result = Invoke-JsonSchemaValidation -SchemaPath $schemaPath -InputObject $value
        $result.ExitCode | Should -Not -Be 0
    }

    It 'requires lowercase digests in the <Name> schema' -TestCases $contractCases -Skip:(-not $hasJsonSchema) {
        param($FixtureProperty, $SchemaFile, $DigestPath)
        $schemaPath = Join-Path $script:SchemaRoot $SchemaFile
        Test-Path -LiteralPath $schemaPath -PathType Leaf | Should -BeTrue
        $value = Copy-ContractObject $script:Fixture.PSObject.Properties[$FixtureProperty].Value
        Set-ContractDigestUppercase -InputObject $value -DigestPath $DigestPath
        $result = Invoke-JsonSchemaValidation -SchemaPath $schemaPath -InputObject $value
        $result.ExitCode | Should -Not -Be 0
    }

    It 'rejects duplicate action IDs using ordinal comparison' {
        $manifest = Copy-ContractObject $script:Fixture.executionManifest
        $duplicate = Copy-ContractObject $manifest.actions[0]
        $duplicate.provider = 'AnotherSyntheticProvider'
        $manifest.actions = @($manifest.actions) + @($duplicate)
        { Test-TenantLifecycleContract -Kind ExecutionManifest -InputObject $manifest } |
            Should -Throw -ExpectedMessage 'TenantLifecycle.Contract.ExecutionManifest'
    }

    It 'rejects a state resource without stableId' {
        $state = Copy-ContractObject $script:Fixture.state
        $state.resources[0].PSObject.Properties.Remove('stableId')
        { Test-TenantLifecycleContract -Kind State -InputObject $state } |
            Should -Throw -ExpectedMessage 'TenantLifecycle.Contract.State'

        if ($script:HasJsonSchema) {
            $result = Invoke-JsonSchemaValidation `
                -SchemaPath (Join-Path $script:SchemaRoot 'tenant-lifecycle-state.schema.json') `
                -InputObject $state
            $result.ExitCode | Should -Not -Be 0
        }
    }

    It 'final review state contract permits null stableId for reviewed Create adoption' {
        $state = Copy-ContractObject $script:Fixture.state
        $state.resources[0].stableId = $null

        Test-TenantLifecycleContract -Kind State -InputObject $state |
            Should -BeTrue

        if ($script:HasJsonSchema) {
            $result = Invoke-JsonSchemaValidation `
                -SchemaPath (
                    Join-Path `
                        $script:SchemaRoot `
                        'tenant-lifecycle-state.schema.json'
                ) `
                -InputObject $state
            $result.ExitCode | Should -Be 0 -Because $result.Output
        }
    }

    It 'rejects a classification outside the six-value set' {
        $manifest = Copy-ContractObject $script:Fixture.executionManifest
        $manifest.actions[0].classification = 'Reconcile'
        { Test-TenantLifecycleContract -Kind ExecutionManifest -InputObject $manifest } |
            Should -Throw -ExpectedMessage 'TenantLifecycle.Contract.ExecutionManifest'

        if ($script:HasJsonSchema) {
            $result = Invoke-JsonSchemaValidation `
                -SchemaPath (Join-Path $script:SchemaRoot 'tenant-lifecycle-execution-manifest.schema.json') `
                -InputObject $manifest
            $result.ExitCode | Should -Not -Be 0
        }
    }
}

Describe 'Tenant lifecycle intent and state separation' {
    BeforeAll {
        $script:RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
        $script:ModulePath = Join-Path $script:RepositoryRoot 'infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1'
        Import-Module $script:ModulePath -Force
        $fixturePath = Join-Path $script:RepositoryRoot 'infra\tests\fixtures\runbooks\tenant-lifecycle.synthetic.json'
        $script:Fixture = ConvertFrom-TenantLifecycleJson -InputObject (
            Get-Content -Raw -LiteralPath $fixturePath
        )

        $script:SyntheticRepositoryRoot = Join-Path $TestDrive 'repository'
        $script:SyntheticTenantRoot = Join-Path $script:SyntheticRepositoryRoot 'infra\src\config\tenants'
        $script:IntentPath = Join-Path $script:SyntheticTenantRoot 'tenant1.local.psd1'
        $script:StatePath = Join-Path $script:SyntheticTenantRoot 'tenant1.state.local.json'
        [IO.Directory]::CreateDirectory($script:SyntheticTenantRoot) | Out-Null

        function Copy-LifecycleValue {
            param([Parameter(Mandatory)][object]$InputObject)
            ConvertFrom-TenantLifecycleJson -InputObject (
                $InputObject | ConvertTo-Json -Depth 30
            )
        }

        function Write-SyntheticReviewedIntent {
            param(
                [Parameter(Mandatory)]
                [ValidateSet('Existing', 'Create')]
                [string]$Mode,

                [string]$Provider = 'Synthetic',

                [string]$ResourceType = 'SyntheticResource',

                [string]$LogicalName = 'component-001',

                [string]$Id
            )

            $intent = Get-Content -Raw -LiteralPath (
                Join-Path `
                    $script:RepositoryRoot `
                    'infra\src\config\tenants\_template.psd1'
            )
            $intent = $intent.Replace(
                "TenantAlias = 'example123456'",
                "TenantAlias = 'privatemarker123'"
            )
            $intent = $intent.Replace(
                'bootstrap-example123456',
                'bootstrap-privatemarker123'
            )
            $componentLines = @(
                "        SyntheticResource = @{"
                "            Provider = '$Provider'"
                "            ResourceType = '$ResourceType'"
                "            LogicalName = '$LogicalName'"
                "            Mode = '$Mode'"
            )
            if ($PSBoundParameters.ContainsKey('Id')) {
                $componentLines += "            Id = '$Id'"
            }
            $componentLines += '        }'
            $componentBlock = (
                "    Components = @{$([Environment]::NewLine)" +
                ($componentLines -join [Environment]::NewLine) +
                "$([Environment]::NewLine)    }"
            )
            $intent = $intent.Replace(
                '    Components = @{}',
                $componentBlock
            )
            [IO.File]::WriteAllText(
                $script:IntentPath,
                $intent,
                [Text.UTF8Encoding]::new($false)
            )
        }

        function Reset-SyntheticPrivatePair {
            Write-SyntheticReviewedIntent `
                -Mode Existing `
                -Id 'stable-synthetic-001'
            [IO.File]::WriteAllText(
                $script:StatePath,
                (($script:Fixture.state | ConvertTo-Json -Depth 30 -Compress) + "`n"),
                [Text.UTF8Encoding]::new($false)
            )
        }

        function New-SyntheticGitBoundaryRunner {
            param(
                [Parameter(Mandatory)]
                [AllowEmptyCollection()]
                [Collections.Generic.List[string]]$Calls
            )

            {
                param($FilePath, $ArgumentList)

                $arguments = @($ArgumentList)
                $command = ($arguments | ForEach-Object { [string]$_ }) -join ' '
                [void]$Calls.Add("$FilePath $command")
                $relativeLabel = [string]$arguments[-1]
                if ($command -match ' check-ignore --quiet -- ') {
                    return [pscustomobject]@{ exitCode = 0; stdout = ''; stderr = '' }
                }
                if ($command -match ' ls-files --error-unmatch -- ') {
                    return [pscustomobject]@{ exitCode = 1; stdout = ''; stderr = '' }
                }
                if ($command -match ' status --porcelain=v1 --ignored --untracked-files=all -- ') {
                    return [pscustomobject]@{
                        exitCode = 0
                        stdout = "!! $relativeLabel"
                        stderr = ''
                    }
                }
                throw "Unexpected synthetic Git command: $command"
            }.GetNewClosure()
        }

        function Invoke-SyntheticPrivateBoundary {
            param([Parameter(Mandatory)][scriptblock]$Runner)

            Test-TenantLifecyclePrivateBoundary `
                -PublicTenantKey tenant1 `
                -IntentPath $script:IntentPath `
                -StatePath $script:StatePath `
                -RepositoryRoot $script:SyntheticRepositoryRoot `
                -NativeCommandRunner $Runner
        }
    }

    BeforeEach {
        Reset-SyntheticPrivatePair
    }

    It 'exports the intent state and private-boundary functions' {
        foreach ($name in @(
            'Test-TenantLifecyclePrivateBoundary',
            'Import-TenantLifecycleState',
            'Update-TenantLifecycleState'
        )) {
            Get-Command -Name $name -Module Caldova.HrFrontier.Bootstrap -ErrorAction SilentlyContinue |
                Should -Not -BeNullOrEmpty
        }
    }

    It 'rejects absent private files before invoking Git without leaking paths' {
        Remove-Item -LiteralPath $script:StatePath -Force
        $calls = [Collections.Generic.List[string]]::new()
        $runner = New-SyntheticGitBoundaryRunner -Calls $calls

        $message = try {
            Invoke-SyntheticPrivateBoundary -Runner $runner
            ''
        }
        catch {
            $_.Exception.Message
        }

        $message | Should -BeExactly 'TenantLifecycle.PrivateBoundary.Files'
        $message | Should -Not -Match ([regex]::Escape($script:SyntheticRepositoryRoot))
        $calls.Count | Should -Be 0
    }

    It 'rejects paths outside the exact tenant boundary and the tracked template before invoking Git' {
        $calls = [Collections.Generic.List[string]]::new()
        $runner = New-SyntheticGitBoundaryRunner -Calls $calls
        $outsidePath = Join-Path $script:SyntheticRepositoryRoot 'tenant1.local.psd1'
        Copy-Item -LiteralPath $script:IntentPath -Destination $outsidePath

        {
            Test-TenantLifecyclePrivateBoundary `
                -PublicTenantKey tenant1 `
                -IntentPath $outsidePath `
                -StatePath $script:StatePath `
                -RepositoryRoot $script:SyntheticRepositoryRoot `
                -NativeCommandRunner $runner
        } | Should -Throw -ExpectedMessage 'TenantLifecycle.PrivateBoundary.Path'

        {
            Test-TenantLifecyclePrivateBoundary `
                -PublicTenantKey tenant1 `
                -IntentPath (Join-Path $script:RepositoryRoot 'infra\src\config\tenants\_template.psd1') `
                -StatePath $script:StatePath `
                -RepositoryRoot $script:SyntheticRepositoryRoot `
                -NativeCommandRunner $runner
        } | Should -Throw -ExpectedMessage 'TenantLifecycle.PrivateBoundary.Path'

        $calls.Count | Should -Be 0
    }

    It 'rejects a wrong public tenant key before invoking Git without leaking private values' {
        $intent = Get-Content -Raw -LiteralPath $script:IntentPath
        $intent = $intent.Replace("PublicTenantKey = 'tenant1'", "PublicTenantKey = 'tenant9'")
        [IO.File]::WriteAllText($script:IntentPath, $intent, [Text.UTF8Encoding]::new($false))
        $calls = [Collections.Generic.List[string]]::new()
        $runner = New-SyntheticGitBoundaryRunner -Calls $calls

        $message = try {
            Invoke-SyntheticPrivateBoundary -Runner $runner
            ''
        }
        catch {
            $_.Exception.Message
        }

        $message | Should -BeExactly 'TenantLifecycle.PrivateBoundary.Intent'
        $message | Should -Not -Match 'privatemarker123|tenant9'
        $calls.Count | Should -Be 0
    }

    It 'rejects state-added desired properties and intent classifications' {
        foreach ($propertyName in @('desiredProperties', 'classification')) {
            $state = Copy-LifecycleValue $script:Fixture.state
            $state.resources[0] | Add-Member -NotePropertyName $propertyName -NotePropertyValue 'private-marker'
            [IO.File]::WriteAllText(
                $script:StatePath,
                (($state | ConvertTo-Json -Depth 30 -Compress) + "`n"),
                [Text.UTF8Encoding]::new($false)
            )

            {
                Import-TenantLifecycleState -Path $script:StatePath -PublicTenantKey tenant1
            } | Should -Throw -ExpectedMessage 'TenantLifecycle.State.Invalid'
        }
    }

    It 'rejects a wrong state tenant key and duplicate stable IDs' {
        $wrongKey = Copy-LifecycleValue $script:Fixture.state
        $wrongKey.publicTenantKey = 'tenant9'
        [IO.File]::WriteAllText(
            $script:StatePath,
            (($wrongKey | ConvertTo-Json -Depth 30 -Compress) + "`n"),
            [Text.UTF8Encoding]::new($false)
        )
        {
            Import-TenantLifecycleState -Path $script:StatePath -PublicTenantKey tenant1
        } | Should -Throw -ExpectedMessage 'TenantLifecycle.State.PublicTenantKey'

        $duplicate = Copy-LifecycleValue $script:Fixture.state
        $second = Copy-LifecycleValue $duplicate.resources[0]
        $second.logicalName = 'component-002'
        $duplicate.resources = @($duplicate.resources) + @($second)
        [IO.File]::WriteAllText(
            $script:StatePath,
            (($duplicate | ConvertTo-Json -Depth 30 -Compress) + "`n"),
            [Text.UTF8Encoding]::new($false)
        )
        {
            Import-TenantLifecycleState -Path $script:StatePath -PublicTenantKey tenant1
        } | Should -Throw -ExpectedMessage 'TenantLifecycle.State.Invalid'
    }

    It 'rejects state resources not present in reviewed intent before invoking Git' {
        $state = Copy-LifecycleValue $script:Fixture.state
        $state.resources[0].resourceType = 'UnreviewedResource'
        [IO.File]::WriteAllText(
            $script:StatePath,
            (($state | ConvertTo-Json -Depth 30 -Compress) + "`n"),
            [Text.UTF8Encoding]::new($false)
        )
        $calls = [Collections.Generic.List[string]]::new()
        $runner = New-SyntheticGitBoundaryRunner -Calls $calls

        {
            Invoke-SyntheticPrivateBoundary -Runner $runner
        } | Should -Throw -ExpectedMessage 'TenantLifecycle.PrivateBoundary.State'
        $calls.Count | Should -Be 0
    }

    It 'rejects tracked or inexactly reported private files' {
        $trackedRunner = {
            param($FilePath, $ArgumentList)
            $command = (@($ArgumentList) | ForEach-Object { [string]$_ }) -join ' '
            if ($command -match ' check-ignore --quiet -- ') {
                return [pscustomobject]@{ exitCode = 0; stdout = ''; stderr = '' }
            }
            if ($command -match ' ls-files --error-unmatch -- ') {
                return [pscustomobject]@{ exitCode = 0; stdout = [string]@($ArgumentList)[-1]; stderr = '' }
            }
            return [pscustomobject]@{ exitCode = 0; stdout = ''; stderr = '' }
        }
        {
            Invoke-SyntheticPrivateBoundary -Runner $trackedRunner
        } | Should -Throw -ExpectedMessage 'TenantLifecycle.PrivateBoundary.Git'

        $inexactRunner = {
            param($FilePath, $ArgumentList)
            $command = (@($ArgumentList) | ForEach-Object { [string]$_ }) -join ' '
            if ($command -match ' check-ignore --quiet -- ') {
                return [pscustomobject]@{ exitCode = 0; stdout = ''; stderr = '' }
            }
            if ($command -match ' ls-files --error-unmatch -- ') {
                return [pscustomobject]@{ exitCode = 1; stdout = ''; stderr = '' }
            }
            return [pscustomobject]@{ exitCode = 0; stdout = '!! infra/src/config/tenants/decoy.local.json'; stderr = '' }
        }
        {
            Invoke-SyntheticPrivateBoundary -Runner $inexactRunner
        } | Should -Throw -ExpectedMessage 'TenantLifecycle.PrivateBoundary.Git'
    }

    It 'accepts only the exact ignored and untracked synthetic private pair' {
        $calls = [Collections.Generic.List[string]]::new()
        $runner = New-SyntheticGitBoundaryRunner -Calls $calls

        $result = Invoke-SyntheticPrivateBoundary -Runner $runner

        $result.PSObject.Properties.Name -join ',' |
            Should -BeExactly 'publicTenantKey,intent,state'
        $result.intent.PSObject.Properties.Name -join ',' |
            Should -BeExactly 'label,exists,ignored,tracked,schemaValid,digest'
        $result.state.PSObject.Properties.Name -join ',' |
            Should -BeExactly 'label,exists,ignored,tracked,schemaValid,digest'
        $result.publicTenantKey | Should -BeExactly 'tenant1'
        $result.intent.label | Should -BeExactly 'infra/src/config/tenants/tenant1.local.psd1'
        $result.state.label | Should -BeExactly 'infra/src/config/tenants/tenant1.state.local.json'
        $result.intent.exists | Should -BeTrue
        $result.intent.ignored | Should -BeTrue
        $result.intent.tracked | Should -BeFalse
        $result.intent.schemaValid | Should -BeTrue
        $result.intent.digest | Should -Match '^[0-9a-f]{64}$'
        $result.state.exists | Should -BeTrue
        $result.state.ignored | Should -BeTrue
        $result.state.tracked | Should -BeFalse
        $result.state.schemaValid | Should -BeTrue
        $result.state.digest | Should -Match '^[0-9a-f]{64}$'
        ($result | ConvertTo-Json -Depth 10) |
            Should -Not -Match 'privatemarker123|SyntheticResource|stable-synthetic|repository'

        $calls.Count | Should -Be 6
        @($calls | Where-Object { $_ -match ' check-ignore --quiet -- infra/src/config/tenants/tenant1\.local\.psd1$' }).Count |
            Should -Be 1
        @($calls | Where-Object { $_ -match ' ls-files --error-unmatch -- infra/src/config/tenants/tenant1\.state\.local\.json$' }).Count |
            Should -Be 1
        @($calls | Where-Object { $_ -match ' status --porcelain=v1 --ignored --untracked-files=all -- ' }).Count |
            Should -Be 2
    }

    It 'changes the sanitized intent digest when reviewed intent changes' {
        $firstCalls = [Collections.Generic.List[string]]::new()
        $first = Invoke-SyntheticPrivateBoundary `
            -Runner (New-SyntheticGitBoundaryRunner -Calls $firstCalls)
        $intent = Get-Content -Raw -LiteralPath $script:IntentPath
        $intent = [regex]::Replace(
            $intent,
            "(?m)^\s*DisplayName\s*=\s*'[^']+'\s*$",
            "    DisplayName = 'Reviewed Intent Drift'"
        )
        [IO.File]::WriteAllText(
            $script:IntentPath,
            $intent,
            [Text.UTF8Encoding]::new($false)
        )
        $secondCalls = [Collections.Generic.List[string]]::new()

        $second = Invoke-SyntheticPrivateBoundary `
            -Runner (New-SyntheticGitBoundaryRunner -Calls $secondCalls)

        $second.intent.digest | Should -Not -BeExactly $first.intent.digest
        ($second | ConvertTo-Json -Depth 10) |
            Should -Not -Match 'Reviewed Intent Drift|privatemarker123'
    }

    It 'uses the tracked state ignore rule in the actual repository' {
        $rules = Get-Content -LiteralPath (Join-Path $script:RepositoryRoot '.gitignore')
        $rules | Should -Contain 'infra/src/config/tenants/*.state.local.json'

        & git -C $script:RepositoryRoot check-ignore --quiet -- (
            'infra/src/config/tenants/tenant1.state.local.json'
        )
        $LASTEXITCODE | Should -Be 0
    }

    It 'updates only observed fields for matching Existing reviewed intent' {
        $state = Copy-LifecycleValue $script:Fixture.state
        $verifiedResource = [pscustomobject]@{
            provider = 'Synthetic'
            resourceType = 'SyntheticResource'
            logicalName = 'component-001'
            stableId = 'stable-synthetic-001'
            ownedPropertiesDigest = 'f' * 64
            exactReadBack = $true
        }
        $now = [datetime]::SpecifyKind([datetime]'2026-10-02T14:30:00', [DateTimeKind]::Utc)

        $updated = Update-TenantLifecycleState `
            -State $state `
            -ReviewedIntentPath $script:IntentPath `
            -ReviewedIntentComponentName SyntheticResource `
            -VerifiedResource $verifiedResource `
            -NowUtc $now

        $state.resources[0].stableId | Should -BeExactly 'stable-synthetic-001'
        $updated.resources[0].provider | Should -BeExactly 'Synthetic'
        $updated.resources[0].resourceType | Should -BeExactly 'SyntheticResource'
        $updated.resources[0].logicalName | Should -BeExactly 'component-001'
        $updated.resources[0].stableId | Should -BeExactly 'stable-synthetic-001'
        $updated.resources[0].lastVerifiedAtUtc | Should -BeExactly '2026-10-02T14:30:00.0000000Z'
        $updated.resources[0].ownedPropertiesDigest | Should -BeExactly ('f' * 64)
        Test-TenantLifecycleContract -Kind State -InputObject $updated | Should -BeTrue
    }

    It 'rejects a stable ID change for Existing reviewed intent' {
        $state = Copy-LifecycleValue $script:Fixture.state
        $verifiedResource = [pscustomobject]@{
            provider = 'Synthetic'
            resourceType = 'SyntheticResource'
            logicalName = 'component-001'
            stableId = 'stable-synthetic-002'
            ownedPropertiesDigest = 'f' * 64
            exactReadBack = $true
        }

        {
            Update-TenantLifecycleState `
                -State $state `
                -ReviewedIntentPath $script:IntentPath `
                -ReviewedIntentComponentName SyntheticResource `
                -VerifiedResource $verifiedResource `
                -NowUtc ([datetime]::UtcNow)
        } | Should -Throw -ExpectedMessage 'TenantLifecycle.State.Intent'
    }

    It 'requires the reviewed intent path and rejects an identity mismatch' {
        $state = Copy-LifecycleValue $script:Fixture.state
        $verifiedResource = [pscustomobject]@{
            provider = 'Synthetic'
            resourceType = 'SyntheticResource'
            logicalName = 'component-001'
            stableId = 'stable-synthetic-001'
            ownedPropertiesDigest = 'f' * 64
            exactReadBack = $true
        }

        {
            Update-TenantLifecycleState `
                -State $state `
                -VerifiedResource $verifiedResource `
                -NowUtc ([datetime]::UtcNow)
        } | Should -Throw -ExpectedMessage '*ReviewedIntentPath*'

        Write-SyntheticReviewedIntent `
            -Mode Existing `
            -LogicalName 'component-999' `
            -Id 'stable-synthetic-001'
        {
            Update-TenantLifecycleState `
                -State $state `
                -ReviewedIntentPath $script:IntentPath `
                -ReviewedIntentComponentName SyntheticResource `
                -VerifiedResource $verifiedResource `
                -NowUtc ([datetime]::UtcNow)
        } | Should -Throw -ExpectedMessage 'TenantLifecycle.State.Intent'
    }

    It 'rejects an inexact reviewed intent mode' {
        $state = Copy-LifecycleValue $script:Fixture.state
        $intent = Get-Content -Raw -LiteralPath $script:IntentPath
        $intent = $intent.Replace(
            "            Mode = 'Existing'",
            "            Mode = 'create'"
        )
        [IO.File]::WriteAllText(
            $script:IntentPath,
            $intent,
            [Text.UTF8Encoding]::new($false)
        )
        $verifiedResource = [pscustomobject]@{
            provider = 'Synthetic'
            resourceType = 'SyntheticResource'
            logicalName = 'component-001'
            stableId = 'stable-synthetic-002'
            ownedPropertiesDigest = 'f' * 64
            exactReadBack = $true
        }

        {
            Update-TenantLifecycleState `
                -State $state `
                -ReviewedIntentPath $script:IntentPath `
                -ReviewedIntentComponentName SyntheticResource `
                -VerifiedResource $verifiedResource `
                -NowUtc ([datetime]::UtcNow)
        } | Should -Throw -ExpectedMessage 'TenantLifecycle.State.Intent'
    }

    It 'adopts a verified stable ID only for matching Create reviewed intent' {
        $state = Copy-LifecycleValue $script:Fixture.state
        $state.resources[0].stableId = $null
        Write-SyntheticReviewedIntent -Mode Create
        $unverified = [pscustomobject]@{
            provider = 'Synthetic'
            resourceType = 'SyntheticResource'
            logicalName = 'component-001'
            stableId = 'stable-synthetic-002'
            ownedPropertiesDigest = 'f' * 64
            exactReadBack = $false
        }
        {
            Update-TenantLifecycleState `
                -State $state `
                -ReviewedIntentPath $script:IntentPath `
                -ReviewedIntentComponentName SyntheticResource `
                -VerifiedResource $unverified `
                -NowUtc ([datetime]::UtcNow)
        } | Should -Throw -ExpectedMessage 'TenantLifecycle.State.ReadBack'

        $verified = Copy-LifecycleValue $unverified
        $verified.exactReadBack = $true
        $updated = Update-TenantLifecycleState `
            -State $state `
            -ReviewedIntentPath $script:IntentPath `
            -ReviewedIntentComponentName SyntheticResource `
            -VerifiedResource $verified `
            -NowUtc (
                [datetime]::SpecifyKind(
                    [datetime]'2026-10-02T15:30:00',
                    [DateTimeKind]::Utc
                )
            )

        $state.resources[0].stableId | Should -BeNullOrEmpty
        $updated.resources[0].stableId | Should -BeExactly 'stable-synthetic-002'
        $updated.resources[0].lastVerifiedAtUtc |
            Should -BeExactly '2026-10-02T15:30:00.0000000Z'
        $updated.resources[0].ownedPropertiesDigest | Should -BeExactly ('f' * 64)
    }

    It 'final review adopts null stableId once from the exact reviewed Create component' {
        $state = Copy-LifecycleValue $script:Fixture.state
        $state.resources[0].stableId = $null
        Write-SyntheticReviewedIntent -Mode Create
        $verified = [pscustomobject][ordered]@{
            provider = 'Synthetic'
            resourceType = 'SyntheticResource'
            logicalName = 'component-001'
            stableId = 'stable-synthetic-002'
            ownedPropertiesDigest = 'f' * 64
            exactReadBack = $true
        }
        $updated = Update-TenantLifecycleState `
            -State $state `
            -ReviewedIntentPath $script:IntentPath `
            -ReviewedIntentComponentName SyntheticResource `
            -VerifiedResource $verified `
            -NowUtc (
                [datetime]::SpecifyKind(
                    [datetime]'2026-10-02T15:30:00',
                    [DateTimeKind]::Utc
                )
            )

        $updated.resources[0].stableId |
            Should -BeExactly 'stable-synthetic-002'

        $verified.ownedPropertiesDigest = 'd' * 64
        $refreshed = Update-TenantLifecycleState `
            -State $updated `
            -ReviewedIntentPath $script:IntentPath `
            -ReviewedIntentComponentName SyntheticResource `
            -VerifiedResource $verified `
            -NowUtc (
                [datetime]::SpecifyKind(
                    [datetime]'2026-10-02T16:30:00',
                    [DateTimeKind]::Utc
                )
            )
        $refreshed.resources[0].stableId |
            Should -BeExactly 'stable-synthetic-002'
        $refreshed.resources[0].ownedPropertiesDigest |
            Should -BeExactly ('d' * 64)
    }

    It 'final review keeps every non-null Create stableId immutable' {
        $state = Copy-LifecycleValue $script:Fixture.state
        Write-SyntheticReviewedIntent -Mode Create
        $verified = [pscustomobject][ordered]@{
            provider = 'Synthetic'
            resourceType = 'SyntheticResource'
            logicalName = 'component-001'
            stableId = 'stable-synthetic-002'
            ownedPropertiesDigest = 'f' * 64
            exactReadBack = $true
        }

        {
            Update-TenantLifecycleState `
                -State $state `
                -ReviewedIntentPath $script:IntentPath `
                -ReviewedIntentComponentName SyntheticResource `
                -VerifiedResource $verified `
                -NowUtc ([datetime]::UtcNow)
        } | Should -Throw -ExpectedMessage (
            'TenantLifecycle.State.StableIdImmutable'
        )
    }

    It 'final review rejects caller-asserted identity absent from reviewed intent' {
        $state = Copy-LifecycleValue $script:Fixture.state
        Write-SyntheticReviewedIntent `
            -Mode Existing `
            -Provider OtherProvider `
            -Id 'stable-synthetic-001'
        $verified = [pscustomobject][ordered]@{
            provider = 'Synthetic'
            resourceType = 'SyntheticResource'
            logicalName = 'component-001'
            stableId = 'stable-synthetic-001'
            ownedPropertiesDigest = 'f' * 64
            exactReadBack = $true
        }
        {
            Update-TenantLifecycleState `
                -State $state `
                -ReviewedIntentPath $script:IntentPath `
                -ReviewedIntentComponentName SyntheticResource `
                -VerifiedResource $verified `
                -NowUtc ([datetime]::UtcNow)
        } | Should -Throw -ExpectedMessage 'TenantLifecycle.State.Intent'
    }

    It 'final review private boundary binds the exact reviewed component identity' {
        Write-SyntheticReviewedIntent `
            -Mode Existing `
            -Provider OtherProvider `
            -Id 'stable-synthetic-001'
        $calls = [Collections.Generic.List[string]]::new()

        {
            Invoke-SyntheticPrivateBoundary `
                -Runner (New-SyntheticGitBoundaryRunner -Calls $calls)
        } | Should -Throw -ExpectedMessage (
            'TenantLifecycle.PrivateBoundary.State'
        )
        $calls.Count | Should -Be 0
    }

    It 'final review private boundary permits null stableId only for unadopted Create intent' {
        $state = Copy-LifecycleValue $script:Fixture.state
        $state.resources[0].stableId = $null
        [IO.File]::WriteAllText(
            $script:StatePath,
            (($state | ConvertTo-Json -Depth 30 -Compress) + "`n"),
            [Text.UTF8Encoding]::new($false)
        )
        $existingCalls = [Collections.Generic.List[string]]::new()
        {
            Invoke-SyntheticPrivateBoundary `
                -Runner (
                    New-SyntheticGitBoundaryRunner `
                        -Calls $existingCalls
                )
        } | Should -Throw -ExpectedMessage (
            'TenantLifecycle.PrivateBoundary.State'
        )
        $existingCalls.Count | Should -Be 0

        Write-SyntheticReviewedIntent -Mode Create
        $createCalls = [Collections.Generic.List[string]]::new()
        $boundary = Invoke-SyntheticPrivateBoundary `
            -Runner (
                New-SyntheticGitBoundaryRunner `
                    -Calls $createCalls
            )
        $boundary.state.schemaValid | Should -BeTrue
        $createCalls.Count | Should -Be 6
    }

    It 'refuses state adoption without a pre-existing state resource' {
        $state = Copy-LifecycleValue $script:Fixture.state
        Write-SyntheticReviewedIntent `
            -Mode Create `
            -LogicalName 'component-999'
        $unknown = [pscustomobject]@{
            provider = 'Synthetic'
            resourceType = 'SyntheticResource'
            logicalName = 'component-999'
            stableId = 'stable-synthetic-999'
            ownedPropertiesDigest = 'f' * 64
            exactReadBack = $true
        }

        {
            Update-TenantLifecycleState `
                -State $state `
                -ReviewedIntentPath $script:IntentPath `
                -ReviewedIntentComponentName SyntheticResource `
                -VerifiedResource $unknown `
                -NowUtc ([datetime]::UtcNow)
        } | Should -Throw -ExpectedMessage 'TenantLifecycle.State.Resource'
    }

    It 'rejects fields outside the exact read-back contract' {
        $state = Copy-LifecycleValue $script:Fixture.state
        $state.resources[0].stableId = $null
        Write-SyntheticReviewedIntent -Mode Create
        $classificationChange = [pscustomobject]@{
            provider = 'Synthetic'
            resourceType = 'SyntheticResource'
            logicalName = 'component-001'
            stableId = 'stable-synthetic-002'
            ownedPropertiesDigest = 'f' * 64
            exactReadBack = $true
            classification = 'Manual'
        }

        {
            Update-TenantLifecycleState `
                -State $state `
                -ReviewedIntentPath $script:IntentPath `
                -ReviewedIntentComponentName SyntheticResource `
                -VerifiedResource $classificationChange `
                -NowUtc ([datetime]::UtcNow)
        } | Should -Throw -ExpectedMessage 'TenantLifecycle.State.ReadBack'
    }
}

Describe 'Tenant lifecycle evidence manifest and writer' {
    BeforeAll {
        $script:EvidenceRepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
        $script:EvidenceModulePath = Join-Path $script:EvidenceRepositoryRoot 'infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1'
        Import-Module $script:EvidenceModulePath -Force
        $fixturePath = Join-Path $script:EvidenceRepositoryRoot 'infra\tests\fixtures\runbooks\tenant-lifecycle.synthetic.json'
        $script:EvidenceFixture = ConvertFrom-TenantLifecycleJson -InputObject (
            Get-Content -Raw -LiteralPath $fixturePath
        )

        function Copy-EvidenceValue {
            param([Parameter(Mandatory)][object]$InputObject)
            ConvertFrom-TenantLifecycleJson -InputObject (
                $InputObject | ConvertTo-Json -Depth 30
            )
        }

        function New-EvidenceManifestParameters {
            @{
                RunId = [guid]'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee'
                SourceCommit = 'a' * 40
                EvidenceRoot = 'C:\evidence-root-synthetic'
                PublicTenantKey = 'tenant1'
                IntentDigest = '1' * 64
                StateDigest = '2' * 64
                SelectedStages = [string[]]@('Foundation')
                PrerequisiteResults = [object[]]@()
                Machine = Copy-EvidenceValue $script:EvidenceFixture.executionManifest.machine
                Operator = Copy-EvidenceValue $script:EvidenceFixture.executionManifest.operator
                ToolIdentities = @(Copy-EvidenceValue $script:EvidenceFixture.executionManifest.toolIdentities)
                ProviderContexts = @(Copy-EvidenceValue $script:EvidenceFixture.executionManifest.providerContexts)
                Prerequisites = @(Copy-EvidenceValue $script:EvidenceFixture.executionManifest.prerequisites)
                Actions = @(Copy-EvidenceValue $script:EvidenceFixture.executionManifest.actions)
                GeneratedAtUtc = [datetime]'2026-10-02T12:05:00Z'
                ExpiresAtUtc = [datetime]'2026-10-02T12:35:00Z'
            }
        }
    }

    Describe 'Tenant lifecycle stage-only projection contracts' {
        BeforeEach {
            $script:StageProjectionRunId =
                [guid]'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee'
            $projectionRoot = Join-Path (
                $TestDrive
            ) ([guid]::NewGuid().ToString('N'))
            $script:StageProjectionRunDirectory = Join-Path (
                $projectionRoot
            ) $script:StageProjectionRunId.ToString('D').ToLowerInvariant()
            [IO.Directory]::CreateDirectory(
                $script:StageProjectionRunDirectory
            ) | Out-Null
            $script:StageProjectionOutputPath = Join-Path (
                $script:StageProjectionRunDirectory
            ) 'summary.json'
            $script:StageProjectionResults = @(
                foreach ($stage in @('Foundation', 'ReadBack')) {
                    New-TenantLifecycleStageResult `
                        -RunId $script:StageProjectionRunId `
                        -Stage $stage `
                        -SourceCommit ('a' * 40) `
                        -PublicTenantKey tenant1 `
                        -IntentDigest ('1' * 64) `
                        -StateDigest ('2' * 64) `
                        -PhaseManifestDigest ('3' * 64) `
                        -PhaseSummaryDigest ('4' * 64) `
                        -Status Passed `
                        -Classification NoChange `
                        -EvidenceRelativePath "phases/$stage/summary.json" `
                        -CompletedAtUtc (
                            [datetime]'2026-10-03T08:31:00Z'
                        )
                }
            )

            foreach ($stage in @('Foundation', 'ReadBack')) {
                $phaseDirectory = Join-Path (
                    $script:StageProjectionRunDirectory
                ) "phases\$stage"
                [IO.Directory]::CreateDirectory($phaseDirectory) | Out-Null
                $childSummary = Copy-EvidenceValue (
                    $script:EvidenceFixture.phaseSummary
                )
                $childSummary.stage = $stage
                $childSummary | ConvertTo-Json -Depth 30 |
                    Set-Content `
                        -LiteralPath (
                            Join-Path $phaseDirectory 'summary.json'
                        ) `
                        -Encoding UTF8
            }
        }

        It 'writes an exact ordered stage-only projection' {
            $path = ConvertTo-TenantLifecycleAcceptanceProjection `
                -RunId $script:StageProjectionRunId `
                -PublicTenantKey tenant1 `
                -OrderedStageResults $script:StageProjectionResults `
                -OutputPath $script:StageProjectionOutputPath

            $projection = ConvertFrom-TenantLifecycleJson -InputObject (
                Get-Content -Raw -LiteralPath $path
            )
            (
                @($projection.PSObject.Properties.Name) |
                    Sort-Object
            ) -join ',' | Should -BeExactly (
                'digest,nonClaims,publicTenantKey,runId,' +
                'schemaVersion,stages'
            )
            ($projection.stages.stage -join ',') |
                Should -BeExactly 'Foundation,ReadBack'
            foreach ($stage in @($projection.stages)) {
                (
                    @($stage.PSObject.Properties.Name) |
                        Sort-Object
                ) -join ',' | Should -BeExactly (
                    'classification,intentDigest,phaseManifestDigest,' +
                    'phaseSummaryDigest,sourceCommit,stage,stateDigest,status'
                )
            }
            ($projection.nonClaims -join "`n") | Should -BeExactly (
                "The umbrella did not execute a provider mutation.`n" +
                "Provider approvals and read-back remain child-runbook evidence.`n" +
                'This projection discloses no provider resource identity or raw provider response.'
            )
            $digestInput = [pscustomobject][ordered]@{
                schemaVersion = $projection.schemaVersion
                runId = $projection.runId
                publicTenantKey = $projection.publicTenantKey
                stages = @($projection.stages)
                nonClaims = @($projection.nonClaims)
            }
            $projection.digest | Should -BeExactly (
                Get-RunbookContentDigest -InputObject $digestInput
            )
        }

        It 'excludes projection prohibited provider data and properties' {
            ConvertTo-TenantLifecycleAcceptanceProjection `
                -RunId $script:StageProjectionRunId `
                -PublicTenantKey tenant1 `
                -OrderedStageResults $script:StageProjectionResults `
                -OutputPath $script:StageProjectionOutputPath |
                Out-Null

            $projectionBytes = Get-Content `
                -Raw `
                -LiteralPath $script:StageProjectionOutputPath
            $prohibited = @(
                'tenant-synthetic-001',
                'subscription-synthetic-001',
                'application-synthetic-001',
                'environment-synthetic-001',
                'project-synthetic-001',
                'pipeline-synthetic-001',
                'object-synthetic-001',
                'role-synthetic-001',
                'resource-synthetic-001',
                'https://provider.example.invalid/path?token=synthetic',
                'SyntheticProvider',
                'action-synthetic-001',
                'Create',
                'Update',
                'requestPayload',
                'actionResults',
                'rawReadBack',
                'tenantId',
                'subscriptionId',
                'applicationId',
                'environmentId',
                'projectId',
                'pipelineId',
                'objectId',
                'roleId',
                'resourceId'
            )
            foreach ($value in $prohibited) {
                $projectionBytes | Should -Not -Match ([regex]::Escape($value))
            }
            $prohibitedPropertyNames = @(
                'tenantId',
                'subscriptionId',
                'applicationId',
                'environmentId',
                'projectId',
                'pipelineId',
                'objectId',
                'roleId',
                'resourceId',
                'resourceUrl',
                'provider',
                'actionId',
                'operations',
                'requestPayload',
                'actionResults',
                'rawReadBack'
            )
            $projectionBytes | Should -Not -Match (
                '"(?:' +
                (($prohibitedPropertyNames | ForEach-Object {
                    [regex]::Escape($_)
                }) -join '|') +
                ')"\s*:'
            )

            $invalidResult = Copy-EvidenceValue (
                $script:StageProjectionResults[0]
            )
            $invalidProperties = [ordered]@{
                tenantId = 'tenant-synthetic-001'
                subscriptionId = 'subscription-synthetic-001'
                applicationId = 'application-synthetic-001'
                environmentId = 'environment-synthetic-001'
                projectId = 'project-synthetic-001'
                pipelineId = 'pipeline-synthetic-001'
                objectId = 'object-synthetic-001'
                roleId = 'role-synthetic-001'
                resourceId = 'resource-synthetic-001'
                resourceUrl =
                    'https://provider.example.invalid/path?token=synthetic'
                provider = 'SyntheticProvider'
                actionId = 'action-synthetic-001'
                operations = @('Create', 'Update')
                requestPayload = 'requestPayload'
                actionResults = 'actionResults'
                rawReadBack = 'rawReadBack'
            }
            foreach ($entry in $invalidProperties.GetEnumerator()) {
                $invalidResult | Add-Member `
                    -NotePropertyName $entry.Key `
                    -NotePropertyValue $entry.Value
            }
            $message = try {
                ConvertTo-TenantLifecycleAcceptanceProjection `
                    -RunId $script:StageProjectionRunId `
                    -PublicTenantKey tenant1 `
                    -OrderedStageResults @($invalidResult) `
                    -OutputPath (
                        Join-Path (
                            $script:StageProjectionRunDirectory
                        ) 'invalid-summary.json'
                    )
                'NO-ERROR'
            }
            catch {
                $_.Exception.Message
            }
            $message | Should -Not -BeExactly 'NO-ERROR'
            foreach ($value in @(
                $prohibited +
                $prohibitedPropertyNames
            )) {
                $message | Should -Not -Match ([regex]::Escape($value))
            }

            $parameters = (
                Get-Command ConvertTo-TenantLifecycleAcceptanceProjection
            ).Parameters.Keys
            $parameters | Should -Not -Contain 'AllowedStableIds'
            $parameters | Should -Not -Contain 'AllowedUrlHosts'
        }
    }

    BeforeEach {
        $script:EvidenceRunDirectory = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    }

    It 'exports the evidence manifest approval and writer commands' {
        foreach ($name in @(
            'New-TenantLifecycleExecutionManifest',
            'Test-TenantLifecycleApproval',
            'Write-TenantLifecycleEvidence'
        )) {
            Get-Command -Name $name -Module Caldova.HrFrontier.Bootstrap -ErrorAction SilentlyContinue |
                Should -Not -BeNullOrEmpty
        }
    }

    It 'creates a canonical evidence manifest whose digest binds every accepted input' {
        $parameters = New-EvidenceManifestParameters
        $manifest = New-TenantLifecycleExecutionManifest @parameters
        $repeatParameters = New-EvidenceManifestParameters
        $repeat = New-TenantLifecycleExecutionManifest @repeatParameters

        ($manifest | ConvertTo-Json -Depth 30 -Compress) |
            Should -BeExactly ($repeat | ConvertTo-Json -Depth 30 -Compress)
        Test-TenantLifecycleContract -Kind ExecutionManifest -InputObject $manifest | Should -BeTrue

        $mutations = [ordered]@{
            runId = { param($value) $value.RunId = [guid]'bbbbbbbb-cccc-4ddd-8eee-ffffffffffff' }
            sourceCommit = { param($value) $value.SourceCommit = 'b' * 40 }
            evidenceRoot = { param($value) $value.EvidenceRoot = 'C:\other-evidence-root' }
            intentDigest = { param($value) $value.IntentDigest = '3' * 64 }
            stateDigest = { param($value) $value.StateDigest = '4' * 64 }
            selectedStages = {
                param($value)
                $value.SelectedStages = [string[]]@('Workstation')
            }
            prerequisiteResults = {
                param($value)
                $value.PrerequisiteResults = @(
                    [pscustomobject][ordered]@{
                        stage = 'Workstation'
                        status = 'Passed'
                        classification = 'NoChange'
                        phaseManifestDigest = '3' * 64
                        phaseSummaryDigest = '4' * 64
                        intentDigest = '1' * 64
                        stateDigest = '2' * 64
                    }
                )
            }
            machine = { param($value) $value.Machine.machineId = 'machine-synthetic-002' }
            operator = { param($value) $value.Operator.operatorId = 'operator-synthetic-002' }
            toolIdentities = { param($value) $value.ToolIdentities[0].digest = '5' * 64 }
            providerContexts = { param($value) $value.ProviderContexts[0].digest = '6' * 64 }
            prerequisites = { param($value) $value.Prerequisites[0].evidenceDigest = '8' * 64 }
            actions = { param($value) $value.Actions[0].desiredPropertiesDigest = '7' * 64 }
            generatedAtUtc = { param($value) $value.GeneratedAtUtc = [datetime]'2026-10-02T12:06:00Z' }
            expiresAtUtc = { param($value) $value.ExpiresAtUtc = [datetime]'2026-10-02T12:34:00Z' }
        }

        foreach ($field in $mutations.Keys) {
            $variantParameters = New-EvidenceManifestParameters
            & $mutations[$field] $variantParameters
            $variant = New-TenantLifecycleExecutionManifest @variantParameters
            $variant.digest | Should -Not -BeExactly $manifest.digest -Because "$field must be digest-bound"
        }
    }

    It 'rejects an evidence approval window longer than thirty minutes' {
        $parameters = New-EvidenceManifestParameters
        $parameters.ExpiresAtUtc = [datetime]'2026-10-02T12:35:00.001Z'

        {
            New-TenantLifecycleExecutionManifest @parameters
        } | Should -Throw -ExpectedMessage 'TenantLifecycle.Manifest.Expiry'
    }

    It 'writes every evidence kind only to its exact allowlisted filename' {
        $manifestParameters = New-EvidenceManifestParameters
        $executionManifest = New-TenantLifecycleExecutionManifest @manifestParameters
        $cases = @(
            @{ Kind = 'Assessment'; RelativePath = 'assessment.json'; Input = $script:EvidenceFixture.assessment }
            @{ Kind = 'ExecutionManifest'; RelativePath = 'execution-manifest.json'; Input = $executionManifest }
            @{ Kind = 'Approval'; RelativePath = 'approvals.json'; Input = $script:EvidenceFixture.approval }
            @{ Kind = 'ActionEvidence'; RelativePath = 'actions/action-001.json'; Input = $script:EvidenceFixture.actionEvidence }
            @{ Kind = 'ReadBack'; RelativePath = 'read-back.json'; Input = $script:EvidenceFixture.readBack }
            @{ Kind = 'Summary'; RelativePath = 'summary.json'; Input = $script:EvidenceFixture.summary }
        )

        foreach ($case in $cases) {
            $path = Write-TenantLifecycleEvidence `
                -RunDirectory $script:EvidenceRunDirectory `
                -RelativePath $case.RelativePath `
                -Kind $case.Kind `
                -InputObject (Copy-EvidenceValue $case.Input)

            $path | Should -BeExactly ([IO.Path]::GetFullPath((Join-Path $script:EvidenceRunDirectory $case.RelativePath.Replace('/', '\'))))
            Test-Path -LiteralPath $path -PathType Leaf | Should -BeTrue
        }

        {
            Write-TenantLifecycleEvidence `
                -RunDirectory $script:EvidenceRunDirectory `
                -RelativePath 'other-summary.json' `
                -Kind Summary `
                -InputObject (Copy-EvidenceValue $script:EvidenceFixture.summary)
        } | Should -Throw -ExpectedMessage 'TenantLifecycle.Evidence.Path'
    }

    It 'final review refuses private state as run evidence' {
        $privateStateEvidenceName = 'state' + '.json'
        {
            Write-TenantLifecycleEvidence `
                -RunDirectory $script:EvidenceRunDirectory `
                -RelativePath $privateStateEvidenceName `
                -Kind State `
                -InputObject (
                    Copy-EvidenceValue $script:EvidenceFixture.state
                )
        } | Should -Throw
        Join-Path $script:EvidenceRunDirectory $privateStateEvidenceName |
            Should -Not -Exist
    }

    It 'rejects a digest-stale evidence manifest before writing any bytes' {
        $manifestParameters = New-EvidenceManifestParameters
        $manifest = New-TenantLifecycleExecutionManifest @manifestParameters
        $manifest.sourceCommit = 'b' * 40

        {
            Write-TenantLifecycleEvidence `
                -RunDirectory $script:EvidenceRunDirectory `
                -RelativePath 'execution-manifest.json' `
                -Kind ExecutionManifest `
                -InputObject $manifest
        } | Should -Throw -ExpectedMessage 'TenantLifecycle.Evidence.Invalid'

        Test-Path -LiteralPath (Join-Path $script:EvidenceRunDirectory 'execution-manifest.json') |
            Should -BeFalse
    }

    It 'writes canonical UTF-8 evidence with no BOM one LF and repeatable bytes' {
        $firstRun = Join-Path $TestDrive 'canonical-first'
        $secondRun = Join-Path $TestDrive 'canonical-second'
        $input = Copy-EvidenceValue $script:EvidenceFixture.assessment

        $firstPath = Write-TenantLifecycleEvidence -RunDirectory $firstRun -RelativePath 'assessment.json' -Kind Assessment -InputObject $input
        $secondPath = Write-TenantLifecycleEvidence -RunDirectory $secondRun -RelativePath 'assessment.json' -Kind Assessment -InputObject (Copy-EvidenceValue $input)
        $firstBytes = [IO.File]::ReadAllBytes($firstPath)
        $secondBytes = [IO.File]::ReadAllBytes($secondPath)
        $text = [Text.UTF8Encoding]::new($false, $true).GetString($firstBytes)

        [Convert]::ToBase64String($firstBytes) | Should -BeExactly ([Convert]::ToBase64String($secondBytes))
        ($firstBytes[0..2] -join ',') | Should -Not -BeExactly '239,187,191'
        $firstBytes[-1] | Should -Be 10
        $text.TrimEnd("`n").Contains("`n") | Should -BeFalse
        $text.Contains("`r") | Should -BeFalse
        @(Get-ChildItem -LiteralPath $firstRun -Recurse -Filter '*.tmp').Count | Should -Be 0
        @(Get-ChildItem -LiteralPath $secondRun -Recurse -Filter '*.tmp').Count | Should -Be 0
    }

    It 'leaves no partial evidence or temporary file when validation fails' {
        $invalid = Copy-EvidenceValue $script:EvidenceFixture.assessment
        $invalid | Add-Member -NotePropertyName rawCommandOutput -NotePropertyValue 'private-marker-do-not-disclose'
        $message = try {
            Write-TenantLifecycleEvidence `
                -RunDirectory $script:EvidenceRunDirectory `
                -RelativePath 'assessment.json' `
                -Kind Assessment `
                -InputObject $invalid
            ''
        }
        catch {
            $_.Exception.Message
        }

        $message | Should -BeExactly 'TenantLifecycle.Evidence.Invalid'
        $message | Should -Not -Match 'private-marker'
        Test-Path -LiteralPath (Join-Path $script:EvidenceRunDirectory 'assessment.json') | Should -BeFalse
        if (Test-Path -LiteralPath $script:EvidenceRunDirectory) {
            @(Get-ChildItem -LiteralPath $script:EvidenceRunDirectory -Recurse -File).Count | Should -Be 0
        }
    }

    It 'never overwrites a completed action evidence envelope' {
        $path = Write-TenantLifecycleEvidence `
            -RunDirectory $script:EvidenceRunDirectory `
            -RelativePath 'actions/action-001.json' `
            -Kind ActionEvidence `
            -InputObject (Copy-EvidenceValue $script:EvidenceFixture.actionEvidence)
        $before = [IO.File]::ReadAllBytes($path)
        $changed = Copy-EvidenceValue $script:EvidenceFixture.actionEvidence
        $changed.recovery = 'Reassess'

        {
            Write-TenantLifecycleEvidence `
                -RunDirectory $script:EvidenceRunDirectory `
                -RelativePath 'actions/action-001.json' `
                -Kind ActionEvidence `
                -InputObject $changed
        } | Should -Throw -ExpectedMessage 'TenantLifecycle.Evidence.Exists'

        [Convert]::ToBase64String([IO.File]::ReadAllBytes($path)) |
            Should -BeExactly ([Convert]::ToBase64String($before))
        @(Get-ChildItem -LiteralPath (Split-Path -Parent $path) -Filter '*.tmp').Count | Should -Be 0
    }

    It 'rejects evidence path traversal outside the run directory' {
        {
            Write-TenantLifecycleEvidence `
                -RunDirectory $script:EvidenceRunDirectory `
                -RelativePath '..\assessment.json' `
                -Kind Assessment `
                -InputObject (Copy-EvidenceValue $script:EvidenceFixture.assessment)
        } | Should -Throw -ExpectedMessage 'TenantLifecycle.Evidence.Path'

        Test-Path -LiteralPath (Join-Path (Split-Path -Parent $script:EvidenceRunDirectory) 'assessment.json') |
            Should -BeFalse
    }

    It 'normalizes an evidence root that is a file without leaking its path' {
        [IO.File]::WriteAllText($script:EvidenceRunDirectory, 'private-root-marker')

        $message = try {
            Write-TenantLifecycleEvidence `
                -RunDirectory $script:EvidenceRunDirectory `
                -RelativePath 'assessment.json' `
                -Kind Assessment `
                -InputObject (Copy-EvidenceValue $script:EvidenceFixture.assessment)
            ''
        }
        catch {
            $_.Exception.Message
        }

        $message | Should -BeExactly 'TenantLifecycle.Evidence.Root'
        $message | Should -Not -Match 'private-root-marker'
        [IO.File]::ReadAllText($script:EvidenceRunDirectory) | Should -BeExactly 'private-root-marker'
    }

    It 'normalizes inaccessible evidence root metadata without leaking the provider error' {
        [IO.Directory]::CreateDirectory($script:EvidenceRunDirectory) | Out-Null
        Mock -CommandName Get-Item -ModuleName Caldova.HrFrontier.Bootstrap -MockWith {
            throw [UnauthorizedAccessException]::new('private-access-marker')
        }

        $message = try {
            Write-TenantLifecycleEvidence `
                -RunDirectory $script:EvidenceRunDirectory `
                -RelativePath 'assessment.json' `
                -Kind Assessment `
                -InputObject (Copy-EvidenceValue $script:EvidenceFixture.assessment)
            ''
        }
        catch {
            $_.Exception.Message
        }

        $message | Should -BeExactly 'TenantLifecycle.Evidence.Root'
        $message | Should -Not -Match 'private-access-marker'
        Test-Path -LiteralPath (Join-Path $script:EvidenceRunDirectory 'assessment.json') |
            Should -BeFalse
    }

    It 'normalizes a malformed evidence root without leaking its value' {
        $malformedRoot = "$TestDrive\private-malformed-marker$([char]0)"
        $message = try {
            Write-TenantLifecycleEvidence `
                -RunDirectory $malformedRoot `
                -RelativePath 'assessment.json' `
                -Kind Assessment `
                -InputObject (Copy-EvidenceValue $script:EvidenceFixture.assessment)
            ''
        }
        catch {
            $_.Exception.Message
        }

        $message | Should -BeExactly 'TenantLifecycle.Evidence.Root'
        $message | Should -Not -Match 'private-malformed-marker'
    }

    It 'normalizes an action directory creation failure without leaking its path' {
        [IO.Directory]::CreateDirectory($script:EvidenceRunDirectory) | Out-Null
        $actionDirectory = Join-Path $script:EvidenceRunDirectory 'actions'
        [IO.File]::WriteAllText($actionDirectory, 'private-action-marker')

        $message = try {
            Write-TenantLifecycleEvidence `
                -RunDirectory $script:EvidenceRunDirectory `
                -RelativePath 'actions/action-001.json' `
                -Kind ActionEvidence `
                -InputObject (Copy-EvidenceValue $script:EvidenceFixture.actionEvidence)
            ''
        }
        catch {
            $_.Exception.Message
        }

        $message | Should -BeExactly 'TenantLifecycle.Evidence.ActionDirectory'
        $message | Should -Not -Match 'private-action-marker'
        [IO.File]::ReadAllText($actionDirectory) | Should -BeExactly 'private-action-marker'
    }

    It 'rejects hidden evidence properties without evaluating them or disclosing their error' {
        $hidden = Copy-EvidenceValue $script:EvidenceFixture.actionEvidence
        $hidden.PSObject.Properties.Remove('actionId')
        $hidden | Add-Member -MemberType ScriptProperty -Name actionId -Value {
            throw 'hidden getter executed'
        }

        $message = try {
            Write-TenantLifecycleEvidence `
                -RunDirectory $script:EvidenceRunDirectory `
                -RelativePath 'actions/action-001.json' `
                -Kind ActionEvidence `
                -InputObject $hidden
            ''
        }
        catch {
            $_.Exception.Message
        }

        $message | Should -BeExactly 'TenantLifecycle.Evidence.Invalid'
        $message | Should -Not -Match 'hidden getter'
        Test-Path -LiteralPath $script:EvidenceRunDirectory | Should -BeFalse
    }

    It 'rejects a reparse-point evidence root' {
        $realRoot = Join-Path $TestDrive 'real-evidence-root'
        $reparseRoot = Join-Path $TestDrive 'linked-evidence-root'
        $nestedRoot = Join-Path $reparseRoot 'run'
        [IO.Directory]::CreateDirectory($realRoot) | Out-Null
        New-Item -ItemType Junction -Path $reparseRoot -Target $realRoot | Out-Null
        try {
            {
                Write-TenantLifecycleEvidence `
                    -RunDirectory $nestedRoot `
                    -RelativePath 'assessment.json' `
                    -Kind Assessment `
                    -InputObject (Copy-EvidenceValue $script:EvidenceFixture.assessment)
            } | Should -Throw -ExpectedMessage 'TenantLifecycle.Evidence.ReparsePoint'
        }
        finally {
            $unexpectedRun = Join-Path $realRoot 'run'
            if (Test-Path -LiteralPath $unexpectedRun) {
                Remove-Item -LiteralPath $unexpectedRun -Recurse -Force
            }
            if (Test-Path -LiteralPath $reparseRoot) {
                Remove-Item -LiteralPath $reparseRoot -Force
            }
        }

        @(Get-ChildItem -LiteralPath $realRoot -Force).Count | Should -Be 0
    }
}
