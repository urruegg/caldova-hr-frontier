@{
    RootModule = 'Caldova.HrFrontier.Bootstrap.psm1'
    ModuleVersion = '1.0.0'
    GUID = '2ba2a5d1-f019-49ca-a5d5-2d58a9437650'
    Author = 'GitHub Copilot'
    CompanyName = 'Caldova'
    Copyright = '(c) Caldova'
    Description = 'Tenant bootstrap configuration helpers for Caldova HR Frontier.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
        'ConvertTo-DiscoveryEvidence',
        'Import-TenantConfiguration',
        'New-TenantSuffix',
        'Get-TenantResourceName',
        'Get-GitHubOidcSubject',
        'Test-DiscoveryEvidence',
        'Test-TenantIntent',
        'Remove-TemporaryRoleAssignments',
        'Resolve-RunbookReportPath',
        'Write-CanonicalJson',
        'Get-RunbookContentDigest',
        'Update-RunbookProcessPath',
        'New-RunbookExecutionManifest',
        'Test-RunbookExecutionManifest',
        'ConvertTo-RunbookEvidenceRecord'
        'Resolve-CloudNativeTool'
        'Test-CloudDelegatedContext'
        'Get-CloudFoundationAssessment'
        'New-CloudFoundationActionPlan'
        'Invoke-CloudFoundationAction'
        'Import-CustomerExportManifest'
        'Resolve-CustomerExportExecutable'
        'Get-CustomerExportSourceSnapshot'
        'Get-CustomerSourceMarkerCatalog'
        'Get-CustomerExportAssessment'
        'Convert-CustomerExportBlob'
        'Invoke-CustomerStructuredReplacement'
        'Get-CustomerExportResidual'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
}