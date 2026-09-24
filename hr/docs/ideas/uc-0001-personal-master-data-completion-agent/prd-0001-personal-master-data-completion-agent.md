# PRD — Personal Master Data Completion Agent

> **Document ID:** GF-PRD-01
> **Status:** Draft 0.3 — supersedes *PRD_Personal_Master_Data_Completion_Agent_Switzerland_Draft_0.1*
> **Scope:** Switzerland MVP only
> **Document owner:** DAAI / HR AI Business Lead
> **Process owner:** Switzerland HR Operations
> **Systems in scope:** SharePoint, Microsoft Copilot Studio (**workflows and agents**), Power Platform (Dataverse, Power Apps code app), the **Workday Access Layer** over the **Microsoft Workday connector**, Workday
> **MVP position:** the first of three use cases proving GF's **Level 3 — agentic** position. See [`prd.md`](../../../../docs/prd.md) §2.1–2.2

---

## 1. Executive Summary

HR Operations manually downloads new-employee PDF documents from PeopleDoc and stores them in a SharePoint *New Employees* folder. A **deterministic workflow** drives the run end to end; where a document defeats the deterministic extraction tier, it calls an **agent node** to read and interpret it. Approved personal master data is matched to exactly one existing Workday candidate or pre-hire profile, and **missing approved values only** are added through the Workday Access Layer.

> **The workflow owns the process; the agent owns the judgement.** This is [ADR-0011](../../../../docs/adr/0011-workflow-first-process-architecture.md), and it is why the audit record for this agent can be trusted: the step sequence and every audit write are deterministic, and reasoning is invoked only where a rule cannot express the work.

The agent never creates an employee, never overwrites an existing Workday value, and never writes when the match is missing or ambiguous. Missing values in a PDF do not stop the remaining fields from being processed. HR Operations reviews outcomes in the **HR Employee Control Plane App** and follows up on what remains incomplete.

> **North-star outcome**
> Reduce manual Workday data entry while keeping HR in control of data quality. The agent completes safe, approved updates; HR reviews additions and follows up on remaining gaps.

### What changed from Draft 0.1

| Area | Draft 0.1 | Draft 0.2 |
|---|---|---|
| Where HR sees results | Weekly Workday validation report (ownership open) | **HR Employee Control Plane App** (Power Apps code app) for run review and exception handling; Workday reporting retained for master-data validation |
| Process state | Implicit | **Dataverse holds process state only** — never a copy of Workday master data ([ADR-0007](../../../../docs/adr/0007-dataverse-process-state-boundary.md)) |
| Audit repository | "exact technical location remains TBD" | **Dataverse audit tables**, surfaced in the control plane app and exportable |
| Interaction surface | Not specified | **Microsoft 365 Copilot, Microsoft Teams and Cowork** for HR Operations |
| Trigger | "Manual agent processing – TBD" | **HR-initiated run** from the control plane app, with a scheduled option deferred to a later increment |
| Process architecture *(0.3)* | Agent-centric | **Workflow-first**: a deterministic Copilot Studio workflow owns the sequence, audit and escalation; the agent is an invoked node ([ADR-0011](../../../../docs/adr/0011-workflow-first-process-architecture.md)) |
| Extraction *(0.3)* | Single path | **Two-tier**: deterministic document processing first, agent node only for what it cannot handle |
| Human in the loop *(0.3)* | Agent instruction | A **workflow action** that pauses the run, collects a named reviewer's decision and resumes |

---

## 2. Problem and Objective

| Current problem | MVP objective |
|---|---|
| Personal master data sits in employee PDFs and must be identified and typed into Workday by hand | Extract and add approved missing values to the existing Workday profile |
| Incomplete documents delay or interrupt manual processing | Process every available approved value; report the fields that remain blank |
| Repeated manual handling risks duplicate entry or overwriting correct data | Apply strict no-overwrite, single-match and duplicate-prevention controls |
| HR has no visibility of what was added and what is still missing | Give HR a single place to see every run, every field action and every exception |

---

## 3. Scope

### 3.1 In scope

- PDF files manually placed in SharePoint `/New Employees` by HR Operations.
- HR-initiated agent run from the HR Employee Control Plane App.
- Reading and grouping PDFs belonging to one employee package.
- Field selection from `Personalstammdaten_Felder_DE_EN.xlsx`: the English field name in **column C**, only where **column E = yes**.
- Matching exactly one existing Workday profile. *(Matching key is open — see D-03.)*
- Adding missing approved values to Workday through the Workday Access Layer.
- Run, field-action and exception records in Dataverse, surfaced in the control plane app.
- Workday validation reporting for master-data completeness.
- Moving processed PDFs to `/Complete`, or to `/Exceptions` where the package could not be completed.

### 3.2 Out of scope

- Creating a Workday candidate, pre-hire or worker record.
- Overwriting or correcting an existing Workday value.
- Deciding on conflicting values, policy exceptions or data correctness.
- Completing information that is not present in the PDFs.
- Any country other than Switzerland.
- Replacing PeopleDoc, or automating the PeopleDoc export itself.

---

## 4. Systems and Roles

| Component | Role in the MVP |
|---|---|
| **Workday** | **System of record** for employee master data. The only place master data is authoritative ([ADR-0005](../../../../docs/adr/0005-workday-as-system-of-record.md)) |
| SharePoint `/New Employees` | Source of PDFs exported from PeopleDoc |
| SharePoint `/Complete`, `/Exceptions` | Archive and quarantine after a recorded outcome |
| **Microsoft Copilot Studio agent** | Reads documents, applies business rules, coordinates Workday updates and records outcomes |
| **Workday Access Layer** | The governed path used to search a profile, read current values and add approved missing values. Exposes three actions and nothing else. It owns the **Microsoft Workday connector** connection; the agent does not — see [ADR-0009](../../../../docs/adr/0009-workday-access-via-connector-behind-governed-layer.md) |
| **Microsoft Workday connector** | Microsoft's Premium connector, **confirmed by GF IT** as the Workday access API. The MVP uses its `Execute SOAP operation` action against the Workday `Human_Resources` web service |
| **Dataverse** | **Process state and audit only** — run, package, field action, exception. Never a copy of Workday master data |
| **HR Employee Control Plane App** (Power Apps code app) | Where HR Operations starts a run, reviews outcomes, works exceptions and follows up on gaps |
| Microsoft 365 Copilot · Teams · Cowork | Where HR Operations is notified, asks questions and picks up follow-ups |
| Personalstammdaten field file | Rule source defining which fields may be copied to Workday |

---

## 5. End-to-End Process

```text
PeopleDoc ──(manual export by HR Ops)──> SharePoint /New Employees
                                                │
                       HR Ops starts a run from the Control Plane App
                                                │
        ╔═══════════════════════════════════════▼════════════════════════════╗
        ║  WORKFLOW — deterministic. Same input, same output.                ║
        ║                                                                    ║
        ║   create run record  →  list documents  →  group into packages     ║
        ║                                   │                                ║
        ║   per package:                    ▼                                ║
        ║     TIER 1  process documents (deterministic extraction)           ║
        ║               │                                                    ║
        ║               ├─ well-formed + confident ─────────────┐            ║
        ║               └─ failed / ambiguous / low confidence  │            ║
        ║                        │                              │            ║
        ║          ┌─────────────▼──────────────┐               │            ║
        ║          │  TIER 2 — AGENT NODE       │               │            ║
        ║          │  read · interpret layout   │               │            ║
        ║          │  extract · state confidence│               │            ║
        ║          │  or refuse                 │               │            ║
        ║          └─────────────┬──────────────┘               │            ║
        ║                        └──────────────┬───────────────┘            ║
        ║                                       ▼                            ║
        ║     match ONE profile          [Access Layer: search_profile]      ║
        ║     read approved fields       [Access Layer: read_fields, batched]║
        ║                                       │                            ║
        ║     per approved field, deterministic branch:                      ║
        ║       WD blank + value  → ADD      [add_missing_value, idempotent] ║
        ║       WD has a value    → SKIP                                     ║
        ║       WD blank + blank  → MISSING (flag, continue)                 ║
        ║       low confidence    → NO WRITE, exception                      ║
        ║       0 or >1 match     → NO WRITE, exception                      ║
        ║                                       │                            ║
        ║     record actions + exceptions in Dataverse                       ║
        ║     move PDFs → /Complete  or  /Exceptions                         ║
        ║                                   │                                ║
        ║   close run  →  notify HR in Teams  →  request information (HITL)  ║
        ╚═══════════════════════════════════════╤════════════════════════════╝
                                                │
                      HR reviews in the Control Plane App
```

| Step | Owner | Process |
|---|---|---|
| 1 | Human | HR downloads the new-employee PDFs from PeopleDoc into SharePoint `/New Employees` |
| 2 | Human | HR Operations starts a run from the HR Employee Control Plane App, typically on receiving the Workday task notification |
| 3 | **Workflow** | Creates the run record, lists the documents, groups them into employee packages |
| 4 | **Workflow** | **Tier 1** — extracts approved fields (column C where column E = yes) from well-formed documents |
| 5 | **Agent node** | **Tier 2** — reads only what Tier 1 could not: unexpected layouts, poor scans, ambiguous values. Returns values with confidence, or refuses |
| 6 | **Workflow** | Searches Workday through the Access Layer and requires **exactly one** match |
| 7 | **Workflow** | Reads the current value of every approved field in **one batched call** |
| 8 | **Workflow** | Per field: adds where Workday is blank and a value exists; skips where populated; flags where both are blank; refuses below the confidence threshold |
| 9 | **Workflow** | Records outcomes, moves the PDFs, closes the run, notifies HR |
| 10 | **Workflow → Human** | Where an exception needs a recorded decision, pauses on the request-information action and resumes with the reviewer's answer |

**Why the split matters.** Exactly one step — 5 — requires judgement. Everything else is process, and process is where the audit evidence lives. Putting the sequence under a reasoning model would make the audit record depend on the model having chosen to write it.

**Tier 1 is also a security control.** Well-formed documents never reach a reasoning model, which narrows the surface on which untrusted document content meets an LLM and reduces credit consumption on a harness billed for building, testing, evaluating and running.

---

## 6. Business Rules

| Rule ID | Condition | Required action |
|---|---|---|
| BR-01 | A PDF is in `/New Employees` | Include it in the processing run |
| BR-02 | Column E is not `yes` | Ignore the field completely |
| BR-03 | Column E is `yes` | Use the field name in column C for the Workday comparison |
| BR-04 | Exactly one Workday profile matches the agreed matching key | Continue to field comparison |
| BR-05 | No Workday profile matches | Do not write; record **Employee Not Found** |
| BR-06 | More than one Workday profile matches | Do not write; record **Multiple Match** |
| BR-07 | Workday already contains a value | Skip; never overwrite; record **Already Exists** |
| BR-08 | Workday is blank and the PDF has an approved value | Add through the Access Layer; record **Added** |
| BR-09 | Workday and PDF are both blank | Record **Missing Value**; raise a flag; continue processing |
| BR-10 | The same file/field transaction was already completed | Do not apply the update again |
| BR-11 | A processing outcome is recorded for the employee package | Move the PDFs to `/Complete` |
| BR-12 | A system or matching error prevents a safe update | Do not write; record the exception for HR review |
| **BR-13** | Extraction confidence for a field is below the agreed threshold | Do not write; record **Low Confidence** for HR review *(new — see D-11)* |
| **BR-14** | A package could not be completed | Move the PDFs to `/Exceptions`, not `/Complete`, so nothing is silently archived |
| **BR-15** | Any write fails part-way through a package | Record each field outcome independently; a partial package is a recorded state, not a failure to retry blindly |
| **BR-16** | Tier 1 extracts a field cleanly and above threshold | Do **not** invoke the agent node for that field — deterministic output is preferred where available *(new — D-17)* |
| **BR-17** | Tier 1 fails, or returns a value below threshold | Route that document to the agent node; record which tier produced every value |
| **BR-18** | The agent node refuses | Treat the refusal as an outcome, not an error: record it, raise the exception, continue the remaining packages |

---

## 7. Functional Requirements

| ID | Capability | Requirement |
|---|---|---|
| FR-01 | SharePoint scan | Read PDF files from `/New Employees` when HR Operations starts a run |
| FR-02 | Document grouping | Group PDFs belonging to the same employee package |
| FR-03 | PDF extraction | Extract designated values from readable PDF documents |
| FR-04 | Approved field filter | Process only column C fields where column E = yes |
| FR-05 | Employee matching | Require exactly one Workday match on the agreed key |
| FR-06 | Read-before-write | Read the existing Workday value before every proposed update |
| FR-07 | Missing-only update | Write only when the approved Workday field is blank and the PDF has a value |
| FR-08 | No overwrite | Never replace an existing Workday value |
| FR-09 | Continue on missing data | Continue processing other fields when one or more values are blank |
| FR-10 | Flags | Flag eligible fields that remain blank |
| FR-11 | Duplicate prevention | Prevent repeated processing of the same PDF and field update |
| FR-12 | File movement | Move processed PDFs to `/Complete`, or `/Exceptions` where not completed |
| FR-13 | Validation reporting | Show profiles processed, values added, values skipped, fields still missing and exceptions |
| FR-14 | Audit record | Record run, employee reference, source files, field actions, Workday outcome, errors and file-move result |
| FR-15 | Safe failure | Do not write when matching, authentication, permissions or connectivity are uncertain |
| **FR-16** | HR control plane | Provide an application where HR Operations starts runs, reviews outcomes and works exceptions |
| **FR-17** | Notification | Notify the responsible HR Operations user in Teams when a run completes or an exception needs attention |
| **FR-18** | Stop control | Provide a control that disables agent writes immediately, without a deployment |
| **FR-19** | Re-run safety | Re-running a package applies no duplicate update and produces a new, linked run record |
| **FR-20** | Extraction traceability | For every extracted value, record the source document and the location within it, so HR can verify without re-reading every PDF |
| **FR-21** | Workflow-owned sequence | The run sequence, branching and file handling execute as a **deterministic workflow**. The agent is invoked for reasoning only and never controls the process |
| **FR-22** | Deterministic audit | Every audit record is written by a workflow step, never left to the agent's discretion. A failed or refused agent call still produces a complete audit entry |
| **FR-23** | Two-tier extraction | Deterministic extraction runs first; the agent node handles only what it could not. Every recorded value identifies the tier that produced it |
| **FR-24** | Workflow human-in-the-loop | Exceptions requiring a recorded decision pause the run on a request-information action and resume with the named reviewer's response |

---

## 8. Non-Functional Requirements

| ID | Requirement |
|---|---|
| NFR-01 | **Least privilege.** The agent identity holds only the SharePoint and Workday permissions its workflow requires |
| NFR-02 | **No personal data in prompts, logs or repositories.** PDF content is processed, not copied into unrestricted locations |
| NFR-03 | **Untrusted input.** PDF content is treated as untrusted; extracted values are validated before any write |
| NFR-04 | **Auditability.** Every write, skip, missing value and error is reconstructable from the audit record |
| NFR-05 | **Retention.** Input PDFs, completed PDFs, process records and audit entries are retained only for the approved period |
| NFR-06 | **Environment separation.** Development, test and production are separate; non-production uses synthetic or approved test data |
| NFR-07 | **Reversibility.** Because the agent only fills blanks, any single incorrect addition can be corrected in Workday without data loss |
| **NFR-08** | **Determinism.** Given identical inputs, the workflow produces an identical sequence of steps and audit records. Only Tier 2 extraction may vary |
| **NFR-09** | **Capacity.** Exhausted prepaid Copilot Studio capacity **blocks new runs** while in-flight runs complete — a silent failure for a date-bound process. PROD runs with pay-as-you-go enabled and a consumption alert |
| **NFR-10** | **Throughput.** A run stays within 200 Workday calls per connection per 60 seconds at the agreed batch size. `read_fields` is batched, never iterated per field |

---

## 9. Human in the Loop

The agent is **propose-and-apply within a narrow, pre-approved envelope** — it applies only additions to blank approved fields. Everything outside that envelope stops and waits for a person.

**The waiting is a workflow state, not a prompt instruction.** Escalation uses the workflow's request-information action: the run pauses, a named reviewer is asked, and execution resumes with their answer. An agent cannot decline to escalate, because escalating is not something the agent does.

| Decision | Agent | Human | Owner |
|---|---|---|---|
| Which fields may be written | No | Yes — approved field list | HR Operations + HRIS |
| Whether a document belongs to an employee package | Proposes | Confirms on exception | HR Operations |
| Whether a profile match is correct | Proposes; refuses on 0 or >1 | Resolves exceptions | HR Operations |
| Whether to add a value to a blank field | **Applies** within the envelope | Reviews after the fact | HR Operations |
| Whether to overwrite an existing value | **Never** | Always | HR Operations |
| Whether to create a worker record | **Never** | Always | HR Operations / HRIS |
| Whether a low-confidence extraction is correct | Proposes | Decides | HR Operations |
| Whether to stop the agent | No | Yes | HR Operations / DAAI |

> **The agent has no employment-decision surface.** It completes reference data on an existing profile. It does not assess, rank, score or recommend anything about a person.

---

## 10. Reporting and Audit

### 10.1 HR Employee Control Plane App

The operational surface for HR Operations:

- Run list with status, counts and duration.
- Per-package view: source documents, matched profile reference, every field action.
- Exception queue: no match, multiple match, low confidence, extraction failure, write failure, move failure.
- Follow-up list: eligible fields still blank, with owner and status.
- Start-a-run and stop-writes controls.

### 10.2 Workday validation reporting

Workday remains the place to validate **master-data completeness**, because Workday is the system of record. The control plane app reports on **what the agent did**; Workday reports on **what the data now looks like**. Keeping the two apart avoids a second, competing version of employee data.

> **Open:** report layout, owner, recipients and follow-up process — D-08.

### 10.3 Audit record

Per field action: run ID and timestamp, source document reference and location, matched profile reference, field name, action (`Added` · `Already Exists` · `Missing` · `Low Confidence` · `No Match` · `Multiple Match` · `Error`), access-layer transaction result and idempotency key, file-move result, and the acting identity.

---

## 11. Success Measures and Acceptance Criteria

| ID | Acceptance criterion |
|---|---|
| AC-01 | The agent processes PDFs from `/New Employees` when HR starts a run |
| AC-02 | Only fields approved by column C / column E = yes are considered |
| AC-03 | No Workday update occurs without exactly one employee match |
| AC-04 | Existing Workday values are never overwritten |
| AC-05 | Missing PDF values do not stop other eligible fields from being processed |
| AC-06 | Every write, skip, missing value and error is auditable |
| AC-07 | The same PDF/field update is not applied twice |
| AC-08 | Processed PDFs move to `/Complete` only after an outcome is recorded |
| AC-09 | HR can see, in one place, what was added and what remains missing |
| AC-10 | The agent can be stopped and does not write during unsafe system or identity conditions |
| **AC-11** | Every added value can be traced to its source document and location |
| **AC-12** | A re-run of a completed package produces no duplicate write |
| **AC-13** | A package that fails part-way leaves each field in a recorded state, and its documents in `/Exceptions` |

### Business measures

| Measure | Baseline | Target |
|---|---|---|
| Manual Workday data-entry effort per new joiner | *To be established — BIZ-03* | Reduce materially; quantify after pilot |
| Approved fields completed without manual entry | 0% | *Set after the first ten packages* |
| Unsafe writes (overwrite, wrong profile, duplicate) | n/a | **Zero — absolute** |
| Packages requiring manual exception handling | n/a | Track; reduce over the pilot |

---

## 12. Roles and Accountability

| Role | Accountability |
|---|---|
| DAAI / HR AI Business Lead | Product direction, requirements, priority, business outcome |
| Switzerland HR Operations | Process, approved fields, document handling, follow-up, operational acceptance |
| Workday / HRIS Owner | Workday field definitions, Integration System User design and permissions, report design, access-layer action approval |
| Security / Privacy | Controls, access, data handling, reporting, retention |
| IT / Platform Owners | Technical environment, identity, operations, support |

Full RACI: [`hr-journey-and-raci.md`](../../../../docs/hr-journey-and-raci.md) §5.

---

## 13. Open Decisions

Carried forward from Draft 0.1, plus those raised by this revision.

| ID | Decision | Owner | Blocks |
|---|---|---|---|
| D-01 | Run cadence: HR-initiated only, or scheduled as well | Kristina / HR Ops | FR-01 |
| D-02 | PDF naming or grouping rule identifying one employee package | HR Operations | FR-02 |
| D-03 | **Matching key.** Last Name + First Name + Postal Code is weak — postal code changes, and names repeat. Can Candidate ID or Pre-Hire ID be carried in the document set? | HRIS / HR Ops | **FR-05 — highest risk item** |
| D-04 | Final approved field list, including entries marked TBC | HR Ops / HRIS | FR-04 |
| D-05 | PDF extraction method | DAAI / IT | FR-03 |
| D-06 | Workday Access Layer actions, Integration System User permissions, and a non-production Workday tenant with its own connection | HRIS / IT | FR-05–08 |
| D-14 | How the Access Layer is surfaced to Copilot Studio — MCP tools, custom connector, or Power Automate child flows | DAAI / IT | FR-05–08 |
| D-15 | Idempotency key design for `add_missing_value`; the Workday connector supplies none, so a retried write is a second write unless the Access Layer prevents it | DAAI / HRIS | FR-08 |
| D-16 | Maximum batch size per run, given the connector's limit of 200 calls per connection per 60 seconds | DAAI / HR Ops | NFR-10 |
| D-17 | **Two-tier extraction threshold** — the confidence level that routes a document from Tier 1 to the agent node, validated against a common sample set | DAAI / HR Ops | FR-23, BR-16 |
| D-18 | PROD capacity headroom, the consumption alert threshold, and whether pay-as-you-go is enabled from day one | IT / DAAI | NFR-09 |
| D-07 | Definition of *processed*, and treatment of failed documents | HR Ops | FR-12, BR-14 |
| D-08 | Workday validation report layout, owner, recipients, follow-up | HR Ops / Workday | FR-13 |
| D-09 | Audit retention period and access | Privacy / Records | NFR-05 |
| D-10 | Support and incident ownership for failed runs or incorrect extraction | DAAI / IT / HR Ops | OPS |
| **D-11** | Extraction confidence threshold below which a field is not written | DAAI / HR Ops | BR-13 |
| **D-12** | Whether HR Ops can approve a low-confidence value in the control plane app, or must enter it in Workday directly | HR Ops / HRIS | FR-16 |
| **D-13** | Whether the Switzerland MVP will extend to other countries, and what would change | DAAI / HR Ops | Roadmap |

> **Definition of Ready.** The build starts when field rules, sample PDFs, the matching key, Workday target fields, **Integration System User permissions**, **the Access Layer action contract**, report design, audit requirements, folder access and test cases are approved by the accountable GF owners.

---

## 14. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| **Weak matching key produces a wrong-profile write** | High — personal data on the wrong worker | Exactly-one-match rule; refuse on ambiguity; resolve D-03 before build |
| Extraction error writes an incorrect value | Medium — a blank field gets wrong data | Confidence threshold (BR-13); source traceability (FR-20); HR review |
| PDF layout variation breaks extraction | Medium — throughput drops | Representative sample set (DAT-01); exception path rather than failure |
| Scope creep toward overwriting or correcting data | High — changes the risk profile entirely | No-overwrite is a hard rule, not a setting |
| Dataverse drifts into holding master data | High — a second source of truth | [ADR-0007](../../../../docs/adr/0007-dataverse-process-state-boundary.md); process state only |
| PeopleDoc export stays manual | Low for MVP | Accepted; automation is a later increment |
| Agent credentials over-permissioned | High | Least privilege; separate identities per environment |

---

## 15. What This Is Not

Stating these plainly, because the agent's narrowness is the reason it is safe to run against the system of record.

- Not a Workday replacement, and not a route around Workday's own validation.
- Not a data-correction tool. It fills blanks; it does not fix what is there.
- Not a decision-maker. No assessment, ranking, scoring or recommendation about a person.
- Not a general document-processing platform. One document source, one country, one approved field list.
- Not an employee-facing experience. The users are HR Operations.
