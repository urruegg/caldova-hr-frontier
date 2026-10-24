function ConvertTo-CustomerHandoverManifest {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory)][object]$LegacyManifest)

    if ($LegacyManifest -isnot [Collections.IDictionary] -and $LegacyManifest -isnot [pscustomobject]) {
        throw 'Customer export legacy manifest root must be an object.'
    }
    $manifest = ConvertFrom-CustomerExportJson -Text (ConvertTo-Json -InputObject $LegacyManifest -Depth 100) -RequireObjectRoot
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
