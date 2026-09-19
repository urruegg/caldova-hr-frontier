# Tenant Setup and Configuration

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-17 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Infrastructure |
| **References** | [Approved Intake Design](../../docs/specs/2026-09-17-architecture-baseline-intake-design.md), [Source Inventory](../../docs/reviews/2026-09-17-architecture-baseline-source-inventory.json) |

This source-derived Proposed Baseline describes intended tenant setup and operations. It does not prove that any tenant, Azure resource, Azure DevOps object, Power Platform environment, GitHub governance control, pipeline, identity, or service is currently deployed or configured.

## Tenant Model

The repository supports exactly three independently onboarded tenants through one shared schema and shared automation. A run selects exactly one tenant; it never processes tenants through a matrix or shares one tenant's variables with another.

Each tenant has one manifest, one `bootstrap-${tenantAlias}` GitHub Environment, and one dedicated single-tenant Entra application and service principal for this repository. Tenant 2 and Tenant 3 remain schema- and workflow-ready only. They are not provisioned in this sprint.

## Tenant 1 Reviewed Metadata

These values are reviewed non-secret metadata and may be versioned. They are cross-checked against discovery and authenticated context before any later bootstrap action.

| Field | Reviewed value | Evidence status in Task 1 |
|---|---|---|
| Tenant alias | `caldova25156897` | Reviewed intent |
| Display name | `Caldova25156897` | Reviewed intent |
| GitHub owner ID | `46865858` | Read-only API verified 2026-09-19 |
| GitHub repository ID | `1371297722` | Read-only API verified 2026-09-19 |
| Tenant ID | `e2312862-df63-440c-8bcf-007a2c52859d` | Discovery required |
| Administrative UPN | `admin@Caldova25156897.onmicrosoft.com` | Attended-account selector; discovery required |
| Subscription ID | `edb45a24-408d-47c4-bbc7-685b9b3fc017` | Discovery required |
| Primary Azure region | `switzerlandnorth` | Reviewed intent |
| Azure DevOps organization | `https://dev.azure.com/caldova25156897/` | Existing candidate; stable ID required |
| Azure DevOps project | `Caldova HR Frontier` | Existing candidate; stable ID required |
| Power Platform DEV | `https://hrfrontierdev.crm17.dynamics.com/` | Existing candidate; stable ID required |
| Power Platform TEST | `https://hrfrontiertest.crm17.dynamics.com/` | Existing candidate; stable ID required |
| Power Platform PROD | `https://hrfrontier.crm17.dynamics.com/` | Existing candidate; stable ID required |
| Company abbreviation | `cal` | Reviewed intent |
| Workload name | `hr-agentic` | Reviewed intent |
| Unique suffix | Not assigned in Task 1 | Generated once in a later reviewed task |

The organization, project, and three Power Platform URLs are discovery hints. They may be classified `Existing` only after current read-only evidence returns the expected stable identifiers.

## Desired State and Observed Evidence

The desired manifest is a PowerShell data file at `infra/src/config/tenants/<tenantAlias>.psd1`. It contains reviewed, non-secret intent only and must reject executable expressions and unknown keys.

Normalized observed evidence is JSON at `infra/evidence/discovery/<tenantAlias>.json`. It is read-only evidence with allowlisted fields, a shared run ID, collection timestamps, stable identifiers, query status, and response hashes. Raw service responses are not committed.

Every managed component uses exactly one reviewed mode:

- `Existing`: current evidence must match the reviewed stable ID exactly.
- `Create`: current evidence must prove that no conflicting or ambiguous object exists.

There is no `Auto` mode. Discovery never edits the manifest and never chooses intent.

## Evidence-Gated Sequence

1. Validate the data-only manifest and cross-field derivations.
2. Collect read-only evidence from GitHub, Entra, Azure, Azure DevOps, and Power Platform.
3. Stop if a required service is unauthorized, unavailable, ambiguous, or stale.
4. Review stable identifiers and record explicit `Existing` or `Create` decisions in a pull request.
5. Establish attended trust for the dedicated bootstrap application only after intent is reviewed.
6. Validate the exact immutable GitHub Environment OIDC subject against the read-only repository OIDC prefix.
7. Build the subscription-scope Bicep entry point and run `what-if` only.
8. Remove approved temporary role assignments by exact ID and verify absence.

A failed gate cannot be converted into success by broadening permissions, introducing a stored credential, or silently creating a replacement object.

## Power Platform ALM Terminology

`DEV`, `TEST`, and `PROD` mean only Power Platform application lifecycle stages:

```text
Unmanaged authoring in DEV -> managed validation in TEST -> approved managed release to PROD
```

They are not Azure subscriptions, Azure resource groups, Bicep stages, or infrastructure environment names. The supplied URLs do not prove environment type, Managed Environment status, DLP configuration, security groups, or solution presence.

Microsoft recommends at least a separate test environment before production in [ALM basics](https://learn.microsoft.com/en-us/power-platform/alm/basics-alm). Release-station and environment-type constraints remain relevant future design inputs in [Environment strategy](https://learn.microsoft.com/en-us/power-platform/alm/environment-strategy-alm).

## Administrative Boundary

The reviewed administrator UPN is used only to select and verify the attended account for operations that require a human administrator. It is never a CI credential. Passwords, MFA responses, access tokens, recovery codes, and private keys are neither accepted by scripts nor stored in the repository.

Tenant settings, licensing, break-glass accounts, Conditional Access, Microsoft 365 workloads, DLP, Managed Environments, and Power Platform security remain attended future decisions. Task 1 neither configures nor verifies them. Useful planning references include [Power Platform tenant settings](https://learn.microsoft.com/en-us/power-platform/admin/tenant-settings), [Managed Environment licensing](https://learn.microsoft.com/en-us/power-platform/admin/managed-environment-licensing), and [Azure landing zones](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/).

## Task 1 Exit Condition

Task 1 is complete only as documentation intake: the ten source documents are reconciled, rejected placeholders remain absent, source ownership is documented, and no cloud or API mutation has occurred. Later implementation and live-state reviews own every operational claim.
