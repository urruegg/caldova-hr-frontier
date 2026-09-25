# `docs/adr/` — Architecture Decision Records

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-24 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Cross-cutting (all solution domains) |
| **References** | [HR Solution Functional Design Intake](../specs/2026-09-24-hr-solution-functional-design-intake-design.md) |

**Purpose.** The decisions that are expensive or impossible to reverse, each recorded with the options rejected and the price paid. **This folder answers *why*.** Every other folder answers *what*.

**Use this folder when** a proposed change contradicts how the platform works, when someone asks why something is the way it is, or when you are about to design around a constraint that exists for a reason.

---

## The records

| ADR | Decision | Status |
|---|---|---|
| [0001](0001-azure-devops-as-engineering-control-plane.md) | Azure DevOps as the Engineering Control Plane, GitHub as the Digital Factory | Proposed Baseline |
| [0002](0002-github-first-bootstrap-and-the-role-of-azure-repos.md) | GitHub-First Bootstrap, and the Role of Azure Repos | Proposed Baseline |
| [0003](0003-bicep-and-powershell-for-infrastructure-as-code.md) | Bicep and PowerShell for Infrastructure as Code | Proposed Baseline |
| [0004](0004-domain-solution-architecture-and-publisher.md) | Domain Solution Architecture, Naming and Publisher — adopt the tenant's supplied publisher; realized as `calhr` for Tenant 1 & 2, `gfhr` for Tenant 3 | Proposed Baseline |
| [0005](0005-workday-as-system-of-record.md) | Workday is the system of record for employee master data | Accepted |
| [0006](0006-agentic-toolset-and-hr-control-plane.md) | The agentic toolset and HR control plane split, and why a code app | Accepted |
| [0007](0007-dataverse-process-state-boundary.md) | The Dataverse process-state boundary | Accepted |
| [0008](0008-human-in-the-loop-and-write-envelope.md) | Human in the loop, and the agent write envelope | Accepted |
| [0009](0009-workday-access-via-connector-behind-governed-layer.md) | Workday access through the Microsoft connector, behind a governed access layer | Accepted |
| [0010](0010-organizational-data-service-as-people-context.md) | Organizational Data Service as people context, not an integration path | **Proposed** |
| [0011](0011-workflow-first-process-architecture.md) | Workflow-first process architecture — the workflow owns the process, the agent owns the judgement | Accepted |

ADRs 0001–0004 are Proposed Baseline candidates from the infrastructure/governance intake (Phase 1); they are not yet accepted repository decisions. ADRs 0005–0011 are the HR solution architecture set from the Phase 4 intake; their own "Accepted"/"Proposed" status reflects the design package's internal decision tracking and is likewise pending repository-level ratification. All Accepted records among 0005–0011 are **pending GF ratification** — accepted as the design position of this package, not yet countersigned by GF.

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

**1. An Accepted ADR outranks narrative text anywhere else.** If `solution-design.md` and an Accepted ADR conflict, the ADR is correct and the design document has drifted. Report the drift rather than reconciling it silently.

**2. Status is not decoration.** ADR-0010 is **Proposed** — the Organizational Data Service is not confirmed by GF, and nothing depends on it. Do not describe it as part of the platform.

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
4. Set Status to `Proposed` until it is agreed. Supersede rather than edit an Accepted record: mark the old one `Superseded by ADR-nnnn` and leave its text intact, because the reasoning stays useful even when the decision does not.
5. Link it from `docs/README.md`, the package `README.md`, and any document whose behaviour it changes.

**What deserves an ADR:** anything expensive to reverse — a system of record, a data boundary, an enforcement mechanism, a publisher prefix, a harness choice, a process shape. **What does not:** anything a pull request can undo.

**Still unwritten, and probably owed one:** model lifecycle (D-0010) and the connected-agent envelope rule (D-0011). Both are recorded as open decisions in `prd.md` §10 rather than settled here.
