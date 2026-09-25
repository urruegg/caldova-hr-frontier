# UC-0006 — Job Description Generator

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-24 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | HR Use Case Portfolio |
| **References** | [HR Solution Functional Design Intake](../../../docs/specs/2026-09-24-hr-solution-functional-design-intake-design.md) |

> **Status:** Idea — draft for review
> **Journey stage:** Hire
> **HR process area:** Recruitment
> **HR owner:** Talent Acquisition
> **Suggested wave:** 2
>
> **Source:** GF HR AI use case list. This document expands the list entry into a reviewable idea; it is **not** an approved requirement.

---

## 1. The Idea

Assists hiring managers by generating standardised, inclusive, role-specific job descriptions.

| | |
|---|---|
| **Business objective** | Faster hiring prep |
| **Business value** | Medium |
| **Expected outcome (KPI)** | -50% JD creation time |
| **Complexity** | Low |
| **Priority** | High |
| **Change timeframe** | 1 – 3 months |
| **Tool** | Copilot |
| **Data source** | Job architecture data |
| **Key personas** | Recruiters; Hiring Managers; Talent Acquisition |
| **Risk type** | Medium |

**Key results as stated by HR:** JD draft cycle time; template compliance; recruiter satisfaction; hiring manager satisfaction

**Risks as stated by HR:** Generic or biased language; inconsistent job architecture data; approval governance

---

## 2. Where It Sits

**Journey stage:** Hire

See [`hr-journey-and-raci.md`](../../../docs/hr-journey-and-raci.md) for the full journey and the placement of every use case.

---

## 3. Platform Fit

**Harness:** **Copilot chat harness** or **standard harness** — this is drafting, not multi-step orchestration.

**Write envelope:** **No write to a system of record.** It produces a draft a human edits and submits.

**Grounding:** GF job architecture data and approved JD templates.

**Data classification:** **Internal.** No personal data involved.

**Employment-decision surface:** None directly. **But a JD shapes who applies**, so biased language has a downstream effect on people — which is why the inclusive-language check is a requirement, not a nicety.

### What it refuses

- Generating a JD for a role with no job architecture entry
- Language the inclusive-language check flags
- Setting a grade, salary range or level — those come from job architecture, not from generation

---

## 4. Assessment

Lowest-risk, highest-visibility recruitment use case. Good early confidence-builder.

*Inconsistent job architecture data* is listed as a risk and is the actual constraint — the generator is only as good as the architecture it reads. This may surface data-quality work nobody has scoped.

Set the approval governance before launch: who signs off a generated JD, and does the recruiter know it was generated?

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
| 1 | Is the stated KPI baseline measurable today? | Talent Acquisition |
| 2 | Does the grounding source exist, with a named content owner and review cadence? | Talent Acquisition |
| 3 | Which country or population is in scope for a first increment? | Talent Acquisition |
| 4 | What is the smallest version of this that would prove the value? | DAAI |
