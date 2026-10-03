# Power Platform DEV Delivery Implementation Plan

| Field | Value |
|---|---|
| **Version** | 1.1 |
| **Date** | 2026-10-03 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Draft |
| **Scope** | Azure Pipeline and HR solution pack, check, publish, WIF import, attended application-user checkpoint, and DEV read-back |
| **References** | [Approved Cloud Service Foundation Runbook Design](../specs/2026-10-02-cloud-service-foundation-runbook-design.md), [Approved Coordinate-Only Simplification Design](../specs/2026-10-03-tenant-lifecycle-coordinate-only-simplification-design.md), [Coordinate-Only Correction Plan](2026-10-03-tenant-lifecycle-coordinate-only-correction-implementation.md), [Cloud Service Foundation Core Plan](2026-10-02-cloud-service-foundation-core-implementation.md), [HR Solution Sources](../../hr/src/solutions/README.md), [Power Platform Environments and ALM](../../infra/docs/12-power-platform-environments-and-alm.md) |

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a manually queued Azure Pipeline and reusable Power Platform Build Tools 2.0 templates that pack/check/publish the committed HR solution once, import the byte-identical artifact to DEV through WIF, and produce exact provenance/read-back contracts without live execution.

**Architecture:** A thin root `azure-pipelines.yml` delegates build/check/publish, DEV deployment, and sanitized evidence to focused templates. The existing HR solution module gains pack, package-validation, provenance, and guarded DEV import functions with injected native runners. The cloud core supplies exact Azure DevOps protected resources and WIF metadata; application-user creation/role assignment remains an attended administrator checkpoint followed by independent read-back.

**Tech Stack:** Azure Pipelines YAML, Power Platform Build Tools 2.0 tasks, workload identity federation, Windows PowerShell 5.1 (authoritative), Pester 5.7.1, reviewed PowerShell 7 compatibility, PAC CLI at the exact reviewed version, SHA-256, JSON Schema draft 2020-12, and `Caldova.HrFrontier.Solutions`.

**Spec:** [`docs/specs/2026-10-02-cloud-service-foundation-runbook-design.md`](../specs/2026-10-02-cloud-service-foundation-runbook-design.md)

## 2026-10-03 Coordinate-Only Dependency Amendment

This child plan remains `Draft` and cannot begin until the [coordinate-only correction](2026-10-03-tenant-lifecycle-coordinate-only-correction-implementation.md) and corrected Plans 1-3 are merged and then-current `main` is green.

- The DEV-delivery child owns its execution manifest, exact child approval in `approvals.json`, capability/WhatIf gates, attended application-user and role checkpoint, pipeline Apply, import, exact artifact/provenance checks, provider-specific read-back, terminal child summary, and canonical `DevDelivery` stage result.
- Every use of `ApprovedExecutionManifestDigest` in this plan and the pipeline means the exact approved child execution-manifest digest. It is never an umbrella digest and is never passed to `Invoke-TenantLifecycle.ps1`.
- Pipeline definition/run IDs, application-user IDs, role IDs, environment IDs/URLs, import actions, package details, action payloads, and read-back stay in child evidence. Only stage-level status, classification, source/intent/state provenance, `phaseManifestDigest`, and `phaseSummaryDigest` enter the canonical stage result.
- Existing Plan 1 manifest, approval, action-evidence, state, atomic-write, and read-back helpers remain shared child-library dependencies. No task below depends on umbrella Apply, umbrella approval loading, `CurrentBindingProvider`, or umbrella resource-level correlation.
- Umbrella `Verify` reads the immutable `<run>/stages/DevDelivery.json` result and its contained canonical child summary; it never queues the pipeline, imports a solution, invokes a child, or parses provider-specific IDs/actions.

## Global Constraints

- This is Plan 4. It depends on merged Plans 1-3 and then-current green `main`.
- At execution time, use `superpowers:using-git-worktrees`. Create branch `feat/power-platform-dev-delivery` and worktree `%LOCALAPPDATA%\CaldovaHR\wt\caldova-hr-frontier\pp-dev`; verify current-user write/delete access and a longest checkout path **less than 240 characters**.
- Windows PowerShell 5.1 with Pester 5.7.1 is authoritative. Run focused solution-module tests with the reviewed PowerShell 7 host after Windows PowerShell passes.
- Do not queue a pipeline, authenticate, create/adopt an application user, grant a role, create a service connection, import a solution, contact Power Platform, or perform any live provider operation while implementing this plan.
- Reuse Plan 1 evidence contracts, Plan 3 provider/protected-resource contracts, the existing `Caldova.HrFrontier.Solutions` module, and current solution source. No broad rewrite.
- Pipeline triggers are exactly `trigger: none` and `pr: none`; manual queue only. GitHub remains source; do not add GitHub Actions delivery or Azure Repo source.
- Use Power Platform Build Tools major version 2 only. Task/minor capability needing live organization validation is a fail-closed preflight result, not an invented value.
- WIF is the only service-connection authentication path. No client secret, certificate, PAT, token parameter, service-principal secret, or hidden fallback.
- Pack `hr/src/solutions/caldovahrfrontier/` once into one unmanaged DEV package. Build/check publishes it; Deploy DEV downloads and verifies the same bytes. No deploy-stage pack/rebuild.
- Pipeline variables are exactly `LifecycleRunId`, `ApprovedExecutionManifestDigest`, `ExpectedGitCommit`, `HrSolutionUniqueName`, `HrSolutionSourcePath`, `HrSolutionPackageName`, `PowerPlatformServiceConnection`, `PowerPlatformDevEnvironmentId`, `PowerPlatformDevEnvironmentUrl`, `PowerPlatformApplicationId`, and `PowerPlatformMinimumRoleId`.
- Tenant-specific values and URLs never appear in YAML. Protected values are reconciled by Plan 3 outside Git.
- The immutable artifact name is `hr-solution-dev`. Its files are `caldovahrfrontier.zip`, `provenance.json`, and `package.sha256`.
- Provenance fields are exactly `schemaVersion`, `pipelineDefinitionId`, `pipelineRunId`, `gitCommit`, `solutionSourceTreeDigest`, `lifecycleRunId`, `approvedExecutionManifestDigest`, `buildToolsMajorVersion`, `taskVersions`, `solutionUniqueName`, `packageType`, `solutionVersion`, `packageSha256`, `buildResult`, `checkResult`.
- DEV application-user/minimum-role creation or adoption is attended and independently read back. Missing permission, unsupported API, ambiguity, extra role, wrong app/environment, or absent stable ID is blocking.
- TEST and PROD are read-only and receive no service connection, application user, role, import, promotion, or pipeline stage.
- Power Platform is not claimed to expose the imported ZIP hash. Prove artifact bytes through Azure Pipelines digest/provenance and environment state through supported read-back.
- Preserve exact stable IDs, pre/post read-back, no self-elevation, no first-match selection, forward reconciliation, and NoChange/idempotent second execution.
- Fixtures use only synthetic IDs and `example.invalid` URLs. Every task ends with focused review and the standard Copilot co-author trailer.

## File and Interface Map

| Path | Responsibility |
|---|---|
| `azure-pipelines.yml` | Thin manual root pipeline. |
| `infra/src/pipelines/templates/power-platform-build.yml` | Exact SHA verification, pack, check, digest, provenance, artifact publish. |
| `infra/src/pipelines/templates/power-platform-deploy-dev.yml` | DEV gate, artifact download/digest verification, WIF import, solution read-back. |
| `infra/src/pipelines/templates/power-platform-evidence.yml` | Allowlisted `pipeline.json` and `power-platform.json` publication. |
| `infra/src/config/schemas/pipeline-provenance.schema.json` | Closed provenance manifest contract. |
| `hr/src/scripts/modules/Caldova.HrFrontier.Solutions/Public/New-HrSolutionPackage.ps1` | Local pack helper. |
| `hr/src/scripts/modules/Caldova.HrFrontier.Solutions/Public/Test-HrSolutionPackage.ps1` | Package identity/type/version validation. |
| `hr/src/scripts/modules/Caldova.HrFrontier.Solutions/Public/New-HrSolutionProvenance.ps1` | Canonical provenance/digest writer. |
| `hr/src/scripts/modules/Caldova.HrFrontier.Solutions/Public/Import-HrSolutionPackage.ps1` | Guarded DEV-only import wrapper for injected PAC runner. |
| `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Test-PowerPlatformDevDeliveryPrincipal.ps1` | Independent application-user and exact-role read-back. |
| `infra/tests/pester/PowerPlatformPipeline.Tests.ps1` | YAML/static/provenance/WIF safety tests. |
| `hr/tests/pester/SolutionDelivery.Tests.ps1` | Pack/import/provenance module tests. |

---

### Task 1: Build Tools, PAC Packability, and WIF Capability Preflight

**Files:**
- Create: `infra/src/config/schemas/power-platform-delivery-capabilities.schema.json`
- Create: `infra/src/config/runbooks/power-platform-delivery-capabilities.json`
- Create: `infra/src/scripts/runbooks/Test-PowerPlatformDeliveryCapabilities.ps1`
- Create: `infra/tests/pester/PowerPlatformDeliveryCapabilities.Tests.ps1`
- Modify: `hr/src/solutions/README.md`

**Interfaces:**
- Produces: `Test-PowerPlatformDeliveryCapabilities.ps1 -CapabilitiesPath -SolutionSourcePath -PacPath -ReportPath -NativeCommandRunner -NowUtc`.
- Capability fields are `schemaVersion`, `reviewedAtUtc`, `pac`, `buildTools`, `azureDevOpsWif`, `digest`; `pac` has `exactVersion`, `packSupported`, `codeAppRoundTripSupported`, `firstPartyReferences`; `buildTools` has `majorVersion`, `taskIds`, `taskVersions`, `firstPartyReferences`; `azureDevOpsWif` has `scheme`, `issuerField`, `subjectField`, `audienceField`, `organizationValidated`, `status`.

- [ ] **Step 1: Write failing capability tests**

Require PAC exact-version pack against committed source, no component loss, explicit Code App limitation result, Build Tools major `2`, exact task IDs, and WIF fields. Live organization availability must remain `Blocked` until an attended preflight records it.

- [ ] **Step 2: Run RED**

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path 'infra/tests/pester/PowerPlatformDeliveryCapabilities.Tests.ps1' -Output Detailed"
```

Expected: **FAIL** because delivery capability contracts do not exist.

- [ ] **Step 3: Implement fail-closed local preflight**

Use the exact PAC version selected by Plan 2 to pack to a temporary external directory and inspect the package without provider access. Record Build Tools 2.0 task IDs/versions from current first-party task metadata. If committed source cannot pack completely, stop and keep delivery blocked rather than excluding the Code App or inventing support. Mark Tenant 1 organization WIF availability `Blocked` for Plan 6 live preflight.

- [ ] **Step 4: Run GREEN**

Run the RED command and the local preflight. Expected: tests **PASS**; local pack capability is proven or the command fails closed with a precise blocked reason; no provider call occurs.

- [ ] **Step 5: Perform focused review**

Confirm exact versions/references, no hidden component omission, no live organization claim, no secret fallback, and accurate update of the known limitation.

- [ ] **Step 6: Commit**

```powershell
git add infra/src/config/schemas/power-platform-delivery-capabilities.schema.json infra/src/config/runbooks/power-platform-delivery-capabilities.json infra/src/scripts/runbooks/Test-PowerPlatformDeliveryCapabilities.ps1 infra/tests/pester/PowerPlatformDeliveryCapabilities.Tests.ps1 hr/src/solutions/README.md
git commit -m "feat(pipeline): validate Power Platform delivery capability" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 2: HR Solution Pack, Package Validation, Provenance, and DEV Import Functions

**Files:**
- Create: the four HR public module files listed in the map.
- Modify: `hr/src/scripts/modules/Caldova.HrFrontier.Solutions/Caldova.HrFrontier.Solutions.psd1`
- Modify: `hr/src/scripts/modules/Caldova.HrFrontier.Solutions/Caldova.HrFrontier.Solutions.psm1`
- Create: `hr/tests/pester/SolutionDelivery.Tests.ps1`

**Interfaces:**
- Produces:

```powershell
New-HrSolutionPackage `
  -SolutionSourcePath <absolute> -PackagePath <absolute.zip> `
  -SolutionUniqueName caldovahrfrontier -PackageType Unmanaged `
  -PacPath <absolute> -NativeCommandRunner <scriptblock>

Test-HrSolutionPackage `
  -PackagePath <absolute.zip> -ExpectedUniqueName caldovahrfrontier `
  -ExpectedVersion <four-part-version> -ExpectedPackageType Unmanaged

New-HrSolutionProvenance `
  -PipelineDefinitionId <string> -PipelineRunId <string> -GitCommit <40-hex> `
  -SolutionSourceTreeDigest <64-hex> -LifecycleRunId <guid> `
  -ApprovedExecutionManifestDigest <64-hex> -TaskVersions <object> `
  -SolutionUniqueName caldovahrfrontier -PackageType Unmanaged `
  -SolutionVersion <four-part-version> -PackagePath <absolute.zip> `
  -BuildResult Succeeded -CheckResult Succeeded -OutputPath <absolute.json>

Import-HrSolutionPackage `
  -PackagePath <absolute.zip> -ExpectedPackageDigest <64-hex> `
  -EnvironmentUrl <https-url> -EnvironmentId <string> `
  -ProfileName <string> -Stage DEV -PacPath <absolute> `
  -NativeCommandRunner <scriptblock> [-WhatIf]
```

- [ ] **Step 1: Write failing module tests**

Cover exact pack arguments, missing source, output overwrite refusal, unique-name/type/version mismatch, package digest, canonical provenance, import digest mismatch, wrong stage, TEST/PROD refusal, wrong environment/profile read-back, `-WhatIf`, and native failure without credential output.

- [ ] **Step 2: Run RED**

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path 'hr/tests/pester/SolutionDelivery.Tests.ps1' -Output Detailed"
```

Expected: **FAIL** because four module functions are absent.

- [ ] **Step 3: Implement minimum solution functions**

Use argument arrays and injected runners. Pack only the committed source path; inspect `solution.xml` from the ZIP for identity/type/version; compute lowercase SHA-256; canonicalize provenance as UTF-8 without BOM; import only after exact profile/environment read-back and digest comparison. Never create an auth profile in these functions.

- [ ] **Step 4: Run GREEN**

Run the RED command under Windows PowerShell 5.1 and reviewed PowerShell 7. Expected: both **PASS** with identical provenance bytes.

- [ ] **Step 5: Perform focused review**

Confirm no export/pull behavior was broken, no default environment, no first PAC profile, no authentication, no TEST/PROD path, no secret argument, and no deploy-stage rebuild helper.

- [ ] **Step 6: Commit**

```powershell
git add hr/src/scripts/modules/Caldova.HrFrontier.Solutions hr/tests/pester/SolutionDelivery.Tests.ps1
git commit -m "feat(hr): add solution package delivery functions" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 3: Pipeline Provenance Schema and Build/Check/Publish Template

**Files:**
- Create: `infra/src/config/schemas/pipeline-provenance.schema.json`
- Create: `infra/src/pipelines/templates/power-platform-build.yml`
- Create: `infra/tests/pester/PowerPlatformPipeline.Tests.ps1`

**Interfaces:**
- Consumes variables `LifecycleRunId`, `ApprovedExecutionManifestDigest`, `ExpectedGitCommit`, `HrSolutionUniqueName`, `HrSolutionSourcePath`, `HrSolutionPackageName`.
- Produces artifact `hr-solution-dev` containing exactly `caldovahrfrontier.zip`, `provenance.json`, `package.sha256`.
- Build task IDs are exactly `microsoft-IsvExpTools.PowerPlatform-BuildTools.tool-installer.PowerPlatformToolInstaller@2`, `microsoft-IsvExpTools.PowerPlatform-BuildTools.pack-solution.PowerPlatformPackSolution@2`, and `microsoft-IsvExpTools.PowerPlatform-BuildTools.checker.PowerPlatformChecker@2`.

- [ ] **Step 1: Write failing static/template tests**

Require exact Git SHA verification, committed source path, unmanaged package, Build Tools `@2`, checker success, one digest calculation, provenance schema validation, one artifact publish, no import/deploy task, no tenant value, no secret variable, and no unpinned script download.

- [ ] **Step 2: Run RED**

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path 'infra/tests/pester/PowerPlatformPipeline.Tests.ps1' -FullNameFilter '*build template*','*provenance schema*' -Output Detailed"
```

Expected: **FAIL** because schema/template are absent.

- [ ] **Step 3: Implement the build template**

Declare typed template parameters for the six consumed values, fail if `Build.SourceVersion` differs from `ExpectedGitCommit`, run Tool Installer/Pack/Checker tasks at major 2, invoke the tested provenance helper, verify digest file content, and publish exactly one immutable artifact.

- [ ] **Step 4: Run GREEN**

Run the RED command. Expected: **PASS** with static/synthetic fixture validation and no pipeline queue.

- [ ] **Step 5: Perform focused review**

Confirm one pack only, no environment URL/ID, no deploy task, no raw logs in artifact, exact artifact members, and exact source/digest bindings.

- [ ] **Step 6: Commit**

```powershell
git add infra/src/config/schemas/pipeline-provenance.schema.json infra/src/pipelines/templates/power-platform-build.yml infra/tests/pester/PowerPlatformPipeline.Tests.ps1
git commit -m "feat(pipeline): build checked HR solution artifact" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 4: Attended DEV Application-User Checkpoint and Independent Read-Back

**Files:**
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Test-PowerPlatformDevDeliveryPrincipal.ps1`
- Modify: bootstrap module export lists.
- Create: `infra/tests/pester/PowerPlatformDevPrincipal.Tests.ps1`
- Modify: `infra/docs/12-power-platform-environments-and-alm.md`

**Interfaces:**
- Produces:

```powershell
Test-PowerPlatformDevDeliveryPrincipal `
  -EnvironmentId <string> -EnvironmentUrl <https-url> `
  -ApplicationId <guid> -ExpectedRoleIds <guid[]> `
  -VerifiedContext <object> -ProviderRunner <scriptblock> -NowUtc <datetime>
```

- Returns exactly `environmentId`, `applicationUserId`, `applicationId`, `enabled`, `roleIds`, `classification`, `readBackDigest`.
- The attended checkpoint action is `CompleteDevApplicationUserAndMinimumRole`; scripts do not perform the administrator action.

- [ ] **Step 1: Write failing checkpoint/read-back tests**

Cover missing user, zero/multiple app matches, wrong environment/app, disabled user, missing role, extra role, malformed/403/404/timeout, exact pass, and no mutation call. Require full role-set equality, not containment.

- [ ] **Step 2: Run RED**

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path 'infra/tests/pester/PowerPlatformDevPrincipal.Tests.ps1' -Output Detailed"
```

Expected: **FAIL** because the independent read-back function is absent.

- [ ] **Step 3: Implement the attended boundary**

Return `Manual` until an authorized administrator completes or adopts the exact application user and minimum role through supported administration. Then independently query exact stable IDs and the complete role set through the injected runner. Never grant a role, self-elevate, infer a role by name, or accept extra roles.

- [ ] **Step 4: Run GREEN**

Run the RED command. Expected: **PASS**, with zero mutation calls in every case.

- [ ] **Step 5: Perform focused review**

Confirm attended authority, no role ID invention, no name-only adoption, no broader permission, no TEST/PROD query with write semantics, and stable sanitized evidence.

- [ ] **Step 6: Commit**

```powershell
git add infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap infra/tests/pester/PowerPlatformDevPrincipal.Tests.ps1 infra/docs/12-power-platform-environments-and-alm.md
git commit -m "feat(power-platform): verify DEV delivery principal" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 5: WIF-Only DEV Deploy and Evidence Templates

**Files:**
- Create: `infra/src/pipelines/templates/power-platform-deploy-dev.yml`
- Create: `infra/src/pipelines/templates/power-platform-evidence.yml`
- Modify: `infra/tests/pester/PowerPlatformPipeline.Tests.ps1`

**Interfaces:**
- Deploy consumes all eleven exact pipeline variables listed in Global Constraints.
- Uses task `microsoft-IsvExpTools.PowerPlatform-BuildTools.import-solution.PowerPlatformImportSolution@2` with WIF service connection `$(PowerPlatformServiceConnection)`.
- Produces allowlisted `pipeline.json` and `power-platform.json` with package digest, run/SHA, import job ID/result, solution unique name/ID/version/managed state/publisher/component summary, application-user stable ID/enabled state/exact role IDs, and explicit TEST/PROD non-mutation.

- [ ] **Step 1: Write failing deploy/evidence tests**

Require `dependsOn` build success, DEV environment gate, artifact download, digest/provenance verification before import, no pack task, one import task at `@2`, service-connection variable only, exact DEV read-back, sanitized evidence, no TEST/PROD stage, and no secret/client credential input.

- [ ] **Step 2: Run RED**

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path 'infra/tests/pester/PowerPlatformPipeline.Tests.ps1' -FullNameFilter '*DEV deploy*','*pipeline evidence*' -Output Detailed"
```

Expected: **FAIL** because deploy/evidence templates are absent.

- [ ] **Step 3: Implement minimum deploy/evidence templates**

Download `hr-solution-dev`, verify all provenance bindings and package digest, require the DEV environment, invoke Build Tools import with the WIF service-connection name, call tested read-back scripts, and publish only sanitized records. Do not assert that Dataverse exposes the ZIP hash.

- [ ] **Step 4: Run GREEN**

Run the RED command. Expected: **PASS**, with static/synthetic validation only.

- [ ] **Step 5: Perform focused review**

Confirm byte identity through download/digest, no rebuild, no secret auth, no unsupported hash claim, no TEST/PROD write, no hidden trigger, and no unallowlisted evidence.

- [ ] **Step 6: Commit**

```powershell
git add infra/src/pipelines/templates/power-platform-deploy-dev.yml infra/src/pipelines/templates/power-platform-evidence.yml infra/tests/pester/PowerPlatformPipeline.Tests.ps1
git commit -m "feat(pipeline): deploy exact artifact to DEV" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 6: Thin Root Pipeline and Idempotent Synthetic Rerun

**Files:**
- Create: `azure-pipelines.yml`
- Modify: `infra/tests/pester/PowerPlatformPipeline.Tests.ps1`
- Modify: `infra/tests/pester/RunbookStaticSafety.Tests.ps1`
- Modify: `.github/cli/tests/WorkflowContract.Tests.ps1`

**Interfaces:**
- Root stages are exactly `BuildAndCheck` and `DeployDev`.
- Root safe constants are `HrSolutionUniqueName: caldovahrfrontier`, `HrSolutionSourcePath: hr/src/solutions/caldovahrfrontier`, and `HrSolutionPackageName: caldovahrfrontier.zip`; all tenant-specific values are externally supplied protected variables.

- [ ] **Step 1: Write failing root/idempotency tests**

Require manual triggers, two stages, template paths, direct GitHub SHA binding, protected variable references, no literal IDs/URLs, no GitHub workflow edit, no TEST/PROD stage, and a synthetic rerun that produces the same package digest and no duplicate resource identity.

- [ ] **Step 2: Run RED**

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path @('infra/tests/pester/PowerPlatformPipeline.Tests.ps1','infra/tests/pester/RunbookStaticSafety.Tests.ps1','.github/cli/tests/WorkflowContract.Tests.ps1') -Output Detailed"
```

Expected: **FAIL** because root YAML is absent.

- [ ] **Step 3: Implement the thin root**

Set `trigger: none`, `pr: none`, declare only safe constants, require externally supplied protected variables, and instantiate the build and deploy templates. Ensure Deploy DEV consumes the published artifact from Build and never checks out/repackages source.

- [ ] **Step 4: Run GREEN**

Run the RED command. Expected: **PASS**; `.github/workflows/validate-repository.yml` remains byte-unchanged.

- [ ] **Step 5: Perform focused review**

Confirm root discoverability without tenant leakage, exact templates, no automatic queue, no variable default that could target a tenant, and no GitHub Actions delivery expansion.

- [ ] **Step 6: Commit**

```powershell
git add azure-pipelines.yml infra/tests/pester/PowerPlatformPipeline.Tests.ps1 infra/tests/pester/RunbookStaticSafety.Tests.ps1 .github/cli/tests/WorkflowContract.Tests.ps1
git commit -m "feat(pipeline): add manual DEV delivery pipeline" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 7: Delivery Documentation and Full Local Verification

**Files:**
- Modify: `hr/src/scripts/README.md`
- Modify: `hr/src/solutions/README.md`
- Modify: `infra/docs/12-power-platform-environments-and-alm.md`
- Modify: `infra/docs/13-azure-devops-engineering-control-plane.md`
- Modify: `infra/docs/runbooks/02-cloud-service-foundation.md`
- Modify: `infra/docs/runbooks/README.md`
- Modify: `infra/docs/README.md`
- Modify: `infra/README.md`
- Modify: `infra/tests/pester/RunbookDocumentation.Tests.ps1`

**Interfaces:**
- Consumes: Tasks 1-6 and Plan 3 protected-resource contract.
- Produces: exact build/deploy/operator documentation; no live execution record.

- [ ] **Step 1: Write failing documentation tests**

Require all YAML paths, variable names, artifact members, Build Tools 2.0/WIF, attended application-user checkpoint, exact role read-back, manual queue, no deploy-stage rebuild, DEV-only mutation, TEST/PROD read-only, provenance limits, and no-live-execution warning.

- [ ] **Step 2: Run RED**

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path 'infra/tests/pester/RunbookDocumentation.Tests.ps1' -Output Detailed"
```

Expected: **FAIL** because current docs say the pipeline/import path is absent.

- [ ] **Step 3: Update documentation and catalogues**

Document implemented local contracts, all hard live-entry gates, exact application-user checkpoint/read-back, artifact identity limits, idempotent rerun expectation, and explicit statement that no pipeline has been queued and no import has run.

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

Expected: all tests/validators/builds **PASS**, GitHub workflows are unchanged, and no live run/evidence claim exists. Repeat focused HR solution tests under reviewed PowerShell 7.

- [ ] **Step 5: Perform focused review**

Map cloud spec section 8 and relevant acceptance criteria to tests/docs. Scan for placeholders, floating task versions, secret auth, first-match profile, TEST/PROD writes, rebuild, trigger, unsupported package-hash claim, and live-execution wording.

- [ ] **Step 6: Commit**

```powershell
git add hr/src/scripts/README.md hr/src/solutions/README.md infra/docs infra/README.md infra/tests/pester/RunbookDocumentation.Tests.ps1
git commit -m "docs(pipeline): document WIF DEV delivery" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

## Completion Gate

Plan 4 is complete only when corrected Plans 1-3 remain green, the committed solution packs without component loss, all YAML/static/synthetic tests pass, one immutable artifact is proven by digest, DEV is the only writable provider stage, application-user/role work remains attended with independent read-back, synthetic canonical `DevDelivery` stage-result emission passes, GitHub workflows are unchanged, and no pipeline or import has executed.
