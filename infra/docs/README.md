# Infrastructure Documentation

| Field | Value |
|---|---|
| **Version** | 1.3 |
| **Date** | 2026-10-03 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Active |
| **Scope** | Infrastructure documentation |
| **References** | [Infrastructure Domain](../README.md), [Documentation Policy](../../docs/README.md), [Approved Tenant 1 Runbook End-to-End Design](../../docs/specs/2026-10-02-tenant-1-runbook-end-to-end-design.md), [Tenant Lifecycle Core Implementation Plan](../../docs/plans/2026-10-02-tenant-lifecycle-core-implementation.md), [Tenant 1 Lean Engineering Platform Design](../../docs/specs/2026-09-28-tenant-1-lean-engineering-platform-design.md) |

## Purpose and Authority

This folder is the maintained catalogue for infrastructure architecture, configuration guidance, operational boundaries, and runbooks. Each child document governs only its stated scope and metadata status; current reproducible evidence controls claims about deployed state.

## Contains and Does Not Contain

This folder contains infrastructure guidance, active attended procedures, superseded stop notices, and the operational-runbook catalogue, including the implemented provider-neutral coordinate-only lifecycle-core boundary. The umbrella exposes only Assess/Plan/Verify: child runbooks retain manifest approval, WhatIf/Apply, `ShouldProcess`, provider read-back, state adoption, and immutable canonical stage-result ownership. Umbrella `Verify` never invokes a child and publishes only the stage-only projection. It does not contain tenant-private configuration or state, raw operational evidence, credentials, deployment state, or source code. Lifecycle state remains ignored and digest-bound rather than copied into run evidence. The lifecycle-core documentation authorizes no provider procedure.

Plan 1 was implemented with local synthetic tests only; no live cloud, provider, or tenant operation was performed. Plan 1 remains incomplete and Plans 2-6 remain `Draft` and blocked until the coordinate-only correction is merged and then-current `main` is green.

## Reading Order

Start with the [repository knowledge map](../../docs/README.md), then the [Infrastructure domain](../README.md), then this catalogue. Read the approved or proposed design before an operational runbook, and read the runbook's status and stop conditions before executing any command.

## Naming and Lifecycle

Number maintained infrastructure guidance in the intended reading order. Use descriptive kebab-case names. Active procedures remain at their operational path; when an entry point is unsafe or unsupported, retain a `Superseded` stop notice and link the reviewed successor. Status changes update this catalogue in the same pull request.

## Catalogue

| Successor or next stage | Document | Status | Purpose | Authority |
|---|---|---|---|---|
| [Tenant 1 lean platform runbook](24-tenant-1-lean-platform-runbook.md) | [Tenant Setup and Configuration](10-tenant-setup-and-configuration.md) | Proposed Baseline | Defines reviewed tenant metadata, desired state, observed evidence, and terminology boundaries. | Proposed infrastructure guidance; it does not prove tenant state. |
| [Tenant 1 lean platform runbook](24-tenant-1-lean-platform-runbook.md) | [Identity and Access](11-identity-and-access.md) | Proposed Baseline | Defines attended administration and separately approved minimum-access boundaries. | Proposed guidance; current access must be read back before use. |
| [Power Platform solution foundation plan](../../docs/plans/2026-09-24-power-platform-solution-foundation-implementation.md) | [Power Platform Environments and ALM](12-power-platform-environments-and-alm.md) | Proposed Baseline | Defines future DEV-to-TEST-to-PROD solution ALM. | Proposed target; it proves no environment or pipeline exists. |
| [Tenant 1 lean platform runbook](24-tenant-1-lean-platform-runbook.md) | [Azure DevOps Engineering Control Plane](13-azure-devops-engineering-control-plane.md) | Proposed Baseline | Describes the approved single backlog and sole-product-source split. | Proposed implementation guidance under approved repository ADRs. |
| [Tenant 1 lean platform runbook](24-tenant-1-lean-platform-runbook.md) | [GitHub Repository Blueprint](14-github-repository-blueprint.md) | Proposed Baseline | Describes the lean repository governance target. | Proposed implementation guidance; observed repository settings require read-back. |
| [HR use-case catalogue](../../hr/docs/use-cases/README.md) | [Agent and Workload Configuration](15-agent-workload-configuration.md) | Proposed Baseline | Defines future agent, flow, app, grounding, packaging, and release contracts. | Proposed guidance; it authorizes no workload deployment. |
| [Tenant 1 lean platform runbook](24-tenant-1-lean-platform-runbook.md) | [Security, Governance and Compliance](16-security-governance-and-compliance.md) | Proposed Baseline | Defines evidence-first security and compliance controls. | Proposed guidance subject to organizational governance and current evidence. |
| [Tenant 1 lean platform runbook](24-tenant-1-lean-platform-runbook.md) | [Bootstrap and Provisioning](17-bootstrap-and-provisioning.md) | Proposed Baseline | Defines the attended local validation and subscription `what-if` boundary. | Proposed procedure; it authorizes no deployment. |
| [Per-tenant topology ADR](../../docs/adr/0012-per-tenant-github-repository-and-account-topology.md) | [Multi-Tenant Provisioning](18-multi-tenant-provisioning.md) | Proposed Baseline | Defines per-tenant ownership and the Tenant 2 transition exception. | Proposed guidance under the approved per-tenant topology decision. |
| [Tenant 1 lean platform runbook](24-tenant-1-lean-platform-runbook.md) | [Bootstrap Recovery](19-bootstrap-recovery.md) | Proposed Baseline | Defines recovery without bypassing validation or approval. | Proposed recovery guidance; it does not widen operator authority. |
| [Lean platform design](../../docs/specs/2026-09-28-tenant-1-lean-engineering-platform-design.md) | [Tenant Trust Activation Runbook](20-tenant-trust-activation-runbook.md) | Superseded | Preserves the operational stop for dormant unsupported trust activation. | Stop notice; no supported mutation path exists. |
| [Central idea catalogue](../../docs/ideas/README.md) | [Azure Boards Population Runbook](21-azure-boards-population-runbook.md) | Superseded | Preserves the operational stop for deferred Azure Boards population. | Stop notice; Board synchronization remains deferred. |
| [Customer handover runbook](runbooks/03-customer-handover.md) | [Repository Clean-Up Runbook](22-repository-cleanup-runbook.md) | Proposed Baseline | Defines tenant-agnostic repository clean-up boundaries. | Proposed procedure; external publication remains separately approved. |
| [Customer handover runbook](runbooks/03-customer-handover.md) | [Customer Repository Export and Handover Runbook](23-customer-repository-export-and-handover-runbook.md) | Proposed Baseline | Defines reviewed export and handover preparation. | Proposed procedure; it authorizes no external repository mutation. |
| [Acceptance review](../../docs/reviews/2026-09-28-tenant-1-lean-engineering-platform-acceptance-review.md) | [Tenant 1 Lean Platform Runbook](24-tenant-1-lean-platform-runbook.md) | Proposed Baseline | Defines the active attended Tenant 1 sequence and acceptance contract. | Proposed operational sequence under the approved lean design and explicit human gates. |
| [Approved end-to-end runbook design](../../docs/specs/2026-10-02-tenant-1-runbook-end-to-end-design.md) | [Infrastructure Operational Runbooks](runbooks/README.md) | Proposed Baseline | Catalogues shared preview, approval, evidence, read-back, recovery, and the provider-neutral lifecycle-core contract. | Maintained routing for the runbook package; Plan 1 is synthetic core only and each child status controls execution. |

## Domain Links

- [Repository knowledge map](../../docs/README.md)
- [Infrastructure domain](../README.md)
- [Specifications](../../docs/specs/README.md)
- [Implementation plans](../../docs/plans/README.md)
- [Durable reviews](../../docs/reviews/README.md)
- [HR domain](../../hr/README.md)
- [Data domain](../../data/README.md)

## Board Synchronization

Azure Boards population is `Deferred - not synchronized`. No Board identifier is created, inferred, or changed by this catalogue.
