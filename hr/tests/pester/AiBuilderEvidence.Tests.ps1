Set-StrictMode -Version Latest

Describe 'AI Builder JSON runtime compatibility' {
    It 'uses command capability detection before passing DateKind' {
        $repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
        $modulePath = Join-Path $repositoryRoot 'hr\src\scripts\modules\Caldova.HrFrontier.AiBuilder\Caldova.HrFrontier.AiBuilder.psm1'
        $moduleText = Get-Content -LiteralPath $modulePath -Raw

        $moduleText | Should -Match "Parameters\.ContainsKey\('DateKind'\)"
        $moduleText | Should -Not -Match 'PSVersion\.Major -ge 7'
    }
}

function script:Set-TestUtf8BomContent {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Content
    )

    $utf8Bom = [System.Text.UTF8Encoding]::new($true)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8Bom)
}

Describe 'AI Builder fixed holdout consumption initialization' {
    BeforeAll {
        $script:HoldoutRepositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
        $script:HoldoutModulePath = Join-Path $script:HoldoutRepositoryRoot 'hr\src\scripts\modules\Caldova.HrFrontier.AiBuilder\Caldova.HrFrontier.AiBuilder.psd1'
        $script:HoldoutEvidenceRoot = Join-Path $script:HoldoutRepositoryRoot 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001'
        $script:ExpectedFixedHoldouts = @(
            [pscustomobject]@{ document = 'a06-CAND-2026-0416-gerber.pdf'; sha256 = '4b1110d9c394a709fbcf6dc39c3ebf20846114e4bb2f818e7dad0118e52ac5db' }
            [pscustomobject]@{ document = 'b06-CAND-2026-0422-schnyder.pdf'; sha256 = '2dd65e48932173a72cbfc0cad0f1bbe01b997e6a28eea60f5a2e8c5d2737a8b6' }
            [pscustomobject]@{ document = 'c06-CAND-2026-0428-frei.pdf'; sha256 = 'dc512e6545293d6532effc196f56322f12cc1b2a89ef3eb31c46c90b1ddcece4' }
            [pscustomobject]@{ document = 'd06-CAND-2026-0434-ochsner.pdf'; sha256 = '5ccc73225f0b12c937ea46d1f0566c5869e38f2756c73dc0b648044203fa74fa' }
        )
        Import-Module $script:HoldoutModulePath -Force

        function New-TestHoldoutInitializationFixture {
            $root = Join-Path $TestDrive ([guid]::NewGuid().ToString())
            $captureRoot = Join-Path $root 'capture'
            New-Item -ItemType Directory -Path $captureRoot -Force | Out-Null

            $manifestPath = Join-Path $root 'run-manifest.json'
            $inventoryPath = Join-Path $root 'model-inventory.json'
            $capabilityPath = Join-Path $root 'capture-capability.json'
            $outputPath = Join-Path $root 'holdout-consumption.json'

            Copy-Item -LiteralPath (Join-Path $script:HoldoutEvidenceRoot 'run-manifest.json') -Destination $manifestPath
            Copy-Item -LiteralPath (Join-Path $script:HoldoutEvidenceRoot 'model-inventory.json') -Destination $inventoryPath
            Copy-Item -LiteralPath (Join-Path $script:HoldoutEvidenceRoot 'capture-capability.json') -Destination $capabilityPath
            foreach ($path in @($manifestPath, $inventoryPath)) {
                $text = Get-Content -LiteralPath $path -Raw
                $convertFromJson = Get-Command ConvertFrom-Json -ErrorAction Stop
                $document = if ($convertFromJson.Parameters.ContainsKey('DateKind')) {
                    $text | ConvertFrom-Json -DateKind String
                }
                else {
                    $text | ConvertFrom-Json
                }
                $model = @($document.models | Where-Object display_name -ceq 'PersonalMasterDataFixed')[0]
                $model.lifecycle_stage = 'capture_validated'
                $captureValidatedIndex = [Array]::IndexOf(
                    [string[]]@($model.lifecycle_history.stage),
                    [string]'capture_validated'
                )
                $model.lifecycle_history = @($model.lifecycle_history)[0..$captureValidatedIndex]
                $document | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $path -Encoding UTF8
            }

            [pscustomobject]@{
                Root = $root
                CaptureRoot = $captureRoot
                ManifestPath = $manifestPath
                InventoryPath = $inventoryPath
                CapabilityPath = $capabilityPath
                OutputPath = $outputPath
            }
        }

        function Invoke-TestHoldoutInitialization {
            param(
                [Parameter(Mandatory)][object]$Fixture,
                [string]$CapabilitySha256 = ''
            )

            if (-not $CapabilitySha256) {
                $CapabilitySha256 = (Get-FileHash -LiteralPath $Fixture.CapabilityPath -Algorithm SHA256).Hash.ToLowerInvariant()
            }

            New-HrAiBuilderHoldoutConsumptionLedger `
                -RunManifestPath $Fixture.ManifestPath `
                -ModelInventoryPath $Fixture.InventoryPath `
                -CaptureCapabilityPath $Fixture.CapabilityPath `
                -CaptureCapabilitySha256 $CapabilitySha256 `
                -CaptureRootPath $Fixture.CaptureRoot `
                -AuthorizationSource 'User instruction dated 2026-09-30' `
                -AuthorizedAtUtc ([datetime]'2026-09-30T11:38:13.945Z') `
                -OutputPath $Fixture.OutputPath
        }

        function Get-TestBooleanValues {
            param([object]$Value)

            if ($Value -is [bool]) {
                return ,$Value
            }

            if ($null -eq $Value -or $Value -is [string] -or $Value -is [ValueType]) {
                return @()
            }

            if ($Value -is [System.Collections.IEnumerable]) {
                return @($Value | ForEach-Object { Get-TestBooleanValues -Value $_ })
            }

            return @(
                $Value.PSObject.Properties |
                    ForEach-Object { Get-TestBooleanValues -Value $_.Value }
            )
        }
    }

    It 'creates a hash-bound unseen ledger for exactly the four authorized fixed holdouts' {
        $fixture = New-TestHoldoutInitializationFixture
        Invoke-TestHoldoutInitialization -Fixture $fixture | Out-Null

        $ledger = Get-Content -LiteralPath $fixture.OutputPath -Raw | ConvertFrom-Json
        $actual = @($ledger.holdouts | ForEach-Object { '{0}|{1}' -f $_.document, $_.sha256 })
        $expected = @($script:ExpectedFixedHoldouts | ForEach-Object { '{0}|{1}' -f $_.document, $_.sha256 })

        $actual | Should -Be $expected
        @($ledger.holdouts).Count | Should -Be 4
        @($ledger.holdouts.state | Select-Object -Unique) | Should -Be @('unseen')
        $ledger.model.name | Should -Be 'PersonalMasterDataFixed'
        $ledger.model.id | Should -Be '74b09a72-d1f1-4598-bc4d-3746d5c97acc'
        $ledger.model.version | Should -Be '1.0'
        $ledger.corpus_revision | Should -Be 'c0310c527f010cc9a24d7a78dae7db1e5ad136116b14306413162fb4223926db'
        $ledger.capture_capability.status | Should -Be 'passed'
        $ledger.capture_capability.decision | Should -Be 'capture_validated'
        $ledger.capture_capability.sha256 | Should -Be (
            (Get-FileHash -LiteralPath $fixture.CapabilityPath -Algorithm SHA256).Hash.ToLowerInvariant()
        )
        $ledger.authorization_scope.scope | Should -Be 'exactly_once_submission_of_the_listed_fixed_holdouts_only'
        @($ledger.authorization_scope.authorized_documents) | Should -Be @($script:ExpectedFixedHoldouts.document)
        @(Get-TestBooleanValues -Value $ledger).Count | Should -Be 0
    }

    It 'rejects a capability decision that is not passed' {
        $fixture = New-TestHoldoutInitializationFixture
        $capability = Get-Content -LiteralPath $fixture.CapabilityPath -Raw | ConvertFrom-Json
        $capability.status = 'blocked'
        $capability | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $fixture.CapabilityPath -Encoding UTF8

        { Invoke-TestHoldoutInitialization -Fixture $fixture } |
            Should -Throw '*capture capability status must be passed*'
        $fixture.OutputPath | Should -Not -Exist
    }

    It 'rejects a capture capability whose bytes do not match the authorized hash' {
        $fixture = New-TestHoldoutInitializationFixture

        { Invoke-TestHoldoutInitialization -Fixture $fixture -CapabilitySha256 ('0' * 64) } |
            Should -Throw '*capture capability SHA-256 does not match*'
        $fixture.OutputPath | Should -Not -Exist
    }

    It 'rejects initialization unless the fixed model lifecycle is capture_validated' {
        $fixture = New-TestHoldoutInitializationFixture
        $inventory = Get-Content -LiteralPath $fixture.InventoryPath -Raw | ConvertFrom-Json
        ($inventory.models | Where-Object display_name -eq 'PersonalMasterDataFixed').lifecycle_stage = 'blocked'
        $inventory | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $fixture.InventoryPath -Encoding UTF8

        { Invoke-TestHoldoutInitialization -Fixture $fixture } |
            Should -Throw '*lifecycle stage must be capture_validated*'
        $fixture.OutputPath | Should -Not -Exist
    }

    It 'rejects initialization when an existing capture pair references a fixed holdout' {
        $fixture = New-TestHoldoutInitializationFixture
        $pairDirectory = Join-Path $fixture.CaptureRoot 'existing'
        New-Item -ItemType Directory -Path $pairDirectory -Force | Out-Null
        $pair = Get-Content -LiteralPath (
            Join-Path $script:HoldoutEvidenceRoot 'capture\cap-20260930094537354Z-34bf8987\capture-pair.json'
        ) -Raw | ConvertFrom-Json
        $pair.source.filename = $script:ExpectedFixedHoldouts[0].document
        $pair.source.sha256 = $script:ExpectedFixedHoldouts[0].sha256
        $pair | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath (Join-Path $pairDirectory 'capture-pair.json') -Encoding UTF8

        { Invoke-TestHoldoutInitialization -Fixture $fixture } |
            Should -Throw '*already references fixed holdout*'
        $fixture.OutputPath | Should -Not -Exist
    }

    It 'rejects duplicate, extra, and missing fixed holdout manifest rows' -ForEach @(
        @{ Mutation = 'duplicate' }
        @{ Mutation = 'extra' }
        @{ Mutation = 'missing' }
    ) {
        $fixture = New-TestHoldoutInitializationFixture
        $manifest = Get-Content -LiteralPath $fixture.ManifestPath -Raw | ConvertFrom-Json
        $model = $manifest.models | Where-Object display_name -eq 'PersonalMasterDataFixed'
        $heldOut = @($model.documents | Where-Object assignment -eq 'held-out')

        if ($Mutation -eq 'duplicate') {
            $model.documents = @($model.documents) + @($heldOut[0])
        }
        elseif ($Mutation -eq 'extra') {
            $extra = $heldOut[0].PSObject.Copy()
            $extra.document = 'x99-not-authorized.pdf'
            $extra.sha256 = ('f' * 64)
            $model.documents = @($model.documents) + @($extra)
        }
        else {
            $model.documents = @($model.documents | Where-Object document -ne $heldOut[0].document)
        }
        $manifest | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $fixture.ManifestPath -Encoding UTF8

        { Invoke-TestHoldoutInitialization -Fixture $fixture } |
            Should -Throw '*exactly the four authorized fixed holdouts*'
        $fixture.OutputPath | Should -Not -Exist
    }

    It 'does not overwrite an existing holdout ledger' {
        $fixture = New-TestHoldoutInitializationFixture
        $original = '{"sentinel":"preserve"}'
        Set-Content -LiteralPath $fixture.OutputPath -Value $original -Encoding UTF8

        { Invoke-TestHoldoutInitialization -Fixture $fixture } |
            Should -Throw '*already exists*'
        (Get-Content -LiteralPath $fixture.OutputPath -Raw).Trim() | Should -Be $original
    }
}

Describe 'AI Builder fixed holdout captured transition' -Tag 'HoldoutCaptureTransition' {
    BeforeAll {
        $script:TransitionRepositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
        $script:TransitionModulePath = Join-Path $script:TransitionRepositoryRoot 'hr\src\scripts\modules\Caldova.HrFrontier.AiBuilder\Caldova.HrFrontier.AiBuilder.psd1'
        $script:TransitionEvidenceRoot = Join-Path $script:TransitionRepositoryRoot 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001'
        $script:TransitionCaptureRunId = 'cap-20260930114811428Z-ed0cd329'
        $script:TransitionDocument = 'a06-CAND-2026-0416-gerber.pdf'
        $script:TransitionSourceSha256 = '4b1110d9c394a709fbcf6dc39c3ebf20846114e4bb2f818e7dad0118e52ac5db'
        $script:TransitionPlatformRunId = '08584108379654495821756934301CU29'
        $script:TransitionCapturePairLocator = 'capture\fixed-holdout\cap-20260930114811428Z-ed0cd329\capture-pair.json'
        Import-Module $script:TransitionModulePath -Force

        function New-TestHoldoutCaptureTransitionFixture {
            $root = Join-Path $TestDrive ([guid]::NewGuid().ToString())
            $captureDirectory = Join-Path $root 'capture\fixed-holdout\cap-20260930114811428Z-ed0cd329'
            New-Item -ItemType Directory -Path (Split-Path -Parent $captureDirectory) -Force | Out-Null
            Copy-Item -LiteralPath (
                Join-Path $script:TransitionEvidenceRoot 'capture\fixed-holdout\cap-20260930114811428Z-ed0cd329'
            ) -Destination $captureDirectory -Recurse

            $ledgerPath = Join-Path $root 'holdout-consumption.json'
            Copy-Item -LiteralPath (Join-Path $script:TransitionEvidenceRoot 'holdout-consumption.json') -Destination $ledgerPath
            $fixtureLedger = Get-Content -LiteralPath $ledgerPath -Raw | ConvertFrom-Json
            foreach ($holdout in $fixtureLedger.holdouts) {
                $holdout.state = 'unseen'
                foreach ($propertyName in @(
                    'execution_run_id',
                    'platform_run_id',
                    'capture_pair_path',
                    'capture_pair_sha256',
                    'raw_sha256',
                    'canonical_sha256',
                    'captured_at_utc'
                )) {
                    $holdout.PSObject.Properties.Remove($propertyName)
                }
            }
            $fixtureLedger | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $ledgerPath -Encoding UTF8

            [pscustomobject]@{
                Root = $root
                LedgerPath = $ledgerPath
                CaptureDirectory = $captureDirectory
                CapturePairPath = Join-Path $captureDirectory 'capture-pair.json'
                RunManifestPath = Join-Path $script:TransitionEvidenceRoot 'run-manifest.json'
                FieldContractPath = Join-Path $script:TransitionRepositoryRoot 'hr\src\ai-builder\contracts\field-contract.json'
                ModelSchemaRecordPath = Join-Path $script:TransitionEvidenceRoot 'model-schema-fixed.json'
                AdapterScriptPath = Join-Path $script:TransitionRepositoryRoot 'hr\src\scripts\adapters\ConvertFrom-HrAiBuilderEvaluationCapture.ps1'
            }
        }

        function Invoke-TestHoldoutCaptureTransition {
            param(
                [Parameter(Mandatory)][object]$Fixture,
                [string]$Document = $script:TransitionDocument,
                [string]$SourceSha256 = $script:TransitionSourceSha256,
                [string]$ExecutionRunId = $script:TransitionCaptureRunId,
                [string]$PlatformRunId = $script:TransitionPlatformRunId,
                [string]$CapturePairLocator = $script:TransitionCapturePairLocator,
                [string]$CapturePairSha256 = '',
                [AllowNull()][string]$CurrentFlowState = 'Off'
            )

            if (-not $CapturePairSha256) {
                $CapturePairSha256 = (Get-FileHash -LiteralPath $Fixture.CapturePairPath -Algorithm SHA256).Hash.ToLowerInvariant()
            }

            Set-HrAiBuilderHoldoutCaptured `
                -LedgerPath $Fixture.LedgerPath `
                -Document $Document `
                -SourceSha256 $SourceSha256 `
                -ExecutionRunId $ExecutionRunId `
                -PlatformRunId $PlatformRunId `
                -CaptureDirectory $Fixture.CaptureDirectory `
                -CapturePairPath $Fixture.CapturePairPath `
                -CapturePairLocator $CapturePairLocator `
                -CapturePairSha256 $CapturePairSha256 `
                -RunManifestPath $Fixture.RunManifestPath `
                -FieldContractPath $Fixture.FieldContractPath `
                -ModelSchemaRecordPath $Fixture.ModelSchemaRecordPath `
                -ModelName 'PersonalMasterDataFixed' `
                -ModelVersion '1.0' `
                -Operator 'admin@caldova25668747.onmicrosoft.com' `
                -AdapterScriptPath $Fixture.AdapterScriptPath `
                -CurrentFlowState $CurrentFlowState
        }

        function Get-TestFileBase64 {
            param([Parameter(Mandatory)][string]$Path)
            return [Convert]::ToBase64String([IO.File]::ReadAllBytes($Path))
        }

        function Read-TestJsonPreservingDates {
            param([Parameter(Mandatory)][string]$Path)

            $content = Get-Content -LiteralPath $Path -Raw
            $command = Get-Command ConvertFrom-Json -ErrorAction Stop
            if ($command.Parameters.ContainsKey('DateKind')) {
                return $content | ConvertFrom-Json -DateKind String
            }
            return $content | ConvertFrom-Json
        }
    }

    It 'captures exactly one independently validated unseen row and preserves all other ledger evidence' {
        $fixture = New-TestHoldoutCaptureTransitionFixture
        $before = Read-TestJsonPreservingDates -Path $fixture.LedgerPath
        $beforeAuthorization = $before.authorization_scope | ConvertTo-Json -Depth 20 -Compress
        $beforeInitialization = [string]$before.initialized_at_utc
        $beforeUntouched = @($before.holdouts | Select-Object -Skip 1 | ForEach-Object {
            $_ | ConvertTo-Json -Depth 10 -Compress
        })
        $pairSha256 = (Get-FileHash -LiteralPath $fixture.CapturePairPath -Algorithm SHA256).Hash.ToLowerInvariant()

        Invoke-TestHoldoutCaptureTransition -Fixture $fixture | Out-Null

        $after = Read-TestJsonPreservingDates -Path $fixture.LedgerPath
        $captured = @($after.holdouts | Where-Object state -eq 'captured')
        $captured.Count | Should -Be 1
        $captured[0].document | Should -Be $script:TransitionDocument
        $captured[0].sha256 | Should -Be $script:TransitionSourceSha256
        $captured[0].execution_run_id | Should -Be $script:TransitionCaptureRunId
        $captured[0].platform_run_id | Should -Be $script:TransitionPlatformRunId
        $captured[0].capture_pair_path | Should -Be $script:TransitionCapturePairLocator
        $captured[0].capture_pair_sha256 | Should -Be $pairSha256
        $captured[0].raw_sha256 | Should -Be '5853d642de33cd4beb46fb008be25c3e0e7e547c5211ea1a7aefca3424232e23'
        $captured[0].canonical_sha256 | Should -Be '531e7522b8896cc44c8b4179eb49eba6394e2cd96ffa008575b51adc6be78f48'
        $captured[0].captured_at_utc | Should -Be '2026-09-30T11:48:59.5749931Z'
        @($after.holdouts | Where-Object state -eq 'unseen').Count | Should -Be 3
        @($after.holdouts | Select-Object -Skip 1 | ForEach-Object {
            $_ | ConvertTo-Json -Depth 10 -Compress
        }) | Should -Be $beforeUntouched
        ($after.authorization_scope | ConvertTo-Json -Depth 20 -Compress) | Should -Be $beforeAuthorization
        $after.initialized_at_utc | Should -Be $beforeInitialization
    }

    It 'rejects a row that is no longer unseen without changing the ledger' -ForEach @(
        @{ State = 'captured' }
        @{ State = 'evaluated' }
        @{ State = 'consumed_by_model_change' }
    ) {
        $fixture = New-TestHoldoutCaptureTransitionFixture
        $ledger = Get-Content -LiteralPath $fixture.LedgerPath -Raw | ConvertFrom-Json
        $ledger.holdouts[0].state = $State
        $ledger | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $fixture.LedgerPath -Encoding UTF8
        $before = Get-TestFileBase64 -Path $fixture.LedgerPath

        { Invoke-TestHoldoutCaptureTransition -Fixture $fixture } |
            Should -Throw '*must be unseen*'
        (Get-TestFileBase64 -Path $fixture.LedgerPath) | Should -Be $before
    }

    It 'rejects wrong target identity or capture correlation without changing the ledger' -ForEach @(
        @{ Mutation = 'filename'; ExpectedMessage = '*document and source SHA-256 must identify exactly one ledger row*' }
        @{ Mutation = 'source_hash'; ExpectedMessage = '*document and source SHA-256 must identify exactly one ledger row*' }
        @{ Mutation = 'execution_run'; ExpectedMessage = '*execution run ID does not match*' }
        @{ Mutation = 'pair_locator'; ExpectedMessage = '*capture-pair locator does not match*' }
        @{ Mutation = 'pair_hash'; ExpectedMessage = '*capture-pair SHA-256 does not match*' }
    ) {
        $fixture = New-TestHoldoutCaptureTransitionFixture
        $arguments = @{
            Fixture = $fixture
            Document = $script:TransitionDocument
            SourceSha256 = $script:TransitionSourceSha256
            ExecutionRunId = $script:TransitionCaptureRunId
            CapturePairLocator = $script:TransitionCapturePairLocator
            CapturePairSha256 = (Get-FileHash -LiteralPath $fixture.CapturePairPath -Algorithm SHA256).Hash.ToLowerInvariant()
        }
        switch ($Mutation) {
            'filename' { $arguments.Document = 'b06-CAND-2026-0422-schnyder.pdf' }
            'source_hash' { $arguments.SourceSha256 = ('0' * 64) }
            'execution_run' { $arguments.ExecutionRunId = 'cap-20260930114811428Z-wrong000' }
            'pair_locator' { $arguments.CapturePairLocator = 'capture\fixed-holdout\wrong\capture-pair.json' }
            'pair_hash' { $arguments.CapturePairSha256 = ('f' * 64) }
        }
        $before = Get-TestFileBase64 -Path $fixture.LedgerPath

        { Invoke-TestHoldoutCaptureTransition @arguments } | Should -Throw $ExpectedMessage
        (Get-TestFileBase64 -Path $fixture.LedgerPath) | Should -Be $before
    }

    It 'rejects a failed independent pair validation without changing the ledger' {
        $fixture = New-TestHoldoutCaptureTransitionFixture
        Add-Content -LiteralPath (
            Join-Path $fixture.CaptureDirectory "$($script:TransitionCaptureRunId).canonical.json"
        ) -Value 'tampered'
        $before = Get-TestFileBase64 -Path $fixture.LedgerPath

        { Invoke-TestHoldoutCaptureTransition -Fixture $fixture } |
            Should -Throw '*independent capture-pair validation must pass*'
        (Get-TestFileBase64 -Path $fixture.LedgerPath) | Should -Be $before
    }

    It 'rejects missing capture evidence without changing the ledger' {
        $fixture = New-TestHoldoutCaptureTransitionFixture
        Remove-Item -LiteralPath $fixture.CapturePairPath -Force
        $before = Get-TestFileBase64 -Path $fixture.LedgerPath

        { Invoke-TestHoldoutCaptureTransition -Fixture $fixture -CapturePairSha256 ('0' * 64) } |
            Should -Throw '*capture-pair evidence*'
        (Get-TestFileBase64 -Path $fixture.LedgerPath) | Should -Be $before
    }

    It 'rejects a current flow state other than Off without changing the ledger' {
        $fixture = New-TestHoldoutCaptureTransitionFixture
        $before = Get-TestFileBase64 -Path $fixture.LedgerPath

        { Invoke-TestHoldoutCaptureTransition -Fixture $fixture -CurrentFlowState 'On' } |
            Should -Throw '*current flow state must be Off*'
        (Get-TestFileBase64 -Path $fixture.LedgerPath) | Should -Be $before
    }

    It 'rejects an overwrite attempt after a successful transition' {
        $fixture = New-TestHoldoutCaptureTransitionFixture
        Invoke-TestHoldoutCaptureTransition -Fixture $fixture | Out-Null
        $afterFirstWrite = Get-TestFileBase64 -Path $fixture.LedgerPath

        { Invoke-TestHoldoutCaptureTransition -Fixture $fixture } |
            Should -Throw '*must be unseen*'
        (Get-TestFileBase64 -Path $fixture.LedgerPath) | Should -Be $afterFirstWrite
    }
}

Describe 'AI Builder fixed holdout evaluated transition' -Tag 'HoldoutEvaluationTransition' {
    BeforeAll {
        $script:EvaluationTransitionRepositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
        $script:EvaluationTransitionEvidenceRoot = Join-Path $script:EvaluationTransitionRepositoryRoot 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001'
        $script:EvaluationTransitionModulePath = Join-Path $script:EvaluationTransitionRepositoryRoot 'hr\src\scripts\modules\Caldova.HrFrontier.AiBuilder\Caldova.HrFrontier.AiBuilder.psd1'
        Import-Module $script:EvaluationTransitionModulePath -Force

        function New-TestHoldoutEvaluationTransitionFixture {
            $root = Join-Path $TestDrive ([guid]::NewGuid().ToString())
            New-Item -ItemType Directory -Path $root -Force | Out-Null
            $ledgerPath = Join-Path $root 'holdout-consumption.json'
            $metricsPath = Join-Path $root 'evaluation-metrics.json'
            Copy-Item -LiteralPath (Join-Path $script:EvaluationTransitionEvidenceRoot 'holdout-consumption.json') -Destination $ledgerPath
            Copy-Item -LiteralPath (Join-Path $script:EvaluationTransitionEvidenceRoot 'evaluation-metrics.json') -Destination $metricsPath
            $ledger = Get-Content -LiteralPath $ledgerPath -Raw | ConvertFrom-Json
            foreach ($row in $ledger.holdouts) {
                $row.state = 'captured'
                foreach ($propertyName in @(
                    'evaluation_metrics_path',
                    'evaluation_metrics_sha256',
                    'evaluated_at_utc'
                )) {
                    $row.PSObject.Properties.Remove($propertyName)
                }
            }
            $ledger | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $ledgerPath -Encoding UTF8

            return [pscustomobject]@{
                LedgerPath = $ledgerPath
                MetricsPath = $metricsPath
            }
        }

        function Get-TestEvaluationTransitionBase64 {
            param([Parameter(Mandatory)][string]$Path)
            return [Convert]::ToBase64String([IO.File]::ReadAllBytes($Path))
        }
    }

    It 'atomically marks all four captured holdouts evaluated from exact passing metrics' {
        $fixture = New-TestHoldoutEvaluationTransitionFixture
        $metricsSha256 = (Get-FileHash -LiteralPath $fixture.MetricsPath -Algorithm SHA256).Hash.ToLowerInvariant()

        Set-HrAiBuilderHoldoutsEvaluated `
            -LedgerPath $fixture.LedgerPath `
            -EvaluationMetricsPath $fixture.MetricsPath `
            -EvaluationMetricsSha256 $metricsSha256 `
            -ModelName 'PersonalMasterDataFixed' `
            -ModelVersion '1.0' | Out-Null

        $ledger = Get-Content -LiteralPath $fixture.LedgerPath -Raw | ConvertFrom-Json
        @($ledger.holdouts).Count | Should -Be 4
        @($ledger.holdouts | Where-Object state -ceq 'evaluated').Count | Should -Be 4
        foreach ($row in $ledger.holdouts) {
            $row.execution_run_id | Should -Not -BeNullOrEmpty
            $row.capture_pair_sha256 | Should -Match '^[a-f0-9]{64}$'
            $row.evaluation_metrics_path | Should -Be 'evaluation-metrics.json'
            $row.evaluation_metrics_sha256 | Should -Be $metricsSha256
            $row.evaluated_at_utc | Should -Not -BeNullOrEmpty
        }
    }

    It 'rejects blocked metrics without changing the ledger' {
        $fixture = New-TestHoldoutEvaluationTransitionFixture
        $metrics = Get-Content -LiteralPath $fixture.MetricsPath -Raw | ConvertFrom-Json
        $metrics.models[0].strict_gate_disposition = 'blocked'
        $metrics.models[0].failed_gates = @('prediction_capture_schema')
        $metrics | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $fixture.MetricsPath -Encoding UTF8
        $before = Get-TestEvaluationTransitionBase64 -Path $fixture.LedgerPath

        {
            Set-HrAiBuilderHoldoutsEvaluated `
                -LedgerPath $fixture.LedgerPath `
                -EvaluationMetricsPath $fixture.MetricsPath `
                -EvaluationMetricsSha256 (Get-FileHash -LiteralPath $fixture.MetricsPath -Algorithm SHA256).Hash.ToLowerInvariant() `
                -ModelName 'PersonalMasterDataFixed' `
                -ModelVersion '1.0'
        } | Should -Throw '*strict evaluation disposition must be evaluated*'
        (Get-TestEvaluationTransitionBase64 -Path $fixture.LedgerPath) | Should -Be $before
    }

    It 'rejects a non-captured holdout without changing the ledger' {
        $fixture = New-TestHoldoutEvaluationTransitionFixture
        $ledger = Get-Content -LiteralPath $fixture.LedgerPath -Raw | ConvertFrom-Json
        $ledger.holdouts[0].state = 'unseen'
        $ledger | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $fixture.LedgerPath -Encoding UTF8
        $before = Get-TestEvaluationTransitionBase64 -Path $fixture.LedgerPath

        {
            Set-HrAiBuilderHoldoutsEvaluated `
                -LedgerPath $fixture.LedgerPath `
                -EvaluationMetricsPath $fixture.MetricsPath `
                -EvaluationMetricsSha256 (Get-FileHash -LiteralPath $fixture.MetricsPath -Algorithm SHA256).Hash.ToLowerInvariant() `
                -ModelName 'PersonalMasterDataFixed' `
                -ModelVersion '1.0'
        } | Should -Throw '*all four holdouts must be captured*'
        (Get-TestEvaluationTransitionBase64 -Path $fixture.LedgerPath) | Should -Be $before
    }

    It 'rejects a metrics hash mismatch without changing the ledger' {
        $fixture = New-TestHoldoutEvaluationTransitionFixture
        $before = Get-TestEvaluationTransitionBase64 -Path $fixture.LedgerPath

        {
            Set-HrAiBuilderHoldoutsEvaluated `
                -LedgerPath $fixture.LedgerPath `
                -EvaluationMetricsPath $fixture.MetricsPath `
                -EvaluationMetricsSha256 ('0' * 64) `
                -ModelName 'PersonalMasterDataFixed' `
                -ModelVersion '1.0'
        } | Should -Throw '*metrics SHA-256 does not match*'
        (Get-TestEvaluationTransitionBase64 -Path $fixture.LedgerPath) | Should -Be $before
    }
}

Describe 'AI Builder fixed model solution approval eligibility' -Tag 'FixedApprovalEligibility' {
    BeforeAll {
        $script:ApprovalRepositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
        $script:ApprovalEvidenceRoot = Join-Path $script:ApprovalRepositoryRoot 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001'
        $script:ApprovalModulePath = Join-Path $script:ApprovalRepositoryRoot 'hr\src\scripts\modules\Caldova.HrFrontier.AiBuilder\Caldova.HrFrontier.AiBuilder.psd1'
        Import-Module $script:ApprovalModulePath -Force
    }

    It 'calculates approval eligibility from the complete retained fixed-model evidence' {
        $outputPath = Join-Path $TestDrive 'fixed-approval-eligibility.json'
        (Get-Command Test-HrAiBuilderFixedApprovalEligibility).Parameters.ContainsKey('CurrentFlowState') |
            Should -BeFalse

        $result = Test-HrAiBuilderFixedApprovalEligibility `
            -EvidenceRoot $script:ApprovalEvidenceRoot `
            -ModelName 'PersonalMasterDataFixed' `
            -ModelId '74b09a72-d1f1-4598-bc4d-3746d5c97acc' `
            -ModelVersion '1.0' `
            -OutputPath $outputPath

        $result.status | Should -Be 'eligible'
        @($result.failed_gates).Count | Should -Be 0
        $result.calculated.records | Should -Be 68
        $result.calculated.false_value_count | Should -Be 0
        $result.calculated.evaluated_holdout_count | Should -Be 4
        $result.calculated.consumed_holdout_count | Should -Be 0
        $result.calculated.flow_state | Should -Be 'Off'
        $result.calculated.security_status | Should -Be 'passed'
        $result.hashes.evaluation_metrics_sha256 | Should -Match '^[a-f0-9]{64}$'
        $result.hashes.prediction_capture_sha256 | Should -Match '^[a-f0-9]{64}$'
        $result.hashes.holdout_ledger_sha256 | Should -Match '^[a-f0-9]{64}$'
        Test-Path -LiteralPath $outputPath -PathType Leaf | Should -BeTrue
    }
}

Describe 'AI Builder observed capture replay projection' {
    BeforeAll {
        $script:ReplayRepositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
        $script:ReplayModulePath = Join-Path $script:ReplayRepositoryRoot 'hr\src\scripts\modules\Caldova.HrFrontier.AiBuilder\Caldova.HrFrontier.AiBuilder.psd1'
        $script:ReplayFixtureRoot = Join-Path $script:ReplayRepositoryRoot 'hr\tests\fixtures\ai-builder\evaluation-capture'
        $script:ReplayRawFixturePath = Join-Path $script:ReplayFixtureRoot 'process-documents-response.json'
        $script:ReplayCanonicalFixturePath = Join-Path $script:ReplayFixtureRoot 'canonical-envelope.json'
        $script:ReplayContractPath = Join-Path $script:ReplayRepositoryRoot 'hr\src\ai-builder\contracts\field-contract.json'
        $script:RetainedReplayRoot = Join-Path $script:ReplayRepositoryRoot 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001'
        $script:RetainedCaptureDirectory = Join-Path $script:RetainedReplayRoot 'capture\cap-20260930094537354Z-34bf8987'
        $script:ReplaySourcePath = Join-Path $script:RetainedCaptureDirectory 'source\a01-CAND-2026-0411-brunner.pdf'
        $script:RetainedReplayHash = '627dc0d4cc26b288ebbcd4109688972f14d7a23ed1f98eee7b2009e47a8fe3f7'
        $script:RetainedHoldout1Directory = Join-Path $script:RetainedReplayRoot 'capture\fixed-holdout\cap-20260930114811428Z-ed0cd329'
        $script:RetainedHoldout1Hash = '531e7522b8896cc44c8b4179eb49eba6394e2cd96ffa008575b51adc6be78f48'
        $script:RetainedHoldout2Directory = Join-Path $script:RetainedReplayRoot 'capture\fixed-holdout\cap-20260930123933155Z-211c905d'
        $script:RetainedHoldout2Hash = '4592ef6706799053fd604917d4fdbffa37ef6f53569eb0bd6663ef15bedc15a9'
        $script:ReplayFieldNames = @(
            (Get-Content -LiteralPath $script:ReplayContractPath -Raw | ConvertFrom-Json).fields.name
        )
        Import-Module $script:ReplayModulePath -Force

        function Update-TestReplayPairHashes {
            param([Parameter(Mandatory)][object]$Fixture)

            $pair = Get-Content -LiteralPath $Fixture.PairPath -Raw | ConvertFrom-Json
            $pair.raw.sha256 = (Get-FileHash -LiteralPath $Fixture.RawPath -Algorithm SHA256).Hash.ToLowerInvariant()
            $pair.raw.size_bytes = (Get-Item -LiteralPath $Fixture.RawPath).Length
            $pair.canonical.sha256 = (Get-FileHash -LiteralPath $Fixture.CanonicalPath -Algorithm SHA256).Hash.ToLowerInvariant()
            $pair.canonical.size_bytes = (Get-Item -LiteralPath $Fixture.CanonicalPath).Length
            Set-TestUtf8NoBomContent -Path $Fixture.PairPath -Content ($pair | ConvertTo-Json -Depth 12)
        }

        function New-TestObservedCaptureFixture {
            $root = Join-Path $TestDrive ([guid]::NewGuid().ToString())
            $captureRoot = Join-Path $root 'capture'
            $captureDirectory = Join-Path $captureRoot 'cap-20260930000000000Z-00000000'
            $sourceDirectory = Join-Path $captureDirectory 'source'
            New-Item -ItemType Directory -Path $sourceDirectory -Force | Out-Null

            $rawPath = Join-Path $captureDirectory 'cap-20260930000000000Z-00000000.ai-builder.raw.json'
            $canonicalPath = Join-Path $captureDirectory 'cap-20260930000000000Z-00000000.canonical.json'
            $sourcePath = Join-Path $sourceDirectory 'a01-CAND-2026-0411-brunner.pdf'
            Copy-Item -LiteralPath $script:ReplayRawFixturePath -Destination $rawPath
            Copy-Item -LiteralPath $script:ReplayCanonicalFixturePath -Destination $canonicalPath
            Copy-Item -LiteralPath $script:ReplaySourcePath -Destination $sourcePath

            $contract = Get-Content -LiteralPath $script:ReplayContractPath -Raw | ConvertFrom-Json
            $contractPath = Join-Path $root 'field-contract.json'
            Set-TestUtf8NoBomContent -Path $contractPath -Content ($contract | ConvertTo-Json -Depth 12)
            $manifestPath = Join-Path $root 'run-manifest.json'
            $manifest = [ordered]@{
                schema_version = '1.0'
                run_id = 'fixture-evaluation-run-001'
                operator = 'operator@example.invalid'
                corpus_revision = 'c0310c527f010cc9a24d7a78dae7db1e5ad136116b14306413162fb4223926db'
                models = @(
                    [ordered]@{
                        display_name = 'PersonalMasterDataFixed'
                        model_kind = 'Fixed'
                        model_id = '00000000-0000-0000-0000-000000000001'
                        version = '1.0'
                        documents = @(
                            [ordered]@{
                                document = 'a01-CAND-2026-0411-brunner.pdf'
                                collection_or_family = 'a-personalblatt'
                                assignment = 'training'
                                sha256 = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash.ToLowerInvariant()
                                source_path = $sourcePath
                            }
                        )
                    }
                )
            }
            Set-TestUtf8NoBomContent -Path $manifestPath -Content ($manifest | ConvertTo-Json -Depth 12)

            $schemaPath = Join-Path $root 'model-schema-fixed.json'
            $schema = [ordered]@{
                schema_version = '1.0'
                model_name = 'PersonalMasterDataFixed'
                model_id = '00000000-0000-0000-0000-000000000001'
                observed_model_version = '1.0'
                operator = 'operator@example.invalid'
                observed_at_utc = '2026-09-30T00:00:00Z'
                fields = @($contract.fields | ForEach-Object {
                    [ordered]@{ name = [string]$_.name; ai_builder_type = [string]$_.ai_builder_type }
                })
            }
            Set-TestUtf8NoBomContent -Path $schemaPath -Content ($schema | ConvertTo-Json -Depth 12)

            $pairPath = Join-Path $captureDirectory 'capture-pair.json'
            $pair = [ordered]@{
                schema_version = '1.0'
                run_id = 'cap-20260930000000000Z-00000000'
                capture_stage = 'training-proof'
                operator_upn = 'operator@example.invalid'
                captured_at_utc = '2026-09-30T00:00:00.0000000Z'
                corpus_revision = $manifest.corpus_revision
                model = [ordered]@{
                    name = 'PersonalMasterDataFixed'
                    id = '00000000-0000-0000-0000-000000000001'
                    version = '1.0'
                }
                source = [ordered]@{
                    local_path = 'capture\cap-20260930000000000Z-00000000\source\a01-CAND-2026-0411-brunner.pdf'
                    filename = 'a01-CAND-2026-0411-brunner.pdf'
                    size_bytes = (Get-Item -LiteralPath $sourcePath).Length
                    sha256 = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash.ToLowerInvariant()
                }
                raw = [ordered]@{
                    local_path = 'capture\cap-20260930000000000Z-00000000\cap-20260930000000000Z-00000000.ai-builder.raw.json'
                    size_bytes = (Get-Item -LiteralPath $rawPath).Length
                    sha256 = (Get-FileHash -LiteralPath $rawPath -Algorithm SHA256).Hash.ToLowerInvariant()
                }
                canonical = [ordered]@{
                    local_path = 'capture\cap-20260930000000000Z-00000000\cap-20260930000000000Z-00000000.canonical.json'
                    size_bytes = (Get-Item -LiteralPath $canonicalPath).Length
                    sha256 = (Get-FileHash -LiteralPath $canonicalPath -Algorithm SHA256).Hash.ToLowerInvariant()
                }
            }
            Set-TestUtf8NoBomContent -Path $pairPath -Content ($pair | ConvertTo-Json -Depth 12)

            return [pscustomobject]@{
                Root = $root
                CaptureDirectory = $captureDirectory
                SourcePath = $sourcePath
                RawPath = $rawPath
                CanonicalPath = $canonicalPath
                PairPath = $pairPath
                ManifestPath = $manifestPath
                ContractPath = $contractPath
                SchemaPath = $schemaPath
                OutputPath = Join-Path $root 'prediction-capture.json'
            }
        }

        function Invoke-TestObservedCaptureReplay {
            param([Parameter(Mandatory)][object]$Fixture)

            ConvertFrom-HrAiBuilderEvaluationCapture `
                -CaptureDirectory $Fixture.CaptureDirectory `
                -RunManifestPath $Fixture.ManifestPath `
                -FieldContractPath $Fixture.ContractPath `
                -ModelSchemaRecordPath $Fixture.SchemaPath `
                -ModelName 'PersonalMasterDataFixed' `
                -ModelVersion '1.0' `
                -Operator 'operator@example.invalid' `
                -OutputPath $Fixture.OutputPath
        }

        function Copy-TestObservedCaptureFixture {
            param(
                [Parameter(Mandatory)][object]$Fixture,
                [Parameter(Mandatory)][string]$RunId,
                [string]$RelativeParent = ''
            )

            $captureRoot = Split-Path -Parent $Fixture.CaptureDirectory
            $destinationParent = if ($RelativeParent) {
                Join-Path $captureRoot $RelativeParent
            }
            else {
                $captureRoot
            }
            New-Item -ItemType Directory -Path $destinationParent -Force | Out-Null
            $destination = Join-Path $destinationParent $RunId
            Copy-Item -LiteralPath $Fixture.CaptureDirectory -Destination $destination -Recurse
            $oldRunId = Split-Path -Leaf $Fixture.CaptureDirectory
            $oldRawPath = Join-Path $destination ($oldRunId + '.ai-builder.raw.json')
            $oldCanonicalPath = Join-Path $destination ($oldRunId + '.canonical.json')
            $newRawPath = Join-Path $destination ($RunId + '.ai-builder.raw.json')
            $newCanonicalPath = Join-Path $destination ($RunId + '.canonical.json')
            Move-Item -LiteralPath $oldRawPath -Destination $newRawPath
            Move-Item -LiteralPath $oldCanonicalPath -Destination $newCanonicalPath

            $canonical = [IO.File]::ReadAllText(
                $newCanonicalPath,
                [Text.UTF8Encoding]::new($false, $true)
            ) | ConvertFrom-Json
            $canonical.run_id = $RunId
            [IO.File]::WriteAllBytes(
                $newCanonicalPath,
                (InModuleScope Caldova.HrFrontier.AiBuilder -Parameters @{ Canonical = $canonical } {
                    param($Canonical)
                    ConvertTo-HrAiBuilderCanonicalJson -InputObject $Canonical
                })
            )

            $pairPath = Join-Path $destination 'capture-pair.json'
            $pair = Get-Content -LiteralPath $pairPath -Raw | ConvertFrom-Json
            $pair.run_id = $RunId
            $portableCapturePath = (@('capture', $RelativeParent, $RunId) |
                Where-Object { $_ }) -join '\'
            $pair.raw.local_path = "$portableCapturePath\$RunId.ai-builder.raw.json"
            $pair.raw.sha256 = (Get-FileHash -LiteralPath $newRawPath -Algorithm SHA256).Hash.ToLowerInvariant()
            $pair.raw.size_bytes = (Get-Item -LiteralPath $newRawPath).Length
            $pair.canonical.local_path = "$portableCapturePath\$RunId.canonical.json"
            $pair.canonical.sha256 = (Get-FileHash -LiteralPath $newCanonicalPath -Algorithm SHA256).Hash.ToLowerInvariant()
            $pair.canonical.size_bytes = (Get-Item -LiteralPath $newCanonicalPath).Length
            $pair.source.local_path = "$portableCapturePath\source\a01-CAND-2026-0411-brunner.pdf"
            Set-TestUtf8NoBomContent -Path $pairPath -Content ($pair | ConvertTo-Json -Depth 12)

            return $destination
        }
    }

    It 'provides the three deterministic replay functions' {
        InModuleScope Caldova.HrFrontier.AiBuilder {
            Get-Command ConvertTo-HrAiBuilderCanonicalJson -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }
        Get-Command Test-HrAiBuilderCapturePair -ErrorAction Stop | Should -Not -BeNullOrEmpty
        Get-Command ConvertFrom-HrAiBuilderEvaluationCapture -ErrorAction Stop | Should -Not -BeNullOrEmpty
    }

    It 'projects the observed response into the exact ordered prediction capture' {
        $fixture = New-TestObservedCaptureFixture

        $result = Invoke-TestObservedCaptureReplay -Fixture $fixture

        $result.status | Should -Be 'passed' -Because ($result.failed_gates -join ', ')
        $capture = Get-Content -LiteralPath $fixture.OutputPath -Raw | ConvertFrom-Json
        $capture.run_id | Should -BeExactly 'fixture-evaluation-run-001'
        $capture.model_name | Should -BeExactly 'PersonalMasterDataFixed'
        $capture.model_version | Should -BeExactly '1.0'
        $capture.capture_mechanism | Should -BeExactly 'Power Automate Process documents'
        $capture.adapter_contract | Should -BeExactly 'replayable-v2'
        $capture.raw_export_format | Should -BeExactly 'ai-builder-process-documents-v1'
        @($capture.documents).Count | Should -Be 1
        $document = $capture.documents[0]
        $document.document | Should -BeExactly 'a01-CAND-2026-0411-brunner.pdf'
        $document.document_sha256 | Should -BeExactly '9c7ebe8d706b5b6ee98d779bcd83a578f8dff44b9b6bd7d02bff2b64e2ba67bd'
        @($document.fields.PSObject.Properties.Name) | Should -Be @($script:ReplayFieldNames)
        $document.fields.candidate_id.value | Should -BeExactly 'CAND-2026-0411'
        $document.fields.candidate_id.confidence | Should -BeOfType [ValueType]
        $document.fields.dob.value | Should -BeNullOrEmpty
        $document.fields.dob.confidence | Should -BeOfType [ValueType]
        $result.hashes.source_sha256 | Should -BeExactly $document.document_sha256
    }

    It 'preserves the retained timestamp lexeme and reproduces its canonical hash' {
        $result = Test-HrAiBuilderCapturePair `
            -CaptureDirectory $script:RetainedCaptureDirectory `
            -RunManifestPath (Join-Path $script:RetainedReplayRoot 'run-manifest.json') `
            -FieldContractPath $script:ReplayContractPath `
            -ModelSchemaRecordPath (Join-Path $script:RetainedReplayRoot 'model-schema-fixed.json') `
            -ModelName 'PersonalMasterDataFixed' `
            -ModelVersion '1.0' `
            -Operator 'admin@caldova25668747.onmicrosoft.com'

        $result.canonical_envelope.captured_at_utc |
            Should -BeExactly '2026-09-30T09:46:29.7963762Z'
        $result.hashes.canonical_sha256 | Should -BeExactly $script:RetainedReplayHash
        $result.hashes.replay_sha256 | Should -BeExactly $script:RetainedReplayHash
        $result.status | Should -Be 'passed' -Because ($result.failed_gates -join ', ')
    }

    It 'replays retained holdout 2 with omitted labels as null fields and reproduces its canonical hash' {
        $result = Test-HrAiBuilderCapturePair `
            -CaptureDirectory $script:RetainedHoldout2Directory `
            -RunManifestPath (Join-Path $script:RetainedReplayRoot 'run-manifest.json') `
            -FieldContractPath $script:ReplayContractPath `
            -ModelSchemaRecordPath (Join-Path $script:RetainedReplayRoot 'model-schema-fixed.json') `
            -ModelName 'PersonalMasterDataFixed' `
            -ModelVersion '1.0' `
            -Operator 'admin@caldova25668747.onmicrosoft.com'

        $result.status | Should -Be 'passed' -Because ($result.failed_gates -join ', ')
        @($result.canonical_envelope.fields.Keys) | Should -Be @($script:ReplayFieldNames)
        foreach ($fieldName in @('candidate_id', 'iban', 'phone', 'email', 'ec_name', 'ec_phone')) {
            $result.canonical_envelope.fields.$fieldName.value | Should -BeNullOrEmpty
            $result.canonical_envelope.fields.$fieldName.confidence | Should -BeNullOrEmpty
        }
        $result.hashes.canonical_sha256 | Should -BeExactly $script:RetainedHoldout2Hash
        $result.hashes.replay_sha256 | Should -BeExactly $script:RetainedHoldout2Hash
    }

    It 'replays a valid capture from a nested fixed-holdout directory' {
        $fixture = New-TestObservedCaptureFixture
        $runId = 'cap-20260930114811428Z-ed0cd329'
        $fixture.CaptureDirectory = Copy-TestObservedCaptureFixture `
            -Fixture $fixture `
            -RunId $runId `
            -RelativeParent 'fixed-holdout'
        $fixture.RawPath = Join-Path $fixture.CaptureDirectory "$runId.ai-builder.raw.json"
        $fixture.CanonicalPath = Join-Path $fixture.CaptureDirectory "$runId.canonical.json"
        $fixture.PairPath = Join-Path $fixture.CaptureDirectory 'capture-pair.json'
        $fixture.SourcePath = Join-Path $fixture.CaptureDirectory 'source\a01-CAND-2026-0411-brunner.pdf'

        $result = Invoke-TestObservedCaptureReplay -Fixture $fixture

        $result.status | Should -Be 'passed' -Because ($result.failed_gates -join ', ')
        $result.hashes.canonical_sha256 | Should -BeExactly $result.hashes.replay_sha256
    }

    It 'fails closed when the capture directory has no capture ancestor' {
        $fixture = New-TestObservedCaptureFixture
        $runId = Split-Path -Leaf $fixture.CaptureDirectory
        $outsideCapture = Join-Path $fixture.Root "not-capture\$runId"
        New-Item -ItemType Directory -Path (Split-Path -Parent $outsideCapture) -Force | Out-Null
        Copy-Item -LiteralPath $fixture.CaptureDirectory -Destination $outsideCapture -Recurse

        $result = Test-HrAiBuilderCapturePair `
            -CaptureDirectory $outsideCapture `
            -RunManifestPath $fixture.ManifestPath `
            -FieldContractPath $fixture.ContractPath `
            -ModelSchemaRecordPath $fixture.SchemaPath `
            -ModelName 'PersonalMasterDataFixed' `
            -ModelVersion '1.0' `
            -Operator 'operator@example.invalid'

        $result.status | Should -Be 'blocked'
        $result.failed_gates | Should -Contain 'evidence_boundary'
    }

    It 'fails closed when a nested pair source locator points to an existing sibling capture with identical bytes' {
        $fixture = New-TestObservedCaptureFixture
        $runId = 'cap-20260930114811428Z-ed0cd329'
        $nestedCapture = Copy-TestObservedCaptureFixture `
            -Fixture $fixture `
            -RunId $runId `
            -RelativeParent 'fixed-holdout'
        $siblingRunId = 'cap-20260930114811428Z-sibling'
        $siblingSourceDirectory = Join-Path (Split-Path -Parent $nestedCapture) "$siblingRunId\source"
        New-Item -ItemType Directory -Path $siblingSourceDirectory -Force | Out-Null
        Copy-Item `
            -LiteralPath (Join-Path $nestedCapture 'source\a01-CAND-2026-0411-brunner.pdf') `
            -Destination (Join-Path $siblingSourceDirectory 'a01-CAND-2026-0411-brunner.pdf')
        $pairPath = Join-Path $nestedCapture 'capture-pair.json'
        $pair = Get-Content -LiteralPath $pairPath -Raw | ConvertFrom-Json
        $pair.source.local_path = "capture\fixed-holdout\$siblingRunId\source\a01-CAND-2026-0411-brunner.pdf"
        Set-TestUtf8NoBomContent -Path $pairPath -Content ($pair | ConvertTo-Json -Depth 12)

        $result = Test-HrAiBuilderCapturePair `
            -CaptureDirectory $nestedCapture `
            -RunManifestPath $fixture.ManifestPath `
            -FieldContractPath $fixture.ContractPath `
            -ModelSchemaRecordPath $fixture.SchemaPath `
            -ModelName 'PersonalMasterDataFixed' `
            -ModelVersion '1.0' `
            -Operator 'operator@example.invalid'

        $result.status | Should -Be 'blocked'
        $result.failed_gates | Should -Contain 'evidence_boundary'
    }

    It 'fails closed when a pair locator does not match the capture artifact path' {
        $fixture = New-TestObservedCaptureFixture
        $pair = Get-Content -LiteralPath $fixture.PairPath -Raw | ConvertFrom-Json
        $pair.raw.local_path = $pair.canonical.local_path
        Set-TestUtf8NoBomContent -Path $fixture.PairPath -Content ($pair | ConvertTo-Json -Depth 12)

        $result = Test-HrAiBuilderCapturePair `
            -CaptureDirectory $fixture.CaptureDirectory `
            -RunManifestPath $fixture.ManifestPath `
            -FieldContractPath $fixture.ContractPath `
            -ModelSchemaRecordPath $fixture.SchemaPath `
            -ModelName 'PersonalMasterDataFixed' `
            -ModelVersion '1.0' `
            -Operator 'operator@example.invalid'

        $result.status | Should -Be 'blocked'
        $result.failed_gates | Should -Contain 'evidence_boundary'
    }

    It 'accepts numeric confidence boundaries and observed numeric representations' -TestCases @(
        @{ Confidence = 0 }
        @{ Confidence = 1 }
        @{ Confidence = 0.5 }
    ) {
        param($Confidence)
        $fixture = New-TestObservedCaptureFixture
        $raw = Get-Content -LiteralPath $fixture.RawPath -Raw | ConvertFrom-Json
        $raw.responsev2.predictionOutput.labels.candidate_id.confidence = $Confidence
        Set-TestUtf8NoBomContent -Path $fixture.RawPath -Content ($raw | ConvertTo-Json -Depth 30 -Compress)
        $canonical = Get-Content -LiteralPath $fixture.CanonicalPath -Raw | ConvertFrom-Json
        $canonical.fields.candidate_id.confidence = $Confidence
        $canonicalBytes = InModuleScope Caldova.HrFrontier.AiBuilder -Parameters @{ Canonical = $canonical } {
            param($Canonical)
            ConvertTo-HrAiBuilderCanonicalJson -InputObject $canonical
        }
        [IO.File]::WriteAllBytes($fixture.CanonicalPath, $canonicalBytes)
        Update-TestReplayPairHashes -Fixture $fixture

        (Invoke-TestObservedCaptureReplay -Fixture $fixture).status | Should -Be 'passed'
        $capture = Get-Content -LiteralPath $fixture.OutputPath -Raw | ConvertFrom-Json
        $capture.documents[0].fields.candidate_id.confidence | Should -Be $Confidence
        $capture.documents[0].fields.candidate_id.confidence | Should -BeOfType [ValueType]
    }

    It 'accepts null confidence only with a null value' {
        $fixture = New-TestObservedCaptureFixture
        $raw = Get-Content -LiteralPath $fixture.RawPath -Raw | ConvertFrom-Json
        $raw.responsev2.predictionOutput.labels.dob.confidence = $null
        Set-TestUtf8NoBomContent -Path $fixture.RawPath -Content ($raw | ConvertTo-Json -Depth 30 -Compress)
        $canonical = Get-Content -LiteralPath $fixture.CanonicalPath -Raw | ConvertFrom-Json
        $canonical.fields.dob.confidence = $null
        [IO.File]::WriteAllBytes(
            $fixture.CanonicalPath,
            (InModuleScope Caldova.HrFrontier.AiBuilder -Parameters @{ Canonical = $canonical } {
                param($Canonical)
                ConvertTo-HrAiBuilderCanonicalJson -InputObject $Canonical
            })
        )
        Update-TestReplayPairHashes -Fixture $fixture

        $result = Invoke-TestObservedCaptureReplay -Fixture $fixture
        $result.status | Should -Be 'passed' -Because ($result.failed_gates -join ', ')
    }

    It 'does not reject structurally valid document-dependent region cardinality' {
        $fixture = New-TestObservedCaptureFixture
        $raw = Get-Content -LiteralPath $fixture.RawPath -Raw | ConvertFrom-Json
        $raw.responsev2.predictionOutput.labels.heimatort.valueLocation.regions = @(
            $raw.responsev2.predictionOutput.labels.heimatort.valueLocation.regions |
                Select-Object -First 2
        )
        Set-TestUtf8NoBomContent -Path $fixture.RawPath -Content ($raw | ConvertTo-Json -Depth 30 -Compress)
        Update-TestReplayPairHashes -Fixture $fixture

        $result = Invoke-TestObservedCaptureReplay -Fixture $fixture

        $result.failed_gates | Should -Not -Contain 'capture_pair_provenance'
    }

    It 'blocks invalid value and confidence pair <Case>' -TestCases @(
        @{ Case = 'string confidence'; Field = 'candidate_id'; Value = 'CAND-2026-0411'; Confidence = '0.9' }
        @{ Case = 'negative confidence'; Field = 'candidate_id'; Value = 'CAND-2026-0411'; Confidence = -0.01 }
        @{ Case = 'confidence over one'; Field = 'candidate_id'; Value = 'CAND-2026-0411'; Confidence = 1.01 }
        @{ Case = 'value with null confidence'; Field = 'candidate_id'; Value = 'CAND-2026-0411'; Confidence = $null }
    ) {
        param($Field, $Value, $Confidence)
        $fixture = New-TestObservedCaptureFixture
        $raw = Get-Content -LiteralPath $fixture.RawPath -Raw | ConvertFrom-Json
        $raw.responsev2.predictionOutput.labels.$Field.value = $Value
        $raw.responsev2.predictionOutput.labels.$Field.confidence = $Confidence
        Set-TestUtf8NoBomContent -Path $fixture.RawPath -Content ($raw | ConvertTo-Json -Depth 30 -Compress)
        Update-TestReplayPairHashes -Fixture $fixture

        $result = Invoke-TestObservedCaptureReplay -Fixture $fixture

        $result.status | Should -Be 'blocked'
        $result.failed_gates | Should -Contain 'prediction_capture_schema'
        $fixture.OutputPath | Should -Not -Exist
    }

    It 'accepts the observed null value with numeric confidence' {
        $fixture = New-TestObservedCaptureFixture

        (Invoke-TestObservedCaptureReplay -Fixture $fixture).status | Should -Be 'passed'
        (Get-Content -LiteralPath $fixture.OutputPath -Raw | ConvertFrom-Json).documents[0].fields.dob.confidence |
            Should -Be 0.99
    }

    It 'projects an absent known raw label to null without copying a canonical value' {
        $fixture = New-TestObservedCaptureFixture
        $raw = Get-Content -LiteralPath $fixture.RawPath -Raw | ConvertFrom-Json
        $raw.responsev2.predictionOutput.labels.PSObject.Properties.Remove('ec_phone')
        Set-TestUtf8NoBomContent -Path $fixture.RawPath -Content ($raw | ConvertTo-Json -Depth 30 -Compress)
        $canonical = Get-Content -LiteralPath $fixture.CanonicalPath -Raw | ConvertFrom-Json
        $canonical.fields.ec_phone.value = $null
        $canonical.fields.ec_phone.confidence = $null
        [IO.File]::WriteAllBytes(
            $fixture.CanonicalPath,
            (InModuleScope Caldova.HrFrontier.AiBuilder -Parameters @{ Canonical = $canonical } {
                param($Canonical)
                ConvertTo-HrAiBuilderCanonicalJson -InputObject $Canonical
            })
        )
        Update-TestReplayPairHashes -Fixture $fixture

        $result = Invoke-TestObservedCaptureReplay -Fixture $fixture

        $result.status | Should -Be 'passed' -Because ($result.failed_gates -join ', ')
        $capture = Get-Content -LiteralPath $fixture.OutputPath -Raw | ConvertFrom-Json
        @($capture.documents[0].fields.PSObject.Properties.Name) | Should -Be @($script:ReplayFieldNames)
        $capture.documents[0].fields.ec_phone.value | Should -BeNullOrEmpty
        $capture.documents[0].fields.ec_phone.confidence | Should -BeNullOrEmpty
    }

    It 'blocks a present false-valued known raw label: <Case>' -TestCases @(
        @{ Case = 'null'; LabelValue = $null }
        @{ Case = 'false'; LabelValue = $false }
    ) {
        param($LabelValue)
        $fixture = New-TestObservedCaptureFixture
        $raw = Get-Content -LiteralPath $fixture.RawPath -Raw | ConvertFrom-Json
        $raw.responsev2.predictionOutput.labels.ec_phone = $LabelValue
        Set-TestUtf8NoBomContent -Path $fixture.RawPath -Content ($raw | ConvertTo-Json -Depth 30 -Compress)
        $canonical = Get-Content -LiteralPath $fixture.CanonicalPath -Raw | ConvertFrom-Json
        $canonical.fields.ec_phone.value = $null
        $canonical.fields.ec_phone.confidence = $null
        [IO.File]::WriteAllBytes(
            $fixture.CanonicalPath,
            (InModuleScope Caldova.HrFrontier.AiBuilder -Parameters @{ Canonical = $canonical } {
                param($Canonical)
                ConvertTo-HrAiBuilderCanonicalJson -InputObject $Canonical
            })
        )
        Update-TestReplayPairHashes -Fixture $fixture

        $result = Invoke-TestObservedCaptureReplay -Fixture $fixture

        $result.status | Should -Be 'blocked'
        $result.failed_gates | Should -Contain 'capture_pair_provenance'
        $fixture.OutputPath | Should -Not -Exist
    }

    It 'blocks replay when an absent raw label has a non-null canonical value' {
        $fixture = New-TestObservedCaptureFixture
        $raw = Get-Content -LiteralPath $fixture.RawPath -Raw | ConvertFrom-Json
        $raw.responsev2.predictionOutput.labels.PSObject.Properties.Remove('candidate_id')
        Set-TestUtf8NoBomContent -Path $fixture.RawPath -Content ($raw | ConvertTo-Json -Depth 30 -Compress)
        Update-TestReplayPairHashes -Fixture $fixture

        $result = Invoke-TestObservedCaptureReplay -Fixture $fixture

        $result.status | Should -Be 'blocked'
        $result.failed_gates | Should -Contain 'adapter_replay'
        $result.failed_gates | Should -Not -Contain 'exact_field_contract'
        $fixture.OutputPath | Should -Not -Exist
    }

    It 'accepts the exact observed valued date label shape' {
        $fixture = New-TestObservedCaptureFixture
        $raw = Get-Content -LiteralPath $fixture.RawPath -Raw | ConvertFrom-Json
        $label = $raw.responsev2.predictionOutput.labels.dob
        $raw.responsev2.predictionOutput.labels.dob = [pscustomobject][ordered]@{
            '@odata.type' = $label.'@odata.type'
            'value@odata.type' = '#DateTimeOffset'
            value = '1989-03-10T00:00:00Z'
            displayName = $label.displayName
            fieldType = $label.fieldType
            confidence = $label.confidence
            text = $label.text
            'spans@odata.type' = $label.'spans@odata.type'
            spans = $label.spans
            valueLocation = $label.valueLocation
        }
        Set-TestUtf8NoBomContent -Path $fixture.RawPath -Content ($raw | ConvertTo-Json -Depth 30 -Compress)
        $canonical = Get-Content -LiteralPath $fixture.CanonicalPath -Raw | ConvertFrom-Json
        $canonical.fields.dob.value = '1989-03-10T00:00:00Z'
        [IO.File]::WriteAllBytes(
            $fixture.CanonicalPath,
            (InModuleScope Caldova.HrFrontier.AiBuilder -Parameters @{ Canonical = $canonical } {
                param($Canonical)
                ConvertTo-HrAiBuilderCanonicalJson -InputObject $Canonical
            })
        )
        Update-TestReplayPairHashes -Fixture $fixture

        $result = Invoke-TestObservedCaptureReplay -Fixture $fixture

        $result.status | Should -Be 'passed' -Because ($result.failed_gates -join ', ')
        [IO.File]::ReadAllText($fixture.OutputPath) |
            Should -Match '"dob":\{"value":"1989-03-10T00:00:00Z","confidence":'
    }

    It 'blocks malformed valued date label shape: <Case>' -TestCases @(
        @{ Case = 'missing type marker'; ExpectedGate = 'capture_pair_provenance' }
        @{ Case = 'additional property'; ExpectedGate = 'capture_pair_provenance' }
        @{ Case = 'reordered properties'; ExpectedGate = 'capture_pair_provenance' }
        @{ Case = 'invalid value type'; ExpectedGate = 'prediction_capture_schema' }
    ) {
        param($Case, $ExpectedGate)
        $fixture = New-TestObservedCaptureFixture
        $raw = Get-Content -LiteralPath $fixture.RawPath -Raw | ConvertFrom-Json
        $label = $raw.responsev2.predictionOutput.labels.dob
        $valued = [ordered]@{
            '@odata.type' = $label.'@odata.type'
            'value@odata.type' = '#DateTimeOffset'
            value = '1989-03-10T00:00:00Z'
            displayName = $label.displayName
            fieldType = $label.fieldType
            confidence = $label.confidence
            text = $label.text
            'spans@odata.type' = $label.'spans@odata.type'
            spans = $label.spans
            valueLocation = $label.valueLocation
        }
        switch ($Case) {
            'missing type marker' {
                $valued.Remove('value@odata.type')
            }
            'additional property' {
                $valued['unexpected'] = 'shape drift'
            }
            'reordered properties' {
                $value = $valued.value
                $valued.Remove('value')
                $valued['value'] = $value
            }
            'invalid value type' {
                $valued.value = 19890310
            }
        }
        $raw.responsev2.predictionOutput.labels.dob = [pscustomobject]$valued
        Set-TestUtf8NoBomContent -Path $fixture.RawPath -Content ($raw | ConvertTo-Json -Depth 30 -Compress)
        Update-TestReplayPairHashes -Fixture $fixture

        $result = Invoke-TestObservedCaptureReplay -Fixture $fixture

        $result.status | Should -Be 'blocked'
        $result.failed_gates | Should -Contain $ExpectedGate
        $fixture.OutputPath | Should -Not -Exist
    }

    It 'blocks a <Case> observed field condition' -TestCases @(
        @{ Case = 'additional'; Mutation = 'additional' }
        @{ Case = 'duplicate source filename'; Mutation = 'duplicate' }
    ) {
        param($Mutation)
        $fixture = New-TestObservedCaptureFixture
        if ($Mutation -eq 'duplicate') {
            Copy-TestObservedCaptureFixture -Fixture $fixture -RunId 'cap-20260930000000000Z-11111111' | Out-Null
            $fixture.CaptureDirectory = Split-Path -Parent $fixture.CaptureDirectory
        }
        else {
            $raw = Get-Content -LiteralPath $fixture.RawPath -Raw | ConvertFrom-Json
            if ($Mutation -eq 'missing') {
                $raw.responsev2.predictionOutput.labels.PSObject.Properties.Remove('candidate_id')
            }
            else {
                $raw.responsev2.predictionOutput.labels | Add-Member -NotePropertyName unexpected_field -NotePropertyValue (
                    [pscustomobject]@{ value = 'unexpected'; confidence = 0.5 }
                )
            }
            Set-TestUtf8NoBomContent -Path $fixture.RawPath -Content ($raw | ConvertTo-Json -Depth 30 -Compress)
            Update-TestReplayPairHashes -Fixture $fixture
        }

        $result = Invoke-TestObservedCaptureReplay -Fixture $fixture

        $result.status | Should -Be 'blocked'
        $result.failed_gates | Should -Contain 'exact_field_contract'
        $fixture.OutputPath | Should -Not -Exist
    }

    It 'blocks a structurally changed label node: <Case>' -TestCases @(
        @{ Case = 'additional label property' }
        @{ Case = 'missing displayName' }
        @{ Case = 'reordered label properties' }
        @{ Case = 'spans changed from an array to an object' }
        @{ Case = 'missing nested boundingBox polygon' }
        @{ Case = 'additional nested coordinate property' }
        @{ Case = 'empty regions' }
        @{ Case = 'invalid additional region' }
    ) {
        param($Case)
        $fixture = New-TestObservedCaptureFixture
        $raw = Get-Content -LiteralPath $fixture.RawPath -Raw | ConvertFrom-Json
        $label = $raw.responsev2.predictionOutput.labels.candidate_id

        switch ($Case) {
            'additional label property' {
                $label | Add-Member -NotePropertyName unexpected -NotePropertyValue 'shape drift'
            }
            'missing displayName' {
                $label.PSObject.Properties.Remove('displayName')
            }
            'reordered label properties' {
                $reordered = [ordered]@{}
                foreach ($propertyName in @($label.PSObject.Properties.Name)) {
                    if ($propertyName -ne 'displayName') {
                        $reordered[$propertyName] = $label.$propertyName
                    }
                }
                $reordered['displayName'] = $label.displayName
                $raw.responsev2.predictionOutput.labels.candidate_id = [pscustomobject]$reordered
            }
            'spans changed from an array to an object' {
                $label.spans = $label.spans[0]
            }
            'missing nested boundingBox polygon' {
                $label.valueLocation.boundingBox.PSObject.Properties.Remove('polygon')
            }
            'additional nested coordinate property' {
                $label.valueLocation.boundingBox.polygon.coordinates[0] |
                    Add-Member -NotePropertyName z -NotePropertyValue 0
            }
            'empty regions' {
                $label.valueLocation.regions = @()
            }
            'invalid additional region' {
                $label.valueLocation.regions = @(
                    $label.valueLocation.regions
                    [pscustomobject]@{ unexpected = 'shape drift' }
                )
            }
        }
        Set-TestUtf8NoBomContent -Path $fixture.RawPath -Content ($raw | ConvertTo-Json -Depth 30 -Compress)
        Update-TestReplayPairHashes -Fixture $fixture

        $result = Invoke-TestObservedCaptureReplay -Fixture $fixture

        $result.status | Should -Be 'blocked'
        $result.failed_gates | Should -Contain 'capture_pair_provenance'
        $fixture.OutputPath | Should -Not -Exist
    }

    It 'blocks a mutually consistent 16-field contract and evidence set' {
        $fixture = New-TestObservedCaptureFixture
        $removedField = 'ec_phone'

        $contract = Get-Content -LiteralPath $fixture.ContractPath -Raw | ConvertFrom-Json
        $contract.fields = @($contract.fields | Where-Object name -cne $removedField)
        $contract.field_count = 16
        Set-TestUtf8NoBomContent -Path $fixture.ContractPath -Content ($contract | ConvertTo-Json -Depth 12)

        $schema = Get-Content -LiteralPath $fixture.SchemaPath -Raw | ConvertFrom-Json
        $schema.fields = @($schema.fields | Where-Object name -cne $removedField)
        Set-TestUtf8NoBomContent -Path $fixture.SchemaPath -Content ($schema | ConvertTo-Json -Depth 12)

        $raw = Get-Content -LiteralPath $fixture.RawPath -Raw | ConvertFrom-Json
        $raw.responsev2.predictionOutput.labels.PSObject.Properties.Remove($removedField)
        Set-TestUtf8NoBomContent -Path $fixture.RawPath -Content ($raw | ConvertTo-Json -Depth 30 -Compress)

        $canonical = Get-Content -LiteralPath $fixture.CanonicalPath -Raw | ConvertFrom-Json
        $canonical.fields.PSObject.Properties.Remove($removedField)
        [IO.File]::WriteAllBytes(
            $fixture.CanonicalPath,
            (InModuleScope Caldova.HrFrontier.AiBuilder -Parameters @{ Canonical = $canonical } {
                param($Canonical)
                ConvertTo-HrAiBuilderCanonicalJson -InputObject $Canonical
            })
        )
        Update-TestReplayPairHashes -Fixture $fixture

        $result = Invoke-TestObservedCaptureReplay -Fixture $fixture

        $result.status | Should -Be 'blocked'
        $result.failed_gates | Should -Contain 'exact_field_contract'
        $fixture.OutputPath | Should -Not -Exist
    }

    It 'serializes canonical JSON to deterministic UTF-8 bytes' {
        $input = [ordered]@{
            schema_version = '1.0'
            text = 'Müller says "yes" at C:\HR'
            nullable = $null
            confidence = 0.99
        }

        $first = InModuleScope Caldova.HrFrontier.AiBuilder -Parameters @{ InputValue = $input } {
            param($InputValue)
            ConvertTo-HrAiBuilderCanonicalJson -InputObject $InputValue
        }
        $second = InModuleScope Caldova.HrFrontier.AiBuilder -Parameters @{ InputValue = $input } {
            param($InputValue)
            ConvertTo-HrAiBuilderCanonicalJson -InputObject $InputValue
        }
        $sha = [Security.Cryptography.SHA256]::Create()
        try {
            $firstHash = ([BitConverter]::ToString($sha.ComputeHash($first)) -replace '-', '').ToLowerInvariant()
            $secondHash = ([BitConverter]::ToString($sha.ComputeHash($second)) -replace '-', '').ToLowerInvariant()
        }
        finally {
            $sha.Dispose()
        }
        $text = [Text.UTF8Encoding]::new($false, $true).GetString($first)

        $firstHash | Should -BeExactly $secondHash
        $firstHash | Should -Match '^[a-f0-9]{64}$'
        @($first[0..2]) | Should -Not -Be @(0xEF, 0xBB, 0xBF)
        $first[-1] | Should -Be 0x0A
        $first[-2] | Should -Not -Be 0x0A
        $first | Should -Not -Contain 0x0D
        $text | Should -Match '^\{"schema_version":"1\.0","text":'
        $text | Should -Match 'Müller'
        $text | Should -Match '\\"yes\\"'
        $text | Should -Match 'C:\\\\HR'
    }

    It 'changes canonical bytes when <Mutation> changes' -TestCases @(
        @{ Mutation = 'a value'; Changed = [ordered]@{ a = 'changed'; b = $null; confidence = 0.5 } }
        @{ Mutation = 'a null'; Changed = [ordered]@{ a = $null; b = 'value'; confidence = 0.5 } }
        @{ Mutation = 'confidence'; Changed = [ordered]@{ a = 'value'; b = $null; confidence = 0.6 } }
        @{ Mutation = 'property order'; Changed = [ordered]@{ confidence = 0.5; b = $null; a = 'value' } }
    ) {
        param($Changed)
        $original = [ordered]@{ a = 'value'; b = $null; confidence = 0.5 }

        $originalBytes = InModuleScope Caldova.HrFrontier.AiBuilder -Parameters @{ Value = $original } {
            param($Value)
            ConvertTo-HrAiBuilderCanonicalJson -InputObject $Value
        }
        $changedBytes = InModuleScope Caldova.HrFrontier.AiBuilder -Parameters @{ Value = $Changed } {
            param($Value)
            ConvertTo-HrAiBuilderCanonicalJson -InputObject $Value
        }

        [Convert]::ToBase64String($changedBytes) | Should -Not -BeExactly ([Convert]::ToBase64String($originalBytes))
    }

    It 'fails closed at <Gate> for <Mutation>' -TestCases @(
        @{ Mutation = 'changed source bytes'; Gate = 'source_sha256' }
        @{ Mutation = 'case-only filename'; Gate = 'exact_correlation' }
        @{ Mutation = 'raw run id'; Gate = 'exact_correlation' }
        @{ Mutation = 'envelope corpus revision'; Gate = 'exact_correlation' }
        @{ Mutation = 'model version'; Gate = 'exact_model_version' }
        @{ Mutation = 'changed raw response'; Gate = 'adapter_replay' }
        @{ Mutation = 'canonical BOM'; Gate = 'canonical_serialization' }
        @{ Mutation = 'existing output'; Gate = 'immutable_output' }
        @{ Mutation = 'path escape'; Gate = 'evidence_boundary' }
    ) {
        param($Mutation, $Gate)
        $fixture = New-TestObservedCaptureFixture
        $arguments = @{
            CaptureDirectory = $fixture.CaptureDirectory
            RunManifestPath = $fixture.ManifestPath
            FieldContractPath = $script:ReplayContractPath
            ModelSchemaRecordPath = $fixture.SchemaPath
            ModelName = 'PersonalMasterDataFixed'
            ModelVersion = '1.0'
            Operator = 'operator@example.invalid'
            OutputPath = $fixture.OutputPath
        }

        switch ($Mutation) {
            'changed source bytes' {
                [IO.File]::AppendAllText($fixture.SourcePath, 'changed', [Text.UTF8Encoding]::new($false))
            }
            'case-only filename' {
                $pair = Get-Content -LiteralPath $fixture.PairPath -Raw | ConvertFrom-Json
                $pair.source.filename = 'A01-CAND-2026-0411-brunner.pdf'
                Set-TestUtf8NoBomContent -Path $fixture.PairPath -Content ($pair | ConvertTo-Json -Depth 12)
            }
            'raw run id' {
                $raw = [IO.File]::ReadAllText($fixture.RawPath, [Text.UTF8Encoding]::new($false, $true)) | ConvertFrom-Json
                $raw.responsev2 | Add-Member -NotePropertyName run_id -NotePropertyValue 'cap-20260930000000000Z-wrong000'
                Set-TestUtf8NoBomContent -Path $fixture.RawPath -Content ($raw | ConvertTo-Json -Depth 30 -Compress)
                Update-TestReplayPairHashes -Fixture $fixture
            }
            'envelope corpus revision' {
                $canonical = [IO.File]::ReadAllText($fixture.CanonicalPath, [Text.UTF8Encoding]::new($false, $true)) | ConvertFrom-Json
                $canonical.corpus_revision = ('f' * 64)
                [IO.File]::WriteAllBytes(
                    $fixture.CanonicalPath,
                    (InModuleScope Caldova.HrFrontier.AiBuilder -Parameters @{ Canonical = $canonical } {
                        param($Canonical)
                        ConvertTo-HrAiBuilderCanonicalJson -InputObject $Canonical
                    })
                )
                Update-TestReplayPairHashes -Fixture $fixture
            }
            'model version' {
                $arguments.ModelVersion = '2.0'
            }
            'changed raw response' {
                $raw = [IO.File]::ReadAllText($fixture.RawPath, [Text.UTF8Encoding]::new($false, $true)) | ConvertFrom-Json
                $raw.responsev2.predictionOutput.labels.candidate_id.value = 'CHANGED'
                Set-TestUtf8NoBomContent -Path $fixture.RawPath -Content ($raw | ConvertTo-Json -Depth 30 -Compress)
                Update-TestReplayPairHashes -Fixture $fixture
            }
            'canonical BOM' {
                $bytes = [IO.File]::ReadAllBytes($fixture.CanonicalPath)
                $withBom = [byte[]]::new($bytes.Length + 3)
                $withBom[0] = 0xEF
                $withBom[1] = 0xBB
                $withBom[2] = 0xBF
                [Array]::Copy($bytes, 0, $withBom, 3, $bytes.Length)
                [IO.File]::WriteAllBytes($fixture.CanonicalPath, $withBom)
                Update-TestReplayPairHashes -Fixture $fixture
            }
            'existing output' {
                Set-TestUtf8NoBomContent -Path $fixture.OutputPath -Content '{}'
            }
            'path escape' {
                $outside = Join-Path $fixture.Root 'outside.pdf'
                Copy-Item -LiteralPath $fixture.SourcePath -Destination $outside
                $pair = Get-Content -LiteralPath $fixture.PairPath -Raw | ConvertFrom-Json
                $pair.source.local_path = '..\outside.pdf'
                Set-TestUtf8NoBomContent -Path $fixture.PairPath -Content ($pair | ConvertTo-Json -Depth 12)
            }
        }

        $result = ConvertFrom-HrAiBuilderEvaluationCapture @arguments

        $result.status | Should -Be 'blocked'
        $result.failed_gates | Should -Contain $Gate
        if ($Mutation -ne 'existing output') {
            $fixture.OutputPath | Should -Not -Exist
        }
    }

    It 'imports the observed capture through the compatible six-parameter adapter entry point' {
        $fixture = New-TestObservedCaptureFixture
        $manifest = Get-Content -LiteralPath $fixture.ManifestPath -Raw | ConvertFrom-Json
        $manifest.models[0].documents[0].assignment = 'held-out'
        Set-TestUtf8NoBomContent -Path $fixture.ManifestPath -Content ($manifest | ConvertTo-Json -Depth 12)
        $importPath = Join-Path $script:ReplayRepositoryRoot 'hr\src\scripts\Import-AiBuilderQuickTestResults.ps1'
        $adapterPath = Join-Path $script:ReplayRepositoryRoot 'hr\src\scripts\adapters\ConvertFrom-HrAiBuilderEvaluationCapture.ps1'

        $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $importPath `
            -RunManifestPath $fixture.ManifestPath `
            -ModelSchemaRecordPath $fixture.SchemaPath `
            -RawExportDirectory $fixture.CaptureDirectory `
            -AdapterScriptPath $adapterPath `
            -TargetModelName 'PersonalMasterDataFixed' `
            -OutputPath $fixture.OutputPath 2>&1
        $exitCode = $LASTEXITCODE

        $exitCode | Should -Be 0 -Because ($output -join [Environment]::NewLine)
        $capture = Get-Content -LiteralPath $fixture.OutputPath -Raw | ConvertFrom-Json
        $capture.capture_mechanism | Should -BeExactly 'Power Automate Process documents'
        $capture.adapter_contract | Should -BeExactly 'replayable-v2'
        $capture.raw_export_format | Should -BeExactly 'ai-builder-process-documents-v1'
    }
}

function script:Set-TestUtf8NoBomContent {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Content
    )

    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

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

    Describe 'AI Builder operator guide contract' {
        BeforeAll {
            $root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
            $script:Guide = Get-Content -LiteralPath (
                Join-Path $root 'hr\docs\ideas\uc-0001-personal-master-data-completion-agent\ai-builder-model-setup.md'
            ) -Raw
            $script:EvidenceReadme = Get-Content -LiteralPath (
                Join-Path $root 'hr\evidence\ai-builder\README.md'
            ) -Raw
            $script:ScriptsReadme = Get-Content -LiteralPath (
                Join-Path $root 'hr\src\scripts\README.md'
            ) -Raw
            $script:ExpectedGuideSectionHeadings = @(
                'Authority, supersession, and preserved evidence'
                'Pre-mutation read-only readiness'
                'Final-name and mutation approval'
                'Fixed `1.0` evaluation publication'
                'Evaluation solution and complete flow creation, explicit binding to published fixed `1.0`, save, and immediate Off state'
                'Security application and verification'
                'One training-PDF observation and immutable byte retention without a capability claim'
                'Adapter TDD against the observed raw shape'
                'Calculated training-PDF capability decision'
                'Exactly-once fixed holdout capture and calculated evaluation'
                'Solution-approval decision'
                'General model continuation decision'
                'Synchronization, BoMs, manifest, and issue 13'
            )
        }

        It 'references the addendum, original design, and preserved blocked evidence' {
            $script:Guide | Should -Match '2026-09-29-ai-builder-evaluation-capture-design\.md'
            $script:Guide | Should -Match '2026-09-25-tenant-2-ai-builder-models-design\.md'
            $script:Guide | Should -Match 'model-test-capability\.json'
            $script:Guide | Should -Match 'historical blocked event'
        }

        It 'states the narrow supersession and preserves Tasks 1-5' {
            $script:Guide | Should -Match 'supersedes only the no-flow capture requirement'
            $script:Guide | Should -Match 'Tasks 1-5 remain complete'
            $script:Guide | Should -Match 'append-only lifecycle'
        }

        It 'uses the approved names and forbids draft 2.0 mutation' {
            $script:Guide | Should -Match 'PersonalMasterDataFixed'
            $script:Guide | Should -Match 'PersonalMasterDataGeneral'
            $script:Guide | Should -Match 'caldovahrfrontier'
            $script:Guide | Should -Match 'Process documents'
            $script:Guide | Should -Match 'Do not train, edit, delete, publish, or use draft `2\.0`'
            $script:Guide | Should -Not -Match 'No Power Automate flow'
            $script:Guide | Should -Not -Match 'Publish that evaluated version'
            $script:Guide | Should -Not -Match 'caldova_Personalstammdaten'
            $script:Guide | Should -Not -Match 'GFHRPlatformCore'
        }

        It 'requires selected names before mutation and preserves the exact field contract' {
            $script:Guide | Should -Match 'Before any mutation, record the final selected values'

            $fieldRowPattern = '(?m)^\|\s*`?(?<bom>BOM-0001-F\d{2})`?\s*\|\s*`?(?<name>[a-z_]+)`?\s*\|\s*`?(?<type>Text|Date)`?\s*\|\s*$'
            $actualRows = @(
                [regex]::Matches($script:Guide, $fieldRowPattern) | ForEach-Object {
                    '{0}|{1}|{2}' -f $_.Groups['bom'].Value, $_.Groups['name'].Value, $_.Groups['type'].Value
                }
            )
            $expectedRows = @(
                $script:ExpectedFieldDefinitions | ForEach-Object {
                    '{0}|{1}|{2}' -f $_.bom_id, $_.name, $_.ai_builder_type
                }
            )

            $actualRows | Should -Be $expectedRows
        }

        It 'keeps the required procedural sections in order' {
            $sectionMatches = [regex]::Matches(
                $script:Guide,
                '(?m)^## (?<number>[1-9]|1[0-3])\. (?<title>[^\r\n]+)\r?$'
            )

            @($sectionMatches | ForEach-Object { $_.Groups['number'].Value }) |
                Should -Be @('1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12', '13')
            @($sectionMatches | ForEach-Object { $_.Groups['title'].Value }) |
                Should -Be $script:ExpectedGuideSectionHeadings
        }

        It 'keeps the revised lifecycle order explicit' {
            $script:Guide | Should -Match '(?s)`evaluation_published`.+`capture_validated`.+`evaluated`.+`approved_for_solution`.+`added_to_solution`'
        }

        It 'preserves structured evidence and strict calculated evaluation language' {
            $script:Guide | Should -Match 'run-manifest\.json'
            $script:Guide | Should -Match 'machine-readable path plus SHA-256 whenever bytes exist'
            $script:Guide | Should -Match 'prediction-capture-fixed-training-proof\.json'
            $script:Guide | Should -Match 'prediction-capture-fixed\.json'
            $script:Guide | Should -Match 'false-value rate remains zero'
            $script:Guide | Should -Match 'Use only calculated repository evidence for the approval decision'
            $script:Guide | Should -Match 'Append `approved_for_solution` only on calculated success'
            $script:Guide | Should -Match 'If calculated gates do not support `approved_for_solution`, stop\. Do not add the model to `caldovahrfrontier`'
            $script:Guide | Should -Match 'If the approved model cannot be added to `caldovahrfrontier`, retain the evidence, do not append `added_to_solution`, and stop'
        }

        It 'requires owner-only flow security and synthetic evidence boundaries' {
            $script:Guide | Should -Match 'named administrators only'
            $script:Guide | Should -Match 'disabled by default'
            $script:Guide | Should -Match 'secure inputs and outputs'
            $script:Guide | Should -Match 'OneDrive or SharePoint synthetic-evidence location'
            $script:Guide | Should -Match 'synthetic only'
            $script:Guide | Should -Match 'no auto-delete'
        }

        It 'uses a training PDF before holdouts and disables the flow on failure' {
            $script:Guide | Should -Match 'training PDF'
            $script:Guide | Should -Match 'Do not expose a fixed holdout until this proof is captured and verified'
            $script:Guide | Should -Match 'turn the flow Off immediately after the run'
            $script:Guide | Should -Match 'turn the flow Off, record `blocked`, and stop'
        }

        It 'requires exactly-once holdouts and gates the general model behind fixed approval' {
            $script:Guide | Should -Match 'process each fixed holdout exactly once'
            $script:Guide | Should -Match 'the affected holdout set is consumed'
            $script:Guide | Should -Match 'Generate unseen synthetic documents, qualify them, and begin a new run'
            $script:Guide | Should -Match 'Do not begin `PersonalMasterDataGeneral` until `PersonalMasterDataFixed` version `1\.0` has reached `approved_for_solution`'
        }

        It 'labels every portal mutation as attended approval work' {
            @([regex]::Matches($script:Guide, 'ATTENDED TENANT OPERATION — STOP FOR APPROVAL')).Count |
                Should -Be 7
        }
    }

    Describe 'AI Builder evidence documentation contract' {
        BeforeAll {
            $root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
            $script:EvidenceReadme = Get-Content -LiteralPath (
                Join-Path $root 'hr\evidence\ai-builder\README.md'
            ) -Raw
            $script:ScriptsReadme = Get-Content -LiteralPath (
                Join-Path $root 'hr\src\scripts\README.md'
            ) -Raw
        }

        It 'documents the capture folder layout and immutable storage rules' {
            $captureLayoutPattern = '(?s)capture/.*<approved-evidence-folder-name>.*<execution-run-id>.*source/<exact-qualified-filename>\.pdf.*<execution-run-id>\.ai-builder\.raw\.json.*<execution-run-id>\.canonical\.json.*capture-pair\.json'

            $script:EvidenceReadme | Should -Match $captureLayoutPattern
            $script:ScriptsReadme | Should -Match $captureLayoutPattern
            $script:EvidenceReadme | Should -Match 'evaluation-capture-intent\.json'
            $script:ScriptsReadme | Should -Match 'evaluation-capture-intent\.json'
            $script:EvidenceReadme | Should -Match 'immutable'
            $script:ScriptsReadme | Should -Match 'immutable'
            $script:EvidenceReadme | Should -Match 'No cleanup is implied'
            $script:ScriptsReadme | Should -Match 'No cleanup is implied'
            $script:EvidenceReadme | Should -Match 'UTF-8 without BOM'
            $script:ScriptsReadme | Should -Match 'UTF-8 without BOM'
        }

        It 'documents the exact adapter, import, and evaluator commands for the flow-based path' {
            foreach ($document in @($script:EvidenceReadme, $script:ScriptsReadme)) {
                $document | Should -Match 'ConvertFrom-HrAiBuilderEvaluationCapture\.ps1'
                $document | Should -Not -Match 'ConvertFrom-HrAiBuilderProcessDocumentsCapture\.ps1'
                $document | Should -Match 'Import-AiBuilderQuickTestResults\.ps1'
                $document | Should -Match 'Measure-AiBuilderEvaluation\.ps1'
                $document | Should -Match 'Power Automate `Process documents`'
                $document | Should -Match 'prediction-capture-fixed\.json'
            }
        }

        It 'marks the approved adapter path as unavailable until Task 7 implements and verifies it' {
            foreach ($document in @($script:Guide, $script:EvidenceReadme, $script:ScriptsReadme)) {
                $document | Should -Match 'ConvertFrom-HrAiBuilderEvaluationCapture\.ps1'
                $document | Should -Match 'Task 7'
                $document | Should -Match 'not yet implemented'
                $document | Should -Match 'Do not run'
                $document | Should -Match 'stop'
            }
        }
    }

    Describe 'AI Builder calculated capture capability evidence' {
        BeforeAll {
            $script:CapabilityRepositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
            $script:CapabilityEvidenceRoot = Join-Path $script:CapabilityRepositoryRoot 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001'
            $script:CapabilityCaptureDirectory = Join-Path $script:CapabilityEvidenceRoot 'capture\cap-20260930094537354Z-34bf8987'
            $script:CapabilityPath = Join-Path $script:CapabilityEvidenceRoot 'capture-capability.json'
            $script:CapabilityManifestPath = Join-Path $script:CapabilityEvidenceRoot 'run-manifest.json'
            $script:CapabilityInventoryPath = Join-Path $script:CapabilityEvidenceRoot 'model-inventory.json'
            $script:CapabilityPairPath = Join-Path $script:CapabilityCaptureDirectory 'capture-pair.json'
            $script:CapabilityAdapterPath = Join-Path $script:CapabilityRepositoryRoot 'hr\src\scripts\adapters\ConvertFrom-HrAiBuilderEvaluationCapture.ps1'
            $script:CapabilityFieldContractPath = Join-Path $script:CapabilityRepositoryRoot 'hr\src\ai-builder\contracts\field-contract.json'
            $script:CapabilityModelSchemaPath = Join-Path $script:CapabilityEvidenceRoot 'model-schema-fixed.json'
            $script:CapabilityModulePath = Join-Path $script:CapabilityRepositoryRoot 'hr\src\scripts\modules\Caldova.HrFrontier.AiBuilder\Caldova.HrFrontier.AiBuilder.psd1'
            $script:CapabilityFieldBoMPath = Join-Path $script:CapabilityRepositoryRoot 'hr\docs\ideas\uc-0001-personal-master-data-completion-agent\bom-0001-peopledoc-master-data-ai-builder-fields.md'
            $script:CapabilityTestBoMPath = Join-Path $script:CapabilityRepositoryRoot 'hr\docs\ideas\uc-0001-personal-master-data-completion-agent\bom-0002-ai-builder-test-inputs-and-outcomes.md'
            Import-Module $script:CapabilityModulePath -Force
        }

        It 'freshly proves every retained artifact and all seven live-derived capture gates' {
            $script:CapabilityPath | Should -Exist
            $capability = Get-Content -LiteralPath $script:CapabilityPath -Raw | ConvertFrom-Json
            $capability.schema_version | Should -Be '1.0'
            $capability.run_id | Should -Be 't2-dev-20260925-001'
            $capability.status | Should -Be 'passed'
            $capability.decision | Should -Be 'capture_validated'
            $capability.model.name | Should -Be 'PersonalMasterDataFixed'
            $capability.model.id | Should -Be '74b09a72-d1f1-4598-bc4d-3746d5c97acc'
            $capability.model.version | Should -Be '1.0'
            @($capability.gates.id) | Should -Be @(
                'AEC-G001', 'AEC-G002', 'AEC-G003', 'AEC-G004',
                'AEC-G005', 'AEC-G006', 'AEC-G007'
            )
            @($capability.gates | Where-Object status -ne 'passed').Count | Should -Be 0
            @($capability.failed_gates).Count | Should -Be 0

            $capability.capture_pair.run_id | Should -Be 'cap-20260930094537354Z-34bf8987'
            $capability.capture_pair.path | Should -Be 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001\capture\cap-20260930094537354Z-34bf8987\capture-pair.json'

            $expectedArtifactIds = @(
                'source', 'raw', 'canonical', 'capture_pair', 'field_contract',
                'model_schema', 'adapter_script', 'pre_decision_record',
                'historical_model_test_capability', 'historical_training_capture_attempt',
                'historical_training_capture_retry', 'training_capture_remediation'
            )
            @($capability.supporting_artifacts.id) | Should -Be $expectedArtifactIds
            foreach ($artifact in @($capability.supporting_artifacts)) {
                [IO.Path]::IsPathRooted([string]$artifact.path) | Should -BeFalse
                $artifactPath = [IO.Path]::GetFullPath((Join-Path $script:CapabilityRepositoryRoot ([string]$artifact.path)))
                $artifactPath.StartsWith(
                    $script:CapabilityRepositoryRoot + [IO.Path]::DirectorySeparatorChar,
                    [StringComparison]::OrdinalIgnoreCase
                ) | Should -BeTrue
                $artifactPath | Should -Exist
                (Get-FileHash -LiteralPath $artifactPath -Algorithm SHA256).Hash.ToLowerInvariant() |
                    Should -Be ([string]$artifact.sha256)
            }

            $pairResult = Test-HrAiBuilderCapturePair `
                -CaptureDirectory $script:CapabilityCaptureDirectory `
                -RunManifestPath $script:CapabilityManifestPath `
                -FieldContractPath $script:CapabilityFieldContractPath `
                -ModelSchemaRecordPath $script:CapabilityModelSchemaPath `
                -ModelName 'PersonalMasterDataFixed' `
                -ModelVersion '1.0' `
                -Operator 'admin@caldova25668747.onmicrosoft.com' `
                -AdapterScriptPath $script:CapabilityAdapterPath

            $pairResult.status | Should -Be 'passed'
            @($pairResult.failed_gates).Count | Should -Be 0

            $firstReplayPath = Join-Path $TestDrive 'fixed-capability-replay-1.json'
            $secondReplayPath = Join-Path $TestDrive 'fixed-capability-replay-2.json'
            try {
                $adapterArguments = @{
                    CaptureDirectory = $script:CapabilityCaptureDirectory
                    RunManifestPath = $script:CapabilityManifestPath
                    FieldContractPath = $script:CapabilityFieldContractPath
                    ModelSchemaRecordPath = $script:CapabilityModelSchemaPath
                    ModelName = 'PersonalMasterDataFixed'
                    ModelVersion = '1.0'
                    Operator = 'admin@caldova25668747.onmicrosoft.com'
                    AdapterScriptPath = $script:CapabilityAdapterPath
                }
                $firstResult = ConvertFrom-HrAiBuilderEvaluationCapture @adapterArguments -OutputPath $firstReplayPath
                $secondResult = ConvertFrom-HrAiBuilderEvaluationCapture @adapterArguments -OutputPath $secondReplayPath
                $firstResult.status | Should -Be 'passed'
                $secondResult.status | Should -Be 'passed'

                $firstHash = (Get-FileHash -LiteralPath $firstReplayPath -Algorithm SHA256).Hash.ToLowerInvariant()
                $secondHash = (Get-FileHash -LiteralPath $secondReplayPath -Algorithm SHA256).Hash.ToLowerInvariant()
                $firstHash | Should -Be $secondHash
                foreach ($replayPath in @($firstReplayPath, $secondReplayPath)) {
                    $historicalHash = & (Get-Module Caldova.HrFrontier.AiBuilder) {
                        param($Path, $Adapter, $Raw)
                        Get-HrAiBuilderTask8ReplayHash -Path $Path -AdapterPath $Adapter -RawPath $Raw
                    } $replayPath $script:CapabilityAdapterPath (
                        Join-Path $script:CapabilityCaptureDirectory 'cap-20260930094537354Z-34bf8987.ai-builder.raw.json'
                    )
                    $historicalHash | Should -Be $capability.replay.first_sha256
                    $historicalHash | Should -Be $capability.replay.second_sha256
                }

                $derivedGates = [ordered]@{
                    'AEC-G001' = -not @($pairResult.failed_gates).Contains('exact_correlation')
                    'AEC-G002' = -not @($pairResult.failed_gates).Contains('source_sha256')
                    'AEC-G003' = -not @($pairResult.failed_gates).Contains('capture_pair_provenance')
                    'AEC-G004' = -not @($pairResult.failed_gates).Contains('exact_field_contract')
                    'AEC-G005' = -not @($pairResult.failed_gates).Contains('prediction_capture_schema')
                    'AEC-G006' = (
                        -not @($pairResult.failed_gates).Contains('canonical_serialization') -and
                        $firstHash -ceq $secondHash
                    )
                    'AEC-G007' = (
                        $pairResult.status -ceq 'passed' -and
                        -not @($pairResult.failed_gates).Contains('adapter_replay') -and
                        $pairResult.hashes.replay_sha256 -ceq $pairResult.hashes.canonical_sha256
                    )
                }
                foreach ($gate in @($capability.gates)) {
                    $derivedGates[[string]$gate.id] | Should -BeTrue
                    $gate.status | Should -Be 'passed'
                }
            }
            finally {
                Remove-Item -LiteralPath $firstReplayPath -Force -ErrorAction SilentlyContinue
                Remove-Item -LiteralPath $secondReplayPath -Force -ErrorAction SilentlyContinue
            }
            $firstReplayPath | Should -Not -Exist
            $secondReplayPath | Should -Not -Exist
        }

        It 'reproduces the historical digest after relocating only the live capture metadata' {
            $relocatedCapture = Join-Path $TestDrive 'relocated-training\capture\cap-20260930094537354Z-34bf8987'
            New-Item -ItemType Directory -Path (Split-Path -Parent $relocatedCapture) -Force | Out-Null
            Copy-Item -LiteralPath $script:CapabilityCaptureDirectory -Destination $relocatedCapture -Recurse
            $replayPath = Join-Path $TestDrive 'relocated-replay.json'
            $rawPath = Join-Path $relocatedCapture 'cap-20260930094537354Z-34bf8987.ai-builder.raw.json'
            $result = ConvertFrom-HrAiBuilderEvaluationCapture `
                -CaptureDirectory $relocatedCapture -RunManifestPath $script:CapabilityManifestPath `
                -FieldContractPath $script:CapabilityFieldContractPath -ModelSchemaRecordPath $script:CapabilityModelSchemaPath `
                -ModelName PersonalMasterDataFixed -ModelVersion '1.0' `
                -Operator 'admin@caldova25668747.onmicrosoft.com' `
                -AdapterScriptPath $script:CapabilityAdapterPath -OutputPath $replayPath
            $result.status | Should -Be 'passed'
            $liveHash = (Get-FileHash -LiteralPath $replayPath -Algorithm SHA256).Hash.ToLowerInvariant()
            $historicalHash = & (Get-Module Caldova.HrFrontier.AiBuilder) {
                param($Path, $Adapter, $Raw)
                Get-HrAiBuilderTask8ReplayHash -Path $Path -AdapterPath $Adapter -RawPath $Raw
            } $replayPath $script:CapabilityAdapterPath $rawPath
            $historicalHash | Should -Be '923290087a0701ed700bd3f54e28d7cbe4f18048688ecab94b3b8fd0bedc8b76'
            $liveHash | Should -Not -Be $historicalHash
            (Get-FileHash -LiteralPath $replayPath -Algorithm SHA256).Hash.ToLowerInvariant() | Should -Be $liveHash
        }

        It 'rejects Task 8 replay metadata with <Mutation>' -TestCases @(
            @{ Mutation = 'wrong adapter' }, @{ Mutation = 'wrong raw path' },
            @{ Mutation = 'relative adapter' }, @{ Mutation = 'relative raw path' },
            @{ Mutation = 'wrong run' }, @{ Mutation = 'wrong model' },
            @{ Mutation = 'wrong version' }, @{ Mutation = 'duplicate document' }
        ) {
            param($Mutation)
            $replayPath = Join-Path $TestDrive ("invalid-metadata-{0}.json" -f ($Mutation -replace ' ', '-'))
            $rawPath = Join-Path $script:CapabilityCaptureDirectory 'cap-20260930094537354Z-34bf8987.ai-builder.raw.json'
            $result = ConvertFrom-HrAiBuilderEvaluationCapture `
                -CaptureDirectory $script:CapabilityCaptureDirectory -RunManifestPath $script:CapabilityManifestPath `
                -FieldContractPath $script:CapabilityFieldContractPath -ModelSchemaRecordPath $script:CapabilityModelSchemaPath `
                -ModelName PersonalMasterDataFixed -ModelVersion '1.0' `
                -Operator 'admin@caldova25668747.onmicrosoft.com' `
                -AdapterScriptPath $script:CapabilityAdapterPath -OutputPath $replayPath
            $result.status | Should -Be 'passed'
            & (Get-Module Caldova.HrFrontier.AiBuilder) {
                param($Path, $Mutation)
                $capture = Read-HrAiBuilderJson -Path $Path -Description 'Replay test'
                switch ($Mutation) {
                    'wrong adapter' { $capture.adapter_script_path += '.other' }
                    'wrong raw path' { $capture.documents[0].source_export_path += '.other' }
                    'relative adapter' { $capture.adapter_script_path = 'adapter.ps1' }
                    'relative raw path' { $capture.documents[0].source_export_path = 'capture.json' }
                    'wrong run' { $capture.run_id = 'other-run' }
                    'wrong model' { $capture.model_name = 'PersonalMasterDataGeneral' }
                    'wrong version' { $capture.model_version = '2.0' }
                    'duplicate document' { $capture.documents = @($capture.documents[0], $capture.documents[0]) }
                }
                [IO.File]::WriteAllBytes($Path, (ConvertTo-HrAiBuilderCanonicalJson $capture))
            } $replayPath $Mutation
            {
                & (Get-Module Caldova.HrFrontier.AiBuilder) {
                    param($Path, $Adapter, $Raw)
                    Get-HrAiBuilderTask8ReplayHash -Path $Path -AdapterPath $Adapter -RawPath $Raw
                } $replayPath $script:CapabilityAdapterPath $rawPath
            } | Should -Throw '*Task 8 replay*'
        }

        It 'keeps tampered replay values bound to the historical digest' {
            $replayPath = Join-Path $TestDrive 'tampered-content-replay.json'
            $rawPath = Join-Path $script:CapabilityCaptureDirectory 'cap-20260930094537354Z-34bf8987.ai-builder.raw.json'
            ConvertFrom-HrAiBuilderEvaluationCapture `
                -CaptureDirectory $script:CapabilityCaptureDirectory -RunManifestPath $script:CapabilityManifestPath `
                -FieldContractPath $script:CapabilityFieldContractPath -ModelSchemaRecordPath $script:CapabilityModelSchemaPath `
                -ModelName PersonalMasterDataFixed -ModelVersion '1.0' `
                -Operator 'admin@caldova25668747.onmicrosoft.com' `
                -AdapterScriptPath $script:CapabilityAdapterPath -OutputPath $replayPath | Out-Null
            $tamperedHash = & (Get-Module Caldova.HrFrontier.AiBuilder) {
                param($Path, $Adapter, $Raw)
                $capture = Read-HrAiBuilderJson -Path $Path -Description 'Replay test'
                $capture.documents[0].fields.first_name.value = 'Tampered'
                [IO.File]::WriteAllBytes($Path, (ConvertTo-HrAiBuilderCanonicalJson $capture))
                Get-HrAiBuilderTask8ReplayHash -Path $Path -AdapterPath $Adapter -RawPath $Raw
            } $replayPath $script:CapabilityAdapterPath $rawPath
            $tamperedHash | Should -Not -Be '923290087a0701ed700bd3f54e28d7cbe4f18048688ecab94b3b8fd0bedc8b76'
        }

        It 'rejects malformed Task 8 replay bytes' {
            $replayPath = Join-Path $TestDrive 'malformed-replay.json'
            [IO.File]::WriteAllText($replayPath, '{', [Text.UTF8Encoding]::new($false))
            {
                & (Get-Module Caldova.HrFrontier.AiBuilder) {
                    param($Path)
                    Get-HrAiBuilderTask8ReplayHash -Path $Path -AdapterPath 'C:\adapter.ps1' -RawPath 'C:\raw.json'
                } $replayPath
            } | Should -Throw '*Task 8 replay*'
        }

        It 'rejects noncanonical bytes rather than silently normalizing the historical replay' {
            $replayPath = Join-Path $TestDrive 'noncanonical-replay.json'
            $rawPath = Join-Path $script:CapabilityCaptureDirectory 'cap-20260930094537354Z-34bf8987.ai-builder.raw.json'
            $result = ConvertFrom-HrAiBuilderEvaluationCapture `
                -CaptureDirectory $script:CapabilityCaptureDirectory -RunManifestPath $script:CapabilityManifestPath `
                -FieldContractPath $script:CapabilityFieldContractPath -ModelSchemaRecordPath $script:CapabilityModelSchemaPath `
                -ModelName PersonalMasterDataFixed -ModelVersion '1.0' `
                -Operator 'admin@caldova25668747.onmicrosoft.com' `
                -AdapterScriptPath $script:CapabilityAdapterPath -OutputPath $replayPath
            $result.status | Should -Be 'passed'
            [IO.File]::AppendAllText($replayPath, ' ', [Text.UTF8Encoding]::new($false))
            {
                & (Get-Module Caldova.HrFrontier.AiBuilder) {
                    param($Path, $Adapter, $Raw)
                    Get-HrAiBuilderTask8ReplayHash -Path $Path -AdapterPath $Adapter -RawPath $Raw
                } $replayPath $script:CapabilityAdapterPath $rawPath
            } | Should -Throw '*not canonically serialized*'
        }

        It 'keeps the flow off and proves no holdout or general model exposure' {
            $capability = Get-Content -LiteralPath $script:CapabilityPath -Raw | ConvertFrom-Json

            $capability.flow_state | Should -Be 'Off'
            $capability.holdout_exposed | Should -BeFalse
            $capability.capture_pair.source_assignment | Should -Be 'training'
            $capability.exclusions.tenant_call | Should -BeTrue
            $capability.exclusions.model_2_0_mutation | Should -BeTrue
            $capability.exclusions.business_use_claim | Should -BeTrue
            $capability.exclusions.model_quality_claim | Should -BeTrue
        }

        It 'retains the complete lifecycle histories through solution addition' {
            $manifestText = Get-Content -LiteralPath $script:CapabilityManifestPath -Raw
            $inventoryText = Get-Content -LiteralPath $script:CapabilityInventoryPath -Raw
            $convertFromJson = Get-Command ConvertFrom-Json -ErrorAction Stop
            if ($convertFromJson.Parameters.ContainsKey('DateKind')) {
                $manifest = $manifestText | ConvertFrom-Json -DateKind String
                $inventory = $inventoryText | ConvertFrom-Json -DateKind String
            }
            else {
                $manifest = $manifestText | ConvertFrom-Json
                $inventory = $inventoryText | ConvertFrom-Json
            }
            $manifestModel = @($manifest.models | Where-Object display_name -eq 'PersonalMasterDataFixed')[0]
            $inventoryModel = @($inventory.models | Where-Object display_name -eq 'PersonalMasterDataFixed')[0]

            $manifestModel.lifecycle_stage | Should -Be 'added_to_solution'
            $inventoryModel.lifecycle_stage | Should -Be 'added_to_solution'
            @($manifestModel.lifecycle_history | ForEach-Object { "$($_.stage)|$($_.changed_at_utc)" }) | Should -Be @(
                'not_created|2026-09-28T14:15:49.4691784Z'
                'created|2026-09-29T06:42:34.4504815Z'
                'schema_defined|2026-09-29T06:42:34.5916192Z'
                'tagged|2026-09-29T09:11:11.1735703Z'
                'trained|2026-09-29T09:11:11.2151672Z'
                'blocked|2026-09-29T09:13:38.1846955Z'
                'evaluation_published|2026-09-29T14:16:34.8902538Z'
                'blocked|2026-09-30T08:20:52.1561940Z'
                "capture_validated|$($manifestModel.lifecycle_history[-4].changed_at_utc)"
                "evaluated|$($manifestModel.lifecycle_history[-3].changed_at_utc)"
                "approved_for_solution|$($manifestModel.lifecycle_history[-2].changed_at_utc)"
                "added_to_solution|$($manifestModel.lifecycle_history[-1].changed_at_utc)"
            )
            @($inventoryModel.lifecycle_history | ForEach-Object { "$($_.stage)|$($_.changed_at_utc)" }) | Should -Be @(
                'not_created|2026-09-28T14:15:49.4691784Z'
                'created|2026-09-29T06:42:34.4542671Z'
                'schema_defined|2026-09-29T06:42:34.5916446Z'
                'tagged|2026-09-29T09:11:11.1829972Z'
                'trained|2026-09-29T09:11:11.2151895Z'
                'blocked|2026-09-29T09:13:38.1865217Z'
                'evaluation_published|2026-09-29T14:16:34.8922386Z'
                'blocked|2026-09-30T08:20:52.1598169Z'
                "capture_validated|$($inventoryModel.lifecycle_history[-4].changed_at_utc)"
                "evaluated|$($inventoryModel.lifecycle_history[-3].changed_at_utc)"
                "approved_for_solution|$($inventoryModel.lifecycle_history[-2].changed_at_utc)"
                "added_to_solution|$($inventoryModel.lifecycle_history[-1].changed_at_utc)"
            )

            $fieldBoM = Get-Content -LiteralPath $script:CapabilityFieldBoMPath -Raw
            $testBoM = Get-Content -LiteralPath $script:CapabilityTestBoMPath -Raw
            $fieldBoM | Should -Match 'capture-capability\.json'
            $fieldBoM | Should -Match '`Evaluated`'
            $testBoM | Should -Match 'capture-capability\.json'
            $testBoM | Should -Match 'strict held-out evaluation'
        }
    }

    Describe 'AI Builder evaluation capture intent evidence' {
        BeforeAll {
            $root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
            $script:EvaluationIntentPath = Join-Path $root 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001\evaluation-capture-intent.json'
            $script:EvaluationReadinessPath = Join-Path $root 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001\evaluation-capture-readiness.json'
            $script:EvaluationFlowDefinitionPath = Join-Path $root 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001\evaluation-flow-definition.md'
            $script:EvaluationFlowExportPath = Join-Path $root 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001\evaluation-flow-export.json'
            $script:GeneralCaptureCapabilityPath = Join-Path $root 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001\capture-capability-general.json'
            $script:GeneralHoldoutLedgerPath = Join-Path $root 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001\holdout-consumption-general.json'
            $script:GeneralHoldoutBlockedPath = Join-Path $root 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001\general-holdout-blocked.json'
            $script:GeneralModelTaggingPath = Join-Path $root 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001\general-model-tagging.json'
            $script:RunManifestPath = Join-Path $root 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001\run-manifest.json'
            $script:ModelInventoryPath = Join-Path $root 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001\model-inventory.json'
            $script:TrainingCaptureAttemptPath = Join-Path $root 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001\training-capture-attempt.json'
            $script:Task6PermissionAnalysisPath = Join-Path $root 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001\task6-permission-analysis.json'
            $script:Task6FailedUploadRequestPath = Join-Path $root 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001\task6-failed-upload-request.json'
            $script:Task6TrainingCaptureRetryPath = Join-Path $root 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001\training-capture-retry.json'
            $script:Task6RetryUploadRequestPath = Join-Path $root 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001\task6-retry-upload-request.json'
            $script:Task6TrainingCaptureRemediationPath = Join-Path $root 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001\training-capture-remediation.json'
            $script:HistoricalTrainingSourcePath = Join-Path $root 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001\capture\cap-20260930094537354Z-34bf8987\source\a01-CAND-2026-0411-brunner.pdf'
            $script:TrainingCaptureFolderScreenshotPath = Join-Path $root 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001\task6-upload-failure-folder-empty.png'
            $script:TestBoM = Get-Content -LiteralPath (
                Join-Path $root 'hr\docs\ideas\uc-0001-personal-master-data-completion-agent\bom-0002-ai-builder-test-inputs-and-outcomes.md'
            ) -Raw
        }

        It 'records the selected DEV-only evaluation names, owner, connection references, and storage boundary' {
            $script:EvaluationIntentPath | Should -Exist
            $intent = Get-Content -LiteralPath $script:EvaluationIntentPath -Raw | ConvertFrom-Json

            $intent.schema_version | Should -Be '1.0'
            $intent.run_id | Should -Be 't2-dev-20260925-001'
            $intent.status | Should -Be 'approved'
            $intent.owner_run_identity | Should -Be 'admin@caldova25668747.onmicrosoft.com'
            $intent.power_platform_environment_id | Should -Be '84ad4c54-41d9-e5df-ba07-188b4719594a'

            $intent.selection.solution.display_name | Should -Be 'Caldova HR AI Evaluation DEV'
            $intent.selection.solution.unique_name | Should -Be 'calhr_ai_evaluation_dev'
            $intent.selection.flow.display_name | Should -Be 'Capture AI Builder Evaluation Evidence'
            $intent.selection.folder.name | Should -Be 'AIBuilderEvaluationEvidence'
            $intent.selection.storage.connector | Should -Be 'Tenant 2 SharePoint'
            $intent.selection.storage.location | Should -Be 'DEV Documents root'
            $intent.selection.storage.exact_folder_url | Should -Be 'https://caldova25668747.sharepoint.com/sites/HRFrontierDEV/Shared Documents/AIBuilderEvaluationEvidence'

            $intent.selection.connection_references.ai_builder.display_name | Should -Be 'Caldova HR AI Evaluation DEV AI Builder'
            $intent.selection.connection_references.ai_builder.unique_name | Should -Be 'calhr_ai_evaluation_dev_aibuilder'
            $intent.selection.connection_references.dataverse_ai_builder.display_name | Should -Be 'Caldova HR AI Evaluation DEV Dataverse (AI Builder)'
            $intent.selection.connection_references.dataverse_ai_builder.unique_name | Should -Be 'calhr_sharedcommondataserviceforapps_68a73'
            $intent.selection.connection_references.dataverse_ai_builder.connector_id | Should -Be '/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps'
            $intent.selection.connection_references.dataverse_ai_builder.usage | Should -Match 'Process documents'
            $intent.selection.connection_references.dataverse_ai_builder.unique_name_disposition | Should -Match 'generated'
            $intent.selection.connection_references.sharepoint.display_name | Should -Be 'Caldova HR AI Evaluation DEV SharePoint'
            $intent.selection.connection_references.sharepoint.unique_name | Should -Be 'calhr_ai_evaluation_dev_sharepoint'
            $intent.selection.connection_references.confirmation.status | Should -Be 'explicit_user_confirmed_with_narrowed_ai_builder_boundary'
            ([datetime]$intent.selection.connection_references.confirmation.confirmed_at_utc) -gt [datetime]'2026-09-29T13:37:13.6480000Z' | Should -BeTrue
            $intent.selection.connection_references.confirmation.source | Should -Be 'user instruction'

            $intent.fixed_model.display_name | Should -Be 'PersonalMasterDataFixed'
            $intent.fixed_model.model_id | Should -Be '74b09a72-d1f1-4598-bc4d-3746d5c97acc'
            $intent.fixed_model.version | Should -Be '1.0'
            ([datetime]$intent.approval_recorded_at_utc).ToUniversalTime().ToString('o') | Should -Be '2026-09-29T13:47:08.4090000Z'
        }

        It 'records the explicit approval response, preserved blocked evidence hash, and mutation exclusions' {
            $script:EvaluationReadinessPath | Should -Exist
            $readiness = Get-Content -LiteralPath $script:EvaluationReadinessPath -Raw | ConvertFrom-Json

            $readiness.schema_version | Should -Be '1.0'
            $readiness.run_id | Should -Be 't2-dev-20260925-001'
            $readiness.status | Should -Be 'passed'
            @($readiness.failed_gates).Count | Should -Be 0
            $readiness.owner_run_identity | Should -Be 'admin@caldova25668747.onmicrosoft.com'
            $readiness.preserved_blocked_evidence.path | Should -Be 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001\model-test-capability.json'
            $readiness.preserved_blocked_evidence.sha256 | Should -Be 'B745FAA53C2847836B23325581FFE7992DCBAD52C338B560B5EF5F613620E1CC'
            $readiness.explicit_approval.response | Should -Be 'proceed'
            ([datetime]$readiness.explicit_approval.responded_at_utc).ToUniversalTime().ToString('o') | Should -Be '2026-09-29T13:47:08.4090000Z'
            $readiness.explicit_approval.scope_summary | Should -Match 'publish only PersonalMasterDataFixed model 74b09a72-d1f1-4598-bc4d-3746d5c97acc version 1\.0 for evaluation'
            $readiness.explicit_approval.scope_summary | Should -Match 'create the unmanaged solution, manual flow, AI Builder and SharePoint connection references, and the selected SharePoint folder'
            @($readiness.explicit_approval.authorized_later_tasks) | Should -Be @('Task 4', 'Task 5', 'Task 6')
            $readiness.explicit_approval.authorization_status | Should -Be 'historical_scope_superseded_for_task_6_execution'
            $readiness.effective_current_authorization.task_4 | Should -Be 'completed'
            $readiness.effective_current_authorization.task_5 | Should -Be 'completed'
            $readiness.effective_current_authorization.task_6 | Should -Be 'training_proof_capture_preserved_for_replay'
            $readiness.effective_current_authorization.pdf_capture_authorized | Should -BeFalse
            $readiness.effective_current_authorization.authorization_consumed | Should -BeTrue
            $readiness.effective_current_authorization.retry_authorized | Should -BeFalse
            $readiness.effective_current_authorization.operational_result_path | Should -Be 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001\training-capture-attempt.json'
            $readiness.effective_current_authorization.corrected_retry_result_path | Should -Be 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001\training-capture-retry.json'
            $readiness.effective_current_authorization.remediation_result_path | Should -Be 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001\training-capture-remediation.json'
            @($readiness.task_6_attempt_history).Count | Should -Be 3
            @($readiness.explicit_approval.exclusions) | Should -Contain 'No TEST or PROD mutation'
            @($readiness.explicit_approval.exclusions) | Should -Contain 'No Tenant 1 mutation'
            @($readiness.explicit_approval.exclusions) | Should -Contain 'No Workday integration'
            @($readiness.explicit_approval.exclusions) | Should -Contain 'No holdout submission'
            @($readiness.explicit_approval.exclusions) | Should -Contain 'No draft 2.0 mutation'
            @($readiness.explicit_approval.exclusions) | Should -Contain 'No deletion'
            $readiness.selection_confirmation.connection_reference_names.status | Should -Be 'explicit_user_confirmed'
            ([datetime]$readiness.selection_confirmation.connection_reference_names.confirmed_at_utc).ToUniversalTime().ToString('o') | Should -Be '2026-09-29T13:37:13.6480000Z'
            $readiness.selection_confirmation.connection_reference_names.observation | Should -Match 'explicitly confirmed'
            ([datetime]$readiness.explicit_approval.responded_at_utc) -gt ([datetime]$readiness.selection_confirmation.connection_reference_names.confirmed_at_utc) | Should -BeTrue
            $readiness.explicit_approval_artifact.prompt | Should -Be 'All final names are now explicitly confirmed. Do you freshly approve this exact Tenant 2 DEV-only scope: publish only PersonalMasterDataFixed model 74b09a72-d1f1-4598-bc4d-3746d5c97acc version 1.0 as evaluation-only; create unmanaged solution Caldova HR AI Evaluation DEV (calhr_ai_evaluation_dev); create manual flow Capture AI Builder Evaluation Evidence; create AI Builder reference Caldova HR AI Evaluation DEV AI Builder (calhr_ai_evaluation_dev_aibuilder); create SharePoint reference Caldova HR AI Evaluation DEV SharePoint (calhr_ai_evaluation_dev_sharepoint); and create folder https://caldova25668747.sharepoint.com/sites/HRFrontierDEV/Shared Documents/AIBuilderEvaluationEvidence, owned/run only by admin@caldova25668747.onmicrosoft.com? This does not authorize business use, TEST/PROD, Tenant 1, Workday, holdouts, draft 2.0 changes, automatic deletion, or any other deletion.'
            $readiness.explicit_approval_artifact.response | Should -Be 'proceed'
            ([datetime]$readiness.explicit_approval_artifact.responded_at_utc).ToUniversalTime().ToString('o') | Should -Be '2026-09-29T13:47:08.4090000Z'
        }

        It 'records the single blocked training capture attempt without a retry or capability claim' {
            $script:TrainingCaptureAttemptPath | Should -Exist
            $script:TrainingCaptureFolderScreenshotPath | Should -Exist
            $attempt = Get-Content -LiteralPath $script:TrainingCaptureAttemptPath -Raw | ConvertFrom-Json

            $attempt.status | Should -Be 'blocked'
            $attempt.capture_stage | Should -Be 'training-proof'
            $attempt.capability_claimed | Should -BeFalse
            $attempt.authorization.response | Should -Be 'Approve exactly one training-proof capture (Recommended)'
            $attempt.selected_document.document | Should -Be 'a01-CAND-2026-0411-brunner.pdf'
            $attempt.selected_document.assignment | Should -Be 'training'
            $attempt.selected_document.manifest_sha256 | Should -Be '9c7ebe8d706b5b6ee98d779bcd83a578f8dff44b9b6bd7d02bff2b64e2ba67bd'
            $attempt.selected_document.observed_sha256 | Should -Be $attempt.selected_document.manifest_sha256
            $attempt.selected_document.hash_match | Should -BeTrue
            $attempt.attempt.attempt_number | Should -Be 1
            $attempt.attempt.http_status | Should -Be 403
            $attempt.attempt.platform_error_code | Should -Match 'System\.UnauthorizedAccessException'
            $attempt.attempt.platform_error_message | Should -Be 'Access denied.'
            $attempt.attempt.retry_performed | Should -BeFalse
            $attempt.attempt.retry_authorized | Should -BeFalse
            $attempt.containment_verification.remote_file_count | Should -Be 0
            $attempt.containment_verification.flow_state | Should -Be 'Draft'
            $attempt.containment_verification.flow_portal_state | Should -Be 'Off'
            $attempt.containment_verification.flow_run_count | Should -Be 0
            $attempt.containment_verification.flow_enabled_during_attempt | Should -BeFalse
            $attempt.containment_verification.ai_builder_invoked | Should -BeFalse
            $attempt.containment_verification.pdfs_processed | Should -Be 0
            $attempt.containment_verification.fixed_holdouts_exposed | Should -Be 0
            $attempt.containment_verification.general_holdouts_exposed | Should -Be 0
            $attempt.final_containment_verification.sharepoint_read_status | Should -Be 200
            $attempt.final_containment_verification.remote_file_count | Should -Be 0
            $attempt.final_containment_verification.flow_state | Should -Be 'Draft'
            $attempt.final_containment_verification.flow_run_count | Should -Be 0
            $attempt.root_cause_analysis.folder_permission_defect | Should -BeFalse
            $attempt.root_cause_analysis.permission_change_applied | Should -BeFalse
            $attempt.root_cause_analysis.evidence_path | Should -Be 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001\task6-permission-analysis.json'
            $attempt.root_cause_analysis.failed_request_path | Should -Be 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001\task6-failed-upload-request.json'
            (Get-FileHash -LiteralPath $script:TrainingCaptureFolderScreenshotPath -Algorithm SHA256).Hash.ToLowerInvariant() |
                Should -Be $attempt.evidence[0].sha256
        }

        It 'records that the folder already had Full Control and the endpoint scope caused the 403' {
            $script:Task6PermissionAnalysisPath | Should -Exist
            $script:Task6FailedUploadRequestPath | Should -Exist
            $analysis = Get-Content -LiteralPath $script:Task6PermissionAnalysisPath -Raw | ConvertFrom-Json
            $failedRequest = Get-Content -LiteralPath $script:Task6FailedUploadRequestPath -Raw | ConvertFrom-Json
            $evidenceRoot = Split-Path -Parent $script:Task6PermissionAnalysisPath

            $analysis.status | Should -Be 'no_permission_change_required'
            $analysis.folder.has_unique_role_assignments | Should -BeTrue
            @($analysis.role_assignments).Count | Should -Be 1
            $analysis.role_assignments[0].login_name | Should -Be 'i:0#.f|membership|admin@caldova25668747.onmicrosoft.com'
            $analysis.role_assignments[0].role_definition_name | Should -Be 'Full Control'
            $analysis.current_user.is_site_admin | Should -BeTrue
            $analysis.diagnosis.failed_endpoint_scope | Should -Be '/_api/web'
            $analysis.diagnosis.correct_endpoint_scope | Should -Be '/sites/HRFrontierDEV/_api/web'
            $analysis.diagnosis.folder_permission_defect | Should -BeFalse
            $analysis.diagnosis.permission_change_applied | Should -BeFalse
            $analysis.containment.pdf_upload_attempted_during_diagnosis | Should -BeFalse
            $analysis.containment.capture_retry_performed | Should -BeFalse
            $analysis.containment.capture_retry_authorized | Should -BeFalse
            $analysis.containment.flow_state | Should -Be 'Draft'
            $analysis.containment.flow_run_count | Should -Be 0
            $analysis.containment.holdouts_exposed | Should -Be 0

            @($analysis.raw_read_back_evidence).Count | Should -Be 4
            foreach ($record in @($analysis.raw_read_back_evidence)) {
                $rawPath = Join-Path $evidenceRoot ([IO.Path]::GetFileName([string]$record.path))
                $rawPath | Should -Exist
                (Get-Item -LiteralPath $rawPath).Length | Should -Be $record.size_bytes
                (Get-FileHash -LiteralPath $rawPath -Algorithm SHA256).Hash.ToLowerInvariant() | Should -Be $record.sha256
            }

            $folderItemText = Get-Content -LiteralPath (Join-Path $evidenceRoot 'task6-folder-item.raw.json') -Raw
            $roleAssignments = Get-Content -LiteralPath (Join-Path $evidenceRoot 'task6-folder-role-assignments.raw.json') -Raw | ConvertFrom-Json
            $currentUser = Get-Content -LiteralPath (Join-Path $evidenceRoot 'task6-current-user.raw.json') -Raw | ConvertFrom-Json
            $roleDefinitions = Get-Content -LiteralPath (Join-Path $evidenceRoot 'task6-role-definitions.raw.json') -Raw | ConvertFrom-Json

            [bool]::Parse([regex]::Match($folderItemText, '"HasUniqueRoleAssignments":(?<value>true|false)').Groups['value'].Value) |
                Should -Be $analysis.folder.has_unique_role_assignments
            [int][regex]::Match($folderItemText, '"Id":(?<value>\d+)').Groups['value'].Value |
                Should -Be $analysis.folder.list_item_id
            @($roleAssignments.value).Count | Should -Be 1
            $roleAssignments.value[0].PrincipalId | Should -Be $analysis.role_assignments[0].principal_id
            $roleAssignments.value[0].Member.LoginName | Should -Be $analysis.role_assignments[0].login_name
            $roleAssignments.value[0].RoleDefinitionBindings[0].Name | Should -Be $analysis.role_assignments[0].role_definition_name
            $currentUser.Id | Should -Be $analysis.current_user.principal_id
            $currentUser.IsSiteAdmin | Should -Be $analysis.current_user.is_site_admin
            @($roleDefinitions.value | Where-Object { $_.Id -eq $analysis.role_assignments[0].role_definition_id } | ForEach-Object { $_.Name }) |
                Should -Be @('Full Control')

            $failedRequest.page_origin | Should -Be 'https://caldova25668747.sharepoint.com'
            $failedRequest.request_relative_url | Should -Match '^/_api/web/'
            ([uri]$failedRequest.request_resolved_url).AbsolutePath | Should -Match '^/_api/web/'
            ([uri]$failedRequest.request_resolved_url).AbsolutePath | Should -Not -Match '^/sites/HRFrontierDEV/_api/web/'
            $failedRequest.method | Should -Be 'POST'
            $failedRequest.overwrite | Should -BeFalse
            $failedRequest.request_body.sha256 | Should -Be '9c7ebe8d706b5b6ee98d779bcd83a578f8dff44b9b6bd7d02bff2b64e2ba67bd'
            $failedRequest.response.http_status | Should -Be 403
            $failedRequest.response.ok | Should -BeFalse
            $failedRequest.response.raw_path | Should -Be $analysis.failed_request_evidence.raw_error_path
            $failedErrorPath = Join-Path $evidenceRoot ([IO.Path]::GetFileName([string]$failedRequest.response.raw_path))
            (Get-Item -LiteralPath $failedErrorPath).Length | Should -Be $failedRequest.response.size_bytes
            (Get-FileHash -LiteralPath $failedErrorPath -Algorithm SHA256).Hash.ToLowerInvariant() |
                Should -Be $failedRequest.response.sha256
            $failedError = Get-Content -LiteralPath $failedErrorPath -Raw | ConvertFrom-Json
            $failedError.'odata.error'.code | Should -Match 'System\.UnauthorizedAccessException'
            $failedError.'odata.error'.message.value | Should -Be 'Access denied.'
            $analysis.diagnosis.failed_endpoint_scope | Should -Be ([uri]$failedRequest.request_resolved_url).AbsolutePath.Substring(
                0,
                ([uri]$failedRequest.request_resolved_url).AbsolutePath.IndexOf('/GetFolderByServerRelativeUrl')
            )
        }

        It 'blocks the corrected retry when the stored source bytes differ before flow enablement' {
            $script:Task6TrainingCaptureRetryPath | Should -Exist
            $script:Task6RetryUploadRequestPath | Should -Exist
            $retry = Get-Content -LiteralPath $script:Task6TrainingCaptureRetryPath -Raw | ConvertFrom-Json
            $uploadRequest = Get-Content -LiteralPath $script:Task6RetryUploadRequestPath -Raw | ConvertFrom-Json
            $evidenceRoot = Split-Path -Parent $script:Task6TrainingCaptureRetryPath
            $security = Get-Content -LiteralPath (Join-Path $evidenceRoot 'security-verification.json') -Raw | ConvertFrom-Json
            $localSource = $script:HistoricalTrainingSourcePath
            $remoteSource = Join-Path $evidenceRoot 'task6-retry-remote-source-mismatch.pdf'
            $screenshot = Join-Path $evidenceRoot 'task6-retry-source-mismatch-folder.png'

            $retry.status | Should -Be 'blocked'
            $retry.capability_claimed | Should -BeFalse
            $retry.selected_document.assignment | Should -Be 'training'
            (Get-Item -LiteralPath $localSource).Length | Should -Be $retry.selected_document.qualified_size_bytes
            (Get-FileHash -LiteralPath $localSource -Algorithm SHA256).Hash.ToLowerInvariant() |
                Should -Be $retry.selected_document.qualified_sha256
            $retry.upload.endpoint_scope | Should -Be '/sites/HRFrontierDEV/_api/web'
            $retry.upload.overwrite | Should -BeFalse
            $retry.upload.http_status | Should -Be 200
            ([uri]$uploadRequest.request_resolved_url).AbsolutePath | Should -Match '^/sites/HRFrontierDEV/_api/web/'
            $uploadRequest.method | Should -Be $retry.upload.method
            $uploadRequest.overwrite | Should -Be $retry.upload.overwrite
            $uploadRequest.response.http_status | Should -Be $retry.upload.http_status
            $requestBodyPath = Join-Path $evidenceRoot ([IO.Path]::GetFileName([string]$uploadRequest.request_body.path))
            (Get-Item -LiteralPath $requestBodyPath).Length | Should -Be $uploadRequest.request_body.size_bytes
            (Get-FileHash -LiteralPath $requestBodyPath -Algorithm SHA256).Hash.ToLowerInvariant() |
                Should -Be $uploadRequest.request_body.sha256
            $uploadResponsePath = Join-Path $evidenceRoot ([IO.Path]::GetFileName([string]$uploadRequest.response.raw_path))
            (Get-Item -LiteralPath $uploadResponsePath).Length | Should -Be $uploadRequest.response.size_bytes
            (Get-FileHash -LiteralPath $uploadResponsePath -Algorithm SHA256).Hash.ToLowerInvariant() |
                Should -Be $uploadRequest.response.sha256
            $uploadResponse = Get-Content -LiteralPath $uploadResponsePath -Raw | ConvertFrom-Json
            $uploadResponse.Name | Should -Be $retry.selected_document.document
            $uploadResponse.ServerRelativeUrl | Should -Be $retry.upload.remote_path
            $uploadResponse.UniqueId | Should -Be $retry.upload.remote_unique_id
            [int]$uploadResponse.Length | Should -Be $retry.pre_flow_byte_verification.remote_size_bytes
            (Get-Item -LiteralPath $remoteSource).Length | Should -Be $retry.pre_flow_byte_verification.remote_size_bytes
            (Get-FileHash -LiteralPath $remoteSource -Algorithm SHA256).Hash.ToLowerInvariant() |
                Should -Be $retry.pre_flow_byte_verification.remote_sha256
            $retry.pre_flow_byte_verification.size_match | Should -BeFalse
            $retry.pre_flow_byte_verification.sha256_match | Should -BeFalse
            $retry.containment.flow_state | Should -Be 'Draft'
            $retry.containment.flow_run_count | Should -Be 0
            $retry.containment.flow_enabled_during_retry | Should -BeFalse
            $retry.containment.ai_builder_invoked | Should -BeFalse
            $retry.containment.pdfs_processed | Should -Be 0
            $retry.containment.fixed_holdouts_exposed | Should -Be 0
            $retry.containment.general_holdouts_exposed | Should -Be 0
            $retry.containment.folder_file_count | Should -Be 1
            $retry.containment.remote_file_retained | Should -BeTrue
            $retry.containment.remote_file_deleted | Should -BeFalse
            $retry.containment.retry_performed_after_mismatch | Should -BeFalse
            $retry.containment.additional_retry_authorized | Should -BeFalse
            $security.authorization_boundary.pdf_count | Should -Be 2
            $security.authorization_boundary.folder_file_count_after_corrected_retry | Should -Be $retry.containment.folder_file_count
            $security.authorization_boundary.processed_pdf_count | Should -Be 1
            $security.authorization_boundary.processed_pdf_count_after_corrected_retry | Should -Be $retry.containment.pdfs_processed
            $security.authorization_boundary.run_count | Should -Be 1
            (Get-FileHash -LiteralPath $screenshot -Algorithm SHA256).Hash.ToLowerInvariant() |
                Should -Be $retry.evidence[1].sha256
        }

        It 'preserves the failed bytes and uses native upload of the allow-listed filename before flow enablement' {
            $script:Task6TrainingCaptureRemediationPath | Should -Exist
            $remediation = Get-Content -LiteralPath $script:Task6TrainingCaptureRemediationPath -Raw | ConvertFrom-Json
            $evidenceRoot = Split-Path -Parent $script:Task6TrainingCaptureRemediationPath
            $qualifiedSource = $script:HistoricalTrainingSourcePath
            $retainedMismatch = Join-Path $evidenceRoot $remediation.preserved_failure_evidence.local_evidence_filename
            $verifiedSource = Join-Path $evidenceRoot $remediation.native_upload.remote_read_back_evidence_filename

            $remediation.authorization.response | Should -Be 'Approve the design and controlled attempt (Recommended)'
            $remediation.authorization.filename_collision_resolution | Should -Be 'rename_retained_mismatch_then_upload_allow_listed_filename'
            $remediation.native_upload.method | Should -Be 'playwright_set_input_files'
            $remediation.native_upload.inline_base64_used | Should -BeFalse
            $remediation.native_upload.overwrite | Should -BeFalse
            $remediation.native_upload.target_filename | Should -Be $remediation.selected_document.original_filename
            $remediation.preserved_failure_evidence.remote_filename_after_rename |
                Should -Not -Be $remediation.selected_document.original_filename
            (Get-Item -LiteralPath $qualifiedSource).Length | Should -Be 3042
            (Get-FileHash -LiteralPath $qualifiedSource -Algorithm SHA256).Hash.ToLowerInvariant() |
                Should -Be '9c7ebe8d706b5b6ee98d779bcd83a578f8dff44b9b6bd7d02bff2b64e2ba67bd'
            (Get-Item -LiteralPath $retainedMismatch).Length | Should -Be 3038
            (Get-FileHash -LiteralPath $retainedMismatch -Algorithm SHA256).Hash.ToLowerInvariant() |
                Should -Be '74c042e2419054136cc512c58ae252b9803f2a6cd7bdfc9d8acff2b04bc4b618'
            (Get-Item -LiteralPath $verifiedSource).Length | Should -Be $remediation.pre_flow_byte_verification.remote_size_bytes
            (Get-FileHash -LiteralPath $verifiedSource -Algorithm SHA256).Hash.ToLowerInvariant() |
                Should -Be $remediation.pre_flow_byte_verification.remote_sha256
            $remediation.pre_flow_byte_verification.remote_size_bytes | Should -Be 3042
            $remediation.pre_flow_byte_verification.remote_sha256 |
                Should -Be '9c7ebe8d706b5b6ee98d779bcd83a578f8dff44b9b6bd7d02bff2b64e2ba67bd'
            $remediation.pre_flow_byte_verification.size_match | Should -BeTrue
            $remediation.pre_flow_byte_verification.sha256_match | Should -BeTrue
            $remediation.pre_flow_byte_verification.gate_passed | Should -BeTrue
            $remediation.flow_invocation.status | Should -Be 'Succeeded'
            $remediation.flow_invocation.invocation_count | Should -Be 1
            $remediation.flow_invocation.flow_state_after_run | Should -Be 'Draft'
            $remediation.flow_invocation.flow_portal_state_after_run | Should -Be 'Off'
            $remediation.containment.flow_run_count | Should -Be 1
            $remediation.containment.pdfs_processed | Should -Be 1
            $remediation.containment.flow_state | Should -Be 'Draft'
            $remediation.containment.flow_portal_state | Should -Be 'Off'
            $remediation.containment.fixed_holdouts_exposed | Should -Be 0
            $remediation.containment.general_holdouts_exposed | Should -Be 0

            $capturePairPath = Join-Path $evidenceRoot $remediation.capture_artifacts.capture_pair_path
            $capturePairPath | Should -Exist
            (Get-Item -LiteralPath $capturePairPath).Length |
                Should -Be $remediation.capture_artifacts.capture_pair_size_bytes
            (Get-FileHash -LiteralPath $capturePairPath -Algorithm SHA256).Hash.ToLowerInvariant() |
                Should -Be $remediation.capture_artifacts.capture_pair_sha256
            $pair = Get-Content -LiteralPath $capturePairPath -Raw | ConvertFrom-Json
            $pair.PSObject.Properties.Name | Should -Not -Contain 'status'
            $pair.PSObject.Properties.Name | Should -Not -Contain 'pass'
            $pair.run_id | Should -Be $remediation.flow_invocation.execution_run_id
            $pair.capture_stage | Should -Be 'training-proof'
            $pair.source.sha256 | Should -Be $remediation.pre_flow_byte_verification.remote_sha256
            foreach ($artifactName in @('source', 'raw', 'canonical')) {
                $artifact = $pair.$artifactName
                $artifactPath = Join-Path $evidenceRoot $artifact.local_path
                (Get-Item -LiteralPath $artifactPath).Length | Should -Be $artifact.size_bytes
                (Get-FileHash -LiteralPath $artifactPath -Algorithm SHA256).Hash.ToLowerInvariant() |
                    Should -Be $artifact.sha256
            }
        }

        It 'records the separately approved publisher after exact read-back and preserves the blocked publisher-gate attempt' {
            $intent = Get-Content -LiteralPath $script:EvaluationIntentPath -Raw | ConvertFrom-Json
            $readiness = Get-Content -LiteralPath $script:EvaluationReadinessPath -Raw | ConvertFrom-Json

            $intent.selection.publisher.friendly_name | Should -Be 'Caldova HR frontier'
            $intent.selection.publisher.unique_name | Should -Be 'calhrfrontier'
            $intent.selection.publisher.prefix | Should -Be 'calhr'
            $intent.selection.publisher.publisher_id | Should -Be '6b6eabd8-57b6-40b7-9d12-7b2a045978e8'
            $intent.selection.publisher.confirmation.status | Should -Be 'explicit_user_approved_after_read_back'
            ([datetime]$intent.selection.publisher.confirmation.approved_at_utc).ToUniversalTime().ToString('o') | Should -Be '2026-09-29T14:32:33.6190000Z'
            ([datetime]$intent.selection.publisher.confirmation.read_back_at_utc).ToUniversalTime().ToString('o') | Should -Be '2026-09-29T14:34:04.9180873Z'
            $intent.selection.publisher.confirmation.source | Should -Be 'user message; pac env fetch'

            $readiness.selection_confirmation.publisher.status | Should -Be 'explicit_user_approved_after_read_back'
            $readiness.selection_confirmation.publisher.friendly_name | Should -Be 'Caldova HR frontier'
            $readiness.selection_confirmation.publisher.unique_name | Should -Be 'calhrfrontier'
            $readiness.selection_confirmation.publisher.prefix | Should -Be 'calhr'
            $readiness.selection_confirmation.publisher.publisher_id | Should -Be '6b6eabd8-57b6-40b7-9d12-7b2a045978e8'
            ([datetime]$readiness.selection_confirmation.publisher.approved_at_utc).ToUniversalTime().ToString('o') | Should -Be '2026-09-29T14:32:33.6190000Z'
            ([datetime]$readiness.selection_confirmation.publisher.read_back_at_utc).ToUniversalTime().ToString('o') | Should -Be '2026-09-29T14:34:04.9180873Z'

            $blockedAttempt = @($readiness.task_5_attempt_history | Where-Object {
                    $_.attempt -eq 1 -and $_.status -eq 'blocked' -and $_.blocker_id -eq 'publisher_not_recorded_in_intent'
                })
            $blockedAttempt.Count | Should -Be 1
            $blockedAttempt[0].evidence_commit | Should -Be 'dbcd3684a2e5a790382e58af8d8808a1471073a4'
            $blockedAttempt[0].evidence_path | Should -Be 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001\security-verification.json'
        }

        It 'records the completed Task 5 flow without erasing either historical blocker' {
            $root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
            $securityPath = Join-Path $root 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001\security-verification.json'
            $readiness = Get-Content -LiteralPath $script:EvaluationReadinessPath -Raw | ConvertFrom-Json
            $security = Get-Content -LiteralPath $securityPath -Raw | ConvertFrom-Json

            $security.status | Should -Be 'passed'
            $security.current_attempt.attempt | Should -Be 3
            $security.current_attempt.status | Should -Be 'passed'
            $security.resource_read_back.evaluation_solution.solution_id | Should -Be 'df590fd2-13bc-f111-aaae-7ced8d44be51'
            $security.resource_read_back.evaluation_solution.state | Should -Be 'created_unmanaged'
            $security.resource_read_back.sharepoint_connection_reference.connection_reference_id | Should -Be '94b29de5-14bc-f111-aaae-70a8a505d538'
            $security.resource_read_back.sharepoint_connection_reference.connector_id | Should -Be '/providers/Microsoft.PowerApps/apis/shared_sharepointonline'
            $security.resource_read_back.dataverse_ai_builder_connection_reference.display_name | Should -Be 'Caldova HR AI Evaluation DEV Dataverse (AI Builder)'
            $security.resource_read_back.dataverse_ai_builder_connection_reference.unique_name | Should -Be 'calhr_sharedcommondataserviceforapps_68a73'
            $security.resource_read_back.dataverse_ai_builder_connection_reference.connector_id | Should -Be '/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps'
            $security.resource_read_back.dataverse_ai_builder_connection_reference.state | Should -Be 'created_active'
            $security.resource_read_back.dataverse_ai_builder_connection_reference.usage | Should -Match 'Process documents'
            $security.resource_read_back.sharepoint_folder.state | Should -Be 'empty_restricted'
            @($security.resource_read_back.sharepoint_folder.principals) | Should -Be @('admin@caldova25668747.onmicrosoft.com')
            $security.resource_read_back.flow.workflow_id | Should -Be '24e38f04-9ebc-f111-aaae-7ced8d44be51'
            $security.resource_read_back.flow.state | Should -Be 'saved_off'
            $security.resource_read_back.flow.exact_name_match_count | Should -Be 1
            $security.resource_read_back.flow.run_count | Should -Be 0

            $history = @($readiness.task_5_attempt_history)
            $history.Count | Should -Be 3
            $history[0].attempt | Should -Be 1
            $history[0].blocker_id | Should -Be 'publisher_not_recorded_in_intent'
            $history[1].attempt | Should -Be 2
            $history[1].blocker_id | Should -Be 'ai_builder_connection_reference_unavailable'
            $history[2].attempt | Should -Be 3
            $history[2].status | Should -Be 'passed'

            foreach ($evidence in @($security.attended_evidence)) {
                $evidencePath = Join-Path (Split-Path -Parent $securityPath) $evidence.screenshot
                $evidencePath | Should -Exist
                (Get-FileHash -LiteralPath $evidencePath -Algorithm SHA256).Hash | Should -Be $evidence.screenshot_sha256
            }

            foreach ($checkId in @(
                    'flow_state_off',
                    'owner_and_run_only',
                    'secure_inputs_outputs',
                    'connector_inventory',
                    'model_binding',
                    'immutable_no_overwrite',
                    'flow_checker',
                    'no_pdf_submission'
                )) {
                $check = @($security.checks | Where-Object id -eq $checkId)
                $check.Count | Should -Be 1
                $check[0].status | Should -Be 'passed'
            }
        }

        It 'records the complete Off flow definition, exact bindings, and zero-run evidence' {
            $script:EvaluationFlowDefinitionPath | Should -Exist
            $definition = Get-Content -LiteralPath $script:EvaluationFlowDefinitionPath -Raw

            $definition | Should -Match 'Status.*Active'
            $definition | Should -Match '24e38f04-9ebc-f111-aaae-7ced8d44be51'
            $definition | Should -Match 'calhr_sharedcommondataserviceforapps_68a73'
            $definition | Should -Match 'calhr_ai_evaluation_dev_sharepoint'
            $definition | Should -Match 'Get source PDF'
            $definition | Should -Match 'Process documents'
            $definition | Should -Match 'Create raw response'
            $definition | Should -Match 'Build canonical envelope'
            $definition | Should -Match 'Create canonical envelope'
            $definition | Should -Match 'Terminate capture success'
            $definition | Should -Match 'Terminate capture failure'
            $definition | Should -Match 'Terminate invalid request'
            $definition | Should -Match '0 errors'
            $definition | Should -Match '0 warnings'
            $definition | Should -Match 'zero runs'
            $definition | Should -Match 'Off'
            $definition | Should -Match 'evaluation-flow-solution-inventory\.png'
            $definition | Should -Match 'evaluation-flow-off-zero-runs\.png'
            $definition | Should -Match 'evaluation-flow-definition-checker\.png'
            $definition | Should -Match 'evaluation-flow-trigger-controls\.png'
        }

        It 'preserves and structurally verifies the exported flow definition' {
            $script:EvaluationFlowExportPath | Should -Exist
            $exportHash = (Get-FileHash -LiteralPath $script:EvaluationFlowExportPath -Algorithm SHA256).Hash
            $exportHash | Should -Be 'FFD993249EF523E93897E1FFB7D6D086C2395959B89CFFBF0DEE0418E753A4B7'
            $flow = Get-Content -LiteralPath $script:EvaluationFlowExportPath -Raw | ConvertFrom-Json
            $definition = $flow.properties.definition
            $trigger = $definition.triggers.manual
            $condition = $definition.actions.Validate_capture_request
            $scope = $condition.actions.Capture_evidence

            @($flow.properties.connectionReferences.psobject.Properties.Name | Sort-Object) |
                Should -Be @('shared_commondataserviceforapps', 'shared_sharepointonline')
            $flow.properties.connectionReferences.shared_commondataserviceforapps.connection.connectionReferenceLogicalName |
                Should -Be 'calhr_sharedcommondataserviceforapps_68a73'
            $flow.properties.connectionReferences.shared_sharepointonline.connection.connectionReferenceLogicalName |
                Should -Be 'calhr_ai_evaluation_dev_sharepoint'

            @($trigger.inputs.schema.required).Count | Should -Be 6
            @($trigger.inputs.schema.properties.psobject.Properties.Value.title) |
                Should -Be @('source_pdf', 'expected_filename', 'expected_sha256', 'execution_run_id', 'corpus_revision', 'capture_stage')
            @($trigger.inputs.schema.properties.text_4.enum) |
                Should -Be @('training-proof', 'fixed-holdout', 'general-holdout')
            @($trigger.runtimeConfiguration.secureData.properties) | Should -Be @('inputs', 'outputs')

            $condition.type | Should -Be 'If'
            $conditionExpression = $condition.expression | ConvertTo-Json -Depth 30 -Compress
            $conditionExpression | Should -Match 'c0310c527f010cc9a24d7a78dae7db1e5ad136116b14306413162fb4223926db'
            $conditionExpression | Should -Match 'training-proof'
            $conditionExpression | Should -Match 'fixed-holdout'
            $conditionExpression | Should -Match 'a01-CAND-2026-0411-brunner\.pdf'
            $conditionExpression | Should -Match 'd06-CAND-2026-0434-ochsner\.pdf'
            $conditionExpression | Should -Match 'g01-arbeitsvertrag-CAND-2026-0411\.pdf'
            $conditionExpression | Should -Not -Match 'g03-arbeitsvertrag-CAND-2026-0413\.pdf'
            @($condition.expression.and[-1].or).Count | Should -Be 2

            @($scope.actions.psobject.Properties.Name) |
                Should -Be @('Get_source_PDF', 'Process_documents', 'Create_raw_response', 'Build_canonical_envelope', 'Create_canonical_envelope')
            $scope.actions.Get_source_PDF.inputs.host.operationId | Should -Be 'GetFileContentByPath'
            $scope.actions.Get_source_PDF.inputs.parameters.path |
                Should -Be "@concat('/Shared Documents/AIBuilderEvaluationEvidence/', triggerBody()?['text'])"
            @($scope.actions.Process_documents.runAfter.Get_source_PDF) | Should -Be @('Succeeded')
            $scope.actions.Process_documents.inputs.host.operationId | Should -Be 'aibuilderpredict_formsprocessing'
            $scope.actions.Process_documents.inputs.parameters.recordId | Should -Be '057bb758-4f5d-47d8-82ca-25eaf0a1cf07'
            $scope.actions.Process_documents.inputs.parameters.'item/requestv2/base64Encoded' | Should -Be "@body('Get_source_PDF')"
            @($scope.actions.Process_documents.runtimeConfiguration.secureData.properties) | Should -Be @('inputs', 'outputs')

            $canonical = $scope.actions.Build_canonical_envelope.inputs
            @($canonical.psobject.Properties.Name) |
                Should -Be @('schema_version', 'run_id', 'corpus_revision', 'filename', 'claimed_sha256', 'model_name', 'model_version', 'captured_at_utc', 'fields')
            @($canonical.fields.psobject.Properties.Name) |
                Should -Be @('candidate_id', 'last_name', 'first_name', 'dob', 'nationality', 'marital', 'heimatort', 'permit', 'street', 'plz', 'city', 'ahv', 'iban', 'phone', 'email', 'ec_name', 'ec_phone')
            $canonical.model_name | Should -Be 'PersonalMasterDataGeneral'
            $canonical.model_version | Should -Be '10/1/2026, 11:48:30 AM'
            foreach ($field in @($canonical.fields.psobject.Properties.Value)) {
                @($field.psobject.Properties.Name) | Should -Be @('value', 'confidence')
            }

            $scope.actions.Create_raw_response.inputs.parameters.name |
                Should -Be "@concat(triggerBody()?['text_2'], '.ai-builder.raw.json')"
            $scope.actions.Create_raw_response.inputs.parameters.body |
                Should -Be "@string(body('Process_documents'))"
            $scope.actions.Create_canonical_envelope.inputs.parameters.name |
                Should -Be "@concat(triggerBody()?['text_2'], '.canonical.json')"
            $scope.actions.Create_canonical_envelope.inputs.parameters.body |
                Should -Be "@concat(string(outputs('Build_canonical_envelope')), decodeUriComponent('%0A'))"

            @($condition.actions.Terminate_capture_success.runAfter.Capture_evidence) | Should -Be @('Succeeded')
            $condition.actions.Terminate_capture_success.inputs.runStatus | Should -Be 'Succeeded'
            @($condition.actions.Terminate_capture_failure.runAfter.Capture_evidence) | Should -Be @('Failed', 'TimedOut')
            $condition.actions.Terminate_capture_failure.inputs.runStatus | Should -Be 'Failed'
            $condition.else.actions.Terminate_invalid_request.inputs.runStatus | Should -Be 'Failed'
        }

        It 'records the passed general capability proof and stops after the first holdout fails validation' {
            $capability = Get-Content -LiteralPath $script:GeneralCaptureCapabilityPath -Raw | ConvertFrom-Json
            $ledger = Get-Content -LiteralPath $script:GeneralHoldoutLedgerPath -Raw | ConvertFrom-Json
            $blocked = Get-Content -LiteralPath $script:GeneralHoldoutBlockedPath -Raw | ConvertFrom-Json
            $tagging = Get-Content -LiteralPath $script:GeneralModelTaggingPath -Raw | ConvertFrom-Json
            $manifest = Get-Content -LiteralPath $script:RunManifestPath -Raw | ConvertFrom-Json
            $inventory = Get-Content -LiteralPath $script:ModelInventoryPath -Raw | ConvertFrom-Json

            $capability.status | Should -Be 'passed'
            $capability.decision | Should -Be 'capture_validated'
            @($capability.failed_gates).Count | Should -Be 0
            @($capability.gates.id) | Should -Be @(
                'AEC-G001', 'AEC-G002', 'AEC-G003', 'AEC-G004', 'AEC-G005', 'AEC-G006', 'AEC-G007'
            )
            $capability.flow_state | Should -Be 'Off'
            $capability.holdout_exposed | Should -BeFalse
            @($tagging.model.psobject.Properties.Name) | Should -Not -Contain 'model_version'
            $tagging.model.document_processing_release | Should -Be 'GA (v4.0)'
            $tagging.model.document_processing_release_basis | Should -Match 'not a trained-model version'

            @($ledger.holdouts).Count | Should -Be 8
            @($ledger.holdouts | Where-Object state -eq 'consumed_failed').Count | Should -Be 1
            @($ledger.holdouts | Where-Object state -eq 'unseen').Count | Should -Be 7
            $ledger.holdouts[0].document | Should -Be 'g03-arbeitsvertrag-CAND-2026-0413.pdf'
            $ledger.holdouts[0].retry_allowed | Should -BeFalse

            $blocked.status | Should -Be 'blocked'
            $blocked.calculated_failure.missing_case | Should -Be 'general-holdout'
            $blocked.calculated_failure.process_documents_executed | Should -BeFalse
            $blocked.calculated_failure.raw_output_created | Should -BeFalse
            $blocked.calculated_failure.canonical_output_created | Should -BeFalse
            $blocked.containment.flow_state | Should -Be 'Off'
            $blocked.containment.additional_holdouts_submitted | Should -Be 0
            $blocked.containment.remaining_holdouts_unseen | Should -Be 7
            $blocked.containment.evaluation_set_terminal | Should -BeTrue
            $blocked.containment.remaining_holdouts_authorized_for_future_submission | Should -BeFalse
            $blocked.decision | Should -Match 'Do not retry the consumed holdout or submit any of the remaining seven holdouts'

            @($manifest.models | Where-Object display_name -eq 'PersonalMasterDataGeneral')[0].lifecycle_stage |
                Should -Be 'blocked'
            @($inventory.models | Where-Object display_name -eq 'PersonalMasterDataGeneral')[0].lifecycle_stage |
                Should -Be 'blocked'
        }

        It 'updates the fixed-model test register to cite the approval evidence before tenant mutation' {
            $script:TestBoM | Should -Match 'evaluation-capture-intent\.json'
            $script:TestBoM | Should -Match 'evaluation-capture-readiness\.json'
            $script:TestBoM | Should -Match 'Explicit pre-mutation approval is recorded before any evaluation publication or flow creation'
        }
    }

    Describe 'AI Builder corpus qualification' {
        BeforeAll {
            $script:ModulePath = Join-Path $PSScriptRoot '..\..\src\scripts\modules\Caldova.HrFrontier.AiBuilder\Caldova.HrFrontier.AiBuilder.psd1'
            Import-Module $script:ModulePath -Force
            $script:RepositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
            $script:ContractPath = Join-Path $script:RepositoryRoot 'hr\src\ai-builder\contracts\field-contract.json'
            $script:FixedPath = Join-Path $script:RepositoryRoot 'hr\docs\ideas\uc-0001-personal-master-data-completion-agent\caldova-aib-fixed-template'
            $script:GeneralPath = Join-Path $script:RepositoryRoot 'hr\docs\ideas\uc-0001-personal-master-data-completion-agent\caldova-aib-general-documents'
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
            Set-TestUtf8BomContent -Path $reviewPath -Content ($review | ConvertTo-Json -Depth 8)

            $result = Test-HrAiBuilderCorpus -PackagePath $script:FixedPath -ModelKind Fixed `
                -ReviewPath $reviewPath -FieldContractPath $script:ContractPath

            $result.passed | Should -BeTrue
            @($result.documents | Where-Object assignment -eq 'training').Count | Should -Be 20
            @($result.documents | Where-Object assignment -eq 'held-out').Count | Should -Be 4
            @($result.documents | Where-Object { $_.sha256 -notmatch '^[a-f0-9]{64}$' }).Count | Should -Be 0
            [IO.Path]::IsPathRooted([string]$result.documents[0].source_path) | Should -BeFalse
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
            Set-TestUtf8BomContent -Path $reviewPath -Content ($review | ConvertTo-Json -Depth 8)

            $result = Test-HrAiBuilderCorpus -PackagePath $script:GeneralPath -ModelKind General `
                -ReviewPath $reviewPath -FieldContractPath $script:ContractPath

            $result.passed | Should -BeTrue
            @($result.documents | Where-Object assignment -eq 'training').Count | Should -Be 16
            @($result.documents | Where-Object assignment -eq 'held-out').Count | Should -Be 8
            [IO.Path]::IsPathRooted([string]$result.documents[0].source_path) | Should -BeFalse
            @(@($result.documents | Where-Object assignment -eq 'held-out').document | Sort-Object) | Should -Be @(
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

            function New-TestLifecycleFixture {
                param(
                    [Parameter(Mandatory)]
                    [string]$Name,

                    [Parameter()]
                    [string]$RunId = 'test-run-001',

                    [ValidateSet('PersonalMasterDataFixed', 'PersonalMasterDataGeneral')]
                    [string[]]$ModelNames = @('PersonalMasterDataFixed')
                )

                $paths = New-RunEvidencePaths -Name $Name
                $models = foreach ($modelName in $ModelNames) {
                    [pscustomobject]@{
                        display_name = $modelName
                        model_kind = if ($modelName -eq 'PersonalMasterDataFixed') { 'Fixed' } else { 'General' }
                    }
                }

                New-HrAiBuilderRunManifest -RunId $RunId -TenantKey 'tenant-2' `
                    -EnvironmentId '84ad4c54-41d9-e5df-ba07-188b4719594a' -EnvironmentStage DEV `
                    -SolutionUniqueName 'caldovahrfrontier' -SolutionVersion '0.0.0.1' `
                    -OperatorUpn 'operator@example.invalid' `
                    -StartedAtUtc ([datetime]'2026-09-25T08:00:00Z') `
                    -CorpusRevision (('a' * 64) -join '') -GeneratorRevision (('b' * 64) -join '') `
                    -FieldContractVersion '0.1' -Models @($models) -CorpusResults @() `
                    -OutputPath $paths.ManifestPath -ModelInventoryPath $paths.InventoryPath | Out-Null

                return $paths
            }

            function New-Task8CaptureDecisionFixture {
                param([Parameter(Mandatory)][string]$Name)

                $paths = New-RunEvidencePaths -Name $Name
                $evidenceRoot = Join-Path $script:RepositoryRoot 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001'
                foreach ($sourceAndDestination in @(
                    @{ Source = Join-Path $evidenceRoot 'run-manifest.json'; Destination = $paths.ManifestPath },
                    @{ Source = Join-Path $evidenceRoot 'model-inventory.json'; Destination = $paths.InventoryPath }
                )) {
                    Copy-Item -LiteralPath $sourceAndDestination.Source -Destination $sourceAndDestination.Destination
                }

                $recreatePreDecisionBytes = @'
param([string] $Path)

$document = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -DateKind String
$model = @($document.models)[0]
$model.lifecycle_stage = 'blocked'
$model.lifecycle_history = @(
    $model.lifecycle_history |
        Where-Object stage -NotIn @(
            'capture_validated',
            'evaluated',
            'approved_for_solution',
            'added_to_solution'
        )
)
$generalModel = @($document.models | Where-Object display_name -eq 'PersonalMasterDataGeneral')[0]
$generalModel.model_id = ''
$generalModel.version = ''
$generalModel.lifecycle_stage = 'not_created'
$generalModel.lifecycle_history = @(
    $generalModel.lifecycle_history |
        Where-Object stage -eq 'not_created' |
        Select-Object -First 1
)
$json = ($document | ConvertTo-Json -Depth 100) -replace "(?<!`r)`n", "`r`n"
[IO.File]::WriteAllText(
    $Path,
    "$json`r`n",
    [Text.UTF8Encoding]::new($false)
)
'@
                $recreateScriptPath = Join-Path (Split-Path -Parent $paths.ManifestPath) 'recreate-task8-predecision.ps1'
                Set-TestUtf8NoBomContent -Path $recreateScriptPath -Content $recreatePreDecisionBytes
                foreach ($fixturePath in @($paths.ManifestPath, $paths.InventoryPath)) {
                    & pwsh -NoProfile -File $recreateScriptPath -Path $fixturePath
                    if ($LASTEXITCODE -ne 0) {
                        throw "Failed to recreate the Task 8 pre-decision fixture: $fixturePath"
                    }
                }
                Remove-Item -LiteralPath $recreateScriptPath -Force
                return $paths
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
            ([datetime]$manifest.started_at_utc).ToUniversalTime().ToString('o') | Should -Be '2026-09-25T08:00:00.0000000Z'
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

        Describe 'AI Builder lifecycle contract' {
            It 'appends the lifecycle stages in the new forward order' {
                $paths = New-TestLifecycleFixture -Name 'lifecycle-forward-order'

                foreach ($stage in 'created', 'schema_defined', 'tagged', 'trained', 'evaluation_published', 'capture_validated', 'evaluated', 'approved_for_solution', 'added_to_solution') {
                    Set-HrAiBuilderModelRecord -RunManifestPath $paths.ManifestPath `
                        -ModelInventoryPath $paths.InventoryPath -ModelName 'PersonalMasterDataFixed' `
                        -ModelId 'model-fixed-001' -ModelVersion '1.0' -LifecycleStage $stage | Out-Null
                }

                $history = @(
                    @((Get-Content -LiteralPath $paths.ManifestPath -Raw | ConvertFrom-Json).models | Where-Object display_name -eq 'PersonalMasterDataFixed')[0].lifecycle_history
                )

                @($history.stage) | Should -Be @(
                    'not_created', 'created', 'schema_defined', 'tagged', 'trained',
                    'evaluation_published', 'capture_validated', 'evaluated',
                    'approved_for_solution', 'added_to_solution'
                )
            }

            It 'does not make blocked capture states generally resumable' {
                $paths = New-TestLifecycleFixture -Name 'lifecycle-capture-blocker'
                $recordArguments = @{
                    RunManifestPath = $paths.ManifestPath
                    ModelInventoryPath = $paths.InventoryPath
                    ModelName = 'PersonalMasterDataFixed'
                    ModelId = 'model-fixed-001'
                    ModelVersion = '1.0'
                }

                foreach ($stage in 'created', 'schema_defined', 'tagged', 'trained', 'evaluation_published', 'blocked') {
                    Set-HrAiBuilderModelRecord @recordArguments -LifecycleStage $stage | Out-Null
                }

                {
                    Set-HrAiBuilderModelRecord @recordArguments -LifecycleStage 'capture_validated'
                } | Should -Throw '*CaptureCapabilityEvidencePath*'
            }

            It 'rejects fabricated all-passed capability evidence with duplicate fake replay hashes' {
                $evidenceRoot = Join-Path $script:RepositoryRoot 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001'
                $fabricatedPath = Join-Path $TestDrive 'capture-capability-fabricated.json'
                $fabricated = Get-Content -LiteralPath (Join-Path $evidenceRoot 'capture-capability.json') -Raw | ConvertFrom-Json
                $fabricated.replay.first_sha256 = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
                $fabricated.replay.second_sha256 = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
                $fabricated | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $fabricatedPath -Encoding UTF8

                $paths = New-Task8CaptureDecisionFixture -Name 'lifecycle-fabricated-capability'
                $recordArguments = @{
                    RunManifestPath = $paths.ManifestPath
                    ModelInventoryPath = $paths.InventoryPath
                    ModelName = 'PersonalMasterDataFixed'
                    ModelId = '74b09a72-d1f1-4598-bc4d-3746d5c97acc'
                    ModelVersion = '1.0'
                }
                {
                    Set-HrAiBuilderModelRecord @recordArguments `
                        -LifecycleStage 'capture_validated' `
                        -CaptureCapabilityEvidencePath $fabricatedPath
                } | Should -Throw '*replay*'
                @(Get-ChildItem -LiteralPath $paths.Root -Directory -Filter '.capture-capability-replay-*' -Force).Count |
                    Should -Be 0
            }

            It 'verifies Task 8 from a relocated checkout without touching pre-existing replay files' {
                $paths = New-Task8CaptureDecisionFixture -Name 'lifecycle-relocated-checkout'
                $relocatedRoot = Join-Path $TestDrive 'relocated-repository'
                $moduleRelativePath = 'hr\src\scripts\modules\Caldova.HrFrontier.AiBuilder'
                $relocatedModuleDirectory = Join-Path $relocatedRoot $moduleRelativePath
                New-Item -ItemType Directory -Path (Split-Path -Parent $relocatedModuleDirectory) -Force | Out-Null
                Copy-Item -LiteralPath (Join-Path $script:RepositoryRoot $moduleRelativePath) `
                    -Destination $relocatedModuleDirectory -Recurse
                $evidenceRelativePath = 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001'
                $capabilityRelativePath = Join-Path $evidenceRelativePath 'capture-capability.json'
                $capability = Get-Content -LiteralPath (Join-Path $script:RepositoryRoot $capabilityRelativePath) -Raw | ConvertFrom-Json
                foreach ($relativePath in @($capability.supporting_artifacts.path) + @($capabilityRelativePath)) {
                    $destination = Join-Path $relocatedRoot $relativePath
                    New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
                    Copy-Item -LiteralPath (Join-Path $script:RepositoryRoot $relativePath) -Destination $destination
                }
                $contractsRelativePath = 'hr\src\ai-builder\contracts'
                Copy-Item -LiteralPath (Join-Path $script:RepositoryRoot $contractsRelativePath) `
                    -Destination (Split-Path -Parent (Join-Path $relocatedRoot $contractsRelativePath)) -Recurse -Force
                $sentinelDirectory = Join-Path $paths.Root '.capture-capability-replay-existing'
                New-Item -ItemType Directory -Path $sentinelDirectory | Out-Null
                $sentinelPaths = @(
                    (Join-Path $paths.Root 'fixed-capability-replay-1.json'),
                    (Join-Path $paths.Root 'fixed-capability-replay-2.json'),
                    (Join-Path $sentinelDirectory 'fixed-capability-replay-1.json')
                )
                foreach ($path in $sentinelPaths) { Set-TestUtf8NoBomContent -Path $path -Content 'untouched' }
                $relocatedCapabilityPath = Join-Path $relocatedRoot $capabilityRelativePath
                $capabilityHashBefore = (Get-FileHash -LiteralPath $relocatedCapabilityPath).Hash
                try {
                    Remove-Module Caldova.HrFrontier.AiBuilder -Force
                    Import-Module (Join-Path $relocatedModuleDirectory 'Caldova.HrFrontier.AiBuilder.psd1') -Force
                    Set-HrAiBuilderModelRecord -RunManifestPath $paths.ManifestPath -ModelInventoryPath $paths.InventoryPath `
                        -ModelName PersonalMasterDataFixed -ModelId '74b09a72-d1f1-4598-bc4d-3746d5c97acc' `
                        -ModelVersion '1.0' -LifecycleStage capture_validated -CaptureCapabilityEvidencePath $relocatedCapabilityPath |
                        Out-Null
                    (Get-Content -LiteralPath $paths.ManifestPath -Raw | ConvertFrom-Json).models[0].lifecycle_stage |
                        Should -Be 'capture_validated'
                    foreach ($path in $sentinelPaths) { (Get-Content -LiteralPath $path -Raw) | Should -Be 'untouched' }
                    @(Get-ChildItem -LiteralPath $paths.Root -Directory -Filter '.capture-capability-replay-*' -Force).Name |
                        Should -Be @('.capture-capability-replay-existing')
                    (Get-FileHash -LiteralPath $relocatedCapabilityPath).Hash | Should -Be $capabilityHashBefore
                }
                finally {
                    Remove-Module Caldova.HrFrontier.AiBuilder -Force
                    Import-Module $script:ModulePath -Force
                }
            }

            It 'isolates concurrent Task 8 replay invocations and cleans up each directory' {
                $fixtures = @(
                    (New-Task8CaptureDecisionFixture -Name 'concurrent-task8-first'),
                    (New-Task8CaptureDecisionFixture -Name 'concurrent-task8-second')
                )
                $capabilityPath = Join-Path $script:RepositoryRoot 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001\capture-capability.json'
                $startPath = Join-Path $TestDrive 'start-concurrent-task8'
                $hostExecutable = if ($PSVersionTable.PSEdition -eq 'Desktop') {
                    Join-Path $PSHOME 'powershell.exe'
                } else {
                    Join-Path $PSHOME 'pwsh.exe'
                }
                $processes = @()
                try {
                    foreach ($fixture in $fixtures) {
                        $childScript = @'
param($ModulePath, $ManifestPath, $InventoryPath, $CapabilityPath, $StartPath)
$ErrorActionPreference = 'Stop'
try {
    Import-Module $ModulePath -Force
    $deadline = [datetime]::UtcNow.AddSeconds(30)
    while (-not (Test-Path -LiteralPath $StartPath)) {
        if ([datetime]::UtcNow -gt $deadline) { throw 'Concurrent test start timed out.' }
        Start-Sleep -Milliseconds 50
    }
    Set-HrAiBuilderModelRecord -RunManifestPath $ManifestPath -ModelInventoryPath $InventoryPath `
        -ModelName PersonalMasterDataFixed -ModelId '74b09a72-d1f1-4598-bc4d-3746d5c97acc' `
        -ModelVersion '1.0' -LifecycleStage capture_validated -CaptureCapabilityEvidencePath $CapabilityPath | Out-Null
    exit 0
}
catch {
    [IO.File]::WriteAllText(($ManifestPath + '.error'), $_.Exception.ToString())
    exit 1
}
'@
                        $childScriptPath = Join-Path $fixture.Root 'concurrent-task8.ps1'
                        Set-TestUtf8NoBomContent -Path $childScriptPath -Content $childScript
                        $arguments = @(
                            $childScriptPath, ([IO.Path]::GetFullPath($script:ModulePath)),
                            $fixture.ManifestPath, $fixture.InventoryPath, $capabilityPath, $startPath
                        ) | ForEach-Object { "'" + $_.Replace("'", "''") + "'" }
                        $command = '& ' + ($arguments -join ' ')
                        $encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
                        $processes += Start-Process $hostExecutable -ArgumentList @(
                            '-NoProfile', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', $encodedCommand
                        ) -PassThru -WindowStyle Hidden
                    }
                    Set-TestUtf8NoBomContent -Path $startPath -Content 'start'
                    foreach ($process in $processes) {
                        $process.WaitForExit(60000) | Should -BeTrue
                    }
                    foreach ($fixture in $fixtures) {
                        $errorPath = $fixture.ManifestPath + '.error'
                        $failureMessage = if (Test-Path -LiteralPath $errorPath) {
                            Get-Content -LiteralPath $errorPath -Raw
                        } else { 'the replay must complete successfully' }
                        $errorPath | Should -Not -Exist -Because $failureMessage
                        (Get-Content -LiteralPath $fixture.ManifestPath -Raw | ConvertFrom-Json).models[0].lifecycle_stage |
                            Should -Be 'capture_validated'
                        @(Get-ChildItem -LiteralPath $fixture.Root -Directory -Filter '.capture-capability-replay-*' -Force).Count |
                            Should -Be 0
                    }
                }
                finally {
                    foreach ($process in $processes) {
                        if (-not $process.HasExited) { Stop-Process -Id $process.Id -Force }
                        $process.Dispose()
                    }
                }
            }

            It 'advances only the exact Task 8 blocker with verified portable capability evidence' {
                $evidenceRoot = Join-Path $script:RepositoryRoot 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001'
                $capabilityPath = Join-Path $evidenceRoot 'capture-capability.json'
                $capabilityHashBefore = (Get-FileHash -LiteralPath $capabilityPath -Algorithm SHA256).Hash
                $paths = New-Task8CaptureDecisionFixture -Name 'lifecycle-verified-capability'
                $recordArguments = @{
                    RunManifestPath = $paths.ManifestPath
                    ModelInventoryPath = $paths.InventoryPath
                    ModelName = 'PersonalMasterDataFixed'
                    ModelId = '74b09a72-d1f1-4598-bc4d-3746d5c97acc'
                    ModelVersion = '1.0'
                    LifecycleStage = 'capture_validated'
                    CaptureCapabilityEvidencePath = $capabilityPath
                }

                Set-HrAiBuilderModelRecord @recordArguments | Out-Null

                foreach ($path in @($paths.ManifestPath, $paths.InventoryPath)) {
                    $model = @(
                        @((Get-Content -LiteralPath $path -Raw | ConvertFrom-Json).models |
                            Where-Object display_name -eq 'PersonalMasterDataFixed')
                    )[0]
                    $model.lifecycle_stage | Should -Be 'capture_validated'
                    @($model.lifecycle_history.stage)[-3..-1] | Should -Be @(
                        'evaluation_published', 'blocked', 'capture_validated'
                    )
                }
                (Get-FileHash -LiteralPath $capabilityPath -Algorithm SHA256).Hash |
                    Should -Be $capabilityHashBefore
            }

            It 'rejects every wrong Task 8 identity, blocker, evidence, and gate state' {
                $evidenceRoot = Join-Path $script:RepositoryRoot 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001'
                $capabilityPath = Join-Path $evidenceRoot 'capture-capability.json'

                $wrongRunPaths = New-TestLifecycleFixture -Name 'lifecycle-wrong-task8-run' -RunId 'other-run'
                $wrongRunArguments = @{
                    RunManifestPath = $wrongRunPaths.ManifestPath
                    ModelInventoryPath = $wrongRunPaths.InventoryPath
                    ModelName = 'PersonalMasterDataFixed'
                    ModelId = '74b09a72-d1f1-4598-bc4d-3746d5c97acc'
                    ModelVersion = '1.0'
                }
                foreach ($stage in 'created', 'schema_defined', 'tagged', 'trained', 'evaluation_published', 'blocked') {
                    Set-HrAiBuilderModelRecord @wrongRunArguments -LifecycleStage $stage | Out-Null
                }
                {
                    Set-HrAiBuilderModelRecord @wrongRunArguments `
                        -LifecycleStage 'capture_validated' `
                        -CaptureCapabilityEvidencePath $capabilityPath
                } | Should -Throw '*exact blocked PersonalMasterDataFixed 1.0*'

                foreach ($identityCase in @(
                    @{ name = 'wrong-id'; id = 'wrong-model-id'; version = '1.0' },
                    @{ name = 'wrong-version'; id = '74b09a72-d1f1-4598-bc4d-3746d5c97acc'; version = '2.0' }
                )) {
                    $paths = New-Task8CaptureDecisionFixture -Name $identityCase.name
                    {
                        Set-HrAiBuilderModelRecord `
                            -RunManifestPath $paths.ManifestPath `
                            -ModelInventoryPath $paths.InventoryPath `
                            -ModelName 'PersonalMasterDataFixed' `
                            -ModelId $identityCase.id `
                            -ModelVersion $identityCase.version `
                            -LifecycleStage 'capture_validated' `
                            -CaptureCapabilityEvidencePath $capabilityPath
                    } | Should -Throw '*exact blocked PersonalMasterDataFixed 1.0*'
                }

                $missingPaths = New-Task8CaptureDecisionFixture -Name 'missing-capability'
                {
                    Set-HrAiBuilderModelRecord `
                        -RunManifestPath $missingPaths.ManifestPath `
                        -ModelInventoryPath $missingPaths.InventoryPath `
                        -ModelName 'PersonalMasterDataFixed' `
                        -ModelId '74b09a72-d1f1-4598-bc4d-3746d5c97acc' `
                        -ModelVersion '1.0' `
                        -LifecycleStage 'capture_validated' `
                        -CaptureCapabilityEvidencePath (Join-Path $TestDrive 'missing-capability.json')
                } | Should -Throw '*not found*'

                foreach ($capabilityCase in @(
                    @{ name = 'wrong-blocker'; mutate = 'blocker'; expected = '*historical_model_test_capability*' },
                    @{ name = 'failed-gate'; mutate = 'failed'; expected = '*failed, unknown*' },
                    @{ name = 'unknown-gate'; mutate = 'unknown'; expected = '*failed, unknown*' },
                    @{ name = 'containment-overclaim'; mutate = 'containment'; expected = '*containment*' }
                )) {
                    $casePath = Join-Path $TestDrive "$($capabilityCase.name)-capture-capability.json"
                    $caseCapability = Get-Content -LiteralPath $capabilityPath -Raw | ConvertFrom-Json
                    if ($capabilityCase.mutate -eq 'blocker') {
                        @($caseCapability.supporting_artifacts |
                            Where-Object id -eq 'historical_model_test_capability')[0].sha256 = (('0' * 64) -join '')
                    }
                    elseif ($capabilityCase.mutate -eq 'containment') {
                        $caseCapability.exclusions.tenant_call = $false
                        $caseCapability.holdout_exposed = $true
                    }
                    else {
                        @($caseCapability.gates | Where-Object id -eq 'AEC-G003')[0].status = $capabilityCase.mutate
                    }
                    $caseCapability | ConvertTo-Json -Depth 20 |
                        Set-Content -LiteralPath $casePath -Encoding UTF8
                    $paths = New-Task8CaptureDecisionFixture -Name $capabilityCase.name

                    {
                        Set-HrAiBuilderModelRecord `
                            -RunManifestPath $paths.ManifestPath `
                            -ModelInventoryPath $paths.InventoryPath `
                            -ModelName 'PersonalMasterDataFixed' `
                            -ModelId '74b09a72-d1f1-4598-bc4d-3746d5c97acc' `
                            -ModelVersion '1.0' `
                            -LifecycleStage 'capture_validated' `
                            -CaptureCapabilityEvidencePath $casePath
                    } | Should -Throw $capabilityCase.expected
                }
            }

            It 'resumes the blocked lifecycle only for the fixed 1.0 model and preserves the evidence bytes' {
                $paths = New-TestLifecycleFixture -Name 'lifecycle-blocked-resume' -RunId 't2-dev-20260925-001'
                $blockedCapabilityPath = Join-Path $script:RepositoryRoot 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001\model-test-capability.json'
                $originalBlockedCapabilityBytes = Get-Content -LiteralPath $blockedCapabilityPath -Raw
                $recordArguments = @{
                    RunManifestPath = $paths.ManifestPath
                    ModelInventoryPath = $paths.InventoryPath
                    ModelName = 'PersonalMasterDataFixed'
                    ModelId = '74b09a72-d1f1-4598-bc4d-3746d5c97acc'
                    ModelVersion = '1.0'
                }

                Set-HrAiBuilderModelRecord @recordArguments -LifecycleStage 'created' | Out-Null
                Set-HrAiBuilderModelRecord @recordArguments -LifecycleStage 'schema_defined' | Out-Null
                Set-HrAiBuilderModelRecord @recordArguments -LifecycleStage 'tagged' | Out-Null
                Set-HrAiBuilderModelRecord @recordArguments -LifecycleStage 'trained' | Out-Null
                Set-HrAiBuilderModelRecord @recordArguments -LifecycleStage 'blocked' | Out-Null

                Set-HrAiBuilderModelRecord @recordArguments `
                    -LifecycleStage 'evaluation_published' `
                    -ResumeBlockedEvaluation `
                    -ResumeEvidencePath $blockedCapabilityPath | Out-Null

                $history = @(
                    @((Get-Content -LiteralPath $paths.ManifestPath -Raw | ConvertFrom-Json).models | Where-Object display_name -eq 'PersonalMasterDataFixed')[0].lifecycle_history
                )

                @($history.stage) | Should -Be @(
                    'not_created', 'created', 'schema_defined', 'tagged', 'trained',
                    'blocked', 'evaluation_published'
                )
                (Get-Content -LiteralPath $blockedCapabilityPath -Raw) |
                    Should -BeExactly $originalBlockedCapabilityBytes
            }

            It 'rejects lifecycle skips and regressions across the evaluation stages' {
                $paths = New-TestLifecycleFixture -Name 'lifecycle-skip-regression'
                $recordArguments = @{
                    RunManifestPath = $paths.ManifestPath
                    ModelInventoryPath = $paths.InventoryPath
                    ModelName = 'PersonalMasterDataFixed'
                    ModelId = 'model-fixed-001'
                    ModelVersion = '1.0'
                }

                foreach ($stage in 'created', 'schema_defined', 'tagged', 'trained') {
                    Set-HrAiBuilderModelRecord @recordArguments -LifecycleStage $stage | Out-Null
                }

                {
                    Set-HrAiBuilderModelRecord @recordArguments -LifecycleStage 'capture_validated'
                } | Should -Throw '*Illegal lifecycle transition*'

                Set-HrAiBuilderModelRecord @recordArguments -LifecycleStage 'evaluation_published' | Out-Null
                {
                    Set-HrAiBuilderModelRecord @recordArguments -LifecycleStage 'evaluated'
                } | Should -Throw '*Illegal lifecycle transition*'

                Set-HrAiBuilderModelRecord @recordArguments -LifecycleStage 'capture_validated' | Out-Null
                Set-HrAiBuilderModelRecord @recordArguments -LifecycleStage 'evaluated' | Out-Null
                {
                    Set-HrAiBuilderModelRecord @recordArguments -LifecycleStage 'added_to_solution'
                } | Should -Throw '*Illegal lifecycle transition*'

                foreach ($priorStage in 'created', 'schema_defined', 'tagged', 'trained', 'evaluation_published', 'capture_validated') {
                    {
                        Set-HrAiBuilderModelRecord @recordArguments -LifecycleStage $priorStage
                    } | Should -Throw '*Illegal lifecycle transition*'
                }
            }

            It 'rejects lifecycle resumes without preserved fixed 1.0 blocked evidence' {
                $baseRecordArguments = @{
                    ModelId = '74b09a72-d1f1-4598-bc4d-3746d5c97acc'
                    ModelVersion = '1.0'
                    LifecycleStage = 'evaluation_published'
                    ResumeBlockedEvaluation = $true
                }
                $blockedCapabilityPath = Join-Path $script:RepositoryRoot 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001\model-test-capability.json'
                $tamperedBlockedCapabilityPath = Join-Path (Join-Path $TestDrive 'lifecycle-tampered') 'model-test-capability.json'
                New-Item -ItemType Directory -Path (Split-Path -Parent $tamperedBlockedCapabilityPath) -Force | Out-Null
                Copy-Item -LiteralPath $blockedCapabilityPath -Destination $tamperedBlockedCapabilityPath
                $tamperedBlockedCapability = Get-Content -LiteralPath $tamperedBlockedCapabilityPath -Raw
                ($tamperedBlockedCapability -replace '"status": "blocked"', '"status": "passed"') |
                    Set-Content -LiteralPath $tamperedBlockedCapabilityPath -Encoding UTF8

                $missingPathPaths = New-TestLifecycleFixture -Name 'lifecycle-missing-resume-path' -RunId 't2-dev-20260925-001'
                foreach ($stage in 'created', 'schema_defined', 'tagged', 'trained', 'blocked') {
                    Set-HrAiBuilderModelRecord -RunManifestPath $missingPathPaths.ManifestPath `
                        -ModelInventoryPath $missingPathPaths.InventoryPath -ModelName 'PersonalMasterDataFixed' `
                        -ModelId '74b09a72-d1f1-4598-bc4d-3746d5c97acc' -ModelVersion '1.0' -LifecycleStage $stage | Out-Null
                }
                {
                    Set-HrAiBuilderModelRecord -RunManifestPath $missingPathPaths.ManifestPath `
                        -ModelInventoryPath $missingPathPaths.InventoryPath -ModelName 'PersonalMasterDataFixed' `
                        @baseRecordArguments
                } | Should -Throw '*ResumeEvidencePath*'

                $wrongVersionPaths = New-TestLifecycleFixture -Name 'lifecycle-wrong-version' -RunId 't2-dev-20260925-001'
                foreach ($stage in 'created', 'schema_defined', 'tagged', 'trained', 'blocked') {
                    Set-HrAiBuilderModelRecord -RunManifestPath $wrongVersionPaths.ManifestPath `
                        -ModelInventoryPath $wrongVersionPaths.InventoryPath -ModelName 'PersonalMasterDataFixed' `
                        -ModelId '74b09a72-d1f1-4598-bc4d-3746d5c97acc' -ModelVersion '2.0' -LifecycleStage $stage | Out-Null
                }
                {
                    Set-HrAiBuilderModelRecord -RunManifestPath $wrongVersionPaths.ManifestPath `
                        -ModelInventoryPath $wrongVersionPaths.InventoryPath -ModelName 'PersonalMasterDataFixed' `
                        -ModelId '74b09a72-d1f1-4598-bc4d-3746d5c97acc' -ModelVersion '2.0' `
                        -LifecycleStage 'evaluation_published' -ResumeBlockedEvaluation `
                        -ResumeEvidencePath $blockedCapabilityPath
                } | Should -Throw '*PersonalMasterDataFixed*1.0*'

                $generalModelPaths = New-TestLifecycleFixture -Name 'lifecycle-general-model' -RunId 't2-dev-20260925-001' -ModelNames @('PersonalMasterDataGeneral')
                foreach ($stage in 'created', 'schema_defined', 'tagged', 'trained', 'blocked') {
                    Set-HrAiBuilderModelRecord -RunManifestPath $generalModelPaths.ManifestPath `
                        -ModelInventoryPath $generalModelPaths.InventoryPath -ModelName 'PersonalMasterDataGeneral' `
                        -ModelId 'model-general-001' -ModelVersion '1.0' -LifecycleStage $stage | Out-Null
                }
                {
                    Set-HrAiBuilderModelRecord -RunManifestPath $generalModelPaths.ManifestPath `
                        -ModelInventoryPath $generalModelPaths.InventoryPath -ModelName 'PersonalMasterDataGeneral' `
                        -ModelId 'model-general-001' -ModelVersion '1.0' `
                        -LifecycleStage 'evaluation_published' -ResumeBlockedEvaluation `
                        -ResumeEvidencePath $blockedCapabilityPath
                } | Should -Throw '*PersonalMasterDataFixed*1.0*'

                $tamperedEvidencePaths = New-TestLifecycleFixture -Name 'lifecycle-tampered-evidence' -RunId 't2-dev-20260925-001'
                foreach ($stage in 'created', 'schema_defined', 'tagged', 'trained', 'blocked') {
                    Set-HrAiBuilderModelRecord -RunManifestPath $tamperedEvidencePaths.ManifestPath `
                        -ModelInventoryPath $tamperedEvidencePaths.InventoryPath -ModelName 'PersonalMasterDataFixed' `
                        -ModelId '74b09a72-d1f1-4598-bc4d-3746d5c97acc' -ModelVersion '1.0' -LifecycleStage $stage | Out-Null
                }
                {
                    Set-HrAiBuilderModelRecord -RunManifestPath $tamperedEvidencePaths.ManifestPath `
                        -ModelInventoryPath $tamperedEvidencePaths.InventoryPath -ModelName 'PersonalMasterDataFixed' `
                        @baseRecordArguments -ResumeEvidencePath $tamperedBlockedCapabilityPath
                } | Should -Throw '*blocked*'
            }

            It 'rejects resume requests that try to overwrite the preserved 1.0 model version' {
                $paths = New-TestLifecycleFixture -Name 'lifecycle-resume-version-mismatch' -RunId 't2-dev-20260925-001'
                $blockedCapabilityPath = Join-Path $script:RepositoryRoot 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001\model-test-capability.json'
                $originalBlockedCapabilityBytes = Get-Content -LiteralPath $blockedCapabilityPath -Raw

                foreach ($stage in 'created', 'schema_defined', 'tagged', 'trained', 'blocked') {
                    Set-HrAiBuilderModelRecord -RunManifestPath $paths.ManifestPath `
                        -ModelInventoryPath $paths.InventoryPath -ModelName 'PersonalMasterDataFixed' `
                        -ModelId '74b09a72-d1f1-4598-bc4d-3746d5c97acc' -ModelVersion '1.0' -LifecycleStage $stage | Out-Null
                }

                $manifestBefore = Get-Content -LiteralPath $paths.ManifestPath -Raw
                $inventoryBefore = Get-Content -LiteralPath $paths.InventoryPath -Raw

                {
                    Set-HrAiBuilderModelRecord -RunManifestPath $paths.ManifestPath `
                        -ModelInventoryPath $paths.InventoryPath -ModelName 'PersonalMasterDataFixed' `
                        -ModelId '74b09a72-d1f1-4598-bc4d-3746d5c97acc' -ModelVersion '2.0' `
                        -LifecycleStage 'evaluation_published' -ResumeBlockedEvaluation `
                        -ResumeEvidencePath $blockedCapabilityPath
                } | Should -Throw '*ModelVersion*1.0*'

                (Get-Content -LiteralPath $blockedCapabilityPath -Raw) | Should -BeExactly $originalBlockedCapabilityBytes
                (Get-Content -LiteralPath $paths.ManifestPath -Raw) | Should -BeExactly $manifestBefore
                (Get-Content -LiteralPath $paths.InventoryPath -Raw) | Should -BeExactly $inventoryBefore
            }
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

            foreach ($stage in 'created', 'schema_defined', 'tagged', 'trained', 'evaluation_published', 'capture_validated', 'evaluated', 'approved_for_solution', 'added_to_solution') {
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
                foreach ($stage in 'created', 'schema_defined', 'tagged', 'trained', 'evaluation_published', 'capture_validated', 'evaluated', 'approved_for_solution', 'added_to_solution') {
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
                foreach ($stage in 'created', 'schema_defined', 'tagged', 'trained', 'evaluation_published', 'capture_validated', 'evaluated', 'approved_for_solution', 'added_to_solution') {
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
                Set-TestUtf8BomContent -Path $reviewPath -Content ($review | ConvertTo-Json -Depth 8)
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
            ([datetime](Get-Content -LiteralPath (Join-Path $outputDirectory 'run-manifest.json') -Raw | ConvertFrom-Json).started_at_utc).ToUniversalTime().ToString('o') |
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
            $fixedPackagePath = Join-Path $script:RepositoryRoot 'hr\docs\ideas\uc-0001-personal-master-data-completion-agent\caldova-aib-fixed-template'
            $generalPackagePath = Join-Path $script:RepositoryRoot 'hr\docs\ideas\uc-0001-personal-master-data-completion-agent\caldova-aib-general-documents'
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

            $previousErrorActionPreference = $ErrorActionPreference
            try {
                # Windows PowerShell turns redirected native stderr into errors; capture the expected rejection.
                $ErrorActionPreference = 'Continue'
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
            }
            finally {
                $ErrorActionPreference = $previousErrorActionPreference
            }

            $exitCode | Should -Not -Be 0
            ($output -join [Environment]::NewLine) | Should -Match 'already exists'
            (Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json).started_at_utc | Should -Be $originalStartedAt
            @((Get-Content -LiteralPath $inventoryPath -Raw | ConvertFrom-Json).models | Where-Object display_name -eq 'PersonalMasterDataFixed')[0].lifecycle_stage |
                Should -Be 'created'
        }
    }

    It 'contains 24 fixed PDFs and matching ground-truth rows' {
        $root = Join-Path $script:UseCaseRoot 'caldova-aib-fixed-template'
        $truth = Get-Content -LiteralPath (Join-Path $root 'ground-truth.json') -Raw | ConvertFrom-Json
        $pdfs = @(Get-ChildItem -LiteralPath (Join-Path $root 'documents') -Filter '*.pdf' -Recurse)

        $pdfs.Count | Should -Be 24
        @($truth.documents).Count | Should -Be 24
        @($truth.documents.document | Sort-Object) |
            Should -Be @($pdfs.Name | Sort-Object)
    }

    It 'contains 24 general PDFs and matching ground-truth rows' {
        $root = Join-Path $script:UseCaseRoot 'caldova-aib-general-documents'
        $truth = Get-Content -LiteralPath (Join-Path $root 'ground-truth.json') -Raw | ConvertFrom-Json
        $pdfs = @(Get-ChildItem -LiteralPath (Join-Path $root 'documents') -Filter '*.pdf' -Recurse)

        $pdfs.Count | Should -Be 24
        @($truth.documents).Count | Should -Be 24
        @($truth.documents.document | Sort-Object) |
            Should -Be @($pdfs.Name | Sort-Object)
    }

    It 'keeps CSV and JSON ground truth equivalent for both supplied packages' {
        foreach ($package in @('caldova-aib-fixed-template', 'caldova-aib-general-documents')) {
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
        foreach ($package in @('caldova-aib-fixed-template', 'caldova-aib-general-documents')) {
            $generatorRoot = Join-Path (Join-Path $script:UseCaseRoot $package) 'generators'
            @(
                Get-ChildItem -LiteralPath $generatorRoot -File -Filter '*.py' |
                    Select-Object -ExpandProperty Name |
                    Sort-Object
            ) | Should -Be @($expected | Sort-Object)
        }
    }

    Describe 'AI Builder evaluation capture schema contracts' {
        BeforeAll {
            $script:PredictionCaptureSchemaPath = Join-Path $script:RepositoryRoot 'hr\src\ai-builder\contracts\prediction-capture.schema.json'
            $script:EvaluationCapturePairSchemaPath = Join-Path $script:RepositoryRoot 'hr\src\ai-builder\contracts\evaluation-capture-pair.schema.json'
            $script:ExpectedCanonicalEnvelopePropertyOrder = @(
                'schema_version',
                'run_id',
                'corpus_revision',
                'filename',
                'claimed_sha256',
                'model_name',
                'model_version',
                'captured_at_utc',
                'fields'
            )

            function Test-JsonSchemaDocument {
                param(
                    [Parameter(Mandatory)]
                    [string]$SchemaPath,

                    [Parameter(Mandatory)]
                    [string]$DocumentPath
                )

                $validatorScriptPath = Join-Path $TestDrive 'json-schema-validator.py'
                if (-not (Test-Path -LiteralPath $validatorScriptPath -PathType Leaf)) {
                    @'
import json
import sys
from jsonschema import Draft202012Validator

with open(sys.argv[1], 'r', encoding='utf-8') as schema_file:
    schema = json.load(schema_file)

with open(sys.argv[2], 'r', encoding='utf-8') as document_file:
    document = json.load(document_file)

validator = Draft202012Validator(schema)
errors = sorted(validator.iter_errors(document), key=lambda error: list(error.path))
if errors:
    for error in errors:
        path = '.'.join(str(segment) for segment in error.path)
        print("{}: {}".format(path, error.message) if path else error.message)
    sys.exit(1)
'@ | Set-Content -LiteralPath $validatorScriptPath -Encoding UTF8
                }

                $pythonOutput = & python $validatorScriptPath $SchemaPath $DocumentPath 2>&1
                $pythonExitCode = $LASTEXITCODE

                [pscustomobject]@{
                    Passed = ($pythonExitCode -eq 0)
                    Output = @($pythonOutput) -join [Environment]::NewLine
                }
            }
        }

        It 'defines the canonical envelope property order and 17 contract fields' {
            $script:EvaluationCapturePairSchemaPath | Should -Exist
            $pairSchema = Get-Content -LiteralPath $script:EvaluationCapturePairSchemaPath -Raw | ConvertFrom-Json
            $canonicalEnvelope = $pairSchema.'$defs'.canonical_envelope

            @($canonicalEnvelope.properties.psobject.Properties.Name) |
                Should -Be $script:ExpectedCanonicalEnvelopePropertyOrder
            @($canonicalEnvelope.required) | Should -Be $script:ExpectedCanonicalEnvelopePropertyOrder
            @($canonicalEnvelope.properties.fields.properties.psobject.Properties.Name) |
                Should -Be @($script:ExpectedFieldDefinitions.name)
            @($canonicalEnvelope.properties.fields.required) |
                Should -Be @($script:ExpectedFieldDefinitions.name)
            $canonicalEnvelope.additionalProperties | Should -BeFalse
            @($pairSchema.'$defs'.canonical_field.properties.psobject.Properties.Name) |
                Should -Be @('value', 'confidence')
            @($pairSchema.'$defs'.canonical_field.required) |
                Should -Be @('value', 'confidence')
            $pairSchema.'$defs'.canonical_field.additionalProperties | Should -BeFalse

            foreach ($fieldName in $script:ExpectedFieldDefinitions.name) {
                $canonicalEnvelope.properties.fields.properties.$fieldName.'$ref' |
                    Should -Be '#/$defs/canonical_field'
            }
        }

        It 'requires lowercase sha256 values for every captured artifact record and disallows duplicate paths' {
            $pairSchema = Get-Content -LiteralPath $script:EvaluationCapturePairSchemaPath -Raw | ConvertFrom-Json
            $artifacts = $pairSchema.properties.artifacts.properties

            foreach ($artifactName in 'source_pdf', 'raw_response', 'canonical_envelope') {
                $artifactSchema = $artifacts.$artifactName
                @($artifactSchema.properties.psobject.Properties.Name) | Should -Be @('path', 'sha256')
                @($artifactSchema.required) | Should -Be @('path', 'sha256')
                $artifactSchema.properties.sha256.pattern | Should -Be '^[a-f0-9]{64}$'
                $artifactSchema.additionalProperties | Should -BeFalse
            }

            $pairSchema.allOf | Should -Not -BeNullOrEmpty
            ($pairSchema | ConvertTo-Json -Depth 20) | Should -Match '(?s)source_pdf.+raw_response'
            ($pairSchema | ConvertTo-Json -Depth 20) | Should -Match '(?s)raw_response.+canonical_envelope'
        }

        It 'pins production prediction captures to the Process documents adapter contract' {
            $script:PredictionCaptureSchemaPath | Should -Exist
            $predictionSchema = Get-Content -LiteralPath $script:PredictionCaptureSchemaPath -Raw | ConvertFrom-Json

            $predictionSchema.properties.capture_mechanism.const | Should -Be 'Power Automate Process documents'
            $predictionSchema.properties.adapter_contract.const | Should -Be 'replayable-v2'
            $predictionSchema.properties.raw_export_format.const | Should -Be 'ai-builder-process-documents-v1'
        }

        It 'does not allow the retired Quick Test constants in the production prediction contract' {
            $predictionSchemaText = Get-Content -LiteralPath $script:PredictionCaptureSchemaPath -Raw

            $predictionSchemaText | Should -Not -Match 'AI Builder Quick Test'
            $predictionSchemaText | Should -Not -Match 'replayable-v1'
            $predictionSchemaText | Should -Not -Match 'test-fixture-json-v1'
        }

        It 'accepts a complete valid capture-pair record and rejects an extra top-level property' {
            $validRecordPath = Join-Path $TestDrive 'evaluation-capture-valid.json'
            $extraPropertyRecordPath = Join-Path $TestDrive 'evaluation-capture-extra.json'
            $fields = [ordered]@{}
            foreach ($fieldDefinition in $script:ExpectedFieldDefinitions) {
                $fields[$fieldDefinition.name] = [ordered]@{
                    value = $null
                    confidence = $null
                }
            }

            $validRecord = [ordered]@{
                schema_version = '1.0'
                run_id = 'cap-20260929100000000Z-7f3a9c2d'
                corpus_revision = 'c0310c527f010cc9a24d7a78dae7db1e5ad136116b14306413162fb4223926db'
                filename = 'a01-CAND-2026-0411-brunner.pdf'
                claimed_sha256 = '9c7ebe8d706b5b6ee98d779bcd83a578f8dff44b9b6bd7d02bff2b64e2ba67bd'
                model_name = 'PersonalMasterDataFixed'
                model_version = '1.0'
                captured_at_utc = '2026-09-29T10:00:00.000Z'
                fields = $fields
                artifacts = [ordered]@{
                    source_pdf = [ordered]@{
                        path = 'source/a01-CAND-2026-0411-brunner.pdf'
                        sha256 = '9c7ebe8d706b5b6ee98d779bcd83a578f8dff44b9b6bd7d02bff2b64e2ba67bd'
                    }
                    raw_response = [ordered]@{
                        path = 'cap-20260929100000000Z-7f3a9c2d.ai-builder.raw.json'
                        sha256 = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
                    }
                    canonical_envelope = [ordered]@{
                        path = 'cap-20260929100000000Z-7f3a9c2d.canonical.json'
                        sha256 = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
                    }
                }
            }

            Set-TestUtf8NoBomContent -Path $validRecordPath -Content ($validRecord | ConvertTo-Json -Depth 20)
            $validResult = Test-JsonSchemaDocument -SchemaPath $script:EvaluationCapturePairSchemaPath -DocumentPath $validRecordPath
            $validResult.Passed | Should -BeTrue -Because $validResult.Output

            $invalidRecord = [ordered]@{} + $validRecord
            $invalidRecord.unexpected = 'forbidden'
            Set-TestUtf8NoBomContent -Path $extraPropertyRecordPath -Content ($invalidRecord | ConvertTo-Json -Depth 20)

            $invalidResult = Test-JsonSchemaDocument -SchemaPath $script:EvaluationCapturePairSchemaPath -DocumentPath $extraPropertyRecordPath
            $invalidResult.Passed | Should -BeFalse
            $invalidResult.Output | Should -Match 'unexpected'
        }
    }

    Describe 'AI Builder normalization and evaluation' {
        BeforeAll {
            $script:ModulePath = Join-Path $PSScriptRoot '..\..\src\scripts\modules\Caldova.HrFrontier.AiBuilder\Caldova.HrFrontier.AiBuilder.psd1'
            Import-Module $script:ModulePath -Force

            function New-TestAiBuilderGateSource {
                param(
                    [switch]$PortableLocators
                )

                $contract = Get-Content -LiteralPath $script:ContractPath -Raw | ConvertFrom-Json
                $fixtureRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString())
                New-Item -ItemType Directory -Path $fixtureRoot -Force | Out-Null
                $packageRoot = if ($PortableLocators) {
                    Join-Path $fixtureRoot 'package'
                }
                else {
                    $fixtureRoot
                }
                $evidenceContextPath = if ($PortableLocators) {
                    Join-Path $fixtureRoot 'evidence'
                }
                else {
                    $fixtureRoot
                }
                New-Item -ItemType Directory -Path $packageRoot, $evidenceContextPath -Force | Out-Null
                $documentsRoot = if ($PortableLocators) {
                    Join-Path $packageRoot 'documents'
                }
                else {
                    $packageRoot
                }
                New-Item -ItemType Directory -Path $documentsRoot -Force | Out-Null
                $inputPdfPath = Join-Path $documentsRoot 'held.pdf'
                $rawExportPath = Join-Path $fixtureRoot 'held.json'
                $schemaEvidencePath = Join-Path $evidenceContextPath 'model-schema-fixed.png'
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

                $source = @{
                    CorpusQualification = [pscustomobject]@{
                        status = 'passed'
                        documents = @([pscustomobject]@{
                            document = 'held.pdf'
                            assignment = 'held-out'
                            sha256 = (Get-FileHash -LiteralPath $inputPdfPath -Algorithm SHA256).Hash.ToLowerInvariant()
                            collection_or_family = 'a-personalblatt'
                            source_path = if ($PortableLocators) { 'documents\held.pdf' } else { $inputPdfPath }
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
                        source_evidence_path = if ($PortableLocators) { 'model-schema-fixed.png' } else { $schemaEvidencePath }
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
                                source_path = if ($PortableLocators) { 'documents\held.pdf' } else { $inputPdfPath }
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

                if ($PortableLocators) {
                    $source['PackageRootPath'] = $packageRoot
                    $source['EvidenceContextPath'] = $evidenceContextPath
                }

                return $source
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
            [IO.Path]::IsPathRooted([string]$record.source_evidence_path) | Should -BeFalse
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

        It 're-evaluates portable held-out and schema evidence locators after moving the root' {
            $source = New-TestAiBuilderGateSource -PortableLocators
            $movedRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString())
            Copy-Item -LiteralPath $source.PackageRootPath -Destination (Join-Path $movedRoot 'package') -Recurse -Force
            Copy-Item -LiteralPath $source.EvidenceContextPath -Destination (Join-Path $movedRoot 'evidence') -Recurse -Force
            Remove-Item -LiteralPath $source.PackageRootPath -Recurse -Force
            Remove-Item -LiteralPath $source.EvidenceContextPath -Recurse -Force
            $source.PackageRootPath = Join-Path $movedRoot 'package'
            $source.EvidenceContextPath = Join-Path $movedRoot 'evidence'

            $gate = Test-HrAiBuilderStrictGates @source

            $gate.status | Should -Be 'evaluated'
        }

        It 'blocks traversal locators for held-out and schema evidence' {
            $source = New-TestAiBuilderGateSource -PortableLocators
            $outsideDocumentPath = Join-Path $TestDrive 'outside-held.pdf'
            $outsideSchemaPath = Join-Path $TestDrive 'outside-schema.png'
            'outside document bytes' | Set-Content -LiteralPath $outsideDocumentPath -Encoding UTF8
            'outside schema bytes' | Set-Content -LiteralPath $outsideSchemaPath -Encoding UTF8
            $source.RunManifest.models[0].documents[0].source_path = '..\outside-held.pdf'
            $source.ModelSchemaRecord.source_evidence_path = '..\outside-schema.png'

            $gate = Test-HrAiBuilderStrictGates @source

            $gate.failed_gates | Should -Contain 'held_out_input_provenance'
            $gate.failed_gates | Should -Contain 'schema_source_provenance'
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
                Set-TestUtf8BomContent -Path $reviewPath -Content ($review | ConvertTo-Json -Depth 8)

                return Test-HrAiBuilderCorpus -PackagePath $PackagePath -ModelKind $ModelKind `
                    -ReviewPath $reviewPath -FieldContractPath $script:FieldContractPath
            }

            $fixedPackagePath = Join-Path $script:RepositoryRoot 'hr\docs\ideas\uc-0001-personal-master-data-completion-agent\caldova-aib-fixed-template'
            $generalPackagePath = Join-Path $script:RepositoryRoot 'hr\docs\ideas\uc-0001-personal-master-data-completion-agent\caldova-aib-general-documents'
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
                    Join-Path $script:RepositoryRoot 'hr\docs\ideas\uc-0001-personal-master-data-completion-agent\caldova-aib-fixed-template'
                }
                else {
                    Join-Path $script:RepositoryRoot 'hr\docs\ideas\uc-0001-personal-master-data-completion-agent\caldova-aib-general-documents'
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

        It 'preserves ISO date values as strings when PowerShell 7 imports a prediction capture' {
            $fixture = New-TestAiBuilderEvaluationFixture -ModelName 'PersonalMasterDataFixed'
            $rawExportPath = @(
                Get-ChildItem -LiteralPath $fixture.RawExportDirectory -Filter '*.json' |
                    Sort-Object Name
            )[0].FullName
            $rawExport = Get-Content -LiteralPath $rawExportPath -Raw | ConvertFrom-Json
            $rawExport.fields.dob.value = '1989-03-10T00:00:00Z'
            $rawExport.fields.dob.confidence = 0.99
            $rawExport | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $rawExportPath -Encoding UTF8

            $output = & pwsh -NoProfile -File $script:ImportQuickTestResultsPath `
                -RunManifestPath $fixture.RunManifestPath `
                -ModelSchemaRecordPath $fixture.ModelSchemaRecordPath `
                -RawExportDirectory $fixture.RawExportDirectory `
                -AdapterScriptPath $fixture.AdapterPath `
                -TargetModelName $fixture.ModelName `
                -OutputPath $fixture.PredictionCapturePath 2>&1
            $exitCode = $LASTEXITCODE

            $exitCode | Should -Be 0 -Because ($output -join [Environment]::NewLine)
            $captureText = Get-Content -LiteralPath $fixture.PredictionCapturePath -Raw
            $captureText | Should -Match '"value":\s*"1989-03-10T00:00:00Z"'
        }

        It 'replays nested fixed-holdout captures from their supplied root' {
            $evidenceRoot = Join-Path $script:RepositoryRoot 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001'
            $root = Join-Path $TestDrive ([guid]::NewGuid().ToString())
            New-Item -ItemType Directory -Path $root -Force | Out-Null
            $outputPath = Join-Path $root 'prediction-capture-fixed.json'

            $output = & pwsh -NoProfile -File $script:ImportQuickTestResultsPath `
                -RunManifestPath (Join-Path $evidenceRoot 'run-manifest.json') `
                -ModelSchemaRecordPath (Join-Path $evidenceRoot 'model-schema-fixed.json') `
                -RawExportDirectory (Join-Path $evidenceRoot 'capture\fixed-holdout') `
                -AdapterScriptPath (Join-Path $script:RepositoryRoot 'hr\src\scripts\adapters\ConvertFrom-HrAiBuilderEvaluationCapture.ps1') `
                -TargetModelName 'PersonalMasterDataFixed' `
                -OutputPath $outputPath 2>&1
            $exitCode = $LASTEXITCODE

            $exitCode | Should -Be 0 -Because ($output -join [Environment]::NewLine)
            $capture = Get-Content -LiteralPath $outputPath -Raw | ConvertFrom-Json
            @($capture.documents).Count | Should -Be 4
            @(
                $capture.documents |
                    ForEach-Object { Split-Path -Parent ([string]$_.source_export_path) } |
                    Sort-Object -Unique
            ).Count | Should -Be 4
        }

        It 'evaluates replayed nested fixed-holdout captures from their common ancestor' {
            $evidenceRoot = Join-Path $script:RepositoryRoot 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001'
            $root = Join-Path $TestDrive ([guid]::NewGuid().ToString())
            New-Item -ItemType Directory -Path $root -Force | Out-Null
            $predictionCapturePath = Join-Path $root 'prediction-capture-fixed.json'
            $evaluationDirectory = Join-Path $root 'evaluation'
            $historicalPackageRoot = Join-Path $root 'historical-fixed-package'
            $historicalGroundTruthPath = Join-Path $historicalPackageRoot 'ground-truth.json'
            New-Item -ItemType Directory -Path $historicalPackageRoot -Force | Out-Null
            Copy-Item -LiteralPath (
                Join-Path $script:RepositoryRoot 'hr\docs\ideas\uc-0001-personal-master-data-completion-agent\caldova-aib-fixed-template\ground-truth.json'
            ) -Destination $historicalGroundTruthPath
            $manifest = Get-Content -LiteralPath (Join-Path $evidenceRoot 'run-manifest.json') -Raw |
                ConvertFrom-Json
            $heldOutDocuments = @(
                @($manifest.models | Where-Object display_name -ceq 'PersonalMasterDataFixed')[0].documents |
                    Where-Object assignment -ceq 'held-out'
            )
            foreach ($document in $heldOutDocuments) {
                $captureSource = @(
                    Get-ChildItem -LiteralPath (Join-Path $evidenceRoot 'capture\fixed-holdout') `
                        -Recurse -Filter ([string]$document.document) -File
                )
                $captureSource.Count | Should -Be 1
                $historicalSourcePath = Join-Path $historicalPackageRoot ([string]$document.source_path)
                New-Item -ItemType Directory -Path (Split-Path -Parent $historicalSourcePath) -Force |
                    Out-Null
                Copy-Item -LiteralPath $captureSource[0].FullName -Destination $historicalSourcePath
            }

            & pwsh -NoProfile -File $script:ImportQuickTestResultsPath `
                -RunManifestPath (Join-Path $evidenceRoot 'run-manifest.json') `
                -ModelSchemaRecordPath (Join-Path $evidenceRoot 'model-schema-fixed.json') `
                -RawExportDirectory (Join-Path $evidenceRoot 'capture\fixed-holdout') `
                -AdapterScriptPath (Join-Path $script:RepositoryRoot 'hr\src\scripts\adapters\ConvertFrom-HrAiBuilderEvaluationCapture.ps1') `
                -TargetModelName 'PersonalMasterDataFixed' `
                -OutputPath $predictionCapturePath | Out-Null
            $LASTEXITCODE | Should -Be 0

            $output = & pwsh -NoProfile -File $script:MeasureEvaluationPath `
                -RunManifestPath (Join-Path $evidenceRoot 'run-manifest.json') `
                -CorpusQualityPath (Join-Path $evidenceRoot 'corpus-quality.json') `
                -FieldContractPath $script:FieldContractPath `
                -ModelSchemaRecordPath (Join-Path $evidenceRoot 'model-schema-fixed.json') `
                -PredictionCapturePath $predictionCapturePath `
                -GroundTruthPath $historicalGroundTruthPath `
                -EvidenceDirectory $evaluationDirectory 2>&1
            $exitCode = $LASTEXITCODE

            $exitCode | Should -Be 0 -Because ($output -join [Environment]::NewLine)
            $metrics = Get-Content -LiteralPath (Join-Path $evaluationDirectory 'evaluation-metrics.json') -Raw |
                ConvertFrom-Json
            @($metrics.models[0].failed_gates) | Should -Not -Contain 'adapter_replay'
        }

        It 'preserves ISO date values as strings when PowerShell 7 evaluates a prediction capture' {
            $fixture = New-TestAiBuilderEvaluationFixture -ModelName 'PersonalMasterDataFixed'
            $rawExportPath = @(
                Get-ChildItem -LiteralPath $fixture.RawExportDirectory -Filter '*.json' |
                    Sort-Object Name
            )[0].FullName
            $rawExport = Get-Content -LiteralPath $rawExportPath -Raw | ConvertFrom-Json
            $rawExport.fields.dob.value = '1989-03-10T00:00:00Z'
            $rawExport.fields.dob.confidence = 0.99
            $rawExport | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $rawExportPath -Encoding UTF8

            & pwsh -NoProfile -File $script:ImportQuickTestResultsPath `
                -RunManifestPath $fixture.RunManifestPath `
                -ModelSchemaRecordPath $fixture.ModelSchemaRecordPath `
                -RawExportDirectory $fixture.RawExportDirectory `
                -AdapterScriptPath $fixture.AdapterPath `
                -TargetModelName $fixture.ModelName `
                -OutputPath $fixture.PredictionCapturePath | Out-Null
            $LASTEXITCODE | Should -Be 0

            $output = & pwsh -NoProfile -File $script:MeasureEvaluationPath `
                -RunManifestPath $fixture.RunManifestPath `
                -CorpusQualityPath $fixture.CorpusQualityPath `
                -FieldContractPath $script:FieldContractPath `
                -ModelSchemaRecordPath $fixture.ModelSchemaRecordPath `
                -PredictionCapturePath $fixture.PredictionCapturePath `
                -GroundTruthPath $fixture.GroundTruthPath `
                -EvidenceDirectory $fixture.EvidenceRoot 2>&1
            $exitCode = $LASTEXITCODE

            $exitCode | Should -Be 0 -Because ($output -join [Environment]::NewLine)
            $metrics = Get-Content -LiteralPath (Join-Path $fixture.EvidenceRoot 'evaluation-metrics.json') -Raw |
                ConvertFrom-Json
            @($metrics.models[0].failed_gates) | Should -Not -Contain 'prediction_capture_schema'
        }

        It 'evaluates an imported capture when the adapter metadata is normalized by the importer' {
            $fixture = New-TestAiBuilderEvaluationFixture -ModelName 'PersonalMasterDataFixed'
            $adapterScript = Get-Content -LiteralPath $fixture.AdapterPath -Raw
            $adapterScript = $adapterScript -replace 'adapter_script_path = \$PSCommandPath', "adapter_script_path = 'adapter-placeholder.ps1'"
            $adapterScript = $adapterScript -replace 'adapter_script_sha256 = \(Get-FileHash -LiteralPath \$PSCommandPath -Algorithm SHA256\)\.Hash\.ToLowerInvariant\(\)', "adapter_script_sha256 = ('f' * 64)"
            Set-Content -LiteralPath $fixture.AdapterPath -Value $adapterScript -Encoding UTF8

            $importOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:ImportQuickTestResultsPath `
                -RunManifestPath $fixture.RunManifestPath `
                -ModelSchemaRecordPath $fixture.ModelSchemaRecordPath `
                -RawExportDirectory $fixture.RawExportDirectory `
                -AdapterScriptPath $fixture.AdapterPath `
                -TargetModelName $fixture.ModelName `
                -OutputPath $fixture.PredictionCapturePath 2>&1
            $importExitCode = $LASTEXITCODE

            $importExitCode | Should -Be 0

            $evaluationOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:MeasureEvaluationPath `
                -RunManifestPath $fixture.RunManifestPath `
                -CorpusQualityPath $fixture.CorpusQualityPath `
                -FieldContractPath $script:FieldContractPath `
                -ModelSchemaRecordPath $fixture.ModelSchemaRecordPath `
                -PredictionCapturePath $fixture.PredictionCapturePath `
                -GroundTruthPath $fixture.GroundTruthPath `
                -EvidenceDirectory $fixture.EvidenceRoot 2>&1
            $evaluationExitCode = $LASTEXITCODE

            $evaluationExitCode | Should -Be 0
            ($evaluationOutput -join [Environment]::NewLine) | Should -Not -Match 'adapter_replay'
        }

        It 'rejects a capture document not present in the held-out allocation' {
            $fixture = New-TestAiBuilderEvaluationFixture -ModelName 'PersonalMasterDataFixed' -UseUnexpectedDocument

            $previousErrorActionPreference = $ErrorActionPreference
            try {
                # Capture expected native stderr without inheriting the caller's Stop preference.
                $ErrorActionPreference = 'Continue'
                $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:ImportQuickTestResultsPath `
                    -RunManifestPath $fixture.RunManifestPath `
                    -ModelSchemaRecordPath $fixture.ModelSchemaRecordPath `
                    -RawExportDirectory $fixture.RawExportDirectory `
                    -AdapterScriptPath $fixture.AdapterPath `
                    -TargetModelName $fixture.ModelName `
                    -OutputPath $fixture.PredictionCapturePath 2>&1
                $exitCode = $LASTEXITCODE
            }
            finally {
                $ErrorActionPreference = $previousErrorActionPreference
            }

            $exitCode | Should -Not -Be 0
            ($output -join [Environment]::NewLine) | Should -Match 'held-out allocation'
        }

        It 'rejects duplicate capture documents before promotion' {
            $fixture = New-TestAiBuilderEvaluationFixture -ModelName 'PersonalMasterDataFixed'
            Write-TestAiBuilderPredictionCapture -Fixture $fixture | Out-Null
            $capture = Get-Content -LiteralPath $fixture.PredictionCapturePath -Raw | ConvertFrom-Json
            $capture.documents[-1] = $capture.documents[0]
            $capture | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $fixture.PredictionCapturePath -Encoding UTF8

            $previousErrorActionPreference = $ErrorActionPreference
            try {
                $ErrorActionPreference = 'Continue'
                $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:MeasureEvaluationPath `
                    -RunManifestPath $fixture.RunManifestPath `
                    -CorpusQualityPath $fixture.CorpusQualityPath `
                    -FieldContractPath $script:FieldContractPath `
                    -ModelSchemaRecordPath $fixture.ModelSchemaRecordPath `
                    -PredictionCapturePath $fixture.PredictionCapturePath `
                    -GroundTruthPath $fixture.GroundTruthPath `
                    -EvidenceDirectory $fixture.EvidenceRoot 2>&1
                $exitCode = $LASTEXITCODE
            }
            finally {
                $ErrorActionPreference = $previousErrorActionPreference
            }

            $exitCode | Should -Not -Be 0
            ($output -join [Environment]::NewLine) | Should -Match 'held_out_document_coverage'
        }

        It 'writes a blocked import summary when the raw export directory is missing' {
            $fixture = New-TestAiBuilderEvaluationFixture -ModelName 'PersonalMasterDataFixed'
            Remove-Item -LiteralPath $fixture.RawExportDirectory -Recurse -Force
            $summaryPath = Join-Path $fixture.InputRoot 'prediction-capture-summary.md'

            $previousErrorActionPreference = $ErrorActionPreference
            try {
                $ErrorActionPreference = 'Continue'
                $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:ImportQuickTestResultsPath `
                    -RunManifestPath $fixture.RunManifestPath `
                    -ModelSchemaRecordPath $fixture.ModelSchemaRecordPath `
                    -RawExportDirectory $fixture.RawExportDirectory `
                    -AdapterScriptPath $fixture.AdapterPath `
                    -TargetModelName $fixture.ModelName `
                    -OutputPath $fixture.PredictionCapturePath 2>&1
                $exitCode = $LASTEXITCODE
            }
            finally {
                $ErrorActionPreference = $previousErrorActionPreference
            }

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

            $previousErrorActionPreference = $ErrorActionPreference
            try {
                $ErrorActionPreference = 'Continue'
                $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:ImportQuickTestResultsPath `
                    -RunManifestPath $fixture.RunManifestPath `
                    -ModelSchemaRecordPath $fixture.ModelSchemaRecordPath `
                    -RawExportDirectory $fixture.RawExportDirectory `
                    -AdapterScriptPath $fixture.AdapterPath `
                    -TargetModelName $fixture.ModelName `
                    -OutputPath $fixture.PredictionCapturePath 2>&1
                $exitCode = $LASTEXITCODE
            }
            finally {
                $ErrorActionPreference = $previousErrorActionPreference
            }

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

            $previousErrorActionPreference = $ErrorActionPreference
            try {
                $ErrorActionPreference = 'Continue'
                $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:MeasureEvaluationPath `
                    -RunManifestPath $fixture.RunManifestPath `
                    -CorpusQualityPath $fixture.CorpusQualityPath `
                    -FieldContractPath $script:FieldContractPath `
                    -ModelSchemaRecordPath $fixture.ModelSchemaRecordPath `
                    -PredictionCapturePath $fixture.PredictionCapturePath `
                    -GroundTruthPath $fixture.GroundTruthPath `
                    -EvidenceDirectory $evidenceDirectory 2>&1
                $exitCode = $LASTEXITCODE
            }
            finally {
                $ErrorActionPreference = $previousErrorActionPreference
            }

            $exitCode | Should -Not -Be 0
            ($output | Out-String -Width 4096) | Should -Match 'already\s+exists'
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

            $previousErrorActionPreference = $ErrorActionPreference
            try {
                $ErrorActionPreference = 'Continue'
                $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:MeasureEvaluationPath `
                    -RunManifestPath $fixture.RunManifestPath `
                    -CorpusQualityPath $fixture.CorpusQualityPath `
                    -FieldContractPath $script:FieldContractPath `
                    -ModelSchemaRecordPath $fixture.ModelSchemaRecordPath `
                    -PredictionCapturePath $fixture.PredictionCapturePath `
                    -GroundTruthPath $fixture.GroundTruthPath `
                    -EvidenceDirectory $fixture.EvidenceRoot 2>&1
                $exitCode = $LASTEXITCODE
            }
            finally {
                $ErrorActionPreference = $previousErrorActionPreference
            }

            $exitCode | Should -Not -Be 0
            (Join-Path $fixture.EvidenceRoot 'evaluation-summary.md') | Should -Exist
            $summary = Get-Content -LiteralPath (Join-Path $fixture.EvidenceRoot 'evaluation-summary.md') -Raw
            $summary | Should -Match 'Blocked'
            $summary | Should -Match 'prediction_capture_schema'
        }

        It 'preserves a blocked capture and writes a blocked import summary when adapter output is invalid' {
            $fixture = New-TestAiBuilderEvaluationFixture -ModelName 'PersonalMasterDataFixed' -MissingConfidence
            $summaryPath = Join-Path $fixture.InputRoot 'prediction-capture-summary.md'

            $previousErrorActionPreference = $ErrorActionPreference
            try {
                $ErrorActionPreference = 'Continue'
                $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:ImportQuickTestResultsPath `
                    -RunManifestPath $fixture.RunManifestPath `
                    -ModelSchemaRecordPath $fixture.ModelSchemaRecordPath `
                    -RawExportDirectory $fixture.RawExportDirectory `
                    -AdapterScriptPath $fixture.AdapterPath `
                    -TargetModelName $fixture.ModelName `
                    -OutputPath $fixture.PredictionCapturePath 2>&1
                $exitCode = $LASTEXITCODE
            }
            finally {
                $ErrorActionPreference = $previousErrorActionPreference
            }

            $blockedCapturePath = $fixture.PredictionCapturePath + '.blocked.json'
            $exitCode | Should -Not -Be 0
            $blockedCapturePath | Should -Exist
            $summaryPath | Should -Exist
            (Get-Content -LiteralPath $summaryPath -Raw) | Should -Match ([regex]::Escape($blockedCapturePath))
            ($output | Out-String -Width 4096) | Should -Match 'violates\s+the capture contract'
        }
    }
}
