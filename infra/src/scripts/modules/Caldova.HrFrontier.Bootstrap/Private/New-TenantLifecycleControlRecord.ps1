function New-TenantLifecycleControlRecord {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)][guid]$RunId,
        [Parameter(Mandatory)]
        [ValidatePattern('^[0-9a-fA-F]{40}$')]
        [string]$SourceCommit,
        [Parameter(Mandatory)]
        [ValidatePattern('^tenant[1-9][0-9]*$')]
        [string]$PublicTenantKey,
        [Parameter(Mandatory)]
        [ValidatePattern('^[0-9a-f]{64}$')]
        [string]$IntentDigest,
        [Parameter(Mandatory)]
        [ValidatePattern('^[0-9a-f]{64}$')]
        [string]$StateDigest,
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$SelectedStages,
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$PrerequisiteResults,
        [Parameter(Mandatory)]
        [string]$EvidenceRunRelativePath
    )

    $knownStages = @(
        'Workstation',
        'PrivateBoundary',
        'Foundation',
        'DevDelivery',
        'ReadBack',
        'Acceptance',
        'TenantReplica'
    )
    $seenStages = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::Ordinal
    )
    $lastStageIndex = -1
    foreach ($selectedStage in @($SelectedStages)) {
        $stageIndex = -1
        for ($index = 0; $index -lt $knownStages.Count; $index++) {
            if ([StringComparer]::Ordinal.Equals(
                    $knownStages[$index],
                    $selectedStage
                )) {
                $stageIndex = $index
                break
            }
        }
        if ($stageIndex -lt 0 -or
            $stageIndex -le $lastStageIndex -or
            -not $seenStages.Add($selectedStage)) {
            throw [IO.InvalidDataException]::new(
                'TenantLifecycle.ControlRecord.Invalid'
            )
        }
        $lastStageIndex = $stageIndex
    }

    $runIdText = $RunId.ToString('D').ToLowerInvariant()
    if ([IO.Path]::IsPathRooted($EvidenceRunRelativePath) -or
        $EvidenceRunRelativePath.Contains('/') -or
        $EvidenceRunRelativePath.Contains('\') -or
        -not [StringComparer]::Ordinal.Equals(
            $runIdText,
            $EvidenceRunRelativePath
        )) {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.ControlRecord.Invalid'
        )
    }

    $safePrerequisites = [Collections.Generic.List[object]]::new()
    foreach ($prerequisite in @($PrerequisiteResults)) {
        try {
            Test-TenantLifecycleContract `
                -Kind StageResult `
                -InputObject $prerequisite |
                Out-Null
        }
        catch {
            throw [IO.InvalidDataException]::new(
                'TenantLifecycle.ControlRecord.Invalid'
            )
        }
        if ([string]$prerequisite.status -cne 'Passed' -or
            [string]$prerequisite.classification -cnotin @(
                'NoChange',
                'Changed'
            )) {
            throw [IO.InvalidDataException]::new(
                'TenantLifecycle.ControlRecord.Invalid'
            )
        }
        $safePrerequisites.Add([pscustomobject][ordered]@{
            stage = [string]$prerequisite.stage
            status = [string]$prerequisite.status
            classification = [string]$prerequisite.classification
            phaseManifestDigest = [string]$prerequisite.phaseManifestDigest
            phaseSummaryDigest = [string]$prerequisite.phaseSummaryDigest
            intentDigest = [string]$prerequisite.intentDigest
            stateDigest = [string]$prerequisite.stateDigest
        })
    }

    [pscustomobject][ordered]@{
        schemaVersion = '1.0'
        runId = $runIdText
        sourceCommit = $SourceCommit.ToLowerInvariant()
        publicTenantKey = $PublicTenantKey
        intentDigest = $IntentDigest
        stateDigest = $StateDigest
        selectedStages = [string[]]@($SelectedStages)
        prerequisiteResults = [object[]]@($safePrerequisites.ToArray())
        evidenceRunRelativePath = $EvidenceRunRelativePath
    }
}
