# Azure Boards Population Runbook

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-25 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Infrastructure (Tenant 1) |
| **References** | [Azure Boards Population Design](../../docs/specs/2026-09-25-azure-boards-population-design.md), [Tenant Trust Activation Runbook](./20-tenant-trust-activation-runbook.md) |

This runbook populates Azure DevOps Boards with one `Epic` per HR use-case idea (19 total), using `infra/src/scripts/Initialize-AzureDevOpsWorkItems.ps1`. It assumes Tenant 1's trust is already active — see the [Tenant Trust Activation Runbook](./20-tenant-trust-activation-runbook.md) — and that you have an authenticated Azure DevOps session (either the same OIDC trust that runbook establishes, or your own `az devops login`).

## Who Can Run This

- **Azure DevOps role:** at least **Contributor** on the `Caldova HR Frontier` project — enough to create work items and add relations; no administrative role is required.
- **Content judgment:** this script only ever copies text already reviewed and committed in `hr/docs/ideas/*.md` into Azure Boards — it never generates new characterizations of a use case. Even so, a human should trigger the first live write of this portfolio into a system other people at GF will read as authoritative — see the spec's Runbook section for why.

## Prerequisites Checklist

- [ ] `az` CLI is installed with the `azure-devops` extension (`az extension add --name azure-devops` if `az boards -h` reports the command group is missing).
- [ ] You are authenticated to Azure DevOps for organization `https://dev.azure.com/caldova25156897/` (`az devops login` or an already-active OIDC session).
- [ ] `Invoke-Pester -Path infra/tests/pester/AzureBoardsPopulation.Tests.ps1 -Output Detailed -CI` passes on the current `main` before you begin.

## Steps

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

   PowerShell's default confirmation preference (`High`, matching the script's declared `ConfirmImpact = 'High'`) prompts once per `Create`-mode Epic before creating it. Answer `Y` for each one you approve; never answer `A` ("Yes to All") — the same reasoning as the [Tenant Trust Activation Runbook](./20-tenant-trust-activation-runbook.md) Step 3 applies here too: a single blanket approval silently skips reviewing the remaining items.

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
| Activating Tenant 1's trust in the first place | [Tenant Trust Activation Runbook](./20-tenant-trust-activation-runbook.md) — must already be complete before this runbook can authenticate |

## Troubleshooting

- **`Azure DevOps project '...' has no 'Epic' work item type.`** The project's process template does not name its top-level backlog item `Epic`. Confirm the actual process (`az devops invoke --area core --resource projects --route-parameters project=... --query-parameters includeCapabilities=true --api-version 7.1`) and treat this as a plan defect to escalate, not something to work around by picking a different type name yourself.
- **`Ambiguous existing work items tagged '...'.`** More than one existing work item carries the same `UC-nnnn` tag. Resolve manually in Azure Boards (retag or close the duplicate) before re-running — this script never guesses which one is authoritative.
- **A read-back mismatch error immediately after a successful-looking creation.** The created work item's `Title`/`Description`/`Tags`/`Hyperlink` do not exactly match what was requested — a stale cached response, a transient service issue, or a real Azure DevOps API bug in this batch. The Epic was already created and tagged before the read-back check ran, so simply re-running the command does **not** re-verify it: the next plan review finds the existing tagged item and marks it `Existing`, skipping it without ever re-checking whether its fields actually match. The operator must manually inspect that specific work item in Azure Boards and either correct its fields by hand or delete it and re-run so it is recreated fresh.
