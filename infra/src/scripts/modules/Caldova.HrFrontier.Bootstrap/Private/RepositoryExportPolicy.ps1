function Get-RepositoryExportPathIdentity {
    param([Parameter(Mandatory)][string]$Path)
    $full = [IO.Path]::GetFullPath($Path)
    if ($full -cne [IO.Path]::GetPathRoot($full)) { $full = $full.TrimEnd('\', '/') }
    Get-RunbookContentDigest -InputObject $full.ToLowerInvariant()
}

function Get-RepositoryExportAncestorIdentities {
    param([Parameter(Mandatory)][string]$Path)
    $cursor = [IO.Path]::GetFullPath($Path)
    while (-not [string]::IsNullOrWhiteSpace($cursor)) {
        Get-RepositoryExportPathIdentity -Path $cursor
        $parent = Split-Path -Parent $cursor
        if ($parent -ceq $cursor) { break }
        $cursor = $parent
    }
}

function Assert-RepositoryExportLocalPath {
    param([Parameter(Mandatory)][string]$Path)
    if (-not [IO.Path]::IsPathRooted($Path) -or $Path -notmatch '^[A-Za-z]:\\' -or
        $Path.Substring(2).Contains(':')) {
        throw 'Repository export requires an absolute local path.'
    }
    $cursor = [IO.Path]::GetFullPath($Path)
    while (-not [string]::IsNullOrWhiteSpace($cursor)) {
        if (Test-Path -LiteralPath $cursor) {
            if (((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw 'Repository export paths must not traverse a reparse point.'
            }
        }
        $parent = Split-Path -Parent $cursor
        if ($parent -ceq $cursor) { break }
        $cursor = $parent
    }
}

function Get-RepositoryExportPathDenial {
    param([string]$Path, [object]$Manifest, [string]$Profile)

    foreach ($deny in @($Manifest.deniedPaths)) {
        if ($Path.Equals($deny, [StringComparison]::OrdinalIgnoreCase) -or
            $Path.StartsWith("$deny/", [StringComparison]::OrdinalIgnoreCase)) { return 'ExactPathDenied' }
    }
    $segments = @($Path -split '/')
    if (@($segments | Where-Object { $_ -imatch '^(\.git|\.hg|\.svn)$' }).Count -gt 0) { return 'SourceHistoryDenied' }
    if ($Profile -ceq 'CustomerHandover' -and $Path.StartsWith('.github/workflows/', [StringComparison]::OrdinalIgnoreCase)) { return 'WorkflowBoundary' }
    if (@($segments | Where-Object { $_ -imatch '^(evidence|artifacts|backups|approvals|\.azure|\.pac|\.credentials)$' }).Count -gt 0) { return 'PrivateArtifactDenied' }
    if ($Path -imatch '(^|/)[^/]*(\.local\.|\.bak$|\.backup$)' -or
        $Path -imatch '(^|/)(approvals|discovery|transition|provider[-.]?(output|response)|deployment[-.]?output|generated[-.]?parameters|authentication|pac[-.]?profiles)([./-]|$)' -or
        $Path -imatch '(^|/)(runs|run-roots|generated-parameters)/') { return 'PrivateArtifactDenied' }
    if ($Path.StartsWith('infra/src/config/tenants/', [StringComparison]::OrdinalIgnoreCase) -or
        $Path.StartsWith('infra/src/bicep/parameters/', [StringComparison]::OrdinalIgnoreCase)) {
        # Only exact reviewed synthetic templates can survive; discovery/transition payloads never can.
        $retained = @($Manifest.retainedTenantArtifacts | Where-Object { $_.path -ceq $Path })
        if ($retained.Count -ne 1 -or $Path -imatch '(transition|discovery|\.local\.)') { return 'TenantArtifactDeniedByDefault' }
    }
    return $null
}

function Get-RepositoryExportActionOrder {
    @('snapshot-source', 'stage-committed-blobs', 'apply-exact-transformations', 'validate-profile',
        'promote-destination', 'snapshot-source-post', 'validate-independent')
}

function Get-RepositoryExportManifestPolicyDigests {
    param([Parameter(Mandatory)][object]$Manifest)
    $fields = [ordered]@{
        manifestDigest = $null
        retainPolicyDigest = 'retainedTenantArtifacts'
        denyPolicyDigest = 'deniedPaths'
        markerPolicyDigest = 'residualMarkers'
        replacementPolicyDigest = 'replacements'
        residualPolicyDigest = 'residualDispositions'
        profilePolicyDigest = 'profilePolicy'
        classificationPolicyDigest = 'fileClassifications'
        binaryPolicyDigest = 'inspectableBinaries'
        syntheticPolicyDigest = 'syntheticDataPolicy'
        suitePolicyDigest = 'validationSuites'
    }
    $digests = [ordered]@{}
    foreach ($name in $fields.Keys) {
        $value = $Manifest
        if ($null -ne $fields[$name]) { $value = $Manifest.($fields[$name]) }
        $digests[$name] = Get-RunbookContentDigest -InputObject $value
    }
    [pscustomobject]$digests
}

function Get-RepositoryExportActions {
    param([Parameter(Mandatory)][string]$DestinationStableId)
    foreach ($id in @(Get-RepositoryExportActionOrder)) {
        [pscustomobject][ordered]@{
            action = $id
            targetId = $DestinationStableId
            service = 'LocalRepositoryExport'
            method = $id
            expectedPostcondition = 'The exact assessed profile contract is satisfied without source mutation.'
        }
    }
}
