# UC-0019 — Attrition Risk Insight Lite

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-24 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | HR Use Case Portfolio |
| **References** | [HR Solution Functional Design Intake](../../../docs/specs/2026-09-24-hr-solution-functional-design-intake-design.md) |

> **Status:** Idea — draft for review
> **Journey stage:** Cross-cutting — Analytics
> **HR process area:** Workforce Planning
> **HR owner:** People Analytics
> **Suggested wave:** 4
>
> **Source:** GF HR AI use case list. This document expands the list entry into a reviewable idea; it is **not** an approved requirement.

---

## 1. The Idea

Analyses workforce trends, engagement indicators and absence data to surface attrition risk.

| | |
|---|---|
| **Business objective** | Retention improvement |
| **Business value** | Medium |
| **Expected outcome (KPI)** | -5% attrition |
| **Complexity** | High |
| **Priority** | Medium |
| **Change timeframe** | > 6 months |
| **Tool** | Copilot + Power BI |
| **Data source** | Workday + history data |
| **Key personas** | HRBPs; People Managers; People Analytics; HR Leadership |
| **Risk type** | High |

**Key results as stated by HR:** Attrition risk identification accuracy; retention action completion; regretted attrition

**Risks as stated by HR:** Employee privacy and ethics; false positives; manager misuse; need for clear intervention

---

## 2. Where It Sits

**Journey stage:** Cross-cutting — Analytics

See [`hr-journey-and-raci.md`](../../../docs/hr-journey-and-raci.md) for the full journey and the placement of every use case.

---

## 3. Platform Fit

**Harness:** Predictive analytics rather than a conversational agent.

**Write envelope:** **No write.**

**Grounding:** Workday and historical workforce data, with a documented feature set.

**Data classification:** **Personal and sensitive.** Engagement and absence indicators are especially sensitive.

**Employment-decision surface:** **Consequential.** An attrition flag can change how someone is treated — which is itself a cause of attrition.

### What it refuses

- Individual-level risk scores exposed to line managers
- Any use of absence or health-adjacent data without an explicit privacy assessment
- Producing a score without a documented intervention path

---

## 4. Assessment

*Manager misuse* is listed and is the central risk. A manager told an employee is a flight risk may act on it in ways that harm the employee and become self-fulfilling.

**Strongly recommend aggregate-only.** Team, function and tenure-band patterns support retention strategy without labelling individuals. The listed KR *regretted attrition* can be measured at population level.

*Need for clear intervention* is the honest constraint: a risk score with no agreed action is surveillance without benefit. Define the intervention before the model.

Absence data is health-adjacent. A privacy assessment is mandatory, not advisory.

---

## 5. Before This Becomes a Requirement

The seven declarations from [`hr-journey-and-raci.md`](../../../docs/hr-journey-and-raci.md) §9 must be answerable:

- [ ] **Write envelope** — what may it write, where, under what conditions?
- [ ] **Refusal set** — what does it refuse, and what happens then?
- [ ] **Escalation path** — who is the named human, and how are they reached?
- [ ] **Grounding sources** — which approved sources, with which owner and review date?
- [ ] **Data classification** — confirmed with Privacy.
- [ ] **Employment-decision surface** — if any output influences a decision about a person, who decides and what do they see?
- [ ] **Measurement** — what changes, and how is that observed? Baseline captured before build.

Plus, for this use case specifically:

- [ ] Confirm the harness choice — **it cannot be changed after the agent is created**.
- [ ] Confirm the KPI baseline exists, or can be established.
- [ ] Confirm the named HR owner has capacity to own the operational outcome.

---

## 6. Open Questions

| # | Question | Owner |
|---|---|---|
| 1 | Is the stated KPI baseline measurable today? | People Analytics |
| 2 | Does the grounding source exist, with a named content owner and review cadence? | People Analytics |
| 3 | Which country or population is in scope for a first increment? | People Analytics |
| 4 | What is the smallest version of this that would prove the value? | DAAI |
