# HR Solution Sources

| Field | Value |
|---|---|
| **Version** | 1.4 |
| **Date** | 2026-10-26 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | HR |
| **References** | [Power Platform Solution Foundation Design](../../../docs/specs/2026-09-24-power-platform-solution-foundation-design.md), [Current Sprint Component Boundary](../../../docs/specs/2026-10-02-cloud-service-foundation-runbook-design.md#33-current-sprint-component-boundary), [Power Platform DEV Delivery Plan](../../../docs/plans/2026-10-02-power-platform-dev-delivery-implementation.md), [HR Control Plane Code App Wireframe Design](../../../docs/specs/2026-09-24-hr-control-plane-code-app-wireframe-design.md), [HR Journey and RACI](../../../docs/hr-journey-and-raci.md) |

This folder contains unpacked, reviewable Power Platform solution source owned by the HR domain.

Do not commit exported solution ZIP files, environment-specific connection values, secrets, personal data, or generated build output. The Infrastructure solution is imported before the HR solution in each Power Platform ALM stage.

## Current state

One foundation solution was historically exported from Tenant 1 DEV. The committed snapshot and the historical environment record are not equivalent:

| Solution | Tenant | Publisher prefix | Committed snapshot |
|---|---|---|---|
| [`caldovahrfrontier`](caldovahrfrontier/) | Tenant 1 (Caldova) | `calhr` | Empty, pre-Code-App foundation snapshot: no Dataverse tables or declared root components. Not proof of full Dataverse parity or packaging capability. |

The historical Tenant 1 DEV record includes the [`hr-control-plane`](../apps/hr-control-plane/README.md) Code App wireframe, added through `pa app push`; this committed snapshot predates that addition. This is not a fresh environment read-back.

[`hr/src/scripts/Sync-HrSolutionSource.ps1`](../scripts/README.md) exports the unmanaged solution and unpacks it here. Accept a synchronization result only after verifying complete source against the reviewed component scope; the existing snapshot must not be described as an exact mirror of Dataverse.

## Historical Code App limitation

The recorded `pac solution unpack` failure with CLI 1.43.6 could not resolve a composite `BackgroundImageUri` reference for the Code App's CanvasApp-family component after the app was added. It was recorded as a PAC limitation, not a sync-tool defect. The issue is preserved as historical evidence, not newly reproduced, fixed, or proof that any current version supports it. The historical version is not a supported-version selection.

## Current sprint gate

At the user's request, the legacy Code App and that specific image-reference pack/unpack case are excluded from the current Tenant 1 runbook, replica, and handover sprint under the [current component boundary](../../../docs/specs/2026-10-02-cloud-service-foundation-runbook-design.md#33-current-sprint-component-boundary). Historical files and [ADR-0006](../../../docs/adr/0006-agentic-toolset-and-hr-control-plane.md) remain; this is not permanent platform retirement or a replacement-UI decision.

Generic HR solution delivery still requires exact PAC versions, Build Tools 2.0, WIF, provenance, approval, read-back, pipeline privacy, and no component loss. Remaining pack/unpack proof must use a reviewed, meaningful non-Code-App fixture with at least one actual declared component and preservation of its references and associated payload. This empty snapshot is not that proof. Missing source for a declared in-scope component, component loss, or unproven applicable capability remains `Blocked`; fixture success does not establish delivery readiness. Report and refuse any out-of-scope Code App in future delivery input, never silently remove it to make packaging pass. The exclusion does not automatically widen or relax export privacy.

`docs/solution-design.md` §7 documents an eventual two-solution split (`GFHRPlatformCore` / `GFHRMasterDataAgent`, Tenant 3 naming) once there is enough content to justify separating shared plumbing from a per-use-case agent. That split has not happened yet — there is currently one foundation solution, for one tenant.
