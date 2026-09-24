# `data/` — Data domain

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-24 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Data |
| **References** | [HR Solution Functional Design Intake](../docs/specs/2026-09-24-hr-solution-functional-design-intake-design.md) |

**Purpose.** Data definitions, field mappings, reference lists and test data that are neither HR use-case logic nor infrastructure. Cross-domain by nature: the approved field list is owned by HR, targeted at Workday, and consumed by a workflow.

---

## What belongs here

| Artefact | Notes |
|---|---|
| **Approved field list** | `Personalstammdaten_Felder_DE_EN.xlsx` — column C where column E = `yes`. **Referenced by GF, not yet supplied.** The authoritative copy lands here, versioned |
| Workday field mapping | Approved field name → Workday target field and domain |
| Reference/lookup lists | Any controlled vocabulary a workflow validates against |
| Synthetic test data | Sample documents and expected outcomes for evaluation test sets |

## What does not belong here

> ⚠️ **No real employee data. Ever.** Not a sample, not an anonymised extract, not "just for testing". The approved field list is a list of *field names*, not values.
>
> Real personal data lives in Workday, and the whole architecture exists to keep it there. A repository is the one place it can neither be governed nor recalled — see [ADR-0007](../docs/adr/0007-dataverse-process-state-boundary.md).

Also not here: Dataverse schema (that is solution source, `hr/src/solutions/`), and environment configuration (`infra/src/config/`).

---

## The approved field list is a control, not a spreadsheet

It determines what the agent may write. Three consequences:

1. **It is versioned.** `gf_approvedfield` in Dataverse carries the active list with a version; this folder holds the source it came from. They must not drift.
2. **A change to it is a change to the write envelope** — so it follows the [ADR-0008](../docs/adr/0008-human-in-the-loop-and-write-envelope.md) change process, with HR Operations accountable and HRIS confirming the Workday target.
3. **Adding a field is not a configuration tweak.** The Workday Integration System User's write permission is scoped to the approved set; a new field needs the Workday-side grant extended first, or the write will be rejected — correctly.

---

## Status

**Empty at handover.** The approved field list (D-01) is an open decision and the single largest content gap in the MVP: without it the extraction mapping cannot be completed and scope is unstable.
