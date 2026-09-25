# UC-0001 — Personal Master Data Completion Agent

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-24 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | HR Use Case Portfolio |
| **References** | [HR Solution Functional Design Intake](../../../../docs/specs/2026-09-24-hr-solution-functional-design-intake-design.md) |

**Purpose.** Everything specific to the **selected MVP use case**. This is the only use case in the portfolio that has advanced past idea, and this folder is the pattern every future selected use case follows.

> **Status: Selected as MVP — the first of three. Approved in scope, not yet approved for build** — the Definition of Ready in the PRD §13 is not met. The blocking item is the matching key (D-03).
>
> UC-0010 and UC-0005 complete the MVP scope but are not yet specified. See [`prd.md`](../../../../docs/prd.md) §2.2.

---

## Contents

| Document | What it is | Authority |
|---|---|---|
| [`uc-0001-personal-master-data-completion-agent.md`](uc-0001-personal-master-data-completion-agent.md) | The use case: what it does, where it sits in the journey, platform fit, assessment | Orientation |
| [`prd-0001-personal-master-data-completion-agent.md`](prd-0001-personal-master-data-completion-agent.md) | **The requirements.** Draft 0.2, superseding GF Draft 0.1. Business rules, functional and non-functional requirements, acceptance criteria, open decisions, risks | **Authoritative for this use case** |
| [`bom-0001-peopledoc-master-data-ai-builder-fields.md`](bom-0001-peopledoc-master-data-ai-builder-fields.md) | Repository-owned traceability for the 17 AI Builder fields from design through tenant-specific implementation evidence; not the GF 60+ item artefact inventory | **Authoritative for AI Builder field lifecycle status** |

Read the use case document for *what and why*. Read the PRD for *exactly what must be true*. Read the field BoM for *what has been designed, implemented and verified*.

---

## What this use case does

HR Operations exports new-joiner PDFs from PeopleDoc into a SharePoint folder. A **deterministic workflow** drives the run; where a document defeats the deterministic extraction tier, an **agent node** reads and interprets it. Approved personal master data is matched to exactly one Workday candidate or pre-hire profile, and **missing approved values only** are added. The process shape is [ADR-0011](../../../../docs/adr/0011-workflow-first-process-architecture.md); the flow is Solution Design §5.

| It does | It never does |
|---|---|
| Add a value to a blank approved field | Overwrite an existing value |
| Continue when one field is missing | Write without exactly one profile match |
| Record every action, skip and exception | Create a worker record |
| Stop and escalate when uncertain | Decide anything about a person |

**Switzerland only.** Scope expansion is a separate decision, not a later phase of this one.

---

## What it inherits

This use case does **not** restate platform requirements — it inherits them, and a reader looking for them here will not find them:

| Inherited from | What |
|---|---|
| [`prd.md`](../../../../docs/prd.md) | FR-0001…FR-0012, NFR-0001…NFR-0010, roles, release gates |
| [`solution-design.md`](../../../../docs/solution-design.md) | Architecture, the Workday Access Layer, connector inventory, security, ALM |
| [`hr-journey-and-raci.md`](../../../../docs/hr-journey-and-raci.md) | Journey placement, RACI, the seven declarations |
| [ADR-0005](../../../../docs/adr/0005-workday-as-system-of-record.md) · [ADR-0007](../../../../docs/adr/0007-dataverse-process-state-boundary.md) · [ADR-0008](../../../../docs/adr/0008-human-in-the-loop-and-write-envelope.md) · [ADR-0009](../../../../docs/adr/0009-workday-access-via-connector-behind-governed-layer.md) · [ADR-0011](../../../../docs/adr/0011-workflow-first-process-architecture.md) | The decisions that shape it |

**The PRD may add requirements. It may not weaken the inherited ones.**

---

## Evidence rules for agents

**1. The PRD is authoritative for this use case; `prd.md` is authoritative for the platform.** A question about *this agent's* business rules is answered from the PRD. A question about how *any* GF agent must behave is answered from `prd.md`. Answering the second from the first produces requirements that look use-case-specific when they are not.

**2. Draft 0.2 supersedes GF's Draft 0.1.** Where they differ, this package is current — it adds the HR Employee Control Plane App, the Dataverse process-state boundary, Teams notification, BR-13…BR-15, FR-16…FR-20, AC-11…AC-13 and D-11…D-13. What changed is listed in PRD §1.

**3. D-03 is unresolved and is the highest-risk open item.** The matching key — Last Name + First Name + Postal Code — is marked TBD in GF's source and is **not sufficient**. Names repeat, postal codes change, and a false match writes one person's data onto another's record. **Do not treat it as decided, and do not propose a workaround that leaves the risk in place.**

**4. Cite IDs.** `BR-08`, `FR-16`, `AC-11`, `D-03` are stable. Prose is not.

**5. The Definition of Ready is a gate, not a checklist to summarise.** PRD §13 lists what must be approved before build. If asked whether build can start, check it rather than inferring from apparent completeness.

---

## The pattern for future use cases

When a use case is selected, it graduates from a flat idea document into a folder:

```text
ideas/uc-nnnn-<context>/
├── README.md                      this file's equivalent
├── uc-nnnn-<context>.md           the use case (moved from ideas/)
└── prd-nnnn-<context>.md          the requirements (new)
```

The folder name matches the use case document name exactly. Later artefacts — test plans, field mappings, evaluation sets — join them here rather than scattering across the repository.

---

## Sources

| Source | Contributed |
|---|---|
| `PRD_Personal_Master_Data_Completion_Agent_Switzerland_Draft_0.1` | Scope, business rules, functional requirements, acceptance criteria, open decisions |
| `BOM_Artefacts_Personal_Master_Data_Completion_Agent_Switzerland_Draft_0.1` | Artefact inventory — 60+ items across business, data, system, security, build, test and operations, with ownership and status |
| `GF_HR AI Use case list.xlsx` | Portfolio context and the HR Ops CH pain points |
| `Personalstammdaten_Felder_DE_EN.xlsx` | The approved field list — column C where column E = yes. **Referenced by GF, not included in this package** |
