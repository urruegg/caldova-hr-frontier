[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$failures = [System.Collections.Generic.List[string]]::new()

function Add-ValidationFailure {
    param([Parameter(Mandatory)][string]$Message)

    $failures.Add($Message)
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
        $nameMatch = [regex]::Match($skillContent, '(?m)^name:\s*["'']?([a-z0-9-]+)["'']?\s*$')
        if (-not $nameMatch.Success) {
            Add-ValidationFailure "Missing or invalid skill name: .github/skills/$($skillDirectory.Name)/SKILL.md"
        }
        elseif ($nameMatch.Groups[1].Value -ne $skillDirectory.Name) {
            Add-ValidationFailure "Skill name does not match directory: $($skillDirectory.Name)"
        }

        foreach ($linkMatch in [regex]::Matches($skillContent, '\[[^\]]+\]\(([^)]+)\)')) {
            $target = $linkMatch.Groups[1].Value.Trim().Trim('<', '>')
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
        Write-Error $failure -ErrorAction Continue
    }
    exit 1
}

Write-Output 'Repository setup validation passed.'