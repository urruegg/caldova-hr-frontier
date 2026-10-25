function Test-LegacyCustomerExport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('CustomerHandover')][string]$Profile,
        [Parameter(Mandatory)][string]$SourceRoot,
        [Parameter(Mandatory)][ValidatePattern('^[0-9a-fA-F]{40}$')][string]$ExpectedSourceCommit,
        [Parameter(Mandatory)][string]$DestinationRoot,
        [Parameter(Mandatory)][string]$ManifestPath,
        [Parameter(Mandatory)][string]$ExecutionManifestPath,
        [Parameter(Mandatory)][ValidatePattern('^[0-9a-fA-F]{64}$')][string]$ApprovedDigest,
        [string]$ReportPath,
        [scriptblock]$NativeCommandRunner,
        [scriptblock]$CommandResolver,
        [scriptblock]$FileIdentityProvider,
        [scriptblock]$GitBlobReader,
        [scriptblock]$ValidationRunner,
        [scriptblock]$InteractiveHostProbe,
        [scriptblock]$OperatorIdProvider,
        [scriptblock]$PlatformProbe,
        [datetime]$NowUtc = [datetime]::UtcNow
    )
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'
    if ($null -eq $NativeCommandRunner) { $NativeCommandRunner = New-DefaultNativeCommandRunner }
    if ($null -eq $CommandResolver) { $CommandResolver = New-DefaultCommandResolver }
    if ($null -eq $FileIdentityProvider) { $FileIdentityProvider = New-DefaultFileIdentityProvider }
    if ($null -eq $GitBlobReader) { $GitBlobReader = New-DefaultGitBlobReader }
    if ($null -eq $InteractiveHostProbe) { $InteractiveHostProbe = { Get-DefaultInteractiveHostState } }
    if ($null -eq $PlatformProbe) { $PlatformProbe = { Get-DefaultPlatformState } }
    if ($null -eq $OperatorIdProvider) { $OperatorIdProvider = { [Security.Principal.WindowsIdentity]::GetCurrent().Name } }
    if ($null -eq $ValidationRunner) { $ValidationRunner = New-DefaultValidationRunner -Runner $NativeCommandRunner }
    $interactiveState = & $InteractiveHostProbe
    if (-not [bool]$interactiveState.isInteractive) { throw 'This runbook requires an interactive Windows 11 PowerShell session.' }
    $platformState = & $PlatformProbe
    if ([string]$platformState.productName -cne 'Windows 11' -or [int]$platformState.build -lt 22000) {
        throw 'This runbook requires Windows 11 build 22000 or later.'
    }
    $operatorId = [string](& $OperatorIdProvider)
    if ([string]::IsNullOrWhiteSpace($operatorId) -or $operatorId -match '[\x00-\x1F]') { throw 'Operator identity is required.' }
    $manifest = Import-CustomerExportManifest -Path $ManifestPath
    Assert-RepositoryExportManifestContract -Manifest $manifest -ExpectedProfile $Profile
    $manifestDigest = Get-RunbookContentDigest -InputObject $manifest
    $executionManifest = Get-Content -Raw -LiteralPath $ExecutionManifestPath | ConvertFrom-Json
    $authentication = [pscustomobject]@{ executionHost = 'InteractiveWindows11PowerShell'; mode = 'NotApplicable' }
    $allowed = @('CreateCustomerExport', 'CopyTrackedBlob', 'ApplyStructuredReplacement', 'ValidateCustomerExport', 'PromoteCustomerExport')
    Test-RunbookExecutionManifest -Manifest $executionManifest -ApprovedDigest $ApprovedDigest `
        -CurrentSourceCommit ([string]$executionManifest.sourceCommit) -CurrentAssessmentDigest ([string]$executionManifest.assessmentDigest) `
        -CurrentAuthenticationContext $executionManifest.authentication -AllowedActionNames $allowed `
        -NowUtc $NowUtc -MaximumAge ([timespan]::FromMinutes(30)) | Out-Null
    $toolIdentities = New-ToolIdentities -ValidationSuites @($manifest.validationSuites) `
        -Resolver $CommandResolver -IdentityProvider $FileIdentityProvider -Runner $NativeCommandRunner `
        -ApprovedIdentities $executionManifest.toolVersions
    foreach ($tool in @($executionManifest.toolVersions.PSObject.Properties.Name)) {
        if ($null -eq $toolIdentities.PSObject.Properties[$tool] -or
            -not (Test-ExactToolIdentity -Expected $executionManifest.toolVersions.$tool -Actual $toolIdentities.$tool)) {
            throw 'Required executable identity changed before approved manifest validation.'
        }
    }
    $git = $toolIdentities.Git
    $snapshot = Get-CustomerExportSourceSnapshot -RepositoryRoot $SourceRoot -GitExecutable $git `
        -NativeCommandRunner $NativeCommandRunner -GitBlobReader $GitBlobReader
    $catalog = Get-CustomerSourceMarkerCatalog -RepositoryRoot $SourceRoot -ExpectedSourceCommit $ExpectedSourceCommit `
        -TrackedFiles @($snapshot.trackedFiles) -RetainedTenantArtifacts @($manifest.retainedTenantArtifacts) `
        -SourceMarkerCatalog @($manifest.sourceMarkerCatalog) -GitExecutable $git -GitBlobReader $GitBlobReader
    $assessment = Get-CustomerExportAssessment -SourceRoot $SourceRoot -ExpectedSourceCommit $ExpectedSourceCommit `
        -DestinationRoot $DestinationRoot -Manifest $manifest -ManifestDigest $manifestDigest -SourceSnapshot $snapshot `
        -ToolIdentities $toolIdentities -MarkerCatalogProof $catalog -GitExecutable $git -GitBlobReader $GitBlobReader -AllowExistingDestination
    Test-RunbookExecutionManifest -Manifest $executionManifest -ApprovedDigest $ApprovedDigest -CurrentSourceCommit $assessment.sourceCommit `
        -CurrentAssessmentDigest $assessment.digest -CurrentAuthenticationContext $authentication -AllowedActionNames $allowed `
        -NowUtc $NowUtc -MaximumAge ([timespan]::FromMinutes(30)) | Out-Null
    $current = New-ToolIdentities -ValidationSuites @($manifest.validationSuites) -Resolver $CommandResolver `
        -IdentityProvider $FileIdentityProvider -Runner $NativeCommandRunner -ApprovedIdentities $executionManifest.toolVersions
    foreach ($tool in @($toolIdentities.PSObject.Properties.Name)) {
        if (-not (Test-ExactToolIdentity -Expected $toolIdentities.$tool -Actual $current.$tool) -or
            -not (Test-ExactToolIdentity -Expected $assessment.toolIdentities.$tool -Actual $current.$tool)) {
            throw 'Required executable identity changed before validation.'
        }
    }
    $root = [IO.Path]::GetFullPath($DestinationRoot)
    Assert-RepositoryExportTree -Root $root
    $log = [Collections.Generic.List[object]]::new()
    foreach ($path in @($assessment.copyFiles | Sort-Object)) {
        [byte[]]$original = @(& $GitBlobReader $git.path ([IO.Path]::GetFullPath($SourceRoot)) $ExpectedSourceCommit.ToLowerInvariant() $path)
        $tracked = @($snapshot.trackedFiles | Where-Object path -CEQ $path) | Select-Object -First 1
        if ($null -eq $tracked -or (Get-CustomerExportSha256 -Bytes $original) -cne [string]$tracked.blobSha256) {
            throw 'Customer export source tracked blob could not be proven.'
        }
        $converted = Convert-CustomerExportBlob -Path $path -OriginalBytes $original -Rules @($manifest.replacements | Where-Object path -CEQ $path)
        $target = Join-Path $root $path.Replace('/', '\')
        if (-not (Test-Path -LiteralPath $target -PathType Leaf) -or
            (Get-CustomerExportFileDigest -Path $target) -cne (Get-CustomerExportSha256 -Bytes $converted.bytes)) {
            $log.Clear()
            $log.Add([pscustomobject]@{ category = 'ExpectedOutputMismatch'; path = $path })
            break
        }
        foreach ($entry in @($converted.replacementLog)) { $log.Add($entry) }
    }
    $result = Test-CustomerExportContent -StagingRoot $root -Manifest $manifest -Assessment $assessment `
        -ExecutionManifest $executionManifest -CurrentSourceSnapshot $snapshot -ReplacementLog @($log) -ValidationRunner $ValidationRunner
    $mismatches = @($log | Where-Object { $_.PSObject.Properties.Name -contains 'category' -and $_.category -ceq 'ExpectedOutputMismatch' })
    if ($mismatches.Count -gt 0) {
        $result.failures = @($result.failures) + $mismatches
        $result.publishReady = $false
        $result.status = 'Failed'
    }
    try {
        Get-RepositoryExportVerifiedTreeDigest -Root $root -Assessment $assessment | Out-Null
    }
    catch {
        $result.failures = @($result.failures) + @([pscustomobject]@{ category = 'FinalTreeVerificationFailed'; path = $null })
        $result.publishReady = $false
        $result.status = 'Failed'
    }
    $post = Get-CustomerExportSourceSnapshot -RepositoryRoot $SourceRoot -GitExecutable $git -NativeCommandRunner $NativeCommandRunner -GitBlobReader $GitBlobReader
    if ((Get-RunbookContentDigest $post) -cne (Get-RunbookContentDigest $snapshot)) { throw 'Source snapshot changed during validation.' }
    $reportRoot = Resolve-RunbookReportPath -RunId ([guid]$executionManifest.runId) -Path $ReportPath -RepositoryRoot $SourceRoot
    [void][IO.Directory]::CreateDirectory($reportRoot)
    Write-CanonicalJson -InputObject $result -Path (Join-Path $reportRoot 'customer-export-validation.json') -Replace | Out-Null
    $evidence = ConvertTo-RunbookEvidenceRecord -RunId ([guid]$executionManifest.runId) -GeneratedAtUtc $NowUtc `
        -SourceCommit $assessment.sourceCommit -AssessmentDigest $assessment.digest -PlanDigest $executionManifest.digest `
        -ManifestDigest $manifestDigest -OperatorId $operatorId -Operation 'ValidateCustomerRepositoryExport' -Classification NoChange `
        -Status $(if ($result.publishReady) { 'Verified' } else { 'Failed' }) -ShouldProcessDecision NotApplicable `
        -TargetId $assessment.destinationStableId -ToolVersions (ConvertTo-EvidenceToolVersions $assessment.toolIdentities) `
        -FinalContext ([pscustomobject]@{ status = 'SourceSnapshotMatched' }) `
        -ErrorCategory $(if ($result.publishReady) { $null } else { 'ExportValidationFailed' })
    Write-CanonicalJson -InputObject $evidence -Path (Join-Path $reportRoot 'customer-export-validation-evidence.json') -Replace | Out-Null
    if (-not $result.publishReady) { throw 'Customer export validation did not produce a publish-ready result.' }
    $result
}
