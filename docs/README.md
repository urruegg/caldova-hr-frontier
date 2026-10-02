# `docs/` — Platform documentation

| Field | Value |
|---|---|
| **Version** | 1.9 |
| **Date** | 2026-10-02 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Cross-cutting (all solution domains) |
| **References** | [Tenant 1 Lean Engineering Platform Design](specs/2026-09-28-tenant-1-lean-engineering-platform-design.md), [HR Solution Functional Design Intake](specs/2026-09-24-hr-solution-functional-design-intake-design.md) |

**Purpose.** What applies to **every** use case: platform requirements, architecture, accountability, and the decisions that shape all of it. Use-case-specific material lives in [`hr/`](../hr/README.md); operational setup lives in [`infra/`](../infra/README.md).

**Read this first if you are an agent or a new contributor.** The rules below tell you which document is authoritative for which kind of question. Answering from the wrong one produces confident, wrong answers — most of the failure modes in this repository start there.

---

## Purpose and Authority

This README is the repository knowledge map and documentation policy. It routes lifecycle, domain, authority, and archive discovery; it does not replace the substantive requirements, decisions, specifications, plans, or evidence it links.

## Contains and Does Not Contain

The `docs/` root contains cross-cutting platform requirements, solution architecture, accountability, lifecycle catalogues, decisions, brand guidance, durable reviews, and historical navigation. It does not contain detailed HR packages, infrastructure source, tenant-private configuration, generated evidence, or real personal data.

## Reading Order

Follow `.github/copilot-instructions.md -> docs/README.md -> lifecycle catalogue -> domain README -> selected artifact and its explicit references`. For new work, start in [Ideas](ideas/README.md), proceed to [Specifications](specs/README.md), then [Implementation Plans](plans/README.md), and use [Reviews](reviews/README.md) or reproducible evidence to determine what happened. Historical questions start in the [Archive](archive/README.md).

## Naming and Lifecycle

Lifecycle READMEs own placement and status routing. Stable identifiers are never reused. A status change updates the owning catalogue in the same pull request, and superseded material links to a maintained successor or archive entry. Catalogue status mirrors child metadata; the child wins if a catalogue drifts.

## Catalogue

Successor links precede the owned child so automated navigation can identify each direct child deterministically.

| Successor or next stage | Direct child | Status | Purpose | Authority |
|---|---|---|---|---|
| [Solution design](solution-design.md) | [Platform PRD](prd.md) | Proposed Baseline | Defines platform-wide functional and non-functional requirements. | Platform requirement authority within its metadata status and approved higher governance. |
| [Architecture decisions](adr/README.md) | [Solution Design](solution-design.md) | Proposed Baseline | Defines platform architecture, boundaries, integration, security, and ALM. | Architecture narrative; Approved ADRs override conflicts. |
| [HR domain](../hr/README.md) | [HR Journey and RACI](hr-journey-and-raci.md) | Proposed Baseline | Defines the end-to-end HR journey, roles, accountability, and sequencing. | Cross-cutting HR accountability guidance within its metadata status. |
| [Specifications](specs/README.md) | [Architecture Decision Records](adr/README.md) | Proposed Baseline | Catalogues expensive or irreversible decisions and their rejected alternatives. | Approved repository-level ADRs override conflicting narrative; other records govern as stated. |
| Use maintained replacements for current work | [Archive](archive/README.md) | Active (consolidated from current state) | Routes historical material to current replacements. | Historical navigation only. |
| [HR control-plane wireframe design](specs/2026-09-24-hr-control-plane-code-app-wireframe-design.md) | [Brand](brand/README.md) | Proposed Baseline | Owns interim product-theme tokens, Fluent themes, and asset guidance. | Proposed product-theme guidance; not an approved corporate identity standard. |
| [Specifications](specs/README.md) | [Ideas](ideas/README.md) | Active | Owns permanent repository-wide ideas and lifecycle state. | Intake and routing authority; not implementation authority. |
| [Durable reviews](reviews/README.md) | [Implementation Plans](plans/README.md) | Active (consolidated from current state) | Catalogues executable plans derived from reviewed specifications. | Plan authority depends on metadata, governing specification, and explicit gates. |
| Use current evidence for implemented-state claims | [Reviews](reviews/README.md) | Active (consolidated from current state) | Catalogues durable intake, readiness, migration, and acceptance reviews. | Review authority is limited to recorded scope, evidence, and disposition. |
| [Implementation plans](plans/README.md) | [Specifications](specs/README.md) | Active (consolidated from current state) | Catalogues reviewed designs and behavioral specifications. | Approved specifications govern only their stated scope. |

## Domain Links

- [HR domain](../hr/README.md)
- [Infrastructure domain](../infra/README.md)
- [Data domain](../data/README.md)
- [HR use-case detail](../hr/docs/use-cases/README.md)
- [Infrastructure documentation](../infra/docs/README.md)

## Board Synchronization

Central ideas record `Deferred - not synchronized`. This knowledge map does not create, infer, or change Azure Boards identifiers.

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
├── ideas/                    Permanent repository-wide idea records and lifecycle catalogue
├── adr/                      Decision records (12: 5 infra/governance, 7 HR solution) — why, what was rejected, what it costs
└── brand/                    BrandKit — tokens, Fluent themes, logo guidance
```

The repository-wide idea portfolio is centralized in **[`docs/ideas/`](ideas/README.md)**. Detailed artifacts for graduated HR use cases live in **[`hr/docs/use-cases/`](../hr/docs/use-cases/README.md)**.

---

## Which document answers which question

| If the question is about… | Read | Not |
|---|---|---|
| What the platform must do, for every use case | `prd.md` | A use-case PRD — it inherits these, it does not restate them |
| What a *specific* use case must do | `hr/docs/use-cases/<uc>/prd-xxxx-<context>.md` | `prd.md` — it is deliberately use-case-agnostic |
| How something is built, and with what | `solution-design.md` | `prd.md` — requirements are not implementation |
| Who does what, and who is accountable | `hr-journey-and-raci.md` §5–6 | `prd.md` §6, which is platform-level only |
| **Why** a choice was made, and what was rejected | `adr/` | Any other document — they state the *what*, not the *why* |
| Whether something is approved | The document's own **Status** field | Its existence. Most documents here describe options, not commitments |
| What it should look like | [`brand/`](brand/README.md) — tokens, Fluent 2 themes, logo | Hand-written hex values in a component |

---

## The authority rule

**When two documents disagree, the more specific one wins — except on governance, where the platform wins.**

- A use-case PRD may add requirements. It may **not** weaken `prd.md` FR-0001…FR-0012 or NFR-0001…NFR-0010.
- An ADR overrides narrative text in any document. If `solution-design.md` and a repository-level Approved ADR conflict, the ADR is correct and the design document has drifted.
- A **Proposed** ADR is a recommendation, not a commitment. Check the Status field before relying on one.

---

## Evidence rules for agents

**1. Distinguish customer-stated fact from this package's assessment.** Every document marks its sources. Statements sourced from the customer-supplied UC-0001 draft PRD, the customer-supplied UC-0001 artefact inventory, the customer-supplied HR AI use-case workbook, or the source Workday presentation are customer-stated. Everything else is analysis produced here. Do not attribute repository analysis to the customer.

**2. Open is open.** Where a source says TBD, these documents say TBD. Open decisions are listed as open — `prd.md` §10, each use-case PRD §13, `solution-design.md` §11. **Never resolve one by inference.** If a value is needed and marked open, say it is open.

**3. Cite the identifier, not the prose.** Requirements, decisions and use cases all carry stable IDs — `FR-0006`, `NFR-0008`, `ADR-0009`, `UC-0001`, `D-0003`. Cite those. They survive rewording; a quoted sentence does not.

**4. Status before content.** `Approved`, `Accepted`, `Proposed`, `Draft`, `Idea` and `Selected as MVP` mean materially different things. `Approved` marks a repository-level decision; the HR package's legacy `Accepted` records remain pending Caldova ratification. **Three use cases are in MVP scope; only UC-0001 is specified.** Fifteen are candidates with no commitment attached.

---

## The three claims most often stated wrong

Stated here because they are load-bearing and easy to get backwards:

> **The agent never holds the Workday connector.** Caldova IT confirmed Microsoft's Workday connector as the access API, but its `Execute SOAP operation` action is a raw pass-through. A governed **Workday Access Layer** sits in front of it and owns the connection. ([ADR-0009](adr/0009-workday-access-via-connector-behind-governed-layer.md))

> **Dataverse holds process state, never master data.** The test: *if Workday were wiped and restored from backup, would this column now be wrong?* If yes, it does not belong in Dataverse. ([ADR-0007](adr/0007-dataverse-process-state-boundary.md))

> **The Organizational Data Service is not confirmed and cannot serve the MVP.** It imports *workers*; the MVP operates on *candidates and pre-hires*. ([ADR-0010](adr/0010-organizational-data-service-as-people-context.md), status Proposed)

> **The workflow owns the process; the agent owns the judgement.** Determinism cannot live in the agent — the GitHub Copilot harness exposes no orchestration configuration. The audit trail is written by deterministic workflow steps, never left to the agent's discretion. ([ADR-0011](adr/0011-workflow-first-process-architecture.md))

> **Caldova positions at Level 3 — agentic — and the MVP is three use cases**: UC-0001, UC-0010 and UC-0005. Fifteen others are candidates only. ([`prd.md`](prd.md) §2.1–2.2)

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

The Infrastructure domain contains the approved lean control-plane topology together with source-derived Proposed Baseline implementation guidance. It describes discovery, validation, ALM, security, and recovery boundaries; it does not prove that tenant configuration, Azure resources, Azure DevOps objects, Power Platform environments, GitHub controls, pipelines, identities, or services currently exist. The attended authority is [ADR-0001](adr/0001-azure-devops-as-engineering-control-plane.md), [ADR-0002](adr/0002-github-first-bootstrap-and-the-role-of-azure-repos.md), [ADR-0012](adr/0012-per-tenant-github-repository-and-account-topology.md), and the [Tenant 1 Lean Engineering Platform Design](specs/2026-09-28-tenant-1-lean-engineering-platform-design.md).

| Document | Purpose |
|---|---|
| [Infrastructure Domain](../infra/README.md) | Defines domain ownership, current no-payload boundary, planned layout, tool boundaries, and document map. |
| [Tenant Setup and Configuration](../infra/docs/10-tenant-setup-and-configuration.md) | Defines the reviewed tenant metadata, desired manifest, observed evidence, explicit intent, and terminology boundaries. |
| [Identity and Access](../infra/docs/11-identity-and-access.md) | Proposed guidance retained for context; the lean sprint uses attended local operation and creates no bootstrap identity or OIDC federation. |
| [Power Platform Environments and ALM](../infra/docs/12-power-platform-environments-and-alm.md) | Defines future DEV-to-TEST-to-PROD ALM, solution ordering, variables, connections, and evidence requirements. |
| [Azure DevOps Engineering Control Plane](../infra/docs/13-azure-devops-engineering-control-plane.md) | Describes the approved single-backlog and sole-product-source split, discovery candidates, API constraints, and future pipeline boundary. |
| [GitHub Repository Blueprint](../infra/docs/14-github-repository-blueprint.md) | Proposed guidance retained for context; the approved solo-owner profile requires pull requests and validation, with zero mandatory approvals and no required CODEOWNERS review. |
| [Agent and Workload Configuration](../infra/docs/15-agent-workload-configuration.md) | Defines future agent, flow, app, grounding, packaging, release, and data-prohibition contracts. |
| [Security, Governance and Compliance](../infra/docs/16-security-governance-and-compliance.md) | Defines evidence-first security principles and proposed DLP, Dataverse, identity, audit, and compliance controls. |
| [Bootstrap and Provisioning](../infra/docs/17-bootstrap-and-provisioning.md) | Defines the attended local state machine, exact minimum-access preflight/read-back, subscription `what-if`, and no-deployment boundary. |
| [Multi-Tenant Provisioning](../infra/docs/18-multi-tenant-provisioning.md) | Proposed guidance retained for context; the lean sprint is Tenant 1 only and does not alter or migrate existing Tenant 2 files. |
| [Bootstrap Recovery](../infra/docs/19-bootstrap-recovery.md) | Defines attended recovery from nine failure states without bypassing validation, approvals, or least privilege. |
| [Tenant Trust Activation Runbook](../infra/docs/20-tenant-trust-activation-runbook.md) | Superseded stop notice for the dormant and unsupported trust command; reuse requires a new reviewed design. |
| [Tenant 1 Lean Engineering Platform Runbook](../infra/docs/24-tenant-1-lean-platform-runbook.md) | Orders tool merge, current-main validation, attended local read-back, governance, Basic Boards, optional empty-repository decision, final governed transaction, and acceptance read-back without claiming execution. |
| [Tenant 1 Lean Engineering Platform Acceptance Review](reviews/2026-09-28-tenant-1-lean-engineering-platform-acceptance-review.md) | Draft control-by-control acceptance record; every outcome remains `Not Run` until supported by current sanitized read-back. |
| [Infrastructure Solution Sources](../infra/src/solutions/README.md) | Defines ownership and exclusions for future unpacked Infrastructure Power Platform solution source. |

**This map is unchanged by the Phase 4 HR solution intake.** The approved Tenant 1 target keeps product source and [Bicep Composition](../infra/src/bicep/main.bicep) in GitHub. Tenant 1 private configuration uses the ignored local `tenant1.local.psd1` with an encrypted, restore-tested backup outside Git. Azure Boards remains on Basic, and a future Azure Pipeline consumes GitHub directly. No private Azure Repo, OIDC bootstrap, `bootstrap-tenant1` Environment, Basic-to-Agile conversion, Azure Pipeline, or live deployment is a current target.

---

## Superseded (Phase 2)

The original Proposed Baseline product/HR operating model is superseded by the documents above, reconciled through the [Phase 4 HR Solution Functional Design Intake](reviews/2026-09-24-phase-4-hr-solution-functional-design-intake.md).

For historical questions, start with the [Phase 2 Operating Model Archive catalogue](archive/phase-2-operating-model/README.md). It records the purpose and current replacement for each immutable snapshot. Do not use the snapshots as current authority.

---

## Source material

Everything here derives from customer-supplied material:

| Source | Contributed |
|---|---|
| The customer-supplied UC-0001 draft PRD | UC-0001 scope, business rules, functional requirements, acceptance criteria, open decisions |
| The customer-supplied UC-0001 artefact inventory | Artefact inventory, ownership, status |
| The customer-supplied HR AI use-case workbook | 16 use cases with business value, KPIs, personas, complexity and risk; plus 2 HR Ops CH pain points (UC-0017, UC-0018) |
| The source Workday presentation | Workday as system of record, integration landscape, functional areas in use |

Microsoft product behaviour is grounded in Microsoft Learn — the Workday connector reference and the Organizational Data Service import guide — and cited where it is load-bearing.
