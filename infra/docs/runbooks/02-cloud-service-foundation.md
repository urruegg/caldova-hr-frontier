# Cloud Service Foundation Runbook

| Field | Value |
|---|---|
| **Version** | 2.0 |
| **Date** | 2026-09-30 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Superseded |
| **Scope** | Infrastructure |
| **References** | [Tenant 1 Lean Engineering Platform Design](../../../docs/specs/2026-09-28-tenant-1-lean-engineering-platform-design.md), [Tenant 1 Lean Platform Runbook](../24-tenant-1-lean-platform-runbook.md) |

> **STOP — SUPERSEDED.** `Get-CloudFoundationPlan.ps1` and `Invoke-CloudFoundation.ps1` are dormant and unsupported in the current sprint. Do not invoke them, copy commands from an earlier revision, or treat their retained module internals as an approved mutation path. Reuse requires a new reviewed design and implementation plan.

## Current Decision

The Tenant 1 lean platform supports local attended discovery, Bicep build, subscription `what-if`, boundary validation, and exact context/access read-back. It does not support a cloud-foundation planner, infrastructure deployment, Entra application creation, Azure DevOps project creation, or GitHub configuration mutation.

Use the [Tenant 1 Lean Platform Runbook](../24-tenant-1-lean-platform-runbook.md) for the current procedure. Its local validation path performs no role or deployment mutation.

## Dormant Compatibility Boundary

Generic cloud-foundation module internals may remain for compatibility with historical tests and future reconsideration. They are not active dependencies, operator defaults, or supported entry points. The two public scripts stop before importing modules, reading tenant configuration, resolving tools, creating output, authenticating, or contacting a provider.

The historical operational-runbook design and implementation plan remain point-in-time records. Their former commands provide no execution approval.

## Conditions for Reconsideration

Cloud-foundation automation may return only through a new reviewed design that defines a measurable need, accountable owners, least-privilege access, private-data boundaries, mutation scope, recovery, approval, and exact read-back. That review must not revive retained module behavior without revalidation.
