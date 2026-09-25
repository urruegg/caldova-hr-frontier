# Tenant 2 AI Builder Model Sprint Implementation Plan

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-25 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Draft |
| **Scope** | HR Solution Architecture - Tenant 2 DEV AI Builder sprint |
| **References** | [Tenant 2 AI Builder Model Implementation Design](../specs/2026-09-25-tenant-2-ai-builder-models-design.md) |

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create, train, evaluate, publish, and solution-package the `PersonalMasterDataFixed` and `PersonalMasterDataGeneral` AI Builder models in Tenant 2 DEV with portable, machine-readable evidence and fully traceable field and test BoMs.

**Architecture:** A tenant-neutral PowerShell module validates the synthetic corpora, creates the run manifest, normalizes captured predictions, calculates metrics, and enforces strict safety gates. Model creation, tagging, training, testing, publication, and solution addition remain attended AI Builder operations because AI Builder authoring is portal-based. Every attended result is linked to the local evidence toolchain through one run ID; Tenant 2 deployment context appears only in the run manifest.

**Tech Stack:** PowerShell 5.1+, Pester 5.7.1, Microsoft Power Platform CLI (`pac`), AI Builder maker portal, JSON, CSV, Markdown, GitHub CLI (`gh`), and the existing deterministic Python/ReportLab document generators.

**Spec:** [`docs/superpowers/specs/2026-09-25-tenant-2-ai-builder-models-design.md`](../specs/2026-09-25-tenant-2-ai-builder-models-design.md)

## Global Constraints

- Implement Tenant 2 DEV only. Do not change Tenant 1, Tenant 3, TEST, or PROD.
- Use tenant alias `caldova25668747`, logical tenant key `tenant-2`, DEV environment ID `84ad4c54-41d9-e5df-ba07-188b4719594a`, and solution unique name `caldovahrfrontier`.
- Read the attended administrator identity from `infra/src/config/tenants/caldova25668747.psd1`; never commit credentials, tokens, or connection values.
- Create exactly two tenant-local models: `PersonalMasterDataFixed` and `PersonalMasterDataGeneral`.
- Both models expose exactly the 17 fields and types defined in the design and `BOM-0001-F01` through `BOM-0001-F17`.
- Use only the supplied synthetic PDFs and ground truth. Do not upload or commit real employee, candidate, pre-hire, worker, or PeopleDoc documents.
- Do not create a Power Automate flow, Copilot Studio agent, SharePoint connection, Workday connection, Dataverse process table, publisher, solution, or cross-tenant dependency.
- Treat corpus integrity, exact contract compatibility, evidence attribution, and zero false values for expected-absent fields as strict gates.
- Record present-field extraction mismatches as findings. Do not use fuzzy matching, semantic matching, punctuation removal, phone reformatting, or vocabulary substitution.
- Do not invent an extraction pass percentage. The first run establishes the baseline; D-11 and D-17 remain open.
- A held-out document that influences tuning is consumed. Generate and hash a new unseen acceptance document before retesting the affected collection or family.
- Do not publish or add a model to the solution until corpus, contract, attribution, and zero-false-value gates pass.
- A published model is evaluated, not approved for a future automated write path.
- Tenant and environment identity belongs in `run-manifest.json`; field-level results reference it through `run_id`.
- Screenshots may supplement evidence but never replace machine-readable field values and per-field confidence.
- If AI Builder Quick Test cannot expose complete structured values and confidence without a flow, record the blocker and stop. Do not bypass the approved no-flow scope.
- Do not commit exported solution ZIP files. Use the existing solution synchronization script to unpack the DEV solution into `hr/src/solutions/caldovahrfrontier/`.
- Update the field BoM and test BoM only from model-version and run-specific evidence.
- Every repository-owned Markdown file created or rewritten carries the required six-field metadata table and follows the conditional Mermaid policy in `docs/README.md`.
- Use test-driven development for every local script or module behavior: write a failing Pester test, verify the expected failure, implement the minimum behavior, and verify green before committing.
- Include `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>` in every implementation commit.

## File Structure

The sprint creates or changes the following units:

| Path | Responsibility |
|---|---|
| `hr/src/ai-builder/contracts/field-contract.json` | Portable machine-readable 17-field contract and BoM mapping |
| `hr/src/ai-builder/contracts/prediction-capture.schema.json` | Exact shape required from structured AI Builder result capture |
| `hr/src/scripts/modules/Caldova.HrFrontier.AiBuilder/` | Reusable corpus, manifest, normalization, metric, and strict-gate functions |
| `hr/src/scripts/Initialize-AiBuilderEvidenceRun.ps1` | Creates corpus-review templates, validates qualified inputs, and writes the run manifest |
| `hr/src/scripts/Measure-AiBuilderEvaluation.ps1` | Converts captured predictions into results, metrics, gates, and summary evidence |
| `hr/tests/pester/AiBuilderEvidence.Tests.ps1` | Unit and contract tests for all local AI Builder evidence behavior |
| `hr/evidence/ai-builder/README.md` | Evidence layout, retention boundary, and operator instructions |
| `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/` | First Tenant 2 DEV run evidence |
| `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/ai-builder-model-setup.md` | Attended operator procedure reconciled to the approved design |
| `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/gf-aib-fixed-template/` | Versioned fixed-template synthetic corpus |
| `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/gf-aib-general-documents/` | Versioned general-document synthetic corpus |
| `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/bom-0001-peopledoc-master-data-ai-builder-fields.md` | Field lifecycle status updated from evidence |
| `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/bom-0002-ai-builder-test-inputs-and-outcomes.md` | Run input and outcome summary updated from evidence |
| `hr/src/solutions/caldovahrfrontier/` | Unpacked solution source after the evaluated models are added |

---

### Task 1: Version the corpus and establish the machine-readable field contract

**Files:**
- Create: `hr/src/ai-builder/contracts/field-contract.json`
- Create: `hr/tests/pester/AiBuilderEvidence.Tests.ps1`
- Add: `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/gf-aib-fixed-template/`
- Add: `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/gf-aib-general-documents/`
- Modify: `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/gf-aib-fixed-template/README.md`
- Modify: `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/gf-aib-general-documents/README.md`

**Interfaces:**
- Produces: `field-contract.json` with `contract_version`, `field_count`, and ordered `fields`.
- Produces: each field object with `bom_id`, `name`, `ai_builder_type`, and `normalization`.
- Produces: two tracked 24-document packages with one-to-one CSV/JSON ground truth.
- Consumed by: Tasks 2, 3, 5, 6, and 7.

- [ ] **Step 1: Write the failing field and corpus contract tests**

Create `hr/tests/pester/AiBuilderEvidence.Tests.ps1`:

```powershell
Set-StrictMode -Version Latest

Describe 'AI Builder field and corpus contracts' {
    BeforeAll {
        $script:RepositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
        $script:ContractPath = Join-Path $script:RepositoryRoot 'hr\src\ai-builder\contracts\field-contract.json'
        $script:UseCaseRoot = Join-Path $script:RepositoryRoot 'hr\docs\ideas\uc-0001-personal-master-data-completion-agent'
        $script:ExpectedFields = @(
            'candidate_id', 'last_name', 'first_name', 'dob', 'nationality',
            'marital', 'heimatort', 'permit', 'street', 'plz', 'city', 'ahv',
            'iban', 'phone', 'email', 'ec_name', 'ec_phone'
        )
    }

    It 'defines the ordered 17-field contract and stable BoM IDs' {
        $script:ContractPath | Should -Exist
        $contract = Get-Content -LiteralPath $script:ContractPath -Raw | ConvertFrom-Json

        $contract.field_count | Should -Be 17
        @($contract.fields.name) | Should -Be $script:ExpectedFields
        @($contract.fields.bom_id) | Should -Be @(
            1..17 | ForEach-Object { 'BOM-0001-F{0:d2}' -f $_ }
        )
        @($contract.fields | Where-Object name -eq 'dob').ai_builder_type | Should -Be 'Date'
        @($contract.fields | Where-Object name -in @('plz', 'ahv')).ai_builder_type |
            Should -Be @('Text', 'Text')
    }

    It 'contains 24 fixed PDFs and matching ground-truth rows' {
        $root = Join-Path $script:UseCaseRoot 'gf-aib-fixed-template'
        $truth = Get-Content -LiteralPath (Join-Path $root 'ground-truth.json') -Raw | ConvertFrom-Json
        $pdfs = @(Get-ChildItem -LiteralPath (Join-Path $root 'documents') -Filter '*.pdf' -Recurse)

        $pdfs.Count | Should -Be 24
        @($truth.documents).Count | Should -Be 24
        @($truth.documents.document | Sort-Object) |
            Should -Be @($pdfs.Name | Sort-Object)
    }

    It 'contains 24 general PDFs and matching ground-truth rows' {
        $root = Join-Path $script:UseCaseRoot 'gf-aib-general-documents'
        $truth = Get-Content -LiteralPath (Join-Path $root 'ground-truth.json') -Raw | ConvertFrom-Json
        $pdfs = @(Get-ChildItem -LiteralPath (Join-Path $root 'documents') -Filter '*.pdf' -Recurse)

        $pdfs.Count | Should -Be 24
        @($truth.documents).Count | Should -Be 24
        @($truth.documents.document | Sort-Object) |
            Should -Be @($pdfs.Name | Sort-Object)
    }
}
```

- [ ] **Step 2: Run the contract tests and verify red**

Run:

```powershell
Import-Module Pester -RequiredVersion 5.7.1 -Force
Invoke-Pester -Path hr/tests/pester/AiBuilderEvidence.Tests.ps1 -Output Detailed
```

Expected: FAIL because `hr/src/ai-builder/contracts/field-contract.json` does not exist.

- [ ] **Step 3: Create the portable field contract**

Create `hr/src/ai-builder/contracts/field-contract.json`:

```json
{
  "schema_version": "1.0",
  "contract_version": "0.1",
  "field_count": 17,
  "fields": [
    { "bom_id": "BOM-0001-F01", "name": "candidate_id", "ai_builder_type": "Text", "normalization": "text" },
    { "bom_id": "BOM-0001-F02", "name": "last_name", "ai_builder_type": "Text", "normalization": "text" },
    { "bom_id": "BOM-0001-F03", "name": "first_name", "ai_builder_type": "Text", "normalization": "text" },
    { "bom_id": "BOM-0001-F04", "name": "dob", "ai_builder_type": "Date", "normalization": "date_ddMMyyyy" },
    { "bom_id": "BOM-0001-F05", "name": "nationality", "ai_builder_type": "Text", "normalization": "text" },
    { "bom_id": "BOM-0001-F06", "name": "marital", "ai_builder_type": "Text", "normalization": "text" },
    { "bom_id": "BOM-0001-F07", "name": "heimatort", "ai_builder_type": "Text", "normalization": "text" },
    { "bom_id": "BOM-0001-F08", "name": "permit", "ai_builder_type": "Text", "normalization": "text" },
    { "bom_id": "BOM-0001-F09", "name": "street", "ai_builder_type": "Text", "normalization": "text" },
    { "bom_id": "BOM-0001-F10", "name": "plz", "ai_builder_type": "Text", "normalization": "text" },
    { "bom_id": "BOM-0001-F11", "name": "city", "ai_builder_type": "Text", "normalization": "text" },
    { "bom_id": "BOM-0001-F12", "name": "ahv", "ai_builder_type": "Text", "normalization": "text" },
    { "bom_id": "BOM-0001-F13", "name": "iban", "ai_builder_type": "Text", "normalization": "text" },
    { "bom_id": "BOM-0001-F14", "name": "phone", "ai_builder_type": "Text", "normalization": "text" },
    { "bom_id": "BOM-0001-F15", "name": "email", "ai_builder_type": "Text", "normalization": "text" },
    { "bom_id": "BOM-0001-F16", "name": "ec_name", "ai_builder_type": "Text", "normalization": "text" },
    { "bom_id": "BOM-0001-F17", "name": "ec_phone", "ai_builder_type": "Text", "normalization": "text" }
  ]
}
```

- [ ] **Step 4: Reconcile the package claims with the approved design**

In both package READMEs:

- replace “approved field list” with “designed 17-field contract” because the GF field workbook is not present;
- remove the fixed-template “above ~95%” expectation;
- state that the first run establishes a measured baseline;
- retain the strict zero-false-value rule;
- state that held-out documents become consumed if their results influence tuning.

- [ ] **Step 5: Run the contract and documentation tests**

Run:

```powershell
Import-Module Pester -RequiredVersion 5.7.1 -Force
Invoke-Pester -Path @(
    'hr/tests/pester/AiBuilderEvidence.Tests.ps1',
    '.github/cli/tests/DocumentationMetadata.Tests.ps1',
    '.github/cli/tests/DocumentationLinks.Tests.ps1'
) -Output Detailed
```

Expected: all tests pass; fixed and general package counts are 24 each.

- [ ] **Step 6: Commit the controlled corpus and contract**

```powershell
git add hr/src/ai-builder/contracts/field-contract.json `
    hr/tests/pester/AiBuilderEvidence.Tests.ps1 `
    hr/docs/ideas/uc-0001-personal-master-data-completion-agent/gf-aib-fixed-template `
    hr/docs/ideas/uc-0001-personal-master-data-completion-agent/gf-aib-general-documents
git commit -m "feat: version AI Builder corpus contract" `
    -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 2: Build corpus qualification, readiness, and run-manifest tooling

**Files:**
- Create: `hr/src/scripts/modules/Caldova.HrFrontier.AiBuilder/Caldova.HrFrontier.AiBuilder.psd1`
- Create: `hr/src/scripts/modules/Caldova.HrFrontier.AiBuilder/Caldova.HrFrontier.AiBuilder.psm1`
- Create: `hr/src/scripts/modules/Caldova.HrFrontier.AiBuilder/Private/Get-HrAiBuilderFileSha256.ps1`
- Create: `hr/src/scripts/modules/Caldova.HrFrontier.AiBuilder/Public/Get-HrAiBuilderFieldContract.ps1`
- Create: `hr/src/scripts/modules/Caldova.HrFrontier.AiBuilder/Public/New-HrAiBuilderCorpusReviewTemplate.ps1`
- Create: `hr/src/scripts/modules/Caldova.HrFrontier.AiBuilder/Public/Test-HrAiBuilderCorpus.ps1`
- Create: `hr/src/scripts/modules/Caldova.HrFrontier.AiBuilder/Public/New-HrAiBuilderRunManifest.ps1`
- Create: `hr/src/scripts/modules/Caldova.HrFrontier.AiBuilder/Public/Set-HrAiBuilderModelRecord.ps1`
- Create: `hr/src/scripts/modules/Caldova.HrFrontier.AiBuilder/Public/Complete-HrAiBuilderRunManifest.ps1`
- Create: `hr/src/scripts/modules/Caldova.HrFrontier.AiBuilder/Public/New-HrAiBuilderReadinessRecord.ps1`
- Create: `hr/src/scripts/modules/Caldova.HrFrontier.AiBuilder/Public/New-HrAiBuilderTestCapabilityRecord.ps1`
- Create: `hr/src/scripts/Initialize-AiBuilderEvidenceRun.ps1`
- Modify: `hr/tests/pester/AiBuilderEvidence.Tests.ps1`
- Modify: `hr/src/scripts/README.md`

**Interfaces:**
- Produces: `Get-HrAiBuilderFieldContract -Path [string]` -> ordered field objects.
- Produces: `New-HrAiBuilderCorpusReviewTemplate -PackagePath [string] -OutputPath [string]` -> review JSON with one record per document.
- Produces: `Test-HrAiBuilderCorpus -PackagePath [string] -ModelKind Fixed|General -ReviewPath [string] -FieldContractPath [string]` -> corpus result with `passed`, `documents`, `field_coverage`, and `errors`.
- Produces: `New-HrAiBuilderRunManifest` -> portable `run-manifest.json`.
- Produces: `Set-HrAiBuilderModelRecord` -> atomically updates one known model in `run-manifest.json` and `model-inventory.json`.
- Produces: `Complete-HrAiBuilderRunManifest` -> records final status and evidence hashes, then prevents further mutation.
- Produces: `New-HrAiBuilderReadinessRecord` -> `readiness.json`, including blocked evidence when any gate fails.
- Produces: `New-HrAiBuilderTestCapabilityRecord` -> `model-test-capability.json`.
- Consumed by: Tasks 3, 5, 6, 7, and 8.

- [ ] **Step 1: Add failing tests for review, corpus, manifest, and stop behavior**

Append these `Describe` blocks to `hr/tests/pester/AiBuilderEvidence.Tests.ps1`:

```powershell
Describe 'AI Builder corpus qualification' {
    BeforeAll {
        $script:ModulePath = Join-Path $PSScriptRoot '..\..\src\scripts\modules\Caldova.HrFrontier.AiBuilder\Caldova.HrFrontier.AiBuilder.psd1'
        Import-Module $script:ModulePath -Force
        $script:RepositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
        $script:ContractPath = Join-Path $script:RepositoryRoot 'hr\src\ai-builder\contracts\field-contract.json'
        $script:FixedPath = Join-Path $script:RepositoryRoot 'hr\docs\ideas\uc-0001-personal-master-data-completion-agent\gf-aib-fixed-template'
    }

    It 'creates one pending visual review record per document' {
        $reviewPath = Join-Path $TestDrive 'fixed-review.json'

        New-HrAiBuilderCorpusReviewTemplate -PackagePath $script:FixedPath -OutputPath $reviewPath
        $review = Get-Content -LiteralPath $reviewPath -Raw | ConvertFrom-Json

        @($review.documents).Count | Should -Be 24
        @($review.documents | Where-Object status -eq 'pending').Count | Should -Be 24
    }

    It 'blocks a corpus while any visual review is pending' {
        $reviewPath = Join-Path $TestDrive 'fixed-review.json'
        New-HrAiBuilderCorpusReviewTemplate -PackagePath $script:FixedPath -OutputPath $reviewPath

        $result = Test-HrAiBuilderCorpus -PackagePath $script:FixedPath -ModelKind Fixed `
            -ReviewPath $reviewPath -FieldContractPath $script:ContractPath

        $result.passed | Should -BeFalse
        $result.errors | Should -Contain 'Visual review is incomplete.'
    }

    It 'assigns 20 fixed documents to training and 4 to held-out' {
        $reviewPath = Join-Path $TestDrive 'fixed-review.json'
        New-HrAiBuilderCorpusReviewTemplate -PackagePath $script:FixedPath -OutputPath $reviewPath
        $review = Get-Content -LiteralPath $reviewPath -Raw | ConvertFrom-Json
        foreach ($document in $review.documents) {
            $document.status = 'confirmed'
            $document.values_visible = $true
            $document.absences_confirmed = $true
            $document.reviewer = 'test-reviewer'
        }
        $review | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $reviewPath -Encoding UTF8

        $result = Test-HrAiBuilderCorpus -PackagePath $script:FixedPath -ModelKind Fixed `
            -ReviewPath $reviewPath -FieldContractPath $script:ContractPath

        $result.passed | Should -BeTrue
        @($result.documents | Where-Object assignment -eq 'training').Count | Should -Be 20
        @($result.documents | Where-Object assignment -eq 'held-out').Count | Should -Be 4
        @($result.documents | Where-Object { $_.sha256 -notmatch '^[a-f0-9]{64}$' }).Count | Should -Be 0
    }
}

Describe 'AI Builder run and readiness evidence' {
    BeforeAll {
        $script:ModulePath = Join-Path $PSScriptRoot '..\..\src\scripts\modules\Caldova.HrFrontier.AiBuilder\Caldova.HrFrontier.AiBuilder.psd1'
        Import-Module $script:ModulePath -Force
    }

    It 'keeps deployment context in the manifest rather than field results' {
        $path = Join-Path $TestDrive 'run-manifest.json'
        $inventoryPath = Join-Path $TestDrive 'model-inventory.json'
        New-HrAiBuilderRunManifest -RunId 'test-run-001' -TenantKey 'tenant-2' `
            -EnvironmentId '84ad4c54-41d9-e5df-ba07-188b4719594a' -EnvironmentStage DEV `
            -SolutionUniqueName 'caldovahrfrontier' -SolutionVersion '0.0.0.1' `
            -FieldContractVersion '0.1' -Models @(
                [pscustomobject]@{ display_name = 'PersonalMasterDataFixed'; model_kind = 'Fixed' }
            ) -CorpusResults @() -OutputPath $path -ModelInventoryPath $inventoryPath

        $manifest = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
        $manifest.tenant_key | Should -Be 'tenant-2'
        $manifest.power_platform_environment_id | Should -Be '84ad4c54-41d9-e5df-ba07-188b4719594a'
        $manifest.environment_stage | Should -Be 'DEV'
    }

    It 'writes blocked readiness evidence instead of returning success-shaped output' {
        $path = Join-Path $TestDrive 'readiness.json'
        $result = New-HrAiBuilderReadinessRecord -RunId 'test-run-001' `
            -EnvironmentVerified -DataverseVerified -MakerAuthorized `
            -AiBuilderAvailable:$false -CapacityAvailable:$false `
            -DataPolicyCompatible -SolutionVerified -PublisherVerified `
            -OutputPath $path

        $result.status | Should -Be 'blocked'
        $result.failed_gates | Should -Contain 'ai_builder_available'
        $result.failed_gates | Should -Contain 'capacity_available'
        $path | Should -Exist
    }

    It 'records a blocked no-flow test mechanism explicitly' {
        $path = Join-Path $TestDrive 'model-test-capability.json'
        $result = New-HrAiBuilderTestCapabilityRecord -RunId 'test-run-001' `
            -Mechanism 'AI Builder Quick Test' `
            -BlockedReason 'No machine-readable confidence export is available.' `
            -OutputPath $path

        $result.status | Should -Be 'blocked'
        $result.machine_readable_values | Should -BeFalse
        $result.per_field_confidence | Should -BeFalse
    }

    It 'records a known model and rejects an unknown model name' {
        $manifestPath = Join-Path $TestDrive 'run-manifest.json'
        $inventoryPath = Join-Path $TestDrive 'model-inventory.json'
        New-HrAiBuilderRunManifest -RunId 'test-run-001' -TenantKey 'tenant-2' `
            -EnvironmentId '84ad4c54-41d9-e5df-ba07-188b4719594a' -EnvironmentStage DEV `
            -SolutionUniqueName 'caldovahrfrontier' -SolutionVersion '0.0.0.1' `
            -FieldContractVersion '0.1' -Models @(
                [pscustomobject]@{ display_name = 'PersonalMasterDataFixed'; model_kind = 'Fixed' }
            ) -CorpusResults @() -OutputPath $manifestPath -ModelInventoryPath $inventoryPath

        Set-HrAiBuilderModelRecord -RunManifestPath $manifestPath `
            -ModelInventoryPath $inventoryPath -ModelName 'PersonalMasterDataFixed' `
            -ModelId 'model-fixed-001' -ModelVersion '1' -LifecycleStage 'trained'

        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
        @($manifest.models | Where-Object display_name -eq 'PersonalMasterDataFixed').version |
            Should -Be '1'
        {
            Set-HrAiBuilderModelRecord -RunManifestPath $manifestPath `
                -ModelInventoryPath $inventoryPath -ModelName 'UnknownModel' `
                -ModelId 'unknown' -ModelVersion '1' -LifecycleStage 'trained'
        } | Should -Throw '*Unknown model*'
    }

    It 'finalizes a run once and refuses later mutation' {
        $manifestPath = Join-Path $TestDrive 'run-manifest.json'
        $inventoryPath = Join-Path $TestDrive 'model-inventory.json'
        $evidencePath = Join-Path $TestDrive 'evidence.json'
        '{}' | Set-Content -LiteralPath $evidencePath -Encoding UTF8
        New-HrAiBuilderRunManifest -RunId 'test-run-001' -TenantKey 'tenant-2' `
            -EnvironmentId '84ad4c54-41d9-e5df-ba07-188b4719594a' -EnvironmentStage DEV `
            -SolutionUniqueName 'caldovahrfrontier' -SolutionVersion '0.0.0.1' `
            -FieldContractVersion '0.1' -Models @(
                [pscustomobject]@{ display_name = 'PersonalMasterDataFixed'; model_kind = 'Fixed' }
            ) -CorpusResults @() -OutputPath $manifestPath -ModelInventoryPath $inventoryPath

        Complete-HrAiBuilderRunManifest -Path $manifestPath -OverallStatus blocked `
            -EvidencePaths @($evidencePath)

        {
            Complete-HrAiBuilderRunManifest -Path $manifestPath -OverallStatus blocked `
                -EvidencePaths @($evidencePath)
        } | Should -Throw '*already finalized*'
    }
}
```

- [ ] **Step 2: Run the new tests and verify red**

Run:

```powershell
Import-Module Pester -RequiredVersion 5.7.1 -Force
Invoke-Pester -Path hr/tests/pester/AiBuilderEvidence.Tests.ps1 -Output Detailed
```

Expected: FAIL because the `Caldova.HrFrontier.AiBuilder` module does not exist.

- [ ] **Step 3: Create the module manifest and loader**

Create the manifest with PowerShell 5.1 compatibility and export exactly:

```powershell
FunctionsToExport = @(
    'Get-HrAiBuilderFieldContract',
    'New-HrAiBuilderCorpusReviewTemplate',
    'Test-HrAiBuilderCorpus',
    'New-HrAiBuilderRunManifest',
    'Set-HrAiBuilderModelRecord',
    'Complete-HrAiBuilderRunManifest',
    'New-HrAiBuilderReadinessRecord',
    'New-HrAiBuilderTestCapabilityRecord'
)
```

Use the same `Private/` then `Public/` dot-source loader pattern as `Caldova.HrFrontier.Solutions.psm1`.

- [ ] **Step 4: Implement hashing and field-contract loading**

`Get-HrAiBuilderFileSha256.ps1` must use:

```powershell
(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
```

`Get-HrAiBuilderFieldContract` must throw when the file is missing, malformed, not ordered, not 17 fields, or contains duplicate names or BoM IDs. It returns `@($contract.fields)`.

- [ ] **Step 5: Implement review-template and corpus qualification**

`New-HrAiBuilderCorpusReviewTemplate` writes:

```json
{
  "schema_version": "1.0",
  "package": "fixed-template",
  "documents": [
    {
      "document": "a01-CAND-2026-0411-brunner.pdf",
      "status": "pending",
      "values_visible": false,
      "absences_confirmed": false,
      "reviewer": "",
      "notes": ""
    }
  ]
}
```

`Test-HrAiBuilderCorpus` must:

1. load `ground-truth.json` and `ground-truth.csv`;
2. require exactly one ground-truth row per PDF and no duplicate document names;
3. require every contract field in every ground-truth row;
4. require every review row to be `confirmed`, both booleans true, and reviewer non-empty;
5. assign fixed documents ending in `01` through `05` within each collection to `training` and `06` to `held-out`;
6. assign the first two general documents in each family to `training` and the third to `held-out`;
7. calculate lowercase SHA-256 for every PDF and both ground-truth files;
8. return `passed = $false` and explicit `errors` for any failure;
9. never omit a failed check or substitute a default passing value.

- [ ] **Step 6: Implement manifest, readiness, and test-capability evidence**

`New-HrAiBuilderRunManifest` writes the exact portable property names from design section 7.1 and creates `model-inventory.json` with both expected models at lifecycle stage `not_created`. `Set-HrAiBuilderModelRecord` accepts lifecycle stages `created`, `schema_defined`, `tagged`, `trained`, `evaluated`, `published`, `added_to_solution`, and `blocked`; it rejects unknown models and finalized manifests. `Complete-HrAiBuilderRunManifest` accepts the synchronized solution version, writes completion UTC, overall status, and SHA-256 for every supplied evidence path, then rejects any second finalization.

`New-HrAiBuilderReadinessRecord` evaluates all eight booleans and writes `passed` or `blocked` plus `failed_gates`. `New-HrAiBuilderTestCapabilityRecord` supports exactly two outcomes:

- pass: `-MachineReadableValues -PerFieldConfidence`;
- block: `-BlockedReason 'Observed reason for the missing structured output'`.

Reject calls that mix pass switches with `-BlockedReason` or supply neither outcome.

- [ ] **Step 7: Create the run-initialization entry point**

`Initialize-AiBuilderEvidenceRun.ps1` accepts:

```powershell
param(
    [Parameter(Mandatory)][string]$RunId,
    [Parameter(Mandatory)][string]$TenantKey,
    [Parameter(Mandatory)][guid]$EnvironmentId,
    [Parameter(Mandatory)][ValidateSet('DEV','TEST','PROD')][string]$EnvironmentStage,
    [Parameter(Mandatory)][string]$SolutionUniqueName,
    [Parameter(Mandatory)][string]$SolutionVersion,
    [Parameter(Mandatory)][string]$OutputDirectory
)
```

On the first invocation, create the two review templates and exit with a non-zero code and the message `Visual corpus review is required before qualification.` On a later invocation, validate the completed reviews, write `corpus-quality.json`, `run-manifest.json`, and `model-inventory.json`, and exit zero only when both corpora pass.

- [ ] **Step 8: Run tests and update the script catalogue**

Run:

```powershell
Import-Module Pester -RequiredVersion 5.7.1 -Force
Invoke-Pester -Path @(
    'hr/tests/pester/AiBuilderEvidence.Tests.ps1',
    'hr/tests/pester/SolutionLifecycle.Tests.ps1'
) -Output Detailed
```

Expected: all AI Builder and existing solution-lifecycle tests pass.

Update `hr/src/scripts/README.md` with the new module, initialization script, evidence boundary, and Tenant 1 portability statement.

- [ ] **Step 9: Commit the qualification toolchain**

```powershell
git add hr/src/scripts/modules/Caldova.HrFrontier.AiBuilder `
    hr/src/scripts/Initialize-AiBuilderEvidenceRun.ps1 `
    hr/src/scripts/README.md `
    hr/tests/pester/AiBuilderEvidence.Tests.ps1
git commit -m "feat: add AI Builder corpus qualification" `
    -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 3: Build prediction capture, normalization, metrics, and strict-gate evaluation

**Files:**
- Create: `hr/src/ai-builder/contracts/prediction-capture.schema.json`
- Create: `hr/src/scripts/modules/Caldova.HrFrontier.AiBuilder/Public/ConvertTo-HrAiBuilderNormalizedValue.ps1`
- Create: `hr/src/scripts/modules/Caldova.HrFrontier.AiBuilder/Public/Measure-HrAiBuilderEvaluation.ps1`
- Create: `hr/src/scripts/modules/Caldova.HrFrontier.AiBuilder/Public/Test-HrAiBuilderStrictGates.ps1`
- Create: `hr/src/scripts/Measure-AiBuilderEvaluation.ps1`
- Create: `hr/evidence/ai-builder/README.md`
- Modify: `hr/src/scripts/modules/Caldova.HrFrontier.AiBuilder/Caldova.HrFrontier.AiBuilder.psd1`
- Modify: `hr/src/scripts/modules/Caldova.HrFrontier.AiBuilder/Caldova.HrFrontier.AiBuilder.psm1`
- Modify: `hr/tests/pester/AiBuilderEvidence.Tests.ps1`

**Interfaces:**
- Consumes: `field-contract.json`, `run-manifest.json`, package ground truth, and prediction capture JSON.
- Produces: `ConvertTo-HrAiBuilderNormalizedValue -Value [object] -FieldType Text|Date`.
- Produces: `Measure-HrAiBuilderEvaluation` with flattened records, aggregate metrics, confidence distribution, and findings.
- Produces: `Test-HrAiBuilderStrictGates` with `status`, `failed_gates`, and per-model disposition.
- Produces: `validation-results-*.csv`, `validation-results.json`, `evaluation-metrics.json`, and `evaluation-summary.md`.

- [ ] **Step 1: Write failing normalization and metric tests**

Append:

```powershell
Describe 'AI Builder normalization and evaluation' {
    BeforeAll {
        $script:ModulePath = Join-Path $PSScriptRoot '..\..\src\scripts\modules\Caldova.HrFrontier.AiBuilder\Caldova.HrFrontier.AiBuilder.psd1'
        Import-Module $script:ModulePath -Force
    }

    It 'normalizes text narrowly and preserves case, accents, and punctuation' {
        ConvertTo-HrAiBuilderNormalizedValue -Value "  Céline   O'Neil  " -FieldType Text |
            Should -Be "Céline O'Neil"
    }

    It 'normalizes DD.MM.YYYY dates to ISO and rejects invalid dates' {
        ConvertTo-HrAiBuilderNormalizedValue -Value '14.03.1994' -FieldType Date |
            Should -Be '1994-03-14'
        { ConvertTo-HrAiBuilderNormalizedValue -Value '31.02.1994' -FieldType Date } |
            Should -Throw '*Invalid Date value*'
    }

    It 'classifies match, missing, incorrect, and false-value outcomes' {
        $rows = @(
            [pscustomobject]@{ expected_raw = 'A'; actual_raw = 'A'; expected_present = $true; actual_present = $true; exact_match = $true; error_class = $null; confidence = 0.99 },
            [pscustomobject]@{ expected_raw = 'B'; actual_raw = $null; expected_present = $true; actual_present = $false; exact_match = $false; error_class = 'missing'; confidence = $null },
            [pscustomobject]@{ expected_raw = $null; actual_raw = 'Invented'; expected_present = $false; actual_present = $true; exact_match = $false; error_class = 'false_value'; confidence = 0.88 },
            [pscustomobject]@{ expected_raw = $null; actual_raw = $null; expected_present = $false; actual_present = $false; exact_match = $true; error_class = $null; confidence = $null }
        )

        $metrics = Measure-HrAiBuilderEvaluation -ValidationRecords $rows

        $metrics.exact_match_accuracy | Should -Be 0.5
        $metrics.precision | Should -Be 0.5
        $metrics.recall | Should -Be 0.5
        $metrics.missing_field_precision | Should -Be 0.5
        $metrics.false_value_rate | Should -Be 0.5
    }

    It 'blocks strict gates when a false value exists' {
        $gate = Test-HrAiBuilderStrictGates -CorpusPassed $true -ContractPassed $true `
            -AttributionPassed $true -ValidationRecordCount 68 -ExpectedValidationRecordCount 68 `
            -FalseValueCount 1

        $gate.status | Should -Be 'blocked'
        $gate.failed_gates | Should -Contain 'zero_false_values'
    }

    It 'passes strict gates while preserving present-field quality findings' {
        $gate = Test-HrAiBuilderStrictGates -CorpusPassed $true -ContractPassed $true `
            -AttributionPassed $true -ValidationRecordCount 68 -ExpectedValidationRecordCount 68 `
            -FalseValueCount 0 -QualityFindingCount 3

        $gate.status | Should -Be 'evaluated'
        $gate.quality_finding_count | Should -Be 3
    }
}
```

- [ ] **Step 2: Run tests and verify red**

Run:

```powershell
Import-Module Pester -RequiredVersion 5.7.1 -Force
Invoke-Pester -Path hr/tests/pester/AiBuilderEvidence.Tests.ps1 -Output Detailed
```

Expected: FAIL because normalization, evaluation, and strict-gate functions are not exported.

- [ ] **Step 3: Define the prediction capture schema**

Create `prediction-capture.schema.json`:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "AI Builder prediction capture",
  "type": "object",
  "additionalProperties": false,
  "required": ["schema_version", "run_id", "model_name", "model_version", "documents"],
  "properties": {
    "schema_version": { "const": "1.0" },
    "run_id": { "type": "string", "minLength": 1 },
    "model_name": {
      "enum": ["PersonalMasterDataFixed", "PersonalMasterDataGeneral"]
    },
    "model_version": { "type": "string", "minLength": 1 },
    "documents": {
      "type": "array",
      "minItems": 1,
      "items": {
        "type": "object",
        "additionalProperties": false,
        "required": ["document", "collection_or_family", "fields"],
        "properties": {
          "document": { "type": "string", "minLength": 1 },
          "collection_or_family": { "type": "string", "minLength": 1 },
          "fields": {
            "type": "object",
            "additionalProperties": false,
            "required": [
              "candidate_id", "last_name", "first_name", "dob", "nationality",
              "marital", "heimatort", "permit", "street", "plz", "city", "ahv",
              "iban", "phone", "email", "ec_name", "ec_phone"
            ],
            "properties": {
              "candidate_id": { "$ref": "#/$defs/field" },
              "last_name": { "$ref": "#/$defs/field" },
              "first_name": { "$ref": "#/$defs/field" },
              "dob": { "$ref": "#/$defs/field" },
              "nationality": { "$ref": "#/$defs/field" },
              "marital": { "$ref": "#/$defs/field" },
              "heimatort": { "$ref": "#/$defs/field" },
              "permit": { "$ref": "#/$defs/field" },
              "street": { "$ref": "#/$defs/field" },
              "plz": { "$ref": "#/$defs/field" },
              "city": { "$ref": "#/$defs/field" },
              "ahv": { "$ref": "#/$defs/field" },
              "iban": { "$ref": "#/$defs/field" },
              "phone": { "$ref": "#/$defs/field" },
              "email": { "$ref": "#/$defs/field" },
              "ec_name": { "$ref": "#/$defs/field" },
              "ec_phone": { "$ref": "#/$defs/field" }
            }
          }
        }
      }
    }
  },
  "$defs": {
    "field": {
      "type": "object",
      "additionalProperties": false,
      "required": ["value", "confidence"],
      "properties": {
        "value": { "type": ["string", "null"] },
        "confidence": {
          "anyOf": [
            { "type": "null" },
            { "type": "number", "minimum": 0, "maximum": 1 }
          ]
        }
      }
    }
  }
}
```

The evaluator must enforce this schema without depending on PowerShell 7 `Test-Json`; use the same explicit checks in PowerShell 5.1 and retain the JSON Schema as the portable contract.

- [ ] **Step 4: Implement deterministic normalization**

For Text:

```powershell
$normalized = $Value.ToString().Normalize([Text.NormalizationForm]::FormKC).Trim()
$normalized = [regex]::Replace($normalized, '\s+', ' ')
return $normalized
```

For Date, use `DateTime.TryParseExact` with `dd.MM.yyyy`, invariant culture, and `DateTimeStyles::None`; return `yyyy-MM-dd`. Return `$null` only for null or empty input. Throw for invalid non-empty dates.

- [ ] **Step 5: Implement row classification and aggregate metrics**

The entry script must join each captured field to ground truth by exact document name and field name, then emit the design section 8.1 properties. Use these classifications in order:

1. expected absent + actual present -> `false_value`;
2. expected present + actual absent -> `missing`;
3. both present + invalid date -> `invalid_format`;
4. both present + normalized unequal -> `incorrect`;
5. otherwise exact match with empty `error_class`.

Metric formulas must use explicit denominators and return null when a denominator is zero:

```text
exact_match_accuracy    = exact matches / all records
precision               = correct non-empty / all returned non-empty
recall                  = correct non-empty / all expected non-empty
missing_field_precision = correctly absent / all expected absent
false_value_rate        = false values / all expected absent
```

Report metrics for the model overall, every field, and every collection or family. Confidence distribution must report count, minimum, maximum, and mean grouped by `exact_match`, `missing`, `incorrect`, `false_value`, and `invalid_format`.

- [ ] **Step 6: Implement strict gates and evidence writing**

`Test-HrAiBuilderStrictGates` fails on:

- corpus not passed;
- contract not passed;
- result attribution not passed;
- record count not equal to expected count;
- any false value.

Present-field `missing`, `incorrect`, and `invalid_format` rows increment quality findings but do not become passing matches and do not fail the safety gate.

`Measure-AiBuilderEvaluation.ps1` writes all output files atomically through temporary files followed by `Move-Item`. If another model already exists in `validation-results.json` or `evaluation-metrics.json`, merge by `run_id` + `model_name` + `model_version`; never overwrite the other model's evidence. If validation fails, write `evaluation-summary.md` with status `Blocked`, the failed gates, and evidence paths before exiting non-zero.

- [ ] **Step 7: Document the evidence contract**

Create `hr/evidence/ai-builder/README.md` with metadata and:

- portable `<tenant-key>/<environment-stage>/<run-id>` layout;
- synthetic-only boundary;
- immutable completed-run rule;
- raw capture versus calculated evidence authority;
- prohibition on credentials, tokens, solution ZIPs, and real personal data;
- exact command examples for the initialization and evaluation scripts.

- [ ] **Step 8: Run focused and regression tests**

Run:

```powershell
Import-Module Pester -RequiredVersion 5.7.1 -Force
Invoke-Pester -Path @(
    'hr/tests/pester/AiBuilderEvidence.Tests.ps1',
    'hr/tests/pester/SolutionLifecycle.Tests.ps1',
    '.github/cli/tests/DocumentationMetadata.Tests.ps1',
    '.github/cli/tests/DocumentationLinks.Tests.ps1'
) -Output Detailed
```

Expected: all tests pass, with the metric fixture producing 0.5 for all five numeric metrics.

- [ ] **Step 9: Commit the evaluation toolchain**

```powershell
git add hr/src/ai-builder/contracts/prediction-capture.schema.json `
    hr/src/scripts/modules/Caldova.HrFrontier.AiBuilder `
    hr/src/scripts/Measure-AiBuilderEvaluation.ps1 `
    hr/evidence/ai-builder/README.md `
    hr/tests/pester/AiBuilderEvidence.Tests.ps1
git commit -m "feat: add AI Builder evaluation evidence" `
    -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 4: Reconcile the attended model setup procedure

**Files:**
- Modify: `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/ai-builder-model-setup.md`
- Modify: `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/README.md`
- Modify: `hr/tests/pester/AiBuilderEvidence.Tests.ps1`
- Test: `.github/cli/tests/DocumentationMetadata.Tests.ps1`
- Test: `.github/cli/tests/DocumentationLinks.Tests.ps1`

**Interfaces:**
- Consumes: approved model names, field contract, scripts, evidence layout, strict gates, and stop behavior.
- Produces: one operator procedure that contains no old `gf_` names, `GFHRPlatformCore`, routing flow, TEST deployment, invented percentage threshold, or Workday action.
- Consumed by: Tasks 5, 6, 7, and 8.

- [ ] **Step 1: Add a failing documentation contract test**

Append to `AiBuilderEvidence.Tests.ps1`:

```powershell
Describe 'AI Builder operator guide contract' {
    BeforeAll {
        $root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
        $script:Guide = Get-Content -LiteralPath (
            Join-Path $root 'hr\docs\ideas\uc-0001-personal-master-data-completion-agent\ai-builder-model-setup.md'
        ) -Raw
    }

    It 'uses the approved model and solution names' {
        $script:Guide | Should -Match 'PersonalMasterDataFixed'
        $script:Guide | Should -Match 'PersonalMasterDataGeneral'
        $script:Guide | Should -Match 'caldovahrfrontier'
        $script:Guide | Should -Not -Match 'gf_Personalstammdaten'
        $script:Guide | Should -Not -Match 'GFHRPlatformCore'
    }

    It 'keeps workflows and TEST deployment outside the sprint' {
        $script:Guide | Should -Not -Match 'Build the routing test'
        $script:Guide | Should -Not -Match 'Deploy to TEST'
        $script:Guide | Should -Match 'No Power Automate flow'
    }

    It 'requires structured evidence and the strict false-value gate' {
        $script:Guide | Should -Match 'run-manifest\.json'
        $script:Guide | Should -Match 'machine-readable'
        $script:Guide | Should -Match 'false-value rate'
        $script:Guide | Should -Match 'zero'
    }
}
```

- [ ] **Step 2: Run the guide contract and verify red**

Run:

```powershell
Import-Module Pester -RequiredVersion 5.7.1 -Force
Invoke-Pester -Path hr/tests/pester/AiBuilderEvidence.Tests.ps1 -Output Detailed
```

Expected: FAIL on the old model names, future solution name, routing flow, and TEST deployment.

- [ ] **Step 3: Rewrite the guide around the approved sprint**

The guide must use this order:

1. read design, field BoM, and test BoM;
2. initialize `t2-dev-20260925-001`;
3. complete visual corpus review and rerun qualification;
4. execute all readiness checks and write `readiness.json`;
5. create and train `PersonalMasterDataFixed`;
6. prove machine-readable no-flow capture before accepting any held-out result;
7. evaluate fixed results and publish only on strict-gate pass;
8. create, train, and evaluate `PersonalMasterDataGeneral`;
9. publish and add only models with passing strict gates;
10. synchronize `caldovahrfrontier`;
11. update both BoMs and issue #13 from evidence.

Include explicit stop boxes for readiness failure, capture-mechanism failure, false values, consumed holdouts, publish failure, and solution-add failure.

- [ ] **Step 4: Run documentation and guide tests**

Run:

```powershell
Import-Module Pester -RequiredVersion 5.7.1 -Force
Invoke-Pester -Path @(
    'hr/tests/pester/AiBuilderEvidence.Tests.ps1',
    '.github/cli/tests/DocumentationMetadata.Tests.ps1',
    '.github/cli/tests/DocumentationLinks.Tests.ps1'
) -Output Detailed
```

Expected: all tests pass.

- [ ] **Step 5: Commit the operator procedure**

```powershell
git add hr/docs/ideas/uc-0001-personal-master-data-completion-agent/ai-builder-model-setup.md `
    hr/docs/ideas/uc-0001-personal-master-data-completion-agent/README.md `
    hr/tests/pester/AiBuilderEvidence.Tests.ps1
git commit -m "docs: reconcile AI Builder setup procedure" `
    -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 5: Qualify inputs and pass the Tenant 2 readiness gate

**Files:**
- Create: `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/corpus-review-fixed.json`
- Create: `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/corpus-review-general.json`
- Create: `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/corpus-quality.json`
- Create: `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/run-manifest.json`
- Create: `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/model-inventory.json`
- Create: `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/readiness.json`
- Modify: `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/bom-0002-ai-builder-test-inputs-and-outcomes.md`

**Interfaces:**
- Consumes: Tasks 1 through 4.
- Produces: qualified input evidence for run `t2-dev-20260925-001`.
- Produces: explicit `passed` or `blocked` readiness status.
- Required before: Tasks 6 and 7.

- [ ] **Step 1: Generate visual review templates and verify the expected stop**

Run:

```powershell
.\hr\src\scripts\Initialize-AiBuilderEvidenceRun.ps1 `
    -RunId 't2-dev-20260925-001' `
    -TenantKey 'tenant-2' `
    -EnvironmentId '84ad4c54-41d9-e5df-ba07-188b4719594a' `
    -EnvironmentStage DEV `
    -SolutionUniqueName 'caldovahrfrontier' `
    -SolutionVersion '0.0.0.1' `
    -OutputDirectory 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001'
```

Expected: non-zero exit, both review templates created, and message `Visual corpus review is required before qualification.`

- [ ] **Step 2: Review every synthetic document against ground truth**

For every review record:

- open the exact PDF;
- compare every non-empty ground-truth value with visible document content;
- confirm every empty ground-truth field is genuinely absent;
- set `status` to `confirmed`;
- set `values_visible` and `absences_confirmed` to `true`;
- set `reviewer` to the attended operator UPN from the Tenant 2 manifest;
- record a concrete note for any corrected or excluded document.

If any ground truth is ambiguous or wrong, correct the generator/package or exclude the document, regenerate hashes, and rerun Task 1 tests before proceeding.

- [ ] **Step 3: Rerun initialization and require corpus pass**

Run the same command from Step 1.

Expected:

- exit zero;
- fixed allocation 20 training and 4 held-out;
- general allocation 16 training and 8 held-out;
- all 48 PDFs and both ground-truth files have SHA-256 values;
- `corpus-quality.json` status is `passed`;
- `run-manifest.json` uses the portable property names and records Tenant 2 only as this run's deployment context.

- [ ] **Step 4: Connect to Tenant 2 DEV using the manifest administrator**

Run:

```powershell
.\hr\src\scripts\Connect-PowerPlatformEnvironment.ps1 `
    -TenantAlias caldova25668747 `
    -Stage Dev
```

Expected: profile `hr-caldova25668747-dev` is selected or created, interactive sign-in uses `admin@caldova25668747.onmicrosoft.com`, and `pac org who` confirms the DEV URL.

- [ ] **Step 5: Perform read-only readiness checks**

Record evidence for:

- environment URL and ID;
- Dataverse organization identity;
- maker authorization to create, train, publish, and solution-package AI Builder models;
- AI Builder availability in the region;
- available AI Builder capacity;
- applicable data policy compatibility;
- unmanaged `caldovahrfrontier` solution version;
- publisher unique name `calhrfrontier` and prefix `calhr`.

Do not allocate capacity, change data policy, grant roles, create a publisher, or create a solution.

- [ ] **Step 6: Write readiness evidence**

When all eight checks pass, run:

```powershell
Import-Module .\hr\src\scripts\modules\Caldova.HrFrontier.AiBuilder\Caldova.HrFrontier.AiBuilder.psd1 -Force
New-HrAiBuilderReadinessRecord `
    -RunId 't2-dev-20260925-001' `
    -EnvironmentVerified `
    -DataverseVerified `
    -MakerAuthorized `
    -AiBuilderAvailable `
    -CapacityAvailable `
    -DataPolicyCompatible `
    -SolutionVerified `
    -PublisherVerified `
    -OutputPath 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001\readiness.json'
```

When a check fails, pass `$false` for that exact switch and preserve the others. For example, unavailable capacity is recorded with:

```powershell
New-HrAiBuilderReadinessRecord `
    -RunId 't2-dev-20260925-001' `
    -EnvironmentVerified `
    -DataverseVerified `
    -MakerAuthorized `
    -AiBuilderAvailable `
    -CapacityAvailable:$false `
    -DataPolicyCompatible `
    -SolutionVerified `
    -PublisherVerified `
    -OutputPath 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001\readiness.json'
```

If any gate is false or unknown, require status `blocked`, update `BOM-0002-R01` and `BOM-0002-R02` to `Blocked`, comment on issue #13 with the exact failed gates, commit the evidence, and stop the sprint before model creation.

- [ ] **Step 7: Update the test BoM input status**

When both corpus and readiness pass:

- set both run IDs to `t2-dev-20260925-001`;
- set deployment context to the run-manifest evidence link;
- set corpus and generator revisions from the manifest;
- change both input statuses from `Planned` to `Qualified`;
- leave both outcomes as `Not run - no evidence`.

- [ ] **Step 8: Validate and commit qualified input evidence**

Run:

```powershell
Import-Module Pester -RequiredVersion 5.7.1 -Force
Invoke-Pester -Path @(
    'hr/tests/pester/AiBuilderEvidence.Tests.ps1',
    '.github/cli/tests/DocumentationMetadata.Tests.ps1',
    '.github/cli/tests/DocumentationLinks.Tests.ps1'
) -Output Detailed
git diff --check
```

Commit:

```powershell
git add hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001 `
    hr/docs/ideas/uc-0001-personal-master-data-completion-agent/bom-0002-ai-builder-test-inputs-and-outcomes.md
git commit -m "test: qualify AI Builder sprint inputs" `
    -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 6: Create, train, evaluate, and package the fixed-template model

**Files:**
- Create: `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/model-test-capability.json`
- Create: `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/prediction-capture-fixed.json`
- Create: `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/validation-results-fixed.csv`
- Modify: `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/model-inventory.json`
- Modify: `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/run-manifest.json`
- Modify: `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/validation-results.json`
- Modify: `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/evaluation-metrics.json`
- Modify: `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/evaluation-summary.md`
- Modify: `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/bom-0001-peopledoc-master-data-ai-builder-fields.md`
- Modify: `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/bom-0002-ai-builder-test-inputs-and-outcomes.md`

**Interfaces:**
- Consumes: qualified run manifest, fixed training allocation, field contract, and readiness pass.
- Produces: fixed-model identity, 68 field-level results, metrics, gates, and evidence.
- Produces: published and solution-added model only when strict gates pass.
- Required before: Task 8.

- [ ] **Step 1: Create the fixed-template model**

In Tenant 2 DEV:

1. open Power Apps -> AI hub -> AI models -> Extract custom information from documents;
2. choose **Fixed template documents**;
3. name the model `PersonalMasterDataFixed`;
4. define all 17 fields in field-contract order;
5. set `dob` to Date;
6. keep `plz` and `ahv` as Text;
7. record the AI Builder model ID and draft version:

```powershell
$fixedModelId = Read-Host 'Paste the Tenant 2 AI Builder model ID for PersonalMasterDataFixed'
$fixedDraftVersion = Read-Host 'Paste the draft model version'
if ([string]::IsNullOrWhiteSpace($fixedModelId) -or
    [string]::IsNullOrWhiteSpace($fixedDraftVersion)) {
    throw 'Model ID and draft version are required.'
}
Set-HrAiBuilderModelRecord `
    -RunManifestPath 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001\run-manifest.json' `
    -ModelInventoryPath 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001\model-inventory.json' `
    -ModelName 'PersonalMasterDataFixed' `
    -ModelId $fixedModelId `
    -ModelVersion $fixedDraftVersion `
    -LifecycleStage 'created'
```

The two values are attended portal outputs, not design constants. Record them exactly; do not generate or infer them.

Do not publish at this stage.

- [ ] **Step 2: Create collections and upload training documents only**

Create:

- `Personalblatt`;
- `AnmeldungGemeinde`;
- `Sozialversicherung`;
- `Bankverbindung`.

Upload only the 20 files marked `training` in the run manifest. Verify no held-out file hash appears in an uploaded training set.

- [ ] **Step 3: Tag the fixed documents**

For every training PDF:

- tag only values present in ground truth;
- mark absent fields unavailable;
- use the canonical field identifiers exactly;
- do not infer, substitute, translate, or synthesize a value;
- review `dob`, `plz`, `ahv`, explicit em dashes, and emergency-contact fields before training.

Update all field BoM fixed-model stages to `Tagged` only after all four collections pass operator review.

- [ ] **Step 4: Train and record the resulting version**

Start training. On platform failure, record the platform error, set the fixed model and `BOM-0002-R01` to blocked, commit evidence, and stop this workstream.

On success, run:

```powershell
$runManifestPath = 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001\run-manifest.json'
$fixedModelId = @(
    (Get-Content -LiteralPath $runManifestPath -Raw | ConvertFrom-Json).models |
        Where-Object display_name -eq 'PersonalMasterDataFixed'
).id
$fixedTrainedVersion = Read-Host 'Paste the trained PersonalMasterDataFixed version'
if ([string]::IsNullOrWhiteSpace($fixedModelId) -or
    [string]::IsNullOrWhiteSpace($fixedTrainedVersion)) {
    throw 'The recorded model ID and trained model version are required.'
}
Set-HrAiBuilderModelRecord `
    -RunManifestPath $runManifestPath `
    -ModelInventoryPath 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001\model-inventory.json' `
    -ModelName 'PersonalMasterDataFixed' `
    -ModelId $fixedModelId `
    -ModelVersion $fixedTrainedVersion `
    -LifecycleStage 'trained'
```

Then set the field BoM fixed-model stage to `Trained`.

- [ ] **Step 5: Prove the no-flow structured capture mechanism**

Use one held-out fixed document in AI Builder Quick Test. Verify whether the supported experience can produce:

- machine-readable values for all 17 fields;
- per-field confidence from 0 through 1;
- document identity;
- unambiguous null for absent values.

If all are available, write pass evidence:

```powershell
New-HrAiBuilderTestCapabilityRecord `
    -RunId 't2-dev-20260925-001' `
    -Mechanism 'AI Builder Quick Test' `
    -MachineReadableValues `
    -PerFieldConfidence `
    -OutputPath 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001\model-test-capability.json'
```

If any are unavailable, write blocked evidence with the observed reason, update both BoMs to `Evidence incomplete`, comment on issue #13, commit, and stop. Do not manually transcribe results or create an unapproved flow.

- [ ] **Step 6: Capture all four held-out fixed documents**

Create `prediction-capture-fixed.json` matching the schema. It must contain:

- the fixed model name and exact version;
- all four held-out filenames;
- the collection for each document;
- all 17 field keys per document;
- raw value or null;
- confidence or null.

Expected count: 4 documents and 68 field captures.

- [ ] **Step 7: Run fixed evaluation**

Run:

```powershell
.\hr\src\scripts\Measure-AiBuilderEvaluation.ps1 `
    -RunManifestPath 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001\run-manifest.json' `
    -FieldContractPath 'hr\src\ai-builder\contracts\field-contract.json' `
    -GroundTruthPath 'hr\docs\ideas\uc-0001-personal-master-data-completion-agent\gf-aib-fixed-template\ground-truth.json' `
    -PredictionCapturePath 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001\prediction-capture-fixed.json' `
    -OutputDirectory 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001'
```

Expected:

- 68 attributed result records;
- field, collection, and model metrics;
- confidence distribution;
- all mismatches visible;
- strict-gate disposition.

- [ ] **Step 8: Apply the fixed-model publication gate**

If any false value exists or another strict gate fails:

- do not publish;
- set fixed stages to `Blocked`;
- update `BOM-0002-R01` to `Blocked - strict gate failure`;
- link the exact evidence;
- commit and stop the fixed workstream.

If strict gates pass:

1. publish `PersonalMasterDataFixed`;
2. add it explicitly to unmanaged solution `caldovahrfrontier`;
3. record publication and solution-add evidence;
4. set fixed field stages to `Added to solution`;
5. set verification per field to `Evaluated - no findings` or `Evaluated - quality findings`;
6. update `BOM-0002-R01` from calculated metrics.

After publication and again after verifying the model in the solution, run:

```powershell
$fixedPublishedVersion = Read-Host 'Paste the published PersonalMasterDataFixed version'
if ([string]::IsNullOrWhiteSpace($fixedPublishedVersion)) {
    throw 'The published model version is required.'
}
$recordArguments = @{
    RunManifestPath = 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001\run-manifest.json'
    ModelInventoryPath = 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001\model-inventory.json'
    ModelName = 'PersonalMasterDataFixed'
    ModelId = $fixedModelId
    ModelVersion = $fixedPublishedVersion
}
Set-HrAiBuilderModelRecord @recordArguments -LifecycleStage 'published'
# Run the next line only after the solution component is visibly confirmed.
Set-HrAiBuilderModelRecord @recordArguments -LifecycleStage 'added_to_solution'
```

- [ ] **Step 9: Validate and commit fixed-model evidence**

Run all AI Builder and documentation tests, then:

```powershell
git add hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001 `
    hr/docs/ideas/uc-0001-personal-master-data-completion-agent/bom-0001-peopledoc-master-data-ai-builder-fields.md `
    hr/docs/ideas/uc-0001-personal-master-data-completion-agent/bom-0002-ai-builder-test-inputs-and-outcomes.md
git commit -m "test: evaluate fixed AI Builder model" `
    -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 7: Create, train, evaluate, and package the general-document model

**Files:**
- Create: `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/prediction-capture-general.json`
- Create: `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/validation-results-general.csv`
- Modify: the shared evidence and BoM files listed in Task 6

**Interfaces:**
- Consumes: qualified general allocation, field contract, readiness pass, and proven structured capture mechanism.
- Produces: general-model identity, 136 field-level results, metrics, gates, and evidence.
- Produces: published and solution-added model only when strict gates pass.
- Required before: Task 8.

- [ ] **Step 1: Create the general-document model**

In Tenant 2 DEV:

1. choose **General documents**;
2. name the model `PersonalMasterDataGeneral`;
3. define the identical 17-field contract;
4. record the observed model ID and draft version:

```powershell
$generalModelId = Read-Host 'Paste the Tenant 2 AI Builder model ID for PersonalMasterDataGeneral'
$generalDraftVersion = Read-Host 'Paste the draft model version'
if ([string]::IsNullOrWhiteSpace($generalModelId) -or
    [string]::IsNullOrWhiteSpace($generalDraftVersion)) {
    throw 'Model ID and draft version are required.'
}
Set-HrAiBuilderModelRecord `
    -RunManifestPath 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001\run-manifest.json' `
    -ModelInventoryPath 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001\model-inventory.json' `
    -ModelName 'PersonalMasterDataGeneral' `
    -ModelId $generalModelId `
    -ModelVersion $generalDraftVersion `
    -LifecycleStage 'created'
```
5. do not create fixed-template collections for this model.

- [ ] **Step 2: Upload only the 16 general training documents**

Use the `training` assignments from `run-manifest.json`. Verify the eight held-out hashes are not uploaded for tagging or training.

- [ ] **Step 3: Tag, review, and train**

Tag all present ground-truth values and mark absent fields unavailable. Review prose, bilingual labels, degraded scans, and the distinction between candidate and emergency-contact names.

On training failure, record the platform error and block only the general workstream. Do not use the fixed result as a substitute.

On success, run:

```powershell
$runManifestPath = 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001\run-manifest.json'
$generalModelId = @(
    (Get-Content -LiteralPath $runManifestPath -Raw | ConvertFrom-Json).models |
        Where-Object display_name -eq 'PersonalMasterDataGeneral'
).id
$generalTrainedVersion = Read-Host 'Paste the trained PersonalMasterDataGeneral version'
if ([string]::IsNullOrWhiteSpace($generalModelId) -or
    [string]::IsNullOrWhiteSpace($generalTrainedVersion)) {
    throw 'The recorded model ID and trained model version are required.'
}
Set-HrAiBuilderModelRecord `
    -RunManifestPath $runManifestPath `
    -ModelInventoryPath 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001\model-inventory.json' `
    -ModelName 'PersonalMasterDataGeneral' `
    -ModelId $generalModelId `
    -ModelVersion $generalTrainedVersion `
    -LifecycleStage 'trained'
```

- [ ] **Step 4: Capture all eight held-out general documents**

Create `prediction-capture-general.json` with:

- exact general model version;
- eight held-out filenames;
- eight collection-or-family values;
- all 17 field keys per document;
- raw value and per-field confidence or null.

Expected count: 8 documents and 136 field captures.

- [ ] **Step 5: Run general evaluation**

Run:

```powershell
.\hr\src\scripts\Measure-AiBuilderEvaluation.ps1 `
    -RunManifestPath 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001\run-manifest.json' `
    -FieldContractPath 'hr\src\ai-builder\contracts\field-contract.json' `
    -GroundTruthPath 'hr\docs\ideas\uc-0001-personal-master-data-completion-agent\gf-aib-general-documents\ground-truth.json' `
    -PredictionCapturePath 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001\prediction-capture-general.json' `
    -OutputDirectory 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001'
```

Expected: 136 attributed results and metrics separated from the fixed model.

- [ ] **Step 6: Apply the general-model publication gate**

Use the same strict gate as the fixed model. Low accuracy for present fields remains visible but does not compensate for or excuse a false value.

If strict gates pass, publish and add `PersonalMasterDataGeneral` explicitly to `caldovahrfrontier`. If they fail, record the blocker and do not publish.

After publication and again after verifying the model in the solution, run:

```powershell
$generalPublishedVersion = Read-Host 'Paste the published PersonalMasterDataGeneral version'
if ([string]::IsNullOrWhiteSpace($generalPublishedVersion)) {
    throw 'The published model version is required.'
}
$recordArguments = @{
    RunManifestPath = 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001\run-manifest.json'
    ModelInventoryPath = 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001\model-inventory.json'
    ModelName = 'PersonalMasterDataGeneral'
    ModelId = $generalModelId
    ModelVersion = $generalPublishedVersion
}
Set-HrAiBuilderModelRecord @recordArguments -LifecycleStage 'published'
# Run the next line only after the solution component is visibly confirmed.
Set-HrAiBuilderModelRecord @recordArguments -LifecycleStage 'added_to_solution'
```

- [ ] **Step 7: Update BoMs from evidence**

Update:

- all general-model field stages and verification statuses;
- `BOM-0002-R02` model version, input status, metrics, findings, outcome status, and evidence;
- the overall implementation status without allowing one model to compensate for the other.

- [ ] **Step 8: Validate and commit general-model evidence**

```powershell
Import-Module Pester -RequiredVersion 5.7.1 -Force
Invoke-Pester -Path @(
    'hr/tests/pester/AiBuilderEvidence.Tests.ps1',
    '.github/cli/tests/DocumentationMetadata.Tests.ps1',
    '.github/cli/tests/DocumentationLinks.Tests.ps1'
) -Output Detailed
git diff --check
```

Commit:

```powershell
git add hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001 `
    hr/docs/ideas/uc-0001-personal-master-data-completion-agent/bom-0001-peopledoc-master-data-ai-builder-fields.md `
    hr/docs/ideas/uc-0001-personal-master-data-completion-agent/bom-0002-ai-builder-test-inputs-and-outcomes.md
git commit -m "test: evaluate general AI Builder model" `
    -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 8: Synchronize solution source and close the sprint evidence loop

**Files:**
- Modify: `hr/src/solutions/caldovahrfrontier/`
- Modify: `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/run-manifest.json`
- Modify: `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/model-inventory.json`
- Modify: `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/evaluation-summary.md`
- Modify: both AI Builder BoMs
- Modify: `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/ai-builder-model-setup.md` only if execution exposed a verified procedural correction
- External: GitHub issue #13

**Interfaces:**
- Consumes: Tasks 1 through 7.
- Produces: immutable completed or blocked run evidence, synchronized solution source, final BoMs, and sprint status.

- [ ] **Step 1: Synchronize the DEV solution source**

Run:

```powershell
.\hr\src\scripts\Sync-HrSolutionSource.ps1 `
    -TenantAlias caldova25668747 `
    -SolutionUniqueName caldovahrfrontier
```

Expected: temporary ZIP is deleted; unpacked source is updated under `hr/src/solutions/caldovahrfrontier/`.

- [ ] **Step 2: Verify solution component evidence**

Run:

```powershell
rg -n "PersonalMasterDataFixed|PersonalMasterDataGeneral" `
    hr/src/solutions/caldovahrfrontier
```

Expected when both models passed and were added: both names occur in unpacked solution source. If a model is absent, keep its BoM stage below `Added to solution`, record the solution-add failure, and leave the overall implementation incomplete.

- [ ] **Step 3: Finalize the run manifest**

Choose the status that matches evidence and run:

```powershell
$evidenceRoot = 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001'
$evidencePaths = @(
    Get-ChildItem -LiteralPath $evidenceRoot -File -Recurse |
        Where-Object Name -ne 'run-manifest.json' |
        Select-Object -ExpandProperty FullName
)
$solutionXml = [xml](Get-Content -LiteralPath `
    'hr\src\solutions\caldovahrfrontier\Other\Solution.xml' -Raw)
$solutionVersion = $solutionXml.ImportExportXml.SolutionManifest.Version
Complete-HrAiBuilderRunManifest `
    -Path (Join-Path $evidenceRoot 'run-manifest.json') `
    -OverallStatus 'technically_complete' `
    -SolutionVersion $solutionVersion `
    -EvidencePaths $evidencePaths
```

Use `partially_complete` when exactly one model is technically complete and `blocked` when neither is technically complete. After finalization, the tooling must refuse in-place mutation. Any rerun uses `t2-dev-20260925-002`.

- [ ] **Step 4: Verify all 17 acceptance criteria**

Create a checklist in `evaluation-summary.md` mapping each design acceptance criterion to:

- pass with evidence path;
- blocked with failed gate and evidence path;
- out of scope only where the design explicitly says so.

Do not mark the sprint complete if either model lacks complete field-level results, has a false value, is unpublished, or is absent from the solution.

- [ ] **Step 5: Run final repository validation**

Run:

```powershell
Import-Module Pester -RequiredVersion 5.7.1 -Force
Invoke-Pester -Path @(
    '.github/cli/tests',
    'hr/tests/pester',
    'infra/tests/pester'
) -Output Detailed
git diff --check
git status --short
```

Expected:

- zero failed tests;
- no generated `testResults.xml`;
- no solution ZIP;
- no credentials, tokens, or real personal data;
- only intended implementation and evidence changes.

- [ ] **Step 6: Update GitHub issue #13**

Post a concise issue comment containing:

- run ID;
- fixed and general model versions and dispositions;
- corpus, contract, and safety gate status;
- metric summary and evidence paths;
- publication and solution-add status;
- open quality findings;
- explicit statement that automated-write approval was not granted.

Use:

```powershell
gh issue comment 13 --repo urruegg/caldova-hr-frontier --body-file `
    hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/evaluation-summary.md
```

Close issue #13 only if both models are technically complete and every acceptance criterion passes. Otherwise leave it open with blockers.

- [ ] **Step 7: Commit the synchronized solution and final evidence**

```powershell
git add hr/src/solutions/caldovahrfrontier `
    hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001 `
    hr/docs/ideas/uc-0001-personal-master-data-completion-agent/bom-0001-peopledoc-master-data-ai-builder-fields.md `
    hr/docs/ideas/uc-0001-personal-master-data-completion-agent/bom-0002-ai-builder-test-inputs-and-outcomes.md
git commit -m "feat: complete Tenant 2 AI Builder sprint" `
    -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

If the run is blocked, use:

```powershell
git commit -m "test: record blocked AI Builder sprint evidence" `
    -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

## Sprint Completion Gate

The sprint is complete only when:

- both corpora are qualified and hash-recorded;
- readiness is passed;
- structured no-flow field and confidence capture is proven;
- both models have complete attributed result sets;
- both models have zero false values for expected absences;
- both models are published and added to `caldovahrfrontier`;
- solution source contains both model components;
- field and test BoMs match the machine-readable evidence;
- the run manifest is finalized and immutable;
- all tests pass;
- issue #13 contains the final evidence summary;
- no workflow, Workday action, real personal data, TEST/PROD deployment, or cross-tenant dependency was introduced.

If any item fails, record the blocker and preserve the evidence. Do not weaken the gate or return a success-shaped result.
