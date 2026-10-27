function Write-SyntheticPrivateBackupPair {
    param([string]$IntentPath, [string]$StatePath, [string]$RestoreRoot, [string]$ManifestPath)

    foreach ($directory in @((Split-Path $IntentPath), (Split-Path $ManifestPath), $RestoreRoot)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    $intent = @'
@{
    SchemaVersion = '1.0'
    PublicTenantKey = 'tenant1'
    TenantAlias = 'synthetic123'
    DisplayName = 'Synthetic Private Marker'
    TenantId = '11111111-1111-4111-8111-111111111111'
    AdminUpn = 'fixture@example.invalid'
    SubscriptionId = '22222222-2222-4222-8222-222222222222'
    PrimaryLocation = 'switzerlandnorth'
    CompanyTla = 'syn'
    WorkloadName = 'hr-agentic'
    UniqueSuffix = 'a1b2c3'
    NamingRoot = 'syn-hr-agentic-a1b2c3'
    LifecycleState = 'DiscoveryRequired'
    GitHub = @{
        Owner = 'synthetic-owner'
        OwnerId = '100001'
        Repository = 'synthetic-repository'
        RepositoryId = '100002'
        EnvironmentName = 'bootstrap-synthetic123'
    }
    AzureDevOps = @{
        OrganizationUrl = 'https://example.invalid/synthetic/'
        ProjectName = 'Synthetic Project'
    }
    PowerPlatform = @{
        DevUrl = 'https://dev.example.invalid/'
        TestUrl = 'https://test.example.invalid/'
        ProdUrl = 'https://prod.example.invalid/'
    }
    Components = @{}
}
'@
    [IO.File]::WriteAllText($IntentPath, $intent)
    [IO.File]::WriteAllText($StatePath, '{"schemaVersion":"1.0","publicTenantKey":"tenant1","resources":[]}')
    foreach ($pair in @(@($IntentPath, 'intent'), @($StatePath, 'state'))) {
        [IO.File]::WriteAllBytes((Join-Path $RestoreRoot $pair[1]), [IO.File]::ReadAllBytes($pair[0]))
        [IO.File]::SetLastWriteTimeUtc($pair[0], [datetime]'2026-10-02T11:59:00Z')
    }
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'private-backup-manifest.synthetic.json') -Destination $ManifestPath
}
