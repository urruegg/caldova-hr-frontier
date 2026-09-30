# Multi-Tenant Provisioning

| Field | Value |
|---|---|
| **Version** | 2.1 |
| **Date** | 2026-09-30 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Infrastructure |
| **References** | [Tenant 1 Lean Engineering Platform Design](../../docs/specs/2026-09-28-tenant-1-lean-engineering-platform-design.md), [ADR-0012](../../docs/adr/0012-per-tenant-github-repository-and-account-topology.md), [Tenant 1 Lean Platform Runbook](24-tenant-1-lean-platform-runbook.md) |

This Proposed Baseline records the per-tenant isolation target and the narrower current Tenant 1 slice. It does not authorize onboarding, mutation, migration, or deletion for another tenant.

## Per-Tenant Repository Model

Each tenant has a distinct GitHub product-source repository and Azure DevOps project. Tenant 1 uses `urruegg/caldova-hr-frontier`. A future customer repository is seeded through a separately reviewed one-time handover, never a live fork or automatic synchronization.

The current sprint does not create a private configuration repository, bootstrap Environment, trust identity, Azure Pipeline, tenant catalogue, transition package, or handoff workflow.

## Current Tenant 1 Contract

Tenant 1 uses:

- this GitHub repository as product source;
- its existing Azure DevOps project and Basic Boards process;
- the ignored local `tenant1.local.psd1` configuration;
- an operator-owned encrypted external backup in a separate failure domain outside Git;
- attended local discovery and sanitized review;
- locally generated Bicep parameters;
- the operator's pre-existing separately approved least-privilege access; and
- subscription `what-if` plus boundary and access read-back.

The sprint creates, changes, and deletes no role assignment, trust object, deployment, pipeline, environment, or application.

## Isolation Controls

| Risk | Required control |
|---|---|
| Wrong tenant selected | Require `PublicTenantKey tenant1`, an explicit local path, and exact authenticated tenant/subscription checks |
| Cross-tenant input | No default path, repository scan, matrix, workflow selector, or fallback |
| Shared authorization | Record the exact attended Tenant 1 principal and exact subscription-scope access before and after `what-if` |
| Ambiguous existing object | Read-only discovery plus exact stable-ID review |
| Accidental creation | `WhatIfOnly` hard guard and no deployment-create command |
| Stale evidence | Fresh attended discovery and one local review sequence |
| Cross-tenant output | Local Tenant 1 operator root outside Git |

Failure for Tenant 1 never authorizes an action in Tenant 2 or Tenant 3.

## Tenant Status

| Tenant | Current repository status | Allowed activity in this sprint |
|---|---|---|
| Tenant 1 | Active product-source repository with ignored local configuration; tracked transition files deleted in the approved commit | Attended local discovery, build, subscription `what-if`, and read-back |
| Tenant 2 | Tracked transition manifest and evidence remain temporarily | No selection, change, validation, migration, or deletion |
| Tenant 3 | No current onboarding artifact | No live action |

## Transition Artifact Boundary

The approved committed deletion removed both tracked Tenant 1 transition files. Do not reconstruct, recommit, or use them for recovery. Tenant 1 recovery uses only the encrypted external backup of the ignored local configuration with SHA-256, separate restore, and schema/import proof.

Tenant 2's existing tracked files also remain unchanged under the prior decision. Future migration or deletion requires current hashes, destination proof, a reviewed plan, and explicit approval.

## Future Onboarding

A future tenant begins with a new reviewed design. At minimum it must define:

1. accountable owners and the dedicated repository/project boundary;
2. explicit private configuration and backup ownership;
3. attended identity and minimum-access approval;
4. tenant-specific discovery and evidence sanitization;
5. exact Bicep, `what-if`, and resource-boundary contracts;
6. cross-tenant isolation tests;
7. failure recovery; and
8. deletion or handover approvals.

Do not copy Tenant 1 identifiers, access, local artifacts, or approvals. Dormant trust code and superseded runbooks are not onboarding templates.

## Tenant 1 Verification

Tenant 1 validation proves only:

- the selected local configuration matches the attended tenant and subscription;
- current discovery agrees with reviewed intent;
- Bicep compiles without a role or principal resource contract;
- subscription `what-if` stays within the allowed boundary; and
- context and access remain unchanged.

It does not prove deployed infrastructure or another tenant's readiness.
