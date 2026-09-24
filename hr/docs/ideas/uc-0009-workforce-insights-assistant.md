# UC-0009 — Workforce Insights Assistant

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-24 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | HR Use Case Portfolio |
| **References** | [HR Solution Functional Design Intake](../../../docs/specs/2026-09-24-hr-solution-functional-design-intake-design.md) |

> **Status:** Idea — draft for review
> **Journey stage:** Cross-cutting — Analytics
> **HR process area:** HR Analytics
> **HR owner:** People Analytics
> **Suggested wave:** 4
>
> **Source:** GF HR AI use case list. This document expands the list entry into a reviewable idea; it is **not** an approved requirement.

---

## 1. The Idea

An analytics assistant letting HR leaders ask business questions in natural language.

| | |
|---|---|
| **Business objective** | Faster decision making |
| **Business value** | High |
| **Expected outcome (KPI)** | 50% faster reporting |
| **Complexity** | High |
| **Priority** | Medium |
| **Change timeframe** | 4 – 6 months |
| **Tool** | Copilot + Power BI |
| **Data source** | Workday + BI |
| **Key personas** | HR Leadership; HRBPs; Local HR |
| **Risk type** | Medium |

**Key results as stated by HR:** Report preparation time; insight adoption; number of recurring reports automated

**Risks as stated by HR:** Data quality gaps; misinterpretation of insights; dependency on BI semantic model

---

## 2. Where It Sits

**Journey stage:** Cross-cutting — Analytics

See [`hr-journey-and-raci.md`](../../../docs/hr-journey-and-raci.md) for the full journey and the placement of every use case.

---

## 3. Platform Fit

**Harness:** **GitHub Copilot harness**, or Power BI's own natural-language capability. Compare before committing.

**Write envelope:** **No write.** Query and present.

**Grounding:** The governed BI semantic model. **Not raw Workday** — the semantic model is where definitions live.

**Data classification:** **Internal** in aggregate; becomes **personal** at small group sizes. The minimum-group-size rule is the boundary.

**Employment-decision surface:** Indirect. Insights shape workforce decisions, so **definition integrity matters more than response speed**.

### What it refuses

- Aggregations below the minimum group size
- Any query that resolves to an individual
- Presenting a correlation as a cause

---

## 4. Assessment

*Dependency on BI semantic model* is listed as a risk and is really a prerequisite — if the semantic model is weak, this use case amplifies the weakness at conversational speed.

*Misinterpretation of insights* is the subtle risk: natural language makes it easy to ask a question the data cannot answer and receive a confident-looking number. Consider requiring the agent to state the definition it used.

Recommend this **after** the data-quality use cases (UC-10, and the MVP) have run. Faster access to poor data is not a win.

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
| 1 | Is the stated KPI baseline measurable today? | People Analytics |
| 2 | Does the grounding source exist, with a named content owner and review cadence? | People Analytics |
| 3 | Which country or population is in scope for a first increment? | People Analytics |
| 4 | What is the smallest version of this that would prove the value? | DAAI |
