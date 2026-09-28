[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
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

    [Parameter(DontShow)]
    [scriptblock]$Clock
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-RepositoryRoot {
    [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
}

function Get-ModuleManifestPath {
    Join-Path $PSScriptRoot 'modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1'
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

function Get-Clock {
    if ($Clock) {
        return & $Clock
    }

    [datetime]::UtcNow
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
            & $FilePath @ArgumentList 1> $stdoutPath 2> $stderrPath
            return [pscustomobject]@{
                ExitCode = $LASTEXITCODE
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
        throw 'Grant-TemporaryBootstrapRoles.ps1 requires -AzRequest for adapter execution.'
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
$pinnedRoleDefinitionIds = @{
    Contributor = "$scope/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c"
    'Role Based Access Control Administrator' = "$scope/providers/Microsoft.Authorization/roleDefinitions/f58310d9-a9f6-439a-9e8d-f62e7b41a168"
}
$createdUtc = (Get-Clock).ToUniversalTime().ToString('o')
$runId = $env:GITHUB_RUN_ID
if (-not [guid]::TryParse([string]$runId, [ref]([guid]::Empty))) {
    $runId = ([guid]::NewGuid()).Guid
}

$roleNames = @('Contributor', 'Role Based Access Control Administrator')
$assignments = @()
if (-not $AzRequest) {
    $callerAssignments = @(Invoke-NativeJsonCommand -ArgumentList @('role', 'assignment', 'list', '--assignee-object-id', $principalObjectId, '--scope', $scope, '--output', 'json'))
    $hasEligibleRole = $false
    foreach ($assignment in $callerAssignments) {
        $roleDefinitionName = [string]$assignment.roleDefinitionName
        if ([string]::IsNullOrWhiteSpace($roleDefinitionName)) {
            $roleDefinitionName = [string]$assignment.RoleDefinitionName
        }

        $assignmentScope = [string]$assignment.scope
        if ([string]::IsNullOrWhiteSpace($assignmentScope)) {
            $assignmentScope = [string]$assignment.Scope
        }

        if ($assignmentScope -ceq $scope -and $roleDefinitionName -in @('Owner', 'Role Based Access Control Administrator')) {
            $hasEligibleRole = $true
            break
        }
    }

    if (-not $hasEligibleRole) {
        throw 'Temporary bootstrap grants require Owner or Role Based Access Control Administrator at the exact subscription scope.'
    }
}

foreach ($roleName in $roleNames) {
    $roleDefinition = if ($AzRequest) {
        (Invoke-AzOperation -Operation 'GetRoleDefinitionByName' -Arguments @{
            RoleName = $roleName
            SubscriptionId = $subscriptionId
            Scope = $scope
        }).Body
    }
    else {
        $definitions = @(Invoke-NativeJsonCommand -ArgumentList @('role', 'definition', 'list', '--name', $roleName, '--scope', $scope, '--output', 'json'))
        if ($definitions.Count -ne 1) {
            throw "Expected exactly one role definition for $roleName."
        }

        $definitions[0]
    }
    if ($null -eq $roleDefinition) {
        throw "Role definition lookup for $roleName did not return an Id."
    }

    $roleDefinitionId = Get-ObjectPropertyValue -InputObject $roleDefinition -PropertyNames @('Id', 'id')
    if ([string]::IsNullOrWhiteSpace($roleDefinitionId)) {
        throw "Role definition lookup for $roleName did not return an Id."
    }

    $pinnedRoleDefinitionId = [string]$pinnedRoleDefinitionIds[$roleName]
    if ($roleDefinitionId -cne $pinnedRoleDefinitionId) {
        throw "$roleName must resolve to its pinned built-in role definition id $pinnedRoleDefinitionId."
    }

    $resolvedRoleName = Get-ObjectPropertyValue -InputObject $roleDefinition -PropertyNames @('RoleName', 'roleName', 'Name', 'name')
    if (-not [string]::IsNullOrWhiteSpace($resolvedRoleName) -and $resolvedRoleName -cne $roleName) {
        throw "Role definition lookup for $roleName returned a different role name."
    }

    if (-not $PSCmdlet.ShouldProcess($scope, "Create temporary $roleName assignment for $principalObjectId")) {
        continue
    }

    $expectedAssignmentId = ''
    $assignment = if ($AzRequest) {
        (Invoke-AzOperation -Operation 'CreateRoleAssignment' -Arguments @{
            RoleName = $roleName
            RoleDefinitionId = $roleDefinitionId
            PrincipalObjectId = $principalObjectId
            Scope = $scope
        }).Body
    }
    else {
        $created = Invoke-NativeJsonCommand -ArgumentList @(
            'role', 'assignment', 'create',
            '--assignee-object-id', $principalObjectId,
            '--assignee-principal-type', 'User',
            '--role', $roleDefinitionId,
            '--scope', $scope,
            '--output', 'json'
        )
        $createdId = [string]$created.id
        if ([string]::IsNullOrWhiteSpace($createdId)) {
            throw "Temporary assignment creation for $roleName did not return an id."
        }

        $expectedAssignmentId = $createdId
        Invoke-NativeJsonCommand -ArgumentList @(
            'rest',
            '--method', 'get',
            '--url', ("{0}?api-version=2022-04-01" -f $createdId),
            '--output', 'json'
        )
    }
    if ($null -eq $assignment) {
        throw "Temporary assignment creation for $roleName did not return an Id."
    }

    $assignmentId = Get-ObjectPropertyValue -InputObject $assignment -PropertyNames @('Id', 'id')
    $assignmentProperties = $assignment
    $propertiesProperty = $assignment.PSObject.Properties['properties']
    if ($propertiesProperty -and $null -ne $propertiesProperty.Value) {
        $assignmentProperties = $propertiesProperty.Value
    }

    $assignmentRoleDefinitionId = Get-ObjectPropertyValue -InputObject $assignmentProperties -PropertyNames @('RoleDefinitionId', 'roleDefinitionId')
    $assignmentPrincipalObjectId = Get-ObjectPropertyValue -InputObject $assignmentProperties -PropertyNames @('PrincipalObjectId', 'principalId')
    $assignmentPrincipalType = Get-ObjectPropertyValue -InputObject $assignmentProperties -PropertyNames @('PrincipalType', 'principalType')
    $assignmentScope = Get-ObjectPropertyValue -InputObject $assignmentProperties -PropertyNames @('Scope', 'scope')
    if (
        [string]::IsNullOrWhiteSpace($assignmentId) -or
        (-not [string]::IsNullOrWhiteSpace($expectedAssignmentId) -and $assignmentId -cne $expectedAssignmentId) -or
        $assignmentRoleDefinitionId -cne $roleDefinitionId -or
        $assignmentPrincipalObjectId -cne $principalObjectId -or
        (-not [string]::IsNullOrWhiteSpace($expectedAssignmentId) -and $assignmentPrincipalType -cne 'User') -or
        $assignmentScope -cne $scope
    ) {
        throw "Temporary assignment read-back for $roleName does not match the exact assignment id, reviewed principal and type, pinned role definition, and scope."
    }

    $assignments += [pscustomobject]@{
        Id = $assignmentId
        RoleName = $roleName
        RoleDefinitionId = $assignmentRoleDefinitionId
        PrincipalObjectId = $assignmentPrincipalObjectId
        Scope = $assignmentScope
        CreatedUtc = if ([string]::IsNullOrWhiteSpace((Get-ObjectPropertyValue -InputObject $assignment -PropertyNames @('CreatedUtc', 'createdUtc')))) { $createdUtc } else { Get-ObjectPropertyValue -InputObject $assignment -PropertyNames @('CreatedUtc', 'createdUtc') }
    }
}

if ($assignments.Count -ne 2) {
    throw 'Temporary bootstrap grant must create exactly two assignments.'
}

$result = [pscustomobject]@{
    SchemaVersion = '1.0'
    RunId = $runId
    TenantAlias = [string]$tenantConfiguration.TenantAlias
    TenantId = [string]$tenantConfiguration.TenantId
    SubscriptionId = $subscriptionId
    PrincipalObjectId = $principalObjectId
    Scope = $scope
    CreatedUtc = $createdUtc
    Assignments = @($assignments)
}

Write-BomFreeJsonFile -Path $resolvedOutputPath -Value $result
$result