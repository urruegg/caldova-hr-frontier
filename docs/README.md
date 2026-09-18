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