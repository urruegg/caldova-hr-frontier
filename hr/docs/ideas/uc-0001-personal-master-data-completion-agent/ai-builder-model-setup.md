# Establishing and testing the AI Builder extraction models in DEV

| Field | Value |
|---|---|
| **Version** | 0.1 |
| **Date** | 2026-09-25 |
| **Author** | DAAI |
| **Status** | Draft |
| **Scope** | UC-0001 Tier 1 extraction model build and evaluation |
| **References** | [UC-0001](./README.md), [ADR-0011](../../../../docs/adr/0011-workflow-first-process-architecture.md) |

IT and the Platform Owners own environment and licensing prerequisites. The controlled test data is in [the fixed-template package](./gf-aib-fixed-template/) and [the general-documents package](./gf-aib-general-documents/).

---

## 1. What you are building and why

[ADR-0011](../../../../docs/adr/0011-workflow-first-process-architecture.md) splits document extraction into two tiers:

```text
WORKFLOW  →  TIER 1   AI Builder document processing     ← this guide
                      well-formed documents, deterministic
                          │ failed / ambiguous / low confidence
                          ▼
             TIER 2   AGENT NODE (GitHub Copilot harness)
                      reasoning over what Tier 1 could not read
```

**Raising Tier 1 coverage is worth real money and real risk reduction.** It cuts credit consumption on a harness billed for building, testing, evaluating *and* running, and it narrows the surface on which untrusted document content reaches a reasoning model. The control-plane mockup shows Tier 2 at 38% against a target under 20% — closing that gap is what these models are for.

You will build **two** models and compare them. That comparison is the evidence for **D-17**, the confidence threshold that routes a document from Tier 1 to the agent node.

| Model | Type | Good at | Training time |
|---|---|---|---|
| `gf_PersonalstammdatenFixed` | **Fixed template documents** | GF's own forms, municipality confirmations — known layouts | Short |
| `gf_PersonalstammdatenGeneral` | **General documents** | Contracts, letters, certificates, scans — unfamiliar structures | **Long** |

---

## 2. Read this before you train anything

Three AI Builder ALM facts that are easy to discover too late, and one of them is close to unrecoverable.

> ### Training data does not travel with the model
>
> When an AI model is added to a solution, **only the model executable is included. The training data is not.**

> ### You cannot retrain an imported document processing model
>
> Creating and training a new version is **disabled** for imported document processing, object detection and entity extraction models — precisely because the training data did not come with it. In TEST and PROD the model is **read-only**. If it needs to change, you change it in DEV and redeploy.

> ### Therefore: DEV is the only place this model can ever be trained, and the training documents are the real asset
>
> If the DEV environment is reset, rebuilt or lost, **the model cannot be reconstructed without the original tagged documents.** This is why the test packages live in version control rather than in someone's Downloads folder, and why §9 treats the training set as a controlled artefact.

Two further constraints that shape the procedure:

- **A model can only be added to a solution once it has a published version**, and only the published version installs in the target environment. Publish before you package.
- **Import within one month of export**, unless the source model is unchanged since export.

---

## 3. Prerequisites

| # | Prerequisite | Owner | Note |
|---|---|---|---|
| 1 | **DEV environment with Dataverse** | IT | Per [Power Platform Environments and ALM](../../../../infra/docs/12-power-platform-environments-and-alm.md) |
| 2 | **AI Builder credits allocated to DEV** | IT | AI Builder is **Premium** — it is on the conditional list in [Solution Design §4.5](../../../../docs/solution-design.md) and becomes required the moment you take this path |
| 3 | **DLP policy applied**, AI Builder in the same data group as Dataverse, SharePoint and Workday | IT / Security | Stage 1.2. Doing this after the flow is built makes the flow un-runnable with no warning |
| 4 | **Publisher `gf_` exists** | IT | Stage 1.3. Cannot be changed later |
| 5 | **`GFHRPlatformCore` unmanaged solution in DEV** | DAAI | The models go here, not in the agent solution — see §4 |
| 6 | **Synthetic test packages available locally** | DAAI | [`gf-aib-fixed-template/`](./gf-aib-fixed-template/) and [`gf-aib-general-documents/`](./gf-aib-general-documents/) |

---

## 4. Which solution the models belong in

Put both models in **`GFHRPlatformCore`**, not in `GFHRMasterDataAgent`.

**Why.** Core holds what more than one use case will consume — tables, security roles, connection references, environment variables, shared skills. Extraction models are the same kind of asset: UC-0005 Onboarding Assistant will want document extraction too, and a model buried in the UC-0001 agent solution cannot be shared without an awkward dependency.

> **A model is not an app or flow dependency.** If a Power Automate flow calls the model, adding the flow to a solution does **not** pull the model in. **Add the model explicitly**, or the import succeeds in TEST and the flow fails at runtime looking for a model that was never deployed.

---

## 5. Build the fixed-template model

**Test data:** [`gf-aib-fixed-template/`](./gf-aib-fixed-template/) — 24 PDFs in 4 collections of 6.

### 5.1 Create

1. **Power Apps → AI hub → AI models → Extract custom information from documents → Create custom model**
2. Document type: **Fixed template documents**
3. Name: `gf_PersonalstammdatenFixed`

### 5.2 Define the 17 fields

Names are **identifiers — never translate them**, in any locale.

| Field | AI Builder type | Why that type |
|---|---|---|
| `candidate_id` | Text | The D-03 fix — see §8 |
| `last_name` · `first_name` | Text | |
| `dob` | **Date**, format **Day, Month, Year** | The documents use `DD.MM.YYYY` |
| `nationality` · `marital` · `heimatort` · `permit` | Text | |
| `street` · `city` | Text | |
| `plz` | **Text — not Number** | A 4-digit Swiss postcode loses leading zeros in a number field |
| `ahv` | **Text — not Number** | `756.1943.0211.85` is not a decimal |
| `iban` | Text | |
| `phone` · `email` | Text | |
| `ec_name` · `ec_phone` | Text | |

### 5.3 Create four collections

One per folder. A collection is a group of documents sharing a layout, and **at least five documents per collection** are required.

| Collection | Folder | Upload |
|---|---|---|
| `Personalblatt` | `a-personalblatt/` | Documents 01–05 |
| `AnmeldungGemeinde` | `b-anmeldung-gemeinde/` | Documents 01–05 |
| `Sozialversicherung` | `c-sozialversicherung/` | Documents 01–05 |
| `Bankverbindung` | `d-bankverbindung/` | Documents 01–05 |

**Hold back document 06 in every collection.** Those four are your test set. Training on all six leaves you with no honest way to measure anything.

### 5.4 Tag, train, publish

Tag each field in each document, then **Train**. Fixed-template training is quick.

**Do not skip Publish.** An unpublished model cannot be added to a solution (§2), and it is the single most common reason the packaging step fails later.

---

## 6. Build the general-documents model

**Test data:** [`gf-aib-general-documents/`](./gf-aib-general-documents/) — 24 PDFs across 8 layout families.

Same field definitions. Two differences that matter:

1. **Document type: General documents.** No collections — mixed layouts in one set is the entire point.
2. **Training takes materially longer.** Start it and do something else.

**Hold back one document per family** — 8 in total — as the test set.

### What to expect, honestly

This package is built to find the ceiling, not to flatter the model.

| Family | If accuracy is low |
|---|---|
| `arbeitsvertrag` | **Expected.** Values sit unlabelled inside legal prose — the hardest common case |
| `scan-degraded` | **Expected and correct.** This is the Tier 2 case. A model that confidently reads a rotated, degraded scan is more worrying than one that declines |
| `selbstdeklaration` · `new-joiner-sheet` | **Investigate.** These are structured; poor accuracy points at tagging, not the model |

---

## 7. Test in DEV — and test the right things

### 7.1 Quick test

On the model details page, **Quick test** with a held-back document.

> **The quick test times out at 90 seconds.** For anything larger, build a Power Automate flow using the **Predict** action — it allows 60 minutes. For this package quick test is fine; for real PeopleDoc bundles it will not be.

### 7.2 Score against ground truth

Each package ships `ground-truth.csv` and `ground-truth.json` — the expected value for every field of every document.

**The scoring rule that matters most:**

> An **empty cell means the field is absent from that document**. The correct outcome is **`Missing`** (BR-09), not an extraction failure.
>
> **A model that invents a value for an absent field is worse than one that returns nothing** — and on a write path to the system of record, materially so. Score invented values as errors, not as near-misses.

Record per field and per collection/family:

| Metric | Why |
|---|---|
| **Extraction accuracy** | Value matches ground truth exactly |
| **Missing-field precision** | Returned nothing where ground truth is empty |
| **False-value rate** | **Invented a value for an absent field.** The one to watch |
| **Confidence distribution** | Feeds D-17 directly |

### 7.3 Build the routing test

The real question is not *"how good is each model?"* but *"where is the boundary?"* Build a small Power Automate flow in DEV that runs a document through Tier 1, reads the confidence, and routes below-threshold cases onward. Vary the threshold across the 48 documents and plot Tier 2 volume against false-value rate.

**That curve is the answer to D-17.** It is also the only defensible basis for the "under 20% Tier 2" target.

> **Sample-size caution.** Three documents per family is a *signal*, not a rate. If a threshold decision turns on one family, generate more documents for it first — the generator makes that cheap (§9).

### 7.4 A second throttle to design around

Document processing calls are limited to **360 per environment per 60 seconds**, across all document processing models including prebuilt ones.

This sits alongside the Workday connector's **200 calls per connection per 60 seconds**. A 50-employee batch with several documents each can approach both. **Batch size is a design decision constrained by two independent throttles**, not one — worth adding to the D-16 analysis.

---

## 8. Two things this test data was built to prove

### The D-03 matching key — demonstrable, not theoretical

The fixed-template package contains `CAND-2026-0412` and `CAND-2026-0434`: **both "Tobias Ochsner", both at postal code 8200 Schaffhausen**, different dates of birth, different AHV numbers, different IBANs. Two different people.

> Under the proposed matching key — **Last Name + First Name + Postal Code** — these are indistinguishable. Best case the run raises a `Multiple Match`. Worst case one person's bank details are written onto the other's record.
>
> **`candidate_id` is in the field list because it is the fix.** Extract it, match on it, and the collision disappears.

Run this deliberately, capture the result, and take it to HRIS. An argument about the highest-risk open item in the MVP is far shorter with a reproduction than without one.

### The Anmeldung Gemeinde template change

Collection B is the *Anmeldung Gemeinde*. The control-plane mockup reports *"12 Low Confidence on Postal Code — 9 from the same document template, layout changed ~15 Sep."* To reproduce: retrain with a modified B layout and watch `plz` confidence fall. It is the clearest available demonstration of why fixing the mapping once beats working twelve exceptions individually.

---

## 9. Treat the training set as a controlled artefact

This follows directly from §2. Because the model can only ever be trained in DEV and the training data does not travel:

1. **The training documents are version-controlled** in [`gf-aib-fixed-template/`](./gf-aib-fixed-template/) and [`gf-aib-general-documents/`](./gf-aib-general-documents/). They are not a scratch upload.
2. **Real PeopleDoc documents never join them.** These packages are synthetic for exactly that reason — a training set in version control must contain no personal data. When GF eventually tags real documents, those stay in the DEV environment and are governed as personal data, **never committed**.
3. **Record which documents trained which model version**, so a rebuild is reproducible.
4. **A DEV reset is a model loss event.** Plan for it before it happens.

The generators (`personas.py`, `gen_fixed.py`, `gen_general.py`, `gen_truth.py`) are deterministic — same seed, same output. To extend a collection, raise the loop count and rerun; ground truth regenerates with it.

---

## 10. Deploy to TEST — once DEV is settled

1. Confirm both models are **Published** in DEV
2. Add both to **`GFHRPlatformCore`** — explicitly, alongside any flow that calls them (§4)
3. **Before exporting, set Managed Properties → Allow customizations = Off.** Changing an imported model creates unmanaged customisations that block future updates
4. Export **managed**; import to TEST
5. Expect a status of **`Importing`** on the model list for several minutes after the import action reports complete. This is normal for document processing models
6. Quick test in TEST to confirm the model responds
7. **Do not edit the model in TEST.** It is read-only by design. If it is wrong, fix DEV and redeploy

---

## 11. Checklist

**Before training**
- [ ] AI Builder credits allocated to DEV
- [ ] DLP policy applied with AI Builder in the right data group
- [ ] `GFHRPlatformCore` exists in DEV
- [ ] Test packages unzipped; held-back test documents identified

**Before deploying**
- [ ] Both models **Published**
- [ ] Scored against ground truth; **false-value rate** recorded
- [ ] Confidence distribution captured per family
- [ ] D-17 threshold proposed with the evidence behind it
- [ ] D-03 reproduction run and captured
- [ ] Training documents committed; model version ↔ document set recorded
- [ ] Allow customizations turned **off** before export

---

## 12. Open items this work feeds

| ID | Decision | What this gives it |
|---|---|---|
| **D-17** | Tier 1 → Tier 2 confidence threshold | The routing curve from §7.3 |
| **D-16** | Maximum batch size per run | The **second** throttle, 360 calls/60s (§7.4) |
| **D-03** | Workday matching key | A reproduction, not an argument (§8) |
| **D-02** | PDF extraction method and its confidence signal | Whether AI Builder is the Tier 1 mechanism at all |
