[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-z0-9]+$')]
    [string]$TenantAlias,

    [ValidateSet('Interactive', 'ExistingContext')]
    [string]$AuthenticationMode = 'Interactive',

    [string]$PowerPlatformProbePath,

    [string]$OutputPath,

    [switch]$Replace,

    [string]$ContextAccountPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-RepositoryRoot {
    [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
}

function Get-ModuleManifestPath {
    Join-Path $PSScriptRoot 'modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1'
}

function Get-TenantManifestPath {
    param(
        [Parameter(Mandatory)]
        [string]$TenantAliasValue
    )

    Join-Path $PSScriptRoot "..\config\tenants\$TenantAliasValue.psd1"
}

function Resolve-AllowedOutputPath {
    param(
        [Parameter(Mandatory)]
        [string]$RepositoryRoot,

        [Parameter(Mandatory)]
        [string]$TenantAliasValue,

        [AllowEmptyString()]
        [string]$CandidatePath
    )

    if ([string]::IsNullOrWhiteSpace($CandidatePath)) {
        return [System.IO.Path]::GetFullPath((Join-Path $RepositoryRoot "infra\evidence\discovery\$TenantAliasValue.json"))
    }

    $resolved = [System.IO.Path]::GetFullPath($CandidatePath)
    $tempRoots = @([System.IO.Path]::GetTempPath())
    if (-not [string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)) {
        $tempRoots += [System.IO.Path]::GetFullPath($env:RUNNER_TEMP)
    }

    foreach ($root in $tempRoots) {
        $normalizedRoot = [System.IO.Path]::GetFullPath($root).TrimEnd('\') + '\'
        if ($resolved.StartsWith($normalizedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $resolved
        }
    }

    throw 'Explicit OutputPath must resolve under the system temporary directory or RUNNER_TEMP.'
}

function Write-BomlessJsonAtomically {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [object]$Value,

        [switch]$ReplaceExisting
    )

    $directory = Split-Path -Parent $Path
    if (-not [System.IO.Directory]::Exists($directory)) {
        [System.IO.Directory]::CreateDirectory($directory) | Out-Null
    }

    if ((Test-Path -LiteralPath $Path) -and -not $ReplaceExisting) {
        throw 'Output file already exists. Supply -Replace to overwrite reviewed evidence.'
    }

    $tempPath = Join-Path $directory ([System.Guid]::NewGuid().ToString() + '.tmp')
    try {
        $json = $Value | ConvertTo-Json -Depth 30
        [System.IO.File]::WriteAllText($tempPath, $json, [System.Text.UTF8Encoding]::new($false))
        Move-Item -LiteralPath $tempPath -Destination $Path -Force
    }
    finally {
        if (Test-Path -LiteralPath $tempPath) {
            Remove-Item -LiteralPath $tempPath -Force
        }
    }
}

function Invoke-AzJson {
    param(
        [Parameter(Mandatory)]
        [string[]]$ArgumentList
    )

    if (-not [string]::IsNullOrWhiteSpace($ContextAccountPath) -and $ArgumentList.Length -ge 2 -and $ArgumentList[0] -ceq 'account' -and $ArgumentList[1] -ceq 'show') {
        if (-not (Test-Path -LiteralPath $ContextAccountPath)) {
            throw 'ContextAccountPath must point to an existing JSON file.'
        }

        try {
            return (Get-Content -Raw -LiteralPath $ContextAccountPath | ConvertFrom-Json)
        }
        catch {
            throw 'ContextAccountPath must contain valid JSON.'
        }
    }

    $output = & az @ArgumentList 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw 'Azure CLI command failed during discovery context verification.'
    }

    $text = ($output | Out-String).Trim()
    if ([string]::IsNullOrWhiteSpace($text)) {
        throw 'Azure CLI returned an empty response during discovery context verification.'
    }

    try {
        $text | ConvertFrom-Json
    }
    catch {
        throw 'Azure CLI returned unexpected non-JSON output during discovery context verification.'
    }
}

function Get-InteractivePrincipal {
    param(
        [Parameter(Mandatory)]
        [object]$TenantConfiguration
    )

    & az login --tenant $TenantConfiguration.TenantId | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw 'Interactive discovery login failed.'
    }

    $account = Invoke-AzJson -ArgumentList @('account', 'show', '--output', 'json')
    if ([string]$account.tenantId -cne [string]$TenantConfiguration.TenantId) {
        throw 'Interactive discovery context tenant does not match the reviewed tenant configuration.'
    }

    if ([string]$account.id -cne [string]$TenantConfiguration.SubscriptionId) {
        throw 'Interactive discovery context subscription does not match the reviewed tenant configuration.'
    }

    $userName = [string]$account.user.name
    if ([string]::IsNullOrWhiteSpace($userName) -or $userName -ine [string]$TenantConfiguration.AdminUpn) {
        throw 'Interactive discovery requires the reviewed administrator account context.'
    }

    [pscustomobject]@{
        Type = 'User'
        Id = $userName
        Upn = $userName
    }
}

function Get-ExistingContextPrincipal {
    param(
        [Parameter(Mandatory)]
        [object]$TenantConfiguration,

        [Parameter(Mandatory)]
        [string]$ProbePath
    )

    if ([string]::IsNullOrWhiteSpace($env:AZURE_CLIENT_ID)) {
        throw 'ExistingContext discovery requires AZURE_CLIENT_ID.'
    }

    if ([string]::IsNullOrWhiteSpace($env:AZURE_TENANT_ID) -or $env:AZURE_TENANT_ID -cne [string]$TenantConfiguration.TenantId) {
        throw 'ExistingContext discovery requires AZURE_TENANT_ID to match the reviewed tenant configuration.'
    }

    if ([string]::IsNullOrWhiteSpace($env:AZURE_SUBSCRIPTION_ID) -or $env:AZURE_SUBSCRIPTION_ID -cne [string]$TenantConfiguration.SubscriptionId) {
        throw 'ExistingContext discovery requires AZURE_SUBSCRIPTION_ID to match the reviewed tenant configuration.'
    }

    if ([string]::IsNullOrWhiteSpace($ProbePath)) {
        throw 'ExistingContext discovery requires PowerPlatformProbePath.'
    }

    $account = Invoke-AzJson -ArgumentList @('account', 'show', '--output', 'json')
    if ([string]$account.tenantId -ine [string]$TenantConfiguration.TenantId) {
        throw 'ExistingContext discovery context tenant does not match the reviewed tenant configuration.'
    }

    if ([string]$account.id -ine [string]$TenantConfiguration.SubscriptionId) {
        throw 'ExistingContext discovery context subscription does not match the reviewed tenant configuration.'
    }

    $accountUserType = [string]$account.user.type
    if ($accountUserType -ine 'servicePrincipal') {
        throw 'ExistingContext discovery requires az account show user.type to equal servicePrincipal.'
    }

    $observedClientId = [string]$account.user.name
    if ([string]::IsNullOrWhiteSpace($observedClientId) -or $observedClientId -ine [string]$env:AZURE_CLIENT_ID) {
        throw 'ExistingContext discovery requires az account show user.name to match AZURE_CLIENT_ID.'
    }

    [pscustomobject]@{
        Type = 'ServicePrincipal'
        Id = $observedClientId
        ClientId = $observedClientId
    }
}

function Get-BaselineDiscoveryEvidence {
    param(
        [Parameter(Mandatory)]
        [string]$RepositoryRoot,

        [Parameter(Mandatory)]
        [string]$TenantAliasValue
    )

    $baselinePath = Join-Path $RepositoryRoot "infra\evidence\discovery\$TenantAliasValue.json"
    if (-not (Test-Path -LiteralPath $baselinePath)) {
        throw 'ExistingContext discovery requires committed baseline evidence.'
    }

    $baseline = Get-Content -Raw -LiteralPath $baselinePath | ConvertFrom-Json
    Test-DiscoveryEvidence -Evidence $baseline -SkipAuthorizationGate | Out-Null
    $baseline
}

$repositoryRoot = Get-RepositoryRoot
$moduleManifestPath = Get-ModuleManifestPath
$tenantManifestPath = Get-TenantManifestPath -TenantAliasValue $TenantAlias
$resolvedOutputPath = Resolve-AllowedOutputPath -RepositoryRoot $repositoryRoot -TenantAliasValue $TenantAlias -CandidatePath $OutputPath

Import-Module $moduleManifestPath -Force
$tenantConfiguration = Import-TenantConfiguration -Path $tenantManifestPath -ValidationStage Discovery

$principal = if ($AuthenticationMode -eq 'Interactive') {
    Get-InteractivePrincipal -TenantConfiguration $tenantConfiguration
}
else {
    Get-ExistingContextPrincipal -TenantConfiguration $tenantConfiguration -ProbePath $PowerPlatformProbePath
}

$baselineEvidence = if ($AuthenticationMode -eq 'ExistingContext') {
    Get-BaselineDiscoveryEvidence -RepositoryRoot $repositoryRoot -TenantAliasValue $TenantAlias
}
else {
    $null
}

$collectionStartedUtc = [datetime]::UtcNow
$runId = [guid]::NewGuid()
$moduleInfo = Get-Module Caldova.HrFrontier.Bootstrap -ErrorAction Stop

$serviceResults = & $moduleInfo {
    param(
        $TenantConfiguration,
        $RunId,
        $CollectedUtc,
        $AuthenticationMode,
        $ProbePath,
        $BaselineEvidence
    )

    $powerPlatformParameters = @{
        TenantConfiguration = $TenantConfiguration
        RunId = $RunId
        CollectedUtc = $CollectedUtc
        AuthenticationMode = $AuthenticationMode
        ProbePath = $ProbePath
    }
    if ($null -ne $BaselineEvidence) {
        $powerPlatformParameters.BaselineEvidence = $BaselineEvidence
    }

    @{
        GitHub = Get-GitHubDiscovery -TenantConfiguration $TenantConfiguration -RunId $RunId -CollectedUtc $CollectedUtc
        Entra = Get-EntraDiscovery -TenantConfiguration $TenantConfiguration -RunId $RunId -CollectedUtc $CollectedUtc
        Azure = Get-AzureDiscovery -TenantConfiguration $TenantConfiguration -RunId $RunId -CollectedUtc $CollectedUtc
        AzureDevOps = Get-AzureDevOpsDiscovery -TenantConfiguration $TenantConfiguration -RunId $RunId -CollectedUtc $CollectedUtc
        PowerPlatform = Get-PowerPlatformDiscovery @powerPlatformParameters
    }
} $tenantConfiguration $runId $collectionStartedUtc $AuthenticationMode $PowerPlatformProbePath $baselineEvidence

$collectionCompletedUtc = [datetime]::UtcNow
$evidence = ConvertTo-DiscoveryEvidence -TenantConfiguration $tenantConfiguration -ServiceResults $serviceResults -RunId $runId -CollectionStartedUtc $collectionStartedUtc -CollectionCompletedUtc $collectionCompletedUtc -Principal $principal
Test-DiscoveryEvidence -Evidence $evidence -NowUtc $collectionCompletedUtc | Out-Null

Write-BomlessJsonAtomically -Path $resolvedOutputPath -Value $evidence -ReplaceExisting:$Replace