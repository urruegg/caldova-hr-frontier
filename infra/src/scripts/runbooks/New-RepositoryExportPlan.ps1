[CmdletBinding()]
param(
    [Parameter(Mandatory)][guid]$RunId,
    [Parameter(Mandatory)][string]$EvidenceRoot,
    [Parameter(Mandatory)][string]$SourceRoot,
    [Parameter(Mandatory)][ValidatePattern('^[0-9a-fA-F]{40}$')][string]$ExpectedSourceCommit,
    [Parameter(Mandatory)][string]$DestinationRoot,
    [Parameter(Mandatory)][string]$ManifestPath,
    [Parameter(Mandatory)][ValidateSet('TenantReplica', 'CustomerHandover')][string]$Profile,
    [Parameter(Mandatory)][ValidatePattern('^[0-9a-fA-F]{64}$')][string]$RepositoryIdentity,
    [Parameter(DontShow)][scriptblock]$NativeCommandRunner,
    [Parameter(DontShow)][scriptblock]$CommandResolver,
    [Parameter(DontShow)][scriptblock]$FileIdentityProvider,
    [Parameter(DontShow)][scriptblock]$GitBlobReader,
    [Parameter(DontShow)][scriptblock]$ValidationRunner,
    [Parameter(DontShow)][scriptblock]$InteractiveHostProbe,
    [Parameter(DontShow)][scriptblock]$OperatorIdProvider,
    [Parameter(DontShow)][scriptblock]$PlatformProbe,
    [Parameter(DontShow)][datetime]$NowUtc = [datetime]::UtcNow
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1') -Force
Invoke-RepositoryExportOperation -Operation Plan @PSBoundParameters
