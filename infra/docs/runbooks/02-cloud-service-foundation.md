# Cloud Service Foundation Runbook

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-27 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Local attended cloud service foundation |
| **References** | [Operational Runbooks](README.md); [Bootstrap Recovery](../19-bootstrap-recovery.md); [Operational Runbooks Design](../../../docs/specs/2026-09-26-operational-runbooks-design.md) |

## Purpose and Status

This runbook prepares the reviewed cloud-service foundation for one tenant from a local Windows 11 administrator workstation. It is a Proposed Baseline, not proof that any tenant foundation is complete. `Get-CloudFoundationPlan.ps1` assesses and plans without cloud mutation. `Invoke-CloudFoundation.ps1` applies only approved supported actions.

The workflow owns sequencing, validation, evidence, and recovery. The administrator owns every approval. Execution is local, interactive, attended, and delegated-user-only. GitHub Actions, workflows, Environments, runners, OIDC, pipeline execution, service-principal execution, PATs, tokens, passwords, certificates, and client secrets are outside this operating path.

## Operator, Scope, and Preconditions

The operator works on one reviewed tenant and the distinct `DEV`, `TEST`, and `PROD` Power Platform stages. The tenant manifest must have `LifecycleState = IntentReviewed`. The operator must use Windows 11, Windows PowerShell 5.1-compatible scripts, a clean reviewed repository commit, and an external evidence directory.

Every native application resolves uniquely to one absolute path. Assessment binds its path, version, and lowercase SHA-256. Apply resolves and hashes it again immediately before each mutation. Missing, multiple, relative, reparse-point, changed-path, changed-version, or changed-hash results require a new assessment and approval.

The external `RunDirectory` contains canonical assessment, plan, execution manifest, evidence, compiled Bicep, parameters, and bounded temporary provider files. It must not be inside any Git worktree. No compiled `main.json` is written beside `infra/src/bicep/main.bicep`.

## Attended Authentication

Use only the reviewed administrator and the manifest values represented by angle-bracket placeholders:

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
# Existing intent
az devops project show --organization <organizationUrl> --project <reviewedProjectId> --output json
# Create intent
az devops project list --organization <organizationUrl> --query "value[?name=='<requestedProjectName>'].{id:id,name:name,state:state,visibility:visibility}" --output json

pac auth create --name <profile> --environment <url> --deviceCode
pac auth create --name hr-<TenantAlias>-dev --environment <devUrl> --deviceCode
pac auth create --name hr-<TenantAlias>-test --environment <testUrl> --deviceCode
pac auth create --name hr-<TenantAlias>-prod --environment <prodUrl> --deviceCode
pac auth list
pac auth select --name hr-<TenantAlias>-dev
pac org who --environment <devUrl>
```

The deterministic profile is `hr-<TenantAlias>-<stage>`. Placeholders are reviewed non-secret metadata, not credential parameters.

The Azure account must be a user, and the signed-in object ID and UPN must match the administrator. An Entra metadata mutation requires an active Application Administrator (`cf1c38e5-3621-4004-a7cb-879624dced7c`) or Cloud Application Administrator (`158c047a-c907-4556-b7ef-446551a6b5f7`) role. Eligibility without activation is insufficient.

For an Entra Create intent, application names are filtered ordinally after successful delegated lookup. Zero means absent; one requires reviewed identity adoption; multiple are ambiguous. A denied, unavailable, malformed, or failed lookup never means absent. Service-principal absence uses the exact reviewed `appId` in the same way. If this run creates the application, its service principal remains blocked until a new assessment binds the returned `appId`.

Azure DevOps always verifies the organization and Connection Data `authenticatedUser`. `Existing` intent binds the reviewed project ID. `Create` intent requires zero exact-name matches, binds name, process ID and name, `git`, and visibility, proves effective **Create new projects** permission, and reads back the returned project ID. Device-code policy blockage stops the run; do not weaken Conditional Access or Security Defaults.

## Permission Matrix

| Surface | Assessment permission | Minimum mutation capability | Boundary |
|---|---|---|---|
| GitHub | Repository metadata and ruleset read | Repository administrator for allowlisted metadata and non-Actions rulesets | Local `gh api`; no Environment, workflow, secret, variable, or Actions endpoint |
| Azure | Subscription, role assignment, deployment, and what-if read | Subscription deployment rights and the exact role-assignment rights validated by Bicep | Same compiled template, parameters, and accepted what-if bytes |
| Entra | Signed-in user, active roles, exact app name and appId lookup | Active Application Administrator or Cloud Application Administrator | Target metadata only; no credentials, federation, consent, or execution identity |
| Azure DevOps | Connection Data, project metadata, process, namespace, effective permission | Delegated project-create permission; Project Administrator for attended settings | Project create only; updates and service connections are blocked |
| Power Platform | Named profile and exact environment identity read | Power Platform Administrator, Dynamics 365 Administrator, or policy-required administrator | Mutation is Manual |
| SharePoint | Exact Graph site metadata read | SharePoint Administrator or policy-required administrator | Site creation and configuration are Manual |

Excess permission is a risk. The scripts do not grant roles, activate PIM, create tenants or organizations, assign licenses, grant consent, or authorize a GitHub App.

## Assessment and Plan

Create an external review directory and run the read-only planner:

```powershell
$report = Join-Path $env:LOCALAPPDATA 'CaldovaHrFrontier\runbook-evidence\cloud-foundation-review'
.\infra\src\scripts\runbooks\Get-CloudFoundationPlan.ps1 `
    -TenantAlias 'caldova25156897' `
    -Stages DEV,TEST,PROD `
    -ReportPath $report

$manifest = Get-Content -Raw (Join-Path $report 'cloud-execution-manifest.json') | ConvertFrom-Json
$manifest.digest
```

The planner writes `cloud-assessment.json`, `cloud-plan.json`, `cloud-execution-manifest.json`, and `cloud-plan-evidence.json`. Planning evidence uses `Status = 'Planned'` and `ShouldProcessDecision = 'NotApplicable'`.

The only classifications are `NoChange`, `Create`, `Update`, `Manual`, `Blocked`, and `Refused`. Every `Create` or `Update` binds method, URI, canonical body digest, target, scope, and expected postcondition. Non-mutating classifications never carry a body digest.

Optional formatting is exactly `az bicep format --file <absoluteSource> --stdout`; output is compared or discarded. Formatting is omitted when `--stdout` is unsupported. The source Bicep SHA-256 must remain unchanged. Build output is an exact external file under `RunDirectory`; what-if and deployment use that identical compiled path and digest.

## Approval and Apply

Review every target, classification, method, URI, body digest, required permission, manual item, blocking item, and expected postcondition. First prove the execution path without mutation:

```powershell
.\infra\src\scripts\runbooks\Invoke-CloudFoundation.ps1 `
    -TenantAlias 'caldova25156897' `
    -ExecutionManifestPath (Join-Path $report 'cloud-execution-manifest.json') `
    -AssessmentPath (Join-Path $report 'cloud-assessment.json') `
    -ApprovedDigest $manifest.digest `
    -ReportPath $report `
    -Apply `
    -WhatIf
```

After review, repeat without `-WhatIf`. `-WhatIf` wins over `-Apply`. Apply requires the exact fresh digest, current source and assessment digests, exact delegated context, current permissions, and unchanged tool identities. Each provider boundary calls `ShouldProcess`; declined confirmation performs no write.

Execution is check-then-act and idempotent. GitHub reads the exact repository or ruleset before and after change. Entra proves exact absence or reads the exact object. Azure deploys only validated bytes and requires `Succeeded`. Azure DevOps proves exact-name absence and reads the returned stable ID. A failure stops dependent providers.

## Manual and Blocking Actions

| Surface | Classification | Attended procedure | Required role | Read-back |
|---|---|---|---|---|
| Entra consent or permissions | `Manual`; credential or federation creation is `Blocked` | Entra admin center → Applications → App registrations → exact target app → API permissions; grant only separately approved consent | Application/Cloud Application Administrator; stronger role when consent requires it | Exact `az ad app show`; credential collections remain empty |
| Power Platform environments | `Manual` | Power Platform admin center → Manage → Environments → New; use exact manifest name, region, type, URL, and Dataverse choice | Power Platform, Dynamics 365, or policy-required administrator | Select the exact named profile and run `pac org who` |
| SharePoint sites | `Manual` | SharePoint admin center → Active sites → Create; use exact URL and owner; add no content | SharePoint or policy-required administrator | Exact Graph site metadata ID and `webUrl` |
| Existing Azure DevOps project updates | `Blocked` | Do not update project metadata in this increment | Future reviewed Project Administrator operation | Stable-ID assessment remains read-only |
| Azure DevOps service connections | `Blocked` | Route to architecture and security review; do not create | Future reviewed endpoint role | No completion claim |
| Azure DevOps approvals and checks | `Manual` | Project settings → exact protected resource → Approvals and checks | Protected-resource administrator | Supported checks metadata or two-person portal verification |
| Azure Boards/GitHub connection | `Manual` | Project settings → GitHub connections → New connection → GitHub App; approve only the reviewed repository | Project Administrator and GitHub owner | Exact connection metadata, or retain `Manual` |

GitHub Environments, workflow settings, OIDC/federated credentials, pipelines, service-principal runbook login, app passwords/certificates, PATs, and secret-bearing service connections are excluded. A service principal may be a target solution resource but never executes this runbook.

Product-owned references:

- [Update a GitHub repository](https://docs.github.com/en/rest/repos/repos#update-a-repository)
- [Create a GitHub ruleset](https://docs.github.com/en/rest/repos/rules#create-a-repository-ruleset)
- [Update a GitHub ruleset](https://docs.github.com/en/rest/repos/rules#update-a-repository-ruleset)
- [Azure subscription deployment](https://learn.microsoft.com/en-us/cli/azure/deployment/sub#az-deployment-sub-create)
- [Microsoft Entra application CLI](https://learn.microsoft.com/en-us/cli/azure/ad/app)
- [Microsoft Entra service-principal CLI](https://learn.microsoft.com/en-us/cli/azure/ad/sp)
- [Azure DevOps project CLI](https://learn.microsoft.com/en-us/cli/azure/devops/project)
- [Power Platform environment administration](https://learn.microsoft.com/en-us/power-platform/admin/environments-overview)
- [Create a SharePoint site](https://learn.microsoft.com/en-us/sharepoint/create-site-collection)
- [Azure DevOps service connections](https://learn.microsoft.com/en-us/azure/devops/pipelines/library/service-endpoints)
- [Azure DevOps approvals and checks](https://learn.microsoft.com/en-us/azure/devops/pipelines/process/approvals)
- [Connect Azure Boards to GitHub](https://learn.microsoft.com/en-us/azure/devops/boards/github/connect-to-github)

## Evidence

Every envelope records generation time, source commit, assessment digest, operator ID, `ShouldProcess` decision, plan digest, manifest digest, tool path/version/SHA-256 set, closed provider read-back, separate manual items, structured recovery, and final context when available.

Planning `ManualItems` have exactly `service,targetId,condition,owner,diagnostic,recovery`. They never contain a decision or provider read-back. Provider read-back retains only approved stable IDs, state, provisioning status, body digest, and credential-absence counts; raw CLI/REST bodies, headers, and stderr are prohibited.

A complete run uses `Verified`. Any partial or incomplete run uses `Failed`, never “succeeded” or “partial”. Categories include `PartialMutation`, `ContextChanged`, `MutationFailed`, `ReadBackUnavailable`, `PostconditionMismatch`, `RefusedOperation`, `BlockedOperation`, and `IncompleteManualActions`.

## Recovery

Follow [Bootstrap Recovery](../19-bootstrap-recovery.md). Each recovery record contains `service`, `targetId`, `lastProvenState`, `safeDiagnostic`, `owner`, `nextAction`, `requiresNewPlan = true`, and `requiresNewApproval = true`.

Preserve a verified GitHub change and let reassessment classify it `NoChange`. Query an Azure deployment by exact name and resource IDs. Query Azure DevOps by the returned operation/project ID before retrying create. Query Entra by exact object/app ID and display name. Never reuse the old approval. Reassess, regenerate action and body digests, and obtain new approval.

## Cleanup and Sign-out

After evidence is secured, use supported exact sign-out:

```powershell
gh auth logout --hostname github.com
az logout
az account clear
pac auth delete --name hr-<TenantAlias>-dev
pac auth delete --name hr-<TenantAlias>-test
pac auth delete --name hr-<TenantAlias>-prod
```

If the installed PAC version supports only index deletion, run `pac auth list`, identify one exact unique profile, delete only that index, and read back absence. Never delete authentication cache folders.

## Definition of Done

The foundation is done only when:

1. Initial and final delegated contexts match the reviewed tenant, subscription, user, GitHub repository, Azure DevOps organization and acting user, and exact Power Platform stage IDs.
2. Existing Azure DevOps intent matches its reviewed project ID; Create intent proves exact-name absence, effective permission, bound name/process/visibility, and returned project ID.
3. An active Entra directory role is proven, and successful exact-name/appId reads establish absence.
4. Tool absolute paths, versions, and SHA-256 values remain unchanged.
5. Source Bicep remains unchanged; optional formatting is stdout-only; what-if and deployment use identical external compiled bytes; no adjacent `main.json` exists.
6. Every supported action is verified `NoChange` or `Changed` with its exact postcondition.
7. Planning evidence is `Planned`; complete invocation evidence is `Verified`.
8. Every manual, blocked, refused, stale, mismatched, unauthorized, unavailable, ambiguous, failed, incomplete, or partial result is `Failed` with exact recovery and means the foundation is not done.
9. Evidence is outside Git and contains only the closed safe projections.
10. Power Platform and SharePoint remain Manual; service connections remain Blocked; approvals and checks remain Manual.
