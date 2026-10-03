function ConvertTo-TenantLifecycleAcceptanceProjection {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][string]$RunDirectory,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$AllowedStableIds,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$AllowedUrlHosts,
        [Parameter(Mandatory)][string]$OutputPath
    )

    try {
        if (-not [IO.Path]::IsPathRooted($RunDirectory) -or
            -not [IO.Path]::IsPathRooted($OutputPath)) {
            throw [IO.InvalidDataException]::new()
        }
        $runRoot = [IO.Path]::GetFullPath($RunDirectory).TrimEnd('\', '/')
        $targetPath = [IO.Path]::GetFullPath($OutputPath)
    }
    catch {
        throw [IO.InvalidDataException]::new('TenantLifecycle.Disclosure.Path')
    }
    if (-not [IO.Directory]::Exists($runRoot)) {
        throw [IO.InvalidDataException]::new('TenantLifecycle.Disclosure.Path')
    }
    if ([IO.File]::Exists($targetPath)) {
        throw [IO.IOException]::new('TenantLifecycle.Disclosure.OutputExists')
    }
    try {
        if (Test-TenantLifecycleDisclosureGitPath -Path $targetPath) {
            throw [IO.InvalidDataException]::new(
                'TenantLifecycle.Disclosure.OutputGit'
            )
        }
        if (Test-TenantLifecycleDisclosureReparsePath -Path $targetPath) {
            throw [IO.InvalidDataException]::new(
                'TenantLifecycle.Disclosure.OutputPath'
            )
        }
    }
    catch {
        if ($_.Exception.Message -cmatch '^TenantLifecycle\.Disclosure\.') {
            throw
        }
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.Disclosure.OutputPath'
        )
    }
    Assert-TenantLifecycleDisclosureAllowlists `
        -AllowedStableIds $AllowedStableIds `
        -AllowedUrlHosts $AllowedUrlHosts

    $assessmentRecord = Import-TenantLifecycleDisclosureEvidence `
        -RunDirectory $runRoot `
        -RelativePath 'assessment.json' `
        -Kind Assessment
    $manifestRecord = Import-TenantLifecycleDisclosureEvidence `
        -RunDirectory $runRoot `
        -RelativePath 'execution-manifest.json' `
        -Kind ExecutionManifest
    $approvalRecord = Import-TenantLifecycleDisclosureEvidence `
        -RunDirectory $runRoot `
        -RelativePath 'approvals.json' `
        -Kind Approval
    $readBackRecord = Import-TenantLifecycleDisclosureEvidence `
        -RunDirectory $runRoot `
        -RelativePath 'read-back.json' `
        -Kind ReadBack
    $summaryRecord = Import-TenantLifecycleDisclosureEvidence `
        -RunDirectory $runRoot `
        -RelativePath 'summary.json' `
        -Kind Summary
    $assessment = $assessmentRecord.Value
    $manifest = $manifestRecord.Value
    $approval = $approvalRecord.Value
    $readBack = $readBackRecord.Value
    $summary = $summaryRecord.Value

    $runId = [string]$manifest.runId
    $sourceCommit = [string]$manifest.sourceCommit
    if ([string]$assessment.runId -cne $runId -or
        [string]$approval.runId -cne $runId -or
        [string]$readBack.runId -cne $runId -or
        [string]$summary.runId -cne $runId -or
        [string]$assessment.sourceCommit -cne $sourceCommit -or
        [string]$summary.sourceCommit -cne $sourceCommit -or
        [string]$assessment.publicTenantKey -cne
            [string]$manifest.publicTenantKey -or
        [string]$assessment.intentDigest -cne
            [string]$manifest.intentDigest -or
        [string]$assessment.stateDigest -cne
            [string]$manifest.stateDigest -or
        [string]$approval.executionManifestDigest -cne
            [string]$manifest.digest -or
        [string]$summary.manifestDigest -cne [string]$manifest.digest -or
        (Get-RunbookContentDigest -InputObject $assessment.machine) -cne
            (Get-RunbookContentDigest -InputObject $manifest.machine) -or
        (Get-RunbookContentDigest -InputObject $assessment.toolIdentities) -cne
            (Get-RunbookContentDigest -InputObject $manifest.toolIdentities) -or
        (Get-RunbookContentDigest -InputObject $assessment.providerContexts) -cne
            (Get-RunbookContentDigest -InputObject $manifest.providerContexts) -or
        (Get-RunbookContentDigest -InputObject $assessment.prerequisites) -cne
            (Get-RunbookContentDigest -InputObject $manifest.prerequisites)) {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.Disclosure.Correlation'
        )
    }

    $manifestActionIds = @($manifest.actions | ForEach-Object { [string]$_.id })
    $approvalScope = @($approval.scope | ForEach-Object { [string]$_ })
    $summaryActionIds = @(
        $summary.actions |
            ForEach-Object { [string]$_.id }
    )
    $summaryPrerequisiteIds = @(
        $summary.prerequisites |
            ForEach-Object { [string]$_.id }
    )
    Assert-TenantLifecycleDisclosureIdentifierSet `
        -Expected $manifestActionIds `
        -Actual $approvalScope `
        -ErrorMessage 'TenantLifecycle.Disclosure.Correlation'
    Assert-TenantLifecycleDisclosureIdentifierSet `
        -Expected $manifestActionIds `
        -Actual $summaryActionIds `
        -ErrorMessage 'TenantLifecycle.Disclosure.ActionEvidence.Correlation'
    Assert-TenantLifecycleDisclosureIdentifierSet `
        -Expected $manifestActionIds `
        -Actual $summaryPrerequisiteIds `
        -ErrorMessage 'TenantLifecycle.Disclosure.ActionEvidence.Correlation'

    $manifestActions = [Collections.Generic.Dictionary[string, object]]::new(
        [StringComparer]::Ordinal
    )
    foreach ($action in @($manifest.actions)) {
        $manifestActions.Add([string]$action.id, $action)
    }
    $summaryPrerequisites =
        [Collections.Generic.Dictionary[string, object]]::new(
            [StringComparer]::Ordinal
        )
    foreach ($prerequisite in @($summary.prerequisites)) {
        $summaryPrerequisites.Add(
            [string]$prerequisite.id,
            $prerequisite
        )
    }

    $projectionActions = [Collections.Generic.List[object]]::new()
    $actionDigests = [Collections.Generic.List[object]]::new()
    $calculatedCounts = [ordered]@{
        NoChange = 0
        Create = 0
        Update = 0
        Manual = 0
        Blocked = 0
        Refused = 0
    }
    foreach ($summaryAction in @($summary.actions)) {
        $actionId = [string]$summaryAction.id
        if (-not $manifestActions.ContainsKey($actionId) -or
            -not $summaryPrerequisites.ContainsKey($actionId) -or
            [string]$summaryAction.evidenceRelativePath -cne
                "actions/$actionId.json") {
            throw [IO.InvalidDataException]::new(
                'TenantLifecycle.Disclosure.ActionEvidence.Correlation'
            )
        }
        $manifestAction = $manifestActions[$actionId]
        $prerequisite = $summaryPrerequisites[$actionId]
        $evidenceRecord = Import-TenantLifecycleDisclosureEvidence `
            -RunDirectory $runRoot `
            -RelativePath "actions/$actionId.json" `
            -Kind ActionEvidence
        $evidence = $evidenceRecord.Value
        $evidenceDigest = [string]$evidenceRecord.ByteDigest
        if ([string]$evidence.runId -cne $runId -or
            [string]$evidence.actionId -cne $actionId -or
            [string]$evidence.classification -cne
                [string]$manifestAction.classification -or
            [string]$evidence.classification -cne
                [string]$summaryAction.classification -or
            [string]$evidence.decision -cne
                [string]$evidence.classification -or
            [string]$evidence.status -cne [string]$summaryAction.status -or
            [string]$evidence.status -cne [string]$prerequisite.status -or
            [string]$evidence.preReadDigest -cne
                [string]$prerequisite.inputDigest -or
            [string]$evidence.postReadDigest -cne
                [string]$evidence.preReadDigest -or
            $evidenceDigest -cne [string]$prerequisite.evidenceDigest) {
            throw [IO.InvalidDataException]::new(
                'TenantLifecycle.Disclosure.ActionEvidence.Correlation'
            )
        }
        $projectionAction = [pscustomobject][ordered]@{
            id = $actionId
            classification = [string]$evidence.classification
            status = [string]$evidence.status
            digest = $evidenceDigest
        }
        $projectionActions.Add($projectionAction)
        $actionDigests.Add([pscustomobject][ordered]@{
            id = $actionId
            digest = $evidenceDigest
        })
        $calculatedCounts[[string]$evidence.classification] =
            [int]$calculatedCounts[[string]$evidence.classification] + 1
    }
    foreach ($classification in @(
        'NoChange',
        'Create',
        'Update',
        'Manual',
        'Blocked',
        'Refused'
    )) {
        if ([int]$summary.counts.$classification -ne
            [int]$calculatedCounts[$classification]) {
            throw [IO.InvalidDataException]::new(
                'TenantLifecycle.Disclosure.ActionEvidence.Correlation'
            )
        }
    }

    $readBackStableIds = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::Ordinal
    )
    foreach ($component in @($readBack.components)) {
        [void]$readBackStableIds.Add([string]$component.stableId)
    }
    foreach ($action in @($manifest.actions)) {
        if ($null -ne $action.targetStableId -and
            -not $readBackStableIds.Contains(
                [string]$action.targetStableId
            )) {
            throw [IO.InvalidDataException]::new(
                'TenantLifecycle.Disclosure.ReadBack.Correlation'
            )
        }
    }

    $stableIdAllowlist = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::Ordinal
    )
    foreach ($value in $AllowedStableIds) {
        [void]$stableIdAllowlist.Add($value)
    }
    $urlHostAllowlist = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::OrdinalIgnoreCase
    )
    foreach ($value in $AllowedUrlHosts) {
        [void]$urlHostAllowlist.Add($value)
    }
    $disclosedStableIds = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::Ordinal
    )
    $disclosedUrlHosts = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::OrdinalIgnoreCase
    )
    foreach ($component in @($readBack.components)) {
        $stableId = [string]$component.stableId
        $uri = $null
        $isHttpUri = [Uri]::TryCreate(
            $stableId,
            [UriKind]::Absolute,
            [ref]$uri
        ) -and $uri.Scheme -in @('http', 'https')
        if ($isHttpUri) {
            if (-not [string]::IsNullOrEmpty($uri.UserInfo)) {
                throw [IO.InvalidDataException]::new(
                    'TenantLifecycle.Disclosure.Identifier'
                )
            }
            $host = $uri.IdnHost.ToLowerInvariant()
            if ($urlHostAllowlist.Contains($host)) {
                [void]$disclosedUrlHosts.Add($host)
            }
        }
        elseif ($stableIdAllowlist.Contains($stableId)) {
            [void]$disclosedStableIds.Add($stableId)
        }
    }
    if ($disclosedStableIds.Count -ne $stableIdAllowlist.Count -or
        $disclosedUrlHosts.Count -ne $urlHostAllowlist.Count) {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.Disclosure.Allowlist'
        )
    }
    [string[]]$stableIdValues = @($disclosedStableIds)
    [string[]]$urlHostValues = @($disclosedUrlHosts)
    [Array]::Sort($stableIdValues, [StringComparer]::Ordinal)
    [Array]::Sort($urlHostValues, [StringComparer]::OrdinalIgnoreCase)

    $approvedDigests = [pscustomobject][ordered]@{
        assessment = [string]$assessmentRecord.ByteDigest
        executionManifest = [string]$manifestRecord.ByteDigest
        approval = [string]$approvalRecord.ByteDigest
        intent = [string]$manifest.intentDigest
        readBack = [string]$readBackRecord.ByteDigest
        summary = [string]$summaryRecord.ByteDigest
        actions = @($actionDigests.ToArray())
    }
    $coreProjection = [pscustomobject][ordered]@{
        actions = @($projectionActions.ToArray())
        approvedDigests = $approvedDigests
        counts = [pscustomobject]$calculatedCounts
        disclosedStableIds = [string[]]$stableIdValues
        disclosedUrlHosts = [string[]]$urlHostValues
        nonClaims = @(
            'Provider mutation was not verified by this projection.',
            'Pipeline import was not verified by this projection.',
            'Artifact bytes were not verified by this projection.'
        )
        runId = $runId
        sourceCommit = $sourceCommit
        statuses = [pscustomobject][ordered]@{
            approval = [string]$approval.status
            readBack = [string]$readBack.status
            summary = [string]$summary.status
        }
    }
    $projection = [pscustomobject][ordered]@{
        actions = $coreProjection.actions
        approvedDigests = $coreProjection.approvedDigests
        artifactDigest = Get-RunbookContentDigest -InputObject $coreProjection
        counts = $coreProjection.counts
        disclosedStableIds = $coreProjection.disclosedStableIds
        disclosedUrlHosts = $coreProjection.disclosedUrlHosts
        nonClaims = $coreProjection.nonClaims
        runId = $coreProjection.runId
        sourceCommit = $coreProjection.sourceCommit
        statuses = $coreProjection.statuses
    }
    Test-TenantLifecycleDisclosure `
        -Projection $projection `
        -AllowedStableIds $AllowedStableIds `
        -AllowedUrlHosts $AllowedUrlHosts |
        Out-Null

    try {
        $targetDirectory = [IO.Path]::GetDirectoryName($targetPath)
        [IO.Directory]::CreateDirectory($targetDirectory) | Out-Null
        $canonical = ConvertTo-CanonicalJsonValue `
            -Value $projection `
            -RemainingDepth 30
        $json = ($canonical | ConvertTo-Json -Depth 30 -Compress) + "`n"
        $bytes = [Text.UTF8Encoding]::new($false, $true).GetBytes($json)
        return Write-TenantLifecycleAtomicFile `
            -Path $targetPath `
            -Bytes $bytes
    }
    catch {
        if ($_.Exception.Message -ceq 'TenantLifecycle.Evidence.Exists') {
            throw [IO.IOException]::new(
                'TenantLifecycle.Disclosure.OutputExists'
            )
        }
        if ($_.Exception.Message -cmatch '^TenantLifecycle\.Disclosure\.') {
            throw
        }
        throw [IO.IOException]::new('TenantLifecycle.Disclosure.Write')
    }
}
