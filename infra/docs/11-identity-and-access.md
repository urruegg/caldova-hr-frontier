# Identity and Access

| Field | Value |
|---|---|
| **Version** | 2.1 |
| **Date** | 2026-09-29 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Infrastructure |
| **References** | [Tenant 1 Lean Engineering Platform Design](../../docs/specs/2026-09-28-tenant-1-lean-engineering-platform-design.md), [Tenant 1 Lean Platform Runbook](24-tenant-1-lean-platform-runbook.md), [Tenant Trust Stop Notice](20-tenant-trust-activation-runbook.md) |

This Proposed Baseline defines the current attended identity and access boundary. It does not prove that a tenant control, Azure role, GitHub rule, pipeline, or Power Platform permission is configured.

## Current Identity Boundary

| Identity | Current use | Prohibited use |
|---|---|---|
| Attended Tenant 1 operator | Local context validation, discovery, Bicep build, subscription `what-if`, and read-back | CI/CD credential, stored password, unattended workload identity, or cross-tenant operation |
| Future workload managed identity | Separately reviewed Azure-hosted runtime | Tenant bootstrap or current local validation |
| Future Power Platform application user | Separately reviewed ALM duties | Current sprint or broad administrator access |

The current sprint has no bootstrap Entra application, service principal, federated credential, or GitHub bootstrap Environment. `Initialize-TenantTrust.ps1` is dormant and unsupported; see the [superseded stop notice](20-tenant-trust-activation-runbook.md).

## Attended Administration

The operator signs in personally and verifies:

- `az account show` reports `user.type` as `user`;
- the tenant ID matches the local Tenant 1 configuration;
- the subscription ID matches the local Tenant 1 configuration; and
- `az ad signed-in-user show` returns a GUID object ID.

The same checks run after subscription `what-if`. A changed principal, tenant, subscription, non-user context, failed lookup, or malformed identifier blocks acceptance.

Scripts never request, relay, print, or store a password, MFA response, token, recovery code, client secret, certificate secret, or private key. MFA, Conditional Access, PIM, emergency access, and administrator-role governance remain separately owned controls.

## Separately Approved Minimum Access

The operator's access exists and is approved outside this sprint. Before discovery and `what-if`, the bootstrap script queries the exact attended principal with group expansion at the exact Tenant 1 subscription scope and resolves the returned role definition.

Evidence must show exactly one direct-user or group assignment to the deterministic `<NamingRoot>-deployment-validation` custom role. That role uses the exact subscription as its only assignable scope and contains exactly `*/read`, deployment read, deployment validate, and deployment `whatIf` actions, with every exclusion and data-action list empty. The preflight records:

- exact principal object ID;
- exact tenant and subscription IDs;
- exact subscription scope;
- assignment IDs;
- user-or-group principal type;
- role-definition ID, name, type, and assignable scope; and
- exact actions, exclusions, and data-action lists.

The same evidence is collected after `what-if` and compared. Wildcard `*`, Owner, Contributor, User Access Administrator, Role Based Access Control Administrator, extra assignment, extra write/delete action, foreign scope, context mismatch, or any access drift fails closed.

Task 4 does not create, update, or delete a role definition or role assignment. It does not call the historical temporary-role grant, state, or cleanup path.

## Local Evidence Boundary

Access evidence is written beside the operator's local discovery file, outside Git. It supports attended review but is not proof of deployment or authorization approval. The approval record remains in its separately governed system.

Do not commit raw assignment evidence, raw discovery, generated parameters, or raw `what-if` output. A shareable summary contains only the minimum stable identifiers, status, timestamps, and hashes needed for review.

## Discovery Authorization

Discovery is read-only. `Unauthorized`, `Unavailable`, and `Ambiguous` are distinct outcomes and all block the run. A lack of permission is never interpreted as absence.

Service-specific access beyond the Azure subscription `what-if` capability remains outside this task. Do not broaden access, add a stored credential, create an application user, or query business data to make discovery pass.

## Deferred Identity Designs

A bootstrap workload identity, trust federation, delivery identity, or Power Platform application user may return only through a new reviewed design. Historical specifications and the dormant command are not active prerequisites and provide no execution approval.

## Verification Contract

Acceptance requires:

1. an attended user context before and after `what-if`;
2. exact Tenant 1 tenant and subscription matches;
3. one stable GUID principal through the full run;
4. separately approved pre-existing capability at the exact subscription scope;
5. identical access evidence before and after `what-if`;
6. no role mutation; and
7. no unattended identity, trust activation, or deployment creation.
