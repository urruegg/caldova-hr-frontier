# Delegated Agent Workflow

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-17 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Repository |
| **References** | [Approved Architecture Baseline Intake Design](../../docs/specs/2026-09-17-architecture-baseline-intake-design.md), [Source Inventory](../../docs/reviews/2026-09-17-architecture-baseline-source-inventory.json) |

## Purpose

Define the proposed work-item-to-pull-request path for agent-assisted delivery in this repository.

This baseline describes a future operating contract. It does not assert that Azure Boards work items, product agents, delivery pipelines, branch controls, or cloud governance controls already exist. Until a named control is implemented and verified, use the approved repository specification, plan, issue, or pull request as the traceability record and state the limitation explicitly.

## Before Intake: Idea to Plan

The proposed lifecycle keeps one continuous delivery record from idea through completion. When Azure Boards is explicitly adopted for a slice, that record is an Azure Boards work item created at the Idea stage and retained throughout the lifecycle. Never invent a work-item identifier or claim a tag transition that has not occurred.

1. **Idea**: capture the problem, affected journey stage, initial data classification, and accountable owner.
2. **Business specification**: document the intended outcome, acceptance criteria, and non-goals. A human Product Owner approves the business specification before delivery planning. The proposed Azure Boards transition is `stage:spec-approved`.
3. **Solution design**: document architecture, security, data, integration, and operational tradeoffs. A human Technical Owner approves the design. Record a repository ADR when the decision needs a durable rationale. The proposed Azure Boards transition is `stage:design-approved`.
4. **Governance classification**: classify information as `data:public`, `data:internal`, `data:personal`, or `data:sensitive`, and identify required redaction before material reaches this public repository. Personal or sensitive content requires recorded approval from the human Governance Owner. Product approval cannot replace this gate.
5. **Plan**: divide the approved design into reviewable slices with acceptance criteria, explicit ownership, and allowed paths. The proposed Azure Boards transition is `stage:plan-ready`.

No personal or special-category data, secret, credential, or private tenant value may be placed in a public tracking record, prompt, branch, commit, pull request, log, or evidence file.

## End-to-End Flow

### 1. Intake

- Select the approved delivery record and cite its real identifier when one exists.
- Confirm acceptance criteria, non-goals, allowed paths, and accountable human owners.
- Confirm the data classification and whether the Governance Owner gate applies.
- Confirm that the requested action is delegable under [Non-Delegable Work](./NON_DELEGABLE_WORK.md).

### 2. Context Alignment

- Read the root [repository guide](../../README.md), [agent instructions](../../AGENTS.md), and scoped governing artifacts first.
- Read cross-cutting documentation when governance, identity, data, architecture, or application lifecycle management is affected.
- Treat absent files, services, agents, and controls as absent. A proposed baseline is not evidence of implementation.

### 3. Branching

- Create a dedicated branch from the reviewed base and use one concern per branch.
- Work in an isolated worktree when the execution environment supports it.
- Never use the same branch for concurrent local and hosted-agent work.
- Never delete or force-push a branch autonomously.

### 4. Implementation

- Apply the smallest edit that satisfies the approved slice.
- Follow current repository patterns before introducing a new abstraction.
- Avoid unrelated changes and stop rather than widening scope without approval.
- For testable behavior, demonstrate a failing check before implementation and a passing check afterward. For low-code artifacts, write and fail the acceptance check first.
- Agents may prepare drafts, plans, commands, and evidence. They may not perform human-only, destructive, administrative, production, identity, secret, or employment-affecting actions.

### 5. Validation

- Run every build, lint, test, policy, security, and solution check required by the affected area.
- Record command-level evidence, including the command, relevant output, and exit result.
- Never disable, weaken, bypass, or skip a failed validator to make a change appear ready.
- Where a change affects a demonstrable journey, exercise the affected step and record the observed result without using personal data.

### 6. Documentation

- Update repository-owned documentation when behavior, contracts, security, architecture, or operations change.
- Record durable design decisions as ADRs in the current repository decision area.
- If documentation does not change, state why in the pull request.
- Follow the [documentation policy](../../docs/README.md), including English prose, UTF-8, current links, and explicit Proposed Baseline status.

### 7. Pull Request Creation

- Use the repository pull request contract when it is present and verified. Until then, record scope, governance, validation evidence, documentation impact, risk, and review focus directly in the pull request description.
- Reference a governing Azure Boards item only when that item actually exists. Put the real `AB#` reference in the description rather than inventing one in the title.
- Link parent and child delivery records when those relationships exist.
- A GitHub issue may be used as an execution record, but it does not replace the approved governing artifact or human gates.

### 8. Review Handoff

- State the review focus and residual risk plainly.
- Resolve review comments and rerun affected checks.
- Require human review for governance, employment, production, destructive, identity, secret, and administrative decisions.

### 9. Merge and Closure

- Merge only after the checks and approvals required by the current repository policy are implemented, present, and passing.
- Use a closing keyword for an external work item only when its acceptance criteria have been verified and the intended transition is understood.
- Update and close real linked records after merge, then add the verified evidence summary.
- Do not claim that branch protection, CODEOWNERS, pipelines, or approval gates enforced a change unless their configuration was read back or otherwise verified.

## Failure Handling

### Scope Breach Risk

Stop and request scope confirmation. Do not widen scope to finish the job.

### Validation Failure

Fix the root cause or document the blocker with evidence. Never disable, bypass, or skip a check.

### Policy Block

Do not bypass review, checks, branch protection, or another governance control without explicit owner approval recorded before the action. Use the [Break-Glass Procedure](./BREAK_GLASS.md) only when its allowed-use threshold is met.

### Missing Environment Dependency

Document the limitation and propose the lowest-risk fallback. Do not represent a local workaround as completion of a missing pipeline or cloud control.

### Governance Uncertainty

Stop when information might contain personal or sensitive data, when a knowledge source might be unapproved, or when an action might affect employment. Escalate to the Governance Owner; uncertainty is not permission to proceed.

### Unsupported Automation

Stop when a service or action cannot be automated safely or when the required tool, permission, or human gate is unavailable. Prepare the evidence and attended procedure instead of simulating success.

## Escalation Routing

| Situation | Accountable human |
|---|---|
| Unclear requirements, priority conflict, scope change | Product Owner |
| Personal or special-category data, external publication, knowledge-source change, agent data scope | Governance Owner |
| Architecture decision, security impact, integration risk, data-model change, automation-permission change | Technical Owner |
| Tenant, environment, data-loss-prevention, identity, or platform configuration | Platform Owner |
| Employment-affecting proposal | Refuse, then escalate to the accountable manager or HR |
| Outcome acceptance | Management or the named outcome owner |

The named human must be identified in the delivery record before the corresponding gate is used. An agent does not assume or impersonate an owner.

## Rollback Guidance

1. Prefer a reviewed revert or the current repository rollback procedure.
2. For managed solution deployments, propose a corrected managed solution rather than a direct target-environment edit that creates unmanaged drift.
3. Obtain and record explicit owner approval before any governance, identity, tenant, bootstrap, destructive, or administrative rollback action.
4. If personal data or a secret reaches the public repository, treat it as an incident. Notify the Governance Owner, rotate exposed credentials through an authorized human process, preserve the audit record, and understand that a revert does not undo publication.
5. Re-run affected validation after the approved rollback and record the result.
