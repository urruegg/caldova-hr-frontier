# Agents

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-17 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Active (consolidated from current state) |
| **Scope** | Repository |
| **References** | [Approved Architecture Baseline Intake Design](../../docs/specs/2026-09-17-architecture-baseline-intake-design.md) |


This folder contains repository-scoped GitHub Copilot custom agent profiles.

Use one focused `*.agent.md` file per role. State the role's purpose, tools, boundaries, and expected handoffs without duplicating repository-wide instructions.

## Available Agents

- [Docs Agent](docs-agent.agent.md): Voice of Knowledge for repository-owned documentation metadata, placement, references, English-language review, and catalogue maintenance; it does not edit code, workflows, infrastructure, or deployment state.
- [Cloud Solution Architect](cloud-solution-architect.agent.md): advisory, read-only architecture reviewer for Microsoft cloud, identity, governance, Power Platform, Azure DevOps, and Azure design decisions; it proposes options and never implements or changes state.
- [UX Designer](ux-designer.agent.md): documentation-focused reviewer for journeys, interaction flows, accessibility, Teams, Copilot, and Power Platform experiences; its edit scope is limited to approved repository-owned design documentation.
