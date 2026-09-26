# Layered Operational Runbook Kit Design

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-26 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Infrastructure operations for Windows 11 developer workstations |
| **References** | [Infrastructure Domain](../../infra/README.md), [Bootstrap and Provisioning](../../infra/docs/17-bootstrap-and-provisioning.md), [Bootstrap Recovery](../../infra/docs/19-bootstrap-recovery.md), [ADR-0001](../adr/0001-azure-devops-as-engineering-control-plane.md), [ADR-0002](../adr/0002-github-first-bootstrap-and-the-role-of-azure-repos.md), [ADR-0003](../adr/0003-bicep-and-powershell-for-infrastructure-as-code.md) |

## 1. Purpose and Decision Status

This specification defines a future operational runbook kit for preparing a Windows 11 developer workstation, establishing the cloud service foundation, and handing the reusable repository to a customer through a sanitized new-repository export. It defines documentation structure, script boundaries, safety gates, permissions, evidence, recovery, testing, and rollout. It does not implement or authorize any runbook, script, cloud mutation, or customer publication.

The design and constraints recorded here form a Proposed Baseline for review. Acceptance of this specification would not approve future implementation changes or any candidate ADR.

The kit is owned by the Infrastructure domain. Operational instructions will live under `infra/docs/runbooks/`, beside the infrastructure they operate, rather than under the cross-cutting `docs/` domain. Focused PowerShell entry points will live under `infra/src/scripts/runbooks/` and will reuse the existing `Caldova.HrFrontier.Bootstrap` module and helpers instead of creating a second bootstrap framework.

[ADR-0001](../adr/0001-azure-devops-as-engineering-control-plane.md), [ADR-0002](../adr/0002-github-first-bootstrap-and-the-role-of-azure-repos.md), and [ADR-0003](../adr/0003-bicep-and-powershell-for-infrastructure-as-code.md) are **Proposed Baseline**, not Accepted. This specification may describe how a kit would operationalize them, but does not promote or approve them. Any implementation that changes their GitHub/Azure DevOps division of responsibility, repository direction, or Bicep/PowerShell boundary requires architecture review and an ADR disposition first.

## 2. Goals

The kit will:

1. Give an operator three ordered, independently usable runbooks with a common safety model.
2. Make assessment the default and require deliberate, reviewable approval before mutation.
3. Validate the selected workstation, repository, tenant, subscription, organization, project, Power Platform environment, and SharePoint site before acting.
4. Separate permissions needed to inspect state from permissions needed to change it.
5. Expose manual steps rather than disguising unsupported APIs, attended consent, or licensing decisions as automation.
6. Reuse existing manifests, discovery conventions, bootstrap helpers, and recovery rules.
7. Produce redacted, reviewable evidence without committing reports, tokens, credentials, tenant payloads, or personal data.
8. Export a customer-specific, history-free copy into a clean staging directory without rewriting, filtering, deleting, or otherwise altering the reusable source repository.

## 3. Non-goals and Explicit Exclusions

The kit will not:

- create a Microsoft Entra tenant, Azure DevOps organization, or other tenant boundary;
- purchase, assign, or bypass a product license;
- bypass interactive authentication, multifactor authentication, Conditional Access, admin consent, repository approval, environment approval, or separation of duties;
- deploy production workloads, import production solutions, or perform DEV-to-TEST-to-PROD workload promotion;
- migrate real HR data or include personal data in tests, plans, reports, staging, or examples;
- rewrite, filter, squash, delete, force-push, or otherwise destructively sanitize the reusable source repository;
- publish a customer repository as a side effect of export or validation;
- replace generic platform terms such as `GitHub`, `Azure`, `Workday`, `Dataverse`, `Power Platform`, or `SharePoint` indiscriminately;
- infer missing tenant intent, choose the first ambiguous object, broaden permissions to make a failed operation succeed, or report partial success as success;
- duplicate the UC-0001 PRD or define HR workload behavior.

## 4. Governing Constraints

The kit inherits the repository's architecture and governance:

- **Workday remains the system of record.** No runbook or export creates a competing store of employee master data ([ADR-0005](../adr/0005-workday-as-system-of-record.md), `FR-0009`).
- **Dataverse stores process state only.** It is not a repository for employee master data ([ADR-0007](../adr/0007-dataverse-process-state-boundary.md), `FR-0010`).
- **The Workday connector remains behind the governed Workday Access Layer.** No runbook grants an agent or operator script a direct Workday write path ([ADR-0009](../adr/0009-workday-access-via-connector-behind-governed-layer.md), `FR-0006` and `FR-0007`).
- **Workflow owns process; an agent owns only judgement.** These operational procedures are deterministic workflows and do not introduce an agent decision point ([ADR-0011](../adr/0011-workflow-first-process-architecture.md), `FR-0013` and `FR-0014`).
- **No agent decides about a person.** The kit does not assess or act on employment decisions (`FR-0005`).
- Every run selects one tenant and one stage or an explicit stage set. It must not process tenants in a matrix or combine evidence from different tenants.
- `DEV`, `TEST`, and `PROD` refer only to the Power Platform ALM stages. They are not interchangeable Azure infrastructure environments.

## 5. Layered Architecture

```text
Operator on Windows 11
        |
        v
Layer 1: runbook index and safety contract
infra/docs/runbooks/README.md
        |
        +--------------------+-----------------------+
        v                    v                       v
Layer 2: workstation   Layer 2: cloud          Layer 2: handover
01-developer-          02-cloud-service-        03-customer-
workstation.md         foundation.md            handover.md
        |                    |                       |
        +--------------------+-----------------------+
                             v
Layer 3: thin PowerShell entry points
infra/src/scripts/runbooks/*.ps1
                             |
                             v
Layer 4: existing bootstrap module and native tools
Caldova.HrFrontier.Bootstrap; PowerShell; Git; GitHub CLI;
Azure CLI; PAC CLI; Microsoft Graph/service REST APIs
                             |
                             v
Layer 5: reviewed intent, generated plans, read-back, evidence
tenant manifest + approved execution manifest + redacted summary
```

The layers separate explanation from execution. Runbooks state who may act, the prerequisites, expected prompts, manual steps, recovery, and evidence. Entry-point scripts validate parameters and coordinate one operation. Reusable parsing, context validation, redaction, retries, service calls, and check-then-act behavior belong in the existing bootstrap module. Native tools and service APIs remain replaceable behind injectable helpers so Pester tests never require live cloud data.

## 6. Planned Documentation and Script Structure

The implementation will create these artifacts:

```text
infra/
├── docs/
│   └── runbooks/
│       ├── README.md
│       ├── 01-developer-workstation.md
│       ├── 02-cloud-service-foundation.md
│       └── 03-customer-handover.md
└── src/
    └── scripts/
        └── runbooks/
            ├── Test-DeveloperWorkstation.ps1
            ├── Initialize-DeveloperWorkstation.ps1
            ├── Get-CloudFoundationPlan.ps1
            ├── Invoke-CloudFoundation.ps1
            ├── New-CustomerRepositoryExport.ps1
            └── Test-CustomerRepositoryExport.ps1
```

Tests will extend `infra/tests/pester/`. Reusable functions needed by the six entry points will be added to the existing bootstrap module in `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/`, grouped by responsibility. The implementation must not create another module with overlapping manifest, discovery, context, retry, evidence, or service-client behavior.

### 6.1 `infra/docs/runbooks/README.md`

The index defines the shared execution model, terminology, evidence location, approval model, redaction rules, common prerequisites, and escalation path. It links the runbooks in order and states which procedures may be run independently. It distinguishes:

- **reviewed intent**, which is the repository-owned prerequisite/tool allowlist for workstation setup, the tenant manifest for cloud foundation, or the customer-export manifest for handover;
- a **reviewed tenant manifest**, which records non-secret desired state under `infra/src/config/tenants/`;
- an **execution manifest**, which is generated from the current assessment and plan, names exact targets and allowed operations, carries a content digest, and is approved for one run;
- an **evidence summary**, which reports what was checked, planned, applied, verified, refused, or left manual without containing secrets or business payloads.

### 6.2 `01-developer-workstation.md`

This runbook assesses and, when explicitly approved, initializes a Windows 11 developer workstation. It covers supported PowerShell, Git, GitHub CLI, Azure CLI with Bicep support, PAC CLI, Pester, repository checkout, executable resolution, authentication-context checks, path handling, and writable out-of-repository evidence/staging locations.

Installation or upgrade is never implied by assessment. Unsupported operating systems fail the platform gate. The runbook must distinguish machine-wide installation, per-user installation, interactive sign-in, and repository-local validation, and state when elevation is required.

### 6.3 `02-cloud-service-foundation.md`

This runbook assesses and plans the foundation across:

- GitHub repository metadata, Environments, governance, and required connections;
- Microsoft Entra application/service-principal and exact federated trust;
- Azure tenant, subscription, role assignments, and Bicep `what-if`;
- Azure DevOps organization, project, Boards/GitHub connection, service connections, environments, approvals, and checks;
- Power Platform `DEV`, `TEST`, and `PROD` environment identities and approved metadata;
- exact SharePoint site collections declared in the selected tenant manifest.

The runbook orchestrates existing discovery and bootstrap capabilities where they exist. It does not replace their detailed contracts. Cloud mutation is limited to operations expressly present in an approved execution manifest and supported by an implemented, reviewed script path.

### 6.4 `03-customer-handover.md`

This runbook creates and validates a sanitized export for a new customer repository. It never edits the source working tree, source `.git` directory, source refs, source remotes, or source history.

The operator supplies:

- the clean source checkout and expected source commit;
- a destination staging directory outside the source repository;
- one reviewed customer-export manifest;
- the tenant alias and selected tenant-owned artifacts to retain;
- structured replacement values for explicitly identified fields;
- the expected validation commands.

Publishing is a distinct, explicit procedure after export validation and human review. The export script must not create a remote repository, add a remote, authenticate to a customer organization, push, or transfer ownership.

## 7. Common Execution Model

Every runbook follows the same state machine:

```text
Prerequisites
  -> Read-only assessment
  -> Generated plan / WhatIf
  -> Human approval of exact plan digest
  -> Apply (explicit -Apply plus ShouldProcess)
  -> Read-back verification
  -> Redacted evidence summary
  -> Recovery or close
```

### 7.1 Default behavior

Invoking a script without `-Apply` is non-mutating. It may validate local files, inspect installed tools, query allowlisted metadata, create an out-of-repository plan/report directory, or calculate the inventory for a disposable export. It may not create the export staging tree, install software, alter machine configuration, mutate a cloud control plane, change repository history, create a remote repository, or publish.

In this contract, non-mutating means that the assessed workstation, repository, cloud service, and export staging target do not change. Writing the requested plan, execution manifest, or redacted evidence summary to the approved external report location is the sole output exception; those files never authorize their own Apply.

`-WhatIf` must remain meaningful. Entry points that can mutate implement PowerShell `SupportsShouldProcess` and call `ShouldProcess` at the smallest reviewable target/action boundary. `-WhatIf` displays proposed operations and performs no mutation. `-Apply` does not override `-WhatIf`; if both are supplied, WhatIf wins and no mutation occurs.

### 7.2 Mutation gate

A mutating operation requires all of the following:

1. explicit `-Apply`;
2. schema-valid reviewed intent: the repository-owned workstation prerequisite policy, a tenant manifest, or a customer-export manifest, as applicable;
3. an execution manifest generated from fresh assessment, containing exact stable target IDs, allowed actions, source commit, tool/API versions, and a digest;
4. recorded human approval matching that exact digest;
5. authenticated-context validation against the selected workstation user, repository, tenant, subscription, organization, project, environment, and site as applicable;
6. a displayed change summary naming creates, updates, grants, removals, and manual actions;
7. confirmation through `ShouldProcess`, with `-WhatIf` support;
8. successful precondition and stale-evidence checks immediately before the first write.

Missing, stale, ambiguous, unauthorized, mismatched, or incomplete input causes refusal. `-Force`, if implemented for non-safety prompts, must never bypass these eight gates.

### 7.3 Plan and approval integrity

Plans are deterministic for the same normalized inputs. Approval binds to the execution-manifest digest, not to a filename or conversational statement. Any change in source commit, selected tenant, target stable ID, requested action, replacement map, tool version that changes interpretation, or assessment result invalidates approval and requires a new plan.

A plan distinguishes:

- `NoChange`: observed state already equals reviewed intent;
- `Create` or `Update`: an implemented mutation with exact target and postcondition;
- `Manual`: attended or unsupported action with owner and read-back check;
- `Blocked`: missing authority, license, consent, evidence, or platform support;
- `Refused`: unsafe, ambiguous, out-of-scope, or contradictory request.

Only verified `NoChange` and successfully read-back `Create`/`Update` operations count as successful automated outcomes. `Manual`, `Blocked`, and `Refused` remain visible and prevent a claim of complete foundation.

## 8. Script Contracts

| Script | Default behavior | Mutation behavior | Required output |
|---|---|---|---|
| `Test-DeveloperWorkstation.ps1` | Read-only checks of Windows 11, tool versions/resolution, repository state, and available external evidence/staging locations | None | Structured assessment and redacted summary |
| `Initialize-DeveloperWorkstation.ps1` | Produces an installation/configuration plan | With `-Apply`, approved execution manifest, context checks, and ShouldProcess, installs or configures only allowlisted workstation prerequisites | Per-item read-back, restart/sign-in/manual-step status |
| `Get-CloudFoundationPlan.ps1` | Runs current read-only discovery, compares exact observed IDs with reviewed intent, and creates the execution manifest | None | Plan, digest, required approvals, permission delta, and manual actions |
| `Invoke-CloudFoundation.ps1` | Validates and displays an approved plan without changing services | With `-Apply`, executes only implemented operations in the approved manifest | Per-service read-back and redacted evidence summary |
| `New-CustomerRepositoryExport.ps1` | Validates inputs and calculates an export plan without creating staging files | `-Apply` authorizes creation of a disposable local export from tracked source in clean external staging, not source mutation or publication | Export inventory, replacement log, exclusions, source commit, and residual-reference report |
| `Test-CustomerRepositoryExport.ps1` | Validates staging isolation, retained artifact allowlist, prohibited content, residual references, repository metadata, and full test suite | None | Pass/fail report with every residual and failed validation |

Local export creation is treated as a controlled write because it creates files, even though it does not mutate cloud state or the source repository. It therefore uses `-Apply` and ShouldProcess. The validator remains read-only.

## 9. Customer Export Design

### 9.1 Source and staging isolation

The export reads the source commit and tracked-file list from Git. It copies tracked source files to a newly created, empty staging directory outside the source repository. It excludes `.git` and never follows untracked files, ignored files, junctions, symbolic links that escape the source root, or generated evidence. A destination that is the source root, below the source root, already non-empty, or resolves through a link into the source root is refused.

The export contains no source history. If local Git metadata is needed for full repository validation, the runbook initializes a new disposable repository in staging only after sanitization and records that this history belongs to the export, not to the reusable source.

### 9.2 Tenant-artifact selection

Tenant-scoped manifests, parameter files, normalized discovery examples, and other tenant-owned artifacts are denied by default. The export manifest names each retained artifact by repository-relative path and intended customer scope. The exporter retains only that allowlist and refuses paths that are absent, untracked, duplicated through case differences, or outside approved tenant-owned locations.

Evidence directories and reports remain excluded even when they contain normalized data unless the export manifest explicitly identifies a synthetic documentation fixture permitted by repository policy.

### 9.3 Structured replacement

Replacement rules operate on allowlisted fields in supported structured formats, not on unrestricted text across the tree. Each rule identifies:

- repository-relative file path or constrained path pattern;
- format and field/key selector;
- expected old value or validation pattern;
- new value;
- required replacement count;
- whether the old value is permitted in explanatory provenance text.

The exporter parses and writes the supported structure, verifies the expected count, and records only non-secret replacement metadata. Unsupported formats or unmatched counts fail closed. Generic platform names and architectural terms are never global replacement targets.

### 9.4 Residual-reference detection

After replacement, the validator scans file names, directory names, and text content for source tenant aliases, IDs, domains, URLs, email suffixes, company-specific names, and other manifest-declared markers. Binary files are rejected unless explicitly allowlisted and independently inspectable. Every match is reported with path, line or location, marker category, and disposition.

A residual may be allowlisted only by an exact path-and-marker rule with a written reason, such as an ADR title retained for provenance. A broad directory, extension, or wildcard suppression is not valid. Any undisposed residual fails validation.

### 9.5 Validation and publication boundary

The disposable export must pass:

1. tracked-file and retained-artifact inventory checks;
2. prohibited-file, secret-pattern, personal-data fixture, and residual-reference negative checks;
3. Markdown metadata, UTF-8, and relative-link validation;
4. Pester and all other repository validation suites applicable to the export;
5. a clean disposable Git status after the export's initial snapshot, if a disposable repository is used;
6. human review of the redacted report and staged content.

Publication occurs only after those checks, through a separately invoked manual or future automated step that names the new remote and requires its own approval. Publication must refuse the reusable source remote and must never force-push.

## 10. Security and Permissions

Assessment and mutation use separate permission profiles. A successful read does not authorize a write, and an operator must not pre-emptively receive every mutation permission. Exact roles/scopes are selected from current official documentation and constrained to the reviewed target; where the platform cannot express the required least privilege, the action remains manual or blocked.

### 10.1 Assessment permissions

| Surface | Minimum assessment capability | Boundary |
|---|---|---|
| Workstation | Standard local user; read installed applications, executable paths, versions, environment, repository metadata, and destination attributes | No package install, machine policy change, elevation, or credential export |
| GitHub | Read repository metadata, rulesets, Environments, connection metadata, and relevant security configuration | Repository/organization secrets and token values are never read |
| Entra/Azure | Read selected tenant, application/service-principal/federated-credential metadata, subscription context, resources, and role assignments; execute Bicep `what-if` only with required read/validation access | No directory write, role grant, resource deployment, or cross-subscription enumeration |
| Azure DevOps | Read the selected organization/project, repository metadata, service-connection metadata, environments, checks, and Boards connection status where supported | No project, repository, pipeline, check, permission, or service-connection write |
| Power Platform | Read selected `DEV`/`TEST`/`PROD` environment identity, approved metadata, solution inventory required for foundation checks, and current authenticated user | No environment creation, solution import, DLP change, application-user creation, or business-data query |
| SharePoint | Resolve and read approved metadata for exact manifest-declared sites | No broad tenant search; no lists, files, pages, permissions, or content |

### 10.2 Mutation permissions

| Surface | Mutation capability, granted only for an approved operation | Boundary and separation |
|---|---|---|
| Workstation | Package installation or upgrade and allowlisted user/machine configuration; elevation only for an item that requires it | Interactive sign-in and license acceptance remain attended; no weakening of execution policy, endpoint protection, or organization policy |
| GitHub | Repository administration needed for exact Environment, rule, variable, or app-connection changes | Prefer repository scope; organization-owner action remains attended; no secret read-back or unrelated repository access |
| Entra/Azure | Exact directory-object update, federated credential operation, approved app consent, narrowly scoped role assignment, or approved Azure deployment capability | Admin consent and privileged role activation are attended; temporary roles use exact IDs and are removed/read back; no broader role as fallback |
| Azure DevOps | Exact project administration needed for approved connection, environment, check, or configuration changes | Organization creation and unsupported app authorization are manual; no source mirror or second product source unless separately approved |
| Power Platform | Environment administration for exact approved application-user, security-role, connection, DLP, or foundation metadata operations | Tenant/environment creation, license purchase, workload import, and production deployment are excluded; separate stage context validation is mandatory |
| SharePoint | Site-specific permission grant or approved site configuration for exact declared site IDs | Prefer selected-site grants; tenant-wide content access is not a fallback; content mutation is outside this kit |

Permissions are checked before planning and again immediately before Apply. An excessive permission is reported as a risk; it is not evidence that a broad action is allowed. Authentication material remains in supported credential stores and process memory and is never written to the plan or evidence summary.

## 11. Explicit Manual Steps

The runbooks must label manual work with an owner, prerequisite, expected screen or service, exact decision, and read-back check. The following stay manual unless an official supported API and a separately reviewed implementation become available:

| Manual condition | Required treatment |
|---|---|
| Tenant or Azure DevOps organization does not exist | Stop. Creation is excluded; direct the tenant owner to the official administrative process |
| Product license is absent | Stop. Record the missing license; do not purchase, assign, trial, or bypass it |
| Interactive device sign-in, MFA, Conditional Access, or terms acceptance is required | Pause for the named operator; never collect or automate credentials |
| Entra or Microsoft Graph admin consent is required | Show exact permissions and target application; an authorized administrator consents, then the kit reads back grants |
| Azure privileged role activation or temporary subscription assignment is required | Use attended least-privilege activation/assignment; record exact assignment IDs outside Git; verify cleanup |
| Azure Boards GitHub App installation/authorization or another connection lacks a supported automation surface | Perform the official attended flow; read back connection state where an official API permits |
| Power Platform environment capacity, region, license, or attended connector consent is required | Stop automation and route to the Power Platform administrator; never substitute another environment or identity |
| SharePoint selected-site consent or site-owner approval is required | An authorized administrator grants only the exact site permission; the kit verifies the site ID and resulting grant |
| Customer organization/repository creation, ownership acceptance, or publication authorization is required | Complete only after sanitized export validation; publication remains a separate explicit operation |

If a manual action cannot be read back through a supported interface, the runbook requires operator-provided confirmation and leaves the result `Manual`, not `Verified`.

## 12. Data Flow and Evidence

```text
Reviewed source + selected manifest + authenticated read context
        |
        v
Allowlisted assessment ------------------------+
        |                                      |
        v                                      |
Normalized observations                        |
        |                                      |
        v                                      |
Plan + exact targets + operations + digest     |
        |                                      |
        v                                      |
Human approval of digest                       |
        |                                      |
        v                                      |
Context revalidation -> ShouldProcess -> Apply |
        |                                      |
        v                                      |
Independent read-back -------------------------+
        |
        v
Redacted evidence summary / recovery record
```

Reports default outside Git, under a per-user local application-data directory such as `%LOCALAPPDATA%\CaldovaHrFrontier\runbook-evidence\<runId>\`. The caller may select another path only if it is outside the repository and export staging tree. The kit refuses a report destination inside any Git working tree unless a test explicitly uses a disposable temporary repository.

Evidence contains run ID, timestamps, source commit, manifest and plan digests, selected non-secret stable IDs, tool/API versions, action classification, ShouldProcess decision, status, sanitized error category, read-back result, and manual/recovery items. It excludes access/refresh/ID tokens, authorization headers, cookies, secrets, private keys, connection strings, raw service responses, SharePoint content, HR data, and command output that may contain them.

Logs and console output use the same redaction rules as files. Redaction is an allowlist transformation performed before serialization; post-write masking is insufficient. A redaction failure prevents report creation and fails the run.

## 13. Error Handling and Recovery

The kit fails closed. Each operation records its last proven state and stops dependent actions after a failure. Independent later operations do not continue merely to increase a success count.

| Failure | Required response | Recovery |
|---|---|---|
| Unsupported OS, missing tool, or incompatible version | Refuse the affected runbook before cloud authentication or export | Regenerate the workstation plan; apply an approved prerequisite change; reassess |
| Authentication/context mismatch | Perform no mutation and suppress credential-bearing output | Sign out or select the correct context through the official tool; rerun full assessment |
| Missing, stale, or ambiguous evidence | Mark the plan blocked; never infer intent or select a candidate | Collect a fresh complete assessment; review stable IDs; generate a new digest |
| Permission denied | Record the exact sanitized capability and target; never retry with a broader role automatically | Use the manual least-privilege path or escalate; rerun assessment |
| Plan drift before Apply | Invalidate approval and refuse the write | Reassess, regenerate, and reapprove |
| Partial cloud mutation | Stop dependent changes; do not label the service successful | Read back current state, produce an exact recovery plan, and require new approval |
| Failed postcondition | Treat the operation as failed even if the API returned success | Retry only when the official API defines safe idempotency; otherwise escalate with current state |
| Workstation restart required | Stop at a resumable boundary | Restart attended, reassess all prerequisites, and resume with a fresh plan if state changed |
| Export destination collision or source-path overlap | Write nothing or remove only the newly created empty staging directory | Select a new empty external destination and restart export |
| Replacement-count mismatch or residual reference | Do not publish; preserve the disposable staging copy only for attended diagnosis when safe | Correct the export manifest, delete the disposable copy, and generate a new export |
| Validation failure | Do not reinterpret partial passes as success | Fix source or structured export rules through review, then recreate the export from the original source commit |
| Evidence write/redaction failure | Do not claim completion | Keep cloud state unchanged where still possible; read back state and rerun into a safe external report path |

Recovery never weakens a context check, approval, permission boundary, replacement rule, or validation. Existing detailed bootstrap recovery remains authoritative for covered cloud failure states: [Bootstrap Recovery](../../infra/docs/19-bootstrap-recovery.md).

## 14. Official-reference Strategy

Implementation and runbook instructions may cite only:

1. Microsoft Learn for Windows, PowerShell, Azure, Microsoft Entra, Azure DevOps, Power Platform, Microsoft Graph, and SharePoint behavior;
2. GitHub Docs for GitHub and Git behavior exposed by GitHub;
3. repository ADRs, requirements, manifests, and domain documentation for repository decisions and constraints.

Community posts, search-result snippets, copied portal instructions, and undocumented endpoints are not normative. If official documentation does not support an API, permission, or unattended flow, the runbook marks the step manual or blocked.

Each external reference must support a specific instruction and include a direct stable URL. The initial implementation reference set includes:

- [PowerShell `ShouldProcess` guidance](https://learn.microsoft.com/en-us/powershell/scripting/developer/cmdlet/how-to-add-support-for-shouldprocess-calls);
- [Windows Package Manager `winget`](https://learn.microsoft.com/en-us/windows/package-manager/winget/);
- [Azure deployment what-if](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deploy-what-if);
- [Microsoft Graph permissions reference](https://learn.microsoft.com/en-us/graph/permissions-reference);
- [Microsoft Graph selected permissions overview](https://learn.microsoft.com/en-us/graph/permissions-selected-overview);
- [Azure DevOps security permissions](https://learn.microsoft.com/en-us/azure/devops/organizations/security/permissions?view=azure-devops);
- [Power Platform CLI reference](https://learn.microsoft.com/en-us/power-platform/developer/cli/reference/);
- [GitHub REST API permissions](https://docs.github.com/en/rest/authentication/permissions-required-for-fine-grained-personal-access-tokens);
- [Install the Azure Boards app for GitHub](https://learn.microsoft.com/en-us/azure/devops/boards/github/install-github-app?view=azure-devops).

References are checked during implementation and every material runbook revision. A changed portal or API is not silently reconciled: update the procedure and tests through review. The runbooks state the date on which attended UI instructions were last verified.

## 15. Testing and Acceptance

All tests use synthetic names, fake stable IDs, mocked native commands/service clients, and temporary directories. They must not authenticate to a live service or contain real tenant responses, credentials, HR records, or customer data.

### 15.1 Pester coverage

Pester tests under `infra/tests/pester/` will cover:

- default non-mutation for every entry point;
- `SupportsShouldProcess`, `-WhatIf`, declined confirmation, and explicit `-Apply`;
- refusal when the approved execution-manifest digest, source commit, authenticated context, target ID, evidence freshness, or required permission does not match;
- refusal of broad permissions, source-repository mutation, in-repository reports, non-empty staging, staging below source, symlink/junction escape, publishing, and force-push behavior;
- deterministic plans and idempotent re-runs when observed state already matches intent;
- one-tenant selection and exact separation of `DEV`, `TEST`, and `PROD`;
- selection of only allowlisted tenant artifacts;
- structured replacement counts and refusal of generic global replacement;
- residual marker detection in paths, text, structured values, case variants, and unsupported binary files;
- exact allowlist dispositions without wildcard suppression;
- fail-closed behavior for unauthorized, unavailable, stale, ambiguous, malformed, partial, and redaction-failed results;
- read-back postconditions and partial-mutation recovery output.

ShouldProcess tests inject or mock the mutation boundary and prove that no mutator is called in assessment, `-WhatIf`, refusal, or declined-confirmation cases.

### 15.2 Disposable export test

An acceptance fixture creates a temporary source repository containing synthetic tracked files, excluded tenant artifacts, structured customer fields, deliberate residual markers, ignored/untracked decoys, and a fake remote. The test exports to a separate temporary directory and proves:

- the source commit, status, refs, remote, and file hashes are unchanged;
- only tracked and selected files are copied;
- only structured allowlisted fields change;
- all seeded residuals are reported;
- failed validation prevents a publish-ready result;
- a clean fixture passes the full exported-repository validation suite.

Temporary material is deleted after tests. No report is written into the real repository.

### 15.3 Full validation and reviews

Acceptance requires:

1. the complete repository validation suite on the reusable source;
2. the complete applicable validation suite inside the disposable export;
3. negative tests for every refusal boundary;
4. an attended workstation dry run on Windows 11 with no mutation;
5. a mocked or sandboxed idempotency demonstration for each mutating script before any tenant use;
6. docs-agent review for metadata, English, links, UTF-8, placement, status, and catalogue policy;
7. architecture review whenever implementation could change or rely on acceptance of ADR-0001, ADR-0002, or ADR-0003, or affect ADR-0005, ADR-0007, ADR-0009, or ADR-0011.

No live production tenant or real customer repository is an acceptance-test target.

## 16. Rollout

Rollout is incremental and each phase has an independent stop gate:

1. **Documentation review.** Approve this design, then author the index and three runbooks with official references and explicit manual steps.
2. **Assessment-only tooling.** Implement workstation assessment, cloud planning, and export validation with mocked service tests. No mutation paths are enabled.
3. **Disposable local operations.** Implement workstation planning and customer export into temporary external directories. Validate source immutability and residual detection.
4. **Workstation Apply.** Enable only reviewed package/configuration operations on a disposable Windows 11 workstation, with ShouldProcess and read-back.
5. **Cloud Apply by service.** Enable one service surface at a time after permission review, mocked negative tests, sandbox evidence, and architecture review. A service without a safe supported API stays manual.
6. **Customer handover rehearsal.** Create and validate a fully synthetic export, conduct human review, and rehearse publication to a disposable new repository through a separate explicit process.
7. **Operational adoption.** Use the kit only after named owners accept the runbooks, recovery routes, evidence retention, and permission assignments.

Progress in one phase does not authorize a later phase. Production workload deployment and real customer publication remain separately approved activities.

## 17. Definition of Done

The operational runbook kit is complete only when:

- the four runbook documents exist under `infra/docs/runbooks/`, use the six-field metadata header, are linked from the Infrastructure documentation map, and contain no unresolved placeholder;
- the six named scripts exist under `infra/src/scripts/runbooks/` as thin entry points and reuse the existing bootstrap module/helpers;
- every mutating path is non-mutating by default and enforces `-Apply`, approved digest-bound execution manifest, fresh context validation, displayed change summary, ShouldProcess, `-WhatIf`, read-back, evidence, and recovery;
- permission guidance separates assessment from mutation for workstation, GitHub, Entra/Azure, Azure DevOps, Power Platform, and SharePoint;
- unsupported APIs, attended consent, authentication, licensing, privileged activation, and publication are explicit manual steps;
- reports default outside Git and contain only allowlisted, redacted evidence;
- customer export copies tracked source to clean external staging, retains only selected tenant artifacts, applies only structured allowlisted replacements, reports every residual, passes full validation, and never alters or publishes the source repository;
- Pester tests prove ShouldProcess behavior, refusals, idempotency, tenant/stage selection, residual detection, source immutability, redaction failure, partial-result failure, and recovery behavior;
- synthetic disposable export and full repository validation pass without live services or real data;
- docs-agent policy review is complete;
- architecture review has confirmed that no implementation silently treats ADR-0001, ADR-0002, or ADR-0003 as Accepted and that the stable HR architecture constraints remain intact.

## 18. Design Self-review

This design contains no implementation placeholder. “Future” identifies intentionally unimplemented artifacts rather than an unresolved decision. The ownership boundary is explicit: the specification is cross-cutting design documentation, while future operational content and scripts belong to Infrastructure. Assessment output and local export creation are distinguished; installation, configuration, cloud changes, and staging-tree creation are gated. Publication is separate from export. Manual outcomes cannot be reported as verified automation.

The three runbooks form one kit because they share the same manifest, plan, approval, evidence, and recovery contracts; each remains independently testable and can be implemented in a separate reviewed increment. The design does not authorize tenant creation, licensing, consent bypass, production deployment, real-data migration, generic replacement, destructive source rewriting, or cloud mutation.
