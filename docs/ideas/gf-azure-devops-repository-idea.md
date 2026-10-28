# GF Azure DevOps Repository Establishment - Idea

| Field | Value |
|---|---|
| **Version** | 0.2 |
| **Date** | 2026-10-28 |
| **Author** | Copilot |
| **Status** | Draft |
| **Scope** | GF technical package: independent Azure Repos repository |
| **References** | [Specification](../specs/2026-10-28-gf-azure-devops-repository-design.md), [Sprint](../plans/2026-10-28-gf-azure-devops-repository-sprint.md), [GF source-authority refinement](../adr/0013-gf-azure-repos-source-authority.md), [Package index](../README.md#gf-draft-packages) |

## Status and provenance

On 2026-10-28 the user confirmed that GF's target repository is Azure DevOps/Azure Repos, seeded from this repository through a one-time reviewed transfer. This is a confirmed target requirement, not an unresolved GitHub-versus-Azure-Repos choice. Nothing has been cloned or published by this documentation change.

The supplied build brief v1.0 sections 1-2 add proposed agent source layout, environment configuration and SharePoint separation. They are design inputs, not evidence that a destination or control is operational. Local preparation is authorized; the confidential brief and detailed refinements must not be committed/pushed to the public demo repository.

## Problem and expected value

GF needs an owned engineering baseline that does not depend on the demonstration repository as its live source authority. The expected value is clear ownership, controlled changes and a foundation for GF delivery pipelines.

## Confirmed idea

After transfer, GF Azure Repos is the sole GF source and pull-request authority. This GitHub repository remains a separate demo/reference repository. There is no automatic synchronization.

A reviewed clone/seed is not permission to copy all demo configuration, evidence or Git history without inspection. The transfer mechanism and history treatment remain open.

## Decision and handover boundary

The GF-specific ADR refinement (Proposed Baseline) preserves approved demo decisions while recording the GF target. Approval to draft is not approval to migrate. GF repository access, branch policies and validation must be explicitly established rather than inherited from the demo's solo-owner settings.

Copilot Studio's GitHub Copilot **runtime harness** is the selected MVP agent platform; it does not change Azure Repos source ownership or require using GitHub as GF's source host. ESS is out of MVP scope.

The brief's example agent/topic/prompt folders need a reviewed harness-specific source mapping, not a second hand-maintained copy of solution artifacts. Preserve the existing five linked documentation packages. Keep business PDFs, real personal data, tenant-specific values and private source evidence outside Git.

## Open decisions and next review

Confirm target organization/project/repository, accountable owner, access baseline, history-preserving versus clean-seed transfer, inclusion/exclusion inventory, licensing obligations and verification evidence. Review current source and any included history for secrets and tenant-specific material before transfer.

This package establishes the repository. The separate CI/CD package owns solution capture, build and TEST delivery.

The [CAT assessment](../README.md#cat-reuse-assessment) supplies candidate versions, provenance and admission gates. No assessed plugin performs the repository transfer. Any future reused bundle needs exact-revision/checksum, dependency, license, code/data-flow and harness review before vendoring; catalogue support is not a production support contract. See the [transfer diagrams](../specs/2026-10-28-gf-azure-devops-repository-design.md#8-transfer-process-and-interactions).

## Board synchronization

Deferred - not synchronized.
