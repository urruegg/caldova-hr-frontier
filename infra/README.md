# infra — Infrastructure as Code

| Field | Value |
|---|---|
| **Version** | 1.6 |
| **Date** | 2026-10-02 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Infrastructure |
| **References** | [Tenant 1 Lean Engineering Platform Design](../docs/specs/2026-09-28-tenant-1-lean-engineering-platform-design.md), [Tenant 1 Lean Platform Runbook](docs/24-tenant-1-lean-platform-runbook.md), [Approved Intake Design](../docs/specs/2026-09-17-architecture-baseline-intake-design.md) |

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
- [Developer Workstation](docs/runbooks/01-developer-workstation.md) defines the approved local workstation assessment and initialization boundary.
- [Tenant Trust Activation Runbook](docs/20-tenant-trust-activation-runbook.md) is a `Superseded stop notice`; no supported trust-activation mutation path exists.
- [Azure Boards Population Runbook](docs/21-azure-boards-population-runbook.md) is a `Superseded stop notice`; Board synchronization remains deferred.
- [Cloud Service Foundation Runbook](docs/runbooks/02-cloud-service-foundation.md) is a `Superseded stop notice`; the dormant planner and apply entry points remain unsupported.
- [Customer Repository Handover](docs/runbooks/03-customer-handover.md) defines the attended synthetic export, approval, validation, and handover boundaries.

## Naming and Lifecycle

Public source uses stable descriptive paths under `src/`; infrastructure documentation uses ordered numeric filenames. Active procedures stay at their operational path. Unsafe or unsupported procedures remain as `Superseded` stop notices and link to reviewed successors. Tenant-private files remain ignored and are never reconstructed from prose.

## Current Boundary

At the end of Sprint 2, this domain contains documentation, solution-source ownership guidance, workstation assessment and initialization tooling, shared runbook contracts, and validation tests. It still contains no cloud-foundation Apply step, customer export or publication flow, production deployment flow, tenant-creation flow, Power Platform solution payload, or deployed resource.

This sprint permits attended local discovery, sanitized review, Bicep build, subscription-scope `what-if`, boundary validation, and context and access read-back. The operator uses pre-existing, separately approved least-privilege access. The sprint performs no role mutation, trust activation, GitHub Environment creation, Azure Pipeline execution, or deployment creation.

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
| [Tenant 1 lean platform design](../docs/specs/2026-09-28-tenant-1-lean-engineering-platform-design.md) | [Infrastructure Documentation](docs/README.md) | Active | Catalogues infrastructure guidance, procedures, and operational stop notices. | Maintained navigation; each child metadata status and explicit gate governs its use. |

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
