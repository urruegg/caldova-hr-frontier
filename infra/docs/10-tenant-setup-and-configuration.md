# Tenant Setup and Configuration

| Field | Value |
|---|---|
| **Version** | 2.0 |
| **Date** | 2026-09-29 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Infrastructure |
| **References** | [Tenant 1 Lean Engineering Platform Design](../../docs/specs/2026-09-28-tenant-1-lean-engineering-platform-design.md), [Tenant 1 Lean Platform Runbook](24-tenant-1-lean-platform-runbook.md), [Approved Intake Design](../../docs/specs/2026-09-17-architecture-baseline-intake-design.md) |

This Proposed Baseline defines the current configuration boundary. It does not prove that an Azure resource, Azure DevOps object, Power Platform environment, GitHub control, pipeline, identity, permission, or service is deployed or configured.

## Current Tenant Model

Each run selects one explicit public tenant key and one explicit configuration path. There is no tenant matrix, automatic selection, or fallback to a tracked manifest.

Tenant 1 is the only lean-platform validation target. The ignored and validated file `infra/src/config/tenants/tenant1.local.psd1` is its active configuration. It remains local to the attended workstation and is backed up outside Git.

The two tracked Tenant 1 transition files remain temporarily because deletion approval was unavailable. They are not active inputs and this sprint does not delete them. Tenant 2's tracked files remain unchanged and are not selected, migrated, validated, or deleted by the Tenant 1 sequence.

## Tenant 1 Reviewed Metadata

The local configuration carries the reviewed tenant alias, tenant and subscription IDs, primary location, deterministic naming values, repository identifiers, Azure DevOps hints, Power Platform URLs, and explicit component intent. These values are private operational context even when individual identifiers are not credentials.

The active script contract requires:

- `PublicTenantKey` to equal `tenant1`;
- `TenantConfigurationPath` to identify the ignored local file explicitly;
- the file to remain untracked and ignored;
- the signed-in tenant and subscription to match the configuration exactly;
- the selected attended principal to remain unchanged through read-back; and
- Tenant 2 to remain unselected and unchanged.

No script infers a tenant from an environment variable, tracked filename, workflow choice, repository Environment, or cloud configuration source.

## Desired State and Observed Evidence

The local PowerShell data file is reviewed intent. The local discovery JSON is observed read-only evidence. Both remain outside version control.

Every managed component has exactly one reviewed mode:

- `Existing`: current evidence must match the reviewed stable ID exactly.
- `Create`: current evidence must prove that no conflicting or ambiguous object exists.

There is no `Auto` mode. Discovery never edits configuration or chooses intent. An `Unauthorized`, `Unavailable`, `Ambiguous`, stale, partial, or mismatched result stops validation.

## Active Attended Sequence

1. Verify the ignored local Tenant 1 configuration and its local backup.
2. Identify the attended user and exact tenant and subscription.
3. Validate pre-existing, separately approved minimum access without changing a role.
4. Collect local read-only discovery.
5. Review a sanitized local summary.
6. Generate local Bicep parameters for the attended principal.
7. Build Bicep and execute subscription `what-if` only.
8. Validate the resource boundary.
9. Read back the same principal, tenant, subscription, and effective access.

The complete commands and failure gates are in the [Tenant 1 Lean Platform Runbook](24-tenant-1-lean-platform-runbook.md).

## Private Artifact Boundary

Never commit:

- `tenant1.local.psd1` or its backup;
- raw discovery or service responses;
- generated `.bicepparam` files;
- access preflight/read-back evidence;
- raw `what-if` output;
- credentials, tokens, keys, authentication headers, or personal HR data.

Sanitized summaries may include only reviewed stable identifiers, status, timestamps, and response hashes needed for decision traceability.

## Tenant 2 Transition Boundary

Tenant 2 remains a transition concern outside this lean Tenant 1 sprint. Its tracked manifest and discovery evidence remain in place. No Task 4 script or runbook uses them as a template, default, fallback, or validation input.

Any future migration or deletion requires an explicit reviewed plan, current hashes, destination read-back, and approval. Absence of approval means no deletion.

## Power Platform ALM Terminology

`DEV`, `TEST`, and `PROD` refer only to Power Platform application lifecycle stages:

```text
Unmanaged authoring in DEV -> managed validation in TEST -> approved managed release to PROD
```

They are not Azure subscriptions, Azure resource groups, Bicep stages, or infrastructure environment names. The current sprint does not create an environment, import a solution, assign an application user, or perform a Power Platform deployment.

## Administrative Boundary

The reviewed administrator UPN is an attended-account selector, never a CI credential. Scripts do not accept or store passwords, MFA responses, access tokens, recovery codes, client secrets, or private keys.

The operator's Azure access is provisioned and approved separately before the run. Task 4 records and compares read-only access evidence; it creates, changes, and deletes no role assignment.
