# Architecture Decision Records

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-17 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Active (consolidated from current state) |
| **Scope** | docs/adr |
| **References** | [Approved Architecture Baseline Intake Design](../specs/2026-09-17-architecture-baseline-intake-design.md) |


This folder records significant architecture decisions, their context, considered options, and consequences.

Use sequentially numbered Markdown files such as `0001-use-example-platform.md`. Accepted records are immutable; supersede them with a new record that links back to the earlier decision.

## Proposed Baseline Candidates

The following ADRs are imported as Proposed Baseline candidates for attended review. They are not accepted repository decisions until a later review explicitly approves them. Phase 2 intake status is recorded in [Phase 2 Product HR Operating Model Intake](../reviews/2026-09-17-phase-2-product-hr-operating-model-intake.md).

| Candidate | Topic |
|---|---|
| [ADR-0001: Azure DevOps as the Engineering Control Plane, GitHub as the Digital Factory](0001-azure-devops-as-engineering-control-plane.md) | Proposed split between Azure Boards governance and GitHub delivery surfaces. |
| [ADR-0002: GitHub-First Bootstrap, and the Role of Azure Repos](0002-github-first-bootstrap-and-the-role-of-azure-repos.md) | Proposed public GitHub origin with private Azure Repos configuration boundary. |
| [ADR-0003: Bicep and PowerShell for Infrastructure as Code](0003-bicep-and-powershell-for-infrastructure-as-code.md) | Proposed infrastructure toolchain and future `infra/` ownership model. |
| [ADR-0004: Domain Solution Architecture, Naming and Publisher](0004-domain-solution-architecture-and-publisher.md) | Proposed Power Platform solution layering, naming, and publisher baseline. |
