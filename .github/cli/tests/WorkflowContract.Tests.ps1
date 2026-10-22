BeforeAll {
    $script:repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
    $script:workflowRoot = Join-Path $script:repositoryRoot '.github\workflows'
    $script:workflowPath = Join-Path $script:workflowRoot 'validate-repository.yml'
    $script:selectorPath = Join-Path $script:repositoryRoot '.github\cli\Get-MaintainedTestGroups.ps1'
    $script:checkoutSha = '3d3c42e5aac5ba805825da76410c181273ba90b1'
    $script:uploadSha = 'ea165f8d65b6e75b540449e92b4886f43607fa02'

    function script:Get-ScalarValue {
        param(
            [Parameter(Mandatory)][AllowEmptyString()][string[]]$Lines,
            [Parameter(Mandatory)][int]$Indent,
            [Parameter(Mandatory)][string]$Key
        )

        $pattern = '^{0}{1}:\s*(?<value>.*?)\s*$' -f (
            ' ' * $Indent
        ), [regex]::Escape($Key)
        $matches = @($Lines | Where-Object { $_ -match $pattern })
        if ($matches.Count -gt 1) {
            throw "Workflow contract parser found duplicate '$Key' values."
        }
        if ($matches.Count -eq 0) {
            return $null
        }
        [regex]::Match($matches[0], $pattern).Groups['value'].Value
    }

    function script:Get-TopLevelBlock {
        param(
            [Parameter(Mandatory)][AllowEmptyString()][string[]]$Lines,
            [Parameter(Mandatory)][string]$Key,
            [switch]$AllowMissing
        )

        $header = "$Key`:"
        $indices = @(
            for ($index = 0; $index -lt $Lines.Count; $index++) {
                if ($Lines[$index] -ceq $header) {
                    $index
                }
            }
        )
        if ($indices.Count -eq 0 -and $AllowMissing) {
            return [string[]]@()
        }
        if ($indices.Count -ne 1) {
            throw "Workflow contract parser expected one top-level '$Key' block."
        }

        $rows = [Collections.Generic.List[string]]::new()
        for ($index = $indices[0] + 1; $index -lt $Lines.Count; $index++) {
            $line = $Lines[$index]
            if (
                -not [string]::IsNullOrWhiteSpace($line) -and
                $line -cmatch '^\S'
            ) {
                break
            }
            [void]$rows.Add($line)
        }
        [string[]]$rows
    }

    function script:ConvertFrom-StepLines {
        param(
            [Parameter(Mandatory)][AllowEmptyString()][string[]]$Lines
        )

        $name = Get-ScalarValue -Lines $Lines -Indent 8 -Key 'name'
        if ([string]::IsNullOrWhiteSpace($name)) {
            throw 'Workflow contract parser requires every step to have a name.'
        }

        $with = [ordered]@{}
        $withIndex = -1
        for ($index = 0; $index -lt $Lines.Count; $index++) {
            if ($Lines[$index] -ceq '        with:') {
                if ($withIndex -ne -1) {
                    throw "Workflow contract parser found duplicate with blocks in '$name'."
                }
                $withIndex = $index
            }
        }
        if ($withIndex -ne -1) {
            for ($index = $withIndex + 1; $index -lt $Lines.Count; $index++) {
                $line = $Lines[$index]
                if ([string]::IsNullOrWhiteSpace($line)) {
                    continue
                }
                if ($line -cnotmatch '^          (?<key>[A-Za-z0-9_-]+):\s*(?<value>.*?)\s*$') {
                    break
                }
                $key = $Matches['key']
                if ($with.Contains($key)) {
                    throw "Workflow contract parser found duplicate with key '$key' in '$name'."
                }
                $with[$key] = $Matches['value']
            }
        }

        $run = $null
        $runIndex = -1
        for ($index = 0; $index -lt $Lines.Count; $index++) {
            if ($Lines[$index] -cmatch '^        run:\s*\|\s*$') {
                if ($runIndex -ne -1) {
                    throw "Workflow contract parser found duplicate run blocks in '$name'."
                }
                $runIndex = $index
            }
        }
        if ($runIndex -ne -1) {
            $runRows = [Collections.Generic.List[string]]::new()
            for ($index = $runIndex + 1; $index -lt $Lines.Count; $index++) {
                $line = $Lines[$index]
                if (-not [string]::IsNullOrEmpty($line) -and $line -cnotmatch '^          ') {
                    break
                }
                if ($line.Length -ge 10) {
                    [void]$runRows.Add($line.Substring(10))
                }
                else {
                    [void]$runRows.Add('')
                }
            }
            $run = $runRows -join "`n"
        }

        [pscustomobject]@{
            Name = $name
            Uses = Get-ScalarValue -Lines $Lines -Indent 8 -Key 'uses'
            Shell = Get-ScalarValue -Lines $Lines -Indent 8 -Key 'shell'
            If = Get-ScalarValue -Lines $Lines -Indent 8 -Key 'if'
            With = $with
            Run = $run
            Lines = [string[]]$Lines
        }
    }

    function script:ConvertFrom-JobLines {
        param(
            [Parameter(Mandatory)][string]$Id,
            [Parameter(Mandatory)][AllowEmptyString()][string[]]$Lines
        )

        $stepStarts = @(
            for ($index = 0; $index -lt $Lines.Count; $index++) {
                if ($Lines[$index] -cmatch '^      - ') {
                    $index
                }
            }
        )
        $namedStepStarts = @(
            $stepStarts | Where-Object {
                $Lines[$_] -cmatch '^      - name:\s*\S'
            }
        )
        if ($stepStarts.Count -ne $namedStepStarts.Count) {
            throw "Workflow contract parser found an unnamed or malformed step in '$Id'."
        }

        $steps = [Collections.Generic.List[object]]::new()
        for ($stepIndex = 0; $stepIndex -lt $stepStarts.Count; $stepIndex++) {
            $start = $stepStarts[$stepIndex]
            $finish = if ($stepIndex + 1 -lt $stepStarts.Count) {
                $stepStarts[$stepIndex + 1] - 1
            }
            else {
                $Lines.Count - 1
            }
            [string[]]$stepLines = @($Lines[$start..$finish])
            $stepLines[0] = $stepLines[0] -replace '^      - ', '        '
            [void]$steps.Add((ConvertFrom-StepLines -Lines $stepLines))
        }

        $needsValue = Get-ScalarValue -Lines $Lines -Indent 4 -Key 'needs'
        [string[]]$needs = @()
        if (-not [string]::IsNullOrWhiteSpace($needsValue)) {
            if ($needsValue -cnotmatch '^\[(?<items>.*?)\]$') {
                throw "Workflow contract parser requires inline needs for '$Id'."
            }
            $needs = [string[]]@(
                $Matches['items'].Split(',') |
                    ForEach-Object { $_.Trim() } |
                    Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
            )
        }

        [pscustomobject]@{
            Id = $Id
            Name = Get-ScalarValue -Lines $Lines -Indent 4 -Key 'name'
            RunsOn = Get-ScalarValue -Lines $Lines -Indent 4 -Key 'runs-on'
            TimeoutMinutes = Get-ScalarValue -Lines $Lines -Indent 4 -Key 'timeout-minutes'
            If = Get-ScalarValue -Lines $Lines -Indent 4 -Key 'if'
            Needs = $needs
            Steps = [object[]]$steps
            Lines = [string[]]$Lines
        }
    }

    function script:ConvertFrom-WorkflowLines {
        param(
            [Parameter(Mandatory)][AllowEmptyString()][string[]]$Lines
        )

        $jobsBlock = Get-TopLevelBlock -Lines $Lines -Key 'jobs'
        $jobStarts = @(
            for ($index = 0; $index -lt $jobsBlock.Count; $index++) {
                if ($jobsBlock[$index] -cmatch '^  (?<id>[a-z][a-z0-9_-]*):\s*$') {
                    [pscustomobject]@{
                        Index = $index
                        Id = $Matches['id']
                    }
                }
            }
        )
        if ($jobStarts.Count -eq 0) {
            throw 'Workflow contract parser found no jobs.'
        }

        $jobs = [ordered]@{}
        for ($jobIndex = 0; $jobIndex -lt $jobStarts.Count; $jobIndex++) {
            $start = $jobStarts[$jobIndex].Index
            $finish = if ($jobIndex + 1 -lt $jobStarts.Count) {
                $jobStarts[$jobIndex + 1].Index - 1
            }
            else {
                $jobsBlock.Count - 1
            }
            $id = $jobStarts[$jobIndex].Id
            if ($jobs.Contains($id)) {
                throw "Workflow contract parser found duplicate job '$id'."
            }
            $jobs[$id] = ConvertFrom-JobLines -Id $id -Lines @(
                $jobsBlock[$start..$finish]
            )
        }

        $permissionsBlock = Get-TopLevelBlock -Lines $Lines -Key 'permissions'
        $permissions = [ordered]@{}
        foreach ($line in $permissionsBlock) {
            if ([string]::IsNullOrWhiteSpace($line)) {
                continue
            }
            if ($line -cnotmatch '^  (?<key>[A-Za-z0-9_-]+):\s*(?<value>\S+)\s*$') {
                throw 'Workflow contract parser found malformed global permissions.'
            }
            $permissions[$Matches['key']] = $Matches['value']
        }

        $concurrencyBlock = Get-TopLevelBlock `
            -Lines $Lines `
            -Key 'concurrency' `
            -AllowMissing
        $concurrency = [ordered]@{}
        foreach ($line in $concurrencyBlock) {
            if ([string]::IsNullOrWhiteSpace($line)) {
                continue
            }
            if ($line -cnotmatch '^  (?<key>[A-Za-z0-9_-]+):\s*(?<value>.*?)\s*$') {
                throw 'Workflow contract parser found malformed concurrency configuration.'
            }
            $concurrency[$Matches['key']] = $Matches['value']
        }

        [pscustomobject]@{
            Name = Get-ScalarValue -Lines $Lines -Indent 0 -Key 'name'
            OnLines = Get-TopLevelBlock -Lines $Lines -Key 'on'
            Permissions = $permissions
            Concurrency = $concurrency
            Jobs = $jobs
            Lines = [string[]]$Lines
        }
    }

    function script:Get-NamedStep {
        param(
            [Parameter(Mandatory)][object]$Job,
            [Parameter(Mandatory)][string]$Name
        )

        $steps = @($Job.Steps | Where-Object Name -CEQ $Name)
        if ($steps.Count -ne 1) {
            throw "Workflow contract expected one '$Name' step in '$($Job.Id)'."
        }
        $steps[0]
    }

    function script:Get-DiscoveredLifecycleCaseId {
        param(
            [Parameter(Mandatory)][string[]]$Path,
            [ValidateSet('All', 'Include', 'Exclude')][string]$Mode
        )

        $configuration = New-PesterConfiguration
        $configuration.Run.Path = $Path
        $configuration.Run.SkipRun = $true
        $configuration.Run.PassThru = $true
        $configuration.Output.Verbosity = 'None'
        if ($Mode -ceq 'Include') {
            $configuration.Filter.Tag = @('CICompatibilitySmoke')
        }
        elseif ($Mode -ceq 'Exclude') {
            $configuration.Filter.ExcludeTag = @('CICompatibilitySmoke')
        }
        $result = Invoke-Pester -Configuration $configuration
        @(
            for ($index = 0; $index -lt $result.Tests.Count; $index++) {
                $test = $result.Tests[$index]
                if (-not $test.ShouldRun) {
                    continue
                }
                '{0:D6}:{1}:{2}::{3}' -f (
                    $index,
                    $test.ScriptBlock.File,
                    ($test.Path -join ' > '),
                    $test.ExpandedName
                )
            }
        )
    }

    function script:Get-ReplacedGateScript {
        param(
            [Parameter(Mandatory)][string]$Run,
            [Parameter(Mandatory)][hashtable]$Results
        )

        $scriptText = $Run
        foreach ($dependency in @('repository', 'infrastructure', 'hr', 'lifecycle')) {
            $token = '${{ needs.' + $dependency + '.result }}'
            $scriptText = $scriptText.Replace($token, [string]$Results[$dependency])
        }
        [scriptblock]::Create($scriptText)
    }

    $script:workflowContent = Get-Content -Raw -LiteralPath $script:workflowPath
    [string[]]$script:workflowLines = @(
        Get-Content -LiteralPath $script:workflowPath
    )
    $script:workflow = ConvertFrom-WorkflowLines -Lines $script:workflowLines
    [string[]]$script:domainIds = @(
        'repository'
        'infrastructure'
        'hr'
        'lifecycle'
    )
}

Describe 'Parallel repository validation workflow' {
    It 'keeps one Validate repository workflow with global contents read' {
        $workflowNames = @(
            Get-ChildItem -LiteralPath $script:workflowRoot -File |
                Where-Object Extension -In @('.yml', '.yaml') |
                Select-Object -ExpandProperty Name
        )
        $workflowNames | Should -Be @('validate-repository.yml')
        $script:workflow.Name | Should -BeExactly 'Validate repository'
        @($script:workflow.Permissions.Keys) | Should -Be @('contents')
        $script:workflow.Permissions['contents'] | Should -BeExactly 'read'

        $eventNames = @(
            $script:workflow.OnLines |
                ForEach-Object {
                    if ($_ -cmatch '^  (?<event>[a-z_]+):') {
                        $Matches['event']
                    }
                }
        )
        $eventNames | Should -Be @('pull_request', 'push', 'workflow_dispatch')
        ($script:workflow.OnLines -join "`n") |
            Should -Match '(?m)^    branches:\s*\[main\]\s*$'

        $yamlParser = Get-Command ConvertFrom-Yaml -ErrorAction SilentlyContinue
        if ($null -eq $yamlParser) {
            Write-Verbose 'ConvertFrom-Yaml is unavailable; the repository semantic parser remains authoritative.'
        }
        else {
            $parsed = $script:workflowContent | ConvertFrom-Yaml
            $parsed.jobs | Should -Not -BeNullOrEmpty
            $parsedJobKeys = if ($parsed.jobs -is [Collections.IDictionary]) {
                @($parsed.jobs.Keys)
            }
            else {
                @($parsed.jobs.PSObject.Properties.Name)
            }
            $parsedJobKeys | Should -Be @(
                'repository'
                'infrastructure'
                'hr'
                'lifecycle'
                'validate'
            )
        }
    }

    It 'defines exactly repository infrastructure hr lifecycle and validate jobs' {
        @($script:workflow.Jobs.Keys) | Should -Be @(
            'repository'
            'infrastructure'
            'hr'
            'lifecycle'
            'validate'
        )
    }

    It 'uses exact display names windows-2025 runners and 30 30 30 45 15 timeouts' {
        $expected = [ordered]@{
            repository = @('Repository/documentation validation', '30')
            infrastructure = @('Infrastructure validation', '30')
            hr = @('HR solution validation', '30')
            lifecycle = @('Lifecycle/runbook validation', '45')
            validate = @('Repository setup validation', '15')
        }
        foreach ($jobId in $expected.Keys) {
            $job = $script:workflow.Jobs[$jobId]
            $job.Name | Should -BeExactly $expected[$jobId][0]
            $job.RunsOn | Should -BeExactly 'windows-2025'
            $job.TimeoutMinutes | Should -BeExactly $expected[$jobId][1]
        }
    }

    It 'declares powershell on every run step' {
        $runSteps = @(
            foreach ($job in $script:workflow.Jobs.Values) {
                $job.Steps | Where-Object { $null -ne $_.Run }
            }
        )
        $runSteps.Count | Should -BeGreaterThan 0
        foreach ($step in $runSteps) {
            $step.Shell | Should -BeExactly 'powershell'
        }
    }

    It 'uses pinned checkout and fetch-depth zero on every domain only' {
        foreach ($domainId in $script:domainIds) {
            $job = $script:workflow.Jobs[$domainId]
            $checkoutSteps = @(
                $job.Steps |
                    Where-Object Uses -CEQ "actions/checkout@$($script:checkoutSha)"
            )
            $checkoutSteps.Count | Should -Be 1
            $checkoutSteps[0].With['fetch-depth'] | Should -BeExactly '0'
            $checkoutSteps[0].Run | Should -BeNullOrEmpty
            $checkoutSteps[0].Shell | Should -BeNullOrEmpty
        }

        @($script:workflow.Jobs.validate.Steps | Where-Object {
            -not [string]::IsNullOrWhiteSpace($_.Uses)
        }) | Should -BeNullOrEmpty
    }

    It 'uses the selector installer and runner for every owning domain' {
        $expected = [ordered]@{
            repository = @('Repository', 'test-results/repository/pester.xml', 1)
            infrastructure = @('Infrastructure', 'test-results/infrastructure/pester.xml', 1)
            hr = @('Hr', 'test-results/hr/pester.xml', 1)
            lifecycle = @('Lifecycle', 'test-results/lifecycle/smoke.xml', 2)
        }
        foreach ($domainId in $expected.Keys) {
            $testStep = @(
                $script:workflow.Jobs[$domainId].Steps |
                    Where-Object Name -Like 'Run * tests'
            )
            $testStep.Count | Should -Be 1
            $run = $testStep[0].Run
            $run | Should -Match (
                [regex]::Escape(
                    ".github/cli/Install-CiTestDependencies.ps1 -Group $($expected[$domainId][0]) -MaxAttempts 3"
                )
            )
            $run | Should -Match (
                [regex]::Escape(
                    ".github/cli/Get-MaintainedTestGroups.ps1 -Group $($expected[$domainId][0])"
                )
            )
            @(
                [regex]::Matches(
                    $run,
                    [regex]::Escape('.github/cli/Invoke-MaintainedTestGroup.ps1')
                )
            ).Count | Should -Be $expected[$domainId][2]
            $run | Should -Match ([regex]::Escape($expected[$domainId][1]))
            $run | Should -Not -Match '\bInvoke-Pester\b|Get-ChildItem.+Tests\.ps1'
        }
    }

    It 'keeps Repository safety and merge-base whitespace in repository' {
        $repositoryJob = $script:workflow.Jobs.repository
        $safety = Get-NamedStep -Job $repositoryJob -Name 'Run repository safety validation'
        $safety.Run | Should -Match (
            [regex]::Escape('.github/cli/verify-repository-safety.ps1')
        )
        $safety.Run | Should -Match '\$LASTEXITCODE\s+-ne\s+0'

        $whitespace = Get-NamedStep -Job $repositoryJob -Name 'Check branch whitespace'
        $whitespace.Run | Should -Match '\bgit merge-base\b'
        $whitespace.Run | Should -Match '\bgit diff --check\b'
        $whitespace.Run | Should -Not -Match 'HEAD~\d+'

        $otherRuns = @(
            foreach ($jobId in @('infrastructure', 'hr', 'lifecycle', 'validate')) {
                $script:workflow.Jobs[$jobId].Steps.Run
            }
        ) -join "`n"
        $otherRuns | Should -Not -Match 'verify-repository-safety|git diff --check'
    }

    It 'keeps recursive local Bicep compilation in infrastructure' {
        $build = Get-NamedStep `
            -Job $script:workflow.Jobs.infrastructure `
            -Name 'Build every maintained Bicep entry point'
        $build.Run | Should -Match (
            [regex]::Escape(
                "Get-ChildItem -LiteralPath 'infra/src/bicep' -Filter '*.bicep' -File -Recurse"
            )
        )
        $build.Run | Should -Match 'entryPoints\.Count\s+-eq\s+0'
        $build.Run | Should -Match '\baz bicep build --file\b'

        $otherRuns = @(
            foreach ($jobId in @('repository', 'hr', 'lifecycle', 'validate')) {
                $script:workflow.Jobs[$jobId].Steps.Run
            }
        ) -join "`n"
        $otherRuns | Should -Not -Match '\baz bicep build\b'
    }

    It 'keeps Hr and Lifecycle Python requirements independent' {
        $hrRun = (Get-NamedStep `
            -Job $script:workflow.Jobs.hr `
            -Name 'Run HR tests').Run
        $lifecycleRun = (Get-NamedStep `
            -Job $script:workflow.Jobs.lifecycle `
            -Name 'Run lifecycle tests').Run

        $hrRun | Should -Match (
            [regex]::Escape(
                '.github/cli/Install-CiTestDependencies.ps1 -Group Hr -MaxAttempts 3'
            )
        )
        $lifecycleRun | Should -Match (
            [regex]::Escape(
                '.github/cli/Install-CiTestDependencies.ps1 -Group Lifecycle -MaxAttempts 3'
            )
        )
        $hrRun | Should -Not -Match 'infra/tests/requirements\.txt|\bpip\b'
        $lifecycleRun | Should -Not -Match 'hr/tests/requirements\.txt|\bpip\b'
    }

    It 'partitions lifecycle smoke and remainder without duplicate cases' {
        $run = (Get-NamedStep `
            -Job $script:workflow.Jobs.lifecycle `
            -Name 'Run lifecycle tests').Run
        $run | Should -Match (
            '(?s)test-results/lifecycle/smoke\.xml.*-Tag CICompatibilitySmoke'
        )
        $run | Should -Match (
            '(?s)test-results/lifecycle/remainder\.xml.*-ExcludeTag CICompatibilitySmoke'
        )
        $run | Should -Not -Match 'FullNameFilter|\bInvoke-Pester\b'

        [string[]]$paths = @(& $script:selectorPath -Group Lifecycle)
        [string[]]$all = @(Get-DiscoveredLifecycleCaseId -Path $paths -Mode All)
        [string[]]$smoke = @(Get-DiscoveredLifecycleCaseId -Path $paths -Mode Include)
        [string[]]$remainder = @(Get-DiscoveredLifecycleCaseId -Path $paths -Mode Exclude)
        $all.Count | Should -BeGreaterThan 0
        $smoke.Count | Should -BeGreaterThan 0
        $remainder.Count | Should -BeGreaterThan 0

        $remainderSet = [Collections.Generic.HashSet[string]]::new(
            $remainder,
            [StringComparer]::Ordinal
        )
        @($smoke | Where-Object { $remainderSet.Contains($_) }) |
            Should -BeNullOrEmpty

        $union = [Collections.Generic.HashSet[string]]::new(
            [StringComparer]::Ordinal
        )
        foreach ($caseId in @($smoke + $remainder)) {
            [void]$union.Add($caseId)
        }
        [string[]]$unionRows = @($union)
        [string[]]$allRows = @($all)
        [Array]::Sort($unionRows, [StringComparer]::Ordinal)
        [Array]::Sort($allRows, [StringComparer]::Ordinal)
        $unionRows | Should -Be $allRows
    }

    It 'uploads four unique always-run raw NUnit artifacts for fourteen days' {
        $expected = [ordered]@{
            repository = @('repository-validation-test-results', 'test-results/repository')
            infrastructure = @('infrastructure-validation-test-results', 'test-results/infrastructure')
            hr = @('hr-validation-test-results', 'test-results/hr')
            lifecycle = @('lifecycle-validation-test-results', 'test-results/lifecycle')
        }
        $artifactNames = [Collections.Generic.HashSet[string]]::new(
            [StringComparer]::Ordinal
        )
        foreach ($domainId in $expected.Keys) {
            $uploads = @(
                $script:workflow.Jobs[$domainId].Steps |
                    Where-Object Uses -Like 'actions/upload-artifact@*'
            )
            $uploads.Count | Should -Be 1
            $upload = $uploads[0]
            $upload.If | Should -BeExactly 'always()'
            $upload.With['name'] | Should -BeExactly $expected[$domainId][0]
            $upload.With['path'] | Should -BeExactly $expected[$domainId][1]
            $upload.With['if-no-files-found'] | Should -BeExactly 'warn'
            $upload.With['retention-days'] | Should -BeExactly '14'
            $artifactNames.Add([string]$upload.With['name']) | Should -BeTrue
        }
        $artifactNames.Count | Should -Be 4
    }

    It 'uses the exact reviewed upload-artifact SHA' {
        $uploads = @(
            foreach ($domainId in $script:domainIds) {
                $script:workflow.Jobs[$domainId].Steps |
                    Where-Object Uses -Like 'actions/upload-artifact@*'
            }
        )
        $uploads.Count | Should -Be 4
        foreach ($upload in $uploads) {
            $upload.Uses |
                Should -BeExactly "actions/upload-artifact@$($script:uploadSha)"
        }
    }

    It 'keeps validate a pure result gate over all four dependencies' {
        $validate = $script:workflow.Jobs.validate
        $validate.Needs | Should -Be $script:domainIds
        $validate.If | Should -BeExactly 'always()'
        $validate.Steps.Count | Should -Be 1
        $gate = Get-NamedStep `
            -Job $validate `
            -Name 'Require every validation domain'
        $gate.Uses | Should -BeNullOrEmpty
        $gate.With.Count | Should -Be 0
        foreach ($domainId in $script:domainIds) {
            $gate.Run | Should -Match (
                [regex]::Escape('${{ needs.' + $domainId + '.result }}')
            )
        }
        $gate.Run | Should -Match "Value -cne 'success'"
        $gate.Run | Should -Match '\bthrow\b'
        $gate.Run | Should -Not -Match (
            'checkout|Install-CiTestDependencies|Get-MaintainedTestGroups|' +
            'Invoke-MaintainedTestGroup|upload-artifact|verify-repository-safety|' +
            'bicep|git diff'
        )
    }

    It 'fails validate for failure cancelled or skipped dependencies' {
        $gate = Get-NamedStep `
            -Job $script:workflow.Jobs.validate `
            -Name 'Require every validation domain'
        $success = @{
            repository = 'success'
            infrastructure = 'success'
            hr = 'success'
            lifecycle = 'success'
        }
        {
            & (Get-ReplacedGateScript -Run $gate.Run -Results $success)
        } | Should -Not -Throw

        foreach ($status in @('failure', 'cancelled', 'skipped')) {
            $results = $success.Clone()
            $results['repository'] = $status
            {
                & (Get-ReplacedGateScript -Run $gate.Run -Results $results)
            } | Should -Throw
        }
    }

    It 'uses exact PR-number-or-ref concurrency with cancellation' {
        @($script:workflow.Concurrency.Keys) | Should -Be @(
            'group'
            'cancel-in-progress'
        )
        $script:workflow.Concurrency['group'] | Should -BeExactly (
            '${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}'
        )
        $script:workflow.Concurrency['cancel-in-progress'] |
            Should -BeExactly 'true'
    }

    It 'excludes path filters caches publishers provider operations and deployment authority' {
        ($script:workflow.OnLines -join "`n") |
            Should -Not -Match '(?m)^\s+paths(?:-ignore)?:'

        $actionUses = @(
            foreach ($job in $script:workflow.Jobs.Values) {
                $job.Steps.Uses |
                    Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
            }
        )
        foreach ($actionUse in $actionUses) {
            $actionUse | Should -BeIn @(
                "actions/checkout@$($script:checkoutSha)"
                "actions/upload-artifact@$($script:uploadSha)"
            )
        }

        $allRunBlocks = @(
            foreach ($job in $script:workflow.Jobs.Values) {
                $job.Steps.Run |
                    Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
            }
        ) -join "`n"
        $allRunBlocks | Should -Not -Match (
            '(?i)\b(?:az\s+(?:login|account|deployment|group|rest)|' +
            'Connect-AzAccount|New-Az\w+|terraform|azd|kubectl|' +
            'Publish-TestResults|cache)\b'
        )
        ($script:workflowLines -join "`n") | Should -Not -Match (
            '(?m)^\s*(?:checks|id-token|actions|pull-requests):\s+write\s*$|' +
            '^\s*(?:environment|secrets):'
        )
    }
}
