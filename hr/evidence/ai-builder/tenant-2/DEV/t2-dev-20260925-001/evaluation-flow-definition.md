# Tenant 2 DEV Evaluation Flow Definition

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-29 |
| **Author** | GitHub Copilot |
| **Status** | Blocked |
| **Scope** | Task 5 Tenant 2 DEV evaluation capture |
| **References** | [Evaluation Capture Design](../../../../../../docs/superpowers/specs/2026-09-29-ai-builder-evaluation-capture-design.md), `evaluation-capture-intent.json`, `evaluation-capture-readiness.json`, `model-evaluation-publication.json`, `security-verification.json` |

## Outcome

Task 5 stopped before any tenant mutation. The publication dependency passed: Tenant 2 DEV and the repository both identify `PersonalMasterDataFixed` model `74b09a72-d1f1-4598-bc4d-3746d5c97acc` version `1.0` as published for evaluation, and the open draft remained untouched.

The solution-creation gate did not pass. `evaluation-capture-intent.json` does not record an approved publisher display name, unique name, or prefix after read-back. Task 5 Step 2 permits use of an existing publisher only when intent records it after read-back; otherwise it requires a separate publisher decision. No publisher was inferred from `caldovahrfrontier`.

## Intended approved resources

| Resource | Exact approved value | Observed Task 5 state |
|---|---|---|
| Evaluation solution | `Caldova HR AI Evaluation DEV` / `calhr_ai_evaluation_dev` | Not created |
| Manual flow | `Capture AI Builder Evaluation Evidence` | Not created |
| AI Builder connection reference | `Caldova HR AI Evaluation DEV AI Builder` / `calhr_ai_evaluation_dev_aibuilder` | Not created |
| SharePoint connection reference | `Caldova HR AI Evaluation DEV SharePoint` / `calhr_ai_evaluation_dev_sharepoint` | Not created |
| Synthetic-evidence folder | `https://caldova25668747.sharepoint.com/sites/HRFrontierDEV/Shared Documents/AIBuilderEvaluationEvidence` | Not created |
| Existing business solution | `caldovahrfrontier` | Present and unchanged |

Read-only supported CLI checks found zero exact matches for the intended evaluation solution and flow. No connection reference or folder was created because execution stopped before Step 2.

## Flow definition state

There is no saved flow definition. Therefore no action names, expressions, connection-reference bindings, output mapping, owner/run-only assignment, secure inputs/outputs, or Off state can be claimed.

The binding target remains the exact published `PersonalMasterDataFixed` version `1.0`; no `Process documents` action was created and no selector was allowed to resolve to draft `2.0` or “latest”.

The required future flow contract remains unchanged:

- manual file-bearing trigger inputs `source_pdf`, `expected_filename`, `expected_sha256`, `execution_run_id`, `corpus_revision`, and `capture_stage`;
- deterministic required-input, lower-case SHA-256, run-ID, corpus-revision, stage, and exact filename allow-list validation before AI Builder;
- only AI Builder and SharePoint connector families;
- source read from the dedicated synthetic-evidence folder;
- unmodified AI Builder action body written as `<execution_run_id>.ai-builder.raw.json`;
- ordered 17-field canonical envelope written as `<execution_run_id>.canonical.json`;
- compact UTF-8 JSON without BOM and with one terminal LF;
- create-file collision failure with no overwrite;
- explicit success and failure termination;
- no auto-delete or cleanup; and
- immediate Off state after the first complete save and before any test or run.

## Security disposition

`security-verification.json` records the publisher gate as `failed`. Controls that require an existing flow are `unknown`, not passed. The safe state is preserved because no flow exists and no PDF was uploaded or submitted.

No HTTP, custom connector, email, Teams, Workday, agent, Dataverse table, schedule, recurrence, event trigger, production source, child flow, delete action, or mutation of draft `2.0` occurred.

## Attended evidence

`evaluation-flow-publication-dependency.png` records the supported Power Apps page showing `PersonalMasterDataFixed` as Published with the open-draft warning. Its SHA-256 is `5f46de223fda357072f88c52475f8fe46d651b905538cbc2ce897cbcafb3287b`.

## Required restart condition

Before Task 5 can resume, a supported read-back must identify the proposed existing publisher and a separate approval must record its display name, unique name, and prefix in `evaluation-capture-intent.json`. Then Task 5 must restart at Step 1 and re-verify tenant identity, publication lineage, approval, and draft preservation.
