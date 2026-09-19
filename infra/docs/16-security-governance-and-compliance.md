# Security, Governance and Compliance

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-17 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Infrastructure |
| **References** | [Approved Intake Design](../../docs/specs/2026-09-17-architecture-baseline-intake-design.md), [Source Inventory](../../docs/reviews/2026-09-17-architecture-baseline-source-inventory.json) |

This source-derived Proposed Baseline describes intended security, governance, and compliance controls. It does not prove that any policy, role, audit setting, DLP rule, Managed Environment, security group, ruleset, scanning feature, identity, or service is currently configured.

## Control Principles

1. Evidence precedes intent, and reviewed intent precedes mutation.
2. Absence, lack of authorization, service failure, and ambiguity remain distinct states.
3. Human approval is required for trust creation, privilege changes, Power Platform access changes, PROD release, and destructive cleanup.
4. Secrets and personal HR data never enter repository source or normalized evidence.
5. Every later mutation is read back and compared with reviewed desired state.
6. A failed validation is repaired at its cause; permissions and scope are not broadened to bypass it.

The cross-cutting human approval and data rules are defined in [HITL Governance](../../docs/operating-model/04-hitl-governance.md).

## Data Classification and Repository Safety

The public repository may contain reviewed non-secret identifiers such as tenant IDs, subscription IDs, stable object IDs, project names, service URLs, resource names, and evidence hashes. It must not contain:

- access or refresh tokens;
- passwords, private keys, authentication headers, or recovery material;
- connection strings or signed URLs;
- unrestricted access-control membership;
- real employee identities or HR records;
- raw API responses;
- environment-specific Power Platform solution values.

Secret scanning and push protection can detect many credential patterns, but human review remains the primary control for personal data. Their configuration must be verified through GitHub evidence before being described as active.

## Proposed Power Platform Data Policy

A future tenant-level data policy may group approved Microsoft business connectors separately from non-business connectors and block unapproved consumer, unauthenticated, public-website, arbitrary HTTP, or uncontrolled channel paths. Endpoint filtering may further constrain approved SharePoint locations.

Microsoft describes design-time and runtime policy enforcement in [Data loss prevention policies](https://learn.microsoft.com/en-us/power-platform/admin/wp-data-loss-prevention) and Copilot Studio controls in [Data policies for agents](https://learn.microsoft.com/en-us/microsoft-copilot-studio/admin-data-loss-prevention).

Task 1 does not create a data policy, assign a connector group, enable tenant isolation, or change an environment.

## Proposed Environment Controls

TEST and PROD may later be reviewed for:

- Managed Environment status and licensing;
- solution-checker enforcement;
- blocking unmanaged customizations;
- sharing controls;
- usage insights and backup retention;
- explicit environment security groups;
- approved application users and minimum roles.

An environment group rule can make settings centrally controlled, but its existence and effective values require current API evidence. See [Managed Environments overview](https://learn.microsoft.com/en-us/power-platform/admin/managed-environment-overview).

## Dataverse Security Design

Future HR solution security uses cumulative roles, row ownership or hierarchy where justified, and column security for sensitive fields. Column security must be tested with non-admin personas because System Administrator bypasses it. Microsoft documents these constraints in [Security roles and privileges](https://learn.microsoft.com/en-us/power-platform/admin/security-roles-privileges), [Hierarchy security](https://learn.microsoft.com/en-us/power-platform/admin/hierarchy-security), and [Column-level security](https://learn.microsoft.com/en-us/power-platform/admin/field-level-security).

No Dataverse table, role, profile, hierarchy, business unit, or record is created in Task 1.

## Identity and Privilege Controls

The bootstrap identity is one dedicated single-tenant application and service principal per independent tenant. It authenticates through the exact tenant-specific GitHub Environment OIDC subject and carries no stored credential.

Managed identities are reserved for future Azure-hosted workloads. Temporary subscription roles are time-bound, recorded by exact assignment ID, deleted only after explicit approval, and verified absent. A cleanup failure fails the run.

No app registration, service principal, federated credential, role definition, role assignment, consent, or Power Platform application user is created in Task 1.

## Audit and Monitoring Proposals

A later implementation may use Azure Activity Log diagnostics, Power Platform activity logging, Purview audit, GitHub audit evidence, and normalized bootstrap results. Platform coverage and latency must be tested rather than assumed. Power Platform activity logging is described in [Activity logging overview](https://learn.microsoft.com/en-us/power-platform/admin/activity-logging-auditing/activity-logs-overview).

The proposed subscription Bicep may show one Log Analytics workspace and subscription Activity Log diagnostic setting in `what-if`. Task 1 does not deploy either resource, and this sprint never executes a platform deployment.

## Compliance Evidence

A later control review must record:

- the reviewed desired-state commit;
- normalized discovery run ID, collection time, stable IDs, and service status;
- approval records for every live mutation;
- OIDC issuer, audience, subject, tenant, subscription, and client read-back;
- Bicep build result and bounded subscription `what-if` output;
- exact temporary role-assignment cleanup evidence;
- GitHub ruleset and Environment API read-back;
- validation output showing repository contracts pass.

Documentation alone is not compliance evidence. Until each item is observed and reviewed, it remains proposed.

## Task 1 Boundary

Task 1 changes repository documentation only. It performs no cloud login, API mutation, policy update, role change, deployment, solution import, or governance activation.
