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
# $UseCaseId - $Title

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
                @{ Id = 'UC-0001'; Path = 'uc-0001-fixture-folder\uc-0001-fixture-folder.md'; Title = 'Fixture MVP Selected'; StatusLine = '**Selected as MVP** - the only use case in this portfolio that has advanced past idea'; Stage = 'Pre-board'; Summary = 'Summary for UC-0001.' }
                @{ Id = 'UC-0002'; Path = 'uc-0002-fixture-adjacent.md'; Title = 'Fixture Adjacent'; StatusLine = '**Runs alongside the MVP** - recommended, not counted'; Stage = 'Cross-cutting - HR Service Delivery'; Summary = 'Summary for UC-0002.' }
                @{ Id = 'UC-0005'; Path = 'uc-0005-fixture-mvp-candidate.md'; Title = 'Fixture MVP Candidate'; StatusLine = '**IN MVP SCOPE** - selected, not yet specified'; Stage = 'Onboard'; Summary = 'Summary for UC-0005.' }
                @{ Id = 'UC-0006'; Path = 'uc-0006-fixture-candidate.md'; Title = 'Fixture Candidate'; StatusLine = 'Idea - draft for review'; Stage = 'Hire'; Summary = 'Summary for UC-0006.' }
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

            $items = & $script:ScriptPath -TenantAlias 'caldova25156897' -IdeasRoot $ideasRoot -RepositoryRootOverride $ideasRoot -ReturnPortfolioOnly

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

            { & $script:ScriptPath -TenantAlias 'caldova25156897' -IdeasRoot $root -RepositoryRootOverride $root -ReturnPortfolioOnly } | Should -Throw '*H1*'
        }

        It 'throws a clear error when an idea file has no Status blockquote line' {
            $root = Join-Path $TestDrive ([guid]::NewGuid().ToString())
            New-Item -ItemType Directory -Path $root -Force | Out-Null
            [System.IO.File]::WriteAllText((Join-Path $root 'uc-0001-broken.md'), "# UC-0001 - Broken`n`nNo status blockquote.`n", [System.Text.UTF8Encoding]::new($false))

            { & $script:ScriptPath -TenantAlias 'caldova25156897' -IdeasRoot $root -RepositoryRootOverride $root -ReturnPortfolioOnly } | Should -Throw '*Status*'
        }

        It 'throws a clear error when an idea file has no Journey stage blockquote line' {
            $root = Join-Path $TestDrive ([guid]::NewGuid().ToString())
            New-Item -ItemType Directory -Path $root -Force | Out-Null
            [System.IO.File]::WriteAllText((Join-Path $root 'uc-0001-broken.md'), "# UC-0001 — Broken`n`n> **Status:** Idea`n", [System.Text.UTF8Encoding]::new($false))

            { & $script:ScriptPath -TenantAlias 'caldova25156897' -IdeasRoot $root -ReturnPortfolioOnly } | Should -Throw '*Journey stage*'
        }

        It 'throws a clear error when an idea file has no summary paragraph after the Idea heading' {
            $root = Join-Path $TestDrive ([guid]::NewGuid().ToString())
            New-Item -ItemType Directory -Path $root -Force | Out-Null
            [System.IO.File]::WriteAllText((Join-Path $root 'uc-0001-broken.md'), "# UC-0001 — Broken`n`n> **Status:** Idea`n> **Journey stage:** Hire`n`n## 1. The Idea`n", [System.Text.UTF8Encoding]::new($false))

            { & $script:ScriptPath -TenantAlias 'caldova25156897' -IdeasRoot $root -ReturnPortfolioOnly } | Should -Throw '*summary*'
        }

        It 'retains a parent-directory prefix in SourcePath when RepositoryRootOverride is one level above IdeasRoot' {
            $ideasRoot = New-FixtureIdeasRoot
            $parentRoot = Split-Path -Parent $ideasRoot
            $ideasFolderName = Split-Path -Leaf $ideasRoot

            $items = & $script:ScriptPath -TenantAlias 'caldova25156897' -IdeasRoot $ideasRoot -RepositoryRootOverride $parentRoot -ReturnPortfolioOnly

            $uc0001 = $items | Where-Object UseCaseId -eq 'UC-0001'
            $uc0001.SourcePath | Should -Be "$ideasFolderName/uc-0001-fixture-folder/uc-0001-fixture-folder.md"
        }
    }

    Context 'Get-AzureDevOpsProcessCapabilities' {
        It 'returns EpicWorkItemTypeName when the project work item types include Epic' {
            $fixture = [pscustomobject]@{
                StatusCode = 200
                Headers = @{}
                Body = [pscustomobject]@{
                    count = 3
                    value = @(
                        [pscustomobject]@{ name = 'Epic'; referenceName = 'Microsoft.VSTS.WorkItemTypes.Epic' }
                        [pscustomobject]@{ name = 'Feature'; referenceName = 'Microsoft.VSTS.WorkItemTypes.Feature' }
                        [pscustomobject]@{ name = 'Bug'; referenceName = 'Microsoft.VSTS.WorkItemTypes.Bug' }
                    )
                }
            }

            $result = & $script:ScriptPath -TenantAlias 'caldova25156897' -ReturnProcessCapabilitiesOnly `
                -AzureDevOpsRequest {
                    param($Operation, $Arguments)
                    $fixture
                }

            $result.EpicWorkItemTypeName | Should -Be 'Epic'
        }

        It 'throws a named error listing the observed types when Epic is absent' {
            $fixture = [pscustomobject]@{
                StatusCode = 200
                Headers = @{}
                Body = [pscustomobject]@{
                    count = 2
                    value = @(
                        [pscustomobject]@{ name = 'Requirement'; referenceName = 'Microsoft.VSTS.WorkItemTypes.Requirement' }
                        [pscustomobject]@{ name = 'Bug'; referenceName = 'Microsoft.VSTS.WorkItemTypes.Bug' }
                    )
                }
            }

            {
                & $script:ScriptPath -TenantAlias 'caldova25156897' -ReturnProcessCapabilitiesOnly `
                    -AzureDevOpsRequest {
                        param($Operation, $Arguments)
                        $fixture
                    }
            } | Should -Throw "*no 'Epic' work item type*Requirement, Bug*"
        }
    }

    Context 'Get-AzureDevOpsWorkItemPlan' {
        It 'marks an idea Create when the WIQL query returns no matching work item' {
            $wiqlEmptyFixture = [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = [pscustomobject]@{ workItems = @() } }

            $ideasRoot = New-FixtureIdeasRoot
            $items = & $script:ScriptPath -TenantAlias 'caldova25156897' -IdeasRoot $ideasRoot -RepositoryRootOverride $ideasRoot -ReturnPortfolioOnly

            $plan = & $script:ScriptPath -TenantAlias 'caldova25156897' -IdeasRoot $ideasRoot -RepositoryRootOverride $ideasRoot -ReturnWorkItemPlanOnly `
                -AzureDevOpsRequest {
                    param($Operation, $Arguments)
                    switch ($Operation) {
                        'ListWorkItemTypes' { return [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = [pscustomobject]@{ count = 1; value = @([pscustomobject]@{ name = 'Epic' }) } } }
                        'QueryWorkItemsByTag' { $wiqlEmptyFixture }
                        default { throw "Unexpected operation '$Operation' in this test." }
                    }
                }

            $plan.Count | Should -Be $items.Count
            ($plan | Where-Object UseCaseId -eq 'UC-0001').Mode | Should -Be 'Create'
            ($plan | Where-Object UseCaseId -eq 'UC-0001').ExistingWorkItemId | Should -Be 0
            ($plan | Where-Object UseCaseId -eq 'UC-0001').HyperlinkUrl | Should -Be 'https://github.com/urruegg/caldova-hr-frontier/blob/main/uc-0001-fixture-folder/uc-0001-fixture-folder.md'
        }

        It 'marks an idea Existing when the WIQL query returns exactly one matching work item' {
            $ideasRoot = New-FixtureIdeasRoot

            $plan = & $script:ScriptPath -TenantAlias 'caldova25156897' -IdeasRoot $ideasRoot -RepositoryRootOverride $ideasRoot -ReturnWorkItemPlanOnly `
                -AzureDevOpsRequest {
                    param($Operation, $Arguments)
                    switch ($Operation) {
                        'ListWorkItemTypes' { return [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = [pscustomobject]@{ count = 1; value = @([pscustomobject]@{ name = 'Epic' }) } } }
                        'QueryWorkItemsByTag' {
                            if ([string]$Arguments['Tag'] -eq 'UC-0002') {
                                return [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = [pscustomobject]@{ workItems = @([pscustomobject]@{ id = 4242 }) } }
                            }
                            return [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = [pscustomobject]@{ workItems = @() } }
                        }
                        default { throw "Unexpected operation '$Operation' in this test." }
                    }
                }

            $uc0002Plan = $plan | Where-Object UseCaseId -eq 'UC-0002'
            $uc0002Plan.Mode | Should -Be 'Existing'
            $uc0002Plan.ExistingWorkItemId | Should -Be 4242
        }

        It 'throws a named ambiguous error when the WIQL query returns more than one matching work item' {
            $ideasRoot = New-FixtureIdeasRoot

            {
                & $script:ScriptPath -TenantAlias 'caldova25156897' -IdeasRoot $ideasRoot -RepositoryRootOverride $ideasRoot -ReturnWorkItemPlanOnly `
                    -AzureDevOpsRequest {
                        param($Operation, $Arguments)
                        switch ($Operation) {
                            'ListWorkItemTypes' { return [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = [pscustomobject]@{ count = 1; value = @([pscustomobject]@{ name = 'Epic' }) } } }
                            default { return [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = [pscustomobject]@{ workItems = @([pscustomobject]@{ id = 1 }, [pscustomobject]@{ id = 2 }) } } }
                        }
                    }
            } | Should -Throw '*Ambiguous existing work items tagged*'
        }
    }

    Context 'Initialize-AzureDevOpsWorkItems main body' {
        It 'performs zero mutation under -WhatIf and writes the plan to -PlanOutputPath' {
            $ideasRoot = New-FixtureIdeasRoot
            $planPath = Join-Path $TestDrive 'plan.json'
            $script:MutationCallCount = 0

            & $script:ScriptPath -TenantAlias 'caldova25156897' -IdeasRoot $ideasRoot -RepositoryRootOverride $ideasRoot -PlanOutputPath $planPath -WhatIf `
                -AzureDevOpsRequest {
                    param($Operation, $Arguments)
                    switch ($Operation) {
                        'ListWorkItemTypes' { return [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = [pscustomobject]@{ count = 1; value = @([pscustomobject]@{ name = 'Epic' }) } } }
                        'QueryWorkItemsByTag' { [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = [pscustomobject]@{ workItems = @() } } }
                        default { $script:MutationCallCount++; throw "Unexpected mutating operation '$Operation' under -WhatIf." }
                    }
                }

            $script:MutationCallCount | Should -Be 0
            Test-Path -LiteralPath $planPath | Should -BeTrue
            $writtenPlan = Get-Content -Raw -LiteralPath $planPath | ConvertFrom-Json
            @($writtenPlan).Count | Should -Be 4
        }

        It 'creates a work item, adds the Hyperlink relation, and verifies the read-back when not -WhatIf' {
            $ideasRoot = New-FixtureIdeasRoot
            $captured = @{ CreatedFieldsById = @{}; RelationAddedById = @{}; NextId = 9001 }

            & $script:ScriptPath -TenantAlias 'caldova25156897' -IdeasRoot $ideasRoot -RepositoryRootOverride $ideasRoot -Confirm:$false `
                -AzureDevOpsRequest {
                    param($Operation, $Arguments)
                    switch ($Operation) {
                        'ListWorkItemTypes' { return [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = [pscustomobject]@{ count = 1; value = @([pscustomobject]@{ name = 'Epic' }) } } }
                        'QueryWorkItemsByTag' { [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = [pscustomobject]@{ workItems = @() } } }
                        'CreateWorkItem' {
                            $newId = $captured.NextId
                            $captured.NextId++
                            $captured.CreatedFieldsById[$newId] = $Arguments
                            [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = [pscustomobject]@{ id = $newId } }
                        }
                        'AddHyperlinkRelation' {
                            $captured.RelationAddedById[[int]$Arguments['WorkItemId']] = $Arguments
                            [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = $null }
                        }
                        'ShowWorkItem' {
                            $id = [int]$Arguments['WorkItemId']
                            $fields = $captured.CreatedFieldsById[$id]
                            $relation = $captured.RelationAddedById[$id]
                            [pscustomobject]@{
                                StatusCode = 200
                                Headers = @{}
                                Body = [pscustomobject]@{
                                    id = $id
                                    fields = [pscustomobject]@{
                                        'System.Title' = [string]$fields['Title']
                                        'System.Description' = [string]$fields['Description']
                                        'System.Tags' = [string]$fields['Tags']
                                    }
                                    relations = @([pscustomobject]@{ rel = 'Hyperlink'; url = [string]$relation['Url'] })
                                }
                            }
                        }
                        default { throw "Unexpected operation '$Operation' in this test." }
                    }
                }

            $uc0001Fields = $captured.CreatedFieldsById[9001]
            $uc0001Fields['Title'] | Should -Be 'Fixture MVP Selected'
            $uc0001Fields['Tags'] | Should -Be 'UC-0001; MVP; Pre-board'
            $captured.RelationAddedById[9001]['Url'] | Should -Be 'https://github.com/urruegg/caldova-hr-frontier/blob/main/uc-0001-fixture-folder/uc-0001-fixture-folder.md'
            $uc0001Fields['WorkItemType'] | Should -Be 'Epic'
        }

        It 'throws when the read-back does not match the plan' {
            $ideasRoot = New-FixtureIdeasRoot

            {
                & $script:ScriptPath -TenantAlias 'caldova25156897' -IdeasRoot $ideasRoot -RepositoryRootOverride $ideasRoot -Confirm:$false `
                    -AzureDevOpsRequest {
                        param($Operation, $Arguments)
                        switch ($Operation) {
                            'ListWorkItemTypes' { return [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = [pscustomobject]@{ count = 1; value = @([pscustomobject]@{ name = 'Epic' }) } } }
                            'QueryWorkItemsByTag' { [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = [pscustomobject]@{ workItems = @() } } }
                            'CreateWorkItem' { [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = [pscustomobject]@{ id = 9001 } } }
                            'AddHyperlinkRelation' { [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = $null } }
                            'ShowWorkItem' {
                                [pscustomobject]@{
                                    StatusCode = 200
                                    Headers = @{}
                                    Body = [pscustomobject]@{
                                        id = 9001
                                        fields = [pscustomobject]@{ 'System.Title' = 'WRONG TITLE'; 'System.Description' = 'x'; 'System.Tags' = 'x' }
                                        relations = @()
                                    }
                                }
                            }
                            default { throw "Unexpected operation '$Operation' in this test." }
                        }
                    }
            } | Should -Throw '*read-back*'
        }
    }
}

