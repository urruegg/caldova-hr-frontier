param(
    [Parameter(Mandatory)][string]$RawExportDirectory,
    [Parameter(Mandatory)][string]$ModelName,
    [Parameter(Mandatory)][string]$ModelVersion,
    [Parameter(Mandatory)][string]$RunId,
    [Parameter(Mandatory)][string]$Operator,
    [Parameter(Mandatory)][string]$OutputPath
)

Set-StrictMode -Version Latest

$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\..'))
$modulePath = Join-Path $repositoryRoot 'hr\src\scripts\modules\Caldova.HrFrontier.AiBuilder\Caldova.HrFrontier.AiBuilder.psd1'
$fieldContractPath = Join-Path $repositoryRoot 'hr\src\ai-builder\contracts\field-contract.json'
$capturePath = [IO.Path]::GetFullPath($RawExportDirectory)
$captureRoot = if ((Split-Path -Leaf (Split-Path -Parent $capturePath)) -eq 'capture') {
    Split-Path -Parent $capturePath
}
else {
    $capturePath
}
$evidenceRoot = Split-Path -Parent $captureRoot
$manifestPath = Join-Path $evidenceRoot 'run-manifest.json'
$modelSchemaFileName = if ($ModelName -eq 'PersonalMasterDataFixed') {
    'model-schema-fixed.json'
}
else {
    'model-schema-general.json'
}
$modelSchemaPath = Join-Path $evidenceRoot $modelSchemaFileName

Import-Module $modulePath -Force

if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "Run manifest '$manifestPath' was not found beside the capture directory."
}
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if (-not [string]::Equals([string]$manifest.run_id, $RunId, [StringComparison]::Ordinal)) {
    throw "RunId '$RunId' does not match the capture run manifest."
}

$result = ConvertFrom-HrAiBuilderEvaluationCapture `
    -CaptureDirectory $capturePath `
    -RunManifestPath $manifestPath `
    -FieldContractPath $fieldContractPath `
    -ModelSchemaRecordPath $modelSchemaPath `
    -ModelName $ModelName `
    -ModelVersion $ModelVersion `
    -Operator $Operator `
    -OutputPath $OutputPath `
    -AdapterScriptPath $PSCommandPath

if ($result.status -ne 'passed') {
    throw "AI Builder capture replay blocked at gate(s): $($result.failed_gates -join ', ')."
}

$result
