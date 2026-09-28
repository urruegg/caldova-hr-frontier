Set-StrictMode -Version Latest

Describe 'AI Builder field and corpus contracts' {
    BeforeAll {
        $script:RepositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
        $script:ContractPath = Join-Path $script:RepositoryRoot 'hr\src\ai-builder\contracts\field-contract.json'
        $script:UseCaseRoot = Join-Path $script:RepositoryRoot 'hr\docs\ideas\uc-0001-personal-master-data-completion-agent'
        $script:ExpectedContractVersion = '0.1'
        $script:ExpectedFieldDefinitions = @(
            @{ bom_id = 'BOM-0001-F01'; name = 'candidate_id'; ai_builder_type = 'Text'; normalization = 'text' }
            @{ bom_id = 'BOM-0001-F02'; name = 'last_name'; ai_builder_type = 'Text'; normalization = 'text' }
            @{ bom_id = 'BOM-0001-F03'; name = 'first_name'; ai_builder_type = 'Text'; normalization = 'text' }
            @{ bom_id = 'BOM-0001-F04'; name = 'dob'; ai_builder_type = 'Date'; normalization = 'date_ddMMyyyy' }
            @{ bom_id = 'BOM-0001-F05'; name = 'nationality'; ai_builder_type = 'Text'; normalization = 'text' }
            @{ bom_id = 'BOM-0001-F06'; name = 'marital'; ai_builder_type = 'Text'; normalization = 'text' }
            @{ bom_id = 'BOM-0001-F07'; name = 'heimatort'; ai_builder_type = 'Text'; normalization = 'text' }
            @{ bom_id = 'BOM-0001-F08'; name = 'permit'; ai_builder_type = 'Text'; normalization = 'text' }
            @{ bom_id = 'BOM-0001-F09'; name = 'street'; ai_builder_type = 'Text'; normalization = 'text' }
            @{ bom_id = 'BOM-0001-F10'; name = 'plz'; ai_builder_type = 'Text'; normalization = 'text' }
            @{ bom_id = 'BOM-0001-F11'; name = 'city'; ai_builder_type = 'Text'; normalization = 'text' }
            @{ bom_id = 'BOM-0001-F12'; name = 'ahv'; ai_builder_type = 'Text'; normalization = 'text' }
            @{ bom_id = 'BOM-0001-F13'; name = 'iban'; ai_builder_type = 'Text'; normalization = 'text' }
            @{ bom_id = 'BOM-0001-F14'; name = 'phone'; ai_builder_type = 'Text'; normalization = 'text' }
            @{ bom_id = 'BOM-0001-F15'; name = 'email'; ai_builder_type = 'Text'; normalization = 'text' }
            @{ bom_id = 'BOM-0001-F16'; name = 'ec_name'; ai_builder_type = 'Text'; normalization = 'text' }
            @{ bom_id = 'BOM-0001-F17'; name = 'ec_phone'; ai_builder_type = 'Text'; normalization = 'text' }
        )
    }

    It 'defines the ordered 17-field contract and stable BoM IDs' {
        $script:ContractPath | Should -Exist
        $contract = Get-Content -LiteralPath $script:ContractPath -Raw | ConvertFrom-Json

        $contract.contract_version | Should -Be $script:ExpectedContractVersion
        $contract.field_count | Should -Be 17
        @($contract.fields.name) | Should -Be @($script:ExpectedFieldDefinitions.name)
        @($contract.fields.bom_id) | Should -Be @($script:ExpectedFieldDefinitions.bom_id)

        for ($index = 0; $index -lt $script:ExpectedFieldDefinitions.Count; $index++) {
            $expected = $script:ExpectedFieldDefinitions[$index]
            $actual = $contract.fields[$index]

            $actual.bom_id | Should -Be $expected.bom_id
            $actual.name | Should -Be $expected.name
            $actual.ai_builder_type | Should -Be $expected.ai_builder_type
            $actual.normalization | Should -Be $expected.normalization
        }
    }

    Describe 'AI Builder corpus qualification' {
        BeforeAll {
            $script:ModulePath = Join-Path $PSScriptRoot '..\..\src\scripts\modules\Caldova.HrFrontier.AiBuilder\Caldova.HrFrontier.AiBuilder.psd1'
            Import-Module $script:ModulePath -Force
            $script:RepositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
            $script:ContractPath = Join-Path $script:RepositoryRoot 'hr\src\ai-builder\contracts\field-contract.json'
            $script:FixedPath = Join-Path $script:RepositoryRoot 'hr\docs\ideas\uc-0001-personal-master-data-completion-agent\gf-aib-fixed-template'
            $script:GeneralPath = Join-Path $script:RepositoryRoot 'hr\docs\ideas\uc-0001-personal-master-data-completion-agent\gf-aib-general-documents'
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

        It 'assigns 16 general documents to training and 8 to held-out' {
            $reviewPath = Join-Path $TestDrive 'general-review.json'
            New-HrAiBuilderCorpusReviewTemplate -PackagePath $script:GeneralPath -OutputPath $reviewPath
            $review = Get-Content -LiteralPath $reviewPath -Raw | ConvertFrom-Json
            foreach ($document in $review.documents) {
                $document.status = 'confirmed'
                $document.values_visible = $true
                $document.absences_confirmed = $true
                $document.reviewer = 'test-reviewer'
            }
            $review | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $reviewPath -Encoding UTF8

            $result = Test-HrAiBuilderCorpus -PackagePath $script:GeneralPath -ModelKind General `
                -ReviewPath $reviewPath -FieldContractPath $script:ContractPath

            $result.passed | Should -BeTrue
            @($result.documents | Where-Object assignment -eq 'training').Count | Should -Be 16
            @($result.documents | Where-Object assignment -eq 'held-out').Count | Should -Be 8
            @($result.documents | Where-Object assignment -eq 'held-out').document | Should -Be @(
                'g03-arbeitsvertrag-CAND-2026-0413.pdf'
                'g06-anschreiben-CAND-2026-0416.pdf'
                'g09-bewilligung-CAND-2026-0419.pdf'
                'g12-versicherung-CAND-2026-0422.pdf'
                'g15-zivilstand-CAND-2026-0425.pdf'
                'g18-selbstdeklaration-CAND-2026-0428.pdf'
                'g21-scan-degraded-CAND-2026-0431.pdf'
                'g24-new-joiner-sheet-CAND-2026-0434.pdf'
            )
        }
    }

    Describe 'AI Builder run and readiness evidence' {
        BeforeAll {
            $script:ModulePath = Join-Path $PSScriptRoot '..\..\src\scripts\modules\Caldova.HrFrontier.AiBuilder\Caldova.HrFrontier.AiBuilder.psd1'
            Import-Module $script:ModulePath -Force

            function New-RunEvidencePaths {
                param([Parameter(Mandatory)][string]$Name)

                $root = Join-Path $TestDrive $Name
                New-Item -ItemType Directory -Force -Path $root | Out-Null
                [pscustomobject]@{
                    Root = $root
                    ManifestPath = Join-Path $root 'run-manifest.json'
                    InventoryPath = Join-Path $root 'model-inventory.json'
                    ReadinessPath = Join-Path $root 'readiness.json'
                    TestCapabilityPath = Join-Path $root 'model-test-capability.json'
                    MetricsPath = Join-Path $root 'evaluation-metrics.json'
                }
            }
        }

        It 'keeps deployment context in the manifest rather than field results' {
            $paths = New-RunEvidencePaths -Name 'deployment-context'
            New-HrAiBuilderRunManifest -RunId 'test-run-001' -TenantKey 'tenant-2' `
                -EnvironmentId '84ad4c54-41d9-e5df-ba07-188b4719594a' -EnvironmentStage DEV `
                -SolutionUniqueName 'caldovahrfrontier' -SolutionVersion '0.0.0.1' `
                -OperatorUpn 'operator@example.invalid' `
                -StartedAtUtc ([datetime]'2026-09-25T08:00:00Z') `
                -CorpusRevision (('a' * 64) -join '') -GeneratorRevision (('b' * 64) -join '') `
                -FieldContractVersion '0.1' -Models @(
                    [pscustomobject]@{ display_name = 'PersonalMasterDataFixed'; model_kind = 'Fixed' }
                ) -CorpusResults @() -OutputPath $paths.ManifestPath -ModelInventoryPath $paths.InventoryPath

            $manifest = Get-Content -LiteralPath $paths.ManifestPath -Raw | ConvertFrom-Json
            $manifest.tenant_key | Should -Be 'tenant-2'
            $manifest.power_platform_environment_id | Should -Be '84ad4c54-41d9-e5df-ba07-188b4719594a'
            $manifest.environment_stage | Should -Be 'DEV'
            $manifest.operator | Should -Be 'operator@example.invalid'
            $manifest.started_at_utc | Should -Be '2026-09-25T08:00:00.0000000Z'
            $manifest.corpus_revision | Should -Match '^[a-f0-9]{64}$'
            $manifest.generator_revision | Should -Match '^[a-f0-9]{64}$'
        }

        It 'refuses to overwrite an existing manifest or inventory' {
            $paths = New-RunEvidencePaths -Name 'overwrite-refusal'
            New-HrAiBuilderRunManifest -RunId 'test-run-001' -TenantKey 'tenant-2' `
                -EnvironmentId '84ad4c54-41d9-e5df-ba07-188b4719594a' -EnvironmentStage DEV `
                -SolutionUniqueName 'caldovahrfrontier' -SolutionVersion '0.0.0.1' `
                -OperatorUpn 'operator@example.invalid' `
                -StartedAtUtc ([datetime]'2026-09-25T08:00:00Z') `
                -CorpusRevision (('a' * 64) -join '') -GeneratorRevision (('b' * 64) -join '') `
                -FieldContractVersion '0.1' -Models @(
                    [pscustomobject]@{ display_name = 'PersonalMasterDataFixed'; model_kind = 'Fixed' }
                ) -CorpusResults @() -OutputPath $paths.ManifestPath -ModelInventoryPath $paths.InventoryPath | Out-Null

            $originalStartedAt = (Get-Content -LiteralPath $paths.ManifestPath -Raw | ConvertFrom-Json).started_at_utc
            {
                New-HrAiBuilderRunManifest -RunId 'test-run-001' -TenantKey 'tenant-2' `
                    -EnvironmentId '84ad4c54-41d9-e5df-ba07-188b4719594a' -EnvironmentStage DEV `
                    -SolutionUniqueName 'caldovahrfrontier' -SolutionVersion '0.0.0.1' `
                    -OperatorUpn 'operator@example.invalid' `
                    -StartedAtUtc ([datetime]'2026-09-25T09:00:00Z') `
                    -CorpusRevision (('a' * 64) -join '') -GeneratorRevision (('b' * 64) -join '') `
                    -FieldContractVersion '0.1' -Models @(
                        [pscustomobject]@{ display_name = 'PersonalMasterDataFixed'; model_kind = 'Fixed' }
                    ) -CorpusResults @() -OutputPath $paths.ManifestPath -ModelInventoryPath $paths.InventoryPath
            } | Should -Throw '*already exists*'
            (Get-Content -LiteralPath $paths.ManifestPath -Raw | ConvertFrom-Json).started_at_utc | Should -Be $originalStartedAt
        }

        It 'preserves failed and unknown readiness observations and blocks both' {
            $paths = New-RunEvidencePaths -Name 'readiness-blocking'
            $checks = @(
                [pscustomobject]@{ id = 'environment'; status = 'passed'; observation = 'DEV URL matched'; source = 'pac org who'; operator = 'operator@example.invalid'; observed_at_utc = '2026-09-25T08:05:00Z' },
                [pscustomobject]@{ id = 'dataverse'; status = 'passed'; observation = 'Organization ID matched'; source = 'pac org who'; operator = 'operator@example.invalid'; observed_at_utc = '2026-09-25T08:05:00Z' },
                [pscustomobject]@{ id = 'maker_authorization'; status = 'passed'; observation = 'Model create action available'; source = 'Power Apps AI hub'; operator = 'operator@example.invalid'; observed_at_utc = '2026-09-25T08:06:00Z' },
                [pscustomobject]@{ id = 'ai_builder_available'; status = 'failed'; observation = 'Custom extraction unavailable'; source = 'Power Apps AI hub'; operator = 'operator@example.invalid'; observed_at_utc = '2026-09-25T08:07:00Z' },
                [pscustomobject]@{ id = 'capacity'; status = 'unknown'; observation = 'Capacity page not accessible'; source = 'Power Platform admin center'; operator = 'operator@example.invalid'; observed_at_utc = '2026-09-25T08:08:00Z' },
                [pscustomobject]@{ id = 'data_policy'; status = 'passed'; observation = 'No blocking policy observed'; source = 'Power Platform admin center'; operator = 'operator@example.invalid'; observed_at_utc = '2026-09-25T08:09:00Z' },
                [pscustomobject]@{ id = 'solution'; status = 'passed'; observation = 'caldovahrfrontier found'; source = 'pac solution list'; operator = 'operator@example.invalid'; observed_at_utc = '2026-09-25T08:10:00Z' },
                [pscustomobject]@{ id = 'publisher'; status = 'passed'; observation = 'calhrfrontier/calhr matched'; source = 'solution details'; operator = 'operator@example.invalid'; observed_at_utc = '2026-09-25T08:10:00Z' }
            )
            $result = New-HrAiBuilderReadinessRecord -RunId 'test-run-001' -Checks $checks -OutputPath $paths.ReadinessPath

            $result.status | Should -Be 'blocked'
            $result.failed_gates | Should -Contain 'ai_builder_available'
            $result.failed_gates | Should -Contain 'capacity'
            @($result.checks | Where-Object status -eq 'unknown').Count | Should -Be 1
            $paths.ReadinessPath | Should -Exist
        }

        It 'records a blocked no-flow test mechanism explicitly' {
            $paths = New-RunEvidencePaths -Name 'blocked-test-capability'
            $result = New-HrAiBuilderTestCapabilityRecord -RunId 'test-run-001' `
                -Mechanism 'AI Builder Quick Test' `
                -BlockedReason 'No machine-readable confidence export is available.' `
                -OutputPath $paths.TestCapabilityPath

            $result.status | Should -Be 'blocked'
            $result.machine_readable_values | Should -BeFalse
            $result.per_field_confidence | Should -BeFalse
        }

        It 'records a known model and rejects an unknown model name' {
            $paths = New-RunEvidencePaths -Name 'known-model-recording'
            New-HrAiBuilderRunManifest -RunId 'test-run-001' -TenantKey 'tenant-2' `
                -EnvironmentId '84ad4c54-41d9-e5df-ba07-188b4719594a' -EnvironmentStage DEV `
                -SolutionUniqueName 'caldovahrfrontier' -SolutionVersion '0.0.0.1' `
                -OperatorUpn 'operator@example.invalid' `
                -StartedAtUtc ([datetime]'2026-09-25T08:00:00Z') `
                -CorpusRevision (('a' * 64) -join '') -GeneratorRevision (('b' * 64) -join '') `
                -FieldContractVersion '0.1' -Models @(
                    [pscustomobject]@{ display_name = 'PersonalMasterDataFixed'; model_kind = 'Fixed' }
                ) -CorpusResults @() -OutputPath $paths.ManifestPath -ModelInventoryPath $paths.InventoryPath

            foreach ($stage in 'created', 'schema_defined', 'tagged', 'trained') {
                Set-HrAiBuilderModelRecord -RunManifestPath $paths.ManifestPath `
                    -ModelInventoryPath $paths.InventoryPath -ModelName 'PersonalMasterDataFixed' `
                    -ModelId 'model-fixed-001' -ModelVersion '1' -LifecycleStage $stage
            }

            $manifest = Get-Content -LiteralPath $paths.ManifestPath -Raw | ConvertFrom-Json
            @($manifest.models | Where-Object display_name -eq 'PersonalMasterDataFixed').version |
                Should -Be '1'
            {
                Set-HrAiBuilderModelRecord -RunManifestPath $paths.ManifestPath `
                    -ModelInventoryPath $paths.InventoryPath -ModelName 'UnknownModel' `
                    -ModelId 'unknown' -ModelVersion '1' -LifecycleStage 'trained'
            } | Should -Throw '*Unknown model*'
            {
                Set-HrAiBuilderModelRecord -RunManifestPath $paths.ManifestPath `
                    -ModelInventoryPath $paths.InventoryPath -ModelName 'PersonalMasterDataFixed' `
                    -ModelId 'model-fixed-001' -ModelVersion '1' -LifecycleStage 'created'
            } | Should -Throw '*Illegal lifecycle transition*'
        }

        It 'derives blocked final status and refuses later mutation' {
            $paths = New-RunEvidencePaths -Name 'blocked-finalization'
            @{
                models = @(
                    @{
                        display_name = 'PersonalMasterDataFixed'
                        strict_gate_disposition = 'blocked'
                    }
                )
            } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $paths.MetricsPath -Encoding UTF8
            New-HrAiBuilderRunManifest -RunId 'test-run-001' -TenantKey 'tenant-2' `
                -EnvironmentId '84ad4c54-41d9-e5df-ba07-188b4719594a' -EnvironmentStage DEV `
                -SolutionUniqueName 'caldovahrfrontier' -SolutionVersion '0.0.0.1' `
                -OperatorUpn 'operator@example.invalid' `
                -StartedAtUtc ([datetime]'2026-09-25T08:00:00Z') `
                -CorpusRevision (('a' * 64) -join '') -GeneratorRevision (('b' * 64) -join '') `
                -FieldContractVersion '0.1' -Models @(
                    [pscustomobject]@{ display_name = 'PersonalMasterDataFixed'; model_kind = 'Fixed' }
                ) -CorpusResults @() -OutputPath $paths.ManifestPath -ModelInventoryPath $paths.InventoryPath

            Complete-HrAiBuilderRunManifest -Path $paths.ManifestPath -SolutionVersion '0.0.0.2' `
                -EvidencePaths @($paths.MetricsPath)
            (Get-Content -LiteralPath $paths.ManifestPath -Raw | ConvertFrom-Json).overall_status |
                Should -Be 'blocked'

            {
                Set-HrAiBuilderModelRecord -RunManifestPath $paths.ManifestPath `
                    -ModelInventoryPath $paths.InventoryPath -ModelName 'PersonalMasterDataFixed' `
                    -ModelId 'model-fixed-001' -ModelVersion '1' -LifecycleStage 'blocked'
            } | Should -Throw '*finalized*'
            {
                Complete-HrAiBuilderRunManifest -Path $paths.ManifestPath -SolutionVersion '0.0.0.2' `
                    -EvidencePaths @($paths.MetricsPath)
            } | Should -Throw '*already finalized*'
        }

        It 'derives partially complete when exactly one known model is added to solution and evaluated' {
            $paths = New-RunEvidencePaths -Name 'partially-complete'
            @{
                models = @(
                    @{
                        display_name = 'PersonalMasterDataFixed'
                        strict_gate_disposition = 'evaluated'
                    }
                    @{
                        display_name = 'PersonalMasterDataGeneral'
                        strict_gate_disposition = 'blocked'
                    }
                )
            } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $paths.MetricsPath -Encoding UTF8

            New-HrAiBuilderRunManifest -RunId 'test-run-001' -TenantKey 'tenant-2' `
                -EnvironmentId '84ad4c54-41d9-e5df-ba07-188b4719594a' -EnvironmentStage DEV `
                -SolutionUniqueName 'caldovahrfrontier' -SolutionVersion '0.0.0.1' `
                -OperatorUpn 'operator@example.invalid' `
                -StartedAtUtc ([datetime]'2026-09-25T08:00:00Z') `
                -CorpusRevision (('a' * 64) -join '') -GeneratorRevision (('b' * 64) -join '') `
                -FieldContractVersion '0.1' -Models @(
                    [pscustomobject]@{ display_name = 'PersonalMasterDataFixed'; model_kind = 'Fixed' }
                    [pscustomobject]@{ display_name = 'PersonalMasterDataGeneral'; model_kind = 'General' }
                ) -CorpusResults @() -OutputPath $paths.ManifestPath -ModelInventoryPath $paths.InventoryPath

            foreach ($stage in 'created', 'schema_defined', 'tagged', 'trained', 'evaluated', 'published', 'added_to_solution') {
                Set-HrAiBuilderModelRecord -RunManifestPath $paths.ManifestPath `
                    -ModelInventoryPath $paths.InventoryPath -ModelName 'PersonalMasterDataFixed' `
                    -ModelId 'model-fixed-001' -ModelVersion '1' -LifecycleStage $stage
            }
            Set-HrAiBuilderModelRecord -RunManifestPath $paths.ManifestPath `
                -ModelInventoryPath $paths.InventoryPath -ModelName 'PersonalMasterDataGeneral' `
                -ModelId 'model-general-001' -ModelVersion '1' -LifecycleStage 'created'

            Complete-HrAiBuilderRunManifest -Path $paths.ManifestPath -SolutionVersion '0.0.0.2' `
                -EvidencePaths @($paths.MetricsPath)
            (Get-Content -LiteralPath $paths.ManifestPath -Raw | ConvertFrom-Json).overall_status |
                Should -Be 'partially_complete'
        }

        It 'derives technically complete when both known models are added to solution and evaluated' {
            $paths = New-RunEvidencePaths -Name 'technically-complete'
            @{
                models = @(
                    @{
                        display_name = 'PersonalMasterDataFixed'
                        strict_gate_disposition = 'evaluated'
                    }
                    @{
                        display_name = 'PersonalMasterDataGeneral'
                        strict_gate_disposition = 'evaluated'
                    }
                )
            } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $paths.MetricsPath -Encoding UTF8

            New-HrAiBuilderRunManifest -RunId 'test-run-001' -TenantKey 'tenant-2' `
                -EnvironmentId '84ad4c54-41d9-e5df-ba07-188b4719594a' -EnvironmentStage DEV `
                -SolutionUniqueName 'caldovahrfrontier' -SolutionVersion '0.0.0.1' `
                -OperatorUpn 'operator@example.invalid' `
                -StartedAtUtc ([datetime]'2026-09-25T08:00:00Z') `
                -CorpusRevision (('a' * 64) -join '') -GeneratorRevision (('b' * 64) -join '') `
                -FieldContractVersion '0.1' -Models @(
                    [pscustomobject]@{ display_name = 'PersonalMasterDataFixed'; model_kind = 'Fixed' }
                    [pscustomobject]@{ display_name = 'PersonalMasterDataGeneral'; model_kind = 'General' }
                ) -CorpusResults @() -OutputPath $paths.ManifestPath -ModelInventoryPath $paths.InventoryPath

            foreach ($modelName in 'PersonalMasterDataFixed', 'PersonalMasterDataGeneral') {
                foreach ($stage in 'created', 'schema_defined', 'tagged', 'trained', 'evaluated', 'published', 'added_to_solution') {
                    Set-HrAiBuilderModelRecord -RunManifestPath $paths.ManifestPath `
                        -ModelInventoryPath $paths.InventoryPath -ModelName $modelName `
                        -ModelId ('model-' + $modelName.ToLowerInvariant()) -ModelVersion '1' -LifecycleStage $stage
                }
            }

            Complete-HrAiBuilderRunManifest -Path $paths.ManifestPath -SolutionVersion '0.0.0.2' `
                -EvidencePaths @($paths.MetricsPath)
            (Get-Content -LiteralPath $paths.ManifestPath -Raw | ConvertFrom-Json).overall_status |
                Should -Be 'technically_complete'
        }

        It 'preserves corpus document assignments and ground-truth hashes after finalization' {
            $paths = New-RunEvidencePaths -Name 'preserve-corpus-evidence'
            @{
                models = @(
                    @{
                        display_name = 'PersonalMasterDataFixed'
                        strict_gate_disposition = 'evaluated'
                    }
                    @{
                        display_name = 'PersonalMasterDataGeneral'
                        strict_gate_disposition = 'evaluated'
                    }
                )
            } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $paths.MetricsPath -Encoding UTF8

            $corpusResults = @(
                [pscustomobject]@{
                    model_kind = 'Fixed'
                    documents = @(
                        [pscustomobject]@{
                            document = 'fixed-doc.pdf'
                            assignment = 'held-out'
                            sha256 = ('c' * 64) -join ''
                        }
                    )
                    ground_truth_hashes = [pscustomobject]@{
                        json = ('d' * 64) -join ''
                        csv = ('e' * 64) -join ''
                    }
                }
                [pscustomobject]@{
                    model_kind = 'General'
                    documents = @(
                        [pscustomobject]@{
                            document = 'general-doc.pdf'
                            assignment = 'training'
                            sha256 = ('f' * 64) -join ''
                        }
                    )
                    ground_truth_hashes = [pscustomobject]@{
                        json = ('1' * 64) -join ''
                        csv = ('2' * 64) -join ''
                    }
                }
            )

            New-HrAiBuilderRunManifest -RunId 'test-run-001' -TenantKey 'tenant-2' `
                -EnvironmentId '84ad4c54-41d9-e5df-ba07-188b4719594a' -EnvironmentStage DEV `
                -SolutionUniqueName 'caldovahrfrontier' -SolutionVersion '0.0.0.1' `
                -OperatorUpn 'operator@example.invalid' `
                -StartedAtUtc ([datetime]'2026-09-25T08:00:00Z') `
                -CorpusRevision (('a' * 64) -join '') -GeneratorRevision (('b' * 64) -join '') `
                -FieldContractVersion '0.1' -Models @(
                    [pscustomobject]@{ display_name = 'PersonalMasterDataFixed'; model_kind = 'Fixed' }
                    [pscustomobject]@{ display_name = 'PersonalMasterDataGeneral'; model_kind = 'General' }
                ) -CorpusResults $corpusResults -OutputPath $paths.ManifestPath -ModelInventoryPath $paths.InventoryPath | Out-Null

            foreach ($modelName in 'PersonalMasterDataFixed', 'PersonalMasterDataGeneral') {
                foreach ($stage in 'created', 'schema_defined', 'tagged', 'trained', 'evaluated', 'published', 'added_to_solution') {
                    Set-HrAiBuilderModelRecord -RunManifestPath $paths.ManifestPath `
                        -ModelInventoryPath $paths.InventoryPath -ModelName $modelName `
                        -ModelId ('model-' + $modelName.ToLowerInvariant()) -ModelVersion '1' -LifecycleStage $stage | Out-Null
                }
            }

            Complete-HrAiBuilderRunManifest -Path $paths.ManifestPath -SolutionVersion '0.0.0.2' `
                -EvidencePaths @($paths.MetricsPath) | Out-Null
            $manifest = Get-Content -LiteralPath $paths.ManifestPath -Raw | ConvertFrom-Json
            $fixedModel = @($manifest.models | Where-Object display_name -eq 'PersonalMasterDataFixed')[0]

            @($fixedModel.documents).Count | Should -Be 1
            @($fixedModel.documents)[0].assignment | Should -Be 'held-out'
            $fixedModel.ground_truth_hashes.json | Should -Be ((('d' * 64) -join ''))
            $fixedModel.ground_truth_hashes.csv | Should -Be ((('e' * 64) -join ''))
        }
    }

    Describe 'Initialize-AiBuilderEvidenceRun' {
            BeforeAll {
                $script:RepositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
                $script:InitializerPath = Join-Path $script:RepositoryRoot 'hr\src\scripts\Initialize-AiBuilderEvidenceRun.ps1'
                $script:ModulePath = Join-Path $PSScriptRoot '..\..\src\scripts\modules\Caldova.HrFrontier.AiBuilder\Caldova.HrFrontier.AiBuilder.psd1'
                Import-Module $script:ModulePath -Force
            }

        It 'creates review templates and exits non-zero before visual review exists' {
            $outputDirectory = Join-Path $TestDrive 'run-init'
            $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:InitializerPath `
                -RunId 'test-run-001' `
                -TenantKey 'tenant-2' `
                -EnvironmentId ([guid]'84ad4c54-41d9-e5df-ba07-188b4719594a') `
                -EnvironmentStage DEV `
                -SolutionUniqueName 'caldovahrfrontier' `
                -SolutionVersion '0.0.0.1' `
                -OperatorUpn 'operator@example.invalid' `
                -OutputDirectory $outputDirectory 2>&1
            $exitCode = $LASTEXITCODE

            $exitCode | Should -Not -Be 0
            ($output -join [Environment]::NewLine) | Should -Match 'Visual corpus review is required before qualification\.'
            (Join-Path $outputDirectory 'fixed-review.json') | Should -Exist
            (Join-Path $outputDirectory 'general-review.json') | Should -Exist
        }

        It 'writes qualified corpus, manifest, and inventory files after confirmed review' {
            $outputDirectory = Join-Path $TestDrive 'run-ready'
            $null = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:InitializerPath `
                -RunId 'test-run-001' `
                -TenantKey 'tenant-2' `
                -EnvironmentId ([guid]'84ad4c54-41d9-e5df-ba07-188b4719594a') `
                -EnvironmentStage DEV `
                -SolutionUniqueName 'caldovahrfrontier' `
                -SolutionVersion '0.0.0.1' `
                -OperatorUpn 'operator@example.invalid' `
                -OutputDirectory $outputDirectory 2>&1

            foreach ($reviewName in 'fixed-review.json', 'general-review.json') {
                $reviewPath = Join-Path $outputDirectory $reviewName
                $review = Get-Content -LiteralPath $reviewPath -Raw | ConvertFrom-Json
                foreach ($document in $review.documents) {
                    $document.status = 'confirmed'
                    $document.values_visible = $true
                    $document.absences_confirmed = $true
                    $document.reviewer = 'test-reviewer'
                }
                $review | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $reviewPath -Encoding UTF8
            }

            $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:InitializerPath `
                -RunId 'test-run-001' `
                -TenantKey 'tenant-2' `
                -EnvironmentId ([guid]'84ad4c54-41d9-e5df-ba07-188b4719594a') `
                -EnvironmentStage DEV `
                -SolutionUniqueName 'caldovahrfrontier' `
                -SolutionVersion '0.0.0.1' `
                -OperatorUpn 'operator@example.invalid' `
                -OutputDirectory $outputDirectory 2>&1
            $exitCode = $LASTEXITCODE

            $exitCode | Should -Be 0
            (Join-Path $outputDirectory 'corpus-quality.json') | Should -Exist
            (Join-Path $outputDirectory 'run-manifest.json') | Should -Exist
            (Join-Path $outputDirectory 'model-inventory.json') | Should -Exist
            ((Get-Content -LiteralPath (Join-Path $outputDirectory 'run-manifest.json') -Raw | ConvertFrom-Json).started_at_utc) |
                Should -Match 'Z$'
            ($output -join [Environment]::NewLine) | Should -Match 'Corpus qualification passed\.'
        }

        It 'recreates only the missing review template and preserves a confirmed peer review' {
            $outputDirectory = Join-Path $TestDrive 'run-partial-review'
            $null = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:InitializerPath `
                -RunId 'test-run-001' `
                -TenantKey 'tenant-2' `
                -EnvironmentId ([guid]'84ad4c54-41d9-e5df-ba07-188b4719594a') `
                -EnvironmentStage DEV `
                -SolutionUniqueName 'caldovahrfrontier' `
                -SolutionVersion '0.0.0.1' `
                -OperatorUpn 'operator@example.invalid' `
                -OutputDirectory $outputDirectory 2>&1

            $fixedReviewPath = Join-Path $outputDirectory 'fixed-review.json'
            $generalReviewPath = Join-Path $outputDirectory 'general-review.json'
            $fixedReview = Get-Content -LiteralPath $fixedReviewPath -Raw | ConvertFrom-Json
            $fixedReview.documents[0].status = 'confirmed'
            $fixedReview.documents[0].values_visible = $true
            $fixedReview.documents[0].absences_confirmed = $true
            $fixedReview.documents[0].reviewer = 'preserved-reviewer'
            $fixedReview | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $fixedReviewPath -Encoding UTF8
            Remove-Item -LiteralPath $generalReviewPath -Force

            $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:InitializerPath `
                -RunId 'test-run-001' `
                -TenantKey 'tenant-2' `
                -EnvironmentId ([guid]'84ad4c54-41d9-e5df-ba07-188b4719594a') `
                -EnvironmentStage DEV `
                -SolutionUniqueName 'caldovahrfrontier' `
                -SolutionVersion '0.0.0.1' `
                -OperatorUpn 'operator@example.invalid' `
                -OutputDirectory $outputDirectory 2>&1
            $exitCode = $LASTEXITCODE

            $exitCode | Should -Not -Be 0
            ($output -join [Environment]::NewLine) | Should -Match 'Visual corpus review is required before qualification\.'
            $preservedReview = Get-Content -LiteralPath $fixedReviewPath -Raw | ConvertFrom-Json
            $preservedReview.documents[0].status | Should -Be 'confirmed'
            $preservedReview.documents[0].reviewer | Should -Be 'preserved-reviewer'
            (Get-Content -LiteralPath $generalReviewPath -Raw | ConvertFrom-Json).documents[0].status | Should -Be 'pending'
        }

        It 'refuses to reset an existing manifest and inventory on rerun' {
            $outputDirectory = Join-Path $TestDrive 'run-existing-manifest'
            $fixedPackagePath = Join-Path $script:RepositoryRoot 'hr\docs\ideas\uc-0001-personal-master-data-completion-agent\gf-aib-fixed-template'
            $generalPackagePath = Join-Path $script:RepositoryRoot 'hr\docs\ideas\uc-0001-personal-master-data-completion-agent\gf-aib-general-documents'
            $contractPath = Join-Path $script:RepositoryRoot 'hr\src\ai-builder\contracts\field-contract.json'

            foreach ($pair in @(
                @{ PackagePath = $fixedPackagePath; ReviewPath = (Join-Path $outputDirectory 'fixed-review.json') }
                @{ PackagePath = $generalPackagePath; ReviewPath = (Join-Path $outputDirectory 'general-review.json') }
            )) {
                New-HrAiBuilderCorpusReviewTemplate -PackagePath $pair.PackagePath -OutputPath $pair.ReviewPath | Out-Null
                $review = Get-Content -LiteralPath $pair.ReviewPath -Raw | ConvertFrom-Json
                foreach ($document in $review.documents) {
                    $document.status = 'confirmed'
                    $document.values_visible = $true
                    $document.absences_confirmed = $true
                    $document.reviewer = 'test-reviewer'
                }
                $review | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $pair.ReviewPath -Encoding UTF8
            }

            $fixedCorpusResult = Test-HrAiBuilderCorpus -PackagePath $fixedPackagePath -ModelKind Fixed `
                -ReviewPath (Join-Path $outputDirectory 'fixed-review.json') -FieldContractPath $contractPath
            $generalCorpusResult = Test-HrAiBuilderCorpus -PackagePath $generalPackagePath -ModelKind General `
                -ReviewPath (Join-Path $outputDirectory 'general-review.json') -FieldContractPath $contractPath

            $manifestPath = Join-Path $outputDirectory 'run-manifest.json'
            $inventoryPath = Join-Path $outputDirectory 'model-inventory.json'
            New-HrAiBuilderRunManifest -RunId 'test-run-001' -TenantKey 'tenant-2' `
                -EnvironmentId '84ad4c54-41d9-e5df-ba07-188b4719594a' -EnvironmentStage DEV `
                -SolutionUniqueName 'caldovahrfrontier' -SolutionVersion '0.0.0.1' `
                -OperatorUpn 'operator@example.invalid' `
                -StartedAtUtc ([datetime]'2026-09-25T08:00:00Z') `
                -CorpusRevision (('a' * 64) -join '') -GeneratorRevision (('b' * 64) -join '') `
                -FieldContractVersion '0.1' -Models @(
                    [pscustomobject]@{ display_name = 'PersonalMasterDataFixed'; model_kind = 'Fixed' }
                    [pscustomobject]@{ display_name = 'PersonalMasterDataGeneral'; model_kind = 'General' }
                ) -CorpusResults @($fixedCorpusResult, $generalCorpusResult) -OutputPath $manifestPath -ModelInventoryPath $inventoryPath | Out-Null

            $originalStartedAt = (Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json).started_at_utc
            Set-HrAiBuilderModelRecord -RunManifestPath $manifestPath `
                -ModelInventoryPath $inventoryPath -ModelName 'PersonalMasterDataFixed' `
                -ModelId 'model-fixed-001' -ModelVersion '1' -LifecycleStage 'created' | Out-Null

            $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:InitializerPath `
                -RunId 'test-run-001' `
                -TenantKey 'tenant-2' `
                -EnvironmentId ([guid]'84ad4c54-41d9-e5df-ba07-188b4719594a') `
                -EnvironmentStage DEV `
                -SolutionUniqueName 'caldovahrfrontier' `
                -SolutionVersion '0.0.0.1' `
                -OperatorUpn 'operator@example.invalid' `
                -OutputDirectory $outputDirectory 2>&1
            $exitCode = $LASTEXITCODE

            $exitCode | Should -Not -Be 0
            ($output -join [Environment]::NewLine) | Should -Match 'already exists'
            (Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json).started_at_utc | Should -Be $originalStartedAt
            @((Get-Content -LiteralPath $inventoryPath -Raw | ConvertFrom-Json).models | Where-Object display_name -eq 'PersonalMasterDataFixed')[0].lifecycle_stage |
                Should -Be 'created'
        }
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

    It 'keeps CSV and JSON ground truth equivalent for both supplied packages' {
        foreach ($package in @('gf-aib-fixed-template', 'gf-aib-general-documents')) {
            $root = Join-Path $script:UseCaseRoot $package
            $jsonRows = @(
                (Get-Content -LiteralPath (Join-Path $root 'ground-truth.json') -Raw |
                    ConvertFrom-Json).documents
            )
            $csvRows = @(Import-Csv -LiteralPath (Join-Path $root 'ground-truth.csv'))

            $csvRows.Count | Should -Be $jsonRows.Count
            ($csvRows | ConvertTo-Json -Depth 8) |
                Should -Be ($jsonRows | ConvertTo-Json -Depth 8)
        }
    }

    It 'contains the versioned generator source for each supplied package' {
        $expected = @('gen_fixed.py', 'gen_general.py', 'gen_truth.py', 'personas.py')
        foreach ($package in @('gf-aib-fixed-template', 'gf-aib-general-documents')) {
            $generatorRoot = Join-Path (Join-Path $script:UseCaseRoot $package) 'generators'
            @(
                Get-ChildItem -LiteralPath $generatorRoot -File -Filter '*.py' |
                    Select-Object -ExpandProperty Name |
                    Sort-Object
            ) | Should -Be @($expected | Sort-Object)
        }
    }
}
