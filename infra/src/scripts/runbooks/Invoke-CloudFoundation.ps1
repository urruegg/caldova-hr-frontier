[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-z0-9]+$')]
    [string]$TenantAlias,

    [string]$TenantConfigurationPath,

    [Parameter(Mandatory)]
    [string]$ExecutionManifestPath,

    [Parameter(Mandatory)]
    [string]$AssessmentPath,

    [string]$ReportPath,

    [Parameter(Mandatory)]
    [ValidatePattern('^[0-9a-f]{64}$')]
    [string]$ApprovedDigest,

    [ValidateSet('DEV','TEST','PROD')]
    [string[]]$Stages = @('DEV','TEST','PROD'),

    [switch]$Apply,
    [scriptblock]$NativeToolResolver,
    [scriptblock]$NativeCommandRunner,
    [scriptblock]$InteractiveHostProbe,
    [scriptblock]$WhatIfValidator,
    [datetime]$NowUtc = [datetime]::UtcNow
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $Apply) {
    throw 'Cloud foundation invocation requires explicit -Apply.'
}

$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\..'))
$modulePath = Join-Path $repositoryRoot 'infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1'
Import-Module $modulePath -Force

function Assert-ApprovedCloudToolResolutions {
    param(
        [Parameter(Mandatory)] [object]$Approved,
        [Parameter(Mandatory)] [scriptblock]$NativeToolResolver
    )
    $fresh = [ordered]@{}
    foreach ($name in @('az','gh','pac','git')) {
        $expected = $Approved.$name
        if ($null -eq $expected) { throw "Approved cloud tool is missing: $name" }
        $current = Resolve-CloudNativeTool -Name $name -ApplicationResolver $NativeToolResolver
        if (-not [IO.Path]::IsPathRooted([string]$current.path) -or
            -not ([IO.Path]::GetFullPath([string]$current.path)).Equals(
                [IO.Path]::GetFullPath([string]$expected.path),
                [StringComparison]::OrdinalIgnoreCase
            ) -or [string]$current.version -cne [string]$expected.version -or
            [string]$current.sha256 -cne [string]$expected.sha256) {
            throw "Approved cloud executable identity changed: $name"
        }
        $fresh[$name] = $current
    }
    [pscustomobject]$fresh
}

function New-CloudRecoveryItem {
    param($Service,$TargetId,$State,$Diagnostic,$Owner,$Next)
    [pscustomobject][ordered]@{
        service=$Service;targetId=$TargetId;lastProvenState=$State
        safeDiagnostic=$Diagnostic;owner=$Owner;nextAction=$Next
        requiresNewPlan=$true;requiresNewApproval=$true
    }
}

if ($null -eq $NativeToolResolver) {
    $NativeToolResolver = { param($Name) @(Get-Command -Name $Name -CommandType Application -All -ErrorAction Stop) }
}
if ($null -eq $NativeCommandRunner) {
    $NativeCommandRunner = {
        param([string]$FilePath,[string[]]$ArgumentList)
        $startInfo = [Diagnostics.ProcessStartInfo]::new()
        $startInfo.FileName=$FilePath
        $startInfo.UseShellExecute=$false
        $startInfo.RedirectStandardOutput=$true
        $startInfo.RedirectStandardError=$true
        $startInfo.Arguments=(($ArgumentList | ForEach-Object {
            if ($_ -notmatch '[\s"]') { return $_ }
            '"' + ($_ -replace '(\\*)"', '$1$1\"' -replace '(\\+)$', '$1$1') + '"'
        }) -join ' ')
        $process=[Diagnostics.Process]::new();$process.StartInfo=$startInfo
        try {
            [void]$process.Start();$stdout=$process.StandardOutput.ReadToEnd()
            $stderr=$process.StandardError.ReadToEnd();$process.WaitForExit()
            [pscustomobject]@{exitCode=$process.ExitCode;stdout=$stdout;stderr=$stderr}
        } finally {$process.Dispose()}
    }
}
if ($null -eq $InteractiveHostProbe) {
    $InteractiveHostProbe = {
        [pscustomobject]@{
            isInteractive=[Environment]::UserInteractive -and -not [Console]::IsInputRedirected
            platform=(Get-CimInstance Win32_OperatingSystem).Caption
        }
    }
}

$manifestPath = [IO.Path]::GetFullPath($ExecutionManifestPath)
$assessmentFile = [IO.Path]::GetFullPath($AssessmentPath)
$runDirectory = Split-Path -Parent $manifestPath
if ([string]::IsNullOrWhiteSpace($ReportPath)) { $ReportPath=$runDirectory }
$resolvedRunDirectory = Resolve-RunbookReportPath -RunId ([guid]::NewGuid()) `
    -Path $ReportPath -RepositoryRoot $repositoryRoot
if (-not $resolvedRunDirectory.Equals($runDirectory,[StringComparison]::OrdinalIgnoreCase) -or
    -not (Split-Path -Parent $assessmentFile).Equals($runDirectory,[StringComparison]::OrdinalIgnoreCase)) {
    throw 'Manifest, assessment, and report path must share one validated RunDirectory.'
}
$tenantPath = if ([string]::IsNullOrWhiteSpace($TenantConfigurationPath)) {
    Join-Path $repositoryRoot "infra\src\config\tenants\$TenantAlias.psd1"
} else {[IO.Path]::GetFullPath($TenantConfigurationPath)}
$tenant = Import-TenantConfiguration -Path $tenantPath -ValidationStage Bootstrap
$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
$assessment = Get-Content -Raw -LiteralPath $assessmentFile | ConvertFrom-Json
if ([string]$manifest.digest -cne $ApprovedDigest) { throw 'Approved digest does not match the execution manifest.' }

$approvedTools = Assert-ApprovedCloudToolResolutions -Approved $manifest.toolVersions `
    -NativeToolResolver $NativeToolResolver
$initialContext = Test-CloudDelegatedContext -TenantConfiguration $tenant -Stages $Stages `
    -ToolResolutions $approvedTools -NativeCommandRunner $NativeCommandRunner `
    -InteractiveHostProbe $InteractiveHostProbe
$gitResult = & $NativeCommandRunner ([string]$approvedTools.git.path) @('rev-parse','HEAD')
if ($null -eq $gitResult -or [int]$gitResult.exitCode -ne 0) {
    throw 'The current source commit could not be read.'
}
$currentCommit = ([string]$gitResult.stdout).Trim().ToLowerInvariant()
$manifestAuthentication = [ordered]@{
    executionHost='InteractiveWindows11PowerShell';mode='AzureCliDelegatedContext'
    accountId=[string]$initialContext.principal.id;tenantId=[string]$initialContext.azure.tenantId
    subscriptionId=[string]$initialContext.azure.subscriptionId;githubHost='github.com'
    githubLogin=[string]$initialContext.github.login
    azureDevOpsOrganizationUrl=[string]$initialContext.azureDevOps.organizationUrl
    azureDevOpsActingUserId=[string]$initialContext.azureDevOps.actingUserId
}
if ([string]$initialContext.azureDevOps.projectIntent -ceq 'Existing') {
    $manifestAuthentication.azureDevOpsProjectId=[string]$initialContext.azureDevOps.projectId
}
$allowedNames=@(
    'VerifyExistingResource','CompleteAttendedManualAction','ResolveBlockedIntent',
    'RefuseMismatchedTarget','UpdateGitHubRepositoryMetadata','UpsertGitHubNonActionsRuleset',
    'DeployAzureFoundation','CreateAzureDevOpsProject','CreateEntraTargetApplication',
    'UpdateEntraTargetApplication','CreateEntraTargetServicePrincipal'
)
Test-RunbookExecutionManifest -Manifest $manifest -ApprovedDigest $ApprovedDigest `
    -CurrentSourceCommit $currentCommit -CurrentAssessmentDigest $assessment.assessmentDigest `
    -CurrentAuthenticationContext ([pscustomobject]$manifestAuthentication) `
    -AllowedActionNames $allowedNames -NowUtc $NowUtc | Out-Null
$plan = New-CloudFoundationActionPlan -TenantConfiguration $tenant -Assessment $assessment
$planDigest = Get-RunbookContentDigest $plan
if ((Get-RunbookContentDigest $plan.manifestActions) -cne
    (Get-RunbookContentDigest $manifest.allowedActions)) {
    throw 'Recomputed action plan does not match the approved manifest.'
}

$providerOrder=@{GitHub=1;Entra=2;Azure=3;AzureDevOps=4}
$mutations=@($plan.actions | Where-Object classification -in @('Create','Update') |
    Sort-Object @{Expression={$providerOrder[[string]$_.service]}},service,targetId)
if (@($mutations | Where-Object action -ceq 'CreateAzureDevOpsProject').Count -gt 0 -and
    [string]$initialContext.azureDevOps.createProjectPermission -cne 'Allowed') {
    throw 'Azure DevOps Create new projects permission changed before Apply; no provider mutation was attempted.'
}
$safeReadBack=[Collections.Generic.List[object]]::new()
$recovery=[Collections.Generic.List[object]]::new()
$changedCount=0
$shouldProcessDecision=if($WhatIfPreference){'WhatIf'}else{'Declined'}
$failureCategory=$null
foreach($action in $mutations) {
    if (-not $PSCmdlet.ShouldProcess(
        "$($action.service):$($action.targetId)",
        "$($action.method) $($action.uri) [$($action.bodyDigest)]"
    )) { continue }
    $shouldProcessDecision='Approved'
    try {
        $freshTools=Assert-ApprovedCloudToolResolutions -Approved $manifest.toolVersions `
            -NativeToolResolver $NativeToolResolver
        $currentContext=Test-CloudDelegatedContext -TenantConfiguration $tenant -Stages $Stages `
            -ToolResolutions $freshTools -NativeCommandRunner $NativeCommandRunner `
            -InteractiveHostProbe $InteractiveHostProbe
        $result=Invoke-CloudFoundationAction -Action $action -TenantConfiguration $tenant `
            -VerifiedContext $currentContext -ToolResolutions $freshTools `
            -RunDirectory $runDirectory -RepositoryRoot $repositoryRoot `
            -NativeCommandRunner $NativeCommandRunner -WhatIfValidator $WhatIfValidator -NowUtc $NowUtc
        $safeReadBack.Add($result.readBack)
        if($result.status -eq 'Changed'){$changedCount++}
    }
    catch {
        $failureCategory=if($changedCount -gt 0){'PartialMutation'}else{'MutationFailed'}
        $recovery.Add((New-CloudRecoveryItem -Service $action.service -TargetId $action.targetId `
            -State $(if($changedCount -gt 0){'Earlier provider changes verified'}else{'No mutation verified'}) `
            -Diagnostic 'Read the exact provider target by stable ID.' -Owner 'Cloud foundation administrator' `
            -Next 'Read back the exact target, rerun assessment, regenerate all digests, and obtain new approval.'))
        break
    }
}
if($null -eq $failureCategory -and $shouldProcessDecision -eq 'Approved') {
    try {
        $finalTools=Assert-ApprovedCloudToolResolutions -Approved $manifest.toolVersions `
            -NativeToolResolver $NativeToolResolver
        $finalContext=Test-CloudDelegatedContext -TenantConfiguration $tenant -Stages $Stages `
            -ToolResolutions $finalTools -NativeCommandRunner $NativeCommandRunner `
            -InteractiveHostProbe $InteractiveHostProbe
        if([string]$finalContext.principal.id -cne [string]$initialContext.principal.id -or
            [string]$finalContext.azure.tenantId -cne [string]$initialContext.azure.tenantId -or
            [string]$finalContext.azure.subscriptionId -cne [string]$initialContext.azure.subscriptionId -or
            [string]$finalContext.github.login -cne [string]$initialContext.github.login -or
            [string]$finalContext.azureDevOps.actingUserId -cne [string]$initialContext.azureDevOps.actingUserId) {
            throw 'Final delegated context differs from the initial verified identity.'
        }
    }
    catch {
        $failureCategory=if($changedCount -gt 0){'PartialMutation'}else{'FinalVerificationFailed'}
        $recovery.Add((New-CloudRecoveryItem -Service 'CloudFoundation' `
            -TargetId ([string]$manifest.target.stableId) -State 'Final context not verified' `
            -Diagnostic 'Re-read every exact provider target and delegated identity.' `
            -Owner 'Cloud foundation administrator' `
            -Next 'Reassess the tenant, regenerate all digests, and obtain new approval.'))
    }
}

$incomplete=@($plan.actions | Where-Object classification -in @('Manual','Blocked','Refused'))
if($null -eq $failureCategory -and $incomplete.Count -gt 0) {
    if(@($incomplete|Where-Object classification -eq 'Refused').Count){$failureCategory='RefusedOperation'}
    elseif(@($incomplete|Where-Object classification -eq 'Blocked').Count){$failureCategory='BlockedOperation'}
    else{$failureCategory='IncompleteManualActions'}
    foreach($item in $incomplete) {
        $recovery.Add((New-CloudRecoveryItem -Service $item.service -TargetId $item.targetId `
            -State $item.classification -Diagnostic $item.expectedPostcondition `
            -Owner 'Cloud foundation administrator' `
            -Next 'Complete the reviewed prerequisite, reassess, generate a new plan, and obtain new approval.'))
    }
}
$status=if($null -eq $failureCategory -and $shouldProcessDecision -eq 'Approved'){'Verified'}else{'Failed'}
$classification=if($status -eq 'Verified'){'NoChange'}elseif($failureCategory -eq 'RefusedOperation'){'Refused'}elseif($failureCategory -eq 'BlockedOperation'){'Blocked'}else{'Manual'}
$evidence=ConvertTo-RunbookEvidenceRecord -RunId ([guid]$manifest.runId) -GeneratedAtUtc $NowUtc `
    -SourceCommit $currentCommit -AssessmentDigest $assessment.assessmentDigest `
    -PlanDigest $planDigest -ManifestDigest $manifest.digest `
    -OperatorId ([string]$initialContext.principal.id) -Operation CloudFoundation `
    -Classification $classification -Status $status -ShouldProcessDecision $shouldProcessDecision `
    -TargetId ([string]$manifest.target.stableId) -ReadBack @($safeReadBack) `
    -ManualItems @($assessment.manualItems) -RecoveryItems @($recovery) -ErrorCategory $failureCategory
Write-CanonicalJson -InputObject $evidence -Path (Join-Path $runDirectory 'cloud-invocation-evidence.json') -Replace | Out-Null
if($status -ne 'Verified') {
    if($failureCategory -eq 'PartialMutation'){throw 'Apply produced a partial cloud foundation; use recorded recovery.'}
    throw "Cloud foundation remains incomplete: $failureCategory"
}
$evidence
