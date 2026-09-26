function Assert-RunbookEvidencePropertyNames {
    param(
        [Parameter(Mandatory)] [object]$InputObject,
        [Parameter(Mandatory)] [string[]]$Allowed,
        [string[]]$Required = @()
    )

    $names = @(Get-RunbookObjectPropertyNames -InputObject $InputObject)
    foreach ($name in $names) {
        if ($name -match '(?i)(token|authorization|cookie|secret|password|credential|private.?key|connection.?string|raw|content|payload)' -or
            $Allowed -notcontains $name) {
            throw 'Input contains a prohibited evidence field.'
        }
    }
    foreach ($name in $Required) {
        if ($names -notcontains $name) { throw 'Input contains a prohibited evidence field.' }
    }
}

function Assert-RunbookDisplaySafeScalar {
    param([AllowNull()] [object]$Value)
    if ($null -eq $Value) { return }

    $allowedTypes = @(
        [string], [char], [bool],
        [byte], [sbyte], [int16], [uint16], [int32], [uint32], [int64], [uint64],
        [single], [double], [decimal],
        [datetime], [datetimeoffset], [guid], [timespan], [version]
    )
    if ($allowedTypes -notcontains $Value.GetType()) {
        throw 'Evidence values must be display-safe scalars.'
    }
    if ($Value -is [string] -and ($Value.Length -gt 2048 -or $Value -match '[\x00-\x08\x0B\x0C\x0E-\x1F]')) {
        throw 'Evidence values must be display-safe scalars.'
    }
}

function ConvertTo-RunbookClosedProjection {
    param(
        [AllowNull()] [object]$InputObject,
        [Parameter(Mandatory)] [string[]]$Allowed,
        [string[]]$Required = @()
    )
    if ($null -eq $InputObject) { return $null }
    Assert-RunbookEvidencePropertyNames -InputObject $InputObject -Allowed $Allowed -Required $Required
    $projected = [ordered]@{}
    foreach ($name in $Allowed) {
        if ((Get-RunbookObjectPropertyNames -InputObject $InputObject) -contains $name) {
            Assert-RunbookDisplaySafeScalar -Value $InputObject.$name
            $projected[$name] = $InputObject.$name
        }
    }
    [pscustomobject]$projected
}

function ConvertTo-RunbookEvidenceRecord {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [guid]$RunId,
        [Parameter(Mandatory)] [datetime]$GeneratedAtUtc,
        [Parameter(Mandatory)] [ValidatePattern('^[0-9a-fA-F]{40}$')] [string]$SourceCommit,
        [Parameter(Mandatory)] [ValidatePattern('^[0-9a-fA-F]{64}$')] [string]$AssessmentDigest,
        [ValidatePattern('^[0-9a-fA-F]{64}$')] [string]$PlanDigest,
        [ValidatePattern('^[0-9a-fA-F]{64}$')] [string]$ManifestDigest,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string]$OperatorId,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string]$Operation,
        [Parameter(Mandatory)] [ValidateSet('NoChange', 'Create', 'Update', 'Manual', 'Blocked', 'Refused')] [string]$Classification,
        [Parameter(Mandatory)] [ValidateSet('Planned', 'Applied', 'Verified', 'Failed', 'Refused', 'Manual')] [string]$Status,
        [Parameter(Mandatory)] [ValidateSet('NotApplicable', 'Approved', 'Declined', 'WhatIf')] [string]$ShouldProcessDecision,
        [string]$TargetId,
        [object]$ToolVersions,
        [object]$ReadBack,
        [object]$FinalContext,
        [object[]]$ManualItems,
        [object[]]$RecoveryItems,
        [string]$ErrorCategory
    )

    foreach ($value in @($OperatorId, $Operation, $TargetId, $ErrorCategory)) {
        Assert-RunbookDisplaySafeScalar -Value $value
    }

    $safeToolVersions = $null
    if ($null -ne $ToolVersions) {
        $safeToolVersions = [ordered]@{}
        foreach ($name in (Get-RunbookObjectPropertyNames -InputObject $ToolVersions)) {
            if ($name -match '(?i)(token|authorization|cookie|secret|password|credential|private.?key|connection.?string|raw|content|payload)') {
                throw 'Input contains a prohibited evidence field.'
            }
            $value = Get-RunbookObjectPropertyValue -InputObject $ToolVersions -Name $name
            Assert-RunbookDisplaySafeScalar -Value $value
            $safeToolVersions[$name] = $value
        }
    }

    $readBackAllowed = @(
        'service', 'targetId', 'status', 'expectedPostcondition', 'version',
        'path', 'exitCode', 'restartRequired', 'resourceId', 'objectId', 'appId',
        'projectId', 'repositoryId', 'rulesetId', 'deploymentId', 'deploymentName',
        'projectName', 'processId', 'displayName', 'organizationUrl',
        'visibility', 'provisioningState', 'bodyDigest', 'symmetricAuthCount',
        'asymmetricAuthCount', 'state', 'resourceIds'
    )
    $safeReadBack = $null
    if ($null -ne $ReadBack) {
        $safeReadBack = @(
            foreach ($record in @($ReadBack)) {
                Assert-RunbookEvidencePropertyNames -InputObject $record -Allowed $readBackAllowed
                $safe = [ordered]@{}
                foreach ($name in $readBackAllowed) {
                    if ((Get-RunbookObjectPropertyNames -InputObject $record) -notcontains $name) { continue }
                    if ($name -eq 'resourceIds') {
                        if ($record.$name -isnot [array]) {
                            throw 'Evidence resourceIds must be a flat array.'
                        }
                        $safe[$name] = @(
                            foreach ($id in @($record.$name)) {
                                if ($id -isnot [string]) {
                                    throw 'Evidence resourceIds must be a flat array.'
                                }
                                Assert-RunbookDisplaySafeScalar -Value $id
                                [string]$id
                            }
                        )
                    }
                    else {
                        Assert-RunbookDisplaySafeScalar -Value $record.$name
                        $safe[$name] = $record.$name
                    }
                }
                [pscustomobject]$safe
            }
        )
        if ($ReadBack -isnot [array] -and $safeReadBack.Count -eq 1) {
            $safeReadBack = $safeReadBack[0]
        }
    }

    $finalAllowed = @(
        'executionHost', 'principalId', 'accountId', 'tenantId', 'subscriptionId',
        'githubHost', 'githubLogin', 'githubRepositoryId', 'azureDevOpsOrganizationUrl',
        'azureDevOpsActingUserId', 'azureDevOpsProjectId', 'powerPlatformProfileName',
        'powerPlatformEnvironmentId', 'status', 'stages'
    )
    $safeFinalContext = $null
    if ($null -ne $FinalContext) {
        Assert-RunbookEvidencePropertyNames -InputObject $FinalContext -Allowed $finalAllowed
        $safeFinalContext = [ordered]@{}
        foreach ($name in $finalAllowed | Where-Object { $_ -ne 'stages' }) {
            if ((Get-RunbookObjectPropertyNames -InputObject $FinalContext) -contains $name) {
                Assert-RunbookDisplaySafeScalar -Value $FinalContext.$name
                $safeFinalContext[$name] = $FinalContext.$name
            }
        }
        if ((Get-RunbookObjectPropertyNames -InputObject $FinalContext) -contains 'stages') {
            if ($FinalContext.stages -isnot [array]) {
                throw 'Evidence stages must be an array.'
            }
            $stageFields = @(
                'stage', 'powerPlatformProfileName', 'powerPlatformEnvironmentId',
                'powerPlatformEnvironmentUrl', 'sharePointSiteId', 'sharePointWebUrl'
            )
            $safeFinalContext.stages = @(
                foreach ($stage in @($FinalContext.stages)) {
                    ConvertTo-RunbookClosedProjection -InputObject $stage -Allowed $stageFields -Required $stageFields
                }
            )
        }
        $safeFinalContext = [pscustomobject]$safeFinalContext
    }

    $manualFields = @('service', 'targetId', 'condition', 'owner', 'diagnostic', 'recovery')
    $safeManualItems = @(
        foreach ($item in @($ManualItems)) {
            if ($null -eq $item) { continue }
            ConvertTo-RunbookClosedProjection -InputObject $item -Allowed $manualFields -Required $manualFields
        }
    )
    $recoveryFields = @(
        'service', 'targetId', 'lastProvenState', 'safeDiagnostic', 'owner',
        'nextAction', 'requiresNewPlan', 'requiresNewApproval'
    )
    $safeRecoveryItems = @(
        foreach ($item in @($RecoveryItems)) {
            if ($null -eq $item) { continue }
            $safe = ConvertTo-RunbookClosedProjection -InputObject $item -Allowed $recoveryFields -Required $recoveryFields
            if ($safe.requiresNewPlan -isnot [bool] -or $safe.requiresNewApproval -isnot [bool] -or
                -not $safe.requiresNewPlan -or -not $safe.requiresNewApproval) {
                throw 'Recovery evidence requires a new plan and a new approval.'
            }
            $safe
        }
    )

    [pscustomobject][ordered]@{
        schemaVersion = '1.0'
        runId = $RunId.ToString('D')
        generatedAtUtc = $GeneratedAtUtc.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        sourceCommit = $SourceCommit.ToLowerInvariant()
        assessmentDigest = $AssessmentDigest.ToLowerInvariant()
        planDigest = $PlanDigest
        manifestDigest = $ManifestDigest
        operatorId = $OperatorId
        operation = $Operation
        classification = [string]$Classification
        status = [string]$Status
        shouldProcessDecision = [string]$ShouldProcessDecision
        targetId = $TargetId
        toolVersions = $safeToolVersions
        readBack = $safeReadBack
        finalContext = $safeFinalContext
        manualItems = @($safeManualItems)
        recoveryItems = @($safeRecoveryItems)
        errorCategory = $ErrorCategory
    }
}
