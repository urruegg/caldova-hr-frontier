# Tenant 2 DEV Evaluation Flow Definition

| Field | Value |
|---|---|
| **Version** | 1.1 |
| **Date** | 2026-09-29 |
| **Author** | GitHub Copilot |
| **Status** | Blocked |
| **Scope** | Task 5 Tenant 2 DEV evaluation capture |
| **References** | [Evaluation Capture Design](../../../../../../docs/superpowers/specs/2026-09-29-ai-builder-evaluation-capture-design.md), `evaluation-capture-intent.json`, `evaluation-capture-readiness.json`, `model-evaluation-publication.json`, `security-verification.json` |

## Current outcome

Task 5 attempt 2 restarted from Step 1 after the separate publisher decision. Supported read-back exactly matched the approved publisher:

- friendly name `Caldova HR frontier`;
- unique name `calhrfrontier`;
- prefix `calhr`; and
- publisher ID `6b6eabd8-57b6-40b7-9d12-7b2a045978e8`.

The publication dependency still passed. Tenant 2 DEV and repository evidence identify `PersonalMasterDataFixed` model `74b09a72-d1f1-4598-bc4d-3746d5c97acc` version `1.0` as published for evaluation. Draft `2.0` remained untouched.

The resumed attempt created the approved unmanaged evaluation solution, the exact SharePoint connection reference, and the empty SharePoint folder. The folder has unique permissions and only `admin@caldova25668747.onmicrosoft.com` has Full Control.

The attempt then stopped at Task 5 Step 3. The supported Power Apps connection-reference picker exposed no AI Builder connector, no `shared_aibuilder` entry, and no connector containing “Builder”. Supported `pac connectivity list-connectors` read-back also returned zero AI Builder or `shared_aibuilder` matches. The required exact AI Builder connection reference could not be created. No substitute connector was selected.

## Append-only attempt history

### Attempt 1 — publisher gate

Attempt 1 stopped before tenant mutation because the intent did not record an approved publisher after read-back. Commit `dbcd3684a2e5a790382e58af8d8808a1471073a4` preserves that historical failure. It remains authoritative for attempt 1 and has not been rewritten away.

### Attempt 2 — AI Builder connection-reference gate

Attempt 2 passed the publisher gate and performed only the already approved mutations listed below. It stopped when the exact AI Builder connection reference could not be created through the supported UI or observed connector inventory.

## Exact resource read-back

| Resource | Exact approved value | Attempt 2 state |
|---|---|---|
| Evaluation solution | `Caldova HR AI Evaluation DEV` / `calhr_ai_evaluation_dev` | Created; ID `df590fd2-13bc-f111-aaae-7ced8d44be51`; unmanaged `1.0.0.0`; approved publisher |
| Manual flow | `Capture AI Builder Evaluation Evidence` | Not created; exact workflow match count `0` |
| AI Builder connection reference | `Caldova HR AI Evaluation DEV AI Builder` / `calhr_ai_evaluation_dev_aibuilder` | Not created; supported connector and picker match counts `0` |
| SharePoint connection reference | `Caldova HR AI Evaluation DEV SharePoint` / `calhr_ai_evaluation_dev_sharepoint` | Created and active; ID `94b29de5-14bc-f111-aaae-70a8a505d538`; connector `/providers/Microsoft.PowerApps/apis/shared_sharepointonline` |
| Synthetic-evidence folder | `https://caldova25668747.sharepoint.com/sites/HRFrontierDEV/Shared Documents/AIBuilderEvaluationEvidence` | Created, empty, unique permissions, sole administrator principal |
| Existing business solution | `caldovahrfrontier` | Present, unmanaged, unchanged |

## Flow definition state

There is no saved flow definition. Therefore no action names, expressions, output mapping, model binding, owner/run-only assignment, secure inputs/outputs, or Off state can be claimed. The safe state is the verified absence of the exact flow, not an unverified or partially configured executable flow.

The required future flow contract remains unchanged:

- manual file-bearing trigger inputs `source_pdf`, `expected_filename`, `expected_sha256`, `execution_run_id`, `corpus_revision`, and `capture_stage`;
- deterministic required-input, lower-case SHA-256, run-ID, corpus-revision, stage, and exact filename allow-list validation before AI Builder;
- only AI Builder and SharePoint connector families;
- source read from the dedicated synthetic-evidence folder;
- explicit binding to published `PersonalMasterDataFixed` version `1.0`, never “latest” or draft `2.0`;
- unmodified AI Builder action body written as `<execution_run_id>.ai-builder.raw.json`;
- ordered 17-field canonical envelope written as `<execution_run_id>.canonical.json`;
- compact UTF-8 JSON without BOM and with one terminal LF;
- create-file collision failure with no overwrite;
- explicit success and failure termination;
- no auto-delete or cleanup; and
- immediate Off state after the first complete save and before any test or run.

## Security disposition

`security-verification.json` records attempt 2 as `blocked`. Controls observed on created resources are recorded as passed or failed. Flow-dependent controls remain `unknown`; they are not represented as passed.

No PDF was uploaded, submitted, or processed. No HTTP, custom connector, email, Teams, Workday, agent, Dataverse table, schedule, recurrence, event trigger, production source, child flow, delete action, or substitute connector was introduced. Nothing was added to `caldovahrfrontier`. Draft `2.0` was not touched. No tenant resource was deleted.

## Attended evidence

- `evaluation-flow-publication-dependency.png` — published fixed `1.0` and preserved open-draft warning; SHA-256 `5F46DE223FDA357072F88C52475F8FE46D651B905538CBC2CE897CBCAFB3287B`.
- `evaluation-solution-resources.png` — exact solution inventory with one SharePoint connection reference and zero cloud flows; SHA-256 `DFFEBE8D5E3EA6BED0612A6652230E0385622E863E78D5A766E2AB85BDC9B1F9`.
- `evaluation-folder-permissions.png` — unique folder permissions and sole Microsoft Administrator principal; SHA-256 `762030649DD6F706DD1A4607DADC077903A9366B0DAA2C33BE924D82090F2B17`.

## Required restart condition

Before Task 5 can resume, an approved supported tenant mechanism must expose `/providers/Microsoft.PowerApps/apis/shared_aibuilder` as the exact explicit solution connection reference without introducing a forbidden connector. Then Task 5 must restart at Step 1 and re-verify tenant identity, publication lineage, approval, publisher, resource state, and draft preservation. The existing solution, SharePoint reference, and folder must be reused; no duplicate resource may be created.
