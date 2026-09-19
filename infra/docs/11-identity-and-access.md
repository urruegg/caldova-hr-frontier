# Identity and Access

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-17 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Infrastructure |
| **References** | [Approved Intake Design](../../docs/specs/2026-09-17-architecture-baseline-intake-design.md), [Source Inventory](../../docs/reviews/2026-09-17-architecture-baseline-source-inventory.json) |

This source-derived Proposed Baseline describes intended identity and access architecture. It does not prove that any tenant, Azure resource, Azure DevOps object, Power Platform environment, GitHub governance control, pipeline, identity, permission, or service is currently deployed or configured.

## Identity Boundary

| Identity | Intended use | Prohibited use |
|---|---|---|
| Reviewed tenant administrator | Attended initial trust, consent, and exceptional portal-only setup | CI/CD credential, stored password, or unattended runtime identity |
| Dedicated per-tenant bootstrap application and service principal | Secretless OIDC discovery, validation, and the approved bootstrap control plane for this repository | Human sign-in, shared cross-tenant identity, or workload runtime identity |
| Future workload managed identity | Azure-hosted application runtime after a separately reviewed deployment | Tenant bootstrap or reuse of the provisioning principal |
| Future Power Platform application user | Minimum approved metadata and `who-am-i` access, then separately reviewed ALM duties | Broad administrator access by default |

Each independent tenant receives its own single-tenant app registration and service principal. Managed identities are reserved for future Azure-hosted workloads and are not used to solve the bootstrap trust problem.

## Attended Administration

Tenant 1 uses `admin@Caldova25156897.onmicrosoft.com` only as the reviewed selector for an attended administrator session. The operator verifies the signed-in tenant and account directly. Scripts never request or relay a password, MFA response, token, recovery code, or private key.

Microsoft recommends workload identities for automation in [Plan for mandatory multifactor authentication](https://learn.microsoft.com/en-us/entra/identity/authentication/concept-mandatory-multifactor-authentication). Emergency-access and privileged-role design remain important attended prerequisites; see [Manage emergency access accounts](https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/security-emergency-access) and [Microsoft Entra role security planning](https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/security-planning).

Task 1 does not prove that MFA, Conditional Access, PIM, break-glass accounts, or administrator roles are configured.

## Secretless GitHub OIDC

The dedicated application trusts one exact GitHub Environment subject per tenant:

```text
Issuer: https://token.actions.githubusercontent.com
Audience: api://AzureADTokenExchange
Subject: repo:${owner}@${ownerId}/${repository}@${repositoryId}:environment:bootstrap-${tenantAlias}
```

The manifest stores the GitHub owner and repository names plus their immutable numeric IDs as reviewed non-secret metadata. Before trust creation, read-only GitHub API calls must return `use_default: true`, `use_immutable_subject: true`, and a `sub_claim_prefix` that exactly matches those fields. A mismatch stops the operation.

Read-only API evidence collected on 2026-09-19 returned owner ID `46865858`, repository ID `1371297722`, and prefix `repo:urruegg@46865858/caldova-hr-frontier@1371297722`. Tenant 1 therefore uses:

```text
repo:urruegg@46865858/caldova-hr-frontier@1371297722:environment:bootstrap-caldova25156897
```

The Environment name, tenant ID, subscription ID, client ID, issuer, audience, and subject are compared case-sensitively with the reviewed manifest and API read-back. A mismatch stops the run. The trust contains no stored credential. GitHub's Azure OIDC guidance is [Configuring OpenID Connect in Azure](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-azure).

No GitHub Environment, app registration, service principal, federated credential, variable, permission, or ruleset is created in Task 1.

## Least-Privilege Discovery

Discovery is read-only across five services:

- GitHub repository controls visible to the authenticated principal;
- Entra application, service-principal, federated-credential, and consent metadata;
- Azure subscription identity, resources, role assignments, policies, and diagnostics;
- Azure DevOps organization, project, repositories, pipelines, environments, checks, and effective permissions;
- Power Platform environment IDs, URLs, types, states, and available governance metadata.

`Unauthorized`, `Unavailable`, and `Ambiguous` are distinct outcomes and all fail the bootstrap decision gate. A lack of permission is never treated as absence.

Azure DevOps authorization is controlled by Azure DevOps permissions rather than Microsoft Graph application roles. Service principals must be added explicitly and should receive only the access needed for the reviewed scenario; see [Service principals and managed identities in Azure DevOps](https://learn.microsoft.com/en-us/azure/devops/integrate/get-started/authentication/service-principal-managed-identity).

## Temporary Azure Authorization

A later attended task may grant the bootstrap service principal exactly two temporary subscription-scope roles for the validation window:

- `Contributor`;
- `Role Based Access Control Administrator`.

Their exact assignment IDs are recorded outside Git and validated before use. Cleanup removes Contributor first and role administration last, then polls read-only state until both exact IDs are absent. Any deletion remains an explicit attended approval gate. Standing elevated access is not an acceptable end state.

The steady-state custom permission set is limited to reads plus deployment validation and `what-if`; it has no resource-provider write or delete permission. Task 1 creates neither the custom role nor any assignment.

## Power Platform Access

The three supplied Power Platform URLs are existing candidates only. After OIDC trust is reviewed, an attended administrator may add the application as an application user in each verified environment with only the minimum existing role that supports `who-am-i` and approved metadata reads.

That action requires separate approval per environment. It must not create an environment, query business data, assign System Administrator as a shortcut, introduce a stored credential, or broaden access when the minimum role is insufficient. If secretless access or minimum-role discovery cannot be proven, the design is reopened rather than weakened. Microsoft documents application-user management in [Manage application users](https://learn.microsoft.com/en-us/power-platform/admin/manage-application-users).

## Verification Contract

A later identity review must prove:

1. one app and one related service principal exist for the selected tenant;
2. the app is single-tenant and carries no password or certificate credential;
3. the exact federated issuer, audience, and Environment subject match;
4. every permission and consent is reviewed and read back;
5. the authenticated Azure context matches the manifest;
6. temporary role assignments are absent after validation;
7. no human account owns an unattended pipeline.

Until those checks produce current evidence, every identity and control remains proposed.
