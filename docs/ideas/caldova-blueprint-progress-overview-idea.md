# Caldova Blueprint and Project Progress Overview - Idea

| Field | Value |
|---|---|
| **Version** | 0.2 |
| **Date** | 2026-10-29 |
| **Author** | Copilot |
| **Status** | Draft |
| **Scope** | Caldova project/demo; GF source/customer context: project handover: evidence-backed blueprint maintenance and repository-working Copilot agent |
| **References** | [Sprint](../plans/2026-10-29-caldova-blueprint-progress-overview-sprint.md), [Specification](../specs/2026-10-29-caldova-blueprint-progress-overview-design.md), [Provisional implementation plan](../plans/2026-10-29-caldova-blueprint-progress-overview-implementation.md), [Package index](../README.md#caldova-draft-packages), [Repository-agent governance](../specs/2026-10-02-hr-frontier-copilot-agent-portfolio-governance-design.md) |

## Caldova project and GF source boundary

This is a Caldova project/demo document using the explicitly identified GF source/customer scenario. GF facts, approvals, requirements and trademarks remain GF-scoped; project renaming does not establish Caldova corporate policy or runtime acceptance. See the [source and authority boundary](../README.md#caldova-project-and-gf-source-boundary). Existing stable IDs are retained for traceability, not reassigned.

## Status and source

The user supplied [Georg Fischer Frontier Company Blueprint.html](../Georg%20Fischer%20Frontier%20Company%20Blueprint.html) and requested a current project overview and a dedicated repository-working GitHub Copilot agent. The HTML is a local imported baseline, not evidence that its proposed capabilities are implemented or that a customer handover has occurred.

The inspected file describes a hypothesis blueprint, version 0.5 dated 2026-10-28, with three workshop MVP PRDs. It embeds structured `frontier-blueprint/1.0` data, its renderer, assets and attribution. Browser workshop notes are stored locally until exported; they are not a shared delivery record.

This overview-enablement set is one of the eight Caldova project packages. It
does not redefine the original GF workshop MVPs or replace the other work
packages, including identity adoption.

## Problem and expected value

Project scope, sprint plans, decisions and verified results can change while the blueprint remains an older snapshot. Manually interpreting a large HTML file makes it easy to confuse drafted work with completed work, or to hand over an attractive but stale overview.

The proposed value is a reviewable view of what is planned, progressing, blocked, implemented, verified and accepted, with evidence and next steps. Baselines for update effort, drift and stakeholder confidence have not been established; no saving or delivery date is claimed.

## Confirmed idea

| Canvas element | Draft starting point |
|---|---|
| Users | GF business/technical project owners, reviewers and handover recipients; named accountability remains to be confirmed |
| Primary source | Repository sprint/delivery records and implementation/test/acceptance evidence; Azure Boards comes later |
| Overview | Derived progress and freshness for the existing work packages, separately from document status and workshop hypothesis validation |
| Narrative | Update only when supported by reviewed decisions, with explicit provenance and human review; do not silently rewrite customer facts |
| Agent | Workspace-scoped Blueprint Maintainer, initially a manually invoked read/search-only preview |
| Deterministic work | Future validation, controlled HTML updates, source fingerprints, stale-output checks and handover manifest |
| Human responsibility | Approve scope, narrative changes, completion/acceptance and publication; the agent cannot approve its own conclusions |
| Delivery mode | Update records and generated overview in the same reviewed change; use the existing validation surface rather than an assumed continuous runner |

The selected rendering approach adds controlled data/rendering sections to the existing HTML. Preserve unrelated content, stable IDs, embedded assets and attribution. Do not recover a missing original plugin by inventing its behavior or rebuilding the entire blueprint.

## Boundaries and readiness

The future writer must distinguish document lifecycle, delivery, environment verification, human acceptance and source freshness. File existence, sprint checkboxes, successful documentation tests or a browser label are not sufficient evidence of a deployed HR capability. No invented aggregate completion percentage is needed.

The existing approved repository-agent design fixes a twelve-role portfolio and limits the Docs Agent to Markdown. The new profile is a scoped, gated preview, not silent activation of a thirteenth operational role. Write/execute capabilities remain blocked until the companion governance decision, implementation and enforcement tests are approved.

The supplied HTML remains unchanged during planning. Its customer-audience label and source visibility labels do not establish public publication permission. Browser feedback, private source material and any personally identifying content require an explicit review before inclusion in a handover.

## Handover and next review

Read this idea, the sprint and specification as the primary set. The implementation plan is a supporting provisional Draft, with written-specification review still pending. The blueprint is the referenced local overview, not a fourth status authority.

Confirm the accountable updater/reviewer, progress evidence rules, narrative approval route and private handover inventory first. Review each unresolved decision interactively. The full agent, renderer, synchronization and stale-output gate are planned; the [read-only preview profile](../../.github/agents/blueprint-maintainer.agent.md) must not claim they already run.

## Board synchronization

Deferred - not synchronized.
