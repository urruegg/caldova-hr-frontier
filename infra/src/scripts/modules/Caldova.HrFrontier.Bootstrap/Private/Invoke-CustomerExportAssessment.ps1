function Invoke-CustomerExportAssessment {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][string]$SourceRoot,
        [Parameter(Mandatory)][ValidatePattern('^[0-9a-fA-F]{40}$')][string]$ExpectedSourceCommit,
        [Parameter(Mandatory)][string]$DestinationRoot,
        [Parameter(Mandatory)][object]$Manifest,
        [Parameter(Mandatory)][ValidatePattern('^[0-9a-fA-F]{64}$')][string]$ManifestDigest,
        [Parameter(Mandatory)][object]$SourceSnapshot,
        [Parameter(Mandatory)][object]$ToolIdentities,
        [Parameter(Mandatory)][object]$MarkerCatalogProof,
        [Parameter(Mandatory)][object]$GitExecutable,
        [Parameter(Mandatory)][scriptblock]$GitBlobReader,
        [switch]$AllowExistingDestination,
        [ValidateSet('TenantReplica', 'CustomerHandover')][string]$Profile = 'CustomerHandover',
        [switch]$Canonical
    )

    $canonicalSource = [IO.Path]::GetFullPath($SourceRoot)
    $canonicalDestination = [IO.Path]::GetFullPath($DestinationRoot)

    if ((Test-RunbookPathWithin -Path $canonicalDestination -Root $canonicalSource) -or
        (Test-RunbookPathWithin -Path $canonicalSource -Root $canonicalDestination)) {
        throw 'Customer export destination must be outside the source repository.'
    }

    if (-not $AllowExistingDestination -and (Test-Path -LiteralPath $canonicalDestination)) {
        throw 'Customer export destination must not already exist.'
    }

    $cursor = if ($AllowExistingDestination -and $Canonical) { Split-Path $canonicalDestination -Parent } else { $canonicalDestination }
    while (-not [string]::IsNullOrWhiteSpace($cursor)) {
        if (Test-Path -LiteralPath $cursor) {
            $item = Get-Item -LiteralPath $cursor -Force
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw 'Customer export destination must not traverse a reparse point.'
            }
            if (Test-Path -LiteralPath (Join-Path $cursor '.git')) {
                throw 'Customer export destination must be outside every Git working tree.'
            }
        }
        $parent = Split-Path -Parent $cursor
        if ([string]::IsNullOrWhiteSpace($parent) -or $parent -ceq $cursor) { break }
        $cursor = $parent
    }

    $trackedByPath = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
    foreach ($tracked in @($SourceSnapshot.trackedFiles)) {
        if ($Canonical -and $Profile -ceq 'TenantReplica' -and
            @(([string]$tracked.path -split '/') | Where-Object { $_ -ieq '.git' }).Count -gt 0) {
            throw 'Repository export refuses GitMetadata in the committed inventory.'
        }
        $path = Test-CustomerExportRelativePath -Path ([string]$tracked.path)
        $trackedByPath[$path] = $tracked
    }

    $tenantRoots = @('infra/src/config/tenants/', 'infra/src/bicep/parameters/')
    $retained = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($artifact in @($Manifest.retainedTenantArtifacts)) {
        [void]$retained.Add((Test-CustomerExportRelativePath -Path ([string]$artifact.path)))
        if ($Canonical -and $Profile -ceq 'TenantReplica') {
            $denial = Get-RepositoryExportPathDenial -Path $artifact.path -Manifest $Manifest -Profile $Profile
            if ($null -ne $denial) { throw "Repository export retention contradicts $denial." }
            if (-not $trackedByPath.ContainsKey($artifact.path)) { throw 'Repository export retention requires a missing committed asset.' }
        }
    }
    if ($Canonical -and $Profile -ceq 'TenantReplica') {
        foreach ($required in @(Get-RepositoryExportRequiredPaths -Manifest $Manifest)) {
            [void]$retained.Add($required)
            if (-not $trackedByPath.ContainsKey($required)) { throw 'Repository export retention requires a missing committed asset.' }
        }
    }

    $fixtureClassifications = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
    $classificationByPath = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
    foreach ($classification in @($Manifest.fileClassifications)) {
        $classificationByPath[(Test-CustomerExportRelativePath -Path ([string]$classification.path))] = $classification
        if ([string]$classification.classification -ceq 'SyntheticFixture') {
            $fixtureClassifications[(Test-CustomerExportRelativePath -Path ([string]$classification.path))] = $classification
        }
    }

    $copyFiles = [Collections.Generic.List[string]]::new()
    $exclusions = [Collections.Generic.List[object]]::new()
    $fileDigests = [ordered]@{}
    foreach ($path in @($trackedByPath.Keys | Sort-Object)) {
        $reason = $null
        if ($Canonical) {
            $reason = Get-RepositoryExportPathDenial -Path $path -Manifest $Manifest -Profile $Profile
        }
        if ($null -eq $reason -and $Profile -ceq 'CustomerHandover' -and $path.StartsWith('.github/workflows/', [StringComparison]::OrdinalIgnoreCase)) {
            $reason = 'WorkflowBoundary'
        }
        elseif ($null -eq $reason -and $path.StartsWith('.git/', [StringComparison]::OrdinalIgnoreCase)) {
            $reason = 'GitMetadataDenied'
        }
        elseif ($null -eq $reason -and ($path.StartsWith('infra/evidence/', [StringComparison]::OrdinalIgnoreCase) -or
            @($path -split '/' | Where-Object { $_ -ieq 'evidence' }).Count -gt 0) -and $Profile -cne 'TenantReplica') {
            $reason = 'EvidenceAlwaysExcluded'
        }
        elseif ($null -eq $reason -and $path.StartsWith('data/', [StringComparison]::OrdinalIgnoreCase) -and
            -not ($Canonical -and $Profile -ceq 'TenantReplica' -and $path -ceq 'data/README.md')) {
            $reason = 'DataPathDenied'
        }
        elseif ($null -eq $reason -and ($path.StartsWith('infra/tests/fixtures/', [StringComparison]::Ordinal) -or
            ($Canonical -and $Profile -ceq 'TenantReplica' -and $path.StartsWith('hr/tests/fixtures/', [StringComparison]::Ordinal)))) {
            $classification = $null
            $fixtureClassifications.TryGetValue($path, [ref]$classification) | Out-Null
            if ($null -eq $classification -or [string]$classification.sourceBlobSha256 -cne [string]$trackedByPath[$path].blobSha256) {
                $reason = 'FixtureDeniedByDefault'
            }
        }
        elseif ($null -eq $reason -and @($tenantRoots | Where-Object { $path.StartsWith($_, [StringComparison]::Ordinal) }).Count -gt 0 -and
            -not $retained.Contains($path)) {
            $reason = 'TenantArtifactDeniedByDefault'
        }

        if ($null -ne $reason) {
            $exclusions.Add([pscustomobject]@{ path = $path; reason = $reason })
            continue
        }

        $originalBytes = [byte[]]@(& $GitBlobReader ([string]$GitExecutable.path) $canonicalSource $ExpectedSourceCommit.ToLowerInvariant() $path)
        $replacementRules = @($Manifest.replacements | Where-Object { ([string]$_.path) -ceq $path })
        $converted = Convert-CustomerExportBlob -Path $path -OriginalBytes $originalBytes -Rules $replacementRules
        if ($Canonical) {
            if ((Get-CustomerExportSha256 -Bytes $originalBytes) -cne [string]$trackedByPath[$path].blobSha256) {
                throw 'Repository export source blob identity drifted.'
            }
            Get-CustomerExportTextKind -Path $path -Bytes $converted.bytes -InspectableBinaries @($Manifest.inspectableBinaries) | Out-Null
            $residuals = @(Get-CustomerExportResidual -RelativePath $path -Bytes $converted.bytes `
                -Markers @($Manifest.residualMarkers) -Dispositions @($Manifest.residualDispositions) `
                -InspectableBinaries @($Manifest.inspectableBinaries) -Profile $Profile)
            if (@($residuals | Where-Object reason -CEQ 'TenantStableIdentifier').Count -gt 0) {
                throw 'Repository export contains TenantStableIdentifier in retained content.'
            }
            if (@($residuals | Where-Object disposition -CEQ 'Undisposed').Count -gt 0) {
                throw 'Repository export contains an unresolved residual.'
            }
            $capability = $null
            if ($Canonical -and $Profile -ceq 'TenantReplica') {
                $capability = Get-RepositoryExportCapability -Path $path -Manifest $Manifest
                if ($null -eq $capability) {
                    $exclusions.Add([pscustomobject]@{ path = $path; reason = 'AmbiguousArtifact' })
                    continue
                }
            }
        }
        $sourceBlobSha256 = [string]$trackedByPath[$path].blobSha256
        $expectedOutputSha256 = Get-CustomerExportSha256 -Bytes $converted.bytes
        $fileDigests[$path] = [pscustomobject]@{
            sourceBlobSha256 = $sourceBlobSha256
            expectedOutputSha256 = $expectedOutputSha256
        }

        $classification = $null
        $classificationByPath.TryGetValue($path, [ref]$classification) | Out-Null
        $classificationResult = Test-CustomerExportSyntheticBytes -Path $path -Bytes $converted.bytes -SyntheticDataPolicy $Manifest.syntheticDataPolicy

        if ([string]$classificationResult.status -ceq 'Failed') {
            throw 'Customer export expected output contains non-synthetic content.'
        }

        if ($null -ne $classification) {
            if ([string]$classification.sourceBlobSha256 -cne $sourceBlobSha256) {
                throw 'Customer export classification source digest does not match the tracked blob.'
            }
            if ([string]$classification.expectedOutputSha256 -cne $expectedOutputSha256) {
                throw 'Customer export classification expected output digest does not match the computed staged bytes.'
            }
        }

        if ([string]$classificationResult.status -ceq 'Inconclusive') {
            if ($null -eq $classification -or [string]$classification.classification -cne 'ReviewedNonPersonal') {
                if ($Canonical -and $Profile -ceq 'TenantReplica' -and ($retained.Contains($path) -or $capability -cne 'SyntheticExamples')) {
                    throw 'Repository export retention requires an exact nonpersonal classification.'
                }
                $exclusions.Add([pscustomobject]@{ path = $path; reason = 'ReviewedNonPersonalClassificationRequired' })
                continue
            }
        }

        $copyFiles.Add($path)
    }

    if ($Canonical -and $Profile -ceq 'TenantReplica') {
        foreach ($required in $retained) {
            if (-not $copyFiles.Contains($required)) {
                $denial = @($exclusions | Where-Object path -CEQ $required | Select-Object -ExpandProperty reason) -join ','
                throw "Repository export retention could not be satisfied: $denial."
            }
        }
    }
    foreach ($rule in @($Manifest.replacements)) {
        $path = Test-CustomerExportRelativePath -Path ([string]$rule.path)
        if (-not $trackedByPath.ContainsKey($path) -or -not ($copyFiles -contains $path)) {
            throw 'Customer export replacement paths must resolve to included tracked files.'
        }
    }

    $destinationStableId = 'customer-export:' + (Get-RunbookContentDigest -InputObject ([ordered]@{
        destinationRoot = $canonicalDestination.ToLowerInvariant()
    }))
    $replacementMetadata = @(
        $Manifest.replacements | Sort-Object path, id | ForEach-Object {
            [ordered]@{
                id = $_.id
                path = $_.path
                format = $_.format
                selector = if ($_.format -eq 'Json') { $_.selector } else { $null }
                requiredCount = $_.requiredCount
                ruleDigest = Get-RunbookContentDigest -InputObject $_
            }
        }
    )

    $allowedActions = @(
        [pscustomobject]@{
            action = 'CreateCustomerExport'
            targetId = $destinationStableId
            service = 'LocalFileSystem'
            method = 'CreateNewDisposableDirectory'
            expectedPostcondition = 'A new isolated disposable staging directory exists outside every Git working tree.'
        }
    )
    $allowedActions += @(
        $copyFiles | Sort-Object | ForEach-Object {
            [pscustomobject]@{
                action = 'CopyTrackedBlob'
                targetId = $_
                service = 'Git'
                method = 'ReadCommitBlob'
                sourceRelativePath = $_
                destinationRelativePath = $_
                expectedPostcondition = 'Destination bytes equal the tracked blob at the approved source commit.'
            }
        }
    )
    $allowedActions += @(
        $replacementMetadata | ForEach-Object {
            [pscustomobject]@{
                action = 'ApplyStructuredReplacement'
                targetId = '{0}#{1}' -f $_.path, $_.id
                service = 'LocalFileSystem'
                method = if ($_.format -eq 'Json') { 'JsonPointer' } else { 'MarkdownExact' }
                sourceRelativePath = $_.path
                destinationRelativePath = $_.path
                replacementRuleId = $_.id
                expectedPostcondition = 'The reviewed exact replacement count is satisfied and the replacement rule digest matches reviewed intent.'
            }
        }
    )
    $allowedActions += @(
        [pscustomobject]@{
            action = 'ValidateCustomerExport'
            targetId = $destinationStableId
            service = 'LocalValidation'
            method = 'FixedValidationSuites'
            expectedPostcondition = 'All inventory, residual, documentation, source immutability, and selected suite checks pass.'
        },
        [pscustomobject]@{
            action = 'PromoteCustomerExport'
            targetId = $destinationStableId
            service = 'LocalFileSystem'
            method = 'AtomicDirectoryMove'
            expectedPostcondition = 'Validated disposable staging is moved to the approved destination.'
        }
    )

    $unsignedAssessment = [ordered]@{
        schemaVersion = '1.0'
        sourceRoot = $canonicalSource
        sourceCommit = $ExpectedSourceCommit.ToLowerInvariant()
        destinationRoot = $canonicalDestination
        destinationStableId = $destinationStableId
        manifestDigest = $ManifestDigest.ToLowerInvariant()
        sourceSnapshot = $SourceSnapshot
        toolIdentities = $ToolIdentities
        markerCatalogProof = $MarkerCatalogProof
        fileClassifications = @(
            $Manifest.fileClassifications |
                Where-Object {
                    $resolved = Test-CustomerExportRelativePath -Path ([string]$_.path)
                    @($copyFiles).Contains($resolved)
                } |
                Sort-Object path
        )
        fileDigests = [pscustomobject]$fileDigests
        copyFiles = @($copyFiles | Sort-Object)
        exclusions = @($exclusions | Sort-Object path, reason)
        replacements = $replacementMetadata
        allowedActions = $allowedActions
    }
    if ($Canonical) {
        $unsignedAssessment.profile = $Profile
        $unsignedAssessment.fixedPolicyDigest = Get-RunbookContentDigest -InputObject (Get-RepositoryExportFixedPolicy -Profile $Profile)
    }

    $digest = Get-RunbookContentDigest -InputObject $unsignedAssessment
    $assessment = [ordered]@{}
    foreach ($entry in $unsignedAssessment.GetEnumerator()) {
        $assessment[$entry.Key] = $entry.Value
    }
    $assessment.digest = $digest
    return [pscustomobject]$assessment
}
