function Read-RepositoryExportRecord {
    param([Parameter(Mandatory)][string]$Path)
    Assert-RepositoryExportLocalPath -Path $Path
    ConvertFrom-CustomerExportJson -Text (Read-CustomerExportUtf8Text -Path $Path) -RequireObjectRoot
}

function Write-RepositoryExportRecord {
    param([Parameter(Mandatory)][object]$Record, [Parameter(Mandatory)][string]$Path)
    Assert-RepositoryExportLocalPath -Path $Path
    $WhatIfPreference = $false
    Write-CanonicalJson -InputObject $Record -Path $Path | Out-Null
    $readBack = Read-RepositoryExportRecord -Path $Path
    if ((Get-RunbookContentDigest $readBack) -cne (Get-RunbookContentDigest $Record)) {
        throw 'Repository export evidence read-back failed.'
    }
}

function Assert-RepositoryExportApproval {
    param($Approval, $Execution, [guid]$RunId, [datetime]$NowUtc)
    Test-TenantLifecycleContract -Kind Approval -InputObject $Approval | Out-Null
    $generated = [datetimeoffset]::Parse($Execution.generatedAtUtc, [Globalization.CultureInfo]::InvariantCulture)
    $approved = [datetimeoffset]::Parse($Approval.approvedAtUtc, [Globalization.CultureInfo]::InvariantCulture)
    $expires = [datetimeoffset]::Parse($Approval.expiresAtUtc, [Globalization.CultureInfo]::InvariantCulture)
    $scope = @(Get-RepositoryExportActionOrder)
    if ($Approval.runId -cne $RunId.ToString('D') -or $Execution.runId -cne $RunId.ToString('D') -or
        $Approval.executionManifestDigest -cne $Execution.digest -or
        (Get-RunbookContentDigest $Approval.scope) -cne (Get-RunbookContentDigest $scope) -or
        $approved -lt $generated -or $approved -gt [datetimeoffset]$NowUtc.ToUniversalTime() -or
        $expires -le $approved -or $expires -gt $generated.AddMinutes(30) -or
        [datetimeoffset]$NowUtc.ToUniversalTime() -ge $expires) {
        throw 'Repository export approval run, digest, scope or freshness does not match.'
    }
}

function Assert-RepositoryExportBoundaries {
    param([string]$SourceRoot, [string]$DestinationRoot, [string]$EvidenceRoot, [string]$ManifestPath)
    foreach ($path in @($SourceRoot, $DestinationRoot, $EvidenceRoot, $ManifestPath)) { Assert-RepositoryExportLocalPath -Path $path }
    if (Test-Path -LiteralPath $DestinationRoot) { throw 'Repository export destination must not already exist.' }
    $roots = @($SourceRoot, $DestinationRoot, $EvidenceRoot)
    foreach ($root in $roots) {
        if (Test-RunbookPathWithin -Path $ManifestPath -Root $root) {
            throw 'Repository export private intent must be outside source, destination and evidence.'
        }
    }
    for ($i = 0; $i -lt $roots.Count; $i++) {
        for ($j = $i + 1; $j -lt $roots.Count; $j++) {
            if ((Test-RunbookPathWithin -Path $roots[$i] -Root $roots[$j]) -or
                (Test-RunbookPathWithin -Path $roots[$j] -Root $roots[$i])) {
                throw 'Repository export source, destination and evidence boundaries overlap.'
            }
        }
    }
    foreach ($root in @($DestinationRoot, $EvidenceRoot)) {
        $cursor = [IO.Path]::GetFullPath($root)
        while ($cursor) {
            if (Test-Path -LiteralPath (Join-Path $cursor '.git')) { throw 'Repository export output must be outside every Git worktree.' }
            $parent = Split-Path -Parent $cursor
            if ($parent -ceq $cursor) { break }
            $cursor = $parent
        }
    }
    if (-not (Test-Path -LiteralPath (Split-Path $DestinationRoot -Parent) -PathType Container)) {
        throw 'Repository export destination parent must exist.'
    }
}

function Assert-RepositoryExportApplyBinding {
    param([Parameter(Mandatory)][object]$Binding)
    Assert-RepositoryExportBoundaries -SourceRoot $Binding.source -DestinationRoot $Binding.destination `
        -EvidenceRoot $Binding.evidence -ManifestPath $Binding.manifestPath
    $manifest = Import-RepositoryExportManifest -Path $Binding.manifestPath -ExpectedProfile $Binding.profile
    if ((Get-RunbookContentDigest $manifest) -cne $Binding.manifestDigest) { throw 'Repository export manifest changed during Apply.' }
    $execution = Read-RepositoryExportRecord -Path $Binding.executionPath
    $approval = Read-RepositoryExportRecord -Path $Binding.approvalPath
    if ((Get-RunbookContentDigest $execution) -cne $Binding.executionDigest -or
        (Get-RunbookContentDigest $approval) -cne $Binding.approvalDigest) {
        throw 'Repository export approval or execution manifest changed during Apply.'
    }
    Assert-RepositoryExportApproval -Approval $approval -Execution $execution -RunId $Binding.runId `
        -NowUtc $Binding.now.Add($Binding.clock.Elapsed)
    foreach ($tool in $Binding.tools.PSObject.Properties) {
        Assert-RepositoryExportLocalPath -Path $tool.Value.path -AllowHardLink
        if ((Get-CustomerExportFileDigest -Path $tool.Value.path) -cne $tool.Value.sha256) {
            throw 'Repository export tool changed during Apply.'
        }
    }
}

function Invoke-RepositoryExportOperation {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)][ValidateSet('Assess', 'Plan', 'Invoke')][string]$Operation,
        [Parameter(Mandatory)][guid]$RunId,
        [Parameter(Mandatory)][string]$EvidenceRoot,
        [Parameter(Mandatory)][string]$SourceRoot,
        [Parameter(Mandatory)][ValidatePattern('^[0-9a-fA-F]{40}$')][string]$ExpectedSourceCommit,
        [Parameter(Mandatory)][string]$DestinationRoot,
        [Parameter(Mandatory)][string]$ManifestPath,
        [Parameter(Mandatory)][ValidateSet('TenantReplica', 'CustomerHandover')][string]$Profile,
        [Parameter(Mandatory)][ValidatePattern('^[0-9a-fA-F]{64}$')][string]$RepositoryIdentity,
        [string]$ExecutionManifestPath,
        [ValidatePattern('^[0-9a-fA-F]{64}$')][string]$ApprovedDigest,
        [switch]$Apply,
        [switch]$Independent,
        [Parameter(DontShow)][scriptblock]$NativeCommandRunner,
        [Parameter(DontShow)][scriptblock]$CommandResolver,
        [Parameter(DontShow)][scriptblock]$FileIdentityProvider,
        [Parameter(DontShow)][scriptblock]$GitBlobReader,
        [Parameter(DontShow)][scriptblock]$ValidationRunner,
        [Parameter(DontShow)][scriptblock]$InteractiveHostProbe,
        [Parameter(DontShow)][scriptblock]$OperatorIdProvider,
        [Parameter(DontShow)][scriptblock]$PlatformProbe,
        [Parameter(DontShow)][datetime]$NowUtc = [datetime]::UtcNow
    )
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'
    $requestedWhatIf = [bool]$WhatIfPreference
    $requestedConfirm = $ConfirmPreference
    $WhatIfPreference = $false
    $ConfirmPreference = 'None'
    $clock = [Diagnostics.Stopwatch]::StartNew()
    if ($RunId.ToString('D') -cnotmatch '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$') {
        throw 'Repository export run ID is invalid.'
    }
    if ($Independent) { throw 'Independent repository export validation is unavailable until the Task 5 validator exists.' }
    if ($Profile -cnotin @('TenantReplica', 'CustomerHandover')) { throw 'Repository export profile is invalid.' }
    Assert-RepositoryExportBoundaries -SourceRoot $SourceRoot -DestinationRoot $DestinationRoot -EvidenceRoot $EvidenceRoot -ManifestPath $ManifestPath
    $child = Join-Path ([IO.Path]::GetFullPath($EvidenceRoot)) ($RunId.ToString('D') + '\phases\RepositoryExport')
    Assert-RepositoryExportLocalPath -Path $child
    $executionPath = Join-Path $child 'execution-manifest.json'
    $manifest = Import-RepositoryExportManifest -Path $ManifestPath -ExpectedProfile $Profile
    if ($null -eq $InteractiveHostProbe) { $InteractiveHostProbe = { Get-DefaultInteractiveHostState } }
    if ($null -eq $PlatformProbe) { $PlatformProbe = { Get-DefaultPlatformState } }
    if ($null -eq $OperatorIdProvider) { $OperatorIdProvider = { [Security.Principal.WindowsIdentity]::GetCurrent().Name } }
    $hostState = & $InteractiveHostProbe
    $platform = & $PlatformProbe
    $operator = [string](& $OperatorIdProvider)
    if (-not $hostState.isInteractive -or $platform.productName -cne 'Windows 11' -or [int]$platform.build -lt 22000) {
        throw 'Repository export requires an interactive Windows 11 PowerShell session.'
    }
    if ([string]::IsNullOrWhiteSpace($operator) -or $operator -match '[\x00-\x1f]') { throw 'Repository export operator identity is required.' }
    $execution = $null
    if ($Operation -ceq 'Invoke') {
        Assert-RepositoryExportLocalPath -Path $ExecutionManifestPath
        if ([IO.Path]::GetFullPath($ExecutionManifestPath) -cne $executionPath) {
            throw 'Repository export requires the exact child execution-manifest.json path.'
        }
        $execution = Read-RepositoryExportRecord -Path $executionPath
        Assert-TenantLifecycleTimestamp -Value $execution.generatedAtUtc
        Test-RunbookExecutionManifest -Manifest $execution -ApprovedDigest $ApprovedDigest -CurrentSourceCommit $ExpectedSourceCommit `
            -CurrentAssessmentDigest $execution.assessmentDigest -CurrentAuthenticationContext $execution.authentication `
            -AllowedActionNames @(Get-RepositoryExportActionOrder) -NowUtc $NowUtc | Out-Null
        $approval = Read-RepositoryExportRecord -Path (Join-Path $child 'approvals.json')
        Assert-RepositoryExportApproval -Approval $approval -Execution $execution -RunId $RunId -NowUtc $NowUtc
    }
    if ($null -eq $NativeCommandRunner) { $NativeCommandRunner = New-DefaultNativeCommandRunner }
    if ($null -eq $CommandResolver) {
        $CommandResolver = {
            param($name)
            switch -CaseSensitive ($name) {
                'git.exe' { Join-Path ([Environment]::GetFolderPath('ProgramFiles')) 'Git\cmd\git.exe' }
                'powershell.exe' { Join-Path ([Environment]::SystemDirectory) 'WindowsPowerShell\v1.0\powershell.exe' }
                default { throw 'Canonical staged validation tool binding is unavailable; no provider executable is resolved.' }
            }
        }
    }
    if ($null -eq $FileIdentityProvider) { $FileIdentityProvider = New-DefaultFileIdentityProvider }
    $approvedTools = if ($null -eq $execution) { $null } else { $execution.toolVersions }
    $tools = New-ToolIdentities -ValidationSuites @($manifest.validationSuites) -Resolver $CommandResolver `
        -IdentityProvider $FileIdentityProvider -Runner $NativeCommandRunner -ApprovedProof $approvedTools -StrictTools
    $context = Get-RepositoryExportContext -SourceRoot $SourceRoot -ExpectedSourceCommit $ExpectedSourceCommit `
        -DestinationRoot $DestinationRoot -Manifest $manifest -Profile $Profile -RepositoryIdentity $RepositoryIdentity `
        -ToolIdentities $tools -NativeCommandRunner $NativeCommandRunner -GitBlobReader $GitBlobReader
    $assessment = $context.assessment
    $binding = [ordered]@{
        manifestPathDigest = Get-RepositoryExportPathIdentity $ManifestPath
        operatorDigest = Get-RunbookContentDigest $operator
        machineDigest = Get-RunbookContentDigest ([Environment]::MachineName)
        childPathDigest = Get-RepositoryExportPathIdentity $child
    }
    $assessment | Add-Member NoteProperty invocationDigest (Get-RunbookContentDigest $binding)
    $unsigned = [ordered]@{}
    foreach ($property in $assessment.PSObject.Properties | Where-Object Name -CNE 'digest') { $unsigned[$property.Name] = $property.Value }
    $assessment.digest = Get-RunbookContentDigest $unsigned
    $context.engine.digest = $assessment.digest
    $generated = if ($null -eq $execution) { $NowUtc } else { [datetime]::Parse($execution.generatedAtUtc, [Globalization.CultureInfo]::InvariantCulture).ToUniversalTime() }
    $plan = New-RepositoryExportActionPlan -Assessment $assessment -Manifest $manifest -RunId $RunId -EvidenceRoot $EvidenceRoot -NowUtc $generated
    if ($Operation -ceq 'Assess') {
        Write-RepositoryExportRecord -Record $assessment -Path (Join-Path $child 'assessment.json')
        return $assessment
    }
    if ($Operation -ceq 'Plan') {
        if (Test-Path -LiteralPath $executionPath) { throw 'Repository export plan already exists; use a new run.' }
        Write-RepositoryExportRecord -Record $plan.executionManifest -Path $executionPath
        return $plan
    }
    Test-RunbookExecutionManifest -Manifest $execution -ApprovedDigest $ApprovedDigest -CurrentSourceCommit $assessment.sourceCommit `
        -CurrentAssessmentDigest $assessment.digest -CurrentAuthenticationContext $plan.executionManifest.authentication `
        -AllowedActionNames @(Get-RepositoryExportActionOrder) -NowUtc $NowUtc | Out-Null
    if ($plan.digest -cne $execution.digest) { throw 'Repository export bound inputs or authorization drifted.' }
    $record = [ordered]@{
        schemaVersion = '1.0'; runId = $RunId.ToString('D'); profile = $Profile
        sourceCommit = $assessment.sourceCommit; assessmentDigest = $assessment.digest
        executionManifestDigest = $execution.digest; sourceSnapshotDigest = $assessment.sourceSnapshotDigest
        retainedFileCount = $assessment.retainedFileCount; deniedFileCount = $assessment.deniedFileCount
        status = 'NotApplied'; shouldProcess = 'NotApplicable'
    }
    if (-not $Apply) { return [pscustomobject]$record }
    $evidencePath = Join-Path $child 'apply.json'
    if (Test-Path -LiteralPath $evidencePath) { throw 'Repository export Apply evidence already exists; use a new run.' }
    $WhatIfPreference = $requestedWhatIf
    $ConfirmPreference = $requestedConfirm
    $proceed = $PSCmdlet.ShouldProcess($assessment.destinationStableId, "Create approved $Profile local export")
    $WhatIfPreference = $false
    $ConfirmPreference = 'None'
    if (-not $proceed) {
        $record.status = 'NotApplied'
        $record.shouldProcess = if ($requestedWhatIf) { 'WhatIf' } else { 'Declined' }
        Write-RepositoryExportRecord -Record ([pscustomobject]$record) -Path (Join-Path $child ($record.shouldProcess.ToLowerInvariant() + '.json'))
        return [pscustomobject]$record
    }
    $record.shouldProcess = 'Approved'
    try {
        if ($null -eq $ValidationRunner) { throw 'Canonical staged validation runner is unavailable; no provider or arbitrary retained script is executed.' }
        $bound = [pscustomobject]@{
            source = $SourceRoot; destination = $DestinationRoot; evidence = $EvidenceRoot
            manifestPath = $ManifestPath; profile = $Profile; manifestDigest = $assessment.manifestDigest
            executionPath = $executionPath; executionDigest = Get-RunbookContentDigest $execution
            approvalPath = Join-Path $child 'approvals.json'; approvalDigest = Get-RunbookContentDigest $approval
            runId = $RunId; now = $NowUtc; clock = $clock; tools = $tools
        }
        $copied = Invoke-RepositoryExportCopy -SourceRoot $SourceRoot -ExpectedSourceCommit $ExpectedSourceCommit `
            -DestinationRoot $DestinationRoot -Manifest $manifest -Assessment $context.engine -ExecutionManifest $execution `
            -SourceSnapshot $context.snapshot -ToolIdentities $tools -NativeCommandRunner $context.runner `
            -GitBlobReader $context.reader -ValidationRunner $ValidationRunner -BoundInputs $bound
        $record.status = 'PromotedPendingIndependent'
        $record.contentTreeDigest = $copied.contentTreeDigest
        $record.sourceImmutability = 'Verified'
        Write-RepositoryExportRecord -Record ([pscustomobject]$record) -Path $evidencePath
        [pscustomobject]$record
    }
    catch {
        $record.status = 'Failed'
        Write-RepositoryExportRecord -Record ([pscustomobject]$record) -Path $evidencePath
        throw
    }
}
