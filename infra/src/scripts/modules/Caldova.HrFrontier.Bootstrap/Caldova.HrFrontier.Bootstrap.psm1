$publicScriptsPath = Join-Path $PSScriptRoot 'Public'
Get-ChildItem -LiteralPath $publicScriptsPath -Filter '*.ps1' | Sort-Object Name | ForEach-Object {
    . $_.FullName
}

Export-ModuleMember -Function @(
    'Import-TenantConfiguration',
    'New-TenantSuffix',
    'Get-TenantResourceName',
    'Get-GitHubOidcSubject'
)