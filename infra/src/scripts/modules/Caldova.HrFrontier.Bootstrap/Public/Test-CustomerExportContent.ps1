function Test-CustomerExportContent {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][string]$StagingRoot,
        [Parameter(Mandatory)][object]$Manifest,
        [Parameter(Mandatory)][object]$Assessment,
        [Parameter(Mandatory)][object]$ExecutionManifest,
        [Parameter(Mandatory)][object]$CurrentSourceSnapshot,
        [AllowEmptyCollection()][object[]]$ReplacementLog = @(),
        [Parameter(Mandatory)][scriptblock]$ValidationRunner
    )

    $root = [IO.Path]::GetFullPath($StagingRoot)
    $failures = [Collections.Generic.List[object]]::new()
    $actualFiles = @(
        Get-ChildItem -LiteralPath $root -Recurse -File -Force |
            ForEach-Object { Get-RunbookRelativePath -Root $root -Path $_.FullName } |
            Sort-Object
    )
    $expectedFiles = @($Assessment.copyFiles | Sort-Object)
    foreach ($missing in @($expectedFiles | Where-Object { $actualFiles -notcontains $_ })) {
        $failures.Add([pscustomobject]@{ category = 'MissingFile'; path = $missing })
    }
    foreach ($extra in @($actualFiles | Where-Object { $expectedFiles -notcontains $_ })) {
        $failures.Add([pscustomobject]@{ category = 'UnexpectedFile'; path = $extra })
    }

    if ([string]$ExecutionManifest.kind -cne 'CustomerExport' -or
        [string]$ExecutionManifest.target.type -cne 'CustomerExport' -or
        [string]$ExecutionManifest.target.stableId -cne [string]$Assessment.destinationStableId -or
        [string]$ExecutionManifest.assessmentDigest -cne [string]$Assessment.digest) {
        $failures.Add([pscustomobject]@{ category = 'ExecutionManifestMismatch'; path = $null })
    }

    $residuals = Get-CustomerExportResidual -StagingRoot $root -Markers @($Manifest.residualMarkers) `
        -Dispositions @($Manifest.residualDispositions) -InspectableBinaries @($Manifest.inspectableBinaries)
    foreach ($residual in @($residuals | Where-Object disposition -eq 'Undisposed')) {
        $failures.Add([pscustomobject]@{ category = 'UndisposedResidual'; path = $residual.path; location = $residual.location; markerId = $residual.markerId })
    }

    $sourceCommit = if ($null -ne $Assessment.PSObject.Properties['sourceCommit'] -and -not [string]::IsNullOrWhiteSpace([string]$Assessment.sourceCommit)) {
        [string]$Assessment.sourceCommit
    }
    else {
        ('0' * 40)
    }
    $synthetic = Test-CustomerExportSyntheticData -StagingRoot $root -SourceCommit $sourceCommit `
        -SyntheticDataPolicy $Manifest.syntheticDataPolicy -FileClassifications @($Assessment.fileClassifications) `
        -FileDigests $Assessment.fileDigests
    if ([string]$synthetic.status -ne 'Passed') {
        foreach ($finding in @($synthetic.findings)) { $failures.Add($finding) }
    }

    $expectedRules = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($rule in @($Manifest.replacements)) { [void]$expectedRules.Add([string]$rule.id) }
    foreach ($entry in @($ReplacementLog)) {
        [void]$expectedRules.Remove([string]$entry.ruleId)
    }
    foreach ($missingRule in $expectedRules) {
        $failures.Add([pscustomobject]@{ category = 'ReplacementLogMissing'; path = $null; ruleId = $missingRule })
    }

    $suiteResults = [Collections.Generic.List[object]]::new()
    foreach ($suite in @($Manifest.validationSuites)) {
        $result = & $ValidationRunner $suite $Assessment.toolIdentities.WindowsPowerShell.path @() $root
        $suiteResults.Add($result)
        if ([int]$result.exitCode -ne 0) {
            $failures.Add([pscustomobject]@{ category = 'ValidationSuiteFailed'; path = $null; suite = $suite })
        }
    }

    return [pscustomobject]@{
        status = if ($failures.Count -eq 0) { 'Passed' } else { 'Failed' }
        publishReady = ($failures.Count -eq 0)
        inventory = [pscustomobject]@{ expected = $expectedFiles; actual = $actualFiles }
        residuals = @($residuals)
        failures = @($failures)
        suiteResults = @($suiteResults)
        replacementLog = @($ReplacementLog)
        classifications = @($synthetic.classifications)
        sourceSnapshot = $CurrentSourceSnapshot
    }
}
