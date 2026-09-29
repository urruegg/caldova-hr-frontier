# Customer Repository Export and Handover Runbook

| Field | Value |
|---|---|
| **Version** | 1.1 |
| **Date** | 2026-09-29 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Infrastructure (all tenants) |
| **References** | [ADR-0012](../../docs/adr/0012-per-tenant-github-repository-and-account-topology.md), [Customer Repository Export and Handover design](../../docs/specs/2026-09-27-customer-repository-export-and-handover-design.md), [Repository Clean-Up Runbook](./22-repository-cleanup-runbook.md) |

This runbook is the end-to-end procedure a new tenant owner follows to turn a copy of Tenant 1's repository into their own tenant-dedicated repository, per [ADR-0012](../../docs/adr/0012-per-tenant-github-repository-and-account-topology.md). Tenant 2's owner (Andrea Rizzi) runs this runbook first, as a genuine, unassisted execution -- not a second reading -- so any gap found is fixed here before Tenant 3 (Georg Fischer) receives it.

## Who Can Run This

- The new tenant's owner, with **repository creation permission** on the destination account (a personal GitHub account, or Owner/Admin on the destination GitHub Organization).
- **Azure DevOps role:** at least **Project Administrator** on the tenant's own Azure DevOps organization/project, to install the Azure Boards GitHub App connection in Step 5.
- No access to any *other* tenant's Azure, Azure DevOps, GitHub, or Entra resources is required or should be used at any point in this runbook.

## Prerequisites Checklist

- [ ] You know your tenant's alias (matching `infra/src/config/tenants/<alias>.psd1`'s own `TenantAlias` field in the source repository) and your tenant's Azure DevOps organization URL and project name.
- [ ] You have decided your account type per [ADR-0012](../../docs/adr/0012-per-tenant-github-repository-and-account-topology.md) -- personal account or GitHub Organization -- before Step 1, since this cannot be changed later without repeating this runbook.
- [ ] `git`, PowerShell 7 or Windows PowerShell 5.1, and the Azure CLI with the `azure-devops` extension are installed locally.

## Steps

1. **Create the destination repository using GitHub's "Use this template" (generate-from-template).**

   Use GitHub's "Use this template" button (requires the source repository to be marked as a template) to generate a brand-new repository, owned by your account, seeded with only the source repository's current file content as a single fresh initial commit -- with **no shared commit history** and no ongoing live link back to the source repository. Name it to match the source repository unless you have a specific reason not to.

   **Do not fork the source repository and detach it instead.** Forking preserves the source repository's *entire* commit history, including every prior tenant's tenant IDs, admin UPNs, and subscription IDs that ever appeared in any commit -- even after a later clean-up commit removes them from the current working tree, they remain fully recoverable from git history and `git blame`. For a real customer handover, this is a genuine data-exposure risk that "Use this template" avoids entirely by starting with no history at all. If "Use this template" is not available for some reason, treat fork-then-detach as a fallback that requires an explicit, documented decision to accept that history-based exposure -- not an equally-good alternative.

2. **Clone the new repository locally and confirm it is the destination, not the source.**

   ```powershell
   git clone https://github.com/<your-account>/<your-repository>.git
   cd <your-repository>
   git remote -v
   ```

   Confirm the `origin` remote points at your new repository, not the source repository you copied from. Every remaining step in this runbook assumes you are working inside this clone.

3. **Run the Repository Clean-Up Runbook.**

   Follow [Repository Clean-Up Runbook](./22-repository-cleanup-runbook.md) in full now, passing your own tenant alias as `-TenantAliasToKeep`. Do not proceed to Step 4 below until that runbook's own Step 4 (full test suite) passes and its clean-up commit (Step 5) is made.

4. **Correct your tenant's own manifest to match the new repository.**

   Open `infra/src/config/tenants/<your-alias>.psd1` and update at minimum:

   ```powershell
   $manifestPath = 'infra\src\config\tenants\<your-alias>.psd1'
   $content = Get-Content -Raw -LiteralPath $manifestPath
   $content = $content -replace "Owner = '[^']*'", "Owner = '<your-github-account-or-org>'"
   $content = $content -replace "Repository = '[^']*'", "Repository = '<your-repository-name>'"
   Set-Content -LiteralPath $manifestPath -Value $content -NoNewline
   ```

   `RepositoryId` and `OwnerId` cannot be corrected this way -- both are the *new* owner's and repository's own immutable numeric IDs, obtained live:

   ```powershell
   gh api repos/<your-account>/<your-repository> --jq '.id'
   # For a personal account owner:
   gh api users/<your-account> --jq '.id'
   # For a GitHub Organization owner:
   gh api orgs/<your-organization> --jq '.id'
   ```

   Paste those values into the manifest's `GitHub.RepositoryId` and `GitHub.OwnerId` fields by hand. Correct all four GitHub fields (`Owner`, `OwnerId`, `Repository`, `RepositoryId`) together, then re-run the Tenant 1 Blueprint Verification suite's pattern against your own manifest and evidence once your own discovery evidence exists (produced by attended tenant discovery per [`infra/docs/17-bootstrap-and-provisioning.md`](./17-bootstrap-and-provisioning.md) -- not a step in this runbook). Trust activation is superseded and is not a handover prerequisite; any future delivery identity requires a new reviewed design.

   Commit this correction as its own commit, separate from the clean-up commit:

   ```powershell
   git add infra/src/config/tenants/<your-alias>.psd1
   git commit -m "chore: correct tenant manifest for new repository"
   ```

5. **Install the Azure Boards GitHub App, connected to your own Azure DevOps organization.**

   From [`https://github.com/marketplace/azure-boards`](https://github.com/marketplace/azure-boards), install and authorize the app against your new repository, then complete the Azure DevOps side by selecting **your own** organization and project -- never a different tenant's. GitHub Marketplace install, organization access grant, and third-party OAuth app policy are each a single confirmation step in that flow; the values you select are tenant-specific, the procedure is not.

6. **Verify the connection live.**

   ```powershell
   az login --tenant <your-tenant-id> --allow-no-subscriptions --use-device-code
   az rest --method get --uri "https://dev.azure.com/<your-org>/<your-project-id>/_apis/githubconnections?api-version=7.1-preview.1" --resource "499b84ac-1321-427f-aa17-267ca6975798"
   ```

   Expect `"count": 1` and `"isConnectionValid": true`, with a `gitHubRepositoryUrl` matching your new repository -- the same live check this platform used to confirm Tenant 1's connection. Log out afterward:

   ```powershell
   az logout
   ```

7. **Run the full test suite one final time in the new repository, and record the result.**

   ```powershell
   Invoke-Pester -Path .github/cli/tests,infra/tests/pester -Output Detailed -CI
   ```

   Record the pass/fail count, the date, and your tenant alias in your own copy of this runbook's execution -- for example as a dated entry appended to this file in your repository, or as a short note in your own repository's first pull request. This is the record Tenant 3's onboarding points to as evidence the runbook works, not merely that it exists.

## What This Runbook Does Not Do

| Not covered here | Where it lives instead |
|---|---|
| Removing other tenants' configuration and evidence | [Repository Clean-Up Runbook](./22-repository-cleanup-runbook.md) -- referenced as Step 3 above, not duplicated |
| Activating your tenant's trust (Entra Application, Service Principal, Federated Identity Credential) | [Tenant Trust Activation Runbook](./20-tenant-trust-activation-runbook.md) |
| Populating your tenant's Azure Boards with HR use-case Epics | [Azure Boards Population Runbook](./21-azure-boards-population-runbook.md) |
| Choosing your account type (personal vs. GitHub Organization) | [ADR-0012](../../docs/adr/0012-per-tenant-github-repository-and-account-topology.md) -- must already be decided before Step 1 |

## Troubleshooting

- **Step 3's clean-up runbook lists a file for a tenant you don't recognize.** The source repository may have onboarded a tenant after this runbook was written. Do not remove it blindly -- confirm with the source repository's own `infra/docs/18-multi-tenant-provisioning.md` Tenant Status table before proceeding.
- **Step 6's live check shows `"count": 0` after apparently completing Step 5.** The GitHub App installation and the Azure DevOps side's project/organization selection are two separate actions -- confirm both were completed, not just the GitHub-side install. Re-open the Azure Boards GitHub App's settings from your repository (GitHub Settings > Integrations > Applications, or the app's own configuration page) and confirm the connection lists your Azure DevOps organization and project; if it does not, repeat Step 5's authorization flow rather than re-running the live check, which only observes the connection and cannot create it.
- **You are not sure whether you're looking at your own tenant's Azure DevOps organization or another tenant's.** Run `az account show` before any tenant-scoped command and confirm the authenticated tenant ID matches your own manifest's `TenantId` field exactly -- never proceed on an assumption here.
