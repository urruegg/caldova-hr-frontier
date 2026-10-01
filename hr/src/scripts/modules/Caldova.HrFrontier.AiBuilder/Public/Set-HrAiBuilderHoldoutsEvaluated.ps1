function Set-HrAiBuilderHoldoutsEvaluated {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$LedgerPath,
        [Parameter(Mandatory)][string]$EvaluationMetricsPath,
        [Parameter(Mandatory)][ValidatePattern('^[a-fA-F0-9]{64}$')][string]$EvaluationMetricsSha256,
        [Parameter(Mandatory)][string]$ModelName,
        [Parameter(Mandatory)][string]$ModelVersion
    )

    $ledgerFullPath = [IO.Path]::GetFullPath($LedgerPath)
    $metricsFullPath = [IO.Path]::GetFullPath($EvaluationMetricsPath)
    if (-not (Test-Path -LiteralPath $ledgerFullPath -PathType Leaf)) {
        throw "Holdout-consumption ledger '$LedgerPath' was not found."
    }
    if (-not (Test-Path -LiteralPath $metricsFullPath -PathType Leaf)) {
        throw "Evaluation metrics '$EvaluationMetricsPath' were not found."
    }
    if ((Split-Path -Parent $ledgerFullPath) -cne (Split-Path -Parent $metricsFullPath) -or
        (Split-Path -Leaf $metricsFullPath) -cne 'evaluation-metrics.json') {
        throw 'Evaluation metrics must be evaluation-metrics.json beside the holdout-consumption ledger.'
    }

    $actualMetricsSha256 = (Get-FileHash -LiteralPath $metricsFullPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualMetricsSha256 -cne $EvaluationMetricsSha256.ToLowerInvariant()) {
        throw 'The evaluation metrics SHA-256 does not match the supplied evidence hash.'
    }

    $lockPath = "$ledgerFullPath.transition.lock"
    $temporaryPath = $null
    $backupPath = $null
    try {
        $lockStream = [IO.File]::Open($lockPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    }
    catch {
        throw "The holdout-consumption ledger transition is already in progress. $($_.Exception.Message)"
    }

    try {
        $utf8 = [Text.UTF8Encoding]::new($false, $true)
        $originalBytes = [IO.File]::ReadAllBytes($ledgerFullPath)
        $ledgerText = $utf8.GetString($originalBytes).TrimStart([char]0xFEFF)
        $metricsText = $utf8.GetString([IO.File]::ReadAllBytes($metricsFullPath)).TrimStart([char]0xFEFF)
        $convertFromJson = Get-Command ConvertFrom-Json -ErrorAction Stop
        if ($convertFromJson.Parameters.ContainsKey('DateKind')) {
            $ledger = $ledgerText | ConvertFrom-Json -DateKind String
            $metrics = $metricsText | ConvertFrom-Json -DateKind String
        }
        else {
            $ledger = $ledgerText | ConvertFrom-Json
            $metrics = $metricsText | ConvertFrom-Json
        }

        if ([string]$ledger.model.name -cne $ModelName -or
            [string]$ledger.model.version -cne $ModelVersion) {
            throw 'The requested model name and version do not match the holdout ledger.'
        }

        $holdouts = @($ledger.holdouts)
        if ($holdouts.Count -ne 4 -or @($holdouts | Where-Object { [string]$_.state -cne 'captured' }).Count -ne 0) {
            throw 'All four holdouts must be captured before evaluation can be recorded.'
        }
        foreach ($row in $holdouts) {
            if ([string]::IsNullOrWhiteSpace([string]$row.execution_run_id) -or
                [string]::IsNullOrWhiteSpace([string]$row.platform_run_id) -or
                [string]$row.capture_pair_sha256 -notmatch '^[a-f0-9]{64}$' -or
                [string]$row.raw_sha256 -notmatch '^[a-f0-9]{64}$' -or
                [string]$row.canonical_sha256 -notmatch '^[a-f0-9]{64}$') {
                throw 'Every captured holdout must retain complete capture evidence.'
            }
        }

        $metricModels = @($metrics.models | Where-Object {
            [string]$_.run_id -ceq [string]$ledger.run_id -and
            [string]$_.model_name -ceq $ModelName -and
            [string]$_.model_version -ceq $ModelVersion
        })
        if ([string]$metrics.run_id -cne [string]$ledger.run_id -or $metricModels.Count -ne 1) {
            throw 'Evaluation metrics must identify exactly the ledger run, model and version.'
        }

        $metric = $metricModels[0]
        if ([string]$metric.strict_gate_disposition -cne 'evaluated' -or
            @($metric.failed_gates).Count -ne 0) {
            throw 'The strict evaluation disposition must be evaluated with no failed gates.'
        }

        $expectedRecordCount = $holdouts.Count * 17
        if ([int]$metric.expected_validation_record_count -ne $expectedRecordCount -or
            [int]$metric.actual_validation_record_count -ne $expectedRecordCount -or
            [int]$metric.false_value_count -ne 0 -or
            [double]$metric.false_value_rate -ne 0) {
            throw "Evaluation metrics must retain exactly $expectedRecordCount records and zero false values."
        }

        $metricsSha256AfterValidation = (Get-FileHash -LiteralPath $metricsFullPath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($metricsSha256AfterValidation -cne $actualMetricsSha256) {
            throw 'Evaluation metrics changed during the holdout transition.'
        }

        $evaluatedAtUtc = [datetime]::UtcNow.ToString('o')
        foreach ($row in $holdouts) {
            $row.state = 'evaluated'
            $row | Add-Member -NotePropertyName evaluation_metrics_path -NotePropertyValue 'evaluation-metrics.json'
            $row | Add-Member -NotePropertyName evaluation_metrics_sha256 -NotePropertyValue $actualMetricsSha256
            $row | Add-Member -NotePropertyName evaluated_at_utc -NotePropertyValue $evaluatedAtUtc
        }

        $currentBytes = [IO.File]::ReadAllBytes($ledgerFullPath)
        if ([Convert]::ToBase64String($currentBytes) -cne [Convert]::ToBase64String($originalBytes)) {
            throw 'The holdout-consumption ledger changed during the transition.'
        }

        $updatedJson = $ledger | ConvertTo-Json -Depth 20
        $updatedBytes = [Text.UTF8Encoding]::new($false).GetBytes(($updatedJson.TrimEnd() + "`n"))
        $temporaryPath = "$ledgerFullPath.$([guid]::NewGuid().ToString('N')).tmp"
        $temporaryStream = [IO.File]::Open(
            $temporaryPath,
            [IO.FileMode]::CreateNew,
            [IO.FileAccess]::Write,
            [IO.FileShare]::None
        )
        try {
            $temporaryStream.Write($updatedBytes, 0, $updatedBytes.Length)
            $temporaryStream.Flush($true)
        }
        finally {
            $temporaryStream.Dispose()
        }

        $backupPath = "$ledgerFullPath.$([guid]::NewGuid().ToString('N')).bak"
        [IO.File]::Replace($temporaryPath, $ledgerFullPath, $backupPath)
        $temporaryPath = $null
        Remove-Item -LiteralPath $backupPath -Force
        $backupPath = $null
        return $ledger
    }
    finally {
        if ($temporaryPath -and (Test-Path -LiteralPath $temporaryPath -PathType Leaf)) {
            Remove-Item -LiteralPath $temporaryPath -Force
        }
        if ($backupPath -and (Test-Path -LiteralPath $backupPath -PathType Leaf)) {
            Remove-Item -LiteralPath $backupPath -Force
        }
        $lockStream.Dispose()
        Remove-Item -LiteralPath $lockPath -Force
    }
}
