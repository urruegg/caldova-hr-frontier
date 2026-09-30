# ADR-0001: Azure DevOps as the Engineering Control Plane, GitHub as the Digital Factory

| Field | Value |
|---|---|
| **Version** | 3.0 |
| **Date** | 2026-09-28 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Approved |
| **Scope** | Cross-cutting (all solution domains) |
| **References** | [Approved Intake Design](../specs/2026-09-17-architecture-baseline-intake-design.md), [Tenant 1 Lean Engineering Platform Design](../specs/2026-09-28-tenant-1-lean-engineering-platform-design.md), [Source Inventory](../reviews/2026-09-17-architecture-baseline-source-inventory.json), [ADR-0012](0012-per-tenant-github-repository-and-account-topology.md) |

## Attended Decision

Approved on 2026-09-28 for **Option A — Lean single-tenant platform**, as defined by
the [Tenant 1 Lean Engineering Platform Design](../specs/2026-09-28-tenant-1-lean-engineering-platform-design.md).
The lean design supersedes the broader remediation topology. This ADR approves a
target and does not authorize a live service mutation.

## Revision Note (v3.0)

Version 3.0 records the approved lean target: GitHub remains the sole product-source
and pull-request authority, Azure Boards remains the single delivery backlog on the
built-in Basic process, and Azure Pipelines is future delivery work rather than a
current-sprint dependency.

## Context

Caldova HR Frontier must be built by an **external GitHub identity** (`github.com/urruegg`, a personal account outside the demo tenant) using GitHub Copilot CLI, while delivery is planned and governed inside the tenant's Azure DevOps organisation (`dev.azure.com/caldova25156897`).

That leaves an unavoidable question: where does the backlog live, and where does the code live?

Three options were considered.

### Historical alternative — Everything in Azure DevOps

Azure Repos for source, Azure Boards for work, Azure Pipelines for delivery.

- Single system, single permission model.
- But: GitHub Copilot CLI, Copilot cloud agent, `copilot-instructions.md`, `AGENTS.md`, rulesets, secret scanning and push protection are GitHub features. Building with Copilot CLI against Azure Repos loses the repository-native Copilot surface that the showcase is partly meant to demonstrate.
- Azure DevOps **public projects are retired and can no longer be created**, so the "build in the open" objective is not achievable there.

### Historical alternative — Everything in GitHub

GitHub Issues and GitHub Projects for work, GitHub for source and Actions.

- Simplest for the external build identity.
- But: **issue types are an organisation-level feature** and `urruegg` is a personal account, so work item typing degrades to labels. There are no iterations, no delivery plans, and no approval checks that pipeline authors provably cannot modify.
- It also removes Azure DevOps from a showcase whose stated scope explicitly includes it.

### Historical alternative — Azure Boards plans, GitHub hosts source, Azure Pipelines delivers

Azure Boards owns the backlog, iterations, delivery plans and deployment approvals. GitHub owns product source, pull requests, and agent definitions. GitHub Actions owns repository validation, while Azure Pipelines owns HR solution CI/CD and controlled TEST-to-PROD delivery. The systems are joined by `AB#<work-item-id>` references.

---

## Decision

GitHub is the sole product-source and pull-request authority. Azure Boards is the
single delivery backlog and remains on the built-in Basic process. Repository
validation runs in GitHub Actions. A future Azure Pipeline connects directly to GitHub
and will consume this repository for HR solution CI/CD; no Azure Pipeline is created
this sprint.

Tenant 1 private configuration is an ignored local file with an encrypted,
restore-tested backup outside Git. A private Azure Repo, OIDC bootstrap,
`bootstrap-tenant1` Environment, cloud workflow retrieval, and Basic-to-Agile
conversion are not current targets.

The Azure Boards GitHub App supplies native work-item linkage. The final proof uses a
real Basic Issue and the literal `Fixes AB#<id>` convention. GitHub Projects is not
part of the operating model.

---

## Rationale

1. **It matches Microsoft's supported integration.** GitHub supplies source and pull requests while Azure Boards plans and tracks work.
2. **It keeps one source and one backlog.** The GitHub repository and the Basic-process backlog have distinct, reviewable responsibilities without a mirror or second board.
3. **It is proportional to current need.** Repository validation and one real traceability transaction establish a usable foundation without prematurely creating delivery infrastructure.
4. **It preserves the future path.** Azure Pipelines can consume GitHub directly when HR solution CI/CD is implemented.

---

## Consequences

### Positive

- A structured Basic backlog without giving up GitHub's Copilot surface.
- Native work-item, branch, commit, and pull-request traceability through the Azure Boards GitHub App.
- A narrow current sprint with no claim that delivery infrastructure already exists.

### Negative

- **Two systems to learn.** Contributors must know that work is tracked in Azure Boards and source is governed in GitHub.
- **No bidirectional synchronization.** The integration links work and source; it does not create another backlog or source replica.
- **Delivery remains deferred.** The repository does not yet provide Azure Pipeline or Power Platform deployment evidence.

### Mitigations

- The pull-request template requires an Azure Boards work-item reference.
- The final proof reads back the real GitHub link and intended Basic Issue transition.
- `Repository setup validation` is the sole required status check.
- Under the current solo-owner profile, required approvals are zero and CODEOWNERS review is not required; both are revisited when a second eligible maintainer exists.

---

## Notes on Evidence

Microsoft endorses this split **implicitly** through the Azure Boards + GitHub integration documentation. There is **no prescriptive Microsoft page recommending it over the alternatives**, and the "Hosting Git repositories" guidance page is thin and dated. This ADR therefore records an architectural judgement for this showcase — not a quoted Microsoft mandate. Revisit if Microsoft publishes explicit decision guidance.

---

## References

- [Azure Boards and GitHub integration](https://learn.microsoft.com/en-us/azure/devops/boards/github/?view=azure-devops)
- [Install the Azure Boards app for GitHub](https://learn.microsoft.com/en-us/azure/devops/boards/github/install-github-app?view=azure-devops)
- [Link to work items from GitHub](https://learn.microsoft.com/en-us/azure/devops/boards/github/link-to-from-github?view=azure-devops)
- [Approvals and checks](https://learn.microsoft.com/en-us/azure/devops/pipelines/process/approvals?view=azure-devops)
- [Choose a process](https://learn.microsoft.com/en-us/azure/devops/boards/work-items/guidance/choose-process?view=azure-devops)
- [Approved Intake Design](../specs/2026-09-17-architecture-baseline-intake-design.md); Infrastructure detail enters in Phase 3.
- [Tenant 1 Lean Engineering Platform Design](../specs/2026-09-28-tenant-1-lean-engineering-platform-design.md)
