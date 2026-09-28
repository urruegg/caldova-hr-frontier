# Tenant 1 Engineering Platform Configuration Review Design

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-28 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Approved |
| **Scope** | Tenant 1 GitHub, Azure DevOps, Azure, Entra, and Power Platform control planes |
| **References** | [ADR-0001](../adr/0001-azure-devops-as-engineering-control-plane.md), [ADR-0002](../adr/0002-github-first-bootstrap-and-the-role-of-azure-repos.md), [Infrastructure and Tenant Bootstrap Implementation Plan](../plans/2026-09-17-infrastructure-tenant-bootstrap-implementation.md) |

## Status

Approved through attended design review on 2026-09-28.

This specification authorizes a read-only configuration and evidence review. It does not authorize a GitHub, Azure DevOps, Azure, Entra, or Power Platform configuration change.

## Problem and Desired Outcome

Tenant 1 has a GitHub repository, an Azure DevOps project, and an Azure Boards GitHub App connection. Supplied screenshots also show an Azure Repo with the project name, no visible Azure Repo branch policies, and the Azure Repos-to-GitHub migration wizard. Those observations do not prove that the intended engineering platform, Boards traceability, workload identity, service connections, deployment environments, or HR solution pipelines are configured correctly.

The review must establish a truthful and reproducible baseline for the current Tenant 1 engineering platform. It must identify configuration gaps, distinguish missing configuration from missing evidence, and define the validation required after remediation. The review is successful when it is actionable and evidence-backed, even if it concludes that Tenant 1 is not deployment-ready.

## Review Baseline

The review uses the following sprint-specific North Star:

```text
Tenant 1
├─ GitHub source: urruegg/caldova-hr-frontier
├─ Azure DevOps project: Caldova HR Frontier
│  ├─ Azure Boards: single delivery backlog
│  └─ Azure Pipelines: HR solution CI/CD
├─ Entra/Azure workload identity and subscription prerequisites
└─ Power Platform: unmanaged DEV source -> managed TEST -> managed PROD prerequisites
```

The operating responsibilities are:

- GitHub is the product-source and pull-request authority.
- GitHub Actions validates repository governance.
- Azure Boards is the delivery backlog.
- Azure Pipelines validates the unmanaged DEV source, builds one managed artifact, and promotes that unchanged artifact to TEST and PROD.
- Each future tenant has one independent GitHub repository clone and one Azure DevOps project, with tenant-specific identities, services, configuration, and evidence.

ADR-0001 and ADR-0002 remain Proposed Baseline documents and do not fully express this emerging one-repository-to-one-project topology. The review treats the approved sprint-specific North Star above as its assessment baseline and records formal ADR reconciliation as a governance gap. It does not silently reinterpret or approve the existing ADRs.

## Scope

### Included

- The `urruegg/caldova-hr-frontier` GitHub repository.
- The Tenant 1 `Caldova HR Frontier` Azure DevOps project.
- Azure Boards project configuration and the Azure Boards GitHub App connection.
- Azure Pipelines definitions, GitHub integration, permissions, agents, service connections, variable groups, secure files, environments, approvals, checks, and existing run evidence.
- Entra workload identity and Azure subscription prerequisites used by the delivery control plane.
- Power Platform DEV, TEST, and PROD prerequisites needed for HR solution CI/CD.
- Cross-system traceability and the reproducibility of Tenant 1 as the source for Tenant 2 and Tenant 3 runbooks.
- The six supplied Azure DevOps screenshots and additional portal screenshots only where an API cannot adequately show a control.

### Excluded

- Any configuration mutation or remediation.
- Creating a work item, branch, commit, pull request, pipeline run, artifact, deployment, identity, role assignment, service connection, or environment.
- Active validation in Tenant 2 or Tenant 3.
- Deploying or changing an HR solution.
- Proving behavior for which no existing runtime transaction is available.
- Retrieving or recording secret values.

## Assessment Architecture

The assessment has five stages:

1. **Preflight** verifies the active identities and confirms that each authenticated context points to Tenant 1.
2. **Read-back** queries configuration through authenticated read-only APIs and command-line clients.
3. **Normalization** maps observations to an allowlisted evidence model and removes public-report-sensitive values.
4. **Evaluation** compares normalized observations with this specification and current Microsoft guidance.
5. **Publication** produces the review, sanitized evidence manifest, test results, and redacted screenshots.

Raw responses remain in the session artifact folder and are not committed. Only sanitized, reviewed evidence enters the public repository.

## Control Domains

### GitHub Repository Governance

The review covers:

- visibility, default branch, merge settings, issue and project usage, and administrator boundary;
- rulesets or branch protection;
- pull-request requirements, approval count, stale-review handling, CODEOWNERS review, and conversation resolution;
- force-push and branch-deletion restrictions;
- GitHub Actions permissions, immutable action pinning, and successful validation on `main`;
- Dependabot and available security-analysis configuration;
- GitHub environments and protection rules; and
- Azure Boards GitHub App installation and repository scope.

### Azure DevOps Project and Boards

The review covers:

- project visibility, process, teams, area paths, iterations, permissions, and backlog configuration;
- the GitHub connection authentication type and repository binding;
- existing `AB#` work-item links, pull-request links, and state-transition evidence;
- service hooks or integration settings relevant to Boards traceability; and
- the purpose of the Azure Repo shown in the supplied screenshots.

An Azure Repo that duplicates product source without an approved role is a competing source-of-truth risk. A private configuration or governed-template repository may be valid only when its purpose, ownership, content boundary, and directional flow are explicit. The Azure Repos-to-GitHub migration wizard is not evidence of the required GitHub-to-Azure Boards or GitHub-to-Azure Pipelines integration.

### Azure Pipelines Control Plane

The review covers:

- pipeline definitions, GitHub triggers, YAML source, and branch filters;
- agent pools, parallel-job readiness, and build-service permissions;
- service connections and authentication schemes;
- variable groups, secure files, environment permissions, approvals, checks, and required templates;
- separation of duties between source authors, pipeline administrators, and deployment approvers;
- CI evidence for HR solution validation and build; and
- CD evidence that one managed artifact built from unmanaged DEV source is promoted unchanged to TEST and PROD.

### Tenant Prerequisites

The review covers:

- Entra application, service principal, and federated or workload-identity configuration;
- Azure subscription role assignments and their scope;
- Power Platform DEV, TEST, and PROD environment existence and lifecycle role;
- application-user and deployment-identity readiness;
- solution and publisher prerequisites; and
- environment-specific configuration boundaries.

The assessment does not retrieve credentials, client secrets, certificate material, or connection secret values.

### Cross-System Traceability and Reproducibility

The review seeks existing evidence for:

```text
GitHub pull request or commit
  -> Azure Boards work item
  -> Azure Pipeline run
  -> immutable artifact
  -> environment deployment and approval record
```

It also tests whether Tenant 1 configuration is declarative, parameterized, documented, and isolated well enough for Tenant 2 and Tenant 3 to reproduce without inheriting Tenant 1 identifiers or privileges.

## Evidence Model

Each control test records:

- stable test identifier;
- control domain;
- expected state;
- observed state;
- outcome;
- observation time in UTC;
- evidence source and read-only command or API class;
- sanitized evidence reference;
- confidence;
- gap priority where applicable;
- impact and dependency;
- recommended accountable owner;
- corrective action; and
- post-remediation validation test.

Allowed outcomes are:

| Outcome | Meaning |
|---|---|
| `PASS` | Direct read-back or an existing successful runtime record proves the expected state. |
| `GAP` | A successful read-back proves that required configuration is absent or incorrect. |
| `NOT EVIDENCED` | Permission, API coverage, or an absent runtime transaction prevents proof. |
| `NOT APPLICABLE` | The control does not apply and the reason is recorded. |

The report must not convert an authorization failure, API error, empty fallback, or missing runtime event into `PASS`.

## Gap Priority

Findings use delivery priority rather than vulnerability severity:

| Priority | Meaning |
|---|---|
| `BLOCKER` | Prevents safe or correct HR solution CI/CD or invalidates the intended source/backlog authority. |
| `HIGH` | Materially weakens access control, deployment integrity, traceability, or reproducibility. |
| `MEDIUM` | Creates operational drift, incomplete evidence, or avoidable manual work. |
| `LOW` | Improves clarity, maintainability, or completeness without blocking delivery. |

Dependencies determine remediation order. A lower-priority prerequisite may be scheduled before a higher-priority dependent control when the report explains the sequencing.

## Collection and Failure Handling

Preferred read-only surfaces are:

- GitHub CLI and GitHub REST API for repository and workflow controls;
- Azure DevOps REST API and supported Azure DevOps CLI reads for project, Boards, Pipelines, and security configuration;
- Azure CLI and Microsoft Graph reads for Azure and Entra configuration; and
- Power Platform CLI or supported administration APIs for environment and application-user readiness.

Collection fails closed:

- an identity or tenant mismatch stops the affected collector;
- `403`, `404`, and unsupported API responses remain distinct;
- ambiguous duplicate resources produce a finding rather than an arbitrary selection;
- unexpected sensitive fields stop public normalization;
- raw responses are never used as public evidence; and
- no collector invokes a create, update, delete, queue, dispatch, approve, or deploy operation.

## Sanitization and Screenshot Policy

Public evidence is allowlisted rather than redacted after arbitrary payload capture. It excludes:

- tokens, secrets, certificates, and credential metadata;
- personal or administrator display names, email addresses, and avatars;
- tenant, subscription, object, application, connection, and environment identifiers;
- tenant-specific service URLs and browser address bars; and
- unrestricted user, group, or membership listings.

Repository and project names, control names, control states, non-sensitive timestamps, and sanitized test identifiers may remain visible.

The supplied screenshots are copied and sanitized; their read-only source files are never modified. Cropping and opaque redaction remove browser chrome and excluded fields. Useful supplied views include:

- the GitHub App connection and selected repository;
- Azure Repo settings and Advanced Security state;
- absence of visible Azure Repo branch policies;
- Azure Repo permission inheritance; and
- the Azure Repos-to-GitHub migration surface and its mismatch with the GitHub-first topology.

New live screenshots are captured only when an API cannot communicate the relevant portal-only state.

## Public Artifacts

Execution creates:

- `docs/reviews/2026-09-28-tenant-1-engineering-platform-configuration-review.md`;
- `docs/reviews/evidence/2026-09-28-tenant-1-engineering-platform/evidence-manifest.json`;
- `docs/reviews/evidence/2026-09-28-tenant-1-engineering-platform/test-results.json`;
- selected sanitized screenshots under the same evidence folder; and
- a catalogue entry in `docs/reviews/README.md`.

The report contains:

- an executive summary;
- current-state topology;
- evidence coverage and limitations;
- the control-by-control evidence matrix;
- a priority- and dependency-ordered gap register;
- quick wins and remediation waves;
- post-remediation evidence tests; and
- implications for Tenant 2 and Tenant 3 reproducibility.

## Acceptance Criteria

The review is complete when:

1. Every in-scope control has exactly one outcome and a timestamped evidence reference.
2. Every `PASS` is supported by direct read-back or an existing successful runtime record.
3. Every `GAP` has priority, impact, dependency, owner recommendation, corrective action, and post-remediation test.
4. Every `NOT EVIDENCED` names the missing permission, unsupported API, or absent transaction.
5. Known, inferred, and not-yet-validated facts are clearly separated.
6. Sanitized screenshots support portal-specific observations without exposing excluded data.
7. No configuration mutation occurs during collection.
8. No excluded sensitive value enters the public repository.
9. Repository documentation metadata, links, whitespace, and existing validation contracts pass.
10. The conclusion distinguishes control configuration, configuration evidence, and proven runtime behavior.

## Follow-On Work

After the review is accepted, remediation receives a separate design and approval gate. That phase may:

- reconcile ADR-0001 and ADR-0002 with the approved one-repository-to-one-project topology;
- remove or narrow an ambiguous Azure Repo;
- configure Boards, pipelines, identities, service connections, environments, and checks;
- add reusable desired-state and conformance automation; and
- execute synthetic end-to-end transactions to prove traceability and deployment behavior.

No remediation is implied by approval of this review design.
