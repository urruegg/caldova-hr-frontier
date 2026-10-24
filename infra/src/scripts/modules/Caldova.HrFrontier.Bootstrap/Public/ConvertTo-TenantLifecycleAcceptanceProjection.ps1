function ConvertTo-TenantLifecycleAcceptanceProjection {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][guid]$RunId,
        [Parameter(Mandatory)]
        [ValidateSet('tenant1')]
        [string]$PublicTenantKey,
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$OrderedStageResults,
        [Parameter(Mandatory)][string]$OutputPath
    )

    $runIdText = $RunId.ToString('D').ToLowerInvariant()
    if (@($OrderedStageResults).Count -eq 0) {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.Disclosure.Invalid'
        )
    }

    $canonicalStages = @(
        'Workstation',
        'PrivateBoundary',
        'Foundation',
        'DevDelivery',
        'ReadBack',
        'Acceptance',
        'TenantReplica'
    )
    $lastStageIndex = -1
    $stages = [Collections.Generic.List[object]]::new()
    foreach ($stageResult in @($OrderedStageResults)) {
        try {
            Test-TenantLifecycleContract `
                -Kind StageResult `
                -InputObject $stageResult |
                Out-Null
            if ([string]$stageResult.runId -cne $runIdText -or
                [string]$stageResult.publicTenantKey -cne
                    $PublicTenantKey -or
                [string]$stageResult.status -cne 'Passed' -or
                [string]$stageResult.classification -cnotin @(
                    'NoChange',
                    'Changed'
                )) {
                throw [IO.InvalidDataException]::new()
            }

            $stageIndex = -1
            for (
                $index = 0;
                $index -lt $canonicalStages.Count;
                $index++
            ) {
                if ([StringComparer]::Ordinal.Equals(
                        $canonicalStages[$index],
                        [string]$stageResult.stage
                    )) {
                    $stageIndex = $index
                    break
                }
            }
            if ($stageIndex -le $lastStageIndex) {
                throw [IO.InvalidDataException]::new()
            }
            $lastStageIndex = $stageIndex
            $stages.Add([pscustomobject][ordered]@{
                stage = [string]$stageResult.stage
                status = [string]$stageResult.status
                classification = [string]$stageResult.classification
                phaseManifestDigest =
                    [string]$stageResult.phaseManifestDigest
                phaseSummaryDigest =
                    [string]$stageResult.phaseSummaryDigest
                sourceCommit = [string]$stageResult.sourceCommit
                intentDigest = [string]$stageResult.intentDigest
                stateDigest = [string]$stageResult.stateDigest
            })
        }
        catch {
            throw [IO.InvalidDataException]::new(
                'TenantLifecycle.Disclosure.Invalid'
            )
        }
    }

    try {
        if (-not [IO.Path]::IsPathRooted($OutputPath)) {
            throw [IO.InvalidDataException]::new()
        }
        $targetPath = [IO.Path]::GetFullPath($OutputPath)
        $targetDirectory = [IO.Path]::GetDirectoryName($targetPath)
        $runDirectoryName = [IO.Path]::GetFileName(
            $targetDirectory.TrimEnd('\', '/')
        )
        if ([IO.Path]::GetFileName($targetPath) -cne 'summary.json' -or
            $runDirectoryName -cne $runIdText -or
            -not [IO.Directory]::Exists($targetDirectory)) {
            throw [IO.InvalidDataException]::new()
        }
    }
    catch {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.Disclosure.Path'
        )
    }
    if ([IO.File]::Exists($targetPath)) {
        throw [IO.IOException]::new(
            'TenantLifecycle.Disclosure.OutputExists'
        )
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

    $coreProjection = [pscustomobject][ordered]@{
        schemaVersion = '1.0'
        runId = $runIdText
        publicTenantKey = $PublicTenantKey
        stages = [object[]]@($stages.ToArray())
        nonClaims = [string[]]@(
            'The umbrella did not execute a provider mutation.',
            'Provider approvals and read-back remain child-runbook evidence.',
            'This projection discloses no provider resource identity or raw provider response.'
        )
    }
    $projection = [pscustomobject][ordered]@{
        schemaVersion = $coreProjection.schemaVersion
        runId = $coreProjection.runId
        publicTenantKey = $coreProjection.publicTenantKey
        stages = $coreProjection.stages
        nonClaims = $coreProjection.nonClaims
        digest = Get-RunbookContentDigest -InputObject $coreProjection
    }
    Test-TenantLifecycleDisclosure -Projection $projection | Out-Null

    try {
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
