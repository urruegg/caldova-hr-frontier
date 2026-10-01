function Test-HrAiBuilderFixedApprovalEligibility {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$EvidenceRoot,
        [Parameter(Mandatory)][string]$ModelName,
        [Parameter(Mandatory)][string]$ModelId,
        [Parameter(Mandatory)][string]$ModelVersion,
        [Parameter()][string]$OutputPath
    )

    $root = [IO.Path]::GetFullPath($EvidenceRoot)
    $paths = [ordered]@{
        manifest = Join-Path $root 'run-manifest.json'
        inventory = Join-Path $root 'model-inventory.json'
        capability = Join-Path $root 'capture-capability.json'
        security = Join-Path $root 'security-verification.json'
        metrics = Join-Path $root 'evaluation-metrics.json'
        prediction = Join-Path $root 'prediction-capture-fixed.json'
        ledger = Join-Path $root 'holdout-consumption.json'
    }
    $failedGates = [Collections.Generic.List[string]]::new()

    foreach ($entry in $paths.GetEnumerator()) {
        if (-not (Test-Path -LiteralPath $entry.Value -PathType Leaf)) {
            $failedGates.Add("missing_$($entry.Key)")
        }
    }
    if ($failedGates.Count -gt 0) {
        $result = [ordered]@{
            schema_version = '1.0'
            calculated_at_utc = [datetime]::UtcNow.ToString('o')
            status = 'blocked'
            failed_gates = @($failedGates)
            model = [ordered]@{ name = $ModelName; id = $ModelId; version = $ModelVersion }
        }
        if ($OutputPath) {
            Write-HrAiBuilderJson -InputObject $result -Path $OutputPath
        }
        return [pscustomobject]$result
    }

    $manifest = Read-HrAiBuilderJson -Path $paths.manifest -Description 'Run manifest'
    $inventory = Read-HrAiBuilderJson -Path $paths.inventory -Description 'Model inventory'
    $capability = Read-HrAiBuilderJson -Path $paths.capability -Description 'Capture capability'
    $security = Read-HrAiBuilderJson -Path $paths.security -Description 'Security verification'
    $metrics = Read-HrAiBuilderJson -Path $paths.metrics -Description 'Evaluation metrics'
    $prediction = Read-HrAiBuilderJson -Path $paths.prediction -Description 'Fixed prediction capture'
    $ledger = Read-HrAiBuilderJson -Path $paths.ledger -Description 'Holdout-consumption ledger'

    $manifestModels = @($manifest.models | Where-Object {
        [string]$_.display_name -ceq $ModelName -and
        [string]$_.model_id -ceq $ModelId -and
        [string]$_.version -ceq $ModelVersion
    })
    $inventoryModels = @($inventory.models | Where-Object {
        [string]$_.display_name -ceq $ModelName -and
        [string]$_.model_id -ceq $ModelId -and
        [string]$_.version -ceq $ModelVersion
    })
    $eligibleLifecycleStages = @('evaluated', 'approved_for_solution', 'added_to_solution')
    $manifestLifecycleStage = if ($manifestModels.Count -eq 1) {
        [string]$manifestModels[0].lifecycle_stage
    }
    else {
        ''
    }
    $inventoryLifecycleStage = if ($inventoryModels.Count -eq 1) {
        [string]$inventoryModels[0].lifecycle_stage
    }
    else {
        ''
    }
    $manifestHistory = if ($manifestModels.Count -eq 1) { @($manifestModels[0].lifecycle_history.stage) } else { @() }
    $inventoryHistory = if ($inventoryModels.Count -eq 1) { @($inventoryModels[0].lifecycle_history.stage) } else { @() }
    if ($manifestModels.Count -ne 1 -or $inventoryModels.Count -ne 1 -or
        $manifestLifecycleStage -cne $inventoryLifecycleStage -or
        $manifestLifecycleStage -cnotin $eligibleLifecycleStages -or
        $manifestHistory -cnotcontains 'evaluated' -or
        $inventoryHistory -cnotcontains 'evaluated') {
        $failedGates.Add('exact_evaluated_model')
    }

    if ([string]$capability.status -cne 'passed' -or
        [string]$capability.decision -cne 'capture_validated' -or
        @($capability.failed_gates).Count -ne 0 -or
        [string]$capability.model.name -cne $ModelName -or
        [string]$capability.model.id -cne $ModelId -or
        [string]$capability.model.version -cne $ModelVersion) {
        $failedGates.Add('capture_capability')
    }
    if ([string]$security.status -cne 'passed') {
        $failedGates.Add('security_verification')
    }
    $retainedFlowState = [string]$security.resource_read_back.flow.portal_status
    if ($retainedFlowState -cne 'Off' -or [string]$capability.flow_state -cne 'Off') {
        $failedGates.Add('flow_off')
    }

    $metricModels = @($metrics.models | Where-Object {
        [string]$_.run_id -ceq [string]$manifest.run_id -and
        [string]$_.model_name -ceq $ModelName -and
        [string]$_.model_version -ceq $ModelVersion
    })
    $metric = if ($metricModels.Count -eq 1) { $metricModels[0] } else { $null }
    if (-not $metric -or
        [string]$metric.strict_gate_disposition -cne 'evaluated' -or
        @($metric.failed_gates).Count -ne 0 -or
        [int]$metric.expected_validation_record_count -ne 68 -or
        [int]$metric.actual_validation_record_count -ne 68 -or
        [int]$metric.false_value_count -ne 0 -or
        [double]$metric.false_value_rate -ne 0) {
        $failedGates.Add('strict_evaluation')
    }

    $documents = @($prediction.documents)
    $fieldCount = @($documents | ForEach-Object { $_.fields.PSObject.Properties }).Count
    if ([string]$prediction.run_id -cne [string]$manifest.run_id -or
        [string]$prediction.model_name -cne $ModelName -or
        [string]$prediction.model_version -cne $ModelVersion -or
        [string]$prediction.adapter_contract -cne 'replayable-v2' -or
        $documents.Count -ne 4 -or $fieldCount -ne 68) {
        $failedGates.Add('complete_replay_capture')
    }

    $holdouts = @($ledger.holdouts)
    $evaluatedHoldouts = @($holdouts | Where-Object state -ceq 'evaluated')
    $consumedHoldouts = @($holdouts | Where-Object state -ceq 'consumed_by_model_change')
    if ([string]$ledger.run_id -cne [string]$manifest.run_id -or
        [string]$ledger.model.name -cne $ModelName -or
        [string]$ledger.model.id -cne $ModelId -or
        [string]$ledger.model.version -cne $ModelVersion -or
        $holdouts.Count -ne 4 -or $evaluatedHoldouts.Count -ne 4 -or $consumedHoldouts.Count -ne 0) {
        $failedGates.Add('holdout_consumption')
    }

    $metricsSha256 = (Get-FileHash -LiteralPath $paths.metrics -Algorithm SHA256).Hash.ToLowerInvariant()
    foreach ($row in $holdouts) {
        $pairPath = Join-Path $root ([string]$row.capture_pair_path)
        if (-not (Test-Path -LiteralPath $pairPath -PathType Leaf) -or
            (Get-FileHash -LiteralPath $pairPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne
                [string]$row.capture_pair_sha256 -or
            [string]$row.evaluation_metrics_sha256 -cne $metricsSha256) {
            $failedGates.Add('evidence_hashes')
            break
        }
        $pair = Read-HrAiBuilderJson -Path $pairPath -Description 'Capture pair'
        $rawPath = Join-Path $root ([string]$pair.raw.local_path)
        $canonicalPath = Join-Path $root ([string]$pair.canonical.local_path)
        if (-not (Test-Path -LiteralPath $rawPath -PathType Leaf) -or
            -not (Test-Path -LiteralPath $canonicalPath -PathType Leaf) -or
            (Get-FileHash -LiteralPath $rawPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne [string]$row.raw_sha256 -or
            (Get-FileHash -LiteralPath $canonicalPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne
                [string]$row.canonical_sha256) {
            $failedGates.Add('evidence_hashes')
            break
        }
    }

    $result = [ordered]@{
        schema_version = '1.0'
        calculated_at_utc = [datetime]::UtcNow.ToString('o')
        run_id = [string]$manifest.run_id
        status = if ($failedGates.Count -eq 0) { 'eligible' } else { 'blocked' }
        failed_gates = @($failedGates)
        model = [ordered]@{ name = $ModelName; id = $ModelId; version = $ModelVersion }
        calculated = [ordered]@{
            records = if ($metric) { [int]$metric.actual_validation_record_count } else { 0 }
            false_value_count = if ($metric) { [int]$metric.false_value_count } else { 0 }
            quality_finding_count = if ($metric) { [int]$metric.quality_finding_count } else { 0 }
            evaluated_holdout_count = $evaluatedHoldouts.Count
            consumed_holdout_count = $consumedHoldouts.Count
            flow_state = $retainedFlowState
            security_status = [string]$security.status
        }
        hashes = [ordered]@{
            evaluation_metrics_sha256 = $metricsSha256
            prediction_capture_sha256 = (Get-FileHash -LiteralPath $paths.prediction -Algorithm SHA256).Hash.ToLowerInvariant()
            holdout_ledger_sha256 = (Get-FileHash -LiteralPath $paths.ledger -Algorithm SHA256).Hash.ToLowerInvariant()
            security_verification_sha256 = (Get-FileHash -LiteralPath $paths.security -Algorithm SHA256).Hash.ToLowerInvariant()
            capture_capability_sha256 = (Get-FileHash -LiteralPath $paths.capability -Algorithm SHA256).Hash.ToLowerInvariant()
        }
    }
    if ($OutputPath) {
        Write-HrAiBuilderJson -InputObject $result -Path $OutputPath
    }
    return [pscustomobject]$result
}
