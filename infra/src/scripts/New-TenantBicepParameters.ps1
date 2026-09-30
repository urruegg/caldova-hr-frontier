[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateScript({
        if ($_ -cnotmatch '^tenant[1-9][0-9]*$') {
            throw 'PublicTenantKey must use the case-sensitive lowercase tenant key format.'
        }
        $true
    })]
    [string]$PublicTenantKey,

    [Parameter(Mandatory)]
    [string]$TenantConfigurationPath,

    [Parameter(Mandatory)]
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

function Get-RepositoryRoot {
    [System.IO.Path]::GetFullPath((Join-Path $script:ScriptDirectory '..\..\..'))
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

function Get-RelativeBicepPath {
    param(
        [Parameter(Mandatory)]
        [string]$FromDirectory,

        [Parameter(Mandatory)]
        [string]$ToPath
    )

    $baseUri = [uri](([System.IO.Path]::GetFullPath($FromDirectory).TrimEnd('\') + '\').Replace('\', '/'))
    $targetUri = [uri]([System.IO.Path]::GetFullPath($ToPath).Replace('\', '/'))
    [uri]::UnescapeDataString($baseUri.MakeRelativeUri($targetUri).ToString())
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
        [string]$BicepTemplateReference
    )

    @(
        "using $(ConvertTo-BicepStringLiteral -Value $BicepTemplateReference)",
        '',
        'param tenant = {',
        "  tenantAlias: $(ConvertTo-BicepStringLiteral -Value ([string]$Configuration.TenantAlias))",
        "  location: $(ConvertTo-BicepStringLiteral -Value ([string]$Configuration.PrimaryLocation))",
        "  namingRoot: $(ConvertTo-BicepStringLiteral -Value ([string]$Configuration.NamingRoot))",
        "  platformResourceGroupName: $(ConvertTo-BicepStringLiteral -Value $PlatformResourceGroupName)",
        "  logAnalyticsWorkspaceName: $(ConvertTo-BicepStringLiteral -Value $LogAnalyticsWorkspaceName)",
        '  policyAssignments: []',
        '}'
    ) -join [Environment]::NewLine
}

$script:ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleManifestPath = Join-Path $script:ScriptDirectory 'modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1'
Import-Module $moduleManifestPath -Force

$configuration = Import-TenantConfiguration `
    -Path ([System.IO.Path]::GetFullPath($TenantConfigurationPath)) `
    -ValidationStage Discovery `
    -ExpectedPublicTenantKey $PublicTenantKey `
    -RequireLocalUntracked

$repositoryRoot = Get-RepositoryRoot
$outputDirectory = [System.IO.Path]::GetFullPath($OutputPath)
$normalizedRepositoryRoot = $repositoryRoot.TrimEnd('\')
$repositoryPrefix = $normalizedRepositoryRoot + '\'
if ($outputDirectory.TrimEnd('\') -ieq $normalizedRepositoryRoot -or
    $outputDirectory.StartsWith($repositoryPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'OutputPath must resolve outside the repository.'
}

[void](New-Item -ItemType Directory -Path $outputDirectory -Force)

$tenantAlias = [string]$configuration.TenantAlias
$bicepTemplateReference = Get-RelativeBicepPath `
    -FromDirectory $outputDirectory `
    -ToPath (Join-Path $script:ScriptDirectory '..\bicep\main.bicep')
$platformResourceGroupName = Get-TenantResourceName -NamingRoot $configuration.NamingRoot -ResourceType ResourceGroup
$logAnalyticsWorkspaceName = Get-TenantResourceName -NamingRoot $configuration.NamingRoot -ResourceType LogAnalytics
$content = New-BicepParameterContent `
    -Configuration $configuration `
    -PlatformResourceGroupName $platformResourceGroupName `
    -LogAnalyticsWorkspaceName $logAnalyticsWorkspaceName `
    -BicepTemplateReference $bicepTemplateReference

$targetPath = Get-TargetParameterPath -DirectoryPath $outputDirectory -TenantAliasValue $tenantAlias
$tempPath = Join-Path $outputDirectory ('.{0}.{1}.tmp' -f $tenantAlias, [guid]::NewGuid().ToString('N'))
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

        $backupPath = Join-Path $outputDirectory ('.{0}.{1}.bak' -f $tenantAlias, [guid]::NewGuid().ToString('N'))
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