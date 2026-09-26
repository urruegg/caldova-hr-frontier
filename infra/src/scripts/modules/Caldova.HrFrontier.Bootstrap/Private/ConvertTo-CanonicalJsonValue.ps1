function ConvertTo-CanonicalJsonValue {
    [CmdletBinding()]
    param(
        [AllowNull()] [object]$Value,
        [Parameter(Mandatory)] [int]$RemainingDepth
    )

    if ($RemainingDepth -lt 0) {
        throw 'Canonical JSON depth was exhausted.'
    }
    if ($null -eq $Value -or $Value -is [string] -or $Value.GetType().IsPrimitive -or
        $Value -is [decimal] -or $Value -is [datetime] -or $Value -is [guid]) {
        return $Value
    }

    if ($Value -is [Collections.IDictionary]) {
        $result = [ordered]@{}
        $keys = @($Value.Keys | ForEach-Object { [string]$_ })
        [Array]::Sort($keys, [StringComparer]::Ordinal)
        foreach ($key in $keys) {
            $result[$key] = ConvertTo-CanonicalJsonValue -Value $Value[$key] -RemainingDepth ($RemainingDepth - 1)
        }
        return $result
    }

    if ($Value -is [Collections.IEnumerable]) {
        $items = @(
            foreach ($item in $Value) {
                ConvertTo-CanonicalJsonValue -Value $item -RemainingDepth ($RemainingDepth - 1)
            }
        )
        return ,$items
    }

    $properties = @($Value.PSObject.Properties | Where-Object MemberType -In NoteProperty, Property)
    $names = @($properties.Name)
    [Array]::Sort($names, [StringComparer]::Ordinal)
    $object = [ordered]@{}
    foreach ($name in $names) {
        $object[$name] = ConvertTo-CanonicalJsonValue -Value $Value.$name -RemainingDepth ($RemainingDepth - 1)
    }
    return $object
}
