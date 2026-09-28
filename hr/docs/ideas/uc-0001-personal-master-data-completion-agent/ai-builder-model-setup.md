# Establishing and testing the AI Builder extraction models in Tenant 2 DEV

| Field | Value |
|---|---|
| **Version** | 0.2 |
| **Date** | 2026-09-28 |
| **Author** | DAAI |
| **Status** | Draft |
| **Scope** | UC-0001 attended AI Builder model build and evaluation in Tenant 2 DEV |
| **References** | [Tenant 2 AI Builder Model Implementation Design](../../../../docs/superpowers/specs/2026-09-25-tenant-2-ai-builder-models-design.md), [AI Builder Field BoM](./bom-0001-peopledoc-master-data-ai-builder-fields.md), [AI Builder Test BoM](./bom-0002-ai-builder-test-inputs-and-outcomes.md) |

This is the attended procedure for run `t2-dev-20260925-001`. It creates evidence under `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/` and uses only the committed synthetic [fixed-template package](./gf-aib-fixed-template/) and [general-documents package](./gf-aib-general-documents/).

This increment creates no workflow, agent, automated model-selection rule, downstream deployment, or HR-system integration. No Power Automate flow is authorized for model evaluation. A failed or unknown gate stops the procedure; the operator records the evidence and does not repair tenant prerequisites under this sprint.

---

## 1. Read the design and both BoMs

Read these three records before opening AI Builder:

1. [Tenant 2 AI Builder Model Implementation Design](../../../../docs/superpowers/specs/2026-09-25-tenant-2-ai-builder-models-design.md) — the approved scope, gates, evidence contract, and stop behavior.
2. [AI Builder Field BoM](./bom-0001-peopledoc-master-data-ai-builder-fields.md) — the 17-field lifecycle record.
3. [AI Builder Test BoM](./bom-0002-ai-builder-test-inputs-and-outcomes.md) — the run-level input and outcome record.

The two model records are independent:

| Model | AI Builder type | Training allocation | Held-out allocation |
|---|---|---:|---:|
| `PersonalMasterDataFixed` | Fixed template document processing | 20 documents | 4 documents |
| `PersonalMasterDataGeneral` | General document processing | 16 documents | 8 documents |

Both models implement the ordered contract in [`field-contract.json`](../../../src/ai-builder/contracts/field-contract.json). The first Tenant 2 run establishes the measured baseline. Do not introduce a percentage threshold that is not derived and approved from evidence.

---

## 2. Initialize `t2-dev-20260925-001`

From the repository root, set the attended operator UPN and initialize the evidence directory. Confirm the Tenant 2 DEV environment ID and current unmanaged solution version against the approved design before running the command.

```powershell
$runId = 't2-dev-20260925-001'
$evidenceDirectory = ".\hr\evidence\ai-builder\tenant-2\DEV\$runId"

.\hr\src\scripts\Initialize-AiBuilderEvidenceRun.ps1 `
    -RunId $runId `
    -TenantKey 'tenant-2' `
    -EnvironmentId ([guid]'84ad4c54-41d9-e5df-ba07-188b4719594a') `
    -EnvironmentStage DEV `
    -SolutionUniqueName 'caldovahrfrontier' `
    -SolutionVersion '0.0.0.1' `
    -OperatorUpn '<attended-operator-upn>' `
    -OutputDirectory $evidenceDirectory
```

The first invocation must exit non-zero after creating `fixed-review.json` and `general-review.json`. The message `Visual corpus review is required before qualification.` is expected. Do not create either model yet.

---

## 3. Complete visual corpus review and rerun qualification

Review every synthetic PDF against the corresponding JSON and CSV ground truth. For each row in both review files:

- set `status` to `confirmed` only after direct visual inspection;
- set `values_visible` to `true` only when every non-empty ground-truth value is visible;
- set `absences_confirmed` to `true` only when every empty value is genuinely absent;
- record the attended reviewer; and
- describe any exclusion or correction in `notes`.

Rerun the initialization command from §2. A passing rerun writes:

- `corpus-quality.json`;
- `run-manifest.json`; and
- `model-inventory.json`.

Confirm the manifest records 20 fixed and 16 general training documents, 4 fixed and 8 general held-out documents, the 17-field contract version, corpus revision, generator revision, file hashes, operator, and UTC start.

> **STOP — corpus qualification failure**
>
> If either corpus, either ground-truth representation, any visual review, any hash, or any training/held-out assignment fails qualification, stop. Correct or exclude the affected synthetic document and start a new evidence run when file identity or allocation changes. Do not upload any document to AI Builder.

---

## 4. Execute all readiness checks and write `readiness.json`

Observe all eight checks in Tenant 2 DEV. Record `passed`, `failed`, or `unknown`, the observation, its source, the attended operator, and UTC time. Do not convert an unavailable observation into a pass.

| Check ID | Pass evidence |
|---|---|
| `environment` | DEV URL and environment ID match the approved baseline |
| `dataverse` | Authenticated Dataverse organization identity and availability match |
| `maker_authorization` | The attended account can create, train, publish, and package AI Builder models |
| `ai_builder_available` | Custom document processing is available |
| `capacity` | Sufficient AI Builder capacity is observed |
| `data_policy` | Applicable policy permits AI Builder and Dataverse use |
| `solution` | `caldovahrfrontier` exists, is unmanaged, and its version is recorded |
| `publisher` | The existing solution publisher and prefix are observed |

Import the evidence module, construct one observation object per row, and write the record:

```powershell
Import-Module '.\hr\src\scripts\modules\Caldova.HrFrontier.AiBuilder\Caldova.HrFrontier.AiBuilder.psd1' -Force

# $checks contains exactly the eight rows above. Each row has:
# id, status, observation, source, operator, and observed_at_utc.
$readiness = New-HrAiBuilderReadinessRecord `
    -RunId 't2-dev-20260925-001' `
    -Checks $checks `
    -OutputPath "$evidenceDirectory\readiness.json"
```

> **STOP — readiness failure**
>
> Continue only when `$readiness.status` is `passed`. A `failed` or `unknown` check blocks model creation. Record the blocker; do not allocate capacity, change policy, grant access, create a publisher, create a solution, or otherwise mutate the prerequisite under this sprint.

---

## 5. Create and train `PersonalMasterDataFixed`

In **Power Apps → AI hub → AI models → Extract custom information from documents**, create a **Fixed template documents** model named exactly `PersonalMasterDataFixed`.

Define the fields in the exact order and type from `field-contract.json`:

| BoM ID | Field | AI Builder type |
|---|---|---|
| `BOM-0001-F01` | `candidate_id` | Text |
| `BOM-0001-F02` | `last_name` | Text |
| `BOM-0001-F03` | `first_name` | Text |
| `BOM-0001-F04` | `dob` | Date |
| `BOM-0001-F05` | `nationality` | Text |
| `BOM-0001-F06` | `marital` | Text |
| `BOM-0001-F07` | `heimatort` | Text |
| `BOM-0001-F08` | `permit` | Text |
| `BOM-0001-F09` | `street` | Text |
| `BOM-0001-F10` | `plz` | Text |
| `BOM-0001-F11` | `city` | Text |
| `BOM-0001-F12` | `ahv` | Text |
| `BOM-0001-F13` | `iban` | Text |
| `BOM-0001-F14` | `phone` | Text |
| `BOM-0001-F15` | `email` | Text |
| `BOM-0001-F16` | `ec_name` | Text |
| `BOM-0001-F17` | `ec_phone` | Text |

Names are case-sensitive identifiers. Do not translate them. Keep `plz` and `ahv` as Text. Record the observed model ID, draft version, exact names and types, operator, UTC observation time, and a hashed schema-evidence file with `New-HrAiBuilderModelSchemaRecord`. If the observed schema differs from the contract, correct the draft before uploading training data.

Create these four collections and upload only the training allocation recorded in `run-manifest.json`:

| Collection | Package folder | Training documents |
|---|---|---|
| `Personalblatt` | `a-personalblatt/` | 01–05 |
| `AnmeldungGemeinde` | `b-anmeldung-gemeinde/` | 01–05 |
| `Sozialversicherung` | `c-sozialversicherung/` | 01–05 |
| `Bankverbindung` | `d-bankverbindung/` | 01–05 |

Do not upload, tag, or train on document 06 in any collection. Tag only values that are present in ground truth, train the model, and preserve any platform error. Advance the model record one stage at a time with `Set-HrAiBuilderModelRecord`: `created`, `schema_defined`, `tagged`, then `trained`. Do not publish yet.

---

## 6. Prove machine-readable no-flow capture

Before submitting any held-out document, prove that AI Builder's model test experience, or another approved no-flow mechanism, exposes:

- machine-readable values for all 17 fields;
- numeric per-field confidence for every returned value;
- a retainable raw export;
- exact held-out document identity; and
- a tested, replayable adapter version that reproduces the prediction capture from the retained raw bytes.

Screenshots and manual transcription do not satisfy the evidence contract. Record the result in `model-test-capability.json` with `New-HrAiBuilderTestCapabilityRecord`.

For a passing observation, provide `-MachineReadableValues`, `-PerFieldConfidence`, the retained `-RawExportPath`, and `-AdapterVersion`. The function hashes the raw export. If equivalent structured output is not available, write a blocked record:

```powershell
New-HrAiBuilderTestCapabilityRecord `
    -RunId 't2-dev-20260925-001' `
    -Mechanism 'AI Builder Quick Test' `
    -BlockedReason '<observed reason structured values or confidence cannot be retained>' `
    -OutputPath "$evidenceDirectory\model-test-capability.json"
```

> **STOP — capture-mechanism failure**
>
> If the mechanism cannot produce machine-readable values, per-field confidence, retained raw exports, and replayable adapter evidence, stop before held-out evaluation. Do not transcribe values, infer confidence, or create a Power Automate flow to bridge the gap.

---

## 7. Evaluate fixed results and publish only after a strict-gate pass

Use only the four fixed documents assigned `held-out` in `run-manifest.json`. Retain the raw no-flow exports, then use the tested adapter to import them:

```powershell
.\hr\src\scripts\Import-AiBuilderQuickTestResults.ps1 `
    -RunManifestPath "$evidenceDirectory\run-manifest.json" `
    -ModelSchemaRecordPath "$evidenceDirectory\model-schema-record-fixed.json" `
    -RawExportDirectory "$evidenceDirectory\raw-fixed" `
    -AdapterScriptPath '<approved-replayable-adapter-script>' `
    -TargetModelName 'PersonalMasterDataFixed' `
    -OutputPath "$evidenceDirectory\prediction-capture-fixed.json"

.\hr\src\scripts\Measure-AiBuilderEvaluation.ps1 `
    -RunManifestPath "$evidenceDirectory\run-manifest.json" `
    -CorpusQualityPath "$evidenceDirectory\corpus-quality.json" `
    -FieldContractPath '.\hr\src\ai-builder\contracts\field-contract.json' `
    -ModelSchemaRecordPath "$evidenceDirectory\model-schema-record-fixed.json" `
    -PredictionCapturePath "$evidenceDirectory\prediction-capture-fixed.json" `
    -GroundTruthPath '.\hr\docs\ideas\uc-0001-personal-master-data-completion-agent\gf-aib-fixed-template\ground-truth.json' `
    -EvidenceDirectory $evidenceDirectory
```

The evaluator writes field-level validation, aggregate metrics, confidence distribution, failed gates, and a human-readable summary. A passing model has complete corpus, contract, attribution, held-out input, raw-export, adapter-replay, schema-source, document-field coverage, and zero-false-value evidence. The false-value rate must be zero. Missing, incorrect, or invalid present-field results remain explicit quality findings; do not hide them behind an invented percentage.

Advance the fixed record to `evaluated` only when `evaluation-metrics.json` reports `strict_gate_disposition` as `evaluated`. Publish that evaluated version in AI Builder, then advance it to `published`. If any strict gate fails, advance it to `blocked` and do not publish.

> **STOP — false values**
>
> Any value returned where ground truth is absent blocks the model. Record the field result and failed `zero_false_values` gate. Do not reinterpret the value as a near-match.

> **STOP — consumed holdouts**
>
> If any held-out result influences tagging, retraining, or another model change, the set is consumed. Do not reuse it for acceptance. Create unseen synthetic documents, record new hashes and assignments, and begin a new run.

> **STOP — publish failure**
>
> Retain the evaluation evidence, record the platform failure, and do not mark the model `published`.

---

## 8. Create, train, and evaluate `PersonalMasterDataGeneral`

Create a **General documents** model named exactly `PersonalMasterDataGeneral`. Define the same ordered 17 fields and record the observed schema and hashed source evidence independently.

Upload only the two training documents assigned in each of these eight families: `arbeitsvertrag`, `anschreiben`, `bewilligung`, `versicherung`, `zivilstand`, `selbstdeklaration`, `scan-degraded`, and `new-joiner-sheet`. Do not upload or tag the third document in any family; those eight documents are held out.

Tag only ground-truth values that are visibly present, train the model, and advance its record in sequence through `created`, `schema_defined`, `tagged`, and `trained`.

Using the already proven no-flow capture mechanism:

1. retain raw exports for the eight general held-out documents;
2. run `Import-AiBuilderQuickTestResults.ps1` with `-TargetModelName 'PersonalMasterDataGeneral'`;
3. run `Measure-AiBuilderEvaluation.ps1` with the general schema record, prediction capture, and `gf-aib-general-documents/ground-truth.json`; and
4. inspect the general model entry in `evaluation-metrics.json`.

Advance the record to `evaluated` only when its calculated strict-gate disposition is `evaluated`. Keep fixed and general metrics separate. If a gate fails, record the evidence, mark the general model `blocked`, and do not publish it.

---

## 9. Publish and add only models with passing strict gates

Publish `PersonalMasterDataGeneral` only if its strict-gate disposition is `evaluated`, then advance its record to `published`. Do not publish a blocked model.

Add each published, evaluated model explicitly to the existing unmanaged `caldovahrfrontier` solution. A model is not inferred as a dependency and cannot be added before publication. After each successful add, advance that model to `added_to_solution`.

Training data does not travel with a model executable, and an imported document-processing model cannot be retrained. The committed synthetic packages, review records, file hashes, training assignments, model IDs, and versions therefore remain the reconstruction evidence for this attended DEV build.

> **STOP — solution-add failure**
>
> Retain the published model and all evaluation evidence, record the platform failure, and do not mark the model `added_to_solution`. One completed model does not make the other complete.

---

## 10. Synchronize `caldovahrfrontier`

After the qualifying models are explicit solution components, pull the current unmanaged DEV source:

```powershell
.\hr\src\scripts\Sync-HrSolutionSource.ps1 `
    -TenantAlias 'caldova25668747' `
    -SolutionUniqueName 'caldovahrfrontier'
```

Review the unpacked source and record the synchronized solution version in the evidence. Do not commit a solution ZIP.

If synchronization fails, record the tooling or platform error. Do not claim source parity and do not substitute an exported package for reviewable unpacked source.

---

## 11. Update both BoMs and issue #13 from evidence

When no further model or solution mutation is required, finalize `run-manifest.json` with the observed synchronized solution version and the complete evidence-path list. `Complete-HrAiBuilderRunManifest` derives `technically_complete`, `partially_complete`, or `blocked`; it then makes the run immutable.

Update the [AI Builder Field BoM](./bom-0001-peopledoc-master-data-ai-builder-fields.md) from model-version-specific evidence:

- exact observed field name and type;
- model ID, version, and lifecycle stage;
- contract and strict-gate status; and
- links to the manifest, schema record, evaluation metrics, and summary.

Update the [AI Builder Test BoM](./bom-0002-ai-builder-test-inputs-and-outcomes.md) from run-specific evidence:

- qualified training and held-out inputs;
- raw capture and adapter provenance;
- field-level result counts;
- exact-match accuracy, precision, recall, missing-field precision, false-value rate, and confidence distribution;
- quality findings and failed gates; and
- publication, solution-add, and final run status.

Finally, update [issue #13](https://github.com/urruegg/caldova-hr-frontier/issues/13) with links to the committed evidence and BoM rows. State only what the evidence proves. Do not claim a future automated write-path approval, downstream deployment, or closure of D-11 or D-17.

Completion checks:

- [ ] Only synthetic documents and non-secret platform metadata are present.
- [ ] `readiness.json` is passed.
- [ ] The no-flow capture capability is passed and machine-readable.
- [ ] Every held-out result is attributable and replayable.
- [ ] Each published or solution-added model has a passing strict-gate disposition and zero false values.
- [ ] Consumed holdouts, publish failures, solution-add failures, and synchronization failures remain explicit.
- [ ] `caldovahrfrontier` source, both BoMs, issue #13, and the immutable run manifest agree.
