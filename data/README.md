# data — Synthetic Demo Data

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-17 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Data |
| **References** | [HITL Governance](../docs/operating-model/04-hitl-governance.md), [Approved Intake Design](../docs/specs/2026-09-17-architecture-baseline-intake-design.md) |

All demonstration data for Caldova HR Frontier is intended to be synthetic. **Every future record in this repository must be synthetic.**

No seed JSON is imported in Phase 2. The files below are planned formats and examples, not present assets.

| Planned format                | Contents                                           |
| ----------------------------- | -------------------------------------------------- |
| `employees.seed.json`         | 40 synthetic employees across 5 departments        |
| `journeytemplates.seed.json`  | Onboarding, Change and Offboarding templates       |
| `cases.seed.json`             | Representative HR cases per category               |

## Rules

1. **No real person, ever.** Names are generated. Email addresses use a reserved demo domain. No real photographs.
2. **Deliberate exceptions are part of the design.** The planned set includes a late start date, a blocked asset return and an overdue checkpoint, so the showcase can demonstrate exception handling rather than only the happy path.
3. **This folder is in a public repository.** The rules in [HITL Governance](../docs/operating-model/04-hitl-governance.md) apply in full.

## Why this is a top-level folder

The future data set spans both domains — employees and journeys are HR, but the reset procedure is platform work. Making it a sibling of `infra/` and `hr/` avoids implying it belongs to one of them.

## Reset

The future demo must return to a clean state in one governed step. No destructive reset command, seed import, or reset capability exists in Phase 2. When orchestration exists, document the procedure here so it removes only generated journey instances, tasks, checkpoints and cases, then reloads from the approved synthetic seed files.
