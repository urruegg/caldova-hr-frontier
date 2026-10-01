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

function Get-RepositoryBrandingScan {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$RepositoryRoot)

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
        foreach ($pattern in $patterns.GetEnumerator()) {
            if ($pattern.Value.IsMatch($content)) {
                Add-Finding -Path $relativePath -PatternClass $pattern.Key
            }
        }
    }

    [pscustomobject]@{
        TrackedCount = $seenPaths.Count
        TextCount = @($files | Where-Object Classification -ceq 'tracked-text').Count
        BinaryCount = @($files | Where-Object Classification -ceq 'tracked-binary').Count
        LinkCount = @($files | Where-Object Classification -ceq 'tracked-link').Count
        Files = @($files)
        Findings = @($findings)
    }
}

Export-ModuleMember -Function Get-RepositoryBrandingScan
