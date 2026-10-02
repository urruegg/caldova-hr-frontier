# UC-0001 — Personal Master Data Completion Agent

| Field | Value |
|---|---|
| **Version** | 1.1 |
| **Date** | 2026-10-01 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Graduated |
| **Scope** | HR Use Case Portfolio |
| **References** | [HR use-case detail](../../hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/README.md), [HR Solution Functional Design Intake](../specs/2026-09-24-hr-solution-functional-design-intake-design.md), [Implementation Plan](../plans/2026-09-24-hr-solution-functional-design-intake-implementation.md) |

> **Status:** **Selected as MVP** — the only use case in this portfolio that has advanced past idea
> **Journey stage:** Pre-board
> **HR process area:** HR Operations Switzerland
> **HR owner:** Switzerland HR Operations
> **Suggested wave:** **1 — in flight**
>
> **Source:** The customer-supplied UC-0001 draft PRD and UC-0001 artefact inventory. Unlike every other document in this folder, this one describes **approved, in-flight work** — its requirements live in the [HR use-case detail package](../../hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/README.md).

---

## 1. The Idea

New joiners in Switzerland arrive with personal master data spread across PDF documents. HR Operations exports those documents from PeopleDoc into a SharePoint folder and re-keys the values into Workday by hand. The agent reads the documents, matches exactly one Workday candidate or pre-hire profile, and **adds missing approved values only** — never overwriting anything that already has a value.

| | |
|---|---|
| **Business objective** | Eliminate manual re-keying of personal master data at pre-boarding |
| **Business value** | High — it removes work at the point where data quality is set for the whole employment lifecycle |
| **Expected outcome (KPI)** | Reduced manual entry effort; improved completeness of approved fields at hire |
| **Complexity** | Medium |
| **Priority** | **Selected — MVP** |
| **Change timeframe** | MVP scope, Switzerland only |
| **Tool** | Microsoft Copilot Studio + Workday |
| **Data source** | PeopleDoc PDFs via SharePoint; Workday Core HCM |
| **Key personas** | HR Operations CH; Workday Solutions / HRIS; Security & Privacy |
| **Risk type** | **High** — it writes to the system of record for employee data |

**Key results:** proportion of approved fields completed without human entry · exception rate by type · time from document arrival to a complete profile

**Risks:** an unreliable matching key (the dominant one) · extraction confidence on varied document layouts · prompt injection through externally supplied PDFs · remediation load if the exception rate is high

---

## 2. Where It Sits

**Journey stage:** Pre-board — between offer acceptance and day one.

This is the earliest point at which employee master data enters Workday, which is why it was chosen. Data quality established here propagates through every downstream stage and every downstream system; data quality *not* established here is corrected repeatedly, by hand, for the length of the employment.

See [`hr-journey-and-raci.md`](../hr-journey-and-raci.md) for the full journey and the placement of every use case.

---

## 3. Platform Fit

**Harness:** **GitHub Copilot harness** — multi-step reasoning across documents and a governed integration. The choice **cannot be changed after the agent is created**, and credits are consumed from the moment building starts, so the budget is confirmed before build (TD-01).

**Write envelope:** **Narrow and additive.** Approved fields only, on a blank field only, on exactly one matched profile. Enforced in three independent places — agent rules, the Workday Access Layer, and the Workday Integration System User's permissions. See [ADR-0008](../adr/0008-human-in-the-loop-and-write-envelope.md) and [ADR-0009](../adr/0009-workday-access-via-connector-behind-governed-layer.md).

**Grounding:** The approved field list (the customer-supplied personal-master-data field workbook, column C where column E = yes), versioned in Dataverse as `caldova_approvedfield`. Workday read live through the Access Layer — never a cached copy.

**Data classification:** **Personal.** Home address, date of birth, and comparable fields. Privacy sign-off is a gate, not a review.

**Employment-decision surface:** **None.** It completes data. It decides nothing about a person, and it must not be extended to.

### What it refuses

- Overwriting a field that already has a value — always, without exception
- Writing when the match is zero profiles or more than one
- Writing when extraction confidence is below the agreed threshold
- Creating a worker record, or writing any field outside the approved list
- Continuing silently past anything it could not do — every skip is recorded and surfaced

---

## 4. Assessment

**Why this one was selected first.** It sits where the manual effort is highest and the data-quality consequence is longest-lived, and — critically — its write is *reversible in effect*. An agent that only fills blanks cannot destroy information. That property is what makes writing to the system of record acceptable for a first use case, and it is the reason this was chosen over larger-value candidates.

**The dominant risk is the matching key.** The customer-supplied UC-0001 draft PRD proposes Last Name + First Name + Postal Code and marks it TBD. Names repeat and postal codes change, so a false match writes one person's data onto another's record — the single worst outcome this agent can produce. Carrying a Candidate or Pre-Hire ID through the PeopleDoc export would remove the risk rather than mitigate it. This is D-03 and it is the most valuable thing to settle before build.

**The documents are untrusted input.** They originate outside the platform, so a PDF containing instruction-shaped text must have no effect on agent behaviour. The design treats document content as data only, and the enforcement that matters sits below the agent where prompt text cannot reach it.

**The exception queue is the real deliverable.** An agent that writes 70% of fields and leaves 30% in a well-formed, owned, actionable queue is a success. One that writes 95% and leaves the rest invisible is not. The HR Employee Control Plane App exists for that queue.

---

## 5. Status — Beyond Idea

This use case has passed the gate the rest of this folder has not. Its artefacts:

| Artefact | Where |
|---|---|
| **Product requirements** | [`prd-0001-personal-master-data-completion-agent.md`](../../hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/prd-0001-personal-master-data-completion-agent.md) — Draft 0.2, superseding the customer-supplied UC-0001 draft PRD |
| **Platform requirements it inherits** | [`prd.md`](../prd.md) — FR-0001…FR-0012, NFR-0001…NFR-0010 |
| **Architecture** | [`solution-design.md`](../solution-design.md) |
| **Decisions** | [ADR-0005](../adr/0005-workday-as-system-of-record.md) · [ADR-0007](../adr/0007-dataverse-process-state-boundary.md) · [ADR-0008](../adr/0008-human-in-the-loop-and-write-envelope.md) · [ADR-0009](../adr/0009-workday-access-via-connector-behind-governed-layer.md) |
| **Artefact inventory** | The customer-supplied UC-0001 artefact inventory — 60+ items across business, data, system, security, build, test and operations |

The seven platform declarations are answered in the PRD rather than left open here. The remaining gates are in [`prd-0001-personal-master-data-completion-agent.md`](../../hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/prd-0001-personal-master-data-completion-agent.md) §13 as the Definition of Ready.

---

## 6. Open Questions

These are the ones that block build. The full list is PRD §13.

| # | Question | Owner |
|---|---|---|
| 1 | **What is the matching key?** Name + postal code is not sufficient — can a Candidate or Pre-Hire ID be carried in the document set? (D-03) | HR Ops CH / HRIS |
| 2 | Which fields are approved, and is the list final? (D-01) | HR Ops CH |
| 3 | What extraction confidence threshold separates a write from an exception? (D-11) | DAAI / HR Ops |
| 4 | Can Workday scope a write permission to the approved field set alone? (TD-09) | HRIS / Security |
| 5 | Is a Workday non-production tenant available, with its own Integration System User? (D-06) | HRIS / IT |
| 6 | Who owns the exception queue operationally, and what is their capacity? | HR Ops CH |
