# Tenant Trust Activation Runbook

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-24 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Infrastructure (reusable for every onboarded tenant) |
| **References** | [Tenant Trust Activation Design](../../docs/specs/2026-09-24-tenant-trust-activation-design.md), [Bootstrap and Provisioning](./17-bootstrap-and-provisioning.md), [Multi-Tenant Provisioning](./18-multi-tenant-provisioning.md), [Bootstrap Recovery](./19-bootstrap-recovery.md) |

This runbook activates one tenant's trust — the Entra Application, Service Principal, Federated Identity Credential, GitHub Environment and its three variables, and the Azure DevOps service-principal entitlement and Readers membership — using the existing `infra/src/scripts/Initialize-TenantTrust.ps1`. No new tooling is introduced here; this document only sequences an existing, already-tested script for a human operator. It is written for `<tenantAlias>` so the same steps apply to Tenant 2 and Tenant 3 when they are onboarded.

## Who Can Run This

- **Entra role:** Application Administrator or Cloud Application Administrator, for the exact tenant being activated.
- **Azure role:** at least Reader on the exact subscription named in the tenant's manifest (`SubscriptionId`), so the interactive context check can confirm tenant and subscription identity. Granting the two temporary elevated roles (Contributor, Role Based Access Control Administrator) is a separate, later step — not part of this runbook.
- **GitHub role:** repository administrator on `urruegg/caldova-hr-frontier`, authenticated via `gh auth login` (this runbook assumes `gh` is already authenticated — confirm with `gh auth status`).
- **Identity match:** the Azure identity used for `az login` must have a `userPrincipalName` exactly matching the tenant's reviewed `AdminUpn` field (for Tenant 1: `admin@Caldova25156897.onmicrosoft.com`, from `infra/src/config/tenants/caldova25156897.psd1`). The tool rejects any other signed-in identity.

## Prerequisites Checklist

- [ ] `az` CLI is installed (`az version`). Azure Developer CLI is not required for this runbook.
- [ ] `gh` CLI is installed and authenticated (`gh auth status`) as a GitHub repository administrator.
- [ ] The tenant's manifest at `infra/src/config/tenants/<tenantAlias>.psd1` is committed with `LifecycleState = 'IntentReviewed'` or later, and every component this runbook touches (`EntraApplication`, `EntraServicePrincipal`, `EntraFederatedIdentityCredential`, `GitHubEnvironment`, `AzureDevOpsServicePrincipalEntitlement`, `AzureDevOpsReadersMembership`) has a reviewed `Mode` of `Existing` (with a stable `Id`) or `Create`.
- [ ] `Invoke-Pester -Path infra/tests/pester/TenantTrust.Tests.ps1 -Output Detailed -CI` passes on the current `main` before you begin.

## Steps

1. **Sign in to Azure as the reviewed administrator.**

   ```powershell
   az login
   az account show --query "{tenantId:tenantId, subscriptionId:id, user:user.name, userType:user.type}" --output table
   ```

   Confirm `tenantId` and `subscriptionId` match the tenant's manifest, `user` matches the reviewed `AdminUpn`, and `userType` is `user` (never `servicePrincipal`). If the wrong subscription is selected, run `az account set --subscription <SubscriptionId>` before continuing.

2. **Review the plan with zero mutation.**

   ```powershell
   $planPath = Join-Path $env:TEMP "tenant-trust-plan-<tenantAlias>.json"
   .\infra\src\scripts\Initialize-TenantTrust.ps1 -TenantAlias <tenantAlias> -PlanOutputPath $planPath -WhatIf
   Get-Content -Raw $planPath | ConvertFrom-Json | ConvertTo-Json -Depth 10
   ```

   Read every plan item. Each one has `Mode` (`Existing` or `Create`) and `Status` (`Existing`, `PlannedCreate`, `PlannedUpdate`, or `AttendedCheckpoint`). Confirm the `Create` items are exactly the ones you expect — nothing has been mutated yet.

3. **Execute the plan.**

   Run the identical command without `-WhatIf`:

   ```powershell
   .\infra\src\scripts\Initialize-TenantTrust.ps1 -TenantAlias <tenantAlias> -PlanOutputPath $planPath
   ```

   PowerShell's default confirmation preference (`High`, matching the script's declared `ConfirmImpact = 'High'`) prompts before every mutating action — for example:

   ```text
   Confirm
   Are you sure you want to perform this action?
   Performing the operation "EnsureEntraApplication" on target "<NamingRoot>-github-bootstrap".
   [Y] Yes  [A] Yes to All  [N] No  [L] No to All  [S] Suspend  [?] Help (default is "Y"):
   ```

   Answer `Y` (or `A` to confirm all remaining prompts in this run) for each step you intend to approve. Do not use `-Confirm:$false` — it silences these prompts, and this runbook's entire safety model depends on seeing and approving each one individually.

4. **Handle a partial failure.**

   If any step fails partway through (for example, the Application is created but a later Graph call fails), do not attempt manual cleanup. Re-run the exact command from Step 3. The tool re-reads current state first; objects already created will read back as `Existing` and only the remaining `Create` items will be attempted. See [Bootstrap Recovery](./19-bootstrap-recovery.md) ("Trust creation", "OIDC mismatch") if the failure is not a simple retry.

5. **Prove activation with a final read-back.**

   ```powershell
   .\infra\src\scripts\Initialize-TenantTrust.ps1 -TenantAlias <tenantAlias> -PlanOutputPath $planPath -WhatIf
   Get-Content -Raw $planPath | ConvertFrom-Json | ConvertTo-Json -Depth 10
   ```

   Every item that was `PlannedCreate` in Step 2 must now show `Status = 'Existing'` with a populated `TargetId` (a real stable ID, not `null`). If any item still shows `PlannedCreate` or `PlannedUpdate`, activation is incomplete — return to Step 3.

## What This Runbook Does Not Do

| Not covered here | Where it lives instead |
|---|---|
| Granting the two temporary Azure RBAC roles (Contributor, Role Based Access Control Administrator) | [Bootstrap and Provisioning](./17-bootstrap-and-provisioning.md) §"Temporary Privilege Lifecycle" — a separate, later attended step |
| Running the Bicep `what-if` bootstrap validation | `.github/workflows/bootstrap-tenant.yml` — requires the GitHub Environment this runbook creates, and requires the temporary roles above to already be granted |
| Activating the final GitHub branch ruleset | `infra/src/scripts/Enable-GitHubGovernance.ps1` — requires a completed, evidenced `bootstrap-tenant.yml` run |
| Azure DevOps project configuration (Boards process, area paths, Azure Repos repurposing) | Tracked as a separate sub-project |
| Populating Azure Boards with the current use-case ideas | Tracked as a separate sub-project |
| The Azure Boards↔GitHub App connection | Attended-only; cannot be automated by any tooling (Microsoft's integration model requires a one-time browser OAuth authorization) |

## Troubleshooting

If `az login` succeeds but `Initialize-TenantTrust.ps1` still fails, consult [Bootstrap Recovery](./19-bootstrap-recovery.md):

- **"Interactive Azure administrator context is required"** or a `userType`/`userPrincipalName` mismatch → see "Trust creation".
- Any federated-credential, issuer, audience, or subject mismatch → see "OIDC mismatch".
- An ambiguous application, service principal, or environment match (more than one candidate) → see "Ambiguous object". Stop; do not choose one arbitrarily.
