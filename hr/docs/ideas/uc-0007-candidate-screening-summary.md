# UC-0007 — Candidate Screening Summary

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
> **Suggested wave:** 3
>
> **Source:** GF HR AI use case list. This document expands the list entry into a reviewable idea; it is **not** an approved requirement.

---

## 1. The Idea

Reviews resumes and applications to generate concise candidate summaries.

| | |
|---|---|
| **Business objective** | Better hiring quality |
| **Business value** | High |
| **Expected outcome (KPI)** | Improved shortlist quality |
| **Complexity** | Medium |
| **Priority** | High |
| **Change timeframe** | 4 – 6 months |
| **Tool** | Copilot + Workday Recruitment |
| **Data source** | Workday |
| **Key personas** | Recruiters; Hiring Managers; Talent Acquisition |
| **Risk type** | High |

**Key results as stated by HR:** Screening cycle time; shortlist quality; recruiter productivity

**Risks as stated by HR:** Bias/fairness concerns; explainability of rankings; data privacy and candidate consent

---

## 2. Where It Sits

**Journey stage:** Hire

See [`hr-journey-and-raci.md`](../../../docs/hr-journey-and-raci.md) for the full journey and the placement of every use case.

---

## 3. Platform Fit

**Harness:** **GitHub Copilot harness** — reads documents and reasons across them.

**Write envelope:** **No write.** Produces a summary attached to the candidate record for a human to read.

**Grounding:** Application materials and the requisition. Nothing else.

**Data classification:** **Personal**, and candidate data carries consent obligations distinct from employee data.

**Employment-decision surface:** **This is the portfolio's most sensitive employment-decision adjacency.** A summary that shapes a shortlist influences hiring. The human decision-maker must see the underlying application, not just the summary.

### What it refuses

- **Ranking or scoring candidates** — summarise, never rank
- Inferring protected characteristics, or anything correlated with them
- Recommending advance or reject
- Processing a candidate who has not consented to automated processing, where consent is required

---

## 4. Assessment

The risk register already says *bias/fairness* and *explainability of rankings* — the honest mitigation is **do not rank**. Summarise consistently and let humans compare.

Consent and candidate privacy vary by country. Switzerland-first scoping applies here too.

Recommend an explicit fairness review with Privacy before build, and a sampling process after launch — not an accuracy metric alone.

Consider whether the summary should be **structured to the requisition criteria** rather than free-form. Structure reduces the room for incidental bias and makes comparison fairer.

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
