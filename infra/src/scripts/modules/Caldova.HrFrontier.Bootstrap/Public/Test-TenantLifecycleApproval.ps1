function Test-TenantLifecycleBindingValue {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [AllowNull()][object]$Expected,
        [AllowNull()][object]$Actual
    )

    $expectedEnvelope = [pscustomobject][ordered]@{ value = $Expected }
    $actualEnvelope = [pscustomobject][ordered]@{ value = $Actual }
    $expectedDigest = Get-RunbookContentDigest -InputObject $expectedEnvelope
    $actualDigest = Get-RunbookContentDigest -InputObject $actualEnvelope
    return [string]::Equals($expectedDigest, $actualDigest, [StringComparison]::Ordinal)
}

function Test-TenantLifecycleApproval {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)][object]$Manifest,
        [Parameter(Mandatory)][object]$Approval,
        [Parameter(Mandatory)][object]$CurrentBinding,
        [Parameter(Mandatory)][datetime]$NowUtc
    )

    try {
        Test-TenantLifecycleContract -Kind ExecutionManifest -InputObject $Manifest | Out-Null
        Test-TenantLifecycleContract -Kind Approval -InputObject $Approval | Out-Null
    }
    catch {
        throw [IO.InvalidDataException]::new('TenantLifecycle.Approval.Invalid')
    }

    $calculatedManifestDigest = Get-TenantLifecycleExecutionManifestDigest -Manifest $Manifest
    if (-not [string]::Equals([string]$Manifest.digest, $calculatedManifestDigest, [StringComparison]::Ordinal)) {
        throw [IO.InvalidDataException]::new('TenantLifecycle.Approval.ManifestDigest')
    }
    if (-not [string]::Equals([string]$Approval.executionManifestDigest, [string]$Manifest.digest, [StringComparison]::Ordinal)) {
        throw [IO.InvalidDataException]::new('TenantLifecycle.Approval.Digest')
    }
    if (-not [string]::Equals([string]$Approval.runId, [string]$Manifest.runId, [StringComparison]::Ordinal)) {
        throw [IO.InvalidDataException]::new('TenantLifecycle.Approval.RunId')
    }

    $expectedScope = @($Manifest.actions | ForEach-Object { [string]$_.id })
    $actualScope = @($Approval.scope | ForEach-Object { [string]$_ })
    if ($expectedScope.Count -ne $actualScope.Count) {
        throw [IO.InvalidDataException]::new('TenantLifecycle.Approval.Scope')
    }
    for ($index = 0; $index -lt $expectedScope.Count; $index++) {
        if (-not [string]::Equals($expectedScope[$index], $actualScope[$index], [StringComparison]::Ordinal)) {
            throw [IO.InvalidDataException]::new('TenantLifecycle.Approval.Scope')
        }
    }

    $manifestGenerated = [DateTimeOffset]::Parse(
        [string]$Manifest.generatedAtUtc,
        [Globalization.CultureInfo]::InvariantCulture,
        [Globalization.DateTimeStyles]::AssumeUniversal
    )
    $manifestExpires = [DateTimeOffset]::Parse(
        [string]$Manifest.expiresAtUtc,
        [Globalization.CultureInfo]::InvariantCulture,
        [Globalization.DateTimeStyles]::AssumeUniversal
    )
    $approved = [DateTimeOffset]::Parse(
        [string]$Approval.approvedAtUtc,
        [Globalization.CultureInfo]::InvariantCulture,
        [Globalization.DateTimeStyles]::AssumeUniversal
    )
    $approvalExpires = [DateTimeOffset]::Parse(
        [string]$Approval.expiresAtUtc,
        [Globalization.CultureInfo]::InvariantCulture,
        [Globalization.DateTimeStyles]::AssumeUniversal
    )
    $now = [DateTimeOffset]$NowUtc

    if (($manifestExpires - $manifestGenerated) -gt [TimeSpan]::FromMinutes(30) -or
        ($approvalExpires - $approved) -gt [TimeSpan]::FromMinutes(30) -or
        $approved -lt $manifestGenerated -or
        $approvalExpires -gt $manifestExpires) {
        throw [IO.InvalidDataException]::new('TenantLifecycle.Approval.Expiry')
    }
    if ($now -lt $approved) {
        throw [IO.InvalidDataException]::new('TenantLifecycle.Approval.NotYetValid')
    }
    if ($now -gt $approvalExpires -or $now -gt $manifestExpires) {
        throw [IO.InvalidDataException]::new('TenantLifecycle.Approval.Expired')
    }

    $bindingFields = @(
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
        'sessionId'
    )
    $bindingProperties = @(
        $CurrentBinding.PSObject.Properties |
            Where-Object { $_.MemberType -in @('NoteProperty', 'Property') }
    )
    $bindingNames = @($bindingProperties | ForEach-Object Name)
    if ($bindingProperties.Count -ne $bindingFields.Count) {
        throw [IO.InvalidDataException]::new('TenantLifecycle.Approval.Binding')
    }
    foreach ($field in $bindingFields) {
        if ($bindingNames -cnotcontains $field) {
            throw [IO.InvalidDataException]::new('TenantLifecycle.Approval.Binding')
        }
    }

    foreach ($field in @($bindingFields | Where-Object { $_ -cne 'sessionId' })) {
        $expected = $Manifest.PSObject.Properties[$field].Value
        $actual = $CurrentBinding.PSObject.Properties[$field].Value
        if (-not (Test-TenantLifecycleBindingValue -Expected $expected -Actual $actual)) {
            throw [IO.InvalidDataException]::new("TenantLifecycle.Approval.Drift.$field")
        }
    }
    if (-not [string]::Equals([string]$CurrentBinding.sessionId, [string]$PID, [StringComparison]::Ordinal)) {
        throw [IO.InvalidDataException]::new('TenantLifecycle.Approval.Drift.sessionId')
    }

    return $true
}
