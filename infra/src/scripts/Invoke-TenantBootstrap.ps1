[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateScript({
        if ($_ -cnotmatch '^tenant[1-9][0-9]*$') {
            throw 'PublicTenantKey must use the case-sensitive lowercase tenant key format.'
        }
        $true
    })]
    [string]$PublicTenantKey,

    [Parameter(Mandatory)]
    [string]$TenantConfigurationPath,

    [Parameter(Mandatory)]
    [string]$EvidencePath,

    [Parameter(Mandatory)]
    [string]$ParameterFile,

    [switch]$WhatIfOnly,

    [Parameter(DontShow)]
    [scriptblock]$DiscoveryEvidenceValidator,

    [Parameter(DontShow)]
    [scriptblock]$IntentValidator,

    [Parameter(DontShow)]
    [scriptblock]$AttendedUserContextValidator,

    [Parameter(DontShow)]
    [scriptblock]$AccessPreflightValidator,

    [Parameter(DontShow)]
    [scriptblock]$BicepValidator,

    [Parameter(DontShow)]
    [scriptblock]$NativeCommandRunner,

    [Parameter(DontShow)]
    [scriptblock]$WhatIfBoundaryValidator
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-ModuleManifestPath {
    Join-Path $PSScriptRoot 'modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1'
}

function Get-RepositoryRoot {
    [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
}

function Get-BicepEntryPath {
    Join-Path $PSScriptRoot '..\bicep\main.bicep'
}

function Get-WhatIfValidatorPath {
    Join-Path $PSScriptRoot 'Test-WhatIfBoundary.ps1'
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

    $commandId = [guid]::NewGuid().Guid
    $stdoutPath = Join-Path $nativeOutputRoot ".native-$commandId.stdout"
    $stderrPath = Join-Path $nativeOutputRoot ".native-$commandId.stderr"
    try {
        $process = Start-Process `
            -FilePath $FilePath `
            -ArgumentList $ArgumentList `
            -WorkingDirectory (Split-Path -Parent $PSScriptRoot) `
            -RedirectStandardOutput $stdoutPath `
            -RedirectStandardError $stderrPath `
            -PassThru `
            -Wait
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

function Get-DefaultDiscoveryEvidence {
    param([string]$Path)

    $evidence = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
    Test-DiscoveryEvidence -Evidence $evidence | Out-Null
    $evidence
}

function Get-DefaultAttendedUserPrincipal {
    param([object]$TenantConfiguration)

    $account = Invoke-NativeJsonCommand -FilePath 'az' -ArgumentList @('account', 'show', '--output', 'json')
    if ([string]$account.user.type -cne 'user') {
        throw 'Lean Tenant 1 validation requires an attended user context.'
    }
    if ([string]$account.tenantId -cne [string]$TenantConfiguration.TenantId) {
        throw 'Signed-in tenant does not match the local Tenant 1 configuration.'
    }
    if ([string]$account.id -cne [string]$TenantConfiguration.SubscriptionId) {
        throw 'Signed-in subscription does not match the local Tenant 1 configuration.'
    }

    $caller = Invoke-NativeJsonCommand -FilePath 'az' -ArgumentList @('ad', 'signed-in-user', 'show', '--output', 'json')
    $principalObjectId = [guid]::Empty
    if (-not [guid]::TryParse([string]$caller.id, [ref]$principalObjectId)) {
        throw 'Signed-in user discovery did not return a GUID object id.'
    }

    $principalObjectId.Guid
}

function Test-ActionPattern {
    param(
        [Parameter(Mandatory)]
        [string]$Action,

        [AllowEmptyCollection()]
        [string[]]$Patterns
    )

    foreach ($pattern in @($Patterns)) {
        if (-not [string]::IsNullOrWhiteSpace($pattern) -and $Action -like $pattern) {
            return $true
        }
    }

    $false
}

function Get-DefaultAccessEvidence {
    param(
        [Parameter(Mandatory)]
        [object]$TenantConfiguration,

        [Parameter(Mandatory)]
        [string]$PrincipalObjectId
    )

    $scope = "/subscriptions/$([string]$TenantConfiguration.SubscriptionId)"
    $rawAssignments = @(
        Invoke-NativeJsonCommand -FilePath 'az' -ArgumentList @(
            'role',
            'assignment',
            'list',
            '--assignee-object-id', $PrincipalObjectId,
            '--scope', $scope,
            '--output', 'json'
        )
    )

    $assignments = [System.Collections.Generic.List[object]]::new()
    foreach ($assignment in $rawAssignments) {
        if ([string]$assignment.principalId -cne $PrincipalObjectId -or [string]$assignment.scope -cne $scope) {
            continue
        }

        $roleDefinitionId = [string]$assignment.roleDefinitionId
        $roleDefinitions = @(
            Invoke-NativeJsonCommand -FilePath 'az' -ArgumentList @(
                'role',
                'definition',
                'list',
                '--name', $roleDefinitionId,
                '--output', 'json'
            )
        )
        if ($roleDefinitions.Count -ne 1) {
            throw "Access preflight could not resolve one role definition for $roleDefinitionId."
        }

        $roleDefinition = $roleDefinitions[0]
        $actions = @($roleDefinition.permissions | ForEach-Object { @($_.actions) }) |
            Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } |
            Sort-Object -Unique
        $notActions = @($roleDefinition.permissions | ForEach-Object { @($_.notActions) }) |
            Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } |
            Sort-Object -Unique

        $assignments.Add([pscustomobject][ordered]@{
            Id = [string]$assignment.id
            PrincipalObjectId = [string]$assignment.principalId
            Scope = [string]$assignment.scope
            RoleDefinitionId = $roleDefinitionId
            RoleName = [string]$roleDefinition.roleName
            Actions = @($actions)
            NotActions = @($notActions)
        }) | Out-Null
    }

    [pscustomobject][ordered]@{
        SchemaVersion = '1.0'
        TenantId = [string]$TenantConfiguration.TenantId
        SubscriptionId = [string]$TenantConfiguration.SubscriptionId
        PrincipalObjectId = $PrincipalObjectId
        Scope = $scope
        Assignments = @($assignments)
    }
}

function Assert-MinimumWhatIfAccessEvidence {
    param(
        [Parameter(Mandatory)]
        [object]$Evidence,

        [Parameter(Mandatory)]
        [object]$TenantConfiguration,

        [Parameter(Mandatory)]
        [string]$PrincipalObjectId
    )

    $scope = "/subscriptions/$([string]$TenantConfiguration.SubscriptionId)"
    if ([string]$Evidence.SchemaVersion -cne '1.0' -or
        [string]$Evidence.TenantId -cne [string]$TenantConfiguration.TenantId -or
        [string]$Evidence.SubscriptionId -cne [string]$TenantConfiguration.SubscriptionId -or
        [string]$Evidence.PrincipalObjectId -cne $PrincipalObjectId -or
        [string]$Evidence.Scope -cne $scope) {
        throw 'Access evidence does not match the attended Tenant 1 context.'
    }

    $requiredAction = 'Microsoft.Resources/deployments/whatIf/action'
    $effectiveAssignments = [System.Collections.Generic.List[object]]::new()
    $seenAssignmentIds = @{}
    foreach ($assignment in @($Evidence.Assignments)) {
        $assignmentId = [string]$assignment.Id
        if ([string]::IsNullOrWhiteSpace($assignmentId) -or $seenAssignmentIds.ContainsKey($assignmentId)) {
            throw 'Access evidence assignment ids must be present and unique.'
        }
        $seenAssignmentIds[$assignmentId] = $true

        if ([string]$assignment.PrincipalObjectId -cne $PrincipalObjectId -or
            [string]$assignment.Scope -cne $scope -or
            [string]::IsNullOrWhiteSpace([string]$assignment.RoleDefinitionId)) {
            throw 'Access evidence assignments must match the attended principal and exact subscription scope.'
        }

        $allowed = Test-ActionPattern -Action $requiredAction -Patterns @($assignment.Actions)
        $denied = Test-ActionPattern -Action $requiredAction -Patterns @($assignment.NotActions)
        if ($allowed -and -not $denied) {
            $effectiveAssignments.Add($assignment) | Out-Null
        }
    }

    if ($effectiveAssignments.Count -eq 0) {
        throw 'No separately approved effective assignment permits the reviewed subscription what-if.'
    }

    $Evidence
}

function Get-AccessEvidenceSignature {
    param([Parameter(Mandatory)][object]$Evidence)

    @(
        foreach ($assignment in @($Evidence.Assignments) | Sort-Object -Property Id) {
            @(
                [string]$assignment.Id
                [string]$assignment.PrincipalObjectId
                [string]$assignment.Scope
                [string]$assignment.RoleDefinitionId
                [string]$assignment.RoleName
                (@($assignment.Actions) | Sort-Object) -join ','
                (@($assignment.NotActions) | Sort-Object) -join ','
            ) -join '|'
        }
    ) -join ';'
}

function Write-JsonFile {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [object]$Value
    )

    [System.IO.File]::WriteAllText(
        $Path,
        ($Value | ConvertTo-Json -Depth 32),
        [System.Text.UTF8Encoding]::new($false)
    )
}

function Test-DefaultBicepInputs {
    param(
        [Parameter(Mandatory)]
        [object]$TenantConfiguration,

        [Parameter(Mandatory)]
        [string]$ParameterFilePath,

        [Parameter(Mandatory)]
        [string]$PrincipalObjectId
    )

    if ([System.IO.Path]::GetExtension($ParameterFilePath) -cne '.bicepparam') {
        throw 'ParameterFile must be a .bicepparam file.'
    }

    $mainBicepPath = [System.IO.Path]::GetFullPath((Get-BicepEntryPath))
    $buildResult = Invoke-NativeCommand -FilePath 'az' -ArgumentList @(
        'bicep',
        'build',
        '--file', $mainBicepPath,
        '--stdout'
    )
    if ($buildResult.ExitCode -ne 0) {
        throw ("Bicep build failed. {0}" -f $buildResult.StdErr)
    }

    $compiledParameters = Invoke-NativeJsonCommand -FilePath 'az' -ArgumentList @(
        'bicep',
        'build-params',
        '--file', $ParameterFilePath,
        '--stdout'
    )
    if ((Get-TenantParameterValue -CompiledParameters $compiledParameters -Name 'tenantAlias') -cne [string]$TenantConfiguration.TenantAlias) {
        throw 'Compiled bicep parameters tenantAlias does not match the local Tenant 1 configuration.'
    }
    if ((Get-TenantParameterValue -CompiledParameters $compiledParameters -Name 'location') -cne [string]$TenantConfiguration.PrimaryLocation) {
        throw 'Compiled bicep parameters location does not match the local Tenant 1 configuration.'
    }
    if ((Get-TenantParameterValue -CompiledParameters $compiledParameters -Name 'namingRoot') -cne [string]$TenantConfiguration.NamingRoot) {
        throw 'Compiled bicep parameters namingRoot does not match the local Tenant 1 configuration.'
    }
    if ((Get-TenantParameterValue -CompiledParameters $compiledParameters -Name 'validationPrincipalId') -cne $PrincipalObjectId) {
        throw 'Compiled bicep parameters validationPrincipalId does not match the attended user.'
    }
}

Import-Module (Get-ModuleManifestPath) -Force

$repositoryRoot = Get-RepositoryRoot
$resolvedTenantConfigurationPath = [System.IO.Path]::GetFullPath($TenantConfigurationPath)
$resolvedEvidencePath = [System.IO.Path]::GetFullPath($EvidencePath)
$resolvedParameterFile = [System.IO.Path]::GetFullPath($ParameterFile)
$nativeOutputRoot = Split-Path -Parent $resolvedEvidencePath
$normalizedRepositoryRoot = $repositoryRoot.TrimEnd('\')
$repositoryPrefix = $normalizedRepositoryRoot + '\'

foreach ($privateRunPath in @($resolvedEvidencePath, $resolvedParameterFile)) {
    if ($privateRunPath.TrimEnd('\') -ieq $normalizedRepositoryRoot -or
        $privateRunPath.StartsWith($repositoryPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'EvidencePath and ParameterFile must resolve outside the repository.'
    }
}

foreach ($requiredPath in @($resolvedTenantConfigurationPath, $resolvedEvidencePath, $resolvedParameterFile)) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        throw "Required path was not found: $requiredPath"
    }
}

$tenantConfiguration = Import-TenantConfiguration `
    -Path $resolvedTenantConfigurationPath `
    -ValidationStage Bootstrap `
    -ExpectedPublicTenantKey $PublicTenantKey `
    -RequireLocalUntracked

if (-not $WhatIfOnly) {
    throw 'Invoke-TenantBootstrap.ps1 only supports -WhatIfOnly in this repository task slice.'
}

$effectiveDiscoveryValidator = if ($DiscoveryEvidenceValidator) {
    $DiscoveryEvidenceValidator
}
else {
    { param([string]$Path) Get-DefaultDiscoveryEvidence -Path $Path }
}
$effectiveAttendedUserContextValidator = if ($AttendedUserContextValidator) {
    $AttendedUserContextValidator
}
else {
    { param([object]$Configuration) Get-DefaultAttendedUserPrincipal -TenantConfiguration $Configuration }
}
$effectiveAccessPreflightValidator = if ($AccessPreflightValidator) {
    $AccessPreflightValidator
}
else {
    {
        param([object]$Configuration, [string]$PrincipalObjectId)
        Get-DefaultAccessEvidence -TenantConfiguration $Configuration -PrincipalObjectId $PrincipalObjectId
    }
}
$effectiveWhatIfBoundaryValidator = if ($WhatIfBoundaryValidator) {
    $WhatIfBoundaryValidator
}
else {
    {
        param([string]$Path, [string]$PrincipalObjectId)
        & (Get-WhatIfValidatorPath) `
            -WhatIfPayloadPath $Path `
            -ExpectedPrincipalObjectId $PrincipalObjectId | Out-Null
    }
}

$attendedPrincipalObjectId = & $effectiveAttendedUserContextValidator $tenantConfiguration
$validatedAttendedPrincipalObjectId = [guid]::Empty
if (-not [guid]::TryParse([string]$attendedPrincipalObjectId, [ref]$validatedAttendedPrincipalObjectId)) {
    throw 'AttendedUserContextValidator must return a GUID principal object id.'
}
$principalObjectId = $validatedAttendedPrincipalObjectId.Guid

$accessEvidencePath = Join-Path (Split-Path -Parent $resolvedEvidencePath) 'access-validation.json'
$whatIfOutputPath = Join-Path (Split-Path -Parent $resolvedEvidencePath) 'what-if.json'
$preflightEvidence = & $effectiveAccessPreflightValidator $tenantConfiguration $principalObjectId
$preflightEvidence = Assert-MinimumWhatIfAccessEvidence `
    -Evidence $preflightEvidence `
    -TenantConfiguration $tenantConfiguration `
    -PrincipalObjectId $principalObjectId

$accessRecord = [pscustomobject][ordered]@{
    SchemaVersion = '1.0'
    RecordedUtc = [datetime]::UtcNow.ToString('o')
    TenantAlias = [string]$tenantConfiguration.TenantAlias
    TenantId = [string]$tenantConfiguration.TenantId
    SubscriptionId = [string]$tenantConfiguration.SubscriptionId
    PrincipalObjectId = $principalObjectId
    Scope = "/subscriptions/$([string]$tenantConfiguration.SubscriptionId)"
    WhatIfOnly = $true
    Preflight = $preflightEvidence
    ReadBack = $null
}
Write-JsonFile -Path $accessEvidencePath -Value $accessRecord

$discoveryEvidence = & $effectiveDiscoveryValidator $resolvedEvidencePath
if ($IntentValidator) {
    & $IntentValidator $tenantConfiguration $resolvedEvidencePath
}
else {
    Test-TenantIntent -TenantConfiguration $tenantConfiguration -Evidence $discoveryEvidence | Out-Null
}

if ($BicepValidator) {
    & $BicepValidator $resolvedParameterFile
}
else {
    Test-DefaultBicepInputs `
        -TenantConfiguration $tenantConfiguration `
        -ParameterFilePath $resolvedParameterFile `
        -PrincipalObjectId $principalObjectId
}

$arguments = @(
    'deployment',
    'sub',
    'what-if',
    '--location', ([string]$tenantConfiguration.PrimaryLocation),
    '--name', ("whatif-{0}-local" -f ([string]$tenantConfiguration.TenantAlias)),
    '--template-file', ([System.IO.Path]::GetFullPath((Get-BicepEntryPath))),
    '--parameters', $resolvedParameterFile,
    '--result-format', 'FullResourcePayloads',
    '--no-pretty-print'
)
$commandResult = Invoke-NativeCommand -FilePath 'az' -ArgumentList $arguments
if ($commandResult.ExitCode -ne 0) {
    throw ("az what-if failed with exit code {0}. {1}" -f $commandResult.ExitCode, $commandResult.StdErr)
}

[System.IO.File]::WriteAllText(
    $whatIfOutputPath,
    [string]$commandResult.StdOut,
    [System.Text.UTF8Encoding]::new($false)
)
& $effectiveWhatIfBoundaryValidator $whatIfOutputPath $principalObjectId

$readBackPrincipalObjectId = & $effectiveAttendedUserContextValidator $tenantConfiguration
$validatedReadBackPrincipalObjectId = [guid]::Empty
if (-not [guid]::TryParse([string]$readBackPrincipalObjectId, [ref]$validatedReadBackPrincipalObjectId) -or
    $validatedReadBackPrincipalObjectId -ne $validatedAttendedPrincipalObjectId) {
    throw 'Attended context drift was detected after what-if.'
}

$readBackEvidence = & $effectiveAccessPreflightValidator $tenantConfiguration $principalObjectId
$readBackEvidence = Assert-MinimumWhatIfAccessEvidence `
    -Evidence $readBackEvidence `
    -TenantConfiguration $tenantConfiguration `
    -PrincipalObjectId $principalObjectId
if ((Get-AccessEvidenceSignature -Evidence $readBackEvidence) -cne
    (Get-AccessEvidenceSignature -Evidence $preflightEvidence)) {
    throw 'Access drift was detected after what-if.'
}

$accessRecord.RecordedUtc = [datetime]::UtcNow.ToString('o')
$accessRecord.ReadBack = $readBackEvidence
Write-JsonFile -Path $accessEvidencePath -Value $accessRecord

[pscustomobject][ordered]@{
    TenantAlias = [string]$tenantConfiguration.TenantAlias
    WhatIfOnly = $true
    PrincipalObjectId = $principalObjectId
    AccessEvidencePath = $accessEvidencePath
    WhatIfOutputPath = $whatIfOutputPath
}
