# GitHub Copilot instructions — GF HR Agentic Platform

You are working in the design repository for Georg Fischer's HR agentic platform. This file tells you how to find evidence here and what you must not do.

---

## What this repository is

The design record for a **pure agentic, Frontier-driven HR organisation** positioned at **Level 3 — agentic** on Microsoft's process-automation model. Workday is the system of record; agents read, prepare, check and complete; people decide.

**It is a design repository, not an implementation.** Solution source folders exist but are empty at handover. If asked what has been built, the honest answer is: nothing yet — three use cases are in MVP scope and one of them has requirements written.

---

## Where to look

| Question | File | Not |
|---|---|---|
| What must the platform do, always | `docs/prd.md` | A use-case PRD — it inherits, it does not restate |
| What must *this* use case do | `hr/docs/ideas/<uc>/prd-xxxx-<context>.md` | `docs/prd.md` — it is use-case-agnostic |
| How is it built | `docs/solution-design.md` | `docs/prd.md` |
| Who is accountable | `docs/hr-journey-and-raci.md` §5–6 | — |
| **Why** was it decided, what was rejected | `docs/adr/` | Any other document |
| How do we stand it up | `infra/docs/30-environment-setup.md` | `docs/solution-design.md` — that is the design, not the procedure |
| What colour / font / logo | `docs/brand/` | Inventing a hex value — every colour is a token |
| Is it approved | The document's own **Status** field | Its existence |

**Authority rule.** More specific wins — except on governance, where the platform wins. A use-case PRD may add requirements; it may **not** weaken `docs/prd.md` FR-0001…FR-0014 or NFR-0001…NFR-0012. An Accepted ADR outranks narrative text anywhere; if `solution-design.md` and an ADR conflict, the ADR is right and the design has drifted — report that, do not silently reconcile.

---

## Evidence rules

**1. Separate GF-stated fact from this package's assessment.** GF's own material is the four source documents listed in `docs/README.md`. Everything else is analysis produced for GF. Never attribute an assessment to GF.

**2. Open is open.** Where a source says TBD, these documents say TBD. **Never resolve an open decision by inference.** Open lists: `docs/prd.md` §10, `docs/solution-design.md` §11, the UC-0001 PRD §13.

**3. Cite identifiers.** `FR-0013`, `NFR-0011`, `ADR-0011`, `UC-0010`, `BR-08`, `D-03` are stable. Prose is not.

**4. Status before content.** Three use cases are in MVP scope; **only UC-0001 is specified**. Fifteen are candidates with no commitment. ADR-0010 is *Proposed*, not accepted.

**5. Never invent a number, name, date or field.** If it is not in the repository or GF's material, say it is not known.

**6. The brand palette is derived, not authoritative.** `docs/brand/` carries values from third-party brand data, not GF's corporate design manual — it says so at the top. **Never add a GF logo file**; the header carries a deliberate placeholder wordmark until Corporate Communications supplies the licensed asset.

---

## Six claims that are load-bearing — state them correctly

> **Workday is the system of record.** No component holds a persistent copy of employee master data. Every read is live. (ADR-0005)

> **Dataverse holds process state, never master data.** Test: *if Workday were wiped and restored from backup, would this column now be wrong?* If yes, it does not belong in Dataverse. (ADR-0007)

> **The agent never holds the Workday connector.** GF IT confirmed Microsoft's Workday connector as the access API, but `Execute SOAP operation` is a raw pass-through. A governed Access Layer owns the connection. (ADR-0009)

> **The workflow owns the process; the agent owns the judgement.** Determinism cannot live in the agent — the GitHub Copilot harness exposes no orchestration configuration. The audit record is written by deterministic workflow steps. (ADR-0011)

> **The Organizational Data Service is not confirmed and cannot serve the MVP.** It imports *workers*; the MVP operates on *candidates and pre-hires*. (ADR-0010, Proposed)

> **No agent decides about a person.** Not hiring, pay, performance, promotion or exit. Agents prepare evidence; named humans decide. (FR-0005)

---

## When proposing a change

Ask, in order:

1. Does it contradict an Accepted ADR? If so, it needs a new ADR superseding it — not an edit.
2. Does it weaken a platform FR or NFR? A use case cannot.
3. Does it put reasoning where a rule would do? Then it is a workflow step (FR-0013).
4. Does it create a write path that bypasses the Access Layer, or give a component the Workday connector directly?
5. Does it place employee master data anywhere other than Workday?
6. Can it answer the seven declarations in `docs/hr-journey-and-raci.md` §9?

Any *yes* to 1–5, or any *no* to 6, means stop and say so.

---

## Naming and structure

`<type>-<number>-<context>.md` — `prd-`, `adr-`, `uc-` as filename prefixes; `FR-`, `NFR-`, `BR-`, `AC-`, `D-`, `TD-` as identifiers inside documents. **Numbers are allocated once and never reused**, including after supersession.

```text
docs/     platform — prd, solution design, journey, ADRs, brand
hr/       HR domain — use cases, requirements, solution source
infra/    infrastructure domain — setup, IaC, configuration
data/     field lists, mappings, test data — never real personal data
```

**A flat use-case file is an idea. A folder is a commitment.**

---

## Tone

Write for HR and IT leaders at GF, not for developers. Prefer plain sentences over bullet cascades. Never use an emoji. When a risk is real, name it plainly rather than softening it — the matching key (D-03) is the clearest example, and it is unresolved.
