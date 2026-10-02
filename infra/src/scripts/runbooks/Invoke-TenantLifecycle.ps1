[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
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
    [ValidateSet('Assess','Plan','Invoke')][string]$Mode = 'Assess',
    [string]$ExecutionManifestPath,
    [ValidatePattern('^[0-9a-f]{64}$')][string]$ApprovedDigest,
    [switch]$Apply,
    [Parameter(DontShow)][scriptblock]$SubsystemInvoker,
    [datetime]$NowUtc = [datetime]::UtcNow
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$modulePath = [IO.Path]::GetFullPath((
    Join-Path $PSScriptRoot (
        '..\modules\Caldova.HrFrontier.Bootstrap\' +
        'Caldova.HrFrontier.Bootstrap.psd1'
    )
))
Import-Module $modulePath -Force

function Get-TenantLifecycleManifestDigest {
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][object]$Manifest)

    Get-RunbookContentDigest -InputObject ([pscustomobject][ordered]@{
        schemaVersion = $Manifest.schemaVersion
        runId = $Manifest.runId
        generatedAtUtc = $Manifest.generatedAtUtc
        expiresAtUtc = $Manifest.expiresAtUtc
        sourceCommit = $Manifest.sourceCommit
        evidenceRoot = $Manifest.evidenceRoot
        publicTenantKey = $Manifest.publicTenantKey
        intentDigest = $Manifest.intentDigest
        stateDigest = $Manifest.stateDigest
        machine = $Manifest.machine
        operator = $Manifest.operator
        toolIdentities = @($Manifest.toolIdentities)
        providerContexts = @($Manifest.providerContexts)
        prerequisites = @($Manifest.prerequisites)
        actions = @($Manifest.actions)
    })
}

function Assert-TenantLifecycleSubsystemOutcome {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowNull()][object]$Outcome,
        [Parameter(Mandatory)][string]$ExpectedStage,
        [Parameter(Mandatory)][string]$ExpectedInputDigest
    )

    try {
        if ($null -eq $Outcome -or
            $Outcome -is [string] -or
            $Outcome -is [System.Array] -or
            $Outcome -is [Collections.IDictionary]) {
            throw [IO.InvalidDataException]::new()
        }

        $expectedProperties = @(
            'id',
            'stage',
            'classification',
            'status',
            'inputDigest',
            'readBackDigest',
            'evidenceRelativePath'
        )
        $properties = @($Outcome.PSObject.Properties)
        if ($properties.Count -ne $expectedProperties.Count) {
            throw [IO.InvalidDataException]::new()
        }
        $actualProperties = [Collections.Generic.HashSet[string]]::new(
            [StringComparer]::Ordinal
        )
        foreach ($property in $properties) {
            if (-not $property.IsGettable -or
                $property.MemberType -notin @(
                    'NoteProperty',
                    'Property',
                    'AliasProperty'
                )) {
                throw [IO.InvalidDataException]::new()
            }
            [void]$actualProperties.Add($property.Name)
        }
        foreach ($name in $expectedProperties) {
            if (-not $actualProperties.Contains($name)) {
                throw [IO.InvalidDataException]::new()
            }
        }

        if (-not [StringComparer]::Ordinal.Equals(
                [string]$Outcome.id,
                $ExpectedStage
            ) -or
            -not [StringComparer]::Ordinal.Equals(
                [string]$Outcome.stage,
                $ExpectedStage
            ) -or
            -not [StringComparer]::Ordinal.Equals(
                [string]$Outcome.inputDigest,
                $ExpectedInputDigest
            ) -or
            [string]$Outcome.classification -cnotin @(
                'NoChange',
                'Create',
                'Update',
                'Manual',
                'Blocked',
                'Refused'
            ) -or
            -not ($Outcome.status -is [string]) -or
            [string]$Outcome.status -cnotmatch '^[A-Za-z][A-Za-z0-9]{0,63}$' -or
            -not [StringComparer]::Ordinal.Equals(
                [string]$Outcome.evidenceRelativePath,
                "actions/$ExpectedStage.json"
            )) {
            throw [IO.InvalidDataException]::new()
        }

        if ($null -ne $Outcome.readBackDigest -and
            (
                -not ($Outcome.readBackDigest -is [string]) -or
                [string]$Outcome.readBackDigest -cnotmatch '^[0-9a-f]{64}$'
            )) {
            throw [IO.InvalidDataException]::new()
        }
    }
    catch {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.Orchestrator.Outcome'
        )
    }
}

if ($null -eq $SubsystemInvoker) {
    throw [InvalidOperationException]::new(
        'TenantLifecycle.SubsystemInvoker.Required'
    )
}
if (@($Stages).Count -eq 0) {
    throw [IO.InvalidDataException]::new('TenantLifecycle.Stages.Required')
}
if ($Apply -and [string]::IsNullOrWhiteSpace($ApprovedDigest)) {
    throw [IO.InvalidDataException]::new('TenantLifecycle.Approval.Required')
}
if ($Apply -and $Mode -cne 'Invoke') {
    throw [IO.InvalidDataException]::new('TenantLifecycle.Apply.Mode')
}
if ($Mode -ceq 'Invoke' -and -not $Apply) {
    throw [IO.InvalidDataException]::new('TenantLifecycle.Apply.Required')
}
if ($Mode -ceq 'Invoke' -and
    [string]::IsNullOrWhiteSpace($ExecutionManifestPath)) {
    throw [IO.InvalidDataException]::new('TenantLifecycle.Manifest.Required')
}

try {
    $repository = [IO.Path]::GetFullPath($RepositoryRoot).TrimEnd('\', '/')
    if (-not [IO.Directory]::Exists($repository)) {
        throw [IO.InvalidDataException]::new()
    }
    $runDirectory = Resolve-RunbookReportPath `
        -RunId $RunId `
        -Path (Join-Path ([IO.Path]::GetFullPath($EvidenceRoot)) $RunId.ToString('D')) `
        -RepositoryRoot $repository
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
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& $gitPath @Arguments 2>&1)
        $exitCode = $LASTEXITCODE
    }
    catch {
        throw [IO.InvalidDataException]::new('TenantLifecycle.Source.Command')
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    [pscustomobject][ordered]@{
        exitCode = $exitCode
        stdout = (($output | ForEach-Object { [string]$_ }) -join "`n").TrimEnd()
        stderr = ''
    }
}

$sourceResult = Invoke-TenantLifecycleGit -Arguments @(
    '-C',
    $repository,
    'rev-parse',
    'HEAD'
)
$sourceCommit = ([string]$sourceResult.stdout).Trim().ToLowerInvariant()
if ([int]$sourceResult.exitCode -ne 0 -or
    $sourceCommit -cnotmatch '^[0-9a-f]{40}$' -or
    -not [StringComparer]::Ordinal.Equals(
        $sourceCommit,
        $ExpectedSourceCommit.ToLowerInvariant()
    )) {
    throw [IO.InvalidDataException]::new('TenantLifecycle.Source.Commit')
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

try {
    Test-TenantLifecyclePrivateBoundary `
        -PublicTenantKey $PublicTenantKey `
        -IntentPath $TenantConfigurationPath `
        -StatePath $TenantStatePath `
        -RepositoryRoot $repository `
        -NativeCommandRunner $gitBoundaryRunner |
        Out-Null
}
catch {
    if ($_.Exception.Message -cmatch '^TenantLifecycle\.PrivateBoundary\.') {
        throw
    }
    throw [IO.InvalidDataException]::new(
        'TenantLifecycle.PrivateBoundary.Invalid'
    )
}

$manifest = $null
if (-not [string]::IsNullOrWhiteSpace($ExecutionManifestPath)) {
    try {
        $manifestPath = [IO.Path]::GetFullPath($ExecutionManifestPath)
        if (-not [IO.File]::Exists($manifestPath)) {
            throw [IO.InvalidDataException]::new()
        }
        $manifest = Get-Content -Raw -LiteralPath $manifestPath |
            ConvertFrom-Json
        Test-TenantLifecycleContract `
            -Kind ExecutionManifest `
            -InputObject $manifest |
            Out-Null
        $calculatedManifestDigest = Get-TenantLifecycleManifestDigest `
            -Manifest $manifest
        if (-not [StringComparer]::Ordinal.Equals(
                [string]$manifest.digest,
                $calculatedManifestDigest
            ) -or
            -not [StringComparer]::Ordinal.Equals(
                [string]$manifest.runId,
                $RunId.ToString('D').ToLowerInvariant()
            ) -or
            -not [StringComparer]::Ordinal.Equals(
                [string]$manifest.sourceCommit,
                $sourceCommit
            ) -or
            -not [StringComparer]::Ordinal.Equals(
                [string]$manifest.publicTenantKey,
                $PublicTenantKey
            ) -or
            -not [StringComparer]::OrdinalIgnoreCase.Equals(
                [IO.Path]::GetFullPath([string]$manifest.evidenceRoot).TrimEnd('\', '/'),
                $runDirectory
            )) {
            throw [IO.InvalidDataException]::new()
        }
        if (-not [string]::IsNullOrWhiteSpace($ApprovedDigest) -and
            -not [StringComparer]::Ordinal.Equals(
                [string]$manifest.digest,
                $ApprovedDigest
            )) {
            throw [IO.InvalidDataException]::new()
        }
        if ($Mode -ceq 'Invoke' -and
            $NowUtc.ToUniversalTime() -ge
                ([DateTimeOffset]$manifest.expiresAtUtc).UtcDateTime) {
            throw [IO.InvalidDataException]::new()
        }
    }
    catch {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.Orchestrator.Manifest'
        )
    }
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
$selectedStageSet = [Collections.Generic.HashSet[string]]::new(
    [StringComparer]::Ordinal
)
foreach ($stage in @($Stages)) {
    [void]$selectedStageSet.Add($stage)
}
$orderedStages = @(
    $canonicalStageOrder |
        Where-Object { $selectedStageSet.Contains($_) }
)

if ($Mode -ceq 'Invoke' -and
    -not $PSCmdlet.ShouldProcess(
        "tenant lifecycle run $($RunId.ToString('D'))",
        "Invoke stages: $($orderedStages -join ',')"
    )) {
    return
}

$machineLabel = if ($null -ne $manifest) {
    [string]$manifest.machine.machineId
}
else {
    [Environment]::MachineName
}
$operatorLabel = if ($null -ne $manifest) {
    [string]$manifest.operator.operatorId
}
else {
    [Environment]::UserName
}
$toolIdentities = if ($null -ne $manifest) {
    @($manifest.toolIdentities)
}
else {
    @()
}
$normalizedApprovedDigest = if (
    [string]::IsNullOrWhiteSpace($ApprovedDigest)
) {
    $null
}
else {
    $ApprovedDigest
}

$outcomes = [Collections.Generic.List[object]]::new()
$nodes = [Collections.Generic.List[object]]::new()
for ($index = 0; $index -lt $orderedStages.Count; $index++) {
    $stage = $orderedStages[$index]
    $controlRecord = [pscustomobject][ordered]@{
        runId = $RunId.ToString('D').ToLowerInvariant()
        runDirectoryLabel = $RunId.ToString('D').ToLowerInvariant()
        publicTenantKey = $PublicTenantKey
        sourceCommit = $sourceCommit
        machineLabel = $machineLabel
        operatorLabel = $operatorLabel
        toolIdentities = @($toolIdentities)
        approvedDigest = $normalizedApprovedDigest
        prerequisiteOutcomes = @($outcomes.ToArray())
    }
    $inputDigest = Get-RunbookContentDigest -InputObject (
        [pscustomobject][ordered]@{
            stage = $stage
            mode = $Mode
            controlRecord = $controlRecord
        }
    )
    [string[]]$prerequisiteIds = @()
    if ($index -gt 0) {
        $prerequisiteIds = @($orderedStages[$index - 1])
    }
    $nodes.Add([pscustomobject][ordered]@{
        id = $stage
        kind = 'Subsystem'
        prerequisiteIds = [string[]]$prerequisiteIds
        requiredOutcome = 'Passed'
        inputDigest = $inputDigest
        stage = $stage
    })

    $resolvedBeforeInvocation = @(
        Resolve-TenantLifecycleGraph `
            -Nodes $nodes.ToArray() `
            -ObservedOutcomes $outcomes.ToArray()
    )
    $currentBeforeInvocation = @(
        $resolvedBeforeInvocation |
            Where-Object { $_.id -ceq $stage }
    )[0]
    if (-not $currentBeforeInvocation.canExecute) {
        break
    }

    try {
        $outcome = & $SubsystemInvoker $stage $Mode $controlRecord
    }
    catch {
        throw [InvalidOperationException]::new(
            'TenantLifecycle.SubsystemInvoker.Failed'
        )
    }
    Assert-TenantLifecycleSubsystemOutcome `
        -Outcome $outcome `
        -ExpectedStage $stage `
        -ExpectedInputDigest $inputDigest
    $outcomes.Add($outcome)

    $resolvedAfterInvocation = @(
        Resolve-TenantLifecycleGraph `
            -Nodes $nodes.ToArray() `
            -ObservedOutcomes $outcomes.ToArray()
    )
    $currentAfterInvocation = @(
        $resolvedAfterInvocation |
            Where-Object { $_.id -ceq $stage }
    )[0]
    if ($currentAfterInvocation.status -cne 'Passed') {
        break
    }
}

if ($null -ne $manifest -and $outcomes.Count -gt 0) {
    $completedNodes = @($nodes.ToArray())[0..($outcomes.Count - 1)]
    $resolvedOutcomes = @(
        Resolve-TenantLifecycleGraph `
            -Nodes $completedNodes `
            -ObservedOutcomes $outcomes.ToArray()
    )
    $resolvedById = @{}
    foreach ($resolvedOutcome in $resolvedOutcomes) {
        $resolvedById[[string]$resolvedOutcome.id] = $resolvedOutcome
    }

    $counts = [ordered]@{
        NoChange = 0
        Create = 0
        Update = 0
        Manual = 0
        Blocked = 0
        Refused = 0
    }
    foreach ($outcome in $outcomes) {
        $counts[[string]$outcome.classification] =
            [int]$counts[[string]$outcome.classification] + 1
    }

    $summaryStatus = if (
        $outcomes.Count -eq $orderedStages.Count -and
        @($resolvedOutcomes | Where-Object { $_.status -cne 'Passed' }).Count -eq 0
    ) {
        'Passed'
    }
    else {
        [string]$resolvedOutcomes[-1].status
    }
    $timestamp = $NowUtc.ToUniversalTime().ToString(
        'yyyy-MM-ddTHH:mm:ss.fffffffZ',
        [Globalization.CultureInfo]::InvariantCulture
    )
    $summary = [pscustomobject][ordered]@{
        schemaVersion = '1.0'
        runId = $RunId.ToString('D').ToLowerInvariant()
        sourceCommit = $sourceCommit
        manifestDigest = [string]$manifest.digest
        startedAtUtc = $timestamp
        completedAtUtc = $timestamp
        status = $summaryStatus
        counts = [pscustomobject]$counts
        prerequisites = @(
            foreach ($outcome in $outcomes) {
                [pscustomobject][ordered]@{
                    id = [string]$outcome.id
                    status = [string]$resolvedById[[string]$outcome.id].status
                    inputDigest = [string]$outcome.inputDigest
                    evidenceDigest = Get-RunbookContentDigest -InputObject $outcome
                }
            }
        )
        actions = @(
            foreach ($outcome in $outcomes) {
                [pscustomobject][ordered]@{
                    id = [string]$outcome.id
                    classification = [string]$outcome.classification
                    status = [string]$resolvedById[[string]$outcome.id].status
                    evidenceRelativePath = [string]$outcome.evidenceRelativePath
                }
            }
        )
        nonClaims = @(
            'Subsystem evidence remains owned by each independently runnable subsystem.',
            'The umbrella supplied no authentication material or service write payload.'
        )
    }
    Write-TenantLifecycleEvidence `
        -RunDirectory $runDirectory `
        -RelativePath 'summary.json' `
        -Kind Summary `
        -InputObject $summary |
        Out-Null
}

return @($outcomes.ToArray())
