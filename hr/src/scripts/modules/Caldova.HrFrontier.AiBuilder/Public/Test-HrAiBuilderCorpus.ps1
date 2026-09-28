function Test-HrAiBuilderCorpus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$PackagePath,

        [Parameter(Mandatory)]
        [ValidateSet('Fixed', 'General')]
        [string]$ModelKind,

        [Parameter(Mandatory)]
        [string]$ReviewPath,

        [Parameter(Mandatory)]
        [string]$FieldContractPath
    )

    $errors = [System.Collections.Generic.List[string]]::new()
    $contractFields = @(Get-HrAiBuilderFieldContract -Path $FieldContractPath)
    $metadata = Get-HrAiBuilderPackageMetadata -PackagePath $PackagePath
    $review = Read-HrAiBuilderJson -Path $ReviewPath -Description 'Corpus review'
    $truthRows = @($metadata.Json.documents)
    $csvRows = @(
        if (Test-Path -LiteralPath $metadata.GroundTruthCsvPath -PathType Leaf) {
            Import-Csv -LiteralPath $metadata.GroundTruthCsvPath -Encoding UTF8
        }
    )
    $pdfsByName = @{}
    foreach ($pdf in $metadata.Pdfs) {
        $pdfsByName[$pdf.Name] = $pdf
    }

    $truthNames = @($truthRows | ForEach-Object { [string]$_.document })
    $csvNames = @($csvRows | ForEach-Object { [string]$_.document })
    $reviewRows = @($review.documents)
    $reviewNames = @($reviewRows | ForEach-Object { [string]$_.document })

    foreach ($duplicateSet in @(
        @{ Label = 'ground-truth JSON'; Values = $truthNames }
        @{ Label = 'ground-truth CSV'; Values = $csvNames }
        @{ Label = 'review'; Values = $reviewNames }
    )) {
        if (@($duplicateSet.Values | Group-Object | Where-Object Count -gt 1).Count -gt 0) {
            $errors.Add("Duplicate document names exist in the $($duplicateSet.Label) data set.") | Out-Null
        }
    }

    if ($truthRows.Count -ne $metadata.Pdfs.Count -or $csvRows.Count -ne $metadata.Pdfs.Count) {
        $errors.Add('Ground-truth rows must resolve to exactly one row per PDF document.') | Out-Null
    }

    if (-not (Compare-HrAiBuilderSequence -Left @($truthNames | Sort-Object) -Right @($metadata.Pdfs.Name | Sort-Object))) {
        $errors.Add('Ground-truth JSON rows do not resolve to the same document set as the PDF inventory.') | Out-Null
    }

    if (-not (Compare-HrAiBuilderSequence -Left @($csvNames | Sort-Object) -Right @($metadata.Pdfs.Name | Sort-Object))) {
        $errors.Add('Ground-truth CSV rows do not resolve to the same document set as the PDF inventory.') | Out-Null
    }

    $csvByName = @{}
    foreach ($row in $csvRows) {
        $csvByName[[string]$row.document] = $row
    }

    foreach ($row in $truthRows) {
        $documentName = [string]$row.document
        $csvRow = $csvByName[$documentName]
        if (-not $csvRow) {
            $errors.Add("Ground-truth CSV is missing document '$documentName'.") | Out-Null
            continue
        }

        foreach ($field in $contractFields) {
            $fieldName = [string]$field.name
            if (-not $row.PSObject.Properties.Name.Contains($field.name)) {
                $errors.Add("Ground-truth JSON row '$documentName' is missing contract field '$fieldName'.") | Out-Null
            }

            if (-not $csvRow.PSObject.Properties.Name.Contains($field.name)) {
                $errors.Add("Ground-truth CSV row '$documentName' is missing contract field '$fieldName'.") | Out-Null
            }
            elseif ([string]$row.($fieldName) -ne [string]$csvRow.($fieldName)) {
                $errors.Add("Ground-truth JSON and CSV differ for '$documentName' field '$fieldName'.") | Out-Null
            }
        }

        if ($row.PSObject.Properties.Name.Contains('candidate_id_expected') -and
            -not [string]::IsNullOrWhiteSpace([string]$row.candidate_id_expected) -and
            ($documentName -notlike "*$($row.candidate_id_expected)*")) {
            $errors.Add("Document '$documentName' does not agree with candidate reference '$($row.candidate_id_expected)'.") | Out-Null
        }

        $pdf = $pdfsByName[$documentName]
        if ($pdf) {
            $expectedGrouping = [string]$row.collection_or_layout
            if ($row.PSObject.Properties.Name.Contains('collection_or_layout')) {
                if ($ModelKind -eq 'Fixed') {
                    $folderName = Split-Path -Leaf (Split-Path -Parent $pdf.FullName)
                    if ($expectedGrouping -ne $folderName) {
                        $errors.Add("Document '$documentName' collection or family does not agree with its folder name.") | Out-Null
                    }
                }
                else {
                    $match = [regex]::Match($documentName, '^g\d{2}-(.+)-CAND-')
                    if (-not $match.Success -or $match.Groups[1].Value -ne $expectedGrouping) {
                        $errors.Add("Document '$documentName' collection or family does not agree with its filename family marker.") | Out-Null
                    }
                }
            }
        }
    }

    $reviewByName = @{}
    foreach ($reviewRow in $reviewRows) {
        $reviewByName[[string]$reviewRow.document] = $reviewRow
    }

    $reviewIncomplete = $false
    foreach ($pdf in $metadata.Pdfs) {
        $reviewRow = $reviewByName[$pdf.Name]
        if (-not $reviewRow) {
            $reviewIncomplete = $true
            continue
        }

        if ([string]$reviewRow.status -ne 'confirmed' -or
            -not [bool]$reviewRow.values_visible -or
            -not [bool]$reviewRow.absences_confirmed -or
            [string]::IsNullOrWhiteSpace([string]$reviewRow.reviewer)) {
            $reviewIncomplete = $true
        }
    }

    if ($reviewIncomplete) {
        $errors.Add('Visual review is incomplete.') | Out-Null
    }

    $rowsByGroup = $truthRows | Group-Object -Property collection_or_layout
    $documentResults = [System.Collections.Generic.List[object]]::new()
    foreach ($group in $rowsByGroup) {
        $sortedRows = @($group.Group | Sort-Object document)
        if ($ModelKind -eq 'Fixed') {
            foreach ($row in $sortedRows) {
                $match = [regex]::Match([string]$row.document, '^[a-z](\d{2})-')
                if (-not $match.Success) {
                    $errors.Add("Fixed document '$($row.document)' does not match the expected naming convention.") | Out-Null
                    continue
                }

                $ordinal = [int]$match.Groups[1].Value
                if ($ordinal -lt 1 -or $ordinal -gt 6) {
                    $errors.Add("Fixed document '$($row.document)' is outside the supported 01-06 collection range.") | Out-Null
                    continue
                }

                $assignment = if ($ordinal -eq 6) { 'held-out' } else { 'training' }
                $documentResults.Add([pscustomobject]@{
                        document = [string]$row.document
                        collection_or_family = [string]$row.collection_or_layout
                        assignment = $assignment
                        sha256 = Get-HrAiBuilderFileSha256 -Path $pdfsByName[[string]$row.document].FullName
                        source_path = $pdfsByName[[string]$row.document].FullName
                    }) | Out-Null
            }
        }
        else {
            if ($sortedRows.Count -ne 3) {
                $errors.Add("General family '$($group.Name)' must contain exactly 3 documents.") | Out-Null
            }

            for ($index = 0; $index -lt $sortedRows.Count; $index++) {
                $assignment = if ($index -eq 2) { 'held-out' } else { 'training' }
                $documentResults.Add([pscustomobject]@{
                        document = [string]$sortedRows[$index].document
                        collection_or_family = [string]$sortedRows[$index].collection_or_layout
                        assignment = $assignment
                        sha256 = Get-HrAiBuilderFileSha256 -Path $pdfsByName[[string]$sortedRows[$index].document].FullName
                        source_path = $pdfsByName[[string]$sortedRows[$index].document].FullName
                    }) | Out-Null
            }
        }
    }

    $fieldCoverage = foreach ($group in $rowsByGroup | Sort-Object Name) {
        $coverage = foreach ($field in $contractFields) {
            [ordered]@{
                field_name = [string]$field.name
                present_count = @($group.Group | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.($field.name)) }).Count
            }
        }

        [ordered]@{
            collection_or_family = [string]$group.Name
            document_count = @($group.Group).Count
            fields = @($coverage)
        }
    }

    $result = [ordered]@{
        schema_version = '1.0'
        package = $metadata.Package
        model_kind = $ModelKind
        passed = ($errors.Count -eq 0)
        documents = @($documentResults)
        field_coverage = @($fieldCoverage)
        errors = @($errors)
        ground_truth_hashes = [ordered]@{
            json = Get-HrAiBuilderFileSha256 -Path $metadata.GroundTruthJsonPath
            csv = Get-HrAiBuilderFileSha256 -Path $metadata.GroundTruthCsvPath
        }
    }

    return [pscustomobject]$result
}
