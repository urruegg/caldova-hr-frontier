# Power Platform Environments and ALM

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-17 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Infrastructure |
| **References** | [Approved Intake Design](../../docs/specs/2026-09-17-architecture-baseline-intake-design.md), [Source Inventory](../../docs/reviews/2026-09-17-architecture-baseline-source-inventory.json) |

This source-derived Proposed Baseline describes intended Power Platform architecture and ALM operations. It does not prove that any Power Platform environment, Managed Environment control, data policy, security group, pipeline, application user, publisher, solution, connection, or workload currently exists.

## Stage Model

`DEV`, `TEST`, and `PROD` are Power Platform ALM stages only. They never name Azure infrastructure environments, subscriptions, resource groups, Bicep stages, or deployment rings.

| Stage | Reviewed URL hint | Intended future use | Task 1 evidence |
|---|---|---|---|
| DEV | `https://hrfrontierdev.crm17.dynamics.com/` | Unmanaged authoring and export | Existing candidate; stable environment ID not yet observed |
| TEST | `https://hrfrontiertest.crm17.dynamics.com/` | Managed import and release validation | Existing candidate; stable environment ID not yet observed |
| PROD | `https://hrfrontier.crm17.dynamics.com/` | Approved managed release | Existing candidate; stable environment ID not yet observed |

The URLs are discovery hints. They do not prove environment type, region, state, security-group binding, Managed Environment status, DLP coverage, publisher, application-user access, or installed solutions.

Microsoft recommends a separate test environment before production in [ALM basics](https://learn.microsoft.com/en-us/power-platform/alm/basics-alm). Environment release-station constraints are described in [Environment strategy for ALM](https://learn.microsoft.com/en-us/power-platform/alm/environment-strategy-alm).

## Discovery and Intent Gate

Read-only discovery obtains stable environment IDs and compares each observed URL with the reviewed manifest. A candidate becomes `Existing` only after the ID and URL match current evidence. `Unauthorized`, `Unavailable`, or `Ambiguous` blocks progress.

This sprint does not create a Power Platform environment, data policy, Managed Environment, environment group, pipeline, application user, publisher, connection, solution, or security role. Tenant 2 and Tenant 3 receive no Power Platform changes.

## Proposed Solution Architecture

Future unpacked source is owned by two domain folders:

- Infrastructure solution source under `infra/src/solutions/`;
- HR solution source under `hr/src/solutions/`.

The Infrastructure solution precedes the HR solution in every ALM stage because it owns shared connection references, environment-variable definitions, security roles, and other shared components. No solution payload exists under the Infrastructure domain in Task 1.

The proposed release flow is:

```text
Author unmanaged components in DEV
-> export and unpack into reviewed source
-> validate and build managed artifacts
-> import Infrastructure before HR into TEST
-> obtain release approval
-> import Infrastructure before HR into PROD
```

Managed artifacts are build output and are never committed as source. ZIP exports, environment-specific values, generated output, credentials, and personal data are prohibited under solution-source folders.

Microsoft recommends custom publishers and solution-aware ALM in [Solution concepts](https://learn.microsoft.com/en-us/power-platform/alm/solution-concepts-alm). Publisher prefix and component lineage are one-time design decisions; Task 1 neither selects a new publisher nor claims that the source package's publisher exists in any environment.

## Environment Variables and Connections

Environment-variable definitions belong in the Infrastructure solution. Values are supplied per verified target during a future deployment and do not belong in solution source. Microsoft documents this portability boundary in [Environment variables overview](https://learn.microsoft.com/en-us/power-apps/maker/data-platform/environmentvariables).

Solution-aware flows use connection references rather than direct environment connections. Connection sharing and ownership must be validated for the deployment principal; see [Use connection references in solutions](https://learn.microsoft.com/en-us/power-apps/maker/data-platform/create-connection-reference).

Future configuration may include approved SharePoint locations, Teams channels, stage labels, scheduling values, and feature flags. It must not include access tokens, private keys, connection strings, or personal HR data.

## Managed Environment and Data-Policy Proposals

TEST and PROD may later be assessed for Managed Environment controls, solution-checker enforcement, unmanaged-customization restrictions, sharing limits, usage insights, and backup retention. Those controls require licensing and attended review; none is active merely because this document names it. See [Managed Environments overview](https://learn.microsoft.com/en-us/power-platform/admin/managed-environment-overview) and [Managed Environment licensing](https://learn.microsoft.com/en-us/power-platform/admin/managed-environment-licensing).

A future tenant-level data policy may separate approved business connectors from non-business and blocked connectors. It is not created in this sprint. Data-policy behavior and propagation are described in [Data loss prevention policies](https://learn.microsoft.com/en-us/power-platform/admin/wp-data-loss-prevention).

## Pipeline Boundary

Azure DevOps remains the proposed engineering control plane for future managed-solution promotion, but Task 1 creates no project, repository, pipeline, environment, check, service connection, artifact, or deployment settings file. The supplied Tenant 1 organization and project are discovery candidates, not proof of an operational pipeline.

Power Platform Pipelines may be evaluated as a maker-facing secondary path. They are not the primary cross-tenant delivery mechanism and are not enabled here; see [Pipelines in Power Platform](https://learn.microsoft.com/en-us/power-platform/alm/pipelines).

## Acceptance Evidence for a Later Release

A future release review must show that:

1. the three stable environment IDs match the reviewed URLs;
2. DEV remains the unmanaged source stage;
3. TEST validates the exact managed artifacts before PROD;
4. Infrastructure imports before HR at each target;
5. environment values and connection bindings are supplied outside solution source;
6. approvals and import results are recorded;
7. no unmanaged layer or manual PROD customization bypasses the release path.

No item in this checklist is asserted as current state by Task 1.
