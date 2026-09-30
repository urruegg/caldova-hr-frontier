# Infrastructure Operational Runbooks

| Field | Value |
|---|---|
| **Version** | 1.2 |
| **Date** | 2026-09-30 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Infrastructure operations |
| **References** | [Operational Runbooks Design](../../../docs/specs/2026-09-26-operational-runbooks-design.md); [Tenant 1 Lean Platform Runbook](../24-tenant-1-lean-platform-runbook.md); [Infrastructure Domain](../../README.md) |

These runbooks govern attended, local operations for the infrastructure domain. They define how an operator proves readiness, previews reviewed intent, receives a digest for approval, executes only the approved changes, records redacted evidence, and closes with recovery when anything remains unresolved.

## Audience and ownership

The service owner approves the reviewed intent, records the approved digest, and accepts the residual risk of each run. The workstation administrator performs attended local operations on the approved Windows 11 workstation. An operator may run assessment to gather read-only evidence, but later cloud and tenant approvals remain separate responsibilities for the service owner, security administrators, and tenant administrators.

## Ordered state machine

1. **Prerequisites**: confirm Windows 11, administrator intent, repository integrity, and reviewed policy.
2. **Assessment**: run [Developer Workstation](01-developer-workstation.md) in read-only mode to prove current state and write assessment evidence.
3. **Preview and plan**: generate a workstation plan and execution manifest without mutating the machine.
4. **Digest approval**: the service owner reviews the exact manifest digest and approves only that manifest.
5. **Apply with `ShouldProcess`**: the workstation administrator removes `-WhatIf` only after approval; every native mutation stays behind PowerShell confirmation boundaries.
6. **Read-back**: each approved operation proves its exact postcondition or fails closed.
7. **Redacted evidence**: the run writes only non-secret execution evidence and summaries.
8. **Recovery and close**: any `Blocked`, `Refused`, or `Manual` item is escalated, reassessed, and re-approved before another run.

## Shared contract terms

- **Reviewed intent**: the already approved policy, repository state, and operator scope that define what the run may do.
- **Execution manifest**: the preview output that fixes the exact allowed actions, workstation identity, digest, expiry, and recovery contract for one attended run.
- **Evidence summary**: redacted operational evidence proving what was assessed, approved, attempted, read back, refused, or left manual.
- **`NoChange`**: the workstation already satisfies the reviewed postcondition.
- **`Create`**: the reviewed plan may add a missing local prerequisite in the exact way described by policy.
- **`Update`**: the reviewed plan may bring an approved prerequisite to the exact reviewed version.
- **`Manual`**: a human-only or unsupported boundary was reached; the run must stop or escalate without claiming verification.
- **`Blocked`**: the run cannot safely continue because state, identity, platform, or policy validation failed.
- **`Refused`**: the run intentionally declined a mutation because approval, interactivity, or confirmation requirements were not satisfied.

## Evidence boundaries

Evidence is written under the operator-selected report path, including the default `%LOCALAPPDATA%\CaldovaHrFrontier\runbook-evidence\...` paths used by the workstation runbook. Evidence may include command names, reviewed identifiers, non-secret account identifiers needed for read-back, digests, timestamps, statuses, and recovery instructions. Evidence must never include tokens, device codes, cookies, authorization headers, PATs, client secrets, certificate secrets, raw authentication responses, or workstation credential-store contents.

## Approval expiry and invalidation

Execution approval expires 30 minutes after manifest creation. Approval is invalid immediately if the repository commit changes, the workstation identity changes, the reviewed digest changes, the assessment digest changes, the operator broadens scope, or the workstation is restarted or partially mutated before successful close. Any invalidation requires a new assessment, a new preview, and a new digest approval.

## Interactive boundaries and unsupported APIs

These runbooks assume an attended PowerShell session on a local Windows 11 workstation. Elevation expectations, device-code entry, browser confirmation, MFA, Conditional Access, product terms, licensing acceptance, and any required restart are completed personally by the operator. Unsupported or human-only API boundaries remain `Manual`. GitHub Actions are prohibited tenant-preparation paths, and OIDC workload identities are prohibited for this local runbook baseline.

## Local-only tenant operations

All later GitHub, Azure, Azure DevOps, Power Platform, and SharePoint operations start from this workstation in an attended PowerShell session. No repository workflow, runner, PAT, token, password, client secret, or unattended identity prepares a tenant in this baseline. A token is never supplied to these scripts or stored in their evidence.

## Authentication lifecycle

Authentication happens only in later attended procedures after the workstation is initialized. The operator signs in with the supported device or web flow, performs immediate context read-back, completes the reviewed operation, performs final context read-back, signs out, deletes or removes the exact temporary profile where supported, and verifies cleanup. Cleanup failure is `Manual`, not success. If the account, tenant, subscription, project, or environment read-back is wrong or incomplete, the run stops before mutation.

## Escalation and recovery

When a step blocks, refuses, or leaves a manual item, stop immediately, preserve sanitized evidence, notify the service owner plus the responsible workstation or security administrator, and reassess before retrying. Recovery never broadens scope, changes package IDs, weakens security controls, or treats a `Manual` item as verified. Restart or partial failure always requires full reassessment, a new manifest, and a new digest.

## Repository-integrity expectations

Repository-bundled Superpowers skills and custom agents are integrity and presence checked by assessment only; they are never machine-installed by a workstation procedure. `.github/plugins` is expected to be absent in this baseline. Vendored skill content under `.github/skills` must never be edited by a workstation runbook or workstation procedure.

## Runbook catalogue

| Runbook | Scope | Status |
|---|---|---|
| [Developer Workstation](01-developer-workstation.md) | Independently runnable assessment, preview, approval, apply, read-back, and recovery for one approved Windows 11 administrator workstation. | In scope now |
| [Cloud Service Foundation Runbook](02-cloud-service-foundation.md) | Superseded stop notice for dormant cloud-foundation entry points; retained generic modules are not an approved operating path. | Superseded |
| [Customer Repository Handover](03-customer-handover.md) | Independently runnable local attended customer export assessment, approval, apply, independent validation, and human review after workstation prerequisites. | In scope now |
| [Tenant 1 Lean Platform](../24-tenant-1-lean-platform-runbook.md) | Attended local private configuration, discovery, Bicep build, subscription `what-if`, boundary validation, and context/access read-back. | In scope now |
| [Tenant Trust Activation](../20-tenant-trust-activation-runbook.md) | Stop notice for the dormant trust command; it is not an active prerequisite or supported procedure. | Superseded |
| Future publication and production deployment runbooks | Later attended operations that consume this workstation baseline. | Out of scope in this increment |
