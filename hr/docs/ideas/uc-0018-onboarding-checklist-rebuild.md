# UC-0018 — Onboarding Checklist Rebuild

> **Status:** Idea — draft for review
> **Journey stage:** Onboard
> **HR process area:** HR Operations (CH)
> **HR owner:** HR Ops CH
> **Suggested wave:** 2
>
> **Source:** GF HR AI use case list. This document expands the list entry into a reviewable idea; it is **not** an approved requirement.

---

## 1. The Idea

The Workday onboarding checklist is reported as not helpful. Rebuild it as a usable, role-aware checklist.

| | |
|---|---|
| **Business objective** | A checklist people actually use |
| **Business value** | Medium |
| **Expected outcome (KPI)** | Checklist completion; day-one readiness |
| **Complexity** | Medium |
| **Priority** | Medium |
| **Change timeframe** | 1 – 3 months |
| **Tool** | Power Platform + Workday |
| **Data source** | Workday, PeopleDoc, SAP |
| **Key personas** | New Hires; Hiring Managers; HR Ops CH |
| **Risk type** | Medium |

**Key results as stated by HR:** Checklist completion rate; day-one readiness; HR follow-up effort

**Risks as stated by HR:** Duplicating Workday functionality; maintaining two checklists

---

## 2. Where It Sits

**Journey stage:** Onboard

See [`hr-journey-and-raci.md`](../../../docs/hr-journey-and-raci.md) for the full journey and the placement of every use case.

---

## 3. Platform Fit

**Harness:** May not need an agent. **A well-designed app may be the answer.**

**Write envelope:** Task state in Dataverse — process state, permitted under ADR-0007. **No employee master data.**

**Grounding:** The onboarding task model and local process content.

**Data classification:** **Internal** for task definitions; **personal** for an individual's task state.

**Employment-decision surface:** None.

### What it refuses

- Duplicating data Workday owns

---

## 4. Assessment

**Source: GF HR Ops CH pain point list** — *"Onboarding Checklist – the one from WD is not helpful"*, frequency ad-hoc, manual effort **medium**.

**Ask why it is not helpful before rebuilding it.** If the Workday checklist is configurable, configuration is cheaper than a parallel system — and avoids the *two checklists* risk that is the main danger here.

If rebuilt: task state belongs in Dataverse as process state. Employee data stays in Workday.

Pairs naturally with [UC-05](uc-0005-onboarding-assistant.md) — the assistant answers questions about the checklist this defines.

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
