# Multi-Tenant Provisioning

| Field | Value |
|---|---|
| **Version** | 1.2 |
| **Date** | 2026-09-27 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Infrastructure |
| **References** | [Approved Intake Design](../../docs/specs/2026-09-17-architecture-baseline-intake-design.md), [Source Inventory](../../docs/reviews/2026-09-17-architecture-baseline-source-inventory.json), [ADR-0012](../../docs/adr/0012-per-tenant-github-repository-and-account-topology.md) |

This source-derived Proposed Baseline describes intended multi-tenant onboarding. It does not prove that Tenant 1, Tenant 2, Tenant 3, or any associated Azure, Entra, Azure DevOps, Power Platform, GitHub, pipeline, identity, or service configuration currently exists.

> **Revision note.** This section previously described one shared repository serving all three tenants. [ADR-0012](../../docs/adr/0012-per-tenant-github-repository-and-account-topology.md) replaced that with one repository per tenant, after confirming live that the Azure Boards GitHub App enforces a real platform constraint — one repository connects to exactly one Azure DevOps organization at a time — which the shared-repository design silently violated for any second tenant. Rewritten below to match.

## Per-Tenant Repository Model

Each tenant has its own dedicated GitHub repository, seeded from Tenant 1's repository as a one-time copy — never a live fork, never automatic sync. See [ADR-0012](../../docs/adr/0012-per-tenant-github-repository-and-account-topology.md) for the account-type decision per tenant, and the [Customer Repository Export and Handover design](../../docs/specs/2026-09-27-customer-repository-export-and-handover-design.md) for the runbooks that carry out the seeding and clean-up.

```text
urruegg/caldova-hr-frontier (Tenant 1)
`-- manifest for Tenant 1 -> bootstrap-caldova25156897 -> dedicated Tenant 1 app/SP

AndreaRizzi/caldova-hr-frontier (Tenant 2, not yet created)
`-- manifest for Tenant 2 -> bootstrap-caldova25668747 -> dedicated Tenant 2 app/SP

<Georg Fischer's GitHub Organization>/<repository> (Tenant 3, not yet created)
`-- manifest for Tenant 3 -> bootstrap-${tenantAlias} -> dedicated Tenant 3 app/SP
```

A workflow run in any tenant's repository selects that repository's own single tenant alias and binds to that tenant's own Environment — there is no cross-tenant selection to prohibit, because no other tenant's manifest exists in the same repository to select by mistake. Each tenant's application, variables, evidence, stable IDs, temporary roles, approvals, and results are isolated by repository boundary, not merely by naming convention.

## Per-Tenant Contract

Each onboarded tenant has:

- one data-only manifest at `infra/src/config/tenants/<tenantAlias>.psd1`;
- one immutable six-character naming suffix generated once and reviewed;
- one canonical naming root;
- one `bootstrap-${tenantAlias}` GitHub Environment;
- one dedicated single-tenant Entra application and service principal;
- one normalized discovery record;
- explicit `Existing` or `Create` intent for every managed component;
- tenant-specific approvals and exact OIDC subject;
- independently reviewed Azure region, subscription, Azure DevOps hints, and Power Platform URLs.

Tenant IDs, subscription IDs, stable object IDs, project names, and approved service URLs are non-secret metadata and may be versioned for validation. Credentials, tokens, private keys, and personal HR data never are.

## Isolation Controls

| Risk | Required control |
|---|---|
| Wrong tenant selected | Validate alias, tenant ID, subscription ID, Environment variables, and authenticated context before action |
| Cross-tenant credential reuse | Dedicated app and service principal per tenant; exact Environment OIDC subject |
| Shared approval | Tenant-specific Environment reviewer and one-tenant concurrency |
| Ambiguous existing object | Read-only discovery plus exact stable-ID match |
| Accidental creation | Explicit reviewed `Create`; no automatic mode |
| Stale evidence | One run ID and collection start within 24 hours for a changing bootstrap run |
| Cross-tenant output | Tenant-specific paths and allowlisted normalized evidence only |

Managed identities remain future workload identities and are not shared bootstrap identities.

## Tenant Status

| Tenant | Repository | Status | Allowed activity |
|---|---|---|---|
| Tenant 1 (`caldova25156897`) | `urruegg/caldova-hr-frontier` (this repository) | Reviewed discovery evidence and bootstrap intent | Bootstrap validation and subscription `what-if` only |
| Tenant 2 (`caldova25668747`) | `AndreaRizzi/caldova-hr-frontier` (not yet created) | Reviewed discovery manifest with optional SharePoint metadata scope; still hosted in this repository until its own repository exists | Attended read-only discovery only |
| Tenant 3 (Georg Fischer) | New organization-owned repository (not yet created) | Schema-ready; no manifest | No live action |

Tenant 2 has one reviewed discovery manifest. Its discovery evidence, stable component IDs, explicit intent, and Bicep parameters remain absent until attended discovery and review. Tenant 3 artifacts remain absent and must not be created as placeholders or speculative configuration.

## Future Onboarding Sequence

For one approved tenant at a time:

1. collect reviewed non-secret metadata;
2. generate and review the data-only manifest;
3. perform attended read-only discovery across all five services;
4. commit normalized evidence;
5. review exact `Existing` or `Create` intent;
6. establish the tenant's dedicated secretless trust;
7. validate exact OIDC context;
8. run fresh discovery;
9. build Bicep and run bounded subscription `what-if` only;
10. clean up temporary authorization after explicit approval;
11. record results before any other tenant begins.

Failure for one tenant does not authorize changes in another. Recovery resumes from the last trusted state for the selected tenant only.

## Power Platform Lineage

All tenants use the same domain split: Infrastructure source precedes HR source in DEV, TEST, and PROD. A tenant may adopt the reviewed publisher lineage or choose a separate lineage before any component exists, but that decision changes compatibility with reference managed solutions and requires separate review.

Task 1 creates no publisher, solution, environment, application user, or deployment pipeline. Microsoft documents the publisher ownership constraint in [Solution concepts](https://learn.microsoft.com/en-us/power-platform/alm/solution-concepts-alm).

## Azure DevOps and Power Platform Hints

Tenant-specific organization names, project names, and environment URLs are discovery inputs. They do not become `Existing` until stable IDs match current evidence. Azure DevOps organization creation remains an attended prerequisite and is not automated. Power Platform environment creation is outside this sprint.

## Verification Per Tenant

A later onboarding review must prove:

- the manifest validates and contains no prohibited data;
- all five discovery services return acceptable, current evidence;
- every `Existing` stable ID matches exactly;
- every `Create` decision has no conflict or ambiguity;
- OIDC resolves to the selected app, tenant, subscription, repository, and Environment;
- `what-if` remains within the approved resource boundary;
- temporary role assignments are absent afterward;
- no other tenant's files, variables, identities, or evidence were touched.

Until those checks are recorded, the tenant remains unprovisioned.
