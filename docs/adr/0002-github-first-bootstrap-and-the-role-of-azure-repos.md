# ADR-0002: GitHub-First Bootstrap, and the Role of Azure Repos

| Field | Value |
|---|---|
| **Version** | 2.0 |
| **Date** | 2026-09-28 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Approved |
| **Scope** | Cross-cutting (all solution domains) |
| **References** | [Approved Intake Design](../specs/2026-09-17-architecture-baseline-intake-design.md), [Tenant 1 Engineering Platform Remediation Design](../specs/2026-09-28-tenant-1-engineering-platform-remediation-design.md), [Source Inventory](../reviews/2026-09-17-architecture-baseline-source-inventory.json), [ADR-0012](0012-per-tenant-github-repository-and-account-topology.md) |

## Attended Decision

Approved on 2026-09-28 for the Tenant 1 remediation baseline defined by
[Tenant 1 Engineering Platform Remediation Design](../specs/2026-09-28-tenant-1-engineering-platform-remediation-design.md).
Acceptance establishes one tenant-dedicated GitHub product-source repository, one Azure DevOps project and Boards backlog,
and one tenant-private Azure Repo named `caldova-hr-frontier-config`. It does not approve a shared source repository,
an initial mirror, synchronization, or a live mutation whose reviewed plan hash has changed.

## Revision Note (v2.0)

Version 2.0 records the attended Wave 0 approval, removes the prior mirror option, and makes the Azure Repo boundary binding. Each tenant runs bootstrap from its own dedicated product-source repository for its own Azure DevOps organization and project. The Tenant 1 names below are the approved Tenant 1 implementation, not a shared multi-tenant workflow.

## Context

ADR-0001 established Azure DevOps as the Engineering Control Plane and GitHub as the Digital Factory, and assumed Azure Repos would stay empty to avoid ambiguity about where code lives.

Two decisions since then change that:

1. **The GitHub repository is created first and provisions Azure DevOps**, rather than both being stood up by hand in parallel. The showcase demonstrates that the engineering control plane is itself reproducible from source.
2. **A dedicated tenant account, `admin@Caldova25156897.onmicrosoft.com`, is the attended identity through which the tenant and the Power Platform are configured.** That account's credentials, and the tenant-specific configuration it manages, must not live in a public repository.

The second point creates a genuine problem that ADR-0001 only flagged and did not solve. The public repository cannot hold deployment settings files containing real environment URLs and connection identifiers, tenant and subscription identifiers, pipeline templates that gate production, or operational runbooks referencing the admin account. Something inside the tenant boundary has to hold them.

---

## Decision

### 1. GitHub is the origin; Azure DevOps is provisioned from it

The approved topology creates the Tenant 1 GitHub repository first. A future bootstrap workflow in that repository provisions, in the existing `dev.azure.com/caldova25156897` organisation:

- the `Caldova HR Frontier` project,
- the private Azure Repos repository `caldova-hr-frontier-config`,
- area paths, iterations and team configuration,
- service connections to the Azure subscription and to the three Power Platform environments,
- pipeline environments with approvals and checks,
- the Azure Boards ↔ GitHub connection.

The organisation itself is treated as an existing tenant-boundary input, and organisation creation is a portal operation.

Bootstrap must be **re-runnable and idempotent**. Re-running it against an already-provisioned project must not fail or duplicate.

### 2. Azure Repos has a narrow and explicit purpose

The private Azure Repo contains only tenant-private configuration, governed templates, operational runbooks,
configuration schemas, and sanitized evidence. It contains no product source, credential, unrestricted membership export, bidirectional synchronization, or initial disaster-recovery mirror.
A mirror requires a future ADR and is not implicit in this decision.

### 3. The split is directional and stated

```text
GitHub (tenant product source)     Azure Repos (private, in-tenant)
──────────────────────────────     ────────────────────────────────
Operating model docs               Tenant-private configuration
Platform documentation             Governed pipeline templates
Power Platform solution source     Operational runbooks
GitHub Actions workflows           Configuration schemas
Agent definitions                  Sanitized evidence
Copilot instructions
Synthetic demo data
```

**Nothing should flow from Azure Repos back into GitHub.** If content needs to be public, it is authored in GitHub in the first place.

---

## Rationale

1. **It resolves the public-repository tension honestly.** ADR-0001 said "move the tenant identifiers out before going public" without saying where to. Now there is a place.
2. **Bootstrap-from-source is the more interesting demonstration.** A showcase that can rebuild its own control plane proves more than one that was clicked together.
3. **The *Required template* check only has integrity if the template is elsewhere.** Azure DevOps checks cannot be modified by someone editing the pipeline YAML — but if the template itself sits in the repository the pipeline author controls, that property is lost.
4. **It keeps the single-backlog rule intact.** Azure Repos holds configuration, not the product backlog and not the product source. Azure Boards remains the only backlog; GitHub remains the only place product code is written.
5. **The admin account's operational material stays inside the tenant**, where it is covered by tenant access controls and audit rather than by a repository's visibility setting.

---

## Consequences

### Positive

- The public repository can stay genuinely free of tenant-specific values without losing the information.
- The engineering control plane becomes reproducible, and re-provisionable into a second tenant.
- Production gating gains real integrity through an out-of-reach required template.
- Tenant-private configuration and governed templates remain reviewable without creating a second product-source location.

### Negative

- **Two repositories to explain** instead of one: the tenant GitHub product-source repository and the private Azure Repos configuration repository. Contributor onboarding must be explicit about which is which.
- **Risk of content drifting into the wrong place.** Someone will eventually put documentation in Azure Repos or a real environment URL in GitHub.
- **The bootstrap workflow is itself privileged.** It creates projects, service connections and approval gates, so it becomes a high-value target and needs its own review discipline.

### Mitigations

- Repository guidance should state the directional rule in one sentence each: *public GitHub for anything reproducible, private Azure Repos for anything tenant-specific.*
- The pull request redaction checklist should ask for confirmation that no tenant identifier is introduced.
- The future bootstrap workflow should run only on `workflow_dispatch` from `main`, be gated by a GitHub environment with a required reviewer, and be owned in `CODEOWNERS`.
- The bootstrap must be idempotent, so a failed or partial run is recoverable by re-running rather than by manual repair.
- Product source and repository synchronization remain prohibited unless a future ADR explicitly approves a mirror.

---

## Alternatives Considered

**Keep Azure Repos empty and put tenant configuration in a private GitHub repository.** Rejected: a second GitHub repository under a personal account still sits outside the tenant boundary, and private repositories on a personal Free plan do not get the environment protection rules the public one does.

**Keep tenant configuration only in Azure DevOps variable groups and secure files, with no repository.** Rejected: variable groups are not versioned, not reviewable and not diffable. Configuration that gates production deserves the same review discipline as code.

**Provision Azure DevOps by hand and document the steps.** Rejected: it contradicts the showcase objective that the whole system be rebuildable from source, and hand-built control planes drift.

---

## References

- [Approved Intake Design](../specs/2026-09-17-architecture-baseline-intake-design.md) — the governed intake and bootstrap design; Infrastructure detail enters in Phase 3.
- [ADR-0001](0001-azure-devops-as-engineering-control-plane.md) — the approved control-plane and product-source split
- [Tenant 1 Engineering Platform Remediation Design](../specs/2026-09-28-tenant-1-engineering-platform-remediation-design.md)
