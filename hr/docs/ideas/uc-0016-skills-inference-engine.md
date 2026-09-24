# UC-0016 — Skills Inference Engine

> **Status:** Idea — draft for review
> **Journey stage:** Grow
> **HR process area:** Talent Management
> **HR owner:** Talent Management
> **Suggested wave:** 4
>
> **Source:** GF HR AI use case list. This document expands the list entry into a reviewable idea; it is **not** an approved requirement.

---

## 1. The Idea

Infers employee skills by analysing job history and project assignments.

| | |
|---|---|
| **Business objective** | Improved workforce visibility |
| **Business value** | High |
| **Expected outcome (KPI)** | Skills coverage %; internal mobility rate |
| **Complexity** | High |
| **Priority** | High |
| **Change timeframe** | > 6 months |
| **Tool** | Workday Skills Cloud |
| **Data source** | Workday |
| **Key personas** | Employees; Managers; Talent Management; HRBPs |
| **Risk type** | High |

**Key results as stated by HR:** Skills profile coverage; inferred skill accuracy; internal mobility rate

**Risks as stated by HR:** Inaccurate skill inference; employee trust; stale job/project data; consent

---

## 2. Where It Sits

**Journey stage:** Grow

See [`hr-journey-and-raci.md`](../../../docs/hr-journey-and-raci.md) for the full journey and the placement of every use case.

---

## 3. Platform Fit

**Harness:** Largely a **Workday Skills Cloud** capability. Assess what Workday provides natively before building anything.

**Write envelope:** Writes **inferred skills** to a profile. Declared envelope: inferred skills are marked as inferred, and the employee can confirm, correct or remove them.

**Grounding:** Workday job history and project assignments.

**Data classification:** **Personal.** Skills profiles shape mobility and opportunity.

**Employment-decision surface:** **Adjacent and consequential.** Skills data drives internal mobility and succession, so an inaccurate inference has a real cost to the individual.

### What it refuses

- Writing an inferred skill as if it were confirmed
- Inferring from data the employee has not been told is used
- Removing an employee-asserted skill

---

## 4. Assessment

*Employee trust* and *consent* are both listed. The design answer is **employee control**: inferred skills are visible to the employee, marked as inferred, and removable. Anything less erodes trust for a marginal coverage gain.

*Stale job/project data* is a hard dependency. Inference from outdated assignment data produces confidently wrong profiles.

**Check Workday Skills Cloud first.** If it already does this, the question is adoption and data quality, not build.

This is a dependency for [UC-11](uc-0011-learning-recommendation-agent.md). Sequence accordingly.

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
| 1 | Is the stated KPI baseline measurable today? | Talent Management |
| 2 | Does the grounding source exist, with a named content owner and review cadence? | Talent Management |
| 3 | Which country or population is in scope for a first increment? | Talent Management |
| 4 | What is the smallest version of this that would prove the value? | DAAI |
