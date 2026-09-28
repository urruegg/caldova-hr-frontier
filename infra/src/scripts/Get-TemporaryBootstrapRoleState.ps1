[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^tenant[1-9][0-9]*$')]
    [string]$PublicTenantKey,

    [Parameter(Mandatory)]
    [string]$TenantConfigurationPath,

    [Parameter(Mandatory)]
    [string]$OutputPath,

    [Parameter(DontShow)]
    [scriptblock]$AzRequest,

    [Parameter(DontShow)]
    [scriptblock]$NativeCommandRunner,

    [guid]$RunId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-ModuleManifestPath {
    Join-Path $PSScriptRoot 'modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1'
}

function Get-RepositoryRoot {
    [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
}

function ConvertTo-OrderedDictionary {
    param([hashtable]$InputObject)

    $ordered = [System.Collections.Specialized.OrderedDictionary]::new()
    foreach ($key in $InputObject.Keys) {
        $ordered.Add([string]$key, $InputObject[$key])
    }

    $ordered
}

function Write-BomFreeJsonFile {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [object]$Value
    )

    $directoryPath = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($directoryPath)) {
        [void](New-Item -ItemType Directory -Path $directoryPath -Force)
    }

    $temporaryPath = "$Path.tmp"
    $json = $Value | ConvertTo-Json -Depth 8
    [System.IO.File]::WriteAllText($temporaryPath, $json, [System.Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $temporaryPath -Destination $Path -Force
}

function Get-ObjectPropertyValue {
    param(
        [Parameter(Mandatory)]
        [object]$InputObject,

        [Parameter(Mandatory)]
        [string[]]$PropertyNames
    )

    foreach ($propertyName in $PropertyNames) {
        $property = $InputObject.PSObject.Properties[$propertyName]
        if ($property) {
            return [string]$property.Value
        }
    }

    ''
}

function Invoke-NativeCommand {
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,

        [Parameter(Mandatory)]
        [string[]]$ArgumentList
    )

    if (-not $NativeCommandRunner) {
        $stdoutPath = [System.IO.Path]::GetTempFileName()
        $stderrPath = [System.IO.Path]::GetTempFileName()
        try {
            $process = Start-Process -FilePath $FilePath -ArgumentList $ArgumentList -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -PassThru -Wait
            return [pscustomobject]@{
                ExitCode = $process.ExitCode
                StdOut = [System.IO.File]::ReadAllText($stdoutPath)
                StdErr = [System.IO.File]::ReadAllText($stderrPath)
            }
        }
        finally {
            Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
        }
    }

    $result = & $NativeCommandRunner -FilePath $FilePath -ArgumentList $ArgumentList
    [pscustomobject]@{
        ExitCode = [int]$result.ExitCode
        StdOut = [string]$result.StdOut
        StdErr = [string]$result.StdErr
    }
}

function Invoke-NativeJsonCommand {
    param(
        [Parameter(Mandatory)]
        [string[]]$ArgumentList
    )

    $result = Invoke-NativeCommand -FilePath 'az' -ArgumentList $ArgumentList
    if ($result.ExitCode -ne 0) {
        throw "Native command failed: az $($ArgumentList -join ' '). $($result.StdErr)"
    }
    if ([string]::IsNullOrWhiteSpace($result.StdOut)) {
        throw "Native command returned empty output: az $($ArgumentList -join ' ')."
    }

    $result.StdOut | ConvertFrom-Json
}

function Invoke-AzOperation {
    param(
        [Parameter(Mandatory)]
        [string]$Operation,

        [Parameter(Mandatory)]
        [hashtable]$Arguments
    )

    if (-not $AzRequest) {
        throw 'Get-TemporaryBootstrapRoleState.ps1 requires -AzRequest for adapter execution.'
    }

    & $AzRequest -Operation $Operation -Arguments (ConvertTo-OrderedDictionary -InputObject $Arguments)
}

Import-Module (Get-ModuleManifestPath) -Force

$repositoryRoot = Get-RepositoryRoot
$resolvedOutputPath = [System.IO.Path]::GetFullPath($OutputPath)
$normalizedRepositoryRoot = $repositoryRoot.TrimEnd('\')
$repositoryPrefix = $normalizedRepositoryRoot + '\'
if ($resolvedOutputPath.TrimEnd('\') -ieq $normalizedRepositoryRoot -or
    $resolvedOutputPath.StartsWith($repositoryPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'OutputPath must resolve outside the repository.'
}

$tenantConfiguration = Import-TenantConfiguration `
    -Path ([System.IO.Path]::GetFullPath($TenantConfigurationPath)) `
    -ValidationStage Bootstrap `
    -ExpectedPublicTenantKey $PublicTenantKey `
    -RequireLocalUntracked

$account = Invoke-NativeJsonCommand -ArgumentList @('account', 'show', '--output', 'json')
if ([string]$account.user.type -cne 'user') {
    throw 'Temporary role operations require an attended user context.'
}
if ([string]$account.tenantId -cne [string]$tenantConfiguration.TenantId) {
    throw 'Signed-in tenant does not match the reviewed tenant manifest.'
}
if ([string]$account.id -cne [string]$tenantConfiguration.SubscriptionId) {
    throw 'Signed-in subscription does not match the reviewed tenant manifest.'
}
$caller = Invoke-NativeJsonCommand -ArgumentList @('ad', 'signed-in-user', 'show', '--output', 'json')
$principalObjectId = [string]$caller.id
if ($principalObjectId -cnotmatch '^[0-9a-fA-F-]{36}$') {
    throw 'Signed-in user discovery did not return a GUID object id.'
}

$subscriptionId = [string]$tenantConfiguration.SubscriptionId
$scope = "/subscriptions/$subscriptionId"
$assignments = if ($AzRequest) {
    @((Invoke-AzOperation -Operation 'ListRoleAssignments' -Arguments @{
        PrincipalObjectId = $principalObjectId
        Scope = $scope
    }).Body)
}
else {
    @(Invoke-NativeJsonCommand -ArgumentList @('role', 'assignment', 'list', '--assignee-object-id', $principalObjectId, '--scope', $scope, '--output', 'json'))
}
$allowedRoleNames = @('Contributor', 'Role Based Access Control Administrator')
$expectedRoleDefinitionIds = @{
    Contributor = "$scope/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c"
    'Role Based Access Control Administrator' = "$scope/providers/Microsoft.Authorization/roleDefinitions/f58310d9-a9f6-439a-9e8d-f62e7b41a168"
}
$byRoleName = @{}
foreach ($roleName in $allowedRoleNames) {
    $byRoleName[$roleName] = @()
}

foreach ($assignment in $assignments) {
    $assignmentId = Get-ObjectPropertyValue -InputObject $assignment -PropertyNames @('Id', 'id')
    $assignmentRoleName = Get-ObjectPropertyValue -InputObject $assignment -PropertyNames @('RoleName', 'roleDefinitionName')
    $assignmentPrincipalObjectId = Get-ObjectPropertyValue -InputObject $assignment -PropertyNames @('PrincipalObjectId', 'principalId')
    $assignmentScope = Get-ObjectPropertyValue -InputObject $assignment -PropertyNames @('Scope', 'scope')
    $assignmentRoleDefinitionId = Get-ObjectPropertyValue -InputObject $assignment -PropertyNames @('RoleDefinitionId', 'roleDefinitionId')

    if ([string]::IsNullOrWhiteSpace($assignmentId) -or $assignmentId -cnotmatch '^/subscriptions/[0-9a-fA-F-]{36}/providers/Microsoft\.Authorization/roleAssignments/[0-9a-fA-F-]{36}$') {
        throw 'Every temporary bootstrap assignment must expose a well-formed exact Id.'
    }

    if ($assignmentRoleName -notin $allowedRoleNames) {
        throw "Unexpected role assignment $assignmentRoleName was returned for temporary bootstrap state discovery."
    }

    if ($assignmentPrincipalObjectId -cne $principalObjectId) {
        throw "Unexpected principal $assignmentPrincipalObjectId was returned for temporary bootstrap state discovery."
    }

    if ($assignmentScope -cne $scope) {
        throw "Unexpected scope $assignmentScope was returned for temporary bootstrap state discovery."
    }

    if ($assignmentRoleDefinitionId -cne [string]$expectedRoleDefinitionIds[$assignmentRoleName]) {
        throw "Unexpected role definition $assignmentRoleDefinitionId was returned for $assignmentRoleName."
    }

    $byRoleName[$assignmentRoleName] += $assignment
}

foreach ($roleName in $allowedRoleNames) {
    if (@($byRoleName[$roleName]).Count -ne 1) {
        throw "Temporary bootstrap state requires exactly one $roleName assignment."
    }
}

$effectiveRunId = if ($PSBoundParameters.ContainsKey('RunId')) { $RunId.Guid } elseif ([guid]::TryParse([string]$env:GITHUB_RUN_ID, [ref]([guid]::Empty))) { [string]$env:GITHUB_RUN_ID } else { ([guid]::NewGuid()).Guid }
$createdUtc = [datetime]::UtcNow.ToString('o')
$resultAssignments = foreach ($roleName in $allowedRoleNames) {
    $assignment = @($byRoleName[$roleName])[0]
    [pscustomobject]@{
        Id = Get-ObjectPropertyValue -InputObject $assignment -PropertyNames @('Id', 'id')
        RoleName = $roleName
        RoleDefinitionId = Get-ObjectPropertyValue -InputObject $assignment -PropertyNames @('RoleDefinitionId', 'roleDefinitionId')
        PrincipalObjectId = $principalObjectId
        Scope = $scope
        CreatedUtc = if ([string]::IsNullOrWhiteSpace((Get-ObjectPropertyValue -InputObject $assignment -PropertyNames @('CreatedUtc', 'createdUtc')))) { $createdUtc } else { Get-ObjectPropertyValue -InputObject $assignment -PropertyNames @('CreatedUtc', 'createdUtc') }
    }
}

$result = [pscustomobject]@{
    SchemaVersion = '1.0'
    RunId = $effectiveRunId
    TenantAlias = [string]$tenantConfiguration.TenantAlias
    TenantId = [string]$tenantConfiguration.TenantId
    SubscriptionId = $subscriptionId
    PrincipalObjectId = $principalObjectId
    Scope = $scope
    CreatedUtc = $createdUtc
    Assignments = @($resultAssignments)
}

Write-BomFreeJsonFile -Path $resolvedOutputPath -Value $result
$result