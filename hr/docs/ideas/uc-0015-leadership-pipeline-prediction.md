# UC-0015 — Leadership Pipeline Prediction

> **Status:** Idea — draft for review
> **Journey stage:** Grow
> **HR process area:** Succession Planning
> **HR owner:** HR Leadership
> **Suggested wave:** 4
>
> **Source:** GF HR AI use case list. This document expands the list entry into a reviewable idea; it is **not** an approved requirement.

---

## 1. The Idea

Identifies future leaders using performance, potential and leadership competency data.

| | |
|---|---|
| **Business objective** | Strong leadership continuity |
| **Business value** | High |
| **Expected outcome (KPI)** | Succession coverage %; bench strength |
| **Complexity** | High |
| **Priority** | High |
| **Change timeframe** | > 6 months |
| **Tool** | Workday Talent + predictive models |
| **Data source** | Performance, career history |
| **Key personas** | HR Leadership; Talent Management; HRBPs; Managers |
| **Risk type** | High |

**Key results as stated by HR:** Succession coverage; bench strength; diversity of successor slate; critical role coverage

**Risks as stated by HR:** Bias in predictive models; sensitive career data; governance and transparency

---

## 2. Where It Sits

**Journey stage:** Grow

See [`hr-journey-and-raci.md`](../../../docs/hr-journey-and-raci.md) for the full journey and the placement of every use case.

---

## 3. Platform Fit

**Harness:** Predictive modelling, not a conversational agent. **Different tool class — assess separately.**

**Write envelope:** **No write.** Input to a human succession process.

**Grounding:** Performance and career history, with a documented and reviewed feature set.

**Data classification:** **Personal and highly sensitive.** Career trajectory data.

**Employment-decision surface:** **Directly employment-affecting.** Succession shapes careers. This is the highest-stakes item in the portfolio alongside compensation.

### What it refuses

- Producing a ranked list of individuals presented as a prediction
- Any inference using or correlated with protected characteristics
- Operating without an explainability mechanism

---

## 4. Assessment

*Bias in predictive models* is listed first, and it is the defining risk. A model trained on historical promotion data learns historical promotion patterns — including their biases. The listed KR *diversity of successor slate* is in direct tension with that, which is worth naming openly.

*Governance and transparency requirements* imply a formal model governance process: documented features, tested fairness, periodic revalidation, and a named accountable owner.

**Recommend treating this as a Talent Management exercise supported by analytics, not as an agent.** The conversational framing adds risk without adding value.

If built: employees should know they are being assessed for succession potential, and on what basis.

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
| 1 | Is the stated KPI baseline measurable today? | HR Leadership |
| 2 | Does the grounding source exist, with a named content owner and review cadence? | HR Leadership |
| 3 | Which country or population is in scope for a first increment? | HR Leadership |
| 4 | What is the smallest version of this that would prove the value? | DAAI |
