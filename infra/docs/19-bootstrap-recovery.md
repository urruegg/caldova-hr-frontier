# Bootstrap Recovery

| Field | Value |
|---|---|
| **Version** | 2.1 |
| **Date** | 2026-09-30 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Infrastructure |
| **References** | [Tenant 1 Lean Platform Runbook](24-tenant-1-lean-platform-runbook.md), [Bootstrap and Provisioning](17-bootstrap-and-provisioning.md), [Tenant 1 Lean Engineering Platform Design](../../docs/specs/2026-09-28-tenant-1-lean-engineering-platform-design.md) |

This Proposed Baseline defines recovery for the attended Tenant 1 local validation path. Recovery resumes from a newly proven state. It never broadens permissions, mutates a role, activates trust, changes tenant, creates a deployment, or recreates a deleted tracked transition file.

## Universal Stop Rule

On any failure:

1. stop later steps;
2. preserve local evidence outside Git;
3. record a sanitized failure summary without credentials or private values;
4. identify the accountable owner for the failed boundary;
5. correct the underlying issue through a separately reviewed action; and
6. restart at attended context and minimum-access preflight.

Never splice discovery, access evidence, parameters, or `what-if` output from different attempts.

## Private Configuration or Backup Failure

- **Last trusted state:** no authenticated operation.
- **Diagnostics:** confirm the explicit path exists, is a data-only `.psd1` file, is ignored and untracked, matches `tenant1`, and has an encrypted external backup in a separate failure domain.
- **Recovery:** compare source and external-backup SHA-256, restore the backup to a separate destination, verify the restored SHA-256 and schema/import, then restore to the exact ignored `tenant1.local.psd1` path and validate with `RequireLocalUntracked` without logging values.
- **Stop boundary:** do not fall back to the tracked transition files or `_template.psd1`.

The tracked Tenant 1 transition files were removed by the approved committed deletion. Recovery never reconstructs or recommits them.

## Attended Context Failure

- **Last trusted state:** local configuration validation.
- **Diagnostics:** run `az account show` and `az ad signed-in-user show`; compare user type, tenant, subscription, and GUID principal locally.
- **Recovery:** end the incorrect session and establish the separately approved attended session.
- **Stop boundary:** do not use a workload identity, environment variable override, different tenant, or stored credential.

## Minimum-Access Preflight Failure

- **Last trusted state:** exact attended context.
- **Diagnostics:** preserve the read-only exact-scope assignment and role-definition result; distinguish missing capability, foreign scope, malformed data, and authorization failure.
- **Recovery:** the access owner reviews and corrects access outside this sprint under a separate approval.
- **Stop boundary:** Task 4 never creates, changes, or deletes an assignment and never invokes temporary-role scripts.

After correction, restart the whole sequence. Do not treat a `403`, `404`, empty result, or indeterminate response as evidence of absence.

## Discovery Failure

- **Last trusted state:** context and access preflight.
- **Diagnostics:** identify the service, requested allowlisted scope, principal, status, and sanitized error class.
- **Recovery:** correct the reviewed selector or separately owned service access, then collect one new complete discovery record.
- **Stop boundary:** do not query business data, introduce a secret, infer an object, or mix service results from different runs.

## Sanitized Review Failure

- **Last trusted state:** local raw discovery only.
- **Diagnostics:** identify prohibited, ambiguous, stale, or mismatched fields without publishing the raw record.
- **Recovery:** rerun discovery after correcting the source issue or produce a new sanitized summary.
- **Stop boundary:** do not commit raw evidence or remove required fields merely to pass review.

## Bicep Build Failure

- **Last trusted state:** reviewed local discovery and parameters.
- **Diagnostics:** inspect compiler diagnostics, parameter derivation, target scope, and allowed resource types.
- **Recovery:** correct source through a reviewed pull request and regenerate parameters from the same validated ignored configuration.
- **Stop boundary:** do not suppress diagnostics, broaden the boundary, or replace build with deployment.

## What-If Failure

- **Last trusted state:** successful Bicep build; no `what-if` result is trusted.
- **Diagnostics:** preserve the local exit code and sanitized Azure error class.
- **Recovery:** correct the source, parameters, access, or transient platform issue through the accountable owner, then restart.
- **Stop boundary:** never substitute a deployment-create command.

## Out-of-Boundary Result

- **Last trusted state:** successful `what-if` API response that authorizes no action.
- **Diagnostics:** identify every unsupported type, scope, resource group, location, delete, warning, error, ignored diagnostic, and malformed change.
- **Recovery:** correct configuration, parameters, or Bicep through review and rerun the complete attended sequence.
- **Stop boundary:** do not expand the allowlist or ignore a change to make the result pass.

## Context or Access Read-Back Drift

- **Last trusted state:** the preflight record; acceptance is blocked.
- **Diagnostics:** compare principal, tenant, subscription, scope, assignment IDs, role definitions, actions, and exclusions.
- **Recovery:** preserve both local views, notify the access owner, and investigate the external change.
- **Stop boundary:** do not restore or remove access under this runbook and do not accept the `what-if`.

## GitHub, Boards, or Empty-Repository Checkpoint Failure

GitHub governance, Basic Boards, and any empty Azure Repo deletion have separate owners and approvals. A failed read, ambiguous object, unexpected branch, wrong work-item process, unresolved conversation, or failed status check blocks the final governed transaction.

Do not weaken the ruleset, create a second workflow, convert Boards to Agile, delete an Issue, or delete an Azure Repo without exact pre-state and explicit approval.

## Dormant Trust Artifact

`Initialize-TenantTrust.ps1` is dormant and unsupported. Recovery never invokes it. A trust or delivery-identity need requires a new reviewed design; see the [superseded stop notice](20-tenant-trust-activation-runbook.md).
