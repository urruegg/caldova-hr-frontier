function Test-TenantLifecycleEvidencePropertyBoundary {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [AllowNull()][object]$Value,
        [string]$PropertyName = '',
        [ValidateRange(0, 30)][int]$Depth = 0
    )

    if ($Depth -ge 30) {
        return $false
    }
    if ($null -eq $Value) {
        return $true
    }

    $clientCredentialPropertyName = 'client' + 'Secret'
    $prohibitedNames = [Collections.Generic.HashSet[string]]::new(
        [string[]]@(
            'accessToken',
            'approvalSession',
            'approvalSessionPayload',
            'authorization',
            $clientCredentialPropertyName,
            'command',
            'commandLine',
            'commandOutput',
            'commandTranscript',
            'credential',
            'credentials',
            'generatedParameters',
            'password',
            'privateKey',
            'privatePath',
            'providerPayload',
            'raw',
            'rawCommand',
            'rawCommandOutput',
            'rawOutput',
            'secret',
            'stderr',
            'stdout',
            'token'
        ),
        [StringComparer]::OrdinalIgnoreCase
    )
    if ($prohibitedNames.Contains($PropertyName)) {
        return $false
    }

    if ($Value -is [string]) {
        if ($PropertyName -cne 'evidenceRoot' -and
            ([string]$Value -match '(?i)(?:^|[\s''"(])(?:[a-z]:[\\/]|\\\\)')) {
            return $false
        }
        return $true
    }
    if ($Value.GetType().IsPrimitive -or $Value -is [decimal] -or
        $Value -is [datetime] -or $Value -is [guid]) {
        return $true
    }
    if ($Value -is [Collections.IDictionary]) {
        foreach ($key in @($Value.Keys)) {
            $name = [string]$key
            if (-not (Test-TenantLifecycleEvidencePropertyBoundary -Value $Value[$key] -PropertyName $name -Depth ($Depth + 1))) {
                return $false
            }
        }
        return $true
    }
    if ($Value -is [Collections.IEnumerable]) {
        foreach ($item in $Value) {
            if (-not (Test-TenantLifecycleEvidencePropertyBoundary -Value $item -PropertyName $PropertyName -Depth ($Depth + 1))) {
                return $false
            }
        }
        return $true
    }

    $properties = @($Value.PSObject.Properties)
    foreach ($property in $properties) {
        if ($property.MemberType -ne 'NoteProperty') {
            return $false
        }
        if (-not (Test-TenantLifecycleEvidencePropertyBoundary -Value $property.Value -PropertyName $property.Name -Depth ($Depth + 1))) {
            return $false
        }
    }
    return $true
}

function Test-TenantLifecycleEvidenceReparsePath {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(DontShow)]
        [scriptblock]$FileSystemProbe
    )

    $fullPath = [IO.Path]::GetFullPath($Path)
    $pathRoot = [IO.Path]::GetPathRoot($fullPath)
    $currentPath = $pathRoot
    foreach ($segment in @($fullPath.Substring($pathRoot.Length) -split '[\\/]')) {
        if ([string]::IsNullOrEmpty($segment)) {
            continue
        }
        $currentPath = Join-Path $currentPath $segment
        if ($null -ne $FileSystemProbe) {
            $probeResult = & $FileSystemProbe $currentPath
            if ($null -eq $probeResult -or -not [bool]$probeResult.exists) {
                break
            }
            $attributes = [IO.FileAttributes]$probeResult.attributes
        }
        else {
            if (-not [IO.Directory]::Exists($currentPath) -and
                -not [IO.File]::Exists($currentPath)) {
                break
            }
            $item = Get-Item -LiteralPath $currentPath -Force
            $attributes = $item.Attributes
        }
        if (($attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            return $true
        }
    }
    return $false
}

function Write-TenantLifecycleEvidence {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][string]$RunDirectory,
        [Parameter(Mandatory)][string]$RelativePath,
        [Parameter(Mandatory)]
        [ValidateSet('Assessment', 'ExecutionManifest', 'Approval', 'ActionEvidence', 'ReadBack', 'Summary')]
        [string]$Kind,
        [Parameter(Mandatory)][object]$InputObject
    )

    try {
        if (-not [IO.Path]::IsPathRooted($RunDirectory)) {
            throw [IO.InvalidDataException]::new('TenantLifecycle.Evidence.Root')
        }
        $root = [IO.Path]::GetFullPath($RunDirectory).TrimEnd(
            [IO.Path]::DirectorySeparatorChar,
            [IO.Path]::AltDirectorySeparatorChar
        )
    }
    catch {
        throw [IO.InvalidDataException]::new('TenantLifecycle.Evidence.Root')
    }

    $allowedPath = switch ($Kind) {
        'Assessment' { $RelativePath -ceq 'assessment.json' }
        'ExecutionManifest' { $RelativePath -ceq 'execution-manifest.json' }
        'Approval' { $RelativePath -ceq 'approvals.json' }
        'ActionEvidence' { $RelativePath -cmatch '^actions/[A-Za-z0-9][A-Za-z0-9._:-]*\.json$' }
        'ReadBack' { $RelativePath -ceq 'read-back.json' }
        'Summary' { $RelativePath -ceq 'summary.json' }
    }
    if (-not $allowedPath -or [IO.Path]::IsPathRooted($RelativePath) -or $RelativePath.Contains('\')) {
        throw [IO.InvalidDataException]::new('TenantLifecycle.Evidence.Path')
    }
    try {
        Test-TenantLifecycleContract `
            -Kind $Kind `
            -InputObject $InputObject |
            Out-Null
        if (-not (Test-TenantLifecycleEvidencePropertyBoundary -Value $InputObject)) {
            throw [IO.InvalidDataException]::new('TenantLifecycle.Evidence.Invalid')
        }
        if ($Kind -ceq 'ExecutionManifest') {
            $calculatedDigest = Get-TenantLifecycleExecutionManifestDigest -Manifest $InputObject
            if (-not [string]::Equals([string]$InputObject.digest, $calculatedDigest, [StringComparison]::Ordinal)) {
                throw [IO.InvalidDataException]::new('TenantLifecycle.Evidence.Invalid')
            }
        }
        $canonical = ConvertTo-CanonicalJsonValue -Value $InputObject -RemainingDepth 30
        $json = ($canonical | ConvertTo-Json -Depth 30 -Compress) + "`n"
        $bytes = [Text.UTF8Encoding]::new($false, $true).GetBytes($json)
    }
    catch {
        throw [IO.InvalidDataException]::new('TenantLifecycle.Evidence.Invalid')
    }

    if ($Kind -ceq 'ActionEvidence') {
        $expectedActionPath = "actions/$([string]$InputObject.actionId).json"
        if ($RelativePath -cne $expectedActionPath) {
            throw [IO.InvalidDataException]::new('TenantLifecycle.Evidence.Path')
        }
    }

    try {
        $relativeNativePath = $RelativePath.Replace('/', [IO.Path]::DirectorySeparatorChar)
        $targetPath = [IO.Path]::GetFullPath((Join-Path $root $relativeNativePath))
    }
    catch {
        throw [IO.InvalidDataException]::new('TenantLifecycle.Evidence.Path')
    }
    $rootPrefix = $root + [IO.Path]::DirectorySeparatorChar
    if (-not $targetPath.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw [IO.InvalidDataException]::new('TenantLifecycle.Evidence.Path')
    }

    try {
        $rootHasReparsePoint = Test-TenantLifecycleEvidenceReparsePath -Path $root
    }
    catch {
        throw [IO.InvalidDataException]::new('TenantLifecycle.Evidence.Root')
    }
    if ($rootHasReparsePoint) {
        throw [IO.InvalidDataException]::new('TenantLifecycle.Evidence.ReparsePoint')
    }

    $rootIsInvalid = $false
    $rootIsReparsePoint = $false
    try {
        if ([IO.File]::Exists($root)) {
            $rootIsInvalid = $true
        }
        elseif (-not [IO.Directory]::Exists($root)) {
            [IO.Directory]::CreateDirectory($root) | Out-Null
        }
        if (-not $rootIsInvalid) {
            $rootItem = Get-Item -LiteralPath $root -Force -ErrorAction Stop
            $rootIsInvalid = -not [bool]$rootItem.PSIsContainer
            $rootIsReparsePoint =
                ($rootItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0
        }
    }
    catch {
        throw [IO.InvalidDataException]::new('TenantLifecycle.Evidence.Root')
    }
    if ($rootIsInvalid) {
        throw [IO.InvalidDataException]::new('TenantLifecycle.Evidence.Root')
    }
    if ($rootIsReparsePoint) {
        throw [IO.InvalidDataException]::new('TenantLifecycle.Evidence.ReparsePoint')
    }

    $targetDirectory = [IO.Path]::GetDirectoryName($targetPath)
    if (-not [string]::Equals($targetDirectory, $root, [StringComparison]::OrdinalIgnoreCase)) {
        $relativeDirectory = $targetDirectory.Substring($rootPrefix.Length)
        $currentDirectory = $root
        foreach ($segment in @($relativeDirectory -split '[\\/]')) {
            if ([string]::IsNullOrEmpty($segment)) {
                continue
            }
            $actionDirectoryIsInvalid = $false
            $actionDirectoryIsReparsePoint = $false
            try {
                $currentDirectory = Join-Path $currentDirectory $segment
                if ([IO.File]::Exists($currentDirectory)) {
                    $actionDirectoryIsInvalid = $true
                }
                elseif (-not [IO.Directory]::Exists($currentDirectory)) {
                    [IO.Directory]::CreateDirectory($currentDirectory) | Out-Null
                }
                if (-not $actionDirectoryIsInvalid) {
                    $item = Get-Item -LiteralPath $currentDirectory -Force -ErrorAction Stop
                    $actionDirectoryIsInvalid = -not [bool]$item.PSIsContainer
                    $actionDirectoryIsReparsePoint =
                        ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0
                }
            }
            catch {
                throw [IO.InvalidDataException]::new(
                    'TenantLifecycle.Evidence.ActionDirectory'
                )
            }
            if ($actionDirectoryIsInvalid) {
                throw [IO.InvalidDataException]::new(
                    'TenantLifecycle.Evidence.ActionDirectory'
                )
            }
            if ($actionDirectoryIsReparsePoint) {
                throw [IO.InvalidDataException]::new('TenantLifecycle.Evidence.ReparsePoint')
            }
        }
    }

    try {
        return Write-TenantLifecycleAtomicFile -Path $targetPath -Bytes $bytes
    }
    catch {
        if ($_.Exception.Message -ceq 'TenantLifecycle.Evidence.Exists') {
            throw
        }
        throw [IO.IOException]::new('TenantLifecycle.Evidence.Write')
    }
}
