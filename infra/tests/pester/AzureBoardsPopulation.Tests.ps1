Set-StrictMode -Version Latest

Describe 'Azure Boards population' {
    BeforeAll {
        $script:RepositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
        $script:ScriptPath = Join-Path $script:RepositoryRoot 'infra\src\scripts\Initialize-AzureDevOpsWorkItems.ps1'

        function script:New-IdeaFixtureFile {
            param(
                [Parameter(Mandatory)] [string]$Root,
                [Parameter(Mandatory)] [string]$RelativePath,
                [Parameter(Mandatory)] [string]$UseCaseId,
                [Parameter(Mandatory)] [string]$Title,
                [Parameter(Mandatory)] [string]$StatusLine,
                [Parameter(Mandatory)] [string]$JourneyStage,
                [Parameter(Mandatory)] [string]$Summary
            )

            $fullPath = Join-Path $Root $RelativePath
            $directory = Split-Path -Parent $fullPath
            if (-not (Test-Path -LiteralPath $directory)) {
                New-Item -ItemType Directory -Path $directory -Force | Out-Null
            }

            $content = @"
# $UseCaseId — $Title

| Field | Value |
|---|---|
| **Version** | 1.0 |

> **Status:** $StatusLine
> **Journey stage:** $JourneyStage
> **HR process area:** Test
> **HR owner:** Test Owner

---

## 1. The Idea

$Summary

| | |
|---|---|
| **Business objective** | Test |
"@
            [System.IO.File]::WriteAllText($fullPath, $content, [System.Text.UTF8Encoding]::new($false))
        }

        function script:New-FixtureIdeasRoot {
            $root = Join-Path $TestDrive ([guid]::NewGuid().ToString())
            New-Item -ItemType Directory -Path $root -Force | Out-Null

            $fixtures = @(
                @{ Id = 'UC-0001'; Path = 'uc-0001-fixture-folder\uc-0001-fixture-folder.md'; Title = 'Fixture MVP Selected'; StatusLine = '**Selected as MVP** — the only use case in this portfolio that has advanced past idea'; Stage = 'Pre-board'; Summary = 'Summary for UC-0001.' }
                @{ Id = 'UC-0002'; Path = 'uc-0002-fixture-adjacent.md'; Title = 'Fixture Adjacent'; StatusLine = '**Runs alongside the MVP** — recommended, not counted'; Stage = 'Cross-cutting — HR Service Delivery'; Summary = 'Summary for UC-0002.' }
                @{ Id = 'UC-0005'; Path = 'uc-0005-fixture-mvp-candidate.md'; Title = 'Fixture MVP Candidate'; StatusLine = '**IN MVP SCOPE** — selected, not yet specified'; Stage = 'Onboard'; Summary = 'Summary for UC-0005.' }
                @{ Id = 'UC-0006'; Path = 'uc-0006-fixture-candidate.md'; Title = 'Fixture Candidate'; StatusLine = 'Idea — draft for review'; Stage = 'Hire'; Summary = 'Summary for UC-0006.' }
            )

            foreach ($fixture in $fixtures) {
                New-IdeaFixtureFile -Root $root -RelativePath $fixture.Path -UseCaseId $fixture.Id -Title $fixture.Title -StatusLine $fixture.StatusLine -JourneyStage $fixture.Stage -Summary $fixture.Summary
            }

            $root
        }
    }

    Context 'Get-HrIdeaPortfolioItems' {
        It 'parses UseCaseId, Title, Status, JourneyStage, SourcePath, and Summary from each fixture idea file' {
            $ideasRoot = New-FixtureIdeasRoot

            $items = & $script:ScriptPath -TenantAlias 'caldova25156897' -IdeasRoot $ideasRoot -ReturnPortfolioOnly

            $items.Count | Should -Be 4

            $uc0001 = $items | Where-Object UseCaseId -eq 'UC-0001'
            $uc0001.Title | Should -Be 'Fixture MVP Selected'
            $uc0001.Status | Should -Be 'MVP'
            $uc0001.JourneyStage | Should -Be 'Pre-board'
            $uc0001.SourcePath | Should -Be 'uc-0001-fixture-folder/uc-0001-fixture-folder.md'
            $uc0001.Summary | Should -Be 'Summary for UC-0001.'

            $uc0002 = $items | Where-Object UseCaseId -eq 'UC-0002'
            $uc0002.Status | Should -Be 'MVP-Adjacent'
            $uc0002.JourneyStage | Should -Be 'Cross-cutting - HR Service Delivery'

            $uc0005 = $items | Where-Object UseCaseId -eq 'UC-0005'
            $uc0005.Status | Should -Be 'MVP-Candidate'

            $uc0006 = $items | Where-Object UseCaseId -eq 'UC-0006'
            $uc0006.Status | Should -Be 'Candidate'
        }

        It 'throws a clear error when an idea file has no H1 line' {
            $root = Join-Path $TestDrive ([guid]::NewGuid().ToString())
            New-Item -ItemType Directory -Path $root -Force | Out-Null
            [System.IO.File]::WriteAllText((Join-Path $root 'uc-0001-broken.md'), "No heading here`n> **Status:** Idea`n", [System.Text.UTF8Encoding]::new($false))

            { & $script:ScriptPath -TenantAlias 'caldova25156897' -IdeasRoot $root -ReturnPortfolioOnly } | Should -Throw '*H1*'
        }

        It 'throws a clear error when an idea file has no Status blockquote line' {
            $root = Join-Path $TestDrive ([guid]::NewGuid().ToString())
            New-Item -ItemType Directory -Path $root -Force | Out-Null
            [System.IO.File]::WriteAllText((Join-Path $root 'uc-0001-broken.md'), "# UC-0001 — Broken`n`nNo status blockquote.`n", [System.Text.UTF8Encoding]::new($false))

            { & $script:ScriptPath -TenantAlias 'caldova25156897' -IdeasRoot $root -ReturnPortfolioOnly } | Should -Throw '*Status*'
        }
    }
}
