function Test-HrAiBuilderStrictGates {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$CorpusQualification,

        [Parameter(Mandatory)]
        [object]$FieldContract,

        [Parameter(Mandatory)]
        [object]$ModelSchemaRecord,

        [Parameter(Mandatory)]
        [object]$RunManifest,

        [Parameter(Mandatory)]
        [object]$PredictionCapture,

        [Parameter(Mandatory)]
        [object[]]$ValidationRecords,

        [string]$PackageRootPath,

        [string]$EvidenceContextPath
    )

    function Add-HrAiBuilderFailedGate {
        param(
            [AllowEmptyCollection()]
            [System.Collections.Generic.List[string]]$FailedGates,

            [Parameter(Mandatory)]
            [string]$Gate
        )

        if (-not $FailedGates.Contains($Gate)) {
            $FailedGates.Add($Gate)
        }
    }

    function Test-HrAiBuilderPredictionField {
        param(
            [Parameter(Mandatory)]
            [object]$FieldRecord,

            [Parameter(Mandatory)]
            [string]$FieldName
        )

        if (-not $FieldRecord) {
            return $false
        }

        $propertyNames = @($FieldRecord.PSObject.Properties.Name)
        if ($propertyNames.Count -ne 2 -or
            -not $propertyNames.Contains('value') -or
            -not $propertyNames.Contains('confidence')) {
            return $false
        }

        $value = $FieldRecord.value
        $confidence = $FieldRecord.confidence
        if ($null -ne $value -and -not ($value -is [string])) {
            return $false
        }

        if ($null -eq $confidence) {
            return ($null -eq $value)
        }

        if (-not ($confidence -is [double] -or $confidence -is [decimal] -or $confidence -is [single] -or $confidence -is [int])) {
            return $false
        }

        $confidenceValue = [double]$confidence
        if ($confidenceValue -lt 0 -or $confidenceValue -gt 1) {
            return $false
        }

        if ($null -ne $value -and $value -is [string]) {
            return $true
        }

        return $true
    }

    function Test-HrAiBuilderOrdinalEquals {
        param(
            [AllowNull()][object]$Left,
            [AllowNull()][object]$Right
        )

        if ($null -eq $Left -or $null -eq $Right) {
            return ($null -eq $Left -and $null -eq $Right)
        }

        return [string]::Equals([string]$Left, [string]$Right, [System.StringComparison]::Ordinal)
    }

    function Test-HrAiBuilderSupportedAdapterContract {
        param([Parameter(Mandatory)][object]$Capture)

        $legacy = (Test-HrAiBuilderOrdinalEquals $Capture.capture_mechanism 'AI Builder Quick Test') -and
            (Test-HrAiBuilderOrdinalEquals $Capture.adapter_contract 'replayable-v1') -and
            (Test-HrAiBuilderOrdinalEquals $Capture.raw_export_format 'test-fixture-json-v1')
        $observed = (Test-HrAiBuilderOrdinalEquals $Capture.capture_mechanism 'Power Automate Process documents') -and
            (Test-HrAiBuilderOrdinalEquals $Capture.adapter_contract 'replayable-v2') -and
            (Test-HrAiBuilderOrdinalEquals $Capture.raw_export_format 'ai-builder-process-documents-v1')

        return ($legacy -or $observed)
    }

    function Compare-HrAiBuilderPredictionCaptures {
        param(
            [Parameter(Mandatory)]
            [object]$Expected,

            [Parameter(Mandatory)]
            [object]$Actual,

            [Parameter(Mandatory)]
            [string[]]$ContractFieldNames
        )

        foreach ($propertyName in @(
                'schema_version',
                'run_id',
                'model_name',
                'model_version',
                'capture_mechanism',
                'adapter_version',
                'adapter_contract',
                'adapter_script_path',
                'adapter_script_sha256',
                'raw_export_format',
                'operator'
            )) {
            if (-not (Test-HrAiBuilderOrdinalEquals -Left $Expected.$propertyName -Right $Actual.$propertyName)) {
                return $false
            }
        }

        $expectedDocuments = @($Expected.documents)
        $actualDocuments = @($Actual.documents)
        if ($expectedDocuments.Count -ne $actualDocuments.Count) {
            return $false
        }

        $actualDocumentsByName = @{}
        foreach ($document in $actualDocuments) {
            $documentName = [string]$document.document
            if ($actualDocumentsByName.ContainsKey($documentName)) {
                return $false
            }

            $actualDocumentsByName[$documentName] = $document
        }

        foreach ($expectedDocument in $expectedDocuments) {
            $documentName = [string]$expectedDocument.document
            if (-not $actualDocumentsByName.ContainsKey($documentName)) {
                return $false
            }

            $actualDocument = $actualDocumentsByName[$documentName]
            foreach ($documentPropertyName in @(
                    'document',
                    'document_sha256',
                    'collection_or_family',
                    'source_export_path',
                    'source_export_sha256'
                )) {
                if (-not (Test-HrAiBuilderOrdinalEquals -Left $expectedDocument.$documentPropertyName -Right $actualDocument.$documentPropertyName)) {
                    return $false
                }
            }

            $expectedFieldNames = @($expectedDocument.fields.PSObject.Properties.Name)
            $actualFieldNames = @($actualDocument.fields.PSObject.Properties.Name)
            if ($expectedFieldNames.Count -ne $ContractFieldNames.Count -or
                $actualFieldNames.Count -ne $ContractFieldNames.Count -or
                -not (Compare-HrAiBuilderSequence -Left @($ContractFieldNames | Sort-Object) -Right @($expectedFieldNames | Sort-Object)) -or
                -not (Compare-HrAiBuilderSequence -Left @($ContractFieldNames | Sort-Object) -Right @($actualFieldNames | Sort-Object))) {
                return $false
            }

            foreach ($fieldName in $ContractFieldNames) {
                $expectedField = $expectedDocument.fields.$fieldName
                $actualField = $actualDocument.fields.$fieldName
                if (-not (Test-HrAiBuilderOrdinalEquals -Left $expectedField.value -Right $actualField.value)) {
                    return $false
                }

                if ($null -eq $expectedField.confidence -or $null -eq $actualField.confidence) {
                    if ($null -ne $expectedField.confidence -or $null -ne $actualField.confidence) {
                        return $false
                    }

                    continue
                }

                if ([double]$expectedField.confidence -ne [double]$actualField.confidence) {
                    return $false
                }
            }
        }

        return $true
    }

    function Test-HrAiBuilderAdapterReplay {
        param(
            [Parameter(Mandatory)]
            [object]$PredictionCapture,

            [Parameter(Mandatory)]
            [string[]]$ContractFieldNames
        )

        if (-not (Test-HrAiBuilderSupportedAdapterContract -Capture $PredictionCapture)) {
            return $false
        }

        $adapterScriptPath = [string]$PredictionCapture.adapter_script_path
        if ([string]::IsNullOrWhiteSpace($adapterScriptPath)) {
            return $false
        }

        try {
            $actualScriptHash = Get-HrAiBuilderFileSha256 -Path $adapterScriptPath
        }
        catch {
            return $false
        }

        if (-not (Test-HrAiBuilderOrdinalEquals -Left $actualScriptHash -Right $PredictionCapture.adapter_script_sha256)) {
            return $false
        }

        $rawExportDirectories = @(
            $PredictionCapture.documents |
                ForEach-Object { Split-Path -Parent ([string]$_.source_export_path) } |
                Sort-Object -Unique
        )
        if ($rawExportDirectories.Count -ne 1) {
            return $false
        }

        $temporaryReplayPath = Join-Path $rawExportDirectories[0] ([guid]::NewGuid().ToString() + '.replay.json')
        try {
            & $adapterScriptPath `
                -RawExportDirectory $rawExportDirectories[0] `
                -ModelName ([string]$PredictionCapture.model_name) `
                -ModelVersion ([string]$PredictionCapture.model_version) `
                -RunId ([string]$PredictionCapture.run_id) `
                -Operator ([string]$PredictionCapture.operator) `
                -OutputPath $temporaryReplayPath
        }
        catch {
            return $false
        }

        if (-not (Test-Path -LiteralPath $temporaryReplayPath -PathType Leaf)) {
            return $false
        }

        try {
            $replayedCapture = Read-HrAiBuilderJson -Path $temporaryReplayPath -Description 'Replayed prediction capture'
            Set-HrAiBuilderPredictionCaptureAdapterMetadata -PredictionCapture $replayedCapture -AdapterScriptPath $adapterScriptPath | Out-Null
        }
        catch {
            return $false
        }
        finally {
            if (Test-Path -LiteralPath $temporaryReplayPath -PathType Leaf) {
                Remove-Item -LiteralPath $temporaryReplayPath -Force
            }
        }

        return (Compare-HrAiBuilderPredictionCaptures -Expected $PredictionCapture -Actual $replayedCapture -ContractFieldNames $ContractFieldNames)
    }

    $failedGates = [System.Collections.Generic.List[string]]::new()
    $contractFields = @($FieldContract.fields)
    $contractFieldNames = @($contractFields | ForEach-Object { [string]$_.name })
    $manifestModel = @($RunManifest.models | Where-Object { [string]$_.display_name -ceq [string]$PredictionCapture.model_name })

    $corpusStatusPassed = $false
    if ($CorpusQualification.PSObject.Properties.Name.Contains('status')) {
        $corpusStatusPassed = ([string]$CorpusQualification.status -eq 'passed')
    }
    elseif ($CorpusQualification.PSObject.Properties.Name.Contains('passed')) {
        $corpusStatusPassed = [bool]$CorpusQualification.passed
    }

    if (-not $corpusStatusPassed) {
        Add-HrAiBuilderFailedGate -FailedGates $failedGates -Gate 'corpus_qualification'
    }

    $schemaFields = @($ModelSchemaRecord.fields)
    $schemaFieldPairs = @($schemaFields | ForEach-Object { '{0}:{1}' -f [string]$_.name, [string]$_.ai_builder_type })
    $contractFieldPairs = @($contractFields | ForEach-Object { '{0}:{1}' -f [string]$_.name, [string]$_.ai_builder_type })
    if ($schemaFields.Count -ne 17 -or -not (Compare-HrAiBuilderSequence -Left $schemaFieldPairs -Right $contractFieldPairs)) {
        Add-HrAiBuilderFailedGate -FailedGates $failedGates -Gate 'exact_field_contract'
    }

    $predictionCaptureSchemaValid = $true
    $predictionTopLevelProperties = @($PredictionCapture.PSObject.Properties.Name)
    $requiredPredictionProperties = @('schema_version', 'run_id', 'model_name', 'model_version', 'capture_mechanism', 'adapter_version', 'adapter_contract', 'adapter_script_path', 'adapter_script_sha256', 'raw_export_format', 'operator', 'documents')
    if ($predictionTopLevelProperties.Count -ne $requiredPredictionProperties.Count -or
        -not (Compare-HrAiBuilderSequence -Left @($requiredPredictionProperties | Sort-Object) -Right @($predictionTopLevelProperties | Sort-Object))) {
        $predictionCaptureSchemaValid = $false
    }
    elseif ([string]$PredictionCapture.schema_version -ne '1.0' -or
        -not (Test-HrAiBuilderSupportedAdapterContract -Capture $PredictionCapture) -or
        [string]::IsNullOrWhiteSpace([string]$PredictionCapture.run_id) -or
        [string]::IsNullOrWhiteSpace([string]$PredictionCapture.model_name) -or
        [string]::IsNullOrWhiteSpace([string]$PredictionCapture.model_version) -or
        [string]::IsNullOrWhiteSpace([string]$PredictionCapture.adapter_version) -or
        [string]::IsNullOrWhiteSpace([string]$PredictionCapture.adapter_script_path) -or
        [string]$PredictionCapture.adapter_script_sha256 -notmatch '^[a-f0-9]{64}$' -or
        [string]::IsNullOrWhiteSpace([string]$PredictionCapture.operator)) {
        $predictionCaptureSchemaValid = $false
    }

    $captureDocuments = @($PredictionCapture.documents)
    if ($captureDocuments.Count -eq 0) {
        $predictionCaptureSchemaValid = $false
    }

    foreach ($document in $captureDocuments) {
        $documentPropertyNames = @($document.PSObject.Properties.Name)
        $requiredDocumentProperties = @('document', 'document_sha256', 'collection_or_family', 'source_export_path', 'source_export_sha256', 'captured_at_utc', 'fields')
        if ($documentPropertyNames.Count -ne $requiredDocumentProperties.Count -or
            -not (Compare-HrAiBuilderSequence -Left @($requiredDocumentProperties | Sort-Object) -Right @($documentPropertyNames | Sort-Object))) {
            $predictionCaptureSchemaValid = $false
            continue
        }

        if ([string]::IsNullOrWhiteSpace([string]$document.document) -or
            [string]$document.document_sha256 -notmatch '^[a-f0-9]{64}$' -or
            [string]::IsNullOrWhiteSpace([string]$document.collection_or_family) -or
            [string]::IsNullOrWhiteSpace([string]$document.source_export_path) -or
            [string]$document.source_export_sha256 -notmatch '^[a-f0-9]{64}$') {
            $predictionCaptureSchemaValid = $false
        }

        try {
            [void][datetime]::Parse([string]$document.captured_at_utc, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)
        }
        catch {
            $predictionCaptureSchemaValid = $false
        }

        $fieldMap = $document.fields
        if (-not $fieldMap) {
            $predictionCaptureSchemaValid = $false
            continue
        }

        $fieldNames = @($fieldMap.PSObject.Properties.Name)
        if ($fieldNames.Count -ne $contractFieldNames.Count -or
            -not (Compare-HrAiBuilderSequence -Left @($contractFieldNames | Sort-Object) -Right @($fieldNames | Sort-Object))) {
            $predictionCaptureSchemaValid = $false
            continue
        }

        foreach ($fieldName in $contractFieldNames) {
            if (-not (Test-HrAiBuilderPredictionField -FieldRecord $fieldMap.$fieldName -FieldName $fieldName)) {
                $predictionCaptureSchemaValid = $false
            }
        }
    }

    if (-not $predictionCaptureSchemaValid) {
        Add-HrAiBuilderFailedGate -FailedGates $failedGates -Gate 'prediction_capture_schema'
    }

    $isObservedCapture = Test-HrAiBuilderOrdinalEquals $PredictionCapture.adapter_contract 'replayable-v2'
    if ($isObservedCapture) {
        $capturePairProvenancePassed = $true
        $canonicalSerializationPassed = $true
        foreach ($document in $captureDocuments) {
            $captureDirectory = Split-Path -Parent ([string]$document.source_export_path)
            $pairPath = Join-Path $captureDirectory 'capture-pair.json'
            $canonicalFiles = @(Get-ChildItem -LiteralPath $captureDirectory -Filter '*.canonical.json' -File -ErrorAction SilentlyContinue)
            if (-not (Test-Path -LiteralPath $pairPath -PathType Leaf) -or $canonicalFiles.Count -ne 1) {
                $capturePairProvenancePassed = $false
                $canonicalSerializationPassed = $false
                continue
            }

            try {
                $pair = Read-HrAiBuilderJson -Path $pairPath -Description 'Capture pair'
                if (-not (Test-HrAiBuilderOrdinalEquals (Get-HrAiBuilderFileSha256 -Path $document.source_export_path) $document.source_export_sha256) -or
                    -not (Test-HrAiBuilderOrdinalEquals (Get-HrAiBuilderFileSha256 -Path $document.source_export_path) $pair.raw.sha256) -or
                    -not (Test-HrAiBuilderOrdinalEquals (Get-HrAiBuilderFileSha256 -Path $canonicalFiles[0].FullName) $pair.canonical.sha256)) {
                    $capturePairProvenancePassed = $false
                }

                $canonicalBytes = [IO.File]::ReadAllBytes($canonicalFiles[0].FullName)
                $hasBom = $canonicalBytes.Length -ge 3 -and
                    $canonicalBytes[0] -eq 0xEF -and $canonicalBytes[1] -eq 0xBB -and $canonicalBytes[2] -eq 0xBF
                $terminalLfCount = 0
                for ($index = $canonicalBytes.Length - 1; $index -ge 0 -and $canonicalBytes[$index] -eq 0x0A; $index--) {
                    $terminalLfCount++
                }
                if ($hasBom -or $terminalLfCount -ne 1 -or $canonicalBytes -contains 0x0D) {
                    $canonicalSerializationPassed = $false
                }
            }
            catch {
                $capturePairProvenancePassed = $false
                $canonicalSerializationPassed = $false
            }
        }
        if (-not $capturePairProvenancePassed) {
            Add-HrAiBuilderFailedGate -FailedGates $failedGates -Gate 'capture_pair_provenance'
        }
        if (-not $canonicalSerializationPassed) {
            Add-HrAiBuilderFailedGate -FailedGates $failedGates -Gate 'canonical_serialization'
        }

        if ($manifestModel.Count -ne 1 -or
            -not (Test-HrAiBuilderOrdinalEquals $PredictionCapture.run_id $RunManifest.run_id) -or
            -not (Test-HrAiBuilderOrdinalEquals $PredictionCapture.model_name $ModelSchemaRecord.model_name) -or
            -not (Test-HrAiBuilderOrdinalEquals $PredictionCapture.operator $RunManifest.operator)) {
            Add-HrAiBuilderFailedGate -FailedGates $failedGates -Gate 'exact_correlation'
        }
        if ($manifestModel.Count -ne 1 -or
            -not (Test-HrAiBuilderOrdinalEquals $PredictionCapture.model_version $manifestModel[0].version) -or
            -not (Test-HrAiBuilderOrdinalEquals $PredictionCapture.model_version $ModelSchemaRecord.observed_model_version)) {
            Add-HrAiBuilderFailedGate -FailedGates $failedGates -Gate 'exact_model_version'
        }
    }

    if ($predictionCaptureSchemaValid -and -not (Test-HrAiBuilderAdapterReplay -PredictionCapture $PredictionCapture -ContractFieldNames $contractFieldNames)) {
        Add-HrAiBuilderFailedGate -FailedGates $failedGates -Gate 'adapter_replay'
    }

    if ($manifestModel.Count -ne 1) {
        Add-HrAiBuilderFailedGate -FailedGates $failedGates -Gate 'complete_attribution'
    }
    else {
        $manifestModel = $manifestModel[0]
        $manifestModelId = if ($manifestModel.PSObject.Properties.Name.Contains('model_id')) {
            [string]$manifestModel.model_id
        }
        elseif ($manifestModel.PSObject.Properties.Name.Contains('id')) {
            [string]$manifestModel.id
        }
        else {
            ''
        }

        if (-not (Test-HrAiBuilderOrdinalEquals -Left $ModelSchemaRecord.model_name -Right $PredictionCapture.model_name) -or
            -not (Test-HrAiBuilderOrdinalEquals -Left $ModelSchemaRecord.model_id -Right $manifestModelId) -or
            -not (Test-HrAiBuilderOrdinalEquals -Left $PredictionCapture.run_id -Right $RunManifest.run_id) -or
            -not (Test-HrAiBuilderOrdinalEquals -Left $PredictionCapture.model_version -Right $manifestModel.version)) {
            Add-HrAiBuilderFailedGate -FailedGates $failedGates -Gate 'complete_attribution'
        }

        foreach ($row in @($ValidationRecords)) {
            if (-not (Test-HrAiBuilderOrdinalEquals -Left $row.run_id -Right $PredictionCapture.run_id) -or
                -not (Test-HrAiBuilderOrdinalEquals -Left $row.model_name -Right $PredictionCapture.model_name) -or
                -not (Test-HrAiBuilderOrdinalEquals -Left $row.model_version -Right $PredictionCapture.model_version)) {
                Add-HrAiBuilderFailedGate -FailedGates $failedGates -Gate 'complete_attribution'
                break
            }
        }
    }

    $heldOutDocuments = @()
    if ($manifestModel -and $manifestModel.PSObject.Properties.Name.Contains('documents')) {
        $heldOutDocuments = @($manifestModel.documents | Where-Object { [string]$_.assignment -eq 'held-out' })
    }

    $heldOutByDocument = @{}
    foreach ($document in $heldOutDocuments) {
        $heldOutByDocument[[string]$document.document] = $document
    }

    $captureDocumentNames = @($captureDocuments | ForEach-Object { [string]$_.document })
    $heldOutDocumentNames = @($heldOutDocuments | ForEach-Object { [string]$_.document })
    if (@($captureDocumentNames | Group-Object | Where-Object Count -gt 1).Count -gt 0 -or
        $captureDocumentNames.Count -ne $heldOutDocumentNames.Count -or
        -not (Compare-HrAiBuilderSequence -Left @($captureDocumentNames | Sort-Object) -Right @($heldOutDocumentNames | Sort-Object))) {
        Add-HrAiBuilderFailedGate -FailedGates $failedGates -Gate 'held_out_document_coverage'
    }

    $heldOutInputProvenanceFailed = $false
    foreach ($document in $heldOutDocuments) {
        $sourcePath = if ($document.PSObject.Properties.Name.Contains('source_path')) {
            [string]$document.source_path
        }
        else {
            ''
        }

        if ([string]::IsNullOrWhiteSpace($sourcePath)) {
            $heldOutInputProvenanceFailed = $true
            continue
        }

        try {
            $resolvedSourcePath = Resolve-HrAiBuilderEvidenceLocator -Locator $sourcePath -RootPath $PackageRootPath -Description "Held-out input PDF for '$([string]$document.document)'"
            $inputHash = Get-HrAiBuilderFileSha256 -Path $resolvedSourcePath
            if (-not (Test-HrAiBuilderOrdinalEquals -Left $inputHash -Right $document.sha256)) {
                $heldOutInputProvenanceFailed = $true
            }
        }
        catch {
            $heldOutInputProvenanceFailed = $true
        }
    }

    if ($heldOutInputProvenanceFailed) {
        Add-HrAiBuilderFailedGate -FailedGates $failedGates -Gate 'held_out_input_provenance'
    }

    $schemaSourceProvenanceFailed = $false
    try {
        $resolvedSchemaEvidencePath = Resolve-HrAiBuilderEvidenceLocator -Locator ([string]$ModelSchemaRecord.source_evidence_path) -RootPath $EvidenceContextPath -Description 'Model schema source evidence'
        $schemaEvidenceHash = Get-HrAiBuilderFileSha256 -Path $resolvedSchemaEvidencePath
        if (-not (Test-HrAiBuilderOrdinalEquals -Left $schemaEvidenceHash -Right $ModelSchemaRecord.source_evidence_sha256)) {
            $schemaSourceProvenanceFailed = $true
        }
    }
    catch {
        $schemaSourceProvenanceFailed = $true
    }

    if ($schemaSourceProvenanceFailed) {
        Add-HrAiBuilderFailedGate -FailedGates $failedGates -Gate 'schema_source_provenance'
    }

    $rawExportProvenanceFailed = $false
    foreach ($document in $captureDocuments) {
        $heldOutDocument = $heldOutByDocument[[string]$document.document]
        if (-not $heldOutDocument -or [string]$heldOutDocument.sha256 -ne [string]$document.document_sha256) {
            $rawExportProvenanceFailed = $true
            continue
        }

        try {
            $sourceHash = Get-HrAiBuilderFileSha256 -Path ([string]$document.source_export_path)
            if ($sourceHash -ne [string]$document.source_export_sha256) {
                $rawExportProvenanceFailed = $true
            }
        }
        catch {
            $rawExportProvenanceFailed = $true
        }
    }

    if ($rawExportProvenanceFailed) {
        Add-HrAiBuilderFailedGate -FailedGates $failedGates -Gate 'raw_export_provenance'
    }

    $expectedValidationRecordCount = $heldOutDocuments.Count * 17
    $actualValidationRecordCount = @($ValidationRecords).Count
    if ($actualValidationRecordCount -ne $expectedValidationRecordCount) {
        Add-HrAiBuilderFailedGate -FailedGates $failedGates -Gate 'result_count'
    }

    $expectedDocumentFieldKeys = @(
        foreach ($documentName in $heldOutDocumentNames) {
            foreach ($fieldName in $contractFieldNames) {
                '{0}|{1}' -f $documentName, $fieldName
            }
        }
    )
    $actualDocumentFieldKeys = @(
        $ValidationRecords |
            ForEach-Object { '{0}|{1}' -f ([string]$_.document), ([string]$_.field_name) }
    )
    $uniqueActualDocumentFieldKeys = @($actualDocumentFieldKeys | Sort-Object -Unique)
    if ($actualDocumentFieldKeys.Count -ne $expectedDocumentFieldKeys.Count -or
        $uniqueActualDocumentFieldKeys.Count -ne $expectedDocumentFieldKeys.Count -or
        -not (Compare-HrAiBuilderSequence -Left @($expectedDocumentFieldKeys | Sort-Object) -Right $uniqueActualDocumentFieldKeys)) {
        Add-HrAiBuilderFailedGate -FailedGates $failedGates -Gate 'document_field_coverage'
    }

    if (@($ValidationRecords | Where-Object { $_.error_class -eq 'false_value' }).Count -gt 0) {
        Add-HrAiBuilderFailedGate -FailedGates $failedGates -Gate 'zero_false_values'
    }

    $qualityFindingCount = @(
        $ValidationRecords |
            Where-Object { $_.error_class -in @('missing', 'incorrect', 'invalid_format') }
    ).Count

    $status = if ($failedGates.Count -eq 0) { 'evaluated' } else { 'blocked' }
    return [pscustomobject]([ordered]@{
            model_name = [string]$PredictionCapture.model_name
            model_version = [string]$PredictionCapture.model_version
            status = $status
            strict_gate_disposition = $status
            failed_gates = @($failedGates)
            expected_validation_record_count = $expectedValidationRecordCount
            actual_validation_record_count = $actualValidationRecordCount
            quality_finding_count = $qualityFindingCount
        })
}
