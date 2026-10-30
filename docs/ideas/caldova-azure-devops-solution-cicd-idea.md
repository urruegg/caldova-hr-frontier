# Caldova GitHub-Source Azure Pipelines CI/CD and DEV Capture - Idea

| Field | Value |
|---|---|
| **Version** | 0.3 |
| **Date** | 2026-10-29 |
| **Author** | Copilot |
| **Status** | Draft |
| **Scope** | Caldova project/demo: GitHub PR authority, Azure CI/CD and independent approved secondary replication |
| **References** | [Specification](../specs/2026-10-28-caldova-azure-devops-solution-cicd-design.md), [Sprint](../plans/2026-10-28-caldova-azure-devops-solution-cicd-sprint.md), [Repository idea](caldova-azure-devops-repository-idea.md), [Proposed ADR-0015](../adr/0015-caldova-github-authority-and-azure-repos-secondary.md), [Package index](../README.md#caldova-draft-packages) |

## Intent and current scope

Move the validation/delivery execution platform toward Azure Pipelines without moving Caldova source/PR authority away from GitHub. Explicit DEV export/unpack proposes source changes through GitHub branches/PRs; reviewed source drives artifact creation and TEST delivery.

The user confirmed direct GitHub-source Azure Pipelines and a separate manually queued main-history copy to Azure Repos. That secondary is not an authoritative build source. The old independent GF Azure Repos lifecycle remains historical at `a4e4fbc`.

This Caldova project/demo retains clearly labelled GF requirements/source/customer context. No GF policy, permission, brand or reported approval becomes Caldova operational authorization.

## Value and operating model

The working benefit is repeatable reviewed-source delivery with exact source/artifact/validation identity. No performance, saving or live-pipeline result is claimed.

Separate PR/main CI, controlled DEV capture, TEST CD and approved replication. Keep PR credentials minimal, deploy only under protected authorization and stop on failed/uncertain outcomes. A copy failure cannot switch CI/CD to Azure-only changes.

## Open gates and next review

Prove GitHub App/service access and required Azure checks in GitHub; retain the existing check until equivalence and retirement approval. Verify full chosen-harness round-trip, component/dependency inventory, private configuration, identities, artifact model and TEST read-back.

Known branding failures remain mandatory-CI readiness blockers. No new GitHub workflow, live connection, pipeline, export/import, source copy or production release is created by this draft.

The [specification](../specs/2026-10-28-caldova-azure-devops-solution-cicd-design.md) defines lifecycle/interaction diagrams, safety and migration acceptance.

## Board synchronization

Deferred - not synchronized.
