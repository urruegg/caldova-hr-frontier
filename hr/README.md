# hr — HR Domain

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-17 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | HR |
| **References** | [HR Employee Journey](./docs/20-hr-employee-journey.md), [Implementation Roadmap](../docs/operating-model/05-implementation-roadmap.md) |

The HR employee journey is proposed to cover the data model, orchestration, experiences and agents for Caldova HR Frontier.

| Path                                                  | Contents                                                                                                                          |
| ----------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| `docs/`                                               | [20 HR Employee Journey](docs/20-hr-employee-journey.md) — proposed stages, capabilities, Dataverse model, security and demo path |
| [src/solutions/README.md](src/solutions/README.md)    | HR solution-source ownership guidance; no Power Platform solution payload is imported in Phase 2                                  |

## Planned Solution Scope

The proposed HR domain solution will contain the Dataverse journey model, Power Automate orchestration, Power Apps experiences and Copilot Studio agents. Phase 2 imports guidance only: no Power Platform solution, app, flow, agent, Dataverse table, security role or `CaldovaHRFrontierHR` directory currently exists in this repository.

The future HR solution depends on `CaldovaHRFrontierInfra`: connection references, environment variable definitions and security roles are planned to live there. The Proposed Baseline sequence is that Infra is imported first, in every environment, every time.

## MVP scope

The MVP is three use cases, not the whole journey. See [Implementation Roadmap](../docs/operating-model/05-implementation-roadmap.md) §7.

| # | Use case                                                 | Stage    |
| - | -------------------------------------------------------- | -------- |
| 1 | Onboarding journey orchestration                         | Onboard  |
| 2 | Onboarding Assistant                                     | Onboard  |
| 3 | Offboarding checklist and access revocation handover     | Offboard |

Every capability in [20 HR Employee Journey](docs/20-hr-employee-journey.md) §3 is tagged **MVP** or **H2**. Confirm the tag before building.

## Conventions

- Logical names use the `ur_` prefix, lowercase, singular: `ur_journeytask`.
- Every connector binds through a **connection reference** (defined in Infra); every environment-specific value is an **environment variable**.
- **Descriptions are mandatory** on every table and column; Copilot Studio grounds on them.
- **No period in a Copilot Studio topic name**; a solution containing one cannot be exported.
- Sensitive HR columns use **column security profiles**. Verify with a non-admin account.
- Author in DEV, export, unpack and commit reviewable solution source. TEST and PROD receive managed solutions only.
