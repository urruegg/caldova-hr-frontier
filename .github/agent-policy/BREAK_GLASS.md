# Break-Glass Procedure

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-17 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Repository |
| **References** | [Approved Architecture Baseline Intake Design](../../docs/specs/2026-09-17-architecture-baseline-intake-design.md), [Delegated Agent Workflow](./AGENT_WORKFLOW.md), [Non-Delegable Work](./NON_DELEGABLE_WORK.md) |

This proposed procedure applies only after its controls are implemented and an authorized repository owner explicitly approves the exact bypass. An agent may prepare the record and attended steps, but it must not approve, initiate, widen, or execute a bypass automatically.

## Allowed Use

Full administrator bypass is allowed only when the protected pull-request path cannot restore service or repository safety in time.

## Required Record

Record the incident or work item, reason, approver, exact bypass scope, start and end time, affected refs or settings, commands or API calls, validation output, and corrective pull request.

The record must exist and name the authorized repository-owner approver before protection changes. Never include personal data, secrets, credentials, or private tenant values in the record.

## Procedure

1. Obtain explicit repository-owner approval and record it before changing protection.
2. Capture the current ruleset and target ref.
3. Apply the narrowest temporary bypass.
4. Make only the approved change.
5. Restore protection immediately.
6. Run the repository validator and affected checks.
7. Open the corrective or audit pull request and link the record.

Every step is attended and evidence-based. Stop if current protection cannot be captured, the approver or scope is unclear, the change would be destructive, restoration cannot be verified, or a required validation fails. Do not continue automatically after a stop.

## Prohibitions

Never use break-glass to avoid review convenience, bypass a failed validator, overwrite unrelated work, force-push unreviewed history, or conceal a control failure.

Break-glass does not authorize deletion, data loss, secret or identity changes, employment decisions, unreviewed history, unrelated administrative action, skipped validation, or any action outside the explicit recorded approval.
