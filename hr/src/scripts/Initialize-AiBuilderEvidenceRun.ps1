param(
    [Parameter(Mandatory)][string]$RunId,
    [Parameter(Mandatory)][string]$TenantKey,
    [Parameter(Mandatory)][guid]$EnvironmentId,
    [Parameter(Mandatory)][ValidateSet('DEV', 'TEST', 'PROD')][string]$EnvironmentStage,
    [Parameter(Mandatory)][string]$SolutionUniqueName,
    [Parameter(Mandatory)][string]$SolutionVersion,
    [Parameter(Mandatory)][string]$OperatorUpn,
    [Parameter(Mandatory)][string]$OutputDirectory
)

Set-StrictMode -Version Latest

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleManifestPath = Join-Path $scriptRoot 'modules\Caldova.HrFrontier.AiBuilder\Caldova.HrFrontier.AiBuilder.psd1'
Import-Module $moduleManifestPath -Force

function Get-InitializerFileSha256 {
    param([Parameter(Mandatory)][string]$Path)
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-InitializerRevisionHash {
    param([Parameter(Mandatory)][string[]]$Hashes)

    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        $content = ($Hashes | Sort-Object) -join "`n"
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($content)
        $hash = $sha256.ComputeHash($bytes)
        return ([System.BitConverter]::ToString($hash) -replace '-', '').ToLowerInvariant()
    }
    finally {
        $sha256.Dispose()
    }
}

$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $scriptRoot '..\..\..'))
$contractPath = Join-Path $repositoryRoot 'hr\src\ai-builder\contracts\field-contract.json'
$fixedPackagePath = Join-Path $repositoryRoot 'hr\docs\use-cases\uc-0001-personal-master-data-completion-agent\caldova-aib-fixed-template'
$generalPackagePath = Join-Path $repositoryRoot 'hr\docs\use-cases\uc-0001-personal-master-data-completion-agent\caldova-aib-general-documents'

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$fixedReviewPath = Join-Path $OutputDirectory 'fixed-review.json'
$generalReviewPath = Join-Path $OutputDirectory 'general-review.json'
$corpusQualityPath = Join-Path $OutputDirectory 'corpus-quality.json'
$manifestPath = Join-Path $OutputDirectory 'run-manifest.json'
$inventoryPath = Join-Path $OutputDirectory 'model-inventory.json'

if (-not (Test-Path -LiteralPath $fixedReviewPath -PathType Leaf) -or
    -not (Test-Path -LiteralPath $generalReviewPath -PathType Leaf)) {
    if (-not (Test-Path -LiteralPath $fixedReviewPath -PathType Leaf)) {
        New-HrAiBuilderCorpusReviewTemplate -PackagePath $fixedPackagePath -OutputPath $fixedReviewPath | Out-Null
    }

    if (-not (Test-Path -LiteralPath $generalReviewPath -PathType Leaf)) {
        New-HrAiBuilderCorpusReviewTemplate -PackagePath $generalPackagePath -OutputPath $generalReviewPath | Out-Null
    }

    Write-Output 'Visual corpus review is required before qualification.'
    exit 1
}

if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
    throw "Run manifest file '$manifestPath' already exists."
}

if (Test-Path -LiteralPath $inventoryPath -PathType Leaf) {
    throw "Model inventory file '$inventoryPath' already exists."
}

$fixedResult = Test-HrAiBuilderCorpus -PackagePath $fixedPackagePath -ModelKind Fixed -ReviewPath $fixedReviewPath -FieldContractPath $contractPath
$generalResult = Test-HrAiBuilderCorpus -PackagePath $generalPackagePath -ModelKind General -ReviewPath $generalReviewPath -FieldContractPath $contractPath
$corpusResults = @($fixedResult, $generalResult)

$corpusRevision = Get-InitializerRevisionHash -Hashes @(
    foreach ($result in $corpusResults) {
        foreach ($document in @($result.documents)) {
            [string]$document.sha256
        }

        [string]$result.ground_truth_hashes.json
        [string]$result.ground_truth_hashes.csv
    }
)

$generatorHashes = @(
    foreach ($packagePath in @($fixedPackagePath, $generalPackagePath)) {
        Get-ChildItem -LiteralPath (Join-Path $packagePath 'generators') -Filter '*.py' | ForEach-Object {
            Get-InitializerFileSha256 -Path $_.FullName
        }
    }
)
$generatorRevision = Get-InitializerRevisionHash -Hashes $generatorHashes

$corpusQuality = [ordered]@{
    schema_version = '1.0'
    run_id = $RunId
    tenant_key = $TenantKey
    environment_stage = $EnvironmentStage
    corpus_revision = $corpusRevision
    generator_revision = $generatorRevision
    passed = (@($corpusResults | Where-Object { -not $_.passed }).Count -eq 0)
    corpora = @($corpusResults)
}
$corpusQuality | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $corpusQualityPath -Encoding UTF8

if (-not $corpusQuality.passed) {
    Write-Output 'Corpus qualification failed.'
    exit 1
}

$contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
New-HrAiBuilderRunManifest `
    -RunId $RunId `
    -TenantKey $TenantKey `
    -EnvironmentId $EnvironmentId.Guid `
    -EnvironmentStage $EnvironmentStage `
    -SolutionUniqueName $SolutionUniqueName `
    -SolutionVersion $SolutionVersion `
    -OperatorUpn $OperatorUpn `
    -StartedAtUtc ([datetime]::UtcNow) `
    -CorpusRevision $corpusRevision `
    -GeneratorRevision $generatorRevision `
    -FieldContractVersion ([string]$contract.contract_version) `
    -Models @(
        [pscustomobject]@{ display_name = 'PersonalMasterDataFixed'; model_kind = 'Fixed' }
        [pscustomobject]@{ display_name = 'PersonalMasterDataGeneral'; model_kind = 'General' }
    ) `
    -CorpusResults $corpusResults `
    -OutputPath $manifestPath `
    -ModelInventoryPath $inventoryPath | Out-Null

Write-Output 'Corpus qualification passed.'
exit 0
