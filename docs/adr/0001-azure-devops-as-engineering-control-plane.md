# ADR-0001: Azure DevOps as the Engineering Control Plane, GitHub as the Digital Factory

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

Caldova HR Frontier must be built by an **external GitHub identity** (`github.com/urruegg`, a personal account outside the demo tenant) using GitHub Copilot CLI, while delivery is proposed to be planned and governed inside the tenant's Azure DevOps organisation (`dev.azure.com/caldova25156897`).

That leaves an unavoidable question: where does the backlog live, and where does the code live?

Three options were considered.

### Option A — Everything in Azure DevOps

Azure Repos for source, Azure Boards for work, Azure Pipelines for delivery.

- Single system, single permission model.
- But: GitHub Copilot CLI, Copilot cloud agent, `copilot-instructions.md`, `AGENTS.md`, rulesets, secret scanning and push protection are GitHub features. Building with Copilot CLI against Azure Repos loses the repository-native Copilot surface that the showcase is partly meant to demonstrate.
- Azure DevOps **public projects are retired and can no longer be created**, so the "build in the open" objective is not achievable there.

### Option B — Everything in GitHub

GitHub Issues and GitHub Projects for work, GitHub for source and Actions.

- Simplest for the external build identity.
- But: **issue types are an organisation-level feature** and `urruegg` is a personal account, so work item typing degrades to labels. There are no iterations, no delivery plans, and no approval checks that pipeline authors provably cannot modify.
- It also removes Azure DevOps from a showcase whose stated scope explicitly includes it.

### Option C — Azure Boards plans, GitHub builds

Azure Boards owns the backlog, iterations, delivery plans and deployment approvals. GitHub owns source, pull requests, Actions, releases and agent definitions. The two are joined by `AB#<work-item-id>` references.

---

## Proposed Decision

**The proposed baseline adopts Option C.**

- **Azure DevOps** is the Engineering Control Plane: Epics, Features, User Stories, Tasks, Bugs, iterations, Delivery Plans, and the PROD approval gate.
- **GitHub** is the Digital Factory: the public repository, pull requests, GitHub Actions, releases, `.github/agents/`, Copilot instructions and Copilot CLI.
- **Azure Boards is the proposed single backlog.** GitHub Projects is not part of the proposed operating model. GitHub Issues exist only as an intake funnel that is triaged into Azure Boards.
- Linkage is the `AB#` convention, to be enforced mechanically by a ruleset commit-message pattern and by the pull request template.
- The connection uses the **Azure Boards GitHub App**, not a personal access token.

---

## Rationale

1. **It is the pattern Microsoft's integration is built for.** *"You can use GitHub for software development while using Azure Boards to plan and track your work."*
2. **The GitHub App is the only viable connection type.** PAT connections — including fine-grained PATs — support neither pull request status checks nor GitHub Copilot integration with Azure Boards.
3. **Approval integrity.** Azure DevOps approvals and checks *"aren't defined in the yaml file. Users modifying the pipeline yaml file can't modify the checks performed before start of a stage."* That property is worth one gate on its own.
4. **The personal-account constraint is real.** Issue types, organisation rulesets and organisation secrets are unavailable to `urruegg`. Azure Boards supplies the structured work model that GitHub cannot here.
5. **Public build, private governance.** The repository is public so the showcase is reproducible; the Azure DevOps project is private, which is now the only option anyway.

---

## Consequences

### Positive

- Structured backlog, iterations and delivery plans without giving up GitHub's Copilot surface.
- Traceability from work item → branch → commit → pull request → merge commit → build → release is intended to be produced automatically by the `AB#` convention.
- Two different classes of approval gate are demonstrated: GitHub Environments for TEST, Azure DevOps Environment checks for PROD.

### Negative

- **Two systems to learn.** Contributors must know that work is tracked in one place and built in another.
- **No bidirectional synchronisation.** The integration provides linking plus a one-way state transition on merge. Nothing else syncs. This is why GitHub Projects is disabled — a second board would drift immediately.
- **You cannot query for work items that have GitHub links.** The available proxy is `External Link Count > 0`.
- **State transitions only fire on merge to the default branch**, which must be explained or it looks broken.
- **One organisation only.** The repository can be connected to exactly one Azure DevOps organisation and project.

### Mitigations

- The proposed commit-message ruleset rejects a push without `AB#`, so the convention cannot silently lapse.
- The pull request template requires the work item reference as its first field.
- `.github/copilot-instructions.md` and `AGENTS.md` state the proposed rule so that agent-produced commits comply.
- The proposed "unlinked work" board query is built on `External Link Count = 0`.

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
