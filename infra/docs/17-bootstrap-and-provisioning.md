# Bootstrap and Provisioning

| Field | Value |
|---|---|
| **Version** | 1.3 |
| **Date** | 2026-09-28 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Infrastructure |
| **References** | [Tenant 1 Engineering Platform Remediation Design](../../docs/specs/2026-09-28-tenant-1-engineering-platform-remediation-design.md), [Approved Intake Design](../../docs/specs/2026-09-17-architecture-baseline-intake-design.md), [Source Inventory](../../docs/reviews/2026-09-17-architecture-baseline-source-inventory.json), [ADR-0012](../../docs/adr/0012-per-tenant-github-repository-and-account-topology.md) |

This document applies the approved Wave 0 topology to the Proposed Baseline bootstrap and validation operations. It does not prove that any tenant, Azure resource, Azure DevOps object, Power Platform environment, GitHub control, pipeline, identity, role, or service is currently deployed or configured.

## Meaning of Bootstrap

Bootstrap establishes and validates the control plane needed for secretless discovery and future provisioning. In this sprint it may later create or validate explicitly approved GitHub, Entra, Power Platform access, and Azure authorization objects needed for trust and least-privilege validation. It does not deploy the Azure platform resources modeled by Bicep.

Each tenant has its own dedicated product-source repository, Azure DevOps project, and private configuration repository (see [ADR-0012](../../docs/adr/0012-per-tenant-github-repository-and-account-topology.md)). This repository bootstraps only Tenant 1 using the approved private configuration path, the `bootstrap-tenant1` Environment with self-review disabled, one dedicated single-tenant app and service principal, one normalized discovery record, and one explicit set of `Existing` or `Create` decisions. Tenant 2's existing manifest and discovery evidence remain hash-pinned here until Slice 5 verifies their handoff; they are not eligible for bootstrap.

## Evidence-Gated State Machine

```text
SourceAssessed
-> ContentReviewed
-> TenantDeclared
-> DiscoveryCollected
-> IntentReviewed
-> TrustEstablished
-> OidcValidated
-> WhatIfValidated
-> GitHubGovernanceActivated
```

Every transition validates the preceding state and produces reviewable evidence. Partial, stale, unauthorized, unavailable, or ambiguous evidence cannot authorize a change.

## Planned Sequence

1. Validate Tenant 1 configuration from the approved private path in `caldova-hr-frontier-config`.
2. Collect attended read-only discovery from GitHub, Entra, Azure, Azure DevOps, and Power Platform.
3. Normalize allowlisted evidence and reject prohibited data.
4. Review stable IDs and commit explicit `Existing` or `Create` intent.
5. Create or validate the tenant's dedicated single-tenant app, service principal, exact federated credential, and GitHub Environment through an attended approval gate.
6. Add the application to each verified Power Platform environment with the minimum metadata-read role only after separate approval.
7. Validate secretless OIDC against the exact repository Environment subject.
8. Collect fresh read-only evidence and compare it with reviewed intent.
9. Build and format the subscription-scope Bicep entry point.
10. Validate exact temporary role assignments and run subscription `what-if` only.
11. Validate the machine-readable result against the approved type, scope, resource-group, and location boundary.
12. After explicit deletion approval, remove the two temporary role assignments by exact ID and verify absence.
13. Activate final GitHub governance only after all preceding evidence succeeds on `main`.

Tenant 1 is the only tenant eligible for bootstrap validation. Tenant 2 is eligible for attended read-only discovery but remains unprovisioned and excluded from bootstrap validation; Tenant 3 remains schema-ready only.

## Desired State and Discovery

The desired Tenant 1 configuration at the approved private path is reviewed non-secret intent. The normalized JSON inventory is observed read-only evidence. Discovery never rewrites private configuration automatically.

Every managed component has one reviewed mode:

- `Existing`, supported by an exact stable-ID match;
- `Create`, supported by evidence that no conflicting or ambiguous object exists.

There is no automatic mode, and discovery never creates an object.

## Trust Bootstrap

The bootstrap identity is a dedicated single-tenant Entra application and service principal for the selected tenant and this repository. Managed identities are reserved for future Azure-hosted workloads.

The GitHub OIDC trust uses:

```text
Issuer: https://token.actions.githubusercontent.com
Audience: api://AzureADTokenExchange
Subject: repo:${owner}@${ownerId}/${repository}@${repositoryId}:environment:bootstrap-tenant1
```

The trust setup first reads GitHub repository metadata and OIDC customization. It requires reviewed owner and repository names and IDs, immutable subjects enabled, and an exact `sub_claim_prefix` match before deriving the Environment context. The attended setup creates no stored credential and reads back all reviewed fields. Any tenant, repository, immutable ID, prefix, Environment, issuer, audience, subject, client, or subscription mismatch stops the process.

## Azure Command Boundary

Documented Azure CLI examples in this sprint are limited to:

- account and subscription context reads;
- role-assignment reads;
- Bicep format and build;
- subscription-scope `what-if`.

The private Tenant 1 parameters path is supplied by the attended operator and is never committed to this product-source repository. The validation shape is:

```powershell
$privateTenant1ParametersPath = '<approved-private-path>\tenant1.bicepparam'
az bicep format --file infra/src/bicep/main.bicep
az bicep build --file infra/src/bicep/main.bicep --stdout
az deployment sub what-if `
  --location switzerlandnorth `
  --template-file infra/src/bicep/main.bicep `
  --parameters $privateTenant1ParametersPath `
  --result-format FullResourcePayloads `
  --no-pretty-print
```

The private parameter path and Bicep entry point above are later-slice artifacts and therefore appear as inline code, not current links. No Azure deployment command is allowed in this sprint.

## Approved `what-if` Boundary

The future subscription composition may show only:

| Resource type | Required scope |
|---|---|
| `Microsoft.Resources/resourceGroups` | Selected tenant subscription |
| `Microsoft.OperationalInsights/workspaces` | Reviewed platform resource group |
| `Microsoft.Insights/diagnosticSettings` | Subscription Activity Log |
| `Microsoft.Authorization/roleDefinitions` | Selected tenant subscription |
| `Microsoft.Authorization/roleAssignments` | Selected tenant subscription |

Tenant 1 policy assignments are an explicit empty set. Any delete, foreign subscription, foreign resource group, unsupported type, unexpected location, ignored diagnostic, or error fails validation.

The `what-if` is a plan, not a deployment. This sprint creates no resource group, workspace, diagnostic setting, policy, Key Vault, storage account, network, application runtime, or workload identity.

## Temporary Privilege Lifecycle

An attended administrator may later grant exactly `Contributor` and `Role Based Access Control Administrator` at the selected subscription to the reviewed bootstrap principal. Their exact assignment IDs are kept outside Git.

Cleanup validates each assignment's principal, role, and scope; removes Contributor first and role administration last after explicit approval; then polls read-only state until both exact IDs are absent. Cleanup failure fails the run and follows [Bootstrap Recovery](./19-bootstrap-recovery.md).

## Non-Azure Boundaries

- Azure DevOps organization and Tenant 1 project are discovery candidates; neither is created here.
- The three Power Platform URLs are discovery hints; no environment or solution is created or imported.
- GitHub Environments and final ruleset are later attended control-plane work; Task 1 creates neither.
- Azure Boards GitHub App authorization remains an attended step because the connection creation flow is not automated.

## Task 1 State

Task 1 imports and reconciles documentation only. It does not authenticate interactively, call a cloud mutation API, create a manifest, execute Bicep, grant a role, run `what-if`, or activate governance.
