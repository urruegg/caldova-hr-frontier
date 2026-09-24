# UC-0008 — Salary Benchmark Assistant

> **Status:** Idea — draft for review
> **Journey stage:** Change
> **HR process area:** Compensation
> **HR owner:** Comp & Ben
> **Suggested wave:** Deferred — Phase 2
>
> **Source:** GF HR AI use case list. This document expands the list entry into a reviewable idea; it is **not** an approved requirement.

---

## 1. The Idea

Analyses internal compensation structures, job grades and historical salary data.

| | |
|---|---|
| **Business objective** | Pay consistency |
| **Business value** | Medium |
| **Expected outcome (KPI)** | Improved pay equity |
| **Complexity** | High |
| **Priority** | Low (Phase 2) |
| **Change timeframe** | > 6 months |
| **Tool** | Copilot |
| **Data source** | Compensation data |
| **Key personas** | Compensation Team; HRBPs; Hiring Managers |
| **Risk type** | High |

**Key results as stated by HR:** Offer acceptance rate; salary range adherence; pay equity exceptions

**Risks as stated by HR:** Sensitive compensation data exposure; inaccurate benchmarks; governance and legal

---

## 2. Where It Sits

**Journey stage:** Change

See [`hr-journey-and-raci.md`](../../../docs/hr-journey-and-raci.md) for the full journey and the placement of every use case.

---

## 3. Platform Fit

**Harness:** **GitHub Copilot harness** if built. Decide at the time.

**Write envelope:** **No write.** Analysis and reference only.

**Grounding:** Approved internal compensation structures and job grades.

**Data classification:** **Special-category in practice.** Compensation data carries the highest exposure risk in the portfolio.

**Employment-decision surface:** **Directly employment-affecting.** Pay decisions require a named human with full context.

### What it refuses

- Any query that would expose an individual's compensation to someone not entitled to see it
- Recommending a specific salary for a specific person
- Aggregations small enough to identify an individual — enforce a minimum group size

---

## 4. Assessment

**GF has already marked this Phase 2, and that judgement is sound.** It is the highest-risk, highest-complexity item with only medium business value.

The minimum-group-size rule is the control that makes aggregate compensation analysis safe. Define it with Privacy before any prototype.

Note the tension in the objective: *pay equity* is a worthwhile goal, and an agent is a poor instrument for it. Equity analysis is a deliberate, reviewed exercise — not a chat interface.

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
| 1 | Is the stated KPI baseline measurable today? | Comp & Ben |
| 2 | Does the grounding source exist, with a named content owner and review cadence? | Comp & Ben |
| 3 | Which country or population is in scope for a first increment? | Comp & Ben |
| 4 | What is the smallest version of this that would prove the value? | DAAI |
