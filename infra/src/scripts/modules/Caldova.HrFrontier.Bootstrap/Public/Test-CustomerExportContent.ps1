function Get-CustomerExportValidationCommand {
    param(
        [Parameter(Mandatory)][string]$Suite,
        [Parameter(Mandatory)][object]$ToolIdentities
    )

    switch ($Suite) {
        'Pester' {
            return [pscustomobject]@{
                filePath = [string]$ToolIdentities.WindowsPowerShell.path
                arguments = @(
                    '-NoProfile',
                    '-Command',
                    'Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester infra/tests/pester,hr/tests/pester,.github/cli/tests -Output Detailed -CI'
                )
            }
        }
        'RepositorySafety' {
            return [pscustomobject]@{
                filePath = [string]$ToolIdentities.WindowsPowerShell.path
                arguments = @('-NoProfile', '-File', '.github/cli/verify-repository-safety.ps1')
            }
        }
        'BicepBuild' {
            return [pscustomobject]@{
                filePath = [string]$ToolIdentities.AzureCli.path
                arguments = @('bicep', 'build', '--file', 'infra/src/bicep/main.bicep', '--stdout')
            }
        }
        default {
            throw "Customer export validation suite '$Suite' is not supported."
        }
    }
}

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
    if ($Manifest -is [array] -or ($Manifest -isnot [Collections.IDictionary] -and $Manifest -isnot [pscustomobject])) {
        throw 'Customer export content requires an object manifest.'
    }
    $profile = 'CustomerHandover'
    $assessmentNames = @(Get-RunbookObjectPropertyNames -InputObject $Assessment)
    $manifestNames = @(Get-RunbookObjectPropertyNames -InputObject $Manifest)
    if ($manifestNames -cnotcontains 'profile' -and
        ($manifestNames -icontains 'profile' -or $assessmentNames -ccontains 'profile')) {
        throw 'Canonical content validation requires an explicit profile manifest.'
    }
    if ($manifestNames -ccontains 'profile') {
        $profile = [string]$Manifest.profile
        Assert-RepositoryExportManifestContract -Manifest $Manifest -ExpectedProfile $profile
        $fixedDigest = Get-RunbookContentDigest -InputObject (Get-RepositoryExportFixedPolicy -Profile $profile)
        $canonicalAssessment = $assessmentNames -ccontains 'profile'
        if (($profile -ceq 'TenantReplica' -or $canonicalAssessment) -and
            (-not $canonicalAssessment -or $Assessment.profile -cne $profile -or
            $assessmentNames -cnotcontains 'fixedPolicyDigest' -or
            $Assessment.fixedPolicyDigest -cne $fixedDigest -or
            $Assessment.manifestDigest -cne (Get-RunbookContentDigest -InputObject $Manifest))) {
            $failures.Add([pscustomobject]@{ category = 'ProfilePolicyMismatch'; path = $null })
        }
    }
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
    if ($profile -ceq 'TenantReplica') {
        foreach ($item in @(Get-ChildItem -LiteralPath $root -Recurse -Force)) {
            $path = Get-RunbookRelativePath -Root $root -Path $item.FullName
            $denial = Get-RepositoryExportPathDenial -Path $path -Manifest $Manifest -Profile $profile -Directory:$item.PSIsContainer
            if ($null -ne $denial) { $failures.Add([pscustomobject]@{ category = $denial; path = $path }) }
            if (-not $item.PSIsContainer -and $null -eq (Get-RepositoryExportCapability -Path $path -Manifest $Manifest)) {
                $failures.Add([pscustomobject]@{ category = 'AmbiguousArtifact'; path = $path })
            }
        }
        foreach ($required in @(Get-RepositoryExportRequiredPaths -Manifest $Manifest)) {
            if ($actualFiles -cnotcontains $required -or $expectedFiles -cnotcontains $required) {
                $failures.Add([pscustomobject]@{ category = 'RequiredCapabilityMissing'; path = $required })
            }
        }
        # Do not inspect metadata payloads, including staged synthetic .git files.
        if (@($failures | Where-Object category -CEQ 'GitMetadata').Count -gt 0) {
            return [pscustomobject]@{ status = 'Failed'; publishReady = $false; failures = @($failures) }
        }
    }

    if ([string]$ExecutionManifest.kind -cne 'CustomerExport' -or
        [string]$ExecutionManifest.target.type -cne 'CustomerExport' -or
        [string]$ExecutionManifest.target.stableId -cne [string]$Assessment.destinationStableId -or
        [string]$ExecutionManifest.assessmentDigest -cne [string]$Assessment.digest) {
        $failures.Add([pscustomobject]@{ category = 'ExecutionManifestMismatch'; path = $null })
    }

    $residuals = Get-CustomerExportResidual -StagingRoot $root -Markers @($Manifest.residualMarkers) `
        -Dispositions @($Manifest.residualDispositions) -InspectableBinaries @($Manifest.inspectableBinaries) -Profile $profile
    foreach ($residual in @($residuals | Where-Object disposition -eq 'Undisposed')) {
        $category = if ($residual.reason -ceq 'TenantStableIdentifier') { 'TenantStableIdentifier' } else { 'UndisposedResidual' }
        $failures.Add([pscustomobject]@{ category = $category; path = $residual.path; location = $residual.location; markerId = $residual.markerId })
    }

    $sourceCommit = if ($null -ne $Assessment.PSObject.Properties['sourceCommit'] -and -not [string]::IsNullOrWhiteSpace([string]$Assessment.sourceCommit)) {
        [string]$Assessment.sourceCommit
    }
    else {
        ('0' * 40)
    }
    $synthetic = Test-CustomerExportSyntheticData -StagingRoot $root -SourceCommit $sourceCommit `
        -SyntheticDataPolicy $Manifest.syntheticDataPolicy -FileClassifications @($Assessment.fileClassifications) `
        -FileDigests $Assessment.fileDigests -Manifest $Manifest
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
        $command = Get-CustomerExportValidationCommand -Suite ([string]$suite) -ToolIdentities $Assessment.toolIdentities
        if (-not [IO.Path]::IsPathRooted([string]$command.filePath)) {
            throw "Customer export validation suite '$suite' resolved a non-rooted executable path."
        }
        $result = & $ValidationRunner $suite $command.filePath @($command.arguments) $root
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
