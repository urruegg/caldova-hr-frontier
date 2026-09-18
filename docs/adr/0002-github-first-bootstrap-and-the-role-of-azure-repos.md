# ADR-0002: GitHub-First Bootstrap, and the Role of Azure Repos

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-17 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Cross-cutting (all solution domains) |
| **References** | [Approved Intake Design](../specs/2026-09-17-architecture-baseline-intake-design.md), [Source Inventory](../reviews/2026-09-17-architecture-baseline-source-inventory.json) |

This candidate is not an accepted repository decision until attended review approves it.

## Context

ADR-0001 established Azure DevOps as the Engineering Control Plane and GitHub as the Digital Factory, and assumed Azure Repos would stay empty to avoid ambiguity about where code lives.

Two decisions since then change that:

1. **The GitHub repository is proposed to be created first and to provision Azure DevOps**, rather than both being stood up by hand in parallel. The showcase should demonstrate that the engineering control plane is itself reproducible from source.
2. **A dedicated tenant account, `admin@Caldova25156897.onmicrosoft.com`, is the proposed identity through which the tenant and the Power Platform would be configured.** That account's credentials, and the tenant-specific configuration it manages, must not live in a public repository.

The second point creates a genuine problem that ADR-0001 only flagged and did not solve. The public repository cannot hold deployment settings files containing real environment URLs and connection identifiers, tenant and subscription identifiers, pipeline templates that gate production, or operational runbooks referencing the admin account. Something inside the tenant boundary has to hold them.

---

## Proposed Decision

### 1. GitHub is the origin; Azure DevOps is provisioned from it

The proposed baseline would create the public GitHub repository first. A future bootstrap workflow in that repository provisions, in the existing `dev.azure.com/caldova25156897` organisation:

- the `Caldova HR Frontier` project,
- the private Azure Repos repository `caldova-hr-frontier-config`,
- area paths, iterations and team configuration,
- service connections to the Azure subscription and to the three Power Platform environments,
- pipeline environments with approvals and checks,
- the Azure Boards ↔ GitHub connection.

The organisation itself is treated as an existing tenant-boundary input, and organisation creation is a portal operation.

Bootstrap must be **re-runnable and idempotent**. Re-running it against an already-provisioned project must not fail or duplicate.

### 2. Azure Repos is proposed for a narrow and explicit purpose

The proposed Azure Repos role is narrow. It holds exactly two things:

| Content | Why it cannot live in GitHub |
|---|---|
| **Tenant-specific configuration** — deployment settings files with real environment URLs and connection identifiers, variable group definitions, tenant and subscription identifiers, environment inventory | The GitHub repository is public and permanent |
| **Governed pipeline templates** — the YAML templates enforced by the proposed Azure DevOps *Required template* check | The check is only meaningful if the template is outside the reach of the person editing the pipeline |

Plus, optionally, a **one-way mirror of GitHub `main`** for in-tenant traceability and disaster recovery. The mirror is read-only and is never a place anyone commits.

### 3. The split is directional and stated

```text
GitHub (public)                    Azure Repos (private, in-tenant)
─────────────────────              ────────────────────────────────
Operating model docs               Deployment settings (real values)
Platform documentation             Variable group definitions
Power Platform solution source     Governed pipeline templates
GitHub Actions workflows           Operational runbooks
Agent definitions                  Break-glass procedures
Copilot instructions               (optional) mirror of GitHub main
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
- Disaster recovery improves: an in-tenant mirror survives the loss of the external GitHub account.

### Negative

- **Three repositories to explain** instead of one: public GitHub, private Azure Repos config, and the optional mirror. Contributor onboarding must be explicit about which is which.
- **Risk of content drifting into the wrong place.** Someone will eventually put documentation in Azure Repos or a real environment URL in GitHub.
- **The bootstrap workflow is itself privileged.** It creates projects, service connections and approval gates, so it becomes a high-value target and needs its own review discipline.
- **Mirroring adds a moving part** that can silently stop.

### Mitigations

- Repository guidance should state the directional rule in one sentence each: *public GitHub for anything reproducible, private Azure Repos for anything tenant-specific.*
- The pull request redaction checklist should ask for confirmation that no tenant identifier is introduced.
- The future bootstrap workflow should run only on `workflow_dispatch` from `main`, be gated by a GitHub environment with a required reviewer, and be owned in `CODEOWNERS`.
- The bootstrap must be idempotent, so a failed or partial run is recoverable by re-running rather than by manual repair.
- The mirror, if enabled, must be monitored and its failure treated as a work item — not silently ignored.

---

## Alternatives Considered

**Keep Azure Repos empty and put tenant configuration in a private GitHub repository.** Rejected: a second GitHub repository under a personal account still sits outside the tenant boundary, and private repositories on a personal Free plan do not get the environment protection rules the public one does.

**Keep tenant configuration only in Azure DevOps variable groups and secure files, with no repository.** Rejected: variable groups are not versioned, not reviewable and not diffable. Configuration that gates production deserves the same review discipline as code.

**Provision Azure DevOps by hand and document the steps.** Rejected: it contradicts the showcase objective that the whole system be rebuildable from source, and hand-built control planes drift.

---

## References

- [Approved Intake Design](../specs/2026-09-17-architecture-baseline-intake-design.md) — the governed intake and bootstrap design; Infrastructure detail enters in Phase 3.
- [ADR-0001](0001-azure-devops-as-engineering-control-plane.md) — the proposed original control plane split
