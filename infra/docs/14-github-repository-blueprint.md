# GitHub Repository Blueprint

| Field | Value |
|---|---|
| **Version** | 1.1 |
| **Date** | 2026-09-27 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Infrastructure |
| **References** | [Approved Intake Design](../../docs/specs/2026-09-17-architecture-baseline-intake-design.md), [Source Inventory](../../docs/reviews/2026-09-17-architecture-baseline-source-inventory.json), [ADR-0012](../../docs/adr/0012-per-tenant-github-repository-and-account-topology.md) |

This source-derived Proposed Baseline describes intended GitHub repository architecture and governance. It does not prove that any ruleset, branch protection, Environment, reviewer, variable, workflow, check, app registration, or service integration is currently configured.

## Revision Note (v1.1)

This section previously described one shared repository serving all three tenants. [ADR-0012](../../docs/adr/0012-per-tenant-github-repository-and-account-topology.md) replaced that with one repository per tenant, after confirming live that the Azure Boards GitHub App enforces a real platform constraint — one repository connects to exactly one Azure DevOps organization at a time — which the shared-repository design silently violated for any second tenant. This document is rewritten below to match; see ADR-0012 for the full rationale and the alternatives considered.

## One Repository Per Tenant

Caldova HR Frontier is Tenant 1's dedicated repository — `urruegg/caldova-hr-frontier`, this repository. Tenant 2 and Tenant 3 (Georg Fischer) each receive their own dedicated repository, seeded from this one as a one-time copy, never a live fork or automatic sync. See [ADR-0012](../../docs/adr/0012-per-tenant-github-repository-and-account-topology.md) for the account-type decision per tenant and the seeding mechanism, and the [Customer Repository Export and Handover design](../../docs/specs/2026-09-27-customer-repository-export-and-handover-design.md) for the runbooks that carry this out.

A workflow run in any tenant's repository selects that repository's own single tenant and binds to that tenant's own `bootstrap-${tenantAlias}` Environment. Repository compromise risk is constrained through reviewed manifests, Environment approval, exact OIDC subjects, per-tenant applications, and evidence gates — the same controls as before, now paired with genuine repository isolation rather than shared-repository discipline standing in for it.

## Repository Ownership

| Path | Ownership |
|---|---|
| `.github/` | Repository governance, agent customization, issue forms, and later workflow definitions |
| `docs/` | Cross-cutting specifications, plans, decisions, policies, and reviews |
| `infra/` | Infrastructure documentation and later tenant bootstrap source |
| `hr/` | HR domain documentation and later solution source |
| `data/` | Synthetic-data guidance and later reviewed synthetic assets |

The current repository already contains reviewed Phase 1 and Phase 2 documentation. Task 1 adds only the Infrastructure documentation surface. A path mentioned for a later task is not evidence that its file or runtime control exists now.

## Tenant-Specific Environments

The proposed bootstrap Environment name is derived without operator choice:

```text
bootstrap-${tenantAlias}
```

Tenant 1 uses `bootstrap-caldova25156897`. Each Environment is intended to:

- allow deployments from `main` only;
- name the reviewed tenant administrator's GitHub identity as required reviewer;
- permit the approved pilot self-review exception;
- expose only `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, and `AZURE_SUBSCRIPTION_ID` as non-secret variables;
- bind OIDC to the exact immutable repository and Environment subject.

The manifest carries the GitHub owner and repository names plus their immutable numeric IDs. Before a federated credential is created, read-only API evidence must confirm that immutable subjects are enabled and that GitHub's `sub_claim_prefix` exactly matches those four fields. Tenant 1's verified prefix is `repo:urruegg@46865858/caldova-hr-frontier@1371297722`; the Environment context is appended to that prefix.

Task 1 creates none of these Environments or variables. Tenant 2 and Tenant 3 Environments are absent until their attended onboarding is approved.

GitHub documents Environment protection and secrets in [Managing environments for deployment](https://docs.github.com/en/actions/deployment/targeting-different-environments/managing-environments-for-deployment).

## Proposed `main` Governance

A later reviewed ruleset is intended to require:

- pull requests for changes to `main`;
- one approval and CODEOWNERS review;
- dismissal of stale approvals;
- resolved review conversations;
- the repository validator status check;
- blocked force pushes and branch deletion;
- administrator bypass through pull request only, with a separate documented break-glass process.

The ruleset is activated only after implementation reaches `main`, repository validation succeeds on `main`, Tenant 1 `what-if` succeeds within boundary, and temporary Azure roles are confirmed absent. Task 1 does not claim that any branch rule is active.

GitHub ruleset behavior is described in [About rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets). CODEOWNERS syntax and branch semantics are described in [About code owners](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners).

## Public Repository Safety

The repository contains reproducible source and reviewed non-secret metadata. It never contains:

- passwords, tokens, private keys, certificates, connection strings, or authentication headers;
- raw service responses or unrestricted membership lists;
- personal or special-category HR data;
- environment-specific Power Platform values or ZIP exports;
- temporary role-assignment state or raw `what-if` output.

Secret scanning and push protection are useful controls for public repositories, but their active status must be verified rather than inferred. They do not replace human review for personal data. See [About secret scanning](https://docs.github.com/en/code-security/secret-scanning/introduction/about-secret-scanning) and [About push protection](https://docs.github.com/en/code-security/secret-scanning/protecting-pushes-with-secret-scanning).

## Workflow Boundary

Later manual workflows may perform read-only discovery and subscription `what-if` through secretless OIDC. They must use minimal permissions, select one tenant, avoid automatic commits or pushes, and publish only normalized redacted evidence.

No bootstrap, discovery, Power Platform ALM, or deployment workflow is added in Task 1. No workflow in this sprint may deploy the proposed Azure platform resources.

## GitHub and Azure Boards

GitHub is the source and pull-request plane. Azure Boards is the proposed single backlog after its existing project and GitHub App connection are discovered and verified. GitHub Issues remain an intake surface, not a second backlog. The initial Azure Boards GitHub App authorization is attended and is not performed by Task 1.

## Verification Contract

A later governance review must read back and compare every ruleset and Environment field with reviewed desired state. It must also confirm the exact immutable OIDC subject and repository prefix, three allowed variable names, branch restriction, reviewer identity, self-review setting, and successful validator check. Until that evidence exists, these controls remain proposed.
