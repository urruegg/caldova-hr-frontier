# `data/` — Data domain

| Field | Value |
|---|---|
| **Version** | 1.2 |
| **Date** | 2026-10-02 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Data |
| **References** | [HR Solution Functional Design Intake](../docs/specs/2026-09-24-hr-solution-functional-design-intake-design.md) |

## Purpose and Authority

This domain owns data definitions, field mappings, reference lists, and synthetic test data that are neither HR use-case logic nor infrastructure configuration. A reviewed source record governs each future artifact; this empty domain does not authorize an inferred field list.

## Contains and Does Not Contain

This domain may contain approved field-name lists, Workday mappings, controlled vocabularies, and synthetic test fixtures. It never contains real personal data, Dataverse solution schema, environment configuration, or raw execution evidence.

## Reading Order

Start with the [repository knowledge map](../docs/README.md), the owning [HR use-case package](../hr/docs/use-cases/README.md), and the applicable architecture decisions. When data artifacts exist, use this catalogue and then follow each artifact's explicit source and successor links.

## Naming and Lifecycle

Use descriptive lowercase kebab-case names and preserve stable field or dataset identifiers. Proposed artifacts remain absent until their source is supplied and reviewed. Replaced mappings link to their successor and remain archived when audit value justifies retention.

## What belongs here

| Artefact | Notes |
|---|---|
| **Approved field list** | The customer-supplied personal-master-data field workbook — column C where column E = `yes`. **Referenced by Caldova, not yet supplied to this repository.** The authoritative copy lands here, versioned |
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

1. **It is versioned.** `caldova_approvedfield` in Dataverse carries the active list with a version; this folder holds the source it came from. They must not drift.
2. **A change to it is a change to the write envelope** — so it follows the [ADR-0008](../docs/adr/0008-human-in-the-loop-and-write-envelope.md) change process, with HR Operations accountable and HRIS confirming the Workday target.
3. **Adding a field is not a configuration tweak.** The Workday Integration System User's write permission is scoped to the approved set; a new field needs the Workday-side grant extended first, or the write will be rejected — correctly.

---

## Status

**Empty at handover.** The approved field list (D-01) is an open decision and the single largest content gap in the MVP: without it the extraction mapping cannot be completed and scope is unstable.

## Catalogue

There are no maintained direct-child data artifacts. Add the first row only when its authoritative source, metadata, ownership, and no-personal-data validation are present.

| Successor or next stage | Artifact | Status | Purpose | Authority |
|---|---|---|---|---|

## Domain Links

- [Documentation knowledge map](../docs/README.md)
- [HR domain](../hr/README.md)
- [HR use-case detail](../hr/docs/use-cases/README.md)
- [Infrastructure domain](../infra/README.md)
- [Dataverse boundary](../docs/adr/0007-dataverse-process-state-boundary.md)
- [Human-in-the-loop and write envelope](../docs/adr/0008-human-in-the-loop-and-write-envelope.md)

## Board Synchronization

Not applicable. Data artifacts do not create or infer Azure Boards identifiers.
