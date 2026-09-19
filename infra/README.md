# infra — Infrastructure as Code

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-17 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Infrastructure |
| **References** | [Approved Intake Design](../docs/specs/2026-09-17-architecture-baseline-intake-design.md), [Source Inventory](../docs/reviews/2026-09-17-architecture-baseline-source-inventory.json) |

This source-derived Proposed Baseline describes intended infrastructure architecture and operations. It does not prove that any tenant, Azure resource, Azure DevOps object, Power Platform environment, GitHub governance control, pipeline, identity, or service is currently deployed or configured.

## Purpose

The `infra/` domain owns future tenant manifests, normalized discovery evidence, subscription-scope Bicep, bootstrap scripts, infrastructure tests, and unpacked Infrastructure Power Platform solution source. All executable artifacts are introduced by later reviewed tasks; Phase 3 Task 1 imports documentation only.

Caldova HR Frontier uses one shared GitHub repository. Each independent tenant receives:

- one reviewed data-only manifest at `infra/src/config/tenants/<tenantAlias>.psd1`;
- one GitHub Environment named `bootstrap-${tenantAlias}`;
- one dedicated single-tenant Microsoft Entra application and service principal for this repository;
- one normalized, read-only discovery record;
- explicit reviewed `Existing` or `Create` intent for every managed component.

There is no automatic intent mode. Discovery reports observed state; a reviewed pull request records desired state.

## Current Boundary

At the end of Task 1, this domain contains documentation and the solution-source ownership README only. It contains no Bicep implementation, tenant manifest, discovery evidence, executable bootstrap script, workflow, test payload, Power Platform solution payload, or deployed resource.

This sprint permits later tasks to establish attended trust, validate secretless GitHub OIDC, perform read-only discovery, build Bicep, and run subscription-scope `what-if`. It does not permit an Azure deployment or creation of the resources shown by `what-if`.

No resource group, Log Analytics workspace, custom role, policy, Key Vault, storage account, application runtime, Power Platform environment, Azure DevOps project, repository, pipeline, solution, or GitHub ruleset is created or deployed by Task 1.

## Tool Boundary

| Tool | Intended responsibility | Sprint boundary |
|---|---|---|
| Bicep | Model the approved subscription baseline | Format, build, and subscription `what-if` only; no deployment |
| PowerShell | Validate manifests and evidence; orchestrate attended trust, discovery, validation, and exact-ID cleanup | Fail closed; no inferred intent and no secret material |
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
|   |-- config/tenants/
|   |-- scripts/
|   `-- solutions/
`-- tests/pester/
```

A path shown here is an ownership boundary, not evidence that its artifact already exists.

## Documentation Map

| Document | Purpose |
|---|---|
| [Tenant Setup and Configuration](docs/10-tenant-setup-and-configuration.md) | Defines the reviewed manifest, evidence, intent, and tenant-stage boundaries. |
| [Identity and Access](docs/11-identity-and-access.md) | Defines attended administration, per-tenant bootstrap identity, OIDC, and least privilege. |
| [Power Platform Environments and ALM](docs/12-power-platform-environments-and-alm.md) | Defines the future DEV-to-TEST-to-PROD solution lifecycle. |
| [Azure DevOps Engineering Control Plane](docs/13-azure-devops-engineering-control-plane.md) | Describes the proposed backlog and delivery control-plane integration. |
| [GitHub Repository Blueprint](docs/14-github-repository-blueprint.md) | Describes the one-repository collaboration and governance target. |
| [Agent and Workload Configuration](docs/15-agent-workload-configuration.md) | Describes future workload packaging, grounding, and release controls. |
| [Security, Governance and Compliance](docs/16-security-governance-and-compliance.md) | Describes proposed technical controls and evidence requirements. |
| [Bootstrap and Provisioning](docs/17-bootstrap-and-provisioning.md) | Defines the evidence-gated, no-deployment bootstrap sequence. |
| [Multi-Tenant Provisioning](docs/18-multi-tenant-provisioning.md) | Defines isolation for three independent tenants in one repository. |
| [Bootstrap Recovery](docs/19-bootstrap-recovery.md) | Defines attended recovery without bypassing validation or approvals. |
| [Infrastructure Solution Sources](src/solutions/README.md) | Defines ownership and exclusions for future unpacked solution source. |

## Conventions

1. Validate before authenticated operations and fail closed on missing, stale, unauthorized, unavailable, or ambiguous evidence.
2. Keep tenant IDs, subscription IDs, project names, and approved service URLs as reviewed non-secret metadata when needed for cross-checking.
3. Never commit tokens, credentials, private keys, connection strings, environment-specific solution values, or personal HR data.
4. Keep `DEV`, `TEST`, and `PROD` exclusive to Power Platform ALM. They are not Azure infrastructure environments.
5. Use deterministic names derived from the reviewed tenant manifest; never generate a second suffix during recovery.
6. Treat local documentation links as current contracts. Refer to future paths as inline code until later tasks create them.

The proposed Bicep and PowerShell split follows [ADR-0003](../docs/adr/0003-bicep-and-powershell-for-infrastructure-as-code.md). That ADR remains a candidate until separately accepted.
