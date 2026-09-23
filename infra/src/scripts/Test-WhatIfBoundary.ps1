[CmdletBinding()]
param(
    [Parameter(Mandatory)]
        [string]$WhatIfPayloadPath,

        [Parameter(Mandatory)]
        [ValidatePattern('^[0-9a-fA-F-]{36}$')]
        [string]$ExpectedPrincipalObjectId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Add-Offense {
    param(
        [Parameter(Mandatory)]
        [object]$Collection,

        [Parameter(Mandatory)]
        [string]$Message
    )

    $Collection.Add([string]$Message) | Out-Null
}

function Get-Entries {
    param([object]$Value)

    if ($null -eq $Value) {
        return [ordered]@{}
    }

    if ($Value -is [System.Collections.IDictionary]) {
        $entries = [ordered]@{}
        foreach ($key in $Value.Keys) {
            $entries[[string]$key] = $Value[$key]
        }

        return $entries
    }

    $entries = [ordered]@{}
    foreach ($property in $Value.PSObject.Properties) {
        if ($property.MemberType -in @('NoteProperty', 'Property', 'ScriptProperty')) {
            $entries[$property.Name] = $property.Value
        }
    }

    $entries
}

function Convert-GuidByteOrder {
    param([Parameter(Mandatory)][byte[]]$Bytes)

    [Array]::Reverse($Bytes, 0, 4)
    [Array]::Reverse($Bytes, 4, 2)
    [Array]::Reverse($Bytes, 6, 2)
    ,$Bytes
}

function New-ArmGuid {
    param([Parameter(Mandatory)][string[]]$Values)

    $namespace = [guid]'11fb06fb-712d-4ddd-98c7-e71bbd588830'
    [byte[]]$namespaceBytes = Convert-GuidByteOrder -Bytes $namespace.ToByteArray()
    [byte[]]$nameBytes = [System.Text.Encoding]::UTF8.GetBytes(($Values -join '-'))
    [byte[]]$combined = New-Object byte[] ($namespaceBytes.Length + $nameBytes.Length)
    [Array]::Copy($namespaceBytes, 0, $combined, 0, $namespaceBytes.Length)
    [Array]::Copy($nameBytes, 0, $combined, $namespaceBytes.Length, $nameBytes.Length)

    $sha1 = [System.Security.Cryptography.SHA1]::Create()
    try {
        [byte[]]$hash = $sha1.ComputeHash($combined)
    }
    finally {
        $sha1.Dispose()
    }

    [byte[]]$guidBytes = New-Object byte[] 16
    [Array]::Copy($hash, $guidBytes, 16)
    $guidBytes[6] = ($guidBytes[6] -band 0x0f) -bor 0x50
    $guidBytes[8] = ($guidBytes[8] -band 0x3f) -bor 0x80
    [byte[]]$orderedBytes = Convert-GuidByteOrder -Bytes $guidBytes
    ([guid]::new($orderedBytes)).ToString()
}

function Test-ExactStringSet {
    param(
        [AllowNull()][object[]]$Actual,
        [Parameter(Mandatory)][string[]]$Expected
    )

    $actualValues = @($Actual | ForEach-Object { [string]$_ } | Sort-Object)
    $expectedValues = @($Expected | Sort-Object)
    @((Compare-Object -ReferenceObject $expectedValues -DifferenceObject $actualValues)).Count -eq 0
}

function Test-IsJsonObject {
    param([AllowNull()][object]$Value)

    $null -ne $Value -and (
        $Value -is [System.Collections.IDictionary] -or
        $Value -is [System.Management.Automation.PSCustomObject]
    )
}

function Test-IsJsonArray {
    param([AllowNull()][object]$Value)

    $Value -is [System.Array]
}

function Test-ExactStringMap {
    param(
        [AllowNull()][object]$Actual,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Expected
    )

    if (-not (Test-IsJsonObject -Value $Actual)) {
        return $false
    }

    $actualEntries = Get-Entries -Value $Actual
    if ($actualEntries.Count -ne $Expected.Count) {
        return $false
    }

    foreach ($key in $Expected.Keys) {
        if (-not $actualEntries.Contains([string]$key) -or [string]$actualEntries[[string]$key] -cne [string]$Expected[$key]) {
            return $false
        }
    }

    $true
}

function Get-ResourceScope {
    param(
        [AllowNull()][string]$ResourceId,
        [AllowNull()][string]$ResourceType
    )

    if ([string]::IsNullOrWhiteSpace($ResourceId)) {
        return '<unknown>'
    }

    if ($ResourceType -ceq 'Microsoft.Resources/resourceGroups' -and $ResourceId -match '^(.*)/resourceGroups/[^/]+$') {
        return [string]$Matches[1]
    }

    $providerIndex = $ResourceId.LastIndexOf('/providers/', [System.StringComparison]::OrdinalIgnoreCase)
    if ($providerIndex -gt 0) {
        return $ResourceId.Substring(0, $providerIndex)
    }

    '<unknown>'
}

function Get-DisplayValue {
    param([AllowNull()][string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return '<none>'
    }

    $Value
}

function Add-ResourceOffense {
    param(
        [Parameter(Mandatory)][object]$Collection,
        [AllowNull()][string]$ResourceId,
        [AllowNull()][string]$ResourceType,
        [AllowNull()][string]$ResourceScope,
        [AllowNull()][string]$ResourceLocation,
        [Parameter(Mandatory)][string]$Message
    )

    $context = 'Resource id={0}; type={1}; scope={2}; location={3}' -f @(
        (Get-DisplayValue -Value $ResourceId),
        (Get-DisplayValue -Value $ResourceType),
        (Get-DisplayValue -Value $ResourceScope),
        (Get-DisplayValue -Value $ResourceLocation)
    )
    Add-Offense -Collection $Collection -Message ("{0}: {1}" -f $context, $Message)
}

function Test-ResourceIdentity {
    param(
        [Parameter(Mandatory)][object]$Collection,
        [Parameter(Mandatory)][object]$Resource,
        [Parameter(Mandatory)][object]$ExpectedResource,
        [Parameter(Mandatory)][string]$ChangeResourceId,
        [Parameter(Mandatory)][string]$PayloadName
    )

    $entries = Get-Entries -Value $Resource
    $payloadId = [string]$entries['id']
    $resourceType = [string]$entries['type']
    $resourceName = [string]$entries['name']
    $resourceLocation = [string]$entries['location']
    $contextId = if ([string]::IsNullOrWhiteSpace($payloadId)) { $ChangeResourceId } else { $payloadId }
    $contextType = if ([string]::IsNullOrWhiteSpace($resourceType)) { [string]$ExpectedResource.Type } else { $resourceType }
    $resourceScope = Get-ResourceScope -ResourceId $contextId -ResourceType $contextType

    if ($payloadId -cne [string]$ExpectedResource.Id) {
        Add-ResourceOffense -Collection $Collection -ResourceId $contextId -ResourceType $contextType -ResourceScope $resourceScope -ResourceLocation $resourceLocation -Message ("{0}.id must equal {1}." -f $PayloadName, [string]$ExpectedResource.Id)
    }
    if ($resourceType -cne [string]$ExpectedResource.Type) {
        Add-ResourceOffense -Collection $Collection -ResourceId $contextId -ResourceType $contextType -ResourceScope $resourceScope -ResourceLocation $resourceLocation -Message ("{0}.type must equal {1}." -f $PayloadName, [string]$ExpectedResource.Type)
    }
    if ($resourceName -cne [string]$ExpectedResource.Name) {
        Add-ResourceOffense -Collection $Collection -ResourceId $contextId -ResourceType $contextType -ResourceScope $resourceScope -ResourceLocation $resourceLocation -Message ("{0}.name must equal {1}; actual={2}." -f $PayloadName, [string]$ExpectedResource.Name, (Get-DisplayValue -Value $resourceName))
    }
    if (-not [string]::IsNullOrWhiteSpace($payloadId)) {
        $idName = [string]($payloadId -split '/')[-1]
        if ($resourceName -cne $idName) {
            Add-ResourceOffense -Collection $Collection -ResourceId $contextId -ResourceType $contextType -ResourceScope $resourceScope -ResourceLocation $resourceLocation -Message ("{0}.name disagrees with its id segment {1}." -f $PayloadName, $idName)
        }
    }
    if ($resourceScope -cne [string]$ExpectedResource.Scope) {
        Add-ResourceOffense -Collection $Collection -ResourceId $contextId -ResourceType $contextType -ResourceScope $resourceScope -ResourceLocation $resourceLocation -Message ("{0} scope must equal {1}." -f $PayloadName, [string]$ExpectedResource.Scope)
    }
    if ([string]$entries['apiVersion'] -cne [string]$ExpectedResource.ApiVersion) {
        Add-ResourceOffense -Collection $Collection -ResourceId $contextId -ResourceType $contextType -ResourceScope $resourceScope -ResourceLocation $resourceLocation -Message ("{0}.apiVersion must equal {1}." -f $PayloadName, [string]$ExpectedResource.ApiVersion)
    }
    if ([string]::IsNullOrWhiteSpace([string]$ExpectedResource.Location)) {
        if (-not [string]::IsNullOrWhiteSpace($resourceLocation)) {
            Add-ResourceOffense -Collection $Collection -ResourceId $contextId -ResourceType $contextType -ResourceScope $resourceScope -ResourceLocation $resourceLocation -Message ("{0}.location must be absent for this subscription resource." -f $PayloadName)
        }
    }
    elseif ($resourceLocation -cne [string]$ExpectedResource.Location) {
        Add-ResourceOffense -Collection $Collection -ResourceId $contextId -ResourceType $contextType -ResourceScope $resourceScope -ResourceLocation $resourceLocation -Message ("{0}.location must equal {1}." -f $PayloadName, [string]$ExpectedResource.Location)
    }

    ,$entries
}

function Test-ExpectedResourceProperties {
    param(
        [Parameter(Mandatory)][object]$Collection,
        [Parameter(Mandatory)][object]$ResourceEntries,
        [Parameter(Mandatory)][object]$ExpectedResource,
        [Parameter(Mandatory)][System.Collections.IDictionary]$ExpectedTags,
        [Parameter(Mandatory)][string[]]$ExpectedRoleActions,
        [Parameter(Mandatory)][string]$ExpectedRoleDescription,
        [Parameter(Mandatory)][string]$ExpectedRoleDefinitionId,
        [Parameter(Mandatory)][string]$ExpectedPrincipalId,
        [Parameter(Mandatory)][string]$ExpectedWorkspaceId,
        [Parameter(Mandatory)][string]$PayloadName
    )

    $resourceId = [string]$ResourceEntries['id']
    $resourceType = [string]$ResourceEntries['type']
    $resourceLocation = [string]$ResourceEntries['location']
    $resourceScope = Get-ResourceScope -ResourceId $resourceId -ResourceType $resourceType
    $offend = {
        param([string]$Message)
        Add-ResourceOffense -Collection $Collection -ResourceId $resourceId -ResourceType $resourceType -ResourceScope $resourceScope -ResourceLocation $resourceLocation -Message $Message
    }

    switch ([string]$ExpectedResource.Type) {
        'Microsoft.Resources/resourceGroups' {
            if (-not (Test-ExactStringMap -Actual $ResourceEntries['tags'] -Expected $ExpectedTags)) {
                & $offend ("{0}.tags must exactly match the Tenant 1 baseline tags." -f $PayloadName)
            }
        }
        'Microsoft.OperationalInsights/workspaces' {
            if (-not (Test-ExactStringMap -Actual $ResourceEntries['tags'] -Expected $ExpectedTags)) {
                & $offend ("{0}.tags must exactly match the Tenant 1 baseline tags." -f $PayloadName)
            }

            if (-not (Test-IsJsonObject -Value $ResourceEntries['properties'])) {
                & $offend ("{0}.properties must be an object." -f $PayloadName)
                break
            }
            $workspaceProperties = Get-Entries -Value $ResourceEntries['properties']
            if (-not (Test-IsJsonObject -Value $workspaceProperties['sku']) -or [string](Get-Entries -Value $workspaceProperties['sku'])['name'] -cne 'PerGB2018') {
                & $offend ("{0}.properties.sku.name must equal PerGB2018." -f $PayloadName)
            }
            if ($workspaceProperties['retentionInDays'] -is [string] -or $workspaceProperties['retentionInDays'] -ne 30) {
                & $offend ("{0}.properties.retentionInDays must equal 30." -f $PayloadName)
            }
            foreach ($networkProperty in @('publicNetworkAccessForIngestion', 'publicNetworkAccessForQuery')) {
                if ([string]$workspaceProperties[$networkProperty] -cne 'Enabled') {
                    & $offend ("{0}.properties.{1} must equal Enabled." -f $PayloadName, $networkProperty)
                }
            }
        }
        'Microsoft.Insights/diagnosticSettings' {
            if (-not (Test-IsJsonObject -Value $ResourceEntries['properties'])) {
                & $offend ("{0}.properties must be an object." -f $PayloadName)
                break
            }
            $diagnosticProperties = Get-Entries -Value $ResourceEntries['properties']
            if ([string]$diagnosticProperties['workspaceId'] -cne $ExpectedWorkspaceId) {
                & $offend ("{0}.properties.workspaceId must equal {1}; actual={2}." -f $PayloadName, $ExpectedWorkspaceId, (Get-DisplayValue -Value ([string]$diagnosticProperties['workspaceId'])))
            }
            if (-not (Test-IsJsonArray -Value $diagnosticProperties['logs']) -or @($diagnosticProperties['logs']).Count -ne 1) {
                & $offend ("{0}.properties.logs must be an array with exactly one entry." -f $PayloadName)
                break
            }
            if (-not (Test-IsJsonObject -Value $diagnosticProperties['logs'][0])) {
                & $offend ("{0}.properties.logs[0] must be an object." -f $PayloadName)
                break
            }
            $logEntry = Get-Entries -Value $diagnosticProperties['logs'][0]
            if ([string]$logEntry['categoryGroup'] -cne 'allLogs' -or $logEntry['enabled'] -isnot [bool] -or $logEntry['enabled'] -ne $true) {
                & $offend ("{0}.properties.logs[0] must enable the allLogs category group." -f $PayloadName)
            }
        }
        'Microsoft.Authorization/roleDefinitions' {
            if (-not (Test-IsJsonObject -Value $ResourceEntries['properties'])) {
                & $offend ("{0}.properties must be an object." -f $PayloadName)
                break
            }
            $roleProperties = Get-Entries -Value $ResourceEntries['properties']
            if ([string]$roleProperties['roleName'] -cne [string]$ExpectedResource.RoleName) {
                & $offend ("{0}.properties.roleName must equal {1}." -f $PayloadName, [string]$ExpectedResource.RoleName)
            }
            if ([string]$roleProperties['description'] -cne $ExpectedRoleDescription) {
                & $offend ("{0}.properties.description must equal the reviewed role description." -f $PayloadName)
            }
            if ([string]$roleProperties['type'] -cne 'CustomRole') {
                & $offend ("{0}.properties.type must equal CustomRole." -f $PayloadName)
            }
            if (-not (Test-IsJsonArray -Value $roleProperties['permissions']) -or @($roleProperties['permissions']).Count -ne 1 -or -not (Test-IsJsonObject -Value $roleProperties['permissions'][0])) {
                & $offend ("{0}.properties.permissions must be an array with exactly one object." -f $PayloadName)
            }
            else {
                $permission = Get-Entries -Value $roleProperties['permissions'][0]
                if (-not (Test-IsJsonArray -Value $permission['actions']) -or -not (Test-ExactStringSet -Actual $permission['actions'] -Expected $ExpectedRoleActions)) {
                    & $offend ("{0}.properties.permissions[0].actions must exactly match the reviewed actions." -f $PayloadName)
                }
                foreach ($emptyProperty in @('notActions', 'dataActions', 'notDataActions')) {
                    if (-not (Test-IsJsonArray -Value $permission[$emptyProperty]) -or @($permission[$emptyProperty]).Count -ne 0) {
                        & $offend ("{0}.properties.permissions[0].{1} must be an empty array." -f $PayloadName, $emptyProperty)
                    }
                }
            }
            if (-not (Test-IsJsonArray -Value $roleProperties['assignableScopes']) -or -not (Test-ExactStringSet -Actual $roleProperties['assignableScopes'] -Expected @([string]$ExpectedResource.Scope))) {
                & $offend ("{0}.properties.assignableScopes must contain only {1}." -f $PayloadName, [string]$ExpectedResource.Scope)
            }
        }
        'Microsoft.Authorization/roleAssignments' {
            if (-not (Test-IsJsonObject -Value $ResourceEntries['properties'])) {
                & $offend ("{0}.properties must be an object." -f $PayloadName)
                break
            }
            $assignmentProperties = Get-Entries -Value $ResourceEntries['properties']
            if ([string]$assignmentProperties['principalId'] -cne $ExpectedPrincipalId) {
                & $offend ("{0}.properties.principalId must equal the reviewed principal {1}." -f $PayloadName, $ExpectedPrincipalId)
            }
            if ([string]$assignmentProperties['principalType'] -cne 'ServicePrincipal') {
                & $offend ("{0}.properties.principalType must equal ServicePrincipal." -f $PayloadName)
            }
            if ([string]$assignmentProperties['roleDefinitionId'] -cne $ExpectedRoleDefinitionId) {
                & $offend ("{0}.properties.roleDefinitionId must equal {1}." -f $PayloadName, $ExpectedRoleDefinitionId)
            }
        }
    }
}

$resolvedPayloadPath = [System.IO.Path]::GetFullPath($WhatIfPayloadPath)
try {
    $payload = Get-Content -Raw -LiteralPath $resolvedPayloadPath | ConvertFrom-Json
}
catch {
    throw ("What-if payload must contain valid JSON: {0}" -f $_.Exception.Message)
}

if (-not (Test-IsJsonObject -Value $payload)) {
    throw 'What-if payload must be an object.'
}

$payloadEntries = Get-Entries -Value $payload
$offenses = [System.Collections.Generic.List[string]]::new()
if (-not $payloadEntries.Contains('status') -or [string]$payloadEntries['status'] -cne 'Succeeded') {
    $actualStatus = if ($payloadEntries.Contains('status')) { [string]$payloadEntries['status'] } else { '<missing>' }
    Add-Offense -Collection $offenses -Message ("What-if payload status must equal Succeeded; actual={0}." -f (Get-DisplayValue -Value $actualStatus))
}
if ($payloadEntries.Contains('error')) {
    Add-Offense -Collection $offenses -Message 'What-if payload must not contain a top-level error.'
}
if (-not $payloadEntries.Contains('properties') -or -not (Test-IsJsonObject -Value $payloadEntries['properties'])) {
    Add-Offense -Collection $offenses -Message 'What-if payload properties must be an object.'
    throw ($offenses -join ' ')
}

$properties = Get-Entries -Value $payloadEntries['properties']
if (-not $properties.Contains('changes')) {
    Add-Offense -Collection $offenses -Message 'What-if payload properties must contain changes.'
    throw ($offenses -join ' ')
}
if (-not (Test-IsJsonArray -Value $properties['changes'])) {
    Add-Offense -Collection $offenses -Message 'What-if payload properties.changes must be an array.'
    throw ($offenses -join ' ')
}

$changes = @($properties['changes'])
if ($changes.Count -eq 0) {
    Add-Offense -Collection $offenses -Message 'What-if payload properties.changes must contain at least one change.'
}

$diagnostics = @()
if ($properties.Contains('diagnostics')) {
    if (-not (Test-IsJsonArray -Value $properties['diagnostics'])) {
        Add-Offense -Collection $offenses -Message 'What-if payload properties.diagnostics must be an array when present.'
    }
    else {
        $diagnostics = @($properties['diagnostics'])
    }
}

$subscriptionId = 'edb45a24-408d-47c4-bbc7-685b9b3fc017'
$expectedSubscriptionScope = "/subscriptions/$subscriptionId"
$expectedResourceGroupName = 'rg-cal-hr-agentic-bc8rbt-platform'
$expectedResourceGroupId = "$expectedSubscriptionScope/resourceGroups/$expectedResourceGroupName"
$expectedWorkspaceName = 'log-cal-hr-agentic-bc8rbt'
$expectedWorkspaceId = "$expectedResourceGroupId/providers/Microsoft.OperationalInsights/workspaces/$expectedWorkspaceName"
$expectedDiagnosticName = 'activity-log-to-log-analytics'
$expectedDiagnosticId = "$expectedSubscriptionScope/providers/Microsoft.Insights/diagnosticSettings/$expectedDiagnosticName"
$expectedRoleName = 'cal-hr-agentic-bc8rbt-deployment-validation'
$expectedRoleDescription = 'Read-only deployment validation role for reviewed tenant subscription baselines.'
$expectedRoleActions = @(
    '*/read',
    'Microsoft.Resources/deployments/read',
    'Microsoft.Resources/deployments/validate/action',
    'Microsoft.Resources/deployments/whatIf/action'
)
$expectedRoleDefinitionGuid = New-ArmGuid -Values @($expectedSubscriptionScope, $expectedRoleName)
$expectedRoleDefinitionId = "$expectedSubscriptionScope/providers/Microsoft.Authorization/roleDefinitions/$expectedRoleDefinitionGuid"
$principalGuid = [guid]::Empty
if (-not [guid]::TryParse($ExpectedPrincipalObjectId, [ref]$principalGuid)) {
    throw 'ExpectedPrincipalObjectId must be a GUID.'
}
$expectedAssignmentGuid = New-ArmGuid -Values @($expectedSubscriptionScope, $expectedRoleDefinitionGuid, $ExpectedPrincipalObjectId)
$expectedAssignmentId = "$expectedSubscriptionScope/providers/Microsoft.Authorization/roleAssignments/$expectedAssignmentGuid"
$expectedTags = [ordered]@{
    tenantAlias = 'caldova25156897'
    namingRoot = 'cal-hr-agentic-bc8rbt'
    baseline = 'subscription-platform'
}
$expectedResources = @(
    [pscustomobject]@{
        Id = $expectedResourceGroupId
        Type = 'Microsoft.Resources/resourceGroups'
        Name = $expectedResourceGroupName
        Scope = $expectedSubscriptionScope
        Location = 'switzerlandnorth'
        ApiVersion = '2024-11-01'
        RoleName = ''
    },
    [pscustomobject]@{
        Id = $expectedWorkspaceId
        Type = 'Microsoft.OperationalInsights/workspaces'
        Name = $expectedWorkspaceName
        Scope = $expectedResourceGroupId
        Location = 'switzerlandnorth'
        ApiVersion = '2023-09-01'
        RoleName = ''
    },
    [pscustomobject]@{
        Id = $expectedDiagnosticId
        Type = 'Microsoft.Insights/diagnosticSettings'
        Name = $expectedDiagnosticName
        Scope = $expectedSubscriptionScope
        Location = ''
        ApiVersion = '2021-05-01-preview'
        RoleName = ''
    },
    [pscustomobject]@{
        Id = $expectedRoleDefinitionId
        Type = 'Microsoft.Authorization/roleDefinitions'
        Name = $expectedRoleDefinitionGuid
        Scope = $expectedSubscriptionScope
        Location = ''
        ApiVersion = '2022-04-01'
        RoleName = $expectedRoleName
    },
    [pscustomobject]@{
        Id = $expectedAssignmentId
        Type = 'Microsoft.Authorization/roleAssignments'
        Name = $expectedAssignmentGuid
        Scope = $expectedSubscriptionScope
        Location = ''
        ApiVersion = '2022-04-01'
        RoleName = ''
    }
)
$expectedById = @{}
$expectedByType = @{}
foreach ($expectedResource in $expectedResources) {
    $expectedById[[string]$expectedResource.Id] = $expectedResource
    $expectedByType[[string]$expectedResource.Type] = $expectedResource
}

$seenResourceIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$seenExpectedIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$acceptedChangeTypes = @('Create', 'Modify', 'NoChange')
for ($changeIndex = 0; $changeIndex -lt $changes.Count; $changeIndex++) {
    $change = $changes[$changeIndex]
    if (-not (Test-IsJsonObject -Value $change)) {
        Add-Offense -Collection $offenses -Message ("Change entry {0} must be an object." -f $changeIndex)
        continue
    }

    $changeEntries = Get-Entries -Value $change
    $resourceId = if ($changeEntries.Contains('resourceId')) { [string]$changeEntries['resourceId'] } else { '' }
    $changeType = if ($changeEntries.Contains('changeType')) { [string]$changeEntries['changeType'] } else { '' }
    $before = if ($changeEntries.Contains('before')) { $changeEntries['before'] } else { $null }
    $after = if ($changeEntries.Contains('after')) { $changeEntries['after'] } else { $null }
    $beforeIsObject = Test-IsJsonObject -Value $before
    $afterIsObject = Test-IsJsonObject -Value $after
    $activeResource = if ($afterIsObject) { $after } elseif ($beforeIsObject) { $before } else { $null }
    $activeEntries = if ($null -ne $activeResource) { Get-Entries -Value $activeResource } else { [ordered]@{} }
    $resourceType = [string]$activeEntries['type']
    $resourceLocation = [string]$activeEntries['location']
    $resourceScope = Get-ResourceScope -ResourceId $resourceId -ResourceType $resourceType

    if ([string]::IsNullOrWhiteSpace($resourceId)) {
        Add-ResourceOffense -Collection $offenses -ResourceId $resourceId -ResourceType $resourceType -ResourceScope $resourceScope -ResourceLocation $resourceLocation -Message ("Change entry {0} must contain a non-empty resourceId." -f $changeIndex)
        continue
    }
    if (-not $seenResourceIds.Add($resourceId)) {
        Add-ResourceOffense -Collection $offenses -ResourceId $resourceId -ResourceType $resourceType -ResourceScope $resourceScope -ResourceLocation $resourceLocation -Message ("Duplicate resourceId {0}." -f $resourceId)
    }

    if ($changeType -notin $acceptedChangeTypes) {
        Add-ResourceOffense -Collection $offenses -ResourceId $resourceId -ResourceType $resourceType -ResourceScope $resourceScope -ResourceLocation $resourceLocation -Message ("ChangeType {0} is not allowed for {1}." -f (Get-DisplayValue -Value $changeType), $resourceId)
    }
    else {
        if ($changeType -eq 'Create' -and (-not $changeEntries.Contains('before') -or $null -ne $before)) {
            Add-ResourceOffense -Collection $offenses -ResourceId $resourceId -ResourceType $resourceType -ResourceScope $resourceScope -ResourceLocation $resourceLocation -Message 'ChangeType Create before must be null.'
        }
        if ($changeType -in @('Modify', 'NoChange') -and -not $beforeIsObject) {
            Add-ResourceOffense -Collection $offenses -ResourceId $resourceId -ResourceType $resourceType -ResourceScope $resourceScope -ResourceLocation $resourceLocation -Message ("ChangeType {0} before must be an object." -f $changeType)
        }
        if (-not $afterIsObject) {
            Add-ResourceOffense -Collection $offenses -ResourceId $resourceId -ResourceType $resourceType -ResourceScope $resourceScope -ResourceLocation $resourceLocation -Message ("ChangeType {0} after must be an object." -f $changeType)
        }
    }

    if ($resourceType -ceq 'Microsoft.Authorization/policyAssignments') {
        Add-ResourceOffense -Collection $offenses -ResourceId $resourceId -ResourceType $resourceType -ResourceScope $resourceScope -ResourceLocation $resourceLocation -Message ("Policy assignments must remain empty for Tenant 1: {0}." -f $resourceId)
        continue
    }

    $expectedResource = $null
    if ($expectedById.ContainsKey($resourceId)) {
        $expectedResource = $expectedById[$resourceId]
    }
    elseif (-not [string]::IsNullOrWhiteSpace($resourceType) -and $expectedByType.ContainsKey($resourceType)) {
        $expectedResource = $expectedByType[$resourceType]
    }

    if ($null -eq $expectedResource) {
        Add-ResourceOffense -Collection $offenses -ResourceId $resourceId -ResourceType $resourceType -ResourceScope $resourceScope -ResourceLocation $resourceLocation -Message ("Unsupported resource type {0} at {1}." -f (Get-DisplayValue -Value $resourceType), $resourceId)
        continue
    }

    if (-not $seenExpectedIds.Add([string]$expectedResource.Id)) {
        Add-ResourceOffense -Collection $offenses -ResourceId $resourceId -ResourceType $resourceType -ResourceScope $resourceScope -ResourceLocation $resourceLocation -Message ("More than one change targets the expected resource {0}." -f [string]$expectedResource.Id)
    }
    if ($resourceId -cne [string]$expectedResource.Id) {
        Add-ResourceOffense -Collection $offenses -ResourceId $resourceId -ResourceType $resourceType -ResourceScope $resourceScope -ResourceLocation $resourceLocation -Message ("change.resourceId must equal {0}." -f [string]$expectedResource.Id)
    }

    if ($afterIsObject) {
        $afterEntries = Test-ResourceIdentity -Collection $offenses -Resource $after -ExpectedResource $expectedResource -ChangeResourceId $resourceId -PayloadName 'after'
        Test-ExpectedResourceProperties -Collection $offenses -ResourceEntries $afterEntries -ExpectedResource $expectedResource -ExpectedTags $expectedTags -ExpectedRoleActions $expectedRoleActions -ExpectedRoleDescription $expectedRoleDescription -ExpectedRoleDefinitionId $expectedRoleDefinitionId -ExpectedPrincipalId $ExpectedPrincipalObjectId -ExpectedWorkspaceId $expectedWorkspaceId -PayloadName 'after'
    }
    if ($beforeIsObject -and $changeType -in @('Modify', 'NoChange')) {
        $beforeEntries = Test-ResourceIdentity -Collection $offenses -Resource $before -ExpectedResource $expectedResource -ChangeResourceId $resourceId -PayloadName 'before'
        if ($changeType -eq 'NoChange') {
            Test-ExpectedResourceProperties -Collection $offenses -ResourceEntries $beforeEntries -ExpectedResource $expectedResource -ExpectedTags $expectedTags -ExpectedRoleActions $expectedRoleActions -ExpectedRoleDescription $expectedRoleDescription -ExpectedRoleDefinitionId $expectedRoleDefinitionId -ExpectedPrincipalId $ExpectedPrincipalObjectId -ExpectedWorkspaceId $expectedWorkspaceId -PayloadName 'before'
        }
    }
}

if ($changes.Count -ne $expectedResources.Count) {
    Add-Offense -Collection $offenses -Message ("What-if payload must contain exactly {0} changes; actual={1}." -f $expectedResources.Count, $changes.Count)
}
foreach ($expectedResource in $expectedResources) {
    if (-not $seenExpectedIds.Contains([string]$expectedResource.Id)) {
        Add-ResourceOffense -Collection $offenses -ResourceId ([string]$expectedResource.Id) -ResourceType ([string]$expectedResource.Type) -ResourceScope ([string]$expectedResource.Scope) -ResourceLocation ([string]$expectedResource.Location) -Message 'Expected Tenant 1 resource is missing from the what-if changes.'
    }
}

for ($diagnosticIndex = 0; $diagnosticIndex -lt $diagnostics.Count; $diagnosticIndex++) {
    $diagnostic = $diagnostics[$diagnosticIndex]
    if (Test-IsJsonObject -Value $diagnostic) {
        $diagnosticEntries = Get-Entries -Value $diagnostic
        Add-Offense -Collection $offenses -Message ("Diagnostic entry {0} is not allowed: level={1}; code={2}; message={3}." -f $diagnosticIndex, (Get-DisplayValue -Value ([string]$diagnosticEntries['level'])), (Get-DisplayValue -Value ([string]$diagnosticEntries['code'])), (Get-DisplayValue -Value ([string]$diagnosticEntries['message'])))
    }
    else {
        Add-Offense -Collection $offenses -Message ("Diagnostic entry {0} is not allowed and must be an object." -f $diagnosticIndex)
    }
}

if ($offenses.Count -gt 0) {
    throw ($offenses -join ' ')
}

[pscustomobject]@{
    ChangeCount = $changes.Count
    DiagnosticsCount = $diagnostics.Count
    SubscriptionId = $subscriptionId
}