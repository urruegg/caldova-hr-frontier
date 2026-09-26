# Cloud Service Foundation Runbook Implementation Plan

| Field | Value |
|---|---|
| **Version** | 1.5 |
| **Date** | 2026-09-26 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Infrastructure cloud-foundation assessment, planning, attended delegated Apply, and verification |
| **References** | [Operational Runbooks Design](../../specs/2026-09-26-operational-runbooks-design.md), [Runbook Foundation and Windows 11 Workstation Plan](./2026-09-26-runbook-foundation-workstation.md), [Documentation Policy](../../README.md), [Infrastructure Domain](../../../infra/README.md), [Bootstrap Recovery](../../../infra/docs/19-bootstrap-recovery.md) |

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a local, attended, delegated-user cloud-foundation runbook that verifies exact service contexts, produces a deterministic digest-bound plan, applies supported provider changes, and reads back every approved outcome without inventing unsupported mutation paths.

**Architecture:** Two thin PowerShell entry points reuse the existing `Caldova.HrFrontier.Bootstrap` module and the shared canonical JSON, external-report, execution-manifest, and evidence contracts from the workstation-foundation plan. New cloud-specific module helpers read allowlisted identity and target metadata, compare stable IDs with one reviewed tenant manifest, and dispatch only digest-bound provider operations through injectable adapters: local `gh api` for non-Actions repository metadata/rulesets, delegated Azure CLI for Bicep subscription deployment and credential-free Entra target-resource metadata, and delegated `az devops` for supported project creation. The apply entry point revalidates executable identity, acting user, effective permissions, and target context; invokes `ShouldProcess` per provider action; performs idempotent check-then-act mutation; and reads back postconditions. Power Platform environments and SharePoint sites/configuration are always `Manual` in this increment, Azure DevOps service connections are `Blocked`, approvals/checks are `Manual`, and GitHub Environments, OIDC, workflows, pipelines, and credential-bearing paths remain excluded.

**Tech Stack:** Windows 11, Windows PowerShell 5.1, PowerShell 7, Pester 5.7.1, JSON, Git, GitHub CLI `gh api`, Azure CLI and Azure DevOps extension, Bicep `what-if`, Power Platform CLI, Microsoft Graph through `az rest`, and the existing `Caldova.HrFrontier.Bootstrap` PowerShell module.

**Spec:** `docs/specs/2026-09-26-operational-runbooks-design.md`

## Global Constraints

- This increment covers only shared cloud-specific helpers, `Get-CloudFoundationPlan.ps1`, `Invoke-CloudFoundation.ps1`, `infra/docs/runbooks/02-cloud-service-foundation.md`, related Pester/static tests, module exports, and Infrastructure documentation linkage.
- Do not create, edit, delete, dispatch, or depend on anything below `.github/workflows/`. Do not use GitHub Actions, `workflow_dispatch`, hosted or self-hosted runners, GitHub Environments, pipelines, OIDC, workload identity, or service-principal automation as an execution path.
- Every command runs locally and interactively from an administrator's Windows 11 workstation in Windows PowerShell 5.1 or PowerShell 7. Refuse CI, remoting, scheduled-task, service, background, and non-interactive hosts before authentication or cloud reads.
- Every cloud operation uses the attended administrator's delegated user identity. A target Microsoft Entra application or service principal is only a managed solution resource and is never selected, authenticated, or used as this kit's execution identity.
- Authentication is completed directly with the identity provider and retained only in supported CLI stores. Prefer `az login --tenant <tenantId> --use-device-code`, `gh auth login --hostname github.com --web --clipboard`, the verified Azure CLI delegated context for Azure DevOps CLI, and PAC `--deviceCode` profiles named exactly `hr-<TenantAlias>-<stage>` where `<stage>` is `dev`, `test`, or `prod`.
- Entry points do not accept password, token, PAT, secret, client-secret, certificate, credential, authorization-header, device-code value, authentication-environment-variable, or app/client identity parameters. They do not read, print, copy, serialize, or persist credentials or supported CLI token caches.
- Resolve every native executable with `Get-Command -CommandType Application -All`, canonicalize its absolute provider path, collapse only ordinal-insensitive duplicates of that same physical file, and require exactly one unique result. Record the absolute path, product version, and lowercase SHA-256 file digest in the plan. Re-resolve and re-hash immediately before every mutation, refuse path/hash/version drift or ambiguity, and invoke only the approved absolute path; never select the first PATH result.
- Reject `GH_TOKEN`, `GITHUB_TOKEN`, `AZURE_DEVOPS_EXT_PAT`, `SYSTEM_ACCESSTOKEN`, Azure/ARM client-id or client-secret environment authentication, PAC secret variables, `--with-token`, `az devops login`, service-principal login, federated login, and unattended/headless switches.
- Context read-back precedes service discovery, is repeated immediately before any approved action and at final verification, and compares exact account, user object ID, tenant, subscription, GitHub host/login/owner/repository ID, Azure DevOps organization and delegated acting user, PAC profile, Power Platform environment ID/URL, and SharePoint site ID/URL. For Azure DevOps `Existing` intent it additionally requires the exact reviewed project ID; for `Create` intent it instead proves zero exact-name matches and refuses ambiguity. Any mismatch refuses before non-identity reads or mutation.
- The selected tenant manifest remains the reviewed non-secret intent. Process exactly one tenant per run. Never infer an absent ID, select the first ambiguous result, mix tenant evidence, or combine `DEV`, `TEST`, and `PROD`.
- A provider write is planned only when its complete desired fields are already expressed by the reviewed tenant manifest, existing reviewed Bicep/parameter derivation, or existing reviewed GitHub ruleset file. If those sources do not express a value, preserve observed state or classify the operation `Blocked`; the runbook must not invent repository metadata, project descriptions, resource names, permissions, or service settings.
- Planning is the default and is read-only apart from canonical plan/evidence and Bicep build/parameter/what-if files in an approved external report directory. If supported by the installed Azure CLI, formatting is validation-only through `az bicep format --file <absoluteSource> --stdout`; discard or compare stdout and never permit in-place formatting. If `--stdout` is unsupported, omit formatting rather than modify source. Record the source Bicep SHA-256 before these operations and require the same hash afterward. Build uses an explicit external `--outfile`, subscription-scope `what-if`, and the existing `Test-WhatIfBoundary.ps1`; it never creates adjacent repository `main.json`. Apply repeats the source-hash check and may call exactly one digest-bound `az deployment sub create` with the exact external compiled-template bytes used for its repeated validated what-if, the exact generated parameter bytes, location, and subscription after provider-level `ShouldProcess`; no deployment stack, group deployment, alternate template, or implicit Bicep output path is allowed.
- Cloud mutation requires explicit `-Apply`, a fresh schema-valid execution manifest, an approval string equal to its lowercase SHA-256 digest, matching source commit and assessment digest, displayed exact actions, current permissions, context revalidation, `ShouldProcess`, postcondition read-back, and redacted evidence. `-WhatIf` always wins.
- Supported local delegated mutations are limited to exact digest-bound operations implemented and tested by this plan: non-Actions GitHub repository metadata/rulesets through `gh api`; the reviewed subscription-scope Bicep deployment through `az deployment sub create`; Azure DevOps project creation through `az devops project create`; and credential-free Entra target application/service-principal metadata through `az ad app create|update` and `az ad sp create` only after current official command verification. Azure DevOps project updates are `Blocked` unless a separate future review establishes an exact current delegated REST contract. Every other create/update is `Manual`, `Blocked`, or `Refused`, and none of those outcomes counts as complete.
- GitHub reads use only local `gh api` after `gh auth status` verifies `github.com`, the delegated login, secure credential storage, and the exact repository. No direct token retrieval and no raw HTTP authorization header are allowed.
- Azure DevOps operations use only the verified Azure CLI delegated user context and documented `az devops` commands. Do not create or run a pipeline. Where delegated support or exact permissions are not evidenced by current official documentation, emit a blocking/manual action.
- PAC authentication profiles are selected and verified one stage at a time with `pac auth list`, `pac auth select --name hr-<TenantAlias>-<stage>`, and `pac org who --environment <exactUrl>`. A profile-name overflow, duplicate profile, wrong URL/ID/user, or unsupported device-code syntax refuses the run.
- SharePoint discovery is metadata-only for exact manifest-declared site collections through Microsoft Graph delegated access. Do not read site content and do not fall back to tenant-wide content access.
- Every provider adapter receives a validated absolute `-RunDirectory` below the approved external report path and outside every Git working tree. Payloads, Bicep parameter files, and temporary response files are created only there with unique names; each adapter removes only files it created in `finally` and never recursively deletes the run directory.
- Evidence is constructed from the shared contract's closed common fields, closed safe provider read-back projections, and structured recovery items, and remains outside Git. Never serialize raw service responses, command output, provider-specific fields outside the shared allowlists, tokens, device codes, authorization headers, cookies, secrets, private keys, connection strings, SharePoint content, or HR/personal data.
- Every planning `ManualItems` record has exactly `service`, `targetId`, `condition`, `owner`, `diagnostic`, and `recovery`; do not emit the retired `decision` or `readBack` properties. Invocation recovery procedures belong in separate `RecoveryItems`, not in an alternate manual-item shape.
- Every planning evidence record uses `Status = 'Planned'` with `ShouldProcessDecision = 'NotApplicable'`. Invocation success uses `Verified`; partial or incomplete invocation uses `Failed` with an exact error category and structured recovery.
- Device-code policy blockage, MFA or Conditional Access denial, missing license/capacity, admin consent, role activation, organization creation, GitHub App authorization, unsupported API, and absent delegated automation are explicit attended `Manual` or terminal `Blocked` outcomes; never weaken policy or broaden permission automatically.
- Existing module exports and bootstrap behavior remain backward compatible. Do not call the legacy `Invoke-TenantDiscovery.ps1`, `Initialize-TenantTrust.ps1`, `Invoke-TenantBootstrap.ps1`, or `Enable-GitHubGovernance.ps1` from this runbook because they include environment-authenticated, OIDC, GitHub Environment, token extraction, or workflow-era contracts prohibited here.
- Tests use synthetic fixtures, injected command runners, and temporary external report paths. They never authenticate, contact a live tenant, mutate cloud state, inspect credential caches, or contain real tokens, tenant payloads, customer data, or HR data.
- ADR-0001, ADR-0002, and ADR-0003 remain Proposed Baseline. This plan neither promotes them nor changes stable HR architecture.
- Each checkbox is one 2–5 minute action. Stop after every command and compare its stated result; do not merge red, green, refactor, documentation, or commit gates.

## File Map

| File | Responsibility |
|---|---|
| `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/Invoke-CloudNativeCommand.ps1` | Runs one injected/native CLI command, captures stdout/stderr separately, rejects prohibited authentication environment state, and returns a sanitized result envelope. |
| `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Resolve-CloudNativeTool.ps1` | Resolves one unique absolute application path, version, and file digest and revalidates the same executable before mutation. |
| `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/Get-CloudServiceSnapshot.ps1` | Performs allowlisted post-context metadata reads for GitHub, Entra/Azure, Azure DevOps, Power Platform, and SharePoint without exposing raw responses. |
| `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/Invoke-GitHubFoundationMutation.ps1` | Executes idempotent local `gh api` PATCH/POST/PUT operations for reviewed non-Actions repository metadata and rulesets, then reads back exact state. |
| `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/Invoke-AzureFoundationMutation.ps1` | Executes the approved subscription-scope Bicep deployment or credential-free Entra target-resource metadata operation under the verified delegated Azure CLI user, then reads back exact state. |
| `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/Invoke-AzureDevOpsFoundationMutation.ps1` | Executes supported delegated `az devops project create`, after acting-identity and effective-permission verification, and polls exact project postconditions without invoking a pipeline. |
| `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Test-CloudDelegatedContext.ps1` | Verifies the local interactive host and exact delegated identity/target context for every selected service and stage. |
| `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Get-CloudFoundationAssessment.ps1` | Collects normalized, allowlisted cloud state after context verification and returns permission/manual/blocking findings. |
| `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/New-CloudFoundationActionPlan.ps1` | Compares reviewed intent with normalized assessment and emits deterministic `NoChange`, `Create`, `Update`, `Manual`, `Blocked`, or `Refused` actions. |
| `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Invoke-CloudFoundationAction.ps1` | Validates one approved action against the provider allowlist and dispatches it to exactly one private provider adapter. |
| `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Caldova.HrFrontier.Bootstrap.psd1` | Exports the five new public cloud functions without removing existing exports. |
| `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Caldova.HrFrontier.Bootstrap.psm1` | Mirrors the manifest export list at runtime. |
| `infra/src/scripts/runbooks/Get-CloudFoundationPlan.ps1` | Thin read-only entry point for tool resolution, context verification, assessment, Bicep `what-if`, deterministic plan/manifest creation, digest display, and provenance-complete redacted evidence. |
| `infra/src/scripts/runbooks/Invoke-CloudFoundation.ps1` | Thin `SupportsShouldProcess` entry point that validates approved plan integrity, dispatches supported provider writes, reads back postconditions, and stops safely on partial failure. |
| `infra/tests/fixtures/runbooks/cloud-contexts.json` | Synthetic successful and mismatched Azure, GitHub, Azure DevOps, PAC, Power Platform, and SharePoint command results. |
| `infra/tests/fixtures/runbooks/cloud-assessment.json` | Synthetic normalized service snapshot with exact stable IDs, permission findings, Bicep `what-if`, and manual conditions. |
| `infra/tests/pester/CloudDelegatedContext.Tests.ps1` | Context command construction, delegated-user continuity, stage profile naming, mismatch, and auth-environment refusal tests. |
| `infra/tests/pester/CloudFoundationPlanning.Tests.ps1` | Determinism, stable-ID comparison, permission delta, provider classification, one-tenant/stage boundaries, and no-mutation planning tests. |
| `infra/tests/pester/CloudFoundationProviderMutations.Tests.ps1` | Exact GitHub, Azure/Entra, and Azure DevOps command construction, idempotency, precondition, and postcondition tests. |
| `infra/tests/pester/CloudFoundationInvocation.Tests.ps1` | `-Apply`, digest, freshness, provider-level `ShouldProcess`, sequencing, final read-back, partial-state, recovery, and evidence tests. |
| `infra/tests/pester/CloudFoundationStaticSafety.Tests.ps1` | AST/text/path validator for forbidden parameters, commands, execution identities, workflows, GitHub Environments, pipelines, and credential handling. |
| `infra/tests/pester/RunbookDocumentation.Tests.ps1` | Extends the runbook documentation contract to cover the cloud-foundation procedure and links. |
| `infra/docs/runbooks/02-cloud-service-foundation.md` | Administrator procedure for attended sign-in, exact planning, approval, verification, manual/blocking work, cleanup, and recovery. |
| `infra/README.md` | Adds the cloud-foundation runbook to the Infrastructure documentation map after the runbook exists. |

No tenant manifest, schema, Bicep source, workflow, legacy bootstrap script, imported evidence file, or other documentation is changed by this plan.

## Exact Interfaces and Data Contracts

The implementation must preserve PowerShell 5.1 compatibility and use `[pscustomobject]`/ordered dictionaries rather than classes.

```powershell
Test-CloudDelegatedContext `
    -TenantConfiguration <object> `
    -ToolResolutions <object> `
    -NativeCommandRunner <scriptblock> `
    [-Stages <string[]>] `
    [-InteractiveHostProbe <scriptblock>]
# -> { schemaVersion, executionHost, principal, azure, github,
#      azureDevOps, powerPlatform[], verifiedAtUtc, overallStatus }

Get-CloudFoundationAssessment `
    -TenantConfiguration <object> `
    -VerifiedContext <object> `
    -ToolResolutions <object> `
    -RunDirectory <absolute-string> `
    -NativeCommandRunner <scriptblock> `
    [-NowUtc <datetime>] `
    [-WhatIfBoundaryValidator <scriptblock>]
# -> { schemaVersion, tenantAlias, assessedAtUtc, contextDigest,
#      services, permissionDelta, manualItems, blockedItems,
#      toolVersions, sourceCommit, overallStatus, assessmentDigest }

New-CloudFoundationActionPlan `
    -TenantConfiguration <object> `
    -Assessment <object>
# -> { actions, manifestActions }, where each actions item is exactly
#    { action, service, targetType, targetId, classification,
#      requiredPermission, method, uri, bodyDigest, providerInput,
#      expectedPostcondition, reason, recovery },
#    classification is one of
#    NoChange|Create|Update|Manual|Blocked|Refused,
#    and each manifestActions item uses the shared closed contract
#    with only { action, targetId, service, method, uri, bodyDigest, scope,
#    expectedPostcondition } where those fields apply

Invoke-CloudFoundationAction `
    -Action <object> `
    -TenantConfiguration <object> `
    -VerifiedContext <object> `
    -ToolResolutions <object> `
    -RunDirectory <string> `
    -NativeCommandRunner <scriptblock> `
    [-NowUtc <datetime>]
# -> { action, service, targetId, status, changed, readBack,
#      completedAtUtc, recovery }

Invoke-GitHubFoundationMutation|Invoke-AzureFoundationMutation|Invoke-AzureDevOpsFoundationMutation `
    -Action <object> `
    -TenantConfiguration <object> `
    -VerifiedContext <object> `
    -ToolResolutions <object> `
    -RunDirectory <absolute-string> `
    -NativeCommandRunner <scriptblock> `
    [-NowUtc <datetime>]
```

`readBack` is always a newly constructed member of the closed safe provider union defined below; `recovery` is either absent on success or is projected to the shared structured recovery-item shape. These return objects never expose the runner envelope, raw stdout/stderr, headers, or a deserialized provider response.

The native resolver and runner signatures are:

```powershell
Resolve-CloudNativeTool `
    -Name <az|gh|pac|git> `
    [-ApplicationResolver <scriptblock>] `
    [-FileHashProvider <scriptblock>] `
    [-VersionProvider <scriptblock>]
# -> { name, path, version, sha256 }, where path is absolute and sha256
#    is the lowercase digest of the executable file bytes

param([string]$FilePath, [string[]]$ArgumentList)
[pscustomobject]@{
    exitCode = 0
    stdout = '{"synthetic":"json"}'
    stderr = ''
}
```

`FilePath` is always the absolute `path` returned by `Resolve-CloudNativeTool`; a leaf command such as `az`, `gh`, `pac`, or `git` is never passed to the runner.

The plan entry point is:

```powershell
Get-CloudFoundationPlan.ps1 `
    -TenantAlias <string> `
    [-TenantConfigurationPath <string>] `
    [-ReportPath <string>] `
    [-Stages <DEV|TEST|PROD[]>] `
    [-NativeCommandRunner <scriptblock>] `
    [-NativeToolResolver <scriptblock>] `
    [-InteractiveHostProbe <scriptblock>] `
    [-NowUtc <datetime>]
```

It writes `cloud-assessment.json`, `cloud-plan.json`, `cloud-execution-manifest.json`, and `cloud-plan-evidence.json` through `Write-CanonicalJson`. `cloud-plan.json` contains the rich action plan and its lowercase canonical `planDigest`; the execution manifest binds the projected actions and tool identities. It calls the shared constructor exactly as defined by the foundation/workstation plan and does not wrap, overload, or reimplement it:

```powershell
New-RunbookExecutionManifest `
    -RunId <guid> `
    -Kind CloudFoundation `
    -TargetStableId <string> `
    -SourceCommit <40-hex> `
    -AssessmentDigest <64-hex> `
    -AuthenticationContext <object> `
    -AllowedActions <object[]> `
    -ToolVersions <object> `
    -GeneratedAtUtc <datetime>
```

The resulting manifest target is exactly `{ type = 'CloudFoundation'; stableId = <TargetStableId> }`. For this one-tenant run, `TargetStableId` is the selected manifest's exact `TenantId`; every service-specific stable ID remains bound in `AllowedActions`.

The invocation entry point is:

```powershell
Invoke-CloudFoundation.ps1 `
    -TenantAlias <string> `
    -ExecutionManifestPath <string> `
    -ApprovedDigest <string> `
    -AssessmentPath <string> `
    [-TenantConfigurationPath <string>] `
    [-ReportPath <string>] `
    [-NativeCommandRunner <scriptblock>] `
    [-NativeToolResolver <scriptblock>] `
    [-InteractiveHostProbe <scriptblock>] `
    [-NowUtc <datetime>] `
    [-Apply] `
    [-WhatIf]
```

It has `[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]`. It exposes no arbitrary mutator scriptblock: production dispatch is closed to the exported provider dispatcher, while the existing native-command runner seam supplies deterministic offline tests. Digest-bound supported `Create` and `Update` actions are applied only after provider-level `ShouldProcess`; `NoChange` is reverified; and any `Manual`, `Blocked`, or `Refused` action keeps the overall result incomplete.

Before calling the shared execution-manifest helper, project the richer verified context into its closed authentication object:

```powershell
$manifestAuthentication = [ordered]@{
    executionHost = 'InteractiveWindows11PowerShell'
    mode = 'AttendedDelegated'
    accountId = [string]$context.principal.id
    tenantId = [string]$context.azure.tenantId
    subscriptionId = [string]$context.azure.subscriptionId
    githubHost = 'github.com'
    githubLogin = [string]$context.github.login
    azureDevOpsOrganizationUrl = [string]$context.azureDevOps.organizationUrl
    azureDevOpsActingUserId = [string]$context.azureDevOps.actingUserId
}
if ($context.azureDevOps.projectIntent -ceq 'Existing') {
    $manifestAuthentication.azureDevOpsProjectId = [string]$context.azureDevOps.projectId
}
```

Azure DevOps organization and acting-user ID are always authentication-context fields. `azureDevOpsProjectId` is present only for `Existing` intent. For `Create` intent, the requested project name, uniquely resolved process ID/name, source control, visibility, and zero-match assessment are bound in the action `providerInput` and `bodyDigest`; the provider-returned project ID can exist only in post-mutation safe read-back and evidence. The three PAC profile names and Power Platform environment IDs remain bound by the assessment digest and by separate stage-scoped manifest actions; do not overload the shared singular `powerPlatformProfileName`/`powerPlatformEnvironmentId` fields or serialize the richer context wholesale.

Every evidence call uses the expanded shared constructor without a wrapper or fork:

```powershell
ConvertTo-RunbookEvidenceRecord `
    -RunId $runId `
    -Operation 'CloudFoundation' `
    -Classification $classification `
    -Status $status `
    -TargetId ([string]$tenant.TenantId) `
    -ToolVersions $toolVersions `
    -ReadBack $safeReadBack `
    -ManualItems $manualItems `
    -RecoveryItems $recoveryItems `
    -ErrorCategory $errorCategory `
    -GeneratedAtUtc $NowUtc `
    -SourceCommit $sourceCommit `
    -AssessmentDigest $assessment.assessmentDigest `
    -OperatorId ([string]$context.principal.id) `
    -ShouldProcessDecision $shouldProcessDecision `
    -PlanDigest $planDigest `
    -ManifestDigest $manifest.digest `
    -FinalContext $safeFinalContext
```

Planning evidence uses the shared enum values `Status = 'Planned'` and `ShouldProcessDecision = 'NotApplicable'`, omits `FinalContext` when no final read-back occurred, and supplies both plan and manifest digests after both artifacts exist. A completed invocation uses `Status = 'Verified'`. A partial mutation or an otherwise incomplete foundation uses `Status = 'Failed'`, never `Partial`, `Incomplete`, or `Succeeded`, and requires the exact applicable `ErrorCategory` plus at least one structured recovery item. Invocation `ShouldProcessDecision` uses the shared enum value selected by the shared contract for approved, declined, or WhatIf execution; the implementation must import those values from the shared validator tests rather than define a cloud-only enum.

For this runbook, project provider results into the shared safe read-back union only; omit inapplicable properties rather than adding nulls:

```text
Common:          service, targetId, status, expectedPostcondition
GitHub:          repositoryId, rulesetId, bodyDigest
Azure deployment: deploymentId, deploymentName, provisioningState, resourceIds
Entra:           objectId, appId, displayName, symmetricAuthCount, asymmetricAuthCount
Azure DevOps:    organizationUrl, projectId, projectName, processId, visibility, state
```

Each `RecoveryItems` element is a structured shared-contract object with exactly `service`, `targetId`, `lastProvenState`, `safeDiagnostic`, `owner`, `nextAction`, `requiresNewPlan`, and `requiresNewApproval`. Both Boolean fields are `true` before any retryable write. `ReadBack`, `FinalContext`, `ManualItems`, and `RecoveryItems` are newly constructed allowlisted projections; raw CLI/REST response objects and arbitrary nested provider properties are rejected before evidence construction.

The cloud `FinalContext` projection contains only `executionHost`, `principalId`, `tenantId`, `subscriptionId`, `githubHost`, `githubLogin`, `githubRepositoryId`, `azureDevOpsOrganizationUrl`, `azureDevOpsActingUserId`, optional `azureDevOpsProjectId` for `Existing` intent or after successful Create read-back, and stage entries containing only `stage`, `powerPlatformProfileName`, `powerPlatformEnvironmentId`, `powerPlatformEnvironmentUrl`, `sharePointSiteId`, and `sharePointWebUrl`. No provider response object is nested beneath those fields.

Every planning `ManualItems` element is projected to the shared exact shape:

```text
service, targetId, condition, owner, diagnostic, recovery
```

All six properties are non-empty strings. `diagnostic` is a sanitized diagnostic category, never provider output; `recovery` states the safe read-only verification and how to resolve or replan the condition. The obsolete properties `decision` and `readBack` are rejected.

---

### Task 1: Add the Delegated Context Verification Contract

**Files:**
- Create: `infra/tests/fixtures/runbooks/cloud-contexts.json`
- Create: `infra/tests/pester/CloudDelegatedContext.Tests.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Resolve-CloudNativeTool.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/Invoke-CloudNativeCommand.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Test-CloudDelegatedContext.ps1`
- Modify: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Caldova.HrFrontier.Bootstrap.psd1`
- Modify: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Caldova.HrFrontier.Bootstrap.psm1`

**Interfaces:**
- Consumes: `Import-TenantConfiguration`; injected application resolver returning application command objects; injected runner `param([string]$FilePath,[string[]]$ArgumentList)` returning `exitCode`, `stdout`, and `stderr`.
- Produces: public `Resolve-CloudNativeTool`; `Test-CloudDelegatedContext` with the exact signature and return shape in “Exact Interfaces and Data Contracts”; private `Invoke-CloudNativeCommand -ToolResolution <object> -ArgumentList <string[]> -Runner <scriptblock> [-Json]`.

- [ ] **Step 1: Create the synthetic context fixture**

Create a closed JSON object keyed by exact command string. Include successful responses for:

```json
{
  "C:\\SyntheticTools\\az.cmd|account show --output json": {
    "exitCode": 0,
    "stdout": "{\"id\":\"11111111-1111-1111-1111-111111111111\",\"tenantId\":\"22222222-2222-2222-2222-222222222222\",\"user\":{\"name\":\"admin@example.invalid\",\"type\":\"user\"}}",
    "stderr": ""
  },
  "C:\\SyntheticTools\\az.cmd|ad signed-in-user show --output json": {
    "exitCode": 0,
    "stdout": "{\"id\":\"user-object-synthetic\",\"userPrincipalName\":\"admin@example.invalid\"}",
    "stderr": ""
  },
  "C:\\SyntheticTools\\gh.exe|auth status --hostname github.com": {
    "exitCode": 0,
    "stdout": "Logged in to github.com account synthetic-admin; Token: stored in secure credential store",
    "stderr": ""
  },
  "C:\\SyntheticTools\\gh.exe|api user": {
    "exitCode": 0,
    "stdout": "{\"id\":12345,\"login\":\"synthetic-admin\"}",
    "stderr": ""
  },
  "C:\\SyntheticTools\\gh.exe|api repos/synthetic-owner/synthetic-repository": {
    "exitCode": 0,
    "stdout": "{\"id\":67890,\"name\":\"synthetic-repository\",\"full_name\":\"synthetic-owner/synthetic-repository\",\"owner\":{\"id\":54321,\"login\":\"synthetic-owner\"},\"permissions\":{\"admin\":true}}",
    "stderr": ""
  },
  "C:\\SyntheticTools\\az.cmd|devops project list --organization https://dev.azure.com/synthetic/ --query value[?name=='SyntheticProject'].{id:id,name:name,state:state,visibility:visibility} --output json": {
    "exitCode": 0,
    "stdout": "[]",
    "stderr": ""
  },
  "C:\\SyntheticTools\\az.cmd|devops invoke --organization https://dev.azure.com/synthetic/ --area location --resource connectionData --api-version 7.1-preview.1 --output json": {
    "exitCode": 0,
    "stdout": "{\"authenticatedUser\":{\"id\":\"ado-user-synthetic\",\"subjectDescriptor\":\"aad.synthetic-descriptor\",\"properties\":{\"Account\":{\"$value\":\"admin@example.invalid\"}}}}",
    "stderr": ""
  },
  "C:\\SyntheticTools\\az.cmd|rest --method get --url https://graph.microsoft.com/v1.0/me/transitiveMemberOf/microsoft.graph.directoryRole?$select=id,displayName,roleTemplateId --output json": {
    "exitCode": 0,
    "stdout": "{\"value\":[{\"id\":\"role-synthetic\",\"displayName\":\"Application Administrator\",\"roleTemplateId\":\"cf1c38e5-3621-4004-a7cb-879624dced7c\"}]}",
    "stderr": ""
  },
  "C:\\SyntheticTools\\pac.exe|auth list --json": {
    "exitCode": 0,
    "stdout": "[{\"name\":\"hr-synthetic-dev\",\"selected\":true,\"user\":\"admin@example.invalid\"}]",
    "stderr": ""
  },
  "C:\\SyntheticTools\\pac.exe|org who --environment https://synthetic-dev.crm.dynamics.com/ --json": {
    "exitCode": 0,
    "stdout": "{\"environmentId\":\"pp-env-dev-synthetic\",\"environmentUrl\":\"https://synthetic-dev.crm.dynamics.com/\",\"user\":\"admin@example.invalid\"}",
    "stderr": ""
  }
}
```

Add analogous unique TEST/PROD PAC entries. Use only `.invalid`, synthetic GUIDs, and synthetic IDs.

- [ ] **Step 2: Write failing context tests**

```powershell
Describe 'Cloud delegated context' {
    BeforeAll {
        $script:ModulePath = Join-Path $PSScriptRoot '..\..\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1'
        Import-Module $script:ModulePath -Force
    }

    It 'accepts only one attended delegated user and exact targets' {
        $result = Test-CloudDelegatedContext -TenantConfiguration $script:Tenant `
            -Stages @('DEV') -ToolResolutions $script:ToolResolutions `
            -NativeCommandRunner $script:Runner `
            -InteractiveHostProbe { [pscustomobject]@{ isInteractive = $true; platform = 'Windows 11' } }
        $result.overallStatus | Should -BeExactly 'Verified'
        $result.azure.userType | Should -BeExactly 'user'
        $result.github.repositoryId | Should -BeExactly '67890'
        $result.powerPlatform[0].profileName | Should -BeExactly 'hr-synthetic-dev'
    }

    It 'refuses before repository metadata when the GitHub host or login differs' {
        $calls = [Collections.Generic.List[string]]::new()
        $runner = New-CloudFixtureRunner -Overrides @{ 'gh|api user' = @{ exitCode = 0; stdout = '{"id":999,"login":"other"}'; stderr = '' } } -Calls $calls
        { Test-CloudDelegatedContext -TenantConfiguration $script:Tenant -Stages @('DEV') -ToolResolutions $script:ToolResolutions -NativeCommandRunner $runner -InteractiveHostProbe $script:Interactive } |
            Should -Throw '*GitHub delegated login does not match*'
        ($calls -join "`n") | Should -Not -Match 'repos/synthetic-owner/synthetic-repository'
    }

    It 'rejects service-principal Azure context and authentication environment variables' {
        { Test-CloudDelegatedContext -TenantConfiguration $script:Tenant -ToolResolutions $script:ToolResolutions -NativeCommandRunner $script:ServicePrincipalRunner -InteractiveHostProbe $script:Interactive } |
            Should -Throw '*delegated user*'
        foreach ($name in 'GH_TOKEN','GITHUB_TOKEN','AZURE_DEVOPS_EXT_PAT','SYSTEM_ACCESSTOKEN','AZURE_CLIENT_ID','AZURE_CLIENT_SECRET','ARM_CLIENT_ID','ARM_CLIENT_SECRET') {
            Set-Item "Env:$name" 'synthetic-prohibited'
            try {
                { Test-CloudDelegatedContext -TenantConfiguration $script:Tenant -ToolResolutions $script:ToolResolutions -NativeCommandRunner $script:Runner -InteractiveHostProbe $script:Interactive } |
                    Should -Throw '*prohibited authentication environment*'
            } finally { Remove-Item "Env:$name" }
        }

        It 'binds Azure DevOps and Entra authorization to the acting delegated user' {
            $result = Test-CloudDelegatedContext -TenantConfiguration $script:Tenant `
                -Stages @('DEV') -ToolResolutions $script:ToolResolutions `
                -NativeCommandRunner $script:Runner -InteractiveHostProbe $script:Interactive
            $result.azureDevOps.actingUserId | Should -BeExactly 'ado-user-synthetic'
            $result.azureDevOps.subjectDescriptor | Should -BeExactly 'aad.synthetic-descriptor'
            $result.azureDevOps.organizationUrl | Should -BeExactly 'https://dev.azure.com/synthetic/'
            $result.azureDevOps.projectIntent | Should -BeExactly 'Create'
            $result.azureDevOps.exactNameMatchCount | Should -Be 0
            $result.azureDevOps.PSObject.Properties.Name | Should -Not -Contain 'projectId'
            $result.entra.activeDirectoryRoleTemplateIds |
                Should -Contain 'cf1c38e5-3621-4004-a7cb-879624dced7c'
        }
    }
}

It 'refuses zero or multiple physical application paths' {
    { Resolve-CloudNativeTool -Name gh -ApplicationResolver { @() } } |
        Should -Throw '*exactly one unique application*'
    { Resolve-CloudNativeTool -Name gh -ApplicationResolver {
            @(
                [pscustomobject]@{ Source = 'C:\ToolsA\gh.exe'; Version = '2.80.0' },
                [pscustomobject]@{ Source = 'D:\ToolsB\gh.exe'; Version = '2.80.0' }
            )
        } } | Should -Throw '*ambiguous*'
}

It 'passes only the approved absolute executable path to the runner' {
    $result = Test-CloudDelegatedContext -TenantConfiguration $script:Tenant `
        -Stages @('DEV') -ToolResolutions $script:ToolResolutions `
        -NativeCommandRunner $script:Runner -InteractiveHostProbe $script:Interactive
    @($script:NativeCalls.FilePath | Select-Object -Unique) |
        Should -Be @('C:\SyntheticTools\az.cmd','C:\SyntheticTools\gh.exe','C:\SyntheticTools\pac.exe')
    @($script:NativeCalls | Where-Object { -not [IO.Path]::IsPathRooted($_.FilePath) }).Count |
        Should -Be 0
}
```

Add focused Azure DevOps context cases using separate tenant fixtures:

```powershell
It 'requires the reviewed project ID only for Existing intent' {
    $result = Test-CloudDelegatedContext -TenantConfiguration $script:ExistingProjectTenant `
        -ToolResolutions $script:ToolResolutions -NativeCommandRunner $script:ExistingRunner `
        -InteractiveHostProbe $script:Interactive
    $result.azureDevOps.projectIntent | Should -BeExactly 'Existing'
    $result.azureDevOps.projectId | Should -BeExactly 'ado-project-synthetic'
}

It 'requires exact-name absence and rejects ambiguity for Create intent' {
    $result = Test-CloudDelegatedContext -TenantConfiguration $script:CreateProjectTenant `
        -ToolResolutions $script:ToolResolutions -NativeCommandRunner $script:CreateAbsentRunner `
        -InteractiveHostProbe $script:Interactive
    $result.azureDevOps.exactNameMatchCount | Should -Be 0
    $result.azureDevOps.PSObject.Properties.Name | Should -Not -Contain 'projectId'

    { Test-CloudDelegatedContext -TenantConfiguration $script:CreateProjectTenant `
        -ToolResolutions $script:ToolResolutions -NativeCommandRunner $script:CreateAmbiguousRunner `
        -InteractiveHostProbe $script:Interactive } | Should -Throw '*ambiguous*'
}
```

- [ ] **Step 3: Run the context tests and verify the red state**

Run:

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester infra/tests/pester/CloudDelegatedContext.Tests.ps1 -Output Detailed -CI"
```

Expected: FAIL because `Test-CloudDelegatedContext` is not exported.

- [ ] **Step 4: Implement unique absolute tool resolution**

For each of `az`, `gh`, `pac`, and `git`, call `Get-Command -Name <name> -CommandType Application -All -ErrorAction Stop`, extract `Source`, resolve full paths, reject relative paths and reparse-point targets, de-duplicate only identical paths with `OrdinalIgnoreCase`, and require one unique path. Calculate `Get-FileHash -Algorithm SHA256`, normalize it to lowercase, collect the product version through that absolute executable, and return:

```powershell
[pscustomobject][ordered]@{
    name = 'gh'
    path = 'C:\Program Files\GitHub CLI\gh.exe'
    version = '2.80.0'
    sha256 = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'
}
```

Tests inject `FileHashProvider param([string]$Path)` and `VersionProvider param([string]$Path,[string]$Name)` for synthetic paths. Production uses `Get-FileHash -LiteralPath <absolutePath> -Algorithm SHA256` and invokes that same absolute path with the tool's non-mutating version arguments. Production never falls back to `$results[0]`, `Get-Command <name>` without `-All`, an alias, function, script, or PATH search performed at invocation time.

- [ ] **Step 5: Implement the private command boundary**

Implement `Invoke-CloudNativeCommand` to accept a validated tool-resolution object. First validate `ToolResolution.name` against the exact logical-name allowlist `az`, `gh`, `pac`, and `git`; never compare the absolute `FilePath`/`path` value to those leaf names. Separately require `ToolResolution.path` to be rooted and canonical, to identify the one uniquely resolved application, and to match the approved path/version/SHA-256 record. Reject the prohibited environment names before execution, capture stdout/stderr separately, reject empty JSON, and return parsed JSON only when `-Json` is set. Invoke `& $ToolResolution.path @ArgumentList`; never invoke the leaf name. Error text contains only the approved logical tool name and exit code, never stdout/stderr.

```powershell
$logicalName = [string]$ToolResolution.name
if ($logicalName -cnotin @('az','gh','pac','git')) {
    throw "Cloud command is not allowlisted: $logicalName"
}
$approvedPath = [string]$ToolResolution.path
if (-not [IO.Path]::IsPathRooted($approvedPath)) {
    throw 'The approved cloud executable path is not absolute.'
}
$approvedPath = [IO.Path]::GetFullPath($approvedPath)
$current = Resolve-CloudNativeTool -Name $logicalName
if (
    -not [IO.Path]::IsPathRooted([string]$current.path) -or
    -not ([IO.Path]::GetFullPath([string]$current.path)).Equals(
        $approvedPath, [StringComparison]::OrdinalIgnoreCase
    ) -or
    [string]$current.sha256 -cne [string]$ToolResolution.sha256 -or
    [string]$current.version -cne [string]$ToolResolution.version
) {
    throw "Approved cloud executable identity changed: $logicalName"
}
$prohibited = @('GH_TOKEN','GITHUB_TOKEN','AZURE_DEVOPS_EXT_PAT','SYSTEM_ACCESSTOKEN',
    'AZURE_CLIENT_ID','AZURE_CLIENT_SECRET','AZURE_FEDERATED_TOKEN_FILE',
    'ARM_CLIENT_ID','ARM_CLIENT_SECRET','ARM_OIDC_TOKEN','POWERPLATFORMCLIENTSECRET')
foreach ($name in $prohibited) {
    if (-not [string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($name))) {
        throw "A prohibited authentication environment variable is set: $name"
    }
}
# Only after all name, path, uniqueness, hash, version, and environment checks:
$nativeResult = & $Runner $approvedPath $ArgumentList
```

`Resolve-CloudNativeTool` provides the zero/multiple-result and reparse-point checks used by this guard. The production runner receives `FilePath = $approvedPath` and invokes exactly `& $FilePath @ArgumentList`; it performs no PATH lookup. The snippet is normative: the allowlist operand is `$ToolResolution.name`, never `$FilePath` or `$ToolResolution.path`. The absolute path is independently canonicalized, uniquely re-resolved, hash/version compared, and supplied to the runner as `FilePath`. Add a negative test in which `name = 'gh'` and `path = 'C:\SyntheticTools\gh.exe'` succeeds, while `name = 'C:\SyntheticTools\gh.exe'`, a relative path, a second unique path, or a changed hash/version fails before the runner is called.

- [ ] **Step 6: Implement exact context checks**

Issue only these read-back argument families, in order, through the matching absolute tool-resolution path: `az account show`, `az ad signed-in-user show`, Microsoft Graph `/me/transitiveMemberOf/microsoft.graph.directoryRole`, `gh auth status`, `gh api user`, `gh api repos/{owner}/{repo}`, Azure DevOps `connectionData`, the intent-specific Azure DevOps project read below, then stage-specific `pac auth list`, `pac auth select --name <profile>` when not already selected, and `pac org who --environment <url>`. Require Azure `user.type` to equal `user`; require Azure DevOps `connectionData.authenticatedUser` ID, descriptor, and account UPN to identify that same reviewed administrator; compare UPN case-insensitively and every stable ID and URL ordinally after only documented trailing-slash normalization. Record active Entra directory role IDs/template IDs but never infer eligibility as activation.

Always return Azure DevOps `organizationUrl`, `actingUserId`, `subjectDescriptor`, and allowlisted account name. For `Existing` project intent, call `az devops project show --organization <url> --project <reviewedProjectId> --output json`, require the returned ID, name, organization, process, and visibility to match reviewed intent, and return `projectIntent = 'Existing'` plus `projectId`. For `Create` intent, do not require a nonexistent ID: call `az devops project list --organization <url> --query "value[?name=='<escapedExactName>'].{id:id,name:name,state:state,visibility:visibility}" --output json`, compare names ordinally after parsing, and return `projectIntent = 'Create'`, `requestedProjectName`, and `exactNameMatchCount = 0`. One exact match makes Create intent a conflict to classify rather than an absent target; more than one exact match is `Ambiguous` and blocks planning. Never select the first result. In both paths resolve the requested process name to one process ID and retain the effective `Create new projects` permission result when creation is requested.

Reject duplicate PAC profile names and calculate names as:

```powershell
$profileName = 'hr-{0}-{1}' -f $TenantConfiguration.TenantAlias, $stage.ToLowerInvariant()
if ($profileName.Length -gt 60) {
    throw 'The deterministic PAC profile name exceeds the supported reviewed limit.'
}
```

Return only allowlisted fields; never include raw command text or output.

- [ ] **Step 7: Export the helper and verify green**

Append `'Resolve-CloudNativeTool'` and `'Test-CloudDelegatedContext'` to `FunctionsToExport` in both module files without changing existing entries.

Run:

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester infra/tests/pester/CloudDelegatedContext.Tests.ps1,infra/tests/pester/TenantConfiguration.Tests.ps1 -Output Detailed -CI"
```

Expected: PASS; no fixture call contains `login`, `--with-token`, a token read, a GitHub Environment endpoint, or a pipeline command.

- [ ] **Step 8: Commit the delegated-context contract**

```powershell
git add -- infra/tests/fixtures/runbooks/cloud-contexts.json infra/tests/pester/CloudDelegatedContext.Tests.ps1 infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap
git commit -m "feat(infra): verify delegated cloud contexts"
```

Expected: one focused commit and no staged path below `.github/workflows/`.

---

### Task 2: Build Normalized Cloud Assessment and Action Classification

**Files:**
- Create: `infra/tests/fixtures/runbooks/cloud-assessment.json`
- Create: `infra/tests/pester/CloudFoundationPlanning.Tests.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/Get-CloudServiceSnapshot.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Get-CloudFoundationAssessment.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/New-CloudFoundationActionPlan.ps1`
- Modify: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Caldova.HrFrontier.Bootstrap.psd1`
- Modify: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Caldova.HrFrontier.Bootstrap.psm1`

**Interfaces:**
- Consumes: verified context from Task 1; validated external `RunDirectory`; `Get-RunbookContentDigest`; existing `Test-WhatIfBoundary.ps1`; reviewed tenant `Components`.
- Produces: the exact assessment and action contracts above; classifications only from `NoChange`, `Create`, `Update`, `Manual`, `Blocked`, and `Refused`.

- [ ] **Step 1: Create a sanitized normalized assessment fixture**

Use one synthetic base tenant with `GitHubRepository`, `AzureSubscription`, and three Power Platform environments matching exact IDs. Add two explicit Azure DevOps fixture variants: `Existing` contains a reviewed project ID and matching ID-based read-back; `Create` contains no project ID, a reviewed requested name/process/visibility, and zero exact-name candidates. Add a separate two-match response for ambiguity tests. Include `EntraApplication` and `EntraServicePrincipal` as absent, no GitHub Environment object, and these findings:

```json
{
  "permissionDelta": [
    {
      "service": "GitHub",
      "targetId": "67890",
      "capability": "RepositoryMetadataRead",
      "status": "Satisfied"
    }
  ],
  "manualItems": [
    {
      "service": "AzureDevOps",
      "targetId": "azuredevops://https://dev.azure.com/synthetic/SyntheticProject/github-connection",
      "condition": "The first Azure Boards GitHub connection requires attended authorization.",
      "owner": "Azure DevOps organization administrator",
      "diagnostic": "ConnectionNotVerified",
      "recovery": "Open Project settings, verify the exact GitHub connection, authorize it interactively if absent, rerun assessment, and generate a new plan."
    }
  ],
  "blockedItems": [
    {
      "service": "GitHub",
      "reason": "GitHub Environment operations are excluded from the local cloud-foundation kit."
    }
  ]
}
```

Do not include access tokens, response bodies, employee data, real domains, or real tenant identifiers.

Assert every planning manual item has exactly `service`, `targetId`, `condition`, `owner`, `diagnostic`, and `recovery`, with no `decision` or `readBack` property:

```powershell
foreach ($item in $script:Assessment.manualItems) {
    @($item.PSObject.Properties.Name) |
        Should -Be @('service','targetId','condition','owner','diagnostic','recovery')
}
($script:Assessment.manualItems | ConvertTo-Json -Depth 10) |
    Should -Not -Match '"(decision|readBack)"\s*:'
```

- [ ] **Step 2: Write failing planning tests**

```powershell
It 'maps exact existing IDs to NoChange and excluded intent to Blocked' {
    $plan = New-CloudFoundationActionPlan -TenantConfiguration $script:Tenant -Assessment $script:Assessment
    ($plan.actions | Where-Object targetType -eq 'GitHubRepository').classification | Should -BeExactly 'NoChange'
    ($plan.actions | Where-Object targetType -eq 'GitHubEnvironment').classification | Should -BeExactly 'Blocked'
    ($plan.actions | Where-Object targetType -eq 'EntraFederatedIdentityCredential').classification | Should -BeExactly 'Blocked'
}

It 'emits only the complete closed classification set' {
    $plan = New-CloudFoundationActionPlan -TenantConfiguration $script:Tenant -Assessment $script:Assessment
    $allowed = @('NoChange','Create','Update','Manual','Blocked','Refused')
    @($plan.actions | Where-Object { $_.classification -cnotin $allowed }).Count | Should -Be 0
}

It 'automates only the reviewed provider allowlist' {
    $plan = New-CloudFoundationActionPlan -TenantConfiguration $script:Tenant -Assessment $script:Assessment
    @($plan.actions | Where-Object classification -in @('Create','Update')).action |
        Should -Be @('UpsertGitHubNonActionsRuleset','DeployAzureFoundation','CreateAzureDevOpsProject')
    ($plan.actions | Where-Object targetType -eq 'AzureDevOpsServicePrincipalEntitlement').classification | Should -BeExactly 'Blocked'
    $verifyAction = $plan.manifestActions | Where-Object action -eq 'VerifyExistingResource' | Select-Object -First 1
    @($verifyAction.PSObject.Properties.Name) |
        Should -Be @('action','targetId','service','method','uri','scope','expectedPostcondition')
}

It 'is deterministic for identical normalized input' {
    $first = New-CloudFoundationActionPlan -TenantConfiguration $script:Tenant -Assessment $script:Assessment
    $second = New-CloudFoundationActionPlan -TenantConfiguration $script:Tenant -Assessment $script:Assessment
    (Get-RunbookContentDigest $first) | Should -BeExactly (Get-RunbookContentDigest $second)
}

It 'requires bodyDigest only for Create and Update actions' {
    $plan = New-CloudFoundationActionPlan -TenantConfiguration $script:Tenant -Assessment $script:Assessment
    foreach ($richAction in $plan.actions) {
        $manifestAction = $plan.manifestActions |
            Where-Object { $_.action -ceq $richAction.action -and $_.targetId -ceq $richAction.targetId } |
            Select-Object -First 1
        if ($richAction.classification -in @('Create','Update')) {
            $manifestAction.bodyDigest | Should -Match '^[0-9a-f]{64}$'
            @($manifestAction.PSObject.Properties.Name) |
                Should -Be @('action','targetId','service','method','uri','bodyDigest','scope','expectedPostcondition')
        }
        else {
            $manifestAction.PSObject.Properties.Name | Should -Not -Contain 'bodyDigest'
        }
    }
}
```

Add assessment cases proving Entra application Create is emitted only after a successful `az ad app list --display-name <reviewedName> --output json` response with zero ordinal exact-name matches. Assert one exact match becomes `Blocked` pending reviewed identity adoption, multiple exact matches become `Blocked` as ambiguous, and 401/403, nonzero exit, malformed JSON, or unavailable output becomes `Blocked` rather than `Missing`. Add equivalent service-principal cases using the reviewed exact `appId`; assert `CreateEntraTargetServicePrincipal` is possible only after a successful zero-match `az ad sp list --filter "appId eq '<exactAppId>'" --output json`, and is blocked when that appId would only be learned from an application created in the same plan.

- [ ] **Step 3: Run the planning tests and verify the red state**

Run:

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester infra/tests/pester/CloudFoundationPlanning.Tests.ps1 -Output Detailed -CI"
```

Expected: FAIL because the assessment and action-plan functions do not exist.

- [ ] **Step 4: Implement allowlisted service snapshots**

Implement these read-only command families and reject any other operation:

```text
GitHub:       gh api repos/{owner}/{repository}
              gh api repos/{owner}/{repository}/rulesets
Entra:       az ad app show --id <reviewed-object-id>
              az ad app list --display-name <reviewed-name> --output json
              az ad sp show --id <reviewed-object-id>
              az ad sp list --filter "appId eq '<exact-appId>'" --output json
Azure:       az role assignment list --scope /subscriptions/<subscriptionId> --output json
              az deployment sub what-if ... --result-format FullResourcePayloads --no-pretty-print
AzureDevOps: az devops project show ...
              az devops invoke for repositories, service endpoints, environments, and checks metadata only
PowerPlatform: pac org who --environment <exact-stage-url> --json
SharePoint:  az rest --method get --url https://graph.microsoft.com/v1.0/sites/<host>:/<path>?$select=id,displayName,webUrl
```

Do not query GitHub Actions permissions, workflows, GitHub Environments, secrets, variable values, pipeline runs, SharePoint content, or broad directory listings. For Entra application `Create` intent without an object ID, call the official delegated `az ad app list --display-name <reviewedName> --output json`, then apply an ordinal exact `displayName` filter locally: zero exact matches is `Missing`, one is `FoundConflict` and must not be silently adopted, and more than one is `Ambiguous`. A 401/403, unsupported command, malformed response, timeout, or other unavailable result is `Blocked`, never absence. Once an exact application `appId` is reviewed or returned by a successful create, locate its service principal only with `az ad sp list --filter "appId eq '<exactAppId>'" --output json`, filter returned `appId` values ordinally, and apply the same zero/one/multiple rules. Never select the first result.

- [ ] **Step 5: Implement normalized assessment**

Require `VerifiedContext.overallStatus -ceq 'Verified'`, exact tenant alias/context, and a context age no greater than five minutes. Construct a new ordered result rather than serializing command responses. Set `overallStatus` to `Blocked` for any unauthorized, unavailable, ambiguous, mismatched, invalid what-if, missing license/capacity, or unsupported delegated capability; otherwise `Ready`.

Set `toolVersions` from the supplied tool-resolution records without modification. For each required tool, require exactly `name`, absolute `path`, `version`, and lowercase 64-hex `sha256`; reject duplicate names and duplicate leaf names resolving to different physical files.

The assessment includes allowlisted authorization facts, not role-name assumptions: Entra signed-in user object ID plus active directory `roleTemplateId` values from `/me/transitiveMemberOf/microsoft.graph.directoryRole`; Entra application exact-name match count and service-principal exact-appId match count without retaining raw list responses; Azure DevOps Connection Data `authenticatedUser.id`, subject descriptor, and account name; and the effective allow/deny result for the exact `Create new projects` action in namespace `52d39943-cb85-4d7f-8fa8-c6baac873819` at collection token `$PROJECT:vstfs:///Classification/TeamProject/`. Missing, unauthorized, ambiguous, or contradictory identity/permission read-back makes the corresponding mutation `Blocked`; unavailable Entra discovery never becomes `Missing`.

Calculate `assessmentDigest` over the object without that property:

```powershell
$unsigned = [ordered]@{
    schemaVersion = '1.0'
    tenantAlias = [string]$TenantConfiguration.TenantAlias
    assessedAtUtc = $NowUtc.ToUniversalTime().ToString('o')
    contextDigest = Get-RunbookContentDigest -InputObject $VerifiedContext
    services = $normalizedServices
    permissionDelta = @($permissionDelta)
    manualItems = @($manualItems)
    blockedItems = @($blockedItems)
    toolVersions = $toolVersions
    sourceCommit = $sourceCommit
    overallStatus = $overallStatus
}
```

- [ ] **Step 6: Implement explicit action classification**

Sort actions by `service`, `targetType`, and `targetId`. Existing exact-ID matches become `NoChange`; supported drift becomes `Update`; supported reviewed absence becomes `Create`; and a mismatched `Existing` stable ID becomes `Refused`. Emit only these automated action names:

```powershell
$automatedActions = @(
    'UpdateGitHubRepositoryMetadata',
    'UpsertGitHubNonActionsRuleset',
    'DeployAzureFoundation',
    'CreateAzureDevOpsProject',
    'CreateEntraTargetApplication',
    'UpdateEntraTargetApplication',
    'CreateEntraTargetServicePrincipal'
)
```

`UpdateGitHubRepositoryMetadata` may contain only reviewed `description`, `homepage`, `has_issues`, `has_projects`, `has_wiki`, `allow_merge_commit`, `allow_squash_merge`, `allow_rebase_merge`, and `delete_branch_on_merge` fields. `UpsertGitHubNonActionsRuleset` accepts a reviewed ruleset only when every rule is one of `deletion`, `non_fast_forward`, or `pull_request`. It must not silently remove `required_status_checks` from `infra/src/config/github/main-ruleset.json`: because the current file contains that Actions-dependent rule, its current ruleset action is `Blocked` until a separately reviewed non-Actions desired-state change is approved outside this plan. The adapter and synthetic TDD fixture still prove supported non-Actions ruleset create/update behavior. The plan records the exact canonical request-body digest, method, endpoint, and expected read-back.

`DeployAzureFoundation` is emitted only after recording the source Bicep hash; optionally running exactly `az bicep format --file <absoluteSource> --stdout` when local help proves `--stdout` support; confirming the source hash is unchanged; running `az bicep build --file <repositoryMainBicep> --outfile <exactExternalRunDirectoryTemplatePath>`; generating parameters into the external run directory; running subscription `what-if` against that compiled template; passing `Test-WhatIfBoundary.ps1`; and obtaining exact compiled-template/parameter digests. Formatting stdout is discarded or compared only, and formatting is omitted if `--stdout` is unavailable. No adjacent repository `main.json` may be created. The generated `validationPrincipalId` must resolve to an approved target solution resource and the current Azure context must still be the delegated user; if the manifest describes that principal as the bootstrap/runbook execution identity, deployment is `Blocked`.

`CreateAzureDevOpsProject` is emitted only for reviewed `Create` intent with zero ordinal exact-name candidates, a uniquely resolved process ID/name, verified organization and acting identity, and effective `Create new projects` permission. Its pre-create `targetId` is the canonical non-secret logical target `azuredevops://<organization>/<requestedProjectName>`, never an invented project GUID. Its canonical `providerInput` binds `organizationUrl`, requested `name`, `processId`, `processName`, `sourceControl = 'git'`, and requested `visibility` before creation. A single existing exact-name result is not absence and is classified from its observed state; multiple results are `Blocked` as ambiguous. For reviewed `Existing` intent, require exact project ID read-back; exact state is `NoChange` and metadata drift is `Blocked`. No unreviewed CLI or REST update contract is inferred. The project ID returned by create is not invented or prebound: it is captured after creation, used for all polling/read-back, and persisted only in the closed safe read-back/evidence projection.

Use these fixed mappings for unsupported reviewed intent:

```powershell
$blockedTypes = @(
    'EntraFederatedIdentityCredential',
    'GitHubEnvironment',
    'AzureDevOpsServicePrincipalEntitlement',
    'AzureDevOpsReadersMembership',
    'AzureDevOpsServiceConnection'
)
$manualTypes = @(
    'PowerPlatformEnvironmentDev',
    'PowerPlatformEnvironmentTest',
    'PowerPlatformEnvironmentProd',
    'SharePointSiteDev',
    'SharePointSiteTest',
    'SharePointSiteProd',
    'AzureDevOpsApproval',
    'AzureDevOpsCheck',
    'AzureBoardsGitHubConnection'
)
```

Automate Entra application display-name/identifier metadata and service-principal creation only when reviewed architecture identifies them as target solution resources, the delegated user has the documented active directory role, no credential or federated identity is requested, and exact-name/app-ID discovery is unambiguous. Application Create requires a successful delegated list with zero ordinal exact-name matches. One exact-name application without the reviewed object ID is a `Blocked` identity-adoption decision; multiple are `Blocked` as ambiguous. Service-principal Create requires an app `appId` already known and reviewed at planning time, a successful delegated exact-appId list, and zero matches; one exact match is assessed by its ID and multiple are `Blocked`. If the application itself must be created by the current plan, classify the dependent service-principal creation `Blocked` with recovery to apply/read back the app, reassess using its returned `appId`, and approve a new plan—never substitute an unknown future appId into a digest-bound action. If current intent identifies them as bootstrap, OIDC, or execution identities, classify them `Blocked`. For this increment the classifications are immutable: Power Platform environments are `Manual`; SharePoint sites and site configuration are `Manual`; Azure DevOps service connections are `Blocked`; and Azure DevOps approvals/checks are `Manual`. Azure DevOps organization creation and Azure Boards GitHub App authorization are also `Manual`. Implementation must not promote any of these surfaces to automated based on ad hoc tool availability.

Project each sorted action into the shared closed execution-manifest action contract; do not redefine that contract. Its complete allowed property set is `action`, `targetId`, `service`, `method`, `uri`, `bodyDigest`, `packageSource`, `packageId`, `scope`, `requiredVersion`, `sourceRelativePath`, `destinationRelativePath`, `replacementRuleId`, and `expectedPostcondition`. Map classifications to action names exactly as follows: `NoChange` to `VerifyExistingResource`, `Manual` to `CompleteAttendedManualAction`, `Blocked` to `ResolveBlockedIntent`, and `Refused` to `RefuseMismatchedTarget`.

Every cloud projection contains `action`, `targetId`, `service`, `scope`, and `expectedPostcondition`. A `VerifyExistingResource` projection contains `method = 'GET'` and the exact non-secret metadata `uri`. A `Create` or `Update` mutation must contain its exact `method`, non-secret `uri`, and lowercase SHA-256 `bodyDigest`; `bodyDigest` is forbidden for `NoChange`, `Manual`, `Blocked`, and `Refused`. For CLI operations the URI is the canonical logical target such as `azure://subscriptions/<id>/deployments/<name>` or `azuredevops://<organization>/<projectName>`. Compute `bodyDigest` over canonical `providerInput`: GitHub request fields; Azure template digest, parameter digest, accepted what-if digest, location, deployment name, and validation-principal ID; Entra metadata; or Azure DevOps project fields and process ID. Manual, blocked, and refused projections also omit mutation `method` and `uri` because no request is authorized. Cloud actions never use package or customer-export properties. Do not pass the richer action objects directly to `New-RunbookExecutionManifest`.

Add Pester cases proving missing `bodyDigest` fails for every `Create`/`Update`, and any `bodyDigest` fails for `NoChange`, `Manual`, `Blocked`, or `Refused`, before manifest creation.

A synthetic Azure manifest action is exactly:

```json
{
  "action": "DeployAzureFoundation",
  "targetId": "11111111-1111-1111-1111-111111111111",
  "service": "Azure",
  "method": "AZCLI",
  "uri": "azure://subscriptions/11111111-1111-1111-1111-111111111111/deployments/cf-synthetic-0123456789ab",
  "bodyDigest": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "scope": "/subscriptions/11111111-1111-1111-1111-111111111111",
  "expectedPostcondition": "Deployment Succeeded and every approved resource ID matches the accepted what-if."
}
```

- [ ] **Step 7: Export helpers and run focused regressions**

Add exactly:

```powershell
'Get-CloudFoundationAssessment',
'New-CloudFoundationActionPlan'
```

to both module export lists.

Run:

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester infra/tests/pester/CloudFoundationPlanning.Tests.ps1,infra/tests/pester/IntentGate.Tests.ps1,infra/tests/pester/WhatIfBoundary.Tests.ps1,infra/tests/pester/SharePointDiscovery.Tests.ps1 -Output Detailed -CI"
```

Expected: PASS; supported provider drift becomes digest-bound `Create`/`Update`, unsupported surfaces remain manual/blocking, and existing intent validation, what-if boundaries, and SharePoint metadata behavior remain compatible.

- [ ] **Step 8: Commit assessment and classification**

```powershell
git add -- infra/tests/fixtures/runbooks/cloud-assessment.json infra/tests/pester/CloudFoundationPlanning.Tests.ps1 infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap
git commit -m "feat(infra): plan cloud foundation under delegated identity"
```

Expected: one reviewable planning-only commit with no provider execution code.

---

### Task 3: Implement the Read-Only Cloud Foundation Plan Entry Point

**Files:**
- Create: `infra/src/scripts/runbooks/Get-CloudFoundationPlan.ps1`
- Modify: `infra/tests/pester/CloudFoundationPlanning.Tests.ps1`

**Interfaces:**
- Consumes: Tasks 1–2 helpers plus `Import-TenantConfiguration`, `Resolve-RunbookReportPath`, `Write-CanonicalJson`, `New-RunbookExecutionManifest`, and `ConvertTo-RunbookEvidenceRecord` from the workstation-foundation plan.
- Produces: the exact plan entry-point signature; canonical assessment, execution-manifest, and evidence files; console output containing only target summary and digest.

- [ ] **Step 1: Add a failing end-to-end planning test**

```powershell
It 'writes a digest-bound plan outside Git without cloud mutation' {
    $report = Join-Path $TestDrive 'external-report'
    $bicepPath = Join-Path $script:RepositoryRoot 'infra\src\bicep\main.bicep'
    $sourceHashBefore = (Get-FileHash -LiteralPath $bicepPath -Algorithm SHA256).Hash
    $result = & $script:PlanScript -TenantAlias 'synthetic' `
        -TenantConfigurationPath $script:TenantPath -ReportPath $report `
        -Stages @('DEV','TEST','PROD') -NativeCommandRunner $script:Runner `
        -InteractiveHostProbe { [pscustomobject]@{ isInteractive = $true; platform = 'Windows 11' } } `
        -NowUtc ([datetime]'2026-09-26T06:00:00Z')

    $result.digest | Should -Match '^[0-9a-f]{64}$'
    $result.target.type | Should -BeExactly 'CloudFoundation'
    $result.target.stableId | Should -BeExactly $script:Tenant.TenantId
    $result.sourceCommit | Should -Match '^[0-9a-f]{40}$'
    $result.assessmentDigest | Should -Match '^[0-9a-f]{64}$'
    Test-Path (Join-Path $report 'cloud-assessment.json') | Should -BeTrue
    Test-Path (Join-Path $report 'cloud-plan.json') | Should -BeTrue
    Test-Path (Join-Path $report 'cloud-execution-manifest.json') | Should -BeTrue
    $evidence = Get-Content -Raw (Join-Path $report 'cloud-plan-evidence.json') | ConvertFrom-Json
    $evidence.generatedAtUtc | Should -BeExactly '2026-09-26T06:00:00.0000000Z'
    $evidence.sourceCommit | Should -Match '^[0-9a-f]{40}$'
    $evidence.assessmentDigest | Should -BeExactly $result.assessmentDigest
    $evidence.operatorId | Should -BeExactly 'user-object-synthetic'
    $evidence.status | Should -BeExactly 'Planned'
    $evidence.shouldProcessDecision | Should -BeExactly 'NotApplicable'
    $evidence.planDigest | Should -Match '^[0-9a-f]{64}$'
    $evidence.manifestDigest | Should -BeExactly $result.digest
    (Get-FileHash -LiteralPath $bicepPath -Algorithm SHA256).Hash |
        Should -BeExactly $sourceHashBefore
    Test-Path (Join-Path (Split-Path $bicepPath -Parent) 'main.json') | Should -BeFalse
    foreach ($item in $evidence.manualItems) {
        @($item.PSObject.Properties.Name) |
            Should -Be @('service','targetId','condition','owner','diagnostic','recovery')
    }
    ($script:Calls -join "`n") | Should -Not -Match '(?i)\b(create|update|delete|deploy|login|dispatch|pipeline run)\b'
}
```

- [ ] **Step 2: Run the entry-point test and verify the red state**

Run:

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester infra/tests/pester/CloudFoundationPlanning.Tests.ps1 -Output Detailed -CI"
```

Expected: FAIL because `infra/src/scripts/runbooks/Get-CloudFoundationPlan.ps1` does not exist.

- [ ] **Step 3: Implement parameter and prerequisite validation**

Use `[CmdletBinding()]`, strict mode, terminating errors, `ValidatePattern('^[a-z0-9]+$')` for `TenantAlias`, and `ValidateSet('DEV','TEST','PROD')` for stages. Resolve the default manifest to `infra/src/config/tenants/<TenantAlias>.psd1`, require `LifecycleState = IntentReviewed`, and call the shared external-report resolver before any cloud command.

- [ ] **Step 4: Implement read-only orchestration**

Use this exact order:

```powershell
$tenant = Import-TenantConfiguration -Path $resolvedTenantPath -ValidationStage Bootstrap
$runId = [guid]::NewGuid()
$toolResolutions = [ordered]@{}
foreach ($name in @('az','gh','pac','git')) {
    $toolResolutions[$name] = Resolve-CloudNativeTool -Name $name `
        -ApplicationResolver $NativeToolResolver
}
$context = Test-CloudDelegatedContext -TenantConfiguration $tenant -Stages $Stages `
    -ToolResolutions $toolResolutions -NativeCommandRunner $NativeCommandRunner `
    -InteractiveHostProbe $InteractiveHostProbe
$assessment = Get-CloudFoundationAssessment -TenantConfiguration $tenant `
    -VerifiedContext $context -ToolResolutions $toolResolutions `
    -RunDirectory $resolvedReportPath `
    -NativeCommandRunner $NativeCommandRunner -NowUtc $NowUtc
$actionPlan = New-CloudFoundationActionPlan -TenantConfiguration $tenant -Assessment $assessment
$planDigest = Get-RunbookContentDigest -InputObject $actionPlan
$manifestAuthentication = [ordered]@{
    executionHost = 'InteractiveWindows11PowerShell'
    mode = 'AttendedDelegated'
    accountId = [string]$context.principal.id
    tenantId = [string]$context.azure.tenantId
    subscriptionId = [string]$context.azure.subscriptionId
    githubHost = 'github.com'
    githubLogin = [string]$context.github.login
    azureDevOpsOrganizationUrl = [string]$context.azureDevOps.organizationUrl
    azureDevOpsActingUserId = [string]$context.azureDevOps.actingUserId
}
if ($context.azureDevOps.projectIntent -ceq 'Existing') {
    $manifestAuthentication.azureDevOpsProjectId = [string]$context.azureDevOps.projectId
}
$manifest = New-RunbookExecutionManifest `
    -RunId $runId `
    -Kind CloudFoundation `
    -TargetStableId ([string]$tenant.TenantId) `
    -SourceCommit $assessment.sourceCommit `
    -AssessmentDigest $assessment.assessmentDigest `
    -AuthenticationContext $manifestAuthentication `
    -AllowedActions $actionPlan.manifestActions `
    -ToolVersions $toolResolutions `
    -GeneratedAtUtc $NowUtc
```

Require `sourceCommit` to match `^[0-9a-f]{40}$`, `assessmentDigest` and `planDigest` to match `^[0-9a-f]{64}$`, and every tool path/hash/version to be present before construction. Assert the returned target has exactly `type = 'CloudFoundation'` and `stableId = $tenant.TenantId`. Write the assessment and rich action plan, construct and write the manifest, then call `ConvertTo-RunbookEvidenceRecord` with `Status = 'Planned'`, `GeneratedAtUtc`, `SourceCommit`, `AssessmentDigest`, `OperatorId`, `ShouldProcessDecision = 'NotApplicable'`, `PlanDigest`, `ManifestDigest`, closed safe planning `ReadBack`, separate `ManualItems`, and an empty `RecoveryItems` array; omit `FinalContext` because planning has no post-Apply context. Write canonical files atomically only after all reads and allowlist projections succeed. If evidence projection fails, delete only temporary files created by the atomic writer and do not claim a plan was produced. Add a test that attempts to inject an unapproved raw provider property into planning read-back and expects the shared evidence constructor to reject it.

- [ ] **Step 5: Add mismatch, blocked-device-code, and permission tests**

Prove a wrong tenant/subscription/user/repository/profile/environment/site stops before the next service read. For Azure DevOps, separately prove an `Existing` project-ID mismatch stops and a `Create` exact-name result count of two blocks without selection; do not require a project ID for the zero-match Create path. Prove a 401/403 becomes a sanitized permission delta; a device-code policy error is `Blocked`; and neither case writes an executable manifest.

- [ ] **Step 6: Run planning and shared-contract tests**

Run:

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester infra/tests/pester/CloudDelegatedContext.Tests.ps1,infra/tests/pester/CloudFoundationPlanning.Tests.ps1,infra/tests/pester/RunbookContracts.Tests.ps1 -Output Detailed -CI"
```

Expected: PASS; repeated identical fixture input and fixed `NowUtc` yields byte-identical plan content and digest.

- [ ] **Step 7: Commit the planning entry point**

```powershell
git add -- infra/src/scripts/runbooks/Get-CloudFoundationPlan.ps1 infra/tests/pester/CloudFoundationPlanning.Tests.ps1
git commit -m "feat(infra): add cloud foundation planning entry point"
```

Expected: one commit containing only the read-only planner and tests.

---

### Task 4: Implement Provider Mutation Adapters and Postcondition Read-Back

**Files:**
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/Invoke-GitHubFoundationMutation.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/Invoke-AzureFoundationMutation.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/Invoke-AzureDevOpsFoundationMutation.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Invoke-CloudFoundationAction.ps1`
- Create: `infra/tests/pester/CloudFoundationProviderMutations.Tests.ps1`
- Modify: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Caldova.HrFrontier.Bootstrap.psd1`
- Modify: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Caldova.HrFrontier.Bootstrap.psm1`

**Interfaces:**
- Consumes: one rich action and its matching closed manifest action from Task 2, exact tenant configuration, verified delegated context, digest-bound tool resolutions, and the injected native runner.
- Produces: `Invoke-CloudFoundationAction` with the exact signature above and a normalized result containing `status = NoChange|Changed|Failed`; no provider adapter is exported.

- [ ] **Step 1: Verify current official delegated command surfaces**

From the attended local workstation, inspect command help without authenticating or mutating:

```powershell
gh api --help
az deployment sub create --help
az deployment sub show --help
az bicep format --help
az bicep build --help
az ad app list --help
az ad app create --help
az ad app update --help
az ad sp list --help
az ad sp create --help
az devops project create --help
az devops project show --help
```

Review the current official GitHub REST repository/ruleset, Azure subscription deployment, Microsoft Entra Azure CLI, and Azure DevOps project CLI references linked by the design. Expected: each automated operation has an official attended delegated-user command, supports the exact stable target and JSON/body fields in this task, and does not require token extraction, PAT input, a client secret, OIDC, or app-only login. If a mutation or required read-back command no longer meets that contract, keep its planner classification `Blocked` and its adapter test asserting refusal; do not substitute an undocumented endpoint. Formatting is the sole optional exception: when `az bicep format --help` does not support `--stdout`, omit formatting and continue with source-hash verification and external-output build.

Use these product-owned references and record them in the runbook:

```text
https://docs.github.com/en/rest/repos/repos#update-a-repository
https://docs.github.com/en/rest/repos/rules#create-a-repository-ruleset
https://docs.github.com/en/rest/repos/rules#update-a-repository-ruleset
https://learn.microsoft.com/en-us/cli/azure/deployment/sub#az-deployment-sub-create
https://learn.microsoft.com/en-us/cli/azure/ad/app
https://learn.microsoft.com/en-us/cli/azure/ad/sp
https://learn.microsoft.com/en-us/cli/azure/devops/project
```

- [ ] **Step 2: Write failing GitHub mutation tests**

```powershell
It 'updates a non-Actions ruleset through local gh api and reads it back' {
    $result = Invoke-CloudFoundationAction -Action $script:GitHubRulesetAction `
        -TenantConfiguration $script:Tenant -VerifiedContext $script:Context `
        -ToolResolutions $script:ToolResolutions `
        -RunDirectory $script:RunDirectory `
        -NativeCommandRunner $script:GitHubRunner -NowUtc $script:Now

    $script:NativeCalls[0].FilePath | Should -BeExactly 'C:\SyntheticTools\gh.exe'
    ($script:NativeCalls[0].ArgumentList -join ' ') | Should -BeExactly 'api repos/synthetic-owner/synthetic-repository/rulesets/321'
    ($script:NativeCalls[1].ArgumentList -join ' ') | Should -Match '^api --method PUT repos/synthetic-owner/synthetic-repository/rulesets/321 --input '
    ($script:NativeCalls[2].ArgumentList -join ' ') | Should -BeExactly 'api repos/synthetic-owner/synthetic-repository/rulesets/321'
    $result.status | Should -BeExactly 'Changed'
    $result.readBack.bodyDigest | Should -BeExactly $script:GitHubRulesetAction.bodyDigest
}

It 'does not write an already exact GitHub ruleset' {
    $result = Invoke-CloudFoundationAction -Action $script:GitHubRulesetAction `
        -TenantConfiguration $script:Tenant -VerifiedContext $script:Context `
        -ToolResolutions $script:ToolResolutions `
        -RunDirectory $script:RunDirectory `
        -NativeCommandRunner $script:ExactGitHubRunner -NowUtc $script:Now
    $result.status | Should -BeExactly 'NoChange'
    @($script:Calls | Where-Object { $_ -match '--method (PATCH|POST|PUT)' }).Count | Should -Be 0
}
```

Also test `PATCH repos/{owner}/{repository}` for allowlisted metadata, `POST repos/{owner}/{repository}/rulesets` for absence, `PUT .../rulesets/{id}` for drift, ambiguous same-name refusal, repository-ID mismatch, admin-permission loss, body-digest mismatch, and rejection of `required_status_checks`, `actions/*`, workflow, Environment, secret, and variable endpoints.

Add tests that reject a missing, relative, repository-contained, reparse-point, or mismatched `RunDirectory`; seed an unrelated sentinel file and prove success/failure cleanup removes only adapter-created payload/parameter/response files while preserving the sentinel and run directory.

- [ ] **Step 3: Run provider tests and verify the first red state**

Run:

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester infra/tests/pester/CloudFoundationProviderMutations.Tests.ps1 -Output Detailed -CI"
```

Expected: FAIL because `Invoke-CloudFoundationAction` is not exported.

- [ ] **Step 4: Implement the GitHub adapter**

Resolve `RunDirectory` through the shared external-report path guard, require it to exist below the approved report root and outside every Git worktree, and reject a reparse point or path mismatch. Reconstruct the canonical payload from `Action.providerInput`, compare its digest with `Action.bodyDigest`, write it atomically as `<RunDirectory>\github-<actionId>.json`, and issue only the following arguments through the approved absolute GitHub CLI path:

```powershell
gh api repos/<owner>/<repository>
gh api repos/<owner>/<repository>/rulesets
gh api repos/<owner>/<repository>/rulesets/<rulesetId>
gh api --method PATCH repos/<owner>/<repository> --input <canonicalPayloadPath>
gh api --method POST repos/<owner>/<repository>/rulesets --input <canonicalPayloadPath>
gh api --method PUT repos/<owner>/<repository>/rulesets/<rulesetId> --input <canonicalPayloadPath>
```

Read before write, skip an exact canonical match, revalidate login/repository/admin immediately before the write, and read the exact repository/ruleset ID afterward. In `finally`, delete only the exact `github-<actionId>.json` file created by this invocation; never recurse or delete another run's file. Reject any payload key outside the official repository metadata allowlist or any ruleset rule outside `deletion`, `non_fast_forward`, and `pull_request`.

- [ ] **Step 5: Write failing Azure deployment and Entra target-resource tests**

```powershell
It 'deploys exactly the approved Bicep bytes under the delegated user' {
    $sourceHashBefore = (Get-FileHash -LiteralPath $script:MainBicepPath -Algorithm SHA256).Hash
    $result = Invoke-CloudFoundationAction -Action $script:AzureDeployAction `
        -TenantConfiguration $script:Tenant -VerifiedContext $script:Context `
        -ToolResolutions $script:ToolResolutions `
        -RunDirectory $script:RunDirectory `
        -NativeCommandRunner $script:AzureRunner -NowUtc $script:Now
    $formatCall = $script:NativeCalls |
        Where-Object { ($_.ArgumentList -join ' ') -match '^bicep format ' } |
        Select-Object -Single
    $formatCall.ArgumentList | Should -Be @(
        'bicep','format','--file',$script:MainBicepPath,'--stdout'
    )
    @($script:NativeCalls.FilePath | Select-Object -Unique) |
        Should -Contain 'C:\SyntheticTools\az.cmd'
    $buildCall = $script:NativeCalls |
        Where-Object { ($_.ArgumentList -join ' ') -match '^bicep build ' } |
        Select-Object -Single
    $buildCall.ArgumentList | Should -Be @(
        'bicep','build','--file',$script:MainBicepPath,
        '--outfile',$script:BuiltTemplatePath
    )
    (($script:NativeCalls.ArgumentList | ForEach-Object { $_ -join ' ' }) -join "`n") |
        Should -Match [regex]::Escape(
        'deployment sub create --name cf-synthetic-0123456789ab --location switzerlandnorth --template-file'
    )
    (($script:NativeCalls.ArgumentList | ForEach-Object { $_ -join ' ' }) -join "`n") |
        Should -Match '--parameters .*synthetic\.bicepparam --output json'
    $script:DeploymentTemplatePath | Should -BeExactly $script:BuiltTemplatePath
    $script:DeploymentTemplateDigest | Should -BeExactly $script:BuiltTemplateDigest
    Test-Path (Join-Path $script:RepositoryRoot 'infra\src\bicep\main.json') | Should -BeFalse
    (Get-FileHash -LiteralPath $script:MainBicepPath -Algorithm SHA256).Hash |
        Should -BeExactly $sourceHashBefore
    $result.readBack.provisioningState | Should -BeExactly 'Succeeded'
}

It 'creates target Entra resources without credentials and never changes execution identity' {
    $result = Invoke-CloudFoundationAction -Action $script:EntraApplicationAction `
        -TenantConfiguration $script:Tenant -VerifiedContext $script:Context `
        -ToolResolutions $script:ToolResolutions `
        -RunDirectory $script:RunDirectory `
        -NativeCommandRunner $script:EntraRunner -NowUtc $script:Now
    ($script:NativeCalls[0].ArgumentList -join ' ') | Should -Match '^ad app create --display-name '
    (($script:NativeCalls.ArgumentList | ForEach-Object { $_ -join ' ' }) -join "`n") |
        Should -Not -Match '(?i)(password|credential|federated|secret|login)'
    $result.readBack.objectId | Should -BeExactly 'entra-app-object-synthetic'
}
```

Add exact pre-create discovery assertions:

```powershell
It 'proves Entra application absence and service-principal absence without broad adoption' {
    $appList = $script:NativeCalls | Where-Object {
        ($_.ArgumentList -join ' ') -eq
            'ad app list --display-name Synthetic Target App --output json'
    }
    @($appList).Count | Should -Be 1

    $spList = $script:NativeCalls | Where-Object {
        ($_.ArgumentList -join ' ') -eq
            "ad sp list --filter appId eq 'entra-app-id-synthetic' --output json"
    }
    @($spList).Count | Should -Be 1
    $script:EntraAssessment.applicationExactNameMatchCount | Should -Be 0
    $script:EntraAssessment.servicePrincipalExactAppIdMatchCount | Should -Be 0
}
```

Add a formatter-capability case where `az bicep format --help` does not document `--stdout`: assert formatting is omitted and build proceeds without changing the source. Add failures for a changed source Bicep hash before/after planning or Apply, any format invocation without `--stdout`, any repository-adjacent `main.json`, changed compiled-template/parameter digest, changed what-if digest, wrong subscription, non-user Azure context, rejected `Test-WhatIfBoundary`, deployment name mismatch, failed provisioning state, Entra application exact-name counts of one and two, unauthorized/unavailable application listing misclassified as absence, service-principal exact-appId ambiguity, unsupported permission/consent request, and app/service-principal context after mutation.

- [ ] **Step 6: Implement the Azure/Entra adapter**

For `DeployAzureFoundation`, validate `RunDirectory` and hash the exact source `infra/src/bicep/main.bicep` bytes before any Bicep command. Inspect local `az bicep format --help`; only when it documents `--stdout`, run exactly `az bicep format --file <absoluteRepositoryMainBicepPath> --stdout` through the approved absolute Azure CLI path and discard the formatted stdout or compare it in memory. Never redirect it over the source. If `--stdout` is unsupported, omit formatting; do not substitute in-place format. Immediately re-hash the source and refuse if it changed.

Regenerate parameters with existing `New-TenantBicepParameters.ps1` as `<RunDirectory>\<tenantAlias>.bicepparam`, and compile `infra/src/bicep/main.bicep` with `az bicep build --file <absoluteRepositoryMainBicepPath> --outfile <RunDirectory>\main-<actionId>.json`. If the installed supported CLI emits only stdout for the reviewed build command variant, capture stdout bytes and atomically write those unchanged bytes to that same external path. Never run a build variant that defaults beside the source and never create `infra/src/bicep/main.json`. Hash the exact compiled JSON file bytes and exact parameter bytes, run `what-if` with `--template-file <thatExactExternalCompiledJsonPath>` into `<RunDirectory>\azure-what-if-<actionId>.json`, rerun `Test-WhatIfBoundary.ps1`, and compare every digest with the approved action before mutation. Re-hash the source once more immediately before `ShouldProcess`/deployment and require the original source digest. Deploy that same compiled path without rebuilding or transforming its bytes:

```powershell
az deployment sub create `
    --name "cf-<tenantAlias>-<first12AssessmentDigest>" `
    --location <PrimaryLocation> `
    --template-file <exactExternalCompiledJsonPath> `
    --parameters <exactExternalBicepParamPath> `
    --output json
az deployment sub show `
    --name "cf-<tenantAlias>-<first12AssessmentDigest>" `
    --query "{id:id,name:name,provisioningState:properties.provisioningState,outputs:properties.outputs}" `
    --output json
```

Require the compiled-template path passed to `what-if` and `deployment sub create` to be ordinally identical and its digest to remain unchanged immediately before deployment. Require `Succeeded`, then read each expected resource ID through allowlisted `az resource show`/`az role assignment list` calls. A prior deployment with the same name and exact successful outputs is `NoChange`; a same-name/different-digest deployment is `Refused`. In `finally`, remove only the parameter, compiled-template, raw-what-if, and temporary response files whose exact paths this adapter recorded; retain canonical evidence files and never delete the run directory. The validation service principal referenced by Bicep is a target resource receiving the approved role assignment; the signed-in delegated user remains the `az account show` execution principal before and after deployment.

For approved target Entra metadata, first read the acting user's active directory roles with:

```powershell
az rest --method get `
    --url 'https://graph.microsoft.com/v1.0/me/transitiveMemberOf/microsoft.graph.directoryRole?$select=id,displayName,roleTemplateId' `
    --output json
```

Require exactly the same delegated user object ID already returned by `az ad signed-in-user show` and at least one active role with `roleTemplateId` `cf1c38e5-3621-4004-a7cb-879624dced7c` (Application Administrator) or `158c047a-c907-4556-b7ef-446551a6b5f7` (Cloud Application Administrator). Eligible-but-not-active PIM state is insufficient. A denied/unavailable role read or absent active role classifies the mutation `Blocked` before `ShouldProcess`.

Before an application Create, execute the official delegated command `az ad app list --display-name <reviewedName> --output json`, retain only `id`, `appId`, and `displayName`, and apply an ordinal exact-name filter. Proceed only on a successful zero-match response. One exact match is a blocked adoption/review condition, multiple are ambiguous and blocked, and authorization failure, command failure, malformed JSON, or unavailable read-back is never treated as absence. Before service-principal Create, require the reviewed application's exact `appId` to have been present when this plan was generated, execute `az ad sp list --filter "appId eq '<exactAppId>'" --output json`, retain only `id`, `appId`, and `displayName`, filter exact appId ordinally, and apply the same zero/one/multiple and unavailable-result rules. A service-principal action dependent on an app created in this same run is refused as not digest-bound and requires reassessment after the app ID is read back.

Then use only `az ad app create --display-name <exactName> --sign-in-audience AzureADMyOrg --output json`, allowlisted `az ad app update --id <objectId> --display-name <exactName>`, and `az ad sp create --id <applicationAppId> --output json`. Do not create passwords, certificates, permissions, consent grants, or federated credentials. Read back with `az ad app show` and `az ad sp show`, require exact tenant/object/app IDs and empty credential collections, and fail if the resource is described as the runbook execution identity.

- [ ] **Step 7: Write failing Azure DevOps mutation tests**

```powershell
It 'creates a private Agile project and waits for the exact stable ID' {
    $result = Invoke-CloudFoundationAction -Action $script:AdoCreateAction `
        -TenantConfiguration $script:Tenant -VerifiedContext $script:Context `
        -ToolResolutions $script:ToolResolutions `
        -RunDirectory $script:RunDirectory `
        -NativeCommandRunner $script:AdoRunner -NowUtc $script:Now
    (($script:NativeCalls.ArgumentList | ForEach-Object { $_ -join ' ' }) -join "`n") |
        Should -Match [regex]::Escape(
        'devops project create --organization https://dev.azure.com/synthetic/ --name SyntheticProject --process Agile --source-control git --visibility private --output json'
    )
    $result.readBack.state | Should -BeExactly 'wellFormed'
    $result.readBack.projectId | Should -BeExactly 'ado-project-synthetic'
    $result.readBack.organizationUrl | Should -BeExactly 'https://dev.azure.com/synthetic/'
    $result.readBack.projectName | Should -BeExactly 'SyntheticProject'
    $result.readBack.processId | Should -BeExactly 'process-agile-synthetic'
    $result.readBack.visibility | Should -BeExactly 'private'
}

It 'stops after an Azure failure and never starts Azure DevOps' {
    { Invoke-CloudFoundationAction -Action $script:FailedAzureAction @script:Common } |
        Should -Throw '*Azure deployment postcondition failed*'
    ($script:Calls -join "`n") | Should -Not -Match 'devops project create'
}
```

Add separate tests for the two context paths: `Existing` intent queries the reviewed project ID and rejects an ID/name/organization mismatch; `Create` intent binds the requested name/process ID/process name/source control/visibility, proceeds only for zero ordinal exact-name matches, treats one match as existing/conflicting state, and blocks two matches as ambiguous without selecting either. Also test exact-existing `NoChange`, existing visibility/description drift becoming `Blocked`, acting-user mismatch, missing effective project-create permission, returned-ID absence/change, async timeout, unsupported process change, and any project-update/pipeline/service-endpoint/check mutation.

- [ ] **Step 8: Implement the Azure DevOps adapter**

For `Create` intent, repeat the exact-name list query immediately before mutation and require zero matches. Verify that `Action.providerInput` and its `bodyDigest` bind the exact organization URL, requested project name, process ID and process name, `sourceControl = 'git'`, and visibility. Use only:

```powershell
az devops project create --organization <url> --name <name> `
    --process Agile --source-control git --visibility private --output json
az devops project show --organization <url> --project <projectId> --output json
```

Resolve the organization and Agile process unambiguously during planning. Read the actual Azure DevOps caller through the documented Connection Data endpoint:

```powershell
az devops invoke --organization <organizationUrl> `
    --area location --resource connectionData `
    --api-version 7.1-preview.1 --output json
```

Require `authenticatedUser.id`, `authenticatedUser.subjectDescriptor`, and the account/unique-name property to match the reviewed administrator and the Azure signed-in user. Then resolve the `Project` security namespace (`52d39943-cb85-4d7f-8fa8-c6baac873819`), select the action whose documented display name is exactly `Create new projects`, and query effective permission for that subject at collection token `$PROJECT:vstfs:///Classification/TeamProject/`:

```powershell
az devops security permission namespace list --organization <organizationUrl> --output json
az devops security permission list `
    --organization <organizationUrl> `
    --id 52d39943-cb85-4d7f-8fa8-c6baac873819 `
    --subject <authenticatedUser.subjectDescriptor> `
    --token '$PROJECT:vstfs:///Classification/TeamProject/' `
    --output json
```

Require the resolved `Create new projects` bit to be effectively allowed and not denied. If Connection Data, the namespace/action, collection token, or effective allow/deny result is unavailable or ambiguous in current official documentation/output, classify project creation `Blocked`; group membership or project visibility alone is never sufficient. Capture the ID returned by `project create`, require one non-empty GUID, and poll only that ID with bounded retry until `state = wellFormed`; compare returned ID, requested name, visibility, organization, and process ID/name. Store that new project ID only in the safe read-back and evidence projection so recovery can query the exact created target. Never invoke a project-update command or create/run a pipeline. Azure DevOps service connections are always `Blocked` in this increment. Approvals/checks and the first Azure Boards GitHub App connection are always attended `Manual`, with portal owner, role, decision, and read-back.

- [ ] **Step 9: Implement the public provider dispatcher**

Use a closed action-to-provider map:

```powershell
$providerMap = @{
    UpdateGitHubRepositoryMetadata = 'GitHub'
    UpsertGitHubNonActionsRuleset = 'GitHub'
    DeployAzureFoundation = 'Azure'
    CreateEntraTargetApplication = 'Azure'
    UpdateEntraTargetApplication = 'Azure'
    CreateEntraTargetServicePrincipal = 'Azure'
    CreateAzureDevOpsProject = 'AzureDevOps'
}
```

Reject unknown names, service disagreement, absent/changed `bodyDigest`, target mismatch, and classifications other than `Create` or `Update`. Validate `RunDirectory` once in the dispatcher and again in the selected private adapter; require it to be the canonical approved external run path. Require each provider tool resolution to contain an absolute path and the exact plan-bound version/hash. The dispatcher does not call `ShouldProcess`; the thin invocation script owns that provider-level user decision.

- [ ] **Step 10: Export and run provider tests**

Add `'Invoke-CloudFoundationAction'` to both module export lists and run:

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester infra/tests/pester/CloudFoundationProviderMutations.Tests.ps1,infra/tests/pester/BicepComposition.Tests.ps1,infra/tests/pester/WhatIfBoundary.Tests.ps1,infra/tests/pester/GitHubGovernance.Tests.ps1 -Output Detailed -CI"
```

Expected: PASS; provider writes are exact, idempotent, delegated-user based, and postcondition verified, while existing Bicep and GitHub governance contracts remain compatible.

- [ ] **Step 11: Commit provider mutations**

```powershell
git add -- infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap infra/tests/pester/CloudFoundationProviderMutations.Tests.ps1
git commit -m "feat(infra): add delegated cloud provider mutations"
```

Expected: one provider-focused commit and no staged workflow path.

---

### Task 5: Implement Digest-Gated Apply and Recovery

**Files:**
- Create: `infra/src/scripts/runbooks/Invoke-CloudFoundation.ps1`
- Create: `infra/tests/pester/CloudFoundationInvocation.Tests.ps1`

**Interfaces:**
- Consumes: approved execution manifest and assessment generated by Task 3; provider dispatcher from Task 4; `Test-RunbookExecutionManifest`, `Test-CloudDelegatedContext`, `Get-CloudFoundationAssessment`, `New-CloudFoundationActionPlan`, `ConvertTo-RunbookEvidenceRecord`, and canonical writer.
- Produces: exact invocation signature above; per-provider `ShouldProcess`; ordered check-then-act application; `cloud-invocation-evidence.json`; exit failure while any `Manual`, `Blocked`, `Refused`, failed, or unverified item remains.

- [ ] **Step 1: Write failing approval and non-mutation tests**

```powershell
It 'requires Apply and the exact approved digest' {
    { & $script:InvokeScript @script:ValidArguments } | Should -Throw '*-Apply*'
    { & $script:InvokeScript @script:ValidArguments -Apply -ApprovedDigest ('0' * 64) -Confirm:$false } |
        Should -Throw '*Approved digest*'
}

It 'lets WhatIf win and performs no cloud write' {
    & $script:InvokeScript @script:ValidArguments -Apply -WhatIf | Out-Null
    ($script:Calls -join "`n") | Should -Not -Match '(?i)\b(create|update|delete|deploy|put|patch|post)\b'
}

It 'blocks excluded or unimplemented actions rather than inventing automation' {
    { & $script:InvokeScript @script:BlockedArguments -Apply -Confirm:$false } |
        Should -Throw '*foundation remains incomplete*'
    ($script:Calls -join "`n") | Should -Not -Match 'actions/environments|federatedIdentityCredentials|pipeline'
}

It 'asks ShouldProcess and applies once at each provider action boundary' {
    & $script:InvokeScript @script:SupportedArguments -Apply -Confirm:$false | Out-Null
    @($script:DispatcherCalls.action) | Should -Be @(
        'UpsertGitHubNonActionsRuleset',
        'DeployAzureFoundation',
        'CreateAzureDevOpsProject'
    )
    @($script:DispatcherCalls | Where-Object status -eq 'Changed').Count | Should -Be 3
}

It 'stops dependent providers and records exact recovery after a partial failure' {
    { & $script:InvokeScript @script:AzureFailureArguments -Apply -Confirm:$false } |
        Should -Throw '*partial cloud foundation*'
    @($script:DispatcherCalls.action) | Should -Be @(
        'UpsertGitHubNonActionsRuleset',
        'DeployAzureFoundation'
    )
    $script:Evidence.status | Should -BeExactly 'Failed'
    $script:Evidence.errorCategory | Should -BeExactly 'PartialMutation'
    $script:Evidence.recoveryItems[0].nextAction | Should -Match 'regenerate.*digest'
    $script:Evidence.recoveryItems[0].requiresNewPlan | Should -BeTrue
    $script:Evidence.recoveryItems[0].requiresNewApproval | Should -BeTrue
}

It 'uses the shared evidence status enums for success and incompleteness' {
    & $script:InvokeScript @script:AllVerifiedArguments -Apply -Confirm:$false | Out-Null
    $script:Evidence.status | Should -BeExactly 'Verified'

    { & $script:InvokeScript @script:ManualRemainingArguments -Apply -Confirm:$false } |
        Should -Throw '*foundation remains incomplete*'
    $script:Evidence.status | Should -BeExactly 'Failed'
    $script:Evidence.errorCategory | Should -BeExactly 'IncompleteManualActions'
    $script:Evidence.recoveryItems[0].nextAction | Should -Not -BeNullOrEmpty
}
```

- [ ] **Step 2: Run invocation tests and verify the red state**

Run:

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester infra/tests/pester/CloudFoundationInvocation.Tests.ps1 -Output Detailed -CI"
```

Expected: FAIL because `Invoke-CloudFoundation.ps1` does not exist.

- [ ] **Step 3: Implement the pre-apply gate**

Before `ShouldProcess`, require:

```powershell
if (-not $Apply) { throw 'Cloud foundation invocation requires explicit -Apply.' }
Test-RunbookExecutionManifest -Manifest $manifest -ApprovedDigest $ApprovedDigest `
    -CurrentSourceCommit $currentCommit `
    -CurrentAssessmentDigest $assessment.assessmentDigest `
    -CurrentAuthenticationContext $manifestAuthentication `
    -AllowedActionNames @(
        'VerifyExistingResource','CompleteAttendedManualAction',
        'ResolveBlockedIntent','RefuseMismatchedTarget',
        'UpdateGitHubRepositoryMetadata','UpsertGitHubNonActionsRuleset',
        'DeployAzureFoundation','CreateAzureDevOpsProject',
        'CreateEntraTargetApplication',
        'UpdateEntraTargetApplication','CreateEntraTargetServicePrincipal'
    ) -NowUtc $NowUtc | Out-Null
```

Apart from `-Manifest` and `-ApprovedDigest`, call the shared validator with only its current contract parameters shown above: `CurrentSourceCommit`, `CurrentAssessmentDigest`, `CurrentAuthenticationContext`, `AllowedActionNames`, and `NowUtc`. Do not pass the retired `ExpectedSourceCommit`, `ExpectedAssessmentDigest`, or `ExpectedAuthentication` aliases, and do not add cloud-only validator parameters.

Recompute `New-CloudFoundationActionPlan` from the supplied assessment, compare its `manifestActions` canonically with the manifest actions, and use its richer `actions` only for dispatch, the displayed summary, and evidence. Recompute every mutation body digest before the first write. Reject a changed source commit, assessment digest, delegated account, target ID, method, URI, body digest, tool/API version, plan age over 30 minutes, future timestamp over two minutes, duplicate action, unknown property, or digest mismatch. Display the exact sorted action summary before asking for confirmation.

Resolve `$runDirectory` as the canonical parent of the supplied execution manifest, require the assessment and plan files to have that same parent, and validate it with `Resolve-RunbookReportPath`. Refuse a repository-contained path, reparse point, mismatched parent, or run ID that does not match the manifest. Provider adapters may create only their named temporary files under this directory.

For every tool recorded in `manifest.toolVersions`, call `Resolve-CloudNativeTool` during preflight and compare `name`, canonical absolute `path`, `version`, and `sha256` ordinally with the approved values. After `ShouldProcess` approves each provider action but immediately before its adapter call, re-resolve and re-hash that action's required tool again and repeat the comparison so the approval window cannot hide executable drift. Refuse the action if resolution returns zero or multiple physical files, the path is no longer absolute, or any field drifted. Pass only these freshly revalidated resolution objects to context checks and provider adapters.

- [ ] **Step 4: Implement provider-level ShouldProcess and ordered Apply**

Order independent providers as GitHub, Entra target metadata, Azure deployment, then Azure DevOps; preserve action order within a provider. Before each mutation, repeat exact delegated context and permission checks and call:

Implement local entry-point function `Assert-ApprovedCloudToolResolutions -Approved <object> -NativeToolResolver <scriptblock>`, returning a complete freshly resolved set whose absolute paths, versions, and hashes exactly match the manifest.

```powershell
if ($PSCmdlet.ShouldProcess(
        "$($action.service):$($action.targetId)",
        "$($action.method) $($action.uri) [$($action.bodyDigest)]"
    )) {
    $revalidatedToolResolutions = Assert-ApprovedCloudToolResolutions `
        -Approved $manifest.toolVersions `
        -NativeToolResolver $NativeToolResolver
    $currentContext = Test-CloudDelegatedContext `
        -TenantConfiguration $tenant -ToolResolutions $revalidatedToolResolutions `
        -NativeCommandRunner $NativeCommandRunner `
        -InteractiveHostProbe $InteractiveHostProbe
    $result = Invoke-CloudFoundationAction -Action $action `
        -TenantConfiguration $tenant -VerifiedContext $currentContext `
        -ToolResolutions $revalidatedToolResolutions `
        -RunDirectory $runDirectory `
        -NativeCommandRunner $NativeCommandRunner -NowUtc $NowUtc
}
```

`NoChange` actions are read back without a mutator. `Manual`, `Blocked`, and `Refused` actions are never dispatched and keep completion false. `-WhatIf` and declined confirmation call no provider adapter. Stop all not-yet-started dependent actions after the first provider failure; do not roll back a successfully verified independent provider automatically.

- [ ] **Step 5: Implement final read-back and partial-state evidence**

After every dispatched action, require its adapter postcondition before continuing. After the sequence, rerun full context verification and `Get-CloudFoundationAssessment` with the same validated `RunDirectory`, then compare action-by-action `targetId` and `expectedPostcondition`. A complete successful run writes `Status = 'Verified'` with no error category. Every partial mutation and every incomplete foundation writes `Status = 'Failed'`: use exact `ErrorCategory = 'PartialMutation'` when an earlier action reached verified `Changed`, `IncompleteManualActions` when any `Manual` item remains, `BlockedOperation` when any `Blocked` item remains, `RefusedOperation` for a refusal, `ContextChanged`, `MutationFailed`, `ReadBackUnavailable`, or `PostconditionMismatch` as applicable. Every failed envelope includes at least one exact recovery item naming the last proven state, affected target, safe read-back command, and requirement to regenerate and reapprove before another write. Never emit status `Partial`, `Incomplete`, or `Succeeded`.

When more than one failure condition exists, choose the single envelope category in this precedence order: `PartialMutation`, `ContextChanged`, `MutationFailed`, `ReadBackUnavailable`, `PostconditionMismatch`, `RefusedOperation`, `BlockedOperation`, then `IncompleteManualActions`; preserve lower-priority manual conditions in `ManualItems` and every recovery procedure in separate structured `RecoveryItems`.

Recovery is provider-specific and never reuses the old approval: preserve a successfully read-back GitHub change and let the next assessment classify it `NoChange`; query the exact Azure deployment name and resource IDs before deciding whether a failed/unknown deployment needs a new plan; query an Azure DevOps project by returned operation/project ID before retrying create so an asynchronous success cannot produce a duplicate; and query Entra by exact object/app ID and display name before retrying. Every recovery reruns full assessment, produces new action/body digests, and requires new human approval.

For success, incomplete, declined, `-WhatIf`, failed, and partial-mutation outcomes, call the shared evidence constructor with all required provenance and supported optional fields:

```powershell
$evidenceContext = if ($null -ne $finalContext) { $finalContext } else { $initialContext }
$evidenceToolVersions = if ($null -ne $revalidatedToolResolutions) {
    $revalidatedToolResolutions
}
else {
    $manifest.toolVersions
}
$evidenceArguments = @{
    RunId = [guid]$manifest.runId
    Operation = 'CloudFoundation'
    Classification = $overallClassification
    Status = $overallStatus
    TargetId = [string]$manifest.target.stableId
    ToolVersions = $evidenceToolVersions
    ReadBack = $safeReadBack
    ManualItems = $manualItems
    RecoveryItems = $recoveryItems
    ErrorCategory = $errorCategory
    GeneratedAtUtc = $NowUtc
    SourceCommit = $currentCommit
    AssessmentDigest = $assessment.assessmentDigest
    OperatorId = [string]$evidenceContext.principal.id
    ShouldProcessDecision = $shouldProcessDecision
    PlanDigest = $planDigest
    ManifestDigest = $manifest.digest
}
if ($null -ne $finalContext) {
    $evidenceArguments.FinalContext = $safeFinalContext
}
$evidence = ConvertTo-RunbookEvidenceRecord @evidenceArguments
```

Before this call, project each adapter result into the closed safe provider read-back union defined in “Exact Interfaces and Data Contracts”; reject a raw response object, unknown property, nested provider payload, or response headers. Build each recovery item with exactly `service`, `targetId`, `lastProvenState`, `safeDiagnostic`, `owner`, `nextAction`, `requiresNewPlan`, and `requiresNewApproval`; do not encode recovery prose inside `ManualItems`. When execution stops before final context exists, omit `FinalContext` but still pass every required parameter. `OperatorId` comes from the last verified delegated context, never from user input. `PlanDigest` is recomputed from the rich action plan; `ManifestDigest` is the validated manifest digest. Evidence serialization failure prevents a success claim.

- [ ] **Step 6: Add confirmation, drift, and evidence tests**

Test `-Confirm:$false`, declined confirmation, `-WhatIf`, stale plan, changed source commit, changed account, changed target ID/method/URI/body digest, zero/ambiguous executable resolution, executable path/version/hash drift, relative executable path, unavailable final read-back, repeat-Apply idempotency, provider failure before any write, partial failure after GitHub success, and complete supported success. Add a mock validator assertion that its context arguments are exactly `CurrentSourceCommit`, `CurrentAssessmentDigest`, `CurrentAuthenticationContext`, `AllowedActionNames`, and `NowUtc` in addition to manifest/digest inputs, with no retired `Expected*` argument. Assert each native-runner call uses an approved absolute path. Assert evidence contains the versioned allowlisted envelope, including:

```text
schemaVersion, runId, operation, classification, status, targetId,
generatedAtUtc, sourceCommit, assessmentDigest, operatorId,
shouldProcessDecision, planDigest, manifestDigest, toolVersions,
readBack, manualItems, recoveryItems, errorCategory, finalContext
```

Assert safe provider read-back retains only the closed fields, structured recovery items have exactly the eight approved properties and both reapproval Booleans, and fixture secrets or unknown fields deliberately placed in stderr/raw payload never appear in console output or evidence. Pass a raw response and an unknown read-back/recovery property directly to the shared constructor and expect validation failure.

- [ ] **Step 7: Run invocation and evidence-security tests**

Run:

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester infra/tests/pester/CloudFoundationInvocation.Tests.ps1,infra/tests/pester/EvidenceSecurity.Tests.ps1,infra/tests/pester/RunbookContracts.Tests.ps1 -Output Detailed -CI"
```

Expected: PASS; exact adapters are called once only after digest/context/permission/`ShouldProcess` gates, repeat Apply is `NoChange`, and no mutator is called in default, refusal, declined-confirmation, `-WhatIf`, manual/blocked, drift, or verified-no-change paths.

- [ ] **Step 8: Commit invocation and recovery**

```powershell
git add -- infra/src/scripts/runbooks/Invoke-CloudFoundation.ps1 infra/tests/pester/CloudFoundationInvocation.Tests.ps1
git commit -m "feat(infra): apply approved cloud foundation plans"
```

Expected: one commit; `git diff HEAD^ --name-only` contains no workflow path.

---

### Task 6: Enforce Static Cloud Runbook Safety

**Files:**
- Create: `infra/tests/pester/CloudFoundationStaticSafety.Tests.ps1`

**Interfaces:**
- Consumes: cloud scripts/module helpers from Tasks 1–5 and `git diff`.
- Produces: a Pester safety gate that rejects prohibited paths, parameters, commands, environment authentication, execution identities, GitHub Environment operations, and pipeline execution.

- [ ] **Step 1: Write the static validator test**

Parse every cloud `.ps1` file with the PowerShell AST and fail on parse errors. Assert parameter names do not match:

```powershell
'(?i)(password|token|pat|secret|credential|certificate|authorization|device.?code|client.?id|service.?principal)'
```

The literal PAC switch `--deviceCode` is allowed only in the runbook documentation login example and must never be a parameter value accepted by a script.

- [ ] **Step 2: Add prohibited command and path assertions**

Scan cloud implementation and documentation for executable use of:

```text
workflow_dispatch
actions/workflows
actions/environments
az devops login
--with-token
--service-principal
--federated-token
deployment sub create
devops project update
pipeline run
gh auth token
AZURE_CLIENT_ID
AZURE_CLIENT_SECRET
AZURE_FEDERATED_TOKEN_FILE
ARM_CLIENT_ID
ARM_CLIENT_SECRET
GH_TOKEN
GITHUB_TOKEN
AZURE_DEVOPS_EXT_PAT
SYSTEM_ACCESSTOKEN
```

Allow `deployment sub create` only as the exact command in `Invoke-AzureFoundationMutation.ps1`, where the AST must also contain `--name`, `--location`, `--template-file`, `--parameters`, and `--output json`; reject it everywhere else. Allow the remaining strings only inside the static test's own denylist and explanatory refusal prose, never in command construction. Permit GitHub `PATCH`, `POST`, and `PUT` only through `gh api` in `Invoke-GitHubFoundationMutation.ps1`, and permit Azure DevOps project `create` only in `Invoke-AzureDevOpsFoundationMutation.ps1`; reject every attempted Azure DevOps project update command. Use AST command-element checks for scripts so comments cannot hide executable violations.

For every native invocation AST, assert that the command expression is the validated absolute `ToolResolution.path`, not a string literal leaf name, alias, `Get-Command` first result, shell command, or PATH lookup. Add text/AST tests proving planning records path/version/SHA-256, Apply re-resolves before every mutation, and path, version, hash, missing-result, and multiple-result drift all fail before a provider write.

Assert Bicep formatting, when present, is exactly `az bicep format --file <absoluteSource> --stdout`; reject every in-place format invocation and require code/tests for omitting format when `--stdout` is unsupported. Assert source SHA-256 capture and equality checks bracket planning and Apply. Assert the Bicep build command always supplies an absolute external `--outfile` below validated `RunDirectory`; fail any build that can emit `infra/src/bicep/main.json` or any compiled output beside a repository `.bicep` file. Assert `what-if` and `deployment sub create` receive the same compiled path and that its SHA-256 is unchanged between validation and mutation. Assert the shared manifest validator invocation contains only the current context parameter names and no `ExpectedSourceCommit`, `ExpectedAssessmentDigest`, or `ExpectedAuthentication`. Assert Entra application Create uses `az ad app list --display-name` and service-principal lookup uses an exact `appId` filter, with error paths that cannot become absence. Assert planning manual items use exactly `service,targetId,condition,owner,diagnostic,recovery` and reject `decision`/`readBack`.

- [ ] **Step 3: Add a workflow immutability assertion**

```powershell
$changed = @(git diff --name-only --diff-filter=ACDMRTUXB HEAD~5..HEAD)
@($changed | Where-Object { $_ -match '^(?i)\.github/workflows/' }).Count | Should -Be 0
```

Also enumerate the task's file map and assert no planned cloud file resolves below `.github/workflows/`.

- [ ] **Step 4: Run the static suite and correct only cloud-scope violations**

Run:

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester infra/tests/pester/CloudFoundationStaticSafety.Tests.ps1 -Output Detailed -CI"
```

Expected: PASS with zero prohibited parameter, command, identity, environment-authentication, workflow, GitHub Environment, or pipeline-execution finding.

- [ ] **Step 5: Commit the static safety gate**

```powershell
git add -- infra/tests/pester/CloudFoundationStaticSafety.Tests.ps1
git commit -m "test(infra): enforce local cloud runbook boundaries"
```

Expected: one test-only commit.

---

### Task 7: Author the Attended Cloud Foundation Runbook

**Files:**
- Create: `infra/docs/runbooks/02-cloud-service-foundation.md`
- Modify: `infra/tests/pester/RunbookDocumentation.Tests.ps1`

**Interfaces:**
- Consumes: exact script commands and classification behavior from Tasks 3–5; official references named in the design.
- Produces: a six-field Proposed Baseline runbook for infrastructure administrators, with no claim that cloud foundation is complete.

- [ ] **Step 1: Add failing documentation contract tests**

Require the H1 and immediate six-field metadata table, English UTF-8 text, valid relative links, and these exact section headings:

```text
Purpose and Status
Operator, Scope, and Preconditions
Attended Authentication
Permission Matrix
Assessment and Plan
Approval and Apply
Manual and Blocking Actions
Evidence
Recovery
Cleanup and Sign-out
Definition of Done
```

Require references to both scripts, `hr-<TenantAlias>-<stage>`, `-Apply`, `-WhatIf`, `ShouldProcess`, `az login --tenant <tenantId> --use-device-code`, `gh auth login --hostname github.com --web --clipboard`, `pac auth create --name <profile> --environment <url> --deviceCode`, and `infra/docs/19-bootstrap-recovery.md`.

Also require direct official links for GitHub repository/ruleset REST mutation, `az deployment sub create`, `az ad app`, `az ad sp`, `az devops project`, Power Platform environment administration, SharePoint site creation, Azure DevOps service connections, approvals/checks, and Azure Boards GitHub connection. Community posts and copied portal screenshots are not normative.

Require literal documentation of planning `Status = 'Planned'`, `ShouldProcessDecision = 'NotApplicable'`, invocation statuses `Verified` and `Failed`, `PartialMutation`, `IncompleteManualActions`, `BlockedOperation`, `RunDirectory`, `az bicep format --file <absoluteSource> --stdout`, unchanged source Bicep SHA-256, exact external Bicep build output, absolute executable path/version/SHA-256 binding, the exact planning ManualItems shape, closed safe provider read-back, structured recovery items, Entra active role and exact-name/appId absence read-back, both Azure DevOps intent-specific context paths, Connection Data/effective permission, and the immutable Manual/Blocked classifications.

- [ ] **Step 2: Run documentation tests and verify the red state**

Run:

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester infra/tests/pester/RunbookDocumentation.Tests.ps1 -Output Detailed -CI"
```

Expected: FAIL because `02-cloud-service-foundation.md` does not exist.

- [ ] **Step 3: Write purpose, scope, and permission sections**

State that the runbook is local-only, one-tenant-at-a-time, and delegated-user-only. Include the design's six-surface permission table, separating assessment from mutation. Name the minimum write capabilities: GitHub repository administrator for metadata/rulesets; Azure subscription deployment rights plus exact role-assignment rights required by the validated Bicep; Application Administrator or Cloud Application Administrator for approved target app/service-principal metadata; and Azure DevOps Project Collection Administrator or delegated project-create permission for project creation, with Project Administrator for project settings. Explain that each required CLI must resolve to exactly one absolute application, that its path/version/SHA-256 are approval-bound, and that any ambiguity or drift requires a new plan. State that excess permission is a risk, no script broadens access, and organization/tenant creation, licenses, consent, role activation, GitHub App authorization, and unsupported delegated APIs remain attended/manual.

- [ ] **Step 4: Write exact attended sign-in and context commands**

Use these literal examples:

```powershell
az login --tenant <tenantId> --use-device-code
az account set --subscription <subscriptionId>
az account show --output json
az ad signed-in-user show --output json
az rest --method get --url 'https://graph.microsoft.com/v1.0/me/transitiveMemberOf/microsoft.graph.directoryRole?$select=id,displayName,roleTemplateId' --output json
az ad app list --display-name <reviewedName> --output json
az ad sp list --filter "appId eq '<exactAppId>'" --output json

gh auth login --hostname github.com --web --clipboard
gh auth status --hostname github.com

az devops invoke --organization <organizationUrl> --area location --resource connectionData --api-version 7.1-preview.1 --output json
az devops security permission namespace list --organization <organizationUrl> --output json
az devops security permission list --organization <organizationUrl> --id 52d39943-cb85-4d7f-8fa8-c6baac873819 --subject <authenticatedUser.subjectDescriptor> --token '$PROJECT:vstfs:///Classification/TeamProject/' --output json
# Existing intent:
az devops project show --organization <organizationUrl> --project <reviewedProjectId> --output json
# Create intent (the implementation safely quotes the exact manifest name):
az devops project list --organization <organizationUrl> --query "value[?name=='<requestedProjectName>'].{id:id,name:name,state:state,visibility:visibility}" --output json

pac auth create --name hr-<TenantAlias>-dev --environment <devUrl> --deviceCode
pac auth create --name hr-<TenantAlias>-test --environment <testUrl> --deviceCode
pac auth create --name hr-<TenantAlias>-prod --environment <prodUrl> --deviceCode
pac auth list
pac auth select --name hr-<TenantAlias>-dev
pac org who --environment <devUrl>
```

Explain that placeholders in angle brackets are values the operator reads from verified context or the reviewed tenant manifest, not script parameters for credentials. For Entra Create intent, document ordinal exact-name filtering for applications and exact-appId filtering for service principals: zero is absent, one requires exact reviewed identity handling, multiple are ambiguous, and an unauthorized/unavailable query is never absence. If the application is created in the current run, its dependent service principal remains blocked until the returned appId is assessed and bound by a newly approved plan. For Azure DevOps, organization and delegated acting-user verification always apply. Document that `Existing` intent resolves only the reviewed project ID, while `Create` intent requires zero exact-name matches and refuses ambiguity; the approved action binds requested name, process ID/name, source control, and visibility, and successful evidence binds the returned project ID. Require the Entra active role template and Azure DevOps `authenticatedUser`/effective `Create new projects` permission checks defined in Task 4; if either documented read-back is unavailable or ambiguous, the associated mutation is `Blocked`. State that device-code blockage stops and escalates rather than weakening Conditional Access or Security Defaults.

- [ ] **Step 5: Write plan, approval, and invocation procedures**

Provide concrete local examples:

```powershell
$report = Join-Path $env:LOCALAPPDATA 'CaldovaHrFrontier\runbook-evidence\cloud-foundation-review'
.\infra\src\scripts\runbooks\Get-CloudFoundationPlan.ps1 `
    -TenantAlias 'caldova25156897' `
    -Stages DEV,TEST,PROD `
    -ReportPath $report

$manifest = Get-Content -Raw (Join-Path $report 'cloud-execution-manifest.json') | ConvertFrom-Json
$manifest.digest

.\infra\src\scripts\runbooks\Invoke-CloudFoundation.ps1 `
    -TenantAlias 'caldova25156897' `
    -ExecutionManifestPath (Join-Path $report 'cloud-execution-manifest.json') `
    -AssessmentPath (Join-Path $report 'cloud-assessment.json') `
    -ApprovedDigest $manifest.digest `
    -ReportPath $report `
    -Apply `
    -WhatIf
```

Then show the same invocation without `-WhatIf` after the operator reviews every `Create`/`Update`, method, URI, body digest, permission, and expected postcondition. Explain that optional formatting is only `az bicep format --file <absoluteSource> --stdout`; its output is discarded/compared, it is omitted when unsupported, and the source SHA-256 must remain unchanged after planning and Apply. Explain that Bicep is compiled to an exact file below `RunDirectory`, `what-if` and Apply use that same file and digest, and no adjacent repository `main.json` is allowed. Explain that supported GitHub, Entra target metadata, Azure Bicep, and Azure DevOps project actions can mutate under the attended delegated user, while any `Manual`/`Blocked` item prevents a complete-foundation claim.

- [ ] **Step 6: Write exact manual and blocking procedures**

Include this decision table with product-owned portal paths, minimum role, and read-back:

| Surface | Classification when no reviewed delegated adapter is available | Attended procedure | Required role | Read-back |
|---|---|---|---|---|
| Entra target app consent/permissions | `Manual`; credential or federation creation is `Blocked` | Microsoft Entra admin center → Identity → Applications → App registrations → exact target app → API permissions; review exact delegated/application permission and use **Grant admin consent** only after separate approval | Application Administrator or Cloud Application Administrator to manage metadata; Privileged Role Administrator or Global Administrator where the exact permission requires admin consent | `az ad app show --id <objectId>` plus allowlisted permission metadata; credential collections must remain empty |
| Power Platform environments | `Manual` | Power Platform admin center → **Manage** → **Environments** → **New**; enter exact manifest display name, region, type, URL, and approved Dataverse choice; stop on capacity/license prompts | Power Platform Administrator, Dynamics 365 Administrator, or Global Administrator as required by the tenant policy | select `hr-<TenantAlias>-<stage>` and run `pac org who --environment <exactUrl>`; compare exact environment ID and URL |
| SharePoint sites | `Manual` | SharePoint admin center → **Active sites** → **Create** → approved site template; enter the exact manifest URL and owner; do not add content | SharePoint Administrator or Global Administrator | delegated `az rest` metadata GET for the exact Graph site URL; compare site ID and `webUrl` |
| Existing Azure DevOps project updates | `Blocked` | Do not change project metadata in this increment; obtain separate review of an exact current delegated REST contract | Project Administrator for any future reviewed operation | current project remains read-only assessed by stable ID |
| Azure DevOps service connections | `Blocked` in this increment | Do not create through the runbook. Route to architecture/security review in Project settings → **Service connections** because credential, workload-identity, pipeline, and approval implications are outside this contract | Project Administrator plus Endpoint Creator/Administrator as documented for the chosen connection | no completion claim; a future reviewed contract must read exact endpoint ID, type, authorization scheme, scope, and disabled state without secrets |
| Azure DevOps approvals/checks | `Manual` | Azure DevOps project → Project settings → selected resource → **Approvals and checks** → add the exact approved check/approvers without running a pipeline | Administrator/owner of the protected resource | use documented checks metadata read where supported; otherwise two-person portal verification remains `Manual`, never `Verified` |
| Azure Boards/GitHub connection | `Manual` | Azure DevOps project → Project settings → **GitHub connections** → **New connection** → GitHub App; the signed-in GitHub organization/repository owner approves only the reviewed repository | Azure DevOps Project Administrator and GitHub organization/repository owner | re-open GitHub connections and read the exact organization, repository, and connection ID through a supported metadata interface; if no API read-back exists, retain `Manual` |

State that GitHub Environments, GitHub workflow settings, OIDC/federated credentials, pipeline creation/execution, service-principal runbook login, app passwords/certificates, PATs, and secret-bearing service connections are always excluded. A workload identity or service principal may exist as an approved target solution resource, including a Bicep role-assignment target, but it never authenticates or executes this runbook.

- [ ] **Step 7: Write evidence, recovery, and cleanup**

Document that every evidence envelope records generated time, source commit, assessment digest, operator ID, `ShouldProcess` decision, plan digest, manifest digest, tool path/version/hash set, closed allowlisted provider read-back, separate manual items, structured recovery items, and allowlisted final context when available. Every planning manual item has exactly `{service,targetId,condition,owner,diagnostic,recovery}` and never `decision` or `readBack`. Planning uses `Status = 'Planned'` and `ShouldProcessDecision = 'NotApplicable'`; complete execution uses `Status = 'Verified'`; every partial or incomplete execution uses `Status = 'Failed'` with the exact error category and at least one structured recovery item. Show the closed provider-safe fields and explicitly prohibit raw CLI/REST responses. For every failure in design section 13, populate `service`, `targetId`, `lastProvenState`, `safeDiagnostic`, `owner`, `nextAction`, `requiresNewPlan = true`, and `requiresNewApproval = true`. Include optional supported cleanup only:

```powershell
gh auth logout --hostname github.com
az logout
az account clear
pac auth delete --name hr-<TenantAlias>-dev
pac auth delete --name hr-<TenantAlias>-test
pac auth delete --name hr-<TenantAlias>-prod
```

Before documenting PAC deletion, verify the installed `pac auth delete help` and current official reference support exact-name deletion. If only index deletion is supported, document `pac auth list`, select the exact unique profile index, delete only that index, and read back absence. Never document cache-folder deletion.

- [ ] **Step 8: Write the runbook Definition of Done**

Require exact contexts verified initially and finally; Azure DevOps organization and delegated acting user always proven; exact project ID proven only for `Existing` intent; exact-name zero/one/ambiguous handling, requested name/process/visibility binding, effective create-project permission, and returned project ID read-back proven for `Create` intent; active Entra directory role proven before Entra mutation; Entra Create absence proven by successful exact-name/application-appId queries rather than inferred from failure; and all other stable IDs matched. Require optional Bicep formatting to use stdout only, source Bicep SHA-256 to remain unchanged after plan and Apply, Bicep what-if to be accepted against the exact compiled bytes under `RunDirectory`, those same bytes to be deployed, and no repository-adjacent `main.json`; executable paths/version/hashes unchanged; run-directory isolation preserved; no excluded identity/path used; evidence written outside Git using only safe fields, exact planning ManualItems, and structured recovery; and every action either verified `NoChange` or successfully `Changed` with its exact postcondition read back. Require planning evidence `Status = 'Planned'`; successful invocation evidence `Status = 'Verified'`; every remaining manual, blocked, refused, stale, mismatched, unauthorized, unavailable, ambiguous, failed, incomplete, or partially verified outcome uses `Status = 'Failed'` with the exact error category and structured recovery and means the foundation is not done.

- [ ] **Step 9: Run documentation tests**

Run:

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester infra/tests/pester/RunbookDocumentation.Tests.ps1 -Output Detailed -CI"
```

Expected: PASS with valid metadata, headings, official references, relative links, and no unresolved implementation marker.

- [ ] **Step 10: Commit the runbook**

```powershell
git add -- infra/docs/runbooks/02-cloud-service-foundation.md infra/tests/pester/RunbookDocumentation.Tests.ps1
git commit -m "docs(infra): add cloud service foundation runbook"
```

Expected: one documentation-contract commit.

---

### Task 8: Link the Runbook and Complete Integrated Validation

**Files:**
- Modify: `infra/README.md`
- Modify: `infra/tests/pester/CloudFoundationStaticSafety.Tests.ps1`

**Interfaces:**
- Consumes: completed cloud runbook and all cloud tests.
- Produces: one Infrastructure documentation-map link and final source/static/regression evidence.

- [ ] **Step 1: Add a failing documentation-map assertion**

```powershell
It 'links the cloud service foundation runbook from the infrastructure map' {
    $content = Get-Content -Raw (Join-Path $script:RepositoryRoot 'infra\README.md')
    $content | Should -Match '\[Cloud Service Foundation Runbook\]\(docs/runbooks/02-cloud-service-foundation\.md\)'
}
```

- [ ] **Step 2: Run the map assertion and verify the red state**

Run:

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester infra/tests/pester/CloudFoundationStaticSafety.Tests.ps1 -Output Detailed -CI"
```

Expected: FAIL because the Infrastructure documentation map has no cloud-foundation runbook link.

- [ ] **Step 3: Add the single documentation-map row**

Add:

```markdown
| [Cloud Service Foundation Runbook](docs/runbooks/02-cloud-service-foundation.md) | Defines local attended delegated assessment, digest-bound approval, exact target read-back, manual boundaries, evidence, and recovery. |
```

Do not rewrite the older architecture narrative in this task; the runbook and current design explicitly supersede legacy workflow/OIDC execution for this operational path.

- [ ] **Step 4: Run all cloud-focused tests**

Run:

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester infra/tests/pester/CloudDelegatedContext.Tests.ps1,infra/tests/pester/CloudFoundationPlanning.Tests.ps1,infra/tests/pester/CloudFoundationProviderMutations.Tests.ps1,infra/tests/pester/CloudFoundationInvocation.Tests.ps1,infra/tests/pester/CloudFoundationStaticSafety.Tests.ps1,infra/tests/pester/RunbookContracts.Tests.ps1,infra/tests/pester/RunbookDocumentation.Tests.ps1 -Output Detailed -CI"
```

Expected: PASS with no live cloud call.

- [ ] **Step 5: Run existing bootstrap regressions**

Run:

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester infra/tests/pester -ExcludeTag Live -Output Detailed -CI"
```

Expected: PASS; legacy exported functions and existing bootstrap tests remain unchanged.

- [ ] **Step 6: Prove no workflow file changed**

Run:

```powershell
$workflowChanges = @(git diff --name-status HEAD~7 -- .github/workflows)
if ($workflowChanges.Count -ne 0) {
    $workflowChanges
    throw 'Cloud-foundation implementation changed a workflow file.'
}
git status --short
```

Expected: no workflow output; status lists only files in this plan's file map.

- [ ] **Step 7: Check documentation encoding and links**

Run:

```powershell
$paths = @(
    'infra/docs/runbooks/02-cloud-service-foundation.md',
    'infra/README.md'
)
foreach ($path in $paths) {
    $bytes = [IO.File]::ReadAllBytes((Resolve-Path $path))
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        throw "UTF-8 BOM is not permitted: $path"
    }
    $text = [Text.Encoding]::UTF8.GetString($bytes)
    if ($text -match "`uFFFD") { throw "Encoding corruption found: $path" }
}
```

Expected: no output.

- [ ] **Step 8: Perform the implementation self-review**

Review the design sections 3–17 and record the result in the pull-request or handoff text, not in a repository change log. Confirm:

```text
Windows 11 local attended execution only
all execution identities are attended delegated users; target service principals remain resources only
preferred login commands and PAC profile naming are exact
context mismatch fails before broader reads or writes
no credential parameter/environment authentication/cache inspection
native tools resolve to one absolute path and are version/hash-bound and revalidated before mutation
native runner allowlisting checks logical ToolResolution.name separately from absolute ToolResolution.path
Create/Update manifest actions require bodyDigest; every non-mutating classification forbids it
planner emits only NoChange/Create/Update/Manual/Blocked/Refused
provider payloads and parameters stay in the validated external RunDirectory with targeted cleanup
local gh api only and no GitHub Environment endpoint
no workflow, workflow_dispatch, runner, OIDC, workload identity, or pipeline execution
target apps/service principals never execute the kit
plan is deterministic and digest-bound
shared manifest validation uses only CurrentSourceCommit, CurrentAssessmentDigest, CurrentAuthenticationContext, AllowedActionNames, and NowUtc beyond manifest/digest inputs
-Apply, ShouldProcess, WhatIf, freshness, permission, read-back, evidence, and recovery gates exist
GitHub, Azure/Entra, and Azure DevOps adapters are closed, idempotent, and postcondition-verified
Azure deployment reuses the exact template, parameters, and accepted what-if digests
Azure Bicep build writes only to the external RunDirectory; what-if and deployment consume the same compiled bytes and no repository main.json is created
Bicep formatting is stdout-only when supported, otherwise omitted, and source Bicep hash remains unchanged after planning and Apply
Azure DevOps always binds organization and delegated acting user; Existing binds project ID while Create proves exact-name absence, binds requested name/process/visibility, and reads back the returned ID
Azure DevOps supports project creation only; existing project updates remain Blocked
Entra application absence uses successful delegated exact-name lookup; service-principal absence uses exact appId lookup; unavailable or unauthorized results never mean absent
provider failure stops dependent actions and records the last proven state
every evidence envelope carries generated time, source/assessment provenance, operator, ShouldProcess decision, plan/manifest digests, and final context when available
planning evidence uses Status Planned and ShouldProcessDecision NotApplicable; complete success uses Verified; partial/incomplete outcomes use Failed with exact error category and structured recovery
evidence contains only shared closed safe provider read-back fields and never raw responses
planning ManualItems use exactly service,targetId,condition,owner,diagnostic,recovery; invocation recovery uses separate structured RecoveryItems
unsupported paths are Manual or Blocked
Power Platform environments and SharePoint sites/configuration are Manual; Azure DevOps service connections are Blocked; approvals/checks are Manual
Manual/Blocked/Refused never counts as complete
one tenant and distinct DEV/TEST/PROD stages
SharePoint metadata only
all tests are synthetic and offline
metadata, links, status, scope, UTF-8, and English are valid
```

Expected: every statement is supported by a specific test and runbook section; fix any discrepancy before committing.

- [ ] **Step 9: Commit linkage and final validation**

```powershell
git add -- infra/README.md infra/tests/pester/CloudFoundationStaticSafety.Tests.ps1
git commit -m "docs(infra): link cloud foundation operations"
```

Expected: clean scoped diff, all tests passing, and no `.github/workflows/` change.

---

## Plan Self-Review

- **Spec coverage:** Sections 3–4 are enforced by Global Constraints and Task 6; sections 5–8 by the file map and Tasks 1–5; authentication, permissions, manual boundaries, evidence, and recovery in sections 7 and 10–14 by Tasks 1, 3, 4, 5, and 7; static validation and acceptance in section 15 by Tasks 6 and 8; rollout and Definition of Done in sections 16–17 by supported provider Apply, explicit manual/blocking classifications, and final review.
- **Prior-art fit:** The plan reuses `Import-TenantConfiguration`, tenant `Components`, stable-ID intent, the existing module layout/export pattern, `New-TenantBicepParameters.ps1`, `infra/src/bicep/main.bicep`, `Test-WhatIfBoundary.ps1`, the reviewed GitHub ruleset shape, bounded retries, injectable native runners, Pester 5.7.1, and the shared runbook contracts planned in `2026-09-26-runbook-foundation-workstation.md`. It extracts only safe check-then-act and read-back patterns from legacy scripts and never calls entry points whose OIDC, environment authentication, GitHub Environment, workflow, or token-extraction contracts conflict with the new design.
- **Interface consistency:** The plan consumes the shared `New-RunbookExecutionManifest -RunId -Kind -TargetStableId -SourceCommit -AssessmentDigest -AuthenticationContext -AllowedActions -ToolVersions -GeneratedAtUtc` constructor and expanded `ConvertTo-RunbookEvidenceRecord` provenance, closed safe read-back, and structured-recovery signature without wrappers or forks. It calls `Test-RunbookExecutionManifest` only with `CurrentSourceCommit`, `CurrentAssessmentDigest`, `CurrentAuthenticationContext`, `AllowedActionNames`, and `NowUtc` beyond its manifest/digest inputs. The resulting `{ type = 'CloudFoundation'; stableId = <TenantId> }` target, closed allowed-action property set, conditional `bodyDigest`, six-value classification set, five public helper signatures, private adapter `RunDirectory`, two entry-point signatures, provider dispatcher, absolute tool-resolution envelope, output filenames, evidence enums, and provenance fields are consistent wherever referenced.
- **Scope:** Only files in the requested cloud-foundation slice are created or modified. No tenant manifest, legacy bootstrap script, Bicep source, unrelated document, or workflow file is touched.
- **Safety result:** Supported GitHub, Azure/Entra, and Azure DevOps project-create writes are local, delegated, digest-bound, provider-confirmed, idempotent, and read back through closed safe projections. The native guard checks logical tool name separately and invokes only an independently validated absolute path. Optional Bicep formatting is stdout-only, source hash stability is tested, compilation is only to `RunDirectory`, and what-if/deployment hash and consume the same bytes. Azure DevOps always proves organization, acting identity, and effective permission, then branches correctly between Existing-ID verification and Create-name absence/ambiguity; Create binds requested fields and reads back the returned ID. Entra active directory role is explicitly proven, and Entra Create absence requires successful ordinal exact-name/appId discovery rather than treating an unavailable call as absence. Power Platform environments and SharePoint sites/configuration remain `Manual`, Azure DevOps service connections remain `Blocked`, and approvals/checks remain `Manual`; no implementation-time promotion or invented API is permitted. Planning evidence is `Planned`/`NotApplicable`, planning manual items use the exact shared six-property shape, and no partial or incomplete invocation can claim success; failures use separate structured recovery rather than raw responses.
- **Placeholder scan:** The plan contains concrete paths, signatures, commands, object shapes, expected failures/passes, and commit commands; it contains no deferred implementation instruction.

## Execution Handoff

Implement the shared foundation/workstation plan before this plan. After those shared contracts exist, this cloud-foundation plan may proceed independently of the customer-handover plan.

1. **Subagent-Driven (recommended):** use `superpowers:subagent-driven-development`, dispatch a fresh implementation subagent for each task, and complete requirements and quality review before the next task.
2. **Inline Execution:** use `superpowers:executing-plans`, implement in batches, and stop at the documented review checkpoints.
