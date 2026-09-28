function Test-CustomerExportPathSegmentProhibited {
    param([Parameter(Mandatory)][string[]]$Segments)

    foreach ($segment in $Segments) {
        if ([string]::Equals($segment, '.git', [StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
        if ($segment.IndexOfAny([char[]]@('*', '?', '[', ']')) -ge 0) {
            return $true
        }
        if ($segment -in @('.', '..')) {
            return $true
        }
    }

    return $false
}

function Assert-CustomerExportRelativePath {
    param(
        [Parameter(Mandatory)][string]$Path,
        [string]$ErrorMessage = 'Manifest paths must be exact path values.'
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw $ErrorMessage
    }
    if ($Path -match '\\' -or $Path -match '^[A-Za-z]:' -or $Path -match '^//|^\\\\') {
        throw $ErrorMessage
    }

    $segments = @($Path -split '/')
    if (@($segments | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count -gt 0) {
        throw $ErrorMessage
    }
    if (Test-CustomerExportPathSegmentProhibited -Segments $segments) {
        throw $ErrorMessage
    }

    foreach ($segment in $segments) {
        if ($segment.IndexOfAny([IO.Path]::GetInvalidFileNameChars()) -ge 0) {
            throw $ErrorMessage
        }
    }

    return ($segments -join '/')
}

function Read-CustomerExportUtf8Text {
    param([Parameter(Mandatory)][string]$Path)

    $bytes = [IO.File]::ReadAllBytes([IO.Path]::GetFullPath($Path))
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        throw 'Customer export manifest must be UTF-8 without BOM.'
    }

    return [Text.UTF8Encoding]::new($false, $true).GetString($bytes)
}

function Skip-CustomerExportJsonWhitespace {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][ref]$Index
    )

    while ($Index.Value -lt $Text.Length -and [char]::IsWhiteSpace($Text[$Index.Value])) {
        $Index.Value++
    }
}

function Read-CustomerExportJsonString {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][ref]$Index
    )

    if ($Index.Value -ge $Text.Length -or $Text[$Index.Value] -ne '"') {
        throw 'Customer export manifest is not valid JSON.'
    }

    $Index.Value++
    $builder = [Text.StringBuilder]::new()
    while ($Index.Value -lt $Text.Length) {
        $character = $Text[$Index.Value]
        if ($character -eq '"') {
            $Index.Value++
            return $builder.ToString()
        }
        if ($character -eq '\') {
            $Index.Value++
            if ($Index.Value -ge $Text.Length) {
                throw 'Customer export manifest is not valid JSON.'
            }
            $escape = $Text[$Index.Value]
            switch ($escape) {
                '"' { [void]$builder.Append('"') }
                '\' { [void]$builder.Append('\') }
                '/' { [void]$builder.Append('/') }
                'b' { [void]$builder.Append([char]8) }
                'f' { [void]$builder.Append([char]12) }
                'n' { [void]$builder.Append("`n") }
                'r' { [void]$builder.Append("`r") }
                't' { [void]$builder.Append("`t") }
                'u' {
                    if ($Index.Value + 4 -ge $Text.Length) {
                        throw 'Customer export manifest is not valid JSON.'
                    }
                    $hex = $Text.Substring($Index.Value + 1, 4)
                    if ($hex -notmatch '^[0-9A-Fa-f]{4}$') {
                        throw 'Customer export manifest is not valid JSON.'
                    }
                    [void]$builder.Append([char][Convert]::ToInt32($hex, 16))
                    $Index.Value += 4
                }
                default { throw 'Customer export manifest is not valid JSON.' }
            }
            $Index.Value++
            continue
        }
        [void]$builder.Append($character)
        $Index.Value++
    }

    throw 'Customer export manifest is not valid JSON.'
}

function Skip-CustomerExportJsonNumber {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][ref]$Index
    )

    if ($Text[$Index.Value] -eq '-') { $Index.Value++ }
    if ($Index.Value -ge $Text.Length) { throw 'Customer export manifest is not valid JSON.' }
    if ($Text[$Index.Value] -eq '0') {
        $Index.Value++
    }
    else {
        if ($Text[$Index.Value] -notmatch '[1-9]') {
            throw 'Customer export manifest is not valid JSON.'
        }
        while ($Index.Value -lt $Text.Length -and $Text[$Index.Value] -match '[0-9]') {
            $Index.Value++
        }
    }
    if ($Index.Value -lt $Text.Length -and $Text[$Index.Value] -eq '.') {
        $Index.Value++
        if ($Index.Value -ge $Text.Length -or $Text[$Index.Value] -notmatch '[0-9]') {
            throw 'Customer export manifest is not valid JSON.'
        }
        while ($Index.Value -lt $Text.Length -and $Text[$Index.Value] -match '[0-9]') {
            $Index.Value++
        }
    }
    if ($Index.Value -lt $Text.Length -and $Text[$Index.Value] -match '[eE]') {
        $Index.Value++
        if ($Index.Value -lt $Text.Length -and $Text[$Index.Value] -match '[+-]') {
            $Index.Value++
        }
        if ($Index.Value -ge $Text.Length -or $Text[$Index.Value] -notmatch '[0-9]') {
            throw 'Customer export manifest is not valid JSON.'
        }
        while ($Index.Value -lt $Text.Length -and $Text[$Index.Value] -match '[0-9]') {
            $Index.Value++
        }
    }
}

function Test-CustomerExportJsonValue {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][ref]$Index
    )

    Skip-CustomerExportJsonWhitespace -Text $Text -Index $Index
    if ($Index.Value -ge $Text.Length) {
        throw 'Customer export manifest is not valid JSON.'
    }

    switch ($Text[$Index.Value]) {
        '{' {
            $Index.Value++
            Skip-CustomerExportJsonWhitespace -Text $Text -Index $Index
            $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
            if ($Index.Value -lt $Text.Length -and $Text[$Index.Value] -eq '}') {
                $Index.Value++
                return
            }
            while ($true) {
                $propertyName = Read-CustomerExportJsonString -Text $Text -Index $Index
                if (-not $seen.Add($propertyName)) {
                    throw "Customer export manifest contains a duplicate JSON property: $propertyName"
                }
                Skip-CustomerExportJsonWhitespace -Text $Text -Index $Index
                if ($Index.Value -ge $Text.Length -or $Text[$Index.Value] -ne ':') {
                    throw 'Customer export manifest is not valid JSON.'
                }
                $Index.Value++
                Test-CustomerExportJsonValue -Text $Text -Index $Index
                Skip-CustomerExportJsonWhitespace -Text $Text -Index $Index
                if ($Index.Value -ge $Text.Length) {
                    throw 'Customer export manifest is not valid JSON.'
                }
                if ($Text[$Index.Value] -eq '}') {
                    $Index.Value++
                    return
                }
                if ($Text[$Index.Value] -ne ',') {
                    throw 'Customer export manifest is not valid JSON.'
                }
                $Index.Value++
                Skip-CustomerExportJsonWhitespace -Text $Text -Index $Index
            }
        }
        '[' {
            $Index.Value++
            Skip-CustomerExportJsonWhitespace -Text $Text -Index $Index
            if ($Index.Value -lt $Text.Length -and $Text[$Index.Value] -eq ']') {
                $Index.Value++
                return
            }
            while ($true) {
                Test-CustomerExportJsonValue -Text $Text -Index $Index
                Skip-CustomerExportJsonWhitespace -Text $Text -Index $Index
                if ($Index.Value -ge $Text.Length) {
                    throw 'Customer export manifest is not valid JSON.'
                }
                if ($Text[$Index.Value] -eq ']') {
                    $Index.Value++
                    return
                }
                if ($Text[$Index.Value] -ne ',') {
                    throw 'Customer export manifest is not valid JSON.'
                }
                $Index.Value++
                Skip-CustomerExportJsonWhitespace -Text $Text -Index $Index
            }
        }
        '"' {
            [void](Read-CustomerExportJsonString -Text $Text -Index $Index)
            return
        }
        't' {
            if ($Text.Substring($Index.Value, [Math]::Min(4, $Text.Length - $Index.Value)) -cne 'true') {
                throw 'Customer export manifest is not valid JSON.'
            }
            $Index.Value += 4
            return
        }
        'f' {
            if ($Text.Substring($Index.Value, [Math]::Min(5, $Text.Length - $Index.Value)) -cne 'false') {
                throw 'Customer export manifest is not valid JSON.'
            }
            $Index.Value += 5
            return
        }
        'n' {
            if ($Text.Substring($Index.Value, [Math]::Min(4, $Text.Length - $Index.Value)) -cne 'null') {
                throw 'Customer export manifest is not valid JSON.'
            }
            $Index.Value += 4
            return
        }
        default {
            if ($Text[$Index.Value] -match '[-0-9]') {
                Skip-CustomerExportJsonNumber -Text $Text -Index $Index
                return
            }
            throw 'Customer export manifest is not valid JSON.'
        }
    }
}

function ConvertTo-CustomerExportJsonValue {
    param([AllowNull()][object]$Value)

    if ($null -eq $Value) { return $null }
    if ($Value -is [psobject] -and $Value.PSObject.Properties.Count -gt 0 -and $Value -isnot [string]) {
        $ordered = [ordered]@{}
        foreach ($property in $Value.PSObject.Properties) {
            if ($property.MemberType -in @('NoteProperty', 'Property', 'ScriptProperty')) {
                $ordered[$property.Name] = ConvertTo-CustomerExportJsonValue -Value $property.Value
            }
        }
        if ($ordered.Count -gt 0) {
            return [pscustomobject]$ordered
        }
    }
    if ($Value -is [System.Collections.IDictionary]) {
        $ordered = [ordered]@{}
        foreach ($key in $Value.Keys) {
            $ordered[[string]$key] = ConvertTo-CustomerExportJsonValue -Value $Value[$key]
        }
        return [pscustomobject]$ordered
    }
    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
        return @(
            foreach ($item in @($Value)) {
                ConvertTo-CustomerExportJsonValue -Value $item
            }
        )
    }
    return $Value
}

function ConvertFrom-CustomerExportJson {
    param([Parameter(Mandatory)][string]$Text)

    $index = 0
    Test-CustomerExportJsonValue -Text $Text -Index ([ref]$index)
    Skip-CustomerExportJsonWhitespace -Text $Text -Index ([ref]$index)
    if ($index -ne $Text.Length) {
        throw 'Customer export manifest is not valid JSON.'
    }

    $json = if ($PSVersionTable.PSVersion.Major -ge 6) {
        ConvertFrom-Json -InputObject $Text -Depth 100
    }
    else {
        ConvertFrom-Json -InputObject $Text
    }
    return ConvertTo-CustomerExportJsonValue -Value $json
}

function Test-CustomerExportPathHasEvidenceSegment {
    param([Parameter(Mandatory)][string]$Path)
    @($Path -split '/') | Where-Object { [string]::Equals($_, 'evidence', [StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1
}

function Import-CustomerExportManifest {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][string]$Path
    )

    $manifest = ConvertFrom-CustomerExportJson -Text (Read-CustomerExportUtf8Text -Path $Path)
    $rootEntries = Get-ObjectEntryTable -InputObject $manifest
    $requiredRootProperties = @(
        'schemaVersion', 'tenantAlias', 'customerScope', 'retainedTenantArtifacts',
        'replacements', 'residualMarkers', 'sourceMarkerCatalog', 'residualDispositions',
        'syntheticDataPolicy', 'fileClassifications', 'inspectableBinaries', 'validationSuites'
    )
    Assert-RunbookClosedObject -InputObject $manifest -AllowedProperties $requiredRootProperties `
        -RequiredProperties $requiredRootProperties -ErrorMessage 'Customer export manifest is not closed.'
    if ([string]$manifest.schemaVersion -cne '1.0') {
        throw 'Customer export manifest schema version is not supported.'
    }

    $genericTerms = @('GitHub', 'Azure', 'Workday', 'Dataverse', 'Power Platform', 'SharePoint')
    $allowedRoots = @('infra/src/config/tenants/', 'infra/src/bicep/parameters/')
    $allowedMarkerCategories = @('TenantAlias', 'StableId', 'Domain', 'Url', 'EmailSuffix', 'CompanyName', 'OtherTenantIdentifier')
    $allowedComparisons = @('Ordinal', 'OrdinalIgnoreCase')
    $allowedSuites = @('Pester', 'RepositorySafety', 'BicepBuild')
    $allowedReservedDomains = @('example.com', 'example.org', 'example.net', 'example.invalid')

    foreach ($artifact in @($manifest.retainedTenantArtifacts)) {
        Assert-RunbookClosedObject -InputObject $artifact `
            -AllowedProperties @('path', 'artifactKind', 'customerScope') `
            -RequiredProperties @('path', 'artifactKind', 'customerScope') `
            -ErrorMessage 'Customer export retainedTenantArtifacts entry is not closed.'
        $artifact.path = Assert-CustomerExportRelativePath -Path ([string]$artifact.path)
        if ((Test-CustomerExportPathHasEvidenceSegment -Path $artifact.path) -or
            $artifact.path.StartsWith('infra/evidence/', [StringComparison]::OrdinalIgnoreCase)) {
            throw 'Customer export retained tenant artifacts cannot include evidence.'
        }
        if (@($allowedRoots | Where-Object { $artifact.path.StartsWith($_, [StringComparison]::Ordinal) }).Count -eq 0) {
            throw 'Customer export retained tenant artifacts must use an exact allowed root.'
        }
    }

    foreach ($rule in @($manifest.replacements)) {
        $format = [string]$rule.format
        switch ($format) {
            'Json' {
                Assert-RunbookClosedObject -InputObject $rule `
                    -AllowedProperties @('id', 'path', 'format', 'selector', 'expectedOldValue', 'newValue', 'requiredCount') `
                    -RequiredProperties @('id', 'path', 'format', 'selector', 'expectedOldValue', 'newValue', 'requiredCount') `
                    -ErrorMessage 'Customer export replacement is not closed.'
                $rule.path = Assert-CustomerExportRelativePath -Path ([string]$rule.path)
                if (-not $rule.path.EndsWith('.json', [StringComparison]::Ordinal)) {
                    throw 'Customer export Json replacements require an exact .json path.'
                }
                if ([string]$rule.selector -notmatch '^/' -or [string]$rule.selector -match '\*$|\?' ) {
                    throw 'Customer export Json selector must be an RFC 6901 JSON Pointer.'
                }
                if ([int]$rule.requiredCount -ne 1) {
                    throw 'Customer export Json replacements require requiredCount = 1.'
                }
            }
            'MarkdownExact' {
                Assert-RunbookClosedObject -InputObject $rule `
                    -AllowedProperties @('id', 'path', 'format', 'expectedOldText', 'newText', 'requiredCount') `
                    -RequiredProperties @('id', 'path', 'format', 'expectedOldText', 'newText', 'requiredCount') `
                    -ErrorMessage 'Customer export replacement is not closed.'
                $rule.path = Assert-CustomerExportRelativePath -Path ([string]$rule.path)
                if (-not $rule.path.EndsWith('.md', [StringComparison]::Ordinal)) {
                    throw 'Customer export MarkdownExact replacements require an exact .md path.'
                }
                if ([string]::IsNullOrEmpty([string]$rule.expectedOldText) -or
                    [string]::IsNullOrEmpty([string]$rule.newText) -or
                    [string]$rule.expectedOldText -ceq [string]$rule.newText) {
                    throw 'Customer export MarkdownExact replacements require distinct exact text values.'
                }
                if ([int]$rule.requiredCount -lt 1) {
                    throw 'Customer export MarkdownExact replacements require a positive occurrence count.'
                }
            }
            default {
                throw 'Customer export replacement format is not supported.'
            }
        }

        if ([string]$rule.id -notmatch '^[a-z][a-z0-9-]{2,63}$') {
            throw 'Customer export replacement IDs must match the required pattern.'
        }
        if ($rule.path.StartsWith('.github/workflows/', [StringComparison]::OrdinalIgnoreCase) -or
            $rule.path.StartsWith('.github/skills/', [StringComparison]::OrdinalIgnoreCase) -or
            $rule.path.StartsWith('infra/evidence/', [StringComparison]::OrdinalIgnoreCase) -or
            (Test-CustomerExportPathHasEvidenceSegment -Path $rule.path)) {
            throw 'Customer export manifest contains a prohibited replacement path.'
        }
    }

    $duplicateMarker = @($manifest.residualMarkers | Group-Object id | Where-Object Count -ne 1)
    $duplicateReplacementId = @($manifest.replacements | Group-Object id | Where-Object Count -ne 1)
    $duplicateReplacement = @(
        $manifest.replacements | Group-Object {
            if ($_.format -eq 'Json') {
                '{0}|Json|{1}' -f $_.path.ToLowerInvariant(), $_.selector
            }
            else {
                '{0}|MarkdownExact|{1}' -f $_.path.ToLowerInvariant(), (Get-RunbookContentDigest -InputObject $_.expectedOldText)
            }
        } | Where-Object Count -ne 1
    )
    if ($duplicateMarker -or $duplicateReplacementId -or $duplicateReplacement) {
        throw 'Marker IDs, replacement IDs, and replacement path/selectors must be unique.'
    }

    foreach ($marker in @($manifest.residualMarkers)) {
        Assert-RunbookClosedObject -InputObject $marker `
            -AllowedProperties @('id', 'category', 'value', 'comparison') `
            -RequiredProperties @('id', 'category', 'value', 'comparison') `
            -ErrorMessage 'Customer export residual marker is not closed.'
        if ($allowedMarkerCategories -notcontains [string]$marker.category -or
            $allowedComparisons -notcontains [string]$marker.comparison) {
            throw 'Customer export residual marker uses an unsupported category or comparison.'
        }
        if ([string]$marker.value -in $genericTerms) {
            throw 'Generic platform and architecture terms cannot be tenant residual markers.'
        }
    }

    foreach ($entry in @($manifest.sourceMarkerCatalog)) {
        Assert-RunbookClosedObject -InputObject $entry `
            -AllowedProperties @('id', 'category', 'value', 'comparison', 'sources') `
            -RequiredProperties @('id', 'category', 'value', 'comparison', 'sources') `
            -ErrorMessage 'Customer export sourceMarkerCatalog entry is not closed.'
        if ($allowedMarkerCategories -notcontains [string]$entry.category -or
            $allowedComparisons -notcontains [string]$entry.comparison -or
            @($entry.sources).Count -lt 1) {
            throw 'Customer export sourceMarkerCatalog entry is invalid.'
        }
        foreach ($source in @($entry.sources)) {
            Assert-RunbookClosedObject -InputObject $source `
                -AllowedProperties @('path', 'blobSha256', 'occurrenceCount') `
                -RequiredProperties @('path', 'blobSha256', 'occurrenceCount') `
                -ErrorMessage 'Customer export sourceMarkerCatalog source is not closed.'
            $source.path = Assert-CustomerExportRelativePath -Path ([string]$source.path)
            if ([string]$source.blobSha256 -notmatch '^[0-9a-f]{64}$' -or [int]$source.occurrenceCount -lt 1) {
                throw 'Customer export sourceMarkerCatalog source is invalid.'
            }
        }
    }

    $catalogKeys = @($manifest.sourceMarkerCatalog | ForEach-Object {
        '{0}|{1}|{2}|{3}' -f $_.id, $_.category, $_.comparison, $_.value
    } | Sort-Object -Unique)
    $residualKeys = @($manifest.residualMarkers | ForEach-Object {
        '{0}|{1}|{2}|{3}' -f $_.id, $_.category, $_.comparison, $_.value
    } | Sort-Object -Unique)
    if ($catalogKeys.Count -ne @($manifest.sourceMarkerCatalog).Count -or
        $residualKeys.Count -ne @($manifest.residualMarkers).Count -or
        ($catalogKeys -join "`n") -cne ($residualKeys -join "`n")) {
        throw 'Customer export sourceMarkerCatalog and residualMarkers must exactly match.'
    }

    $markerIds = @($manifest.residualMarkers | ForEach-Object { [string]$_.id })
    foreach ($disposition in @($manifest.residualDispositions)) {
        Assert-RunbookClosedObject -InputObject $disposition `
            -AllowedProperties @('path', 'markerId', 'reason') `
            -RequiredProperties @('path', 'markerId', 'reason') `
            -ErrorMessage 'Customer export residual disposition is not closed.'
        $disposition.path = Assert-CustomerExportRelativePath -Path ([string]$disposition.path) -ErrorMessage 'Customer export residual dispositions require an exact path.'
        if ($markerIds -notcontains [string]$disposition.markerId) {
            throw 'Customer export residual disposition references an unknown marker ID.'
        }
    }

    Assert-RunbookClosedObject -InputObject $manifest.syntheticDataPolicy `
        -AllowedProperties @('reservedNames', 'reservedDomains', 'reservedIdPrefixes') `
        -RequiredProperties @('reservedNames', 'reservedDomains', 'reservedIdPrefixes') `
        -ErrorMessage 'Customer export syntheticDataPolicy is not closed.'
    if (@($manifest.syntheticDataPolicy.reservedNames | Select-Object -Unique).Count -ne @($manifest.syntheticDataPolicy.reservedNames).Count) {
        throw 'Customer export reservedNames must be unique.'
    }
    foreach ($domain in @($manifest.syntheticDataPolicy.reservedDomains)) {
        if ($allowedReservedDomains -notcontains [string]$domain) {
            throw 'Customer export reservedDomains must use only reserved example domains.'
        }
    }
    foreach ($prefix in @($manifest.syntheticDataPolicy.reservedIdPrefixes)) {
        if ([string]$prefix -notmatch '^synthetic-[a-z0-9-]*$') {
            throw 'Customer export reservedIdPrefixes must use the synthetic- prefix.'
        }
    }

    $classificationPaths = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($classification in @($manifest.fileClassifications)) {
        Assert-RunbookClosedObject -InputObject $classification `
            -AllowedProperties @('path', 'sourceBlobSha256', 'expectedOutputSha256', 'classification', 'reason') `
            -RequiredProperties @('path', 'sourceBlobSha256', 'expectedOutputSha256', 'classification', 'reason') `
            -ErrorMessage 'Customer export fileClassifications entry is not closed.'
        $classification.path = Assert-CustomerExportRelativePath -Path ([string]$classification.path)
        if (-not $classificationPaths.Add($classification.path)) {
            throw 'Customer export fileClassifications must use unique exact paths.'
        }
        if ([string]$classification.sourceBlobSha256 -notmatch '^[0-9a-f]{64}$' -or
            [string]$classification.expectedOutputSha256 -notmatch '^[0-9a-f]{64}$') {
            throw 'Customer export fileClassifications require exact source and expected output digests.'
        }
        switch ([string]$classification.classification) {
            'SyntheticFixture' {
                if (-not $classification.path.StartsWith('infra/tests/fixtures/', [StringComparison]::Ordinal)) {
                    throw 'Customer export SyntheticFixture classifications are allowed only below infra/tests/fixtures/.'
                }
            }
            'ReviewedNonPersonal' {
                if ($classification.path.StartsWith('data/', [StringComparison]::OrdinalIgnoreCase) -or
                    $classification.path.StartsWith('infra/evidence/', [StringComparison]::OrdinalIgnoreCase) -or
                    (Test-CustomerExportPathHasEvidenceSegment -Path $classification.path) -or
                    $classification.path.StartsWith('infra/tests/fixtures/', [StringComparison]::Ordinal)) {
                    throw 'Customer export ReviewedNonPersonal classifications cannot target data, evidence, or fixture paths.'
                }
            }
            default {
                throw 'Customer export file classification is not supported.'
            }
        }
    }

    foreach ($binary in @($manifest.inspectableBinaries)) {
        Assert-RunbookClosedObject -InputObject $binary `
            -AllowedProperties @('path', 'sha256', 'reason') `
            -RequiredProperties @('path', 'sha256', 'reason') `
            -ErrorMessage 'Customer export inspectable binary entry is not closed.'
        $binary.path = Assert-CustomerExportRelativePath -Path ([string]$binary.path)
        if ([string]$binary.sha256 -notmatch '^[0-9a-f]{64}$') {
            throw 'Customer export inspectable binaries require lowercase SHA-256 digests.'
        }
    }

    if ((Get-RunbookContentDigest -InputObject @($manifest.validationSuites)) -cne
        (Get-RunbookContentDigest -InputObject $allowedSuites)) {
        throw 'Customer export validationSuites must exactly match the fixed local suite IDs.'
    }

    return $manifest
}
