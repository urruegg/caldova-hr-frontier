function Update-TenantLifecycleState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$State,

        [Parameter(Mandatory)]
        [string]$ReviewedIntentPath,

        [Parameter(Mandatory)]
        [string]$ReviewedIntentComponentName,

        [Parameter(Mandatory)]
        [object]$VerifiedResource,

        [Parameter(Mandatory)]
        [datetime]$NowUtc
    )

    Test-TenantLifecycleContract -Kind State -InputObject $State | Out-Null

    $expectedFields = @(
        'provider',
        'resourceType',
        'logicalName',
        'stableId',
        'ownedPropertiesDigest',
        'exactReadBack'
    )
    $properties = @($VerifiedResource.PSObject.Properties)
    $actualFields = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::Ordinal
    )
    foreach ($property in $properties) {
        if ($property.MemberType -ne 'NoteProperty' -or
            -not $property.IsGettable -or
            -not $actualFields.Add($property.Name)) {
            throw [IO.InvalidDataException]::new(
                'TenantLifecycle.State.ReadBack'
            )
        }
    }
    if ($properties.Count -ne $expectedFields.Count -or
        @(
            $expectedFields |
                Where-Object { -not $actualFields.Contains($_) }
        ).Count -ne 0 -or
        $VerifiedResource.exactReadBack -isnot [bool] -or
        -not [bool]$VerifiedResource.exactReadBack -or
        $NowUtc.Kind -ne [DateTimeKind]::Utc) {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.State.ReadBack'
        )
    }

    foreach ($name in @('provider', 'resourceType', 'logicalName')) {
        $value = $VerifiedResource.PSObject.Properties[$name].Value
        if ($value -isnot [string] -or
            $value.Length -gt 128 -or
            $value -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._:-]*$') {
            throw [IO.InvalidDataException]::new(
                'TenantLifecycle.State.ReadBack'
            )
        }
    }
    if ($VerifiedResource.stableId -isnot [string] -or
        [string]::IsNullOrWhiteSpace(
            [string]$VerifiedResource.stableId
        ) -or
        ([string]$VerifiedResource.stableId).Length -gt 2048 -or
        [string]$VerifiedResource.stableId -match '[\x00-\x1f]' -or
        $VerifiedResource.ownedPropertiesDigest -isnot [string] -or
        [string]$VerifiedResource.ownedPropertiesDigest -cnotmatch
            '^[0-9a-f]{64}$') {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.State.ReadBack'
        )
    }

    try {
        if ($ReviewedIntentComponentName -cnotmatch
                '^[A-Za-z][A-Za-z0-9]*$') {
            throw [IO.InvalidDataException]::new()
        }
        $reviewedIntent = Import-TenantConfiguration `
            -Path $ReviewedIntentPath `
            -ValidationStage Discovery `
            -ExpectedPublicTenantKey ([string]$State.publicTenantKey)
        $componentProperty =
            $reviewedIntent.Components.PSObject.Properties[
                $ReviewedIntentComponentName
            ]
        if ($null -eq $componentProperty) {
            throw [IO.InvalidDataException]::new()
        }
        $component = $componentProperty.Value
        $componentProperties = @($component.PSObject.Properties)
        $componentNames = @(
            $componentProperties |
                ForEach-Object { [string]$_.Name }
        )
        $intentMode = [string]$component.Mode
        $expectedIntentFields = @(
            'Provider',
            'ResourceType',
            'LogicalName',
            'Mode'
        )
        if ($intentMode -ceq 'Existing') {
            $expectedIntentFields += 'Id'
        }
        if ($intentMode -cnotin @('Existing', 'Create') -or
            $componentProperties.Count -ne
                $expectedIntentFields.Count -or
            @(
                $expectedIntentFields |
                    Where-Object { $componentNames -cnotcontains $_ }
            ).Count -ne 0) {
            throw [IO.InvalidDataException]::new()
        }
        foreach ($name in @(
            'Provider',
            'ResourceType',
            'LogicalName'
        )) {
            $value = [string]$component.$name
            if ($value -cnotmatch
                    '^[A-Za-z0-9][A-Za-z0-9._:-]*$' -or
                $value.Length -gt 128) {
                throw [IO.InvalidDataException]::new()
            }
        }
        if ($intentMode -ceq 'Existing' -and
            ([string]::IsNullOrWhiteSpace([string]$component.Id) -or
                ([string]$component.Id).Length -gt 2048 -or
                [string]$component.Id -match '[\x00-\x1f]')) {
            throw [IO.InvalidDataException]::new()
        }
    }
    catch {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.State.Intent'
        )
    }

    $identityFields = [ordered]@{
        Provider = 'provider'
        ResourceType = 'resourceType'
        LogicalName = 'logicalName'
    }
    foreach ($intentName in $identityFields.Keys) {
        $verifiedName = $identityFields[$intentName]
        if (-not [StringComparer]::Ordinal.Equals(
                [string]$component.$intentName,
                [string]$VerifiedResource.$verifiedName
            )) {
            throw [IO.InvalidDataException]::new(
                'TenantLifecycle.State.Intent'
            )
        }
    }

    $matchingIndexes = @()
    for (
        $index = 0;
        $index -lt @($State.resources).Count;
        $index++
    ) {
        $resource = @($State.resources)[$index]
        if ([string]$resource.provider -ceq
                [string]$component.Provider -and
            [string]$resource.resourceType -ceq
                [string]$component.ResourceType -and
            [string]$resource.logicalName -ceq
                [string]$component.LogicalName) {
            $matchingIndexes += $index
        }
    }
    if ($matchingIndexes.Count -ne 1) {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.State.Resource'
        )
    }

    $currentResource = @($State.resources)[$matchingIndexes[0]]
    if ($intentMode -ceq 'Existing') {
        if ($null -eq $currentResource.stableId -or
            -not [StringComparer]::Ordinal.Equals(
                [string]$component.Id,
                [string]$currentResource.stableId
            ) -or
            -not [StringComparer]::Ordinal.Equals(
                [string]$component.Id,
                [string]$VerifiedResource.stableId
            )) {
            throw [IO.InvalidDataException]::new(
                'TenantLifecycle.State.Intent'
            )
        }
    }
    elseif ($null -ne $currentResource.stableId -and
        -not [StringComparer]::Ordinal.Equals(
            [string]$currentResource.stableId,
            [string]$VerifiedResource.stableId
        )) {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.State.StableIdImmutable'
        )
    }

    $updated = ConvertFrom-TenantLifecycleJson -InputObject (
        $State | ConvertTo-Json -Depth 30
    )
    $target = @($updated.resources)[$matchingIndexes[0]]
    if ($intentMode -ceq 'Create' -and
        $null -eq $target.stableId) {
        $target.stableId = [string]$VerifiedResource.stableId
    }
    $target.lastVerifiedAtUtc = $NowUtc.ToString(
        'yyyy-MM-ddTHH:mm:ss.fffffffZ',
        [Globalization.CultureInfo]::InvariantCulture
    )
    $target.ownedPropertiesDigest =
        [string]$VerifiedResource.ownedPropertiesDigest

    try {
        Test-TenantLifecycleContract `
            -Kind State `
            -InputObject $updated |
            Out-Null
    }
    catch {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.State.Resource'
        )
    }
    $updated
}
