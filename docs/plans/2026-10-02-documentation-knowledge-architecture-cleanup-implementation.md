# Documentation Knowledge Architecture Cleanup Implementation Plan

| Field | Value |
|---|---|
| **Version** | 1.1 |
| **Date** | 2026-10-02 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Draft |
| **Scope** | Repository documentation knowledge architecture cleanup |
| **References** | [Approved Documentation Knowledge Architecture Cleanup Design](../specs/2026-10-02-documentation-knowledge-architecture-cleanup-design.md), [Approved Repository-Agent Portfolio Governance Design](../specs/2026-10-02-hr-frontier-copilot-agent-portfolio-governance-design.md) |

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Consolidate repository knowledge into one idea-to-specification-to-plan lifecycle, separate central portfolio records from domain detail, archive the immutable Phase 2 snapshots, and make every active documentation root deterministically navigable and testable.

**Architecture:** Central lifecycle records live in `docs/ideas/`, `docs/specs/`, and `docs/plans/`; detailed HR use-case material lives in `hr/docs/use-cases/`; immutable Phase 2 snapshots live under `docs/archive/phase-2-operating-model/`. A new Pester navigation contract enforces canonical roots, curated direct-child catalogues, status consistency, exact historical exceptions, deferred Board synchronization, and the absence of new GitHub workflows. Existing metadata, link, source-contract, issue-form, repository-safety, branding, and AI Builder contracts remain the enforcement spine.

**Tech Stack:** Git, Windows PowerShell 5.1, Pester 5.7.1, Markdown, YAML, JSON, Python 3 generators, and existing repository PowerShell validators.

**Spec:** [`docs/specs/2026-10-02-documentation-knowledge-architecture-cleanup-design.md`](../specs/2026-10-02-documentation-knowledge-architecture-cleanup-design.md)

## Global Constraints

- Start execution from commit `a56a521` or a reviewed descendant that contains both approved designs and this plan. At execution time, use `superpowers:using-git-worktrees` to create the isolated branch/worktree selected by that skill.
- On Windows developer workstations, place external worktrees below `%LOCALAPPDATA%\CaldovaHrFrontier\worktrees\<repository>\<branch>`. Resolve Local AppData with `[Environment]::GetFolderPath('LocalApplicationData')`, create only the task-specific directory, and prove current-user write/delete permission with a unique probe file before `git worktree add`. Do not require elevation or broaden ACLs.
- Repository-wide lifecycle roots are exactly `docs/ideas/`, `docs/specs/`, and `docs/plans/`.
- Central idea records remain after graduation. UC-0001 becomes `Graduated`; its detailed package moves to `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/`.
- Do not preserve, create, infer, rebuild, or modify Azure Boards IDs, links, work items, iterations, teams, areas, or configuration. Central idea rows use `Deferred - not synchronized`.
- Do not add, remove, or modify `.github/workflows/validate-repository.yml`. No new GitHub Actions workflow is allowed.
- Do not edit files below the vendored Superpowers roots in `.github/skills/`. Add the repository placement override only to repository-owned instructions.
- Use `git mv` for every tracked move. Do not create redirect stubs at retired paths.
- Preserve all 48 synthetic corpus PDFs byte-for-byte. Preserve the 7 immutable AI Builder evidence PDFs at their existing paths and byte values.
- Move the eight named Phase 2 snapshots byte-for-byte and retain their current SHA-256 values. Keep `docs/reviews/2026-09-17-architecture-baseline-source-inventory.json` unchanged.
- Exclude only the eight named archived snapshots from live-link validation. The archive README and every active document remain link-validated.
- Keep superseded operational stop notices in current infrastructure paths when the path itself prevents use of retired behavior.
- Active control surfaces may not reference retired roots. Historical plans, reviews, the immutable source inventory, the migration review, and vendored skill text may retain exact old-path facts.
- Every maintained repository-owned Markdown file remains English, UTF-8, and compliant with the six-field metadata policy.
- Every document creation, move, graduation, supersession, or removal updates its owning README in the same commit.
- Use Windows PowerShell 5.1 and exact Pester 5.7.1 for authoritative validation. Do not install dependencies unless a selected command proves they are missing.
- Each task uses red/green validation where behavior changes, receives a focused diff review, and ends in one scoped commit with `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>`.

---

### Task 1: Capture the Migration Baseline and Review Contract

**Files:**
- Create: `docs/reviews/2026-10-02-documentation-knowledge-architecture-migration-review.md`
- Create: `docs/reviews/evidence/2026-10-02-documentation-knowledge-architecture/migration-baseline.json`
- Modify: `docs/reviews/README.md`

**Interfaces:**
- Consumes: approved migration map in `docs/specs/2026-10-02-documentation-knowledge-architecture-cleanup-design.md`.
- Produces: one durable migration review with baseline commit, pre-move inventory, path dispositions, before hashes, validation state, and rollback evidence used by Tasks 2-6.

- [ ] **Step 1: Confirm the execution baseline is clean**

Run:

```powershell
git status --short
git rev-parse HEAD
git branch --show-current
```

Expected: no status output; `HEAD` is `a56a521` or a reviewed descendant; the branch is not `main`.

- [ ] **Step 2: Capture the exact pre-move inventory and hashes**

Run:

```powershell
$tracked = @(
    git -c core.quotepath=false ls-files -- `
        'docs/**' 'hr/**' 'infra/**' 'data/**' |
        Where-Object {
            $_ -match '\.(md|html|pdf|csv|json|py|ps1|yml|yaml)$'
        }
)
if ($LASTEXITCODE -ne 0) { throw 'Cannot enumerate migration inventory.' }

$records = foreach ($relativePath in $tracked) {
    [pscustomobject]@{
        Path = $relativePath
        Sha256 = (Get-FileHash -LiteralPath $relativePath -Algorithm SHA256).Hash.ToLowerInvariant()
    }
}

$payload = [ordered]@{
    schemaVersion = 1
    baselineCommit = (git rev-parse HEAD).Trim()
    files = @($records | Sort-Object Path)
}
$evidenceRoot = 'docs\reviews\evidence\2026-10-02-documentation-knowledge-architecture'
New-Item -ItemType Directory -Path $evidenceRoot -Force | Out-Null
$payload |
    ConvertTo-Json -Depth 5 |
    Set-Content -LiteralPath (Join-Path $evidenceRoot 'migration-baseline.json') -Encoding UTF8
```

Expected: the committed evidence manifest contains the exact baseline commit and every candidate path with a lowercase SHA-256 value. It is point-in-time migration evidence, not current documentation authority.

- [ ] **Step 3: Create the migration review with an honest pre-state**

Create `docs/reviews/2026-10-02-documentation-knowledge-architecture-migration-review.md` with:

```markdown
# Documentation Knowledge Architecture Migration Review

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-10-02 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Draft |
| **Scope** | Documentation knowledge architecture migration evidence |
| **References** | [Approved Cleanup Design](../specs/2026-10-02-documentation-knowledge-architecture-cleanup-design.md), [Migration Plan](../plans/2026-10-02-documentation-knowledge-architecture-cleanup-implementation.md), [Baseline Manifest](evidence/2026-10-02-documentation-knowledge-architecture/migration-baseline.json) |

## Baseline

Record the execution commit, branch, tracked Markdown count, corpus PDF count, immutable evidence PDF count, and the exact validation commands run before mutation.

## Migration Register

| Old path | New path | Class | Pre-move SHA-256 | Post-move SHA-256 | Disposition | Active replacement | Validation |
|---|---|---|---|---|---|---|---|

## Validation Summary

Every command remains `Not run - migration pending` until its output is observed.

## Exceptions and Failures

No exception or failure is recorded at baseline.
```

Populate the migration register from the approved move/remove/retain sets. Use one row per moved or removed tracked item; directory summary rows may group the 48 PDFs only when the review also records the aggregate file count and a comparison against the per-file baseline manifest. Add explicit retained-control rows for the seven immutable evidence PDFs, the source inventory JSON, `docs/brand/`, and each superseded infrastructure stop notice that stays at its operational path.

- [ ] **Step 4: Add the review to the reviews catalogue**

Add one row to `docs/reviews/README.md` with:

```markdown
| [Documentation Knowledge Architecture Migration Review](2026-10-02-documentation-knowledge-architecture-migration-review.md) | 2026-10-02 | Draft | Documentation path, hash, reference, catalogue, and validation migration evidence | [Baseline manifest](evidence/2026-10-02-documentation-knowledge-architecture/migration-baseline.json); migration not run |
```

- [ ] **Step 5: Validate metadata and links**

Run:

```powershell
Import-Module Pester -RequiredVersion 5.7.1 -Force
$result = Invoke-Pester -Path @(
    '.github\cli\tests\DocumentationMetadata.Tests.ps1'
    '.github\cli\tests\DocumentationLinks.Tests.ps1'
) -Output Detailed -CI -PassThru
if ($result.FailedCount -gt 0) { throw "$($result.FailedCount) documentation test(s) failed." }
git diff --check
```

Expected: all selected tests pass and `git diff --check` exits `0`.

- [ ] **Step 6: Commit the baseline evidence**

```powershell
git add -- `
    'docs/reviews/2026-10-02-documentation-knowledge-architecture-migration-review.md' `
    'docs/reviews/evidence/2026-10-02-documentation-knowledge-architecture/migration-baseline.json' `
    'docs/reviews/README.md'
git commit -m "docs: capture knowledge migration baseline" `
    -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 2: Centralize Ideas and Move HR Use-Case Detail

**Files:**
- Create: `.github/cli/tests/DocumentationNavigation.Tests.ps1`
- Rewrite: `docs/ideas/README.md`
- Move: `hr/docs/ideas/hr-control-plane-mockup-idea.md` -> `docs/ideas/hr-control-plane-mockup-idea.md`
- Move: `hr/docs/ideas/hr-control-plane-mockup.html` -> `docs/ideas/hr-control-plane-mockup.html`
- Move: `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/uc-0001-personal-master-data-completion-agent.md` -> `docs/ideas/uc-0001-personal-master-data-completion-agent.md`
- Move: `hr/docs/ideas/uc-0002-hr-policy-chat-assistant.md` -> `docs/ideas/uc-0002-hr-policy-chat-assistant.md`
- Move: `hr/docs/ideas/uc-0003-employee-self-service-assistant.md` -> `docs/ideas/uc-0003-employee-self-service-assistant.md`
- Move: `hr/docs/ideas/uc-0004-hr-case-classification-bot.md` -> `docs/ideas/uc-0004-hr-case-classification-bot.md`
- Move: `hr/docs/ideas/uc-0005-onboarding-assistant.md` -> `docs/ideas/uc-0005-onboarding-assistant.md`
- Move: `hr/docs/ideas/uc-0006-job-description-generator.md` -> `docs/ideas/uc-0006-job-description-generator.md`
- Move: `hr/docs/ideas/uc-0007-candidate-screening-summary.md` -> `docs/ideas/uc-0007-candidate-screening-summary.md`
- Move: `hr/docs/ideas/uc-0008-salary-benchmark-assistant.md` -> `docs/ideas/uc-0008-salary-benchmark-assistant.md`
- Move: `hr/docs/ideas/uc-0009-workforce-insights-assistant.md` -> `docs/ideas/uc-0009-workforce-insights-assistant.md`
- Move: `hr/docs/ideas/uc-0010-employee-data-validation-bot.md` -> `docs/ideas/uc-0010-employee-data-validation-bot.md`
- Move: `hr/docs/ideas/uc-0011-learning-recommendation-agent.md` -> `docs/ideas/uc-0011-learning-recommendation-agent.md`
- Move: `hr/docs/ideas/uc-0012-payroll-anomaly-detection.md` -> `docs/ideas/uc-0012-payroll-anomaly-detection.md`
- Move: `hr/docs/ideas/uc-0013-performance-review-draft-assistant.md` -> `docs/ideas/uc-0013-performance-review-draft-assistant.md`
- Move: `hr/docs/ideas/uc-0014-continuous-performance-insights.md` -> `docs/ideas/uc-0014-continuous-performance-insights.md`
- Move: `hr/docs/ideas/uc-0015-leadership-pipeline-prediction.md` -> `docs/ideas/uc-0015-leadership-pipeline-prediction.md`
- Move: `hr/docs/ideas/uc-0016-skills-inference-engine.md` -> `docs/ideas/uc-0016-skills-inference-engine.md`
- Move: `hr/docs/ideas/uc-0017-pre-hire-process-orchestration.md` -> `docs/ideas/uc-0017-pre-hire-process-orchestration.md`
- Move: `hr/docs/ideas/uc-0018-onboarding-checklist-rebuild.md` -> `docs/ideas/uc-0018-onboarding-checklist-rebuild.md`
- Move: `hr/docs/ideas/uc-0019-attrition-risk-insight-lite.md` -> `docs/ideas/uc-0019-attrition-risk-insight-lite.md`
- Move: remaining `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/` -> `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/`
- Create: `hr/docs/use-cases/README.md`
- Delete after merge: `hr/docs/ideas/README.md`
- Modify: `README.md`
- Modify: `AGENTS.md`
- Modify: `.github/copilot-instructions.md`
- Modify: `.github/CODEOWNERS`
- Modify: `.github/ISSUE_TEMPLATE/use-case-intake.yml`
- Modify: `.github/cli/modules/DocumentationMetadata.psm1`
- Modify: `.github/cli/tests/DocumentationMetadata.Tests.ps1`
- Modify: `.github/cli/tests/IssueFormContract.Tests.ps1`
- Modify: `.github/cli/tests/RepositorySafety.Tests.ps1`
- Modify: `.github/cli/tests/DocsAgentContract.Tests.ps1`
- Modify: `hr/tests/pester/AiBuilderCorpus.Tests.ps1`
- Modify: `hr/tests/pester/AiBuilderEvidence.Tests.ps1`
- Modify: `hr/src/scripts/Initialize-AiBuilderEvidenceRun.ps1`
- Modify: `hr/src/scripts/README.md`
- Modify: `hr/evidence/ai-builder/README.md`
- Modify: `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/evaluation-summary.md`
- Modify: `hr/README.md`
- Modify: `docs/README.md`
- Modify: `docs/prd.md`
- Modify: `docs/solution-design.md`
- Modify: `docs/hr-journey-and-raci.md`
- Modify: `docs/adr/0008-human-in-the-loop-and-write-envelope.md`
- Modify: `docs/specs/2026-09-24-hr-control-plane-code-app-wireframe-design.md`
- Modify: `infra/docs/21-azure-boards-population-runbook.md`
- Modify after move: `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/README.md`
- Modify after move: `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/ai-builder-model-setup.md`
- Modify after move: `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/bom-0001-peopledoc-master-data-ai-builder-fields.md`
- Modify after move: `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/bom-0002-ai-builder-test-inputs-and-outcomes.md`
- Modify: `docs/reviews/2026-10-02-documentation-knowledge-architecture-migration-review.md`

**Interfaces:**
- Consumes: Task 1 hash baseline and approved central idea/domain split.
- Produces: permanent central idea records, `hr/docs/use-cases/` domain detail, unchanged corpus/evidence bytes, updated path consumers, and the first navigation contract.

- [ ] **Step 1: Add failing central-idea and domain-path tests**

Create `.github/cli/tests/DocumentationNavigation.Tests.ps1` with:

```powershell
Set-StrictMode -Version Latest

BeforeAll {
    $script:repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
    $script:ideaRoot = Join-Path $script:repositoryRoot 'docs\ideas'
    $script:useCaseRoot = Join-Path $script:repositoryRoot 'hr\docs\use-cases'
}

Describe 'Central idea portfolio and HR use-case detail' {
    It 'uses one central idea root and one HR detail root' {
        $script:ideaRoot | Should -Exist
        $script:useCaseRoot | Should -Exist
        (Join-Path $script:repositoryRoot 'hr\docs\ideas') | Should -Not -Exist
    }

    It 'retains all nineteen HR use-case idea records centrally' {
        $ideas = @(Get-ChildItem -LiteralPath $script:ideaRoot -Filter 'uc-*.md' -File)
        $ideas.Count | Should -Be 19
        foreach ($number in 1..19) {
            $pattern = 'uc-{0:d4}-*.md' -f $number
            @(Get-ChildItem -LiteralPath $script:ideaRoot -Filter $pattern -File).Count |
                Should -Be 1
        }
    }

    It 'marks UC-0001 graduated and defers Board synchronization' {
        $idea = Get-Content -LiteralPath (
            Join-Path $script:ideaRoot 'uc-0001-personal-master-data-completion-agent.md'
        ) -Raw
        $idea | Should -Match '\| \*\*Status\*\* \| Graduated \|'
        $catalogue = Get-Content -LiteralPath (Join-Path $script:ideaRoot 'README.md') -Raw
        $catalogue | Should -Match 'Deferred - not synchronized'
        $catalogue | Should -Not -Match 'AB#\d+'
    }
}
```

Add this case to `DocumentationMetadata.Tests.ps1` before changing the module:

```powershell
It 'accepts Graduated for a retained idea record' {
    $content = New-ValidMetadataDocument -Status 'Graduated'
    @(Test-DocumentationMetadataContent `
        -Content $content `
        -DocumentRelativePath 'docs/ideas/uc-0001-example.md').Count |
        Should -Be 0
}
```

- [ ] **Step 2: Run the new tests and verify they fail for the old layout and status vocabulary**

Run:

```powershell
Import-Module Pester -RequiredVersion 5.7.1 -Force
$result = Invoke-Pester -Path @(
    '.github\cli\tests\DocumentationNavigation.Tests.ps1'
    '.github\cli\tests\DocumentationMetadata.Tests.ps1'
) `
    -Output Detailed -CI -PassThru
if ($result.FailedCount -eq 0) { throw 'Expected the pre-migration navigation contract to fail.' }
```

Expected: failures report missing `hr/docs/use-cases`, existing `hr/docs/ideas`, UC records not yet centralized, and unsupported `Graduated` metadata.

- [ ] **Step 3: Add the Graduated metadata status**

Add `'Graduated'` to `$script:DocumentationStatusPrefixes` in `.github/cli/modules/DocumentationMetadata.psm1`. Do not relax safe-text, qualifier, header, or field-count validation.

- [ ] **Step 4: Move the central idea records and UC-0001 detail**

Run the exact `git mv` operations listed in this task's **Files** section. Create `hr/docs/use-cases/` before moving the remaining UC-0001 directory. Merge the substantive portfolio guidance from `hr/docs/ideas/README.md` into `docs/ideas/README.md`, then remove the former README with `git rm`.

The central catalogue must contain these columns:

```markdown
| ID | Idea | Domain | Status | Purpose | Authority | Domain detail | Governing specification | Implementation plan | Board synchronization |
```

Every row uses `Deferred - not synchronized`. UC-0001 links to its HR detail package and governing specification/plan; records without a downstream artifact say `Not created` rather than inventing a link.

- [ ] **Step 5: Repair central idea links and mark UC-0001 graduated**

Update relative links in all files moved into `docs/ideas/`. In `docs/ideas/uc-0001-personal-master-data-completion-agent.md`, set:

```markdown
| **Status** | Graduated |
```

Add explicit links to:

- `../../hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/README.md`
- the governing specification in `../specs/`
- the governing implementation plan in `../plans/`

Do not add an Azure Boards ID.

- [ ] **Step 6: Repair path consumers and ownership**

Update the exact active consumers listed in **Files**. In `.github/CODEOWNERS`, replace:

```text
/hr/docs/ideas/              @urruegg
```

with:

```text
/docs/ideas/                 @urruegg
/hr/docs/use-cases/          @urruegg
```

Update the use-case issue form check to:

```yaml
- label: I have checked this is not already in docs/ideas/
  required: true
```

Update the repository safety PDF path and both `AiBuilderCorpus.Tests.ps1` corpus prefixes to `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/`. Update evidence scripts and tests only where they consume the moved use-case package; keep `hr/evidence/ai-builder/` unchanged.

- [ ] **Step 7: Verify corpus and evidence bytes against the Task 1 baseline**

Run:

```powershell
$baseline = Get-Content -LiteralPath (
    'docs\reviews\evidence\2026-10-02-documentation-knowledge-architecture\migration-baseline.json'
) -Raw | ConvertFrom-Json

$moved = @(
    git -c core.quotepath=false ls-files -- `
        'hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/**' |
        Where-Object { [IO.Path]::GetExtension($_) -in @('.pdf', '.csv', '.json', '.py') }
)
foreach ($newPath in $moved) {
    $oldPath = $newPath.Replace('hr/docs/use-cases/', 'hr/docs/ideas/')
    $expected = @($baseline.files | Where-Object Path -CEQ $oldPath)
    if ($expected.Count -ne 1) { throw "Missing baseline hash: $oldPath" }
    $actual = (Get-FileHash -LiteralPath $newPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -cne $expected[0].Sha256) { throw "Hash changed: $newPath" }
}
```

Expected: all 48 PDFs, CSV/JSON truth, and Python generators match their old-path hashes. Moved Markdown remains subject to metadata, link, and catalogue validation because approved reference repairs can change its bytes.

- [ ] **Step 8: Run targeted navigation, documentation, issue, safety, and AI Builder tests**

Run:

```powershell
Import-Module Pester -RequiredVersion 5.7.1 -Force
$result = Invoke-Pester -Path @(
    '.github\cli\tests\DocumentationNavigation.Tests.ps1'
    '.github\cli\tests\DocumentationMetadata.Tests.ps1'
    '.github\cli\tests\DocumentationLinks.Tests.ps1'
    '.github\cli\tests\DocsAgentContract.Tests.ps1'
    '.github\cli\tests\IssueFormContract.Tests.ps1'
    '.github\cli\tests\RepositorySafety.Tests.ps1'
    'hr\tests\pester\AiBuilderCorpus.Tests.ps1'
    'hr\tests\pester\AiBuilderEvidence.Tests.ps1'
) -Output Detailed -CI -PassThru
if ($result.FailedCount -gt 0) { throw "$($result.FailedCount) targeted test(s) failed." }
powershell -NoProfile -ExecutionPolicy Bypass -File .github/cli/verify-repository-safety.ps1
git diff --check
```

Expected: every selected test passes, repository safety prints its success line, and whitespace validation exits `0`.

- [ ] **Step 9: Update migration evidence and commit**

Record every move, changed hash, retained evidence path, command, and outcome in the migration review. Then commit:

```powershell
git add -- `
    '.github' 'AGENTS.md' 'README.md' 'docs' 'hr' 'infra'
git commit -m "docs: centralize ideas and HR use cases" `
    -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 3: Consolidate Superpowers Specifications and Plans

**Files:**
- Move: `docs/superpowers/specs/2026-09-25-tenant-2-ai-builder-models-design.md` -> `docs/specs/2026-09-25-tenant-2-ai-builder-models-design.md`
- Move: `docs/superpowers/specs/2026-09-29-ai-builder-evaluation-capture-design.md` -> `docs/specs/2026-09-29-ai-builder-evaluation-capture-design.md`
- Move: `docs/superpowers/plans/2026-09-25-tenant-2-ai-builder-models-implementation.md` -> `docs/plans/2026-09-25-tenant-2-ai-builder-models-implementation.md`
- Move: `docs/superpowers/plans/2026-09-26-runbook-cloud-foundation.md` -> `docs/plans/2026-09-26-runbook-cloud-foundation.md`
- Move: `docs/superpowers/plans/2026-09-26-runbook-customer-handover.md` -> `docs/plans/2026-09-26-runbook-customer-handover.md`
- Move: `docs/superpowers/plans/2026-09-26-runbook-foundation-workstation.md` -> `docs/plans/2026-09-26-runbook-foundation-workstation.md`
- Move: `docs/superpowers/plans/2026-09-29-ai-builder-evaluation-capture-implementation.md` -> `docs/plans/2026-09-29-ai-builder-evaluation-capture-implementation.md`
- Modify: `.github/cli/tests/DocumentationNavigation.Tests.ps1`
- Modify: `.github/cli/tests/DocsAgentContract.Tests.ps1`
- Modify: `.github/copilot-instructions.md`
- Modify: `AGENTS.md`
- Modify: `docs/specs/README.md`
- Modify: `docs/plans/README.md`
- Modify: `hr/src/scripts/README.md`
- Modify: `hr/evidence/ai-builder/README.md`
- Modify: `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/evaluation-flow-definition.md`
- Modify: `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/ai-builder-model-setup.md`
- Modify: `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/bom-0001-peopledoc-master-data-ai-builder-fields.md`
- Modify: `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/bom-0002-ai-builder-test-inputs-and-outcomes.md`
- Modify: `docs/reviews/2026-10-02-documentation-knowledge-architecture-migration-review.md`

**Interfaces:**
- Consumes: central navigation contract from Task 2.
- Produces: one spec root, one plan root, exhaustive catalogues, and a repository-owned override that leaves vendored skills unchanged.

- [ ] **Step 1: Add failing canonical spec/plan tests**

Append:

```powershell
Describe 'Canonical specification and plan roots' {
    It 'has no repository documentation below docs/superpowers' {
        (Join-Path $script:repositoryRoot 'docs\superpowers') | Should -Not -Exist
    }

    It 'stores the two AI Builder designs and five plans in canonical roots' {
        foreach ($relativePath in @(
            'docs/specs/2026-09-25-tenant-2-ai-builder-models-design.md'
            'docs/specs/2026-09-29-ai-builder-evaluation-capture-design.md'
            'docs/plans/2026-09-25-tenant-2-ai-builder-models-implementation.md'
            'docs/plans/2026-09-26-runbook-cloud-foundation.md'
            'docs/plans/2026-09-26-runbook-customer-handover.md'
            'docs/plans/2026-09-26-runbook-foundation-workstation.md'
            'docs/plans/2026-09-29-ai-builder-evaluation-capture-implementation.md'
        )) {
            Join-Path $script:repositoryRoot $relativePath | Should -Exist
        }
    }
}
```

- [ ] **Step 2: Run the focused tests and verify red**

Run the `DocumentationNavigation.Tests.ps1` command from Task 2.

Expected: failures report the seven missing canonical targets and existing `docs/superpowers`.

- [ ] **Step 3: Move the seven artifacts and repair internal references**

Use `git mv` for all seven **Files** entries. Relative plan-to-spec links that remain correct after the move need no textual rewrite. Replace explicit `docs/superpowers/...` paths with canonical paths in repository-owned active files.

Do not modify:

- `.github/skills/brainstorming/SKILL.md`
- `.github/skills/brainstorming/spec-document-reviewer-prompt.md`
- `.github/skills/writing-plans/SKILL.md`
- `.github/skills/subagent-driven-development/SKILL.md`
- `.github/skills/requesting-code-review/SKILL.md`

- [ ] **Step 4: Add the repository placement override**

Add this durable rule to `.github/copilot-instructions.md` and reference it from `AGENTS.md`:

```markdown
**Repository documentation path override.** Store approved design specifications in
`docs/specs/` and implementation plans in `docs/plans/`. These repository-owned
paths override the vendored Superpowers default `docs/superpowers/` locations.
Do not edit vendored skills to change their examples.
```

- [ ] **Step 5: Rebuild both catalogues**

Add the two moved designs to `docs/specs/README.md` and the five moved plans to `docs/plans/README.md`. Each row must use the file's real metadata status, purpose, authority, and successor/next-stage link. The catalogues must list every direct `.md` child except `README.md` exactly once.

Update `DocsAgentContract.Tests.ps1` to read the moved AI Builder design from `docs/specs/` and the moved BoMs from `hr/docs/use-cases/`.

- [ ] **Step 6: Run targeted tests**

Run:

```powershell
Import-Module Pester -RequiredVersion 5.7.1 -Force
$result = Invoke-Pester -Path @(
    '.github\cli\tests\DocumentationNavigation.Tests.ps1'
    '.github\cli\tests\DocumentationMetadata.Tests.ps1'
    '.github\cli\tests\DocumentationLinks.Tests.ps1'
    '.github\cli\tests\DocsAgentContract.Tests.ps1'
) -Output Detailed -CI -PassThru
if ($result.FailedCount -gt 0) { throw "$($result.FailedCount) targeted test(s) failed." }
git diff --check
```

Expected: all selected tests pass and no whitespace errors remain.

- [ ] **Step 7: Update migration evidence and commit**

```powershell
git add -- '.github' 'AGENTS.md' 'docs' 'hr'
git commit -m "docs: consolidate specifications and plans" `
    -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 4: Archive Immutable Phase 2 Records and Repair Governance Routing

**Files:**
- Move: `docs/operating-model/00-north-star.md` -> `docs/archive/phase-2-operating-model/00-north-star.md`
- Move: `docs/operating-model/01-prd.md` -> `docs/archive/phase-2-operating-model/01-prd.md`
- Move: `docs/operating-model/02-system-design.md` -> `docs/archive/phase-2-operating-model/02-system-design.md`
- Move: `docs/operating-model/03-agent-operating-model.md` -> `docs/archive/phase-2-operating-model/03-agent-operating-model.md`
- Move: `docs/operating-model/04-hitl-governance.md` -> `docs/archive/phase-2-operating-model/04-hitl-governance.md`
- Move: `docs/operating-model/05-implementation-roadmap.md` -> `docs/archive/phase-2-operating-model/05-implementation-roadmap.md`
- Move: `docs/90-microsoft-best-practice-evaluation.md` -> `docs/archive/phase-2-operating-model/90-microsoft-best-practice-evaluation.md`
- Move: `hr/docs/20-hr-employee-journey.md` -> `docs/archive/phase-2-operating-model/20-hr-employee-journey.md`
- Create: `docs/archive/phase-2-operating-model/README.md`
- Modify: `docs/archive/README.md`
- Modify: `docs/README.md`
- Modify: `.github/cli/tests/Phase2SourceContract.Tests.ps1`
- Modify: `.github/cli/tests/DocumentationLinks.Tests.ps1`
- Modify: `.github/cli/tests/DocumentationNavigation.Tests.ps1`
- Modify: `.github/cli/tests/IssueFormContract.Tests.ps1`
- Modify: `.github/ISSUE_TEMPLATE/03-frontier-intake.yml`
- Modify: `.github/ISSUE_TEMPLATE/config.yml`
- Modify: `.github/pull_request_template.md`
- Modify: `infra/docs/15-agent-workload-configuration.md`
- Modify: `infra/docs/16-security-governance-and-compliance.md`
- Modify: `hr/src/solutions/README.md`
- Modify: `docs/reviews/2026-10-02-documentation-knowledge-architecture-migration-review.md`

**Interfaces:**
- Consumes: Task 1 hashes and Task 3 canonical lifecycle roots.
- Produces: byte-identical archived snapshots, current archive navigation, current governance routing, exact source-contract enforcement, and a narrow live-link exclusion.

- [ ] **Step 1: Split the Phase 2 source contract into source and archive assertions**

Before moving files, write failing changes in `Phase2SourceContract.Tests.ps1`:

- keep the existing old paths and hashes in a source-inventory map used only against `2026-09-17-architecture-baseline-source-inventory.json`;
- add an archive-path map with the same eight hashes;
- set the current evaluation path to `docs/archive/phase-2-operating-model/90-microsoft-best-practice-evaluation.md`;
- replace on-disk old-path assertions with the eight archive paths.

The archive map contains these exact SHA-256 values:

```powershell
$script:archivedPhase2 = [ordered]@{
    'docs/archive/phase-2-operating-model/00-north-star.md' = '7be5151f04031f4f36e58b80d741ad40c8beb2b26a4dd5ddf8363f318fe9f025'
    'docs/archive/phase-2-operating-model/01-prd.md' = '7fdc213f864cff3cd0e4755e073b0a23fbf797953132b8a94fab55e8548204a3'
    'docs/archive/phase-2-operating-model/02-system-design.md' = 'e0b6ff1c43ae0954bb51edf1993ddd9a6d81376834849a756335034bdd1d88e6'
    'docs/archive/phase-2-operating-model/03-agent-operating-model.md' = '556efcd4af83d221fbe055bbea468d20585112e8d302a4b8ada28514867888a7'
    'docs/archive/phase-2-operating-model/04-hitl-governance.md' = '8c98c9d1d839d92711b01d651b8277cdd67bf61bb81c29c1defb9a5d6eb1de2b'
    'docs/archive/phase-2-operating-model/05-implementation-roadmap.md' = '8698e90d24f7f2809c7c4208769395e9296f39fe4323f8edbe33b4ec0fb2c509'
    'docs/archive/phase-2-operating-model/90-microsoft-best-practice-evaluation.md' = 'fb4d29d4cf75f7cb659c71b21f83e900a484257e8d2cc06e1a006ec40f1b6031'
    'docs/archive/phase-2-operating-model/20-hr-employee-journey.md' = '49d6988c476b9866bc3ca6b70cae3d84b48a5e4c6e2918426c5b2b1614464bca'
}
```

- [ ] **Step 2: Add the exact link-validation exclusion and verify red**

In `DocumentationLinks.Tests.ps1`, define the same eight normalized archive paths and skip only those files before reading links. Do not skip `docs/archive/README.md` or `docs/archive/phase-2-operating-model/README.md`.

Run:

```powershell
Import-Module Pester -RequiredVersion 5.7.1 -Force
$result = Invoke-Pester -Path @(
    '.github\cli\tests\Phase2SourceContract.Tests.ps1'
    '.github\cli\tests\DocumentationLinks.Tests.ps1'
) -Output Detailed -CI -PassThru
if ($result.FailedCount -eq 0) { throw 'Expected archive-path tests to fail before the moves.' }
```

Expected: archive targets are missing.

- [ ] **Step 3: Move the eight files byte-for-byte**

Create `docs/archive/phase-2-operating-model/` and execute the eight `git mv` operations. Do not edit the moved snapshots.

Run:

```powershell
$baseline = Get-Content -LiteralPath (
    'docs\reviews\evidence\2026-10-02-documentation-knowledge-architecture\migration-baseline.json'
) -Raw | ConvertFrom-Json
$archiveMoves = [ordered]@{
    'docs/archive/phase-2-operating-model/00-north-star.md' = 'docs/operating-model/00-north-star.md'
    'docs/archive/phase-2-operating-model/01-prd.md' = 'docs/operating-model/01-prd.md'
    'docs/archive/phase-2-operating-model/02-system-design.md' = 'docs/operating-model/02-system-design.md'
    'docs/archive/phase-2-operating-model/03-agent-operating-model.md' = 'docs/operating-model/03-agent-operating-model.md'
    'docs/archive/phase-2-operating-model/04-hitl-governance.md' = 'docs/operating-model/04-hitl-governance.md'
    'docs/archive/phase-2-operating-model/05-implementation-roadmap.md' = 'docs/operating-model/05-implementation-roadmap.md'
    'docs/archive/phase-2-operating-model/90-microsoft-best-practice-evaluation.md' = 'docs/90-microsoft-best-practice-evaluation.md'
    'docs/archive/phase-2-operating-model/20-hr-employee-journey.md' = 'hr/docs/20-hr-employee-journey.md'
}
foreach ($entry in $archiveMoves.GetEnumerator()) {
    $expected = @($baseline.files | Where-Object Path -CEQ $entry.Value)
    if ($expected.Count -ne 1) { throw "Missing baseline hash: $($entry.Value)" }
    $actual = (Get-FileHash -LiteralPath $entry.Key -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -cne $expected[0].Sha256) { throw "Archive hash mismatch: $($entry.Key)" }
}
```

Expected: all eight hashes match.

- [ ] **Step 4: Create current archive navigation**

Create `docs/archive/phase-2-operating-model/README.md` with a catalogue of the eight snapshots, `Superseded` status, original purpose, and current replacement. State that the snapshots retain original internal links and are excluded from live-link validation because their bytes are hash-pinned.

Update `docs/archive/README.md` and `docs/README.md` to route historical questions through this README, not through the snapshots directly.

- [ ] **Step 5: Point active issue intake to current governance**

Set the current governance path in `IssueFormContract.Tests.ps1` to:

```powershell
$script:governancePolicyRelativePath = '.github/agent-policy/NON_DELEGABLE_WORK.md'
$script:governancePolicyUrl = 'https://github.com/urruegg/caldova-hr-frontier/blob/main/.github/agent-policy/NON_DELEGABLE_WORK.md'
```

Remove assertions that forbid this path as “interim.” Update `03-frontier-intake.yml`, `config.yml`, `infra/docs/15-agent-workload-configuration.md`, and `infra/docs/16-security-governance-and-compliance.md` to current platform policy and `docs/hr-journey-and-raci.md`.

Change `03-frontier-intake.yml` to say the request is triaged into the central repository idea lifecycle; do not promise Azure Boards creation.

Replace the Azure Boards contact in `config.yml` with:

```yaml
  - name: Idea portfolio and delivery lifecycle
    url: https://github.com/urruegg/caldova-hr-frontier/blob/main/docs/ideas/README.md
    about: Ideas are governed in the repository; Azure Boards synchronization is deferred until the later rebuild sprint.
```

Replace the mandatory `AB#` section in `.github/pull_request_template.md` with:

```markdown
## Governing record

<!-- Link the repository idea, specification, plan, or verified Azure Boards item. -->

Board synchronization: Deferred - not synchronized

Use `Fixes AB#<id>` only after Azure Boards synchronization has been rebuilt and
the referenced ID has been verified. Until then, the repository idea,
specification, and plan are the governing delivery record.
```

Update `IssueFormContract.Tests.ps1` to require this repository-first text, the central idea URL, and conditional rather than mandatory `Fixes AB#`.

- [ ] **Step 6: Run archive, issue-form, metadata, and link tests**

Run:

```powershell
Import-Module Pester -RequiredVersion 5.7.1 -Force
$result = Invoke-Pester -Path @(
    '.github\cli\tests\Phase2SourceContract.Tests.ps1'
    '.github\cli\tests\DocumentationLinks.Tests.ps1'
    '.github\cli\tests\DocumentationMetadata.Tests.ps1'
    '.github\cli\tests\DocumentationNavigation.Tests.ps1'
    '.github\cli\tests\IssueFormContract.Tests.ps1'
) -Output Detailed -CI -PassThru
if ($result.FailedCount -gt 0) { throw "$($result.FailedCount) archive test(s) failed." }
git diff --check
```

Expected: all selected tests pass and only the eight snapshots are excluded from link traversal.

- [ ] **Step 7: Update migration evidence and commit**

```powershell
git add -- '.github' 'docs' 'hr' 'infra'
git commit -m "docs: archive superseded phase 2 records" `
    -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 5: Remove Placeholder Roots and Complete Knowledge Catalogues

**Files:**
- Delete: `docs/brandkit/README.md`
- Delete: `docs/business/README.md`
- Delete: `docs/delegation/README.md`
- Delete: `docs/issues/README.md`
- Delete: `docs/sprints/README.md`
- Delete: `docs/templates/README.md`
- Modify: `.github/cli/tests/DocumentationNavigation.Tests.ps1`
- Modify: `.github/cli/verify-repository-setup.ps1`
- Modify: `.github/agents/docs-agent.agent.md`
- Modify: `.github/copilot-instructions.md`
- Modify: `.github/cli/tests/DocsAgentContract.Tests.ps1`
- Modify: `docs/README.md`
- Modify: `docs/ideas/README.md`
- Modify: `docs/specs/README.md`
- Modify: `docs/plans/README.md`
- Modify: `docs/reviews/README.md`
- Modify: `docs/archive/README.md`
- Modify: `docs/adr/README.md`
- Modify: `docs/brand/README.md`
- Modify: `hr/README.md`
- Modify: `hr/docs/use-cases/README.md`
- Create: `infra/docs/README.md`
- Modify: `infra/README.md`
- Modify: `infra/docs/runbooks/01-developer-workstation.md`
- Modify: `data/README.md`
- Modify: `docs/reviews/2026-10-02-documentation-knowledge-architecture-migration-review.md`

**Interfaces:**
- Consumes: Tasks 2-4 canonical paths and archive.
- Produces: complete curated direct-child catalogues, deterministic reading order, no empty category roots, and enforcement through the Docs Agent and repository setup validator.

- [ ] **Step 1: Add failing canonical-root and catalogue tests**

Extend `DocumentationNavigation.Tests.ps1` with helpers that:

```powershell
function Get-MetadataStatus {
    param([Parameter(Mandatory)][string]$Path)
    $content = Get-Content -LiteralPath $Path -Raw
    $match = [regex]::Match(
        $content,
        '(?m)^\| \*\*Status\*\* \| (?<Status>.*?) \|\r?$'
    )
    if (-not $match.Success) { throw "Missing Status metadata: $Path" }
    return $match.Groups['Status'].Value.Trim()
}

function Get-DirectMarkdownChildren {
    param([Parameter(Mandatory)][string]$Directory)
    return @(
        Get-ChildItem -LiteralPath $Directory -Filter '*.md' -File |
            Where-Object Name -ne 'README.md' |
            Sort-Object Name
    )
}

function Get-ExpectedDirectCatalogueTargets {
    param([Parameter(Mandatory)][string]$Directory)

    $files = @(Get-DirectMarkdownChildren -Directory $Directory |
        ForEach-Object FullName)
    $childReadmes = @(
        Get-ChildItem -LiteralPath $Directory -Directory |
            ForEach-Object { Join-Path $_.FullName 'README.md' } |
            Where-Object { Test-Path -LiteralPath $_ -PathType Leaf }
    )
    return @(($files + $childReadmes) | Sort-Object -Unique)
}

function Get-CatalogueRows {
    param([Parameter(Mandatory)][string]$ReadmePath)

    $content = Get-Content -LiteralPath $ReadmePath -Raw
    $directory = Split-Path -Parent $ReadmePath
    $catalogueHeading = [regex]::Match(
        $content,
        '(?m)^## Catalogue\s*$'
    )
    if (-not $catalogueHeading.Success) { return @() }

    $catalogueStart = $catalogueHeading.Index + $catalogueHeading.Length
    $remaining = $content.Substring($catalogueStart)
    $nextHeading = [regex]::Match($remaining, '(?m)^## [^#].*$')
    $catalogue = if ($nextHeading.Success) {
        $remaining.Substring(0, $nextHeading.Index)
    }
    else {
        $remaining
    }

    return @(
        [regex]::Matches(
            $catalogue,
            '(?m)^\|[^\r\n]*\]\((?<Target>[^)#?]+\.md)(?:#[^)]+)?\)\s*\|\s*(?<Status>[^|]+?)\s*\|'
        ) |
            ForEach-Object {
                $target = [Uri]::UnescapeDataString(
                    $_.Groups['Target'].Value
                ).Replace('/', '\')
                [pscustomobject]@{
                    Target = [IO.Path]::GetFullPath((Join-Path $directory $target))
                    Status = $_.Groups['Status'].Value.Trim()
                }
            } |
            Where-Object {
                $_.Target.StartsWith(
                    ([IO.Path]::GetFullPath($directory).TrimEnd('\') + '\'),
                    [StringComparison]::OrdinalIgnoreCase
                )
            }
    )
}
```

Add tests for these authoritative catalogue roots:

```powershell
$catalogueRoots = @(
    'docs/ideas'
    'docs/specs'
    'docs/plans'
    'docs/reviews'
    'docs/adr'
    'docs/brand'
    'docs/archive'
    'docs/archive/phase-2-operating-model'
    'hr/docs/use-cases'
    'infra/docs'
)
```

For each root, assert `README.md` exists and run:

```powershell
$expectedTargets = @(Get-ExpectedDirectCatalogueTargets -Directory $fullRoot)
$rows = @(Get-CatalogueRows -ReadmePath (Join-Path $fullRoot 'README.md'))
$actualTargets = @($rows.Target | Sort-Object -Unique)
$actualTargets | Should -Be $expectedTargets

foreach ($file in Get-DirectMarkdownChildren -Directory $fullRoot) {
    $matching = @($rows | Where-Object Target -CEQ $file.FullName)
    $matching.Count | Should -Be 1
    $matching[0].Status | Should -Be (Get-MetadataStatus -Path $file.FullName)
}
```

Every direct Markdown child and every direct child directory with its own README must appear. The exact target comparison rejects stale catalogue rows, and direct Markdown file status must equal metadata.

Also assert these roots are absent:

```powershell
@(
    'docs/brandkit'
    'docs/business'
    'docs/delegation'
    'docs/issues'
    'docs/sprints'
    'docs/templates'
    'docs/superpowers'
    'docs/operating-model'
    'hr/docs/ideas'
)
```

- [ ] **Step 2: Run navigation tests and verify red**

Expected failures: placeholder roots still exist, `infra/docs/README.md` is absent, and incomplete catalogues are identified by exact child.

- [ ] **Step 3: Remove only approved placeholder roots**

Use `git rm` on the six listed README files. Do not delete `docs/archive/`, infrastructure stop notices, or any non-placeholder content.

- [ ] **Step 4: Rebuild the knowledge map and direct-child catalogues**

Implement the README contract from the spec in every listed file:

1. Purpose and authority.
2. Contains and does not contain.
3. Reading order.
4. Naming and lifecycle.
5. Complete curated direct-child catalogue.
6. Domain links.
7. Board synchronization state where relevant.

Each row includes filename or stable ID, exact metadata status, purpose, authority, and successor/next stage. READMEs route; they do not repeat child requirements.

- [ ] **Step 5: Update repository setup validation**

Replace the documentation entries in `$baseFolders` inside `.github/cli/verify-repository-setup.ps1` with:

```powershell
'docs/adr'
'docs/archive'
'docs/archive/phase-2-operating-model'
'docs/brand'
'docs/ideas'
'docs/plans'
'docs/reviews'
'docs/specs'
'hr/docs/use-cases'
'infra/docs'
'data'
```

Keep the existing `.github/*` entries and the protected `.github/skills` handling unchanged.

- [ ] **Step 6: Strengthen the Docs Agent contract**

Update `.github/agents/docs-agent.agent.md` so its mandatory outputs include:

- owning README updated in the same PR;
- complete direct-child catalogue;
- correct lifecycle and domain placement;
- successor/archive link when status changes;
- `Deferred - not synchronized` rather than an invented Board ID.

Update `DocsAgentContract.Tests.ps1` to assert those phrases and the canonical paths.

- [ ] **Step 7: Document the external worktree convention**

Add this Windows convention to `.github/copilot-instructions.md` and `infra/docs/runbooks/01-developer-workstation.md`:

```powershell
$localAppData = [Environment]::GetFolderPath('LocalApplicationData')
if ([string]::IsNullOrWhiteSpace($localAppData)) {
    throw 'LocalApplicationData is unavailable.'
}
$worktreeRoot = Join-Path $localAppData 'CaldovaHrFrontier\worktrees'
$repositoryRoot = Join-Path $worktreeRoot 'caldova-hr-frontier'
New-Item -ItemType Directory -Path $repositoryRoot -Force | Out-Null
$probe = Join-Path $repositoryRoot ('.write-probe-{0}.tmp' -f [guid]::NewGuid().ToString('N'))
[IO.File]::WriteAllText($probe, 'permission-probe', [Text.UTF8Encoding]::new($false))
Remove-Item -LiteralPath $probe -Force
```

State that task worktrees append a sanitized branch name below this repository root, require no administrator rights, and are removed through `git worktree remove` after branch completion. Never loosen directory ACLs automatically; a failed probe is a blocking workstation prerequisite.

- [ ] **Step 8: Run navigation, docs-agent, metadata, links, and setup validation**

Run:

```powershell
Import-Module Pester -RequiredVersion 5.7.1 -Force
$result = Invoke-Pester -Path @(
    '.github\cli\tests\DocumentationNavigation.Tests.ps1'
    '.github\cli\tests\DocumentationMetadata.Tests.ps1'
    '.github\cli\tests\DocumentationLinks.Tests.ps1'
    '.github\cli\tests\DocsAgentContract.Tests.ps1'
) -Output Detailed -CI -PassThru
if ($result.FailedCount -gt 0) { throw "$($result.FailedCount) catalogue test(s) failed." }

powershell -NoProfile -ExecutionPolicy Bypass `
    -File .github/cli/verify-repository-setup.ps1 `
    -SkipIntegratedTests `
    -SkipBicepBuild
if ($LASTEXITCODE -ne 0) { throw 'Repository setup validation failed.' }
git diff --check
```

Expected: all selected tests pass and the setup validator prints `Repository setup validation passed.`

- [ ] **Step 9: Update migration evidence and commit**

```powershell
git add -- '.github' 'docs' 'hr' 'infra' 'data'
git commit -m "docs: establish canonical knowledge catalogues" `
    -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 6: Enforce Retired-Path Boundaries and Run Full Acceptance

**Files:**
- Modify: `.github/cli/tests/DocumentationNavigation.Tests.ps1`
- Modify: `docs/reviews/2026-10-02-documentation-knowledge-architecture-migration-review.md`
- Modify: `docs/reviews/README.md`

**Interfaces:**
- Consumes: complete migration from Tasks 1-5.
- Produces: fail-closed retired-path allowlist, Board-neutral and workflow-neutral acceptance, final hash evidence, full-suite results, and an Active migration review.

- [ ] **Step 1: Add the final retired-path, Board, and workflow tests**

Add an exact allowlist for old-path mentions. It contains:

```powershell
$exactHistoricalAllowlist = @(
    'docs/plans/2026-09-15-repository-superpowers-implementation.md'
    'docs/plans/2026-09-17-governance-github-intake-implementation.md'
    'docs/plans/2026-09-17-product-hr-operating-model-intake-implementation.md'
    'docs/plans/2026-09-24-hr-solution-functional-design-intake-implementation.md'
    'docs/plans/2026-09-25-azure-boards-population-implementation.md'
    'docs/plans/2026-10-01-caldova-branding-migration-implementation.md'
    'docs/reviews/2026-09-17-architecture-baseline-source-inventory.json'
    'docs/reviews/2026-09-17-phase-2-product-hr-operating-model-intake.md'
    'docs/reviews/2026-09-24-phase-4-hr-solution-functional-design-intake.md'
    'docs/specs/2026-09-17-architecture-baseline-intake-design.md'
    'docs/specs/2026-09-24-hr-solution-functional-design-intake-design.md'
    'docs/specs/2026-09-25-azure-boards-population-design.md'
    'docs/specs/2026-10-02-documentation-knowledge-architecture-cleanup-design.md'
    'docs/plans/2026-10-02-documentation-knowledge-architecture-cleanup-implementation.md'
    'docs/reviews/2026-10-02-documentation-knowledge-architecture-migration-review.md'
    'docs/archive/phase-2-operating-model/00-north-star.md'
    'docs/archive/phase-2-operating-model/01-prd.md'
    'docs/archive/phase-2-operating-model/02-system-design.md'
    'docs/archive/phase-2-operating-model/03-agent-operating-model.md'
    'docs/archive/phase-2-operating-model/04-hitl-governance.md'
    'docs/archive/phase-2-operating-model/05-implementation-roadmap.md'
    'docs/archive/phase-2-operating-model/90-microsoft-best-practice-evaluation.md'
    'docs/archive/phase-2-operating-model/20-hr-employee-journey.md'
)
```

Files below `.github/skills/` are separately allowed because they are vendored and immutable. Every other match fails. Before final acceptance, review each historical allowlist entry and remove it if the migration no longer leaves an old-path fact in that file.

The prohibited patterns are:

```text
docs/superpowers/
docs/operating-model/
docs/brandkit/
docs/business/
docs/delegation/
docs/issues/
docs/sprints/
docs/templates/
hr/docs/ideas/
```

The test enumerates `git grep -I -n` matches and fails with the exact unallowlisted file and line.

Add tests that:

- every `docs/ideas/README.md` row says `Deferred - not synchronized` or `Not applicable`;
- no central idea file contains `AB#` followed by digits;
- `.github/pull_request_template.md` requires a repository governing record and permits `Fixes AB#` only after verified synchronization;
- `.github/workflows/` contains exactly `README.md` and `validate-repository.yml`; and
- `git diff --name-only <baseline>...HEAD -- .github/workflows` is empty for the migration range.

- [ ] **Step 2: Run the final navigation contract and verify any remaining failures are real**

Run:

```powershell
Import-Module Pester -RequiredVersion 5.7.1 -Force
$result = Invoke-Pester -Path '.github\cli\tests\DocumentationNavigation.Tests.ps1' `
    -Output Detailed -CI -PassThru
if ($result.FailedCount -gt 0) {
    $result.Failed | Format-List *
    throw "$($result.FailedCount) navigation acceptance test(s) failed."
}
```

Expected: pass. Do not add a broad exception to silence a remaining active reference.

If an unexpected active file fails the allowlist test, stop and amend this plan with that exact path and reviewed disposition before editing it.

- [ ] **Step 3: Compare every moved binary and immutable snapshot hash**

Load `docs/reviews/evidence/2026-10-02-documentation-knowledge-architecture/migration-baseline.json` and re-run the Task 1 baseline comparison for:

- all 48 corpus PDFs;
- both CSV and JSON truth files;
- all Python generators and package READMEs that were not intentionally link-edited;
- all 7 immutable evidence PDFs at their unchanged paths; and
- all 8 archived Phase 2 snapshots.

Record file count, expected hash, actual hash, and verdict in the migration review. A mismatch blocks acceptance; do not regenerate a file as a substitute.

- [ ] **Step 4: Run the complete maintained Pester suite**

Run the same discovery model as `.github/workflows/validate-repository.yml`:

```powershell
Import-Module Pester -RequiredVersion 5.7.1 -Force
$githubTests = @(
    Get-ChildItem -LiteralPath '.github\cli\tests' -Filter '*.Tests.ps1' -File |
        Sort-Object FullName |
        Select-Object -ExpandProperty FullName
)
$result = Invoke-Pester -Path @(
    $githubTests + @('infra\tests\pester', 'hr\tests\pester')
) -Output Detailed -CI -PassThru
if ($result.FailedCount -gt 0) {
    throw "$($result.FailedCount) maintained test(s) failed."
}
```

Expected: zero failed tests. Record discovered, passed, failed, skipped, inconclusive, and not-run counts.

- [ ] **Step 5: Run repository safety, comprehensive setup, and Bicep validation**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
    -File .github/cli/verify-repository-safety.ps1
if ($LASTEXITCODE -ne 0) { throw 'Repository safety validation failed.' }

powershell -NoProfile -ExecutionPolicy Bypass `
    -File .github/cli/verify-repository-setup.ps1
if ($LASTEXITCODE -ne 0) { throw 'Repository setup validation failed.' }

$entryPoints = @(
    Get-ChildItem -LiteralPath 'infra\src\bicep' -Filter '*.bicep' -File -Recurse |
        Sort-Object FullName
)
if ($entryPoints.Count -eq 0) { throw 'No maintained Bicep entry point was found.' }
foreach ($entryPoint in $entryPoints) {
    az bicep build --file $entryPoint.FullName --stdout | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Bicep build failed: $($entryPoint.FullName)" }
}
```

Expected: both PowerShell validators print their success line and every Bicep build exits `0`.

- [ ] **Step 6: Verify branch scope and whitespace**

Run:

```powershell
$base = git merge-base origin/main HEAD
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($base)) {
    throw 'Cannot resolve the origin/main merge base.'
}

git diff --check "$base...HEAD"
if ($LASTEXITCODE -ne 0) { throw 'Whitespace validation failed.' }

$workflowChanges = @(git diff --name-only "$base...HEAD" -- '.github/workflows')
if ($workflowChanges.Count -ne 0) {
    throw "Workflow changes are outside scope: $($workflowChanges -join ', ')"
}
```

Expected: no whitespace errors and no workflow changes.

- [ ] **Step 7: Finalize the migration review**

Set the review status to `Active`. Record:

- baseline and final commit;
- every path disposition;
- before/after hash result;
- targeted and full-suite commands with observed counts;
- repository safety, setup, Bicep, whitespace, Board-neutral, and workflow-neutral verdicts;
- all exact historical exceptions; and
- `None` for unresolved failures only when the evidence supports it.

Update `docs/reviews/README.md` from `Draft` to `Active`.

- [ ] **Step 8: Commit final acceptance evidence**

```powershell
$remaining = @(git diff --name-only)
$forbidden = @($remaining | Where-Object {
    $_ -like '.github/workflows/*' -or
    $_ -like 'infra/src/config/*azure*boards*'
})
if ($forbidden.Count -gt 0) {
    throw "Out-of-scope final changes: $($forbidden -join ', ')"
}
git add -- $remaining
git commit -m "test: verify documentation knowledge migration" `
    -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

- [ ] **Step 9: Verify the committed result**

Run:

```powershell
git status --short
git --no-pager log -6 --oneline
```

Expected: the working tree is clean and the six scoped task commits are visible. Do not begin repository-agent implementation until the migration review is Active and every acceptance command above has fresh passing evidence.
