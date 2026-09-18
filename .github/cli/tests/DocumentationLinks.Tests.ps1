BeforeAll {
    $script:repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
    $script:repositoryPrefix = $script:repositoryRoot.TrimEnd('\') + '\'

    function Remove-MarkdownFencedCode {
        param(
            [Parameter(Mandatory)]
            [AllowEmptyString()]
            [string]$Content
        )

        $lines = @($Content.Replace("`r`n", "`n").Replace("`r", "`n").Split("`n"))
        $visibleLines = [Collections.Generic.List[string]]::new()
        $insideFence = $false
        $fenceMarker = [char]0
        $fenceLength = 0

        foreach ($line in $lines) {
            if ($insideFence) {
                $closingPattern = '^ {0,3}' + [regex]::Escape($fenceMarker.ToString()) +
                    '{' + $fenceLength + ',}\s*$'
                if ([regex]::IsMatch(
                    $line,
                    $closingPattern,
                    [Text.RegularExpressions.RegexOptions]::CultureInvariant
                )) {
                    $insideFence = $false
                    $fenceMarker = [char]0
                    $fenceLength = 0
                }
                continue
            }

            $opening = [regex]::Match(
                $line,
                '^ {0,3}(?<Fence>`{3,}|~{3,})(?<Info>.*)$',
                [Text.RegularExpressions.RegexOptions]::CultureInvariant
            )
            if ($opening.Success) {
                $fence = $opening.Groups['Fence'].Value
                $marker = $fence[0]
                $info = $opening.Groups['Info'].Value
                if ($marker -ne [char]'`' -or
                    $info.IndexOf([char]'`') -lt 0) {
                    $insideFence = $true
                    $fenceMarker = $marker
                    $fenceLength = $fence.Length
                    continue
                }
            }

            $visibleLines.Add($line)
        }

        return [string]::Join("`n", $visibleLines)
    }
}

Describe 'Repository documentation links' {
    It 'resolves every tracked local Markdown link within the repository' {
        $gitOutput = @(& git -C $script:repositoryRoot ls-files -- '*.md' 2>&1)
        $gitExitCode = $LASTEXITCODE
        $gitExitCode | Should -Be 0 -Because (
            'git ls-files must enumerate the tracked Markdown inventory: {0}' -f
            ([string]::Join([Environment]::NewLine, $gitOutput))
        )
        $paths = @($gitOutput | ForEach-Object { $_.ToString() })

        $failures = [Collections.Generic.List[string]]::new()
        foreach ($relativePath in $paths) {
            if ($relativePath.StartsWith('.github/skills/', [StringComparison]::Ordinal) -and
                $relativePath -cne '.github/skills/README.md') {
                continue
            }

            $sourcePath = Join-Path $script:repositoryRoot $relativePath
            $content = Get-Content -LiteralPath $sourcePath -Raw
            $contentWithoutFences = Remove-MarkdownFencedCode -Content $content
            foreach ($linkMatch in [regex]::Matches(
                $contentWithoutFences,
                '!?\[[^\]]*\]\(([^)]+)\)',
                [Text.RegularExpressions.RegexOptions]::CultureInvariant
            )) {
                $rawTarget = $linkMatch.Groups[1].Value.Trim()
                if ($rawTarget.StartsWith('<', [StringComparison]::Ordinal)) {
                    $closingAngle = $rawTarget.IndexOf('>', [StringComparison]::Ordinal)
                    if ($closingAngle -lt 0) {
                        $failures.Add("$relativePath -> $rawTarget")
                        continue
                    }
                    $target = $rawTarget.Substring(1, $closingAngle - 1)
                }
                else {
                    $target = ($rawTarget -split '\s+', 2)[0]
                }

                if ($target -match '^(?i:https?://|mailto:|#)') {
                    continue
                }
                $pathPart = ($target -split '[?#]', 2)[0]
                if ([string]::IsNullOrWhiteSpace($pathPart)) {
                    continue
                }

                try {
                    $decoded = [Uri]::UnescapeDataString($pathPart).Replace('/', '\')
                    $resolved = [IO.Path]::GetFullPath((
                        Join-Path (Split-Path -Parent $sourcePath) $decoded
                    ))
                }
                catch {
                    $failures.Add("$relativePath -> $target")
                    continue
                }

                $insideRepository = $resolved.Equals(
                    $script:repositoryRoot,
                    [StringComparison]::OrdinalIgnoreCase
                ) -or $resolved.StartsWith(
                    $script:repositoryPrefix,
                    [StringComparison]::OrdinalIgnoreCase
                )
                if (-not $insideRepository -or
                    -not (Test-Path -LiteralPath $resolved)) {
                    $failures.Add("$relativePath -> $target")
                }
            }
        }

        $failures | Should -BeNullOrEmpty
    }
}