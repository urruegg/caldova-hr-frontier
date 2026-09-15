[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$skillsRoot = Join-Path $repositoryRoot '.github\skills'
$skillsPrefix = [IO.Path]::GetFullPath($skillsRoot).TrimEnd('\') + '\'
$failures = [Collections.Generic.List[string]]::new()

function Add-Failure {
    param([string]$Message)
    [void]$failures.Add($Message)
}

function Test-RequiredContent {
    param([string]$RelativePath, [string[]]$Terms, [string[]]$ExactLines = @())

    $path = Join-Path $repositoryRoot ($RelativePath.Replace('/', '\'))
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Add-Failure "Missing file: $RelativePath"
        return
    }
    try {
        [string[]]$lines = @(Get-Content -LiteralPath $path)
        $content = $lines -join "`n"
    }
    catch {
        Add-Failure "Cannot read file: $RelativePath"
        return
    }
    foreach ($term in $Terms) {
        if ($content.IndexOf($term, [StringComparison]::Ordinal) -lt 0) {
            Add-Failure "$RelativePath does not contain '$term'."
        }
    }
    foreach ($exactLine in $ExactLines) {
        if (-not ($lines -ccontains $exactLine)) {
            Add-Failure "$RelativePath does not contain the exact line '$exactLine'."
        }
    }
}

$baseFolders = @(
    '.github/agent-policy', '.github/agents', '.github/cli', '.github/instructions',
    '.github/issue-templates', '.github/skills', '.github/workflows', 'docs/adr',
    'docs/archive', 'docs/brandkit', 'docs/business', 'docs/delegation', 'docs/ideas',
    'docs/issues', 'docs/plans', 'docs/reviews', 'docs/specs', 'docs/sprints', 'docs/templates'
)
foreach ($relativeFolder in $baseFolders) {
    $folder = Join-Path $repositoryRoot ($relativeFolder.Replace('/', '\'))
    if (-not (Test-Path -LiteralPath $folder -PathType Container)) {
        Add-Failure "Missing directory: $relativeFolder"
        continue
    }
    $readme = Join-Path $folder 'README.md'
    if (-not (Test-Path -LiteralPath $readme -PathType Leaf)) {
        Add-Failure "Missing README.md: $relativeFolder/README.md"
        continue
    }
    try { $readmeContent = Get-Content -LiteralPath $readme -Raw }
    catch { Add-Failure "Cannot read README.md: $relativeFolder/README.md"; continue }
    if ([string]::IsNullOrWhiteSpace($readmeContent)) {
        Add-Failure "Empty README.md: $relativeFolder/README.md"
    }
}
foreach ($legacyPath in @('.github/ISSUE_TEMPLATE', 'docs/storyboard')) {
    if (Test-Path -LiteralPath (Join-Path $repositoryRoot ($legacyPath.Replace('/', '\')))) {
        Add-Failure "Legacy path must not exist: $legacyPath"
    }
}

$skillNames = @(
    'brainstorming', 'dispatching-parallel-agents', 'executing-plans',
    'finishing-a-development-branch', 'receiving-code-review', 'requesting-code-review',
    'subagent-driven-development', 'systematic-debugging', 'test-driven-development',
    'using-git-worktrees', 'using-superpowers', 'verification-before-completion',
    'writing-plans', 'writing-skills'
)
$expectedSkills = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$actualSkills = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach ($skillName in $skillNames) { [void]$expectedSkills.Add($skillName) }
if (Test-Path -LiteralPath $skillsRoot -PathType Container) {
    foreach ($directory in @(Get-ChildItem -LiteralPath $skillsRoot -Directory -Force)) {
        [void]$actualSkills.Add($directory.Name)
        if (-not $expectedSkills.Contains($directory.Name)) {
            Add-Failure "Unexpected skill directory: $($directory.Name)"
        }
    }
}
foreach ($skillName in $skillNames) {
    if (-not $actualSkills.Contains($skillName)) {
        Add-Failure "Missing skill directory: $skillName"
    }
}

$namePattern = '^name:[ \t]*(?:([a-z0-9-]+)|''([a-z0-9-]+)''|"([a-z0-9-]+)")[ \t]*$'
foreach ($skillName in $skillNames) {
    if (-not $actualSkills.Contains($skillName)) { continue }
    $relativeSkillFile = "$skillName/SKILL.md"
    $skillFile = Join-Path $skillsRoot ($relativeSkillFile.Replace('/', '\'))
    if (-not (Test-Path -LiteralPath $skillFile -PathType Leaf)) {
        Add-Failure "Missing skill file: $relativeSkillFile"
        continue
    }
    try { [string[]]$lines = @(Get-Content -LiteralPath $skillFile) }
    catch { Add-Failure "Cannot read skill file: $relativeSkillFile"; continue }
    if ($lines.Count -eq 0 -or $lines[0] -cne '---') {
        Add-Failure "Missing leading YAML frontmatter: $relativeSkillFile"
        continue
    }
    $closingIndex = -1
    for ($lineIndex = 1; $lineIndex -lt $lines.Count; $lineIndex++) {
        if ($lines[$lineIndex] -ceq '---') { $closingIndex = $lineIndex; break }
    }
    if ($closingIndex -lt 0) {
        Add-Failure "Unclosed YAML frontmatter: $relativeSkillFile"
        continue
    }
    $nameLines = [Collections.Generic.List[string]]::new()
    for ($lineIndex = 1; $lineIndex -lt $closingIndex; $lineIndex++) {
        if ($lines[$lineIndex].StartsWith('name:', [StringComparison]::Ordinal)) {
            [void]$nameLines.Add($lines[$lineIndex])
        }
    }
    if ($nameLines.Count -ne 1) {
        Add-Failure "$relativeSkillFile must contain exactly one frontmatter name."
        continue
    }
    $nameMatch = [regex]::Match($nameLines[0], $namePattern)
    if (-not $nameMatch.Success) {
        Add-Failure "Invalid frontmatter name in $relativeSkillFile."
        continue
    }
    $declaredName = $nameMatch.Groups[1].Value
    if (-not $declaredName) { $declaredName = $nameMatch.Groups[2].Value }
    if (-not $declaredName) { $declaredName = $nameMatch.Groups[3].Value }
    if ($declaredName -cne $skillName) {
        Add-Failure "Skill name does not match directory: $relativeSkillFile declares '$declaredName'."
    }
}

function Test-SafeManifestPath {
    param([string]$RelativePath)

    try {
        $segments = $RelativePath.Split([char[]]@('/'), [StringSplitOptions]::None)
        $unsafe = $RelativePath.Contains('\') -or $RelativePath.StartsWith('/', [StringComparison]::Ordinal) -or
            [IO.Path]::IsPathRooted($RelativePath) -or $RelativePath -match '^[A-Za-z]:'
        foreach ($segment in $segments) {
            if ($segment.Length -eq 0 -or $segment -ceq '.' -or $segment -ceq '..') { $unsafe = $true }
        }
        if ($segments.Count -eq 0 -or -not $expectedSkills.Contains($segments[0])) { $unsafe = $true }
        if ($unsafe) { Add-Failure "Unsafe manifest path: $RelativePath"; return $false }
        $resolved = [IO.Path]::GetFullPath((Join-Path $skillsRoot ($RelativePath.Replace('/', '\'))))
        if (-not $resolved.StartsWith($skillsPrefix, [StringComparison]::OrdinalIgnoreCase)) {
            Add-Failure "Unsafe manifest path: $RelativePath"
            return $false
        }
    }
    catch {
        Add-Failure "Manifest path cannot be resolved: $RelativePath"
        return $false
    }
    return $true
}

$manifestFile = Join-Path $skillsRoot 'SUPERPOWERS_SHA256SUMS'
$manifestEntries = [Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
$seenManifestPaths = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
if (-not (Test-Path -LiteralPath $manifestFile -PathType Leaf)) {
    Add-Failure 'Missing file: .github/skills/SUPERPOWERS_SHA256SUMS'
}
else {
    try { [string[]]$manifestLines = @(Get-Content -LiteralPath $manifestFile) }
    catch { Add-Failure 'Cannot read file: .github/skills/SUPERPOWERS_SHA256SUMS'; $manifestLines = @() }
    if ($manifestLines.Count -eq 0) { Add-Failure 'Manifest must not be empty.' }
    $previousPath = $null
    $reportedUnsorted = $false
    for ($lineIndex = 0; $lineIndex -lt $manifestLines.Count; $lineIndex++) {
        $manifestMatch = [regex]::Match($manifestLines[$lineIndex], '^([0-9a-f]{64})  (.+)$')
        if (-not $manifestMatch.Success) {
            Add-Failure "Malformed manifest line $($lineIndex + 1)."
            continue
        }
        $hash = $manifestMatch.Groups[1].Value
        $relativePath = $manifestMatch.Groups[2].Value
        if ($null -ne $previousPath -and [StringComparer]::Ordinal.Compare($previousPath, $relativePath) -gt 0 -and -not $reportedUnsorted) {
            Add-Failure 'Manifest paths are not ordinally sorted.'
            $reportedUnsorted = $true
        }
        $previousPath = $relativePath
        if (-not $seenManifestPaths.Add($relativePath)) {
            Add-Failure "Duplicate manifest path: $relativePath"
            continue
        }
        if (Test-SafeManifestPath $relativePath) { $manifestEntries.Add($relativePath, $hash) }
    }
}

$runtimeFiles = [Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
foreach ($skillName in $skillNames) {
    if (-not $actualSkills.Contains($skillName)) { continue }
    try { $files = @(Get-ChildItem -LiteralPath (Join-Path $skillsRoot $skillName) -File -Recurse -Force) }
    catch { Add-Failure "Cannot enumerate runtime files for skill: $skillName"; continue }
    foreach ($file in $files) {
        $relativePath = $file.FullName.Substring($skillsPrefix.Length).Replace('\', '/')
        $runtimeFiles[$relativePath] = $file.FullName
    }
}
[string[]]$runtimePaths = @($runtimeFiles.Keys)
[Array]::Sort($runtimePaths, [StringComparer]::Ordinal)
foreach ($relativePath in $runtimePaths) {
    if (-not $manifestEntries.ContainsKey($relativePath)) {
        Add-Failure "Runtime file is missing from manifest: $relativePath"
        continue
    }
    try { $actualHash = (Get-FileHash -LiteralPath $runtimeFiles[$relativePath] -Algorithm SHA256).Hash.ToLowerInvariant() }
    catch { Add-Failure "Cannot hash runtime file: $relativePath"; continue }
    if ($actualHash -cne $manifestEntries[$relativePath]) {
        Add-Failure "Hash mismatch for runtime file: $relativePath"
    }
}
[string[]]$manifestPaths = @($manifestEntries.Keys)
[Array]::Sort($manifestPaths, [StringComparer]::Ordinal)
foreach ($relativePath in $manifestPaths) {
    if (-not $runtimeFiles.ContainsKey($relativePath)) {
        Add-Failure "Manifest path is not a runtime file: $relativePath"
    }
}

Test-RequiredContent 'AGENTS.md' @('.github/skills', 'using-superpowers')
Test-RequiredContent '.github/copilot-instructions.md' @('.github/skills', 'using-superpowers')
Test-RequiredContent '.github/skills/SUPERPOWERS_VERSION' @(
    'https://github.com/obra/superpowers', 'v6.3.0', 'b36e0829c6d0140e93cfef2ca599b1b07d4a7797'
) @('manifest=SUPERPOWERS_SHA256SUMS')
Test-RequiredContent '.github/skills/LICENSE.superpowers' @('MIT License', 'Copyright (c) 2025 Jesse Vincent')
Test-RequiredContent 'README.md' @('Superpowers', 'v6.3.0', '.github/skills', 'verify-repository-setup.ps1')

if ($failures.Count -gt 0) {
    foreach ($failure in $failures) { Write-Output "ERROR: $failure" }
    Write-Output "Repository setup validation failed with $($failures.Count) error(s)."
    exit 1
}
Write-Output 'Repository setup validation passed.'
