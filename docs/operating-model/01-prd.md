# PRD: Caldova HR Frontier Operating System

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-17 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Cross-cutting (all solution domains) |
| **References** | [Approved Intake Design](../specs/2026-09-17-architecture-baseline-intake-design.md), [System Design](./02-system-design.md) |

Proposed Baseline orientation: This document describes intended future operating-model behavior. It does not prove that agents, Azure DevOps objects, pipelines, environments, Power Platform solutions, Azure resources, Teams structures, Work IQ configuration, or tenant controls currently exist.

## 1. Product Name

**Caldova HR Frontier Operating System**
Short name: **CHF FOS**
Solution / domain name used throughout repository, Azure DevOps and Power Platform: **Caldova HR Frontier**

## 2. Product Purpose

The Caldova HR Frontier Operating System connects employees, managers, HR practitioners, Microsoft 365 Copilot agents, Work IQ, Copilot Studio, Azure DevOps, GitHub, the Power Platform and Dataverse into one closed digital feedback loop covering the employee journey from onboarding to offboarding.

The goal is to capture feedback and insight from employee moments, HR cases, manager conversations, Teams reviews, sprint reviews and product usage; structure it agentically; have it controlled by people; and convert it into delivery work that is planned in Azure DevOps and built in GitHub.

## 3. Problem Statement

Relevant HR information is created today in multiple silos:

- Teams discussions and channel threads
- HR service desk cases and email
- Meeting transcripts (intake, review, calibration)
- Azure DevOps work items
- Sprint reviews
- Product and agent usage
- Employee and manager feedback
- Operational Dataverse data

Without a standardised feedback loop, insight risks being:

- not captured,
- not prioritised,
- never converted into a work item,
- never delivered,
- or never checked for impact after delivery.

In an HR context there is a further risk: insight that **is** captured may carry personal or special-category data into engineering systems — including a **public** GitHub repository — where it does not belong.

## 4. Product Vision

> **CHF FOS turns every relevant insight into a controlled, traceable and measurable improvement — without ever exposing an identifiable employee.**

## 5. Audiences

### Primary users

- Employees of Caldova
- People managers
- HR Business Partners and HR operations specialists
- Product Owner
- Engineers and build agents
- Management

### Secondary users

- Candidates and new joiners
- Leavers and alumni
- External delivery partners
- Works council / employee representation
- Data protection, compliance and quality owners

## 6. System Roles

| Role | Responsibility |
|---|---|
| Employee | Give feedback, validate information, consume status |
| Manager | Own journey tasks for their team, approve people-related steps |
| HR Business Partner | Qualify employee signals, confirm professional relevance and policy fit |
| Product Owner | Prioritise, define sprint scope, approve Azure Boards work items |
| Engineer | Technical implementation, pull requests, reviews, releases |
| Agent Owner | Monitor agents, maintain prompts, instructions and policies |
| Governance Owner | Data protection, compliance, risk and approval logic |
| Platform Owner | Tenant, environment, DLP and identity configuration |

## 7. Core Capabilities

### 7.1 Feedback Intake

The system must be able to ingest feedback from:

- Teams messages
- Teams meeting transcripts
- Work IQ interactions
- HR service desk cases
- Onboarding and offboarding checkpoint responses
- Sprint reviews
- Employee listening / pulse responses
- Dataverse signals

### 7.2 Agentic Classification

Feedback must be classified automatically as:

- Bug
- Feature request
- User story
- Epic
- Process problem
- HR service quality
- Data model topic
- Architecture topic
- Compliance or privacy risk
- Policy question
- Release communication

### 7.3 HITL Review

Before feedback becomes a work item, a human must be able to:

- approve,
- edit,
- defer,
- reject,
- escalate to a named role.

### 7.4 Work Item Generation

After approval, the system must produce sprint-ready artefacts in **Azure Boards**, and the corresponding implementation artefacts in **GitHub**:

| Azure DevOps (plan & govern) | GitHub (build & prove) |
|---|---|
| Epic | Milestone / tracking issue |
| Feature | Branch + pull request |
| User Story | Pull request with acceptance criteria |
| Task | Commit(s) linked with `AB#<id>` |
| Bug | Fix PR + regression test |
| — | ADR in `docs/adr/` |
| Release work item | Release notes draft |

The linkage between the two planes is the `AB#<work-item-id>` reference in commit messages and pull request descriptions.

### 7.5 Delivery Status Feedback

Implementation status must be published from Azure DevOps and GitHub back to Teams and Work IQ:

- planned
- in delivery
- in review
- deployed to TEST
- deployed to PROD
- blocked
- deferred

### 7.6 Outcome Measurement

After deployment the system must check whether delivery created impact:

- Journey task completion improved?
- Time-to-productivity improved?
- HR case volume for the topic reduced?
- Manager or employee experience improved?
- Errors and rework reduced?
- Process cycle time reduced?

## 8. Non-Goals of the First Version

The first version deliberately does not connect every system autonomously. Non-goals:

- no fully automatic prioritisation without human approval,
- no automatic PROD deployment without approval,
- no unreviewed processing of special-category personal data by arbitrary agents,
- no full replacement of existing HR or engineering processes,
- **no autonomous decision affecting an individual's employment** — hiring, performance, compensation, disciplinary or termination outcomes remain human decisions,
- no publication of identifiable employee data to the public repository under any circumstance.

## 9. MVP Scope

### MVP 1: Delivery transparency

```text
Azure DevOps / GitHub Release
  -> Delivery Agent
    -> Status Summary
      -> Teams Channel
```

### MVP 2: Review transcript to work item intake

```text
Teams Review Transcript
  -> Work IQ
    -> Product Discovery Agent
      -> Governance Agent (redaction)
        -> Work Item Draft
          -> PO Review
            -> Azure Boards Work Item
```

### MVP 3: Onboarding journey slice

```text
New Joiner Record (Dataverse)
  -> Onboarding Orchestration (Power Automate)
    -> Employee + Manager Tasks (Power App / Teams)
      -> Copilot Studio Onboarding Assistant
        -> Completion Signals (Dataverse)
```

### MVP 4: Outcome review

```text
Release
  -> Dataverse Signal
    -> Outcome Agent
      -> Impact Summary
        -> Teams Review
```

## 10. Functional Requirements

### FR-001: Capture feedback

The system must ingest feedback from Work IQ, Teams, HR cases and reviews.

### FR-002: Classify feedback

The system must classify feedback by type, relevance, urgency and target area.

### FR-003: Generate draft work items

The system must generate Azure Boards work item drafts from validated feedback.

### FR-004: Enable human review

The system must enable human review before creation of, or handover to, any engineering artefact.

### FR-005: Report delivery status

The system must make relevant status changes from Azure DevOps and GitHub visible to employees.

### FR-006: Distinguish TEST and PROD

The system must distinguish releases and deployments at least by TEST and PROD.

### FR-007: Capture outcome

The system should collect and summarise relevant outcome signals after delivery.

### FR-008: Ensure auditability

The system must make traceable which agent produced which proposal and which person granted which approval.

### FR-009: Enforce redaction before engineering handover

The system must remove or abstract personal data before any content reaches GitHub, including issue bodies, pull request descriptions, commit messages and release notes.

### FR-010: Cover the full journey

The solution must address the employee journey stages Hire, Onboard, Enable, Change and Offboard, with at least one delivered capability in each stage.

### FR-011: Reproducible environment configuration

Tenant, environment and solution configuration must be described in the repository so the showcase can be rebuilt from source.

## 11. Non-Functional Requirements

### NFR-001: Security

All integrations must be role-based, auditable and least-privilege. Automation identities must use workload identity federation where supported, and never long-lived secrets in the repository.

### NFR-002: Data protection

Employee and candidate data may only be processed in a controlled, purpose-limited and minimal way. Special-category data is excluded from agent processing unless explicitly approved.

### NFR-003: Traceability

Agent decisions must be treated as proposals and documented including their source.

### NFR-004: Extensibility

New agents and workflows must be addable in a modular way.

### NFR-005: ALM compatibility

All implementation-relevant artefacts must be solution-aware and source-controllable: Power Platform solutions, Copilot Studio agents, Power Automate flows and Power Apps all ship through the same pipeline.

### NFR-006: Teams-first experience

Employees should experience status and interaction primarily through Teams and Work IQ.

### NFR-007: Public repository safety

The repository is public. Secret scanning with push protection must be enabled, no tenant secrets may be committed, and all sample data must be synthetic.

### NFR-008: Demonstrability

Every capability must be demonstrable in under ten minutes from a clean start, with a documented demo path.

## 12. KPIs

| KPI | Description |
|---|---|
| Feedback-to-Work-Item Rate | Share of relevant feedback converted into Azure Boards work items |
| Draft Approval Rate | Share of agent-generated drafts approved by people |
| Insight-to-Sprint Time | Time from insight to sprint planning |
| Delivery Transparency Rate | Share of delivery status updates published automatically to Teams |
| Release-to-Outcome Rate | Share of releases with a measurable outcome review |
| HITL Intervention Rate | Share of agent proposals requiring human correction |
| Rework Rate | Share of work items reworked due to unclear requirements |
| Redaction Catch Rate | Share of drafts in which the Governance Agent removed personal data before handover |
| Journey Coverage | Share of employee journey stages with a delivered capability |

## 13. Risks

| Risk | Description | Mitigation |
|---|---|---|
| Incorrect classification | Agent classifies feedback wrongly | HITL review, labels, confidence score |
| Data protection breach | Personal data reaches the public repository | Redaction, DLP, push protection, review gate |
| Over-automation | People lose control of people-affecting decisions | Clear approval points, agents as draft producers only |
| Information overload | Teams receives too many status messages | Channel strategy, filters, relevance logic |
| Unclear ownership | Nobody reviews agent proposals | Named roles: PO, Agent Owner, Governance Owner, Platform Owner |
| Dual backlog drift | Azure Boards and GitHub Issues diverge | Single source of truth in Azure Boards; GitHub Issues disabled or mirrored only |
| Demo tenant drift | Manual changes break reproducibility | Configuration-as-documentation, solution-based ALM, no manual PROD edits |
| Fairness and bias | Agent output influences people decisions unevenly | Human decision ownership, documented instructions, sampling review |

## 14. MVP Acceptance Criteria

- A Teams review transcript can be processed end to end.
- The Product Discovery Agent produces structured work item drafts.
- The Governance Agent removes personal data before handover and the removal is visible in the audit trail.
- A Product Owner can approve or reject drafts.
- Approved drafts can be created as Azure Boards work items when the integration is implemented.
- A commit or pull request in GitHub links back to its Azure Boards work item via `AB#`.
- Azure DevOps and GitHub status changes can be rendered as a Teams status message.
- TEST and PROD status are communicated separately.
- An onboarding journey slice runs against Dataverse with employee and manager tasks.
- An outcome report can be generated as a draft.
- The entire configuration can be reproduced from the repository documentation.
