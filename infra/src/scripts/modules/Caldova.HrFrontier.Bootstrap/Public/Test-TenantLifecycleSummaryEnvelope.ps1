function Test-TenantLifecycleSummaryEnvelope {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][string]$RunDirectory,
        [Parameter(Mandatory)][guid]$RunId,
        [Parameter(Mandatory)]
        [ValidateSet(
            'Workstation',
            'PrivateBoundary',
            'Foundation',
            'DevDelivery',
            'ReadBack',
            'Acceptance',
            'TenantReplica'
        )]
        [string]$Stage,
        [Parameter(Mandatory)]
        [ValidatePattern('^[0-9a-f]{40}$')]
        [string]$SourceCommit,
        [Parameter(Mandatory)]
        [ValidateSet('tenant1')]
        [string]$PublicTenantKey,
        [Parameter(Mandatory)]
        [ValidatePattern('^[0-9a-f]{64}$')]
        [string]$IntentDigest,
        [Parameter(Mandatory)][object]$StageResult
    )

    try {
        Test-TenantLifecycleContract `
            -Kind StageResult `
            -InputObject $StageResult |
            Out-Null
    }
    catch {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.SummaryEnvelope.StageResult.Invalid'
        )
    }

    $runIdText = $RunId.ToString('D').ToLowerInvariant()
    $expectedSummaryRelativePath = "phases/$Stage/summary.json"
    if (-not [StringComparer]::Ordinal.Equals(
            [string]$StageResult.runId,
            $runIdText
        ) -or
        -not [StringComparer]::Ordinal.Equals(
            [string]$StageResult.stage,
            $Stage
        ) -or
        -not [StringComparer]::Ordinal.Equals(
            [string]$StageResult.sourceCommit,
            $SourceCommit
        ) -or
        -not [StringComparer]::Ordinal.Equals(
            [string]$StageResult.publicTenantKey,
            $PublicTenantKey
        ) -or
        -not [StringComparer]::Ordinal.Equals(
            [string]$StageResult.intentDigest,
            $IntentDigest
        ) -or
        -not [StringComparer]::Ordinal.Equals(
            [string]$StageResult.evidenceRelativePath,
            $expectedSummaryRelativePath
        )) {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.SummaryEnvelope.StageResult.Invalid'
        )
    }

    $manifestRelativePath =
        "phases/$Stage/execution-manifest.json"
    try {
        $manifestPath = Join-Path $RunDirectory (
            $manifestRelativePath.Replace(
                '/',
                [IO.Path]::DirectorySeparatorChar
            )
        )
        $manifestRecord = Read-TenantLifecycleCanonicalJsonFile `
            -Path $manifestPath `
            -ContainmentRoot $RunDirectory `
            -ExpectedRelativePath $manifestRelativePath `
            -ExpectedDigest ([string]$StageResult.phaseManifestDigest) `
            -ContractKind ExecutionManifest
        $manifest = $manifestRecord.value
    }
    catch {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.SummaryEnvelope.Manifest.FileInvalid'
        )
    }

    try {
        $calculatedManifestDigest =
            Get-TenantLifecycleExecutionManifestDigest `
                -Manifest $manifest
    }
    catch {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.SummaryEnvelope.' +
            'Manifest.EmbeddedDigestMismatch'
        )
    }
    if (-not [StringComparer]::Ordinal.Equals(
            [string]$manifest.digest,
            [string]$calculatedManifestDigest
        )) {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.SummaryEnvelope.' +
            'Manifest.EmbeddedDigestMismatch'
        )
    }

    if (-not [StringComparer]::Ordinal.Equals(
            [string]$manifest.runId,
            $runIdText
        )) {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.SummaryEnvelope.runId.Mismatch'
        )
    }
    if (-not [StringComparer]::Ordinal.Equals(
            [string]$manifest.sourceCommit,
            $SourceCommit
        )) {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.SummaryEnvelope.sourceCommit.Mismatch'
        )
    }
    if (-not [StringComparer]::Ordinal.Equals(
            [string]$manifest.publicTenantKey,
            $PublicTenantKey
        )) {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.SummaryEnvelope.publicTenantKey.Mismatch'
        )
    }
    if (-not [StringComparer]::Ordinal.Equals(
            [string]$manifest.intentDigest,
            $IntentDigest
        )) {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.SummaryEnvelope.intentDigest.Mismatch'
        )
    }

    try {
        $summaryPath = Join-Path $RunDirectory (
            $expectedSummaryRelativePath.Replace(
                '/',
                [IO.Path]::DirectorySeparatorChar
            )
        )
        $summaryRecord = Read-TenantLifecycleCanonicalJsonFile `
            -Path $summaryPath `
            -ContainmentRoot $RunDirectory `
            -ExpectedRelativePath $expectedSummaryRelativePath `
            -ExpectedDigest ([string]$StageResult.phaseSummaryDigest) `
            -ContractKind Summary
        $summary = $summaryRecord.value
        if (-not (Test-TenantLifecycleEvidencePropertyBoundary `
                -Value $summary)) {
            throw [IO.InvalidDataException]::new()
        }
    }
    catch {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.SummaryEnvelope.Summary.FileInvalid'
        )
    }

    if ([string]$summary.schemaVersion -cne '1.0') {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.SummaryEnvelope.schemaVersion.Mismatch'
        )
    }
    if (-not [StringComparer]::Ordinal.Equals(
            [string]$summary.runId,
            [string]$StageResult.runId
        ) -or
        -not [StringComparer]::Ordinal.Equals(
            [string]$summary.runId,
            $runIdText
        )) {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.SummaryEnvelope.runId.Mismatch'
        )
    }
    if (-not [StringComparer]::Ordinal.Equals(
            [string]$summary.stage,
            [string]$StageResult.stage
        ) -or
        -not [StringComparer]::Ordinal.Equals(
            [string]$summary.stage,
            $Stage
        )) {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.SummaryEnvelope.stage.Mismatch'
        )
    }
    if (-not [StringComparer]::Ordinal.Equals(
            [string]$summary.sourceCommit,
            [string]$StageResult.sourceCommit
        ) -or
        -not [StringComparer]::Ordinal.Equals(
            [string]$summary.sourceCommit,
            $SourceCommit
        )) {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.SummaryEnvelope.sourceCommit.Mismatch'
        )
    }
    if (-not [StringComparer]::Ordinal.Equals(
            [string]$summary.publicTenantKey,
            [string]$StageResult.publicTenantKey
        ) -or
        -not [StringComparer]::Ordinal.Equals(
            [string]$summary.publicTenantKey,
            $PublicTenantKey
        )) {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.SummaryEnvelope.publicTenantKey.Mismatch'
        )
    }
    if (-not [StringComparer]::Ordinal.Equals(
            [string]$summary.intentDigest,
            [string]$StageResult.intentDigest
        ) -or
        -not [StringComparer]::Ordinal.Equals(
            [string]$summary.intentDigest,
            $IntentDigest
        )) {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.SummaryEnvelope.intentDigest.Mismatch'
        )
    }
    if (-not [StringComparer]::Ordinal.Equals(
            [string]$summary.stateDigest,
            [string]$StageResult.stateDigest
        )) {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.SummaryEnvelope.stateDigest.Mismatch'
        )
    }
    if (-not [StringComparer]::Ordinal.Equals(
            [string]$summary.phaseManifestDigest,
            [string]$StageResult.phaseManifestDigest
        )) {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.SummaryEnvelope.phaseManifestDigest.Mismatch'
        )
    }
    if (-not [StringComparer]::Ordinal.Equals(
            [string]$summary.status,
            [string]$StageResult.status
        )) {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.SummaryEnvelope.status.Mismatch'
        )
    }
    if (-not [StringComparer]::Ordinal.Equals(
            [string]$summary.classification,
            [string]$StageResult.classification
        )) {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.SummaryEnvelope.classification.Mismatch'
        )
    }
    if (-not [StringComparer]::Ordinal.Equals(
            [string]$summary.completedAtUtc,
            [string]$StageResult.completedAtUtc
        )) {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.SummaryEnvelope.completedAtUtc.Mismatch'
        )
    }

    $closedPrerequisiteResults =
        [Collections.Generic.List[object]]::new()
    foreach ($prerequisite in @($manifest.prerequisiteResults)) {
        $closedPrerequisiteResults.Add(
            [pscustomobject][ordered]@{
                stage = [string]$prerequisite.stage
                status = [string]$prerequisite.status
                classification = [string]$prerequisite.classification
                phaseManifestDigest =
                    [string]$prerequisite.phaseManifestDigest
                phaseSummaryDigest =
                    [string]$prerequisite.phaseSummaryDigest
                intentDigest = [string]$prerequisite.intentDigest
                stateDigest = [string]$prerequisite.stateDigest
            }
        )
    }

    [pscustomobject][ordered]@{
        stage = [string]$Stage
        manifestStateDigest = [string]$manifest.stateDigest
        selectedStages = [string[]]@($manifest.selectedStages)
        prerequisiteResults =
            [object[]]@($closedPrerequisiteResults.ToArray())
    }
}
