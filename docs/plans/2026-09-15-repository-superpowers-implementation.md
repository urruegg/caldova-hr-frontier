# Repository Superpowers Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bundle Superpowers v6.3.0, the approved repository folder structure, and structured GitHub issue forms so contributors and GitHub Copilot use consistent project workflows from a normal clone.

**Architecture:** GitHub Copilot discovers unchanged upstream skills from `.github/skills/`. A PowerShell setup validator checks the fixed repository contract, including the pinned manifest digest, exact runtime and issue-form inventories, complete Git index classification, required modes, and raw index/working-tree object-ID coherence. Pinned SHA-256 values protect the approved bytes without parsing Markdown bodies, links, or YAML. Repository-owned bootstrap instructions, exact version metadata, a pinned upstream license copy, and folder READMEs make the bundle reviewable and maintainable.

**Tech Stack:** GitHub Copilot Agent Skills, Markdown, PowerShell 5.1+, Git

---

## Execution Status

Tasks 1-6 are completed historical context. Their unchecked boxes, embedded commands, and exact code blocks preserve the implementation sequence; they are not a replay path or the final validator contract. The authoritative shipped validator is the current `.github/cli/verify-repository-setup.ps1` at commit `cc3f74ce22ce98b1388cc02d956addabbb4ed7cb` (`cc3f74c`). Task 7 is the closeout verification against the current committed artifacts and does not assume a fixed commit count.

## Shipped Integrity Contract

- **Superpowers runtime:** `.github/skills/` contains exactly 14 expected skill directories and 51 runtime files. The exact skill names, in alphabetical order, are: `brainstorming`, `dispatching-parallel-agents`, `executing-plans`, `finishing-a-development-branch`, `receiving-code-review`, `requesting-code-review`, `subagent-driven-development`, `systematic-debugging`, `test-driven-development`, `using-git-worktrees`, `using-superpowers`, `verification-before-completion`, `writing-plans`, `writing-skills`. `SUPERPOWERS_SHA256SUMS` has raw SHA-256 digest `be8b1626ea290a4cc0a99ccf0e4878fcf8c5ca7d238094be3d23b59563d28f1c` and is an exact-case stage-0 mode `100644` entry. Its exact ordinal path/hash set equals the forced working-file set.
- **Persistent validator boundary:** every tracked path beneath `.github/skills/` is classified. Unknown nested skill trees, skill or file case variants, extra runtime paths, and unexpected root files are rejected. Outside the skill directories, only exact root paths `README.md`, `LICENSE.superpowers`, `SUPERPOWERS_SHA256SUMS`, and `SUPERPOWERS_VERSION` are allowlisted. For the manifest plus 51 runtime paths, the validator requires unique exact-case stage-0 records with the expected modes, thereby rejecting their conflict stages, and verifies their pinned hashes and raw index/working-tree OIDs. The three auxiliary root files are allowlisted and content-validated persistently as applicable, but their Git index records are not required by the persistent validator.
- **Task 7 complete root audit:** Task 7 Step 2 separately requires the exact complete tracked set beneath `.github/skills/`: root records `README.md`, `LICENSE.superpowers`, `SUPERPOWERS_SHA256SUMS`, and `SUPERPOWERS_VERSION`, plus the manifest-defined runtime records, with no omissions or extras and only stage-0 records. This catches missing or conflict-stage auxiliary root records.
- **Runtime modes and coherence:** the 51 runtime records are exactly 44 stage-0 mode `100644` files and seven stage-0 mode `100755` files. Raw working-tree and index object IDs match for the manifest plus all runtime paths (`52/52`). Hidden entries and reparse points cannot evade enumeration.
- **Pinned metadata:** `LICENSE.superpowers` has full-file SHA-256 digest `a37e0e9697144819e1d965176ac4ae5bc3fa02d11e7812036bbcadf6dafe2400`, and `SUPERPOWERS_VERSION` matches the exact ordered v6.3.0 metadata lines.
- **Issue forms:** exactly `.github/ISSUE_TEMPLATE/01-bug.yml`, `.github/ISSUE_TEMPLATE/02-feature.yml`, and `.github/ISSUE_TEMPLATE/config.yml` exist and are tracked with exact uppercase casing as stage-0 mode `100644`. Their pinned hashes preserve the approved schema, required fields, public-data warning, security wording, and intentional absence of unverified contact links.
- **Attributes and form coherence:** `.gitattributes` contains exactly one `/.gitattributes -text` and exactly one `/.github/ISSUE_TEMPLATE/*.yml -text`; `git check-attr text` reports effective `unset` for `.gitattributes` and all three forms. Their exact path set has no extras or reparse points, and raw working-tree/index object IDs match for all four paths (`4/4`).
- **Portability:** clean committed checkouts under both `core.autocrlf=true` and `core.autocrlf=false` retain the exact bytes, attributes, hashes, coherent snapshots, sole validator success line, and clean status.

Post-Task-6 review hardened the validator from staged form-snapshot checking (`c168f9e`) and raw `.gitattributes` protection (`cda9393`) through the complete runtime snapshot (`46c1e53`), extra-runtime rejection (`904f7a8`), and final rogue-skill-path rejection (`cc3f74c`). The current validator and Task 7 are authoritative; the earlier embedded replacement blocks remain historical evidence only.

## Task 1: Add the Repository Setup Verifier

> **Historical snapshot:** The validator and fixture blocks in this task preserve the original implementation slice. Do not recreate the Task 6 baseline from these blocks or depend on their historical `Add-ValidationFailure` name. In the historical sequence, Task 6 read the then-current `41a869dc3cb81522638bfd6df7dcf8557a4fb18c` baseline, which used `Add-Failure`; that baseline is not the shipped validator.

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

Active GitHub issue forms live in `.github/ISSUE_TEMPLATE/`. Review changes here before promoting them to the active forms, and update the repository validator when the active form contract changes.
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

The command succeeds with `Repository setup validation passed.` when the folder structure, skill metadata, exact runtime file set and SHA-256 hashes, executable Git modes, bootstrap instructions, version metadata, and license are valid.

In VS Code, open **Chat: Open Customizations** and confirm the workspace skills appear without metadata errors. Confirm `using-superpowers` shows its source/path as `.github/skills/using-superpowers/SKILL.md` so repository provenance is checked.

In Copilot CLI, from the repository root run `copilot --no-auto-update -C . skill list --json` and confirm `using-superpowers` has `source` equal to `project`, `enabled` equal to `true`, and a `path` ending in this repository's `.github/skills/using-superpowers`, regardless of whether the host displays `/` or `\` path separators. In an interactive session, `/skills info using-superpowers` can also confirm the repository location. For the behavior smoke test, start `copilot --no-auto-update -C .`, then enter a natural-language prompt such as `Use the /using-superpowers skill to identify which process applies before changing code.` Standalone `/using-superpowers` is supported, but the prompt form is recommended because it provides a verifiable response.

### Pinned Version and License

The vendored runtime is pinned to upstream release v6.3.0 at commit `b36e0829c6d0140e93cfef2ca599b1b07d4a7797`.

- Source metadata: [`.github/skills/SUPERPOWERS_VERSION`](.github/skills/SUPERPOWERS_VERSION)
- Runtime SHA-256 manifest: [`.github/skills/SUPERPOWERS_SHA256SUMS`](.github/skills/SUPERPOWERS_SHA256SUMS)
- Upstream MIT license: [`.github/skills/LICENSE.superpowers`](.github/skills/LICENSE.superpowers)

### Updating Superpowers

Updates are deliberate and reviewed. To update:

1. Review the newer upstream release and release notes.
2. Replace only the 14 vendored skill directories with the newer release's `skills/` content.
3. Review and update `.github/cli/verify-repository-setup.ps1` fixed contracts for the new upstream release: the expected 14-skill inventory, seven-path executable mode inventory, source release/version/tag/commit, manifest name and metadata, and license attribution checks.
4. Regenerate `SUPERPOWERS_SHA256SUMS` from every file in the 14 reviewed upstream runtime directories using forward-slash relative paths, ordinal path sorting, and lowercase SHA-256 hashes.
5. Preserve the upstream executable Git modes for the reviewed runtime paths.
6. Refresh `LICENSE.superpowers` if the upstream license changed.
7. Update `SUPERPOWERS_VERSION` with the release, tag object, commit, date, manifest name, and included skill list.
8. Run the repository verifier and complete the VS Code and Copilot CLI smoke tests under **Verify the Bundle**.
9. Commit the runtime replacement, manifest, metadata, validator contracts, and any required bootstrap compatibility changes together.

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

## Task 6: Add Structured GitHub Issue Forms

> **Historical implementation record:** This task preserves the exact issue-form implementation slice and its approved YAML and hashes. Post-task review hardened the validator through `cc3f74c`; the current `.github/cli/verify-repository-setup.ps1`, the **Shipped Integrity Contract**, and Task 7 define the authoritative final behavior. Task 6's Step 4 replacement block and its fixture blocks are historical; they are not the final validator.

**Files:**

- Modify: `.gitattributes`
- Create: `.github/ISSUE_TEMPLATE/01-bug.yml`
- Create: `.github/ISSUE_TEMPLATE/02-feature.yml`
- Create: `.github/ISSUE_TEMPLATE/config.yml`
- Modify: `.github/cli/verify-repository-setup.ps1`

The lowercase `.github/issue-templates/README.md`, design specification, and this plan are updated and committed separately before this task. The implementation commit in this task contains only root `.gitattributes`, the three active issue-form files, and the repository validator.

Task 6 historically started from the then-current committed validator at `41a869dc3cb81522638bfd6df7dcf8557a4fb18c`, not the Task 1 sample. At that point, the executor had to read the actual `.github/cli/verify-repository-setup.ps1` and confirm that it defined `Add-Failure` and contained the legacy-path loop quoted in Step 4.

- [ ] **Step 1: Run a RED check against the current legacy-path contract**

Run this from the repository root before changing the validator or adding `.gitattributes`. It first proves that Git has no active-form EOL override, then creates and removes an empty active issue-template directory solely to prove the current committed validator rejects that path:

```powershell
$activeIssueTemplatePath = '.github\ISSUE_TEMPLATE'
if (Test-Path -LiteralPath $activeIssueTemplatePath) {
    throw '.github/ISSUE_TEMPLATE must not exist before the RED check.'
}
$attributeOutput = @(git check-attr text -- .github/ISSUE_TEMPLATE/01-bug.yml)
if ($LASTEXITCODE -ne 0 -or $attributeOutput.Count -ne 1 -or
    $attributeOutput[0] -cne '.github/ISSUE_TEMPLATE/01-bug.yml: text: unspecified') {
    $attributeOutput
    throw 'Expected the active issue-form text attribute to be unspecified before implementation.'
}
New-Item -ItemType Directory -Path $activeIssueTemplatePath | Out-Null
try {
    $output = @(& powershell -NoProfile -ExecutionPolicy Bypass -File .github/cli/verify-repository-setup.ps1 2>&1 | ForEach-Object { $_.ToString() })
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 1 -or $output -notcontains 'ERROR: Legacy path must not exist: .github/ISSUE_TEMPLATE') {
        $output
        throw 'Current validator did not reject .github/ISSUE_TEMPLATE as a legacy path.'
    }
}
finally {
    Remove-Item -LiteralPath $activeIssueTemplatePath -Force
}
Write-Output 'RED confirmed: current validator rejects .github/ISSUE_TEMPLATE.'
```

Expected: `git check-attr` reports `.github/ISSUE_TEMPLATE/01-bug.yml: text: unspecified`, followed by `RED confirmed: current validator rejects .github/ISSUE_TEMPLATE.` The validator implementation has not changed yet. The exact legacy diagnostic assertion is intentionally tied to the committed pre-Task-6 validator, not Task 1's historical sample.

- [ ] **Step 2: Create the exact active issue forms**

All three active YAML files are raw-byte contracts: UTF-8 without a BOM, LF line endings, and exactly one final LF. The `-text` rule added in Step 3 disables Git EOL conversion for these paths, making their stated raw SHA-256 hashes portable across checkout settings.

Create `.github/ISSUE_TEMPLATE/01-bug.yml` with UTF-8 encoding without a BOM, LF line endings, and exactly one final LF:

```yaml
name: Bug report
description: Report a reproducible problem in Caldova HR Frontier.
title: "[Bug]: "
body:
  - type: markdown
    attributes:
      value: |
        Thank you for helping us improve Caldova HR Frontier.
        This form is public. Do not include secrets, personal data, or security vulnerability details.
  - type: checkboxes
    id: existing_issue
    attributes:
      label: Existing issue check
      description: Search open and closed issues before submitting.
      options:
        - label: I searched for an existing issue that describes this problem.
          required: true
  - type: textarea
    id: problem
    attributes:
      label: Problem
      description: Describe the problem and its impact.
      placeholder: What happened, and who or what is affected?
    validations:
      required: true
  - type: textarea
    id: reproduction
    attributes:
      label: Steps to reproduce
      description: Provide the smallest reliable sequence that reproduces the problem.
      placeholder: |
        1. Go to ...
        2. Select ...
        3. Observe ...
    validations:
      required: true
  - type: textarea
    id: expected_behavior
    attributes:
      label: Expected behavior
      description: Describe what you expected to happen.
    validations:
      required: true
  - type: textarea
    id: actual_behavior
    attributes:
      label: Actual behavior
      description: Describe what happened instead.
    validations:
      required: true
  - type: textarea
    id: environment
    attributes:
      label: Environment
      description: Provide the environment details needed to reproduce the problem.
      placeholder: |
        - Operating system:
        - Browser or runtime:
        - Version or commit:
    validations:
      required: true
  - type: textarea
    id: logs
    attributes:
      label: Relevant logs
      description: Remove secrets and personal data before pasting relevant log output.
      render: shell
  - type: textarea
    id: additional_context
    attributes:
      label: Additional context
      description: Add screenshots, links, or other context that may help the investigation.
```

Create `.github/ISSUE_TEMPLATE/02-feature.yml` with UTF-8 encoding without a BOM, LF line endings, and exactly one final LF:

```yaml
name: Feature request
description: Propose an outcome or capability for Caldova HR Frontier.
title: "[Feature]: "
body:
  - type: markdown
    attributes:
      value: |
        Thank you for proposing an improvement. Focus on the problem and desired outcome before implementation details.
  - type: checkboxes
    id: existing_request
    attributes:
      label: Existing request check
      description: Search open and closed issues before submitting.
      options:
        - label: I searched for an existing request that addresses this need.
          required: true
  - type: textarea
    id: problem_value
    attributes:
      label: Problem and value
      description: Describe the problem, who experiences it, and why solving it matters.
      placeholder: What outcome is difficult today, and what value would improve?
    validations:
      required: true
  - type: textarea
    id: desired_outcome
    attributes:
      label: Desired outcome
      description: Describe the observable result rather than prescribing an implementation.
    validations:
      required: true
  - type: textarea
    id: alternatives
    attributes:
      label: Alternatives considered
      description: Describe current workarounds or other approaches you considered.
  - type: textarea
    id: acceptance_criteria
    attributes:
      label: Acceptance criteria
      description: List measurable conditions that would demonstrate the requested outcome.
      placeholder: |
        - [ ] The user can ...
        - [ ] The system reports ...
    validations:
      required: true
  - type: textarea
    id: additional_context
    attributes:
      label: Additional context
      description: Add examples, links, sketches, or constraints that may help evaluate the request.
```

Create `.github/ISSUE_TEMPLATE/config.yml` with UTF-8 encoding without a BOM, LF line endings, and exactly one final LF:

```yaml
blank_issues_enabled: false
```

The exact byte contracts are:

```text
8f2c31b169477b86d85e60f9d1c91eed349fae829f1071b8b42dc93624d8879a  01-bug.yml
748e69155e9e60acd16f5cbb93b6398fd5853905951829080a9c440ed5c0e7a4  02-feature.yml
1f103c6a9dd07cd13a9a6f17ace6b813f47747eb9cb7e00488cb2073caaf91bb  config.yml
```

- [ ] **Step 3: Disable EOL conversion for active issue forms**

Modify root `.gitattributes` by adding this exact line. Preserve its existing rules, use UTF-8 encoding without a BOM and LF line endings, and retain exactly one final LF:

```gitattributes
/.github/ISSUE_TEMPLATE/*.yml -text
```

Run the GREEN attribute check:

```powershell
$issueTemplatePaths = @(
    '.github/ISSUE_TEMPLATE/01-bug.yml',
    '.github/ISSUE_TEMPLATE/02-feature.yml',
    '.github/ISSUE_TEMPLATE/config.yml'
)
$attributeOutput = @(git check-attr text -- $issueTemplatePaths)
if ($LASTEXITCODE -ne 0 -or $attributeOutput.Count -ne $issueTemplatePaths.Count) {
    $attributeOutput
    throw 'Unable to inspect active issue-form text attributes.'
}
foreach ($path in $issueTemplatePaths) {
    if ($attributeOutput -cnotcontains "${path}: text: unset") {
        $attributeOutput
        throw "Active issue-form EOL conversion is not disabled: $path"
    }
}
$attributeOutput
```

Expected: one `<path>: text: unset` line for each active YAML file. The exact `-text` rule makes Git preserve the pinned UTF-8-no-BOM LF bytes instead of applying `core.autocrlf` conversion.

- [ ] **Step 4: Replace the legacy-path rejection with the pinned active-form contract**

Read the current committed `.github/cli/verify-repository-setup.ps1` before editing it. In the `41a869dc3cb81522638bfd6df7dcf8557a4fb18c` baseline, replace this exact `Add-Failure` loop that rejects both legacy paths:

```powershell
foreach ($legacyPath in @('.github/ISSUE_TEMPLATE', 'docs/storyboard')) {
    if (Test-Path -LiteralPath (Join-Path $repositoryRoot ($legacyPath.Replace('/', '\')))) {
        Add-Failure "Legacy path must not exist: $legacyPath"
    }
}
```

with this exact validation block. The repository validator intentionally validates fixed names, ordinary files, reparse-point absence, and pinned SHA-256 hashes instead of adding or hand-writing a YAML parser:

```powershell
$storyboardPath = Join-Path $repositoryRoot 'docs\storyboard'
if (Test-Path -LiteralPath $storyboardPath) {
    Add-Failure 'Legacy path must not exist: docs/storyboard'
}

$issueTemplateRelativeRoot = '.github/ISSUE_TEMPLATE'
$githubRoot = Join-Path $repositoryRoot '.github'
$issueTemplateRoot = Join-Path $repositoryRoot '.github\ISSUE_TEMPLATE'
$issueTemplateFileNames = @('01-bug.yml', '02-feature.yml', 'config.yml')
$issueTemplateGitPrefix = '.github/ISSUE_TEMPLATE/'
$expectedIssueTemplateGitPaths = @($issueTemplateFileNames | ForEach-Object { "${issueTemplateGitPrefix}$_" })
$expectedIssueTemplateHashes = [Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
$expectedIssueTemplateHashes.Add('01-bug.yml', '8f2c31b169477b86d85e60f9d1c91eed349fae829f1071b8b42dc93624d8879a')
$expectedIssueTemplateHashes.Add('02-feature.yml', '748e69155e9e60acd16f5cbb93b6398fd5853905951829080a9c440ed5c0e7a4')
$expectedIssueTemplateHashes.Add('config.yml', '1f103c6a9dd07cd13a9a6f17ace6b813f47747eb9cb7e00488cb2073caaf91bb')
$actualIssueTemplateFiles = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$reparseIssueTemplateEntries = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$ordinaryIssueTemplateFiles = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$issueTemplateRootTrusted = $true

if (Test-Path -LiteralPath $githubRoot -PathType Container) {
    try {
        $issueTemplateDirectoryCandidates = @(Get-ChildItem -LiteralPath $githubRoot -Directory -Force | Where-Object {
            [string]::Equals($_.Name, 'ISSUE_TEMPLATE', [StringComparison]::OrdinalIgnoreCase)
        })
        foreach ($candidate in $issueTemplateDirectoryCandidates) {
            if ($candidate.Name -cne 'ISSUE_TEMPLATE') {
                Add-Failure "Active issue-template directory must use exact filesystem casing: .github/$($candidate.Name)"
            }
        }
        if ($issueTemplateDirectoryCandidates.Count -gt 1) {
            Add-Failure 'Multiple case variants of the active issue-template directory exist under .github'
        }
    }
    catch {
        Add-Failure 'Cannot inspect active issue-template directory casing under .github'
    }
}

if (-not (Test-Path -LiteralPath $issueTemplateRoot -PathType Container)) {
    Add-Failure "Missing directory: $issueTemplateRelativeRoot"
    $issueTemplateRootTrusted = $false
}
else {
    try { $issueTemplateRootItem = Get-Item -LiteralPath $issueTemplateRoot -Force }
    catch { Add-Failure "Cannot inspect directory: $issueTemplateRelativeRoot"; $issueTemplateRootTrusted = $false }
    if ($issueTemplateRootTrusted -and ($issueTemplateRootItem.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        Add-Failure "Reparse point is not allowed: $issueTemplateRelativeRoot"
        $issueTemplateRootTrusted = $false
    }
}

if ($issueTemplateRootTrusted) {
    try { $issueTemplateEntries = @(Get-ChildItem -LiteralPath $issueTemplateRoot -Force) }
    catch { Add-Failure "Cannot enumerate entries under $issueTemplateRelativeRoot"; $issueTemplateEntries = @() }
    foreach ($entry in $issueTemplateEntries) {
        if ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            Add-Failure "Reparse point is not allowed under ${issueTemplateRelativeRoot}: $($entry.Name)"
            [void]$reparseIssueTemplateEntries.Add($entry.Name)
        }
        if ($issueTemplateFileNames -cnotcontains $entry.Name) {
            Add-Failure "Unexpected active issue-template entry: $($entry.Name)"
            continue
        }
        [void]$actualIssueTemplateFiles.Add($entry.Name)
    }
}

foreach ($fileName in $issueTemplateFileNames) {
    $relativePath = "$issueTemplateRelativeRoot/$fileName"
    if (-not $actualIssueTemplateFiles.Contains($fileName)) {
        Add-Failure "Missing active issue-template file: $relativePath"
        continue
    }
    if ($reparseIssueTemplateEntries.Contains($fileName)) { continue }
    $filePath = Join-Path $issueTemplateRoot $fileName
    if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
        Add-Failure "Active issue-template entry is not a file: $relativePath"
        continue
    }
    [void]$ordinaryIssueTemplateFiles.Add($fileName)
}

$gitCommand = Get-Command git -CommandType Application -ErrorAction SilentlyContinue
$gitIndexLines = @()
$gitIndexReadable = $false
if ($null -eq $gitCommand) {
    Add-Failure 'Cannot inspect Git index for active issue-template paths: git is unavailable'
}
else {
    try {
        $gitIndexLines = @(& $gitCommand.Source -C $repositoryRoot -c core.quotePath=false ls-files --stage 2>&1 |
            ForEach-Object { $_.ToString() })
        $gitIndexExitCode = $LASTEXITCODE
        if ($gitIndexExitCode -ne 0) {
            Add-Failure 'Cannot inspect Git index for active issue-template paths'
        }
        else {
            $gitIndexReadable = $true
        }
    }
    catch {
        Add-Failure 'Cannot inspect Git index for active issue-template paths'
    }
}

if ($gitIndexReadable) {
    $issueTemplateGitRecords = [Collections.Generic.List[object]]::new()
    foreach ($line in $gitIndexLines) {
        if ($line -notmatch '^([0-7]{6}) ([0-9a-fA-F]{40,64}) ([0-3])\t(.*)$') {
            Add-Failure "Cannot parse Git index record: $line"
            continue
        }
        $record = [pscustomobject]@{
            Mode = $Matches[1]
            ObjectId = $Matches[2]
            Stage = $Matches[3]
            Path = $Matches[4]
        }
        if (-not $record.Path.StartsWith($issueTemplateGitPrefix, [StringComparison]::OrdinalIgnoreCase)) {
            continue
        }
        [void]$issueTemplateGitRecords.Add($record)
        $caseInsensitiveExpectedPath = @($expectedIssueTemplateGitPaths | Where-Object {
            [string]::Equals($_, $record.Path, [StringComparison]::OrdinalIgnoreCase)
        })
        if (-not $record.Path.StartsWith($issueTemplateGitPrefix, [StringComparison]::Ordinal) -or
            ($caseInsensitiveExpectedPath.Count -eq 1 -and $record.Path -cne $caseInsensitiveExpectedPath[0])) {
            Add-Failure "Active issue-template path must use exact Git casing: $($record.Path)"
            continue
        }
        if ($expectedIssueTemplateGitPaths -cnotcontains $record.Path) {
            Add-Failure "Unexpected tracked active issue-template path: $($record.Path)"
        }
    }

    foreach ($expectedPath in $expectedIssueTemplateGitPaths) {
        $matchingRecords = @($issueTemplateGitRecords | Where-Object { $_.Path -ceq $expectedPath })
        if ($matchingRecords.Count -eq 0) {
            Add-Failure "Active issue-template file is not tracked at exact Git path: $expectedPath"
            continue
        }
        if ($matchingRecords.Count -ne 1) {
            Add-Failure "Ambiguous Git index entries for active issue-template path: $expectedPath"
            continue
        }
        if ($matchingRecords[0].Stage -cne '0' -or $matchingRecords[0].Mode -cne '100644') {
            Add-Failure "Active issue-template Git entry must be stage-0 mode 100644: $expectedPath"
        }
    }
}

$gitattributesRelativePath = '.gitattributes'
$gitattributesPath = Join-Path $repositoryRoot $gitattributesRelativePath
$issueTemplateByteStabilityRule = '/.github/ISSUE_TEMPLATE/*.yml -text'
$gitattributesLines = @()
$gitattributesReadable = $false
try {
    if (-not (Test-Path -LiteralPath $gitattributesPath -PathType Leaf)) {
        Add-Failure '.gitattributes must be an ordinary readable file.'
    }
    else {
        $gitattributesItem = Get-Item -LiteralPath $gitattributesPath -Force -ErrorAction Stop
        if ($gitattributesItem.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            Add-Failure '.gitattributes must be an ordinary readable file.'
        }
        else {
            $gitattributesLines = @(Get-Content -LiteralPath $gitattributesPath -ErrorAction Stop)
            $gitattributesReadable = $true
        }
    }
}
catch {
    Add-Failure '.gitattributes must be an ordinary readable file.'
}

if ($gitattributesReadable) {
    $byteStabilityRuleCount = @($gitattributesLines | Where-Object {
        $_ -ceq $issueTemplateByteStabilityRule
    }).Count
    if ($byteStabilityRuleCount -ne 1) {
        Add-Failure '.gitattributes must contain exactly one issue-form byte-stability rule.'
    }
}

$gitAttributeLines = @()
$gitAttributesReadable = $false
if ($null -eq $gitCommand) {
    Add-Failure 'Cannot inspect Git text attributes for active issue-template paths: git is unavailable'
}
else {
    try {
        $gitAttributeLines = @(& $gitCommand.Source -C $repositoryRoot -c core.quotePath=false check-attr text -- $expectedIssueTemplateGitPaths 2>&1 |
            ForEach-Object { $_.ToString() })
        $gitAttributeExitCode = $LASTEXITCODE
        if ($gitAttributeExitCode -ne 0) {
            Add-Failure 'Cannot inspect Git text attributes for active issue-template paths'
        }
        else {
            $gitAttributesReadable = $true
        }
    }
    catch {
        Add-Failure 'Cannot inspect Git text attributes for active issue-template paths'
    }
}

if ($gitAttributesReadable) {
    if ($gitAttributeLines.Count -ne $expectedIssueTemplateGitPaths.Count) {
        Add-Failure "Expected 3 Git text attribute records, found $($gitAttributeLines.Count)"
    }
    $gitAttributeRecords = [Collections.Generic.List[object]]::new()
    foreach ($line in $gitAttributeLines) {
        $attributeMatch = [regex]::Match($line, '^(.*): text: (.*)$')
        if (-not $attributeMatch.Success) {
            Add-Failure "Cannot parse Git text attribute record: $line"
            continue
        }
        $reportedPath = $attributeMatch.Groups[1].Value
        $normalizedReportedPath = $reportedPath.Replace('\', '/')
        if ($expectedIssueTemplateGitPaths -cnotcontains $normalizedReportedPath) {
            Add-Failure "Unexpected Git text attribute path: $reportedPath"
            continue
        }
        [void]$gitAttributeRecords.Add([pscustomobject]@{
            Path = $normalizedReportedPath
            Value = $attributeMatch.Groups[2].Value
        })
    }
    foreach ($expectedPath in $expectedIssueTemplateGitPaths) {
        $matchingAttributeRecords = @($gitAttributeRecords | Where-Object { $_.Path -ceq $expectedPath })
        if ($matchingAttributeRecords.Count -ne 1) {
            Add-Failure "Ambiguous Git text attribute result: $expectedPath"
            continue
        }
        if ($matchingAttributeRecords[0].Value -cne 'unset') {
            Add-Failure "Issue-form Git text attribute is not unset: $expectedPath"
        }
    }
}

foreach ($fileName in $issueTemplateFileNames) {
    if (-not $ordinaryIssueTemplateFiles.Contains($fileName)) { continue }
    $relativePath = "$issueTemplateRelativeRoot/$fileName"
    $filePath = Join-Path $issueTemplateRoot $fileName
    try { $actualHash = (Get-FileHash -LiteralPath $filePath -Algorithm SHA256).Hash.ToLowerInvariant() }
    catch { Add-Failure "Cannot hash active issue-template file: $relativePath"; continue }
    if ($actualHash -cne $expectedIssueTemplateHashes[$fileName]) {
        Add-Failure "Hash mismatch for active issue-template file: $relativePath"
    }
}
```

- [ ] **Step 5: Exercise exact-set, attribute, hash, reparse-point, and Git-casing failures**

Run this focused mutation check. It first stages the three active forms so the real index represents the intended tracked-file contract; keep that deliberate staging through Step 8. Every temporary filesystem mutation is restored in `finally`, the wrong-case record exists only in an alternate temporary index, and `.gitattributes` mutations occur only in a disposable linked worktree created from a temporary index snapshot. The last assertion requires the exact green validator output against the restored real index:

```powershell
function Invoke-RepositoryVerifier {
    param([string]$RepositoryRoot = (Resolve-Path '.').Path)

    $validatorPath = Join-Path $RepositoryRoot '.github\cli\verify-repository-setup.ps1'
    $output = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $validatorPath 2>&1 | ForEach-Object { $_.ToString() })
    [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output }
}

function Assert-RepositoryVerifierFailure {
    param(
        [Parameter(Mandatory)][string[]]$ExpectedErrors,
        [string]$RepositoryRoot = (Resolve-Path '.').Path
    )

    $result = Invoke-RepositoryVerifier -RepositoryRoot $RepositoryRoot
    if ($result.ExitCode -ne 1) {
        $result.Output
        throw "Expected repository validator exit code 1, found $($result.ExitCode)."
    }
    foreach ($expectedError in $ExpectedErrors) {
        if ($result.Output -notcontains "ERROR: $expectedError") {
            $result.Output
            throw "Expected validator failure was not reported: $expectedError"
        }
    }
}

function Assert-RepositoryVerifierSuccess {
    param([string]$RepositoryRoot = (Resolve-Path '.').Path)

    $result = Invoke-RepositoryVerifier -RepositoryRoot $RepositoryRoot
    if ($result.ExitCode -ne 0 -or $result.Output.Count -ne 1 -or $result.Output[0] -cne 'Repository setup validation passed.') {
        $result.Output
        throw 'Repository validator did not return its exact success contract.'
    }
}

$issueTemplateGitPaths = @(
    '.github/ISSUE_TEMPLATE/01-bug.yml',
    '.github/ISSUE_TEMPLATE/02-feature.yml',
    '.github/ISSUE_TEMPLATE/config.yml'
)
git add -- $issueTemplateGitPaths
if ($LASTEXITCODE -ne 0) { throw 'Unable to stage active issue-template fixture inputs.' }

$issueTemplateRoot = (Resolve-Path '.github\ISSUE_TEMPLATE').Path
$bugPath = Join-Path $issueTemplateRoot '01-bug.yml'
$bugBytes = [IO.File]::ReadAllBytes($bugPath)
$missingBackup = Join-Path ([IO.Path]::GetTempPath()) "01-bug-$([guid]::NewGuid()).yml"
try {
    Move-Item -LiteralPath $bugPath -Destination $missingBackup
    Assert-RepositoryVerifierFailure 'Missing active issue-template file: .github/ISSUE_TEMPLATE/01-bug.yml'
}
finally {
    if (Test-Path -LiteralPath $missingBackup) {
        Move-Item -LiteralPath $missingBackup -Destination $bugPath
    }
}

$unexpectedPath = Join-Path $issueTemplateRoot 'unexpected.yml'
try {
    [IO.File]::WriteAllText($unexpectedPath, "unexpected`n", [Text.UTF8Encoding]::new($false))
    Assert-RepositoryVerifierFailure 'Unexpected active issue-template entry: unexpected.yml'
}
finally {
    if (Test-Path -LiteralPath $unexpectedPath) { Remove-Item -LiteralPath $unexpectedPath -Force }
}

try {
    [IO.File]::WriteAllBytes($bugPath, [byte[]]($bugBytes + [byte]10))
    Assert-RepositoryVerifierFailure 'Hash mismatch for active issue-template file: .github/ISSUE_TEMPLATE/01-bug.yml'
}
finally {
    [IO.File]::WriteAllBytes($bugPath, $bugBytes)
}

$reparsePath = Join-Path $issueTemplateRoot 'reparse-probe'
$reparseTarget = Join-Path ([IO.Path]::GetTempPath()) "issue-form-reparse-$([guid]::NewGuid())"
New-Item -ItemType Directory -Path $reparseTarget | Out-Null
try {
    New-Item -ItemType Junction -Path $reparsePath -Target $reparseTarget | Out-Null
    Assert-RepositoryVerifierFailure 'Reparse point is not allowed under .github/ISSUE_TEMPLATE: reparse-probe'
}
finally {
    if (Test-Path -LiteralPath $reparsePath) { [IO.Directory]::Delete($reparsePath) }
    if (Test-Path -LiteralPath $reparseTarget) { Remove-Item -LiteralPath $reparseTarget -Recurse -Force }
}

$gitIndexPath = @(git rev-parse --git-path index)
if ($LASTEXITCODE -ne 0 -or $gitIndexPath.Count -ne 1) { throw 'Unable to locate the current Git index.' }
$bugBlob = @(git hash-object -- .github/ISSUE_TEMPLATE/01-bug.yml)
if ($LASTEXITCODE -ne 0 -or $bugBlob.Count -ne 1) { throw 'Unable to identify the bug-form blob.' }
$temporaryIndex = Join-Path ([IO.Path]::GetTempPath()) "issue-form-index-$([guid]::NewGuid())"
$previousGitIndexFile = [Environment]::GetEnvironmentVariable('GIT_INDEX_FILE', 'Process')
Copy-Item -LiteralPath $gitIndexPath[0] -Destination $temporaryIndex
try {
    [Environment]::SetEnvironmentVariable('GIT_INDEX_FILE', $temporaryIndex, 'Process')
    git update-index --force-remove -- .github/ISSUE_TEMPLATE/01-bug.yml
    if ($LASTEXITCODE -ne 0) { throw 'Unable to remove the exact-case bug-form fixture entry.' }
    $cacheInfo = "100644,$($bugBlob[0]),.github/issue_template/01-bug.yml"
    git update-index --add --cacheinfo $cacheInfo
    if ($LASTEXITCODE -ne 0) { throw 'Unable to add the lowercase bug-form fixture entry.' }

    if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) {
        if (-not (Test-Path -LiteralPath '.github\issue_template\01-bug.yml' -PathType Leaf)) {
            throw 'The Windows fixture did not reproduce the case-insensitive filesystem lookup.'
        }
        Write-Output 'RED confirmed: the lowercase Git path still satisfies the old Windows filesystem lookup.'
    }
    Assert-RepositoryVerifierFailure 'Active issue-template path must use exact Git casing: .github/issue_template/01-bug.yml'
}
finally {
    [Environment]::SetEnvironmentVariable('GIT_INDEX_FILE', $previousGitIndexFile, 'Process')
    if (Test-Path -LiteralPath $temporaryIndex) { Remove-Item -LiteralPath $temporaryIndex -Force }
    if (Test-Path -LiteralPath "$temporaryIndex.lock") { Remove-Item -LiteralPath "$temporaryIndex.lock" -Force }
}

$attributeFixtureIndex = Join-Path ([IO.Path]::GetTempPath()) "issue-form-attributes-index-$([guid]::NewGuid())"
$previousGitIndexFile = [Environment]::GetEnvironmentVariable('GIT_INDEX_FILE', 'Process')
Copy-Item -LiteralPath $gitIndexPath[0] -Destination $attributeFixtureIndex
try {
    [Environment]::SetEnvironmentVariable('GIT_INDEX_FILE', $attributeFixtureIndex, 'Process')
    git add -- .gitattributes $issueTemplateGitPaths .github/cli/verify-repository-setup.ps1
    if ($LASTEXITCODE -ne 0) { throw 'Unable to stage the attribute fixture snapshot.' }
    git diff --cached --check -- .gitattributes $issueTemplateGitPaths .github/cli/verify-repository-setup.ps1
    if ($LASTEXITCODE -ne 0) { throw 'Attribute fixture snapshot diff check failed.' }
    $attributeFixtureTree = @(git write-tree)
    if ($LASTEXITCODE -ne 0 -or $attributeFixtureTree.Count -ne 1) {
        throw 'Unable to write the attribute fixture tree.'
    }
}
finally {
    [Environment]::SetEnvironmentVariable('GIT_INDEX_FILE', $previousGitIndexFile, 'Process')
    if (Test-Path -LiteralPath $attributeFixtureIndex) { Remove-Item -LiteralPath $attributeFixtureIndex -Force }
    if (Test-Path -LiteralPath "$attributeFixtureIndex.lock") { Remove-Item -LiteralPath "$attributeFixtureIndex.lock" -Force }
}

$attributeFixtureCommit = @(git commit-tree $attributeFixtureTree[0] -p HEAD -m 'Task 6 issue-form attribute fixture')
if ($LASTEXITCODE -ne 0 -or $attributeFixtureCommit.Count -ne 1) {
    throw 'Unable to create the attribute fixture commit.'
}

$attributeFixtureRoot = Join-Path ([IO.Path]::GetTempPath()) "issue-form-attributes-$([guid]::NewGuid())"
try {
    git worktree add --detach $attributeFixtureRoot $attributeFixtureCommit[0] | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Unable to create the disposable attribute fixture worktree.' }

    $attributeFixturePath = Join-Path $attributeFixtureRoot '.gitattributes'
    $attributeFixtureBytes = [IO.File]::ReadAllBytes($attributeFixturePath)
    $attributeFixtureLines = @(Get-Content -LiteralPath $attributeFixturePath)
    $byteStabilityRule = '/.github/ISSUE_TEMPLATE/*.yml -text'
    $normalizedCleanAttributeOutput = @(git -C $attributeFixtureRoot -c core.quotePath=false check-attr text -- $issueTemplateGitPaths 2>&1 |
        ForEach-Object { $_.ToString().Replace('\', '/') })
    $cleanAttributeExitCode = $LASTEXITCODE
    if ($cleanAttributeExitCode -ne 0 -or $normalizedCleanAttributeOutput.Count -ne $issueTemplateGitPaths.Count) {
        $normalizedCleanAttributeOutput
        throw 'Clean attribute fixture did not return exactly three Git attribute records.'
    }
    foreach ($path in $issueTemplateGitPaths) {
        if (@($normalizedCleanAttributeOutput | Where-Object { $_ -ceq "${path}: text: unset" }).Count -ne 1) {
            $normalizedCleanAttributeOutput
            throw "Clean attribute fixture did not report text: unset: $path"
        }
    }
    Assert-RepositoryVerifierSuccess -RepositoryRoot $attributeFixtureRoot
    Write-Output 'GREEN confirmed: the exact byte-stability rule yields text: unset for all three forms.'

    try {
        $withoutByteStabilityRule = [string[]]@($attributeFixtureLines | Where-Object { $_ -cne $byteStabilityRule })
        [IO.File]::WriteAllLines($attributeFixturePath, $withoutByteStabilityRule, [Text.UTF8Encoding]::new($false))
        Assert-RepositoryVerifierFailure -ExpectedErrors @(
            '.gitattributes must contain exactly one issue-form byte-stability rule.'
            'Issue-form Git text attribute is not unset: .github/ISSUE_TEMPLATE/01-bug.yml'
            'Issue-form Git text attribute is not unset: .github/ISSUE_TEMPLATE/02-feature.yml'
            'Issue-form Git text attribute is not unset: .github/ISSUE_TEMPLATE/config.yml'
        ) -RepositoryRoot $attributeFixtureRoot
        Write-Output 'RED confirmed: deleting the rule fails before any issue-form bytes are converted.'
    }
    finally {
        [IO.File]::WriteAllBytes($attributeFixturePath, $attributeFixtureBytes)
    }

    try {
        $duplicateRuleLines = [string[]]@($attributeFixtureLines + $byteStabilityRule)
        [IO.File]::WriteAllLines($attributeFixturePath, $duplicateRuleLines, [Text.UTF8Encoding]::new($false))
        Assert-RepositoryVerifierFailure -ExpectedErrors @(
            '.gitattributes must contain exactly one issue-form byte-stability rule.'
        ) -RepositoryRoot $attributeFixtureRoot
        Write-Output 'RED confirmed: duplicating the exact rule fails the exact-one contract.'
    }
    finally {
        [IO.File]::WriteAllBytes($attributeFixturePath, $attributeFixtureBytes)
    }

    try {
        $overrideRuleLines = [string[]]@($attributeFixtureLines + '/.github/ISSUE_TEMPLATE/*.yml text')
        [IO.File]::WriteAllLines($attributeFixturePath, $overrideRuleLines, [Text.UTF8Encoding]::new($false))
        Assert-RepositoryVerifierFailure -ExpectedErrors @(
            'Issue-form Git text attribute is not unset: .github/ISSUE_TEMPLATE/01-bug.yml'
            'Issue-form Git text attribute is not unset: .github/ISSUE_TEMPLATE/02-feature.yml'
            'Issue-form Git text attribute is not unset: .github/ISSUE_TEMPLATE/config.yml'
        ) -RepositoryRoot $attributeFixtureRoot
        Write-Output 'RED confirmed: a later text override defeats effective -text and fails validation.'
    }
    finally {
        [IO.File]::WriteAllBytes($attributeFixturePath, $attributeFixtureBytes)
    }

    Assert-RepositoryVerifierSuccess -RepositoryRoot $attributeFixtureRoot
}
finally {
    if (Test-Path -LiteralPath $attributeFixtureRoot) {
        git worktree remove --force $attributeFixtureRoot
        if ($LASTEXITCODE -ne 0) { Write-Warning "Unable to remove attribute fixture worktree: $attributeFixtureRoot" }
    }
    git worktree prune
}

Assert-RepositoryVerifierSuccess
Write-Output 'GREEN confirmed: exact uppercase stage-0 mode 100644 Git paths pass.'
Write-Output 'Active issue-form validator fixture checks passed.'
```

Expected: on Windows, the lowercase index fixture first reports `RED confirmed: the lowercase Git path still satisfies the old Windows filesystem lookup.` On every platform, the alternate index is rejected with `Active issue-template path must use exact Git casing: .github/issue_template/01-bug.yml`. The disposable attribute worktree proves the clean exact rule yields `text: unset` for all three forms and exact validator success; deleting the rule fails both the exact-one rule and effective-attribute checks before any EOL conversion, duplicating it fails exact-one validation, and a later `text` rule fails all three effective-attribute checks while the required line remains. Restoring the real index reports `GREEN confirmed: exact uppercase stage-0 mode 100644 Git paths pass.` and `Active issue-form validator fixture checks passed.` Missing, unexpected, reparse-point, hash-mismatched, untracked, wrong-mode, wrong-stage, and wrong-case active entries are rejected. The three active forms remain deliberately staged; every temporary filesystem, index, and linked-worktree mutation is restored.

- [ ] **Step 6: Validate YAML schemas and parsed issue-form semantics**

In VS Code, call `get_errors` for all three active files:

```text
.github/ISSUE_TEMPLATE/01-bug.yml
.github/ISSUE_TEMPLATE/02-feature.yml
.github/ISSUE_TEMPLATE/config.yml
```

Expected: all three files have no YAML syntax or GitHub issue-form schema diagnostics.

Then run this ephemeral semantic check. It uses `ConvertFrom-Yaml`, PyYAML, `yaml`, or `js-yaml` when one is already available, in that order, and never installs or adds a runtime dependency:

```powershell
$issueTemplatePaths = [ordered]@{
    '01-bug.yml' = '.github\ISSUE_TEMPLATE\01-bug.yml'
    '02-feature.yml' = '.github\ISSUE_TEMPLATE\02-feature.yml'
    'config.yml' = '.github\ISSUE_TEMPLATE\config.yml'
}
$documents = $null
$parserName = $null

if (Get-Command ConvertFrom-Yaml -ErrorAction SilentlyContinue) {
    $parsedDocuments = [ordered]@{}
    foreach ($entry in $issueTemplatePaths.GetEnumerator()) {
        $parsedDocuments[$entry.Key] = Get-Content -LiteralPath $entry.Value -Raw | ConvertFrom-Yaml
    }
    $documents = [pscustomobject]$parsedDocuments
    $parserName = 'ConvertFrom-Yaml'
}

if ($null -eq $documents) {
    $pythonCommand = Get-Command python -ErrorAction SilentlyContinue
    if ($pythonCommand) {
        & $pythonCommand.Source -c 'import yaml' 2>$null
        if ($LASTEXITCODE -eq 0) {
            $pythonScript = @'
import json
from pathlib import Path
import yaml

paths = {
    "01-bug.yml": ".github/ISSUE_TEMPLATE/01-bug.yml",
    "02-feature.yml": ".github/ISSUE_TEMPLATE/02-feature.yml",
    "config.yml": ".github/ISSUE_TEMPLATE/config.yml",
}
print(json.dumps({name: yaml.safe_load(Path(path).read_text(encoding="utf-8")) for name, path in paths.items()}))
'@
            $json = @($pythonScript | & $pythonCommand.Source -)
            if ($LASTEXITCODE -ne 0) { throw 'PyYAML parser check failed.' }
            $documents = ($json -join "`n") | ConvertFrom-Json
            $parserName = 'PyYAML'
        }
    }
}

if ($null -eq $documents) {
    $nodeCommand = Get-Command node -ErrorAction SilentlyContinue
    if ($nodeCommand) {
        $yamlModule = $null
        foreach ($candidate in @('yaml', 'js-yaml')) {
            & $nodeCommand.Source -e "require.resolve('$candidate')" 2>$null
            if ($LASTEXITCODE -eq 0) { $yamlModule = $candidate; break }
        }
        if ($yamlModule) {
            $env:ISSUE_FORM_YAML_MODULE = $yamlModule
            try {
                $nodeScript = @'
const fs = require("fs");
const moduleName = process.env.ISSUE_FORM_YAML_MODULE;
const yaml = require(moduleName);
const parse = moduleName === "yaml" ? yaml.parse : yaml.load;
const paths = {
  "01-bug.yml": ".github/ISSUE_TEMPLATE/01-bug.yml",
  "02-feature.yml": ".github/ISSUE_TEMPLATE/02-feature.yml",
  "config.yml": ".github/ISSUE_TEMPLATE/config.yml",
};
const documents = Object.fromEntries(
  Object.entries(paths).map(([name, path]) => [name, parse(fs.readFileSync(path, "utf8"))]),
);
process.stdout.write(JSON.stringify(documents));
'@
                $json = @($nodeScript | & $nodeCommand.Source -)
                if ($LASTEXITCODE -ne 0) { throw "$yamlModule parser check failed." }
                $documents = ($json -join "`n") | ConvertFrom-Json
                $parserName = $yamlModule
            }
            finally {
                Remove-Item Env:ISSUE_FORM_YAML_MODULE -ErrorAction SilentlyContinue
            }
        }
    }
}

if ($null -ne $documents) {
    try {
        $documents = $documents | ConvertTo-Json -Depth 100 | ConvertFrom-Json
    }
    catch {
        throw "Issue-form semantic normalization failed after ${parserName}: $($_.Exception.Message)"
    }
}

$hashtableFixtureDocuments = @{
    'fixture.yml' = @{
        name = 'Fixture form'
        description = 'Exercises IDictionary normalization.'
        body = @(
            @{
                type = 'checkboxes'
                id = 'existing_issue'
                attributes = @{ options = @(@{ label = 'Checked'; required = $true }) }
            },
            @{
                type = 'textarea'
                id = 'problem'
                attributes = @{ label = 'Problem' }
                validations = @{ required = $true }
            }
        )
    }
    'config.yml' = @{ blank_issues_enabled = $false }
}
try {
    $normalizedHashtableFixture = $hashtableFixtureDocuments | ConvertTo-Json -Depth 100 | ConvertFrom-Json
}
catch {
    throw "Hashtable semantic normalization fixture failed: $($_.Exception.Message)"
}
$fixtureForm = $normalizedHashtableFixture.'fixture.yml'
$fixturePropertyNames = @($fixtureForm.PSObject.Properties.Name)
foreach ($requiredProperty in @('name', 'description', 'body')) {
    if ($fixturePropertyNames -cnotcontains $requiredProperty) {
        throw "Hashtable semantic normalization fixture is missing top-level $requiredProperty."
    }
}
if (@($fixtureForm.body).Count -ne 2) {
    throw 'Hashtable semantic normalization fixture did not preserve the body array.'
}
$fixtureItemsById = @{}
foreach ($item in @($fixtureForm.body)) { $fixtureItemsById[[string]$item.id] = $item }
if ($fixtureItemsById['problem'].validations.required -ne $true) {
    throw 'Hashtable semantic normalization fixture lost nested validation access.'
}
$fixtureOptions = @($fixtureItemsById['existing_issue'].attributes.options)
if ($fixtureOptions.Count -ne 1 -or $fixtureOptions[0].required -ne $true) {
    throw 'Hashtable semantic normalization fixture did not preserve checkbox options.'
}
$fixtureConfig = $normalizedHashtableFixture.'config.yml'
if ($fixtureConfig.blank_issues_enabled -isnot [bool] -or $fixtureConfig.blank_issues_enabled -ne $false) {
    throw 'Hashtable semantic normalization fixture did not preserve Boolean false.'
}
Write-Output 'Hashtable semantic normalization fixture passed.'

if ($null -eq $documents) {
    Write-Output 'No environment YAML parser detected; parser check skipped without adding a dependency.'
}
else {
    function Assert-IssueFormContract {
        param(
            [Parameter(Mandatory)]$Form,
            [Parameter(Mandatory)][string]$FileName,
            [Parameter(Mandatory)][string[]]$CoreIds,
            [Parameter(Mandatory)][string]$CheckboxId
        )

        $propertyNames = @($Form.PSObject.Properties.Name)
        foreach ($requiredProperty in @('name', 'description', 'body')) {
            if ($propertyNames -cnotcontains $requiredProperty) {
                throw "$FileName is missing top-level $requiredProperty."
            }
        }
        if ([string]::IsNullOrWhiteSpace([string]$Form.name) -or
            [string]::IsNullOrWhiteSpace([string]$Form.description) -or @($Form.body).Count -eq 0) {
            throw "$FileName has an empty name, description, or body."
        }
        foreach ($forbiddenProperty in @('labels', 'assignees', 'contact_links')) {
            if ($propertyNames -ccontains $forbiddenProperty) {
                throw "$FileName must not define $forbiddenProperty."
            }
        }

        $itemsById = @{}
        $ids = [Collections.Generic.List[string]]::new()
        foreach ($item in @($Form.body)) {
            if ($item.PSObject.Properties.Name -cnotcontains 'id') { continue }
            $id = [string]$item.id
            if ($itemsById.ContainsKey($id)) { throw "$FileName contains duplicate body id: $id" }
            $itemsById[$id] = $item
            [void]$ids.Add($id)
        }
        if ($ids.Count -ne @($ids | Select-Object -Unique).Count) {
            throw "$FileName body IDs are not unique."
        }
        foreach ($coreId in $CoreIds) {
            if (-not $itemsById.ContainsKey($coreId)) { throw "$FileName is missing core field: $coreId" }
            if ($coreId -cne $CheckboxId -and $itemsById[$coreId].validations.required -ne $true) {
                throw "$FileName core field is not required: $coreId"
            }
        }
        $checkbox = $itemsById[$CheckboxId]
        if ($checkbox.type -cne 'checkboxes' -or @($checkbox.attributes.options | Where-Object { $_.required -eq $true }).Count -eq 0) {
            throw "$FileName duplicate check is not required."
        }
    }

    $bugForm = $documents.'01-bug.yml'
    $featureForm = $documents.'02-feature.yml'
    $chooserConfig = $documents.'config.yml'
    Assert-IssueFormContract $bugForm '01-bug.yml' @(
        'existing_issue', 'problem', 'reproduction', 'expected_behavior', 'actual_behavior', 'environment'
    ) 'existing_issue'
    Assert-IssueFormContract $featureForm '02-feature.yml' @(
        'existing_request', 'problem_value', 'desired_outcome', 'acceptance_criteria'
    ) 'existing_request'

    $configProperties = @($chooserConfig.PSObject.Properties.Name)
    if ($chooserConfig.blank_issues_enabled -ne $false) {
        throw 'config.yml must set blank_issues_enabled to false.'
    }
    foreach ($forbiddenProperty in @('labels', 'assignees', 'contact_links')) {
        if ($configProperties -ccontains $forbiddenProperty) {
            throw "config.yml must not define $forbiddenProperty."
        }
    }
    Write-Output "Issue-form semantic validation passed with $parserName."
}
```

Expected: `Hashtable semantic normalization fixture passed.` proves that an `IDictionary` graph normalizes to uniform `PSCustomObject` values while preserving body and options arrays, nested validation access, and Boolean `false`. If an environment YAML parser exists, the command then reports `Issue-form semantic validation passed with <parser>.` after validating top-level `name`, `description`, and `body`, unique body IDs, required core fields, `blank_issues_enabled: false`, and the absence of labels, assignees, and contact links. If none exists, `$documents` remains `$null` and the command reports the explicit skip without installing a dependency; VS Code YAML diagnostics remain mandatory.

- [ ] **Step 7: Run the GREEN validation gate and portable-checkout tests**

```powershell
$validatorOutput = @(& powershell -NoProfile -ExecutionPolicy Bypass -File .github/cli/verify-repository-setup.ps1 2>&1 | ForEach-Object { $_.ToString() })
if ($LASTEXITCODE -ne 0 -or $validatorOutput.Count -ne 1 -or $validatorOutput[0] -cne 'Repository setup validation passed.') {
    $validatorOutput
    throw 'Repository validator did not return its exact success contract.'
}
$validatorOutput
$issueTemplatePaths = @(
    '.github/ISSUE_TEMPLATE/01-bug.yml',
    '.github/ISSUE_TEMPLATE/02-feature.yml',
    '.github/ISSUE_TEMPLATE/config.yml'
)
$attributeOutput = @(git check-attr text -- $issueTemplatePaths)
foreach ($path in $issueTemplatePaths) {
    if ($attributeOutput -cnotcontains "${path}: text: unset") {
        $attributeOutput
        throw "Active issue-form EOL conversion is not disabled: $path"
    }
}
git diff --check
if ($LASTEXITCODE -ne 0) { throw 'git diff --check failed.' }
```

Then stage only the Task 6 implementation paths, create an unreachable validation commit without moving the branch, and test clean temporary checkouts under both `core.autocrlf` settings:

```powershell
$task6Paths = @(
    '.gitattributes',
    '.github/ISSUE_TEMPLATE/01-bug.yml',
    '.github/ISSUE_TEMPLATE/02-feature.yml',
    '.github/ISSUE_TEMPLATE/config.yml',
    '.github/cli/verify-repository-setup.ps1'
)
git add -- $task6Paths
if ($LASTEXITCODE -ne 0) { throw 'Unable to stage Task 6 validation inputs.' }
git diff --cached --check -- $task6Paths
if ($LASTEXITCODE -ne 0) { throw 'Staged Task 6 diff check failed.' }

$treeHash = @(git write-tree)
if ($LASTEXITCODE -ne 0 -or $treeHash.Count -ne 1) { throw 'Unable to write the Task 6 validation tree.' }
$validationCommit = @(git commit-tree $treeHash[0] -p HEAD -m 'Task 6 checkout validation')
if ($LASTEXITCODE -ne 0 -or $validationCommit.Count -ne 1) { throw 'Unable to create the Task 6 validation commit.' }

$expectedIssueTemplateHashes = [ordered]@{
    '.github/ISSUE_TEMPLATE/01-bug.yml' = '8f2c31b169477b86d85e60f9d1c91eed349fae829f1071b8b42dc93624d8879a'
    '.github/ISSUE_TEMPLATE/02-feature.yml' = '748e69155e9e60acd16f5cbb93b6398fd5853905951829080a9c440ed5c0e7a4'
    '.github/ISSUE_TEMPLATE/config.yml' = '1f103c6a9dd07cd13a9a6f17ace6b813f47747eb9cb7e00488cb2073caaf91bb'
}
$temporaryWorktrees = [Collections.Generic.List[string]]::new()
try {
    foreach ($autocrlf in @('true', 'false')) {
        $checkoutRoot = Join-Path ([IO.Path]::GetTempPath()) "issue-forms-$autocrlf-$([guid]::NewGuid())"
        [void]$temporaryWorktrees.Add($checkoutRoot)
        git -c "core.autocrlf=$autocrlf" worktree add --detach $checkoutRoot $validationCommit[0] | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Unable to create core.autocrlf=$autocrlf checkout." }

        $previousConfigCount = [Environment]::GetEnvironmentVariable('GIT_CONFIG_COUNT', 'Process')
        $previousConfigKey = [Environment]::GetEnvironmentVariable('GIT_CONFIG_KEY_0', 'Process')
        $previousConfigValue = [Environment]::GetEnvironmentVariable('GIT_CONFIG_VALUE_0', 'Process')
        try {
            [Environment]::SetEnvironmentVariable('GIT_CONFIG_COUNT', '1', 'Process')
            [Environment]::SetEnvironmentVariable('GIT_CONFIG_KEY_0', 'core.autocrlf', 'Process')
            [Environment]::SetEnvironmentVariable('GIT_CONFIG_VALUE_0', $autocrlf, 'Process')

            $checkoutAttributes = @(git -C $checkoutRoot check-attr text -- $issueTemplatePaths)
            foreach ($path in $issueTemplatePaths) {
                if ($checkoutAttributes -cnotcontains "${path}: text: unset") {
                    $checkoutAttributes
                    throw "Clean checkout lost the -text contract with core.autocrlf=${autocrlf}: $path"
                }
            }
            foreach ($entry in $expectedIssueTemplateHashes.GetEnumerator()) {
                $checkoutPath = Join-Path $checkoutRoot ($entry.Key.Replace('/', '\'))
                $actualHash = (Get-FileHash -LiteralPath $checkoutPath -Algorithm SHA256).Hash.ToLowerInvariant()
                if ($actualHash -cne $entry.Value) {
                    throw "Clean checkout hash mismatch with core.autocrlf=${autocrlf}: $($entry.Key)"
                }
            }
            $checkoutValidator = Join-Path $checkoutRoot '.github\cli\verify-repository-setup.ps1'
            $checkoutValidatorOutput = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $checkoutValidator 2>&1 | ForEach-Object { $_.ToString() })
            if ($LASTEXITCODE -ne 0 -or $checkoutValidatorOutput.Count -ne 1 -or
                $checkoutValidatorOutput[0] -cne 'Repository setup validation passed.') {
                $checkoutValidatorOutput
                throw "Clean checkout validator failed with core.autocrlf=$autocrlf."
            }
            $checkoutStatus = @(git -C $checkoutRoot status --porcelain=v1)
            if ($LASTEXITCODE -ne 0 -or $checkoutStatus.Count -ne 0) {
                $checkoutStatus
                throw "Temporary checkout is not clean with core.autocrlf=$autocrlf."
            }
            Write-Output "Clean checkout validation passed with core.autocrlf=$autocrlf."
        }
        finally {
            [Environment]::SetEnvironmentVariable('GIT_CONFIG_COUNT', $previousConfigCount, 'Process')
            [Environment]::SetEnvironmentVariable('GIT_CONFIG_KEY_0', $previousConfigKey, 'Process')
            [Environment]::SetEnvironmentVariable('GIT_CONFIG_VALUE_0', $previousConfigValue, 'Process')
        }
    }
}
finally {
    foreach ($temporaryWorktree in $temporaryWorktrees) {
        if (Test-Path -LiteralPath $temporaryWorktree) {
            git worktree remove --force $temporaryWorktree
            if ($LASTEXITCODE -ne 0) { Write-Warning "Unable to remove temporary worktree: $temporaryWorktree" }
        }
    }
    git worktree prune
}
```

Expected: exactly `Repository setup validation passed.` from the working-tree validator, `text: unset` for all three active YAML paths, no output from either diff check, no diagnostics from the three-file VS Code `get_errors` check in Step 6, and one clean-checkout success line for each of `core.autocrlf=true` and `core.autocrlf=false`. In both temporary checkouts, the raw hashes remain exact and the repository validator returns its exact green line.

- [ ] **Step 8: Commit the EOL rule, active forms, and validator**

```powershell
git add -- .gitattributes .github/ISSUE_TEMPLATE/01-bug.yml .github/ISSUE_TEMPLATE/02-feature.yml .github/ISSUE_TEMPLATE/config.yml .github/cli/verify-repository-setup.ps1
git commit -m "feat: add structured GitHub issue forms" -- .gitattributes .github/ISSUE_TEMPLATE/01-bug.yml .github/ISSUE_TEMPLATE/02-feature.yml .github/ISSUE_TEMPLATE/config.yml .github/cli/verify-repository-setup.ps1
```

## Task 7: Perform Final Repository and Host Validation

**Files:**

- Verify: all files introduced by Tasks 1-6

- [ ] **Step 1: Run automated repository validation from a clean shell**

```powershell
$validatorOutput = @(& powershell -NoProfile -ExecutionPolicy Bypass -File .github/cli/verify-repository-setup.ps1 2>&1 | ForEach-Object { $_.ToString() })
if ($LASTEXITCODE -ne 0 -or $validatorOutput.Count -ne 1 -or $validatorOutput[0] -cne 'Repository setup validation passed.') {
    $validatorOutput
    throw 'Repository validator did not return its exact success contract.'
}
$repositoryRoot = (Resolve-Path '.').Path
$issueTemplatePaths = @(
    '.github/ISSUE_TEMPLATE/01-bug.yml',
    '.github/ISSUE_TEMPLATE/02-feature.yml',
    '.github/ISSUE_TEMPLATE/config.yml'
)
$gitattributesSelfByteStabilityRule = '/.gitattributes -text'
$issueTemplateByteStabilityRule = '/.github/ISSUE_TEMPLATE/*.yml -text'
$protectedAttributePaths = @('.gitattributes') + $issueTemplatePaths
$gitattributesPath = Join-Path $repositoryRoot '.gitattributes'
if (-not (Test-Path -LiteralPath $gitattributesPath -PathType Leaf)) {
    throw '.gitattributes must be an ordinary readable file.'
}
$gitattributesItem = Get-Item -LiteralPath $gitattributesPath -Force
if ($gitattributesItem.Attributes -band [IO.FileAttributes]::ReparsePoint) {
    throw '.gitattributes must be an ordinary readable file.'
}
$gitattributesLines = @(Get-Content -LiteralPath $gitattributesPath -ErrorAction Stop)
if (@($gitattributesLines | Where-Object { $_ -ceq $gitattributesSelfByteStabilityRule }).Count -ne 1) {
    throw '.gitattributes must contain exactly one self byte-stability rule.'
}
if (@($gitattributesLines | Where-Object { $_ -ceq $issueTemplateByteStabilityRule }).Count -ne 1) {
    throw '.gitattributes must contain exactly one issue-form byte-stability rule.'
}
$attributeOutput = @(git -C $repositoryRoot -c core.quotePath=false check-attr text -- $protectedAttributePaths 2>&1 |
    ForEach-Object { $_.ToString().Replace('\', '/') })
$attributeExitCode = $LASTEXITCODE
if ($attributeExitCode -ne 0 -or $attributeOutput.Count -ne $protectedAttributePaths.Count) {
    $attributeOutput
    throw 'Unable to read exactly four protected Git text attributes.'
}
foreach ($path in $protectedAttributePaths) {
    if (@($attributeOutput | Where-Object { $_ -ceq "${path}: text: unset" }).Count -ne 1) {
        $attributeOutput
        throw "Protected Git text attribute is not unset: $path"
    }
}
$baseCommit = git merge-base HEAD main
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($baseCommit)) {
    throw 'Unable to determine the branch base against main.'
}
git diff --check "$baseCommit..HEAD"
if ($LASTEXITCODE -ne 0) { throw 'git diff --check failed.' }
$validatorOutput

$expectedIssueTemplateHashes = [ordered]@{
    '.github/ISSUE_TEMPLATE/01-bug.yml' = '8f2c31b169477b86d85e60f9d1c91eed349fae829f1071b8b42dc93624d8879a'
    '.github/ISSUE_TEMPLATE/02-feature.yml' = '748e69155e9e60acd16f5cbb93b6398fd5853905951829080a9c440ed5c0e7a4'
    '.github/ISSUE_TEMPLATE/config.yml' = '1f103c6a9dd07cd13a9a6f17ace6b813f47747eb9cb7e00488cb2073caaf91bb'
}
$temporaryWorktrees = [Collections.Generic.List[string]]::new()
try {
    foreach ($autocrlf in @('true', 'false')) {
        $checkoutRoot = Join-Path ([IO.Path]::GetTempPath()) "final-issue-forms-$autocrlf-$([guid]::NewGuid())"
        [void]$temporaryWorktrees.Add($checkoutRoot)
        git -c "core.autocrlf=$autocrlf" worktree add --detach $checkoutRoot HEAD | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Unable to create final core.autocrlf=$autocrlf checkout." }

        $previousConfigCount = [Environment]::GetEnvironmentVariable('GIT_CONFIG_COUNT', 'Process')
        $previousConfigKey = [Environment]::GetEnvironmentVariable('GIT_CONFIG_KEY_0', 'Process')
        $previousConfigValue = [Environment]::GetEnvironmentVariable('GIT_CONFIG_VALUE_0', 'Process')
        try {
            [Environment]::SetEnvironmentVariable('GIT_CONFIG_COUNT', '1', 'Process')
            [Environment]::SetEnvironmentVariable('GIT_CONFIG_KEY_0', 'core.autocrlf', 'Process')
            [Environment]::SetEnvironmentVariable('GIT_CONFIG_VALUE_0', $autocrlf, 'Process')

            $checkoutAttributesPath = Join-Path $checkoutRoot '.gitattributes'
            $checkoutAttributeLines = @(Get-Content -LiteralPath $checkoutAttributesPath -ErrorAction Stop)
            if (@($checkoutAttributeLines | Where-Object { $_ -ceq $gitattributesSelfByteStabilityRule }).Count -ne 1 -or
                @($checkoutAttributeLines | Where-Object { $_ -ceq $issueTemplateByteStabilityRule }).Count -ne 1) {
                throw "Clean checkout lost an exact-one byte-stability rule with core.autocrlf=$autocrlf."
            }
            $checkoutAttributes = @(git -C $checkoutRoot -c core.quotePath=false check-attr text -- $protectedAttributePaths 2>&1 |
                ForEach-Object { $_.ToString().Replace('\', '/') })
            $checkoutAttributeExitCode = $LASTEXITCODE
            if ($checkoutAttributeExitCode -ne 0 -or $checkoutAttributes.Count -ne $protectedAttributePaths.Count) {
                $checkoutAttributes
                throw "Clean checkout did not return exactly four Git attributes with core.autocrlf=$autocrlf."
            }
            foreach ($path in $protectedAttributePaths) {
                if (@($checkoutAttributes | Where-Object { $_ -ceq "${path}: text: unset" }).Count -ne 1) {
                    $checkoutAttributes
                    throw "Clean checkout lost the -text contract with core.autocrlf=${autocrlf}: $path"
                }
            }
            foreach ($entry in $expectedIssueTemplateHashes.GetEnumerator()) {
                $checkoutPath = Join-Path $checkoutRoot ($entry.Key.Replace('/', '\'))
                $actualHash = (Get-FileHash -LiteralPath $checkoutPath -Algorithm SHA256).Hash.ToLowerInvariant()
                if ($actualHash -cne $entry.Value) {
                    throw "Clean checkout hash mismatch with core.autocrlf=${autocrlf}: $($entry.Key)"
                }
            }
            $checkoutValidator = Join-Path $checkoutRoot '.github\cli\verify-repository-setup.ps1'
            $checkoutValidatorOutput = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $checkoutValidator 2>&1 | ForEach-Object { $_.ToString() })
            if ($LASTEXITCODE -ne 0 -or $checkoutValidatorOutput.Count -ne 1 -or
                $checkoutValidatorOutput[0] -cne 'Repository setup validation passed.') {
                $checkoutValidatorOutput
                throw "Clean checkout validator failed with core.autocrlf=$autocrlf."
            }
            $checkoutStatus = @(git -C $checkoutRoot status --porcelain=v1)
            if ($LASTEXITCODE -ne 0 -or $checkoutStatus.Count -ne 0) {
                $checkoutStatus
                throw "Temporary checkout is not clean with core.autocrlf=$autocrlf."
            }
            Write-Output "Final clean checkout validation passed with core.autocrlf=$autocrlf."
        }
        finally {
            [Environment]::SetEnvironmentVariable('GIT_CONFIG_COUNT', $previousConfigCount, 'Process')
            [Environment]::SetEnvironmentVariable('GIT_CONFIG_KEY_0', $previousConfigKey, 'Process')
            [Environment]::SetEnvironmentVariable('GIT_CONFIG_VALUE_0', $previousConfigValue, 'Process')
        }
    }
}
finally {
    foreach ($temporaryWorktree in $temporaryWorktrees) {
        if (Test-Path -LiteralPath $temporaryWorktree) {
            git worktree remove --force $temporaryWorktree
            if ($LASTEXITCODE -ne 0) { Write-Warning "Unable to remove temporary worktree: $temporaryWorktree" }
        }
    }
    git worktree prune
}
```

Expected: exactly one `Repository setup validation passed.` line from the validator; root `.gitattributes` is ordinary and contains exactly one `/.gitattributes -text` plus exactly one `/.github/ISSUE_TEMPLATE/*.yml -text`; and `git check-attr text` returns exactly four effective `text: unset` records. `git diff --check` produces no output for the aggregate branch diff from its merge base with `main` through `HEAD`. Clean temporary checkouts under both `core.autocrlf=true` and `core.autocrlf=false` retain both exact-one rules, all four unset attributes, pinned hashes, exact sole validator success, and clean status. The current validator also rechecks the complete runtime and issue-form snapshots in each clone. The check does not assume a fixed commit count.

- [ ] **Step 2: Verify exact inventories and coherent Git snapshots**

First call `get_errors` for `.github/ISSUE_TEMPLATE/01-bug.yml`, `.github/ISSUE_TEMPLATE/02-feature.yml`, and `.github/ISSUE_TEMPLATE/config.yml`. Require no YAML or GitHub issue-form schema diagnostics. Their exact hashes below pin the approved fields and security wording.

```powershell
$skillNames = @(
    'brainstorming', 'dispatching-parallel-agents', 'executing-plans',
    'finishing-a-development-branch', 'receiving-code-review', 'requesting-code-review',
    'subagent-driven-development', 'systematic-debugging', 'test-driven-development',
    'using-git-worktrees', 'using-superpowers', 'verification-before-completion',
    'writing-plans', 'writing-skills'
)
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
$repositoryRoot = (Resolve-Path '.').Path
$expectedIssueTemplateFiles = @('01-bug.yml', '02-feature.yml', 'config.yml')
$issueTemplateGitPrefix = '.github/ISSUE_TEMPLATE/'
$expectedIssueTemplateGitPaths = @(
    '.github/ISSUE_TEMPLATE/01-bug.yml',
    '.github/ISSUE_TEMPLATE/02-feature.yml',
    '.github/ISSUE_TEMPLATE/config.yml'
)
$expectedIssueTemplateHashes = [ordered]@{
    '.github/ISSUE_TEMPLATE/01-bug.yml' = '8f2c31b169477b86d85e60f9d1c91eed349fae829f1071b8b42dc93624d8879a'
    '.github/ISSUE_TEMPLATE/02-feature.yml' = '748e69155e9e60acd16f5cbb93b6398fd5853905951829080a9c440ed5c0e7a4'
    '.github/ISSUE_TEMPLATE/config.yml' = '1f103c6a9dd07cd13a9a6f17ace6b813f47747eb9cb7e00488cb2073caaf91bb'
}
if (-not (Test-Path -LiteralPath '.github/ISSUE_TEMPLATE' -PathType Container)) {
    throw 'Missing active .github/ISSUE_TEMPLATE directory.'
}
$issueTemplateDirectoryCandidates = @(Get-ChildItem -LiteralPath '.github' -Directory -Force | Where-Object {
    [string]::Equals($_.Name, 'ISSUE_TEMPLATE', [StringComparison]::OrdinalIgnoreCase)
})
if ($issueTemplateDirectoryCandidates.Count -ne 1 -or
    $issueTemplateDirectoryCandidates[0].Name -cne 'ISSUE_TEMPLATE') {
    throw 'The active issue-template directory must be exactly .github/ISSUE_TEMPLATE.'
}
$issueTemplateEntries = @(Get-ChildItem -LiteralPath '.github/ISSUE_TEMPLATE' -Force)
$missingIssueTemplateFiles = $expectedIssueTemplateFiles | Where-Object {
    $name = $_
    @($issueTemplateEntries | Where-Object { -not $_.PSIsContainer -and $_.Name -ceq $name }).Count -ne 1
}
$unexpectedIssueTemplateEntries = @($issueTemplateEntries | Where-Object {
    $_.PSIsContainer -or ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -or
        $expectedIssueTemplateFiles -cnotcontains $_.Name
})
$gitCommand = Get-Command git -CommandType Application -ErrorAction SilentlyContinue
if ($null -eq $gitCommand) { throw 'Cannot inspect active issue-template paths because git is unavailable.' }
$gitIndexLines = @(& $gitCommand.Source -C $repositoryRoot -c core.quotePath=false ls-files --stage 2>&1 |
    ForEach-Object { $_.ToString() })
if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect the Git index for active issue-template paths.' }
$gitIndexRecords = @()
$issueTemplateGitRecords = @()
foreach ($line in $gitIndexLines) {
    if ($line -notmatch '^([0-7]{6}) ((?:[0-9a-fA-F]{40}|[0-9a-fA-F]{64})) ([0-3])\t(.*)$') {
        throw "Cannot parse Git index record: $line"
    }
    $record = [pscustomobject]@{
        Mode = $Matches[1]
        ObjectId = $Matches[2]
        Stage = $Matches[3]
        Path = $Matches[4]
    }
    $gitIndexRecords += $record
    if (-not $record.Path.StartsWith($issueTemplateGitPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        continue
    }
    $issueTemplateGitRecords += $record
    $caseInsensitiveExpectedPath = @($expectedIssueTemplateGitPaths | Where-Object {
        [string]::Equals($_, $record.Path, [StringComparison]::OrdinalIgnoreCase)
    })
    if (-not $record.Path.StartsWith($issueTemplateGitPrefix, [StringComparison]::Ordinal) -or
        ($caseInsensitiveExpectedPath.Count -eq 1 -and $record.Path -cne $caseInsensitiveExpectedPath[0])) {
        throw "Active issue-template path must use exact Git casing: $($record.Path)"
    }
    if ($expectedIssueTemplateGitPaths -cnotcontains $record.Path) {
        throw "Unexpected tracked active issue-template path: $($record.Path)"
    }
}
if ($issueTemplateGitRecords.Count -ne 3) {
    throw "Expected 3 tracked active issue-template paths, found $($issueTemplateGitRecords.Count)"
}
foreach ($expectedPath in $expectedIssueTemplateGitPaths) {
    $matchingRecords = @($issueTemplateGitRecords | Where-Object { $_.Path -ceq $expectedPath })
    if ($matchingRecords.Count -ne 1) {
        throw "Expected exactly one Git index entry at active issue-template path: $expectedPath"
    }
    if ($matchingRecords[0].Stage -cne '0' -or $matchingRecords[0].Mode -cne '100644') {
        throw "Active issue-template Git entry must be stage-0 mode 100644: $expectedPath"
    }
}
if ($missingReadmes.Count -ne 0) { throw "Missing README files: $($missingReadmes -join ', ')" }
if ($requiredReadmes.Count -ne 19) { throw "Expected the 19-README contract, found $($requiredReadmes.Count) paths." }
if ($missingIssueTemplateFiles.Count -ne 0) {
    throw "Missing active issue-template files: $($missingIssueTemplateFiles -join ', ')"
}
if ($unexpectedIssueTemplateEntries.Count -ne 0) {
    throw "Unexpected active issue-template entries: $($unexpectedIssueTemplateEntries.Name -join ', ')"
}
if ($issueTemplateEntries.Count -ne 3) { throw "Expected 3 active issue-template files, found $($issueTemplateEntries.Count)" }
if (Test-Path -LiteralPath 'docs/storyboard') { throw 'Excluded docs/storyboard exists.' }

foreach ($entry in $expectedIssueTemplateHashes.GetEnumerator()) {
    $actualHash = (Get-FileHash -LiteralPath $entry.Key -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -cne $entry.Value) { throw "Active issue-form hash mismatch: $($entry.Key)" }
}

$skillsRoot = (Resolve-Path '.github/skills').Path.TrimEnd('\')
$actualSkillNames = @(Get-ChildItem -LiteralPath $skillsRoot -Directory -Force | ForEach-Object Name)
if ($actualSkillNames.Count -ne 14) { throw "Expected 14 skill directories, found $($actualSkillNames.Count)." }
foreach ($skillName in $skillNames) {
    if ($actualSkillNames -cnotcontains $skillName) { throw "Missing exact skill directory: $skillName" }
}
foreach ($actualSkillName in $actualSkillNames) {
    if ($skillNames -cnotcontains $actualSkillName) { throw "Unexpected or case-variant skill directory: $actualSkillName" }
}

$runtimeFiles = @($skillNames | ForEach-Object {
    Get-ChildItem -LiteralPath (Join-Path $skillsRoot $_) -File -Recurse -Force
})
$runtimeRelativePaths = @($runtimeFiles | ForEach-Object {
    $_.FullName.Substring($skillsRoot.Length + 1).Replace('\', '/')
})
$manifestPath = '.github/skills/SUPERPOWERS_SHA256SUMS'
$manifestHash = (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($manifestHash -cne 'be8b1626ea290a4cc0a99ccf0e4878fcf8c5ca7d238094be3d23b59563d28f1c') {
    throw 'Pinned Superpowers manifest digest mismatch.'
}
$manifestLines = @(Get-Content -LiteralPath $manifestPath)
$manifestRelativePaths = @(for ($lineIndex = 0; $lineIndex -lt $manifestLines.Count; $lineIndex++) {
    $manifestMatch = [regex]::Match($manifestLines[$lineIndex], '^([0-9a-f]{64})  (.+)$')
    if (-not $manifestMatch.Success) { throw "Malformed manifest line $($lineIndex + 1)." }
    $manifestMatch.Groups[2].Value
})
if ($runtimeFiles.Count -ne 51 -or $manifestRelativePaths.Count -ne 51) {
    throw "Expected 51 runtime files and 51 manifest paths; found $($runtimeFiles.Count) and $($manifestRelativePaths.Count)."
}
foreach ($relativePath in $runtimeRelativePaths) {
    if ($manifestRelativePaths -cnotcontains $relativePath) { throw "Working runtime path is not pinned: $relativePath" }
}
foreach ($relativePath in $manifestRelativePaths) {
    if ($runtimeRelativePaths -cnotcontains $relativePath) { throw "Pinned runtime path is missing: $relativePath" }
}

$expectedVersionLines = @(
    'name=Superpowers',
    'source=https://github.com/obra/superpowers',
    'release=v6.3.0',
    'version=6.3.0',
    'tag-object=86babb696875227929e85420f287d6309374b93f',
    'commit=b36e0829c6d0140e93cfef2ca599b1b07d4a7797',
    'vendored=2026-09-15',
    'upstream-path=skills/',
    'destination=.github/skills/',
    'manifest=SUPERPOWERS_SHA256SUMS',
    'included-skills=brainstorming,dispatching-parallel-agents,executing-plans,finishing-a-development-branch,receiving-code-review,requesting-code-review,subagent-driven-development,systematic-debugging,test-driven-development,using-git-worktrees,using-superpowers,verification-before-completion,writing-plans,writing-skills'
)
$actualVersionLines = @(Get-Content -LiteralPath '.github/skills/SUPERPOWERS_VERSION')
if ($actualVersionLines.Count -ne $expectedVersionLines.Count) { throw 'SUPERPOWERS_VERSION line count mismatch.' }
for ($lineIndex = 0; $lineIndex -lt $expectedVersionLines.Count; $lineIndex++) {
    if ($actualVersionLines[$lineIndex] -cne $expectedVersionLines[$lineIndex]) {
        throw "SUPERPOWERS_VERSION mismatch at line $($lineIndex + 1)."
    }
}
$licenseHash = (Get-FileHash -LiteralPath '.github/skills/LICENSE.superpowers' -Algorithm SHA256).Hash.ToLowerInvariant()
if ($licenseHash -cne 'a37e0e9697144819e1d965176ac4ae5bc3fa02d11e7812036bbcadf6dafe2400') {
    throw 'Superpowers license hash mismatch.'
}

$allowedSkillRootGitPaths = @(
    '.github/skills/README.md',
    '.github/skills/LICENSE.superpowers',
    '.github/skills/SUPERPOWERS_SHA256SUMS',
    '.github/skills/SUPERPOWERS_VERSION'
)
$expectedRuntimeGitPaths = @($manifestRelativePaths | ForEach-Object { ".github/skills/$_" })
$expectedSkillGitPaths = @($allowedSkillRootGitPaths + $expectedRuntimeGitPaths)
$skillGitRecords = @($gitIndexRecords | Where-Object {
    $_.Path.StartsWith('.github/skills/', [StringComparison]::OrdinalIgnoreCase)
})
if ($skillGitRecords.Count -ne $expectedSkillGitPaths.Count) {
    throw "Expected $($expectedSkillGitPaths.Count) exact tracked paths under .github/skills, found $($skillGitRecords.Count)."
}
foreach ($record in $skillGitRecords) {
    if ($expectedSkillGitPaths -cnotcontains $record.Path) {
        throw "Rogue, case-variant, or extra tracked path under .github/skills: $($record.Path)"
    }
    if ($record.Stage -cne '0') { throw "Conflict stage is not allowed under .github/skills: $($record.Path)" }
}

function Get-ExactIndexRecord {
    param([string]$Path, [string]$Mode)

    $matchingRecords = @($gitIndexRecords | Where-Object { $_.Path -ceq $Path })
    if ($matchingRecords.Count -ne 1 -or $matchingRecords[0].Stage -cne '0' -or
        $matchingRecords[0].Mode -cne $Mode) {
        throw "Expected one exact-case stage-0 mode $Mode Git record: $Path"
    }
    $matchingRecords[0]
}

function Assert-IndexWorkingTreeOidMatch {
    param([object]$Record)

    $workingOidOutput = @(& $gitCommand.Source -C $repositoryRoot hash-object --no-filters -- $Record.Path 2>&1 |
        ForEach-Object { $_.ToString() })
    $hashObjectExitCode = $LASTEXITCODE
    if ($hashObjectExitCode -ne 0 -or $workingOidOutput.Count -ne 1 -or
        $workingOidOutput[0] -notmatch '^(?:[0-9a-fA-F]{40}|[0-9a-fA-F]{64})$') {
        throw "Cannot compute raw working-tree OID: $($Record.Path)"
    }
    if ($workingOidOutput[0].ToLowerInvariant() -cne $Record.ObjectId.ToLowerInvariant()) {
        throw "Raw index/working-tree OID mismatch: $($Record.Path)"
    }
}

$executableRuntimePaths = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach ($relativePath in @(
    'brainstorming/scripts/start-server.sh', 'brainstorming/scripts/stop-server.sh',
    'subagent-driven-development/scripts/review-package', 'subagent-driven-development/scripts/sdd-workspace',
    'subagent-driven-development/scripts/task-brief', 'systematic-debugging/find-polluter.sh',
    'writing-skills/render-graphs.js'
)) { [void]$executableRuntimePaths.Add($relativePath) }

$runtimeSnapshotRecords = @((Get-ExactIndexRecord $manifestPath '100644'))
$mode100644Count = 0
$mode100755Count = 0
foreach ($relativePath in $manifestRelativePaths) {
    $mode = if ($executableRuntimePaths.Contains($relativePath)) { '100755' } else { '100644' }
    $runtimeSnapshotRecords += Get-ExactIndexRecord ".github/skills/$relativePath" $mode
    if ($mode -ceq '100755') { $mode100755Count++ } else { $mode100644Count++ }
}
if ($mode100644Count -ne 44 -or $mode100755Count -ne 7) {
    throw "Expected runtime modes 44/7, found $mode100644Count/$mode100755Count."
}
$runtimeOidMatchCount = 0
foreach ($record in $runtimeSnapshotRecords) {
    Assert-IndexWorkingTreeOidMatch $record
    $runtimeOidMatchCount++
}
if ($runtimeOidMatchCount -ne 52) { throw "Expected 52/52 runtime OID matches, found $runtimeOidMatchCount/52." }

$protectedFormGitPaths = @('.gitattributes') + $expectedIssueTemplateGitPaths
$formOidMatchCount = 0
foreach ($path in $protectedFormGitPaths) {
    $record = Get-ExactIndexRecord $path '100644'
    Assert-IndexWorkingTreeOidMatch $record
    $formOidMatchCount++
}
if ($formOidMatchCount -ne 4) { throw "Expected 4/4 form/attribute OID matches, found $formOidMatchCount/4." }

Write-Output 'README and exact-form inventory validation passed (19 READMEs; 3 forms).'
Write-Output 'Superpowers snapshot validation passed (14 dirs; 51 runtime; 44 mode 100644; 7 mode 100755; 52/52 OID matches).'
Write-Output 'Issue-form snapshot validation passed (4/4 OID matches).'
```

Expected: no form diagnostics and the three exact success lines reporting 19 READMEs, three forms, 14 directories, 51 runtime files, the 44/7 mode split, `52/52` runtime/manifest OID matches, and `4/4` form/attribute OID matches. The Task 7 script independently checks the pinned manifest digest, full license hash, exact ordered version metadata, form hashes, the exact complete tracked root/runtime set beneath `.github/skills/`, conflict-stage rejection across that complete set, and raw OID coherence. The sole-green persistent repository validator separately rejects unexpected tracked root paths; requires unique exact-case stage-0 records with expected modes for the manifest/runtime index snapshot, rejecting conflict stages for those paths; validates working version metadata and license content; and provides hidden-entry and reparse defenses. Task 7 supplies the additional requirement that every permitted auxiliary root path has an exact stage-0 tracked record, catching missing or conflict-stage auxiliary records.

- [ ] **Step 3: Smoke-test VS Code discovery**

In VS Code:

1. Open this feature worktree/repository checkout as the workspace root. Testing the parent primary checkout before integration is invalid because it does not contain this branch's repository customizations.
2. Run **Chat: Open Customizations**.
3. Open the **Skills** tab.
4. Confirm exactly the 14 names in the **Shipped Integrity Contract** appear as repository skills, with no extra project skill and no metadata diagnostics.
5. Manually confirm repository provenance for the entries and confirm `using-superpowers` shows `.github/skills/using-superpowers/SKILL.md` as its source/path in this checkout.
6. Start a new chat in the repository and enter `Use using-superpowers and tell me which process applies before changing code.`

Expected: Copilot identifies and follows the repository-owned `using-superpowers` skill without asking for a global install.

- [ ] **Step 4: Smoke-test Copilot CLI discovery**

From the repository root, inspect project-skill provenance:

```powershell
copilot --no-auto-update -C . skill list --json
```

Expected: the JSON contains exactly the 14 names in the **Shipped Integrity Contract** with `source` equal to `project`, `enabled` equal to `true`, and paths ending in this repository's corresponding `.github/skills/<name>` directories with either supported path separator. There are no missing or extra project skills.

Start Copilot CLI from the repository root:

```powershell
copilot --no-auto-update -C .
```

Optionally, enter `/skills info using-superpowers` to confirm the repository project skill location. Then enter this natural-language prompt:

```text
Use the /using-superpowers skill to identify which process applies before changing code.
```

Standalone `/using-superpowers` is supported, but the prompt form is recommended because it provides a verifiable response.

Expected: Copilot CLI chooses and loads the repository project skill from the prompt and does not ask for a global or machine-level installation.

- [ ] **Step 5: Confirm final Git state**

```powershell
git status --short
$baseCommit = git merge-base HEAD main
git log --oneline "$baseCommit..HEAD"
```

Expected: the working tree is clean and the branch history contains the design, implementation plan, documentation, runtime, bootstrap, and active issue-form changes. The validation does not require a fixed number of commits.
