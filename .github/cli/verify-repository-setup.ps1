[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$skillsRoot = Join-Path $repositoryRoot '.github\skills'
$skillsPrefix = [IO.Path]::GetFullPath($skillsRoot).TrimEnd('\') + '\'
$failures = [Collections.Generic.List[string]]::new()

function Add-Failure {
    param([string]$Message)
    [void]$failures.Add($Message)
}
$skillsRootTrusted = $true
if (Test-Path -LiteralPath $skillsRoot) {
    try { $skillsRootItem = Get-Item -LiteralPath $skillsRoot -Force }
    catch { Add-Failure 'Cannot inspect directory: .github/skills'; $skillsRootTrusted = $false }
    if ($skillsRootTrusted -and ($skillsRootItem.Attributes -band [IO.FileAttributes]::ReparsePoint)) { Add-Failure 'Reparse point is not allowed: .github/skills'; $skillsRootTrusted = $false }
}
function Test-RequiredContent {
    param([string]$RelativePath, [string[]]$Terms, [string[]]$ExpectedLines = @())

    if (-not $skillsRootTrusted -and $RelativePath.StartsWith('.github/skills/', [StringComparison]::Ordinal)) { return }
    $path = Join-Path $repositoryRoot ($RelativePath.Replace('/', '\'))
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Add-Failure "Missing file: $RelativePath"
        return
    }
    try {
        [string[]]$lines = @(Get-Content -LiteralPath $path)
        $content = $lines -join "`n"
    }
    catch {
        Add-Failure "Cannot read file: $RelativePath"
        return
    }
    if ($ExpectedLines.Count -gt 0) {
        if ($lines.Count -ne $ExpectedLines.Count) {
            Add-Failure "$RelativePath does not match the pinned metadata contract."
            return
        }
        for ($lineIndex = 0; $lineIndex -lt $lines.Count; $lineIndex++) {
            if ($lines[$lineIndex] -cne $ExpectedLines[$lineIndex]) {
                Add-Failure "$RelativePath does not match the pinned metadata contract."
                return
            }
        }
        return
    }
    foreach ($term in $Terms) {
        if ($content.IndexOf($term, [StringComparison]::Ordinal) -lt 0) {
            Add-Failure "$RelativePath does not contain '$term'."
        }
    }
}

$baseFolders = @(
    '.github/agent-policy', '.github/agents', '.github/cli', '.github/instructions',
    '.github/issue-templates', '.github/skills', '.github/workflows', 'docs/adr',
    'docs/archive', 'docs/brandkit', 'docs/business', 'docs/delegation', 'docs/ideas',
    'docs/issues', 'docs/plans', 'docs/reviews', 'docs/specs', 'docs/sprints', 'docs/templates'
)
foreach ($relativeFolder in $baseFolders) {
    if ($relativeFolder -ceq '.github/skills' -and -not $skillsRootTrusted) { continue }
    $folder = Join-Path $repositoryRoot ($relativeFolder.Replace('/', '\'))
    if (-not (Test-Path -LiteralPath $folder -PathType Container)) {
        Add-Failure "Missing directory: $relativeFolder"
        continue
    }
    $readme = Join-Path $folder 'README.md'
    if (-not (Test-Path -LiteralPath $readme -PathType Leaf)) {
        Add-Failure "Missing README.md: $relativeFolder/README.md"
        continue
    }
    try { $readmeContent = Get-Content -LiteralPath $readme -Raw }
    catch { Add-Failure "Cannot read README.md: $relativeFolder/README.md"; continue }
    if ([string]::IsNullOrWhiteSpace($readmeContent)) {
        Add-Failure "Empty README.md: $relativeFolder/README.md"
    }
}
$storyboardPath = Join-Path $repositoryRoot 'docs\storyboard'
if (Test-Path -LiteralPath $storyboardPath) {
    Add-Failure 'Legacy path must not exist: docs/storyboard'
}

$issueTemplateRelativeRoot = '.github/ISSUE_TEMPLATE'
$githubRoot = Join-Path $repositoryRoot '.github'
$issueTemplateRoot = Join-Path $repositoryRoot '.github\ISSUE_TEMPLATE'
$issueTemplateFileNames = @('01-bug.yml', '02-feature.yml', 'config.yml')
$issueTemplateGitPrefix = '.github/ISSUE_TEMPLATE/'
$expectedIssueTemplateGitPaths = @($issueTemplateFileNames | ForEach-Object { "${issueTemplateGitPrefix}$_" })
$gitattributesRelativePath = '.gitattributes'
$expectedIssueTemplateHashes = [Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
$expectedIssueTemplateHashes.Add('01-bug.yml', '8f2c31b169477b86d85e60f9d1c91eed349fae829f1071b8b42dc93624d8879a')
$expectedIssueTemplateHashes.Add('02-feature.yml', '748e69155e9e60acd16f5cbb93b6398fd5853905951829080a9c440ed5c0e7a4')
$expectedIssueTemplateHashes.Add('config.yml', '1f103c6a9dd07cd13a9a6f17ace6b813f47747eb9cb7e00488cb2073caaf91bb')
$actualIssueTemplateFiles = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$reparseIssueTemplateEntries = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$ordinaryIssueTemplateFiles = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$issueTemplateRootTrusted = $true

if (Test-Path -LiteralPath $githubRoot -PathType Container) {
    try {
        $issueTemplateDirectoryCandidates = @(Get-ChildItem -LiteralPath $githubRoot -Directory -Force | Where-Object {
            [string]::Equals($_.Name, 'ISSUE_TEMPLATE', [StringComparison]::OrdinalIgnoreCase)
        })
        foreach ($candidate in $issueTemplateDirectoryCandidates) {
            if ($candidate.Name -cne 'ISSUE_TEMPLATE') {
                Add-Failure "Active issue-template directory must use exact filesystem casing: .github/$($candidate.Name)"
            }
        }
        if ($issueTemplateDirectoryCandidates.Count -gt 1) {
            Add-Failure 'Multiple case variants of the active issue-template directory exist under .github'
        }
    }
    catch {
        Add-Failure 'Cannot inspect active issue-template directory casing under .github'
    }
}

if (-not (Test-Path -LiteralPath $issueTemplateRoot -PathType Container)) {
    Add-Failure "Missing directory: $issueTemplateRelativeRoot"
    $issueTemplateRootTrusted = $false
}
else {
    try { $issueTemplateRootItem = Get-Item -LiteralPath $issueTemplateRoot -Force }
    catch { Add-Failure "Cannot inspect directory: $issueTemplateRelativeRoot"; $issueTemplateRootTrusted = $false }
    if ($issueTemplateRootTrusted -and ($issueTemplateRootItem.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        Add-Failure "Reparse point is not allowed: $issueTemplateRelativeRoot"
        $issueTemplateRootTrusted = $false
    }
}

if ($issueTemplateRootTrusted) {
    try { $issueTemplateEntries = @(Get-ChildItem -LiteralPath $issueTemplateRoot -Force) }
    catch { Add-Failure "Cannot enumerate entries under $issueTemplateRelativeRoot"; $issueTemplateEntries = @() }
    foreach ($entry in $issueTemplateEntries) {
        if ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            Add-Failure "Reparse point is not allowed under ${issueTemplateRelativeRoot}: $($entry.Name)"
            [void]$reparseIssueTemplateEntries.Add($entry.Name)
        }
        if ($issueTemplateFileNames -cnotcontains $entry.Name) {
            Add-Failure "Unexpected active issue-template entry: $($entry.Name)"
            continue
        }
        [void]$actualIssueTemplateFiles.Add($entry.Name)
    }
}

foreach ($fileName in $issueTemplateFileNames) {
    $relativePath = "$issueTemplateRelativeRoot/$fileName"
    if (-not $actualIssueTemplateFiles.Contains($fileName)) {
        Add-Failure "Missing active issue-template file: $relativePath"
        continue
    }
    if ($reparseIssueTemplateEntries.Contains($fileName)) { continue }
    $filePath = Join-Path $issueTemplateRoot $fileName
    if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
        Add-Failure "Active issue-template entry is not a file: $relativePath"
        continue
    }
    [void]$ordinaryIssueTemplateFiles.Add($fileName)
}

$gitCommand = Get-Command git -CommandType Application -ErrorAction SilentlyContinue
$gitIndexLines = @()
$gitIndexReadable = $false
if ($null -eq $gitCommand) {
    Add-Failure 'Cannot inspect Git index for active issue-template paths: git is unavailable'
}
else {
    try {
        $gitIndexLines = @(& $gitCommand.Source -C $repositoryRoot -c core.quotePath=false ls-files --stage 2>&1 |
            ForEach-Object { $_.ToString() })
        $gitIndexExitCode = $LASTEXITCODE
        if ($gitIndexExitCode -ne 0) {
            Add-Failure 'Cannot inspect Git index for active issue-template paths'
        }
        else {
            $gitIndexReadable = $true
        }
    }
    catch {
        Add-Failure 'Cannot inspect Git index for active issue-template paths'
    }
}

if ($gitIndexReadable) {
    $gitIndexRecords = [Collections.Generic.List[object]]::new()
    $issueTemplateGitRecords = [Collections.Generic.List[object]]::new()
    $protectedGitRecordsToCompare = [Collections.Generic.List[object]]::new()
    foreach ($line in $gitIndexLines) {
        if ($line -notmatch '^([0-7]{6}) ((?:[0-9a-fA-F]{40}|[0-9a-fA-F]{64})) ([0-3])\t(.*)$') {
            Add-Failure "Cannot parse Git index record: $line"
            continue
        }
        $record = [pscustomobject]@{
            Mode = $Matches[1]
            ObjectId = $Matches[2]
            Stage = $Matches[3]
            Path = $Matches[4]
        }
        [void]$gitIndexRecords.Add($record)
        if ([string]::Equals($record.Path, $gitattributesRelativePath, [StringComparison]::OrdinalIgnoreCase)) {
            if ($record.Path -cne $gitattributesRelativePath) {
                Add-Failure ".gitattributes must use exact Git casing: $($record.Path)"
            }
        }
        if (-not $record.Path.StartsWith($issueTemplateGitPrefix, [StringComparison]::OrdinalIgnoreCase)) {
            continue
        }
        [void]$issueTemplateGitRecords.Add($record)
        $caseInsensitiveExpectedPath = @($expectedIssueTemplateGitPaths | Where-Object {
            [string]::Equals($_, $record.Path, [StringComparison]::OrdinalIgnoreCase)
        })
        if (-not $record.Path.StartsWith($issueTemplateGitPrefix, [StringComparison]::Ordinal) -or
            ($caseInsensitiveExpectedPath.Count -eq 1 -and $record.Path -cne $caseInsensitiveExpectedPath[0])) {
            Add-Failure "Active issue-template path must use exact Git casing: $($record.Path)"
            continue
        }
        if ($expectedIssueTemplateGitPaths -cnotcontains $record.Path) {
            Add-Failure "Unexpected tracked active issue-template path: $($record.Path)"
        }
    }

    foreach ($expectedPath in $expectedIssueTemplateGitPaths) {
        $matchingRecords = @($issueTemplateGitRecords | Where-Object { $_.Path -ceq $expectedPath })
        if ($matchingRecords.Count -eq 0) {
            Add-Failure "Active issue-template file is not tracked at exact Git path: $expectedPath"
            continue
        }
        if ($matchingRecords.Count -ne 1) {
            Add-Failure "Ambiguous Git index entries for active issue-template path: $expectedPath"
            continue
        }
        if ($matchingRecords[0].Stage -cne '0' -or $matchingRecords[0].Mode -cne '100644') {
            Add-Failure "Active issue-template Git entry must be stage-0 mode 100644: $expectedPath"
            continue
        }
        [void]$protectedGitRecordsToCompare.Add($matchingRecords[0])
    }

    $matchingGitattributesRecords = @($gitIndexRecords | Where-Object { $_.Path -ceq $gitattributesRelativePath })
    if ($matchingGitattributesRecords.Count -eq 0) {
        Add-Failure ".gitattributes is not tracked at exact Git path: $gitattributesRelativePath"
    }
    elseif ($matchingGitattributesRecords.Count -ne 1) {
        Add-Failure "Ambiguous Git index entries for path: $gitattributesRelativePath"
    }
    elseif ($matchingGitattributesRecords[0].Stage -cne '0' -or $matchingGitattributesRecords[0].Mode -cne '100644') {
        Add-Failure ".gitattributes Git entry must be stage-0 mode 100644: $gitattributesRelativePath"
    }
    else {
        [void]$protectedGitRecordsToCompare.Add($matchingGitattributesRecords[0])
    }

    foreach ($record in $protectedGitRecordsToCompare) {
        try {
            [string[]]$workingTreeObjectIdLines = @(& $gitCommand.Source -C $repositoryRoot hash-object --no-filters -- $record.Path 2>&1 |
                ForEach-Object { $_.ToString() })
            $hashObjectExitCode = $LASTEXITCODE
            if ($hashObjectExitCode -ne 0 -or $workingTreeObjectIdLines.Count -ne 1 -or
                $workingTreeObjectIdLines[0] -notmatch '^(?:[0-9a-fA-F]{40}|[0-9a-fA-F]{64})$') {
                Add-Failure "Cannot compare Git index content with working tree: $($record.Path)"
                continue
            }
            $workingTreeObjectId = $workingTreeObjectIdLines[0].ToLowerInvariant()
            $indexObjectId = $record.ObjectId.ToLowerInvariant()
            if ($workingTreeObjectId -ceq $indexObjectId) { continue }
            if ($record.Path -ceq $gitattributesRelativePath) {
                [string[]]$gitNormalizedObjectIdLines = @(& $gitCommand.Source -C $repositoryRoot hash-object "--path=$($record.Path)" -- $record.Path 2>&1 |
                    ForEach-Object { $_.ToString() })
                $gitNormalizedHashExitCode = $LASTEXITCODE
                if ($gitNormalizedHashExitCode -ne 0 -or $gitNormalizedObjectIdLines.Count -ne 1 -or
                    $gitNormalizedObjectIdLines[0] -notmatch '^(?:[0-9a-fA-F]{40}|[0-9a-fA-F]{64})$') {
                    Add-Failure "Cannot compare Git index content with working tree: $($record.Path)"
                    continue
                }
                if ($gitNormalizedObjectIdLines[0].ToLowerInvariant() -ceq $indexObjectId) { continue }
            }
            Add-Failure "Git index content differs from working tree: $($record.Path)"
        }
        catch {
            Add-Failure "Cannot compare Git index content with working tree: $($record.Path)"
        }
    }
}

$gitattributesPath = Join-Path $repositoryRoot $gitattributesRelativePath
$issueTemplateByteStabilityRule = '/.github/ISSUE_TEMPLATE/*.yml -text'
$gitattributesLines = @()
$gitattributesReadable = $false
try {
    if (-not (Test-Path -LiteralPath $gitattributesPath -PathType Leaf)) {
        Add-Failure '.gitattributes must be an ordinary readable file.'
    }
    else {
        $gitattributesItem = Get-Item -LiteralPath $gitattributesPath -Force -ErrorAction Stop
        if ($gitattributesItem.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            Add-Failure '.gitattributes must be an ordinary readable file.'
        }
        else {
            $gitattributesLines = @(Get-Content -LiteralPath $gitattributesPath -ErrorAction Stop)
            $gitattributesReadable = $true
        }
    }
}
catch {
    Add-Failure '.gitattributes must be an ordinary readable file.'
}

if ($gitattributesReadable) {
    $byteStabilityRuleCount = @($gitattributesLines | Where-Object {
        $_ -ceq $issueTemplateByteStabilityRule
    }).Count
    if ($byteStabilityRuleCount -ne 1) {
        Add-Failure '.gitattributes must contain exactly one issue-form byte-stability rule.'
    }
}

$gitAttributeLines = @()
$gitAttributesReadable = $false
if ($null -eq $gitCommand) {
    Add-Failure 'Cannot inspect Git text attributes for active issue-template paths: git is unavailable'
}
else {
    try {
        $gitAttributeLines = @(& $gitCommand.Source -C $repositoryRoot -c core.quotePath=false check-attr text -- $expectedIssueTemplateGitPaths 2>&1 |
            ForEach-Object { $_.ToString() })
        $gitAttributeExitCode = $LASTEXITCODE
        if ($gitAttributeExitCode -ne 0) {
            Add-Failure 'Cannot inspect Git text attributes for active issue-template paths'
        }
        else {
            $gitAttributesReadable = $true
        }
    }
    catch {
        Add-Failure 'Cannot inspect Git text attributes for active issue-template paths'
    }
}

if ($gitAttributesReadable) {
    if ($gitAttributeLines.Count -ne $expectedIssueTemplateGitPaths.Count) {
        Add-Failure "Expected 3 Git text attribute records, found $($gitAttributeLines.Count)"
    }
    $gitAttributeRecords = [Collections.Generic.List[object]]::new()
    foreach ($line in $gitAttributeLines) {
        $attributeMatch = [regex]::Match($line, '^(.*): text: (.*)$')
        if (-not $attributeMatch.Success) {
            Add-Failure "Cannot parse Git text attribute record: $line"
            continue
        }
        $reportedPath = $attributeMatch.Groups[1].Value
        $normalizedReportedPath = $reportedPath.Replace('\', '/')
        if ($expectedIssueTemplateGitPaths -cnotcontains $normalizedReportedPath) {
            Add-Failure "Unexpected Git text attribute path: $reportedPath"
            continue
        }
        [void]$gitAttributeRecords.Add([pscustomobject]@{
            Path = $normalizedReportedPath
            Value = $attributeMatch.Groups[2].Value
        })
    }
    foreach ($expectedPath in $expectedIssueTemplateGitPaths) {
        $matchingAttributeRecords = @($gitAttributeRecords | Where-Object { $_.Path -ceq $expectedPath })
        if ($matchingAttributeRecords.Count -ne 1) {
            Add-Failure "Ambiguous Git text attribute result: $expectedPath"
            continue
        }
        if ($matchingAttributeRecords[0].Value -cne 'unset') {
            Add-Failure "Issue-form Git text attribute is not unset: $expectedPath"
        }
    }
}

foreach ($fileName in $issueTemplateFileNames) {
    if (-not $ordinaryIssueTemplateFiles.Contains($fileName)) { continue }
    $relativePath = "$issueTemplateRelativeRoot/$fileName"
    $filePath = Join-Path $issueTemplateRoot $fileName
    try { $actualHash = (Get-FileHash -LiteralPath $filePath -Algorithm SHA256).Hash.ToLowerInvariant() }
    catch { Add-Failure "Cannot hash active issue-template file: $relativePath"; continue }
    if ($actualHash -cne $expectedIssueTemplateHashes[$fileName]) {
        Add-Failure "Hash mismatch for active issue-template file: $relativePath"
    }
}

$skillNames = @(
    'brainstorming', 'dispatching-parallel-agents', 'executing-plans',
    'finishing-a-development-branch', 'receiving-code-review', 'requesting-code-review',
    'subagent-driven-development', 'systematic-debugging', 'test-driven-development',
    'using-git-worktrees', 'using-superpowers', 'verification-before-completion',
    'writing-plans', 'writing-skills'
)
$expectedSkills = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$actualSkills = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach ($skillName in $skillNames) { [void]$expectedSkills.Add($skillName) }
$reportedReparsePaths = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
if ($skillsRootTrusted -and (Test-Path -LiteralPath $skillsRoot -PathType Container)) {
    try { $skillEntries = @(Get-ChildItem -LiteralPath $skillsRoot -Force -Recurse) }
    catch { Add-Failure 'Cannot enumerate entries under .github/skills.'; $skillsRootTrusted = $false; $skillEntries = @() }
    foreach ($entry in $skillEntries) {
        if (-not ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint)) { continue }
        $relativePath = $entry.FullName.Substring($skillsPrefix.Length).Replace('\', '/')
        if ($reportedReparsePaths.Add($relativePath)) { Add-Failure "Reparse point is not allowed under .github/skills: $relativePath" }
    }
}
if ($skillsRootTrusted -and (Test-Path -LiteralPath $skillsRoot -PathType Container)) {
    foreach ($directory in @(Get-ChildItem -LiteralPath $skillsRoot -Directory -Force)) {
        [void]$actualSkills.Add($directory.Name)
        if (-not $expectedSkills.Contains($directory.Name)) {
            Add-Failure "Unexpected skill directory: $($directory.Name)"
        }
    }
}
foreach ($skillName in $skillNames) {
    if ($skillsRootTrusted -and -not $actualSkills.Contains($skillName)) {
        Add-Failure "Missing skill directory: $skillName"
    }
}

$namePattern = '^name:[ \t]*(?:([a-z0-9-]+)|''([a-z0-9-]+)''|"([a-z0-9-]+)")[ \t]*$'
foreach ($skillName in $skillNames) {
    if (-not $actualSkills.Contains($skillName)) { continue }
    $relativeSkillFile = "$skillName/SKILL.md"
    $skillFile = Join-Path $skillsRoot ($relativeSkillFile.Replace('/', '\'))
    if (-not (Test-Path -LiteralPath $skillFile -PathType Leaf)) {
        Add-Failure "Missing skill file: $relativeSkillFile"
        continue
    }
    try { [string[]]$lines = @(Get-Content -LiteralPath $skillFile) }
    catch { Add-Failure "Cannot read skill file: $relativeSkillFile"; continue }
    if ($lines.Count -eq 0 -or $lines[0] -cne '---') {
        Add-Failure "Missing leading YAML frontmatter: $relativeSkillFile"
        continue
    }
    $closingIndex = -1
    for ($lineIndex = 1; $lineIndex -lt $lines.Count; $lineIndex++) {
        if ($lines[$lineIndex] -ceq '---') { $closingIndex = $lineIndex; break }
    }
    if ($closingIndex -lt 0) {
        Add-Failure "Unclosed YAML frontmatter: $relativeSkillFile"
        continue
    }
    $nameLines = [Collections.Generic.List[string]]::new()
    for ($lineIndex = 1; $lineIndex -lt $closingIndex; $lineIndex++) {
        if ($lines[$lineIndex].StartsWith('name:', [StringComparison]::Ordinal)) {
            [void]$nameLines.Add($lines[$lineIndex])
        }
    }
    if ($nameLines.Count -ne 1) {
        Add-Failure "$relativeSkillFile must contain exactly one frontmatter name."
        continue
    }
    $nameMatch = [regex]::Match($nameLines[0], $namePattern)
    if (-not $nameMatch.Success) {
        Add-Failure "Invalid frontmatter name in $relativeSkillFile."
        continue
    }
    $declaredName = $nameMatch.Groups[1].Value
    if (-not $declaredName) { $declaredName = $nameMatch.Groups[2].Value }
    if (-not $declaredName) { $declaredName = $nameMatch.Groups[3].Value }
    if ($declaredName -cne $skillName) {
        Add-Failure "Skill name does not match directory: $relativeSkillFile declares '$declaredName'."
    }
}

function Test-SafeManifestPath {
    param([string]$RelativePath)

    try {
        $segments = $RelativePath.Split([char[]]@('/'), [StringSplitOptions]::None)
        $unsafe = $RelativePath.Contains('\') -or $RelativePath.StartsWith('/', [StringComparison]::Ordinal) -or
            [IO.Path]::IsPathRooted($RelativePath) -or $RelativePath -match '^[A-Za-z]:'
        foreach ($segment in $segments) {
            if ($segment.Length -eq 0 -or $segment -ceq '.' -or $segment -ceq '..') { $unsafe = $true }
        }
        if ($segments.Count -eq 0 -or -not $expectedSkills.Contains($segments[0])) { $unsafe = $true }
        if ($unsafe) { Add-Failure "Unsafe manifest path: $RelativePath"; return $false }
        $resolved = [IO.Path]::GetFullPath((Join-Path $skillsRoot ($RelativePath.Replace('/', '\'))))
        if (-not $resolved.StartsWith($skillsPrefix, [StringComparison]::OrdinalIgnoreCase)) {
            Add-Failure "Unsafe manifest path: $RelativePath"
            return $false
        }
    }
    catch {
        Add-Failure "Manifest path cannot be resolved: $RelativePath"
        return $false
    }
    return $true
}

$manifestFile = Join-Path $skillsRoot 'SUPERPOWERS_SHA256SUMS'
$manifestEntries = [Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
$seenManifestPaths = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
if ($skillsRootTrusted -and -not (Test-Path -LiteralPath $manifestFile -PathType Leaf)) {
    Add-Failure 'Missing file: .github/skills/SUPERPOWERS_SHA256SUMS'
}
elseif ($skillsRootTrusted) {
    try { [string[]]$manifestLines = @(Get-Content -LiteralPath $manifestFile) }
    catch { Add-Failure 'Cannot read file: .github/skills/SUPERPOWERS_SHA256SUMS'; $manifestLines = @() }
    if ($manifestLines.Count -eq 0) { Add-Failure 'Manifest must not be empty.' }
    $previousPath = $null
    $reportedUnsorted = $false
    for ($lineIndex = 0; $lineIndex -lt $manifestLines.Count; $lineIndex++) {
        $manifestMatch = [regex]::Match($manifestLines[$lineIndex], '^([0-9a-f]{64})  (.+)$')
        if (-not $manifestMatch.Success) {
            Add-Failure "Malformed manifest line $($lineIndex + 1)."
            continue
        }
        $hash = $manifestMatch.Groups[1].Value
        $relativePath = $manifestMatch.Groups[2].Value
        if ($null -ne $previousPath -and [StringComparer]::Ordinal.Compare($previousPath, $relativePath) -gt 0 -and -not $reportedUnsorted) {
            Add-Failure 'Manifest paths are not ordinally sorted.'
            $reportedUnsorted = $true
        }
        $previousPath = $relativePath
        if (-not $seenManifestPaths.Add($relativePath)) {
            Add-Failure "Duplicate manifest path: $relativePath"
            continue
        }
        if (Test-SafeManifestPath $relativePath) { $manifestEntries.Add($relativePath, $hash) }
    }
}

$runtimeFiles = [Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
foreach ($skillName in $skillNames) {
    if (-not $actualSkills.Contains($skillName)) { continue }
    try { $files = @(Get-ChildItem -LiteralPath (Join-Path $skillsRoot $skillName) -File -Recurse -Force) }
    catch { Add-Failure "Cannot enumerate runtime files for skill: $skillName"; continue }
    foreach ($file in $files) {
        $relativePath = $file.FullName.Substring($skillsPrefix.Length).Replace('\', '/')
        $runtimeFiles[$relativePath] = $file.FullName
    }
}
[string[]]$runtimePaths = @($runtimeFiles.Keys)
[Array]::Sort($runtimePaths, [StringComparer]::Ordinal)
foreach ($relativePath in $runtimePaths) {
    if (-not $manifestEntries.ContainsKey($relativePath)) {
        Add-Failure "Runtime file is missing from manifest: $relativePath"
        continue
    }
    try { $actualHash = (Get-FileHash -LiteralPath $runtimeFiles[$relativePath] -Algorithm SHA256).Hash.ToLowerInvariant() }
    catch { Add-Failure "Cannot hash runtime file: $relativePath"; continue }
    if ($actualHash -cne $manifestEntries[$relativePath]) {
        Add-Failure "Hash mismatch for runtime file: $relativePath"
    }
}
[string[]]$manifestPaths = @($manifestEntries.Keys)
[Array]::Sort($manifestPaths, [StringComparer]::Ordinal)
foreach ($relativePath in $manifestPaths) {
    if (-not $runtimeFiles.ContainsKey($relativePath)) {
        Add-Failure "Manifest path is not a runtime file: $relativePath"
    }
}

$executableRuntimePaths = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach ($relativePath in @(
    'brainstorming/scripts/start-server.sh', 'brainstorming/scripts/stop-server.sh',
    'subagent-driven-development/scripts/review-package', 'subagent-driven-development/scripts/sdd-workspace',
    'subagent-driven-development/scripts/task-brief', 'systematic-debugging/find-polluter.sh',
    'writing-skills/render-graphs.js'
)) { [void]$executableRuntimePaths.Add($relativePath) }
function Test-RuntimeGitMode {
    param([string]$ManifestRelativePath)

    $repositoryRelativePath = ".github/skills/$ManifestRelativePath"
    $expectedMode = if ($executableRuntimePaths.Contains($ManifestRelativePath)) { '100755' } else { '100644' }
    $valid = $false
    try {
        Push-Location -LiteralPath $repositoryRoot
        try { [string[]]$records = @(& git ls-files --stage -- $repositoryRelativePath 2>$null); $gitExitCode = $LASTEXITCODE }
        finally { Pop-Location }
        if ($gitExitCode -eq 0 -and $records.Count -eq 1) {
            $recordMatch = [regex]::Match($records[0], '^([0-9]{6}) [0-9a-f]+ ([0-3])\t(.+)$')
            $valid = $recordMatch.Success -and $recordMatch.Groups[1].Value -ceq $expectedMode -and
                $recordMatch.Groups[2].Value -ceq '0' -and $recordMatch.Groups[3].Value -ceq $repositoryRelativePath
        }
    }
    catch {}
    if (-not $valid) { Add-Failure "Expected Git mode ${expectedMode}: $repositoryRelativePath" }
}
foreach ($relativePath in $runtimePaths) { Test-RuntimeGitMode $relativePath }

Test-RequiredContent 'AGENTS.md' @('.github/skills', 'using-superpowers')
Test-RequiredContent '.github/copilot-instructions.md' @('.github/skills', 'using-superpowers')
Test-RequiredContent '.github/skills/SUPERPOWERS_VERSION' @() @(
    'name=Superpowers',
    'source=https://github.com/obra/superpowers',
    'release=v6.3.0',
    'version=6.3.0',
    'tag-object=86babb696875227929e85420f287d6309374b93f',
    'commit=b36e0829c6d0140e93cfef2ca599b1b07d4a7797',
    'vendored=2026-09-15',
    'upstream-path=skills/',
    'destination=.github/skills/',
    'manifest=SUPERPOWERS_SHA256SUMS',
    'included-skills=brainstorming,dispatching-parallel-agents,executing-plans,finishing-a-development-branch,receiving-code-review,requesting-code-review,subagent-driven-development,systematic-debugging,test-driven-development,using-git-worktrees,using-superpowers,verification-before-completion,writing-plans,writing-skills'
)
if ($skillsRootTrusted) {
    $licenseRelativePath = '.github/skills/LICENSE.superpowers'
    $licensePath = Join-Path $repositoryRoot ($licenseRelativePath.Replace('/', '\'))
    if (-not (Test-Path -LiteralPath $licensePath -PathType Leaf)) { Add-Failure "Missing file: $licenseRelativePath" }
    else {
        try { $licenseHash = (Get-FileHash -LiteralPath $licensePath -Algorithm SHA256).Hash.ToLowerInvariant() }
        catch { Add-Failure "Cannot hash file: $licenseRelativePath"; $licenseHash = $null }
        if ($licenseHash -and $licenseHash -cne 'a37e0e9697144819e1d965176ac4ae5bc3fa02d11e7812036bbcadf6dafe2400') {
            Add-Failure "License hash mismatch: $licenseRelativePath"
        }
    }
}
Test-RequiredContent 'README.md' @('Superpowers', 'v6.3.0', '.github/skills', 'verify-repository-setup.ps1')

if ($failures.Count -gt 0) {
    foreach ($failure in $failures) { Write-Output "ERROR: $failure" }
    Write-Output "Repository setup validation failed with $($failures.Count) error(s)."
    exit 1
}
Write-Output 'Repository setup validation passed.'
