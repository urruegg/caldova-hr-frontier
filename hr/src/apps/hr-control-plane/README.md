# HR Control Plane Code App

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-24 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | HR |
| **References** | [HR Control Plane Code App Wireframe Design](../../../../docs/specs/2026-09-24-hr-control-plane-code-app-wireframe-design.md), [ADR-0006 Agentic Toolset and HR Control Plane Split](../../../../docs/adr/0006-agentic-toolset-and-hr-control-plane.md), [HR Solution Sources](../../solutions/README.md) |

Power Apps Code App project for the HR Employee Control Plane described in [ADR-0006](../../../../docs/adr/0006-agentic-toolset-and-hr-control-plane.md). Built with Vite, React, and TypeScript on Microsoft's official Power Apps Code Apps template, themed with the GF BrandKit (`docs/brand/gf-fluent-theme.ts`).

## Current state

Wireframe milestone only: the five structural regions from `docs/brand/hr-control-plane-mockup.html` (header, nav rail, main, footer, action drawer) are reproduced with static placeholder content. There is no Dataverse connector, no data, and no business logic — only local UI state for nav selection and drawer open/close.

Deployed to Tenant 1 DEV (environment `346c2cb2-534d-e581-978f-4c293e25a146`), added to the `caldovahrfrontier` Dataverse solution (`power.config.json` records the binding).

## Working with this project

```powershell
npm install
npm run dev     # local dev server
npm run build   # production build to dist/
pa app push     # deploy to the bound environment
```

`pa` is Microsoft's Power Apps Code Apps CLI (`npm install -g @microsoft/power-apps-cli` or run via `npx pa`). Requires Node.js 22+.

## Known limitation

`hr/src/scripts/Sync-HrSolutionSource.ps1` cannot currently re-sync `hr/src/solutions/caldovahrfrontier/` once this code app is present in the solution: `pac solution unpack` (CLI 1.43.6) fails to resolve a composite `BackgroundImageUri` reference for the code app's CanvasApp-family component. This is a `pac` CLI limitation with Code Apps, not a defect in the sync tooling. Until it is resolved upstream, that folder continues to reflect the solution's state from before this code app was added.
