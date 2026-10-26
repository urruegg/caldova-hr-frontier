# Infrastructure Operational Runbooks

| Field | Value |
|---|---|
| **Version** | 1.9 |
| **Date** | 2026-10-26 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Infrastructure operations |
| **References** | [Approved Tenant 1 Runbook End-to-End Design](../../../docs/specs/2026-10-02-tenant-1-runbook-end-to-end-design.md); [Approved Child Summary Envelope Design](../../../docs/specs/2026-10-03-tenant-lifecycle-child-summary-envelope-design.md); [Draft Child Summary Envelope Implementation Plan](../../../docs/plans/2026-10-03-tenant-lifecycle-child-summary-envelope-implementation.md); [Tenant Lifecycle Core Implementation Plan](../../../docs/plans/2026-10-02-tenant-lifecycle-core-implementation.md); [Operational Runbooks Design](../../../docs/specs/2026-09-26-operational-runbooks-design.md); [Tenant 1 Lean Platform Runbook](../24-tenant-1-lean-platform-runbook.md); [Infrastructure Domain](../../README.md) |

These runbooks govern attended, local operations for the infrastructure domain. They define how an operator proves readiness, previews reviewed intent, receives a digest for approval, executes only the approved changes, records redacted evidence, and closes with recovery when anything remains unresolved.

The [repository handover runbook](03-customer-handover.md#canonical-standalone-export-contracts)
now documents Plan 5 Tasks 1–5's explicit-profile standalone scripts, mandatory
caller-reviewed `RepositoryIdentity`, immutable external run layout, and manual
child `approvals.json`. Synthetic approved-copy tests do not establish operational
acceptance. `-Independent` now reconstructs the complete existing input from
fresh committed blobs and executes installed provider-free offline tools.
Source and candidate boundaries are rechecked after every suite; a failed or
unavailable boundary blocks later suites even if final source verification recovers.
Missing tools or mandatory suite assets block; absent actual Plan 4 pipelines
remain an explicit prerequisite. Separate immutable validation evidence is not
canonical lifecycle or human acceptance, and Apply emits no lifecycle `Passed`.
The historical fixed-customer wrappers remain a separate compatibility contract.

## Implemented lifecycle-core boundary

Plan 1 implements closed lifecycle contracts, deterministic prerequisite evaluation, retained child-owned digest/approval/evidence helpers, a provider-neutral coordinate-only umbrella, canonical child stage results, and a stage-only acceptance projection. Plan 1 was implemented with local synthetic tests only; no live cloud, provider, or tenant operation was performed. The exact operational boundary is: **no provider mutation is implemented by the lifecycle core.**

The core does not install a tool, authenticate, discover or select a provider object, invoke a provider command, deploy infrastructure, queue a pipeline, import a solution, export a customer repository, or publish a handover. The dormant cloud-foundation stop stubs remain unchanged. The `Workstation`, `Foundation`, `DevDelivery`, and `TenantReplica` stage names are sequencing identifiers, not claims that those subsystem implementations are wired.

### Exact coordinate-only evidence envelope

One run uses one absolute evidence directory outside Git. The coordinate-only umbrella accepts or writes only these canonical paths:

| Relative path | Coordinate-only meaning |
|---|---|
| `phases/<stage>/assessment.json` | Canonical non-mutating output produced by that child during umbrella `Assess`. |
| `phases/<stage>/execution-manifest.json` | Canonical non-mutating output produced by that child during umbrella `Plan`. Its required root includes `selectedStages` and `prerequisiteResults`; both are validated ordinally. |
| `phases/<stage>/summary.json` | Immutable canonical terminal child summary. Its shared envelope is validated semantically and correlated with current coordinates, the exact manifest, and the stage result; provider-specific root extras remain opaque child-owned evidence. |
| `<run>/stage-results/<stage>.json` | Immutable canonical stage result containing only stage status, classification, source/intent/state provenance, child manifest/summary digests, its canonical summary path, and completion time. |
| `<run>/summary.json` | Stage-only projection written by umbrella `Verify` after the exact selected stage-result set succeeds. |

Child execution manifests and summaries are read-only umbrella `Verify` inputs. They remain child-owned evidence. The umbrella validates canonical coordinates, exact bytes and file digests, the shared summary envelope, and the manifest's independent embedded digest; it acquires no authority from provider content. Child `approvals.json`, provider actions, WhatIf/Apply, `ShouldProcess`, state adoption, and provider read-back remain child-only and are neither umbrella authority nor umbrella output. The umbrella validates `selectedStages` and `prerequisiteResults` in exact ordinal order and never reads provider actions to derive topology. `pipeline.json` and `power-platform.json` remain provider-child evidence names; Plan 1 does not create or consume them as proof of pipeline execution, artifact import, or provider mutation.

### Approved child summary envelope and residual gate

The shared child summary envelope reserves exactly `schemaVersion`, `runId`, `stage`, `sourceCommit`, `publicTenantKey`, `intentDigest`, `stateDigest`, `phaseManifestDigest`, `status`, `classification`, and `completedAtUtc`, and retains the five standard fields `startedAtUtc`, `counts`, `prerequisites`, `actions`, and `nonClaims`.

Provider-specific extras are root-only and opaque, are absent from projections and errors, and cannot enter the closed shared nested structures.

The manifest embedded `digest`, exact-file `phaseManifestDigest`, and exact-file `phaseSummaryDigest` are three distinct checks.

The child writes the summary before the stage result, and the summary has no self-digest.

Umbrella `Verify` and `Assess`/`Plan` prerequisite dispatch enforce the same envelope and embedded manifest digest.

Legacy evidence fails closed and requires a new run; there is no compatibility, inference, or repair path.

Umbrella authority remains exactly `Assess`, `Plan`, and `Verify`; `stage-results` remains authoritative and the second `Verify` pass remains required.

Plan 1 and the child summary envelope implementation remain synthetic, `Draft`, and blocked until reviewed merge and then-current green `main`.

No live, provider, or tenant operation was performed, and no merge-readiness claim is made.

The retained child classifications are `NoChange`, `Create`, `Update`, `Manual`, `Blocked`, and `Refused`. At the umbrella boundary, a dependency succeeds only when its canonical stage result has literal `Passed` status and a `NoChange` or `Changed` classification. `Failed`, `Manual`, `Blocked`, and `Refused` all block dependants. A completed unchanged synthetic run does not prove a live provider is unchanged.

### Intent, state, and disclosure boundary

Human-reviewed intent remains in ignored `infra/src/config/tenants/tenant1.local.psd1`. Tool-observed stable state remains only in ignored `infra/src/config/tenants/tenant1.state.local.json`; it is never copied into run evidence. Every state row binds the exact reviewed `Provider`, `ResourceType`, and `LogicalName` component identity. `Existing` requires the exact non-null reviewed ID. Unadopted reviewed `Create` intent uses `stableId: null`, permits one exact verified null-to-ID adoption, and then keeps that non-null ID immutable. State may not introduce desired values, classifications, credentials, or resources absent from reviewed intent and existing state. Source, intent, state, machine, operator, tool, provider context, prerequisite, action, evidence root, expiry, scope, status, or process-session drift invalidates approval.

Umbrella `Verify` reads only the validated in-memory canonical stage results after it validates each exact stage-result file, its child execution-manifest bytes/digest, its child summary bytes/digest, root `selectedStages`, root `prerequisiteResults`, source/intent/state continuity, canonical order, and literal `Passed` dependencies. It never invokes children and never interprets provider actions, IDs, URLs, payloads, or raw read-back.

The stage-only projection root is exactly `schemaVersion`, `runId`, `publicTenantKey`, `stages`, `nonClaims`, and `digest`. Every projected stage is exactly `stage`, `status`, `classification`, `phaseManifestDigest`, `phaseSummaryDigest`, `sourceCommit`, `intentDigest`, and `stateDigest`. The stage-only projection does not claim provider execution, provider approval, provider read-back, deployment, publication, or live tenant state. Its exact nonclaims are:

- `The umbrella did not execute a provider mutation.`
- `Provider approvals and read-back remain child-runbook evidence.`
- `This projection discloses no provider resource identity or raw provider response.`

All lifecycle JSON reloads use the shared cross-host string-preserving loader. Seven-fraction UTC timestamp strings remain strings on Windows PowerShell 5.1 and PowerShell 7.6.6. Canonical stage-result and projection bytes are UTF-8 without BOM, ordinal-key-sorted, array-order-preserving, depth 30, and terminated by exactly one LF.

### Umbrella signature and subsystem independence

[`Invoke-TenantLifecycle.ps1`](../../src/scripts/runbooks/Invoke-TenantLifecycle.ps1) exposes this operator-facing contract:

```powershell
Invoke-TenantLifecycle.ps1 `
  -RunId <guid> `
  -EvidenceRoot <absolute-path-outside-git> `
  -RepositoryRoot <clean-reviewed-repository> `
  -ExpectedSourceCommit <40-hex-sha> `
  -PublicTenantKey tenant1 `
  -TenantConfigurationPath <ignored-intent-path> `
  -TenantStatePath <ignored-state-path> `
  -Stages <Workstation|PrivateBoundary|Foundation|DevDelivery|ReadBack|Acceptance|TenantReplica[]> `
  [-Mode <Assess|Plan|Verify>] `
  [-SubsystemInvoker <hidden-scriptblock>] `
  [-NowUtc <utc-datetime>]
```

`Assess` and `Plan` require the hidden injected invoker and may dispatch only the same non-mutating child mode. The invoker has the exact shape `param([string]$Stage,[string]$Mode,[object]$ControlRecord)`; its return value is discarded, and the umbrella accepts only the canonical artifact at the exact child path after invocation. `Verify` rejects an invoker and performs no dispatch. There is no umbrella `Apply`, `ExecutionManifestPath`, `ApprovedDigest`, `BindingObserver`, `CurrentBindingProvider`, `WhatIf`, `Confirm`, `SupportsShouldProcess`, approval loading, provider result, or provider correlation.

The closed control record contains only `schemaVersion`, `runId`, `sourceCommit`, `publicTenantKey`, `intentDigest`, `stateDigest`, `selectedStages`, `prerequisiteResults`, and `evidenceRunRelativePath`. `selectedStages` is the exact canonical selected order. `prerequisiteResults` is empty for the first selected stage and otherwise contains only the immediately preceding canonical stage result. Each subsystem remains independently runnable, and the selected subset forms a linear dependency chain without provider topology.

Before and after each `Assess` or `Plan` child dispatch, and around `Verify` evidence validation, the umbrella rechecks source `HEAD`, repository cleanliness, private intent, and private state. Source, intent, or state drift fails closed. Approval, WhatIf/Apply, `ShouldProcess`, provider mutation, state adoption, and provider read-back stay entirely within independently invoked child runbooks.

### Child-owned operator sequence

For every selected stage, the operator follows this order:

1. run the child assessment and invoke the child directly in `Plan` mode;
2. review that child manifest and record the exact child approval in child `approvals.json`;
3. invoke the child directly with `WhatIf`;
4. pass the child-specific hard stop and invoke the child directly with `Apply`;
5. complete child read-back, child state adoption where applicable, and the terminal child summary;
6. write the immutable canonical stage result at `<run>/stage-results/<stage>.json`;
7. stop if the result is `Failed`, `Manual`, `Blocked`, or `Refused`, otherwise repeat for the next selected dependency; and
8. after all selected results have literal `Passed`, run umbrella `Verify` without `SubsystemInvoker`.

Umbrella `Verify` never invokes a child. It validates the immutable child envelope and writes only the stage-only projection.

## Audience and ownership

The service owner approves the reviewed intent, records the approved digest, and accepts the residual risk of each run. The workstation administrator performs attended local operations on the approved Windows 11 workstation. An operator may run assessment to gather read-only evidence, but later cloud and tenant approvals remain separate responsibilities for the service owner, security administrators, and tenant administrators.

## Ordered state machine

1. **Prerequisites**: confirm Windows 11, administrator intent, repository integrity, and reviewed policy.
2. **Assessment**: run [Developer Workstation](01-developer-workstation.md) in read-only mode to prove current state and write assessment evidence.
3. **Preview and plan**: generate a workstation plan and execution manifest without mutating the machine.
4. **Digest approval**: the service owner reviews the exact manifest digest and approves only that manifest.
5. **Apply with `ShouldProcess`**: the workstation administrator removes `-WhatIf` only after approval; every native mutation stays behind PowerShell confirmation boundaries.
6. **Read-back**: each approved operation proves its exact postcondition or fails closed.
7. **Redacted evidence**: the run writes only non-secret execution evidence and summaries.
8. **Recovery and close**: any `Blocked`, `Refused`, or `Manual` item is escalated, reassessed, and re-approved before another run.

## Shared contract terms

- **Reviewed intent**: the already approved policy, repository state, and operator scope that define what the run may do.
- **Execution manifest**: the preview output that fixes the exact allowed actions, workstation identity, digest, expiry, and recovery contract for one attended run.
- **Evidence summary**: redacted operational evidence proving what was assessed, approved, attempted, read back, refused, or left manual.
- **`NoChange`**: the workstation already satisfies the reviewed postcondition.
- **`Create`**: the reviewed plan may add a missing local prerequisite in the exact way described by policy.
- **`Update`**: the reviewed plan may bring an approved prerequisite to the exact reviewed version.
- **`Manual`**: a human-only or unsupported boundary was reached; the run must stop or escalate without claiming verification.
- **`Blocked`**: the run cannot safely continue because state, identity, platform, or policy validation failed.
- **`Refused`**: the run intentionally declined a mutation because approval, interactivity, or confirmation requirements were not satisfied.

## Evidence boundaries

Evidence is written under the operator-selected report path, including the default `%LOCALAPPDATA%\CaldovaHrFrontier\runbook-evidence\...` paths used by the workstation runbook. Evidence may include command names, reviewed identifiers, non-secret account identifiers needed for read-back, digests, timestamps, statuses, and recovery instructions. Evidence must never include tokens, device codes, cookies, authorization headers, PATs, client secrets, certificate secrets, raw authentication responses, or workstation credential-store contents.

## Approval expiry and invalidation

Execution approval expires 30 minutes after manifest creation. Approval is invalid immediately if the repository commit changes, the workstation identity changes, the reviewed digest changes, the assessment digest changes, the operator broadens scope, or the workstation is restarted or partially mutated before successful close. Any invalidation requires a new assessment, a new preview, and a new digest approval.

## Interactive boundaries and unsupported APIs

These runbooks assume an attended PowerShell session on a local Windows 11 workstation. Elevation expectations, device-code entry, browser confirmation, MFA, Conditional Access, product terms, licensing acceptance, and any required restart are completed personally by the operator. Unsupported or human-only API boundaries remain `Manual`. GitHub Actions are prohibited tenant-preparation paths, and OIDC workload identities are prohibited for this local runbook baseline.

## Local-only tenant operations

All later GitHub, Azure, Azure DevOps, Power Platform, and SharePoint operations start from this workstation in an attended PowerShell session. No repository workflow, runner, PAT, token, password, client secret, or unattended identity prepares a tenant in this baseline. A token is never supplied to these scripts or stored in their evidence.

## Authentication lifecycle

Authentication happens only in later attended procedures after the workstation is initialized. The operator signs in with the supported device or web flow, performs immediate context read-back, completes the reviewed operation, performs final context read-back, signs out, deletes or removes the exact temporary profile where supported, and verifies cleanup. Cleanup failure is `Manual`, not success. If the account, tenant, subscription, project, or environment read-back is wrong or incomplete, the run stops before mutation.

## Escalation and recovery

When a step blocks, refuses, or leaves a manual item, stop immediately, preserve sanitized evidence, notify the service owner plus the responsible workstation or security administrator, and reassess before retrying. Recovery never broadens scope, changes package IDs, weakens security controls, or treats a `Manual` item as verified. Restart or partial failure always requires full reassessment, a new manifest, and a new digest.

## Repository-integrity expectations

Repository-bundled Superpowers skills and custom agents are integrity and presence checked by assessment only; they are never machine-installed by a workstation procedure. `.github/plugins` is expected to be absent in this baseline. Vendored skill content under `.github/skills` must never be edited by a workstation runbook or workstation procedure.

## Runbook catalogue

| Runbook | Scope | Status |
|---|---|---|
| [Developer Workstation](01-developer-workstation.md) | Independently runnable assessment, preview, approval, apply, read-back, and recovery for one approved Windows 11 administrator workstation; not wired by the lifecycle core. | In scope now |
| [Cloud Service Foundation Runbook](02-cloud-service-foundation.md) | Superseded stop notice for dormant cloud-foundation entry points; retained generic modules are not an approved operating path. | Superseded |
| [Customer Repository Handover](03-customer-handover.md) | Independently runnable local attended customer export assessment, approval, apply, independent validation, and human review; not wired by the lifecycle core. | In scope now |
| [Tenant 1 Lean Platform](../24-tenant-1-lean-platform-runbook.md) | Attended local private configuration, discovery, Bicep build, subscription `what-if`, boundary validation, and context/access read-back. | In scope now |
| [Tenant Trust Activation](../20-tenant-trust-activation-runbook.md) | Stop notice for the dormant trust command; it is not an active prerequisite or supported procedure. | Superseded |
| Production lifecycle subsystem invokers, provider procedures, publication, and deployment runbooks | Later attended operations that consume the accepted lifecycle-core contract. | Out of scope in Plan 1 |
