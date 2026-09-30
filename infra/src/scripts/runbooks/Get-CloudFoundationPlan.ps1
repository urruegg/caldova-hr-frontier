[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-z0-9]+$')]
    [string]$TenantAlias,

    [string]$TenantConfigurationPath,
    [string]$ReportPath,

    [ValidateSet('DEV','TEST','PROD')]
    [string[]]$Stages = @('DEV','TEST','PROD'),

    [scriptblock]$NativeToolResolver,
    [scriptblock]$NativeCommandRunner,
    [scriptblock]$InteractiveHostProbe,
    [datetime]$NowUtc = [datetime]::UtcNow
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

throw 'Cloud foundation planning is retired from the current sprint. The entry point is dormant and unsupported; use the Tenant 1 lean platform runbook.'
