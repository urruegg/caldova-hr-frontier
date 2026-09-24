# Power Platform Solution Foundation Design

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-24 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Draft |
| **Scope** | HR Solution Architecture |
| **References** | [HR Solution Functional Design Intake](./2026-09-24-hr-solution-functional-design-intake-design.md), [Solution Design](../solution-design.md), [HR Solution Sources](../../hr/src/solutions/README.md) |

## Objective

Establish the reusable tooling and the tracked source for the HR domain's Power Platform solution: PowerShell scripts that connect to a tenant's Power Platform environment, export the unmanaged solution, and unpack it into `hr/src/solutions/`, plus the first committed (currently empty) solution source for Tenant 1 (Caldova, DEV). The scripts are written to be reused unchanged for Tenant 2 and Tenant 3 after handover — parameterized by tenant alias, never hardcoded to Tenant 1.

This is a **foundation** sprint: no Dataverse tables or Copilot Studio agent are created in Power Platform here, because none exist there yet. That is deliberately the next sprint, once this tooling exists to pull the result back into source control.

## Ground Truth (verified via `pac`, read-only, before writing this spec)

- Active PAC auth profile `caldova25156897` already exists and is interactively authenticated as `admin@caldova25156897.onmicrosoft.com`.
- Tenant 1 DEV environment: `hrfrontierdev.crm17.dynamics.com`, environment ID `346c2cb2-534d-e581-978f-4c293e25a146` — matches the reviewed `infra/src/config/tenants/caldova25156897.psd1` manifest's `Components.PowerPlatformEnvironmentDev.Id` and `PowerPlatform.DevUrl` exactly. No infra config needs to change.
- The solution: unique name `caldovahrfrontier`, friendly name "Caldova HR frontier", version `0.0.0.1`, unmanaged, publisher unique name `calhrfrontier`, **customization prefix `calhr`** (matches the confirmed Phase 4 decision). `RootComponents` is empty — genuinely no tables, forms, flows or agents exist in it yet.
- No PowerShell automation for Power Platform (`pac`) exists anywhere in this repository today. `infra/src/scripts/` automates tenant/identity/GitHub-governance bootstrap via Azure/GitHub/Azure DevOps REST APIs; it has no Dataverse solution lifecycle logic to build on or collide with.

## Decisions

### 1. One solution now, not the documented two-solution split

`docs/solution-design.md` §7 documents an eventual split into `GFHRPlatformCore` (Dataverse tables, security roles, connection references, environment variable definitions, shared agent components) and `GFHRMasterDataAgent` (the agent, its flows, the control plane app registration) — Tenant 3/GF naming, for the fully-built target. Only one solution exists in Power Platform today, for Tenant 1.

**Decision:** treat `caldovahrfrontier` as the one foundation solution for now. Do not create a second solution in Power Platform, and do not invent a Tenant-1-equivalent "Core"/"Agent" naming split that nobody has asked for. `hr/README.md`'s Solutions table is updated to state the current single-solution reality for Tenant 1 alongside the still-valid Tenant 3 target, rather than silently reconciling the two.

### 2. Scripts live in `hr/src/scripts/`, reading `infra/` read-only

The HR domain owns the Dataverse/Copilot Studio solution lifecycle; infra owns tenant/identity bootstrap. New scripts go in `hr/src/scripts/`, a new HR-owned sibling to `hr/src/solutions/`. They resolve a tenant's Power Platform environment URLs by reading (never writing) `infra/src/config/tenants/<TenantAlias>.psd1` — the same reviewed manifest infra's own bootstrap scripts already read from a different relative path. No file under `infra/` is created, modified, or deleted by this work.

### 3. Pull only — export and unpack; pack and import are separate future work

The request is scoped to reading the environment into source control. Pushing local changes back into Dataverse (`pac solution pack` + `pac solution import`) has no current use case — there is nothing local to push yet — and is left for a follow-up sprint once real content exists to round-trip.

### 4. Interactive auth only, parameterized by tenant

Tenant 1's OIDC/service-principal bootstrap is not yet fully live (`LifecycleState: IntentReviewed`, not deployed). These scripts authenticate the same way the operator already does today — an interactive PAC auth profile — selected or created per tenant alias. Non-interactive (CI/service-principal) auth is explicitly deferred until a tenant's infra bootstrap actually provisions a usable credential for this purpose.

### 5. A small reusable module behind thin entry-point scripts

Mirrors the exact pattern already established in `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/` (a module of `Public/` functions, each accepting an injectable native-command-runner scriptblock for Pester testability, with thin top-level `.ps1` entry points that parse CLI parameters and call into the module). This is what makes the tooling genuinely reusable and testable, not just a one-off script that happens to work once.

## Component Design

### File structure

```text
hr/
├── src/
│   ├── scripts/
│   │   ├── README.md
│   │   ├── Connect-PowerPlatformEnvironment.ps1
│   │   ├── Sync-HrSolutionSource.ps1
│   │   └── modules/
│   │       └── Caldova.HrFrontier.Solutions/
│   │           ├── Caldova.HrFrontier.Solutions.psd1
│   │           ├── Caldova.HrFrontier.Solutions.psm1
│   │           └── Public/
│   │               ├── Get-HrTenantPowerPlatformUrl.ps1
│   │               ├── Connect-HrPowerPlatformEnvironment.ps1
│   │               ├── Export-HrSolutionPackage.ps1
│   │               └── Expand-HrSolutionPackage.ps1
│   └── solutions/
│       ├── README.md                  (updated)
│       └── caldovahrfrontier/         (new — unpacked solution source, currently empty of business components)
└── tests/
    └── pester/
        └── SolutionLifecycle.Tests.ps1
```

### `Get-HrTenantPowerPlatformUrl`

**Purpose:** resolve a tenant's Power Platform environment URL for a given stage, from the reviewed tenant manifest.

**Signature:** `Get-HrTenantPowerPlatformUrl -TenantAlias <string> -Stage <'Dev'|'Test'|'Prod'>`

**Behavior:**
- Resolves the manifest path as `<repo-root>/infra/src/config/tenants/<TenantAlias>.psd1` — read-only, via `Import-PowerShellDataFile`.
- Throws a clear, actionable error if the manifest does not exist (fail closed — no inferred URL, matching the repository's evidence rules).
- Returns the string at `.PowerPlatform.<Stage>Url` (e.g. `.PowerPlatform.DevUrl`).

### `Connect-HrPowerPlatformEnvironment`

**Purpose:** ensure an authenticated PAC CLI profile is active for a tenant, without depending on ambient auth state.

**Signature:** `Connect-HrPowerPlatformEnvironment -TenantAlias <string> -Stage <'Dev'|'Test'|'Prod'> [-NativeCommandRunner <scriptblock>]`

**Behavior:**
1. Resolves `pac.exe` via `Get-Command pac -CommandType Application` (mirrors the git-executable-resolution hardening already in `.github/cli/verify-repository-setup.ps1`); throws if not found.
2. Resolves the environment URL via `Get-HrTenantPowerPlatformUrl`.
3. Computes a deterministic profile name `hr-<TenantAlias>-<stage>` (lowercase stage), and **validates it is ≤ 30 characters** (PAC's hard limit) — throws a clear error rather than silently truncating if a future tenant alias makes it too long.
4. Runs `pac auth list`, parses the table output for a row whose Name field exactly matches the computed profile name (regex anchored on `\[(?<idx>\d+)\]\s*(?<active>\*)?\s*(?<kind>\S+)\s+(?<name>\S+)`).
5. If found: `pac auth select --name <profileName>`. If not found: `pac auth create --name <profileName> --environment <url>` (this is the one interactive step — a login prompt appears only if no cached token exists).
6. Verifies success via `pac org who` exit code.
7. Returns an object: `{ TenantAlias, Stage, EnvironmentUrl, ProfileName }`.

**Testability:** all `pac` invocations go through the injectable `-NativeCommandRunner` scriptblock (default: actually invokes `pac.exe`), so Pester can supply canned stdout/exit-codes and assert exact argument construction without touching a live tenant — mirroring `infra/src/scripts/Invoke-TenantDiscovery.ps1`'s own testing pattern exactly.

### `Export-HrSolutionPackage`

**Purpose:** export a named, unmanaged solution from a tenant's **DEV environment only** to a local zip file.

**Signature:** `Export-HrSolutionPackage -TenantAlias <string> -SolutionUniqueName <string> -DestinationPath <string> [-NativeCommandRunner <scriptblock>]`

**Behavior:**
1. Calls `Connect-HrPowerPlatformEnvironment -TenantAlias $TenantAlias -Stage 'Dev'` — **Stage is hardcoded to Dev inside this function, not exposed as a parameter**, because `docs/solution-design.md` §7's ALM rule states managed solutions for TEST/PROD are pipeline-produced, never hand-exported. Exporting from Test/Prod through this tool would violate that rule, so the option does not exist.
2. Runs `pac solution export --name <SolutionUniqueName> --path <DestinationPath> --managed false --overwrite true --environment <resolved DEV url>` (explicit `--environment` on every call — never relies on ambient "currently selected org" state, matching the "no ambient state" pattern used throughout this repository, e.g. `-RepositoryRoot` always resolved explicitly rather than inferred from CWD).
3. Verifies the zip file exists and the command's exit code is 0; throws with the captured output otherwise.

### `Expand-HrSolutionPackage`

**Purpose:** unpack an exported solution zip into `hr/src/solutions/<SolutionUniqueName>/`, keeping the tracked source an exact mirror of the environment.

**Signature:** `Expand-HrSolutionPackage -ZipPath <string> -SolutionUniqueName <string> -SolutionsRoot <string> [-NativeCommandRunner <scriptblock>]`

**Behavior:**
1. Computes the target folder `<SolutionsRoot>/<SolutionUniqueName>/`.
2. Runs `pac solution unpack --zipfile <ZipPath> --folder <targetFolder> --packagetype Unmanaged --allowWrite true --allowDelete true --clobber true` — write/delete are enabled because the source of truth is the environment; git is the review and rollback safety net for what changed, not a locked local folder.
3. Verifies the exit code is 0 and the target folder is non-empty; throws otherwise.

### Entry-point scripts

**`Connect-PowerPlatformEnvironment.ps1`** — thin CLI wrapper exposing `-TenantAlias` and `-Stage` (default `Dev`), imports the module, calls `Connect-HrPowerPlatformEnvironment`, prints the result. Useful standalone for verifying connectivity to any of the three stages without exporting anything.

**`Sync-HrSolutionSource.ps1`** — the main entry point matching the request ("read out the solution using PAC and export and unpack"). Exposes `-TenantAlias` and `-SolutionUniqueName` (both mandatory — no hardcoded tenant or solution name, so it works unchanged for Tenant 2 and Tenant 3). Creates a temp working directory, calls `Export-HrSolutionPackage` then `Expand-HrSolutionPackage`, always removes the temp directory in a `finally` block (never commits the zip, per `hr/src/solutions/README.md`'s existing rule), and prints a summary (solution unique name, version parsed from the unpacked `solution.xml`, environment URL, timestamp) plus a `git status --porcelain` of the affected folder as a non-fatal convenience (skipped silently if `git` is unavailable).

## Testing

`hr/tests/pester/SolutionLifecycle.Tests.ps1`, using injected `-NativeCommandRunner` fakes throughout (no live tenant access in CI):

- `Get-HrTenantPowerPlatformUrl`: resolves each of Dev/Test/Prod correctly from a fixture manifest; throws clearly when the manifest file does not exist.
- `Connect-HrPowerPlatformEnvironment`: computes the correct profile name; throws when the computed name would exceed 30 characters; correctly parses a fixture `pac auth list` table to find an existing profile and calls `select` rather than `create`; falls back to `create` when no matching profile exists; propagates failure when `pac org who` fails.
- `Export-HrSolutionPackage`: constructs the exact expected `pac solution export` argument list, including the explicit `--environment` value and `--managed false`; **rejects any attempt to call it for Test/Prod** (Stage is not a parameter, so this is a structural test that the function signature has no such parameter, plus a behavioral test that it always requests the Dev URL).
- `Expand-HrSolutionPackage`: constructs the exact expected `pac solution unpack` argument list, including `--allowWrite true --allowDelete true`.
- The CI wiring: `.github/workflows/validate-repository.yml` adds `hr/tests/pester` to its required Pester path list, alongside `infra/tests/pester`.

## Documentation Updates

- `hr/src/scripts/README.md` (new) — purpose, both entry-point scripts, parameters, the Dev-only export constraint and why, and the explicit reuse story for Tenant 2 and Tenant 3.
- `hr/src/solutions/README.md` (updated) — replaces the now-inaccurate "No Power Platform solution payload is present" with the current state: one foundation solution (`caldovahrfrontier`, Tenant 1, publisher prefix `calhr`), currently holding no business components, synced via `Sync-HrSolutionSource.ps1`. Existing rules (no zips, no secrets, no personal data) are preserved unchanged.
- `hr/README.md` — the Solutions table gains a note distinguishing the current single-solution reality (Tenant 1) from the documented Tenant-3 Core/Agent target, so the two do not silently contradict each other.
- `.github/workflows/validate-repository.yml` — adds `hr/tests/pester` to the required Pester test paths.

## What Is Explicitly Out of Scope

- Splitting into two solutions (Core/Agent) — future work, once there is enough content to justify the split.
- `pac solution pack` / `pac solution import` (pushing local changes back into Dataverse) — future work, once local changes actually exist to push.
- Service-principal or other non-interactive authentication — deferred until a tenant's infra bootstrap provisions a usable credential for this purpose.
- Any Dataverse table, security role, connection reference, environment variable, Copilot Studio agent, or workflow — none of these exist in the Power Platform solution yet; this sprint only builds the tooling and commits the (still-empty) tracked source.
- Any change to `infra/`.

## Validation

- `hr/tests/pester/SolutionLifecycle.Tests.ps1` passes under Pester 5.7.1.
- `powershell -File .github/cli/verify-repository-setup.ps1` passes (documentation metadata on all new/updated markdown).
- A live, manual run of `Sync-HrSolutionSource.ps1 -TenantAlias caldova25156897 -SolutionUniqueName caldovahrfrontier` against the real Tenant 1 DEV environment succeeds and produces a `hr/src/solutions/caldovahrfrontier/` folder whose `solution.xml` matches the ground truth captured above (unique name, version `0.0.0.1`, publisher prefix `calhr`, empty `RootComponents`).
