# Tenant 1 End-to-End Acceptance Implementation Plan

| Field | Value |
|---|---|
| **Version** | 1.1 |
| **Date** | 2026-10-03 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Draft |
| **Scope** | Attended Tenant 1 execution, acceptance review, fresh-laptop continuation, local TenantReplica validation, and post-acceptance documentation disposition |
| **References** | [Approved Coordinate-Only Simplification Design](../specs/2026-10-03-tenant-lifecycle-coordinate-only-simplification-design.md), [Coordinate-Only Correction Plan](2026-10-03-tenant-lifecycle-coordinate-only-correction-implementation.md), [Approved Tenant 1 Runbook End-to-End Design](../specs/2026-10-02-tenant-1-runbook-end-to-end-design.md), [Lifecycle Core Plan](2026-10-02-tenant-lifecycle-core-implementation.md), [Workstation Plan](2026-10-02-developer-workstation-runbook-refactor-implementation.md), [Cloud Core Plan](2026-10-02-cloud-service-foundation-core-implementation.md), [Power Platform DEV Delivery Plan](2026-10-02-power-platform-dev-delivery-implementation.md), [Tenant Replica Plan](2026-10-02-tenant-replica-handover-implementation.md) |

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Execute one attended, evidence-bound Tenant 1 lifecycle from the current developer workstation through exact DEV delivery, prove NoChange and fresh-laptop continuation, validate a local TenantReplica, and publish a new sanitized acceptance review before replacing or archiving legacy runbook documentation.

**Architecture:** This plan consumes the already merged and locally accepted outputs of Plans 1-5; it does not build around a failed prerequisite. One run ID and external evidence root correlate workstation, private-boundary, provider, Bicep, pipeline, Power Platform, rerun, fresh-laptop, and replica evidence. Every write boundary has a hard human STOP, exact digest approval, immediate read-back, and forward-only recovery; only sanitized review material enters Git.

**Tech Stack:** Windows 11, Windows PowerShell 5.1 (authoritative), Pester 5.7.1, reviewed PowerShell 7, Git/GitHub CLI, Azure CLI/Bicep, Azure DevOps CLI/REST, PAC CLI, Azure Pipelines, Power Platform Build Tools 2.0 with WIF, and the accepted runbook modules/scripts from Plans 1-5.

**Spec:** [`docs/specs/2026-10-03-tenant-lifecycle-coordinate-only-simplification-design.md`](../specs/2026-10-03-tenant-lifecycle-coordinate-only-simplification-design.md), as the focused corrective authority over [`docs/specs/2026-10-02-tenant-1-runbook-end-to-end-design.md`](../specs/2026-10-02-tenant-1-runbook-end-to-end-design.md)

## 2026-10-03 Coordinate-Only Operator-Sequence Amendment

This plan remains `Draft` and blocked until the [coordinate-only correction](2026-10-03-tenant-lifecycle-coordinate-only-correction-implementation.md) and corrected Plans 1-5 are merged and then-current `main` is green. The Non-Negotiable Entry STOP, all hard attended STOPs, and controls `T1-E2E-01` through `T1-E2E-14` remain unchanged.

The controlling operator sequence is:

1. invoke each independently runnable child directly in Plan mode and validate its child execution manifest;
2. obtain exact child approval in that phase's `approvals.json`;
3. invoke that child directly with WhatIf and review the exact approved actions;
4. invoke that child directly with Apply only after its existing hard STOP and child-specific approval;
5. complete provider-specific or local child read-back, child state adoption where applicable, and the terminal child summary;
6. write the immutable canonical child stage result at `<run>/stages/<stage>.json`;
7. repeat for each dependency in the accepted order, stopping on every `Failed`, `Manual`, `Blocked`, or `Refused` result; and
8. only after the exact selected stage-result set exists, run `Invoke-TenantLifecycle.ps1 -Mode Verify` with no `SubsystemInvoker` and require every dependency result to have literal status `Passed`.

The sequence above replaces every reading of this plan that implies umbrella Apply, one umbrella approval, umbrella `ApprovedDigest`, umbrella `CurrentBindingProvider`, umbrella action evidence, or umbrella provider/resource correlation. In particular:

- Task 2 owns the `Workstation` and `PrivateBoundary` child manifests, approvals, Apply/read-back, summaries, and stage results.
- Tasks 3-5 own foundation assessment and the `Foundation` child manifest, approval, WhatIf/Apply/read-back, summary, and stage result.
- Task 6 owns the `DevDelivery` child manifest/approval, attended checkpoint, pipeline/import Apply, read-back, summary, and stage result.
- Task 7 owns the fresh child NoChange plan/approval/invocation/read-back and `ReadBack` stage result.
- Task 9 owns the local `TenantReplica` child manifest/approval/WhatIf/Apply/independent read-back, summary, and stage result.
- Task 10 records the `Acceptance` stage result only after the unchanged human acceptance gate is satisfied, then runs coordinate-only umbrella Verify before any final status or archive disposition.

Provider IDs, URLs, role IDs, pipeline/action IDs, payloads, and raw read-back remain in child evidence. The umbrella summary and committed sanitized projection contain only stage-level provenance, status/classification, child manifest/summary digests, and fixed nonclaims.

## Non-Negotiable Entry STOP

> **STOP — THIS PLAN CANNOT EXECUTE YET.** Do not run Task 1 or any live/read-only provider command until Plans 1-5 are merged into current `main`, the current-main GitHub `Repository setup validation` check is green for the exact execution SHA, all local authoritative tests pass, and the private prerequisites listed below are present. The approval of this plan is not approval to mutate a workstation or provider.

Required private prerequisites, all outside Git:

1. restored or re-entered `infra/src/config/tenants/tenant1.local.psd1`;
2. schema-valid `infra/src/config/tenants/tenant1.state.local.json`;
3. encrypted backup containing both artifacts;
4. successful equality proof from a separate restore root;
5. named accountable owners and attended administrator availability;
6. exact Tenant 1 GitHub, Azure, Entra, Azure DevOps, PAC/Power Platform access ready for interactive authentication;
7. reviewed minimum DEV application-user role ID;
8. reviewed Build Tools 2.0/WIF capability for the Tenant 1 Azure DevOps organization; and
9. an external raw-evidence location and backup location that are not inside a Git worktree.

If any item is absent, stale, ambiguous, unauthorized, or cannot be independently read back, record `Blocked` outside Git and stop. Do not reconstruct private intent from discovery, prose, old transition files, Tenant 2 files, or historical evidence.

## Global Constraints

- This is Plan 6 and depends on all Plans 1-5. No task may bypass the entry STOP.
- At execution time, use `superpowers:using-git-worktrees`. Create branch `ops/tenant1-end-to-end-acceptance` and documentation worktree `%LOCALAPPDATA%\CaldovaHR\wt\caldova-hr-frontier\t1-accept`. Create a second clean execution worktree `%LOCALAPPDATA%\CaldovaHR\wt\caldova-hr-frontier\t1-run` pinned to the exact then-current green `main` SHA; do not edit or commit in `t1-run`. Verify current-user write/delete access and a longest checkout path **less than 240 characters** for both. Acceptance-review commits in `t1-accept` must never change the exact source SHA used for tests, plans, Bicep, and pipeline.
- Windows PowerShell 5.1 with Pester 5.7.1 is authoritative. Use only the exact reviewed PowerShell 7/tool versions from Plans 2 and 4.
- Raw evidence stays outside Git at `%LOCALAPPDATA%\CaldovaHR\runbook-evidence\<run-id>\`; generated parameters, templates containing private context, command transcripts, provider responses, auth output, and pipeline protected values remain local.
- The proposed committed review path is `docs/reviews/2026-10-02-tenant-1-runbook-end-to-end-acceptance-review.md`. Its metadata `Date` must be the actual review date; do not backdate it. Update `docs/reviews/README.md` in the same change. Never overwrite either 2026-09-28 review.
- Use acceptance IDs `T1-E2E-01` through `T1-E2E-13` exactly. The new review also satisfies the umbrella specification's sanitized-review control `T1-E2E-14`; it does not renumber or replace IDs 01-13.
- No result is accepted when `Manual`, `Blocked`, `Refused`, `Not Run`, stale, failed, ambiguous, or lacking exact read-back. Stop at the first such outcome.
- Every mutation performs immediate pre-read, exact stable-ID target selection, per-action `ShouldProcess`, exact approved action, and immediate post-read. No first-match selection, self-elevation, hidden consent, broad role grant, secret fallback, automatic rollback, or deletion.
- Reconcile forward after fresh assessment. Never splice evidence or approval across attempts.
- GitHub writes are limited to accepted existing-repository properties. No repository creation/publication and no GitHub Actions delivery expansion.
- Azure applies exact approved Bicep bytes in incremental mode only. Delete/complete mode/deployment stack is prohibited.
- Azure DevOps writes are limited to the accepted project/pipeline/DEV environment/WIF protected resources. No Azure Repo source, PAT, secret service connection, or automatic trigger.
- Power Platform mutation is DEV only. TEST and PROD are exact-context read-only; no import, application user, role, connection, promotion, or pipeline stage for either.
- Pipeline import uses the exact published package bytes; no deployment-stage rebuild.
- No Tenant 2 login, provider call, repository/project creation, validation, or mutation. `TenantReplica` is local only and never published.
- Archive/move/status changes occur only after replacement runbooks are implemented, local tests pass, and the new acceptance review is explicitly accepted by a human. Retain runbooks 20 and 21 as stop notices.
- Each task has a RED/GREEN evidence gate, focused review, and a focused commit with `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>`. Raw evidence is never staged.

## Acceptance and File Map

| ID | Plan task | Required result |
|---|---|---|
| `T1-E2E-01` | Task 1 | Exact execution SHA is locally green and current-main repository CI is green. |
| `T1-E2E-02` | Task 2 | Workstation assess/plan/approval/Apply/read-back/restart/NoChange passes. |
| `T1-E2E-03` | Task 2 | Private intent/state ignored boundary plus encrypted backup/separate restore equality passes. |
| `T1-E2E-04` | Task 3 | Fresh exact provider-context inventory passes. |
| `T1-E2E-05` | Task 4 | Deterministic plan and subscription `what-if` are approved by exact digest. |
| `T1-E2E-06` | Task 5 | Exact incremental Bicep deployment/read-back matches approved `what-if`. |
| `T1-E2E-07` | Task 6 | Pipeline exact SHA/digest and immutable package provenance pass. |
| `T1-E2E-08` | Task 6 | Same package imports to exact DEV; app user/role/solution read-back passes. |
| `T1-E2E-09` | Task 6 | Unchanged pipeline rerun is idempotent with identical package bytes. |
| `T1-E2E-10` | Task 7 | Fresh foundation run contains no `Create` or `Update`. |
| `T1-E2E-11` | Tasks 3 and 6 | TEST/PROD exact identities are read back and remain unchanged. |
| `T1-E2E-12` | Task 8 | Fresh Windows 11 laptop continuation reaches foundation NoChange and pipeline/read-back proof. |
| `T1-E2E-13` | Task 9 | Local TenantReplica passes complete independent validation with no private material. |

Files created or changed only through this plan:

- Create: `infra/docs/runbooks/04-tenant-1-end-to-end-acceptance.md`
- Create: `docs/reviews/2026-10-02-tenant-1-runbook-end-to-end-acceptance-review.md`
- Update: `docs/reviews/README.md`
- Rewrite after acceptance: `infra/docs/runbooks/01-developer-workstation.md`, `02-cloud-service-foundation.md`, `03-customer-handover.md`, and the infrastructure guidance/catalogues named in Task 10.
- Archive after acceptance: `infra/docs/17-bootstrap-and-provisioning.md`, `19-bootstrap-recovery.md`, `22-repository-cleanup-runbook.md`, `23-customer-repository-export-and-handover-runbook.md`, and `24-tenant-1-lean-platform-runbook.md` into `docs/archive/tenant-1-legacy-runbooks/`.
- Retain in place: `infra/docs/20-tenant-trust-activation-runbook.md` and `infra/docs/21-azure-boards-population-runbook.md`.

---

### Task 1: Current-Developer-System Readiness and T1-E2E-01

**Files:**
- Create: `infra/docs/runbooks/04-tenant-1-end-to-end-acceptance.md`
- Create: `docs/reviews/2026-10-02-tenant-1-runbook-end-to-end-acceptance-review.md` with status `Draft` and every control `Not Run`.
- Modify: `docs/reviews/README.md`
- Test: existing repository, runbook, documentation, safety, setup, Bicep, and workflow-neutral suites.

**Interfaces:**
- Consumes: merged Plans 1-5 and current-main CI.
- Produces run variables `RunId`, `EvidenceRoot`, `ExecutionSourceCommit`, `MachineId`, and an external readiness record; only source SHA/status and sanitized results may enter the Draft review.

- [ ] **Step 1: Write the failing readiness review**

Create the acceptance runbook and Draft review with rows `T1-E2E-01` through `T1-E2E-14`, each `Not Run`, an exact evidence-relative-path column, owner/disposition, and explicit non-claims. Add documentation tests requiring the entry STOP, dependencies, evidence root, hard mutation gates, and historical-review preservation.

- [ ] **Step 2: Run RED**

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path @('.github/cli/tests','infra/tests/pester/RunbookDocumentation.Tests.ps1') -Output Detailed"
```

Expected: **FAIL** until the new runbook/review/catalogue entry is complete. Do not run any provider command.

- [ ] **Step 3: Complete local readiness verification**

Use the clean `t1-run` execution worktree from exact green `main`; keep review edits in `t1-accept`. Set:

```powershell
$RunId = [guid]::NewGuid()
$EvidenceRoot = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) `
  ('CaldovaHR\runbook-evidence\{0}' -f $RunId.ToString('D'))
$ExecutionSourceCommit = (git rev-parse HEAD).Trim().ToLowerInvariant()
```

Require full 40-hex SHA, clean/non-sparse checkout, exact remote, green current-main `Repository setup validation`, merged plan files, exact tools, and all nine private entry prerequisites. Run no live provider check yet. Record `T1-E2E-01` only after local and GitHub CI results refer to the exact SHA.

- [ ] **Step 4: Run GREEN**

```powershell
$ErrorActionPreference = 'Stop'
Import-Module Pester -RequiredVersion 5.7.1 -Force
$result = Invoke-Pester -Path @('.github/cli/tests','infra/tests/pester','hr/tests/pester') -Output Detailed -PassThru
if ($result.FailedCount -gt 0) { throw "$($result.FailedCount) test(s) failed." }
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .github/cli/verify-repository-safety.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .github/cli/verify-repository-setup.ps1
Get-ChildItem infra/src/bicep -Filter *.bicep -File -Recurse | ForEach-Object {
  az bicep build --file $_.FullName --stdout | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "Bicep build failed: $($_.FullName)" }
}
git diff --check
git diff --exit-code -- .github/workflows
```

Expected: all local checks **PASS**, current-main CI is green for `$ExecutionSourceCommit`, private prerequisites are present, and `T1-E2E-01` can move to `Pass`. Otherwise leave it failed/blocked and stop.

- [ ] **Step 5: Perform focused review and HARD STOP**

Verify raw evidence is outside Git, review has no private value/path/auth output, and no implementation-plan dependency is merely present on another branch. **HARD STOP:** obtain explicit attended authorization before any workstation Apply or live provider contact.

- [ ] **Step 6: Commit**

```powershell
git add infra/docs/runbooks/04-tenant-1-end-to-end-acceptance.md docs/reviews/2026-10-02-tenant-1-runbook-end-to-end-acceptance-review.md docs/reviews/README.md
git commit -m "docs(acceptance): initialize Tenant 1 end-to-end review" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 2: Workstation Apply, Restart, and Private Recovery — T1-E2E-02/03

**Files:**
- Update: new acceptance review only with sanitized outcomes.
- Raw external files: `assessment.json`, `execution-manifest.json`, `approvals.json`, `actions/*.json`, `read-back.json`, `summary.json`.
- Test: workstation and evidence Pester suites before execution.

**Interfaces:**
- Consumes: Plan 2 exact policy/compatibility, private paths, encrypted backup manifest.
- Produces accepted workstation outcome digest and private-boundary outcome digest for cloud prerequisites.

- [ ] **Step 1: Add failing pre-mutation gates**

In the Draft review, require evidence checks for standard-user token, exact machine/source/tools, worktree budget `<240`, ignored/untracked intent/state, encrypted backup, separate restore equality, approval digest, `-WhatIf`, post-read, restart invalidation, new approval, and second `NoChange`.

- [ ] **Step 2: Run RED**

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path @('infra/tests/pester/DeveloperWorkstationAssessment.Tests.ps1','infra/tests/pester/DeveloperWorkstationInitialization.Tests.ps1','infra/tests/pester/EvidenceSecurity.Tests.ps1') -Output Detailed"
```

Expected: tests **PASS**, but review controls remain **Not Run**. If tests fail, stop before mutation.

- [ ] **Step 3: HARD STOP, then execute the minimum attended local sequence**

> **HARD STOP — LOCAL MUTATION.** The workstation owner reviews the exact manifest and records an unexpired approval digest. Without that approval, run only assessment/plan/`-WhatIf` and stop.

Run `Test-DeveloperWorkstation.ps1`, then `Initialize-DeveloperWorkstation.ps1` in plan mode and `-WhatIf`. Review actions and create `approvals.json` outside Git. Run `-Apply` as the standard user. Complete any installer UI/elevation/restart only as an explicit human `Manual` boundary; the script does not self-elevate. After restart, perform a full new assessment/new manifest/new approval and require `NoChange`. Independently validate private backup/restore equality without serializing values.

For `tenant1.local.psd1`, restore from the approved encrypted backup when available. If no trusted backup exists, a human re-enters intent only from the reviewed authoritative source, validates it without provider access, creates a new encrypted backup, restores that backup to a separate external root, and proves equality before continuing. Restore `tenant1.state.local.json` only from trusted encrypted state; otherwise initialize empty tool-owned state and populate stable IDs solely through later fresh exact read-back. Never infer either file from discovery, prose, templates, or Tenant 2 artifacts.

- [ ] **Step 4: Run GREEN**

Run the focused tests again and validate external evidence with Plan 1 contracts. Expected: `T1-E2E-02` and `T1-E2E-03` **Pass**, every action has post-read, old approval is invalid after restart, new run has no `Create`/`Update`, and private artifacts remain ignored/untracked.

- [ ] **Step 5: Perform focused review**

Review only sanitized digests/statuses and explicit non-claims. Confirm no cloud auth occurred, no private value/hash entered Git, no ACL/long-path/security weakening occurred, and no stale approval resumed.

- [ ] **Step 6: Commit**

```powershell
git add docs/reviews/2026-10-02-tenant-1-runbook-end-to-end-acceptance-review.md
git commit -m "docs(acceptance): record workstation recovery evidence" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 3: Exact Interactive Context Preflight and Fresh Assessment — T1-E2E-04/11

**Files:**
- Update: new acceptance review only.
- Raw external file: `assessment.json`.
- Test: Tenant foundation context/assessment/static-safety suites.

**Interfaces:**
- Consumes: workstation/private prerequisite outcomes and exact private intent/state.
- Produces verified GitHub, Azure, Entra, Azure DevOps, DEV/TEST/PROD PAC context digests and fresh provider assessment.

- [ ] **Step 1: Add failing context evidence gates**

Require exact stable IDs for repository, tenant/subscription/principal, project/user, and all Power Platform stages; require zero ambiguity, current permissions, Build Tools/WIF capability, and TEST/PROD read-only disposition.

- [ ] **Step 2: Run RED**

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path @('infra/tests/pester/TenantFoundationContexts.Tests.ps1','infra/tests/pester/TenantFoundationAssessment.Tests.ps1','infra/tests/pester/CloudFoundationStaticSafety.Tests.ps1') -Output Detailed"
```

Expected: tests **PASS**, review remains **Not Run**. If not green, stop.

- [ ] **Step 3: HARD STOP, authenticate interactively, and assess read-only**

> **HARD STOP — LIVE PROVIDER CONTACT (READ-ONLY).** Obtain explicit attended live-assessment approval. Authentication is interactive per tool; no token is copied between tools or recorded.

Read back `gh auth status --hostname github.com`, `az account show`, Entra signed-in principal/roles, exact Azure DevOps connection/project/user, and PAC named profiles for DEV/TEST/PROD. Run `Test-TenantFoundation.ps1`. Any wrong context, 403/404, malformed/empty response, timeout, unsupported capability, stale state, or multiple match blocks before inventory/dependent work.

- [ ] **Step 4: Run GREEN**

Validate `assessment.json` against the schema and rerun context tests. Expected: `T1-E2E-04` **Pass**; the read-only portion of `T1-E2E-11` records exact TEST/PROD identities and no write; no provider mutation occurred.

- [ ] **Step 5: Perform focused review**

Confirm each tool proved itself independently, all stable IDs match private intent/state, permissions are least-privilege/attended, raw responses/auth output remain external, and historical reviews were not reused.

- [ ] **Step 6: Commit**

```powershell
git add docs/reviews/2026-10-02-tenant-1-runbook-end-to-end-acceptance-review.md
git commit -m "docs(acceptance): record exact provider assessment" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 4: Fresh Plan, Bicep What-If, and Human Digest Approval — T1-E2E-05

**Files:**
- Update: new acceptance review only.
- Raw external files: `execution-manifest.json`, `approvals.json`, compiled Bicep, generated parameters, raw `what-if`.
- Test: planning, evidence, and Bicep boundary suites.

**Interfaces:**
- Consumes: current assessment and exact source/intent/state/tool/context bindings.
- Produces one approved manifest digest binding ordered provider actions, Bicep source/template/parameters/what-if, pipeline source, HR solution-source tree, and prerequisites.

- [ ] **Step 1: Add failing plan/approval checks**

Require deterministic regeneration, no delete/unsupported `what-if`, explicit `Manual`/`Blocked` handling, complete action prerequisites, 30-minute expiry, and approver role/scope without credential/session data.

- [ ] **Step 2: Run RED**

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path @('infra/tests/pester/TenantFoundationPlanning.Tests.ps1','infra/tests/pester/TenantLifecycleContracts.Tests.ps1','infra/tests/pester/WhatIfBoundary.Tests.ps1') -Output Detailed"
```

Expected: tests **PASS**, review remains **Not Run** pending a fresh live plan.

- [ ] **Step 3: Generate plan and obtain exact human approval**

Run `New-TenantFoundationPlan.ps1`, inspect the complete manifest and sanitized `what-if`, resolve every required `Manual` checkpoint through independent read-back, and reject any `Blocked`/`Refused`/delete/unsupported change. The human approver records the exact manifest digest in `approvals.json`; approving a summary is invalid.

- [ ] **Step 4: Run GREEN**

Regenerate deterministically before expiry and validate exact bytes/digests. Expected: `T1-E2E-05` **Pass** with one fresh approved digest and zero provider writes.

- [ ] **Step 5: Perform focused review and HARD STOP**

Confirm source/intent/state/tools/contexts have not drifted and every mutation target is exact. **HARD STOP:** do not proceed to Task 5 until provider owners approve the exact mutation set and Bicep `what-if`.

- [ ] **Step 6: Commit**

```powershell
git add docs/reviews/2026-10-02-tenant-1-runbook-end-to-end-acceptance-review.md
git commit -m "docs(acceptance): record approved foundation digest" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 5: Foundation Apply and Incremental Azure Deployment — T1-E2E-06

**Files:**
- Update: new acceptance review only.
- Raw external files: `actions/*.json`, `read-back.json`, `summary.json`, deployment/what-if raw boundary.
- Test: provider-contract/invocation/idempotency suites immediately before mutation.

**Interfaces:**
- Consumes: exact fresh approved digest from Task 4.
- Produces exact post-read for GitHub, Entra app/SP/FIC, incremental Azure resources, Azure DevOps project/pipeline/DEV environment/WIF protected resources.

- [ ] **Step 1: Add failing mutation-entry assertions**

Require current approval, same bytes/contexts, fresh pre-read, zero ambiguity, per-action `ShouldProcess`, stop-first-failure, exact post-read, no deletion/rollback, no queue/import, and external atomic evidence.

- [ ] **Step 2: Run RED**

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path @('infra/tests/pester/TenantFoundationProviderContracts.Tests.ps1','infra/tests/pester/TenantFoundationInvocation.Tests.ps1','infra/tests/pester/Idempotency.Tests.ps1') -Output Detailed"
```

Expected: tests **PASS**, review remains **Not Run** pending live Apply.

- [ ] **Step 3: HARD STOP and Apply**

> **HARD STOP — LIVE FOUNDATION MUTATION.** Reconfirm owner approval, exact digest, expiry, contexts, and `ShouldProcess` targets. If anything changed, regenerate the plan and approval.

Run `Invoke-TenantFoundation.ps1 -WhatIf` first, compare displayed actions to the manifest, then run with `-Apply`. Stop on first failed/indeterminate action. For Azure, repeat `what-if`, verify approved template/parameter bytes, use incremental mode, and compare actual creates/updates with the sanitized approved result.

- [ ] **Step 4: Run GREEN**

Validate every action envelope/read-back and state update. Expected: `T1-E2E-06` **Pass**, exact Bicep-owned resources match, no implicit deletion, and pipeline was not queued.

- [ ] **Step 5: Perform focused review**

Confirm stable IDs, exact owned properties, credential-free federation, preserved unrelated state, no secret, no self-elevation, no TEST/PROD write, and forward-only recovery where needed.

- [ ] **Step 6: Commit**

```powershell
git add docs/reviews/2026-10-02-tenant-1-runbook-end-to-end-acceptance-review.md
git commit -m "docs(acceptance): record foundation apply read-back" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 6: DEV Application User, Pipeline, Exact Import, and Rerun — T1-E2E-07/08/09/11

**Files:**
- Update: new acceptance review only.
- Raw external files: `pipeline.json`, `power-platform.json`, `actions/*.json`, pipeline artifact/provenance.
- Test: Power Platform capability, pipeline static, solution delivery, and principal read-back suites.

**Interfaces:**
- Consumes: exact DEV environment, delivery application, WIF connection, protected variables, minimum role, source SHA, run ID, approved digest.
- Produces artifact `hr-solution-dev` with exact three files and exact DEV solution/application-user read-back.

- [ ] **Step 1: Add failing delivery-entry checks**

Require Build Tools 2.0 organization capability, WIF scheme read-back, DEV environment gate, attended exact app user/minimum role, full role-set equality, manual queue variables, immutable artifact members, package digest/provenance, no rebuild, exact import job/solution read-back, and TEST/PROD non-mutation.

- [ ] **Step 2: Run RED**

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path @('infra/tests/pester/PowerPlatformDeliveryCapabilities.Tests.ps1','infra/tests/pester/PowerPlatformPipeline.Tests.ps1','infra/tests/pester/PowerPlatformDevPrincipal.Tests.ps1','hr/tests/pester/SolutionDelivery.Tests.ps1') -Output Detailed"
```

Expected: tests **PASS**, review remains **Not Run** pending attended administration/pipeline.

- [ ] **Step 3: HARD STOP, complete attended checkpoint, and queue exact pipeline**

> **HARD STOP — DEV IDENTITY/ROLE AND SOLUTION MUTATION.** An authorized Power Platform administrator confirms the exact service principal, creates/adopts only its DEV application user, grants only the reviewed role, and permits independent read-back. Stop on extra/missing role or ambiguity.

After read-back passes, manually queue the exact pipeline with the eleven reviewed variables. Verify exact GitHub SHA and approved digest. Download `hr-solution-dev`, verify `package.sha256`/`provenance.json`, import the same bytes to DEV through WIF, and read back the import and supported solution properties. Then queue an unchanged rerun and require the same package digest and no duplicate resource.

- [ ] **Step 4: Run GREEN**

Validate pipeline/power-platform records and repeat read-only TEST/PROD IDs. Expected: `T1-E2E-07`, `08`, `09`, and `11` **Pass**; no TEST/PROD mutation; no claim that Dataverse exposes ZIP hash.

- [ ] **Step 5: Perform focused review**

Confirm no secret service connection, no deploy-stage rebuild, exact artifact bytes, exact full role set, no duplicate app user/identity/connection/pipeline/solution, and no production claim.

- [ ] **Step 6: Commit**

```powershell
git add docs/reviews/2026-10-02-tenant-1-runbook-end-to-end-acceptance-review.md
git commit -m "docs(acceptance): record exact DEV delivery evidence" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 7: Fresh Foundation Reassessment and NoChange Apply — T1-E2E-10

**Files:**
- Update: new acceptance review only.
- Raw external files: a new assessment/manifest/approval/action/read-back set under the same run with a distinct attempt ID.
- Test: lifecycle drift/idempotency suites.

**Interfaces:**
- Consumes: current post-Task-6 state; never reuses Task 4 assessment/approval.
- Produces a fresh approved manifest containing no `Create` or `Update`.

- [ ] **Step 1: Add failing second-run gate**

Require fresh assessment, new digest/approval, same stable IDs, exact owned properties, Bicep no owned changes, pipeline/protected resources match, DEV principal/role/solution match, and zero `Create`/`Update`.

- [ ] **Step 2: Run RED**

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path @('infra/tests/pester/TenantFoundationInvocation.Tests.ps1','infra/tests/pester/Idempotency.Tests.ps1','infra/tests/pester/TenantLifecycleOrchestration.Tests.ps1') -Output Detailed"
```

Expected: tests **PASS**, review remains **Not Run** until fresh live reassessment.

- [ ] **Step 3: Reassess, reapprove, and invoke NoChange**

Run fresh context verification and `Test-TenantFoundation.ps1`; create a new plan and approval. If any `Create`/`Update` appears, stop, investigate drift, and do not force idempotency. Invoke the approved NoChange plan and read back all supported properties.

- [ ] **Step 4: Run GREEN**

Expected: `T1-E2E-10` **Pass**, new manifest has zero `Create`/`Update`, and all stable IDs/read-back remain exact.

- [ ] **Step 5: Perform focused review**

Confirm no old digest/evidence was reused, no drift was normalized away, and no provider mutation occurred in the NoChange run.

- [ ] **Step 6: Commit**

```powershell
git add docs/reviews/2026-10-02-tenant-1-runbook-end-to-end-acceptance-review.md
git commit -m "docs(acceptance): record foundation NoChange rerun" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 8: Fresh-Laptop Continuation Handoff — T1-E2E-12

**Files:**
- Update: `infra/docs/runbooks/04-tenant-1-end-to-end-acceptance.md`
- Update: new acceptance review.
- Raw external evidence: separate fresh-laptop subdirectory under the same run ID.

**Interfaces:**
- Consumes: then-current accepted `main`, encrypted private backup, exact policies/tools, existing accepted foundation.
- Produces fresh-laptop workstation NoChange, foundation NoChange, exact pipeline/read-back proof, and sanitized continuation handoff record.

- [ ] **Step 1: Add failing fresh-laptop checklist tests**

Require fresh Windows 11, then-current main clone, approved external worktree, workstation assess/Apply/restart/NoChange, separate private restore, interactive context proof, foundation NoChange, exact-SHA pipeline verification, DEV read-back, external raw evidence, and no credential transfer.

- [ ] **Step 2: Run RED**

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path 'infra/tests/pester/RunbookDocumentation.Tests.ps1' -FullNameFilter '*fresh laptop*' -Output Detailed"
```

Expected: **FAIL** until the complete continuation handoff is documented.

- [ ] **Step 3: HARD STOP and perform attended continuation**

> **HARD STOP — SECOND MACHINE LIVE ACCESS.** Verify the fresh laptop and named operator are authorized. Transfer only the encrypted backup through the approved private channel; never transfer token caches or authenticated profiles.

Follow the exact nine-step fresh-laptop sequence in the workstation specification. Any source/tool/private/context mismatch, `Create`/`Update`, or failed pipeline/read-back stops acceptance.

- [ ] **Step 4: Run GREEN**

Run the documentation test and validate fresh-laptop evidence. Expected: `T1-E2E-12` **Pass**, workstation/foundation are NoChange, and no credential/auth-state transfer occurred.

- [ ] **Step 5: Perform focused review**

Confirm then-current main SHA, separate machine identity, backup equality, independent auth, exact provider IDs, no mutation, and sanitized handoff record.

- [ ] **Step 6: Commit**

```powershell
git add infra/docs/runbooks/04-tenant-1-end-to-end-acceptance.md docs/reviews/2026-10-02-tenant-1-runbook-end-to-end-acceptance-review.md
git commit -m "docs(acceptance): record fresh-laptop continuation" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 9: Local TenantReplica Export and Independent Validation — T1-E2E-13

**Files:**
- Update: new acceptance review only.
- Raw external files: replica assessment/manifest/approval/actions/independent-validation under the shared run ID.
- Test: repository export/profile/independent-validation suites.

**Interfaces:**
- Consumes: exact accepted source commit and canonical `TenantReplica` manifest.
- Produces one local external destination and independent validation result; no `.git`, remote, or publication.

- [ ] **Step 1: Add failing replica acceptance gates**

Require exact source snapshot, complete retain/deny/marker review, approved digest, `-WhatIf`, Apply, complete byte reconstruction, all retained-tree suites, source immutability, no private ID/state/evidence/transition artifact, and human content review.

- [ ] **Step 2: Run RED**

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path @('infra/tests/pester/RepositoryExportProfiles.Tests.ps1','infra/tests/pester/RepositoryExportIndependentValidation.Tests.ps1','infra/tests/pester/CustomerExportStaticSafety.Tests.ps1') -Output Detailed"
```

Expected: tests **PASS**, review remains **Not Run** until the local accepted export.

- [ ] **Step 3: HARD STOP and execute local export**

> **HARD STOP — LOCAL DESTINATION CREATION.** Review the complete manifest and exact digest. Confirm destination is empty/absent, external, disposable, and has no remote/publication target.

Run assessment, plan, `-WhatIf`, approved Apply, `Test-RepositoryExport.ps1 -Independent`, and human content review. Do not run `git init`, authenticate, publish, or contact Tenant 2.

- [ ] **Step 4: Run GREEN**

Validate independent result and source pre/post snapshot. Expected: `T1-E2E-13` **Pass**, complete tree matches, retained tests pass, prohibited material count is zero, and source is unchanged.

- [ ] **Step 5: Perform focused review**

Confirm no private/stable identifier/evidence/transition payload, no `.git`/remote/history, no publication, no Tenant 2 action, and no claim beyond local profile conformance.

- [ ] **Step 6: Commit**

```powershell
git add docs/reviews/2026-10-02-tenant-1-runbook-end-to-end-acceptance-review.md
git commit -m "docs(acceptance): record local TenantReplica validation" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 10: Sanitized Review Acceptance and Post-Acceptance Documentation Disposition

**Files:**
- Update: `docs/reviews/2026-10-02-tenant-1-runbook-end-to-end-acceptance-review.md`
- Update: `docs/reviews/README.md`
- Rewrite: `infra/README.md`, `infra/docs/README.md`, `infra/docs/runbooks/README.md`
- Rewrite: `infra/docs/runbooks/01-developer-workstation.md`, `02-cloud-service-foundation.md`, `03-customer-handover.md`
- Rewrite links/authority: `infra/docs/10-tenant-setup-and-configuration.md`, `11-identity-and-access.md`, `12-power-platform-environments-and-alm.md`, `13-azure-devops-engineering-control-plane.md`, `14-github-repository-blueprint.md`, `16-security-governance-and-compliance.md`, `18-multi-tenant-provisioning.md`, `15-agent-workload-configuration.md`
- Create: `docs/archive/tenant-1-legacy-runbooks/README.md`
- Move into that folder: `17-bootstrap-and-provisioning.md`, `19-bootstrap-recovery.md`, `22-repository-cleanup-runbook.md`, `23-customer-repository-export-and-handover-runbook.md`, `24-tenant-1-lean-platform-runbook.md`
- Update: `docs/archive/README.md`, `docs/README.md`
- Retain unchanged except repaired successor links if required: `infra/docs/20-tenant-trust-activation-runbook.md`, `21-azure-boards-population-runbook.md`

**Interfaces:**
- Consumes: passing `T1-E2E-01` through `T1-E2E-13`, sanitized projection, explicit human acceptance.
- Produces: `T1-E2E-14` sanitized review result, accepted replacement routing, complete direct-child catalogues, and a historical archive with successor links.

- [ ] **Step 1: Write failing review/archive/navigation tests**

Require every 01-13 row to cite sanitized evidence and non-claims; require actual human disposition before status promotion; require new review path without historical overwrite; require archive catalogue/current replacements; require no active links to moved paths; and require runbooks 20/21 to remain stop notices.

- [ ] **Step 2: Run RED**

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path @('.github/cli/tests/DocumentationLinks.Tests.ps1','.github/cli/tests/DocumentationMetadata.Tests.ps1','.github/cli/tests/DocumentationNavigation.Tests.ps1','infra/tests/pester/RunbookDocumentation.Tests.ps1') -Output Detailed"
```

Expected: **FAIL** because legacy routing/archive and final review disposition are not complete.

- [ ] **Step 3: HARD STOP, obtain acceptance, then replace/archive**

> **HARD STOP — STATUS AND ARCHIVE CHANGES.** If any `T1-E2E-01` through `13` is not `Pass`, or the human reviewer has not explicitly accepted the sanitized review, leave the review `Draft`, move nothing, change no legacy status, and stop.

After explicit acceptance, mark only supported review/status claims, record `T1-E2E-14`, rewrite the three current runbooks and related guidance, create the archive catalogue, move the five legacy documents with repaired metadata/references, update all owning catalogues, and retain 20/21 as stop notices. Use Git history as change log; add no in-document history.

- [ ] **Step 4: Run GREEN and final verification**

```powershell
$ErrorActionPreference = 'Stop'
Import-Module Pester -RequiredVersion 5.7.1 -Force
$result = Invoke-Pester -Path @('.github/cli/tests','infra/tests/pester','hr/tests/pester') -Output Detailed -PassThru
if ($result.FailedCount -gt 0) { throw "$($result.FailedCount) test(s) failed." }
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .github/cli/verify-repository-safety.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .github/cli/verify-repository-setup.ps1
Get-ChildItem infra/src/bicep -Filter *.bicep -File -Recurse | ForEach-Object {
  az bicep build --file $_.FullName --stdout | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "Bicep build failed: $($_.FullName)" }
}
git diff --check
git diff --exit-code -- .github/workflows
git status --short
```

Expected: all tests/metadata/links/navigation/safety/setup/Bicep checks **PASS**, catalogues are complete, old paths have no maintained inbound links, 20/21 remain stops, and only sanitized evidence is committed.

- [ ] **Step 5: Perform final focused review**

Review all four approved specs and six plans against the final tree. Confirm no approval was invented, review metadata uses actual date, all 01-13 evidence is current, `T1-E2E-14` has explicit human disposition, historical reviews remain unchanged, archive successor links resolve, no secret/private value/raw evidence entered Git, and no Tenant 2 or TEST/PROD mutation claim exists.

- [ ] **Step 6: Commit**

```powershell
git add docs infra/docs infra/README.md
git commit -m "docs(runbooks): accept Tenant 1 end-to-end lifecycle" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

## Completion Gate

This plan is complete only after all 14 specification controls pass in one traceable lifecycle, every mutating child has its own Plan/`approvals.json`/WhatIf/Apply/read-back/canonical stage result, coordinate-only umbrella Verify accepts the exact selected ordered set with literal `Passed` dependencies, the human reviewer explicitly accepts the new sanitized review, current-main validation remains green, a fresh laptop continues safely, local `TenantReplica` validation passes, historical reviews remain intact, archive/navigation tests pass, and no unapproved live operation, TEST/PROD mutation, GitHub Actions delivery expansion, remote publication, or Tenant 2 action occurred.
