function New-TenantLifecycleStageResult {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
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
        [ValidatePattern('^[0-9a-fA-F]{40}$')]
        [string]$SourceCommit,
        [Parameter(Mandatory)]
        [ValidateSet('tenant1')]
        [string]$PublicTenantKey,
        [Parameter(Mandatory)]
        [ValidatePattern('^[0-9a-f]{64}$')]
        [string]$IntentDigest,
        [Parameter(Mandatory)]
        [ValidatePattern('^[0-9a-f]{64}$')]
        [string]$StateDigest,
        [Parameter(Mandatory)]
        [ValidatePattern('^[0-9a-f]{64}$')]
        [string]$PhaseManifestDigest,
        [Parameter(Mandatory)]
        [ValidatePattern('^[0-9a-f]{64}$')]
        [string]$PhaseSummaryDigest,
        [Parameter(Mandatory)]
        [ValidateSet('Passed', 'Failed', 'Blocked', 'Refused', 'Manual')]
        [string]$Status,
        [Parameter(Mandatory)]
        [ValidateSet('NoChange', 'Changed', 'Manual', 'Blocked', 'Refused')]
        [string]$Classification,
        [Parameter(Mandatory)]
        [string]$EvidenceRelativePath,
        [Parameter(Mandatory)]
        [datetime]$CompletedAtUtc
    )

    $expectedEvidenceRelativePath = "phases/$Stage/summary.json"
    if (-not [StringComparer]::Ordinal.Equals(
            $EvidenceRelativePath,
            $expectedEvidenceRelativePath
        )) {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.StageResult.Invalid'
        )
    }

    $completed = if ($CompletedAtUtc.Kind -eq [DateTimeKind]::Unspecified) {
        [DateTime]::SpecifyKind($CompletedAtUtc, [DateTimeKind]::Utc)
    }
    else {
        $CompletedAtUtc.ToUniversalTime()
    }
    $candidate = [pscustomobject][ordered]@{
        schemaVersion = '1.0'
        runId = $RunId.ToString('D').ToLowerInvariant()
        stage = $Stage
        sourceCommit = $SourceCommit.ToLowerInvariant()
        publicTenantKey = $PublicTenantKey
        intentDigest = $IntentDigest
        stateDigest = $StateDigest
        phaseManifestDigest = $PhaseManifestDigest
        phaseSummaryDigest = $PhaseSummaryDigest
        status = $Status
        classification = $Classification
        evidenceRelativePath = $EvidenceRelativePath
        completedAtUtc = $completed.ToString(
            "yyyy-MM-dd'T'HH:mm:ss.fff'Z'",
            [Globalization.CultureInfo]::InvariantCulture
        )
    }

    try {
        Test-TenantLifecycleContract `
            -Kind StageResult `
            -InputObject $candidate |
            Out-Null
    }
    catch {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.StageResult.Invalid'
        )
    }
    $candidate
}
