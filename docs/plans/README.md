# Implementation Plans

| Field | Value |
|---|---|
| **Version** | 1.8 |
| **Date** | 2026-10-02 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Active (consolidated from current state) |
| **Scope** | docs/plans |
| **References** | [Documentation Knowledge Architecture Cleanup Implementation Plan](2026-10-02-documentation-knowledge-architecture-cleanup-implementation.md), [Approved Documentation Knowledge Architecture Cleanup Design](../specs/2026-10-02-documentation-knowledge-architecture-cleanup-design.md), [Caldova Branding Migration Implementation Plan](2026-10-01-caldova-branding-migration-implementation.md) |

## Purpose and Authority

This is the canonical repository-wide implementation-plan root. Plans translate reviewed specifications into ordered changes and validation. A plan's metadata and governing specification define its authority; a plan never proves that its steps ran.

## Contains and Does Not Contain

This folder contains implementation plans and superseded plans retained for traceability. It does not contain ideas, design specifications, execution evidence, domain runbooks, or source code.

## Reading Order

Start at the [documentation knowledge map](../README.md), select the governing [specification](../specs/README.md), then use this catalogue to find the plan. Confirm status and prerequisites before execution. Read current evidence or a durable review to determine what actually passed.

## Naming and Lifecycle

Name plans `YYYY-MM-DD-topic-implementation.md`. Include exact files, ordered steps, validation commands, expected outcomes, and completion criteria. A superseded plan remains for history but must not execute; it links to its successor. Status changes update this catalogue in the same pull request.

## Catalogue

| Successor or next stage | Plan | Status | Purpose | Authority |
|---|---|---|---|---|
| [Architecture baseline intake plan](2026-09-17-architecture-baseline-intake-implementation.md) | [Repository Superpowers Integration Implementation Plan](2026-09-15-repository-superpowers-implementation.md) | Approved | Bundles the pinned repository-local Superpowers foundation and issue forms. | Approved implementation authority for the repository-local integration foundation. |
| [Phase 1 governance review](../reviews/2026-09-17-phase-1-governance-github-intake.md) | [Architecture Baseline Intake Implementation Plan](2026-09-17-architecture-baseline-intake-implementation.md) | Draft | Coordinates governed architecture source intake and Tenant 1 validation. | Draft execution sequence; the approved governing design controls its scope. |
| [Phase 1 governance review](../reviews/2026-09-17-phase-1-governance-github-intake.md) | [Governance and GitHub Intake Implementation Plan](2026-09-17-governance-github-intake-implementation.md) | Draft | Implements source intake, documentation governance, and GitHub intake artifacts. | Draft plan; it does not independently authorize repository governance changes. |
| [Phase 3 infrastructure review](../reviews/2026-09-17-phase-3-infrastructure-tenant-bootstrap-intake.md) | [Infrastructure and Tenant Bootstrap Implementation Plan](2026-09-17-infrastructure-tenant-bootstrap-implementation.md) | Draft | Implements the secretless tenant bootstrap and infrastructure validation sequence. | Draft plan; tenant and trust changes remain subject to its gates and attended approval. |
| [Phase 2 intake review](../reviews/2026-09-17-phase-2-product-hr-operating-model-intake.md) | [Product, HR, and Operating Model Intake Implementation Plan](2026-09-17-product-hr-operating-model-intake-implementation.md) | Draft | Imports the product, HR, data, ADR, and operating-model baseline. | Draft intake plan; imported Proposed Baseline content is not promoted by execution. |
| [Tenant 1 configuration review plan](2026-09-28-tenant-1-engineering-platform-configuration-review-implementation.md) | [Azure DevOps and GitHub Single Source of Truth Implementation Plan](2026-09-24-azure-devops-github-single-source-of-truth-implementation.md) | Draft | Closes the Azure Repos content-verification gap identified by the design. | Draft evidence plan; it does not authorize a source-of-truth switch or live mutation. |
| [Phase 4 HR intake review](../reviews/2026-09-24-phase-4-hr-solution-functional-design-intake.md) | [HR Solution Functional Design Intake Implementation Plan](2026-09-24-hr-solution-functional-design-intake-implementation.md) | Draft | Reconciles the Caldova HR functional-design package into the repository baseline. | Draft intake plan; the governing design and recorded collision rules remain authoritative. |
| [Tenant 2 AI Builder model plan](2026-09-25-tenant-2-ai-builder-models-implementation.md) | [Power Platform Solution Foundation Implementation Plan](2026-09-24-power-platform-solution-foundation-implementation.md) | Draft | Builds tested solution synchronization tooling and captures initial solution source. | Draft plan; it authorizes no tenant action without its attended gates. |
| [Tenant trust activation runbook](../../infra/docs/20-tenant-trust-activation-runbook.md) | [Tenant Trust Activation Runbook Implementation Plan](2026-09-24-tenant-trust-activation-runbook-implementation.md) | Draft | Documents attended activation of the existing Tenant 1 trust tooling. | Draft operator plan; the current operational stop remains authoritative. |
| [Azure Boards runbook](../../infra/docs/21-azure-boards-population-runbook.md) | [Azure Boards Population Implementation Plan](2026-09-25-azure-boards-population-implementation.md) | Draft | Implements attended creation of traceable Azure Boards work items from HR ideas. | Draft plan; it does not authorize Board population or synchronization. |
| [Evaluation capture successor](2026-09-29-ai-builder-evaluation-capture-implementation.md) | [Tenant 2 AI Builder Model Sprint Implementation Plan](2026-09-25-tenant-2-ai-builder-models-implementation.md) | Draft | Creates and evaluates two Tenant 2 DEV AI Builder models with portable evidence. | Draft plan; its no-flow capture steps are superseded where the evaluation-capture plan conflicts. |
| [Developer workstation runbook](../../infra/docs/runbooks/01-developer-workstation.md) | [Runbook Foundation and Windows 11 Workstation Implementation Plan](2026-09-26-runbook-foundation-workstation.md) | Proposed Baseline | Defines shared digest-bound contracts and attended workstation readiness. | Proposed only; it does not authorize installation, authentication, or live mutation without approval. |
| [Cloud service foundation runbook](../../infra/docs/runbooks/02-cloud-service-foundation.md) | [Cloud Service Foundation Runbook Implementation Plan](2026-09-26-runbook-cloud-foundation.md) | Proposed Baseline | Defines attended, delegated-user cloud assessment, planning, apply, and verification. | Proposed only; supported writes remain digest-bound, attended, and separately approved. |
| [Customer handover runbook](../../infra/docs/runbooks/03-customer-handover.md) | [Customer Repository Export and Handover Implementation Plan](2026-09-26-runbook-customer-handover.md) | Proposed Baseline | Defines a history-free, digest-bound customer export and handover process. | Proposed only; it authorizes no customer publication or remote repository mutation. |
| [Digest-bound handover successor](2026-09-26-runbook-customer-handover.md) | [Customer Repository Export and Handover Implementation Plan](2026-09-27-customer-repository-export-and-handover-implementation.md) | Draft | Builds tenant-agnostic clean-up and export tooling for customer handover. | Draft plan; it does not authorize external repository creation, publication, or ownership transfer. |
| [Lean implementation successor](2026-09-28-tenant-1-lean-engineering-platform-implementation.md) | [Tenant 1 Engineering Control Plane Foundation Implementation Plan](2026-09-28-tenant-1-engineering-control-plane-foundation-implementation.md) | Superseded | Preserves the stopped broader Tenant 1 control-plane implementation sequence. | No execution authority; Tasks 3-12 must not execute. |
| [Configuration review](../reviews/2026-09-28-tenant-1-engineering-platform-configuration-review.md) | [Tenant 1 Engineering Platform Configuration Review Implementation Plan](2026-09-28-tenant-1-engineering-platform-configuration-review-implementation.md) | Draft | Produces a read-only, evidence-backed Tenant 1 configuration review. | Draft plan governed by the approved read-only design; it authorizes no remediation. |
| [Acceptance review](../reviews/2026-09-28-tenant-1-lean-engineering-platform-acceptance-review.md) | [Tenant 1 Lean Engineering Platform Implementation Plan](2026-09-28-tenant-1-lean-engineering-platform-implementation.md) | Draft | Implements the approved lean Tenant 1 foundation from a clean base. | Draft execution plan; the approved lean design and attended gates govern mutation. |
| [AI Builder evidence contract](../../hr/evidence/ai-builder/README.md) | [AI Builder Evaluation Capture Implementation Plan](2026-09-29-ai-builder-evaluation-capture-implementation.md) | Draft | Replaces the blocked no-flow path with restricted replayable Tenant 2 DEV evaluation capture. | Draft plan; publication is evaluation executability only and tenant changes remain gated. |
| [Brand catalogue](../brand/README.md) | [Caldova Branding Migration Implementation Plan](2026-10-01-caldova-branding-migration-implementation.md) | Draft | Migrates the tracked tree to Caldova branding while preserving technical and immutable evidence. | Draft migration plan governed by the approved branding design and protected-surface checks. |
| [Migration review](../reviews/2026-10-02-documentation-knowledge-architecture-migration-review.md) | [Documentation Knowledge Architecture Cleanup Implementation Plan](2026-10-02-documentation-knowledge-architecture-cleanup-implementation.md) | Draft | Consolidates lifecycle documentation and validates canonical navigation. | Draft migration plan governed by the approved cleanup design; archive and evidence exclusions remain binding. |

## Domain Links

- [Documentation knowledge map](../README.md)
- [Ideas](../ideas/README.md)
- [Specifications](../specs/README.md)
- [Durable reviews](../reviews/README.md)
- [HR domain](../../hr/README.md)
- [Infrastructure domain](../../infra/README.md)
- [Data domain](../../data/README.md)

## Board Synchronization

Implementation plans are not synchronized to Azure Boards by this documentation change. No Board identifier is created or inferred.
