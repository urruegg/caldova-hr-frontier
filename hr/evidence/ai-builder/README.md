# `hr/evidence/ai-builder/` — AI Builder evaluation evidence

| Field | Value |
|---|---|
| **Version** | 1.1 |
| **Date** | 2026-09-29 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Draft |
| **Scope** | UC-0001 AI Builder evidence contract |
| **References** | [AI Builder Evaluation Capture Design Addendum](../../../docs/superpowers/specs/2026-09-29-ai-builder-evaluation-capture-design.md), [Tenant 2 AI Builder Model Implementation Design](../../../docs/superpowers/specs/2026-09-25-tenant-2-ai-builder-models-design.md), [HR script tooling](../../src/scripts/README.md) |

This folder holds tenant-local evidence for attended AI Builder evaluation runs. The fixed training history and the preserved no-flow blocker remain part of the record; the approved capture path for resumed evaluation is the restricted Power Automate `Process documents` flow described in the addendum.

## Layout

The run root remains portable by tenant, stage, and run ID:

```text
hr/evidence/ai-builder/
└── <tenant-key>/
    └── <environment-stage>/
        └── <run-id>/
            ├── readiness.json
            ├── corpus-quality.json
            ├── model-inventory.json
            ├── run-manifest.json
            ├── model-test-capability.json
            ├── model-evaluation-publication.json
            ├── model-evaluation-published-fixed.png
            ├── prediction-capture-fixed-training-proof.json
            ├── prediction-capture-fixed.json
            ├── validation-results-fixed.csv
            ├── validation-results.json
            ├── evaluation-metrics.json
            └── capture/
                └── <approved-evidence-folder-name>/
                    └── <execution-run-id>/
                        ├── source/<exact-qualified-filename>.pdf
                        ├── <execution-run-id>.ai-builder.raw.json
                        ├── <execution-run-id>.canonical.json
                        └── capture-pair.json
```

`<approved-evidence-folder-name>` comes from `evaluation-capture-intent.json` and must be used unchanged once approved. `<execution-run-id>` is the immutable identifier shared by the source PDF, raw AI Builder response, canonical envelope, and `capture-pair.json`.

## Boundary rules

- **Synthetic data only.** No real PeopleDoc, candidate, pre-hire, worker, or employee documents belong here.
- **Historical blockers stay visible.** The preserved `model-test-capability.json` blocked record remains evidence even after the resumed flow-based path succeeds.
- **Raw and canonical files are immutable.** The source PDF, `.ai-builder.raw.json`, `.canonical.json`, and `capture-pair.json` are retained exactly as written for that execution. Do not overwrite or normalize them in place.
- **No cleanup is implied.** Successful proof, evaluation, approval, or synchronization does not authorize deletion. Cleanup is a separate explicit user decision.
- **Local output is UTF-8 without BOM.** Repository-authored local JSON and Markdown outputs for this capture flow are written as UTF-8 without BOM unless an externally owned platform export dictates otherwise.
- **No invented values.** Prediction values and confidence must come from retained source and raw bytes through a tested adapter. Screenshots supplement evidence only.
- **No secrets or packages.** Do not place credentials, tokens, PAC profiles, solution ZIPs, or deployable artifacts in this tree.

## Command examples

Initialize or resume the tenant-local evidence root:

```powershell
$runId = 't2-dev-20260925-001'
$evidenceDirectory = ".\hr\evidence\ai-builder\tenant-2\DEV\$runId"
```

Run focused adapter and capture-contract tests before claiming capability from a proof capture:

```powershell
powershell.exe -NoProfile -Command "& {
    Import-Module 'C:\Users\anrizzi\OneDrive - Microsoft\Documents\PowerShell\Modules\Pester\5.7.1\Pester.psd1' -Force
    Invoke-Pester -Path 'hr/tests/pester/AiBuilderEvidence.Tests.ps1' -FullNameFilter '*AI Builder evaluation capture schema contracts*'
}"
```

Import retained Power Automate `Process documents` captures through the approved adapter:

Task 7 has not yet implemented `.\hr\src\scripts\adapters\ConvertFrom-HrAiBuilderEvaluationCapture.ps1`. Do not run the import command below until Task 7 creates that exact script and the focused adapter tests pass. If the script is absent or the tests are not green, stop.

```powershell
$adapterScriptPath = '.\hr\src\scripts\adapters\ConvertFrom-HrAiBuilderEvaluationCapture.ps1'

.\hr\src\scripts\Import-AiBuilderQuickTestResults.ps1 `
    -RunManifestPath "$evidenceDirectory\run-manifest.json" `
    -ModelSchemaRecordPath "$evidenceDirectory\model-schema-record-fixed.json" `
    -RawExportDirectory "$evidenceDirectory\capture\<approved-evidence-folder-name>" `
    -AdapterScriptPath $adapterScriptPath `
    -TargetModelName 'PersonalMasterDataFixed' `
    -OutputPath "$evidenceDirectory\prediction-capture-fixed.json"
```

Measure the fixed holdout evaluation from the imported capture:

```powershell
.\hr\src\scripts\Measure-AiBuilderEvaluation.ps1 `
    -RunManifestPath "$evidenceDirectory\run-manifest.json" `
    -CorpusQualityPath "$evidenceDirectory\corpus-quality.json" `
    -FieldContractPath '.\hr\src\ai-builder\contracts\field-contract.json' `
    -ModelSchemaRecordPath "$evidenceDirectory\model-schema-record-fixed.json" `
    -PredictionCapturePath "$evidenceDirectory\prediction-capture-fixed.json" `
    -GroundTruthPath '.\hr\docs\ideas\uc-0001-personal-master-data-completion-agent\gf-aib-fixed-template\ground-truth.json' `
    -EvidenceDirectory $evidenceDirectory
```
