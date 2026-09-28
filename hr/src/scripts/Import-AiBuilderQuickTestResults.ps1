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
        if ([string]$Left[$index] -ne [string]$Right[$index]) {
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

function Test-ImportPredictionCapture {
    param(
        [Parameter(Mandatory)][object]$PredictionCapture,
        [Parameter(Mandatory)][object]$RunManifest,
        [Parameter(Mandatory)][object]$ModelSchemaRecord,
        [Parameter(Mandatory)][string[]]$FieldNames,
        [Parameter(Mandatory)][string]$TargetModelName
    )

    $manifestModel = @($RunManifest.models | Where-Object { [string]$_.display_name -eq $TargetModelName })
    if ($manifestModel.Count -ne 1) {
        throw "Run manifest does not contain exactly one model record for '$TargetModelName'."
    }

    $manifestModel = $manifestModel[0]
    $manifestModelId = [string]$manifestModel.model_id
    if ([string]::IsNullOrWhiteSpace($manifestModelId)) {
        $manifestModelId = [string]$manifestModel.id
    }

    if ([string]$ModelSchemaRecord.model_name -ne $TargetModelName -or [string]$ModelSchemaRecord.model_id -ne $manifestModelId) {
        throw "Model schema record does not match manifest model '$TargetModelName'."
    }

    if ([string]$PredictionCapture.schema_version -ne '1.0' -or
        [string]$PredictionCapture.capture_mechanism -ne 'AI Builder Quick Test' -or
        [string]$PredictionCapture.run_id -ne [string]$RunManifest.run_id -or
        [string]$PredictionCapture.model_name -ne $TargetModelName -or
        [string]$PredictionCapture.model_version -ne [string]$manifestModel.version -or
        [string]$PredictionCapture.operator -ne [string]$RunManifest.operator -or
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

        if ([string]$document.document_sha256 -ne [string]$heldOutDocument.sha256) {
            throw "Prediction capture document '$($document.document)' does not match the held-out allocation hash."
        }

        if (-not (Test-Path -LiteralPath $document.source_export_path -PathType Leaf)) {
            throw "Prediction capture raw export '$($document.source_export_path)' was not found."
        }

        $actualExportHash = Get-ImportFileSha256 -Path ([string]$document.source_export_path)
        if ($actualExportHash -ne [string]$document.source_export_sha256) {
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
}

$temporaryCapturePath = Join-Path (Split-Path -Parent $OutputPath) ([IO.Path]::GetFileNameWithoutExtension($OutputPath) + '.tmp.' + [guid]::NewGuid().ToString() + '.json')

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

    $manifestModel = @($runManifest.models | Where-Object { [string]$_.display_name -eq $TargetModelName })
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
    Test-ImportPredictionCapture -PredictionCapture $predictionCapture `
        -RunManifest $runManifest `
        -ModelSchemaRecord $modelSchemaRecord `
        -FieldNames $fieldNames `
        -TargetModelName $TargetModelName

    Move-ImportTempFile -SourcePath $temporaryCapturePath -DestinationPath $OutputPath
    Write-Output "Prediction capture imported to '$OutputPath'."
    exit 0
}
catch {
    if (Test-Path -LiteralPath $temporaryCapturePath -PathType Leaf) {
        $blockedPath = $OutputPath + '.blocked.json'
        Move-ImportTempFile -SourcePath $temporaryCapturePath -DestinationPath $blockedPath
    }

    Write-Error $_.Exception.Message
    exit 1
}
