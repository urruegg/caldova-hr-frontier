# `hr/src/scripts/` — Power Platform solution lifecycle tooling

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-24 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | HR Solution Architecture |
| **References** | [Power Platform Solution Foundation Design](../../../docs/specs/2026-09-24-power-platform-solution-foundation-design.md) |

**Purpose.** Connects to a tenant's Power Platform environment and pulls its Dataverse solution into source control. Built once, parameterized by tenant alias throughout, so the same scripts work unchanged for Tenant 2 and Tenant 3 after handover — no code here names Tenant 1 or `caldovahrfrontier` directly.

## What is here

| Path | Purpose |
|---|---|
| `Connect-PowerPlatformEnvironment.ps1` | Verifies (and if needed, creates) an authenticated PAC CLI profile for a tenant/stage. Useful standalone to check connectivity before running anything else. |
| `Sync-HrSolutionSource.ps1` | The main entry point: exports a named solution's unmanaged package from a tenant's **DEV environment only**, unpacks it into `hr/src/solutions/<SolutionUniqueName>/`, and cleans up the temporary zip. This is what makes the committed source an exact, reviewable mirror of what is in Dataverse. |
| `modules/Caldova.HrFrontier.Solutions/` | The module both scripts are built on — read `Public/` for the individual functions if you are calling this from another script. |

## Usage

```powershell
# Verify connectivity to Tenant 1's DEV environment
.\Connect-PowerPlatformEnvironment.ps1 -TenantAlias caldova25156897 -Stage Dev

# Pull the current state of the solution into source control
.\Sync-HrSolutionSource.ps1 -TenantAlias caldova25156897 -SolutionUniqueName caldovahrfrontier
```

The first run for a tenant prompts an interactive Microsoft Entra ID sign-in (a PAC auth profile named `hr-<TenantAlias>-<stage>` is created and reused on subsequent runs). No service-principal or CI credential path exists yet — that is deliberately deferred until a tenant's infrastructure bootstrap provisions a usable credential for it.

## Why export is DEV-only

`Export-HrSolutionPackage` does not accept a `-Stage` parameter. Managed solutions for TEST and PROD are produced by a deployment pipeline from the committed DEV source — never hand-exported from those environments — per [`docs/solution-design.md`](../../../docs/solution-design.md) §7. Hand-exporting from TEST or PROD would create a second, undocumented path for solution content to enter source control, silently diverging from the pipeline-managed one.

## What this does not do (yet)

- **No push path.** These scripts only pull (export + unpack). Pushing local changes back into Dataverse (`pac solution pack` + `pac solution import`) is separate future work, once there is local content to round-trip.
- **No table, security role, connection reference, environment variable, or Copilot Studio agent creation.** Those are authored in the Power Platform maker portal (or via `pac` commands run directly by whoever is building); this tooling only pulls the result into source control afterward.
