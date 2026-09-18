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

## Operating Model

The operating-model set is imported as Proposed Baseline content: it describes the intended future operating model and does not by itself prove tenant configuration, deployed agents, Azure DevOps objects, pipelines, environments, Power Platform solutions, Azure resources, or Teams structures exist. Phase 2 intake status is recorded in [Phase 2 Product HR Operating Model Intake](reviews/2026-09-17-phase-2-product-hr-operating-model-intake.md).

| Document | Purpose |
|---|---|
| [North Star](operating-model/00-north-star.md) | Defines the cross-cutting ambition, loop, and operating principles for Caldova HR Frontier. |
| [PRD](operating-model/01-prd.md) | Captures the product purpose, audiences, capabilities, requirements, KPIs, risks, and MVP acceptance criteria. |
| [System Design](operating-model/02-system-design.md) | Describes the intended control planes, data flows, repository structure, integration patterns, and security model. |
| [Agent Operating Model](operating-model/03-agent-operating-model.md) | Defines planned agent roles, principles, outputs, handoffs, and publication standards. |
| [HITL Governance](operating-model/04-hitl-governance.md) | Sets the human-in-the-loop approval, redaction, audit, escalation, and standing prohibition rules. |
| [Implementation Roadmap](operating-model/05-implementation-roadmap.md) | Lays out the MVP and Horizon 2 phases, backlog, sequencing, and delivery constraints. |