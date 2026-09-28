# `hr/evidence/ai-builder/` — AI Builder evaluation evidence

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-28 |
| **Author** | GitHub Copilot |
| **Status** | Draft |
| **Scope** | UC-0001 AI Builder evidence contract |
| **References** | [Tenant 2 AI Builder Model Implementation Design](../../../docs/superpowers/specs/2026-09-25-tenant-2-ai-builder-models-design.md), [HR script tooling](../../src/scripts/README.md) |

This folder holds the tenant-local evidence for AI Builder held-out evaluation runs. The contract is portable: tenant identity, environment stage, run ID, model attribution, and source hashes are supplied by the run, not embedded into the tooling.

---

## Layout

```text
hr/evidence/ai-builder/
└── <tenant-key>/
    └── <environment-stage>/
        └── <run-id>/
            ├── readiness.json
            ├── corpus-quality.json
            ├── model-inventory.json
            ├── run-manifest.json
            ├── prediction-capture-*.json
            ├── prediction-capture-summary.md
            ├── validation-results-fixed.csv
            ├── validation-results-general.csv
            ├── validation-results.json
            ├── evaluation-metrics.json
            └── evaluation-summary.md
```

`<tenant-key>\<environment-stage>\<run-id>` is the only supported committed path. A completed run is immutable. If the corpus changes, a held-out set is consumed, a model is retrained, or deployment context changes, create a new run ID instead of rewriting evidence in place.

## Boundary rules

- **Synthetic data only.** No real PeopleDoc, candidate, pre-hire, worker, or employee documents belong here.
- **Raw capture is provenance, not authority.** Retained Quick Test exports prove what the tested adapter observed. The repository scripts recalculate hashes, normalize values, classify results, derive gates, and write the authoritative metrics and summaries.
- **Replayable adapter contract required.** A prediction capture is valid only when the retained raw-export bytes can reproduce the same field values and confidence through a tested replayable adapter. Unsupported raw-export formats are blocked in this increment by design.
- **No secrets or packages.** Do not place credentials, tokens, PAC profiles, solution ZIPs, or any other deployable artifact in this tree.
- **No invented values.** Prediction values and confidence must come from the retained raw export through a tested adapter. Hand-authored values or confidence are invalid evidence.
- **Blocked imports stay visible.** Import failures write `prediction-capture-summary.md` and preserve `*.blocked.json` when the adapter emitted an invalid capture.

## Command examples

Initialize a new evidence run:

```powershell
.\hr\src\scripts\Initialize-AiBuilderEvidenceRun.ps1 `
    -RunId 'tenant2-dev-2026-09-28-a' `
    -TenantKey 'tenant-2' `
    -EnvironmentId ([guid]'84ad4c54-41d9-e5df-ba07-188b4719594a') `
    -EnvironmentStage DEV `
    -SolutionUniqueName 'caldovahrfrontier' `
    -SolutionVersion '0.0.0.1' `
    -OperatorUpn 'admin@caldova25668747.onmicrosoft.com' `
    -OutputDirectory '.\hr\evidence\ai-builder\tenant-2\DEV\tenant2-dev-2026-09-28-a'
```

Import retained Quick Test exports through a tested adapter:

```powershell
.\hr\src\scripts\Import-AiBuilderQuickTestResults.ps1 `
    -RunManifestPath '.\hr\evidence\ai-builder\tenant-2\DEV\tenant2-dev-2026-09-28-a\run-manifest.json' `
    -ModelSchemaRecordPath '.\hr\evidence\ai-builder\tenant-2\DEV\tenant2-dev-2026-09-28-a\model-schema-record-fixed.json' `
    -RawExportDirectory '.\hr\evidence\ai-builder\tenant-2\DEV\tenant2-dev-2026-09-28-a\raw-fixed' `
    -AdapterScriptPath '.\hr\src\scripts\adapters\ConvertFrom-HrAiBuilderQuickTestExport.ps1' `
    -TargetModelName 'PersonalMasterDataFixed' `
    -OutputPath '.\hr\evidence\ai-builder\tenant-2\DEV\tenant2-dev-2026-09-28-a\prediction-capture-fixed.json'
```

Measure the held-out evaluation and derive strict gates:

```powershell
.\hr\src\scripts\Measure-AiBuilderEvaluation.ps1 `
    -RunManifestPath '.\hr\evidence\ai-builder\tenant-2\DEV\tenant2-dev-2026-09-28-a\run-manifest.json' `
    -CorpusQualityPath '.\hr\evidence\ai-builder\tenant-2\DEV\tenant2-dev-2026-09-28-a\corpus-quality.json' `
    -FieldContractPath '.\hr\src\ai-builder\contracts\field-contract.json' `
    -ModelSchemaRecordPath '.\hr\evidence\ai-builder\tenant-2\DEV\tenant2-dev-2026-09-28-a\model-schema-record-fixed.json' `
    -PredictionCapturePath '.\hr\evidence\ai-builder\tenant-2\DEV\tenant2-dev-2026-09-28-a\prediction-capture-fixed.json' `
    -GroundTruthPath '.\hr\docs\ideas\uc-0001-personal-master-data-completion-agent\gf-aib-fixed-template\ground-truth.json' `
    -EvidenceDirectory '.\hr\evidence\ai-builder\tenant-2\DEV\tenant2-dev-2026-09-28-a'
```
