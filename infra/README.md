# infra — Infrastructure as Code

| Field | Value |
|---|---|
| **Version** | 1.4 |
| **Date** | 2026-09-30 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Infrastructure |
| **References** | [Tenant 1 Lean Engineering Platform Design](../docs/specs/2026-09-28-tenant-1-lean-engineering-platform-design.md), [Tenant 1 Lean Platform Runbook](docs/24-tenant-1-lean-platform-runbook.md), [Approved Intake Design](../docs/specs/2026-09-17-architecture-baseline-intake-design.md) |

This source-derived Proposed Baseline describes intended infrastructure architecture and operations. It does not prove that any tenant, Azure resource, Azure DevOps object, Power Platform environment, GitHub governance control, pipeline, identity, or service is currently deployed or configured.

## Purpose

The `infra/` domain owns public infrastructure source, subscription-scope Bicep, attended local validation scripts, infrastructure tests, and unpacked Infrastructure Power Platform solution source. Tenant-private configuration and raw operational evidence stay outside version control.

Caldova HR Frontier uses one tenant-dedicated GitHub product-source repository and one Azure DevOps project per tenant. For the current Tenant 1 lean sprint, the active configuration is the ignored, validated `infra/src/config/tenants/tenant1.local.psd1` file. The approved deletion of the tracked Tenant 1 transition files is committed; they are absent and must not be reconstructed. Tenant 2's tracked files remain unchanged and are not selected by Tenant 1 validation.

There is no automatic intent mode. Discovery reports observed state; a reviewed pull request records desired state.

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

## Documentation Map

| Document | Purpose |
|---|---|
| [Tenant Setup and Configuration](docs/10-tenant-setup-and-configuration.md) | Defines reviewed private configuration, sanitized evidence, explicit intent, and tenant-stage boundaries. |
| [Identity and Access](docs/11-identity-and-access.md) | Defines attended administration and separately approved pre-existing minimum access. |
| [Power Platform Environments and ALM](docs/12-power-platform-environments-and-alm.md) | Defines the future DEV-to-TEST-to-PROD solution lifecycle. |
| [Azure DevOps Engineering Control Plane](docs/13-azure-devops-engineering-control-plane.md) | Describes the approved Azure Boards single backlog and GitHub sole-product-source integration. |
| [GitHub Repository Blueprint](docs/14-github-repository-blueprint.md) | Describes the Tenant 1 repository and lean `main` governance target without a bootstrap Environment. |
| [Agent and Workload Configuration](docs/15-agent-workload-configuration.md) | Describes future workload packaging, grounding, and release controls. |
| [Security, Governance and Compliance](docs/16-security-governance-and-compliance.md) | Describes proposed technical controls and evidence requirements. |
| [Bootstrap and Provisioning](docs/17-bootstrap-and-provisioning.md) | Defines the attended local, what-if-only validation sequence. |
| [Multi-Tenant Provisioning](docs/18-multi-tenant-provisioning.md) | Defines one repository and one Azure DevOps project per tenant, plus the Tenant 2 transition exception through Slice 5. |
| [Bootstrap Recovery](docs/19-bootstrap-recovery.md) | Defines attended recovery without bypassing validation or approvals. |
| [Tenant Trust Activation Runbook](docs/20-tenant-trust-activation-runbook.md) | Superseded stop notice for the dormant, unsupported trust command. |
| [Tenant 1 Lean Platform Runbook](docs/24-tenant-1-lean-platform-runbook.md) | Active attended local Tenant 1 sequence, checkpoints, and acceptance contract. |
| [Operational Runbooks](docs/runbooks/README.md) | Defines the shared preview, approval, evidence, manual-step, read-back, and recovery contract. |
| [Developer Workstation](docs/runbooks/01-developer-workstation.md) | Assesses and explicitly initializes an approved Windows 11 administrator workstation. |
| [Cloud Service Foundation Runbook](docs/runbooks/02-cloud-service-foundation.md) | Superseded stop notice for dormant planner/apply entry points; no supported mutation path. |
| [Customer Repository Handover](docs/runbooks/03-customer-handover.md) | Defines local attended synthetic customer export assessment, digest approval, apply, independent validation, and handover boundaries. |
| [Infrastructure Solution Sources](src/solutions/README.md) | Defines ownership and exclusions for future unpacked solution source. |

## Conventions

1. Validate before authenticated operations and fail closed on missing, stale, unauthorized, unavailable, or ambiguous evidence.
2. Keep tenant IDs, subscription IDs, project names, and approved service URLs as reviewed non-secret metadata when needed for cross-checking.
3. Never commit tokens, credentials, private keys, connection strings, environment-specific solution values, or personal HR data.
4. Keep `DEV`, `TEST`, and `PROD` exclusive to Power Platform ALM. They are not Azure infrastructure environments.
5. Use deterministic names derived from reviewed tenant-private configuration; never generate a second suffix during recovery.
6. Treat local documentation links as current contracts. Refer to future paths as inline code until later tasks create them.

The proposed Bicep and PowerShell split follows [ADR-0003](../docs/adr/0003-bicep-and-powershell-for-infrastructure-as-code.md). That ADR remains a candidate until separately approved.
