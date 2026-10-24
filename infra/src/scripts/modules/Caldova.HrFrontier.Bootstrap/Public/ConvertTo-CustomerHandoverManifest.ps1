function ConvertTo-CustomerHandoverManifest {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory)][object]$LegacyManifest)

    $manifest = ConvertFrom-CustomerExportJson -Text ($LegacyManifest | ConvertTo-Json -Depth 100)
    Assert-CustomerExportManifestContract -Manifest $manifest
    $manifest | Add-Member NoteProperty profile 'CustomerHandover'
    $manifest | Add-Member NoteProperty profilePolicy ([pscustomobject][ordered]@{
        denyWorkflows = $true
        denyEvidence = $true
        denyTenantTransitions = $true
        denyPrivateState = $true
        denySourceHistory = $true
        denyUntrackedFiles = $true
    })
    $manifest | Add-Member NoteProperty deniedPaths @()
    Assert-RepositoryExportManifestContract -Manifest $manifest -ExpectedProfile CustomerHandover
    return $manifest
}
