# Phase 2 Operating Model Archive

| Field | Value |
|---|---|
| **Version** | 1.1 |
| **Date** | 2026-10-02 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Active |
| **Scope** | docs/archive/phase-2-operating-model |
| **References** | [Current Documentation Map](../../README.md), [Migration Review](../../reviews/2026-10-02-documentation-knowledge-architecture-migration-review.md) |

## Purpose and Authority

This catalogue is the entry point for the immutable Phase 2 operating-model records. The snapshots are retained byte-for-byte for historical and audit questions; they are not current authority.

## Contains and Does Not Contain

This folder contains exactly the eight archived snapshots listed below and this maintained README. It does not contain active requirements, specifications, plans, or implementation evidence.

## Reading Order

Start at the [archive root](../README.md), identify the historical question below, then read the snapshot and its listed current replacement together. Use the replacement for current decisions.

## Naming and Lifecycle

Snapshot filenames retain their imported identifiers and bytes. They remain `Superseded`; no snapshot is edited, renamed, or promoted. Any new historical set receives a separate archive folder and catalogue.

## Catalogue

| Current replacement | Snapshot | Status | Original purpose | Authority |
|---|---|---|---|---|
| [Platform PRD](../../prd.md), [Solution Design](../../solution-design.md), and [HR Journey and RACI](../../hr-journey-and-raci.md) | [North Star](00-north-star.md) | Superseded | Described the intended platform vision and operating loop. | Immutable historical context only. |
| [Platform PRD](../../prd.md) and the [central idea lifecycle](../../ideas/README.md) | [Product Requirements](01-prd.md) | Superseded | Defined the Phase 2 product purpose, audiences, and operating-model requirements. | Immutable historical context only. |
| [Solution Design](../../solution-design.md) and current [architecture decisions](../../adr/README.md) | [System Design](02-system-design.md) | Superseded | Described the proposed human-agent and delivery architecture. | Immutable historical context only. |
| [Repository-agent portfolio design](../../specs/2026-10-02-hr-frontier-copilot-agent-portfolio-governance-design.md) and [Non-Delegable Work](../../../.github/agent-policy/NON_DELEGABLE_WORK.md) | [Agent Operating Model](03-agent-operating-model.md) | Superseded | Proposed agent roles, responsibilities, and constraints. | Immutable historical context only. |
| [Non-Delegable Work](../../../.github/agent-policy/NON_DELEGABLE_WORK.md) and [HR Journey and RACI](../../hr-journey-and-raci.md) | [HITL Governance](04-hitl-governance.md) | Superseded | Defined the Phase 2 human approval and privacy model. | Immutable historical context only. |
| [Central idea lifecycle](../../ideas/README.md), [specification catalogue](../../specs/README.md), and [implementation plan catalogue](../../plans/README.md) | [Implementation Roadmap](05-implementation-roadmap.md) | Superseded | Proposed the Phase 2 MVP and horizon delivery sequence. | Immutable historical context only. |
| [HR Journey and RACI](../../hr-journey-and-raci.md), [central ideas](../../ideas/README.md), and [HR use-case detail](../../../hr/docs/use-cases/README.md) | [HR Employee Journey](20-hr-employee-journey.md) | Superseded | Proposed the Phase 2 journey scope, capabilities, and data model. | Immutable historical context only. |
| [Current documentation map](../../README.md) | [Microsoft Best Practice Evaluation](90-microsoft-best-practice-evaluation.md) | Superseded | Assessed the Phase 2 design against Microsoft guidance. | Immutable historical assessment; no current replacement evaluation exists. |

## Domain Links

- [Archive root](../README.md)
- [Documentation knowledge map](../../README.md)
- [HR domain](../../../hr/README.md)
- [Infrastructure domain](../../../infra/README.md)

## Board Synchronization

Not applicable. Archived snapshots do not create or infer Azure Boards identifiers.

The snapshots retain their original metadata and internal links. Some of those
links no longer resolve from the archive location. The eight snapshot files,
and only those files, are excluded from live-link validation because their
bytes are pinned by SHA-256 in the migration evidence. This README and all
other archive content remain subject to normal live-link validation.
