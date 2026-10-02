# AI Builder test package — General documents

| Field | Value |
|---|---|
| **Version** | 0.2 |
| **Date** | 2026-10-01 |
| **Author** | DAAI |
| **Status** | Draft |
| **Scope** | UC-0001 synthetic general-document AI Builder test data |
| **References** | [UC-0001](../README.md), [ADR-0011](../../../../../docs/adr/0011-workflow-first-process-architecture.md) |

**24 synthetic PDFs across 8 deliberately different layout families**, for training and testing an AI Builder *General documents* model against the UC-0001 designed 17-field contract.

> **Every person, address, AHV number, IBAN and phone number in this package is fictional.** No real employee data is present, and none may be added. AHV numbers and IBANs carry **valid check digits** so format validation can be tested — they identify nobody.

The committed PDFs and ground truth in this package are the controlled sprint inputs for implementation and validation.

---

## Why this package exists, and how it differs from the other one

The [fixed-template package](../caldova-aib-fixed-template/README.md) tests the easy case: known forms, stable layouts. **This one tests the case that decides whether UC-0001 works in production** — the documents nobody anticipated.

| | Fixed template | General documents |
|---|---|---|
| Layout | Constant within a collection | **Different in every family** |
| Training time | Short | **Long** |
| Good at | Known forms | Unfamiliar structures, prose, mixed languages |
| Here | 4 collections × 6 | **8 families × 3** |

PeopleDoc exports whatever the employee, the municipality, the insurer or the migration office produced. A model that only handles Caldova's own forms handles the minority of the problem.

---

## The eight layout families

Each is a genuinely different structure, not a restyled form.

| # | Family | Structure | Why it is here |
|---|---|---|---|
| 1 | **Arbeitsvertrag** | Flowing legal prose, data embedded in sentences | Values have **no label** — the hardest common case |
| 2 | **Anschreiben** | Letter, sender block right-aligned, data in body text | Tests reading order and prose extraction |
| 3 | **Aufenthaltsbewilligung** | Official two-column card layout | Column-pair association |
| 4 | **Versicherungspolice** | Banded label/value table | Structured but unfamiliar |
| 5 | **Zivilstandsausweis** | **Centred** certificate, decorative border | Non-left-aligned reading order |
| 6 | **Selbstdeklaration** | Monospace form, dot-leader labels | Typewriter-style, cramped |
| 7 | **Scan (degraded)** | **Rotated 1–2°, off-white on grey, reduced quality** | **The Tier 2 escalation case** |
| 8 | **New Joiner Sheet** | Two-column, **English/German mixed** | Bilingual labels — real for a Swiss company |

**Family 7 is the important one.** It is deliberately the worst document in the package: rotated, degraded, low contrast. If the general model handles it, Tier 1 coverage rises and credit consumption falls. If it does not, that is the correct answer — it *should* escalate to the agent node, and knowing where the boundary sits is what **D-17** needs.

---

## The 17 fields

Identical to the fixed-template package, so the two are directly comparable. **Never translate these names** — they are identifiers.

`candidate_id` · `last_name` · `first_name` · `dob` · `nationality` · `marital` · `heimatort` · `permit` · `street` · `plz` · `city` · `ahv` · `iban` · `phone` · `email` · `ec_name` · `ec_phone`

`dob` is a **Date** field, format **DD.MM.YYYY**. `plz` and `ahv` stay **Text** — leading zeros and dot separators do not survive a number field.

### Coverage varies by family — on purpose

| Family | Fields carried |
|---|---|
| Arbeitsvertrag · Selbstdeklaration · New Joiner Sheet | All or nearly all 17 |
| Anschreiben · Versicherung · Scan | 15–16 |
| Zivilstandsausweis | 10 |
| Aufenthaltsbewilligung | 10 |

An empty cell in `ground-truth.csv` means **the field is absent from that document**. Correct outcome: **`Missing`** (BR-09). A model that invents a value for an absent field is worse than one that returns nothing — and on a write path to the system of record, materially so.

---

## How to use it

1. **Power Apps → AI hub → AI models → Extract custom information from documents → Create custom model**
2. Choose **General documents**
3. Define the 17 fields
4. Upload documents. The general model **does not require collections** — mixed layouts in one set is the point
5. Tag the fields in each document
6. **Train** — expect this to take materially longer than the fixed-template model
7. **Quick test**, then score against `ground-truth.csv`

### A realistic expectation

The first run establishes a measured baseline. Do **not** expect fixed-template accuracy, and do not infer an expected percentage before the committed corpus has been measured. Keep the zero-false-value rule strict: an invented value for an absent field is a failure, even if the aggregate numbers look encouraging. If you tune against a document that was meant to stay held out, that held-out document is consumed and must be replaced before you claim the next result. A sensible reading:

| Family | If accuracy is low |
|---|---|
| 1 Arbeitsvertrag | Expected. Unlabelled values in prose are genuinely hard |
| 7 Scan | **Expected and correct** — this is the Tier 2 case |
| 6 Selbstdeklaration · 8 New Joiner | Investigate. These are structured; low accuracy suggests a tagging problem |

---

## What this package is actually for

**Finding the Tier 1/Tier 2 boundary.** Run both packages, compare per-family accuracy, and you have the evidence for:

- **D-17** — the confidence threshold that routes a document from Tier 1 to the agent node
- **The 38% Tier 2 rate** shown in the control-plane mockup, and whether the under-20% target is reachable
- Whether `candidate_id` can be reliably extracted, which is the practical test of the **D-03** fix

> **One caution.** Per-family accuracy from 3 documents is indicative, not statistical. Treat a family as a *signal* worth investigating, never as a measured rate. If a boundary decision turns on it, generate more documents for that family first — the generator makes that cheap.

---

## Regenerating

`gen_general.py`, `gen_fixed.py`, `gen_truth.py`, and `personas.py` are the source provenance for the committed PDFs and ground truth in this package. To add documents to a family, raise the loop count in `build()` and rerun — but do not claim byte-for-byte deterministic PDF output unless a repeat-generation test proves it.
