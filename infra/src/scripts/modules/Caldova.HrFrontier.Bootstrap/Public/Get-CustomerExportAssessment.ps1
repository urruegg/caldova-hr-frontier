function Get-CustomerExportAssessment {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][string]$SourceRoot,
        [Parameter(Mandatory)][ValidatePattern('^[0-9a-fA-F]{40}$')][string]$ExpectedSourceCommit,
        [Parameter(Mandatory)][string]$DestinationRoot,
        [Parameter(Mandatory)][object]$Manifest,
        [Parameter(Mandatory)][ValidatePattern('^[0-9a-fA-F]{64}$')][string]$ManifestDigest,
        [Parameter(Mandatory)][object]$SourceSnapshot,
        [Parameter(Mandatory)][object]$ToolIdentities,
        [Parameter(Mandatory)][object]$MarkerCatalogProof,
        [Parameter(Mandatory)][object]$GitExecutable,
        [Parameter(Mandatory)][scriptblock]$GitBlobReader,
        [switch]$AllowExistingDestination
    )

    $names = @(Get-RunbookObjectPropertyNames -InputObject $Manifest)
    if (@($names | Where-Object { $_ -in @('profile', 'profilePolicy', 'deniedPaths') }).Count -gt 0) {
        if ($names -contains 'profile' -and [string]$Manifest.profile -cne 'CustomerHandover') {
            throw 'Customer compatibility assessment accepts only CustomerHandover.'
        }
        Assert-RepositoryExportManifestContract -Manifest $Manifest -ExpectedProfile CustomerHandover
        if (@($Manifest.deniedPaths).Count -ne 0) {
            throw 'Customer export legacy consumers do not support additional deniedPaths.'
        }
    }
    Invoke-CustomerExportAssessment @PSBoundParameters
}
