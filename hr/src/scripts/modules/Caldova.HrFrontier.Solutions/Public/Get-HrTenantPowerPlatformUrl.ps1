function Get-HrTenantPowerPlatformUrl {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('^[a-z0-9]+$')]
        [string]$TenantAlias,

        [Parameter(Mandatory)]
        [ValidateSet('Dev', 'Test', 'Prod')]
        [string]$Stage,

        [string]$TenantConfigurationPath
    )

    $resolvedPath = if ([string]::IsNullOrWhiteSpace($TenantConfigurationPath)) {
        [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\..\..\..\..\..\infra\src\config\tenants\$TenantAlias.psd1"))
    }
    else {
        [System.IO.Path]::GetFullPath($TenantConfigurationPath)
    }

    if (-not (Test-Path -LiteralPath $resolvedPath -PathType Leaf)) {
        throw "Tenant manifest not found for '$TenantAlias': $resolvedPath. This function reads infra/src/config/tenants/ read-only and never creates a manifest."
    }

    $configuration = Import-PowerShellDataFile -LiteralPath $resolvedPath
    $urlPropertyName = "$($Stage)Url"
    $powerPlatform = $configuration.PowerPlatform
    if ($null -eq $powerPlatform -or -not $powerPlatform.Contains($urlPropertyName)) {
        throw "Tenant manifest for '$TenantAlias' does not define PowerPlatform.$urlPropertyName."
    }

    [string]$powerPlatform[$urlPropertyName]
}
