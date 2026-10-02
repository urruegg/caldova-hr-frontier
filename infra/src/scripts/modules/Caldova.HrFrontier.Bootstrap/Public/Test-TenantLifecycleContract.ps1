function Assert-TenantLifecycleCondition {
    [CmdletBinding()]
    param([Parameter(Mandatory)][bool]$Condition)

    if (-not $Condition) {
        throw [IO.InvalidDataException]::new('Invalid tenant lifecycle contract.')
    }
}

function Assert-TenantLifecycleProperties {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowNull()][object]$InputObject,
        [Parameter(Mandatory)][string[]]$Fields
    )

    Assert-TenantLifecycleCondition ($null -ne $InputObject)
    Assert-TenantLifecycleCondition (-not ($InputObject -is [string]))
    Assert-TenantLifecycleCondition (-not ($InputObject -is [System.Array]))
    Assert-TenantLifecycleCondition (-not ($InputObject -is [System.Collections.IDictionary]))

    $properties = @(
        $InputObject.PSObject.Properties |
            Where-Object { $_.MemberType -in @('NoteProperty', 'Property', 'AliasProperty') }
    )
    Assert-TenantLifecycleCondition ($properties.Count -eq $Fields.Count)

    $actual = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($property in $properties) {
        [void]$actual.Add($property.Name)
    }
    foreach ($field in $Fields) {
        Assert-TenantLifecycleCondition ($actual.Contains($field))
    }
}

function Assert-TenantLifecycleString {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowNull()][object]$Value,
        [Parameter(Mandatory)][string]$Pattern,
        [int]$MaximumLength = 2048
    )

    Assert-TenantLifecycleCondition ($Value -is [string])
    Assert-TenantLifecycleCondition ($Value.Length -gt 0)
    Assert-TenantLifecycleCondition ($Value.Length -le $MaximumLength)
    Assert-TenantLifecycleCondition ([regex]::IsMatch($Value, $Pattern, [Text.RegularExpressions.RegexOptions]::CultureInvariant))
}

function Assert-TenantLifecycleName {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowNull()][object]$Value)

    Assert-TenantLifecycleString -Value $Value -Pattern '^[A-Za-z0-9][A-Za-z0-9._:-]*$' -MaximumLength 128
}

function Assert-TenantLifecycleStableId {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowNull()][object]$Value)

    Assert-TenantLifecycleCondition ($Value -is [string])
    Assert-TenantLifecycleCondition ($Value.Length -gt 0)
    Assert-TenantLifecycleCondition ($Value.Length -le 2048)
    Assert-TenantLifecycleCondition (-not [regex]::IsMatch($Value, '[\x00-\x1f]'))
}

function Assert-TenantLifecycleDigest {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowNull()][object]$Value)

    Assert-TenantLifecycleString -Value $Value -Pattern '^[0-9a-f]{64}$' -MaximumLength 64
}

function Assert-TenantLifecycleTimestamp {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowNull()][object]$Value)

    if ($Value -is [datetime]) {
        Assert-TenantLifecycleCondition ($Value.Kind -eq [DateTimeKind]::Utc)
        return
    }
    if ($Value -is [DateTimeOffset]) {
        Assert-TenantLifecycleCondition ($Value.Offset -eq [TimeSpan]::Zero)
        return
    }
    Assert-TenantLifecycleCondition ($Value -is [string])
    Assert-TenantLifecycleCondition ($Value -match 'Z$')
    $parsed = [DateTimeOffset]::MinValue
    $valid = [DateTimeOffset]::TryParse(
        $Value,
        [Globalization.CultureInfo]::InvariantCulture,
        [Globalization.DateTimeStyles]::RoundtripKind,
        [ref]$parsed
    )
    Assert-TenantLifecycleCondition $valid
}

function Assert-TenantLifecycleArray {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowNull()][object]$Value,
        [int]$MinimumCount = 0
    )

    Assert-TenantLifecycleCondition ($Value -is [System.Array])
    Assert-TenantLifecycleCondition (@($Value).Count -ge $MinimumCount)
}

function Assert-TenantLifecycleUniqueValues {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object[]]$Values,
        [Parameter(Mandatory)][string]$PropertyName
    )

    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($value in $Values) {
        $property = $value.PSObject.Properties[$PropertyName]
        Assert-TenantLifecycleCondition ($null -ne $property)
        Assert-TenantLifecycleCondition ($property.Value -is [string])
        Assert-TenantLifecycleCondition ($seen.Add($property.Value))
    }
}

function Assert-TenantLifecycleStringArray {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowNull()][object]$Value,
        [int]$MinimumCount = 0,
        [switch]$NamesOnly
    )

    Assert-TenantLifecycleArray -Value $Value -MinimumCount $MinimumCount
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($item in @($Value)) {
        if ($NamesOnly) {
            Assert-TenantLifecycleName $item
        }
        else {
            Assert-TenantLifecycleCondition ($item -is [string])
            Assert-TenantLifecycleCondition ($item.Length -gt 0)
            Assert-TenantLifecycleCondition ($item.Length -le 512)
        }
        Assert-TenantLifecycleCondition ($seen.Add($item))
    }
}

function Assert-TenantLifecycleClassification {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowNull()][object]$Value)

    $classifications = @('NoChange', 'Create', 'Update', 'Manual', 'Blocked', 'Refused')
    Assert-TenantLifecycleCondition ($Value -is [string])
    Assert-TenantLifecycleCondition ($classifications -ccontains $Value)
}

function Assert-TenantLifecycleMachine {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowNull()][object]$Value)

    Assert-TenantLifecycleProperties -InputObject $Value -Fields @('machineId', 'platform')
    Assert-TenantLifecycleName $Value.machineId
    Assert-TenantLifecycleString -Value $Value.platform -Pattern '^.{1,128}$' -MaximumLength 128
}

function Assert-TenantLifecycleOperator {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowNull()][object]$Value)

    Assert-TenantLifecycleProperties -InputObject $Value -Fields @('operatorId', 'role')
    Assert-TenantLifecycleName $Value.operatorId
    Assert-TenantLifecycleName $Value.role
}

function Assert-TenantLifecycleToolIdentities {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowNull()][object]$Value)

    Assert-TenantLifecycleArray -Value $Value -MinimumCount 1
    foreach ($tool in @($Value)) {
        Assert-TenantLifecycleProperties -InputObject $tool -Fields @('id', 'version', 'digest')
        Assert-TenantLifecycleName $tool.id
        Assert-TenantLifecycleString -Value $tool.version -Pattern '^.{1,128}$' -MaximumLength 128
        Assert-TenantLifecycleDigest $tool.digest
    }
    Assert-TenantLifecycleUniqueValues -Values @($Value) -PropertyName 'id'
}

function Assert-TenantLifecycleProviderContexts {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowNull()][object]$Value)

    Assert-TenantLifecycleArray -Value $Value
    foreach ($context in @($Value)) {
        Assert-TenantLifecycleProperties -InputObject $context -Fields @('provider', 'contextId', 'status', 'digest')
        Assert-TenantLifecycleName $context.provider
        Assert-TenantLifecycleStableId $context.contextId
        Assert-TenantLifecycleName $context.status
        Assert-TenantLifecycleDigest $context.digest
    }
    Assert-TenantLifecycleUniqueValues -Values @($Value) -PropertyName 'contextId'
}

function Assert-TenantLifecyclePrerequisites {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowNull()][object]$Value)

    Assert-TenantLifecycleArray -Value $Value
    foreach ($prerequisite in @($Value)) {
        Assert-TenantLifecycleProperties -InputObject $prerequisite -Fields @('id', 'status', 'inputDigest', 'evidenceDigest')
        Assert-TenantLifecycleName $prerequisite.id
        Assert-TenantLifecycleName $prerequisite.status
        Assert-TenantLifecycleDigest $prerequisite.inputDigest
        Assert-TenantLifecycleDigest $prerequisite.evidenceDigest
    }
    Assert-TenantLifecycleUniqueValues -Values @($Value) -PropertyName 'id'
}

function Assert-TenantLifecycleAssessmentComponents {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowNull()][object]$Value)

    Assert-TenantLifecycleArray -Value $Value -MinimumCount 1
    foreach ($component in @($Value)) {
        Assert-TenantLifecycleProperties -InputObject $component -Fields @(
            'id',
            'provider',
            'resourceType',
            'classification',
            'targetStableId',
            'ownedPropertiesDigest',
            'status'
        )
        Assert-TenantLifecycleName $component.id
        Assert-TenantLifecycleName $component.provider
        Assert-TenantLifecycleName $component.resourceType
        Assert-TenantLifecycleClassification $component.classification
        Assert-TenantLifecycleStableId $component.targetStableId
        Assert-TenantLifecycleDigest $component.ownedPropertiesDigest
        Assert-TenantLifecycleName $component.status
    }
    Assert-TenantLifecycleUniqueValues -Values @($Value) -PropertyName 'id'
    Assert-TenantLifecycleUniqueValues -Values @($Value) -PropertyName 'targetStableId'
}

function Assert-TenantLifecycleActions {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowNull()][object]$Value)

    Assert-TenantLifecycleArray -Value $Value -MinimumCount 1
    foreach ($action in @($Value)) {
        Assert-TenantLifecycleProperties -InputObject $action -Fields @(
            'id',
            'provider',
            'classification',
            'targetStableId',
            'absencePredicate',
            'desiredPropertiesDigest',
            'preconditionDigest',
            'prerequisiteActionIds',
            'adapter',
            'shouldProcessTarget',
            'expectedPostcondition',
            'recovery',
            'evidenceProjection'
        )
        Assert-TenantLifecycleName $action.id
        Assert-TenantLifecycleName $action.provider
        Assert-TenantLifecycleClassification $action.classification
        if ($null -ne $action.targetStableId) {
            Assert-TenantLifecycleStableId $action.targetStableId
        }
        Assert-TenantLifecycleString -Value $action.absencePredicate -Pattern '^.{1,512}$' -MaximumLength 512
        Assert-TenantLifecycleDigest $action.desiredPropertiesDigest
        Assert-TenantLifecycleDigest $action.preconditionDigest
        Assert-TenantLifecycleStringArray -Value $action.prerequisiteActionIds -NamesOnly
        Assert-TenantLifecycleName $action.adapter
        Assert-TenantLifecycleString -Value $action.shouldProcessTarget -Pattern '^.{1,512}$' -MaximumLength 512
        Assert-TenantLifecycleString -Value $action.expectedPostcondition -Pattern '^.{1,512}$' -MaximumLength 512
        Assert-TenantLifecycleString -Value $action.recovery -Pattern '^.{1,512}$' -MaximumLength 512
        Assert-TenantLifecycleStringArray -Value $action.evidenceProjection -MinimumCount 1 -NamesOnly
    }
    Assert-TenantLifecycleUniqueValues -Values @($Value) -PropertyName 'id'
}

function Assert-TenantLifecycleStateResources {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowNull()][object]$Value)

    Assert-TenantLifecycleArray -Value $Value
    foreach ($resource in @($Value)) {
        Assert-TenantLifecycleProperties -InputObject $resource -Fields @(
            'provider',
            'resourceType',
            'logicalName',
            'stableId',
            'lastVerifiedAtUtc',
            'ownedPropertiesDigest'
        )
        Assert-TenantLifecycleName $resource.provider
        Assert-TenantLifecycleName $resource.resourceType
        Assert-TenantLifecycleName $resource.logicalName
        Assert-TenantLifecycleStableId $resource.stableId
        Assert-TenantLifecycleTimestamp $resource.lastVerifiedAtUtc
        Assert-TenantLifecycleDigest $resource.ownedPropertiesDigest
    }
    Assert-TenantLifecycleUniqueValues -Values @($Value) -PropertyName 'logicalName'
    Assert-TenantLifecycleUniqueValues -Values @($Value) -PropertyName 'stableId'
}

function Assert-TenantLifecycleReadBackComponents {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowNull()][object]$Value)

    Assert-TenantLifecycleArray -Value $Value
    foreach ($component in @($Value)) {
        Assert-TenantLifecycleProperties -InputObject $component -Fields @(
            'id',
            'provider',
            'stableId',
            'ownedPropertiesDigest',
            'status'
        )
        Assert-TenantLifecycleName $component.id
        Assert-TenantLifecycleName $component.provider
        Assert-TenantLifecycleStableId $component.stableId
        Assert-TenantLifecycleDigest $component.ownedPropertiesDigest
        Assert-TenantLifecycleName $component.status
    }
    Assert-TenantLifecycleUniqueValues -Values @($Value) -PropertyName 'id'
    Assert-TenantLifecycleUniqueValues -Values @($Value) -PropertyName 'stableId'
}

function Assert-TenantLifecycleCounts {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowNull()][object]$Value)

    $fields = @('NoChange', 'Create', 'Update', 'Manual', 'Blocked', 'Refused')
    Assert-TenantLifecycleProperties -InputObject $Value -Fields $fields
    foreach ($field in $fields) {
        $count = $Value.PSObject.Properties[$field].Value
        Assert-TenantLifecycleCondition ($count -is [int] -or $count -is [long])
        Assert-TenantLifecycleCondition ($count -ge 0)
    }
}

function Assert-TenantLifecycleSummaryActions {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowNull()][object]$Value)

    Assert-TenantLifecycleArray -Value $Value
    foreach ($action in @($Value)) {
        Assert-TenantLifecycleProperties -InputObject $action -Fields @(
            'id',
            'classification',
            'status',
            'evidenceRelativePath'
        )
        Assert-TenantLifecycleName $action.id
        Assert-TenantLifecycleClassification $action.classification
        Assert-TenantLifecycleName $action.status
        Assert-TenantLifecycleString `
            -Value $action.evidenceRelativePath `
            -Pattern '^actions/[A-Za-z0-9][A-Za-z0-9._:-]*\.json$' `
            -MaximumLength 256
    }
    Assert-TenantLifecycleUniqueValues -Values @($Value) -PropertyName 'id'
}

function Test-TenantLifecycleContract {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Assessment', 'ExecutionManifest', 'Approval', 'ActionEvidence', 'State', 'ReadBack', 'Summary')]
        [string]$Kind,

        [Parameter(Mandatory)]
        [object]$InputObject
    )

    try {
        switch ($Kind) {
            'Assessment' {
                Assert-TenantLifecycleProperties -InputObject $InputObject -Fields @(
                    'schemaVersion',
                    'runId',
                    'kind',
                    'generatedAtUtc',
                    'sourceCommit',
                    'machine',
                    'publicTenantKey',
                    'intentDigest',
                    'stateDigest',
                    'toolIdentities',
                    'providerContexts',
                    'components',
                    'prerequisites',
                    'digest'
                )
                Assert-TenantLifecycleCondition ($InputObject.schemaVersion -ceq '1.0')
                Assert-TenantLifecycleString -Value $InputObject.runId -Pattern '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' -MaximumLength 36
                Assert-TenantLifecycleName $InputObject.kind
                Assert-TenantLifecycleTimestamp $InputObject.generatedAtUtc
                Assert-TenantLifecycleString -Value $InputObject.sourceCommit -Pattern '^[0-9a-f]{40}$' -MaximumLength 40
                Assert-TenantLifecycleMachine $InputObject.machine
                Assert-TenantLifecycleString -Value $InputObject.publicTenantKey -Pattern '^tenant[0-9]+$' -MaximumLength 64
                Assert-TenantLifecycleDigest $InputObject.intentDigest
                Assert-TenantLifecycleDigest $InputObject.stateDigest
                Assert-TenantLifecycleToolIdentities $InputObject.toolIdentities
                Assert-TenantLifecycleProviderContexts $InputObject.providerContexts
                Assert-TenantLifecycleAssessmentComponents $InputObject.components
                Assert-TenantLifecyclePrerequisites $InputObject.prerequisites
                Assert-TenantLifecycleDigest $InputObject.digest
            }
            'ExecutionManifest' {
                Assert-TenantLifecycleProperties -InputObject $InputObject -Fields @(
                    'schemaVersion',
                    'runId',
                    'generatedAtUtc',
                    'expiresAtUtc',
                    'sourceCommit',
                    'evidenceRoot',
                    'publicTenantKey',
                    'intentDigest',
                    'stateDigest',
                    'machine',
                    'operator',
                    'toolIdentities',
                    'providerContexts',
                    'prerequisites',
                    'actions',
                    'digest'
                )
                Assert-TenantLifecycleCondition ($InputObject.schemaVersion -ceq '1.0')
                Assert-TenantLifecycleString -Value $InputObject.runId -Pattern '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' -MaximumLength 36
                Assert-TenantLifecycleTimestamp $InputObject.generatedAtUtc
                Assert-TenantLifecycleTimestamp $InputObject.expiresAtUtc
                Assert-TenantLifecycleCondition (([DateTimeOffset]$InputObject.expiresAtUtc) -gt ([DateTimeOffset]$InputObject.generatedAtUtc))
                Assert-TenantLifecycleString -Value $InputObject.sourceCommit -Pattern '^[0-9a-f]{40}$' -MaximumLength 40
                Assert-TenantLifecycleStableId $InputObject.evidenceRoot
                Assert-TenantLifecycleString -Value $InputObject.publicTenantKey -Pattern '^tenant[0-9]+$' -MaximumLength 64
                Assert-TenantLifecycleDigest $InputObject.intentDigest
                Assert-TenantLifecycleDigest $InputObject.stateDigest
                Assert-TenantLifecycleMachine $InputObject.machine
                Assert-TenantLifecycleOperator $InputObject.operator
                Assert-TenantLifecycleToolIdentities $InputObject.toolIdentities
                Assert-TenantLifecycleProviderContexts $InputObject.providerContexts
                Assert-TenantLifecyclePrerequisites $InputObject.prerequisites
                Assert-TenantLifecycleActions $InputObject.actions
                Assert-TenantLifecycleDigest $InputObject.digest
            }
            'Approval' {
                Assert-TenantLifecycleProperties -InputObject $InputObject -Fields @(
                    'schemaVersion',
                    'runId',
                    'executionManifestDigest',
                    'approverRole',
                    'approvedAtUtc',
                    'expiresAtUtc',
                    'scope',
                    'status'
                )
                Assert-TenantLifecycleCondition ($InputObject.schemaVersion -ceq '1.0')
                Assert-TenantLifecycleString -Value $InputObject.runId -Pattern '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' -MaximumLength 36
                Assert-TenantLifecycleDigest $InputObject.executionManifestDigest
                Assert-TenantLifecycleName $InputObject.approverRole
                Assert-TenantLifecycleTimestamp $InputObject.approvedAtUtc
                Assert-TenantLifecycleTimestamp $InputObject.expiresAtUtc
                Assert-TenantLifecycleCondition (([DateTimeOffset]$InputObject.expiresAtUtc) -gt ([DateTimeOffset]$InputObject.approvedAtUtc))
                Assert-TenantLifecycleStringArray -Value $InputObject.scope -MinimumCount 1 -NamesOnly
                Assert-TenantLifecycleCondition ($InputObject.status -ceq 'Approved')
            }
            'ActionEvidence' {
                Assert-TenantLifecycleProperties -InputObject $InputObject -Fields @(
                    'schemaVersion',
                    'runId',
                    'actionId',
                    'classification',
                    'startedAtUtc',
                    'completedAtUtc',
                    'preReadDigest',
                    'decision',
                    'postReadDigest',
                    'status',
                    'errorCode',
                    'recovery'
                )
                Assert-TenantLifecycleCondition ($InputObject.schemaVersion -ceq '1.0')
                Assert-TenantLifecycleString -Value $InputObject.runId -Pattern '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' -MaximumLength 36
                Assert-TenantLifecycleName $InputObject.actionId
                Assert-TenantLifecycleClassification $InputObject.classification
                Assert-TenantLifecycleTimestamp $InputObject.startedAtUtc
                Assert-TenantLifecycleTimestamp $InputObject.completedAtUtc
                Assert-TenantLifecycleCondition (([DateTimeOffset]$InputObject.completedAtUtc) -ge ([DateTimeOffset]$InputObject.startedAtUtc))
                Assert-TenantLifecycleDigest $InputObject.preReadDigest
                Assert-TenantLifecycleName $InputObject.decision
                Assert-TenantLifecycleDigest $InputObject.postReadDigest
                Assert-TenantLifecycleName $InputObject.status
                if ($null -ne $InputObject.errorCode) {
                    Assert-TenantLifecycleName $InputObject.errorCode
                }
                Assert-TenantLifecycleString -Value $InputObject.recovery -Pattern '^.{1,512}$' -MaximumLength 512
            }
            'State' {
                Assert-TenantLifecycleProperties -InputObject $InputObject -Fields @(
                    'schemaVersion',
                    'publicTenantKey',
                    'resources'
                )
                Assert-TenantLifecycleCondition ($InputObject.schemaVersion -ceq '1.0')
                Assert-TenantLifecycleString -Value $InputObject.publicTenantKey -Pattern '^tenant[0-9]+$' -MaximumLength 64
                Assert-TenantLifecycleStateResources $InputObject.resources
            }
            'ReadBack' {
                Assert-TenantLifecycleProperties -InputObject $InputObject -Fields @(
                    'schemaVersion',
                    'runId',
                    'generatedAtUtc',
                    'components',
                    'status',
                    'digest'
                )
                Assert-TenantLifecycleCondition ($InputObject.schemaVersion -ceq '1.0')
                Assert-TenantLifecycleString -Value $InputObject.runId -Pattern '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' -MaximumLength 36
                Assert-TenantLifecycleTimestamp $InputObject.generatedAtUtc
                Assert-TenantLifecycleReadBackComponents $InputObject.components
                Assert-TenantLifecycleName $InputObject.status
                Assert-TenantLifecycleDigest $InputObject.digest
            }
            'Summary' {
                Assert-TenantLifecycleProperties -InputObject $InputObject -Fields @(
                    'schemaVersion',
                    'runId',
                    'sourceCommit',
                    'manifestDigest',
                    'startedAtUtc',
                    'completedAtUtc',
                    'status',
                    'counts',
                    'prerequisites',
                    'actions',
                    'nonClaims'
                )
                Assert-TenantLifecycleCondition ($InputObject.schemaVersion -ceq '1.0')
                Assert-TenantLifecycleString -Value $InputObject.runId -Pattern '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' -MaximumLength 36
                Assert-TenantLifecycleString -Value $InputObject.sourceCommit -Pattern '^[0-9a-f]{40}$' -MaximumLength 40
                Assert-TenantLifecycleDigest $InputObject.manifestDigest
                Assert-TenantLifecycleTimestamp $InputObject.startedAtUtc
                Assert-TenantLifecycleTimestamp $InputObject.completedAtUtc
                Assert-TenantLifecycleCondition (([DateTimeOffset]$InputObject.completedAtUtc) -ge ([DateTimeOffset]$InputObject.startedAtUtc))
                Assert-TenantLifecycleName $InputObject.status
                Assert-TenantLifecycleCounts $InputObject.counts
                Assert-TenantLifecyclePrerequisites $InputObject.prerequisites
                Assert-TenantLifecycleSummaryActions $InputObject.actions
                Assert-TenantLifecycleStringArray -Value $InputObject.nonClaims -MinimumCount 1
            }
        }

        $canonicalDigest = Get-RunbookContentDigest -InputObject $InputObject
        Assert-TenantLifecycleDigest $canonicalDigest
        return $true
    }
    catch {
        throw [IO.InvalidDataException]::new("TenantLifecycle.Contract.$Kind")
    }
}
