Set-StrictMode -Version Latest

Describe 'Developer workstation assessment' {
    Describe 'Bound current-user workstation source assessment' {
            BeforeAll {
                $script:BoundEntry = Join-Path $PSScriptRoot '..\..\src\scripts\runbooks\Test-DeveloperWorkstation.ps1'
                $script:BoundInitializer = Join-Path $PSScriptRoot '..\..\src\scripts\runbooks\Initialize-DeveloperWorkstation.ps1'
                $script:ConfigRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\src\config\runbooks'))
                $gitCommands = @(Get-Command git.exe -All -CommandType Application | ForEach-Object Source | Sort-Object -Unique)
                if ($gitCommands.Count -ne 1) { throw 'Tests require one Git executable.' }
                $script:BoundGit = $gitCommands[0]
                Import-Module (Join-Path $PSScriptRoot '..\..\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1') -Force

                function script:Invoke-FixtureGit {
                    param([string]$Root, [string[]]$Arguments)
                    $output = @(& $script:BoundGit --no-optional-locks -C $Root @Arguments 2>&1 | ForEach-Object ToString)
                    if ($LASTEXITCODE -ne 0) { throw 'Synthetic Git fixture setup failed.' }
                    $output
                }

                function script:New-BoundFixture {
                    $context = Join-Path $TestDrive ([guid]::NewGuid().ToString('N').Substring(0, 6))
                    $repo = Join-Path $context 'repo'
                    New-Item -ItemType Directory -Path (Join-Path $repo 'infra\src\config\tenants') -Force | Out-Null
                    New-Item -ItemType Directory -Path (Join-Path $repo 'infra\src\config\runbooks') | Out-Null
                    New-Item -ItemType Directory -Path (Join-Path $context 'wt\task') -Force | Out-Null
                    Copy-Item -LiteralPath (Join-Path $script:ConfigRoot 'workstation-prerequisites.json') -Destination (Join-Path $repo 'infra\src\config\runbooks')
                    Copy-Item -LiteralPath (Join-Path $script:ConfigRoot 'workstation-compatibility.json') -Destination (Join-Path $repo 'infra\src\config\runbooks')
                    [IO.File]::WriteAllText((Join-Path $repo 'README.md'), 'synthetic public source')
                    [IO.File]::WriteAllText((Join-Path $repo '.gitignore'), "*.local.psd1`n*.state.local.json`n")
                    Invoke-FixtureGit $repo @('init', '--quiet')
                    Invoke-FixtureGit $repo @('config', 'core.autocrlf', 'false')
                    Invoke-FixtureGit $repo @('config', 'user.email', 'synthetic@example.invalid')
                    Invoke-FixtureGit $repo @('config', 'user.name', 'Synthetic Fixture')
                    Invoke-FixtureGit $repo @('remote', 'add', 'origin', 'https://example.invalid/synthetic/repository.git')
                    Invoke-FixtureGit $repo @('add', '.')
                    Invoke-FixtureGit $repo @('commit', '--quiet', '-m', 'synthetic source')
                    $sha = @(Invoke-FixtureGit $repo @('rev-parse', 'HEAD'))[0]
                    $config = Join-Path $repo 'infra\src\config\tenants\tenant1.local.psd1'
                    $state = Join-Path $repo 'infra\src\config\tenants\tenant1.state.local.json'
                    [IO.File]::WriteAllText($config, 'DO-NOT-READ-SYNTHETIC-PRIVATE')
                    [IO.File]::WriteAllText($state, 'DO-NOT-READ-SYNTHETIC-PRIVATE')
                    $remoteLines = @(
                        "origin`thttps://example.invalid/synthetic/repository.git (fetch)"
                        "origin`thttps://example.invalid/synthetic/repository.git (push)"
                    )
                    $record = Get-Content -Raw (Join-Path $repo 'infra\src\config\runbooks\workstation-compatibility.json') | ConvertFrom-Json
                    $gitComponent = @($record.components | Where-Object id -CEQ Git)[0]
                    $calls = [Collections.Generic.List[string]]::new()
                    $gitPath = $script:BoundGit
                    $version = [string]$gitComponent.exactVersions[0]
                    $hash = [string]$gitComponent.installationSource.sha256
                    $runner = {
                        param($file, $arguments)
                        $calls.Add(($arguments -join ' '))
                        if ($file -cne $gitPath) { throw 'Unexpected executable in synthetic fixture.' }
                        if (($arguments -join ' ') -ceq '--version') {
                            return [pscustomobject]@{ exitCode = 0; stdout = @("git version $version"); stderr = @() }
                        }
                        $output = @(& $file @arguments 2>&1 | ForEach-Object ToString)
                        [pscustomobject]@{ exitCode = $LASTEXITCODE; stdout = $output; stderr = @() }
                    }.GetNewClosure()
                    $parameters = @{
                        RunId = [guid]::NewGuid()
                        EvidenceRoot = Join-Path $context 'evidence'
                        RepositoryRoot = $repo
                        ExpectedSourceCommit = $sha
                        RepositoryIdentity = Get-RunbookContentDigest -InputObject $remoteLines
                        ExpectedMachineId = 'SYNTHETIC-PC\fixture'
                        WorktreeRoot = Join-Path $context 'wt\task'
                        PolicyPath = Join-Path $repo 'infra\src\config\runbooks\workstation-prerequisites.json'
                        CompatibilityPath = Join-Path $repo 'infra\src\config\runbooks\workstation-compatibility.json'
                        TenantConfigurationPath = $config
                        TenantStatePath = $state
                        BackupManifestPath = Join-Path $context 'backup\manifest.json'
                        PlatformProbe = { [pscustomobject]@{ productName = 'Windows 11'; build = 26100; architecture = 'X64'; machineId = 'SYNTHETIC-PC\fixture' } }
                        InteractiveHostProbe = { [pscustomobject]@{ isInteractive = $true; reason = 'SyntheticHost' } }
                        CommandResolver = { param($name) if ($name -ceq 'git.exe') { @($gitPath) } }.GetNewClosure()
                        FileIdentityProvider = { param($path) [pscustomobject]@{ path = $path; sha256 = $hash } }.GetNewClosure()
                        NativeCommandRunner = $runner
                    }
                    [pscustomobject]@{ parameters = $parameters; context = $context; calls = $calls; gitHash = $hash }
                }

                function script:Read-BoundAssessment {
                    param($Fixture)
                    & $script:BoundEntry @($Fixture.parameters)
                }
            }

            It 'proves source and the sibling budget without claiming the missing private-backup gate' {
                $f = New-BoundFixture
                $p = $f.parameters
                $index = Join-Path $p.RepositoryRoot '.git\index'
                $before = [IO.File]::ReadAllBytes($index)
                $stamp = [IO.File]::GetLastWriteTimeUtc($index)
                $locked = [IO.File]::Open($p.TenantConfigurationPath, 'Open', 'ReadWrite', 'None')
                try { $result = & $script:BoundEntry @p } finally { $locked.Dispose() }
                $result.components.PSObject.Properties.Name | Should -Be @('worktreeAccess','pathBudget','repositorySource','repositoryCleanliness','toolIdentities')
                $result.components.worktreeAccess.classification | Should -BeExactly 'NoChange'
                $result.components.repositorySource.classification | Should -BeExactly 'NoChange'
                $result.components.repositoryCleanliness.classification | Should -BeExactly 'NoChange'
                $result.components.toolIdentities.inventory.id | Should -Be @(
                    'PowerShell7','WindowsPowerShell','Git','GitHubCli','AzureCli',
                    'Bicep','azure-devops','PowerPlatformCli','Pester'
                )
                $result.components.pathBudget.maximumExclusive | Should -Be 240
                $result.scopeStage | Should -BeExactly 'Task2AssessmentOnly'
                $result.privateBackup.classification | Should -BeExactly 'Blocked'
                $result.overallStatus | Should -BeExactly 'Blocked'
                $result.PSObject.Properties.Name | Should -Not -Contain 'childSummary'
                $json = $result | ConvertTo-Json -Depth 30
                $json | Should -Not -Match 'DO-NOT-READ|tenant1[.]local|https://example|SYNTHETIC-PC'
                $json | Should -Not -Match ([regex]::Escape($f.context))
                [Convert]::ToBase64String([IO.File]::ReadAllBytes($index)) | Should -BeExactly ([Convert]::ToBase64String($before))
                [IO.File]::GetLastWriteTimeUtc($index) | Should -Be $stamp
                @(Get-ChildItem -LiteralPath $p.WorktreeRoot -Force).Count | Should -Be 0
                @(Invoke-FixtureGit $p.RepositoryRoot @('status','--porcelain=v1','--untracked-files=all')).Count | Should -Be 0
                (Join-Path $p.EvidenceRoot "$($p.RunId)\assessment.json") | Should -Exist
                (Join-Path $p.EvidenceRoot "$($p.RunId)\summary.json") | Should -Not -Exist
                @($f.calls | Where-Object { $_ -match ' -C ' -and $_ -notmatch '^--no-optional-locks ' }).Count | Should -Be 0
            }

            It 'uses the primary checkout common directory for a linked source' {
                $f = New-BoundFixture
                $p = $f.parameters
                $linked = Join-Path $f.context 'wt\linked'
                Invoke-FixtureGit $p.RepositoryRoot @('worktree','add','--quiet','--detach',$linked)
                $p.RepositoryRoot = $linked
                $p.PolicyPath = Join-Path $linked 'infra\src\config\runbooks\workstation-prerequisites.json'
                $p.CompatibilityPath = Join-Path $linked 'infra\src\config\runbooks\workstation-compatibility.json'
                $p.TenantConfigurationPath = Join-Path $linked 'infra\src\config\tenants\tenant1.local.psd1'
                $p.TenantStatePath = Join-Path $linked 'infra\src\config\tenants\tenant1.state.local.json'
                New-Item -ItemType Directory -Path (Split-Path $p.TenantConfigurationPath) -Force | Out-Null
                [IO.File]::WriteAllText($p.TenantConfigurationPath, 'synthetic-private')
                [IO.File]::WriteAllText($p.TenantStatePath, 'synthetic-private')
                $p.WorktreeRoot = $linked
                $result = & $script:BoundEntry @p
                $result.components.worktreeAccess.classification | Should -BeExactly 'NoChange'
                $result.components.repositorySource.classification | Should -BeExactly 'NoChange'
            }

            It 'enforces the exact <Length>-character checkout boundary' -ForEach @(
                @{ Length = 239; Want = 'NoChange' }
                @{ Length = 240; Want = 'Blocked' }
            ) {
                $f = New-BoundFixture
                $p = $f.parameters
                $longest = @(Invoke-FixtureGit $p.RepositoryRoot @('-c','core.quotepath=false','ls-files') | Sort-Object Length -Descending)[0]
                $parent = Join-Path $f.context 'wt'
                $nameLength = $Length - $parent.Length - 2 - $longest.Length
                $p.WorktreeRoot = Join-Path $parent ('x' * $nameLength)
                $result = & $script:BoundEntry @p
                $result.components.pathBudget.PSObject.Properties.Name | Should -Be @('worktreeRootLength','longestTrackedRelativePath','longestCheckoutPathLength','maximumExclusive','classification')
                $result.components.pathBudget.longestCheckoutPathLength | Should -Be $Length
                $result.components.pathBudget.classification | Should -BeExactly $Want
            }

            It 'blocks <Drift> independently of the observed source' -ForEach @(
                @{ Drift = 'Machine' }
                @{ Drift = 'Commit' }
                @{ Drift = 'RemoteDigest' }
                @{ Drift = 'AdditionalFetchRemote' }
                @{ Drift = 'AdditionalPushUrl' }
            ) {
                $f = New-BoundFixture; $p = $f.parameters
                switch ($Drift) {
                    Machine { $p.ExpectedMachineId = 'OTHER-PC\fixture' }
                    Commit { $p.ExpectedSourceCommit = '1' * 40 }
                    RemoteDigest { $p.RepositoryIdentity = '2' * 64 }
                    AdditionalFetchRemote { Invoke-FixtureGit $p.RepositoryRoot @('remote','add','extra','https://example.invalid/drift.git') }
                    AdditionalPushUrl { Invoke-FixtureGit $p.RepositoryRoot @('remote','set-url','--add','--push','origin','https://example.invalid/extra.git') }
                }
                { & $script:BoundEntry @p } | Should -Throw 'Workstation.*'
                @(Get-ChildItem -LiteralPath $p.WorktreeRoot -Force).Count | Should -Be 0
            }

            It 'blocks <Kind> source without disclosing native paths or private content' -ForEach @(
                @{ Kind = 'Dirty' }; @{ Kind = 'Staged' }; @{ Kind = 'Untracked' }
                @{ Kind = 'Conflict' }; @{ Kind = 'Sparse' }; @{ Kind = 'Submodule' }; @{ Kind = 'TrackedPrivate' }
            ) {
                $f = New-BoundFixture; $p = $f.parameters
                switch ($Kind) {
                    Dirty { Add-Content (Join-Path $p.RepositoryRoot 'README.md') 'change' }
                    Staged { Add-Content (Join-Path $p.RepositoryRoot 'README.md') 'change'; Invoke-FixtureGit $p.RepositoryRoot @('add','README.md') }
                    Untracked { [IO.File]::WriteAllText((Join-Path $p.RepositoryRoot 'untracked-private-name.txt'), 'synthetic') }
                    Conflict {
                        $blob = @(Invoke-FixtureGit $p.RepositoryRoot @('rev-parse','HEAD:README.md'))[0]
                        "100644 $blob 1`tREADME.md`n100644 $blob 2`tREADME.md" | & $script:BoundGit -C $p.RepositoryRoot update-index --index-info
                    }
                    Sparse { Invoke-FixtureGit $p.RepositoryRoot @('config','core.sparseCheckout','true') }
                    Submodule { Invoke-FixtureGit $p.RepositoryRoot @('update-index','--add','--cacheinfo',"160000,$($p.ExpectedSourceCommit),synthetic-submodule") }
                    TrackedPrivate { Invoke-FixtureGit $p.RepositoryRoot @('add','--force','infra/src/config/tenants/tenant1.local.psd1') }
                }
                $failure = $null
                try { & $script:BoundEntry @p } catch { $failure = $_ }
                $failure | Should -Not -BeNullOrEmpty
                $failure.Exception.Message | Should -Match '^Workstation[.]'
                $failure.Exception.Message | Should -Not -Match 'tenant1|untracked-private|DO-NOT|synthetic-submodule'
                @(Get-ChildItem -LiteralPath $p.WorktreeRoot -Force).Count | Should -Be 0
            }

            It 'rejects unsafe <Coordinate> coordinates before reading contracts or invoking tools' -ForEach @(
                @{ Coordinate = 'PolicyOutside' }; @{ Coordinate = 'PrivateOutside' }; @{ Coordinate = 'EvidenceInside' }
                @{ Coordinate = 'WorktreeInside' }; @{ Coordinate = 'WrongSibling' }; @{ Coordinate = 'MissingRoot' }
                @{ Coordinate = 'RootAlias' }; @{ Coordinate = 'MissingIdentity' }
            ) {
                $f = New-BoundFixture; $p = $f.parameters
                switch ($Coordinate) {
                    PolicyOutside { $p.PolicyPath = Join-Path $f.context 'DO-NOT-OPEN.json' }
                    PrivateOutside { $p.TenantConfigurationPath = Join-Path $f.context 'DO-NOT-OPEN.psd1' }
                    EvidenceInside { $p.EvidenceRoot = Join-Path $p.RepositoryRoot 'evidence' }
                    WorktreeInside { $p.WorktreeRoot = Join-Path $p.RepositoryRoot 'wt\task' }
                    WrongSibling { $p.WorktreeRoot = Join-Path $f.context 'wrong\task' }
                    MissingRoot { $p.RepositoryRoot = Join-Path $f.context 'missing' }
                    RootAlias { $p.RepositoryRoot += '\.' }
                    MissingIdentity { $p.Remove('RepositoryIdentity') }
                }
                { & $script:BoundEntry @p } | Should -Throw 'Workstation.*'
                $f.calls.Count | Should -Be 0
            }

            It 'refuses a junction root before any native call' {
                $f = New-BoundFixture; $p = $f.parameters
                $alias = Join-Path $f.context 'alias'
                New-Item -ItemType Junction -Path $alias -Target $p.RepositoryRoot | Out-Null
                $p.RepositoryRoot = $alias
                try { { & $script:BoundEntry @p } | Should -Throw 'Workstation.*' }
                finally { [IO.Directory]::Delete($alias) }
                $f.calls.Count | Should -Be 0
            }

            It 'rejects <Change> Git identity before source execution' -ForEach @(
                @{ Change = 'Duplicate' }; @{ Change = 'WrongHash' }; @{ Change = 'WrongVersion' }; @{ Change = 'HashDrift' }
                @{ Change = 'WrongPath' }
            ) {
                $f = New-BoundFixture; $p = $f.parameters
                $gitPath = $script:BoundGit
                switch ($Change) {
                    Duplicate { $p.CommandResolver = { param($name) if ($name -ceq 'git.exe') { @($gitPath, 'C:\SyntheticShadow\git.exe') } }.GetNewClosure() }
                    WrongHash { $p.FileIdentityProvider = { param($path) [pscustomobject]@{ path = $path; sha256 = ('f' * 64) } } }
                    WrongPath { $p.CommandResolver = { param($name) if ($name -ceq 'git.exe') { @('C:\SyntheticShadow\git.exe') } } }
                    WrongVersion { $p.NativeCommandRunner = { param($file,$arguments) [pscustomobject]@{ exitCode = 0; stdout = @('git version 0.0.0.windows.1'); stderr = @() } } }
                    HashDrift {
                        $counter = @{ value = 0 }; $hash = $f.gitHash
                        $p.FileIdentityProvider = { param($path) $counter.value++; [pscustomobject]@{ path = $path; sha256 = $(if ($counter.value -gt 1) { 'f' * 64 } else { $hash }) } }.GetNewClosure()
                    }
                }
                { & $script:BoundEntry @p } | Should -Throw 'Workstation.*'
                if ($Change -eq 'WrongPath') { $f.calls.Count | Should -Be 0 }
                @(Get-ChildItem -LiteralPath $p.WorktreeRoot -Force).Count | Should -Be 0
            }

            It 'rejects incompatible Git architecture before any native probe' {
                $f = New-BoundFixture; $p = $f.parameters
                $programFiles = $env:ProgramFiles
                $syntheticPrograms = Join-Path $f.context 'programs'
                $syntheticGit = Join-Path $syntheticPrograms 'Git\cmd\git.exe'
                New-Item -ItemType Directory -Path (Split-Path $syntheticGit) -Force | Out-Null
                $bytes = [byte[]]::new(0x48)
                $bytes[0x3c] = 0x40
                $bytes[0x44] = 0x4c
                $bytes[0x45] = 0x01
                [IO.File]::WriteAllBytes($syntheticGit, $bytes)
                $p.CommandResolver = { param($name) if ($name -ceq 'git.exe') { @($syntheticGit) } }.GetNewClosure()
                try {
                    $env:ProgramFiles = $syntheticPrograms
                    { & $script:BoundEntry @p } | Should -Throw 'Workstation.*'
                    $f.calls.Count | Should -Be 0
                } finally { $env:ProgramFiles = $programFiles }
            }

            It 'keeps failed probe creation and deletion blocked and never deletes existing content' {
                $f = New-BoundFixture; $p = $f.parameters
                [IO.File]::WriteAllText((Join-Path $p.WorktreeRoot 'owned-by-someone-else.txt'), 'retain')
                Mock New-Item { throw 'synthetic create failure' } -ParameterFilter { $ItemType -eq 'File' }
                $result = & $script:BoundEntry @p
                $result.components.worktreeAccess.classification | Should -BeExactly 'Blocked'
                [IO.File]::ReadAllText((Join-Path $p.WorktreeRoot 'owned-by-someone-else.txt')) | Should -BeExactly 'retain'
            }

            It 'blocks a failed write or delete probe and reports only a fixed diagnostic' -ForEach @(
                @{ Operation = 'Write' }; @{ Operation = 'Delete' }
            ) {
                $f = New-BoundFixture; $p = $f.parameters
                if ($Operation -eq 'Write') { Mock Set-Content { throw 'synthetic write failure' } -ParameterFilter { $LiteralPath -like '*.access-probe-*' } }
                else { Mock Remove-Item { throw 'synthetic delete failure' } -ParameterFilter { $LiteralPath -like '*.access-probe-*' } }
                $result = & $script:BoundEntry @p
                $result.components.worktreeAccess.classification | Should -BeExactly 'Blocked'
                ($result | ConvertTo-Json -Depth 30) | Should -Not -Match 'synthetic (write|delete) failure'
            }

            It 'forwards bound context through the real initializer and produces no executable plan' {
                $f = New-BoundFixture; $p = $f.parameters
                $result = & $script:BoundInitializer @p
                $result.scopeStage | Should -BeExactly 'Task2AssessmentOnly'
                $result.assessment.components.repositorySource.classification | Should -BeExactly 'NoChange'
                $result.classification | Should -BeExactly 'Blocked'
                @(Get-ChildItem -LiteralPath $p.EvidenceRoot -Recurse -Filter '*manifest*').Count | Should -Be 0
                @(Get-ChildItem -LiteralPath $p.EvidenceRoot -Recurse -Filter 'summary.json').Count | Should -Be 0
                $p.ExpectedSourceCommit = 'e' * 40
                { & $script:BoundInitializer @p } | Should -Throw 'Workstation.*'
            }

            It 'never treats an old unbound public invocation as a canonical assessment or plan' {
                { & $script:BoundEntry -RepositoryRoot $TestDrive } | Should -Throw 'Workstation.Context.Required'
                { & $script:BoundInitializer -RepositoryRoot $TestDrive } | Should -Throw 'Workstation.Context.Required'
            }
        }
    BeforeAll {
        $script:ScriptPath = Join-Path $PSScriptRoot '..\..\src\scripts\runbooks\Test-DeveloperWorkstation.ps1'
        $script:FixturePath = Join-Path $PSScriptRoot '..\fixtures\runbooks\native-command-results.json'
        $script:RepositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
        $script:GitPath = @(
            (Get-Command git.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1).Source,
            'C:\Program Files\Git\cmd\git.exe'
        ) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) } | Select-Object -First 1
        if (-not $script:GitPath) {
            throw 'git.exe is required for DeveloperWorkstationAssessment.Tests.ps1.'
        }
        $script:Windows11PlatformProbe = {
            [pscustomobject]@{ productName = 'Windows 11'; build = 26100 }
        }

        function script:New-FixtureRunner {
            param([Parameter(Mandatory)][string]$FixturePath)

            $fixture = Get-Content -Raw -LiteralPath $FixturePath | ConvertFrom-Json
            return {
                param([string]$FilePath, [string[]]$ArgumentList)

                $key = '{0}|{1}' -f $FilePath, ($ArgumentList -join ' ')
                $property = $fixture.results.PSObject.Properties[$key]
                if ($null -eq $property) {
                    return [pscustomobject]@{
                        exitCode = 127
                        stdout = @()
                        stderr = @('fixture command not found')
                    }
                }

                $property.Value
            }.GetNewClosure()
        }

        function script:New-MinimalReviewedRepository {
            param(
                [Parameter(Mandatory)][string]$Root,
                [switch]$DuplicateSkillManifestPath,
                [switch]$CaseVariantDuplicateSkillManifestPath
            )

            [void](New-Item -ItemType Directory -Path $Root -Force)
            [void](New-Item -ItemType Directory -Path (Join-Path $Root '.github\skills\alpha') -Force)
            [void](New-Item -ItemType Directory -Path (Join-Path $Root '.github\agents') -Force)

            Set-Content -LiteralPath (Join-Path $Root '.github\skills\SUPERPOWERS_VERSION') -Value '1.0' -Encoding UTF8
            Set-Content -LiteralPath (Join-Path $Root '.github\skills\alpha\SKILL.md') -Value '# alpha' -Encoding UTF8
            Set-Content -LiteralPath (Join-Path $Root '.github\agents\docs-agent.agent.md') -Value 'docs' -Encoding UTF8
            Set-Content -LiteralPath (Join-Path $Root '.github\agents\cloud-solution-architect.agent.md') -Value 'cloud' -Encoding UTF8
            Set-Content -LiteralPath (Join-Path $Root '.github\agents\ux-designer.agent.md') -Value 'ux' -Encoding UTF8

            $skillPath = Join-Path $Root '.github\skills\alpha\SKILL.md'
            $relative = 'alpha/SKILL.md'
            $hash = (Get-FileHash -LiteralPath $skillPath -Algorithm SHA256).Hash.ToLowerInvariant()
            $manifestLines = @("$hash  $relative")
            if ($DuplicateSkillManifestPath) {
                $manifestLines += "$hash  $relative"
            }
            if ($CaseVariantDuplicateSkillManifestPath) {
                $manifestLines += "$hash  ALPHA/SKILL.md"
            }
            Set-Content -LiteralPath (Join-Path $Root '.github\skills\SUPERPOWERS_SHA256SUMS') -Value $manifestLines -Encoding UTF8
            Set-Content -LiteralPath (Join-Path $Root 'README.md') -Value 'root' -Encoding UTF8

            & $script:GitPath -C $Root init | Out-Null
            & $script:GitPath -C $Root config user.email 'runbook@example.invalid'
            & $script:GitPath -C $Root config user.name 'Runbook Test'
            & $script:GitPath -C $Root add .
            & $script:GitPath -C $Root commit -m 'fixture' | Out-Null

            $Root
        }
    }

    It 'returns structured results without invoking an install or authentication command' {
        $calls = [Collections.Generic.List[string]]::new()
        $fixtureRunner = New-FixtureRunner -FixturePath $script:FixturePath
        $runner = {
            param($file, $arguments)
            [void]$calls.Add(('{0} {1}' -f $file, ($arguments -join ' ')))
            & $fixtureRunner $file $arguments
        }.GetNewClosure()

        $result = & $script:ScriptPath -RepositoryRoot $script:RepositoryRoot `
            -NativeCommandRunner $runner `
            -InteractiveHostProbe { [pscustomobject]@{ isInteractive = $true; reason = 'TestHost' } } `
            -PlatformProbe $script:Windows11PlatformProbe `
            -NowUtc ([datetime]'2026-09-26T05:00:00Z')

        $result.schemaVersion | Should -Be '1.0'
        $result.assessmentDigest | Should -Match '^[0-9a-f]{64}$'
        ($calls -join "`n") | Should -Not -Match '(?i)\b(install|upgrade|login|auth|config|set)\b'
    }

    It 'produces the same state digest when only run identity and time change' {
        $runner = New-FixtureRunner -FixturePath $script:FixturePath

        $first = & $script:ScriptPath -RepositoryRoot $script:RepositoryRoot `
            -NativeCommandRunner $runner `
            -InteractiveHostProbe { [pscustomobject]@{ isInteractive = $true; reason = 'TestHost' } } `
            -PlatformProbe $script:Windows11PlatformProbe `
            -NowUtc ([datetime]'2026-09-26T05:00:00Z')
        $second = & $script:ScriptPath -RepositoryRoot $script:RepositoryRoot `
            -NativeCommandRunner $runner `
            -InteractiveHostProbe { [pscustomobject]@{ isInteractive = $true; reason = 'TestHost' } } `
            -PlatformProbe $script:Windows11PlatformProbe `
            -NowUtc ([datetime]'2026-09-26T05:20:00Z')

        $first.runId | Should -Not -Be $second.runId
        $first.assessedAtUtc | Should -Not -Be $second.assessedAtUtc
        $first.assessmentDigest | Should -BeExactly $second.assessmentDigest
    }

    It 'refuses a non-Windows-11 platform before probing tools' {
        $calls = [Collections.Generic.List[string]]::new()
        $platformProbeCalls = [Collections.Generic.List[string]]::new()
        $platformProbe = {
            [void]$platformProbeCalls.Add('called')
            [pscustomobject]@{ productName = 'Windows 10'; build = 19045 }
        }.GetNewClosure()

        $exception = $null
        try {
            & $script:ScriptPath -RepositoryRoot $script:RepositoryRoot `
                -NativeCommandRunner { param($f, $a) [void]$calls.Add($f) } `
                -InteractiveHostProbe {
                    [pscustomobject]@{ isInteractive = $true; reason = 'TestHost' }
                } `
                -PlatformProbe $platformProbe
        }
        catch {
            $exception = $_.Exception
        }

        $exception | Should -Not -BeNullOrEmpty
        $exception.Message | Should -BeExactly 'This runbook requires Windows 11 build 22000 or later.'
        $platformProbeCalls.Count | Should -Be 1
        $calls.Count | Should -Be 0
    }

    It 'refuses CI OIDC remoting and every non-interactive execution host' {
        $calls = [Collections.Generic.List[string]]::new()

        {
            & $script:ScriptPath -RepositoryRoot $script:RepositoryRoot `
                -InteractiveHostProbe {
                    [pscustomobject]@{ isInteractive = $false; reason = 'CI runner' }
                } `
                -PlatformProbe $script:Windows11PlatformProbe `
                -NativeCommandRunner { param($f, $a) [void]$calls.Add($f) }
        } | Should -Throw '*interactive Windows 11 PowerShell session*'

        $calls.Count | Should -Be 0
    }

    It 'blocks an ambiguous executable resolution before invoking either path' {
        $calls = [Collections.Generic.List[string]]::new()

        $result = & $script:ScriptPath -RepositoryRoot $script:RepositoryRoot `
            -CommandResolver {
                param($name)
                if ($name -eq 'git.exe') {
                    @('C:\Approved\git.exe', 'C:\Shadow\git.exe')
                }
                else {
                    @("C:\Approved\$name")
                }
            } `
            -FileIdentityProvider { param($path) [pscustomobject]@{ path = $path; sha256 = ('a' * 64) } } `
            -InteractiveHostProbe { [pscustomobject]@{ isInteractive = $true; reason = 'TestHost' } } `
            -PlatformProbe $script:Windows11PlatformProbe `
            -NativeCommandRunner { param($f, $a) [void]$calls.Add($f) }

        ($result.tools | Where-Object id -eq 'Git').status | Should -Be 'Blocked'
        $calls | Should -Not -Contain 'C:\Approved\git.exe'
        $calls | Should -Not -Contain 'C:\Shadow\git.exe'
    }

    It 'writes assessment and evidence only below a safe external report path' {
        $fixtureRunner = New-FixtureRunner -FixturePath $script:FixturePath
        $reportPath = Join-Path $TestDrive 'assessment-report'

        $result = & $script:ScriptPath -RepositoryRoot $script:RepositoryRoot `
            -NativeCommandRunner $fixtureRunner `
            -ReportPath $reportPath `
            -InteractiveHostProbe { [pscustomobject]@{ isInteractive = $true; reason = 'TestHost' } } `
            -PlatformProbe $script:Windows11PlatformProbe `
            -NowUtc ([datetime]'2026-09-26T05:00:00Z')

        $assessmentPath = Join-Path $reportPath 'workstation-assessment.json'
        $evidencePath = Join-Path $reportPath 'workstation-evidence.json'

        $assessmentPath | Should -Exist
        $evidencePath | Should -Exist
        $result.assessmentDigest | Should -BeExactly (
            (Get-Content -Raw -LiteralPath $assessmentPath | ConvertFrom-Json).assessmentDigest
        )
        (Get-Content -Raw -LiteralPath $evidencePath | ConvertFrom-Json).operation |
            Should -Be 'AssessWorkstation'
    }

    It 'reads repository state with git -C from outside the reviewed repository root' {
        $fixtureRunner = New-FixtureRunner -FixturePath $script:FixturePath
        $otherRepo = New-MinimalReviewedRepository -Root (Join-Path $TestDrive 'other-repo')
        $gitPath = $script:GitPath
        $runner = {
            param($file, $arguments)
            if ($file -ceq $gitPath) {
                $output = @(& $file @arguments 2>&1 | ForEach-Object { $_.ToString() })
                return [pscustomobject]@{
                    exitCode = $(if ($null -ne $LASTEXITCODE) { [int]$LASTEXITCODE } else { 0 })
                    stdout = $output
                    stderr = @()
                }
            }
            & $fixtureRunner $file $arguments
        }.GetNewClosure()

        Push-Location $otherRepo
        try {
            $result = & $script:ScriptPath -RepositoryRoot $script:RepositoryRoot `
                -NativeCommandRunner $runner `
                -CommandResolver {
                    param($name)
                    if ($name -eq 'git.exe') { @($gitPath) } else { @($name) }
                }.GetNewClosure() `
                -FileIdentityProvider {
                    param($path)
                    if ($path -ceq $gitPath) {
                        [pscustomobject]@{
                            path = $path
                            sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
                        }
                    }
                    else {
                        [pscustomobject]@{ path = $path; sha256 = ('a' * 64) }
                    }
                } `
                -InteractiveHostProbe { [pscustomobject]@{ isInteractive = $true; reason = 'TestHost' } } `
                -PlatformProbe $script:Windows11PlatformProbe `
                -NowUtc ([datetime]'2026-09-26T05:00:00Z')
        }
        finally {
            Pop-Location
        }

        $result.repository.root | Should -Be $script:RepositoryRoot
        $result.repository.sourceCommit | Should -Match '^[0-9a-f]{40}$'
        $result.repository.diagnostic | Should -BeNullOrEmpty
    }

    It 'rejects duplicate normalized SUPERPOWERS_SHA256SUMS paths as mismatch' {
        $fixtureRunner = New-FixtureRunner -FixturePath $script:FixturePath
        $repositoryRoot = New-MinimalReviewedRepository -Root (Join-Path $TestDrive 'duplicate-skills-repo') -DuplicateSkillManifestPath
        $gitPath = $script:GitPath
        $runner = {
            param($file, $arguments)
            if ($file -ceq $gitPath) {
                $output = @(& $file @arguments 2>&1 | ForEach-Object { $_.ToString() })
                return [pscustomobject]@{
                    exitCode = $(if ($null -ne $LASTEXITCODE) { [int]$LASTEXITCODE } else { 0 })
                    stdout = $output
                    stderr = @()
                }
            }
            & $fixtureRunner $file $arguments
        }.GetNewClosure()

        $result = & $script:ScriptPath -RepositoryRoot $repositoryRoot `
            -NativeCommandRunner $runner `
            -CommandResolver {
                param($name)
                if ($name -eq 'git.exe') { @($gitPath) } else { @($name) }
            }.GetNewClosure() `
            -FileIdentityProvider {
                param($path)
                if ($path -ceq $gitPath) {
                    [pscustomobject]@{
                        path = $path
                        sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
                    }
                }
                else {
                    [pscustomobject]@{ path = $path; sha256 = ('a' * 64) }
                }
            } `
            -InteractiveHostProbe { [pscustomobject]@{ isInteractive = $true; reason = 'TestHost' } } `
            -PlatformProbe $script:Windows11PlatformProbe `
            -NowUtc ([datetime]'2026-09-26T05:00:00Z')

        ($result.repositoryAssets | Where-Object path -eq '.github/skills' | Select-Object -First 1).status | Should -Be 'Mismatch'
    }

    It 'rejects case-variant normalized SUPERPOWERS_SHA256SUMS paths as mismatch on Windows' {
        $fixtureRunner = New-FixtureRunner -FixturePath $script:FixturePath
        $repositoryRoot = New-MinimalReviewedRepository -Root (Join-Path $TestDrive 'case-duplicate-skills-repo') -CaseVariantDuplicateSkillManifestPath
        $gitPath = $script:GitPath
        $runner = {
            param($file, $arguments)
            if ($file -ceq $gitPath) {
                $output = @(& $file @arguments 2>&1 | ForEach-Object { $_.ToString() })
                return [pscustomobject]@{
                    exitCode = $(if ($null -ne $LASTEXITCODE) { [int]$LASTEXITCODE } else { 0 })
                    stdout = $output
                    stderr = @()
                }
            }
            & $fixtureRunner $file $arguments
        }.GetNewClosure()

        $result = & $script:ScriptPath -RepositoryRoot $repositoryRoot `
            -NativeCommandRunner $runner `
            -CommandResolver {
                param($name)
                if ($name -eq 'git.exe') { @($gitPath) } else { @($name) }
            }.GetNewClosure() `
            -FileIdentityProvider {
                param($path)
                if ($path -ceq $gitPath) {
                    [pscustomobject]@{
                        path = $path
                        sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
                    }
                }
                else {
                    [pscustomobject]@{ path = $path; sha256 = ('a' * 64) }
                }
            } `
            -InteractiveHostProbe { [pscustomobject]@{ isInteractive = $true; reason = 'TestHost' } } `
            -PlatformProbe $script:Windows11PlatformProbe `
            -NowUtc ([datetime]'2026-09-26T05:00:00Z')

        ($result.repositoryAssets | Where-Object path -eq '.github/skills' | Select-Object -First 1).status | Should -Be 'Mismatch'
    }
}
