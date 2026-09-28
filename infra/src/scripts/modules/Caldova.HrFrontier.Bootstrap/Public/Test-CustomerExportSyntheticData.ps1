function Test-CustomerExportSyntheticData {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][string]$StagingRoot,
        [Parameter(Mandatory)][ValidatePattern('^[0-9a-fA-F]{40}$')][string]$SourceCommit,
        [Parameter(Mandatory)][object]$SyntheticDataPolicy,
        [AllowEmptyCollection()][object[]]$FileClassifications = @(),
        [Parameter(Mandatory)][object]$FileDigests
    )

    $root = [IO.Path]::GetFullPath($StagingRoot)
    $classifications = [Collections.Generic.List[object]]::new()
    $findings = [Collections.Generic.List[object]]::new()
    $classificationByPath = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
    foreach ($classification in @($FileClassifications)) {
        $classificationByPath[[string]$classification.path] = $classification
    }

    foreach ($file in Get-ChildItem -LiteralPath $root -Recurse -File -Force | Sort-Object FullName) {
        $relative = Get-RunbookRelativePath -Root $root -Path $file.FullName
        $segments = @($relative -split '/')
        if (@($segments | Where-Object { $_ -ieq 'data' -or $_ -ieq 'evidence' }).Count -gt 0) {
            $findings.Add([pscustomobject]@{ path = $relative; category = 'DeniedPath'; reason = 'data-or-evidence' })
            continue
        }

        $digestEntry = $null
        if ($FileDigests -is [hashtable]) {
            if ($FileDigests.ContainsKey($relative)) {
                $digestEntry = $FileDigests[$relative]
            }
        }
        elseif ($null -ne $FileDigests.PSObject.Properties[$relative]) {
            $digestEntry = $FileDigests.PSObject.Properties[$relative].Value
        }
        if ($null -eq $digestEntry) {
            $findings.Add([pscustomobject]@{ path = $relative; category = 'Digest'; reason = 'Missing file digest entry.' })
            continue
        }

        $classification = $null
        $classificationByPath.TryGetValue($relative, [ref]$classification) | Out-Null
        if ($relative.StartsWith('infra/tests/fixtures/', [StringComparison]::Ordinal)) {
            if ($null -ne $classification -and
                [string]$classification.classification -ceq 'SyntheticFixture' -and
                [string]$classification.sourceBlobSha256 -ceq [string]$digestEntry.sourceBlobSha256 -and
                [string]$classification.expectedOutputSha256 -ceq [string]$digestEntry.expectedOutputSha256 -and
                -not [string]::IsNullOrWhiteSpace([string]$classification.reason)) {
                $classifications.Add($classification)
                continue
            }

            $findings.Add([pscustomobject]@{ path = $relative; category = 'SyntheticFixture'; reason = 'Exact synthetic fixture classification required.' })
            continue
        }

        $bytes = [IO.File]::ReadAllBytes($file.FullName)
        $result = Test-CustomerExportSyntheticBytes -Path $relative -Bytes $bytes -SyntheticDataPolicy $SyntheticDataPolicy
        if ([string]$result.status -eq 'Failed') {
            foreach ($finding in @($result.findings)) { $findings.Add($finding) }
            continue
        }
        if ([string]$result.status -eq 'Inconclusive') {
            if ($null -ne $classification -and
                [string]$classification.classification -ceq 'ReviewedNonPersonal' -and
                [string]$classification.sourceBlobSha256 -ceq [string]$digestEntry.sourceBlobSha256 -and
                [string]$classification.expectedOutputSha256 -ceq [string]$digestEntry.expectedOutputSha256 -and
                -not [string]::IsNullOrWhiteSpace([string]$classification.reason)) {
                $classifications.Add($classification)
                continue
            }

            $findings.Add([pscustomobject]@{
                path = $relative
                category = 'ReviewedNonPersonalClassificationRequired'
                reason = 'Exact digest-bound reviewed classification required.'
            })
        }
    }

    return [pscustomobject]@{
        status = if ($findings.Count -eq 0) { 'Passed' } else { 'Failed' }
        findings = @($findings)
        classifications = @($classifications)
    }
}
