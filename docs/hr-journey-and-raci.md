# HR End-to-End Journey, Roles and RACI

> **Document ID:** GF-JRN-03
> **Status:** Draft 0.1
> **Owner:** DAAI / HR AI Business Lead, with HR Operations
> **Purpose:** The journey the agentic platform serves, the roles that own each stage, and where every candidate use case lands

---

## 1. Why This Document Exists

A use case list is a shopping list until it is placed in a journey. This document gives every candidate agent a **stage**, an **owner** and a **relationship to the systems of record**, so sequencing decisions can be made on where value compounds rather than on which idea was pitched most recently.

It also makes the platform's boundaries visible: the stages where Workday is authoritative, the stages where a local system owns the truth, and the handful of places where GF has a genuine gap.

---

## 2. The Journey

```text
   ATTRACT        HIRE          PRE-BOARD       ONBOARD        ENABLE
      │             │               │              │              │
      ▼             ▼               ▼              ▼              ▼
  ┌────────┐  ┌──────────┐  ┌─────────────┐  ┌──────────┐  ┌───────────┐
  │ Employer│  │ Requisi- │  │ Offer accep-│  │ Day one  │  │ Learning  │
  │ brand   │  │ tion, JD,│  │ ted → master│  │ → 90 day │  │ perform-  │
  │ sourcing│  │ screening│  │ data, IT,   │  │ readiness│  │ ance, pay │
  │         │  │ offer    │  │ contract    │  │          │  │ mobility  │
  └────────┘  └──────────┘  └─────────────┘  └──────────┘  └───────────┘
                                   ▲
                          ┌────────┴────────┐
                          │  MVP LANDS HERE │
                          └─────────────────┘

    GROW           CHANGE         OFFBOARD        ALUMNI
      │              │               │              │
      ▼              ▼               ▼              ▼
  ┌──────────┐  ┌──────────┐  ┌─────────────┐  ┌──────────┐
  │ Succes-  │  │ Role,    │  │ Leaver, exit│  │ Records, │
  │ sion,    │  │ manager, │  │ access      │  │ rehire   │
  │ skills,  │  │ location,│  │ revocation, │  │          │
  │ mobility │  │ contract │  │ handover    │  │          │
  └──────────┘  └──────────┘  └─────────────┘  └──────────┘

  ───────────────────── CROSS-CUTTING ─────────────────────
  HR Service Delivery  ·  HR Operations & Data Quality  ·  Analytics
```

### Stage definitions

| Stage | Starts when | Ends when | System of record |
|---|---|---|---|
| **Attract** | A hiring need is identified | A requisition is open | Workday Recruiting |
| **Hire** | Requisition opens | Offer accepted | Workday Recruiting |
| **Pre-board** | Offer accepted | Employee is ready for day one | **Workday Core HCM** + PeopleDoc (documents) |
| **Onboard** | Day one | 90-day checkpoint complete | Workday Core HCM |
| **Enable** | 90-day checkpoint complete | Continuous | Workday Talent & Performance, Learning |
| **Grow** | Continuous | Continuous | Workday Talent |
| **Change** | Role, manager, location or contract change | Change complete and systems updated | Workday Core HCM → ServiceNow |
| **Offboard** | Leaving recorded | Access revoked, assets returned, records closed | Workday → ServiceNow |
| **Alumni** | Last day | Retention period ends | Workday |

> **The MVP sits in Pre-board**, which is deliberate. It is the stage with the highest manual re-keying, the clearest quality problem, and the narrowest safe write — and everything downstream depends on the master data being complete.

---

## 3. Where the Systems Sit

| System | Owns | In the journey |
|---|---|---|
| **Workday** | Employee master data — the system of record | Every stage |
| **PeopleDoc** | Employee documents | Pre-board, Change, Offboard |
| **ServiceNow** | IT service management, user account lifecycle | Pre-board, Change, Offboard — bi-directional with Workday, drives joiner/mover/leaver |
| **SAP P01 (CH)** | Swiss payroll | Pre-board onwards, local |
| **Local payroll and time systems (20+)** | Country payroll and time | Varies |
| **ERP (40+)** | Cost centres, employee distribution | Change |
| **Microsoft 365** | Collaboration, knowledge, the experience layer | Every stage |
| **Power Platform** | Agentic toolset and HR control plane | Every stage the platform touches |

> **Two observations worth carrying into sequencing.** First, Workday Time Tracking and Absence are pending a decision, and interfaces to time recording, access management and shift planning are **not yet planned** — so use cases depending on them are blocked by a decision, not by build effort. Second, the ServiceNow integration already handles joiner/mover/leaver; agentic use cases in those stages should **consume** it, never duplicate it.

---

## 4. Roles

| Role | Accountable for |
|---|---|
| **DAAI / HR AI Business Lead** | Product direction, use-case priority, agent behaviour standards, business outcome |
| **Switzerland HR Operations** | Process design, approved fields, document handling, exception follow-up, operational acceptance |
| **HR Operations (global)** | Service delivery, case handling, process standards |
| **Workday Solutions / HRIS Owner** | Workday configuration, field definitions, report design, Integration System User design and permissions, access-layer action approval, data model integrity |
| **Talent Acquisition** | Recruiting process, candidate experience, hiring manager enablement |
| **Talent Management** | Performance, succession, skills, internal mobility |
| **L&D** | Learning content, paths, adoption |
| **Compensation & Benefits** | Pay structures, benchmarks, equity |
| **People Analytics** | Reporting, insight quality, measurement |
| **HRBP** | Business partnering, manager enablement, local application |
| **Local Payroll Team (CH)** | Payroll execution and controls |
| **Security / Privacy** | Data protection, access, retention, control approval |
| **IT / Platform Owners** | Environments, identity, integration, operations, support |
| **People Manager** | Their team's journey actions and people decisions |
| **Employee** | Their own data accuracy and journey participation |

---

## 5. RACI — Platform and Agent Delivery

**R** responsible · **A** accountable · **C** consulted · **I** informed

| Activity | DAAI | HR Ops CH | HRIS | Security / Privacy | IT | HRBP |
|---|---|---|---|---|---|---|
| Use-case prioritisation | **A/R** | C | C | I | C | C |
| Business requirements (PRD) | **A** | **R** | C | C | I | C |
| Approved field list | C | **A/R** | **R** | C | I | I |
| Workday field definitions and validation | I | C | **A/R** | I | I | I |
| Access-layer action design and approval | C | C | **A** | **C** | **R** | I |
| Workday Integration System User permission scope | C | I | **A** | C | **R** | **C** |
| Connector inventory and DLP data-group assignment | C | I | C | I | **R** | **A** |
| Agent design and configuration | **A/R** | C | C | C | C | I |
| Write envelope definition | **R** | **A** | **R** | **C** | I | I |
| Widening the write envelope | C | **A** | **R** | **C** | I | I |
| Privacy assessment | C | C | C | **A/R** | I | I |
| Access and permissions design | C | C | C | **A** | **R** | I |
| Environment and identity setup | C | I | C | C | **A/R** | I |
| Test strategy and acceptance | C | **A** | **R** | C | C | I |
| UAT and pilot exit decision | C | **A/R** | C | C | I | C |
| Operating procedure | C | **A/R** | C | C | C | I |
| Exception handling (run time) | I | **A/R** | C | I | C | I |
| Incident response | C | C | C | **C** | **A/R** | I |
| Outcome measurement | **A** | **R** | C | I | I | C |
| Stop the agent | **R** | **A/R** | I | C | I | I |

> **Two accountabilities to keep distinct.** The **write envelope** is accountable to HR Operations — they carry the consequence of a bad write. **Enforcing** it is accountable to HRIS, because the enforcement lives in the Workday Access Layer and, ultimately, in the Integration System User's permissions. Merging them puts the control and the incentive in the same place.

---

## 6. RACI — Journey Operation

| Journey activity | Employee | Manager | HR Ops | HRBP | HRIS | Agent |
|---|---|---|---|---|---|---|
| Provide personal master data | **A/R** | I | C | I | I | — |
| Complete master data in Workday | C | I | **A** | I | C | **R** *(within envelope)* |
| Resolve a match exception | C | I | **A/R** | I | C | Escalates |
| Approve a low-confidence value | C | I | **A/R** | I | C | Proposes |
| Follow up on a still-missing field | **C** | I | **A/R** | I | I | Flags |
| Validate master-data completeness | I | I | **R** | I | **A** | Reports |
| Answer a policy question | **A** *(asks)* | C | C | C | I | **R** *(grounded, cites)* |
| Decide a policy exception | I | C | **C** | **A/R** | I | **Refuses** |
| Any employment decision | I | **A/R** | C | **C** | I | **Refuses** |

---

## 7. Use Case Placement

Every candidate from the GF HR AI use case list, placed in the journey. Full drafts in [`hr/docs/ideas/`](../hr/docs/ideas/README.md).

| Stage | Use case | Priority | Complexity | HR owner | Idea |
|---|---|---|---|---|---|
| **Hire** | Job Description Generator | High | Low | Talent Acquisition | [UC-0006](../hr/docs/ideas/uc-0006-job-description-generator.md) |
| **Hire** | Candidate Screening Summary | High | Medium | Talent Acquisition | [UC-0007](../hr/docs/ideas/uc-0007-candidate-screening-summary.md) |
| **Pre-board** | **Personal Master Data Completion Agent** | **MVP** | Medium | HR Ops CH | [PRD](../hr/docs/ideas/uc-0001-personal-master-data-completion-agent/prd-0001-personal-master-data-completion-agent.md) |
| **Pre-board** | Pre-hire Process Orchestration | High | High | HR Ops CH | [UC-0017](../hr/docs/ideas/uc-0017-pre-hire-process-orchestration.md) |
| **Onboard** | Onboarding Assistant | High | Medium | HR Ops | [UC-0005](../hr/docs/ideas/uc-0005-onboarding-assistant.md) |
| **Onboard** | Onboarding Checklist Rebuild | Medium | Medium | HR Ops CH | [UC-0018](../hr/docs/ideas/uc-0018-onboarding-checklist-rebuild.md) |
| **Enable** | Learning Recommendation Agent | High | Medium | L&D | [UC-0011](../hr/docs/ideas/uc-0011-learning-recommendation-agent.md) |
| **Enable** | Performance Review Draft Assistant | High | Low | HRBP | [UC-0013](../hr/docs/ideas/uc-0013-performance-review-draft-assistant.md) |
| **Enable** | Continuous Performance Insights | High | High | Talent Management | [UC-0014](../hr/docs/ideas/uc-0014-continuous-performance-insights.md) |
| **Grow** | Skills Inference Engine | High | High | Talent Management | [UC-0016](../hr/docs/ideas/uc-0016-skills-inference-engine.md) |
| **Grow** | Leadership Pipeline Prediction | High | High | HR Leadership | [UC-0015](../hr/docs/ideas/uc-0015-leadership-pipeline-prediction.md) |
| **Change** | Salary Benchmark Assistant | Low — Phase 2 | High | Comp & Ben | [UC-0008](../hr/docs/ideas/uc-0008-salary-benchmark-assistant.md) |
| **Cross — Service Delivery** | HR Policy Chat Assistant | High | Low | HR Ops | [UC-0002](../hr/docs/ideas/uc-0002-hr-policy-chat-assistant.md) |
| **Cross — Service Delivery** | Employee Self-Service Assistant | High | Medium | Workday Solutions | [UC-0003](../hr/docs/ideas/uc-0003-employee-self-service-assistant.md) |
| **Cross — Service Delivery** | HR Case Classification Bot | High | Medium | HR Ops | [UC-0004](../hr/docs/ideas/uc-0004-hr-case-classification-bot.md) |
| **Cross — Operations** | Employee Data Validation Bot | High | Medium | Workday Solutions | [UC-0010](../hr/docs/ideas/uc-0010-employee-data-validation-bot.md) |
| **Cross — Operations** | Payroll Anomaly Detection | High | High | HR Ops / Local Payroll | [UC-0012](../hr/docs/ideas/uc-0012-payroll-anomaly-detection.md) |
| **Cross — Analytics** | Workforce Insights Assistant | Medium | High | People Analytics | [UC-0009](../hr/docs/ideas/uc-0009-workforce-insights-assistant.md) |
| **Cross — Analytics** | Attrition Risk Insight Lite | Medium | High | People Analytics | [UC-0019](../hr/docs/ideas/uc-0019-attrition-risk-insight-lite.md) |

### Coverage observation

The portfolio is **strong in Enable and Grow, and thin in Offboard and Alumni**. No candidate use case addresses leaving, access revocation confirmation, knowledge handover or alumni records — even though offboarding carries real compliance exposure and the ServiceNow integration already provides the hook. Worth raising with HR Operations: is this a genuine absence of pain, or an absence of anyone in the room representing it?

---

## 8. Sequencing Logic

GF positions at **Level 3 — agentic**. The MVP has to earn that position, so it is scoped to three use cases rather than a wave, and each is chosen for what it proves.

```text
MVP — three use cases, one platform thesis
├── UC-0001  Personal Master Data Completion   REASONING + GOVERNED WRITE
│            reads unstructured documents, writes to the system of record
│            inside an envelope enforced where the agent cannot reach it
│
├── UC-0010  Employee Data Validation          THE CLOSED LOOP
│            finds what is still missing across the population and feeds
│            it back. Built workflow-first; agent only for ambiguity
│
└── UC-0005  Onboarding Assistant              THE REUSE TEST
             same pattern, next journey stage. Proves the second costs less

ALONGSIDE (not counted — answers rather than acts)
└── UC-0002  HR Policy Chat Assistant
             Copilot chat harness, no charge for M365 Copilot-licensed users

WAVE 2 — service delivery at scale
├── HR Case Classification Bot
├── Job Description Generator
└── Onboarding Checklist Rebuild

WAVE 3 — assisted judgement  (higher governance load)
├── Performance Review Draft Assistant
├── Employee Self-Service Assistant
├── Learning Recommendation Agent
└── Candidate Screening Summary

WAVE 4 — analytics and prediction  (highest governance load)
├── Workforce Insights Assistant
├── Skills Inference Engine
├── Continuous Performance Insights
├── Attrition Risk Insight Lite
└── Leadership Pipeline Prediction

DEFERRED — blocked or Phase 2
├── Salary Benchmark Assistant       (marked Phase 2 by HR)
├── Payroll Anomaly Detection        (local payroll, high compliance impact)
└── Pre-hire Process Orchestration   (depends on MVP + Workday/PeopleDoc/SAP decisions)
```

### Why these three

**UC-0001 and UC-0010 are one loop, not two projects.** UC-0001 fills the blanks it has documents for; UC-0010 answers the question that creates — *what is still wrong or missing across everyone else?* Same data, same owner, same quality problem. Running them together compounds; running them apart duplicates the discovery work twice.

**UC-0005 exists to test the thesis, not to add scope.** The whole argument for building a platform rather than an agent is that the second use case costs less than the first. UC-0005 is the cheapest honest test of that: a different journey stage, the same process pattern, the same governed integration. It is also the pattern Microsoft names for HR — an onboarding workflow that calls an agent for the part needing judgement.

**UC-0002 runs alongside but is not counted.** It is the lowest-complexity, highest-visibility item in the portfolio and effectively free on the Copilot chat harness for Microsoft 365 Copilot-licensed users. It buys organisational familiarity cheaply — but it answers questions rather than taking action, so it is not evidence for the Level 3 position and should not be presented as such.

### The discipline that makes the position credible

> **UC-0010 is expected to be mostly workflow, with an agent only where a rule cannot express the check.** That is not a retreat from Level 3. A Level 3 organisation is one that knows where an agent earns its place — putting a reasoning model where a rule belongs trades governability for nothing, and is the fastest way to discredit the position. See [FR-0013](prd.md) and [ADR-0011](adr/0011-workflow-first-process-architecture.md).

**Why prediction comes last.** Wave 4 use cases influence decisions about people. They need the governance model, the escalation discipline and the organisational trust that the MVP and Waves 2–3 build. Starting there would be starting with the hardest conversation.

---

## 9. Governance Applied to Every Use Case

Regardless of stage, each use case declares before build:

| Declaration | Question |
|---|---|
| **Write envelope** | What may it write, where, under what conditions? If nothing, say so |
| **Refusal set** | What does it refuse, and what happens then? |
| **Escalation path** | Who is the named human, and how are they reached? |
| **Grounding sources** | Which approved sources, with which owner and review date? |
| **Data classification** | Public, internal, personal or special-category? |
| **Employment-decision surface** | Does any output influence a decision about a person? If yes, who decides, and what do they see? |
| **Measurement** | What changes, and how is that observed? |

A use case that cannot answer all seven is not ready for build, whatever its priority.

---

## 10. Open Journey Questions

| ID | Question | Owner |
|---|---|---|
| J-01 | Does the journey extend beyond Switzerland in the MVP horizon, and what changes if so? | DAAI / HR Ops |
| J-02 | Is the Offboard gap real, or unrepresented? | HR Operations |
| J-03 | What is the decision timeline on Workday Time Tracking and Absence? Several use cases depend on it | HRIS |
| J-04 | Which stages does Cowork serve first? | DAAI |
| J-05 | Who owns the employee-facing experience standard across all agents — tone, escalation, identification? | DAAI / HR Ops |
| J-06 | Should the Pre-hire Process Orchestration use case absorb the MVP once proven, or stay separate? | DAAI / HR Ops CH |
