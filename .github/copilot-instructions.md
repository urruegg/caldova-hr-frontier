# Repository Copilot Instructions

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-17 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Active (consolidated from current state) |
| **Scope** | Repository |
| **References** | [Approved Architecture Baseline Intake Design](../docs/specs/2026-09-17-architecture-baseline-intake-design.md) |


This repository bundles Superpowers as project skills under `.github/skills/`; do not require contributors to install it globally.

Before any response or action, load `using-superpowers` from `.github/skills/using-superpowers/SKILL.md`, check for other applicable skills, and follow the applicable workflow. Repository and user instructions take precedence if they conflict with a vendored skill.

All maintained repository documentation is written in English and follows [the documentation policy](../docs/README.md). Use [.github/agents/docs-agent.agent.md](agents/docs-agent.agent.md) as the documentation policy owner. Preserve the documented exclusions and never edit vendored Superpowers content to enforce repository metadata.
