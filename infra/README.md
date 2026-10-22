# infra — Infrastructure as Code

| Field | Value |
|---|---|
| **Version** | 1.10 |
| **Date** | 2026-10-19 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Infrastructure |
| **References** | [Approved Tenant 1 Runbook End-to-End Design](../docs/specs/2026-10-02-tenant-1-runbook-end-to-end-design.md), [Approved Child Summary Envelope Design](../docs/specs/2026-10-03-tenant-lifecycle-child-summary-envelope-design.md), [Draft Child Summary Envelope Implementation Plan](../docs/plans/2026-10-03-tenant-lifecycle-child-summary-envelope-implementation.md), [Tenant Lifecycle Core Implementation Plan](../docs/plans/2026-10-02-tenant-lifecycle-core-implementation.md), [Tenant 1 Lean Engineering Platform Design](../docs/specs/2026-09-28-tenant-1-lean-engineering-platform-design.md), [Tenant 1 Lean Platform Runbook](docs/24-tenant-1-lean-platform-runbook.md), [Approved Intake Design](../docs/specs/2026-09-17-architecture-baseline-intake-design.md) |

This source-derived Proposed Baseline describes intended infrastructure architecture and operations. It does not prove that any tenant, Azure resource, Azure DevOps object, Power Platform environment, GitHub governance control, pipeline, identity, or service is currently deployed or configured.

## Purpose and Authority

The `infra/` domain owns public infrastructure source, subscription-scope Bicep, attended local validation scripts, infrastructure tests, and unpacked Infrastructure Power Platform solution source. Tenant-private configuration and raw operational evidence stay outside version control.

Caldova HR Frontier uses one tenant-dedicated GitHub product-source repository and one Azure DevOps project per tenant. For the current Tenant 1 lean sprint, the active configuration is the ignored, validated `infra/src/config/tenants/tenant1.local.psd1` file. The approved deletion of the tracked Tenant 1 transition files is committed; they are absent and must not be reconstructed. Tenant 2's tracked files remain unchanged and are not selected by Tenant 1 validation.

There is no automatic intent mode. Discovery reports observed state; a reviewed pull request records desired state.

## Contains and Does Not Contain

This domain contains public Bicep, scripts, tests, solution-source ownership guidance, and maintained infrastructure documentation. It does not contain tenant-private configuration, credentials, raw operational evidence, unattended live mutation, or proof that a resource exists.

## Reading Order

Start at the [repository knowledge map](../docs/README.md), then this domain boundary, then the [infrastructure documentation catalogue](docs/README.md). Read the relevant design before a runbook, and use current sanitized read-back before making a claim about deployed state.

## Safety-Critical Entry Points

- [Tenant 1 Lean Platform Runbook](docs/24-tenant-1-lean-platform-runbook.md) is the active attended local Tenant 1 sequence and acceptance contract.
- [Operational Runbooks](docs/runbooks/README.md) catalogues the shared preview, approval, evidence, read-back, and recovery procedures.
- [`Invoke-TenantLifecycle.ps1`](src/scripts/runbooks/Invoke-TenantLifecycle.ps1) is a provider-neutral coordinate-only sequencing core with the exact Assess/Plan/Verify modes. Assess and Plan accept only a hidden non-mutating child invoker; Verify rejects an invoker, validates immutable canonical stage results and child artifact digests, and writes only a stage-only projection. It has no Apply, approval, `ShouldProcess`, current-binding provider, provider action, or provider result authority.
- [Developer Workstation](docs/runbooks/01-developer-workstation.md) defines the approved local workstation assessment and initialization boundary.
- [Tenant Trust Activation Runbook](docs/20-tenant-trust-activation-runbook.md) is a `Superseded stop notice`; no supported trust-activation mutation path exists.
- [Azure Boards Population Runbook](docs/21-azure-boards-population-runbook.md) is a `Superseded stop notice`; Board synchronization remains deferred.
- [Cloud Service Foundation Runbook](docs/runbooks/02-cloud-service-foundation.md) is a `Superseded stop notice`; the dormant planner and apply entry points remain unsupported.
- [Customer Repository Handover](docs/runbooks/03-customer-handover.md) defines the attended synthetic export, approval, validation, and handover boundaries.

## Naming and Lifecycle

Public source uses stable descriptive paths under `src/`; infrastructure documentation uses ordered numeric filenames. Active procedures stay at their operational path. Unsafe or unsupported procedures remain as `Superseded` stop notices and link to reviewed successors. Tenant-private files remain ignored and are never reconstructed from prose.

## Current Boundary

Plan 1 adds closed tenant-lifecycle schemas, private intent/state validation, one-time reviewed Create adoption, shared cross-host string-preserving JSON loading, deterministic prerequisites, retained child manifest/approval/action/state/read-back helpers, immutable canonical stage results, a provider-neutral coordinate-only umbrella, and a stage-only acceptance projection. Child execution-manifest roots require ordinal `selectedStages` and `prerequisiteResults`; umbrella Verify validates those coordinates and never uses provider actions for topology. Private stable state remains only in ignored `tenant1.state.local.json` and is bound by `stateDigest`; it is not run evidence. Plan 1 adds no workstation, cloud-foundation, DEV-delivery, or handover subsystem implementation to the umbrella. It still contains no active cloud-foundation Apply step, lifecycle-driven customer export or publication flow, production deployment flow, tenant-creation flow, Power Platform solution payload, or deployed resource. The dormant cloud-foundation stop stubs remain unchanged.

Existing independently runnable procedures retain their own explicit gates: child Plan, child `approvals.json`, child WhatIf/Apply, child `ShouldProcess`, child read-back/state adoption, terminal summary, and `<run>/stage-results/<stage>.json`. A dependency succeeds at the umbrella only with literal `Passed`; `Failed`, `Manual`, `Blocked`, and `Refused` stop the chain. The lifecycle core itself permits only provider-neutral validation, non-mutating Assess/Plan sequencing through an injected invoker, exact Verify validation without child invocation, and a stage-only projection. It performs no authentication, provider discovery, role mutation, trust activation, GitHub Environment creation, Azure Pipeline execution, PAC operation, solution import, deployment creation, handover publication, or provider mutation.

Plan 1 was implemented with local synthetic tests only; no live cloud, provider, or tenant operation was performed. Its projection explicitly makes no provider execution, approval, read-back, deployment, publication, or live-state claim. Plan 1 remains incomplete and Plans 2-6 remain `Draft` and blocked until the coordinate-only correction is merged and then-current `main` is green.

## Approved Child Summary Envelope and Residual Gate

The shared child summary envelope reserves exactly `schemaVersion`, `runId`, `stage`, `sourceCommit`, `publicTenantKey`, `intentDigest`, `stateDigest`, `phaseManifestDigest`, `status`, `classification`, and `completedAtUtc`, and retains the five standard fields `startedAtUtc`, `counts`, `prerequisites`, `actions`, and `nonClaims`.

Provider-specific extras are root-only and opaque, are absent from projections and errors, and cannot enter the closed shared nested structures.

The manifest embedded `digest`, exact-file `phaseManifestDigest`, and exact-file `phaseSummaryDigest` are three distinct checks.

The child writes the summary before the stage result, and the summary has no self-digest.

Umbrella `Verify` and `Assess`/`Plan` prerequisite dispatch enforce the same envelope and embedded manifest digest.

Legacy evidence fails closed and requires a new run; there is no compatibility, inference, or repair path.

Umbrella authority remains exactly `Assess`, `Plan`, and `Verify`; `stage-results` remains authoritative and the second `Verify` pass remains required.

Plan 1 and the child summary envelope implementation remain synthetic, `Draft`, and blocked until reviewed merge and then-current green `main`.

No live, provider, or tenant operation was performed, and no merge-readiness claim is made.

No resource group, Log Analytics workspace, custom role, policy, Key Vault, storage account, application runtime, Power Platform environment, Azure DevOps project, repository, pipeline, solution, or GitHub ruleset is created or deployed by Task 1.

## Tool Boundary

| Tool | Intended responsibility | Sprint boundary |
|---|---|---|
| Bicep | Model the approved subscription baseline | Format, build, and subscription `what-if` only; no deployment |
| PowerShell | Validate explicit local configuration, discovery, Bicep inputs, Azure context, access, and the `what-if` boundary | Attended and local; no role, trust, or deployment mutation |
| GitHub Actions | Validate repository setup for governed pull requests | No tenant discovery, OIDC bootstrap, or Azure operation |
| Service APIs | Read stable identifiers, exact context, and effective access | Read-only in this sprint; indeterminate results fail closed |

Managed identities are reserved for future Azure-hosted workloads. They are not the bootstrap identity.

## Planned Layout

Later tasks may add these reviewed paths:

```text
infra/
|-- README.md
|-- docs/
|-- evidence/discovery/
|-- src/
|   |-- bicep/
|   |-- config/                    public schemas, samples, and hash-pinned transition files only
|   |-- scripts/
|   `-- solutions/
`-- tests/pester/
```

A path shown here is an ownership boundary, not evidence that its artifact already exists.

## Catalogue

| Prior or next stage | Direct child | Status | Purpose | Authority |
|---|---|---|---|---|
| [Approved Tenant 1 runbook end-to-end design](../docs/specs/2026-10-02-tenant-1-runbook-end-to-end-design.md) | [Infrastructure Documentation](docs/README.md) | Active | Catalogues infrastructure guidance, procedures, operational stop notices, and the implemented provider-neutral lifecycle-core boundary. | Maintained navigation; the lifecycle core is synthetic-only and each child metadata status and explicit gate governs operational use. |

## Conventions

1. Validate before authenticated operations and fail closed on missing, stale, unauthorized, unavailable, or ambiguous evidence.
2. Keep tenant IDs, subscription IDs, project names, and approved service URLs as reviewed non-secret metadata when needed for cross-checking.
3. Never commit tokens, credentials, private keys, connection strings, environment-specific solution values, or personal HR data.
4. Keep `DEV`, `TEST`, and `PROD` exclusive to Power Platform ALM. They are not Azure infrastructure environments.
5. Use deterministic names derived from reviewed tenant-private configuration; never generate a second suffix during recovery.
6. Treat local documentation links as current contracts. Refer to future paths as inline code until later tasks create them.

The proposed Bicep and PowerShell split follows [ADR-0003](../docs/adr/0003-bicep-and-powershell-for-infrastructure-as-code.md). That ADR remains a candidate until separately approved.

## Domain Links

- [Documentation knowledge map](../docs/README.md)
- [Specifications](../docs/specs/README.md)
- [Implementation plans](../docs/plans/README.md)
- [Durable reviews](../docs/reviews/README.md)
- [HR domain](../hr/README.md)
- [Data domain](../data/README.md)

## Board Synchronization

Azure Boards synchronization is `Deferred - not synchronized`. This domain README does not create or infer a Board identifier.
