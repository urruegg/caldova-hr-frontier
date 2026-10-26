# HR Control Plane Code App

| Field | Value |
|---|---|
| **Version** | 1.2 |
| **Date** | 2026-10-26 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | HR |
| **References** | [HR Control Plane Code App Wireframe Design](../../../../docs/specs/2026-09-24-hr-control-plane-code-app-wireframe-design.md), [Current Sprint Component Boundary](../../../../docs/specs/2026-10-02-cloud-service-foundation-runbook-design.md#33-current-sprint-component-boundary), [ADR-0006 Agentic Toolset and HR Control Plane Split](../../../../docs/adr/0006-agentic-toolset-and-hr-control-plane.md), [HR Solution Sources](../../solutions/README.md) |

Power Apps Code App project for the HR Employee Control Plane described in [ADR-0006](../../../../docs/adr/0006-agentic-toolset-and-hr-control-plane.md). Built with Vite, React, and TypeScript on Microsoft's official Power Apps Code Apps template, themed from `docs/brand/caldova-fluent-theme.ts`. The inherited values are an interim product palette pending an approved Caldova design standard; palette values, contrast targets, semantic-state colours, and dark-mode behavior remain unchanged.

## Current state

Wireframe milestone only: the five structural regions from `docs/brand/hr-control-plane-mockup.html` (header, nav rail, main, footer, action drawer) are reproduced with static placeholder content. There is no Dataverse connector, no data, and no business logic — only local UI state for nav selection and drawer open/close.

The historical deployment record places this wireframe in Tenant 1 DEV and the `caldovahrfrontier` Dataverse solution. The existing binding remains in `power.config.json`; this README is not a fresh provider read-back.

## Current sprint scope

At the user's request, this legacy Code App and its specific `BackgroundImageUri` pack/unpack capability are not required for the current Tenant 1 runbook, replica, or handover sprint. This is a [sprint-only exclusion](../../../../docs/specs/2026-10-02-cloud-service-foundation-runbook-design.md#33-current-sprint-component-boundary), not permanent platform retirement, removal of this project, supersession of ADR-0006, or selection of another UI. Generic Power Platform HR delivery remains in scope.

Applicable capability proof must use a reviewed, meaningful non-Code-App fixture with at least one actual declared component and reference/payload preservation. The empty, pre-Code-App [solution snapshot](../../solutions/README.md) is neither that proof nor full Dataverse parity. Missing source, component loss, and unsupported applicable capabilities remain `Blocked`. An out-of-scope Code App found in future delivery input must be reported and refused, not silently stripped. Export retention and privacy still follow the reviewed profile.

## Working with this project

```powershell
npm install
npm run dev     # local dev server
npm run build   # production build to dist/
pa app push     # deploy to the bound environment
```

`pa` is Microsoft's Power Apps Code Apps CLI (`npm install -g @microsoft/power-apps-cli` or run via `npx pa`). Requires Node.js 22+.

## Known limitation

The historical `hr/src/scripts/Sync-HrSolutionSource.ps1` record reports that `pac solution unpack` (CLI 1.43.6) failed to resolve a composite `BackgroundImageUri` reference for this Code App's CanvasApp-family component. This was recorded as a PAC limitation, not a sync-tool defect; it has not been newly reproduced or claimed fixed here, and the recorded version is not a supported-version selection. The committed solution folder remains an empty pre-Code-App snapshot. That limitation remains honest historical context, not a required current-sprint Code App gate.
