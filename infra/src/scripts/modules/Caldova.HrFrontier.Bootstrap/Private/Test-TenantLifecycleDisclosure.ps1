function Test-TenantLifecycleDisclosureFields {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$InputObject,
        [Parameter(Mandatory)][string[]]$ExpectedFields
    )

    if ($null -eq $InputObject -or
        $InputObject -is [string] -or
        $InputObject -is [System.Array] -or
        $InputObject -is [Collections.IDictionary]) {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.Disclosure.Invalid'
        )
    }
    $properties = @($InputObject.PSObject.Properties)
    if ($properties.Count -ne $ExpectedFields.Count) {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.Disclosure.Invalid'
        )
    }
    $actual = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::Ordinal
    )
    foreach ($property in $properties) {
        if ($property.MemberType -ne 'NoteProperty' -or
            -not $actual.Add($property.Name)) {
            throw [IO.InvalidDataException]::new(
                'TenantLifecycle.Disclosure.Invalid'
            )
        }
    }
    foreach ($field in $ExpectedFields) {
        if (-not $actual.Contains($field)) {
            throw [IO.InvalidDataException]::new(
                'TenantLifecycle.Disclosure.Invalid'
            )
        }
    }
}

function Test-TenantLifecycleDisclosureDigest {
    [CmdletBinding()]
    param([AllowNull()][object]$Value)

    if (-not ($Value -is [string]) -or
        [string]$Value -cnotmatch '^[0-9a-f]{64}$') {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.Disclosure.Invalid'
        )
    }
}

function Test-TenantLifecycleDisclosure {
    [CmdletBinding()]
    [OutputType([bool])]
    param([Parameter(Mandatory)][object]$Projection)

    Test-TenantLifecycleDisclosureFields `
        -InputObject $Projection `
        -ExpectedFields @(
            'schemaVersion',
            'runId',
            'publicTenantKey',
            'stages',
            'nonClaims',
            'digest'
        )
    if ([string]$Projection.schemaVersion -cne '1.0' -or
        -not ($Projection.runId -is [string]) -or
        [string]$Projection.runId -cnotmatch (
            '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-' +
            '[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
        ) -or
        [string]$Projection.publicTenantKey -cne 'tenant1' -or
        -not ($Projection.stages -is [System.Array]) -or
        @($Projection.stages).Count -eq 0) {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.Disclosure.Invalid'
        )
    }

    $canonicalStages = @(
        'Workstation',
        'PrivateBoundary',
        'Foundation',
        'DevDelivery',
        'ReadBack',
        'Acceptance',
        'TenantReplica'
    )
    $lastStageIndex = -1
    foreach ($stage in @($Projection.stages)) {
        Test-TenantLifecycleDisclosureFields `
            -InputObject $stage `
            -ExpectedFields @(
                'stage',
                'status',
                'classification',
                'phaseManifestDigest',
                'phaseSummaryDigest',
                'sourceCommit',
                'intentDigest',
                'stateDigest'
            )
        $stageIndex = -1
        for ($index = 0; $index -lt $canonicalStages.Count; $index++) {
            if ([StringComparer]::Ordinal.Equals(
                    $canonicalStages[$index],
                    [string]$stage.stage
                )) {
                $stageIndex = $index
                break
            }
        }
        if ($stageIndex -le $lastStageIndex -or
            [string]$stage.status -cne 'Passed' -or
            [string]$stage.classification -cnotin @(
                'NoChange',
                'Changed'
            ) -or
            -not ($stage.sourceCommit -is [string]) -or
            [string]$stage.sourceCommit -cnotmatch '^[0-9a-f]{40}$') {
            throw [IO.InvalidDataException]::new(
                'TenantLifecycle.Disclosure.Invalid'
            )
        }
        $lastStageIndex = $stageIndex
        foreach ($name in @(
            'phaseManifestDigest',
            'phaseSummaryDigest',
            'intentDigest',
            'stateDigest'
        )) {
            Test-TenantLifecycleDisclosureDigest $stage.$name
        }
    }

    $expectedNonClaims = @(
        'The umbrella did not execute a provider mutation.',
        'Provider approvals and read-back remain child-runbook evidence.',
        'This projection discloses no provider resource identity or raw provider response.'
    )
    if (-not ($Projection.nonClaims -is [System.Array]) -or
        @($Projection.nonClaims).Count -ne $expectedNonClaims.Count) {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.Disclosure.Invalid'
        )
    }
    for ($index = 0; $index -lt $expectedNonClaims.Count; $index++) {
        if ([string]$Projection.nonClaims[$index] -cne
            $expectedNonClaims[$index]) {
            throw [IO.InvalidDataException]::new(
                'TenantLifecycle.Disclosure.Invalid'
            )
        }
    }

    Test-TenantLifecycleDisclosureDigest $Projection.digest
    $digestInput = [pscustomobject][ordered]@{
        schemaVersion = [string]$Projection.schemaVersion
        runId = [string]$Projection.runId
        publicTenantKey = [string]$Projection.publicTenantKey
        stages = [object[]]@($Projection.stages)
        nonClaims = [string[]]@($Projection.nonClaims)
    }
    if ([string]$Projection.digest -cne (
            Get-RunbookContentDigest -InputObject $digestInput
        )) {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.Disclosure.Invalid'
        )
    }
    return $true
}

function Test-TenantLifecycleDisclosureGitPath {
    [CmdletBinding()]
    [OutputType([bool])]
    param([Parameter(Mandatory)][string]$Path)

    $current = [IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($Path))
    while (-not [string]::IsNullOrEmpty($current)) {
        $gitMarker = Join-Path $current '.git'
        if ([IO.Directory]::Exists($gitMarker) -or
            [IO.File]::Exists($gitMarker)) {
            return $true
        }
        $parent = [IO.Directory]::GetParent($current)
        if ($null -eq $parent) {
            break
        }
        $current = $parent.FullName
    }
    return $false
}

function Test-TenantLifecycleDisclosureReparsePath {
    [CmdletBinding()]
    [OutputType([bool])]
    param([Parameter(Mandatory)][string]$Path)

    $current = [IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($Path))
    while (-not [string]::IsNullOrEmpty($current)) {
        if ([IO.Directory]::Exists($current)) {
            $item = Get-Item `
                -LiteralPath $current `
                -Force `
                -ErrorAction Stop
            if (
                ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne
                    0
            ) {
                return $true
            }
        }
        $parent = [IO.Directory]::GetParent($current)
        if ($null -eq $parent) {
            break
        }
        $current = $parent.FullName
    }
    return $false
}
