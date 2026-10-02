# Cloud Service Foundation Runbook Design

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-10-02 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Tenant 1 provider foundation, Azure Pipeline, and Power Platform DEV deployment |
| **References** | [Tenant 1 Runbook End-to-End Design](2026-10-02-tenant-1-runbook-end-to-end-design.md), [Current Cloud Foundation Stop Notice](../../infra/docs/runbooks/02-cloud-service-foundation.md), [Power Platform Environments and ALM](../../infra/docs/12-power-platform-environments-and-alm.md), [Azure DevOps Engineering Control Plane](../../infra/docs/13-azure-devops-engineering-control-plane.md), [ADR-0003](../adr/0003-bicep-and-powershell-for-infrastructure-as-code.md) |

## 1. Status and Authority

This specification proposes the cloud subsystem of the [Tenant 1 end-to-end lifecycle](2026-10-02-tenant-1-runbook-end-to-end-design.md). It is independently plannable but is not approved implementation or live-operation authority.

User approval of the complete design set is required before an implementation plan is written, the current [stop notice](../../infra/docs/runbooks/02-cloud-service-foundation.md) is replaced, a public Apply path is activated, or any provider is contacted for live execution.

The current public scripts remain unsupported stop stubs until reviewed implementation, tests, runbook replacement, and live-entry approval are complete. Removing their initial `throw` statements is explicitly insufficient.

## 2. Problem and Proposed Outcome

The repository can validate a lean Tenant 1 boundary and contains dormant provider modules, but it has no supported end-to-end cloud runbook. The stopped public entry points do not plan or Apply. There is no Azure Pipeline YAML, workload-identity-federated Power Platform service connection, application-user reconciliation, solution pack/import path, or DEV deployment evidence.

The proposed subsystem supplies one attended, digest-bound sequence:

```text
Test-TenantFoundation
-> New-TenantFoundationPlan
-> human approval of the exact digest
-> Invoke-TenantFoundation -WhatIf
-> Invoke-TenantFoundation -Apply
-> Test-TenantFoundation
-> prove NoChange
```

It reconciles only the reviewed Tenant 1 foundation, builds the committed HR solution once, imports that exact artifact to DEV, and proves an unchanged second run has no `Create` or `Update`.

## 3. Scope

### 3.1 Included

- Read-only assessment of exact Tenant 1 GitHub, Entra, Azure, Azure DevOps, and Power Platform contexts.
- Deterministic provider action planning and shared digest approval.
- Existing GitHub repository metadata and ruleset verification or reconciliation.
- A credential-free Entra delivery application, service principal, and reviewed federated credential.
- Subscription-scope Bicep build, `what-if`, incremental Apply, and exact resource read-back.
- Exact Tenant 1 Azure DevOps project verification; project creation remains a reusable action only for reviewed future `Create` intent with zero ambiguous matches.
- An Azure Pipeline connected directly to GitHub, its DEV environment, workload-identity-federated Power Platform service connection, and required permission-gated checks.
- Verification of the three Power Platform environments.
- Attended reconciliation and independent read-back of the DEV application user and minimum reviewed role.
- Power Platform Build Tools 2.0 pack, check, publish, import to DEV, and read-back.
- Partial-run recovery by reassessment and forward reconciliation.
- Raw local evidence and a sanitized acceptance projection.

### 3.2 Excluded

- Tenant creation, license purchase or assignment, or Azure DevOps organization creation.
- TEST or PROD import, promotion, mutation, approval, or release.
- Power Platform environment creation.
- SharePoint site creation or configuration.
- DLP, Conditional Access, Managed Environment, environment-group, or tenant-policy changes.
- GitHub repository creation, publication, GitHub Environment creation, or GitHub Actions delivery.
- Azure complete-mode deployment, deployment-stack adoption, implicit deletion, or automatic destructive rollback.
- Secret-based service connections, client secrets, certificates in source, PATs, token parameters, or self-elevation.
- Workload deployment beyond the exact committed HR solution artifact imported to DEV.

## 4. Current State

### 4.1 Supported Today

- Local attended context validation, discovery, Bicep build, subscription `what-if`, boundary checks, and read-back exist in the lean path.
- The current Bicep composition declares the subscription platform resource group, Log Analytics workspace, Activity Log diagnostic setting, and policy assignments.
- Dormant module helpers cover portions of GitHub, Entra, Azure, and Azure DevOps assessment and reconciliation.
- Power Platform DEV, TEST, and PROD were observed historically, and unmanaged HR solution state was historically observed in DEV.

These are inputs to fresh assessment, not proof that the current state still matches.

### 4.2 Unsupported or Missing Today

- `Get-CloudFoundationPlan.ps1` and `Invoke-CloudFoundation.ps1` throw before doing work.
- No Azure Pipeline YAML exists.
- Current HR PAC tooling exports and unpacks only; it does not pack, check, import, or deploy.
- No implemented application-user, Power Platform WIF service-connection, Azure Pipeline environment/check, or exact artifact-delivery path exists.
- Power Platform environments, SharePoint, approvals/checks, connections, and federation surfaces are currently `Manual` or `Blocked`.
- The Tenant 1 private intent file is absent.
- The observed Azure extension context was not proven to be Tenant 1 and is not shared evidence for Azure CLI, PAC CLI, Azure DevOps, or GitHub CLI.

## 5. Architecture and Public Contracts

### 5.1 Thin Public Entry Points

The proposed supported surface is:

```text
infra/src/scripts/runbooks/Test-TenantFoundation.ps1
infra/src/scripts/runbooks/New-TenantFoundationPlan.ps1
infra/src/scripts/runbooks/Invoke-TenantFoundation.ps1
```

Their responsibilities are:

| Entry point | Responsibility | Write boundary |
|---|---|---|
| `Test-TenantFoundation` | Read exact contexts and provider state, compare with reviewed intent and state, and classify every component. | External evidence only. |
| `New-TenantFoundationPlan` | Convert one fresh assessment into ordered actions, perform Bicep build and subscription `what-if`, and produce the execution manifest. | External evidence and generated external build artifacts only. |
| `Invoke-TenantFoundation` | Revalidate the approved run, simulate through `-WhatIf`, or execute supported actions through explicit `-Apply` and per-action `ShouldProcess`. | Approved provider actions only. |

Provider logic remains in focused adapters or module functions with injected command runners. The entry points do not embed provider implementations.

The stopped `Get-CloudFoundationPlan.ps1` and `Invoke-CloudFoundation.ps1` surface is replaced only through a reviewed migration. Old filenames may remain as fail-closed compatibility notices, but they may not silently forward to live Apply. No command becomes supported merely because a stop guard was deleted.

### 5.2 Required Inputs

Every entry point requires:

- run ID and external evidence root;
- explicit `PublicTenantKey tenant1`;
- explicit path to ignored `tenant1.local.psd1`;
- explicit path to ignored `tenant1.state.local.json`;
- expected source commit and repository root;
- exact workstation prerequisite outcome;
- exact provider tool identities;
- selected stage set, fixed to `DEV` for mutation and `DEV`, `TEST`, `PROD` for read-only validation; and
- for invocation, the exact execution-manifest path and approved digest.

There is no tracked-manifest fallback, environment-variable tenant selector, first matching object, or matrix mode.

### 5.3 Private Intent and State

`tenant1.local.psd1` is human-reviewed non-secret desired intent. `tenant1.state.local.json` is tool-generated stable-ID and last-verified state. Both are ignored, encrypted in backup, restore-tested, and excluded from raw source and committed evidence.

The state file:

- cannot introduce a desired resource or property;
- cannot change a `Manual` or `Blocked` classification;
- cannot prove that an object still exists;
- may nominate an exact stable ID for fresh adoption read-back; and
- is updated only after exact postcondition read-back.

## 6. Assessment and Planning Model

### 6.1 Assessment

Assessment reads each provider through its independently authenticated supported context. It first proves:

- attended operator and interactivity;
- GitHub host, login, owner, repository, and stable repository ID;
- Azure account, tenant, subscription, and principal;
- Azure DevOps organization, project, acting principal, and stable project ID;
- PAC profile, tenant, environment URL, and stable environment ID for each stage; and
- source commit, intent digest, state digest, and tool identities.

Only then may it inventory resources. A mismatched context stops that provider and all dependent actions. One valid context does not validate another tool.

### 6.2 Deterministic Plan

The plan contains ordered actions with:

- stable action ID and provider;
- classification: `NoChange`, `Create`, `Update`, `Manual`, `Blocked`, or `Refused`;
- target stable ID or an exact absence predicate for `Create`;
- desired properties and preconditions by digest;
- prerequisite action IDs;
- mutation adapter and `ShouldProcess` target;
- expected postcondition;
- recovery guidance; and
- evidence projection.

The plan includes the exact Bicep source hash, compiled-template hash, parameter hash, sanitized `what-if` summary, pipeline source hash, HR solution-source tree hash, and tool identities.

Human approval binds the complete execution-manifest digest. A summary or partial provider approval is not sufficient for Apply.

### 6.3 What-If

`Invoke-TenantFoundation -WhatIf`:

- revalidates the complete manifest;
- rereads contexts and current targets;
- displays every planned `Create`, `Update`, `Manual`, `Blocked`, and `Refused` action;
- invokes no provider write;
- does not queue a pipeline;
- does not create an Azure DevOps environment, check, connection, or variable;
- does not create a Bicep deployment; and
- records `WhatIf` decisions as evidence.

Azure subscription `what-if` is generated during planning and repeated before Azure Apply when required by drift policy. PowerShell `-WhatIf` does not substitute for Bicep `what-if`.

## 7. Provider Order and Ownership

Every mutation rereads the exact target immediately before action and reads back stable IDs and exact supported properties immediately after action. Ambiguity, stale state, missing permission, or uncertain ownership blocks.

| Order | Provider | Supported proposed responsibility | Manual or blocked boundary |
|---|---|---|---|
| 1 | GitHub | Verify or reconcile approved metadata and one applicable ruleset on the existing repository. | Repository creation, publication, account policy, billing, and Actions delivery. |
| 2 | Entra | Verify or reconcile one credential-free delivery application, service principal, and reviewed federated credential. | Consent, role approval, owner changes, and any secret or certificate. |
| 3 | Azure | Build, repeat subscription `what-if`, deploy the exact Bicep bytes incrementally, and read back resources. | Complete mode, deletion, deployment stacks, and unreviewed role resources. |
| 4 | Azure DevOps | Verify the exact project; reconcile the YAML pipeline, DEV environment, WIF service connection, protected variables, and supported checks. | Organization creation, licenses, unsupported check APIs, and administrator approval. |
| 5 | Power Platform administration | Verify all three environments; reconcile the DEV application user and minimum role through attended authority. | Environment creation, licenses, DLP, consent, connections, TEST, and PROD writes. |
| 6 | Azure Pipeline | Pack and check committed HR source, publish one artifact, import that same artifact to DEV, and read back. | TEST/PROD promotion, maker publication, production approval, and environment rebuild. |

### 7.1 GitHub

Tenant 1 already has the source repository. `Create` for a repository is unsupported. The action set may reconcile only properties present in reviewed intent and the approved ruleset contract. It preserves unrelated settings unless the design explicitly owns them.

GitHub Actions remains repository validation only. The foundation runbook neither creates nor changes a workflow to deploy a tenant.

### 7.2 Entra and Federation

The delivery identity has no client secret or certificate. It consists of:

- one reviewed application registration;
- its service principal;
- one federated identity credential whose issuer, subject, and audience are derived from the exact Azure DevOps service-connection contract; and
- only the API permissions and ownership needed for the approved DEV delivery path.

Federation metadata is approved before creation and read back after creation. Multiple matching applications, service principals, or credentials block. The local runbook continues to execute as the attended user; it never authenticates as the delivery application.

This federation connects Azure DevOps delivery to Power Platform. It does not reactivate the rejected GitHub OIDC bootstrap, create a GitHub Environment, or let a GitHub workflow prepare a tenant.

### 7.3 Azure and Bicep

Bicep is the sole owner of Azure resources. The current composition owns:

- subscription-scope platform resource group;
- Log Analytics workspace;
- Activity Log diagnostic setting; and
- policy assignments.

PowerShell may generate external parameters from reviewed intent, compile to the external run directory, invoke `what-if`, invoke one approved deployment, and read back. It does not reproduce an Azure resource with imperative REST or CLI commands.

Apply uses incremental mode. The exact template and parameter bytes must match those approved after `what-if`. `Delete` or unsupported change types block. Complete mode and implicit deletion are prohibited. Deployment stacks remain a future option only after a reviewed deletion and lifecycle design.

### 7.4 Azure DevOps Foundation

For Tenant 1, the expected path is exact project verification, not duplicate project creation. Reusable project creation is allowed only when:

- reviewed intent says `Create`;
- the organization is exact and already exists;
- fresh read-back proves zero exact-name matches and no stable-ID conflict;
- the process and visibility are explicit; and
- asynchronous creation reaches the reviewed terminal state before dependent actions.

The proposed repository paths are:

```text
azure-pipelines.yml
infra/src/pipelines/templates/
```

The root file is a thin discoverable entry point. Reusable Build Tools and evidence logic lives in reviewed templates. Tenant-specific IDs and URLs do not enter YAML; the foundation runbook configures them through approved Azure DevOps resources outside Git and records only sanitized digests.

The current sprint uses manual pipeline queueing:

```yaml
trigger: none
pr: none
```

This prevents an implementation merge from importing automatically. A future trigger strategy requires separate review. DEV deployment also remains behind the Azure DevOps environment's attended approval/check boundary where the platform supports it. An unsupported check surface remains `Manual` and must be read back; it is not silently omitted.

### 7.5 Power Platform Administration

Assessment verifies all three environment stable IDs, URLs, lifecycle types, and accessibility. Only DEV can receive writes.

Before pipeline import, an authorized Power Platform administrator:

1. confirms the exact delivery service principal;
2. creates or adopts its DEV application user;
3. grants only the reviewed minimum security role needed for checker/import/read-back;
4. records the human action without credentials; and
5. permits independent read-back of application-user ID, application ID, environment ID, enabled state, and exact role set.

The runbook does not assign the administrator's own role, request elevation, broaden access after a failure, or mutate TEST/PROD.

## 8. Azure Pipeline and Exact Artifact Contract

### 8.1 Build and Deployment Stages

The pipeline consumes GitHub directly and has two logical stages:

1. **Build and check**
   - checkout the exact queued GitHub SHA;
   - verify the SHA, approved run ID, and intent digest;
   - install the reviewed Power Platform Build Tools 2.0 task version;
   - pack the committed `hr/src/solutions/caldovahrfrontier/` source into the reviewed unmanaged DEV solution package;
   - run Solution Checker or the approved Build Tools check task;
   - calculate the package SHA-256;
   - publish the package and adjacent provenance manifest as one immutable pipeline artifact.
2. **Deploy DEV**
   - require successful build/check and the DEV environment gate;
   - download the published artifact;
   - verify its package digest and provenance;
   - authenticate through the workload-identity-federated service connection;
   - import the same package bytes to the exact DEV environment;
   - perform supported solution read-back; and
   - publish sanitized deployment evidence.

There is no pack or rebuild step in the deployment stage.

### 8.2 Provenance Manifest

The artifact's adjacent provenance record includes:

- pipeline definition and run IDs;
- exact GitHub commit SHA;
- source tree digest for the solution path;
- umbrella run ID and approved execution-manifest digest;
- Build Tools major and task versions;
- solution unique name, declared package type, and version;
- package SHA-256; and
- build/check results.

It includes no token, federated assertion, connection payload, tenant-private URL, or secret.

### 8.3 Read-Back

Acceptance reads back the properties the platform supports reliably:

- exact DEV environment stable ID and URL match;
- application-user stable ID, application ID, enabled state, and exact minimum role set;
- pipeline definition, source repository, source branch, and run SHA;
- artifact identity and package digest in Azure Pipelines;
- import job identity and terminal result;
- solution unique name, solution ID where exposed, version, managed state, publisher identity, and expected component summary; and
- no write to TEST or PROD.

Power Platform is not assumed to expose the imported ZIP hash. Artifact-byte identity is proven by pipeline download/digest and import-task provenance; solution state is proven by supported environment read-back. The acceptance review must not claim a stronger platform guarantee.

## 9. Apply, Idempotency, and Recovery

### 9.1 Apply

`Invoke-TenantFoundation -Apply` requires:

- successful current assessment and workstation prerequisite;
- fresh, schema-valid execution manifest;
- exact human-approved digest;
- unchanged source, intent, state, machine, tools, and contexts;
- no unresolved prerequisite `Manual`, `Blocked`, or `Refused` outcome;
- per-action `ShouldProcess`; and
- immediate pre-read and post-read.

A human-only step may be interleaved only when the manifest declares it and the runbook pauses for independent read-back.

### 9.2 Idempotency

The second run performs a new assessment and receives a new digest. It passes only when:

- provider resources resolve by the same stable IDs;
- exact owned properties match;
- Bicep `what-if` reports no owned changes;
- pipeline definition and protected resources match;
- DEV application user and role match;
- the committed HR source and accepted imported solution state match the declared version; and
- no action is classified `Create` or `Update`.

A pipeline rerun with unchanged SHA and intent may revalidate or perform a platform-supported no-op import, but it must not create a duplicate identity, service connection, environment, pipeline, application user, role assignment, solution, or artifact with different package bytes.

### 9.3 Partial Failure

- Stop on the first failed action and do not execute dependent actions.
- Preserve completed action evidence and exact failed state.
- Perform fresh assessment before retry.
- Adopt a partial resource only by exact stable ID and exact property read-back.
- Reconcile forward under a new digest.
- Never automatically delete an application, service principal, federated credential, deployment, project, pipeline, environment, service connection, application user, role, or solution.

## 10. Evidence

Provider action envelopes live under `actions/`; consolidated projections use:

- `assessment.json`
- `execution-manifest.json`
- `approvals.json`
- `read-back.json`
- `pipeline.json`
- `power-platform.json`
- `summary.json`

Raw responses, generated Bicep parameters, compiled templates where they reveal private context, federated assertions, Azure DevOps protected values, PAC profiles, URLs outside the allowlist, and authentication output remain in the local raw boundary and are not committed.

The sanitized acceptance review cites hashes, stable IDs approved for disclosure, statuses, counts, source SHA, artifact digest, and read-back outcomes. It does not overwrite historical reviews.

## 11. Implementation Decomposition

After user approval, the cloud implementation plan can use these ordered units:

1. Define closed assessment, state, action-plan, pipeline-provenance, and read-back schemas.
2. Write focused failing tests for stopped-entry safety and the three new public contracts.
3. Implement exact multi-tool context assessment and ambiguity handling with injected runners.
4. Validate dormant module contracts; wrap only safe behavior and replace unsupported behavior.
5. Implement deterministic planning, Bicep build/`what-if`, digest binding, and drift invalidation.
6. Implement GitHub reconciliation with immediate pre-read and post-read.
7. Implement Entra application, service principal, and federated-credential reconciliation without secrets.
8. Implement incremental Bicep Apply using the exact approved bytes.
9. Implement exact Azure DevOps project validation and pipeline/environment/WIF connection resources.
10. Add root pipeline YAML and reusable Build Tools 2.0 templates with static and fixture tests.
11. Implement attended DEV application-user and minimum-role checkpoint plus independent read-back.
12. Implement exact artifact build/check/publish/import/read-back.
13. Add interruption, partial adoption, rerun, wrong-context, ambiguity, and no-delete tests.
14. Rewrite the cloud runbook and related infrastructure guidance.
15. Run all local tests and current-main CI before scheduling separately approved attended execution.

Each provider increment follows focused test-driven development and current API contract validation. Unsupported legacy actions remain blocked.

## 12. Acceptance Criteria

The cloud subsystem is acceptable only when:

- all focused, infrastructure, HR, static safety, schema, and repository tests pass;
- wrong or unproven context stops before inventory or mutation;
- planning is deterministic and binds the exact Bicep, pipeline, solution-source, tool, intent, and source bytes;
- `-WhatIf`, missing approval, digest drift, and context drift cause no provider write;
- each mutation performs immediate pre-read and exact supported post-read;
- GitHub reconciliation changes only approved existing-repository properties;
- the Entra delivery identity has no credential and its federated credential matches the reviewed Azure DevOps contract;
- incremental Bicep results match approved `what-if` without deletion;
- the pipeline uses Power Platform Build Tools 2.0 and WIF;
- one package from the exact GitHub SHA is checked, published, and imported byte-for-byte to DEV without a deployment rebuild;
- DEV application-user and minimum-role read-back passes;
- TEST and PROD are validated but unchanged;
- a pipeline rerun is idempotent;
- a fresh second foundation run has no `Create` or `Update`; and
- the umbrella acceptance controls `T1-E2E-04` through `T1-E2E-12` have current sanitized evidence.

## 13. Risks and Tradeoffs

| Risk or tradeoff | Treatment |
|---|---|
| Dormant code no longer matches provider APIs | Contract-test adapters before reuse; replace unclear behavior. |
| Azure DevOps WIF setup may require attended permissions or unavailable features | Assess organization capability first; classify unsupported state `Blocked`, never fall back to a secret. |
| Power Platform roles are easy to overgrant | Define the exact minimum role, require administrator approval, and read back the complete role set. |
| DEV import can overwrite maker changes | Bind import to reviewed committed source and require a fresh export/reconciliation decision when DEV is ahead. |
| Solution source has a recorded PAC unpack limitation | Prove pack/check behavior and source completeness before live import; block on unresolved component loss. |
| Providers expose different idempotency semantics | Use exact stable IDs and owned-property comparisons; document supported no-op behavior per action. |
| Manual pipeline queueing is less automated | It prevents an implementation merge from importing automatically; trigger expansion is a later decision. |
| Forward recovery may leave a partial resource visible | Preserve evidence, block dependents, and adopt only after exact read-back; avoid unsafe automatic deletion. |

## 14. Explicit Non-goals

This design does not implement or authorize scripts, tests, YAML, live calls, mutations, role changes, pipeline runs, imports, or document status changes. It does not claim that Tenant 1 intent, contexts, permissions, WIF, pipeline resources, application user, or environments are currently ready.

It also does not authorize Tenant 2 operations, TEST/PROD writes, external publication, tenant creation, license operations, DLP or Conditional Access changes, self-elevation, secrets, destructive rollback, complete-mode deployment, deployment stacks, or GitHub Actions delivery.

## 15. First-Party and Repository Sources

- [Bicep deployment what-if operation](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deploy-what-if)
- [Azure Resource Manager deployment modes](https://learn.microsoft.com/en-us/azure/azure-resource-manager/templates/deployment-modes)
- [Azure deployment stacks](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deployment-stacks)
- [Power Platform Build Tools for Azure DevOps](https://learn.microsoft.com/en-us/power-platform/alm/devops-build-tools)
- [Power Platform Build Tools tasks](https://learn.microsoft.com/en-us/power-platform/alm/devops-build-tool-tasks)
- [Power Platform Environments and ALM](../../infra/docs/12-power-platform-environments-and-alm.md)
- [Azure DevOps Engineering Control Plane](../../infra/docs/13-azure-devops-engineering-control-plane.md)
- [HR Solution Lifecycle Tooling](../../hr/src/scripts/README.md)
- [HR Solution Sources](../../hr/src/solutions/README.md)
- [ADR-0001](../adr/0001-azure-devops-as-engineering-control-plane.md), [ADR-0002](../adr/0002-github-first-bootstrap-and-the-role-of-azure-repos.md), [ADR-0003](../adr/0003-bicep-and-powershell-for-infrastructure-as-code.md), and [ADR-0012](../adr/0012-per-tenant-github-repository-and-account-topology.md)
