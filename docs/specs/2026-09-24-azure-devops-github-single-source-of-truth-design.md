# Azure DevOps and GitHub Connection: Single Source of Truth for Source Code

| Field | Value |
|---|---|
| **Version** | 1.1 |
| **Date** | 2026-09-24 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Infrastructure (Tenant 1) |
| **References** | [ADR-0001](../adr/0001-azure-devops-as-engineering-control-plane.md), [ADR-0002](../adr/0002-github-first-bootstrap-and-the-role-of-azure-repos.md), [Azure DevOps Engineering Control Plane](../../infra/docs/13-azure-devops-engineering-control-plane.md), [GitHub Repository Blueprint](../../infra/docs/14-github-repository-blueprint.md), [Multi-Tenant Provisioning](../../infra/docs/18-multi-tenant-provisioning.md), [Tenant 1 Discovery Evidence](../../infra/evidence/discovery/caldova25156897.json) |

## Status

Proposed Baseline. This document operationalizes ADR-0001 and ADR-0002 — both still Proposed Baseline themselves — for Tenant 1 (`caldova25156897`). It does not supersede either ADR and introduces no new architectural decision; it confirms, with current evidence, how the already-decided split is meant to be wired together, and records the gap between that decision and what exists today. Nothing in this document authorizes a live change to GitHub or Azure DevOps.

## Revision Note (v1.1)

This document was revised after Task 1 landed (commit `3024e25`, `feat(infra): capture Azure Repos repository size and default branch in discovery`). The evidence gap identified in the original Context section is closed by capturing `size` (bytes) and `defaultBranch` — both already present in the existing Azure DevOps Git Repositories API response — rather than commit count or `parentRepository`/import metadata, because the Azure DevOps repositories list API does not return a commit count. The Context section and Verification Plan below have been corrected to reflect what was actually built, and the Verification Plan and Open Items now also note that the Azure Boards ↔ GitHub App connection cannot yet be confirmed or ruled out by discovery, because discovery does not query the `githubconnections` API area.

## Objective

Answer, for Tenant 1, whether the source code for `urruegg/caldova-hr-frontier` has one unambiguous, authoritative copy, and specify exactly how Azure DevOps is meant to reference that copy without creating a second one.

## Context: What Current Evidence Shows

Tenant 1 discovery (`infra/evidence/discovery/caldova25156897.json`, run `a490a106-9d3e-4389-911a-3e6540f5aca4`, collected 2026-09-23) shows:

| Item | Status |
|---|---|
| Azure DevOps organization/project `Caldova HR Frontier` | Existing, `f250378e-597d-487b-854a-fb8338962822` |
| Azure Repos Git repository `Caldova HR Frontier` | Existing, `e518fd29-3604-4b24-9853-efff150e3865` — the project's auto-created default repository |
| Azure Boards ↔ GitHub App connection | Not observable with current discovery — `githubconnections` is a distinct Azure DevOps API area that discovery does not yet query; absence of service-endpoint/environment/pipeline/check resources does not prove this connection is absent |
| GitHub Environment `bootstrap-caldova25156897` | Missing |
| Azure Pipelines | None found |

Two things follow from this evidence, and neither should be inferred beyond what it shows:

1. **No service-endpoint, environment, pipeline, or check connects GitHub and Azure DevOps for Tenant 1 today.** The organization and project exist as attended prerequisites; nothing in those four resource types joins them to the GitHub repository. Whether the Azure Boards GitHub App connection itself is installed is a separate, currently unobservable question — discovery does not query the `githubconnections` API area, so its absence from these four resource types is not proof it is absent.
2. **The existing Azure Repos Git repository's content is now observable.** `Get-AzureDevOpsDiscovery.ps1` records `id`, `name`, `url`, `scope`, `status`, `size` (bytes), and `defaultBranch` for a repository resource. A repository with `size = 0` and no `defaultBranch` has never received a push; a populated repository shows a nonzero size and a default branch. Tenant 1's evidence file (`infra/evidence/discovery/caldova25156897.json`, run `a490a106-9d3e-4389-911a-3e6540f5aca4`) predates this capability and must be re-run to read back these values for the existing repository — see the Verification Plan.

## Two Connections, Not One

Reviewing a Microsoft-sourced overview of Azure DevOps and GitHub positioning (source code → GitHub, backlog → Azure Boards, CI/CD → GitHub Actions or Azure Pipelines) confirms the direction already recorded in ADR-0001 and ADR-0002. Applied to Tenant 1, "connecting" GitHub to Azure DevOps is two independent, purpose-built connections — never a copy of the source code itself:

```text
GitHub (public)                         Azure DevOps (dev.azure.com/caldova25156897)
─────────────────────                   ──────────────────────────────────────────────
urruegg/caldova-hr-frontier    ────►     Azure Boards GitHub App
  (sole source of truth)                   - AB# in commits/PRs links to work items
                                            - merge to main transitions work-item state
                                            - attended, one-time authorization

urruegg/caldova-hr-frontier    ────►     Azure Pipelines GitHub service connection
  (checked out at build time,               - used only by the future governed
   never copied into Azure Repos)            Power Platform DEV -> TEST -> PROD
                                              promotion pipeline (infra/docs/13)
                                            - resources.repositories + checkout,
                                              no Azure Repos mirror required
```

- **Backlog connection — Azure Boards GitHub App.** This is the connection ADR-0001 already specifies. It links work items to commits and pull requests through the `AB#` convention; it carries no source code.
- **Build connection — Azure Pipelines GitHub service connection (future).** Azure Pipelines can declare the GitHub repository as an external `repository` resource and check it out directly at build time, authenticated through a service connection. This is a standard, documented Azure Pipelines capability and requires no Azure Repos copy of the source. It applies only once the governed Power Platform promotion pipeline described in infra/docs/13 is built — not in this sprint.
- **Azure Repos carries zero source code either way**, consistent with ADR-0002's rule that "nothing should flow from Azure Repos back into GitHub." The optional one-way DR mirror ADR-0002 describes is explicitly out of scope for Tenant 1 per this review; it was considered and declined in favor of the simpler zero-copy model above.

## Gap Analysis and Target State

| Component | Current state | Target state | Who acts |
|---|---|---|---|
| GitHub repository `urruegg/caldova-hr-frontier` | Existing, authoritative | Unchanged | — |
| Azure DevOps org/project | Existing | Unchanged | — |
| Azure Repos Git repository (currently named `Caldova HR Frontier`) | Existing, content unverified | Renamed/repurposed to `caldova-hr-frontier-config`†; holds only deployment settings, variable-group definitions, governed pipeline templates, and runbooks, per ADR-0002 | Attended Azure DevOps administrator action; not automatable from GitHub |
| Azure Boards GitHub App | Not connected | Installed through attended one-time authorization; `AB#` commit-message ruleset and pull request template enforce the convention | Attended GitHub + Azure DevOps administrator action ([Install the Azure Boards app for GitHub](https://learn.microsoft.com/en-us/azure/devops/boards/github/install-github-app?view=azure-devops)) |
| GitHub Environment `bootstrap-caldova25156897` | Missing | Created per infra/docs/14 | Future reviewed bootstrap workflow run |
| Azure Pipelines GitHub service connection | Does not exist (no pipeline exists) | Created only when the Power Platform promotion pipeline is built | Future, separate review |

† This narrows ADR-0002's automated-provisioning intent to a manual rename for Tenant 1 specifically, because an Azure Repos Git repository named `Caldova HR Frontier` already exists here (evidenced above) rather than needing to be created fresh; a future bootstrap workflow implementing ADR-0002 for a new tenant would still create `<tenantAlias>-config` directly.

## Verification Plan

Evidence must be collected and read back before any status above is claimed `Existing`:

1. **Done.** `Get-AzureDevOpsDiscovery.ps1` now captures the Azure Repos Git repository's `size` (bytes) and `defaultBranch` (commit `3024e25`, `feat(infra): capture Azure Repos repository size and default branch in discovery`), closing the evidence gap identified above without needing a commit count or `parentRepository`/import metadata — the Azure DevOps Git Repositories list API does not return a commit count. Re-running Tenant 1 discovery will populate these fields for the existing repository and answer whether it already holds content.
2. Before the Azure Boards GitHub App connection can be confirmed or ruled out by discovery, `Get-AzureDevOpsDiscovery.ps1` must be extended to query the `githubconnections` API area, which it does not currently read. This is a prerequisite step, not yet done.
3. After the Azure Boards GitHub App is installed **and** step 2 above is implemented, re-run tenant discovery and confirm a `githubconnections` (or equivalent service-endpoint/connection) resource is now returned for Azure DevOps — that read-back is the proof the link exists, not the installation step itself.
4. No live change to GitHub repository settings, Azure Repos, or Azure Boards is made by this document. Any change follows this repository's existing attended-review bootstrap discipline (infra/docs/17, infra/docs/19).

## Open Items

- Whether to rename the existing Azure Repos default repository or create a differently named one is an attended Azure DevOps administrator decision, not resolved here.
- The Power Platform promotion pipeline and its GitHub service connection are future scope; this document only confirms the connection method is available when that pipeline is designed.
- The optional ADR-0002 DR mirror remains available if a future review decides Tenant 1 needs it; it is declined for now, not removed as an option.
- Extending `Get-AzureDevOpsDiscovery.ps1` to query the `githubconnections` API area — needed to observe the Azure Boards GitHub App connection directly instead of inferring its absence — is unautomated future work, not done by this branch.
