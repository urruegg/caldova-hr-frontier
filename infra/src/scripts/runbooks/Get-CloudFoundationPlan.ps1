[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-z0-9]+$')]
    [string]$TenantAlias,

    [string]$TenantConfigurationPath,
    [string]$ReportPath,

    [ValidateSet('DEV','TEST','PROD')]
    [string[]]$Stages = @('DEV','TEST','PROD'),

    [scriptblock]$NativeToolResolver,
    [scriptblock]$NativeCommandRunner,
    [scriptblock]$InteractiveHostProbe,
    [datetime]$NowUtc = [datetime]::UtcNow
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\..'))
$modulePath = Join-Path $repositoryRoot 'infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1'
Import-Module $modulePath -Force

if ($null -eq $NativeToolResolver) {
    $NativeToolResolver = { param($Name) @(Get-Command -Name $Name -CommandType Application -All -ErrorAction Stop) }
}
if ($null -eq $NativeCommandRunner) {
    $NativeCommandRunner = {
        param([string]$FilePath,[string[]]$ArgumentList)
        $startInfo = [Diagnostics.ProcessStartInfo]::new()
        $startInfo.FileName = $FilePath
        $startInfo.UseShellExecute = $false
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        $startInfo.Arguments = (($ArgumentList | ForEach-Object {
            if ($_ -notmatch '[\s"]') { return $_ }
            '"' + ($_ -replace '(\\*)"', '$1$1\"' -replace '(\\+)$', '$1$1') + '"'
        }) -join ' ')
        $process = [Diagnostics.Process]::new()
        $process.StartInfo = $startInfo
        try {
            [void]$process.Start()
            $stdout = $process.StandardOutput.ReadToEnd()
            $stderr = $process.StandardError.ReadToEnd()
            $process.WaitForExit()
            [pscustomobject]@{
                exitCode=$process.ExitCode
                stdout=$stdout
                stderr=$stderr
            }
        } finally { $process.Dispose() }
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

$resolvedTenantPath = if ([string]::IsNullOrWhiteSpace($TenantConfigurationPath)) {
    Join-Path $repositoryRoot "infra\src\config\tenants\$TenantAlias.psd1"
} else { [IO.Path]::GetFullPath($TenantConfigurationPath) }
$tenant = Import-TenantConfiguration -Path $resolvedTenantPath -ValidationStage Bootstrap
if ([string]$tenant.TenantAlias -cne $TenantAlias) {
    throw 'Tenant configuration alias does not match the requested alias.'
}

$runId = [guid]::NewGuid()
$resolvedReportPath = Resolve-RunbookReportPath -RunId $runId -Path $ReportPath -RepositoryRoot $repositoryRoot
[IO.Directory]::CreateDirectory($resolvedReportPath) | Out-Null
$toolResolutions = [ordered]@{}
foreach ($name in @('az','gh','pac','git')) {
    $toolResolutions[$name] = Resolve-CloudNativeTool -Name $name -ApplicationResolver $NativeToolResolver
}
$context = Test-CloudDelegatedContext -TenantConfiguration $tenant -Stages $Stages `
    -ToolResolutions ([pscustomobject]$toolResolutions) -NativeCommandRunner $NativeCommandRunner `
    -InteractiveHostProbe $InteractiveHostProbe
$assessment = Get-CloudFoundationAssessment -TenantConfiguration $tenant `
    -VerifiedContext $context -ToolResolutions ([pscustomobject]$toolResolutions) `
    -RunDirectory $resolvedReportPath -NativeCommandRunner $NativeCommandRunner -NowUtc $NowUtc
$actionPlan = New-CloudFoundationActionPlan -TenantConfiguration $tenant -Assessment $assessment
$planDigest = Get-RunbookContentDigest -InputObject $actionPlan

$manifestAuthentication = [ordered]@{
    executionHost='InteractiveWindows11PowerShell'
    mode='AzureCliDelegatedContext'
    accountId=[string]$context.principal.id
    tenantId=[string]$context.azure.tenantId
    subscriptionId=[string]$context.azure.subscriptionId
    githubHost='github.com'
    githubLogin=[string]$context.github.login
    azureDevOpsOrganizationUrl=[string]$context.azureDevOps.organizationUrl
    azureDevOpsActingUserId=[string]$context.azureDevOps.actingUserId
}
if ([string]$context.azureDevOps.projectIntent -ceq 'Existing') {
    $manifestAuthentication.azureDevOpsProjectId = [string]$context.azureDevOps.projectId
}
$manifest = New-RunbookExecutionManifest -RunId $runId -Kind CloudFoundation `
    -TargetStableId ([string]$tenant.TenantId) -SourceCommit $assessment.sourceCommit `
    -AssessmentDigest $assessment.assessmentDigest -AuthenticationContext ([pscustomobject]$manifestAuthentication) `
    -AllowedActions $actionPlan.manifestActions -ToolVersions ([pscustomobject]$toolResolutions) `
    -GeneratedAtUtc $NowUtc
$readBack = @(
    $actionPlan.actions | Where-Object classification -eq 'NoChange' | ForEach-Object {
        [pscustomobject][ordered]@{
            service=[string]$_.service;targetId=[string]$_.targetId;status='NoChange'
            expectedPostcondition=[string]$_.expectedPostcondition
        }
    }
)
$evidence = ConvertTo-RunbookEvidenceRecord -RunId $runId -GeneratedAtUtc $NowUtc `
    -SourceCommit $assessment.sourceCommit -AssessmentDigest $assessment.assessmentDigest `
    -PlanDigest $planDigest -ManifestDigest $manifest.digest -OperatorId ([string]$context.principal.id) `
    -Operation CloudFoundation -Classification NoChange -Status Planned `
    -ShouldProcessDecision NotApplicable -TargetId ([string]$tenant.TenantId) `
    -ReadBack $readBack -ManualItems @($assessment.manualItems) -RecoveryItems @()

Write-CanonicalJson -InputObject $assessment -Path (Join-Path $resolvedReportPath 'cloud-assessment.json') | Out-Null
Write-CanonicalJson -InputObject $actionPlan -Path (Join-Path $resolvedReportPath 'cloud-plan.json') | Out-Null
Write-CanonicalJson -InputObject $manifest -Path (Join-Path $resolvedReportPath 'cloud-execution-manifest.json') | Out-Null
Write-CanonicalJson -InputObject $evidence -Path (Join-Path $resolvedReportPath 'cloud-plan-evidence.json') | Out-Null

[pscustomobject][ordered]@{
    target=$manifest.target
    digest=$manifest.digest
    sourceCommit=$assessment.sourceCommit
    assessmentDigest=$assessment.assessmentDigest
    planDigest=$planDigest
    reportPath=$resolvedReportPath
}
