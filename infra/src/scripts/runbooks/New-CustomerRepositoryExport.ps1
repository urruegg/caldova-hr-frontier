[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)][string]$SourceRoot,
    [Parameter(Mandatory)][ValidatePattern('^[0-9a-fA-F]{40}$')][string]$ExpectedSourceCommit,
    [Parameter(Mandatory)][string]$DestinationRoot,
    [Parameter(Mandatory)][string]$ManifestPath,
    [string]$ReportPath,
    [string]$ExecutionManifestPath,
    [ValidatePattern('^[0-9a-fA-F]{64}$')][string]$ApprovedDigest,
    [switch]$Apply,
    [scriptblock]$NativeCommandRunner,
    [scriptblock]$CommandResolver,
    [scriptblock]$FileIdentityProvider,
    [scriptblock]$GitBlobReader,
    [scriptblock]$ValidationRunner,
    [scriptblock]$InteractiveHostProbe,
    [Parameter(DontShow)][scriptblock]$OperatorIdProvider,
    [Parameter(DontShow)][scriptblock]$PlatformProbe,
    [datetime]$NowUtc = [datetime]::UtcNow
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1') -Force
& (Get-Module Caldova.HrFrontier.Bootstrap) {
    param($arguments)
    Invoke-LegacyCustomerExport -Profile CustomerHandover @arguments
} $PSBoundParameters
