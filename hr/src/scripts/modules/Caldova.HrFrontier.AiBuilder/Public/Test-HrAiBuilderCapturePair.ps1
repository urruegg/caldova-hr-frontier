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

    function Read-CapturePairJson {
        [CmdletBinding(DefaultParameterSetName = 'Path')]
        param(
            [Parameter(Mandatory, ParameterSetName = 'Path')]
            [string]$Path,

            [Parameter(Mandatory, ParameterSetName = 'Bytes')]
            [byte[]]$Bytes,

            [Parameter(Mandatory)]
            [string]$Description
        )

        $text = if ($PSCmdlet.ParameterSetName -eq 'Path') {
            [IO.File]::ReadAllText(
                [IO.Path]::GetFullPath($Path),
                [Text.UTF8Encoding]::new($false, $true)
            )
        }
        else {
            [Text.UTF8Encoding]::new($false, $true).GetString($Bytes)
        }
        $text = $text.TrimStart([char]0xFEFF)

        try {
            $convertFromJson = Get-Command ConvertFrom-Json -ErrorAction Stop
            if ($convertFromJson.Parameters.ContainsKey('DateKind')) {
                return $text | ConvertFrom-Json -DateKind String -ErrorAction Stop
            }
            return $text | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            throw "$Description is not valid JSON: $($_.Exception.Message)"
        }
    }

    function Test-CapturePairOrdinal {
        param([AllowNull()][object]$Left, [AllowNull()][object]$Right)
        if ($null -eq $Left -or $null -eq $Right) {
            return ($null -eq $Left -and $null -eq $Right)
        }
        return [string]::Equals([string]$Left, [string]$Right, [StringComparison]::Ordinal)
    }

    function Test-CapturePairNumber {
        param([AllowNull()][object]$Value)
        return $Value -is [byte] -or $Value -is [int16] -or
            $Value -is [int32] -or $Value -is [int64] -or
            $Value -is [single] -or $Value -is [double] -or
            $Value -is [decimal]
    }

    function Test-CapturePairProperties {
        param(
            [AllowNull()][object]$Node,
            [Parameter(Mandatory)][string[]]$Expected
        )
        return $null -ne $Node -and
            (Compare-HrAiBuilderSequence -Left $Expected -Right @($Node.PSObject.Properties.Name))
    }

    function Test-CapturePairCoordinate {
        param([AllowNull()][object]$Coordinate)
        return (Test-CapturePairProperties -Node $Coordinate -Expected @('@odata.type', 'x', 'y')) -and
            (Test-CapturePairOrdinal $Coordinate.'@odata.type' '#Microsoft.Dynamics.CRM.expando') -and
            (Test-CapturePairNumber $Coordinate.x) -and
            (Test-CapturePairNumber $Coordinate.y)
    }

    function Test-CapturePairPolygon {
        param([AllowNull()][object]$Polygon)
        if (-not (Test-CapturePairProperties -Node $Polygon -Expected @(
            '@odata.type', 'coordinates@odata.type', 'coordinates'
        )) -or
            -not (Test-CapturePairOrdinal $Polygon.'@odata.type' '#Microsoft.Dynamics.CRM.expando') -or
            -not (Test-CapturePairOrdinal $Polygon.'coordinates@odata.type' '#Collection(Microsoft.Dynamics.CRM.crmbaseentity)') -or
            -not ($Polygon.coordinates -is [array]) -or
            @($Polygon.coordinates).Count -ne 4) {
            return $false
        }
        foreach ($coordinate in @($Polygon.coordinates)) {
            if (-not (Test-CapturePairCoordinate -Coordinate $coordinate)) {
                return $false
            }
        }
        return $true
    }

    function Test-CapturePairLabelShape {
        param(
            [Parameter(Mandatory)][string]$FieldName,
            [AllowNull()][object]$Label
        )

        if ($null -eq $Label) {
            return $false
        }

        $propertyNames = @($Label.PSObject.Properties.Name)
        $dateWithoutValueProperties = @(
            '@odata.type', 'displayName', 'fieldType', 'confidence', 'text',
            'spans@odata.type', 'spans', 'valueLocation'
        )
        $dateWithValueProperties = @(
            '@odata.type', 'value@odata.type', 'value', 'displayName', 'fieldType',
            'confidence', 'text', 'spans@odata.type', 'spans', 'valueLocation'
        )
        $expectedProperties = if ($FieldName -ceq 'dob') {
            if (Compare-HrAiBuilderSequence -Left $dateWithoutValueProperties -Right $propertyNames) {
                $dateWithoutValueProperties
            }
            elseif (Compare-HrAiBuilderSequence -Left $dateWithValueProperties -Right $propertyNames) {
                $dateWithValueProperties
            }
            else {
                @()
            }
        }
        else {
            @('@odata.type', 'value', 'displayName', 'fieldType', 'confidence', 'text',
                'spans@odata.type', 'spans', 'valueLocation')
        }
        $expectedFieldType = if ($FieldName -ceq 'dob') { 'date' } else { 'string' }
        if ($expectedProperties.Count -eq 0 -or
            -not (Test-CapturePairProperties -Node $Label -Expected $expectedProperties) -or
            -not (Test-CapturePairOrdinal $Label.'@odata.type' '#Microsoft.Dynamics.CRM.expando') -or
            -not (Test-CapturePairOrdinal $Label.displayName $FieldName) -or
            -not (Test-CapturePairOrdinal $Label.fieldType $expectedFieldType) -or
            -not ($Label.text -is [string]) -or
            -not (Test-CapturePairOrdinal $Label.'spans@odata.type' '#Collection(Microsoft.Dynamics.CRM.crmbaseentity)') -or
            -not ($Label.spans -is [array]) -or
            @($Label.spans).Count -ne 1) {
            return $false
        }
        if ($FieldName -cne 'dob' -and -not ($Label.value -is [string])) {
            return $false
        }
        if ($FieldName -ceq 'dob' -and $expectedProperties.Count -eq $dateWithValueProperties.Count -and
            (-not (Test-CapturePairOrdinal $Label.'value@odata.type' '#DateTimeOffset') -or
                -not ($Label.value -is [string]))) {
            return $false
        }

        $span = @($Label.spans)[0]
        if (-not (Test-CapturePairProperties -Node $span -Expected @(
            '@odata.type', 'offset@odata.type', 'offset', 'length@odata.type', 'length'
        )) -or
            -not (Test-CapturePairOrdinal $span.'@odata.type' '#Microsoft.Dynamics.CRM.expando') -or
            -not (Test-CapturePairOrdinal $span.'offset@odata.type' '#Int64') -or
            -not (Test-CapturePairOrdinal $span.'length@odata.type' '#Int64') -or
            -not (Test-CapturePairNumber $span.offset) -or
            -not (Test-CapturePairNumber $span.length)) {
            return $false
        }

        $location = $Label.valueLocation
        if (-not (Test-CapturePairProperties -Node $location -Expected @(
            '@odata.type', 'pageNumber@odata.type', 'pageNumber', 'boundingBox',
            'regions@odata.type', 'regions'
        )) -or
            -not (Test-CapturePairOrdinal $location.'@odata.type' '#Microsoft.Dynamics.CRM.expando') -or
            -not (Test-CapturePairOrdinal $location.'pageNumber@odata.type' '#Int64') -or
            -not (Test-CapturePairNumber $location.pageNumber) -or
            -not (Test-CapturePairOrdinal $location.'regions@odata.type' '#Collection(Microsoft.Dynamics.CRM.crmbaseentity)') -or
            -not ($location.regions -is [array]) -or
            @($location.regions).Count -lt 1) {
            return $false
        }

        $box = $location.boundingBox
        if (-not (Test-CapturePairProperties -Node $box -Expected @(
            '@odata.type', 'left', 'top', 'width', 'height', 'polygon'
        )) -or
            -not (Test-CapturePairOrdinal $box.'@odata.type' '#Microsoft.Dynamics.CRM.expando') -or
            -not (Test-CapturePairNumber $box.left) -or
            -not (Test-CapturePairNumber $box.top) -or
            -not (Test-CapturePairNumber $box.width) -or
            -not (Test-CapturePairNumber $box.height) -or
            -not (Test-CapturePairPolygon -Polygon $box.polygon)) {
            return $false
        }

        foreach ($region in @($location.regions)) {
            if (-not (Test-CapturePairProperties -Node $region -Expected @(
                '@odata.type', 'pageNumber@odata.type', 'pageNumber', 'polygon'
            )) -or
                -not (Test-CapturePairOrdinal $region.'@odata.type' '#Microsoft.Dynamics.CRM.expando') -or
                -not (Test-CapturePairOrdinal $region.'pageNumber@odata.type' '#Int64') -or
                -not (Test-CapturePairNumber $region.pageNumber) -or
                -not (Test-CapturePairPolygon -Polygon $region.polygon)) {
                return $false
            }
        }
        return $true
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
        $pair = Read-CapturePairJson -Path $pairFiles[0].FullName -Description 'Capture pair'
        $manifest = Read-CapturePairJson -Path $RunManifestPath -Description 'Run manifest'
        $contract = Read-CapturePairJson -Path $FieldContractPath -Description 'Field contract'
        $schema = Read-CapturePairJson -Path $ModelSchemaRecordPath -Description 'Model schema record'
        $canonicalBytes = [IO.File]::ReadAllBytes($canonicalFiles[0].FullName)
        $canonical = Read-CapturePairJson -Bytes $canonicalBytes -Description 'Canonical envelope'
        $raw = Read-CapturePairJson -Path $rawFiles[0].FullName -Description 'Raw response'
    }
    catch {
        Add-CapturePairFailure 'capture_pair_provenance'
        return Complete-CapturePairResult
    }

    $captureRoot = $null
    $ancestor = [IO.DirectoryInfo]::new($capturePath).Parent
    while ($null -ne $ancestor) {
        if ([string]::Equals($ancestor.Name, 'capture', [StringComparison]::Ordinal)) {
            $captureRoot = $ancestor.FullName
            break
        }
        $ancestor = $ancestor.Parent
    }
    if (-not $captureRoot -or
        -not (Test-HrAiBuilderPathWithinRoot -Path $capturePath -RootPath $captureRoot) -or
        (Test-CapturePairOrdinal $capturePath $captureRoot)) {
        Add-CapturePairFailure 'evidence_boundary'
        return Complete-CapturePairResult -Envelope $canonical -RawPath $rawFiles[0].FullName
    }
    $evidenceRoot = Split-Path -Parent $captureRoot
    try {
        $sourcePath = [IO.Path]::GetFullPath((Join-Path $evidenceRoot ([string]$pair.source.local_path)))
        $expectedSourcePath = [IO.Path]::GetFullPath(
            (Join-Path $capturePath ('source\' + [string]$pair.source.filename))
        )
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

    if (-not (Test-CapturePairOrdinal $sourcePath $expectedSourcePath) -or
        -not (Test-CapturePairOrdinal $pairRawPath $rawFiles[0].FullName) -or
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

    $requiredContractNames = @(
        'candidate_id', 'last_name', 'first_name', 'dob', 'nationality', 'marital',
        'heimatort', 'permit', 'street', 'plz', 'city', 'ahv', 'iban', 'phone',
        'email', 'ec_name', 'ec_phone'
    )
    $contractNames = @($contract.fields | ForEach-Object { [string]$_.name })
    $schemaNames = @($schema.fields | ForEach-Object { [string]$_.name })
    $canonicalNames = @($canonical.fields.PSObject.Properties.Name)
    $labels = $raw.responsev2.predictionOutput.labels
    if (-not $labels) {
        Add-CapturePairFailure 'exact_field_contract'
        return Complete-CapturePairResult -Envelope $canonical -RawPath $rawFiles[0].FullName
    }
    $labelNames = @($labels.PSObject.Properties.Name | Where-Object { $_ -ne '@odata.type' })
    if ($contract.field_count -ne 17 -or
        $contractNames.Count -ne 17 -or
        @($contractNames | Select-Object -Unique).Count -ne 17 -or
        -not (Compare-HrAiBuilderSequence -Left $requiredContractNames -Right $contractNames) -or
        -not (Compare-HrAiBuilderSequence -Left $contractNames -Right $schemaNames) -or
        -not (Compare-HrAiBuilderSequence -Left $contractNames -Right $canonicalNames) -or
        @($labelNames | Where-Object { -not $contractNames.Contains($_) }).Count -gt 0) {
        Add-CapturePairFailure 'exact_field_contract'
    }
    if (-not (Test-CapturePairOrdinal $labels.'@odata.type' '#Microsoft.Dynamics.CRM.expando')) {
        Add-CapturePairFailure 'capture_pair_provenance'
    }

    $projectedFields = [ordered]@{}
    foreach ($fieldName in $contractNames) {
        $labelProperty = $labels.PSObject.Properties[$fieldName]
        if ($null -eq $labelProperty) {
            $projectedFields[$fieldName] = [ordered]@{ value = $null; confidence = $null }
            continue
        }
        $label = $labelProperty.Value
        if (-not (Test-CapturePairLabelShape -FieldName $fieldName -Label $label)) {
            Add-CapturePairFailure 'capture_pair_provenance'
            if ($null -eq $label -or $label -is [ValueType] -or $label -is [string]) {
                $projectedFields[$fieldName] = [ordered]@{ value = $null; confidence = $null }
                continue
            }
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
