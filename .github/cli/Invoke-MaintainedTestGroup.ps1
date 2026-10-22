[CmdletBinding(DefaultParameterSetName = 'NoTag')]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string[]]$Path,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$OutputPath,

    [Parameter(ParameterSetName = 'IncludeTag')]
    [ValidateSet('CICompatibilitySmoke')]
    [string]$Tag,

    [Parameter(ParameterSetName = 'ExcludeTag')]
    [ValidateSet('CICompatibilitySmoke')]
    [string]$ExcludeTag,

    [Parameter(DontShow)]
    [scriptblock]$PesterInvoker,

    [Parameter(DontShow)]
    [scriptblock]$ApplicationResolver,

    [Parameter(DontShow)]
    [scriptblock]$Clock,

    [Parameter(DontShow)]
    [scriptblock]$FileSystemProbe
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$repositoryPrefix = $repositoryRoot.TrimEnd(
    [IO.Path]::DirectorySeparatorChar,
    [IO.Path]::AltDirectorySeparatorChar
) + [IO.Path]::DirectorySeparatorChar

function Test-RepositoryContainedPath {
    param(
        [Parameter(Mandatory)]
        [string]$Candidate
    )

    $Candidate.StartsWith(
        $repositoryPrefix,
        [StringComparison]::OrdinalIgnoreCase
    )
}

if ($null -eq $FileSystemProbe) {
    $FileSystemProbe = {
        param([string]$LiteralPath)

        try {
            $attributes = [IO.File]::GetAttributes($LiteralPath)
        }
        catch [IO.FileNotFoundException] {
            return [pscustomobject]@{
                Exists = [bool]$false
                IsContainer = [bool]$false
                IsLeaf = [bool]$false
                Attributes = [IO.FileAttributes]::Normal
            }
        }
        catch [IO.DirectoryNotFoundException] {
            return [pscustomobject]@{
                Exists = [bool]$false
                IsContainer = [bool]$false
                IsLeaf = [bool]$false
                Attributes = [IO.FileAttributes]::Normal
            }
        }

        $isContainer = (
            $attributes -band [IO.FileAttributes]::Directory
        ) -ne 0
        [pscustomobject]@{
            Exists = [bool]$true
            IsContainer = [bool]$isContainer
            IsLeaf = [bool](-not $isContainer)
            Attributes = [IO.FileAttributes]$attributes
        }
    }
}

function Get-FileSystemState {
    param(
        [Parameter(Mandatory)]
        [string]$LiteralPath,

        [Parameter(Mandatory)]
        [ValidateSet('repository root', 'selected test path', 'output path')]
        [string]$Context
    )

    try {
        $responses = @(& $FileSystemProbe ([string]$LiteralPath))
    }
    catch {
        throw "CiPester.FileSystemProbe: cannot inspect the $Context."
    }
    if (
        $responses.Count -ne 1 -or
        $null -eq $responses[0].PSObject.Properties['Exists'] -or
        $null -eq $responses[0].PSObject.Properties['IsContainer'] -or
        $null -eq $responses[0].PSObject.Properties['IsLeaf'] -or
        $null -eq $responses[0].PSObject.Properties['Attributes']
    ) {
        throw "CiPester.FileSystemProbe: invalid state for the $Context."
    }

    try {
        [pscustomobject]@{
            Exists = [bool]$responses[0].Exists
            IsContainer = [bool]$responses[0].IsContainer
            IsLeaf = [bool]$responses[0].IsLeaf
            Attributes = [IO.FileAttributes]$responses[0].Attributes
        }
    }
    catch {
        throw "CiPester.FileSystemProbe: invalid state for the $Context."
    }
}

function Assert-NormalPathSegments {
    param(
        [Parameter(Mandatory)]
        [string]$Candidate,

        [Parameter(Mandatory)]
        [ValidateSet('selected test path', 'output path')]
        [string]$Context,

        [switch]$AllowMissing,

        [ValidateSet('Any', 'Container', 'Leaf')]
        [string]$FinalKind = 'Any'
    )

    $rootState = Get-FileSystemState `
        -LiteralPath $repositoryRoot `
        -Context 'repository root'
    if (-not $rootState.Exists -or -not $rootState.IsContainer) {
        throw 'CiPester.RepositoryRoot: repository root is not a normal directory.'
    }
    if (
        ($rootState.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0
    ) {
        throw 'CiPester.ReparsePoint: repository root is not a normal directory.'
    }

    if (
        [string]::Equals(
            $Candidate,
            $repositoryRoot,
            [StringComparison]::OrdinalIgnoreCase
        )
    ) {
        if ($FinalKind -ceq 'Leaf') {
            throw "CiPester.PathState: $Context is not a leaf."
        }
        $rootState
        return
    }
    if (-not (Test-RepositoryContainedPath -Candidate $Candidate)) {
        throw "CiPester.PathState: $Context is outside the repository."
    }

    $relativePath = $Candidate.Substring($repositoryPrefix.Length)
    [string[]]$segments = @(
        $relativePath.Split(
            [char[]]@(
                [IO.Path]::DirectorySeparatorChar,
                [IO.Path]::AltDirectorySeparatorChar
            ),
            [StringSplitOptions]::RemoveEmptyEntries
        )
    )
    $currentPath = $repositoryRoot
    $finalState = $rootState
    $missingSegmentSeen = $false
    for ($index = 0; $index -lt $segments.Count; $index++) {
        $currentPath = Join-Path $currentPath $segments[$index]
        if ($missingSegmentSeen) {
            continue
        }

        $state = Get-FileSystemState `
            -LiteralPath $currentPath `
            -Context $Context
        $finalState = $state
        if (-not $state.Exists) {
            if ($AllowMissing) {
                $missingSegmentSeen = $true
                continue
            }
            throw "CiPester.PathState: required $Context segment is missing."
        }
        if (
            ($state.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0
        ) {
            throw "CiPester.ReparsePoint: $Context contains a reparse point."
        }

        $isFinalSegment = $index -eq ($segments.Count - 1)
        if (-not $isFinalSegment -and -not $state.IsContainer) {
            throw "CiPester.PathState: $Context has a non-directory ancestor."
        }
        if ($isFinalSegment) {
            if ($FinalKind -ceq 'Container' -and -not $state.IsContainer) {
                throw "CiPester.PathState: $Context is not a directory."
            }
            if ($FinalKind -ceq 'Leaf' -and -not $state.IsLeaf) {
                throw "CiPester.PathState: $Context is not a leaf."
            }
        }
    }
    $finalState
}

if ($Path.Count -eq 0) {
    throw 'CiPester.Path: at least one test path is required.'
}

[string[]]$resolvedPaths = @(
    foreach ($selectedPath in $Path) {
        if ([string]::IsNullOrWhiteSpace($selectedPath)) {
            throw 'CiPester.Path: selected paths cannot be empty.'
        }

        $candidate = if ([IO.Path]::IsPathRooted($selectedPath)) {
            [IO.Path]::GetFullPath($selectedPath)
        }
        else {
            [IO.Path]::GetFullPath((Join-Path $repositoryRoot $selectedPath))
        }
        if (-not (Test-RepositoryContainedPath -Candidate $candidate)) {
            throw "CiPester.Path: '$selectedPath' resolves outside the repository."
        }
        if (-not $candidate.EndsWith('.Tests.ps1', [StringComparison]::Ordinal)) {
            throw "CiPester.Path: '$selectedPath' is not a canonical test file."
        }
        $null = Assert-NormalPathSegments `
            -Candidate $candidate `
            -Context 'selected test path' `
            -FinalKind Leaf
        [string]$candidate
    }
)

if (-not [IO.Path]::IsPathRooted($OutputPath)) {
    throw 'CiPester.OutputPath: an absolute path is required.'
}
$resolvedOutputPath = [IO.Path]::GetFullPath($OutputPath)
if (-not (Test-RepositoryContainedPath -Candidate $resolvedOutputPath)) {
    throw 'CiPester.OutputPath: the result path must remain beneath the repository.'
}
if (-not $resolvedOutputPath.EndsWith('.xml', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'CiPester.OutputPath: the result path must end in .xml.'
}
Import-Module Pester -RequiredVersion 5.7.1 -Force -ErrorAction Stop
$loadedPesterModules = @(Get-Module -Name Pester)
if (
    $loadedPesterModules.Count -ne 1 -or
    $loadedPesterModules[0].Version -ne [version]'5.7.1'
) {
    throw 'CiPester.PesterVersion: exact loaded version 5.7.1 is required.'
}
$loadedPesterVersion = [version]$loadedPesterModules[0].Version

if ($null -eq $PesterInvoker) {
    $PesterInvoker = {
        param([PesterConfiguration]$Configuration)

        Set-StrictMode -Off
        Invoke-Pester -Configuration $Configuration
    }
}

if ($null -eq $ApplicationResolver) {
    $ApplicationResolver = {
        param(
            [ValidateSet('git.exe', 'pwsh.exe')]
            [string]$Name
        )

        [string[]]@(
            Get-Command `
                -Name $Name `
                -CommandType Application `
                -All `
                -ErrorAction SilentlyContinue |
                ForEach-Object { [string]$_.Source }
        )
    }
}

if ($null -eq $Clock) {
    $Clock = {
        param()

        [datetime]::UtcNow
    }
}

[string[]]$gitApplications = @(& $ApplicationResolver 'git.exe')
[string[]]$pwshApplications = @(& $ApplicationResolver 'pwsh.exe')
if (
    $gitApplications.Count -eq 0 -or
    [string]::IsNullOrWhiteSpace($gitApplications[0])
) {
    throw 'CiPester.Application: git.exe did not resolve to a scalar application.'
}
if (
    $pwshApplications.Count -eq 0 -or
    [string]::IsNullOrWhiteSpace($pwshApplications[0])
) {
    throw 'CiPester.Application: pwsh.exe did not resolve to a scalar application.'
}
[string]$gitApplication = $gitApplications[0]
[string]$pwshApplication = $pwshApplications[0]

$configuration = New-PesterConfiguration
$configuration.Run.Path = [string[]]$resolvedPaths
$configuration.Run.Throw = $true
$configuration.Run.Exit = $false
$configuration.Run.PassThru = $true
$configuration.Output.Verbosity = 'Detailed'
$configuration.TestResult.Enabled = $true
$configuration.TestResult.OutputFormat = 'NUnitXml'
$configuration.TestResult.OutputPath = $resolvedOutputPath
if ($PSCmdlet.ParameterSetName -ceq 'IncludeTag') {
    $configuration.Filter.Tag = [string[]]@($Tag)
}
elseif ($PSCmdlet.ParameterSetName -ceq 'ExcludeTag') {
    $configuration.Filter.ExcludeTag = [string[]]@($ExcludeTag)
}

$initialOutputState = Assert-NormalPathSegments `
    -Candidate $resolvedOutputPath `
    -Context 'output path' `
    -AllowMissing `
    -FinalKind Leaf
if ($initialOutputState.Exists) {
    try {
        Remove-Item `
            -LiteralPath $resolvedOutputPath `
            -Force `
            -ErrorAction Stop
    }
    catch {
        throw 'CiPester.OutputPathState: validated output target could not be removed.'
    }
}

$postRemovalState = Assert-NormalPathSegments `
    -Candidate $resolvedOutputPath `
    -Context 'output path' `
    -AllowMissing `
    -FinalKind Leaf
if ($postRemovalState.Exists) {
    throw 'CiPester.OutputPathState: output target remains after removal.'
}

$resultParent = Split-Path -Parent $resolvedOutputPath
try {
    [void](New-Item `
        -ItemType Directory `
        -Path $resultParent `
        -Force `
        -ErrorAction Stop)
}
catch {
    throw 'CiPester.OutputPathState: output parent could not be created.'
}
$null = Assert-NormalPathSegments `
    -Candidate $resultParent `
    -Context 'output path' `
    -FinalKind Container

$startedAtUtc = & $Clock
Write-Host ('CI Pester selected paths={0}' -f ($resolvedPaths -join ';'))
Write-Host (
    'CI Pester host={0} {1}' -f
    [string]$PSVersionTable.PSEdition,
    [string]$PSVersionTable.PSVersion
)
Write-Host ('CI Pester version={0}' -f $loadedPesterVersion)
Write-Host ('CI Pester git applications={0}' -f ($gitApplications -join ';'))
Write-Host ('CI Pester pwsh applications={0}' -f ($pwshApplications -join ';'))
Write-Host ('CI Pester selected git application={0}' -f $gitApplication)
Write-Host ('CI Pester selected pwsh application={0}' -f $pwshApplication)
Write-Host ('CI Pester start={0:o}' -f $startedAtUtc)

$result = $null
$finishedAtUtc = $null
try {
    $preInvocationState = Assert-NormalPathSegments `
        -Candidate $resolvedOutputPath `
        -Context 'output path' `
        -AllowMissing `
        -FinalKind Leaf
    if ($preInvocationState.Exists) {
        throw 'CiPester.OutputPathState: output target must be missing before Pester.'
    }

    $invocationResults = @(& $PesterInvoker $configuration)
    if ($invocationResults.Count -ne 1) {
        throw 'CiPester.ResultObject'
    }
    $result = $invocationResults[0]
    if ([int]$result.TotalCount -eq 0) {
        throw 'CiPester.ZeroTests'
    }
    if ([int]$result.FailedCount -gt 0) {
        throw 'CiPester.FailedTests'
    }
    if ([int]$result.FailedContainersCount -gt 0) {
        throw 'CiPester.FailedContainers'
    }
    if ([string]$result.Result -cne 'Passed') {
        throw 'CiPester.ResultNotPassed'
    }
}
finally {
    $finishedAtUtc = & $Clock
    Write-Host ('CI Pester finish={0:o}' -f $finishedAtUtc)
}

$finalOutputState = Assert-NormalPathSegments `
    -Candidate $resolvedOutputPath `
    -Context 'output path' `
    -AllowMissing `
    -FinalKind Leaf
if (-not $finalOutputState.Exists) {
    throw 'CiPester.ResultFileMissing'
}

[pscustomobject][ordered]@{
    TotalCount = [int]$result.TotalCount
    FailedCount = [int]$result.FailedCount
    FailedContainersCount = [int]$result.FailedContainersCount
    Result = [string]$result.Result
    OutputPath = [string]$resolvedOutputPath
    StartedAtUtc = $startedAtUtc.ToString('o')
    FinishedAtUtc = $finishedAtUtc.ToString('o')
}
