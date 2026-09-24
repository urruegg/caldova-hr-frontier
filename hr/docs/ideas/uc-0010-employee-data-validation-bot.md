# UC-0010 — Employee Data Validation Bot

> **Status:** **IN MVP SCOPE** — selected, not yet specified
> **Journey stage:** Cross-cutting — HR Operations
> **HR process area:** HR Operations
> **HR owner:** Workday Solutions
> **Position:** **MVP use case 2 of 3**
>
> **Source:** GF HR AI use case list. This document expands the list entry into a reviewable idea. It is **in MVP scope but has no PRD yet** — the requirements are written next, not assumed from here.

---

> ## ⬛ IN MVP SCOPE — use case 2 of 3
>
> **Selected.** UC-0010 closes the loop that UC-0001 opens: the completion agent fills the blanks it has documents for, this finds what is still missing or inconsistent across the whole population. Same data, same owner, same quality problem.
>
> **Expected shape: workflow-first, agent-light.** If the validation rules are deterministic — and most are — this is a scheduled workflow with an agent node only where a rule cannot express the check. **That is not a lesser outcome.** A Level 3 organisation is one that knows where an agent earns its place; see [ADR-0011](../../../docs/adr/0011-workflow-first-process-architecture.md) and FR-0013.
>
> **Not yet specified.** No PRD exists. It graduates into its own folder when one is written — after UC-0001's Definition of Ready is met.


## 1. The Idea

Continuously scans employee master data within Workday to identify missing or inconsistent values.

| | |
|---|---|
| **Business objective** | Data quality improvement |
| **Business value** | Medium |
| **Expected outcome (KPI)** | 90% data accuracy |
| **Complexity** | Medium |
| **Priority** | High |
| **Change timeframe** | 4 – 6 months |
| **Tool** | Workday + Copilot |
| **Data source** | Workday Core HR |
| **Key personas** | Workday Solutions; HR Ops; Data Owners; Payroll Partners |
| **Risk type** | Medium |

**Key results as stated by HR:** Data accuracy rate; number of validation issues detected; correction cycle time

**Risks as stated by HR:** False positives; unclear data ownership; remediation backlog

---

## 2. Where It Sits

**Journey stage:** Cross-cutting — HR Operations

See [`hr-journey-and-raci.md`](../../../docs/hr-journey-and-raci.md) for the full journey and the placement of every use case.

---

## 3. Platform Fit

**Harness:** **GitHub Copilot harness** for multi-step scanning, or a scheduled Power Automate flow if the rules are simple enough not to need an agent at all. **Ask that question first.**

**Write envelope:** **Read-only.** It detects and reports. Correction is the MVP agent's job, or a human's.

**Grounding:** Workday Core HR, read live. The validation rule set, versioned.

**Data classification:** **Personal.** It reads master data, though it reports on completeness rather than content.

**Employment-decision surface:** None.

### What it refuses

- Writing any correction — detection and correction are deliberately separate
- Flagging a field whose ownership is undefined

---

## 4. Assessment

**This is the MVP's natural partner.** The MVP fills blanks it has documents for; this finds every blank and inconsistency across the population. Same data, same owner, same quality problem — running them together compounds the value.

*Remediation backlog* is the listed risk and the likely reality: the first scan will find more than HR can fix. Plan the triage before the first run, or the output becomes noise.

*Unclear data ownership* must be resolved per field — a finding with no owner is not actionable.

Honest question worth asking: does this need an agent, or a scheduled report? If the rules are deterministic, a report is cheaper and more predictable.

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
