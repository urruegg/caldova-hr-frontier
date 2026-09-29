# Tenant 1 Lean Platform Runbook

| Field | Value |
|---|---|
| **Version** | 1.2 |
| **Date** | 2026-09-29 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Tenant 1 engineering platform |
| **References** | [Tenant 1 Lean Engineering Platform Design](../../docs/specs/2026-09-28-tenant-1-lean-engineering-platform-design.md), [Implementation Plan](../../docs/plans/2026-09-28-tenant-1-lean-engineering-platform-implementation.md), [Bootstrap Recovery](19-bootstrap-recovery.md), [Azure Boards Population Runbook](21-azure-boards-population-runbook.md) |

This runbook is the active Tenant 1 operator path. It is attended, local, and fail-closed. It performs discovery, Bicep build, subscription `what-if`, boundary validation, and context and access read-back. It creates no deployment, trust, identity, role assignment, GitHub Environment, Azure Pipeline, or Power Platform deployment.

## Private Configuration and Backup

The ignored and validated `tenant1.local.psd1` file is the active configuration. The two tracked Tenant 1 transition files remain temporarily because deletion approval was unavailable; they are not the active input and must not be deleted under this runbook.

Open an attended PowerShell session and set the exact local paths:

```powershell
$RepositoryRoot = 'C:\Users\urruegg\source\urruegg\caldova-hr-frontier\.worktrees\tenant1-lean-platform'
$OperatorRoot = Join-Path $env:LOCALAPPDATA 'Caldova\HrFrontier\tenant1'
$ConfigPath = Join-Path $RepositoryRoot 'infra\src\config\tenants\tenant1.local.psd1'
$DiscoveryPath = Join-Path $OperatorRoot 'discovery.json'
$ParameterRoot = Join-Path $OperatorRoot 'parameters'
[void](New-Item -ItemType Directory -Path $OperatorRoot -Force)
[void](New-Item -ItemType Directory -Path $ParameterRoot -Force)
Set-Location $RepositoryRoot
```

Confirm that Git ignores the configuration, then create a local backup outside Git:

```powershell
if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) { throw 'Tenant 1 local configuration is missing.' }
git check-ignore --quiet -- $ConfigPath
if ($LASTEXITCODE -ne 0) { throw 'Tenant 1 local configuration is not ignored.' }
$BackupRoot = Join-Path $OperatorRoot 'backup'
[void](New-Item -ItemType Directory -Path $BackupRoot -Force)
Copy-Item -LiteralPath $ConfigPath -Destination (Join-Path $BackupRoot 'tenant1.local.psd1') -Force
```

Protect the operator root with the workstation's existing user-only controls. Never commit the configuration, backup, raw discovery, generated parameters, access evidence, or raw `what-if` output.

## Attended Context and Minimum Access

Access is provisioned and approved separately before this sprint. The operator must use a pre-existing, separately approved least-privilege assignment that can execute the reviewed subscription `what-if`. This sprint performs no role mutation.

```powershell
$Account = az account show --output json | ConvertFrom-Json
if ([string]$Account.user.type -cne 'user') { throw 'An attended user context is required.' }
$Caller = az ad signed-in-user show --output json | ConvertFrom-Json
$ValidationPrincipalId = [guid]$Caller.id
```

Compare `$Account.tenantId` and `$Account.id` with the locally reviewed configuration before continuing. Confirm the access approval through the separately governed record; do not copy that approval into Git.

`Invoke-TenantBootstrap.ps1` queries the attended user with Azure CLI group expansion, then requires exactly one direct-user or group assignment to the approved custom `<NamingRoot>-deployment-validation` role at the exact subscription scope. Its role definition must contain exactly:

```text
*/read
Microsoft.Resources/deployments/read
Microsoft.Resources/deployments/validate/action
Microsoft.Resources/deployments/whatIf/action
```

The role must be `CustomRole`, have one permission block, use only the exact subscription as its assignable scope, and have empty `notActions`, `dataActions`, and `notDataActions`. Wildcard `*`, Owner, Contributor, User Access Administrator, Role Based Access Control Administrator, additional assignments, and any extra write or delete action fail preflight.

Do not run `az role assignment create`, `az role assignment delete`, `Grant-TemporaryBootstrapRoles.ps1`, or `Remove-TemporaryRoleAssignments.ps1`.

## Local Discovery

Run discovery only from the attended user session:

```powershell
.\infra\src\scripts\Invoke-TenantDiscovery.ps1 `
    -PublicTenantKey tenant1 `
    -TenantConfigurationPath $ConfigPath `
    -AuthenticationMode Interactive `
    -OutputPath $DiscoveryPath
```

Discovery must finish successfully for the exact Tenant 1 tenant and subscription. `Unauthorized`, `Unavailable`, `Ambiguous`, stale evidence, a tenant mismatch, or a subscription mismatch stops the run.

## Sanitized Review

Review `$DiscoveryPath` locally. Confirm the tenant, subscription, stable identifiers, service statuses, collection time, and intended boundary. Do not paste the raw record into an issue, pull request, chat, workflow artifact, or repository file.

A shareable summary may contain only status, timestamp, approved stable identifiers, and response hashes. Remove tenant-private values and unrestricted object or membership details. If sanitization is uncertain, share nothing and escalate.

## Bicep Build

After the sanitized review and separate access confirmation, derive the exact attended principal and generate one local parameter file:

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

The bootstrap command compiles `infra/src/bicep/main.bicep` and the selected `.bicepparam` file before it contacts the deployment `what-if` API. A compiler error, parameter mismatch, or principal mismatch stops the run.

## Subscription What-If

Execute only the attended, local `WhatIfOnly` path:

```powershell
.\infra\src\scripts\Invoke-TenantBootstrap.ps1 `
    -PublicTenantKey tenant1 `
    -TenantConfigurationPath $ConfigPath `
    -EvidencePath $DiscoveryPath `
    -ParameterFile $ParameterFile[0].FullName `
    -WhatIfOnly
```

The script invokes `az deployment sub what-if`; it has no deployment-create path. `what-if` is planning evidence only and is not deployment evidence. Never substitute `az deployment sub create`, `New-AzSubscriptionDeployment`, or a portal deployment.

## Boundary and Access Read-Back

The bootstrap script writes `what-if.json` and `access-validation.json` beside the local discovery file. It validates the `what-if` boundary, then repeats `az account show`, signed-in-user discovery, exact-scope assignment reads, and role-definition reads.

Acceptance requires the same attended principal, tenant, subscription, assignee query, user-or-group principal type, scope, assignment ID, exact custom role definition, action sets, and exclusions before and after `what-if`. Any context or access drift blocks acceptance. Confirm that Tenant 2 was neither selected nor changed and that no private artifact is tracked:

```powershell
git status --short
$TrackedLocalConfig = @(git ls-files -- 'infra/src/config/tenants/tenant1.local.psd1')
if ($TrackedLocalConfig.Count -gt 0) { throw 'The local Tenant 1 configuration is tracked.' }
```

## GitHub Governance

Tenant 1 uses this GitHub repository as the sole product-source repository. The lean governance target is the minimal `main` ruleset and repository settings described by the approved design, read back after any separately approved change. This runbook does not create a bootstrap Environment, OIDC trust, or workflow-hosted discovery path.

No governance mutation is authorized by the local Azure validation steps. Use a separately reviewed governance task and preserve the single `Repository setup validation` check.

## Basic Boards

Azure Boards remains Basic: one existing project, its existing team and project-root area, and the hierarchy `Epic -> Issue -> Task`. Do not convert the process to Agile, create six iterations, add a second team, or make the optional 19-idea portfolio a prerequisite.

Use one durable Basic Issue for the final `Fixes AB#<positive-integer>` proof. Do not delete it after validation. Boards changes and read-back require their own attended approval. The optional 19-Epic tool remains unchanged and is not required for lean acceptance.

Create the deterministic plan outside Git from the attended Azure DevOps user session:

```powershell
$BoardsPlanPath = Join-Path $OperatorRoot 'azure-boards-lean-plan.json'
$BoardsParameters = @{
    OrganizationUrl = 'https://dev.azure.com/<exact-organization>/'
    ProjectName = 'Caldova HR Frontier'
    TeamName = 'Caldova HR Frontier Team'
    CurrentSprintPath = 'Caldova HR Frontier\Current'
    IssueTitle = 'Tenant 1 lean engineering platform acceptance'
    PlanOutputPath = $BoardsPlanPath
}
.\infra\src\scripts\Initialize-AzureBoardsLeanSprint.ps1 @BoardsParameters -WhatIf
```

The plan must read back the Basic process, exact existing team, project-root area, exact current sprint, and either zero or one Issue with the stable tag `tenant1-lean-platform-traceability`. Zero matches plans `Create`; one exact match plans `Reuse`; more than one match stops as ambiguous. `-WhatIf` and the default mode perform no Azure DevOps mutation.

Omit sprint dates unless the attended owner supplies and approves both exact current-sprint dates. When approved dates exist, add both `SprintStartDate` and `SprintFinishDate` to `$BoardsParameters`. The script changes only the selected current sprint and reads both dates back.

After separate attended approval, apply the unchanged plan:

```powershell
.\infra\src\scripts\Initialize-AzureBoardsLeanSprint.ps1 @BoardsParameters -Apply
```

Require `Status = Applied` and a positive `IssueId`. Preserve that Issue as the durable cross-system traceability item.

## Empty Azure Repo Checkpoint

The empty Azure Repo has no lean-platform dependency. This implementation collects proof only: it does not delete or mutate the repository. Obtain the exact repository and project IDs as attended input, then read metadata, refs, and recursive items through Azure DevOps REST 7.1:

```powershell
$AzureRepoId = (Read-Host 'Enter the exact empty Azure Repo GUID').Trim()
if ($AzureRepoId -cnotmatch '^[0-9a-fA-F-]{36}$') { throw 'Azure Repo ID must be a GUID.' }
$OrganizationUrl = (Read-Host 'Enter the Azure DevOps organization URL').Trim()
$ProjectId = (Read-Host 'Enter the exact Azure DevOps project GUID').Trim()
if ($ProjectId -cnotmatch '^[0-9a-fA-F-]{36}$') { throw 'Project ID must be a GUID.' }

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

Any failed call, `403`, `404`, empty body, malformed response, branch, ref, item, ambiguity, or indeterminate result stops. Capture only the exact stable IDs and sanitized predicate results outside Git:

```powershell
$RepoProofPath = Join-Path $OperatorRoot 'empty-azure-repo-proof.json'
$RepoProof = [ordered]@{
    collectedAtUtc = [datetime]::UtcNow.ToString('o')
    organizationUrl = $OrganizationUrl
    projectId = $ProjectId
    repositoryId = $AzureRepoId
    repositoryName = [string]$Repository.name
    size = [long]$Repository.size
    defaultBranch = [string]$Repository.defaultBranch
    refCount = @($Refs.value).Count
    itemCount = @($Items.value).Count
    predicates = [ordered]@{
        sizeIsZero = ([long]$Repository.size -eq 0)
        defaultBranchIsEmpty = [string]::IsNullOrWhiteSpace([string]$Repository.defaultBranch)
        refsAreEmpty = (@($Refs.value).Count -eq 0)
        itemsAreEmpty = (@($Items.value).Count -eq 0)
    }
}
[System.IO.File]::WriteAllText(
    $RepoProofPath,
    ($RepoProof | ConvertTo-Json -Depth 5),
    [System.Text.UTF8Encoding]::new($false)
)
```

### Separate Destructive Checkpoint

The proof above is not deletion approval. Stop after capturing it. Any future deletion is a separate attended destructive checkpoint:

1. Display the exact repository ID, repository name, project ID, and all four successful predicates.
2. Ask the Azure DevOps project administrator whether to delete that exact repository.
3. Stop on anything other than explicit attended approval.
4. Only after that approval, run exactly:

   ```powershell
   az repos delete --id $AzureRepoId --organization $OrganizationUrl --project $ProjectId --yes
   ```

5. Read back by exact repository ID. Only a post-delete `404` is expected; success, `403`, an empty response, or any other result is failure:

   ```powershell
   $DeleteReadBack = @(az repos show --id $AzureRepoId --organization $OrganizationUrl --project $ProjectId 2>&1)
   $DeleteReadBackExitCode = $LASTEXITCODE
   if ($DeleteReadBackExitCode -eq 0) { throw 'Deleted Azure Repo still resolves by exact ID.' }
   if (($DeleteReadBack -join [Environment]::NewLine) -cnotmatch '\b404\b') {
       throw 'Exact Azure Repo post-delete read-back did not return the expected 404.'
   }
   ```

This runbook supplies no deletion approval and does not run the command. Without a separate explicit approval, leave the repository unchanged. The Tenant 1 tracked-file deletion gate also remains deferred.

## Final Governed Transaction

After the separately approved GitHub and Boards checkpoints are complete, use one real product-source transaction:

1. select the durable Basic Issue;
2. create a branch and pull request for an approved change;
3. place `Fixes AB#<positive-integer>` in the pull-request body;
4. pass the single `Repository setup validation` workflow;
5. resolve every review conversation;
6. squash-merge through the protected branch;
7. verify the source branch is deleted, `main` is green, and the Boards link and state transition read back correctly.

The transaction does not prove an Azure deployment, Power Platform deployment, or Azure Pipeline.

## Failure and Recovery

Stop on every failed or incomplete check. Preserve only local, sanitized evidence and follow [Bootstrap Recovery](19-bootstrap-recovery.md). Do not broaden access, change roles, switch identities, change subscriptions, activate trust, create a deployment, delete the tracked transition files, or retry against Tenant 2.

After correction, restart at **Attended Context and Minimum Access**. Never splice preflight evidence from one attempt into another.

## Acceptance

Accept this run only when:

- the ignored local Tenant 1 configuration and its local backup exist outside version control;
- attended context and separately approved pre-existing minimum access pass before and after `what-if`;
- local discovery, sanitized review, Bicep build, subscription `what-if`, and boundary validation succeed;
- no role assignment, trust, GitHub Environment, Azure Pipeline, deployment, or Power Platform release was created, changed, or deleted;
- Tenant 2 was not selected or changed;
- `what-if` is recorded only as planning evidence; and
- later governance, Boards, repository, and final-transaction checkpoints are supported by their own current read-back.
