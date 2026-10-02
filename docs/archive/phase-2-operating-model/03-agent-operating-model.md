# Agent Operating Model: Caldova HR Frontier

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-17 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Superseded |
| **Scope** | Cross-cutting (all solution domains) |
| **References** | [Approved Intake Design](../specs/2026-09-17-architecture-baseline-intake-design.md), [System Design](./02-system-design.md) |

> **Superseded.** This document is retained for history. The current product and solution design is [`prd.md`](../prd.md), [`solution-design.md`](../solution-design.md), and [`hr-journey-and-raci.md`](../hr-journey-and-raci.md), reconciled through the [Phase 4 HR Solution Functional Design Intake](../reviews/2026-09-24-phase-4-hr-solution-functional-design-intake.md).

Proposed Baseline orientation: This document describes intended future operating-model behavior. It does not prove that agents, Azure DevOps objects, pipelines, environments, Power Platform solutions, Azure resources, Teams structures, Work IQ configuration, or tenant controls currently exist.

## 1. Purpose

This document describes the agent roles, responsibilities and superpowers in the Caldova HR Frontier Operating System.

Agents do not replace people. They form a digital workforce that structures information, produces proposals and prepares recurring work. Decisions with professional, business, employment or data-protection impact remain human-in-the-loop.

## 2. Agent Principles

- Agents produce proposals, not uncontrolled decisions.
- Agents work from cited sources and remain traceable.
- Agents emit confidence scores when uncertain.
- Agents escalate sensitive or unclear cases to people.
- Agents never write unreviewed employee data into GitHub or any public surface.
- Agents produce artefacts that are compatible with Azure Boards and GitHub.
- **Agents never make or imply an employment decision** about an individual.
- Agents state their identity when interacting with an employee.

## 3. Agent Overview — Operating Agents

| Agent | Purpose | Primary output |
|---|---|---|
| Voice of Employee Agent | Detects employee and manager needs and pain points | Feedback clusters, trends, opportunities |
| Product Discovery Agent | Converts feedback into product work | Epic, Feature, Story, Bug drafts |
| Architecture Agent | Assesses technical consequences | ADR draft, data model proposal, integration sketch |
| Delivery Agent | Monitors delivery | Sprint status, risk, blockers, deployment status |
| Release Agent | Produces release communication | Release notes, TEST/PROD updates |
| Outcome Agent | Checks impact after delivery | Outcome summary, impact report |
| Governance Agent | Checks risk and compliance | Redaction proposal, policy warning, approval requirement |
| Quality Agent | Checks rigour and quality | Review findings, consistency check, improvement proposals |

## 4. Agent Overview — HR Journey Agents

These are the planned employee-facing agents that would constitute the showcase itself. They are intended to be built in Microsoft Copilot Studio and Microsoft 365 Copilot and shipped as solution components.

| Agent | Journey stage | Purpose |
|---|---|---|
| Onboarding Assistant | Pre-boarding, Onboard | Guides the new joiner and the hiring manager through day-one, week-one and 90-day tasks |
| Policy & Benefits Assistant | All stages | Answers grounded policy, benefits and process questions from approved HR knowledge sources |
| Manager Assistant | Enable, Change | Supports managers with journey tasks, approvals and people-process guidance |
| Offboarding Assistant | Offboard | Coordinates last-day tasks, asset return, access revocation and knowledge handover |

Every HR journey agent is subject to the same principles as the operating agents, plus two specific constraints:

1. It answers only from approved, versioned HR knowledge sources and must cite them.
2. It hands off to a human HR contact whenever a question touches an individual case, an exception or a grievance.

## 5. Voice of Employee Agent

### Purpose

Detects recurring patterns from onboarding experiences, check-ins, HR cases, service desk tickets and feedback.

### Inputs

- Work IQ feedback
- Onboarding and offboarding checkpoint responses
- Check-in notes
- Teams discussions
- HR case summaries
- Dataverse signals

### Outputs

- Pain point cluster
- Opportunity statement
- Population segment signal (role, location, tenure band — never individual)
- Relevance assessment
- Possible product impact

### Superpowers

- Pattern recognition
- Summarisation
- Clustering
- Signal-to-noise reduction
- Marking sensitive data
- Aggregation thresholds: never report a cluster derived from fewer than five individuals

## 6. Product Discovery Agent

### Purpose

Translates validated insight into sprint-ready product artefacts.

### Inputs

- Voice of Employee findings
- Sprint review transcripts
- Teams discussions
- Product Owner comments

### Outputs

- Epic draft
- Feature draft
- User story draft
- Bug draft
- Acceptance criteria
- Azure Boards tags and area path proposal
- Prioritisation proposal

### Superpowers

- Story mapping
- Writing acceptance criteria
- Filling the work item template
- Detecting duplicates
- Proposing links to existing work items

## 7. Architecture Agent

### Purpose

Assesses technical impact and produces architecture proposals.

### Inputs

- User stories
- Existing architecture
- Dataverse model
- Repository context
- Technical constraints

### Outputs

- ADR draft
- Data model proposal
- API / integration proposal
- Risk analysis
- Implementation options

### Superpowers

- Architecture comparison
- Checking Dataverse and Common Data Model alignment
- Detecting integration risk
- Giving security-by-design guidance
- Assessing solution layering and dependency impact

## 8. Delivery Agent

### Purpose

Monitors delivery across Azure DevOps and GitHub and makes status visible to the organisation.

### Inputs

- Azure Boards work items
- Pull requests
- GitHub Actions runs
- Azure Pipelines runs
- Deployments and releases

### Outputs

- Sprint status
- Blocker summary
- TEST deployment update
- PROD deployment update
- Risk overview

### Superpowers

- Status aggregation across two planes
- Release readiness summary
- Blocker detection
- Short, Teams-ready communication

## 9. Release Agent

### Purpose

Translates technical change into understandable release communication.

### Inputs

- Merged pull requests
- Release tags
- Azure Boards work items
- Deployment status

### Outputs

- Release notes for employees
- Release notes for HR practitioners
- Technical changelog summary
- TEST approval communication
- PROD go-live communication

### Superpowers

- Explaining technical content simply
- Audience-appropriate communication
- Highlighting the TEST/PROD difference
- Naming relevant risks

## 10. Outcome Agent

### Purpose

Checks whether a change produced measurable impact after release.

### Inputs

- Release information
- Dataverse process data
- Usage data
- Post-release feedback
- HR service quality signals

### Outputs

- Impact summary
- Adoption signal
- Outcome report
- Learnings for the next sprint

### Superpowers

- Recognising before/after patterns
- Connecting qualitative and quantitative signals
- Testing hypotheses
- Proposing next improvements

## 11. Governance Agent

### Purpose

Protects against uncontrolled processing of sensitive data and supports compliance. In the Caldova HR Frontier this agent is load-bearing, because the repository is public and the domain is HR.

### Inputs

- Feedback content
- Transcripts
- Work item drafts
- Release notes
- Outcome reports
- Any content queued for handover to GitHub

### Outputs

- Sensitivity flag
- Redaction proposal
- Approval requirement
- Risk note
- Repository-safe version of the content

### Superpowers

- Marking personal data
- Detecting special-category data (health, absence, disciplinary, compensation, background check)
- Proposing data minimisation
- Producing a public-repository-safe version
- Blocking handover when confidence is low

## 12. Quality Agent

### Purpose

Checks rigour, consistency and quality of requirements, PRDs, system designs and sprint artefacts.

### Inputs

- PRD
- System design
- Work items
- Acceptance criteria
- Sprint review notes

### Outputs

- Consistency check
- Open questions
- Conflicts
- Improvement proposals
- Definition-of-Ready check

### Superpowers

- Detecting missing rigour
- Marking goal conflicts
- Sharpening acceptance criteria
- Improving delivery-ready documentation

## 13. Agent Interaction Pattern

```text
Voice of Employee Agent
  -> Product Discovery Agent
    -> Governance Agent
      -> Human Review
        -> Azure Boards work item
          -> Architecture Agent
            -> GitHub Copilot CLI build
              -> Delivery Agent
                -> Release Agent
                  -> Outcome Agent
                    -> Teams Learning Loop
```

## 14. Human-in-the-Loop Matrix

| Decision | Agent supports | Human decides | Decision owner |
|---|---|---|---|
| Is feedback relevant? | Yes | Yes | Product Owner |
| Does it contain personal data? | Yes | Yes | Governance Owner |
| Create work item? | Yes | Yes | Product Owner |
| Set priority? | Yes | Yes | Product Owner |
| Take into sprint? | Yes | Yes | Product Owner |
| Choose architecture? | Yes | Yes | Technical Owner |
| Merge pull request? | Yes | Yes | Technical Owner |
| Release to TEST? | Yes | Yes | Product Owner |
| Release to PROD? | Yes | Yes | Product Owner + Governance Owner |
| Publish an employee-facing agent? | Yes | Yes | Agent Owner + Governance Owner |
| Accept outcome? | Yes | Yes | Management |
| Any employment-affecting decision | No | Yes | Accountable manager / HR |

## 15. Agent Definition Standard

Every future agent definition under `.github/agents/<agent-name>/` should carry at minimum:

```text
.github/agents/<agent-name>/
  README.md            # purpose, owner, inputs, outputs, escalation rules
  instructions.md      # system instructions used by the agent
  schema.md            # the output contract the agent must produce
  evaluation.md        # how the agent's quality is assessed
```

Every Copilot Studio agent additionally carries, in its solution:

- a documented knowledge source list with owner and review date,
- a documented set of topics and actions,
- an authentication and data-scope statement,
- a published escalation path to a human.
