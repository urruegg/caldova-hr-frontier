# AI Builder test package — Fixed template documents

| Field | Value |
|---|---|
| **Version** | 0.1 |
| **Date** | 2026-09-25 |
| **Author** | DAAI |
| **Status** | Draft |
| **Scope** | UC-0001 synthetic fixed-template AI Builder test data |
| **References** | [UC-0001](../README.md), [ADR-0011](../../../../../docs/adr/0011-workflow-first-process-architecture.md) |

**24 synthetic PDFs in 4 collections, for training and testing an AI Builder *Fixed template documents* model** against the UC-0001 approved master-data field set.

> **Every person, address, AHV number, IBAN and phone number in this package is fictional.** No real employee data is present, and none may be added. AHV numbers and IBANs carry **valid check digits** so format validation can be tested — they identify nobody.

---

## Why this package exists

[UC-0001](../README.md) extracts approved personal master data from new-joiner documents. [ADR-0011](../../../../../docs/adr/0011-workflow-first-process-architecture.md) splits that extraction in two:

| Tier | Does what | This package |
|---|---|---|
| **Tier 1** — deterministic | AI Builder document processing on well-formed documents | **What you are testing here** |
| **Tier 2** — agent node | Reasoning over what Tier 1 could not handle | The [general-documents package](../gf-aib-general-documents/README.md) |

Raising Tier 1 coverage cuts credit consumption *and* narrows the prompt-injection surface, so how well this model performs is a direct input to **D-17**, the two-tier confidence threshold.

---

## What is in it

```text
documents/
├── a-personalblatt/         6 PDFs  GF internal new-joiner data sheet
├── b-anmeldung-gemeinde/    6 PDFs  Municipality registration confirmation
├── c-sozialversicherung/    6 PDFs  AHV / social-insurance notification
└── d-bankverbindung/        6 PDFs  Salary payment instruction
ground-truth.csv             expected value per document per field
ground-truth.json            same, machine-readable
```

**Each folder is one AI Builder collection.** A collection is a group of documents sharing the same layout, and AI Builder requires **at least five per collection** — six are supplied so one can be held back for testing.

Within a collection the layout is **pixel-identical**; only the values change. That is precisely the condition the fixed-template model is built for and its training time is short as a result.

---

## The 17 fields

Aligned to the UC-0001 approved field list. **Never translate these names** — they are identifiers.

| Field | Type | Example | Notes |
|---|---|---|---|
| `candidate_id` | Text | `CAND-2026-0411` | **See the D-03 note below** |
| `last_name` · `first_name` | Text | `Brunner` · `Livia` | |
| `dob` | Date | `14.03.1994` | Format **DD.MM.YYYY** — set this in the field definition |
| `nationality` | Text | `Schweiz` | |
| `marital` | Text | `ledig` | ledig · verheiratet · geschieden |
| `heimatort` | Text | `Stein am Rhein SH` | Swiss place of origin. No equivalent outside CH |
| `permit` | Text | `B (EU/EFTA)` | `—` where not applicable |
| `street` · `plz` · `city` | Text | `Sonnenbergstrasse 14` · `8203` · `Schaffhausen` | `plz` is 4 digits — keep as **text**, not number |
| `ahv` | Text | `756.1943.0211.85` | Valid EAN-13 check digit. **Text, not number** |
| `iban` | Text | `CH74 0070 0001 1455 2331` | Valid mod-97 check digits |
| `phone` · `email` | Text | `+41 79 412 88 03` | |
| `ec_name` · `ec_phone` | Text | `Marco Brunner` | Emergency contact |

---

## Which fields appear where

Deliberately **not** every field on every document — that is what real document sets look like, and it lets you test the *Missing* path rather than only the happy path.

| Collection | Carries | Notably absent |
|---|---|---|
| **A — Personalblatt** | All 17 | — |
| **B — Anmeldung Gemeinde** | 11 | No IBAN, no contact details, no candidate ID |
| **C — Sozialversicherung** | 11 | No candidate ID, no contact details, no permit |
| **D — Bankverbindung** | 9 | No nationality, marital status, heimatort or contact details |

In `ground-truth.csv` an **empty cell means the field is absent from that document**. The correct agent outcome is **`Missing`** (BR-09), not an extraction failure. A model that invents a value for an absent field is worse than one that returns nothing.

---

## How to use it

1. **Power Apps → AI hub → AI models → Extract custom information from documents → Create custom model**
2. Choose **Fixed template documents**
3. Define the 17 fields above. Set `dob` as a **Date** field with format **Day, Month, Year**; leave `plz` and `ahv` as **Text**
4. Create **four collections** — one per folder — and upload five documents to each
5. Tag the fields in each document
6. **Train**, then **Quick test** with the sixth document you held back
7. Score the result against `ground-truth.csv`

### A realistic expectation

Fixed-template models do very well on this kind of document. If accuracy on collections A–D is **not** above ~95% after tagging five documents each, the problem is almost certainly the tagging, not the model.

---

## Two things worth testing deliberately

**1. The D-03 matching-key weakness — this package can demonstrate it.**

`CAND-2026-0412` and `CAND-2026-0434` are **both "Tobias Ochsner", both at postal code 8200 Schaffhausen**, with different dates of birth, AHV numbers and IBANs. They are two different people.

> Under the currently proposed matching key — **Last Name + First Name + Postal Code** — these two records are indistinguishable. A run would return a `Multiple Match` at best, and write one person's bank details onto the other's record at worst.
>
> **`candidate_id` is in the document set precisely because it is the proposed fix.** Extract it, match on it, and the collision disappears. That is the evidence to put in front of HRIS when [D-03](../prd-0001-personal-master-data-completion-agent.md) is decided — the highest-risk open item in the MVP.

**2. Collection B is the *Anmeldung Gemeinde* template.** The control-plane mockup shows a Refine insight reporting *"12 Low Confidence on Postal Code — 9 from the same document template, Anmeldung Gemeinde changed layout ~15 Sep."* If you want to reproduce that scenario, retrain with a modified B layout and watch confidence drop on `plz`. It is the clearest demonstration of why fix-once beats working twelve exceptions.

---

## Regenerating

`gen_fixed.py` and `personas.py` produce this package deterministically — same seed, same output. Change a layout or add a collection there rather than editing PDFs.
