[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-z0-9]+$')]
    [string]$TenantAliasToKeep,

    [string]$RepositoryRootOverride
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-RepositoryRoot {
    [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
}

function Get-OtherTenantArtifacts {
    param(
        [Parameter(Mandatory)]
        [string]$TenantAliasToKeep,

        [Parameter(Mandatory)]
        [string]$RepositoryRoot
    )

    $manifestRoot = Join-Path $RepositoryRoot 'infra\src\config\tenants'
    $evidenceRoot = Join-Path $RepositoryRoot 'infra\evidence\discovery'
    $bicepParamsRoot = Join-Path $RepositoryRoot 'infra\src\bicep\params'

    $artifacts = [System.Collections.Generic.List[string]]::new()

    if (Test-Path -LiteralPath $manifestRoot) {
        Get-ChildItem -LiteralPath $manifestRoot -Filter '*.psd1' -File |
            Where-Object { $_.BaseName -ne $TenantAliasToKeep -and $_.BaseName -ne '_template' } |
            ForEach-Object { $artifacts.Add($_.FullName) }
    }

    if (Test-Path -LiteralPath $evidenceRoot) {
        Get-ChildItem -LiteralPath $evidenceRoot -Filter '*.json' -File |
            Where-Object { $_.BaseName -ne $TenantAliasToKeep } |
            ForEach-Object { $artifacts.Add($_.FullName) }
    }

    if (Test-Path -LiteralPath $bicepParamsRoot) {
        Get-ChildItem -LiteralPath $bicepParamsRoot -Filter '*.bicepparam' -File |
            Where-Object { $_.BaseName -ne $TenantAliasToKeep } |
            ForEach-Object { $artifacts.Add($_.FullName) }
    }

    $artifacts.ToArray()
}

$resolvedRepositoryRoot = if ([string]::IsNullOrWhiteSpace($RepositoryRootOverride)) {
    Get-RepositoryRoot
}
else {
    # Resolve against the caller's current PowerShell location, not the
    # process's current working directory -- these can differ, and a
    # relative override resolved the wrong way could silently target an
    # unintended directory.
    $PSCmdlet.GetUnresolvedProviderPathFromPSPath($RepositoryRootOverride)
}

$tenantManifestPath = Join-Path $resolvedRepositoryRoot "infra\src\config\tenants\$TenantAliasToKeep.psd1"
if (-not (Test-Path -LiteralPath $tenantManifestPath)) {
    throw "No manifest found for -TenantAliasToKeep '$TenantAliasToKeep' at '$tenantManifestPath'. Refusing to proceed -- an alias that does not match any tenant manifest would cause every tenant's files to be treated as 'other tenant' and removed."
}

$artifacts = @(Get-OtherTenantArtifacts -TenantAliasToKeep $TenantAliasToKeep -RepositoryRoot $resolvedRepositoryRoot)

foreach ($artifact in $artifacts) {
    $relativePath = $artifact.Substring($resolvedRepositoryRoot.Length).TrimStart('\', '/')
    if ($PSCmdlet.ShouldProcess($relativePath, 'Remove other-tenant artifact')) {
        Remove-Item -LiteralPath $artifact -Force
    }
}

$artifacts
