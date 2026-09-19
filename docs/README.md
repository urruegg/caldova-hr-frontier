# Documentation

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-17 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Active |
| **Scope** | Cross-cutting (all solution domains) |
| **References** | [Docs Agent](../.github/agents/docs-agent.agent.md) |

## Policy

All maintained repository documentation is written in English, stored as UTF-8, aligned with delivered behavior or explicitly marked Proposed Baseline, and owned by a named solution domain.

Every repository-owned Markdown artifact contains the standard six-field metadata table immediately after its first H1. Agent YAML frontmatter may precede the H1. Git history is the change log.

## Exclusions

The header and language migration do not modify vendored files below `.github/skills/{vendored-skill}/`, licenses, generated evidence, machine-readable manifests, or externally owned immutable text. `.github/skills/README.md` is repository-owned and is included.

## Placement

- `docs/`: cross-cutting knowledge, decisions, specifications, plans, reviews, and policies.
- `infra/docs/`: infrastructure, identity, security, tenant bootstrap, and ALM control-plane knowledge.
- `hr/docs/`: HR domain behavior and employee-journey knowledge.
- `data/`: synthetic-data guidance and assets.

The [Docs Agent](../.github/agents/docs-agent.agent.md) owns metadata, placement, references, English-language review, and catalogue maintenance.

## Decision Candidates

The ADR candidates below are imported as Proposed Baseline content. They are not accepted repository decisions until attended review approves them. Phase 2 intake status is recorded in [Phase 2 Product HR Operating Model Intake](reviews/2026-09-17-phase-2-product-hr-operating-model-intake.md).

| Candidate                                                                                                                                       | Topic                                                                          |
| ----------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| [ADR-0001: Azure DevOps as the Engineering Control Plane, GitHub as the Digital Factory](adr/0001-azure-devops-as-engineering-control-plane.md) | Proposed split between Azure Boards governance and GitHub delivery surfaces.   |
| [ADR-0002: GitHub-First Bootstrap, and the Role of Azure Repos](adr/0002-github-first-bootstrap-and-the-role-of-azure-repos.md)                 | Proposed public GitHub origin with private Azure Repos configuration boundary. |
| [ADR-0003: Bicep and PowerShell for Infrastructure as Code](adr/0003-bicep-and-powershell-for-infrastructure-as-code.md)                        | Proposed infrastructure toolchain and future `infra/` ownership model.         |
| [ADR-0004: Domain Solution Architecture, Naming and Publisher](adr/0004-domain-solution-architecture-and-publisher.md)                          | Proposed Power Platform solution layering, naming, and publisher baseline.     |

## Microsoft Evaluation

[Microsoft Best Practice Evaluation](90-microsoft-best-practice-evaluation.md) is imported as a source-derived Proposed Baseline assessment. Its `Aligned` positions describe alignment of the documented design, not proof that tenant configuration, deployed controls, Azure DevOps objects, Azure resources, Power Platform solutions, or rulesets currently exist.

## Operating Model

The operating-model set is imported as Proposed Baseline content: it describes the intended future operating model and does not by itself prove tenant configuration, deployed agents, Azure DevOps objects, pipelines, environments, Power Platform solutions, Azure resources, or Teams structures exist. Phase 2 intake status is recorded in [Phase 2 Product HR Operating Model Intake](reviews/2026-09-17-phase-2-product-hr-operating-model-intake.md).

| Document                                                               | Purpose                                                                                                            |
| ---------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| [North Star](operating-model/00-north-star.md)                         | Defines the cross-cutting ambition, loop, and operating principles for Caldova HR Frontier.                        |
| [PRD](operating-model/01-prd.md)                                       | Captures the product purpose, audiences, capabilities, requirements, KPIs, risks, and MVP acceptance criteria.     |
| [System Design](operating-model/02-system-design.md)                   | Describes the intended control planes, data flows, repository structure, integration patterns, and security model. |
| [Agent Operating Model](operating-model/03-agent-operating-model.md)   | Defines planned agent roles, principles, outputs, handoffs, and publication standards.                             |
| [HITL Governance](operating-model/04-hitl-governance.md)               | Sets the human-in-the-loop approval, redaction, audit, escalation, and standing prohibition rules.                 |
| [Implementation Roadmap](operating-model/05-implementation-roadmap.md) | Lays out the MVP and Horizon 2 phases, backlog, sequencing, and delivery constraints.                              |

## Infrastructure Domain

The Infrastructure domain is imported as source-derived Proposed Baseline documentation. It describes intended architecture, discovery, trust, validation, ALM, security, and recovery boundaries; it does not prove that tenant configuration, Azure resources, Azure DevOps objects, Power Platform environments, GitHub controls, pipelines, identities, or services currently exist. Task 1 disposition and pending approval are recorded in [Phase 3 Infrastructure and Tenant Bootstrap Intake](reviews/2026-09-17-phase-3-infrastructure-tenant-bootstrap-intake.md).

| Document                                                                                                   | Purpose                                                                                                                  |
| ---------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| [Infrastructure Domain](../infra/README.md)                                                                | Defines domain ownership, current no-payload boundary, planned layout, tool boundaries, and document map.                |
| [Tenant Setup and Configuration](../infra/docs/10-tenant-setup-and-configuration.md)                       | Defines the reviewed tenant metadata, desired manifest, observed evidence, explicit intent, and terminology boundaries. |
| [Identity and Access](../infra/docs/11-identity-and-access.md)                                             | Defines attended administration, per-tenant bootstrap identity, exact OIDC binding, and temporary privilege lifecycle.  |
| [Power Platform Environments and ALM](../infra/docs/12-power-platform-environments-and-alm.md)             | Defines future DEV-to-TEST-to-PROD ALM, solution ordering, variables, connections, and evidence requirements.            |
| [Azure DevOps Engineering Control Plane](../infra/docs/13-azure-devops-engineering-control-plane.md)       | Describes the proposed backlog and delivery split, discovery candidates, API constraints, and future pipeline boundary. |
| [GitHub Repository Blueprint](../infra/docs/14-github-repository-blueprint.md)                             | Defines the shared-repository model, tenant Environments, proposed governance, public-repository safety, and read-back.  |
| [Agent and Workload Configuration](../infra/docs/15-agent-workload-configuration.md)                       | Defines future agent, flow, app, grounding, packaging, release, and data-prohibition contracts.                          |
| [Security, Governance and Compliance](../infra/docs/16-security-governance-and-compliance.md)              | Defines evidence-first security principles and proposed DLP, Dataverse, identity, audit, and compliance controls.       |
| [Bootstrap and Provisioning](../infra/docs/17-bootstrap-and-provisioning.md)                               | Defines the evidence-gated state machine, attended trust, subscription `what-if`, and no-deployment boundary.           |
| [Multi-Tenant Provisioning](../infra/docs/18-multi-tenant-provisioning.md)                                 | Defines isolation for exactly three independent tenants using one repository and one-tenant execution.                  |
| [Bootstrap Recovery](../infra/docs/19-bootstrap-recovery.md)                                               | Defines attended recovery from nine failure states without bypassing validation, approvals, or least privilege.         |
| [Infrastructure Solution Sources](../infra/src/solutions/README.md)                                        | Defines ownership and exclusions for future unpacked Infrastructure Power Platform solution source.                     |

## Data Domain

The Data domain is imported as Proposed Baseline guidance for future synthetic demonstration data. No seed JSON is imported in Phase 2.

| Document                                    | Purpose                                                                                           |
| ------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| [Synthetic Demo Data](../data/README.md)    | Defines synthetic-data rules, planned seed-file formats, and the future reset procedure boundary. |

## HR Domain

The HR domain is imported as Proposed Baseline guidance for the future employee-journey solution. No Power Platform solution payload is imported in Phase 2.

| Document                                                        | Purpose                                                                                                                                    |
| --------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| [HR Domain](../hr/README.md)                                    | Summarizes HR domain ownership, MVP scope, conventions, and the Infra-before-HR dependency.                                                |
| [HR Employee Journey](../hr/docs/20-hr-employee-journey.md)     | Defines planned journey stages, capabilities, Dataverse model, security model, agent grounding, synthetic-data constraints, and demo path. |
| [HR Solution Sources](../hr/src/solutions/README.md)            | States ownership rules for future unpacked solution source and confirms no solution payload is present.                                    |
