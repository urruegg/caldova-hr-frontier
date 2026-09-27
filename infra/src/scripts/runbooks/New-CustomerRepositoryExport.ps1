[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)][string]$SourceRoot,
    [Parameter(Mandatory)][ValidatePattern('^[0-9a-fA-F]{40}$')][string]$ExpectedSourceCommit,
    [Parameter(Mandatory)][string]$DestinationRoot,
    [Parameter(Mandatory)][string]$ManifestPath,
    [string]$ReportPath,
    [string]$ExecutionManifestPath,
    [ValidatePattern('^[0-9a-fA-F]{64}$')][string]$ApprovedDigest,
    [switch]$Apply,
    [scriptblock]$NativeCommandRunner,
    [scriptblock]$CommandResolver,
    [scriptblock]$FileIdentityProvider,
    [scriptblock]$GitBlobReader,
    [scriptblock]$ValidationRunner,
    [scriptblock]$InteractiveHostProbe,
    [Parameter(DontShow)][scriptblock]$OperatorIdProvider,
    [Parameter(DontShow)][scriptblock]$PlatformProbe,
    [datetime]$NowUtc = [datetime]::UtcNow
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function New-DefaultNativeCommandRunner {
    {
        param([string]$FilePath, [string[]]$ArgumentList)
        $previousErrorActionPreference = $ErrorActionPreference
        $nativeErrorPreferenceExists = Test-Path Variable:PSNativeCommandUseErrorActionPreference
        $previousNativeErrorPreference = if ($nativeErrorPreferenceExists) {
            $PSNativeCommandUseErrorActionPreference
        } else {
            $null
        }
        try {
            $ErrorActionPreference = 'Continue'
            if ($nativeErrorPreferenceExists) {
                $PSNativeCommandUseErrorActionPreference = $false
            }
            $output = @(& $FilePath @ArgumentList 2>&1 | ForEach-Object { $_.ToString() })
            $exitCode = if ($null -ne $LASTEXITCODE) { [int]$LASTEXITCODE } else { 0 }
        }
        finally {
            $ErrorActionPreference = $previousErrorActionPreference
            if ($nativeErrorPreferenceExists) {
                $PSNativeCommandUseErrorActionPreference = $previousNativeErrorPreference
            }
        }
        [pscustomobject]@{ exitCode = $exitCode; stdout = ($output -join [Environment]::NewLine); stderr = '' }
    }.GetNewClosure()
}

function New-DefaultCommandResolver {
    { param($name) @(Get-Command $name -All -CommandType Application -ErrorAction SilentlyContinue | ForEach-Object Source) }.GetNewClosure()
}

function New-DefaultFileIdentityProvider {
    {
        param($path)
        [pscustomobject]@{
            path = [IO.Path]::GetFullPath($path)
            sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
        }
    }.GetNewClosure()
}

function ConvertTo-WindowsProcessArgument {
    param([AllowEmptyString()][string]$Value)

    if ($null -eq $Value) { return '""' }
    if ($Value -notmatch '[\s"]') { return $Value }

    $builder = [Text.StringBuilder]::new('"')
    $backslashCount = 0
    foreach ($character in $Value.ToCharArray()) {
        if ($character -eq '\') {
            $backslashCount++
            continue
        }
        if ($character -eq '"') {
            [void]$builder.Append(('\' * (($backslashCount * 2) + 1)))
            [void]$builder.Append('"')
            $backslashCount = 0
            continue
        }
        if ($backslashCount -gt 0) {
            [void]$builder.Append(('\' * $backslashCount))
            $backslashCount = 0
        }
        [void]$builder.Append($character)
    }
    if ($backslashCount -gt 0) {
        [void]$builder.Append(('\' * ($backslashCount * 2)))
    }
    [void]$builder.Append('"')
    $builder.ToString()
}

function Join-WindowsProcessArguments {
    param([Parameter(Mandatory)][string[]]$ArgumentList)

    (@($ArgumentList) | ForEach-Object { ConvertTo-WindowsProcessArgument -Value ([string]$_) }) -join ' '
}

function New-DefaultGitBlobReader {
    {
        param([string]$GitPath, [string]$RepositoryRoot, [string]$Commit, [string]$Path)

        function Join-Arguments {
            param([string[]]$Values)
            function Quote-Argument {
                param([AllowEmptyString()][string]$Value)
                if ($null -eq $Value) { return '""' }
                if ($Value -notmatch '[\s"]') { return $Value }

                $builder = [Text.StringBuilder]::new('"')
                $backslashCount = 0
                foreach ($character in $Value.ToCharArray()) {
                    if ($character -eq '\') { $backslashCount++; continue }
                    if ($character -eq '"') {
                        [void]$builder.Append(('\' * (($backslashCount * 2) + 1)))
                        [void]$builder.Append('"')
                        $backslashCount = 0
                        continue
                    }
                    if ($backslashCount -gt 0) {
                        [void]$builder.Append(('\' * $backslashCount))
                        $backslashCount = 0
                    }
                    [void]$builder.Append($character)
                }
                if ($backslashCount -gt 0) {
                    [void]$builder.Append(('\' * ($backslashCount * 2)))
                }
                [void]$builder.Append('"')
                $builder.ToString()
            }

            (@($Values) | ForEach-Object { Quote-Argument -Value ([string]$_) }) -join ' '
        }

        $process = [System.Diagnostics.Process]::new()
        $process.StartInfo = [System.Diagnostics.ProcessStartInfo]::new()
        $process.StartInfo.FileName = [IO.Path]::GetFullPath($GitPath)
        $process.StartInfo.Arguments = Join-Arguments -Values @('-C', [IO.Path]::GetFullPath($RepositoryRoot), 'show', '--no-textconv', ('{0}:{1}' -f $Commit, $Path))
        $process.StartInfo.UseShellExecute = $false
        $process.StartInfo.RedirectStandardOutput = $true
        $process.StartInfo.RedirectStandardError = $true

        try {
            [void]$process.Start()
            $stream = $process.StandardOutput.BaseStream
            $buffer = New-Object byte[] 4096
            $memory = [IO.MemoryStream]::new()
            try {
                while (($read = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                    $memory.Write($buffer, 0, $read)
                }
                $process.WaitForExit()
                $stderr = $process.StandardError.ReadToEnd()
                if ($process.ExitCode -ne 0) {
                    throw "Git commit blob read failed: $stderr"
                }
                return $memory.ToArray()
            }
            finally {
                $memory.Dispose()
            }
        }
        finally {
            $process.Dispose()
        }
    }.GetNewClosure()
}

function New-DefaultValidationRunner {
    param([Parameter(Mandatory)][scriptblock]$Runner)

    {
        param([string]$id, [string]$file, [string[]]$arguments, [string]$root)

        Push-Location -LiteralPath $root
        try {
            $nativeResult = & $Runner $file @($arguments)
        }
        finally {
            Pop-Location
        }

        if ($null -eq $nativeResult) {
            $nativeResult = [pscustomobject]@{ exitCode = 1; stdout = ''; stderr = 'runner returned no result' }
        }
        [pscustomobject]@{
            suite = $id
            executablePath = $file
            exitCode = [int]$nativeResult.exitCode
            status = if ([int]$nativeResult.exitCode -eq 0) { 'Passed' } else { 'Failed' }
        }
    }.GetNewClosure()
}

function Get-DefaultInteractiveHostState {
    [pscustomobject]@{
        isInteractive = [Environment]::UserInteractive -and [string]::IsNullOrWhiteSpace($env:CI) -and [string]::IsNullOrWhiteSpace($env:GITHUB_ACTIONS)
        reason = 'InteractiveWindows11PowerShell'
    }
}

function Get-DefaultPlatformState {
    $os = Get-CimInstance Win32_OperatingSystem
    [pscustomobject]@{
        productName = $(if ([string]$os.Caption -match 'Windows 11') { 'Windows 11' } else { [string]$os.Caption })
        build = [int]$os.BuildNumber
    }
}

function Get-ExecutableVersion {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][scriptblock]$Runner
    )

    $args = switch ($Name) {
        'git.exe' { @('--version') }
        'powershell.exe' { @('-NoProfile', '-Command', '$PSVersionTable.PSVersion.ToString()') }
        'az.cmd' { @('--version') }
        default { @('--version') }
    }
    $result = & $Runner $Path $args
    if ($null -eq $result) { throw 'Required executable version could not be read.' }
    $stdout = [string]$result.stdout
    if ($result.PSObject.Properties.Name -contains 'stdout' -and $result.stdout -is [array]) {
        $stdout = (@($result.stdout) -join [Environment]::NewLine)
    }
    $version = $stdout.Trim()
    if ([string]::IsNullOrWhiteSpace($version)) { $version = [string]$Name }
    $version
}

function New-ToolIdentities {
    param(
        [Parameter(Mandatory)][string[]]$ValidationSuites,
        [Parameter(Mandatory)][scriptblock]$Resolver,
        [Parameter(Mandatory)][scriptblock]$IdentityProvider,
        [Parameter(Mandatory)][scriptblock]$Runner,
        [object]$ApprovedIdentities
    )

    $tools = [ordered]@{}
    foreach ($toolName in @('git.exe', 'powershell.exe')) {
        $resolved = Resolve-CustomerExportExecutable -Name $toolName -CommandResolver $Resolver -FileIdentityProvider $IdentityProvider
        $key = if ($toolName -eq 'git.exe') { 'Git' } else { 'WindowsPowerShell' }
        if ($null -ne $ApprovedIdentities) {
            $expected = $ApprovedIdentities.PSObject.Properties[$key]
            if ($null -eq $expected -or [string]$expected.Value.path -cne [string]$resolved.path -or
                [string]$expected.Value.sha256 -cne [string]$resolved.sha256) {
                throw 'Required executable identity changed before approved manifest validation.'
            }
        }
        $tools[$key] = [pscustomobject]@{
            path = $resolved.path
            sha256 = $resolved.sha256
            version = Get-ExecutableVersion -Name $toolName -Path $resolved.path -Runner $Runner
        }
    }
    if (@($ValidationSuites | Where-Object { $_ -ceq 'BicepBuild' }).Count -gt 0) {
        $resolved = Resolve-CustomerExportExecutable -Name 'az.cmd' -CommandResolver $Resolver -FileIdentityProvider $IdentityProvider
        if ($null -ne $ApprovedIdentities) {
            $expected = $ApprovedIdentities.PSObject.Properties['AzureCli']
            if ($null -eq $expected -or [string]$expected.Value.path -cne [string]$resolved.path -or
                [string]$expected.Value.sha256 -cne [string]$resolved.sha256) {
                throw 'Required executable identity changed before approved manifest validation.'
            }
        }
        $tools['AzureCli'] = [pscustomobject]@{
            path = $resolved.path
            sha256 = $resolved.sha256
            version = Get-ExecutableVersion -Name 'az.cmd' -Path $resolved.path -Runner $Runner
        }
    }
    [pscustomobject]$tools
}

function Test-ExactToolIdentity {
    param([Parameter(Mandatory)][object]$Expected, [Parameter(Mandatory)][object]$Actual)
    foreach ($name in @('path', 'sha256', 'version')) {
        if ([string]$Expected.$name -cne [string]$Actual.$name) { return $false }
    }
    return $true
}

function ConvertTo-EvidenceToolVersions {
    param([Parameter(Mandatory)][object]$ToolIdentities)
    $versions = [ordered]@{}
    foreach ($property in $ToolIdentities.PSObject.Properties) {
        $versions[$property.Name] = [string]$property.Value.version
    }
    [pscustomobject]$versions
}

$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\..'))
$modulePath = Join-Path $repositoryRoot 'infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1'
Import-Module $modulePath -Force

if ($null -eq $NativeCommandRunner) { $NativeCommandRunner = New-DefaultNativeCommandRunner }
if ($null -eq $CommandResolver) { $CommandResolver = New-DefaultCommandResolver }
if ($null -eq $FileIdentityProvider) { $FileIdentityProvider = New-DefaultFileIdentityProvider }
if ($null -eq $GitBlobReader) { $GitBlobReader = New-DefaultGitBlobReader }
if ($null -eq $ValidationRunner) { $ValidationRunner = New-DefaultValidationRunner -Runner $NativeCommandRunner }
if ($null -eq $InteractiveHostProbe) { $InteractiveHostProbe = { Get-DefaultInteractiveHostState } }
if ($null -eq $PlatformProbe) { $PlatformProbe = { Get-DefaultPlatformState } }
if ($null -eq $OperatorIdProvider) { $OperatorIdProvider = { [Security.Principal.WindowsIdentity]::GetCurrent().Name } }

$interactiveState = & $InteractiveHostProbe
if (-not [bool]$interactiveState.isInteractive) { throw 'This runbook requires an interactive Windows 11 PowerShell session.' }
$platformState = & $PlatformProbe
if ([string]$platformState.productName -cne 'Windows 11' -or [int]$platformState.build -lt 22000) {
    throw 'This runbook requires Windows 11 build 22000 or later.'
}

$operatorId = [string](& $OperatorIdProvider)
if ([string]::IsNullOrWhiteSpace($operatorId) -or $operatorId -match '[\x00-\x1F]') {
    throw 'Operator identity is required.'
}
if ($Apply -and ([string]::IsNullOrWhiteSpace($ExecutionManifestPath) -or [string]::IsNullOrWhiteSpace($ApprovedDigest))) {
    throw 'Apply requires an execution manifest path and approved digest.'
}
if (-not $Apply -and (-not [string]::IsNullOrWhiteSpace($ExecutionManifestPath) -or -not [string]::IsNullOrWhiteSpace($ApprovedDigest))) {
    throw 'Approval arguments require -Apply.'
}

$runId = [guid]::NewGuid()
$resolvedReportPath = Resolve-RunbookReportPath -RunId $runId -Path $ReportPath -RepositoryRoot ([IO.Path]::GetFullPath($SourceRoot))
[IO.Directory]::CreateDirectory($resolvedReportPath) | Out-Null

$manifest = Import-CustomerExportManifest -Path $ManifestPath
$manifestDigest = Get-RunbookContentDigest -InputObject $manifest
$authentication = [pscustomobject]@{ executionHost = 'InteractiveWindows11PowerShell'; mode = 'NotApplicable' }
$loadedExecutionManifest = $null
if ($Apply) {
    $loadedExecutionManifest = Get-Content -Raw -LiteralPath $ExecutionManifestPath | ConvertFrom-Json
    Test-RunbookExecutionManifest -Manifest $loadedExecutionManifest -ApprovedDigest $ApprovedDigest `
        -CurrentSourceCommit ([string]$loadedExecutionManifest.sourceCommit) `
        -CurrentAssessmentDigest ([string]$loadedExecutionManifest.assessmentDigest) `
        -CurrentAuthenticationContext $loadedExecutionManifest.authentication `
        -AllowedActionNames @('CreateCustomerExport', 'CopyTrackedBlob', 'ApplyStructuredReplacement', 'ValidateCustomerExport', 'PromoteCustomerExport') `
        -NowUtc $NowUtc -MaximumAge ([timespan]::FromMinutes(30)) | Out-Null
    $toolIdentities = New-ToolIdentities -ValidationSuites @($manifest.validationSuites) `
        -Resolver $CommandResolver -IdentityProvider $FileIdentityProvider -Runner $NativeCommandRunner `
        -ApprovedIdentities $loadedExecutionManifest.toolVersions
    foreach ($tool in @($loadedExecutionManifest.toolVersions.PSObject.Properties.Name)) {
        if ($null -eq $toolIdentities.PSObject.Properties[$tool] -or
            -not (Test-ExactToolIdentity -Expected $loadedExecutionManifest.toolVersions.$tool -Actual $toolIdentities.$tool)) {
            throw 'Required executable identity changed before approved manifest validation.'
        }
    }
}
else {
    $toolIdentities = New-ToolIdentities -ValidationSuites @($manifest.validationSuites) -Resolver $CommandResolver -IdentityProvider $FileIdentityProvider -Runner $NativeCommandRunner
}
$gitExecutable = [pscustomobject]@{ path = $toolIdentities.Git.path; sha256 = $toolIdentities.Git.sha256 }
$sourceSnapshot = Get-CustomerExportSourceSnapshot -RepositoryRoot $SourceRoot -GitExecutable $gitExecutable -NativeCommandRunner $NativeCommandRunner -GitBlobReader $GitBlobReader
if ([string]$sourceSnapshot.commit -cne $ExpectedSourceCommit.ToLowerInvariant()) {
    throw 'Expected source commit does not match the current source snapshot.'
}
$markerCatalog = Get-CustomerSourceMarkerCatalog -RepositoryRoot $SourceRoot -ExpectedSourceCommit $ExpectedSourceCommit -TrackedFiles @($sourceSnapshot.trackedFiles) `
    -RetainedTenantArtifacts @($manifest.retainedTenantArtifacts) -SourceMarkerCatalog @($manifest.sourceMarkerCatalog) `
    -GitExecutable $gitExecutable -GitBlobReader $GitBlobReader
$assessment = Get-CustomerExportAssessment -SourceRoot $SourceRoot -ExpectedSourceCommit $ExpectedSourceCommit `
    -DestinationRoot $DestinationRoot -Manifest $manifest -ManifestDigest $manifestDigest `
    -SourceSnapshot $sourceSnapshot -ToolIdentities $toolIdentities -MarkerCatalogProof $markerCatalog `
    -GitExecutable $gitExecutable -GitBlobReader $GitBlobReader
$evidenceToolVersions = ConvertTo-EvidenceToolVersions -ToolIdentities $assessment.toolIdentities
$executionManifest = New-RunbookExecutionManifest -RunId $runId -Kind CustomerExport `
    -TargetStableId $assessment.destinationStableId -SourceCommit $assessment.sourceCommit `
    -AssessmentDigest $assessment.digest -AuthenticationContext $authentication `
    -AllowedActions $assessment.allowedActions -ToolVersions $assessment.toolIdentities -GeneratedAtUtc $NowUtc

if (-not $Apply) {
    Write-CanonicalJson -InputObject $assessment -Path (Join-Path $resolvedReportPath 'customer-export-assessment.json') -Replace | Out-Null
    Write-CanonicalJson -InputObject $executionManifest -Path (Join-Path $resolvedReportPath 'customer-export-execution-manifest.json') -Replace | Out-Null
    $evidence = ConvertTo-RunbookEvidenceRecord -RunId $runId -GeneratedAtUtc $NowUtc `
        -SourceCommit $assessment.sourceCommit -AssessmentDigest $assessment.digest `
        -PlanDigest $executionManifest.digest -ManifestDigest $manifestDigest -OperatorId $operatorId `
        -Operation 'PlanCustomerRepositoryExport' -Classification Create -Status Planned `
        -ShouldProcessDecision NotApplicable -TargetId $assessment.destinationStableId `
        -ToolVersions $evidenceToolVersions -FinalContext ([pscustomobject]@{ status = 'SourceSnapshotMatched' })
    Write-CanonicalJson -InputObject $evidence -Path (Join-Path $resolvedReportPath 'customer-export-evidence.json') -Replace | Out-Null
    return [pscustomobject]@{ reportPath = $resolvedReportPath; digest = $executionManifest.digest; sourceCommit = $assessment.sourceCommit }
}
Test-RunbookExecutionManifest -Manifest $loadedExecutionManifest -ApprovedDigest $ApprovedDigest `
    -CurrentSourceCommit $assessment.sourceCommit -CurrentAssessmentDigest $assessment.digest `
    -CurrentAuthenticationContext $authentication `
    -AllowedActionNames @('CreateCustomerExport', 'CopyTrackedBlob', 'ApplyStructuredReplacement', 'ValidateCustomerExport', 'PromoteCustomerExport') `
    -NowUtc $NowUtc -MaximumAge ([timespan]::FromMinutes(30)) | Out-Null

$currentToolIdentities = New-ToolIdentities -ValidationSuites @($manifest.validationSuites) -Resolver $CommandResolver `
    -IdentityProvider $FileIdentityProvider -Runner $NativeCommandRunner -ApprovedIdentities $loadedExecutionManifest.toolVersions
foreach ($tool in @($assessment.toolIdentities.PSObject.Properties.Name)) {
    if (-not (Test-ExactToolIdentity -Expected $assessment.toolIdentities.$tool -Actual $currentToolIdentities.$tool) -or
        -not (Test-ExactToolIdentity -Expected $loadedExecutionManifest.toolVersions.$tool -Actual $currentToolIdentities.$tool)) {
        throw 'Required executable identity changed before mutation.'
    }
}

if (-not $PSCmdlet.ShouldProcess($assessment.destinationRoot, "Create validated customer export for execution manifest $($loadedExecutionManifest.digest)")) {
    $decision = if ($WhatIfPreference) { 'WhatIf' } else { 'Declined' }
    $evidence = ConvertTo-RunbookEvidenceRecord -RunId ([guid]$loadedExecutionManifest.runId) `
        -GeneratedAtUtc $NowUtc -SourceCommit $assessment.sourceCommit -AssessmentDigest $assessment.digest `
        -PlanDigest $loadedExecutionManifest.digest -ManifestDigest $manifestDigest -OperatorId $operatorId `
        -Operation 'CreateCustomerRepositoryExport' `
        -Classification $(if ($decision -eq 'Declined') { 'Refused' } else { 'Create' }) `
        -Status $(if ($decision -eq 'Declined') { 'Refused' } else { 'Planned' }) `
        -ShouldProcessDecision $decision -TargetId $assessment.destinationStableId `
        -ToolVersions $evidenceToolVersions -FinalContext ([pscustomobject]@{ status = 'SourceSnapshotMatched' })
    Write-CanonicalJson -InputObject $evidence -Path (Join-Path $resolvedReportPath 'customer-export-evidence.json') -Replace | Out-Null
    return [pscustomobject]@{ reportPath = $resolvedReportPath; digest = $loadedExecutionManifest.digest; sourceCommit = $assessment.sourceCommit }
}

$disposable = Join-Path (Split-Path -Parent ([IO.Path]::GetFullPath($DestinationRoot))) ('.customer-export-' + [guid]::NewGuid().ToString('N'))
if (Test-Path -LiteralPath $disposable) { throw 'Disposable staging already exists.' }
$replacementLog = [Collections.Generic.List[object]]::new()
try {
    [IO.Directory]::CreateDirectory($disposable) | Out-Null
    foreach ($path in @($assessment.copyFiles | Sort-Object)) {
        $destinationPath = Join-Path $disposable ($path -replace '/', '\')
        $parent = Split-Path -Parent $destinationPath
        [IO.Directory]::CreateDirectory($parent) | Out-Null
        [byte[]]$bytes = @(& $GitBlobReader $toolIdentities.Git.path ([IO.Path]::GetFullPath($SourceRoot)) $ExpectedSourceCommit.ToLowerInvariant() $path)
        [IO.File]::WriteAllBytes($destinationPath, $bytes)
    }

    foreach ($group in @($manifest.replacements | Group-Object path)) {
        $entries = Invoke-CustomerStructuredReplacement -StagingRoot $disposable -Path $group.Name -Rules @($group.Group)
        foreach ($entry in @($entries)) { $replacementLog.Add($entry) }
    }

    $postSnapshot = Get-CustomerExportSourceSnapshot -RepositoryRoot $SourceRoot -GitExecutable $gitExecutable -NativeCommandRunner $NativeCommandRunner -GitBlobReader $GitBlobReader
    if ((Get-RunbookContentDigest -InputObject $postSnapshot) -cne (Get-RunbookContentDigest -InputObject $sourceSnapshot)) {
        throw 'Source snapshot changed during export.'
    }

    $validation = Test-CustomerExportContent -StagingRoot $disposable -Manifest $manifest -Assessment $assessment `
        -ExecutionManifest $loadedExecutionManifest -CurrentSourceSnapshot $postSnapshot `
        -ReplacementLog @($replacementLog) -ValidationRunner $ValidationRunner
    if (-not $validation.publishReady) {
        $evidence = ConvertTo-RunbookEvidenceRecord -RunId ([guid]$loadedExecutionManifest.runId) `
            -GeneratedAtUtc $NowUtc -SourceCommit $assessment.sourceCommit -AssessmentDigest $assessment.digest `
            -PlanDigest $loadedExecutionManifest.digest -ManifestDigest $manifestDigest -OperatorId $operatorId `
            -Operation 'CreateCustomerRepositoryExport' -Classification Create -Status Failed `
            -ShouldProcessDecision Approved -TargetId $assessment.destinationStableId `
            -ToolVersions $evidenceToolVersions -FinalContext ([pscustomobject]@{ status = 'SourceSnapshotMatched' }) `
            -ErrorCategory 'ExportValidationFailed'
        Write-CanonicalJson -InputObject $evidence -Path (Join-Path $resolvedReportPath 'customer-export-evidence.json') -Replace | Out-Null
        throw 'Customer export validation failed.'
    }

    [IO.Directory]::Move($disposable, [IO.Path]::GetFullPath($DestinationRoot))
    $finalSnapshot = Get-CustomerExportSourceSnapshot -RepositoryRoot $SourceRoot -GitExecutable $gitExecutable -NativeCommandRunner $NativeCommandRunner -GitBlobReader $GitBlobReader
    if ((Get-RunbookContentDigest -InputObject $finalSnapshot) -cne (Get-RunbookContentDigest -InputObject $sourceSnapshot)) {
        throw 'Source snapshot changed during export.'
    }
    $evidence = ConvertTo-RunbookEvidenceRecord -RunId ([guid]$loadedExecutionManifest.runId) `
        -GeneratedAtUtc $NowUtc -SourceCommit $assessment.sourceCommit -AssessmentDigest $assessment.digest `
        -PlanDigest $loadedExecutionManifest.digest -ManifestDigest $manifestDigest -OperatorId $operatorId `
        -Operation 'CreateCustomerRepositoryExport' -Classification Create -Status Verified `
        -ShouldProcessDecision Approved -TargetId $assessment.destinationStableId `
        -ToolVersions $evidenceToolVersions -FinalContext ([pscustomobject]@{ status = 'SourceSnapshotMatched' })
    Write-CanonicalJson -InputObject $evidence -Path (Join-Path $resolvedReportPath 'customer-export-evidence.json') -Replace | Out-Null
    return [pscustomobject]@{
        reportPath = $resolvedReportPath
        digest = $loadedExecutionManifest.digest
        sourceCommit = $assessment.sourceCommit
        destinationRoot = [IO.Path]::GetFullPath($DestinationRoot)
        replacementLog = @($replacementLog)
    }
}
finally {
    if (Test-Path -LiteralPath $disposable) {
        Remove-Item -LiteralPath $disposable -Recurse -Force
    }
}
