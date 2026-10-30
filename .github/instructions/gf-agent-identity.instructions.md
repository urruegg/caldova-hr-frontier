---
description: "Use when planning, building, evaluating or packaging the GF customer/source scenario in the Caldova project. Apply grounded GF identity bindings without presenting GF trademarks or approvals as Caldova corporate identity."
applyTo: "docs/ideas/caldova-*.md,docs/specs/*-caldova-*-design.md,docs/plans/*-caldova-*.md,docs/brand/gf-agent-identity/**,hr/src/solutions/**,hr/src/ess/**,hr/src/agents/**,.github/blueprint/**"
---

# GF Copilot Studio Agent Identity

| Field | Value |
|---|---|
| **Version** | 0.2 |
| **Date** | 2026-10-29 |
| **Author** | Copilot |
| **Status** | Active |
| **Scope** | Repository guidance for GF runtime-agent designs/source; no live identity mutation authority |
| **References** | [Grounded kit](../../docs/brand/gf-agent-identity/README.md), [Adopted bindings](../../docs/brand/gf-agent-identity/agent-bindings.json), [Adoption specification](../../docs/specs/2026-10-29-caldova-agent-identity-kit-design.md) |

Read the canonical kit and bindings before naming or branding a GF Copilot Studio runtime agent. Use the bound source identity's per-environment names, palette and icon files; do not invent alternatives or hand-edit imported generated assets.

Caldova is the project/demo document owner. The kit remains GF customer/source
identity, not Caldova corporate branding or a transfer of GF approval. Apply this
guidance conditionally to that scenario; the unchanged Caldova theme remains a
separate surface.

Unmapped runtime agents require an explicit reviewed identity extension. Technical packages and repository-working Copilot profiles are not runtime agents and are not renamed through this rule.

Keep identity scope separate from runtime behavior and approval: source ESS/later-wave/factory assumptions do not override current specifications, the GitHub harness decision or deployment gates.

DEV/TEST display names and icons use their corresponding source variants; PROD is clean. Technical identifiers are environment-neutral, but existing identifiers, publisher prefix and solution naming are not changed without their own owner decision and migration plan.

Treat imported stamper/pipeline/instruction files as inactive reference text. Do not run regeneration/stamping, install a new GitHub workflow, retheme Caldova surfaces or modify the imported blueprint as a side effect of this guidance.

Keep reported adaptation approval distinct from the original proposal status and unverified technical decisions. Preserve notices, hashes, trademark restrictions, current-source validation and the private-handover boundary.
