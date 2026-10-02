# Cloud Service Foundation Core Implementation Plan

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-10-02 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Draft |
| **Scope** | Tenant 1 provider assessment, deterministic planning, and foundation reconciliation core |
| **References** | [Approved Cloud Service Foundation Runbook Design](../specs/2026-10-02-cloud-service-foundation-runbook-design.md), [Tenant Lifecycle Core Plan](2026-10-02-tenant-lifecycle-core-implementation.md), [Developer Workstation Refactor Plan](2026-10-02-developer-workstation-runbook-refactor-implementation.md), [Current Cloud Stop Notice](../../infra/docs/runbooks/02-cloud-service-foundation.md) |

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build supported Test/New/Invoke Tenant 1 foundation entry points, exact provider adapters, deterministic Bicep/provider planning, and tested forward reconciliation while retaining stopped legacy entry points and excluding pipeline solution-delivery tasks and live execution.

**Architecture:** New thin scripts consume Plan 1 lifecycle contracts and Plan 2 workstation evidence. Focused provider adapters expose exact assessment, plan, pre-read, mutation, and post-read contracts through injected runners; existing dormant helpers are reused only after contract tests prove them safe. Bicep remains the sole Azure-resource owner, while PowerShell validates contexts, composes an approved plan, sequences provider actions, and fails closed on ambiguity or unsupported capability.

**Tech Stack:** Windows PowerShell 5.1 (authoritative), Pester 5.7.1, reviewed PowerShell 7 compatibility, JSON Schema draft 2020-12, GitHub REST API `2022-11-28`, Microsoft Graph v1.0 where supported, Azure CLI/Bicep, Azure DevOps REST API 7.1, PAC CLI read-only context, and `Caldova.HrFrontier.Bootstrap`.

**Spec:** [`docs/specs/2026-10-02-cloud-service-foundation-runbook-design.md`](../specs/2026-10-02-cloud-service-foundation-runbook-design.md)

## Global Constraints

- This is Plan 3. It depends on merged Plans 1 and 2 and then-current green `main`.
- At execution time, use `superpowers:using-git-worktrees`. Create branch `feat/cloud-service-foundation-core` and worktree `%LOCALAPPDATA%\CaldovaHR\wt\caldova-hr-frontier\cloud-core`; prove current-user write/delete access and a longest checkout path **less than 240 characters**.
- Windows PowerShell 5.1 and Pester 5.7.1 are authoritative; run reviewed PowerShell 7 compatibility tests where scripts/modules are shared.
- This plan builds code and synthetic/provider-contract tests only. Do not authenticate, contact a live provider, run live assessment, execute Bicep `create`, create a pipeline, or mutate Tenant 1.
- Keep `infra/src/scripts/runbooks/Get-CloudFoundationPlan.ps1` and `Invoke-CloudFoundation.ps1` as fail-closed compatibility notices with their initial `throw`. Do not forward either legacy filename to a new path.
- New public entry points are `Test-TenantFoundation.ps1`, `New-TenantFoundationPlan.ps1`, and `Invoke-TenantFoundation.ps1`.
- Require explicit `PublicTenantKey tenant1`, ignored `tenant1.local.psd1`, ignored `tenant1.state.local.json`, expected source commit, exact workstation outcome, exact tool identities, run ID, and external evidence root. No tracked fallback, environment selector, first match, or matrix mode.
- One tool context never validates another. Prove GitHub, Azure, Entra, Azure DevOps, and PAC/Power Platform contexts before inventory. Wrong/missing/ambiguous/unauthorized context is blocking.
- Preserve `NoChange`, `Create`, `Update`, `Manual`, `Blocked`, `Refused`; exact stable IDs; zero/multiple-match blocking; immediate pre/post read-back; forward reconciliation; and a second run with no `Create`/`Update`.
- No self-elevation, secrets, certificates, PATs, token parameters, client-secret fallback, hidden consent, automatic role grant, destructive rollback, delete, complete-mode deployment, deployment stack, or source mutation.
- GitHub scope is the existing repository only. No repository creation/publication and no GitHub Actions delivery expansion.
- Entra identity is credential-free. Federation metadata must be exact and read back; multiple app/SP/credential matches block.
- Bicep uses incremental mode and exact approved template/parameter bytes. Delete or unsupported `what-if` changes block.
- Azure DevOps project creation is reusable only for explicit reviewed `Create` intent with zero matches. Tenant 1 expects exact existing-project verification.
- The adapter may reconcile pipeline definition, DEV environment, WIF service connection, protected variables, and supported checks, but it must remain `Blocked` until Plan 4's exact YAML paths and the live capability record are present.
- TEST and PROD are read-only. No Power Platform environment creation, application-user work, solution pack/import, pipeline queue, TEST/PROD write, Tenant 2 work, or live execution in this plan.
- Use injected native/provider runners in every test. Fixtures contain only synthetic IDs and `example.invalid` URLs.
- Every task ends with a focused review and commit trailer `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>`.

## File and Contract Map

| Path | Responsibility |
|---|---|
| `infra/src/config/schemas/tenant-foundation-assessment.schema.json` | Exact context and provider inventory projection. |
| `infra/src/config/schemas/tenant-foundation-action-plan.schema.json` | Ordered provider actions and prerequisites. |
| `infra/src/config/schemas/tenant-foundation-provider-plan.schema.json` | Provider adapter mutation/read-back envelope. |
| `infra/src/config/schemas/tenant-foundation-read-back.schema.json` | Exact stable-ID and owned-property postconditions. |
| `infra/src/config/schemas/tenant-foundation-capabilities.schema.json` | Reviewed API/WIF/check capability record. |
| `infra/src/config/runbooks/tenant-foundation-capabilities.json` | Supported capability decisions; unproven entries are `Blocked`. |
| `infra/src/scripts/runbooks/Test-TenantFoundation.ps1` | Context-first read-only assessment. |
| `infra/src/scripts/runbooks/New-TenantFoundationPlan.ps1` | Deterministic plan, Bicep build, and subscription `what-if`. |
| `infra/src/scripts/runbooks/Invoke-TenantFoundation.ps1` | Approval-bound `-WhatIf`/`-Apply` dispatcher. |
| `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/*TenantFoundation*.ps1` | Provider-neutral public functions. |
| `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/*TenantFoundation*.ps1` | Focused provider adapters. |
| `infra/tests/pester/TenantFoundation*.Tests.ps1` | New focused schema, context, adapter, planning, and reconciliation tests. |

Assessment root fields are exactly `schemaVersion`, `runId`, `generatedAtUtc`, `sourceCommit`, `publicTenantKey`, `intentDigest`, `stateDigest`, `workstationOutcomeDigest`, `toolIdentities`, `contexts`, `providers`, `components`, `overallStatus`, `digest`.

Context fields are:

- GitHub: `host`, `login`, `owner`, `repository`, `repositoryId`, `status`;
- Azure: `accountId`, `tenantId`, `subscriptionId`, `principalType`, `status`;
- Entra: `tenantId`, `principalId`, `activeRoleTemplateIds`, `status`;
- Azure DevOps: `organizationUrl`, `projectName`, `projectId`, `actingUserId`, `subjectDescriptor`, `status`;
- Power Platform stage: `profileName`, `tenantId`, `environmentId`, `environmentUrl`, `stage`, `lifecycleType`, `status`.

Action fields are exactly Plan 1's action fields plus `providerPlanDigest`. Provider-plan fields are `schemaVersion`, `actionId`, `provider`, `operation`, `method`, `resourceUri`, `requestBodyDigest`, `preRead`, `expectedPostcondition`, `readBackSelector`, `forbiddenOperations`, `digest`.

The capability record fields are `schemaVersion`, `reviewedAtUtc`, `providers`, and `digest`; each provider has `name`, `apiVersion`, `capabilities`, `firstPartyReferences`, and `status`. Capabilities cover GitHub rulesets, Graph federated identity credentials, Azure subscription `what-if`/incremental deployment, Azure DevOps YAML pipeline/environment/service-endpoint/check APIs, Power Platform Build Tools 2.0 WIF scheme metadata, and PAC environment read-back. Unsupported/unverified is `Blocked`; no secret fallback exists.

---

### Task 1: Closed Cloud Schemas and Capability Preflight

**Files:**
- Create: the five `tenant-foundation-*.schema.json` files in the map.
- Create: `infra/src/config/runbooks/tenant-foundation-capabilities.json`
- Create: `infra/src/scripts/runbooks/Test-TenantFoundationCapabilities.ps1`
- Create: `infra/tests/pester/TenantFoundationContracts.Tests.ps1`
- Create: `infra/tests/fixtures/runbooks/tenant-foundation.synthetic.json`

**Interfaces:**
- Consumes: current first-party API/task documentation and unauthenticated local help only.
- Produces: `Test-TenantFoundationCapabilities.ps1 -CapabilitiesPath -ReportPath -NativeCommandRunner -NowUtc`.
- Produces closed schema version `1.0` records with the exact fields above.

- [ ] **Step 1: Write failing schema/capability tests**

Reject unknown fields, unversioned API contracts, secret authentication schemes, unsupported Build Tools major values, absent WIF issuer/subject/audience metadata fields, unchecked protected-resource APIs, `latest`, and a capability marked supported without a first-party reference.

- [ ] **Step 2: Run RED**

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path 'infra/tests/pester/TenantFoundationContracts.Tests.ps1' -Output Detailed"
```

Expected: **FAIL** because schemas, capability record, and preflight are absent.

- [ ] **Step 3: Implement the minimum preflight contract**

Record reviewed API versions/capabilities only after current first-party validation. Where Tenant 1 organization availability or permission requires live validation, set `status` to `Blocked` and emit an external preflight record naming the exact missing capability; do not invent support. Runtime preflight validates the tracked decision and local CLI help but performs no authentication or provider call.

- [ ] **Step 4: Run GREEN**

Run the RED command and the preflight against synthetic capability fixtures. Expected: schema tests **PASS** and unproven live-only capabilities return `Blocked`, not success.

- [ ] **Step 5: Perform focused review**

Confirm every supported entry has a version/reference, every live-only entry fails closed, and no token/client-secret/certificate fallback or guessed capability exists.

- [ ] **Step 6: Commit**

```powershell
git add infra/src/config/schemas/tenant-foundation-*.schema.json infra/src/config/runbooks/tenant-foundation-capabilities.json infra/src/scripts/runbooks/Test-TenantFoundationCapabilities.ps1 infra/tests/pester/TenantFoundationContracts.Tests.ps1 infra/tests/fixtures/runbooks/tenant-foundation.synthetic.json
git commit -m "feat(cloud): define foundation provider contracts" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 2: New Entry-Point Contracts and Legacy Stop Safety

**Files:**
- Create: `infra/src/scripts/runbooks/Test-TenantFoundation.ps1`
- Create: `infra/src/scripts/runbooks/New-TenantFoundationPlan.ps1`
- Create: `infra/src/scripts/runbooks/Invoke-TenantFoundation.ps1`
- Modify: `infra/tests/pester/CloudFoundationStaticSafety.Tests.ps1`
- Create: `infra/tests/pester/TenantFoundationEntryPoints.Tests.ps1`

**Interfaces:**
- Produces these exact public parameter sets:

```powershell
Test-TenantFoundation.ps1 `
  -RunId <guid> -EvidenceRoot <absolute> -RepositoryRoot <absolute> `
  -ExpectedSourceCommit <40-hex> -PublicTenantKey tenant1 `
  -TenantConfigurationPath <absolute> -TenantStatePath <absolute> `
  -WorkstationOutcomePath <absolute> -CapabilitiesPath <absolute> `
  -Stages DEV,TEST,PROD

New-TenantFoundationPlan.ps1 `
  -RunId <guid> -EvidenceRoot <absolute> -RepositoryRoot <absolute> `
  -ExpectedSourceCommit <40-hex> -PublicTenantKey tenant1 `
  -TenantConfigurationPath <absolute> -TenantStatePath <absolute> `
  -WorkstationOutcomePath <absolute> -CapabilitiesPath <absolute> `
  -AssessmentPath <absolute> -BicepEntryPoint <absolute> `
  -Stages DEV,TEST,PROD

Invoke-TenantFoundation.ps1 `
  -RunId <guid> -EvidenceRoot <absolute> -RepositoryRoot <absolute> `
  -ExpectedSourceCommit <40-hex> -PublicTenantKey tenant1 `
  -TenantConfigurationPath <absolute> -TenantStatePath <absolute> `
  -WorkstationOutcomePath <absolute> -CapabilitiesPath <absolute> `
  -ExecutionManifestPath <absolute> -ApprovedDigest <64-hex> `
  -Stages DEV,TEST,PROD [-Apply]
```

Each script also accepts hidden `NativeToolResolver`, `NativeCommandRunner`, `ProviderRunner`, `InteractiveHostProbe`, and `NowUtc`.

- [ ] **Step 1: Write failing contract/static tests**

Require new paths/signatures, default non-mutation, hidden injected seams, `SupportsShouldProcess` on Invoke, explicit tenant/stages, and no credential parameters. Assert both legacy files still throw before imports/native calls and contain no forwarding call.

- [ ] **Step 2: Run RED**

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path @('infra/tests/pester/TenantFoundationEntryPoints.Tests.ps1','infra/tests/pester/CloudFoundationStaticSafety.Tests.ps1') -Output Detailed"
```

Expected: **FAIL** because new entry points are absent.

- [ ] **Step 3: Add fail-closed thin scripts**

Implement parameter validation and imports only. Default missing injected implementation throws `TenantFoundation.Adapter.NotConfigured`; do not copy provider logic into entry points. Preserve the exact first executable stop behavior of the two old files.

- [ ] **Step 4: Run GREEN**

Run the RED command. Expected: **PASS**, with no provider/native call from contract tests and unchanged legacy stops.

- [ ] **Step 5: Perform focused review**

Confirm no aliases to `TenantAlias`, no implicit stage, no environment-variable tenant selection, no secret input, and no silent unblocking.

- [ ] **Step 6: Commit**

```powershell
git add infra/src/scripts/runbooks/Test-TenantFoundation.ps1 infra/src/scripts/runbooks/New-TenantFoundationPlan.ps1 infra/src/scripts/runbooks/Invoke-TenantFoundation.ps1 infra/tests/pester/TenantFoundationEntryPoints.Tests.ps1 infra/tests/pester/CloudFoundationStaticSafety.Tests.ps1
git commit -m "feat(cloud): add stopped-safe foundation entry points" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 3: Exact Multi-Tool Context Assessment Before Inventory

**Files:**
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Test-TenantFoundationContexts.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/Get-TenantFoundationContext.ps1`
- Modify: bootstrap module export lists.
- Modify: `infra/src/scripts/runbooks/Test-TenantFoundation.ps1`
- Create: `infra/tests/pester/TenantFoundationContexts.Tests.ps1`

**Interfaces:**
- Consumes: explicit intent stable selectors and Plan 2 tool identities.
- Produces: `Test-TenantFoundationContexts -TenantConfiguration -ToolIdentities -Stages -NativeCommandRunner -NowUtc`.
- Context reads use exact commands/endpoints selected by Task 1 capability records; each returns the exact context fields in the map.

- [ ] **Step 1: Write failing context tests**

Cover wrong host/login/repository ID, wrong Azure tenant/subscription/principal, missing Entra principal/role proof, wrong Azure DevOps organization/project/user/project ID, PAC profile ambiguity, wrong stage/environment/lifecycle type, one valid context not validating another, malformed/empty/403/404/timeout responses, and zero/multiple matches.

- [ ] **Step 2: Run RED**

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path 'infra/tests/pester/TenantFoundationContexts.Tests.ps1' -Output Detailed"
```

Expected: **FAIL** because exact context assessment is unavailable.

- [ ] **Step 3: Implement context-first assessment**

Resolve exact tool paths from Plan 2 evidence and invoke only injected runners. Compare stable IDs and normalized exact values with reviewed intent. Return all contexts plus `overallStatus`; do not inventory any provider until every required context is `Verified`. Do not catch and reinterpret uncertain responses as absence.

- [ ] **Step 4: Run GREEN**

Run the RED command. Expected: **PASS**, including assertions that provider inventory call count is zero on any context failure.

- [ ] **Step 5: Perform focused review**

Confirm no shared-context assumption, first match, URL substring match, stale evidence adoption, raw response persistence, or provider call before complete context proof.

- [ ] **Step 6: Commit**

```powershell
git add infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap infra/src/scripts/runbooks/Test-TenantFoundation.ps1 infra/tests/pester/TenantFoundationContexts.Tests.ps1
git commit -m "feat(cloud): verify exact provider contexts" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 4: Provider Inventory Adapters and Deterministic Assessment

**Files:**
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/Get-GitHubTenantFoundationState.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/Get-EntraTenantFoundationState.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/Get-AzureTenantFoundationState.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/Get-AzureDevOpsTenantFoundationState.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/Get-PowerPlatformTenantFoundationState.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Get-TenantFoundationAssessment.ps1`
- Modify: module export lists and `Test-TenantFoundation.ps1`.
- Create: `infra/tests/pester/TenantFoundationAssessment.Tests.ps1`

**Interfaces:**
- Every private adapter has `-Intent <object> -State <object> -VerifiedContext <object> -Capabilities <object> -ProviderRunner <scriptblock>`.
- `Get-TenantFoundationAssessment` accepts the five adapter results and emits the closed assessment schema.
- Components use `logicalName`, `provider`, `resourceType`, `observedStableId`, `classification`, `ownedPropertiesDigest`, `reasonCode`.

- [ ] **Step 1: Write failing adapter tests**

Use recorded synthetic response fixtures for exact, missing, drifted, unauthorized, unsupported, malformed, ambiguous, and partially adopted resources. Cover GitHub metadata/ruleset, Entra app/SP/federated credential, Azure Bicep-owned resources, Azure DevOps project/pipeline/environment/service endpoint/check/variables, and all three Power Platform environments read-only.

- [ ] **Step 2: Run RED**

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path 'infra/tests/pester/TenantFoundationAssessment.Tests.ps1' -Output Detailed"
```

Expected: **FAIL** because focused adapters/assessment do not exist.

- [ ] **Step 3: Implement the minimum inventory projection**

Reuse existing `Get-GitHubDiscovery`, `Get-EntraDiscovery`, `Get-AzureDiscovery`, and `Get-AzureDevOpsDiscovery` only behind wrappers where fixture contract tests prove stable output. Replace unsupported assumptions with focused parsing. State may nominate an ID but every resource is freshly read back; exact-name discovery never authorizes first-match adoption.

- [ ] **Step 4: Run GREEN**

Run the RED command. Expected: **PASS** with deterministic sanitized assessment and no raw responses.

- [ ] **Step 5: Perform focused review**

Review each provider's absence predicate and exact-ID adoption. Confirm TEST/PROD components cannot classify as writable and unsupported pipeline/WIF capabilities remain `Blocked`.

- [ ] **Step 6: Commit**

```powershell
git add infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap infra/src/scripts/runbooks/Test-TenantFoundation.ps1 infra/tests/pester/TenantFoundationAssessment.Tests.ps1
git commit -m "feat(cloud): assess foundation provider state" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 5: Deterministic Provider Plan, Bicep Build, and Subscription What-If

**Files:**
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/New-TenantFoundationActionPlan.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/New-TenantFoundationProviderPlan.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/ConvertTo-SanitizedBicepWhatIf.ps1`
- Modify: module export lists and `New-TenantFoundationPlan.ps1`.
- Create: `infra/tests/pester/TenantFoundationPlanning.Tests.ps1`

**Interfaces:**
- Consumes: fresh Task 4 assessment, exact Bicep entry point, Plan 1 manifest constructor.
- Produces ordered provider actions `github.*`, `entra.*`, `azure.deploy`, `azuredevops.*`, and read-only `powerplatform.verify.*`.
- Manifest bindings include `bicepSourceHash`, `compiledTemplateHash`, `parameterHash`, `whatIfDigest`, `pipelineSourceHash`, `solutionSourceTreeHash`, and exact tool identities.

- [ ] **Step 1: Write failing planning/what-if tests**

Assert deterministic ordering/digests, prerequisite IDs, exact absence predicates, no action for ambiguity, Azure build bytes bound, generated parameters external, delete/unsupported change blocking, incremental mode, no provider write during planning, missing Plan 4 YAML causing pipeline action `Blocked`, and TEST/PROD read-only actions.

- [ ] **Step 2: Run RED**

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path 'infra/tests/pester/TenantFoundationPlanning.Tests.ps1' -Output Detailed"
```

Expected: **FAIL** because the new planner and sanitized `what-if` contract are absent.

- [ ] **Step 3: Implement minimum deterministic planning**

Build Bicep to the external run directory, generate parameters from reviewed intent, invoke subscription `what-if` through the injected runner, reject deletes/unsupported changes, and bind exact bytes. Create a provider plan for each `Create`/`Update`; `Manual`, `Blocked`, and `Refused` remain explicit actions and block dependents.

- [ ] **Step 4: Run GREEN**

Run the RED command and local `az bicep build --file infra/src/bicep/main.bicep --stdout`. Expected: tests **PASS** and Bicep builds without a live deployment.

- [ ] **Step 5: Perform focused review**

Confirm no `az deployment sub create`, complete mode, imperative Azure-resource duplicate, generated parameter in Git, summary-only approval, or writable TEST/PROD plan.

- [ ] **Step 6: Commit**

```powershell
git add infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap infra/src/scripts/runbooks/New-TenantFoundationPlan.ps1 infra/tests/pester/TenantFoundationPlanning.Tests.ps1
git commit -m "feat(cloud): plan deterministic provider actions" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 6: GitHub, Entra, and Incremental Azure Reconciliation Adapters

**Files:**
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/Invoke-GitHubTenantFoundationAction.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/Invoke-EntraTenantFoundationAction.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/Invoke-AzureTenantFoundationAction.ps1`
- Create: `infra/tests/pester/TenantFoundationProviderContracts.Tests.ps1`

**Interfaces:**
- Each adapter accepts `-ProviderPlan -VerifiedContext -Capabilities -ProviderRunner -NowUtc` and returns `preRead`, `mutation`, `postRead`, `stableId`, `ownedPropertiesDigest`, `status`.
- Supported operations are exactly `UpdateRepositoryMetadata`, `UpsertRepositoryRuleset`, `CreateApplication`, `UpdateApplicationMetadata`, `CreateServicePrincipal`, `UpsertFederatedIdentityCredential`, and `DeploySubscriptionBicepIncremental`.

- [ ] **Step 1: Write failing provider-contract tests**

Require immediate pre-read, exact request digest, post-read, no repository creation, preserved unrelated GitHub properties, no app password/key credential, exact FIC issuer/subject/audience, repeated Azure `what-if`, approved byte match, incremental deployment, and no delete/rollback. Add partial-adoption and ambiguous-match failures.

- [ ] **Step 2: Run RED**

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path 'infra/tests/pester/TenantFoundationProviderContracts.Tests.ps1' -FullNameFilter '*GitHub*','*Entra*','*Azure*' -Output Detailed"
```

Expected: **FAIL** because the adapters do not exist.

- [ ] **Step 3: Implement minimum adapters**

Dispatch only the exact operation allowlist, compare the provider-plan digest before pre-read, stop on drift, call one injected mutation, and require exact post-read. For Azure, compare rebuilt template/parameters and fresh sanitized `what-if` to the approved hashes before an injected incremental deployment call.

- [ ] **Step 4: Run GREEN**

Run the RED command. Expected: **PASS** with synthetic runners and no network.

- [ ] **Step 5: Perform focused review**

Confirm no secret credential, hidden consent, owner/role expansion, deletion, retry after uncertain mutation, or automatic rollback. Ensure state updates occur only after successful post-read.

- [ ] **Step 6: Commit**

```powershell
git add infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private infra/tests/pester/TenantFoundationProviderContracts.Tests.ps1
git commit -m "feat(cloud): reconcile GitHub Entra and Azure" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 7: Azure DevOps Project, Pipeline, Environment, WIF, and Protected-Resource Adapter

**Files:**
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/Invoke-AzureDevOpsTenantFoundationAction.ps1`
- Modify: `infra/tests/pester/TenantFoundationProviderContracts.Tests.ps1`
- Create: `infra/tests/fixtures/runbooks/azure-devops-foundation.synthetic.json`

**Interfaces:**
- Supported operations are exactly `VerifyProject`, `CreateProject`, `UpsertYamlPipeline`, `UpsertDevEnvironment`, `UpsertPowerPlatformWifServiceConnection`, `UpsertProtectedVariables`, and `UpsertSupportedChecks`.
- Protected variable names are exactly `LifecycleRunId`, `ApprovedExecutionManifestDigest`, `ExpectedGitCommit`, `HrSolutionUniqueName`, `HrSolutionSourcePath`, `HrSolutionPackageName`, `PowerPlatformServiceConnection`, `PowerPlatformDevEnvironmentId`, `PowerPlatformDevEnvironmentUrl`, `PowerPlatformApplicationId`, and `PowerPlatformMinimumRoleId`.
- Pipeline paths are exactly `/azure-pipelines.yml` and `infra/src/pipelines/templates/`.

- [ ] **Step 1: Write failing Azure DevOps tests**

Cover exact existing project, explicit safe reusable project creation, asynchronous terminal state, GitHub repository/branch binding, absent YAML path, DEV-only environment, WIF endpoint scheme metadata, protected variable names, supported check read-back, unsupported checks as `Manual`, ambiguous endpoint/environment/pipeline, no secret fallback, and no queue.

- [ ] **Step 2: Run RED**

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path 'infra/tests/pester/TenantFoundationProviderContracts.Tests.ps1' -FullNameFilter '*Azure DevOps*' -Output Detailed"
```

Expected: **FAIL** because the Azure DevOps adapter is absent.

- [ ] **Step 3: Implement minimum protected-resource reconciliation**

Use exact stable IDs and API versions from Task 1. Keep absent Plan 4 YAML and unproven organization WIF/check capability `Blocked`. Never synthesize a service-connection secret. Preserve unrelated project resources and require immediate post-read for every completed operation.

- [ ] **Step 4: Run GREEN**

Run the RED command. Expected: **PASS**, with no queue/pipeline execution and blocked status when YAML/capability prerequisites are absent.

- [ ] **Step 5: Perform focused review**

Confirm direct GitHub source, `trigger: none` expectation, DEV-only protected environment, no Azure Repo creation, no PAT, no GitHub Actions delivery, no automatic administrator grant, and no TEST/PROD resource.

- [ ] **Step 6: Commit**

```powershell
git add infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/Invoke-AzureDevOpsTenantFoundationAction.ps1 infra/tests/pester/TenantFoundationProviderContracts.Tests.ps1 infra/tests/fixtures/runbooks/azure-devops-foundation.synthetic.json
git commit -m "feat(cloud): reconcile Azure DevOps foundation" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 8: Invocation, Partial Adoption, NoChange Rerun, Documentation, and Full Verification

**Files:**
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Invoke-TenantFoundationAction.ps1`
- Modify: module export lists and `Invoke-TenantFoundation.ps1`.
- Create: `infra/tests/pester/TenantFoundationInvocation.Tests.ps1`
- Modify: `infra/docs/runbooks/02-cloud-service-foundation.md`
- Modify: `infra/docs/runbooks/README.md`
- Modify: `infra/docs/README.md`
- Modify: `infra/README.md`

**Interfaces:**
- Consumes: approved Plan 1 manifest, Tasks 3-7.
- Produces one atomic action envelope per attempted action, exact provider read-back, and a second synthetic assessment with no `Create`/`Update`.
- The old filenames remain compatibility stops until this replacement passes acceptance; documentation must say so.

- [ ] **Step 1: Write failing invocation/recovery tests**

Cover `-WhatIf`, missing/expired/wrong approval, all drift dimensions, dependency stop, first failure stop, interrupted run, partial exact-ID adoption, uncertain mutation refusal, fresh reassessment, forward-only retry, unchanged second run, and no delete. Assert TEST/PROD calls are read-only and old stop files remain inert.

- [ ] **Step 2: Run RED**

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path @('infra/tests/pester/TenantFoundationInvocation.Tests.ps1','infra/tests/pester/CloudFoundationStaticSafety.Tests.ps1') -Output Detailed"
```

Expected: **FAIL** because final dispatch/recovery and replacement documentation are incomplete.

- [ ] **Step 3: Implement invocation and lean documentation**

Validate current bindings through Plan 1, invoke only actions whose prerequisites passed, call `ShouldProcess`, dispatch by exact provider/operation, write pre/post evidence atomically, update state after post-read, and stop at first failure. Document the new surface as implemented but not yet live-accepted; retain legacy compatibility notices.

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

Expected: all local suites/validators/builds **PASS**, no provider is contacted, no pipeline YAML/solution task is added, no workflow changes occur, and both old stop guards remain. Repeat focused module/entry tests with reviewed PowerShell 7.

- [ ] **Step 5: Perform focused review**

Map cloud spec sections 5-7 and 9-13 to tests. Scan for placeholders, broad catches, first-match selection, secret fallback, delete/rollback, queue/import calls, writable TEST/PROD, Tenant 2, or old-entry forwarding.

- [ ] **Step 6: Commit**

```powershell
git add infra/src/scripts infra/tests/pester infra/tests/fixtures/runbooks infra/docs infra/README.md
git commit -m "docs(cloud): complete foundation core contracts" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

## Completion Gate

Plan 3 is complete only when Plans 1-2 remain green, all provider contracts pass synthetically, capabilities that need live proof remain blocked, the second synthetic run contains no `Create`/`Update`, TEST/PROD are read-only, no pipeline is queued/imported, no live provider is contacted, and legacy entry points remain fail-closed compatibility notices.
