param(
    [Parameter(Mandatory)][string]$RunManifestPath,
    [Parameter(Mandatory)][string]$CorpusQualityPath,
    [Parameter(Mandatory)][string]$FieldContractPath,
    [Parameter(Mandatory)][string]$ModelSchemaRecordPath,
    [Parameter(Mandatory)][string]$PredictionCapturePath,
    [Parameter(Mandatory)][string]$GroundTruthPath,
    [Parameter(Mandatory)][string]$EvidenceDirectory
)

Set-StrictMode -Version Latest

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleManifestPath = Join-Path $scriptRoot 'modules\Caldova.HrFrontier.AiBuilder\Caldova.HrFrontier.AiBuilder.psd1'
Import-Module $moduleManifestPath -Force

function Read-EvaluationJson {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Description
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "$Description file '$Path' was not found."
    }

    try {
        return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    }
    catch {
        throw "$Description file '$Path' is malformed JSON. $($_.Exception.Message)"
    }
}

function Write-EvaluationJsonAtomically {
    param(
        [Parameter(Mandatory)][object]$InputObject,
        [Parameter(Mandatory)][string]$Path
    )

    $directory = Split-Path -Parent $Path
    if ($directory) {
        New-Item -ItemType Directory -Force -Path $directory | Out-Null
    }

    $temporaryPath = Join-Path $directory ([guid]::NewGuid().ToString() + '.json')
    $InputObject | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $temporaryPath -Encoding UTF8
    Move-Item -LiteralPath $temporaryPath -Destination $Path -Force
}

function Write-EvaluationCsvAtomically {
    param(
        [Parameter(Mandatory)][object[]]$Rows,
        [Parameter(Mandatory)][string]$Path
    )

    $directory = Split-Path -Parent $Path
    if ($directory) {
        New-Item -ItemType Directory -Force -Path $directory | Out-Null
    }

    $temporaryPath = Join-Path $directory ([guid]::NewGuid().ToString() + '.csv')
    $Rows | Export-Csv -LiteralPath $temporaryPath -NoTypeInformation -Encoding UTF8
    Move-Item -LiteralPath $temporaryPath -Destination $Path -Force
}

function Write-EvaluationTextAtomically {
    param(
        [Parameter(Mandatory)][string]$Content,
        [Parameter(Mandatory)][string]$Path
    )

    $directory = Split-Path -Parent $Path
    if ($directory) {
        New-Item -ItemType Directory -Force -Path $directory | Out-Null
    }

    $temporaryPath = Join-Path $directory ([guid]::NewGuid().ToString() + '.md')
    Set-Content -LiteralPath $temporaryPath -Value $Content -Encoding UTF8
    Move-Item -LiteralPath $temporaryPath -Destination $Path -Force
}

function Test-FieldValuePresent {
    param([AllowNull()][object]$Value)

    if ($null -eq $Value) {
        return $false
    }

    return (-not [string]::IsNullOrWhiteSpace([string]$Value))
}

function Test-OrdinalStringEquals {
    param(
        [AllowNull()][object]$Left,
        [AllowNull()][object]$Right
    )

    if ($null -eq $Left -or $null -eq $Right) {
        return ($null -eq $Left -and $null -eq $Right)
    }

    return [string]::Equals([string]$Left, [string]$Right, [System.StringComparison]::Ordinal)
}

function Get-EvaluationCombinedDocument {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$RunId
    )

    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        $existing = Read-EvaluationJson -Path $Path -Description ([IO.Path]::GetFileName($Path))
        if ([string]$existing.run_id -ne $RunId) {
            throw "Evidence file '$Path' belongs to run '$($existing.run_id)', not '$RunId'."
        }

        return $existing
    }

    return [ordered]@{
        schema_version = '1.0'
        run_id = $RunId
        models = @()
    }
}

function Test-EvaluationDuplicateModel {
    param(
        [AllowEmptyCollection()][object[]]$Models,
        [Parameter(Mandatory)][string]$RunId,
        [Parameter(Mandatory)][string]$ModelName,
        [Parameter(Mandatory)][string]$ModelVersion
    )

    foreach ($model in $Models) {
        if ([string]$model.run_id -eq $RunId -and
            [string]$model.model_name -eq $ModelName -and
            [string]$model.model_version -eq $ModelVersion) {
            return $true
        }
    }

    return $false
}

function New-EvaluationSummaryContent {
    param(
        [Parameter(Mandatory)][string]$Status,
        [Parameter(Mandatory)][string]$RunId,
        [Parameter(Mandatory)][string]$ModelName,
        [Parameter(Mandatory)][string]$ModelVersion,
        [string[]]$FailedGates = @(),
        [Parameter(Mandatory)][hashtable]$EvidencePaths
    )

    $failedGatesText = if ($FailedGates.Count -gt 0) {
        ($FailedGates | ForEach-Object { "- $_" }) -join "`n"
    }
    else {
        '- None'
    }

    return @(
        '# AI Builder evaluation summary'
        ''
        ('- Status: {0}' -f $Status)
        ('- Run ID: {0}' -f $RunId)
        ('- Model: {0}' -f $ModelName)
        ('- Model version: {0}' -f $ModelVersion)
        ''
        '## Failed gates'
        $failedGatesText
        ''
        '## Evidence paths'
        ('- Validation CSV: {0}' -f $EvidencePaths.ValidationCsv)
        ('- Validation JSON: {0}' -f $EvidencePaths.ValidationJson)
        ('- Metrics JSON: {0}' -f $EvidencePaths.MetricsJson)
        ('- Prediction capture: {0}' -f $EvidencePaths.PredictionCapture)
        ('- Run manifest: {0}' -f $EvidencePaths.RunManifest)
        ('- Corpus quality: {0}' -f $EvidencePaths.CorpusQuality)
        ('- Model schema record: {0}' -f $EvidencePaths.ModelSchemaRecord)
        ('- Ground truth: {0}' -f $EvidencePaths.GroundTruth)
    ) -join "`r`n"
}

try {
    $runManifest = Read-EvaluationJson -Path $RunManifestPath -Description 'Run manifest'
    $corpusQuality = Read-EvaluationJson -Path $CorpusQualityPath -Description 'Corpus quality'
    $fieldContractDocument = Read-EvaluationJson -Path $FieldContractPath -Description 'Field contract'
    $modelSchemaRecord = Read-EvaluationJson -Path $ModelSchemaRecordPath -Description 'Model schema record'
    $predictionCapture = Read-EvaluationJson -Path $PredictionCapturePath -Description 'Prediction capture'
    $groundTruth = Read-EvaluationJson -Path $GroundTruthPath -Description 'Ground truth'
    $fieldContract = @(Get-HrAiBuilderFieldContract -Path $FieldContractPath)

    $manifestModel = @($runManifest.models | Where-Object { [string]$_.display_name -ceq [string]$predictionCapture.model_name })
    if ($manifestModel.Count -ne 1) {
        throw "Run manifest does not contain exactly one model record for '$($predictionCapture.model_name)'."
    }

    $manifestModel = $manifestModel[0]
    $heldOutDocuments = @($manifestModel.documents | Where-Object { [string]$_.assignment -eq 'held-out' })
    $groundTruthByDocument = @{}
    foreach ($document in @($groundTruth.documents)) {
        $groundTruthByDocument[[string]$document.document] = $document
    }

    $validationRecords = @()
    foreach ($captureDocument in @($predictionCapture.documents)) {
        $groundTruthRow = $groundTruthByDocument[[string]$captureDocument.document]
        if (-not $groundTruthRow) {
            throw "Ground truth does not contain document '$($captureDocument.document)'."
        }

        foreach ($field in $fieldContract) {
            $expectedRaw = if (Test-FieldValuePresent -Value $groundTruthRow.($field.name)) {
                [string]$groundTruthRow.($field.name)
            }
            else {
                $null
            }
            $actualField = $captureDocument.fields.($field.name)
            $actualRaw = if ($actualField -and (Test-FieldValuePresent -Value $actualField.value)) {
                [string]$actualField.value
            }
            else {
                $null
            }

            $expectedPresent = ($null -ne $expectedRaw)
            $actualPresent = ($null -ne $actualRaw)
            $expectedNormalized = if ($expectedPresent) {
                ConvertTo-HrAiBuilderNormalizedValue -Value $expectedRaw -FieldType $field.ai_builder_type
            }
            else {
                $null
            }

            $actualNormalized = $null
            $actualInvalidFormat = $false
            if ($actualPresent) {
                try {
                    $actualNormalized = ConvertTo-HrAiBuilderNormalizedValue -Value $actualRaw -FieldType $field.ai_builder_type
                }
                catch {
                    if ([string]$field.ai_builder_type -eq 'Date') {
                        $actualInvalidFormat = $true
                    }
                    else {
                        throw
                    }
                }
            }

            $errorClass = $null
            $exactMatch = $false
            if (-not $expectedPresent -and $actualPresent) {
                $errorClass = 'false_value'
            }
            elseif ($expectedPresent -and -not $actualPresent) {
                $errorClass = 'missing'
            }
            elseif ($expectedPresent -and $actualPresent -and $actualInvalidFormat) {
                $errorClass = 'invalid_format'
            }
            elseif ($expectedPresent -and $actualPresent -and -not (Test-OrdinalStringEquals -Left $expectedNormalized -Right $actualNormalized)) {
                $errorClass = 'incorrect'
            }
            else {
                $exactMatch = $true
            }

            $validationRecords += [pscustomobject]@{
                run_id = [string]$predictionCapture.run_id
                model_name = [string]$predictionCapture.model_name
                model_version = [string]$predictionCapture.model_version
                document = [string]$captureDocument.document
                collection_or_family = [string]$groundTruthRow.collection_or_layout
                field_name = [string]$field.name
                field_type = [string]$field.ai_builder_type
                expected_raw = $expectedRaw
                actual_raw = $actualRaw
                expected_normalized = $expectedNormalized
                actual_normalized = $actualNormalized
                confidence = if ($actualField) { $actualField.confidence } else { $null }
                expected_present = $expectedPresent
                actual_present = $actualPresent
                exact_match = $exactMatch
                error_class = $errorClass
            }
        }
    }

    $metrics = Measure-HrAiBuilderEvaluation -ValidationRecords $validationRecords
    $strictGates = Test-HrAiBuilderStrictGates `
        -CorpusQualification $corpusQuality `
        -FieldContract $fieldContractDocument `
        -ModelSchemaRecord $modelSchemaRecord `
        -RunManifest $runManifest `
        -PredictionCapture $predictionCapture `
        -ValidationRecords $validationRecords

    New-Item -ItemType Directory -Force -Path $EvidenceDirectory | Out-Null
    $modelSuffix = if ([string]$manifestModel.model_kind -eq 'Fixed') { 'fixed' } else { 'general' }
    $validationCsvPath = Join-Path $EvidenceDirectory ("validation-results-{0}.csv" -f $modelSuffix)
    $validationJsonPath = Join-Path $EvidenceDirectory 'validation-results.json'
    $metricsJsonPath = Join-Path $EvidenceDirectory 'evaluation-metrics.json'
    $summaryPath = Join-Path $EvidenceDirectory 'evaluation-summary.md'

    $existingValidationResults = Get-EvaluationCombinedDocument -Path $validationJsonPath -RunId ([string]$predictionCapture.run_id)
    if (Test-EvaluationDuplicateModel -Models @($existingValidationResults.models) `
            -RunId ([string]$predictionCapture.run_id) `
            -ModelName ([string]$predictionCapture.model_name) `
            -ModelVersion ([string]$predictionCapture.model_version)) {
        throw "Validation results for run '$($predictionCapture.run_id)', model '$($predictionCapture.model_name)', version '$($predictionCapture.model_version)' already exists."
    }

    $existingMetrics = Get-EvaluationCombinedDocument -Path $metricsJsonPath -RunId ([string]$predictionCapture.run_id)
    if (Test-EvaluationDuplicateModel -Models @($existingMetrics.models) `
            -RunId ([string]$predictionCapture.run_id) `
            -ModelName ([string]$predictionCapture.model_name) `
            -ModelVersion ([string]$predictionCapture.model_version)) {
        throw "Evaluation metrics for run '$($predictionCapture.run_id)', model '$($predictionCapture.model_name)', version '$($predictionCapture.model_version)' already exists."
    }

    $validationEntry = [ordered]@{
        run_id = [string]$predictionCapture.run_id
        model_name = [string]$predictionCapture.model_name
        model_version = [string]$predictionCapture.model_version
        validation_record_count = $validationRecords.Count
        csv_path = $validationCsvPath
        records = @($validationRecords)
    }
    $existingValidationResults.models = @($existingValidationResults.models + $validationEntry)

    $metricsEntry = [ordered]@{
        run_id = [string]$predictionCapture.run_id
        display_name = [string]$predictionCapture.model_name
        model_name = [string]$predictionCapture.model_name
        model_version = [string]$predictionCapture.model_version
        strict_gate_disposition = [string]$strictGates.strict_gate_disposition
        failed_gates = @($strictGates.failed_gates)
        expected_validation_record_count = $strictGates.expected_validation_record_count
        actual_validation_record_count = $strictGates.actual_validation_record_count
        exact_match_accuracy = $metrics.exact_match_accuracy
        precision = $metrics.precision
        recall = $metrics.recall
        missing_field_precision = $metrics.missing_field_precision
        false_value_rate = $metrics.false_value_rate
        false_value_count = $metrics.false_value_count
        quality_finding_count = $metrics.quality_finding_count
        confidence_distribution = @($metrics.confidence_distribution)
        by_field = @($metrics.by_field)
        by_collection_or_family = @($metrics.by_collection_or_family)
    }
    $existingMetrics.models = @($existingMetrics.models + $metricsEntry)

    Write-EvaluationCsvAtomically -Rows $validationRecords -Path $validationCsvPath
    Write-EvaluationJsonAtomically -InputObject $existingValidationResults -Path $validationJsonPath
    Write-EvaluationJsonAtomically -InputObject $existingMetrics -Path $metricsJsonPath

    $summaryStatus = if ($strictGates.status -eq 'evaluated') { 'Evaluated' } else { 'Blocked' }
    $summaryContent = New-EvaluationSummaryContent `
        -Status $summaryStatus `
        -RunId ([string]$predictionCapture.run_id) `
        -ModelName ([string]$predictionCapture.model_name) `
        -ModelVersion ([string]$predictionCapture.model_version) `
        -FailedGates @($strictGates.failed_gates) `
        -EvidencePaths @{
            ValidationCsv = $validationCsvPath
            ValidationJson = $validationJsonPath
            MetricsJson = $metricsJsonPath
            PredictionCapture = $PredictionCapturePath
            RunManifest = $RunManifestPath
            CorpusQuality = $CorpusQualityPath
            ModelSchemaRecord = $ModelSchemaRecordPath
            GroundTruth = $GroundTruthPath
        }
    Write-EvaluationTextAtomically -Content $summaryContent -Path $summaryPath

    if ([string]$strictGates.status -eq 'blocked') {
        $failedGateSummary = if (@($strictGates.failed_gates).Count -gt 0) {
            $strictGates.failed_gates -join ', '
        }
        else {
            'unknown'
        }

        Write-Error "Evaluation blocked for '$($predictionCapture.model_name)'. Failed gates: $failedGateSummary."
        exit 1
    }

    Write-Output "Evaluation completed for '$($predictionCapture.model_name)'."
    exit 0
}
catch {
    if (-not (Test-Path -LiteralPath $EvidenceDirectory -PathType Container)) {
        New-Item -ItemType Directory -Force -Path $EvidenceDirectory | Out-Null
    }

    $summaryPath = Join-Path $EvidenceDirectory 'evaluation-summary.md'
    $summaryContent = @(
        '# AI Builder evaluation summary'
        ''
        '- Status: Blocked'
        ('- Error: {0}' -f $_.Exception.Message)
    ) -join "`r`n"
    Write-EvaluationTextAtomically -Content $summaryContent -Path $summaryPath
    Write-Error $_.Exception.Message
    exit 1
}
