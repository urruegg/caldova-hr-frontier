# GF Grounded Agent Identity Kit - Idea

| Field | Value |
|---|---|
| **Version** | 0.1 |
| **Date** | 2026-10-29 |
| **Author** | Copilot |
| **Status** | Draft |
| **Scope** | GF handover: grounded identity for planned and built Copilot Studio runtime agents |
| **References** | [Kit guide](../brand/gf-agent-identity/README.md), [Sprint](../plans/2026-10-29-gf-agent-identity-kit-sprint.md), [Specification](../specs/2026-10-29-gf-agent-identity-kit-design.md), [Provisional implementation plan](../plans/2026-10-29-gf-agent-identity-kit-implementation.md), [Package index](../README.md#gf-draft-packages) |

## Status and source

The supplied GF HR agent identity package v1.0.0, dated 2026-10-28, has been curated into the existing brand folder. The repository owner reports written GF approval to adapt it for the agents; the approval reference was not supplied. The original source's proposal status and N-1 through N-6/G5 questions remain visible.

The eighth handover package establishes identity adoption, not a new HR runtime MVP. It neither approves all 37 source catalogue identities for implementation nor replaces the seven existing package scopes.

## Problem and expected value

Agent names, colours, icons and environment markers can drift between designs, maker configuration, exported source and Teams/Microsoft 365 publication. Consistent identities help employees recognize the responsible process area and avoid confusing test builds with production.

The proposed benefit is fewer identity inconsistencies and clearer handover/deployment checks. No user-recognition baseline, numeric saving or completed tenant rollout is claimed.

## Confirmed idea

| Canvas element | Adopted design |
|---|---|
| Audience | GF process owners, makers, release engineers and handover reviewers; end users see the resulting runtime identities |
| Source | Versioned kit configuration, per-agent identity JSON, palette and supplied icons; exact bytes recorded in the intake manifest |
| Current mappings | Policy D3-A01, Recruiting D1-A01, HR Operations D2-A01, new ESS-equivalent D3-A02 |
| Environment presentation | Source DEV/TEST names and marked icons; clean PROD name/icon; technical identifiers remain environment-neutral |
| Repository guidance | Required grounded reference for GF runtime designs/source; future unmapped agents need reviewed identity extension |
| Deterministic work | Intake validation now; fail-closed source stamping and deployment read-back only after supported-format proof and separate approval |
| Human responsibility | GF owners decide naming/prefix/solution questions, brand/trademark use and release acceptance |

The four mappings were explicitly approved in conversation. Source descriptions, `ess` kind, old later-wave labels and factory-role names are not behavioral/platform authority. The current GitHub-harness decisions and safety/write gates remain unchanged.

## Intake and boundaries

The curated kit preserves 466 source files with hashes, including 442 assets/configuration/visual references and 24 inactive source-reference files. Original automation/instructions are `.txt` references, not installed scripts or pipelines.

Keep the Caldova demo theme and its logo restriction intact. Supplied GF trademark assets/notices stay with authorized GF handover; source inclusion is not unrestricted public-publication permission. Repository-working Copilot profiles and technical packages are not renamed as Copilot Studio agents.

## Decisions and next review

Confirm the formal approval reference, unresolved publisher/solution/naming-owner questions, final published descriptions and actual GitHub-harness export/manifest fields. Resolve environment-stamping differences against the release-artifact policy before enabling pipeline behavior.

The legacy anonymization guard already rejected GF content before this intake. Do not bypass it with fabricated evidence exceptions; a narrow reviewed customer-identity scope decision is a merge-readiness requirement.

Use the [sprint](../plans/2026-10-29-gf-agent-identity-kit-sprint.md) and [specification](../specs/2026-10-29-gf-agent-identity-kit-design.md) for intake evidence, Mermaid flow, adoption rules and implementation gates. The detailed implementation plan is a supporting artifact. No commit, push, source stamping, live rename, icon upload, blueprint rewrite or customer transfer is performed by drafting this package.

## Board synchronization

Deferred - not synchronized.
