Set-StrictMode -Version Latest

Describe 'Tenant 1 lean Azure Boards sprint operation' {
    BeforeAll {
        $script:RepositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
        $script:ScriptPath = Join-Path $script:RepositoryRoot 'infra\src\scripts\Initialize-AzureBoardsLeanSprint.ps1'
        $script:ProjectName = 'Caldova HR Frontier'
        $script:TeamName = 'Caldova HR Frontier Team'
        $script:IterationPath = 'Caldova HR Frontier\Current'
        $script:IssueTitle = 'Tenant 1 lean engineering platform acceptance'
        $script:TraceabilityTag = 'tenant1-lean-platform-traceability'

        function script:Invoke-LeanBoardsScript {
            param(
                [string]$Mode = 'Create',
                [switch]$Apply,
                [switch]$WhatIf,
                [AllowNull()][Nullable[datetime]]$SprintStartDate,
                [AllowNull()][Nullable[datetime]]$SprintFinishDate
            )

            $script:State.AdapterMode = $Mode
            $parameters = @{
                OrganizationUrl = 'https://dev.azure.com/example/'
                ProjectName = $script:ProjectName
                TeamName = $script:TeamName
                CurrentSprintPath = $script:IterationPath
                IssueTitle = $script:IssueTitle
                PlanOutputPath = Join-Path $TestDrive "$Mode-boards-plan.json"
                AzureDevOpsRequest = $script:ExactBasicState
            }
            if ($Apply) {
                $parameters.Apply = $true
                $parameters.Confirm = $false
            }
            if ($WhatIf) {
                $parameters.WhatIf = $true
            }
            if ($null -ne $SprintStartDate) {
                $parameters.SprintStartDate = [datetime]$SprintStartDate
            }
            if ($null -ne $SprintFinishDate) {
                $parameters.SprintFinishDate = [datetime]$SprintFinishDate
            }

            & $script:ScriptPath @parameters
        }
    }

    BeforeEach {
        $state = [pscustomobject]@{
            AdapterMode = 'Create'
            MutationCalls = [System.Collections.Generic.List[object]]::new()
            OperationCalls = [System.Collections.Generic.List[string]]::new()
            QueryCalls = 0
            IterationStartDate = '2026-09-28T00:00:00Z'
            IterationFinishDate = '2026-10-09T00:00:00Z'
            CreatedIssueFields = $null
        }
        $script:State = $state
        $script:MutationCalls = $state.MutationCalls
        $script:OperationCalls = $state.OperationCalls
        $projectName = $script:ProjectName
        $teamName = $script:TeamName
        $iterationPath = $script:IterationPath
        $issueTitle = $script:IssueTitle
        $traceabilityTag = $script:TraceabilityTag

        $script:ExactBasicState = {
            param($Operation, $Arguments)

            $state.OperationCalls.Add([string]$Operation) | Out-Null
            switch ($Operation) {
                'GetProjectWithCapabilities' {
                    $processName = if ($state.AdapterMode -ceq 'Agile') { 'Agile' } else { 'Basic' }
                    return [pscustomobject]@{
                        id = '00000000-0000-0000-0000-000000000001'
                        name = $projectName
                        capabilities = [pscustomobject]@{
                            processTemplate = [pscustomobject]@{ templateName = $processName }
                        }
                    }
                }
                'GetTeam' {
                    if ($state.AdapterMode -ceq 'MissingTeam') {
                        return $null
                    }

                    return [pscustomobject]@{
                        id = '00000000-0000-0000-0000-000000000002'
                        name = $teamName
                        projectName = $projectName
                    }
                }
                'GetProjectRootArea' {
                    $path = if ($state.AdapterMode -ceq 'NonRootArea') {
                        "$projectName\Platform"
                    }
                    else {
                        $projectName
                    }
                    return [pscustomobject]@{
                        id = 1
                        name = $projectName
                        path = $path
                        structureType = 'area'
                    }
                }
                'GetIteration' {
                    if ($state.AdapterMode -ceq 'NotFound') {
                        return $null
                    }

                    return [pscustomobject]@{
                        id = 2
                        name = 'Current'
                        path = $iterationPath
                        structureType = 'iteration'
                        attributes = [pscustomobject]@{
                            startDate = $state.IterationStartDate
                            finishDate = $state.IterationFinishDate
                        }
                    }
                }
                'UpdateIterationDates' {
                    $state.MutationCalls.Add([pscustomobject]@{
                        Operation = $Operation
                        Arguments = $Arguments
                    }) | Out-Null
                    if ($state.AdapterMode -cne 'DateMismatch') {
                        $state.IterationStartDate = ([datetime]$Arguments.StartDate).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
                        $state.IterationFinishDate = ([datetime]$Arguments.FinishDate).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
                    }
                    return [pscustomobject]@{ path = $iterationPath }
                }
                'QueryTraceabilityIssue' {
                    $state.QueryCalls++
                    switch ($state.AdapterMode) {
                        'QueryMissingWorkItems' {
                            return [pscustomobject]@{ count = 0 }
                        }
                        'QueryNullWorkItems' {
                            return [pscustomobject]@{ workItems = $null }
                        }
                        'QueryWrongTypeWorkItems' {
                            return [pscustomobject]@{ workItems = [pscustomobject]@{ id = 42 } }
                        }
                        'DuplicateIssue' {
                            return [pscustomobject]@{ workItems = @(
                                [pscustomobject]@{ id = 41 }
                                [pscustomobject]@{ id = 42 }
                            ) }
                        }
                        'ConcurrentDuplicate' {
                            [object[]]$workItems = @()
                            if ($null -ne $state.CreatedIssueFields) {
                                $workItems = [object[]]@(
                                    [pscustomobject]@{ id = 73 }
                                    [pscustomobject]@{ id = 74 }
                                )
                            }
                            return [pscustomobject]@{ workItems = $workItems }
                        }
                        { $_ -in @('Reuse', 'DateMismatch') } {
                            return [pscustomobject]@{ workItems = [object[]]@([pscustomobject]@{ id = 42 }) }
                        }
                        default {
                            [object[]]$workItems = @()
                            if ($null -ne $state.CreatedIssueFields) {
                                $workItems = [object[]]@([pscustomobject]@{ id = 73 })
                            }
                            return [pscustomobject]@{ workItems = $workItems }
                        }
                    }
                }
                'CreateTraceabilityIssue' {
                    $state.CreatedIssueFields = $Arguments.Fields
                    $state.MutationCalls.Add([pscustomobject]@{
                        Operation = $Operation
                        Arguments = $Arguments
                    }) | Out-Null
                    return [pscustomobject]@{
                        id = 73
                        fields = $Arguments.Fields
                    }
                }
                'GetWorkItem' {
                    $id = [int]$Arguments.WorkItemId
                    $title = if ($state.AdapterMode -ceq 'CreateMismatch') {
                        'Unexpected title'
                    }
                    else {
                        $issueTitle
                    }
                    return [pscustomobject]@{
                        id = $id
                        fields = @{
                            'System.WorkItemType' = 'Issue'
                            'System.Title' = $title
                            'System.AreaPath' = $projectName
                            'System.IterationPath' = $iterationPath
                            'System.Tags' = $traceabilityTag
                        }
                    }
                }
                default {
                    throw "Unexpected test adapter operation '$Operation'."
                }
            }
        }.GetNewClosure()
    }

    It 'accepts only Basic existing team root area and one Issue' {
        $planPath = Join-Path $TestDrive 'boards-plan.json'

        $result = & $script:ScriptPath `
            -OrganizationUrl 'https://dev.azure.com/example/' `
            -ProjectName $script:ProjectName `
            -TeamName $script:TeamName `
            -CurrentSprintPath $script:IterationPath `
            -IssueTitle $script:IssueTitle `
            -PlanOutputPath $planPath `
            -AzureDevOpsRequest $script:ExactBasicState `
            -WhatIf

        $result.ProcessName | Should -BeExactly 'Basic'
        $result.TeamName | Should -BeExactly $script:TeamName
        $result.AreaPath | Should -BeExactly $script:ProjectName
        $result.CurrentSprintPath | Should -BeExactly $script:IterationPath
        $result.IssueMode | Should -BeExactly 'Create'
        $result.Status | Should -BeExactly 'Planned'
        @($script:MutationCalls).Count | Should -Be 0
        $persisted = Get-Content -LiteralPath $planPath -Raw | ConvertFrom-Json
        $persisted.IssueMode | Should -BeExactly 'Create'
        $persisted.Status | Should -BeExactly 'Planned'
    }

    It 'rejects unsafe state without mutation' -TestCases @(
        @{ Mode = 'Agile'; Expected = '*Basic*'; Start = $null; Finish = $null }
        @{ Mode = 'MissingTeam'; Expected = '*team*'; Start = $null; Finish = $null }
        @{ Mode = 'NonRootArea'; Expected = '*root area*'; Start = $null; Finish = $null }
        @{ Mode = 'DuplicateIssue'; Expected = '*Ambiguous*Issue*'; Start = $null; Finish = $null }
        @{ Mode = 'OneDate'; Expected = '*both sprint dates*'; Start = [datetime]'2026-09-28T00:00:00Z'; Finish = $null }
        @{ Mode = 'NotFound'; Expected = '*indeterminate*'; Start = $null; Finish = $null }
    ) {
        param($Mode, $Expected, $Start, $Finish)

        { Invoke-LeanBoardsScript -Mode $Mode -WhatIf -SprintStartDate $Start -SprintFinishDate $Finish } | Should -Throw $Expected
        @($script:MutationCalls).Count | Should -Be 0
    }

    It 'rejects indeterminate WIQL response shapes without mutation' -TestCases @(
        @{ Mode = 'QueryMissingWorkItems' }
        @{ Mode = 'QueryNullWorkItems' }
        @{ Mode = 'QueryWrongTypeWorkItems' }
    ) {
        param($Mode)

        { Invoke-LeanBoardsScript -Mode $Mode -WhatIf } | Should -Throw '*Issue*indeterminate*workItems*array*'
        @($script:MutationCalls).Count | Should -Be 0
    }

    It 'rejects foreign or ambiguous current sprint paths before any Azure DevOps call' -TestCases @(
        @{ Path = 'Other Project\Current' }
        @{ Path = 'Current' }
        @{ Path = 'Caldova HR Frontier\Iteration\Current' }
        @{ Path = 'Caldova HR Frontier\\Current' }
    ) {
        param($Path)

        {
            & $script:ScriptPath `
                -OrganizationUrl 'https://dev.azure.com/example/' `
                -ProjectName $script:ProjectName `
                -TeamName $script:TeamName `
                -CurrentSprintPath $Path `
                -IssueTitle $script:IssueTitle `
                -PlanOutputPath (Join-Path $TestDrive 'unsafe-path-plan.json') `
                -AzureDevOpsRequest $script:ExactBasicState `
                -WhatIf
        } | Should -Throw '*CurrentSprintPath*project-relative*'
        @($script:OperationCalls).Count | Should -Be 0
    }

    It 'reuses one exact tagged Issue and exposes its positive ID without deletion' {
        $result = Invoke-LeanBoardsScript -Mode 'Reuse' -WhatIf

        $result.IssueMode | Should -BeExactly 'Reuse'
        $result.IssueId | Should -Be 42
        $result.Status | Should -BeExactly 'Planned'
        @($script:MutationCalls).Count | Should -Be 0
        $script:OperationCalls | Should -Not -Contain 'DeleteWorkItem'
    }

    It 'updates dates only on the selected current sprint and reads them back' {
        $start = [datetime]'2026-10-12T00:00:00Z'
        $finish = [datetime]'2026-10-23T00:00:00Z'

        $result = Invoke-LeanBoardsScript -Mode 'Reuse' -Apply -SprintStartDate $start -SprintFinishDate $finish

        $result.Status | Should -BeExactly 'Applied'
        $result.IssueId | Should -Be 42
        $result.SprintDateMode | Should -BeExactly 'Update'
        $script:MutationCalls.Count | Should -Be 1
        $script:MutationCalls[0].Operation | Should -BeExactly 'UpdateIterationDates'
        $script:MutationCalls[0].Arguments.IterationPath | Should -BeExactly $script:IterationPath
        $script:MutationCalls[0].Arguments.StartDate | Should -Be $start
        $script:MutationCalls[0].Arguments.FinishDate | Should -Be $finish
        ($script:OperationCalls | Where-Object { $_ -ceq 'GetIteration' }).Count | Should -Be 2
        $script:State.QueryCalls | Should -Be 2
        $script:OperationCalls.LastIndexOf('QueryTraceabilityIssue') |
            Should -BeGreaterThan $script:OperationCalls.IndexOf('UpdateIterationDates')
    }

    It 'preserves observed iteration dates when sprint dates are omitted' {
        $result = Invoke-LeanBoardsScript -Mode 'Reuse' -Apply

        $result.Status | Should -BeExactly 'Applied'
        $result.SprintDateMode | Should -BeExactly 'Preserve'
        $result.SprintStartDate | Should -BeExactly '2026-09-28T00:00:00.0000000Z'
        $result.SprintFinishDate | Should -BeExactly '2026-10-09T00:00:00.0000000Z'
        @($script:MutationCalls).Count | Should -Be 0
        ($script:OperationCalls | Where-Object { $_ -ceq 'GetIteration' }).Count | Should -Be 1
    }

    It 'creates the traceability Issue with exact fields and verifies a positive ID' {
        $result = Invoke-LeanBoardsScript -Mode 'Create' -Apply

        $result.Status | Should -BeExactly 'Applied'
        $result.IssueMode | Should -BeExactly 'Create'
        $result.IssueId | Should -Be 73
        $script:MutationCalls.Count | Should -Be 1
        $script:MutationCalls[0].Operation | Should -BeExactly 'CreateTraceabilityIssue'
        $script:State.CreatedIssueFields['System.WorkItemType'] | Should -BeExactly 'Issue'
        $script:State.CreatedIssueFields['System.Title'] | Should -BeExactly $script:IssueTitle
        $script:State.CreatedIssueFields['System.AreaPath'] | Should -BeExactly $script:ProjectName
        $script:State.CreatedIssueFields['System.IterationPath'] | Should -BeExactly $script:IterationPath
        $script:State.CreatedIssueFields['System.Tags'] | Should -BeExactly $script:TraceabilityTag
        $script:State.QueryCalls | Should -Be 2
        $script:OperationCalls.LastIndexOf('QueryTraceabilityIssue') |
            Should -BeGreaterThan $script:OperationCalls.IndexOf('CreateTraceabilityIssue')
    }

    It 'fails closed when a concurrent duplicate appears after Issue creation' {
        { Invoke-LeanBoardsScript -Mode 'ConcurrentDuplicate' -Apply } |
            Should -Throw '*post-mutation*exactly one*expected*73*'
        $script:MutationCalls.Count | Should -Be 1
        $script:MutationCalls[0].Operation | Should -BeExactly 'CreateTraceabilityIssue'
        $script:State.QueryCalls | Should -Be 2
    }

    It 'fails when created Issue read-back does not match the exact requested fields' {
        { Invoke-LeanBoardsScript -Mode 'CreateMismatch' -Apply } | Should -Throw '*read-back*Title*mismatch*'
        $script:MutationCalls.Count | Should -Be 1
        $script:MutationCalls[0].Operation | Should -BeExactly 'CreateTraceabilityIssue'
        $script:OperationCalls | Should -Not -Contain 'DeleteWorkItem'
    }

    It 'fails when updated sprint dates do not match read-back' {
        $start = [datetime]'2026-10-12T00:00:00Z'
        $finish = [datetime]'2026-10-23T00:00:00Z'

        { Invoke-LeanBoardsScript -Mode 'DateMismatch' -Apply -SprintStartDate $start -SprintFinishDate $finish } |
            Should -Throw '*read-back*sprint dates*mismatch*'
        $script:MutationCalls.Count | Should -Be 1
        $script:MutationCalls[0].Operation | Should -BeExactly 'UpdateIterationDates'
    }

    It 'performs zero mutation under WhatIf even when sprint dates and Issue creation are planned' {
        $result = Invoke-LeanBoardsScript `
            -Mode 'Create' `
            -WhatIf `
            -SprintStartDate ([datetime]'2026-10-12T00:00:00Z') `
            -SprintFinishDate ([datetime]'2026-10-23T00:00:00Z')

        $result.Status | Should -BeExactly 'Planned'
        $result.SprintDateMode | Should -BeExactly 'Update'
        $result.IssueMode | Should -BeExactly 'Create'
        @($script:MutationCalls).Count | Should -Be 0
    }

    It 'performs zero mutation by default without Apply' {
        $result = Invoke-LeanBoardsScript -Mode 'Create'

        $result.Status | Should -BeExactly 'Planned'
        @($script:MutationCalls).Count | Should -Be 0
    }

    It 'rejects Apply combined with WhatIf before mutation' {
        { Invoke-LeanBoardsScript -Mode 'Create' -Apply -WhatIf } | Should -Throw '*Apply*WhatIf*'
        @($script:MutationCalls).Count | Should -Be 0
        @($script:OperationCalls).Count | Should -Be 0
    }

    It 'rejects a reversed sprint date range before mutation' {
        {
            Invoke-LeanBoardsScript `
                -Mode 'Create' `
                -Apply `
                -SprintStartDate ([datetime]'2026-10-23T00:00:00Z') `
                -SprintFinishDate ([datetime]'2026-10-12T00:00:00Z')
        } | Should -Throw '*start date*finish date*'
        @($script:MutationCalls).Count | Should -Be 0
        @($script:OperationCalls).Count | Should -Be 0
    }

    It 'accepts the repository response envelope contract from an injected adapter' {
        $innerAdapter = $script:ExactBasicState
        $wrappedAdapter = {
            param($Operation, $Arguments)

            [pscustomobject]@{
                StatusCode = 200
                Headers = @{}
                Body = & $innerAdapter $Operation $Arguments
            }
        }.GetNewClosure()

        $result = & $script:ScriptPath `
            -OrganizationUrl 'https://dev.azure.com/example/' `
            -ProjectName $script:ProjectName `
            -TeamName $script:TeamName `
            -CurrentSprintPath $script:IterationPath `
            -IssueTitle $script:IssueTitle `
            -PlanOutputPath (Join-Path $TestDrive 'wrapped-adapter-plan.json') `
            -AzureDevOpsRequest $wrappedAdapter `
            -WhatIf

        $result.ProcessName | Should -BeExactly 'Basic'
        $result.IssueMode | Should -BeExactly 'Create'
        @($script:MutationCalls).Count | Should -Be 0
    }

    It 'uses the REST 7.1 production adapter without a live Azure DevOps call' {
        $global:LeanBoardsFakeAzCalls = [System.Collections.Generic.List[object]]::new()
        $global:LeanBoardsFakeWiqlCalls = 0
        function global:az {
            $arguments = @($args | ForEach-Object { [string]$_ })
            $global:LeanBoardsFakeAzCalls.Add($arguments) | Out-Null
            $global:LASTEXITCODE = 0
            $resourceIndex = [array]::IndexOf($arguments, '--resource')
            $resource = if ($resourceIndex -ge 0) { $arguments[$resourceIndex + 1] } else { '' }

            if ($arguments -contains 'project' -and $arguments -contains 'show') {
                return '{"id":"00000000-0000-0000-0000-000000000001","name":"Caldova HR Frontier","capabilities":{"processTemplate":{"templateName":"Basic"}}}'
            }
            if ($resource -ceq 'teams') {
                return '{"id":"00000000-0000-0000-0000-000000000002","name":"Caldova HR Frontier Team","projectName":"Caldova HR Frontier"}'
            }
            if ($resource -ceq 'classificationnodes' -and $arguments -contains 'structureGroup=areas') {
                return '{"id":1,"name":"Area","path":"\\Caldova HR Frontier\\Area","structureType":"area"}'
            }
            if ($resource -ceq 'classificationnodes' -and $arguments -contains 'structureGroup=iterations') {
                return '{"id":2,"name":"Current","path":"\\Caldova HR Frontier\\Iteration\\Current","structureType":"iteration","attributes":{"startDate":"2026-09-28T00:00:00Z","finishDate":"2026-10-09T00:00:00Z"}}'
            }
            if ($resource -ceq 'wiql') {
                $global:LeanBoardsFakeWiqlCalls++
                if ($global:LeanBoardsFakeWiqlCalls -eq 1) {
                    return '{"workItems":[]}'
                }
                return '{"workItems":[{"id":73}]}'
            }
            if ($resource -ceq 'workitems' -and $arguments -contains 'POST') {
                return '{"id":73}'
            }
            if ($resource -ceq 'workitems') {
                return '{"id":73,"fields":{"System.WorkItemType":"Issue","System.Title":"Tenant 1 lean engineering platform acceptance","System.AreaPath":"Caldova HR Frontier","System.IterationPath":"Caldova HR Frontier\\Current","System.Tags":"tenant1-lean-platform-traceability"}}'
            }

            $global:LASTEXITCODE = 1
            return '{"error":"unexpected fake az command"}'
        }

        try {
            $planPath = Join-Path $TestDrive 'production-adapter-plan.json'
            $result = & $script:ScriptPath `
                -OrganizationUrl 'https://dev.azure.com/example/' `
                -ProjectName $script:ProjectName `
                -TeamName $script:TeamName `
                -CurrentSprintPath $script:IterationPath `
                -IssueTitle $script:IssueTitle `
                -PlanOutputPath $planPath `
                -Apply `
                -Confirm:$false

            $result.IssueId | Should -Be 73
            $result.Status | Should -BeExactly 'Applied'
            (Test-Path -LiteralPath (Join-Path $TestDrive 'traceability-issue-query.json')) | Should -BeTrue
            (Test-Path -LiteralPath (Join-Path $TestDrive 'traceability-issue-create.json')) | Should -BeTrue
            @($global:LeanBoardsFakeAzCalls).Count | Should -Be 8
            @($global:LeanBoardsFakeAzCalls | Where-Object { $_ -contains '--api-version' -and $_ -contains '7.1' }).Count |
                Should -Be 7

            $iterationCall = @($global:LeanBoardsFakeAzCalls | Where-Object {
                $_ -contains '--resource' -and $_ -contains 'classificationnodes' -and
                    $_ -contains 'structureGroup=iterations'
            })[0]
            ($iterationCall -join '|') | Should -BeExactly (
                @(
                    'devops', 'invoke',
                    '--organization', 'https://dev.azure.com/example/',
                    '--area', 'wit',
                    '--resource', 'classificationnodes',
                    '--route-parameters', 'project=Caldova HR Frontier', 'structureGroup=iterations', 'path=Current',
                    '--api-version', '7.1',
                    '--output', 'json'
                ) -join '|'
            )

            $createBodyPath = Join-Path $TestDrive 'traceability-issue-create.json'
            $createCall = @($global:LeanBoardsFakeAzCalls | Where-Object {
                $_ -contains '--resource' -and $_ -contains 'workitems' -and $_ -contains 'POST'
            })[0]
            ($createCall -join '|') | Should -BeExactly (
                @(
                    'devops', 'invoke',
                    '--organization', 'https://dev.azure.com/example/',
                    '--area', 'wit',
                    '--resource', 'workitems',
                    '--route-parameters', 'project=Caldova HR Frontier', 'type=Issue',
                    '--http-method', 'POST',
                    '--in-file', $createBodyPath,
                    '--media-type', 'application/json-patch+json',
                    '--api-version', '7.1',
                    '--output', 'json'
                ) -join '|'
            )

            $createPatch = Get-Content -LiteralPath $createBodyPath -Raw | ConvertFrom-Json
            $createPatch.Count | Should -Be 4
            $createPatch[0].op | Should -BeExactly 'add'
            $createPatch[0].path | Should -BeExactly '/fields/System.Title'
            $createPatch[0].value | Should -BeExactly $script:IssueTitle
            $createPatch[1].op | Should -BeExactly 'add'
            $createPatch[1].path | Should -BeExactly '/fields/System.AreaPath'
            $createPatch[1].value | Should -BeExactly $script:ProjectName
            $createPatch[2].op | Should -BeExactly 'add'
            $createPatch[2].path | Should -BeExactly '/fields/System.IterationPath'
            $createPatch[2].value | Should -BeExactly $script:IterationPath
            $createPatch[3].op | Should -BeExactly 'add'
            $createPatch[3].path | Should -BeExactly '/fields/System.Tags'
            $createPatch[3].value | Should -BeExactly $script:TraceabilityTag
        }
        finally {
            Remove-Item -Path Function:\global:az -ErrorAction SilentlyContinue
            Remove-Variable -Name LeanBoardsFakeAzCalls -Scope Global -ErrorAction SilentlyContinue
            Remove-Variable -Name LeanBoardsFakeWiqlCalls -Scope Global -ErrorAction SilentlyContinue
        }
    }

    It 'uses a nested project-relative classification-node path without a live Azure DevOps call' {
        $global:LeanBoardsNestedFakeAzCalls = [System.Collections.Generic.List[object]]::new()
        function global:az {
            $arguments = @($args | ForEach-Object { [string]$_ })
            $global:LeanBoardsNestedFakeAzCalls.Add($arguments) | Out-Null
            $global:LASTEXITCODE = 0
            $resourceIndex = [array]::IndexOf($arguments, '--resource')
            $resource = if ($resourceIndex -ge 0) { $arguments[$resourceIndex + 1] } else { '' }

            if ($arguments -contains 'project' -and $arguments -contains 'show') {
                return '{"id":"00000000-0000-0000-0000-000000000001","name":"Caldova HR Frontier","capabilities":{"processTemplate":{"templateName":"Basic"}}}'
            }
            if ($resource -ceq 'teams') {
                return '{"id":"00000000-0000-0000-0000-000000000002","name":"Caldova HR Frontier Team","projectName":"Caldova HR Frontier"}'
            }
            if ($resource -ceq 'classificationnodes' -and $arguments -contains 'structureGroup=areas') {
                return '{"id":1,"name":"Area","path":"\\Caldova HR Frontier\\Area","structureType":"area"}'
            }
            if ($resource -ceq 'classificationnodes' -and $arguments -contains 'structureGroup=iterations') {
                return '{"id":2,"name":"Current","path":"\\Caldova HR Frontier\\Iteration\\Release 1\\Current","structureType":"iteration","attributes":{"startDate":"2026-09-28T00:00:00Z","finishDate":"2026-10-09T00:00:00Z"}}'
            }
            if ($resource -ceq 'wiql') {
                return '{"workItems":[]}'
            }

            $global:LASTEXITCODE = 1
            return '{"error":"unexpected fake az command"}'
        }

        try {
            $result = & $script:ScriptPath `
                -OrganizationUrl 'https://dev.azure.com/example/' `
                -ProjectName $script:ProjectName `
                -TeamName $script:TeamName `
                -CurrentSprintPath 'Caldova HR Frontier\Release 1\Current' `
                -IssueTitle $script:IssueTitle `
                -PlanOutputPath (Join-Path $TestDrive 'nested-production-adapter-plan.json') `
                -WhatIf

            $result.Status | Should -BeExactly 'Planned'
            $iterationCall = @($global:LeanBoardsNestedFakeAzCalls | Where-Object {
                $_ -contains '--resource' -and $_ -contains 'classificationnodes' -and
                    $_ -contains 'structureGroup=iterations'
            })[0]
            ($iterationCall -join '|') | Should -BeExactly (
                @(
                    'devops', 'invoke',
                    '--organization', 'https://dev.azure.com/example/',
                    '--area', 'wit',
                    '--resource', 'classificationnodes',
                    '--route-parameters', 'project=Caldova HR Frontier', 'structureGroup=iterations', 'path=Release 1\Current',
                    '--api-version', '7.1',
                    '--output', 'json'
                ) -join '|'
            )
        }
        finally {
            Remove-Item -Path Function:\global:az -ErrorAction SilentlyContinue
            Remove-Variable -Name LeanBoardsNestedFakeAzCalls -Scope Global -ErrorAction SilentlyContinue
        }
    }
}
