# UC-0014 — Continuous Performance Insights

> **Status:** Idea — draft for review
> **Journey stage:** Enable
> **HR process area:** Performance Management
> **HR owner:** Talent Management
> **Suggested wave:** 4
>
> **Source:** GF HR AI use case list. This document expands the list entry into a reviewable idea; it is **not** an approved requirement.

---

## 1. The Idea

Analyses feedback, goals and outputs to identify trends, strengths and development areas.

| | |
|---|---|
| **Business objective** | Better performance decisions |
| **Business value** | High |
| **Expected outcome (KPI)** | Performance cycle completion %; quality scores |
| **Complexity** | High |
| **Priority** | High |
| **Change timeframe** | > 6 months |
| **Tool** | Workday + NLP analytics |
| **Data source** | Performance reviews, feedback tools |
| **Key personas** | Managers; HRBPs; Talent Management; Employees |
| **Risk type** | High |

**Key results as stated by HR:** Performance cycle completion; feedback quality; trend insight usage; manager action

**Risks as stated by HR:** Subjective data interpretation; privacy concerns; poor feedback data quality; trust

---

## 2. Where It Sits

**Journey stage:** Enable

See [`hr-journey-and-raci.md`](../../../docs/hr-journey-and-raci.md) for the full journey and the placement of every use case.

---

## 3. Platform Fit

**Harness:** To be determined. Consider whether this is an agent or an analytics capability.

**Write envelope:** **No write.** Insight only.

**Grounding:** Performance reviews and feedback, within the entitlement of the person asking.

**Data classification:** **Personal and sensitive.**

**Employment-decision surface:** **Employment-affecting.** *Better performance decisions* is the stated objective, which makes the human decision-maker and their evidence the central design question.

### What it refuses

- Producing an individual-level assessment presented as objective
- Inferring intent or attitude from written feedback
- Any output that would function as an unreviewed performance judgement

---

## 4. Assessment

*Subjective data interpretation* and *trust* are both listed, and they are the same problem: NLP over written feedback produces confident summaries of inherently subjective text.

Employee awareness is not optional here. Analysing feedback about people without their knowledge is a trust failure regardless of legality.

**The strongest version of this use case may be aggregate, not individual** — feedback quality trends across a population, rather than a per-person read. Worth testing that framing with Talent Management before committing to individual insight.

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
