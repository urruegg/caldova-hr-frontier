# Tenant Replica and Customer Handover Implementation Plan

| Field | Value |
|---|---|
| **Version** | 1.1 |
| **Date** | 2026-10-03 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Draft |
| **Scope** | Local profile-based TenantReplica and CustomerHandover export, compatibility, and independent validation |
| **References** | [Approved Tenant Replica and Customer Handover Runbook Design](../specs/2026-10-02-tenant-replica-and-customer-handover-runbook-design.md), [Approved Coordinate-Only Simplification Design](../specs/2026-10-03-tenant-lifecycle-coordinate-only-simplification-design.md), [Coordinate-Only Correction Plan](2026-10-03-tenant-lifecycle-coordinate-only-correction-implementation.md), [Tenant Lifecycle Core Plan](2026-10-02-tenant-lifecycle-core-implementation.md), [Current Customer Handover Runbook](../../infra/docs/runbooks/03-customer-handover.md) |

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Evolve the existing local customer-export engine into one explicit-profile engine for `TenantReplica` and `CustomerHandover`, preserving stricter compatibility behavior and proving complete local exports independently without remote creation, publication, or Tenant 2 action.

**Architecture:** Keep the committed-blob reader, exact transformations, marker catalogue, deterministic plan, `ShouldProcess`, and byte-level independent validation. Add one closed canonical manifest with explicit profiles and a compatibility adapter for existing customer manifests; profile policy determines retain/deny maps and required local suites, while source/destination safety and copy/transform/validate/promote behavior remain shared.

**Tech Stack:** Windows PowerShell 5.1 (authoritative), Pester 5.7.1, reviewed PowerShell 7 compatibility, Git object reads, JSON Schema draft 2020-12, SHA-256, and `Caldova.HrFrontier.Bootstrap`.

**Spec:** [`docs/specs/2026-10-02-tenant-replica-and-customer-handover-runbook-design.md`](../specs/2026-10-02-tenant-replica-and-customer-handover-runbook-design.md)

## 2026-10-03 Coordinate-Only Dependency Amendment

This child plan remains `Draft`. Tasks 1-4 cannot begin until the [coordinate-only correction](2026-10-03-tenant-lifecycle-coordinate-only-correction-implementation.md) and corrected Plan 1 are merged and then-current `main` is green; the existing Plan 4 gate for final retained-pipeline acceptance also remains.

- `Test-RepositoryExport.ps1`, `New-RepositoryExportPlan.ps1`, and `Invoke-RepositoryExport.ps1` own the complete local child lifecycle: child assessment, child execution manifest, child `approvals.json`, child `-WhatIf`, child `-Apply`, child `ShouldProcess`, independent full-tree read-back/validation, terminal child summary, and canonical `TenantReplica` stage result.
- Existing `ExecutionManifestPath`, `ApprovedDigest`, and Apply behavior remain local child interfaces. They are not umbrella parameters and do not depend on umbrella approval loading, `CurrentBindingProvider`, or umbrella resource-level correlation.
- The child writes `<run>/stage-results/TenantReplica.json` only after atomic destination promotion and independent validation pass, or after a terminal child outcome is truthfully recorded. Remote/provider coordinates, destination details, file payloads, action IDs, and validation output stay in child evidence.
- Existing Plan 1 manifest, approval, action-evidence, atomic-write, and read-back helpers remain shared child-library dependencies. Umbrella `Verify` reads only the canonical stage result and contained canonical child summary and never invokes the export engine.

## Global Constraints

- This is Plan 5. Tasks 1-4 may begin after Plan 1 is merged and then-current `main` is green. Tasks 5-6 may implement profile-independent validation before Plan 4, but final `TenantReplica` retained-tree acceptance must wait until Plan 4's root pipeline/templates are merged and current-main tests are green.
- At execution time, use `superpowers:using-git-worktrees`. Create branch `feat/tenant-replica-handover` and worktree `%LOCALAPPDATA%\CaldovaHR\wt\caldova-hr-frontier\replica`; verify current-user write/delete access and a longest checkout path **less than 240 characters**.
- Windows PowerShell 5.1 with Pester 5.7.1 is authoritative; run focused profile/export tests with reviewed PowerShell 7 after Windows PowerShell passes.
- Do not create/init a repository, configure a remote, authenticate, call a provider, push, publish, transfer, create a destination repository/project, or perform Tenant 2/Tenant 3 discovery or mutation.
- Reuse the current scripts/module engine, committed Git blobs, source snapshot, exact replacement, marker, execution-manifest, `ShouldProcess`, and independent byte-comparison patterns. Do not create a second copy engine.
- Every new public operation requires an explicit `TenantReplica` or `CustomerHandover` profile. Unknown, absent, or conflicting profile is blocking.
- Preserve existing `CustomerHandover` behavior or make it stricter. Existing v1 manifests are accepted only through a tested compatibility adapter that labels them `CustomerHandover`; no general profile entry point infers a profile.
- Source must be clean, exact-commit, non-sparse, conflict-free, submodule-free for accepted export, and immutable before/after. Never clean/reset/checkout/filter/rewrite/delete/modify source.
- Destination is external, absent before Apply, outside source/worktrees/evidence, has no reparse/symlink/Git link, and is atomically promoted from a disposable sibling only after complete validation.
- `-WhatIf`, missing approval, declined confirmation, drift, or failed validation creates neither destination nor staging.
- Read only tracked regular blobs from the approved Git commit. Never read ignored/untracked Tenant 1 intent/state even when present.
- `TenantReplica` retains reusable source, `.github/workflows/validate-repository.yml`, `azure-pipelines.yml`, `infra/src/pipelines/templates/`, tests, current replacement runbooks, schemas, and synthetic examples after Plan 4.
- `TenantReplica` denies `.git`, history/remotes/hooks/config, every ignored/untracked file, Tenant 1 intent/state/backups/generated parameters, stable identifiers/private URLs/account selectors, approvals, raw/sanitized run evidence, provider outputs/artifacts/PAC profiles/authentication, and all tracked tenant transition/discovery payloads including Tenant 2 artifacts.
- `CustomerHandover` denies `.github/workflows`, evidence, transition payloads, private state, source history/publication configuration, and every artifact not explicitly retained by its stricter manifest.
- No wildcard replacement, broad customer-name replacement, unresolved marker, ambiguous binary/encoding/path, force, or skip-validation option.
- Evidence records counts/digests/statuses only; no source text, replacement value, tenant marker, private path, remote coordinate, token, or raw validation output.
- Fixtures contain synthetic IDs and reserved domains only. Each task ends with focused review and the standard Copilot co-author trailer.

## File and Interface Map

| Path | Responsibility |
|---|---|
| `infra/src/config/schemas/repository-export.schema.json` | Canonical explicit-profile manifest. |
| `infra/src/config/runbooks/tenant-replica.sample.json` | Synthetic `TenantReplica` policy example. |
| `infra/src/config/runbooks/customer-export.sample.json` | Existing strict customer sample, upgraded through compatibility. |
| `infra/src/scripts/runbooks/Test-RepositoryExport.ps1` | Profile-aware assessment and independent validation. |
| `infra/src/scripts/runbooks/New-RepositoryExportPlan.ps1` | Deterministic profile plan and execution manifest. |
| `infra/src/scripts/runbooks/Invoke-RepositoryExport.ps1` | Approval-bound local Apply. |
| Existing customer-named wrappers | Fixed `CustomerHandover` compatibility only. |
| `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/*RepositoryExport*.ps1` | Canonical manifest, assessment, transform, and validation interfaces. |
| `infra/tests/pester/RepositoryExportProfiles.Tests.ps1` | Profile/schema/compatibility/retention tests. |
| `infra/tests/pester/RepositoryExportIndependentValidation.Tests.ps1` | Complete expected-tree reconstruction and suite execution. |

Canonical manifest root fields are exactly `schemaVersion`, `profile`, `expectedSourceRepository`, `retainedPathRules`, `deniedPathRules`, `tenantArtifactRules`, `replacements`, `residualMarkers`, `sourceMarkerCatalog`, `residualDispositions`, `syntheticDataPolicy`, `fileClassifications`, `inspectableBinaries`, `validationSuites`, `profilePolicy`.

Path rules have exactly `id`, `kind`, `value`, `reason`; `kind` is `ExactPath` or `PathPrefix`, and `value` is a normalized repository-relative path with no glob metacharacter. `profilePolicy` has exactly `allowGitHubValidationWorkflow`, `allowAzurePipelineDefinitions`, `allowInternalTests`, `allowOperationalRunbooks`, `allowEvidence`, `allowTenantTransitionPayload`, `allowPublicationConfiguration`, all booleans fixed by profile tests.

---

### Task 1: Explicit Profile Schema and v1 Customer Compatibility

**Files:**
- Create: `infra/src/config/schemas/repository-export.schema.json`
- Create: `infra/src/config/runbooks/tenant-replica.sample.json`
- Modify: `infra/src/config/runbooks/customer-export.sample.json`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Import-RepositoryExportManifest.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/ConvertTo-CustomerHandoverManifest.ps1`
- Modify: `Import-CustomerExportManifest.ps1` and module export lists.
- Create: `infra/tests/pester/RepositoryExportProfiles.Tests.ps1`

**Interfaces:**
- Produces `Import-RepositoryExportManifest -Path <absolute> -ExpectedProfile <TenantReplica|CustomerHandover>`.
- Produces `ConvertTo-CustomerHandoverManifest -LegacyManifest <object>`, returning canonical schema `1.0` with explicit `profile: CustomerHandover`.
- Existing `Import-CustomerExportManifest -Path` remains callable and returns the canonical fixed customer profile.

- [ ] **Step 1: Write failing schema/compatibility tests**

Accept both explicit profiles, reject absent/unknown profile, unknown fields, wildcard paths/replacements, conflicting retain/deny rules, invalid profile-policy booleans, and duplicate IDs. Prove existing valid v1 customer fixtures map byte-deterministically to `CustomerHandover` and existing invalid fixtures still fail.

- [ ] **Step 2: Run RED**

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path @('infra/tests/pester/RepositoryExportProfiles.Tests.ps1','infra/tests/pester/CustomerExportManifest.Tests.ps1') -Output Detailed"
```

Expected: **FAIL** because the canonical schema/import/adapter do not exist.

- [ ] **Step 3: Implement minimum canonical import**

Validate duplicate JSON properties, UTF-8 without BOM, exact paths, closed fields, profile policy, and contradictory rules. Adapt only recognized v1 fields; set the fixed strict policy and never infer `TenantReplica`. Keep the old schema for historical input validation and the new schema as canonical output.

- [ ] **Step 4: Run GREEN**

Run the RED command under Windows PowerShell 5.1. Expected: **PASS**, including all existing customer manifest tests.

- [ ] **Step 5: Perform focused review**

Confirm no implicit profile in canonical entry points, no wildcard, no broad replacement, no weakening of old customer denials, and no source/private-value read during import.

- [ ] **Step 6: Commit**

```powershell
git add infra/src/config/schemas/repository-export.schema.json infra/src/config/runbooks/tenant-replica.sample.json infra/src/config/runbooks/customer-export.sample.json infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap infra/tests/pester/RepositoryExportProfiles.Tests.ps1
git commit -m "feat(export): add explicit repository profiles" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 2: Shared Profile-Aware Assessment and Deterministic Planning

**Files:**
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Get-RepositoryExportAssessment.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/New-RepositoryExportActionPlan.ps1`
- Modify: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Get-CustomerExportAssessment.ps1`
- Modify: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Get-CustomerExportSourceSnapshot.ps1`
- Modify: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Get-CustomerSourceMarkerCatalog.ps1`
- Modify: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Get-CustomerExportResidual.ps1`
- Modify: module export lists.
- Modify: `infra/tests/pester/RepositoryExportProfiles.Tests.ps1`
- Modify: `infra/tests/pester/CustomerRepositoryExport.Tests.ps1`
- Modify: `infra/tests/pester/CustomerExportIsolation.Tests.ps1`
- Modify: `infra/tests/pester/CustomerExportSanitization.Tests.ps1`

**Interfaces:**
- `Get-RepositoryExportAssessment -SourceRoot -ExpectedSourceCommit -DestinationRoot -Manifest -Profile -RepositoryIdentity -ToolIdentities -NativeCommandRunner`.
- `New-RepositoryExportActionPlan -Assessment -Manifest -RunId -EvidenceRoot -NowUtc`.
- Action IDs are exactly `snapshot-source`, `stage-committed-blobs`, `apply-exact-transformations`, `validate-profile`, `promote-destination`, `snapshot-source-post`, `validate-independent`.

- [ ] **Step 1: Write failing shared-engine tests**

Cover exact commit/remote, dirty/staged/untracked/conflicted/sparse/submodule source, destination exists/inside source/worktree, reparse/symlink, denied path, unresolved marker, binary/encoding ambiguity, deterministic plan/digest, and same core action order for both profiles.

- [ ] **Step 2: Run RED**

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path @('infra/tests/pester/RepositoryExportProfiles.Tests.ps1','infra/tests/pester/CustomerRepositoryExport.Tests.ps1','infra/tests/pester/CustomerExportIsolation.Tests.ps1') -Output Detailed"
```

Expected: **FAIL** because canonical assessment/planning functions are unavailable.

- [ ] **Step 3: Refactor minimally to one engine**

Wrap existing source snapshot, blob enumeration, marker catalogue, residual, and transform helpers. Resolve profile policy before path enumeration. Bind exact source snapshot, retain/deny/marker/replacement/profile/tool/destination digests into the Plan 1 execution manifest.

- [ ] **Step 4: Run GREEN**

Run the RED command. Expected: **PASS**, with all existing customer tests preserved.

- [ ] **Step 5: Perform focused review**

Confirm one engine, no working-tree file copy, no ignored file read, no destination patch, no source cleanup, and no compatibility branch that bypasses canonical validation.

- [ ] **Step 6: Commit**

```powershell
git add infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap infra/tests/pester/RepositoryExportProfiles.Tests.ps1 infra/tests/pester/CustomerRepositoryExport.Tests.ps1 infra/tests/pester/CustomerExportIsolation.Tests.ps1 infra/tests/pester/CustomerExportSanitization.Tests.ps1
git commit -m "refactor(export): share profile assessment and plan" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 3: TenantReplica Retain/Deny Map and No-Private-Identifier Policy

**Files:**
- Modify: `infra/src/config/runbooks/tenant-replica.sample.json`
- Create: `infra/tests/fixtures/runbooks/repository-export/tenant-replica-tree/`
- Create: `infra/tests/fixtures/runbooks/repository-export/prohibited-tree/`
- Modify: `infra/tests/pester/RepositoryExportProfiles.Tests.ps1`
- Modify: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Get-CustomerSourceMarkerCatalog.ps1`
- Modify: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Get-CustomerExportResidual.ps1`
- Modify: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Test-CustomerExportContent.ps1`

**Interfaces:**
- Consumes: canonical path rules and marker catalogue.
- Produces `TenantReplica` retained capability groups `ProductSource`, `InfrastructureSource`, `GitHubValidation`, `AzurePipeline`, `InfrastructureTests`, `HrTests`, `ReplacementRunbooks`, `Schemas`, `SyntheticExamples`.
- Produces denied artifact groups `GitMetadata`, `IgnoredOrUntracked`, `TenantPrivate`, `TenantStableIdentifier`, `TenantTransition`, `Evidence`, `ProviderOutput`, `Authentication`, `Publication`.

- [ ] **Step 1: Write failing positive/negative fixture tests**

Require retained reusable files and reject intent/state/backups, generated parameters, IDs/URLs/account selectors, approvals/evidence, transition manifests/discovery evidence (including Tenant 2), pipeline artifacts, PAC profiles, provider responses, `.git`, hooks/remotes, ambiguous markers, and unexpected files. Test reusable literal “Tenant 1” narrative separately from prohibited stable values.

- [ ] **Step 2: Run RED**

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path 'infra/tests/pester/RepositoryExportProfiles.Tests.ps1' -FullNameFilter '*TenantReplica retain and deny*' -Output Detailed"
```

Expected: **FAIL** because the complete map/fixtures do not exist.

- [ ] **Step 3: Implement exact capability and deny maps**

Use exact paths/path prefixes plus marker dispositions; never global text replacement. Exclude any ambiguous file. Permit a retained file with a source-tenant narrative only when marker policy proves no prohibited stable value remains.

- [ ] **Step 4: Run GREEN**

Run the RED command. Expected: **PASS** for the positive tree and exact blocked reasons for every prohibited fixture.

- [ ] **Step 5: Perform focused review**

Review the map against tracked repository paths. Confirm private files cannot enter through ignore state, no Tenant 2 transition file is retained, and reusable build capability is not silently removed.

- [ ] **Step 6: Commit**

```powershell
git add infra/src/config/runbooks/tenant-replica.sample.json infra/tests/fixtures/runbooks/repository-export infra/tests/pester/RepositoryExportProfiles.Tests.ps1 infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap
git commit -m "feat(export): define TenantReplica safety map" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 4: Three Profile-Aware Entry Points and Customer Wrapper Compatibility

**Files:**
- Create: `infra/src/scripts/runbooks/Test-RepositoryExport.ps1`
- Create: `infra/src/scripts/runbooks/New-RepositoryExportPlan.ps1`
- Create: `infra/src/scripts/runbooks/Invoke-RepositoryExport.ps1`
- Modify: `New-CustomerRepositoryExport.ps1`
- Modify: `Test-CustomerRepositoryExport.ps1`
- Modify: `infra/tests/pester/CustomerExportStaticSafety.Tests.ps1`
- Modify: `infra/tests/pester/RepositoryExportProfiles.Tests.ps1`

**Interfaces:**
- Public signatures:

```powershell
Test-RepositoryExport.ps1 `
  -RunId <guid> -EvidenceRoot <absolute> -SourceRoot <absolute> `
  -ExpectedSourceCommit <40-hex> -DestinationRoot <absolute> `
  -ManifestPath <absolute> -Profile <TenantReplica|CustomerHandover> `
  [-Independent]

New-RepositoryExportPlan.ps1 `
  -RunId <guid> -EvidenceRoot <absolute> -SourceRoot <absolute> `
  -ExpectedSourceCommit <40-hex> -DestinationRoot <absolute> `
  -ManifestPath <absolute> -Profile <TenantReplica|CustomerHandover>

Invoke-RepositoryExport.ps1 `
  -RunId <guid> -EvidenceRoot <absolute> -SourceRoot <absolute> `
  -ExpectedSourceCommit <40-hex> -DestinationRoot <absolute> `
  -ManifestPath <absolute> -Profile <TenantReplica|CustomerHandover> `
  -ExecutionManifestPath <absolute> -ApprovedDigest <64-hex> [-Apply]
```

All retain existing hidden injected runners and `NowUtc`.

- [ ] **Step 1: Write failing entry/wrapper/safety tests**

Require explicit profile on new scripts, exact digest/`ShouldProcess`, `-WhatIf`, no destination on refusal, no network executables/API modules, no `git init/remote/push`, and customer wrappers fixed to canonical `CustomerHandover`. Assert wrappers reject any attempt to supply/derive `TenantReplica`.

- [ ] **Step 2: Run RED**

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path @('infra/tests/pester/RepositoryExportProfiles.Tests.ps1','infra/tests/pester/CustomerExportStaticSafety.Tests.ps1','infra/tests/pester/CustomerRepositoryExport.Tests.ps1') -Output Detailed"
```

Expected: **FAIL** because new entry points are absent and wrappers do not use the canonical adapter.

- [ ] **Step 3: Implement thin scripts and fixed wrappers**

Call shared assessment/planning/apply functions only. `Invoke` copies approved committed blobs to disposable staging, applies exact in-memory transformations, validates, and atomically promotes. Compatibility wrappers explicitly construct/validate `CustomerHandover`; they never inspect content to choose a profile.

- [ ] **Step 4: Run GREEN**

Run the RED command. Expected: **PASS**, zero network calls, and all existing customer behavior preserved.

- [ ] **Step 5: Perform focused review**

Confirm no publication code, no hidden remote, no profile inference, no source write, no destination patch, no broad cleanup, and no force/skip flag.

- [ ] **Step 6: Commit**

```powershell
git add infra/src/scripts/runbooks infra/tests/pester/RepositoryExportProfiles.Tests.ps1 infra/tests/pester/CustomerExportStaticSafety.Tests.ps1 infra/tests/pester/CustomerRepositoryExport.Tests.ps1
git commit -m "feat(export): add profile-aware export entry points" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 5: Independent Full-Tree Reconstruction and Profile Suite Execution

**Files:**
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Test-RepositoryExportIndependent.ps1`
- Create: `infra/tests/pester/RepositoryExportIndependentValidation.Tests.ps1`
- Modify: module export lists and `Test-RepositoryExport.ps1`.

**Interfaces:**
- Produces:

```powershell
Test-RepositoryExportIndependent `
  -SourceRoot <absolute> -ExpectedSourceCommit <40-hex> `
  -DestinationRoot <absolute> -Manifest <object> `
  -Profile <TenantReplica|CustomerHandover> `
  -GitBlobReader <scriptblock> -ValidationRunner <scriptblock>
```

- Validation result fields are `profile`, `expectedFileCount`, `actualFileCount`, `contentTreeDigest`, `unexpectedPaths`, `missingPaths`, `mismatchedPaths`, `deniedFindings`, `suiteResults`, `sourceUnchanged`, `status`.

- [ ] **Step 1: Write failing independent-validation tests**

Cover complete byte reconstruction, added/missing/changed file, `.git`, reparse/symlink, denied marker/artifact, source pre/post mismatch, staging metadata distrust, failed suite, interrupted staging, existing destination, and customer omission of forbidden workflows/tests. Before Plan 4 merges, assert missing pipeline files produce an explicit pending prerequisite rather than a false pass.

- [ ] **Step 2: Run RED**

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path 'infra/tests/pester/RepositoryExportIndependentValidation.Tests.ps1' -Output Detailed"
```

Expected: **FAIL** because canonical independent validation is absent.

- [ ] **Step 3: Implement independent reconstruction**

Reread every expected blob from the approved commit, independently reapply canonical rules in memory, byte-compare all files, detect unexpected filesystem objects, rerun marker/deny policy, compare source snapshots, and execute only manifest-selected local suites through injected runners. Do not trust Apply logs or staging metadata.

- [ ] **Step 4: Run GREEN**

Run the RED command. Expected: **PASS** for synthetic complete trees and exact failure sets for every tamper case.

- [ ] **Step 5: Perform focused review**

Confirm validator independence, full-tree rather than sampled comparison, no provider access, no force/skip, no source read outside Git blobs, and explicit pending status for Plan 4 assets.

- [ ] **Step 6: Commit**

```powershell
git add infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap infra/src/scripts/runbooks/Test-RepositoryExport.ps1 infra/tests/pester/RepositoryExportIndependentValidation.Tests.ps1
git commit -m "feat(export): validate complete profile trees independently" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 6: Post-Plan-4 TenantReplica Acceptance, Documentation, and Full Verification

**Files:**
- Modify: `infra/tests/pester/RepositoryExportProfiles.Tests.ps1`
- Modify: `infra/tests/pester/RepositoryExportIndependentValidation.Tests.ps1`
- Modify: `infra/docs/runbooks/03-customer-handover.md`
- Modify: `infra/docs/runbooks/README.md`
- Modify: `infra/docs/18-multi-tenant-provisioning.md`
- Modify: `infra/docs/README.md`
- Modify: `infra/README.md`
- Modify: `infra/tests/pester/RunbookDocumentation.Tests.ps1`

**Interfaces:**
- Consumes: merged Plan 4 `azure-pipelines.yml` and `infra/src/pipelines/templates/`.
- Produces: local synthetic `TenantReplica` acceptance including pipeline-template validation; no real export, remote, or Tenant 2 action.

- [ ] **Step 1: Write the failing final retained-tree/documentation tests**

Require retention and staged-tree validation of root YAML/templates, GitHub validation workflow, infrastructure/HR tests, replacement runbooks, schemas, and synthetic examples; require exclusion of all private/transition/evidence artifacts. Require docs to state exact profiles, compatibility behavior, no publication, and later Tenant 2 private-intent ownership without authorizing it.

- [ ] **Step 2: Run RED**

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path @('infra/tests/pester/RepositoryExportProfiles.Tests.ps1','infra/tests/pester/RepositoryExportIndependentValidation.Tests.ps1','infra/tests/pester/RunbookDocumentation.Tests.ps1') -Output Detailed"
```

Expected: **FAIL** until Plan 4 assets are merged and the final retained-tree suite/docs are wired. **STOP** if Plan 4 is not on current `main`.

- [ ] **Step 3: Complete final local synthetic acceptance and docs**

Rebase onto green current `main`, bind the exact new pipeline/template paths into `TenantReplica`, run the retained-tree suites in a temporary external destination, and update owning catalogues. Do not execute an export containing private state and do not publish.

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

Expected: all tests/validators/builds **PASS**, the local synthetic replica validates completely, GitHub workflows are unchanged, and no remote/provider operation occurs. Repeat focused profile tests under reviewed PowerShell 7.

- [ ] **Step 5: Perform focused review**

Map every design acceptance criterion to tests/docs. Scan for placeholder rules, implicit profile, private/transition/evidence leakage, wildcard/global replacement, remote commands, Tenant 2 live steps, source mutation, skip/force flags, and duplicated engine logic.

- [ ] **Step 6: Commit**

```powershell
git add infra/src/config/runbooks/tenant-replica.sample.json infra/tests/pester infra/docs infra/README.md
git commit -m "docs(export): publish profile-based handover runbook" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

## Completion Gate

Plan 5 is complete only when corrected Plan 1 and Plan 4 assets are present, both profiles are explicit and independently validated, all old customer tests pass, the complete synthetic `TenantReplica` retains required pipeline/source/test/runbook capability, synthetic canonical `TenantReplica` stage-result emission passes, no private identifier/state/evidence/transition artifact survives, source snapshots match, and no remote, provider, publication, or Tenant 2 operation occurs.
