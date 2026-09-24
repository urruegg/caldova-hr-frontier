# UC-0011 — Learning Recommendation Agent

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-24 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | HR Use Case Portfolio |
| **References** | [HR Solution Functional Design Intake](../../../docs/specs/2026-09-24-hr-solution-functional-design-intake-design.md) |

> **Status:** Idea — draft for review
> **Journey stage:** Enable
> **HR process area:** Learning
> **HR owner:** L&D
> **Suggested wave:** 3
>
> **Source:** GF HR AI use case list. This document expands the list entry into a reviewable idea; it is **not** an approved requirement.

---

## 1. The Idea

Recommends personalised learning paths, courses and development programmes.

| | |
|---|---|
| **Business objective** | Skill development |
| **Business value** | Medium |
| **Expected outcome (KPI)** | +30% course adoption |
| **Complexity** | Medium |
| **Priority** | High |
| **Change timeframe** | 4 – 6 months |
| **Tool** | Workday Learning + Copilot |
| **Data source** | Skills data |
| **Key personas** | Employees; Managers; Learning Team; Talent Management Team |
| **Risk type** | Medium |

**Key results as stated by HR:** Course adoption; learning path completion; skills gap closure; employee engagement

**Risks as stated by HR:** Poor skills data quality; irrelevant recommendations; low adoption without manager support

---

## 2. Where It Sits

**Journey stage:** Enable

See [`hr-journey-and-raci.md`](../../../docs/hr-journey-and-raci.md) for the full journey and the placement of every use case.

---

## 3. Platform Fit

**Harness:** **Standard or GitHub Copilot harness** depending on reasoning depth.

**Write envelope:** **No write** in the first increment. Enrolment, if added, is the employee's action.

**Grounding:** Workday Learning catalogue and skills data.

**Data classification:** **Personal** — an individual's skills and learning history.

**Employment-decision surface:** **Adjacent.** A recommendation is not a decision, but 'the system said you need this' can feel like one. Framing matters.

### What it refuses

- Recommending learning as a response to a performance concern — that is a manager conversation
- Inferring a development need from performance data without the employee's involvement

---

## 4. Assessment

*Poor skills data quality* is listed as the first risk, and it is a hard dependency on [UC-16](uc-0016-skills-inference-engine.md). Recommendations built on thin skills data will be generic, which is exactly the *irrelevant recommendations* risk.

*Low adoption without manager support* is an adoption design problem, not a technical one. Build the manager view alongside the employee view.

Consider whether recommendations should be **opt-in**. Employee agency over development is part of the value.

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
| 1 | Is the stated KPI baseline measurable today? | L&D |
| 2 | Does the grounding source exist, with a named content owner and review cadence? | L&D |
| 3 | Which country or population is in scope for a first increment? | L&D |
| 4 | What is the smallest version of this that would prove the value? | DAAI |
