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
            Where-Object { $_.BaseName -cne $TenantAliasToKeep -and $_.BaseName -cne '_template' } |
            ForEach-Object { $artifacts.Add($_.FullName) }
    }

    if (Test-Path -LiteralPath $evidenceRoot) {
        Get-ChildItem -LiteralPath $evidenceRoot -Filter '*.json' -File |
            Where-Object { $_.BaseName -cne $TenantAliasToKeep } |
            ForEach-Object { $artifacts.Add($_.FullName) }
    }

    if (Test-Path -LiteralPath $bicepParamsRoot) {
        Get-ChildItem -LiteralPath $bicepParamsRoot -Filter '*.bicepparam' -File |
            Where-Object { $_.BaseName -cne $TenantAliasToKeep } |
            ForEach-Object { $artifacts.Add($_.FullName) }
    }

    $artifacts.ToArray()
}

$resolvedRepositoryRoot = if ([string]::IsNullOrWhiteSpace($RepositoryRootOverride)) {
    Get-RepositoryRoot
}
else {
    [System.IO.Path]::GetFullPath($RepositoryRootOverride)
}

$artifacts = @(Get-OtherTenantArtifacts -TenantAliasToKeep $TenantAliasToKeep -RepositoryRoot $resolvedRepositoryRoot)

foreach ($artifact in $artifacts) {
    $relativePath = $artifact.Substring($resolvedRepositoryRoot.Length).TrimStart('\', '/')
    if ($PSCmdlet.ShouldProcess($relativePath, 'Remove other-tenant artifact')) {
        Remove-Item -LiteralPath $artifact -Force
    }
}

$artifacts
