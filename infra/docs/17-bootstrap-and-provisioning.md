# Bootstrap and Provisioning

| Field | Value |
|---|---|
| **Version** | 2.1 |
| **Date** | 2026-09-29 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Infrastructure |
| **References** | [Tenant 1 Lean Engineering Platform Design](../../docs/specs/2026-09-28-tenant-1-lean-engineering-platform-design.md), [Tenant 1 Lean Platform Runbook](24-tenant-1-lean-platform-runbook.md), [Bootstrap Recovery](19-bootstrap-recovery.md) |

This document defines the current Tenant 1 validation boundary. Here, bootstrap means proving reviewed intent through attended local checks and Azure subscription `what-if`; it does not mean creating trust, authorization, or infrastructure.

## Current Boundary

The active sequence consumes:

- the explicit ignored `infra/src/config/tenants/tenant1.local.psd1` file;
- local read-only discovery evidence;
- one generated local `.bicepparam` file;
- the attended operator's pre-existing, separately approved least-privilege access; and
- the maintained subscription-scope Bicep entry point.

It creates no Entra object, workload federation, GitHub Environment, role assignment, Azure deployment, Azure Pipeline, Azure DevOps repository, Power Platform environment, or solution deployment.

`Initialize-TenantTrust.ps1` is dormant and unsupported. The historical temporary-role grant, state, and cleanup scripts are outside the active dependency graph.

## Fail-Closed State Machine

```text
PrivateConfigurationValidated
-> AttendedContextValidated
-> MinimumAccessPreflightValidated
-> DiscoveryCollected
-> SanitizedReviewCompleted
-> BicepBuilt
-> WhatIfValidated
-> BoundaryAndAccessReadBackValidated
```

Every transition validates the previous state. Missing, stale, unauthorized, unavailable, ambiguous, foreign-scope, or indeterminate evidence stops the run.

## Fixed Local Sequence

1. Resolve the explicit ignored local Tenant 1 configuration and verify its protected backup.
2. Read the attended user, tenant, and subscription.
3. Query the attended user with group expansion and require exactly one direct-user or group assignment to the deterministic approved custom validation role and its exact read/validate/`whatIf` action set.
4. Collect local discovery and review a sanitized summary.
5. Generate parameters for the exact attended principal.
6. Build the maintained Bicep and parameter file.
7. Invoke `az deployment sub what-if` once with full resource payloads.
8. Validate the machine-readable result against the approved boundary.
9. Repeat attended context and access reads.
10. Require identical principal, tenant, subscription, and access evidence.

The exact commands are in the [Tenant 1 Lean Platform Runbook](24-tenant-1-lean-platform-runbook.md).

## Azure Command Boundary

Allowed Azure CLI operations are limited to:

- `az account show`;
- `az ad signed-in-user show`;
- exact-scope role-assignment listing;
- role-definition listing;
- Bicep build and parameter build; and
- `az deployment sub what-if`.

The active bootstrap script has no deployment-create path and no role-assignment create, update, or delete path. It stores raw evidence only under the operator-selected local root outside Git.

## Approved What-If Boundary

The future subscription composition may show only:

| Resource type | Required scope |
|---|---|
| `Microsoft.Resources/resourceGroups` | Selected Tenant 1 subscription |
| `Microsoft.OperationalInsights/workspaces` | Reviewed platform resource group |
| `Microsoft.Insights/diagnosticSettings` | Subscription Activity Log |
| `Microsoft.Authorization/roleDefinitions` | Selected Tenant 1 subscription |
| `Microsoft.Authorization/roleAssignments` | Selected Tenant 1 subscription |

Tenant 1 policy assignments remain an explicit empty set. Any delete, foreign subscription, foreign resource group, unsupported type, unexpected location, ignored diagnostic, warning, error, or malformed payload fails validation.

Authorization resources in the plan are predicted future state only. Because the command is `what-if`, the current sprint does not create, update, or delete them.

## Evidence and Read-Back

The script writes local `what-if.json` and `access-validation.json` files beside the selected discovery evidence. The access record contains preflight and post-`what-if` views of the same exact principal, subscription scope, assignments, role definitions, actions, and exclusions.

These files support attended review. They are not deployment evidence, approval records, or repository artifacts.

## No-Deployment Rule

`what-if` is a plan. A successful result does not prove that a resource exists and does not authorize a deployment. Never replace it with `az deployment sub create`, `New-AzSubscriptionDeployment`, a portal deployment, or a pipeline.

## Tenant Isolation

Tenant 1 is the only selected validation target. Tenant 2's tracked transition files remain unchanged. The bootstrap script has no default configuration path, repository scan, tenant matrix, or fallback that could select Tenant 2.

## Recovery

On failure, stop and follow [Bootstrap Recovery](19-bootstrap-recovery.md). Do not broaden permissions, switch identity, change subscription, mutate a role, activate trust, delete tracked transition files, or retry with a different tenant.
