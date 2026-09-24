# Tenant Trust Activation Runbook Implementation Plan

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-24 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Draft |
| **Scope** | Infrastructure (Tenant 1, reusable for Tenant 2/3) |
| **References** | [Tenant Trust Activation Design](../specs/2026-09-24-tenant-trust-activation-design.md) |

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Write the operator runbook that activates Tenant 1's trust (Entra Application, Service Principal, Federated Identity Credential, GitHub Environment + 3 variables, Azure DevOps entitlement, Azure DevOps Readers membership) using the existing, already-tested `Initialize-TenantTrust.ps1` — no new PowerShell code — and confirm the tool is ready to run against live Tenant 1 state today.

**Architecture:** `Initialize-TenantTrust.ps1` already contains the full mutation logic behind `$PSCmdlet.ShouldProcess(...)` gates; passing `-WhatIf` stops before any mutation (`if ($WhatIfPreference) { return $result }`), omitting it lets the human confirm each creation individually. This plan adds a documentation-only deliverable (`infra/docs/20-tenant-trust-activation-runbook.md`) plus a readiness check — it creates or modifies no PowerShell source.

**Tech Stack:** PowerShell 5.1 (Windows PowerShell, matching CI — `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`), Pester 5.7.1, Azure CLI 2.90+, GitHub CLI.

**Spec:** [`docs/specs/2026-09-24-tenant-trust-activation-design.md`](../specs/2026-09-24-tenant-trust-activation-design.md)

## Global Constraints

- **No PowerShell file is created or modified.** `infra/src/scripts/Initialize-TenantTrust.ps1` and `infra/tests/pester/TenantTrust.Tests.ps1` are used exactly as they exist today — this plan is documentation-only.
- **`-PlanOutputPath` must resolve under the OS temp directory or `$env:RUNNER_TEMP`** (`Resolve-AllowedPlanOutputPath` in `Initialize-TenantTrust.ps1` throws otherwise) — never point it at a path inside the repository.
- **The reviewed `AdminUpn` for Tenant 1 is `admin@Caldova25156897.onmicrosoft.com`** (`infra/src/config/tenants/caldova25156897.psd1`). The tool asserts the authenticated Azure principal's `UserPrincipalName` matches this exactly — `az login` must be done as this identity, not merely as "some Application Administrator."
- **The GitHub reviewer is always `urruegg`**, regardless of tenant alias — `Initialize-TenantTrust.ps1` resolves this login directly; it is not read from the tenant manifest.
- **Every markdown file created or rewritten carries the repository's required six-field documentation metadata table** (`Version`/`Date`/`Author`/`Status`/`Scope`/`References`) immediately after its H1 — enforced by `.github/cli/modules/DocumentationMetadata.psm1`.
- **No Azure RBAC role assignment, `bootstrap-tenant.yml` run, or `Enable-GitHubGovernance.ps1` run is performed by this plan** — those are separate, later, already-built steps explicitly out of scope here.

---

### Task 1: Confirm readiness and write the tenant trust activation runbook

**Files:**
- Create: `infra/docs/20-tenant-trust-activation-runbook.md`

**Interfaces:**
- Consumes: `infra/src/scripts/Initialize-TenantTrust.ps1` (existing, unmodified) — parameters `-TenantAlias <string>` (mandatory), `-PlanOutputPath <string>` (optional, must resolve under temp), `-WhatIf` (standard PowerShell common parameter via `SupportsShouldProcess`). `infra/tests/pester/TenantTrust.Tests.ps1` (existing, unmodified).
- Produces: nothing consumed by later tasks — this is the only task in the plan.

- [ ] **Step 1: Confirm the existing test suite is green**

Run: `Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path infra/tests/pester/TenantTrust.Tests.ps1 -Output Detailed -CI`
Expected: PASS — 23/23 tests green, including `'fails closed on ambiguous application lookup in Create mode'` and `'never contains app credential creation commands or forbidden secret flags'`. This is a pre-existing, unmodified test file — if it is not green, STOP and report BLOCKED rather than writing the runbook, since the runbook would then be documenting an unreliable tool.

- [ ] **Step 2: Confirm the tool's real (non-test-double) wiring fails cleanly when not logged in**

Run (from the repository root, in Windows PowerShell):
```powershell
.\infra\src\scripts\Initialize-TenantTrust.ps1 -TenantAlias caldova25156897 -WhatIf
```
Expected: the command fails with an error whose message includes `Please run 'az login' to setup account` (assuming `az` is installed but not currently logged in in this environment — if it fails with a *different* error, or if `az` is not found at all, STOP and report the exact message; do not proceed to Step 3 until this exact, expected failure is reproduced). This proves the script's real Azure CLI adapter path is reachable and fails safely (zero mutation either way, since nothing beyond the login check runs) rather than silently doing nothing or throwing something unrelated.

- [ ] **Step 3: Write the runbook**

Create `infra/docs/20-tenant-trust-activation-runbook.md` with exactly this content:

```markdown
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
```

- [ ] **Step 4: Verify the documentation metadata check passes**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .github/cli/verify-repository-setup.ps1 -SkipIntegratedTests -SkipBicepBuild`
Expected: PASS — the new file's six-field metadata table is recognized and validated.

- [ ] **Step 5: Commit**

```bash
git add infra/docs/20-tenant-trust-activation-runbook.md
git commit -m "docs(infra): add tenant trust activation runbook"
```

---

## Out of Scope (Tracked as Later Sub-Projects)

These are not tasks in this plan — each needs its own brainstorm → spec → plan cycle when picked up:

- Azure DevOps project configuration for Tenant 1 (Boards process, area paths/iterations, repurposing the Azure Repos config repo per the merged single-source-of-truth spec).
- Populating Azure Boards with the current use-case ideas, linked.
- The Azure Boards↔GitHub App connection (attended-only) and final GitHub governance activation (`Enable-GitHubGovernance.ps1` — already built, not yet run).
- The Power Platform ALM pipeline foundation to build and deploy the code app and agent solution to DEV.
- Actually running this runbook against live Tenant 1 (granting the human's own `az login`, approving each `ShouldProcess` prompt) — that is the human's own attended action after this plan's documentation lands, not a task any agent performs.
