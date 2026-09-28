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
| `Initialize-AiBuilderEvidenceRun.ps1` | Initializes a tenant-local AI Builder evidence run, creates required visual-review templates on first use, and writes qualified corpus plus run-manifest evidence only after both corpora pass the strict gate. |
| `modules/Caldova.HrFrontier.AiBuilder/` | Corpus qualification, readiness, lifecycle, and immutable run-manifest helpers for the Tenant-local AI Builder model workstream. |

## Usage

```powershell
# Verify connectivity to Tenant 1's DEV environment
.\Connect-PowerPlatformEnvironment.ps1 -TenantAlias caldova25156897 -Stage Dev

# Pull the current state of the solution into source control
.\Sync-HrSolutionSource.ps1 -TenantAlias caldova25156897 -SolutionUniqueName caldovahrfrontier
```

The first run for a tenant prompts an interactive Microsoft Entra ID sign-in (a PAC auth profile named `hr-<TenantAlias>-<stage>` is created and reused on subsequent runs). No service-principal or CI credential path exists yet — that is deliberately deferred until a tenant's infrastructure bootstrap provisions a usable credential for it.

## AI Builder evidence tooling

`Initialize-AiBuilderEvidenceRun.ps1` is deliberately **evidence-only**. It does not create a model, upload documents, or change a tenant prerequisite. Its job is to:

1. create the fixed and general visual-review templates for the committed synthetic corpora;
2. stop until a human confirms that visible values and deliberate absences match the controlled ground truth;
3. qualify both corpora, derive corpus and generator revisions, and create `corpus-quality.json`, `run-manifest.json`, and `model-inventory.json` only when both packages pass.

The committed evidence boundary remains under `hr/evidence/ai-builder/<tenant-key>/<environment-stage>/<run-id>/`. The evidence contains only synthetic values and non-secret platform metadata. Real PeopleDoc, candidate, pre-hire, worker, or employee documents must not be introduced here.

The AI Builder module is portable by tenant design. Tenant keys, environment IDs, environment stages, operators, and output locations are inputs to a run; they are not embedded into the code. That keeps the Tenant 2 implementation repeatable for a separately approved Tenant 1 team without importing Tenant 2 artifacts or credentials.

## Why export is DEV-only

`Export-HrSolutionPackage` does not accept a `-Stage` parameter. Managed solutions for TEST and PROD are produced by a deployment pipeline from the committed DEV source — never hand-exported from those environments — per [`docs/solution-design.md`](../../../docs/solution-design.md) §7. Hand-exporting from TEST or PROD would create a second, undocumented path for solution content to enter source control, silently diverging from the pipeline-managed one.

## What this does not do (yet)

- **No push path.** These scripts only pull (export + unpack). Pushing local changes back into Dataverse (`pac solution pack` + `pac solution import`) is separate future work, once there is local content to round-trip.
- **No table, security role, connection reference, environment variable, or Copilot Studio agent creation.** Those are authored in the Power Platform maker portal (or via `pac` commands run directly by whoever is building); this tooling only pulls the result into source control afterward.
