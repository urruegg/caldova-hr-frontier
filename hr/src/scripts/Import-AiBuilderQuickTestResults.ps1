param(
    [Parameter(Mandatory)][string]$RunManifestPath,
    [Parameter(Mandatory)][string]$ModelSchemaRecordPath,
    [Parameter(Mandatory)][string]$RawExportDirectory,
    [Parameter(Mandatory)][string]$AdapterScriptPath,
    [Parameter(Mandatory)][ValidateSet('PersonalMasterDataFixed', 'PersonalMasterDataGeneral')][string]$TargetModelName,
    [Parameter(Mandatory)][string]$OutputPath
)

Set-StrictMode -Version Latest

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleManifestPath = Join-Path $scriptRoot 'modules\Caldova.HrFrontier.AiBuilder\Caldova.HrFrontier.AiBuilder.psd1'
Import-Module $moduleManifestPath -Force
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $scriptRoot '..\..\..'))
$fieldContractPath = Join-Path $repositoryRoot 'hr\src\ai-builder\contracts\field-contract.json'

function Read-ImportJson {
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

function Move-ImportTempFile {
    param(
        [Parameter(Mandatory)][string]$SourcePath,
        [Parameter(Mandatory)][string]$DestinationPath
    )

    $destinationDirectory = Split-Path -Parent $DestinationPath
    if ($destinationDirectory) {
        New-Item -ItemType Directory -Force -Path $destinationDirectory | Out-Null
    }

    Move-Item -LiteralPath $SourcePath -Destination $DestinationPath -Force
}

function Get-ImportSummaryPath {
    param(
        [Parameter(Mandatory)][string]$OutputPath
    )

    return Join-Path (Split-Path -Parent $OutputPath) 'prediction-capture-summary.md'
}

function Get-ImportFileSha256 {
    param(
        [Parameter(Mandatory)][string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "File '$Path' was not found."
    }

    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Test-ImportSequenceEqual {
    param(
        [Parameter(Mandatory)][object[]]$Left,
        [Parameter(Mandatory)][object[]]$Right
    )

    if ($Left.Count -ne $Right.Count) {
        return $false
    }

    for ($index = 0; $index -lt $Left.Count; $index++) {
        if (-not [string]::Equals([string]$Left[$index], [string]$Right[$index], [System.StringComparison]::Ordinal)) {
            return $false
        }
    }

    return $true
}

function Test-ImportPredictionCaptureField {
    param(
        [Parameter(Mandatory)][object]$FieldRecord
    )

    $propertyNames = @($FieldRecord.PSObject.Properties.Name)
    if ($propertyNames.Count -ne 2 -or -not $propertyNames.Contains('value') -or -not $propertyNames.Contains('confidence')) {
        return $false
    }

    if ($null -ne $FieldRecord.value -and -not ($FieldRecord.value -is [string])) {
        return $false
    }

    if ($null -eq $FieldRecord.confidence) {
        return ($null -eq $FieldRecord.value)
    }

    if (-not ($FieldRecord.confidence -is [double] -or $FieldRecord.confidence -is [decimal] -or $FieldRecord.confidence -is [single] -or $FieldRecord.confidence -is [int])) {
        return $false
    }

    $confidenceValue = [double]$FieldRecord.confidence
    return ($confidenceValue -ge 0 -and $confidenceValue -le 1)
}

function New-ImportBlockedSummaryContent {
    param(
        [Parameter(Mandatory)][string]$Reason,
        [Parameter(Mandatory)][hashtable]$EvidencePaths
    )

    return @(
        '# AI Builder prediction capture summary'
        ''
        '- Status: Blocked'
        ('- Reason: {0}' -f $Reason)
        ''
        '## Evidence paths'
        ('- Run manifest: {0}' -f $EvidencePaths.RunManifest)
        ('- Model schema record: {0}' -f $EvidencePaths.ModelSchemaRecord)
        ('- Raw export directory: {0}' -f $EvidencePaths.RawExportDirectory)
        ('- Adapter script: {0}' -f $EvidencePaths.AdapterScript)
        ('- Prediction capture output: {0}' -f $EvidencePaths.OutputPath)
        ('- Blocked capture: {0}' -f $EvidencePaths.BlockedCapture)
    ) -join "`r`n"
}

function Write-ImportBlockedSummary {
    param(
        [Parameter(Mandatory)][string]$SummaryPath,
        [Parameter(Mandatory)][string]$Reason,
        [Parameter(Mandatory)][hashtable]$EvidencePaths
    )

    $summaryDirectory = Split-Path -Parent $SummaryPath
    if ($summaryDirectory) {
        New-Item -ItemType Directory -Force -Path $summaryDirectory | Out-Null
    }

    Set-Content -LiteralPath $SummaryPath -Value (New-ImportBlockedSummaryContent -Reason $Reason -EvidencePaths $EvidencePaths) -Encoding UTF8
}

function Test-ImportOrdinalEquals {
    param(
        [AllowNull()][object]$Left,
        [AllowNull()][object]$Right
    )

    if ($null -eq $Left -or $null -eq $Right) {
        return ($null -eq $Left -and $null -eq $Right)
    }

    return [string]::Equals([string]$Left, [string]$Right, [System.StringComparison]::Ordinal)
}

function Set-ImportCaptureAdapterMetadata {
    param(
        [Parameter(Mandatory)][object]$PredictionCapture,
        [Parameter(Mandatory)][string]$AdapterScriptPath
    )

    $metadataValues = [ordered]@{
        adapter_script_path = $AdapterScriptPath
        adapter_script_sha256 = Get-ImportFileSha256 -Path $AdapterScriptPath
    }

    foreach ($property in $metadataValues.GetEnumerator()) {
        if ($PredictionCapture.PSObject.Properties.Name.Contains($property.Key)) {
            $PredictionCapture.$($property.Key) = $property.Value
        }
        else {
            $PredictionCapture | Add-Member -NotePropertyName $property.Key -NotePropertyValue $property.Value
        }
    }

    return $PredictionCapture
}

function Compare-ImportPredictionCapture {
    param(
        [Parameter(Mandatory)][object]$Expected,
        [Parameter(Mandatory)][object]$Actual,
        [Parameter(Mandatory)][string[]]$FieldNames
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
        if (-not (Test-ImportOrdinalEquals -Left $Expected.$propertyName -Right $Actual.$propertyName)) {
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
            if (-not (Test-ImportOrdinalEquals -Left $expectedDocument.$documentPropertyName -Right $actualDocument.$documentPropertyName)) {
                return $false
            }
        }

        $expectedFieldNames = @($expectedDocument.fields.PSObject.Properties.Name)
        $actualFieldNames = @($actualDocument.fields.PSObject.Properties.Name)
        if ($expectedFieldNames.Count -ne $FieldNames.Count -or
            $actualFieldNames.Count -ne $FieldNames.Count -or
            -not (Test-ImportSequenceEqual -Left @($FieldNames | Sort-Object) -Right @($expectedFieldNames | Sort-Object)) -or
            -not (Test-ImportSequenceEqual -Left @($FieldNames | Sort-Object) -Right @($actualFieldNames | Sort-Object))) {
            return $false
        }

        foreach ($fieldName in $FieldNames) {
            $expectedField = $expectedDocument.fields.$fieldName
            $actualField = $actualDocument.fields.$fieldName
            if (-not (Test-ImportOrdinalEquals -Left $expectedField.value -Right $actualField.value)) {
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

function Test-ImportAdapterReplay {
    param(
        [Parameter(Mandatory)][object]$PredictionCapture,
        [Parameter(Mandatory)][string[]]$FieldNames
    )

    if (-not (Test-ImportOrdinalEquals -Left $PredictionCapture.adapter_contract -Right 'replayable-v1') -or
        -not (Test-ImportOrdinalEquals -Left $PredictionCapture.raw_export_format -Right 'test-fixture-json-v1')) {
        return $false
    }

    $adapterScriptPath = [string]$PredictionCapture.adapter_script_path
    if ([string]::IsNullOrWhiteSpace($adapterScriptPath)) {
        return $false
    }

    if (-not (Test-ImportOrdinalEquals -Left (Get-ImportFileSha256 -Path $adapterScriptPath) -Right $PredictionCapture.adapter_script_sha256)) {
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

    $replayPath = Join-Path $rawExportDirectories[0] ([guid]::NewGuid().ToString() + '.replay.json')
    try {
        & $adapterScriptPath `
            -RawExportDirectory $rawExportDirectories[0] `
            -ModelName ([string]$PredictionCapture.model_name) `
            -ModelVersion ([string]$PredictionCapture.model_version) `
            -RunId ([string]$PredictionCapture.run_id) `
            -Operator ([string]$PredictionCapture.operator) `
            -OutputPath $replayPath
    }
    catch {
        return $false
    }

    if (-not (Test-Path -LiteralPath $replayPath -PathType Leaf)) {
        return $false
    }

    try {
        $replayedCapture = Read-ImportJson -Path $replayPath -Description 'Replayed prediction capture'
        Set-ImportCaptureAdapterMetadata -PredictionCapture $replayedCapture -AdapterScriptPath $adapterScriptPath | Out-Null
    }
    catch {
        return $false
    }
    finally {
        if (Test-Path -LiteralPath $replayPath -PathType Leaf) {
            Remove-Item -LiteralPath $replayPath -Force
        }
    }

    return (Compare-ImportPredictionCapture -Expected $PredictionCapture -Actual $replayedCapture -FieldNames $FieldNames)
}

function Test-ImportPredictionCapture {
    param(
        [Parameter(Mandatory)][object]$PredictionCapture,
        [Parameter(Mandatory)][object]$RunManifest,
        [Parameter(Mandatory)][object]$ModelSchemaRecord,
        [Parameter(Mandatory)][string[]]$FieldNames,
        [Parameter(Mandatory)][string]$TargetModelName
    )

    $manifestModel = @($RunManifest.models | Where-Object { [string]$_.display_name -ceq $TargetModelName })
    if ($manifestModel.Count -ne 1) {
        throw "Run manifest does not contain exactly one model record for '$TargetModelName'."
    }

    $manifestModel = $manifestModel[0]
    $manifestModelId = [string]$manifestModel.model_id
    if ([string]::IsNullOrWhiteSpace($manifestModelId)) {
        $manifestModelId = [string]$manifestModel.id
    }

    if (-not (Test-ImportOrdinalEquals -Left $ModelSchemaRecord.model_name -Right $TargetModelName) -or
        -not (Test-ImportOrdinalEquals -Left $ModelSchemaRecord.model_id -Right $manifestModelId)) {
        throw "Model schema record does not match manifest model '$TargetModelName'."
    }

    if (-not (Test-ImportOrdinalEquals -Left $PredictionCapture.adapter_contract -Right 'replayable-v1') -or
        -not (Test-ImportOrdinalEquals -Left $PredictionCapture.raw_export_format -Right 'test-fixture-json-v1')) {
        throw 'Prediction capture adapter verification contract is unsupported.'
    }

    if (-not (Test-ImportOrdinalEquals -Left $PredictionCapture.schema_version -Right '1.0') -or
        -not (Test-ImportOrdinalEquals -Left $PredictionCapture.capture_mechanism -Right 'AI Builder Quick Test') -or
        -not (Test-ImportOrdinalEquals -Left $PredictionCapture.run_id -Right $RunManifest.run_id) -or
        -not (Test-ImportOrdinalEquals -Left $PredictionCapture.model_name -Right $TargetModelName) -or
        -not (Test-ImportOrdinalEquals -Left $PredictionCapture.model_version -Right $manifestModel.version) -or
        [string]::IsNullOrWhiteSpace([string]$PredictionCapture.adapter_script_path) -or
        [string]$PredictionCapture.adapter_script_sha256 -notmatch '^[a-f0-9]{64}$' -or
        -not (Test-ImportOrdinalEquals -Left $PredictionCapture.operator -Right $RunManifest.operator) -or
        [string]::IsNullOrWhiteSpace([string]$PredictionCapture.adapter_version)) {
        throw 'Prediction capture top-level attribution is invalid.'
    }

    $heldOutByDocument = @{}
    foreach ($document in @($manifestModel.documents | Where-Object { [string]$_.assignment -eq 'held-out' })) {
        $heldOutByDocument[[string]$document.document] = $document
    }

    foreach ($document in @($PredictionCapture.documents)) {
        $heldOutDocument = $heldOutByDocument[[string]$document.document]
        if (-not $heldOutDocument) {
            throw "Prediction capture document '$($document.document)' is not part of the held-out allocation."
        }

        if (-not (Test-ImportOrdinalEquals -Left $document.document_sha256 -Right $heldOutDocument.sha256)) {
            throw "Prediction capture document '$($document.document)' does not match the held-out allocation hash."
        }

        if (-not (Test-Path -LiteralPath $document.source_export_path -PathType Leaf)) {
            throw "Prediction capture raw export '$($document.source_export_path)' was not found."
        }

        $actualExportHash = Get-ImportFileSha256 -Path ([string]$document.source_export_path)
        if (-not (Test-ImportOrdinalEquals -Left $actualExportHash -Right $document.source_export_sha256)) {
            throw "Prediction capture raw export '$($document.source_export_path)' hash does not match."
        }

        $fieldMap = $document.fields
        if (-not $fieldMap) {
            throw "Prediction capture document '$($document.document)' does not contain fields."
        }

        $fieldNamesInCapture = @($fieldMap.PSObject.Properties.Name)
        if ($fieldNamesInCapture.Count -ne $FieldNames.Count -or
            -not (Test-ImportSequenceEqual -Left @($FieldNames | Sort-Object) -Right @($fieldNamesInCapture | Sort-Object))) {
            throw "Prediction capture document '$($document.document)' does not contain the exact 17-field contract."
        }

        foreach ($fieldName in $FieldNames) {
            if (-not (Test-ImportPredictionCaptureField -FieldRecord $fieldMap.$fieldName)) {
                throw "Prediction capture field '$fieldName' in document '$($document.document)' violates the capture contract."
            }
        }
    }

    $captureDocumentNames = @($PredictionCapture.documents | ForEach-Object { [string]$_.document })
    $heldOutDocumentNames = @($heldOutByDocument.Keys)
    if (@($captureDocumentNames | Group-Object | Where-Object Count -gt 1).Count -gt 0 -or
        $captureDocumentNames.Count -ne $heldOutDocumentNames.Count -or
        -not (Test-ImportSequenceEqual -Left @($captureDocumentNames | Sort-Object) -Right @($heldOutDocumentNames | Sort-Object))) {
        throw 'Prediction capture documents must cover each held-out document exactly once.'
    }

    if (-not (Test-ImportAdapterReplay -PredictionCapture $PredictionCapture -FieldNames $FieldNames)) {
        throw 'Prediction capture cannot be reproduced from the retained raw exports through the tested adapter.'
    }
}

$temporaryCapturePath = Join-Path (Split-Path -Parent $OutputPath) ([IO.Path]::GetFileNameWithoutExtension($OutputPath) + '.tmp.' + [guid]::NewGuid().ToString() + '.json')
$summaryPath = Get-ImportSummaryPath -OutputPath $OutputPath
$blockedCapturePath = $OutputPath + '.blocked.json'

try {
    if (-not (Test-Path -LiteralPath $RawExportDirectory -PathType Container)) {
        throw "Raw export directory '$RawExportDirectory' was not found."
    }

    if (-not (Test-Path -LiteralPath $AdapterScriptPath -PathType Leaf)) {
        throw "Adapter script '$AdapterScriptPath' was not found."
    }

    if (Test-Path -LiteralPath $OutputPath -PathType Leaf) {
        throw "Prediction capture file '$OutputPath' already exists."
    }

    $runManifest = Read-ImportJson -Path $RunManifestPath -Description 'Run manifest'
    $modelSchemaRecord = Read-ImportJson -Path $ModelSchemaRecordPath -Description 'Model schema record'
    $fieldNames = @((Get-HrAiBuilderFieldContract -Path $fieldContractPath) | ForEach-Object { [string]$_.name })

    $manifestModel = @($runManifest.models | Where-Object { [string]$_.display_name -ceq $TargetModelName })
    if ($manifestModel.Count -ne 1) {
        throw "Run manifest does not contain exactly one model record for '$TargetModelName'."
    }

    & $AdapterScriptPath `
        -RawExportDirectory $RawExportDirectory `
        -ModelName $TargetModelName `
        -ModelVersion ([string]$manifestModel[0].version) `
        -RunId ([string]$runManifest.run_id) `
        -Operator ([string]$runManifest.operator) `
        -OutputPath $temporaryCapturePath

    $predictionCapture = Read-ImportJson -Path $temporaryCapturePath -Description 'Prediction capture'
    Set-ImportCaptureAdapterMetadata -PredictionCapture $predictionCapture -AdapterScriptPath ([IO.Path]::GetFullPath($AdapterScriptPath)) | Out-Null
    Test-ImportPredictionCapture -PredictionCapture $predictionCapture `
        -RunManifest $runManifest `
        -ModelSchemaRecord $modelSchemaRecord `
        -FieldNames $fieldNames `
        -TargetModelName $TargetModelName

    $predictionCapture | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $temporaryCapturePath -Encoding UTF8

    Move-ImportTempFile -SourcePath $temporaryCapturePath -DestinationPath $OutputPath
    Write-Output "Prediction capture imported to '$OutputPath'."
    exit 0
}
catch {
    if (Test-Path -LiteralPath $temporaryCapturePath -PathType Leaf) {
        Move-ImportTempFile -SourcePath $temporaryCapturePath -DestinationPath $blockedCapturePath
    }

    Write-ImportBlockedSummary -SummaryPath $summaryPath -Reason $_.Exception.Message -EvidencePaths @{
        RunManifest = $RunManifestPath
        ModelSchemaRecord = $ModelSchemaRecordPath
        RawExportDirectory = $RawExportDirectory
        AdapterScript = $AdapterScriptPath
        OutputPath = $OutputPath
        BlockedCapture = if (Test-Path -LiteralPath $blockedCapturePath -PathType Leaf) { $blockedCapturePath } else { 'Not created' }
    }

    Write-Error $_.Exception.Message
    exit 1
}
