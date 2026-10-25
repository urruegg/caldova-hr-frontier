function Get-RepositoryExportContext {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][string]$SourceRoot,
        [Parameter(Mandatory)][ValidatePattern('^[0-9a-fA-F]{40}$')][string]$ExpectedSourceCommit,
        [Parameter(Mandatory)][string]$DestinationRoot,
        [Parameter(Mandatory)][object]$Manifest,
        [Parameter(Mandatory)][ValidateSet('TenantReplica', 'CustomerHandover')][string]$Profile,
        [Parameter(Mandatory)][ValidatePattern('^[0-9a-fA-F]{64}$')][string]$RepositoryIdentity,
        [Parameter(Mandatory)][object]$ToolIdentities,
        [Parameter(Mandatory)][scriptblock]$NativeCommandRunner,
        [scriptblock]$GitBlobReader
    )

    # Object inputs obey the same closed canonical contract as file inputs, before enumeration.
    try { Assert-RepositoryExportManifestContract -Manifest $Manifest -ExpectedProfile $Profile }
    catch { throw 'Repository export profile manifest is invalid.' }
    foreach ($artifact in @($Manifest.retainedTenantArtifacts)) {
        if ($null -ne (Get-RepositoryExportPathDenial -Path $artifact.path -Manifest $Manifest -Profile $Profile)) {
            throw 'Repository export profile retention contradicts the fixed deny policy.'
        }
    }
    Assert-RepositoryExportLocalPath -Path $SourceRoot
    Assert-RepositoryExportLocalPath -Path $DestinationRoot
    if (Test-Path -LiteralPath $DestinationRoot) { throw 'Repository export destination must not already exist.' }
    $requiredTools = @('Git', 'WindowsPowerShell')
    if (@($Manifest.validationSuites) -contains 'BicepBuild') { $requiredTools += 'AzureCli' }
    try {
        Assert-RunbookClosedObject -InputObject $ToolIdentities -AllowedProperties @('Git', 'WindowsPowerShell', 'AzureCli') -RequiredProperties $requiredTools
        foreach ($name in @(Get-RunbookObjectPropertyNames -InputObject $ToolIdentities)) {
            $tool = Get-RunbookObjectPropertyValue -InputObject $ToolIdentities -Name $name
            Assert-RunbookClosedObject -InputObject $tool -AllowedProperties @('path', 'sha256', 'version') -RequiredProperties @('path', 'sha256', 'version')
            if ($tool.path -isnot [string] -or $tool.sha256 -isnot [string] -or $tool.version -isnot [string] -or
                $tool.sha256 -cnotmatch '^[0-9a-f]{64}$' -or
                $tool.version -cnotmatch '\A[A-Za-z0-9][A-Za-z0-9 ._()+-]{0,127}\z') { throw 'Invalid tool.' }
            Assert-RepositoryExportLocalPath -Path $tool.path -AllowHardLink
            if (-not (Test-Path -LiteralPath $tool.path -PathType Leaf) -or
                (Get-CustomerExportFileDigest -Path $tool.path) -cne $tool.sha256) { throw 'Stale tool.' }
        }
    }
    catch { throw 'Repository export tool identity is invalid or stale.' }
    $git = Get-RunbookObjectPropertyValue -InputObject $ToolIdentities -Name 'Git'
    $runner = {
        param($file, $arguments)
        # Git status must not refresh the source index.
        & $NativeCommandRunner $file (@('--no-optional-locks') + $arguments)
    }.GetNewClosure()
    $reader = ${function:Read-CustomerExportCommitBlob}
    if ($null -ne $GitBlobReader) {
        $committedReader = $reader
        $injectedReader = $GitBlobReader
        $hashBytes = ${function:Get-CustomerExportSha256}
        $reader = {
            param($gitPath, $repository, $commit, $path)
            [byte[]]$committed = @(& $committedReader $gitPath $repository $commit $path)
            [byte[]]$candidate = @(& $injectedReader $gitPath $repository $commit $path)
            if ((& $hashBytes -Bytes $committed) -cne (& $hashBytes -Bytes $candidate)) {
                throw 'Repository export injected blob identity does not match the committed regular blob.'
            }
            return $committed
        }.GetNewClosure()
    }
    $snapshot = Get-CustomerExportSourceSnapshot -RepositoryRoot $SourceRoot -GitExecutable $git `
        -NativeCommandRunner $runner -GitBlobReader $reader -ExpectedSourceCommit $ExpectedSourceCommit -RepositoryIdentity $RepositoryIdentity
    if ($snapshot.commit -cne $ExpectedSourceCommit.ToLowerInvariant()) { throw 'Repository export source commit does not match.' }
    if ($snapshot.remotesDigest -cne $RepositoryIdentity.ToLowerInvariant()) { throw 'Repository export repository identity does not match.' }
    $catalog = Get-CustomerSourceMarkerCatalog -RepositoryRoot $SourceRoot -ExpectedSourceCommit $snapshot.commit `
        -TrackedFiles @($snapshot.trackedFiles) -RetainedTenantArtifacts @($Manifest.retainedTenantArtifacts) `
        -SourceMarkerCatalog @($Manifest.sourceMarkerCatalog) -GitExecutable $git -GitBlobReader $reader -DigestOnly
    $manifestDigest = Get-RunbookContentDigest -InputObject $Manifest
    $engine = Invoke-CustomerExportAssessment -SourceRoot $SourceRoot -ExpectedSourceCommit $snapshot.commit `
        -DestinationRoot $DestinationRoot -Manifest $Manifest -ManifestDigest $manifestDigest `
        -SourceSnapshot $snapshot -ToolIdentities $ToolIdentities -MarkerCatalogProof $catalog `
        -GitExecutable $git -GitBlobReader $reader -Profile $Profile -Canonical
    $post = Get-CustomerExportSourceSnapshot -RepositoryRoot $SourceRoot -GitExecutable $git `
        -NativeCommandRunner $runner -GitBlobReader $reader
    $snapshotDigest = Get-RunbookContentDigest -InputObject $snapshot
    if ($snapshotDigest -cne (Get-RunbookContentDigest -InputObject $post)) { throw 'Repository export source snapshot drifted during assessment.' }
    $destinationId = 'repository-export:' + (Get-RepositoryExportPathIdentity -Path $DestinationRoot)
    $toolProof = [ordered]@{}
    foreach ($name in @(Get-RunbookObjectPropertyNames -InputObject $ToolIdentities | Sort-Object)) {
        $tool = Get-RunbookObjectPropertyValue -InputObject $ToolIdentities -Name $name
        $toolProof[$name] = [pscustomobject][ordered]@{
            pathDigest = Get-RepositoryExportPathIdentity -Path $tool.path
            sha256 = $tool.sha256
            version = $tool.version
        }
    }
    $unsigned = [ordered]@{
        schemaVersion = '1.0'
        profile = $Profile
        classification = 'Create'
        sourceCommit = $snapshot.commit
        repositoryIdentity = $RepositoryIdentity.ToLowerInvariant()
        sourceSnapshotDigest = $snapshotDigest
        sourceBoundary = @(Get-RepositoryExportAncestorIdentities -Path $SourceRoot)
        destinationBoundary = @(Get-RepositoryExportAncestorIdentities -Path $DestinationRoot)
        destinationStableId = $destinationId
        retainedInventoryDigest = Get-RunbookContentDigest -InputObject ([ordered]@{ paths = $engine.copyFiles; fileDigests = $engine.fileDigests })
        deniedInventoryDigest = Get-RunbookContentDigest -InputObject $engine.exclusions
        retainedFileCount = @($engine.copyFiles).Count
        deniedFileCount = @($engine.exclusions).Count
        markerCatalogProof = $catalog
        toolIdentities = [pscustomobject]$toolProof
        validationSuites = @($Manifest.validationSuites)
        orderedActions = @(Get-RepositoryExportActions -DestinationStableId $destinationId)
    }
    $policies = Get-RepositoryExportManifestPolicyDigests -Manifest $Manifest
    foreach ($property in $policies.PSObject.Properties) { $unsigned[$property.Name] = $property.Value }
    $result = [ordered]@{}
    foreach ($entry in $unsigned.GetEnumerator()) { $result[$entry.Key] = $entry.Value }
    $result.digest = Get-RunbookContentDigest -InputObject $unsigned
    $public = [pscustomobject]$result
    # The content validator consumes the private inventory, but the signature stays bound to public evidence.
    $engine.digest = $public.digest
    $engine.destinationStableId = $public.destinationStableId
    [pscustomobject]@{ assessment = $public; engine = $engine; snapshot = $snapshot; reader = $reader; runner = $runner }
}

function Get-RepositoryExportAssessment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SourceRoot,
        [Parameter(Mandatory)][ValidatePattern('^[0-9a-fA-F]{40}$')][string]$ExpectedSourceCommit,
        [Parameter(Mandatory)][string]$DestinationRoot,
        [Parameter(Mandatory)][object]$Manifest,
        [Parameter(Mandatory)][ValidateSet('TenantReplica', 'CustomerHandover')][string]$Profile,
        [Parameter(Mandatory)][ValidatePattern('^[0-9a-fA-F]{64}$')][string]$RepositoryIdentity,
        [Parameter(Mandatory)][object]$ToolIdentities,
        [Parameter(Mandatory)][scriptblock]$NativeCommandRunner
    )
    (Get-RepositoryExportContext @PSBoundParameters).assessment
}
