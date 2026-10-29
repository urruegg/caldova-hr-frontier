# `docs/` — Platform documentation

| Field | Value |
|---|---|
| **Version** | 1.17 |
| **Date** | 2026-10-29 |
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

## GF Draft Packages

For receiving the complete change set, start with the
[detailed GF handover](reviews/2026-10-29-gf-project-handover-review.md).
It links all eight packages, explains implemented versus planned artifacts,
records validation/approval blockers and includes an exhaustive file/hash inventory.

The following are eight separate GF starting-point handover packages, each with its own sprint, idea and specification. All twenty-four primary documents are **Draft**. They do not graduate or replace existing Caldova portfolio records, commit delivery dates, or authorize live changes. Implementation plans, proposed ADRs, the identity source kit and the gated preview agent are supporting artifacts, not additional primary documents.

| Topic | Sprint document | Idea document | Specification |
|---|---|---|---|
| Functional: SSE HR Policy assistant | [Draft sprint](plans/2026-10-28-gf-sse-hr-policy-assistant-sprint.md) | [Draft idea](ideas/gf-sse-hr-policy-assistant-idea.md) | [Draft specification](specs/2026-10-28-gf-sse-hr-policy-assistant-design.md) |
| Functional: Recruiting - Job Requisition and Job Posting agent | [Draft sprint](plans/2026-10-28-gf-recruiting-requisition-posting-agent-sprint.md) | [Draft idea](ideas/gf-recruiting-requisition-posting-agent-idea.md) | [Draft specification](specs/2026-10-28-gf-recruiting-requisition-posting-agent-design.md) |
| Functional: HR Operations Agent | [Draft sprint](plans/2026-10-28-gf-hr-operations-agent-sprint.md) | [Draft idea](ideas/gf-hr-operations-agent-idea.md) | [Draft specification](specs/2026-10-28-gf-hr-operations-agent-design.md) |
| Technical: GF Azure DevOps repository | [Draft sprint](plans/2026-10-28-gf-azure-devops-repository-sprint.md) | [Draft idea](ideas/gf-azure-devops-repository-idea.md) | [Draft specification](specs/2026-10-28-gf-azure-devops-repository-design.md) |
| Technical: Azure DevOps CI/CD and DEV solution capture | [Draft sprint](plans/2026-10-28-gf-azure-devops-solution-cicd-sprint.md) | [Draft idea](ideas/gf-azure-devops-solution-cicd-idea.md) | [Draft specification](specs/2026-10-28-gf-azure-devops-solution-cicd-design.md) |
| Functional: ESS-equivalent employee self-service rebuild | [Draft sprint](plans/2026-10-28-gf-ess-github-harness-workiq-sprint.md) | [Draft idea](ideas/gf-ess-github-harness-workiq-idea.md) | [Draft specification](specs/2026-10-28-gf-ess-github-harness-workiq-design.md) |
| Technical: Blueprint and project progress overview | [Draft sprint](plans/2026-10-29-gf-blueprint-progress-overview-sprint.md) | [Draft idea](ideas/gf-blueprint-progress-overview-idea.md) | [Draft specification](specs/2026-10-29-gf-blueprint-progress-overview-design.md) |
| Technical: Grounded Copilot Studio agent identity kit | [Draft sprint](plans/2026-10-29-gf-agent-identity-kit-sprint.md) | [Draft idea](ideas/gf-agent-identity-kit-idea.md) | [Draft specification](specs/2026-10-29-gf-agent-identity-kit-design.md) |

Scope was refined interactively with the repository owner on 2026-10-28. The original five packages use the supplied build brief; the sixth ESS-equivalent package uses public Microsoft references and separately confirmed scope. The original SOPs, policy PDFs, FAQ/workbooks, templates and evidence register have not been independently reviewed here. The drafts distinguish user decisions, reported evidence, proposals and open gates. HR Operations now has a detailed process but remains propose-only with writes blocked. No actual GF URL, named approver or delivery estimate is invented.

The seventh package was refined on 2026-10-29 from the locally supplied blueprint and repository-agent/source authority. It is project-overview enablement, not an additional customer workshop MVP. Its derived status must not promote the six work packages from Draft into delivered capabilities.

The eighth package intakes the supplied GF agent identity kit v1.0.0 with source
hashes/notices, four adopted runtime bindings and scoped guidance. GF written
approval to adapt is user-reported; original proposal status and technical
decisions remain visible. Identity adoption is not runtime delivery or approval
of every source-catalogue hypothesis.

GF's confirmed target is an independent Azure Repos source/PR authority after a reviewed one-time transfer, with no automatic GitHub synchronization. [ADR-0013](adr/0013-gf-azure-repos-source-authority.md) is the **Proposed Baseline** GF-scoped refinement of ADR-0001, ADR-0002 and ADR-0012, preserving their approved demo history. CI/CD includes reusable explicit DEV capture into branch/PR and TEST delivery only; production is later scope.

Continue review one question at a time: challenge and refine each answer before treating it as a settled requirement. Source-dependent decisions remain open until the SharePoint material and accountable owners support them.

### GF Source Basis and Publication Boundary

The local source is *Georg Fischer HR - MVP 1-3 agent canvases, processes, audiences and SharePoint BOM*, v1.0 dated 2026-10-28, supplied from outside this repository. It is marked confidential. Its original stays outside Git. The repository is public; permission to prepare the handover locally is **not permission to commit, push or upload confidential refinements publicly**. Verify the private GF destination and disclosure inventory before handover. This documentation change performs no commit, push, source upload or tenant operation.

References such as `brief 3.6 / E41` mean "reported by the supplied brief", not that the primary document or tenant condition was inspected. The brief's "received", "validated" and "in place" labels must not become local verification claims. Its workshop dates are context, not sprint commitments. Keep policy PDFs and employee intake in controlled SharePoint, and real personal data, tenant-specific values and private source attachments out of Git.

| Topic | Confirmed refinement or open decision |
|---|---|
| Original functional MVPs | Copilot Studio's **GitHub Copilot runtime harness** selected by the user. Native ESS templates remain excluded from those packages; the separate ESS-equivalent sixth package has its own gated scope. No silent standard-harness substitution; runtime choice is separate from GitHub source hosting. |
| Policy | Switzerland-only MVP; design supports later regional onboarding with separate sources, audience permissions, applicability, languages, owners, escalation and tests. Exact regional deployment topology is open. |
| Recruiting | **GF-REC-D01 remains open for HR stakeholders:** earlier approved agent-created requisition/publication versus brief manual Workday entry and recruiter publication. No operational Workday writes or publishing enabled while unresolved. |
| HR Operations | Detail the PeopleDoc-to-Workday proposal process; writes remain blocked until matching, field/document, approval, interface/identity, privacy and safety gates close. |
| Repository / CI/CD | Independent Azure Repos; explicit reusable DEV capture to branch/PR; reviewed-source build and TEST delivery. Prove chosen-harness packaging/deployment and preserve functional write blocks. PROD is later scope. |

Process and participant-interaction Mermaid diagrams live in each specification; dependency/gate diagrams live in each sprint. Idea canvases link to these authoritative diagrams rather than maintain competing copies. The drawings are proposed responsibilities and gates, not implementation evidence.

### CAT Reuse Assessment

The [CAT gallery](https://microsoft.github.io/cat-agent-skills/?platform=Copilot+Studio) was assessed on 2026-10-28. Its fetched page exposed only a QR-code entry, while the [repository source at `6b31474`](https://github.com/microsoft/cat-agent-skills/tree/6b31474a2c93f603ff8ce5659bc3cefbca0fe77a) contained many metadata/instruction entries. The assessment below therefore pins **source records**, not an assumed complete published gallery. This is a bounded shortlist relevant to the five packages, not an exhaustive catalogue review.

The [project support policy](https://github.com/microsoft/cat-agent-skills/blob/6b31474a2c93f603ff8ce5659bc3cefbca0fe77a/SUPPORT.md) describes an example implementation with community/project support, separate from support for underlying Microsoft services. The repository reports [MIT licensing](https://github.com/microsoft/cat-agent-skills/blob/6b31474a2c93f603ff8ce5659bc3cefbca0fe77a/LICENSE); bundled/transitive asset notices still require review. Metadata/instruction records were inspected; ZIP contents/dependencies were **not** installed, executed or validated.

| Candidate and inspected version | Fit | Recommendation and constraint |
|---|---|---|
| [Copilot Studio Knowledge Readiness](https://github.com/microsoft/cat-agent-skills/blob/6b31474a2c93f603ff8ce5659bc3cefbca0fe77a/src/content/skills/copilot-studio-knowledge-readiness.md), 1.0.0 | Policy corpus; Recruiting guidance preparation | Conditional **maker-side** aid for inventory, knowledge-versus-action separation and cleanup/test planning. Exported files do not establish live ACLs, metadata, indexing or permission readiness. Do not upload confidential material to the public gallery. |
| [Agent Evaluation Designer](https://github.com/microsoft/cat-agent-skills/blob/6b31474a2c93f603ff8ce5659bc3cefbca0fe77a/src/content/skills/agent-evaluation-designer.md), 1.0.0 | All three agents; shared CI/CD evaluation design | Recommend adapting the methodology: semantic grounding, deterministic safety/tool checks and human go/no-go. Not an executable CI runner. Validate harness-specific evaluation APIs, quotas and grading; never replace the agreed 66-policy-case target with its generic smaller starting set. |
| [Knowledge Source Router](https://github.com/microsoft/cat-agent-skills/blob/6b31474a2c93f603ff8ce5659bc3cefbca0fe77a/src/content/skills/knowledge-source-router.md), 2.0.0 | Future regional policy onboarding | Conditional pattern, **not required for the fixed Swiss MVP**. It assumes `sharepoint_metadata_filter` and `knowledge_search_sharepoint`; availability/contracts are unverified. Combine region metadata with approved/current sources and effective caller access. Disable its multi-country comparisons for the MVP; missing metadata must not broaden retrieval. |
| [Template-Based Document Generation](https://github.com/microsoft/cat-agent-skills/blob/6b31474a2c93f603ff8ce5659bc3cefbca0fe77a/src/content/skills/template-based-document-generation.md), 3.8.0 | Optional Recruiting Word output | Conditional candidate after approval of template, Python/sandbox/filesystem support, script dependencies, output storage/retention and tests. Restrict derived literals to GF-approved inputs/rules; its reports/work files may contain personal values. Not a Workday/publishing/approval capability. |
| [Copilot Studio Adaptive Card Builder](https://github.com/microsoft/cat-agent-skills/blob/6b31474a2c93f603ff8ce5659bc3cefbca0fe77a/src/content/skills/copilot-studio-adaptive-card-builder.md), 1.0.0 | Review/confirmation UI idea | **Not a drop-in MVP runtime dependency.** Its generated package explicitly targets standard-harness card/topic nodes. Validate a GitHub-harness-supported interaction or separately governed workflow/channel UX; a model emitting JSON is not a native rendered card. |
| [Copilot Studio Test Planner](https://github.com/microsoft/cat-agent-skills/blob/6b31474a2c93f603ff8ce5659bc3cefbca0fe77a/src/content/skills/copilot-studio-test-planner.md), 1.0.0 | Potential development test planning | Metadata/package is a **Cowork-only plugin**, despite the name. Not a Copilot Studio runtime plugin or proven pipeline runner; use the evaluation-methodology candidate instead. |
| [Assistente CLT para RH](https://github.com/microsoft/cat-agent-skills/blob/6b31474a2c93f603ff8ce5659bc3cefbca0fe77a/src/content/skills/clt-hr-assistant.md), version not stated | Superficially HR-related | Reject for these MVPs: Brazilian employment-law/payroll calculations and personal inputs do not fit approved Swiss-policy-only guidance or the no-employment-decision boundary. |
| [PDF Table Data Conversion](https://github.com/microsoft/cat-agent-skills/blob/6b31474a2c93f603ff8ce5659bc3cefbca0fe77a/src/content/skills/pdf-table-data-conversion.md), 1.0.0 | Superficially similar to HR Operations extraction | Do not use as the Operations extraction engine: exports tables to spreadsheets, not approved-field provenance/confidence, exact profile matching or server-enforced add-only updates. No assessed skill replaces the Workday Access Layer. |

**No candidate is admitted, installed or activated by this assessment.** Before reuse, record the accountable owner, exact source/bundle revision and checksum, license/notices, scripts/dependencies, execution/network/data locations, secret handling, least-privilege tools, selected-harness support, synthetic positive/negative tests and export/import asset coverage. Restrict any adapted instructions to the declared write envelope; a skill's instructions are not permission enforcement. Reuse must not enable memory for write-capable agents, Work IQ or connected-agent delegation contrary to existing governance.

The [repository package](specs/2026-10-28-gf-azure-devops-repository-design.md#9-source-layout-and-reusable-component-boundary) owns future vendoring/source admission; the [CI/CD package](specs/2026-10-28-gf-azure-devops-solution-cicd-design.md#8-selected-harness-evidence-and-reuse) owns bundle inclusion and regression evidence. Neither needs a CAT plugin to clone a repository, create pipelines or govern Workday access.

## GF ESS-Equivalent Rebuild

This is the sixth linked handover set in the package index, with a matching idea, the existing sprint and the specification. It remains a separately gated proposal, not a replacement for the original five packages or an in-place migration of an existing ESS deployment.

| Artifact | Status | Purpose |
|---|---|---|
| [ESS-equivalent idea](ideas/gf-ess-github-harness-workiq-idea.md) | Draft | Outcome, user/capability canvas, six-operation scope, business-value hypothesis, readiness questions and GF handover reading order. |
| [ESS-equivalent specification](specs/2026-10-28-gf-ess-github-harness-workiq-design.md) | Draft | First-party ESS/Developer Kit capability and gap analysis, per-use-case M365 matrix, six self-only Workday actions, Mermaid architecture/state/case interactions, identity, audit and value criteria. |
| [ESS-equivalent sprint](plans/2026-10-28-gf-ess-github-harness-workiq-sprint.md) | Draft | Evaluation-first capability/identity proof, independent scenario tracks and TEST/business acceptance gates; no invented time box or commitments. |
| [ESS-equivalent implementation plan](plans/2026-10-28-gf-ess-github-harness-workiq-implementation.md) | Draft | Ten test-first slices, intended source/contracts/tests, safe activation, TEST delivery and value/stop/reconciliation acceptance, derived after written-specification review. |
| [ADR-0014](adr/0014-gf-ess-workiq-and-self-service-write-envelope.md) | Proposed Baseline | Scoped Work IQ proposal and separate ESS write envelope; preserves HR Operations add-only protections and Access Layer ownership. |

The user selected Copilot Studio's GitHub Copilot runtime harness and separate governed integration paths: Work IQ for justified M365 capabilities, employee-delegated OAuth for Workday. Selected transactions are personal phone/email/address/emergency-contact updates, time-off submission through Workday's approval, and Workday Help case creation only after review/confirmation.

Privacy/Security approval is user-reported; its formal scope/reference is not verified. Workday Help API support, some update APIs, delegated identity propagation, M365 resource/action enforcement and chosen-harness ALM remain explicit gates. Documentation does not install tools, enable connections or grant operational permission.

The Developer Kit's pinned main branch now targets declarative ESS; its Custom Engine branch and developer MCP are assessed separately. GitHub Copilot authoring, Copilot Studio's GitHub runtime harness, Work IQ and a Workday connector are not interchangeable boundaries. The specification cites exact sources/revisions and records what was not proven.

The user reviewed the written specification as the basis for the Draft implementation plan. That planning review does not ratify operational permissions or authorize implementation, public publication or live deployment.

## GF Blueprint Progress Overview

The imported [Georg Fischer Frontier Company Blueprint.html](Georg%20Fischer%20Frontier%20Company%20Blueprint.html) is a local hypothesis baseline, version 0.5 dated 2026-10-28. It contains embedded structured data and a renderer; its browser notes are not a shared delivery record. The original HTML is preserved unchanged by this planning work and has not been published or transferred.

| Artifact | Status | Purpose |
|---|---|---|
| [Blueprint overview idea](ideas/gf-blueprint-progress-overview-idea.md) | Draft | Outcome, evidence-first maintenance model, stakeholder responsibilities and handover boundary. |
| [Blueprint overview sprint](plans/2026-10-29-gf-blueprint-progress-overview-sprint.md) | Draft | Source/contracts, controlled rendering, stale-output checks, scoped agent and customer acceptance work. |
| [Blueprint overview specification](specs/2026-10-29-gf-blueprint-progress-overview-design.md) | Draft | Authority, status/freshness model, reviewed narrative changes, HTML preservation and gated preview-agent design. |
| [Blueprint overview implementation plan](plans/2026-10-29-gf-blueprint-progress-overview-implementation.md) | Draft | Provisional nine-task plan covering contracts, controlled projection, freshness enforcement, role review, browser notes and clean-folder handover. |
| [Blueprint Maintainer preview](../.github/agents/blueprint-maintainer.agent.md) | Proposed Baseline | Manually invoked read/search-only analysis and recommendations; no editing, execution, remote access or automated refresh. |

Repository sprint/delivery records and verified evidence govern progress first; Azure Boards is later scope. The intended operating model updates the derived overview in the same reviewed change and rejects stale/inconsistent output through existing validation. A custom agent profile is not a continuous runner.

The user explicitly approved the narrow read/search-only preview, which is now created with focused static contract tests. Written-specification review was requested but the user was unavailable, so the implementation plan remains provisional. The write-capable maintainer, structured inputs, renderer, synchronization and stale gate remain planned. Full activation requires that review, a scoped portfolio amendment and proven controls; no additional operational writer or HTML-edit permission is silently introduced. Host invocation/loading has not been verified by static tests.

## GF Grounded Agent Identity

The [curated kit](brand/gf-agent-identity/README.md) extends the brand folder
without changing the Caldova theme or supplied blueprint. It preserves 466 source
files and records the four approved identity mappings for Policy, Recruiting,
HR Operations and the new ESS-equivalent. Source automation/instructions are
inactive `.txt` references.

| Artifact | Status | Purpose |
|---|---|---|
| [Identity-kit idea](ideas/gf-agent-identity-kit-idea.md) | Draft | Outcome, source approval/mapping scope and readiness questions. |
| [Identity-kit sprint](plans/2026-10-29-gf-agent-identity-kit-sprint.md) | Draft | Curated intake/static checks and future owner/source/stamping/read-back tracks. |
| [Identity-kit specification](specs/2026-10-29-gf-agent-identity-kit-design.md) | Draft | Identity contracts, source preservation, environment rules and guarded integration. |
| [Identity-kit implementation plan](plans/2026-10-29-gf-agent-identity-kit-implementation.md) | Draft | Provisional seven-task plan for source/owner policy, target-format proof, fail-closed adaptation, artifact/read-back and authorized handover. |

Use the kit/bindings for all GF Copilot Studio planning/building. New unmapped
runtime agents require reviewed extension; repository-working agents and
technical packages are not renamed. The already-failing blanket anonymization
branding guard needs a reviewed customer-scope decision before merge/public
handover. No guard is disabled and no full-repository branding pass is claimed.

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
.github/copilot-instructions.md
docs/
├── README.md
├── ideas/
│   └── README.md
├── specs/
│   └── README.md
├── plans/
│   └── README.md
├── reviews/
│   └── README.md
├── archive/
│   ├── README.md
│   └── phase-2-operating-model/
│       └── README.md
├── adr/
├── brand/
├── prd.md
├── solution-design.md
└── hr-journey-and-raci.md
hr/
├── README.md
└── docs/
    └── use-cases/
        └── README.md
infra/
├── README.md
└── docs/
    └── README.md
data/
└── README.md
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

## Authority and Conflict Order

Navigation order is not an authority override. When maintained records conflict, use this order:

1. law, organizational governance, and explicit human authority;
2. Accepted or Approved policies, ADRs, and specifications;
3. approved platform requirements and cross-cutting governance;
4. the more specific domain or use-case contract, provided it does not weaken higher governance;
5. the approved implementation plan for the selected specification; and
6. evidence of the implemented state.

Check status before content. `Superseded`, `Draft`, `Proposed Baseline`, `Idea`, and `Graduated` material cannot silently override Approved or Accepted authority. README catalogue text is a routing aid; if it conflicts with an authoritative child, the child wins and the README must be repaired.

For a question about what currently exists or passed, current reproducible evidence controls. An approved design or plan defines intent but does not prove implementation.

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
| `uc-` | Central portfolio idea record | `docs/ideas/uc-<number>-<context>.md` |
| `uc-` package | Detailed HR use-case package | `hr/docs/use-cases/uc-<number>-<context>/` |
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
