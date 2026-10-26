function Test-RepositoryExportIndependent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SourceRoot,
        [Parameter(Mandatory)][ValidatePattern('^[0-9a-fA-F]{40}$')][string]$ExpectedSourceCommit,
        [Parameter(Mandatory)][string]$DestinationRoot,
        [Parameter(Mandatory)][object]$Manifest,
        [Parameter(Mandatory)][ValidateSet('TenantReplica', 'CustomerHandover')][string]$Profile,
        [Parameter(Mandatory)][ValidatePattern('^[0-9a-fA-F]{64}$')][string]$RepositoryIdentity,
        [Parameter(DontShow)][scriptblock]$GitBlobReader,
        [Parameter(DontShow)][scriptblock]$ValidationRunner,
        [Parameter(DontShow)][scriptblock]$NativeCommandRunner,
        [Parameter(DontShow)][scriptblock]$CommandResolver,
        [Parameter(DontShow)][scriptblock]$FileIdentityProvider,
        [Parameter(DontShow)][object]$ToolIdentities
    )
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'
    Assert-RepositoryExportManifestContract -Manifest $Manifest -ExpectedProfile $Profile
    $manifestDigest = Get-RunbookContentDigest $Manifest
    $policyDigest = Get-RunbookContentDigest (Get-RepositoryExportFixedPolicy -Profile $Profile)
    $result = [pscustomobject][ordered]@{
        profile = $Profile; expectedFileCount = 0; actualFileCount = 0; contentTreeDigest = $null
        unexpectedPaths = @(); missingPaths = @(); mismatchedPaths = @(); deniedFindings = @()
        suiteResults = @(); sourceUnchanged = $false; status = 'Failed'
        provenance = [pscustomobject]@{
            sourceSnapshotDigest = $null; manifestDigest = $manifestDigest
            fixedPolicyDigest = $policyDigest; toolIdentities = [pscustomobject]@{}
            sourceVerification = 'Unavailable'
        }
    }
    $context = $null
    $sourceSnapshotDigest = $null
    $toolPrerequisite = $false
    $expected = [Collections.Generic.Dictionary[string, byte[]]]::new([StringComparer]::Ordinal)
    if ($null -eq $NativeCommandRunner) { $NativeCommandRunner = New-DefaultNativeCommandRunner }
    if ($null -eq $CommandResolver) { $CommandResolver = New-RepositoryExportCommandResolver }
    if ($null -eq $FileIdentityProvider) { $FileIdentityProvider = New-DefaultFileIdentityProvider }
    if ($null -eq $ValidationRunner) { $ValidationRunner = New-DefaultValidationRunner -Runner $NativeCommandRunner }
    try {
        Assert-RepositoryExportLocalPath -Path $SourceRoot
        Assert-RepositoryExportLocalPath -Path $DestinationRoot
        if (-not (Test-Path -LiteralPath $DestinationRoot -PathType Container)) { throw 'Candidate is unavailable.' }
        if ($null -eq $ToolIdentities) {
            try {
                $ToolIdentities = New-ToolIdentities -ValidationSuites @('Pester') -Resolver $CommandResolver `
                    -IdentityProvider $FileIdentityProvider -Runner $NativeCommandRunner -Canonical -StrictTools
            }
            catch {
                $toolPrerequisite = $true
                foreach ($suite in $Manifest.validationSuites) {
                    $result.suiteResults += [pscustomobject]@{ suite = $suite; status = 'Blocked'; exitCode = 1; category = 'ToolUnavailable' }
                }
                throw 'Required offline tool is unavailable.'
            }
            try {
                $completeTools = New-ToolIdentities -ValidationSuites @($Manifest.validationSuites) -Resolver $CommandResolver `
                    -IdentityProvider $FileIdentityProvider -Runner $NativeCommandRunner -Canonical -StrictTools
                $ToolIdentities = $completeTools
            }
            catch {
                $result.suiteResults += [pscustomobject]@{ suite = 'BicepBuild'; status = 'Blocked'; exitCode = 1; category = 'ToolUnavailable' }
            }
        }
        $context = Get-RepositoryExportContext -SourceRoot $SourceRoot -ExpectedSourceCommit $ExpectedSourceCommit `
            -DestinationRoot $DestinationRoot -Manifest $Manifest -Profile $Profile -RepositoryIdentity $RepositoryIdentity `
            -ToolIdentities $ToolIdentities -NativeCommandRunner $NativeCommandRunner -GitBlobReader $GitBlobReader -Independent
        $sourceSnapshotDigest = Get-RunbookContentDigest $context.snapshot
        $frozenTools = ConvertFrom-CustomerExportJson -Text ($ToolIdentities | ConvertTo-Json -Depth 10 -Compress) -RequireObjectRoot
        $result.provenance.sourceSnapshotDigest = $sourceSnapshotDigest
        $result.provenance.toolIdentities = $context.assessment.toolIdentities
        # Reconstruct bytes afresh, not from assessment hashes, Apply logs or candidate metadata.
        foreach ($path in $context.engine.copyFiles) {
            [byte[]]$original = @(& $context.reader $ToolIdentities.Git.path $SourceRoot $ExpectedSourceCommit.ToLowerInvariant() $path)
            $rules = @($Manifest.replacements | Where-Object path -CEQ $path)
            $converted = Convert-CustomerExportBlob -Path $path -OriginalBytes $original -Rules $rules
            if ((Get-CustomerExportTextKind -Path $path -Bytes $converted.bytes).kind -cne 'Utf8Text') { throw 'Unsupported committed content.' }
            $expected.Add($path, [byte[]]$converted.bytes)
        }
        $result.expectedFileCount = $expected.Count
        $inspection = Test-RepositoryExportReconstructedTree -Root $DestinationRoot -Expected $expected -Manifest $Manifest -Profile $Profile
        Merge-RepositoryExportInspection -Result $result -Inspection $inspection
        if (@($result.deniedFindings).Count -eq 0 -and @($result.unexpectedPaths).Count -eq 0 -and
            @($result.missingPaths).Count -eq 0 -and @($result.mismatchedPaths).Count -eq 0) {
            $prerequisites = @(Get-RepositoryExportSuitePrerequisites -Manifest $Manifest -Paths @($expected.Keys) -Profile $Profile)
            foreach ($prerequisite in $prerequisites) {
                if (@($result.suiteResults | Where-Object suite -CEQ $prerequisite.suite).Count -eq 0) { $result.suiteResults += $prerequisite }
            }
            foreach ($suite in @($Manifest.validationSuites)) {
                if (@($result.suiteResults | Where-Object suite -CEQ $suite).Count -gt 0) { continue }
                try {
                    Assert-RepositoryExportToolFiles -Tools $frozenTools
                    if ((Get-RunbookContentDigest $Manifest) -cne $manifestDigest) { throw 'Reviewed input drifted.' }
                    $command = Get-RepositoryExportValidationCommand -Suite $suite -ToolIdentities $frozenTools -Root $DestinationRoot -Profile $Profile
                    $suiteResult = & $ValidationRunner $suite $command.filePath @($command.arguments) $DestinationRoot
                    if ($null -eq $suiteResult -or $suiteResult -is [array] -or
                        $null -eq $suiteResult.PSObject.Properties['suite'] -or $suiteResult.suite -cne $suite -or
                        $null -eq $suiteResult.PSObject.Properties['exitCode'] -or $suiteResult.exitCode -isnot [int]) { throw 'Invalid suite result.' }
                    $result.suiteResults += [pscustomobject]@{
                        suite = $suite; exitCode = $suiteResult.exitCode
                        status = if ($suiteResult.exitCode -eq 0) { 'Passed' } else { 'Failed' }
                        category = if ($suiteResult.exitCode -eq 0) { 'None' } else { 'ValidationSuiteFailed' }
                    }
                }
                catch {
                    $result.suiteResults += [pscustomobject]@{ suite = $suite; exitCode = 1; status = 'Failed'; category = 'ValidationSuiteFailed' }
                }
                finally {
                    # A failing or throwing runner is mutable too: do not let it suppress inspection.
                    $inspection = Test-RepositoryExportReconstructedTree -Root $DestinationRoot -Expected $expected -Manifest $Manifest -Profile $Profile
                    Merge-RepositoryExportInspection -Result $result -Inspection $inspection
                }
                if (-not $inspection.passed) { break }
            }
        }
    }
    catch {
        $category = if ($null -eq $context) { 'SourceVerificationUnavailable' } else { 'ReconstructionFailed' }
        if (-not $toolPrerequisite) { $result.deniedFindings += [pscustomobject]@{ category = $category; path = $null } }
    }
    finally {
        if ($null -ne $context) {
            try {
                Assert-RepositoryExportToolFiles -Tools ([pscustomobject]@{ Git = $frozenTools.Git })
                $post = Get-CustomerExportSourceSnapshot -RepositoryRoot $SourceRoot -GitExecutable $frozenTools.Git `
                    -NativeCommandRunner $context.runner -GitBlobReader $context.reader
                $result.sourceUnchanged = $sourceSnapshotDigest -ceq (Get-RunbookContentDigest $post)
                $result.provenance.sourceVerification = if ($result.sourceUnchanged) { 'Matched' } else { 'Mismatch' }
            }
            catch { $result.provenance.sourceVerification = 'Unavailable' }
            try { Assert-RepositoryExportToolFiles -Tools $frozenTools }
            catch { $result.deniedFindings += [pscustomobject]@{ category = 'ToolIdentityDrift'; path = $null } }
        }
        else {
            # Unavailable source proof must not suppress object and deny-boundary inspection.
            try {
                $inventory = Get-HistoryFreeRepositoryInventory -Root $DestinationRoot
                $result.actualFileCount = @($inventory.files).Count
                $result.deniedFindings += @($inventory.findings)
                foreach ($path in @($inventory.files) + @($inventory.directories)) {
                    $category = Get-RepositoryExportPathDenial -Path $path -Manifest $Manifest -Profile $Profile `
                        -Directory:($inventory.directories -ccontains $path)
                    if ($category) { $result.deniedFindings += [pscustomobject]@{ category = $category; path = $path } }
                }
            }
            catch { $result.deniedFindings += [pscustomobject]@{ category = 'ObjectInspectionUnavailable'; path = $null } }
        }
        if ((Get-RunbookContentDigest $Manifest) -cne $manifestDigest -or
            (Get-RunbookContentDigest (Get-RepositoryExportFixedPolicy -Profile $Profile)) -cne $policyDigest) {
            $result.deniedFindings += [pscustomobject]@{ category = 'ReviewedInputDrift'; path = $null }
        }
    }
    $treeFailed = @($result.unexpectedPaths).Count + @($result.missingPaths).Count + @($result.mismatchedPaths).Count + @($result.deniedFindings).Count -gt 0
    if ($toolPrerequisite -and -not $treeFailed) { $result.status = 'Blocked' }
    elseif (-not $result.sourceUnchanged -or $treeFailed -or @($result.suiteResults | Where-Object status -CEQ 'Failed').Count -gt 0) { $result.status = 'Failed' }
    elseif (@($result.suiteResults | Where-Object category -CEQ 'PipelineAssetsMissing').Count -gt 0) { $result.status = 'PendingPrerequisite' }
    elseif (@($result.suiteResults | Where-Object status -CEQ 'Blocked').Count -gt 0 -or @($result.suiteResults).Count -ne @($Manifest.validationSuites).Count) { $result.status = 'Blocked' }
    else { $result.status = 'Passed' }
    $result
}
