# Tenant Lifecycle Coordinate-Only Correction Implementation Plan

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-10-03 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Draft |
| **Scope** | Corrective implementation on the existing blocked Tenant 1 lifecycle-core branch: coordinate-only umbrella authority, canonical child stage results, exact verification, and stage-only projection |
| **References** | [Approved Tenant Lifecycle Coordinate-Only Simplification Design](../specs/2026-10-03-tenant-lifecycle-coordinate-only-simplification-design.md), [Tenant Lifecycle Core Plan](2026-10-02-tenant-lifecycle-core-implementation.md), [Approved Tenant 1 Runbook End-to-End Design](../specs/2026-10-02-tenant-1-runbook-end-to-end-design.md), [Implementation Plan Catalogue](README.md) |

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Correct the existing `feat/tenant-lifecycle-core` implementation in place so `Invoke-TenantLifecycle.ps1` can coordinate non-mutating Assess/Plan work and verify exact child-owned stage results, but can never approve, execute, correlate, or project provider mutations.

**Architecture:** Preserve the existing 15-commit Plan 1 history and retained child-library helpers, then remove mutation authority only from the umbrella execution path. Independently runnable children keep manifest, approval, WhatIf/Apply, `ShouldProcess`, provider correlation, state adoption, and read-back; the umbrella accepts immutable canonical stage results, evaluates literal `Passed` dependencies, validates child summary bytes/digests without interpreting provider details, and emits a strict stage-level projection.

**Tech Stack:** Windows PowerShell 5.1 (authoritative), Pester 5.7.1, reviewed PowerShell 7 compatibility, JSON Schema draft 2020-12, canonical UTF-8 JSON without BOM, SHA-256, Git, and the existing `Caldova.HrFrontier.Bootstrap` module.

**Spec:** [`docs/specs/2026-10-03-tenant-lifecycle-coordinate-only-simplification-design.md`](../specs/2026-10-03-tenant-lifecycle-coordinate-only-simplification-design.md)

## Global Constraints

- Execute only on the existing `feat/tenant-lifecycle-core` branch and its existing worktree after synchronizing the committed design and plan amendments from `docs/tenant1-runbook-end-to-end-design`. Do not create a replacement branch, rebase, amend, squash, reset, or rewrite any of the 15 existing implementation commits.
- Before editing source, record the original 15 commit IDs in oldest-first order. After every task, prove each remains an ancestor of `HEAD` with the same object ID.
- The correction adds reviewable commits after the existing history. Each task ends with a focused commit and trailer `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>`.
- Do not authenticate, contact GitHub/Entra/Azure/Azure DevOps/PAC/Power Platform, queue a pipeline, import a solution, run Bicep deployment/WhatIf against Azure, mutate Tenant 1, or perform any live/provider operation. Every runner/invoker in tests is synthetic and injected.
- Windows PowerShell 5.1 with Pester 5.7.1 is authoritative. Run the focused lifecycle suites under the reviewed PowerShell 7 host after Windows PowerShell passes. Do not introduce PowerShell 7-only syntax into authoritative code.
- The public umbrella signature is exactly:

```powershell
[CmdletBinding()]
param(
 [Parameter(Mandatory)][guid]$RunId,
 [Parameter(Mandatory)][string]$EvidenceRoot,
 [Parameter(Mandatory)][string]$RepositoryRoot,
 [Parameter(Mandatory)][ValidatePattern('^[0-9a-fA-F]{40}$')][string]$ExpectedSourceCommit,
 [Parameter(Mandatory)][ValidateSet('tenant1')][string]$PublicTenantKey,
 [Parameter(Mandatory)][string]$TenantConfigurationPath,
 [Parameter(Mandatory)][string]$TenantStatePath,
 [Parameter(Mandatory)][ValidateSet('Workstation','PrivateBoundary','Foundation','DevDelivery','ReadBack','Acceptance','TenantReplica')][string[]]$Stages,
 [ValidateSet('Assess','Plan','Verify')][string]$Mode = 'Assess',
 [Parameter(DontShow)][scriptblock]$SubsystemInvoker,
 [datetime]$NowUtc = [datetime]::UtcNow
)
```

- Do not add aliases or alternate parameter sets. Remove `Apply`, `ExecutionManifestPath`, `ApprovedDigest`, `BindingObserver`, `CurrentBindingProvider`, `SupportsShouldProcess`, umbrella approval loading, umbrella provider action/result evidence, and umbrella resource-level correlation.
- `SubsystemInvoker` is required at runtime only for `Assess` and `Plan`. It receives exactly `Stage`, `Mode`, and a newly built closed non-secret `ControlRecord`. `Verify` rejects a supplied invoker and never invokes a child.
- The closed `ControlRecord` fields are exactly `schemaVersion`, `runId`, `sourceCommit`, `publicTenantKey`, `intentDigest`, `stateDigest`, `selectedStages`, `prerequisiteResults`, and `evidenceRunRelativePath`. Each `prerequisiteResults` item contains only `stage`, `status`, `classification`, `phaseManifestDigest`, `phaseSummaryDigest`, `intentDigest`, and `stateDigest`.
- Add closed JSON Schema draft 2020-12 contract `tenant-lifecycle-stage-result.schema.json` with exactly `schemaVersion`, `runId`, `stage`, `sourceCommit`, `publicTenantKey`, `intentDigest`, `stateDigest`, `phaseManifestDigest`, `phaseSummaryDigest`, `status`, `classification`, `evidenceRelativePath`, and `completedAtUtc`.
- `status` is exactly `Passed`, `Failed`, `Blocked`, `Refused`, or `Manual`. `classification` is exactly `NoChange`, `Changed`, `Manual`, `Blocked`, or `Refused`. Allowed pairs are `Passed/NoChange`, `Passed/Changed`, `Failed/NoChange`, `Failed/Changed`, `Blocked/Blocked`, `Refused/Refused`, and `Manual/Manual`.
- A stage result is canonical UTF-8 without BOM, one trailing LF, immutable, a regular non-reparse file, and contained at `<run>/stage-results/<stage>.json`. Use ordinal stage and filename comparison; case-only drift is invalid.
- Verify requires the exact selected ordered stage-result set with no missing, extra, duplicate, case-drifted, stale, tampered, foreign, reordered, noncanonical, noncontained, or reparse entry.
- Verify correlates exact run ID, source commit, public tenant key, intent digest, state digest chain, stage token, phase manifest digest, phase summary digest, and child evidence path. It validates the contained canonical child summary file and computes `phaseSummaryDigest` over its exact bytes.
- Verify does not parse provider-specific IDs, URLs, action IDs, actions, payloads, or read-back from a child summary. A future shared child-summary schema requires a separately reviewed contract before the umbrella can interpret additional fields.
- Dependency success is literal stage-result status `Passed`. `Failed`, `Manual`, `Blocked`, and `Refused` always block dependents and final acceptance regardless of classification or otherwise valid evidence.
- The umbrella summary/projection contains only root correlation, ordered stage entries with `stage`, `status`, `classification`, `phaseManifestDigest`, `phaseSummaryDigest`, `sourceCommit`, `intentDigest`, and `stateDigest`, plus the three fixed nonclaims from the Approved design. It contains no provider stable IDs, URLs, role IDs, action IDs, action payloads, or raw provider read-back.
- Keep state private-path validation, child-owned Create adoption, immutable stable IDs, and all shared manifest/approval/action/state/read-back/evidence helpers available to child runbooks. Removal from the umbrella path is not deletion from the shared library.
- No historical commit or retained shared-helper file is deleted. Delete only dead umbrella code branches, old umbrella parameters, old projection allowlist arguments, umbrella-only provider/resource correlation logic, and tests/fixture properties that assert those retired interfaces.
- Preserve the initial stop guards and bytes of `infra/src/scripts/runbooks/Get-CloudFoundationPlan.ps1` and `infra/src/scripts/runbooks/Invoke-CloudFoundation.ps1`.
- Fixtures contain only synthetic IDs and `example.invalid` URLs. No real identifier, URL, tenant value, private path, credential, token, customer data, or HR data enters source or test output.
- The branch remains blocked and nonmergeable until every task is reviewed, all final verification is fresh and green, and a final broad review covers the complete branch rather than only the corrective commits.

## File and Interface Map

| Path | Corrective responsibility |
|---|---|
| `infra/src/config/schemas/tenant-lifecycle-stage-result.schema.json` | New closed stage-result schema and allowed outcome pairs. |
| `infra/src/scripts/runbooks/Invoke-TenantLifecycle.ps1` | Exact Assess/Plan/Verify coordinate-only public surface. |
| `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Test-TenantLifecycleContract.ps1` | Adds exact `StageResult` runtime validation. |
| `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/New-TenantLifecycleStageResult.ps1` | Builds the closed child-owned terminal result object. |
| `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Write-TenantLifecycleStageResult.ps1` | Writes one immutable canonical result at `stage-results/<stage>.json`. |
| `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Test-TenantLifecycleStageResultSet.ps1` | Reads and validates the exact selected ordered result/manifest/summary set. |
| `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Resolve-TenantLifecycleGraph.ps1` | Evaluates umbrella dependencies from literal stage-result `Passed` status while preserving child action-helper availability. |
| `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/ConvertTo-TenantLifecycleAcceptanceProjection.ps1` | Produces the strict stage-only umbrella summary/projection. |
| `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/New-TenantLifecycleControlRecord.ps1` | Reconstructs a closed non-secret Assess/Plan dispatch record. |
| `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/Read-TenantLifecycleCanonicalJsonFile.ps1` | Enforces containment, regular/non-reparse type, strict UTF-8/LF/canonical bytes, duplicate-key rejection, and exact byte digest. |
| `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/Test-TenantLifecycleDisclosure.ps1` | Changes from provider allowlisting to a closed stage-projection assertion. |
| `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Caldova.HrFrontier.Bootstrap.psd1` | Exports the reviewed public stage-result helpers. |
| `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Caldova.HrFrontier.Bootstrap.psm1` | Loads the reviewed public/private helper files. |
| `infra/tests/pester/TenantLifecycleContracts.Tests.ps1` | Schema, canonical bytes, immutable writer, and outcome-pair coverage. |
| `infra/tests/pester/TenantLifecycleOrchestration.Tests.ps1` | Assess/Plan/Verify, drift, exact set, dependency, summary, and adversarial coverage. |
| `infra/tests/pester/RunbookContracts.Tests.ps1` | Exact public parameter and mode contract. |
| `infra/tests/pester/RunbookStaticSafety.Tests.ps1` | Absence of old parameters, provider commands, current-binding, target correlation, and mutation authority. |
| `infra/tests/pester/RunbookDocumentation.Tests.ps1` | Corrected plan/spec/runbook wording and exact operator boundary. |
| `infra/tests/fixtures/runbooks/tenant-lifecycle.synthetic.json` | Synthetic coordinate-only run and stage-result fixtures. |
| `infra/docs/runbooks/README.md` | Routes the coordinate-only umbrella and child ownership. |
| `infra/docs/runbooks/01-developer-workstation.md` | States child-owned workstation/private lifecycle and stage results. |
| `infra/docs/runbooks/03-customer-handover.md` | States child-owned replica lifecycle and stage result. |
| `infra/docs/README.md` and `infra/README.md` | Correct authority/navigation without live-execution claims. |

No whole source or documentation file is deleted by this correction. The exact retired interfaces are the old umbrella parameter declarations and aliases, `Mode Invoke`, umbrella `ShouldProcess`, umbrella manifest/approval loading, umbrella current-binding callbacks, umbrella action/provider/result correlation, `AllowedStableIds`, `AllowedUrlHosts`, and umbrella `targetStableId` matching. Shared child functions and their files remain.

---

### Task 1: Contract Amendment, Stage-Result Schema, and Static RED/GREEN Safety

**Files:**
- Create: `infra/src/config/schemas/tenant-lifecycle-stage-result.schema.json`
- Modify: `infra/src/scripts/runbooks/Invoke-TenantLifecycle.ps1`
- Modify: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Test-TenantLifecycleContract.ps1`
- Modify: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Caldova.HrFrontier.Bootstrap.psd1`
- Modify: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Caldova.HrFrontier.Bootstrap.psm1`
- Modify: `infra/tests/pester/TenantLifecycleContracts.Tests.ps1`
- Modify: `infra/tests/pester/RunbookContracts.Tests.ps1`
- Modify: `infra/tests/pester/RunbookStaticSafety.Tests.ps1`
- Modify: `infra/tests/pester/RunbookDocumentation.Tests.ps1`
- Modify: `infra/tests/fixtures/runbooks/tenant-lifecycle.synthetic.json`

**Interfaces:**
- Consumes: the committed Approved coordinate-only specification and plan amendments; existing canonical JSON/digest helpers.
- Produces: the exact public umbrella parameter block in Global Constraints; `Test-TenantLifecycleContract -Kind StageResult -InputObject <object>`; schema version `1.0`.
- Preserves: all existing `Assessment`, `ExecutionManifest`, `Approval`, `ActionEvidence`, `State`, `ReadBack`, and `Summary` validator kinds for direct child use.

- [ ] **Step 1: Locate and synchronize the existing blocked branch without rewriting history**

Run from the repository containing both branches:

```powershell
$ErrorActionPreference = 'Stop'
$branchRef = 'refs/heads/feat/tenant-lifecycle-core'
$records = New-Object System.Collections.Generic.List[object]
$path = $null
foreach ($line in @(git worktree list --porcelain)) {
    if ($line -like 'worktree *') {
        $path = $line.Substring(9)
    }
    elseif ($line -eq "branch $branchRef") {
        $records.Add([pscustomobject]@{ Path = $path; Branch = $branchRef })
    }
}
if ($records.Count -ne 1) {
    throw "Expected exactly one existing worktree for $branchRef; found $($records.Count)."
}
$LifecycleRoot = $records[0].Path
$status = @(git -C $LifecycleRoot status --short)
if ($LASTEXITCODE -ne 0 -or $status.Count -ne 0) {
    throw 'The existing lifecycle-core worktree must be clean.'
}
$MergeBase = (git -C $LifecycleRoot merge-base main HEAD).Trim()
$OriginalCommits = @(git -C $LifecycleRoot rev-list --reverse "$MergeBase..HEAD")
if ($OriginalCommits.Count -ne 15) {
    throw "Expected 15 existing lifecycle-core commits; found $($OriginalCommits.Count)."
}
$DocsBranch = 'docs/tenant1-runbook-end-to-end-design'
$DocsSyncBase = (git merge-base $branchRef $DocsBranch).Trim()
$DocsCommits = @(git rev-list --reverse "$DocsSyncBase..$DocsBranch" -- `
  docs/specs/2026-10-03-tenant-lifecycle-coordinate-only-simplification-design.md `
  docs/specs/README.md `
  docs/plans/README.md `
  docs/plans/2026-10-02-tenant-lifecycle-core-implementation.md `
  docs/plans/2026-10-02-developer-workstation-runbook-refactor-implementation.md `
  docs/plans/2026-10-02-cloud-service-foundation-core-implementation.md `
  docs/plans/2026-10-02-power-platform-dev-delivery-implementation.md `
  docs/plans/2026-10-02-tenant-replica-handover-implementation.md `
  docs/plans/2026-10-02-tenant-1-end-to-end-acceptance-implementation.md `
  docs/plans/2026-10-03-tenant-lifecycle-coordinate-only-correction-implementation.md)
if ($DocsCommits.Count -eq 0) {
    throw 'No committed coordinate-only design/plan amendment commits were found to synchronize.'
}
git -C $LifecycleRoot cherry-pick $DocsCommits
if ($LASTEXITCODE -ne 0) {
    throw 'Documentation amendment synchronization failed; abort the cherry-pick and review branch ancestry instead of rewriting history.'
}
foreach ($commit in $OriginalCommits) {
    git -C $LifecycleRoot merge-base --is-ancestor $commit HEAD
    if ($LASTEXITCODE -ne 0) { throw "Original commit is no longer an ancestor: $commit" }
}
```

Expected: one existing clean worktree is found, exactly 15 original commits are recorded, every committed coordinate-only design/catalogue/plan amendment commit is added after them in original order, and all 15 object IDs remain ancestors. Before cherry-picking, inspect `git show --stat --oneline $DocsCommits`; stop if any selected commit contains source, workflow, infrastructure, generated evidence, or unrelated documentation changes.

- [ ] **Step 2: Write the failing schema, signature, and static-safety tests**

Add exact assertions that:

1. the schema declares draft 2020-12, `type: object`, the 13 required properties in the order listed in Global Constraints, and `additionalProperties: false`;
2. `schemaVersion` is `1.0`, `publicTenantKey` is `tenant1`, source commit is 40 hex, digests are 64 lowercase hex, and `evidenceRelativePath` is exactly `phases/<same-stage>/summary.json`;
3. all seven allowed status/classification pairs pass and every other cross-pair fails;
4. the script AST reports exactly the 11 parameter names and order from the required signature, exactly modes `Assess`, `Plan`, `Verify`, and no `SupportsShouldProcess`;
5. calls using `-Apply`, `-ExecutionManifestPath`, `-ApprovedDigest`, `-BindingObserver`, or `-CurrentBindingProvider` fail parameter binding;
6. the umbrella source contains no old parameter declaration, approval-file load, current-binding callback, `targetStableId` resource correlation, provider action/result loop, or `ShouldProcess`;
7. the Approved spec, this corrective plan, and amended Plan 1 are present and state that Plan 1 is incomplete until correction passes.

Use fixture cases with `stage: Foundation`, synthetic digests, `example.invalid` only where a prohibited-value test needs a URL, and no real identifiers.

- [ ] **Step 3: Run RED**

Run:

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path @('infra/tests/pester/TenantLifecycleContracts.Tests.ps1','infra/tests/pester/RunbookContracts.Tests.ps1','infra/tests/pester/RunbookStaticSafety.Tests.ps1','infra/tests/pester/RunbookDocumentation.Tests.ps1') -FullNameFilter '*stage result schema*','*coordinate-only signature*','*retired umbrella authority*','*coordinate-only plan authority*' -Output Detailed"
```

Expected: **FAIL** because the stage-result schema and validator kind are absent, the umbrella still exposes retired mutation/current-binding parameters or modes, and static safety still recognizes the old projection/orchestration path.

- [ ] **Step 4: Implement the minimum contract amendment**

Create the schema with this exact shape:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "tenant-lifecycle-stage-result.schema.json",
  "title": "Tenant lifecycle stage result",
  "type": "object",
  "additionalProperties": false,
  "required": [
    "schemaVersion",
    "runId",
    "stage",
    "sourceCommit",
    "publicTenantKey",
    "intentDigest",
    "stateDigest",
    "phaseManifestDigest",
    "phaseSummaryDigest",
    "status",
    "classification",
    "evidenceRelativePath",
    "completedAtUtc"
  ],
  "properties": {
    "schemaVersion": { "const": "1.0" },
    "runId": { "type": "string", "format": "uuid" },
    "stage": {
      "enum": ["Workstation", "PrivateBoundary", "Foundation", "DevDelivery", "ReadBack", "Acceptance", "TenantReplica"]
    },
    "sourceCommit": { "type": "string", "pattern": "^[0-9a-fA-F]{40}$" },
    "publicTenantKey": { "const": "tenant1" },
    "intentDigest": { "type": "string", "pattern": "^[0-9a-f]{64}$" },
    "stateDigest": { "type": "string", "pattern": "^[0-9a-f]{64}$" },
    "phaseManifestDigest": { "type": "string", "pattern": "^[0-9a-f]{64}$" },
    "phaseSummaryDigest": { "type": "string", "pattern": "^[0-9a-f]{64}$" },
    "status": { "enum": ["Passed", "Failed", "Blocked", "Refused", "Manual"] },
    "classification": { "enum": ["NoChange", "Changed", "Manual", "Blocked", "Refused"] },
    "evidenceRelativePath": {
      "type": "string",
      "pattern": "^phases/(Workstation|PrivateBoundary|Foundation|DevDelivery|ReadBack|Acceptance|TenantReplica)/summary[.]json$"
    },
    "completedAtUtc": { "type": "string", "format": "date-time" }
  },
  "oneOf": [
    { "properties": { "status": { "const": "Passed" }, "classification": { "enum": ["NoChange", "Changed"] } } },
    { "properties": { "status": { "const": "Failed" }, "classification": { "enum": ["NoChange", "Changed"] } } },
    { "properties": { "status": { "const": "Blocked" }, "classification": { "const": "Blocked" } } },
    { "properties": { "status": { "const": "Refused" }, "classification": { "const": "Refused" } } },
    { "properties": { "status": { "const": "Manual" }, "classification": { "const": "Manual" } } }
  ]
}
```

Extend the runtime validator with exact allowed/required property arrays, ordinal stage/path correlation, the seven outcome pairs, and UTC normalization `yyyy-MM-dd'T'HH:mm:ss.fff'Z'`. Replace the umbrella parameter block exactly as specified. Remove retired variables and their code branches rather than retaining aliases or ignored compatibility parameters. Preserve child validator kinds and helper exports unchanged.

- [ ] **Step 5: Run GREEN**

Run the RED command again, then run the contract suite under PowerShell 7:

```powershell
pwsh.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path 'infra/tests/pester/TenantLifecycleContracts.Tests.ps1' -FullNameFilter '*stage result schema*' -Output Detailed"
```

Expected: both commands **PASS**. The AST parameter sequence is exact; every retired parameter is unbindable; no retained child validator/helper test regresses.

- [ ] **Step 6: Perform focused review**

Review only the schema, exact signature, validator, fixture, module load/export lists, and four focused test files. Confirm there is no alias, alternate parameter set, `Mode Invoke`, `SupportsShouldProcess`, broad catch, permissive additional property, upper-case digest acceptance, real identifier, or child-helper deletion.

- [ ] **Step 7: Commit**

```powershell
git add infra/src/config/schemas/tenant-lifecycle-stage-result.schema.json infra/src/scripts/runbooks/Invoke-TenantLifecycle.ps1 infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap infra/tests/pester/TenantLifecycleContracts.Tests.ps1 infra/tests/pester/RunbookContracts.Tests.ps1 infra/tests/pester/RunbookStaticSafety.Tests.ps1 infra/tests/pester/RunbookDocumentation.Tests.ps1 infra/tests/fixtures/runbooks/tenant-lifecycle.synthetic.json
git commit -m "fix(runbooks): amend lifecycle umbrella contracts" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 2: Coordinate-Only Assess/Plan Orchestrator and Source/Private Drift Gates

**Files:**
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/New-TenantLifecycleControlRecord.ps1`
- Modify: `infra/src/scripts/runbooks/Invoke-TenantLifecycle.ps1`
- Modify: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Caldova.HrFrontier.Bootstrap.psm1`
- Modify: `infra/tests/pester/TenantLifecycleOrchestration.Tests.ps1`
- Modify: `infra/tests/pester/RunbookStaticSafety.Tests.ps1`
- Modify: `infra/tests/fixtures/runbooks/tenant-lifecycle.synthetic.json`

**Interfaces:**
- Consumes: exact signature from Task 1, `Test-TenantLifecyclePrivateBoundary`, `Resolve-RunbookReportPath`, source-commit verification, canonical digests, and already completed prerequisite stage results.
- Produces:

```powershell
New-TenantLifecycleControlRecord `
  -RunId <guid> `
  -SourceCommit <40-hex> `
  -PublicTenantKey tenant1 `
  -IntentDigest <64-lower-hex> `
  -StateDigest <64-lower-hex> `
  -SelectedStages <string[]> `
  -PrerequisiteResults <object[]> `
  -EvidenceRunRelativePath <string>
```

- Invoker call contract:

```powershell
Invoke-TenantLifecycleIsolatedInvoker `
  -Invoker $SubsystemInvoker `
  -Stage $stage `
  -Mode $Mode `
  -ControlRecord $freshControlRecord `
  -ExternalRunRoot $trustedEvidenceRoot
```

- The adapter runs the scriptblock in a fresh no-profile PowerShell process, passes only serialized/deep-cloned `Stage`, `Mode`, and `ControlRecord`, clears inherited environment values except the Windows process bootstrap variables, and uses the external evidence root as the working directory. `SubsystemInvoker` remains a controlled dispatch seam, not a security boundary.
- The invoker return value is discarded. Assess validates `phases/<stage>/assessment.json` and requires ordinal-exact `assessment.kind == <stage>`. Plan validates `phases/<stage>/execution-manifest.json` and requires exactly one stage action with ordinal-exact `actions[0].id == <stage>`. Neither mode writes or accepts a terminal stage result.

- [ ] **Step 1: Write the failing Assess/Plan orchestration tests**

Add exact cases for:

- missing invoker in Assess and Plan;
- invoker supplied in Verify;
- selected stages empty, duplicate, wrong case for every stage, unknown, or incompatible with the accepted prerequisite graph;
- wrong-case Assess, Plan, or Verify mode before invoker and filesystem access;
- stage and mode arguments exact and control record properties exactly equal to the nine-field allowlist;
- control record excludes absolute private paths, private values, credentials, tokens, approval digests, provider contexts, stable IDs, URLs, actions, payloads, and raw read-back;
- Assess invokes only Assess and validates only the canonical assessment path;
- Plan invokes only Plan and validates only the canonical child execution-manifest path;
- cross-stage assessment-kind and manifest-action substitutions;
- adversarial `Set-Variable` attempts against every authoritative coordinator name, proving the isolated process cannot mutate coordinator state;
- source commit changes before invocation, during invocation, or after artifact validation;
- intent or state digest changes before invocation, during invocation, or after artifact validation;
- invoker returns provider IDs/actions/payloads or mutates its return object after return;
- invoker attempts to claim `Passed` without a terminal child phase;
- first invalid prerequisite stops later dispatch.

Assert zero provider runner calls in every case.

- [ ] **Step 2: Run RED**

Run:

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path @('infra/tests/pester/TenantLifecycleOrchestration.Tests.ps1','infra/tests/pester/RunbookStaticSafety.Tests.ps1') -FullNameFilter '*coordinate-only Assess*','*coordinate-only Plan*','*control record*','*source and private drift*' -Output Detailed"
```

Expected: **FAIL** because the old orchestrator trusts invoker results, carries retired approval/provider data, lacks the exact control-record allowlist, or does not re-run every source/private drift gate around dispatch.

- [ ] **Step 3: Implement the minimum non-mutating dispatch**

Implement the orchestrator in this order:

1. resolve one contained run root using `Resolve-RunbookReportPath`;
2. reject non-ordinal Mode and every empty/duplicate/case-drifted/unknown stage list immediately after parameter binding and before invoker or filesystem checks;
3. verify clean exact source commit without modifying the worktree;
4. validate ignored/untracked contained private intent/state paths and compute canonical intent/state digests;
5. load only already completed prerequisite stage results needed for dispatch;
6. create a new closed control record for the current stage;
7. invoke exactly once in the same Assess or Plan mode through the isolated serialized adapter;
8. assign the invocation result to `$null`;
9. reconstruct source/private/stage/control values from trusted inputs rather than from dynamic-scope locals or returned objects;
10. rerun source/private digests and reject any drift;
11. validate the expected canonical assessment or manifest artifact from disk, including ordinal stage binding through assessment `kind` or the manifest's single action `id`; and
12. stop on the first invalid prerequisite or artifact.

Do not invoke `ShouldProcess`, load `approvals.json`, read an umbrella manifest, write action evidence, update state, correlate `targetStableId`, or create a stage result. Error IDs must distinguish `TenantLifecycle.SubsystemInvoker.Required`, `TenantLifecycle.SubsystemInvoker.NotAllowed`, `TenantLifecycle.Source.Drift`, `TenantLifecycle.Intent.Drift`, `TenantLifecycle.State.Drift`, and `TenantLifecycle.ChildArtifact.Invalid`.

- [ ] **Step 4: Run GREEN**

Run the RED command again.

Expected: **PASS**. Assess/Plan dispatch only the selected non-mutating mode; return objects have no authority; pre/during/post source or private drift fails closed; no child/provider call occurs in Verify.

- [ ] **Step 5: Perform focused review**

Trace every value passed to the invoker. Confirm the record is newly allocated per stage, has exactly nine root fields, contains only provider-neutral prerequisite projections, and is rebuilt after each invocation. Confirm only the serialized three-argument contract and the external working directory cross the fresh-process boundary, no closure/module/environment value is inherited, the adapter is documented as state isolation rather than a security boundary, and no mutable return value affects acceptance.

- [ ] **Step 6: Commit**

```powershell
git add infra/src/scripts/runbooks/Invoke-TenantLifecycle.ps1 infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/New-TenantLifecycleControlRecord.ps1 infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Caldova.HrFrontier.Bootstrap.psm1 infra/tests/pester/TenantLifecycleOrchestration.Tests.ps1 infra/tests/pester/RunbookStaticSafety.Tests.ps1 infra/tests/fixtures/runbooks/tenant-lifecycle.synthetic.json
git commit -m "fix(runbooks): make lifecycle dispatch coordinate only" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 3: Verify Mode, Canonical Stage Results, Child Summary Digests, and Literal Dependency Success

**Files:**
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/New-TenantLifecycleStageResult.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Write-TenantLifecycleStageResult.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Test-TenantLifecycleStageResultSet.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/Read-TenantLifecycleCanonicalJsonFile.ps1`
- Modify: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Write-TenantLifecycleEvidence.ps1`
- Modify: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Resolve-TenantLifecycleGraph.ps1`
- Modify: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Caldova.HrFrontier.Bootstrap.psd1`
- Modify: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Caldova.HrFrontier.Bootstrap.psm1`
- Modify: `infra/src/scripts/runbooks/Invoke-TenantLifecycle.ps1`
- Modify: `infra/tests/pester/TenantLifecycleContracts.Tests.ps1`
- Modify: `infra/tests/pester/TenantLifecycleOrchestration.Tests.ps1`
- Modify: `infra/tests/fixtures/runbooks/tenant-lifecycle.synthetic.json`

**Interfaces:**
- Produces:

```powershell
New-TenantLifecycleStageResult `
  -RunId <guid> -Stage <closed-stage> -SourceCommit <40-hex> `
  -PublicTenantKey tenant1 -IntentDigest <64-lower-hex> `
  -StateDigest <64-lower-hex> -PhaseManifestDigest <64-lower-hex> `
  -PhaseSummaryDigest <64-lower-hex> `
  -Status <Passed|Failed|Blocked|Refused|Manual> `
  -Classification <NoChange|Changed|Manual|Blocked|Refused> `
  -EvidenceRelativePath <phases/stage/summary.json> `
  -CompletedAtUtc <datetime>

Write-TenantLifecycleStageResult `
  -RunDirectory <absolute> -StageResult <closed-object>

Test-TenantLifecycleStageResultSet `
  -RunDirectory <absolute> -RunId <guid> -Stages <closed-stage[]> `
  -SourceCommit <40-hex> -PublicTenantKey tenant1 `
  -IntentDigest <64-lower-hex> -CurrentStateDigest <64-lower-hex>

Read-TenantLifecycleCanonicalJsonFile `
  -Path <absolute> -ContainmentRoot <absolute> `
  -ExpectedRelativePath <ordinal-relative> [-ExpectedDigest <64-lower-hex>]
```

- `Test-TenantLifecycleStageResultSet` returns an ordered array with only the 13 closed result fields. It never returns parsed child-summary provider properties.
- `Resolve-TenantLifecycleGraph -Nodes <object[]> -ObservedOutcomes <object[]>` retains its existing signature. Umbrella nodes have exactly `id`, `kind`, `prerequisiteIds`, `requiredOutcome`, `inputDigest`, and `stage`, with `kind: Stage` and `requiredOutcome: Passed`; umbrella observed outcomes are closed stage-result objects. Existing child action nodes remain supported outside the umbrella path.

- [ ] **Step 1: Write the failing canonical evidence and Verify adversarial tests**

Create table-driven tests for:

- valid canonical UTF-8 without BOM, exactly one LF, lower-case digest, immutable first write, and same-object second write refusal;
- missing result, extra entry, duplicate selected stage, duplicate JSON property, alternate/case-drifted filename, reordered selected stages, stale source/intent/state, tampered bytes, foreign run, foreign tenant, foreign stage, and unsupported outcome pair;
- BOM, CRLF, zero LF, two trailing LFs, noncanonical key order, noncanonical whitespace, upper-case digest, malformed JSON, non-object root, additional property, and path traversal;
- result file, `stage-results` directory, manifest, or child summary implemented as symlink/junction/reparse point;
- result or summary outside the run root, absolute `evidenceRelativePath`, wrong summary stage segment, and manifest/summary digest mismatch;
- child phase summary containing synthetic provider IDs, URLs, action IDs, actions, payloads, and read-back: Verify must digest the canonical bytes but must neither copy nor interpret those properties;
- supplied Verify invoker with a counter that must remain zero;
- dependency results `Failed/NoChange`, `Failed/Changed`, `Manual/Manual`, `Blocked/Blocked`, and `Refused/Refused`, each blocking its dependents and final Verify;
- `Passed/NoChange` and `Passed/Changed` satisfying dependencies;
- changed child state forming the accepted ordered manifest-input/result-output digest chain, and unexplained or final-current-state mismatch failing closed.

On Windows, create reparse cases only when the test process can create the required link; otherwise assert the production reparse detector against an injected filesystem probe so the safety case is never silently skipped.

- [ ] **Step 2: Run RED**

Run:

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path @('infra/tests/pester/TenantLifecycleContracts.Tests.ps1','infra/tests/pester/TenantLifecycleOrchestration.Tests.ps1') -FullNameFilter '*canonical stage result*','*exact stage result set*','*phase summary digest*','*Verify never invokes*','*literal Passed dependency*','*stage state digest chain*' -Output Detailed"
```

Expected: **FAIL** because the immutable stage-result writer, strict canonical reader, exact set verifier, byte-digest child-summary validation, and literal `Passed` graph behavior do not exist.

- [ ] **Step 3: Implement canonical read/write and exact Verify**

Implement `Read-TenantLifecycleCanonicalJsonFile` to:

1. normalize and ordinal-compare the expected relative path;
2. prove every existing path segment and the file are contained and not reparse points;
3. require one regular file and reject directories/devices/links;
4. read raw bytes once and reject UTF-8 BOM, invalid UTF-8, CR, missing final LF, or more than one trailing LF;
5. tokenize JSON strings/object boundaries before deserialization and reject duplicate property names ordinally at every object depth;
6. deserialize, run the correct closed runtime contract where one exists, canonicalize with `Write-CanonicalJson` semantics in memory, and require byte-for-byte equality;
7. compute lowercase SHA-256 over the original exact file bytes; and
8. compare `ExpectedDigest` when supplied.

Implement `Write-TenantLifecycleStageResult` through the existing same-directory atomic writer. Create `stages` only below the selected run, reject reparse points before and after creation, write once, flush/close, atomically promote, and never overwrite an existing result even when bytes match.

Implement Verify in this order:

1. reject a non-null `SubsystemInvoker`;
2. re-run exact source and private-path/digest gates;
3. enumerate every direct entry under `<run>/stage-results` and require an ordinal one-to-one filename match with `-Stages`;
4. read results in caller-supplied order and verify exact run/source/tenant/intent/stage values;
5. read fixed `phases/<stage>/execution-manifest.json`, validate only its shared run/source/tenant/intent/input-state/selected-stage/prerequisite envelope, compute its exact canonical byte digest, and match `phaseManifestDigest` without enumerating provider contexts, targets, or actions;
6. resolve only the exact `evidenceRelativePath`, require `phases/<stage>/summary.json`, compute exact canonical byte digest, and match `phaseSummaryDigest`;
7. validate the ordered manifest-input/result-output state digest chain and require the final result state digest to equal the current private state digest;
8. evaluate the retained closed prerequisite graph with literal `Passed` success; and
9. fail before summary generation on any invalid or non-`Passed` selected/dependency result.

Do not normalize invalid evidence, search alternate paths, infer a result from nearby files, parse provider-specific child summary properties, or repair state.

- [ ] **Step 4: Run GREEN**

Run the RED command again, then run the same focused suites under PowerShell 7:

```powershell
pwsh.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path @('infra/tests/pester/TenantLifecycleContracts.Tests.ps1','infra/tests/pester/TenantLifecycleOrchestration.Tests.ps1') -FullNameFilter '*canonical stage result*','*exact stage result set*','*phase summary digest*','*Verify never invokes*','*literal Passed dependency*','*stage state digest chain*' -Output Detailed"
```

Expected: both hosts **PASS** every canonical, stale/tampered/foreign, missing/extra/duplicate/case, summary path/digest/reparse, no-invoker, state-chain, and non-`Passed` dependency case.

- [ ] **Step 5: Perform focused review**

Review byte handling, path containment, reparse checks, duplicate-key detection, immutable writes, state-chain logic, and graph outcomes. Confirm that child summaries are treated as canonical opaque JSON bytes after path/digest validation and no provider-specific identifier/action is read into the umbrella model.

- [ ] **Step 6: Commit**

```powershell
git add infra/src/scripts/runbooks/Invoke-TenantLifecycle.ps1 infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap infra/tests/pester/TenantLifecycleContracts.Tests.ps1 infra/tests/pester/TenantLifecycleOrchestration.Tests.ps1 infra/tests/fixtures/runbooks/tenant-lifecycle.synthetic.json
git commit -m "fix(runbooks): verify canonical child stage results" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 4: Stage-Only Sanitized Projection and Removal of Umbrella Provider Correlation

**Files:**
- Modify: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/ConvertTo-TenantLifecycleAcceptanceProjection.ps1`
- Modify: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/Test-TenantLifecycleDisclosure.ps1`
- Modify: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Write-TenantLifecycleEvidence.ps1`
- Modify: `infra/src/scripts/runbooks/Invoke-TenantLifecycle.ps1`
- Modify: `infra/tests/pester/TenantLifecycleContracts.Tests.ps1`
- Modify: `infra/tests/pester/TenantLifecycleOrchestration.Tests.ps1`
- Modify: `infra/tests/pester/RunbookStaticSafety.Tests.ps1`
- Modify: `infra/tests/fixtures/runbooks/tenant-lifecycle.synthetic.json`

**Interfaces:**
- Replaces the old projection signature with:

```powershell
ConvertTo-TenantLifecycleAcceptanceProjection `
  -RunId <guid> `
  -PublicTenantKey tenant1 `
  -OrderedStageResults <validated-object[]> `
  -OutputPath <absolute-contained-run-summary-path>
```

- Root projection fields are exactly `schemaVersion`, `runId`, `publicTenantKey`, `stages`, `nonClaims`, and `digest`.
- Each `stages` entry contains exactly `stage`, `status`, `classification`, `phaseManifestDigest`, `phaseSummaryDigest`, `sourceCommit`, `intentDigest`, and `stateDigest`.
- `nonClaims` contains exactly:
  1. `The umbrella did not execute a provider mutation.`
  2. `Provider approvals and read-back remain child-runbook evidence.`
  3. `This projection discloses no provider resource identity or raw provider response.`

- [ ] **Step 1: Write the failing projection and dead-path tests**

Seed validated stage results plus child summaries containing synthetic:

- tenant/subscription/application/environment/project/pipeline/object/role/resource IDs;
- `https://provider.example.invalid/path?token=synthetic`;
- provider names, action IDs, `Create`/`Update` operations, request payloads, action results, and raw read-back.

Assert:

- the projection has exactly the six root fields and eight fields per stage;
- stages preserve the exact verified order;
- the three nonclaims are byte-exact and in the stated order;
- no seeded provider value or prohibited property name appears in projection bytes or thrown messages;
- `AllowedStableIds` and `AllowedUrlHosts` are no longer bindable;
- `CurrentBindingProvider`, `BindingObserver`, `targetStableId`, action/provider/result correlation, approval loading, and old projection allowlists are absent from `Invoke-TenantLifecycle.ps1`, `ConvertTo-TenantLifecycleAcceptanceProjection.ps1`, and `Test-TenantLifecycleDisclosure.ps1`;
- those terms may still exist in retained child helper files/tests where they implement child-owned manifest, approval, state adoption, or provider read-back.

- [ ] **Step 2: Run RED**

Run:

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path @('infra/tests/pester/TenantLifecycleContracts.Tests.ps1','infra/tests/pester/TenantLifecycleOrchestration.Tests.ps1','infra/tests/pester/RunbookStaticSafety.Tests.ps1') -FullNameFilter '*stage-only projection*','*projection prohibited provider data*','*retired umbrella correlation*' -Output Detailed"
```

Expected: **FAIL** because the old projection accepts stable-ID/URL allowlists or copies provider/resource/action detail, and umbrella-only correlation code remains.

- [ ] **Step 3: Implement the strict projection and exact retirement**

Construct the projection exclusively from the validated in-memory stage results returned by Task 3. Do not read child action, read-back, pipeline, Power Platform, or raw provider files. Validate the closed projection before canonical write to `<run>/summary.json`; include the projection digest over the object with `digest` omitted, matching existing repository digest conventions.

Retire exactly:

- old projection parameters `AllowedStableIds` and `AllowedUrlHosts`;
- provider host normalization and stable-ID allowlisting in the umbrella disclosure helper;
- umbrella `CurrentBindingProvider`/`BindingObserver` calls;
- umbrella target-only `targetStableId` correlation;
- umbrella approval/manifest action iteration and action-evidence writes;
- umbrella provider action/result return processing.

Retain exactly:

- `New-TenantLifecycleExecutionManifest`, `Test-TenantLifecycleApproval`, action-evidence, state adoption, read-back, and atomic writer functions for child callers;
- their schemas and child-focused tests;
- provider-specific IDs/actions inside external child evidence.

No whole file is deleted. `Test-TenantLifecycleDisclosure.ps1` remains and is narrowed to enforce the closed stage projection. Delete only the retired parameters and code branches listed above, plus their umbrella-only test cases and fixture properties; do not delete retained child helper files, schemas, tests, or historical documentation.

- [ ] **Step 4: Run GREEN**

Run the RED command again.

Expected: **PASS**. Projection bytes contain only approved stage fields and fixed nonclaims; old projection arguments are rejected; no umbrella source contains current-binding or target-level provider correlation; retained child helper tests remain green.

- [ ] **Step 5: Perform focused review**

Compare the projection field-by-field with the Approved design. Search the three umbrella files for `tenantId`, `subscriptionId`, `applicationId`, `environmentId`, `projectId`, `pipelineId`, `roleId`, `resourceId`, `url`, `uri`, `actionId`, `payload`, `response`, `readBack`, `CurrentBindingProvider`, and `targetStableId`; each occurrence must be absent or part of a negative/prohibition assertion, never output construction or correlation. Required provider-neutral names such as `runId` and digest fields remain.

- [ ] **Step 6: Commit**

```powershell
git add infra/src/scripts/runbooks/Invoke-TenantLifecycle.ps1 infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap infra/tests/pester/TenantLifecycleContracts.Tests.ps1 infra/tests/pester/TenantLifecycleOrchestration.Tests.ps1 infra/tests/pester/RunbookStaticSafety.Tests.ps1 infra/tests/fixtures/runbooks/tenant-lifecycle.synthetic.json
git commit -m "fix(runbooks): restrict umbrella evidence to stages" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 5: Compatibility, Documentation, Plan 1 Cleanup, Whole-Branch Review, and Final Verification

**Files:**
- Modify: `infra/tests/pester/TenantLifecycleContracts.Tests.ps1`
- Modify: `infra/tests/pester/TenantLifecycleOrchestration.Tests.ps1`
- Modify: `infra/tests/pester/RunbookContracts.Tests.ps1`
- Modify: `infra/tests/pester/RunbookStaticSafety.Tests.ps1`
- Modify: `infra/tests/pester/RunbookDocumentation.Tests.ps1`
- Modify: `infra/docs/runbooks/README.md`
- Modify: `infra/docs/runbooks/01-developer-workstation.md`
- Modify: `infra/docs/runbooks/03-customer-handover.md`
- Modify: `infra/docs/README.md`
- Modify: `infra/README.md`
- Review without rewriting historical tasks: `docs/plans/2026-10-02-tenant-lifecycle-core-implementation.md`
- Review unchanged: `infra/src/scripts/runbooks/Get-CloudFoundationPlan.ps1`
- Review unchanged: `infra/src/scripts/runbooks/Invoke-CloudFoundation.ps1`

**Interfaces:**
- Consumes: Tasks 1-4 and all retained Plan 1 child helpers.
- Produces: host-compatible coordinate-only lifecycle behavior, truthful runbook/navigation text, complete final evidence, and a whole-branch review package.
- Does not change any plan status from `Draft`, claim live execution, unblock Plans 2-6, or merge the branch.

- [ ] **Step 1: Write the failing cross-host, compatibility, and documentation assertions**

Add golden tests that run equivalent synthetic results through Windows PowerShell 5.1 and the reviewed PowerShell 7 host and byte-compare:

- canonical stage-result files;
- exact summary digests;
- stage-only projection bytes;
- source/private drift error IDs;
- exact ordered dependency outcomes.

Add documentation assertions requiring:

- exact Assess/Plan/Verify signature and no Apply;
- explicit child Plan -> child `approvals.json` -> child WhatIf/Apply -> child read-back -> canonical stage result -> umbrella Verify sequence;
- `<run>/stage-results/<stage>.json`;
- Verify never invoking children;
- literal `Passed` dependency success;
- exact stage-only projection nonclaims;
- Plan 1 remaining incomplete and Plans 2-6 remaining blocked until correction merges/current-main is green;
- no live/provider execution claim.

- [ ] **Step 2: Run RED**

Run:

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path @('infra/tests/pester/TenantLifecycleContracts.Tests.ps1','infra/tests/pester/TenantLifecycleOrchestration.Tests.ps1','infra/tests/pester/RunbookContracts.Tests.ps1','infra/tests/pester/RunbookStaticSafety.Tests.ps1','infra/tests/pester/RunbookDocumentation.Tests.ps1') -FullNameFilter '*cross-host coordinate-only golden*','*coordinate-only documentation*','*Plan 1 corrective gate*' -Output Detailed"
```

Expected: **FAIL** until host normalization and all current runbook/catalogue statements use the corrected authority and operator sequence.

- [ ] **Step 3: Apply only proven compatibility and documentation corrections**

Normalize encoding, path casing comparisons, JSON depth, array ordering, native result handling, and datetime rendering only where the cross-host golden tests prove a difference. Do not fork business behavior by host.

Update the five listed infrastructure documentation files to:

- describe the umbrella as Assess/Plan/Verify only;
- route manifest/approval/WhatIf/Apply/`ShouldProcess`/read-back/state adoption to child runbooks;
- document immutable canonical stage results and stage-only projection;
- state that implementation used synthetic tests only and performed no provider/live operation;
- preserve the workstation, handover, and dormant cloud stop boundaries.

Do not rewrite the historical task text in Plan 1. Confirm its prominent corrective amendment and incomplete completion gate remain intact. Remove stale old-interface assertions only from tests/fixtures/code that execute the umbrella; retain child-library coverage for manifest/approval/action/state/read-back functions.

- [ ] **Step 4: Run focused GREEN on both hosts**

Run:

```powershell
$LifecycleTests = @(
  'infra/tests/pester/TenantLifecycleContracts.Tests.ps1',
  'infra/tests/pester/TenantLifecycleOrchestration.Tests.ps1',
  'infra/tests/pester/RunbookContracts.Tests.ps1',
  'infra/tests/pester/RunbookStaticSafety.Tests.ps1',
  'infra/tests/pester/RunbookDocumentation.Tests.ps1'
)
$LifecycleLiteral = ($LifecycleTests | ForEach-Object { "'$_'" }) -join ','
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path @($LifecycleLiteral) -Output Detailed"
if ($LASTEXITCODE -ne 0) { throw 'Windows PowerShell lifecycle coverage failed.' }
pwsh.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path @($LifecycleLiteral) -Output Detailed"
if ($LASTEXITCODE -ne 0) { throw 'PowerShell 7 lifecycle compatibility failed.' }
```

Expected: all lifecycle contract/orchestration/static/documentation tests **PASS** under both hosts with byte-identical golden outputs.

- [ ] **Step 5: Run full final verification**

Run from the lifecycle-core worktree:

```powershell
$ErrorActionPreference = 'Stop'
$MergeBase = (git merge-base main HEAD).Trim()
$OriginalCommits = @(git rev-list --reverse "$MergeBase..HEAD" | Select-Object -First 15)
if ($OriginalCommits.Count -ne 15) {
    throw "Expected to recover the original 15 lifecycle commits; found $($OriginalCommits.Count)."
}

Import-Module Pester -RequiredVersion 5.7.1 -Force
$full = Invoke-Pester -Path @('.github/cli/tests','infra/tests/pester','hr/tests/pester') -Output Detailed -PassThru
if ($full.FailedCount -gt 0) {
    throw "$($full.FailedCount) maintained Pester test(s) failed."
}

powershell.exe -NoProfile -ExecutionPolicy Bypass -File .github/cli/verify-repository-safety.ps1
if ($LASTEXITCODE -ne 0) { throw 'Repository safety verification failed.' }
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .github/cli/verify-repository-setup.ps1
if ($LASTEXITCODE -ne 0) { throw 'Repository setup verification failed.' }

$docs = Invoke-Pester -Path @(
  '.github/cli/tests/DocumentationMetadata.Tests.ps1',
  '.github/cli/tests/DocumentationLinks.Tests.ps1',
  '.github/cli/tests/DocumentationNavigation.Tests.ps1'
) -Output Detailed -PassThru
if ($docs.FailedCount -gt 0) {
    throw "$($docs.FailedCount) documentation validation test(s) failed."
}

Get-ChildItem infra/src/bicep -Filter *.bicep -File -Recurse |
    Sort-Object FullName |
    ForEach-Object {
        az bicep build --file $_.FullName --stdout | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Bicep build failed: $($_.FullName)" }
    }

git diff --check "$MergeBase..HEAD"
if ($LASTEXITCODE -ne 0) { throw 'Git diff whitespace validation failed.' }
git diff --exit-code "$MergeBase..HEAD" -- .github/workflows
if ($LASTEXITCODE -ne 0) { throw 'GitHub workflows changed.' }
git diff --exit-code "$MergeBase..HEAD" -- `
  infra/src/scripts/runbooks/Get-CloudFoundationPlan.ps1 `
  infra/src/scripts/runbooks/Invoke-CloudFoundation.ps1
if ($LASTEXITCODE -ne 0) { throw 'Dormant cloud stop stubs changed.' }

$OriginalCommits | ForEach-Object {
    git merge-base --is-ancestor $_ HEAD
    if ($LASTEXITCODE -ne 0) { throw "Original lifecycle commit was rewritten: $_" }
}

git status --short
git diff --stat "$MergeBase..HEAD"
git log --oneline --decorate "$MergeBase..HEAD"
```

Expected:

- focused lifecycle coverage passes on Windows PowerShell 5.1 and reviewed PowerShell 7;
- all maintained Pester suites pass with zero failures;
- repository safety/setup and documentation metadata/link/navigation checks pass;
- every Bicep source builds;
- `git diff --check` passes;
- `.github/workflows` and both dormant cloud stop stubs are unchanged;
- no live/provider runner was called;
- all original 15 commit IDs remain ancestors;
- `git status --short` is empty after the task commit; and
- the branch still has no merge/readiness claim.

- [ ] **Step 6: Perform final broad review**

Review the complete `$MergeBase..HEAD` diff, not only the five corrective commits. Use this exact checklist:

1. every Approved design requirement maps to a focused test and implementation path;
2. exact signature/types/modes match in source, plan, docs, and tests;
3. old parameters and aliases are rejected;
4. Verify never invokes `SubsystemInvoker` or a child;
5. missing/extra/duplicate/case/stale/tampered/foreign/noncanonical/reparse/path/digest adversarial cases are covered;
6. `Failed`, `Manual`, `Blocked`, and `Refused` block dependencies;
7. provider IDs/URLs/actions/payloads/read-back are prohibited from projection;
8. `CurrentBindingProvider` and `targetStableId` correlation are absent from umbrella code;
9. child manifest/approval/action/state/adoption/read-back helpers and tests remain;
10. private intent/state paths and adoption contracts remain unchanged;
11. no placeholder, broad catch, silent fallback, provider command, workflow change, stop-stub change, or live-execution claim exists; and
12. all six amended plans and this corrective plan remain `Draft` and blocked until the corrective branch merges and then-current `main` is green.

Any failed item keeps the branch blocked and returns to the owning task; do not waive or defer it.

- [ ] **Step 7: Commit**

```powershell
git add infra/tests/pester infra/docs infra/README.md
git commit -m "docs(runbooks): finalize coordinate-only lifecycle correction" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

After the commit, rerun `git status --short`, `git diff --check "$MergeBase..HEAD"`, the focused lifecycle suites on both hosts, and the full final verification command block. Expected: clean worktree and the same all-green evidence.

## Completion Gate

This correction is complete only when all five corrective commits follow the unchanged 15-commit history, focused lifecycle coverage passes on Windows PowerShell 5.1 and reviewed PowerShell 7, all maintained Pester/safety/setup/documentation/Bicep/workflow-neutral checks pass, dormant cloud stubs are byte-unchanged, no live/provider call occurred, and a broad review of the whole implementation branch finds no remaining umbrella Apply/approval/current-binding/provider-correlation authority or provider detail in the stage projection. Even then, `feat/tenant-lifecycle-core` remains blocked and nonmergeable until the clean review is accepted; Plans 2-6 remain `Draft` and blocked until the corrective change is merged and then-current `main` is green.
