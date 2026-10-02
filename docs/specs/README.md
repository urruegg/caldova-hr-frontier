# Specifications

| Field | Value |
|---|---|
| **Version** | 1.7 |
| **Date** | 2026-10-02 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Active (consolidated from current state) |
| **Scope** | docs/specs |
| **References** | [Documentation Policy](../README.md), [Documentation Knowledge Architecture Cleanup Design](2026-10-02-documentation-knowledge-architecture-cleanup-design.md), [HR Frontier Copilot Repository-Agent Portfolio Governance Design](2026-10-02-hr-frontier-copilot-agent-portfolio-governance-design.md) |

## Purpose and Authority

This is the canonical repository-wide specification root. It contains designs and behavioral specifications whose metadata states whether they are approved, active, proposed, draft, or superseded. The migrated Superpowers specifications are consolidated here rather than establishing a second specification root. An Approved specification is implementation authority only for its stated scope; a superseded specification is historical context.

The artifact's metadata status is authoritative. This README routes readers and does not restate or override a specification.

## Contains and Does Not Contain

This folder contains repository-wide and domain-scoped specifications that define outcomes, architecture, constraints, validation, risks, and non-goals before implementation planning.

It does not contain ideas, implementation plans, implementation evidence, domain runbooks, generated evidence, or source code. Ideas belong in [`docs/ideas/`](../ideas/README.md), plans in [`docs/plans/`](../plans/README.md), durable reviews in [`docs/reviews/`](../reviews/README.md), and domain detail below the owning domain.

## Reading Order

Read [the documentation knowledge map](../README.md), then this catalogue, then the selected specification and its explicit references. Follow the owning domain README for detailed domain authority:

- [HR](../../hr/README.md)
- [Infrastructure](../../infra/README.md)
- [Data](../../data/README.md)

Read an implementation plan only after confirming that its governing specification is approved and the plan has not been superseded.

## Naming and Lifecycle

Name specifications `YYYY-MM-DD-topic-design.md`. Capture scope, architecture, constraints, validation, risks, dependencies, and explicit non-goals.

A specification is created from a selected idea or approved problem. It precedes its implementation plan, remains after implementation, and links to a successor when superseded. Status changes update this catalogue in the same pull request.

## Catalogue

| Successor or next stage | Specification | Status | Purpose | Authority |
|---|---|---|---|---|
| [Implementation plan](../plans/2026-09-15-repository-superpowers-implementation.md) | [`2026-09-15-repository-superpowers-design.md`](2026-09-15-repository-superpowers-design.md) | Approved | Defines the pinned repository-local Superpowers integration. | Governs the integration foundation; vendored content remains excluded from repository metadata policy. |
| [Implementation plan](../plans/2026-09-17-architecture-baseline-intake-implementation.md) | [`2026-09-17-architecture-baseline-intake-design.md`](2026-09-17-architecture-baseline-intake-design.md) | Approved | Defines governed source intake and Tenant 1 bootstrap boundaries. | Governs the architecture-baseline intake scope recorded by its reviews. |
| [Implementation plan](../plans/2026-09-24-azure-devops-github-single-source-of-truth-implementation.md) | [`2026-09-24-azure-devops-github-single-source-of-truth-design.md`](2026-09-24-azure-devops-github-single-source-of-truth-design.md) | Proposed Baseline | Defines the intended GitHub source and Azure DevOps control-plane connection. | Proposed only; it authorizes no live connection or mutation. |
| [HR control-plane application](../../hr/src/apps/hr-control-plane/README.md) | [`2026-09-24-hr-control-plane-code-app-wireframe-design.md`](2026-09-24-hr-control-plane-code-app-wireframe-design.md) | Active | Defines the static HR control-plane Code App wireframe boundary. | Active design for the wireframe scope; it does not authorize data or functional behavior. |
| [Implementation plan](../plans/2026-09-24-hr-solution-functional-design-intake-implementation.md) | [`2026-09-24-hr-solution-functional-design-intake-design.md`](2026-09-24-hr-solution-functional-design-intake-design.md) | Draft | Records the HR functional-design intake and collision rules. | Draft intake record; not approval of every imported recommendation. |
| [Implementation plan](../plans/2026-09-24-power-platform-solution-foundation-implementation.md) | [`2026-09-24-power-platform-solution-foundation-design.md`](2026-09-24-power-platform-solution-foundation-design.md) | Draft | Defines the HR Power Platform solution-source foundation. | Draft; it does not prove or authorize tenant implementation beyond its evidence. |
| [Operational stop notice](../../infra/docs/20-tenant-trust-activation-runbook.md) | [`2026-09-24-tenant-trust-activation-design.md`](2026-09-24-tenant-trust-activation-design.md) | Proposed Baseline | Defines the proposed attended Tenant 1 trust-activation procedure. | Proposed only; the current operational path remains stopped unless separately reviewed. |
| [Azure Boards runbook](../../infra/docs/21-azure-boards-population-runbook.md) | [`2026-09-25-azure-boards-population-design.md`](2026-09-25-azure-boards-population-design.md) | Proposed Baseline | Defines a proposed mapping of HR ideas to Azure Boards. | Proposed only; it does not authorize Board creation or synchronization. |
| [Implementation plan](../plans/2026-09-25-tenant-2-ai-builder-models-implementation.md) | [`2026-09-25-tenant-2-ai-builder-models-design.md`](2026-09-25-tenant-2-ai-builder-models-design.md) | Draft | Defines two Tenant 2 DEV AI Builder document-processing models and their shared 17-field evaluation contract. | Draft design; it does not authorize Tenant 1, TEST, PROD, Workday, or automated-write changes. |
| [Operational runbooks](../../infra/docs/runbooks/README.md) | [`2026-09-26-operational-runbooks-design.md`](2026-09-26-operational-runbooks-design.md) | Proposed Baseline | Defines a layered, attended Windows runbook kit. | Proposed only; individual current runbooks and stop notices govern operation. |
| [Implementation plan](../plans/2026-09-27-customer-repository-export-and-handover-implementation.md) | [`2026-09-27-customer-repository-export-and-handover-design.md`](2026-09-27-customer-repository-export-and-handover-design.md) | Proposed Baseline | Defines the proposed customer repository export and handover sequence. | Proposed only; it authorizes no external repository creation or publication. |
| [Implementation plan](../plans/2026-09-28-tenant-1-engineering-platform-configuration-review-implementation.md) | [`2026-09-28-tenant-1-engineering-platform-configuration-review-design.md`](2026-09-28-tenant-1-engineering-platform-configuration-review-design.md) | Approved | Defines the read-only Tenant 1 engineering-platform evidence review. | Authorizes read-only review, not configuration change. |
| [Approved lean successor](2026-09-28-tenant-1-lean-engineering-platform-design.md) | [`2026-09-28-tenant-1-engineering-platform-remediation-design.md`](2026-09-28-tenant-1-engineering-platform-remediation-design.md) | Superseded | Preserves the broader historical remediation target. | No current implementation authority. |
| [Implementation plan](../plans/2026-09-28-tenant-1-lean-engineering-platform-implementation.md) | [`2026-09-28-tenant-1-lean-engineering-platform-design.md`](2026-09-28-tenant-1-lean-engineering-platform-design.md) | Approved | Defines the secure, attended Tenant 1 lean foundation. | Governs the selected lean target and explicitly deferred controls. |
| [Implementation plan](../plans/2026-09-29-ai-builder-evaluation-capture-implementation.md) | [`2026-09-29-ai-builder-evaluation-capture-design.md`](2026-09-29-ai-builder-evaluation-capture-design.md) | Draft | Defines the restricted Tenant 2 DEV flow needed to capture replayable AI Builder evaluation evidence. | Draft addendum; its own authority statement does not authorize tenant changes. |
| [Implementation plan](../plans/2026-10-01-caldova-branding-migration-implementation.md) | [`2026-10-01-caldova-branding-migration-design.md`](2026-10-01-caldova-branding-migration-design.md) | Approved | Defines the current-tree migration to Caldova branding. | Governs branding migration without rewriting history or immutable evidence. |
| [Implementation-plan entry criteria](2026-10-02-documentation-knowledge-architecture-cleanup-design.md#15-dependencies-and-entry-criteria) | [`2026-10-02-documentation-knowledge-architecture-cleanup-design.md`](2026-10-02-documentation-knowledge-architecture-cleanup-design.md) | Approved | Defines canonical documentation lifecycle, navigation, migration, archive, and validation. | Governs the documentation cleanup and is prerequisite to repository-agent implementation. |
| [Documentation-cleanup prerequisite](2026-10-02-documentation-knowledge-architecture-cleanup-design.md) | [`2026-10-02-hr-frontier-copilot-agent-portfolio-governance-design.md`](2026-10-02-hr-frontier-copilot-agent-portfolio-governance-design.md) | Approved | Defines the twelve-agent repository portfolio, action tiers, delivery handoffs, and acceptance evidence. | Governs future repository-agent implementation after documentation cleanup acceptance. |

## Domain Links

- [Documentation knowledge map](../README.md)
- [Ideas](../ideas/README.md)
- [Implementation plans](../plans/README.md)
- [Durable reviews](../reviews/README.md)
- [HR domain](../../hr/README.md)
- [Infrastructure domain](../../infra/README.md)
- [Data domain](../../data/README.md)

## Board Synchronization

Specifications are not synchronized to Azure Boards by this documentation change. No current Board identifier is required, preserved, created, or modified. Any future link must be verified before it is added.
