# Caldova GitHub Authority and Azure Repos Secondary Copy - Idea

| Field | Value |
|---|---|
| **Version** | 0.3 |
| **Date** | 2026-10-29 |
| **Author** | Copilot |
| **Status** | Draft |
| **Scope** | Caldova Tenant 1 project/demo: reviewed main-history secondary copy, not source cutover |
| **References** | [Specification](../specs/2026-10-28-caldova-azure-devops-repository-design.md), [Sprint](../plans/2026-10-28-caldova-azure-devops-repository-sprint.md), [CI/CD idea](caldova-azure-devops-solution-cicd-idea.md), [Proposed ADR-0015](../adr/0015-caldova-github-authority-and-azure-repos-secondary.md), [Package index](../README.md#caldova-draft-packages) |

## Intent and source boundary

Keep GitHub as Caldova's authoritative source/PR plane while maintaining an approved secondary Azure Repos copy. Azure Pipelines reads GitHub directly; replication does not become a release prerequisite.

The user selected `main` plus reachable history, preserving commit IDs, and a separate manually queued pipeline with exact-SHA validation and approval gates. The intended target is user-supplied private/session input, not a verified live configuration.

The former GF independent-cutover idea remains in fixed snapshot `a4e4fbc`. It is not applied to Caldova. GF source/customer material, approvals and trademarks remain labelled; `IDEA-GF-REPOSITORY` is a legacy traceability ID, not current source authority.

## Value hypothesis and boundaries

The expected value is a reproducible secondary copy and clear engineering ownership without dual development. No backup/DR guarantee, measured saving or deployment date is claimed.

Copy only eligible reviewed GitHub-main history. Do not push unpushed confidential work to public GitHub, copy other branch/tag refs, use `--mirror`/force, delete target refs or reverse-merge Azure-only changes. Divergence or unavailable authority/evidence stops the operation.

Adding a local remote, Boards linkage, Pipeline access and source replication are separate operations. No live operation is performed by this idea.

## Decisions and next review

Verify target identity/privacy/ownership/refs/content, historical disclosure, LFS/submodules, credential isolation and approval enforcement. Ratify the scoped no-mirror exception and resolve known mandatory-validation failures before execution.

The [specification](../specs/2026-10-28-caldova-azure-devops-repository-design.md) owns the source/failure diagrams and detailed contract. Keep tenant-private configuration outside Git and source control authority on GitHub.

## Board synchronization

Deferred - not synchronized.
