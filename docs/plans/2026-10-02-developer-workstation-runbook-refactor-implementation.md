# Developer Workstation Runbook Refactor Implementation Plan

| Field | Value |
|---|---|
| **Version** | 1.3 |
| **Date** | 2026-10-27 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Draft |
| **Scope** | Windows 11 workstation assessment, initialization, private-boundary readiness, and restart-safe local evidence |
| **References** | [Approved Developer Workstation Runbook Refactor Design](../specs/2026-10-02-developer-workstation-runbook-refactor-design.md), [Approved Coordinate-Only Simplification Design](../specs/2026-10-03-tenant-lifecycle-coordinate-only-simplification-design.md), [Coordinate-Only Correction Plan](2026-10-03-tenant-lifecycle-coordinate-only-correction-implementation.md), [Tenant Lifecycle Core Plan](2026-10-02-tenant-lifecycle-core-implementation.md), [Current Developer Workstation Runbook](../../infra/docs/runbooks/01-developer-workstation.md) |

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor the existing Windows 11 workstation runbook into an exact-version, current-user-safe, restart-safe prerequisite subsystem that validates local Tenant 1 intent/state backup and restore without authenticating or calling a provider.

**Architecture:** Revise the existing policy, schemas, assessment script, and initialization script in place; do not create a second workstation engine. A first task records exact supported tool versions from current first-party capability evidence and fails closed when support cannot be proven. The subsystem consumes Plan 1 lifecycle contracts, writes atomic evidence below the shared run root, and treats restart, machine, source, policy, tool, private-boundary, and approval drift as invalidation.

**Tech Stack:** Windows 11, Windows PowerShell 5.1 (authoritative), Pester 5.7.1, reviewed PowerShell 7, Git, WinGet, GitHub CLI, Azure CLI/Bicep, Azure DevOps CLI extension, PAC CLI, JSON Schema draft 2020-12, and `Caldova.HrFrontier.Bootstrap`.

**Spec:** [`docs/specs/2026-10-02-developer-workstation-runbook-refactor-design.md`](../specs/2026-10-02-developer-workstation-runbook-refactor-design.md)

## 2026-10-03 Coordinate-Only Dependency Amendment

This child plan remains `Draft` and cannot begin until the [coordinate-only correction](2026-10-03-tenant-lifecycle-coordinate-only-correction-implementation.md) is merged and then-current `main` is green.

- `Test-DeveloperWorkstation.ps1` and `Initialize-DeveloperWorkstation.ps1` own the complete `Workstation` and `PrivateBoundary` child lifecycle: child assessment, child execution manifest, child `approvals.json`, child `-WhatIf`, child `-Apply`, child `ShouldProcess`, local read-back, restart handling, private-boundary proof, terminal child summary, and canonical stage result.
- Existing `ExecutionManifestPath`, `ApprovedDigest`, and `Apply` parameters remain child parameters on `Initialize-DeveloperWorkstation.ps1`; they are not inputs to `Invoke-TenantLifecycle.ps1`.
- After terminal child read-back or confirmed `NoChange`, the child writes the immutable canonical result at `<run>/stage-results/<stage>.json` through the corrected shared helper. The result exposes only stage-level status, classification, provenance, and child artifact digests.
- Any reference below to Plan 1 approval, action, state, or read-back contracts means retained shared child-library contracts. It does not create a dependency on umbrella Apply, umbrella `ApprovedDigest`, `CurrentBindingProvider`, umbrella action evidence, or umbrella resource-level correlation.
- Umbrella `Assess` or `Plan` may dispatch this child only in the matching non-mutating mode. Umbrella `Verify` never invokes it and accepts only exact canonical `Passed` stage results.

## Global Constraints

- This is Plan 2. Do not begin until Plan 1 is merged, then-current `main` is green, and its lifecycle schemas/functions are available.
- At execution time, use `superpowers:using-git-worktrees`. Create branch `feat/developer-workstation-runbook-refactor` in the sibling `Source\<repository-context>\wt\ws-refactor` location required by the current instructions and Approved workstation specification. Use the current-user write/delete probe and prove the longest checkout path is **less than 240 characters**. Never enable `core.longpaths`, change ACLs, self-elevate, or relocate a profile.
- Windows PowerShell 5.1 with Pester 5.7.1 is authoritative. The exact reviewed PowerShell 7 version selected in Task 1 is the compatibility host; both hosts must pass focused tests.
- Do not authenticate, inspect a provider context, call a provider API, install an Azure DevOps organization extension, create an identity, or mutate cloud/tenant/pipeline state.
- Reuse `Test-DeveloperWorkstation.ps1`, `Initialize-DeveloperWorkstation.ps1`, the current policy/schema, Plan 1 lifecycle contracts, existing `ShouldProcess`, and injected-runner patterns. No broad rewrite.
- Do not reactivate or edit the stopped cloud entry points. A local success never implies cloud readiness.
- Every delivery-critical tool uses an exact version or a finite exact allowlist selected by Task 1. `Present` is prohibited for Windows PowerShell, reviewed PowerShell 7, Git, GitHub CLI, Azure CLI, Bicep, Azure DevOps CLI extension, PAC CLI, and Pester.
- Resolve every executable to exactly one canonical physical path and SHA-256. Zero or multiple matches, parser failure, changed file/version/source, or an unreviewed architecture is `Blocked`; never select the first match.
- Assessment performs no install, authentication, provider call, persistent configuration, source edit, working-tree cleanup, or private-value serialization.
- Apply requires explicit `-Apply`, fresh exact approval, per-action `ShouldProcess`, an allowlisted action, immediate post-read, and standard-user operation. Elevation, license acceptance, interactive installer UI, and restart remain `Manual`.
- Private intent/state remain ignored and untracked. Validate only path, ownership, schema, backup/restore predicates, and equality booleans; do not serialize values or private-content hashes.
- A restart invalidates the active manifest and approval. Continue only through a full new assessment and new digest; never resume an old action cursor.
- Use exact evidence filenames from Plan 1. Workstation-specific records live within `assessment.json`, `actions/*.json`, `read-back.json`, and `summary.json`, not ad hoc committed reports.
- No real IDs, URLs, usernames, paths, tenant values, credentials, or raw native output in fixtures.
- Each task ends with focused review and a commit using `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>`.

## File and Interface Map

| Path | Responsibility |
|---|---|
| `infra/src/config/runbooks/workstation-prerequisites.json` | Closed exact-version and exact-action policy, revised in place. |
| `infra/src/config/schemas/workstation-prerequisites.schema.json` | Policy schema with exact/allowlist modes and capability records. |
| `infra/src/config/schemas/workstation-compatibility.schema.json` | Current first-party support decision record. |
| `infra/src/config/runbooks/workstation-compatibility.json` | Reviewed exact supported values selected by Task 1. |
| `infra/src/scripts/runbooks/Test-DeveloperWorkstationCompatibility.ps1` | Read-only, unauthenticated capability preflight. |
| `infra/src/scripts/runbooks/Test-DeveloperWorkstation.ps1` | Read-only local assessment and evidence. |
| `infra/src/scripts/runbooks/Initialize-DeveloperWorkstation.ps1` | Plan/approval/Apply/read-back through existing `ShouldProcess`. |
| `infra/tests/pester/WorkstationCompatibility.Tests.ps1` | Exact-version and capability policy tests. |
| Existing workstation Pester files | Assessment, Apply, drift, restart, and static-safety coverage. |

The compatibility record fields are exactly `schemaVersion`, `reviewedAtUtc`, `reviewedByRole`, `components`, and `digest`. Each component has `id`, `exactVersions`, `host`, `architecture`, `installationSource`, `versionCommand`, `capabilityChecks`, and `firstPartyReferences`. `exactVersions` has one or more full versions and no range/wildcard.

The revised public signatures are:

```powershell
Test-DeveloperWorkstation.ps1 `
  -RunId <guid> -EvidenceRoot <absolute> -PolicyPath <absolute> `
  -CompatibilityPath <absolute> -RepositoryRoot <absolute> `
  -ExpectedSourceCommit <40-hex> -RepositoryIdentity <64-hex> -ExpectedMachineId <string> `
  -WorktreeRoot <absolute> -TenantConfigurationPath <absolute> `
  -TenantStatePath <absolute> -BackupManifestPath <absolute>

Initialize-DeveloperWorkstation.ps1 `
  -RunId <guid> -EvidenceRoot <absolute> -PolicyPath <absolute> `
  -CompatibilityPath <absolute> -RepositoryRoot <absolute> `
  -ExpectedSourceCommit <40-hex> -RepositoryIdentity <64-hex> -ExpectedMachineId <string> `
  -WorktreeRoot <absolute> -TenantConfigurationPath <absolute> `
  -TenantStatePath <absolute> -BackupManifestPath <absolute> `
  -ExecutionManifestPath <absolute> -ApprovedDigest <64-hex> [-Apply]
```

Existing hidden test seams remain: `NativeCommandRunner`, `CommandResolver`, `FileIdentityProvider`, `PlatformProbe`, `InteractiveHostProbe`, `AssessmentProvider`, `SummaryWriter`, and `NowUtc`.

`RepositoryIdentity` is the caller-reviewed expected complete Git remote-inventory
digest. It supplies the independent expected remote required by specification
section 7; assessment must not infer it from the source it is verifying.

## Task 1 Technical Implementation Checkpoint

Task 1 is implemented locally through `836e4446d0ab64c1a7e150c79d365a1604c310e7`, following the sprint-only Code App scope correction `af31fb0`. The canonical compatibility record has the declared five root and eight component fields and a stored, verified digest. Exact runtime versions, trusted executable/Store/Pester payload identities, closed raw JSON contracts, and meaningful two-component non-Code-App package preservation are enforced before technical acceptance. Automated technical review is explicitly not human approval.

Review corrections prevent untrusted alias execution and Pester import, reject duplicate/scalar contract substitutions, and keep unreviewed WinGet package/runtime mappings Manual and non-executable. GitHub CLI `2.103.3` was adopted only after a separate signed-file/publisher-release/version/help/hash review; no installer was run. Caller-relative file paths now resolve once against PowerShell's FileSystem location so hashing and reading use the same inputs.

The final focused related suites passed 150 cases on each of Windows PowerShell 5.1 and reviewed PowerShell 7.6.8; documentation passed 232 cases. Controller checks independently passed the prior 138-case set and the final 12 path regressions on both hosts. Actual absolute and corrected relative default preflights returned `NoChange` for nine components with the four native PAC operations, preserving both declared Web Resources, references, and payloads.

This is local tool compatibility, not child-stage, machine, backup, provider, import, or human acceptance. Tasks 2-7 remain incomplete and the plan remains Draft. No live Apply, installation, authentication, provider action, or source publication was performed. Continue with Task 2 under the current sibling-worktree rule and explicit expected repository identity.

---

### Task 1: Fail-Closed Tool-Version and Capability Preflight

**Files:**
- Create: `infra/src/config/schemas/workstation-compatibility.schema.json`
- Create: `infra/src/config/runbooks/workstation-compatibility.json`
- Create: `infra/src/scripts/runbooks/Test-DeveloperWorkstationCompatibility.ps1`
- Create: `infra/tests/pester/WorkstationCompatibility.Tests.ps1`
- Modify: `infra/src/config/runbooks/workstation-prerequisites.json`
- Modify: `infra/src/config/schemas/workstation-prerequisites.schema.json`

**Interfaces:**
- Consumes: installed command help/version output and reviewed first-party references; no authenticated endpoint.
- Produces: `Test-DeveloperWorkstationCompatibility.ps1 -CompatibilityPath -PolicyPath -ReportPath -CommandResolver -NativeCommandRunner -NowUtc`.
- Produces exact reviewed versions for `PowerShell7`, `WindowsPowerShell`, `Git`, `GitHubCli`, `AzureCli`, `Bicep`, `azure-devops`, `PowerPlatformCli`, and `Pester`.

- [x] **Step 1: Write failing preflight tests**

Require exact versions, full semver where the product exposes semver, nonempty first-party references, host/architecture, and capability checks. Include PAC pack/unpack/help parsing, Bicep build help, Azure DevOps extension version, and PowerShell 7 Windows compatibility. Cover a meaningful non-Code-App component round trip, refusal of out-of-scope Code App delivery input, and rejection of empty or missing-source input as capability proof. Assert any unproven applicable component returns `Blocked` and prevents policy acceptance.

- [x] **Step 2: Run RED**

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path 'infra/tests/pester/WorkstationCompatibility.Tests.ps1' -Output Detailed"
```

Expected: **FAIL** because the compatibility schema, record, and preflight do not exist and current delivery tools still use `Present`.

- [x] **Step 3: Perform and record the minimum support decision**

From the execution worktree, inspect current first-party release/support pages and unauthenticated installed command output. Record only values whose applicable capability checks pass; keep raw machine output in external preflight evidence. The [approved sprint scope](../specs/2026-10-02-developer-workstation-runbook-refactor-design.md#6-version-and-tool-policy) excludes the legacy HR control-plane Code App and its specific `BackgroundImageUri` pack/unpack case, not PAC or generic Power Platform delivery. Preserve the historical limitation without claiming it fixed.

Prove the remaining PAC pack/unpack capability with a reviewed, meaningful non-Code-App fixture containing at least one actual declared component. Verify that the declared component, its references, and associated payload survive the round trip without loss. The current empty, pre-Code-App HR snapshot cannot supply that proof. Report and refuse any out-of-scope Code App in future delivery input against the declared scope; never silently strip it or waive another in-scope component.

If any applicable capability cannot be proven, including PAC round-trip support, record the component as `Blocked` in external preflight evidence and **stop this plan without inventing a version**. Missing source or component loss remains blocking. Once all nine delivery-critical tool values and their applicable capabilities are reviewed, commit full exact versions/finite allowlists to `workstation-compatibility.json` and reference them from the prerequisite policy; remove delivery-critical `Present` modes.

- [x] **Step 4: Run GREEN**

Run the RED command and:

```powershell
& powershell.exe -NoProfile -File infra/src/scripts/runbooks/Test-DeveloperWorkstationCompatibility.ps1 `
  -CompatibilityPath infra/src/config/runbooks/workstation-compatibility.json `
  -PolicyPath infra/src/config/runbooks/workstation-prerequisites.json `
  -ReportPath (Join-Path $env:TEMP 'caldova-workstation-compatibility')
```

Expected: Pester **PASS** and preflight returns `NoChange` only when every exact value and capability is proven; otherwise it fails closed with `Blocked` and no policy mutation.

- [x] **Step 5: Perform focused review**

Review source ownership, release dates, exact values, capability evidence, and parser behavior. Confirm no guessed version, floating major, wildcard, `latest`, `Present`, authentication, install, or provider call.

- [x] **Step 6: Commit**

```powershell
git add infra/src/config/runbooks/workstation-prerequisites.json infra/src/config/runbooks/workstation-compatibility.json infra/src/config/schemas/workstation-prerequisites.schema.json infra/src/config/schemas/workstation-compatibility.schema.json infra/src/scripts/runbooks/Test-DeveloperWorkstationCompatibility.ps1 infra/tests/pester/WorkstationCompatibility.Tests.ps1
git commit -m "feat(workstation): pin supported delivery tools" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 2: Current-User Worktree, Repository, and 240-Character Budget Assessment

**Files:**
- Modify: `infra/src/scripts/runbooks/Test-DeveloperWorkstation.ps1`
- Modify: `infra/tests/pester/DeveloperWorkstationAssessment.Tests.ps1`
- Modify: `infra/tests/pester/RunbookStaticSafety.Tests.ps1`

**Interfaces:**
- Consumes: Task 1 exact identities and Plan 1 evidence contracts.
- Produces assessment components `worktreeAccess`, `pathBudget`, `repositorySource`, `repositoryCleanliness`, and `toolIdentities`.
- `pathBudget` fields are `worktreeRootLength`, `longestTrackedRelativePath`, `longestCheckoutPathLength`, `maximumExclusive`, and `classification`; `maximumExclusive` is exactly `240`.

- [ ] **Step 1: Write failing assessment tests**

Cover missing `LocalApplicationData`, failed create/write/delete probe, path length 239/240, dirty/conflicted/sparse checkout, remote mismatch, SHA mismatch, duplicate executable resolution, changed hash/version, private file accidentally tracked, and a valid `%LOCALAPPDATA%\CaldovaHR\wt\caldova-hr-frontier\ws-refactor` fixture.

- [ ] **Step 2: Run RED**

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path @('infra/tests/pester/DeveloperWorkstationAssessment.Tests.ps1','infra/tests/pester/RunbookStaticSafety.Tests.ps1') -Output Detailed"
```

Expected: **FAIL** because the current script does not expose the required run/worktree/source/private-boundary contract.

- [ ] **Step 3: Extend assessment minimally**

Add the revised signature and retain hidden seams. Probe the exact worktree root as the current user, enumerate tracked paths with `git -c core.quotepath=false ls-files`, compute the longest checkout path, require `< 240`, and remove only the unique probe created by this run. Use exact Git remote/SHA/status/sparse checks. Resolve tools without `Select-Object -First 1`.

- [ ] **Step 4: Run GREEN**

Run the RED command. Expected: **PASS**; all blocked cases make no write except external evidence and the deleted access probe.

- [ ] **Step 5: Perform focused review**

Confirm no ACL edit, no `core.longpaths`, no profile move, no source cleanup, no broad temp deletion, no first match, and no private path/value in evidence.

- [ ] **Step 6: Commit**

```powershell
git add infra/src/scripts/runbooks/Test-DeveloperWorkstation.ps1 infra/tests/pester/DeveloperWorkstationAssessment.Tests.ps1 infra/tests/pester/RunbookStaticSafety.Tests.ps1
git commit -m "feat(workstation): enforce external worktree budget" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 3: Private Intent/State Validation and Backup/Restore Gates

**Files:**
- Create: `infra/src/config/schemas/private-backup-manifest.schema.json`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Test-TenantPrivateBackup.ps1`
- Modify: bootstrap module export lists.
- Modify: `infra/src/scripts/runbooks/Test-DeveloperWorkstation.ps1`
- Modify: `infra/tests/pester/DeveloperWorkstationAssessment.Tests.ps1`
- Create: `infra/tests/fixtures/runbooks/private-backup-manifest.synthetic.json`

**Interfaces:**
- Consumes: Plan 1 `Test-TenantLifecyclePrivateBoundary`.
- Produces: `Test-TenantPrivateBackup -IntentPath -StatePath -BackupManifestPath -RestoreRoot -DecryptAndReadRunner -NowUtc`.
- Backup manifest fields are exactly `schemaVersion`, `publicTenantKey`, `createdAtUtc`, `encryptionProvider`, `containerLabel`, `intentEntry`, `stateEntry`, `restoreTest`; entry fields are `logicalName`, `included`, `encrypted`; restore fields are `testedAtUtc`, `separateRoot`, `intentEqual`, `stateEqual`, `result`.

- [ ] **Step 1: Write failing backup/restore tests**

Test plaintext backup refusal, source-path restore, missing entry, wrong tenant key, restore root inside Git, unequal restored bytes, stale/failed restore test, raw content/hash leakage, and successful equality booleans through an injected decrypt/read runner.

- [ ] **Step 2: Run RED**

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path 'infra/tests/pester/DeveloperWorkstationAssessment.Tests.ps1' -FullNameFilter '*private backup and restore*' -Output Detailed"
```

Expected: **FAIL** because the backup schema/function and assessment gate do not exist.

- [ ] **Step 3: Implement the local-only gate**

Validate that backup creation is attended and external, both files are encrypted entries, and restore proof comes from a separate external root. Compare bytes in memory via the injected runner and persist only booleans plus non-sensitive labels. Never create, encrypt, decrypt, copy, or restore a private file in assessment.

- [ ] **Step 4: Run GREEN**

Run the RED command. Expected: **PASS** with no private value, digest, or absolute restore path in evidence.

- [ ] **Step 5: Perform focused review**

Confirm assessment cannot manufacture backup evidence, cannot infer Tenant 1 values, and blocks until both encrypted backup and separate equality proof exist.

- [ ] **Step 6: Commit**

```powershell
git add infra/src/config/schemas/private-backup-manifest.schema.json infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap infra/src/scripts/runbooks/Test-DeveloperWorkstation.ps1 infra/tests/pester/DeveloperWorkstationAssessment.Tests.ps1 infra/tests/fixtures/runbooks/private-backup-manifest.synthetic.json
git commit -m "feat(workstation): gate private backup and restore" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 4: Deterministic Workstation Plan and Shared Manifest

**Files:**
- Modify: `infra/src/scripts/runbooks/Initialize-DeveloperWorkstation.ps1`
- Modify: `infra/tests/pester/DeveloperWorkstationInitialization.Tests.ps1`
- Modify: `infra/tests/pester/WorkstationPrerequisitePolicy.Tests.ps1`

**Interfaces:**
- Consumes: current assessment, Task 1 policy, Plan 1 `New-TenantLifecycleExecutionManifest`.
- Produces exact actions `WinGetInstallExact`, `InstallPesterExact`, `InstallBicepComponent`, `InstallAzureCliExtensionExact`, and `InstallVsCodeExtensionExact`; each has prerequisite IDs, exact executable/package/source/scope, expected restart, and exact postcondition.

- [ ] **Step 1: Write failing planning tests**

Assert deterministic action order/digest, complete machine/source/policy/compatibility/private-boundary bindings, no action for `VerifyOnly` or `Manual`, no elevation-required automatic action, 30-minute maximum expiry, and no manifest when assessment contains `Blocked` or `Refused`.

- [ ] **Step 2: Run RED**

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path @('infra/tests/pester/DeveloperWorkstationInitialization.Tests.ps1','infra/tests/pester/WorkstationPrerequisitePolicy.Tests.ps1') -FullNameFilter '*execution manifest*','*deterministic*' -Output Detailed"
```

Expected: **FAIL** because initialization still emits the older manifest shape.

- [ ] **Step 3: Implement minimal Plan mode**

Keep default behavior non-mutating. Convert assessment differences to exact allowlisted actions and call the Plan 1 manifest constructor. Bind policy and compatibility digests as prerequisite records. Emit `execution-manifest.json`; approval remains a separate human-authored `approvals.json`.

- [ ] **Step 4: Run GREEN**

Run the RED command. Expected: **PASS** and byte-identical manifests for equivalent fixed-time inputs.

- [ ] **Step 5: Perform focused review**

Confirm no implicit acceptance, no summary-only approval, no package/version drift, no automatic action requiring machine elevation, and no authentication method execution.

- [ ] **Step 6: Commit**

```powershell
git add infra/src/scripts/runbooks/Initialize-DeveloperWorkstation.ps1 infra/tests/pester/DeveloperWorkstationInitialization.Tests.ps1 infra/tests/pester/WorkstationPrerequisitePolicy.Tests.ps1
git commit -m "feat(workstation): bind exact initialization plan" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 5: Apply, Exact Read-Back, Atomic Evidence, and Restart Invalidation

**Files:**
- Modify: `infra/src/scripts/runbooks/Initialize-DeveloperWorkstation.ps1`
- Modify: `infra/tests/pester/DeveloperWorkstationInitialization.Tests.ps1`
- Modify: `infra/tests/pester/EvidenceSecurity.Tests.ps1`

**Interfaces:**
- Consumes: Plan 1 approval validator/writer and Task 4 actions.
- Produces one `actions/<ordered-action-id>.json` per attempted action and workstation data in `read-back.json`/`summary.json`.
- Session binding fields are exactly `bootTimeUtc`, `processSessionId`, `machineId`, and `userId`.

- [ ] **Step 1: Write failing Apply/restart tests**

Cover missing `-Apply`, `-WhatIf`, declined confirmation, expired approval, reboot-time drift, process-session drift after partial completion, tool/source/policy drift, native failure, post-read mismatch, atomic evidence interruption, completed-action adoption after reassessment, and second-run `NoChange`.

- [ ] **Step 2: Run RED**

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path @('infra/tests/pester/DeveloperWorkstationInitialization.Tests.ps1','infra/tests/pester/EvidenceSecurity.Tests.ps1') -Output Detailed"
```

Expected: **FAIL** because restart/session binding and Plan 1 action envelopes are not integrated.

- [ ] **Step 3: Implement minimal safe Apply**

Reassess all bindings before each action, call `ShouldProcess`, invoke only the policy's exact path/arguments, immediately resolve and fingerprint the postcondition, then atomically write the envelope. On restart or partial failure, preserve completed evidence, mark remaining actions not attempted, invalidate approval, and require a new assessment/manifest.

- [ ] **Step 4: Run GREEN**

Run the RED command. Expected: **PASS**, with zero native mutation in refusal/`-WhatIf`/drift cases and no stale resume.

- [ ] **Step 5: Perform focused review**

Inspect every native call. Confirm no shell-string interpolation, hidden acceptance flag, broad PATH edit, automatic uninstall/rollback, source edit, cloud auth, or evidence overwrite.

- [ ] **Step 6: Commit**

```powershell
git add infra/src/scripts/runbooks/Initialize-DeveloperWorkstation.ps1 infra/tests/pester/DeveloperWorkstationInitialization.Tests.ps1 infra/tests/pester/EvidenceSecurity.Tests.ps1
git commit -m "feat(workstation): make apply restart safe" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 6: Windows PowerShell 5.1 and Reviewed PowerShell 7 Compatibility

**Files:**
- Modify: workstation scripts and bootstrap helpers only where focused tests prove incompatibility.
- Modify: `infra/tests/pester/DeveloperWorkstationAssessment.Tests.ps1`
- Modify: `infra/tests/pester/DeveloperWorkstationInitialization.Tests.ps1`
- Modify: `infra/tests/pester/WorkstationCompatibility.Tests.ps1`

**Interfaces:**
- Consumes: exact Task 1 PowerShell 7 value.
- Produces identical canonical evidence and classifications under Windows PowerShell 5.1 and that reviewed PowerShell 7 version.

- [ ] **Step 1: Add failing cross-host golden tests**

Run the same synthetic policy/assessment/plan fixtures under both hosts and byte-compare canonical outputs. Add cases for native stderr, `$LASTEXITCODE`, UTF-8 without BOM, path casing, JSON depth, and array ordering.

- [ ] **Step 2: Run RED**

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path @('infra/tests/pester/DeveloperWorkstationAssessment.Tests.ps1','infra/tests/pester/DeveloperWorkstationInitialization.Tests.ps1','infra/tests/pester/WorkstationCompatibility.Tests.ps1') -Output Detailed"
pwsh.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path @('infra/tests/pester/DeveloperWorkstationAssessment.Tests.ps1','infra/tests/pester/DeveloperWorkstationInitialization.Tests.ps1','infra/tests/pester/WorkstationCompatibility.Tests.ps1') -Output Detailed"
```

Expected: at least one new golden/compatibility assertion **FAILS** before normalization.

- [ ] **Step 3: Implement only proven compatibility fixes**

Normalize native result objects, encoding, path comparison, and canonical JSON at existing seams. Do not fork business behavior by host. If a reviewed PowerShell 7 host cannot satisfy the same contract, stop and amend the design instead of weakening Windows PowerShell 5.1 authority.

- [ ] **Step 4: Run GREEN**

Run both RED commands. Expected: both **PASS** with byte-identical golden output.

- [ ] **Step 5: Perform focused review**

Confirm host-neutral behavior, no PowerShell 7-only syntax in authoritative paths, and no compatibility shim that bypasses a safety check.

- [ ] **Step 6: Commit**

```powershell
git add infra/src/scripts infra/tests/pester
git commit -m "test(workstation): prove supported PowerShell hosts" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 7: Runbook Documentation and Final Local Verification

**Files:**
- Modify: `infra/docs/runbooks/01-developer-workstation.md`
- Modify: `infra/docs/runbooks/README.md`
- Modify: `infra/docs/README.md`
- Modify: `infra/README.md`
- Modify: `infra/tests/pester/RunbookDocumentation.Tests.ps1`

**Interfaces:**
- Consumes: Tasks 1-6.
- Produces: current local operator documentation with no cloud-auth or provider-call step.

- [ ] **Step 1: Write failing documentation tests**

Require the exact script signatures, compatibility record, worktree convention, `<240` budget, first/second run, restart invalidation, private backup/restore predicates, evidence names, Windows PowerShell 5.1 authority, reviewed PowerShell 7 version, and explicit “no cloud authentication or provider calls.”

- [ ] **Step 2: Run RED**

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path 'infra/tests/pester/RunbookDocumentation.Tests.ps1' -Output Detailed"
```

Expected: **FAIL** because current documentation reflects the older policy and evidence contract.

- [ ] **Step 3: Rewrite the workstation runbook and catalogue rows**

Document assessment, plan, digest review, `-WhatIf`, Apply, restart, reassessment, second `NoChange`, private restore gate, exact non-goals, and troubleshooting that fails closed. Update each owning catalogue touched by the runbook.

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

Expected: all tests/validators/builds **PASS**, GitHub workflows are unchanged, no provider call occurs, and only reviewed Plan 2 files are modified. Repeat the focused workstation suites with the exact reviewed PowerShell 7 host.

- [ ] **Step 5: Perform focused review**

Compare every design acceptance criterion to a test/documented step. Scan for floating versions, placeholders, first-match selection, cloud commands, auth, credentials, self-elevation, stale resume, source cleanup, and silent stop-stub changes.

- [ ] **Step 6: Commit**

```powershell
git add infra/docs infra/README.md infra/tests/pester/RunbookDocumentation.Tests.ps1
git commit -m "docs(workstation): publish exact restart-safe runbook" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

## Completion Gate

Plan 2 is complete only when the corrected Plan 1 contracts remain green, exact supported versions are recorded from reviewed evidence, both PowerShell hosts pass, first and second synthetic child runs behave correctly, restart requires new child approval, private backup/restore is proven without value leakage, synthetic exact `Workstation` and `PrivateBoundary` stage-result emission passes, and no cloud authentication or provider call occurs.
