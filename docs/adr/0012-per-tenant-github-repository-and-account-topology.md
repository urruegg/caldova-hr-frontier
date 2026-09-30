# ADR-0012: Per-Tenant GitHub Repository and Account Topology

| Field | Value |
|---|---|
| **Version** | 3.0 |
| **Date** | 2026-09-28 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Approved |
| **Scope** | Cross-cutting (all solution domains) |
| **References** | [Tenant 1 Lean Engineering Platform Design](../specs/2026-09-28-tenant-1-lean-engineering-platform-design.md), [ADR-0001](0001-azure-devops-as-engineering-control-plane.md), [ADR-0002](0002-github-first-bootstrap-and-the-role-of-azure-repos.md), [ADR-0004](0004-domain-solution-architecture-and-publisher.md), [Azure DevOps and GitHub single source of truth design](../specs/2026-09-24-azure-devops-github-single-source-of-truth-design.md) |

## Attended Decision

Approved on 2026-09-28 for **Option A — Lean single-tenant platform**, as defined by
the [Tenant 1 Lean Engineering Platform Design](../specs/2026-09-28-tenant-1-lean-engineering-platform-design.md).
The lean design supersedes the broader remediation topology. This ADR approves a
target and does not authorize a live service mutation.

## Revision Note (v3.0)

Version 3.0 retains one GitHub product-source repository per tenant while removing the
private Azure Repo from the current topology. Tenant 1 private configuration is an
ignored local file with an encrypted, restore-tested backup outside Git. Existing
Tenant 2 files are out of scope for the lean sprint and remain untouched.

## Context

ADR-0001 established that exactly one GitHub repository connects to exactly one Azure DevOps organization and project through the Azure Boards GitHub App — "one organization only" was recorded there as a negative consequence of Option C, not examined further at the time.

This repository, `urruegg/caldova-hr-frontier`, has since been used as a shared "factory": it holds tenant configuration manifests (`infra/src/config/tenants/*.psd1`) and discovery evidence for **two** tenants —

- Tenant 1, `caldova25156897`, Azure DevOps org `https://dev.azure.com/caldova25156897/`
- Tenant 2, `caldova25668747`, Azure DevOps org `https://dev.azure.com/caldova25668747/`

— both currently configured with `GitHub.Owner = 'urruegg'` and the same `GitHub.Repository = 'caldova-hr-frontier'`.

A third tenant is now planned for Georg Fischer (Tenant 3), the actual customer this platform is designed for, as distinct from Tenant 1 and Tenant 2, which are the builder's own demonstration/development tenants under the personal `urruegg` GitHub account.

Two forces collide:

1. **The Azure Boards GitHub App enforces the ADR-0001 constraint at the platform level, not just as a recorded consequence.** A GitHub repository cannot be connected to more than one Azure DevOps organization at the same time; a second connection attempt is rejected until the first is removed. Verified directly against GitHub and Microsoft's own integration behavior, not inferred.
2. **Tenant 3 (Georg Fischer) needs the features a personal GitHub account cannot provide** — organization-level issue types, organization rulesets and secrets, and Environment protection rules with required reviewers — which ADR-0001 already listed as unavailable under `urruegg`'s personal account.

Continuing to host Tenant 1 and Tenant 2 from the same repository means only one of the two can have a live Boards↔GitHub connection at any given moment. That silent, easy-to-forget trade-off is the immediate problem this ADR resolves, ahead of Tenant 3's onboarding.

---

## Decision

GitHub is the sole product-source and pull-request authority. Azure Boards is the
single delivery backlog and remains on the built-in Basic process. Repository
validation runs in GitHub Actions. A future Azure Pipeline will consume this GitHub
repository directly for HR solution CI/CD; no Azure Pipeline is created this sprint.

Tenant 1 private configuration is an ignored local file with an encrypted,
restore-tested backup outside Git. A private Azure Repo, OIDC bootstrap,
`bootstrap-tenant1` Environment, cloud workflow retrieval, and Basic-to-Agile
conversion are not current targets.

**Adopt one GitHub product-source repository and one Azure DevOps organization,
project, and Basic backlog per tenant, with GitHub account type varying by tenant,
not by a shared repository.**

| Tenant | GitHub location | Account type | Status |
|---|---|---|---|
| Tenant 1 | `urruegg/caldova-hr-frontier` (this repository) | Personal | Existing; unchanged |
| Tenant 2 | `AndreaRizzi/caldova-hr-frontier` | Personal (different individual) | Not yet created |
| Tenant 3 (Georg Fischer) | A new organization-owned repository, org not yet named | GitHub Organization | Not yet created |

1. **This repository is the Tenant 1 product-source repository.** The lean sprint does not alter, migrate, package, or validate existing Tenant 2 files.
2. **Tenant 2 gets its own personal-account repository** when separately attended and authorized.
3. **Tenant 3 gets its own organization-owned repository** when its GitHub organization and tenant details are known.
4. **The rule is symmetric across all tenants regardless of account type**: one GitHub product-source repository, one Azure DevOps organization and project, and one live Boards connection. Account type (personal vs. organization) is a per-tenant choice, not an exception to the topology rule.
5. **Tenant-private configuration is not a second repository role.** For Tenant 1 it is the ignored `tenant1.local.psd1`, protected by an encrypted, restore-tested backup outside Git.

### Seeding strategy

Each new tenant repository (Tenant 2, Tenant 3) is seeded as a **one-time copy** of this repository's current content — via GitHub's "generate from template" or an equivalent fork-then-detach — not a live git fork and not an ongoing automatic sync.

- The new repository immediately removes every other tenant's manifest and discovery evidence, keeping only its own.
- Fixes and improvements made in one tenant's repository afterward are backported to the others **deliberately**, through a normal pull request, at whatever cadence the maintainers choose. There is no automatic propagation.
- This matches this repository's existing governance posture: every change of consequence is attended and reviewed, never silently synchronized. It is also the simplest option available today, and the one that does not require standing up shared-component tooling this codebase does not yet have.

---

## Rationale

1. **The constraint is real and already enforced**, not merely a documented trade-off to manage by convention. Designing around it now, before Tenant 3 onboards, is cheaper than discovering it mid-incident when a Tenant 1 change silently drops Tenant 2's Boards traceability.
2. **Symmetry avoids a tenant-dependent exception.** Making personal-vs-organization the only axis of difference — rather than shared-repository-for-personal, dedicated-repository-for-organization — keeps one topology rule instead of two, which is easier to state, audit and explain to a new contributor.
3. **A one-time seed matches this repository's own attended-change philosophy.** Automatic propagation is deliberately avoided in favor of reviewed, deliberate promotion.
4. **It does not block on work this repository cannot do.** Creating `AndreaRizzi`'s repository or Georg Fischer's GitHub Organization requires credentials this environment does not hold. Recording the decision and the seeding mechanism now lets that attended work proceed independently, on its own schedule, without blocking documentation or planning.

---

## Consequences

### Positive

- Every tenant has a clean, symmetric, always-correct Boards↔GitHub connection — no manual re-pointing, no silent one-tenant-at-a-time trade-off.
- Tenant 3 (Georg Fischer) gets full organization-level GitHub features from day one, without forcing Tenant 1 or Tenant 2 into an organization they do not need.
- The seeding mechanism requires no new tooling; it is a one-time repository operation available in the GitHub product today.

### Negative

- **Three repositories to maintain** instead of one. A fix made in Tenant 1's repository does not appear in Tenant 2's or Tenant 3's until someone deliberately backports it.
- **Divergence risk.** Without a scheduled backport review, the repositories will drift, and by how much depends entirely on maintainer discipline.
- **No automated evidence of parity.** Nothing today compares the three repositories' tooling and detects drift; this is accepted as a manual process for now.

### Mitigations

- The maintainer who owns cross-tenant fixes should periodically review whether a change in one repository is broadly applicable and open a corresponding pull request in the others. This ADR does not assign that cadence; a future runbook should.
- If more than three tenant-dedicated repositories are ever needed, or if drift becomes a recurring problem, revisit the "shared core as a versioned component" alternative below — it was deliberately deferred here, not ruled out permanently.

---

## Alternatives Considered

**Keep Tenant 1 and Tenant 2 sharing one repository, accept the one-tenant-at-a-time Boards connection.** Rejected: it reintroduces, by inaction, exactly the ambiguity this ADR exists to close, and it is easy to forget which tenant currently holds the live connection.

**Branch-per-tenant instead of repository-per-tenant.** Rejected: the Azure Boards GitHub App connects at the repository level, not the branch level. A second branch in the same repository does not create a second connection target; this does not solve the constraint at all.

**A live GitHub fork relationship between the tenant repositories**, with periodic `merge upstream/main`. Deferred, not rejected: it keeps a discoverable lineage and eases pulling in upstream fixes, but adds ongoing merge-conflict management this showcase does not yet need. Revisit if backport frequency becomes high enough to justify the overhead.

**A shared core extracted as a versioned component** (Git submodule or private package), consumed by all three tenant repositories at a pinned version. Deferred, not rejected: the cleanest long-term separation of concerns, but real engineering investment — versioning, release discipline, a publishing pipeline — that is not justified for three tenants today. Revisit if a fourth customer-dedicated tenant is expected.

**Full Azure DevOps consolidation** (Azure Repos, Azure Boards and Azure Pipelines only, no GitHub). Rejected: this repository's purpose includes demonstrating GitHub Copilot CLI and coding-agent-native development — `.github/copilot-instructions.md`, `AGENTS.md`, pull-request-based Copilot review — none of which has an Azure DevOps equivalent. Removing the "build in the open" motivation for a public repository (moot once repositories are private) does not remove this second, independent reason to keep GitHub.

---

## Compliance

A future change should be able to answer:

1. Does every tenant still have exactly one GitHub product-source repository connected to exactly one Azure DevOps organization and project?
2. Was a new tenant repository seeded as a one-time copy, with every other tenant's manifest and evidence removed before first use?
3. If a fix was made in one tenant's repository, was a corresponding backport pull request at least considered for the others?
4. Does removing a tenant's configuration from a repository happen only in Slice 5, after that tenant's destination repository already exists and holds a verified copy — never before?

---

## References

- [ADR-0001](0001-azure-devops-as-engineering-control-plane.md) — approves the one-repository-one-organization control-plane rule
- [ADR-0002](0002-github-first-bootstrap-and-the-role-of-azure-repos.md) — approves the ignored local private-configuration boundary and no-current-bootstrap rule
- [ADR-0004](0004-domain-solution-architecture-and-publisher.md) — an existing precedent distinguishing Tenant 1 & 2 from Tenant 3 at the Dataverse publisher level, for a related but distinct concern
- [Azure DevOps and GitHub single source of truth design](../specs/2026-09-24-azure-devops-github-single-source-of-truth-design.md) — confirmed live, in this session, that the Boards↔GitHub connection is per-repository
- [Tenant 1 Lean Engineering Platform Design](../specs/2026-09-28-tenant-1-lean-engineering-platform-design.md)
- [Connect Azure Boards to GitHub](https://learn.microsoft.com/en-us/azure/devops/boards/github/connect-to-github) — Microsoft's own guidance: "You shouldn't connect a GitHub repository to more than one Azure DevOps organization."
