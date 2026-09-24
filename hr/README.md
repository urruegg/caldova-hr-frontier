# `hr/` — HR domain

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-24 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | HR |
| **References** | [HR Solution Functional Design Intake](../docs/specs/2026-09-24-hr-solution-functional-design-intake-design.md) |

**Purpose.** Everything specific to HR: the use cases, their requirements, and the Power Platform solutions that implement them. If it is about *what HR does*, it lives here. If it is about *how the platform works*, it lives in [`docs/`](../docs/README.md).

---

## Structure

```text
hr/
├── README.md                  this file
├── docs/
│   ├── ideas/                 the use case portfolio
│   │   ├── README.md          index, waves, journey placement
│   │   ├── uc-0001-personal-master-data-completion-agent/
│   │   │   ├── README.md      the MVP use case folder
│   │   │   ├── uc-0001-….md   the use case
│   │   │   └── prd-0001-….md  the requirements  ◀ authoritative
│   │   └── uc-0002 … uc-0019.md
│   └── (use-case folders join here as they graduate)
└── src/
    └── solutions/             Power Platform solution source
```

**A flat file is an idea. A folder is a commitment.** A use case graduates into a folder — named identically to its use case document — when a PRD is written for it.

---

## MVP scope

| # | Use case | Status |
|---|---|---|
| **UC-0001** | [Personal Master Data Completion Agent](docs/ideas/uc-0001-personal-master-data-completion-agent/README.md) | **Specified** — PRD Draft 0.3, pending Definition of Ready |
| **UC-0010** | [Employee Data Validation](docs/ideas/uc-0010-employee-data-validation-bot.md) | In scope, **no PRD yet** |
| **UC-0005** | [Onboarding Assistant](docs/ideas/uc-0005-onboarding-assistant.md) | In scope, **no PRD yet** |

Fifteen further use cases are candidates with no commitment attached. See the [portfolio](docs/ideas/README.md).

---

## Solutions

Power Platform solution source lives in `src/solutions/`, exported unmanaged from DEV and committed. Managed solutions for TEST and PROD are produced by the pipeline, never hand-exported.

| Solution | Contains |
|---|---|
| `GFHRPlatformCore` | Dataverse tables, security roles, connection references, environment variable definitions, shared agent skills |
| `GFHRMasterDataAgent` | The UC-0001 workflow, the agent it calls, the Workday Access Layer workflow, the control plane app registration |

Core imports first. The agent solution depends on it. Publisher prefix is tenant-specific and decided once per tenant before the first table — `calhr` for the Caldova practice tenants (Tenant 1 & 2), `gfhr` for the real customer tenant (Tenant 3) — because it cannot be changed afterwards without rebuilding every component that references it. This domain's solution names below (`GFHRPlatformCore`, `GFHRMasterDataAgent`) are the Tenant 3 build.

---

## Rules that apply to everything in this domain

These are not aspirations. They are testable, and they come from [`docs/prd.md`](../docs/prd.md):

| | |
|---|---|
| **FR-0005** | No agent makes or communicates a decision about a person |
| **FR-0006** | Workday writes pass through the Access Layer, enforced server-side |
| **FR-0010** | Dataverse holds process state only — never master data values |
| **FR-0013** | Workflow-first. A step that cannot state why it needs reasoning is a workflow step |
| **FR-0014** | The audit record is written by deterministic workflow steps |

> **Before any use case here starts, it answers the seven declarations** in [`hr-journey-and-raci.md`](../docs/hr-journey-and-raci.md) §9: write envelope · refusal set · escalation path · grounding sources · data classification · employment-decision surface · measurement.

---

## For agents working in this folder

**The PRD is authoritative for a use case; `docs/prd.md` is authoritative for the platform.** A question about *this agent's* business rules is answered from the use-case PRD. A question about how *any* GF agent must behave is answered from the platform PRD. Getting that backwards produces requirements that look use-case-specific when they are not.

**D-03 is unresolved and is the highest-risk open item in the MVP.** The Workday matching key — Last Name + First Name + Postal Code — is marked TBD in GF's source and is not sufficient. Do not treat it as decided, and do not propose a workaround that leaves the risk in place.

**Cite identifiers, not prose.** `BR-08`, `FR-23`, `AC-11`, `D-17`, `UC-0010` are stable. Sentences are not.
