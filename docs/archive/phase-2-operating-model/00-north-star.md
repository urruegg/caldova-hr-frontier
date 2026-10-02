# North Star: Caldova HR Frontier Operating System

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-17 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Superseded |
| **Scope** | Cross-cutting (all solution domains) |
| **References** | [Approved Intake Design](../specs/2026-09-17-architecture-baseline-intake-design.md), [Implementation Roadmap](./05-implementation-roadmap.md) |

> **Superseded.** This document is retained for history. The current product and solution design is [`prd.md`](../prd.md), [`solution-design.md`](../solution-design.md), and [`hr-journey-and-raci.md`](../hr-journey-and-raci.md), reconciled through the [Phase 4 HR Solution Functional Design Intake](../reviews/2026-09-24-phase-4-hr-solution-functional-design-intake.md).

Proposed Baseline orientation: This document describes intended future operating-model behavior. It does not prove that agents, Azure DevOps objects, pipelines, environments, Power Platform solutions, Azure resources, Teams structures, Work IQ configuration, or tenant controls currently exist.

## 1. Starting Position

Caldova HR Frontier is intended to be built on a dedicated Microsoft demo tenant in which the following strategic platforms would be operated as one connected system rather than as isolated tools:

- **Microsoft Teams** — the employee and organisation workspace.
- **Microsoft 365 Copilot** — the productivity-adjacent AI layer for every employee, manager and HR practitioner.
- **Work IQ** — the interaction layer between people and Microsoft 365 Copilot build agents.
- **Microsoft Copilot Studio** — the authoring surface for HR-specific conversational and autonomous agents.
- **Power Platform and Dataverse** — the operational platform for HR processes, case data and employee lifecycle records.
- **Azure DevOps** — the engineering control plane for work items, delivery planning, pipelines and release approvals.
- **GitHub** — the public digital factory for requirements-as-code, source, automation, agent definitions and releases.
- **GitHub Copilot CLI** — the technical implementation layer operated from a dedicated build identity.

The strategic ambition is a **closed feedback loop** in which insight from the organisation is converted automatically into product improvements, process improvements and measurable outcomes across the whole employee journey.

## 2. North Star

> **Every relevant interaction with an employee, a manager, an HR practitioner or a system automatically improves our HR service, our product and our processes.**

Expressed technically:

> **Caldova HR Frontier is a human-led, agent-operated HR service platform in which Work IQ governs the human–agent interaction, Azure DevOps governs the engineering flow, GitHub orchestrates the digital build, and Dataverse represents operational truth across the employee journey.**

## 3. Operating Loop

```text
Insight
  -> Decision
    -> Delivery
      -> Outcome
        -> Learning
          -> Insight
```

### Insight

Insight originates from:

- Onboarding and offboarding experiences
- Manager and employee check-ins
- HR service desk cases and ticket patterns
- Teams discussions and HR community channels
- Sprint reviews and showcase feedback
- Product and agent usage telemetry
- Employee listening and pulse feedback
- Policy, compliance and works-council input
- Recruiting and hiring-manager feedback

### Decision

Human roles decide:

- What is relevant?
- What is prioritised?
- What may be automated?
- What requires review?
- What enters the next sprint?
- What is refused on policy, privacy or fairness grounds?

### Delivery

Azure DevOps governs the flow of work; GitHub orchestrates the build:

- Epics, Features, User Stories, Bugs (Azure Boards)
- Iterations, Delivery Plans, Environments and approval gates (Azure DevOps)
- Branches, Pull Requests, GitHub Actions, Releases (GitHub)
- GitHub Copilot CLI build tasks and agent definitions
- Power Platform solution export, unpack, pack and import

### Outcome

Impact is measured through:

- Time-to-productivity for new joiners
- Onboarding and offboarding task completion rates
- HR case deflection and resolution time
- Employee and manager experience signals
- Process quality and compliance exceptions
- Release adoption of shipped HR capabilities
- Operational KPIs held in Dataverse and Power Platform

## 4. Frontier Firm Principles

### Human-led

People set direction, standards, priorities and approvals. No agent decides an employment-affecting matter.

### Agent-operated

Agents perform analysis, structuring, recommendation, drafting, status reporting and recurring operational work.

### HITL-controlled

Critical steps stay under explicit human control, with named owners and recorded decisions.

### DevOps-governed

All delivery-relevant work is planned, tracked, approved and released through Azure DevOps so that flow, capacity and gates are visible.

### GitHub-driven

All implementation-relevant artefacts are versioned, reviewable and reproducible in the public GitHub repository.

### Dataverse-backed

Operational truth and impact measurement are intended to live in Dataverse and the Power Platform.

### Teams-visible

Delivery status is intended to stay visible to employees in Teams, in business language.

### Privacy-by-design

The employee journey handles personal data end to end. Minimisation, purpose limitation and redaction are design constraints, not afterthoughts.

## 5. Target Picture

```text
Employees / Candidates / Managers
   |
   v
HR Moments: Hire / Onboard / Enable / Change / Offboard
   |
   v
Work IQ Interaction Layer
   |
   v
Microsoft 365 Copilot + Copilot Studio Agent Mesh
   |
   v
Azure DevOps Engineering Control Plane
   |
   v
GitHub Digital Factory (public repository + Copilot CLI)
   |
   v
Power Platform Deployment: DEV -> TEST -> PROD
   |
   v
Dataverse / Power Platform Outcome Measurement
   |
   v
Teams Transparency Loop
```

## 6. Strategic Benefit

- Less information loss between HR operations, product and engineering.
- Faster conversion of employee and manager feedback into sprint-ready requirements.
- Higher transparency for the organisation about what is being built and why.
- Reusable agent roles for intake, discovery, delivery, release, outcome and governance.
- Controlled automation with human-in-the-loop at every employment-affecting decision.
- A measurable link between feedback, delivery and impact across the employee journey.
- A reproducible showcase: the entire operating system is described in a public repository and is intended to be rebuildable from source.

## 7. Showcase Objective

Caldova HR Frontier is a **demonstrable reference implementation**. Beyond the HR outcome, it must prove that:

1. A frontier operating model can be expressed entirely as versioned markdown and code.
2. An external build identity using GitHub Copilot CLI can deliver into a governed Microsoft tenant without weakening that tenant's controls.
3. Azure DevOps and GitHub can be combined — planning and approval in Azure DevOps, build and automation in GitHub — without duplicate backlogs.
4. Microsoft 365 Copilot, Microsoft 365 Agents, Copilot Studio, Power Automate and Power Apps can be delivered through one ALM chain.
