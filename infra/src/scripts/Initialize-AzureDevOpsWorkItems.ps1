[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-z0-9]+$')]
    [string]$TenantAlias,

    [string]$IdeasRoot,

    [string]$PlanOutputPath,

    [switch]$ReturnPortfolioOnly,

    [Parameter(DontShow)]
    [scriptblock]$AzRequest,

    [Parameter(DontShow)]
    [scriptblock]$AzureDevOpsRequest,

    [Parameter(DontShow)]
    [scriptblock]$NativeCommandRunner
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-RepositoryRoot {
    [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
}

function Get-DefaultIdeasRoot {
    Join-Path (Get-RepositoryRoot) 'hr\docs\ideas'
}

function ConvertTo-RepoRelativeForwardSlashPath {
    param(
        [Parameter(Mandatory)]
        [string]$FullPath,

        [Parameter(Mandatory)]
        [string]$RepositoryRoot
    )

    $normalizedRoot = [System.IO.Path]::GetFullPath($RepositoryRoot).TrimEnd('\', '/')
    $normalizedFull = [System.IO.Path]::GetFullPath($FullPath)
    if (-not $normalizedFull.StartsWith($normalizedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Path '$FullPath' is not under repository root '$RepositoryRoot'."
    }

    $relative = $normalizedFull.Substring($normalizedRoot.Length).TrimStart('\', '/')
    $relative -replace '\\', '/'
}

function Get-HrIdeaPortfolioItems {
    param(
        [Parameter(Mandatory)]
        [string]$IdeasRoot
    )

    $repositoryRoot = if (-not [string]::IsNullOrWhiteSpace($IdeasRoot) -and (Test-Path -LiteralPath $IdeasRoot)) { [System.IO.Path]::GetFullPath($IdeasRoot) } else { Get-RepositoryRoot }
    $files = @(Get-ChildItem -LiteralPath $IdeasRoot -Filter '*.md' -Recurse -File |
        Where-Object { $_.Name -cmatch '^uc-\d{4}-' } |
        Sort-Object FullName)

    if ($files.Count -eq 0) {
        throw "No idea files matching 'uc-NNNN-*.md' were found under '$IdeasRoot'."
    }

    $items = [System.Collections.Generic.List[object]]::new()
    foreach ($file in $files) {
        $content = [System.IO.File]::ReadAllText($file.FullName)
        $lines = $content -split "`r?`n"

        $headingLine = $lines | Where-Object { $_ -cmatch '^#\s+(UC-\d{4})\s*[—-]\s*(.+)$' } | Select-Object -First 1
        if (-not $headingLine) {
            throw "Idea file '$($file.FullName)' has no H1 line matching '# UC-NNNN — Title'."
        }
        $null = $headingLine -cmatch '^#\s+(UC-\d{4})\s*[—-]\s*(.+)$'
        $useCaseId = $Matches[1]
        $title = $Matches[2].Trim()

        $statusLine = $lines | Where-Object { $_ -cmatch '^>\s*\*\*Status:\*\*\s*(.+)$' } | Select-Object -First 1
        if (-not $statusLine) {
            throw "Idea file '$($file.FullName)' ($useCaseId) has no '> **Status:** ...' blockquote line."
        }
        $null = $statusLine -cmatch '^>\s*\*\*Status:\*\*\s*(.+)$'
        $statusText = $Matches[1].Trim()

        $status =
            if ($statusText -match 'Selected as MVP') { 'MVP' }
            elseif ($statusText -match 'IN MVP SCOPE') { 'MVP-Candidate' }
            elseif ($statusText -match 'Runs alongside the MVP') { 'MVP-Adjacent' }
            else { 'Candidate' }

        $stageLine = $lines | Where-Object { $_ -cmatch '^>\s*\*\*Journey stage:\*\*\s*(.+)$' } | Select-Object -First 1
        if (-not $stageLine) {
            throw "Idea file '$($file.FullName)' ($useCaseId) has no '> **Journey stage:** ...' blockquote line."
        }
        $null = $stageLine -cmatch '^>\s*\*\*Journey stage:\*\*\s*(.+)$'
        $journeyStage = ($Matches[1].Trim()) -replace '\s+—\s+', ' - '

        $ideaHeadingIndex = 0..($lines.Count - 1) | Where-Object { $lines[$_] -cmatch '^##\s+1\.\s+The Idea\s*$' } | Select-Object -First 1
        if ($null -eq $ideaHeadingIndex) {
            throw "Idea file '$($file.FullName)' ($useCaseId) has no '## 1. The Idea' heading."
        }
        $summary = $null
        for ($i = [int]$ideaHeadingIndex + 1; $i -lt $lines.Count; $i++) {
            if (-not [string]::IsNullOrWhiteSpace($lines[$i])) {
                $summary = $lines[$i].Trim()
                break
            }
        }
        if ($null -eq $summary) {
            throw "Idea file '$($file.FullName)' ($useCaseId) has no summary paragraph after '## 1. The Idea'."
        }

        $items.Add([pscustomobject]@{
            UseCaseId = $useCaseId
            Title = $title
            Status = $status
            JourneyStage = $journeyStage
            SourcePath = ConvertTo-RepoRelativeForwardSlashPath -FullPath $file.FullName -RepositoryRoot $repositoryRoot
            Summary = $summary
        }) | Out-Null
    }

    @($items | Sort-Object UseCaseId)
}

$resolvedIdeasRoot = if ([string]::IsNullOrWhiteSpace($IdeasRoot)) { Get-DefaultIdeasRoot } else { $IdeasRoot }
$portfolio = Get-HrIdeaPortfolioItems -IdeasRoot $resolvedIdeasRoot

if ($ReturnPortfolioOnly) {
    Write-Output -NoEnumerate $portfolio
    return
}

throw 'Initialize-AzureDevOpsWorkItems.ps1: only -ReturnPortfolioOnly is implemented so far (Task 1 of the implementation plan). Later tasks add process discovery, plan computation, and mutation.'
