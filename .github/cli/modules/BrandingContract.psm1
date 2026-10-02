Set-StrictMode -Version Latest

function New-BrandingPatternSet {
    $first = -join [char[]](71, 101, 111, 114, 103)
    $second = -join [char[]](70, 105, 115, 99, 104, 101, 114)
    $initials = $first[0] + $second[0]
    $ignoreCase = [Text.RegularExpressions.RegexOptions]::IgnoreCase -bor
        [Text.RegularExpressions.RegexOptions]::CultureInvariant
    $caseSensitive = [Text.RegularExpressions.RegexOptions]::CultureInvariant

    [ordered]@{
        L1 = [regex]::new(
            [regex]::Escape($first + ' ' + $second),
            $ignoreCase
        )
        L2 = [regex]::new(
            [regex]::Escape($first + $second),
            $ignoreCase
        )
        L3 = [regex]::new(
            ('(?<![A-Za-z0-9]){0}(?![A-Za-z0-9])' -f
                [regex]::Escape($initials)),
            $ignoreCase
        )
        L4 = [regex]::new(
            ('(?<![A-Za-z0-9]){0}-' -f
                [regex]::Escape($initials.ToLowerInvariant())),
            $ignoreCase
        )
        L5 = [regex]::new(
            ('(?<![A-Za-z0-9]){0}_' -f
                [regex]::Escape($initials.ToLowerInvariant())),
            $ignoreCase
        )
        L6 = [regex]::new(
            ('(?<![A-Za-z0-9]){0}(?=[A-Z])' -f
                [regex]::Escape($initials.ToLowerInvariant())),
            $caseSensitive
        )
        L7 = [regex]::new(
            ('(?<![A-Za-z0-9]){0}(?=[A-Z])' -f
                [regex]::Escape(
                    $initials[0] + $initials[1].ToString().ToLowerInvariant()
                )),
            $caseSensitive
        )
    }
}

function Invoke-BrandingGitIndexQuery {
    param([Parameter(Mandatory)][string]$RepositoryRoot)

    $gitPath = @(
        (Get-Command git.exe -CommandType Application -ErrorAction SilentlyContinue |
            Select-Object -First 1).Source
        'C:\Program Files\Git\cmd\git.exe'
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) } |
        Select-Object -First 1
    if (-not $gitPath) { throw 'git-error: git.exe is unavailable.' }

    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $gitPath
    $start.Arguments = 'ls-files -z --stage'
    $start.WorkingDirectory = $RepositoryRoot
    $start.UseShellExecute = $false
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    $stream = [IO.MemoryStream]::new()
    try {
        if (-not $process.Start()) { throw 'git-error: git.exe did not start.' }
        $errorTask = $process.StandardError.ReadToEndAsync()
        $process.StandardOutput.BaseStream.CopyTo($stream)
        $process.WaitForExit()
        $stderr = $errorTask.Result
        if ($process.ExitCode -ne 0) {
            throw ("git-error: git ls-files failed with exit code {0}: {1}" -f
                $process.ExitCode, $stderr.Trim())
        }
        [Convert]::ToBase64String($stream.ToArray())
    }
    finally {
        $stream.Dispose()
        $process.Dispose()
    }
}

function ConvertFrom-BrandingGitIndexBytes {
    param([Parameter(Mandatory)][byte[]]$Bytes)

    try {
        $text = [Text.UTF8Encoding]::new($false, $true).GetString($Bytes)
    }
    catch {
        throw 'git-error: Git returned a path inventory that is not valid UTF-8.'
    }

    $entries = [Collections.Generic.List[object]]::new()
    foreach ($record in $text.Split([char]0)) {
        if ([string]::IsNullOrEmpty($record)) { continue }
        $separator = $record.IndexOf([char]9)
        if ($separator -lt 0) {
            throw 'index-record-error: Git index record has no path separator.'
        }
        $metadata = $record.Substring(0, $separator)
        $path = $record.Substring($separator + 1)
        $match = [regex]::Match(
            $metadata,
            '^(?<Mode>[0-9]{6}) (?<Object>[0-9a-f]{40,64}) (?<Stage>[0-3])$',
            [Text.RegularExpressions.RegexOptions]::CultureInvariant
        )
        if (-not $match.Success -or [string]::IsNullOrEmpty($path)) {
            throw 'index-record-error: Git index record is malformed.'
        }
        [void]$entries.Add([pscustomobject]@{
            Mode = $match.Groups['Mode'].Value
            Stage = [int]$match.Groups['Stage'].Value
            Path = $path
        })
    }
    @($entries)
}

function Test-BrandingBinarySignature {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [byte[]]$Bytes
    )

    $signatures = @(
        [byte[]](0x25, 0x50, 0x44, 0x46, 0x2D),
        [byte[]](0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A),
        [byte[]](0xFF, 0xD8, 0xFF),
        [byte[]](0x47, 0x49, 0x46, 0x38),
        [byte[]](0x50, 0x4B, 0x03, 0x04),
        [byte[]](0x50, 0x4B, 0x05, 0x06),
        [byte[]](0x50, 0x4B, 0x07, 0x08)
    )
    foreach ($signature in $signatures) {
        if ($Bytes.Length -lt $signature.Length) { continue }
        $equal = $true
        for ($index = 0; $index -lt $signature.Length; $index++) {
            if ($Bytes[$index] -ne $signature[$index]) {
                $equal = $false
                break
            }
        }
        if ($equal) { return $true }
    }
    $false
}

function ConvertTo-BrandingDisplayPath {
    param([Parameter(Mandatory)][string]$Path)

    $builder = [Text.StringBuilder]::new()
    foreach ($character in $Path.ToCharArray()) {
        if ([char]::IsControl($character)) {
            [void]$builder.Append(('\u{0:x4}' -f [int]$character))
        }
        else {
            [void]$builder.Append($character)
        }
    }
    $builder.ToString()
}

function Test-BrandingReparsePointInPath {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$RepositoryRoot
    )

    $fullPath = [IO.Path]::GetFullPath($Path)
    $root = [IO.Path]::GetFullPath($RepositoryRoot).TrimEnd('\')
    $rootPrefix = $root + '\'
    if (-not $fullPath.Equals(
        $root,
        [StringComparison]::OrdinalIgnoreCase
    ) -and -not $fullPath.StartsWith(
        $rootPrefix,
        [StringComparison]::OrdinalIgnoreCase
    )) {
        throw 'path-error: Tracked path is outside RepositoryRoot.'
    }

    $paths = [Collections.Generic.List[string]]::new()
    [void]$paths.Add($root)
    $relativePath = $fullPath.Substring($root.Length).TrimStart('\')
    $currentPath = $root
    foreach ($component in $relativePath.Split(
        [char]'\',
        [StringSplitOptions]::RemoveEmptyEntries
    )) {
        $currentPath = Join-Path $currentPath $component
        [void]$paths.Add($currentPath)
    }

    foreach ($currentPath in $paths) {
        try {
            $item = Get-Item -LiteralPath $currentPath -Force -ErrorAction Stop
        }
        catch [Management.Automation.ItemNotFoundException] {
            $item = $null
        }
        if ($null -ne $item -and
            ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            return $true
        }
    }
    $false
}

function Get-BrandingCanonicalMatches {
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Content,
        [Parameter(Mandatory)][Collections.IDictionary]$Patterns
    )

    $matches = [Collections.Generic.List[object]]::new()
    $specificInitialMatches = [Collections.Generic.HashSet[int]]::new()
    foreach ($patternClass in @('L1', 'L2', 'L4', 'L5', 'L6', 'L7')) {
        foreach ($match in $Patterns[$patternClass].Matches($Content)) {
            [void]$matches.Add([pscustomobject]@{
                PatternClass = $patternClass
                Index = $match.Index
                Length = $match.Length
            })
            if ($patternClass -in @('L4', 'L5')) {
                [void]$specificInitialMatches.Add($match.Index)
            }
        }
    }
    foreach ($match in $Patterns['L3'].Matches($Content)) {
        if ($specificInitialMatches.Contains($match.Index)) { continue }
        [void]$matches.Add([pscustomobject]@{
            PatternClass = 'L3'
            Index = $match.Index
            Length = $match.Length
        })
    }
    @($matches | Sort-Object Index, PatternClass)
}

function Test-BrandingExactProperties {
    param(
        [Parameter(Mandatory)][object]$InputObject,
        [Parameter(Mandatory)][string[]]$Expected
    )

    if ($null -eq $InputObject -or $InputObject -is [string] -or
        $InputObject -is [ValueType]) {
        return $false
    }
    $actual = @($InputObject.PSObject.Properties.Name)
    if ($actual.Count -ne $Expected.Count) { return $false }
    $expectedSet = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::Ordinal
    )
    foreach ($name in $Expected) { [void]$expectedSet.Add($name) }
    foreach ($name in $actual) {
        if (-not $expectedSet.Contains($name)) { return $false }
    }
    $true
}

function Get-BrandingSha256 {
    param([Parameter(Mandatory)][byte[]]$Bytes)

    $sha256 = [Security.Cryptography.SHA256]::Create()
    try {
        ([BitConverter]::ToString($sha256.ComputeHash($Bytes))).
            Replace('-', '').
            ToLowerInvariant()
    }
    finally {
        $sha256.Dispose()
    }
}

function Get-RepositoryBrandingScan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [AllowEmptyString()][string]$EvidenceExceptionManifestPath
    )

    $root = [IO.Path]::GetFullPath($RepositoryRoot)
    if (-not (Test-Path -LiteralPath $root -PathType Container)) {
        throw 'git-error: RepositoryRoot is not a directory.'
    }
    $rootPrefix = $root.TrimEnd('\') + '\'
    $patterns = New-BrandingPatternSet
    $raw = [Convert]::FromBase64String(
        (Invoke-BrandingGitIndexQuery -RepositoryRoot $root)
    )
    $entries = @(ConvertFrom-BrandingGitIndexBytes -Bytes $raw)
    $files = [Collections.Generic.List[object]]::new()
    $findings = [Collections.Generic.List[object]]::new()
    $findingKeys = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::Ordinal
    )
    $seenPaths = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::Ordinal
    )
    $entryByPath = [Collections.Generic.Dictionary[string, object]]::new(
        [StringComparer]::Ordinal
    )
    $contentMatchesByPath =
        [Collections.Generic.Dictionary[string, object[]]]::new(
            [StringComparer]::Ordinal
        )

    function Add-Finding {
        param([string]$Path, [string]$PatternClass)
        $displayPath = ConvertTo-BrandingDisplayPath -Path $Path
        if ($findingKeys.Add($displayPath + [char]0 + $PatternClass)) {
            [void]$findings.Add([pscustomobject]@{
                Path = $displayPath
                PatternClass = $PatternClass
            })
        }
    }

    foreach ($entry in $entries) {
        $relativePath = [string]$entry.Path
        if ($entry.Stage -eq 0 -and -not $entryByPath.ContainsKey($relativePath)) {
            $entryByPath.Add($relativePath, $entry)
        }
        foreach ($pattern in $patterns.GetEnumerator()) {
            if ($pattern.Value.IsMatch($relativePath)) {
                Add-Finding -Path $relativePath -PatternClass $pattern.Key
            }
        }
        if ($entry.Stage -ne 0) {
            Add-Finding -Path $relativePath -PatternClass 'index-stage-error'
            continue
        }
        if (-not $seenPaths.Add($relativePath)) {
            Add-Finding -Path $relativePath -PatternClass 'index-record-error'
            continue
        }

        if ($entry.Mode -ceq '120000') {
            [void]$files.Add([pscustomobject]@{
                Path = ConvertTo-BrandingDisplayPath -Path $relativePath
                Classification = 'tracked-link'
            })
            Add-Finding -Path $relativePath -PatternClass 'tracked-link'
            continue
        }
        if ($entry.Mode -notin @('100644', '100755')) {
            [void]$files.Add([pscustomobject]@{
                Path = ConvertTo-BrandingDisplayPath -Path $relativePath
                Classification = 'unsupported-tracked-mode'
            })
            Add-Finding -Path $relativePath -PatternClass 'unsupported-tracked-mode'
            continue
        }

        try {
            $absolutePath = [IO.Path]::GetFullPath(
                (Join-Path $root $relativePath.Replace('/', '\'))
            )
            if (-not $absolutePath.StartsWith(
                $rootPrefix,
                [StringComparison]::OrdinalIgnoreCase
            )) {
                Add-Finding -Path $relativePath -PatternClass 'path-error'
                continue
            }
        }
        catch {
            Add-Finding -Path $relativePath -PatternClass 'path-error'
            continue
        }

        try {
            if (Test-BrandingReparsePointInPath `
                -Path $absolutePath `
                -RepositoryRoot $root) {
                [void]$files.Add([pscustomobject]@{
                    Path = ConvertTo-BrandingDisplayPath -Path $relativePath
                    Classification = 'tracked-link'
                })
                Add-Finding -Path $relativePath -PatternClass 'tracked-link'
                continue
            }
        }
        catch {
            Add-Finding -Path $relativePath -PatternClass 'path-error'
            continue
        }

        try {
            $bytes = [IO.File]::ReadAllBytes($absolutePath)
        }
        catch {
            Add-Finding -Path $relativePath -PatternClass 'read-error'
            continue
        }

        if (Test-BrandingBinarySignature -Bytes $bytes) {
            [void]$files.Add([pscustomobject]@{
                Path = ConvertTo-BrandingDisplayPath -Path $relativePath
                Classification = 'tracked-binary'
            })
            continue
        }

        try {
            $content = [Text.UTF8Encoding]::new($false, $true).GetString($bytes)
            if ($content.IndexOf([char]0) -ge 0 -or
                @($content.ToCharArray() | Where-Object {
                    [char]::IsControl($_) -and $_ -notin @(
                        [char]9, [char]10, [char]12, [char]13
                    )
                }).Count -gt 0) {
                throw 'Unclassified control byte.'
            }
        }
        catch {
            Add-Finding -Path $relativePath -PatternClass 'classification-error'
            continue
        }

        [void]$files.Add([pscustomobject]@{
            Path = ConvertTo-BrandingDisplayPath -Path $relativePath
            Classification = 'tracked-text'
        })
        $contentMatches = @(
            Get-BrandingCanonicalMatches -Content $content -Patterns $patterns
        )
        $contentMatchesByPath[$relativePath] = $contentMatches
        foreach ($patternClass in @(
            $contentMatches | Select-Object -ExpandProperty PatternClass -Unique
        )) {
            Add-Finding -Path $relativePath -PatternClass $patternClass
        }
    }

    $approvedEvidence = [Collections.Generic.List[object]]::new()
    $suppressionKeys = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::Ordinal
    )
    $manifestRelativePath =
        '.github/cli/config/branding-evidence-exceptions.json'
    $manifestWasExplicit = $PSBoundParameters.ContainsKey(
        'EvidenceExceptionManifestPath'
    )
    $manifestDisabled = $manifestWasExplicit -and
        [string]::IsNullOrEmpty($EvidenceExceptionManifestPath)
    $manifestAbsolutePath = if ($manifestWasExplicit -and -not $manifestDisabled) {
        try {
            [IO.Path]::GetFullPath($EvidenceExceptionManifestPath)
        }
        catch {
            $null
        }
    }
    else {
        Join-Path $root $manifestRelativePath.Replace('/', '\')
    }

    if (-not $manifestDisabled -and $null -ne $manifestAbsolutePath) {
        $manifestExists = Test-Path -LiteralPath $manifestAbsolutePath -PathType Leaf
        $defaultManifestAbsent = -not $manifestWasExplicit -and -not $manifestExists
        if (-not $defaultManifestAbsent) {
            $manifestValid = $true
            try {
                $manifestFullPath = [IO.Path]::GetFullPath($manifestAbsolutePath)
                if (-not $manifestFullPath.StartsWith(
                    $rootPrefix,
                    [StringComparison]::OrdinalIgnoreCase
                )) {
                    throw 'Manifest is outside RepositoryRoot.'
                }
                $manifestRelativePath = $manifestFullPath.
                    Substring($rootPrefix.Length).
                    Replace('\', '/')
                if (-not $entryByPath.ContainsKey($manifestRelativePath)) {
                    throw 'Manifest is not tracked.'
                }
                $manifestEntry = $entryByPath[$manifestRelativePath]
                if ($manifestEntry.Stage -ne 0 -or
                    $manifestEntry.Mode -notin @('100644', '100755')) {
                    throw 'Manifest is not a regular tracked file.'
                }
                $manifestBytes = [IO.File]::ReadAllBytes($manifestFullPath)
                $manifestText = [Text.UTF8Encoding]::new(
                    $false,
                    $true
                ).GetString($manifestBytes)
                $manifest = $manifestText | ConvertFrom-Json -ErrorAction Stop
                if (-not (Test-BrandingExactProperties -InputObject $manifest `
                    -Expected @('schemaVersion', 'exceptions'))) {
                    throw 'Manifest root schema is invalid.'
                }
                if ($manifest.schemaVersion -cne '1.0' -or
                    $manifest.exceptions -isnot [Array]) {
                    throw 'Manifest root values are invalid.'
                }

                $records = @($manifest.exceptions)
                $recordPaths = [Collections.Generic.HashSet[string]]::new(
                    [StringComparer]::Ordinal
                )
                $candidates = [Collections.Generic.List[object]]::new()
                foreach ($record in $records) {
                    if (-not (Test-BrandingExactProperties -InputObject $record `
                        -Expected @(
                            'path',
                            'sha256',
                            'patternClass',
                            'count',
                            'provenance',
                            'rationale'
                        ))) {
                        throw 'Manifest record schema is invalid.'
                    }
                    if ($record.path -isnot [string] -or
                        $record.sha256 -isnot [string] -or
                        $record.patternClass -isnot [string] -or
                        $record.provenance -isnot [string] -or
                        $record.rationale -isnot [string]) {
                        throw 'Manifest record types are invalid.'
                    }
                    $recordPath = [string]$record.path
                    if ([string]::IsNullOrWhiteSpace($recordPath) -or
                        $recordPath -cne $recordPath.Trim() -or
                        $recordPath.Contains('\') -or
                        $recordPath.StartsWith('/') -or
                        $recordPath.Contains('//') -or
                        @($recordPath.Split('/') | Where-Object {
                            $_ -in @('', '.', '..')
                        }).Count -gt 0) {
                        throw 'Manifest record path is not normalized.'
                    }
                    if (-not $recordPath.StartsWith(
                        'hr/evidence/ai-builder/',
                        [StringComparison]::Ordinal
                    )) {
                        throw 'Manifest record path is outside the evidence root.'
                    }
                    foreach ($pattern in $patterns.Values) {
                        if ($pattern.IsMatch($recordPath)) {
                            throw 'Manifest record path contains a prohibited pattern.'
                        }
                    }
                    if (-not $recordPaths.Add($recordPath)) {
                        throw 'Manifest record path is duplicated.'
                    }
                    if (-not $entryByPath.ContainsKey($recordPath)) {
                        throw 'Manifest record path is not tracked.'
                    }
                    $recordEntry = $entryByPath[$recordPath]
                    if ($recordEntry.Stage -ne 0 -or
                        $recordEntry.Mode -notin @('100644', '100755')) {
                        throw 'Manifest record path is not a regular tracked file.'
                    }
                    if ($record.sha256 -cnotmatch '^[0-9a-f]{64}$') {
                        throw 'Manifest record hash is invalid.'
                    }
                    if ($record.patternClass -cnotmatch '^L[1-7]$') {
                        throw 'Manifest record pattern class is invalid.'
                    }
                    if ($record.count -isnot [int] -or $record.count -ne 1) {
                        throw 'Manifest record count is invalid.'
                    }
                    if ([string]::IsNullOrWhiteSpace($record.provenance) -or
                        [string]::IsNullOrWhiteSpace($record.rationale)) {
                        throw 'Manifest record provenance is invalid.'
                    }
                    $recordAbsolutePath = Join-Path $root (
                        $recordPath.Replace('/', '\')
                    )
                    $recordBytes = [IO.File]::ReadAllBytes($recordAbsolutePath)
                    $actualSha256 = Get-BrandingSha256 -Bytes $recordBytes
                    if ($actualSha256 -cne $record.sha256) {
                        throw 'Manifest record hash does not match evidence.'
                    }
                    if (-not $contentMatchesByPath.ContainsKey($recordPath)) {
                        throw 'Manifest record does not identify tracked text.'
                    }
                    $recordMatches = @($contentMatchesByPath[$recordPath])
                    $declaredMatches = @($recordMatches | Where-Object {
                        $_.PatternClass -ceq $record.patternClass
                    })
                    if ($declaredMatches.Count -ne $record.count -or
                        $recordMatches.Count -ne $record.count) {
                        throw 'Manifest record finding class or count does not match.'
                    }
                    [void]$candidates.Add([pscustomobject]@{
                        Path = $recordPath
                        PatternClass = [string]$record.patternClass
                        Sha256 = $actualSha256
                    })
                }

                foreach ($candidate in $candidates) {
                    [void]$approvedEvidence.Add($candidate)
                    [void]$suppressionKeys.Add(
                        $candidate.Path + [char]0 + $candidate.PatternClass
                    )
                }
            }
            catch {
                $manifestValid = $false
            }
            if (-not $manifestValid) {
                Add-Finding -Path $manifestRelativePath `
                    -PatternClass 'evidence-exception-error'
                $approvedEvidence.Clear()
                $suppressionKeys.Clear()
            }
        }
    }
    elseif (-not $manifestDisabled) {
        Add-Finding -Path $manifestRelativePath `
            -PatternClass 'evidence-exception-error'
    }

    $unapprovedFindings = @($findings | Where-Object {
        -not $suppressionKeys.Contains(
            $_.Path + [char]0 + $_.PatternClass
        )
    })
    [pscustomobject]@{
        TrackedCount = $seenPaths.Count
        TextCount = @($files | Where-Object Classification -ceq 'tracked-text').Count
        BinaryCount = @($files | Where-Object Classification -ceq 'tracked-binary').Count
        LinkCount = @($files | Where-Object Classification -ceq 'tracked-link').Count
        Files = @($files)
        Findings = $unapprovedFindings
        ApprovedEvidence = @($approvedEvidence)
        ApprovedEvidenceCount = $approvedEvidence.Count
    }
}

Export-ModuleMember -Function Get-RepositoryBrandingScan
