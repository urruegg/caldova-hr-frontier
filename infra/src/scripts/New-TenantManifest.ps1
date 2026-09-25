[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-z0-9]+$')]
    [string]$TenantAlias
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-Psd1Literal {
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$Value,

        [int]$Indent = 0
    )

    if ($Value -is [System.Collections.IDictionary]) {
        if ($Value.Count -eq 0) {
            return '@{}'
        }

        $lines = New-Object System.Collections.Generic.List[string]
        [void]$lines.Add('@{')

        foreach ($key in $Value.Keys) {
            $rendered = ConvertTo-Psd1Literal -Value $Value[$key] -Indent ($Indent + 4)
            [void]$lines.Add(('{0}{1} = {2}' -f (' ' * ($Indent + 4)), $key, $rendered))
        }

        [void]$lines.Add((' ' * $Indent) + '}')
        return ($lines -join [Environment]::NewLine)
    }

    if ($null -eq $Value) {
        return '$null'
    }

    if ($Value -is [string]) {
        return "'{0}'" -f $Value.Replace("'", "''")
    }

    [string]$Value
}

$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleManifestPath = Join-Path $scriptDirectory 'modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1'
Import-Module $moduleManifestPath -Force

$tenantProfile = switch ($TenantAlias) {
    'caldova25156897' {
        [ordered]@{
            DisplayName = 'Caldova25156897'
            TenantId = 'e2312862-df63-440c-8bcf-007a2c52859d'
            AdminUpn = 'admin@Caldova25156897.onmicrosoft.com'
            SubscriptionId = 'edb45a24-408d-47c4-bbc7-685b9b3fc017'
            PrimaryLocation = 'switzerlandnorth'
            CompanyTla = 'cal'
            AzureDevOps = [ordered]@{
                OrganizationUrl = 'https://dev.azure.com/caldova25156897/'
                ProjectName = 'Caldova HR Frontier'
            }
            PowerPlatform = [ordered]@{
                DevUrl = 'https://hrfrontierdev.crm17.dynamics.com/'
                TestUrl = 'https://hrfrontiertest.crm17.dynamics.com/'
                ProdUrl = 'https://hrfrontier.crm17.dynamics.com/'
            }
        }
    }
    'caldova25668747' {
        [ordered]@{
            DisplayName = 'Caldova25668747'
            TenantId = '4682b8db-586c-4602-ad98-d29e4018fd5b'
            AdminUpn = 'admin@caldova25668747.onmicrosoft.com'
            SubscriptionId = 'c097a50e-bfe0-487f-bffe-22d7695caadd'
            PrimaryLocation = 'switzerlandnorth'
            CompanyTla = 'cal'
            AzureDevOps = [ordered]@{
                OrganizationUrl = 'https://dev.azure.com/Caldova25668747/'
                ProjectName = 'FrontierHR'
            }
            PowerPlatform = [ordered]@{
                DevUrl = 'https://calhrfrontierdev.crm17.dynamics.com/'
                TestUrl = 'https://calhrfrontiertest.crm17.dynamics.com/'
                ProdUrl = 'https://calhrfrontier.crm17.dynamics.com/'
            }
            SharePoint = [ordered]@{
                DevUrl = 'https://caldova25668747.sharepoint.com/sites/HRFrontierDEV'
                TestUrl = 'https://caldova25668747.sharepoint.com/sites/HRFrontierTEST'
                ProdUrl = 'https://caldova25668747.sharepoint.com/sites/HRFrontier'
            }
        }
    }
    default {
        throw "No reviewed tenant profile exists for alias $TenantAlias."
    }
}

$tenantDirectory = Join-Path $scriptDirectory '..\config\tenants'
$targetPath = [System.IO.Path]::GetFullPath((Join-Path $tenantDirectory "$TenantAlias.psd1"))
$targetAlreadyExists = Test-Path -LiteralPath $targetPath
if ($targetAlreadyExists) {
    throw "Tenant manifest already exists at $targetPath."
}

$suffix = New-TenantSuffix
$namingRoot = '{0}-hr-agentic-{1}' -f $tenantProfile.CompanyTla, $suffix
$manifest = [ordered]@{
    SchemaVersion = '1.0'
    TenantAlias = $TenantAlias
    DisplayName = $tenantProfile.DisplayName
    TenantId = $tenantProfile.TenantId
    AdminUpn = $tenantProfile.AdminUpn
    SubscriptionId = $tenantProfile.SubscriptionId
    PrimaryLocation = $tenantProfile.PrimaryLocation
    CompanyTla = $tenantProfile.CompanyTla
    WorkloadName = 'hr-agentic'
    UniqueSuffix = $suffix
    NamingRoot = $namingRoot
    LifecycleState = 'DiscoveryRequired'
    GitHub = [ordered]@{
        Owner = 'urruegg'
        OwnerId = '46865858'
        Repository = 'caldova-hr-frontier'
        RepositoryId = '1371297722'
        EnvironmentName = "bootstrap-$TenantAlias"
    }
    AzureDevOps = $tenantProfile.AzureDevOps
    PowerPlatform = $tenantProfile.PowerPlatform
    Components = [ordered]@{}
}
if ($tenantProfile.Contains('SharePoint')) {
    $manifest.SharePoint = $tenantProfile.SharePoint
    $components = $manifest.Components
    $manifest.Remove('Components')
    $manifest.Components = $components
}

$tempPath = Join-Path $tenantDirectory ('.{0}.{1}.tmp' -f $TenantAlias, [guid]::NewGuid().ToString('N'))

try {
    $content = ConvertTo-Psd1Literal -Value $manifest
    [System.IO.File]::WriteAllText($tempPath, $content, [System.Text.UTF8Encoding]::new($false))
    Import-TenantConfiguration -Path $tempPath -ValidationStage Discovery | Out-Null
    Move-Item -LiteralPath $tempPath -Destination $targetPath
}
catch {
    if (Test-Path -LiteralPath $tempPath) {
        Remove-Item -LiteralPath $tempPath -Force
    }

    if (-not $targetAlreadyExists -and (Test-Path -LiteralPath $targetPath)) {
        Remove-Item -LiteralPath $targetPath -Force
    }

    throw
}

Write-Output ('Assigned suffix: ' + $suffix)
Write-Output ('Naming root: ' + $namingRoot)