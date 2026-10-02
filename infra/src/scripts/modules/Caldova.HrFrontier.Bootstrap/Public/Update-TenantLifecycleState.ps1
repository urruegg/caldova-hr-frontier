function Update-TenantLifecycleState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$State,

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
    $properties = @(
        $VerifiedResource.PSObject.Properties |
            Where-Object { $_.MemberType -in @('NoteProperty', 'Property', 'AliasProperty') }
    )
    $actualFields = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($property in $properties) {
        [void]$actualFields.Add($property.Name)
    }
    if ($properties.Count -ne $expectedFields.Count -or
        @($expectedFields | Where-Object { -not $actualFields.Contains($_) }).Count -ne 0 -or
        $VerifiedResource.exactReadBack -isnot [bool] -or
        -not [bool]$VerifiedResource.exactReadBack -or
        $NowUtc.Kind -ne [DateTimeKind]::Utc) {
        throw [IO.InvalidDataException]::new('TenantLifecycle.State.ReadBack')
    }

    foreach ($name in @('provider', 'resourceType', 'logicalName')) {
        $value = $VerifiedResource.PSObject.Properties[$name].Value
        if ($value -isnot [string] -or
            $value.Length -gt 128 -or
            $value -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._:-]*$') {
            throw [IO.InvalidDataException]::new('TenantLifecycle.State.ReadBack')
        }
    }
    if ($VerifiedResource.stableId -isnot [string] -or
        [string]::IsNullOrWhiteSpace([string]$VerifiedResource.stableId) -or
        ([string]$VerifiedResource.stableId).Length -gt 2048 -or
        [string]$VerifiedResource.stableId -match '[\x00-\x1f]' -or
        $VerifiedResource.ownedPropertiesDigest -isnot [string] -or
        [string]$VerifiedResource.ownedPropertiesDigest -cnotmatch '^[0-9a-f]{64}$') {
        throw [IO.InvalidDataException]::new('TenantLifecycle.State.ReadBack')
    }

    $matchingIndexes = @()
    for ($index = 0; $index -lt @($State.resources).Count; $index++) {
        $resource = @($State.resources)[$index]
        if ([string]$resource.provider -ceq [string]$VerifiedResource.provider -and
            [string]$resource.resourceType -ceq [string]$VerifiedResource.resourceType -and
            [string]$resource.logicalName -ceq [string]$VerifiedResource.logicalName) {
            $matchingIndexes += $index
        }
    }
    if ($matchingIndexes.Count -ne 1) {
        throw [IO.InvalidDataException]::new('TenantLifecycle.State.Resource')
    }

    $updated = $State | ConvertTo-Json -Depth 30 | ConvertFrom-Json
    $target = @($updated.resources)[$matchingIndexes[0]]
    $target.stableId = [string]$VerifiedResource.stableId
    $target.lastVerifiedAtUtc = $NowUtc.ToString(
        'yyyy-MM-ddTHH:mm:ss.fffffffZ',
        [Globalization.CultureInfo]::InvariantCulture
    )
    $target.ownedPropertiesDigest = [string]$VerifiedResource.ownedPropertiesDigest

    try {
        Test-TenantLifecycleContract -Kind State -InputObject $updated | Out-Null
    }
    catch {
        throw [IO.InvalidDataException]::new('TenantLifecycle.State.Resource')
    }
    $updated
}
