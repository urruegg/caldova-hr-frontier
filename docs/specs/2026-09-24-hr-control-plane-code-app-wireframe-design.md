# HR Control Plane Code App — Wireframe Bootstrap Design

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-24 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Active |
| **Scope** | HR |
| **References** | [ADR-0006 Agentic Toolset and HR Control Plane Split](../adr/0006-agentic-toolset-and-hr-control-plane.md), [HR Control Plane Mockup Idea](../../hr/docs/ideas/hr-control-plane-mockup-idea.md), [Power Platform Solution Foundation Design](2026-09-24-power-platform-solution-foundation-design.md), [BrandKit README](../brand/README.md) |

## Purpose

Bootstrap the Power Apps Code App project for the HR Employee Control Plane described in [ADR-0006](../adr/0006-agentic-toolset-and-hr-control-plane.md): a Vite + React + TypeScript project, themed with the GF BrandKit, reproducing the five structural regions of the reviewed mockup (header, nav rail, main content area, footer, action drawer) — with **no Dataverse connector, no data, and no interactive logic**. This is a wireframe milestone only.

## Decisions made autonomously

The maker was unavailable for live discussion during this design; every decision below is a stated assumption, not a confirmed instruction. Flag any of these for correction.

| # | Decision | Rationale |
|---|---|---|
| 1 | Bootstrap using Microsoft's official Power Apps Code Apps tooling (`npx degit microsoft/PowerAppsCodeApps/templates/vite`, then `pa app init` / `pa app push`), scaffold + bind + baseline-deploy to Tenant 1 DEV in one pass (Approach A of three presented) | Matches "bootstrap... to the DEV environment" literally; proves the deploy pipeline works before any real UI is layered in; this is the Microsoft-sanctioned path, avoiding hand-rolled deployment wiring |
| 2 | Project lives at `hr/src/apps/hr-control-plane/`, a new `apps/` sibling category next to `hr/src/scripts/` and `hr/src/solutions/` | A code app is a different kind of source (an npm/Vite project) than either PowerShell tooling or unpacked Dataverse XML; a dedicated category folder keeps that distinction visible and leaves room for further code apps without renaming anything |
| 3 | Reproduce the mockup's real nav rail items (Focus, Journey, Runs, Exceptions, Follow-ups, Agents, Field List, Audit) and real 3-column footer content (Platform / Governance / Status), not generic placeholders | The wireframe should stay recognisable as the same control plane the mockup and ADR-0006 describe, not a generic app shell |
| 4 | The mockup's `aside.drawer` (contextual slide-in panel, `role="dialog"`, used for resolve/assign/escalate actions) is the "action area" referenced in the task | It is the only distinct region in the mockup besides header/nav/main/footer that reads as an "action area" |
| 5 | `main` renders an empty/placeholder content region only — none of the mockup's fake triage tiles, journey ribbon, or decision-queue table/data are ported | "Without any functional code at all" — that dashboard content is demo data and JS logic, not shell structure |
| 6 | Target environment: Tenant 1 DEV, environment ID `346c2cb2-534d-e581-978f-4c293e25a146` (`caldovahrfrontier` Dataverse solution's environment) | Confirmed live via `pac` in the Power Platform Solution Foundation sprint; same environment the Dataverse solution already targets |
| 7 | The scaffolded template's own root `README.md` is rewritten to follow this repository's documentation metadata convention (six-field table) rather than excluded from the doc-metadata check | Unlike vendored Superpowers skills (pinned third-party snapshot), this project is owned and evolved by this repository long-term, so its README should read like the rest of the repo's documentation, not carry an exclusion |
| 8 | No `/add-dataverse` or other data-source connector is added in this milestone | Explicit instruction: "without any functional code at all" |

## Wireframe region mapping

| Mockup DOM element | Region | Wireframe content |
|---|---|---|
| `header.app-header` | Header | Logo/wordmark, environment pill, capacity meter, language/role switch, notification bell, persona avatar — structure and labels only, static placeholder values |
| `nav.nav-rail` | Nav | 8 static items (Focus, Journey, Runs, Exceptions, Follow-ups, Agents, Field List, Audit), no routing, no live counts |
| `main.main` | Main | Empty content region with a per-screen title placeholder; no triage tiles, ribbon, or table |
| `footer.app-foot` | Footer | 3-column layout (Platform / Governance / Status) plus bottom bar (disclaimer, copyright, privacy links), static text |
| `aside.drawer` | Action area | Slide-in panel shell (`role="dialog"`), closed by default, no wired actions |

## Theming

Consume `docs/brand/gf-fluent-theme.ts` directly (`gfLightTheme` / `gfDarkTheme`, `@fluentui/react-components` `Theme` objects) via `FluentProvider` at the app root. No new token values are introduced; `docs/brand/gf-tokens.css` is not needed by the React app.

## File structure (post-scaffold)

```text
hr/src/apps/hr-control-plane/
  power.config.json        # created by `pa app init`, environmentId = Tenant 1 DEV
  package.json
  src/
    App.tsx                # FluentProvider + AppShell composition, no routing yet
    components/
      AppHeader.tsx
      NavRail.tsx
      MainRegion.tsx
      AppFooter.tsx
      ActionDrawer.tsx
  README.md                 # rewritten to repository documentation convention
```

## Deployment plan

1. `npx degit microsoft/PowerAppsCodeApps/templates/vite hr/src/apps/hr-control-plane --force`
2. `npm install`
3. `pa app init -n 'HR Control Plane' -e 346c2cb2-534d-e581-978f-4c293e25a146`
4. Build the five wireframe components and wire them into `App.tsx` with the BrandKit theme
5. `npm run build`
6. `pa app push` (baseline deploy — pre-approved as part of the scaffold flow)
7. Update `hr/README.md` and `hr/src/solutions/README.md`'s sibling references to point at the new `apps/` folder

## Explicitly out of scope

- Any Dataverse table, connector, or generated service (`/add-dataverse` is not run)
- Any interactivity beyond, at most, nav item selection state
- The mockup's fake dashboard data, triage tiles, journey ribbon, decision-queue table
- Copilot Studio agent artefacts (tracked separately under `hr/src/solutions/caldovahrfrontier/`)
- Routing between nav items (a single static main region is enough for a wireframe)

## Result

Approach A was confirmed live by the maker and executed. Deviations from the plan above, discovered during implementation:

- **`pa` CLI has its own, separate auth cache from `pac`.** It required its own device-code sign-in (`pa auth login --device-code`) as the Tenant 1 Caldova admin before `pa app init` could resolve the environment; the first attempt hit a transient network error, the retry succeeded.
- **`pa app push` targets the environment's "preferred solution" by default, not `caldovahrfrontier`.** The first push landed the app outside our solution. Re-run with `pa app push -s dc6d5d75-8eb6-f111-aaae-7ced8d5f6af9` (the `caldovahrfrontier` solution ID, matching the maker portal URL shared at the start of this sprint) to add it to the correct solution.
- **Footer governance links use generic themed labels, not the mockup's ADR citations.** The mockup's `ADR-0004`/`ADR-0005`/`ADR-0007`/`ADR-0003` references predate this repository's ADR renumbering and would be wrong if reproduced verbatim; inventing corrected numbers in committed UI code carried the same risk. Footer status stat values are placeholders (`—`), not the mockup's fake numbers, for the same reason main-content data was excluded.
- **`hr/src/scripts/Sync-HrSolutionSource.ps1` cannot currently re-sync the solution now that the code app is in it.** `pac solution unpack` (CLI 1.43.6) fails to resolve a composite `BackgroundImageUri` reference for the code app's CanvasApp-family component. `hr/src/solutions/caldovahrfrontier/` still reflects the pre-code-app state of the solution until this is resolved upstream or worked around. Tracked as a known limitation, not silently patched.
- **Nav item selection and drawer open/close use local React state**, resolving the open question about what counts as "functional code": local UI-only state (no data, no computation) was treated as acceptable wireframe behaviour, consistent with a clickable prototype rather than a static image.
- The `apps/` folder name and the drawer-as-action-area mapping were both used as assumed, without further pushback from the maker.
