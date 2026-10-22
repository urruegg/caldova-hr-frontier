[CmdletBinding()]
param(
    [Parameter(Mandatory)][guid]$RunId,
    [Parameter(Mandatory)][string]$EvidenceRoot,
    [Parameter(Mandatory)][string]$RepositoryRoot,
    [Parameter(Mandatory)][ValidatePattern('^[0-9a-fA-F]{40}$')][string]$ExpectedSourceCommit,
    [Parameter(Mandatory)][ValidateSet('tenant1')][string]$PublicTenantKey,
    [Parameter(Mandatory)][string]$TenantConfigurationPath,
    [Parameter(Mandatory)][string]$TenantStatePath,
    [Parameter(Mandatory)]
    [ValidateSet('Workstation','PrivateBoundary','Foundation','DevDelivery','ReadBack','Acceptance','TenantReplica')]
    [string[]]$Stages,
    [ValidateSet('Assess','Plan','Verify')][string]$Mode = 'Assess',
    [Parameter(DontShow)][scriptblock]$SubsystemInvoker,
    [datetime]$NowUtc = [datetime]::UtcNow
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$canonicalStageOrder = @(
    'Workstation',
    'PrivateBoundary',
    'Foundation',
    'DevDelivery',
    'ReadBack',
    'Acceptance',
    'TenantReplica'
)
$canonicalModes = @('Assess', 'Plan', 'Verify')
$modeIsExact = $false
foreach ($canonicalMode in $canonicalModes) {
    if ([StringComparer]::Ordinal.Equals($canonicalMode, $Mode)) {
        $modeIsExact = $true
        break
    }
}
if (-not $modeIsExact) {
    throw [IO.InvalidDataException]::new('TenantLifecycle.Mode.Invalid')
}
if (@($Stages).Count -eq 0) {
    throw [IO.InvalidDataException]::new('TenantLifecycle.Stages.Required')
}
$selectedStageSet = [Collections.Generic.HashSet[string]]::new(
    [StringComparer]::Ordinal
)
$lastSelectedStageIndex = -1
foreach ($selectedStage in @($Stages)) {
    $selectedStageIndex = -1
    for ($index = 0; $index -lt $canonicalStageOrder.Count; $index++) {
        if ([StringComparer]::Ordinal.Equals(
                $canonicalStageOrder[$index],
                $selectedStage
            )) {
            $selectedStageIndex = $index
            break
        }
    }
    if ($selectedStageIndex -lt 0 -or
        $selectedStageIndex -le $lastSelectedStageIndex -or
        -not $selectedStageSet.Add($selectedStage)) {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.Stages.Invalid'
        )
    }
    $lastSelectedStageIndex = $selectedStageIndex
}

if ($Mode -ceq 'Verify' -and $null -ne $SubsystemInvoker) {
    throw [InvalidOperationException]::new(
        'TenantLifecycle.SubsystemInvoker.NotAllowed'
    )
}
if ($Mode -cne 'Verify' -and $null -eq $SubsystemInvoker) {
    throw [InvalidOperationException]::new(
        'TenantLifecycle.SubsystemInvoker.Required'
    )
}

$trustedRunId = [guid]$RunId
$trustedRunIdText = $trustedRunId.ToString('D').ToLowerInvariant()
$trustedExpectedSourceCommit = $ExpectedSourceCommit.ToLowerInvariant()
$trustedPublicTenantKey = [string]$PublicTenantKey
$trustedTenantConfigurationPath = [string]$TenantConfigurationPath
$trustedTenantStatePath = [string]$TenantStatePath
$trustedStages = [string[]]@($Stages)
$trustedMode = [string]$Mode

$modulePath = [IO.Path]::GetFullPath((
    Join-Path $PSScriptRoot (
        '..\modules\Caldova.HrFrontier.Bootstrap\' +
        'Caldova.HrFrontier.Bootstrap.psd1'
    )
))
Import-Module $modulePath -Force

try {
    $repository = [IO.Path]::GetFullPath($RepositoryRoot).TrimEnd('\', '/')
    if (-not [IO.Directory]::Exists($repository)) {
        throw [IO.InvalidDataException]::new()
    }
    $trustedEvidenceRoot = [IO.Path]::GetFullPath(
        $EvidenceRoot
    ).TrimEnd('\', '/')
    $expectedRunDirectory = [IO.Path]::GetFullPath((
        Join-Path $trustedEvidenceRoot $trustedRunIdText
    ))
    $runDirectory = Resolve-RunbookReportPath `
        -RunId $trustedRunId `
        -Path $expectedRunDirectory `
        -RepositoryRoot $repository
    if (-not [StringComparer]::OrdinalIgnoreCase.Equals(
            $expectedRunDirectory,
            $runDirectory
        ) -or
        -not [StringComparer]::OrdinalIgnoreCase.Equals(
            $trustedEvidenceRoot,
            (Split-Path -Parent $runDirectory)
        )) {
        throw [IO.InvalidDataException]::new()
    }
}
catch {
    throw [IO.InvalidDataException]::new('TenantLifecycle.Orchestrator.Path')
}

$gitCommand = Get-Command `
    git.exe `
    -CommandType Application `
    -ErrorAction SilentlyContinue |
    Select-Object -First 1
if ($null -eq $gitCommand -or
    [string]::IsNullOrWhiteSpace([string]$gitCommand.Source)) {
    throw [InvalidOperationException]::new('TenantLifecycle.Source.Command')
}
$gitPath = [string]$gitCommand.Source

function Invoke-TenantLifecycleGit {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string[]]$Arguments)

    $previousErrorActionPreference = $ErrorActionPreference
    $exitCode = -1
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& $gitPath @Arguments 2>&1)
        $exitCode = $LASTEXITCODE
    }
    catch {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.Source.Command'
        )
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    [pscustomobject][ordered]@{
        exitCode = $exitCode
        stdout = (
            ($output | ForEach-Object { [string]$_ }) -join "`n"
        ).TrimEnd()
        stderr = ''
    }
}

function Get-TenantLifecycleSourceBinding {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $sourceResult = Invoke-TenantLifecycleGit -Arguments @(
        '-C',
        $repository,
        'rev-parse',
        'HEAD'
    )
    $currentSourceCommit = (
        [string]$sourceResult.stdout
    ).Trim().ToLowerInvariant()
    if ([int]$sourceResult.exitCode -ne 0) {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.Source.Command'
        )
    }
    if ($currentSourceCommit -cnotmatch '^[0-9a-f]{40}$' -or
        -not [StringComparer]::Ordinal.Equals(
            $currentSourceCommit,
            $trustedExpectedSourceCommit
        )) {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.Source.Drift'
        )
    }

    $cleanResult = Invoke-TenantLifecycleGit -Arguments @(
        '-C',
        $repository,
        'status',
        '--porcelain=v1',
        '--untracked-files=all'
    )
    if ([int]$cleanResult.exitCode -ne 0) {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.Source.Command'
        )
    }
    if (-not [string]::IsNullOrWhiteSpace(
            [string]$cleanResult.stdout
        )) {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.Source.Drift'
        )
    }

    $currentSourceCommit
}

$gitBoundaryRunner = {
    param([string]$FilePath, [string[]]$ArgumentList)

    if ($FilePath -cne 'git') {
        throw [InvalidOperationException]::new(
            'TenantLifecycle.PrivateBoundary.Git'
        )
    }
    Invoke-TenantLifecycleGit -Arguments $ArgumentList
}

function Get-TenantLifecyclePrivateBinding {
    [CmdletBinding()]
    [OutputType([object])]
    param()

    try {
        Test-TenantLifecyclePrivateBoundary `
            -PublicTenantKey $trustedPublicTenantKey `
            -IntentPath $trustedTenantConfigurationPath `
            -StatePath $trustedTenantStatePath `
            -RepositoryRoot $repository `
            -NativeCommandRunner $gitBoundaryRunner
    }
    catch {
        if ($_.Exception.Message -cmatch (
                '^TenantLifecycle\.PrivateBoundary\.'
            )) {
            throw
        }
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.PrivateBoundary.Invalid'
        )
    }
}

$baselineSourceCommit = Get-TenantLifecycleSourceBinding
$baselinePrivateBinding = Get-TenantLifecyclePrivateBinding
$baselineIntentDigest = [string]$baselinePrivateBinding.intent.digest
$baselineStateDigest = [string]$baselinePrivateBinding.state.digest

function Assert-TenantLifecycleBindings {
    [CmdletBinding()]
    [OutputType([object])]
    param()

    $currentSourceCommit = Get-TenantLifecycleSourceBinding
    if (-not [StringComparer]::Ordinal.Equals(
            $baselineSourceCommit,
            $currentSourceCommit
        )) {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.Source.Drift'
        )
    }
    $currentPrivateBinding = Get-TenantLifecyclePrivateBinding
    if (-not [StringComparer]::Ordinal.Equals(
            $baselineIntentDigest,
            [string]$currentPrivateBinding.intent.digest
        )) {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.Intent.Drift'
        )
    }
    if (-not [StringComparer]::Ordinal.Equals(
            $baselineStateDigest,
            [string]$currentPrivateBinding.state.digest
        )) {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.State.Drift'
        )
    }

    [pscustomobject][ordered]@{
        sourceCommit = $currentSourceCommit
        intentDigest = [string]$currentPrivateBinding.intent.digest
        stateDigest = [string]$currentPrivateBinding.state.digest
    }
}

if ($trustedMode -ceq 'Verify') {
    $verifiedCoordinates = Assert-TenantLifecycleBindings
    $stageResults = @(
        Test-TenantLifecycleStageResultSet `
            -RunDirectory $runDirectory `
            -RunId $trustedRunId `
            -Stages $trustedStages `
            -SourceCommit $verifiedCoordinates.sourceCommit `
            -PublicTenantKey $trustedPublicTenantKey `
            -IntentDigest $verifiedCoordinates.intentDigest `
            -CurrentStateDigest $verifiedCoordinates.stateDigest
    )
    $verifiedCoordinates = Assert-TenantLifecycleBindings

    $stageNodes = [Collections.Generic.List[object]]::new()
    for (
        $verifyStageIndex = 0;
        $verifyStageIndex -lt $trustedStages.Count;
        $verifyStageIndex++
    ) {
        $verifyStage = [string]$trustedStages[$verifyStageIndex]
        [string[]]$prerequisiteIds = @()
        if ($verifyStageIndex -gt 0) {
            $prerequisiteIds = [string[]]@(
                $trustedStages[$verifyStageIndex - 1]
            )
        }
        $stageNodes.Add([pscustomobject][ordered]@{
            id = $verifyStage
            kind = 'Stage'
            prerequisiteIds = $prerequisiteIds
            requiredOutcome = 'Passed'
            inputDigest = [string]$stageResults[
                $verifyStageIndex
            ].phaseManifestDigest
            stage = $verifyStage
        })
    }
    $resolvedStages = @(
        Resolve-TenantLifecycleGraph `
            -Nodes @($stageNodes.ToArray()) `
            -ObservedOutcomes $stageResults
    )
    foreach ($resolvedStage in $resolvedStages) {
        if (-not [bool]$resolvedStage.canExecute -or
            [string]$resolvedStage.status -cne 'Passed') {
            throw [IO.InvalidDataException]::new(
                'TenantLifecycle.Verify.Invalid'
            )
        }
    }
    foreach ($stageResult in $stageResults) {
        if ([string]$stageResult.status -cne 'Passed') {
            throw [IO.InvalidDataException]::new(
                'TenantLifecycle.Verify.Invalid'
            )
        }
    }

    $verifiedCoordinates = Assert-TenantLifecycleBindings
    $revalidatedStageResults = @(
        Test-TenantLifecycleStageResultSet `
            -RunDirectory $runDirectory `
            -RunId $trustedRunId `
            -Stages $trustedStages `
            -SourceCommit $verifiedCoordinates.sourceCommit `
            -PublicTenantKey $trustedPublicTenantKey `
            -IntentDigest $verifiedCoordinates.intentDigest `
            -CurrentStateDigest $verifiedCoordinates.stateDigest
    )
    $verifiedCoordinates = Assert-TenantLifecycleBindings
    $firstValidatedBytes = [Text.UTF8Encoding]::new(
        $false,
        $true
    ).GetBytes((
        ConvertTo-TenantLifecycleCanonicalJson `
            -InputObject ([object[]]$stageResults)
    ))
    $secondValidatedBytes = [Text.UTF8Encoding]::new(
        $false,
        $true
    ).GetBytes((
        ConvertTo-TenantLifecycleCanonicalJson `
            -InputObject ([object[]]$revalidatedStageResults)
    ))
    if ([Convert]::ToBase64String($firstValidatedBytes) -cne
        [Convert]::ToBase64String($secondValidatedBytes)) {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.Verify.EvidenceDrift'
        )
    }
    $stageResults = [object[]]$revalidatedStageResults
    $summaryPath = Join-Path $runDirectory 'summary.json'
    $null = ConvertTo-TenantLifecycleAcceptanceProjection `
        -RunId $trustedRunId `
        -PublicTenantKey $trustedPublicTenantKey `
        -OrderedStageResults $stageResults `
        -OutputPath $summaryPath
    return
}

function Test-TenantLifecycleRunPath {
    [CmdletBinding()]
    [OutputType([bool])]
    param([Parameter(Mandatory)][string]$Path)

    $fullPath = [IO.Path]::GetFullPath($Path)
    $rootWithSeparator = $runDirectory.TrimEnd('\', '/') +
        [IO.Path]::DirectorySeparatorChar
    $fullPath.StartsWith(
        $rootWithSeparator,
        [StringComparison]::OrdinalIgnoreCase
    )
}

function Read-TenantLifecycleCanonicalArtifact {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)][string]$RelativePath,
        [Parameter(Mandatory)]
        [ValidateSet(
            'Assessment',
            'ExecutionManifest',
            'StageResult',
            'Opaque'
        )]
        [string]$Kind,
        [switch]$PassThruRecord
    )

    try {
        if ([IO.Path]::IsPathRooted($RelativePath) -or
            $RelativePath.Contains('\') -or
            $RelativePath -cnotmatch (
                '^(phases/[A-Za-z0-9]+/' +
                '(assessment|execution-manifest|summary)[.]json|' +
                'stage-results/[A-Za-z0-9]+[.]json)$'
            )) {
            throw [IO.InvalidDataException]::new()
        }
        $nativeRelativePath = $RelativePath.Replace(
            '/',
            [IO.Path]::DirectorySeparatorChar
        )
        $artifactPath = [IO.Path]::GetFullPath((
            Join-Path $runDirectory $nativeRelativePath
        ))
        if (-not (Test-TenantLifecycleRunPath -Path $artifactPath)) {
            throw [IO.InvalidDataException]::new()
        }

        $resolvedPath = $runDirectory
        foreach ($segment in @($RelativePath -split '/')) {
            $matches = @(
                Get-ChildItem `
                    -LiteralPath $resolvedPath `
                    -Force `
                    -ErrorAction Stop |
                    Where-Object {
                        [StringComparer]::Ordinal.Equals(
                            [string]$_.Name,
                            [string]$segment
                        )
                    }
            )
            if ($matches.Count -ne 1) {
                throw [IO.InvalidDataException]::new()
            }
            $item = $matches[0]
            if (($item.Attributes -band
                    [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw [IO.InvalidDataException]::new()
            }
            $resolvedPath = [IO.Path]::GetFullPath(
                [string]$item.FullName
            )
        }
        if (-not [StringComparer]::Ordinal.Equals(
                $artifactPath,
                $resolvedPath
            ) -or
            -not [IO.File]::Exists($resolvedPath)) {
            throw [IO.InvalidDataException]::new()
        }

        $bytes = [IO.File]::ReadAllBytes($resolvedPath)
        if ($bytes.Length -eq 0 -or
            ($bytes.Length -ge 3 -and
                $bytes[0] -eq 0xEF -and
                $bytes[1] -eq 0xBB -and
                $bytes[2] -eq 0xBF)) {
            throw [IO.InvalidDataException]::new()
        }
        $text = [Text.UTF8Encoding]::new(
            $false,
            $true
        ).GetString($bytes)
        if ($text.Contains("`r") -or
            -not $text.EndsWith("`n", [StringComparison]::Ordinal) -or
            $text.EndsWith("`n`n", [StringComparison]::Ordinal)) {
            throw [IO.InvalidDataException]::new()
        }
        $artifact = ConvertFrom-TenantLifecycleJson -InputObject $text
        if ($Kind -cne 'Opaque') {
            Test-TenantLifecycleContract `
                -Kind $Kind `
                -InputObject $artifact |
                Out-Null
        }
        $canonicalText = ConvertTo-TenantLifecycleCanonicalJson `
            -InputObject $artifact
        if (-not [StringComparer]::Ordinal.Equals(
                $text,
                $canonicalText
            )) {
            throw [IO.InvalidDataException]::new()
        }
        if ($PassThruRecord) {
            $algorithm = [Security.Cryptography.SHA256]::Create()
            try {
                $digest = -join @(
                    $algorithm.ComputeHash($bytes) |
                        ForEach-Object { $_.ToString('x2') }
                )
            }
            finally {
                $algorithm.Dispose()
            }
            return [pscustomobject][ordered]@{
                relativePath = $RelativePath
                digest = $digest
                value = $artifact
            }
        }
        $artifact
    }
    catch {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.ChildArtifact.Invalid'
        )
    }
}

function Test-TenantLifecycleEmbeddedDigest {
    [CmdletBinding()]
    [OutputType([bool])]
    param([Parameter(Mandatory)][object]$Artifact)

    $digestInput = [ordered]@{}
    foreach ($property in @($Artifact.PSObject.Properties)) {
        if ($property.Name -cne 'digest') {
            $digestInput[$property.Name] = $property.Value
        }
    }
    $calculatedDigest = Get-RunbookContentDigest -InputObject (
        [pscustomobject]$digestInput
    )
    [StringComparer]::Ordinal.Equals(
        [string]$Artifact.digest,
        $calculatedDigest
    )
}

function Read-TenantLifecyclePrerequisite {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)][string]$Stage,
        [string]$ExpectedOutputStateDigest = $baselineStateDigest
    )

    $relativePath = "stage-results/$Stage.json"
    $prerequisiteRecord = Read-TenantLifecycleCanonicalArtifact `
        -RelativePath $relativePath `
        -Kind StageResult `
        -PassThruRecord
    $prerequisite = $prerequisiteRecord.value
    if (-not [StringComparer]::Ordinal.Equals(
            [string]$prerequisite.runId,
            $trustedRunIdText
        ) -or
        -not [StringComparer]::Ordinal.Equals(
            [string]$prerequisite.stage,
            $Stage
        ) -or
        -not [StringComparer]::Ordinal.Equals(
            [string]$prerequisite.sourceCommit,
            $baselineSourceCommit
        ) -or
        -not [StringComparer]::Ordinal.Equals(
            [string]$prerequisite.publicTenantKey,
            $trustedPublicTenantKey
        ) -or
        -not [StringComparer]::Ordinal.Equals(
            [string]$prerequisite.intentDigest,
            $baselineIntentDigest
        ) -or
        -not [StringComparer]::Ordinal.Equals(
            [string]$prerequisite.stateDigest,
            $ExpectedOutputStateDigest
        ) -or
        [string]$prerequisite.status -cne 'Passed' -or
        [string]$prerequisite.classification -cnotin @(
            'NoChange',
            'Changed'
        )) {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.ChildArtifact.Invalid'
        )
    }

    $stageIndex = [Array]::IndexOf($trustedStages, $Stage)
    if ($stageIndex -lt 0) {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.ChildArtifact.Invalid'
        )
    }
    try {
        $envelope = Test-TenantLifecycleSummaryEnvelope `
            -RunDirectory $runDirectory `
            -RunId $trustedRunId `
            -Stage $Stage `
            -SourceCommit $baselineSourceCommit `
            -PublicTenantKey $trustedPublicTenantKey `
            -IntentDigest $baselineIntentDigest `
            -StageResult $prerequisite
    }
    catch {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.ChildArtifact.Invalid'
        )
    }
    if (-not ($envelope.selectedStages -is [System.Array]) -or
        @($envelope.selectedStages).Count -ne $trustedStages.Count) {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.ChildArtifact.Invalid'
        )
    }
    for (
        $selectedIndex = 0;
        $selectedIndex -lt $trustedStages.Count;
        $selectedIndex++
    ) {
        if (-not [StringComparer]::Ordinal.Equals(
                [string]$envelope.selectedStages[$selectedIndex],
                [string]$trustedStages[$selectedIndex]
            )) {
            throw [IO.InvalidDataException]::new(
                'TenantLifecycle.ChildArtifact.Invalid'
            )
        }
    }

    [object[]]$expectedManifestPrerequisites = @()
    if ($stageIndex -gt 0) {
        $previousStage = [string]$trustedStages[$stageIndex - 1]
        $previousResult = Read-TenantLifecyclePrerequisite `
            -Stage $previousStage `
            -ExpectedOutputStateDigest (
                [string]$envelope.manifestStateDigest
            )
        $expectedManifestPrerequisites = @(
            [pscustomobject][ordered]@{
                stage = [string]$previousResult.stage
                status = [string]$previousResult.status
                classification = [string]$previousResult.classification
                phaseManifestDigest =
                    [string]$previousResult.phaseManifestDigest
                phaseSummaryDigest =
                    [string]$previousResult.phaseSummaryDigest
                intentDigest = [string]$previousResult.intentDigest
                stateDigest = [string]$previousResult.stateDigest
            }
        )
    }
    if (-not ($envelope.prerequisiteResults -is [System.Array]) -or
        @($envelope.prerequisiteResults).Count -ne
            $expectedManifestPrerequisites.Count) {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.ChildArtifact.Invalid'
        )
    }
    $prerequisiteFields = @(
        'stage',
        'status',
        'classification',
        'phaseManifestDigest',
        'phaseSummaryDigest',
        'intentDigest',
        'stateDigest'
    )
    for (
        $prerequisiteIndex = 0;
        $prerequisiteIndex -lt $expectedManifestPrerequisites.Count;
        $prerequisiteIndex++
    ) {
        $actualManifestPrerequisite =
            $envelope.prerequisiteResults[$prerequisiteIndex]
        $expectedManifestPrerequisite =
            $expectedManifestPrerequisites[$prerequisiteIndex]
        foreach ($field in $prerequisiteFields) {
            if (-not [StringComparer]::Ordinal.Equals(
                    [string]$actualManifestPrerequisite.$field,
                    [string]$expectedManifestPrerequisite.$field
                )) {
                throw [IO.InvalidDataException]::new(
                    'TenantLifecycle.ChildArtifact.Invalid'
                )
            }
        }
    }

    $stateAdvanced = -not [StringComparer]::Ordinal.Equals(
        [string]$envelope.manifestStateDigest,
        [string]$prerequisite.stateDigest
    )
    if ($stateAdvanced -and
        [string]$prerequisite.classification -cne 'Changed') {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.ChildArtifact.Invalid'
        )
    }

    $prerequisite
}

function Assert-TenantLifecycleChildArtifact {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Stage,
        [Parameter(Mandatory)][string]$DispatchMode,
        [Parameter(Mandatory)][object]$ControlRecord
    )

    if ($DispatchMode -ceq 'Assess') {
        $kind = 'Assessment'
        $relativePath = "phases/$Stage/assessment.json"
    }
    else {
        $kind = 'ExecutionManifest'
        $relativePath = "phases/$Stage/execution-manifest.json"
    }
    $artifact = Read-TenantLifecycleCanonicalArtifact `
        -RelativePath $relativePath `
        -Kind $kind
    if (-not [StringComparer]::Ordinal.Equals(
            [string]$artifact.runId,
            $trustedRunIdText
        ) -or
        -not [StringComparer]::Ordinal.Equals(
            [string]$artifact.sourceCommit,
            $baselineSourceCommit
        ) -or
        -not [StringComparer]::Ordinal.Equals(
            [string]$artifact.publicTenantKey,
            $trustedPublicTenantKey
        ) -or
        -not [StringComparer]::Ordinal.Equals(
            [string]$artifact.intentDigest,
            $baselineIntentDigest
        ) -or
        -not [StringComparer]::Ordinal.Equals(
            [string]$artifact.stateDigest,
            $baselineStateDigest
        ) -or
        -not (Test-TenantLifecycleEmbeddedDigest -Artifact $artifact)) {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.ChildArtifact.Invalid'
        )
    }
    if ($DispatchMode -ceq 'Assess') {
        if (-not [StringComparer]::Ordinal.Equals(
                [string]$artifact.kind,
                $Stage
            )) {
            throw [IO.InvalidDataException]::new(
                'TenantLifecycle.ChildArtifact.Invalid'
            )
        }
    }
    else {
        if (@($artifact.actions).Count -ne 1 -or
            -not [StringComparer]::Ordinal.Equals(
                [string]$artifact.actions[0].id,
                $Stage
            ) -or
            -not ($artifact.selectedStages -is [System.Array]) -or
            @($artifact.selectedStages).Count -ne
                @($ControlRecord.selectedStages).Count -or
            -not ($artifact.prerequisiteResults -is [System.Array]) -or
            @($artifact.prerequisiteResults).Count -ne
                @($ControlRecord.prerequisiteResults).Count) {
            throw [IO.InvalidDataException]::new(
                'TenantLifecycle.ChildArtifact.Invalid'
            )
        }
        for (
            $selectedIndex = 0;
            $selectedIndex -lt
                @($ControlRecord.selectedStages).Count;
            $selectedIndex++
        ) {
            if (-not [StringComparer]::Ordinal.Equals(
                    [string]$artifact.selectedStages[$selectedIndex],
                    [string]$ControlRecord.selectedStages[$selectedIndex]
                )) {
                throw [IO.InvalidDataException]::new(
                    'TenantLifecycle.ChildArtifact.Invalid'
                )
            }
        }
        $prerequisiteFields = @(
            'stage',
            'status',
            'classification',
            'phaseManifestDigest',
            'phaseSummaryDigest',
            'intentDigest',
            'stateDigest'
        )
        for (
            $prerequisiteIndex = 0;
            $prerequisiteIndex -lt
                @($ControlRecord.prerequisiteResults).Count;
            $prerequisiteIndex++
        ) {
            $actualPrerequisite =
                $artifact.prerequisiteResults[$prerequisiteIndex]
            $expectedPrerequisite =
                $ControlRecord.prerequisiteResults[$prerequisiteIndex]
            foreach ($field in $prerequisiteFields) {
                if (-not [StringComparer]::Ordinal.Equals(
                        [string]$actualPrerequisite.$field,
                        [string]$expectedPrerequisite.$field
                    )) {
                    throw [IO.InvalidDataException]::new(
                        'TenantLifecycle.ChildArtifact.Invalid'
                    )
                }
            }
        }
    }
}

function New-TenantLifecycleProcessJob {
    if ($null -eq (
            'Caldova.HrFrontier.Runtime.TenantLifecycleProcessJob' -as [type]
        )) {
        Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Diagnostics;
using System.Runtime.InteropServices;

namespace Caldova.HrFrontier.Runtime
{
    public sealed class TenantLifecycleProcessJob : IDisposable
    {
        private const uint KillOnJobClose = 0x00002000;
        private const int ExtendedLimitInformation = 9;
        private IntPtr handle;

        [StructLayout(LayoutKind.Sequential)]
        private struct BasicLimitInformation
        {
            public long PerProcessUserTimeLimit;
            public long PerJobUserTimeLimit;
            public uint LimitFlags;
            public UIntPtr MinimumWorkingSetSize;
            public UIntPtr MaximumWorkingSetSize;
            public uint ActiveProcessLimit;
            public UIntPtr Affinity;
            public uint PriorityClass;
            public uint SchedulingClass;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct IoCounters
        {
            public ulong ReadOperationCount;
            public ulong WriteOperationCount;
            public ulong OtherOperationCount;
            public ulong ReadTransferCount;
            public ulong WriteTransferCount;
            public ulong OtherTransferCount;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct ExtendedLimit
        {
            public BasicLimitInformation BasicLimitInformation;
            public IoCounters IoInfo;
            public UIntPtr ProcessMemoryLimit;
            public UIntPtr JobMemoryLimit;
            public UIntPtr PeakProcessMemoryUsed;
            public UIntPtr PeakJobMemoryUsed;
        }

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern IntPtr CreateJobObject(
            IntPtr jobAttributes,
            string name
        );

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool SetInformationJobObject(
            IntPtr job,
            int informationClass,
            IntPtr information,
            uint informationLength
        );

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool AssignProcessToJobObject(
            IntPtr job,
            IntPtr process
        );

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool CloseHandle(IntPtr handle);

        public TenantLifecycleProcessJob()
        {
            handle = CreateJobObject(IntPtr.Zero, null);
            if (handle == IntPtr.Zero)
            {
                throw new Win32Exception(Marshal.GetLastWin32Error());
            }

            ExtendedLimit information = new ExtendedLimit();
            information.BasicLimitInformation.LimitFlags = KillOnJobClose;
            int length = Marshal.SizeOf(typeof(ExtendedLimit));
            IntPtr informationPointer = Marshal.AllocHGlobal(length);
            try
            {
                Marshal.StructureToPtr(
                    information,
                    informationPointer,
                    false
                );
                if (!SetInformationJobObject(
                        handle,
                        ExtendedLimitInformation,
                        informationPointer,
                        (uint)length
                    ))
                {
                    throw new Win32Exception(Marshal.GetLastWin32Error());
                }
            }
            catch
            {
                CloseHandle(handle);
                handle = IntPtr.Zero;
                throw;
            }
            finally
            {
                Marshal.FreeHGlobal(informationPointer);
            }
        }

        public void Assign(Process process)
        {
            if (process == null)
            {
                throw new ArgumentNullException("process");
            }
            if (handle == IntPtr.Zero)
            {
                throw new ObjectDisposedException(
                    "TenantLifecycleProcessJob"
                );
            }
            if (!AssignProcessToJobObject(handle, process.Handle))
            {
                throw new Win32Exception(Marshal.GetLastWin32Error());
            }
        }

        public void Dispose()
        {
            IntPtr currentHandle = handle;
            handle = IntPtr.Zero;
            if (currentHandle != IntPtr.Zero &&
                !CloseHandle(currentHandle))
            {
                throw new Win32Exception(Marshal.GetLastWin32Error());
            }
            GC.SuppressFinalize(this);
        }

        ~TenantLifecycleProcessJob()
        {
            if (handle != IntPtr.Zero)
            {
                CloseHandle(handle);
                handle = IntPtr.Zero;
            }
        }
    }
}
'@
    }

    [Caldova.HrFrontier.Runtime.TenantLifecycleProcessJob]::new()
}

function Invoke-TenantLifecycleIsolatedInvoker {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][scriptblock]$Invoker,
        [Parameter(Mandatory)][string]$Stage,
        [Parameter(Mandatory)][string]$Mode,
        [Parameter(Mandatory)][object]$ControlRecord,
        [Parameter(Mandatory)][string]$ExternalRunRoot
    )

    $invocationEnvelope = [pscustomobject][ordered]@{
        invoker = [Convert]::ToBase64String(
            [Text.Encoding]::UTF8.GetBytes($Invoker.ToString())
        )
        stage = $Stage
        mode = $Mode
        controlRecord = $ControlRecord
    }
    $invocationEnvelopeJson = $invocationEnvelope |
        ConvertTo-Json -Depth 30 -Compress
    $childScript = @'
$ErrorActionPreference = 'Stop'
try {
    [Console]::SetOut([IO.TextWriter]::Null)
    [Console]::SetError([IO.TextWriter]::Null)
    $invocationEnvelope = [Console]::In.ReadToEnd() | ConvertFrom-Json
    $invokerText = [Text.Encoding]::UTF8.GetString(
        [Convert]::FromBase64String([string]$invocationEnvelope.invoker)
    )
    $invoker = [scriptblock]::Create($invokerText)
    $null = & $invoker `
        -Stage ([string]$invocationEnvelope.stage) `
        -Mode ([string]$invocationEnvelope.mode) `
        -ControlRecord $invocationEnvelope.controlRecord *> $null
    exit 0
}
catch {
    exit 1
}
'@
    $encodedChildScript = [Convert]::ToBase64String(
        [Text.Encoding]::Unicode.GetBytes($childScript)
    )
    $hostExecutableName = if ($PSVersionTable.PSEdition -ceq 'Core') {
        'pwsh.exe'
    }
    else {
        'powershell.exe'
    }
    $hostExecutable = Join-Path $PSHOME $hostExecutableName
    if (-not [IO.File]::Exists($hostExecutable)) {
        throw [InvalidOperationException]::new(
            'TenantLifecycle.SubsystemInvoker.Failed'
        )
    }

    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $hostExecutable
    $startInfo.Arguments = (
        '-NoLogo -NoProfile -NonInteractive -EncodedCommand ' +
        $encodedChildScript
    )
    [IO.Directory]::CreateDirectory($ExternalRunRoot) | Out-Null
    $startInfo.WorkingDirectory = $ExternalRunRoot
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardInput = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.EnvironmentVariables.Clear()
    foreach ($environmentName in @('SystemRoot', 'WINDIR', 'ComSpec')) {
        $environmentValue = [Environment]::GetEnvironmentVariable(
            $environmentName,
            [EnvironmentVariableTarget]::Process
        )
        if (-not [string]::IsNullOrWhiteSpace($environmentValue)) {
            $startInfo.EnvironmentVariables[$environmentName] =
                $environmentValue
        }
    }

    $child = [Diagnostics.Process]::new()
    $child.StartInfo = $startInfo
    $processJob = $null
    $childStarted = $false
    $childExited = $false
    $stdoutDrainTask = $null
    $stderrDrainTask = $null
    $invocationException = $null
    try {
        $processJob = New-TenantLifecycleProcessJob
        if (-not $child.Start()) {
            throw [InvalidOperationException]::new()
        }
        $childStarted = $true
        $processJob.Assign($child)
        $stdoutDrainTask = $child.StandardOutput.BaseStream.CopyToAsync(
            [IO.Stream]::Null,
            4096
        )
        $stderrDrainTask = $child.StandardError.BaseStream.CopyToAsync(
            [IO.Stream]::Null,
            4096
        )
        $timeoutMilliseconds = 300000
        $stopwatch = [Diagnostics.Stopwatch]::StartNew()
        $writeTask = $child.StandardInput.WriteAsync(
            $invocationEnvelopeJson
        )
        if (-not $writeTask.Wait($timeoutMilliseconds)) {
            throw [TimeoutException]::new()
        }
        [void]$writeTask.GetAwaiter().GetResult()
        $child.StandardInput.Close()
        $remainingMilliseconds = $timeoutMilliseconds - [int][Math]::Min(
            $stopwatch.ElapsedMilliseconds,
            $timeoutMilliseconds
        )
        if ($remainingMilliseconds -le 0 -or
            -not $child.WaitForExit($remainingMilliseconds)) {
            throw [TimeoutException]::new()
        }
        $childExited = $true
        if ($child.ExitCode -ne 0) {
            throw [InvalidOperationException]::new()
        }
    }
    catch {
        $invocationException = $_.Exception
    }

    $cleanupExceptions = [Collections.Generic.List[Exception]]::new()
    if ($null -ne $processJob) {
        try {
            $processJob.Dispose()
        }
        catch {
            [void]$cleanupExceptions.Add($_.Exception)
        }
    }
    try {
        if ($childStarted -and
            -not $childExited -and
            -not $child.WaitForExit(5000)) {
            $child.Kill()
            if (-not $child.WaitForExit(5000)) {
                throw [TimeoutException]::new()
            }
            $childExited = $true
        }
    }
    catch {
        [void]$cleanupExceptions.Add($_.Exception)
    }
    foreach ($drainTask in @($stdoutDrainTask, $stderrDrainTask)) {
        if ($null -eq $drainTask) {
            continue
        }
        try {
            if (-not $drainTask.Wait(5000)) {
                throw [TimeoutException]::new()
            }
            [void]$drainTask.GetAwaiter().GetResult()
        }
        catch {
            [void]$cleanupExceptions.Add($_.Exception)
        }
    }
    try {
        $child.Dispose()
    }
    catch {
        [void]$cleanupExceptions.Add($_.Exception)
    }

    if ($cleanupExceptions.Count -gt 0) {
        $cleanupException = if ($cleanupExceptions.Count -eq 1) {
            $cleanupExceptions[0]
        }
        else {
            [AggregateException]::new(
                [Exception[]]$cleanupExceptions.ToArray()
            )
        }
        throw [InvalidOperationException]::new(
            'TenantLifecycle.SubsystemInvoker.Failed',
            $cleanupException
        )
    }
    if ($null -ne $invocationException) {
        throw [InvalidOperationException]::new(
            'TenantLifecycle.SubsystemInvoker.Failed',
            $invocationException
        )
    }
}

for ($stageIndex = 0; $stageIndex -lt $trustedStages.Count; $stageIndex++) {
    $stage = [string]$trustedStages[$stageIndex]
    $prerequisiteResults = @()
    if ($stageIndex -gt 0) {
        $prerequisiteStage = [string]$trustedStages[$stageIndex - 1]
        $prerequisiteResults = @(
            Read-TenantLifecyclePrerequisite -Stage $prerequisiteStage
        )
    }

    $verifiedCoordinates = Assert-TenantLifecycleBindings
    $freshControlRecord = New-TenantLifecycleControlRecord `
        -RunId $trustedRunId `
        -SourceCommit $verifiedCoordinates.sourceCommit `
        -PublicTenantKey $trustedPublicTenantKey `
        -IntentDigest $verifiedCoordinates.intentDigest `
        -StateDigest $verifiedCoordinates.stateDigest `
        -SelectedStages $trustedStages `
        -PrerequisiteResults $prerequisiteResults `
        -EvidenceRunRelativePath $trustedRunIdText

    $Mode = $trustedMode
    try {
        Invoke-TenantLifecycleIsolatedInvoker `
            -Invoker $SubsystemInvoker `
            -Stage $stage `
            -Mode $Mode `
            -ControlRecord $freshControlRecord `
            -ExternalRunRoot $trustedEvidenceRoot
    }
    catch {
        throw [InvalidOperationException]::new(
            'TenantLifecycle.SubsystemInvoker.Failed',
            $_.Exception
        )
    }

    $stage = [string]$trustedStages[$stageIndex]
    $Mode = $trustedMode
    $verifiedCoordinates = Assert-TenantLifecycleBindings
    $freshControlRecord = New-TenantLifecycleControlRecord `
        -RunId $trustedRunId `
        -SourceCommit $verifiedCoordinates.sourceCommit `
        -PublicTenantKey $trustedPublicTenantKey `
        -IntentDigest $verifiedCoordinates.intentDigest `
        -StateDigest $verifiedCoordinates.stateDigest `
        -SelectedStages $trustedStages `
        -PrerequisiteResults $prerequisiteResults `
        -EvidenceRunRelativePath $trustedRunIdText

    Assert-TenantLifecycleChildArtifact `
        -Stage $stage `
        -DispatchMode $Mode `
        -ControlRecord $freshControlRecord
    $verifiedCoordinates = Assert-TenantLifecycleBindings
    $freshControlRecord = New-TenantLifecycleControlRecord `
        -RunId $trustedRunId `
        -SourceCommit $verifiedCoordinates.sourceCommit `
        -PublicTenantKey $trustedPublicTenantKey `
        -IntentDigest $verifiedCoordinates.intentDigest `
        -StateDigest $verifiedCoordinates.stateDigest `
        -SelectedStages $trustedStages `
        -PrerequisiteResults $prerequisiteResults `
        -EvidenceRunRelativePath $trustedRunIdText
}
