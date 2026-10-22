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
    $nodesById = [Collections.Generic.Dictionary[string, object]]::new(
        [StringComparer]::Ordinal
    )
    foreach ($node in $orderedNodes) {
        [void]$nodeIds.Add($node.id)
        $nodesById.Add($node.id, $node)
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

        $isStageResult =
            $null -eq $outcome.PSObject.Properties['id'] -and
            $null -ne $outcome.PSObject.Properties['stage']
        if ($isStageResult) {
            try {
                Test-TenantLifecycleContract `
                    -Kind StageResult `
                    -InputObject $outcome |
                    Out-Null
            }
            catch {
                throw [IO.InvalidDataException]::new('TenantLifecycle.Graph.InvalidOutcome')
            }
            $outcomeId = [string]$outcome.stage
            if (-not $nodeIds.Contains($outcomeId) -or
                [string]$nodesById[$outcomeId].kind -cne 'Stage' -or
                -not [StringComparer]::Ordinal.Equals(
                    [string]$nodesById[$outcomeId].stage,
                    $outcomeId
                )) {
                throw [IO.InvalidDataException]::new(
                    'TenantLifecycle.Graph.InvalidOutcome'
                )
            }
        }
        else {
            foreach ($field in @(
                'id',
                'classification',
                'status',
                'inputDigest'
            )) {
                if ($null -eq $outcome.PSObject.Properties[$field]) {
                    throw [IO.InvalidDataException]::new(
                        'TenantLifecycle.Graph.InvalidOutcome'
                    )
                }
            }

            if (
                -not ($outcome.id -is [string]) -or
                -not $nodeIds.Contains($outcome.id) -or
                [string]$nodesById[$outcome.id].kind -ceq 'Stage' -or
                -not ($outcome.classification -is [string]) -or
                -not ($outcome.status -is [string]) -or
                [string]::IsNullOrWhiteSpace($outcome.status) -or
                $outcome.status.Length -gt 64 -or
                -not ($outcome.inputDigest -is [string]) -or
                -not [regex]::IsMatch(
                    $outcome.inputDigest,
                    '^[0-9a-f]{64}$',
                    [Text.RegularExpressions.RegexOptions]::CultureInvariant
                )
            ) {
                throw [IO.InvalidDataException]::new(
                    'TenantLifecycle.Graph.InvalidOutcome'
                )
            }

            if (-not $allowedClassifications.Contains(
                    $outcome.classification
                )) {
                throw [IO.InvalidDataException]::new(
                    'TenantLifecycle.Graph.InvalidClassification'
                )
            }
            $readBackProperty =
                $outcome.PSObject.Properties['readBackDigest']
            if (
                $null -ne $readBackProperty -and
                $null -ne $readBackProperty.Value -and
                (
                    -not ($readBackProperty.Value -is [string]) -or
                    -not [regex]::IsMatch(
                        $readBackProperty.Value,
                        '^[0-9a-f]{64}$',
                        [Text.RegularExpressions.RegexOptions]::CultureInvariant
                    )
                )
            ) {
                throw [IO.InvalidDataException]::new(
                    'TenantLifecycle.Graph.InvalidOutcome'
                )
            }
            $outcomeId = [string]$outcome.id
        }
        if ($outcomesById.ContainsKey($outcomeId)) {
            throw [IO.InvalidDataException]::new(
                'TenantLifecycle.Graph.DuplicateOutcomeId'
            )
        }
        $outcomesById.Add($outcomeId, $outcome)
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
            if ([string]$node.kind -ceq 'Stage') {
                if (-not [StringComparer]::Ordinal.Equals(
                        [string]$node.inputDigest,
                        [string]$outcome.phaseManifestDigest
                    )) {
                    $status = 'Stale'
                }
                else {
                    $status = [string]$outcome.status
                    $isFreshSuccess = $status -ceq 'Passed'
                }
            }
            elseif (-not [StringComparer]::Ordinal.Equals($node.inputDigest, $outcome.inputDigest)) {
                $status = 'Stale'
            }
            elseif ($outcome.classification -ceq 'Blocked') {
                $status = 'Blocked'
            }
            elseif ($outcome.classification -ceq 'Refused') {
                $status = 'Refused'
            }
            elseif (-not [StringComparer]::Ordinal.Equals('Passed', $outcome.status)) {
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
                        if (
                            $null -ne $readBackProperty -and
                            $readBackProperty.Value -is [string] -and
                            [StringComparer]::Ordinal.Equals($node.inputDigest, $readBackProperty.Value)
                        ) {
                            $status = 'Passed'
                            $isFreshSuccess = $true
                        }
                        else {
                            $status = 'Unverified'
                        }
                    }
                    'Manual' {
                        $readBackProperty = $outcome.PSObject.Properties['readBackDigest']
                        if (
                            $null -ne $readBackProperty -and
                            $readBackProperty.Value -is [string] -and
                            [StringComparer]::Ordinal.Equals($node.inputDigest, $readBackProperty.Value)
                        ) {
                            $status = 'Passed'
                            $isFreshSuccess = $true
                        }
                        elseif ($null -ne $readBackProperty -and $readBackProperty.Value -is [string]) {
                            $status = 'Unverified'
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
