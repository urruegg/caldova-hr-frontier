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
    [scriptblock]$Clock
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
        if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            throw "CiPester.Path: '$selectedPath' is not an existing leaf."
        }
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

$resultParent = Split-Path -Parent $resolvedOutputPath
[void](New-Item -ItemType Directory -Path $resultParent -Force)
if (Test-Path -LiteralPath $resolvedOutputPath) {
    Remove-Item -LiteralPath $resolvedOutputPath -Force
}

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

$result = $null
$finishedAtUtc = $null
try {
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

if (-not (Test-Path -LiteralPath $resolvedOutputPath -PathType Leaf)) {
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
