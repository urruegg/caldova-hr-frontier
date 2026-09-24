# `.github/agents/` — agent definitions for repository work

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-24 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Repository |
| **References** | [HR Solution Functional Design Intake](../../docs/specs/2026-09-24-hr-solution-functional-design-intake-design.md) |

**Purpose.** Definitions for agents that work *on this repository* — drafting, reviewing and checking documents. Not the HR agents GF builds; those are described in [`AGENTS.md`](../../AGENTS.md) and specified in [`hr/`](../../hr/README.md).

**Not empty.** This folder already contains repository-scoped GitHub Copilot custom agent profiles, in addition to the shared instructions in [`copilot-instructions.md`](../copilot-instructions.md) that apply to all repository work:

## Available Agents

- [Docs Agent](docs-agent.agent.md): Voice of Knowledge for repository-owned documentation metadata, placement, references, English-language review, and catalogue maintenance; it does not edit code, workflows, infrastructure, or deployment state.
- [Cloud Solution Architect](cloud-solution-architect.agent.md): advisory, read-only architecture reviewer for Microsoft cloud, identity, governance, Power Platform, Azure DevOps, and Azure design decisions; it proposes options and never implements or changes state.
- [UX Designer](ux-designer.agent.md): documentation-focused reviewer for journeys, interaction flows, accessibility, Teams, Copilot, and Power Platform experiences; its edit scope is limited to approved repository-owned design documentation.

## Candidates worth defining

| Agent | Would do |
|---|---|
| **Design reviewer** | Check a proposed change against the Accepted ADRs and the platform requirements, and report contradictions rather than reconciling them |
| **Use-case intake** | Turn an intake issue into a draft idea document in the house format, with the platform-fit assessment left honest — including *does this need an agent at all* |
| **Consistency checker** | Verify identifiers, statuses and links across documents after a change |

Whatever is added here inherits `copilot-instructions.md` rather than restating it — particularly the evidence rules and the six load-bearing claims.
