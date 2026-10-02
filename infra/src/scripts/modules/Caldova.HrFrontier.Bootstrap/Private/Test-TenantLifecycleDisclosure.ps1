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
        throw [IO.InvalidDataException]::new('TenantLifecycle.Disclosure.Invalid')
    }
    $properties = @($InputObject.PSObject.Properties)
    if ($properties.Count -ne $ExpectedFields.Count) {
        throw [IO.InvalidDataException]::new('TenantLifecycle.Disclosure.Invalid')
    }
    $actual = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::Ordinal
    )
    foreach ($property in $properties) {
        if ($property.MemberType -notin @('NoteProperty', 'Property') -or
            -not $actual.Add($property.Name)) {
            throw [IO.InvalidDataException]::new('TenantLifecycle.Disclosure.Invalid')
        }
    }
    foreach ($field in $ExpectedFields) {
        if (-not $actual.Contains($field)) {
            throw [IO.InvalidDataException]::new('TenantLifecycle.Disclosure.Invalid')
        }
    }
}

function Test-TenantLifecycleDisclosureDigest {
    [CmdletBinding()]
    param([AllowNull()][object]$Value)

    if (-not ($Value -is [string]) -or
        [string]$Value -cnotmatch '^[0-9a-f]{64}$') {
        throw [IO.InvalidDataException]::new('TenantLifecycle.Disclosure.Invalid')
    }
}

function Test-TenantLifecycleDisclosureStringSet {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Value,
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [Collections.Generic.HashSet[string]]$Allowed
    )

    if (-not ($Value -is [System.Array])) {
        throw [IO.InvalidDataException]::new('TenantLifecycle.Disclosure.Invalid')
    }
    $seen = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::Ordinal
    )
    foreach ($item in @($Value)) {
        if (-not ($item -is [string]) -or
            [string]::IsNullOrWhiteSpace($item) -or
            -not $Allowed.Contains([string]$item) -or
            -not $seen.Add([string]$item)) {
            throw [IO.InvalidDataException]::new('TenantLifecycle.Disclosure.Invalid')
        }
    }
}

function Test-TenantLifecycleDisclosure {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)][object]$Projection,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$AllowedStableIds,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$AllowedUrlHosts
    )

    Test-TenantLifecycleDisclosureFields `
        -InputObject $Projection `
        -ExpectedFields @(
            'actions',
            'approvedDigests',
            'artifactDigest',
            'counts',
            'disclosedStableIds',
            'disclosedUrlHosts',
            'nonClaims',
            'runId',
            'sourceCommit',
            'statuses'
        )
    if (-not ($Projection.runId -is [string]) -or
        [string]$Projection.runId -cnotmatch (
            '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-' +
            '[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
        ) -or
        -not ($Projection.sourceCommit -is [string]) -or
        [string]$Projection.sourceCommit -cnotmatch '^[0-9a-f]{40}$') {
        throw [IO.InvalidDataException]::new('TenantLifecycle.Disclosure.Invalid')
    }

    Test-TenantLifecycleDisclosureFields `
        -InputObject $Projection.approvedDigests `
        -ExpectedFields @(
            'actions',
            'approval',
            'assessment',
            'executionManifest',
            'intent',
            'readBack',
            'state',
            'summary'
        )
    foreach ($name in @(
        'approval',
        'assessment',
        'executionManifest',
        'intent',
        'readBack',
        'state',
        'summary'
    )) {
        Test-TenantLifecycleDisclosureDigest $Projection.approvedDigests.$name
    }
    if (-not ($Projection.approvedDigests.actions -is [System.Array])) {
        throw [IO.InvalidDataException]::new('TenantLifecycle.Disclosure.Invalid')
    }
    foreach ($actionDigest in @($Projection.approvedDigests.actions)) {
        Test-TenantLifecycleDisclosureFields `
            -InputObject $actionDigest `
            -ExpectedFields @('digest', 'id')
        if (-not ($actionDigest.id -is [string]) -or
            [string]$actionDigest.id -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._:-]*$') {
            throw [IO.InvalidDataException]::new('TenantLifecycle.Disclosure.Invalid')
        }
        Test-TenantLifecycleDisclosureDigest $actionDigest.digest
    }

    if (-not ($Projection.actions -is [System.Array])) {
        throw [IO.InvalidDataException]::new('TenantLifecycle.Disclosure.Invalid')
    }
    $classificationNames = @(
        'NoChange',
        'Create',
        'Update',
        'Manual',
        'Blocked',
        'Refused'
    )
    foreach ($action in @($Projection.actions)) {
        Test-TenantLifecycleDisclosureFields `
            -InputObject $action `
            -ExpectedFields @('classification', 'digest', 'id', 'status')
        if (-not ($action.id -is [string]) -or
            [string]$action.id -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._:-]*$' -or
            $classificationNames -cnotcontains [string]$action.classification -or
            -not ($action.status -is [string]) -or
            [string]$action.status -cnotmatch '^[A-Za-z][A-Za-z0-9]{0,63}$') {
            throw [IO.InvalidDataException]::new('TenantLifecycle.Disclosure.Invalid')
        }
        Test-TenantLifecycleDisclosureDigest $action.digest
    }

    Test-TenantLifecycleDisclosureFields `
        -InputObject $Projection.counts `
        -ExpectedFields $classificationNames
    foreach ($name in $classificationNames) {
        if (-not ($Projection.counts.$name -is [int]) -or
            [int]$Projection.counts.$name -lt 0) {
            throw [IO.InvalidDataException]::new('TenantLifecycle.Disclosure.Invalid')
        }
    }
    Test-TenantLifecycleDisclosureFields `
        -InputObject $Projection.statuses `
        -ExpectedFields @('approval', 'readBack', 'summary')
    if ([string]$Projection.statuses.approval -cne 'Approved') {
        throw [IO.InvalidDataException]::new('TenantLifecycle.Disclosure.Invalid')
    }
    foreach ($name in @('readBack', 'summary')) {
        if (-not ($Projection.statuses.$name -is [string]) -or
            [string]$Projection.statuses.$name -cnotmatch '^[A-Za-z][A-Za-z0-9]{0,63}$') {
            throw [IO.InvalidDataException]::new('TenantLifecycle.Disclosure.Invalid')
        }
    }

    $stableIdAllowlist = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::Ordinal
    )
    foreach ($value in $AllowedStableIds) {
        [void]$stableIdAllowlist.Add($value)
    }
    $urlHostAllowlist = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::OrdinalIgnoreCase
    )
    foreach ($value in $AllowedUrlHosts) {
        [void]$urlHostAllowlist.Add($value)
    }
    Test-TenantLifecycleDisclosureStringSet `
        -Value $Projection.disclosedStableIds `
        -Allowed $stableIdAllowlist
    Test-TenantLifecycleDisclosureStringSet `
        -Value $Projection.disclosedUrlHosts `
        -Allowed $urlHostAllowlist

    $expectedNonClaims = @(
        'Provider mutation was not verified by this projection.',
        'Pipeline import was not verified by this projection.',
        'Artifact bytes were not verified by this projection.'
    )
    if (-not ($Projection.nonClaims -is [System.Array]) -or
        @($Projection.nonClaims).Count -ne $expectedNonClaims.Count) {
        throw [IO.InvalidDataException]::new('TenantLifecycle.Disclosure.Invalid')
    }
    for ($index = 0; $index -lt $expectedNonClaims.Count; $index++) {
        if ([string]$Projection.nonClaims[$index] -cne $expectedNonClaims[$index]) {
            throw [IO.InvalidDataException]::new('TenantLifecycle.Disclosure.Invalid')
        }
    }
    Test-TenantLifecycleDisclosureDigest $Projection.artifactDigest
    return $true
}

function Assert-TenantLifecycleDisclosureAllowlists {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$AllowedStableIds,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$AllowedUrlHosts
    )

    $stableIds = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::Ordinal
    )
    foreach ($value in $AllowedStableIds) {
        $uri = $null
        $isHttpUri = [Uri]::TryCreate(
            $value,
            [UriKind]::Absolute,
            [ref]$uri
        ) -and $uri.Scheme -in @('http', 'https')
        if ([string]::IsNullOrWhiteSpace($value) -or
            $value.Length -gt 2048 -or
            $value -cmatch '[\x00-\x1f]' -or
            $value -cmatch '^(?:[A-Za-z]:[\\/]|\\\\)' -or
            $isHttpUri -or
            -not $stableIds.Add($value)) {
            throw [IO.InvalidDataException]::new(
                'TenantLifecycle.Disclosure.Allowlist'
            )
        }
    }

    $urlHosts = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::OrdinalIgnoreCase
    )
    foreach ($value in $AllowedUrlHosts) {
        if ([string]::IsNullOrWhiteSpace($value) -or
            $value.Length -gt 253 -or
            $value -cmatch '[\x00-\x20/:?#@]' -or
            [Uri]::CheckHostName($value) -eq [UriHostNameType]::Unknown -or
            -not $urlHosts.Add($value)) {
            throw [IO.InvalidDataException]::new(
                'TenantLifecycle.Disclosure.Allowlist'
            )
        }
    }
}

function Test-TenantLifecycleDisclosureGitPath {
    [CmdletBinding()]
    [OutputType([bool])]
    param([Parameter(Mandatory)][string]$Path)

    $current = [IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($Path))
    while (-not [string]::IsNullOrEmpty($current)) {
        $gitMarker = Join-Path $current '.git'
        if ([IO.Directory]::Exists($gitMarker) -or [IO.File]::Exists($gitMarker)) {
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
            $item = Get-Item -LiteralPath $current -Force -ErrorAction Stop
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
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

function ConvertFrom-TenantLifecycleDisclosureJson {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Json)

    if ($PSVersionTable.PSVersion.Major -ge 6) {
        $parameters = @{
            InputObject = $Json
            Depth = 100
        }
        if ((Get-Command ConvertFrom-Json).Parameters.ContainsKey('DateKind')) {
            $parameters.DateKind = 'String'
        }
        return ConvertFrom-Json @parameters
    }
    return ConvertFrom-Json -InputObject $Json
}

function Import-TenantLifecycleDisclosureEvidence {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RunDirectory,
        [Parameter(Mandatory)][string]$RelativePath,
        [Parameter(Mandatory)]
        [ValidateSet(
            'Assessment',
            'ExecutionManifest',
            'Approval',
            'ActionEvidence',
            'State',
            'ReadBack',
            'Summary'
        )]
        [string]$Kind
    )

    try {
        $root = [IO.Path]::GetFullPath($RunDirectory).TrimEnd('\', '/')
        $candidate = [IO.Path]::GetFullPath((
            Join-Path $root (
                $RelativePath.Replace(
                    '/',
                    [IO.Path]::DirectorySeparatorChar
                )
            )
        ))
        $rootPrefix = $root + [IO.Path]::DirectorySeparatorChar
        if (-not $candidate.StartsWith(
                $rootPrefix,
                [StringComparison]::OrdinalIgnoreCase
            ) -or
            -not [IO.File]::Exists($candidate) -or
            (Test-TenantLifecycleEvidenceReparsePath -Path $candidate)) {
            throw [IO.InvalidDataException]::new()
        }
        $bytes = [IO.File]::ReadAllBytes($candidate)
        $json = [Text.UTF8Encoding]::new($false, $true).GetString($bytes)
        $value = ConvertFrom-TenantLifecycleDisclosureJson -Json $json
        Test-TenantLifecycleContract -Kind $Kind -InputObject $value | Out-Null
        if (-not (Test-TenantLifecycleEvidencePropertyBoundary -Value $value)) {
            throw [IO.InvalidDataException]::new()
        }
        $canonical = ConvertTo-CanonicalJsonValue -Value $value -RemainingDepth 30
        $canonicalJson = ($canonical | ConvertTo-Json -Depth 30 -Compress) + "`n"
        $canonicalBytes = [Text.UTF8Encoding]::new($false, $true).GetBytes(
            $canonicalJson
        )
        if ([Convert]::ToBase64String($bytes) -cne
            [Convert]::ToBase64String($canonicalBytes)) {
            throw [IO.InvalidDataException]::new()
        }
        if ($Kind -ceq 'ExecutionManifest') {
            $digest = Get-TenantLifecycleExecutionManifestDigest -Manifest $value
            if ([string]$value.digest -cne $digest) {
                throw [IO.InvalidDataException]::new()
            }
        }
        return $value
    }
    catch {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.Disclosure.Evidence.Invalid'
        )
    }
}
