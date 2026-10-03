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
        'TenantLifecycle.SubsystemInvoker.Prohibited'
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

$modulePath = [IO.Path]::GetFullPath((
    Join-Path $PSScriptRoot (
        '..\modules\Caldova.HrFrontier.Bootstrap\' +
        'Caldova.HrFrontier.Bootstrap.psd1'
    )
))
Import-Module $modulePath -Force

function Assert-TenantLifecycleSubsystemOutcome {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowNull()][object]$Outcome,
        [Parameter(Mandatory)][string]$ExpectedStage,
        [Parameter(Mandatory)][string]$ExpectedInputDigest,
        [switch]$RequireReadBackDigest
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
                $property.MemberType -ne 'NoteProperty') {
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
            -not ($Outcome.evidenceRelativePath -is [string]) -or
            [string]::IsNullOrWhiteSpace(
                [string]$Outcome.evidenceRelativePath
            )) {
            throw [IO.InvalidDataException]::new()
        }

        if (($RequireReadBackDigest -or
                $null -ne $Outcome.readBackDigest) -and
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
if (@($Stages).Count -eq 0) {
    throw [IO.InvalidDataException]::new('TenantLifecycle.Stages.Required')
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
    if ([int]$sourceResult.exitCode -ne 0 -or
        $currentSourceCommit -cnotmatch '^[0-9a-f]{40}$' -or
        -not [StringComparer]::Ordinal.Equals(
            $currentSourceCommit,
            $ExpectedSourceCommit.ToLowerInvariant()
        )) {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.Source.Commit'
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
    if (-not [string]::IsNullOrWhiteSpace([string]$cleanResult.stdout)) {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.Source.Clean'
        )
    }

    return $currentSourceCommit
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
    param()

    try {
        return Test-TenantLifecyclePrivateBoundary `
            -PublicTenantKey $PublicTenantKey `
            -IntentPath $TenantConfigurationPath `
            -StatePath $TenantStatePath `
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

$sourceCommit = Get-TenantLifecycleSourceBinding
$privateBoundary = Get-TenantLifecyclePrivateBinding
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

$outcomes = [Collections.Generic.List[object]]::new()
$nodes = [Collections.Generic.List[object]]::new()
for ($index = 0; $index -lt $orderedStages.Count; $index++) {
    $stage = $orderedStages[$index]
    $controlRecord = [pscustomobject][ordered]@{
        runId = $RunId.ToString('D').ToLowerInvariant()
        runDirectoryLabel = $RunId.ToString('D').ToLowerInvariant()
        publicTenantKey = $PublicTenantKey
        sourceCommit = $sourceCommit
        machineLabel = [Environment]::MachineName
        operatorLabel = [Environment]::UserName
        toolIdentities = @()
        stageInputDigest = $null
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

return @($outcomes.ToArray())
