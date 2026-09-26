# Azure Boards Population Implementation Plan

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-25 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Draft |
| **Scope** | Infrastructure (Tenant 1) |
| **References** | [Azure Boards Population Design](../specs/2026-09-25-azure-boards-population-design.md) |

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build one self-contained, tested PowerShell script that populates Azure DevOps Boards for Tenant 1 with one `Epic` per HR use-case idea (19 total), each tagged with its real status/journey-stage and linked to its GitHub source via a native `Hyperlink` relation — following the same discover → plan → attended-execute → read-back pattern already used by `Initialize-TenantTrust.ps1`.

**Architecture:** A single top-level script, `infra/src/scripts/Initialize-AzureDevOpsWorkItems.ps1`, sized and structured like `Initialize-TenantTrust.ps1` (own internal helper functions, injectable adapter parameters, tested by direct invocation — not a module member). Three internal functions do the work: `Get-HrIdeaPortfolioItems` (parses the 19 idea files' own H1 + status blockquote — verified present in all 19 files during design), `Get-AzureDevOpsProcessCapabilities` (confirms an `Epic` work item type exists before planning anything), and `Get-AzureDevOpsWorkItemPlan` (WIQL-queries existing tagged items, computes Create/Existing). The main script body writes a reviewed plan JSON under `-WhatIf`, and — only without `-WhatIf` — creates/updates each Epic behind `ShouldProcess`, with full read-back verification.

**Tech Stack:** PowerShell 5.1 (Windows PowerShell, matching CI), Pester 5.7.1, Azure CLI 2.90+ with the `azure-devops` extension (`az boards work-item create/update/show/relation add`, `az boards query`, `az devops invoke`).

**Spec:** [`docs/specs/2026-09-25-azure-boards-population-design.md`](../specs/2026-09-25-azure-boards-population-design.md)

## Global Constraints

- **No live Azure DevOps mutation is performed by this plan.** All 5 tasks are buildable and fully testable with injected fakes; running the finished script for real against Tenant 1 is deferred to the runbook (Task 5), an attended human action — matching this repository's established pattern for `Initialize-TenantTrust.ps1`.
- **One `Epic` per idea, nothing underneath** (spec Ruling 1). Never create a `Feature`/`User Story`/`Task`/`Bug`.
- **Status tag priority order is exact** (spec Ruling 3): `Selected as MVP` → `MVP`; `IN MVP SCOPE` → `MVP-Candidate`; `Runs alongside the MVP` → `MVP-Adjacent`; anything else → `Candidate`. This order matters — check in this sequence, first match wins.
- **`JourneyStage` tag is the blockquote's `**Journey stage:**` value verbatim**, with ` — ` (em dash, spaces either side) replaced by ` - ` (hyphen) — never truncated, never re-categorized.
- **The GitHub source link is a native `Hyperlink` relation**, not a URL embedded in `Description` prose (spec Ruling 2).
- **The process/Epic-type check fails closed.** If the Azure DevOps project's work item types do not include one named exactly `Epic`, the script throws a named, actionable error and computes no plan at all.
- **`-PlanOutputPath` must resolve under the OS temp directory or `$env:RUNNER_TEMP`**, matching `Resolve-AllowedPlanOutputPath` in `Initialize-TenantTrust.ps1` exactly (reuse the same restriction, do not weaken it).
- **A `UC-nnnn` tag matching more than one existing work item is ambiguous and fails closed** — never pick the first match.
- Every markdown file created carries the repository's required six-field documentation metadata table (`Version`/`Date`/`Author`/`Status`/`Scope`/`References`) immediately after its H1.

---

### Task 1: Portfolio parsing — `Get-HrIdeaPortfolioItems`

**Files:**
- Create: `infra/src/scripts/Initialize-AzureDevOpsWorkItems.ps1` (this task adds only the top portion: param block, helper functions through `Get-HrIdeaPortfolioItems`, and a temporary bottom guard so the file is valid PowerShell — later tasks extend this same file)
- Create: `infra/tests/pester/AzureBoardsPopulation.Tests.ps1`

**Interfaces:**
- Produces: `Get-HrIdeaPortfolioItems -IdeasRoot <string>` → `[pscustomobject[]]`, one per idea, each with properties `UseCaseId` (e.g. `'UC-0006'`), `Title` (e.g. `'Job Description Generator'`), `Status` (one of `'MVP'`, `'MVP-Candidate'`, `'MVP-Adjacent'`, `'Candidate'`), `JourneyStage` (e.g. `'Hire'`, `'Cross-cutting - HR Service Delivery'`), `SourcePath` (repo-relative, forward-slash separated, e.g. `'hr/docs/ideas/uc-0006-job-description-generator.md'`), `Summary` (one line, e.g. `'Assists hiring managers by generating standardised, inclusive, role-specific job descriptions.'`). Always returns exactly 19 items, ordered `UC-0001` through `UC-0019`. Later tasks (2 is independent; 3, 4 consume this) call this function by this exact name and signature.

- [ ] **Step 1: Write the failing test**

Create `infra/tests/pester/AzureBoardsPopulation.Tests.ps1` with this content:

```powershell
Set-StrictMode -Version Latest

Describe 'Azure Boards population' {
    BeforeAll {
        $script:RepositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
        $script:ScriptPath = Join-Path $script:RepositoryRoot 'infra\src\scripts\Initialize-AzureDevOpsWorkItems.ps1'

        function script:New-IdeaFixtureFile {
            param(
                [Parameter(Mandatory)] [string]$Root,
                [Parameter(Mandatory)] [string]$RelativePath,
                [Parameter(Mandatory)] [string]$UseCaseId,
                [Parameter(Mandatory)] [string]$Title,
                [Parameter(Mandatory)] [string]$StatusLine,
                [Parameter(Mandatory)] [string]$JourneyStage,
                [Parameter(Mandatory)] [string]$Summary
            )

            $fullPath = Join-Path $Root $RelativePath
            $directory = Split-Path -Parent $fullPath
            if (-not (Test-Path -LiteralPath $directory)) {
                New-Item -ItemType Directory -Path $directory -Force | Out-Null
            }

            $content = @"
# $UseCaseId — $Title

| Field | Value |
|---|---|
| **Version** | 1.0 |

> **Status:** $StatusLine
> **Journey stage:** $JourneyStage
> **HR process area:** Test
> **HR owner:** Test Owner

---

## 1. The Idea

$Summary

| | |
|---|---|
| **Business objective** | Test |
"@
            [System.IO.File]::WriteAllText($fullPath, $content, [System.Text.UTF8Encoding]::new($false))
        }

        function script:New-FixtureIdeasRoot {
            $root = Join-Path $TestDrive ([guid]::NewGuid().ToString())
            New-Item -ItemType Directory -Path $root -Force | Out-Null

            $fixtures = @(
                @{ Id = 'UC-0001'; Path = 'uc-0001-fixture-folder\uc-0001-fixture-folder.md'; Title = 'Fixture MVP Selected'; StatusLine = '**Selected as MVP** — the only use case in this portfolio that has advanced past idea'; Stage = 'Pre-board'; Summary = 'Summary for UC-0001.' }
                @{ Id = 'UC-0002'; Path = 'uc-0002-fixture-adjacent.md'; Title = 'Fixture Adjacent'; StatusLine = '**Runs alongside the MVP** — recommended, not counted'; Stage = 'Cross-cutting — HR Service Delivery'; Summary = 'Summary for UC-0002.' }
                @{ Id = 'UC-0005'; Path = 'uc-0005-fixture-mvp-candidate.md'; Title = 'Fixture MVP Candidate'; StatusLine = '**IN MVP SCOPE** — selected, not yet specified'; Stage = 'Onboard'; Summary = 'Summary for UC-0005.' }
                @{ Id = 'UC-0006'; Path = 'uc-0006-fixture-candidate.md'; Title = 'Fixture Candidate'; StatusLine = 'Idea — draft for review'; Stage = 'Hire'; Summary = 'Summary for UC-0006.' }
            )

            foreach ($fixture in $fixtures) {
                New-IdeaFixtureFile -Root $root -RelativePath $fixture.Path -UseCaseId $fixture.Id -Title $fixture.Title -StatusLine $fixture.StatusLine -JourneyStage $fixture.Stage -Summary $fixture.Summary
            }

            $root
        }
    }

    Context 'Get-HrIdeaPortfolioItems' {
        It 'parses UseCaseId, Title, Status, JourneyStage, SourcePath, and Summary from each fixture idea file' {
            $ideasRoot = New-FixtureIdeasRoot

            $items = InModuleScope -ModuleName 'DoesNotExist' -ErrorAction SilentlyContinue { } 2>$null
            $items = & {
                . $script:ScriptPath -TenantAlias 'caldova25156897' -IdeasRoot $ideasRoot -WhatIf -ReturnPortfolioOnly 2>$null
            }

            $items = Get-HrIdeaPortfolioItemsForTest -IdeasRoot $ideasRoot

            $items.Count | Should -Be 4

            $uc0001 = $items | Where-Object UseCaseId -eq 'UC-0001'
            $uc0001.Title | Should -Be 'Fixture MVP Selected'
            $uc0001.Status | Should -Be 'MVP'
            $uc0001.JourneyStage | Should -Be 'Pre-board'
            $uc0001.SourcePath | Should -Be 'uc-0001-fixture-folder/uc-0001-fixture-folder.md'
            $uc0001.Summary | Should -Be 'Summary for UC-0001.'

            $uc0002 = $items | Where-Object UseCaseId -eq 'UC-0002'
            $uc0002.Status | Should -Be 'MVP-Adjacent'
            $uc0002.JourneyStage | Should -Be 'Cross-cutting - HR Service Delivery'

            $uc0005 = $items | Where-Object UseCaseId -eq 'UC-0005'
            $uc0005.Status | Should -Be 'MVP-Candidate'

            $uc0006 = $items | Where-Object UseCaseId -eq 'UC-0006'
            $uc0006.Status | Should -Be 'Candidate'
        }

        It 'throws a clear error when an idea file has no H1 line' {
            $root = Join-Path $TestDrive ([guid]::NewGuid().ToString())
            New-Item -ItemType Directory -Path $root -Force | Out-Null
            [System.IO.File]::WriteAllText((Join-Path $root 'uc-0001-broken.md'), "No heading here`n> **Status:** Idea`n", [System.Text.UTF8Encoding]::new($false))

            { Get-HrIdeaPortfolioItemsForTest -IdeasRoot $root } | Should -Throw '*H1*'
        }

        It 'throws a clear error when an idea file has no Status blockquote line' {
            $root = Join-Path $TestDrive ([guid]::NewGuid().ToString())
            New-Item -ItemType Directory -Path $root -Force | Out-Null
            [System.IO.File]::WriteAllText((Join-Path $root 'uc-0001-broken.md'), "# UC-0001 — Broken`n`nNo status blockquote.`n", [System.Text.UTF8Encoding]::new($false))

            { Get-HrIdeaPortfolioItemsForTest -IdeasRoot $root } | Should -Throw '*Status*'
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path infra/tests/pester/AzureBoardsPopulation.Tests.ps1 -Output Detailed`
Expected: FAIL — `infra/src/scripts/Initialize-AzureDevOpsWorkItems.ps1` does not exist yet, and `Get-HrIdeaPortfolioItemsForTest` is not recognized.

- [ ] **Step 3: Replace the test's awkward invocation with the real, final pattern**

The test above has a placeholder invocation approach (the two throwaway lines calling `InModuleScope`/dot-sourcing with stray parameters) because the script does not exist yet. Before running Step 2, delete those two throwaway lines and replace the whole `It` block bodies with the pattern the script will actually support: the script, when dot-sourced, defines its functions in the caller's scope without executing its main body, guarded by `$MyInvocation.InvocationName -eq '.'` being false only when directly invoked — instead, use the simpler, already-proven repository convention from `TenantTrust.Tests.ps1`: expose a `-ReturnPortfolioOnly` switch on the script itself that, when set, computes and returns just the portfolio array (via `Write-Output -NoEnumerate`) without touching Azure DevOps at all. Replace the test file's `Context 'Get-HrIdeaPortfolioItems'` block with:

```powershell
    Context 'Get-HrIdeaPortfolioItems' {
        It 'parses UseCaseId, Title, Status, JourneyStage, SourcePath, and Summary from each fixture idea file' {
            $ideasRoot = New-FixtureIdeasRoot

            $items = & $script:ScriptPath -TenantAlias 'caldova25156897' -IdeasRoot $ideasRoot -ReturnPortfolioOnly

            $items.Count | Should -Be 4

            $uc0001 = $items | Where-Object UseCaseId -eq 'UC-0001'
            $uc0001.Title | Should -Be 'Fixture MVP Selected'
            $uc0001.Status | Should -Be 'MVP'
            $uc0001.JourneyStage | Should -Be 'Pre-board'
            $uc0001.SourcePath | Should -Be 'uc-0001-fixture-folder/uc-0001-fixture-folder.md'
            $uc0001.Summary | Should -Be 'Summary for UC-0001.'

            $uc0002 = $items | Where-Object UseCaseId -eq 'UC-0002'
            $uc0002.Status | Should -Be 'MVP-Adjacent'
            $uc0002.JourneyStage | Should -Be 'Cross-cutting - HR Service Delivery'

            $uc0005 = $items | Where-Object UseCaseId -eq 'UC-0005'
            $uc0005.Status | Should -Be 'MVP-Candidate'

            $uc0006 = $items | Where-Object UseCaseId -eq 'UC-0006'
            $uc0006.Status | Should -Be 'Candidate'
        }

        It 'throws a clear error when an idea file has no H1 line' {
            $root = Join-Path $TestDrive ([guid]::NewGuid().ToString())
            New-Item -ItemType Directory -Path $root -Force | Out-Null
            [System.IO.File]::WriteAllText((Join-Path $root 'uc-0001-broken.md'), "No heading here`n> **Status:** Idea`n", [System.Text.UTF8Encoding]::new($false))

            { & $script:ScriptPath -TenantAlias 'caldova25156897' -IdeasRoot $root -ReturnPortfolioOnly } | Should -Throw '*H1*'
        }

        It 'throws a clear error when an idea file has no Status blockquote line' {
            $root = Join-Path $TestDrive ([guid]::NewGuid().ToString())
            New-Item -ItemType Directory -Path $root -Force | Out-Null
            [System.IO.File]::WriteAllText((Join-Path $root 'uc-0001-broken.md'), "# UC-0001 — Broken`n`nNo status blockquote.`n", [System.Text.UTF8Encoding]::new($false))

            { & $script:ScriptPath -TenantAlias 'caldova25156897' -IdeasRoot $root -ReturnPortfolioOnly } | Should -Throw '*Status*'
        }
    }
```

Also delete the now-unused `Get-HrIdeaPortfolioItemsForTest`-style stray line from `BeforeAll` if you copied it verbatim from Step 1 — the final test file's `Context` block above is self-contained and needs nothing else from `BeforeAll` beyond the two fixture-building functions already shown in Step 1.

- [ ] **Step 4: Run test again to verify it fails for the right reason**

Run: `Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path infra/tests/pester/AzureBoardsPopulation.Tests.ps1 -Output Detailed`
Expected: FAIL — `infra/src/scripts/Initialize-AzureDevOpsWorkItems.ps1` does not exist (`The term '...\Initialize-AzureDevOpsWorkItems.ps1' is not recognized`).

- [ ] **Step 5: Create the script with the param block, `Get-HrIdeaPortfolioItems`, and a minimal main body**

Create `infra/src/scripts/Initialize-AzureDevOpsWorkItems.ps1`:

```powershell
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-z0-9]+$')]
    [string]$TenantAlias,

    [string]$IdeasRoot,

    [string]$PlanOutputPath,

    [switch]$ReturnPortfolioOnly,

    [Parameter(DontShow)]
    [scriptblock]$AzRequest,

    [Parameter(DontShow)]
    [scriptblock]$AzureDevOpsRequest,

    [Parameter(DontShow)]
    [scriptblock]$NativeCommandRunner
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-RepositoryRoot {
    [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
}

function Get-DefaultIdeasRoot {
    Join-Path (Get-RepositoryRoot) 'hr\docs\ideas'
}

function ConvertTo-RepoRelativeForwardSlashPath {
    param(
        [Parameter(Mandatory)]
        [string]$FullPath,

        [Parameter(Mandatory)]
        [string]$RepositoryRoot
    )

    $normalizedRoot = [System.IO.Path]::GetFullPath($RepositoryRoot).TrimEnd('\', '/')
    $normalizedFull = [System.IO.Path]::GetFullPath($FullPath)
    if (-not $normalizedFull.StartsWith($normalizedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Path '$FullPath' is not under repository root '$RepositoryRoot'."
    }

    $relative = $normalizedFull.Substring($normalizedRoot.Length).TrimStart('\', '/')
    $relative -replace '\\', '/'
}

function Get-HrIdeaPortfolioItems {
    param(
        [Parameter(Mandatory)]
        [string]$IdeasRoot
    )

    $repositoryRoot = Get-RepositoryRoot
    $files = @(Get-ChildItem -LiteralPath $IdeasRoot -Filter '*.md' -Recurse -File |
        Where-Object { $_.Name -cmatch '^uc-\d{4}-' } |
        Sort-Object FullName)

    if ($files.Count -eq 0) {
        throw "No idea files matching 'uc-NNNN-*.md' were found under '$IdeasRoot'."
    }

    $items = [System.Collections.Generic.List[object]]::new()
    foreach ($file in $files) {
        $content = [System.IO.File]::ReadAllText($file.FullName)
        $lines = $content -split "`r?`n"

        $headingLine = $lines | Where-Object { $_ -cmatch '^#\s+(UC-\d{4})\s*[—-]\s*(.+)$' } | Select-Object -First 1
        if (-not $headingLine) {
            throw "Idea file '$($file.FullName)' has no H1 line matching '# UC-NNNN — Title'."
        }
        $null = $headingLine -cmatch '^#\s+(UC-\d{4})\s*[—-]\s*(.+)$'
        $useCaseId = $Matches[1]
        $title = $Matches[2].Trim()

        $statusLine = $lines | Where-Object { $_ -cmatch '^>\s*\*\*Status:\*\*\s*(.+)$' } | Select-Object -First 1
        if (-not $statusLine) {
            throw "Idea file '$($file.FullName)' ($useCaseId) has no '> **Status:** ...' blockquote line."
        }
        $null = $statusLine -cmatch '^>\s*\*\*Status:\*\*\s*(.+)$'
        $statusText = $Matches[1].Trim()

        $status =
            if ($statusText -match 'Selected as MVP') { 'MVP' }
            elseif ($statusText -match 'IN MVP SCOPE') { 'MVP-Candidate' }
            elseif ($statusText -match 'Runs alongside the MVP') { 'MVP-Adjacent' }
            else { 'Candidate' }

        $stageLine = $lines | Where-Object { $_ -cmatch '^>\s*\*\*Journey stage:\*\*\s*(.+)$' } | Select-Object -First 1
        if (-not $stageLine) {
            throw "Idea file '$($file.FullName)' ($useCaseId) has no '> **Journey stage:** ...' blockquote line."
        }
        $null = $stageLine -cmatch '^>\s*\*\*Journey stage:\*\*\s*(.+)$'
        $journeyStage = ($Matches[1].Trim()) -replace '\s+—\s+', ' - '

        $ideaHeadingIndex = 0..($lines.Count - 1) | Where-Object { $lines[$_] -cmatch '^##\s+1\.\s+The Idea\s*$' } | Select-Object -First 1
        if ($null -eq $ideaHeadingIndex) {
            throw "Idea file '$($file.FullName)' ($useCaseId) has no '## 1. The Idea' heading."
        }
        $summary = $null
        for ($i = [int]$ideaHeadingIndex + 1; $i -lt $lines.Count; $i++) {
            if (-not [string]::IsNullOrWhiteSpace($lines[$i])) {
                $summary = $lines[$i].Trim()
                break
            }
        }
        if ($null -eq $summary) {
            throw "Idea file '$($file.FullName)' ($useCaseId) has no summary paragraph after '## 1. The Idea'."
        }

        $items.Add([pscustomobject]@{
            UseCaseId = $useCaseId
            Title = $title
            Status = $status
            JourneyStage = $journeyStage
            SourcePath = ConvertTo-RepoRelativeForwardSlashPath -FullPath $file.FullName -RepositoryRoot $repositoryRoot
            Summary = $summary
        }) | Out-Null
    }

    @($items | Sort-Object UseCaseId)
}

$resolvedIdeasRoot = if ([string]::IsNullOrWhiteSpace($IdeasRoot)) { Get-DefaultIdeasRoot } else { $IdeasRoot }
$portfolio = Get-HrIdeaPortfolioItems -IdeasRoot $resolvedIdeasRoot

if ($ReturnPortfolioOnly) {
    Write-Output -NoEnumerate $portfolio
    return
}

throw 'Initialize-AzureDevOpsWorkItems.ps1: only -ReturnPortfolioOnly is implemented so far (Task 1 of the implementation plan). Later tasks add process discovery, plan computation, and mutation.'
```

- [ ] **Step 6: Run test to verify it passes**

Run: `Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path infra/tests/pester/AzureBoardsPopulation.Tests.ps1 -Output Detailed`
Expected: PASS — all 3 tests in the `Get-HrIdeaPortfolioItems` context green.

- [ ] **Step 7: Sanity-check parsing against this repository's real 19 idea files**

Run (from the repository root, in Windows PowerShell): `. .\infra\src\scripts\Initialize-AzureDevOpsWorkItems.ps1 -TenantAlias caldova25156897 -ReturnPortfolioOnly | Format-Table UseCaseId, Status, JourneyStage, SourcePath -AutoSize`

Wait — dot-sourcing the script this way also executes its bottom `throw`/`return` logic outside a function context, which is fine here since `-ReturnPortfolioOnly` causes an early `return` before the `throw` line. Confirm the output shows all 19 real ideas (`UC-0001` through `UC-0019`), `UC-0001` shows `Status = MVP`, `UC-0002` shows `Status = MVP-Adjacent`, `UC-0005` and `UC-0010` show `Status = MVP-Candidate`, and the remaining 15 show `Status = Candidate`. This is a real, live check against this repository's actual content — not a fixture — and is the cheapest possible way to catch a parsing rule that works on fixtures but not on the real files' exact formatting.
Expected: 19 rows, exactly the status distribution above, and every `JourneyStage` value free of literal em-dash characters (`—`) — confirm with `... | Select-Object -ExpandProperty JourneyStage | Select-String '—'` returning nothing.

- [ ] **Step 8: Commit**

```bash
git add infra/src/scripts/Initialize-AzureDevOpsWorkItems.ps1 infra/tests/pester/AzureBoardsPopulation.Tests.ps1
git commit -m "feat(infra): add HR idea portfolio parsing for Azure Boards population"
```

---

### Task 2: Process capability discovery — `Get-AzureDevOpsProcessCapabilities`

**Files:**
- Modify: `infra/src/scripts/Initialize-AzureDevOpsWorkItems.ps1` (insert the new function and its supporting adapter helpers; do not touch `Get-HrIdeaPortfolioItems` from Task 1)
- Modify: `infra/tests/pester/AzureBoardsPopulation.Tests.ps1` (add a new `Context` block)

**Interfaces:**
- Consumes: an injected `-AzureDevOpsRequest` scriptblock with signature `param($Operation, $Arguments)`, matching `Invoke-AzureDevOpsDiscoveryRequest`'s calling convention in `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/Get-AzureDevOpsDiscovery.ps1`.
- Produces: `Get-AzureDevOpsProcessCapabilities -OrganizationUrl <string> -ProjectName <string> -Request <scriptblock>` → `[pscustomobject]` with one property, `EpicWorkItemTypeName` (`[string]`, always exactly `'Epic'` when found — this function's whole job is verifying that name is present, not discovering an alternate name). Throws `"Azure DevOps project '<ProjectName>' has no 'Epic' work item type. Observed types: <comma-joined list>."` when absent. Task 3 calls this function and consumes its non-throwing return as proof planning may proceed.

- [ ] **Step 1: Write the failing test**

Add this `Context` block to `infra/tests/pester/AzureBoardsPopulation.Tests.ps1`, inside the existing `Describe 'Azure Boards population'` block, after the `Context 'Get-HrIdeaPortfolioItems'` block:

```powershell
    Context 'Get-AzureDevOpsProcessCapabilities' {
        It 'returns EpicWorkItemTypeName when the project work item types include Epic' {
            $fixture = [pscustomobject]@{
                StatusCode = 200
                Headers = @{}
                Body = [pscustomobject]@{
                    count = 3
                    value = @(
                        [pscustomobject]@{ name = 'Epic'; referenceName = 'Microsoft.VSTS.WorkItemTypes.Epic' }
                        [pscustomobject]@{ name = 'Feature'; referenceName = 'Microsoft.VSTS.WorkItemTypes.Feature' }
                        [pscustomobject]@{ name = 'Bug'; referenceName = 'Microsoft.VSTS.WorkItemTypes.Bug' }
                    )
                }
            }

            $result = & $script:ScriptPath -TenantAlias 'caldova25156897' -ReturnProcessCapabilitiesOnly `
                -AzureDevOpsRequest {
                    param($Operation, $Arguments)
                    $fixture
                }

            $result.EpicWorkItemTypeName | Should -Be 'Epic'
        }

        It 'throws a named error listing the observed types when Epic is absent' {
            $fixture = [pscustomobject]@{
                StatusCode = 200
                Headers = @{}
                Body = [pscustomobject]@{
                    count = 2
                    value = @(
                        [pscustomobject]@{ name = 'Requirement'; referenceName = 'Microsoft.VSTS.WorkItemTypes.Requirement' }
                        [pscustomobject]@{ name = 'Bug'; referenceName = 'Microsoft.VSTS.WorkItemTypes.Bug' }
                    )
                }
            }

            {
                & $script:ScriptPath -TenantAlias 'caldova25156897' -ReturnProcessCapabilitiesOnly `
                    -AzureDevOpsRequest {
                        param($Operation, $Arguments)
                        $fixture
                    }
            } | Should -Throw "*no 'Epic' work item type*Requirement, Bug*"
        }
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path infra/tests/pester/AzureBoardsPopulation.Tests.ps1 -Output Detailed`
Expected: FAIL — `-ReturnProcessCapabilitiesOnly` parameter does not exist.

- [ ] **Step 3: Implement**

Insert into `infra/src/scripts/Initialize-AzureDevOpsWorkItems.ps1`, immediately before the line `$resolvedIdeasRoot = if (...)`:

First, add two new parameters to the top `param()` block, alongside the existing ones (insert after `[switch]$ReturnPortfolioOnly,`):

```powershell
    [switch]$ReturnProcessCapabilitiesOnly,
```

Next, add these helper and adapter functions, immediately after `Get-HrIdeaPortfolioItems`'s closing `}` and before the `$resolvedIdeasRoot = ...` line:

```powershell
function Get-ResponseBodyOrNull {
    param(
        [Parameter(Mandatory)]
        [object]$Response
    )

    $responseTable = ConvertTo-Hashtable -InputObject $Response
    if ($responseTable.ContainsKey('Body')) { $responseTable['Body'] } else { $null }
}

function ConvertTo-Hashtable {
    param(
        [AllowNull()]
        [object]$InputObject
    )

    if ($null -eq $InputObject) {
        return @{}
    }

    if ($InputObject -is [hashtable]) {
        return $InputObject
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        $table = @{}
        foreach ($key in $InputObject.Keys) {
            $table[[string]$key] = $InputObject[$key]
        }

        return $table
    }

    $table = @{}
    foreach ($property in $InputObject.PSObject.Properties) {
        if ($property.MemberType -in @('NoteProperty', 'Property', 'ScriptProperty')) {
            $table[$property.Name] = $property.Value
        }
    }

    $table
}

function ConvertTo-AzureDevOpsWorkItemTypeItems {
    param(
        [AllowNull()]
        [object]$Node
    )

    if ($null -eq $Node) {
        return @()
    }

    $entries = ConvertTo-Hashtable -InputObject $Node
    if ($entries.ContainsKey('value')) {
        return @($entries['value'])
    }

    @($Node)
}

function New-DefaultAzureDevOpsRequest {
    param(
        [Parameter(Mandatory)]
        [scriptblock]$NativeRunner
    )

    {
        param($Operation, $Arguments)

        switch ($Operation) {
            'ListWorkItemTypes' {
                return (Invoke-NativeJsonCommand -Runner $NativeRunner -FilePath 'az' -ArgumentList @(
                    'devops', 'invoke',
                    '--organization', [string]$Arguments['OrganizationUrl'],
                    '--area', 'wit',
                    '--resource', 'workitemtypes',
                    '--route-parameters', "project=$([string]$Arguments['ProjectName'])",
                    '--api-version', '7.1',
                    '--output', 'json'
                ))
            }
            default {
                throw "Unsupported AzureDevOps operation '$Operation'."
            }
        }
    }.GetNewClosure()
}

function Get-AzureDevOpsProcessCapabilities {
    param(
        [Parameter(Mandatory)]
        [string]$OrganizationUrl,

        [Parameter(Mandatory)]
        [string]$ProjectName,

        [Parameter(Mandatory)]
        [scriptblock]$Request
    )

    $response = & $Request 'ListWorkItemTypes' @{ OrganizationUrl = $OrganizationUrl; ProjectName = $ProjectName }
    $body = Get-ResponseBodyOrNull -Response $response
    $types = @(ConvertTo-AzureDevOpsWorkItemTypeItems -Node $body)
    $typeNames = @($types | ForEach-Object { [string](ConvertTo-Hashtable -InputObject $_)['name'] })

    if ($typeNames -notcontains 'Epic') {
        throw "Azure DevOps project '$ProjectName' has no 'Epic' work item type. Observed types: $($typeNames -join ', ')."
    }

    [pscustomobject]@{ EpicWorkItemTypeName = 'Epic' }
}
```

Also add, immediately after `Invoke-NativeJsonCommand`'s definition is needed — since Task 1 did not define it, add these two native-command helpers as well, in the same location (before `New-DefaultAzureDevOpsRequest`, since it depends on them):

```powershell
function Invoke-NativeCommand {
    param(
        [Parameter(Mandatory)]
        [scriptblock]$Runner,

        [Parameter(Mandatory)]
        [string]$FilePath,

        [Parameter(Mandatory)]
        [string[]]$ArgumentList
    )

    $result = & $Runner -FilePath $FilePath -ArgumentList $ArgumentList
    $resultTable = ConvertTo-Hashtable -InputObject $result
    if (-not $resultTable.ContainsKey('ExitCode')) {
        throw "Native command '$FilePath' did not return ExitCode."
    }

    [pscustomobject]@{
        ExitCode = [int]$resultTable.ExitCode
        StdOut = if ($resultTable.ContainsKey('StdOut')) { [string]$resultTable.StdOut } else { '' }
        StdErr = if ($resultTable.ContainsKey('StdErr')) { [string]$resultTable.StdErr } else { '' }
    }
}

function Invoke-NativeJsonCommand {
    param(
        [Parameter(Mandatory)]
        [scriptblock]$Runner,

        [Parameter(Mandatory)]
        [string]$FilePath,

        [Parameter(Mandatory)]
        [string[]]$ArgumentList
    )

    $commandResult = Invoke-NativeCommand -Runner $Runner -FilePath $FilePath -ArgumentList $ArgumentList
    if ($commandResult.ExitCode -ne 0) {
        throw "$FilePath $($ArgumentList -join ' ') failed with exit code $($commandResult.ExitCode): $($commandResult.StdErr)"
    }

    [pscustomobject]@{
        StatusCode = 200
        Headers = @{}
        Body = if ([string]::IsNullOrWhiteSpace($commandResult.StdOut)) { $null } else { $commandResult.StdOut | ConvertFrom-Json }
    }
}

function New-DefaultNativeCommandRunner {
    {
        param(
            [Parameter(Mandatory)]
            [string]$FilePath,

            [Parameter(Mandatory)]
            [string[]]$ArgumentList
        )

        $merged = & $FilePath @ArgumentList 2>&1
        [pscustomobject]@{
            ExitCode = $LASTEXITCODE
            StdOut = ($merged | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
            StdErr = ''
        }
    }
}
```

Finally, replace the line `$resolvedIdeasRoot = if ([string]::IsNullOrWhiteSpace($IdeasRoot)) { Get-DefaultIdeasRoot } else { $IdeasRoot }` and everything below it with:

```powershell
$nativeCommandRunner = if ($NativeCommandRunner) { $NativeCommandRunner } else { New-DefaultNativeCommandRunner }
$azureDevOpsRequest = if ($AzureDevOpsRequest) { $AzureDevOpsRequest } else { New-DefaultAzureDevOpsRequest -NativeRunner $nativeCommandRunner }

$resolvedIdeasRoot = if ([string]::IsNullOrWhiteSpace($IdeasRoot)) { Get-DefaultIdeasRoot } else { $IdeasRoot }
$portfolio = Get-HrIdeaPortfolioItems -IdeasRoot $resolvedIdeasRoot

if ($ReturnPortfolioOnly) {
    Write-Output -NoEnumerate $portfolio
    return
}

$organizationUrl = "https://dev.azure.com/$TenantAlias/"
$projectName = 'Caldova HR Frontier'

if ($ReturnProcessCapabilitiesOnly) {
    $capabilities = Get-AzureDevOpsProcessCapabilities -OrganizationUrl $organizationUrl -ProjectName $projectName -Request $azureDevOpsRequest
    Write-Output -NoEnumerate $capabilities
    return
}

throw 'Initialize-AzureDevOpsWorkItems.ps1: only -ReturnPortfolioOnly and -ReturnProcessCapabilitiesOnly are implemented so far (Tasks 1-2 of the implementation plan). Later tasks add plan computation and mutation.'
```

- [ ] **Step 4: Run test to verify it passes**

Run: `Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path infra/tests/pester/AzureBoardsPopulation.Tests.ps1 -Output Detailed`
Expected: PASS — all tests from Task 1 and Task 2 green (5 total).

- [ ] **Step 5: Commit**

```bash
git add infra/src/scripts/Initialize-AzureDevOpsWorkItems.ps1 infra/tests/pester/AzureBoardsPopulation.Tests.ps1
git commit -m "feat(infra): add Azure DevOps Epic work item type capability check"
```

---

### Task 3: Plan computation — `Get-AzureDevOpsWorkItemPlan`

**Files:**
- Modify: `infra/src/scripts/Initialize-AzureDevOpsWorkItems.ps1`
- Modify: `infra/tests/pester/AzureBoardsPopulation.Tests.ps1`

**Interfaces:**
- Consumes: `Get-HrIdeaPortfolioItems` (Task 1) return shape; `Get-AzureDevOpsProcessCapabilities` (Task 2) return shape; the same `-AzureDevOpsRequest` adapter convention.
- Produces: `Get-AzureDevOpsWorkItemPlan -OrganizationUrl <string> -ProjectName <string> -PortfolioItems <object[]> -Request <scriptblock>` → `[pscustomobject[]]`, one per portfolio item, each with `UseCaseId`, `Title`, `Status`, `JourneyStage`, `SourcePath`, `Summary` (carried through from the portfolio item), plus `ExistingWorkItemId` (`[int]`, `0` when none found), `Mode` (`'Existing'` or `'Create'`), `HyperlinkUrl` (`[string]`, the computed `https://github.com/urruegg/caldova-hr-frontier/blob/main/<SourcePath>` URL). Throws `"Ambiguous existing work items tagged '<UseCaseId>': ids <comma-joined ids>."` when a tag query returns more than one result. Task 4 consumes this array to decide what to create/update.

- [ ] **Step 1: Write the failing test**

Add this `Context` block after `Context 'Get-AzureDevOpsProcessCapabilities'`:

```powershell
    Context 'Get-AzureDevOpsWorkItemPlan' {
        It 'marks an idea Create when the WIQL query returns no matching work item' {
            $wiqlEmptyFixture = [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = [pscustomobject]@{ workItems = @() } }

            $ideasRoot = New-FixtureIdeasRoot
            $items = & $script:ScriptPath -TenantAlias 'caldova25156897' -IdeasRoot $ideasRoot -ReturnPortfolioOnly

            $plan = & $script:ScriptPath -TenantAlias 'caldova25156897' -IdeasRoot $ideasRoot -ReturnWorkItemPlanOnly `
                -AzureDevOpsRequest {
                    param($Operation, $Arguments)
                    switch ($Operation) {
                        'QueryWorkItemsByTag' { $wiqlEmptyFixture }
                        default { throw "Unexpected operation '$Operation' in this test." }
                    }
                }

            $plan.Count | Should -Be $items.Count
            ($plan | Where-Object UseCaseId -eq 'UC-0001').Mode | Should -Be 'Create'
            ($plan | Where-Object UseCaseId -eq 'UC-0001').ExistingWorkItemId | Should -Be 0
            ($plan | Where-Object UseCaseId -eq 'UC-0001').HyperlinkUrl | Should -Be 'https://github.com/urruegg/caldova-hr-frontier/blob/main/uc-0001-fixture-folder/uc-0001-fixture-folder.md'
        }

        It 'marks an idea Existing when the WIQL query returns exactly one matching work item' {
            $ideasRoot = New-FixtureIdeasRoot

            $plan = & $script:ScriptPath -TenantAlias 'caldova25156897' -IdeasRoot $ideasRoot -ReturnWorkItemPlanOnly `
                -AzureDevOpsRequest {
                    param($Operation, $Arguments)
                    switch ($Operation) {
                        'QueryWorkItemsByTag' {
                            if ([string]$Arguments['Tag'] -eq 'UC-0002') {
                                return [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = [pscustomobject]@{ workItems = @([pscustomobject]@{ id = 4242 }) } }
                            }
                            return [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = [pscustomobject]@{ workItems = @() } }
                        }
                        default { throw "Unexpected operation '$Operation' in this test." }
                    }
                }

            $uc0002Plan = $plan | Where-Object UseCaseId -eq 'UC-0002'
            $uc0002Plan.Mode | Should -Be 'Existing'
            $uc0002Plan.ExistingWorkItemId | Should -Be 4242
        }

        It 'throws a named ambiguous error when the WIQL query returns more than one matching work item' {
            $ideasRoot = New-FixtureIdeasRoot

            {
                & $script:ScriptPath -TenantAlias 'caldova25156897' -IdeasRoot $ideasRoot -ReturnWorkItemPlanOnly `
                    -AzureDevOpsRequest {
                        param($Operation, $Arguments)
                        [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = [pscustomobject]@{ workItems = @([pscustomobject]@{ id = 1 }, [pscustomobject]@{ id = 2 }) } }
                    }
            } | Should -Throw '*Ambiguous existing work items tagged*'
        }
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path infra/tests/pester/AzureBoardsPopulation.Tests.ps1 -Output Detailed`
Expected: FAIL — `-ReturnWorkItemPlanOnly` parameter does not exist.

- [ ] **Step 3: Implement**

Add a new parameter to the top `param()` block, after `[switch]$ReturnProcessCapabilitiesOnly,`:

```powershell
    [switch]$ReturnWorkItemPlanOnly,
```

Add the `QueryWorkItemsByTag` case to `New-DefaultAzureDevOpsRequest`'s `switch` statement (insert before the `default` case):

```powershell
            'QueryWorkItemsByTag' {
                $wiqlQuery = "SELECT [System.Id] FROM WorkItems WHERE [System.TeamProject] = '$([string]$Arguments['ProjectName'])' AND [System.WorkItemType] = 'Epic' AND [System.Tags] CONTAINS '$([string]$Arguments['Tag'])'"
                $wiqlBody = @{ query = $wiqlQuery } | ConvertTo-Json -Compress
                $tempFile = [System.IO.Path]::GetTempFileName()
                try {
                    [System.IO.File]::WriteAllText($tempFile, $wiqlBody)
                    return (Invoke-NativeJsonCommand -Runner $NativeRunner -FilePath 'az' -ArgumentList @(
                        'devops', 'invoke',
                        '--organization', [string]$Arguments['OrganizationUrl'],
                        '--area', 'wit',
                        '--resource', 'wiql',
                        '--route-parameters', "project=$([string]$Arguments['ProjectName'])",
                        '--http-method', 'POST',
                        '--in-file', $tempFile,
                        '--api-version', '7.1',
                        '--output', 'json'
                    ))
                }
                finally {
                    Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
                }
            }
```

Add the `Get-AzureDevOpsWorkItemPlan` function immediately after `Get-AzureDevOpsProcessCapabilities`'s closing `}`:

```powershell
function Get-AzureDevOpsWorkItemPlan {
    param(
        [Parameter(Mandatory)]
        [string]$OrganizationUrl,

        [Parameter(Mandatory)]
        [string]$ProjectName,

        [Parameter(Mandatory)]
        [object[]]$PortfolioItems,

        [Parameter(Mandatory)]
        [scriptblock]$Request
    )

    $plan = [System.Collections.Generic.List[object]]::new()
    foreach ($item in $PortfolioItems) {
        $response = & $Request 'QueryWorkItemsByTag' @{ OrganizationUrl = $OrganizationUrl; ProjectName = $ProjectName; Tag = $item.UseCaseId }
        $body = Get-ResponseBodyOrNull -Response $response
        $bodyTable = ConvertTo-Hashtable -InputObject $body
        $workItems = if ($bodyTable.ContainsKey('workItems')) { @($bodyTable['workItems']) } else { @() }

        $ids = @($workItems | ForEach-Object { [int](ConvertTo-Hashtable -InputObject $_)['id'] })
        if ($ids.Count -gt 1) {
            throw "Ambiguous existing work items tagged '$($item.UseCaseId)': ids $($ids -join ', ')."
        }

        $existingId = if ($ids.Count -eq 1) { $ids[0] } else { 0 }
        $mode = if ($existingId -gt 0) { 'Existing' } else { 'Create' }

        $plan.Add([pscustomobject]@{
            UseCaseId = $item.UseCaseId
            Title = $item.Title
            Status = $item.Status
            JourneyStage = $item.JourneyStage
            SourcePath = $item.SourcePath
            Summary = $item.Summary
            ExistingWorkItemId = $existingId
            Mode = $mode
            HyperlinkUrl = "https://github.com/urruegg/caldova-hr-frontier/blob/main/$($item.SourcePath)"
        }) | Out-Null
    }

    @($plan)
}
```

Replace the `if ($ReturnProcessCapabilitiesOnly) { ... }` block and the final `throw` line with:

```powershell
if ($ReturnProcessCapabilitiesOnly) {
    $capabilities = Get-AzureDevOpsProcessCapabilities -OrganizationUrl $organizationUrl -ProjectName $projectName -Request $azureDevOpsRequest
    Write-Output -NoEnumerate $capabilities
    return
}

if ($ReturnWorkItemPlanOnly) {
    $null = Get-AzureDevOpsProcessCapabilities -OrganizationUrl $organizationUrl -ProjectName $projectName -Request $azureDevOpsRequest
    $workItemPlan = Get-AzureDevOpsWorkItemPlan -OrganizationUrl $organizationUrl -ProjectName $projectName -PortfolioItems $portfolio -Request $azureDevOpsRequest
    Write-Output -NoEnumerate $workItemPlan
    return
}

throw 'Initialize-AzureDevOpsWorkItems.ps1: only -ReturnPortfolioOnly, -ReturnProcessCapabilitiesOnly, and -ReturnWorkItemPlanOnly are implemented so far (Tasks 1-3 of the implementation plan). Task 4 adds mutation.'
```

- [ ] **Step 4: Run test to verify it passes**

Run: `Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path infra/tests/pester/AzureBoardsPopulation.Tests.ps1 -Output Detailed`
Expected: PASS — all tests from Tasks 1-3 green (8 total).

- [ ] **Step 5: Commit**

```bash
git add infra/src/scripts/Initialize-AzureDevOpsWorkItems.ps1 infra/tests/pester/AzureBoardsPopulation.Tests.ps1
git commit -m "feat(infra): add Azure Boards Create/Existing plan computation"
```

---

### Task 4: Mutation and read-back verification

**Files:**
- Modify: `infra/src/scripts/Initialize-AzureDevOpsWorkItems.ps1`
- Modify: `infra/tests/pester/AzureBoardsPopulation.Tests.ps1`

**Interfaces:**
- Consumes: the plan array shape produced by Task 3.
- Produces: no new function — this task completes the script's main body so that, without `-WhatIf`, it creates each `Create`-mode plan item as a real Epic (`Title`, `Description` = `Summary`, `Tags` = `"<UseCaseId>; <Status>; <JourneyStage>"`) then adds the `Hyperlink` relation, then reads the item back and throws if `Title`/`Description`/`Tags`/the `Hyperlink` URL do not match; and, with `-WhatIf`, writes the plan to `-PlanOutputPath` (same temp-directory restriction as `Initialize-TenantTrust.ps1`) and performs zero mutation. Task 5 (the runbook) documents running this final behavior.

- [ ] **Step 1: Write the failing test**

Add this `Context` block after `Context 'Get-AzureDevOpsWorkItemPlan'`:

```powershell
    Context 'Initialize-AzureDevOpsWorkItems main body' {
        It 'performs zero mutation under -WhatIf and writes the plan to -PlanOutputPath' {
            $ideasRoot = New-FixtureIdeasRoot
            $planPath = Join-Path $TestDrive 'plan.json'
            $script:MutationCallCount = 0

            & $script:ScriptPath -TenantAlias 'caldova25156897' -IdeasRoot $ideasRoot -PlanOutputPath $planPath -WhatIf `
                -AzureDevOpsRequest {
                    param($Operation, $Arguments)
                    switch ($Operation) {
                        'QueryWorkItemsByTag' { [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = [pscustomobject]@{ workItems = @() } } }
                        default { $script:MutationCallCount++; throw "Unexpected mutating operation '$Operation' under -WhatIf." }
                    }
                }

            $script:MutationCallCount | Should -Be 0
            Test-Path -LiteralPath $planPath | Should -BeTrue
            $writtenPlan = Get-Content -Raw -LiteralPath $planPath | ConvertFrom-Json
            @($writtenPlan).Count | Should -Be 4
        }

        It 'creates a work item, adds the Hyperlink relation, and verifies the read-back when not -WhatIf' {
            $ideasRoot = New-FixtureIdeasRoot
            $script:CreatedFields = $null
            $script:RelationAdded = $null

            & $script:ScriptPath -TenantAlias 'caldova25156897' -IdeasRoot $ideasRoot -Confirm:$false `
                -AzureDevOpsRequest {
                    param($Operation, $Arguments)
                    switch ($Operation) {
                        'QueryWorkItemsByTag' { [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = [pscustomobject]@{ workItems = @() } } }
                        'CreateWorkItem' {
                            $script:CreatedFields = $Arguments
                            [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = [pscustomobject]@{ id = 9001 } }
                        }
                        'AddHyperlinkRelation' {
                            $script:RelationAdded = $Arguments
                            [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = $null }
                        }
                        'ShowWorkItem' {
                            [pscustomobject]@{
                                StatusCode = 200
                                Headers = @{}
                                Body = [pscustomobject]@{
                                    id = 9001
                                    fields = [pscustomobject]@{
                                        'System.Title' = [string]$script:CreatedFields['Title']
                                        'System.Description' = [string]$script:CreatedFields['Description']
                                        'System.Tags' = [string]$script:CreatedFields['Tags']
                                    }
                                    relations = @([pscustomobject]@{ rel = 'Hyperlink'; url = [string]$script:RelationAdded['Url'] })
                                }
                            }
                        }
                        default { throw "Unexpected operation '$Operation' in this test." }
                    }
                }

            $script:CreatedFields['Title'] | Should -Be 'Fixture MVP Selected'
            $script:CreatedFields['Tags'] | Should -Be 'UC-0001; MVP; Pre-board'
            $script:RelationAdded['Url'] | Should -Be 'https://github.com/urruegg/caldova-hr-frontier/blob/main/uc-0001-fixture-folder/uc-0001-fixture-folder.md'
        }

        It 'throws when the read-back does not match the plan' {
            $ideasRoot = New-FixtureIdeasRoot

            {
                & $script:ScriptPath -TenantAlias 'caldova25156897' -IdeasRoot $ideasRoot -Confirm:$false `
                    -AzureDevOpsRequest {
                        param($Operation, $Arguments)
                        switch ($Operation) {
                            'QueryWorkItemsByTag' { [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = [pscustomobject]@{ workItems = @() } } }
                            'CreateWorkItem' { [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = [pscustomobject]@{ id = 9001 } } }
                            'AddHyperlinkRelation' { [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = $null } }
                            'ShowWorkItem' {
                                [pscustomobject]@{
                                    StatusCode = 200
                                    Headers = @{}
                                    Body = [pscustomobject]@{
                                        id = 9001
                                        fields = [pscustomobject]@{ 'System.Title' = 'WRONG TITLE'; 'System.Description' = 'x'; 'System.Tags' = 'x' }
                                        relations = @()
                                    }
                                }
                            }
                            default { throw "Unexpected operation '$Operation' in this test." }
                        }
                    }
            } | Should -Throw '*read-back*'
        }
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path infra/tests/pester/AzureBoardsPopulation.Tests.ps1 -Output Detailed`
Expected: FAIL — the script currently throws its Task 3 placeholder error for any invocation without `-ReturnPortfolioOnly`/`-ReturnProcessCapabilitiesOnly`/`-ReturnWorkItemPlanOnly`.

- [ ] **Step 3: Implement**

Add the `CreateWorkItem`, `AddHyperlinkRelation`, and `ShowWorkItem` cases to `New-DefaultAzureDevOpsRequest`'s `switch` statement (insert before `default`):

```powershell
            'CreateWorkItem' {
                $patchBody = @(
                    @{ op = 'add'; path = '/fields/System.Title'; value = [string]$Arguments['Title'] }
                    @{ op = 'add'; path = '/fields/System.Description'; value = [string]$Arguments['Description'] }
                    @{ op = 'add'; path = '/fields/System.Tags'; value = [string]$Arguments['Tags'] }
                ) | ConvertTo-Json -Compress
                $tempFile = [System.IO.Path]::GetTempFileName()
                try {
                    [System.IO.File]::WriteAllText($tempFile, $patchBody)
                    return (Invoke-NativeJsonCommand -Runner $NativeRunner -FilePath 'az' -ArgumentList @(
                        'devops', 'invoke',
                        '--organization', [string]$Arguments['OrganizationUrl'],
                        '--area', 'wit',
                        '--resource', 'workitems',
                        '--route-parameters', "project=$([string]$Arguments['ProjectName'])", "type=$([string]$Arguments['WorkItemType'])",
                        '--http-method', 'POST',
                        '--in-file', $tempFile,
                        '--api-version', '7.1',
                        '--output', 'json'
                    ))
                }
                finally {
                    Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
                }
            }
            'AddHyperlinkRelation' {
                return (Invoke-NativeJsonCommand -Runner $NativeRunner -FilePath 'az' -ArgumentList @(
                    'boards', 'work-item', 'relation', 'add',
                    '--id', [string]$Arguments['WorkItemId'],
                    '--relation-type', 'Hyperlink',
                    '--target-url', [string]$Arguments['Url'],
                    '--organization', [string]$Arguments['OrganizationUrl'],
                    '--output', 'json'
                ))
            }
            'ShowWorkItem' {
                return (Invoke-NativeJsonCommand -Runner $NativeRunner -FilePath 'az' -ArgumentList @(
                    'boards', 'work-item', 'show',
                    '--id', [string]$Arguments['WorkItemId'],
                    '--expand', 'all',
                    '--organization', [string]$Arguments['OrganizationUrl'],
                    '--output', 'json'
                ))
            }
```

Add this assertion helper immediately after `Get-AzureDevOpsWorkItemPlan`'s closing `}`:

```powershell
function Assert-WorkItemReadBack {
    param(
        [Parameter(Mandatory)]
        [object]$ReadBack,

        [Parameter(Mandatory)]
        [string]$ExpectedTitle,

        [Parameter(Mandatory)]
        [string]$ExpectedDescription,

        [Parameter(Mandatory)]
        [string]$ExpectedTags,

        [Parameter(Mandatory)]
        [string]$ExpectedHyperlinkUrl
    )

    $readBackTable = ConvertTo-Hashtable -InputObject $ReadBack
    $fields = ConvertTo-Hashtable -InputObject $readBackTable['fields']
    if ([string]$fields['System.Title'] -cne $ExpectedTitle) {
        throw "Work item read-back Title mismatch: expected '$ExpectedTitle', observed '$([string]$fields['System.Title'])'."
    }
    if ([string]$fields['System.Description'] -cne $ExpectedDescription) {
        throw "Work item read-back Description mismatch: expected '$ExpectedDescription', observed '$([string]$fields['System.Description'])'."
    }
    if ([string]$fields['System.Tags'] -cne $ExpectedTags) {
        throw "Work item read-back Tags mismatch: expected '$ExpectedTags', observed '$([string]$fields['System.Tags'])'."
    }

    $relations = if ($readBackTable.ContainsKey('relations')) { @($readBackTable['relations']) } else { @() }
    $hyperlinkMatch = @($relations | Where-Object {
        $relationTable = ConvertTo-Hashtable -InputObject $_
        [string]$relationTable['rel'] -ceq 'Hyperlink' -and [string]$relationTable['url'] -ceq $ExpectedHyperlinkUrl
    })
    if ($hyperlinkMatch.Count -eq 0) {
        throw "Work item read-back is missing the expected Hyperlink relation to '$ExpectedHyperlinkUrl'."
    }
}
```

Replace the final `throw` line (`throw 'Initialize-AzureDevOpsWorkItems.ps1: only -ReturnPortfolioOnly, -ReturnProcessCapabilitiesOnly, and -ReturnWorkItemPlanOnly are implemented so far...`) with:

```powershell
$workItemPlan = Get-AzureDevOpsWorkItemPlan -OrganizationUrl $organizationUrl -ProjectName $projectName -PortfolioItems $portfolio -Request $azureDevOpsRequest

if ($PlanOutputPath) {
    $resolvedPlanOutputPath = [System.IO.Path]::GetFullPath($PlanOutputPath)
    $allowedRoots = @([System.IO.Path]::GetTempPath())
    if (-not [string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)) {
        $allowedRoots += [System.IO.Path]::GetFullPath($env:RUNNER_TEMP)
    }
    $isAllowed = $false
    foreach ($root in $allowedRoots) {
        $normalizedRoot = [System.IO.Path]::GetFullPath($root).TrimEnd('\') + '\'
        if ($resolvedPlanOutputPath.StartsWith($normalizedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            $isAllowed = $true
            break
        }
    }
    if (-not $isAllowed) {
        throw 'PlanOutputPath must resolve under the system temporary directory or RUNNER_TEMP.'
    }

    $workItemPlan | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $resolvedPlanOutputPath -Encoding utf8NoBOM
}

if ($WhatIfPreference) {
    Write-Output -NoEnumerate $workItemPlan
    return
}

foreach ($planItem in $workItemPlan) {
    if ($planItem.Mode -cne 'Create') {
        continue
    }

    $target = "$($planItem.UseCaseId) ($($planItem.Title))"
    if (-not $PSCmdlet.ShouldProcess($target, 'CreateAzureBoardsEpic')) {
        throw "Azure Boards Epic creation for '$target' was declined."
    }

    $tags = "$($planItem.UseCaseId); $($planItem.Status); $($planItem.JourneyStage)"
    $createResponse = & $azureDevOpsRequest 'CreateWorkItem' @{
        OrganizationUrl = $organizationUrl
        ProjectName = $projectName
        WorkItemType = 'Epic'
        Title = $planItem.Title
        Description = $planItem.Summary
        Tags = $tags
    }
    $createdBody = Get-ResponseBodyOrNull -Response $createResponse
    $createdId = [int](ConvertTo-Hashtable -InputObject $createdBody)['id']
    if ($createdId -le 0) {
        throw "Azure Boards Epic creation for '$target' did not return a valid work item id."
    }

    $null = & $azureDevOpsRequest 'AddHyperlinkRelation' @{
        OrganizationUrl = $organizationUrl
        WorkItemId = $createdId
        Url = $planItem.HyperlinkUrl
    }

    $readBackResponse = & $azureDevOpsRequest 'ShowWorkItem' @{ OrganizationUrl = $organizationUrl; WorkItemId = $createdId }
    $readBackBody = Get-ResponseBodyOrNull -Response $readBackResponse
    Assert-WorkItemReadBack -ReadBack $readBackBody -ExpectedTitle $planItem.Title -ExpectedDescription $planItem.Summary -ExpectedTags $tags -ExpectedHyperlinkUrl $planItem.HyperlinkUrl
}

Write-Output -NoEnumerate $workItemPlan
```

- [ ] **Step 4: Run test to verify it passes**

Run: `Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path infra/tests/pester/AzureBoardsPopulation.Tests.ps1 -Output Detailed`
Expected: PASS — all tests from Tasks 1-4 green (11 total).

- [ ] **Step 5: Run the full infra and hr Pester suites (regression check)**

Run: `Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path @('infra/tests/pester','hr/tests/pester') -Output Detailed -CI`
Expected: PASS — no new failures beyond any pre-existing, unrelated ones already present on `main` (e.g. Bicep tests requiring a local `az`/`bicep` toolchain not installed in this sandbox).

- [ ] **Step 6: Commit**

```bash
git add infra/src/scripts/Initialize-AzureDevOpsWorkItems.ps1 infra/tests/pester/AzureBoardsPopulation.Tests.ps1
git commit -m "feat(infra): add Azure Boards Epic creation with read-back verification"
```

---

### Task 5: Operator runbook

**Files:**
- Create: `infra/docs/21-azure-boards-population-runbook.md`

**Interfaces:**
- Consumes: `infra/src/scripts/Initialize-AzureDevOpsWorkItems.ps1` (Tasks 1-4, unmodified by this task) — parameters `-TenantAlias <string>` (mandatory), `-IdeasRoot <string>` (optional, defaults to this repository's real `hr/docs/ideas`), `-PlanOutputPath <string>` (optional, temp-directory-restricted), `-WhatIf`.
- Produces: nothing consumed by later tasks — this is the last task in the plan.

- [ ] **Step 1: Confirm the full test suite is green**

Run: `Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path infra/tests/pester/AzureBoardsPopulation.Tests.ps1 -Output Detailed`
Expected: PASS — 11/11 tests green. If not, STOP and report BLOCKED rather than writing the runbook.

- [ ] **Step 2: Write the runbook**

Create `infra/docs/21-azure-boards-population-runbook.md`:

```markdown
# Azure Boards Population Runbook

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-25 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Infrastructure (Tenant 1) |
| **References** | [Azure Boards Population Design](../../docs/specs/2026-09-25-azure-boards-population-design.md), [Tenant Trust Activation Runbook](../../infra/docs/20-tenant-trust-activation-runbook.md) |

This runbook populates Azure DevOps Boards with one `Epic` per HR use-case idea (19 total), using `infra/src/scripts/Initialize-AzureDevOpsWorkItems.ps1`. It assumes Tenant 1's trust is already active — see the [Tenant Trust Activation Runbook](../../infra/docs/20-tenant-trust-activation-runbook.md) — and that you have an authenticated Azure DevOps session (either the same OIDC trust that runbook establishes, or your own `az devops login`).

## Who Can Run This

- **Azure DevOps role:** at least **Contributor** on the `Caldova HR Frontier` project — enough to create work items and add relations; no administrative role is required.
- **Content judgment:** this script only ever copies text already reviewed and committed in `hr/docs/ideas/*.md` into Azure Boards — it never generates new characterizations of a use case. Even so, a human should trigger the first live write of this portfolio into a system other people at GF will read as authoritative — see the spec's Runbook section for why.

## Prerequisites Checklist

- [ ] `az` CLI is installed with the `azure-devops` extension (`az extension add --name azure-devops` if `az boards -h` reports the command group is missing).
- [ ] You are authenticated to Azure DevOps for organization `https://dev.azure.com/caldova25156897/` (`az devops login` or an already-active OIDC session).
- [ ] `Invoke-Pester -Path infra/tests/pester/AzureBoardsPopulation.Tests.ps1 -Output Detailed -CI` passes on the current `main` before you begin.

## Steps

1. **Review the plan with zero mutation.**

   ```powershell
   $planPath = Join-Path $env:TEMP 'azure-boards-population-plan.json'
   .\infra\src\scripts\Initialize-AzureDevOpsWorkItems.ps1 -TenantAlias caldova25156897 -PlanOutputPath $planPath -WhatIf
   Get-Content -Raw $planPath | ConvertFrom-Json | Format-Table UseCaseId, Title, Status, JourneyStage, Mode, ExistingWorkItemId -AutoSize
   ```

   Confirm all 19 ideas appear, and that the `Mode` column matches what you expect (`Create` for every idea the first time this runs; `Existing` for any idea already tagged in Azure Boards on a later run).

2. **Execute the plan.**

   ```powershell
   .\infra\src\scripts\Initialize-AzureDevOpsWorkItems.ps1 -TenantAlias caldova25156897 -PlanOutputPath $planPath
   ```

   PowerShell's default confirmation preference (`High`, matching the script's declared `ConfirmImpact = 'High'`) prompts once per `Create`-mode Epic before creating it. Answer `Y` for each one you approve; never answer `A` ("Yes to All") — the same reasoning as the [Tenant Trust Activation Runbook](../../infra/docs/20-tenant-trust-activation-runbook.md) Step 3 applies here too: a single blanket approval silently skips reviewing the remaining items.

3. **Handle a partial failure.**

   If the script fails partway through (for example, item 12 of 19 fails a read-back check), re-run the exact command from Step 2. Every idea already created is now tagged and will be found by the WIQL query on the next run, so it reports as `Existing` and is skipped — only the remaining `Create`-mode ideas are attempted.

4. **Prove population with a final read-back.**

   ```powershell
   .\infra\src\scripts\Initialize-AzureDevOpsWorkItems.ps1 -TenantAlias caldova25156897 -PlanOutputPath $planPath -WhatIf
   Get-Content -Raw $planPath | ConvertFrom-Json | Where-Object Mode -ne 'Existing'
   ```

   Expect no output from the last line — every idea should now show `Mode = 'Existing'` with a populated `ExistingWorkItemId`.

## What This Runbook Does Not Do

| Not covered here | Where it lives instead |
|---|---|
| Creating Features, User Stories, Tasks, or Bugs under any Epic | Deliberately out of scope — see the spec's Ruling 1; only `UC-0001` has a PRD, and even its Definition of Ready is not yet met |
| Azure DevOps project configuration (area paths, iterations, delivery plans, Azure Repos repurposing) | Tracked as a separate, not-yet-started sub-project |
| The Azure Boards↔GitHub App connection and the `AB#` commit convention | Attended-only (one-time browser OAuth); see `docs/specs/2026-09-24-azure-devops-github-single-source-of-truth-design.md` |
| Activating Tenant 1's trust in the first place | [Tenant Trust Activation Runbook](../../infra/docs/20-tenant-trust-activation-runbook.md) — must already be complete before this runbook can authenticate |

## Troubleshooting

- **`Azure DevOps project '...' has no 'Epic' work item type.`** The project's process template does not name its top-level backlog item `Epic`. Confirm the actual process (`az devops invoke --area core --resource projects --route-parameters project=... --query-parameters includeCapabilities=true --api-version 7.1`) and treat this as a plan defect to escalate, not something to work around by picking a different type name yourself.
- **`Ambiguous existing work items tagged '...'.`** More than one existing work item carries the same `UC-nnnn` tag. Resolve manually in Azure Boards (retag or close the duplicate) before re-running — this script never guesses which one is authoritative.
- **A read-back mismatch error immediately after a successful-looking creation.** The created work item's `Title`/`Description`/`Tags`/`Hyperlink` do not exactly match what was requested — a stale cached response, a transient service issue, or a real Azure DevOps API bug in this batch. Re-run the exact command from Step 2; the offending item shows `Mode = 'Create'` again on the next plan review.
```

- [ ] **Step 3: Verify the documentation metadata check passes**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .github/cli/verify-repository-setup.ps1 -SkipIntegratedTests -SkipBicepBuild`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add infra/docs/21-azure-boards-population-runbook.md
git commit -m "docs(infra): add Azure Boards population runbook"
```

---

## Out of Scope (Attended Human Action)

Actually running this runbook against live Tenant 1 Azure Boards is not performed by this plan — it is the human's own attended action, once Tenant 1's trust is active (per `infra/docs/20-tenant-trust-activation-runbook.md`) and they are ready to review the first live write of the portfolio into a system others at GF will read as authoritative.
