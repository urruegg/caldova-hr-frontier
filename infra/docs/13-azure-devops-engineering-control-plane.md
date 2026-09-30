# Azure DevOps Engineering Control Plane

| Field | Value |
|---|---|
| **Version** | 1.1 |
| **Date** | 2026-09-28 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Infrastructure |
| **References** | [Tenant 1 Engineering Platform Remediation Design](../../docs/specs/2026-09-28-tenant-1-engineering-platform-remediation-design.md), [ADR-0001](../../docs/adr/0001-azure-devops-as-engineering-control-plane.md), [Approved Intake Design](../../docs/specs/2026-09-17-architecture-baseline-intake-design.md), [Source Inventory](../../docs/reviews/2026-09-17-architecture-baseline-source-inventory.json) |

This document applies the approved Wave 0 Azure DevOps and GitHub responsibility split to the Proposed Baseline implementation guidance. It does not prove that an Azure DevOps organization, project, repository, backlog, pipeline, environment, check, service connection, permission, or GitHub connection currently exists or is configured.

## Approved Split

| Responsibility | Approved owner | Boundary |
|---|---|---|
| Backlog and delivery planning | Azure Boards | Single backlog, iterations, delivery planning, and work traceability; GitHub Projects is disabled |
| Product source and pull requests | This tenant-dedicated GitHub repository | Sole product source and pull-request authority; product source is not copied to Azure Repos |
| Repository validation | GitHub Actions | Governance and traceability checks only; no HR solution CI/CD or deployment |
| HR solution CI/CD | Azure Pipelines | Immutable artifact publication and controlled TEST-to-PROD delivery from reviewed GitHub source |

Azure Boards and GitHub can be used together for planning and delivery; see [Use GitHub with Azure Boards](https://learn.microsoft.com/en-us/azure/devops/boards/github/). The split is the attended repository decision recorded in [ADR-0001](../../docs/adr/0001-azure-devops-as-engineering-control-plane.md), not a Microsoft mandate or a claim that the controls are deployed.

Azure Boards is the single backlog. GitHub Projects is disabled, and GitHub Issues remain an intake and repository-execution surface rather than a parallel project board.

## Tenant 1 Discovery Candidates

| Field | Reviewed hint | Task 1 classification |
|---|---|---|
| Organization URL | `https://dev.azure.com/caldova25156897/` | Existing candidate; discovery must verify organization identity and tenant connection |
| Project name | `Caldova HR Frontier` | Existing candidate; discovery must verify stable project ID |
| Project visibility | Private | Desired constraint; not yet evidenced here |
| Process | Agile | Approved target; current evidence must be read before any separately authorized change |

An Azure DevOps organization is always a prerequisite because automated organization creation is unsupported. Microsoft documents attended organization creation in [Create an organization](https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/create-organization).

Task 1 does not create or alter the organization, project, repository, users, licenses, groups, permissions, Boards hierarchy, iteration dates, delivery plans, pipelines, environments, checks, extensions, billing, or service connections.

## Read-Only Discovery

Discovery uses supported Azure DevOps REST API reads and records only allowlisted metadata:

- organization connection and authenticated-principal context;
- project ID, name, visibility, state, and process metadata;
- repositories, default branches, and repository size in bytes — size distinguishes a repository that has never received a push (size `0`, no default branch) from one that already holds content;
- pipeline, environment, check, and service-connection identifiers;
- effective permissions needed to evaluate the approved bootstrap.

A missing permission is `Unauthorized`, not `Missing`. More than one matching object is `Ambiguous`. Either result blocks intent review.

The supplied organization URL and project name may be marked `Existing` only when the observed stable IDs match reviewed evidence. A later `Create` decision for a supported project-level object requires current evidence proving that no conflicting object exists. There is no automatic creation mode.

## Platform Constraints Worth Preserving

- New Azure DevOps public projects cannot be created; see [Public projects retirement](https://learn.microsoft.com/en-us/azure/devops/organizations/projects/public-projects-retirement).
- Project creation, when separately approved in a future sprint, is asynchronous and must reach `wellFormed` before dependent objects are created; see [Projects REST API](https://learn.microsoft.com/en-us/rest/api/azure/devops/core/projects/create).
- Process-template identifiers are resolved from the target organization rather than copied from examples.
- Azure DevOps approval and check configuration is resource-administered and independent of pipeline YAML; see [Approvals and checks](https://learn.microsoft.com/en-us/azure/devops/pipelines/process/approvals).
- Azure DevOps service principals use Azure DevOps permissions and entitlements, not Microsoft Graph app roles.

These facts shape future implementation. They do not authorize Task 1 to execute it.

## GitHub Connection Boundary

The Azure Boards GitHub App is the approved backlog integration because it supports repository linking and GitHub checks without a PAT. The first organization-to-repository connection is an attended GitHub App authorization because the documented REST surface does not create it; see [Connect Azure Boards to GitHub](https://learn.microsoft.com/en-us/azure/devops/boards/github/connect-to-github).

The approved topology binds one tenant-dedicated GitHub repository to one Azure DevOps organization and project for unambiguous `AB#` resolution. Commit and pull-request descriptions may carry `AB#` links after that connection is verified. Task 1 neither installs the app nor creates a connection.

## Future Delivery Boundary

Azure Pipelines owns HR solution CI/CD, immutable artifact publication, and controlled TEST-to-PROD delivery through resource-administered approvals. GitHub Actions owns repository validation and does not perform HR solution build, artifact publication, or deployment. The later Azure Pipelines implementation must:

1. read and validate the existing project by stable ID;
2. use secretless workload identity where supported;
3. keep deployment settings and credentials out of public source;
4. preserve the Infrastructure-before-HR solution order;
5. require explicit approval for PROD;
6. avoid automatically creating unsupported organization-level objects.

No Azure DevOps pipeline or Power Platform deployment is implemented in this sprint.

## Verification Evidence

Current evidence must be collected before claiming any Azure DevOps control is active. A later review records stable IDs, query status, effective permissions, connection type, approval configuration, and read-back results. The Wave 0 topology is approved; implementation controls remain inactive until their required read-back succeeds.
