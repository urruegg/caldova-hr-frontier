Set-StrictMode -Version Latest

function Read-HrAiBuilderJson {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Description
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

function Write-HrAiBuilderJson {
    param(
        [Parameter(Mandatory)]
        [object]$InputObject,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $directory = Split-Path -Parent $Path
    if ($directory) {
        New-Item -ItemType Directory -Force -Path $directory | Out-Null
    }

    $InputObject | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Get-HrAiBuilderKnownModels {
    @(
        [pscustomobject]@{ display_name = 'PersonalMasterDataFixed'; model_kind = 'Fixed' }
        [pscustomobject]@{ display_name = 'PersonalMasterDataGeneral'; model_kind = 'General' }
    )
}

function Get-HrAiBuilderLifecycleOrder {
    @(
        'not_created',
        'created',
        'schema_defined',
        'tagged',
        'trained',
        'evaluated',
        'published',
        'added_to_solution'
    )
}

function Get-HrAiBuilderKnownReadinessCheckIds {
    @(
        'environment',
        'dataverse',
        'maker_authorization',
        'ai_builder_available',
        'capacity',
        'data_policy',
        'solution',
        'publisher'
    )
}

function Get-HrAiBuilderKnownFieldNames {
    @(
        'candidate_id',
        'last_name',
        'first_name',
        'dob',
        'nationality',
        'marital',
        'heimatort',
        'permit',
        'street',
        'plz',
        'city',
        'ahv',
        'iban',
        'phone',
        'email',
        'ec_name',
        'ec_phone'
    )
}

function Get-HrAiBuilderMetricValue {
    param(
        [Parameter(Mandatory)]
        [double]$Numerator,

        [Parameter(Mandatory)]
        [double]$Denominator
    )

    if ($Denominator -eq 0) {
        return $null
    }

    return ($Numerator / $Denominator)
}

function Get-HrAiBuilderConfidenceSummary {
    param(
        [AllowEmptyCollection()]
        [object[]]$Records
    )

    $numericConfidence = @(
        $Records |
            Where-Object {
                $_ -and
                $_.PSObject.Properties.Name.Contains('confidence') -and
                (
                    $_.confidence -is [double] -or
                    $_.confidence -is [decimal] -or
                    $_.confidence -is [single] -or
                    $_.confidence -is [int]
                )
            } |
            ForEach-Object { [double]$_.confidence }
    )

    if ($numericConfidence.Count -eq 0) {
        return [ordered]@{
            count = 0
            minimum = $null
            maximum = $null
            mean = $null
        }
    }

    return [ordered]@{
        count = $numericConfidence.Count
        minimum = ($numericConfidence | Measure-Object -Minimum).Minimum
        maximum = ($numericConfidence | Measure-Object -Maximum).Maximum
        mean = ($numericConfidence | Measure-Object -Average).Average
    }
}

function Get-HrAiBuilderStringSha256 {
    param(
        [Parameter(Mandatory)]
        [string]$InputText
    )

    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($InputText)
        $hash = $sha256.ComputeHash($bytes)
        return ([System.BitConverter]::ToString($hash) -replace '-', '').ToLowerInvariant()
    }
    finally {
        $sha256.Dispose()
    }
}

function Get-HrAiBuilderRevisionHash {
    param(
        [Parameter(Mandatory)]
        [string[]]$Hashes
    )

    if (-not $Hashes -or $Hashes.Count -eq 0) {
        throw 'At least one SHA-256 hash is required to derive a revision.'
    }

    return Get-HrAiBuilderStringSha256 -InputText (($Hashes | Sort-Object) -join "`n")
}

function Get-HrAiBuilderPackageMetadata {
    param(
        [Parameter(Mandatory)]
        [string]$PackagePath
    )

    $groundTruthJsonPath = Join-Path $PackagePath 'ground-truth.json'
    $groundTruthCsvPath = Join-Path $PackagePath 'ground-truth.csv'
    $documentsPath = Join-Path $PackagePath 'documents'

    if (-not (Test-Path -LiteralPath $documentsPath -PathType Container)) {
        throw "Package '$PackagePath' does not contain a documents directory."
    }

    $json = Read-HrAiBuilderJson -Path $groundTruthJsonPath -Description 'Ground-truth'
    $pdfs = @(
        Get-ChildItem -LiteralPath $documentsPath -Filter '*.pdf' -Recurse |
            Sort-Object FullName
    )

    [pscustomobject]@{
        GroundTruthJsonPath = $groundTruthJsonPath
        GroundTruthCsvPath = $groundTruthCsvPath
        DocumentsPath = $documentsPath
        Package = [string]$json.package
        Pdfs = $pdfs
        Json = $json
    }
}

function Get-HrAiBuilderInventoryPathFromManifest {
    param(
        [Parameter(Mandatory)]
        [string]$ManifestPath
    )

    Join-Path (Split-Path -Parent $ManifestPath) 'model-inventory.json'
}

function Assert-HrAiBuilderManifestMutable {
    param(
        [Parameter(Mandatory)]
        [object]$Manifest,

        [Parameter(Mandatory)]
        [string]$Path
    )

    if ($Manifest.finalized) {
        throw "Run manifest '$Path' is finalized and cannot be mutated."
    }
}

function New-HrAiBuilderModelRecordState {
    param(
        [Parameter(Mandatory)]
        [string]$DisplayName,

        [Parameter(Mandatory)]
        [string]$ModelKind,

        [object[]]$Documents = @(),

        [object]$GroundTruthHashes = $null
    )

    [ordered]@{
        display_name = $DisplayName
        model_kind = $ModelKind
        model_id = ''
        version = ''
        lifecycle_stage = 'not_created'
        documents = @($Documents)
        ground_truth_hashes = if ($GroundTruthHashes) { $GroundTruthHashes } else { [ordered]@{} }
        lifecycle_history = @(
            [ordered]@{
                stage = 'not_created'
                changed_at_utc = [datetime]::UtcNow.ToString('o')
            }
        )
    }
}

function Compare-HrAiBuilderSequence {
    param(
        [Parameter(Mandatory)]
        [object[]]$Left,

        [Parameter(Mandatory)]
        [object[]]$Right
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

$privateScriptsPath = Join-Path $PSScriptRoot 'Private'
if (Test-Path -LiteralPath $privateScriptsPath) {
    Get-ChildItem -LiteralPath $privateScriptsPath -Filter '*.ps1' | Sort-Object Name | ForEach-Object {
        . $_.FullName
    }
}

$publicScriptsPath = Join-Path $PSScriptRoot 'Public'
Get-ChildItem -LiteralPath $publicScriptsPath -Filter '*.ps1' | Sort-Object Name | ForEach-Object {
    . $_.FullName
}

Export-ModuleMember -Function @(
    'Get-HrAiBuilderFieldContract',
    'New-HrAiBuilderCorpusReviewTemplate',
    'Test-HrAiBuilderCorpus',
    'New-HrAiBuilderRunManifest',
    'Set-HrAiBuilderModelRecord',
    'Complete-HrAiBuilderRunManifest',
    'New-HrAiBuilderReadinessRecord',
    'New-HrAiBuilderTestCapabilityRecord',
    'ConvertTo-HrAiBuilderNormalizedValue',
    'Measure-HrAiBuilderEvaluation',
    'New-HrAiBuilderModelSchemaRecord',
    'Test-HrAiBuilderStrictGates'
)
