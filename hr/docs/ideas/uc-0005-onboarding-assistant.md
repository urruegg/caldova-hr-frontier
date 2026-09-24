# UC-0005 — Onboarding Assistant

> **Status:** **IN MVP SCOPE** — selected, not yet specified
> **Journey stage:** Onboard
> **HR process area:** HR Service Delivery
> **HR owner:** HR Ops
> **Position:** **MVP use case 3 of 3**
>
> **Source:** GF HR AI use case list. This document expands the list entry into a reviewable idea. It is **in MVP scope but has no PRD yet** — the requirements are written next, not assumed from here.

---

> ## ⬛ IN MVP SCOPE — use case 3 of 3
>
> **Selected as the reuse test.** The argument for building a platform rather than an agent is that the second use case costs less than the first. UC-0005 is the cheapest honest test of that claim: a different journey stage, the same process pattern, the same governed integration, the same control plane.
>
> **The MVP's exit criterion runs through this use case.** If UC-0005 costs roughly what UC-0001 cost, the reuse thesis is wrong — and three use cases is a far cheaper place to discover that than thirteen. Measure the build effort deliberately.
>
> It is also the pattern Microsoft names for HR: an onboarding workflow that calls an agent for the part needing judgement.
>
> **Not yet specified.** No PRD exists. It graduates into its own folder when one is written.


## 1. The Idea

An AI-driven onboarding companion guiding new employees through their onboarding journey.

| | |
|---|---|
| **Business objective** | Better employee experience |
| **Business value** | High |
| **Expected outcome (KPI)** | +20% onboarding satisfaction |
| **Complexity** | Medium |
| **Priority** | High |
| **Change timeframe** | 1 – 3 months |
| **Tool** | Copilot |
| **Data source** | Workday onboarding |
| **Key personas** | New Hires; Hiring Managers; HR Ops; Onboarding Coordinators |
| **Risk type** | Medium |

**Key results as stated by HR:** New-hire task completion; onboarding satisfaction; time to productivity; HR onboarding effort

**Risks as stated by HR:** Incomplete onboarding content; inconsistent local processes; over-reliance on AI

---

## 2. Where It Sits

**Journey stage:** Onboard

See [`hr-journey-and-raci.md`](../../../docs/hr-journey-and-raci.md) for the full journey and the placement of every use case.

---

## 3. Platform Fit

**Harness:** **Copilot chat harness** for the knowledge half. If it must read and update task state, that is a **separate** agent or a declared write envelope.

**Write envelope:** **Read-only in the first increment.** Task completion updates, if added, need a declared envelope.

**Grounding:** Workday onboarding content plus approved local onboarding material, versioned with named owners.

**Data classification:** **Internal** for content; **personal** where it references the individual's own tasks.

**Employment-decision surface:** None.

### What it refuses

- Any question about the new joiner's own contract, pay or personal circumstances
- A local process variation the approved content does not cover
- Anything a manager or HR should answer personally

---

## 4. Assessment

The listed risk *inconsistent local processes* is the design problem. Switzerland onboarding is not Germany onboarding. Either scope to one country first, or model locality explicitly — do not average it.

*Over-reliance on AI* is a real concern for a new joiner who does not yet know what normal looks like. The assistant should route to a human buddy or manager readily, not exhaustively answer.

This overlaps the GF HR Ops CH finding that *the Workday onboarding checklist is not helpful* — see [UC-18](uc-0018-onboarding-checklist-rebuild.md). Consider sequencing them together.

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
| 1 | Is the stated KPI baseline measurable today? | HR Ops |
| 2 | Does the grounding source exist, with a named content owner and review cadence? | HR Ops |
| 3 | Which country or population is in scope for a first increment? | HR Ops |
| 4 | What is the smallest version of this that would prove the value? | DAAI |
