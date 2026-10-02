function Resolve-TenantLifecycleGraph {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [object[]]$Nodes,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$ObservedOutcomes
    )

    $orderedNodes = @(Sort-TenantLifecycleGraph -Nodes $Nodes)
    $nodeIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($node in $orderedNodes) {
        [void]$nodeIds.Add($node.id)
    }

    $allowedClassifications = [Collections.Generic.HashSet[string]]::new(
        [string[]]@('NoChange', 'Create', 'Update', 'Manual', 'Blocked', 'Refused'),
        [StringComparer]::Ordinal
    )
    $outcomesById = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
    foreach ($outcome in $ObservedOutcomes) {
        if ($null -eq $outcome -or $outcome -is [string] -or $outcome -is [System.Array] -or $outcome -is [System.Collections.IDictionary]) {
            throw [IO.InvalidDataException]::new('TenantLifecycle.Graph.InvalidOutcome')
        }

        foreach ($field in @('id', 'classification', 'status', 'inputDigest')) {
            if ($null -eq $outcome.PSObject.Properties[$field]) {
                throw [IO.InvalidDataException]::new('TenantLifecycle.Graph.InvalidOutcome')
            }
        }

        if (
            -not ($outcome.id -is [string]) -or
            -not $nodeIds.Contains($outcome.id) -or
            -not ($outcome.classification -is [string]) -or
            -not ($outcome.status -is [string]) -or
            [string]::IsNullOrWhiteSpace($outcome.status) -or
            $outcome.status.Length -gt 64 -or
            -not ($outcome.inputDigest -is [string]) -or
            -not [regex]::IsMatch($outcome.inputDigest, '^[0-9a-f]{64}$', [Text.RegularExpressions.RegexOptions]::CultureInvariant)
        ) {
            throw [IO.InvalidDataException]::new('TenantLifecycle.Graph.InvalidOutcome')
        }

        if (-not $allowedClassifications.Contains($outcome.classification)) {
            throw [IO.InvalidDataException]::new('TenantLifecycle.Graph.InvalidClassification')
        }
        $readBackProperty = $outcome.PSObject.Properties['readBackDigest']
        if (
            $null -ne $readBackProperty -and
            $null -ne $readBackProperty.Value -and
            (
                -not ($readBackProperty.Value -is [string]) -or
                -not [regex]::IsMatch($readBackProperty.Value, '^[0-9a-f]{64}$', [Text.RegularExpressions.RegexOptions]::CultureInvariant)
            )
        ) {
            throw [IO.InvalidDataException]::new('TenantLifecycle.Graph.InvalidOutcome')
        }
        if ($outcomesById.ContainsKey($outcome.id)) {
            throw [IO.InvalidDataException]::new('TenantLifecycle.Graph.DuplicateOutcomeId')
        }
        $outcomesById.Add($outcome.id, $outcome)
    }

    $freshSuccessById = [Collections.Generic.Dictionary[string, bool]]::new([StringComparer]::Ordinal)
    $resolved = [Collections.Generic.List[object]]::new()
    foreach ($node in $orderedNodes) {
        $blockingIds = [Collections.Generic.SortedSet[string]]::new([StringComparer]::Ordinal)
        foreach ($prerequisiteId in @($node.prerequisiteIds)) {
            if (-not $freshSuccessById[$prerequisiteId]) {
                [void]$blockingIds.Add($prerequisiteId)
            }
        }

        $canExecute = $blockingIds.Count -eq 0
        $status = 'NotRun'
        $isFreshSuccess = $false
        $outcome = $null
        $hasOutcome = $outcomesById.TryGetValue($node.id, [ref]$outcome)

        if (-not $canExecute) {
            $status = 'Blocked'
        }
        elseif ($hasOutcome) {
            if (-not [StringComparer]::Ordinal.Equals($node.inputDigest, $outcome.inputDigest)) {
                $status = 'Stale'
            }
            elseif ($outcome.classification -ceq 'Blocked') {
                $status = 'Blocked'
            }
            elseif ($outcome.classification -ceq 'Refused') {
                $status = 'Refused'
            }
            elseif (-not [StringComparer]::Ordinal.Equals($node.requiredOutcome, $outcome.status)) {
                $status = $outcome.status
            }
            else {
                switch -CaseSensitive ($outcome.classification) {
                    'NoChange' {
                        $status = 'Passed'
                        $isFreshSuccess = $true
                    }
                    { $_ -in @('Create', 'Update') } {
                        $readBackProperty = $outcome.PSObject.Properties['readBackDigest']
                        if ($null -ne $readBackProperty -and $readBackProperty.Value -is [string]) {
                            $status = 'Passed'
                            $isFreshSuccess = $true
                        }
                        else {
                            $status = 'Unverified'
                        }
                    }
                    'Manual' {
                        $readBackProperty = $outcome.PSObject.Properties['readBackDigest']
                        if ($null -ne $readBackProperty -and $readBackProperty.Value -is [string]) {
                            $status = 'Passed'
                            $isFreshSuccess = $true
                        }
                        else {
                            $status = 'Manual'
                        }
                    }
                }
            }
        }

        $freshSuccessById.Add($node.id, ($canExecute -and $isFreshSuccess))
        $resolved.Add([pscustomobject][ordered]@{
            id = $node.id
            kind = $node.kind
            prerequisiteIds = @($node.prerequisiteIds)
            requiredOutcome = $node.requiredOutcome
            inputDigest = $node.inputDigest
            stage = $node.stage
            status = $status
            blockingPrerequisiteIds = @($blockingIds)
            canExecute = $canExecute
        })
    }

    return $resolved
}
