# UC-0003 — Employee Self-Service Assistant

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-24 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | HR Use Case Portfolio |
| **References** | [HR Solution Functional Design Intake](../../../docs/specs/2026-09-24-hr-solution-functional-design-intake-design.md) |

> **Status:** Idea — draft for review
> **Journey stage:** Cross-cutting — HR Service Delivery
> **HR process area:** HR Service Delivery
> **HR owner:** Workday Solutions
> **Suggested wave:** 2
>
> **Source:** GF HR AI use case list. This document expands the list entry into a reviewable idea; it is **not** an approved requirement.

---

## 1. The Idea

A virtual HR assistant helping employees access their personal HR information.

| | |
|---|---|
| **Business objective** | Faster HR responses |
| **Business value** | High |
| **Expected outcome (KPI)** | 40% faster response |
| **Complexity** | Medium |
| **Priority** | High |
| **Change timeframe** | 4 – 6 months |
| **Tool** | Workday + Copilot |
| **Data source** | Workday HCM |
| **Key personas** | All Employees; Workday Solutions Team; Local HR |
| **Risk type** | High |

**Key results as stated by HR:** Self-service adoption; reduction in HR inquiries; response time; employee satisfaction

**Risks as stated by HR:** Personal data privacy; integration reliability; unclear ownership between Workday and Copilot

---

## 2. Where It Sits

**Journey stage:** Cross-cutting — HR Service Delivery

See [`hr-journey-and-raci.md`](../../../docs/hr-journey-and-raci.md) for the full journey and the placement of every use case.

---

## 3. Platform Fit

**Harness:** **Standard or GitHub Copilot harness** depending on whether it only retrieves, or also acts. Decide before creation — the choice is permanent.

**Write envelope:** **Read-only in the first increment.** Any write to Workday requires a declared envelope per ADR-0008, and should be a separate, later decision.

**Grounding:** Workday HCM, read live through the governed Workday Access Layer. **Never a cached copy** — ADR-0005.

**Data classification:** **Personal.** This agent surfaces an individual's own employee data. Highest care in the portfolio outside payroll.

**Employment-decision surface:** None, if read-only. Revisit if it gains write capability.

### What it refuses

- Any request for another person's data
- Anything the asking user is not entitled to see in Workday
- A change request that Workday's own self-service should handle

---

## 4. Assessment

The listed risk names it precisely: *unclear ownership between Workday and Copilot*. Resolve that before build — who owns the answer when Workday and the agent disagree?

**Identity is the whole control.** The agent must act as the asking user, not as a service identity, or it becomes a way to read anyone's record.

Workday already has self-service. The honest question is what this adds — convenience of surface, or genuinely faster resolution? Answer it before building.

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
| 1 | Is the stated KPI baseline measurable today? | Workday Solutions |
| 2 | Does the grounding source exist, with a named content owner and review cadence? | Workday Solutions |
| 3 | Which country or population is in scope for a first increment? | Workday Solutions |
| 4 | What is the smallest version of this that would prove the value? | DAAI |
