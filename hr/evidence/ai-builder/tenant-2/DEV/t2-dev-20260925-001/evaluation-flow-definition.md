# Tenant 2 DEV Evaluation Flow Definition

| Field | Value |
|---|---|
| **Version** | 1.2 |
| **Date** | 2026-09-30 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Active |
| **Scope** | Completed Task 5 Tenant 2 DEV evaluation capture flow |
| **References** | [Evaluation Capture Design](../../../../../../docs/specs/2026-09-29-ai-builder-evaluation-capture-design.md), [Capture intent](evaluation-capture-intent.json), [Capture readiness](evaluation-capture-readiness.json), [Model publication](model-evaluation-publication.json), [Security verification](security-verification.json) |

## Current outcome

Task 5 attempt 3 completed and passed. The unmanaged solution `Caldova HR AI Evaluation DEV` / `calhr_ai_evaluation_dev` has solution ID `df590fd2-13bc-f111-aaae-7ced8d44be51`. Its inventory contains exactly one cloud flow and two connection references.

The flow `Capture AI Builder Evaluation Evidence` has workflow ID `24e38f04-9ebc-f111-aaae-7ced8d44be51`. Its portal status is **Off**, it has zero run history, its primary owner is Microsoft Administrator (`admin@caldova25668747.onmicrosoft.com`), and it has no run-only sharing.

No PDF has been uploaded, submitted, or processed. The approved SharePoint folder remains empty and restricted. Task 6 is not authorized without its separate attended approval.

## Machine-readable definition evidence

The fresh post-import tenant export is preserved as `evaluation-flow-export.json` with SHA-256 `AE3C91F22CB6BA0DE8B1BF5226C3C02FA92302B1D32C705C2081EFE660DA91D9`. It is the authoritative machine-readable record of:

- the trigger schema, required flags, and `capture_stage` enum;
- the complete validation expression and fixed-model filename allow-lists;
- both connection-reference logical names;
- action types, connector operations, inputs, and `runAfter` rules;
- secure trigger and AI Builder settings;
- the ordered canonical object and 17 ordered field mappings;
- raw and canonical filename/content expressions; and
- explicit success, capture-failure, and invalid-request termination.

The remaining sections summarize that exported definition for attended review; they do not replace it.

## Append-only attempt history

### Attempt 1 — publisher gate

Attempt 1 stopped before tenant mutation because the intent did not record an approved publisher after read-back. Commit `dbcd3684a2e5a790382e58af8d8808a1471073a4` preserves that historical failure. It remains authoritative and is not reclassified.

### Attempt 2 — AI Builder connection-reference gate

Attempt 2 passed the publisher gate and created the approved unmanaged solution, SharePoint connection reference, and restricted empty folder. It stopped because the supported connection-reference picker did not expose `shared_aibuilder`. No substitute connector or flow was created. This blocker remains authoritative for the second attempt.

### Attempt 3 — successful action-first continuation

Action-first discovery established that solution-aware AI Builder `Process documents` uses a dedicated Dataverse connection reference. The user approved the narrower boundary and retaining the platform-generated unique name while changing only its display name:

| Property | Verified value |
|---|---|
| Display name | `Caldova HR AI Evaluation DEV Dataverse (AI Builder)` |
| Generated unique name | `calhr_sharedcommondataserviceforapps_68a73` |
| Connector | `shared_commondataserviceforapps` |
| Sole use | AI Builder `Process documents` operation `aibuilderpredict_formsprocessing` |
| Dataverse table actions | None |

This action-only dependency resolves attempt 2 without erasing it and does not authorize general Dataverse use.

## Exact solution inventory

| Component | Verified value |
|---|---|
| Cloud flow | `Capture AI Builder Evaluation Evidence`; workflow ID `24e38f04-9ebc-f111-aaae-7ced8d44be51` |
| AI Builder dependency | `Caldova HR AI Evaluation DEV Dataverse (AI Builder)` / `calhr_sharedcommondataserviceforapps_68a73` / `shared_commondataserviceforapps` |
| Storage dependency | `Caldova HR AI Evaluation DEV SharePoint` / `calhr_ai_evaluation_dev_sharepoint` / `shared_sharepointonline` |

There are exactly three solution objects: the flow and these two connection references. Existing unmanaged solution `caldovahrfrontier` is unchanged.

## Exported trigger and fail-closed validation

The fresh exported definition proves six required trigger inputs:

1. `source_pdf` — File;
2. `expected_filename` — Text;
3. `expected_sha256` — Text;
4. `execution_run_id` — Text;
5. `corpus_revision` — Text; and
6. `capture_stage` — enum `training-proof`, `fixed-holdout`, or `general-holdout`.

Validation occurs before AI Builder and fails closed for:

- source-file name versus claimed filename identity;
- lower-case 64-hex claimed SHA-256;
- execution run ID pattern `^cap-[0-9]{17}Z-[a-f0-9]{8}$`;
- exact corpus revision `c0310c527f010cc9a24d7a78dae7db1e5ad136116b14306413162fb4223926db`;
- one of the three declared capture-stage values; and
- the exact training and fixed-holdout filename allow-lists from the qualified fixed-model corpus.

Because this flow is bound to the fixed model, `general-holdout` is a reserved portability value and fails the filename-stage validation. Invalid or unsupported requests terminate before `Process documents`.

## Exact action inventory

| Scope or branch | Action |
|---|---|
| If yes / `Capture evidence` | `Get source PDF` |
| If yes / `Capture evidence` | `Process documents` |
| If yes / `Capture evidence` | `Create raw response` |
| If yes / `Capture evidence` | `Build canonical envelope` |
| If yes / `Capture evidence` | `Create canonical envelope` |
| If yes | `Terminate capture success` |
| If yes | `Terminate capture failure` |
| If no | `Terminate invalid request` |

## Trusted source retrieval and AI binding

Within the `Capture evidence` scope, action `Get source PDF` uses the approved SharePoint connection reference and operation `GetFileContentByPath`. Its path is:

```text
/Shared Documents/AIBuilderEvaluationEvidence/<expected_filename>
```

`Process documents` runs only after `Get source PDF` succeeds and consumes the retrieved SharePoint bytes through the exact binding:

```text
@body('Get_source_PDF')
```

It does not consume trigger-uploaded bytes. The trigger file remains an attended input surface, but the approved restricted SharePoint folder is the trusted document source used for AI processing.

## AI Builder action and outputs

`Process documents` is explicitly bound to `PersonalMasterDataFixed` model ID `74b09a72-d1f1-4598-bc4d-3746d5c97acc`. The published fixed `1.0` lineage was proven before flow creation; draft `2.0` remains untouched. Secure inputs and outputs are enabled on both the manual trigger and AI Builder action.

The flow writes, using Create file and without overwrite:

- the unmodified action body as `<execution_run_id>.ai-builder.raw.json`; and
- the ordered canonical envelope as `<execution_run_id>.canonical.json`.

The canonical envelope contains the approved ordered 17-field contract with each field represented as `value` then `confidence`. Both writes target the approved restricted SharePoint folder. The definition has explicit success, capture-failure, and invalid-request termination.

## Security and negative inventory

The owner and primary owner are Microsoft Administrator (`admin@caldova25668747.onmicrosoft.com`). There is no run-only sharing. The only connector families are `shared_commondataserviceforapps` for the single AI Builder operation and `shared_sharepointonline` for approved file writes.

The exported definition contains no Dataverse table action, HTTP, custom connector, email, Teams, Workday, agent, child flow, schedule, recurrence, event trigger, delete, cleanup, or retention action. Portal Flow checker reported **0 errors and 0 warnings**.

The flow remains Off with zero runs. The folder remains empty and restricted. No training PDF, fixed holdout, or general holdout has been exposed.

## Attended evidence

The Task 5 evidence set includes:

- `evaluation-flow-solution-inventory.png` — exact one-flow/two-reference inventory;
- `evaluation-flow-off-zero-runs.png` — flow details showing the Off state;
- `evaluation-flow-zero-run-history.png` — run-history view stating that the flow has not been run;
- `evaluation-flow-definition-checker.png` — Flow checker with zero errors and zero warnings; and
- `evaluation-flow-trigger-controls.png` — trigger editor showing `source_pdf`, `expected_filename`, `expected_sha256`, and `execution_run_id`.

`security-verification.json` is the authoritative screenshot-hash inventory. The hash-bound `evaluation-flow-export.json`, not the partial trigger screenshot, is the authoritative evidence for all six trigger inputs, the three stage choices, and secure trigger settings.

## Next authorization boundary

Task 5 is complete. Task 6 remains unchecked and unauthorized. Before any enablement or invocation, obtain separate attended approval for exactly one allow-listed training-PDF observation. Task 5 completion is not permission to expose a PDF.
