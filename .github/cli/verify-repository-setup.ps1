[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$failures = [System.Collections.Generic.List[string]]::new()

function Add-ValidationFailure {
    param([Parameter(Mandatory)][string]$Message)

    $failures.Add($Message)
}

function Get-SkillNameFromFrontmatter {
    param([Parameter(Mandatory)][string]$Content)

    $lines = [regex]::Split($Content, '\r\n|\n|\r')
    if ($lines.Count -lt 3 -or $lines[0] -cne '---') {
        return $null
    }

    $frontmatterEnd = -1
    for ($index = 1; $index -lt $lines.Count; $index++) {
        if ($lines[$index] -ceq '---') {
            $frontmatterEnd = $index
            break
        }
    }

    if ($frontmatterEnd -lt 0) {
        return $null
    }

    $namePattern = '^name:[ \t]*(?:(?<plain>[a-z0-9-]+)|''(?<single>[a-z0-9-]+)''|"(?<double>[a-z0-9-]+)")[ \t]*$'
    for ($index = 1; $index -lt $frontmatterEnd; $index++) {
        $nameMatch = [regex]::Match($lines[$index], $namePattern)
        if (-not $nameMatch.Success) {
            continue
        }

        foreach ($groupName in @('plain', 'single', 'double')) {
            if ($nameMatch.Groups[$groupName].Success) {
                return $nameMatch.Groups[$groupName].Value
            }
        }
    }

    return $null
}

function Test-MarkdownEscapableCharacter {
    param([Parameter(Mandatory)][char]$Character)

    $characterCode = [int]$Character
    return ($characterCode -ge 0x21 -and $characterCode -le 0x2f) -or
        ($characterCode -ge 0x3a -and $characterCode -le 0x40) -or
        ($characterCode -ge 0x5b -and $characterCode -le 0x60) -or
        ($characterCode -ge 0x7b -and $characterCode -le 0x7e)
}

function ConvertFrom-MarkdownEscapes {
    param([Parameter(Mandatory)][string]$Text)

    $result = [System.Text.StringBuilder]::new()
    for ($index = 0; $index -lt $Text.Length; $index++) {
        if ($Text[$index] -eq '\' -and
            $index + 1 -lt $Text.Length -and
            (Test-MarkdownEscapableCharacter $Text[$index + 1])) {
            $index++
        }

        [void]$result.Append($Text[$index])
    }

    return $result.ToString()
}

function Get-MarkdownContentOutsideFences {
    param([Parameter(Mandatory)][string]$Content)

    $result = [System.Text.StringBuilder]::new()
    $fenceCharacter = $null
    $fenceLength = 0

    foreach ($line in [regex]::Split($Content, '\r\n|\n|\r')) {
        $fenceMatch = [regex]::Match($line, '^[ ]{0,3}(?<marker>`{3,}|~{3,})')
        if ($fenceMatch.Success) {
            $marker = $fenceMatch.Groups['marker'].Value
            if ($null -eq $fenceCharacter) {
                $fenceCharacter = $marker[0]
                $fenceLength = $marker.Length
                [void]$result.AppendLine()
                continue
            }

            $remainder = $line.Substring($fenceMatch.Length)
            if ($marker[0] -ceq $fenceCharacter -and
                $marker.Length -ge $fenceLength -and
                $remainder -match '^[ \t]*$') {
                $fenceCharacter = $null
                $fenceLength = 0
                [void]$result.AppendLine()
                continue
            }
        }

        if ($null -eq $fenceCharacter) {
            [void]$result.AppendLine($line)
        }
        else {
            [void]$result.AppendLine()
        }
    }

    return $result.ToString()
}

function Read-MarkdownDestination {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][int]$StartIndex,
        [switch]$RequireClosingParenthesis
    )

    $index = $StartIndex
    while ($index -lt $Text.Length -and [char]::IsWhiteSpace($Text[$index])) {
        $index++
    }

    $destination = [System.Text.StringBuilder]::new()
    if ($index -lt $Text.Length -and $Text[$index] -eq '<') {
        $index++
        $closed = $false
        while ($index -lt $Text.Length) {
            if ($Text[$index] -eq '\' -and
                $index + 1 -lt $Text.Length -and
                (Test-MarkdownEscapableCharacter $Text[$index + 1])) {
                [void]$destination.Append($Text[$index])
                $index++
                [void]$destination.Append($Text[$index])
                $index++
                continue
            }

            if ($Text[$index] -eq '>') {
                $closed = $true
                $index++
                break
            }

            if ($Text[$index] -eq '<' -or $Text[$index] -eq "`r" -or $Text[$index] -eq "`n") {
                return $null
            }

            [void]$destination.Append($Text[$index])
            $index++
        }

        if (-not $closed) {
            return $null
        }
    }
    else {
        $parenthesisDepth = 0
        while ($index -lt $Text.Length) {
            if ($Text[$index] -eq '\' -and
                $index + 1 -lt $Text.Length -and
                (Test-MarkdownEscapableCharacter $Text[$index + 1])) {
                [void]$destination.Append($Text[$index])
                $index++
                [void]$destination.Append($Text[$index])
                $index++
                continue
            }

            if ($Text[$index] -eq '(') {
                $parenthesisDepth++
            }
            elseif ($Text[$index] -eq ')') {
                if ($parenthesisDepth -eq 0) {
                    break
                }

                $parenthesisDepth--
            }
            elseif ([char]::IsWhiteSpace($Text[$index])) {
                if ($parenthesisDepth -gt 0) {
                    return $null
                }

                break
            }
            elseif ($Text[$index] -eq '<') {
                return $null
            }

            [void]$destination.Append($Text[$index])
            $index++
        }

        if ($parenthesisDepth -ne 0) {
            return $null
        }
    }

    $hadWhitespace = $false
    while ($index -lt $Text.Length -and [char]::IsWhiteSpace($Text[$index])) {
        $hadWhitespace = $true
        $index++
    }

    if ($RequireClosingParenthesis -and $index -lt $Text.Length -and $Text[$index] -eq ')') {
        return [pscustomobject]@{
            Destination = ConvertFrom-MarkdownEscapes $destination.ToString()
            EndIndex = $index
        }
    }

    if (-not $RequireClosingParenthesis -and $index -eq $Text.Length) {
        return [pscustomobject]@{
            Destination = ConvertFrom-MarkdownEscapes $destination.ToString()
            EndIndex = $index
        }
    }

    if (-not $hadWhitespace -or $index -ge $Text.Length) {
        return $null
    }

    $titleDelimiter = $Text[$index]
    if ($titleDelimiter -eq '"' -or $titleDelimiter -eq "'") {
        $titleTerminator = $titleDelimiter
    }
    elseif ($titleDelimiter -eq '(') {
        $titleTerminator = ')'
    }
    else {
        return $null
    }

    $index++
    $titleClosed = $false
    while ($index -lt $Text.Length) {
        if ($Text[$index] -eq '\' -and
            $index + 1 -lt $Text.Length -and
            (Test-MarkdownEscapableCharacter $Text[$index + 1])) {
            $index += 2
            continue
        }

        if ($Text[$index] -eq $titleTerminator) {
            $titleClosed = $true
            $index++
            break
        }

        if ($Text[$index] -eq "`r" -or $Text[$index] -eq "`n") {
            return $null
        }

        $index++
    }

    if (-not $titleClosed) {
        return $null
    }

    while ($index -lt $Text.Length -and [char]::IsWhiteSpace($Text[$index])) {
        $index++
    }

    if ($RequireClosingParenthesis) {
        if ($index -ge $Text.Length -or $Text[$index] -ne ')') {
            return $null
        }
    }
    elseif ($index -ne $Text.Length) {
        return $null
    }

    return [pscustomobject]@{
        Destination = ConvertFrom-MarkdownEscapes $destination.ToString()
        EndIndex = $index
    }
}

function Get-MarkdownLinkDestinations {
    param([Parameter(Mandatory)][string]$Content)

    $contentOutsideFences = Get-MarkdownContentOutsideFences $Content
    $index = 0
    while ($index -lt $contentOutsideFences.Length) {
        if ($contentOutsideFences[$index] -eq '\' -and
            $index + 1 -lt $contentOutsideFences.Length -and
            (Test-MarkdownEscapableCharacter $contentOutsideFences[$index + 1])) {
            $index += 2
            continue
        }

        if ($contentOutsideFences[$index] -ne '[') {
            $index++
            continue
        }

        $labelDepth = 1
        $labelEnd = $index + 1
        while ($labelEnd -lt $contentOutsideFences.Length -and $labelDepth -gt 0) {
            if ($contentOutsideFences[$labelEnd] -eq '\' -and
                $labelEnd + 1 -lt $contentOutsideFences.Length -and
                (Test-MarkdownEscapableCharacter $contentOutsideFences[$labelEnd + 1])) {
                $labelEnd += 2
                continue
            }

            if ($contentOutsideFences[$labelEnd] -eq '[') {
                $labelDepth++
            }
            elseif ($contentOutsideFences[$labelEnd] -eq ']') {
                $labelDepth--
            }

            $labelEnd++
        }

        if ($labelDepth -ne 0 -or
            $labelEnd -ge $contentOutsideFences.Length -or
            $contentOutsideFences[$labelEnd] -ne '(') {
            $index++
            continue
        }

        $link = Read-MarkdownDestination $contentOutsideFences ($labelEnd + 1) -RequireClosingParenthesis
        if ($null -eq $link) {
            $index = $labelEnd + 1
            continue
        }

        if (-not [string]::IsNullOrWhiteSpace($link.Destination)) {
            Write-Output $link.Destination
        }
        $index = $link.EndIndex + 1
    }

    foreach ($line in [regex]::Split($contentOutsideFences, '\r\n|\n|\r')) {
        $definitionMatch = [regex]::Match($line, '^[ ]{0,3}\[(?:\\.|[^\]\\])+\]:[ \t]*')
        if (-not $definitionMatch.Success) {
            continue
        }

        $definition = Read-MarkdownDestination $line $definitionMatch.Length
        if ($null -ne $definition -and -not [string]::IsNullOrWhiteSpace($definition.Destination)) {
            Write-Output $definition.Destination
        }
    }
}

$requiredDirectories = @(
    '.github/agent-policy',
    '.github/agents',
    '.github/cli',
    '.github/instructions',
    '.github/issue-templates',
    '.github/skills',
    '.github/workflows',
    'docs/adr',
    'docs/archive',
    'docs/brandkit',
    'docs/business',
    'docs/delegation',
    'docs/ideas',
    'docs/issues',
    'docs/plans',
    'docs/reviews',
    'docs/specs',
    'docs/sprints',
    'docs/templates'
)

foreach ($relativeDirectory in $requiredDirectories) {
    $directory = Join-Path $repositoryRoot $relativeDirectory
    if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
        Add-ValidationFailure "Missing required directory: $relativeDirectory"
        continue
    }

    $readme = Join-Path $directory 'README.md'
    if (-not (Test-Path -LiteralPath $readme -PathType Leaf)) {
        Add-ValidationFailure "Missing folder README: $relativeDirectory/README.md"
        continue
    }

    if ([string]::IsNullOrWhiteSpace((Get-Content -LiteralPath $readme -Raw))) {
        Add-ValidationFailure "Empty folder README: $relativeDirectory/README.md"
    }
}

foreach ($excludedDirectory in @('.github/ISSUE_TEMPLATE', 'docs/storyboard')) {
    if (Test-Path -LiteralPath (Join-Path $repositoryRoot $excludedDirectory)) {
        Add-ValidationFailure "Excluded directory exists: $excludedDirectory"
    }
}

$skillsRoot = Join-Path $repositoryRoot '.github/skills'
if (Test-Path -LiteralPath $skillsRoot -PathType Container) {
    $skillDirectories = Get-ChildItem -LiteralPath $skillsRoot -Directory
    foreach ($skillDirectory in $skillDirectories) {
        $skillFile = Join-Path $skillDirectory.FullName 'SKILL.md'
        if (-not (Test-Path -LiteralPath $skillFile -PathType Leaf)) {
            Add-ValidationFailure "Missing SKILL.md: .github/skills/$($skillDirectory.Name)"
            continue
        }

        $skillContent = Get-Content -LiteralPath $skillFile -Raw
        $skillName = Get-SkillNameFromFrontmatter $skillContent
        if ([string]::IsNullOrWhiteSpace($skillName)) {
            Add-ValidationFailure "Missing or invalid skill name: .github/skills/$($skillDirectory.Name)/SKILL.md"
        }
        elseif ($skillName -cne $skillDirectory.Name) {
            Add-ValidationFailure "Skill name does not match directory: $($skillDirectory.Name)"
        }

        foreach ($target in Get-MarkdownLinkDestinations $skillContent) {
            if ($target -match '^(?:https?://|mailto:|#)') {
                continue
            }

            $targetPath = ($target -split '#', 2)[0]
            if ([string]::IsNullOrWhiteSpace($targetPath)) {
                continue
            }

            $resolvedTarget = Join-Path $skillDirectory.FullName ([Uri]::UnescapeDataString($targetPath))
            if (-not (Test-Path -LiteralPath $resolvedTarget)) {
                Add-ValidationFailure "Broken skill link in $($skillDirectory.Name)/SKILL.md: $target"
            }
        }
    }
}

$usingSuperpowers = Join-Path $skillsRoot 'using-superpowers/SKILL.md'
if (-not (Test-Path -LiteralPath $usingSuperpowers -PathType Leaf)) {
    Add-ValidationFailure 'The using-superpowers entry skill is missing.'
}

foreach ($bootstrapFile in @('AGENTS.md', '.github/copilot-instructions.md')) {
    $bootstrapPath = Join-Path $repositoryRoot $bootstrapFile
    if (-not (Test-Path -LiteralPath $bootstrapPath -PathType Leaf)) {
        Add-ValidationFailure "Missing Copilot bootstrap: $bootstrapFile"
        continue
    }

    $bootstrapContent = Get-Content -LiteralPath $bootstrapPath -Raw
    if ($bootstrapContent -notmatch '\.github/skills') {
        Add-ValidationFailure "Bootstrap does not reference .github/skills: $bootstrapFile"
    }
    if ($bootstrapContent -notmatch 'using-superpowers') {
        Add-ValidationFailure "Bootstrap does not reference using-superpowers: $bootstrapFile"
    }
}

$versionFile = Join-Path $skillsRoot 'SUPERPOWERS_VERSION'
if (-not (Test-Path -LiteralPath $versionFile -PathType Leaf)) {
    Add-ValidationFailure 'Missing .github/skills/SUPERPOWERS_VERSION.'
}
else {
    $versionContent = Get-Content -LiteralPath $versionFile -Raw
    foreach ($requiredValue in @(
        'https://github.com/obra/superpowers',
        'v6.3.0',
        'b36e0829c6d0140e93cfef2ca599b1b07d4a7797'
    )) {
        if ($versionContent -notmatch [regex]::Escape($requiredValue)) {
            Add-ValidationFailure "Version metadata is missing: $requiredValue"
        }
    }
}

$licenseFile = Join-Path $skillsRoot 'LICENSE.superpowers'
if (-not (Test-Path -LiteralPath $licenseFile -PathType Leaf)) {
    Add-ValidationFailure 'Missing .github/skills/LICENSE.superpowers.'
}
else {
    $licenseContent = Get-Content -LiteralPath $licenseFile -Raw
    if ($licenseContent -notmatch 'MIT License' -or $licenseContent -notmatch 'Copyright \(c\) 2025 Jesse Vincent') {
        Add-ValidationFailure 'The bundled Superpowers license is incomplete.'
    }
}

$rootReadme = Join-Path $repositoryRoot 'README.md'
if (-not (Test-Path -LiteralPath $rootReadme -PathType Leaf)) {
    Add-ValidationFailure 'Missing root README.md.'
}
else {
    $rootReadmeContent = Get-Content -LiteralPath $rootReadme -Raw
    foreach ($requiredValue in @('Superpowers', 'v6.3.0', '.github/skills', 'verify-repository-setup.ps1')) {
        if ($rootReadmeContent -notmatch [regex]::Escape($requiredValue)) {
            Add-ValidationFailure "Root README is missing: $requiredValue"
        }
    }
}

if ($failures.Count -gt 0) {
    foreach ($failure in $failures) {
        Write-Output "ERROR: $failure"
    }
    Write-Output "Repository setup validation failed with $($failures.Count) error(s)."
    exit 1
}

Write-Output 'Repository setup validation passed.'