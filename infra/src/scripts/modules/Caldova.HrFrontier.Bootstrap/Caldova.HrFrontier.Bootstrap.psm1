$privateScriptsPath = Join-Path $PSScriptRoot 'Private'
if (Test-Path -LiteralPath $privateScriptsPath) {
    Get-ChildItem -LiteralPath $privateScriptsPath -Filter '*.ps1' | Sort-Object Name | ForEach-Object {
        . $_.FullName
    }
}

$publicScriptsPath = Join-Path $PSScriptRoot 'Public'
Get-ChildItem -LiteralPath $publicScriptsPath -Filter '*.ps1' | Sort-Object Name | ForEach-Object {
    . $_.FullName
}

Export-ModuleMember -Function @(
    'ConvertTo-DiscoveryEvidence',
    'Import-TenantConfiguration',
    'New-TenantSuffix',
    'Get-TenantResourceName',
    'Get-GitHubOidcSubject',
    'Test-DiscoveryEvidence',
    'Test-TenantIntent',
    'Remove-TemporaryRoleAssignments'
)