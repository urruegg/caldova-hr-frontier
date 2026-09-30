function Set-HrAiBuilderHoldoutCaptured {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$LedgerPath,
        [Parameter(Mandatory)][string]$Document,
        [Parameter(Mandatory)][ValidatePattern('^[a-fA-F0-9]{64}$')][string]$SourceSha256,
        [Parameter(Mandatory)][string]$ExecutionRunId,
        [Parameter(Mandatory)][string]$PlatformRunId,
        [Parameter(Mandatory)][string]$CaptureDirectory,
        [Parameter(Mandatory)][string]$CapturePairPath,
        [Parameter(Mandatory)][string]$CapturePairLocator,
        [Parameter(Mandatory)][ValidatePattern('^[a-fA-F0-9]{64}$')][string]$CapturePairSha256,
        [Parameter(Mandatory)][string]$RunManifestPath,
        [Parameter(Mandatory)][string]$FieldContractPath,
        [Parameter(Mandatory)][string]$ModelSchemaRecordPath,
        [Parameter(Mandatory)][string]$ModelName,
        [Parameter(Mandatory)][string]$ModelVersion,
        [Parameter(Mandatory)][string]$Operator,
        [Parameter(Mandatory)][string]$AdapterScriptPath,
        [Parameter(Mandatory)][AllowEmptyString()][string]$CurrentFlowState
    )

    if ($CurrentFlowState -cne 'Off') {
        throw 'The calculated current flow state must be Off.'
    }

    $ledgerFullPath = [IO.Path]::GetFullPath($LedgerPath)
    if (-not (Test-Path -LiteralPath $ledgerFullPath -PathType Leaf)) {
        throw "Holdout-consumption ledger '$LedgerPath' was not found."
    }
    if (-not (Test-Path -LiteralPath $CapturePairPath -PathType Leaf)) {
        throw "The capture-pair evidence '$CapturePairPath' was not found."
    }

    $captureDirectoryFullPath = [IO.Path]::GetFullPath($CaptureDirectory)
    $capturePairFullPath = [IO.Path]::GetFullPath($CapturePairPath)
    $expectedPairFullPath = [IO.Path]::GetFullPath((Join-Path $captureDirectoryFullPath 'capture-pair.json'))
    if ($capturePairFullPath -cne $expectedPairFullPath) {
        throw 'The capture-pair path must identify capture-pair.json in the supplied capture directory.'
    }
    if ((Split-Path -Leaf $captureDirectoryFullPath) -cne $ExecutionRunId) {
        throw 'The execution run ID does not match the capture directory.'
    }
    if ((Split-Path -Leaf (Split-Path -Parent $captureDirectoryFullPath)) -cne 'fixed-holdout') {
        throw 'The capture stage directory must be fixed-holdout.'
    }

    $expectedPairLocator = "capture\fixed-holdout\$ExecutionRunId\capture-pair.json"
    if ($CapturePairLocator -cne $expectedPairLocator) {
        throw 'The capture-pair locator does not match the execution run ID and fixed-holdout stage.'
    }

    $actualPairSha256 = (Get-FileHash -LiteralPath $capturePairFullPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualPairSha256 -cne $CapturePairSha256.ToLowerInvariant()) {
        throw 'The capture-pair SHA-256 does not match the supplied evidence hash.'
    }

    $lockPath = "$ledgerFullPath.transition.lock"
    try {
        $lockStream = [IO.File]::Open($lockPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    }
    catch {
        throw "The holdout-consumption ledger transition is already in progress. $($_.Exception.Message)"
    }

    $temporaryPath = $null
    $backupPath = $null
    try {
        $originalBytes = [IO.File]::ReadAllBytes($ledgerFullPath)
        $utf8 = [Text.UTF8Encoding]::new($false, $true)
        try {
            $ledgerText = $utf8.GetString($originalBytes).TrimStart([char]0xFEFF)
            $convertFromJson = Get-Command ConvertFrom-Json -ErrorAction Stop
            if ($convertFromJson.Parameters.ContainsKey('DateKind')) {
                $ledger = $ledgerText | ConvertFrom-Json -DateKind String -ErrorAction Stop
            }
            else {
                $ledger = $ledgerText | ConvertFrom-Json -ErrorAction Stop
            }
        }
        catch {
            throw "Holdout-consumption ledger '$LedgerPath' is malformed JSON. $($_.Exception.Message)"
        }

        $matchingRows = @($ledger.holdouts | Where-Object {
            [string]$_.document -ceq $Document -and
            [string]$_.sha256 -ceq $SourceSha256.ToLowerInvariant()
        })
        if ($matchingRows.Count -ne 1) {
            throw 'The document and source SHA-256 must identify exactly one ledger row.'
        }

        $target = $matchingRows[0]
        if ([string]$target.state -cne 'unseen') {
            throw "The holdout row must be unseen; its current state is '$($target.state)'."
        }

        if ([string]$ledger.model.name -cne $ModelName -or
            [string]$ledger.model.version -cne $ModelVersion) {
            throw 'The requested model name and version do not match the holdout ledger.'
        }

        $pairText = [IO.File]::ReadAllText($capturePairFullPath, [Text.UTF8Encoding]::new($false, $true))
        $convertFromJson = Get-Command ConvertFrom-Json -ErrorAction Stop
        if ($convertFromJson.Parameters.ContainsKey('DateKind')) {
            $pair = $pairText | ConvertFrom-Json -DateKind String -ErrorAction Stop
        }
        else {
            $pair = $pairText | ConvertFrom-Json -ErrorAction Stop
        }
        if ([string]$pair.capture_stage -cne 'fixed-holdout') {
            throw 'The capture pair stage must be fixed-holdout.'
        }
        if ([string]$pair.run_id -cne $ExecutionRunId) {
            throw 'The execution run ID does not match the capture pair.'
        }
        if ([string]$pair.source.filename -cne $Document -or
            [string]$pair.source.sha256 -cne $SourceSha256.ToLowerInvariant()) {
            throw 'The capture-pair source does not match the exact holdout ledger row.'
        }
        if ([string]$pair.source.assignment -cne 'held-out') {
            throw 'The capture-pair source assignment must be held-out.'
        }
        if ([string]$pair.corpus_revision -cne [string]$ledger.corpus_revision) {
            throw 'The capture-pair corpus revision does not match the holdout ledger.'
        }
        if ([string]$pair.model.name -cne [string]$ledger.model.name -or
            [string]$pair.model.id -cne [string]$ledger.model.id -or
            [string]$pair.model.version -cne [string]$ledger.model.version) {
            throw 'The capture-pair model identity does not match the holdout ledger.'
        }

        $pairValidation = Test-HrAiBuilderCapturePair `
            -CaptureDirectory $captureDirectoryFullPath `
            -RunManifestPath $RunManifestPath `
            -FieldContractPath $FieldContractPath `
            -ModelSchemaRecordPath $ModelSchemaRecordPath `
            -ModelName $ModelName `
            -ModelVersion $ModelVersion `
            -Operator $Operator `
            -AdapterScriptPath $AdapterScriptPath

        if ([string]$pairValidation.status -cne 'passed' -or
            @($pairValidation.failed_gates).Count -ne 0) {
            throw 'The independent capture-pair validation must pass before the holdout ledger can transition.'
        }

        $pairSha256AfterValidation = (Get-FileHash -LiteralPath $capturePairFullPath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($pairSha256AfterValidation -cne $actualPairSha256) {
            throw 'The capture-pair evidence changed during independent validation.'
        }
        if ([string]$pairValidation.hashes.source_sha256 -cne $SourceSha256.ToLowerInvariant()) {
            throw 'The independently calculated source SHA-256 does not match the holdout ledger.'
        }
        if ([string]$pairValidation.hashes.canonical_sha256 -cne [string]$pairValidation.hashes.replay_sha256) {
            throw 'The independently replayed canonical SHA-256 does not match the captured canonical evidence.'
        }

        function Get-HoldoutEvidenceValue {
            param(
                [Parameter(Mandatory)][object]$Row,
                [Parameter(Mandatory)][string]$Name
            )

            $property = $Row.PSObject.Properties[$Name]
            if ($null -eq $property) {
                return $null
            }
            return $property.Value
        }

        foreach ($row in @($ledger.holdouts)) {
            if ($row -ne $target -and (
                [string](Get-HoldoutEvidenceValue -Row $row -Name 'execution_run_id') -ceq $ExecutionRunId -or
                [string](Get-HoldoutEvidenceValue -Row $row -Name 'platform_run_id') -ceq $PlatformRunId -or
                [string](Get-HoldoutEvidenceValue -Row $row -Name 'capture_pair_path') -ceq $CapturePairLocator -or
                [string](Get-HoldoutEvidenceValue -Row $row -Name 'capture_pair_sha256') -ceq $actualPairSha256
            )) {
                throw 'The capture evidence is already assigned to another holdout row.'
            }
        }

        $target.state = 'captured'
        $target | Add-Member -NotePropertyName execution_run_id -NotePropertyValue $ExecutionRunId
        $target | Add-Member -NotePropertyName platform_run_id -NotePropertyValue $PlatformRunId
        $target | Add-Member -NotePropertyName capture_pair_path -NotePropertyValue $CapturePairLocator
        $target | Add-Member -NotePropertyName capture_pair_sha256 -NotePropertyValue $actualPairSha256
        $target | Add-Member -NotePropertyName raw_sha256 -NotePropertyValue ([string]$pairValidation.hashes.raw_sha256)
        $target | Add-Member -NotePropertyName canonical_sha256 -NotePropertyValue ([string]$pairValidation.hashes.canonical_sha256)
        $target | Add-Member -NotePropertyName captured_at_utc -NotePropertyValue ([string]$pair.captured_at_utc)

        $currentBytes = [IO.File]::ReadAllBytes($ledgerFullPath)
        if ([Convert]::ToBase64String($currentBytes) -cne [Convert]::ToBase64String($originalBytes)) {
            throw 'The holdout-consumption ledger changed during the transition.'
        }

        $json = $ledger | ConvertTo-Json -Depth 20
        $updatedBytes = [Text.UTF8Encoding]::new($false).GetBytes(($json.TrimEnd() + "`n"))
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
        return $target
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
