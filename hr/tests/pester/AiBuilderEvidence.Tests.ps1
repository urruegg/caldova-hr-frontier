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

    Describe 'AI Builder normalization and evaluation' {
        BeforeAll {
            $script:ModulePath = Join-Path $PSScriptRoot '..\..\src\scripts\modules\Caldova.HrFrontier.AiBuilder\Caldova.HrFrontier.AiBuilder.psd1'
            Import-Module $script:ModulePath -Force

            function New-TestAiBuilderGateSource {
                $contract = Get-Content -LiteralPath $script:ContractPath -Raw | ConvertFrom-Json
                $fixtureRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString())
                New-Item -ItemType Directory -Path $fixtureRoot -Force | Out-Null
                $inputPdfPath = Join-Path $fixtureRoot 'held.pdf'
                $rawExportPath = Join-Path $fixtureRoot 'held.json'
                $schemaEvidencePath = Join-Path $fixtureRoot 'model-schema-fixed.png'
                $adapterScriptPath = Join-Path $fixtureRoot 'ReplayAdapter.ps1'
                'synthetic pdf bytes' | Set-Content -LiteralPath $inputPdfPath -Encoding UTF8
                '{"source":"adapter"}' | Set-Content -LiteralPath $rawExportPath -Encoding UTF8
                'schema-evidence' | Set-Content -LiteralPath $schemaEvidencePath -Encoding UTF8
                @'
param(
    [Parameter(Mandatory)][string]$RawExportDirectory,
    [Parameter(Mandatory)][string]$ModelName,
    [Parameter(Mandatory)][string]$ModelVersion,
    [Parameter(Mandatory)][string]$RunId,
    [Parameter(Mandatory)][string]$Operator,
    [Parameter(Mandatory)][string]$OutputPath
)

Set-StrictMode -Version Latest

$capture = [ordered]@{
    schema_version = '1.0'
    run_id = $RunId
    model_name = $ModelName
    model_version = $ModelVersion
    capture_mechanism = 'AI Builder Quick Test'
    adapter_version = 'test-adapter-1.0'
    adapter_contract = 'replayable-v1'
    adapter_script_path = $PSCommandPath
    adapter_script_sha256 = (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash.ToLowerInvariant()
    raw_export_format = 'test-fixture-json-v1'
    operator = $Operator
    documents = @(
        [ordered]@{
            document = 'held.pdf'
            document_sha256 = [string](Get-Content -LiteralPath (Join-Path $RawExportDirectory 'document-hash.txt') -Raw).Trim()
            collection_or_family = 'a-personalblatt'
            source_export_path = Join-Path $RawExportDirectory 'held.json'
            source_export_sha256 = (Get-FileHash -LiteralPath (Join-Path $RawExportDirectory 'held.json') -Algorithm SHA256).Hash.ToLowerInvariant()
            captured_at_utc = '2026-09-25T08:20:00Z'
            fields = [ordered]@{}
        }
    )
}

$contract = Get-Content -LiteralPath (Join-Path $RawExportDirectory 'field-contract.json') -Raw | ConvertFrom-Json
foreach ($field in $contract.fields) {
    $capture.documents[0].fields[$field.name] = [ordered]@{
        value = $null
        confidence = $null
    }
}

$capture | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
'@ | Set-Content -LiteralPath $adapterScriptPath -Encoding UTF8
                $contract | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $fixtureRoot 'field-contract.json') -Encoding UTF8
                ((Get-FileHash -LiteralPath $inputPdfPath -Algorithm SHA256).Hash.ToLowerInvariant()) |
                    Set-Content -LiteralPath (Join-Path $fixtureRoot 'document-hash.txt') -Encoding UTF8

                $fields = [ordered]@{}
                foreach ($field in $contract.fields) {
                    $fields[$field.name] = [pscustomobject]@{ value = $null; confidence = $null }
                }

                $rows = @(
                    foreach ($field in $contract.fields) {
                        [pscustomobject]@{
                            run_id = 'test-run-001'
                            model_name = 'PersonalMasterDataFixed'
                            model_version = '1'
                            document = 'held.pdf'
                            collection_or_family = 'a-personalblatt'
                            field_name = $field.name
                            field_type = $field.ai_builder_type
                            expected_raw = $null
                            actual_raw = $null
                            expected_normalized = $null
                            actual_normalized = $null
                            confidence = $null
                            expected_present = $false
                            actual_present = $false
                            exact_match = $true
                            error_class = $null
                        }
                    }
                )

                @{
                    CorpusQualification = [pscustomobject]@{
                        status = 'passed'
                        documents = @([pscustomobject]@{
                            document = 'held.pdf'
                            assignment = 'held-out'
                            sha256 = (Get-FileHash -LiteralPath $inputPdfPath -Algorithm SHA256).Hash.ToLowerInvariant()
                            collection_or_family = 'a-personalblatt'
                            source_path = $inputPdfPath
                        })
                    }
                    FieldContract = $contract
                    ModelSchemaRecord = [pscustomobject]@{
                        model_name = 'PersonalMasterDataFixed'
                        model_id = 'model-fixed-001'
                        observed_model_version = 'draft-1'
                        observed_at_utc = '2026-09-25T08:15:00Z'
                        operator = 'operator@example.invalid'
                        fields = @($contract.fields | Select-Object name, ai_builder_type)
                        source_evidence_path = $schemaEvidencePath
                        source_evidence_sha256 = (Get-FileHash -LiteralPath $schemaEvidencePath -Algorithm SHA256).Hash.ToLowerInvariant()
                    }
                    RunManifest = [pscustomobject]@{
                        run_id = 'test-run-001'
                        operator = 'operator@example.invalid'
                        models = @([pscustomobject]@{
                            display_name = 'PersonalMasterDataFixed'
                            model_id = 'model-fixed-001'
                            version = '1'
                            documents = @([pscustomobject]@{
                                document = 'held.pdf'
                                assignment = 'held-out'
                                sha256 = (Get-FileHash -LiteralPath $inputPdfPath -Algorithm SHA256).Hash.ToLowerInvariant()
                                collection_or_family = 'a-personalblatt'
                                source_path = $inputPdfPath
                            })
                        })
                    }
                    PredictionCapture = [pscustomobject]@{
                        schema_version = '1.0'
                        run_id = 'test-run-001'
                        model_name = 'PersonalMasterDataFixed'
                        model_version = '1'
                        capture_mechanism = 'AI Builder Quick Test'
                        adapter_version = 'test-adapter-1.0'
                        adapter_contract = 'replayable-v1'
                        adapter_script_path = $adapterScriptPath
                        adapter_script_sha256 = (Get-FileHash -LiteralPath $adapterScriptPath -Algorithm SHA256).Hash.ToLowerInvariant()
                        raw_export_format = 'test-fixture-json-v1'
                        operator = 'operator@example.invalid'
                        documents = @([pscustomobject]@{
                            document = 'held.pdf'
                            document_sha256 = (Get-FileHash -LiteralPath $inputPdfPath -Algorithm SHA256).Hash.ToLowerInvariant()
                            collection_or_family = 'a-personalblatt'
                            source_export_path = $rawExportPath
                            source_export_sha256 = (Get-FileHash -LiteralPath $rawExportPath -Algorithm SHA256).Hash.ToLowerInvariant()
                            captured_at_utc = '2026-09-25T08:20:00Z'
                            fields = [pscustomobject]$fields
                        })
                    }
                    ValidationRecords = $rows
                }
            }
        }

        It 'records the observed schema without coercing incorrect field names or types' {
            $schemaEvidencePath = Join-Path $TestDrive 'model-schema-observation.txt'
            'observed schema' | Set-Content -LiteralPath $schemaEvidencePath -Encoding UTF8
            $outputPath = Join-Path $TestDrive 'model-schema-record.json'
            $observedFields = @(
                [pscustomobject]@{ name = 'candidate_id'; ai_builder_type = 'Text' }
                [pscustomobject]@{ name = 'wrong_name'; ai_builder_type = 'Date' }
            )

            $record = New-HrAiBuilderModelSchemaRecord `
                -ModelName 'PersonalMasterDataFixed' `
                -ModelId 'model-fixed-001' `
                -ObservedModelVersion 'draft-1' `
                -Operator 'operator@example.invalid' `
                -ObservedAtUtc ([datetime]'2026-09-25T08:15:00Z') `
                -Fields $observedFields `
                -SourceEvidencePath $schemaEvidencePath `
                -OutputPath $outputPath

            $record.fields.Count | Should -Be 2
            $record.fields[1].name | Should -Be 'wrong_name'
            $record.fields[1].ai_builder_type | Should -Be 'Date'
            $record.source_evidence_sha256 | Should -Be (
                (Get-FileHash -LiteralPath $schemaEvidencePath -Algorithm SHA256).Hash.ToLowerInvariant()
            )
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
                [pscustomobject]@{ expected_raw = 'A'; actual_raw = 'A'; expected_present = $true; actual_present = $true; exact_match = $true; error_class = $null; confidence = 0.99; field_name = 'first_name'; collection_or_family = 'fixture' },
                [pscustomobject]@{ expected_raw = 'B'; actual_raw = $null; expected_present = $true; actual_present = $false; exact_match = $false; error_class = 'missing'; confidence = $null; field_name = 'first_name'; collection_or_family = 'fixture' },
                [pscustomobject]@{ expected_raw = $null; actual_raw = 'Invented'; expected_present = $false; actual_present = $true; exact_match = $false; error_class = 'false_value'; confidence = 0.88; field_name = 'first_name'; collection_or_family = 'fixture' },
                [pscustomobject]@{ expected_raw = $null; actual_raw = $null; expected_present = $false; actual_present = $false; exact_match = $true; error_class = $null; confidence = $null; field_name = 'first_name'; collection_or_family = 'fixture' }
            )

            $metrics = Measure-HrAiBuilderEvaluation -ValidationRecords $rows

            $metrics.exact_match_accuracy | Should -Be 0.5
            $metrics.precision | Should -Be 0.5
            $metrics.recall | Should -Be 0.5
            $metrics.missing_field_precision | Should -Be 0.5
            $metrics.false_value_rate | Should -Be 0.5
        }

        It 'derives strict gates from source evidence and blocks false values' {
            $source = New-TestAiBuilderGateSource
            $source.ValidationRecords[0].actual_present = $true
            $source.ValidationRecords[0].actual_raw = 'Invented'
            $source.ValidationRecords[0].actual_normalized = 'Invented'
            $source.ValidationRecords[0].exact_match = $false
            $source.ValidationRecords[0].error_class = 'false_value'
            $source.PredictionCapture.documents[0].fields.candidate_id.value = 'Invented'
            $source.PredictionCapture.documents[0].fields.candidate_id.confidence = 0.88

            $gate = Test-HrAiBuilderStrictGates @source

            $gate.status | Should -Be 'blocked'
            $gate.expected_validation_record_count | Should -Be 17
            $gate.failed_gates | Should -Contain 'zero_false_values'
        }

        It 'blocks contract, attribution, and raw-provenance mismatches' {
            $source = New-TestAiBuilderGateSource
            $source.ModelSchemaRecord.fields[0].name = 'wrong_name'
            (Test-HrAiBuilderStrictGates @source).failed_gates |
                Should -Contain 'exact_field_contract'

            $source = New-TestAiBuilderGateSource
            $source.PredictionCapture.model_version = 'wrong-version'
            (Test-HrAiBuilderStrictGates @source).failed_gates |
                Should -Contain 'complete_attribution'

            $source = New-TestAiBuilderGateSource
            $source.PredictionCapture.documents[0].source_export_sha256 = (('0' * 64) -join '')
            (Test-HrAiBuilderStrictGates @source).failed_gates |
                Should -Contain 'raw_export_provenance'
        }

        It 'rejects a returned value without numeric per-field confidence' {
            $source = New-TestAiBuilderGateSource
            $source.PredictionCapture.documents[0].fields.first_name.value = 'Livia'
            $source.PredictionCapture.documents[0].fields.first_name.confidence = $null

            (Test-HrAiBuilderStrictGates @source).failed_gates |
                Should -Contain 'prediction_capture_schema'
        }

        It 'blocks when retained raw export bytes no longer reproduce the capture' {
            $source = New-TestAiBuilderGateSource
            '{"source":"tampered"}' | Set-Content -LiteralPath $source.PredictionCapture.documents[0].source_export_path -Encoding UTF8

            (Test-HrAiBuilderStrictGates @source).failed_gates |
                Should -Contain 'adapter_replay'
        }

        It 'blocks when capture values are tampered after import' {
            $source = New-TestAiBuilderGateSource
            $source.PredictionCapture.documents[0].fields.first_name.value = 'Tampered'
            $source.PredictionCapture.documents[0].fields.first_name.confidence = 0.42

            (Test-HrAiBuilderStrictGates @source).failed_gates |
                Should -Contain 'adapter_replay'
        }

        It 'blocks when held-out input PDF evidence is missing or hash-mismatched' {
            $source = New-TestAiBuilderGateSource
            Remove-Item -LiteralPath $source.RunManifest.models[0].documents[0].source_path -Force

            (Test-HrAiBuilderStrictGates @source).failed_gates |
                Should -Contain 'held_out_input_provenance'

            $source = New-TestAiBuilderGateSource
            'drifted pdf bytes' | Set-Content -LiteralPath $source.RunManifest.models[0].documents[0].source_path -Encoding UTF8

            (Test-HrAiBuilderStrictGates @source).failed_gates |
                Should -Contain 'held_out_input_provenance'
        }

        It 'blocks when schema source evidence is missing or hash-mismatched' {
            $source = New-TestAiBuilderGateSource
            Remove-Item -LiteralPath $source.ModelSchemaRecord.source_evidence_path -Force

            (Test-HrAiBuilderStrictGates @source).failed_gates |
                Should -Contain 'schema_source_provenance'

            $source = New-TestAiBuilderGateSource
            'drifted schema evidence' | Set-Content -LiteralPath $source.ModelSchemaRecord.source_evidence_path -Encoding UTF8

            (Test-HrAiBuilderStrictGates @source).failed_gates |
                Should -Contain 'schema_source_provenance'
        }

        It 'treats case-drifted schema fields as contract mismatches' {
            $source = New-TestAiBuilderGateSource
            $source.ModelSchemaRecord.fields[0].name = 'Candidate_Id'

            (Test-HrAiBuilderStrictGates @source).failed_gates |
                Should -Contain 'exact_field_contract'
        }
    }

    Describe 'AI Builder import and evaluation scripts' {
        BeforeAll {
            $script:ModulePath = Join-Path $PSScriptRoot '..\..\src\scripts\modules\Caldova.HrFrontier.AiBuilder\Caldova.HrFrontier.AiBuilder.psd1'
            $script:RepositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
            $script:ImportQuickTestResultsPath = Join-Path $script:RepositoryRoot 'hr\src\scripts\Import-AiBuilderQuickTestResults.ps1'
            $script:MeasureEvaluationPath = Join-Path $script:RepositoryRoot 'hr\src\scripts\Measure-AiBuilderEvaluation.ps1'
            $script:FieldContractPath = Join-Path $script:RepositoryRoot 'hr\src\ai-builder\contracts\field-contract.json'
            $script:FieldContract = Get-Content -LiteralPath $script:FieldContractPath -Raw | ConvertFrom-Json
            Import-Module $script:ModulePath -Force

            function New-TestAiBuilderConfirmedCorpusResult {
                param(
                    [Parameter(Mandatory)]
                    [string]$PackagePath,

                    [Parameter(Mandatory)]
                    [string]$ModelKind
                )

                $reviewPath = Join-Path $TestDrive ([guid]::NewGuid().ToString() + '-review.json')
                New-HrAiBuilderCorpusReviewTemplate -PackagePath $PackagePath -OutputPath $reviewPath | Out-Null
                $review = Get-Content -LiteralPath $reviewPath -Raw | ConvertFrom-Json
                foreach ($document in $review.documents) {
                    $document.status = 'confirmed'
                    $document.values_visible = $true
                    $document.absences_confirmed = $true
                    $document.reviewer = 'test-reviewer'
                }
                $review | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $reviewPath -Encoding UTF8

                return Test-HrAiBuilderCorpus -PackagePath $PackagePath -ModelKind $ModelKind `
                    -ReviewPath $reviewPath -FieldContractPath $script:FieldContractPath
            }

            $fixedPackagePath = Join-Path $script:RepositoryRoot 'hr\docs\ideas\uc-0001-personal-master-data-completion-agent\gf-aib-fixed-template'
            $generalPackagePath = Join-Path $script:RepositoryRoot 'hr\docs\ideas\uc-0001-personal-master-data-completion-agent\gf-aib-general-documents'
            $script:FixedCorpusResult = New-TestAiBuilderConfirmedCorpusResult -PackagePath $fixedPackagePath -ModelKind Fixed
            $script:GeneralCorpusResult = New-TestAiBuilderConfirmedCorpusResult -PackagePath $generalPackagePath -ModelKind General

            function New-TestAiBuilderAdapterScript {
                param(
                    [Parameter(Mandatory)]
                    [string]$Path
                )

                @'
param(
    [Parameter(Mandatory)][string]$RawExportDirectory,
    [Parameter(Mandatory)][string]$ModelName,
    [Parameter(Mandatory)][string]$ModelVersion,
    [Parameter(Mandatory)][string]$RunId,
    [Parameter(Mandatory)][string]$Operator,
    [Parameter(Mandatory)][string]$OutputPath
)

Set-StrictMode -Version Latest

$documents = @(
    Get-ChildItem -LiteralPath $RawExportDirectory -Filter '*.json' |
        Sort-Object Name |
        ForEach-Object {
            $json = Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json
            [ordered]@{
                document = [string]$json.document
                document_sha256 = [string]$json.document_sha256
                collection_or_family = [string]$json.collection_or_family
                source_export_path = $_.FullName
                source_export_sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
                captured_at_utc = '2026-09-25T09:00:00Z'
                fields = $json.fields
            }
        }
)

$capture = [ordered]@{
    schema_version = '1.0'
    run_id = $RunId
    model_name = $ModelName
    model_version = $ModelVersion
    capture_mechanism = 'AI Builder Quick Test'
    adapter_version = 'test-adapter-1.0'
    adapter_contract = 'replayable-v1'
    adapter_script_path = $PSCommandPath
    adapter_script_sha256 = (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash.ToLowerInvariant()
    raw_export_format = 'test-fixture-json-v1'
    operator = $Operator
    documents = @($documents)
}

$capture | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
'@ | Set-Content -LiteralPath $Path -Encoding UTF8

                return $Path
            }

            function New-TestAiBuilderEvaluationFixture {
                param(
                    [Parameter(Mandatory)]
                    [ValidateSet('PersonalMasterDataFixed', 'PersonalMasterDataGeneral')]
                    [string]$ModelName,

                    [switch]$UseUnexpectedDocument,

                    [switch]$MissingConfidence
                )

                $root = Join-Path $TestDrive ([guid]::NewGuid().ToString())
                $inputRoot = Join-Path $root 'input'
                $evidenceRoot = Join-Path $root 'evidence'
                $rawExportDirectory = Join-Path $root 'raw'
                New-Item -ItemType Directory -Path $inputRoot, $evidenceRoot, $rawExportDirectory -Force | Out-Null

                $fixedModel = [pscustomobject]@{ display_name = 'PersonalMasterDataFixed'; model_kind = 'Fixed' }
                $generalModel = [pscustomobject]@{ display_name = 'PersonalMasterDataGeneral'; model_kind = 'General' }
                $manifestPath = Join-Path $inputRoot 'run-manifest.json'
                $inventoryPath = Join-Path $inputRoot 'model-inventory.json'
                New-HrAiBuilderRunManifest -RunId 'test-run-001' -TenantKey 'tenant-2' `
                    -EnvironmentId '84ad4c54-41d9-e5df-ba07-188b4719594a' -EnvironmentStage DEV `
                    -SolutionUniqueName 'caldovahrfrontier' -SolutionVersion '0.0.0.1' `
                    -OperatorUpn 'operator@example.invalid' `
                    -StartedAtUtc ([datetime]'2026-09-25T08:00:00Z') `
                    -CorpusRevision (('a' * 64) -join '') -GeneratorRevision (('b' * 64) -join '') `
                    -FieldContractVersion '0.1' -Models @($fixedModel, $generalModel) `
                    -CorpusResults @($script:FixedCorpusResult, $script:GeneralCorpusResult) `
                    -OutputPath $manifestPath -ModelInventoryPath $inventoryPath | Out-Null

                foreach ($modelSpec in @(
                    @{ Name = 'PersonalMasterDataFixed'; Id = 'model-fixed-001'; Version = '1' }
                    @{ Name = 'PersonalMasterDataGeneral'; Id = 'model-general-001'; Version = '1' }
                )) {
                    foreach ($stage in 'created', 'schema_defined', 'tagged', 'trained') {
                        Set-HrAiBuilderModelRecord -RunManifestPath $manifestPath `
                            -ModelInventoryPath $inventoryPath -ModelName $modelSpec.Name `
                            -ModelId $modelSpec.Id -ModelVersion $modelSpec.Version `
                            -LifecycleStage $stage | Out-Null
                    }
                }

                $corpusResult = if ($ModelName -eq 'PersonalMasterDataFixed') { $script:FixedCorpusResult } else { $script:GeneralCorpusResult }
                $groundTruthRoot = if ($ModelName -eq 'PersonalMasterDataFixed') {
                    Join-Path $script:RepositoryRoot 'hr\docs\ideas\uc-0001-personal-master-data-completion-agent\gf-aib-fixed-template'
                }
                else {
                    Join-Path $script:RepositoryRoot 'hr\docs\ideas\uc-0001-personal-master-data-completion-agent\gf-aib-general-documents'
                }
                $groundTruthPath = Join-Path $groundTruthRoot 'ground-truth.json'
                $groundTruth = Get-Content -LiteralPath $groundTruthPath -Raw | ConvertFrom-Json

                $heldOutRows = @()
                foreach ($heldOutDocument in @($corpusResult.documents | Where-Object assignment -eq 'held-out')) {
                    $heldOutRows += @($groundTruth.documents | Where-Object document -eq $heldOutDocument.document)
                }

                foreach ($row in $heldOutRows) {
                    $fieldMap = [ordered]@{}
                    foreach ($field in $script:FieldContract.fields) {
                        $value = [string]$row.($field.name)
                        if ([string]::IsNullOrWhiteSpace($value)) {
                            $fieldMap[$field.name] = [ordered]@{ value = $null; confidence = $null }
                        }
                        else {
                            $fieldMap[$field.name] = [ordered]@{ value = $value; confidence = 0.95 }
                        }
                    }

                    if ($MissingConfidence -and $row.document -eq $heldOutRows[0].document) {
                        $fieldMap['first_name'] = [ordered]@{
                            value = [string]$row.first_name
                            confidence = $null
                        }
                    }

                    $documentName = if ($UseUnexpectedDocument -and $row.document -eq $heldOutRows[0].document) {
                        'unexpected.pdf'
                    }
                    else {
                        [string]$row.document
                    }

                    $rawExport = [ordered]@{
                        document = $documentName
                        document_sha256 = [string]@($corpusResult.documents | Where-Object document -eq $row.document)[0].sha256
                        collection_or_family = [string]$row.collection_or_layout
                        fields = $fieldMap
                    }
                    $rawExportPath = Join-Path $rawExportDirectory ($documentName -replace '\.pdf$', '.json')
                    $rawExport | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $rawExportPath -Encoding UTF8
                }

                $schemaEvidencePath = Join-Path $inputRoot 'model-schema-observation.txt'
                'observed schema' | Set-Content -LiteralPath $schemaEvidencePath -Encoding UTF8
                $modelSchemaRecordPath = Join-Path $inputRoot 'model-schema-record.json'
                $modelId = if ($ModelName -eq 'PersonalMasterDataFixed') {
                    'model-fixed-001'
                }
                else {
                    'model-general-001'
                }
                New-HrAiBuilderModelSchemaRecord -ModelName $ModelName `
                    -ModelId $modelId `
                    -ObservedModelVersion 'draft-1' `
                    -Operator 'operator@example.invalid' `
                    -ObservedAtUtc ([datetime]'2026-09-25T08:15:00Z') `
                    -Fields @($script:FieldContract.fields | Select-Object name, ai_builder_type) `
                    -SourceEvidencePath $schemaEvidencePath `
                    -OutputPath $modelSchemaRecordPath | Out-Null

                $corpusQualityPath = Join-Path $inputRoot 'corpus-quality.json'
                @{
                    schema_version = '1.0'
                    run_id = 'test-run-001'
                    status = 'passed'
                    passed = $true
                    corpora = @($script:FixedCorpusResult, $script:GeneralCorpusResult)
                    documents = @($corpusResult.documents)
                } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $corpusQualityPath -Encoding UTF8

                $adapterPath = New-TestAiBuilderAdapterScript -Path (Join-Path $inputRoot 'TestAdapter.ps1')
                $predictionCapturePath = Join-Path $inputRoot 'prediction-capture.json'

                return [pscustomobject]@{
                    Root = $root
                    InputRoot = $inputRoot
                    EvidenceRoot = $evidenceRoot
                    RawExportDirectory = $rawExportDirectory
                    RunManifestPath = $manifestPath
                    ModelSchemaRecordPath = $modelSchemaRecordPath
                    CorpusQualityPath = $corpusQualityPath
                    GroundTruthPath = $groundTruthPath
                    AdapterPath = $adapterPath
                    PredictionCapturePath = $predictionCapturePath
                    ModelName = $ModelName
                    HeldOutCount = @($corpusResult.documents | Where-Object assignment -eq 'held-out').Count
                    ExpectedValidationRecordCount = @($corpusResult.documents | Where-Object assignment -eq 'held-out').Count * 17
                }
            }

            function Write-TestAiBuilderPredictionCapture {
                param(
                    [Parameter(Mandatory)]
                    [object]$Fixture
                )

                $rawExports = @(
                    Get-ChildItem -LiteralPath $Fixture.RawExportDirectory -Filter '*.json' |
                        Sort-Object Name
                )
                $documents = @(
                    foreach ($rawExport in $rawExports) {
                        $json = Get-Content -LiteralPath $rawExport.FullName -Raw | ConvertFrom-Json
                        [ordered]@{
                            document = [string]$json.document
                            document_sha256 = [string]$json.document_sha256
                            collection_or_family = [string]$json.collection_or_family
                            source_export_path = $rawExport.FullName
                            source_export_sha256 = (Get-FileHash -LiteralPath $rawExport.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
                            captured_at_utc = '2026-09-25T09:00:00Z'
                            fields = $json.fields
                        }
                    }
                )

                @{
                    schema_version = '1.0'
                    run_id = 'test-run-001'
                    model_name = $Fixture.ModelName
                    model_version = '1'
                    capture_mechanism = 'AI Builder Quick Test'
                    adapter_version = 'test-adapter-1.0'
                    adapter_contract = 'replayable-v1'
                    adapter_script_path = $Fixture.AdapterPath
                    adapter_script_sha256 = (Get-FileHash -LiteralPath $Fixture.AdapterPath -Algorithm SHA256).Hash.ToLowerInvariant()
                    raw_export_format = 'test-fixture-json-v1'
                    operator = 'operator@example.invalid'
                    documents = $documents
                } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $Fixture.PredictionCapturePath -Encoding UTF8

                return $Fixture.PredictionCapturePath
            }
        }

        It 'imports retained Quick Test exports into a prediction capture' {
            $fixture = New-TestAiBuilderEvaluationFixture -ModelName 'PersonalMasterDataFixed'

            $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:ImportQuickTestResultsPath `
                -RunManifestPath $fixture.RunManifestPath `
                -ModelSchemaRecordPath $fixture.ModelSchemaRecordPath `
                -RawExportDirectory $fixture.RawExportDirectory `
                -AdapterScriptPath $fixture.AdapterPath `
                -TargetModelName $fixture.ModelName `
                -OutputPath $fixture.PredictionCapturePath 2>&1
            $exitCode = $LASTEXITCODE

            $exitCode | Should -Be 0
            $fixture.PredictionCapturePath | Should -Exist
            @((Get-Content -LiteralPath $fixture.PredictionCapturePath -Raw | ConvertFrom-Json).documents).Count |
                Should -Be $fixture.HeldOutCount
        }

        It 'rejects a capture document not present in the held-out allocation' {
            $fixture = New-TestAiBuilderEvaluationFixture -ModelName 'PersonalMasterDataFixed' -UseUnexpectedDocument

            $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:ImportQuickTestResultsPath `
                -RunManifestPath $fixture.RunManifestPath `
                -ModelSchemaRecordPath $fixture.ModelSchemaRecordPath `
                -RawExportDirectory $fixture.RawExportDirectory `
                -AdapterScriptPath $fixture.AdapterPath `
                -TargetModelName $fixture.ModelName `
                -OutputPath $fixture.PredictionCapturePath 2>&1
            $exitCode = $LASTEXITCODE

            $exitCode | Should -Not -Be 0
            ($output -join [Environment]::NewLine) | Should -Match 'held-out allocation'
        }

        It 'rejects duplicate capture documents before promotion' {
            $fixture = New-TestAiBuilderEvaluationFixture -ModelName 'PersonalMasterDataFixed'
            Write-TestAiBuilderPredictionCapture -Fixture $fixture | Out-Null
            $capture = Get-Content -LiteralPath $fixture.PredictionCapturePath -Raw | ConvertFrom-Json
            $capture.documents[-1] = $capture.documents[0]
            $capture | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $fixture.PredictionCapturePath -Encoding UTF8

            $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:MeasureEvaluationPath `
                -RunManifestPath $fixture.RunManifestPath `
                -CorpusQualityPath $fixture.CorpusQualityPath `
                -FieldContractPath $script:FieldContractPath `
                -ModelSchemaRecordPath $fixture.ModelSchemaRecordPath `
                -PredictionCapturePath $fixture.PredictionCapturePath `
                -GroundTruthPath $fixture.GroundTruthPath `
                -EvidenceDirectory $fixture.EvidenceRoot 2>&1
            $exitCode = $LASTEXITCODE

            $exitCode | Should -Not -Be 0
            ($output -join [Environment]::NewLine) | Should -Match 'held_out_document_coverage'
        }

        It 'writes a blocked import summary when the raw export directory is missing' {
            $fixture = New-TestAiBuilderEvaluationFixture -ModelName 'PersonalMasterDataFixed'
            Remove-Item -LiteralPath $fixture.RawExportDirectory -Recurse -Force
            $summaryPath = Join-Path $fixture.InputRoot 'prediction-capture-summary.md'

            $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:ImportQuickTestResultsPath `
                -RunManifestPath $fixture.RunManifestPath `
                -ModelSchemaRecordPath $fixture.ModelSchemaRecordPath `
                -RawExportDirectory $fixture.RawExportDirectory `
                -AdapterScriptPath $fixture.AdapterPath `
                -TargetModelName $fixture.ModelName `
                -OutputPath $fixture.PredictionCapturePath 2>&1
            $exitCode = $LASTEXITCODE

            $exitCode | Should -Not -Be 0
            $summaryPath | Should -Exist
            $summary = Get-Content -LiteralPath $summaryPath -Raw
            $summary | Should -Match 'Raw export directory'
            $summary | Should -Match ([regex]::Escape($fixture.RawExportDirectory))
            ($output -join [Environment]::NewLine) | Should -Match 'was not found'
        }

        It 'writes a blocked import summary when the adapter contract is unsupported' {
            $fixture = New-TestAiBuilderEvaluationFixture -ModelName 'PersonalMasterDataFixed'
            $adapterScript = Get-Content -LiteralPath $fixture.AdapterPath -Raw
            $adapterScript = $adapterScript -replace "adapter_contract = 'replayable-v1'", "adapter_contract = 'unsupported-v1'"
            $adapterScript = $adapterScript -replace "raw_export_format = 'test-fixture-json-v1'", "raw_export_format = 'unsupported-format-v1'"
            Set-Content -LiteralPath $fixture.AdapterPath -Value $adapterScript -Encoding UTF8
            $summaryPath = Join-Path $fixture.InputRoot 'prediction-capture-summary.md'

            $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:ImportQuickTestResultsPath `
                -RunManifestPath $fixture.RunManifestPath `
                -ModelSchemaRecordPath $fixture.ModelSchemaRecordPath `
                -RawExportDirectory $fixture.RawExportDirectory `
                -AdapterScriptPath $fixture.AdapterPath `
                -TargetModelName $fixture.ModelName `
                -OutputPath $fixture.PredictionCapturePath 2>&1
            $exitCode = $LASTEXITCODE

            $exitCode | Should -Not -Be 0
            $summaryPath | Should -Exist
            (Get-Content -LiteralPath $summaryPath -Raw) | Should -Match 'unsupported'
            ($output -join [Environment]::NewLine) | Should -Match 'unsupported'
        }

        It 'derives <ExpectedValidationRecordCount> validation rows for <ModelName>' -TestCases @(
            @{ ModelName = 'PersonalMasterDataFixed'; ExpectedValidationRecordCount = 68 }
            @{ ModelName = 'PersonalMasterDataGeneral'; ExpectedValidationRecordCount = 136 }
        ) {
            param($ModelName, $ExpectedValidationRecordCount)

            $fixture = New-TestAiBuilderEvaluationFixture -ModelName $ModelName
            Write-TestAiBuilderPredictionCapture -Fixture $fixture | Out-Null

            $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:MeasureEvaluationPath `
                -RunManifestPath $fixture.RunManifestPath `
                -CorpusQualityPath $fixture.CorpusQualityPath `
                -FieldContractPath $script:FieldContractPath `
                -ModelSchemaRecordPath $fixture.ModelSchemaRecordPath `
                -PredictionCapturePath $fixture.PredictionCapturePath `
                -GroundTruthPath $fixture.GroundTruthPath `
                -EvidenceDirectory $fixture.EvidenceRoot 2>&1
            $exitCode = $LASTEXITCODE

            $exitCode | Should -Be 0
            $results = Get-Content -LiteralPath (Join-Path $fixture.EvidenceRoot 'validation-results.json') -Raw | ConvertFrom-Json
            @($results.models)[0].validation_record_count | Should -Be $ExpectedValidationRecordCount
        }

        It 'treats a case-only value difference as incorrect' {
            $fixture = New-TestAiBuilderEvaluationFixture -ModelName 'PersonalMasterDataFixed'
            $rawExportPath = @(Get-ChildItem -LiteralPath $fixture.RawExportDirectory -Filter '*.json' | Sort-Object Name)[0].FullName
            $rawExport = Get-Content -LiteralPath $rawExportPath -Raw | ConvertFrom-Json
            $originalValue = [string]$rawExport.fields.first_name.value
            $rawExport.fields.first_name.value = $originalValue.Substring(0, 1).ToLowerInvariant() + $originalValue.Substring(1)
            $rawExport | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $rawExportPath -Encoding UTF8
            Write-TestAiBuilderPredictionCapture -Fixture $fixture | Out-Null
            $capture = Get-Content -LiteralPath $fixture.PredictionCapturePath -Raw | ConvertFrom-Json

            $null = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:MeasureEvaluationPath `
                -RunManifestPath $fixture.RunManifestPath `
                -CorpusQualityPath $fixture.CorpusQualityPath `
                -FieldContractPath $script:FieldContractPath `
                -ModelSchemaRecordPath $fixture.ModelSchemaRecordPath `
                -PredictionCapturePath $fixture.PredictionCapturePath `
                -GroundTruthPath $fixture.GroundTruthPath `
                -EvidenceDirectory $fixture.EvidenceRoot 2>&1
            $LASTEXITCODE | Should -Be 0

            $validationDocument = Get-Content -LiteralPath (Join-Path $fixture.EvidenceRoot 'validation-results.json') -Raw | ConvertFrom-Json
            $row = @($validationDocument.models[0].records | Where-Object {
                    $_.document -eq $capture.documents[0].document -and $_.field_name -eq 'first_name'
                })[0]

            $row.exact_match | Should -BeFalse
            $row.error_class | Should -Be 'incorrect'
        }

        It 'merges fixed and general model evidence without overwriting either model record' {
            $evidenceDirectory = Join-Path $TestDrive 'combined-evidence'
            New-Item -ItemType Directory -Path $evidenceDirectory -Force | Out-Null
            $fixedFixture = New-TestAiBuilderEvaluationFixture -ModelName 'PersonalMasterDataFixed'
            $generalFixture = New-TestAiBuilderEvaluationFixture -ModelName 'PersonalMasterDataGeneral'
            Write-TestAiBuilderPredictionCapture -Fixture $fixedFixture | Out-Null
            Write-TestAiBuilderPredictionCapture -Fixture $generalFixture | Out-Null

            foreach ($fixture in @($fixedFixture, $generalFixture)) {
                $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:MeasureEvaluationPath `
                    -RunManifestPath $fixture.RunManifestPath `
                    -CorpusQualityPath $fixture.CorpusQualityPath `
                    -FieldContractPath $script:FieldContractPath `
                    -ModelSchemaRecordPath $fixture.ModelSchemaRecordPath `
                    -PredictionCapturePath $fixture.PredictionCapturePath `
                    -GroundTruthPath $fixture.GroundTruthPath `
                    -EvidenceDirectory $evidenceDirectory 2>&1
                $LASTEXITCODE | Should -Be 0
            }

            $results = Get-Content -LiteralPath (Join-Path $evidenceDirectory 'validation-results.json') -Raw | ConvertFrom-Json
            @($results.models.model_name | Sort-Object) | Should -Be @('PersonalMasterDataFixed', 'PersonalMasterDataGeneral')
            $metrics = Get-Content -LiteralPath (Join-Path $evidenceDirectory 'evaluation-metrics.json') -Raw | ConvertFrom-Json
            @($metrics.models.display_name | Sort-Object) | Should -Be @('PersonalMasterDataFixed', 'PersonalMasterDataGeneral')
        }

        It 'rejects a second write for the same run model and version' {
            $evidenceDirectory = Join-Path $TestDrive 'duplicate-evidence'
            New-Item -ItemType Directory -Path $evidenceDirectory -Force | Out-Null
            $fixture = New-TestAiBuilderEvaluationFixture -ModelName 'PersonalMasterDataFixed'
            Write-TestAiBuilderPredictionCapture -Fixture $fixture | Out-Null

            $null = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:MeasureEvaluationPath `
                -RunManifestPath $fixture.RunManifestPath `
                -CorpusQualityPath $fixture.CorpusQualityPath `
                -FieldContractPath $script:FieldContractPath `
                -ModelSchemaRecordPath $fixture.ModelSchemaRecordPath `
                -PredictionCapturePath $fixture.PredictionCapturePath `
                -GroundTruthPath $fixture.GroundTruthPath `
                -EvidenceDirectory $evidenceDirectory 2>&1

            $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:MeasureEvaluationPath `
                -RunManifestPath $fixture.RunManifestPath `
                -CorpusQualityPath $fixture.CorpusQualityPath `
                -FieldContractPath $script:FieldContractPath `
                -ModelSchemaRecordPath $fixture.ModelSchemaRecordPath `
                -PredictionCapturePath $fixture.PredictionCapturePath `
                -GroundTruthPath $fixture.GroundTruthPath `
                -EvidenceDirectory $evidenceDirectory 2>&1
            $exitCode = $LASTEXITCODE

            $exitCode | Should -Not -Be 0
            ($output -join [Environment]::NewLine) | Should -Match 'already exists'
            @((Get-Content -LiteralPath (Join-Path $evidenceDirectory 'evaluation-metrics.json') -Raw | ConvertFrom-Json).models).Count |
                Should -Be 1
        }

        It 'blocks duplicate validation rows that substitute one held-out document for another' {
            $fixture = New-TestAiBuilderEvaluationFixture -ModelName 'PersonalMasterDataFixed'
            Write-TestAiBuilderPredictionCapture -Fixture $fixture | Out-Null

            $null = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:MeasureEvaluationPath `
                -RunManifestPath $fixture.RunManifestPath `
                -CorpusQualityPath $fixture.CorpusQualityPath `
                -FieldContractPath $script:FieldContractPath `
                -ModelSchemaRecordPath $fixture.ModelSchemaRecordPath `
                -PredictionCapturePath $fixture.PredictionCapturePath `
                -GroundTruthPath $fixture.GroundTruthPath `
                -EvidenceDirectory $fixture.EvidenceRoot 2>&1
            $LASTEXITCODE | Should -Be 0

            $validationDocument = Get-Content -LiteralPath (Join-Path $fixture.EvidenceRoot 'validation-results.json') -Raw | ConvertFrom-Json
            $records = @($validationDocument.models[0].records)
            $documentNames = @($records.document | Select-Object -Unique)
            $recordsForFirstDocument = @($records | Where-Object document -eq $documentNames[0])
            $recordsForSecondDocument = @($records | Where-Object document -eq $documentNames[1])
            $mutatedRecords = @(
                $records |
                    Where-Object document -notin @($documentNames[1]) |
                    ForEach-Object { $_ }
            ) + @($recordsForFirstDocument)

            $gate = Test-HrAiBuilderStrictGates `
                -CorpusQualification (Get-Content -LiteralPath $fixture.CorpusQualityPath -Raw | ConvertFrom-Json) `
                -FieldContract (Get-Content -LiteralPath $script:FieldContractPath -Raw | ConvertFrom-Json) `
                -ModelSchemaRecord (Get-Content -LiteralPath $fixture.ModelSchemaRecordPath -Raw | ConvertFrom-Json) `
                -RunManifest (Get-Content -LiteralPath $fixture.RunManifestPath -Raw | ConvertFrom-Json) `
                -PredictionCapture (Get-Content -LiteralPath $fixture.PredictionCapturePath -Raw | ConvertFrom-Json) `
                -ValidationRecords $mutatedRecords

            $gate.failed_gates | Should -Contain 'document_field_coverage'
            $recordsForSecondDocument.Count | Should -Be 17
        }

        It 'writes a blocked summary before returning non-zero from an invalid capture' {
            $fixture = New-TestAiBuilderEvaluationFixture -ModelName 'PersonalMasterDataFixed' -MissingConfidence
            Write-TestAiBuilderPredictionCapture -Fixture $fixture | Out-Null

            $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:MeasureEvaluationPath `
                -RunManifestPath $fixture.RunManifestPath `
                -CorpusQualityPath $fixture.CorpusQualityPath `
                -FieldContractPath $script:FieldContractPath `
                -ModelSchemaRecordPath $fixture.ModelSchemaRecordPath `
                -PredictionCapturePath $fixture.PredictionCapturePath `
                -GroundTruthPath $fixture.GroundTruthPath `
                -EvidenceDirectory $fixture.EvidenceRoot 2>&1
            $exitCode = $LASTEXITCODE

            $exitCode | Should -Not -Be 0
            (Join-Path $fixture.EvidenceRoot 'evaluation-summary.md') | Should -Exist
            $summary = Get-Content -LiteralPath (Join-Path $fixture.EvidenceRoot 'evaluation-summary.md') -Raw
            $summary | Should -Match 'Blocked'
            $summary | Should -Match 'prediction_capture_schema'
        }

        It 'preserves a blocked capture and writes a blocked import summary when adapter output is invalid' {
            $fixture = New-TestAiBuilderEvaluationFixture -ModelName 'PersonalMasterDataFixed' -MissingConfidence
            $summaryPath = Join-Path $fixture.InputRoot 'prediction-capture-summary.md'

            $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:ImportQuickTestResultsPath `
                -RunManifestPath $fixture.RunManifestPath `
                -ModelSchemaRecordPath $fixture.ModelSchemaRecordPath `
                -RawExportDirectory $fixture.RawExportDirectory `
                -AdapterScriptPath $fixture.AdapterPath `
                -TargetModelName $fixture.ModelName `
                -OutputPath $fixture.PredictionCapturePath 2>&1
            $exitCode = $LASTEXITCODE

            $blockedCapturePath = $fixture.PredictionCapturePath + '.blocked.json'
            $exitCode | Should -Not -Be 0
            $blockedCapturePath | Should -Exist
            $summaryPath | Should -Exist
            (Get-Content -LiteralPath $summaryPath -Raw) | Should -Match ([regex]::Escape($blockedCapturePath))
            ($output -join [Environment]::NewLine) | Should -Match 'violates the capture contract'
        }
    }
}
