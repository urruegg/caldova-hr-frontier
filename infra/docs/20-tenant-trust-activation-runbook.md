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
- **GitHub role:** repository administrator on `urruegg/caldova-hr-frontier`, authenticated via `gh auth login` (this runbook assumes `gh` is already authenticated — confirm with `gh auth status`). If `$env:GITHUB_TOKEN` or `$env:GH_TOKEN` is set in the shell, `gh`'s API calls use that token instead of the `gh`-authenticated identity, so `gh auth status` may not reflect the identity actually used — check for and clear either variable first if you need the two to match.
- **Azure DevOps role:** organization membership with **Project Collection Administrator** rights in the Azure DevOps organization. `Initialize-TenantTrust.ps1` calls Azure DevOps APIs (service-principal entitlement creation, Readers group membership) using the signed-in user's own Azure DevOps token, and these calls can fail with a 403 without this role even when every Entra/Azure/GitHub prerequisite is satisfied.
- **Identity match:** the Azure identity used for `az login` must have a `userPrincipalName` exactly matching the tenant's reviewed `AdminUpn` field (for Tenant 1: `admin@Caldova25156897.onmicrosoft.com`, from `infra/src/config/tenants/caldova25156897.psd1`). The tool rejects any other signed-in identity.

## Prerequisites Checklist

- [ ] `az` CLI is installed (`az version`). Azure Developer CLI is not required for this runbook.
- [ ] `gh` CLI is installed and authenticated (`gh auth status`) as a GitHub repository administrator. If `$env:GITHUB_TOKEN` or `$env:GH_TOKEN` is set, confirm which identity it belongs to — it takes precedence over the `gh`-authenticated identity shown by `gh auth status`.
- [ ] The signed-in Azure identity has organization membership with **Project Collection Administrator** rights in the Azure DevOps organization, in addition to the Entra and Azure roles above.
- [ ] The repository's GitHub OIDC customization for `urruegg/caldova-hr-frontier` is already configured with `use_default: true`, `use_immutable_subject: true`, and the exact `sub_claim_prefix` the tool computes for this tenant and repository (confirmed already correct live today). `Initialize-TenantTrust.ps1` reads this back and throws if it does not match — it does not configure it for you.
- [ ] The tenant's manifest at `infra/src/config/tenants/<tenantAlias>.psd1` is committed with `LifecycleState` set to exactly `'IntentReviewed'` (an exact, case-sensitive string match — `Import-TenantConfiguration.ps1` compares with `-cne 'IntentReviewed'` and throws on any other value, including any value that might otherwise be read as "later"), and every component this runbook touches (`EntraApplication`, `EntraServicePrincipal`, `EntraFederatedIdentityCredential`, `GitHubEnvironment`, `AzureDevOpsServicePrincipalEntitlement`, `AzureDevOpsReadersMembership`) has a reviewed `Mode` of `Existing` (with a stable `Id`) or `Create`.
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

   Read every plan item. Each one has `Mode` (`Existing` or `Create`) and `Status` (`Existing`, `PlannedCreate`, `PlannedUpdate`, or `AttendedCheckpoint`). Confirm the `Create` items are exactly the ones you expect — nothing has been mutated yet. On a fresh tenant's first plan review, the `EnsureGitHubEnvironmentVariable` item for `AZURE_CLIENT_ID` will show a `null` value — this is expected, because the Entra Application does not exist yet at this point, and is not an error.

   `$planPath` must stay defined in the same PowerShell session through Steps 2, 3, and 5. If you close and reopen the session, redefine it with the same value before continuing.

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

   Answer `Y` only, one prompt at a time. **Never answer `A` ("Yes to All").**

   You will see each of the 11 queued operations prompted **twice**: before the `-WhatIf` gate in the script, an unconditional pre-flight loop calls `$PSCmdlet.ShouldProcess(...)` once for every queued operation purely to surface the confirmation preview — that round is discarded and performs no mutation. The real mutation for each operation is gated by its own, separate `ShouldProcess` call later in the script. Seeing every operation's name prompted twice is expected script behavior, not a bug or a sign that something ran twice.

   If you answer `A` during **either** round — including the first, throwaway pre-flight round — PowerShell's confirmation machinery disables per-object confirmation for the remainder of that single script invocation, and every subsequent real mutation is silently approved without ever showing you a prompt. That defeats the entire point of this runbook's safety model: reviewing and approving each creation individually. Always answer `Y` and let each of the 22 prompts (11 operations × 2 rounds) appear. Do not use `-Confirm:$false` either — it silences these prompts the same way.

4. **Handle a partial failure.**

   If any step fails partway through (for example, the Application is created but a later Graph call fails), do not attempt manual cleanup. Re-run the exact command from Step 3. The tool re-reads current state first; objects already created will read back as `Existing` and only the remaining `Create` items will be attempted. `GrantAdminConsent` and all three `EnsureGitHubEnvironmentVariable`/`SetEnvironmentVariable` calls are the exception: those four run unconditionally on every invocation regardless of what already succeeded, so their confirmation prompts will reappear on a retry even though nothing about them was missing — this is expected, and re-running is still safe and idempotent. See [Bootstrap Recovery](./19-bootstrap-recovery.md) ("Trust creation", "OIDC mismatch") if the failure is not a simple retry.

5. **Prove activation with a final read-back.**

   ```powershell
   .\infra\src\scripts\Initialize-TenantTrust.ps1 -TenantAlias <tenantAlias> -PlanOutputPath $planPath -WhatIf
   Get-Content -Raw $planPath | ConvertFrom-Json | ConvertTo-Json -Depth 10
   ```

   Success does not mean "every item that was `PlannedCreate` now shows `Existing`" — three of the plan items never do, by design. Check each operation type against its own criterion:

   - `EnsureEntraApplication`, `EnsureEntraServicePrincipal`, `EnsureFederatedCredential`, `EnsureGitHubEnvironment`, `EnsureAzureDevOpsServicePrincipalEntitlement`, `EnsureAzureDevOpsReadersMembership`: each must show `Status = 'Existing'` with a populated `TargetId` (a real stable ID, not `null`). If any of these still shows `PlannedCreate` or `PlannedUpdate`, activation is incomplete — return to Step 3. For `EnsureAzureDevOpsReadersMembership` specifically, a populated `TargetId` is not, on its own, proof of membership: when the principal is not a member, `TargetId` falls back to the Readers group descriptor rather than being `null`. Treat only `Status = 'Existing'` as the real success signal for this item.
   - `GrantAdminConsent`: this always shows `Status = 'AttendedCheckpoint'`, on every run, whether or not consent was granted. It is an attended checkpoint operation, not a create/existing state — do not expect `Existing` here, and do not treat a repeated `AttendedCheckpoint` as a failure.
   - `EnsureGitHubEnvironmentVariable` (all three: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`): these always show `Status = 'PlannedCreate'`, unconditionally, on every run forever — the plan-building code emits them with `Mode = 'Create'` and `Status = 'PlannedCreate'` regardless of whether the variables already exist. This is by design, not a failure signal, and this read-back cannot prove or disprove that the variables were set. To verify them, check the values directly:

     ```powershell
     gh api repos/urruegg/caldova-hr-frontier/environments/<environmentName>/variables
     ```

     Confirm `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, and `AZURE_SUBSCRIPTION_ID` are present with the expected values (the Application's `appId`, the tenant's `TenantId`, and the tenant's `SubscriptionId`, respectively).

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
