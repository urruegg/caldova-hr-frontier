# ADR-0013: GF Azure Repos Source Authority and Independent Repository Handover

| Field | Value |
|---|---|
| **Version** | 0.2 |
| **Date** | 2026-10-28 |
| **Author** | Copilot |
| **Status** | Proposed Baseline |
| **Scope** | GF only: source authority, repository transfer and Azure DevOps delivery boundary |
| **References** | [ADR-0001](0001-azure-devops-as-engineering-control-plane.md), [ADR-0002](0002-github-first-bootstrap-and-the-role-of-azure-repos.md), [ADR-0012](0012-per-tenant-github-repository-and-account-topology.md), [GF repository specification](../specs/2026-10-28-gf-azure-devops-repository-design.md), [GF CI/CD specification](../specs/2026-10-28-gf-azure-devops-solution-cicd-design.md) |

## Context and status

The user confirmed on 2026-10-28 that GF's target repository is Azure DevOps/Azure Repos, seeded by a one-time reviewed transfer from this repository. GF Azure Repos is to be independent and authoritative for GF source and pull requests, with no automatic synchronization to the GitHub demo/reference repository.

ADRs 0001, 0002 and 0012 record the approved GitHub-based demo/tenant operating model. Reapplying that model unchanged to GF would contradict the confirmed GF target. This record supplies a traceable, GF-scoped refinement rather than silently editing their historical decisions or reopening the target-platform choice.

The GF target requirement is confirmed; this architectural adoption record remains Proposed Baseline pending formal review. Approval to draft did not authorize transfer, service configuration or deployment.

## Proposed decision

1. GF uses Azure Repos as its sole product-source and pull-request authority after verified cutover. The GF target is not a GitHub mirror.
2. Seed GF once through an explicitly reviewed transfer. Determine history treatment, inclusion/exclusion inventory, licensing obligations and information-protection checks before live execution.
3. Keep this GitHub repository as a separate demo/reference repository. No automatic synchronization or dual-source write authority is introduced.
4. Establish GF's own identity, access, protected-branch and validation controls. Do not carry the demonstration's solo-owner approval exceptions into GF by default.
5. Use Azure DevOps pipelines for GF's proposed solution capture/build/delivery path. Capture DEV solutions through an explicit reusable operation into a branch/PR; reviewed repository source drives releases. The initial delivery sprint targets TEST only, not production.
6. Keep forthcoming functional source documents on the agreed SharePoint site. Repository documents may reference controlled sources; no raw HR documents, real personal data or credentials are copied into Git by implication.
7. Use Copilot Studio's GitHub Copilot runtime harness for the three functional MVP agents, as explicitly selected by the user. ESS is out of current scope. This runtime choice neither changes Azure Repos source ownership nor proves a supported solution export/import route; the technical package retains that capability gate.
8. Treat the supplied confidential brief and CAT catalogue as design inputs, not verified tenant state or automatically admitted dependencies. Local preparation is authorized; public disclosure, plugin installation and live execution are not. Preserve private-source and reusable-component review gates.

## Scoped supersession and unchanged decisions

On approval, this record supersedes the GF applicability of the GitHub-only source/PR, GitHub-specific validation/integration and mandatory per-tenant GitHub topology provisions in ADR-0001, ADR-0002 and ADR-0012. It does not supersede their existing demo/tenant decisions, rewrite their approval history or migrate any demo tenant.

Do not infer that GF is an already configured tenant from ADR-0012's table. GF organization/project/repository names, backlog process, environment identities, reviewer policy and service connections are not known.

All unrelated HR governance remains intact: human employment decisions, bounded write envelopes, workflow-owned determinism/audit, governed access and the employee master-data boundary. Recruiting systems remain subject to SOP review; this ADR does not select one.

## Options considered

| Option | Disposition and trade-off |
|---|---|
| Independent GF Azure Repos repository after reviewed one-time transfer | Selected target requirement; fits GF ownership, but requires explicit validation/control migration and independent maintenance. |
| GitHub remains GF source with an Azure Repos mirror | Does not meet the confirmed sole-authority target and introduces synchronization ambiguity. |
| Rewrite the approved demo ADRs as globally Azure-Repos-first | Rejected: would erase scope/history and imply changes to demo tenants that were not requested. |

## Consequences

GF has a single owned engineering baseline and a source model consistent with its delivery target. GitHub-hosted CI, integrations and repository protections must be assessed and replaced or mapped explicitly; copying their files is insufficient.

Separate repositories can diverge. Any later reuse requires deliberate reviewed changes; no propagation is automatic. History retention and sanitization may change the transfer mechanism, and remain open rather than being hidden behind the word "clone."

## Compliance and execution gates

Before transfer, verify the approved GF-scoped decision, named ownership, destination authorization, security baseline, reviewed source/history inventory and independent transfer verification. Before pipeline operation, verify solution inventory, DEV/TEST access, packaging support and least-privilege execution controls.

Acceptance requires destination read-back, enforced PR/validation behavior, independent source verification and evidence of no automatic synchronization. No production deployment is authorized by this record.
