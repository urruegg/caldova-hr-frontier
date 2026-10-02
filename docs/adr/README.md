# `docs/adr/` — Architecture Decision Records

| Field | Value |
|---|---|
| **Version** | 1.4 |
| **Date** | 2026-10-02 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Cross-cutting (all solution domains) |
| **References** | [Tenant 1 Lean Engineering Platform Design](../specs/2026-09-28-tenant-1-lean-engineering-platform-design.md), [HR Solution Functional Design Intake](../specs/2026-09-24-hr-solution-functional-design-intake-design.md) |

## Purpose and Authority

This folder owns decisions that are expensive or impossible to reverse, each recorded with the options rejected and the price paid. It answers *why*. Approved repository-level ADRs override conflicting narrative; other statuses govern only as stated in their metadata and decision context.

**Use this folder when** a proposed change contradicts how the platform works, when someone asks why something is the way it is, or when you are about to design around a constraint that exists for a reason.

## Contains and Does Not Contain

This folder contains architecture decision records. It does not contain design specifications, implementation plans, open-decision lists, runbooks, or implementation evidence.

## Reading Order

Start with the [documentation knowledge map](../README.md), select the relevant record below, then read its Context, Options considered, Decision, Consequences, and Compliance sections. Check metadata status before applying it.

## Naming and Lifecycle

Use the next four-digit stable identifier and a lowercase descriptive filename. New decisions start `Proposed`. Supersede rather than rewrite an Approved record, and link the successor from both records and this catalogue.

## Catalogue

| Successor or next stage | ADR | Status | Purpose | Authority |
|---|---|---|---|---|
| [Lean platform design](../specs/2026-09-28-tenant-1-lean-engineering-platform-design.md) | [ADR-0001](0001-azure-devops-as-engineering-control-plane.md) | Approved | Establishes Azure DevOps as the engineering control plane and GitHub as the digital factory. | Repository-level approved decision. |
| [Lean platform design](../specs/2026-09-28-tenant-1-lean-engineering-platform-design.md) | [ADR-0002](0002-github-first-bootstrap-and-the-role-of-azure-repos.md) | Approved | Establishes GitHub source authority and the ignored local Tenant 1 configuration boundary. | Repository-level approved decision. |
| Separate ratification required | [ADR-0003](0003-bicep-and-powershell-for-infrastructure-as-code.md) | Proposed Baseline | Proposes Bicep and PowerShell for infrastructure as code. | Proposed intake decision; not independently approved. |
| Separate ratification required | [ADR-0004](0004-domain-solution-architecture-and-publisher.md) | Proposed Baseline | Proposes domain solution naming and publisher ownership. | Proposed intake decision; not independently approved. |
| Caldova ratification pending | [ADR-0005](0005-workday-as-system-of-record.md) | Proposed Baseline | Establishes Workday as the employee master-data system of record. | Accepted within the HR design package; repository metadata remains Proposed Baseline. |
| Caldova ratification pending | [ADR-0006](0006-agentic-toolset-and-hr-control-plane.md) | Proposed Baseline | Defines the agentic toolset and HR control-plane split. | Accepted within the HR design package; repository metadata remains Proposed Baseline. |
| Caldova ratification pending | [ADR-0007](0007-dataverse-process-state-boundary.md) | Proposed Baseline | Defines the Dataverse process-state boundary. | Accepted within the HR design package; repository metadata remains Proposed Baseline. |
| Caldova ratification pending | [ADR-0008](0008-human-in-the-loop-and-write-envelope.md) | Proposed Baseline | Defines human authority and the agent write envelope. | Accepted within the HR design package; repository metadata remains Proposed Baseline. |
| Caldova ratification pending | [ADR-0009](0009-workday-access-via-connector-behind-governed-layer.md) | Proposed Baseline | Places the Microsoft Workday connector behind a governed access layer. | Accepted within the HR design package; repository metadata remains Proposed Baseline. |
| Validate product fit before any implementation | [ADR-0010](0010-organizational-data-service-as-people-context.md) | Proposed Baseline | Treats Organizational Data Service as optional people context, not an integration path. | Proposed within the HR design package and not confirmed by Caldova. |
| Caldova ratification pending | [ADR-0011](0011-workflow-first-process-architecture.md) | Proposed Baseline | Defines workflow-first process architecture. | Accepted within the HR design package; repository metadata remains Proposed Baseline. |
| [Lean platform design](../specs/2026-09-28-tenant-1-lean-engineering-platform-design.md) | [ADR-0012](0012-per-tenant-github-repository-and-account-topology.md) | Approved | Establishes per-tenant GitHub repository and account topology. | Repository-level approved decision. |

ADRs 0001, 0002, and 0012 are repository-level **Approved** decisions for Option A in the attended [Tenant 1 Lean Engineering Platform Design](../specs/2026-09-28-tenant-1-lean-engineering-platform-design.md). They establish GitHub as sole source authority, Azure Boards Basic as the single backlog, future Azure Pipelines consuming GitHub directly, and ignored local Tenant 1 private configuration. ADRs 0003 and 0004 remain Proposed Baseline candidates from the infrastructure/governance intake. ADRs 0005–0011 are the HR solution architecture set from the Phase 4 intake; their own "Accepted"/"Proposed" status reflects the design package's internal decision tracking and remains pending repository-level ratification. All Accepted records among 0005–0011 are **pending Caldova ratification** — accepted as the design position of that package, not yet countersigned by Caldova.

---

## How to read one

Each record carries the same sections, and two of them carry most of the value:

| Section | Why it is there |
|---|---|
| **Context** | The forces that made a decision necessary. If these change, the decision should be revisited |
| **Decision** | The commitment, stated as numbered points so it can be cited precisely |
| **Options considered** | **The rejected alternatives, with the reason.** Read this before proposing one of them again |
| **Consequences** | Positive, negative and accepted risks. The negatives are real and were accepted knowingly |
| **Compliance** | The questions a future change must answer. **This is the reusable part** |

> **Read "Options considered" first when you disagree with a decision.** The alternative you have in mind is usually there, with the reason it was not taken. If it is not there, that is genuinely new information and worth raising.

---

## Evidence rules for agents

**1. A repository-level Approved ADR outranks narrative text anywhere else.** If `solution-design.md` and an Approved ADR conflict, the ADR is correct and the design document has drifted. Report the drift rather than reconciling it silently. Legacy "Accepted" statuses in the Phase 4 HR package remain package decisions pending repository-level ratification.

**2. Status is not decoration.** ADR-0010 is **Proposed** — the Organizational Data Service is not confirmed by Caldova, and nothing depends on it. Do not describe it as part of the platform.

**3. Cite the ADR number.** `ADR-0009` survives rewording; a quoted sentence does not.

**4. Do not infer a decision that is not here.** Absence of an ADR means the decision has not been made, not that any answer is acceptable. Open decisions live in `prd.md` §10 and `solution-design.md` §11.

**5. The Compliance section is a test, not a summary.** When evaluating a proposed change, run its questions literally.

---

## The three most consequential, and what they forbid

> **ADR-0007 — the Dataverse boundary.** Mechanical test: *if Workday were wiped and restored from backup, would this column now be wrong?* If yes, it does not belong in Dataverse. Apply this at every schema change, not at review.

> **ADR-0008 + ADR-0009 — the write envelope and its enforcement.** The envelope is enforced in three independent places: agent rules, the Workday Access Layer, and the Workday Integration System User's permissions. **The agent never holds the Workday connector directly** — its `Execute SOAP operation` action is a raw pass-through, and granting it to an agent that reads externally supplied PDFs would put the whole permission surface behind a prompt.

> **ADR-0005 — Workday as system of record.** No component holds a persistent copy of employee master data. Every read is live. The cost — a round-trip per read, and a hard dependency on connector availability — was accepted deliberately.

> **ADR-0011 — workflow-first.** Determinism cannot live in the agent: the GitHub Copilot harness applies its orchestration model to all agents and exposes no configuration for it. So the step sequence, the audit trail and the escalation path run as a deterministic workflow, and the agent is called only where reasoning is required. **A step that cannot state why it needs reasoning is a workflow step.**

---

## Adding a record

1. Take the next number. **Numbers are never reused**, including after a record is superseded.
2. Name it `adr-<nnnn>-<context>.md`, lowercase, hyphenated.
3. Follow the existing section structure. **Options considered and Consequences are not optional** — a record without them documents an outcome, not a decision.
4. Set Status to `Proposed` until it is agreed. Supersede rather than edit an Approved record: mark the old one `Superseded by ADR-nnnn` and leave its text intact, because the reasoning stays useful even when the decision does not.
5. Link it from `docs/README.md`, the package `README.md`, and any document whose behaviour it changes.

**What deserves an ADR:** anything expensive to reverse — a system of record, a data boundary, an enforcement mechanism, a publisher prefix, a harness choice, a process shape. **What does not:** anything a pull request can undo.

**Still unwritten, and probably owed one:** model lifecycle (D-0010) and the connected-agent envelope rule (D-0011). Both are recorded as open decisions in `prd.md` §10 rather than settled here.

## Domain Links

- [Documentation knowledge map](../README.md)
- [Specifications](../specs/README.md)
- [HR domain](../../hr/README.md)
- [Infrastructure domain](../../infra/README.md)
- [Data domain](../../data/README.md)

## Board Synchronization

Not applicable. ADRs do not create or infer Azure Boards identifiers.
