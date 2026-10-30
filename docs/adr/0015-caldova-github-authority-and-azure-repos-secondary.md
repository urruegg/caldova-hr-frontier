# ADR-0015: Caldova GitHub Authority, Azure Repos Secondary Copy and Azure Pipelines Delivery

| Field | Value |
|---|---|
| **Version** | 0.1 |
| **Date** | 2026-10-29 |
| **Author** | Copilot |
| **Status** | Proposed Baseline |
| **Scope** | Caldova Tenant 1 project/demo: GitHub authority, approved main-history replication and direct-source Azure Pipelines |
| **References** | [Repository specification](../specs/2026-10-28-caldova-azure-devops-repository-design.md), [CI/CD specification](../specs/2026-10-28-caldova-azure-devops-solution-cicd-design.md), [ADR-0001](0001-azure-devops-as-engineering-control-plane.md), [ADR-0002](0002-github-first-bootstrap-and-the-role-of-azure-repos.md), [ADR-0012](0012-per-tenant-github-repository-and-account-topology.md), [Historical GF scope](0013-gf-azure-repos-source-authority.md), [Repository-agent delivery governance](../specs/2026-10-02-hr-frontier-copilot-agent-portfolio-governance-design.md) |

## Context and decision status

The user selected GitHub as the authoritative source/PR plane for the Caldova project, Azure Pipelines as CI/CD consuming GitHub directly, and the intended Caldova Azure Repo as a reviewed secondary copy. This is not the independent GF Azure Repos cutover model in ADR-0013.

The current Approved Tenant 1 lean decisions preserve GitHub authority but prohibit source mirroring. This Proposed Baseline records a narrow proposed exception rather than editing that approved history. Design-direction approval is not ratification, a permission grant, or evidence that live integration exists.

The eight package sets are now Caldova project/demo documents. GF remains explicitly identified source/customer context; GF policy, approval and trademark statements are not Caldova corporate facts.

## Proposed decision

1. **GitHub remains the sole source and pull-request authority**, including pipeline YAML. The existing Azure Boards backlog remains the single backlog; no second development/approval plane is created.
2. **Azure Pipelines reads authoritative GitHub source directly** for PR/main validation, controlled DEV capture and reviewed-artifact TEST delivery. Azure Repos replication is not a CI/CD prerequisite or alternate release source.
3. **Azure Repos receives only approved GitHub `main` and its reachable history.** Preserve source commit IDs; no other branch/tag references, all-ref mirror, force push, deletion or reverse synchronization is admitted.
4. **Replication is a separate manually queued pipeline**, with a selected GitHub-main SHA, successful exact-revision validation, content/history authorization, protected approval and target preflight before a non-force update.
5. **No overwrite or reconciliation by merging Azure-only work.** Equal refs are NoChange; an approved fast-forward may proceed; divergence, unrelated history, missing/failed validation, uncertain target or denied approval stops without mutation.
6. **Keep identity/permissions separate.** PR CI receives no replication or deployment credentials. The copy identity is restricted to the secondary repository and protected approvals/resources; granting project-wide build-service write access is not equivalent isolation.
7. **Retain existing GitHub validation** until equivalent Azure PR/main results and required-check blocking, source/artifact identity, retained logs, rollback/ownership and explicit retirement approval are proven.
8. **Keep actual target endpoints and credentials private/local.** Adding a local `azdo` remote is optional future configuration, not synchronization; never change `origin` into a dual-push URL or publish unpushed confidential work to satisfy replication.
9. **Preserve source and safety boundaries.** Tenant-private configuration remains ignored/outside Git; imported GF assets, the fixed GF handover and existing HR write/privacy gates remain intact.

## Scoped supersession

On formal ratification, this record supersedes only the applicable Tenant 1 no-secondary-source-copy provisions of ADR-0001, ADR-0002 and ADR-0012 for this explicit approved-main replication path, and the deferred CI/CD target to the extent separately implemented and accepted.

It preserves their GitHub source authority, Azure Boards Basic backlog, per-tenant separation and private-configuration boundary. It does not activate privileged bootstrap, automatic cloud discovery, a configuration repository, additional tenant onboarding or Basic-to-Agile conversion.

ADR-0013 remains a GF-specific historical proposal, not authority to replace Caldova GitHub with Azure Repos. ADR-0014's GF-scenario ESS/Privacy proposal is not Caldova operational authorization.

## Options considered

| Option | Disposition |
|---|---|
| GitHub authority, direct-source Azure Pipelines, separately approved Azure secondary | Selected design direction; preserves continuity without making copy lag a release dependency. Requires explicit replication/governance proof. |
| Azure Repos becomes source/PR authority | Not selected for Caldova. It was the independent GF handover model, a different customer/source boundary. |
| GitHub source and Azure Pipelines with no Azure code copy | Simpler and consistent with the earlier lean target, but does not meet the user's secondary-copy requirement. |
| Clean snapshot without source history | Useful for a filtered independent handover; not selected for this ongoing same-project copy because it changes commit identity and continuity. |
| Bidirectional sync or `--mirror` | Rejected: creates authority ambiguity and can overwrite/delete target refs. |

## Consequences and activation gates

The secondary is not a backup/DR guarantee, an independent development repository or proof of customer handover. Historical content reachable from `main` must be reviewed, not just current files.

Before any live change, verify the intended target's identity, privacy, ownership, permissions, refs/default branch/content, source eligibility, LFS/submodule needs, exact revision validation and approval enforcement. A supplied URL, historical zero size or existing authentication does not close these gates.

Current legacy branding failures block a claim of green required CI; a passing focused subset is not a substitute. Production deployment remains later scope. No remote, connection, pipeline, permission, Git ref or deployment is configured by this record.
