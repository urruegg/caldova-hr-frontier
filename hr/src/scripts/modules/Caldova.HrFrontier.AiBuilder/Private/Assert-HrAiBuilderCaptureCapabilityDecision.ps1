function Assert-HrAiBuilderCaptureCapabilityDecision {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RunManifestPath,
        [Parameter(Mandatory)][string]$ModelInventoryPath,
        [Parameter(Mandatory)][string]$ModelName,
        [Parameter(Mandatory)][string]$ModelId,
        [Parameter(Mandatory)][string]$ModelVersion,
        [Parameter(Mandatory)][string]$CaptureCapabilityEvidencePath
    )

    function Read-CaptureDecisionJson {
        param(
            [Parameter(Mandatory)][string]$Path,
            [Parameter(Mandatory)][string]$Description
        )

        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
            throw "$Description file '$Path' was not found."
        }
        $text = [IO.File]::ReadAllText(
            [IO.Path]::GetFullPath($Path),
            [Text.UTF8Encoding]::new($false, $true)
        )
        try {
            $convertFromJson = Get-Command ConvertFrom-Json -ErrorAction Stop
            if ($convertFromJson.Parameters.ContainsKey('DateKind')) {
                return $text | ConvertFrom-Json -DateKind String -ErrorAction Stop
            }
            return $text | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            throw "$Description file '$Path' is malformed JSON. $($_.Exception.Message)"
        }
    }

    function Get-CaptureDecisionHistory {
        param([Parameter(Mandatory)][object[]]$History)
        return @($History | ForEach-Object { "$([string]$_.stage)|$([string]$_.changed_at_utc)" })
    }

    $module = Get-Module -Name 'Caldova.HrFrontier.AiBuilder' -ErrorAction Stop
    $repositoryRoot = [IO.Path]::GetFullPath((Join-Path $module.ModuleBase '..\..\..\..\..'))
    $repositoryRootWithSeparator = $repositoryRoot.TrimEnd(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar
    ) + [IO.Path]::DirectorySeparatorChar

    $capabilityHashBefore = Get-HrAiBuilderFileSha256 -Path $CaptureCapabilityEvidencePath
    $capability = Read-CaptureDecisionJson `
        -Path $CaptureCapabilityEvidencePath `
        -Description 'Capture capability evidence'
    $manifest = Read-CaptureDecisionJson -Path $RunManifestPath -Description 'Run manifest'
    $inventory = Read-CaptureDecisionJson -Path $ModelInventoryPath -Description 'Model inventory'

    $manifestModel = @($manifest.models | Where-Object display_name -eq $ModelName)
    $inventoryModel = @($inventory.models | Where-Object display_name -eq $ModelName)
    if ($manifestModel.Count -ne 1 -or $inventoryModel.Count -ne 1) {
        throw "Capture capability validation requires exactly one '$ModelName' record."
    }
    $manifestModel = $manifestModel[0]
    $inventoryModel = $inventoryModel[0]

    if ([string]$manifest.run_id -cne 't2-dev-20260925-001' -or
        [string]$inventory.run_id -cne 't2-dev-20260925-001' -or
        $ModelName -cne 'PersonalMasterDataFixed' -or
        $ModelId -cne '74b09a72-d1f1-4598-bc4d-3746d5c97acc' -or
        $ModelVersion -cne '1.0' -or
        [string]$manifestModel.model_id -cne $ModelId -or
        [string]$inventoryModel.model_id -cne $ModelId -or
        [string]$manifestModel.version -cne $ModelVersion -or
        [string]$inventoryModel.version -cne $ModelVersion -or
        [string]$manifestModel.lifecycle_stage -cne 'blocked' -or
        [string]$inventoryModel.lifecycle_stage -cne 'blocked') {
        throw 'Capture capability validation only supports the exact blocked PersonalMasterDataFixed 1.0 record for run t2-dev-20260925-001.'
    }

    if ([string]$capability.schema_version -cne '1.0' -or
        [string]$capability.run_id -cne 't2-dev-20260925-001' -or
        [string]$capability.status -cne 'passed' -or
        [string]$capability.decision -cne 'capture_validated' -or
        [string]$capability.model.name -cne $ModelName -or
        [string]$capability.model.id -cne $ModelId -or
        [string]$capability.model.version -cne $ModelVersion -or
        @($capability.failed_gates).Count -ne 0) {
        throw 'Capture capability evidence does not contain the exact passed Task 8 decision.'
    }
    $manifestGeneralModel = @($manifest.models | Where-Object display_name -eq 'PersonalMasterDataGeneral')
    $inventoryGeneralModel = @($inventory.models | Where-Object display_name -eq 'PersonalMasterDataGeneral')
    if ([string]$capability.flow_state -cne 'Off' -or
        [bool]$capability.holdout_exposed -ne $false -or
        [string]$capability.capture_pair.source_assignment -cne 'training' -or
        [bool]$capability.exclusions.tenant_call -ne $true -or
        [bool]$capability.exclusions.github_issue_update -ne $true -or
        [bool]$capability.exclusions.holdout_exposure -ne $true -or
        [bool]$capability.exclusions.model_2_0_mutation -ne $true -or
        [bool]$capability.exclusions.business_use_claim -ne $true -or
        [bool]$capability.exclusions.model_quality_claim -ne $true -or
        $manifestGeneralModel.Count -ne 1 -or
        $inventoryGeneralModel.Count -ne 1 -or
        [string]$manifestGeneralModel[0].lifecycle_stage -cne 'not_created' -or
        [string]$inventoryGeneralModel[0].lifecycle_stage -cne 'not_created') {
        throw 'Capture capability containment does not preserve the no-tenant, no-holdout, no-model-2.0, and no-overclaim boundaries.'
    }

    $expectedArtifacts = @(
        [pscustomobject]@{ id = 'source'; path = 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001\capture\cap-20260930094537354Z-34bf8987\source\a01-CAND-2026-0411-brunner.pdf' },
        [pscustomobject]@{ id = 'raw'; path = 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001\capture\cap-20260930094537354Z-34bf8987\cap-20260930094537354Z-34bf8987.ai-builder.raw.json' },
        [pscustomobject]@{ id = 'canonical'; path = 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001\capture\cap-20260930094537354Z-34bf8987\cap-20260930094537354Z-34bf8987.canonical.json' },
        [pscustomobject]@{ id = 'capture_pair'; path = 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001\capture\cap-20260930094537354Z-34bf8987\capture-pair.json' },
        [pscustomobject]@{ id = 'field_contract'; path = 'hr\src\ai-builder\contracts\field-contract.json' },
        [pscustomobject]@{ id = 'model_schema'; path = 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001\model-schema-fixed.json' },
        [pscustomobject]@{ id = 'adapter_script'; path = 'hr\src\scripts\adapters\ConvertFrom-HrAiBuilderEvaluationCapture.ps1' },
        [pscustomobject]@{ id = 'pre_decision_record'; path = 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001\capture-capability-pre-decision.json' },
        [pscustomobject]@{ id = 'historical_model_test_capability'; path = 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001\model-test-capability.json' },
        [pscustomobject]@{ id = 'historical_training_capture_attempt'; path = 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001\training-capture-attempt.json' },
        [pscustomobject]@{ id = 'historical_training_capture_retry'; path = 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001\training-capture-retry.json' },
        [pscustomobject]@{ id = 'training_capture_remediation'; path = 'hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001\training-capture-remediation.json' }
    )
    $artifacts = @($capability.supporting_artifacts)
    if ($artifacts.Count -ne $expectedArtifacts.Count) {
        throw 'Capture capability evidence does not contain the exact portable artifact set.'
    }

    $artifactPaths = @{}
    for ($index = 0; $index -lt $expectedArtifacts.Count; $index++) {
        $expected = $expectedArtifacts[$index]
        $artifact = $artifacts[$index]
        if ([string]$artifact.id -cne $expected.id -or
            [string]$artifact.path -cne $expected.path -or
            [IO.Path]::IsPathRooted([string]$artifact.path)) {
            throw "Capture capability artifact '$($expected.id)' is not the expected portable reference."
        }
        $artifactPath = [IO.Path]::GetFullPath((Join-Path $repositoryRoot ([string]$artifact.path)))
        if (-not $artifactPath.StartsWith($repositoryRootWithSeparator, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Capture capability artifact '$($expected.id)' escapes the repository evidence boundary."
        }
        $freshHash = Get-HrAiBuilderFileSha256 -Path $artifactPath
        if ($freshHash -cne [string]$artifact.sha256) {
            throw "Capture capability artifact '$($expected.id)' does not match its retained SHA-256."
        }
        $artifactPaths[$expected.id] = $artifactPath
    }

    $preDecision = Read-CaptureDecisionJson `
        -Path $artifactPaths.pre_decision_record `
        -Description 'Capture capability pre-decision evidence'
    if ([string]$preDecision.run_id -cne 't2-dev-20260925-001' -or
        [string]$preDecision.model.name -cne $ModelName -or
        [string]$preDecision.model.id -cne $ModelId -or
        [string]$preDecision.model.version -cne $ModelVersion -or
        [string]$preDecision.model.stage -cne 'blocked' -or
        (Get-HrAiBuilderFileSha256 -Path $RunManifestPath) -cne [string]$preDecision.run_manifest_pre_decision_sha256 -or
        (Get-HrAiBuilderFileSha256 -Path $ModelInventoryPath) -cne [string]$preDecision.model_inventory_pre_decision_sha256) {
        throw 'Capture capability pre-decision evidence does not match the exact blocked Task 8 inputs.'
    }

    $manifestHistory = Get-CaptureDecisionHistory -History @($manifestModel.lifecycle_history)
    $inventoryHistory = Get-CaptureDecisionHistory -History @($inventoryModel.lifecycle_history)
    $expectedManifestHistory = Get-CaptureDecisionHistory -History @($preDecision.manifest_lifecycle_history)
    $expectedInventoryHistory = Get-CaptureDecisionHistory -History @($preDecision.inventory_lifecycle_history)
    if (-not (Compare-HrAiBuilderSequence -Left $expectedManifestHistory -Right $manifestHistory) -or
        -not (Compare-HrAiBuilderSequence -Left $expectedInventoryHistory -Right $inventoryHistory)) {
        throw 'Capture capability validation requires the complete pre-existing lifecycle history unchanged.'
    }

    $blocker = Read-CaptureDecisionJson `
        -Path $artifactPaths.historical_model_test_capability `
        -Description 'Task 6 blocker evidence'
    if ([string]$preDecision.task_6_blocker.path -cne $expectedArtifacts[8].path -or
        [string]$preDecision.task_6_blocker.sha256 -cne [string]$artifacts[8].sha256 -or
        [string]$blocker.run_id -cne 't2-dev-20260925-001' -or
        [string]$blocker.status -cne 'blocked' -or
        [string]$blocker.mechanism -cne [string]$preDecision.task_6_blocker.mechanism -or
        [string]$blocker.blocked_reason -cne [string]$preDecision.task_6_blocker.blocked_reason) {
        throw 'Capture capability validation requires the exact retained Task 6 blocker.'
    }

    $pairResult = Test-HrAiBuilderCapturePair `
        -CaptureDirectory (Split-Path -Parent $artifactPaths.capture_pair) `
        -RunManifestPath $RunManifestPath `
        -FieldContractPath $artifactPaths.field_contract `
        -ModelSchemaRecordPath $artifactPaths.model_schema `
        -ModelName $ModelName `
        -ModelVersion $ModelVersion `
        -Operator ([string]$manifest.operator) `
        -AdapterScriptPath $artifactPaths.adapter_script

    $replayDirectory = Join-Path (Split-Path -Parent ([IO.Path]::GetFullPath($RunManifestPath))) (
        '.capture-capability-replay-' + [guid]::NewGuid().ToString('N')
    )
    New-Item -ItemType Directory -Path $replayDirectory -ErrorAction Stop | Out-Null
    $firstReplayPath = Join-Path $replayDirectory 'fixed-capability-replay-1.json'
    $secondReplayPath = Join-Path $replayDirectory 'fixed-capability-replay-2.json'

    try {
        $adapterArguments = @{
            CaptureDirectory = Split-Path -Parent $artifactPaths.capture_pair
            RunManifestPath = $RunManifestPath
            FieldContractPath = $artifactPaths.field_contract
            ModelSchemaRecordPath = $artifactPaths.model_schema
            ModelName = $ModelName
            ModelVersion = $ModelVersion
            Operator = [string]$manifest.operator
            AdapterScriptPath = $artifactPaths.adapter_script
        }
        $firstResult = ConvertFrom-HrAiBuilderEvaluationCapture @adapterArguments -OutputPath $firstReplayPath
        $secondResult = ConvertFrom-HrAiBuilderEvaluationCapture @adapterArguments -OutputPath $secondReplayPath
        if ([string]$firstResult.status -cne 'passed' -or [string]$secondResult.status -cne 'passed') {
            throw 'Capture capability replay did not pass twice.'
        }
        $firstReplayHash = Get-HrAiBuilderFileSha256 -Path $firstReplayPath
        $secondReplayHash = Get-HrAiBuilderFileSha256 -Path $secondReplayPath
        if ($firstReplayHash -cne $secondReplayHash) {
            throw 'Capture capability replay outputs are not byte-identical.'
        }
        $firstHistoricalHash = Get-HrAiBuilderTask8ReplayHash -Path $firstReplayPath `
            -AdapterPath $artifactPaths.adapter_script -RawPath $artifactPaths.raw
        $secondHistoricalHash = Get-HrAiBuilderTask8ReplayHash -Path $secondReplayPath `
            -AdapterPath $artifactPaths.adapter_script -RawPath $artifactPaths.raw
    }
    finally {
        Remove-Item -LiteralPath $replayDirectory -Recurse -Force -ErrorAction Stop
    }

    $failedPairGates = @($pairResult.failed_gates)
    $derivedGates = [ordered]@{
        'AEC-G001' = -not $failedPairGates.Contains('exact_correlation')
        'AEC-G002' = -not $failedPairGates.Contains('source_sha256')
        'AEC-G003' = -not $failedPairGates.Contains('capture_pair_provenance')
        'AEC-G004' = -not $failedPairGates.Contains('exact_field_contract')
        'AEC-G005' = -not $failedPairGates.Contains('prediction_capture_schema')
        'AEC-G006' = (
            -not $failedPairGates.Contains('canonical_serialization') -and
            $firstReplayHash -ceq $secondReplayHash
        )
        'AEC-G007' = (
            [string]$pairResult.status -ceq 'passed' -and
            -not $failedPairGates.Contains('adapter_replay') -and
            [string]$pairResult.hashes.replay_sha256 -ceq [string]$pairResult.hashes.canonical_sha256
        )
    }
    $recordedGates = @($capability.gates)
    if ($recordedGates.Count -ne 7) {
        throw 'Capture capability evidence must contain exactly seven gates.'
    }
    for ($index = 0; $index -lt $recordedGates.Count; $index++) {
        $expectedGateId = "AEC-G00$($index + 1)"
        $recordedGate = $recordedGates[$index]
        if ([string]$recordedGate.id -cne $expectedGateId -or
            [string]$recordedGate.status -cne 'passed' -or
            $derivedGates[$expectedGateId] -ne $true) {
            throw "Capture capability gate '$expectedGateId' is failed, unknown, or not live-derived."
        }
    }

    if ($firstHistoricalHash -cne [string]$capability.replay.first_sha256 -or
        $secondHistoricalHash -cne [string]$capability.replay.second_sha256 -or
        [bool]$capability.replay.byte_deterministic -ne $true) {
        throw 'Capture capability replay hashes do not match the live adapter outputs.'
    }
    if ([string]$pairResult.hashes.source_sha256 -cne [string]$capability.supporting_hashes.source_sha256 -or
        [string]$pairResult.hashes.raw_sha256 -cne [string]$capability.supporting_hashes.raw_sha256 -or
        [string]$pairResult.hashes.canonical_sha256 -cne [string]$capability.supporting_hashes.canonical_sha256 -or
        [string]$pairResult.hashes.replay_sha256 -cne [string]$capability.supporting_hashes.canonical_replay_sha256) {
        throw 'Capture capability supporting hashes do not match the live capture-pair result.'
    }

    $capabilityHashAfter = Get-HrAiBuilderFileSha256 -Path $CaptureCapabilityEvidencePath
    if ($capabilityHashBefore -cne $capabilityHashAfter) {
        throw 'Capture capability evidence changed during verification.'
    }
}
