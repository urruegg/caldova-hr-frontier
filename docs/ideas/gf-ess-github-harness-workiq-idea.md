# GF ESS-Equivalent Employee Self-Service Rebuild - Idea

| Field | Value |
|---|---|
| **Version** | 0.1 |
| **Date** | 2026-10-28 |
| **Author** | Copilot |
| **Status** | Draft |
| **Scope** | GF functional handover package: employee self-service with GitHub harness, Work IQ and governed Workday access |
| **References** | [Sprint](../plans/2026-10-28-gf-ess-github-harness-workiq-sprint.md), [Specification](../specs/2026-10-28-gf-ess-github-harness-workiq-design.md), [Implementation plan](../plans/2026-10-28-gf-ess-github-harness-workiq-implementation.md), [Proposed ADR-0014](../adr/0014-gf-ess-workiq-and-self-service-write-envelope.md), [Package index](../README.md#gf-draft-packages) |

## Status and provenance

This is the sixth GF draft handover package, separate from the existing policy-only, Recruiting, HR Operations and two technical packages. It does not replace them, graduate Caldova UC-0003, or grant implementation authority.

The scope was refined interactively with the repository owner on 2026-10-28. Microsoft's public ESS Custom Engine Agent documentation and the Employee Self-Service Agent Developer Kit were analyzed as references; exact sources and pinned revisions are recorded in the specification. There is no existing GF ESS source/export baseline to migrate. This is a new ESS-equivalent proposal, not an installed Microsoft ESS product or demonstrated feature parity.

## Problem and expected value

Employees need a clear route from an HR question to a safe, completed self-service request without navigating disconnected policy, Workday and support experiences. The working value hypothesis is fewer manual steps, less repeated data entry and better visibility of request outcomes while retaining human and Workday approval authority.

GF's business owners still need to establish manual baselines, pilot volumes, capacity and benefit thresholds. No time saving, adoption rate, cost reduction or delivery date is claimed.

## Confirmed idea

| Canvas element | Draft starting point for GF review |
|---|---|
| Users | Signed-in employees in Switzerland for the initial scope; exact pilot group and named acceptance owner remain open |
| Goal | Grounded policy guidance and explicitly confirmed self-service transactions with verified backend outcomes |
| Trigger and inputs | Employee asks a question or requests an action; approved regional policies, employee-provided task inputs and necessary live own-Workday data |
| Reasoning | Clarify missing details, explain policy, prepare drafts and interpret bounded results; never authorize the action itself |
| Deterministic responsibilities | Workflow validates identity, scope, confirmation, current state, execution, replay protection, audit and reconciliation |
| Platform | New Copilot Studio agent on the GitHub Copilot runtime harness; reusable skills and supported workflows, not copied classic topic/card assumptions |
| Workday access | Governed Access Layer with the employee's own delegated OAuth connection; no raw connector or arbitrary employee target on the reasoning agent |
| Work IQ role | Per-use-case M365 reads, drafts and separately confirmed actions for Outlook, Teams and documents; not an assumed Workday connector gateway |
| Human responsibility | Employee reviews/confirms; HRIS owns operation contracts; HR/business owners retain policy, exception and employment decisions |
| Outputs | Cited guidance, reviewed changes, verified transaction/request/case references and status, or explicit blocked/uncertain outcomes |
| Delivery boundary | DEV build and TEST validation; production and live activation are outside the current sprint |

Later regions require their own source, permissions, policy applicability, language, owner, escalation and evaluation review. This proposal does not activate another region automatically.

## Selected transaction scope

Each operation is independently gated; inclusion below is not proof of API support or live authorization.

| Operation | Essential boundary |
|---|---|
| Personal phone number | Change only the selected personal-phone fields after exact review/confirmation; preserve unrelated contacts |
| Personal email address | Change the selected personal email, not the work account or identity |
| Home address | Update only the selected home address under an HRIS-proven field/effective-date contract |
| Emergency contact | Apply the reviewed change to the selected contact; protect related-person information and preserve other entries |
| Time-off request | Submit through Workday's existing approval process; the agent never decides entitlement or approves leave |
| Workday Help case | Create only after employee review and confirmation; return a verified case reference/status, not merely a support link or email |

Requested Word outputs and M365 communications must remain minimal and separately authorized. Inbox/chat content cannot authorize a Workday write or supply guessed personal details. Case attachments, automatic transcripts, broad inbox searches, payroll/bank, identity documents, manager/other-person actions and employment decisions are not implicitly included.

## Readiness and stakeholder questions

| Review area | Required GF disposition |
|---|---|
| Business ownership | Confirm accountable sponsor/process owner, pilot audience, scenario priority, capacity and measurable value criteria |
| Privacy/Security | Supply the scope/reference of the user-reported approval; confirm resources/actions, identities, environments, transient state, transcripts and retention |
| Workday/HRIS | Prove delegated self-identity and each operation's exact API, permissions, field validation, confirmation and outcome/reconciliation contract |
| Workday Help | Establish create/status/routing support and duplicate prevention; the researched ESS reference does not supply a proven ready-made case action |
| M365/platform | Prove enforceable resource/action restrictions, supported confirmation/document experience, and GitHub-harness source/export/import completeness |
| Operations | Name support/incident/acceptance roles and agree stop, in-flight reconciliation and TEST evidence |

Named individuals, tenant endpoints and unresolved permissions are not invented. The proposed ADR records the new scoped Work IQ and employee-self envelope; it does not weaken HR Operations' add-only protections or the policy-only assistant's read boundary.

## Handover reading order and next checkpoint

Read this idea for the outcome and scope, then the [sprint](../plans/2026-10-28-gf-ess-github-harness-workiq-sprint.md) for candidate work and acceptance, and the [specification](../specs/2026-10-28-gf-ess-github-harness-workiq-design.md) for detailed contracts, capability gaps and Mermaid diagrams. The [implementation plan](../plans/2026-10-28-gf-ess-github-harness-workiq-implementation.md) and [ADR-0014](../adr/0014-gf-ess-workiq-and-self-service-write-envelope.md) are supporting artifacts, not extra primary package documents.

The first GF review should confirm owners and priorities, then resolve approval scope and operation-specific capability gaps one question at a time. Record each capability as demonstrated, blocked or deliberately deferred; do not treat a good conversational answer as a completed transaction.

The handover documents are prepared locally for review. No repository transfer, publication, implementation, live test, commit or push is performed by creating this package.

## Board synchronization

Deferred - not synchronized.
