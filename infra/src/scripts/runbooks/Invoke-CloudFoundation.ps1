[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-z0-9]+$')]
    [string]$TenantAlias,

    [string]$TenantConfigurationPath,

    [Parameter(Mandatory)]
    [string]$ExecutionManifestPath,

    [Parameter(Mandatory)]
    [string]$AssessmentPath,

    [string]$ReportPath,

    [Parameter(Mandatory)]
    [ValidatePattern('^[0-9a-f]{64}$')]
    [string]$ApprovedDigest,

    [ValidateSet('DEV','TEST','PROD')]
    [string[]]$Stages = @('DEV','TEST','PROD'),

    [switch]$Apply,
    [scriptblock]$NativeToolResolver,
    [scriptblock]$NativeCommandRunner,
    [scriptblock]$InteractiveHostProbe,
    [scriptblock]$WhatIfValidator,
    [datetime]$NowUtc = [datetime]::UtcNow
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

throw 'Cloud foundation apply is retired from the current sprint. The entry point is dormant and unsupported; use the Tenant 1 lean platform runbook.'
