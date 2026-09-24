# Tenant Trust Activation: Creating the Entra Application, Service Principal, Federated Credential, and GitHub Environment

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-24 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Infrastructure (Tenant 1, reusable for Tenant 2/3) |
| **References** | [Bootstrap and Provisioning](../../infra/docs/17-bootstrap-and-provisioning.md), [Multi-Tenant Provisioning](../../infra/docs/18-multi-tenant-provisioning.md), [Bootstrap Recovery](../../infra/docs/19-bootstrap-recovery.md), [ADR-0001](../adr/0001-azure-devops-as-engineering-control-plane.md), [ADR-0002](../adr/0002-github-first-bootstrap-and-the-role-of-azure-repos.md) |

## Status

Proposed Baseline. This document is the first of several planned sub-projects toward standing up Tenant 1's Azure DevOps and GitHub foundation for building and deploying HR solutions to DEV. It scopes only the trust-creation gap identified below. Azure DevOps project configuration, Azure Boards backlog population, the Azure Boards↔GitHub connection, final GitHub governance activation, and the Power Platform DEV deployment pipeline are explicitly tracked as separate, later sub-projects — not designed here.

## Objective

Close the one gap blocking every piece of already-built Tenant 1 automation (discovery, the bootstrap `what-if`, GitHub governance activation): no script in this repository creates the Entra Application, Service Principal, Federated Identity Credential, or the GitHub Environment `bootstrap-${tenantAlias}`. `Initialize-TenantTrust.ps1` only plans this — proven zero-mutation by its own test suite. Build the missing, reusable creation capability, and produce a runbook so this same tooling activates trust for Tenant 2 and Tenant 3 later.

## Context: Why This Is the Right Next Step

Live evidence gathered directly in this session:

- `az` CLI 2.90.0 and Azure Developer CLI are installed locally, but not logged in (`az account show` → "Please run 'az login'"). `gh` CLI is already authenticated as `urruegg` with `repo` scope.
- GitHub side: 0 Environments and 0 rulesets exist on `urruegg/caldova-hr-frontier` today.
- `infra/src/config/tenants/caldova25156897.psd1` still marks `EntraApplication`, `EntraServicePrincipal`, `EntraFederatedIdentityCredential`, and `GitHubEnvironment` as `Mode = Create` — none exist yet.
- `.github/workflows/discover-tenant.yml` and `bootstrap-tenant.yml` both declare `environment: bootstrap-${{ inputs.tenantAlias }}` — neither can even start without that Environment already existing.
- `Initialize-TenantTrust.ps1`'s own Pester coverage proves it performs zero mutation ("builds the full attended trust plan under WhatIf with zero mutation adapter calls") and "never contains app credential creation commands or forbidden secret flags." Its `Assert-*State` functions only read and compare — they never create.
- `Enable-GitHubGovernance.ps1` (the final governance-activation step) requires the Environment to already exist (`Assert-EnvironmentReadBack`) and requires a completed, evidenced `bootstrap-tenant.yml` run — it activates the branch ruleset only, nothing upstream of it.
- Creating the very first OIDC trust for a tenant is an inherent chicken-and-egg: a GitHub Actions workflow has nothing to authenticate with until the trust exists, so this one-time step can only ever be run by a human, with their own interactive Azure login carrying Entra Application Administrator rights. This is universal to OIDC bootstrapping, not a gap specific to this repository.

## Architecture

```text
Initialize-TenantTrust.ps1 (existing, zero-mutation)
    --> writes reviewed plan JSON (-PlanOutputPath)
        --> New-TenantTrust.ps1 (new, mutation-capable)
            --> Graph API: create Application, Service Principal, Federated Identity Credential
            --> GitHub API: create Environment + 3 variables
            --> re-invokes Initialize-TenantTrust.ps1 for read-back proof
```

`New-TenantTrust.ps1` never re-implements plan logic. It reads the JSON plan the existing tool already produces (via `Add-PlanItem`'s `Order`/`Operation`/`TargetType`/`TargetId`/`TargetName`/`Mode`/`Status`/`Properties` shape) and adds only the missing capability: executing `Create` items. It does not invent new verification either: after creating, it re-runs `Initialize-TenantTrust.ps1` fresh and requires every previously-`Create` item to now read back `Existing`/verified with an exact stable ID — reusing a tool a human already trusts rather than auditing new verification code. This leaves the existing, already-tested 1,500-line `Initialize-TenantTrust.ps1` completely untouched — zero regression risk to it.

Scope is deliberately narrow: only `EntraApplication`, `EntraServicePrincipal`, `EntraFederatedIdentityCredential`, `GitHubEnvironment` (and its 3 non-secret variables). `AzureDevOpsServicePrincipalEntitlement`, `AzureDevOpsReadersMembership`, and every `PowerPlatformEnvironment*` component are explicitly out of scope — separate sub-projects. No Azure RBAC role assignment is ever created, granted, or touched here, and no application secret or certificate credential is ever created — the federated identity credential is the only trust mechanism, matching this repository's existing hard rule (proven by `Initialize-TenantTrust.ps1`'s "never contains app credential creation commands" test).

## Components

| File | Responsibility |
|---|---|
| `infra/src/scripts/New-TenantTrust.ps1` (new) | CLI entry point. Reads a plan JSON produced by `Initialize-TenantTrust.ps1 -PlanOutputPath`, filters to in-scope `Create` items, executes them in `Order`, then re-invokes `Initialize-TenantTrust.ps1` for read-back proof. `[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]`. Performs the same interactive-context check as the existing tool: the authenticated Azure principal must be a `user` (never a service principal) whose `UserPrincipalName` matches the reviewed `AdminUpn`. |
| `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/New-EntraTrustApplication.ps1` (new) | `POST /applications` — single-tenant (`signInAudience = AzureADMyOrg`), exact reviewed display name `{NamingRoot}-github-bootstrap`. Reads the created object back via `GET` before returning. |
| `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/New-EntraTrustServicePrincipal.ps1` (new) | `POST /servicePrincipals` for the created application's `appId`. |
| `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/New-EntraTrustFederatedCredential.ps1` (new) | `POST /applications/{id}/federatedIdentityCredentials` with the exact issuer (`https://token.actions.githubusercontent.com`), audience (`api://AzureADTokenExchange`), and subject computed by the existing, reused `Get-GitHubOidcSubject` module function — never a hand-built string. |
| `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/New-GitHubBootstrapEnvironment.ps1` (new) | `PUT /repos/{owner}/{repo}/environments/{name}` (deployment branch policy restricted to `main`, required reviewer = the reviewed GitHub login), then `POST` the 3 non-secret variables `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`. |
| `infra/tests/pester/TenantTrustActivation.Tests.ps1` (new) | Full injected-adapter coverage mirroring `TenantTrust.Tests.ps1`'s dependency-injection pattern — zero live network calls in any test. Kept as its own file rather than growing the already 1,500+ line existing one. |
| `infra/docs/20-tenant-trust-activation-runbook.md` (new) | Tenant-agnostic (`<tenantAlias>`-parameterized), step-by-step operator runbook — see below. |

Each new Private function does exactly one Graph/GitHub call plus its own read-back; none creates more than one object type.

## Data Flow, Gating, and Error Handling

1. The human runs `az login` interactively, with Entra Application Administrator rights — outside any script, and never performed by an agent.
2. The human runs `Initialize-TenantTrust.ps1 -TenantAlias <alias> -PlanOutputPath plan.json` (existing tool, zero mutation) and reviews the plan.
3. The human — or an agent in the same session, only with the human's explicit go-ahead at this specific step — runs `New-TenantTrust.ps1 -TenantAlias <alias> -PlanPath plan.json`. Default PowerShell `ShouldProcess` behavior prompts for confirmation before creating each object; nothing is created silently.
4. A partial failure (for example, the Application is created but the Service Principal `POST` fails) is diagnosable and safely re-runnable: re-running `New-TenantTrust.ps1` against a fresh plan shows the Application as `Existing` and only attempts the remaining `Create` items. No rollback or delete logic is built — this matches [Bootstrap Recovery](../../infra/docs/19-bootstrap-recovery.md)'s existing "stop on ambiguity, repair only after approval" model, never an automatic delete.
5. Final step: re-run `Initialize-TenantTrust.ps1` fresh; every item that was `Create` must now read back `Existing` with a stable ID matching what was just created — not merely "an application exists somewhere."
6. Explicitly **not** covered by this sub-project: granting the two temporary Azure RBAC roles (Contributor, Role Based Access Control Administrator), running `bootstrap-tenant.yml`, or running `Enable-GitHubGovernance.ps1`. Those are already-built, later steps in the existing evidence-gated state machine and remain their own separate, attended actions.

## Testing

Every new Private function gets injected-adapter Pester tests: success path, a Graph/GitHub error response, and a read-back mismatch that must throw. No test makes a live call, matching this repository's universal pattern. `New-TenantTrust.ps1` gets integration-style tests using the same injection points, covering: a full `Create` set, a mixed `Existing`+`Create` plan, a plan containing an out-of-scope target type (must be skipped — Azure DevOps and Power Platform items are never touched), and a forced read-back mismatch after creation (must throw, never silently accept).

## Runbook (Reusable Across Tenants)

`infra/docs/20-tenant-trust-activation-runbook.md` is written parameterized by `<tenantAlias>` so the same steps activate trust for Tenant 2 and Tenant 3 later, per the sequence already documented in [Multi-Tenant Provisioning](../../infra/docs/18-multi-tenant-provisioning.md). It covers:

- **Prerequisites:** Entra Application Administrator (or Cloud Application Administrator) role for the operator; `az` CLI installed and not yet logged in; `gh` CLI already authenticated with repository administrator permission; the tenant's manifest committed with `LifecycleState = IntentReviewed` or later.
- **Step-by-step:** `az login` (interactive); run `Initialize-TenantTrust.ps1` and review the plan by hand; run `New-TenantTrust.ps1` and respond to each `ShouldProcess` confirmation; re-run `Initialize-TenantTrust.ps1` and confirm every prior `Create` item now shows `Existing` with a stable ID.
- **Explicit boundaries:** what this runbook does not do (temporary Azure role grants, `bootstrap-tenant.yml`, `Enable-GitHubGovernance.ps1`), each with a pointer to the existing document that owns it.
- **Troubleshooting:** maps directly to the relevant sections of [Bootstrap Recovery](../../infra/docs/19-bootstrap-recovery.md) ("Trust creation", "OIDC mismatch") rather than duplicating their content.

## Open Items (Tracked as Later Sub-Projects)

- Azure DevOps project configuration for Tenant 1 (Boards process, area paths/iterations, repurposing the Azure Repos config repo per the merged single-source-of-truth spec).
- Populating Azure Boards with the ~19 current use-case ideas, linked.
- The Azure Boards↔GitHub App connection (attended-only; cannot be automated by any tooling per ADR-0001 and Microsoft's own integration model) and final GitHub governance activation (`Enable-GitHubGovernance.ps1` — already built, not yet run).
- The Power Platform ALM pipeline foundation to build and deploy the code app and agent solution to DEV.
- Granting the two temporary Azure RBAC roles and running `bootstrap-tenant.yml` — the next attended step immediately after this sub-project's runbook completes.
