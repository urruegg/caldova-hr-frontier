# Multi-Tenant Provisioning

| Field | Value |
|---|---|
| **Version** | 1.3 |
| **Date** | 2026-09-28 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Infrastructure |
| **References** | [Tenant 1 Engineering Platform Remediation Design](../../docs/specs/2026-09-28-tenant-1-engineering-platform-remediation-design.md), [Approved Intake Design](../../docs/specs/2026-09-17-architecture-baseline-intake-design.md), [Source Inventory](../../docs/reviews/2026-09-17-architecture-baseline-source-inventory.json), [ADR-0012](../../docs/adr/0012-per-tenant-github-repository-and-account-topology.md) |

This document applies the approved Wave 0 per-tenant topology to the Proposed Baseline onboarding guidance. It does not prove that Tenant 1, Tenant 2, Tenant 3, or any associated Azure, Entra, Azure DevOps, Power Platform, GitHub, pipeline, identity, or service configuration currently exists.

> **Revision note.** This section previously described one shared repository serving all three tenants. The now-approved [ADR-0012](../../docs/adr/0012-per-tenant-github-repository-and-account-topology.md) replaced that with one product-source repository, one Azure DevOps project, and one private configuration repository per tenant. The Azure Boards GitHub App enforces the repository-to-project boundary at the platform level.

## Per-Tenant Repository Model

Each tenant has its own dedicated GitHub repository, seeded from Tenant 1's repository as a one-time copy - never a live fork, never automatic sync. See [ADR-0012](../../docs/adr/0012-per-tenant-github-repository-and-account-topology.md) for the account-type decision per tenant, and the [Customer Repository Export and Handover design](../../docs/specs/2026-09-27-customer-repository-export-and-handover-design.md) for the runbooks that carry out the seeding and clean-up.

```text
urruegg/caldova-hr-frontier (Tenant 1)
`-- private Tenant 1 configuration -> bootstrap-tenant1 -> dedicated Tenant 1 app/SP

AndreaRizzi/caldova-hr-frontier (Tenant 2, not yet created)
`-- private Tenant 2 configuration -> tenant-specific bootstrap -> dedicated Tenant 2 app/SP

<Georg Fischer's GitHub Organization>/<repository> (Tenant 3, not yet created)
`-- private Tenant 3 configuration -> tenant-specific bootstrap -> dedicated Tenant 3 app/SP
```

A workflow run in a tenant's repository selects that repository's own tenant and binds to that tenant's Environment. In this repository the only bootstrap target is `tenant1`, bound to `bootstrap-tenant1`; self-review is disabled. Tenant 2's existing manifest and discovery evidence are the temporary hash-pinned exception until Slice 5 and cannot be selected for bootstrap. Each tenant's application, variables, evidence, stable IDs, temporary roles, approvals, and results are isolated by repository boundary, not merely by naming convention.

## Per-Tenant Contract

Each onboarded tenant has:

- one reviewed configuration overlay at an approved private path in that tenant's `caldova-hr-frontier-config` Azure Repo;
- one immutable six-character naming suffix generated once and reviewed;
- one canonical naming root;
- one tenant-specific GitHub Environment; this repository uses `bootstrap-tenant1`;
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
| Tenant 1 (`caldova25156897`) | `urruegg/caldova-hr-frontier` (this repository) | Reviewed discovery evidence and bootstrap intent. GitHub-to-Boards connection verified live and valid. | Bootstrap validation and subscription `what-if` only |
| Tenant 2 (`caldova25668747`) | `AndreaRizzi/caldova-hr-frontier` (not yet created) | Existing manifest and discovery evidence remain hash-pinned in this repository until Slice 5 verifies destination handoff | Attended read-only discovery only |
| Tenant 3 (Georg Fischer) | New organization-owned repository (not yet created) | Schema-ready; no manifest | No live action |

Tenant 2 files remain until Slice 5. The existing manifest and discovery evidence may receive only the neutral public-key metadata required by the explicit-path contract before both are pinned by reviewed hash. They must not be removed or modified beyond that exception until destination read-back proves the handoff. Tenant 3 artifacts remain absent and must not be created as placeholders or speculative configuration.

## Tenant 1 Blueprint Verification

`infra/tests/pester/TenantBlueprintVerification.Tests.ps1` remains the pre-migration characterization for Tenant 1's existing manifest and discovery evidence. The approved target moves Tenant 1 private values to `caldova-hr-frontier-config`; later implementation must replace this public-path dependency with validation against the attended private path. Re-run the current suite until that migration is complete.

This proves the manifest and evidence agree with each other. It does not prove the underlying Azure, Azure DevOps, or GitHub resources still exist - that requires fresh, live discovery, which remains a separate, attended action.

Separately, `infra/src/scripts/Initialize-TenantTrust.ps1` was reviewed (2026-09-27) against Tenant 1's six remaining `Mode = 'Create'` components (`EntraApplication`, `EntraServicePrincipal`, `EntraFederatedIdentityCredential`, `GitHubEnvironment`, `AzureDevOpsServicePrincipalEntitlement`, `AzureDevOpsReadersMembership`) and confirmed complete and gap-free: each has its own plan item, mutation-queue entry, and `ShouldProcess`-gated execution block in that script. Running it live remains a separate, attended activity - this review only confirms the path exists and is correct, not that it has been executed.

For the concrete, tenant-agnostic procedure - not just the sequence below - see the [Customer Repository Export and Handover Runbook](./23-customer-repository-export-and-handover-runbook.md), which in turn uses the [Repository Clean-Up Runbook](./22-repository-cleanup-runbook.md).

## Future Onboarding Sequence

For one approved tenant at a time:

1. collect reviewed non-secret metadata;
2. generate and review the tenant-private configuration at the approved private path;
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

- the private configuration validates and contains no prohibited data;
- all five discovery services return acceptable, current evidence;
- every `Existing` stable ID matches exactly;
- every `Create` decision has no conflict or ambiguity;
- OIDC resolves to the selected app, tenant, subscription, repository, and Environment;
- `what-if` remains within the approved resource boundary;
- temporary role assignments are absent afterward;
- no other tenant's files, variables, identities, or evidence were touched, except for the exact hash-pinned Tenant 2 transition files permitted until Slice 5.

Until those checks are recorded, the tenant remains unprovisioned.
