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

## Normal Governance Bypass

The ruleset's `User` bypass for `urruegg` with `bypass_mode: pull_request` is a normal governance path, not break-glass. It permits repository-owner completion through a pull request when independent approval is unavailable. It never permits a direct push to `main`.

An `always` or `exempt` bypass, or any other direct-push path, remains forbidden unless a separate incident record contains the exact scope and explicit attended emergency approval before the change. No agent approves or activates either the normal ruleset or an emergency bypass.

## Governance Activation Gate

Ruleset activation requires both reviewed GitHub Actions runs to be completed successfully on `main`: `.github/workflows/validate-repository.yml` (`Validate repository`) and `.github/workflows/bootstrap-tenant.yml` (`Validate tenant bootstrap`). It also requires current normalized cleanup evidence for the same bootstrap run proving that the exact Contributor and Role Based Access Control Administrator assignments are absent.

A successful workflow conclusion alone is insufficient cleanup evidence. An agent may validate inputs and prepare an exact `-WhatIf` proposal, but only an attended repository owner may approve and activate the mutation.

## Allowed Use

Full administrator bypass is allowed only when the protected pull-request path cannot restore service or repository safety in time.

## Required Record

Record the incident or work item, reason, approver, exact bypass scope, start and end time, affected refs or settings, commands or API calls, validation output, and corrective pull request.

The record must exist and name the authorized repository-owner approver before protection changes. Never include personal data, secrets, credentials, or private tenant values in the record.

## Procedure

1. Obtain separate explicit attended repository-owner emergency approval and record it before changing protection.
2. Capture the current ruleset and target ref.
3. Apply the narrowest temporary bypass exactly as recorded; do not broaden it during execution.
4. Make only the approved change.
5. Restore protection immediately.
6. Run the repository validator and affected checks.
7. Open the corrective or audit pull request and link the record.

Every step is attended and evidence-based. Stop if current protection cannot be captured, the approver or scope is unclear, the change would be destructive, restoration cannot be verified, or a required validation fails. Do not continue automatically after a stop.

## Prohibitions

Never use break-glass to avoid review convenience, bypass a failed validator, overwrite unrelated work, force-push unreviewed history, or conceal a control failure.

Without a separately recorded exact attended emergency approval, never configure `always`, `exempt`, or direct-push bypass. The normal `User`/`pull_request` bypass does not provide that approval.

Break-glass does not authorize deletion, data loss, secret or identity changes, employment decisions, unreviewed history, unrelated administrative action, skipped validation, or any action outside the explicit recorded approval. No agent may approve, activate, or extend break-glass access.
