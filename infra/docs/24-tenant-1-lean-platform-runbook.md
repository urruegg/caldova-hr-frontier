# Tenant 1 Lean Platform Runbook

| Field | Value |
|---|---|
| **Version** | 1.5 |
| **Date** | 2026-09-30 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Tenant 1 engineering platform |
| **References** | [Tenant 1 Lean Engineering Platform Design](../../docs/specs/2026-09-28-tenant-1-lean-engineering-platform-design.md), [Implementation Plan](../../docs/plans/2026-09-28-tenant-1-lean-engineering-platform-implementation.md), [Draft Acceptance Review](../../docs/reviews/2026-09-28-tenant-1-lean-engineering-platform-acceptance-review.md), [Bootstrap Recovery](19-bootstrap-recovery.md), [Azure Boards Population Runbook](21-azure-boards-population-runbook.md) |

This runbook is the active Tenant 1 operator path. It is attended, local, and fail-closed. It performs discovery, Bicep build, subscription `what-if`, boundary validation, and context and access read-back. It creates no deployment, trust, identity, role assignment, GitHub Environment, Azure Pipeline, or Power Platform deployment.

Every checkpoint below is `Not Run`. This document fixes the order and acceptance evidence; it does not authorize or record execution.

## Merge Tool Changes

**Outcome: Not Run.** Merge the reviewed Tasks 1-7 changes and the Task 8 source and safety-verification changes before activating governance. The implementation pull request uses the old governance state. It must not apply the desired ruleset, change repository settings, create a Boards item, delete an Azure Repo, or perform any other live action.

The merge must preserve the clean branch history and the approved committed deletion of the tracked Tenant 1 transition files. Record only the reviewed merge commit and merge-base safety result in the Draft acceptance review; do not treat this runbook or a source commit as live execution evidence.

## Current-Main Validator

**Outcome: Not Run.** After the implementation pull request is merged, check out the merged `main` commit and run the repository validator against that exact SHA. Require one completed, successful `.github/workflows/validate-repository.yml` run and exactly one successful job named `Repository setup validation`.

Do not apply GitHub governance before the tool changes are merged to `main` and the successful current-`main` validator run has been read back. Pass that run ID to `Enable-GitHubGovernance.ps1`; never substitute a branch run, stale SHA, inferred status, or second check.

## Local Validation and Access Read-Back

**Outcome: Not Run.** Complete the attended local checkpoint before GitHub governance. It comprises the following backup, access, discovery, sanitized-review, Bicep-build, subscription-`what-if`, boundary, and access-read-back sections. A failure in any section stops the sequence; local validation does not authorize a governance, Boards, repository, role, or deployment mutation.

## Private Configuration and Backup

The ignored and validated `tenant1.local.psd1` file is the active configuration. The approved committed deletion of the two tracked Tenant 1 transition files is complete. Do not recreate either tracked file; recovery restores only the ignored local configuration.

Open an attended PowerShell session and set the exact local paths:

```powershell
$RepositoryRoot = 'C:\Users\urruegg\source\urruegg\caldova-hr-frontier\.worktrees\tenant1-lean-platform'
$OperatorRoot = Join-Path $env:LOCALAPPDATA 'Caldova\HrFrontier\tenant1'
$ConfigPath = Join-Path $RepositoryRoot 'infra\src\config\tenants\tenant1.local.psd1'
$DiscoveryPath = Join-Path $OperatorRoot 'discovery.json'
$ParameterRoot = Join-Path $OperatorRoot 'parameters'
$BackupRoot = [System.IO.Path]::GetFullPath(
    (Read-Host 'Enter the mounted encrypted external backup root in a separate failure domain').Trim()
)
[void](New-Item -ItemType Directory -Path $OperatorRoot -Force)
[void](New-Item -ItemType Directory -Path $ParameterRoot -Force)
Set-Location $RepositoryRoot
```

`$BackupRoot` is operator supplied. It must already exist on encrypted external
storage or a separately recoverable encrypted service outside the workstation's
primary failure domain. `%LOCALAPPDATA%`, the repository, and another folder on
the same unprotected workstation are not sufficient as the sole backup.

Confirm the exact ignored local boundary, create a dated external backup, compare
SHA-256, restore to a separate destination, and validate both the restored copy
and the active ignored copy without displaying their values:

```powershell
if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) { throw 'Tenant 1 local configuration is missing.' }
git check-ignore --quiet -- $ConfigPath
if ($LASTEXITCODE -ne 0) { throw 'Tenant 1 local configuration is not ignored.' }
if (-not (Test-Path -LiteralPath $BackupRoot -PathType Container)) { throw 'Encrypted external backup root does not exist.' }
$LocalAppDataRoot = [System.IO.Path]::GetFullPath($env:LOCALAPPDATA).TrimEnd('\') + '\'
if ($BackupRoot.StartsWith($LocalAppDataRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'BackupRoot must not use LOCALAPPDATA as the sole backup.'
}

$BackupSet = Join-Path $BackupRoot ('tenant1-{0}' -f [datetime]::UtcNow.ToString('yyyyMMddTHHmmssZ'))
$RestoreRoot = Join-Path $OperatorRoot ('restore-proof-{0}' -f [guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $BackupSet, $RestoreRoot -Force)
$BackupPath = Join-Path $BackupSet 'tenant1.local.psd1'
$RestorePath = Join-Path $RestoreRoot 'tenant1.local.psd1'
Copy-Item -LiteralPath $ConfigPath -Destination $BackupPath

$SourceHash = (Get-FileHash -LiteralPath $ConfigPath -Algorithm SHA256).Hash
$BackupHash = (Get-FileHash -LiteralPath $BackupPath -Algorithm SHA256).Hash
if ($SourceHash -cne $BackupHash) { throw 'Encrypted external backup SHA-256 mismatch.' }
[System.IO.File]::WriteAllText(
    (Join-Path $BackupSet 'tenant1.local.sha256'),
    $SourceHash,
    [System.Text.UTF8Encoding]::new($false)
)

Copy-Item -LiteralPath $BackupPath -Destination $RestorePath
$RestoreHash = (Get-FileHash -LiteralPath $RestorePath -Algorithm SHA256).Hash
if ($RestoreHash -cne $SourceHash) { throw 'Separate restore SHA-256 mismatch.' }

Import-Module '.\infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1' -Force
Import-TenantConfiguration -Path $RestorePath -ValidationStage Discovery -ExpectedPublicTenantKey tenant1 | Out-Null
Import-TenantConfiguration -Path $ConfigPath -ValidationStage Bootstrap -ExpectedPublicTenantKey tenant1 -RequireLocalUntracked | Out-Null
Remove-Item -LiteralPath $RestoreRoot -Recurse -Force
```

Keep the backup set and its hash record encrypted outside Git. Protect the
operator working root with the workstation's existing user-only controls. Never
commit the configuration, backup, hash, raw discovery, generated parameters,
access evidence, or raw `what-if` output.

## Attended Context and Minimum Access

Access is provisioned and approved separately before this sprint. The operator must use a pre-existing, separately approved least-privilege assignment that can execute the reviewed subscription `what-if`. This sprint performs no role mutation.

```powershell
$Account = az account show --output json | ConvertFrom-Json
if ([string]$Account.user.type -cne 'user') { throw 'An attended user context is required.' }
$Caller = az ad signed-in-user show --output json | ConvertFrom-Json
[void][guid]$Caller.id
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

After the sanitized review and separate access confirmation, generate one local parameter file. The lean Bicep contract contains no role definition, role assignment, validation role, or principal parameter:

```powershell
.\infra\src\scripts\New-TenantBicepParameters.ps1 `
    -PublicTenantKey tenant1 `
    -TenantConfigurationPath $ConfigPath `
    -OutputPath $ParameterRoot
$ParameterFile = @(Get-ChildItem -LiteralPath $ParameterRoot -Filter '*.bicepparam' -File)
if ($ParameterFile.Count -ne 1) { throw 'Expected exactly one generated parameter file.' }
```

The bootstrap command compiles `infra/src/bicep/main.bicep` and the selected `.bicepparam` file before it contacts the deployment `what-if` API. A compiler or parameter mismatch stops the run. Authorization role-definition or role-assignment Create, Modify, or Delete results are rejected.

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

**Outcome: Not Run.** This checkpoint starts only after the successful current-`main` validator and the complete local validation and access read-back. A separately attended repository owner runs the reviewed governance script first with `-WhatIf`, reviews the closed proposal, and only then may provide separate approval for apply and exact read-back.

Tenant 1 uses this GitHub repository as the sole product-source repository. The lean governance target is the minimal `main` ruleset and repository settings described by the approved design, read back after any separately approved change. This runbook does not create a bootstrap Environment, OIDC trust, or workflow-hosted discovery path.

The solo-owner target requires pull requests, resolved conversations, the single `Repository setup validation` check, blocked force pushes and branch deletion, squash-only merge, merged-branch deletion, disabled GitHub Projects, and enabled Dependabot security updates. It requires zero approving reviews and does not require CODEOWNERS review. No governance mutation is authorized by the local Azure validation steps.

## Basic Boards Issue

**Outcome: Not Run.** Start this checkpoint only after GitHub governance has been applied and read back exactly. Planning is non-mutating. Applying the reviewed unchanged plan requires separate attended approval and must preserve the built-in Basic process, existing team, project-root area, and selected current sprint. Before planning, require the selected team's settings to contain exactly the project-root area and its current-iterations endpoint to return exactly one item whose full path equals `CurrentSprintPath`. The sprint performs no role mutation.

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

The plan must read back the Basic process, exact existing team, its exact project-root area setting, exactly one current team iteration whose full path equals `CurrentSprintPath`, the matching classification node, and either zero or one Issue with the stable tag `tenant1-lean-platform-traceability`. Zero matches plans `Create`; one exact match plans `Reuse`; more than one match stops as ambiguous. Missing, multiple, malformed, or mismatched team/current-iteration state stops before WIQL or mutation. A missing, null, or non-array WIQL `workItems` property is indeterminate and stops; it never plans `Create`. `CurrentSprintPath` is the full observed project path. The script removes exactly the `<project>\` prefix before calling the classification-node REST route (`Caldova HR Frontier\Current` becomes `Current`, and nested suffixes remain nested); relative, foreign-project, `Iteration`-prefixed, empty-segment, and mixed-separator paths stop before any Azure DevOps call. `-WhatIf` and the default mode perform no Azure DevOps mutation.

Omit sprint dates unless the attended owner supplies and approves both exact current-sprint dates. When approved dates exist, add both `SprintStartDate` and `SprintFinishDate` to `$BoardsParameters`. The script changes only the selected current sprint and reads both dates back.

After separate attended approval, apply the unchanged plan:

```powershell
.\infra\src\scripts\Initialize-AzureBoardsLeanSprint.ps1 @BoardsParameters -Apply
```

Issue creation uses `POST` to the `wit/workitems` resource with route parameters for the exact project and `type=Issue`, and sends the JSON Patch body as `application/json-patch+json`. After any create or sprint-date update, the script reruns the stable-tag WIQL query and requires exactly one result whose ID equals the read-back Issue ID. A missing result, changed ID, or concurrent duplicate stops before `Status = Applied`.

Require `Status = Applied` and a positive `IssueId`. Preserve that Issue as the durable cross-system traceability item.

## Empty Azure Repo Checkpoint

**Outcome: Not Run.** This is optional and is not a dependency of local validation, governance, the Basic Boards Issue, or the final governed transaction. Proof collection is read-only. Deletion is destructive and remains behind the separate attended checkpoint below; an empty-repository proof is not deletion approval.

The empty Azure Repo has no lean-platform dependency. This implementation collects proof only: it does not delete or mutate the repository. Obtain the exact repository and project IDs as attended input, then read metadata, refs, and recursive items through Azure DevOps REST 7.1:

```powershell
$AzureRepoId = (Read-Host 'Enter the exact empty Azure Repo GUID').Trim()
$ParsedAzureRepoId = [guid]::Empty
if ($AzureRepoId -cnotmatch '^[0-9a-fA-F-]{36}$' -or
    -not [guid]::TryParse($AzureRepoId, [ref]$ParsedAzureRepoId)) {
    throw 'Azure Repo ID must be a GUID.'
}
$OrganizationUrl = (Read-Host 'Enter the Azure DevOps organization URL').Trim()
$ProjectId = (Read-Host 'Enter the exact Azure DevOps project GUID').Trim()
$ParsedProjectId = [guid]::Empty
if ($ProjectId -cnotmatch '^[0-9a-fA-F-]{36}$' -or
    -not [guid]::TryParse($ProjectId, [ref]$ParsedProjectId)) {
    throw 'Project ID must be a GUID.'
}

function Invoke-AzureDevOpsJsonRead {
    param(
        [Parameter(Mandatory)][string]$Description,
        [Parameter(Mandatory)][string[]]$ArgumentList
    )

    $Output = @(& az @ArgumentList 2>&1)
    $ExitCode = $LASTEXITCODE
    $Text = ($Output | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    if ($ExitCode -ne 0) { throw "$Description failed with exit code ${ExitCode}: $Text" }
    if ([string]::IsNullOrWhiteSpace($Text)) { throw "$Description returned an empty body." }
    try {
        $Text | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "$Description returned malformed JSON: $($_.Exception.Message)"
    }
}

$Repository = Invoke-AzureDevOpsJsonRead -Description 'Exact Azure Repo metadata read' -ArgumentList @(
    'repos', 'show',
    '--id', $AzureRepoId,
    '--organization', $OrganizationUrl,
    '--project', $ProjectId,
    '--output', 'json'
)
$Refs = Invoke-AzureDevOpsJsonRead -Description 'Exact Azure Repo refs read' -ArgumentList @(
    'devops', 'invoke',
    '--organization', $OrganizationUrl,
    '--area', 'git',
    '--resource', 'refs',
    '--route-parameters', "project=$ProjectId", "repositoryId=$AzureRepoId",
    '--api-version', '7.1',
    '--output', 'json'
)
$Items = Invoke-AzureDevOpsJsonRead -Description 'Exact Azure Repo recursive items read' -ArgumentList @(
    'devops', 'invoke',
    '--organization', $OrganizationUrl,
    '--area', 'git',
    '--resource', 'items',
    '--route-parameters', "project=$ProjectId", "repositoryId=$AzureRepoId",
    '--query-parameters', 'scopePath=/', 'recursionLevel=Full', 'includeContentMetadata=true',
    '--api-version', '7.1',
    '--output', 'json'
)

$ValidatedRepoProof = & (Join-Path $RepositoryRoot 'infra\src\scripts\Assert-AzureRepoEmptyProof.ps1') `
    -AzureRepoId $AzureRepoId `
    -ProjectId $ProjectId `
    -Repository $Repository `
    -Refs $Refs `
    -Items $Items
```

The validator requires a repository response object with matching string GUIDs at `id` and `project.id`, a non-empty string `name`, numeric `size` equal to zero, and a present `defaultBranch` whose value is explicitly null or the empty string. It requires refs and items response objects with numeric `count`, an actual array `value`, equality between `count` and `value.Count`, and zero elements. `{}`, missing properties, null or wrong-type collections, string numeric values, count mismatches, and foreign IDs all stop. Any failed call, `403`, `404`, empty body, malformed response, branch, ref, item, ambiguity, or indeterminate result stops.

Capture only the validated exact stable IDs and sanitized predicate results outside Git:

```powershell
$RepoProofPath = Join-Path $OperatorRoot 'empty-azure-repo-proof.json'
$RepoProof = [ordered]@{
    collectedAtUtc = [datetime]::UtcNow.ToString('o')
    organizationUrl = $OrganizationUrl
    projectId = $ValidatedRepoProof.projectId
    repositoryId = $ValidatedRepoProof.repositoryId
    repositoryName = $ValidatedRepoProof.repositoryName
    size = $ValidatedRepoProof.size
    defaultBranch = $ValidatedRepoProof.defaultBranch
    refCount = $ValidatedRepoProof.refCount
    itemCount = $ValidatedRepoProof.itemCount
    predicates = $ValidatedRepoProof.predicates
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

This runbook supplies no Azure Repo deletion approval and does not run the command. Without a separate explicit approval, leave the Azure Repo unchanged. The tracked Tenant 1 transition-file deletion is already committed and is not part of this optional checkpoint.

## Final Governed Transaction

**Outcome: Not Run.** Begin only after GitHub governance and the durable Basic Boards Issue are applied and read back. The optional empty Azure Repo checkpoint is not a prerequisite and cannot be used to imply deletion approval.

After the separately approved GitHub and Boards checkpoints are complete, use one real product-source transaction:

1. select the durable Basic Issue;
2. create a branch and pull request for an approved change;
3. place `Fixes AB#<positive-integer>` in the pull-request body;
4. pass the single `Repository setup validation` workflow;
5. resolve every review conversation;
6. squash-merge through the protected branch;
7. verify the source branch is deleted, `main` is green, and the Boards link and state transition read back correctly.

The transaction does not prove an Azure deployment, Power Platform deployment, or Azure Pipeline.

## Acceptance Read-Back

**Outcome: Not Run.** Use the [Draft Acceptance Review](../../docs/reviews/2026-09-28-tenant-1-lean-engineering-platform-acceptance-review.md) as the control-by-control record. Keep every outcome `Not Run` until the applicable checkpoint has current, sanitized read-back. Task 8 may record source and safety-verification evidence, but post-merge, governance, Boards, optional deletion-decision, final-transaction, and merged-`main` outcomes remain `Not Run` until their own later attended execution.

Do not promote the review from `Draft` or infer live success from source, plans, `what-if`, historical evidence, the committed source deletion, or this ordered procedure. All 14 acceptance outcomes remain `Not Run`; the empty Azure Repo decision remains optional and destructive.

## Failure and Recovery

Stop on every failed or incomplete check. Preserve only local, sanitized evidence and follow [Bootstrap Recovery](19-bootstrap-recovery.md). Do not broaden access, change roles, switch identities, change subscriptions, activate trust, create a deployment, recreate the deleted tracked transition files, or retry against Tenant 2.

After correction, restart at **Attended Context and Minimum Access**. Never splice preflight evidence from one attempt into another.

## Acceptance

Accept this run only when:

- the ignored local Tenant 1 configuration and its encrypted external backup in a separate failure domain exist outside version control;
- source, backup, and separate-restore SHA-256 values match, the restored copy imports against the schema, and the exact ignored local file passes live-boundary validation;
- attended context and separately approved pre-existing minimum access pass before and after `what-if`;
- local discovery, sanitized review, Bicep build, subscription `what-if`, and boundary validation succeed;
- no role assignment, trust, GitHub Environment, Azure Pipeline, deployment, or Power Platform release was created, changed, or deleted;
- Tenant 2 was not selected or changed;
- `what-if` is recorded only as planning evidence; and
- later governance, Boards, repository, and final-transaction checkpoints are supported by their own current read-back;
- the approved committed Tenant 1 transition-file deletion remains intact without being treated as live acceptance evidence; all 14 Draft outcomes remain `Not Run`; and
- the optional empty Azure Repo decision is never treated as a prerequisite or implicit deletion approval.
