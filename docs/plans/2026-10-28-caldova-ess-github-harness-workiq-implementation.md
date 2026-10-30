# Caldova ESS-Equivalent GitHub Harness and Work IQ Implementation Plan

| Field | Value |
|---|---|
| **Version** | 0.2 |
| **Date** | 2026-10-29 |
| **Author** | Copilot |
| **Status** | Draft |
| **Scope** | Caldova project/demo; GF source/customer context: new employee-self-service implementation: capability-gated DEV/TEST slices, not live authorization |
| **References** | [Reviewed planning specification](../specs/2026-10-28-caldova-ess-github-harness-workiq-design.md), [Sprint](2026-10-28-caldova-ess-github-harness-workiq-sprint.md), [Proposed scoped ADR](../adr/0014-gf-ess-workiq-and-self-service-write-envelope.md), [HR source tooling](../../hr/src/scripts/README.md), [Solution source boundary](../../hr/src/solutions/README.md), [Caldova delivery design](../specs/2026-10-28-caldova-azure-devops-solution-cicd-design.md) |

## Caldova project and GF source boundary

This is a Caldova project/demo document using the explicitly identified GF source/customer scenario. GF facts, approvals, requirements and trademarks remain GF-scoped; project renaming does not establish Caldova corporate policy or runtime acceptance. See the [source and authority boundary](../README.md#caldova-project-and-gf-source-boundary). Existing stable IDs are retained for traceability, not reassigned.

> **For agentic workers:** Use `executing-plans` for inline execution with checkpoints, or `subagent-driven-development` only when explicitly selected. Steps use checkbox syntax. This plan is not execution approval.

**Goal:** Build and verify a new restricted ESS-equivalent with policy guidance, six self-only Workday operations and per-use-case Work IQ support, with traceable backend outcomes and business evidence.

**Architecture:** GitHub-harness skills handle bounded reasoning; deterministic Copilot Studio workflows own confirmation, transaction state, audit and execution. Workday uses a separate employee-delegated OAuth Access Layer; M365 actions use only a proven, enforceable Work IQ boundary. Unknown product/API/source-format contracts stop their dependent slice instead of being replaced by guesses.

**Tech stack:** Copilot Studio GitHub harness/workflows, the Microsoft Workday connector with delegated OAuth, Work IQ MCP, supported Power Platform solution tooling, authoritative GitHub source with Azure Pipelines CI/CD, existing Pester 5.7.1 and Python `jsonschema`. Azure Repos replication is separate. Runtime source format is a Task 1 discovery output, not assumed classic topic YAML.

**Spec:** [Caldova ESS-equivalent specification](../specs/2026-10-28-caldova-ess-github-harness-workiq-design.md), reviewed by the user on 2026-10-28 as the planning basis. Formal governance and operational gates remain open.

## Global constraints

- New implementation; there is no deployed ESS source baseline to refactor or migrate.
- Switzerland first; DEV build and TEST verification only. Production is excluded.
- Preserve the five existing packages, policy-only read envelope, Recruiting's open decision and HR Operations add-only/blocked-write boundaries.
- Only the authenticated employee's own records, using delegated OAuth. No supplied target employee, shared maker/HR identity or Basic-auth fallback.
- Six selected transactions: personal phone, personal email, home address, emergency contact, time-off submission and confirmed Workday Help case creation.
- Workflow/Access Layer enforces confirmation, scope, current state, replay protection, audit and explicit failure outside model instructions.
- No raw SOAP/REST or unbounded M365 mutation tools on the reasoning node.
- Split prepare/execute/status calls; no user or Workday approval waits inside the 100-second synchronous workflow-tool limit.
- Memory remains off for write-capable agents; connected-agent delegation stays blocked.
- Synthetic data in source/tests. No secrets, tenant-specific connection values, production exports, employee PDFs, master values or confidential attachments in Git.
- Work IQ use is per use case; claimed Privacy approval remains user-reported until its scope/reference and effective controls are verified.
- No installation, tenant sign-in, permission change, live test, commit or push without separate authorization. Proposed commit messages below are future checkpoints only.

## 1. Execution setup and non-negotiable gates

Before any code execution, follow the external-worktree prerequisite in the [workstation runbook](../../infra/docs/runbooks/01-developer-workstation.md#external-worktree-prerequisite) and the repository `using-git-worktrees` workflow. Resolve the sibling `wt` root from the primary checkout, prove write/delete access and the path budget, and use a reviewed short branch name. Do not create a worktree during planning or change ACL/long-path settings.

Keep actual approvals, tenant connection settings and runtime evidence in an approved private location outside Git. The operator supplies that exact location for a live task. No sample tenant URL or employee reference becomes a default.

Every implementation task has two gates:

1. **Local gate:** approved synthetic source/test changes in an isolated branch.
2. **Live gate:** accountable business/HRIS/Privacy authorization, exact environment/identity, supported operation and effective permission proof for the selected action.

A local green test does not close the live gate. Missing API evidence is a blocking outcome, not a task to invent an endpoint. If native tooling cannot enforce the boundary, stop and obtain a reviewed mediation design before adding a service/backend.

## 2. File and source ownership map

These are intended new paths, not files claimed to exist. Do not generate any of them merely by opening this plan.

| Intended path | Responsibility |
|---|---|
| `hr\src\ess\README.md` | Scenario/source map, status and canonical ownership; links to native generated components rather than duplicates |
| `hr\src\ess\contracts\operations.json` | Six logical operations, permitted semantic fields, disabled-by-default state and evidence references; no endpoint credentials |
| `hr\src\ess\contracts\operation.schema.json` | Strict structure/allowed keys/enums for operation records |
| `hr\src\ess\contracts\messages.schema.json` | Proposed prepare/execute/status response contracts and outcome enums |
| `hr\src\ess\contracts\m365-scopes.json` | Per-use-case purpose, resources, read/draft/action boundaries and activation evidence |
| `hr\src\ess\source-map.json` | One canonical native source file/component mapping per logical skill/workflow, captured after supported format discovery |
| `hr\src\ess\capability-evidence.json` | Sanitized proof references, source/configuration revisions and explicit unavailable/blocked results; no raw tenant evidence |
| `hr\src\ess\evaluations\golden-cases.json` | Owner-reviewed synthetic scenario inputs/expected results and required authorization context |
| `hr\src\ess\evaluations\negative-cases.json` | Cross-user, confirmation, injection, state, timeout/replay and data-disclosure cases |
| `hr\tests\fixtures\gf-ess\` | Synthetic messages/outcomes and redacted native source/evaluation fixtures |
| `hr\tests\pester\GfEss.Contracts.Tests.ps1` | Contract/schema/disabled-default tests |
| `hr\tests\pester\GfEss.SourceMapping.Tests.ps1` | No missing/duplicate native assets, raw pass-through or unsupported source assumptions |
| `hr\tests\pester\GfEss.TransactionEvidence.Tests.ps1` | Validate canonical evaluation evidence against required actor/action/outcome scenarios |
| `hr\tests\pester\GfEss.WorkIq.Tests.ps1` | Per-use-case M365 scope/confirmation/evidence tests |
| `hr\tests\pester\GfEss.Delivery.Tests.ps1` | Artifact/source mapping, private-setting exclusion and TEST verification evidence |
| `hr\src\scripts\Test-GfEssRunEvidence.ps1` | Offline validation of collected, sanitized run evidence; never creates runtime proof or calls a live system |
| `hr\README.md`, `hr\src\scripts\README.md`, `hr\src\solutions\README.md` | Update only when implementation changes their actual inventories/behavior |

Generated agent/skill/workflow/connection-reference source belongs in the **one verified solution source root** recorded by Task 1. Do not prescribe an unverified solution unique name or component-file extension. The exact files to edit are resolved from `source-map.json`, not a guessed `topics\` directory. Hand-authored contract/evaluation records are not a second editable copy of native runtime components.

If GitHub-harness assets are not exportable through the selected format, block source/delivery tasks and revise the mapping with platform evidence; do not stage a partial export and call it a complete rebuild.

## 3. Shared logical interfaces

The following are proposed application contracts, not Microsoft API operation names.

**Operation IDs:** `update_personal_phone`, `update_personal_email`, `update_home_address`, `update_emergency_contact`, `submit_time_off`, `create_help_case`.

**Prepare input:** trusted actor context plus `operationId` and validated employee-provided task input. The public agent input must not accept an arbitrary `employeeId`, Workday service/path, connector connection or destination operation.

**Prepared result:** `operationRef`, normalized review summary, selected operation, current-state/version reference, allowed destination, validity and `AwaitingConfirmation` state. Personal payload is confined to approved short-lived execution state, not the audit/contract repository.

**Execute input:** opaque `operationRef` and a trusted confirmation artifact whose actor/content/operation/destination/version/expiry can be verified server-side. A model-provided Boolean is invalid.

**Status result:**

```json
{
  "schemaVersion": "1.0",
  "operationId": "create_help_case",
  "operationRef": "operation-synthetic-001",
  "status": "Uncertain",
  "outcomeRef": null,
  "errorCode": "remote_timeout",
  "retryDisposition": "reconcile_only"
}
```

Allowed operational statuses are `Draft`, `AwaitingConfirmation`, `Revalidating`, `Executing`, `Completed`, `Submitted`, `Failed`, `Uncertain`, `Reconciled`, `Blocked`, `Cancelled`. The status response contains no current/proposed personal-field values. `Completed` requires verified outcome evidence; a leave request can remain `Submitted`; an unknown case result cannot become `Completed` without a verified reference.

The workflow owns persistent status and audit. Direct reads of model text or fixture JSON are not live Workday proof.

## Task 1: Prove and record the selected runtime/source contracts

**Files:** create `hr\src\ess\README.md`, `source-map.json`, `capability-evidence.json`, `contracts\operations.json`, `contracts\operation.schema.json`; create `hr\tests\pester\GfEss.Contracts.Tests.ps1` and `GfEss.SourceMapping.Tests.ps1`. Native source files are identified by the proven export and recorded in the source map before modification.

**Consumes:** reviewed specification, scoped governance proposal and separately authorized access to an empty/restricted DEV proof agent if a live proof is approved.

**Produces:** exact component/source mapping; six disabled operation records; evidence on delegated OAuth, workflow confirmation, Work IQ restrictions and export/import completeness. Each capability records `unverified`, `blocked` or `verified`, with a source/configuration revision and proof reference.

- [ ] Write the inventory/disabled-default test first:

```powershell
BeforeAll {
    $root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
    $path = Join-Path $root 'hr\src\ess\contracts\operations.json'
}
It 'declares exactly the requested operations and disables unverified capabilities' {
    $records = @(Get-Content -LiteralPath $path -Raw | ConvertFrom-Json)
    @($records.operationId | Sort-Object) | Should -Be @(
        'create_help_case', 'submit_time_off', 'update_emergency_contact',
        'update_home_address', 'update_personal_email', 'update_personal_phone'
    )
    foreach ($record in $records) {
        if ($record.capabilityState -cne 'verified') {
            $record.activation | Should -BeExactly 'disabled'
        }
        elseif ($record.activation -ceq 'enabled') {
            $record.evidenceRef | Should -Not -BeNullOrEmpty
        }
    }
}
```

- [ ] Run `Invoke-Pester -Path 'hr\tests\pester\GfEss.Contracts.Tests.ps1' -Output Detailed`; confirm a missing-file failure before authoring the six records.
- [ ] Implement the records and strict schema with only declared properties; initially set every `capabilityState` to `unverified` and `activation` to `disabled`. Permit `verified` only with revision-bound reviewed proof, not a manually asserted flag. Distinguish semantic field names from backend fields whose mapping requires HRIS proof. Use the existing Python `jsonschema` dependency through Pester rather than installing another validator.
- [ ] With separate authorization, prove a minimal GitHub-harness workflow tool, trusted confirmation mechanism, two-user self-context and chosen source export/import. Capture unsupported behavior explicitly. No production data or mutation is needed to prove source mapping.
- [ ] Record native component names/types/source-relative paths and configuration proof references. Test that every map entry resolves under the selected canonical source root and each native asset has one owner. A successful export command alone is insufficient.
- [ ] Re-run the two focused test files. Stop dependent live work unless capability-specific proof is verified. Suggested local checkpoint: `test(ess): define disabled operation and native-source contracts`.

## Task 2: Define evaluation fixtures and response semantics first

**Files:** create `hr\src\ess\contracts\messages.schema.json`, both evaluation JSON files, synthetic fixtures under `hr\tests\fixtures\gf-ess\`, `hr\tests\pester\GfEss.TransactionEvidence.Tests.ps1` and `hr\src\scripts\Test-GfEssRunEvidence.ps1`; update `hr\src\scripts\README.md` when that validator actually exists.

**Consumes:** Task 1 operation/source contracts and the specification's mandatory acceptance groups.

**Produces:** versioned synthetic golden/negative sets and an offline evidence validator. Validator inputs are explicit `-RunEvidencePath` and `-OutputPath`; output contains `schemaVersion`, source/evaluation/configuration references, case results and `Passed` or `Failed`. Structural parsing failure is an error, not an empty passing set.

- [ ] Write schema tests for every status and for rejection of undeclared personal-value fields, missing references, wrong operations and malformed evidence.
- [ ] Add positive/negative vectors for all six operations and policy/M365 scenarios. Example canonical expectation:

```json
{
  "caseId": "case-confirmation-missing",
  "operationId": "create_help_case",
  "actor": "employee-synthetic-a",
  "condition": "no_trusted_confirmation",
  "expectedStatus": "Blocked",
  "expectedMutationCount": 0,
  "expectedErrorCode": "confirmation_required"
}
```

- [ ] Run the contracts/evidence tests and confirm missing validator/schema coverage fails. Implement strict parsing and case-set validation, retaining failed cases and source evidence references.
- [ ] Ensure duplicate case IDs, missing mandatory cases, wrong configuration/source revisions and fabricated `Completed` outcomes without references fail validation. A valid JSON structure never attests that a runtime test occurred.
- [ ] Run `Invoke-Pester -Path @('hr\tests\pester\GfEss.Contracts.Tests.ps1','hr\tests\pester\GfEss.TransactionEvidence.Tests.ps1') -Output Detailed`.
- [ ] Review the evaluation criteria with the business/HRIS owner before authoring runtime mutations. Suggested checkpoint: `test(ess): add synthetic safety and outcome contracts`.

## Task 3: Implement trusted confirmation, self binding, audit and reconciliation

**Files:** modify only Task 1-mapped native workflow/skill assets for prepare/execute/status, self resolution, audit and stop controls; update `messages.schema.json`, `source-map.json`, synthetic fixtures and `GfEss.TransactionEvidence.Tests.ps1`.

**Consumes:** Tasks 1-2, an approved confirmation/short-lived-state design, and separately authorized DEV test identities. If native controls cannot enforce the envelope, stop for the mediation design; do not create an unreviewed service.

**Produces:** prepare/execute/status interfaces from section 3; self-only authorization; deterministic outcome/audit transitions; explicit stop and reconciliation behavior.

- [ ] Before runtime authoring, add cases for forged actor/employee target, model-supplied confirmation, changed content/destination, expiry, user switch, stale state, replay and uncertain outcome. Required result is blocked/no mutation or reconciliation-only as specified.
- [ ] Implement workflow steps in this order:

| Step | Required implementation behavior |
|---|---|
| Resolve | Obtain authenticated actor and employee mapping through the proven trusted platform path, never a chat parameter. Verify delegated connection belongs to that actor. |
| Prepare | Validate operation/fields, read current relevant state and construct the exact review summary. Keep proposed values only in approved short-lived protected state. |
| Confirm | Capture explicit user action in a trusted platform/workflow mechanism and bind it to actor, proposal, content, target, destination, version and expiry. |
| Revalidate | Verify confirmation and current state. Prove an expected-version or HRIS-approved concurrency mechanism; a read followed by a write is not atomic by itself. |
| Execute | Record the opaque operation/replay reference before invoking only the allow-listed action. Reject changed state or incomplete operation proof. |
| Reconcile | Map immediate/pending/rejected/uncertain results explicitly; no blind mutation retry. Read original operation state under the same authorization. |
| Audit | Workflow writes minimized operation/configuration/confirmation/outcome references and statuses. Agent text is not the audit producer. |

- [ ] Prove the reasoning node cannot invoke raw Workday operations or generic M365 writes around this sequence. A negative test must attempt the bypass, not merely inspect instructions for a warning sentence.
- [ ] Test stop behavior before/after remote submission, policy denial, throttling and uncertain results. Returning `Uncertain` must retain the operation for reconciliation and never claim success.
- [ ] Keep synchronous agent-tool calls inside 100 seconds; test prepare/status independently and do not wait for humans or Workday business-process approval.
- [ ] Validate collected synthetic runtime evidence with `Test-GfEssRunEvidence.ps1` and rerun transaction/source-mapping tests. Suggested checkpoint: `feat(ess): enforce self-only confirmed workflow operations`.

## Task 4: Deliver policy and personal phone/email as the first vertical slice

**Files:** modify mapped policy/retrieval, contact-detail skill/workflow and Access Layer assets; update the phone/email records in `operations.json`, evaluation files, source map and transaction/source tests.

**Consumes:** Tasks 1-3; approved Swiss source boundary; HRIS-confirmed phone/email mappings and references; operation-specific activation authorization.

**Produces:** source-cited policy behavior and verified self-only phone/email updates, with no broadened work-account/contact change.

- [ ] Add failures for other-region/restricted/archived knowledge, unsupported personal data, unselected work/secondary contact mutation and primary/secondary side effects.
- [ ] Author the bounded agent skill behavior: clarify missing information; show current/permitted proposed change; never generate an authorization or assume a value from mail/chat.
- [ ] Implement Access Layer mapping from approved semantic fields to the proven Workday template/API. Retain the employee's delegated connection; never reuse an upstream ISU setup or raw sample SOAP from the model.
- [ ] Verify preservation of unrelated records and enforce the Task 3 concurrency/confirmation mechanism. Test rejected validation and pending Workday business processes separately from immediate success.
- [ ] In authorized synthetic/test profiles, capture actual before/after/status evidence without copying raw values into audit/Git. Demonstrate two-user denial and an attempted raw-tool bypass.
- [ ] Run the contract/source/transaction tests and offline evidence validation. Activate phone/email independently only when evidence and approvals match the exact release configuration. Suggested checkpoint: `feat(ess): add policy and confirmed personal contact updates`.

## Task 5: Deliver home-address and emergency-contact extensions

**Files:** modify mapped address/emergency-contact skills/workflows and Access Layer assets; update their two operation contracts, evaluation vectors, source map and transaction tests.

**Consumes:** Tasks 1-3; HRIS evidence identifying actual write APIs, expected-version/concurrency behavior, required/reference fields, effective-date semantics and delegated permissions; Privacy approval for related-person data.

**Produces:** verified update of only the selected home address or emergency contact, without whole-profile or related-person replacement.

- [ ] Write cases for missing reference data, country/format validation, wrong selected entry, unauthorized effective date, concurrent edit and attempted unrelated contact deletion.
- [ ] Review the exact API field mapping with HRIS before setting the operation to an executable state. A read topic or ISO-country reference table is not write proof; no accepted contract means this task remains blocked.
- [ ] Implement the mapped workflow using Task 3's prepare/confirm/execute/status protocol. Show the user which entry/fields will change; do not collect unrelated family information or fetch candidate/identity records.
- [ ] Validate provider-required fields and record-selection semantics without silently filling omitted personal facts. Preserve every unselected entry.
- [ ] Run the synthetic/authorized test-profile scenarios including denied permissions and ambiguous remote outcomes. Verify no contact values appear in persistent audit, fixtures, logs or default receipts.
- [ ] Re-run focused transaction/source/contract tests and validate observed runtime evidence. Activate address and emergency contact separately. Suggested checkpoint: `feat(ess): add bounded home and emergency-contact changes`.

## Task 6: Deliver time-off submission without an approval authority

**Files:** modify mapped leave request/status skills/workflows and Access Layer assets; update the time-off operation record, evaluation cases, source map and transaction tests.

**Consumes:** Tasks 1-3; tenant-confirmed leave types/units/required fields, request/status contract and existing business-process approval rules.

**Produces:** a reviewed self-only request with verified submission reference and accurate Pending/terminal state, not an eligibility or leave-approval decision.

- [ ] Add tests for invalid types/units/date ranges, insufficient/unknown eligibility evidence, stale confirmation, duplicate submission and an existing pending request.
- [ ] Reuse the official time-off sample only as a mapping/test reference. Translate its classic topic/template structure into the Task 1-supported runtime representation.
- [ ] Read only necessary own balances/reference data; collect exact employee-requested type/dates/units. Never treat balances or calendar availability as permission to approve.
- [ ] Submit once after trusted confirmation, persist the request reference, and return `Submitted` when Workday approval is pending. Status polling is a separate authorized tool call.
- [ ] Test Workday rejection/approval, connection loss before/after submission, duplicate clicks and replay. No blind request repetition or automatic cancellation.
- [ ] Run transaction/source tests and validate observed backend request/status evidence. Optional calendar messages belong to Task 8 and need a separate confirmation. Suggested checkpoint: `feat(ess): submit time off through existing Workday approval`.

## Task 7: Deliver employee-confirmed Workday Help cases

**Files:** modify mapped case-drafting/create/status skills/workflows and Access Layer assets; update the Help operation record, case fixtures/evaluations, source map and transaction tests.

**Consumes:** Tasks 1-3; a proven Workday Help create/status API with delegated scope, approved categories/routing, required fields and duplicate behavior.

**Produces:** one verified Workday Help case/reference/status after employee review and confirmation. No inferred endpoint, email substitute or automatic fallback case.

- [ ] Write tests before authoring for request-without-confirmation, automatic policy-fallback submission, missing routing, unsupported attachments, embedded instructions, duplicate click and uncertain create response.
- [ ] HRIS/Workday Help owner supplies supported create/status contract evidence. If unavailable, keep `create_help_case` disabled and report a manual support handoff as a handoff, not case success.
- [ ] Implement a minimal draft from employee-provided issue/context and approved routing choices. Exclude automatic transcripts, contact-field dumps, attachments and unrelated mail/chat.
- [ ] Capture trusted confirmation against exact description/category/routing and actor. Execute only through the Access Layer; record a protected replay reference before submission.
- [ ] Verify returned case reference/status through the supported result/read-back route. On timeout, reconcile before any resubmission; uncertain outcome is not `Completed`.
- [ ] Run transaction/source tests and validate backend case evidence. Confirm user feedback identifies the actual case reference/status and follow-up route. Suggested checkpoint: `feat(ess): create reviewed Workday Help cases`.

## Task 8: Add per-use-case Work IQ and requested Word outputs

**Files:** create `hr\src\ess\contracts\m365-scopes.json` and `hr\tests\pester\GfEss.WorkIq.Tests.ps1`; modify mapped M365/document skills/workflows and corresponding evaluation/source records.

**Consumes:** Tasks 1-3, the specification's M365 matrix and independently approved tools/resources/read/draft/action scopes. Task 1 must establish supported identity and enforceable restrictions; a workload checkbox is insufficient.

**Produces:** approved scoped retrieval/drafts and separately confirmed M365 side effects; no generic mutation bypass.

- [ ] Write a failing scope test: every enabled scenario must declare purpose, permitted resources, read/draft/action operations, allowed destinations, confirmation requirement, retention and proof reference. Reject an enabled wildcard send/update/delete route.
- [ ] Verify effective Work IQ tenant/agent/client permissions, including the documented differences in write defaults. If available admin controls cannot enforce the envelope, stop this action track for mediation design rather than prompt-only restrictions.
- [ ] Configure only needed workloads and test allowed/denied resource paths under the employee identity. Relevant message/thread reads require a defined user-selected scope; messages are never Workday authorization.
- [ ] Implement draft-first outputs. The exact recipient/thread/site/content/action is separately confirmed before send/post/storage; leave submission alone never causes a meeting or status message.
- [ ] For Word, prove native generation or an admitted template skill independently from Work IQ file access/storage. Test missing values, template fidelity, authorized destination, temporary-file cleanup, retention and minimal receipts; do not reproduce the master profile.
- [ ] Use only reviewed pinned Developer Kit/CAT assets. Inspect licensing, scripts/dependencies, outbound telemetry, secret handling and sandbox support before importing any bundle.
- [ ] Run Work IQ/source/evidence tests and observed allowed/denied/draft/send scenarios. A native card package for the standard harness or Cowork-only plugin cannot be counted as GitHub-harness compatibility. Suggested checkpoint: `feat(ess): add scoped M365 and requested document support`.

## Task 9: Prove reviewed-source capture and TEST delivery

**Files:** modify Task 1-selected canonical solution source, `source-map.json`, `capability-evidence.json`, `hr\tests\pester\GfEss.Delivery.Tests.ps1` and owning READMEs when inventories change. Pipeline YAML belongs to the authoritative GitHub source mapping defined by the Caldova CI/CD package.

**Consumes:** Tasks 1-3, complete operation evidence and direct GitHub-source Caldova delivery prerequisites. The Azure secondary is not a dependency. No default tenant or production destination is inferred.

**Produces:** captured branch/PR, identified source/artifact, complete asset mapping, TEST import/configuration/runtime evidence and explicit disabled capabilities.

- [ ] Write tests that fail on a missing native asset/skill, private environment value, raw export ZIP in Git, missing source revision, enabled unverified operation or an arbitrary deploy-from-capture branch.
- [ ] With separate export authorization, evaluate the existing module's explicit-path interfaces:

```powershell
Import-Module '.\hr\src\scripts\modules\Caldova.HrFrontier.Solutions\Caldova.HrFrontier.Solutions.psd1'
Get-Command Export-HrSolutionPackage, Expand-HrSolutionPackage -Syntax
```

`Export-HrSolutionPackage` accepts `-TenantConfigurationPath` and exports unmanaged DEV. `Expand-HrSolutionPackage` writes/clobbers its target. The current wrapper does not expose that explicit private-path input and the solution README documents a component-unpack limitation. Do not run the wrapper or unpack directly over accepted source as proof of this runtime.

- [ ] Export into an explicitly approved private temporary location and unpack into a separate candidate directory only after chosen-harness completeness is demonstrated. Inspect/sanitize a diff into the capture branch; no direct main write or hidden deletion.
- [ ] Build/test the reviewed GitHub source through the Caldova Azure Pipelines design. Bind artifact identity, source/evaluation/configuration versions and disabled operation list. No pipeline file or task version is fabricated if that package has not established it.
- [ ] With separate TEST import authorization, set private environment values/connections through the reviewed release mechanism; test all selected identities, source permissions, skills and workflow components after import.
- [ ] Run delivery/source/contract tests plus operation-specific TEST evaluations. A green local fixture test or successful import alone does not establish runtime parity.
- [ ] Record per-capability acceptance/blocked state and review as a human. Suggested checkpoint: `test(ess): verify reviewed-source TEST delivery`.

## Task 10: Validate business outcomes, stop/recovery and handover

**Files:** update synthetic evaluation coverage and the offline evidence validator/tests only for actual learned requirements; update the three ESS design artifacts and README status/routing from observed evidence. Maintain private live evidence outside Git.

**Consumes:** Task 9 TEST results, operation references, approved retention/incident/owner routes and recorded manual baseline.

**Produces:** per-scenario safe-completion/value report, human acceptance or explicit no-go, stop/reconciliation demonstration and a later-production proposal only if requested.

- [ ] Record the manual baseline and pilot method for each scenario: steps/active time, correct completion, exceptions/support, employee feedback, latency and credit/cost per safe completion. Do not invent savings or combine draft-only replies with verified backend transactions.
- [ ] Require every signed-off mandatory safety/golden case to pass with no unauthorized/cross-user/duplicate mutation. Field correctness, Workday approval and case creation each use backend evidence, not an LLM-quality score.
- [ ] Demonstrate disabling new submissions, retaining/reconciling in-flight requests and re-enabling only an approved configuration. Show that code rollback does not imply data rollback, cancellation or deletion.
- [ ] Re-run the smallest local files covering the release; use the CI-defined broader suite before integration when execution reaches that stage. For this planned ESS suite:

```powershell
$ErrorActionPreference = 'Stop'
Import-Module Pester -RequiredVersion 5.7.1
$result = Invoke-Pester -Path @(
    'hr\tests\pester\GfEss.Contracts.Tests.ps1',
    'hr\tests\pester\GfEss.SourceMapping.Tests.ps1',
    'hr\tests\pester\GfEss.TransactionEvidence.Tests.ps1',
    'hr\tests\pester\GfEss.WorkIq.Tests.ps1',
    'hr\tests\pester\GfEss.Delivery.Tests.ps1'
) -Output Detailed -PassThru
if ($result.Result -ne 'Passed') { throw 'ESS local verification failed.' }
& '.\.github\cli\verify-repository-safety.ps1'
git --no-pager diff --check
if ($LASTEXITCODE -ne 0) { throw 'Whitespace verification failed.' }
```

These tests/scripts are planned deliverables, not available or executed by this planning task. Preserve existing source/lifecycle regression tests when changing shared tooling.

- [ ] Review missing capability, failed/uncertain results, value thresholds and privacy evidence with named owners. A blocked case/address/contact operation prevents claiming full six-operation delivery; report delivered slices honestly.
- [ ] Update catalogue metadata/status only from the actual acceptance decision. Suggested checkpoint: `docs(ess): record TEST and value acceptance evidence`.

## 4. Dependency and review checklist

| Specification coverage | Implementation task |
|---|---|
| ESS/reference/Developer Kit parity and source boundaries | 1, 8, 9 |
| Six-operation field/action/API contracts | 1, 4, 5, 6, 7 |
| Authenticated self-only delegated identity | 1, 3 and every operation's two-user tests |
| Workflow-owned confirmation, concurrency, replay, audit and 100-second call boundary | 2, 3 and runtime evidence in 4-9 |
| Per-use-case Work IQ, draft/action distinction and Word privacy | 8 |
| Data minimization, memory-off, delegation block and declarations | 1-3, 8-10 |
| Harness source/ALM completeness and TEST configuration | 1, 9 |
| Business value, stop/reconciliation and honest delivery states | 10 |

For each task, review requirements coverage and actual evidence before taking the next dependent task. Use red-green tests for local code/contracts and before/after negative cases for low-code runtime changes; never replace the latter with static prompt-text inspection.

## 5. Current handoff status

This plan is a Draft derived from the user-reviewed specification. No source folders, test files, workflow assets, connection settings or backend APIs described above are implemented by writing it. Formal governance, API, identity, permission, privacy and capacity gates remain visible.

Implementation can later run inline through `executing-plans` with checkpoints, or through explicitly selected subagent-driven slices. Execution requires a separate user decision and appropriate operation/environment authorization. No commit/push is requested by this plan.

Board synchronization is Deferred - not synchronized.
