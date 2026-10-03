function Test-TenantLifecycleStageResultSet {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)][string]$RunDirectory,
        [Parameter(Mandatory)][guid]$RunId,
        [Parameter(Mandatory)][string[]]$Stages,
        [Parameter(Mandatory)]
        [ValidatePattern('^[0-9a-f]{40}$')]
        [string]$SourceCommit,
        [Parameter(Mandatory)]
        [ValidateSet('tenant1')]
        [string]$PublicTenantKey,
        [Parameter(Mandatory)]
        [ValidatePattern('^[0-9a-f]{64}$')]
        [string]$IntentDigest,
        [Parameter(Mandatory)]
        [ValidatePattern('^[0-9a-f]{64}$')]
        [string]$CurrentStateDigest
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
    if (@($Stages).Count -eq 0) {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.StageResultSet.Invalid'
        )
    }
    $selectedStageNames = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::Ordinal
    )
    $lastStageIndex = -1
    foreach ($stage in @($Stages)) {
        $stageIndex = -1
        for ($index = 0; $index -lt $knownStages.Count; $index++) {
            if ([StringComparer]::Ordinal.Equals(
                    $knownStages[$index],
                    $stage
                )) {
                $stageIndex = $index
                break
            }
        }
        if ($stageIndex -lt 0 -or
            $stageIndex -le $lastStageIndex -or
            -not $selectedStageNames.Add($stage)) {
            throw [IO.InvalidDataException]::new(
                'TenantLifecycle.StageResultSet.Invalid'
            )
        }
        $lastStageIndex = $stageIndex
    }

    try {
        if (-not [IO.Path]::IsPathRooted($RunDirectory)) {
            throw [IO.InvalidDataException]::new()
        }
        $runRoot = [IO.Path]::GetFullPath($RunDirectory)
        $pathRoot = [IO.Path]::GetPathRoot($runRoot)
        if ($runRoot.Length -gt $pathRoot.Length) {
            $runRoot = $runRoot.TrimEnd(
                [IO.Path]::DirectorySeparatorChar,
                [IO.Path]::AltDirectorySeparatorChar
            )
        }
        if (-not [IO.Directory]::Exists($runRoot) -or
            (Test-TenantLifecycleEvidenceReparsePath -Path $runRoot)) {
            throw [IO.InvalidDataException]::new()
        }
        $runItem = Get-Item `
            -LiteralPath $runRoot `
            -Force `
            -ErrorAction Stop
        if (-not [bool]$runItem.PSIsContainer -or
            ($runItem.Attributes -band
                [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw [IO.InvalidDataException]::new()
        }
        $stagesDirectory = Join-Path $runRoot 'stages'
        if (-not [IO.Directory]::Exists($stagesDirectory) -or
            (Test-TenantLifecycleEvidenceReparsePath `
                -Path $stagesDirectory)) {
            throw [IO.InvalidDataException]::new()
        }
        $stagesItem = Get-Item `
            -LiteralPath $stagesDirectory `
            -Force `
            -ErrorAction Stop
        if (-not [bool]$stagesItem.PSIsContainer -or
            ($stagesItem.Attributes -band
                [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw [IO.InvalidDataException]::new()
        }
        $entries = @(
            Get-ChildItem `
                -LiteralPath $stagesDirectory `
                -Force `
                -ErrorAction Stop
        )
        if ($entries.Count -ne $Stages.Count) {
            throw [IO.InvalidDataException]::new()
        }
        $expectedFileNames = [Collections.Generic.HashSet[string]]::new(
            [StringComparer]::Ordinal
        )
        foreach ($stage in @($Stages)) {
            [void]$expectedFileNames.Add("$stage.json")
        }
        foreach ($entry in $entries) {
            if ([bool]$entry.PSIsContainer -or
                ($entry.Attributes -band
                    [IO.FileAttributes]::ReparsePoint) -ne 0 -or
                -not $expectedFileNames.Contains([string]$entry.Name)) {
                throw [IO.InvalidDataException]::new()
            }
        }
    }
    catch {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.StageResultSet.Invalid'
        )
    }

    $runIdText = $RunId.ToString('D').ToLowerInvariant()
    $results = [Collections.Generic.List[object]]::new()
    $previousOutputStateDigest = $null
    foreach ($stage in @($Stages)) {
        try {
            $resultRelativePath = "stages/$stage.json"
            $resultPath = Join-Path $runRoot (
                $resultRelativePath.Replace(
                    '/',
                    [IO.Path]::DirectorySeparatorChar
                )
            )
            $resultRecord = Read-TenantLifecycleCanonicalJsonFile `
                -Path $resultPath `
                -ContainmentRoot $runRoot `
                -ExpectedRelativePath $resultRelativePath
            $result = $resultRecord.value
            $expectedEvidenceRelativePath =
                "phases/$stage/summary.json"
            if (-not [StringComparer]::Ordinal.Equals(
                    [string]$result.runId,
                    $runIdText
                ) -or
                -not [StringComparer]::Ordinal.Equals(
                    [string]$result.stage,
                    $stage
                ) -or
                -not [StringComparer]::Ordinal.Equals(
                    [string]$result.sourceCommit,
                    $SourceCommit
                ) -or
                -not [StringComparer]::Ordinal.Equals(
                    [string]$result.publicTenantKey,
                    $PublicTenantKey
                ) -or
                -not [StringComparer]::Ordinal.Equals(
                    [string]$result.intentDigest,
                    $IntentDigest
                ) -or
                -not [StringComparer]::Ordinal.Equals(
                    [string]$result.evidenceRelativePath,
                    $expectedEvidenceRelativePath
                )) {
                throw [IO.InvalidDataException]::new()
            }

            $manifestRelativePath =
                "phases/$stage/execution-manifest.json"
            $manifestPath = Join-Path $runRoot (
                $manifestRelativePath.Replace(
                    '/',
                    [IO.Path]::DirectorySeparatorChar
                )
            )
            $manifestRecord = Read-TenantLifecycleCanonicalJsonFile `
                -Path $manifestPath `
                -ContainmentRoot $runRoot `
                -ExpectedRelativePath $manifestRelativePath `
                -ExpectedDigest ([string]$result.phaseManifestDigest)
            $manifest = $manifestRecord.value
            foreach ($field in @(
                'schemaVersion',
                'runId',
                'sourceCommit',
                'publicTenantKey',
                'intentDigest',
                'stateDigest'
            )) {
                $property = $manifest.PSObject.Properties[$field]
                if ($null -eq $property -or
                    $property.MemberType -ne 'NoteProperty') {
                    throw [IO.InvalidDataException]::new()
                }
            }
            if ([string]$manifest.schemaVersion -cne '1.0' -or
                -not [StringComparer]::Ordinal.Equals(
                    [string]$manifest.runId,
                    $runIdText
                ) -or
                -not [StringComparer]::Ordinal.Equals(
                    [string]$manifest.sourceCommit,
                    $SourceCommit
                ) -or
                -not [StringComparer]::Ordinal.Equals(
                    [string]$manifest.publicTenantKey,
                    $PublicTenantKey
                ) -or
                -not [StringComparer]::Ordinal.Equals(
                    [string]$manifest.intentDigest,
                    $IntentDigest
                ) -or
                -not ([string]$manifest.stateDigest -cmatch
                    '^[0-9a-f]{64}$')) {
                throw [IO.InvalidDataException]::new()
            }

            $summaryPath = Join-Path $runRoot (
                $expectedEvidenceRelativePath.Replace(
                    '/',
                    [IO.Path]::DirectorySeparatorChar
                )
            )
            $null = Read-TenantLifecycleCanonicalJsonFile `
                -Path $summaryPath `
                -ContainmentRoot $runRoot `
                -ExpectedRelativePath $expectedEvidenceRelativePath `
                -ExpectedDigest ([string]$result.phaseSummaryDigest)

            if ($null -ne $previousOutputStateDigest -and
                -not [StringComparer]::Ordinal.Equals(
                    $previousOutputStateDigest,
                    [string]$manifest.stateDigest
                )) {
                throw [IO.InvalidDataException]::new()
            }
            $stateChanged = -not [StringComparer]::Ordinal.Equals(
                [string]$manifest.stateDigest,
                [string]$result.stateDigest
            )
            $claimsChanged = [string]$result.classification -ceq 'Changed'
            if ($stateChanged -ne $claimsChanged) {
                throw [IO.InvalidDataException]::new()
            }
            $previousOutputStateDigest = [string]$result.stateDigest
            $results.Add([pscustomobject][ordered]@{
                schemaVersion = [string]$result.schemaVersion
                runId = [string]$result.runId
                stage = [string]$result.stage
                sourceCommit = [string]$result.sourceCommit
                publicTenantKey = [string]$result.publicTenantKey
                intentDigest = [string]$result.intentDigest
                stateDigest = [string]$result.stateDigest
                phaseManifestDigest =
                    [string]$result.phaseManifestDigest
                phaseSummaryDigest =
                    [string]$result.phaseSummaryDigest
                status = [string]$result.status
                classification = [string]$result.classification
                evidenceRelativePath =
                    [string]$result.evidenceRelativePath
                completedAtUtc = [string]$result.completedAtUtc
            })
        }
        catch {
            throw [IO.InvalidDataException]::new(
                'TenantLifecycle.StageResultSet.Invalid'
            )
        }
    }

    if (-not [StringComparer]::Ordinal.Equals(
            $previousOutputStateDigest,
            $CurrentStateDigest
        )) {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.StageResultSet.Invalid'
        )
    }
    $results.ToArray()
}
