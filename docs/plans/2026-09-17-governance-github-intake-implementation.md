# Governance and GitHub Intake Implementation Plan

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-17 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Draft |
| **Scope** | Cross-cutting (all solution domains) |
| **References** | [Architecture Baseline Intake and Tenant Bootstrap Design](../specs/2026-09-17-architecture-baseline-intake-design.md) |

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish deterministic source intake, the English documentation metadata contract and docs-agent, reviewed GitHub governance artifacts, a third active issue form, and a required repository validation workflow without changing the protected Superpowers runtime.

**Architecture:** Two focused PowerShell modules own source inventory and documentation metadata. Repository-owned governance artifacts are semantically merged from the assessed source package, while all protected target files win collisions. Pester fixtures and the existing repository validator enforce the source inventory, metadata eligibility, issue-form bytes, agent contract, links, and workflow contract before any later content phase begins.

**Tech Stack:** Windows PowerShell 5.1, Pester 5.7.1, JSON Schema Draft 2020-12, GitHub Actions, YAML issue forms, Git

---

## Preconditions

- Work from `sprint/architecture-baseline-intake` in `.wt/architecture-baseline-intake`.
- Confirm `git rev-parse HEAD` descends from approved specification commit `affffeb485e5fcf0c6a9d1c3964d59b1eb6632ac`.
- Treat `C:\Users\urruegg\Downloads\caldova-hr-frontier` as read-only source input.
- Do not edit `.github/skills/{vendored-skill}/**`, `.github/skills/SUPERPOWERS_SHA256SUMS`, `.github/skills/SUPERPOWERS_VERSION`, `.github/skills/LICENSE.superpowers`, or `LICENSE`.
- Do not activate a GitHub ruleset in this phase. The final infrastructure plan owns that mutation after Tenant 1 `what-if` succeeds.

### Task 1: Pin the Assessed Source Inventory

**Files:**
- Create: `.github/cli/schemas/source-inventory.schema.json`
- Create: `.github/cli/modules/SourceInventory.psm1`
- Create: `.github/cli/New-ArchitectureSourceInventory.ps1`
- Create: `.github/cli/tests/SourceInventory.Tests.ps1`
- Create: `docs/reviews/2026-09-17-architecture-baseline-source-inventory.json`

- [ ] **Step 1: Write the failing source-inventory tests**

Create `.github/cli/tests/SourceInventory.Tests.ps1`:

```powershell
$modulePath = Join-Path $PSScriptRoot '..\modules\SourceInventory.psm1'
Import-Module $modulePath -Force

Describe 'Get-ArchitectureSourceInventory' {
    BeforeEach {
        $source = Join-Path $TestDrive 'source'
        New-Item -ItemType Directory -Path (Join-Path $source 'nested') -Force | Out-Null
        [IO.File]::WriteAllText((Join-Path $source 'b.txt'), 'beta', [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllText((Join-Path $source 'nested\a.txt'), 'alpha', [Text.UTF8Encoding]::new($false))
    }

    It 'returns ordinally sorted relative paths, byte counts, and lowercase SHA-256 values' {
        $result = Get-ArchitectureSourceInventory -SourceRoot $source -GeneratedUtc '2026-09-17T12:00:00Z'

        $result.schemaVersion | Should -Be '1.0'
        $result.generatedUtc | Should -Be '2026-09-17T12:00:00Z'
        $result.files.relativePath | Should -Be @('b.txt', 'nested/a.txt')
        $result.files[0].bytes | Should -Be 4
        $result.files[1].bytes | Should -Be 5
        $result.files[0].sha256 | Should -Match '^[0-9a-f]{64}$'
        $result.totalCount | Should -Be 2
        $result.totalBytes | Should -Be 9
    }

    It 'rejects nested Git metadata' {
        New-Item -ItemType Directory -Path (Join-Path $source '.git') | Out-Null

        { Get-ArchitectureSourceInventory -SourceRoot $source -GeneratedUtc '2026-09-17T12:00:00Z' } |
            Should -Throw '*Nested Git metadata*'
    }
}
```

- [ ] **Step 2: Run the tests to verify RED**

Run:

```powershell
Invoke-Pester .github/cli/tests/SourceInventory.Tests.ps1 -Output Detailed
```

Expected: FAIL because `SourceInventory.psm1` does not exist.

- [ ] **Step 3: Add the inventory schema**

Create `.github/cli/schemas/source-inventory.schema.json`:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://github.com/urruegg/caldova-hr-frontier/schemas/source-inventory.schema.json",
  "title": "Architecture source inventory",
  "type": "object",
  "additionalProperties": false,
  "required": ["schemaVersion", "generatedUtc", "sourceName", "totalCount", "totalBytes", "files"],
  "properties": {
    "schemaVersion": { "const": "1.0" },
    "generatedUtc": { "type": "string", "format": "date-time" },
    "sourceName": { "type": "string", "minLength": 1 },
    "totalCount": { "type": "integer", "minimum": 0 },
    "totalBytes": { "type": "integer", "minimum": 0 },
    "files": {
      "type": "array",
      "items": {
        "type": "object",
        "additionalProperties": false,
        "required": ["relativePath", "bytes", "sha256"],
        "properties": {
          "relativePath": { "type": "string", "pattern": "^(?!/)(?!.*(?:^|/)\\.\\.(?:/|$))[^\\\\]+$" },
          "bytes": { "type": "integer", "minimum": 0 },
          "sha256": { "type": "string", "pattern": "^[0-9a-f]{64}$" }
        }
      }
    }
  }
}
```

- [ ] **Step 4: Implement deterministic inventory generation**

Create `.github/cli/modules/SourceInventory.psm1`:

```powershell
Set-StrictMode -Version Latest

function Get-ArchitectureSourceInventory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SourceRoot,
        [Parameter(Mandatory)][string]$GeneratedUtc
    )

    $resolvedRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
    $rootItem = Get-Item -LiteralPath $resolvedRoot -Force
    if ($rootItem.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        throw "Source root must not be a reparse point: $resolvedRoot"
    }
    if (Test-Path -LiteralPath (Join-Path $resolvedRoot '.git')) {
        throw 'Nested Git metadata is not allowed in the architecture source.'
    }

    $recordsByPath = [Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
    foreach ($item in @(Get-ChildItem -LiteralPath $resolvedRoot -File -Recurse -Force)) {
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            throw "Reparse point is not allowed: $($item.FullName)"
        }
        $relativePath = $item.FullName.Substring($resolvedRoot.Length).TrimStart('\').Replace('\', '/')
        $recordsByPath.Add($relativePath, [ordered]@{
            relativePath = $relativePath
            bytes = [long]$item.Length
            sha256 = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        })
    }

    [string[]]$sortedPaths = @($recordsByPath.Keys)
    [Array]::Sort($sortedPaths, [StringComparer]::Ordinal)
    $sorted = @($sortedPaths | ForEach-Object { $recordsByPath[$_] })
    [ordered]@{
        schemaVersion = '1.0'
        generatedUtc = $GeneratedUtc
        sourceName = Split-Path -Leaf $resolvedRoot
        totalCount = $sorted.Count
        totalBytes = [long](($sorted | Measure-Object -Property bytes -Sum).Sum)
        files = $sorted
    }
}

Export-ModuleMember -Function Get-ArchitectureSourceInventory
```

Create `.github/cli/New-ArchitectureSourceInventory.ps1`:

```powershell
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SourceRoot,
    [Parameter(Mandatory)][string]$OutputPath,
    [string]$GeneratedUtc = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'modules\SourceInventory.psm1') -Force
$inventory = Get-ArchitectureSourceInventory -SourceRoot $SourceRoot -GeneratedUtc $GeneratedUtc
$json = $inventory | ConvertTo-Json -Depth 6
$absoluteOutput = [IO.Path]::GetFullPath((Join-Path (Get-Location) $OutputPath))
$parent = Split-Path -Parent $absoluteOutput
if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
[IO.File]::WriteAllText($absoluteOutput, $json + "`n", [Text.UTF8Encoding]::new($false))
Write-Output "Wrote source inventory: $OutputPath"
```

- [ ] **Step 5: Run the inventory tests to verify GREEN**

Run:

```powershell
Invoke-Pester .github/cli/tests/SourceInventory.Tests.ps1 -Output Detailed
```

Expected: 2 tests passed, 0 failed.

- [ ] **Step 6: Generate and verify the assessed inventory**

Run:

```powershell
./.github/cli/New-ArchitectureSourceInventory.ps1 `
  -SourceRoot 'C:\Users\urruegg\Downloads\caldova-hr-frontier' `
  -OutputPath 'docs/reviews/2026-09-17-architecture-baseline-source-inventory.json' `
  -GeneratedUtc '2026-09-17T00:00:00Z'

$inventory = Get-Content docs/reviews/2026-09-17-architecture-baseline-source-inventory.json -Raw | ConvertFrom-Json
if ($inventory.totalCount -ne 45) { throw "Expected 45 source files, found $($inventory.totalCount)." }
if ($inventory.totalBytes -ne 485126) { throw "Expected 485126 source bytes, found $($inventory.totalBytes)." }
$readme = $inventory.files | Where-Object relativePath -ceq 'README.md'
if ($readme.sha256 -cne '5035ac2b1c59ce776de359ac9592483bf0b9e20572dd1bee8a5aae2638ab8605') {
    throw 'Source README hash does not match the approved assessment.'
}
Write-Output 'Architecture source inventory matches the approved assessment.'
```

Expected: `Architecture source inventory matches the approved assessment.`

- [ ] **Step 7: Commit the inventory foundation**

```powershell
git add -- .github/cli/schemas/source-inventory.schema.json .github/cli/modules/SourceInventory.psm1 .github/cli/New-ArchitectureSourceInventory.ps1 .github/cli/tests/SourceInventory.Tests.ps1 docs/reviews/2026-09-17-architecture-baseline-source-inventory.json
git commit -m "feat: add deterministic architecture source inventory" -- .github/cli/schemas/source-inventory.schema.json .github/cli/modules/SourceInventory.psm1 .github/cli/New-ArchitectureSourceInventory.ps1 .github/cli/tests/SourceInventory.Tests.ps1 docs/reviews/2026-09-17-architecture-baseline-source-inventory.json
```

### Task 2: Implement the Documentation Metadata Contract

**Files:**
- Create: `.github/cli/modules/DocumentationMetadata.psm1`
- Create: `.github/cli/Set-DocumentationMetadata.ps1`
- Create: `.github/cli/tests/DocumentationMetadata.Tests.ps1`

- [ ] **Step 1: Write failing metadata eligibility and structure tests**

Create `.github/cli/tests/DocumentationMetadata.Tests.ps1`:

```powershell
$modulePath = Join-Path $PSScriptRoot '..\modules\DocumentationMetadata.psm1'
Import-Module $modulePath -Force

Describe 'Documentation metadata contract' {
    It 'includes repository-owned Markdown and excludes vendored and immutable text' {
        Test-DocumentationMetadataEligibility 'README.md' | Should -BeTrue
        Test-DocumentationMetadataEligibility '.github/agents/docs-agent.agent.md' | Should -BeTrue
        Test-DocumentationMetadataEligibility '.github/skills/README.md' | Should -BeTrue
        Test-DocumentationMetadataEligibility '.github/skills/brainstorming/SKILL.md' | Should -BeFalse
        Test-DocumentationMetadataEligibility '.github/skills/LICENSE.superpowers' | Should -BeFalse
        Test-DocumentationMetadataEligibility 'LICENSE' | Should -BeFalse
        Test-DocumentationMetadataEligibility 'infra/evidence/discovery/example.json' | Should -BeFalse
    }

    It 'accepts the exact six-field table after the first H1' {
        $content = @'
# Example

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-17 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Active (consolidated from current state) |
| **Scope** | Repository |
| **References** | None |

Body.
'@
        (Test-DocumentationMetadataContent -Content $content).Count | Should -Be 0
    }

    It 'rejects a missing field and body content before the table' {
        $content = "# Example`n`nBody first.`n"
        $failures = Test-DocumentationMetadataContent -Content $content
        $failures | Should -Contain 'Standard metadata table must immediately follow the first H1.'
    }
}
```

- [ ] **Step 2: Run the tests to verify RED**

Run:

```powershell
Invoke-Pester .github/cli/tests/DocumentationMetadata.Tests.ps1 -Output Detailed
```

Expected: FAIL because `DocumentationMetadata.psm1` does not exist.

- [ ] **Step 3: Implement eligibility and table validation**

Create `.github/cli/modules/DocumentationMetadata.psm1`:

```powershell
Set-StrictMode -Version Latest

$script:MetadataLabels = @('Version', 'Date', 'Author', 'Status', 'Scope', 'References')
$script:AllowedStatusPrefixes = @('Draft', 'Proposed Baseline', 'Active', 'Approved', 'Superseded', 'Archived')

function Test-DocumentationMetadataEligibility {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$RelativePath)

    $path = $RelativePath.Replace('\', '/').TrimStart('/')
    if ($path -ceq 'LICENSE' -or $path -ceq '.github/skills/LICENSE.superpowers') { return $false }
    if ($path.StartsWith('infra/evidence/', [StringComparison]::Ordinal)) { return $false }
    if ($path.StartsWith('.github/skills/', [StringComparison]::Ordinal) -and $path -cne '.github/skills/README.md') {
        return $false
    }
    return $path.EndsWith('.md', [StringComparison]::OrdinalIgnoreCase)
}

function Test-DocumentationMetadataContent {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Content)

    $failures = [Collections.Generic.List[string]]::new()
    $lines = @($Content -split "`r?`n")
    $frontmatterEnd = -1
    if ($lines.Count -gt 0 -and $lines[0] -ceq '---') {
        for ($index = 1; $index -lt $lines.Count; $index++) {
            if ($lines[$index] -ceq '---') { $frontmatterEnd = $index; break }
        }
        if ($frontmatterEnd -lt 0) { $failures.Add('YAML frontmatter is not closed.'); return $failures }
    }
    $searchStart = if ($frontmatterEnd -ge 0) { $frontmatterEnd + 1 } else { 0 }
    $h1 = -1
    for ($index = $searchStart; $index -lt $lines.Count; $index++) {
        if ($lines[$index] -match '^# [^#]') { $h1 = $index; break }
    }
    if ($h1 -lt 0) { $failures.Add('Document must contain one level-one heading.'); return $failures }

    $table = $h1 + 1
    while ($table -lt $lines.Count -and [string]::IsNullOrWhiteSpace($lines[$table])) { $table++ }
    if ($table + 7 -ge $lines.Count -or $lines[$table] -cne '| Field | Value |' -or $lines[$table + 1] -cne '|---|---|') {
        $failures.Add('Standard metadata table must immediately follow the first H1.')
        return $failures
    }
    for ($offset = 0; $offset -lt $script:MetadataLabels.Count; $offset++) {
        $label = $script:MetadataLabels[$offset]
        $match = [regex]::Match($lines[$table + 2 + $offset], '^\| \*\*(.+)\*\* \| (.+) \|$')
        if (-not $match.Success -or $match.Groups[1].Value -cne $label -or [string]::IsNullOrWhiteSpace($match.Groups[2].Value)) {
            $failures.Add("Invalid or missing metadata field: $label")
        }
    }
    $version = [regex]::Match($lines[$table + 2], '\| \*\*Version\*\* \| (.+) \|$').Groups[1].Value
    $date = [regex]::Match($lines[$table + 3], '\| \*\*Date\*\* \| (.+) \|$').Groups[1].Value
    $status = [regex]::Match($lines[$table + 5], '\| \*\*Status\*\* \| (.+) \|$').Groups[1].Value
    if ($version -notmatch '^\d+\.\d+$') { $failures.Add('Version must use major.minor syntax.') }
    if ($date -notmatch '^\d{4}-\d{2}-\d{2}$') { $failures.Add('Date must use ISO 8601 calendar syntax.') }
    if (-not @($script:AllowedStatusPrefixes | Where-Object { $status.StartsWith($_, [StringComparison]::Ordinal) })) {
        $failures.Add('Status does not use an allowed prefix.')
    }
    return $failures
}

function New-DocumentationMetadataTable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Version,
        [Parameter(Mandatory)][string]$Date,
        [Parameter(Mandatory)][string]$Author,
        [Parameter(Mandatory)][string]$Status,
        [Parameter(Mandatory)][string]$Scope,
        [Parameter(Mandatory)][string]$References
    )
    @(
        '| Field | Value |', '|---|---|',
        "| **Version** | $Version |", "| **Date** | $Date |", "| **Author** | $Author |",
        "| **Status** | $Status |", "| **Scope** | $Scope |", "| **References** | $References |"
    ) -join "`n"
}

Export-ModuleMember -Function Test-DocumentationMetadataEligibility, Test-DocumentationMetadataContent, New-DocumentationMetadataTable
```

- [ ] **Step 4: Add the narrowly scoped migration script**

Create `.github/cli/Set-DocumentationMetadata.ps1`:

```powershell
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][string]$Version,
    [Parameter(Mandatory)][string]$Date,
    [Parameter(Mandatory)][string]$Author,
    [Parameter(Mandatory)][string]$Status,
    [Parameter(Mandatory)][string]$Scope,
    [Parameter(Mandatory)][string]$References
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'modules\DocumentationMetadata.psm1') -Force
$relativePath = $Path.Replace('\', '/')
if (-not (Test-DocumentationMetadataEligibility -RelativePath $relativePath)) {
    throw "Path is excluded from documentation metadata: $relativePath"
}
$content = Get-Content -LiteralPath $Path -Raw
if ((Test-DocumentationMetadataContent -Content $content).Count -eq 0) {
    Write-Output "Metadata already valid: $relativePath"
    return
}
$lines = [Collections.Generic.List[string]]@($content -split "`r?`n")
$h1 = -1
for ($index = 0; $index -lt $lines.Count; $index++) {
    if ($lines[$index] -match '^# [^#]') { $h1 = $index; break }
}
if ($h1 -lt 0) { throw "Cannot add metadata without an H1: $relativePath" }
$table = New-DocumentationMetadataTable -Version $Version -Date $Date -Author $Author `
    -Status $Status -Scope $Scope -References $References
$newLines = [Collections.Generic.List[string]]::new()
for ($index = 0; $index -le $h1; $index++) { $newLines.Add($lines[$index]) }
$newLines.Add('')
foreach ($line in @($table -split "`n")) { $newLines.Add($line) }
$newLines.Add('')
for ($index = $h1 + 1; $index -lt $lines.Count; $index++) {
    if ($index -eq $h1 + 1 -and [string]::IsNullOrWhiteSpace($lines[$index])) { continue }
    $newLines.Add($lines[$index])
}
if ($PSCmdlet.ShouldProcess($relativePath, 'Add standard documentation metadata')) {
    [IO.File]::WriteAllText((Resolve-Path -LiteralPath $Path).Path, (($newLines -join "`n").TrimEnd() + "`n"), [Text.UTF8Encoding]::new($false))
}
```

- [ ] **Step 5: Run the metadata tests to verify GREEN**

Run:

```powershell
Invoke-Pester .github/cli/tests/DocumentationMetadata.Tests.ps1 -Output Detailed
```

Expected: 3 tests passed, 0 failed.

- [ ] **Step 6: Commit the metadata tooling**

```powershell
git add -- .github/cli/modules/DocumentationMetadata.psm1 .github/cli/Set-DocumentationMetadata.ps1 .github/cli/tests/DocumentationMetadata.Tests.ps1
git commit -m "feat: define documentation metadata contract" -- .github/cli/modules/DocumentationMetadata.psm1 .github/cli/Set-DocumentationMetadata.ps1 .github/cli/tests/DocumentationMetadata.Tests.ps1
```

### Task 3: Add the Documentation Agent and Policy Anchors

**Files:**
- Create: `.github/agents/docs-agent.agent.md`
- Create: `docs/README.md`
- Create: `.github/cli/tests/DocsAgentContract.Tests.ps1`
- Modify: `AGENTS.md`
- Modify: `.github/copilot-instructions.md`
- Modify: `.github/agents/README.md`

- [ ] **Step 1: Write the failing docs-agent contract test**

Create `.github/cli/tests/DocsAgentContract.Tests.ps1`:

```powershell
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))

Describe 'Documentation agent contract' {
    It 'exists with the focused tool boundary and English metadata ownership' {
        $path = Join-Path $repositoryRoot '.github\agents\docs-agent.agent.md'
        $path | Should -Exist
        $content = Get-Content -LiteralPath $path -Raw
        $content | Should -Match '(?m)^name: docs-agent$'
        $content | Should -Match '(?m)^tools: \[read, search, edit, todo\]$'
        $content | Should -Match 'standard metadata header'
        $content | Should -Match 'written in English'
        $content | Should -Not -Match '(?m)^tools:.*execute'
    }

    It 'is directly anchored from both repository instruction files' {
        foreach ($relativePath in @('AGENTS.md', '.github/copilot-instructions.md')) {
            $content = Get-Content -LiteralPath (Join-Path $repositoryRoot $relativePath) -Raw
            $content | Should -Match '\.github/agents/docs-agent\.agent\.md'
        }
    }
}
```

- [ ] **Step 2: Run the test to verify RED**

Run:

```powershell
Invoke-Pester .github/cli/tests/DocsAgentContract.Tests.ps1 -Output Detailed
```

Expected: FAIL because `docs-agent.agent.md` and its anchors do not exist.

- [ ] **Step 3: Create the adapted docs-agent**

Create `.github/agents/docs-agent.agent.md` with this exact frontmatter and policy body:

```markdown
---
name: docs-agent
description: "Voice of Knowledge. Use when creating, consolidating, reviewing, relocating, cataloguing, or standardizing repository documentation, metadata headers, references, status, scope, and English-language knowledge across solution domains."
tools: [read, search, edit, todo]
user-invocable: true
---

# Docs Agent (Voice of Knowledge)

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-17 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Active |
| **Scope** | Cross-cutting (all solution domains) |
| **References** | [Documentation Policy](../../docs/README.md) |

## Mission

Keep repository-owned documentation current, concise, traceable, correctly placed, cross-linked, usable by people and agents, and written in English.

## Workflow

1. Apply the repository Superpowers workflow and use brainstorming before restructuring documentation.
2. Identify the authoritative behavior, contract, decision, or explicitly marked Proposed Baseline.
3. Confirm the owning domain and intended audience.
4. Add or validate the standard six-field metadata header.
5. Update relative references and the documentation map when inventory or placement changes.
6. Validate links, UTF-8 text, metadata, status, and scope before handing off.

## Boundaries

- Edit repository-owned Markdown and documentation catalogues only.
- Do not edit vendored Superpowers, licenses, generated evidence, source code, workflows, infrastructure, or deployment state.
- Do not invent approval, backdate metadata, or promote Proposed Baseline content without reviewed evidence.
- Use Git history as the change log; do not add in-document change logs.

## Required Header

Every eligible repository-owned Markdown artifact has `Version`, `Date`, `Author`, `Status`, `Scope`, and `References` immediately after its first H1. Exclusions are defined in the documentation policy and validator.

## Review Checklist

1. Is the document written in English and free from encoding corruption?
2. Is its current status explicit and supported?
3. Does the header use the exact field names and valid values?
4. Is the artifact in the correct solution domain?
5. Are relative references valid and sufficient for traceability?
6. Is the content current and lean, with obsolete material archived rather than narrated?
```

- [ ] **Step 4: Create the authoritative documentation policy**

Create `docs/README.md` with the standard header and these required sections:

```markdown
# Documentation

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-17 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Active |
| **Scope** | Cross-cutting (all solution domains) |
| **References** | [Docs Agent](../.github/agents/docs-agent.agent.md) |

## Policy

All maintained repository documentation is written in English, stored as UTF-8, aligned with delivered behavior or explicitly marked Proposed Baseline, and owned by a named solution domain.

Every repository-owned Markdown artifact contains the standard six-field metadata table immediately after its first H1. Agent YAML frontmatter may precede the H1. Git history is the change log.

## Exclusions

The header and language migration do not modify vendored files below `.github/skills/{vendored-skill}/`, licenses, generated evidence, machine-readable manifests, or externally owned immutable text. `.github/skills/README.md` is repository-owned and is included.

## Placement

- `docs/`: cross-cutting knowledge, decisions, specifications, plans, reviews, and policies.
- `infra/docs/`: infrastructure, identity, security, tenant bootstrap, and ALM control-plane knowledge.
- `hr/docs/`: HR domain behavior and employee-journey knowledge.
- `data/`: synthetic-data guidance and assets.

The [Docs Agent](../.github/agents/docs-agent.agent.md) owns metadata, placement, references, English-language review, and catalogue maintenance.
```

- [ ] **Step 5: Add direct ownership anchors without weakening Superpowers**

In `AGENTS.md`, retain every existing Superpowers rule and append:

```markdown
## Documentation Policy

- Maintained repository documentation is written in English and follows [the documentation policy](docs/README.md).
- Use [.github/agents/docs-agent.agent.md](.github/agents/docs-agent.agent.md) as the Voice of Knowledge for documentation metadata, placement, references, and catalogue maintenance.
- Do not apply repository documentation headers to vendored Superpowers files, licenses, generated evidence, or immutable external text.
```

In `.github/copilot-instructions.md`, retain the project-skill bootstrap and append:

```markdown
All maintained repository documentation is written in English and follows [the documentation policy](../docs/README.md). Use [.github/agents/docs-agent.agent.md](agents/docs-agent.agent.md) as the documentation policy owner. Preserve the documented exclusions and never edit vendored Superpowers content to enforce repository metadata.
```

Update `.github/agents/README.md` to link `docs-agent.agent.md` and retain the one-role-per-file contract.

- [ ] **Step 6: Run the docs-agent test to verify GREEN**

Run:

```powershell
Invoke-Pester .github/cli/tests/DocsAgentContract.Tests.ps1 -Output Detailed
```

Expected: 2 tests passed, 0 failed.

- [ ] **Step 7: Commit the documentation policy owner**

```powershell
git add -- AGENTS.md .github/copilot-instructions.md .github/agents/README.md .github/agents/docs-agent.agent.md docs/README.md .github/cli/tests/DocsAgentContract.Tests.ps1
git commit -m "docs: anchor repository documentation policy" -- AGENTS.md .github/copilot-instructions.md .github/agents/README.md .github/agents/docs-agent.agent.md docs/README.md .github/cli/tests/DocsAgentContract.Tests.ps1
```

### Task 4: Migrate Existing Repository-Owned Markdown Headers

**Files:**
- Modify: `README.md`
- Modify: `.github/agent-policy/README.md`
- Modify: `.github/agents/README.md`
- Modify: `.github/cli/README.md`
- Modify: `.github/instructions/README.md`
- Modify: `.github/issue-templates/README.md`
- Modify: `.github/skills/README.md`
- Modify: `.github/workflows/README.md`
- Modify: `docs/adr/README.md`
- Modify: `docs/archive/README.md`
- Modify: `docs/brandkit/README.md`
- Modify: `docs/business/README.md`
- Modify: `docs/delegation/README.md`
- Modify: `docs/ideas/README.md`
- Modify: `docs/issues/README.md`
- Modify: `docs/plans/README.md`
- Modify: `docs/reviews/README.md`
- Modify: `docs/specs/README.md`
- Modify: `docs/sprints/README.md`
- Modify: `docs/templates/README.md`
- Modify: `docs/specs/2026-09-15-repository-superpowers-design.md`
- Modify: `docs/plans/2026-09-15-repository-superpowers-implementation.md`
- Verify unchanged: `.github/skills/{vendored-skill}/**`

- [ ] **Step 1: Add a failing repository-wide metadata test**

Append to `.github/cli/tests/DocumentationMetadata.Tests.ps1`:

```powershell
Describe 'Repository documentation inventory' {
    It 'has valid metadata on every eligible tracked Markdown file' {
        $repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
        $paths = @(Get-ChildItem -LiteralPath $repositoryRoot -File -Recurse -Filter '*.md' | ForEach-Object {
            $_.FullName.Substring($repositoryRoot.Length).TrimStart('\').Replace('\', '/')
        })
        $failures = [Collections.Generic.List[string]]::new()
        foreach ($relativePath in $paths) {
            if (-not (Test-DocumentationMetadataEligibility -RelativePath $relativePath)) { continue }
            $content = Get-Content -LiteralPath (Join-Path $repositoryRoot $relativePath) -Raw
            foreach ($failure in @(Test-DocumentationMetadataContent -Content $content)) {
                $failures.Add("${relativePath}: $failure")
            }
        }
        $failures | Should -BeNullOrEmpty
    }
}
```

- [ ] **Step 2: Run the test to verify RED**

Run:

```powershell
Invoke-Pester .github/cli/tests/DocumentationMetadata.Tests.ps1 -Output Detailed
```

Expected: FAIL and list the header-deficient repository-owned Markdown paths.

- [ ] **Step 3: Add metadata without changing document meaning**

Run `Set-DocumentationMetadata.ps1` once for each path above. Use:

- `Version 1.0`, `Date 2026-09-17`, and `Author 'docs-agent (Voice of Knowledge)'`;
- `Status 'Active (consolidated from current state)'` for folder guidance and root `README.md`;
- `Status 'Approved'` for the 2026-09-15 design and implementation plan;
- `Scope 'Repository'` for root and `.github` artifacts;
- each document's owning `docs/{domain}` name for domain folder guidance;
- the approved 2026-09-17 specification as `References` for migration provenance.

Before writing, run every command with `-WhatIf`. After writing, verify that `git diff -- .github/skills` is empty.

- [ ] **Step 4: Run the metadata suite to verify GREEN**

Run:

```powershell
Invoke-Pester .github/cli/tests/DocumentationMetadata.Tests.ps1 -Output Detailed
git diff --check
git diff -- .github/skills
```

Expected: all metadata tests pass; both Git commands produce no output.

- [ ] **Step 5: Commit the metadata migration**

Stage and commit only the listed repository-owned Markdown paths plus `DocumentationMetadata.Tests.ps1`:

```powershell
git add -- README.md .github/agent-policy/README.md .github/agents/README.md .github/cli/README.md .github/instructions/README.md .github/issue-templates/README.md .github/skills/README.md .github/workflows/README.md docs/adr/README.md docs/archive/README.md docs/brandkit/README.md docs/business/README.md docs/delegation/README.md docs/ideas/README.md docs/issues/README.md docs/plans/README.md docs/reviews/README.md docs/specs/README.md docs/sprints/README.md docs/templates/README.md docs/specs/2026-09-15-repository-superpowers-design.md docs/plans/2026-09-15-repository-superpowers-implementation.md .github/cli/tests/DocumentationMetadata.Tests.ps1
git commit -m "docs: standardize repository document metadata" -- README.md .github/agent-policy/README.md .github/agents/README.md .github/cli/README.md .github/instructions/README.md .github/issue-templates/README.md .github/skills/README.md .github/workflows/README.md docs/adr/README.md docs/archive/README.md docs/brandkit/README.md docs/business/README.md docs/delegation/README.md docs/ideas/README.md docs/issues/README.md docs/plans/README.md docs/reviews/README.md docs/specs/README.md docs/sprints/README.md docs/templates/README.md docs/specs/2026-09-15-repository-superpowers-design.md docs/plans/2026-09-15-repository-superpowers-implementation.md .github/cli/tests/DocumentationMetadata.Tests.ps1
```

### Task 5: Import Reviewed Governance and Agent Artifacts

**Files:**
- Create: `.github/agent-policy/AGENT_WORKFLOW.md`
- Create: `.github/agent-policy/KPI_BASELINE.md`
- Create: `.github/agent-policy/NON_DELEGABLE_WORK.md`
- Create: `.github/agent-policy/BREAK_GLASS.md`
- Create: `.github/agents/cloud-solution-architect.agent.md`
- Create: `.github/agents/ux-designer.agent.md`
- Create: `docs/reviews/2026-09-17-phase-1-governance-github-intake.md`
- Modify: `.github/agents/README.md`

- [ ] **Step 1: Verify source hashes before adaptation**

Run:

```powershell
$source = 'C:\Users\urruegg\Downloads\caldova-hr-frontier'
$expected = @{
  '.github/agent-policy/AGENT_WORKFLOW.md' = 'a09a2530ea93166cb7f4b79c3ee6403ab3811e9369dd9003a4c642336890685b'
  '.github/agent-policy/KPI_BASELINE.md' = 'e88d86d810e99af8fcd6c20c7b5e00df56f9619da161f86e7dd20364a710d92a'
  '.github/agent-policy/NON_DELEGABLE_WORK.md' = '5095e9b6693b8b8853af0372ccafe7ffcc7037176c10ccc6e43753e90d610481'
  '.github/agents/cloud-solution-architect.agent.md' = '560dc12f27d11f6874b15229cc58f715546311650af9ba1bc6f305c94370a077'
  '.github/agents/ux-designer.agent.md' = '3563f94a163414cb913459fd11acbb4f78c7c0d25ce769e52807083655a53ca1'
}
foreach ($entry in $expected.GetEnumerator()) {
  $actual = (Get-FileHash -LiteralPath (Join-Path $source $entry.Key) -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($actual -cne $entry.Value) { throw "Source changed: $($entry.Key)" }
}
Write-Output 'Phase 1 governance sources match the approved inventory.'
```

Expected: `Phase 1 governance sources match the approved inventory.`

- [ ] **Step 2: Import policy prose as Proposed Baseline**

For each of the three source policy files:

1. Copy its H1 and body into the same target path.
2. Insert the standard metadata table after H1 with Version `1.0`, Date `2026-09-17`, Author `docs-agent (Voice of Knowledge)`, Status `Proposed Baseline`, Scope `Repository`, and References linking the approved specification and source inventory.
3. Replace stale links with target-relative links.
4. Preserve prohibitions on personal data, secrets, employment decisions, unsupported autonomy, and skipped validation.
5. Do not import claims that absent agents, pipelines, or Azure Boards items already exist.

- [ ] **Step 3: Add the break-glass contract**

Create `.github/agent-policy/BREAK_GLASS.md` with the standard header and these required sections:

```markdown
## Allowed Use

Full administrator bypass is allowed only when the protected pull-request path cannot restore service or repository safety in time.

## Required Record

Record the incident or work item, reason, approver, exact bypass scope, start and end time, affected refs or settings, commands or API calls, validation output, and corrective pull request.

## Procedure

1. Obtain explicit repository-owner approval and record it before changing protection.
2. Capture the current ruleset and target ref.
3. Apply the narrowest temporary bypass.
4. Make only the approved change.
5. Restore protection immediately.
6. Run the repository validator and affected checks.
7. Open the corrective or audit pull request and link the record.

## Prohibitions

Never use break-glass to avoid review convenience, bypass a failed validator, overwrite unrelated work, force-push unreviewed history, or conceal a control failure.
```

- [ ] **Step 4: Adapt the two source agents to valid workspace custom agents**

Preserve each reviewed source body after removing claims that unsupported tools or absent roles are active. Add YAML frontmatter before the H1:

```yaml
---
name: cloud-solution-architect
description: "Use when reviewing Microsoft cloud architecture, identity, governance, Power Platform, Azure DevOps, or Azure design decisions against current Microsoft guidance; advisory and read-only."
tools: [read, search, web]
user-invocable: true
---
```

```yaml
---
name: ux-designer
description: "Use when reviewing HR Frontier user journeys, interaction flows, accessibility, Teams, Copilot, or Power Platform experience designs before implementation; documentation-focused."
tools: [read, search, edit, web]
user-invocable: true
---
```

Insert each standard metadata table after its H1 with Status `Proposed Baseline`, Scope `Cross-cutting (all solution domains)`, and references to the approved specification and relevant operating-model document.

- [ ] **Step 5: Write the Phase 1 intake review**

Create `docs/reviews/2026-09-17-phase-1-governance-github-intake.md` with the standard header and tables that record every Phase 1 source path, source hash, target path, `Add` or `Merge` classification, applied transformation, validation command, and disposition. State explicitly that the source `.github/copilot-instructions.md`, `AGENTS.md`, `.gitignore`, `.github/agents/README.md`, and issue chooser were semantically merged rather than overwritten.

- [ ] **Step 6: Validate metadata, links, and agent diagnostics**

Run:

```powershell
Invoke-Pester .github/cli/tests/DocumentationMetadata.Tests.ps1,.github/cli/tests/DocsAgentContract.Tests.ps1 -Output Detailed
git diff --check
```

Use VS Code **Problems** to confirm no frontmatter or Markdown diagnostics in the three agent files.

Expected: all tests pass, `git diff --check` is empty, and VS Code reports no diagnostics.

- [ ] **Step 7: Commit the governance artifacts**

```powershell
git add -- .github/agent-policy .github/agents docs/reviews/2026-09-17-phase-1-governance-github-intake.md
git commit -m "docs: import governance baseline" -- .github/agent-policy .github/agents docs/reviews/2026-09-17-phase-1-governance-github-intake.md
```

### Task 6: Add Collaboration and Intake Controls

**Files:**
- Create: `.github/CODEOWNERS`
- Create: `.github/dependabot.yml`
- Create: `.github/ISSUE_TEMPLATE/03-frontier-intake.yml`
- Create: `.github/pull_request_template.md`
- Create: `.github/cli/tests/IssueFormContract.Tests.ps1`
- Create: `.github/cli/tests/DocumentationLinks.Tests.ps1`
- Modify: `.github/ISSUE_TEMPLATE/config.yml`
- Modify: `.gitignore`

- [ ] **Step 1: Write failing collaboration contract tests**

Create `.github/cli/tests/IssueFormContract.Tests.ps1`:

```powershell
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))

Describe 'Active issue forms' {
    It 'contains the exact four-file set' {
        $actual = @(Get-ChildItem (Join-Path $repositoryRoot '.github\ISSUE_TEMPLATE') -File | Sort-Object Name | ForEach-Object Name)
        $actual | Should -Be @('01-bug.yml', '02-feature.yml', '03-frontier-intake.yml', 'config.yml')
    }

    It 'retains bug and feature bytes and adds reviewed intake controls' {
        (Get-FileHash (Join-Path $repositoryRoot '.github\ISSUE_TEMPLATE\01-bug.yml') -Algorithm SHA256).Hash.ToLowerInvariant() |
            Should -Be '8f2c31b169477b86d85e60f9d1c91eed349fae829f1071b8b42dc93624d8879a'
        (Get-FileHash (Join-Path $repositoryRoot '.github\ISSUE_TEMPLATE\02-feature.yml') -Algorithm SHA256).Hash.ToLowerInvariant() |
            Should -Be '748e69155e9e60acd16f5cbb93b6398fd5853905951829080a9c440ed5c0e7a4'
        $intake = Get-Content (Join-Path $repositoryRoot '.github\ISSUE_TEMPLATE\03-frontier-intake.yml') -Raw
        $intake | Should -Match 'Do not include personal data'
        $intake | Should -Match 'Employee journey stage'
        $config = Get-Content (Join-Path $repositoryRoot '.github\ISSUE_TEMPLATE\config.yml') -Raw
        $config | Should -Match 'https://dev.azure.com/caldova25156897'
        $config | Should -Match 'docs/operating-model/04-hitl-governance.md'
    }
}
```

Create `.github/cli/tests/DocumentationLinks.Tests.ps1`:

```powershell
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
$repositoryPrefix = $repositoryRoot.TrimEnd('\') + '\'

Describe 'Repository documentation links' {
    It 'resolves every local Markdown link within the repository' {
        $paths = @(Get-ChildItem -LiteralPath $repositoryRoot -File -Recurse -Filter '*.md' | ForEach-Object {
            $_.FullName.Substring($repositoryRoot.Length).TrimStart('\').Replace('\', '/')
        })
        $failures = [Collections.Generic.List[string]]::new()
        foreach ($relativePath in $paths) {
            if ($relativePath.StartsWith('.github/skills/', [StringComparison]::Ordinal) -and
                $relativePath -cne '.github/skills/README.md') { continue }
            $sourcePath = Join-Path $repositoryRoot $relativePath
            $content = Get-Content -LiteralPath $sourcePath -Raw
            $contentWithoutFences = [regex]::Replace($content, '(?ms)^```.*?^```\s*$', '')
            foreach ($match in [regex]::Matches($contentWithoutFences, '!?(?:\[[^\]]*\])\(([^)]+)\)')) {
                $target = $match.Groups[1].Value.Trim().Trim([char[]]@(60, 62))
                if ($target -match '^(?:https?://|mailto:|#)') { continue }
                $pathPart = ($target -split '[?#]', 2)[0]
                if ([string]::IsNullOrWhiteSpace($pathPart)) { continue }
                $decoded = [Uri]::UnescapeDataString($pathPart).Replace('/', '\')
                $resolved = [IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $sourcePath) $decoded))
                if (-not $resolved.StartsWith($repositoryPrefix, [StringComparison]::OrdinalIgnoreCase) -or
                    -not (Test-Path -LiteralPath $resolved)) {
                    $failures.Add("$relativePath -> $target")
                }
            }
        }
        $failures | Should -BeNullOrEmpty
    }
}
```

While Phase 2 targets are not present, imported Phase 1 governance documents link to the approved intake specification instead of future paths. Phase 2 adds operating-model links atomically with their targets.

- [ ] **Step 2: Run the tests to verify RED**

Run:

```powershell
Invoke-Pester .github/cli/tests/IssueFormContract.Tests.ps1,.github/cli/tests/DocumentationLinks.Tests.ps1 -Output Detailed
```

Expected: FAIL because the intake form, contact links, CODEOWNERS targets, and imported documentation links are not complete.

- [ ] **Step 3: Add the exact Frontier Intake form and chooser links**

Copy the reviewed source `.github/ISSUE_TEMPLATE/intake.yml` body to `.github/ISSUE_TEMPLATE/03-frontier-intake.yml` after verifying source hash `d2b5eb7227c3040f65e9787c7575ca27fcd8546750a2b4ccc8977b4cdd81d06e`.

Replace `.github/ISSUE_TEMPLATE/config.yml` with:

```yaml
blank_issues_enabled: false
contact_links:
  - name: Backlog and delivery tracking
    url: https://dev.azure.com/caldova25156897
    about: Work is planned and tracked in Azure Boards. This repository is the build plane.
  - name: Governance and data rules
    url: https://github.com/urruegg/caldova-hr-frontier/blob/main/docs/operating-model/04-hitl-governance.md
    about: Read before raising anything that might contain personal data.
```

- [ ] **Step 4: Add CODEOWNERS and dependency automation**

Adapt source `.github/CODEOWNERS` so every referenced target path exists in this or a scheduled later phase. Keep `@urruegg` as default owner and explicitly own `.github/`, `AGENTS.md`, `docs/`, `infra/`, `hr/`, and `data/`.

Create `.github/dependabot.yml` from the reviewed source hash `883b95e3be554fbadd92b315e4a8c6ea6ca688b64924e22dd61222b07f683507` and validate it uses GitHub Actions ecosystem with weekly cadence.

- [ ] **Step 5: Adapt the pull request template to the public multi-tenant contract**

Add an H1 and standard metadata table before adapting source `.github/pull_request_template.md`. Preserve scope, governance, validation evidence, documentation, impact, and review-first sections. Replace the unsafe blanket statement that tenant identifiers and environment URLs are prohibited with this precise contract:

```markdown
- [ ] No secrets, credentials, access tokens, personal HR data, or unreviewed tenant values introduced
- [ ] Any committed tenant identifier or service URL is approved non-secret metadata covered by the tenant manifest and evidence policy
```

Retain Power Platform DEV/TEST/PROD checkboxes and state that they describe ALM impact, not Azure infrastructure environments.

- [ ] **Step 6: Merge only safe `.gitignore` additions**

Preserve every current rule, especially `.wt/` and the VS Code allowlist. Add only rules absent from the target:

```gitignore
dist/
build/
*.zip
*.cdsproj.user
.pac/
*.tfstate
*.tfstate.*
.terraform/
npm-debug.log*
.idea/
*.swp
.DS_Store
*.pem
*.key
.env.*
local.settings.json
```

Do not add `.vscode/` because the target intentionally tracks selected workspace configuration.

- [ ] **Step 7: Run collaboration tests to verify GREEN**

Run:

```powershell
Invoke-Pester .github/cli/tests/IssueFormContract.Tests.ps1,.github/cli/tests/DocumentationLinks.Tests.ps1 -Output Detailed
git diff --check
```

Expected: all tests pass and the diff check is empty.

- [ ] **Step 8: Commit collaboration controls**

```powershell
git add -- .github/CODEOWNERS .github/dependabot.yml .github/ISSUE_TEMPLATE .github/pull_request_template.md .github/cli/tests/IssueFormContract.Tests.ps1 .github/cli/tests/DocumentationLinks.Tests.ps1 .gitignore
git commit -m "feat: add repository collaboration controls" -- .github/CODEOWNERS .github/dependabot.yml .github/ISSUE_TEMPLATE .github/pull_request_template.md .github/cli/tests/IssueFormContract.Tests.ps1 .github/cli/tests/DocumentationLinks.Tests.ps1 .gitignore
```

### Task 7: Integrate Governance Checks into the Repository Validator

**Files:**
- Modify: `.github/cli/verify-repository-setup.ps1`
- Modify: `.github/cli/README.md`
- Modify: `.github/workflows/README.md`
- Create: `.github/workflows/validate-repository.yml`
- Create: `.github/cli/tests/WorkflowContract.Tests.ps1`

- [ ] **Step 1: Write the failing workflow contract test**

Create `.github/cli/tests/WorkflowContract.Tests.ps1`:

```powershell
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))

Describe 'Repository validation workflow' {
    It 'has least privilege, a pinned checkout action, and runs both validator and Pester' {
        $path = Join-Path $repositoryRoot '.github\workflows\validate-repository.yml'
        $path | Should -Exist
        $content = Get-Content -LiteralPath $path -Raw
        $content | Should -Match '(?m)^permissions:\s*\r?\n\s+contents: read$'
        $content | Should -Match 'actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683'
        $content | Should -Match '(?m)^\s+name: Repository setup validation$'
        $content | Should -Match 'verify-repository-setup.ps1'
        $content | Should -Match 'Invoke-Pester'
        $content | Should -Not -Match 'pull-requests: write|contents: write|id-token: write'
    }
}
```

- [ ] **Step 2: Run the test to verify RED**

Run:

```powershell
Invoke-Pester .github/cli/tests/WorkflowContract.Tests.ps1 -Output Detailed
```

Expected: FAIL because `validate-repository.yml` does not exist.

- [ ] **Step 3: Extend the validator without weakening protected snapshots**

Keep all current Superpowers and issue-form raw/index coherence checks. Refactor only enough to:

1. change the active issue-form set to four files;
2. replace hard-coded issue-form hashes with the four newly reviewed hashes generated from `Get-FileHash` after Task 6;
3. import `DocumentationMetadata.psm1` and validate every eligible tracked Markdown path;
4. require `docs/README.md`, `docs-agent.agent.md`, both direct policy anchors, source inventory, Phase 1 review, CODEOWNERS, pull request template, Dependabot, and validator workflow;
5. invoke the focused Pester suite and aggregate failures without skipping the existing byte-stability checks;
6. retain the exact sole success line `Repository setup validation passed.`.

- [ ] **Step 4: Add the validator workflow**

Create `.github/workflows/validate-repository.yml`:

```yaml
name: Validate repository

on:
  pull_request:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read

jobs:
  validate:
        name: Repository setup validation
    runs-on: windows-2025
    timeout-minutes: 15
    steps:
      - name: Check out repository
        uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683
        with:
          fetch-depth: 0

      - name: Install pinned Pester
        shell: powershell
        run: Install-Module Pester -RequiredVersion 5.7.1 -Scope CurrentUser -Force -SkipPublisherCheck

      - name: Run repository validator
        shell: powershell
        run: powershell -NoProfile -ExecutionPolicy Bypass -File .github/cli/verify-repository-setup.ps1

      - name: Run repository contract tests
        shell: powershell
        run: Invoke-Pester .github/cli/tests -Output Detailed

      - name: Check branch whitespace
        shell: powershell
        run: git diff --check origin/main...HEAD
```

- [ ] **Step 5: Update CLI and workflow catalogues**

Document the inventory generator, metadata migration tool, validator, Pester suite, source-root requirement, and validator workflow in `.github/cli/README.md` and `.github/workflows/README.md`. Retain their standard headers.

- [ ] **Step 6: Run the complete Phase 1 suite**

Run:

```powershell
Invoke-Pester .github/cli/tests -Output Detailed
powershell -NoProfile -ExecutionPolicy Bypass -File .github/cli/verify-repository-setup.ps1
git diff --check main...HEAD
```

Expected: all Pester tests pass; validator sole output is `Repository setup validation passed.`; diff check is empty.

- [ ] **Step 7: Commit validator integration**

```powershell
git add -- .github/cli/verify-repository-setup.ps1 .github/cli/README.md .github/workflows/README.md .github/workflows/validate-repository.yml .github/cli/tests/WorkflowContract.Tests.ps1
git commit -m "ci: validate governance and documentation contracts" -- .github/cli/verify-repository-setup.ps1 .github/cli/README.md .github/workflows/README.md .github/workflows/validate-repository.yml .github/cli/tests/WorkflowContract.Tests.ps1
```

### Task 8: Review Phase 1 as an Independent Slice

**Files:**
- Verify: every path introduced or modified by Tasks 1-7

- [ ] **Step 1: Verify exact source and target boundaries**

Run:

```powershell
$inventory = Get-Content docs/reviews/2026-09-17-architecture-baseline-source-inventory.json -Raw | ConvertFrom-Json
if ($inventory.totalCount -ne 45 -or $inventory.totalBytes -ne 485126) { throw 'Source inventory drifted.' }
git diff --exit-code -- .github/skills
git status --short
```

Expected: source totals match; Superpowers diff is empty; status lists only intended Phase 1 changes or is clean after commits.

- [ ] **Step 2: Run clean-shell validation**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "& { Invoke-Pester .github/cli/tests -Output Detailed; if (`$LASTEXITCODE -ne 0) { exit `$LASTEXITCODE }; & .github/cli/verify-repository-setup.ps1 }"
git diff --check main...HEAD
```

Expected: all tests pass, validator prints its sole success line, and the diff check is empty.

- [ ] **Step 3: Push the reviewable phase branch**

Run:

```powershell
git push -u origin sprint/architecture-baseline-intake
```

Expected: the branch is published. Do not activate the `main` ruleset and do not merge before Phase 1 review is complete.