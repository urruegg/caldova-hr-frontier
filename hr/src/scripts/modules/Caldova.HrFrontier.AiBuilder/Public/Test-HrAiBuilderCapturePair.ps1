function Test-HrAiBuilderCapturePair {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CaptureDirectory,

        [Parameter(Mandatory)]
        [string]$RunManifestPath,

        [Parameter(Mandatory)]
        [string]$FieldContractPath,

        [Parameter(Mandatory)]
        [string]$ModelSchemaRecordPath,

        [Parameter(Mandatory)]
        [string]$ModelName,

        [Parameter(Mandatory)]
        [string]$ModelVersion,

        [Parameter(Mandatory)]
        [string]$Operator,

        [string]$AdapterScriptPath
    )

    $failedGates = [System.Collections.Generic.List[string]]::new()
    $blockedReason = $null
    $hashes = [ordered]@{
        source_sha256 = $null
        raw_sha256 = $null
        canonical_sha256 = $null
        adapter_script_sha256 = $null
        replay_sha256 = $null
    }

    function Add-CapturePairFailure {
        param([Parameter(Mandatory)][string]$Gate)
        if (-not $failedGates.Contains($Gate)) {
            $failedGates.Add($Gate)
        }
    }

    function Test-CapturePairOrdinal {
        param([AllowNull()][object]$Left, [AllowNull()][object]$Right)
        if ($null -eq $Left -or $null -eq $Right) {
            return ($null -eq $Left -and $null -eq $Right)
        }
        return [string]::Equals([string]$Left, [string]$Right, [StringComparison]::Ordinal)
    }

    function Complete-CapturePairResult {
        param(
            [AllowNull()][object]$Envelope,
            [AllowNull()][object]$Document,
            [AllowNull()][string]$RawPath
        )

        [pscustomobject]@{
            status = if ($failedGates.Count -eq 0) { 'passed' } else { 'blocked' }
            failed_gates = @($failedGates)
            blocked_reason = $blockedReason
            hashes = [pscustomobject]$hashes
            canonical_envelope = $Envelope
            document = $Document
            raw_path = $RawPath
        }
    }

    trap {
        $blockedReason = $_.Exception.Message
        Add-CapturePairFailure 'capture_pair_provenance'
        return Complete-CapturePairResult
    }

    if (-not (Test-Path -LiteralPath $CaptureDirectory -PathType Container)) {
        Add-CapturePairFailure 'evidence_boundary'
        return Complete-CapturePairResult
    }

    $capturePath = [IO.Path]::GetFullPath($CaptureDirectory)
    $rawFiles = @(Get-ChildItem -LiteralPath $capturePath -Filter '*.ai-builder.raw.json' -File)
    $canonicalFiles = @(Get-ChildItem -LiteralPath $capturePath -Filter '*.canonical.json' -File)
    $pairFiles = @(Get-ChildItem -LiteralPath $capturePath -Filter 'capture-pair.json' -File)
    if ($rawFiles.Count -ne 1 -or $canonicalFiles.Count -ne 1 -or $pairFiles.Count -ne 1) {
        Add-CapturePairFailure 'capture_pair_provenance'
        return Complete-CapturePairResult
    }

    $rawSuffix = '.ai-builder.raw.json'
    $canonicalSuffix = '.canonical.json'
    $captureRunId = $rawFiles[0].Name.Substring(0, $rawFiles[0].Name.Length - $rawSuffix.Length)
    $canonicalRunId = $canonicalFiles[0].Name.Substring(0, $canonicalFiles[0].Name.Length - $canonicalSuffix.Length)
    if (-not (Test-CapturePairOrdinal $captureRunId $canonicalRunId) -or
        -not (Test-CapturePairOrdinal $captureRunId (Split-Path -Leaf $capturePath))) {
        Add-CapturePairFailure 'exact_correlation'
    }

    try {
        $pair = Read-HrAiBuilderJson -Path $pairFiles[0].FullName -Description 'Capture pair'
        $manifest = Read-HrAiBuilderJson -Path $RunManifestPath -Description 'Run manifest'
        $contract = Read-HrAiBuilderJson -Path $FieldContractPath -Description 'Field contract'
        $schema = Read-HrAiBuilderJson -Path $ModelSchemaRecordPath -Description 'Model schema record'
        $canonicalBytes = [IO.File]::ReadAllBytes($canonicalFiles[0].FullName)
        $canonicalText = [Text.UTF8Encoding]::new($false, $true).GetString($canonicalBytes)
        $canonical = $canonicalText.TrimStart([char]0xFEFF) | ConvertFrom-Json
        $raw = Read-HrAiBuilderJson -Path $rawFiles[0].FullName -Description 'Raw response'
    }
    catch {
        Add-CapturePairFailure 'capture_pair_provenance'
        return Complete-CapturePairResult
    }

    $captureRoot = Split-Path -Parent $capturePath
    $evidenceRoot = Split-Path -Parent $captureRoot
    try {
        $sourcePath = [IO.Path]::GetFullPath((Join-Path $evidenceRoot ([string]$pair.source.local_path)))
        $pairRawPath = [IO.Path]::GetFullPath((Join-Path $evidenceRoot ([string]$pair.raw.local_path)))
        $pairCanonicalPath = [IO.Path]::GetFullPath((Join-Path $evidenceRoot ([string]$pair.canonical.local_path)))
        foreach ($path in @($sourcePath, $pairRawPath, $pairCanonicalPath)) {
            if (-not (Test-HrAiBuilderPathWithinRoot -Path $path -RootPath $evidenceRoot)) {
                Add-CapturePairFailure 'evidence_boundary'
            }
        }
    }
    catch {
        Add-CapturePairFailure 'evidence_boundary'
        return Complete-CapturePairResult -Envelope $canonical -RawPath $rawFiles[0].FullName
    }

    if (-not (Test-CapturePairOrdinal $pairRawPath $rawFiles[0].FullName) -or
        -not (Test-CapturePairOrdinal $pairCanonicalPath $canonicalFiles[0].FullName) -or
        -not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        Add-CapturePairFailure 'evidence_boundary'
    }

    try {
        $hashes.source_sha256 = Get-HrAiBuilderFileSha256 -Path $sourcePath
        $hashes.raw_sha256 = Get-HrAiBuilderFileSha256 -Path $rawFiles[0].FullName
        $hashes.canonical_sha256 = Get-HrAiBuilderFileSha256 -Path $canonicalFiles[0].FullName
        if ($AdapterScriptPath) {
            $hashes.adapter_script_sha256 = Get-HrAiBuilderFileSha256 -Path $AdapterScriptPath
        }
    }
    catch {
        Add-CapturePairFailure 'capture_pair_provenance'
    }

    if (-not (Test-CapturePairOrdinal $hashes.source_sha256 $pair.source.sha256) -or
        -not (Test-CapturePairOrdinal $hashes.source_sha256 $canonical.claimed_sha256)) {
        Add-CapturePairFailure 'source_sha256'
    }
    if (-not (Test-CapturePairOrdinal $hashes.raw_sha256 $pair.raw.sha256) -or
        -not (Test-CapturePairOrdinal $hashes.canonical_sha256 $pair.canonical.sha256)) {
        Add-CapturePairFailure 'capture_pair_provenance'
    }

    $hasBom = $canonicalBytes.Length -ge 3 -and
        $canonicalBytes[0] -eq 0xEF -and $canonicalBytes[1] -eq 0xBB -and $canonicalBytes[2] -eq 0xBF
    $terminalLfCount = 0
    for ($index = $canonicalBytes.Length - 1; $index -ge 0 -and $canonicalBytes[$index] -eq 0x0A; $index--) {
        $terminalLfCount++
    }
    if ($hasBom -or $canonicalBytes.Length -eq 0 -or $terminalLfCount -ne 1 -or $canonicalBytes -contains 0x0D) {
        Add-CapturePairFailure 'canonical_serialization'
    }

    $manifestModels = @($manifest.models | Where-Object {
        Test-CapturePairOrdinal $_.display_name $ModelName
    })
    if ($manifestModels.Count -ne 1 -or
        -not (Test-CapturePairOrdinal $manifestModels[0].version $ModelVersion) -or
        -not (Test-CapturePairOrdinal $schema.observed_model_version $ModelVersion) -or
        -not (Test-CapturePairOrdinal $pair.model.version $ModelVersion) -or
        -not (Test-CapturePairOrdinal $canonical.model_version $ModelVersion)) {
        Add-CapturePairFailure 'exact_model_version'
    }

    if (-not (Test-CapturePairOrdinal $pair.run_id $captureRunId) -or
        -not (Test-CapturePairOrdinal $canonical.run_id $captureRunId) -or
        -not (Test-CapturePairOrdinal $pair.corpus_revision $manifest.corpus_revision) -or
        -not (Test-CapturePairOrdinal $canonical.corpus_revision $manifest.corpus_revision) -or
        -not (Test-CapturePairOrdinal $pair.model.name $ModelName) -or
        -not (Test-CapturePairOrdinal $canonical.model_name $ModelName) -or
        -not (Test-CapturePairOrdinal $pair.operator_upn $Operator) -or
        -not (Test-CapturePairOrdinal $manifest.operator $Operator) -or
        -not (Test-CapturePairOrdinal $schema.operator $Operator) -or
        -not (Test-CapturePairOrdinal $pair.source.filename $canonical.filename) -or
        -not (Test-CapturePairOrdinal $pair.source.filename (Split-Path -Leaf $sourcePath))) {
        Add-CapturePairFailure 'exact_correlation'
    }

    if ($raw.responsev2.PSObject.Properties.Name.Contains('run_id') -and
        -not (Test-CapturePairOrdinal $raw.responsev2.run_id $captureRunId)) {
        Add-CapturePairFailure 'exact_correlation'
    }

    $expectedRawProperties = @('@odata.context', 'responsev2')
    $expectedResponseProperties = @('@odata.type', 'operationStatus', 'predictionId', 'predictionOutput')
    $expectedOutputProperties = @(
        '@odata.type',
        'pageCount@odata.type',
        'pageCount',
        'layoutName',
        'layoutConfidenceScore',
        'costAsAiBuilderCredits@odata.type',
        'costAsAiBuilderCredits',
        'costAsCopilotCredits',
        'submitTime@odata.type',
        'submitTime',
        'readResults@odata.type',
        'readResults',
        'tables',
        'labels'
    )
    if (-not (Compare-HrAiBuilderSequence -Left $expectedRawProperties -Right @($raw.PSObject.Properties.Name)) -or
        -not (Compare-HrAiBuilderSequence -Left $expectedResponseProperties -Right @($raw.responsev2.PSObject.Properties.Name | Where-Object { $_ -ne 'run_id' })) -or
        -not (Compare-HrAiBuilderSequence -Left $expectedOutputProperties -Right @($raw.responsev2.predictionOutput.PSObject.Properties.Name)) -or
        -not (Test-CapturePairOrdinal $raw.responsev2.operationStatus 'Success')) {
        Add-CapturePairFailure 'capture_pair_provenance'
    }

    $manifestDocuments = @()
    if ($manifestModels.Count -eq 1) {
        $manifestDocuments = @($manifestModels[0].documents | Where-Object {
            Test-CapturePairOrdinal $_.document $pair.source.filename
        })
    }
    if ($manifestDocuments.Count -ne 1 -or
        -not (Test-CapturePairOrdinal $manifestDocuments[0].sha256 $hashes.source_sha256)) {
        Add-CapturePairFailure 'exact_correlation'
    }

    $contractNames = @($contract.fields | ForEach-Object { [string]$_.name })
    $schemaNames = @($schema.fields | ForEach-Object { [string]$_.name })
    $canonicalNames = @($canonical.fields.PSObject.Properties.Name)
    $labels = $raw.responsev2.predictionOutput.labels
    if (-not $labels) {
        Add-CapturePairFailure 'exact_field_contract'
        return Complete-CapturePairResult -Envelope $canonical -RawPath $rawFiles[0].FullName
    }
    $labelNames = @($labels.PSObject.Properties.Name | Where-Object { $_ -ne '@odata.type' })
    if (-not (Compare-HrAiBuilderSequence -Left $contractNames -Right $schemaNames) -or
        -not (Compare-HrAiBuilderSequence -Left $contractNames -Right $canonicalNames) -or
        $labelNames.Count -ne $contractNames.Count -or
        @($labelNames | Where-Object { -not $contractNames.Contains($_) }).Count -gt 0) {
        Add-CapturePairFailure 'exact_field_contract'
    }

    $projectedFields = [ordered]@{}
    foreach ($fieldName in $contractNames) {
        $labelProperty = $labels.PSObject.Properties[$fieldName]
        $label = if ($labelProperty) { $labelProperty.Value } else { $null }
        if (-not $label) {
            Add-CapturePairFailure 'exact_field_contract'
            continue
        }

        $value = if ($label.PSObject.Properties.Name.Contains('value')) { $label.value } else { $null }
        $confidence = if ($label.PSObject.Properties.Name.Contains('confidence')) { $label.confidence } else { $null }
        $numericConfidence = $confidence -is [byte] -or $confidence -is [int16] -or
            $confidence -is [int32] -or $confidence -is [int64] -or
            $confidence -is [single] -or $confidence -is [double] -or
            $confidence -is [decimal]
        if (($null -ne $value -and -not ($value -is [string])) -or
            ($null -eq $confidence -and $null -ne $value) -or
            ($null -ne $confidence -and (-not $numericConfidence -or [double]$confidence -lt 0 -or [double]$confidence -gt 1))) {
            Add-CapturePairFailure 'prediction_capture_schema'
        }
        $projectedFields[$fieldName] = [ordered]@{ value = $value; confidence = $confidence }
    }

    $replayedEnvelope = [ordered]@{
        schema_version = '1.0'
        run_id = $captureRunId
        corpus_revision = [string]$manifest.corpus_revision
        filename = [string]$pair.source.filename
        claimed_sha256 = [string]$hashes.source_sha256
        model_name = $ModelName
        model_version = $ModelVersion
        captured_at_utc = [string]$pair.captured_at_utc
        fields = $projectedFields
    }
    $replayBytes = ConvertTo-HrAiBuilderCanonicalJson -InputObject $replayedEnvelope
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $hashes.replay_sha256 = ([BitConverter]::ToString($sha.ComputeHash($replayBytes)) -replace '-', '').ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }
    if ($canonicalBytes.Length -ne $replayBytes.Length -or
        [Convert]::ToBase64String($canonicalBytes) -cne [Convert]::ToBase64String($replayBytes)) {
        Add-CapturePairFailure 'adapter_replay'
    }

    $document = [ordered]@{
        document = [string]$pair.source.filename
        document_sha256 = [string]$hashes.source_sha256
        collection_or_family = if ($manifestDocuments.Count -eq 1) {
            [string]$manifestDocuments[0].collection_or_family
        } else {
            ''
        }
        source_export_path = $rawFiles[0].FullName
        source_export_sha256 = [string]$hashes.raw_sha256
        captured_at_utc = [string]$pair.captured_at_utc
        fields = $projectedFields
    }

    return Complete-CapturePairResult -Envelope $replayedEnvelope -Document $document -RawPath $rawFiles[0].FullName
}
