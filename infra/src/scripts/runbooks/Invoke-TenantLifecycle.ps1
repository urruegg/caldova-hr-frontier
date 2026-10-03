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

if ($Mode -ceq 'Verify' -and $null -ne $SubsystemInvoker) {
    throw [InvalidOperationException]::new(
        'TenantLifecycle.SubsystemInvoker.NotAllowed'
    )
}
if ($Mode -ceq 'Verify') {
    throw [InvalidOperationException]::new(
        'TenantLifecycle.Verify.NotImplemented'
    )
}
if ($null -eq $SubsystemInvoker) {
    throw [InvalidOperationException]::new(
        'TenantLifecycle.SubsystemInvoker.Required'
    )
}

$canonicalStageOrder = @(
    'Workstation',
    'PrivateBoundary',
    'Foundation',
    'DevDelivery',
    'ReadBack',
    'Acceptance',
    'TenantReplica'
)
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

$gitCommand = @(
    Get-Command git.exe -CommandType Application -ErrorAction SilentlyContinue
)
if ($gitCommand.Count -ne 1 -or
    [string]::IsNullOrWhiteSpace([string]$gitCommand[0].Source)) {
    throw [InvalidOperationException]::new('TenantLifecycle.Source.Command')
}
$gitPath = [string]$gitCommand[0].Source

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
        [ValidateSet('Assessment', 'ExecutionManifest', 'StageResult')]
        [string]$Kind
    )

    try {
        if ([IO.Path]::IsPathRooted($RelativePath) -or
            $RelativePath.Contains('\') -or
            $RelativePath -cnotmatch (
                '^(phases/[A-Za-z0-9]+/' +
                '(assessment|execution-manifest)[.]json|' +
                'stages/[A-Za-z0-9]+[.]json)$'
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
        if (-not (Test-TenantLifecycleRunPath -Path $artifactPath) -or
            -not [IO.File]::Exists($artifactPath)) {
            throw [IO.InvalidDataException]::new()
        }

        $cursor = $artifactPath
        while (-not [StringComparer]::OrdinalIgnoreCase.Equals(
                $cursor,
                $runDirectory
            )) {
            $item = Get-Item -LiteralPath $cursor -Force
            if (($item.Attributes -band
                    [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw [IO.InvalidDataException]::new()
            }
            $cursor = Split-Path -Parent $cursor
        }

        $bytes = [IO.File]::ReadAllBytes($artifactPath)
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
        Test-TenantLifecycleContract `
            -Kind $Kind `
            -InputObject $artifact |
            Out-Null
        $canonicalText = ConvertTo-TenantLifecycleCanonicalJson `
            -InputObject $artifact
        if (-not [StringComparer]::Ordinal.Equals(
                $text,
                $canonicalText
            )) {
            throw [IO.InvalidDataException]::new()
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
    param([Parameter(Mandatory)][string]$Stage)

    $relativePath = "stages/$Stage.json"
    $prerequisite = Read-TenantLifecycleCanonicalArtifact `
        -RelativePath $relativePath `
        -Kind StageResult
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
            $baselineStateDigest
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
    $prerequisite
}

function Assert-TenantLifecycleChildArtifact {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Stage,
        [Parameter(Mandatory)][string]$DispatchMode
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
        $null = & $SubsystemInvoker `
            -Stage $stage `
            -Mode $Mode `
            -ControlRecord $freshControlRecord
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
        -DispatchMode $Mode
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
