# `hr/src/scripts/` — Power Platform solution lifecycle tooling

| Field | Value |
|---|---|
| **Version** | 1.1 |
| **Date** | 2026-09-29 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | HR Solution Architecture |
| **References** | [Power Platform Solution Foundation Design](../../../docs/specs/2026-09-24-power-platform-solution-foundation-design.md), [AI Builder Evaluation Capture Design Addendum](../../../docs/superpowers/specs/2026-09-29-ai-builder-evaluation-capture-design.md), [AI Builder evidence contract](../../evidence/ai-builder/README.md) |

**Purpose.** Connects to a tenant's Power Platform environment, pulls its Dataverse solution into source control, and supports the local evidence toolchain used to qualify and evaluate AI Builder models.

## What is here

| Path | Purpose |
|---|---|
| `Connect-PowerPlatformEnvironment.ps1` | Verifies (and if needed, creates) an authenticated PAC CLI profile for a tenant/stage. Useful standalone to check connectivity before running anything else. |
| `Sync-HrSolutionSource.ps1` | Exports a named solution's unmanaged package from a tenant's **DEV environment only**, unpacks it into `hr/src/solutions/<SolutionUniqueName>/`, and cleans up the temporary zip. |
| `Initialize-AiBuilderEvidenceRun.ps1` | Initializes a tenant-local AI Builder evidence run, creates required visual-review templates on first use, and writes qualified corpus plus run-manifest evidence only after both corpora pass the strict gate. |
| `Import-AiBuilderQuickTestResults.ps1` | Legacy script name retained for compatibility; the production capture contract now imports retained Power Automate `Process documents` evidence through an approved replay adapter. |
| `Measure-AiBuilderEvaluation.ps1` | Converts imported captures into results, metrics, lifecycle decisions, and strict-gate evidence. |
| `modules/Caldova.HrFrontier.Solutions/` | Shared solution-export module. |
| `modules/Caldova.HrFrontier.AiBuilder/` | Corpus qualification, readiness, lifecycle, capture-contract, and evaluation helpers for the AI Builder workstream. |

## Usage

```powershell
# Verify connectivity to Tenant 2 DEV
.\Connect-PowerPlatformEnvironment.ps1 -TenantAlias caldova25668747 -Stage Dev

# Pull the current state of the solution into source control
.\Sync-HrSolutionSource.ps1 -TenantAlias caldova25668747 -SolutionUniqueName caldovahrfrontier
```

The first run for a tenant prompts an interactive Microsoft Entra ID sign-in. No service-principal or CI credential path exists yet.

## AI Builder evidence tooling

`Initialize-AiBuilderEvidenceRun.ps1` remains **evidence-only**. It does not create a model, upload documents, or change a tenant prerequisite. Its job is to:

1. create the fixed and general visual-review templates for the committed synthetic corpora;
2. stop until a human confirms that visible values and deliberate absences match the controlled ground truth; and
3. qualify both corpora, derive corpus and generator revisions, and create `corpus-quality.json`, `run-manifest.json`, and `model-inventory.json` only when both packages pass.

The attended evaluation-capture flow stores its immutable per-execution outputs under the run root with this layout:

```text
capture/
└── <approved-evidence-folder-name>/
    └── <execution-run-id>/
        ├── source/<exact-qualified-filename>.pdf
        ├── <execution-run-id>.ai-builder.raw.json
        ├── <execution-run-id>.canonical.json
        └── capture-pair.json
```

`<approved-evidence-folder-name>` comes from `evaluation-capture-intent.json`. The source PDF, raw response, canonical envelope, and `capture-pair.json` are immutable once written. No cleanup is implied, and repository-authored local outputs are UTF-8 without BOM.

Run focused local capture-contract tests before using a proof capture:

```powershell
powershell.exe -NoProfile -Command "& {
    Import-Module 'C:\Users\anrizzi\OneDrive - Microsoft\Documents\PowerShell\Modules\Pester\5.7.1\Pester.psd1' -Force
    Invoke-Pester -Path 'hr/tests/pester/AiBuilderEvidence.Tests.ps1' -FullNameFilter '*AI Builder evaluation capture schema contracts*'
}"
```

Import retained Power Automate `Process documents` captures through the approved adapter:

Task 7 has not yet implemented `.\hr\src\scripts\adapters\ConvertFrom-HrAiBuilderEvaluationCapture.ps1`. Do not run the import command below until Task 7 creates that exact script and the focused adapter tests pass. If the script is absent or the tests are not green, stop.

```powershell
$runId = 't2-dev-20260925-001'
$evidenceDirectory = ".\hr\evidence\ai-builder\tenant-2\DEV\$runId"
$adapterScriptPath = '.\hr\src\scripts\adapters\ConvertFrom-HrAiBuilderEvaluationCapture.ps1'

.\Import-AiBuilderQuickTestResults.ps1 `
    -RunManifestPath "$evidenceDirectory\run-manifest.json" `
    -ModelSchemaRecordPath "$evidenceDirectory\model-schema-record-fixed.json" `
    -RawExportDirectory "$evidenceDirectory\capture\<approved-evidence-folder-name>" `
    -AdapterScriptPath $adapterScriptPath `
    -TargetModelName 'PersonalMasterDataFixed' `
    -OutputPath "$evidenceDirectory\prediction-capture-fixed.json"
```

Measure the fixed holdout evaluation:

```powershell
.\Measure-AiBuilderEvaluation.ps1 `
    -RunManifestPath "$evidenceDirectory\run-manifest.json" `
    -CorpusQualityPath "$evidenceDirectory\corpus-quality.json" `
    -FieldContractPath '.\hr\src\ai-builder\contracts\field-contract.json' `
    -ModelSchemaRecordPath "$evidenceDirectory\model-schema-record-fixed.json" `
    -PredictionCapturePath "$evidenceDirectory\prediction-capture-fixed.json" `
    -GroundTruthPath '.\hr\docs\ideas\uc-0001-personal-master-data-completion-agent\gf-aib-fixed-template\ground-truth.json' `
    -EvidenceDirectory $evidenceDirectory
```

The evidence boundary remains under `hr/evidence/ai-builder/<tenant-key>/<environment-stage>/<run-id>/`. Use only synthetic values and non-secret platform metadata.

## Why export is DEV-only

`Export-HrSolutionPackage` does not accept a `-Stage` parameter. Managed solutions for TEST and PROD are produced by a deployment pipeline from the committed DEV source — never hand-exported from those environments.

## What this does not do (yet)

- **No push path.** These scripts only pull solution state into source control.
- **No automatic tenant mutation.** Model creation, publication, flow authoring, and attended evaluation remain portal operations with explicit approval points.
- **No production data handling.** The AI Builder evidence path is synthetic-only.
