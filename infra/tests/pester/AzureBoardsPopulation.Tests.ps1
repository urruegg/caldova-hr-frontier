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
            [System.IO.File]::WriteAllText((Join-Path $root 'uc-0001-broken.md'), "# UC-0001 - Broken`n`n> **Status:** Idea`n", [System.Text.UTF8Encoding]::new($false))

            { & $script:ScriptPath -TenantAlias 'caldova25156897' -IdeasRoot $root -ReturnPortfolioOnly } | Should -Throw '*Journey stage*'
        }

        It 'throws a clear error when an idea file has no summary paragraph after the Idea heading' {
            $root = Join-Path $TestDrive ([guid]::NewGuid().ToString())
            New-Item -ItemType Directory -Path $root -Force | Out-Null
            [System.IO.File]::WriteAllText((Join-Path $root 'uc-0001-broken.md'), "# UC-0001 - Broken`n`n> **Status:** Idea`n> **Journey stage:** Hire`n`n## 1. The Idea`n", [System.Text.UTF8Encoding]::new($false))

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

    Context 'New-DefaultAzureDevOpsRequest (real az-invoking path, no -AzureDevOpsRequest override)' {
        It 'resolves Invoke-NativeJsonCommand and returns parsed JSON when only -NativeCommandRunner is faked' {
            # Regression test: every other test in this file supplies -AzureDevOpsRequest, which
            # bypasses New-DefaultAzureDevOpsRequest entirely. That function's returned scriptblock
            # is created with .GetNewClosure(), which runs in an isolated dynamic module when this
            # script is invoked as "./Initialize-AzureDevOpsWorkItems.ps1 ..." (exactly how the
            # runbook, CI, and this test invoke it via $script:ScriptPath) - a bare call to the
            # "Invoke-NativeJsonCommand" function by name previously failed there with
            # CommandNotFoundException. This test exercises that real path by faking only the
            # native process boundary (-NativeCommandRunner), not the request dispatcher.
            $result = & $script:ScriptPath -TenantAlias 'caldova25156897' -ReturnProcessCapabilitiesOnly `
                -NativeCommandRunner {
                    param($FilePath, $ArgumentList)
                    [pscustomobject]@{
                        ExitCode = 0
                        StdOut = '{"count":1,"value":[{"name":"Epic"}]}'
                        StdErr = ''
                    }
                }

            $result.EpicWorkItemTypeName | Should -Be 'Epic'
        }

        It 'creates and reads back a work item over raw HTTP calls with a UTF-8 charset instead of az' {
            # Regression test: az CLI - "az devops invoke" (including with an explicit --encoding
            # utf-8), the native "az boards work-item create" command, and "az boards work-item
            # show" - all handle non-ASCII characters incorrectly, both encoding requests and
            # decoding responses. Confirmed live against Tenant 1: an em dash (U+2014) in a work
            # item Description became U+FFFD REPLACEMENT CHARACTER through every az CLI code path
            # tried, including reading back data that a raw REST call proved was stored correctly.
            # A raw HTTP call that declares "charset=utf-8" on the Content-Type header round-trips
            # the same text correctly - also confirmed live. CreateWorkItem and ShowWorkItem now
            # get a bearer token via "az account get-access-token" (ASCII-only, no risk) and send
            # /receive the work item body itself via -HttpCommandRunner, bypassing az's broken
            # transport entirely. This test uses a real non-ASCII character (an em dash, matching
            # UC-0001's actual summary) to prove the bytes sent and read back are correct UTF-8,
            # not just that a call was made.
            # Uses a bespoke single-idea fixture (rather than New-FixtureIdeasRoot's shared fixtures)
            # so the summary can contain a real em dash (—, U+2014) - matching UC-0001's actual
            # production summary - without touching the shared fixture text other tests assert on.
            $ideasRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString())
            New-Item -ItemType Directory -Path $ideasRoot -Force | Out-Null
            New-IdeaFixtureFile -Root $ideasRoot -RelativePath 'uc-0001-encoding-fixture.md' -UseCaseId 'UC-0001' -Title 'Encoding Fixture' -StatusLine '**Selected as MVP**' -JourneyStage 'Pre-board' -Summary 'Adds missing approved values only — never overwriting anything that already has a value.'
            $capturedTokenArgumentLists = [System.Collections.Generic.List[object]]::new()
            $capturedHttpCalls = [System.Collections.Generic.List[object]]::new()
            $createdById = @{}
            $relationUrlById = @{}
            $nextId = 9001

            & $script:ScriptPath -TenantAlias 'caldova25156897' -IdeasRoot $ideasRoot -RepositoryRootOverride $ideasRoot -Confirm:$false `
                -NativeCommandRunner {
                    param($FilePath, $ArgumentList)
                    if ($ArgumentList -contains 'workitemtypes') {
                        return [pscustomobject]@{ ExitCode = 0; StdOut = '{"count":1,"value":[{"name":"Epic"}]}'; StdErr = '' }
                    }
                    if ($ArgumentList -contains 'wiql') {
                        return [pscustomobject]@{ ExitCode = 0; StdOut = '{"workItems":[]}'; StdErr = '' }
                    }
                    if ($ArgumentList -contains 'get-access-token') {
                        $capturedTokenArgumentLists.Add($ArgumentList)
                        return [pscustomobject]@{ ExitCode = 0; StdOut = 'fake-bearer-token'; StdErr = '' }
                    }
                    if ($FilePath -eq 'az' -and $ArgumentList -contains 'add') {
                        $idIndex = [array]::IndexOf($ArgumentList, '--id')
                        $urlIndex = [array]::IndexOf($ArgumentList, '--target-url')
                        $relationUrlById[[int]$ArgumentList[$idIndex + 1]] = $ArgumentList[$urlIndex + 1]
                        return [pscustomobject]@{ ExitCode = 0; StdOut = ''; StdErr = '' }
                    }
                    throw "Unexpected native command: $FilePath $($ArgumentList -join ' ')"
                }.GetNewClosure() `
                -HttpCommandRunner {
                    param($Method, $Uri, $AccessToken, $BodyBytes, $ContentType)
                    if ($Method -eq 'POST') {
                        $capturedHttpCalls.Add([pscustomobject]@{ Method = $Method; Uri = $Uri; AccessToken = $AccessToken; BodyBytes = $BodyBytes; ContentType = $ContentType })
                        $bodyText = [System.Text.Encoding]::UTF8.GetString($BodyBytes)
                        $patchOps = $bodyText | ConvertFrom-Json
                        $id = $nextId
                        $nextId++
                        $fieldsByPath = @{}
                        foreach ($patchOp in $patchOps) { $fieldsByPath[$patchOp.path] = $patchOp.value }
                        $createdById[$id] = $fieldsByPath
                        return [pscustomobject]@{
                            id = $id
                            fields = [pscustomobject]@{
                                'System.Title' = $fieldsByPath['/fields/System.Title']
                                'System.Description' = $fieldsByPath['/fields/System.Description']
                                'System.Tags' = $fieldsByPath['/fields/System.Tags']
                            }
                        }
                    }
                    # GET: ShowWorkItem read-back, also bypasses az (its response decoding has the
                    # same non-ASCII corruption as its request encoding - confirmed live).
                    $idMatch = [regex]::Match($Uri, 'workitems/(\d+)\?')
                    $id = [int]$idMatch.Groups[1].Value
                    $fieldsByPath = $createdById[$id]
                    [pscustomobject]@{
                        id = $id
                        fields = [pscustomobject]@{
                            'System.Title' = $fieldsByPath['/fields/System.Title']
                            'System.Description' = $fieldsByPath['/fields/System.Description']
                            'System.Tags' = $fieldsByPath['/fields/System.Tags']
                        }
                        relations = @([pscustomobject]@{ rel = 'Hyperlink'; url = $relationUrlById[$id] })
                    }
                }.GetNewClosure()

            $capturedTokenArgumentLists.Count | Should -BeGreaterThan 0
            $capturedTokenArgumentLists[0] | Should -Contain '499b84ac-1321-427f-aa17-267ca6975798'

            $capturedHttpCalls.Count | Should -BeGreaterThan 0
            foreach ($httpCall in $capturedHttpCalls) {
                $httpCall.Method | Should -Be 'POST'
                $httpCall.Uri | Should -Match '_apis/wit/workitems/\$Epic\?api-version=7\.1$'
                $httpCall.ContentType | Should -Be 'application/json-patch+json; charset=utf-8'
                $httpCall.AccessToken | Should -Be 'fake-bearer-token'
            }

            # Confirm the exact UTF-8 byte sequence for the em dash (E2 80 94) appears verbatim in
            # what was actually sent over HTTP - proof this is genuine byte-correct UTF-8, not
            # merely a call that happened to succeed.
            $emDashUtf8Bytes = [System.Text.Encoding]::UTF8.GetBytes([string][char]0x2014)
            $bodyBytesText = ($capturedHttpCalls[0].BodyBytes | ForEach-Object { $_.ToString('X2') }) -join ''
            $emDashHex = ($emDashUtf8Bytes | ForEach-Object { $_.ToString('X2') }) -join ''
            $bodyBytesText | Should -Match $emDashHex
        }

        It 'parses a real Azure DevOps workitemtypes response containing an empty-string transitions key' {
            # Regression test: the live Azure DevOps workitemtypes API returns each work item type's
            # "transitions" map keyed by an empty string for the initial (no prior state) transition.
            # Default ConvertFrom-Json cannot represent an empty-string property name on a
            # PSCustomObject and throws "The provided JSON includes a property whose name is an empty
            # string, this is only supported using the -AsHashTable switch." This was discovered
            # live-testing a -WhatIf preview against Tenant 1's real Azure DevOps project.
            $realShapedJson = @'
{
  "count": 1,
  "value": [
    {
      "name": "Epic",
      "referenceName": "Microsoft.VSTS.WorkItemTypes.Epic",
      "states": [
        { "category": "Proposed", "color": "b2b2b2", "name": "To Do" }
      ],
      "transitions": {
        "": [ { "actions": null, "to": "To Do" } ],
        "To Do": [ { "actions": null, "to": "To Do" } ]
      }
    }
  ]
}
'@

            $result = & $script:ScriptPath -TenantAlias 'caldova25156897' -ReturnProcessCapabilitiesOnly `
                -NativeCommandRunner {
                    param($FilePath, $ArgumentList)
                    [pscustomobject]@{
                        ExitCode = 0
                        StdOut = $realShapedJson
                        StdErr = ''
                    }
                }

            $result.EpicWorkItemTypeName | Should -Be 'Epic'
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
