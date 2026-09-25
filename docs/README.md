# `docs/` — Platform documentation

| Field | Value |
|---|---|
| **Version** | 1.1 |
| **Date** | 2026-09-25 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Cross-cutting (all solution domains) |
| **References** | [HR Solution Functional Design Intake](specs/2026-09-24-hr-solution-functional-design-intake-design.md) |

**Purpose.** What applies to **every** use case: platform requirements, architecture, accountability, and the decisions that shape all of it. Use-case-specific material lives in [`hr/`](../hr/README.md); operational setup lives in [`infra/`](../infra/README.md).

**Read this first if you are an agent or a new contributor.** The rules below tell you which document is authoritative for which kind of question. Answering from the wrong one produces confident, wrong answers — most of the failure modes in this repository start there.

---

## Documentation Policy

All maintained repository documentation is written in English, stored as UTF-8, aligned with delivered behavior or explicitly marked Proposed Baseline, and owned by a named solution domain. Every repository-owned Markdown artifact contains the standard six-field metadata table immediately after its first H1 (Agent YAML frontmatter may precede the H1). Git history is the change log.

The header and language policy do not modify vendored files below `.github/skills/{vendored-skill}/`, licenses, generated evidence, machine-readable manifests, or externally owned immutable text.

The [Docs Agent](../.github/agents/docs-agent.agent.md) owns metadata, placement, references, English-language review, and catalogue maintenance.

### Visual communication

Use Mermaid diagrams when flows, states, sequences, relationships, or architecture are materially easier to understand visually than through prose or tables alone. A short document, decision record, requirement list, or catalogue does not need a diagram when one would add no explanatory value.

A Mermaid diagram supplements the written record. It does not replace authoritative tables, requirements, stable identifiers, or prose. Every diagram must:

- have an adjacent plain-English introduction or summary;
- use the same stable identifiers and terminology as the authoritative text;
- remain readable without custom colours, external images, or raw HTML;
- use Mermaid syntax supported by GitHub Markdown;
- stay focused on one relationship, flow, state model, or architecture view.

When a maintained document already uses ASCII art for one of these purposes, prefer a Mermaid diagram when revising that section.

---

## Structure

```text
docs/
├── prd.md                    Platform requirements — FR-0001…, NFR-0001…, roles, gates
├── solution-design.md        Architecture — layers, components, integration, security, ALM
├── hr-journey-and-raci.md    The HR journey, roles, RACI, use-case placement, sequencing
├── adr/                      Decision records (11: 4 infra/governance, 7 HR solution) — why, what was rejected, what it costs
└── brand/                    BrandKit — tokens, Fluent themes, logo guidance
```

The use case portfolio moved to **[`hr/docs/ideas/`](../hr/docs/ideas/README.md)** when the repository adopted domain roots. This folder is platform-only.

---

## Which document answers which question

| If the question is about… | Read | Not |
|---|---|---|
| What the platform must do, for every use case | `prd.md` | A use-case PRD — it inherits these, it does not restate them |
| What a *specific* use case must do | `hr/docs/ideas/<uc>/prd-xxxx-<context>.md` | `prd.md` — it is deliberately use-case-agnostic |
| How something is built, and with what | `solution-design.md` | `prd.md` — requirements are not implementation |
| Who does what, and who is accountable | `hr-journey-and-raci.md` §5–6 | `prd.md` §6, which is platform-level only |
| **Why** a choice was made, and what was rejected | `adr/` | Any other document — they state the *what*, not the *why* |
| Whether something is approved | The document's own **Status** field | Its existence. Most documents here describe options, not commitments |
| What it should look like | [`brand/`](brand/README.md) — tokens, Fluent 2 themes, logo | Hand-written hex values in a component |

---

## The authority rule

**When two documents disagree, the more specific one wins — except on governance, where the platform wins.**

- A use-case PRD may add requirements. It may **not** weaken `prd.md` FR-0001…FR-0012 or NFR-0001…NFR-0010.
- An ADR overrides narrative text in any document. If `solution-design.md` and an Accepted ADR conflict, the ADR is correct and the design document has drifted.
- A **Proposed** ADR is a recommendation, not a commitment. Check the Status field before relying on one.

---

## Evidence rules for agents

**1. Distinguish GF-stated fact from this package's assessment.** Every document marks its sources. Statements sourced from GF material (`PRD_…Draft_0.1`, the Build of Materials, `GF_HR AI Use case list.xlsx`, `GFAG_Workday Information for Microsoft.pptx`) are GF's own. Everything else is analysis produced here. Do not attribute an assessment to GF.

**2. Open is open.** Where a source says TBD, these documents say TBD. Open decisions are listed as open — `prd.md` §10, each use-case PRD §13, `solution-design.md` §11. **Never resolve one by inference.** If a value is needed and marked open, say it is open.

**3. Cite the identifier, not the prose.** Requirements, decisions and use cases all carry stable IDs — `FR-0006`, `NFR-0008`, `ADR-0009`, `UC-0001`, `D-0003`. Cite those. They survive rewording; a quoted sentence does not.

**4. Status before content.** `Accepted`, `Proposed`, `Draft`, `Idea` and `Selected as MVP` mean materially different things. **Three use cases are in MVP scope; only UC-0001 is specified.** Fifteen are candidates with no commitment attached.

---

## The three claims most often stated wrong

Stated here because they are load-bearing and easy to get backwards:

> **The agent never holds the Workday connector.** GF IT confirmed Microsoft's Workday connector as the access API, but its `Execute SOAP operation` action is a raw pass-through. A governed **Workday Access Layer** sits in front of it and owns the connection. ([ADR-0009](adr/0009-workday-access-via-connector-behind-governed-layer.md))

> **Dataverse holds process state, never master data.** The test: *if Workday were wiped and restored from backup, would this column now be wrong?* If yes, it does not belong in Dataverse. ([ADR-0007](adr/0007-dataverse-process-state-boundary.md))

> **The Organizational Data Service is not confirmed and cannot serve the MVP.** It imports *workers*; the MVP operates on *candidates and pre-hires*. ([ADR-0010](adr/0010-organizational-data-service-as-people-context.md), status Proposed)

> **The workflow owns the process; the agent owns the judgement.** Determinism cannot live in the agent — the GitHub Copilot harness exposes no orchestration configuration. The audit trail is written by deterministic workflow steps, never left to the agent's discretion. ([ADR-0011](adr/0011-workflow-first-process-architecture.md))

> **GF positions at Level 3 — agentic — and the MVP is three use cases**: UC-0001, UC-0010 and UC-0005. Fifteen others are candidates only. ([`prd.md`](prd.md) §2.1–2.2)

---

## Naming convention

`<type>-<number>-<context>.md`, so that any reference is traceable to exactly one file.

| Prefix | Type | Example |
|---|---|---|
| `prd-` | Product requirements for one use case | `prd-0001-personal-master-data-completion-agent.md` |
| `adr-` | Architecture decision record | `0009-workday-access-via-connector-behind-governed-layer.md` |
| `uc-` | Use case (in `hr/`) | `uc-0010-employee-data-validation-bot.md` |
| `fr-` / `nfr-` | Requirement IDs — **identifiers within documents**, not filenames | `FR-0006`, `NFR-0008` |
| `d-` / `td-` | Open decision IDs — identifiers, not filenames | `D-0003`, `TD-09` |

Numbers are **allocated once and never reused**, including after a document is superseded. The three top-level documents — `prd.md`, `solution-design.md`, `hr-journey-and-raci.md` — carry no number because there is exactly one of each.

---

## Infrastructure Domain

The Infrastructure domain is imported as source-derived Proposed Baseline documentation. It describes intended architecture, discovery, trust, validation, ALM, security, and recovery boundaries; it does not prove that tenant configuration, Azure resources, Azure DevOps objects, Power Platform environments, GitHub controls, pipelines, identities, or services currently exist. Task 1 disposition and pending approval are recorded in [Phase 3 Infrastructure and Tenant Bootstrap Intake](reviews/2026-09-17-phase-3-infrastructure-tenant-bootstrap-intake.md).

| Document | Purpose |
|---|---|
| [Infrastructure Domain](../infra/README.md) | Defines domain ownership, current no-payload boundary, planned layout, tool boundaries, and document map. |
| [Tenant Setup and Configuration](../infra/docs/10-tenant-setup-and-configuration.md) | Defines the reviewed tenant metadata, desired manifest, observed evidence, explicit intent, and terminology boundaries. |
| [Identity and Access](../infra/docs/11-identity-and-access.md) | Defines attended administration, per-tenant bootstrap identity, exact OIDC binding, and temporary privilege lifecycle. |
| [Power Platform Environments and ALM](../infra/docs/12-power-platform-environments-and-alm.md) | Defines future DEV-to-TEST-to-PROD ALM, solution ordering, variables, connections, and evidence requirements. |
| [Azure DevOps Engineering Control Plane](../infra/docs/13-azure-devops-engineering-control-plane.md) | Describes the proposed backlog and delivery split, discovery candidates, API constraints, and future pipeline boundary. |
| [GitHub Repository Blueprint](../infra/docs/14-github-repository-blueprint.md) | Defines the shared-repository model, tenant Environments, proposed governance, public-repository safety, and read-back. |
| [Agent and Workload Configuration](../infra/docs/15-agent-workload-configuration.md) | Defines future agent, flow, app, grounding, packaging, release, and data-prohibition contracts. |
| [Security, Governance and Compliance](../infra/docs/16-security-governance-and-compliance.md) | Defines evidence-first security principles and proposed DLP, Dataverse, identity, audit, and compliance controls. |
| [Bootstrap and Provisioning](../infra/docs/17-bootstrap-and-provisioning.md) | Defines the evidence-gated state machine, attended trust, subscription `what-if`, and no-deployment boundary. |
| [Multi-Tenant Provisioning](../infra/docs/18-multi-tenant-provisioning.md) | Defines isolation for exactly three independent tenants using one repository and one-tenant execution. |
| [Bootstrap Recovery](../infra/docs/19-bootstrap-recovery.md) | Defines attended recovery from nine failure states without bypassing validation, approvals, or least privilege. |
| [Tenant Trust Activation Runbook](../infra/docs/20-tenant-trust-activation-runbook.md) | Operator runbook for activating a tenant's Entra/GitHub/Azure DevOps trust using the existing Initialize-TenantTrust.ps1. |
| [Infrastructure Solution Sources](../infra/src/solutions/README.md) | Defines ownership and exclusions for future unpacked Infrastructure Power Platform solution source. |

**This map is unchanged by the Phase 4 HR solution intake.** `infra/` remains governed exclusively by the Phase 3 review; see [Bicep Composition](../infra/src/bicep/main.bicep) and [Tenant 1 Manifest](../infra/src/config/tenants/caldova25156897.psd1) for its current state.

---

## Superseded (Phase 2)

The original Proposed Baseline product/HR operating model is superseded by the documents above, reconciled through the [Phase 4 HR Solution Functional Design Intake](reviews/2026-09-24-phase-4-hr-solution-functional-design-intake.md). Retained for history, each carrying its own superseded banner:

| Document | Superseded by |
|---|---|
| [operating-model/00-05](operating-model/00-north-star.md) | `prd.md`, `solution-design.md`, `hr-journey-and-raci.md` |
| [90 Microsoft Best Practice Evaluation](90-microsoft-best-practice-evaluation.md) | A fresh evaluation against the new design is not yet performed — treat this as historical only |
| [HR Employee Journey (Phase 2)](../hr/docs/20-hr-employee-journey.md) | `hr-journey-and-raci.md`, `hr/docs/ideas/` |

---

## Source material

Everything here derives from GF-supplied material:

| Source | Contributed |
|---|---|
| `PRD_Personal_Master_Data_Completion_Agent_Switzerland_Draft_0.1` | UC-0001 scope, business rules, functional requirements, acceptance criteria, open decisions |
| `BOM_Artefacts_Personal_Master_Data_Completion_Agent_Switzerland_Draft_0.1` | Artefact inventory, ownership, status |
| `GF_HR AI Use case list.xlsx` | 16 use cases with business value, KPIs, personas, complexity and risk; plus 2 HR Ops CH pain points (UC-0017, UC-0018) |
| `GFAG_Workday Information for Microsoft.pptx` | Workday as system of record, integration landscape, functional areas in use |

Microsoft product behaviour is grounded in Microsoft Learn — the Workday connector reference and the Organizational Data Service import guide — and cited where it is load-bearing.
