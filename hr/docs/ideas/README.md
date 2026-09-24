# `docs/ideas/` — the use case portfolio

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-24 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | HR Use Case Portfolio |
| **References** | [HR Solution Functional Design Intake](../../../docs/specs/2026-09-24-hr-solution-functional-design-intake-design.md) |

**Purpose.** Every candidate use case from the **GF HR AI use case list**, expanded into a reviewable idea document and placed in the HR journey. This folder is where a use case lives before anyone commits to it.

> **Most of these are ideas, not requirements — and that distinction is the point of this folder.** Each document records what HR stated (objective, value, KPI, complexity, priority, risks, personas) and adds a platform-fit assessment: harness, write envelope, refusals, grounding, data classification and employment-decision surface.
>
> **Three are in MVP scope** — UC-0001, UC-0010 and UC-0005. **Fifteen are not**, and none of those fifteen is scheduled, committed or approved for build.

---

## Structure

```text
ideas/
├── README.md                                  this file
├── uc-0001-personal-master-data-completion-agent/   SELECTED — has a folder and a PRD
│   ├── README.md
│   ├── uc-0001-personal-master-data-completion-agent.md
│   └── prd-0001-personal-master-data-completion-agent.md
├── uc-0005-onboarding-assistant.md                 MVP scope — flat until selected
├── uc-0010-employee-data-validation-bot.md         MVP scope — flat until selected
└── uc-0002-…  …  uc-0019-….md                      ideas — one flat file each
```

**A flat file is an idea. A folder is a commitment.** When a use case is selected, it graduates: a folder is created with the same name as its use case document, the document moves in, and a PRD joins it. UC-0010 and UC-0005 are in MVP scope but have **not** yet graduated — they get folders when their PRDs are written, which is the next drafting step after UC-0001's Definition of Ready is met.

---

## Evidence rules for agents

**1. A flat `uc-*.md` file is not approved work** — with the two named MVP exceptions, UC-0010 and UC-0005, which are *in scope* but not yet specified. Do not describe any other use case as planned, scheduled or committed. The waves below are a **recommended** sequence, not a roadmap GF has agreed.

**2. Separate what HR stated from what this package assessed.** Section 1 of each document is GF's own material from the use case list. Sections 3 and 4 are analysis produced here. Do not attribute the assessment to GF.

**3. The assessment asks whether an agent is the right answer.** Several documents conclude it may not be — a scheduled report, a Workday capability, or a process fix may serve better. Preserve that; it is deliberate, not hedging.

**4. Cite `UC-nnnn`.** The identifiers are stable; titles and prose are not.

**5. Five use cases touch employment decisions.** UC-0007, UC-0008, UC-0014, UC-0015, UC-0019. Never describe any of them as deciding anything about a person — each requires a named human decision-maker who sees the underlying evidence. `prd.md` FR-0005 is absolute on this.

---

## The MVP — three use cases

GF positions at **Level 3 — agentic**. These three carry that claim.

| # | Use case | What it proves | Complexity | HR owner |
|---|---|---|---|---|
| **[UC-0001](uc-0001-personal-master-data-completion-agent/README.md)** | Personal Master Data Completion Agent | Reasoning over unstructured documents **plus a governed write to the system of record** | Medium | HR Ops CH |
| **[UC-0010](uc-0010-employee-data-validation-bot.md)** | Employee Data Validation | The **closed loop** — detection across the population feeding completion | Medium | Workday Solutions |
| **[UC-0005](uc-0005-onboarding-assistant.md)** | Onboarding Assistant | The pattern **extends to a second journey stage** at lower cost | Medium | HR Ops |

**Alongside, not counted:** [UC-0002 HR Policy Chat Assistant](uc-0002-hr-policy-chat-assistant.md) — free on the Copilot chat harness for Microsoft 365 Copilot-licensed users, and an adoption vehicle rather than an agentic exemplar. It answers; it does not act.

> **UC-0010 is expected to be mostly workflow.** That is deliberate. A Level 3 organisation is one that knows where an agent earns its place — see [ADR-0011](../../../docs/adr/0011-workflow-first-process-architecture.md).

---

## Everything else — by suggested wave

### Wave 2 — service delivery at scale

| # | Use case | Complexity | HR owner |
|---|---|---|---|
| [UC-0004](uc-0004-hr-case-classification-bot.md) | HR Case Classification Bot | Medium | HR Ops |
| [UC-0006](uc-0006-job-description-generator.md) | Job Description Generator | Low | Talent Acquisition |
| [UC-0018](uc-0018-onboarding-checklist-rebuild.md) | Onboarding Checklist Rebuild | Medium | HR Ops CH |

### Wave 3 — assisted judgement

| # | Use case | Complexity | HR owner |
|---|---|---|---|
| [UC-0003](uc-0003-employee-self-service-assistant.md) | Employee Self-Service Assistant | Medium | Workday Solutions |
| [UC-0007](uc-0007-candidate-screening-summary.md) | Candidate Screening Summary | Medium | Talent Acquisition |
| [UC-0011](uc-0011-learning-recommendation-agent.md) | Learning Recommendation Agent | Medium | L&D |
| [UC-0013](uc-0013-performance-review-draft-assistant.md) | Performance Review Draft Assistant | Low | HRBP |

### Wave 4 — analytics and prediction

| # | Use case | Complexity | HR owner |
|---|---|---|---|
| [UC-0009](uc-0009-workforce-insights-assistant.md) | Workforce Insights Assistant | High | People Analytics |
| [UC-0014](uc-0014-continuous-performance-insights.md) | Continuous Performance Insights | High | Talent Management |
| [UC-0015](uc-0015-leadership-pipeline-prediction.md) | Leadership Pipeline Prediction | High | HR Leadership |
| [UC-0016](uc-0016-skills-inference-engine.md) | Skills Inference Engine | High | Talent Management |
| [UC-0019](uc-0019-attrition-risk-insight-lite.md) | Attrition Risk Insight Lite | High | People Analytics |

### Deferred

| # | Use case | Why deferred |
|---|---|---|
| [UC-0008](uc-0008-salary-benchmark-assistant.md) | Salary Benchmark Assistant | Marked Phase 2 by HR. Highest risk, highest complexity, medium value |
| [UC-0012](uc-0012-payroll-anomaly-detection.md) | Payroll Anomaly Detection | Local payroll, high compliance impact, 20+ system variants |
| [UC-0017](uc-0017-pre-hire-process-orchestration.md) | Pre-hire Process Orchestration | The process is *still open*. Depends on the MVP and on Workday/PeopleDoc/SAP decisions |

---

## By journey stage

| Stage | Use cases |
|---|---|
| **Hire** | UC-0006 Job Description Generator · UC-0007 Candidate Screening Summary |
| **Pre-board** | **[UC-0001](uc-0001-personal-master-data-completion-agent/README.md) Personal Master Data Completion Agent — MVP** · UC-0017 Pre-hire Process Orchestration |
| **Onboard** | **[UC-0005](uc-0005-onboarding-assistant.md) Onboarding Assistant — MVP** · UC-0018 Onboarding Checklist Rebuild |
| **Enable** | UC-0011 Learning Recommendation · UC-0013 Performance Review Draft · UC-0014 Continuous Performance Insights |
| **Grow** | UC-0015 Leadership Pipeline Prediction · UC-0016 Skills Inference Engine |
| **Change** | UC-0008 Salary Benchmark Assistant |
| **Offboard** | *(none — see the coverage gap below)* |
| **Cross — Service Delivery** | UC-0002 HR Policy Chat · UC-0003 Employee Self-Service · UC-0004 Case Classification |
| **Cross — Operations** | **[UC-0010](uc-0010-employee-data-validation-bot.md) Employee Data Validation — MVP** · UC-0012 Payroll Anomaly Detection |
| **Cross — Analytics** | UC-0009 Workforce Insights · UC-0019 Attrition Risk |

---

## Three observations

**The Offboard stage has no use cases.** Nothing in the portfolio addresses leaving, access revocation confirmation, knowledge handover or alumni records — despite the compliance exposure, and despite the ServiceNow integration already providing the hook. Worth asking HR Operations whether this reflects an absence of pain or an absence of representation.

**Five use cases carry a real employment-decision adjacency** — UC-0007 Candidate Screening, UC-0008 Salary Benchmark, UC-0014 Continuous Performance, UC-0015 Leadership Pipeline, UC-0019 Attrition Risk. Each needs a named human decision-maker who sees the underlying evidence, not just the agent's output. That is a governance commitment, not a build task, and it should be made before any of them starts.

**Several may not need an agent at all.** UC-0010 could be a scheduled report if its rules are deterministic. UC-0015 and UC-0019 are predictive modelling, not conversation. UC-0016 may already be a Workday Skills Cloud capability. Each idea document asks that question rather than assuming the answer — building an agent where a report would do is the most expensive kind of success.

---

## Sources

- `GF_HR AI Use case list.xlsx` — sheets *T-Shirt Size BizValue* (16 use cases) and *HR Ops CH* (2 pain points, captured as UC-0017 and UC-0018)
- `GFAG_Workday Information for Microsoft.pptx` — system landscape and Workday functional areas in use
- `PRD_Personal_Master_Data_Completion_Agent_Switzerland_Draft_0.1`
- `BOM_Artefacts_Personal_Master_Data_Completion_Agent_Switzerland_Draft_0.1`
