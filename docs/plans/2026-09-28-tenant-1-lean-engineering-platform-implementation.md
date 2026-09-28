# Tenant 1 Lean Engineering Platform Implementation Plan

| Field | Value |
|---|---|
| **Version** | 1.1 |
| **Date** | 2026-09-29 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Draft |
| **Scope** | Tenant 1 lean engineering platform, current sprint only |
| **References** | [Approved Tenant 1 Lean Engineering Platform Design](../specs/2026-09-28-tenant-1-lean-engineering-platform-design.md), [Active Tenant 1 Configuration Review](../reviews/2026-09-28-tenant-1-engineering-platform-configuration-review.md), [Superseded Foundation Plan](2026-09-28-tenant-1-engineering-control-plane-foundation-implementation.md), [ADR-0001](../adr/0001-azure-devops-as-engineering-control-plane.md), [ADR-0002](../adr/0002-github-first-bootstrap-and-the-role-of-azure-repos.md), [ADR-0012](../adr/0012-per-tenant-github-repository-and-account-topology.md) |

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish the approved lean Tenant 1 engineering foundation with one comprehensive GitHub validator, minimal GitHub governance, local attended Tenant 1 validation, a Basic Azure Boards traceability Issue, and one real governed `Fixes AB#` transaction.

**Architecture:** Start from the reviewed Task 1 head in a new clean worktree so the superseded 112-file Task 2 change and its partial uncommitted repair never enter the lean branch. GitHub remains the sole product-source and pull-request authority; Azure Boards remains the Basic-process backlog; ignored local Tenant 1 configuration and the attended operator's pre-existing, separately approved least-privilege access drive discovery and subscription `what-if`; one GitHub Actions job validates all maintained repository surfaces. Live changes are separated by attended checkpoints, use exact stable identifiers, fail closed on incomplete read-back, perform no role mutation, and never create an Azure deployment, Azure Pipeline, or Power Platform deployment.

**Tech Stack:** Windows PowerShell 5.1, Pester 5.7.1, Git, GitHub CLI, Azure CLI, Azure DevOps CLI extension 1.0.8, Azure DevOps REST API 7.1, GitHub REST API `2022-11-28`, JSON Schema draft 2020-12, Bicep CLI.

**Spec:** [`docs/specs/2026-09-28-tenant-1-lean-engineering-platform-design.md`](../specs/2026-09-28-tenant-1-lean-engineering-platform-design.md)

## Global Constraints

- Execute only in `C:\Users\urruegg\source\urruegg\caldova-hr-frontier\.worktrees\tenant1-lean-platform` after Task 1 creates it.
- Create branch `feat/tenant1-lean-platform` from reviewed Task 1 head `dc6ad37e63a71e1d04674964ccda9ba38ea4e332`; cherry-pick approved lean decision commit `e01ca1156bb973c5c90c2ebe5cbe7c7453219e6c` and the attended future commit containing this plan.
- Never revert `6b9eaa6` in place. Never clean, reset, stash, checkout, modify, or delete `C:\Users\urruegg\source\urruegg\caldova-hr-frontier\.worktrees\tenant1-engineering-platform-review`.
- Preserve that historical worktree on the lineage containing `e01ca1156bb973c5c90c2ebe5cbe7c7453219e6c` and the future plan commit, with its existing uncommitted change to `infra/tests/pester/CloudFoundationStaticSafety.Tests.ps1`.
- Do not create or run an Azure Pipeline, service connection, artifact, Power Platform import, infrastructure deployment, or `az deployment sub create`.
- Do not activate tenant trust, create a bootstrap Entra application or service principal, add a federated credential, create a `bootstrap-tenant1` GitHub Environment, or fetch private configuration in a workflow.
- Keep `infra/src/config/tenants/_template.psd1` tracked and synthetic. Keep Tenant 1 configuration only at ignored path `infra/src/config/tenants/tenant1.local.psd1`.
- Preserve these exact Tenant 2 blobs unchanged from the clean base: `f4b2dfed2f42d1d9d95d51dddaeaaedf4d8b6dce` at `infra/src/config/tenants/caldova25668747.psd1` and `c2d4d66f4f812fc449752c275845fac5a713915e` at `infra/evidence/discovery/caldova25668747.json`.
- Do not create a tenant catalogue, legacy-transition manifest, private overlay, transition package, handoff package, or automation for Tenant 2.
- Local configuration contains values only, never credentials or tokens. Raw discovery, access-preflight detail, generated parameters, `what-if` output, hashes, and backups remain outside Git.
- All live scripts require explicit `-PublicTenantKey tenant1` and `-TenantConfigurationPath 'infra\src\config\tenants\tenant1.local.psd1'`; they fail before external access if the path is missing, tracked, the template, outside the exact ignored boundary, unreadable, schema-invalid, or identifies another public tenant.
- `403`, `404`, an empty response, malformed JSON, ambiguity, timeout, unsupported capability, or failed read-back is a blocking error. Only an explicitly documented post-delete `404` proves a separately approved Azure Repo deletion.
- Local validation uses the attended operator's pre-existing, separately approved least-privilege access. This sprint creates, changes, and deletes no role assignment; context and minimum-access preflight/read-back fail closed on mismatch or insufficient evidence.
- GitHub governance mutation requires a successful completed run of `.github/workflows/validate-repository.yml` on the current `main` SHA and the exact job/check `Repository setup validation`.
- Azure Boards remains on the built-in Basic process, existing team, and project-root area. Do not convert to Agile, create six iterations, create a second team or area, or alter the optional 19-Epic portfolio tooling.
- Every implementation change follows red/green/refactor, a scoped review, and a scoped commit. Every new commit uses `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>`.
- Install nothing proactively. If a focused test proves Pester 5.7.1 absent, install exactly that version for the current user, rerun the failed command, and record the prerequisite correction.

---

## Execution Baseline and Review Protocol

The current historical branch contains:

- reviewed Task 1 head `dc6ad37e63a71e1d04674964ccda9ba38ea4e332`;
- superseded Task 2 commit `6b9eaa6`, which touches 112 files;
- approved lean decision commit `e01ca1156bb973c5c90c2ebe5cbe7c7453219e6c`; and
- an uncommitted partial edit to `infra/tests/pester/CloudFoundationStaticSafety.Tests.ps1`.

That state is evidence, not an execution base. Task 1 creates a clean branch instead of trying to separate the 112-file commit in place.

At the start of every task:

```powershell
Set-Location 'C:\Users\urruegg\source\urruegg\caldova-hr-frontier\.worktrees\tenant1-lean-platform'
$TaskBase = git rev-parse HEAD
if ($LASTEXITCODE -ne 0) { throw 'Cannot record the task review base.' }
```

Before each task commit:

```powershell
git diff --check
if ($LASTEXITCODE -ne 0) { throw 'Whitespace validation failed.' }
git status --short
git diff --stat $TaskBase
git diff $TaskBase -- .
```

After each task commit, use the `requesting-code-review` skill against `$TaskBase..HEAD`. Resolve every high-confidence correctness or scope finding before starting the next task. At the end of Task 8, request a final review against:

```powershell
$ReviewBase = git merge-base origin/main HEAD
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($ReviewBase)) {
    throw 'Cannot resolve the final review merge base.'
}
git diff --stat "$ReviewBase..HEAD"
```

Never use `HEAD~5`, `HEAD~7`, or another fixed history depth for task or final review.

## File and Interface Map

| Unit | Exact paths | Responsibility |
|---|---|---|
| Clean execution and decisions | `docs/adr/0001-azure-devops-as-engineering-control-plane.md`, `docs/adr/0002-github-first-bootstrap-and-the-role-of-azure-repos.md`, `docs/adr/0012-per-tenant-github-repository-and-account-topology.md`, `docs/adr/README.md`, `docs/README.md`, `README.md`, `infra/tests/pester/EngineeringControlPlaneDocumentation.Tests.ps1` | Reconcile current authority to Option A without rewriting historical review evidence. |
| Single validator | `.github/workflows/validate-repository.yml`, `.github/workflows/audit-repository.yml`, `.github/workflows/discover-tenant.yml`, `.github/workflows/bootstrap-tenant.yml`, `.github/workflows/README.md`, `.github/cli/tests/WorkflowContract.Tests.ps1`, `.github/cli/verify-repository-setup.ps1`, `infra/tests/pester/WorkflowContract.Tests.ps1`, `infra/src/config/github/action-pins.json` | Leave one workflow and one check named exactly `Repository setup validation`; retire workflow-only contracts and pins. |
| Local boundary | `.gitignore`, `infra/src/config/tenants/_template.psd1`, `infra/src/config/schemas/tenant.schema.json`, `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Import-TenantConfiguration.ps1`, module manifests, three active scripts and their focused tests | Require explicit ignored Tenant 1 local configuration and reject template, tracked, wrong-tenant, or implicit paths. |
| Attended validation | `infra/src/scripts/Invoke-TenantBootstrap.ps1`, `infra/tests/pester/Idempotency.Tests.ps1`, `infra/tests/pester/WhatIfBoundary.Tests.ps1`, `infra/docs/24-tenant-1-lean-platform-runbook.md`, active infrastructure documentation | Execute attended-context and minimum-access preflight/read-back, discovery, sanitized review, Bicep build, subscription `what-if`, and boundary validation locally; never mutate roles or deploy. Dormant role scripts remain outside this dependency graph. |
| GitHub governance | `infra/src/config/github/main-ruleset.json`, `infra/src/config/schemas/github-ruleset.schema.json`, `infra/src/scripts/Enable-GitHubGovernance.ps1`, `infra/tests/pester/GitHubGovernance.Tests.ps1`, `.github/CODEOWNERS`, `.github/pull_request_template.md` | Gate mutation only on current-main validation, apply minimal rules/settings/security updates, and perform exact read-back. |
| Basic Boards | `infra/src/scripts/Initialize-AzureBoardsLeanSprint.ps1`, `infra/tests/pester/AzureBoardsLeanSprint.Tests.ps1`, `infra/docs/21-azure-boards-population-runbook.md`, lean operator runbook | Verify Basic/team/root area, optionally set approved current-sprint dates, and create or reuse one durable Issue without changing the 19-Epic tool. |
| Acceptance and safety | `.github/cli/verify-repository-safety.ps1`, `.github/cli/tests/RepositorySafety.Tests.ps1`, `infra/tests/pester/CloudFoundationStaticSafety.Tests.ps1`, `infra/tests/pester/RunbookDocumentation.Tests.ps1`, `docs/reviews/2026-09-28-tenant-1-lean-engineering-platform-acceptance-review.md`, `docs/reviews/README.md` | Enforce the private boundary, remove fixed-depth history assumptions, record only sanitized evidenced outcomes, and prove acceptance. |

## Locked Interfaces

### Tenant configuration import

```powershell
Import-TenantConfiguration `
    -Path [string] `
    -ValidationStage [Discovery|Bootstrap] `
    -ExpectedPublicTenantKey [string] `
    -RequireLocalUntracked
```

`-ExpectedPublicTenantKey` is mandatory for every active live script. `-RequireLocalUntracked` resolves the repository root, accepts only `infra\src\config\tenants\{PublicTenantKey}.local.psd1`, rejects `_template.psd1`, rejects any `git ls-files` match, requires `git check-ignore` success, and returns a read-only validated configuration. Tests may omit `-RequireLocalUntracked` only for synthetic `TestDrive` fixtures.

### Active local scripts

```text
Invoke-TenantDiscovery.ps1
  -PublicTenantKey [string] -TenantConfigurationPath [string]
  -AuthenticationMode Interactive -OutputPath [string]
  [-PowerPlatformProbePath [string]] [-Replace] [-ContextAccountPath [string]]

New-TenantBicepParameters.ps1
  -PublicTenantKey [string] -TenantConfigurationPath [string]
  -ValidationPrincipalId [guid] -OutputPath [string] [-Replace]

Invoke-TenantBootstrap.ps1
  -PublicTenantKey [string] -TenantConfigurationPath [string]
  -EvidencePath [string] -ParameterFile [string] -WhatIfOnly
```

Discovery evidence and generated parameters resolve outside the repository. `Invoke-TenantBootstrap.ps1` validates the attended signed-in user, exact tenant and subscription, separately approved pre-existing minimum access, and post-operation context; it never uses an OIDC workload context and performs no role mutation.

### Minimal governance

```powershell
.\infra\src\scripts\Enable-GitHubGovernance.ps1 `
    -Repository 'urruegg/caldova-hr-frontier' `
    -ValidatorRunId $ValidatorRunId `
    -DesiredStatePath 'infra\src\config\github\main-ruleset.json' `
    [-WhatIf] [-Confirm]
```

There is no bootstrap run ID, bootstrap evidence path, Environment, tenant manifest, Azure account, service principal, or Azure role input.

### Basic Boards

```powershell
.\infra\src\scripts\Initialize-AzureBoardsLeanSprint.ps1 `
    -OrganizationUrl $OrganizationUrl `
    -ProjectName 'Caldova HR Frontier' `
    -TeamName $TeamName `
    -CurrentSprintPath $CurrentSprintPath `
    -IssueTitle 'Tenant 1 lean engineering platform acceptance' `
    -PlanOutputPath $PlanOutputPath `
    [-SprintStartDate $SprintStartDate -SprintFinishDate $SprintFinishDate] `
    [-Apply] [-Confirm]
```

Both sprint dates are supplied together or both are omitted. The script produces one closed plan/read-back object with `ProcessName`, `TeamName`, `AreaPath`, `IterationPath`, `StartDate`, `FinishDate`, `IssueId`, `IssueMode`, and `Status`.

## Control Disposition

| Removed or deferred from this sprint | Replacement now |
|---|---|
| Private Tenant 1 Azure Repo as configuration store | Ignored local `tenant1.local.psd1`, encrypted external backup, restore/hash/schema test |
| OIDC bootstrap, `bootstrap-tenant1` Environment, workflow configuration retrieval | Attended user authentication and explicit local path |
| `discover-tenant.yml` and `bootstrap-tenant.yml` | Local operator runbook |
| Advisory `audit-repository.yml` | One required comprehensive validator |
| Separate traceability workflow | PR template, human review, Azure Boards GitHub App, real transaction |
| Bootstrap, non-production, and production identities | Attended operator for this sprint; future delivery identities require a new design |
| Basic-to-Agile conversion and six generated iterations | Existing Basic process/team/root area and current sprint only |
| Required Azure DevOps template control | Future Azure Pipeline design |
| Tenant catalogue, legacy-transition file, private overlay, package automation | No replacement; YAGNI |
| Automated rebuild and multi-tenant bootstrap | Attended recovery from tested external backup |

`Initialize-TenantTrust.ps1` may remain as dormant source because deleting a large, potentially reusable implementation adds no current value. Its active test and maintained runbook references are removed; validation does not execute it; active documentation states that it is unsupported in this sprint and requires a new design before reuse.

## Ownership and Attended Approvals

| Owner | Current-sprint responsibility | Approval that cannot be delegated |
|---|---|---|
| Repository owner | Lean branch history, one-workflow inventory, source changes, GitHub pre-state, governance proposal, and rollback branch | Approve governance mutation only after tool changes are on `main` and the current-main validator is green |
| Tenant 1 attended operator | Own `tenant1.local.psd1`, restrict its access, maintain the encrypted external backup in a separate failure domain, prove restore/hash/schema, and run attended-context/minimum-access preflight, discovery, `what-if`, and read-back | Provide the separate approval record for pre-existing minimum access and confirm public Tenant 1 file removal only after backup proof |
| Azure DevOps project administrator | Verify Basic process/team/root area, approve optional current-sprint dates, read back the Boards GitHub App, and inspect the empty Azure Repo proof | Approve the exact Azure Repo deletion separately; no other checkpoint implies this approval |
| Pull-request author and attended repository owner | Use the real `Fixes AB#` reference, pass validation, resolve conversations, and complete the governed proof | Confirm the solo-owner gate and squash-merge the real proof pull request |
| Future release owner and independent approver | Design a later GitHub-sourced Azure Pipeline and TEST-to-PROD path | No current-sprint deployment or release approval exists |

## Failure and Rollback Semantics

- A cherry-pick conflict aborts Task 1. Run `git cherry-pick --abort`, preserve both worktrees, and return for review; do not resolve an approved decision patch by improvisation.
- A failed local backup or restore/hash/schema check blocks removal of committed Tenant 1 files.
- A failed local operation records the attended principal, tenant, subscription, and access preflight state, performs no role mutation, and stops all later checkpoints.
- A GitHub or Azure Boards pre-state mismatch causes zero mutation. A post-mutation mismatch stops subsequent mutations and requires attended rollback from captured pre-state.
- Repository source rollback uses a reviewed revert or corrective pull request; never reset protected history.
- GitHub settings rollback restores captured repository settings and the exact prior ruleset payload by stable ruleset ID, then reads both back.
- Boards rollback restores only the captured current-sprint dates. The durable Issue is not deleted or hidden to simulate rollback.
- Local configuration recovery restores from the encrypted external backup, verifies SHA-256 and schema, and reruns discovery. It is never recommitted.
- The empty Azure Repo is not deleted unless the attended pre-state proves `size = 0`, no default branch, no refs, and no items. If deleted, future need creates a new reviewed repository; no content rollback is claimed.
- No deployment rollback exists because deployment creation is prohibited.

---

### Task 1: Create the Clean Lean Worktree and Reconcile the Approved Decisions

**Files:**
- Modify: `docs/adr/0001-azure-devops-as-engineering-control-plane.md`
- Modify: `docs/adr/0002-github-first-bootstrap-and-the-role-of-azure-repos.md`
- Modify: `docs/adr/0012-per-tenant-github-repository-and-account-topology.md`
- Modify: `docs/adr/README.md`
- Modify: `docs/README.md`
- Modify: `README.md`
- Modify: `infra/tests/pester/EngineeringControlPlaneDocumentation.Tests.ps1`

**Interfaces:**
- Consumes: reviewed base `dc6ad37e63a71e1d04674964ccda9ba38ea4e332`, lean decision `e01ca1156bb973c5c90c2ebe5cbe7c7453219e6c`, and one attended 40-character plan commit SHA.
- Produces: clean branch `feat/tenant1-lean-platform`, clean worktree path, and three Approved ADRs aligned to Option A.

- [ ] **Step 1: Capture and verify the preserved historical state without changing it**

```powershell
$PrimaryRoot = 'C:\Users\urruegg\source\urruegg\caldova-hr-frontier'
$HistoricalRoot = Join-Path $PrimaryRoot '.worktrees\tenant1-engineering-platform-review'
$HistoricalHead = git -C $HistoricalRoot rev-parse HEAD
if ($HistoricalHead -cnotmatch '^[0-9a-f]{40}$') { throw 'Cannot read the historical worktree head.' }
$HistoricalChanges = @(git -C $HistoricalRoot status --porcelain=v1)
if ($HistoricalChanges -notcontains ' M infra/tests/pester/CloudFoundationStaticSafety.Tests.ps1') {
    throw 'Expected historical partial safety-test edit is absent; stop before creating a lean worktree.'
}
```

Expected: the historical head and protected partial edit are present. Do not run any modifying Git command against `$HistoricalRoot`.

- [ ] **Step 2: Obtain and validate the future plan commit as an attended input**

```powershell
$PlanCommit = (Read-Host 'Enter the committed SHA containing this plan, its catalogue update, and the solo-owner lean-design revision').Trim()
if ($PlanCommit -cnotmatch '^[0-9a-f]{40}$') {
    throw 'The plan commit must be a full lowercase 40-character SHA.'
}
git -C $PrimaryRoot cat-file -e "$PlanCommit^{commit}"
if ($LASTEXITCODE -ne 0) { throw 'The attended plan SHA is not a commit in this repository.' }
$PlanPaths = @(git -C $PrimaryRoot diff-tree --no-commit-id --name-only -r $PlanCommit | Sort-Object)
$ExpectedPlanPaths = @(
    'docs/plans/2026-09-28-tenant-1-lean-engineering-platform-implementation.md'
    'docs/plans/README.md'
    'docs/specs/2026-09-28-tenant-1-lean-engineering-platform-design.md'
) | Sort-Object
if (($PlanPaths -join "`n") -cne ($ExpectedPlanPaths -join "`n")) {
    throw "The plan commit contains an unexpected path set: $($PlanPaths -join ', ')"
}
if ($HistoricalHead -notin @('e01ca1156bb973c5c90c2ebe5cbe7c7453219e6c', $PlanCommit)) {
    throw "Historical worktree moved to an unexpected commit: $HistoricalHead"
}
```

Expected: the attended commit contains exactly the new plan and its catalogue update. Do not invent or pre-record a hash.

- [ ] **Step 3: Create the clean branch/worktree and cherry-pick only the approved commits**

```powershell
$LeanRoot = Join-Path $PrimaryRoot '.worktrees\tenant1-lean-platform'
if (Test-Path -LiteralPath $LeanRoot) { throw "Lean worktree already exists: $LeanRoot" }
git -C $PrimaryRoot show-ref --verify --quiet refs/heads/feat/tenant1-lean-platform
if ($LASTEXITCODE -eq 0) { throw 'Lean branch already exists; stop for attended review.' }

git -C $PrimaryRoot worktree add -b feat/tenant1-lean-platform $LeanRoot dc6ad37e63a71e1d04674964ccda9ba38ea4e332
if ($LASTEXITCODE -ne 0) { throw 'Failed to create the lean worktree.' }
git -C $LeanRoot cherry-pick e01ca1156bb973c5c90c2ebe5cbe7c7453219e6c
if ($LASTEXITCODE -ne 0) {
    git -C $LeanRoot cherry-pick --abort
    throw 'Lean decision cherry-pick conflicted and was aborted.'
}
git -C $LeanRoot cherry-pick $PlanCommit
if ($LASTEXITCODE -ne 0) {
    git -C $LeanRoot cherry-pick --abort
    throw 'Plan cherry-pick conflicted and was aborted.'
}
```

Expected: both cherry-picks succeed without carrying their parent commit.

- [ ] **Step 4: Prove the superseded commit and partial diff are absent**

```powershell
git -C $LeanRoot merge-base --is-ancestor 6b9eaa6 HEAD
if ($LASTEXITCODE -eq 0) { throw 'Superseded Task 2 is an ancestor of the lean branch.' }
git -C $LeanRoot diff --quiet dc6ad37e63a71e1d04674964ccda9ba38ea4e332 -- infra/tests/pester/CloudFoundationStaticSafety.Tests.ps1
if ($LASTEXITCODE -ne 0) { throw 'The historical partial safety-test edit leaked into the lean branch.' }
if (@(git -C $LeanRoot status --porcelain=v1).Count -ne 0) {
    throw 'The new lean worktree is not clean after bootstrap.'
}
```

Expected: `6b9eaa6` is not an ancestor, the safety test equals the reviewed base, the lean worktree is clean, and the historical worktree remains unchanged.

- [ ] **Step 5: Write the failing decision contract**

Replace the current old-topology assertions in `infra/tests/pester/EngineeringControlPlaneDocumentation.Tests.ps1` with:

```powershell
It 'records Option A as the approved current target' {
    $documents = $script:AdrPaths | ForEach-Object {
        Get-Content -Raw (Join-Path $script:Root $_)
    }
    foreach ($content in $documents) {
        $content | Should -Match '\|\s+\*\*Status\*\*\s+\|\s+Approved\s+\|'
        $content | Should -Match '2026-09-28-tenant-1-lean-engineering-platform-design\.md'
    }
    ($documents -join "`n") | Should -Not -Match 'private Azure Repo.+current target'
    ($documents -join "`n") | Should -Not -Match 'bootstrap-tenant1.+current target'
    ($documents -join "`n") | Should -Not -Match 'convert.+Basic.+Agile'
}

It 'keeps GitHub as source authority Boards as backlog and Azure Pipelines as future delivery' {
    $adr1 = Get-Content -Raw (Join-Path $script:Root $script:AdrPaths[0])
    $adr1 | Should -Match 'GitHub.+sole product-source'
    $adr1 | Should -Match 'Azure Boards.+single delivery backlog'
    $adr1 | Should -Match 'future Azure Pipeline.+directly.+GitHub'
    $adr1 | Should -Not -Match 'Azure Pipeline.+current sprint'
}
```

- [ ] **Step 6: Run the focused test and verify red**

```powershell
Set-Location $LeanRoot
Invoke-Pester -Path 'infra\tests\pester\EngineeringControlPlaneDocumentation.Tests.ps1' -Output Detailed
```

Expected: FAIL because the ADRs still describe the superseded private-repository/bootstrap topology.

- [ ] **Step 7: Reconcile the ADRs and catalogues**

Use these exact rulings:

```markdown
## Decision

GitHub is the sole product-source and pull-request authority. Azure Boards is the
single delivery backlog and remains on the built-in Basic process. Repository
validation runs in GitHub Actions. A future Azure Pipeline will consume this GitHub
repository directly for HR solution CI/CD; no Azure Pipeline is created this sprint.

Tenant 1 private configuration is an ignored local file with an encrypted,
restore-tested backup outside Git. A private Azure Repo, OIDC bootstrap,
`bootstrap-tenant1` Environment, cloud workflow retrieval, and Basic-to-Agile
conversion are not current targets.
```

Give ADR-0001 the source/backlog/future-delivery ruling, ADR-0002 the no-current-Azure-Repo/no-mirror ruling, and ADR-0012 the per-tenant GitHub plus local-private-configuration ruling. Set each to Version `3.0`, Date `2026-09-28`, Status `Approved`, and reference the approved lean design. Update `docs/adr/README.md`, `docs/README.md`, and root `README.md` so their authority maps point to the lean design and no catalogue presents the superseded private Repo, OIDC bootstrap, or Agile conversion as current.

- [ ] **Step 8: Run focused documentation validation and verify green**

```powershell
Invoke-Pester -Path @(
    'infra\tests\pester\EngineeringControlPlaneDocumentation.Tests.ps1'
    '.github\cli\tests\DocumentationLinks.Tests.ps1'
    '.github\cli\tests\DocumentationMetadata.Tests.ps1'
) -Output Detailed
```

Expected: PASS.

- [ ] **Step 9: Commit the clean bootstrap decision slice**

```powershell
git add README.md docs/README.md docs/adr infra/tests/pester/EngineeringControlPlaneDocumentation.Tests.ps1
git commit -m 'docs: reconcile lean platform decisions' -m 'Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>'
```

Expected: one documentation-and-contract commit. Review `$TaskBase..HEAD` before Task 2.

---

### Task 2: Consolidate Repository Validation into One Workflow

**Files:**
- Modify: `.github/workflows/validate-repository.yml`
- Delete: `.github/workflows/audit-repository.yml`
- Delete: `.github/workflows/discover-tenant.yml`
- Delete: `.github/workflows/bootstrap-tenant.yml`
- Modify: `.github/workflows/README.md`
- Modify: `.github/cli/tests/WorkflowContract.Tests.ps1`
- Modify: `.github/cli/verify-repository-setup.ps1`
- Delete: `infra/tests/pester/WorkflowContract.Tests.ps1`
- Modify: `infra/src/config/github/action-pins.json`
- Modify: `.github/pull_request_template.md`
- Test: `.github/cli/tests/RepositorySafety.Tests.ps1`

**Interfaces:**
- Consumes: Pester 5.7.1, pinned `actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1`, Bicep CLI, full Git history.
- Produces: exactly one workflow file and one job/check named `Repository setup validation`.

- [ ] **Step 1: Replace the workflow contract with a failing comprehensive contract**

```powershell
Describe 'Lean repository validation workflow' {
    It 'keeps exactly one least-privilege workflow and one stable job' {
        $workflowRoot = Join-Path $script:repositoryRoot '.github\workflows'
        $workflows = @(Get-ChildItem -LiteralPath $workflowRoot -Filter '*.yml' -File)
        $workflows.Name | Should -Be @('validate-repository.yml')
        $content = Get-Content -Raw -LiteralPath $workflows[0].FullName
        $content | Should -Match '(?m)^permissions:\r?\n  contents: read\r?$'
        $content | Should -Match 'actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1'
        @([regex]::Matches($content, '(?m)^\s{2}[a-z][a-z0-9_-]*:\r?$')).Count | Should -Be 1
        $content | Should -Match '(?m)^\s+name: Repository setup validation\r?$'
        $content | Should -Not -Match '(?m)^\s*(?:id-token|actions|pull-requests):\s+write\r?$'
    }

    It 'runs every maintained test safety build and merge-base whitespace check' {
        $content = Get-Content -Raw -LiteralPath $script:workflowPath
        $content | Should -Match 'Get-ChildItem.+\.github[/\\]cli[/\\]tests.+\*\.Tests\.ps1'
        $content | Should -Match "'infra[/\\]tests[/\\]pester'"
        $content | Should -Match "'hr[/\\]tests[/\\]pester'"
        $content | Should -Match 'verify-repository-safety\.ps1'
        $content | Should -Match 'Get-ChildItem.+infra[/\\]src[/\\]bicep.+-Recurse.+\*\.bicep'
        $content | Should -Match 'git merge-base'
        $content | Should -Match 'git diff --check'
        $content | Should -Not -Match 'HEAD~\d+'
    }
}
```

- [ ] **Step 2: Run the focused contract and verify red**

```powershell
Invoke-Pester -Path '.github\cli\tests\WorkflowContract.Tests.ps1' -Output Detailed
```

Expected: FAIL because four workflows exist and `validate-repository.yml` omits seven `.github/cli/tests` files.

- [ ] **Step 3: Implement the one-job workflow**

Use this test and build body in `.github/workflows/validate-repository.yml` while preserving its triggers, `windows-2025`, `timeout-minutes: 15`, checkout SHA, and `fetch-depth: 0`:

```yaml
      - name: Run all maintained tests
        shell: powershell
        run: |
          $ErrorActionPreference = 'Stop'
          $githubTests = @(
            Get-ChildItem -LiteralPath '.github\cli\tests' -Filter '*.Tests.ps1' -File |
              Sort-Object FullName |
              Select-Object -ExpandProperty FullName
          )
          $result = Invoke-Pester -Path @($githubTests + @('infra\tests\pester', 'hr\tests\pester')) -Output Detailed -CI -PassThru
          if ($result.FailedCount -gt 0) {
            throw "$($result.FailedCount) maintained test(s) failed."
          }

      - name: Run repository safety validation
        shell: powershell
        run: powershell -NoProfile -ExecutionPolicy Bypass -File .github/cli/verify-repository-safety.ps1

      - name: Build every maintained Bicep entry point
        shell: powershell
        run: |
          $ErrorActionPreference = 'Stop'
          $entryPoints = @(
            Get-ChildItem -LiteralPath 'infra\src\bicep' -Filter '*.bicep' -File -Recurse |
              Sort-Object FullName
          )
          if ($entryPoints.Count -eq 0) { throw 'No maintained Bicep entry point was found.' }
          foreach ($entryPoint in $entryPoints) {
            az bicep build --file $entryPoint.FullName --stdout | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "Bicep build failed: $($entryPoint.FullName)" }
          }

      - name: Check branch whitespace
        shell: powershell
        run: |
          $ErrorActionPreference = 'Stop'
          $baseRef = if ([string]::IsNullOrWhiteSpace($env:GITHUB_BASE_REF)) { 'origin/main' } else { "origin/$env:GITHUB_BASE_REF" }
          $mergeBase = git merge-base $baseRef HEAD
          if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($mergeBase)) { throw 'Cannot resolve whitespace merge base.' }
          git diff --check "$mergeBase...HEAD"
          if ($LASTEXITCODE -ne 0) { throw 'Whitespace validation failed.' }
```

- [ ] **Step 4: Remove obsolete workflows and only workflow-specific contracts**

```powershell
git rm '.github\workflows\audit-repository.yml'
git rm '.github\workflows\discover-tenant.yml'
git rm '.github\workflows\bootstrap-tenant.yml'
git rm 'infra\tests\pester\WorkflowContract.Tests.ps1'
```

Rewrite `.github/workflows/README.md` to describe only the one validator. Remove the advisory-audit checkbox from `.github/pull_request_template.md`. Remove audit/discovery/bootstrap requirements from `.github/cli/verify-repository-setup.ps1`; keep its independent repository/documentation validation behavior.

- [ ] **Step 5: Reduce action pins to the one active external action**

```json
{
  "schemaVersion": "1.0",
  "actions": {
    "actions/checkout": {
      "sourceRef": "v7.0.1",
      "sha": "3d3c42e5aac5ba805825da76410c181273ba90b1"
    }
  }
}
```

Do not remove the pin manifest: the safety verifier still proves that the active checkout action is immutable and reviewed.

- [ ] **Step 6: Run focused workflow and safety tests**

```powershell
Invoke-Pester -Path @(
    '.github\cli\tests\WorkflowContract.Tests.ps1'
    '.github\cli\tests\RepositorySafety.Tests.ps1'
) -Output Detailed
powershell -NoProfile -ExecutionPolicy Bypass -File '.github\cli\verify-repository-safety.ps1'
if ($LASTEXITCODE -ne 0) { throw 'Repository safety validation failed.' }
```

Expected: PASS; the safety verifier reports no unused action pin.

- [ ] **Step 7: Commit the validator consolidation**

```powershell
git add .github/workflows .github/cli .github/pull_request_template.md infra/src/config/github/action-pins.json infra/tests/pester/WorkflowContract.Tests.ps1
git commit -m 'ci: consolidate repository validation' -m 'Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>'
```

Expected: one workflow remains. Review `$TaskBase..HEAD` before Task 3.

---

### Task 3: Establish the Local Tenant 1 Configuration Boundary

**Files:**
- Modify: `.gitignore`
- Modify: `infra/src/config/tenants/_template.psd1`
- Modify: `infra/src/config/schemas/tenant.schema.json`
- Modify: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Import-TenantConfiguration.ps1`
- Modify: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Caldova.HrFrontier.Bootstrap.psd1`
- Modify: `infra/src/scripts/Invoke-TenantDiscovery.ps1`
- Modify: `infra/src/scripts/New-TenantBicepParameters.ps1`
- Modify: `infra/src/scripts/Invoke-TenantBootstrap.ps1`
- Modify: `infra/tests/pester/TenantConfiguration.Tests.ps1`
- Modify: `infra/tests/pester/DiscoveryNormalization.Tests.ps1`
- Modify: `infra/tests/pester/BicepComposition.Tests.ps1`
- Modify: `infra/tests/pester/Idempotency.Tests.ps1`
- Delete after attended backup: the one tracked Tenant 1 manifest resolved by excluding `_template.psd1` and the protected Tenant 2 blob from the clean-base inventory
- Delete after attended backup: the one tracked Tenant 1 discovery record resolved by excluding the protected Tenant 2 blob from the clean-base inventory
- Preserve byte-for-byte: `infra/src/config/tenants/caldova25668747.psd1`
- Preserve byte-for-byte: `infra/evidence/discovery/caldova25668747.json`

**Interfaces:**
- Consumes: ignored local path, safe template, encrypted external backup selected by the attended operator.
- Produces: locked import and active-script interfaces defined above; no catalogue, transition file, or private overlay.

- [ ] **Step 1: Write failing local-boundary tests**

Add these cases to `infra/tests/pester/TenantConfiguration.Tests.ps1` and the explicit-parameter assertion to each named active-script test:

```powershell
It 'ignores only local tenant configuration files and keeps the template tracked' {
    $rules = Get-Content -LiteralPath (Join-Path $script:RepositoryRoot '.gitignore')
    $rules | Should -Contain 'infra/src/config/tenants/*.local.psd1'
    & git -C $script:RepositoryRoot check-ignore --quiet -- 'infra/src/config/tenants/tenant1.local.psd1'
    $LASTEXITCODE | Should -Be 0
    & git -C $script:RepositoryRoot ls-files --error-unmatch -- 'infra/src/config/tenants/_template.psd1' 2>$null
    $LASTEXITCODE | Should -Be 0
}

It 'rejects template tracked wrong-key and non-boundary paths for live use' {
    { Import-TenantConfiguration -Path (Join-Path $script:RepositoryRoot 'infra\src\config\tenants\_template.psd1') `
        -ValidationStage Discovery -ExpectedPublicTenantKey tenant1 -RequireLocalUntracked } |
        Should -Throw '*template*'
    { Import-TenantConfiguration -Path $script:TenantManifestPath `
        -ValidationStage Discovery -ExpectedPublicTenantKey tenant2 } |
        Should -Throw '*PublicTenantKey*tenant2*'
}

It 'requires the explicit local configuration parameter on every active command' {
    foreach ($scriptName in @(
        'Invoke-TenantDiscovery.ps1',
        'New-TenantBicepParameters.ps1',
        'Invoke-TenantBootstrap.ps1'
    )) {
        $path = Join-Path $script:RepositoryRoot "infra\src\scripts\$scriptName"
        { & $path -PublicTenantKey tenant1 } | Should -Throw '*TenantConfigurationPath*'
    }
}
```

- [ ] **Step 2: Run the focused tests and verify red**

```powershell
Invoke-Pester -Path @(
    'infra\tests\pester\TenantConfiguration.Tests.ps1'
    'infra\tests\pester\DiscoveryNormalization.Tests.ps1'
    'infra\tests\pester\BicepComposition.Tests.ps1'
    'infra\tests\pester\Idempotency.Tests.ps1'
) -Output Detailed
```

Expected: FAIL because the ignore rule, public key, locked path, and mandatory parameters do not exist on the clean base.

- [ ] **Step 3: Add the exact ignore and safe public-key example**

Append once to `.gitignore`:

```gitignore
# Private tenant configuration — local operator-owned, never tracked
infra/src/config/tenants/*.local.psd1
```

No exception is needed because `_template.psd1` does not match `*.local.psd1`. Add `PublicTenantKey = 'tenant1'` to the synthetic template and an optional generic schema property matching `^tenant[1-9][0-9]*$`. Require the property only when `ExpectedPublicTenantKey` or `RequireLocalUntracked` activates the live boundary. Do not add a tenant catalogue or change either Tenant 2 file.

- [ ] **Step 4: Implement the fail-closed import boundary**

Extend `Import-TenantConfiguration` with:

```powershell
[ValidateScript({
    if ($_ -cnotmatch '^tenant[1-9][0-9]*$') {
        throw 'ExpectedPublicTenantKey must use the case-sensitive lowercase tenant key format.'
    }
    $true
})]
[string]$ExpectedPublicTenantKey,

[switch]$RequireLocalUntracked
```

After schema validation, enforce the property only for a live boundary and use exact case-sensitive matching. `RequireLocalUntracked` without `ExpectedPublicTenantKey` is invalid:

```powershell
$expectsPublicTenantKey = $PSBoundParameters.ContainsKey('ExpectedPublicTenantKey')
if ($RequireLocalUntracked -and -not $expectsPublicTenantKey) {
    throw 'ExpectedPublicTenantKey is required when RequireLocalUntracked is used.'
}
if ($expectsPublicTenantKey -or $RequireLocalUntracked) {
    $configurationEntries = Get-ObjectEntryTable $configuration
    if (-not $configurationEntries.Contains('PublicTenantKey')) {
        throw 'Configuration.PublicTenantKey is required for a live tenant boundary.'
    }
    if ([string]$configuration.PublicTenantKey -cne $ExpectedPublicTenantKey) {
        throw "Configuration.PublicTenantKey must equal '$ExpectedPublicTenantKey'."
    }
}

if ($RequireLocalUntracked) {
    $repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\..\..\..'))
    $expectedPath = [System.IO.Path]::GetFullPath(
        (Join-Path $repositoryRoot "infra\src\config\tenants\$ExpectedPublicTenantKey.local.psd1")
    )
    if ($resolvedPath -cne $expectedPath) {
        throw "Live tenant configuration must use the exact ignored path '$expectedPath'."
    }
    if ([System.IO.Path]::GetFileName($resolvedPath) -ceq '_template.psd1') {
        throw 'The tracked template cannot be used for a live operation.'
    }
    $relativePath = $resolvedPath.Substring($repositoryRoot.TrimEnd('\').Length).TrimStart('\').Replace('\', '/')
    & git -C $repositoryRoot ls-files --error-unmatch -- $relativePath 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        throw 'Live tenant configuration must not be tracked by Git.'
    }
    & git -C $repositoryRoot check-ignore --quiet -- $relativePath
    if ($LASTEXITCODE -ne 0) {
        throw 'Live tenant configuration must be covered by the reviewed ignore rule.'
    }
}
```

Resolve `git.exe` as one application command with `Get-Command ... | Select-Object -First 1`; fail if Git is absent or ambiguous after resolution. Preserve the module's read-only return conversion.

- [ ] **Step 5: Update the three active script signatures and output boundaries**

Remove every `Get-DefaultTenantConfigurationPath`. Add mandatory `-PublicTenantKey`, `-TenantConfigurationPath`, and mandatory external output path as defined in Locked Interfaces. Each script calls:

```powershell
$tenantConfiguration = Import-TenantConfiguration `
    -Path ([System.IO.Path]::GetFullPath($TenantConfigurationPath)) `
    -ValidationStage Bootstrap `
    -ExpectedPublicTenantKey $PublicTenantKey `
    -RequireLocalUntracked
```

Discovery may use `Discovery` rather than `Bootstrap`. Reject an output path when it starts with the normalized repository root plus `\`. `Invoke-TenantBootstrap.ps1` applies the same rejection to `EvidencePath` and `ParameterFile`, because both contain private run material even though the orchestrator consumes them as inputs. Historical authorization scripts remain dormant and unchanged; they are not active Task 3 dependencies.

Use case-sensitive lowercase validation on every live public key:

```powershell
[ValidateScript({
    if ($_ -cnotmatch '^tenant[1-9][0-9]*$') {
        throw 'PublicTenantKey must use the case-sensitive lowercase tenant key format.'
    }
    $true
})]
[string]$PublicTenantKey
```

The three active scripts are:

```text
Invoke-TenantDiscovery.ps1
New-TenantBicepParameters.ps1
Invoke-TenantBootstrap.ps1
```

Task 4 removes the remaining historical authorization-mutation tuple from the bootstrap interface. No Task 3 step grants, discovers, or removes a role assignment.

- [ ] **Step 6: Run the focused tests and verify green**

```powershell
Invoke-Pester -Path @(
    'infra\tests\pester\TenantConfiguration.Tests.ps1'
    'infra\tests\pester\DiscoveryNormalization.Tests.ps1'
    'infra\tests\pester\BicepComposition.Tests.ps1'
    'infra\tests\pester\Idempotency.Tests.ps1'
) -Output Detailed
```

Expected: PASS using synthetic `TestDrive` configurations for live-boundary behavior plus read-only import probes for both preserved tracked manifests. Tests do not print private values.

- [ ] **Step 7: Commit the local-boundary implementation before private-file removal**

```powershell
git add .gitignore infra/src/config/tenants/_template.psd1 infra/src/config/schemas/tenant.schema.json infra/src/scripts infra/tests/pester
git commit -m 'refactor(config): enforce local Tenant 1 boundary' -m 'Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>'
```

- [ ] **Step 8: Back up and restore-test the committed Tenant 1 files outside Git**

This is an attended local checkpoint. The operator supplies an encrypted external path outside the repository and outside the workstation's primary failure domain:

```powershell
$RepositoryRoot = 'C:\Users\urruegg\source\urruegg\caldova-hr-frontier\.worktrees\tenant1-lean-platform'
$BackupRoot = [System.IO.Path]::GetFullPath((Read-Host 'Enter the mounted encrypted external backup directory').Trim())
$RepositoryPrefix = [System.IO.Path]::GetFullPath($RepositoryRoot).TrimEnd('\') + '\'
if ($BackupRoot.StartsWith($RepositoryPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'Backup directory must be outside the repository.'
}
if (-not (Test-Path -LiteralPath $BackupRoot -PathType Container)) {
    throw 'Encrypted external backup directory does not exist.'
}

$Tenant2ManifestPath = 'infra/src/config/tenants/caldova25668747.psd1'
$Tenant2EvidencePath = 'infra/evidence/discovery/caldova25668747.json'
$TrackedManifests = @(git -C $RepositoryRoot ls-files 'infra/src/config/tenants/*.psd1')
$TrackedEvidence = @(git -C $RepositoryRoot ls-files 'infra/evidence/discovery/*.json')
$Tenant1ManifestCandidates = @($TrackedManifests | Where-Object {
    $_ -cne 'infra/src/config/tenants/_template.psd1' -and $_ -cne $Tenant2ManifestPath
})
$Tenant1EvidenceCandidates = @($TrackedEvidence | Where-Object { $_ -cne $Tenant2EvidencePath })
if ($Tenant1ManifestCandidates.Count -ne 1 -or $Tenant1EvidenceCandidates.Count -ne 1) {
    throw 'Tenant 1 committed configuration paths are ambiguous.'
}
$SourcePaths = @($Tenant1ManifestCandidates[0], $Tenant1EvidenceCandidates[0])
$BackupSet = Join-Path $BackupRoot ('tenant1-pre-lean-' + [datetime]::UtcNow.ToString('yyyyMMddTHHmmssZ'))
[void](New-Item -ItemType Directory -Path $BackupSet)
$Hashes = foreach ($relative in $SourcePaths) {
    $source = Join-Path $RepositoryRoot $relative
    $destination = Join-Path $BackupSet ([System.IO.Path]::GetFileName($source))
    Copy-Item -LiteralPath $source -Destination $destination
    [pscustomobject]@{
        File = [System.IO.Path]::GetFileName($source)
        Sha256 = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
    }
}
$HashPath = Join-Path $BackupSet 'sha256.json'
[System.IO.File]::WriteAllText(
    $HashPath,
    ($Hashes | ConvertTo-Json -Depth 4),
    [System.Text.UTF8Encoding]::new($false)
)
```

Restore to a new protected location outside Git and verify byte hashes without printing file content:

```powershell
$RestoreRoot = Join-Path $env:LOCALAPPDATA ('Caldova\HrFrontier\restore-check\' + [guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $RestoreRoot -Force)
foreach ($record in $Hashes) {
    $backupFile = Join-Path $BackupSet $record.File
    $restoredFile = Join-Path $RestoreRoot $record.File
    Copy-Item -LiteralPath $backupFile -Destination $restoredFile
    $actual = (Get-FileHash -LiteralPath $restoredFile -Algorithm SHA256).Hash
    if ($actual -cne $record.Sha256) { throw "Restore hash mismatch for $($record.File)." }
}
$restoredManifest = Join-Path $RestoreRoot ([System.IO.Path]::GetFileName($Tenant1ManifestCandidates[0]))
$null = Import-PowerShellDataFile -LiteralPath $restoredManifest
Write-Output 'Tenant 1 encrypted backup restore, hash, and parse checks passed.'
```

Create the ignored local manifest without printing other values, validate it, and store its final hash with the encrypted backup:

```powershell
$LocalConfigPath = Join-Path $RepositoryRoot 'infra\src\config\tenants\tenant1.local.psd1'
Copy-Item -LiteralPath $restoredManifest -Destination $LocalConfigPath
$LocalText = [System.IO.File]::ReadAllText($LocalConfigPath)
if ($LocalText -notmatch '(?m)^\s*PublicTenantKey\s*=') {
    $OpeningIndex = $LocalText.IndexOf('@{', [System.StringComparison]::Ordinal)
    if ($OpeningIndex -lt 0) { throw 'Restored Tenant 1 manifest has no root hashtable.' }
    $InsertAt = $OpeningIndex + 2
    $LocalText = $LocalText.Insert($InsertAt, "`r`n    PublicTenantKey = 'tenant1'")
    [System.IO.File]::WriteAllText($LocalConfigPath, $LocalText, [System.Text.UTF8Encoding]::new($false))
}

Import-Module '.\infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1' -Force
$null = Import-TenantConfiguration `
    -Path $LocalConfigPath `
    -ValidationStage Discovery `
    -ExpectedPublicTenantKey tenant1 `
    -RequireLocalUntracked

git -C $RepositoryRoot check-ignore --quiet -- 'infra/src/config/tenants/tenant1.local.psd1'
if ($LASTEXITCODE -ne 0) { throw 'Local Tenant 1 configuration is not ignored.' }
$LocalHash = (Get-FileHash -LiteralPath $LocalConfigPath -Algorithm SHA256).Hash
[System.IO.File]::WriteAllText(
    (Join-Path $BackupSet 'tenant1.local.sha256'),
    ($LocalHash + [Environment]::NewLine),
    [System.Text.UTF8Encoding]::new($false)
)
```

Do not stage the local file or hashes.

- [ ] **Step 9: Stop for attended confirmation before deleting public Tenant 1 artifacts**

Present the backup directory, two source/backup hash matches, restore-test success, local configuration schema result, and:

```powershell
git status --short --untracked-files=all
git check-ignore -v -- 'infra/src/config/tenants/tenant1.local.psd1'
```

Expected: the local file is ignored and absent from `git status`. Ask the attended operator to confirm deletion of only the two tracked Tenant 1 files. Do not continue on silence or ambiguous approval.

- [ ] **Step 10: Remove only the confirmed Tenant 1 artifacts and prove Tenant 2 unchanged**

```powershell
git rm -- $Tenant1ManifestCandidates[0] $Tenant1EvidenceCandidates[0]
if ($LASTEXITCODE -ne 0) { throw 'Tenant 1 public artifact removal failed.' }

$Tenant2ManifestBlob = git hash-object -- $Tenant2ManifestPath
$Tenant2EvidenceBlob = git hash-object -- $Tenant2EvidencePath
if ($Tenant2ManifestBlob -cne 'f4b2dfed2f42d1d9d95d51dddaeaaedf4d8b6dce') {
    throw 'Tenant 2 manifest changed.'
}
if ($Tenant2EvidenceBlob -cne 'c2d4d66f4f812fc449752c275845fac5a713915e') {
    throw 'Tenant 2 evidence changed.'
}
```

- [ ] **Step 11: Commit the attended public-file removal**

```powershell
git commit -m 'chore(config): remove public Tenant 1 artifacts' -m 'Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>'
```

Expected: the commit deletes exactly the Tenant 1 manifest/evidence. Review both Task 3 commits from `$TaskBase..HEAD` before Task 4.

---

### Task 4: Make Validation Local, Attended, What-If-Only, and Minimum-Access-Safe

**Files:**
- Modify: `infra/src/scripts/Invoke-TenantBootstrap.ps1`
- Modify: `infra/tests/pester/Idempotency.Tests.ps1`
- Modify: `infra/tests/pester/WhatIfBoundary.Tests.ps1`
- Delete: `infra/tests/pester/TenantTrust.Tests.ps1`
- Create: `infra/docs/24-tenant-1-lean-platform-runbook.md`
- Modify: `infra/README.md`
- Modify: `infra/docs/runbooks/README.md`
- Modify: `infra/docs/10-tenant-setup-and-configuration.md`
- Modify: `infra/docs/11-identity-and-access.md`
- Modify: `infra/docs/14-github-repository-blueprint.md`
- Modify: `infra/docs/17-bootstrap-and-provisioning.md`
- Modify: `infra/docs/18-multi-tenant-provisioning.md`
- Modify: `infra/docs/19-bootstrap-recovery.md`
- Modify: `infra/docs/20-tenant-trust-activation-runbook.md`
- Modify: `infra/tests/pester/RunbookDocumentation.Tests.ps1`

**Interfaces:**
- Consumes: Task 3 local configuration and active script contracts.
- Produces: fixed local sequence `attended context -> minimum-access preflight -> discovery -> sanitized review -> Bicep build -> subscription what-if -> boundary and access read-back`, with no role mutation, trust activation, or deployment creation.

- [ ] **Step 1: Write failing attended-context and runbook contracts**

Add to `infra/tests/pester/Idempotency.Tests.ps1`:

```powershell
It 'requires attended minimum access and has no role-mutation OIDC or deployment-create path' {
    $content = Get-Content -Raw -LiteralPath $script:BootstrapScriptPath
    $content | Should -Match 'user\.type.+user'
    $content | Should -Match 'AttendedUserContextValidator'
    $content | Should -Match 'AccessPreflightValidator'
    $content | Should -Match "'deployment',\s*'sub',\s*'what-if'"
    $content | Should -Not -Match 'role.+assignment.+(create|delete)'
    $content | Should -Not -Match 'OidcContextValidator|AZURE_CLIENT_ID|federated'
    $content | Should -Not -Match "'deployment',\s*'sub',\s*'create'|New-AzSubscriptionDeployment"
}
```

Add a `RunbookDocumentation.Tests.ps1` case requiring headings `Private Configuration and Backup`, `Attended Context and Minimum Access`, `Local Discovery`, `Sanitized Review`, `Bicep Build`, `Subscription What-If`, `Boundary and Access Read-Back`, `GitHub Governance`, `Basic Boards`, `Empty Azure Repo Checkpoint`, `Final Governed Transaction`, `Failure and Recovery`, and `Acceptance`.

- [ ] **Step 2: Run focused tests and verify red**

```powershell
Invoke-Pester -Path @(
    'infra\tests\pester\Idempotency.Tests.ps1'
    'infra\tests\pester\WhatIfBoundary.Tests.ps1'
    'infra\tests\pester\RunbookDocumentation.Tests.ps1'
) -Output Detailed
```

Expected: FAIL because bootstrap still exposes the historical authorization-mutation interface, lacks minimum-access preflight/read-back, and the lean runbook does not exist.

- [ ] **Step 3: Replace authorization mutation with attended-user and minimum-access validation**

Rename `Test-DefaultOidcContext` and the injected `OidcContextValidator` to `Get-DefaultAttendedUserPrincipal` and `AttendedUserContextValidator`. Remove the historical authorization-mutation parameters, state loading, and mutation recovery from the active bootstrap interface. The default attended-context validator must:

```powershell
$account = Invoke-NativeJsonCommand -FilePath 'az' -ArgumentList @('account', 'show', '--output', 'json')
if ([string]$account.user.type -cne 'user') {
    throw 'Lean Tenant 1 validation requires an attended user context.'
}
if ([string]$account.tenantId -cne [string]$TenantConfiguration.TenantId) {
    throw 'Signed-in tenant does not match the local Tenant 1 configuration.'
}
if ([string]$account.id -cne [string]$TenantConfiguration.SubscriptionId) {
    throw 'Signed-in subscription does not match the local Tenant 1 configuration.'
}
$caller = Invoke-NativeJsonCommand -FilePath 'az' -ArgumentList @('ad', 'signed-in-user', 'show', '--output', 'json')
$principalObjectId = [guid]::Empty
if (-not [guid]::TryParse([string]$caller.id, [ref]$principalObjectId)) {
    throw 'Signed-in user discovery did not return a GUID object id.'
}
```

Add an injected `AccessPreflightValidator` for tests and a default read-only preflight that records the exact attended principal, tenant, subscription, and separately approved access evidence outside Git. It may list effective assignments and role definitions at the exact subscription scope, but it must not create, update, or delete an assignment. Fail when no separately approved pre-existing access can execute the reviewed `what-if`.

Keep the `-WhatIfOnly` hard failure, Bicep build, `az deployment sub what-if`, and `Test-WhatIfBoundary.ps1`. After `what-if`, repeat `az account show` and signed-in-user discovery and require the same principal, tenant, and subscription. Any context or access drift blocks acceptance. This sprint performs no role mutation.

- [ ] **Step 4: Retire trust activation from the active dependency graph**

Delete `infra/tests/pester/TenantTrust.Tests.ps1` so the comprehensive validator does not execute dormant trust code. Leave `infra/src/scripts/Initialize-TenantTrust.ps1` unchanged. Rewrite `infra/docs/20-tenant-trust-activation-runbook.md` as Status `Superseded`, with an opening stop notice that the command is dormant, unsupported in the current sprint, and requires a new reviewed design before reuse. Remove active links that describe it as a prerequisite.

- [ ] **Step 5: Write the lean operator runbook with exact safe commands**

Create `infra/docs/24-tenant-1-lean-platform-runbook.md` with repository metadata and the required headings. Its local commands use:

```powershell
$RepositoryRoot = 'C:\Users\urruegg\source\urruegg\caldova-hr-frontier\.worktrees\tenant1-lean-platform'
$OperatorRoot = Join-Path $env:LOCALAPPDATA 'Caldova\HrFrontier\tenant1'
$ConfigPath = Join-Path $RepositoryRoot 'infra\src\config\tenants\tenant1.local.psd1'
$DiscoveryPath = Join-Path $OperatorRoot 'discovery.json'
$ParameterRoot = Join-Path $OperatorRoot 'parameters'
[void](New-Item -ItemType Directory -Path $OperatorRoot -Force)
[void](New-Item -ItemType Directory -Path $ParameterRoot -Force)
```

Discovery:

```powershell
.\infra\src\scripts\Invoke-TenantDiscovery.ps1 `
    -PublicTenantKey tenant1 `
    -TenantConfigurationPath $ConfigPath `
    -AuthenticationMode Interactive `
    -OutputPath $DiscoveryPath
```

After local sanitized review, confirm the separately approved pre-existing minimum access outside Git and derive the exact attended principal without changing roles:

```powershell
$Account = az account show --output json | ConvertFrom-Json
if ([string]$Account.user.type -cne 'user') { throw 'An attended user context is required.' }
$Caller = az ad signed-in-user show --output json | ConvertFrom-Json
$ValidationPrincipalId = [guid]$Caller.id

.\infra\src\scripts\New-TenantBicepParameters.ps1 `
    -PublicTenantKey tenant1 `
    -TenantConfigurationPath $ConfigPath `
    -ValidationPrincipalId $ValidationPrincipalId `
    -OutputPath $ParameterRoot
$ParameterFile = @(Get-ChildItem -LiteralPath $ParameterRoot -Filter '*.bicepparam' -File)
if ($ParameterFile.Count -ne 1) { throw 'Expected exactly one generated parameter file.' }
```

Execute only:

```powershell
.\infra\src\scripts\Invoke-TenantBootstrap.ps1 `
    -PublicTenantKey tenant1 `
    -TenantConfigurationPath $ConfigPath `
    -EvidencePath $DiscoveryPath `
    -ParameterFile $ParameterFile[0].FullName `
    -WhatIfOnly
```

The runbook must say that access is provisioned and approved separately before this sprint, the sprint performs no role mutation, context and access are read back after `what-if`, and `what-if` is not deployment evidence.

- [ ] **Step 6: Remove active cloud-bootstrap claims from maintained docs**

Update the listed infrastructure documents to the lean topology. Active text must not instruct an operator to create OIDC trust, a GitHub bootstrap Environment, a private Azure Repo, or workflow-hosted discovery. Historical/spec links may remain only when labelled superseded or deferred. Do not edit the active point-in-time configuration review or its evidence.

- [ ] **Step 7: Run focused orchestration and documentation tests**

```powershell
Invoke-Pester -Path @(
    'infra\tests\pester\Idempotency.Tests.ps1'
    'infra\tests\pester\WhatIfBoundary.Tests.ps1'
    'infra\tests\pester\RunbookDocumentation.Tests.ps1'
) -Output Detailed
```

Expected: PASS.

- [ ] **Step 8: Commit the attended validation slice**

```powershell
git add infra/src/scripts/Invoke-TenantBootstrap.ps1 infra/tests/pester infra/docs infra/README.md
git commit -m 'refactor(bootstrap): use attended what-if validation' -m 'Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>'
```

Review `$TaskBase..HEAD` before Task 5.

---

### Task 5: Apply Only Minimal GitHub Governance

**Files:**
- Modify: `infra/src/config/github/main-ruleset.json`
- Modify: `infra/src/config/schemas/github-ruleset.schema.json`
- Modify: `infra/src/scripts/Enable-GitHubGovernance.ps1`
- Rewrite focused cases: `infra/tests/pester/GitHubGovernance.Tests.ps1`
- Modify: `.github/pull_request_template.md`
- Test unchanged ownership: `.github/CODEOWNERS`

**Interfaces:**
- Consumes: successful current-main validator run ID, desired-state JSON, existing CODEOWNERS.
- Produces: exact minimal ruleset, repository settings, Dependabot security updates, and complete read-back; no bootstrap/identity/role gate.

- [ ] **Step 1: Replace bootstrap-heavy tests with a failing minimal contract**

Keep reusable ruleset pagination/fnmatch/read-back tests, but remove fixtures and assertions for bootstrap evidence, Entra principal, Azure roles, and GitHub Environments. Add:

```powershell
It 'requires only repository validator and desired state inputs' {
    $command = Get-Command $script:ScriptPath
    @($command.Parameters.Keys) | Should -Contain 'Repository'
    @($command.Parameters.Keys) | Should -Contain 'ValidatorRunId'
    @($command.Parameters.Keys) | Should -Contain 'DesiredStatePath'
    foreach ($removed in @('BootstrapRunId','BootstrapEvidencePath','PublicTenantKey','TenantConfigurationPath')) {
        @($command.Parameters.Keys) | Should -Not -Contain $removed
    }
}

It 'ships the exact lean repository settings and single required check' {
    $state = Get-Content -Raw -LiteralPath $script:DesiredStatePath | ConvertFrom-Json
    $state.repositorySettings.allowMergeCommit | Should -BeFalse
    $state.repositorySettings.allowRebaseMerge | Should -BeFalse
    $state.repositorySettings.allowSquashMerge | Should -BeTrue
    $state.repositorySettings.deleteBranchOnMerge | Should -BeTrue
    $state.repositorySettings.hasProjects | Should -BeFalse
    $state.security.dependabotSecurityUpdates | Should -BeTrue
    @($state.rulesets[0].bypassActors).Count | Should -Be 0
    $pullRequest = @($state.rulesets[0].rules | Where-Object type -eq 'pull_request')[0]
    $pullRequest.parameters.allowedMergeMethods | Should -Be @('squash')
    $pullRequest.parameters.requiredApprovingReviewCount | Should -Be 0
    $pullRequest.parameters.requireCodeOwnerReview | Should -BeFalse
    $pullRequest.parameters.requiredReviewThreadResolution | Should -BeTrue
    $checks = @($state.rulesets[0].rules | Where-Object type -eq 'required_status_checks')[0]
    @($checks.parameters.requiredStatusChecks.context) | Should -Be @('Repository setup validation')
}
```

Add negative cases for a validator run not completed/successful, wrong branch, wrong SHA, wrong workflow path, current-main movement, duplicate main-applicable ruleset, repository-setting drift, ruleset drift, Dependabot read-back drift, any Environment API path, and any Azure CLI invocation.

- [ ] **Step 2: Run governance tests and verify red**

```powershell
Invoke-Pester -Path 'infra\tests\pester\GitHubGovernance.Tests.ps1' -Output Detailed
```

Expected: FAIL on the old parameters, three merge methods, bypass actor, missing settings/security state, and bootstrap gates.

- [ ] **Step 3: Extend the closed desired state and schema**

Add these exact top-level objects:

```json
{
  "repositorySettings": {
    "defaultBranch": "main",
    "allowMergeCommit": false,
    "allowRebaseMerge": false,
    "allowSquashMerge": true,
    "deleteBranchOnMerge": true,
    "hasProjects": false
  },
  "security": {
    "dependabotSecurityUpdates": true
  }
}
```

Set `bypassActors` to `[]`, `allowedMergeMethods` to `["squash"]`, and keep only the four rule types `deletion`, `non_fast_forward`, `pull_request`, and `required_status_checks`. Keep the sole status context `Repository setup validation` with the existing GitHub Actions integration ID. Make every object recursively closed in the schema.

- [ ] **Step 4: Simplify the governance script and validator gate**

The public parameter block is exactly:

```powershell
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[^/]+/[^/]+$')]
    [string]$Repository,

    [Parameter(Mandatory)]
    [ValidateScript({ $_ -gt 0 })]
    [long]$ValidatorRunId,

    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string]$DesiredStatePath
)
```

Before mutation, read `main`, then `actions/runs/$ValidatorRunId`, and require:

```powershell
if ([string]$Run.path -cne '.github/workflows/validate-repository.yml' -or
    [string]$Run.head_branch -cne 'main' -or
    [string]$Run.head_sha -cne $CurrentMainSha -or
    [string]$Run.status -cne 'completed' -or
    [string]$Run.conclusion -cne 'success') {
    throw 'Validator run must be the successful completed current-main validate-repository workflow.'
}
```

Read the run's jobs and require exactly one job named `Repository setup validation` with conclusion `success`. Read `.github/CODEOWNERS` at the same main SHA and require a non-empty ownership map, but do not require a CODEOWNERS approval while the solo-owner profile is active.

Remove `Assert-BootstrapEvidence`, tenant-manifest import, Environment read-back, Azure account/service-principal checks, ARM role reads, access-token acquisition, and all Environment API calls.

- [ ] **Step 5: Implement exact mutation and read-back**

`-WhatIf` produces a closed proposal and makes zero POST/PUT/PATCH calls. Apply mode:

1. Captures complete repository settings and detailed ruleset pre-state.
2. Rereads `main` and the validator immediately before mutation.
3. PATCHes only the five repository settings when drift exists.
4. POSTs or PUTs the exact `main` ruleset payload by stable ruleset ID.
5. PUTs `repos/$Repository/automated-security-fixes` only when not already enabled.
6. Reads repository settings, detailed ruleset, all competing main-applicable rulesets, and automated-security-fix status back.
7. Returns `Status = 'Verified'` only when every value exactly matches desired state.

Never call an `actions/environments` endpoint and never invoke `az`.

- [ ] **Step 6: Tighten the PR traceability wording**

Keep `## Work item` followed by `AB#`, and add:

```markdown
For the final governed proof, use the literal `Fixes AB#` prefix followed by the
selected Azure Boards Issue ID. Human review verifies the reference; no separate
traceability workflow is required.
```

Add an `IssueFormContract.Tests.ps1` assertion if the existing test does not already require that exact phrase.

- [ ] **Step 7: Run governance and collaboration tests**

```powershell
Invoke-Pester -Path @(
    'infra\tests\pester\GitHubGovernance.Tests.ps1'
    '.github\cli\tests\IssueFormContract.Tests.ps1'
) -Output Detailed
```

Expected: PASS, including zero-mutation and every negative read-back case.

- [ ] **Step 8: Commit minimal governance**

```powershell
git add infra/src/config/github infra/src/scripts/Enable-GitHubGovernance.ps1 infra/tests/pester/GitHubGovernance.Tests.ps1 .github/pull_request_template.md .github/cli/tests/IssueFormContract.Tests.ps1
git commit -m 'feat(governance): enforce lean GitHub controls' -m 'Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>'
```

Review `$TaskBase..HEAD` before Task 6.

---

### Task 6: Add the Lean Basic Boards Operation and the Empty-Repo Checkpoint

**Files:**
- Create: `infra/src/scripts/Initialize-AzureBoardsLeanSprint.ps1`
- Create: `infra/tests/pester/AzureBoardsLeanSprint.Tests.ps1`
- Modify: `infra/docs/21-azure-boards-population-runbook.md`
- Modify: `infra/docs/24-tenant-1-lean-platform-runbook.md`
- Leave unchanged: `infra/src/scripts/Initialize-AzureDevOpsWorkItems.ps1`
- Leave unchanged: `infra/tests/pester/AzureBoardsPopulation.Tests.ps1`

**Interfaces:**
- Consumes: authenticated attended Azure DevOps user context, exact organization/project/team/current-sprint inputs.
- Produces: verified Basic/team/root/current-sprint state and one durable Issue ID; optional separate empty Azure Repo deletion checkpoint.

- [ ] **Step 1: Write failing Basic Boards tests**

Create `infra/tests/pester/AzureBoardsLeanSprint.Tests.ps1` around an injected `AzureDevOpsRequest` adapter:

```powershell
It 'accepts only Basic existing team root area and one Issue' {
    $result = & $script:ScriptPath `
        -OrganizationUrl 'https://dev.azure.com/example/' `
        -ProjectName 'Caldova HR Frontier' `
        -TeamName 'Caldova HR Frontier Team' `
        -CurrentSprintPath 'Caldova HR Frontier\Current' `
        -IssueTitle 'Tenant 1 lean engineering platform acceptance' `
        -PlanOutputPath (Join-Path $TestDrive 'boards-plan.json') `
        -AzureDevOpsRequest $script:ExactBasicState `
        -WhatIf

    $result.ProcessName | Should -BeExactly 'Basic'
    $result.AreaPath | Should -BeExactly 'Caldova HR Frontier'
    $result.IssueMode | Should -BeExactly 'Create'
    $result.Status | Should -BeExactly 'Planned'
}

It 'rejects unsafe state without mutation' -TestCases @(
    @{ Mode = 'Agile'; Expected = '*Basic*' }
    @{ Mode = 'MissingTeam'; Expected = '*team*' }
    @{ Mode = 'NonRootArea'; Expected = '*root area*' }
    @{ Mode = 'DuplicateIssue'; Expected = '*Ambiguous*Issue*' }
    @{ Mode = 'OneDate'; Expected = '*both sprint dates*' }
    @{ Mode = 'NotFound'; Expected = '*indeterminate*' }
) {
    param($Mode, $Expected)
    { Invoke-TestCase -Mode $Mode } | Should -Throw $Expected
    $script:MutationCalls | Should -BeEmpty
}
```

Add tests that an existing exact tagged Issue is reused and never deleted, supplied dates change only the selected current sprint, omitted dates cause no iteration mutation, create/read-back mismatch fails, and `-WhatIf` performs zero mutations.

- [ ] **Step 2: Run the new test and verify red**

```powershell
Invoke-Pester -Path 'infra\tests\pester\AzureBoardsLeanSprint.Tests.ps1' -Output Detailed
```

Expected: FAIL because the script does not exist.

- [ ] **Step 3: Implement the minimal Boards script**

Use this public parameter block:

```powershell
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)][ValidatePattern('^https://')][string]$OrganizationUrl,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ProjectName,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$TeamName,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$CurrentSprintPath,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$IssueTitle,
    [Parameter(Mandatory)][string]$PlanOutputPath,
    [datetime]$SprintStartDate,
    [datetime]$SprintFinishDate,
    [switch]$Apply,
    [Parameter(DontShow)][scriptblock]$AzureDevOpsRequest
)
```

Default and `-WhatIf` execution return the deterministic plan with zero mutation. Mutation requires `-Apply` and `ShouldProcess`; reject `-Apply` combined with `-WhatIf`. The adapter supports only:

```text
GetProjectWithCapabilities
GetTeam
GetProjectRootArea
GetIteration
UpdateIterationDates
QueryTraceabilityIssue
CreateTraceabilityIssue
GetWorkItem
```

The query uses work item type `Issue` and exact tag `tenant1-lean-platform-traceability`. Zero matches plans create; one match plans reuse; more than one fails. Create fields are:

```powershell
@{
    'System.WorkItemType' = 'Issue'
    'System.Title' = $IssueTitle
    'System.AreaPath' = $ProjectName
    'System.IterationPath' = $CurrentSprintPath
    'System.Tags' = 'tenant1-lean-platform-traceability'
}
```

Require project capability `processTemplate.templateName = 'Basic'`, exact existing team, exact root area, and exact iteration path. If dates are supplied, require `StartDate -le FinishDate`; update only that iteration and read both dates back. If dates are omitted, preserve observed dates. Never create a team, area, iteration, Epic, Task, or process.

The production adapter uses Azure DevOps REST API 7.1 through `az devops invoke` with these exact resources:

```powershell
# Process/project capability
az devops project show --organization $OrganizationUrl --project $ProjectName --output json

# Existing team
az devops invoke --organization $OrganizationUrl --area core --resource teams `
    --route-parameters "projectId=$ProjectName" "teamId=$TeamName" --api-version 7.1 --output json

# Root area and exact current iteration
az devops invoke --organization $OrganizationUrl --area wit --resource classificationnodes `
    --route-parameters "project=$ProjectName" 'structureGroup=areas' --api-version 7.1 --output json
az devops invoke --organization $OrganizationUrl --area wit --resource classificationnodes `
    --route-parameters "project=$ProjectName" 'structureGroup=iterations' "path=$CurrentSprintPath" `
    --api-version 7.1 --output json

# Exact Issue query
$WiqlPath = Join-Path ([System.IO.Path]::GetDirectoryName($PlanOutputPath)) 'traceability-issue-query.json'
$Wiql = @{
    query = "SELECT [System.Id] FROM WorkItems WHERE [System.TeamProject] = '$ProjectName' AND [System.WorkItemType] = 'Issue' AND [System.Tags] CONTAINS 'tenant1-lean-platform-traceability'"
} | ConvertTo-Json -Compress
[System.IO.File]::WriteAllText($WiqlPath, $Wiql, [System.Text.UTF8Encoding]::new($false))
az devops invoke --organization $OrganizationUrl --area wit --resource wiql `
    --route-parameters "project=$ProjectName" --http-method POST --in-file $WiqlPath `
    --api-version 7.1 --output json
```

`UpdateIterationDates` PATCHes only the exact `classificationnodes/iterations/{path}` attributes object. `CreateTraceabilityIssue` POSTs JSON Patch to `wit/workitems/$Issue`. The script writes request bodies beside `PlanOutputPath`, never in the repository, checks the native exit code and non-empty JSON body after every call, and deletes no work item.

- [ ] **Step 4: Run Basic Boards tests and the untouched Epic suite**

```powershell
Invoke-Pester -Path @(
    'infra\tests\pester\AzureBoardsLeanSprint.Tests.ps1'
    'infra\tests\pester\AzureBoardsPopulation.Tests.ps1'
) -Output Detailed
```

Expected: PASS. The separate 19-Epic tool remains behaviorally unchanged and optional.

- [ ] **Step 5: Reconcile the Boards runbook**

Mark `infra/docs/21-azure-boards-population-runbook.md` as optional portfolio tooling, remove trust/OIDC prerequisites, and state that it is not required for lean acceptance. Add the locked lean script command and explain that current-sprint dates are omitted unless the attended owner supplies approved dates.

- [ ] **Step 6: Add the exact empty Azure Repo pre-delete proof to the lean runbook**

The runbook obtains the exact repo ID as attended input:

```powershell
$AzureRepoId = (Read-Host 'Enter the exact empty Azure Repo GUID').Trim()
if ($AzureRepoId -cnotmatch '^[0-9a-fA-F-]{36}$') { throw 'Azure Repo ID must be a GUID.' }
$OrganizationUrl = (Read-Host 'Enter the Azure DevOps organization URL').Trim()
$ProjectId = (Read-Host 'Enter the exact Azure DevOps project GUID').Trim()
if ($ProjectId -cnotmatch '^[0-9a-fA-F-]{36}$') { throw 'Project ID must be a GUID.' }
```

Use Azure DevOps REST 7.1 to read repository metadata, refs, and recursive items. Require all four predicates:

```powershell
$Repository = az repos show --id $AzureRepoId --organization $OrganizationUrl --project $ProjectId --output json |
    ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or $null -eq $Repository) { throw 'Cannot read exact Azure Repo metadata.' }

$Refs = az devops invoke --organization $OrganizationUrl --area git --resource refs `
    --route-parameters "project=$ProjectId" "repositoryId=$AzureRepoId" `
    --api-version 7.1 --output json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or $null -eq $Refs) { throw 'Cannot prove Azure Repo refs.' }

$Items = az devops invoke --organization $OrganizationUrl --area git --resource items `
    --route-parameters "project=$ProjectId" "repositoryId=$AzureRepoId" `
    --query-parameters 'scopePath=/' 'recursionLevel=Full' 'includeContentMetadata=true' `
    --api-version 7.1 --output json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or $null -eq $Items) { throw 'Cannot prove Azure Repo items.' }

if ([long]$Repository.size -ne 0) { throw 'Azure Repo size is not zero.' }
if (-not [string]::IsNullOrWhiteSpace([string]$Repository.defaultBranch)) { throw 'Azure Repo has a default branch.' }
if (@($Refs.value).Count -ne 0) { throw 'Azure Repo contains refs.' }
if (@($Items.value).Count -ne 0) { throw 'Azure Repo contains items.' }
```

Any failed call, `403`, `404`, empty body, malformed response, branch, ref, or item stops. Capture the sanitized proof and stable repo ID outside Git.

- [ ] **Step 7: Define and stop at the destructive checkpoint**

The runbook must say:

1. Display the exact repo ID/name/project plus the four successful predicates.
2. Ask the Azure DevOps project administrator whether to delete that exact repository.
3. Stop on anything other than explicit attended approval.
4. Run only `az repos delete --id $AzureRepoId --organization $OrganizationUrl --project $ProjectId --yes`.
5. Read back by exact ID; only the post-delete `404` is expected. Any other result is failure.

This plan does not supply approval and does not run the command.

- [ ] **Step 8: Commit the Boards slice**

```powershell
git add infra/src/scripts/Initialize-AzureBoardsLeanSprint.ps1 infra/tests/pester/AzureBoardsLeanSprint.Tests.ps1 infra/docs/21-azure-boards-population-runbook.md infra/docs/24-tenant-1-lean-platform-runbook.md
git commit -m 'feat(boards): add lean sprint traceability operation' -m 'Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>'
```

Review `$TaskBase..HEAD` before Task 7.

---

### Task 7: Prepare the Ordered Operator Checkpoints and Draft Acceptance Record

**Files:**
- Modify: `infra/docs/24-tenant-1-lean-platform-runbook.md`
- Modify: `infra/tests/pester/RunbookDocumentation.Tests.ps1`
- Create: `docs/reviews/2026-09-28-tenant-1-lean-engineering-platform-acceptance-review.md`
- Modify: `docs/reviews/README.md`
- Modify: `docs/README.md`

**Interfaces:**
- Consumes: Tasks 1-6 interfaces and rollback rules.
- Produces: a no-mutation operator sequence and a Draft review whose outcomes remain `Not Run` until Task 8 has actual read-back.

- [ ] **Step 1: Write the failing ordered-checkpoint documentation test**

Add:

```powershell
It 'documents the irreversible checkpoint order without claiming execution' {
    $path = Join-Path $script:repositoryRoot 'infra\docs\24-tenant-1-lean-platform-runbook.md'
    $content = Get-Content -Raw -LiteralPath $path
    $headings = @(
        'Merge Tool Changes',
        'Current-Main Validator',
        'Local Validation and Access Read-Back',
        'GitHub Governance',
        'Basic Boards Issue',
        'Empty Azure Repo Checkpoint',
        'Final Governed Transaction',
        'Acceptance Read-Back'
    )
    $positions = @($headings | ForEach-Object { $content.IndexOf("## $_", [StringComparison]::Ordinal) })
    @($positions | Where-Object { $_ -lt 0 }).Count | Should -Be 0
    for ($index = 1; $index -lt $positions.Count; $index++) {
        $positions[$index] | Should -BeGreaterThan $positions[$index - 1]
    }
    $content | Should -Match 'Do not apply.+governance.+before.+tool.+main'
    $content | Should -Match 'Not Run'
}
```

- [ ] **Step 2: Run the focused test and verify red**

```powershell
Invoke-Pester -Path 'infra\tests\pester\RunbookDocumentation.Tests.ps1' -Output Detailed
```

Expected: FAIL because the runbook does not yet lock the activation order or Draft outcomes.

- [ ] **Step 3: Add the no-mutation checkpoint sequence**

Expand the lean runbook with the headings and exact order from Step 1. State that Tasks 1-7 and Task 8 source/safety verification merge before governance activation. The implementation pull request uses the old governance state; after merge, current `main` must produce one successful validator run before `Enable-GitHubGovernance.ps1` can run. Local validation precedes governance, governance precedes the real governed proof PR, and Azure Repo deletion remains a separate optional checkpoint.

- [ ] **Step 4: Create the Draft acceptance review**

Create `docs/reviews/2026-09-28-tenant-1-lean-engineering-platform-acceptance-review.md` with repository metadata and Status `Draft`. Include a table with control, owner, required read-back, sanitized evidence, outcome, and rollback state for:

- clean branch history;
- one validator;
- local backup/restore;
- local discovery;
- every maintained Bicep build;
- subscription `what-if`;
- attended-context and minimum-access preflight/read-back;
- GitHub settings/ruleset/Dependabot;
- Basic Boards Issue;
- optional empty Azure Repo decision;
- real `Fixes AB#` link and transition;
- source-branch deletion; and
- merged-main green state.

Every outcome starts as `Not Run`. Add explicit non-claims for Azure Pipeline, Power Platform deployment, infrastructure deployment, trust activation, and Agile conversion. Catalogue the review in `docs/reviews/README.md` and `docs/README.md`. Do not alter the active point-in-time configuration review or its evidence.

- [ ] **Step 5: Run documentation tests and verify green**

```powershell
Invoke-Pester -Path @(
    'infra\tests\pester\RunbookDocumentation.Tests.ps1'
    '.github\cli\tests\DocumentationLinks.Tests.ps1'
    '.github\cli\tests\DocumentationMetadata.Tests.ps1'
) -Output Detailed
```

Expected: PASS.

- [ ] **Step 6: Commit the checkpoint and Draft review**

```powershell
git add infra/docs/24-tenant-1-lean-platform-runbook.md infra/tests/pester/RunbookDocumentation.Tests.ps1 docs/reviews docs/README.md
git commit -m 'docs: prepare lean platform acceptance checkpoints' -m 'Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>'
```

Review `$TaskBase..HEAD` before Task 8. No live setting, role, work item, repository, or deployment mutation occurs in this task.

---

### Task 8: Add Safety Coverage, Acceptance Review, and Complete Verification

**Files:**
- Modify: `.github/cli/verify-repository-safety.ps1`
- Modify: `.github/cli/tests/RepositorySafety.Tests.ps1`
- Modify: `infra/tests/pester/CloudFoundationStaticSafety.Tests.ps1`
- Modify: `infra/tests/pester/RunbookDocumentation.Tests.ps1`
- Modify only when supported by sanitized read-back: `docs/reviews/2026-09-28-tenant-1-lean-engineering-platform-acceptance-review.md`
- Modify: `docs/reviews/README.md`
- Modify: `docs/README.md`

**Interfaces:**
- Consumes: all Tasks 1-7 and the branch merge base.
- Produces: deterministic private-boundary scan, merge-base history safety, documentation acceptance record, full green suite, task review, and final review.

- [ ] **Step 1: Write failing safety tests**

Add a fixture-driven `RepositorySafety.Tests.ps1` case:

```powershell
It 'allows only the template and exact preserved Tenant 2 files in tracked tenant boundaries' {
    $tracked = @(& $script:gitPath -C $script:repositoryRoot ls-files -- `
        'infra/src/config/tenants/*.psd1' 'infra/evidence/discovery/*.json')
    $tracked | Should -Be @(
        'infra/evidence/discovery/caldova25668747.json'
        'infra/src/config/tenants/_template.psd1'
        'infra/src/config/tenants/caldova25668747.psd1'
    )
    & $script:gitPath -C $script:repositoryRoot ls-files -- 'infra/src/config/tenants/*.local.psd1' |
        Should -BeNullOrEmpty
}
```

Add negative fixture cases for a tracked `tenant1.local.psd1`, another manifest, another discovery file, or a Tenant 2 path with a different blob. Assert the exact preserved blob IDs from Global Constraints.

- [ ] **Step 2: Replace fixed-depth history safety with merge-base safety**

In `CloudFoundationStaticSafety.Tests.ps1`, replace `HEAD~5..HEAD` with:

```powershell
$git = (Get-Command git.exe -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
$baseRef = if ([string]::IsNullOrWhiteSpace($env:GITHUB_BASE_REF)) { 'origin/main' } else { "origin/$env:GITHUB_BASE_REF" }
$mergeBase = (& $git -C $script:RepositoryRoot merge-base $baseRef HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $mergeBase -cnotmatch '^[0-9a-f]{40}$') {
    throw 'Cannot resolve cloud-safety merge base.'
}
$changed = @(& $git -C $script:RepositoryRoot diff --name-only --diff-filter=ACDMRTUXB "$mergeBase...HEAD")
foreach ($workflowPath in @($changed | Where-Object { $_ -match '^(?i)\.github/workflows/.+\.ya?ml$' })) {
    $content = Get-Content -Raw -LiteralPath (Join-Path $script:RepositoryRoot $workflowPath)
    $content | Should -Not -Match 'Get-CloudFoundationPlan|Invoke-CloudFoundation' -Because $workflowPath
}
```

This independently implements the intended fix on the clean branch. Do not copy or modify the historical worktree's uncommitted partial edit.

- [ ] **Step 3: Run safety tests and verify red, then implement the inventory scan**

```powershell
Invoke-Pester -Path @(
    '.github\cli\tests\RepositorySafety.Tests.ps1'
    'infra\tests\pester\CloudFoundationStaticSafety.Tests.ps1'
) -Output Detailed
```

Expected initial result: FAIL until `.github/cli/verify-repository-safety.ps1` validates the exact tracked boundary and blob IDs. Add the same inventory logic to the real verifier, using Git object IDs rather than reading or printing Tenant 2 content. Rerun and expect PASS.

The verifier uses:

```powershell
$gitPath = (Get-Command git.exe -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
$trackedTenantFiles = @(
    & $gitPath -C $repositoryRootPath ls-files -- `
        'infra/src/config/tenants/*.psd1' `
        'infra/evidence/discovery/*.json'
)
$allowedTenantFiles = @(
    'infra/evidence/discovery/caldova25668747.json'
    'infra/src/config/tenants/_template.psd1'
    'infra/src/config/tenants/caldova25668747.psd1'
)
if (($trackedTenantFiles -join "`n") -cne ($allowedTenantFiles -join "`n")) {
    [void]$failures.Add('Tracked tenant configuration/evidence inventory is not the reviewed lean boundary.')
}
$expectedTenant2Blobs = @{
    'infra/src/config/tenants/caldova25668747.psd1' = 'f4b2dfed2f42d1d9d95d51dddaeaaedf4d8b6dce'
    'infra/evidence/discovery/caldova25668747.json' = 'c2d4d66f4f812fc449752c275845fac5a713915e'
}
foreach ($entry in $expectedTenant2Blobs.GetEnumerator()) {
    $actualBlob = (& $gitPath -C $repositoryRootPath hash-object -- $entry.Key).Trim()
    if ($LASTEXITCODE -ne 0 -or $actualBlob -cne $entry.Value) {
        [void]$failures.Add("Protected Tenant 2 blob changed: $($entry.Key)")
    }
}
```

Update `New-SafetyFixture` to create the two tenant directories, copy the exact protected Tenant 2 files from `$script:repositoryRoot`, create a synthetic `_template.psd1`, run `git init`, and `git add` those three allowed files. Each negative test then creates or edits its offending file and stages it before invoking the verifier; this makes the real `git ls-files` and `git hash-object` boundary testable without weakening production behavior.

- [ ] **Step 4: Validate the Draft acceptance review without rewriting historical audit evidence**

Verify `docs/reviews/2026-09-28-tenant-1-lean-engineering-platform-acceptance-review.md` still has Status `Draft`. Keep the existing configuration review and generated evidence immutable. The new review contains:

- control, owner, required evidence, observed sanitized evidence, and outcome;
- separate outcomes for workflow, local backup, attended context, minimum-access preflight, discovery, Bicep build, `what-if`, access read-back, governance, Boards, traceability, branch deletion, and main-green state;
- `Not Run` until a checkpoint has actual read-back;
- explicit non-claims for Azure Pipeline, Power Platform deployment, and infrastructure deployment; and
- rollback status for every mutated surface.

Confirm `docs/reviews/README.md` and `docs/README.md` catalogue the Draft review without changing the historical review's counts, control results, screenshots, or status. Change an outcome from `Not Run` only when sanitized read-back collected in this task proves it.

- [ ] **Step 5: Run every maintained test exactly as CI will**

```powershell
$GitHubTests = @(
    Get-ChildItem -LiteralPath '.github\cli\tests' -Filter '*.Tests.ps1' -File |
        Sort-Object FullName |
        Select-Object -ExpandProperty FullName
)
$Result = Invoke-Pester -Path @($GitHubTests + @('infra\tests\pester', 'hr\tests\pester')) -Output Detailed -CI -PassThru
if ($Result.FailedCount -gt 0) {
    throw "$($Result.FailedCount) maintained test(s) failed."
}
```

Expected: zero failed tests. This includes documentation metadata and link tests.

- [ ] **Step 6: Run safety, every maintained Bicep build, and whitespace**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File '.github\cli\verify-repository-safety.ps1'
if ($LASTEXITCODE -ne 0) { throw 'Repository safety validation failed.' }

$EntryPoints = @(
    Get-ChildItem -LiteralPath 'infra\src\bicep' -Filter '*.bicep' -File -Recurse |
        Sort-Object FullName
)
if ($EntryPoints.Count -eq 0) { throw 'No maintained Bicep entry point was found.' }
foreach ($EntryPoint in $EntryPoints) {
    az bicep build --file $EntryPoint.FullName --stdout | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Bicep build failed: $($EntryPoint.FullName)" }
}

$MergeBase = git merge-base origin/main HEAD
if ($LASTEXITCODE -ne 0 -or $MergeBase -cnotmatch '^[0-9a-f]{40}$') {
    throw 'Cannot resolve final verification merge base.'
}
git diff --check "$MergeBase...HEAD"
if ($LASTEXITCODE -ne 0) { throw 'Whitespace validation failed.' }
```

- [ ] **Step 7: Prove topology, history isolation, and private boundary**

```powershell
$Workflows = @(Get-ChildItem -LiteralPath '.github\workflows' -Filter '*.yml' -File)
if ($Workflows.Count -ne 1 -or $Workflows[0].Name -cne 'validate-repository.yml') {
    throw 'Workflow inventory is not exact.'
}
git merge-base --is-ancestor 6b9eaa6 HEAD
if ($LASTEXITCODE -eq 0) { throw 'Superseded Task 2 entered lean history.' }

foreach ($entry in @(
    @{ Path = 'infra/src/config/tenants/caldova25668747.psd1'; Blob = 'f4b2dfed2f42d1d9d95d51dddaeaaedf4d8b6dce' }
    @{ Path = 'infra/evidence/discovery/caldova25668747.json'; Blob = 'c2d4d66f4f812fc449752c275845fac5a713915e' }
)) {
    $actual = git rev-parse "HEAD:$($entry.Path)"
    if ($actual -cne $entry.Blob) { throw "Protected Tenant 2 file changed: $($entry.Path)" }
}

$TrackedLocal = @(git ls-files -- 'infra/src/config/tenants/*.local.psd1')
$AllowedManifests = @('infra/src/config/tenants/_template.psd1', 'infra/src/config/tenants/caldova25668747.psd1')
$AllowedEvidence = @('infra/evidence/discovery/caldova25668747.json')
$UnexpectedManifests = @(git ls-files 'infra/src/config/tenants/*.psd1' | Where-Object { $_ -notin $AllowedManifests })
$UnexpectedEvidence = @(git ls-files 'infra/evidence/discovery/*.json' | Where-Object { $_ -notin $AllowedEvidence })
if ($TrackedLocal.Count -ne 0 -or $UnexpectedManifests.Count -ne 0 -or $UnexpectedEvidence.Count -ne 0) {
    throw 'Tenant 1 private artifacts remain tracked or an unapproved tenant artifact exists.'
}
```

- [ ] **Step 8: Run the plan consistency and incomplete-marker scan**

```powershell
$PlanPath = 'docs\plans\2026-09-28-tenant-1-lean-engineering-platform-implementation.md'
$PlanText = Get-Content -Raw -LiteralPath $PlanPath
$IncompleteMarkers = @(
    'T' + 'BD'
    'T' + 'ODO'
    'fill ' + 'in details'
    'implement' + ' later'
    'Similar ' + 'to Task'
)
foreach ($Marker in $IncompleteMarkers) {
    if ($PlanText.IndexOf($Marker, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
        throw "Incomplete plan marker found: $Marker"
    }
}
```

Also verify every path in each task exists at the point it is consumed or is explicitly created earlier, every command is Windows PowerShell 5.1 compatible, and every commit block contains the required trailer.

- [ ] **Step 9: Commit the safety slice**

```powershell
git add .github/cli infra/tests/pester/CloudFoundationStaticSafety.Tests.ps1 infra/tests/pester/RunbookDocumentation.Tests.ps1 docs/reviews docs/README.md
git commit -m 'test: verify lean platform acceptance boundary' -m 'Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>'
```

- [ ] **Step 10: Complete task and final reviews**

Request task review for `$TaskBase..HEAD`, resolve findings, rerun Steps 5-7, then request final review for `$ReviewBase..HEAD`. The final reviewer must explicitly check spec coverage, task boundaries, signatures, test/code consistency, Windows commands, links, private-data handling, rollback, failure semantics, and every acceptance criterion below.

- [ ] **Step 11: Merge all tool changes before activating protection**

Open the implementation pull request while the old governance still permits the transition. Require Steps 5-7 and final review to pass, obtain approval, and squash-merge. Do not apply the new ruleset before the code and validator are on `main`, because doing so can deadlock the transition.

- [ ] **Step 12: Require one successful current-main validator run**

```powershell
$ValidatorRunIdText = (Read-Host 'Enter the successful current-main Validate repository run ID').Trim()
[long]$ValidatorRunId = 0
if (-not [long]::TryParse($ValidatorRunIdText, [ref]$ValidatorRunId) -or $ValidatorRunId -le 0) {
    throw 'Validator run ID must be a positive integer.'
}
gh run view $ValidatorRunId --repo urruegg/caldova-hr-frontier --json databaseId,workflowName,headBranch,headSha,status,conclusion,jobs
if ($LASTEXITCODE -ne 0) { throw 'Cannot read the validator run.' }
```

The attended reviewer confirms workflow `Validate repository`, branch `main`, current `main` SHA, status `completed`, conclusion `success`, and job `Repository setup validation` success.

- [ ] **Step 13: Run attended local validation through access read-back**

Follow the runbook in order. Before local validation, confirm the separately approved pre-existing minimum-access record outside Git. After `Invoke-TenantBootstrap.ps1`, read back the attended principal, tenant, subscription, and effective minimum-access context and require an exact match. Sanitize `what-if` output locally. Stop on unexpected resource type, scope, deletion, replacement, tenant, subscription, principal, or access state. Do not mutate roles or run deployment create.

- [ ] **Step 14: Apply and read back minimal GitHub governance**

First prove zero-mutation output:

```powershell
.\infra\src\scripts\Enable-GitHubGovernance.ps1 `
    -Repository 'urruegg/caldova-hr-frontier' `
    -ValidatorRunId $ValidatorRunId `
    -DesiredStatePath 'infra\src\config\github\main-ruleset.json' `
    -WhatIf
```

Compare the proposal to captured pre-state, obtain attended approval, then rerun without `-WhatIf`. Read back repository settings, every ruleset that applies to `main`, detailed `main` ruleset, and Dependabot automated security fixes. Require the exact values from Task 5.

- [ ] **Step 15: Apply the Basic Boards operation**

Run `Initialize-AzureBoardsLeanSprint.ps1 -WhatIf` first. If current-sprint dates were not supplied by the owner, omit both date parameters and preserve existing dates. After attended approval, use `-Apply`, read back Basic process, team, root area, current iteration, and the created or reused Issue.

Capture the durable positive Issue ID:

```powershell
$IssueIdText = (Read-Host 'Enter the read-back Azure Boards Issue ID').Trim()
[int]$IssueId = 0
if (-not [int]::TryParse($IssueIdText, [ref]$IssueId) -or $IssueId -le 0) {
    throw 'Azure Boards Issue ID must be a positive integer.'
}
```

- [ ] **Step 16: Keep empty Azure Repo deletion separate and optional**

Follow Task 6 only if the Azure DevOps project administrator wants to consider deletion. A repo with any size, default branch, ref, item, ambiguity, or failed read remains preserved. Do not combine this approval with GitHub governance or Boards approval.

- [ ] **Step 17: Create the one real governed proof pull request**

Create a documentation-only branch for an approved, accurate update to the Draft acceptance review. Change only outcomes already proven by sanitized read-back; post-merge outcomes remain `Not Run`.

```powershell
$ProofBranch = "docs/tenant1-lean-proof-$IssueId"
git switch -c $ProofBranch
git add 'docs/reviews/2026-09-28-tenant-1-lean-engineering-platform-acceptance-review.md'
git commit -m 'docs: record lean platform proof inputs' -m 'Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>'

$PrBodyRoot = Join-Path $env:LOCALAPPDATA 'Caldova\HrFrontier\proof'
[void](New-Item -ItemType Directory -Path $PrBodyRoot -Force)
$PrBodyPath = Join-Path $PrBodyRoot "pr-$IssueId.md"
$PrBody = @"
Fixes AB#$IssueId

Records only sanitized Tenant 1 lean-platform outcomes supported by attended read-back.
"@
[System.IO.File]::WriteAllText($PrBodyPath, $PrBody, [System.Text.UTF8Encoding]::new($false))
git push --set-upstream origin $ProofBranch
gh pr create --repo urruegg/caldova-hr-frontier --base main --head $ProofBranch `
    --title 'docs: record Tenant 1 lean platform proof' --body-file $PrBodyPath
```

Require `Repository setup validation` and all conversations resolved. Confirm the ruleset has zero required approvals and no required CODEOWNERS review under the recorded solo-owner profile, then squash-merge through the protected branch.

- [ ] **Step 18: Read back the complete transaction and acceptance**

Verify:

- the proof PR merged by squash;
- its source branch no longer exists;
- the Azure Boards GitHub App shows the real branch, commit, and PR link;
- the durable Basic Issue made the intended state transition;
- `main` points at the merged commit; and
- `Repository setup validation` is green on that exact `main` commit.

Failure of any item means the sprint is not accepted. Do not infer linkage or transition from PR text alone. Keep the sanitized post-merge read-back with the attended acceptance record; if repository documentation must later record it, use a separately reviewed corrective PR rather than rewriting the completed transaction.

## Sprint Acceptance

Do not change the acceptance review from `Draft` to repository-supported status `Active` until all are true:

- `feat/tenant1-lean-platform` descends from `dc6ad37e63a71e1d04674964ccda9ba38ea4e332`, contains the approved lean decision and plan commits, and does not contain `6b9eaa6` or the historical partial diff.
- ADR-0001, ADR-0002, ADR-0012, and catalogues identify Option A as current.
- `.github/workflows/validate-repository.yml` is the only workflow; its only job/check is `Repository setup validation`; it runs all `.github/cli/tests`, infrastructure tests, HR tests, safety, every maintained Bicep entry point, and merge-base whitespace validation.
- Checkout remains pinned to `3d3c42e5aac5ba805825da76410c181273ba90b1`; permissions remain `contents: read`.
- The encrypted external Tenant 1 backup, SHA-256 comparison, separate restore, schema parse, and ignored local file are proven before public Tenant 1 artifact deletion.
- Tenant 1 committed manifest/evidence are absent; the exact Tenant 2 manifest/evidence blobs are unchanged and never selected by Tenant 1 operations.
- Every active live script requires explicit local configuration, rejects tracked/template/wrong-tenant paths, writes private outputs outside Git, and uses an attended user.
- Attended-context and minimum-access preflight/read-back, local discovery, sanitized review, every maintained Bicep build, subscription `what-if`, and boundary validation pass; no role mutation or deployment is created.
- `Initialize-TenantTrust.ps1` is dormant, not run by validation, and not presented as supported.
- The minimal `main` ruleset enforces PRs, resolved conversations, the sole required check, force-push block, deletion block, and squash only. It requires zero approvals and no CODEOWNERS review under the recorded solo-owner profile.
- Repository settings delete merged branches, disable Projects, disable merge/rebase, enable squash, and enable Dependabot security updates; exact read-back passes.
- Azure Boards remains Basic with the existing team and root area; only approved current-sprint dates change; one durable Issue exists; the optional 19-Epic tool remains independent.
- Any Azure Repo deletion occurs only after the separate attended empty/no-default/no-ref/no-item proof and approval.
- A real PR uses `Fixes AB#` with the durable Issue, passes governance, squash-merges, deletes its source branch, links/transitions in Boards, and leaves the merged `main` commit green.
- The full maintained test suite, safety verifier, Bicep builds, documentation tests, topology checks, private-boundary scan, task reviews, and final review pass.
- No Azure Pipeline, service connection, artifact, Power Platform deployment, infrastructure deployment, bootstrap identity, federated credential, bootstrap Environment, cloud configuration retrieval, Agile conversion, tenant catalogue, transition package, or private overlay is created or claimed.
