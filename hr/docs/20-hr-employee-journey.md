# Solution Domain: Caldova HR Employee Journey

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-17 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Superseded |
| **Scope** | HR |
| **References** | [Implementation Roadmap](../../docs/operating-model/05-implementation-roadmap.md), [Approved Intake Design](../../docs/specs/2026-09-17-architecture-baseline-intake-design.md) |

> **Superseded.** This document is retained for history. The current product and solution design is [`prd.md`](../../docs/prd.md), [`solution-design.md`](../../docs/solution-design.md), and [`hr-journey-and-raci.md`](../../docs/hr-journey-and-raci.md), reconciled through the [Phase 4 HR Solution Functional Design Intake](../../docs/reviews/2026-09-24-phase-4-hr-solution-functional-design-intake.md).

Proposed Baseline orientation: this document describes intended future HR capabilities, data model, security model, agents and demo path. Phase 2 imports documentation only; it does not deliver Power Platform solution payload, Dataverse tables, security roles, agents, apps, flows, seed JSON or executable implementation.

## 1. Purpose

This document defines the proposed business scope of the Caldova HR Frontier showcase: the end-to-end employee journey from onboarding to offboarding, the capabilities intended for each stage, and the Dataverse data model planned to carry them.

It is the bridge between the operating model (`docs/operating-model/`) and the future platform configuration. [Approved Intake Design](../../docs/specs/2026-09-17-architecture-baseline-intake-design.md) is the governing repository-local reference until infrastructure detail is imported. Infrastructure detail enters in Phase 3.

## 2. Journey Stages

```text
Hire  ->  Onboard  ->  Enable  ->  Change  ->  Offboard
```

| Stage    | Trigger                                              | Ends when                                              |
| -------- | ---------------------------------------------------- | ------------------------------------------------------ |
| Hire     | Offer accepted                                       | Pre-boarding record created                            |
| Onboard  | Pre-boarding record created                          | 90-day checkpoint complete                             |
| Enable   | 90-day checkpoint complete                           | Continuous                                             |
| Change   | Role, manager, location or contract change           | Change checklist complete                              |
| Offboard | Resignation, end of contract or termination recorded | Alumni record created, access revoked, assets returned |

## 3. Capabilities per Stage

The **Scope** column is the MVP boundary. `MVP` items are the three use cases in [Implementation Roadmap](../../docs/operating-model/05-implementation-roadmap.md) §7. Everything else is Horizon 2 — designed here, not built yet.

### 3.1 Hire

| Capability                                                  | Built with                 | Priority | Scope |
| ----------------------------------------------------------- | -------------------------- | -------- | ----- |
| Offer-accepted intake creating a candidate-to-joiner record | Power Automate + Dataverse | Must     | H2    |
| Hiring manager pre-boarding checklist                       | Power Apps + Dataverse     | Must     | H2    |
| Pre-boarding welcome communication                          | Power Automate + Teams     | Should   | H2    |
| Candidate questions answered from public policy knowledge   | Copilot Studio agent       | Should   | H2    |

### 3.2 Onboard

| Capability                                                     | Built with                                      | Priority | Scope                |
| -------------------------------------------------------------- | ----------------------------------------------- | -------- | -------------------- |
| Day-one, week-one and 90-day task generation                   | Power Automate + Dataverse                      | Must     | **MVP — use case 1** |
| New joiner task experience                                     | **Power Apps** (canvas or model-driven)         | Must     | **MVP — use case 1** |
| Manager onboarding dashboard                                   | Power Apps + Dataverse                          | Must     | **MVP — use case 1** |
| Onboarding Assistant guiding the new joiner                    | Copilot Studio agent                            | Must     | **MVP — use case 2** |
| Equipment and access request orchestration                     | Power Automate                                  | Must     | H2                   |
| Buddy assignment                                               | Power Automate                                  | Should   | H2                   |
| Day-one, week-one and 90-day checkpoints with feedback capture | Power Automate + Dataverse                      | Must     | H2                   |
| Grounded answers on policy, benefits and "how do I…"           | **Copilot Studio agent (Copilot chat harness)** | Must     | H2                   |

### 3.3 Enable

| Capability                            | Built with                                      | Priority | Scope |
| ------------------------------------- | ----------------------------------------------- | -------- | ----- |
| Learning path assignment and tracking | Power Automate + Dataverse                      | Should   | H2    |
| Manager check-in prompts and capture  | Copilot Studio agent + Dataverse                | Should   | H2    |
| Policy & Benefits Assistant           | **Copilot Studio agent (Copilot chat harness)** | Must     | H2    |
| HR case intake and routing            | Power Automate + Dataverse                      | Should   | H2    |

### 3.4 Change

| Capability                                    | Built with                 | Priority | Scope |
| --------------------------------------------- | -------------------------- | -------- | ----- |
| Role, manager or location change checklist    | Power Automate + Dataverse | Should   | H2    |
| Access change orchestration                   | Power Automate             | Should   | H2    |
| Manager Assistant for people-process guidance | Copilot Studio agent       | Should   | H2    |

### 3.5 Offboard

| Capability                                             | Built with                       | Priority | Scope                |
| ------------------------------------------------------ | -------------------------------- | -------- | -------------------- |
| Leaver intake and last-day calculation                 | Power Automate + Dataverse       | Must     | **MVP — use case 3** |
| Offboarding checklist for employee, manager, IT and HR | Power Apps + Dataverse           | Must     | **MVP — use case 3** |
| Asset return tracking                                  | Power Automate + Dataverse       | Must     | **MVP — use case 3** |
| Access revocation handover pack                        | Power Automate                   | Must     | **MVP — use case 3** |
| Knowledge handover capture                             | Copilot Studio agent + Dataverse | Should   | H2                   |
| Exit feedback capture                                  | Power Automate + Dataverse       | Must     | H2                   |
| Offboarding Assistant                                  | Copilot Studio agent             | Must     | H2                   |
| Alumni record creation                                 | Power Automate + Dataverse       | Could    | H2                   |

> **Two capability surfaces changed when the MVP was defined.** The new joiner task experience is a **standard Power App**, not a Power Apps code app; and grounded policy answers come from a **Copilot Studio agent on the Copilot chat harness**, not a Microsoft 365 declarative agent. Both deferred surfaces remain proposed — see the roadmap §8 H2-E.

## 4. Dataverse Data Model

Solution publisher prefix: `ur`, adopted from the supplied solution zip. Confirm once, before the first table is created — the prefix cannot be changed afterwards without rebuilding components.

All tables below are planned for the future **`CaldovaHRFrontierHR`** solution under [HR Solution Sources](../src/solutions/README.md). Security roles, connection references and environment variable definitions are planned for **`CaldovaHRFrontierInfra`**, which is always imported first. See [ADR-0004](../../docs/adr/0004-domain-solution-architecture-and-publisher.md) and [Approved Intake Design](../../docs/specs/2026-09-17-architecture-baseline-intake-design.md); Infrastructure detail enters in Phase 3.

### 4.1 Core tables

| Table                 | Logical name             | Purpose                                                      | Key columns                                                                                                              |
| --------------------- | ------------------------ | ------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------ |
| Employee              | `ur_employee`            | The person record for the demo journey (synthetic data only) | Employee number, display name, work email, manager, department, location, employment type, hire date, leave date, status |
| Journey               | `ur_journey`             | An instance of a journey for one employee                    | Employee, stage, start date, target completion date, actual completion date, status, owner                               |
| Journey Task          | `ur_journeytask`         | A single actionable step in a journey                        | Journey, title, description, assigned role, assigned to, due date, completion date, status, blocking flag, sequence      |
| Journey Template      | `ur_journeytemplate`     | Reusable definition of a journey                             | Name, stage, applies-to criteria, active                                                                                 |
| Journey Template Task | `ur_journeytemplatetask` | Reusable definition of a task                                | Template, title, assigned role, offset days, sequence, mandatory                                                         |
| HR Case               | `ur_hrcase`              | A question or issue raised by an employee or manager         | Employee, category, subject, description, channel, priority, status, resolution, resolved date                           |
| Asset                 | `ur_asset`               | Equipment issued to an employee                              | Asset tag, type, issued to, issued date, returned date, status                                                           |
| Access Request        | `ur_accessrequest`       | Access grant or revoke request                               | Employee, system, action, requested date, completed date, status                                                         |
| Checkpoint            | `ur_checkpoint`          | Day-one / week-one / 90-day / exit checkpoint                | Journey, type, scheduled date, completed date, sentiment, summary                                                        |
| Outcome Signal        | `ur_outcomesignal`       | Measurement point for the outcome loop                       | Name, journey stage, period, value, unit, release reference, source                                                      |
| Feedback Item         | `ur_feedbackitem`        | Structured feedback captured through Work IQ or an agent     | Source, journey stage, classification, summary, data classification, redaction applied, work item reference, status      |

### 4.2 Choice columns

```text
ur_journeystage:        Hire | Onboard | Enable | Change | Offboard
ur_taskstatus:          Not started | In progress | Blocked | Complete | Not applicable
ur_assignedrole:        Employee | Manager | HR | IT | Facilities | Buddy
ur_checkpointtype:      Day one | Week one | Thirty day | Ninety day | Exit
ur_dataclassification:  Public | Internal | Personal | Sensitive
ur_casecategory:        Policy | Benefits | Payroll | Equipment | Access | Learning | Other
```

### 4.3 Relationships

```text
ur_journeytemplate  1 --- N  ur_journeytemplatetask
ur_employee         1 --- N  ur_journey
ur_journey          1 --- N  ur_journeytask
ur_journey          1 --- N  ur_checkpoint
ur_employee         1 --- N  ur_hrcase
ur_employee         1 --- N  ur_asset
ur_employee         1 --- N  ur_accessrequest
ur_journey          1 --- N  ur_feedbackitem   (optional)
```

### 4.4 Security model

| Table                                                                       | Access pattern                                                     | Mechanism                                                    |
| --------------------------------------------------------------------------- | ------------------------------------------------------------------ | ------------------------------------------------------------ |
| `ur_employee`                                                               | Employee sees own record; manager sees direct reports; HR sees all | Business units + hierarchy security, or an owning-team model |
| `ur_journeytask`                                                            | Assignee and task owner                                            | Ownership + team access                                      |
| `ur_hrcase`                                                                 | Requester, assigned HR agent, HR role                              | Ownership + role privileges                                  |
| Sensitive columns (absence reason, accommodation notes, exit reason detail) | HR role only                                                       | **Column security profiles**                                 |
| `ur_outcomesignal`                                                          | Aggregated; readable by delivery roles                             | Organisation-level read                                      |

Three custom security roles are planned for **`CaldovaHRFrontierInfra`**, so they will exist before the HR solution that references them:

- `Caldova HR Frontier — Employee`
- `Caldova HR Frontier — Manager`
- `Caldova HR Frontier — HR Practitioner`

Plus one for automation:

- `Caldova HR Frontier — Integration` (used by the build and orchestration application users; least privilege, no delete on employee records)

## 5. Agent Grounding Sources

| Agent                       | Knowledge source                                                                       | Owner               | Review cadence |
| --------------------------- | -------------------------------------------------------------------------------------- | ------------------- | -------------- |
| Policy & Benefits Assistant | SharePoint library `HR Policies` (approved, versioned documents only)                  | Governance Owner    | Quarterly      |
| Onboarding Assistant        | SharePoint library `Onboarding Guides` + `ur_journeytask` for the employee's own tasks | Product Owner       | Per release    |
| Manager Assistant           | SharePoint library `Manager Playbooks`                                                 | HR Business Partner | Quarterly      |
| Offboarding Assistant       | SharePoint library `Offboarding Guides` + `ur_journeytask`                             | Product Owner       | Per release    |

Rules for all four:

1. Only approved, versioned sources. No general web grounding for policy answers.
2. Every answer cites its source.
3. Any individual case, exception, grievance or employment decision is handed to a named human contact.
4. No access to special-category columns.

## 6. Demo Data

All demonstration data is **synthetic**. No seed JSON, generator or data-loading payload is imported in Phase 2. The planned seed files below are formats/examples for a future reproducible showcase:

```text
data/
  employees.seed.json          # 40 synthetic employees across 5 departments
  journeytemplates.seed.json   # Onboarding, Change and Offboarding templates
  cases.seed.json              # Representative HR cases per category
  README.md                    # reset and reload procedure
```

Rules:

- Names are generated, not real. Email addresses use a reserved demo domain.
- No real photographs of people.
- The planned data set includes deliberately "messy" records (a late start date, a blocked asset return, an overdue checkpoint) so that the showcase can demonstrate exception handling.

## 7. Demo Path

The intended showcase path is designed to be demonstrable in roughly ten minutes after the future implementation exists:

1. **Hire** — an offer-accepted signal creates a pre-boarding record and notifies the hiring manager in Teams.
2. **Onboard** — the journey generates day-one, week-one and 90-day tasks; the new joiner opens the journey app and asks the Onboarding Assistant a question; the assistant answers from an approved source and cites it.
3. **Enable** — a manager asks the Policy & Benefits Assistant a question that touches an individual exception; the agent refuses and routes to a human.
4. **Change** — a role change triggers an access change checklist.
5. **Offboard** — a leaver record generates the offboarding checklist; an asset is outstanding and the exception is surfaced.
6. **Loop** — feedback captured at the exit checkpoint is classified, redacted by the Governance Agent, approved by the Product Owner and created as an Azure Boards work item; the resulting release is announced in Teams and the outcome signal is measured.

## 8. Out of Scope

- Integration with a real HR system of record.
- Payroll calculation or payment.
- Any live identity provisioning or deprovisioning against production systems. Access requests are modelled and orchestrated, but the fulfilment step in the showcase is simulated.
- Any processing of real employee data.
