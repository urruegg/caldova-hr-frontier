# UC-0017 — Pre-hire Process Orchestration

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-24 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | HR Use Case Portfolio |
| **References** | [HR Solution Functional Design Intake](../../../docs/specs/2026-09-24-hr-solution-functional-design-intake-design.md) |

> **Status:** Idea — draft for review
> **Journey stage:** Pre-board
> **HR process area:** HR Operations (CH)
> **HR owner:** HR Ops CH
> **Suggested wave:** Deferred — depends on the MVP
>
> **Source:** GF HR AI use case list. This document expands the list entry into a reviewable idea; it is **not** an approved requirement.

---

## 1. The Idea

The pre-hire process spans Workday, PeopleDoc, Workday again and SAP, and is still open. Manual effort is high and the process is ad-hoc.

| | |
|---|---|
| **Business objective** | Close the pre-hire gap end to end |
| **Business value** | High |
| **Expected outcome (KPI)** | Pre-hire cycle time; manual effort |
| **Complexity** | High |
| **Priority** | High |
| **Change timeframe** | > 6 months |
| **Tool** | Power Platform + Copilot Studio |
| **Data source** | Workday, PeopleDoc, SAP |
| **Key personas** | HR Ops CH; Workday Solutions; Local Payroll |
| **Risk type** | High |

**Key results as stated by HR:** Pre-hire cycle time; manual handoffs eliminated; data completeness at day one

**Risks as stated by HR:** Process not yet defined; four-system span; local variation

---

## 2. Where It Sits

**Journey stage:** Pre-board

See [`hr-journey-and-raci.md`](../../../docs/hr-journey-and-raci.md) for the full journey and the placement of every use case.

---

## 3. Platform Fit

**Harness:** **GitHub Copilot harness** for orchestration, if built as an agent at all.

**Write envelope:** Would require multiple declared envelopes — one per target system. **Define them separately, never as one broad permission.**

**Grounding:** The defined pre-hire process — **which does not yet exist in an agreed form.**

**Data classification:** **Personal.**

**Employment-decision surface:** Process orchestration, not decision-making — provided each write stays within its envelope.

### What it refuses

- Acting where the process is undefined
- Writing to SAP payroll without a declared, approved envelope

---

## 4. Assessment

**Source: GF HR Ops CH pain point list** — *"Prehire Process still open… Workday – PeopleDoc – Workday – SAP"*, frequency ad-hoc, manual effort **high**.

**The process is described as still open.** That is the blocker: you cannot orchestrate an undefined process. Defining it is the prerequisite, and it is HR work, not platform work.

**The MVP is the first slice of this use case.** It automates one step (master data completion) of the larger flow. Proving it is the right way to earn the right to attempt the rest.

Open question J-06: should this absorb the MVP once proven, or stay separate?

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
| 1 | Is the stated KPI baseline measurable today? | HR Ops CH |
| 2 | Does the grounding source exist, with a named content owner and review cadence? | HR Ops CH |
| 3 | Which country or population is in scope for a first increment? | HR Ops CH |
| 4 | What is the smallest version of this that would prove the value? | DAAI |
