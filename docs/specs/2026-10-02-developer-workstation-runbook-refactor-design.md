# Developer Workstation Runbook Refactor Design

| Field | Value |
|---|---|
| **Version** | 1.3 |
| **Date** | 2026-10-26 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Approved |
| **Scope** | Windows 11 workstation subsystem for the Tenant 1 runbook sprint |
| **References** | [Tenant 1 Runbook End-to-End Design](2026-10-02-tenant-1-runbook-end-to-end-design.md), [Developer Workstation Implementation Plan](../plans/2026-10-02-developer-workstation-runbook-refactor-implementation.md), [Current Developer Workstation Runbook](../../infra/docs/runbooks/01-developer-workstation.md), [Operational Runbooks Design](2026-09-26-operational-runbooks-design.md), [Infrastructure Domain](../../infra/README.md) |

## 1. Status and Execution Gate

The user approved this workstation subsystem of the [Tenant 1 end-to-end lifecycle](2026-10-02-tenant-1-runbook-end-to-end-design.md) on 2026-10-02. It is implementation-planning authority for its stated local scope. Approval does not authorize a live Apply, cloud authentication, provider access, or provider mutation.

The existing workstation assessment and Apply engine remains the starting point. This proposal refactors and extends it; it does not justify a second workstation framework.

## 2. Problem and Outcome

The current workstation runbook has a substantial tested foundation: read-only assessment, a digest-bound execution manifest, explicit Apply, `ShouldProcess`, exact tool resolution, evidence, and read-back. Its policy still permits `Present` for several tools, does not establish the complete pipeline and Power Platform compatibility set, and does not yet prove restart-safe continuation or the complete lifecycle on a fresh laptop.

The proposed subsystem produces an approved Windows 11 workstation that:

- can clone and validate then-current `main` in an external worktree;
- has exact supported versions of every tool required by provider assessment, Azure Pipeline administration, Bicep, and Power Platform DEV delivery;
- can assess, plan, receive digest approval, Apply, and read back local prerequisites;
- records evidence that survives restart without reusing stale approval;
- can restore Tenant 1 private intent and state from encrypted backup without committing either;
- supports only attended interactive authentication for local orchestration; and
- proves a second unchanged workstation run has no `Create` or `Update`.

## 3. Scope

### 3.1 Included

- Refactor of the existing workstation policy, schemas, assessment, initialization, tests, and runbook.
- Windows 11 and Windows PowerShell 5.1 compatibility plus a reviewed PowerShell 7 version.
- Git, GitHub CLI, Azure CLI, Bicep, Azure DevOps CLI extension, PAC CLI, Pester, and repository validation prerequisites.
- Tools needed to review and operate Azure Pipelines and Power Platform Build Tools 2.0; the Build Tools extension itself remains an Azure DevOps organization capability assessed by the cloud subsystem.
- Exact executable path, version, and SHA-256 identity in each run.
- External worktree, path-budget, current-user write/delete, clean-source, and current-main validation.
- Restart-safe evidence and approval invalidation.
- Encrypted backup and separate restore prerequisites for Tenant 1 local intent and state.
- Fresh Windows 11 laptop acceptance.

### 3.2 Excluded

- Cloud authentication during workstation assessment or installation.
- Tenant, provider, pipeline, or Power Platform mutation.
- Installing Azure DevOps organization extensions.
- Creating a service principal, federated credential, application user, service connection, or environment.
- Storing credentials, token caches, tenant-private values, or raw provider output in workstation evidence.
- Editing vendored skills or installing repository-bundled agents or skills on the machine.
- Weakening execution policy, endpoint protection, Conditional Access, filesystem permissions, or organization policy.
- Requiring the legacy HR control-plane Code App or its specific `BackgroundImageUri` pack/unpack capability for this sprint.

## 4. Current Baseline

The current [runbook](../../infra/docs/runbooks/01-developer-workstation.md), policy, scripts, module helpers, and tests are retained where they satisfy this contract.

| Existing capability | Disposition |
|---|---|
| Read-only `Test-DeveloperWorkstation.ps1` assessment | Keep and extend. |
| `Initialize-DeveloperWorkstation.ps1` plan, execution manifest, Apply, `-WhatIf`, and `ShouldProcess` | Keep and extend. |
| Closed policy and schema | Revise in place; do not introduce a parallel policy. |
| Exact Windows PowerShell 5.1 and Pester 5.7.1 requirements | Retain unless a separately reviewed compatibility finding requires a design amendment. |
| `Present` policies for delivery-critical CLIs | Replace with exact reviewed versions or an exact allowlist that is fixed in the approved execution manifest. |
| External worktree convention | Retain and enforce. |
| Interactive authentication descriptions | Retain as later manual prerequisites; assessment and Apply do not authenticate. |
| Current evidence and approval expiry rules | Align with the shared lifecycle contract and strengthen restart handling. |

The exact supported versions for PowerShell 7, GitHub CLI, Azure CLI, Bicep, Azure DevOps CLI extension, and PAC CLI must be selected from current first-party compatibility evidence during implementation planning. This specification does not invent version numbers. No implementation may leave a delivery-critical tool at an unconstrained `Present` policy.

## 5. Proposed Contracts

### 5.1 Public Entry Points

The subsystem keeps two independently usable thin entry points:

```text
Test-DeveloperWorkstation.ps1
Initialize-DeveloperWorkstation.ps1
```

`Test-DeveloperWorkstation.ps1` is read-only except for its external evidence directory. `Initialize-DeveloperWorkstation.ps1` produces the plan and execution manifest by default; local mutation requires explicit `-Apply`, an exact approved digest, fresh state, and per-action `ShouldProcess`.

The umbrella lifecycle may call these entry points, but neither script imports or invokes the umbrella.

### 5.2 Inputs

Required inputs are:

- explicit repository root and expected source commit;
- explicit external evidence root and run ID;
- expected machine identity;
- reviewed workstation policy path and digest;
- external worktree root;
- optional approved execution-manifest path and digest for Apply; and
- explicit paths for restored Tenant 1 intent and state validation, without reading or serializing their values.

There is no default Tenant 1 content path that causes cloud access. The workstation subsystem checks only local path, ignored/untracked status, schema, backup, and restore predicates.

### 5.3 Outputs

The subsystem writes allowlisted records below the shared run root:

- workstation assessment;
- ordered local action plan;
- shared execution manifest;
- one action envelope per attempted local action;
- tool identity inventory;
- repository and worktree validation result;
- restart and invalidation status; and
- workstation summary.

Outputs contain tool paths, product versions, executable hashes, package IDs, result classifications, digests, timestamps, and non-sensitive machine labels. They contain no credentials, tenant-private values, raw file hashes that would expose private content, or provider contexts.

## 6. Version and Tool Policy

The revised policy is closed and schema-validated. Every delivery-critical component declares:

- exact product or extension identifier;
- trusted installation source;
- exact version or reviewed finite allowlist;
- version command and parser;
- architecture and host constraints where relevant;
- install disposition: `Automated`, `Manual`, `Recommended`, or `VerifyOnly`;
- elevation and restart expectations;
- exact post-install read-back; and
- first-party reference.

The minimum compatibility set covers:

| Capability | Required component |
|---|---|
| Script hosts and tests | Windows PowerShell 5.1, reviewed PowerShell 7, Pester 5.7.1 |
| Source and worktrees | Git |
| Repository context | GitHub CLI |
| Azure and Bicep | Azure CLI and Bicep CLI component |
| Azure DevOps administration | Azure DevOps CLI extension and supported REST access from PowerShell |
| Power Platform package and context operations | PAC CLI version proven to pack/import the committed HR solution or a documented Build Tools-only boundary |
| Local editing and optional operator experience | VS Code and reviewed extensions, without making editor state a cloud prerequisite |

At the user's request, the legacy HR control-plane Code App at `hr/src/apps/hr-control-plane/` and its specific `BackgroundImageUri` pack/unpack case are excluded from the current Tenant 1 runbook, replica, and handover sprint. This is a sprint-only scope decision, not platform retirement or exclusion of all Power Platform delivery. Historical source and the [recorded PAC limitation](../../hr/src/solutions/README.md) remain; no fix or current support is claimed. [ADR-0006](../adr/0006-agentic-toolset-and-hr-control-plane.md) still records the control-plane Code App choice; no replacement UI is selected.

PAC remains in the exact-version toolset. Applicable pack/unpack capability must be proven with a reviewed, meaningful non-Code-App fixture containing at least one actual declared component, with its references and associated payload preserved through the round trip. The current empty, pre-Code-App HR snapshot is not capability proof or full Dataverse parity. Missing source, component loss, or any unproven applicable capability remains `Blocked`; installation alone is insufficient. Any out-of-scope Code App found in future delivery input must be reported and refused against the declared scope, never silently stripped to make packaging pass.

Each executable resolves to exactly one canonical physical path. Ambiguous PATH results, changed files, changed versions, untrusted sources, or parser failures are `Blocked`; there is no first-match selection.

## 7. Worktree and Repository Contract

Task worktrees remain outside the primary checkout under:

```text
Source\<repository-context>\wt\<sprint-branch>
```

The primary checkout remains at `Source\<repository-context>\<repository>`; `wt` is its sibling, never a directory inside the checkout. The user approved this location revision on 2026-10-26. It supersedes worktree-location examples in earlier implementation plans, not their other constraints or the evidence and tenant-private configuration roots. The [current workstation runbook](../../infra/docs/runbooks/01-developer-workstation.md#external-worktree-prerequisite) owns the root-resolution and safe-relocation procedure.

The runbook:

1. validates current-user create/write/delete access without changing ACLs;
2. calculates the checkout path budget against tracked paths;
3. confirms the repository remote and expected source commit;
4. refuses a dirty, conflicted, sparse, or ambiguous source checkout where the operation requires clean state;
5. validates required repository assets and the absence of prohibited plugin or private files;
6. invokes repository tests or validation only through reviewed local commands; and
7. records paths relative to approved roots in sanitized evidence.

It never enables `core.longpaths`, relocates a user profile, weakens ACLs, edits source, or cleans a working tree automatically.

## 8. Assessment, Plan, Apply, and Read-Back

### 8.1 Assessment

Assessment:

- refuses CI, remoting, services, scheduled tasks, background sessions, and non-interactive hosts;
- proves Windows 11 build and architecture;
- validates repository, worktree, policy, evidence-root, and private-file boundaries;
- resolves and fingerprints required tools;
- classifies each prerequisite as `NoChange`, `Create`, `Update`, `Manual`, `Blocked`, or `Refused`; and
- performs no installation, authentication, persistent configuration, or provider call.

### 8.2 Plan and Approval

The plan is deterministic for the assessment and binds:

- machine and source commit;
- policy and assessment digests;
- exact ordered actions;
- package IDs, versions, sources, and scopes;
- tool identities;
- expected restart behavior;
- evidence root; and
- approval expiry.

The reviewer approves the execution-manifest digest, not a console summary.

### 8.3 Apply

Apply:

- requires explicit `-Apply`;
- revalidates all bound inputs immediately before mutation;
- treats `-WhatIf` or declined confirmation as authoritative;
- invokes only an allowlisted local action through its exact tool path;
- keeps every native mutation behind `ShouldProcess`;
- stops on the first failed or indeterminate action; and
- reads back the exact postcondition before marking the action complete.

Manual license acceptance, interactive installer UI, elevation, or restart remains visible and cannot be auto-accepted.

### 8.4 Second Run

After a successful Apply and any required restart, a fresh assessment and newly approved execution manifest must classify all workstation prerequisites as `NoChange`. Reusing the first approval after restart is prohibited.

## 9. Restart-Safe Evidence and Recovery

Restart safety means completed evidence survives; it does not mean stale execution resumes automatically.

- Every action envelope is written atomically after postcondition read-back.
- The summary distinguishes completed, failed, pending, manual, and not-attempted actions.
- A restart invalidates the active approval and execution manifest.
- The next session performs a full assessment, adopts only exact read-back postconditions, and creates a new plan and digest.
- A partially installed tool is classified from current state, not from the prior attempted action.
- Recovery never uninstalls a tool, rolls back a package, edits PATH broadly, or weakens security to recreate pre-state.

## 10. Authentication Boundary

Authentication occurs only after workstation acceptance and as an explicit prerequisite of the cloud runbook:

- GitHub CLI uses an attended supported browser/device flow.
- Azure CLI uses an attended tenant-specific interactive flow.
- Azure DevOps context is independently read back even when it reuses Azure CLI authentication.
- PAC CLI uses an attended named profile for the exact environment.
- Any Entra or editor extension context is treated as separate unless the target script independently reads back and validates it.

The available Azure extension context observed during design is not accepted as Tenant 1 evidence. No token or cache is copied between tools, and no authentication result enters the workstation evidence.

## 11. Fresh-Laptop Acceptance

A fresh Windows 11 laptop is mandatory end-to-end acceptance, not an optional demonstration:

1. Clone then-current `main`.
2. Create the approved external worktree.
3. Run workstation assessment, plan, digest approval, Apply, and read-back.
4. Restart when required, reassess, and prove workstation `NoChange`.
5. Restore Tenant 1 intent and state from encrypted backup to reviewed local paths and validate them without committing either.
6. Authenticate interactively to each required Tenant 1 context.
7. Run the cloud foundation lifecycle and obtain no `Create` or `Update` against the already accepted foundation.
8. Run or verify the exact-SHA Azure Pipeline and Power Platform DEV read-back.
9. Preserve raw evidence outside Git and contribute only the sanitized acceptance record.

Failure at steps 5-8 can fail the overall fresh-laptop acceptance even when the workstation itself is correctly initialized.

## 12. Implementation Decomposition

The workstation implementation plan uses these ordered units:

1. Add failing schema and policy tests for exact version requirements and delivery-tool coverage.
2. Revise the existing policy and schema rather than create parallel artifacts.
3. Extend assessment for exact tool identity, worktree, repository, private-file, and compatibility checks.
4. Extend deterministic planning and shared execution-manifest fields.
5. Extend Apply and postcondition read-back through the existing `ShouldProcess` core.
6. Add atomic action evidence and restart-invalidation tests.
7. Add synthetic partial-install and post-restart recovery tests.
8. Rewrite the workstation runbook and catalogue links.
9. Run focused tests, full infrastructure tests, repository validation, and a non-live clean-machine fixture.
10. Schedule the attended fresh-laptop acceptance only after the cloud subsystem is ready.

Tests use injected command runners and temporary external directories. They do not install software, authenticate, or contact providers.

## 13. Acceptance Criteria

The workstation subsystem is acceptable only when:

- all policy, schema, module, script, and static safety tests pass in Windows PowerShell 5.1 and the selected PowerShell 7 version;
- delivery-critical tools use exact reviewed version contracts;
- assessment performs no install, authentication, provider call, or source mutation;
- `-WhatIf`, missing approval, digest drift, machine drift, source drift, and tool drift prevent mutation;
- every approved action has exact read-back and allowlisted evidence;
- interruption preserves completed evidence and requires a new assessment and approval;
- the first accepted Apply reaches the reviewed state;
- the second unchanged run has no `Create` or `Update`;
- the external worktree and repository validation contracts pass; and
- the fresh-laptop sequence in section 11 passes as part of the umbrella acceptance matrix.

## 14. Risks and Non-goals

| Risk | Treatment |
|---|---|
| Exact versions become obsolete | Change them through reviewed policy and tests; never float silently during a run. |
| Tool installation appears to prove cloud readiness | Keep authentication, authorization, and provider state in the cloud subsystem. |
| Restarts invite stale-resume behavior | Persist evidence, invalidate approval, and reassess from current state. |
| Machine-specific paths leak into committed review | Keep raw paths local and sanitize to approved labels. |
| PAC compatibility differs between local and pipeline tooling | Validate both contracts separately and record the accepted division of responsibility. |

This subsystem does not create pipelines, identities, cloud resources, environments, tenants, licenses, roles, repositories, or publications. It does not prove Tenant 1 readiness by itself and does not reactivate a cloud Apply path.
