[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-z0-9]+$')]
    [string]$TenantAlias,

    [string]$TenantConfigurationPath,

    [Parameter(Mandatory)]
    [string]$EvidencePath,

    [Parameter(Mandatory)]
    [string]$ParameterFile,

    [Parameter(Mandatory)]
    [string]$TemporaryRoleStatePath,

    [Parameter(Mandatory)]
    [bool]$ConfirmRoleCleanup,

    [Parameter(Mandatory)]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string]$BootstrapRunId,

    [Parameter(Mandatory)]
    [ValidateCount(2, 2)]
    [string[]]$ApprovedRoleAssignmentIds,

    [switch]$WhatIfOnly,

    [Parameter(DontShow)]
    [scriptblock]$DiscoveryEvidenceValidator,

    [Parameter(DontShow)]
    [scriptblock]$IntentValidator,

    [Parameter(DontShow)]
    [scriptblock]$OidcContextValidator,

    [Parameter(DontShow)]
    [scriptblock]$BicepValidator,

    [Parameter(DontShow)]
    [scriptblock]$RoleStateLoader,

    [Parameter(DontShow)]
    [scriptblock]$NativeCommandRunner,

    [Parameter(DontShow)]
    [scriptblock]$WhatIfBoundaryValidator,

    [Parameter(DontShow)]
    [scriptblock]$CleanupRunner
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-ModuleManifestPath {
    Join-Path $PSScriptRoot 'modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1'
}

function Get-DefaultTenantConfigurationPath {
    param([string]$TenantAliasValue)

    Join-Path $PSScriptRoot "..\config\tenants\$TenantAliasValue.psd1"
}

function Get-BicepEntryPath {
    Join-Path $PSScriptRoot '..\bicep\main.bicep'
}

function Get-TenantParameterValue {
    param(
        [Parameter(Mandatory)]
        [object]$CompiledParameters,

        [Parameter(Mandatory)]
        [string]$Name
    )

    $parameterDocument = if ($CompiledParameters.PSObject.Properties.Name -contains 'parametersJson') {
        [string]$CompiledParameters.parametersJson | ConvertFrom-Json
    }
    else {
        $CompiledParameters
    }

    $tenantParameter = $parameterDocument.parameters.PSObject.Properties['tenant']
    if (-not $tenantParameter -or $null -eq $tenantParameter.Value -or $null -eq $tenantParameter.Value.value) {
        return ''
    }

    $tenantValue = $tenantParameter.Value.value
    $property = $tenantValue.PSObject.Properties[$Name]
    if (-not $property) {
        return ''
    }

    [string]$property.Value
}

function Invoke-NativeCommand {
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,

        [Parameter(Mandatory)]
        [string[]]$ArgumentList
    )

    if ($NativeCommandRunner) {
        $result = & $NativeCommandRunner -FilePath $FilePath -ArgumentList $ArgumentList
        return [pscustomobject]@{
            ExitCode = [int]$result.ExitCode
            StdOut = [string]$result.StdOut
            StdErr = [string]$result.StdErr
        }
    }

    $stdoutPath = [System.IO.Path]::GetTempFileName()
    $stderrPath = [System.IO.Path]::GetTempFileName()
    try {
        $process = Start-Process -FilePath $FilePath -ArgumentList $ArgumentList -WorkingDirectory (Split-Path -Parent $PSScriptRoot) -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -PassThru -Wait
        [pscustomobject]@{
            ExitCode = $process.ExitCode
            StdOut = [System.IO.File]::ReadAllText($stdoutPath)
            StdErr = [System.IO.File]::ReadAllText($stderrPath)
        }
    }
    finally {
        Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-NativeJsonCommand {
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,

        [Parameter(Mandatory)]
        [string[]]$ArgumentList
    )

    $result = Invoke-NativeCommand -FilePath $FilePath -ArgumentList $ArgumentList
    if ($result.ExitCode -ne 0) {
        throw ("{0} failed with exit code {1}. {2}" -f $FilePath, $result.ExitCode, $result.StdErr)
    }
    if ([string]::IsNullOrWhiteSpace($result.StdOut)) {
        throw ("{0} returned empty output for arguments: {1}" -f $FilePath, ($ArgumentList -join ' '))
    }

    $result.StdOut | ConvertFrom-Json
}

function Get-WhatIfValidatorPath {
    Join-Path $PSScriptRoot 'Test-WhatIfBoundary.ps1'
}

function Get-DefaultDiscoveryEvidence {
    param([string]$Path)

    $evidence = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
    Test-DiscoveryEvidence -Evidence $evidence | Out-Null
    $evidence
}

function Test-DefaultOidcContext {
    param([object]$TenantConfiguration)

    $account = Invoke-NativeJsonCommand -FilePath 'az' -ArgumentList @('account', 'show', '--output', 'json')
    if ([string]$account.user.type -cne 'servicePrincipal') {
        throw 'Bootstrap requires a service-principal OIDC context.'
    }
    if ([string]$account.tenantId -cne [string]$TenantConfiguration.TenantId) {
        throw 'OIDC tenant does not match the reviewed tenant manifest.'
    }
    if ([string]$account.id -cne [string]$TenantConfiguration.SubscriptionId) {
        throw 'OIDC subscription does not match the reviewed tenant manifest.'
    }
    if ([string]::IsNullOrWhiteSpace([string]$env:AZURE_TENANT_ID) -or [string]$env:AZURE_TENANT_ID -cne [string]$account.tenantId) {
        throw 'AZURE_TENANT_ID must match the observed az account tenant.'
    }
    if ([string]::IsNullOrWhiteSpace([string]$env:AZURE_SUBSCRIPTION_ID) -or [string]$env:AZURE_SUBSCRIPTION_ID -cne [string]$account.id) {
        throw 'AZURE_SUBSCRIPTION_ID must match the observed az account subscription.'
    }

    $observedClientId = [string]$account.user.name
    if ([string]::IsNullOrWhiteSpace([string]$env:AZURE_CLIENT_ID) -or [string]::IsNullOrWhiteSpace($observedClientId) -or [string]$env:AZURE_CLIENT_ID -cne $observedClientId) {
        throw 'AZURE_CLIENT_ID must match the observed service-principal client id.'
    }
}

function Get-ValidatedRoleState {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [object]$TenantConfiguration
    )

    $roleState = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
    if ([string]$roleState.SchemaVersion -cne '1.0') {
        throw 'TemporaryRoleState.SchemaVersion must equal 1.0.'
    }
    if ([string]$roleState.TenantAlias -cne [string]$TenantConfiguration.TenantAlias) {
        throw 'TemporaryRoleState.TenantAlias must match the reviewed tenant manifest.'
    }
    if ([string]$roleState.TenantId -cne [string]$TenantConfiguration.TenantId) {
        throw 'TemporaryRoleState.TenantId must match the reviewed tenant manifest.'
    }
    if ([string]$roleState.SubscriptionId -cne [string]$TenantConfiguration.SubscriptionId) {
        throw 'TemporaryRoleState.SubscriptionId must match the reviewed tenant manifest.'
    }
    $parsedRunId = [guid]::Empty
    if (-not [guid]::TryParse([string]$roleState.RunId, [ref]$parsedRunId)) {
        throw 'TemporaryRoleState.RunId must be a GUID.'
    }
    [datetime]::Parse([string]$roleState.CreatedUtc).ToUniversalTime() | Out-Null

    $expectedPrincipalObjectId = [string]$TenantConfiguration.Components.EntraServicePrincipal.Id
    if ([string]$roleState.PrincipalObjectId -cne $expectedPrincipalObjectId) {
        throw 'TemporaryRoleState.PrincipalObjectId must match the reviewed tenant manifest.'
    }

    $expectedScope = "/subscriptions/$([string]$TenantConfiguration.SubscriptionId)"
    if ([string]$roleState.Scope -cne $expectedScope) {
        throw 'TemporaryRoleState.Scope must match the reviewed subscription scope.'
    }

    $assignments = @($roleState.Assignments)
    if ($assignments.Count -ne 2) {
        throw 'TemporaryRoleState.Assignments must contain exactly two assignments.'
    }

    $seenIds = @{}
    $seenRoles = @{}
    $expectedRoleDefinitionIds = @{
        Contributor = "$expectedScope/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c"
        'Role Based Access Control Administrator' = "$expectedScope/providers/Microsoft.Authorization/roleDefinitions/f58310d9-a9f6-439a-9e8d-f62e7b41a168"
    }
    foreach ($assignment in $assignments) {
        $assignmentId = [string]$assignment.Id
        $roleName = [string]$assignment.RoleName
        if ([string]::IsNullOrWhiteSpace($assignmentId) -or $assignmentId -cnotmatch ('^' + [regex]::Escape("$expectedScope/providers/Microsoft.Authorization/roleAssignments/") + '[0-9a-fA-F-]{36}$')) {
            throw 'TemporaryRoleState assignments require well-formed exact Id values at the reviewed subscription scope.'
        }
        if ($seenIds.ContainsKey($assignmentId)) {
            throw 'TemporaryRoleState assignment ids must be unique.'
        }
        $seenIds[$assignmentId] = $true

        if ($roleName -notin @('Contributor', 'Role Based Access Control Administrator')) {
            throw "TemporaryRoleState role $roleName is not allowed."
        }
        if ($seenRoles.ContainsKey($roleName)) {
            throw "TemporaryRoleState role $roleName must be unique."
        }
        $seenRoles[$roleName] = $true

        if ([string]$assignment.PrincipalObjectId -cne $expectedPrincipalObjectId) {
            throw 'TemporaryRoleState assignment principal must match the reviewed tenant manifest.'
        }
        if ([string]$assignment.Scope -cne $expectedScope) {
            throw 'TemporaryRoleState assignment scope must match the reviewed subscription scope.'
        }
        if ([string]$assignment.RoleDefinitionId -cne [string]$expectedRoleDefinitionIds[$roleName]) {
            throw "TemporaryRoleState assignment RoleDefinitionId is not the expected built-in definition for $roleName."
        }
        [datetime]::Parse([string]$assignment.CreatedUtc) | Out-Null
    }

    $roleState
}

function Assert-ReviewedCleanupApproval {
    param(
        [Parameter(Mandatory)]
        [object]$RoleState,

        [Parameter(Mandatory)]
        [string]$ExpectedRunId,

        [Parameter(Mandatory)]
        [string[]]$ApprovedAssignmentIds,

        [Parameter(Mandatory)]
        [string]$ExpectedScope
    )

    if ([string]$RoleState.RunId -cne $ExpectedRunId) {
        throw 'BootstrapRunId must match TemporaryRoleState.RunId.'
    }

    $assignmentIdPattern = '^' + [regex]::Escape("$ExpectedScope/providers/Microsoft.Authorization/roleAssignments/") + '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
    $seenApprovedIds = @{}
    foreach ($approvedId in @($ApprovedAssignmentIds)) {
        if ([string]$approvedId -cnotmatch $assignmentIdPattern) {
            throw 'ApprovedRoleAssignmentIds must contain well-formed exact assignment ids at the reviewed subscription scope.'
        }
        if ($seenApprovedIds.ContainsKey([string]$approvedId)) {
            throw 'ApprovedRoleAssignmentIds must be unique.'
        }

        $seenApprovedIds[[string]$approvedId] = $true
    }

    $stateIds = @($RoleState.Assignments | ForEach-Object { [string]$_.Id })
    $unapprovedIds = @($stateIds | Where-Object { [string]$_ -cnotin @($ApprovedAssignmentIds) })
    $missingIds = @($ApprovedAssignmentIds | Where-Object { [string]$_ -cnotin $stateIds })
    if ($stateIds.Count -ne 2 -or $unapprovedIds.Count -gt 0 -or $missingIds.Count -gt 0) {
        throw 'ApprovedRoleAssignmentIds must exactly match TemporaryRoleState assignment ids.'
    }
}

function Test-DefaultBicepInputs {
    param(
        [Parameter(Mandatory)]
        [object]$TenantConfiguration,

        [Parameter(Mandatory)]
        [string]$ParameterFilePath,

        [Parameter(Mandatory)]
        [object]$RoleState
    )

    if ([System.IO.Path]::GetExtension($ParameterFilePath) -cne '.bicepparam') {
        throw 'ParameterFile must be a .bicepparam file.'
    }

    $mainBicepPath = [System.IO.Path]::GetFullPath((Get-BicepEntryPath))
    $buildResult = Invoke-NativeCommand -FilePath 'az' -ArgumentList @('bicep', 'build', '--file', $mainBicepPath, '--stdout')
    if ($buildResult.ExitCode -ne 0) {
        throw ("Bicep build failed. {0}" -f $buildResult.StdErr)
    }

    $compiledParameters = Invoke-NativeJsonCommand -FilePath 'az' -ArgumentList @('bicep', 'build-params', '--file', $ParameterFilePath, '--stdout')
    if ((Get-TenantParameterValue -CompiledParameters $compiledParameters -Name 'tenantAlias') -cne [string]$TenantConfiguration.TenantAlias) {
        throw 'Compiled bicep parameters tenantAlias does not match the reviewed tenant manifest.'
    }
    if ((Get-TenantParameterValue -CompiledParameters $compiledParameters -Name 'location') -cne [string]$TenantConfiguration.PrimaryLocation) {
        throw 'Compiled bicep parameters location does not match the reviewed tenant manifest.'
    }
    if ((Get-TenantParameterValue -CompiledParameters $compiledParameters -Name 'namingRoot') -cne [string]$TenantConfiguration.NamingRoot) {
        throw 'Compiled bicep parameters namingRoot does not match the reviewed tenant manifest.'
    }
    if ((Get-TenantParameterValue -CompiledParameters $compiledParameters -Name 'validationPrincipalId') -cne [string]$RoleState.PrincipalObjectId) {
        throw 'Compiled bicep parameters validationPrincipalId does not match the accepted temporary role state.'
    }
}

Import-Module (Get-ModuleManifestPath) -Force

$resolvedTenantConfigurationPath = if ([string]::IsNullOrWhiteSpace($TenantConfigurationPath)) {
    Get-DefaultTenantConfigurationPath -TenantAliasValue $TenantAlias
}
else {
    [System.IO.Path]::GetFullPath($TenantConfigurationPath)
}

$resolvedEvidencePath = [System.IO.Path]::GetFullPath($EvidencePath)
$resolvedParameterFile = [System.IO.Path]::GetFullPath($ParameterFile)
$resolvedTemporaryRoleStatePath = [System.IO.Path]::GetFullPath($TemporaryRoleStatePath)

foreach ($requiredPath in @($resolvedTenantConfigurationPath, $resolvedEvidencePath, $resolvedParameterFile, $resolvedTemporaryRoleStatePath)) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        throw "Required path was not found: $requiredPath"
    }
}

$tenantConfiguration = Import-TenantConfiguration -Path $resolvedTenantConfigurationPath -ValidationStage 'Bootstrap'

if (-not $ConfirmRoleCleanup) {
    throw 'ConfirmRoleCleanup must be true before temporary role cleanup can be orchestrated.'
}

$effectiveDiscoveryValidator = if ($DiscoveryEvidenceValidator) { $DiscoveryEvidenceValidator } else { { param([string]$Path) Get-DefaultDiscoveryEvidence -Path $Path } }
$effectiveIntentValidator = if ($IntentValidator) { $IntentValidator } else { $null }
$effectiveOidcContextValidator = if ($OidcContextValidator) { $OidcContextValidator } else { $null }
$effectiveBicepValidator = if ($BicepValidator) { $BicepValidator } else { $null }
$effectiveRoleStateLoader = if ($RoleStateLoader) { $RoleStateLoader } else { $null }
$effectiveWhatIfBoundaryValidator = if ($WhatIfBoundaryValidator) { $WhatIfBoundaryValidator } else { { param([string]$Path, [string]$PrincipalObjectId) & (Get-WhatIfValidatorPath) -WhatIfPayloadPath $Path -ExpectedPrincipalObjectId $PrincipalObjectId | Out-Null } }
$cleanupNativeRunner = $NativeCommandRunner
$cleanupExpectedRunId = $BootstrapRunId
$cleanupApprovedRoleAssignmentIds = @($ApprovedRoleAssignmentIds)
$cleanupExpectedPrincipalObjectId = [string]$tenantConfiguration.Components.EntraServicePrincipal.Id
$cleanupExpectedScope = "/subscriptions/$([string]$tenantConfiguration.SubscriptionId)"
$effectiveCleanupRunner = if ($CleanupRunner) { $CleanupRunner } else { { param([object]$RoleState) Remove-TemporaryRoleAssignments -BootstrapResult $RoleState -ExpectedRunId $cleanupExpectedRunId -ApprovedRoleAssignmentIds $cleanupApprovedRoleAssignmentIds -ExpectedPrincipalObjectId $cleanupExpectedPrincipalObjectId -ExpectedScope $cleanupExpectedScope -NativeCommandRunner $cleanupNativeRunner -Confirm:$false | Out-Null }.GetNewClosure() }

$discoveryEvidence = & $effectiveDiscoveryValidator $resolvedEvidencePath
if ($effectiveIntentValidator) {
    & $effectiveIntentValidator $tenantConfiguration $resolvedEvidencePath
}
else {
    Test-TenantIntent -TenantConfiguration $tenantConfiguration -Evidence $discoveryEvidence | Out-Null
}

if ($effectiveOidcContextValidator) {
    & $effectiveOidcContextValidator $tenantConfiguration
}
else {
    Test-DefaultOidcContext -TenantConfiguration $tenantConfiguration
}

$roleState = if ($effectiveRoleStateLoader) {
    & $effectiveRoleStateLoader $resolvedTemporaryRoleStatePath
}
else {
    Get-ValidatedRoleState -Path $resolvedTemporaryRoleStatePath -TenantConfiguration $tenantConfiguration
}

Assert-ReviewedCleanupApproval -RoleState $roleState -ExpectedRunId $BootstrapRunId -ApprovedAssignmentIds $ApprovedRoleAssignmentIds -ExpectedScope $cleanupExpectedScope

$originalError = $null
$cleanupError = $null

try {
    if ($effectiveBicepValidator) {
        & $effectiveBicepValidator $resolvedParameterFile
    }
    else {
        Test-DefaultBicepInputs -TenantConfiguration $tenantConfiguration -ParameterFilePath $resolvedParameterFile -RoleState $roleState
    }

    if (-not $WhatIfOnly) {
        throw 'Invoke-TenantBootstrap.ps1 only supports -WhatIfOnly in this repository task slice.'
    }

    $whatIfNameToken = if ([string]::IsNullOrWhiteSpace($env:GITHUB_RUN_ID)) { 'local' } else { $env:GITHUB_RUN_ID }
    $arguments = @(
        'deployment',
        'sub',
        'what-if',
        '--location', 'switzerlandnorth',
        '--name', ("whatif-{0}-{1}" -f $TenantAlias, $whatIfNameToken),
        '--template-file', ([System.IO.Path]::GetFullPath((Get-BicepEntryPath))),
        '--parameters', $resolvedParameterFile,
        '--result-format', 'FullResourcePayloads',
        '--no-pretty-print'
    )

    $commandResult = Invoke-NativeCommand -FilePath 'az' -ArgumentList $arguments
    if ($commandResult.ExitCode -ne 0) {
        throw ("az what-if failed with exit code {0}. {1}" -f $commandResult.ExitCode, $commandResult.StdErr)
    }

    $tempRoot = if (-not [string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)) { $env:RUNNER_TEMP } else { [System.IO.Path]::GetTempPath() }
    $whatIfOutputPath = Join-Path $tempRoot ("whatif-{0}.json" -f ([guid]::NewGuid()).Guid)
    [System.IO.File]::WriteAllText($whatIfOutputPath, [string]$commandResult.StdOut, [System.Text.UTF8Encoding]::new($false))
    & $effectiveWhatIfBoundaryValidator $whatIfOutputPath ([string]$roleState.PrincipalObjectId)
}
catch {
    $originalError = $_
}
finally {
    if ($null -ne $roleState) {
        try {
            & $effectiveCleanupRunner $roleState
        }
        catch {
            $cleanupError = $_
        }
    }
}

if ($originalError -and $cleanupError) {
    throw ("{0} Cleanup failure: {1}" -f $originalError.Exception.Message, $cleanupError.Exception.Message)
}

if ($originalError) {
    throw $originalError.Exception
}

if ($cleanupError) {
    throw $cleanupError.Exception
}

[pscustomobject]@{
    TenantAlias = $TenantAlias
    WhatIfOnly = $true
    TemporaryRoleStatePath = $resolvedTemporaryRoleStatePath
}