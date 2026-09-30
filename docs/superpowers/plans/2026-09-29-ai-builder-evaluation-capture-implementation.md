# AI Builder Evaluation Capture Implementation Plan

| Field | Value |
|---|---|
| **Version** | 1.1 |
| **Date** | 2026-09-30 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Draft |
| **Scope** | HR Solution Architecture - Tenant 2 DEV AI Builder evaluation capture and issue 13 completion |
| **References** | [AI Builder Evaluation Capture Design Addendum](../specs/2026-09-29-ai-builder-evaluation-capture-design.md), [Original Tenant 2 AI Builder Model Sprint Plan](./2026-09-25-tenant-2-ai-builder-models-implementation.md), [Documentation Policy](../../README.md) |

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the blocked no-flow evidence path with a restricted, attended Tenant 2 DEV capture flow, replay its retained AI Builder output locally, evaluate fixed model `PersonalMasterDataFixed` version `1.0` exactly once against the qualified holdouts, and continue to the general model only after the fixed capture and evaluation pattern succeeds.

**Architecture:** Repository contracts and PowerShell 5.1 tooling define append-only lifecycle events, raw/canonical capture pairs, deterministic UTF-8 serialization, exact correlation, local replay, and calculated fail-closed gates. After readiness approval, attended tenant execution is strictly linear: publish exact fixed `1.0` as `evaluation_published`; create and secure the separate unmanaged DEV-only evaluation solution and complete owner-restricted manual flow bound to that published version; run one separate attended training-PDF capture; implement the adapter with TDD; calculate capability; and only then expose holdouts. The flow uses only AI Builder and one dedicated synthetic-evidence location. Tenant operations are never simulated by Pester, and addition to `caldovahrfrontier` remains a separate calculated decision.

**Tech Stack:** Windows PowerShell 5.1, Pester 5.7.1, JSON Schema draft 2020-12, SHA-256, UTF-8 JSON, Microsoft Power Apps and AI Builder, Microsoft Power Automate, Tenant 2 OneDrive or SharePoint, Microsoft Power Platform CLI (`pac`), Git, and GitHub CLI (`gh`).

**Spec:** `docs/superpowers/specs/2026-09-29-ai-builder-evaluation-capture-design.md`

## Supersession and preserved work

This plan supersedes **only** the conflicting steps in the original plan concerning:

1. the no-flow capture prohibition;
2. publication only after evaluation; and
3. the downstream sequencing of original Task 6 and later tasks.

Original Tasks 1–5 are completed inputs and remain preserved. All unchanged corpus, field-contract, synthetic-data, exact-attribution, replay, calculated-gate, zero-false-value, holdout-consumption, evidence-retention, tenant-isolation, and no-automated-write rules remain in force. The historical `trained -> blocked` event and `model-test-capability.json` remain unchanged. The automatically created, untrained fixed draft `2.0` remains untouched.

## Global Constraints

- Work only in `C:\Users\anrizzi\Repositories\caldova-hr-frontier.worktrees\issue-13-ai-builder-setup-worktree`.
- Tenant operations are limited to Tenant 2 DEV: alias `caldova25668747`, environment ID `84ad4c54-41d9-e5df-ba07-188b4719594a`, attended administrator `admin@caldova25668747.onmicrosoft.com`.
- Do not mutate Tenant 1, Tenant 3, TEST, or PROD.
- Do not alter or reclassify the historical blocked capability record. Append new lifecycle and capture evidence.
- Use fixed model `PersonalMasterDataFixed`, model ID `74b09a72-d1f1-4598-bc4d-3746d5c97acc`, trained version `1.0`. Never train, edit, delete, publish, or capture with draft `2.0`.
- The evaluation solution is unmanaged, DEV-only, separate from `caldovahrfrontier`, never exported or promoted, and contains no business components.
- Final evaluation-solution, flow, connection-reference, and evidence-folder names are selected and recorded at an attended approval checkpoint before tenant creation. Do not infer final names from candidate names.
- Microsoft `Process documents` cannot be selected, bound, or configured until exact fixed model `1.0` has been published and recorded as `evaluation_published`. Do not create a complete or partial capture flow before that dependency passes.
- Restrict ownership and run permission to the named administrator. Keep the flow disabled except during an attended capture window.
- Secure inputs and outputs are required on the file-bearing manual trigger and AI Builder action.
- Permit only AI Builder and one dedicated Tenant 2 OneDrive or SharePoint synthetic-evidence location. Stop if HTTP, custom connectors, email, Teams, Workday, agents, production sources, or another connector is required.
- Use only the qualified synthetic corpus. Never store real candidate, pre-hire, worker, employee, or PeopleDoc data.
- Never auto-delete source PDFs, raw responses, canonical envelopes, or calculated evidence. Cleanup requires a separate explicit approval.
- Raw AI Builder response bytes are immutable provenance. The canonical envelope is a deterministic 17-field projection, not a replacement for raw evidence.
- The adapter independently hashes source PDFs, recalculates every evidence hash, checks exact ordinal correlation, validates numeric/null confidence, replays from raw bytes, and fails closed.
- Capability proof uses one allow-listed training PDF. No holdout may be exposed before all `AEC-G001` through `AEC-G007` gates pass.
- Each of the four fixed holdouts is processed exactly once. A retry has a new execution `run_id`; failed evidence remains visible.
- If any fixed holdout result influences retagging, retraining, or model change, consume the complete fixed holdout set and require newly generated unseen acceptance documents under a new evidence run.
- `evaluation_published` is platform executability only. It does not grant business use, packaging, automated-write, Workday, TEST, PROD, or Tenant 1 approval.
- Assign `approved_for_solution` only from calculated gates. Add fixed `1.0` to `caldovahrfrontier` only after that stage.
- Do not create `PersonalMasterDataGeneral` until fixed capture and evaluation succeed and the attended decision checkpoint authorizes continuation.
- Screenshots supplement evidence but never replace machine-readable bytes, hashes, values, nulls, or confidence.
- Use repository-relative forward-slash paths in Markdown. Commands may use Windows paths and backslashes.
- Run PowerShell tests with Windows PowerShell 5.1 and the verified Pester manifest `C:\Users\anrizzi\OneDrive - Microsoft\Documents\PowerShell\Modules\Pester\5.7.1\Pester.psd1`.
- Every local behavior change is TDD: add one focused failing Pester test, run red, implement the minimum behavior, run green, then run regressions.
- Pester tests use synthetic `$TestDrive` files and test adapters only. They never authenticate, call Power Platform, mutate a tenant, or pretend an attended observation occurred.
- Every implementation commit includes `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>`.
- Do not push unless the user explicitly approves a push after branch review.

## File Map and Interfaces

| Path | Responsibility |
|---|---|
| `hr/src/ai-builder/contracts/evaluation-capture-pair.schema.json` | Closed contract for source, raw-response, canonical-envelope, and SHA-256 correlation evidence. |
| `hr/src/ai-builder/contracts/prediction-capture.schema.json` | Existing evaluator input updated from Quick Test metadata to flow-capture metadata. |
| `hr/src/scripts/modules/Caldova.HrFrontier.AiBuilder/Private/ConvertTo-HrAiBuilderCanonicalJson.ps1` | Deterministic UTF-8-without-BOM, ordered, compact JSON serialization ending with one LF. |
| `hr/src/scripts/modules/Caldova.HrFrontier.AiBuilder/Public/ConvertFrom-HrAiBuilderEvaluationCapture.ps1` | Reads retained source/raw/envelope files, verifies exact correlation and hashes, projects 17 fields, and writes prediction capture. |
| `hr/src/scripts/modules/Caldova.HrFrontier.AiBuilder/Public/Test-HrAiBuilderCapturePair.ps1` | Fail-closed validation of one raw/canonical/source evidence pair. |
| `hr/src/scripts/adapters/ConvertFrom-HrAiBuilderEvaluationCapture.ps1` | Six-parameter compatibility entry point used by the existing importer; delegates to the module function with repository contract paths. |
| `hr/src/scripts/modules/Caldova.HrFrontier.AiBuilder/Public/Set-HrAiBuilderModelRecord.ps1` | Append-only lifecycle transitions including controlled resumption from the historical fixed blocker. |
| `hr/src/scripts/modules/Caldova.HrFrontier.AiBuilder/Public/Test-HrAiBuilderStrictGates.ps1` | Existing strict gates extended with capture-pair, lifecycle, corpus-revision, and replay gates. |
| `hr/src/scripts/Import-AiBuilderQuickTestResults.ps1` | Renamed in behavior and retained for compatibility; imports evaluation-flow capture pairs through the tested adapter. |
| `hr/src/scripts/Measure-AiBuilderEvaluation.ps1` | Existing metrics writer updated for new lifecycle disposition and capture provenance. |
| `hr/tests/fixtures/ai-builder/evaluation-capture/` | Synthetic raw-response and canonical-envelope fixtures shaped from the observed `Process documents` output. |
| `hr/tests/pester/AiBuilderEvidence.Tests.ps1` | Red-first lifecycle, schema, serialization, replay, fail-closed, historical-evidence, and guide tests. |
| `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/ai-builder-model-setup.md` | Attended operator guide for approval, solution/flow setup, security verification, capture, failure, and disablement. |
| `hr/evidence/ai-builder/README.md` | Raw/canonical pair layout, immutable retention, exact operator evidence, and replay commands. |
| `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/evaluation-capture-intent.json` | Approved final names, owners, connector choices, dedicated folder, and explicit mutation authorization. |
| `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/capture/` | Downloaded synthetic sources and immutable raw/canonical pairs for capability and holdout executions. |
| `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/capture-capability.json` | Calculated `AEC-G001` through `AEC-G007` result, separate from historical blocked evidence. |
| `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/prediction-capture-fixed.json` | Adapter-produced fixed prediction capture. |
| `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/holdout-consumption.json` | Exactly-once execution and consumption state for fixed and later general holdouts. |
| `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/security-verification.json` | Observed owners, state, secure settings, connectors, folder boundary, and retention controls. |
| `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/run-manifest.json` | Existing deployment context and append-only lifecycle history. |
| `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/model-inventory.json` | Existing per-model lifecycle mirror. |
| `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/bom-0001-peopledoc-master-data-ai-builder-fields.md` | Field stages and evidence links. |
| `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/bom-0002-ai-builder-test-inputs-and-outcomes.md` | Run inputs, capability, metrics, findings, publication, and solution status. |
| `hr/src/solutions/caldovahrfrontier/` | Synchronized business solution source after an approved model is added; never contains the evaluation flow. |

The production adapter has this exact interface:

```powershell
ConvertFrom-HrAiBuilderEvaluationCapture `
    -CaptureDirectory <string> `
    -RunManifestPath <string> `
    -FieldContractPath <string> `
    -ModelSchemaRecordPath <string> `
    -ModelName <PersonalMasterDataFixed|PersonalMasterDataGeneral> `
    -ModelVersion <string> `
    -Operator <string> `
    -OutputPath <string>
```

It returns the deserialized prediction-capture object and writes the same object atomically to `OutputPath`. `Test-HrAiBuilderCapturePair` accepts `-SourcePdfPath`, `-RawResponsePath`, `-CanonicalEnvelopePath`, `-RunManifestPath`, `-FieldContractPath`, `-ModelName`, and `-ModelVersion`, and returns `{ status, failed_gates[], source_sha256, raw_response_sha256, canonical_envelope_sha256, replay_sha256 }`.

The compatibility adapter called by `Import-AiBuilderQuickTestResults.ps1` preserves the existing exact script signature:

```powershell
param(
    [Parameter(Mandatory)][string]$RawExportDirectory,
    [Parameter(Mandatory)][string]$ModelName,
    [Parameter(Mandatory)][string]$ModelVersion,
    [Parameter(Mandatory)][string]$RunId,
    [Parameter(Mandatory)][string]$Operator,
    [Parameter(Mandatory)][string]$OutputPath
)
```

---

### Task 1: Extend lifecycle and capture contracts

**Files:**
- Create: `hr/src/ai-builder/contracts/evaluation-capture-pair.schema.json`
- Modify: `hr/src/ai-builder/contracts/prediction-capture.schema.json`
- Modify: `hr/src/scripts/modules/Caldova.HrFrontier.AiBuilder/Public/Set-HrAiBuilderModelRecord.ps1`
- Modify: `hr/src/scripts/modules/Caldova.HrFrontier.AiBuilder/Private/Convert-HrAiBuilderPortableLocator.ps1`
- Modify: `hr/tests/pester/AiBuilderEvidence.Tests.ps1`

**Interfaces:**
- Produces lifecycle order `not_created -> created -> schema_defined -> tagged -> trained -> evaluation_published -> capture_validated -> evaluated -> approved_for_solution -> added_to_solution`.
- Produces one narrow resume path: historical fixed `blocked` may append `evaluation_published` only when version `1.0`, the history immediately includes `trained` then `blocked`, and `-ResumeBlockedEvaluation -ResumeEvidencePath <path>` verifies the preserved blocked file.
- Produces capture-pair schema version `1.0` and prediction-capture mechanism `Power Automate Process documents`.

- [ ] **Step 1: Add red lifecycle tests**

Add focused tests that assert:

```powershell
$recordArguments = @{
    RunManifestPath = $manifestPath
    ModelInventoryPath = $inventoryPath
    ModelName = 'PersonalMasterDataFixed'
    ModelId = '74b09a72-d1f1-4598-bc4d-3746d5c97acc'
    ModelVersion = '1.0'
}
Set-HrAiBuilderModelRecord @recordArguments -LifecycleStage 'trained'
Set-HrAiBuilderModelRecord @recordArguments -LifecycleStage 'blocked'

Set-HrAiBuilderModelRecord @recordArguments `
    -LifecycleStage 'evaluation_published' `
    -ResumeBlockedEvaluation `
    -ResumeEvidencePath $blockedCapabilityPath

$history = @(
    (Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json).models[0].lifecycle_history
)
@($history.stage) | Should -Be @(
    'not_created', 'created', 'schema_defined', 'tagged', 'trained',
    'blocked', 'evaluation_published'
)
(Get-Content -LiteralPath $blockedCapabilityPath -Raw) |
    Should -BeExactly $originalBlockedCapabilityBytes
```

Add separate tests rejecting: `blocked -> capture_validated`; resume without the evidence path; resume for version `2.0`; resume for the general model; changed blocked bytes; skipped `evaluation_published -> evaluated`; `evaluated -> added_to_solution`; and every regression. Assert normal forward transitions through all new stages.

- [ ] **Step 2: Run lifecycle tests and verify red**

Run:

```powershell
powershell.exe -NoProfile -Command "& {
    Import-Module 'C:\Users\anrizzi\OneDrive - Microsoft\Documents\PowerShell\Modules\Pester\5.7.1\Pester.psd1' -Force
    Invoke-Pester -Path 'hr/tests/pester/AiBuilderEvidence.Tests.ps1' -FullNameFilter '*lifecycle*' -Output Detailed
}"
```

Expected: FAIL because `evaluation_published`, `capture_validated`, `approved_for_solution`, and resume parameters are unsupported.

- [ ] **Step 3: Implement the append-only lifecycle**

Extend `Set-HrAiBuilderModelRecord` with:

```powershell
[Parameter()]
[switch]$ResumeBlockedEvaluation,

[Parameter()]
[string]$ResumeEvidencePath
```

Use the exact lifecycle array above. Permit the resume exception only for `PersonalMasterDataFixed` version `1.0`; require the last two history stages before the append to be `trained`, `blocked`; parse the preserved record and require `status = blocked`, `run_id` equal to the manifest, and the existing non-empty `blocked_reason`. Hash it before and after the operation and reject a mismatch. Never remove or replace a history event.

- [ ] **Step 4: Add red schema tests**

Create tests that load both schemas and assert:

- canonical top-level keys are exactly `schema_version`, `run_id`, `corpus_revision`, `filename`, `claimed_sha256`, `model_name`, `model_version`, `captured_at_utc`, and `fields`;
- fields occur in `field-contract.json` order and contain exactly `value`, `confidence`;
- source/raw/canonical artifact records each require a lowercase SHA-256;
- prediction capture requires `capture_mechanism = Power Automate Process documents`, `adapter_contract = replayable-v2`, and `raw_export_format = ai-builder-process-documents-v1`;
- Quick Test constants no longer validate production captures.

- [ ] **Step 5: Run schema tests and verify red**

Run the focused contract `Describe` with the command from Step 2.

Expected: FAIL because `evaluation-capture-pair.schema.json` does not exist and the prediction schema still requires Quick Test.

- [ ] **Step 6: Create the closed capture-pair schema and update prediction schema**

Define one execution record with:

```json
{
  "schema_version": "1.0",
  "run_id": "cap-20260929100000000Z-7f3a9c2d",
  "corpus_revision": "c0310c527f010cc9a24d7a78dae7db1e5ad136116b14306413162fb4223926db",
  "filename": "a01-CAND-2026-0411-brunner.pdf",
  "claimed_sha256": "9c7ebe8d706b5b6ee98d779bcd83a578f8dff44b9b6bd7d02bff2b64e2ba67bd",
  "model_name": "PersonalMasterDataFixed",
  "model_version": "1.0",
  "captured_at_utc": "2026-09-29T10:00:00.000Z",
  "artifacts": {
    "source_pdf": { "path": "source/a01-CAND-2026-0411-brunner.pdf", "sha256": "9c7ebe8d706b5b6ee98d779bcd83a578f8dff44b9b6bd7d02bff2b64e2ba67bd" },
    "raw_response": { "path": "cap-20260929100000000Z-7f3a9c2d.ai-builder.raw.json", "sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" },
    "canonical_envelope": { "path": "cap-20260929100000000Z-7f3a9c2d.canonical.json", "sha256": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" }
  }
}
```

The schema must reject extra properties, malformed IDs, wrong model/version, uppercase hashes, duplicate artifact paths, and missing fields. Keep field names generated explicitly from the existing contract, not a second invented field list.

- [ ] **Step 7: Run focused and full AI Builder tests**

Run:

```powershell
powershell.exe -NoProfile -Command "& {
    Import-Module 'C:\Users\anrizzi\OneDrive - Microsoft\Documents\PowerShell\Modules\Pester\5.7.1\Pester.psd1' -Force
    Invoke-Pester -Path 'hr/tests/pester/AiBuilderEvidence.Tests.ps1' -Output Detailed
}"
```

Expected: PASS; the historical blocked bytes and ordered history remain unchanged.

- [ ] **Step 8: Commit the lifecycle and schema contract**

```powershell
git add -- hr/src/ai-builder/contracts/evaluation-capture-pair.schema.json `
    hr/src/ai-builder/contracts/prediction-capture.schema.json `
    hr/src/scripts/modules/Caldova.HrFrontier.AiBuilder/Public/Set-HrAiBuilderModelRecord.ps1 `
    hr/src/scripts/modules/Caldova.HrFrontier.AiBuilder/Private/Convert-HrAiBuilderPortableLocator.ps1 `
    hr/tests/pester/AiBuilderEvidence.Tests.ps1
git commit -m "feat: add AI Builder evaluation capture contracts" `
    -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 2: Update the attended guide and evidence contract

**Files:**
- Modify: `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/ai-builder-model-setup.md`
- Modify: `hr/evidence/ai-builder/README.md`
- Modify: `hr/src/scripts/README.md`
- Modify: `hr/tests/pester/AiBuilderEvidence.Tests.ps1`

**Interfaces:**
- Produces the exact attended sequence used by Tasks 3–14.
- Defines required operator evidence without claiming tenant state.

- [ ] **Step 1: Replace the old guide contract tests with red addendum tests**

Assert the guide:

- references the approved addendum and original design;
- states the narrow supersession language from this plan;
- preserves Tasks 1–5 and the historical blocked event;
- forbids draft `2.0`;
- requires selected names before mutation;
- includes `evaluation_published`, `capture_validated`, `evaluated`, `approved_for_solution`, and `added_to_solution` in order;
- requires named-admin-only, disabled-by-default, secure input/output, connector allow-list, synthetic-only storage, and no auto-delete;
- uses a training PDF before holdouts;
- records blocked evidence and disables the flow on every failure;
- requires exactly-once holdouts and consumption rules;
- gates the general model behind fixed success and approval.

Remove tests requiring “No Power Automate flow” and publish-after-evaluation.

- [ ] **Step 2: Run guide tests and verify red**

Expected: FAIL on the no-flow and old publication sequence.

- [ ] **Step 3: Rewrite the operator guide**

Use these sections in order:

1. authority, supersession, and preserved evidence;
2. pre-mutation read-only readiness;
3. final-name and mutation approval;
4. fixed `1.0` evaluation publication;
5. evaluation solution and complete flow creation, explicit binding to published fixed `1.0`, save, and immediate Off state;
6. security application and verification;
7. one training-PDF observation and immutable byte retention without a capability claim;
8. adapter TDD against the observed raw shape;
9. calculated training-PDF capability decision;
10. exactly-once fixed holdout capture and calculated evaluation;
11. solution-approval decision;
12. general model continuation decision;
13. synchronization, BoMs, manifest, and issue 13.

For every attended observation require operator UPN, UTC time, portal location, exact selected value, screenshot filename when visual evidence is needed, and machine-readable path/hash when bytes exist. Label portal steps `ATTENDED TENANT OPERATION — STOP FOR APPROVAL`; do not show them as Pester or automated commands.

- [ ] **Step 4: Update evidence and script documentation**

Document this layout:

```text
capture/
└── <approved-evidence-folder-name>/
    └── <execution-run-id>/
        ├── source/<exact-qualified-filename>.pdf
        ├── <execution-run-id>.ai-builder.raw.json
        ├── <execution-run-id>.canonical.json
        └── capture-pair.json
```

State that final folder name comes from `evaluation-capture-intent.json`, raw and canonical files are immutable, no cleanup is implied, and local output is UTF-8 without BOM. Add the exact adapter/import/evaluator commands from this plan.

- [ ] **Step 5: Validate documentation**

Run:

```powershell
powershell.exe -NoProfile -Command "& {
    Import-Module 'C:\Users\anrizzi\OneDrive - Microsoft\Documents\PowerShell\Modules\Pester\5.7.1\Pester.psd1' -Force
    Invoke-Pester -Path @(
        'hr/tests/pester/AiBuilderEvidence.Tests.ps1',
        '.github/cli/tests/DocumentationMetadata.Tests.ps1',
        '.github/cli/tests/DocumentationLinks.Tests.ps1'
    ) -Output Detailed
}"
git diff --check
```

Expected: PASS and no broken relative links.

- [ ] **Step 6: Commit the attended procedure**

```powershell
git add -- hr/docs/ideas/uc-0001-personal-master-data-completion-agent/ai-builder-model-setup.md `
    hr/evidence/ai-builder/README.md `
    hr/src/scripts/README.md `
    hr/tests/pester/AiBuilderEvidence.Tests.ps1
git commit -m "docs: define attended AI Builder capture procedure" `
    -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 3: Record pre-mutation readiness and obtain explicit approval

**Files:**
- Create: `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/evaluation-capture-intent.json`
- Create: `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/evaluation-capture-readiness.json`
- Modify: `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/bom-0002-ai-builder-test-inputs-and-outcomes.md`

**Interfaces:**
- Produces selected names and an explicit approval record consumed by every tenant task.
- Does not mutate Tenant 2.

- [ ] **Step 1: Verify repository and evidence baseline read-only**

Run:

```powershell
$root = 'C:\Users\anrizzi\Repositories\caldova-hr-frontier.worktrees\issue-13-ai-builder-setup-worktree'
Set-Location $root
$evidenceRoot = Join-Path $root 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001'
$manifest = Get-Content -LiteralPath (Join-Path $evidenceRoot 'run-manifest.json') -Raw | ConvertFrom-Json
$fixed = @($manifest.models | Where-Object display_name -eq 'PersonalMasterDataFixed')[0]
$general = @($manifest.models | Where-Object display_name -eq 'PersonalMasterDataGeneral')[0]
if ($fixed.model_id -ne '74b09a72-d1f1-4598-bc4d-3746d5c97acc' -or
    $fixed.version -ne '1.0' -or
    $fixed.lifecycle_stage -ne 'blocked' -or
    $general.lifecycle_stage -ne 'not_created') {
    throw 'The preserved model baseline does not match the approved addendum.'
}
Get-FileHash -LiteralPath (Join-Path $evidenceRoot 'model-test-capability.json') -Algorithm SHA256
```

Expected: fixed `1.0` is blocked after trained, general is `not_created`, and the blocked record hash is captured without modification.

- [ ] **Step 2: Perform attended read-only tenant checks**

**STOP — attended observation, no mutation.** Connect with:

```powershell
.\hr\src\scripts\Connect-PowerPlatformEnvironment.ps1 `
    -TenantAlias caldova25668747 `
    -Stage Dev
pac org who
pac solution list
```

Record exact observations that fixed `1.0` is trained, draft `2.0` is untrained and untouched, `caldovahrfrontier` remains unmanaged, the named administrator is active, AI Builder and the selected OneDrive/SharePoint connector are permitted, and no existing evaluation solution/flow will collide with candidate names. Do not publish, edit, create, enable, share, or delete anything.

- [ ] **Step 3: Present candidates and record the selected values**

Present these candidates to the user:

| Item | Candidate A | Candidate B |
|---|---|---|
| Evaluation solution display name | `Caldova HR AI Evaluation DEV` | `Caldova AI Builder Capture DEV` |
| Evaluation solution unique name | `calhr_ai_evaluation_dev` | `calhr_ai_builder_capture_dev` |
| Manual flow display name | `Capture AI Builder Evaluation Evidence` | `Run AI Builder Evaluation Capture` |
| Dedicated evidence folder | `AIBuilderEvaluationEvidence` | `AIBuilderCaptureEvidence` |
| Storage connector | Tenant 2 OneDrive for Business | Tenant 2 SharePoint |

The user may select a collision-free candidate or provide another compliant value. Record the selected values, the sole owner/run identity `admin@caldova25668747.onmicrosoft.com`, connection-reference display/unique names, exact storage URL/path, and approval UTC in `evaluation-capture-intent.json`. Do not use candidate text as tenant intent until the user selects it.

- [ ] **Step 4: Require explicit mutation approval**

Display a summary containing the final names, environment ID, owner, connectors, folder, fixed model ID/version, creation actions, publication effect, and no-delete rule. Stop until the user explicitly approves:

```text
Approve creation of the recorded DEV-only evaluation solution, manual flow,
connection references, and synthetic-evidence folder, and evaluation publication
of PersonalMasterDataFixed version 1.0 in Tenant 2 DEV.
```

Record the exact approval statement and timestamp. Absence, ambiguity, or changed names means `status = blocked` and no tenant mutation.

The approval authorizes only this fail-closed linear order: first publish exact fixed `1.0` as `evaluation_published` while leaving `2.0` untouched; then create the approved evaluation solution, connection references, folder, and complete manual flow bound explicitly to the now-published fixed `1.0`, save it, immediately ensure it is Off, and apply and verify security. Only after those steps pass may a separate attended training-PDF capture be requested. Approval does not permit creating or configuring a `Process documents` action before publication.

- [ ] **Step 5: Validate and commit intent evidence**

Run documentation tests and `git diff --check`.

```powershell
git add -- hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/evaluation-capture-intent.json `
    hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/evaluation-capture-readiness.json `
    hr/docs/ideas/uc-0001-personal-master-data-completion-agent/bom-0002-ai-builder-test-inputs-and-outcomes.md
git commit -m "test: approve Tenant 2 evaluation capture intent" `
    -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 4: Publish exact fixed `1.0` for evaluation

**Files:**
- Modify: `run-manifest.json` and `model-inventory.json` in the existing evidence run
- Create: attended publication evidence under the run evidence folder

**Interfaces:**
- Consumes the approved readiness and mutation intent from Task 3.
- Produces lifecycle `evaluation_published` for exact fixed `1.0` while leaving draft `2.0` untouched.
- Creates no solution, connection reference, folder, or flow and makes no capability claim.

- [ ] **Step 1: Stop before publication**

**ATTENDED TENANT OPERATION — STOP FOR APPROVAL.** Reload the approved intent, run `pac org who`, compare the environment ID and administrator, read back fixed model ID/version, confirm `1.0` is trained, and confirm `2.0` is untrained and unchanged. Reconfirm that the recorded approval still applies. Do not create or configure a solution, connection reference, folder, flow, or `Process documents` action at this checkpoint.

- [ ] **Step 2: Publish exactly fixed `1.0`**

Publish `PersonalMasterDataFixed` version `1.0` in AI Builder. Do not open, edit, train, publish, select, or otherwise mutate `2.0`. Capture the operator UPN, UTC time, portal location, exact model ID/version, resulting published status, and screenshot filename.

If publication fails or the exact version cannot be proved, preserve the observation, append `blocked`, update the BoMs and issue 13, and stop. Do not create any evaluation resources.

- [ ] **Step 3: Append only `evaluation_published`**

After exact publication is visibly verified, append:

```powershell
Set-HrAiBuilderModelRecord `
    -RunManifestPath $runManifestPath `
    -ModelInventoryPath $inventoryPath `
    -ModelName 'PersonalMasterDataFixed' `
    -ModelId '74b09a72-d1f1-4598-bc4d-3746d5c97acc' `
    -ModelVersion '1.0' `
    -LifecycleStage 'evaluation_published' `
    -ResumeBlockedEvaluation `
    -ResumeEvidencePath (Join-Path $evidenceRoot 'model-test-capability.json')
```

Expected: the historical `blocked` event remains unchanged, `evaluation_published` is appended for fixed `1.0`, and no lifecycle or tenant evidence mentions a `2.0` mutation.

- [ ] **Step 4: Commit publication evidence**

Validate the manifest and inventory, preserve the publication screenshot and observation, and commit with message `test: publish fixed model for evaluation`. This commit contains no flow-definition or capture evidence.

---

### Task 5: Create and secure the complete DEV-only evaluation flow — complete

**Files:**
- Create: `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/security-verification.json`
- Create: `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/evaluation-flow-definition.md`
- Create: attended screenshots under the run evidence folder

**Interfaces:**
- Requires Task 4 evidence proving exact fixed `1.0` is published as `evaluation_published`.
- Consumes only approved values from `evaluation-capture-intent.json`.
- Produces the approved unmanaged solution, connection references, synthetic-evidence folder, and complete manual flow bound explicitly to published fixed `1.0`; the saved flow is immediately Off and security is applied and verified.
- Tenant actions are attended and are not automated tests.

- [x] **Step 1: Stop and prove the publication dependency**

**ATTENDED TENANT OPERATION — STOP FOR APPROVAL.** Reload intent, run `pac org who`, compare environment ID and administrator, and show the exact mutations. Require the manifest and portal to agree that model ID `74b09a72-d1f1-4598-bc4d-3746d5c97acc` version `1.0` is published and recorded as `evaluation_published`, with `2.0` untouched. Continue only after the operator confirms the recorded creation approval still applies. Any missing, failed, unknown, or mismatched publication evidence stops creation.

- [x] **Step 2: Create the unmanaged evaluation solution**

In Power Apps Tenant 2 DEV, create the selected display/unique names from intent. Use the existing approved publisher only if intent records it after read-back; otherwise stop for a separate publisher decision. Verify `Managed = No`. Do not add anything to `caldovahrfrontier`.

- [x] **Step 3: Create approved connection references and folder**

Inside the evaluation solution, create only:

1. AI Builder connection reference; and
2. the selected Tenant 2 OneDrive for Business or SharePoint connection reference.

Create the selected dedicated synthetic-evidence folder. Restrict it to the named administrator. Do not upload a training PDF or holdout.

- [x] **Step 4: Create and complete the manual file-bearing flow**

Use the selected flow name. Configure manual inputs:

```text
source_pdf          File, required
expected_filename   Text, required
expected_sha256     Text, required, lower-case 64 hex
execution_run_id    Text, required, ^cap-[0-9]{17}Z-[a-f0-9]{8}$
corpus_revision     Text, required, exact manifest revision
capture_stage       Choice: training-proof | fixed-holdout | general-holdout
```

Only now, after Task 4 publication, add `Process documents` and select exact published `PersonalMasterDataFixed` version `1.0`. Never bind to “latest” or any selector that can resolve to `2.0`. Add deterministic steps to validate required inputs; reject a non-allow-listed filename before AI Builder; read the source through the dedicated connector; execute `Process documents`; write the unmodified action body; create the ordered 17-field envelope; write the canonical envelope; and terminate success/failure. Filenames are exactly `<execution_run_id>.ai-builder.raw.json` and `<execution_run_id>.canonical.json`; a create-file collision fails and never overwrites.

- [x] **Step 5: Configure canonical JSON output**

The canonical object property order is:

```text
schema_version, run_id, corpus_revision, filename, claimed_sha256,
model_name, model_version, captured_at_utc, fields
```

The `fields` order is the existing contract order. Each field has `value` then `confidence`. Use explicit nulls. The flow must emit compact JSON as UTF-8 without BOM and one terminal LF. Do not normalize or edit AI Builder values.

- [x] **Step 6: Save and immediately ensure the flow is Off**

Save the complete flow, then immediately switch it Off and visibly verify the Off state before any test or capture. Do not invoke it during creation. If save, exact fixed `1.0` binding, or Off-state verification fails or is unknown, keep or force the flow Off where possible, record `blocked`, preserve available evidence, and stop.

- [x] **Step 7: Apply and verify security controls**

Apply, then verify and record:

- sole owner and run-only user are the named administrator;
- flow state is Off;
- secure inputs and secure outputs are enabled on the manual trigger and AI Builder action;
- exact `Process documents` binding is published fixed `1.0`, not “latest” and not `2.0`;
- only the two approved connector families exist;
- no child flow, HTTP, custom connector, email, Teams, Workday, agent, Dataverse table, schedule, recurrence, or event trigger exists;
- folder contains synthetic evidence only;
- no auto-delete, cleanup, or retention action exists; and
- failure branches terminate the attended attempt, preserve available evidence, and require the operator to ensure the flow is Off.

- [x] **Step 8: Record exact flow definition and security evidence**

`evaluation-flow-definition.md` records action names, expressions, the attended binding to published fixed `1.0`, connection references, output naming, field mapping, saved state, and screenshots. `security-verification.json` records observed values and `passed|failed|unknown`. Any failed or unknown value keeps the flow Off, appends or records `blocked` as applicable, preserves evidence, and stops before a training PDF.

- [x] **Step 9: Record setup evidence**

```powershell
git add -- hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/security-verification.json `
    hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/evaluation-flow-definition.md `
    hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/*.png
git commit -m "test: record DEV evaluation flow controls" `
    -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

**Completed Task 5 ruling (attempt 3, 2026-09-30):** Preserve attempts 1 and 2 as blocked history. Action-first discovery proved that `Process documents` operation `aibuilderpredict_formsprocessing` creates and uses a dedicated `shared_commondataserviceforapps` dependency. The user approved narrowing the AI Builder boundary to that action-only Dataverse reference, changing only its display name to `Caldova HR AI Evaluation DEV Dataverse (AI Builder)` and retaining generated unique name `calhr_sharedcommondataserviceforapps_68a73`. This does not authorize Dataverse table actions. The only other connection reference is the approved SharePoint reference. The exported definition and portal checks passed; the flow is Off with zero runs and Task 5 is complete. The historical blockers are not reclassified.

**Trusted-source refinement:** Within `Capture evidence`, `Get source PDF` uses the approved SharePoint reference, operation `GetFileContentByPath`, and path `/Shared Documents/AIBuilderEvaluationEvidence/<expected_filename>`. `Process documents` runs after that action and consumes exactly `@body('Get_source_PDF')`, not trigger-uploaded bytes. This refinement did not enable or run the flow and exposed no PDF.

Task 6 is deliberately still unchecked. No Task 5 approval or completion authorizes its attended capture. A separate attended approval is required before enabling or invoking the flow, and no training PDF has yet been exposed.

---

### Task 6: Capture exactly one attended training PDF

**Files:**
- Create: capture evidence under the approved folder name
- Modify: run evidence, BoMs, and issue #13 only as required by an operational result

**Interfaces:**
- Requires Task 5 setup and security evidence to pass with the complete flow saved, explicitly bound to published fixed `1.0`, and Off.
- Produces exactly one attended training-PDF observation with immutable source, raw-response, canonical-envelope, and pair-metadata bytes for Task 7.
- Makes no capability claim and does not append `capture_validated`; Task 8 owns the calculated decision.

- [ ] **Step 1: Stop before the separate capture**

**ATTENDED TENANT OPERATION — STOP FOR APPROVAL.** Present exact fixed model ID/version, `evaluation_published` evidence, passed security controls, flow Off state, and the fact that this is one irreversible attended observation rather than flow creation or capability proof. Continue only with explicit approval for one training-PDF capture.

- [ ] **Step 2: Select one allow-listed training PDF**

Read one training record from the manifest, display its filename/hash, and copy only that qualified synthetic PDF to the dedicated folder. Record its exact manifest record. Do not select a held-out assignment.

- [ ] **Step 3: Open the single attended training-capture window**

Enable the flow, verify only the named administrator can run it, manually invoke once with the exact training filename/hash/corpus revision and a collision-resistant run ID generated by:

```powershell
$executionRunId = 'cap-{0}Z-{1}' -f `
    ([datetime]::UtcNow.ToString('yyyyMMddHHmmssfff')), `
    ([guid]::NewGuid().ToString('N').Substring(0, 8))
```

Wait for terminal status and disable the flow immediately. This is exactly one training-PDF capture attempt. Do not retry it and do not use a holdout.

- [ ] **Step 4: Handle an operational capture failure**

If trigger validation, source read, AI Builder, either write, download, or immediate disablement fails: ensure the flow is Off where possible; retain all available bytes; record the exact operational failure without asserting capability status; append lifecycle `blocked`; update BoMs and issue 13; commit evidence; and stop. Do not retry the training PDF and do not use a holdout.

- [ ] **Step 5: Preserve the exact observation and pair metadata**

Download the source PDF, unmodified raw action-body JSON, and canonical envelope JSON without opening or resaving them. Record operator UPN, UTC time, remote path, local path, size, and lowercase SHA-256. Create `capture-pair.json` only from the approved manifest identity plus those observed artifact locators, sizes, and hashes; do not interpret values, run replay, or add a pass flag. Make the source, raw, canonical, and pair-metadata files immutable evidence. Never use clipboard transcription.

- [ ] **Step 6: Close without a capability claim**

Confirm the flow is Off, commit the immutable observation, and record only that the source/raw/canonical/pair bytes were captured. Do not run replay, set `capture-capability.json`, append `capture_validated`, or characterize the model or capture path as capable. Proceed to Task 7.

---

### Task 7: Implement deterministic local capture replay against the observed raw shape

**Files:**
- Create: `hr/src/scripts/modules/Caldova.HrFrontier.AiBuilder/Private/ConvertTo-HrAiBuilderCanonicalJson.ps1`
- Create: `hr/src/scripts/modules/Caldova.HrFrontier.AiBuilder/Public/Test-HrAiBuilderCapturePair.ps1`
- Create: `hr/src/scripts/modules/Caldova.HrFrontier.AiBuilder/Public/ConvertFrom-HrAiBuilderEvaluationCapture.ps1`
- Create: `hr/src/scripts/adapters/ConvertFrom-HrAiBuilderEvaluationCapture.ps1`
- Create: `hr/tests/fixtures/ai-builder/evaluation-capture/process-documents-response.json`
- Create: `hr/tests/fixtures/ai-builder/evaluation-capture/canonical-envelope.json`
- Modify: `hr/src/scripts/modules/Caldova.HrFrontier.AiBuilder/Caldova.HrFrontier.AiBuilder.psd1`
- Modify: `hr/src/scripts/Import-AiBuilderQuickTestResults.ps1`
- Modify: `hr/src/scripts/modules/Caldova.HrFrontier.AiBuilder/Public/Test-HrAiBuilderStrictGates.ps1`
- Modify: `hr/tests/pester/AiBuilderEvidence.Tests.ps1`

**Interfaces:**
- Consumes the one immutable training-PDF observation produced by Task 6.
- `ConvertTo-HrAiBuilderCanonicalJson -InputObject <object>` returns UTF-8 bytes without BOM, compact JSON, fixed property order, escaped JSON strings, one terminal LF.
- `Test-HrAiBuilderCapturePair` returns calculated gates and hashes; it never accepts operator pass booleans.
- `ConvertFrom-HrAiBuilderEvaluationCapture` writes the existing prediction-capture shape with flow metadata and one document per validated capture directory.

- [ ] **Step 1: Preserve the observed raw format as a synthetic fixture**

Sanitize only platform IDs and synthetic values from the Task 6 `Process documents` response, preserving the exact JSON shape. Do not invent an AI Builder action-body abstraction. The fixture remains synthetic and retains every node used to locate value and confidence.

- [ ] **Step 2: Write red projection and confidence tests**

Add tests that invoke:

```powershell
$result = ConvertFrom-HrAiBuilderEvaluationCapture `
    -CaptureDirectory $fixtureCaptureDirectory `
    -RunManifestPath $fixtureManifestPath `
    -FieldContractPath $script:ContractPath `
    -ModelSchemaRecordPath $fixtureSchemaPath `
    -ModelName 'PersonalMasterDataFixed' `
    -ModelVersion '1.0' `
    -Operator 'operator@example.invalid' `
    -OutputPath (Join-Path $TestDrive 'prediction-capture.json')
```

Assert exact source SHA-256, run ID, corpus revision, case-sensitive filename, fixed model/version, all 17 ordered keys, string/null values, and numeric/null confidence. Add one test each for integer, double, `0`, `1`, null with null value, string confidence, `-0.01`, `1.01`, value with null confidence, null value with numeric confidence, missing field, additional field, and duplicate source filename.

- [ ] **Step 3: Run projection tests and verify red**

Run the focused adapter `Describe`.

Expected: FAIL because the three new functions do not exist.

- [ ] **Step 4: Implement canonical serialization**

Build ordered objects with `[ordered]` and serialize using:

```powershell
$json = $InputObject | ConvertTo-Json -Depth 30 -Compress
$normalized = $json.Replace("`r`n", "`n").Replace("`r", "`n") + "`n"
return [Text.UTF8Encoding]::new($false).GetBytes($normalized)
```

Reject dictionary keys not supplied in the contract order. Write bytes with `[IO.File]::WriteAllBytes`; never use Windows PowerShell 5.1 `Set-Content -Encoding UTF8` for canonical output because it adds a BOM.

- [ ] **Step 5: Add red byte-determinism tests**

Serialize the same ordered fixture twice and assert `Should -BeExactly` on lowercase SHA-256. Assert no `EF BB BF` prefix, exactly one terminal `0A`, no `0D`, stable property order, Unicode preservation, escaped quotes/backslashes, and byte change when a value, null, confidence, or property order changes.

- [ ] **Step 6: Run determinism tests red, implement minimum behavior, and rerun green**

Expected red: serializer absent. Expected green: both byte arrays and hashes are identical.

- [ ] **Step 7: Implement exact pair correlation and replay**

For each capture directory:

1. require exactly one `*.ai-builder.raw.json` and matching `*.canonical.json`;
2. derive the shared `run_id` from the complete basename and reject collisions;
3. resolve paths inside the approved capture root;
4. independently hash the retained source PDF;
5. compare filename, hash, run ID, corpus revision, model name, and model version ordinally across manifest, pair index, canonical envelope, and invocation;
6. parse fields from the raw response using only the observed fixture shape;
7. project exactly the 17 contract fields in contract order;
8. validate value/confidence pairs;
9. serialize the replayed canonical envelope;
10. require byte equality with the retained canonical file;
11. record source, raw, canonical, adapter-script, and replay hashes.

Any unknown raw shape or mismatch returns `status = blocked`, names the failed gate, writes no success capture, and preserves all input bytes.

- [ ] **Step 8: Add red fail-closed and replay tests**

Mutate one fixture property at a time and assert these gates:

| Mutation | Failed gate |
|---|---|
| source bytes | `source_sha256` |
| case-only filename change | `exact_correlation` |
| raw `run_id` mismatch when available | `exact_correlation` |
| envelope corpus revision change | `exact_correlation` |
| model `2.0` | `exact_model_version` |
| raw response changed after envelope creation | `adapter_replay` |
| canonical BOM | `canonical_serialization` |
| missing/additional field | `exact_field_contract` |
| invalid confidence | `prediction_capture_schema` |
| existing output path | `immutable_output` |
| path escaping capture root | `evidence_boundary` |

- [ ] **Step 9: Update importer and strict gates**

Retain the script filename for compatibility, but replace its Quick Test-only production path with:

```powershell
.\hr\src\scripts\Import-AiBuilderQuickTestResults.ps1 `
    -RunManifestPath $runManifestPath `
    -ModelSchemaRecordPath $modelSchemaPath `
    -RawExportDirectory $captureDirectory `
    -AdapterScriptPath '.\hr\src\scripts\adapters\ConvertFrom-HrAiBuilderEvaluationCapture.ps1' `
    -TargetModelName 'PersonalMasterDataFixed' `
    -OutputPath $predictionCapturePath
```

The adapter wrapper uses the exact existing six-parameter entry contract when called by the importer. It verifies `RunId` against the manifest discovered in the capture directory, resolves the repository field contract and sibling model-schema record, then calls `ConvertFrom-HrAiBuilderEvaluationCapture` with its full public-function signature. Set `capture_mechanism`, `adapter_contract`, and `raw_export_format` to the new constants. Extend strict gates with `capture_pair_provenance`, `exact_correlation`, `canonical_serialization`, `exact_model_version`, and `adapter_replay`.

- [ ] **Step 10: Run all AI Builder tests**

Run the full command from Task 1 Step 7.

Expected: PASS; four synthetic fixed documents still produce 68 records and eight synthetic general documents produce 136.

- [ ] **Step 11: Commit the replay adapter**

```powershell
git add -- hr/src/scripts/modules/Caldova.HrFrontier.AiBuilder `
    hr/src/scripts/Import-AiBuilderQuickTestResults.ps1 `
    hr/tests/fixtures/ai-builder/evaluation-capture `
    hr/tests/pester/AiBuilderEvidence.Tests.ps1
git commit -m "feat: replay AI Builder flow capture evidence" `
    -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 8: Calculate the fixed capture-capability decision

**Files:**
- Create: `capture-capability.json`
- Modify: `run-manifest.json`, `model-inventory.json`, both BoMs, and issue #13 evidence as required by the result

**Interfaces:**
- Consumes Task 6 immutable bytes and the Task 7 adapter.
- Produces the calculated `AEC-G001` through `AEC-G007` decision.
- Appends `capture_validated` only when every calculated gate passes.

- [ ] **Step 1: Calculate `AEC-G001` through `AEC-G007`**

Run `Test-HrAiBuilderCapturePair` and require all seven gates. Run the adapter twice to separate output paths and compare SHA-256:

```powershell
$first = Join-Path $env:TEMP 'fixed-capability-replay-1.json'
$second = Join-Path $env:TEMP 'fixed-capability-replay-2.json'
ConvertFrom-HrAiBuilderEvaluationCapture @adapterArguments -OutputPath $first
ConvertFrom-HrAiBuilderEvaluationCapture @adapterArguments -OutputPath $second
$firstHash = (Get-FileHash $first -Algorithm SHA256).Hash
$secondHash = (Get-FileHash $second -Algorithm SHA256).Hash
if ($firstHash -cne $secondHash) {
    throw "Canonical replay is not byte-deterministic: $firstHash != $secondHash"
}
Remove-Item -LiteralPath $first, $second -Force
```

Expected: exact filename, source hash, raw bytes, 17 fields, confidence contract, deterministic naming/serialization, and replay all pass.

- [ ] **Step 2: Record failure or append `capture_validated`**

Write `capture-capability.json` with every calculated gate and supporting hash. If any gate fails or is unknown, keep the flow Off, preserve all bytes, append `blocked`, update BoMs and issue 13, commit evidence, and stop before any holdout. Only after calculated pass:

```powershell
Set-HrAiBuilderModelRecord @recordArguments -LifecycleStage 'capture_validated'
```

Keep the flow Off. Commit capability evidence with message `test: prove AI Builder capture capability`.

---

### Task 9: Execute the fixed holdout exactly once and calculate evaluation

**Files:**
- Create: `holdout-consumption.json`
- Create: four fixed capture directories and pairs
- Create: `prediction-capture-fixed.json`
- Create/Modify: `validation-results-fixed.csv`, `validation-results.json`, `evaluation-metrics.json`, `evaluation-summary.md`
- Modify: `run-manifest.json`, `model-inventory.json`, and both BoMs

**Interfaces:**
- Consumes passed capability and still-unseen fixed holdouts.
- Produces exactly 4 documents and 68 validation records.

- [ ] **Step 1: Initialize holdout-consumption evidence**

Create one row per fixed holdout with exact filename/hash and `state = unseen`. Reject initialization if capability is not passed, lifecycle is not `capture_validated`, or any capture pair already references a fixed holdout.

- [ ] **Step 2: Stop before irreversible holdout exposure**

**ATTENDED TENANT OPERATION — STOP FOR APPROVAL.** Display all four fixed filenames/hashes, fixed `1.0`, flow controls, and exactly-once consequence. Continue only with explicit approval for these four records.

- [ ] **Step 3: Process one fixed holdout at a time**

For each manifest held-out document:

1. require consumption state `unseen`;
2. copy exact qualified source to the dedicated folder;
3. generate a new execution run ID;
4. enable flow;
5. manually invoke once;
6. wait for terminal status;
7. disable flow immediately;
8. download source/raw/canonical/pair bytes;
9. hash and locally validate the pair;
10. set state to `captured` only after complete pair validation.

Never batch retries or rerun a successful filename. On failure set that execution `blocked`, disable flow, preserve evidence, leave remaining documents unseen, and stop before another holdout.

- [ ] **Step 4: Import all four pairs**

Run:

```powershell
.\hr\src\scripts\Import-AiBuilderQuickTestResults.ps1 `
    -RunManifestPath "$evidenceRoot\run-manifest.json" `
    -ModelSchemaRecordPath "$evidenceRoot\model-schema-fixed.json" `
    -RawExportDirectory "$evidenceRoot\capture\$approvedFolderName\fixed-holdout" `
    -AdapterScriptPath '.\hr\src\scripts\adapters\ConvertFrom-HrAiBuilderEvaluationCapture.ps1' `
    -TargetModelName 'PersonalMasterDataFixed' `
    -OutputPath "$evidenceRoot\prediction-capture-fixed.json"
```

Expected: 4 exact documents, 68 field captures, source/raw/canonical/adapter hashes, no manual values.

- [ ] **Step 5: Run strict evaluation**

```powershell
.\hr\src\scripts\Measure-AiBuilderEvaluation.ps1 `
    -RunManifestPath "$evidenceRoot\run-manifest.json" `
    -CorpusQualityPath "$evidenceRoot\corpus-quality.json" `
    -FieldContractPath '.\hr\src\ai-builder\contracts\field-contract.json' `
    -ModelSchemaRecordPath "$evidenceRoot\model-schema-fixed.json" `
    -PredictionCapturePath "$evidenceRoot\prediction-capture-fixed.json" `
    -GroundTruthPath '.\hr\docs\ideas\uc-0001-personal-master-data-completion-agent\gf-aib-fixed-template\ground-truth.json' `
    -EvidenceDirectory $evidenceRoot
```

Expected: 68 records; complete attribution; zero false values; every mismatch retained; all capture gates calculated.

- [ ] **Step 6: Apply holdout-consumption rules**

Set all four rows to `evaluated` after metrics are written. If any result is used to alter tags/model/training, atomically set all four to `consumed_by_model_change`, append `blocked`, require a new corpus revision and run ID with unseen documents, and stop. Never return them to `unseen`.

- [ ] **Step 7: Append `evaluated` only on calculated pass**

If strict disposition is blocked, append `blocked`, keep flow Off, update evidence/BoMs/issue, commit, and stop. If disposition is evaluated:

```powershell
Set-HrAiBuilderModelRecord @recordArguments -LifecycleStage 'evaluated'
```

- [ ] **Step 8: Run regressions and commit**

Run AI Builder, documentation, and solution lifecycle tests; expect zero failures.

```powershell
git add -- hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001 `
    hr/docs/ideas/uc-0001-personal-master-data-completion-agent/bom-0001-peopledoc-master-data-ai-builder-fields.md `
    hr/docs/ideas/uc-0001-personal-master-data-completion-agent/bom-0002-ai-builder-test-inputs-and-outcomes.md
git commit -m "test: evaluate fixed model from replayed capture" `
    -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 10: Decide approval for solution and add fixed `1.0`

**Files:**
- Modify: existing fixed evidence, BoMs, manifest, and inventory
- External: issue #13

**Interfaces:**
- Produces `approved_for_solution` only from calculated gates and an attended acknowledgement.
- Produces `added_to_solution` only after visible component confirmation.

- [ ] **Step 1: Calculate approval eligibility**

Require exact fixed model/version, capability gates pass, strict gates pass, zero false values, 68 results, complete hashes/replay, flow Off, security verification pass, and no consumed holdout. Do not accept an operator-supplied pass flag.

- [ ] **Step 2: Stop at the decision checkpoint**

Present metrics, quality findings, failed gates, publication meaning, and statement that automated-write approval is not granted. **STOP** until the user approves adding exact fixed `1.0` to `caldovahrfrontier`.

- [ ] **Step 3: Append approval and perform attended add**

Append `approved_for_solution`, then in Tenant 2 DEV add only `PersonalMasterDataFixed` version `1.0` to unmanaged `caldovahrfrontier`. Do not add the flow, evaluation solution, connection references, or evidence folder.

- [ ] **Step 4: Verify and append solution stage**

Visibly verify the model component in `caldovahrfrontier`, record evidence, then append `added_to_solution`. On add failure, append `blocked`; do not claim completion.

- [ ] **Step 5: Update issue 13 and commit**

Post an interim comment with exact version, calculated gates, metrics, quality findings, flow Off state, evidence paths, and no automated-write approval. Commit with `feat: approve fixed AI Builder model for solution`.

---

### Task 11: Continue the general model only under the proven pattern

**Files:**
- Create: general schema/capture/evaluation evidence in the existing run
- Modify: shared metrics, summary, manifest, inventory, and BoMs

**Interfaces:**
- Consumes successful fixed `added_to_solution` and the proven flow/adapter pattern.
- Produces 8 general holdouts and 136 records without using fixed evidence as a substitute.

- [ ] **Step 1: Stop for separate general-model approval**

Present fixed completion evidence and proposed general work. Continue only after explicit approval to create/train/publish/evaluate `PersonalMasterDataGeneral`. Without approval, leave it `not_created`.

- [ ] **Step 2: Create, define, tag, and train attended**

Follow the unchanged original general-model safety rules: exact 17 fields, 16 training documents only, 8 holdouts untouched, observed schema evidence, and sequential lifecycle through `trained`. Tenant actions remain attended.

- [ ] **Step 3: Publish general only for evaluation**

Publish the exact trained general version, visibly verify it, and record `evaluation_published`. Only then bind the same disabled-by-default flow to that exact published version and reconfirm all security controls. Never select or configure an unpublished model in `Process documents`. Do not infer the fixed result as general capability.

- [ ] **Step 4: Prove model-specific capture with a general training PDF**

Use one general training PDF, a new execution ID, and the same `AEC-G001`–`AEC-G007` calculations. Disable and block on failure before any general holdout. Append `capture_validated` only on pass.

- [ ] **Step 5: Execute eight general holdouts exactly once**

Use independent consumption rows and one attended execution per holdout. Download and replay all pairs. Expected adapter output: 8 documents and 136 fields.

- [ ] **Step 6: Evaluate and decide solution approval**

Run the same evaluator and strict gates with general ground truth. Append `evaluated` only on calculated pass. Stop for explicit approval before `approved_for_solution`; add only the approved general model to `caldovahrfrontier`; append `added_to_solution` only after visible confirmation.

- [ ] **Step 7: Update BoMs and commit**

Keep fixed/general metrics and findings separate. Commit with `test: evaluate general model under proven capture pattern`.

---

### Task 12: Synchronize solution source, inventory, manifest, and issue 13

**Files:**
- Modify: `hr/src/solutions/caldovahrfrontier/`
- Modify: run evidence and both BoMs
- Create: `acceptance-criteria.json`
- External: issue #13

**Interfaces:**
- Produces synchronized business solution only; evaluation solution remains tenant-local and absent.

- [ ] **Step 1: Synchronize `caldovahrfrontier`**

```powershell
.\hr\src\scripts\Sync-HrSolutionSource.ps1 `
    -TenantAlias caldova25668747 `
    -SolutionUniqueName caldovahrfrontier
```

Expected: temporary ZIP removed; unpacked source updated.

- [ ] **Step 2: Verify inclusion and exclusion**

Use PowerShell:

```powershell
$solutionFiles = Get-ChildItem -LiteralPath '.\hr\src\solutions\caldovahrfrontier' -File -Recurse
$solutionText = ($solutionFiles | ForEach-Object {
    Get-Content -LiteralPath $_.FullName -Raw -ErrorAction SilentlyContinue
}) -join "`n"
$solutionText | Select-String -Pattern 'PersonalMasterDataFixed'
$solutionText | Select-String -Pattern 'PersonalMasterDataGeneral'
if ($solutionText -match [regex]::Escape($intent.flow.display_name) -or
    $solutionText -match [regex]::Escape($intent.evaluation_solution.unique_name)) {
    throw 'Evaluation-only components leaked into caldovahrfrontier.'
}
```

Expected: every approved model occurs; evaluation flow/solution does not.

- [ ] **Step 3: Update inventory, BoMs, and acceptance**

Record lifecycle, versions, capability/strict gates, metrics, findings, publication semantics, solution membership, flow Off state, and untouched `2.0`. Build `acceptance-criteria.json` from the addendum gates and preserved original acceptance rules. Never erase the historical blocker.

- [ ] **Step 4: Update issue #13**

```powershell
gh issue comment 13 --repo urruegg/caldova-hr-frontier --body-file `
    "$evidenceRoot\evaluation-summary.md"
```

Close only when both approved workstreams and all acceptance criteria are complete. Otherwise leave open with exact blockers.

- [ ] **Step 5: Finalize the run manifest last**

Run `Complete-HrAiBuilderRunManifest` only after every hashed file is final. Update it first so `approved_for_solution` is required and the historical blocker is allowed as preserved history rather than current disposition. After finalization, any retry uses a new run ID.

- [ ] **Step 6: Commit synchronization**

Commit with `feat: synchronize evaluated AI Builder models`; use `test: record blocked AI Builder evaluation` when final status is blocked or partial.

---

### Task 13: Full verification and scoped code review

**Files:**
- Review only the files changed by this plan.

**Interfaces:**
- Produces reproducible verification evidence and review findings before branch finishing.

- [ ] **Step 1: Run the complete Windows PowerShell test suite**

```powershell
powershell.exe -NoProfile -Command "& {
    Import-Module 'C:\Users\anrizzi\OneDrive - Microsoft\Documents\PowerShell\Modules\Pester\5.7.1\Pester.psd1' -Force
    Invoke-Pester -Path @(
        '.github/cli/tests',
        'hr/tests/pester',
        'infra/tests/pester'
    ) -Output Detailed
}"
```

Expected: zero failed tests.

- [ ] **Step 2: Run repository checks**

```powershell
git diff --check
git status --short
Get-ChildItem -Recurse -File -Filter '*.zip' | Select-Object -ExpandProperty FullName
Get-ChildItem -Recurse -File -Filter 'testResults.xml' | Select-Object -ExpandProperty FullName
```

Expected: no whitespace errors, no solution ZIP, no generated test result, and only intended files.

- [ ] **Step 3: Verify security and privacy boundaries**

Review diffs for operational configuration or evidence showing credentials, tokens, connection values, forbidden connections, TEST/PROD or other prohibited promotion targets, real personal data, evaluation components in `caldovahrfrontier`, broad sharing, auto-delete, or draft `2.0` mutation. Any such operational occurrence blocks completion. Policy, plan, test, or guide text that merely names TEST, PROD, Workday, forbidden connectors, or another prohibited surface does not block completion.

- [ ] **Step 4: Request scoped code review**

Use `superpowers:requesting-code-review`. Ask the reviewer to compare the diff with the addendum and this plan, focusing on lifecycle append-only behavior, raw-byte authority, deterministic serialization, exact correlation, confidence validation, replay, fail-closed paths, holdout consumption, tenant checkpoints, and evaluation-solution isolation.

- [ ] **Step 5: Resolve findings with TDD**

For every behavior finding, add a red test, reproduce, implement the minimum fix, run focused green, then rerun the complete suite. Commit each coherent fix separately.

---

### Task 14: Finish the branch without an unapproved push

**Files:**
- No new implementation files.

**Interfaces:**
- Produces a reviewed local branch ready for user-directed integration.

- [ ] **Step 1: Use the finishing workflow**

Invoke `superpowers:finishing-a-development-branch`. Re-run its verification gate before presenting branch options.

- [ ] **Step 2: Show local branch state**

```powershell
git status --short
git log --oneline --decorate -12
git diff --stat HEAD~1..HEAD
```

Expected: clean working tree after planned commits and a reviewable commit sequence.

- [ ] **Step 3: Do not push without approval**

Present local merge, pull-request, keep-branch, and discard choices. Do not run `git push`, create a pull request, merge, or delete the worktree unless the user explicitly chooses that action.

## Completion Gate

The work is complete only when:

- historical blocked evidence and fixed lifecycle history remain intact;
- draft fixed `2.0` is demonstrably untouched;
- selected tenant names and folder are approved and recorded before creation;
- exact fixed `1.0` publication and `evaluation_published` evidence precede creation or configuration of every evaluation solution component and `Process documents` action;
- the evaluation solution is unmanaged, DEV-only, isolated, and not in `caldovahrfrontier`;
- named-admin-only, disabled-by-default, secure input/output, connector allow-list, synthetic-only, and no-auto-delete controls pass;
- fixed `1.0` is recorded as `evaluation_published`, not business-approved;
- a training PDF passes `AEC-G001` through `AEC-G007`;
- all four fixed holdouts are captured exactly once and replayed locally;
- 68 fixed records and all strict calculated gates exist;
- `approved_for_solution` precedes addition to `caldovahrfrontier`;
- general work starts only after fixed success and separate approval, then follows the proven pattern;
- BoMs, inventory, run manifest, issue 13, and synchronized solution agree;
- all tests and scoped review pass;
- the flow is Off after every window;
- no evidence is auto-deleted; and
- no push occurs without explicit approval.

Any failed or unknown gate records `blocked`, disables the flow, preserves available evidence, and stops. It never produces a success-shaped record.
