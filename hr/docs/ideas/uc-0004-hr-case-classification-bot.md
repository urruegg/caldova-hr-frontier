# UC-0004 — HR Case Classification Bot

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
> **HR owner:** HR Ops
> **Suggested wave:** 2
>
> **Source:** GF HR AI use case list. This document expands the list entry into a reviewable idea; it is **not** an approved requirement.

---

## 1. The Idea

Automatically analyses incoming HR service requests received through email and routes them.

| | |
|---|---|
| **Business objective** | Faster resolution |
| **Business value** | Medium |
| **Expected outcome (KPI)** | -35% resolution time |
| **Complexity** | Medium |
| **Priority** | High |
| **Change timeframe** | 1 – 3 months |
| **Tool** | Copilot |
| **Data source** | ServiceNow / Workday |
| **Key personas** | Workday Solutions Team; Local HR & Managers; HR Ops; Employees Raising Cases |
| **Risk type** | Medium |

**Key results as stated by HR:** Auto-classification accuracy; first-contact resolution; case reassignment rate

**Risks as stated by HR:** Misclassification of urgent cases; model drift; change resistance from case handlers

---

## 2. Where It Sits

**Journey stage:** Cross-cutting — HR Service Delivery

See [`hr-journey-and-raci.md`](../../../docs/hr-journey-and-raci.md) for the full journey and the placement of every use case.

---

## 3. Platform Fit

**Harness:** **Standard harness** if classification is rule-shaped; **GitHub Copilot harness** if it must read attachments and reason across them.

**Write envelope:** Writes a **classification and routing decision** to the case record. Declared envelope: category, priority, queue. Never the case resolution itself.

**Grounding:** Historical case data and the approved category taxonomy.

**Data classification:** **Personal**, often **special-category** — HR cases include health, absence and grievance content.

**Employment-decision surface:** Routing is not an employment decision. **But misrouting a grievance is a real harm**, so the refusal path matters more than the accuracy rate.

### What it refuses

- A case it cannot classify above the confidence threshold — routes to a human triage queue
- Anything flagged as urgent, sensitive or a grievance — those go to a human immediately
- Cases containing special-category data

---

## 4. Assessment

*Misclassification of urgent cases* is listed as a risk and it is the one that matters. Design the urgent path first: anything that might be urgent goes to a human, and the agent's job is to be generous about what 'might be' means.

*Change resistance from case handlers* is also listed. Involve them in defining the taxonomy — a classifier imposed on the people who will correct it fails quietly.

Measure reassignment rate, not just classification accuracy. Reassignment is what the handlers actually experience.

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
