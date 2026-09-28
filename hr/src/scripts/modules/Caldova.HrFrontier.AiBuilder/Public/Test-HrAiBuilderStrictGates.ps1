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
        [object[]]$ValidationRecords
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

    $failedGates = [System.Collections.Generic.List[string]]::new()
    $contractFields = @($FieldContract.fields)
    $contractFieldNames = @($contractFields | ForEach-Object { [string]$_.name })
    $manifestModel = @($RunManifest.models | Where-Object { [string]$_.display_name -eq [string]$PredictionCapture.model_name })

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
    $requiredPredictionProperties = @('schema_version', 'run_id', 'model_name', 'model_version', 'capture_mechanism', 'adapter_version', 'operator', 'documents')
    if ($predictionTopLevelProperties.Count -ne $requiredPredictionProperties.Count -or
        -not (Compare-HrAiBuilderSequence -Left @($requiredPredictionProperties | Sort-Object) -Right @($predictionTopLevelProperties | Sort-Object))) {
        $predictionCaptureSchemaValid = $false
    }
    elseif ([string]$PredictionCapture.schema_version -ne '1.0' -or
        [string]$PredictionCapture.capture_mechanism -ne 'AI Builder Quick Test' -or
        [string]::IsNullOrWhiteSpace([string]$PredictionCapture.run_id) -or
        [string]::IsNullOrWhiteSpace([string]$PredictionCapture.model_name) -or
        [string]::IsNullOrWhiteSpace([string]$PredictionCapture.model_version) -or
        [string]::IsNullOrWhiteSpace([string]$PredictionCapture.adapter_version) -or
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

        if ([string]$ModelSchemaRecord.model_name -ne [string]$PredictionCapture.model_name -or
            [string]$ModelSchemaRecord.model_id -ne $manifestModelId -or
            [string]$PredictionCapture.run_id -ne [string]$RunManifest.run_id -or
            [string]$PredictionCapture.model_version -ne [string]$manifestModel.version) {
            Add-HrAiBuilderFailedGate -FailedGates $failedGates -Gate 'complete_attribution'
        }

        foreach ($row in @($ValidationRecords)) {
            if ([string]$row.run_id -ne [string]$PredictionCapture.run_id -or
                [string]$row.model_name -ne [string]$PredictionCapture.model_name -or
                [string]$row.model_version -ne [string]$PredictionCapture.model_version) {
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
