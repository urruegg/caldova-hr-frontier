[CmdletBinding()]
param(
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
    [Parameter(DontShow)][scriptblock]$OperatorIdProvider,
    [Parameter(DontShow)][scriptblock]$PlatformProbe,
    [datetime]$NowUtc = [datetime]::UtcNow
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function New-DefaultNativeCommandRunner {
    {
        param([string]$FilePath, [string[]]$ArgumentList)
        $output = @(& $FilePath @ArgumentList 2>&1 | ForEach-Object { $_.ToString() })
        [pscustomobject]@{ exitCode = $(if ($null -ne $LASTEXITCODE) { [int]$LASTEXITCODE } else { 0 }); stdout = ($output -join [Environment]::NewLine); stderr = '' }
    }.GetNewClosure()
}
function New-DefaultCommandResolver { { param($name) @(Get-Command $name -All -CommandType Application -ErrorAction SilentlyContinue | ForEach-Object Source) }.GetNewClosure() }
function New-DefaultFileIdentityProvider { { param($path) [pscustomobject]@{ path=[IO.Path]::GetFullPath($path); sha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() } }.GetNewClosure() }
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
function Get-DefaultInteractiveHostState { [pscustomobject]@{ isInteractive = [Environment]::UserInteractive -and [string]::IsNullOrWhiteSpace($env:CI); reason = 'InteractiveWindows11PowerShell' } }
function Get-DefaultPlatformState { $os = Get-CimInstance Win32_OperatingSystem; [pscustomobject]@{ productName = $(if ([string]$os.Caption -match 'Windows 11') { 'Windows 11' } else { [string]$os.Caption }); build = [int]$os.BuildNumber } }
function Get-ExecutableVersion {
    param([string]$Name,[string]$Path,[scriptblock]$Runner)
    $args = switch ($Name) {
        'git.exe' { @('--version') }
        'powershell.exe' { @('-NoProfile','-Command','$PSVersionTable.PSVersion.ToString()') }
        'az.cmd' { @('--version') }
        default { @('--version') }
    }
    $result = & $Runner $Path $args
    $stdout = if ($result.stdout -is [array]) { @($result.stdout) -join [Environment]::NewLine } else { [string]$result.stdout }
    if ([string]::IsNullOrWhiteSpace($stdout)) { return $Name }
    $stdout.Trim()
}
function New-ToolIdentities {
    param([string[]]$ValidationSuites,[scriptblock]$Resolver,[scriptblock]$IdentityProvider,[scriptblock]$Runner)
    $tools = [ordered]@{}
    foreach ($toolName in @('git.exe','powershell.exe')) {
        $resolved = Resolve-CustomerExportExecutable -Name $toolName -CommandResolver $Resolver -FileIdentityProvider $IdentityProvider
        $key = if ($toolName -eq 'git.exe') { 'Git' } else { 'WindowsPowerShell' }
        $tools[$key] = [pscustomobject]@{ path = $resolved.path; sha256 = $resolved.sha256; version = Get-ExecutableVersion -Name $toolName -Path $resolved.path -Runner $Runner }
    }
    if (@($ValidationSuites | Where-Object { $_ -ceq 'BicepBuild' }).Count -gt 0) {
        $resolved = Resolve-CustomerExportExecutable -Name 'az.cmd' -CommandResolver $Resolver -FileIdentityProvider $IdentityProvider
        $tools['AzureCli'] = [pscustomobject]@{ path = $resolved.path; sha256 = $resolved.sha256; version = Get-ExecutableVersion -Name 'az.cmd' -Path $resolved.path -Runner $Runner }
    }
    [pscustomobject]$tools
}
function Test-ExactToolIdentity {
    param([object]$Expected,[object]$Actual)
    foreach ($name in @('path','sha256','version')) {
        if ([string]$Expected.$name -cne [string]$Actual.$name) { return $false }
    }
    return $true
}
function ConvertTo-EvidenceToolVersions {
    param([object]$ToolIdentities)
    $versions = [ordered]@{}
    foreach ($property in $ToolIdentities.PSObject.Properties) { $versions[$property.Name] = [string]$property.Value.version }
    [pscustomobject]$versions
}
function Get-ByteSha256 {
    param([byte[]]$Bytes)
    $hash = [Security.Cryptography.SHA256]::Create()
    try {
        [BitConverter]::ToString($hash.ComputeHash($Bytes)).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $hash.Dispose()
    }
}

$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\..'))
$modulePath = Join-Path $repositoryRoot 'infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1'
Import-Module $modulePath -Force

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
if ([string]$platformState.productName -cne 'Windows 11' -or [int]$platformState.build -lt 22000) { throw 'This runbook requires Windows 11 build 22000 or later.' }
$operatorId = [string](& $OperatorIdProvider)
if ([string]::IsNullOrWhiteSpace($operatorId) -or $operatorId -match '[\x00-\x1F]') { throw 'Operator identity is required.' }

$manifest = Import-CustomerExportManifest -Path $ManifestPath
$manifestDigest = Get-RunbookContentDigest -InputObject $manifest
$executionManifest = Get-Content -Raw -LiteralPath $ExecutionManifestPath | ConvertFrom-Json
$toolIdentities = $executionManifest.toolVersions
$gitExecutable = [pscustomobject]@{ path = $toolIdentities.Git.path; sha256 = $toolIdentities.Git.sha256 }
$sourceSnapshot = Get-CustomerExportSourceSnapshot -RepositoryRoot $SourceRoot -GitExecutable $gitExecutable -NativeCommandRunner $NativeCommandRunner -GitBlobReader $GitBlobReader
$markerCatalog = Get-CustomerSourceMarkerCatalog -RepositoryRoot $SourceRoot -ExpectedSourceCommit $ExpectedSourceCommit -TrackedFiles @($sourceSnapshot.trackedFiles) `
    -RetainedTenantArtifacts @($manifest.retainedTenantArtifacts) -SourceMarkerCatalog @($manifest.sourceMarkerCatalog) `
    -GitExecutable $gitExecutable -GitBlobReader $GitBlobReader
$assessment = Get-CustomerExportAssessment -SourceRoot $SourceRoot -ExpectedSourceCommit $ExpectedSourceCommit `
    -DestinationRoot $DestinationRoot -Manifest $manifest -ManifestDigest $manifestDigest -SourceSnapshot $sourceSnapshot `
    -ToolIdentities $toolIdentities -MarkerCatalogProof $markerCatalog -GitExecutable $gitExecutable -GitBlobReader $GitBlobReader `
    -AllowExistingDestination
$authentication = [pscustomobject]@{ executionHost = 'InteractiveWindows11PowerShell'; mode = 'NotApplicable' }
Test-RunbookExecutionManifest -Manifest $executionManifest -ApprovedDigest $ApprovedDigest `
    -CurrentSourceCommit $assessment.sourceCommit -CurrentAssessmentDigest $assessment.digest `
    -CurrentAuthenticationContext $authentication -AllowedActionNames @('CreateCustomerExport','CopyTrackedBlob','ApplyStructuredReplacement','ValidateCustomerExport','PromoteCustomerExport') `
    -NowUtc $NowUtc -MaximumAge ([timespan]::FromMinutes(30)) | Out-Null

$currentToolIdentities = New-ToolIdentities -ValidationSuites @($manifest.validationSuites) -Resolver $CommandResolver -IdentityProvider $FileIdentityProvider -Runner $NativeCommandRunner
foreach ($tool in @($toolIdentities.PSObject.Properties.Name)) {
    if (-not (Test-ExactToolIdentity -Expected $toolIdentities.$tool -Actual $currentToolIdentities.$tool) -or
        -not (Test-ExactToolIdentity -Expected $assessment.toolIdentities.$tool -Actual $currentToolIdentities.$tool)) {
        throw 'Required executable identity changed before validation.'
    }
}

$root = [IO.Path]::GetFullPath($DestinationRoot)
$replacementLog = [Collections.Generic.List[object]]::new()
foreach ($path in @($assessment.copyFiles | Sort-Object)) {
    [byte[]]$originalBytes = @(& $GitBlobReader $toolIdentities.Git.path ([IO.Path]::GetFullPath($SourceRoot)) $ExpectedSourceCommit.ToLowerInvariant() $path)
    $tracked = @($sourceSnapshot.trackedFiles | Where-Object { $_.path -ceq $path }) | Select-Object -First 1
    if ($null -eq $tracked -or (Get-ByteSha256 -Bytes $originalBytes) -cne [string]$tracked.blobSha256) {
        throw 'Customer export source tracked blob could not be proven.'
    }
    $rules = @($manifest.replacements | Where-Object { ([string]$_.path) -ceq $path })
    $converted = Convert-CustomerExportBlob -Path $path -OriginalBytes $originalBytes -Rules $rules
    $stagedPath = Join-Path $root ($path -replace '/', '\')
    if (-not (Test-Path -LiteralPath $stagedPath -PathType Leaf)) {
        $replacementLog.Clear()
        $result = [pscustomobject]@{ category = 'ExpectedOutputMismatch'; path = $path }
        $replacementLog.Add($result)
        break
    }
    $stagedBytes = [IO.File]::ReadAllBytes($stagedPath)
    if ((Get-ByteSha256 -Bytes $stagedBytes) -cne (Get-ByteSha256 -Bytes $converted.bytes)) {
        $replacementLog.Clear()
        $replacementLog.Add([pscustomobject]@{ category = 'ExpectedOutputMismatch'; path = $path })
        break
    }
    foreach ($entry in @($converted.replacementLog)) { $replacementLog.Add($entry) }
}

$result = Test-CustomerExportContent -StagingRoot $DestinationRoot -Manifest $manifest -Assessment $assessment `
    -ExecutionManifest $executionManifest -CurrentSourceSnapshot $sourceSnapshot -ReplacementLog @($replacementLog) `
    -ValidationRunner $ValidationRunner
$mismatches = @(
    $replacementLog | Where-Object {
        $_.PSObject.Properties.Name -contains 'category' -and [string]$_.category -ceq 'ExpectedOutputMismatch'
    }
)
if ($mismatches.Count -gt 0) {
    $result.failures = @($result.failures) + $mismatches
    $result.publishReady = $false
    $result.status = 'Failed'
}

$reportRoot = Resolve-RunbookReportPath -RunId ([guid]$executionManifest.runId) -Path $ReportPath -RepositoryRoot ([IO.Path]::GetFullPath($SourceRoot))
[IO.Directory]::CreateDirectory($reportRoot) | Out-Null
Write-CanonicalJson -InputObject $result -Path (Join-Path $reportRoot 'customer-export-validation.json') -Replace | Out-Null
$evidence = ConvertTo-RunbookEvidenceRecord -RunId ([guid]$executionManifest.runId) `
    -GeneratedAtUtc $NowUtc -SourceCommit $assessment.sourceCommit -AssessmentDigest $assessment.digest `
    -PlanDigest $executionManifest.digest -ManifestDigest $manifestDigest -OperatorId $operatorId `
    -Operation 'ValidateCustomerRepositoryExport' -Classification NoChange `
    -Status $(if ($result.publishReady) { 'Verified' } else { 'Failed' }) -ShouldProcessDecision NotApplicable `
    -TargetId $assessment.destinationStableId -ToolVersions (ConvertTo-EvidenceToolVersions -ToolIdentities $assessment.toolIdentities) `
    -FinalContext ([pscustomobject]@{ status = 'SourceSnapshotMatched' }) `
    -ErrorCategory $(if ($result.publishReady) { $null } else { 'ExportValidationFailed' })
Write-CanonicalJson -InputObject $evidence -Path (Join-Path $reportRoot 'customer-export-validation-evidence.json') -Replace | Out-Null

if (-not $result.publishReady) {
    throw 'Customer export validation did not produce a publish-ready result.'
}

$result
