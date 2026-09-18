# HITL Governance: Caldova HR Frontier

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-17 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Cross-cutting (all solution domains) |
| **References** | [Approved Intake Design](../specs/2026-09-17-architecture-baseline-intake-design.md), [Agent Operating Model](./03-agent-operating-model.md) |

Proposed Baseline orientation: This document describes intended future operating-model behavior. It does not prove that agents, Azure DevOps objects, pipelines, environments, Power Platform solutions, Azure resources, Teams structures, Work IQ configuration, or tenant controls currently exist.

## 1. Purpose

This document defines the human-in-the-loop governance for the use of Microsoft 365 Copilot agents, Copilot Studio agents, Work IQ, Azure DevOps and GitHub in the Caldova HR Frontier Operating System.

The goal is controlled automation, in which agents prepare operational work while people retain business, professional and data-protection accountability.

Two circumstances make this document stricter than a generic version:

1. **The domain is HR.** Content routinely contains personal data and can contain special-category data.
2. **The repository is public.** Anything committed is world-readable and effectively permanent.

## 2. Governance Principles

1. Agents produce proposals, not final decisions, in critical processes.
2. Employee data is minimised or redacted before it reaches any engineering system.
3. Every relevant publication or handover has a named owner.
4. Every agent action must be traceable.
5. Automation may increase transparency but must not replace accountability.
6. No agent output may determine an individual's employment outcome.
7. Nothing identifiable, and no tenant secret, ever enters the public repository.

## 3. Approval Points

| Process step | Agent action | Human control | Owner |
|---|---|---|---|
| Feedback intake | Summarise and classify | Confirm relevance | Product Owner |
| Sensitivity assessment | Flag and propose redaction | Confirm or override | Governance Owner |
| Transcript analysis | Produce findings and drafts | Review by PO or subject owner | Product Owner |
| Work item creation | Prepare the draft | Approve before creation | Product Owner |
| Architecture proposal | Present options and risks | Technical decision | Technical Owner |
| Pull request review | Provide review notes | Engineer review and merge | Technical Owner |
| TEST deployment | Report status | Test approval | Product Owner |
| PROD deployment | Produce release summary | Production approval | Product Owner + Governance Owner |
| Agent publication | Prepare agent package and instructions | Approve publication to employees | Agent Owner + Governance Owner |
| Knowledge source change | Propose source addition | Approve source and review date | Governance Owner |
| Outcome report | Summarise impact | Management review | Management |

## 4. Data Classes

### Public or non-critical data

Examples:

- General feature requests
- Technical release notes
- Non-personal process notes
- Published HR policy text already public

Processing:

- Agentic processing permitted
- Handover to GitHub permitted after standard review

### Internal business data

Examples:

- Internal priorities
- Roadmap topics
- Process problems
- Aggregated employee feedback

Processing:

- Only within authorised Teams and engineering areas
- No automatic publication without review
- Aggregate only; no individual attribution

### Personal employee data

Examples:

- Name, employee ID, contact details
- Manager and reporting line
- Role, location, start and end dates
- Case notes with personal reference

Processing:

- Redaction before any engineering handover
- Purpose limitation
- Human review
- Stays inside Dataverse with role-based access

### Special-category and high-sensitivity HR data

Examples:

- Health, sickness and absence data
- Accommodation and disability information
- Compensation, bonus and equity data
- Performance, disciplinary and grievance records
- Background check and right-to-work data
- Works council and employee representation matters

Processing:

- Highest protection class
- Excluded from agent processing unless explicitly approved case by case
- Never handed to GitHub in any form
- Column-level security in Dataverse
- Only abstracted requirements or synthetic patterns may inform engineering work

## 5. Redaction Pattern

Before handover to any engineering system the Governance Agent must remove or abstract sensitive detail.

### Example raw signal

```text
New joiner Alex Muster reported after the day-one check-in that the equipment request
form is too complicated and that their accessibility equipment was not ordered.
```

### Repository-safe version

```text
A new joiner reported after the day-one check-in that the equipment request form
is too complicated and that a requested item was not ordered.
```

### Better still, as a product requirement

```text
As a new joiner I want to complete my equipment request in as few steps as possible,
and see the fulfilment status of each requested item, so that day-one readiness is
predictable.
```

Note that the accessibility detail was removed rather than generalised: it is special-category data and is not needed to express the requirement. The rule is **remove what is not needed, abstract what is**.

### Redaction checklist

Before any content is committed, posted to the repository or attached to a work item, confirm that it contains no:

- names, employee IDs, email addresses, phone numbers,
- job titles combined with location or team small enough to identify a person,
- health, absence, accommodation, performance, compensation or disciplinary detail,
- tenant identifiers, environment URLs with credentials, subscription IDs, client secrets, connection strings,
- screenshots containing any of the above.

## 6. Audit Trail

Every workflow must document at minimum:

- Source of the feedback
- Time of processing
- Responsible agent and agent version
- Generated proposal
- Sensitivity classification and redaction applied
- Human reviewer
- Decision
- Azure Boards reference
- GitHub reference
- Outcome reference

## 7. Approval States

Recommended status values:

```text
Drafted by Agent
Needs Governance Review
Needs Human Review
Approved
Needs Changes
Rejected
Created in Azure Boards
In Sprint
Delivered to TEST
Delivered to PROD
Outcome Reviewed
```

## 8. Risk and Escalation Logic

### Escalate to Product Owner

- Unclear requirements
- High business relevance
- Priority conflict
- Scope change affecting a journey stage

### Escalate to Governance Owner

- Personal data
- Special-category HR data
- Data protection uncertainty
- External publication
- Any proposal to add a knowledge source
- Any request to widen an agent's data scope

### Escalate to Technical Owner

- Architecture decision
- Security impact
- Integration risk
- Data model change
- Elevation of an automation identity's permissions

### Escalate to Management

- Employment-affecting proposals — always, and always as a refusal by the agent
- Outcome acceptance
- Works council or employee representation topics

## 9. Definition of Ready for a Work Item

A work item may enter a sprint when:

- the problem is clearly described,
- the target user is clear,
- acceptance criteria are present,
- no unreviewed sensitive data is contained,
- priority is set,
- a business owner is named,
- technical feasibility has been roughly assessed,
- the affected employee journey stage is tagged,
- the governance classification is recorded.

## 10. Definition of Done for the Feedback Loop

A feedback loop is complete when:

- feedback was captured,
- a decision was made,
- delivery or deliberate rejection was documented,
- status was reported back to Teams,
- where delivered, an outcome was reviewed,
- learnings are available for future sprints,
- the audit trail is complete end to end.

## 11. Agent Publication Gate

No agent becomes available to employees until all of the following are true:

| Check | Evidence |
|---|---|
| Purpose and scope documented | `.github/agents/<agent>/README.md` |
| Instructions reviewed | Approved diff in a pull request |
| Knowledge sources approved with owner and review date | Governance record |
| Data scope confirmed least-privilege | Connection and security role review |
| Escalation path to a human is implemented and tested | Test evidence |
| Agent identifies itself as an agent | Test evidence |
| Refusal behaviour for employment decisions tested | Test evidence |
| DLP and connector policy compliant | Power Platform admin review |
| Published through solution deployment, not manual edit | Pipeline run |

## 12. Standing Prohibitions

The following are prohibited regardless of approval:

- Committing real employee data to the repository.
- Committing tenant secrets, client secrets or connection strings to the repository.
- Granting an automation identity tenant-wide administrative rights for convenience.
- Manual edits directly in the PROD environment.
- Using production personal data for demonstrations. All demo data is synthetic.
- Allowing an agent to communicate an employment decision to an individual.
