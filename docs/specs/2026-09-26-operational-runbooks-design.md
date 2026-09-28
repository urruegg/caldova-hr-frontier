# Layered Operational Runbook Kit Design

| Field | Value |
|---|---|
| **Version** | 1.1 |
| **Date** | 2026-09-26 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Infrastructure operations for Windows 11 developer workstations |
| **References** | [Infrastructure Domain](../../infra/README.md), [Bootstrap and Provisioning](../../infra/docs/17-bootstrap-and-provisioning.md), [Bootstrap Recovery](../../infra/docs/19-bootstrap-recovery.md), [ADR-0001](../adr/0001-azure-devops-as-engineering-control-plane.md), [ADR-0002](../adr/0002-github-first-bootstrap-and-the-role-of-azure-repos.md), [ADR-0003](../adr/0003-bicep-and-powershell-for-infrastructure-as-code.md) |

## 1. Purpose and Decision Status

This specification defines a future operational runbook kit for preparing a Windows 11 developer workstation, establishing the cloud service foundation, and handing the reusable repository to a customer through a sanitized new-repository export. It defines documentation structure, local script boundaries, attended authentication, safety gates, permissions, evidence, recovery, testing, and rollout. It does not implement or authorize any runbook, script, cloud mutation, or customer publication.

The design and constraints recorded here form a Proposed Baseline for review. Acceptance of this specification would not approve future implementation changes or any candidate ADR.

The kit is owned by the Infrastructure domain. Operational instructions will live under `infra/docs/runbooks/`, beside the infrastructure they operate, rather than under the cross-cutting `docs/` domain. Focused PowerShell entry points will live under `infra/src/scripts/runbooks/` and will reuse the existing `Caldova.HrFrontier.Bootstrap` module and helpers instead of creating a second bootstrap framework.

[ADR-0001](../adr/0001-azure-devops-as-engineering-control-plane.md), [ADR-0002](../adr/0002-github-first-bootstrap-and-the-role-of-azure-repos.md), and [ADR-0003](../adr/0003-bicep-and-powershell-for-infrastructure-as-code.md) are **Proposed Baseline**, not Accepted. This specification may describe how a local, attended kit would operationalize them, but does not promote or approve them. Any implementation that changes their GitHub/Azure DevOps division of responsibility, repository direction, or Bicep/PowerShell boundary requires architecture review and an ADR disposition first.

## 2. Goals

The kit will:

1. Give an administrator three ordered, independently usable runbooks with a common safety model.
2. Run every runbook and PowerShell script locally and interactively from that administrator's Windows 11 developer workstation.
3. Prefer device-code or device/browser authentication, with the person authenticating directly to the identity provider and completing MFA and Conditional Access.
4. Make assessment the default and require deliberate, reviewable approval before mutation.
5. Validate the selected local user, repository, tenant, subscription, organization, project, Power Platform environment, and SharePoint site before acting and after operations.
6. Separate permissions needed to inspect state from permissions needed to change it.
7. Expose manual steps rather than disguising unsupported APIs, attended consent, policy decisions, or licensing decisions as automation.
8. Reuse existing manifests, discovery conventions, bootstrap helpers, and recovery rules.
9. Produce redacted, reviewable evidence without committing reports, tokens, credentials, tenant payloads, or personal data.
10. Export a customer-specific, history-free copy into a clean staging directory without rewriting, filtering, deleting, or otherwise altering the reusable source repository.

## 3. Non-goals and Explicit Exclusions

The kit will not:

- use GitHub Actions or any other unattended pipeline to prepare, configure, validate, or hand over a tenant;
- create or modify `.github/workflows/`, invoke `workflow_dispatch`, depend on a runner, or create or manage a GitHub Environment as part of tenant preparation;
- use OIDC workload federation, workload identity, a service-principal automation identity, a client secret, PAT injection, `GH_TOKEN`, `GITHUB_TOKEN`, `AZURE_DEVOPS_EXT_PAT`, or another environment-variable authentication path for runbook execution;
- accept tokens, secrets, credentials, authorization headers, or authentication environment variables as script parameters or input files;
- create an unattended or headless execution path;
- create a Microsoft Entra tenant, Azure DevOps organization, or other tenant boundary;
- purchase, assign, or bypass a product license;
- bypass interactive authentication, multifactor authentication, Conditional Access, Security Defaults, admin consent, repository approval, environment approval, or separation of duties;
- deploy production workloads, import production solutions, or perform DEV-to-TEST-to-PROD workload promotion;
- migrate real HR data or include personal data in tests, plans, reports, staging, or examples;
- rewrite, filter, squash, delete, force-push, or otherwise destructively sanitize the reusable source repository;
- publish a customer repository as a side effect of export or validation;
- replace generic platform terms such as `GitHub`, `Azure`, `Workday`, `Dataverse`, `Power Platform`, or `SharePoint` indiscriminately;
- infer missing tenant intent, choose the first ambiguous object, broaden permissions to make a failed operation succeed, or report partial success as success;
- duplicate the UC-0001 PRD or define HR workload behavior.

GitHub repository configuration may still be performed by local PowerShell invoking `gh api` after the administrator completes the approved GitHub CLI browser/device login. GitHub Actions workflows and GitHub Environments are outside the tenant-preparation kit and are not created, changed, dispatched, or used by its runbooks.

## 4. Governing Constraints

The kit inherits the repository's architecture and governance:

- **Workday remains the system of record.** No runbook or export creates a competing store of employee master data ([ADR-0005](../adr/0005-workday-as-system-of-record.md), `FR-0009`).
- **Dataverse stores process state only.** It is not a repository for employee master data ([ADR-0007](../adr/0007-dataverse-process-state-boundary.md), `FR-0010`).
- **The Workday connector remains behind the governed Workday Access Layer.** No runbook grants an agent or operator script a direct Workday write path ([ADR-0009](../adr/0009-workday-access-via-connector-behind-governed-layer.md), `FR-0006` and `FR-0007`).
- **Workflow owns HR process; an agent owns only judgement.** The local operational procedures do not introduce an agent decision point or change the solution's deterministic process architecture ([ADR-0011](../adr/0011-workflow-first-process-architecture.md), `FR-0013` and `FR-0014`).
- **No agent decides about a person.** The kit does not assess or act on employment decisions (`FR-0005`).
- Every run selects one tenant and one stage or an explicit stage set. It must not process tenants in a matrix or combine evidence from different tenants.
- `DEV`, `TEST`, and `PROD` refer only to the Power Platform ALM stages. They are not interchangeable Azure infrastructure environments.
- The execution principal is always the attended administrator's delegated user identity. Target Entra applications or service principals created as eventual solution resources are managed objects, not execution identities. The scripts never switch to app-only execution.

## 5. Layered Architecture

```text
Administrator at a Windows 11 developer workstation
        |
        v
Layer 1: runbook index, local-only rule, and safety contract
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
Layer 3: thin local interactive PowerShell entry points
infra/src/scripts/runbooks/*.ps1
                             |
                             v
Layer 4: existing bootstrap module and authenticated native CLIs
Caldova.HrFrontier.Bootstrap; PowerShell; Git; GitHub CLI;
Azure CLI; PAC CLI; Microsoft Graph/service REST APIs
                             |
                             v
Layer 5: reviewed intent, generated plans, read-back, evidence
tenant manifest + approved execution manifest + redacted summary
```

There is no remote execution layer. No pipeline, runner, GitHub Actions job, GitHub Environment identity, federated trust, workload identity, service-principal automation identity, or secret injection sits between the administrator and the local entry point.

The layers separate explanation from execution. Runbooks state who may act, prerequisites, expected attended prompts, login and logout choices, manual steps, recovery, and evidence. Entry-point scripts validate parameters and coordinate one operation. Reusable parsing, context validation, redaction, retries, service calls, and check-then-act behavior belong in the existing bootstrap module. Native tools and service APIs remain replaceable behind injectable helpers so Pester tests never require live cloud data.

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

The index defines the local-only execution model, terminology, authentication state machine, evidence location, approval model, redaction rules, common prerequisites, and escalation path. It links the runbooks in order and states which procedures may be run independently. It distinguishes:

- **reviewed intent**, which is the repository-owned prerequisite/tool allowlist for workstation setup, the tenant manifest for cloud foundation, or the customer-export manifest for handover;
- a **reviewed tenant manifest**, which records non-secret desired state under `infra/src/config/tenants/`;
- an **execution manifest**, which is generated from current assessment and plan, names exact targets and allowed operations, carries a content digest, and is approved for one attended local run;
- an **evidence summary**, which reports what was checked, planned, applied, verified, refused, or left manual without containing secrets or business payloads.

### 6.2 `01-developer-workstation.md`

This runbook assesses and, when explicitly approved, initializes an administrator's Windows 11 developer workstation. It covers supported PowerShell, Git, GitHub CLI, Azure CLI with Bicep support, PAC CLI, Pester, repository checkout, executable resolution, secure CLI credential storage, authentication-context checks, path handling, and writable out-of-repository evidence/staging locations.

Installation or upgrade is never implied by assessment. Unsupported operating systems fail the platform gate. The runbook distinguishes machine-wide installation, per-user installation, interactive sign-in, and repository-local validation, and states when elevation is required.

### 6.3 `02-cloud-service-foundation.md`

This locally executed runbook assesses and plans the foundation across:

- GitHub repository metadata, non-Actions governance and protection settings, and required connections;
- Microsoft Entra target application and service-principal metadata for the eventual solution, without using those objects to execute this kit;
- Azure tenant, subscription, role assignments, and Bicep `what-if`;
- Azure DevOps organization, project, Boards/GitHub connection, service connections, environments, approvals, and checks;
- Power Platform `DEV`, `TEST`, and `PROD` environment identities and approved metadata;
- exact SharePoint site collections declared in the selected tenant manifest.

The runbook orchestrates existing discovery and bootstrap capabilities where they exist. It does not replace their detailed contracts. Cloud mutation is limited to operations expressly present in an approved execution manifest and supported by an implemented, reviewed local script path. The administrator's verified delegated identity performs every read and mutation.

### 6.4 `03-customer-handover.md`

This local runbook creates and validates a sanitized export for a new customer repository. It never edits the source working tree, source `.git` directory, source refs, source remotes, or source history.

The administrator supplies the clean source checkout and expected source commit, a destination staging directory outside the source repository, one reviewed customer-export manifest, the tenant alias and selected tenant-owned artifacts to retain, structured replacement values for explicitly identified fields, and the expected validation commands.

Publishing is a distinct, explicit attended procedure after export validation and human review. The export script must not create a remote repository, add a remote, authenticate to a customer organization, push, or transfer ownership.

## 7. Local Authentication and Execution Model

### 7.1 Authentication state machine

Every service session follows this state machine:

```text
Signed out
  -> Device challenge issued by supported CLI
  -> User authenticates directly with identity provider in browser/device flow
  -> MFA / Conditional Access / Security Defaults evaluation
  -> Supported CLI stores delegated tokens in its supported cache/credential store
  -> Identity and target context read-back
  -> Local script assessment / approved operations
  -> Final identity and target context read-back
  -> Optional supported CLI logout/clear chosen by operator and runbook
```

Credentials are **not passed to the script**. The administrator authenticates directly with the identity provider. Supported CLIs cache delegated tokens; the script invokes those authenticated CLIs and validates non-secret context without reading, printing, exporting, accepting, or storing tokens. Device code does not bypass and is not guaranteed to satisfy Security Defaults or Conditional Access. If policy blocks device code, the runbook stops and escalates for an approved attended browser-interactive method; policy is never weakened.

At initial or final read-back, any mismatch in account, tenant, subscription, GitHub host/owner/repository, Azure DevOps organization/project, or Power Platform environment causes refusal. Before successful initial context verification, the script permits only local prerequisite checks and the minimum identity metadata needed to diagnose the mismatch; it performs no other cloud reads and no mutation.

### 7.2 Preferred login, context, read-back, and logout

**Azure, Entra, Microsoft Graph, and Azure DevOps**

```powershell
az login --tenant <tenant-id> --use-device-code
az account set --subscription <subscription-id>
az account show --output json
az ad signed-in-user show --output json
```

The script compares tenant, subscription, and signed-in delegated user with reviewed intent before proceeding. Azure DevOps commands use this verified delegated Azure CLI context only where the [official Azure DevOps CLI documentation](https://learn.microsoft.com/en-us/azure/devops/cli/) supports it; the runbook never calls `az devops login`, supplies a PAT, or silently falls back to another identity. End-of-run cleanup is an explicit operator choice documented for the runbook. Where chosen, use only the officially supported commands and behavior:

```powershell
az logout
az account clear
```

The runbook explains that `az logout` signs out Azure CLI accounts and that `az account clear` clears the local subscription cache, and asks the operator to choose cleanup appropriate to the workstation. It never deletes Azure CLI cache folders manually.

**GitHub**

```powershell
gh auth login --hostname github.com --web --clipboard
gh auth status
```

The administrator completes GitHub CLI's device/browser flow. `--clipboard` copies the one-time device code for the attended flow; it does not provide a credential to the script. Authentication must use the operating system's secure credential store. If GitHub CLI would fall back to plaintext storage, the runbook stops until secure storage is available.

The baseline login requests the GitHub CLI's documented default OAuth scopes `repo`, `read:org`, and `gist`. The execution manifest must additionally name any operation-specific scope and repository or organization permission supported by the exact `gh api` endpoint; organization administration, when required, is attended and requires the narrow documented organization authority. Unneeded scopes are not requested, and absence of a required scope blocks the operation. `GH_TOKEN`, `GITHUB_TOKEN`, `--with-token`, PAT-based execution, plaintext credentials, and insecure storage are rejected. When cleanup is called for:

```powershell
gh auth logout --hostname github.com
```

**Power Platform**

```powershell
pac auth create --name <profile> --environment <url> --deviceCode
pac auth list
pac auth select --name <profile>
pac org who --environment <url>
```

Profile names follow the repository's existing deterministic convention: `hr-<TenantAlias>-<stage>`, with the reviewed tenant alias and one of `dev`, `test`, or `prod`. The script verifies that the computed name does not exceed PAC CLI's supported limit, then verifies the selected profile and environment-specific `pac org who` result before each stage operation and at final read-back. Cleanup uses only supported `pac auth clear` or official profile-management commands described by the [Power Platform CLI authentication reference](https://learn.microsoft.com/en-us/power-platform/developer/cli/reference/auth); it never exposes tokens or deletes cache files manually.

### 7.3 Operational state machine

Every runbook follows this sequence. For a wholly local operation that contacts no service, the authentication and service-context steps are explicitly `NotApplicable`, not silently skipped:

```text
Prerequisites
  -> Local attended authentication and context read-back
  -> Read-only assessment
  -> Generated plan / WhatIf
  -> Human approval of exact plan digest
  -> Apply (explicit -Apply plus ShouldProcess)
  -> Final identity, target, and operation read-back
  -> Redacted evidence summary
  -> Optional supported logout / recovery / close
```

Invoking a script without `-Apply` is non-mutating. It may validate local files, inspect installed tools, query allowlisted metadata after identity verification, create an out-of-repository plan/report directory, or calculate the inventory for a disposable export. It may not create the export staging tree, install software, alter machine configuration, mutate a cloud control plane, change repository history, create a remote repository, or publish.

`-WhatIf` remains meaningful. Entry points that can mutate implement PowerShell `SupportsShouldProcess` and call `ShouldProcess` at the smallest reviewable target/action boundary. `-WhatIf` displays proposed operations and performs no mutation. `-Apply` does not override `-WhatIf`.

### 7.4 Mutation gate

A mutating operation requires all of the following:

1. execution by an attended administrator in local PowerShell on Windows 11;
2. successful device/browser login and exact delegated-user context read-back for every contacted service, or an explicit `NotApplicable` for a wholly local operation;
3. explicit `-Apply`;
4. schema-valid reviewed intent;
5. an execution manifest generated from fresh assessment, containing exact stable target IDs, allowed actions, source commit, tool/API versions, and a digest;
6. recorded human approval matching that exact digest;
7. a displayed change summary naming creates, updates, grants, removals, and manual actions;
8. confirmation through `ShouldProcess`, with `-WhatIf` support;
9. successful permission, precondition, stale-evidence, and context checks immediately before the first write;
10. confirmation that no token/secret input, environment authentication, app-only identity, workflow file change, or unattended path is involved.

Missing, stale, ambiguous, unauthorized, mismatched, or incomplete input causes refusal. `-Force`, if implemented for non-safety prompts, must never bypass these gates. Final context read-back is required before success is reported.

### 7.5 Plan and approval integrity

Plans are deterministic for the same normalized inputs. Approval binds to the execution-manifest digest, not to a filename or conversational statement. Any change in source commit, delegated account, selected tenant, target stable ID, requested action, replacement map, tool version that changes interpretation, or assessment result invalidates approval and requires a new plan.

A plan distinguishes `NoChange`, `Create` or `Update`, `Manual`, `Blocked`, and `Refused`. Only verified `NoChange` and successfully read-back `Create`/`Update` operations count as successful outcomes. `Manual`, `Blocked`, and `Refused` remain visible and prevent a claim of complete foundation.

## 8. Script Contracts

All six scripts are local, interactive entry points. None accepts a credential, token, secret, client ID/secret pair, PAT, authorization header, or authentication environment-variable name/value. They invoke authenticated CLIs and consume only allowlisted identity/context fields from CLI read-back.

| Script | Default behavior | Mutation behavior | Required output |
|---|---|---|---|
| `Test-DeveloperWorkstation.ps1` | Read-only checks of Windows 11, tool versions/resolution, secure credential-store availability, repository state, and external evidence/staging locations | None | Structured assessment and redacted summary |
| `Initialize-DeveloperWorkstation.ps1` | Produces an installation/configuration plan | With `-Apply`, approved execution manifest, context checks, and ShouldProcess, installs or configures only allowlisted workstation prerequisites | Per-item read-back, restart/sign-in/manual-step status |
| `Get-CloudFoundationPlan.ps1` | Verifies delegated contexts, runs allowlisted read-only discovery, compares exact observed IDs with reviewed intent, and creates the execution manifest | None | Plan, digest, required approvals, permission delta, and manual actions |
| `Invoke-CloudFoundation.ps1` | Validates and displays an approved plan without changing services | With `-Apply`, executes only implemented operations in the approved manifest under the verified delegated user | Per-service final context/read-back and redacted evidence summary |
| `New-CustomerRepositoryExport.ps1` | Validates inputs and calculates an export plan without creating staging files | `-Apply` authorizes creation of a disposable local export from tracked source in clean external staging, not source mutation or publication | Export inventory, replacement log, exclusions, source commit, and residual-reference report |
| `Test-CustomerRepositoryExport.ps1` | Validates staging isolation, retained artifact allowlist, prohibited content, residual references, repository metadata, and full test suite | None | Pass/fail report with every residual and failed validation |

Local export creation is a controlled write because it creates files, even though it does not mutate cloud state or the source repository. It therefore uses `-Apply` and ShouldProcess. The validator remains read-only.

Target Entra applications and service principals may be created or configured as approved eventual-solution resources. They are never used to authenticate these scripts, and the scripts do not create an execution credential, switch identity, or continue app-only.

## 9. Customer Export Design

### 9.1 Source and staging isolation

The export reads the source commit and tracked-file list from Git. It copies tracked source files to a newly created, empty staging directory outside the source repository. It excludes `.git` and never follows untracked files, ignored files, junctions, symbolic links that escape the source root, or generated evidence. A destination that is the source root, below the source root, already non-empty, or resolves through a link into the source root is refused.

The export contains no source history and no `.git` file or directory anywhere in staging or the promoted export. Validation operates directly on exported files and must not initialize a repository.

The customer export excludes `.github/workflows/` in full. The exported repository contains no GitHub Actions workflow, reusable workflow, or workflow template. The source repository is not altered; this exclusion applies only while constructing the clean customer staging tree.

### 9.2 Tenant-artifact selection

Tenant-scoped manifests, parameter files, normalized discovery examples, and other tenant-owned artifacts are denied by default. The export manifest names each retained artifact by repository-relative path and intended customer scope. The exporter retains only that allowlist and refuses paths that are absent, untracked, duplicated through case differences, or outside approved tenant-owned locations.

Evidence directories and reports are excluded without exception. An exact synthetic documentation fixture may be retained only from `infra/tests/fixtures/` when its path, expected file digest, `SyntheticFixture` classification, and reason are bound into the reviewed export manifest.

### 9.3 Structured replacement

Replacement rules are exhaustive and exact. A JSON rule contains one tracked repository-relative `.json` path, one RFC 6901 pointer, exact old and new JSON values, and required count `1`. A Markdown rule contains one tracked repository-relative `.md` path, exact old and new text, and a reviewed positive occurrence count. Path patterns, validation patterns, wildcards, regular expressions, case-insensitive matching, directory-wide replacement, and inline provenance exemptions are prohibited. A retained occurrence requires a separate exact path-and-marker residual disposition with a written reason.

The exporter parses and writes the supported structure, verifies the expected count, and records only non-secret replacement metadata. Unsupported formats or unmatched counts fail closed. Generic platform names and architectural terms are never global replacement targets.

Customer-name changes in maintained Markdown use an exact per-file `MarkdownExact` rule: one tracked `.md` path, exact expected old text, exact new text, and reviewed occurrence count. Wildcards, regular expressions, directory-wide replacement, vendored skills, workflow paths, and unrestricted repository search-and-replace are prohibited. The writer validates BOM-free UTF-8, preserves the file's existing LF or CRLF convention, writes atomically, and records only digests and counts. Residual scanning must then prove that every undisposed source customer or tenant marker has been removed from all exported documentation.

### 9.4 Residual-reference detection

After replacement, the validator scans file names, directory names, and text content for source tenant aliases, IDs, domains, URLs, email suffixes, company-specific names, and other manifest-declared markers. Binary files are rejected unless explicitly allowlisted and independently inspectable. Every match is reported with path, line or location, marker category, and disposition.

A residual may be allowlisted only by an exact path-and-marker rule with a written reason. A broad directory, extension, or wildcard suppression is invalid. Any undisposed residual fails validation.

### 9.5 Validation and publication boundary

The disposable export must pass:

1. tracked-file and retained-artifact inventory checks;
2. prohibited-file, secret-pattern, personal-data fixture, and residual-reference negative checks;
3. a static assertion that the source workflow paths are unchanged and the customer export contains no `.github/workflows/` path;
4. Markdown metadata, UTF-8, and relative-link validation;
5. Pester and all other repository validation suites applicable to the export;
6. direct staged-tree inventory and byte validation without initializing or inspecting a staging repository;
7. human review of the redacted report and staged content.

Publication occurs only after those checks, through a separately invoked attended manual process that names the new remote and requires its own approval. Publication must refuse the reusable source remote and must never force-push.

## 10. Security and Permissions

The operator uses one delegated user identity per service session. Assessment and mutation capabilities are separate; a successful read does not authorize a write. Exact roles and scopes come from current official documentation, are recorded in the reviewed plan, and are constrained to the selected target. Unsupported least privilege leaves an action manual or blocked.

### 10.1 Authentication and permission table

| Surface | Required attended authentication and assessment capability | Approved mutation boundary |
|---|---|---|
| Workstation | Signed-in administrator; read installed applications, executable paths, versions, repository metadata, secure credential-store availability, and destination attributes | Allowlisted installation/configuration only; item-specific elevation; no policy or endpoint-protection weakening |
| GitHub | `gh auth login --hostname github.com --web --clipboard`; `gh auth status`; secure credential store; default scopes `repo`, `read:org`, `gist`; exact endpoint permissions read back or reviewed | Local `gh api` only for exact repository/organization operation; additional documented scope explicitly approved; no workflow path, token environment variable, PAT, secret read-back, or unrelated repository |
| Entra/Azure/Graph | `az login --tenant <tenant-id> --use-device-code`; selected subscription and signed-in-user read-back; delegated read permission for exact metadata | Exact approved directory object, role assignment, or Azure deployment under same delegated user; attended consent/activation; no execution credential, client secret, workload identity, or app-only switch |
| Azure DevOps | Verified delegated Azure CLI context, used only where officially supported; read selected organization/project and connection/check metadata | Project creation only where the acting identity and effective permission can be read back through a documented delegated interface; service connections are `Blocked`; approvals and checks are `Manual`; no PAT, `az devops login`, pipeline execution, or organization creation |
| Power Platform | Deterministic PAC device-code profile; `pac auth list`, `pac auth select`, and environment-specific `pac org who` | Environment creation and configuration are `Manual` for this increment, with separate `DEV`/`TEST`/`PROD` read-back; no application-user execution switch |
| SharePoint | Delegated identity resolves approved metadata for exact manifest-declared sites | Site creation, permission, and configuration are `Manual` for this increment; no tenant-wide content access fallback or content mutation |

Permissions are checked before planning and immediately before Apply. Excess permission is reported as a risk, not treated as authorization. Supported CLI token caches and operating-system credential stores are opaque to the scripts. Tokens are never read, printed, copied, serialized, or included in evidence.

### 10.2 GitHub scope and permission contract

The runbook records the following exact GitHub requirements and refuses an operation outside them:

| Local operation | OAuth scope | Resource permission |
|---|---|---|
| Authenticate with the required `gh auth login` command | GitHub CLI defaults: `repo`, `read:org`, `gist` | Membership and repository access remain limited to the signed-in user |
| Read selected private-repository metadata, rulesets, and connection metadata outside GitHub Actions | `repo`; `read:org` only for selected organization identity/membership read-back | Read access to the selected repository; endpoint-specific read access |
| Change selected repository settings or rulesets outside GitHub Actions | `repo` | Administrator permission on that repository and endpoint-specific write access |
| Read selected organization metadata | `read:org` | Membership visibility for that organization |
| Perform organization-level administration | Not granted by the required baseline login; script operation is `Blocked` | Complete through a separately approved attended official flow with the exact organization role and scope required by the documented endpoint |
| Install or authorize a GitHub App | No script-added scope | Attended organization/repository owner approval through GitHub's supported flow |

The default `gist` scope is acquired by the mandated GitHub CLI login flow but is unused by this kit. The `workflow` scope is neither requested nor used. The plan must identify the exact `gh api` endpoint and its documented permission before a write; an operation requiring any unlisted scope is `Blocked` pending review rather than granted dynamically.

## 11. Explicit Manual Steps

Manual work has a named owner, prerequisite, expected official screen/service, exact decision, and read-back check.

| Manual condition | Required treatment |
|---|---|
| Tenant or Azure DevOps organization does not exist | Stop. Creation is excluded; direct the tenant owner to the official administrative process |
| Product license is absent | Stop. Record the missing license; do not purchase, assign, trial, or bypass it |
| Device code is blocked by Security Defaults or Conditional Access | Stop and escalate for an approved attended browser-interactive method; never weaken or bypass policy |
| MFA, Conditional Access, terms acceptance, or reauthentication is required | Pause for the named administrator to complete it directly with the identity provider; never collect or automate credentials |
| Entra or Microsoft Graph admin consent is required | Show exact permissions and target application; an authorized administrator consents through an attended official flow, then the kit reads back grants |
| Azure privileged role activation or temporary subscription assignment is required | Use attended least-privilege activation/assignment; record exact non-secret assignment IDs outside Git and verify cleanup |
| Azure Boards GitHub App installation/authorization or another connection lacks a supported API | Perform the official attended flow and read back connection state where an official interface permits |
| Power Platform environment capacity, region, license, or attended connector consent is required | Stop and route to the Power Platform administrator; never substitute another environment or identity |
| SharePoint selected-site consent or site-owner approval is required | An authorized administrator grants only the exact site permission; the kit verifies site ID and resulting grant |
| Customer organization/repository creation, ownership acceptance, or publication authorization is required | Complete only after sanitized export validation; publication remains a separate attended operation |

If a manual action cannot be read back through a supported interface, the runbook requires operator confirmation and leaves the result `Manual`, not `Verified`.

## 12. Data Flow and Evidence

```text
Administrator -> supported CLI device/browser challenge
        -> direct identity-provider authentication + MFA/CA
        -> opaque delegated CLI cache / secure credential store
        -> identity and exact target read-back
        -> reviewed source + selected manifest
        -> allowlisted assessment
        -> plan + exact operations + digest
        -> human approval
        -> context revalidation -> ShouldProcess -> local script operation
        -> final identity + target + postcondition read-back
        -> redacted evidence
        -> optional supported CLI logout/clear
```

Reports default outside Git under `%LOCALAPPDATA%\CaldovaHrFrontier\runbook-evidence\<runId>\`. The caller may select another path only outside the repository and export staging tree. The kit refuses a report destination inside any Git working tree unless a test explicitly uses a disposable temporary repository.

Evidence contains run ID, timestamps, source commit, manifest and plan digests, delegated-user display-safe identifier, selected non-secret stable IDs, tool/API versions, action classification, ShouldProcess decision, status, sanitized error category, final read-back result, and manual/recovery items. It excludes passwords, access/refresh/ID tokens, device codes, authorization headers, cookies, secrets, private keys, connection strings, credential/cache files, raw service responses, SharePoint content, HR data, and command output that may contain them.

Logs and console output use the same allowlist redaction rules as files. Post-write masking is insufficient. A redaction failure prevents report creation and fails the run.

## 13. Error Handling and Recovery

The kit fails closed. Each operation records its last proven state and stops dependent actions after a failure.

| Failure | Required response | Recovery |
|---|---|---|
| Unsupported OS, non-interactive host, missing tool, or incompatible version | Refuse before cloud authentication or export | Correct an approved workstation prerequisite and reassess locally |
| Device/browser authentication blocked by policy | Perform no cloud reads beyond returned identity/error metadata and no mutation | Stop and escalate for approved attended browser interaction; do not weaken policy |
| Account, tenant, subscription, organization, project, repository, profile, or environment mismatch | Refuse before additional cloud reads or mutation; suppress credential-bearing output | Use official CLI selection/logout commands, authenticate correctly, and rerun full assessment |
| Insecure or plaintext GitHub credential storage | Refuse GitHub operations | Configure supported secure credential storage, log in again, and verify status |
| Token/secret parameter, authentication environment variable, PAT, app-only identity, or unattended host detected | Refuse the run | Remove the prohibited path; return to attended delegated login |
| Missing, stale, or ambiguous evidence | Mark the plan blocked; never infer intent | Collect fresh assessment, review stable IDs, and generate a new digest |
| Permission denied | Record exact sanitized capability and target; never broaden automatically | Use attended least-privilege process or escalate; reassess |
| Plan drift before Apply | Invalidate approval and refuse the write | Reassess, regenerate, and reapprove |
| Identity/context changes during the run | Stop dependent operations and do not claim success | Read back current state, restore approved context through official commands, and create a new plan |
| Partial cloud mutation | Stop dependent changes | Read back current state, produce exact recovery plan, and require new approval |
| Failed postcondition | Treat operation as failed even if API returned success | Retry only with documented safe idempotency; otherwise escalate |
| Workstation restart required | Stop at a resumable boundary | Restart attended, reassess all prerequisites, and reauthenticate |
| Export collision, source overlap, replacement mismatch, or residual | Do not publish | Correct reviewed inputs, remove only disposable output, and regenerate from original source commit |
| Evidence write/redaction failure | Do not claim completion | Read back state and rerun into a safe external report path |

Recovery never weakens authentication, context checks, approval, permissions, replacement rules, or validation. It uses official CLI logout/profile cleanup only and never manually deletes credential or token-cache folders. Existing detailed recovery remains authoritative for covered cloud failure states: [Bootstrap Recovery](../../infra/docs/19-bootstrap-recovery.md).

## 14. Official-reference Strategy

Normative external instructions use current official Microsoft Learn, GitHub CLI, or GitHub Docs references. Community posts, search snippets, copied portal instructions, and undocumented endpoints are not normative. If official documentation does not support a delegated, attended API or CLI path, the action is manual or blocked.

The required authentication references are:

- [Azure CLI interactive authentication](https://learn.microsoft.com/en-us/cli/azure/authenticate-azure-cli-interactively);
- [`az login`](https://learn.microsoft.com/en-us/cli/azure/reference-index#az-login);
- [`az logout`](https://learn.microsoft.com/en-us/cli/azure/reference-index#az-logout);
- [Azure DevOps CLI](https://learn.microsoft.com/en-us/azure/devops/cli/);
- [Power Platform CLI authentication commands](https://learn.microsoft.com/en-us/power-platform/developer/cli/reference/auth);
- [`gh auth login`](https://cli.github.com/manual/gh_auth_login);
- [`gh auth status`](https://cli.github.com/manual/gh_auth_status);
- [`gh auth logout`](https://cli.github.com/manual/gh_auth_logout).

Additional implementation references include [PowerShell `ShouldProcess`](https://learn.microsoft.com/en-us/powershell/scripting/developer/cmdlet/how-to-add-support-for-shouldprocess-calls), [Windows Package Manager](https://learn.microsoft.com/en-us/windows/package-manager/winget/), [Azure deployment what-if](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deploy-what-if), [Microsoft Graph selected permissions](https://learn.microsoft.com/en-us/graph/permissions-selected-overview), [Azure DevOps security permissions](https://learn.microsoft.com/en-us/azure/devops/organizations/security/permissions?view=azure-devops), and [Azure Boards app for GitHub](https://learn.microsoft.com/en-us/azure/devops/boards/github/install-github-app?view=azure-devops).

References are rechecked during implementation and every material runbook revision. A changed CLI, portal, policy, or API is not silently reconciled: update the procedure and tests through review. Attended UI instructions state when they were last verified.

## 15. Testing and Acceptance

All automated tests use synthetic names, fake stable IDs, mocked native commands/service clients, and temporary directories. They do not authenticate to a live service or contain real tenant responses, credentials, HR records, or customer data.

### 15.1 Pester coverage

Pester tests under `infra/tests/pester/` will cover:

- local Windows 11 and interactive-session enforcement for every entry point;
- default non-mutation, `SupportsShouldProcess`, `-WhatIf`, declined confirmation, and explicit `-Apply`;
- exact Azure, GitHub, and PAC login/context/read-back command construction without invoking live authentication;
- refusal before non-identity reads or mutation on every account/tenant/subscription/organization/project/repository/environment mismatch;
- refusal when the approved digest, source commit, target ID, evidence freshness, permission, or final context does not match;
- delegated-user continuity and refusal of app-only or service-principal execution;
- static rejection of any creation or modification below `.github/workflows/` and any GitHub Environment API operation;
- PowerShell AST and text validation rejecting parameters or aliases for tokens, secrets, credentials, PATs, client secrets, authorization headers, and supplied device-code values while permitting the literal PAC CLI `--deviceCode` flow-selection switch;
- static and runtime rejection of `GH_TOKEN`, `GITHUB_TOKEN`, `AZURE_DEVOPS_EXT_PAT`, `SYSTEM_ACCESSTOKEN`, Azure/ARM client-secret variables, PAC secret variables, `--with-token`, `az devops login`, and equivalent environment-variable authentication paths;
- rejection of runners, `workflow_dispatch`, OIDC/workload-federation execution, any GitHub Environment operation, unattended/headless flags, plaintext credential storage, and manual cache deletion;
- deterministic plans, idempotent reruns, one-tenant selection, and exact `DEV`/`TEST`/`PROD` separation;
- broad-permission refusal, source immutability, external evidence paths, staging isolation, structured replacement counts, and residual detection;
- fail-closed behavior for blocked device code, unauthorized, unavailable, stale, ambiguous, malformed, partial, and redaction-failed results;
- operation and final-context read-back plus partial-mutation recovery.

ShouldProcess tests inject or mock the mutation boundary and prove that no mutator is called during assessment, `-WhatIf`, refusal, mismatch, or declined confirmation.

### 15.2 Static kit validator

A repository validator will inventory proposed kit changes and fail if:

1. any added, removed, or modified path is below `.github/workflows/`;
2. a script parameter, manifest field, command builder, or example accepts a token, secret, credential, PAT, client secret, authorization header, or supplied device-code value; the PAC CLI `--deviceCode` switch is permitted because it selects the attended flow and does not carry the code;
3. a script reads authentication from an environment variable;
4. any command uses `--with-token`, `az devops login`, a service-principal login, client-secret login, workload identity, OIDC federation, or an unattended execution switch;
5. any GitHub Environment is described, created, updated, or used by the kit.

The validator permits supported CLIs to manage their own opaque delegated token caches. It must not inspect those caches.

### 15.3 Disposable export test

An acceptance fixture creates a temporary source repository containing synthetic tracked files, excluded tenant artifacts, structured customer fields, deliberate residual markers, ignored/untracked decoys, a fake remote, and a sentinel `.github/workflows/` file. The test exports to a separate temporary directory and proves:

- the source commit, status, refs, remote, file hashes, and workflow sentinel are unchanged;
- no source workflow file is created, changed, or removed, and no workflow path is copied to the export;
- only tracked and selected files are copied;
- only structured allowlisted fields change;
- all seeded residuals are reported;
- failed validation prevents a publish-ready result;
- a clean fixture passes the full exported-repository validation suite.

Temporary material is deleted after tests. No report is written into the real repository.

### 15.4 Full validation and reviews

Acceptance requires:

1. the complete repository validation suite on the reusable source;
2. the complete applicable validation suite inside the disposable export;
3. negative tests for every authentication, context, workflow-path, secret-input, and mutation refusal boundary;
4. an attended Windows 11 dry run using synthetic/non-production targets and delegated device/browser login, with no mutation;
5. a mocked or sandboxed local idempotency demonstration for each mutating script before tenant use;
6. docs-agent review for metadata, English, links, UTF-8, placement, status, and catalogue policy;
7. architecture review whenever implementation could change or rely on acceptance of ADR-0001, ADR-0002, or ADR-0003, or affect ADR-0005, ADR-0007, ADR-0009, or ADR-0011.

No production tenant or real customer repository is an acceptance-test target.

## 16. Rollout

Rollout is incremental and each phase has an independent stop gate:

1. **Documentation review.** Approve this design, then author the index and three local runbooks with official references, exact login/read-back/logout procedures, and explicit manual steps.
2. **Static boundaries.** Add validators that reject `.github/workflows/` changes, token/secret parameters, environment authentication, PATs, app-only execution, and unattended paths before any operational script is accepted.
3. **Assessment-only tooling.** Implement local workstation assessment, delegated cloud planning, and export validation with mocked service tests. No mutation path is enabled.
4. **Disposable local operations.** Implement workstation planning and customer export into temporary external directories. Validate source and workflow-file immutability.
5. **Workstation Apply.** Enable reviewed package/configuration operations on a disposable Windows 11 workstation with an attended administrator, ShouldProcess, and read-back.
6. **Cloud Apply by service.** Enable one local delegated-user service surface at a time after permission review, negative tests, sandbox evidence, and architecture review. A service without a safe supported attended API stays manual.
7. **Customer handover rehearsal.** Create and validate a synthetic export, conduct human review, and rehearse publication to a disposable repository through a separate attended process.
8. **Operational adoption.** Use the kit only after named owners accept authentication, context, recovery, evidence retention, and permission assignments.

Progress in one phase does not authorize a later phase. No phase introduces GitHub Actions, runner execution, pipeline preparation, workload federation, secret injection, or app-only runbook execution. Production workload deployment and real customer publication remain separately approved activities.

## 17. Definition of Done

The operational runbook kit is complete only when:

- the four runbook documents exist under `infra/docs/runbooks/`, use the six-field metadata header, are linked from the Infrastructure documentation map, and contain no unresolved placeholder;
- the six named scripts exist under `infra/src/scripts/runbooks/` as thin local interactive entry points and reuse the existing bootstrap module/helpers;
- every service follows signed out, device/browser challenge, direct identity-provider authentication, delegated CLI cache, context read-back, script operations, final read-back, and optional supported logout;
- credentials are never passed to scripts, and scripts never read, print, store, or accept tokens or authentication environment variables;
- exact Azure, GitHub, and PAC commands and context checks match this design and current official documentation;
- account, tenant, subscription, organization, project, repository, or environment mismatch refuses before reads beyond identity metadata or any mutation;
- every mutating path enforces `-Apply`, digest-bound manifest, delegated context validation, displayed summary, ShouldProcess, `-WhatIf`, postcondition read-back, evidence, and recovery;
- target Entra applications/service principals remain managed solution objects and never become this kit's execution identity;
- GitHub configuration, if automated, is local `gh api` under browser/device-authenticated GitHub CLI context;
- validators prove that the kit does not create or modify `.github/workflows/` and rejects token/secret parameters, environment authentication, PATs, insecure storage, OIDC/workload identity, client-secret login, and unattended execution;
- device-code policy blockage stops and escalates without weakening Security Defaults or Conditional Access;
- reports remain outside Git and contain only allowlisted redacted evidence;
- customer export preserves source and source workflow files, omits `.github/workflows/` from the disposable export, applies only structured replacements, reports every residual, passes validation, and never publishes the source repository;
- synthetic tests pass without live services or real data;
- docs-agent policy review is complete;
- architecture review confirms Proposed ADR status and preservation of stable HR constraints.

## 18. Design Self-review

This design contains no implementation placeholder. “Future” identifies intentionally unimplemented artifacts rather than an unresolved decision. The ownership boundary is explicit: this is cross-cutting design documentation, while future operational content and scripts belong to Infrastructure.

All preparation, configuration, validation, and handover execution is local, attended, and delegated-user based. GitHub Actions, workflow dispatch, runners, pipeline preparation, GitHub Environment operations, OIDC/workload federation, service-principal automation, client-secret or PAT execution, secret injection, authentication environment variables, and unattended paths are excluded and statically tested. Target solution applications/service principals remain distinct from the operator and never execute the kit.

Device code is preferred but does not bypass or guarantee satisfaction of Security Defaults or Conditional Access; blockage stops the run and requires an approved attended alternative. Credentials are entered only at the identity provider, supported CLIs retain opaque delegated authentication state, scripts consume only context read-back, and cleanup uses supported CLI commands without manual cache deletion.

The stable Workday, Dataverse, Workday Access Layer, workflow-first HR architecture, no-employment-decision, one-tenant, and stage-separation constraints remain unchanged. Assessment differs from mutation, publication remains separate from export, and manual outcomes cannot be reported as verified automation.
