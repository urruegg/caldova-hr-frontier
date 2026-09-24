# HR Solution Sources

| Field | Value |
|---|---|
| **Version** | 1.1 |
| **Date** | 2026-09-24 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | HR |
| **References** | [Power Platform Solution Foundation Design](../../../docs/specs/2026-09-24-power-platform-solution-foundation-design.md), [HR Employee Journey](../../docs/20-hr-employee-journey.md) |

This folder contains unpacked, reviewable Power Platform solution source owned by the HR domain.

Do not commit exported solution ZIP files, environment-specific connection values, secrets, personal data, or generated build output. The Infrastructure solution is imported before the HR solution in each Power Platform ALM stage.

## Current state

One foundation solution exists, synced from Tenant 1's DEV environment:

| Solution | Tenant | Publisher prefix | Contains |
|---|---|---|---|
| [`caldovahrfrontier`](caldovahrfrontier/) | Tenant 1 (Caldova) | `calhr` | Nothing yet — the solution is empty. This is the tracked foundation, ready to receive Dataverse tables and Copilot Studio agent artefacts as they are built. |

Synced using [`hr/src/scripts/Sync-HrSolutionSource.ps1`](../scripts/README.md), which exports the unmanaged solution and unpacks it here. Re-run that script after any change in the Power Platform maker portal to keep this folder an exact, reviewable mirror of what is actually in Dataverse.

`docs/solution-design.md` §7 documents an eventual two-solution split (`GFHRPlatformCore` / `GFHRMasterDataAgent`, Tenant 3 naming) once there is enough content to justify separating shared plumbing from a per-use-case agent. That split has not happened yet — there is currently one foundation solution, for one tenant.
