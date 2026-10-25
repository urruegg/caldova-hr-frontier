function New-RepositoryExportActionPlan {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][object]$Assessment,
        [Parameter(Mandatory)][object]$Manifest,
        [Parameter(Mandatory)][guid]$RunId,
        [Parameter(Mandatory)][string]$EvidenceRoot,
        [Parameter(Mandatory)][datetime]$NowUtc
    )

    try { Assert-RepositoryExportManifestContract -Manifest $Manifest -ExpectedProfile ([string]$Assessment.profile) }
    catch { throw 'Repository export planning requires a valid explicit profile.' }
    $unsigned = [ordered]@{}
    foreach ($name in @(Get-RunbookObjectPropertyNames -InputObject $Assessment | Where-Object { $_ -cne 'digest' })) {
        $unsigned[$name] = Get-RunbookObjectPropertyValue -InputObject $Assessment -Name $name
    }
    if ((Get-RunbookContentDigest -InputObject $unsigned) -cne [string]$Assessment.digest -or
        (Get-RunbookContentDigest -InputObject $Manifest) -cne [string]$Assessment.manifestDigest) {
        throw 'Repository export assessment or manifest digest drifted.'
    }
    $policies = Get-RepositoryExportManifestPolicyDigests -Manifest $Manifest
    foreach ($property in $policies.PSObject.Properties) {
        if ([string]$Assessment.($property.Name) -cne [string]$property.Value) {
            throw 'Repository export assessed policy digest does not match reviewed intent.'
        }
    }
    if ((Get-RunbookContentDigest -InputObject $Assessment.validationSuites) -cne $policies.suitePolicyDigest -or
        [string]$Assessment.markerCatalogProof.sourceMarkerCatalogDigest -cne (Get-RunbookContentDigest -InputObject $Manifest.sourceMarkerCatalog)) {
        throw 'Repository export assessed marker or suite policy does not match reviewed intent.'
    }
    $expectedActions = @(Get-RepositoryExportActions -DestinationStableId $Assessment.destinationStableId)
    if ($Assessment.classification -cne 'Create' -or
        (Get-RunbookContentDigest -InputObject $Assessment.orderedActions) -cne (Get-RunbookContentDigest -InputObject $expectedActions)) {
        throw 'Repository export ordered action sequence is invalid.'
    }
    Assert-RepositoryExportLocalPath -Path $EvidenceRoot
    $evidenceIdentity = Get-RepositoryExportPathIdentity -Path $EvidenceRoot
    $evidenceAncestors = @(Get-RepositoryExportAncestorIdentities -Path $EvidenceRoot)
    if ($Assessment.sourceBoundary -contains $evidenceIdentity -or $Assessment.destinationBoundary -contains $evidenceIdentity -or
        $evidenceAncestors -contains $Assessment.sourceBoundary[0] -or $evidenceAncestors -contains $Assessment.destinationBoundary[0]) {
        throw 'Repository export evidence must be outside source and destination boundaries.'
    }
    $cursor = [IO.Path]::GetFullPath($EvidenceRoot)
    while (-not [string]::IsNullOrWhiteSpace($cursor)) {
        if (Test-Path -LiteralPath (Join-Path $cursor '.git')) { throw 'Repository export evidence must be outside every Git worktree.' }
        $parent = Split-Path -Parent $cursor
        if ($parent -ceq $cursor) { break }
        $cursor = $parent
    }
    $permissions = @(
        foreach ($action in $expectedActions) {
            $permission = [ordered]@{}
            foreach ($property in $action.PSObject.Properties) { $permission[$property.Name] = $property.Value }
            $permission.scope = 'evidence:' + $evidenceIdentity
            [pscustomobject]$permission
        }
    )
    $authentication = [pscustomobject]@{ executionHost = 'InteractiveWindows11PowerShell'; mode = 'NotApplicable' }
    $execution = New-RunbookExecutionManifest -RunId $RunId -Kind CustomerExport -TargetStableId $Assessment.destinationStableId `
        -SourceCommit $Assessment.sourceCommit -AssessmentDigest $Assessment.digest -AuthenticationContext $authentication `
        -AllowedActions $permissions -ToolVersions $Assessment.toolIdentities -GeneratedAtUtc $NowUtc
    Test-RunbookExecutionManifest -Manifest $execution -ApprovedDigest $execution.digest -CurrentSourceCommit $Assessment.sourceCommit `
        -CurrentAssessmentDigest $Assessment.digest -CurrentAuthenticationContext $authentication `
        -AllowedActionNames @(Get-RepositoryExportActionOrder) -NowUtc $NowUtc | Out-Null
    [pscustomobject][ordered]@{
        classification = $Assessment.classification
        profile = $Assessment.profile
        assessmentDigest = $Assessment.digest
        evidenceRootStableId = 'evidence:' + $evidenceIdentity
        orderedActions = @($Assessment.orderedActions)
        executionManifest = $execution
        digest = $execution.digest
    }
}
