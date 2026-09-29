# Tenant Trust Activation Runbook

| Field | Value |
|---|---|
| **Version** | 2.0 |
| **Date** | 2026-09-29 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Superseded |
| **Scope** | Infrastructure |
| **References** | [Tenant 1 Lean Engineering Platform Design](../../docs/specs/2026-09-28-tenant-1-lean-engineering-platform-design.md), [Tenant 1 Lean Platform Runbook](24-tenant-1-lean-platform-runbook.md) |

> **STOP — SUPERSEDED.** `Initialize-TenantTrust.ps1` is dormant and unsupported in the current sprint. Do not invoke it, copy commands from an earlier revision, or treat trust activation as a prerequisite. Reuse requires a new reviewed design and implementation plan.

## Current Decision

The Tenant 1 lean platform has no bootstrap Entra application, service principal, federated credential, or GitHub bootstrap Environment. The active path is attended and local, uses the operator's pre-existing separately approved least-privilege access, and performs no role mutation.

Use the [Tenant 1 Lean Platform Runbook](24-tenant-1-lean-platform-runbook.md) for private local configuration, discovery, sanitized review, Bicep build, subscription `what-if`, boundary validation, and context/access read-back.

## Dormant Artifact Boundary

`infra/src/scripts/Initialize-TenantTrust.ps1` remains unchanged as a dormant historical artifact. Its presence is not approval to execute it. Active tests, comprehensive validation, runbooks, and operator prerequisites do not depend on it.

The current sprint does not create or update:

- an Entra application or service principal;
- a workload identity or federated credential;
- a GitHub Environment or Environment variable;
- an Azure DevOps service-principal entitlement or group membership;
- a role definition or role assignment; or
- a cloud configuration retrieval path.

## Conditions for Reconsideration

Trust activation may return only through a new reviewed design that defines the business need, ownership, least-privilege permissions, attended approval, failure recovery, evidence boundary, and exact read-back. That review must not revive commands or assumptions from the superseded procedure without revalidation.
