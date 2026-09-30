# Tenant 1 Lean Engineering Platform Acceptance Review

| Field | Value |
|---|---|
| **Version** | 0.1 |
| **Date** | 2026-09-30 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Draft |
| **Scope** | Tenant 1 lean engineering platform ordered acceptance controls |
| **References** | [Lean Platform Design](../specs/2026-09-28-tenant-1-lean-engineering-platform-design.md), [Implementation Plan](../plans/2026-09-28-tenant-1-lean-engineering-platform-implementation.md), [Operator Runbook](../../infra/docs/24-tenant-1-lean-platform-runbook.md), [Point-in-Time Configuration Review](2026-09-28-tenant-1-engineering-platform-configuration-review.md) |

## Review Boundary

This Draft is the acceptance record for the ordered lean-platform checkpoints. It is not an execution log, approval, or live-state claim. Every control starts as `Not Run` and remains so until an attended operator records current, sanitized read-back from the applicable checkpoint.

The active [point-in-time configuration review](2026-09-28-tenant-1-engineering-platform-configuration-review.md) and its evidence remain unchanged. Historical evidence cannot satisfy a control in this Draft unless the control explicitly requires that same historical point in time.

## Acceptance Controls

| Control | Owner | Required read-back | Sanitized evidence | Outcome | Rollback state |
|---|---|---|---|---|---|
| Clean branch history | Pull-request author | Merge base, reviewed commit range, and repository-safety result show only intended history and changes. | Commit SHAs, changed-path list, and passing safety-test summary; no private content. | Not Run | Stop before merge; repair or recreate the branch from the approved base. |
| One current-main validator | Attended repository owner | The exact merged `main` SHA has one completed successful `validate-repository.yml` run with exactly one successful `Repository setup validation` job. | Merged SHA, workflow run ID, workflow path, conclusion, and unique job name. | Not Run | Do not apply governance; correct source or validator failure and run again on current `main`. |
| Local backup and restore | Attended operator | The ignored `tenant1.local.psd1` backup restores to a separate local path with matching hash and valid schema. | Timestamp, approved local-path labels, hash comparison result, and schema result; no values or raw hashes that expose private content. | Not Run | Restore from the encrypted backup, verify again, and restart discovery. |
| Local discovery | Attended operator | Discovery succeeds for the exact Tenant 1 tenant and subscription with current, unambiguous evidence. | Timestamp, approved stable identifiers, service-status summary, and response hashes only. | Not Run | Preserve local evidence, correct context or access, and rerun discovery; never select Tenant 2. |
| Every maintained Bicep build | Platform engineer | Every maintained Bicep entry point and the selected generated parameter file compile successfully before `what-if`. | Tracked source-path inventory, compiler result, and count; no generated parameters or private values. | Not Run | Correct source or local parameters and rebuild all maintained entry points. |
| Subscription `what-if` | Attended operator | Subscription-scope `az deployment sub what-if` succeeds within the approved boundary and no deployment-create command runs. | Timestamp, subscription and tenant stable identifiers, sanitized change-type summary, and output hash. | Not Run | Stop, preserve local evidence, correct the plan, and rerun preflight before another `what-if`. |
| Attended context and minimum-access preflight/read-back | Attended operator and access owner | The same attended user, tenant, subscription, exact-scope assignment, and exact custom validation role pass before and after `what-if`; no role mutation occurs. | Stable principal/assignment/role identifiers, scope, action-set comparison, and pre/post equality result. | Not Run | Stop on drift; use the separately governed access process, then restart the complete local checkpoint. |
| GitHub settings, ruleset, and Dependabot | Attended repository owner | Exact repository settings, no classic protection, one applicable `main` ruleset, the sole required validator, zero required approvals, no required CODEOWNERS review, and enabled Dependabot security updates read back. | Repository name, stable ruleset ID, governed property summary, required-check name, approval counts, and Dependabot state. | Not Run | Use the script's captured pre-state and reviewed recovery; do not broaden rules or add bypasses. |
| Durable Basic Boards Issue | Azure DevOps project administrator | The Basic process, existing team, project-root area, selected current sprint, and exactly one stable-tagged Issue with a positive ID read back after apply. | Project/team labels, iteration path, positive Issue ID, stable tag, and exact result count; no identity expansion. | Not Run | Stop on ambiguity; preserve the durable Issue and restore only an approved changed sprint date from captured pre-state. |
| Optional empty Azure Repo decision | Azure DevOps project administrator | Fresh exact-ID metadata, refs, and recursive-item reads prove zero size, no default branch, zero refs, and zero items; any deletion also requires separate explicit attended approval and exact-ID `404` read-back. | Stable project/repository IDs and name, four predicate results, decision, and exact post-action status when applicable. | Not Run | Default is preservation. Stop on no approval or indeterminate proof; deletion recovery requires a separately reviewed recreation decision. |
| Tracked Tenant 1 transition-file deletion | Repository owner | Separate approval identifies the exact tracked files and a later diff/read-back proves only those approved paths were deleted. | Approval reference, path-only diff, commit SHA, and repository-safety result; never file contents. | Not Run | Keep both files tracked until approved; revert only the approved deletion commit if rollback is required. |
| Real `Fixes AB#` link and transition | Pull-request author and Azure DevOps project administrator | A real governed pull request contains `Fixes AB#<positive-integer>` for the durable Issue, and the GitHub link plus intended Issue transition read back after merge. | Pull-request number, positive Issue ID, literal reference result, link type, and resulting state. | Not Run | Stop before merge if invalid; after merge preserve the Issue and correct through a new governed transaction. |
| Source-branch deletion | Attended repository owner | The final proof pull request is squash-merged and the exact source branch no longer resolves. | Pull-request number, merge commit SHA, source-branch name, and absence result. | Not Run | Delete the source branch through the governed repository path if automatic deletion failed; never rewrite `main`. |
| Merged-main green state | Attended repository owner | Current `main` equals the final merge commit and its sole `Repository setup validation` job is successful. | `main` SHA, merge commit SHA, workflow run ID, job name, and successful conclusion. | Not Run | Stop acceptance; fix forward through another governed pull request and re-run the final read-back. |

## Explicit Non-Claims

This review does not claim or accept:

- an Azure Pipeline definition, run, service connection, environment, or delivery path;
- a Power Platform deployment or release to DEV, TEST, or PROD;
- an Azure infrastructure deployment; subscription `what-if` is planning evidence only;
- tenant trust activation, OIDC bootstrap, a GitHub bootstrap Environment, or any role mutation; or
- Basic-to-Agile conversion, a second team or area, or generated sprint cadence.

It also does not authorize deletion of the tracked Tenant 1 transition files or the optional empty Azure Repo. Both remain `Not Run`; Azure Repo deletion is an optional, separate destructive checkpoint.

## Completion Rule

Update only controls supported by current sanitized read-back. Leave post-merge or live controls `Not Run` when execution has not occurred. Promote this record from `Draft` only after every required control is supported, every optional control is either supported or explicitly recorded as not exercised, rollback state is known, and the final merged-`main` green state is read back.
