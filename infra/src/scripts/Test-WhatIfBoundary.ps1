[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$WhatIfPayloadPath,

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
    [object]$CompiledParameters
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

function Get-RequiredCompiledTenantValue {
    param(
        [Parameter(Mandatory)][object]$CompiledTenant,
        [Parameter(Mandatory)][string]$Name
    )

    $entries = Get-Entries -Value $CompiledTenant
    if (-not $entries.Contains($Name) -or
        [string]::IsNullOrWhiteSpace([string]$entries[$Name])) {
        throw "Compiled tenant parameters must contain '$Name'."
    }

    [string]$entries[$Name]
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
    }
}

$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
$modulePath = Join-Path $repositoryRoot 'infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1'
Import-Module $modulePath -Force

$tenantConfiguration = Import-TenantConfiguration `
    -Path ([IO.Path]::GetFullPath($TenantConfigurationPath)) `
    -ValidationStage Discovery `
    -ExpectedPublicTenantKey $PublicTenantKey `
    -RequireLocalUntracked
$compiledDocument = if ($CompiledParameters.PSObject.Properties.Name -contains 'parametersJson') {
    [string]$CompiledParameters.parametersJson | ConvertFrom-Json
}
else {
    $CompiledParameters
}
$compiledEntries = Get-Entries -Value $compiledDocument
if (-not $compiledEntries.Contains('parameters')) {
    throw 'Compiled parameters must contain a parameters object.'
}
$parameterEntries = Get-Entries -Value $compiledEntries['parameters']
if (-not $parameterEntries.Contains('tenant')) {
    throw 'Compiled parameters must contain the tenant parameter.'
}
$tenantParameterEntries = Get-Entries -Value $parameterEntries['tenant']
if (-not $tenantParameterEntries.Contains('value') -or
    -not (Test-IsJsonObject -Value $tenantParameterEntries['value'])) {
    throw 'Compiled tenant parameters must contain an object value.'
}
$compiledTenant = $tenantParameterEntries['value']
$compiledTenantAlias = Get-RequiredCompiledTenantValue -CompiledTenant $compiledTenant -Name 'tenantAlias'
$compiledLocation = Get-RequiredCompiledTenantValue -CompiledTenant $compiledTenant -Name 'location'
$compiledNamingRoot = Get-RequiredCompiledTenantValue -CompiledTenant $compiledTenant -Name 'namingRoot'
if ($compiledTenantAlias -cne [string]$tenantConfiguration.TenantAlias -or
    $compiledLocation -cne [string]$tenantConfiguration.PrimaryLocation -or
    $compiledNamingRoot -cne [string]$tenantConfiguration.NamingRoot) {
    throw 'Compiled tenant parameters do not match the validated local configuration.'
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

$subscriptionId = [string]$tenantConfiguration.SubscriptionId
$expectedSubscriptionScope = "/subscriptions/$subscriptionId"
$expectedResourceGroupName = Get-RequiredCompiledTenantValue -CompiledTenant $compiledTenant -Name 'platformResourceGroupName'
$expectedResourceGroupId = "$expectedSubscriptionScope/resourceGroups/$expectedResourceGroupName"
$expectedWorkspaceName = Get-RequiredCompiledTenantValue -CompiledTenant $compiledTenant -Name 'logAnalyticsWorkspaceName'
$expectedWorkspaceId = "$expectedResourceGroupId/providers/Microsoft.OperationalInsights/workspaces/$expectedWorkspaceName"
$expectedDiagnosticName = 'activity-log-to-log-analytics'
$expectedDiagnosticId = "$expectedSubscriptionScope/providers/Microsoft.Insights/diagnosticSettings/$expectedDiagnosticName"
$expectedTags = [ordered]@{
    tenantAlias = $compiledTenantAlias
    namingRoot = $compiledNamingRoot
    baseline = 'subscription-platform'
}
$expectedResources = @(
    [pscustomobject]@{
        Id = $expectedResourceGroupId
        Type = 'Microsoft.Resources/resourceGroups'
        Name = $expectedResourceGroupName
        Scope = $expectedSubscriptionScope
        Location = $compiledLocation
        ApiVersion = '2024-11-01'
        RoleName = ''
    },
    [pscustomobject]@{
        Id = $expectedWorkspaceId
        Type = 'Microsoft.OperationalInsights/workspaces'
        Name = $expectedWorkspaceName
        Scope = $expectedResourceGroupId
        Location = $compiledLocation
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

    if ($resourceType -in @(
        'Microsoft.Authorization/roleDefinitions',
        'Microsoft.Authorization/roleAssignments'
    ) -or $resourceId -match '(?i)/providers/Microsoft\.Authorization/(?:roleDefinitions|roleAssignments)/') {
        Add-ResourceOffense -Collection $offenses -ResourceId $resourceId -ResourceType $resourceType -ResourceScope $resourceScope -ResourceLocation $resourceLocation -Message 'Authorization role definition and assignment changes are prohibited.'
        continue
    }

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
        Test-ExpectedResourceProperties -Collection $offenses -ResourceEntries $afterEntries -ExpectedResource $expectedResource -ExpectedTags $expectedTags -ExpectedWorkspaceId $expectedWorkspaceId -PayloadName 'after'
    }
    if ($beforeIsObject -and $changeType -in @('Modify', 'NoChange')) {
        $beforeEntries = Test-ResourceIdentity -Collection $offenses -Resource $before -ExpectedResource $expectedResource -ChangeResourceId $resourceId -PayloadName 'before'
        if ($changeType -eq 'NoChange') {
            Test-ExpectedResourceProperties -Collection $offenses -ResourceEntries $beforeEntries -ExpectedResource $expectedResource -ExpectedTags $expectedTags -ExpectedWorkspaceId $expectedWorkspaceId -PayloadName 'before'
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