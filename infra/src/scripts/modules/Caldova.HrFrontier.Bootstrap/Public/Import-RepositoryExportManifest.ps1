function Assert-RepositoryExportManifestContract {
    param(
        [Parameter(Mandatory)][object]$Manifest,
        [Parameter(Mandatory)][string]$ExpectedProfile
    )

    $legacyFields = @(Get-CustomerExportManifestFields)
    $fields = @($legacyFields) + @('profile', 'profilePolicy', 'deniedPaths')
    Assert-CustomerExportClosedObject -InputObject $Manifest -AllowedProperties $fields `
        -RequiredProperties $fields -ErrorMessage 'Repository export profile manifest is not closed.'
    if ($ExpectedProfile -cnotin @('TenantReplica', 'CustomerHandover') -or
        $Manifest.profile -isnot [string] -or
        $Manifest.profile -cnotin @('TenantReplica', 'CustomerHandover') -or
        $Manifest.profile -cne $ExpectedProfile) {
        throw 'Repository export profile does not match the expected explicit profile.'
    }

    $policyFields = @(
        'denyWorkflows', 'denyEvidence', 'denyTenantTransitions',
        'denyPrivateState', 'denySourceHistory', 'denyUntrackedFiles'
    )
    Assert-CustomerExportClosedObject -InputObject $Manifest.profilePolicy -AllowedProperties $policyFields `
        -RequiredProperties $policyFields -ErrorMessage 'Repository export profile policy is not closed.'
    foreach ($name in $policyFields) {
        $expected = if ($name -ceq 'denyWorkflows') { $Manifest.profile -ceq 'CustomerHandover' } else { $true }
        if ($Manifest.profilePolicy.$name -isnot [bool] -or $Manifest.profilePolicy.$name -ne $expected) {
            throw 'Repository export profile policy cannot be changed.'
        }
    }

    $legacy = [ordered]@{}
    foreach ($name in $legacyFields) {
        $legacy[$name] = $Manifest.$name
    }
    Assert-CustomerExportManifestContract -Manifest ([pscustomobject]$legacy)

    if ($Manifest.deniedPaths -isnot [array]) {
        throw 'Repository export deniedPaths must be an array of exact paths.'
    }
    $denied = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($path in $Manifest.deniedPaths) {
        Assert-SchemaString -Value $path -Schema ([pscustomobject]@{ minLength = 1 }) -Path 'Export.deniedPaths'
        $exact = Assert-CustomerExportRelativePath -Path $path
        if (-not $denied.Add($exact)) {
            throw 'Repository export deniedPaths must be unique exact paths.'
        }
    }

    $retained = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($artifact in $Manifest.retainedTenantArtifacts) {
        if (-not $retained.Add($artifact.path)) {
            throw 'Repository export retained artifacts must be unique exact paths.'
        }
    }
    $usedPaths = @($Manifest.retainedTenantArtifacts | ForEach-Object path) +
        @($Manifest.replacements | ForEach-Object path) +
        @($Manifest.residualDispositions | ForEach-Object path) +
        @($Manifest.fileClassifications | ForEach-Object path) +
        @($Manifest.inspectableBinaries | ForEach-Object path)
    foreach ($path in $usedPaths) {
        foreach ($deny in $denied) {
            if ([string]::Equals($path, $deny, [StringComparison]::OrdinalIgnoreCase) -or
                $path.StartsWith("$deny/", [StringComparison]::OrdinalIgnoreCase) -or
                $deny.StartsWith("$path/", [StringComparison]::OrdinalIgnoreCase)) {
                throw 'Repository export retained and denied path rules contradict each other.'
            }
        }
    }
}

function Import-RepositoryExportManifest {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][ValidateSet('TenantReplica', 'CustomerHandover')][string]$ExpectedProfile
    )

    if (-not [IO.Path]::IsPathRooted($Path) -or $Path -notmatch '^[A-Za-z]:[\\/]') {
        throw 'Repository export manifest requires an absolute local file path.'
    }
    $manifest = ConvertFrom-CustomerExportJson -Text (Read-CustomerExportUtf8Text -Path $Path)
    Assert-RepositoryExportManifestContract -Manifest $manifest -ExpectedProfile $ExpectedProfile
    return $manifest
}
