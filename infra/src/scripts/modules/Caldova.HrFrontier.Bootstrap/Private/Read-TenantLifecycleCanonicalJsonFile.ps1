function Skip-TenantLifecycleJsonWhitespace {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][ref]$Index
    )

    while ($Index.Value -lt $Text.Length -and
        [char]::IsWhiteSpace($Text[$Index.Value])) {
        $Index.Value++
    }
}

function Read-TenantLifecycleJsonStringToken {
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][ref]$Index
    )

    if ($Index.Value -ge $Text.Length -or $Text[$Index.Value] -ne '"') {
        throw [IO.InvalidDataException]::new()
    }
    $Index.Value++
    $builder = [Text.StringBuilder]::new()
    while ($Index.Value -lt $Text.Length) {
        $character = $Text[$Index.Value]
        $Index.Value++
        if ($character -eq '"') {
            return $builder.ToString()
        }
        if ([int]$character -lt 0x20) {
            throw [IO.InvalidDataException]::new()
        }
        if ($character -ne '\') {
            [void]$builder.Append($character)
            continue
        }
        if ($Index.Value -ge $Text.Length) {
            throw [IO.InvalidDataException]::new()
        }
        $escape = $Text[$Index.Value]
        $Index.Value++
        switch ($escape) {
            '"' { [void]$builder.Append('"') }
            '\' { [void]$builder.Append('\') }
            '/' { [void]$builder.Append('/') }
            'b' { [void]$builder.Append([char]0x08) }
            'f' { [void]$builder.Append([char]0x0C) }
            'n' { [void]$builder.Append([char]0x0A) }
            'r' { [void]$builder.Append([char]0x0D) }
            't' { [void]$builder.Append([char]0x09) }
            'u' {
                if ($Index.Value + 4 -gt $Text.Length) {
                    throw [IO.InvalidDataException]::new()
                }
                $hex = $Text.Substring($Index.Value, 4)
                if ($hex -cnotmatch '^[0-9a-fA-F]{4}$') {
                    throw [IO.InvalidDataException]::new()
                }
                $codeUnit = [Convert]::ToInt32($hex, 16)
                $Index.Value += 4
                if ($codeUnit -ge 0xD800 -and $codeUnit -le 0xDBFF) {
                    if ($Index.Value + 6 -gt $Text.Length -or
                        $Text[$Index.Value] -ne '\' -or
                        $Text[$Index.Value + 1] -ne 'u') {
                        throw [IO.InvalidDataException]::new()
                    }
                    $lowHex = $Text.Substring($Index.Value + 2, 4)
                    if ($lowHex -cnotmatch '^[0-9a-fA-F]{4}$') {
                        throw [IO.InvalidDataException]::new()
                    }
                    $lowCodeUnit = [Convert]::ToInt32($lowHex, 16)
                    if ($lowCodeUnit -lt 0xDC00 -or
                        $lowCodeUnit -gt 0xDFFF) {
                        throw [IO.InvalidDataException]::new()
                    }
                    $Index.Value += 6
                    $codePoint = 0x10000 +
                        (($codeUnit - 0xD800) * 0x400) +
                        ($lowCodeUnit - 0xDC00)
                    [void]$builder.Append(
                        [char]::ConvertFromUtf32($codePoint)
                    )
                }
                elseif ($codeUnit -ge 0xDC00 -and
                    $codeUnit -le 0xDFFF) {
                    throw [IO.InvalidDataException]::new()
                }
                else {
                    [void]$builder.Append([char]$codeUnit)
                }
            }
            default {
                throw [IO.InvalidDataException]::new()
            }
        }
    }
    throw [IO.InvalidDataException]::new()
}

function Assert-TenantLifecycleJsonValueToken {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][ref]$Index,
        [ValidateRange(0, 100)][int]$Depth = 0
    )

    if ($Depth -ge 100) {
        throw [IO.InvalidDataException]::new()
    }
    Skip-TenantLifecycleJsonWhitespace -Text $Text -Index $Index
    if ($Index.Value -ge $Text.Length) {
        throw [IO.InvalidDataException]::new()
    }
    $character = $Text[$Index.Value]
    if ($character -eq '{') {
        $Index.Value++
        $propertyNames = [Collections.Generic.HashSet[string]]::new(
            [StringComparer]::Ordinal
        )
        Skip-TenantLifecycleJsonWhitespace -Text $Text -Index $Index
        if ($Index.Value -lt $Text.Length -and
            $Text[$Index.Value] -eq '}') {
            $Index.Value++
            return
        }
        while ($true) {
            Skip-TenantLifecycleJsonWhitespace -Text $Text -Index $Index
            $propertyName = Read-TenantLifecycleJsonStringToken `
                -Text $Text `
                -Index $Index
            if (-not $propertyNames.Add($propertyName)) {
                throw [IO.InvalidDataException]::new()
            }
            Skip-TenantLifecycleJsonWhitespace -Text $Text -Index $Index
            if ($Index.Value -ge $Text.Length -or
                $Text[$Index.Value] -ne ':') {
                throw [IO.InvalidDataException]::new()
            }
            $Index.Value++
            Assert-TenantLifecycleJsonValueToken `
                -Text $Text `
                -Index $Index `
                -Depth ($Depth + 1)
            Skip-TenantLifecycleJsonWhitespace -Text $Text -Index $Index
            if ($Index.Value -ge $Text.Length) {
                throw [IO.InvalidDataException]::new()
            }
            if ($Text[$Index.Value] -eq '}') {
                $Index.Value++
                return
            }
            if ($Text[$Index.Value] -ne ',') {
                throw [IO.InvalidDataException]::new()
            }
            $Index.Value++
        }
    }
    if ($character -eq '[') {
        $Index.Value++
        Skip-TenantLifecycleJsonWhitespace -Text $Text -Index $Index
        if ($Index.Value -lt $Text.Length -and
            $Text[$Index.Value] -eq ']') {
            $Index.Value++
            return
        }
        while ($true) {
            Assert-TenantLifecycleJsonValueToken `
                -Text $Text `
                -Index $Index `
                -Depth ($Depth + 1)
            Skip-TenantLifecycleJsonWhitespace -Text $Text -Index $Index
            if ($Index.Value -ge $Text.Length) {
                throw [IO.InvalidDataException]::new()
            }
            if ($Text[$Index.Value] -eq ']') {
                $Index.Value++
                return
            }
            if ($Text[$Index.Value] -ne ',') {
                throw [IO.InvalidDataException]::new()
            }
            $Index.Value++
        }
    }
    if ($character -eq '"') {
        $null = Read-TenantLifecycleJsonStringToken `
            -Text $Text `
            -Index $Index
        return
    }
    foreach ($literal in @('true', 'false', 'null')) {
        if ($Text.Length - $Index.Value -ge $literal.Length -and
            [StringComparer]::Ordinal.Equals(
                $Text.Substring($Index.Value, $literal.Length),
                $literal
            )) {
            $Index.Value += $literal.Length
            return
        }
    }
    $numberMatch = [regex]::Match(
        $Text.Substring($Index.Value),
        '^-?(?:0|[1-9][0-9]*)(?:[.][0-9]+)?(?:[eE][+-]?[0-9]+)?',
        [Text.RegularExpressions.RegexOptions]::CultureInvariant
    )
    if (-not $numberMatch.Success) {
        throw [IO.InvalidDataException]::new()
    }
    $Index.Value += $numberMatch.Length
}

function Assert-TenantLifecycleJsonHasUniqueProperties {
    param([Parameter(Mandatory)][string]$Text)

    $index = 0
    Assert-TenantLifecycleJsonValueToken `
        -Text $Text `
        -Index ([ref]$index)
    Skip-TenantLifecycleJsonWhitespace `
        -Text $Text `
        -Index ([ref]$index)
    if ($index -ne $Text.Length) {
        throw [IO.InvalidDataException]::new()
    }
}

function Resolve-TenantLifecycleOrdinalChildPath {
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string[]]$Segments
    )

    $currentPath = $Root
    foreach ($segment in $Segments) {
        if (-not [IO.Directory]::Exists($currentPath)) {
            throw [IO.InvalidDataException]::new()
        }
        $matchingItems = @(
            Get-ChildItem `
                -LiteralPath $currentPath `
                -Force `
                -ErrorAction Stop |
                Where-Object {
                    [StringComparer]::OrdinalIgnoreCase.Equals(
                        [string]$_.Name,
                        $segment
                    )
                }
        )
        if ($matchingItems.Count -ne 1 -or
            -not [StringComparer]::Ordinal.Equals(
                [string]$matchingItems[0].Name,
                $segment
            ) -or
            ($matchingItems[0].Attributes -band
                [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw [IO.InvalidDataException]::new()
        }
        $currentPath = [string]$matchingItems[0].FullName
    }
    [IO.Path]::GetFullPath($currentPath)
}

function Read-TenantLifecycleCanonicalJsonFile {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$ContainmentRoot,
        [Parameter(Mandatory)][string]$ExpectedRelativePath,
        [ValidatePattern('^[0-9a-f]{64}$')]
        [string]$ExpectedDigest
    )

    try {
        if (-not [IO.Path]::IsPathRooted($ContainmentRoot) -or
            -not [IO.Path]::IsPathRooted($Path) -or
            [IO.Path]::IsPathRooted($ExpectedRelativePath) -or
            $ExpectedRelativePath.Contains('\')) {
            throw [IO.InvalidDataException]::new()
        }
        $relativeSegments = @($ExpectedRelativePath -split '/')
        if ($relativeSegments.Count -eq 0 -or
            @(
                $relativeSegments |
                    Where-Object {
                        [string]::IsNullOrEmpty($_) -or
                        $_ -ceq '.' -or
                        $_ -ceq '..'
                    }
            ).Count -ne 0 -or
            ($relativeSegments -join '/') -cne $ExpectedRelativePath) {
            throw [IO.InvalidDataException]::new()
        }

        $root = [IO.Path]::GetFullPath($ContainmentRoot)
        $pathRoot = [IO.Path]::GetPathRoot($root)
        if ($root.Length -gt $pathRoot.Length) {
            $root = $root.TrimEnd(
                [IO.Path]::DirectorySeparatorChar,
                [IO.Path]::AltDirectorySeparatorChar
            )
        }
        $nativeRelativePath = $ExpectedRelativePath.Replace(
            '/',
            [IO.Path]::DirectorySeparatorChar
        )
        $expectedPath = [IO.Path]::GetFullPath(
            (Join-Path $root $nativeRelativePath)
        )
        $suppliedPath = [IO.Path]::GetFullPath($Path)
        $rootPrefix = $root + [IO.Path]::DirectorySeparatorChar
        if (-not $expectedPath.StartsWith(
                $rootPrefix,
                [StringComparison]::OrdinalIgnoreCase
            ) -or
            -not [StringComparer]::Ordinal.Equals(
                $expectedPath,
                $suppliedPath
            ) -or
            -not [IO.Directory]::Exists($root) -or
            (Test-TenantLifecycleEvidenceReparsePath -Path $root)) {
            throw [IO.InvalidDataException]::new()
        }
        $rootItem = Get-Item -LiteralPath $root -Force -ErrorAction Stop
        $resolvedPath = Resolve-TenantLifecycleOrdinalChildPath `
            -Root $root `
            -Segments $relativeSegments
        if (-not [StringComparer]::Ordinal.Equals(
                $expectedPath,
                $resolvedPath
            ) -or
            -not [IO.File]::Exists($resolvedPath) -or
            (Test-TenantLifecycleEvidenceReparsePath `
                -Path $resolvedPath)) {
            throw [IO.InvalidDataException]::new()
        }
        $fileItem = Get-Item `
            -LiteralPath $resolvedPath `
            -Force `
            -ErrorAction Stop
        if (-not [bool]$rootItem.PSIsContainer -or
            [bool]$fileItem.PSIsContainer -or
            ($fileItem.Attributes -band
                [IO.FileAttributes]::ReparsePoint) -ne 0 -or
            ($fileItem.Attributes -band
                [IO.FileAttributes]::Device) -ne 0) {
            throw [IO.InvalidDataException]::new()
        }

        $bytes = [IO.File]::ReadAllBytes($resolvedPath)
        if ($bytes.Length -eq 0 -or
            ($bytes.Length -ge 3 -and
                $bytes[0] -eq 0xEF -and
                $bytes[1] -eq 0xBB -and
                $bytes[2] -eq 0xBF) -or
            $bytes[-1] -ne 0x0A -or
            ($bytes.Length -gt 1 -and $bytes[-2] -eq 0x0A) -or
            $bytes -contains 0x0D) {
            throw [IO.InvalidDataException]::new()
        }
        $text = [Text.UTF8Encoding]::new(
            $false,
            $true
        ).GetString($bytes)
        Assert-TenantLifecycleJsonHasUniqueProperties -Text $text
        $value = ConvertFrom-TenantLifecycleJson -InputObject $text
        if ($null -eq $value -or
            $value -is [string] -or
            $value -is [System.Array] -or
            $value -is [Collections.IDictionary] -or
            $value.GetType().IsPrimitive) {
            throw [IO.InvalidDataException]::new()
        }
        if ($ExpectedRelativePath -cmatch (
                '^stage-results/(Workstation|PrivateBoundary|Foundation|' +
                'DevDelivery|ReadBack|Acceptance|TenantReplica)[.]json$'
            )) {
            Test-TenantLifecycleContract `
                -Kind StageResult `
                -InputObject $value |
                Out-Null
        }
        $canonicalText = ConvertTo-TenantLifecycleCanonicalJson `
            -InputObject $value
        $canonicalBytes = [Text.UTF8Encoding]::new(
            $false,
            $true
        ).GetBytes($canonicalText)
        if ([Convert]::ToBase64String($bytes) -cne
            [Convert]::ToBase64String($canonicalBytes)) {
            throw [IO.InvalidDataException]::new()
        }

        $algorithm = [Security.Cryptography.SHA256]::Create()
        try {
            $digest = -join @(
                $algorithm.ComputeHash($bytes) |
                    ForEach-Object { $_.ToString('x2') }
            )
        }
        finally {
            $algorithm.Dispose()
        }
        if ($PSBoundParameters.ContainsKey('ExpectedDigest') -and
            -not [StringComparer]::Ordinal.Equals(
                $ExpectedDigest,
                $digest
            )) {
            throw [IO.InvalidDataException]::new()
        }

        [pscustomobject][ordered]@{
            relativePath = $ExpectedRelativePath
            path = $resolvedPath
            digest = $digest
            value = $value
        }
    }
    catch {
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.CanonicalJson.Invalid'
        )
    }
}
