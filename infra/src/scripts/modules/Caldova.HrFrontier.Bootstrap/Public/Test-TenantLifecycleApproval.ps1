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

function Test-TenantLifecyclePassiveBindingValue {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [AllowNull()][object]$Value,
        [ValidateRange(0, 30)][int]$Depth = 0
    )

    if ($Depth -ge 30) {
        return $false
    }
    if ($null -eq $Value -or
        $Value -is [string] -or
        $Value.GetType().IsPrimitive -or
        $Value -is [decimal] -or
        $Value -is [guid]) {
        return $true
    }
    if ($Value -is [System.Array]) {
        foreach ($item in @($Value)) {
            if (-not (Test-TenantLifecyclePassiveBindingValue `
                    -Value $item `
                    -Depth ($Depth + 1))) {
                return $false
            }
        }
        return $true
    }
    if ($Value -is [Collections.IDictionary] -or
        $Value -is [Collections.IEnumerable]) {
        return $false
    }

    $properties = @($Value.PSObject.Properties)
    $names = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::Ordinal
    )
    foreach ($property in $properties) {
        if ($property.MemberType -ne 'NoteProperty' -or
            -not $property.IsGettable -or
            -not $names.Add($property.Name)) {
            return $false
        }
    }
    foreach ($property in $properties) {
        if (-not (Test-TenantLifecyclePassiveBindingValue `
                -Value $property.Value `
                -Depth ($Depth + 1))) {
            return $false
        }
    }
    return $true
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
        $approvalProperties = @($Approval.PSObject.Properties)
        foreach ($property in $approvalProperties) {
            if ($property.MemberType -ne 'NoteProperty' -or
                -not $property.IsGettable) {
                throw [IO.InvalidDataException]::new()
            }
        }
        $statusProperty = $Approval.PSObject.Properties['status']
        if ($null -eq $statusProperty -or
            $statusProperty.MemberType -ne 'NoteProperty' -or
            -not [string]::Equals(
                [string]$statusProperty.Value,
                'Approved',
                [StringComparison]::Ordinal
            )) {
            throw [IO.InvalidDataException]::new('TenantLifecycle.Approval.Status')
        }
    }
    catch {
        throw [IO.InvalidDataException]::new('TenantLifecycle.Approval.Status')
    }

    try {
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
    }
    catch {
        throw [IO.InvalidDataException]::new('TenantLifecycle.Approval.Invalid')
    }
    if ($approvalExpires -le $approved) {
        throw [IO.InvalidDataException]::new('TenantLifecycle.Approval.Expiry')
    }

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
    if ($now -ge $approvalExpires -or $now -ge $manifestExpires) {
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
        'selectedStages',
        'prerequisiteResults',
        'machine',
        'operator',
        'toolIdentities',
        'providerContexts',
        'prerequisites',
        'actions',
        'sessionId'
    )
    $bindingProperties = @($CurrentBinding.PSObject.Properties)
    $bindingNames = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::Ordinal
    )
    if ($bindingProperties.Count -ne $bindingFields.Count) {
        throw [IO.InvalidDataException]::new('TenantLifecycle.Approval.Binding')
    }
    foreach ($property in $bindingProperties) {
        if ($property.MemberType -ne 'NoteProperty' -or
            -not $property.IsGettable -or
            -not $bindingNames.Add($property.Name)) {
            throw [IO.InvalidDataException]::new(
                'TenantLifecycle.Approval.Binding'
            )
        }
    }
    foreach ($field in $bindingFields) {
        if (-not $bindingNames.Contains($field)) {
            throw [IO.InvalidDataException]::new('TenantLifecycle.Approval.Binding')
        }
    }

    if (-not (Test-TenantLifecyclePassiveBindingValue `
            -Value $CurrentBinding)) {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.Approval.Binding'
        )
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
