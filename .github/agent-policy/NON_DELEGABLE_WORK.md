# Non-Delegable Work

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-17 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Repository |
| **References** | [Approved Architecture Baseline Intake Design](../../docs/specs/2026-09-17-architecture-baseline-intake-design.md), [Source Inventory](../../docs/reviews/2026-09-17-architecture-baseline-source-inventory.json) |

These are actions an agent must never perform autonomously. Each action requires an identified human acting deliberately within current authority, with the decision and evidence recorded in the governing artifact or pull request.

An agent that encounters one of these actions stops and escalates. It may prepare a draft, plan, exact command, risk assessment, or checklist for an authorized human, but it may not execute the action, grant its own approval, or treat silence as approval.

## 1. Employment-Affecting Decisions - Absolute

No agent may make, communicate, imply, recommend, rank, or encode a decision about an individual's employment. This includes:

- hiring, rejection, or offer decisions;
- performance assessment, rating, or ranking;
- compensation, bonus, or equity decisions;
- promotion, demotion, or role changes;
- disciplinary action, warnings, or grievance outcomes;
- termination, redundancy selection, or contract non-renewal;
- any recommendation that would materially determine one of these outcomes.

This boundary does not depend on confidence or workflow. There is no approval that makes an employment decision delegable to an agent. An agent asked to perform one refuses and routes the request to the accountable manager or HR.

An agent may summarize an approved policy, explain a process, generate a neutral checklist, draft a communication template for human review, or surface an aggregate pattern that meets the approved reporting threshold and contains no personal data.

## 2. Tenant and Platform Configuration

Only a specifically authorized human administrator may approve and perform these actions through an attended, recorded process:

- change a Microsoft 365, Microsoft Entra, Power Platform, Azure, Azure DevOps, or GitHub administrative setting;
- create, delete, reset, restore, copy, or modify an environment;
- change a data-loss-prevention or data policy;
- enable or modify managed-environment settings or environment-group rules;
- change tenant settings, including agent authoring and publication controls;
- create or modify security groups, licenses, administrative roles, or role assignments;
- elevate a human or automation identity to an administrative role;
- create, modify, or bypass a repository ruleset, branch protection, required review, or validation control.

This proposed list does not assert that any tenant, environment, administrator, platform control, or administrative center is currently configured.

## 3. Identity and Secrets

An agent must not autonomously:

- create, modify, or delete an app registration, service principal, managed identity, or federated credential;
- grant, widen, or elevate a permission for a human or automation identity;
- rotate, issue, reveal, store, or revoke a secret, password, key, token, or certificate;
- add an identity to a delivery platform or grant organization-level administration;
- change Conditional Access, multifactor authentication, emergency access, or break-glass configuration;
- place a secret or private tenant value in source, prompts, logs, evidence, issues, commits, or pull requests.

Agents may draft an attended command and validation plan. An authorized human must approve the exact scope before execution and verify cleanup afterward.

## 4. Production and Destructive Operations

The following actions are human-only and require explicit recorded approval:

- deploy to production; where an approved pipeline exists, production deployment is pipeline-only and uses its recorded gate;
- make a direct change in a test or production environment, including a small or emergency fix;
- delete a managed solution, data table, column, record set, repository, branch, environment, identity, or cloud resource;
- force-push history, delete a protected ref, or bypass branch protection;
- reset, restore, or copy an environment;
- approve a deployment, publication, merge, or release gate;
- run a destructive command or API call, even when rollback appears possible.

If the required pipeline, gate, backup, or approval control does not exist, the action remains blocked. Its absence does not authorize a manual substitute.

## 5. Agent Publication

No agent becomes available to an employee without a recorded publication review signed by the named Agent Owner and Governance Owner. Human-only actions include:

- publishing or updating an employee-facing agent;
- adding, removing, or changing a knowledge source;
- widening an agent's data scope, connector access, tools, or permissions;
- changing an escalation path, refusal behavior, or employment-decision boundary;
- approving an agent in a registry or catalogue.

This section defines the proposed gate; it does not claim an employee-facing agent, registry, release pipeline, or publication control currently exists.

## 6. Governance Decisions

An agent must not autonomously:

- classify content as public when it might be personal or sensitive;
- approve personal or special-category data for an engineering system or public repository;
- decide that a redaction is sufficient;
- waive, defer, override, or bypass a governance, security, review, or validation control;
- approve the use of an unverified knowledge source;
- conceal an incident, failed check, unsupported action, or control gap.

When classification or redaction is uncertain, the agent stops and escalates to the Governance Owner. No personal data or secret may be retained merely to support an audit or metric.

## 7. External Communication

Agents draft; an accountable human reviews and sends. An agent must not autonomously:

- send a communication to an employee, manager, candidate, customer, or external party;
- post to a collaboration channel on behalf of the organization;
- publish a release note, outcome report, status update, policy, or employment-related message to a human audience;
- impersonate a human approver or imply that a human reviewed content when no review occurred.

## When an Agent Encounters Non-Delegable Work

1. **Stop.** Do not attempt a partial, indirect, automatic, or supposedly safer form of the action.
2. State which boundary applies and why.
3. Produce only the artifact an authorized human needs to decide or act, without personal data or secrets.
4. Escalate to the accountable human named in the [Delegated Agent Workflow](./AGENT_WORKFLOW.md#escalation-routing).
5. Record the stop, decision, approval, execution owner, and validation evidence in the real governing artifact.
6. Never skip required validation or perform an administrative or destructive step automatically after approval is requested.

Stopping is a successful outcome. A documented block is preferable to unsupported autonomy, an invented approval, or an irreversible action.
