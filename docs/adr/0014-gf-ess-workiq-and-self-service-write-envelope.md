# ADR-0014: GF ESS-Equivalent Work IQ Scope and Employee Self-Service Write Envelope

| Field | Value |
|---|---|
| **Version** | 0.1 |
| **Date** | 2026-10-28 |
| **Author** | Copilot |
| **Status** | Proposed Baseline |
| **Scope** | GF new ESS-equivalent only: scoped Work IQ use and self-only delegated Workday actions |
| **References** | [Specification](../specs/2026-10-28-gf-ess-github-harness-workiq-design.md), [Sprint](../plans/2026-10-28-gf-ess-github-harness-workiq-sprint.md), [HR agent governance](../../AGENTS.md), [ADR-0008](0008-human-in-the-loop-and-write-envelope.md), [ADR-0009](0009-workday-access-via-connector-behind-governed-layer.md), [ADR-0011](0011-workflow-first-process-architecture.md), [ADR-0013](0013-gf-azure-repos-source-authority.md) |

## Context and decision status

Existing governance deliberately disables Work IQ for HR agents pending Privacy approval, and the HR Operations master-data path is add-only. The user now requests a **new** ESS-equivalent on Copilot Studio's GitHub Copilot runtime harness, with selected employee updates, Workday Help cases and use-case-specific M365 capabilities.

The user reports that Privacy/Security approval exists, but its decision reference and exact scope have not been supplied. The user approved drafting this architecture, not enabling tools or ratifying every operational permission. This ADR records a proposed scoped exception and new envelope; it does not silently rewrite existing governance.

No deployed ESS source is being migrated. Microsoft ESS and the pinned Developer Kit are capability/design references; their starter topics, UI and diagnostics are not proof that the new runtime or OAuth integrations work.

## Proposed decision

1. Build a new, restricted ESS-equivalent with GitHub-harness reasoning and deterministic workflows. Keep the existing five GF packages unchanged.
2. Permit Work IQ only under a reviewed **per-use-case** contract covering purpose, reads, draft outputs, mutations, resource/destination limits, confirmation, data handling and tests. Do not interpret workload selection or general consent as an unlimited HR data surface.
3. Keep Workday on a **separate governed Access Layer**, using the signed-in employee's own delegated OAuth authorization. No agent holds the raw connector, SOAP body, arbitrary HTTP path or selectable employee target.
4. Define six independently gated employee-self capabilities: personal phone, personal email, home address, emergency contact, time-off submission through Workday's approval, and Workday Help case creation after review/confirmation.
5. Enforce actor/content/operation-bound trusted confirmation, field/action allow-lists, current-state validation, replay protection, status reconciliation and deterministic audit outside model instructions.
6. Expose no generic M365 mutation surface that can bypass the declared workflow envelope. Prove native controls or separately design mediation; keep the affected action blocked when enforceability is uncertain.
7. Maintain Workday as master-data authority, minimize short-lived execution state, prohibit master-value copies in process/audit tables and Git, and review transcripts, case data, emergency-contact privacy and Word/M365 outputs before operational use.
8. Retain memory-off for write-capable reasoning and the connected-agent block. No employment decision, manager/other-person action, profile creation, identity-document or payroll/bank capability is admitted.
9. Keep direct/unified Work IQ-to-Workday exposure as optional research. No documented path or endpoint is assumed. The kit's ISU/WS-Security/Basic developer MCP is not the chosen delegated OAuth runtime.
10. Build/verify in DEV and TEST through GF's reviewed source/delivery model. Production and live activation require separate decisions and operation-specific evidence.

## Scoped supersession and unchanged invariants

If ratified, this record supersedes the Work IQ-off rule **only for this GF ESS-equivalent and its approved use-case envelopes**. It specializes ADR-0008's envelope mechanism for selected employee updates and case/request creation; the original HR Operations add-only and never-overwrite rules remain binding in that use case.

It specializes ADR-0009's three-action/service-identity implementation for this new self-service path: separately reviewed self-only operation contracts and employee-delegated OAuth replace that path's assumed service identity. It preserves ADR-0009's core boundary that the Access Layer, never the agent, owns the connector. It preserves ADR-0011's workflow-owned process/audit and all human employment-decision authority.

It does not supersede demo GitHub source authority, existing GF policy-only read restrictions, Recruiting's unresolved action boundary, or the HR Operations blocked-write gate. No global instruction file is changed by this proposal.

## Options considered

| Option | Disposition and trade-off |
|---|---|
| Separate governed Work IQ/M365 and Workday OAuth paths | Selected design direction by the user. Clear enforcement/identity boundaries, but requires contract and identity/ALM proof. |
| Work IQ as a single gateway to all Workday operations | Optional feasibility research only. Retrieved Business Apps documentation does not establish the needed connector route; a guessed endpoint is unacceptable. |
| Give the agent raw Workday/M365 tools and rely on confirmations in instructions | Rejected: generic tools could bypass the envelope after prompt injection or unauthorized target/content changes. |
| Copy native ESS/Developer Kit components as a complete GitHub-harness runtime | Rejected as an assumption: classic/declarative authoring references, native ESS UX, sample MCP and runtime harness are distinct surfaces. |

## Consequences

The new use case can assess employee value through real, narrowly authorized transactions while preserving existing packages. It carries a materially broader personal-data and operational risk than policy Q&A, and address/contact/Help extensions may remain blocked until HRIS API support is demonstrated.

Work IQ's documented first policy surface is tenant-scoped, not a guarantee of agent-specific controls. Effective whole-workload access and mutation policies require negative tests. The build may need additional controlled mediation; no timeline or deployment success is promised.

An application-version rollback does not undo Workday submissions or M365 side effects. Stop new mutations and reconcile pending operations; any reversal is a separately authorized business operation.

## Compliance and activation gates

Before live enablement, require the formal Privacy/Security scope/reference, named business/HRIS/IT owners, approved six-operation contracts, supported employee OAuth propagation, trusted confirmation/state handling, effective M365 resource/action restrictions, minimized data/retention design, signed-off tests and chosen-harness TEST deployment evidence.

Require zero cross-user/unauthorized writes, no duplicate mutation after ambiguous results, and verified request/case outcomes. Pending leave is never agent-approved leave; a Help Center link or email is never reported as a created Workday case.

No tenant settings, credentials, connector permissions, case endpoints or runtime features are created by this Proposed Baseline record.
