# Azure Boards Population Runbook

| Field | Value |
|---|---|
| **Version** | 2.2 |
| **Date** | 2026-09-30 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Superseded |
| **Scope** | Infrastructure (Tenant 1) |
| **References** | [Azure Boards Population Design](../../docs/specs/2026-09-25-azure-boards-population-design.md), [Tenant 1 Lean Engineering Platform Design](../../docs/specs/2026-09-28-tenant-1-lean-engineering-platform-design.md), [Tenant 1 Lean Platform Runbook](./24-tenant-1-lean-platform-runbook.md) |

> **STOP — OPTIONAL PORTFOLIO TOOLING.** The 19-Epic population procedure is dormant and not a lean-platform prerequisite. It remains unchanged and requires its own attended approval; do not substitute it for the locked lean Basic Boards operation below.

This runbook separates the active lean Basic Boards operation from the optional portfolio population tool. Both use an already authenticated attended Azure DevOps user context. Neither requires or creates OIDC trust, a service principal, a GitHub Environment, a second team, a non-root area, an Agile process, or additional iterations.

## Lean Basic Boards Operation

Use only the existing Basic project, current team, project-root area, and exact current sprint. The operation creates or reuses one durable `Issue` identified by the stable tag `tenant1-lean-platform-traceability`. It never creates or deletes a team, area, iteration, Epic, Task, or process.

Run the locked planning command first. Keep the plan outside Git:

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
Get-Content -LiteralPath $BoardsPlanPath -Raw | ConvertFrom-Json |
    Format-List ProcessName, TeamName, AreaPath, CurrentSprintPath, SprintDateMode, IssueMode, IssueId, Status
```

The expected plan reports `Basic`, the exact existing team, `Caldova HR Frontier` as the root area, the exact current sprint, and `Status = Planned`. `IssueMode` is `Create` only when an actual WIQL `workItems` array is present and empty; missing, null, or wrong-type `workItems` is indeterminate and stops. `Reuse` requires exactly one matching Issue, and more than one match is ambiguous and stops. The full observed sprint path is converted to the project-relative classification-node route (`Caldova HR Frontier\Current` becomes `Current`); foreign, relative-only, REST-prefixed, or ambiguous paths stop.

Current-sprint dates are deliberately omitted. Add both `SprintStartDate` and `SprintFinishDate` only when the attended owner supplies and approves both exact dates. Supplying one date, a reversed range, or an unverified read-back stops without further mutation.

After a separately recorded attended approval, use the same locked parameters:

```powershell
.\infra\src\scripts\Initialize-AzureBoardsLeanSprint.ps1 @BoardsParameters -Apply
```

Approve only the exact proposed mutation. Issue creation sends its four-field JSON Patch body with media type `application/json-patch+json`. After creation or a sprint-date update, the script reruns the stable-tag query and requires exactly one result with the expected Issue ID; a concurrent duplicate stops before success. The result must report `Status = Applied` and a positive `IssueId`. Preserve that durable Issue for the final `Fixes AB#<positive-integer>` transaction; never delete it.

## Optional 19-Epic Portfolio Tooling

The existing `infra/src/scripts/Initialize-AzureDevOpsWorkItems.ps1` can copy the reviewed `hr/docs/ideas/*.md` portfolio into one `Epic` per idea. It remains behaviorally unchanged and is not part of lean acceptance.

### Optional Prerequisites

- [ ] Use an authenticated attended Azure DevOps user with the separately approved project permissions.
- [ ] Install the `az` CLI and the `azure-devops` extension (`az extension add --name azure-devops` if `az boards -h` reports the command group is missing).
- [ ] `Invoke-Pester -Path infra/tests/pester/AzureBoardsPopulation.Tests.ps1 -Output Detailed -CI` passes on the current `main`.
- [ ] Obtain separate approval for the optional 19-Epic population. Lean Basic Boards approval does not authorize it.

### Optional Procedure

1. **Review the plan with zero mutation.**

   ```powershell
   $planPath = Join-Path $env:TEMP 'azure-boards-population-plan.json'
   .\infra\src\scripts\Initialize-AzureDevOpsWorkItems.ps1 -TenantAlias caldova25156897 -PlanOutputPath $planPath -WhatIf
   Get-Content -Raw $planPath | ConvertFrom-Json | Format-Table UseCaseId, Title, Status, JourneyStage, Mode, ExistingWorkItemId -AutoSize
   ```

   Confirm all 19 ideas appear, and that the `Mode` column matches what you expect (`Create` for every idea the first time this runs; `Existing` for any idea already tagged in Azure Boards on a later run).

2. **Execute the plan.**

   ```powershell
   .\infra\src\scripts\Initialize-AzureDevOpsWorkItems.ps1 -TenantAlias caldova25156897 -PlanOutputPath $planPath
   ```

   The procedure requires one-at-a-time confirmation and prohibits `A` ("Yes to All").

3. **Handle a partial failure.**

   If the script fails partway through (for example, item 12 of 19 fails a read-back check), re-run the exact command from Step 2. Every idea already created is now tagged and will be found by the WIQL query on the next run, so it reports as `Existing` and is skipped — only the remaining `Create`-mode ideas are attempted.

4. **Prove population with a final read-back.**

   ```powershell
   .\infra\src\scripts\Initialize-AzureDevOpsWorkItems.ps1 -TenantAlias caldova25156897 -PlanOutputPath $planPath -WhatIf
   Get-Content -Raw $planPath | ConvertFrom-Json | Where-Object Mode -ne 'Existing'
   ```

   Expect no output from the last line — every idea should now show `Mode = 'Existing'` with a populated `ExistingWorkItemId`.

## What This Runbook Does Not Do

| Not covered here | Where it lives instead |
|---|---|
| Creating Features, User Stories, Tasks, or Bugs under any Epic | Deliberately out of scope — see the spec's Ruling 1; only `UC-0001` has a PRD, and even its Definition of Ready is not yet met |
| Azure DevOps project configuration (area paths, iterations, delivery plans, Azure Repos repurposing) | Tracked as a separate, not-yet-started sub-project |
| The Azure Boards↔GitHub App connection and the `AB#` commit convention | Attended-only (one-time browser OAuth); see `docs/specs/2026-09-24-azure-devops-github-single-source-of-truth-design.md` |
| Tenant trust, OIDC, or a delivery identity | Not required by either Boards tool; neither tool creates or activates them |

## Troubleshooting

- **`Azure DevOps project '...' has no 'Epic' work item type.`** The project's process template does not name its top-level backlog item `Epic`. Confirm the actual process (`az devops invoke --area core --resource projects --route-parameters project=... --query-parameters includeCapabilities=true --api-version 7.1`) and treat this as a plan defect to escalate, not something to work around by picking a different type name yourself.
- **`Ambiguous existing work items tagged '...'.`** More than one existing work item carries the same `UC-nnnn` tag. Resolve manually in Azure Boards (retag or close the duplicate) before re-running — this script never guesses which one is authoritative.
- **A read-back mismatch error immediately after a successful-looking creation.** The created work item's `Title`/`Description`/`Tags`/`Hyperlink` do not exactly match what was requested — a stale cached response, a transient service issue, or a real Azure DevOps API bug in this batch. The Epic was already created and tagged before the read-back check ran, so simply re-running the command does **not** re-verify it: the next plan review finds the existing tagged item and marks it `Existing`, skipping it without ever re-checking whether its fields actually match. The operator must manually inspect that specific work item in Azure Boards and either correct its fields by hand or delete it and re-run so it is recreated fresh.
