# Tenant Lifecycle Core Implementation Plan

| Field | Value |
|---|---|
| **Version** | 1.3 |
| **Date** | 2026-10-03 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Draft |
| **Scope** | Shared Tenant 1 lifecycle contracts, orchestration, evidence, and synthetic tests |
| **References** | [Approved Coordinate-Only Simplification Design](../specs/2026-10-03-tenant-lifecycle-coordinate-only-simplification-design.md), [Coordinate-Only Correction Plan](2026-10-03-tenant-lifecycle-coordinate-only-correction-implementation.md), [Approved Tenant 1 Runbook End-to-End Design](../specs/2026-10-02-tenant-1-runbook-end-to-end-design.md), [Implementation Plan Catalogue](README.md), [Infrastructure Domain](../../infra/README.md) |

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the provider-neutral Tenant 1 lifecycle contracts, prerequisite engine, digest-bound evidence core, sanitized projection, and thin umbrella orchestrator without implementing or invoking a provider mutation.

**Architecture:** Extend the existing `Caldova.HrFrontier.Bootstrap` canonical-JSON and digest patterns with closed lifecycle schemas and focused public functions. `Invoke-TenantLifecycle.ps1` sequences independently runnable subsystems through injected invokers and passes only non-secret control records; provider-specific assessment and mutation remain in later plans. Intent remains human-owned, state remains observed and tool-owned, and neither can silently override the other.

**Tech Stack:** Windows PowerShell 5.1 (authoritative host), Pester 5.7.1, reviewed PowerShell 7 compatibility, JSON Schema draft 2020-12, Git, and the existing `Caldova.HrFrontier.Bootstrap` module.

**Spec:** [`docs/specs/2026-10-03-tenant-lifecycle-coordinate-only-simplification-design.md`](../specs/2026-10-03-tenant-lifecycle-coordinate-only-simplification-design.md), as the focused corrective authority over [`docs/specs/2026-10-02-tenant-1-runbook-end-to-end-design.md`](../specs/2026-10-02-tenant-1-runbook-end-to-end-design.md)

## 2026-10-03 Coordinate-Only Corrective Amendment

This amendment is controlling where the historical task text below conflicts with the Approved coordinate-only design.

- Tasks 1-7 remain the implementation history represented by the 15 existing commits on blocked branch `feat/tenant-lifecycle-core`. Do not rewrite, amend, squash, or restate those historical task steps.
- The [coordinate-only corrective plan](2026-10-03-tenant-lifecycle-coordinate-only-correction-implementation.md) supersedes Task 5's mutation-capable umbrella signature and execution path, Task 6's provider-ID/URL projection contract, and Task 7's umbrella approval/action-evidence assumptions.
- Tasks 1-4 remain retained shared child-library history: closed contracts, canonical JSON/digests, intent/state separation, one-time Create adoption with immutable stable IDs, prerequisite sorting, child manifests, child approvals, child action/state/read-back evidence, and atomic writes stay available to independently runnable child runbooks.
- The corrected umbrella has only `Assess`, `Plan`, and `Verify`; it has no `Apply`, `ExecutionManifestPath`, `ApprovedDigest`, `BindingObserver`, `CurrentBindingProvider`, approval loading, provider action/result correlation, resource-level target correlation, or `SupportsShouldProcess`.
- The corrected umbrella projection is stage-only. It contains no provider stable IDs, URLs, role IDs, action IDs, action payloads, or raw provider read-back.
- Plan 1 is incomplete until every corrective task passes focused review, Windows PowerShell 5.1 and reviewed PowerShell 7 lifecycle coverage, full maintained Pester, safety/setup validation, all Bicep builds, documentation validation, workflow-neutral checks, and a whole-branch review.
- Plan 1 and Plans 2-6 remain `Draft` and blocked. Plan 2 cannot begin until the corrective plan is merged and then-current `main` is green.

## Global Constraints

- This is Plan 1 and has no implementation-plan dependency. Plans 2-6 consume its accepted contracts.
- At execution time, use `superpowers:using-git-worktrees` before editing. Create branch `feat/tenant-lifecycle-core` and worktree `%LOCALAPPDATA%\CaldovaHR\wt\caldova-hr-frontier\lifecycle-core`; verify current-user create/write/delete access and prove the longest checkout path is **less than 240 characters**. Do not create that worktree while reviewing this plan.
- Start from then-current green `main`, run the baseline tests, and stop if the worktree is dirty, detached unexpectedly, sparse, conflicted, or not at the reviewed source commit.
- Windows PowerShell 5.1 with Pester 5.7.1 is authoritative. Run the stated PowerShell 7 checks only after the Windows PowerShell checks pass.
- Reuse `Write-CanonicalJson`, `Get-RunbookContentDigest`, `Resolve-RunbookReportPath`, and existing injected-runner patterns. Do not broadly rewrite the bootstrap module.
- Do not call GitHub, Entra, Azure, Azure DevOps, PAC, Power Platform, or any service API. Do not install software, authenticate, mutate a provider, queue a pipeline, or import a solution.
- The umbrella script contains no provider command, provider payload, secret parameter, token, credential, first-match selection, self-elevation, rollback, or tenant fallback.
- Preserve the dormant `Get-CloudFoundationPlan.ps1` and `Invoke-CloudFoundation.ps1` initial stop guards. This plan does not edit either file.
- Keep `tenant1.local.psd1` as human-reviewed intent and `tenant1.state.local.json` as observed stable state. State cannot introduce desired resources or change a `Manual`, `Blocked`, or `Refused` classification.
- Use only `NoChange`, `Create`, `Update`, `Manual`, `Blocked`, and `Refused`. A dependent step proceeds only from a fresh successful prerequisite.
- Canonical JSON is UTF-8 without BOM, ordinal-key-sorted, array-order-preserving, depth 30, one trailing LF, and lowercase SHA-256 over those exact bytes.
- All lifecycle JSON reloads use the shared string-preserving loader: `ConvertFrom-Json -DateKind String` when supported and plain `ConvertFrom-Json` on Windows PowerShell 5.1. Generated timestamps use seven fractional digits and `Z`.
- Umbrella evidence filenames are exactly `assessment.json`, `execution-manifest.json`, `approvals.json`, `actions/<stage>.json`, `read-back.json`, `pipeline.json`, `power-platform.json`, and `summary.json`.
- Private `tenant1.state.local.json` is never copied into run evidence. Assessment and manifest bind its canonical `stateDigest`; acceptance consumes only closed read-back evidence and reviewed stable-ID disclosures.
- Approval expires at the earlier of the manifest expiry or 30 minutes after generation. Restart, source, intent, state, machine, tool, context, prerequisite, action, or evidence-root drift invalidates it.
- The core execution manifest is stage-level: exactly one action per selected umbrella stage in canonical selected-stage order. A provider subsystem may own multiple actions only in its own digest-bound provider manifest; only that manifest's digest may cross the umbrella stage input/evidence boundary.
- No committed fixture may contain a real tenant ID, subscription ID, application ID, environment URL, private path, credential, token, customer data, or HR data.
- Each task follows RED/GREEN, focused review, and a focused commit. Use the exact commit trailer `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>`.

## File and Contract Map

| Path | Responsibility |
|---|---|
| `infra/src/config/schemas/tenant-lifecycle-assessment.schema.json` | Closed assessment and classification contract. |
| `infra/src/config/schemas/tenant-lifecycle-execution-manifest.schema.json` | Complete approval binding, ordered actions, expiry, and drift inputs. |
| `infra/src/config/schemas/tenant-lifecycle-approval.schema.json` | Human approval record without session or credential data. |
| `infra/src/config/schemas/tenant-lifecycle-action-evidence.schema.json` | One atomic pre-read/action/post-read envelope. |
| `infra/src/config/schemas/tenant-lifecycle-state.schema.json` | Tool-owned stable-ID adoption state, never desired intent. |
| `infra/src/config/schemas/tenant-lifecycle-read-back.schema.json` | Consolidated stable-ID and exact-property read-back. |
| `infra/src/config/schemas/tenant-lifecycle-summary.schema.json` | Consolidated allowlisted run result. |
| `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/ConvertFrom-TenantLifecycleJson.ps1` | Shared cross-host string-preserving lifecycle JSON load and canonical serialization helpers. |
| `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/*TenantLifecycle*.ps1` | Public lifecycle constructors, validators, graph evaluation, and acceptance projection. |
| `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/*TenantLifecycle*.ps1` | Closed-object, relative-path, atomic-write, and redaction internals. |
| `infra/src/scripts/runbooks/Invoke-TenantLifecycle.ps1` | Provider-neutral stage sequencing only. |
| `infra/tests/pester/TenantLifecycleContracts.Tests.ps1` | Schema, type, digest, state, and approval tests. |
| `infra/tests/pester/TenantLifecycleOrchestration.Tests.ps1` | Synthetic graph, orchestration, failure, and no-provider tests. |
| `infra/tests/fixtures/runbooks/tenant-lifecycle.synthetic.json` | Fully synthetic lifecycle input. |

The schema root fields are fixed as follows:

- assessment: `schemaVersion`, `runId`, `kind`, `generatedAtUtc`, `sourceCommit`, `machine`, `publicTenantKey`, `intentDigest`, `stateDigest`, `toolIdentities`, `providerContexts`, `components`, `prerequisites`, `digest`;
- execution manifest: `schemaVersion`, `runId`, `generatedAtUtc`, `expiresAtUtc`, `sourceCommit`, `evidenceRoot`, `publicTenantKey`, `intentDigest`, `stateDigest`, `machine`, `operator`, `toolIdentities`, `providerContexts`, `prerequisites`, `actions`, `digest`;
- action: `id`, `provider`, `classification`, `targetStableId`, `absencePredicate`, `desiredPropertiesDigest`, `preconditionDigest`, `prerequisiteActionIds`, `adapter`, `shouldProcessTarget`, `expectedPostcondition`, `recovery`, `evidenceProjection`;
- approval: `schemaVersion`, `runId`, `executionManifestDigest`, `approverRole`, `approvedAtUtc`, `expiresAtUtc`, `scope`, `status`;
- state resource: `provider`, `resourceType`, `logicalName`, `stableId`, `lastVerifiedAtUtc`, `ownedPropertiesDigest`; `stableId` may be null only while the exact reviewed `Create` component remains unadopted;
- action evidence: `schemaVersion`, `runId`, `actionId`, `classification`, `startedAtUtc`, `completedAtUtc`, `preReadDigest`, `decision`, `postReadDigest`, `status`, `errorCode`, `recovery`;
- read-back: `schemaVersion`, `runId`, `generatedAtUtc`, `components`, `status`, `digest`; each component has `id`, `provider`, `stableId`, `ownedPropertiesDigest`, `status`;
- summary: `schemaVersion`, `runId`, `sourceCommit`, `manifestDigest`, `startedAtUtc`, `completedAtUtc`, `status`, `counts`, `prerequisites`, `actions`, `nonClaims`.

---

### Task 1: Closed Lifecycle Schemas and Runtime Contract Validation

**Files:**
- Create: the seven `tenant-lifecycle-*.schema.json` files in the file map.
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Test-TenantLifecycleContract.ps1`
- Modify: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Caldova.HrFrontier.Bootstrap.psd1`
- Modify: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Caldova.HrFrontier.Bootstrap.psm1`
- Create: `infra/tests/pester/TenantLifecycleContracts.Tests.ps1`
- Create: `infra/tests/fixtures/runbooks/tenant-lifecycle.synthetic.json`

**Interfaces:**
- Consumes: existing `Get-RunbookContentDigest -InputObject <object>`.
- Produces: `Test-TenantLifecycleContract -Kind <Assessment|ExecutionManifest|Approval|ActionEvidence|State|ReadBack|Summary> -InputObject <object>`, returning `$true` or throwing a stable `TenantLifecycle.Contract.<Kind>` error.
- Produces: the exact schema fields listed in the file map; every object has `additionalProperties: false`, `schemaVersion: "1.0"`, and ordinally unique action/resource IDs.

- [ ] **Step 1: Write the failing contract tests**

Add table-driven Pester cases that load each schema, accept a complete synthetic object, reject one unknown property, reject a missing required property, reject a non-lowercase digest, reject duplicate action IDs, reject a state resource without the `stableId` property, accept a null `stableId` at the schema layer, reject classifications outside the six-value set, and reject nested alias, script, code, executable, hidden, or additional runtime members without invoking getters. Assert module exports of `Test-TenantLifecycleContract` and the shared lifecycle JSON loader.

- [ ] **Step 2: Run RED**

Run:

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path 'infra/tests/pester/TenantLifecycleContracts.Tests.ps1' -Output Detailed"
```

Expected: **FAIL** because the schemas and `Test-TenantLifecycleContract` do not exist.

- [ ] **Step 3: Implement the minimum closed contracts**

Implement the schemas with the fixed fields above. Implement:

```powershell
function Test-TenantLifecycleContract {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Assessment','ExecutionManifest','Approval','ActionEvidence','State','ReadBack','Summary')]
        [string]$Kind,
        [Parameter(Mandatory)][object]$InputObject
    )
}
```

Use explicit allowed/required property arrays and type/value checks compatible with Windows PowerShell 5.1; inspect every property member before reading any value and accept only passive JSON data members. Do not make runtime correctness depend on `Test-Json`. Keep the JSON schemas as machine-readable mirrors and test them with the repository's existing Python `jsonschema` dependency where available. Implement and export `ConvertFrom-TenantLifecycleJson` for every lifecycle hashing/validation reload, preserving date strings on both required hosts.

- [ ] **Step 4: Run GREEN**

Run the RED command again, then:

```powershell
pwsh.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path 'infra/tests/pester/TenantLifecycleContracts.Tests.ps1' -Output Detailed"
```

Expected: both runs **PASS**; invalid fixtures fail with stable contract errors and no sensitive value in the message.

- [ ] **Step 5: Perform focused review**

Review only the six schemas, fixture, export lists, and validator. Confirm exact field parity, closed objects, no real identifiers, no permissive `.*` tenant fields, no secret-shaped properties, and Windows PowerShell 5.1 parsing.

- [ ] **Step 6: Commit**

```powershell
git add infra/src/config/schemas/tenant-lifecycle-*.schema.json infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap infra/tests/pester/TenantLifecycleContracts.Tests.ps1 infra/tests/fixtures/runbooks/tenant-lifecycle.synthetic.json
git commit -m "feat(runbooks): add lifecycle contract schemas" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 2: Intent/State Separation and Private-Boundary Validation

**Files:**
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Test-TenantLifecyclePrivateBoundary.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Import-TenantLifecycleState.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Update-TenantLifecycleState.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/Test-TenantLifecycleGitBoundary.ps1`
- Modify: module manifest and root module export lists.
- Modify: `infra/tests/pester/TenantLifecycleContracts.Tests.ps1`

**Interfaces:**
- Consumes: `Import-TenantConfiguration -Path <tenant1.local.psd1>` and Task 1 state contract.
- Produces: `Test-TenantLifecyclePrivateBoundary -PublicTenantKey tenant1 -IntentPath <absolute> -StatePath <absolute> -RepositoryRoot <absolute> -NativeCommandRunner <scriptblock>`.
- Produces: `Import-TenantLifecycleState -Path <absolute> -PublicTenantKey tenant1`.
- Produces: `Update-TenantLifecycleState -State <object> -ReviewedIntentPath <absolute> -ReviewedIntentComponentName <string> -VerifiedResource <object> -NowUtc <datetime>`; the function loads the reviewed intent itself, and the exact provider/resource-type/logical-name resource must already exist in reviewed intent and state and have exact post-read proof.

- [ ] **Step 1: Write failing separation tests**

Test absent files, tracked files, paths outside `infra/src/config/tenants`, template selection, wrong `PublicTenantKey`, state-added desired properties, duplicate stable IDs, state changing intent classification, exact ignored/untracked paths, and a valid synthetic private pair. Inject `git check-ignore`, `git ls-files`, and `git status --porcelain` results.

- [ ] **Step 2: Run RED**

Run:

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path 'infra/tests/pester/TenantLifecycleContracts.Tests.ps1' -FullNameFilter '*intent and state separation*' -Output Detailed"
```

Expected: **FAIL** because the private-boundary and state functions are not exported.

- [ ] **Step 3: Implement the minimum boundary**

Implement exact signatures:

```powershell
Test-TenantLifecyclePrivateBoundary `
  -PublicTenantKey <string> -IntentPath <string> -StatePath <string> `
  -RepositoryRoot <string> -NativeCommandRunner <scriptblock>

Import-TenantLifecycleState -Path <string> -PublicTenantKey <string>

Update-TenantLifecycleState `
  -State <object> -ReviewedIntentPath <absolute> `
  -ReviewedIntentComponentName <string> `
  -VerifiedResource <object> -NowUtc <datetime>
```

The function loads `ReviewedIntentPath` with `Import-TenantConfiguration` and selects the exact named reviewed component. That component explicitly binds `Provider`, `ResourceType`, `LogicalName`, and `Mode`, plus `Id` for `Existing`. Its identity must match the exact verified resource and exactly one resource already represented in state. `Existing` requires a non-null exact reviewed ID. `Create` starts with `stableId: null`, may adopt the exact verified stable ID once after exact read-back, and can never change a non-null stable ID on a later call.

Return a sanitized boundary record containing only `publicTenantKey`, relative labels, existence/ignored/tracked/schema statuses, and intent/state digests. Never return private values or hash a private value into committed evidence. `Update-TenantLifecycleState` may update only `stableId` for `Create`, plus `lastVerifiedAtUtc` and `ownedPropertiesDigest`, after exact read-back.

- [ ] **Step 4: Run GREEN**

Run the RED command again. Expected: **PASS**, with no native call for schema-invalid paths and no path/value leakage in thrown messages.

- [ ] **Step 5: Perform focused review**

Confirm no first-match path selection, no default tenant content path, no discovery-to-intent conversion, no state-created desired resource, and no source mutation or Git cleanup.

- [ ] **Step 6: Commit**

```powershell
git add infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap infra/tests/pester/TenantLifecycleContracts.Tests.ps1
git commit -m "feat(runbooks): separate tenant intent and state" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 3: Prerequisite Graph and Classification Engine

**Files:**
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Resolve-TenantLifecycleGraph.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/Sort-TenantLifecycleGraph.ps1`
- Modify: module export lists.
- Create: `infra/tests/pester/TenantLifecycleOrchestration.Tests.ps1`

**Interfaces:**
- Consumes: Task 1 action objects and six classifications.
- Produces: `Resolve-TenantLifecycleGraph -Nodes <object[]> -ObservedOutcomes <object[]>`, returning ordered nodes with `status`, `blockingPrerequisiteIds`, and `canExecute`.
- Node fields are exactly the six readable instance properties `id`, `kind`, `prerequisiteIds`, `requiredOutcome`, `inputDigest`, and `stage`; any additional property of any member type, including `ScriptProperty` or `CodeProperty`, is invalid.
- `requiredOutcome` is the case-sensitive literal `Passed`. It is descriptive contract data, not a caller-controlled success selector.
- For `Create`, `Update`, and `Manual`, `inputDigest` is the approved expected owned-properties/input digest. `readBackDigest` binds ordinally to that exact value; a different valid digest is `Unverified` and never fresh success. Plans 2-6 and provider-specific plans must preserve this binding.

- [ ] **Step 1: Write failing graph tests**

Cover deterministic topological order across every meaningful input permutation, missing prerequisite, cycle, duplicate ID, closed property membership (including `ScriptProperty` and `CodeProperty` extras), caller-supplied non-`Passed` required outcomes, stale digest, mismatched valid read-back digest, `Manual` without read-back, propagation of `Blocked` and `Refused`, failed prerequisite, and an all-`NoChange` path. Assert later nodes never execute when a prerequisite is not fresh success.

- [ ] **Step 2: Run RED**

Run:

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path 'infra/tests/pester/TenantLifecycleOrchestration.Tests.ps1' -FullNameFilter '*prerequisite graph*' -Output Detailed"
```

Expected: **FAIL** because `Resolve-TenantLifecycleGraph` is unavailable.

- [ ] **Step 3: Implement the minimum graph engine**

Implement:

```powershell
function Resolve-TenantLifecycleGraph {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)][object[]]$Nodes,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$ObservedOutcomes
    )
}
```

Use ordinal ID comparison and Kahn topological sorting. Validate all node properties before reading their values, accepting only the exact six-property contract and rejecting hidden or executable property types. Fresh success means outcome status is the literal `Passed`, `inputDigest` matches, and classification is `NoChange`. A completed `Create`, `Update`, or `Manual` additionally requires `readBackDigest` to ordinally equal the node `inputDigest` (the approved expected owned-properties/input digest); a different valid read-back digest is `Unverified`. `Manual` without read-back remains non-success.

- [ ] **Step 4: Run GREEN**

Run the RED command again. Expected: **PASS**, including stable cycle and missing-prerequisite failures.

- [ ] **Step 5: Perform focused review**

Review classification propagation and prove that no graph branch treats absent, stale, `Manual`, `Blocked`, or `Refused` as truthy success.

- [ ] **Step 6: Commit**

```powershell
git add infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap infra/tests/pester/TenantLifecycleOrchestration.Tests.ps1
git commit -m "feat(runbooks): add lifecycle prerequisite graph" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 4: Atomic Evidence Writer, Manifest, Approval, Expiry, and Drift

**Files:**
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/New-TenantLifecycleExecutionManifest.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Test-TenantLifecycleApproval.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Write-TenantLifecycleEvidence.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/Write-TenantLifecycleAtomicFile.ps1`
- Modify: module export lists.
- Modify: both lifecycle Pester files.

**Interfaces:**
- Consumes: Task 1 schemas, Task 3 ordered graph, existing canonical JSON/digest functions.
- Produces:

```powershell
New-TenantLifecycleExecutionManifest `
  -RunId <guid> -SourceCommit <40-hex> -EvidenceRoot <absolute> `
  -PublicTenantKey tenant1 -IntentDigest <64-hex> -StateDigest <64-hex> `
  -Machine <object> -Operator <object> -ToolIdentities <object[]> `
  -ProviderContexts <object[]> -Prerequisites <object[]> -Actions <object[]> `
  -GeneratedAtUtc <datetime> -ExpiresAtUtc <datetime>

Test-TenantLifecycleApproval `
  -Manifest <object> -Approval <object> -CurrentBinding <object> -NowUtc <datetime>

Write-TenantLifecycleEvidence `
  -RunDirectory <absolute> -RelativePath <allowlisted-relative-path> `
  -Kind <Assessment|ExecutionManifest|Approval|ActionEvidence|ReadBack|Summary> `
  -InputObject <object>
```

- [ ] **Step 1: Write failing evidence and drift tests**

Test canonical repeatability, exact filenames, temporary-file atomic promotion, no partial file on failure, action envelope immutability, approval digest mismatch, >30-minute expiry, restart session mismatch, machine/source/intent/state/tool/context/prerequisite/action/evidence-root drift, path traversal, reparse-point root, and prohibited evidence properties.

- [ ] **Step 2: Run RED**

Run:

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path @('infra/tests/pester/TenantLifecycleContracts.Tests.ps1','infra/tests/pester/TenantLifecycleOrchestration.Tests.ps1') -FullNameFilter '*evidence*','*approval*','*drift*' -Output Detailed"
```

Expected: **FAIL** because the lifecycle manifest, approval validator, and writer do not exist.

- [ ] **Step 3: Implement minimum evidence behavior**

Bind every listed manifest field into `digest`. Require approval `status: Approved`, exact digest/scope/run ID, and expiry not later than the manifest expiry. `CurrentBinding` has the same binding fields as the manifest plus `sessionId`; mismatch throws `TenantLifecycle.Approval.Drift.<field>`. For this integration, `CurrentBinding.sessionId` is `[string]$PID` from the PowerShell process that captured the approval binding; callers must carry that binding forward rather than reconstructing it after restart. This invariant does not add a session field to the accepted schemas. Current binding and evidence objects are recursively closed before values are read. Write to a same-directory GUID temporary file, flush and close, then atomically move only after validation. Never overwrite an existing action envelope, and never accept private state as run evidence.

- [ ] **Step 4: Run GREEN**

Run the RED command again. Expected: **PASS** and byte-identical output for repeated equivalent inputs.

- [ ] **Step 5: Perform focused review**

Inspect all write paths and error text. Confirm allowlisted filenames, no overwrite of completed evidence, no raw command output, no absolute private path in sanitized records, and no stale approval continuation.

- [ ] **Step 6: Commit**

```powershell
git add infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap infra/tests/pester/TenantLifecycleContracts.Tests.ps1 infra/tests/pester/TenantLifecycleOrchestration.Tests.ps1
git commit -m "feat(runbooks): bind lifecycle evidence and approval" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 5: Provider-Neutral Umbrella Orchestrator

**Files:**
- Create: `infra/src/scripts/runbooks/Invoke-TenantLifecycle.ps1`
- Modify: `infra/tests/pester/TenantLifecycleOrchestration.Tests.ps1`
- Modify: `infra/tests/pester/RunbookStaticSafety.Tests.ps1`
- Modify: `infra/tests/pester/RunbookContracts.Tests.ps1`

**Interfaces:**
- Consumes: Tasks 2-4 and an injected `SubsystemInvoker`.
- Produces this exact public signature:

```powershell
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)][guid]$RunId,
    [Parameter(Mandatory)][string]$EvidenceRoot,
    [Parameter(Mandatory)][string]$RepositoryRoot,
    [Parameter(Mandatory)][ValidatePattern('^[0-9a-fA-F]{40}$')][string]$ExpectedSourceCommit,
    [Parameter(Mandatory)][ValidateSet('tenant1')][string]$PublicTenantKey,
    [Parameter(Mandatory)][string]$TenantConfigurationPath,
    [Parameter(Mandatory)][string]$TenantStatePath,
    [Parameter(Mandatory)]
    [ValidateSet('Workstation','PrivateBoundary','Foundation','DevDelivery','ReadBack','Acceptance','TenantReplica')]
    [string[]]$Stages,
    [ValidateSet('Assess','Plan','Invoke')][string]$Mode = 'Assess',
    [string]$ExecutionManifestPath,
    [ValidatePattern('^[0-9a-f]{64}$')][string]$ApprovedDigest,
    [switch]$Apply,
    [Parameter(DontShow)][scriptblock]$SubsystemInvoker,
    [Parameter(DontShow)][scriptblock]$BindingObserver,
    [Parameter(DontShow)][scriptblock]$CurrentBindingProvider,
    [datetime]$NowUtc = [datetime]::UtcNow
)
```

The invoker contract is `param([string]$Stage,[string]$Mode,[object]$ControlRecord)` and returns `id`, `stage`, `classification`, `status`, `inputDigest`, `readBackDigest`, `evidenceRelativePath`.

The execution manifest and invoker boundary are amended as follows:

- `actions` contains exactly one lifecycle action for each selected umbrella stage, in canonical selected-stage order. Provider actions never appear in this manifest.
- The first selected stage has no `prerequisiteActionIds`. Each later selected stage has exactly the immediately preceding selected stage as its sole prerequisite. An independent subset therefore starts with no prerequisite and stays linear across only the selected stages.
- A provider subsystem may hold multiple provider actions in its own digest-bound provider manifest. Its umbrella stage action references that provider manifest through `desiredPropertiesDigest`; the closed control record exposes only the same opaque `stageInputDigest`, never the provider manifest or its actions. The stage input digest and action evidence bind that value transitively.
- The invoker continues to return one outcome and one umbrella action-evidence path per stage.
- `BindingObserver` is a hidden provider-neutral test hook. It receives checkpoint and optional stage labels before revalidation and supplies no provider data, approval material, or path. Production callers omit it.
- `CurrentBindingProvider` is hidden and required only for `Invoke`. It takes no manifest-derived values from the orchestrator and returns a fresh closed current binding at every mutation boundary.

- [ ] **Step 1: Write failing orchestration and safety tests**

Test stage order, exact stage-level manifest scope, linear prerequisites for full and independently selected subsets, prerequisite blocking, no `-Apply` without approved digest, `-WhatIf` dominance, no provider executable literals, no credential parameters, no direct import of subsystem scripts, no mutation when an injected stage returns `Manual`, and exact non-secret control-record properties. Add RED cases for source/intent/state drift injected after initial validation and between stages, approval status/expiry/restart/drift/scope through the production orchestrator, missing or executable current-binding provider output, `Assess` and `Plan` with a supplied manifest but no approval/current binding/action evidence/read-back, `Invoke` with a null read-back digest, noncanonical action evidence bytes, and a nested provider manifest represented only by its opaque digest with no provider actions in the umbrella control record.

- [ ] **Step 2: Run RED**

Run:

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path @('infra/tests/pester/TenantLifecycleOrchestration.Tests.ps1','infra/tests/pester/RunbookStaticSafety.Tests.ps1','infra/tests/pester/RunbookContracts.Tests.ps1') -Output Detailed"
```

Expected: **FAIL** because `Invoke-TenantLifecycle.ps1` and its contract are absent.

- [ ] **Step 3: Implement the thin orchestrator**

Resolve the run directory with `Resolve-RunbookReportPath`; validate source `HEAD`, source cleanliness, and the private boundary during initial intake. In `Invoke`, require `CurrentBindingProvider`, load fixed `approvals.json` from the run directory through the shared lifecycle JSON loader, rerun those source checks and `Test-TenantLifecyclePrivateBoundary` immediately before `ShouldProcess`, obtain a fresh provider binding, and call `Test-TenantLifecycleApproval`. Repeat the same source/private/approval/current-binding sequence immediately before every subsystem invocation. Never populate current machine, operator, tool, provider-context, prerequisite, action, or session values from the manifest. Drift introduced by an earlier stage or concurrent process blocks later invocation. Evaluate prerequisites with Task 3; pass only `runId`, run-directory label, public tenant key, source commit, machine/operator labels, tool identity records, approved digest, opaque `stageInputDigest`, and prerequisite outcomes. Gate non-null read-back validation, canonical action-evidence byte equality, action-evidence correlation, and umbrella summary emission to `Invoke`; `Assess` and `Plan` may use a supplied manifest as context without approval, current binding, action evidence, or read-back. Default invoker must fail closed with `TenantLifecycle.SubsystemInvoker.Required`; it must not discover or call providers.

- [ ] **Step 4: Run GREEN**

Run the RED command again. Expected: **PASS** with injected synthetic invocations only and zero provider command calls.

- [ ] **Step 5: Perform focused review**

Compare the script to spec section 4.1. Confirm it is sequencing-only, independently runnable subsets use only their selected-stage chain, the manifest has one action and the invoker one outcome per stage, provider manifests cross only as an opaque stage-input/evidence digest, source/private rebinds occur immediately before `ShouldProcess` and each invocation, `ShouldProcess` wraps invocation mode, and no token/payload/fallback/provider action crosses the interface.

- [ ] **Step 6: Commit**

```powershell
git add infra/src/scripts/runbooks/Invoke-TenantLifecycle.ps1 infra/tests/pester/TenantLifecycleOrchestration.Tests.ps1 infra/tests/pester/RunbookStaticSafety.Tests.ps1 infra/tests/pester/RunbookContracts.Tests.ps1
git commit -m "feat(runbooks): add tenant lifecycle orchestrator" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 6: Sanitized Acceptance Projection

**Files:**
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/ConvertTo-TenantLifecycleAcceptanceProjection.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/Test-TenantLifecycleDisclosure.ps1`
- Modify: module export lists.
- Modify: both lifecycle Pester files.

**Interfaces:**
- Consumes: exact evidence files from Task 4.
- Produces:

```powershell
ConvertTo-TenantLifecycleAcceptanceProjection `
  -RunDirectory <absolute> `
  -AllowedStableIds <string[]> `
  -AllowedUrlHosts <string[]> `
  -OutputPath <absolute-outside-git>
```

The projection contains only `runId`, `sourceCommit`, approved digests, disclosed stable IDs, classifications/statuses/counts, artifact digest, and non-claims.

- [ ] **Step 1: Write failing disclosure tests**

Seed synthetic evidence with tokens, private paths, an unapproved stable ID, URL query strings, raw command output, and private intent values. Assert fail-closed projection, allowlisted host normalization, exact disclosed IDs only, explicit non-claims, and no overwrite.

- [ ] **Step 2: Run RED**

Run:

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path @('infra/tests/pester/TenantLifecycleContracts.Tests.ps1','infra/tests/pester/TenantLifecycleOrchestration.Tests.ps1') -FullNameFilter '*acceptance projection*' -Output Detailed"
```

Expected: **FAIL** because the projection function does not exist.

- [ ] **Step 3: Implement minimum projection**

Read only known evidence filenames, validate each before use, reconstruct the projection from allowlisted properties, strip URL paths/query/fragment unless explicitly approved, and throw when prohibited material appears rather than attempting broad regex redaction. Do not read or require private state evidence. Bind assessment and manifest `stateDigest`, validate the independent read-back contract and embedded digest, correlate actual canonical action evidence, require each non-null manifest action target stable ID in read-back, and disclose only stable IDs or URL hosts present in the explicit allowlists. Write canonical JSON outside Git through Task 4.

- [ ] **Step 4: Run GREEN**

Run the RED command again. Expected: **PASS** and no prohibited synthetic marker in output or errors.

- [ ] **Step 5: Perform focused review**

Review disclosure as an allowlist, not a denylist. Confirm the projection makes no claim that provider mutation, pipeline import, or artifact-byte verification occurred.

- [ ] **Step 6: Commit**

```powershell
git add infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap infra/tests/pester/TenantLifecycleContracts.Tests.ps1 infra/tests/pester/TenantLifecycleOrchestration.Tests.ps1
git commit -m "feat(runbooks): add sanitized acceptance projection" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 7: Synthetic Lifecycle Acceptance, Documentation, and Full Verification

**Files:**
- Modify: `infra/tests/pester/TenantLifecycleOrchestration.Tests.ps1`
- Modify: `infra/docs/runbooks/README.md`
- Modify: `infra/docs/runbooks/01-developer-workstation.md`
- Modify: `infra/docs/runbooks/03-customer-handover.md`
- Modify: `infra/docs/README.md`
- Modify: `infra/README.md`

**Interfaces:**
- Consumes: all Plan 1 contracts.
- Produces: a documented provider-neutral lifecycle contract for Plans 2-6; no active provider procedure.

- [ ] **Step 1: Write the failing end-to-end synthetic test**

Add one fixture-driven lifecycle that writes assessment, manifest, approval, action envelopes, read-back, and summary without copying private state into evidence; interrupts after one action; requires a new manifest after simulated restart; completes with all `NoChange`; generates a sanitized projection; and proves no provider runner was called.

- [ ] **Step 2: Run RED**

Run:

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path 'infra/tests/pester/TenantLifecycleOrchestration.Tests.ps1' -FullNameFilter '*synthetic lifecycle acceptance*' -Output Detailed"
```

Expected: **FAIL** until the fixture and complete evidence sequence are wired.

- [ ] **Step 3: Complete the synthetic path and lean documentation**

Document exact evidence names, classifications, intent/state boundary, umbrella signature, subsystem independence, restart invalidation, and the explicit statement “no provider mutation is implemented by the lifecycle core.” Update all direct-child catalogues touched by runbook references.

- [ ] **Step 4: Run GREEN and final verification**

Run:

```powershell
$ErrorActionPreference = 'Stop'
Import-Module Pester -RequiredVersion 5.7.1 -Force
$paths = @(
  '.github/cli/tests',
  'infra/tests/pester',
  'hr/tests/pester'
)
$result = Invoke-Pester -Path $paths -Output Detailed -PassThru
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

Expected: all Pester suites, safety/setup validators, and Bicep builds **PASS**; whitespace is clean; GitHub workflows are unchanged; status contains only reviewed Plan 1 files. Also run the focused lifecycle suites under reviewed PowerShell 7 and expect **PASS**.

- [ ] **Step 5: Perform focused review**

Review spec sections 4-7 and 9 against the implementation. Scan for `TODO`, `TBD`, “similar to”, secret parameters, provider commands, broad catches, first-match selection, silent legacy activation, and undocumented exports. Confirm no provider mutation and no live execution.

- [ ] **Step 6: Commit**

```powershell
git add infra/src infra/tests infra/docs infra/README.md
git commit -m "docs(runbooks): document lifecycle core contracts" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

## Completion Gate

Plan 1 is complete only when all seven historical task commits and the coordinate-only correction are reviewed, Windows PowerShell 5.1 is green, reviewed PowerShell 7 compatibility is green, the full repository-neutral validation passes, the stop stubs are unchanged, and synthetic evidence proves child-owned approval expiry, drift invalidation, restart invalidation, deterministic stage-result behavior, exact `Passed` dependency handling, and zero umbrella provider mutation. Until the corrective plan is merged and then-current `main` is green, Plan 1 remains incomplete and blocked.
