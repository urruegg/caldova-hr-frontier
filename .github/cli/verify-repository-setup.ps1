[CmdletBinding()]
param(
    [switch]$SkipIntegratedTests,
    [switch]$SkipBicepBuild
)
$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$skillsRoot = Join-Path $repositoryRoot '.github\skills'
$skillsPrefix = [IO.Path]::GetFullPath($skillsRoot).TrimEnd('\') + '\'
$failures = [Collections.Generic.List[string]]::new()

function Add-Failure {
    param([string]$Message)
    [void]$failures.Add($Message)
}
$documentationMetadataModulePath = Join-Path $PSScriptRoot 'modules\DocumentationMetadata.psm1'
$documentationMetadataAvailable = $false
if (-not (Test-Path -LiteralPath $documentationMetadataModulePath -PathType Leaf)) {
    Add-Failure 'Missing documentation metadata module: .github/cli/modules/DocumentationMetadata.psm1'
}
else {
    try {
        Import-Module $documentationMetadataModulePath -Force -ErrorAction Stop
        $documentationMetadataAvailable = $true
    }
    catch {
        Add-Failure "Cannot import documentation metadata module: $($_.Exception.Message)"
    }
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
$issueTemplateFileNames = @('01-bug.yml', '02-feature.yml', '03-frontier-intake.yml', 'config.yml')
$issueTemplateGitPrefix = '.github/ISSUE_TEMPLATE/'
$expectedIssueTemplateGitPaths = @($issueTemplateFileNames | ForEach-Object { "${issueTemplateGitPrefix}$_" })
$gitattributesRelativePath = '.gitattributes'
$expectedIssueTemplateHashes = [Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
$expectedIssueTemplateHashes.Add('01-bug.yml', '8f2c31b169477b86d85e60f9d1c91eed349fae829f1071b8b42dc93624d8879a')
$expectedIssueTemplateHashes.Add('02-feature.yml', '748e69155e9e60acd16f5cbb93b6398fd5853905951829080a9c440ed5c0e7a4')
$expectedIssueTemplateHashes.Add('03-frontier-intake.yml', 'af13ab5a7c0aec18af59c10a257089b5b44ebf31208396b1c5903c56c394f840')
$expectedIssueTemplateHashes.Add('config.yml', '6913de0ee9863fce0c24df504fb706a88c38b090617a3071fe207fd8f9ec6cbb')
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

$gitCommand = Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
$gitIndexLines = @()
$gitIndexReadable = $false
$gitIndexRecords = [Collections.Generic.List[object]]::new()
$gitIndexRecordsByCaseInsensitivePath = [Collections.Generic.Dictionary[string,object]]::new([StringComparer]::OrdinalIgnoreCase)
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
    $issueTemplateGitRecords = [Collections.Generic.List[object]]::new()
    $protectedGitRecordsToCompare = [Collections.Generic.List[object]]::new()
    foreach ($line in $gitIndexLines) {
        $indexRecordMatch = [regex]::Match($line, '^([0-7]{6}) ((?:[0-9a-fA-F]{40}|[0-9a-fA-F]{64})) ([0-3])\t(.*)$')
        if (-not $indexRecordMatch.Success) {
            Add-Failure "Cannot parse Git index record: $line"
            continue
        }
        $record = [pscustomobject]@{
            Mode = $indexRecordMatch.Groups[1].Value
            ObjectId = $indexRecordMatch.Groups[2].Value
            Stage = $indexRecordMatch.Groups[3].Value
            Path = $indexRecordMatch.Groups[4].Value
        }
        [void]$gitIndexRecords.Add($record)
        if (-not $gitIndexRecordsByCaseInsensitivePath.ContainsKey($record.Path)) {
            $gitIndexRecordsByCaseInsensitivePath.Add($record.Path, [Collections.Generic.List[object]]::new())
        }
        $caseInsensitivePathRecords = [Collections.Generic.List[object]]$gitIndexRecordsByCaseInsensitivePath[$record.Path]
        [void]$caseInsensitivePathRecords.Add($record)
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
            Add-Failure "Git index content differs from working tree: $($record.Path)"
        }
        catch {
            Add-Failure "Cannot compare Git index content with working tree: $($record.Path)"
        }
    }
}

function Get-ExactGitIndexRecord {
    param([string]$RelativePath, [string]$ExpectedMode, [string]$FailureMessage)

    if (-not $gitIndexReadable) { return $null }
    if (-not $gitIndexRecordsByCaseInsensitivePath.ContainsKey($RelativePath)) {
        Add-Failure $FailureMessage
        return $null
    }
    $matchingRecords = @($gitIndexRecordsByCaseInsensitivePath[$RelativePath])
    if ($matchingRecords.Count -ne 1 -or $matchingRecords[0].Path -cne $RelativePath -or
        $matchingRecords[0].Stage -cne '0' -or $matchingRecords[0].Mode -cne $ExpectedMode) {
        Add-Failure $FailureMessage
        return $null
    }
    return $matchingRecords[0]
}

function Test-GitIndexContentMatchesWorkingTree {
    param([object]$Record)

    try {
        [string[]]$workingTreeObjectIdLines = @(& $gitCommand.Source -C $repositoryRoot hash-object --no-filters -- $Record.Path 2>&1 |
            ForEach-Object { $_.ToString() })
        $hashObjectExitCode = $LASTEXITCODE
        if ($hashObjectExitCode -ne 0 -or $workingTreeObjectIdLines.Count -ne 1 -or
            $workingTreeObjectIdLines[0] -notmatch '^(?:[0-9a-fA-F]{40}|[0-9a-fA-F]{64})$') {
            Add-Failure "Cannot compare Git index content with working tree: $($Record.Path)"
            return
        }
        $workingTreeObjectId = $workingTreeObjectIdLines[0].ToLowerInvariant()
        $indexObjectId = $Record.ObjectId.ToLowerInvariant()
        if ($workingTreeObjectId -cne $indexObjectId) {
            Add-Failure "Git index content differs from working tree: $($Record.Path)"
        }
    }
    catch {
        Add-Failure "Cannot compare Git index content with working tree: $($Record.Path)"
    }
}

$gitattributesPath = Join-Path $repositoryRoot $gitattributesRelativePath
$gitattributesSelfByteStabilityRule = '/.gitattributes -text'
$issueTemplateByteStabilityRule = '/.github/ISSUE_TEMPLATE/*.yml -text'
$gitattributesLines = @()
$gitattributesReadable = $false
$gitattributesSelfByteStabilityRuleValid = $false
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
    $selfByteStabilityRuleCount = @($gitattributesLines | Where-Object {
        $_ -ceq $gitattributesSelfByteStabilityRule
    }).Count
    $gitattributesSelfByteStabilityRuleValid = $selfByteStabilityRuleCount -eq 1
    if (-not $gitattributesSelfByteStabilityRuleValid) {
        Add-Failure '.gitattributes must contain exactly one self byte-stability rule.'
    }
    $issueTemplateByteStabilityRuleCount = @($gitattributesLines | Where-Object {
        $_ -ceq $issueTemplateByteStabilityRule
    }).Count
    if ($issueTemplateByteStabilityRuleCount -ne 1) {
        Add-Failure '.gitattributes must contain exactly one issue-form byte-stability rule.'
    }
}

$expectedGitTextAttributePaths = @($gitattributesRelativePath) + @($expectedIssueTemplateGitPaths)
$gitAttributeLines = @()
$gitAttributesReadable = $false
if ($null -eq $gitCommand) {
    Add-Failure 'Cannot inspect Git text attributes for protected paths: git is unavailable'
}
else {
    try {
        $gitAttributeLines = @(& $gitCommand.Source -C $repositoryRoot -c core.quotePath=false check-attr text -- $expectedGitTextAttributePaths 2>&1 |
            ForEach-Object { $_.ToString() })
        $gitAttributeExitCode = $LASTEXITCODE
        if ($gitAttributeExitCode -ne 0) {
            Add-Failure 'Cannot inspect Git text attributes for protected paths'
        }
        else {
            $gitAttributesReadable = $true
        }
    }
    catch {
        Add-Failure 'Cannot inspect Git text attributes for protected paths'
    }
}

if ($gitAttributesReadable) {
    if ($gitAttributeLines.Count -ne $expectedGitTextAttributePaths.Count) {
        Add-Failure "Expected $($expectedGitTextAttributePaths.Count) Git text attribute records, found $($gitAttributeLines.Count)"
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
        if ($expectedGitTextAttributePaths -cnotcontains $normalizedReportedPath) {
            Add-Failure "Unexpected Git text attribute path: $reportedPath"
            continue
        }
        [void]$gitAttributeRecords.Add([pscustomobject]@{
            Path = $normalizedReportedPath
            Value = $attributeMatch.Groups[2].Value
        })
    }
    foreach ($expectedPath in $expectedGitTextAttributePaths) {
        $matchingAttributeRecords = @($gitAttributeRecords | Where-Object { $_.Path -ceq $expectedPath })
        if ($matchingAttributeRecords.Count -ne 1) {
            Add-Failure "Ambiguous Git text attribute result: $expectedPath"
            continue
        }
        if ($matchingAttributeRecords[0].Value -ceq 'unset') { continue }
        if ($expectedPath -ceq $gitattributesRelativePath) {
            if ($gitattributesSelfByteStabilityRuleValid) {
                Add-Failure ".gitattributes Git text attribute is not unset: $expectedPath"
            }
        }
        else {
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

$manifestRepositoryRelativePath = '.github/skills/SUPERPOWERS_SHA256SUMS'
$manifestFile = Join-Path $skillsRoot 'SUPERPOWERS_SHA256SUMS'
$expectedManifestHash = 'be8b1626ea290a4cc0a99ccf0e4878fcf8c5ca7d238094be3d23b59563d28f1c'
$manifestEntries = [Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
$seenManifestPaths = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
if ($skillsRootTrusted -and -not (Test-Path -LiteralPath $manifestFile -PathType Leaf)) {
    Add-Failure "Missing file: $manifestRepositoryRelativePath"
}
elseif ($skillsRootTrusted) {
    try { $actualManifestHash = (Get-FileHash -LiteralPath $manifestFile -Algorithm SHA256).Hash.ToLowerInvariant() }
    catch { Add-Failure "Cannot hash pinned manifest: $manifestRepositoryRelativePath"; $actualManifestHash = $null }
    if ($actualManifestHash -and $actualManifestHash -cne $expectedManifestHash) {
        Add-Failure "Pinned manifest hash mismatch: $manifestRepositoryRelativePath"
    }
    try { [string[]]$manifestLines = @(Get-Content -LiteralPath $manifestFile) }
    catch { Add-Failure "Cannot read file: $manifestRepositoryRelativePath"; $manifestLines = @() }
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

$runtimeGitPrefix = '.github/skills/'
$allowedSkillRootGitPathsByCaseInsensitivePath = [Collections.Generic.Dictionary[string,string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($repositoryRelativePath in @(
    '.github/skills/README.md', '.github/skills/LICENSE.superpowers',
    '.github/skills/SUPERPOWERS_SHA256SUMS', '.github/skills/SUPERPOWERS_VERSION'
)) {
    $allowedSkillRootGitPathsByCaseInsensitivePath.Add($repositoryRelativePath, $repositoryRelativePath)
}
$expectedRuntimeGitPaths = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$expectedRuntimeGitPathsByCaseInsensitivePath = [Collections.Generic.Dictionary[string,string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($relativePath in $manifestPaths) {
    $repositoryRelativePath = "$runtimeGitPrefix$relativePath"
    [void]$expectedRuntimeGitPaths.Add($repositoryRelativePath)
    if (-not $expectedRuntimeGitPathsByCaseInsensitivePath.ContainsKey($repositoryRelativePath)) {
        $expectedRuntimeGitPathsByCaseInsensitivePath.Add($repositoryRelativePath, $repositoryRelativePath)
    }
}
$expectedSkillNamesByCaseInsensitiveName = [Collections.Generic.Dictionary[string,string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($skillName in $skillNames) { $expectedSkillNamesByCaseInsensitiveName.Add($skillName, $skillName) }
$reportedSkillRootGitCasingPaths = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$reportedUnexpectedSkillRootGitPaths = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$reportedUnexpectedSkillGitPaths = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$reportedRuntimeGitCasingPaths = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$reportedUnexpectedRuntimeGitPaths = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach ($record in $gitIndexRecords) {
    if (-not $record.Path.StartsWith($runtimeGitPrefix, [StringComparison]::OrdinalIgnoreCase)) { continue }
    $runtimeRelativePath = $record.Path.Substring($runtimeGitPrefix.Length)
    $skillSeparatorIndex = $runtimeRelativePath.IndexOf('/')
    if ($skillSeparatorIndex -lt 0) {
        if (-not $allowedSkillRootGitPathsByCaseInsensitivePath.ContainsKey($record.Path)) {
            if ($reportedUnexpectedSkillRootGitPaths.Add($record.Path)) {
                Add-Failure "Unexpected tracked path under .github/skills: $($record.Path)"
            }
            continue
        }
        $expectedSkillRootGitPath = $allowedSkillRootGitPathsByCaseInsensitivePath[$record.Path]
        if ($record.Path -cne $expectedSkillRootGitPath -and $reportedSkillRootGitCasingPaths.Add($record.Path)) {
            Add-Failure "Tracked path under .github/skills must use exact Git casing: $($record.Path)"
        }
        continue
    }
    $runtimeSkillName = $runtimeRelativePath.Substring(0, $skillSeparatorIndex)
    if (-not $expectedSkillNamesByCaseInsensitiveName.ContainsKey($runtimeSkillName)) {
        if ($reportedUnexpectedSkillGitPaths.Add($record.Path)) {
            Add-Failure "Unexpected tracked skill path: $($record.Path)"
        }
        continue
    }
    $expectedSkillName = $expectedSkillNamesByCaseInsensitiveName[$runtimeSkillName]
    $expectedRuntimeGitPath = if ($expectedRuntimeGitPathsByCaseInsensitivePath.ContainsKey($record.Path)) {
        $expectedRuntimeGitPathsByCaseInsensitivePath[$record.Path]
    } else { $null }
    if (-not $record.Path.StartsWith($runtimeGitPrefix, [StringComparison]::Ordinal) -or
        $runtimeSkillName -cne $expectedSkillName -or
        ($null -ne $expectedRuntimeGitPath -and $record.Path -cne $expectedRuntimeGitPath)) {
        if ($reportedRuntimeGitCasingPaths.Add($record.Path)) {
            Add-Failure "Tracked runtime path must use exact Git casing: $($record.Path)"
        }
        continue
    }
    if (-not $expectedRuntimeGitPaths.Contains($record.Path) -and $reportedUnexpectedRuntimeGitPaths.Add($record.Path)) {
        Add-Failure "Unexpected tracked runtime path: $($record.Path)"
    }
}

$executableRuntimePaths = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach ($relativePath in @(
    'brainstorming/scripts/start-server.sh', 'brainstorming/scripts/stop-server.sh',
    'subagent-driven-development/scripts/review-package', 'subagent-driven-development/scripts/sdd-workspace',
    'subagent-driven-development/scripts/task-brief', 'systematic-debugging/find-polluter.sh',
    'writing-skills/render-graphs.js'
)) { [void]$executableRuntimePaths.Add($relativePath) }
$runtimeSnapshotGitRecords = [Collections.Generic.List[object]]::new()
if ($gitIndexReadable) {
    $manifestGitRecord = Get-ExactGitIndexRecord $manifestRepositoryRelativePath '100644' `
        "Pinned manifest Git entry must be unique, exact-case, stage-0 mode 100644: $manifestRepositoryRelativePath"
    if ($null -ne $manifestGitRecord) { [void]$runtimeSnapshotGitRecords.Add($manifestGitRecord) }
    foreach ($relativePath in $manifestPaths) {
        $repositoryRelativePath = ".github/skills/$relativePath"
        $expectedMode = if ($executableRuntimePaths.Contains($relativePath)) { '100755' } else { '100644' }
        $runtimeGitRecord = Get-ExactGitIndexRecord $repositoryRelativePath $expectedMode `
            "Expected Git mode ${expectedMode}: $repositoryRelativePath"
        if ($null -ne $runtimeGitRecord) { [void]$runtimeSnapshotGitRecords.Add($runtimeGitRecord) }
    }
    foreach ($record in $runtimeSnapshotGitRecords) {
        Test-GitIndexContentMatchesWorkingTree $record
    }
}

Test-RequiredContent 'AGENTS.md' @('.github/skills', 'using-superpowers', '.github/agents/docs-agent.agent.md')
Test-RequiredContent '.github/copilot-instructions.md' @('.github/skills', 'using-superpowers', '.github/agents/docs-agent.agent.md')
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
Test-RequiredContent 'docs/README.md' @(
    'All maintained repository documentation is written in English',
    'standard six-field metadata table',
    '.github/agents/docs-agent.agent.md'
)
Test-RequiredContent '.github/agents/docs-agent.agent.md' @(
    'name: docs-agent',
    'tools: [read, search, edit, todo]',
    'standard six-field metadata header',
    'written in English'
)
Test-RequiredContent 'docs/reviews/2026-09-17-architecture-baseline-source-inventory.json' @(
    '"schemaVersion"',
    '"sourceName"',
    '"totalCount"',
    '"sha256"'
)
Test-RequiredContent 'docs/reviews/2026-09-17-phase-1-governance-github-intake.md' @(
    '# Phase 1 Governance and GitHub Intake Review',
    'Proposed Baseline',
    'Phase 1 Inventory Disposition'
)
Test-RequiredContent '.github/CODEOWNERS' @('* @urruegg', '/.github/ @urruegg', '/docs/ @urruegg')
Test-RequiredContent '.github/pull_request_template.md' @(
    '# Pull Request',
    '### Governance',
    '### Validation evidence'
)
Test-RequiredContent '.github/dependabot.yml' @('package-ecosystem: "github-actions"', 'interval: "weekly"')
Test-RequiredContent '.github/workflows/validate-repository.yml' @(
    'name: Validate repository',
    'actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1',
    'Repository setup validation',
    'RepositorySafety.Tests.ps1',
    'infra/tests/pester',
    'verify-repository-safety.ps1',
    'az bicep build --file infra/src/bicep/main.bicep --stdout'
)
Test-RequiredContent '.github/workflows/audit-repository.yml' @(
    'name: Audit repository baseline',
    'Repository baseline audit (advisory)',
    'verify-repository-setup.ps1 -SkipIntegratedTests -SkipBicepBuild'
)

$phase3RequiredPaths = @(
    '.github/cli/tests/Phase3SourceContract.Tests.ps1',
    '.github/workflows/README.md',
    '.github/workflows/bootstrap-tenant.yml',
    '.github/workflows/discover-tenant.yml',
    'docs/reviews/2026-09-17-phase-3-infrastructure-tenant-bootstrap-intake.md',
    'infra/README.md',
    'infra/docs/10-tenant-setup-and-configuration.md',
    'infra/docs/11-identity-and-access.md',
    'infra/docs/12-power-platform-environments-and-alm.md',
    'infra/docs/13-azure-devops-engineering-control-plane.md',
    'infra/docs/14-github-repository-blueprint.md',
    'infra/docs/15-agent-workload-configuration.md',
    'infra/docs/16-security-governance-and-compliance.md',
    'infra/docs/17-bootstrap-and-provisioning.md',
    'infra/docs/18-multi-tenant-provisioning.md',
    'infra/docs/19-bootstrap-recovery.md',
    'infra/src/bicep/bicepconfig.json',
    'infra/src/bicep/main.bicep',
    'infra/src/bicep/modules/activity-log-diagnostics.bicep',
    'infra/src/bicep/modules/log-analytics-workspace.bicep',
    'infra/src/bicep/modules/resource-group.bicep',
    'infra/src/bicep/modules/subscription-policy-assignments.bicep',
    'infra/src/bicep/modules/validation-role.bicep',
    'infra/src/config/schemas/bootstrap-result.schema.json',
    'infra/src/config/schemas/discovery.schema.json',
    'infra/src/config/schemas/tenant.schema.json',
    'infra/src/config/tenants/_template.psd1',
    'infra/src/config/tenants/caldova25156897.psd1',
    'infra/src/scripts/Get-TemporaryBootstrapRoleState.ps1',
    'infra/src/scripts/Grant-TemporaryBootstrapRoles.ps1',
    'infra/src/scripts/Initialize-TenantTrust.ps1',
    'infra/src/scripts/Invoke-TenantBootstrap.ps1',
    'infra/src/scripts/Invoke-TenantDiscovery.ps1',
    'infra/src/scripts/New-TenantBicepParameters.ps1',
    'infra/src/scripts/New-TenantManifest.ps1',
    'infra/src/scripts/Test-WhatIfBoundary.ps1',
    'infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Caldova.HrFrontier.Bootstrap.psd1',
    'infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Caldova.HrFrontier.Bootstrap.psm1',
    'infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/Get-AzureDevOpsDiscovery.ps1',
    'infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/Get-AzureDiscovery.ps1',
    'infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/Get-EntraDiscovery.ps1',
    'infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/Get-GitHubDiscovery.ps1',
    'infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/Get-PowerPlatformDiscovery.ps1',
    'infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/Invoke-BoundedRetry.ps1',
    'infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/Test-ProhibitedData.ps1',
    'infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/ConvertTo-DiscoveryEvidence.ps1',
    'infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Get-GitHubOidcSubject.ps1',
    'infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Get-TenantResourceName.ps1',
    'infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Import-TenantConfiguration.ps1',
    'infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/New-TenantSuffix.ps1',
    'infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Remove-TemporaryRoleAssignments.ps1',
    'infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Test-DiscoveryEvidence.ps1',
    'infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Test-TenantIntent.ps1',
    'infra/src/solutions/README.md',
    'infra/tests/fixtures/discovery/azure-devops.json',
    'infra/tests/fixtures/discovery/azure.json',
    'infra/tests/fixtures/discovery/entra.json',
    'infra/tests/fixtures/discovery/github.json',
    'infra/tests/fixtures/discovery/power-platform.json',
    'infra/tests/fixtures/what-if/allowed.json',
    'infra/tests/fixtures/what-if/unexpected-type.json',
    'infra/tests/fixtures/what-if/wrong-scope.json',
    'infra/tests/pester/BicepComposition.Tests.ps1',
    'infra/tests/pester/DiscoveryNormalization.Tests.ps1',
    'infra/tests/pester/EvidenceGate.Tests.ps1',
    'infra/tests/pester/EvidenceSecurity.Tests.ps1',
    'infra/tests/pester/Idempotency.Tests.ps1',
    'infra/tests/pester/IntentGate.Tests.ps1',
    'infra/tests/pester/Naming.Tests.ps1',
    'infra/tests/pester/TemporaryRoleCleanup.Tests.ps1',
    'infra/tests/pester/TenantConfiguration.Tests.ps1',
    'infra/tests/pester/TenantTrust.Tests.ps1',
    'infra/tests/pester/WhatIfBoundary.Tests.ps1',
    'infra/tests/pester/WorkflowContract.Tests.ps1'
)
foreach ($relativePath in $phase3RequiredPaths) {
    Test-RequiredContent $relativePath @()
    if ($gitIndexReadable) {
        [void](Get-ExactGitIndexRecord $relativePath '100644' `
            "Phase 3 path must be tracked at exact case as stage-0 mode 100644: $relativePath")
    }
}

Test-RequiredContent 'infra/src/config/schemas/discovery.schema.json' @(
    '"GitHub"', '"Entra"', '"Azure"', '"AzureDevOps"', '"PowerPlatform"'
)
Test-RequiredContent 'infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/Test-ProhibitedData.ps1' @(
    'access[_-]?token', 'refresh[_-]?token', 'client[_-]?secret', 'authorization:\s*bearer',
    'AccountKey=', 'SharedAccessSignature=', 'PRIVATE KEY', 'Principal.Upn'
)
Test-RequiredContent 'infra/tests/pester/BicepComposition.Tests.ps1' @(
    'Microsoft.Resources/resourceGroups',
    'Microsoft.OperationalInsights/workspaces',
    'Microsoft.Insights/diagnosticSettings',
    'Microsoft.Authorization/roleDefinitions',
    'Microsoft.Authorization/roleAssignments',
    'Microsoft.Authorization/policyAssignments'
)
foreach ($workflowPath in @('.github/workflows/bootstrap-tenant.yml', '.github/workflows/discover-tenant.yml')) {
    Test-RequiredContent $workflowPath @(
        'permissions:',
        'contents: read',
        'id-token: write',
        'actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1',
        'azure/login@a457da9ea143d694b1b9c7c869ebb04ebe844ef5',
        'environment: bootstrap-${{ inputs.tenantAlias }}'
    )
}

$phase3TenantManifestRelativePath = 'infra/src/config/tenants/caldova25156897.psd1'
$phase3TenantManifestPath = Join-Path $repositoryRoot ($phase3TenantManifestRelativePath.Replace('/', '\'))
if (Test-Path -LiteralPath $phase3TenantManifestPath -PathType Leaf) {
    try {
        $tenantConfiguration = Import-PowerShellDataFile -LiteralPath $phase3TenantManifestPath
        $expectedNamingRoot = '{0}-{1}-{2}' -f
            $tenantConfiguration.CompanyTla,
            $tenantConfiguration.WorkloadName,
            $tenantConfiguration.UniqueSuffix
        if ($tenantConfiguration.NamingRoot -cne $expectedNamingRoot -or
            $tenantConfiguration.NamingRoot -cne 'cal-hr-agentic-bc8rbt') {
            Add-Failure 'Tenant 1 NamingRoot does not match its reviewed derivation.'
        }
        if ($tenantConfiguration.GitHub.Owner -cne 'urruegg' -or
            $tenantConfiguration.GitHub.OwnerId -cne '46865858' -or
            $tenantConfiguration.GitHub.Repository -cne 'caldova-hr-frontier' -or
            $tenantConfiguration.GitHub.RepositoryId -cne '1371297722' -or
            $tenantConfiguration.GitHub.EnvironmentName -cne 'bootstrap-caldova25156897') {
            Add-Failure 'Tenant 1 GitHub identity does not match the reviewed immutable IDs and Environment.'
        }
        $oidcSubject = 'repo:{0}@{1}/{2}@{3}:environment:{4}' -f
            $tenantConfiguration.GitHub.Owner,
            $tenantConfiguration.GitHub.OwnerId,
            $tenantConfiguration.GitHub.Repository,
            $tenantConfiguration.GitHub.RepositoryId,
            $tenantConfiguration.GitHub.EnvironmentName
        if ($oidcSubject -cne 'repo:urruegg@46865858/caldova-hr-frontier@1371297722:environment:bootstrap-caldova25156897') {
            Add-Failure 'Tenant 1 immutable OIDC subject does not match the reviewed prefix and Environment.'
        }
    }
    catch {
        Add-Failure "Cannot validate the Tenant 1 manifest contract: $($_.Exception.Message)"
    }
}

$infraRoot = Join-Path $repositoryRoot 'infra'
if (Test-Path -LiteralPath $infraRoot -PathType Container) {
    foreach ($placeholder in @(Get-ChildItem -LiteralPath $infraRoot -Filter '.gitkeep' -File -Recurse -Force)) {
        $relativePlaceholder = $placeholder.FullName.Substring($repositoryRoot.Length).TrimStart('\').Replace('\', '/')
        Add-Failure "Rejected infrastructure placeholder remains: $relativePlaceholder"
    }
}

$tenantManifestRoot = Join-Path $repositoryRoot 'infra\src\config\tenants'
if (Test-Path -LiteralPath $tenantManifestRoot -PathType Container) {
    $allowedTenantManifestNames = @('_template.psd1', 'caldova25156897.psd1')
    foreach ($tenantManifest in @(Get-ChildItem -LiteralPath $tenantManifestRoot -Filter '*.psd1' -File -Force)) {
        if ($allowedTenantManifestNames -cnotcontains $tenantManifest.Name) {
            Add-Failure "Tenant 2 or Tenant 3 manifest is not allowed in this phase: infra/src/config/tenants/$($tenantManifest.Name)"
        }
    }
}

$prohibitedBootstrapPattern = 'az\s+deployment\s+sub\s+create|New-AzSubscriptionDeployment|client[_-]?secret|AZURE_CLIENT_SECRET|--password'
$phase3ExecutablePaths = [Collections.Generic.List[string]]::new()
if (Test-Path -LiteralPath (Join-Path $repositoryRoot 'infra\src\scripts') -PathType Container) {
    foreach ($scriptFile in @(Get-ChildItem -LiteralPath (Join-Path $repositoryRoot 'infra\src\scripts') -File -Recurse -Force | Where-Object {
        $_.Extension -in @('.ps1', '.psm1')
    })) {
        [void]$phase3ExecutablePaths.Add($scriptFile.FullName)
    }
}
foreach ($workflowPath in @('.github/workflows/bootstrap-tenant.yml', '.github/workflows/discover-tenant.yml')) {
    $absoluteWorkflowPath = Join-Path $repositoryRoot ($workflowPath.Replace('/', '\'))
    if (Test-Path -LiteralPath $absoluteWorkflowPath -PathType Leaf) {
        [void]$phase3ExecutablePaths.Add($absoluteWorkflowPath)
    }
}
foreach ($executablePath in $phase3ExecutablePaths) {
    try { $executableContent = [IO.File]::ReadAllText($executablePath) }
    catch { Add-Failure "Cannot scan executable Phase 3 file: $executablePath"; continue }
    if ($executableContent -match $prohibitedBootstrapPattern) {
        $relativeExecutablePath = $executablePath.Substring($repositoryRoot.Length).TrimStart('\').Replace('\', '/')
        Add-Failure "Prohibited bootstrap command or credential pattern found: $relativeExecutablePath"
    }
}

$phase3ReviewRelativePath = 'docs/reviews/2026-09-17-phase-3-infrastructure-tenant-bootstrap-intake.md'
Test-RequiredContent $phase3ReviewRelativePath @(
    '**Status** | Approved',
    'implementation-intake approval',
    'Task 1 documentation target: `18b3977`',
    'Task 2 configuration target: `5cde70b`',
    'Task 3 discovery target: `41dc36a`',
    'Task 4 trust target: `89a316a`',
    'Task 5 Bicep target: `82b6ef9`',
    'Task 6 bootstrap safety target: `7cde772`',
    'Task 7 workflow target: `c0bf369`',
    'All five source placeholders are absent and replaced',
    'does not prove or authorize live trust creation',
    'role mutation',
    'what-if completion',
    'deployment',
    'Power Platform mutation',
    'Tenant 2 or Tenant 3 provisioning',
    'final governance activation'
)
$phase3ReviewPath = Join-Path $repositoryRoot ($phase3ReviewRelativePath.Replace('/', '\'))
if (Test-Path -LiteralPath $phase3ReviewPath -PathType Leaf) {
    try { $phase3ReviewContent = [IO.File]::ReadAllText($phase3ReviewPath) }
    catch { Add-Failure "Cannot read file: $phase3ReviewRelativePath"; $phase3ReviewContent = '' }
    if ($phase3ReviewContent -match '(?i)commit(?: ID)? pending|scheduled') {
        Add-Failure "$phase3ReviewRelativePath retains a pending or scheduled inventory status."
    }
}

Test-RequiredContent 'README.md' @(
    '### Phase 3 Infrastructure Map',
    '[Phase 3 Infrastructure and Tenant Bootstrap Intake](docs/reviews/2026-09-17-phase-3-infrastructure-tenant-bootstrap-intake.md)',
    '`infra/src/config/tenants/caldova25156897.psd1`',
    '`infra/src/scripts/Invoke-TenantDiscovery.ps1`',
    '`infra/src/scripts/Initialize-TenantTrust.ps1`',
    '`infra/src/scripts/Invoke-TenantBootstrap.ps1`',
    'No live deployment is authorized by this repository state.'
)
Test-RequiredContent '.github/cli/README.md' @(
    'Git',
    'Pester 5.7.1',
    'Azure CLI with the Bicep command',
    'Invoke-Pester .github/cli/tests,infra/tests/pester -Output Detailed -CI',
    'az bicep build --file infra/src/bicep/main.bicep --stdout',
    'does not authenticate or call Azure services'
)

if ($null -eq $gitCommand) {
    Add-Failure 'Cannot enumerate tracked Markdown documentation: git is unavailable'
}
else {
    try {
        [string[]]$trackedMarkdownPaths = @(& $gitCommand.Source -C $repositoryRoot -c core.quotePath=false ls-files -- '*.md' 2>&1 |
            ForEach-Object { $_.ToString() })
        $trackedMarkdownExitCode = $LASTEXITCODE
        if ($trackedMarkdownExitCode -ne 0) {
            Add-Failure 'Cannot enumerate tracked Markdown documentation with git ls-files'
        }
        elseif ($documentationMetadataAvailable) {
            foreach ($relativePath in $trackedMarkdownPaths) {
                if (-not (Test-DocumentationMetadataEligibility -RelativePath $relativePath)) { continue }
                $documentPath = Join-Path $repositoryRoot ($relativePath.Replace('/', '\'))
                if (-not (Test-Path -LiteralPath $documentPath -PathType Leaf)) {
                    Add-Failure "Tracked Markdown file is missing from the working tree: $relativePath"
                    continue
                }
                try {
                    $documentContent = [IO.File]::ReadAllText($documentPath)
                    $metadataFailures = @(Test-DocumentationMetadataContent `
                        -Content $documentContent `
                        -DocumentRelativePath $relativePath)
                    foreach ($metadataFailure in $metadataFailures) {
                        Add-Failure "Documentation metadata invalid for ${relativePath}: $metadataFailure"
                    }
                }
                catch {
                    Add-Failure "Cannot validate documentation metadata for ${relativePath}: $($_.Exception.Message)"
                }
            }
        }
    }
    catch {
        Add-Failure "Cannot enumerate tracked Markdown documentation with git ls-files: $($_.Exception.Message)"
    }
}

if (-not $SkipIntegratedTests) {
    $requiredPesterVersion = [Version]'5.7.1'
    $pesterModule = @(Get-Module -ListAvailable -Name Pester | Where-Object {
        $_.Version -eq $requiredPesterVersion
    } | Select-Object -First 1)
    if ($pesterModule.Count -ne 1) {
        Add-Failure 'Required Pester version 5.7.1 is unavailable.'
    }
    else {
    $validationSuitePaths = @(
        (Join-Path $PSScriptRoot 'tests'),
        (Join-Path $repositoryRoot 'infra\tests\pester')
    )
    $powershellCommand = Get-Command powershell.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -eq $powershellCommand) {
        Add-Failure 'Cannot run integrated repository and infrastructure Pester suites: powershell.exe is unavailable.'
    }
    $escapedPesterModulePath = $pesterModule[0].Path.Replace("'", "''")
    $escapedValidationSuitePaths = @($validationSuitePaths | ForEach-Object {
        "'$($_.Replace("'", "''"))'"
    }) -join ', '
    $pesterCommand = @"
`$ErrorActionPreference = 'Stop'
`$pesterPowerShell = [PowerShell]::Create()
`$pesterOutput = @()
`$invocationFailed = `$false
try {
    [void]`$pesterPowerShell.AddCommand('Import-Module').AddParameter('Name', '$escapedPesterModulePath').AddParameter('Force').AddParameter('ErrorAction', 'Stop')
    [void]`$pesterPowerShell.AddStatement()
    [void]`$pesterPowerShell.AddCommand('Pester\Invoke-Pester').AddParameter('Path', @($escapedValidationSuitePaths)).AddParameter('Output', 'None').AddParameter('PassThru')
    `$pesterOutput = @(`$pesterPowerShell.Invoke())
}
catch {
    `$invocationFailed = `$true
}
`$pesterResults = @(`$pesterOutput | Where-Object {
    `$null -ne `$_ -and
    `$null -ne `$_.PSObject.Properties['Result'] -and
    `$null -ne `$_.PSObject.Properties['FailedCount']
})
`$result = if (`$pesterResults.Count -eq 1) { `$pesterResults[0] } else { `$null }
`$summary = [ordered]@{
    Result = if (`$null -ne `$result) { `$result.Result.ToString() } else { 'Missing' }
    TotalCount = if (`$null -ne `$result) { `$result.TotalCount } else { 0 }
    PassedCount = if (`$null -ne `$result) { `$result.PassedCount } else { 0 }
    FailedCount = if (`$null -ne `$result) { `$result.FailedCount } else { 0 }
    SkippedCount = if (`$null -ne `$result) { `$result.SkippedCount } else { 0 }
    HadErrors = (`$invocationFailed -or `$pesterPowerShell.HadErrors)
    ErrorCount = @(`$pesterPowerShell.Streams.Error).Count
    FailedTests = if (`$null -ne `$result) { @(`$result.Failed | ForEach-Object {
        `$failureName = if (-not [string]::IsNullOrWhiteSpace([string]`$_.ExpandedName)) { [string]`$_.ExpandedName } else { [string]`$_.Name }
        if (`$failureName.Length -gt 300) { `$failureName = `$failureName.Substring(0, 300) + '...' }
        `$failureMessage = [string]`$_.ErrorRecord.Exception.Message -replace '[\r\n]+', ' '
        `$failureMessage = `$failureMessage -replace '(?i)-----BEGIN(?: [A-Z0-9]+)* PRIVATE KEY-----.*?-----END(?: [A-Z0-9]+)* PRIVATE KEY-----', '[REDACTED]'
        `$failureMessage = `$failureMessage -replace '(?i)(?:authorization\s*[:=]\s*(?:\S+(?:\s+\S+)?)|sharedaccesssignature\s+\S+|(?:access[_\s-]?token|refresh[_\s-]?token|client[_\s-]?secret|password|api[_\s-]?key|accountkey|sharedaccesskey|(?:sig|signature))\s*[:=]\s*(?:"[^"]*"|''[^'']*''|[^&\s;,]+)|eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)', '[REDACTED]'
        if (`$failureMessage.Length -gt 1000) { `$failureMessage = `$failureMessage.Substring(0, 1000) + '...' }
        '{0}: {1}' -f `$failureName, `$failureMessage
    } | Select-Object -First 10) } else { @() }
}
Write-Output ('__PESTER_RESULT__' + (`$summary | ConvertTo-Json -Compress))
`$pesterPowerShell.Dispose()
if (`$pesterResults.Count -ne 1 -or `$summary.HadErrors -or `$summary.Result -cne 'Passed' -or `$summary.FailedCount -ne 0) { exit 1 }
"@
    $pesterProcess = $null
    try {
        if ($null -eq $powershellCommand) { throw 'powershell.exe is unavailable.' }
        $pesterProcessStartInfo = [Diagnostics.ProcessStartInfo]::new()
        $pesterProcessStartInfo.FileName = $powershellCommand.Source
        $pesterProcessStartInfo.Arguments = '-NoProfile -ExecutionPolicy Bypass -EncodedCommand {0}' -f `
            [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($pesterCommand))
        $pesterProcessStartInfo.WorkingDirectory = $repositoryRoot
        $pesterProcessStartInfo.UseShellExecute = $false
        $pesterProcessStartInfo.CreateNoWindow = $true
        $pesterProcessStartInfo.RedirectStandardOutput = $true
        $pesterProcessStartInfo.RedirectStandardError = $true
        $pesterProcess = [Diagnostics.Process]::new()
        $pesterProcess.StartInfo = $pesterProcessStartInfo
        [void]$pesterProcess.Start()
        $pesterStandardOutputTask = $pesterProcess.StandardOutput.ReadToEndAsync()
        $pesterStandardErrorTask = $pesterProcess.StandardError.ReadToEndAsync()
        $pesterProcess.WaitForExit()
        $pesterStandardOutput = $pesterStandardOutputTask.Result
        $pesterStandardError = $pesterStandardErrorTask.Result
        $pesterResultLines = @($pesterStandardOutput -split "`r?`n" | Where-Object {
            $_.StartsWith('__PESTER_RESULT__', [StringComparison]::Ordinal)
        })
        if ($pesterResultLines.Count -ne 1) {
            $capturedError = if ([string]::IsNullOrWhiteSpace($pesterStandardError)) {
                'no result summary was returned'
            }
            else {
                $pesterStandardError.Trim()
            }
            Add-Failure "Cannot run integrated repository and infrastructure Pester suites under version 5.7.1: $capturedError"
        }
        else {
            $pesterResult = $pesterResultLines[0].Substring('__PESTER_RESULT__'.Length) | ConvertFrom-Json
            if ($pesterProcess.ExitCode -ne 0 -or
                $pesterResult.PSObject.Properties.Name -notcontains 'HadErrors' -or
                $pesterResult.HadErrors -ne $false -or
                $pesterResult.Result -cne 'Passed' -or
                $pesterResult.FailedCount -ne 0) {
                $resultSummary = 'result={0}, total={1}, passed={2}, failed={3}, skipped={4}, hadErrors={5}, errorCount={6}, failedTests={7}' -f
                    $pesterResult.Result,
                    $pesterResult.TotalCount,
                    $pesterResult.PassedCount,
                    $pesterResult.FailedCount,
                    $pesterResult.SkippedCount,
                    $pesterResult.HadErrors,
                    $pesterResult.ErrorCount,
                    (@($pesterResult.FailedTests) -join ' || ')
                Add-Failure "Integrated repository and infrastructure Pester suites did not pass under version 5.7.1: $resultSummary"
            }
        }
    }
    catch {
        Add-Failure "Cannot run integrated repository and infrastructure Pester suites under version 5.7.1: $($_.Exception.Message)"
    }
    finally {
        if ($null -ne $pesterProcess) { $pesterProcess.Dispose() }
    }
    }
}

if (-not $SkipBicepBuild) {
    $azCommand = Get-Command az -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -eq $azCommand) {
        Add-Failure 'Azure CLI with the Bicep command is unavailable.'
    }
    else {
        $phase3BicepPath = Join-Path $repositoryRoot 'infra\src\bicep\main.bicep'
        if (Test-Path -LiteralPath $phase3BicepPath -PathType Leaf) {
            try {
                [string[]]$bicepBuildOutput = @(& $azCommand.Source bicep build --file $phase3BicepPath --stdout 2>&1 |
                    ForEach-Object { $_.ToString() })
                $bicepBuildExitCode = $LASTEXITCODE
                if ($bicepBuildExitCode -ne 0 -or [string]::IsNullOrWhiteSpace(($bicepBuildOutput -join "`n"))) {
                    Add-Failure 'Local Phase 3 Bicep build failed.'
                }
            }
            catch {
                Add-Failure "Cannot run the local Phase 3 Bicep build: $($_.Exception.Message)"
            }
        }
    }
}

if ($failures.Count -gt 0) {
    foreach ($failure in $failures) { Write-Output "ERROR: $failure" }
    Write-Output "Repository setup validation failed with $($failures.Count) error(s)."
    exit 1
}
Write-Output 'Repository setup validation passed.'
