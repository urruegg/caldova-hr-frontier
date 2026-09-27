function Test-RunbookExecutionManifest {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)] [object]$Manifest,
        [Parameter(Mandatory)] [ValidatePattern('^[0-9a-fA-F]{64}$')] [string]$ApprovedDigest,
        [Parameter(Mandatory)] [ValidatePattern('^[0-9a-fA-F]{40}$')] [string]$CurrentSourceCommit,
        [Parameter(Mandatory)] [ValidatePattern('^[0-9a-fA-F]{64}$')] [string]$CurrentAssessmentDigest,
        [Parameter(Mandatory)] [object]$CurrentAuthenticationContext,
        [Parameter(Mandatory)] [string[]]$AllowedActionNames,
        [datetime]$NowUtc = [datetime]::UtcNow,
        [timespan]$MaximumAge = ([timespan]::FromMinutes(30))
    )

    $rootProperties = @(
        'schemaVersion', 'runId', 'kind', 'generatedAtUtc', 'sourceCommit',
        'assessmentDigest', 'authentication', 'target', 'toolVersions',
        'allowedActions', 'digest'
    )
    try {
        Assert-RunbookClosedObject -InputObject $Manifest -AllowedProperties $rootProperties `
            -RequiredProperties $rootProperties `
            -ErrorMessage 'Execution manifest contains an unrecognized property.'
    }
    catch {
        throw 'Execution manifest contains an unrecognized property.'
    }
    if ($Manifest.schemaVersion -ne '1.0') {
        throw 'Execution manifest schema is not supported.'
    }
    if (@('Workstation', 'CloudFoundation', 'CustomerExport') -notcontains [string]$Manifest.kind -or
        -not [string]::Equals([string]$Manifest.target.type, [string]$Manifest.kind, [StringComparison]::Ordinal) -or
        [string]::IsNullOrWhiteSpace([string]$Manifest.target.stableId)) {
        throw 'Execution manifest contains an unrecognized property.'
    }

    Assert-RunbookClosedObject -InputObject $Manifest.target `
        -AllowedProperties @('type', 'stableId') -RequiredProperties @('type', 'stableId') `
        -ErrorMessage 'Execution manifest contains an unrecognized property.'
    Assert-RunbookAuthenticationContext -AuthenticationContext $Manifest.authentication
    $actionProperties = @(
        'action', 'targetId', 'service', 'method', 'uri', 'bodyDigest',
        'packageSource', 'packageId', 'scope', 'requiredVersion',
        'sourceRelativePath', 'destinationRelativePath', 'replacementRuleId',
        'expectedPostcondition'
    )
    $seenActions = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($action in @($Manifest.allowedActions)) {
        Assert-RunbookClosedObject -InputObject $action -AllowedProperties $actionProperties `
            -RequiredProperties @('action', 'targetId') `
            -ErrorMessage 'Execution manifest contains an unrecognized property.'
        $actionKey = ([string]$action.action) + "`0" + ([string]$action.targetId)
        if (-not $seenActions.Add($actionKey)) {
            throw 'Execution manifest contains an unrecognized property.'
        }
    }

    $unsigned = [ordered]@{}
    foreach ($property in $rootProperties | Where-Object { $_ -ne 'digest' }) {
        $unsigned[$property] = $Manifest.$property
    }
    $computedDigest = Get-RunbookContentDigest -InputObject $unsigned
    if (-not [string]::Equals($computedDigest, [string]$Manifest.digest, [StringComparison]::Ordinal)) {
        throw 'Execution manifest digest does not match its content.'
    }
    if (-not [string]::Equals([string]$ApprovedDigest, [string]$Manifest.digest, [StringComparison]::Ordinal)) {
        throw 'Approved digest does not match the execution manifest.'
    }
    if (-not [string]::Equals($CurrentSourceCommit.ToLowerInvariant(), [string]$Manifest.sourceCommit, [StringComparison]::Ordinal)) {
        throw 'Execution manifest source commit is stale.'
    }
    if (-not [string]::Equals($CurrentAssessmentDigest.ToLowerInvariant(), [string]$Manifest.assessmentDigest, [StringComparison]::Ordinal)) {
        throw 'Execution manifest assessment is stale.'
    }
    if (-not [string]::Equals(
        (Get-RunbookContentDigest -InputObject $CurrentAuthenticationContext),
        (Get-RunbookContentDigest -InputObject $Manifest.authentication),
        [StringComparison]::Ordinal
    )) {
        throw 'Execution manifest authentication context does not match read-back.'
    }

    $generated = [datetime]::Parse(
        [string]$Manifest.generatedAtUtc,
        [Globalization.CultureInfo]::InvariantCulture,
        [Globalization.DateTimeStyles]::AssumeUniversal
    ).ToUniversalTime()
    $now = $NowUtc.ToUniversalTime()
    if ($generated -gt $now.AddMinutes(2) -or ($now - $generated) -gt $MaximumAge) {
        throw 'Execution manifest has expired.'
    }
    foreach ($action in @($Manifest.allowedActions)) {
        if ($AllowedActionNames -notcontains [string]$action.action) {
            throw 'Execution manifest contains an unallowlisted action.'
        }
    }
    return $true
}
