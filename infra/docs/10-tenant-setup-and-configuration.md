# Tenant Setup and Configuration

| Field | Value |
|---|---|
| **Version** | 1.1 |
| **Date** | 2026-09-24 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Infrastructure |
| **References** | [Approved Intake Design](../../docs/specs/2026-09-17-architecture-baseline-intake-design.md), [Source Inventory](../../docs/reviews/2026-09-17-architecture-baseline-source-inventory.json) |

This source-derived Proposed Baseline describes intended tenant setup and operations. It does not prove that any tenant, Azure resource, Azure DevOps object, Power Platform environment, GitHub governance control, pipeline, identity, or service is currently deployed or configured.

## Tenant Model

The repository supports exactly three independently onboarded tenants through one shared schema and shared automation. A run selects exactly one tenant; it never processes tenants through a matrix or shares one tenant's variables with another.

Each tenant has one manifest, one `bootstrap-${tenantAlias}` GitHub Environment, and one dedicated single-tenant Entra application and service principal for this repository. Tenant 1 is bootstrap-reviewed, Tenant 2 is discovery-ready, and Tenant 3 remains schema-ready only.

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

## Tenant 2 Reviewed Discovery Metadata

Tenant 2 is approved for attended discovery only. Its manifest remains `DiscoveryRequired`, its component map remains empty, and it is not selectable in the bootstrap workflow until reviewed evidence supplies stable identifiers and a later pull request records explicit intent.

| Field | Reviewed value | Current status |
|---|---|---|
| Tenant alias | `caldova25668747` | Reviewed intent |
| Display name | `Caldova25668747` | Reviewed intent |
| Tenant ID | `4682b8db-586c-4602-ad98-d29e4018fd5b` | Discovery required |
| Administrative UPN | `admin@caldova25668747.onmicrosoft.com` | Attended-account selector; discovery required |
| Subscription ID | `c097a50e-bfe0-487f-bffe-22d7695caadd` | Discovery required |
| Primary Azure region | `switzerlandnorth` | Reviewed intent |
| Azure DevOps organization | `https://dev.azure.com/Caldova25668747/` | Existing candidate; stable ID required |
| Azure DevOps project | `FrontierHR` | Existing candidate; stable ID required |
| Power Platform DEV | `https://calhrfrontierdev.crm17.dynamics.com/` | Existing candidate; stable ID required |
| Power Platform TEST | `https://calhrfrontiertest.crm17.dynamics.com/` | Existing candidate; stable ID required |
| Power Platform PROD | `https://calhrfrontier.crm17.dynamics.com/` | Existing candidate; stable ID required |
| SharePoint DEV | `https://caldova25668747.sharepoint.com/sites/HRFrontierDEV` | Existing candidate; stable site ID required |
| SharePoint TEST | `https://caldova25668747.sharepoint.com/sites/HRFrontierTEST` | Existing candidate; stable site ID required |
| SharePoint PROD | `https://caldova25668747.sharepoint.com/sites/HRFrontier` | Existing candidate; stable site ID required |
| Company abbreviation | `cal` | Reviewed intent |
| Workload name | `hr-agentic` | Reviewed intent |
| Unique suffix | `zenpnq` | Generated once and committed for review |

SharePoint discovery uses Microsoft Graph only to resolve each exact reviewed site collection. Normalized evidence permits the stable site ID, display name, web URL, stage scope, status, timestamp, and response hash. Lists, files, pages, permissions, and site content are outside this discovery contract.

## Desired State and Observed Evidence

The desired manifest is a PowerShell data file at `infra/src/config/tenants/<tenantAlias>.psd1`. It contains reviewed, non-secret intent only and must reject executable expressions and unknown keys.

Normalized observed evidence is JSON at `infra/evidence/discovery/<tenantAlias>.json`. It is read-only evidence with allowlisted fields, a shared run ID, collection timestamps, stable identifiers, query status, and response hashes. Raw service responses are not committed.

Every managed component uses exactly one reviewed mode:

- `Existing`: current evidence must match the reviewed stable ID exactly.
- `Create`: current evidence must prove that no conflicting or ambiguous object exists.

There is no `Auto` mode. Discovery never edits the manifest and never chooses intent.

## Evidence-Gated Sequence

1. Validate the data-only manifest and cross-field derivations.
2. Collect read-only evidence from GitHub, Entra, Azure, Azure DevOps, Power Platform, and any SharePoint sites declared by the selected manifest.
3. Stop if a required service is unauthorized, unavailable, ambiguous, or stale.
4. Review stable identifiers and record explicit `Existing` or `Create` decisions in a pull request.
5. Establish attended trust for the dedicated bootstrap application only after intent is reviewed.
6. Validate the exact immutable GitHub Environment OIDC subject against the read-only repository OIDC prefix.
7. Build the subscription-scope Bicep entry point and run `what-if` only.
8. Remove approved temporary role assignments by exact ID and verify absence.

A failed gate cannot be converted into success by broadening permissions, introducing a stored credential, or silently creating a replacement object.

## Tenant 2 Attended Discovery Runbook

1. Create the GitHub Environment `bootstrap-caldova25668747`.
2. Configure its non-secret variables `AZURE_CLIENT_ID`, `AZURE_TENANT_ID=4682b8db-586c-4602-ad98-d29e4018fd5b`, and `AZURE_SUBSCRIPTION_ID=c097a50e-bfe0-487f-bffe-22d7695caadd`.
3. Establish the dedicated single-tenant application, service principal, and federated credential for the immutable environment subject. Do not reuse Tenant 1 identity objects.
4. Add the application user to the three reviewed Power Platform environments with only the role needed for `who-am-i` and approved metadata reads.
5. Grant the application Microsoft Graph `Sites.Selected` application permission with admin consent, then grant `read` access to only the three reviewed SharePoint sites.
6. Sign in interactively as `admin@caldova25668747.onmicrosoft.com` and run `./infra/src/scripts/Invoke-TenantDiscovery.ps1 -TenantAlias caldova25668747 -AuthenticationMode Interactive` to create the first local evidence candidate.
7. Review the normalized file for exact tenant, subscription, Azure DevOps, Power Platform, and SharePoint stable identifiers. Commit it only after removing no fields and confirming that it contains no prohibited data.
8. Commit the reviewed baseline evidence in a dedicated pull request. That later change may add `caldova25668747` to the `Discover tenant` workflow choice so OIDC can validate the committed baseline and produce the seven-day redacted artifact.
9. Keep Tenant 2 excluded from `Validate tenant bootstrap` until another reviewed change records explicit `Existing` or `Create` decisions and generates its Bicep parameters.

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
