[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Repository', 'Infrastructure', 'Hr', 'Lifecycle')]
    [string]$Group,

    [ValidateScript({ [IO.Path]::IsPathRooted($_) })]
    [string]$RepositoryRoot = [IO.Path]::GetFullPath((
        Join-Path $PSScriptRoot '..\..'
    )),

    [Parameter(DontShow)]
    [scriptblock]$TrackedPathProvider
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$maintainedRoots = [ordered]@{
    Repository = '.github/cli/tests'
    Infrastructure = 'infra/tests/pester'
    Hr = 'hr/tests/pester'
}
$lifecycleAllowlist = [string[]]@(
    'infra/tests/pester/TenantLifecycleContracts.Tests.ps1'
    'infra/tests/pester/TenantLifecycleOrchestration.Tests.ps1'
    'infra/tests/pester/RunbookContracts.Tests.ps1'
    'infra/tests/pester/RunbookStaticSafety.Tests.ps1'
    'infra/tests/pester/RunbookDocumentation.Tests.ps1'
)

function Test-MaintainedRoot {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    foreach ($relativeRoot in $maintainedRoots.Values) {
        if ($Path.StartsWith("$relativeRoot/", [StringComparison]::Ordinal)) {
            return $true
        }
    }

    return $false
}

function Get-RepositoryRelativePath {
    param(
        [Parameter(Mandatory)]
        [string]$FullName,

        [Parameter(Mandatory)]
        [string]$RootPrefix
    )

    if (-not $FullName.StartsWith($RootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "MaintainedTests.Root: '$FullName' is outside '$resolvedRepositoryRoot'."
    }

    $FullName.Substring($RootPrefix.Length).Replace('\', '/')
}

try {
    $resolvedRepositoryRoot = [IO.Path]::GetFullPath($RepositoryRoot)
    $repositoryRootItem = Get-Item -LiteralPath $resolvedRepositoryRoot -Force
}
catch {
    throw "MaintainedTests.Root: repository root '$RepositoryRoot' is unavailable. $($_.Exception.Message)"
}
if (-not $repositoryRootItem.PSIsContainer) {
    throw "MaintainedTests.Root: repository root '$resolvedRepositoryRoot' is not a directory."
}
$resolvedRepositoryRoot = [IO.Path]::GetFullPath([string]$repositoryRootItem.FullName)
$rootPrefix = $resolvedRepositoryRoot.TrimEnd(
    [IO.Path]::DirectorySeparatorChar,
    [IO.Path]::AltDirectorySeparatorChar
) + [IO.Path]::DirectorySeparatorChar

[string[]]$maintainedInventory = @(
    foreach ($relativeRoot in $maintainedRoots.Values) {
        $absoluteRoot = Join-Path $resolvedRepositoryRoot $relativeRoot.Replace('/', '\')
        if (-not (Test-Path -LiteralPath $absoluteRoot -PathType Container)) {
            throw "MaintainedTests.Root: maintained root '$relativeRoot' is unavailable."
        }

        foreach (
            $file in @(
                Get-ChildItem `
                    -LiteralPath $absoluteRoot `
                    -Filter '*.Tests.ps1' `
                    -File `
                    -Recurse
            )
        ) {
            $relativePath = Get-RepositoryRelativePath `
                -FullName ([string]$file.FullName) `
                -RootPrefix $rootPrefix
            if (-not $relativePath.EndsWith('.Tests.ps1', [StringComparison]::Ordinal)) {
                throw "MaintainedTests.Case: '$relativePath' does not use the canonical '.Tests.ps1' suffix."
            }
            [string]$relativePath
        }
    }
)

$inventorySet = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach ($relativePath in $maintainedInventory) {
    if (-not $inventorySet.Add($relativePath)) {
        throw "MaintainedTests.Duplicate: recursive inventory contains '$relativePath' more than once."
    }
}

if ($null -eq $TrackedPathProvider) {
    $gitApplication = Get-Command `
        -Name git.exe `
        -CommandType Application `
        -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($null -eq $gitApplication) {
        throw 'MaintainedTests.TrackedInventory: git.exe is unavailable.'
    }
    $gitPath = [string]$gitApplication.Source
    if ([string]::IsNullOrWhiteSpace($gitPath)) {
        throw 'MaintainedTests.TrackedInventory: git.exe resolved without a scalar source path.'
    }

    $TrackedPathProvider = {
        param([string]$ProviderRoot)

        [string[]]$trackedRows = @(
            & $gitPath -C $ProviderRoot -c core.quotepath=false ls-files
        )
        if ($LASTEXITCODE -ne 0) {
            throw "MaintainedTests.TrackedInventory: git ls-files exited with code $LASTEXITCODE."
        }

        [string[]]@(
            $trackedRows |
                Where-Object {
                    $_.EndsWith('.Tests.ps1', [StringComparison]::OrdinalIgnoreCase)
                }
        )
    }.GetNewClosure()
}

try {
    [string[]]$trackedTestPaths = @(
        & $TrackedPathProvider ([string]$resolvedRepositoryRoot)
    )
}
catch {
    throw "MaintainedTests.TrackedInventory: tracked-path provider failed. $($_.Exception.Message)"
}

$trackedSet = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$trackedIgnoreCaseSet = [Collections.Generic.HashSet[string]]::new(
    [StringComparer]::OrdinalIgnoreCase
)
foreach ($trackedPath in $trackedTestPaths) {
    if (
        [string]::IsNullOrWhiteSpace($trackedPath) -or
        [IO.Path]::IsPathRooted($trackedPath) -or
        $trackedPath.Contains('\') -or
        -not $trackedPath.EndsWith(
            '.Tests.ps1',
            [StringComparison]::OrdinalIgnoreCase
        )
    ) {
        throw "MaintainedTests.TrackedInventory: invalid tracked test path '$trackedPath'."
    }
    if (-not $trackedSet.Add($trackedPath)) {
        throw "MaintainedTests.TrackedInventory: duplicate canonical tracked row '$trackedPath'."
    }
    [void]$trackedIgnoreCaseSet.Add($trackedPath)
}

foreach ($relativePath in $maintainedInventory) {
    if ($trackedSet.Contains($relativePath)) {
        continue
    }
    if ($trackedIgnoreCaseSet.Contains($relativePath)) {
        throw "MaintainedTests.Case: tracked spelling differs from '$relativePath'."
    }
    throw "MaintainedTests.Unowned: maintained leaf '$relativePath' is not tracked."
}

foreach ($trackedPath in $trackedTestPaths) {
    if (-not (Test-MaintainedRoot -Path $trackedPath)) {
        throw "MaintainedTests.Unowned: tracked test '$trackedPath' is outside the maintained roots."
    }
    if ($inventorySet.Contains($trackedPath)) {
        continue
    }

    $matchingInventoryPath = @(
        $maintainedInventory |
            Where-Object {
                [string]::Equals(
                    $_,
                    $trackedPath,
                    [StringComparison]::OrdinalIgnoreCase
                )
            }
    ) | Select-Object -First 1
    if ($null -ne $matchingInventoryPath) {
        throw "MaintainedTests.Case: tracked spelling '$trackedPath' differs from '$matchingInventoryPath'."
    }
    throw "MaintainedTests.Unowned: tracked test '$trackedPath' is not a real maintained leaf."
}

$lifecycleSet = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach ($relativePath in $lifecycleAllowlist) {
    if (-not $lifecycleSet.Add($relativePath)) {
        throw "MaintainedTests.Lifecycle: duplicate allowlist path '$relativePath'."
    }

    $absolutePath = Join-Path $resolvedRepositoryRoot $relativePath.Replace('/', '\')
    if (Test-Path -LiteralPath $absolutePath -PathType Container) {
        throw "MaintainedTests.Leaf: lifecycle path '$relativePath' is a directory."
    }
    if (-not (Test-Path -LiteralPath $absolutePath -PathType Leaf)) {
        throw "MaintainedTests.Lifecycle: required lifecycle leaf '$relativePath' is missing."
    }
}

$groups = [ordered]@{
    Repository = [string[]]@(
        $maintainedInventory |
            Where-Object {
                $_.StartsWith(
                    "$($maintainedRoots.Repository)/",
                    [StringComparison]::Ordinal
                )
            }
    )
    Infrastructure = [string[]]@(
        $maintainedInventory |
            Where-Object {
                $_.StartsWith(
                    "$($maintainedRoots.Infrastructure)/",
                    [StringComparison]::Ordinal
                ) -and
                -not $lifecycleSet.Contains($_)
            }
    )
    Hr = [string[]]@(
        $maintainedInventory |
            Where-Object {
                $_.StartsWith(
                    "$($maintainedRoots.Hr)/",
                    [StringComparison]::Ordinal
                )
            }
    )
    Lifecycle = [string[]]@($lifecycleAllowlist)
}

foreach ($groupName in $groups.Keys) {
    [string[]]$groupPaths = @($groups[$groupName])
    if ($groupPaths.Count -eq 0) {
        throw "MaintainedTests.Empty: group '$groupName' has no test paths."
    }

    $groupSet = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($relativePath in $groupPaths) {
        if (-not $groupSet.Add($relativePath)) {
            throw "MaintainedTests.Duplicate: group '$groupName' repeats '$relativePath'."
        }

        $absolutePath = Join-Path $resolvedRepositoryRoot $relativePath.Replace('/', '\')
        if (-not (Test-Path -LiteralPath $absolutePath -PathType Leaf)) {
            throw "MaintainedTests.Leaf: '$relativePath' is not a real leaf."
        }
        if (-not $trackedSet.Contains($relativePath)) {
            if ($trackedIgnoreCaseSet.Contains($relativePath)) {
                throw "MaintainedTests.Case: tracked spelling differs from '$relativePath'."
            }
            throw "MaintainedTests.Unowned: selected path '$relativePath' is not tracked."
        }
    }
}

$groupNames = [string[]]@($groups.Keys)
for ($left = 0; $left -lt $groupNames.Count; $left++) {
    for ($right = $left + 1; $right -lt $groupNames.Count; $right++) {
        $rightSet = [Collections.Generic.HashSet[string]]::new(
            [string[]]$groups[$groupNames[$right]],
            [StringComparer]::Ordinal
        )
        foreach ($relativePath in $groups[$groupNames[$left]]) {
            if ($rightSet.Contains($relativePath)) {
                throw "MaintainedTests.Overlap: '$relativePath' belongs to '$($groupNames[$left])' and '$($groupNames[$right])'."
            }
        }
    }
}

[string[]]$expectedLifecycle = @($lifecycleAllowlist)
[string[]]$actualLifecycle = @($groups.Lifecycle)
[Array]::Sort($expectedLifecycle, [StringComparer]::Ordinal)
[Array]::Sort($actualLifecycle, [StringComparer]::Ordinal)
if (($actualLifecycle -join "`n") -cne ($expectedLifecycle -join "`n")) {
    throw 'MaintainedTests.Lifecycle: selected lifecycle group differs from the exact allowlist.'
}

$unionSet = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach ($groupName in $groups.Keys) {
    foreach ($relativePath in $groups[$groupName]) {
        if (-not $unionSet.Add($relativePath)) {
            throw "MaintainedTests.Overlap: union repeats '$relativePath'."
        }
    }
}
if ($unionSet.Count -ne $inventorySet.Count) {
    throw 'MaintainedTests.Unowned: selected union does not equal the recursive inventory.'
}
foreach ($relativePath in $maintainedInventory) {
    if (-not $unionSet.Contains($relativePath)) {
        throw "MaintainedTests.Unowned: recursive leaf '$relativePath' has no owner."
    }
}

[string[]]$selected = @($groups[$Group])
[Array]::Sort($selected, [StringComparer]::Ordinal)
$selected
