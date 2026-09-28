# infra — Infrastructure as Code

| Field | Value |
|---|---|
| **Version** | 1.1 |
| **Date** | 2026-09-28 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Infrastructure |
| **References** | [Tenant 1 Engineering Platform Remediation Design](../docs/specs/2026-09-28-tenant-1-engineering-platform-remediation-design.md), [Approved Intake Design](../docs/specs/2026-09-17-architecture-baseline-intake-design.md), [Source Inventory](../docs/reviews/2026-09-17-architecture-baseline-source-inventory.json) |

This source-derived Proposed Baseline describes intended infrastructure architecture and operations. It does not prove that any tenant, Azure resource, Azure DevOps object, Power Platform environment, GitHub governance control, pipeline, identity, or service is currently deployed or configured.

## Purpose

The `infra/` domain owns public infrastructure source, normalized sanitized discovery evidence, subscription-scope Bicep, bootstrap scripts, infrastructure tests, and unpacked Infrastructure Power Platform solution source. Tenant-private configuration belongs at an attended private path in `caldova-hr-frontier-config`; it is not a second product source. This documentation-only task performs no file or platform mutation.

Caldova HR Frontier uses one tenant-dedicated GitHub product-source repository and one Azure DevOps project per tenant. For Tenant 1, this repository is the sole product source and `caldova-hr-frontier-config` is the tenant-private Azure Repo. The private repository contains no product source, credential, unrestricted membership export, synchronization, or initial disaster-recovery mirror. Tenant 2's existing manifest and discovery evidence remain here as the explicit hash-pinned transition exception until Slice 5 verifies their handoff.

- one reviewed Tenant 1 configuration overlay at an approved private path in `caldova-hr-frontier-config`;
- one GitHub Environment named `bootstrap-tenant1`, restricted to `main`, with the approved reviewer and self-review disabled;
- one dedicated single-tenant Microsoft Entra application and service principal for this repository;
- one normalized, read-only discovery record;
- explicit reviewed `Existing` or `Create` intent for every managed component.

There is no automatic intent mode. Discovery reports observed state; a reviewed pull request records desired state.

## Current Boundary

At the end of Sprint 2, this domain contains documentation, solution-source ownership guidance, workstation assessment and initialization tooling, shared runbook contracts, and validation tests. It still contains no cloud-foundation Apply step, customer export or publication flow, production deployment flow, tenant-creation flow, Power Platform solution payload, or deployed resource.

This sprint permits later tasks to establish attended trust, validate secretless GitHub OIDC, perform read-only discovery, build Bicep, and run subscription-scope `what-if`. It does not permit an Azure deployment or creation of the resources shown by `what-if`.

No resource group, Log Analytics workspace, custom role, policy, Key Vault, storage account, application runtime, Power Platform environment, Azure DevOps project, repository, pipeline, solution, or GitHub ruleset is created or deployed by Task 1.

## Tool Boundary

| Tool | Intended responsibility | Sprint boundary |
|---|---|---|
| Bicep | Model the approved subscription baseline | Format, build, and subscription `what-if` only; no deployment |
| PowerShell | Validate private configuration, transition manifests, and evidence; orchestrate attended trust, discovery, validation, and exact-ID cleanup | Fail closed; no inferred intent and no secret material |
| GitHub Actions | Select one tenant and bind to its exact Environment subject | Manual dispatch, OIDC, read-only discovery, validation, and `what-if` only |
| Service APIs | Read stable identifiers and verify attended control-plane changes | Discovery is read-only; mutation requires the explicit gate owned by its later task |

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
| [Identity and Access](docs/11-identity-and-access.md) | Defines attended administration, per-tenant bootstrap identity, OIDC, and least privilege. |
| [Power Platform Environments and ALM](docs/12-power-platform-environments-and-alm.md) | Defines the future DEV-to-TEST-to-PROD solution lifecycle. |
| [Azure DevOps Engineering Control Plane](docs/13-azure-devops-engineering-control-plane.md) | Describes the approved Azure Boards single backlog and GitHub sole-product-source integration. |
| [GitHub Repository Blueprint](docs/14-github-repository-blueprint.md) | Describes the Tenant 1 repository, `bootstrap-tenant1`, no-self-review, and governance target. |
| [Agent and Workload Configuration](docs/15-agent-workload-configuration.md) | Describes future workload packaging, grounding, and release controls. |
| [Security, Governance and Compliance](docs/16-security-governance-and-compliance.md) | Describes proposed technical controls and evidence requirements. |
| [Bootstrap and Provisioning](docs/17-bootstrap-and-provisioning.md) | Defines the evidence-gated, no-deployment bootstrap sequence. |
| [Multi-Tenant Provisioning](docs/18-multi-tenant-provisioning.md) | Defines one repository and one Azure DevOps project per tenant, plus the Tenant 2 transition exception through Slice 5. |
| [Bootstrap Recovery](docs/19-bootstrap-recovery.md) | Defines attended recovery without bypassing validation or approvals. |
| [Tenant Trust Activation Runbook](docs/20-tenant-trust-activation-runbook.md) | Operator runbook for activating a tenant's Entra/GitHub/Azure DevOps trust using the existing Initialize-TenantTrust.ps1. |
| [Operational Runbooks](docs/runbooks/README.md) | Defines the shared preview, approval, evidence, manual-step, read-back, and recovery contract. |
| [Developer Workstation](docs/runbooks/01-developer-workstation.md) | Assesses and explicitly initializes an approved Windows 11 administrator workstation. |
| [Cloud Service Foundation Runbook](docs/runbooks/02-cloud-service-foundation.md) | Defines local attended delegated assessment, digest-bound approval, exact target read-back, manual boundaries, evidence, and recovery. |
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
