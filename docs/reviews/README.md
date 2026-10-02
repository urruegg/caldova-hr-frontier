# Reviews

| Field | Value |
|---|---|
| **Version** | 1.4 |
| **Date** | 2026-10-02 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Active (consolidated from current state) |
| **Scope** | docs/reviews |
| **References** | [Tenant 1 Engineering Platform Configuration Review](2026-09-28-tenant-1-engineering-platform-configuration-review.md), [Tenant 1 Lean Engineering Platform Acceptance Review](2026-09-28-tenant-1-lean-engineering-platform-acceptance-review.md) |

## Purpose and Authority

This folder owns durable architecture, security, readiness, migration, and implementation review records. A review governs only the disposition and evidence in its stated scope; current reproducible evidence controls claims about implemented state.

## Contains and Does Not Contain

This folder contains maintained review records and their nearest evidence packages. It does not contain routine pull request comments, implementation plans, design specifications, source inventories used as active authority, or generated operational output outside an approved evidence package.

## Reading Order

Start at the [documentation knowledge map](../README.md), identify the governing specification or plan, then select the review below. Read the review before its evidence package so the evidence is interpreted against the recorded controls and disposition.

## Naming and Lifecycle

Name durable reviews `YYYY-MM-DD-topic-review.md` or use the established intake name when preserving a governed sequence. Record findings by severity, evidence, owner, and disposition. Status changes and successor reviews update this catalogue in the same pull request. Routine pull request comments remain on the pull request unless a durable record is required.

## Catalogue

| Evidence or next stage | Review | Status | Purpose | Authority |
|---|---|---|---|---|
| [Governance intake plan](../plans/2026-09-17-governance-github-intake-implementation.md) | [Phase 1 Governance and GitHub Intake](2026-09-17-phase-1-governance-github-intake.md) | Proposed Baseline | Records the Phase 1 governance and GitHub intake assessment. | Proposed review record for its intake scope; it does not prove later governance state. |
| [Current documentation map](../README.md) | [Phase 2 Product, HR, and Operating Model Intake](2026-09-17-phase-2-product-hr-operating-model-intake.md) | Approved | Records acceptance and disposition of the Phase 2 product and HR operating-model intake. | Approved intake review for the imported Phase 2 package; current authority is routed through maintained documents and the archive. |
| [Infrastructure documentation](../../infra/docs/README.md) | [Phase 3 Infrastructure and Tenant Bootstrap Intake](2026-09-17-phase-3-infrastructure-tenant-bootstrap-intake.md) | Approved | Records acceptance and disposition of the infrastructure and tenant-bootstrap intake. | Approved intake review for its stated source package and controls. |
| [HR use-case detail](../../hr/docs/use-cases/README.md) | [Phase 4 HR Solution Functional Design Intake](2026-09-24-phase-4-hr-solution-functional-design-intake.md) | Draft | Records reconciliation of the HR functional-design package. | Draft review; the governing design and child metadata determine current authority. |
| [Manifest](evidence/2026-09-28-tenant-1-engineering-platform/evidence-manifest.json), [control results](evidence/2026-09-28-tenant-1-engineering-platform/test-results.json), and six sanitized screenshots | [Tenant 1 Engineering Platform Configuration Review](2026-09-28-tenant-1-engineering-platform-configuration-review.md) | Active | Reviews Tenant 1 GitHub, Azure DevOps, Azure, Entra, and Power Platform control planes. | Active evidence-backed review for the observed point in time; it authorizes no remediation. |
| [Tenant 1 lean platform runbook](../../infra/docs/24-tenant-1-lean-platform-runbook.md) | [Tenant 1 Lean Engineering Platform Acceptance Review](2026-09-28-tenant-1-lean-engineering-platform-acceptance-review.md) | Draft | Defines ordered Tenant 1 lean-platform acceptance controls. | Draft acceptance record; every outcome remains `Not Run` until current sanitized read-back exists. |
| [Baseline manifest](evidence/2026-10-02-documentation-knowledge-architecture/migration-baseline.json) | [Documentation Knowledge Architecture Migration Review](2026-10-02-documentation-knowledge-architecture-migration-review.md) | Active | Records path, hash, reference, catalogue, and validation migration evidence. | Active migration evidence; the lifecycle and domain catalogues remain discovery authority. |

## Domain Links

- [Documentation knowledge map](../README.md)
- [Specifications](../specs/README.md)
- [Implementation plans](../plans/README.md)
- [Archive](../archive/README.md)
- [HR domain](../../hr/README.md)
- [Infrastructure domain](../../infra/README.md)

## Board Synchronization

Not applicable. Reviews do not create or infer Azure Boards identifiers.
