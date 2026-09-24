[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-z0-9]+$')]
    [string]$TenantAlias,

    [ValidateSet('Dev', 'Test', 'Prod')]
    [string]$Stage = 'Dev'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-ModuleManifestPath {
    Join-Path $PSScriptRoot 'modules\Caldova.HrFrontier.Solutions\Caldova.HrFrontier.Solutions.psd1'
}

Import-Module (Get-ModuleManifestPath) -Force

Connect-HrPowerPlatformEnvironment -TenantAlias $TenantAlias -Stage $Stage
