function Get-RunbookObjectPropertyNames {
    param([Parameter(Mandatory)] [object]$InputObject)
    if ($InputObject -is [Collections.IDictionary]) {
        return @($InputObject.Keys | ForEach-Object { [string]$_ })
    }
    @($InputObject.PSObject.Properties | Where-Object MemberType -In NoteProperty, Property | ForEach-Object Name)
}

function Get-RunbookObjectPropertyValue {
    param(
        [Parameter(Mandatory)] [object]$InputObject,
        [Parameter(Mandatory)] [string]$Name
    )
    if ($InputObject -is [Collections.IDictionary]) {
        return $InputObject[$Name]
    }
    return $InputObject.$Name
}

function Assert-RunbookClosedObject {
    param(
        [Parameter(Mandatory)] [object]$InputObject,
        [Parameter(Mandatory)] [string[]]$AllowedProperties,
        [string[]]$RequiredProperties = @(),
        [string]$ErrorMessage = 'Object contains an unrecognized property.'
    )

    $names = @(Get-RunbookObjectPropertyNames -InputObject $InputObject)
    foreach ($name in $names) {
        if ($AllowedProperties -notcontains $name) { throw $ErrorMessage }
    }
    foreach ($name in $RequiredProperties) {
        if ($names -notcontains $name) { throw $ErrorMessage }
    }
}

function Assert-RunbookAuthenticationContext {
    param([Parameter(Mandatory)] [object]$AuthenticationContext)

    $authenticationProperties = @(
        'executionHost', 'mode', 'accountId', 'tenantId', 'subscriptionId',
        'githubHost', 'githubLogin', 'azureDevOpsOrganizationUrl',
        'azureDevOpsActingUserId', 'azureDevOpsProjectId',
        'powerPlatformProfileName', 'powerPlatformEnvironmentId'
    )
    Assert-RunbookClosedObject -InputObject $AuthenticationContext `
        -AllowedProperties $authenticationProperties `
        -RequiredProperties @('executionHost', 'mode') `
        -ErrorMessage 'Execution manifest authentication contains an unrecognized property.'
    foreach ($name in (Get-RunbookObjectPropertyNames -InputObject $AuthenticationContext)) {
        if ($name -match '(?i)(token|password|secret|credential|certificate)') {
            throw 'Execution manifest authentication contains a prohibited property.'
        }
    }
    if ($AuthenticationContext.executionHost -ne 'InteractiveWindows11PowerShell') {
        throw 'Execution manifest authentication host is not supported.'
    }
    $allowedModes = @(
        'NotRequired', 'DeviceCode', 'WebDevice',
        'AzureCliDelegatedContext', 'PacNamedDeviceCodeProfile'
    )
    if ($allowedModes -notcontains [string]$AuthenticationContext.mode) {
        throw 'Execution manifest authentication mode is not supported.'
    }
}

function New-RunbookExecutionManifest {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [guid]$RunId,
        [Parameter(Mandatory)] [ValidateSet('Workstation', 'CloudFoundation', 'CustomerExport')] [string]$Kind,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string]$TargetStableId,
        [Parameter(Mandatory)] [ValidatePattern('^[0-9a-fA-F]{40}$')] [string]$SourceCommit,
        [Parameter(Mandatory)] [ValidatePattern('^[0-9a-fA-F]{64}$')] [string]$AssessmentDigest,
        [Parameter(Mandatory)] [object]$AuthenticationContext,
        [Parameter(Mandatory)] [object[]]$AllowedActions,
        [Parameter(Mandatory)] [object]$ToolVersions,
        [Parameter(Mandatory)] [datetime]$GeneratedAtUtc
    )

    Assert-RunbookAuthenticationContext -AuthenticationContext $AuthenticationContext

    $actionProperties = @(
        'action', 'targetId', 'service', 'method', 'uri', 'bodyDigest',
        'packageSource', 'packageId', 'scope', 'requiredVersion',
        'sourceRelativePath', 'destinationRelativePath', 'replacementRuleId',
        'expectedPostcondition'
    )
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $safeActions = @(
        foreach ($item in $AllowedActions) {
            Assert-RunbookClosedObject -InputObject $item -AllowedProperties $actionProperties `
                -RequiredProperties @('action', 'targetId') `
                -ErrorMessage 'Execution manifest action contains an unrecognized property.'
            $key = ([string]$item.action) + "`0" + ([string]$item.targetId)
            if (-not $seen.Add($key)) {
                throw 'Execution manifest contains a duplicate action and target pair.'
            }
            $safe = [ordered]@{}
            foreach ($property in $actionProperties) {
                if ((Get-RunbookObjectPropertyNames -InputObject $item) -contains $property) {
                    $safe[$property] = Get-RunbookObjectPropertyValue -InputObject $item -Name $property
                }
            }
            [pscustomobject]$safe
        }
    )
    $comparison = [Comparison[object]] {
        param($left, $right)
        $result = [StringComparer]::Ordinal.Compare([string]$left.action, [string]$right.action)
        if ($result -eq 0) {
            $result = [StringComparer]::Ordinal.Compare([string]$left.targetId, [string]$right.targetId)
        }
        $result
    }
    [Array]::Sort($safeActions, $comparison)

    $unsigned = [ordered]@{
        schemaVersion = '1.0'
        runId = $RunId.ToString('D')
        kind = [string]$Kind
        generatedAtUtc = $GeneratedAtUtc.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        sourceCommit = $SourceCommit.ToLowerInvariant()
        assessmentDigest = $AssessmentDigest.ToLowerInvariant()
        authentication = $AuthenticationContext
        target = [ordered]@{
            type = [string]$Kind
            stableId = $TargetStableId
        }
        toolVersions = $ToolVersions
        allowedActions = @($safeActions)
    }
    $digest = Get-RunbookContentDigest -InputObject $unsigned
    $signed = [ordered]@{}
    foreach ($entry in $unsigned.GetEnumerator()) { $signed[$entry.Key] = $entry.Value }
    $signed.digest = $digest
    [pscustomobject]$signed
}
