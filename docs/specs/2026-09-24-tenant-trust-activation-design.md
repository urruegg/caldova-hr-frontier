# Tenant Trust Activation: Creating the Entra Application, Service Principal, Federated Credential, and GitHub Environment

| Field | Value |
|---|---|
| **Version** | 2.0 |
| **Date** | 2026-09-24 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Infrastructure (Tenant 1, reusable for Tenant 2/3) |
| **References** | [Bootstrap and Provisioning](../../infra/docs/17-bootstrap-and-provisioning.md), [Multi-Tenant Provisioning](../../infra/docs/18-multi-tenant-provisioning.md), [Bootstrap Recovery](../../infra/docs/19-bootstrap-recovery.md), [ADR-0001](../adr/0001-azure-devops-as-engineering-control-plane.md), [ADR-0002](../adr/0002-github-first-bootstrap-and-the-role-of-azure-repos.md) |

## Status

Proposed Baseline. This document is the first of several planned sub-projects toward standing up Tenant 1's Azure DevOps and GitHub foundation for building and deploying HR solutions to DEV. It scopes only the trust-activation gap identified below. Azure DevOps project configuration, Azure Boards backlog population, the Azure Boards↔GitHub connection, final GitHub governance activation, and the Power Platform DEV deployment pipeline are explicitly tracked as separate, later sub-projects — not designed here.

**Revision note (v2.0):** Version 1.0 of this document claimed no script in this repository creates the Entra Application, Service Principal, Federated Identity Credential, or GitHub Environment, and proposed building a new `New-TenantTrust.ps1` plus four new module functions to do so. That claim was wrong — the author read one test title ("builds the full attended trust plan under WhatIf with zero mutation adapter calls") and incorrectly inferred it described the script's only behavior, without reading the script's actual control flow. `Initialize-TenantTrust.ps1` already creates every one of these objects when run without `-WhatIf` (see Context below). Version 2.0 corrects this: no new script or module function is proposed. The only new deliverable is the operator runbook, plus a zero-mutation readiness check confirming the existing tool runs cleanly against live Tenant 1 state today.

## Objective

Produce the operator runbook for activating Tenant 1's trust — the Entra Application, Service Principal, Federated Identity Credential, and GitHub Environment `bootstrap-caldova25156897` (with its 3 variables), plus the Azure DevOps service-principal entitlement and Readers membership — using the existing `Initialize-TenantTrust.ps1`, which already creates all of these. This unblocks every downstream piece of already-built automation (discovery, the bootstrap `what-if`, GitHub governance activation), and the runbook itself is written to be reusable for Tenant 2 and Tenant 3 later.

## Context: What `Initialize-TenantTrust.ps1` Actually Does

Live evidence gathered directly in this session, and a full read of `infra/src/scripts/Initialize-TenantTrust.ps1`'s control flow:

- `az` CLI 2.90.0 and Azure Developer CLI are installed locally, but not logged in (`az account show` → "Please run 'az login'"). `gh` CLI is already authenticated as `urruegg` with `repo` scope.
- GitHub side: 0 Environments and 0 rulesets exist on `urruegg/caldova-hr-frontier` today.
- `infra/src/config/tenants/caldova25156897.psd1` still marks `EntraApplication`, `EntraServicePrincipal`, `EntraFederatedIdentityCredential`, and `GitHubEnvironment` as `Mode = Create` — none exist yet.
- `.github/workflows/discover-tenant.yml` and `bootstrap-tenant.yml` both declare `environment: bootstrap-${{ inputs.tenantAlias }}` — neither can start without that Environment already existing.
- **`Initialize-TenantTrust.ps1` is not read-only.** It always builds and writes the reviewed plan first (`Write-BomlessJsonAtomically` to `-PlanOutputPath`, when supplied), then contains this exact gate: `if ($WhatIfPreference) { return $result }`. Passed `-WhatIf`, it stops there — zero mutation, which is what its own test ("builds the full attended trust plan under WhatIf with zero mutation adapter calls") actually proves, and only that. **Run without `-WhatIf`, it continues past that gate** and, for every component whose reviewed `Mode` is `Create`, performs the real creation: `CreateApplication`, `CreateServicePrincipal`, `AddApplicationPermission`, `GrantAdminConsent`, `CreateFederatedCredential`, `PutEnvironment`, `SetEnvironmentVariable` (all three variables), `CreateServicePrincipalEntitlement` (Azure DevOps), and the Azure DevOps Readers group membership — each individually gated by its own `$PSCmdlet.ShouldProcess(...)` call, and each followed by an immediate read-back through the same `Assert-*State` functions used for verification.
- It never creates a password or certificate credential — the federated identity credential is the only trust mechanism (proven by its own "never contains app credential creation commands or forbidden secret flags" test) — and it never touches Azure RBAC role assignments or Power Platform environments; `New-PowerPlatformPrerequisites` only documents what a Power Platform administrator still needs to do separately.
- It requires an **interactive Azure user context**: it calls `az account get-access-token` and asserts the authenticated principal's `UserType` is `user` (never a service principal) and its `UserPrincipalName` matches the reviewed `AdminUpn`. This is why it can only ever be run by a human with their own `az login` — it is designed for exactly that, not for a GitHub Actions workflow.
- `-PlanOutputPath` must resolve under the OS temp directory or `$env:RUNNER_TEMP` (`Resolve-AllowedPlanOutputPath` throws otherwise) — the plan file is deliberately kept out of the repository.
- `Enable-GitHubGovernance.ps1` (the final governance-activation step, separate and later) requires this Environment to already exist (`Assert-EnvironmentReadBack`) and a completed, evidenced `bootstrap-tenant.yml` run — it activates the branch ruleset only, nothing this document covers.
- Creating the very first OIDC trust for a tenant is an inherent chicken-and-egg: a GitHub Actions workflow has nothing to authenticate with until the trust exists, so this one-time run is always a human, interactively, with Entra Application Administrator rights — universal to OIDC bootstrapping, not a gap in this repository's design.

## Architecture

No new script or module function. The existing `Initialize-TenantTrust.ps1` is run twice by the operator:

```text
az login                                    (human, interactive, Application Administrator)
    |
    v
Initialize-TenantTrust.ps1 -WhatIf          (review the plan; zero mutation; safe to re-run any time)
    |  human reviews the written plan JSON
    v
Initialize-TenantTrust.ps1                  (same tool, no -WhatIf; creates every reviewed Create item;
                                              each object individually confirmed via ShouldProcess)
    |
    v
Initialize-TenantTrust.ps1 -WhatIf          (re-run for read-back proof: every prior Create item
                                              must now show Existing with a stable ID)
```

Running with `-WhatIf` first is a safety practice this design recommends, not something the tool requires — `-WhatIf` and the no-`-WhatIf` run both write the same plan file shape, so the first run gives the operator a clean, risk-free preview before anything is created.

## Components

| File | Responsibility |
|---|---|
| `infra/docs/20-tenant-trust-activation-runbook.md` (new) | Tenant-agnostic (`<tenantAlias>`-parameterized), step-by-step operator runbook — see below. The only new file this document proposes. |

No PowerShell code is created or modified. `Initialize-TenantTrust.ps1` and its Pester coverage (`infra/tests/pester/TenantTrust.Tests.ps1`) are used exactly as they exist today.

## Data Flow, Gating, and Error Handling

1. The human runs `az login` interactively, with Entra Application Administrator rights — outside any script, never performed by an agent.
2. The human (or an agent in the same session, only with the human's explicit go-ahead at this specific step) runs `Initialize-TenantTrust.ps1 -TenantAlias caldova25156897 -PlanOutputPath <temp-path>\tenant-trust-plan.json -WhatIf` and reviews the written plan.
3. The same command is run again **without** `-WhatIf`. PowerShell's default `$ConfirmPreference` (`High`, matching the script's declared `ConfirmImpact = 'High'`) means every mutating step prompts for confirmation automatically — nothing is created silently, with no extra flag required.
4. A partial failure (for example, the Application is created but a later step fails) is diagnosable and safely re-runnable: re-running the same command shows already-created objects as `Existing` and only attempts the remaining `Create` items — this is the script's own existing behavior, not new logic.
5. Final step: re-run with `-WhatIf` one more time; every item that was `Create` must now read back `Existing` with a stable ID matching what was just created.
6. Explicitly **not** covered by this sub-project: granting the two temporary Azure RBAC roles (Contributor, Role Based Access Control Administrator), running `bootstrap-tenant.yml`, or running `Enable-GitHubGovernance.ps1`. Those are already-built, later steps in the existing evidence-gated state machine and remain their own separate, attended actions.

## Testing

No new test file. `infra/tests/pester/TenantTrust.Tests.ps1` already covers the Create path with injected adapters (for example: "fails closed on ambiguous application lookup in Create mode"), so this sub-project's only verification obligation is a readiness check: run `Invoke-Pester -Path infra/tests/pester/TenantTrust.Tests.ps1 -Output Detailed` and confirm it is green today, then perform one real, zero-mutation `-WhatIf` run against live Tenant 1 state (after `az login`) to prove the tool actually executes end-to-end in this environment — not just under test doubles.

## Runbook (Reusable Across Tenants)

`infra/docs/20-tenant-trust-activation-runbook.md` is written parameterized by `<tenantAlias>` so the same steps activate trust for Tenant 2 and Tenant 3 later, per the sequence already documented in [Multi-Tenant Provisioning](../../infra/docs/18-multi-tenant-provisioning.md). It covers:

- **Prerequisites:** Entra Application Administrator (or Cloud Application Administrator) role for the operator; `az` CLI installed and not yet logged in; `gh` CLI already authenticated with repository administrator permission; the tenant's manifest committed with `LifecycleState = IntentReviewed` or later.
- **Step-by-step:** `az login` (interactive); run `Initialize-TenantTrust.ps1 -WhatIf` and review the plan by hand; run the same command again without `-WhatIf` and respond to each `ShouldProcess` confirmation; re-run with `-WhatIf` and confirm every prior `Create` item now shows `Existing` with a stable ID.
- **Explicit boundaries:** what this runbook does not do (temporary Azure role grants, `bootstrap-tenant.yml`, `Enable-GitHubGovernance.ps1`), each with a pointer to the existing document that owns it.
- **Troubleshooting:** maps directly to the relevant sections of [Bootstrap Recovery](../../infra/docs/19-bootstrap-recovery.md) ("Trust creation", "OIDC mismatch") rather than duplicating their content.

## Open Items (Tracked as Later Sub-Projects)

- Azure DevOps project configuration for Tenant 1 (Boards process, area paths/iterations, repurposing the Azure Repos config repo per the merged single-source-of-truth spec).
- Populating Azure Boards with the ~19 current use-case ideas, linked.
- The Azure Boards↔GitHub App connection (attended-only; cannot be automated by any tooling per ADR-0001 and Microsoft's own integration model) and final GitHub governance activation (`Enable-GitHubGovernance.ps1` — already built, not yet run).
- The Power Platform ALM pipeline foundation to build and deploy the code app and agent solution to DEV.
- Granting the two temporary Azure RBAC roles and running `bootstrap-tenant.yml` — the next attended step immediately after this sub-project's runbook completes.
