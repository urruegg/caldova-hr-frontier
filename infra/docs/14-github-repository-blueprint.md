# GitHub Repository Blueprint

| Field | Value |
|---|---|
| **Version** | 2.1 |
| **Date** | 2026-09-30 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Infrastructure |
| **References** | [Tenant 1 Lean Engineering Platform Design](../../docs/specs/2026-09-28-tenant-1-lean-engineering-platform-design.md), [Tenant 1 Lean Platform Runbook](24-tenant-1-lean-platform-runbook.md), [ADR-0012](../../docs/adr/0012-per-tenant-github-repository-and-account-topology.md) |

This Proposed Baseline defines the lean Tenant 1 repository target. It does not claim that a setting, ruleset, check, app connection, or Azure Boards transition is active until current read-back proves it.

## One Product-Source Repository

`urruegg/caldova-hr-frontier` is Tenant 1's sole product-source repository. Tenant 2 and Tenant 3 use separate repository and Azure DevOps project boundaries when their onboarding is separately approved.

Tenant 1 validation uses the explicit ignored local configuration path. There is no active private configuration repository dependency, bootstrap GitHub Environment, workload federation, or workflow-hosted tenant discovery. The approved deletion of the tracked Tenant 1 transition files is committed; they are absent and must not become validation or recovery inputs.

## Repository Ownership

| Path | Ownership |
|---|---|
| `.github/` | Repository governance, agent customization, issue forms, pull-request template, and the single validation workflow |
| `docs/` | Cross-cutting specifications, plans, decisions, policies, and reviews |
| `infra/` | Infrastructure documentation, source, tests, and attended local validation |
| `hr/` | HR domain documentation and solution source |
| `data/` | Synthetic-data guidance and reviewed synthetic assets |

Private configuration, raw discovery, generated parameters, access evidence, and raw `what-if` output stay outside Git.

## Lean `main` Governance

The approved minimum target is:

- every change to `main` uses a pull request;
- required approving reviews remain zero while there is only one eligible maintainer;
- CODEOWNERS remains an ownership map, not a required solo-owner review gate;
- every review conversation is resolved;
- `Repository setup validation` is the sole required status check;
- force pushes and branch deletion are blocked;
- squash is the only enabled merge method;
- merged branches are deleted automatically;
- GitHub Projects is disabled; and
- Dependabot security updates are enabled.

When a second eligible maintainer is added, requiring one approval and CODEOWNERS review is a separate reviewed governance change.

## Validation Workflow Boundary

Repository setup validation runs repository-owned tests, infrastructure tests, HR tests, safety checks, maintained Bicep compilation, and whitespace validation. It does not authenticate to Tenant 1, retrieve private configuration, run discovery, create trust, alter roles, call Azure `what-if`, or create a deployment.

No separate traceability workflow is required. The pull-request template requires an Azure Boards reference and human review confirms the final proof uses `Fixes AB#<positive-integer>`.

## Public Repository Safety

The repository never contains:

- credentials, tokens, keys, certificates, connection strings, or authentication headers;
- Tenant 1 local configuration or its backup;
- raw discovery, access evidence, or `what-if` output;
- unrestricted object or membership lists;
- personal or special-category HR data;
- generated environment-specific Power Platform values; or
- temporary authorization state.

Secret scanning and push protection supplement but do not replace review. Their active status must be read back rather than inferred.

## GitHub and Azure Boards

GitHub is the product-source and pull-request plane. Azure Boards is the single backlog. The Azure Boards GitHub App, not a workflow credential, proves the real link and state transition.

Tenant 1 keeps the Basic process and native `Epic -> Issue -> Task` hierarchy. One durable Basic Issue is used for the final `Fixes AB#` proof. The current lean sprint does not create a second team, a second area, six iterations, or a parallel GitHub Projects backlog.

## Deferred Controls

A bootstrap Environment, workload federation, private configuration repository, required delivery template, Azure Pipeline, or separate delivery identity may return only through a new reviewed design. Historical documents and dormant code are not active prerequisites.

## Verification Contract

Current read-back must compare the exact ruleset and repository settings with the lean target and prove:

1. only `Repository setup validation` is required;
2. solo-owner review settings do not deadlock merge;
3. squash-only merge and branch deletion settings are active;
4. GitHub Projects remains disabled;
5. the Boards connection and one real `Fixes AB#` transition work; and
6. no private Tenant 1 artifact or dormant trust path is an active dependency.
