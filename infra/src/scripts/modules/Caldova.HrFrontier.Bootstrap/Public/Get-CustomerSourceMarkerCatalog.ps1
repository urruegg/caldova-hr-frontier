function Get-CustomerExportOccurrenceCount {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][string]$Needle,
        [Parameter(Mandatory)][string]$Comparison
    )

    $count = 0
    $offset = 0
    $comparisonType = if ($Comparison -ceq 'OrdinalIgnoreCase') {
        [StringComparison]::OrdinalIgnoreCase
    }
    else {
        [StringComparison]::Ordinal
    }
    while ($true) {
        $index = $Text.IndexOf($Needle, $offset, $comparisonType)
        if ($index -lt 0) { break }
        $count++
        $offset = $index + $Needle.Length
    }
    return $count
}

function ConvertFrom-CustomerExportUtf8Bytes {
    param([Parameter(Mandatory)][byte[]]$Bytes)

    if ($Bytes.Length -ge 3 -and $Bytes[0] -eq 0xEF -and $Bytes[1] -eq 0xBB -and $Bytes[2] -eq 0xBF) {
        throw 'Customer export tenant artifacts must be BOM-free UTF-8.'
    }
    return [Text.UTF8Encoding]::new($false, $true).GetString($Bytes)
}

function New-CustomerExportAutomaticCandidate {
    param(
        [Parameter(Mandatory)][string]$Category,
        [Parameter(Mandatory)][string]$Value,
        [Parameter(Mandatory)][string]$Comparison,
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$BlobSha256
    )

    [pscustomobject]@{
        category = $Category
        value = $Value
        comparison = $Comparison
        path = $Path
        blobSha256 = $BlobSha256
        occurrenceCount = 1
    }
}

function Get-CustomerExportKeyValueCandidatesFromJson {
    param(
        [AllowNull()][object]$Value,
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.ArrayList]$Candidates
    )

    if ($null -eq $Value) { return }
    if ($Value -is [System.Collections.IDictionary]) {
        foreach ($key in $Value.Keys) {
            $stringValue = $Value[$key]
            if ($stringValue -is [string]) {
                if ([string]$key -ceq 'TenantAlias') {
                    [void]$Candidates.Add(@{ key = [string]$key; value = $stringValue })
                }
                elseif ([string]$key -match 'Id$') {
                    [void]$Candidates.Add(@{ key = [string]$key; value = $stringValue })
                }
                elseif ($stringValue -match '^https://') {
                    [void]$Candidates.Add(@{ key = [string]$key; value = $stringValue })
                }
                elseif ($stringValue -match '(?i)\b[A-Z0-9._%+\-]+@([A-Z0-9.\-]+\.[A-Z]{2,})\b') {
                    [void]$Candidates.Add(@{ key = [string]$key; value = $stringValue })
                }
            }
            Get-CustomerExportKeyValueCandidatesFromJson -Value $Value[$key] -Candidates $Candidates
        }
        return
    }
    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
        foreach ($item in @($Value)) {
            Get-CustomerExportKeyValueCandidatesFromJson -Value $item -Candidates $Candidates
        }
    }
}

function Get-CustomerExportAutomaticCandidates {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$BlobSha256,
        [Parameter(Mandatory)][byte[]]$Bytes
    )

    $text = ConvertFrom-CustomerExportUtf8Bytes -Bytes $Bytes
    $rawCandidates = [System.Collections.ArrayList]::new()
    if ($Path.EndsWith('.json', [StringComparison]::OrdinalIgnoreCase)) {
        $parsed = ConvertFrom-CustomerExportJson -Text $text
        Get-CustomerExportKeyValueCandidatesFromJson -Value $parsed -Candidates $rawCandidates
    }
    elseif ($Path.EndsWith('.psd1', [StringComparison]::OrdinalIgnoreCase)) {
        foreach ($match in [regex]::Matches($text, "(?m)(?<key>[A-Za-z0-9_]+)\s*=\s*(?<value>'[^']*'|""[^""]*"")")) {
            $rawValue = $match.Groups['value'].Value
            $value = $rawValue.Substring(1, $rawValue.Length - 2)
            [void]$rawCandidates.Add(@{ key = $match.Groups['key'].Value; value = $value })
        }
    }

    $grouped = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
    foreach ($item in @($rawCandidates)) {
        $key = [string]$item.key
        $value = [string]$item.value
        $records = @()
        if ($key -ceq 'TenantAlias') {
            $records += (New-CustomerExportAutomaticCandidate -Category 'TenantAlias' -Value $value -Comparison 'OrdinalIgnoreCase' -Path $Path -BlobSha256 $BlobSha256)
        }
        if ($value -match '^[0-9a-fA-F-]{36}$') {
            $records += (New-CustomerExportAutomaticCandidate -Category 'StableId' -Value $value.ToLowerInvariant() -Comparison 'OrdinalIgnoreCase' -Path $Path -BlobSha256 $BlobSha256)
        }
        elseif ($key -match 'Id$') {
            $records += (New-CustomerExportAutomaticCandidate -Category 'OtherTenantIdentifier' -Value $value -Comparison 'Ordinal' -Path $Path -BlobSha256 $BlobSha256)
        }
        if ($value -match '^https://') {
            $records += (New-CustomerExportAutomaticCandidate -Category 'Url' -Value $value -Comparison 'Ordinal' -Path $Path -BlobSha256 $BlobSha256)
            $uri = [uri]$value
            $records += (New-CustomerExportAutomaticCandidate -Category 'Domain' -Value $uri.Host.ToLowerInvariant() -Comparison 'OrdinalIgnoreCase' -Path $Path -BlobSha256 $BlobSha256)
        }
        $emailMatches = [regex]::Matches($value, '(?i)\b[A-Z0-9._%+\-]+@(?<suffix>[A-Z0-9.\-]+\.[A-Z]{2,})\b')
        foreach ($emailMatch in $emailMatches) {
            $records += (New-CustomerExportAutomaticCandidate -Category 'EmailSuffix' -Value $emailMatch.Groups['suffix'].Value.ToLowerInvariant() -Comparison 'OrdinalIgnoreCase' -Path $Path -BlobSha256 $BlobSha256)
        }

        foreach ($record in $records) {
            $groupKey = '{0}|{1}|{2}|{3}|{4}' -f $record.category, $record.value, $record.comparison, $record.path, $record.blobSha256
            if ($grouped.ContainsKey($groupKey)) {
                $grouped[$groupKey].occurrenceCount++
            }
            else {
                $grouped[$groupKey] = $record
            }
        }
    }

    return @($grouped.Values | Sort-Object category, value, path)
}

function Get-CustomerSourceMarkerCatalog {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [Parameter(Mandatory)][ValidatePattern('^[0-9a-fA-F]{40}$')][string]$ExpectedSourceCommit,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$TrackedFiles,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$RetainedTenantArtifacts,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$SourceMarkerCatalog,
        [Parameter(Mandatory)][object]$GitExecutable,
        [Parameter(Mandatory)][scriptblock]$GitBlobReader
    )

    $repository = [IO.Path]::GetFullPath($RepositoryRoot)
    $trackedLookup = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
    foreach ($tracked in @($TrackedFiles)) {
        $path = Test-CustomerExportRelativePath -Path ([string]$tracked.path)
        $trackedLookup[$path] = $tracked
    }

    $reviewedAssertionsVerified = 0
    foreach ($marker in @($SourceMarkerCatalog)) {
        foreach ($source in @($marker.sources)) {
            $path = Test-CustomerExportRelativePath -Path ([string]$source.path)
            if (-not $trackedLookup.ContainsKey($path)) {
                throw 'Reviewed catalog source assertion does not match a tracked source path.'
            }
            $tracked = $trackedLookup[$path]
            [byte[]]$bytes = & $GitBlobReader ([string]$GitExecutable.path) $repository $ExpectedSourceCommit $path
            if ($null -eq $bytes) {
                throw 'Reviewed catalog source assertion blob could not be read.'
            }
            $blobSha = Get-CustomerExportSha256 -Bytes $bytes
            if ($blobSha -cne [string]$source.blobSha256 -or
                ($tracked.PSObject.Properties.Name -contains 'blobSha256' -and [string]$tracked.blobSha256 -cne $blobSha)) {
                throw 'Reviewed catalog source assertion is stale.'
            }
            $text = ConvertFrom-CustomerExportUtf8Bytes -Bytes $bytes
            $count = Get-CustomerExportOccurrenceCount -Text $text -Needle ([string]$marker.value) -Comparison ([string]$marker.comparison)
            if ($count -ne [int]$source.occurrenceCount -or $count -lt 1) {
                throw 'Reviewed catalog source assertion is stale.'
            }
            $reviewedAssertionsVerified++
        }
    }

    $tenantRoots = @('infra/src/config/tenants/', 'infra/src/bicep/parameters/')
    $automaticCandidates = @()
    foreach ($tracked in @($TrackedFiles)) {
        $path = Test-CustomerExportRelativePath -Path ([string]$tracked.path)
        if (@($tenantRoots | Where-Object { $path.StartsWith($_, [StringComparison]::Ordinal) }).Count -eq 0) {
            continue
        }
        [byte[]]$bytes = & $GitBlobReader ([string]$GitExecutable.path) $repository $ExpectedSourceCommit $path
        if ($null -eq $bytes) {
            throw 'Customer export planning found an uninspectable tenant artifact.'
        }
        $blobSha = Get-CustomerExportSha256 -Bytes $bytes
        $automaticCandidates += @(Get-CustomerExportAutomaticCandidates -Path $path -BlobSha256 $blobSha -Bytes $bytes)
    }

    foreach ($candidate in @($automaticCandidates)) {
        $matches = @(
            foreach ($marker in @($SourceMarkerCatalog)) {
                if ([string]$marker.category -cne [string]$candidate.category -or
                    [string]$marker.comparison -cne [string]$candidate.comparison -or
                    [string]$marker.value -cne [string]$candidate.value) {
                    continue
                }
                foreach ($source in @($marker.sources)) {
                    if ([string]$source.path -ceq [string]$candidate.path -and
                        [string]$source.blobSha256 -ceq [string]$candidate.blobSha256 -and
                        [int]$source.occurrenceCount -eq [int]$candidate.occurrenceCount) {
                        $source
                    }
                }
            }
        )
        if (@($matches).Count -ne 1) {
            throw 'Customer export planning found an unrepresented source marker.'
        }
    }

    return [pscustomobject][ordered]@{
        reviewedAssertionsVerified = $reviewedAssertionsVerified
        automaticCandidateCount = @($automaticCandidates).Count
        automaticCandidates = @($automaticCandidates)
        markerProjection = @(
            $SourceMarkerCatalog | ForEach-Object {
                [pscustomobject]@{
                    id = $_.id
                    category = $_.category
                    value = $_.value
                    comparison = $_.comparison
                }
            } | Sort-Object id, category, comparison, value
        )
    }
}
