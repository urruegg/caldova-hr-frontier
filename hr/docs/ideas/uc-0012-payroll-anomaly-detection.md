# UC-0012 — Payroll Anomaly Detection

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-24 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | HR Use Case Portfolio |
| **References** | [HR Solution Functional Design Intake](../../../docs/specs/2026-09-24-hr-solution-functional-design-intake-design.md) |

> **Status:** Idea — draft for review
> **Journey stage:** Cross-cutting — HR Operations
> **HR process area:** Payroll (Local)
> **HR owner:** HR Ops / Local Payroll Team
> **Suggested wave:** Deferred
>
> **Source:** GF HR AI use case list. This document expands the list entry into a reviewable idea; it is **not** an approved requirement.

---

## 1. The Idea

Analyses payroll data before execution to detect unusual payment patterns.

| | |
|---|---|
| **Business objective** | Reduced payroll errors and compliance risk |
| **Business value** | High |
| **Expected outcome (KPI)** | Payroll error rate; audit exceptions |
| **Complexity** | High |
| **Priority** | High |
| **Change timeframe** | > 6 months |
| **Tool** | ADP / SAP / Local Payroll |
| **Data source** | Payroll system, time data, benefits |
| **Key personas** | Payroll Team; HR Ops; Finance |
| **Risk type** | High |

**Key results as stated by HR:** Payroll error rate; pre-payroll exceptions detected; audit exceptions; manual rework

**Risks as stated by HR:** High compliance impact; false negatives; local payroll variation; sensitive pay data

---

## 2. Where It Sits

**Journey stage:** Cross-cutting — HR Operations

See [`hr-journey-and-raci.md`](../../../docs/hr-journey-and-raci.md) for the full journey and the placement of every use case.

---

## 3. Platform Fit

**Harness:** To be determined. **This may not be a Copilot Studio use case at all** — anomaly detection over structured payroll data is a different tool shape.

**Write envelope:** **No write. Ever.** Detection and alerting only. Payroll correction is a controlled payroll process.

**Grounding:** Payroll, time and benefits data for the specific local payroll instance.

**Data classification:** **Special-category in practice.** Pay data with the highest compliance exposure in the portfolio.

**Employment-decision surface:** **Payroll is an employment consequence.** Every anomaly is reviewed by a human before payroll runs.

### What it refuses

- Any write to a payroll system
- Suppressing an anomaly it cannot explain — a false positive reviewed is cheaper than a false negative paid

---

## 4. Assessment

**GF context matters here.** Swiss payroll is SAP P01, and there are 20+ local payroll and time systems. This is a *local* use case, not a global platform one — the *local payroll variation* risk is structural.

*False negatives* is the right risk to fear. An anomaly detector that misses a real error is worse than none, because it creates false assurance. Tune for recall, accept false positives.

Workday holds **payment elections only**, not payroll execution. The data this needs is largely outside Workday — check integration feasibility before committing.

Sequence after the local payroll roadmap is clear. Building against 20+ variants is not an MVP.

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
| 1 | Is the stated KPI baseline measurable today? | HR Ops / Local Payroll Team |
| 2 | Does the grounding source exist, with a named content owner and review cadence? | HR Ops / Local Payroll Team |
| 3 | Which country or population is in scope for a first increment? | HR Ops / Local Payroll Team |
| 4 | What is the smallest version of this that would prove the value? | DAAI |
