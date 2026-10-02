# Caldova Branding Migration Implementation Plan

| Field | Value |
|---|---|
| **Version** | 1.3 |
| **Date** | 2026-10-01 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Draft |
| **Scope** | Current tracked repository tree branding migration |
| **References** | [Approved Caldova Branding Migration Design](../specs/2026-10-01-caldova-branding-migration-design.md) |

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the legacy customer identity from the maintained repository and present Caldova consistently in tracked prose, identifiers, paths, generated documents, tests, and catalogues without changing technical meaning, synthetic truth, accessibility semantics, or immutable review evidence.

**Architecture:** One fail-closed PowerShell module owns Git-index enumeration, path classification, strict text decoding, L1-L7 matching, and exact immutable-evidence manifest validation; its Pester suite is the maintained current-tree contract, so operational checks and tests never duplicate scanner logic. The migration then renames brand and corpus assets before repairing consumers, scrubs current prose by owning domain, updates both generator copies, regenerates all 48 corpus PDFs through their maintained entry points, and closes with the complete local acceptance set. Generated review evidence, seven hash-bound AI Builder source-evidence files, seven immutable AI Builder input PDFs, and the six already-sanitized screenshots remain immutable, while their bytes are compared directly with the applicable baseline.

**Tech Stack:** Windows PowerShell 5.1, Pester 5.7.1, Git, Python 3, ReportLab, local `pypdf`, React 19, TypeScript 5.9, Fluent UI React Components 9, Vite 7, ESLint 9, npm, Bicep CLI.

**Spec:** [`docs/specs/2026-10-01-caldova-branding-migration-design.md`](../specs/2026-10-01-caldova-branding-migration-design.md)

## Global Constraints

- The migration is one repository change on one feature branch and is small enough for one implementation plan. A later implementation plan may sequence the approved work but may not widen this design.
- Every path and file tracked at the baseline commit, plus every migration artifact added on the feature branch, including maintained source, tests, generators, synthetic data, generated PDFs, application labels, mockups, catalogues, and repository-owned Markdown.
- Current documents are scrubbed without changing their approval state, supersession state, evidential meaning, stable requirement identifiers, or architectural decisions.
- Descriptions of original external source files become neutral descriptions, such as “the customer-supplied use-case workbook” or “the source Workday presentation.”
- Repository text must not state or imply that an external file, backup, or source package was renamed.
- Partial aliasing is not allowed because it would preserve two active brand vocabularies.
- The inherited palette is an **interim product palette pending an approved Caldova design standard**.
- This branding migration renames tokens and reframes provenance; it does not change colour values. Existing contrast and semantic-state behavior are preserved unless a separate approved design explicitly authorizes colour changes.
- Generators use a fictional Caldova entity and a clearly fictional, non-customer address.
- Synthetic-person disclaimers and candidate truth data remain intact.
- Generator output, checked-in PDFs, and checked-in truth data must agree. Hand-editing generated PDFs is not an acceptable migration method.
- The six sanitized Azure DevOps screenshots remain byte-for-byte unchanged because they already display Caldova only. Their hashes are compared with the baseline commit during acceptance. Historical generated review evidence is also unchanged.
- An ambiguous `L3`, identifier, or prefix transformation stops the migration until its context and disposition are recorded in the implementation review.
- A generator failure, PDF read failure, page text-extraction failure, or generator/truth mismatch blocks acceptance.
- No scanner, generator, or verifier may convert an error into a warning or silently skip a file.
- An unexpected binary change, screenshot hash change, symlink, broken link, or rename without a matching reference update is reported explicitly and blocks completion.
- A count discrepancy triggers a fresh inventory and explanation; counts are not adjusted merely to make acceptance pass.
- Git history rewriting, including rebases or filter-based removal of old content.
- Backups, local session artifacts, ignored files, other worktrees, remote systems, and external source files.
- Generated review evidence, including manifests and test-result evidence, and the six sanitized Azure DevOps screenshots.
- Live systems, tenant configuration, infrastructure mutation, application deployment, and remote repository changes.

The last four bullets are prohibitions. Execute only in `C:\Users\urruegg\source\urruegg\caldova-hr-frontier\.worktrees\caldova-branding-migration` on branch `feat/caldova-branding-migration-implementation`, descended from approved base `ba35a098e058a51425c5e6052912bda4d04864be` through the controller's plan/catalogue commit. Do not create another branch or worktree. Every task uses red/green/refactor, receives a focused diff review, and creates one scoped commit with `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>`.

---

## Post-Baseline `origin/main` Integration Amendment

After the eight migration tasks completed, `origin/main` advanced to `402f42ff01e662dcb6762d44e9a5fec09b3484cd` with the governed AI Builder evaluation subsystem. Integrate that commit with `git merge --no-ff --no-commit origin/main`; do not rebase, squash, rewrite history, push, or touch a live system. Preserve all current-main evidence contracts and behavior while applying the completed Caldova names and `caldova-aib-*` package paths to mutable additions.

Seven new-main files remain byte-for-byte immutable:

- three raw model-response JSON files recorded by the training-proof and fixed-holdout captures, each with one `L3` OCR occurrence;
- `evaluation-summary.md`, with one `L4` occurrence; and
- `training-capture-attempt.json`, `training-capture-remediation.json`, and `training-capture-retry.json`, each with one `L4` occurrence.

Their live-model output cannot be rewritten truthfully without a separately authorized rerun. The tracked `.github/cli/config/branding-evidence-exceptions.json` therefore records exactly those seven normalized paths, lowercase SHA-256 values, declared classes, count `1`, provenance, and rationale. The one BrandingContract module loads that repository manifest by default and validates exact schema, no extra properties, unique normalized paths, exact evidence root, tracked regular-file mode, hash, class, count, and absence of extra matches. A declared exception path must itself contain no `L1`-`L7` match; approval is content-only and never suppresses a path finding. A malformed, missing, untracked, out-of-root, duplicate, drifted, or mismatched record fails closed without exposing matched content. Fixture scans use their own fixture manifest or the explicit manifest parameter; they never fall back to another repository.

No broad scanner exception exists. Every mutable match in the integrated plans, HR guidance, BoMs, scripts, tests, fixtures, and evidence README is migrated. Acceptance is zero unapproved `Findings`, exactly seven `ApprovedEvidence` entries, `ApprovedEvidenceCount = 7`, complete tracked accounting, and byte equality between all seven evidence files and `origin/main`.

The integrated PDF inventory is exactly 55: 48 generated corpus PDFs below the two exact `caldova-aib-*` document roots, 7 point-in-time input PDFs below `hr/evidence/ai-builder/`, and no others. Corpus PDFs must be readable and free of prohibited embedded matches. Evidence PDFs may retain historical branding because they are immutable inputs; acceptance reports their historical match classes and counts and requires all seven to be readable plus byte-identical by Git blob and SHA-256 to `402f42ff01e662dcb6762d44e9a5fec09b3484cd`.

---

## Execution Baseline

Run this once before Task 1:

```powershell
$ErrorActionPreference = 'Stop'
$RepoRoot = 'C:\Users\urruegg\source\urruegg\caldova-hr-frontier\.worktrees\caldova-branding-migration'
$ApprovedBase = 'ba35a098e058a51425c5e6052912bda4d04864be'
$InventoryBaseline = '63e7900edd431cc810a8396a24b19c17ef4999d1'
Set-Location -LiteralPath $RepoRoot

if ((git branch --show-current).Trim() -cne 'feat/caldova-branding-migration-implementation') {
    throw 'Wrong implementation branch.'
}
if (@(git status --porcelain=v1).Count -ne 0) {
    throw 'The implementation worktree must be clean.'
}
$ImplementationBase = (git rev-parse HEAD).Trim()
$mergeBase = (git merge-base $ApprovedBase $ImplementationBase).Trim()
if ($mergeBase -cne $ApprovedBase) {
    throw 'The committed plan does not descend from the approved base.'
}
$preImplementationChanges = @(
    git diff --name-only $ApprovedBase $ImplementationBase
)
$expectedPlanChanges = @(
    'docs/plans/2026-10-01-caldova-branding-migration-implementation.md'
    'docs/plans/README.md'
)
if (@(Compare-Object $expectedPlanChanges $preImplementationChanges).Count -ne 0) {
    Compare-Object $expectedPlanChanges $preImplementationChanges |
        Format-Table -AutoSize
    throw 'Only the controller-committed plan and catalogue may precede implementation.'
}
Import-Module Pester -RequiredVersion 5.7.1 -Force
```

Expected: the branch, approved ancestry, controller-committed plan/catalogue, clean worktree, and exact Pester version are confirmed without changing repository or external state. `$ImplementationBase` is the controller's plan commit and is the parent boundary for the eight implementation commits. If Pester 5.7.1, Python, ReportLab, or local `pypdf` is unavailable, stop and report the missing prerequisite; this plan does not add or install a dependency.

The approved pre-design inventory at `$InventoryBaseline` is:

| Surface | Baseline evidence |
|---|---:|
| Tracked files | 475 |
| Lines containing L1 or L2 | 33 lines across 16 text files |
| Lines containing customer-use L3 | 476 lines across 72 text files |
| Lines containing L4 or L5 | 325 lines across 30 files |
| Branded tracked paths | 64 |
| Tracked PDFs below branded paths | 48 |
| PDFs containing embedded legacy full-name text | 24 |
| Sanitized Azure DevOps screenshots already showing Caldova only | 6 |

These categories overlap and are not additive occurrence counts. A discrepancy is investigated against the approved baseline; it is never normalized away.

## File Structure and Producer/Consumer Boundaries

| Path or exact set | Responsibility |
|---|---|
| `.github/cli/modules/BrandingContract.psm1` | The only L1-L7 scanner implementation: Git-index enumeration, strict decoding, explicit text/binary/link classification, and path/class-only findings. |
| `.github/cli/tests/BrandingContract.Tests.ps1` | Maintained contract and fixture tests for the scanner; the full-repository assertion starts RED and ends GREEN. |
| `docs/brand/caldova-fluent-theme.ts` | Canonical Fluent theme asset after the rename. |
| `docs/brand/caldova-tokens.css` | Canonical CSS token asset after the rename. |
| `hr/tests/pester/HrControlPlaneBranding.Tests.ps1` | Static target-name, symbol, palette, app-label, CSS-prefix, and mockup contract. |
| `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/caldova-aib-fixed-template/` | Renamed 24-document fixed-template corpus, truth, guidance, and generator copy. |
| `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/caldova-aib-general-documents/` | Renamed 24-document general-document corpus, truth, guidance, and generator copy. |
| `hr/tests/pester/AiBuilderCorpus.Tests.ps1` | Target-path, package-shape, truth-equivalence, maintained-entry-point, and fictional-entity contract. |
| Scanner findings under `README.md`, `AGENTS.md`, `.github/`, `data/`, and `infra/` | Exact Task 4 prose/source set; vendored skills, licenses, and generated evidence are blocked rather than edited. |
| Scanner findings under `docs/`, excluding `docs/brand/` already completed in Task 2 and immutable files under `docs/reviews/evidence/` | Exact Task 5 ADR/spec/plan/review/catalogue prose set. |
| Scanner findings under `hr/`, excluding app files completed in Task 2 and the eight generator files reserved for Task 7 | Exact Task 6 HR guidance, use-case, static source, and source-label set. |
| The eight `generators/*.py` files below the two renamed packages and all 48 package PDFs | Task 7 generator and generated-output set. |
| Existing contracts that identify renamed paths, exact prose, or hashes | Task 8 repair set, discovered by the complete Pester run and changed only when the underlying reviewed target changed. |

The scanner output makes the prose sets exact at execution time: each finding has only `Path` and `PatternClass`. Tasks filter that complete result by the boundaries above, print the sorted paths before editing, and fail if a prohibited match appears in an excluded or immutable path. This is not an allowlist in the maintained contract; the final contract always scans the complete Git-tracked tree.

## Acceptance-Criteria Map

| Design requirement or acceptance criterion | Implemented and proved in |
|---|---|
| Git-tracked, fail-closed L1-L7 path/text contract with indirect pattern construction and no broad allowlist | Tasks 1 and 8 |
| Brand assets, duplicated app theme, labels, CSS, TypeScript, prefixes, palette, accessibility, lint, and build | Task 2; rerun in Task 8 |
| Both package-directory renames and every path/link/test/generator/catalogue/safety consumer | Task 3; references rechecked in Task 8 |
| Root, `.github`, data, infrastructure, ADR, spec, plan, review, README, HR, and source prose scrub with neutral external-source descriptions | Tasks 4-6 |
| Generated review evidence unchanged and six screenshot SHA-256 values equal baseline | Tasks 4 and 8 |
| Fictional Caldova entity/address, unchanged disclaimers/person truth/candidate data, 48 regenerated PDFs, semantic reproducibility | Task 7 |
| Exactly 48 readable PDFs, zero extraction errors, and zero legacy matches | Tasks 7 and 8 |
| Metadata, links, repository safety, all maintained tests, conditional five Bicep builds, whitespace, final diff | Task 8 |
| No live-system, deployment, history-rewrite, external-source, screenshot-edit, or session-artifact action | Global constraints and every task |

### Task 1: Add the Fail-Closed Branding Contract and Establish RED

**Files:**
- Create: `.github/cli/modules/BrandingContract.psm1`
- Create: `.github/cli/tests/BrandingContract.Tests.ps1`

**Interfaces:**
- Consumes: Git index entries from `git ls-files -z --stage`; repository bytes only.
- Produces: `Get-RepositoryBrandingScan -RepositoryRoot $RepoRoot` returning one object with integer `TrackedCount`, `TextCount`, `BinaryCount`, and `LinkCount`; `Files` entries with string `Path` and `Classification`; and `Findings` entries with string `Path` and `PatternClass`.
- Produces: exact match classes `L1` through `L7`; fail-closed classes `git-error`, `index-record-error`, `index-stage-error`, `path-error`, `read-error`, `classification-error`, `tracked-link`, and `unsupported-tracked-mode`.
- Consumer rule: Tasks 2-8 import this module. No task reimplements its patterns, decoding, binary signatures, symlink policy, or Git enumeration.

The focused module belongs in `.github\cli\modules` because fixture tests, domain-slice checks, and final acceptance all need the same scanner. The Pester file remains the maintained current-tree contract. There is no second CLI scanner and no duplicated matching logic.

- [ ] **Step 1: Write the scanner fixture tests first**

Create `.github/cli/tests/BrandingContract.Tests.ps1` with these fixture helpers and assertions:

```powershell
Set-StrictMode -Version Latest

BeforeAll {
    $script:repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
    $script:modulePath = Join-Path $script:repositoryRoot '.github\cli\modules\BrandingContract.psm1'
    Import-Module $script:modulePath -Force
    $script:gitPath = @(
        (Get-Command git.exe -CommandType Application -ErrorAction SilentlyContinue |
            Select-Object -First 1).Source
        'C:\Program Files\Git\cmd\git.exe'
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) } |
        Select-Object -First 1
    if (-not $script:gitPath) { throw 'git.exe is required.' }

    $first = -join [char[]](71, 101, 111, 114, 103)
    $second = -join [char[]](70, 105, 115, 99, 104, 101, 114)
    $initials = $first[0] + $second[0]
    $script:forms = [ordered]@{
        L1 = $first + ' ' + $second
        L2 = $first + $second
        L3 = $initials
        L4 = $initials.ToLowerInvariant() + '-'
        L5 = $initials.ToLowerInvariant() + '_'
        L6 = $initials.ToLowerInvariant() + 'Brand'
        L7 = $initials[0] + $initials[1].ToString().ToLowerInvariant() + 'Brand'
    }

    function script:New-BrandingFixture {
        $root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        [void](New-Item -ItemType Directory -Path $root)
        & $script:gitPath -C $root init --quiet
        if ($LASTEXITCODE -ne 0) { throw 'Cannot initialize fixture repository.' }
        $root
    }

    function script:Add-FixtureText {
        param(
            [Parameter(Mandatory)][string]$Root,
            [Parameter(Mandatory)][string]$RelativePath,
            [Parameter(Mandatory)][AllowEmptyString()][string]$Content
        )
        $path = Join-Path $Root $RelativePath
        [void](New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force)
        [IO.File]::WriteAllText($path, $Content, [Text.UTF8Encoding]::new($false))
        & $script:gitPath -C $Root add -- $RelativePath.Replace('\', '/')
        if ($LASTEXITCODE -ne 0) { throw "Cannot stage fixture: $RelativePath" }
    }
}

Describe 'Branding scanner behavior' -Tag 'BrandingContractUnit' {
    It 'finds every prohibited class in tracked paths and tracked text without returning matched content' {
        $root = New-BrandingFixture
        foreach ($entry in $script:forms.GetEnumerator()) {
            Add-FixtureText -Root $root `
                -RelativePath ("paths\{0}\safe.txt" -f $entry.Value) `
                -Content 'safe'
            Add-FixtureText -Root $root `
                -RelativePath ("text\{0}.txt" -f $entry.Key) `
                -Content ("before {0} after" -f $entry.Value)
        }
        [IO.File]::WriteAllText(
            (Join-Path $root 'untracked.txt'),
            $script:forms.L1,
            [Text.UTF8Encoding]::new($false)
        )

        $result = Get-RepositoryBrandingScan -RepositoryRoot $root

        foreach ($label in $script:forms.Keys) {
            @($result.Findings | Where-Object PatternClass -ceq $label).Count |
                Should -BeGreaterOrEqual 2
        }
        foreach ($finding in $result.Findings) {
            $finding.PSObject.Properties.Name |
                Should -Be @('Path', 'PatternClass')
        }
        $result.Findings.Path | Should -Not -Contain 'untracked.txt'
    }

    It 'scans text by bytes and strict UTF-8 rather than by an extension allowlist' {
        $root = New-BrandingFixture
        foreach ($extension in @('.md', '.ps1', '.ts', '.xyz')) {
            Add-FixtureText -Root $root `
                -RelativePath ("content\sample{0}" -f $extension) `
                -Content $script:forms.L1
        }

        $result = Get-RepositoryBrandingScan -RepositoryRoot $root

        @($result.Findings | Where-Object PatternClass -ceq 'L1').Count | Should -Be 4
        @($result.Files | Where-Object Classification -ceq 'tracked-text').Count |
            Should -Be 4
    }

    It 'classifies a signature-proven binary explicitly and does not decode it as text' {
        $root = New-BrandingFixture
        $path = Join-Path $root 'image.bin'
        [IO.File]::WriteAllBytes(
            $path,
            [byte[]](137, 80, 78, 71, 13, 10, 26, 10, 0, 255, 1, 2)
        )
        & $script:gitPath -C $root add -- 'image.bin'

        $result = Get-RepositoryBrandingScan -RepositoryRoot $root

        $result.BinaryCount | Should -Be 1
        @($result.Files | Where-Object Path -ceq 'image.bin').Classification |
            Should -BeExactly 'tracked-binary'
        $result.Findings | Should -BeNullOrEmpty
    }

    It 'fails closed on undecodable unclassified bytes and a missing tracked file' {
        $root = New-BrandingFixture
        $bad = Join-Path $root 'bad-text.dat'
        [IO.File]::WriteAllBytes($bad, [byte[]](195, 40))
        & $script:gitPath -C $root add -- 'bad-text.dat'
        Add-FixtureText -Root $root -RelativePath 'missing.txt' -Content 'safe'
        Remove-Item -LiteralPath (Join-Path $root 'missing.txt') -Force

        $result = Get-RepositoryBrandingScan -RepositoryRoot $root

        $result.Findings |
            Where-Object { $_.Path -ceq 'bad-text.dat' } |
            Select-Object -ExpandProperty PatternClass |
            Should -Contain 'classification-error'
        $result.Findings |
            Where-Object { $_.Path -ceq 'missing.txt' } |
            Select-Object -ExpandProperty PatternClass |
            Should -Contain 'read-error'
    }

    It 'fails closed when Git enumeration cannot run' {
        $notARepository = Join-Path $TestDrive 'not-a-repository'
        [void](New-Item -ItemType Directory -Path $notARepository)

        { Get-RepositoryBrandingScan -RepositoryRoot $notARepository } |
            Should -Throw '*git-error*'
    }

    It 'classifies a staged link record as blocking rather than following its target' {
        $record = [Text.UTF8Encoding]::new($false).GetBytes(
            "120000 0123456789012345678901234567890123456789 0`tlink`0"
        )

        InModuleScope BrandingContract -Parameters @{ Bytes = $record } {
            param($Bytes)
            $entries = ConvertFrom-BrandingGitIndexBytes -Bytes $Bytes
            $entries.Count | Should -Be 1
            $entries[0].Mode | Should -BeExactly '120000'
            $entries[0].Path | Should -BeExactly 'link'
        }
    }
}

Describe 'Current repository branding' {
    It 'contains no prohibited tracked path or scannable tracked text' {
        $result = Get-RepositoryBrandingScan -RepositoryRoot $script:repositoryRoot

        $result.Findings | Sort-Object Path, PatternClass |
            Should -BeNullOrEmpty
    }
}
```

- [ ] **Step 2: Run the fixture tests and verify the missing-module RED**

```powershell
Invoke-Pester -Path '.github\cli\tests\BrandingContract.Tests.ps1' `
    -Tag 'BrandingContractUnit' -Output Detailed
```

Expected: FAIL because `.github\cli\modules\BrandingContract.psm1` does not exist.

- [ ] **Step 3: Implement the single scanner**

Create `.github/cli/modules/BrandingContract.psm1`. The implementation must use this structure; keep pattern construction in `New-BrandingPatternSet` and nowhere else:

```powershell
Set-StrictMode -Version Latest

function New-BrandingPatternSet {
    $first = -join [char[]](71, 101, 111, 114, 103)
    $second = -join [char[]](70, 105, 115, 99, 104, 101, 114)
    $initials = $first[0] + $second[0]
    $ignoreCase = [Text.RegularExpressions.RegexOptions]::IgnoreCase -bor
        [Text.RegularExpressions.RegexOptions]::CultureInvariant
    $caseSensitive = [Text.RegularExpressions.RegexOptions]::CultureInvariant

    [ordered]@{
        L1 = [regex]::new(
            [regex]::Escape($first + ' ' + $second),
            $ignoreCase
        )
        L2 = [regex]::new(
            [regex]::Escape($first + $second),
            $ignoreCase
        )
        L3 = [regex]::new(
            ('(?<![A-Za-z0-9]){0}(?![A-Za-z0-9])' -f
                [regex]::Escape($initials)),
            $ignoreCase
        )
        L4 = [regex]::new(
            ('(?<![A-Za-z0-9]){0}-' -f
                [regex]::Escape($initials.ToLowerInvariant())),
            $ignoreCase
        )
        L5 = [regex]::new(
            ('(?<![A-Za-z0-9]){0}_' -f
                [regex]::Escape($initials.ToLowerInvariant())),
            $ignoreCase
        )
        L6 = [regex]::new(
            ('(?<![A-Za-z0-9]){0}(?=[A-Z])' -f
                [regex]::Escape($initials.ToLowerInvariant())),
            $caseSensitive
        )
        L7 = [regex]::new(
            ('(?<![A-Za-z0-9]){0}(?=[A-Z])' -f
                [regex]::Escape(
                    $initials[0] + $initials[1].ToString().ToLowerInvariant()
                )),
            $caseSensitive
        )
    }
}

function Invoke-BrandingGitIndexQuery {
    param([Parameter(Mandatory)][string]$RepositoryRoot)

    $gitPath = @(
        (Get-Command git.exe -CommandType Application -ErrorAction SilentlyContinue |
            Select-Object -First 1).Source
        'C:\Program Files\Git\cmd\git.exe'
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) } |
        Select-Object -First 1
    if (-not $gitPath) { throw 'git-error: git.exe is unavailable.' }

    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $gitPath
    $start.Arguments = 'ls-files -z --stage'
    $start.WorkingDirectory = $RepositoryRoot
    $start.UseShellExecute = $false
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    $stream = [IO.MemoryStream]::new()
    try {
        if (-not $process.Start()) { throw 'git-error: git.exe did not start.' }
        $errorTask = $process.StandardError.ReadToEndAsync()
        $process.StandardOutput.BaseStream.CopyTo($stream)
        $process.WaitForExit()
        $stderr = $errorTask.Result
        if ($process.ExitCode -ne 0) {
            throw ("git-error: git ls-files failed with exit code {0}: {1}" -f
                $process.ExitCode, $stderr.Trim())
        }
        [Convert]::ToBase64String($stream.ToArray())
    }
    finally {
        $stream.Dispose()
        $process.Dispose()
    }
}

function ConvertFrom-BrandingGitIndexBytes {
    param([Parameter(Mandatory)][byte[]]$Bytes)

    try {
        $text = [Text.UTF8Encoding]::new($false, $true).GetString($Bytes)
    }
    catch {
        throw 'git-error: Git returned a path inventory that is not valid UTF-8.'
    }

    $entries = [Collections.Generic.List[object]]::new()
    foreach ($record in $text.Split([char]0)) {
        if ([string]::IsNullOrEmpty($record)) { continue }
        $separator = $record.IndexOf([char]9)
        if ($separator -lt 0) {
            throw 'index-record-error: Git index record has no path separator.'
        }
        $metadata = $record.Substring(0, $separator)
        $path = $record.Substring($separator + 1)
        $match = [regex]::Match(
            $metadata,
            '^(?<Mode>[0-9]{6}) (?<Object>[0-9a-f]{40,64}) (?<Stage>[0-3])$',
            [Text.RegularExpressions.RegexOptions]::CultureInvariant
        )
        if (-not $match.Success -or [string]::IsNullOrEmpty($path)) {
            throw 'index-record-error: Git index record is malformed.'
        }
        [void]$entries.Add([pscustomobject]@{
            Mode = $match.Groups['Mode'].Value
            Stage = [int]$match.Groups['Stage'].Value
            Path = $path
        })
    }
    @($entries)
}

function Test-BrandingBinarySignature {
    param([Parameter(Mandatory)][byte[]]$Bytes)

    $signatures = @(
        [byte[]](0x25, 0x50, 0x44, 0x46, 0x2D),
        [byte[]](0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A),
        [byte[]](0xFF, 0xD8, 0xFF),
        [byte[]](0x47, 0x49, 0x46, 0x38),
        [byte[]](0x50, 0x4B, 0x03, 0x04),
        [byte[]](0x50, 0x4B, 0x05, 0x06),
        [byte[]](0x50, 0x4B, 0x07, 0x08)
    )
    foreach ($signature in $signatures) {
        if ($Bytes.Length -lt $signature.Length) { continue }
        $equal = $true
        for ($index = 0; $index -lt $signature.Length; $index++) {
            if ($Bytes[$index] -ne $signature[$index]) {
                $equal = $false
                break
            }
        }
        if ($equal) { return $true }
    }
    $false
}

function ConvertTo-BrandingDisplayPath {
    param([Parameter(Mandatory)][string]$Path)

    $builder = [Text.StringBuilder]::new()
    foreach ($character in $Path.ToCharArray()) {
        if ([char]::IsControl($character)) {
            [void]$builder.Append(('\u{0:x4}' -f [int]$character))
        }
        else {
            [void]$builder.Append($character)
        }
    }
    $builder.ToString()
}

function Get-RepositoryBrandingScan {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$RepositoryRoot)

    $root = [IO.Path]::GetFullPath($RepositoryRoot)
    if (-not (Test-Path -LiteralPath $root -PathType Container)) {
        throw 'git-error: RepositoryRoot is not a directory.'
    }
    $rootPrefix = $root.TrimEnd('\') + '\'
    $patterns = New-BrandingPatternSet
    $raw = [Convert]::FromBase64String(
        (Invoke-BrandingGitIndexQuery -RepositoryRoot $root)
    )
    $entries = @(ConvertFrom-BrandingGitIndexBytes -Bytes $raw)
    $files = [Collections.Generic.List[object]]::new()
    $findings = [Collections.Generic.List[object]]::new()
    $findingKeys = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::Ordinal
    )
    $seenPaths = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::Ordinal
    )

    function Add-Finding {
        param([string]$Path, [string]$PatternClass)
        $displayPath = ConvertTo-BrandingDisplayPath -Path $Path
        if ($findingKeys.Add($displayPath + [char]0 + $PatternClass)) {
            [void]$findings.Add([pscustomobject]@{
                Path = $displayPath
                PatternClass = $PatternClass
            })
        }
    }

    foreach ($entry in $entries) {
        $relativePath = [string]$entry.Path
        foreach ($pattern in $patterns.GetEnumerator()) {
            if ($pattern.Value.IsMatch($relativePath)) {
                Add-Finding -Path $relativePath -PatternClass $pattern.Key
            }
        }
        if ($entry.Stage -ne 0) {
            Add-Finding -Path $relativePath -PatternClass 'index-stage-error'
            continue
        }
        if (-not $seenPaths.Add($relativePath)) {
            Add-Finding -Path $relativePath -PatternClass 'index-record-error'
            continue
        }

        if ($entry.Mode -ceq '120000') {
            [void]$files.Add([pscustomobject]@{
                Path = ConvertTo-BrandingDisplayPath -Path $relativePath
                Classification = 'tracked-link'
            })
            Add-Finding -Path $relativePath -PatternClass 'tracked-link'
            continue
        }
        if ($entry.Mode -notin @('100644', '100755')) {
            [void]$files.Add([pscustomobject]@{
                Path = ConvertTo-BrandingDisplayPath -Path $relativePath
                Classification = 'unsupported-tracked-mode'
            })
            Add-Finding -Path $relativePath -PatternClass 'unsupported-tracked-mode'
            continue
        }

        try {
            $absolutePath = [IO.Path]::GetFullPath(
                (Join-Path $root $relativePath.Replace('/', '\'))
            )
            if (-not $absolutePath.StartsWith(
                $rootPrefix,
                [StringComparison]::OrdinalIgnoreCase
            )) {
                Add-Finding -Path $relativePath -PatternClass 'path-error'
                continue
            }
        }
        catch {
            Add-Finding -Path $relativePath -PatternClass 'path-error'
            continue
        }

        try {
            $bytes = [IO.File]::ReadAllBytes($absolutePath)
        }
        catch {
            Add-Finding -Path $relativePath -PatternClass 'read-error'
            continue
        }

        if (Test-BrandingBinarySignature -Bytes $bytes) {
            [void]$files.Add([pscustomobject]@{
                Path = ConvertTo-BrandingDisplayPath -Path $relativePath
                Classification = 'tracked-binary'
            })
            continue
        }

        try {
            $content = [Text.UTF8Encoding]::new($false, $true).GetString($bytes)
            if ($content.IndexOf([char]0) -ge 0 -or
                @($content.ToCharArray() | Where-Object {
                    [char]::IsControl($_) -and $_ -notin @(
                        [char]9, [char]10, [char]12, [char]13
                    )
                }).Count -gt 0) {
                throw 'Unclassified control byte.'
            }
        }
        catch {
            Add-Finding -Path $relativePath -PatternClass 'classification-error'
            continue
        }

        [void]$files.Add([pscustomobject]@{
            Path = ConvertTo-BrandingDisplayPath -Path $relativePath
            Classification = 'tracked-text'
        })
        foreach ($pattern in $patterns.GetEnumerator()) {
            if ($pattern.Value.IsMatch($content)) {
                Add-Finding -Path $relativePath -PatternClass $pattern.Key
            }
        }
    }

    [pscustomobject]@{
        TrackedCount = $seenPaths.Count
        TextCount = @($files | Where-Object Classification -ceq 'tracked-text').Count
        BinaryCount = @($files | Where-Object Classification -ceq 'tracked-binary').Count
        LinkCount = @($files | Where-Object Classification -ceq 'tracked-link').Count
        Files = @($files)
        Findings = @($findings)
    }
}

Export-ModuleMember -Function Get-RepositoryBrandingScan
```

Do not add extension/path/directory exclusions. A known binary is identified by bytes; an unrecognized or undecodable file blocks as `classification-error`. A tracked link blocks as `tracked-link`, so link-target drift can never be hidden by following the worktree target.

- [ ] **Step 4: Run scanner unit tests and verify GREEN**

```powershell
Import-Module Pester -RequiredVersion 5.7.1 -Force
Invoke-Pester -Path '.github\cli\tests\BrandingContract.Tests.ps1' `
    -Tag 'BrandingContractUnit' -Output Detailed
```

Expected: PASS. The fixture proves Git-tracked enumeration, L1-L7 path and text detection, arbitrary text extensions, explicit binary classification, fail-closed decoding/read/Git behavior, and explicit link handling.

- [ ] **Step 5: Run the complete new contract and prove the current baseline is RED**

```powershell
$result = Invoke-Pester -Path '.github\cli\tests\BrandingContract.Tests.ps1' `
    -Output Detailed -PassThru
if ($result.FailedCount -eq 0) {
    throw 'The approved pre-migration tree unexpectedly passed the branding contract.'
}
```

Expected: the fixture tests pass and the current-repository assertion fails. Its output contains offending path and `PatternClass` only. Compare the reported surface with the approved evidence—475 tracked files at the inventory baseline; 33 L1/L2 lines in 16 files; 476 standalone-L3 lines in 72 files; 325 L4/L5 lines in 30 files; and 64 branded paths—while remembering that categories overlap and the current head also contains post-baseline design artefacts.

- [ ] **Step 6: Review and commit the independently reviewable RED contract**

```powershell
$TaskBase = git rev-parse HEAD
git diff --check
git diff --stat
git diff -- '.github/cli/modules/BrandingContract.psm1' `
    '.github/cli/tests/BrandingContract.Tests.ps1'
git add -- '.github/cli/modules/BrandingContract.psm1' `
    '.github/cli/tests/BrandingContract.Tests.ps1'
git diff --cached --check
git commit -m 'test: add branding regression contract' `
    -m 'Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>'
```

Expected: one reviewed contract commit. This is the only task allowed to commit while the full branding assertion is intentionally RED; its focused fixture suite is GREEN and the RED result is the approved migration baseline.

---

### Task 2: Rename the Brand Assets and Migrate the HR Control Plane Surface

**Files:**
- Rename to: `docs/brand/caldova-fluent-theme.ts`
- Rename to: `docs/brand/caldova-tokens.css`
- Modify: `docs/brand/README.md`
- Modify: `docs/brand/hr-control-plane-mockup.html`
- Modify: `hr/src/apps/hr-control-plane/src/theme.ts`
- Modify: `hr/src/apps/hr-control-plane/src/App.tsx`
- Modify: `hr/src/apps/hr-control-plane/src/components/AppHeader.tsx`
- Modify: `hr/src/apps/hr-control-plane/src/components/AppFooter.tsx`
- Modify: `hr/src/apps/hr-control-plane/README.md`
- Create: `hr/tests/pester/HrControlPlaneBranding.Tests.ps1`
- Test: `.github/cli/tests/BrandingContract.Tests.ps1`

**Interfaces:**
- Consumes: `Get-RepositoryBrandingScan` from Task 1 and the existing palette values in the two canonical brand assets, duplicated app theme, and static mockup.
- Produces: CSS custom-property prefix `--caldova-`, CSS class prefix `.caldova-`, Dataverse-style prefix `caldova_`, and exact TypeScript exports `caldovaBrandRamp`, `caldovaLightTheme`, `caldovaDarkTheme`, `caldovaSemantic`, `caldovaDataViz`, `caldovaLocales`, `CaldovaLocale`, `caldovaDefaultLocale`, and `caldovaNonLocalisedPatterns`.
- Produces: visible app/mockup product name `Caldova HR Agentic Platform` and wordmark `Caldova`.
- Consumer rule: later prose tasks reference only `docs/brand/caldova-fluent-theme.ts` and `docs/brand/caldova-tokens.css`; no compatibility aliases remain.

- [ ] **Step 1: Write the failing static app and palette contract**

Create `hr/tests/pester/HrControlPlaneBranding.Tests.ps1`:

```powershell
Set-StrictMode -Version Latest

BeforeAll {
    $script:root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
    $script:docsTheme = Join-Path $script:root 'docs\brand\caldova-fluent-theme.ts'
    $script:tokens = Join-Path $script:root 'docs\brand\caldova-tokens.css'
    $script:mockup = Join-Path $script:root 'docs\brand\hr-control-plane-mockup.html'
    $script:appRoot = Join-Path $script:root 'hr\src\apps\hr-control-plane'
    $script:appTheme = Join-Path $script:appRoot 'src\theme.ts'
    $script:app = Join-Path $script:appRoot 'src\App.tsx'
    $script:header = Join-Path $script:appRoot 'src\components\AppHeader.tsx'
    $script:footer = Join-Path $script:appRoot 'src\components\AppFooter.tsx'
}

Describe 'Caldova product theme contract' {
    It 'uses the two canonical target asset paths' {
        $script:docsTheme | Should -Exist
        $script:tokens | Should -Exist
    }

    It 'preserves the exact Fluent brand ramp in the canonical and app themes' {
        $expected = [ordered]@{
            10 = '#04121E'; 20 = '#08243C'; 30 = '#0C3559'; 40 = '#104776'
            50 = '#145893'; 60 = '#1965A3'; 70 = '#2C76B0'; 80 = '#4488BE'
            90 = '#5F9ACB'; 100 = '#7CACD8'; 110 = '#99BFE4'
            120 = '#B5D1EC'; 130 = '#CFE1F3'; 140 = '#E2EDF8'
            150 = '#EFF5FB'; 160 = '#F7FAFD'
        }
        foreach ($path in @($script:docsTheme, $script:appTheme)) {
            $content = [IO.File]::ReadAllText($path)
            foreach ($entry in $expected.GetEnumerator()) {
                $content | Should -Match (
                    '(?m)^\s*{0}:\s*"{1}",' -f $entry.Key, [regex]::Escape($entry.Value)
                )
            }
            $content | Should -Match '6\.05:1 on white'
            $content | Should -Match '7\.28:1 on #1B1A19'
        }
    }

    It 'exports only the Caldova symbol contract and Dataverse-style prefix' {
        $content = [IO.File]::ReadAllText($script:appTheme)
        foreach ($symbol in @(
            'caldovaBrandRamp', 'caldovaLightTheme', 'caldovaDarkTheme',
            'caldovaSemantic', 'caldovaDataViz', 'caldovaLocales',
            'CaldovaLocale', 'caldovaDefaultLocale',
            'caldovaNonLocalisedPatterns'
        )) {
            $content | Should -Match ('\b{0}\b' -f [regex]::Escape($symbol))
        }
        $content | Should -Match '\^caldova_\[a-z\]\+\$'
    }

    It 'uses the canonical CSS prefixes and interim-palette wording' {
        $tokenContent = [IO.File]::ReadAllText($script:tokens)
        $brandGuide = [IO.File]::ReadAllText(
            (Join-Path $script:root 'docs\brand\README.md')
        )
        $tokenContent | Should -Match '--caldova-brand-60:\s+#1965A3'
        $tokenContent | Should -Match '(?m)^\.caldova-theme-dark\s*\{'
        $tokenContent | Should -Match '(?m)^\.caldova-app\s*\{'
        $brandGuide | Should -Match (
            'interim product palette pending an approved Caldova design standard'
        )
        $brandGuide | Should -Not -Match 'official Caldova corporate'
    }

    It 'uses Caldova in the app and mockup visible labels and imports' {
        [IO.File]::ReadAllText($script:app) |
            Should -Match 'import \{ caldovaLightTheme \} from "\./theme"'
        [IO.File]::ReadAllText($script:app) |
            Should -Match 'theme=\{caldovaLightTheme\}'
        [IO.File]::ReadAllText($script:header) |
            Should -Match '>Caldova<'
        [IO.File]::ReadAllText($script:footer) |
            Should -Match 'Caldova HR Agentic Platform'
        [IO.File]::ReadAllText($script:mockup) |
            Should -Match 'Caldova HR Agentic Platform'
        [IO.File]::ReadAllText($script:mockup) |
            Should -Match '--caldova-brand-60'
    }
}
```

- [ ] **Step 2: Run the focused test and verify RED**

```powershell
Invoke-Pester -Path 'hr\tests\pester\HrControlPlaneBranding.Tests.ps1' `
    -Output Detailed
```

Expected: FAIL because the target asset paths, symbols, prefixes, imports, wording, and visible labels do not yet exist.

- [ ] **Step 3: Rename the assets before repairing consumers**

Use code-point construction so the command never stores a prohibited source slug:

```powershell
$legacyPair = -join [char[]](103, 102)
$oldTheme = "docs/brand/$legacyPair-fluent-theme.ts"
$oldTokens = "docs/brand/$legacyPair-tokens.css"
git mv -- $oldTheme 'docs/brand/caldova-fluent-theme.ts'
if ($LASTEXITCODE -ne 0) { throw 'Theme rename failed.' }
git mv -- $oldTokens 'docs/brand/caldova-tokens.css'
if ($LASTEXITCODE -ne 0) { throw 'Token rename failed.' }
```

Expected: Git records two renames; there are no copied aliases at the source paths.

- [ ] **Step 4: Migrate the canonical and duplicated theme interfaces**

In both TypeScript theme files, retain all literal palette, semantic, type, radius, and locale values while applying this exact interface:

```typescript
export const caldovaBrandRamp: BrandVariants = {
  10: "#04121E",
  20: "#08243C",
  30: "#0C3559",
  40: "#104776",
  50: "#145893",
  60: "#1965A3", // PRIMARY — 6.05:1 on white
  70: "#2C76B0",
  80: "#4488BE",
  90: "#5F9ACB",
  100: "#7CACD8", // dark-mode primary — 7.28:1 on #1B1A19
  110: "#99BFE4",
  120: "#B5D1EC",
  130: "#CFE1F3",
  140: "#E2EDF8",
  150: "#EFF5FB",
  160: "#F7FAFD",
};

const caldovaFontFamily =
  '"Segoe UI Variable Display", "Segoe UI Variable Text", "Segoe UI", ' +
  "system-ui, -apple-system, sans-serif";

const caldovaShared = {
  fontFamilyBase: caldovaFontFamily,
  borderRadiusSmall: "2px",
  borderRadiusMedium: "4px",
  borderRadiusLarge: "8px",
} satisfies Partial<Theme>;

export const caldovaLightTheme: Theme = {
  ...createLightTheme(caldovaBrandRamp),
  ...caldovaShared,
};

export const caldovaDarkTheme: Theme = {
  ...createDarkTheme(caldovaBrandRamp),
  ...caldovaShared,
};

export const caldovaNonLocalisedPatterns = [
  /^UC-\d{4}$/,
  /^(FR|NFR|BR|AC|D|TD)-\d+$/,
  /^ADR-\d{4}$/,
  /^RUN-\d{4}-\d{4}-\d{2}$/,
  /^PKG-\d{4}-\d{4}-\d{2}$/,
  /^caldova_[a-z]+$/,
] as const;
```

Rename the remaining exports exactly as declared in the task interface. In `docs/brand/caldova-tokens.css`, change every branded custom property and class to the `caldova` forms, including references inside `var(...)`; leave generic mockup aliases such as `--brand` unchanged. Use `.caldova-theme-dark`, `.caldova-app`, `.caldova-num`, `.caldova-metric`, `.caldova-focusable`, and `.caldova-logo`.

- [ ] **Step 5: Reframe guidance and update visible/static consumers**

Use this exact provenance statement in `docs/brand/README.md` and equivalent concise comments in both theme assets:

```markdown
The inherited values are an **interim product palette pending an approved
Caldova design standard**. They are not an official corporate identity.
This migration changes names and provenance wording only; palette values,
contrast targets, semantic-state colours, and dark-mode behavior remain unchanged.
```

Update the brand guide links and example imports to the two target asset names and new symbols. Update the mockup's custom-property/class names, comments, title, wordmark, platform label, and footer labels to Caldova without changing CSS values or layout.

Update `App.tsx`:

```tsx
import { caldovaLightTheme } from "./theme";

// ...
<FluentProvider theme={caldovaLightTheme} className={styles.shell}>
```

Update visible app labels to:

```tsx
// AppHeader.tsx
<Text className={styles.wordmark}>Caldova</Text>

// AppFooter.tsx
<Text weight="semibold">Caldova HR Agentic Platform</Text>
<Text size={200}>Caldova · HR Control Plane wireframe · © 2026</Text>
```

Update `hr/src/apps/hr-control-plane/README.md` to reference `docs/brand/caldova-fluent-theme.ts` and describe the interim product palette. Do not change the app's deployment-state statement, environment binding, or lifecycle status.

Set the metadata-table values in `docs/brand/README.md` and `hr/src/apps/hr-control-plane/README.md` to Version `1.1` and Date `2026-10-01`; preserve their existing Author, Status, Scope, and design authority while repairing renamed References.

- [ ] **Step 6: Prove every hexadecimal colour occurrence is preserved**

This check compares multisets, not just distinct colours, and derives the source files from the implementation base:

```powershell
@'
from collections import Counter
from pathlib import Path
import re
import subprocess

base = "ba35a098e058a51425c5e6052912bda4d04864be"
pair = "".join(chr(value) for value in (103, 102))
pairs = [
    (f"docs/brand/{pair}-fluent-theme.ts", "docs/brand/caldova-fluent-theme.ts"),
    (f"docs/brand/{pair}-tokens.css", "docs/brand/caldova-tokens.css"),
    ("docs/brand/hr-control-plane-mockup.html", "docs/brand/hr-control-plane-mockup.html"),
    ("hr/src/apps/hr-control-plane/src/theme.ts", "hr/src/apps/hr-control-plane/src/theme.ts"),
]
pattern = re.compile(r"#[0-9A-Fa-f]{3,8}\b")
failures = []
for old_path, new_path in pairs:
    old_text = subprocess.check_output(
        ["git", "show", f"{base}:{old_path}"], text=True, encoding="utf-8"
    )
    new_text = Path(new_path).read_text(encoding="utf-8-sig")
    if Counter(value.upper() for value in pattern.findall(old_text)) != Counter(
        value.upper() for value in pattern.findall(new_text)
    ):
        failures.append(new_path)
print(f"Palette multiset verification: checked={len(pairs)}; failures={len(failures)}")
for failure in failures:
    print(failure)
if failures:
    raise SystemExit(1)
'@ | python -
```

Expected: `checked=4; failures=0`. ReportLab and `pypdf` are not used in this task.

- [ ] **Step 7: Run focused app, scanner-slice, lint, and build checks**

```powershell
Import-Module (Join-Path $RepoRoot '.github\cli\modules\BrandingContract.psm1') -Force
Invoke-Pester -Path 'hr\tests\pester\HrControlPlaneBranding.Tests.ps1' `
    -Output Detailed

$scan = Get-RepositoryBrandingScan -RepositoryRoot $RepoRoot
$appFindings = @($scan.Findings | Where-Object {
    $_.Path -like 'docs/brand/*' -or
    $_.Path -like 'hr/src/apps/hr-control-plane/*'
})
if ($appFindings.Count -gt 0) {
    $appFindings | Sort-Object Path, PatternClass | Format-Table -AutoSize
    throw 'Brand/app slice still contains prohibited findings.'
}

Push-Location 'hr\src\apps\hr-control-plane'
try {
    npm run lint
    if ($LASTEXITCODE -ne 0) { throw 'App lint failed.' }
    npm run build
    if ($LASTEXITCODE -ne 0) { throw 'App build failed.' }
}
finally {
    Pop-Location
}
```

Expected: the static contract, lint, and build pass; the completed brand/app slice has no finding. The complete repository contract remains RED only on not-yet-migrated surfaces.

- [ ] **Step 8: Review and commit the theme/app slice**

```powershell
git diff --check
git diff --stat
git diff -- docs/brand hr/src/apps/hr-control-plane `
    hr/tests/pester/HrControlPlaneBranding.Tests.ps1
git add -- docs/brand hr/src/apps/hr-control-plane `
    hr/tests/pester/HrControlPlaneBranding.Tests.ps1
git diff --cached --check
git commit -m 'feat: migrate product theme branding' `
    -m 'Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>'
```

Expected: one independently reviewable rename/theme/app commit with unchanged palette and accessibility behavior.

---

### Task 3: Rename Both AI Builder Corpus Packages and Repair Every Consumer

**Files:**
- Rename to: `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/caldova-aib-fixed-template/`
- Rename to: `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/caldova-aib-general-documents/`
- Create: `hr/tests/pester/AiBuilderCorpus.Tests.ps1`
- Modify: `.github/cli/tests/RepositorySafety.Tests.ps1`
- Modify: every tracked Markdown, test, plan/spec, generator, catalogue, and source file reported by Git as containing either prior package slug
- Test: `.github/cli/tests/DocumentationLinks.Tests.ps1`
- Test: `.github/cli/tests/BrandingContract.Tests.ps1`

**Interfaces:**
- Consumes: the two source package slugs formed as `(-join [char[]](103,102)) + '-aib-fixed-template'` and `(-join [char[]](103,102)) + '-aib-general-documents'`.
- Produces: package roots ending in `caldova-aib-fixed-template` and `caldova-aib-general-documents`, each with one README, `documents/`, `generators/`, `ground-truth.csv`, and `ground-truth.json`.
- Produces: exactly 24 PDFs per package and 48 total, with pre-regeneration Git blob IDs unchanged by this task.
- Consumer rule: Task 7 invokes generators and truth files only through these target package roots; no plan, spec, catalogue, test, import, or link retains a prior package path.

- [ ] **Step 1: Write the failing target-path and truth-shape tests**

Create `hr/tests/pester/AiBuilderCorpus.Tests.ps1`:

```powershell
Set-StrictMode -Version Latest

BeforeAll {
    $script:root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
    $script:ucRoot = Join-Path $script:root (
        'hr\docs\ideas\uc-0001-personal-master-data-completion-agent'
    )
    $script:packages = [ordered]@{
        Fixed = Join-Path $script:ucRoot 'caldova-aib-fixed-template'
        General = Join-Path $script:ucRoot 'caldova-aib-general-documents'
    }
    $script:fieldNames = @(
        'candidate_id', 'last_name', 'first_name', 'dob', 'nationality',
        'marital', 'heimatort', 'permit', 'street', 'plz', 'city', 'ahv',
        'iban', 'phone', 'email', 'ec_name', 'ec_phone'
    )
}

Describe 'AI Builder corpus target paths and truth' {
    It 'has exactly the two Caldova package roots' {
        foreach ($path in $script:packages.Values) {
            $path | Should -Exist
            (Get-Item -LiteralPath $path).PSIsContainer | Should -BeTrue
        }
    }

    It 'uses the target package references in both READMEs and repository safety' {
        $fixedReadme = [IO.File]::ReadAllText(
            (Join-Path $script:packages.Fixed 'README.md')
        )
        $generalReadme = [IO.File]::ReadAllText(
            (Join-Path $script:packages.General 'README.md')
        )
        $safety = [IO.File]::ReadAllText(
            (Join-Path $script:root '.github\cli\tests\RepositorySafety.Tests.ps1')
        )

        $fixedReadme | Should -Match (
            '\.\./caldova-aib-general-documents/README\.md'
        )
        $generalReadme | Should -Match (
            '\.\./caldova-aib-fixed-template/README\.md'
        )
        $safety | Should -Match (
            'caldova-aib-fixed-template/documents/a-personalblatt/' +
            'a01-CAND-2026-0411-brunner\.pdf'
        )
    }

    It 'retains exactly 24 PDFs and 24 truth rows in each package' {
        foreach ($entry in $script:packages.GetEnumerator()) {
            $pdfs = @(Get-ChildItem -LiteralPath (
                Join-Path $entry.Value 'documents'
            ) -Filter '*.pdf' -File -Recurse)
            $csvRows = @(
                Get-Content -LiteralPath (Join-Path $entry.Value 'ground-truth.csv') `
                    -Encoding UTF8 | ConvertFrom-Csv
            )
            $json = Get-Content -LiteralPath (
                Join-Path $entry.Value 'ground-truth.json'
            ) -Raw -Encoding UTF8 | ConvertFrom-Json

            $pdfs.Count | Should -Be 24 -Because "$($entry.Key) PDF count is fixed"
            $csvRows.Count | Should -Be 24
            @($json.documents).Count | Should -Be 24
            [int]$json.field_count | Should -Be 17
        }
    }

    It 'keeps CSV and JSON truth equivalent for every document and field' {
        foreach ($packagePath in $script:packages.Values) {
            $csvRows = @(
                Get-Content -LiteralPath (Join-Path $packagePath 'ground-truth.csv') `
                    -Encoding UTF8 | ConvertFrom-Csv
            )
            $json = Get-Content -LiteralPath (
                Join-Path $packagePath 'ground-truth.json'
            ) -Raw -Encoding UTF8 | ConvertFrom-Json
            $jsonByDocument = @{}
            foreach ($document in $json.documents) {
                $jsonByDocument[[string]$document.document] = $document
            }

            foreach ($row in $csvRows) {
                $jsonByDocument.ContainsKey([string]$row.document) | Should -BeTrue
                $expected = $jsonByDocument[[string]$row.document]
                foreach ($property in @(
                    'document', 'collection_or_layout', 'candidate_id_expected'
                ) + $script:fieldNames) {
                    [string]$row.$property |
                        Should -BeExactly ([string]$expected.$property)
                }
            }
        }
    }
}
```

- [ ] **Step 2: Run the focused test and verify path RED**

```powershell
Invoke-Pester -Path 'hr\tests\pester\AiBuilderCorpus.Tests.ps1' `
    -Output Detailed
```

Expected: FAIL because neither target package root exists. The truth assertions do not pass by skipping absent packages.

- [ ] **Step 3: Rename both package trees**

```powershell
$legacyPair = -join [char[]](103, 102)
$ucGitRoot = 'hr/docs/ideas/uc-0001-personal-master-data-completion-agent'
$oldFixed = "$ucGitRoot/$legacyPair-aib-fixed-template"
$oldGeneral = "$ucGitRoot/$legacyPair-aib-general-documents"
$newFixed = "$ucGitRoot/caldova-aib-fixed-template"
$newGeneral = "$ucGitRoot/caldova-aib-general-documents"

git mv -- $oldFixed $newFixed
if ($LASTEXITCODE -ne 0) { throw 'Fixed-template package rename failed.' }
git mv -- $oldGeneral $newGeneral
if ($LASTEXITCODE -ne 0) { throw 'General-document package rename failed.' }
```

Expected: two directory renames; all 48 PDFs move with their package.

- [ ] **Step 4: Repair every exact package-path consumer**

Enumerate tracked text consumers with Git, block immutable evidence, and replace only the two exact slugs:

```powershell
$legacySlugs = @(
    "$legacyPair-aib-fixed-template"
    "$legacyPair-aib-general-documents"
)
$utf8NoBom = [Text.UTF8Encoding]::new($false)
foreach ($legacySlug in $legacySlugs) {
    $paths = @(& git grep -Il --fixed-strings -e $legacySlug --)
    if ($LASTEXITCODE -notin @(0, 1)) {
        throw "git grep failed for a package slug."
    }
    foreach ($gitPath in $paths) {
        if ($gitPath -like 'docs/reviews/evidence/*' -or
            (
                $gitPath -like '.github/skills/*' -and
                $gitPath -cne '.github/skills/README.md'
            )) {
            throw "Immutable or vendored content contains a package reference: $gitPath"
        }
        $absolutePath = Join-Path $RepoRoot $gitPath.Replace('/', '\')
        $replacement = if ($legacySlug.EndsWith('fixed-template')) {
            'caldova-aib-fixed-template'
        }
        else {
            'caldova-aib-general-documents'
        }
        $content = [IO.File]::ReadAllText($absolutePath)
        $updated = $content.Replace($legacySlug, $replacement)
        if ($updated -ceq $content) {
            throw "Expected package reference was not replaced: $gitPath"
        }
        [IO.File]::WriteAllText($absolutePath, $updated, $utf8NoBom)
    }
}
```

Review every changed context. This exact replacement updates Markdown links, test paths, plans/specs, generator comments/import paths, catalogues, and the repository-safety sample PDF path without changing broader prose yet. In `.github/cli/tests/RepositorySafety.Tests.ps1`, the PDF binary-attribute assertion must target:

```text
hr/docs/ideas/uc-0001-personal-master-data-completion-agent/caldova-aib-fixed-template/documents/a-personalblatt/a01-CAND-2026-0411-brunner.pdf
```

Run this no-stale-reference check:

```powershell
foreach ($legacySlug in $legacySlugs) {
    & git grep -In --fixed-strings -e $legacySlug --
    if ($LASTEXITCODE -eq 0) { throw 'A stale package reference remains.' }
    if ($LASTEXITCODE -ne 1) { throw 'git grep failed.' }
}
```

Expected: no tracked text consumer contains either old slug.

- [ ] **Step 5: Prove all 48 PDFs were preserved before regeneration**

Compare source and target Git blob IDs by package-relative path:

```powershell
$renames = @(
    @{ Old = $oldFixed; New = $newFixed }
    @{ Old = $oldGeneral; New = $newGeneral }
)
$verified = 0
foreach ($rename in $renames) {
    $oldPdfs = @(
        git ls-tree -r --name-only $ImplementationBase -- $rename.Old |
            Where-Object { $_ -like '*.pdf' }
    )
    $newPdfs = @(
        git ls-files -- "$($rename.New)/*.pdf"
    )
    if ($oldPdfs.Count -ne 24 -or $newPdfs.Count -ne 24) {
        throw "Expected 24 PDFs on each side of package rename."
    }
    foreach ($oldPath in $oldPdfs) {
        $suffix = $oldPath.Substring($rename.Old.Length)
        $newPath = $rename.New + $suffix
        $oldBlob = (git rev-parse "$ImplementationBase`:$oldPath").Trim()
        $newBlob = (git hash-object -- $newPath).Trim()
        if ($LASTEXITCODE -ne 0 -or $oldBlob -cne $newBlob) {
            throw "PDF changed during path-only rename: $newPath"
        }
        $verified++
    }
}
if ($verified -ne 48) { throw "Expected 48 preserved PDFs; found $verified." }
Write-Output 'Pre-regeneration PDF preservation: 48/48 unchanged.'
```

Expected: `48/48 unchanged`. This task does not regenerate or edit PDF bytes.

- [ ] **Step 6: Run focused package, link, safety-path, and slice checks**

```powershell
Invoke-Pester -Path @(
    'hr\tests\pester\AiBuilderCorpus.Tests.ps1'
    '.github\cli\tests\DocumentationLinks.Tests.ps1'
    '.github\cli\tests\RepositorySafety.Tests.ps1'
) -Output Detailed

Import-Module (Join-Path $RepoRoot '.github\cli\modules\BrandingContract.psm1') -Force
$scan = Get-RepositoryBrandingScan -RepositoryRoot $RepoRoot
$pathFindings = @($scan.Findings | Where-Object {
    $_.Path -like '*aib-fixed-template*' -or
    $_.Path -like '*aib-general-documents*'
})
$legacyPathFindings = @($pathFindings | Where-Object {
    $_.PatternClass -in @('L4', 'L5', 'L6', 'L7')
})
if ($legacyPathFindings.Count -gt 0) {
    $legacyPathFindings | Sort-Object Path, PatternClass | Format-Table -AutoSize
    throw 'A package path or package-path reference remains prohibited.'
}
```

Expected: package shape/truth, all local Markdown links, and repository-safety PDF attributes pass. Broader prose and generator-content findings remain RED for later tasks.

- [ ] **Step 7: Review and commit the path/reference slice**

```powershell
git diff --check
git diff --stat
git diff --name-status
git diff -- . ':!*.pdf'
git add --all -- $ucGitRoot .github docs hr
git diff --cached --check
git commit -m 'refactor: rename ai builder corpus packages' `
    -m 'Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>'
```

Expected: one path/reference commit. Its 48 PDFs are rename-only and blob-identical to the implementation base.

---

### Task 4: Scrub Root, GitHub, Data, and Infrastructure Guidance

**Files:**
- Modify: `README.md`
- Modify: `AGENTS.md`
- Modify: exact tracked findings under `.github/` except vendored child directories below `.github/skills/`; `.github/skills/README.md` remains repository-owned
- Modify: exact tracked findings under `data/`
- Modify: exact tracked findings under `infra/`
- Do not modify: `LICENSE`
- Do not modify: vendored child directories below `.github/skills/`
- Test: `.github/cli/tests/BrandingContract.Tests.ps1`
- Test: affected `.github/cli/tests/*.Tests.ps1` identified by focused Pester failures

**Interfaces:**
- Consumes: complete `Findings` from Task 1, filtered only for the root/GitHub/data/infra ownership boundary.
- Produces: zero findings in this ownership boundary, neutral external-source descriptions, unchanged lifecycle meaning, and repaired exact contracts for this slice.
- Produces: direct SHA-256 comparison of all six screenshot bytes with commit `63e7900edd431cc810a8396a24b19c17ef4999d1`; no hash is written into a screenshot or evidence manifest.
- Consumer rule: Tasks 5-8 may assume root guidance and repository instructions teach only Caldova terminology.

- [ ] **Step 1: Run the existing contract as the failing test and print the exact slice**

```powershell
Import-Module (Join-Path $RepoRoot '.github\cli\modules\BrandingContract.psm1') -Force
$scan = Get-RepositoryBrandingScan -RepositoryRoot $RepoRoot
$slice = @($scan.Findings | Where-Object {
    $_.Path -in @('README.md', 'AGENTS.md') -or
    $_.Path -like 'data/*' -or
    $_.Path -like 'infra/*' -or
    (
        $_.Path -like '.github/*' -and
        (
            $_.Path -notlike '.github/skills/*' -or
            $_.Path -ceq '.github/skills/README.md'
        )
    )
})
$blocked = @($scan.Findings | Where-Object {
    $_.Path -ceq 'LICENSE' -or
    (
        $_.Path -like '.github/skills/*' -and
        $_.Path -cne '.github/skills/README.md'
    )
})
if ($blocked.Count -gt 0) {
    $blocked | Sort-Object Path, PatternClass | Format-Table -AutoSize
    throw 'A prohibited finding exists in immutable or vendored content.'
}
if ($slice.Count -eq 0) {
    throw 'The pre-migration guidance slice unexpectedly has no findings.'
}
$slice | Sort-Object Path, PatternClass | Format-Table -AutoSize
```

Expected: the exact files and classes for this task print, and the slice is RED.

- [ ] **Step 2: Derive and verify the six screenshot SHA-256 baselines before editing prose**

Run this read-only check:

```powershell
@'
from pathlib import Path
import hashlib
import re
import subprocess

baseline = "63e7900edd431cc810a8396a24b19c17ef4999d1"
root = "docs/reviews/evidence/2026-09-28-tenant-1-engineering-platform"
paths = subprocess.check_output(
    ["git", "ls-tree", "-r", "--name-only", baseline, "--", root],
    text=True,
    encoding="utf-8",
).splitlines()
screenshots = [
    path for path in paths
    if re.fullmatch(r"0[1-6]-[^/]+\.png", Path(path).name)
]
failures = []
for path in screenshots:
    expected = hashlib.sha256(
        subprocess.check_output(["git", "show", f"{baseline}:{path}"])
    ).hexdigest()
    actual = hashlib.sha256(Path(path).read_bytes()).hexdigest()
    if actual != expected:
        failures.append(path)
print(
    f"Screenshot SHA-256 baseline: count={len(screenshots)}; "
    f"mismatches={len(failures)}"
)
for failure in failures:
    print(failure)
if len(screenshots) != 6 or failures:
    raise SystemExit(1)
'@ | python -
```

Expected: `count=6; mismatches=0`. The hashes exist only in process memory/output and are not written to mutable content.

- [ ] **Step 3: Apply context-reviewed transformations**

For every printed finding, inspect the complete sentence, identifier, or path reference and apply exactly one of these outcomes:

| Context | Required result |
|---|---|
| Visible L1, L2, or customer-use L3 | `Caldova` |
| Slug beginning L4 | `caldova-` plus the unchanged suffix |
| Schema/prefix beginning L5 | `caldova_` plus the unchanged suffix |
| Lower-camel symbol beginning L6 | `caldova` plus the unchanged suffix |
| Pascal symbol beginning L7 | `Caldova` plus the unchanged suffix |
| Original HR use-case workbook title | `the customer-supplied HR AI use-case workbook` |
| Original Workday slide-deck title | `the source Workday presentation` |
| Original UC-0001 PRD filename | `the customer-supplied UC-0001 draft PRD` |
| Original UC-0001 artefact-inventory filename | `the customer-supplied UC-0001 artefact inventory` |
| Original personal-master-data field-list filename | `the customer-supplied personal-master-data field workbook` |

Do not claim that any external source was renamed. Preserve every stable ID, decision, status, supersession statement, environment fact, safety boundary, and architecture ruling. For each changed repository-owned Markdown file, preserve `Author`, `Status`, and `Scope`; update renamed `References`, set `Date` to `2026-10-01`, and increment only its metadata-table version once (minor for a two-part version, patch for a three-part version). Do not alter version numbers embedded in historical body prose.

In `.github` YAML, agent Markdown, forms, instructions, and tests, preserve YAML keys, form IDs, exact safety wording, hashes unrelated to changed files, and test strength. Where an exact-content hash protects a deliberately changed instruction/form, review the complete diff, calculate the new SHA-256, and pin that exact value without changing the rest of the assertion.

- [ ] **Step 4: Run focused tests and prove the slice GREEN**

```powershell
$scan = Get-RepositoryBrandingScan -RepositoryRoot $RepoRoot
$remaining = @($scan.Findings | Where-Object {
    $_.Path -in @('README.md', 'AGENTS.md') -or
    $_.Path -like 'data/*' -or
    $_.Path -like 'infra/*' -or
    (
        $_.Path -like '.github/*' -and
        (
            $_.Path -notlike '.github/skills/*' -or
            $_.Path -ceq '.github/skills/README.md'
        )
    )
})
if ($remaining.Count -gt 0) {
    $remaining | Sort-Object Path, PatternClass | Format-Table -AutoSize
    throw 'Root/GitHub/data/infra slice still contains prohibited findings.'
}

Invoke-Pester -Path @(
    '.github\cli\tests\DocsAgentContract.Tests.ps1'
    '.github\cli\tests\IssueFormContract.Tests.ps1'
    '.github\cli\tests\RepositorySafety.Tests.ps1'
    '.github\cli\tests\WorkflowContract.Tests.ps1'
) -Output Detailed
```

Expected: zero slice findings and all four focused suites PASS. Any behavior, shape, safety, ownership, workflow, exact-hash, or immutable-evidence failure blocks this task.

- [ ] **Step 5: Re-run screenshot verification and prove no evidence changed**

Run the exact Python SHA-256 command from Step 2 again, then:

```powershell
$evidenceChanges = @(
    git diff --name-only -- 'docs/reviews/evidence/**'
)
if ($evidenceChanges.Count -gt 0) {
    $evidenceChanges | ForEach-Object { Write-Output $_ }
    throw 'Generated review evidence or a screenshot changed.'
}
```

Expected: six matches, zero hash mismatch, and no evidence path in the diff.

- [ ] **Step 6: Review and commit the repository-guidance slice**

```powershell
git diff --check
git diff --stat
git diff -- README.md AGENTS.md .github data infra
git add -- README.md AGENTS.md .github data infra
git diff --cached --check
git commit -m 'docs: migrate repository guidance branding' `
    -m 'Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>'
```

Expected: one reviewed root/GitHub/data/infra commit, with vendored skills, licenses, generated evidence, and screenshots absent.

---

### Task 5: Scrub ADRs, Specifications, Plans, Reviews, and Documentation Catalogues

**Files:**
- Modify: exact scanner findings under `docs/adr/`
- Modify: exact scanner findings under `docs/specs/`
- Modify: exact scanner findings under `docs/plans/`
- Modify: exact scanner findings in current narrative Markdown under `docs/reviews/`
- Modify: exact scanner findings in `docs/README.md`, `docs/prd.md`, `docs/solution-design.md`, `docs/hr-journey-and-raci.md`, `docs/operating-model/`, and other repository-owned documentation paths printed by the task command
- Do not modify: `docs/reviews/evidence/`
- Do not modify: `.github/skills/`
- Test: `.github/cli/tests/DocumentationLinks.Tests.ps1`
- Test: `.github/cli/tests/DocumentationMetadata.Tests.ps1`
- Test: `.github/cli/tests/Phase2SourceContract.Tests.ps1`
- Test: `.github/cli/tests/Phase3SourceContract.Tests.ps1`
- Test: `.github/cli/tests/BrandingContract.Tests.ps1`

**Interfaces:**
- Consumes: the complete Task 1 findings under `docs/`, plus target brand/package paths from Tasks 2-3.
- Produces: current documentation records that use Caldova while retaining each document's status, supersession statement, authority, stable identifiers, requirements, decisions, and evidential meaning.
- Produces: all local Markdown references under `docs/` resolving to renamed targets.
- Consumer rule: Task 8 can validate all documentation without an exception for historical/current plans, approved specifications, superseded records, or the branding design itself.

- [ ] **Step 1: Run the existing contract as the failing test and print the exact documentation set**

```powershell
Import-Module (Join-Path $RepoRoot '.github\cli\modules\BrandingContract.psm1') -Force
$scan = Get-RepositoryBrandingScan -RepositoryRoot $RepoRoot
$immutableDocs = @($scan.Findings | Where-Object {
    $_.Path -like 'docs/reviews/evidence/*'
})
if ($immutableDocs.Count -gt 0) {
    $immutableDocs | Sort-Object Path, PatternClass | Format-Table -AutoSize
    throw 'Generated review evidence contains a prohibited finding and cannot be edited.'
}
$docsSlice = @($scan.Findings | Where-Object {
    $_.Path -like 'docs/*' -and
    $_.Path -notlike 'docs/brand/*' -and
    $_.Path -notlike 'docs/reviews/evidence/*'
})
if ($docsSlice.Count -eq 0) {
    throw 'The pre-migration documentation slice unexpectedly has no findings.'
}
$docsSlice | Sort-Object Path, PatternClass | Format-Table -AutoSize
```

Expected: the exact ADR, spec, plan, review-narrative, README, and policy files and pattern classes print. Generated evidence has no editable finding.

- [ ] **Step 2: Scrub each current document without changing authority**

Apply the complete transformation table from Task 4. In addition:

- Keep `Approved`, `Draft`, `Proposed Baseline`, `Superseded`, `Active`, and `Archived` statuses exactly as they are.
- Keep requirement/decision IDs and historical dates in body text unchanged.
- Replace a customer attribution with `customer-supplied`, `customer-stated`, `HR-stated`, or `source-derived` according to its existing meaning; do not attribute repository analysis to the customer.
- Replace an external filename with the exact neutral descriptions defined in Task 4; do not construct a Caldova filename for an external source.
- Update all target links to `caldova-fluent-theme.ts`, `caldova-tokens.css`, `caldova-aib-fixed-template`, and `caldova-aib-general-documents`.
- Retain the branding design's L1-L7 vocabulary and code-point definitions; it already avoids literal prohibited values and remains the approval authority.
- Ensure this implementation plan remains scanner-clean and references only post-migration target paths.

For changed repository-owned Markdown, apply the metadata rule from Task 4: preserve `Author`, `Status`, and `Scope`; update renamed `References`; set `Date` to `2026-10-01`; increment only the metadata-table version once.

- [ ] **Step 3: Repair documentation contracts without weakening provenance**

Run the focused documentation suites:

```powershell
$docsResult = Invoke-Pester -Path @(
    '.github\cli\tests\DocumentationLinks.Tests.ps1'
    '.github\cli\tests\DocumentationMetadata.Tests.ps1'
    '.github\cli\tests\Phase2SourceContract.Tests.ps1'
    '.github\cli\tests\Phase3SourceContract.Tests.ps1'
) -Output Detailed -PassThru
```

If a source-contract assertion reads current narrative wording, update its expected Caldova wording while preserving the same authority/status requirement. Do not alter the immutable source-inventory JSON or its recorded source hashes: those records continue to prove the original intake, while Git history and current narrative carry the migration. A failure in a hash that is explicitly defined as an immutable imported-source record is not “fixed” by replacing the recorded hash.

Expected after minimal contract repair: all four suites PASS.

- [ ] **Step 4: Prove the documentation slice and links are GREEN**

```powershell
$scan = Get-RepositoryBrandingScan -RepositoryRoot $RepoRoot
$remaining = @($scan.Findings | Where-Object {
    $_.Path -like 'docs/*' -and
    $_.Path -notlike 'docs/brand/*' -and
    $_.Path -notlike 'docs/reviews/evidence/*'
})
if ($remaining.Count -gt 0) {
    $remaining | Sort-Object Path, PatternClass | Format-Table -AutoSize
    throw 'Documentation slice still contains prohibited findings.'
}
Invoke-Pester -Path @(
    '.github\cli\tests\DocumentationLinks.Tests.ps1'
    '.github\cli\tests\DocumentationMetadata.Tests.ps1'
) -Output Detailed
```

Expected: no prohibited documentation finding, every eligible Markdown header valid, and every tracked local Markdown link resolving.

- [ ] **Step 5: Review and commit the documentation-record slice**

```powershell
git diff --check
git diff --stat
git diff -- docs .github/cli/tests/Phase2SourceContract.Tests.ps1 `
    .github/cli/tests/Phase3SourceContract.Tests.ps1
git diff --name-only -- 'docs/reviews/evidence/**'
if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect evidence diff.' }
if (@(git diff --name-only -- 'docs/reviews/evidence/**').Count -ne 0) {
    throw 'Generated review evidence changed.'
}
git add -- docs .github/cli/tests/Phase2SourceContract.Tests.ps1 `
    .github/cli/tests/Phase3SourceContract.Tests.ps1
git diff --cached --check
git commit -m 'docs: migrate design record branding' `
    -m 'Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>'
```

Expected: one documentation-record commit with immutable evidence absent and all lifecycle meaning preserved.

---

### Task 6: Scrub HR Guidance, Use Cases, and Maintained Static Source Labels

**Files:**
- Modify: `hr/README.md`
- Modify: exact scanner findings under `hr/docs/`, including both renamed corpus READMEs, use-case catalogues, all use-case documents, PRDs, BoMs, and setup guidance
- Modify: exact scanner findings under `hr/src/solutions/` and other maintained HR static source
- Modify: exact scanner findings under `hr/tests/` when an assertion consumes rebranded text
- Exclude until Task 7: the eight `generators/*.py` files below `caldova-aib-fixed-template` and `caldova-aib-general-documents`
- Exclude as binary generated output until Task 7: all 48 package PDFs
- Test: `hr/tests/pester/SolutionLifecycle.Tests.ps1`
- Test: `hr/tests/pester/HrControlPlaneBranding.Tests.ps1`
- Test: `hr/tests/pester/AiBuilderCorpus.Tests.ps1`
- Test: `.github/cli/tests/DocumentationLinks.Tests.ps1`
- Test: `.github/cli/tests/DocumentationMetadata.Tests.ps1`
- Test: `.github/cli/tests/BrandingContract.Tests.ps1`

**Interfaces:**
- Consumes: target app/brand interfaces from Task 2, target package paths from Task 3, and the Task 4 neutral source-description table.
- Produces: HR guidance and source labels that use Caldova, `caldova_` schema examples, and post-migration links while preserving all use-case IDs, requirements, decisions, statuses, synthetic-person warnings, and candidate truth.
- Produces: a remaining HR finding set confined exactly to the six branding-bearing generator files (`gen_fixed.py`, `gen_general.py`, and `personas.py` in each package); Task 7 additionally owns both package-local `gen_truth.py` entry points.
- Consumer rule: Task 7 changes generator code/PDFs only; it does not need to rewrite HR guidance.

- [ ] **Step 1: Run the existing contract as the failing test and identify the exact HR set**

```powershell
Import-Module (Join-Path $RepoRoot '.github\cli\modules\BrandingContract.psm1') -Force
$fixedGeneratorRoot = (
    'hr/docs/ideas/uc-0001-personal-master-data-completion-agent/' +
    'caldova-aib-fixed-template/generators/'
)
$generalGeneratorRoot = (
    'hr/docs/ideas/uc-0001-personal-master-data-completion-agent/' +
    'caldova-aib-general-documents/generators/'
)
$scan = Get-RepositoryBrandingScan -RepositoryRoot $RepoRoot
$hrSlice = @($scan.Findings | Where-Object {
    $_.Path -like 'hr/*' -and
    $_.Path -notlike "$fixedGeneratorRoot*" -and
    $_.Path -notlike "$generalGeneratorRoot*"
})
if ($hrSlice.Count -eq 0) {
    throw 'The pre-migration HR slice unexpectedly has no findings.'
}
$hrSlice | Sort-Object Path, PatternClass | Format-Table -AutoSize
```

Expected: the exact HR prose, use-case, source-label, and consuming-test files print.

- [ ] **Step 2: Apply context-reviewed HR transformations**

Apply the Task 4 transformation table to every printed finding. These requirements are non-negotiable:

- Keep `UC-0001` through `UC-0019`, all `FR`, `NFR`, `BR`, `AC`, `D`, `TD`, `ADR`, run, package, and candidate IDs unchanged.
- Preserve the UC-0001 status and Definition of Ready, including the unresolved matching-key decision and all human-decision/write-envelope constraints.
- Preserve candidate rows, names, dates, addresses, identifiers, contact data, deliberate missing fields, and the duplicate-person test case in both CSV and JSON truth.
- Preserve the statement that all corpus people and personal data are fictional.
- Convert schema examples beginning L5 to `caldova_...`; do not change unrelated Power Platform solution unique names or verified tenant aliases that already use Caldova.
- Replace external filenames with the neutral descriptions from Task 4 and preserve which claims came from HR/customer material versus repository analysis.
- Update all brand and package links to target paths.
- In source/XML/static labels, change only branding labels and identifiers covered by the design; do not change GUIDs, component types, environment URLs, solution lifecycle behavior, or deployment-state facts.

Apply the same exact Markdown metadata rule as Tasks 4-5.

- [ ] **Step 3: Run focused HR tests and repair only rebranded expectations**

```powershell
Invoke-Pester -Path @(
    'hr\tests\pester\SolutionLifecycle.Tests.ps1'
    'hr\tests\pester\HrControlPlaneBranding.Tests.ps1'
    'hr\tests\pester\AiBuilderCorpus.Tests.ps1'
    '.github\cli\tests\DocumentationLinks.Tests.ps1'
    '.github\cli\tests\DocumentationMetadata.Tests.ps1'
) -Output Detailed
```

Expected: PASS. If an assertion fails, update only its expected label/path while preserving exact counts, safety checks, solution behavior, and truth comparisons.

- [ ] **Step 4: Prove only the exact generator files remain in the HR finding set**

```powershell
$scan = Get-RepositoryBrandingScan -RepositoryRoot $RepoRoot
$remainingHr = @($scan.Findings | Where-Object { $_.Path -like 'hr/*' })
$unexpected = @($remainingHr | Where-Object {
    $_.Path -notlike "$fixedGeneratorRoot*" -and
    $_.Path -notlike "$generalGeneratorRoot*"
})
if ($unexpected.Count -gt 0) {
    $unexpected | Sort-Object Path, PatternClass | Format-Table -AutoSize
    throw 'An HR finding remains outside the generator boundary.'
}
$generatorPaths = @($remainingHr.Path | Sort-Object -Unique)
$expectedGeneratorPaths = @(
    "${fixedGeneratorRoot}gen_fixed.py"
    "${fixedGeneratorRoot}gen_general.py"
    "${fixedGeneratorRoot}personas.py"
    "${generalGeneratorRoot}gen_fixed.py"
    "${generalGeneratorRoot}gen_general.py"
    "${generalGeneratorRoot}personas.py"
)
if (@(Compare-Object $expectedGeneratorPaths $generatorPaths).Count -ne 0) {
    Compare-Object $expectedGeneratorPaths $generatorPaths | Format-Table -AutoSize
    throw 'Remaining generator finding paths are not the exact six-file boundary.'
}
```

Expected: no HR finding outside the exact six branding-bearing generator files. The PDF embedded-text boundary remains separate and is not hidden by the text scanner.

- [ ] **Step 5: Review and commit the HR prose/static-source slice**

```powershell
git diff --check
git diff --stat
git diff -- hr `
    ":(exclude)$fixedGeneratorRoot*" `
    ":(exclude)$generalGeneratorRoot*" `
    ':(exclude)*.pdf'
git add -- hr
if (@(git diff --cached --name-only -- '*.pdf').Count -ne 0) {
    throw 'PDFs must not be staged in the HR prose task.'
}
git diff --cached --check
git commit -m 'docs: migrate hr domain branding' `
    -m 'Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>'
```

Expected: one HR prose/static-source commit; generators and PDFs remain unstaged and unchanged.

---

### Task 7: Update Both Generator Copies and Regenerate the 48-PDF Corpus

**Files:**
- Modify: `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/caldova-aib-fixed-template/generators/gen_fixed.py`
- Modify: `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/caldova-aib-fixed-template/generators/gen_general.py`
- Modify: `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/caldova-aib-fixed-template/generators/gen_truth.py`
- Modify: `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/caldova-aib-fixed-template/generators/personas.py`
- Modify: `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/caldova-aib-general-documents/generators/gen_fixed.py`
- Modify: `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/caldova-aib-general-documents/generators/gen_general.py`
- Modify: `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/caldova-aib-general-documents/generators/gen_truth.py`
- Modify: `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/caldova-aib-general-documents/generators/personas.py`
- Regenerate: all PDFs below both target packages' `documents/` directories
- Verify unchanged semantics: both packages' `ground-truth.csv` and `ground-truth.json`
- Modify tests: `hr/tests/pester/AiBuilderCorpus.Tests.ps1`
- Test: `.github/cli/tests/BrandingContract.Tests.ps1`

**Interfaces:**
- Consumes: existing `gen_fixed.build(base) -> list[tuple[str, str, dict, str]]`, `gen_general.build(base) -> list[tuple[str, str, dict]]`, `gen_truth.rows_for(docs, cover_map, key_of) -> list[dict]`, and `gen_truth.write(base, rows, label) -> tuple[int, int, int]`.
- Produces: package-local maintained commands `python .\generators\gen_fixed.py`, `python .\generators\gen_general.py`, and `python .\generators\gen_truth.py`; only the relevant document generator is invoked for each package in this task.
- Produces: constants `FICTIONAL_ENTITY = "Caldova Fictional HR Lab"` and `FICTIONAL_ADDRESS = "Fictionalstrasse 1, 9999 Musterstadt"` in both generator copies.
- Produces: 24 fixed-template and 24 general-document PDFs, unchanged CSV/JSON candidate truth, and semantically reproducible extracted text/page geometry.
- Consumer rule: Task 8 treats checked-in generated PDFs as valid only if the explicit local `pypdf` acceptance command passes.

- [ ] **Step 1: Extend the corpus contract and verify generator RED**

Append these tests to `hr/tests/pester/AiBuilderCorpus.Tests.ps1`:

```powershell
Describe 'AI Builder maintained generator contract' {
    It 'uses a clearly fictional Caldova entity and address in both copies' {
        foreach ($packagePath in $script:packages.Values) {
            foreach ($name in @('gen_fixed.py', 'gen_general.py')) {
                $content = [IO.File]::ReadAllText(
                    (Join-Path $packagePath "generators\$name")
                )
                $content | Should -Match (
                    'FICTIONAL_ENTITY\s*=\s*"Caldova Fictional HR Lab"'
                )
                $content | Should -Match (
                    'FICTIONAL_ADDRESS\s*=\s*"Fictionalstrasse 1, 9999 Musterstadt"'
                )
                $content | Should -Match 'SYNTHETIC TEST DOCUMENT'
                $content | Should -Match 'Not a real person'
            }
        }
    }

    It 'keeps package-local maintained entry points' {
        $fixedGenerator = [IO.File]::ReadAllText(
            (Join-Path $script:packages.Fixed 'generators\gen_fixed.py')
        )
        $generalGenerator = [IO.File]::ReadAllText(
            (Join-Path $script:packages.General 'generators\gen_general.py')
        )
        $fixedTruth = [IO.File]::ReadAllText(
            (Join-Path $script:packages.Fixed 'generators\gen_truth.py')
        )
        $generalTruth = [IO.File]::ReadAllText(
            (Join-Path $script:packages.General 'generators\gen_truth.py')
        )

        $fixedGenerator | Should -Match (
            'build\(os\.path\.join\(PACKAGE_ROOT,\s*"documents"\)\)'
        )
        $generalGenerator | Should -Match (
            'build\(os\.path\.join\(PACKAGE_ROOT,\s*"documents"\)\)'
        )
        $fixedTruth | Should -Match (
            '(?s)write\(\s*PACKAGE_ROOT,.*?"fixed-template"\s*,?\s*\)'
        )
        $generalTruth | Should -Match (
            '(?s)write\(\s*PACKAGE_ROOT,.*?"general-documents"\s*,?\s*\)'
        )
    }
}
```

Run:

```powershell
Invoke-Pester -Path 'hr\tests\pester\AiBuilderCorpus.Tests.ps1' `
    -Output Detailed
```

Expected: existing path/truth tests pass; new fictional-entity and maintained-entry-point tests FAIL.

- [ ] **Step 2: Update both copies without changing persona data or disclaimers**

At the top of both copies of `gen_fixed.py` and `gen_general.py`, add:

```python
PACKAGE_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FICTIONAL_ENTITY = "Caldova Fictional HR Lab"
FICTIONAL_ADDRESS = "Fictionalstrasse 1, 9999 Musterstadt"
```

Use these constants everywhere an employer/entity/address is rendered. Fixed-template headers use `Caldova` or `FICTIONAL_ENTITY`; employer rows use:

```python
value(c, 20*mm, y, f"{FICTIONAL_ENTITY}, {FICTIONAL_ADDRESS}")
```

General-document contracts and letters use:

```python
c.drawString(
    22*mm,
    H-34*mm,
    f"zwischen {FICTIONAL_ENTITY}, {FICTIONAL_ADDRESS} (Arbeitgeberin)",
)

for line in [
    FICTIONAL_ENTITY,
    "HR Operations",
    "Fictionalstrasse 1",
    "9999 Musterstadt",
]:
    c.drawString(22*mm, y, line)
    y -= 4.8*mm
```

Keep the exact synthetic-person disclaimer in every PDF:

```python
"SYNTHETIC TEST DOCUMENT - fictional data for AI Builder training. Not a real person."
```

The fixed generator's existing longer disclaimer may retain “model” if present; its meaning and all candidate/person data remain unchanged. In both `personas.py` copies, change branding-only comments/docstrings, but make no edit to `P`, `KEYS`, `people()`, check-digit logic, or output fields.

Make the fixed package's `gen_fixed.py` main block package-local:

```python
if __name__ == "__main__":
    made = build(os.path.join(PACKAGE_ROOT, "documents"))
    print("generated", len(made), "PDFs across", len(COLLECTIONS), "collections")
```

Make the general package's `gen_general.py` main block package-local:

```python
if __name__ == "__main__":
    made = build(os.path.join(PACKAGE_ROOT, "documents"))
    print("generated", len(made), "PDFs across", len(LAYOUTS), "layout families")
```

Keep the non-owning generator file in each copied generator suite updated with the same entity/address/disclaimer changes, so neither copy can reintroduce old output if called directly.

In the fixed package's `gen_truth.py`, retain `FIELDS`, `FIXED_COVER`, `GEN_COVER`, `rows_for`, and `write`, add `PACKAGE_ROOT`, and make `__main__` build only fixed rows before calling:

```python
if __name__ == "__main__":
    personas = people()
    fixed_documents = []
    for collection_index, (folder, _function, _name) in enumerate(
        gen_fixed.COLLECTIONS
    ):
        for document_index in range(6):
            person = personas[(collection_index * 6 + document_index) % 24]
            fixed_documents.append(
                (
                    f"{folder[0]}{document_index + 1:02d}-"
                    f"{person['candidate_id']}-{person['last_name'].lower()}.pdf",
                    folder,
                    person,
                )
            )
    count, present, total = write(
        PACKAGE_ROOT,
        rows_for(fixed_documents, FIXED_COVER, lambda group: group),
        "fixed-template",
    )
    print(
        f"fixed  : {count} docs, {present}/{total} field values present "
        f"({total - present} deliberate gaps)"
    )
```

In the general package's copy, build only general rows and call:

```python
if __name__ == "__main__":
    personas = people()
    general_documents = []
    sequence = 0
    for layout_index, (layout_name, _function) in enumerate(gen_general.LAYOUTS):
        for document_index in range(3):
            person = personas[(layout_index * 3 + document_index) % 24]
            sequence += 1
            general_documents.append(
                (
                    f"g{sequence:02d}-{layout_name}-{person['candidate_id']}.pdf",
                    layout_name,
                    person,
                )
            )
    count, present, total = write(
        PACKAGE_ROOT,
        rows_for(general_documents, GEN_COVER, lambda group: group),
        "general-documents",
    )
    print(
        f"general: {count} docs, {present}/{total} field values present "
        f"({total - present} deliberate gaps)"
    )
```

These are changes to the files' existing `__main__` entry points and existing function signatures, not invented executables.

- [ ] **Step 3: Run static generator tests and verify GREEN before generation**

```powershell
Invoke-Pester -Path 'hr\tests\pester\AiBuilderCorpus.Tests.ps1' `
    -Output Detailed
```

Expected: PASS, with the previously checked-in truth and 48 pre-regeneration PDFs still present.

- [ ] **Step 4: Prove pre-generation truth semantics against the implementation base**

Use process memory only:

```powershell
$truthCheck = @'
from pathlib import Path
import csv
import io
import json
import subprocess

base = "IMPLEMENTATION_BASE"
pair = "".join(chr(value) for value in (103, 102))
uc = "hr/docs/ideas/uc-0001-personal-master-data-completion-agent"
packages = [
    (f"{uc}/{pair}-aib-fixed-template", f"{uc}/caldova-aib-fixed-template"),
    (f"{uc}/{pair}-aib-general-documents", f"{uc}/caldova-aib-general-documents"),
]

def base_text(path):
    return subprocess.check_output(
        ["git", "show", f"{base}:{path}"]
    ).decode("utf-8-sig")

def csv_rows(text):
    return list(csv.DictReader(io.StringIO(text, newline="")))

rows = 0
failures = []
for old_root, new_root in packages:
    old_csv = csv_rows(base_text(f"{old_root}/ground-truth.csv"))
    new_csv = csv_rows(
        (Path(new_root) / "ground-truth.csv").read_text(encoding="utf-8-sig")
    )
    old_json = json.loads(base_text(f"{old_root}/ground-truth.json"))
    new_json = json.loads(
        (Path(new_root) / "ground-truth.json").read_text(encoding="utf-8-sig")
    )
    rows += len(new_csv)
    if old_csv != new_csv:
        failures.append(f"{new_root}/ground-truth.csv")
    if old_json != new_json:
        failures.append(f"{new_root}/ground-truth.json")

print(f"Truth equivalence: packages={len(packages)}; rows={rows}; failures={len(failures)}")
for failure in failures:
    print(failure)
if len(packages) != 2 or rows != 48 or failures:
    raise SystemExit(1)
'@
$truthCheck.Replace('IMPLEMENTATION_BASE', $ImplementationBase) | python -
```

Expected: `packages=2; rows=48; failures=0`; no baseline file or sidecar is created.

- [ ] **Step 5: Regenerate through the maintained package entry points**

Preflight and invoke the exact files inspected above:

```powershell
python -c "import reportlab; print(reportlab.Version)"
if ($LASTEXITCODE -ne 0) { throw 'Local ReportLab is required.' }

$fixedRoot = Join-Path $RepoRoot (
    'hr\docs\ideas\uc-0001-personal-master-data-completion-agent\' +
    'caldova-aib-fixed-template'
)
$generalRoot = Join-Path $RepoRoot (
    'hr\docs\ideas\uc-0001-personal-master-data-completion-agent\' +
    'caldova-aib-general-documents'
)

Push-Location $fixedRoot
try {
    Get-ChildItem -LiteralPath '.\documents' -Filter '*.pdf' -File -Recurse |
        Remove-Item -Force
    python .\generators\gen_fixed.py
    if ($LASTEXITCODE -ne 0) { throw 'Fixed PDF generation failed.' }
    python .\generators\gen_truth.py
    if ($LASTEXITCODE -ne 0) { throw 'Fixed truth generation failed.' }
}
finally { Pop-Location }

Push-Location $generalRoot
try {
    Get-ChildItem -LiteralPath '.\documents' -Filter '*.pdf' -File -Recurse |
        Remove-Item -Force
    python .\generators\gen_general.py
    if ($LASTEXITCODE -ne 0) { throw 'General PDF generation failed.' }
    python .\generators\gen_truth.py
    if ($LASTEXITCODE -ne 0) { throw 'General truth generation failed.' }
}
finally { Pop-Location }
```

Expected: each document generator reports 24 PDFs; each truth generator reports 24 documents and all deliberate gaps.

- [ ] **Step 6: Prove truth semantics are unchanged**

```powershell
$truthCheck = @'
from pathlib import Path
import csv
import io
import json
import subprocess

base = "IMPLEMENTATION_BASE"
pair = "".join(chr(value) for value in (103, 102))
uc = "hr/docs/ideas/uc-0001-personal-master-data-completion-agent"
packages = [
    (f"{uc}/{pair}-aib-fixed-template", f"{uc}/caldova-aib-fixed-template"),
    (f"{uc}/{pair}-aib-general-documents", f"{uc}/caldova-aib-general-documents"),
]

def base_text(path):
    return subprocess.check_output(
        ["git", "show", f"{base}:{path}"]
    ).decode("utf-8-sig")

def csv_rows(text):
    return list(csv.DictReader(io.StringIO(text, newline="")))

rows = 0
failures = []
for old_root, new_root in packages:
    old_csv = csv_rows(base_text(f"{old_root}/ground-truth.csv"))
    new_csv = csv_rows(
        (Path(new_root) / "ground-truth.csv").read_text(encoding="utf-8-sig")
    )
    old_json = json.loads(base_text(f"{old_root}/ground-truth.json"))
    new_json = json.loads(
        (Path(new_root) / "ground-truth.json").read_text(encoding="utf-8-sig")
    )
    rows += len(new_csv)
    if old_csv != new_csv:
        failures.append(f"{new_root}/ground-truth.csv")
    if old_json != new_json:
        failures.append(f"{new_root}/ground-truth.json")

print(f"Truth equivalence: packages={len(packages)}; rows={rows}; failures={len(failures)}")
for failure in failures:
    print(failure)
if len(packages) != 2 or rows != 48 or failures:
    raise SystemExit(1)
'@
$truthCheck.Replace('IMPLEMENTATION_BASE', $ImplementationBase) | python -
```

Expected: `packages=2; rows=48; failures=0`. All 48 candidate rows and all 17 field values/gaps are equivalent. No brand field exists in current truth, so there is no approved truth-field exception.

- [ ] **Step 7: Prove semantic reproducibility without claiming byte determinism**

Current generators call ReportLab `canvas.Canvas` without deterministic metadata controls. ReportLab may vary creation metadata/document IDs, so this plan deliberately does not require regenerated PDF byte equality. Instead, generate once into an automatically removed temporary directory and compare relative filename, page count, media box, and normalized extracted text with the checked-in output:

```powershell
@'
from importlib import util
from pathlib import Path
import sys
import tempfile

from pypdf import PdfReader

root = Path.cwd()
uc = root / "hr/docs/ideas/uc-0001-personal-master-data-completion-agent"
fixed = uc / "caldova-aib-fixed-template"
general = uc / "caldova-aib-general-documents"

def load(name, path):
    sys.path.insert(0, str(path.parent))
    try:
        spec = util.spec_from_file_location(name, path)
        module = util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module
    finally:
        sys.path.pop(0)

def semantic(path):
    reader = PdfReader(path)
    pages = []
    for page in reader.pages:
        text = (page.extract_text() or "").replace("\r\n", "\n").replace("\r", "\n")
        pages.append(
            {
                "media_box": tuple(float(value) for value in page.mediabox),
                "text": text,
            }
        )
    return pages

with tempfile.TemporaryDirectory(prefix="caldova-corpus-") as temporary:
    temporary = Path(temporary)
    fixed_module = load("caldova_fixed_generator", fixed / "generators/gen_fixed.py")
    general_module = load("caldova_general_generator", general / "generators/gen_general.py")
    fixed_out = temporary / "fixed"
    general_out = temporary / "general"
    fixed_module.build(str(fixed_out))
    general_module.build(str(general_out))

    comparisons = [
        (fixed / "documents", fixed_out),
        (general / "documents", general_out),
    ]
    checked = 0
    failures = []
    for checked_root, generated_root in comparisons:
        checked_paths = {
            path.relative_to(checked_root): path
            for path in checked_root.rglob("*.pdf")
        }
        generated_paths = {
            path.relative_to(generated_root): path
            for path in generated_root.rglob("*.pdf")
        }
        if set(checked_paths) != set(generated_paths):
            failures.append(f"{checked_root}: filename set")
            continue
        for relative in sorted(checked_paths, key=lambda value: str(value)):
            checked += 1
            try:
                if semantic(checked_paths[relative]) != semantic(generated_paths[relative]):
                    failures.append(f"{checked_root / relative}: semantic mismatch")
            except Exception as exc:
                failures.append(
                    f"{checked_root / relative}: {type(exc).__name__}: {exc}"
                )

print(f"Semantic regeneration: checked={checked}; failures={len(failures)}")
for failure in failures:
    print(failure)
if checked != 48 or failures:
    raise SystemExit(1)
'@ | python -
```

Expected: `checked=48; failures=0`. The temporary directory is automatically removed. This verifies current generator behavior semantically and makes no unsupported byte-equality claim.

- [ ] **Step 8: Run corpus, branding, and explicit local PDF checks**

```powershell
Invoke-Pester -Path @(
    'hr\tests\pester\AiBuilderCorpus.Tests.ps1'
    '.github\cli\tests\BrandingContract.Tests.ps1'
) -Output Detailed
```

Then run this complete local check:

```powershell
@'
from pathlib import Path
import re
import subprocess
import sys

from pypdf import PdfReader

first = "".join(chr(value) for value in (71, 101, 111, 114, 103))
second = "".join(chr(value) for value in (70, 105, 115, 99, 104, 101, 114))
initials = first[0] + second[0]
patterns = {
    "spaced-full-name": re.compile(re.escape(first + " " + second), re.IGNORECASE),
    "joined-full-name": re.compile(re.escape(first + second), re.IGNORECASE),
    "standalone-initials": re.compile(
        rf"(?<![A-Za-z0-9]){re.escape(initials)}(?![A-Za-z0-9])"
    ),
    "branded-prefix": re.compile(
        rf"(?<![A-Za-z0-9]){re.escape(initials.lower())}[-_]",
        re.IGNORECASE,
    ),
    "lower-camel-prefix": re.compile(
        rf"(?<![A-Za-z0-9]){re.escape(initials.lower())}(?=[A-Z])"
    ),
    "pascal-prefix": re.compile(
        rf"(?<![A-Za-z0-9]){re.escape(initials[0] + initials[1].lower())}(?=[A-Z])"
    ),
}

raw = subprocess.check_output(["git", "ls-files", "-z", "--", "*.pdf"])
tracked = [Path(value) for value in raw.decode("utf-8").split("\0") if value]
use_case_root = "hr/docs/ideas/uc-0001-personal-master-data-completion-agent/"
corpus_roots = (
    use_case_root + "caldova-aib-fixed-template/documents/",
    use_case_root + "caldova-aib-general-documents/documents/",
)
paths = [
    path for path in tracked
    if path.as_posix().startswith(corpus_roots)
]
readable = 0
extraction_errors = []
legacy_matches = []

for path in paths:
    try:
        reader = PdfReader(path)
        text = "\n".join((page.extract_text() or "") for page in reader.pages)
        readable += 1
    except Exception as exc:
        extraction_errors.append(f"{path}: {type(exc).__name__}: {exc}")
        continue
    for label, pattern in patterns.items():
        if pattern.search(text):
            legacy_matches.append(f"{path}: {label}")

print(
    "PDF verification: "
    f"readable={readable}; "
    f"extraction_errors={len(extraction_errors)}; "
    f"legacy_matches={len(legacy_matches)}"
)
for failure in extraction_errors + legacy_matches:
    print(failure)

if len(paths) != 48 or readable != 48 or extraction_errors or legacy_matches:
    sys.exit(1)
'@ | python -
```

Expected: corpus and branding contracts pass, and local PDF extraction has exactly 48 readable corpus files with no error or legacy match. The final 55-file corpus/evidence partition and evidence byte-equality check runs in Task 8 Step 8.

- [ ] **Step 9: Review and commit generators plus generated output**

```powershell
$ucGitRoot = 'hr/docs/ideas/uc-0001-personal-master-data-completion-agent'
$fixedGeneratorRoot = "$ucGitRoot/caldova-aib-fixed-template/generators"
$generalGeneratorRoot = "$ucGitRoot/caldova-aib-general-documents/generators"
git diff --check
git diff --stat
git diff -- $fixedGeneratorRoot $generalGeneratorRoot `
    hr/tests/pester/AiBuilderCorpus.Tests.ps1
if (@(git status --short -- '*.pdf').Count -ne 48) {
    throw 'Expected exactly 48 regenerated PDF paths in the worktree diff.'
}
git add -- $fixedGeneratorRoot $generalGeneratorRoot `
    hr/tests/pester/AiBuilderCorpus.Tests.ps1 `
    "$ucGitRoot/caldova-aib-fixed-template/documents" `
    "$ucGitRoot/caldova-aib-fixed-template/ground-truth.csv" `
    "$ucGitRoot/caldova-aib-fixed-template/ground-truth.json" `
    "$ucGitRoot/caldova-aib-general-documents/documents" `
    "$ucGitRoot/caldova-aib-general-documents/ground-truth.csv" `
    "$ucGitRoot/caldova-aib-general-documents/ground-truth.json"
git diff --cached --check
git commit -m 'feat: regenerate caldova synthetic corpus' `
    -m 'Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>'
```

Expected: one generator/generated-output commit with exactly 48 regenerated PDFs and semantically unchanged truth.

---

### Task 8: Repair Remaining Contracts and Run Complete Acceptance

**Files:**
- Modify: exact failing contracts under `.github/cli/tests/` and `hr/tests/pester/` whose protected target path, visible label, or exact repository-owned file hash changed
- Modify only if required by its own contract: `.github/workflows/validate-repository.yml`
- Test: `.github/cli/tests/BrandingContract.Tests.ps1`
- Test: every `*.Tests.ps1` under `.github/cli/tests/`
- Test: `infra/tests/pester/`
- Test: `hr/tests/pester/`
- Validate: `docs/`, `hr/src/apps/hr-control-plane/`, `infra/src/bicep/`, both target corpus packages, and all six screenshots

**Interfaces:**
- Consumes: all target paths, symbols, prose, generator outputs, and test contracts from Tasks 1-7.
- Produces: zero `Findings` from `Get-RepositoryBrandingScan`, zero failed maintained Pester tests, six baseline-equal screenshot SHA-256 values, five successful Bicep builds when the comprehensive workflow still requires them, one passing app lint/build, semantically equivalent truth, exactly 48 readable corpus PDFs with no extraction error or prohibited embedded text, and exactly 7 readable byte-identical evidence PDFs with historical matches reported separately.
- Produces: a reviewed branch diff from `ba35a098e058a51425c5e6052912bda4d04864be` containing only approved current-tree migration changes.
- Consumer rule: after the final whole-branch review, the controller may prepare a pull request; this task does not create, push, merge, or deploy one.

- [ ] **Step 1: Run the complete maintained Pester set first and record every RED contract**

```powershell
Import-Module Pester -RequiredVersion 5.7.1 -Force
$paths = @(
    (Get-ChildItem -LiteralPath '.github\cli\tests' -Filter '*.Tests.ps1' -File |
        Sort-Object FullName |
        Select-Object -ExpandProperty FullName)
    'infra\tests\pester'
    'hr\tests\pester'
)
$initial = Invoke-Pester -Path $paths -Output Detailed -CI -PassThru
Write-Output (
    'Initial complete suite: passed={0}; failed={1}; skipped={2}' -f
        $initial.PassedCount, $initial.FailedCount, $initial.SkippedCount
)
```

Expected: any remaining RED is limited to an exact path, target label, or hash contract affected by the approved migration. A behavioral, safety, evidence-integrity, truth, metadata, link, source-authority, or solution-lifecycle failure blocks repair-by-expectation.

- [ ] **Step 2: Repair affected tests and hashes without weakening assertions**

For each failure:

1. Confirm the implementation target against the approved design and the producing task.
2. Keep exact count, shape, safety, and status assertions.
3. Replace only the old expected path/label with its exact Caldova target.
4. For a hash-protected repository-owned text file, inspect its complete diff, confirm branding/provenance is the only semantic change, calculate its new SHA-256 with `Get-FileHash`, and pin that exact lowercase value.
5. Never update a hash for a screenshot, generated review evidence, protected tenant blob, vendored skill, license, or original source-inventory record.
6. Never add an exclusion to `BrandingContract`, turn an error into a warning, lower a count, or remove an assertion to obtain green.

The current exact-hash form contract protects these two repository-owned files. Recalculate a hash only when that file is present in the approved branch diff:

```powershell
$hashProtectedTextPaths = @(
    '.github\ISSUE_TEMPLATE\01-bug.yml'
    '.github\ISSUE_TEMPLATE\02-feature.yml'
)
foreach ($hashProtectedTextPath in $hashProtectedTextPaths) {
    git diff $ImplementationBase -- $hashProtectedTextPath
    if ($LASTEXITCODE -ne 0) { throw 'Cannot review protected text diff.' }
    if (@(git diff --name-only $ImplementationBase -- $hashProtectedTextPath).Count -eq 0) {
        continue
    }
    $newHash = (
        Get-FileHash -LiteralPath $hashProtectedTextPath -Algorithm SHA256
    ).Hash.ToLowerInvariant()
    if ($newHash -notmatch '^[0-9a-f]{64}$') {
        throw 'Cannot derive exact SHA-256.'
    }
    Write-Output "$hashProtectedTextPath $newHash"
}
```

Pin an emitted value only in the assertion for that exact file. If neither path changed, do not change either hash.

- [ ] **Step 3: Run documentation metadata and link validation**

```powershell
Invoke-Pester -Path @(
    '.github\cli\tests\DocumentationMetadata.Tests.ps1'
    '.github\cli\tests\DocumentationLinks.Tests.ps1'
) -Output Detailed -CI
```

Expected: PASS. Every eligible repository-owned Markdown file has the exact six fields and valid status; every tracked local Markdown link resolves.

- [ ] **Step 4: Run repository safety separately**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
    -File .github/cli/verify-repository-safety.ps1
if ($LASTEXITCODE -ne 0) { throw 'Repository safety validation failed.' }
```

Expected: `Repository safety validation passed.` No live system is contacted or mutated.

- [ ] **Step 5: Run app lint and production build**

```powershell
Push-Location 'hr\src\apps\hr-control-plane'
try {
    npm run lint
    if ($LASTEXITCODE -ne 0) { throw 'App lint failed.' }
    npm run build
    if ($LASTEXITCODE -ne 0) { throw 'App build failed.' }
}
finally {
    Pop-Location
}
```

Expected: both npm scripts pass from the required app directory.

- [ ] **Step 6: Run generator/truth and semantic-regeneration validation**

```powershell
Invoke-Pester -Path 'hr\tests\pester\AiBuilderCorpus.Tests.ps1' `
    -Output Detailed -CI
```

Recheck baseline truth:

```powershell
$truthCheck = @'
from pathlib import Path
import csv
import io
import json
import subprocess

base = "IMPLEMENTATION_BASE"
pair = "".join(chr(value) for value in (103, 102))
uc = "hr/docs/ideas/uc-0001-personal-master-data-completion-agent"
packages = [
    (f"{uc}/{pair}-aib-fixed-template", f"{uc}/caldova-aib-fixed-template"),
    (f"{uc}/{pair}-aib-general-documents", f"{uc}/caldova-aib-general-documents"),
]

def base_text(path):
    return subprocess.check_output(
        ["git", "show", f"{base}:{path}"]
    ).decode("utf-8-sig")

def csv_rows(text):
    return list(csv.DictReader(io.StringIO(text, newline="")))

rows = 0
failures = []
for old_root, new_root in packages:
    old_csv = csv_rows(base_text(f"{old_root}/ground-truth.csv"))
    new_csv = csv_rows(
        (Path(new_root) / "ground-truth.csv").read_text(encoding="utf-8-sig")
    )
    old_json = json.loads(base_text(f"{old_root}/ground-truth.json"))
    new_json = json.loads(
        (Path(new_root) / "ground-truth.json").read_text(encoding="utf-8-sig")
    )
    rows += len(new_csv)
    if old_csv != new_csv:
        failures.append(f"{new_root}/ground-truth.csv")
    if old_json != new_json:
        failures.append(f"{new_root}/ground-truth.json")

print(f"Truth equivalence: packages={len(packages)}; rows={rows}; failures={len(failures)}")
for failure in failures:
    print(failure)
if len(packages) != 2 or rows != 48 or failures:
    raise SystemExit(1)
'@
$truthCheck.Replace('IMPLEMENTATION_BASE', $ImplementationBase) | python -
```

Then regenerate into an automatically removed temporary directory and compare semantics:

```powershell
@'
from importlib import util
from pathlib import Path
import sys
import tempfile

from pypdf import PdfReader

root = Path.cwd()
uc = root / "hr/docs/ideas/uc-0001-personal-master-data-completion-agent"
fixed = uc / "caldova-aib-fixed-template"
general = uc / "caldova-aib-general-documents"

def load(name, path):
    sys.path.insert(0, str(path.parent))
    try:
        spec = util.spec_from_file_location(name, path)
        module = util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module
    finally:
        sys.path.pop(0)

def semantic(path):
    reader = PdfReader(path)
    pages = []
    for page in reader.pages:
        text = (page.extract_text() or "").replace("\r\n", "\n").replace("\r", "\n")
        pages.append(
            {
                "media_box": tuple(float(value) for value in page.mediabox),
                "text": text,
            }
        )
    return pages

with tempfile.TemporaryDirectory(prefix="caldova-corpus-") as temporary:
    temporary = Path(temporary)
    fixed_module = load("caldova_fixed_acceptance", fixed / "generators/gen_fixed.py")
    general_module = load(
        "caldova_general_acceptance", general / "generators/gen_general.py"
    )
    fixed_out = temporary / "fixed"
    general_out = temporary / "general"
    fixed_module.build(str(fixed_out))
    general_module.build(str(general_out))
    comparisons = [
        (fixed / "documents", fixed_out),
        (general / "documents", general_out),
    ]
    checked = 0
    failures = []
    for checked_root, generated_root in comparisons:
        checked_paths = {
            path.relative_to(checked_root): path
            for path in checked_root.rglob("*.pdf")
        }
        generated_paths = {
            path.relative_to(generated_root): path
            for path in generated_root.rglob("*.pdf")
        }
        if set(checked_paths) != set(generated_paths):
            failures.append(f"{checked_root}: filename set")
            continue
        for relative in sorted(checked_paths, key=lambda value: str(value)):
            checked += 1
            try:
                if semantic(checked_paths[relative]) != semantic(generated_paths[relative]):
                    failures.append(f"{checked_root / relative}: semantic mismatch")
            except Exception as exc:
                failures.append(
                    f"{checked_root / relative}: {type(exc).__name__}: {exc}"
                )

print(f"Semantic regeneration: checked={checked}; failures={len(failures)}")
for failure in failures:
    print(failure)
if checked != 48 or failures:
    raise SystemExit(1)
'@ | python -
```

Expected: 24 rows per package, 17 truth fields, CSV/JSON equivalence, 48 baseline-equivalent truth rows, and `Semantic regeneration: checked=48; failures=0`.

- [ ] **Step 7: Build all five maintained Bicep entry points only while the comprehensive workflow requires them**

```powershell
$workflowPath = '.github\workflows\validate-repository.yml'
$workflowContent = [IO.File]::ReadAllText((Join-Path $RepoRoot $workflowPath))
$workflowRequiresBicep = $workflowContent -match (
    '(?m)^\s*-\s+name:\s+Build every maintained Bicep entry point\s*$'
)
if ($workflowRequiresBicep) {
    $entryPoints = @(
        Get-ChildItem -LiteralPath 'infra\src\bicep' -Filter '*.bicep' `
            -File -Recurse | Sort-Object FullName
    )
    if ($entryPoints.Count -ne 5) {
        throw "The comprehensive workflow requires exactly five Bicep builds; found $($entryPoints.Count)."
    }
    foreach ($entryPoint in $entryPoints) {
        az bicep build --file $entryPoint.FullName --stdout | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Bicep build failed: $($entryPoint.FullName)"
        }
    }
    Write-Output 'Bicep validation: 5/5 passed.'
}
else {
    Write-Output 'Bicep validation not required by the comprehensive repository workflow.'
}
```

Expected at the approved base: `Bicep validation: 5/5 passed.` The five files are `infra\src\bicep\main.bicep` and the four files under `infra\src\bicep\modules\`.

- [ ] **Step 8: Run the explicit local `pypdf` acceptance command**

This is the approved specification command and adds no CI dependency:

```powershell
@'
from collections import Counter
from hashlib import sha256
from pathlib import Path
import re
import subprocess
import sys

from pypdf import PdfReader

integrated_main = "402f42ff01e662dcb6762d44e9a5fec09b3484cd"
first = "".join(chr(value) for value in (71, 101, 111, 114, 103))
second = "".join(chr(value) for value in (70, 105, 115, 99, 104, 101, 114))
initials = first[0] + second[0]
patterns = {
    "L1": re.compile(re.escape(first + " " + second), re.IGNORECASE),
    "L2": re.compile(re.escape(first + second), re.IGNORECASE),
    "L3": re.compile(
        rf"(?<![A-Za-z0-9]){re.escape(initials)}(?![A-Za-z0-9])",
        re.IGNORECASE,
    ),
    "L4": re.compile(
        rf"(?<![A-Za-z0-9]){re.escape(initials.lower())}-",
        re.IGNORECASE,
    ),
    "L5": re.compile(
        rf"(?<![A-Za-z0-9]){re.escape(initials.lower())}_",
        re.IGNORECASE,
    ),
    "L6": re.compile(
        rf"(?<![A-Za-z0-9]){re.escape(initials.lower())}(?=[A-Z])"
    ),
    "L7": re.compile(
        rf"(?<![A-Za-z0-9]){re.escape(initials[0] + initials[1].lower())}(?=[A-Z])"
    ),
}

raw = subprocess.check_output(["git", "ls-files", "-z", "--", "*.pdf"])
paths = [Path(value) for value in raw.decode("utf-8").split("\0") if value]
use_case_root = "hr/docs/ideas/uc-0001-personal-master-data-completion-agent/"
corpus_roots = (
    use_case_root + "caldova-aib-fixed-template/documents/",
    use_case_root + "caldova-aib-general-documents/documents/",
)
corpus = [
    path for path in paths
    if path.as_posix().startswith(corpus_roots)
]
evidence = [
    path for path in paths
    if path.as_posix().startswith("hr/evidence/ai-builder/")
]
other = [
    path for path in paths
    if path not in corpus and path not in evidence
]

def inspect(group):
    readable = 0
    extraction_errors = []
    matches = []
    for path in group:
        try:
            text = "\n".join(
                (page.extract_text() or "") for page in PdfReader(path).pages
            )
            readable += 1
        except Exception as exc:
            extraction_errors.append(
                f"{path}: {type(exc).__name__}: {exc}"
            )
            continue
        for label, pattern in patterns.items():
            matches.extend([label] * len(pattern.findall(text)))
    return readable, extraction_errors, matches

corpus_readable, corpus_errors, corpus_matches = inspect(corpus)
evidence_readable, evidence_errors, evidence_matches = inspect(evidence)
blob_mismatches = []
sha256_mismatches = []
for path in evidence:
    relative = path.as_posix()
    main_blob = subprocess.check_output(
        ["git", "rev-parse", f"{integrated_main}:{relative}"],
        text=True,
    ).strip()
    worktree_blob = subprocess.check_output(
        ["git", "hash-object", "--", relative],
        text=True,
    ).strip()
    main_bytes = subprocess.check_output(
        ["git", "cat-file", "blob", main_blob]
    )
    worktree_bytes = path.read_bytes()
    if main_blob != worktree_blob:
        blob_mismatches.append(relative)
    if sha256(main_bytes).hexdigest() != sha256(worktree_bytes).hexdigest():
        sha256_mismatches.append(relative)

evidence_classes = ",".join(
    f"{label}:{count}"
    for label, count in sorted(Counter(evidence_matches).items())
)
print(
    f"PDF inventory: total={len(paths)}; corpus={len(corpus)}; "
    f"evidence={len(evidence)}; other={len(other)}"
)
print(
    f"Corpus PDF verification: readable={corpus_readable}; "
    f"extraction_errors={len(corpus_errors)}; "
    f"legacy_matches={len(corpus_matches)}"
)
print(
    f"Evidence PDF verification: readable={evidence_readable}; "
    f"extraction_errors={len(evidence_errors)}; "
    f"blob_mismatches={len(blob_mismatches)}; "
    f"sha256_mismatches={len(sha256_mismatches)}"
)
print(
    f"Evidence historical matches: count={len(evidence_matches)}; "
    f"classes={evidence_classes}"
)

if (
    len(paths) != 55
    or len(corpus) != 48
    or len(evidence) != 7
    or other
    or corpus_readable != 48
    or corpus_errors
    or corpus_matches
    or evidence_readable != 7
    or evidence_errors
    or blob_mismatches
    or sha256_mismatches
):
    sys.exit(1)
'@ | python -
```

Expected: total `55` partitioned as corpus `48`, evidence `7`, other `0`; corpus readable `48`, extraction errors `0`, prohibited matches `0`; evidence readable `7`, extraction errors `0`, blob mismatches `0`, SHA-256 mismatches `0`. Historical evidence match count and classes are reported separately and do not fail acceptance.

- [ ] **Step 9: Verify all six screenshot SHA-256 values against the baseline again**

Run:

```powershell
@'
from pathlib import Path
import hashlib
import re
import subprocess

baseline = "63e7900edd431cc810a8396a24b19c17ef4999d1"
root = "docs/reviews/evidence/2026-09-28-tenant-1-engineering-platform"
paths = subprocess.check_output(
    ["git", "ls-tree", "-r", "--name-only", baseline, "--", root],
    text=True,
    encoding="utf-8",
).splitlines()
screenshots = [
    path for path in paths
    if re.fullmatch(r"0[1-6]-[^/]+\.png", Path(path).name)
]
failures = []
for path in screenshots:
    expected = hashlib.sha256(
        subprocess.check_output(["git", "show", f"{baseline}:{path}"])
    ).hexdigest()
    actual = hashlib.sha256(Path(path).read_bytes()).hexdigest()
    if actual != expected:
        failures.append(path)
print(
    f"Screenshot SHA-256 baseline: count={len(screenshots)}; "
    f"mismatches={len(failures)}"
)
for failure in failures:
    print(failure)
if len(screenshots) != 6 or failures:
    raise SystemExit(1)
'@ | python -
```

Expected exactly: `Screenshot SHA-256 baseline: count=6; mismatches=0`. Also require:

```powershell
if (@(git diff --name-only $ImplementationBase -- `
    'docs/reviews/evidence/2026-09-28-tenant-1-engineering-platform/*.png'
).Count -ne 0) {
    throw 'A sanitized screenshot changed on the implementation branch.'
}
if (@(git diff --name-only $ImplementationBase -- `
    'docs/reviews/evidence/**'
).Count -ne 0) {
    throw 'Generated review evidence changed on the implementation branch.'
}
```

- [ ] **Step 10: Run the exact no-match path/text scan**

```powershell
Import-Module (Join-Path $RepoRoot '.github\cli\modules\BrandingContract.psm1') -Force
$scan = Get-RepositoryBrandingScan -RepositoryRoot $RepoRoot
$accounted = $scan.TextCount + $scan.BinaryCount + $scan.LinkCount +
    @($scan.Files | Where-Object Classification -ceq 'unsupported-tracked-mode').Count
if ($scan.TrackedCount -le 0) { throw 'Tracked inventory is empty.' }
if ($scan.Files.Count -ne $scan.TrackedCount -or
    $accounted -ne $scan.TrackedCount) {
    throw 'Tracked classification accounting is incomplete.'
}
if ($scan.LinkCount -ne 0) {
    $scan.Findings | Where-Object PatternClass -ceq 'tracked-link' |
        Format-Table -AutoSize
    throw 'Tracked links are not accepted by this contract.'
}
if ($scan.Findings.Count -ne 0) {
    $scan.Findings | Sort-Object Path, PatternClass | Format-Table -AutoSize
    throw 'Branding path/text acceptance failed.'
}
Write-Output (
    'Branding verification: tracked={0}; text={1}; binary={2}; findings=0' -f
        $scan.TrackedCount, $scan.TextCount, $scan.BinaryCount
)
```

Expected: all tracked entries explicitly classified and zero path/text findings. There is no exception for this plan, the approved design, current historical records, tests, or catalogues.

- [ ] **Step 11: Run the full Windows PowerShell 5.1 Pester 5.7.1 suite**

```powershell
Import-Module Pester -RequiredVersion 5.7.1 -Force
$paths = @(
    (Get-ChildItem -LiteralPath '.github\cli\tests' -Filter '*.Tests.ps1' -File |
        Sort-Object FullName |
        Select-Object -ExpandProperty FullName)
    'infra\tests\pester'
    'hr\tests\pester'
)
Invoke-Pester -Path $paths -Output Detailed -CI
```

Expected: PASS with zero failed tests under Windows PowerShell 5.1 and exact Pester 5.7.1.

- [ ] **Step 12: Run whitespace and approved-diff checks**

```powershell
git diff --check
if ($LASTEXITCODE -ne 0) { throw 'Working-tree whitespace validation failed.' }

$changed = @(git diff --name-only $ImplementationBase)
$prohibitedChanges = @($changed | Where-Object {
    $_ -like '.github/skills/*' -or
    $_ -ceq 'LICENSE' -or
    $_ -like 'docs/reviews/evidence/*'
})
if ($prohibitedChanges.Count -gt 0) {
    $prohibitedChanges | ForEach-Object { Write-Output $_ }
    throw 'Final diff includes an excluded path.'
}
git diff --stat $ImplementationBase
git diff --name-status $ImplementationBase
```

Expected: no whitespace error; no vendored skill, license, generated review evidence, or screenshot appears; all remaining paths map to Tasks 1-8.

- [ ] **Step 13: Perform the final task review and commit the contract-repair slice**

```powershell
$TaskBase = git rev-parse HEAD
git diff --check
git diff --stat
git diff
git add -- .github/cli/tests .github/workflows hr/tests/pester
git diff --cached --check

if (@(git diff --cached --name-only).Count -eq 0) {
    git commit --allow-empty -m 'test: record branding acceptance checkpoint' `
        -m 'Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>'
}
else {
    git commit -m 'test: close branding migration contracts' `
        -m 'Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>'
}
```

Expected: one final scoped commit. An empty checkpoint is allowed only when the first complete suite had zero failures and no contract/hash repair was necessary; it records that the mandatory final task review and complete acceptance ran.

- [ ] **Step 14: Perform the whole-branch review before pull-request preparation**

```powershell
$mergeBase = git merge-base $ApprovedBase HEAD
if ($LASTEXITCODE -ne 0 -or $mergeBase.Trim() -cne $ApprovedBase) {
    throw 'The implementation branch no longer descends directly from the approved base.'
}
git diff --check "$ApprovedBase...HEAD"
if ($LASTEXITCODE -ne 0) { throw 'Committed branch whitespace validation failed.' }
git log --oneline --decorate "$ImplementationBase..HEAD"
git diff --stat "$ApprovedBase...HEAD"
git diff --name-status "$ApprovedBase...HEAD"

$commitCount = [int](git rev-list --count "$ImplementationBase..HEAD")
$coauthorCount = @(
    git log --format='%B' "$ImplementationBase..HEAD" |
        Where-Object {
            $_ -ceq (
                'Co-authored-by: Copilot ' +
                '<223556219+Copilot@users.noreply.github.com>'
            )
        }
).Count
if ($commitCount -ne 8 -or $coauthorCount -ne 8) {
    throw "Expected 8 implementation commits with 8 required co-author trailers."
}
if (@(git status --porcelain=v1).Count -ne 0) {
    throw 'Worktree is not clean after final acceptance.'
}
```

Review the complete diff against the acceptance-criteria map at the top of this plan. Confirm:

- all 475-file baseline evidence categories were addressed despite overlap;
- every rename has all consumers repaired;
- all 48 corpus PDFs were preserved before regeneration and regenerated only through maintained entry points;
- all truth rows and synthetic-person disclaimers remain intact;
- all six screenshots and generated review evidence remain unchanged;
- no external-source rename, live-system change, deployment, history rewrite, or excluded-path edit appears.

Expected: exactly eight scoped implementation commits, each with the required co-author trailer, a clean worktree, and a complete reviewed branch ready for the controller's pull-request process.
