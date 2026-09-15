# Repository Superpowers Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bundle Superpowers v6.3.0 and the approved repository folder structure so GitHub Copilot in VS Code and Copilot CLI use the same workflows from a normal clone.

**Architecture:** GitHub Copilot discovers unchanged upstream skills from `.github/skills/`. Repository-owned bootstrap instructions activate the Superpowers selection workflow, while version metadata, an upstream license copy, folder READMEs, and a PowerShell verifier make the bundle reviewable and maintainable.

**Tech Stack:** GitHub Copilot Agent Skills, Markdown, PowerShell 5.1+, Git

---

### Task 1: Add the Repository Setup Verifier

**Files:**
- Create: `.github/cli/verify-repository-setup.ps1`

- [ ] **Step 1: Write the failing validation script**

Create `.github/cli/verify-repository-setup.ps1` with this content:

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
    '.github/agent-policy',
    '.github/agents',
    '.github/cli',
    '.github/instructions',
    '.github/issue-templates',
    '.github/skills',
    '.github/workflows',
    'docs/adr',
    'docs/archive',
    'docs/brandkit',
    'docs/business',
    'docs/delegation',
    'docs/ideas',
    'docs/issues',
    'docs/plans',
    'docs/reviews',
    'docs/specs',
    'docs/sprints',
    'docs/templates'
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

$skillsRoot = Join-Path $repositoryRoot '.github/skills'
if (Test-Path -LiteralPath $skillsRoot -PathType Container) {
    $skillDirectories = Get-ChildItem -LiteralPath $skillsRoot -Directory
    foreach ($skillDirectory in $skillDirectories) {
        $skillFile = Join-Path $skillDirectory.FullName 'SKILL.md'
        if (-not (Test-Path -LiteralPath $skillFile -PathType Leaf)) {
            Add-ValidationFailure "Missing SKILL.md: .github/skills/$($skillDirectory.Name)"
            continue
        }

        $skillContent = Get-Content -LiteralPath $skillFile -Raw
        $nameMatch = [regex]::Match($skillContent, '(?m)^name:\s*["'']?([a-z0-9-]+)["'']?\s*$')
        if (-not $nameMatch.Success) {
            Add-ValidationFailure "Missing or invalid skill name: .github/skills/$($skillDirectory.Name)/SKILL.md"
        }
        elseif ($nameMatch.Groups[1].Value -ne $skillDirectory.Name) {
            Add-ValidationFailure "Skill name does not match directory: $($skillDirectory.Name)"
        }

        foreach ($linkMatch in [regex]::Matches($skillContent, '\[[^\]]+\]\(([^)]+)\)')) {
            $target = $linkMatch.Groups[1].Value.Trim().Trim('<', '>')
            if ($target -match '^(?:https?://|mailto:|#)') {
                continue
            }

            $targetPath = ($target -split '#', 2)[0]
            if ([string]::IsNullOrWhiteSpace($targetPath)) {
                continue
            }

            $resolvedTarget = Join-Path $skillDirectory.FullName ([Uri]::UnescapeDataString($targetPath))
            if (-not (Test-Path -LiteralPath $resolvedTarget)) {
                Add-ValidationFailure "Broken skill link in $($skillDirectory.Name)/SKILL.md: $target"
            }
        }
    }
}

$usingSuperpowers = Join-Path $skillsRoot 'using-superpowers/SKILL.md'
if (-not (Test-Path -LiteralPath $usingSuperpowers -PathType Leaf)) {
    Add-ValidationFailure 'The using-superpowers entry skill is missing.'
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
    foreach ($requiredValue in @(
        'https://github.com/obra/superpowers',
        'v6.3.0',
        'b36e0829c6d0140e93cfef2ca599b1b07d4a7797'
    )) {
        if ($versionContent -notmatch [regex]::Escape($requiredValue)) {
            Add-ValidationFailure "Version metadata is missing: $requiredValue"
        }
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
        Write-Error $failure -ErrorAction Continue
    }
    exit 1
}

Write-Output 'Repository setup validation passed.'
```

- [ ] **Step 2: Run the verifier to prove the repository is not configured yet**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .github/cli/verify-repository-setup.ps1
```

Expected: exit code `1` with missing directory, bootstrap, skill, version, and license failures.

- [ ] **Step 3: Commit the validation baseline**

```powershell
git add -- .github/cli/verify-repository-setup.ps1
git commit -m "test: add repository setup verifier" -- .github/cli/verify-repository-setup.ps1
```

### Task 2: Establish the GitHub Collaboration Folders

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

### Task 3: Establish the Documentation Folders

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

### Task 4: Vendor Superpowers v6.3.0

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
- Create: `.github/skills/SUPERPOWERS_VERSION`

- [ ] **Step 1: Fetch and copy only the pinned runtime payload**

Run this PowerShell block from the repository root:

```powershell
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) "superpowers-v6.3.0-$([guid]::NewGuid())"
try {
    git clone --quiet --depth 1 --branch v6.3.0 https://github.com/obra/superpowers.git $tempRoot
    if ($LASTEXITCODE -ne 0) { throw 'Unable to clone Superpowers v6.3.0.' }

    $resolvedCommit = git -C $tempRoot rev-parse HEAD
    if ($resolvedCommit -ne 'b36e0829c6d0140e93cfef2ca599b1b07d4a7797') {
        throw "Unexpected Superpowers commit: $resolvedCommit"
    }
    Copy-Item -LiteralPath (Join-Path $tempRoot 'skills\brainstorming') -Destination '.github\skills' -Recurse
    Copy-Item -LiteralPath (Join-Path $tempRoot 'skills\dispatching-parallel-agents') -Destination '.github\skills' -Recurse
    Copy-Item -LiteralPath (Join-Path $tempRoot 'skills\executing-plans') -Destination '.github\skills' -Recurse
    Copy-Item -LiteralPath (Join-Path $tempRoot 'skills\finishing-a-development-branch') -Destination '.github\skills' -Recurse
    Copy-Item -LiteralPath (Join-Path $tempRoot 'skills\receiving-code-review') -Destination '.github\skills' -Recurse
    Copy-Item -LiteralPath (Join-Path $tempRoot 'skills\requesting-code-review') -Destination '.github\skills' -Recurse
    Copy-Item -LiteralPath (Join-Path $tempRoot 'skills\subagent-driven-development') -Destination '.github\skills' -Recurse
    Copy-Item -LiteralPath (Join-Path $tempRoot 'skills\systematic-debugging') -Destination '.github\skills' -Recurse
    Copy-Item -LiteralPath (Join-Path $tempRoot 'skills\test-driven-development') -Destination '.github\skills' -Recurse
    Copy-Item -LiteralPath (Join-Path $tempRoot 'skills\using-git-worktrees') -Destination '.github\skills' -Recurse
    Copy-Item -LiteralPath (Join-Path $tempRoot 'skills\using-superpowers') -Destination '.github\skills' -Recurse
    Copy-Item -LiteralPath (Join-Path $tempRoot 'skills\verification-before-completion') -Destination '.github\skills' -Recurse
    Copy-Item -LiteralPath (Join-Path $tempRoot 'skills\writing-plans') -Destination '.github\skills' -Recurse
    Copy-Item -LiteralPath (Join-Path $tempRoot 'skills\writing-skills') -Destination '.github\skills' -Recurse
    Copy-Item -LiteralPath (Join-Path $tempRoot 'LICENSE') -Destination '.github\skills\LICENSE.superpowers'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
```

Expected: `.github/skills/` contains the 14 listed upstream skill directories and no plugin manifests, hooks, upstream tests, or upstream documentation tree.

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
try {
    git clone --quiet --depth 1 --branch v6.3.0 https://github.com/obra/superpowers.git $tempRoot
    if ($LASTEXITCODE -ne 0) { throw 'Unable to clone Superpowers v6.3.0.' }

    foreach ($skillName in $skillNames) {
        $difference = @(git diff --no-index -- (Join-Path $tempRoot "skills\$skillName") ".github\skills\$skillName" 2>&1)
        if ($LASTEXITCODE -gt 1) {
            throw "Unable to compare vendored skill: $skillName"
        }
        if ($LASTEXITCODE -eq 1) {
            $runtimeDifferences.AddRange([string[]]$difference)
        }
    }
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
if ($runtimeDifferences) {
    $runtimeDifferences
    throw 'Vendored runtime differs from Superpowers v6.3.0.'
}
```

Expected: no runtime differences for any of the 14 named skill directories. Repository-owned files at the `.github/skills/` root are outside the comparison.

- [ ] **Step 4: Run repository validation**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .github/cli/verify-repository-setup.ps1
```

Expected: exit code `1`; skill, version, license, directory, and README checks pass. Only bootstrap and root README content failures remain.

- [ ] **Step 5: Commit the pinned runtime**

```powershell
git add -- .github/skills
git commit -m "build: vendor Superpowers v6.3.0" -- .github/skills
```

### Task 5: Bootstrap Copilot and Document Contributor Use

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

```markdown
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

The command succeeds with `Repository setup validation passed.` when the folder structure, skill metadata, local skill links, bootstrap instructions, version metadata, and license are valid.

In VS Code, open **Chat: Open Agent Customizations** and confirm the workspace skills appear without metadata errors. In Copilot CLI, start `copilot` from the repository root and invoke or ask it to use `using-superpowers`.

### Pinned Version and License

The vendored runtime is pinned to upstream release v6.3.0 at commit `b36e0829c6d0140e93cfef2ca599b1b07d4a7797`.

- Source metadata: [`.github/skills/SUPERPOWERS_VERSION`](.github/skills/SUPERPOWERS_VERSION)
- Upstream MIT license: [`.github/skills/LICENSE.superpowers`](.github/skills/LICENSE.superpowers)

### Updating Superpowers

Updates are deliberate and reviewed. To update:

1. Review the newer upstream release and release notes.
2. Replace only the 14 vendored skill directories with the newer release's `skills/` content.
3. Refresh `LICENSE.superpowers` if the upstream license changed.
4. Update `SUPERPOWERS_VERSION` with the release, tag object, commit, date, and included skill list.
5. Run the repository verifier and smoke-test discovery in VS Code and Copilot CLI.
6. Commit the runtime replacement, metadata, and any required bootstrap compatibility changes together.

Do not track upstream `main`, use a submodule, or edit vendored skill files for repository-specific behavior.
```

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

### Task 6: Perform Final Repository and Host Validation

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
$skillCount = @(Get-ChildItem -LiteralPath '.github/skills' -Directory | Where-Object {
    Test-Path -LiteralPath (Join-Path $_.FullName 'SKILL.md')
}).Count
if ($missingReadmes.Count -ne 0) { throw "Missing README files: $($missingReadmes -join ', ')" }
if ($skillCount -ne 14) { throw "Expected 14 skills, found $skillCount" }
if (Test-Path -LiteralPath '.github/ISSUE_TEMPLATE') { throw 'Excluded .github/ISSUE_TEMPLATE exists.' }
if (Test-Path -LiteralPath 'docs/storyboard') { throw 'Excluded docs/storyboard exists.' }
Write-Output 'Folder and skill count validation passed.'
```

Expected: `Folder and skill count validation passed.`

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