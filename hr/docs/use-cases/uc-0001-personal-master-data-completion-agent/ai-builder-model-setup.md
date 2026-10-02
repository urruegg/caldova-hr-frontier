# Establishing and testing the AI Builder extraction models in Tenant 2 DEV

| Field | Value |
|---|---|
| **Version** | 0.5 |
| **Date** | 2026-10-01 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Draft |
| **Scope** | UC-0001 attended AI Builder model build and evaluation in Tenant 2 DEV |
| **References** | [Central idea record](../../../../docs/ideas/uc-0001-personal-master-data-completion-agent.md), [AI Builder Evaluation Capture Design Addendum](../../../../docs/specs/2026-09-29-ai-builder-evaluation-capture-design.md), [Tenant 2 AI Builder Model Implementation Design](../../../../docs/specs/2026-09-25-tenant-2-ai-builder-models-design.md), [AI Builder Field BoM](./bom-0001-peopledoc-master-data-ai-builder-fields.md), [AI Builder Test BoM](./bom-0002-ai-builder-test-inputs-and-outcomes.md), [AI Builder evidence contract](../../../evidence/ai-builder/README.md) |

This attended procedure resumes run `t2-dev-20260925-001` after Tasks 1-6 completed corpus qualification, readiness, fixed-model training, secured flow creation, and one immutable training-proof observation. It preserves the historical blocked event at [`model-test-capability.json`](../../../evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/model-test-capability.json) and both blocked upload attempts while preparing the captured bytes for deterministic replay.

Task 5 of the evaluation-capture implementation is complete after a third continuation. Attempts 1 and 2 remain preserved as blocked history. The unmanaged solution `Caldova HR AI Evaluation DEV` (`calhr_ai_evaluation_dev`, ID `df590fd2-13bc-f111-aaae-7ced8d44be51`) contains exactly the flow and two connection references. The flow `Capture AI Builder Evaluation Evidence` (workflow ID `24e38f04-9ebc-f111-aaae-7ced8d44be51`) is Off after exactly one successful attended run, is owned only by `admin@caldova25668747.onmicrosoft.com`, and has no run-only sharing.

Action-first discovery proved that AI Builder `Process documents` is represented by a dedicated Dataverse connection reference. Its approved display name is `Caldova HR AI Evaluation DEV Dataverse (AI Builder)`, generated unique name `calhr_sharedcommondataserviceforapps_68a73`, and connector `shared_commondataserviceforapps`. It is used only by operation `aibuilderpredict_formsprocessing`; no Dataverse table action is present. The second reference remains `Caldova HR AI Evaluation DEV SharePoint` / `calhr_ai_evaluation_dev_sharepoint` / `shared_sharepointonline`.

The final trusted-source definition retrieves the document inside `Capture evidence` with SharePoint action `Get source PDF`, operation `GetFileContentByPath`, at `/Shared Documents/AIBuilderEvaluationEvidence/<expected_filename>`. `Process documents` runs after that action and its document input is exactly `@body('Get_source_PDF')`; it does not process trigger-uploaded bytes. The flow remains Off after one successful training-proof run. No holdout was exposed.

> **STOP — Task 6 attempt 1 is blocked**
>
> The user separately authorized exactly one attended training-proof attempt. The selected qualified training file `a01-CAND-2026-0411-brunner.pdf` matched its manifest SHA-256, but SharePoint rejected the required upload with HTTP 403 `System.UnauthorizedAccessException`. The flow was never enabled or invoked. The restricted folder remains empty, the flow remains Off with zero runs, and no holdout was exposed. The one-attempt authorization is consumed; do not retry without a reviewed remediation plan and new explicit authorization.

Permission read-back after the failure proved that the folder has unique assignments and already grants only the attended administrator Full Control. No permission change was required or applied. The failed request used the tenant-root `/_api/web` scope rather than the `HRFrontierDEV` site scope at `/sites/HRFrontierDEV/_api/web`. A corrected upload remains a retry and therefore still requires new explicit authorization.

The user later authorized exactly one corrected retry. It reached the `HRFrontierDEV` site and created the same training filename with overwrite disabled, but immediate read-back found 3,038 bytes and a different SHA-256 from the qualified 3,042-byte source. The pre-flow byte gate stopped the retry. The flow remained Off with zero runs, AI Builder was not invoked, and no holdout was exposed. The mismatched source remains in the restricted folder as evidence. Do not replace, delete, upload again, or enable the flow without a new reviewed remediation plan and explicit authorization.

The reviewed remediation proved that the corrected retry's inline Base64 request body was already malformed before SharePoint received it. SharePoint had stored the submitted bytes exactly. The user approved preserving those bytes under `task6-retry-mismatch-a01-CAND-2026-0411-brunner.pdf`, then uploading the qualified source under its original allow-listed filename through Playwright native file selection. Browser-side and remote read-back checks both returned 3,042 bytes and SHA-256 `9c7ebe8d706b5b6ee98d779bcd83a578f8dff44b9b6bd7d02bff2b64e2ba67bd`.

The attended flow invocation `cap-20260930094537354Z-34bf8987` succeeded once and produced the immutable raw response, canonical envelope, and [`capture-pair.json`](../../../evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/capture/cap-20260930094537354Z-34bf8987/capture-pair.json). The flow returned to Off immediately. This completes Task 6 observation capture only. It does not establish capture capability, model quality, business approval, or permission to expose a holdout. Task 7 deterministic replay is next.

## 1. Authority, supersession, and preserved evidence

This guide follows the approved addendum and the original design together. It supersedes only the no-flow capture requirement for attended evaluation capture. All other constraints, field definitions, corpus rules, strict gates, evidence rules, and stop conditions remain in force unless the addendum states a narrower rule.

Tasks 1-5 remain complete and are not repeated here:

1. design and BoM review;
2. run initialization;
3. visual corpus review and qualification;
4. read-only readiness confirmation; and
5. creation, schema definition, tagging, and training of `PersonalMasterDataFixed`.

Preserve these existing records unchanged before any new mutation:

- `fixed-review.json`
- `general-review.json`
- `corpus-quality.json`
- `run-manifest.json`
- `model-inventory.json`
- `readiness.json`
- `model-test-capability.json`

The historical blocked event is evidence, not an error to erase. The append-only lifecycle must keep the prior `trained -> blocked` history and then use the flow-based path in this exact order:

1. `evaluation_published`
2. `capture_validated`
3. `evaluated`
4. `approved_for_solution`
5. `added_to_solution`

For every attended observation, record the operator UPN, UTC time, portal location, exact selected value, screenshot filename when visual evidence is needed, and machine-readable path plus SHA-256 whenever bytes exist.

> **STOP — preserved baseline missing**
>
> If any preserved record is missing, changed unexpectedly, or cannot be attributed to run `t2-dev-20260925-001`, stop. Do not publish, create a flow, or repair history in place.

## 2. Pre-mutation read-only readiness

Before any new tenant mutation, re-open the existing evidence and confirm that it still supports the addendum path:

- `run-manifest.json` still identifies Tenant 2 DEV, environment `84ad4c54-41d9-e5df-ba07-188b4719594a`, and solution `caldovahrfrontier`;
- `model-inventory.json` still shows `PersonalMasterDataFixed` version `1.0` as the trained model tied to this run;
- the preserved blocked record still explains why the earlier no-flow capture attempt stopped;
- the automatically created draft `2.0` is observed only as history and remains untouched; and
- no holdout has been consumed by retagging, retraining, or an unrecorded evaluation attempt.

Use the existing evidence root in every local command in this procedure:

```powershell
$runId = 't2-dev-20260925-001'
$evidenceDirectory = ".\hr\evidence\ai-builder\tenant-2\DEV\$runId"
```

**ATTENDED TENANT OPERATION — STOP FOR APPROVAL** Open the Power Apps AI Builder model record in read-only review mode and confirm the observed fixed model name, version `1.0`, and historical blocked state before any further action.

> **STOP — readiness drift**
>
> If the observed environment, model identity, version, prior evidence, or holdout status differs from the preserved baseline, stop. Do not continue until the user decides whether a new run is required.

## 3. Final-name and mutation approval

Before any mutation, record the final selected values for all new tenant-local components and obtain explicit approval to use them:

- evaluation solution display name;
- evaluation solution unique name;
- manual flow display name;
- dedicated OneDrive or SharePoint synthetic-evidence folder path;
- connection references;
- fixed model display name `PersonalMasterDataFixed`; and
- fixed model version `1.0`.

`PersonalMasterDataFixed` and `caldovahrfrontier` are the only approved model and business-solution names in this run. Do not train, edit, delete, publish, or use draft `2.0`.

The fixed model must continue to use the exact ordered 17-field contract from `field-contract.json`:

| BoM ID | Field | AI Builder type |
|---|---|---|
| `BOM-0001-F01` | `candidate_id` | `Text` |
| `BOM-0001-F02` | `last_name` | `Text` |
| `BOM-0001-F03` | `first_name` | `Text` |
| `BOM-0001-F04` | `dob` | `Date` |
| `BOM-0001-F05` | `nationality` | `Text` |
| `BOM-0001-F06` | `marital` | `Text` |
| `BOM-0001-F07` | `heimatort` | `Text` |
| `BOM-0001-F08` | `permit` | `Text` |
| `BOM-0001-F09` | `street` | `Text` |
| `BOM-0001-F10` | `plz` | `Text` |
| `BOM-0001-F11` | `city` | `Text` |
| `BOM-0001-F12` | `ahv` | `Text` |
| `BOM-0001-F13` | `iban` | `Text` |
| `BOM-0001-F14` | `phone` | `Text` |
| `BOM-0001-F15` | `email` | `Text` |
| `BOM-0001-F16` | `ec_name` | `Text` |
| `BOM-0001-F17` | `ec_phone` | `Text` |

> **STOP — approval missing**
>
> If the final selected names, folder, or connection references are not written into evidence and approved before mutation, stop. Do not let the portal choose an implicit default.

## 4. Fixed `1.0` evaluation publication

**ATTENDED TENANT OPERATION — STOP FOR APPROVAL** In Power Apps AI Builder, select `PersonalMasterDataFixed`, verify the selected version is exactly `1.0`, and publish it only to satisfy the `Process documents` execution requirement.

Record the operator UPN, UTC time, portal location, model ID, observed version, screenshot filename of the selected publish target, and any platform confirmation text.

After the attended publish succeeds, append the lifecycle event:

```powershell
Set-HrAiBuilderModelRecord `
    -RunManifestPath "$evidenceDirectory\run-manifest.json" `
    -ModelInventoryPath "$evidenceDirectory\model-inventory.json" `
    -ModelName 'PersonalMasterDataFixed' `
    -ModelId '<observed-fixed-model-id>' `
    -ModelVersion '1.0' `
    -LifecycleStage 'evaluation_published' `
    -ResumeBlockedEvaluation `
    -ResumeEvidencePath "$evidenceDirectory\model-test-capability.json"
```

`evaluation_published` is not business approval, TEST or PROD approval, solution membership, or permission to use the general model.

> **STOP — evaluation publication failure**
>
> If publication fails, select the current page evidence, record the platform failure, and stop. Do not switch to draft `2.0`, and do not create the evaluation flow as a workaround.

## 5. Evaluation solution and complete flow creation, explicit binding to published fixed `1.0`, save, and immediate Off state

**ATTENDED TENANT OPERATION — STOP FOR APPROVAL** Create a DEV-only unmanaged evaluation solution with the approved final names. Inside that solution create one owner-restricted, manually triggered file-bearing flow that:

1. accepts the synthetic PDF plus its exact qualified filename and expected SHA-256;
2. binds AI Builder `Process documents` explicitly to published `PersonalMasterDataFixed` version `1.0`;
3. writes the unmodified action body and canonical envelope to the dedicated synthetic-evidence folder;
4. saves successfully; and
5. is turned Off immediately after save.

Do not add the evaluation flow, its connection references, or its folder to `caldovahrfrontier`. Record the exact selected model name, selected version, solution name, flow name, folder path, and immediate Off-state screenshot filename.

> **STOP — evaluation-solution setup failure**
>
> If the flow cannot be created exactly as approved, or if the selected model is anything other than published fixed `1.0`, turn the flow Off if it exists, record `blocked`, and stop.

## 6. Security application and verification

Apply and verify these controls before any document is processed:

- named administrators only own or run the flow;
- the flow is disabled by default and enabled only for an attended window;
- secure inputs and outputs are enabled on the trigger and all actions that touch the file, AI Builder body, or JSON output;
- connectors are limited to AI Builder and the dedicated Tenant 2 OneDrive or SharePoint synthetic-evidence location;
- storage remains synthetic only; and
- no auto-delete, cleanup rule, or retention shortcut is configured.

**ATTENDED TENANT OPERATION — STOP FOR APPROVAL** Re-open the saved flow, inspect trigger sharing, connections, secure-input/output settings, and the Off state, and capture the exact selected values plus screenshots for the portal views that prove them.

> **STOP — security verification failure**
>
> If any ownership, disabled-by-default, secure input/output, connector allow-list, synthetic-only, or no-auto-delete control is missing or unknown, turn the flow Off, record `blocked`, and stop.

## 7. One training-PDF observation and immutable byte retention without a capability claim

Use one allow-listed **training PDF** before any holdout. Do not expose a fixed holdout until this proof is captured and verified.

**ATTENDED TENANT OPERATION — STOP FOR APPROVAL** Turn the flow On for a single attended proof window, submit one training PDF from the qualified fixed corpus with its exact manifest filename and SHA-256, confirm the run completes, and turn the flow Off immediately after the run.

Store the proof under the capture layout below and retain every file immutably:

```text
capture/
└── <approved-evidence-folder-name>/
    └── <execution-run-id>/
        ├── source/<exact-qualified-filename>.pdf
        ├── <execution-run-id>.ai-builder.raw.json
        ├── <execution-run-id>.canonical.json
        └── capture-pair.json
```

This single run proves only that bytes were captured. It does not yet claim capability.

> **STOP — training-proof capture failure**
>
> If any source, raw, canonical, or capture-pair file is missing, overwritten, malformed, or unhashable, turn the flow Off, record `blocked`, and stop.

## 8. Adapter TDD against the observed raw shape

The local adapter must be tested against the observed raw `Process documents` shape before capability is claimed. The adapter reads retained source and raw bytes, verifies correlation, and reproduces the canonical envelope without transcription.

Run focused local TDD against the observed raw shape before using the proof capture for any decision:

```powershell
powershell.exe -NoProfile -Command "& {
    Import-Module 'C:\Users\anrizzi\OneDrive - Microsoft\Documents\PowerShell\Modules\Pester\5.7.1\Pester.psd1' -Force
    Invoke-Pester -Path 'hr/tests/pester/AiBuilderEvidence.Tests.ps1' -FullNameFilter '*AI Builder evaluation capture schema contracts*'
}"
```

Use the approved adapter path when importing proof or holdout captures:

```powershell
$adapterScriptPath = '.\hr\src\scripts\adapters\ConvertFrom-HrAiBuilderEvaluationCapture.ps1'
```

Task 7 has not yet implemented `.\hr\src\scripts\adapters\ConvertFrom-HrAiBuilderEvaluationCapture.ps1`. Do not run the adapter-backed import commands in this guide until Task 7 creates that exact script and the focused adapter tests pass. If the script is absent or the tests are not green, stop and leave the flow Off.

> **STOP — adapter contract failure**
>
> If focused adapter or capture-contract tests fail, keep the flow Off, record `blocked`, and stop. Do not edit retained raw bytes to make a test pass.

## 9. Calculated training-PDF capability decision

Import the proof capture through the adapter and retain the resulting prediction capture as repository evidence:

```powershell
.\hr\src\scripts\Import-AiBuilderQuickTestResults.ps1 `
    -RunManifestPath "$evidenceDirectory\run-manifest.json" `
    -ModelSchemaRecordPath "$evidenceDirectory\model-schema-record-fixed.json" `
    -RawExportDirectory "$evidenceDirectory\capture\<approved-evidence-folder-name>" `
    -AdapterScriptPath $adapterScriptPath `
    -TargetModelName 'PersonalMasterDataFixed' `
    -OutputPath "$evidenceDirectory\prediction-capture-fixed-training-proof.json"
```

Claim capability only when the retained source PDF, raw body, canonical envelope, capture-pair record, and adapter replay all agree on exact filename, SHA-256, model name, model version, and the complete 17-field `{ value, confidence }` contract.

Append `capture_validated` only after the proof passes:

```powershell
Set-HrAiBuilderModelRecord `
    -RunManifestPath "$evidenceDirectory\run-manifest.json" `
    -ModelInventoryPath "$evidenceDirectory\model-inventory.json" `
    -ModelName 'PersonalMasterDataFixed' `
    -ModelId '<observed-fixed-model-id>' `
    -ModelVersion '1.0' `
    -LifecycleStage 'capture_validated'
```

> **STOP — capability decision failure**
>
> If any capability gate fails or is unknown, record `blocked`, retain the failed proof, keep the flow Off, and stop. Do not expose a holdout.

## 10. Exactly-once fixed holdout capture and calculated evaluation

After `capture_validated`, process each fixed holdout exactly once. Keep the approved flow path, disable the flow after the attended window, and treat any model change as holdout consumption.

**ATTENDED TENANT OPERATION — STOP FOR APPROVAL** Turn the flow On, submit each of the four fixed holdouts with its exact filename and SHA-256, record the run ID and capture folder for each execution, and turn the flow Off after the final successful holdout or immediately after any failure.

If any fixed holdout result influences tagging, retraining, publication choice, or another model change, the affected holdout set is consumed. Do not reuse it. Generate unseen synthetic documents, qualify them, and begin a new run.

Import the fixed holdout captures and calculate the evaluation:

```powershell
.\hr\src\scripts\Import-AiBuilderQuickTestResults.ps1 `
    -RunManifestPath "$evidenceDirectory\run-manifest.json" `
    -ModelSchemaRecordPath "$evidenceDirectory\model-schema-record-fixed.json" `
    -RawExportDirectory "$evidenceDirectory\capture\<approved-evidence-folder-name>" `
    -AdapterScriptPath $adapterScriptPath `
    -TargetModelName 'PersonalMasterDataFixed' `
    -OutputPath "$evidenceDirectory\prediction-capture-fixed.json"

.\hr\src\scripts\Measure-AiBuilderEvaluation.ps1 `
    -RunManifestPath "$evidenceDirectory\run-manifest.json" `
    -CorpusQualityPath "$evidenceDirectory\corpus-quality.json" `
    -FieldContractPath '.\hr\src\ai-builder\contracts\field-contract.json' `
    -ModelSchemaRecordPath "$evidenceDirectory\model-schema-record-fixed.json" `
    -PredictionCapturePath "$evidenceDirectory\prediction-capture-fixed.json" `
    -GroundTruthPath '.\hr\docs\use-cases\uc-0001-personal-master-data-completion-agent\caldova-aib-fixed-template\ground-truth.json' `
    -EvidenceDirectory $evidenceDirectory
```

The calculated evaluation must preserve strict machine-readable evidence for the exact `run-manifest.json` context, keep every present-field mismatch explicit, and prove that zero-false-value evidence still holds. The false-value rate remains zero; if it does not, strict gating fails and the model does not advance.

Advance the model to `evaluated` only when the calculated evaluation finishes with complete attribution and strict-gate disposition `evaluated`.

```powershell
Set-HrAiBuilderModelRecord `
    -RunManifestPath "$evidenceDirectory\run-manifest.json" `
    -ModelInventoryPath "$evidenceDirectory\model-inventory.json" `
    -ModelName 'PersonalMasterDataFixed' `
    -ModelId '<observed-fixed-model-id>' `
    -ModelVersion '1.0' `
    -LifecycleStage 'evaluated'
```

> **STOP — holdout capture or evaluation failure**
>
> On any capture, import, integrity, or strict-gate failure, record `blocked`, retain every failed execution, turn the flow Off, and stop.

## 11. Solution-approval decision

Use only calculated repository evidence for the approval decision. `approved_for_solution` is allowed only when the fixed evaluation proves the exact run, corpus revision, model version `1.0`, and retained bytes passed all strict gates.

Append `approved_for_solution` only on calculated success:

```powershell
Set-HrAiBuilderModelRecord `
    -RunManifestPath "$evidenceDirectory\run-manifest.json" `
    -ModelInventoryPath "$evidenceDirectory\model-inventory.json" `
    -ModelName 'PersonalMasterDataFixed' `
    -ModelId '<observed-fixed-model-id>' `
    -ModelVersion '1.0' `
    -LifecycleStage 'approved_for_solution'
```

**ATTENDED TENANT OPERATION — STOP FOR APPROVAL** Only after that approval, add the published fixed `1.0` model explicitly to the unmanaged `caldovahrfrontier` solution and record the exact selected model, version, solution location, and screenshot filename.

After the add succeeds, append `added_to_solution`.

```powershell
Set-HrAiBuilderModelRecord `
    -RunManifestPath "$evidenceDirectory\run-manifest.json" `
    -ModelInventoryPath "$evidenceDirectory\model-inventory.json" `
    -ModelName 'PersonalMasterDataFixed' `
    -ModelId '<observed-fixed-model-id>' `
    -ModelVersion '1.0' `
    -LifecycleStage 'added_to_solution'
```

> **STOP — solution approval failed**
>
> If calculated gates do not support `approved_for_solution`, stop. Do not add the model to `caldovahrfrontier`.

> **STOP — solution-add failure**
>
> If the approved model cannot be added to `caldovahrfrontier`, retain the evidence, do not append `added_to_solution`, and stop.

## 12. General model continuation decision

`PersonalMasterDataGeneral` remains outside this task until the fixed model succeeds first. Do not begin `PersonalMasterDataGeneral` until `PersonalMasterDataFixed` version `1.0` has reached `approved_for_solution`, the user has approved continuation, and the attended operator records that approval explicitly.

Do not treat `evaluation_published` as permission to create, train, evaluate, publish, or solution-package the general model. Do not use draft `2.0` for any shortcut.

> **STOP — general-model gate closed**
>
> If fixed `1.0` is not approved, or if the user has not approved continuation, stop with the general model at `not_created`.

## 13. Synchronization, BoMs, manifest, and issue 13

After the fixed model is added to `caldovahrfrontier`, synchronize the unpacked solution source and then update the repository records from evidence only:

```powershell
.\hr\src\scripts\Sync-HrSolutionSource.ps1 `
    -TenantAlias 'caldova25668747' `
    -SolutionUniqueName 'caldovahrfrontier'
```

Finalize the run evidence only after synchronization evidence exists. Update the two BoMs and issue 13 from the recorded lifecycle, capture folders, hashes, calculated metrics, and solution version. Preserve all capture files in place; no cleanup is implied by successful evaluation, approval, or synchronization.

> **STOP — synchronization failure**
>
> If synchronization or evidence finalization fails, retain the capture files, do not claim source parity, and stop.
