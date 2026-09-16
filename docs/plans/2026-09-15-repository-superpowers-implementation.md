# Repository Superpowers Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bundle Superpowers v6.3.0 and the approved repository folder structure so GitHub Copilot in VS Code and Copilot CLI use the same workflows from a normal clone.

**Architecture:** GitHub Copilot discovers unchanged upstream skills from `.github/skills/`. A small PowerShell setup validator checks the fixed repository contract, while a pinned SHA-256 manifest proves the exact vendored runtime file set and contents without parsing Markdown bodies or links. Repository-owned bootstrap instructions, version metadata, an upstream license copy, and folder READMEs make the bundle reviewable and maintainable.

**Tech Stack:** GitHub Copilot Agent Skills, Markdown, PowerShell 5.1+, Git

---

## Task 1: Add the Repository Setup Verifier

**Files:**

- Create: `.github/cli/verify-repository-setup.ps1`

- [ ] **Step 1: Write the failing validation script**

Create `.github/cli/verify-repository-setup.ps1` with this content. Use only Windows PowerShell/.NET built-ins; do not parse Markdown bodies or links:

```powershell
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$failures = [System.Collections.Generic.List[string]]::new()
function Add-ValidationFailure {
    param([Parameter(Mandatory)][string]$Message)
    $failures.Add($Message)
}
$requiredDirectories = @(
    '.github/agent-policy', '.github/agents', '.github/cli', '.github/instructions',
    '.github/issue-templates', '.github/skills', '.github/workflows', 'docs/adr',
    'docs/archive', 'docs/brandkit', 'docs/business', 'docs/delegation', 'docs/ideas',
    'docs/issues', 'docs/plans', 'docs/reviews', 'docs/specs', 'docs/sprints', 'docs/templates'
)
foreach ($relativeDirectory in $requiredDirectories) {
    $directory = Join-Path $repositoryRoot $relativeDirectory
    if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
        Add-ValidationFailure "Missing required directory: $relativeDirectory"
        continue
    }

    $readme = Join-Path $directory 'README.md'
    if (-not (Test-Path -LiteralPath $readme -PathType Leaf)) {
        Add-ValidationFailure "Missing folder README: $relativeDirectory/README.md"
        continue
    }

    if ([string]::IsNullOrWhiteSpace((Get-Content -LiteralPath $readme -Raw))) {
        Add-ValidationFailure "Empty folder README: $relativeDirectory/README.md"
    }
}
foreach ($excludedDirectory in @('.github/ISSUE_TEMPLATE', 'docs/storyboard')) {
    if (Test-Path -LiteralPath (Join-Path $repositoryRoot $excludedDirectory)) {
        Add-ValidationFailure "Excluded directory exists: $excludedDirectory"
    }
}
$expectedSkillNames = @(
    'brainstorming', 'dispatching-parallel-agents', 'executing-plans',
    'finishing-a-development-branch', 'receiving-code-review', 'requesting-code-review',
    'subagent-driven-development', 'systematic-debugging', 'test-driven-development',
    'using-git-worktrees', 'using-superpowers', 'verification-before-completion',
    'writing-plans', 'writing-skills'
)
$skillsRoot = Join-Path $repositoryRoot '.github/skills'
if (Test-Path -LiteralPath $skillsRoot -PathType Container) {
    $actualSkillNames = @(Get-ChildItem -LiteralPath $skillsRoot -Directory | ForEach-Object Name)
    foreach ($actualSkillName in $actualSkillNames) {
        if ($expectedSkillNames -cnotcontains $actualSkillName) {
            Add-ValidationFailure "Unexpected skill directory: $actualSkillName"
        }
    }
    foreach ($skillName in $expectedSkillNames) {
        if ($actualSkillNames -cnotcontains $skillName) {
            Add-ValidationFailure "Missing skill directory: $skillName"
            continue
        }
        $skillFile = Join-Path $skillsRoot "$skillName\SKILL.md"
        if (-not (Test-Path -LiteralPath $skillFile -PathType Leaf)) {
            Add-ValidationFailure "Missing SKILL.md: $skillName"
            continue
        }
        $skillLines = @(Get-Content -LiteralPath $skillFile)
        if ($skillLines.Count -eq 0 -or $skillLines[0] -cne '---') {
            Add-ValidationFailure "SKILL.md must start with frontmatter: $skillName"
            continue
        }
        $frontmatterEnd = -1
        for ($index = 1; $index -lt $skillLines.Count; $index++) {
            if ($skillLines[$index] -ceq '---') {
                $frontmatterEnd = $index
                break
            }
        }
        if ($frontmatterEnd -lt 0) {
            Add-ValidationFailure "SKILL.md frontmatter is not closed: $skillName"
            continue
        }

        $nameLines = @()
        for ($index = 1; $index -lt $frontmatterEnd; $index++) {
            if ($skillLines[$index] -match '^name:') { $nameLines += $skillLines[$index] }
        }
        if ($nameLines.Count -ne 1) {
            Add-ValidationFailure "Expected exactly one frontmatter name: $skillName"
            continue
        }
        $nameMatch = [regex]::Match($nameLines[0], '^name:\s*(?:([a-z0-9-]+)|''([a-z0-9-]+)''|"([a-z0-9-]+)")\s*$')
        if (-not $nameMatch.Success) {
            Add-ValidationFailure "Invalid frontmatter name: $skillName"
            continue
        }
        $declaredName = $nameMatch.Groups[1].Value
        if (-not $declaredName) { $declaredName = $nameMatch.Groups[2].Value }
        if (-not $declaredName) { $declaredName = $nameMatch.Groups[3].Value }
        if ($declaredName -cne $skillName) {
            Add-ValidationFailure "Skill name does not match directory: $skillName"
        }
    }
}

$manifestPath = Join-Path $skillsRoot 'SUPERPOWERS_SHA256SUMS'
$manifestHashes = [System.Collections.Generic.Dictionary[string,string]]::new([System.StringComparer]::Ordinal)
$manifestPaths = [System.Collections.Generic.List[string]]::new()
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    Add-ValidationFailure 'Missing .github/skills/SUPERPOWERS_SHA256SUMS.'
}
else {
    $manifestLines = @(Get-Content -LiteralPath $manifestPath)
    if ($manifestLines.Count -eq 0) {
        Add-ValidationFailure 'Runtime manifest is empty.'
    }
    for ($lineIndex = 0; $lineIndex -lt $manifestLines.Count; $lineIndex++) {
        $entryMatch = [regex]::Match($manifestLines[$lineIndex], '^([0-9a-f]{64})  (.+)$')
        if (-not $entryMatch.Success) {
            Add-ValidationFailure "Invalid manifest entry at line $($lineIndex + 1)."
            continue
        }

        $expectedHash = $entryMatch.Groups[1].Value
        $relativePath = $entryMatch.Groups[2].Value
        $segments = @($relativePath -split '/')
        $unsafeSegment = @($segments | Where-Object { $_ -eq '' -or $_ -eq '.' -or $_ -eq '..' })
        $unsafePath = $relativePath.Contains('\') -or $relativePath.StartsWith('/') -or $relativePath -match '^[a-zA-Z]:' -or $unsafeSegment.Count -gt 0
        if ($unsafePath -or $expectedSkillNames -cnotcontains $segments[0]) {
            Add-ValidationFailure "Unsafe manifest path: $relativePath"
            continue
        }

        $skillsRootFull = [System.IO.Path]::GetFullPath($skillsRoot).TrimEnd('\')
        $resolvedPath = [System.IO.Path]::GetFullPath((Join-Path $skillsRoot $relativePath))
        $skillsPrefix = $skillsRootFull + [System.IO.Path]::DirectorySeparatorChar
        if (-not $resolvedPath.StartsWith($skillsPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            Add-ValidationFailure "Manifest path resolves outside .github/skills: $relativePath"
            continue
        }
        if ($manifestHashes.ContainsKey($relativePath)) {
            Add-ValidationFailure "Duplicate manifest path: $relativePath"
            continue
        }
        $manifestHashes.Add($relativePath, $expectedHash)
        $manifestPaths.Add($relativePath)
    }

    $sortedManifestPaths = $manifestPaths.ToArray()
    [System.Array]::Sort($sortedManifestPaths, [System.StringComparer]::Ordinal)
    for ($index = 0; $index -lt $manifestPaths.Count; $index++) {
        if ($manifestPaths[$index] -cne $sortedManifestPaths[$index]) {
            Add-ValidationFailure 'Runtime manifest paths are not sorted ordinally.'
            break
        }
    }
}

$runtimeFiles = [System.Collections.Generic.Dictionary[string,System.IO.FileInfo]]::new([System.StringComparer]::Ordinal)
if (Test-Path -LiteralPath $skillsRoot -PathType Container) {
    $skillsRootFull = [System.IO.Path]::GetFullPath($skillsRoot).TrimEnd('\')
    foreach ($skillName in $expectedSkillNames) {
        $skillDirectory = Join-Path $skillsRoot $skillName
        if (-not (Test-Path -LiteralPath $skillDirectory -PathType Container)) { continue }
        foreach ($runtimeFile in Get-ChildItem -LiteralPath $skillDirectory -File -Recurse) {
            $relativePath = $runtimeFile.FullName.Substring($skillsRootFull.Length + 1).Replace('\', '/')
            $runtimeFiles[$relativePath] = $runtimeFile
        }
    }
}
foreach ($relativePath in $runtimeFiles.Keys) {
    if (-not $manifestHashes.ContainsKey($relativePath)) {
        Add-ValidationFailure "Runtime file is missing from manifest: $relativePath"
        continue
    }
    $actualHash = (Get-FileHash -LiteralPath $runtimeFiles[$relativePath].FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -cne $manifestHashes[$relativePath]) {
        Add-ValidationFailure "Runtime hash mismatch: $relativePath"
    }
}
foreach ($relativePath in $manifestHashes.Keys) {
    if (-not $runtimeFiles.ContainsKey($relativePath)) {
        Add-ValidationFailure "Manifest path is not a runtime file: $relativePath"
    }
}

foreach ($bootstrapFile in @('AGENTS.md', '.github/copilot-instructions.md')) {
    $bootstrapPath = Join-Path $repositoryRoot $bootstrapFile
    if (-not (Test-Path -LiteralPath $bootstrapPath -PathType Leaf)) {
        Add-ValidationFailure "Missing Copilot bootstrap: $bootstrapFile"
        continue
    }

    $bootstrapContent = Get-Content -LiteralPath $bootstrapPath -Raw
    if ($bootstrapContent -notmatch '\.github/skills') {
        Add-ValidationFailure "Bootstrap does not reference .github/skills: $bootstrapFile"
    }
    if ($bootstrapContent -notmatch 'using-superpowers') {
        Add-ValidationFailure "Bootstrap does not reference using-superpowers: $bootstrapFile"
    }
}

$versionFile = Join-Path $skillsRoot 'SUPERPOWERS_VERSION'
if (-not (Test-Path -LiteralPath $versionFile -PathType Leaf)) {
    Add-ValidationFailure 'Missing .github/skills/SUPERPOWERS_VERSION.'
}
else {
    $versionContent = Get-Content -LiteralPath $versionFile -Raw
    foreach ($requiredValue in @('https://github.com/obra/superpowers', 'v6.3.0', 'b36e0829c6d0140e93cfef2ca599b1b07d4a7797')) {
        if ($versionContent -notmatch [regex]::Escape($requiredValue)) {
            Add-ValidationFailure "Version metadata is missing: $requiredValue"
        }
    }
    $versionLines = @(Get-Content -LiteralPath $versionFile)
    if ($versionLines -cnotcontains 'manifest=SUPERPOWERS_SHA256SUMS') {
        Add-ValidationFailure 'Version metadata is missing: manifest=SUPERPOWERS_SHA256SUMS'
    }
}

$licenseFile = Join-Path $skillsRoot 'LICENSE.superpowers'
if (-not (Test-Path -LiteralPath $licenseFile -PathType Leaf)) {
    Add-ValidationFailure 'Missing .github/skills/LICENSE.superpowers.'
}
else {
    $licenseContent = Get-Content -LiteralPath $licenseFile -Raw
    if ($licenseContent -notmatch 'MIT License' -or $licenseContent -notmatch 'Copyright \(c\) 2025 Jesse Vincent') {
        Add-ValidationFailure 'The bundled Superpowers license is incomplete.'
    }
}

$rootReadme = Join-Path $repositoryRoot 'README.md'
if (-not (Test-Path -LiteralPath $rootReadme -PathType Leaf)) {
    Add-ValidationFailure 'Missing root README.md.'
}
else {
    $rootReadmeContent = Get-Content -LiteralPath $rootReadme -Raw
    foreach ($requiredValue in @('Superpowers', 'v6.3.0', '.github/skills', 'verify-repository-setup.ps1')) {
        if ($rootReadmeContent -notmatch [regex]::Escape($requiredValue)) {
            Add-ValidationFailure "Root README is missing: $requiredValue"
        }
    }
}

if ($failures.Count -gt 0) {
    foreach ($failure in $failures) {
        Write-Output "ERROR: $failure"
    }
    Write-Output "Repository setup validation failed with $($failures.Count) error(s)."
    exit 1
}

Write-Output 'Repository setup validation passed.'
```

- [ ] **Step 2: Run the verifier to prove the repository is not configured yet**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .github/cli/verify-repository-setup.ps1
```

Expected: exit code `1` with concise `ERROR: ...` lines for missing setup artifacts, including the runtime manifest, followed by one `Repository setup validation failed with N error(s).` summary. There is no parser or runtime exception.

- [ ] **Step 3: Exercise focused frontmatter and manifest fixtures**

Run this temporary fixture check from the repository root. It creates and removes only a unique directory under the system temporary folder.

```powershell
$validatorSource = (Resolve-Path '.github\cli\verify-repository-setup.ps1').Path
$fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) "repository-verifier-$([guid]::NewGuid())"
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$requiredDirectories = @(
    '.github/agent-policy', '.github/agents', '.github/cli', '.github/instructions',
    '.github/issue-templates', '.github/skills', '.github/workflows', 'docs/adr',
    'docs/archive', 'docs/brandkit', 'docs/business', 'docs/delegation', 'docs/ideas',
    'docs/issues', 'docs/plans', 'docs/reviews', 'docs/specs', 'docs/sprints', 'docs/templates'
)
$skillNames = @(
    'brainstorming', 'dispatching-parallel-agents', 'executing-plans',
    'finishing-a-development-branch', 'receiving-code-review', 'requesting-code-review',
    'subagent-driven-development', 'systematic-debugging', 'test-driven-development',
    'using-git-worktrees', 'using-superpowers', 'verification-before-completion',
    'writing-plans', 'writing-skills'
)

function Write-FixtureManifest {
    $skillsRoot = Join-Path $fixtureRoot '.github\skills'
    $hashes = [System.Collections.Generic.Dictionary[string,string]]::new([System.StringComparer]::Ordinal)
    foreach ($skillName in $skillNames) {
        foreach ($file in Get-ChildItem -LiteralPath (Join-Path $skillsRoot $skillName) -File -Recurse) {
            $relativePath = $file.FullName.Substring($skillsRoot.Length + 1).Replace('\', '/')
            $hashes[$relativePath] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        }
    }
    $paths = [string[]]$hashes.Keys
    [System.Array]::Sort($paths, [System.StringComparer]::Ordinal)
    $content = (($paths | ForEach-Object { "$($hashes[$_])  $_" }) -join "`n") + "`n"
    [System.IO.File]::WriteAllText((Join-Path $skillsRoot 'SUPERPOWERS_SHA256SUMS'), $content, $utf8NoBom)
}

function Initialize-Fixture {
    if (Test-Path -LiteralPath $fixtureRoot) { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force }
    foreach ($relativeDirectory in $requiredDirectories) {
        $directory = Join-Path $fixtureRoot $relativeDirectory
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $directory 'README.md'), "fixture`n", $utf8NoBom)
    }
    Copy-Item -LiteralPath $validatorSource -Destination (Join-Path $fixtureRoot '.github\cli\verify-repository-setup.ps1')
    foreach ($skillName in $skillNames) {
        $skillDirectory = Join-Path $fixtureRoot ".github\skills\$skillName"
        New-Item -ItemType Directory -Path $skillDirectory | Out-Null
        [System.IO.File]::WriteAllText(
            (Join-Path $skillDirectory 'SKILL.md'),
            "---`nname: $skillName`n---`nfixture`n",
            $utf8NoBom
        )
    }
    Write-FixtureManifest
    [System.IO.File]::WriteAllText((Join-Path $fixtureRoot 'AGENTS.md'), ".github/skills using-superpowers`n", $utf8NoBom)
    [System.IO.File]::WriteAllText((Join-Path $fixtureRoot '.github\copilot-instructions.md'), ".github/skills using-superpowers`n", $utf8NoBom)
    [System.IO.File]::WriteAllText(
        (Join-Path $fixtureRoot '.github\skills\SUPERPOWERS_VERSION'),
        "source=https://github.com/obra/superpowers`nrelease=v6.3.0`ncommit=b36e0829c6d0140e93cfef2ca599b1b07d4a7797`nmanifest=SUPERPOWERS_SHA256SUMS`n",
        $utf8NoBom
    )
    [System.IO.File]::WriteAllText((Join-Path $fixtureRoot '.github\skills\LICENSE.superpowers'), "MIT License`nCopyright (c) 2025 Jesse Vincent`n", $utf8NoBom)
    [System.IO.File]::WriteAllText((Join-Path $fixtureRoot 'README.md'), "Superpowers v6.3.0 .github/skills verify-repository-setup.ps1`n", $utf8NoBom)
}

function Invoke-FixtureVerifier {
    $output = @(& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $fixtureRoot '.github\cli\verify-repository-setup.ps1') 2>&1 | ForEach-Object { $_.ToString() })
    [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output }
}

function Assert-FixtureFailure {
    param([Parameter(Mandatory)][string]$ExpectedError)

    $result = Invoke-FixtureVerifier
    if ($result.ExitCode -ne 1 -or $result.Output -notcontains "ERROR: $ExpectedError") {
        throw "Expected fixture failure was not reported: $ExpectedError"
    }
}

try {
    Initialize-Fixture
    $result = Invoke-FixtureVerifier
    if ($result.ExitCode -ne 0 -or $result.Output.Count -ne 1 -or $result.Output[0] -cne 'Repository setup validation passed.') {
        throw 'Baseline verifier fixture did not pass.'
    }

    $quotedSkill = Join-Path $fixtureRoot '.github\skills\brainstorming\SKILL.md'
    [System.IO.File]::WriteAllText($quotedSkill, "---`nname: 'brainstorming'`n---`nfixture`n", $utf8NoBom)
    $doubleQuotedSkill = Join-Path $fixtureRoot '.github\skills\writing-plans\SKILL.md'
    [System.IO.File]::WriteAllText($doubleQuotedSkill, "---`nname: `"writing-plans`"`n---`nfixture`n", $utf8NoBom)
    Write-FixtureManifest
    $result = Invoke-FixtureVerifier
    if ($result.ExitCode -ne 0) { throw 'Quoted frontmatter names were rejected.' }

    Initialize-Fixture
    [System.IO.File]::WriteAllText($quotedSkill, "---`nname: brainstorming`nname: writing-plans`n---`n", $utf8NoBom)
    Write-FixtureManifest
    Assert-FixtureFailure 'Expected exactly one frontmatter name: brainstorming'

    Initialize-Fixture
    $manifestPath = Join-Path $fixtureRoot '.github\skills\SUPERPOWERS_SHA256SUMS'
    $manifestLines = @(Get-Content -LiteralPath $manifestPath)
    $entryParts = $manifestLines[0] -split '  ', 2
    $manifestLines[0] = ((('A' * 64) -join '') + '  ' + $entryParts[1])
    [System.IO.File]::WriteAllLines($manifestPath, $manifestLines, $utf8NoBom)
    Assert-FixtureFailure 'Invalid manifest entry at line 1.'

    Initialize-Fixture
    $manifestLines = @(Get-Content -LiteralPath $manifestPath)
    $entryParts = $manifestLines[0] -split '  ', 2
    $manifestLines[0] = "$($entryParts[0])  brainstorming/../escape.md"
    [System.IO.File]::WriteAllLines($manifestPath, $manifestLines, $utf8NoBom)
    Assert-FixtureFailure 'Unsafe manifest path: brainstorming/../escape.md'

    Initialize-Fixture
    $manifestLines = @(Get-Content -LiteralPath $manifestPath)
    $entryParts = $manifestLines[0] -split '  ', 2
    $manifestLines[0] = ((('0' * 64) -join '') + '  ' + $entryParts[1])
    [System.IO.File]::WriteAllLines($manifestPath, $manifestLines, $utf8NoBom)
    Assert-FixtureFailure "Runtime hash mismatch: $($entryParts[1])"

    Initialize-Fixture
    [System.IO.File]::WriteAllText((Join-Path $fixtureRoot '.github\skills\brainstorming\unlisted.txt'), "extra`n", $utf8NoBom)
    Assert-FixtureFailure 'Runtime file is missing from manifest: brainstorming/unlisted.txt'
}
finally {
    if (Test-Path -LiteralPath $fixtureRoot) { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force }
}
Write-Output 'Verifier fixture checks passed.'
```

Expected: `Verifier fixture checks passed.` The baseline accepts plain and paired-quoted names. Focused mutations reject duplicate frontmatter names, malformed manifest format, unsafe paths, wrong hashes, and runtime files missing from the manifest.

- [ ] **Step 4: Commit the validation baseline**

```powershell
git add -- .github/cli/verify-repository-setup.ps1
git commit -m "test: add repository setup verifier" -- .github/cli/verify-repository-setup.ps1
```

## Task 2: Establish the GitHub Collaboration Folders

**Files:**

- Create: `.github/agent-policy/README.md`
- Create: `.github/agents/README.md`
- Create: `.github/cli/README.md`
- Create: `.github/instructions/README.md`
- Create: `.github/issue-templates/README.md`
- Create: `.github/skills/README.md`
- Create: `.github/workflows/README.md`

- [ ] **Step 1: Add each GitHub folder README**

Create `.github/agent-policy/README.md`:

```markdown
# Agent Policy

This folder contains repository policies that govern AI agent permissions, safety boundaries, autonomy, and escalation.

Add stable, reviewable policy documents here. Keep reusable procedures in `.github/skills/` and agent personas in `.github/agents/`.
```

Create `.github/agents/README.md`:

```markdown
# Agents

This folder contains repository-scoped GitHub Copilot custom agent profiles.

Use one focused `*.agent.md` file per role. State the role's purpose, tools, boundaries, and expected handoffs without duplicating repository-wide instructions.
```

Create `.github/cli/README.md`:

```markdown
# CLI

This folder contains command-line utilities for repository setup, validation, and contributor automation.

Scripts must be non-interactive where practical, document prerequisites, fail with a nonzero exit code, and avoid changing contributor-level configuration.
```

Create `.github/instructions/README.md`:

```markdown
# Instructions

This folder contains path-specific GitHub Copilot instruction files.

Name files `*.instructions.md`, include a narrow `applyTo` glob, and keep each file focused on conventions that are not already enforced by project tooling.
```

Create `.github/issue-templates/README.md`:

```markdown
# Issue Template Sources

This folder contains project-owned drafts, shared wording, and planning material for issue templates.

This lowercase folder is not GitHub's active `.github/ISSUE_TEMPLATE/` directory. Do not expect files placed here to appear automatically in the GitHub issue creation interface.
```

Create `.github/skills/README.md`:

```markdown
# Agent Skills

This folder contains project skills discovered by GitHub Copilot in VS Code and Copilot CLI.

Superpowers is vendored here unchanged from its pinned upstream release. Keep project-owned skills in separate directories and do not edit vendored skill content directly; update it through a reviewed release replacement.
```

Create `.github/workflows/README.md`:

```markdown
# Workflows

This folder contains GitHub Actions workflow definitions for continuous integration and repository automation.

Use descriptive YAML file names, grant least-privilege permissions, pin third-party actions to reviewed versions, and document required secrets without committing their values.
```

- [ ] **Step 2: Run the verifier and confirm this slice is recognized**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .github/cli/verify-repository-setup.ps1
```

Expected: exit code `1`; no missing README failures for `.github/agent-policy`, `.github/agents`, `.github/cli`, `.github/instructions`, `.github/issue-templates`, `.github/skills`, or `.github/workflows`. Failures for documentation folders and the unimplemented Superpowers bundle remain.

- [ ] **Step 3: Commit the GitHub collaboration folders**

```powershell
git add -- .github/agent-policy/README.md .github/agents/README.md .github/cli/README.md .github/instructions/README.md .github/issue-templates/README.md .github/skills/README.md .github/workflows/README.md
git commit -m "docs: establish GitHub collaboration folders" -- .github/agent-policy/README.md .github/agents/README.md .github/cli/README.md .github/instructions/README.md .github/issue-templates/README.md .github/skills/README.md .github/workflows/README.md
```

## Task 3: Establish the Documentation Folders

**Files:**

- Create: `docs/adr/README.md`
- Create: `docs/archive/README.md`
- Create: `docs/brandkit/README.md`
- Create: `docs/business/README.md`
- Create: `docs/delegation/README.md`
- Create: `docs/ideas/README.md`
- Create: `docs/issues/README.md`
- Create: `docs/plans/README.md`
- Create: `docs/reviews/README.md`
- Create: `docs/specs/README.md`
- Create: `docs/sprints/README.md`
- Create: `docs/templates/README.md`

- [ ] **Step 1: Add each documentation folder README**

Create `docs/adr/README.md`:

```markdown
# Architecture Decision Records

This folder records significant architecture decisions, their context, considered options, and consequences.

Use sequentially numbered Markdown files such as `0001-use-example-platform.md`. Accepted records are immutable; supersede them with a new record that links back to the earlier decision.
```

Create `docs/archive/README.md`:

```markdown
# Archive

This folder retains obsolete documentation that still has historical or audit value.

Move content here only when it is no longer authoritative. Preserve its original context and add a short note identifying the replacement when one exists.
```

Create `docs/brandkit/README.md`:

```markdown
# Brand Kit

This folder contains approved brand guidance, visual assets, terminology, and usage rules for Caldova HR Frontier.

Store source assets in reviewable formats and identify the owner and version of each approved guideline. Product implementation assets belong with product source code.
```

Create `docs/business/README.md`:

```markdown
# Business

This folder contains business context, goals, operating assumptions, domain definitions, and outcome measures.

Keep documents decision-oriented and identify an owner, status, and review date when information can become stale.
```

Create `docs/delegation/README.md`:

```markdown
# Delegation

This folder contains durable work delegation briefs and handoff records for contributors and agents.

Each brief should define the outcome, scope, constraints, acceptance criteria, owner, and escalation path. Temporary task chatter does not belong here.
```

Create `docs/ideas/README.md`:

```markdown
# Ideas

This folder captures early concepts that have not yet become approved work.

State the problem, expected value, key assumptions, and open questions. Move validated ideas into a specification or plan and archive ideas that are no longer being considered.
```

Create `docs/issues/README.md`:

```markdown
# Issues

This folder contains detailed issue investigations or supporting material that is too substantial for the issue tracker alone.

Link every document to its tracked issue and avoid creating a second source of truth for status or ownership.
```

Create `docs/plans/README.md`:

```markdown
# Implementation Plans

This folder contains approved, executable implementation plans derived from reviewed specifications.

Name plans `YYYY-MM-DD-topic-implementation.md`. Include exact files, ordered steps, validation commands, expected outcomes, and completion criteria.
```

Create `docs/reviews/README.md`:

```markdown
# Reviews

This folder contains durable architecture, security, readiness, and implementation review records.

Record findings by severity, evidence, owner, and disposition. Routine pull request comments should remain on the pull request unless a durable record is required.
```

Create `docs/specs/README.md`:

```markdown
# Specifications

This folder contains approved designs and behavioral specifications that define what the repository should build or change.

Name specifications `YYYY-MM-DD-topic-design.md`. Capture scope, architecture, constraints, validation, and explicit non-goals before implementation planning begins.
```

Create `docs/sprints/README.md`:

```markdown
# Sprints

This folder contains time-boxed sprint goals, committed scope, review notes, and retrospectives.

Use date- or sequence-based subfolders. Track live task status in the selected work management system and keep only durable sprint context here.
```

Create `docs/templates/README.md`:

```markdown
# Documentation Templates

This folder contains reusable templates for repository documentation.

Templates should define required sections without embedding project-specific decisions. Name each template by its intended document type and keep examples clearly marked.
```

- [ ] **Step 2: Run the verifier and confirm the documentation slice is recognized**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .github/cli/verify-repository-setup.ps1
```

Expected: exit code `1`; no required directory or folder README failures remain. Failures for the Superpowers runtime, metadata, license, bootstrap files, and root README remain.

- [ ] **Step 3: Commit the documentation folders**

```powershell
git add -- docs/adr/README.md docs/archive/README.md docs/brandkit/README.md docs/business/README.md docs/delegation/README.md docs/ideas/README.md docs/issues/README.md docs/plans/README.md docs/reviews/README.md docs/specs/README.md docs/sprints/README.md docs/templates/README.md
git commit -m "docs: establish documentation folders" -- docs/adr/README.md docs/archive/README.md docs/brandkit/README.md docs/business/README.md docs/delegation/README.md docs/ideas/README.md docs/issues/README.md docs/plans/README.md docs/reviews/README.md docs/specs/README.md docs/sprints/README.md docs/templates/README.md
```

## Task 4: Vendor Superpowers v6.3.0

**Files:**

- Create: `.github/skills/brainstorming/**`
- Create: `.github/skills/dispatching-parallel-agents/**`
- Create: `.github/skills/executing-plans/**`
- Create: `.github/skills/finishing-a-development-branch/**`
- Create: `.github/skills/receiving-code-review/**`
- Create: `.github/skills/requesting-code-review/**`
- Create: `.github/skills/subagent-driven-development/**`
- Create: `.github/skills/systematic-debugging/**`
- Create: `.github/skills/test-driven-development/**`
- Create: `.github/skills/using-git-worktrees/**`
- Create: `.github/skills/using-superpowers/**`
- Create: `.github/skills/verification-before-completion/**`
- Create: `.github/skills/writing-plans/**`
- Create: `.github/skills/writing-skills/**`
- Create: `.github/skills/LICENSE.superpowers`
- Create: `.github/skills/SUPERPOWERS_SHA256SUMS`
- Create: `.github/skills/SUPERPOWERS_VERSION`

- [ ] **Step 1: Fetch and copy only the pinned runtime payload**

Run this PowerShell block from the repository root:

```powershell
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) "superpowers-v6.3.0-$([guid]::NewGuid())"
$skillNames = @(
    'brainstorming', 'dispatching-parallel-agents', 'executing-plans',
    'finishing-a-development-branch', 'receiving-code-review', 'requesting-code-review',
    'subagent-driven-development', 'systematic-debugging', 'test-driven-development',
    'using-git-worktrees', 'using-superpowers', 'verification-before-completion',
    'writing-plans', 'writing-skills'
)
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
try {
    git clone --quiet --depth 1 --branch v6.3.0 https://github.com/obra/superpowers.git $tempRoot
    if ($LASTEXITCODE -ne 0) { throw 'Unable to clone Superpowers v6.3.0.' }

    $resolvedCommit = git -C $tempRoot rev-parse HEAD
    if ($resolvedCommit -ne 'b36e0829c6d0140e93cfef2ca599b1b07d4a7797') {
        throw "Unexpected Superpowers commit: $resolvedCommit"
    }
    foreach ($skillName in $skillNames) {
        Copy-Item -LiteralPath (Join-Path $tempRoot "skills\$skillName") -Destination '.github\skills' -Recurse
    }
    Copy-Item -LiteralPath (Join-Path $tempRoot 'LICENSE') -Destination '.github\skills\LICENSE.superpowers'

    $skillsRoot = (Resolve-Path '.github\skills').Path.TrimEnd('\')
    $hashes = [System.Collections.Generic.Dictionary[string,string]]::new([System.StringComparer]::Ordinal)
    foreach ($skillName in $skillNames) {
        foreach ($file in Get-ChildItem -LiteralPath (Join-Path $skillsRoot $skillName) -File -Recurse) {
            $relativePath = $file.FullName.Substring($skillsRoot.Length + 1).Replace('\', '/')
            $hashes.Add($relativePath, (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant())
        }
    }
    $manifestPaths = [string[]]$hashes.Keys
    [System.Array]::Sort($manifestPaths, [System.StringComparer]::Ordinal)
    $manifestContent = (($manifestPaths | ForEach-Object { "$($hashes[$_])  $_" }) -join "`n") + "`n"
    [System.IO.File]::WriteAllText(
        (Join-Path $skillsRoot 'SUPERPOWERS_SHA256SUMS'),
        $manifestContent,
        $utf8NoBom
    )
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
```

Expected: `.github/skills/` contains the 14 listed upstream skill directories and a deterministic UTF-8-no-BOM `SUPERPOWERS_SHA256SUMS`; it contains no plugin manifests, hooks, upstream tests, or upstream documentation tree.

- [ ] **Step 2: Record exact source and runtime metadata**

Create `.github/skills/SUPERPOWERS_VERSION`:

```text
name=Superpowers
source=https://github.com/obra/superpowers
release=v6.3.0
version=6.3.0
tag-object=86babb696875227929e85420f287d6309374b93f
commit=b36e0829c6d0140e93cfef2ca599b1b07d4a7797
vendored=2026-09-15
upstream-path=skills/
destination=.github/skills/
manifest=SUPERPOWERS_SHA256SUMS
included-skills=brainstorming,dispatching-parallel-agents,executing-plans,finishing-a-development-branch,receiving-code-review,requesting-code-review,subagent-driven-development,systematic-debugging,test-driven-development,using-git-worktrees,using-superpowers,verification-before-completion,writing-plans,writing-skills
```

- [ ] **Step 3: Verify copied files against the pinned upstream tree**

Run:

```powershell
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) "superpowers-verify-$([guid]::NewGuid())"
$skillNames = @(
    'brainstorming', 'dispatching-parallel-agents', 'executing-plans',
    'finishing-a-development-branch', 'receiving-code-review', 'requesting-code-review',
    'subagent-driven-development', 'systematic-debugging', 'test-driven-development',
    'using-git-worktrees', 'using-superpowers', 'verification-before-completion',
    'writing-plans', 'writing-skills'
)
$runtimeDifferences = [System.Collections.Generic.List[string]]::new()
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$manifestMatches = $false
try {
    git clone --quiet --depth 1 --branch v6.3.0 https://github.com/obra/superpowers.git $tempRoot
    if ($LASTEXITCODE -ne 0) { throw 'Unable to clone Superpowers v6.3.0.' }

    $resolvedCommit = git -C $tempRoot rev-parse HEAD
    if ($resolvedCommit -ne 'b36e0829c6d0140e93cfef2ca599b1b07d4a7797') {
        throw "Unexpected Superpowers commit: $resolvedCommit"
    }

    $sourceSkillsRoot = (Resolve-Path (Join-Path $tempRoot 'skills')).Path.TrimEnd('\')
    $expectedHashes = [System.Collections.Generic.Dictionary[string,string]]::new([System.StringComparer]::Ordinal)
    foreach ($skillName in $skillNames) {
        foreach ($file in Get-ChildItem -LiteralPath (Join-Path $sourceSkillsRoot $skillName) -File -Recurse) {
            $relativePath = $file.FullName.Substring($sourceSkillsRoot.Length + 1).Replace('\', '/')
            $expectedHashes.Add($relativePath, (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant())
        }
    }
    $expectedPaths = [string[]]$expectedHashes.Keys
    [System.Array]::Sort($expectedPaths, [System.StringComparer]::Ordinal)
    $expectedContent = (($expectedPaths | ForEach-Object { "$($expectedHashes[$_])  $_" }) -join "`n") + "`n"
    $expectedManifest = Join-Path $tempRoot 'SUPERPOWERS_SHA256SUMS.expected'
    [System.IO.File]::WriteAllText($expectedManifest, $expectedContent, $utf8NoBom)
    $expectedBytes = [System.IO.File]::ReadAllBytes($expectedManifest)
    $actualBytes = [System.IO.File]::ReadAllBytes((Resolve-Path '.github\skills\SUPERPOWERS_SHA256SUMS').Path)
    $manifestMatches = $expectedBytes.Length -eq $actualBytes.Length -and
        [System.Convert]::ToBase64String($expectedBytes) -ceq [System.Convert]::ToBase64String($actualBytes)

    foreach ($skillName in $skillNames) {
        $difference = @(git diff --no-index -- (Join-Path $tempRoot "skills\$skillName") ".github\skills\$skillName" 2>&1)
        $diffExitCode = $LASTEXITCODE
        if ($diffExitCode -gt 1) {
            throw "Unable to compare vendored skill: $skillName"
        }
        if ($diffExitCode -eq 1) {
            $runtimeDifferences.AddRange([string[]]$difference)
        }
    }
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
if (-not $manifestMatches) {
    throw 'Runtime manifest differs from the pinned Superpowers v6.3.0 skills tree.'
}
if ($runtimeDifferences) {
    $runtimeDifferences
    throw 'Vendored runtime differs from Superpowers v6.3.0.'
}
```

Expected: the independently generated upstream manifest matches `.github/skills/SUPERPOWERS_SHA256SUMS` byte-for-byte, and `git diff --no-index` reports no differences for any of the 14 named skill directories. Repository-owned files at the `.github/skills/` root are outside the runtime comparison.

- [ ] **Step 4: Run repository validation**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .github/cli/verify-repository-setup.ps1
```

Expected: exit code `1`; manifest format, hash, exact file-set, skill, version, license, directory, and README checks pass. Only bootstrap and root README content failures remain.

- [ ] **Step 5: Commit the pinned runtime**

```powershell
git add -- .github/skills
git commit -m "build: vendor Superpowers v6.3.0" -- .github/skills
```

## Task 5: Bootstrap Copilot and Document Contributor Use

**Files:**

- Create: `AGENTS.md`
- Create: `.github/copilot-instructions.md`
- Modify: `README.md`

- [ ] **Step 1: Add the cross-host agent bootstrap**

Create `AGENTS.md`:

```markdown
# Agent Instructions

## Superpowers Workflow

- This repository bundles agent skills in `.github/skills/`; no machine-level Superpowers installation is required.
- Before responding or taking any action, load and follow the `using-superpowers` skill from `.github/skills/using-superpowers/SKILL.md`.
- Check for a relevant skill before clarifying, exploring, planning, implementing, debugging, reviewing, or claiming completion.
- When a skill applies, follow it as the controlling workflow. Process skills determine the approach before implementation skills are used.
- User and repository instructions take precedence over a conflicting skill instruction.
- Keep vendored Superpowers files unchanged. Put repository-specific guidance in this file, `.github/copilot-instructions.md`, `.github/instructions/`, or a separate project-owned skill.
```

- [ ] **Step 2: Add the VS Code Copilot bootstrap**

Create `.github/copilot-instructions.md`:

```markdown
# Repository Copilot Instructions

This repository bundles Superpowers as project skills under `.github/skills/`; do not require contributors to install it globally.

Before any response or action, load `using-superpowers` from `.github/skills/using-superpowers/SKILL.md`, check for other applicable skills, and follow the applicable workflow. Repository and user instructions take precedence if they conflict with a vendored skill.
```

- [ ] **Step 3: Document contributor usage and updates**

Replace `README.md` with:

````markdown
# caldova-hr-frontier

## Repository Agent Workflow

This repository bundles [Superpowers](https://github.com/obra/superpowers) v6.3.0 for GitHub Copilot. Contributors receive the same agent workflows by cloning the repository; no machine-level Superpowers installation is required.

GitHub Copilot discovers the skills under `.github/skills/` in:

- Visual Studio Code chat and agent mode;
- GitHub Copilot CLI when launched from this repository.

Repository instructions require Copilot to begin with the `using-superpowers` skill and load other skills when relevant.

### Verify the Bundle

From the repository root on Windows, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .github/cli/verify-repository-setup.ps1
```

The command succeeds with `Repository setup validation passed.` when the folder structure, skill metadata, exact runtime file set and SHA-256 hashes, bootstrap instructions, version metadata, and license are valid.

In VS Code, open **Chat: Open Agent Customizations** and confirm the workspace skills appear without metadata errors. In Copilot CLI, start `copilot` from the repository root and invoke or ask it to use `using-superpowers`.

### Pinned Version and License

The vendored runtime is pinned to upstream release v6.3.0 at commit `b36e0829c6d0140e93cfef2ca599b1b07d4a7797`.

- Source metadata: [`.github/skills/SUPERPOWERS_VERSION`](.github/skills/SUPERPOWERS_VERSION)
- Runtime SHA-256 manifest: [`.github/skills/SUPERPOWERS_SHA256SUMS`](.github/skills/SUPERPOWERS_SHA256SUMS)
- Upstream MIT license: [`.github/skills/LICENSE.superpowers`](.github/skills/LICENSE.superpowers)

### Updating Superpowers

Updates are deliberate and reviewed. To update:

1. Review the newer upstream release and release notes.
2. Replace only the 14 vendored skill directories with the newer release's `skills/` content.
3. Regenerate `SUPERPOWERS_SHA256SUMS` from every file in the 14 reviewed upstream runtime directories using forward-slash relative paths, ordinal path sorting, and lowercase SHA-256 hashes.
4. Refresh `LICENSE.superpowers` if the upstream license changed.
5. Update `SUPERPOWERS_VERSION` with the release, tag object, commit, date, manifest name, and included skill list.
6. Run the repository verifier and smoke-test discovery in VS Code and Copilot CLI.
7. Commit the runtime replacement, manifest, metadata, and any required bootstrap compatibility changes together.

Do not track upstream `main`, use a submodule, or edit vendored skill files for repository-specific behavior.
````

- [ ] **Step 4: Run the verifier to green**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .github/cli/verify-repository-setup.ps1
```

Expected: exit code `0` and `Repository setup validation passed.`

- [ ] **Step 5: Commit the Copilot bootstrap and contributor guide**

```powershell
git add -- AGENTS.md .github/copilot-instructions.md README.md
git commit -m "docs: activate bundled Superpowers for Copilot" -- AGENTS.md .github/copilot-instructions.md README.md
```

## Task 6: Perform Final Repository and Host Validation

**Files:**

- Verify: all files introduced by Tasks 1-5

- [ ] **Step 1: Run automated repository validation from a clean shell**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .github/cli/verify-repository-setup.ps1
git diff --check HEAD~4..HEAD
```

Expected: validator exits `0` with `Repository setup validation passed.`; `git diff --check` produces no output.

- [ ] **Step 2: Verify folder and skill counts**

```powershell
$requiredReadmes = @(
    '.github/agent-policy/README.md', '.github/agents/README.md', '.github/cli/README.md',
    '.github/instructions/README.md', '.github/issue-templates/README.md', '.github/skills/README.md',
    '.github/workflows/README.md', 'docs/adr/README.md', 'docs/archive/README.md',
    'docs/brandkit/README.md', 'docs/business/README.md', 'docs/delegation/README.md',
    'docs/ideas/README.md', 'docs/issues/README.md', 'docs/plans/README.md',
    'docs/reviews/README.md', 'docs/specs/README.md', 'docs/sprints/README.md',
    'docs/templates/README.md'
)
$missingReadmes = $requiredReadmes | Where-Object { -not (Test-Path -LiteralPath $_ -PathType Leaf) }
$skillDirectories = @(Get-ChildItem -LiteralPath '.github/skills' -Directory | Where-Object {
    Test-Path -LiteralPath (Join-Path $_.FullName 'SKILL.md')
})
$skillCount = $skillDirectories.Count
$runtimeFileCount = @($skillDirectories | ForEach-Object {
    Get-ChildItem -LiteralPath $_.FullName -File -Recurse
}).Count
$manifestEntryCount = @(Get-Content -LiteralPath '.github/skills/SUPERPOWERS_SHA256SUMS').Count
if ($missingReadmes.Count -ne 0) { throw "Missing README files: $($missingReadmes -join ', ')" }
if ($skillCount -ne 14) { throw "Expected 14 skills, found $skillCount" }
if ($manifestEntryCount -ne $runtimeFileCount) {
    throw "Expected $runtimeFileCount manifest entries, found $manifestEntryCount"
}
if (Test-Path -LiteralPath '.github/ISSUE_TEMPLATE') { throw 'Excluded .github/ISSUE_TEMPLATE exists.' }
if (Test-Path -LiteralPath 'docs/storyboard') { throw 'Excluded docs/storyboard exists.' }
Write-Output 'Folder, skill, and manifest count validation passed.'
```

Expected: `Folder, skill, and manifest count validation passed.` The manifest entry count equals the recursive file count beneath the 14 skill directories; Step 1's main verifier validates every manifest hash and the exact runtime file set.

- [ ] **Step 3: Smoke-test VS Code discovery**

In VS Code:

1. Run **Chat: Open Agent Customizations**.
2. Open the **Skills** tab.
3. Confirm all 14 repository skills appear and no metadata diagnostic is shown.
4. Start a new chat in the repository and enter `Use using-superpowers and tell me which process applies before changing code.`

Expected: Copilot identifies and follows `using-superpowers` from `.github/skills/` without asking for a global install.

- [ ] **Step 4: Smoke-test Copilot CLI discovery**

From the repository root, start:

```powershell
copilot
```

Then enter:

```text
Use using-superpowers and tell me which process applies before changing code.
```

Expected: Copilot CLI loads the repository skill and does not ask for a plugin or machine-level installation.

- [ ] **Step 5: Confirm final Git state**

```powershell
git status --short
git log --oneline -7
```

Expected: working tree is clean and the design, implementation plan, and five implementation commits are present.
