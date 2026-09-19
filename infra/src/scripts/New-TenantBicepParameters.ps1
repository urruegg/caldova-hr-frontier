[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-z0-9]+$')]
    [string]$TenantAlias,

    [Parameter(Mandatory)]
    [string]$ValidationPrincipalId,

    [string]$TenantConfigurationPath,

    [string]$OutputPath,

    [switch]$Replace
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-BicepStringLiteral {
    param(
        [Parameter(Mandatory)]
        [string]$Value
    )

    "'{0}'" -f $Value.Replace("'", "''")
}

function Get-DefaultTenantConfigurationPath {
    param(
        [Parameter(Mandatory)]
        [string]$TenantAliasValue
    )

    Join-Path $script:ScriptDirectory "..\config\tenants\$TenantAliasValue.psd1"
}

function Get-DefaultOutputDirectory {
    Join-Path $script:ScriptDirectory '..\bicep\params'
}

function Get-TargetParameterPath {
    param(
        [Parameter(Mandatory)]
        [string]$DirectoryPath,

        [Parameter(Mandatory)]
        [string]$TenantAliasValue
    )

    Join-Path $DirectoryPath "$TenantAliasValue.bicepparam"
}

function Test-GuidValue {
    param(
        [Parameter(Mandatory)]
        [string]$Value
    )

    $guid = [guid]::Empty
    [guid]::TryParse($Value, [ref]$guid)
}

function New-BicepParameterContent {
    param(
        [Parameter(Mandatory)]
        [object]$Configuration,

        [Parameter(Mandatory)]
        [string]$PlatformResourceGroupName,

        [Parameter(Mandatory)]
        [string]$LogAnalyticsWorkspaceName,

        [Parameter(Mandatory)]
        [string]$ValidationRoleName,

        [Parameter(Mandatory)]
        [string]$ValidationPrincipalObjectId
    )

    @(
        "using '../main.bicep'",
        '',
        'param tenant = {',
        "  tenantAlias: $(ConvertTo-BicepStringLiteral -Value ([string]$Configuration.TenantAlias))",
        "  location: $(ConvertTo-BicepStringLiteral -Value ([string]$Configuration.PrimaryLocation))",
        "  namingRoot: $(ConvertTo-BicepStringLiteral -Value ([string]$Configuration.NamingRoot))",
        "  platformResourceGroupName: $(ConvertTo-BicepStringLiteral -Value $PlatformResourceGroupName)",
        "  logAnalyticsWorkspaceName: $(ConvertTo-BicepStringLiteral -Value $LogAnalyticsWorkspaceName)",
        "  validationRoleName: $(ConvertTo-BicepStringLiteral -Value $ValidationRoleName)",
        "  validationPrincipalId: $(ConvertTo-BicepStringLiteral -Value $ValidationPrincipalObjectId)",
        '  policyAssignments: []',
        '}'
    ) -join [Environment]::NewLine
}

$script:ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleManifestPath = Join-Path $script:ScriptDirectory 'modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1'
Import-Module $moduleManifestPath -Force

if (-not (Test-GuidValue -Value $ValidationPrincipalId)) {
    throw 'ValidationPrincipalId must be a GUID.'
}

$resolvedConfigurationPath = if ([string]::IsNullOrWhiteSpace($TenantConfigurationPath)) {
    [System.IO.Path]::GetFullPath((Get-DefaultTenantConfigurationPath -TenantAliasValue $TenantAlias))
}
else {
    [System.IO.Path]::GetFullPath($TenantConfigurationPath)
}

$configuration = Import-TenantConfiguration -Path $resolvedConfigurationPath -ValidationStage Discovery
if ([string]$configuration.TenantAlias -cne $TenantAlias) {
    throw "Tenant configuration alias '$($configuration.TenantAlias)' does not match requested alias '$TenantAlias'."
}

$outputDirectory = if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    [System.IO.Path]::GetFullPath((Get-DefaultOutputDirectory))
}
else {
    [System.IO.Path]::GetFullPath($OutputPath)
}

[void](New-Item -ItemType Directory -Path $outputDirectory -Force)

$platformResourceGroupName = Get-TenantResourceName -NamingRoot $configuration.NamingRoot -ResourceType ResourceGroup
$logAnalyticsWorkspaceName = Get-TenantResourceName -NamingRoot $configuration.NamingRoot -ResourceType LogAnalytics
$validationRoleName = Get-TenantResourceName -NamingRoot $configuration.NamingRoot -ResourceType DeploymentValidationRole

$content = New-BicepParameterContent `
    -Configuration $configuration `
    -PlatformResourceGroupName $platformResourceGroupName `
    -LogAnalyticsWorkspaceName $logAnalyticsWorkspaceName `
    -ValidationRoleName $validationRoleName `
    -ValidationPrincipalObjectId $ValidationPrincipalId

$targetPath = Get-TargetParameterPath -DirectoryPath $outputDirectory -TenantAliasValue $TenantAlias
$tempPath = Join-Path $outputDirectory ('.{0}.{1}.tmp' -f $TenantAlias, [guid]::NewGuid().ToString('N'))
$backupPath = $null

try {
    [System.IO.File]::WriteAllText($tempPath, $content, [System.Text.UTF8Encoding]::new($false))

    if (Test-Path -LiteralPath $targetPath) {
        $existingContent = [System.IO.File]::ReadAllText($targetPath)
        if ($existingContent -ceq $content) {
            Remove-Item -LiteralPath $tempPath -Force
            Write-Output ("Parameter file already matches reviewed content at $targetPath.")
            return
        }

        if (-not $Replace) {
            throw 'Existing parameter file differs from the reviewed suffix or principal ID. Re-run with -Replace to overwrite it.'
        }

        $backupPath = Join-Path $outputDirectory ('.{0}.{1}.bak' -f $TenantAlias, [guid]::NewGuid().ToString('N'))
        [System.IO.File]::Replace($tempPath, $targetPath, $backupPath)
        if (Test-Path -LiteralPath $backupPath) {
            Remove-Item -LiteralPath $backupPath -Force
        }
    }
    else {
        Move-Item -LiteralPath $tempPath -Destination $targetPath
    }
}
catch {
    if (Test-Path -LiteralPath $tempPath) {
        Remove-Item -LiteralPath $tempPath -Force
    }

    if ($backupPath -and (Test-Path -LiteralPath $backupPath)) {
        Remove-Item -LiteralPath $backupPath -Force
    }

    throw
}

Write-Output ("Wrote reviewed tenant parameters to $targetPath.")