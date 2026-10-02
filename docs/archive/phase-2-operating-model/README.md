# Phase 2 Operating Model Archive

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-10-02 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Superseded |
| **Scope** | docs/archive/phase-2-operating-model |
| **References** | [Current Documentation Map](../../README.md), [Migration Review](../../reviews/2026-10-02-documentation-knowledge-architecture-migration-review.md) |

This catalogue is the entry point for the immutable Phase 2 operating-model
records. The snapshots are retained byte-for-byte for historical and audit
questions; they are not current authority.

| Snapshot | Original purpose | Current replacement |
|---|---|---|
| [North Star](00-north-star.md) | Described the intended platform vision and operating loop. | [Platform PRD](../../prd.md), [Solution Design](../../solution-design.md), and [HR Journey and RACI](../../hr-journey-and-raci.md) |
| [Product Requirements](01-prd.md) | Defined the Phase 2 product purpose, audiences, and operating-model requirements. | [Platform PRD](../../prd.md) and the [central idea lifecycle](../../ideas/README.md) |
| [System Design](02-system-design.md) | Described the proposed human-agent and delivery architecture. | [Solution Design](../../solution-design.md) and current [architecture decisions](../../adr/README.md) |
| [Agent Operating Model](03-agent-operating-model.md) | Proposed agent roles, responsibilities, and constraints. | [HR Frontier Copilot Agent Portfolio Governance Design](../../specs/2026-10-02-hr-frontier-copilot-agent-portfolio-governance-design.md) and [Non-Delegable Work](../../../.github/agent-policy/NON_DELEGABLE_WORK.md) |
| [HITL Governance](04-hitl-governance.md) | Defined the Phase 2 human approval and privacy model. | [Non-Delegable Work](../../../.github/agent-policy/NON_DELEGABLE_WORK.md) and [HR Journey and RACI](../../hr-journey-and-raci.md) |
| [Implementation Roadmap](05-implementation-roadmap.md) | Proposed the Phase 2 MVP and horizon delivery sequence. | [Central idea lifecycle](../../ideas/README.md), [specification catalogue](../../specs/README.md), and [implementation plan catalogue](../../plans/README.md) |
| [Microsoft Best Practice Evaluation](90-microsoft-best-practice-evaluation.md) | Assessed the Phase 2 design against Microsoft guidance. | No current replacement evaluation exists; use the [current documentation map](../../README.md) and treat this assessment as historical only. |
| [HR Employee Journey](20-hr-employee-journey.md) | Proposed the Phase 2 journey scope, capabilities, and data model. | [HR Journey and RACI](../../hr-journey-and-raci.md), [central ideas](../../ideas/README.md), and [HR use-case detail](../../../hr/docs/use-cases/README.md) |

The snapshots retain their original metadata and internal links. Some of those
links no longer resolve from the archive location. The eight snapshot files,
and only those files, are excluded from live-link validation because their
bytes are pinned by SHA-256 in the migration evidence. This README and all
other archive content remain subject to normal live-link validation.
