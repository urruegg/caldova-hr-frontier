function Sort-TenantLifecycleGraph {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [object[]]$Nodes
    )

    $expectedFields = @('id', 'kind', 'prerequisiteIds', 'requiredOutcome', 'inputDigest', 'stage')
    $nodesById = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)

    foreach ($node in $Nodes) {
        if ($null -eq $node -or $node -is [string] -or $node -is [System.Array] -or $node -is [System.Collections.IDictionary]) {
            throw [IO.InvalidDataException]::new('TenantLifecycle.Graph.InvalidNode')
        }

        $properties = @(
            $node.PSObject.Properties |
                Where-Object { $_.MemberType -in @('NoteProperty', 'Property', 'AliasProperty') }
        )
        if ($properties.Count -ne $expectedFields.Count) {
            throw [IO.InvalidDataException]::new('TenantLifecycle.Graph.InvalidNode')
        }

        $actualFields = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach ($property in $properties) {
            [void]$actualFields.Add($property.Name)
        }
        foreach ($field in $expectedFields) {
            if (-not $actualFields.Contains($field)) {
                throw [IO.InvalidDataException]::new('TenantLifecycle.Graph.InvalidNode')
            }
        }

        if (
            -not ($node.id -is [string]) -or
            -not [regex]::IsMatch($node.id, '^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$', [Text.RegularExpressions.RegexOptions]::CultureInvariant) -or
            -not ($node.kind -is [string]) -or
            [string]::IsNullOrWhiteSpace($node.kind) -or
            $node.kind.Length -gt 128 -or
            -not ($node.requiredOutcome -is [string]) -or
            [string]::IsNullOrWhiteSpace($node.requiredOutcome) -or
            $node.requiredOutcome.Length -gt 64 -or
            -not ($node.inputDigest -is [string]) -or
            -not [regex]::IsMatch($node.inputDigest, '^[0-9a-f]{64}$', [Text.RegularExpressions.RegexOptions]::CultureInvariant) -or
            -not ($node.stage -is [string]) -or
            [string]::IsNullOrWhiteSpace($node.stage) -or
            $node.stage.Length -gt 128 -or
            -not ($node.prerequisiteIds -is [System.Array])
        ) {
            throw [IO.InvalidDataException]::new('TenantLifecycle.Graph.InvalidNode')
        }

        $prerequisiteIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach ($prerequisiteId in @($node.prerequisiteIds)) {
            if (
                -not ($prerequisiteId -is [string]) -or
                -not [regex]::IsMatch($prerequisiteId, '^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$', [Text.RegularExpressions.RegexOptions]::CultureInvariant) -or
                -not $prerequisiteIds.Add($prerequisiteId)
            ) {
                throw [IO.InvalidDataException]::new('TenantLifecycle.Graph.InvalidNode')
            }
        }

        if ($nodesById.ContainsKey($node.id)) {
            throw [IO.InvalidDataException]::new('TenantLifecycle.Graph.DuplicateNodeId')
        }
        $nodesById.Add($node.id, $node)
    }

    $inDegree = [Collections.Generic.Dictionary[string, int]]::new([StringComparer]::Ordinal)
    $dependents = [Collections.Generic.Dictionary[string, Collections.Generic.List[string]]]::new([StringComparer]::Ordinal)
    foreach ($nodeId in $nodesById.Keys) {
        $inDegree.Add($nodeId, 0)
        $dependents.Add($nodeId, [Collections.Generic.List[string]]::new())
    }

    foreach ($node in $nodesById.Values) {
        foreach ($prerequisiteId in @($node.prerequisiteIds)) {
            if (-not $nodesById.ContainsKey($prerequisiteId)) {
                throw [IO.InvalidDataException]::new('TenantLifecycle.Graph.MissingPrerequisite')
            }

            $inDegree[$node.id] = $inDegree[$node.id] + 1
            $dependents[$prerequisiteId].Add($node.id)
        }
    }

    $ready = [Collections.Generic.SortedSet[string]]::new([StringComparer]::Ordinal)
    foreach ($nodeId in $nodesById.Keys) {
        if ($inDegree[$nodeId] -eq 0) {
            [void]$ready.Add($nodeId)
        }
    }

    $orderedNodes = [Collections.Generic.List[object]]::new()
    while ($ready.Count -gt 0) {
        $nodeId = $ready.Min
        [void]$ready.Remove($nodeId)
        $orderedNodes.Add($nodesById[$nodeId])

        foreach ($dependentId in $dependents[$nodeId]) {
            $inDegree[$dependentId] = $inDegree[$dependentId] - 1
            if ($inDegree[$dependentId] -eq 0) {
                [void]$ready.Add($dependentId)
            }
        }
    }

    if ($orderedNodes.Count -ne $nodesById.Count) {
        throw [IO.InvalidDataException]::new('TenantLifecycle.Graph.Cycle')
    }

    return $orderedNodes
}
