Set-StrictMode -Version Latest

Describe 'Developer workstation initialization gates' {
    BeforeAll {
        $script:ScriptPath = Join-Path $PSScriptRoot '..\..\src\scripts\runbooks\Initialize-DeveloperWorkstation.ps1'
        $script:ModulePath = Join-Path $PSScriptRoot '..\..\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1'
        Import-Module $script:ModulePath -Force

        function script:New-SyntheticAssessment {
            param([ValidateSet('', 'Git')][string]$MissingTool = '')

            [pscustomobject]@{
                schemaVersion = '1.0'
                platform = [pscustomobject]@{
                    productName = 'Windows 11'
                    build = 26100
                    stableId = 'SYNTHETIC-WORKSTATION\operator'
                    packageManager = [pscustomobject]@{
                        executablePath = 'C:\Approved\winget.exe'
                        executableSha256 = ('1' * 64)
                    }
                }
                repository = [pscustomobject]@{
                    sourceCommit = ('a' * 40)
                    clean = $true
                }
                tools = @(
                    [pscustomobject]@{
                        id = 'Git'
                        status = $(if ($MissingTool -eq 'Git') { 'Missing' } else { 'Ready' })
                        version = $(if ($MissingTool -eq 'Git') { $null } else { '2.51.0.windows.1' })
                        executablePath = $(if ($MissingTool -eq 'Git') { $null } else { 'C:\Approved\git.exe' })
                        executableSha256 = $(if ($MissingTool -eq 'Git') { $null } else { ('2' * 64) })
                    }
                    [pscustomobject]@{
                        id = 'WindowsPowerShell'
                        status = 'Ready'
                        version = '5.1.26100.6584'
                        executablePath = 'C:\Approved\powershell.exe'
                        executableSha256 = ('3' * 64)
                    }
                    [pscustomobject]@{
                        id = 'AzureCli'
                        status = 'Ready'
                        version = '2.78.0'
                        executablePath = 'C:\Approved\az.cmd'
                        executableSha256 = ('4' * 64)
                    }
                    [pscustomobject]@{
                        id = 'VisualStudioCode'
                        status = 'Ready'
                        version = '1.95.0'
                        executablePath = 'C:\Approved\code.cmd'
                        executableSha256 = ('5' * 64)
                    }
                )
                azureCliExtensions = @(
                    [pscustomobject]@{
                        name = 'azure-devops'
                        status = 'Ready'
                        version = '1.0.8'
                    }
                )
                vsCodeExtensions = @(
                    [pscustomobject]@{
                        id = 'GitHub.copilot'
                        status = 'Missing'
                    }
                )
                assessmentDigest = ('b' * 64)
                overallStatus = $(if ($MissingTool) { 'Blocked' } else { 'Ready' })
            }
        }

        $script:ValidManifest = Join-Path $TestDrive 'workstation-execution-manifest.json'
        $manifest = New-RunbookExecutionManifest -RunId ([guid]'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee') `
            -Kind Workstation -SourceCommit ('a' * 40) -AssessmentDigest ('b' * 64) `
            -TargetStableId 'SYNTHETIC-WORKSTATION\operator' `
            -AuthenticationContext ([pscustomobject]@{
                executionHost = 'InteractiveWindows11PowerShell'
                mode = 'NotRequired'
            }) `
            -AllowedActions @([pscustomobject]@{
                action = 'WinGetInstallExact'
                targetId = 'Git.Git'
                packageSource = 'winget'
                packageId = 'Git.Git'
                scope = 'machine'
                expectedPostcondition = 'git.exe resolves and git --version exits 0'
            }) `
            -ToolVersions @{} -GeneratedAtUtc ([datetime]'2026-09-26T05:00:00Z')
        $script:ApprovedDigest = $manifest.digest
        Write-CanonicalJson -InputObject $manifest -Path $script:ValidManifest | Out-Null
    }

    It 'does not call a mutator by default and writes plan artifacts' {
        $mutations = [Collections.Generic.List[string]]::new()
        $repositoryRoot = Join-Path $TestDrive 'repo'
        $reportPath = Join-Path $TestDrive 'external\preview'
        [void](New-Item -ItemType Directory -Path $repositoryRoot -Force)

        $result = & $script:ScriptPath -RepositoryRoot $repositoryRoot -ReportPath $reportPath `
            -AssessmentProvider { New-SyntheticAssessment } `
            -InteractiveHostProbe { [pscustomobject]@{ isInteractive = $true; reason = 'TestHost' } } `
            -NativeCommandRunner {
                param($f, $a)
                if (($a -join ' ') -match 'install|add') { [void]$mutations.Add("$f $a") }
            }

        $mutations.Count | Should -Be 0
        $result.mode | Should -Be 'Preview'
        (Join-Path $reportPath 'workstation-plan.json') | Should -Exist
        (Join-Path $reportPath 'workstation-execution-manifest.json') | Should -Exist
    }

    It 'does not call a mutator under WhatIf even when Apply is present' {
        $mutations = [Collections.Generic.List[string]]::new()

        & $script:ScriptPath -Apply -ExecutionManifestPath $script:ValidManifest `
            -ApprovedDigest $script:ApprovedDigest -WhatIf -Confirm:$false `
            -AssessmentProvider { New-SyntheticAssessment } `
            -InteractiveHostProbe { [pscustomobject]@{ isInteractive = $true; reason = 'TestHost' } } `
            -NowUtc ([datetime]'2026-09-26T05:10:00Z') `
            -NativeCommandRunner {
                param($f, $a)
                if (($a -join ' ') -match 'install|add') { [void]$mutations.Add("$f $a") }
            } | Out-Null

        $mutations.Count | Should -Be 0
    }

    It 'refuses a digest mismatch before calling a mutator' {
        $mutations = [Collections.Generic.List[string]]::new()

        {
            & $script:ScriptPath -Apply -ExecutionManifestPath $script:ValidManifest `
                -ApprovedDigest ('f' * 64) -Confirm:$false `
                -AssessmentProvider { New-SyntheticAssessment } `
                -InteractiveHostProbe { [pscustomobject]@{ isInteractive = $true; reason = 'TestHost' } } `
                -NowUtc ([datetime]'2026-09-26T05:10:00Z') `
                -NativeCommandRunner { param($f, $a) [void]$mutations.Add("$f $a") }
        } | Should -Throw '*Approved digest*'

        $mutations.Count | Should -Be 0
    }

    It 'refuses non-interactive and GitHub Actions execution before calling a mutator' {
        $mutations = [Collections.Generic.List[string]]::new()

        {
            & $script:ScriptPath -Apply -ExecutionManifestPath $script:ValidManifest `
                -ApprovedDigest $script:ApprovedDigest -Confirm:$false `
                -InteractiveHostProbe { [pscustomobject]@{ isInteractive = $false; reason = 'GitHub Actions' } } `
                -AssessmentProvider { New-SyntheticAssessment } `
                -NowUtc ([datetime]'2026-09-26T05:10:00Z') `
                -NativeCommandRunner { param($f, $a) [void]$mutations.Add("$f $a") }
        } | Should -Throw '*interactive Windows 11 PowerShell session*'

        $mutations.Count | Should -Be 0
    }

    It 'uses exact allowlisted arguments and reads back after an approved action' {
        $calls = [Collections.Generic.List[string]]::new()
        $summaries = [Collections.Generic.List[object]]::new()

        $result = & $script:ScriptPath -Apply -ExecutionManifestPath $script:ValidManifest `
            -ApprovedDigest $script:ApprovedDigest -Confirm:$false `
            -AssessmentProvider { New-SyntheticAssessment -MissingTool Git } `
            -InteractiveHostProbe { [pscustomobject]@{ isInteractive = $true; reason = 'TestHost' } } `
            -NowUtc ([datetime]'2026-09-26T05:10:00Z') `
            -NativeCommandRunner {
                param($f, $a)
                [void]$calls.Add(('{0}|{1}' -f $f, ($a -join ' ')))
                [pscustomobject]@{ exitCode = 0; stdout = @('synthetic'); stderr = @() }
            } `
            -CommandResolver { param($name) @("C:\Approved\$name") } `
            -FileIdentityProvider {
                param($path)
                [pscustomobject]@{
                    path = $path
                    sha256 = $(if ($path -like '*winget.exe') { '1' * 64 } else { '2' * 64 })
                }
            } `
            -SummaryWriter { param($operations) foreach ($operation in $operations) { $summaries.Add($operation) } }

        $calls[0] | Should -Be 'C:\Approved\winget.exe|install --exact --id Git.Git --source winget --scope machine'
        $calls[-1] | Should -Be 'C:\Approved\git.exe|--version'
        $summaries.Count | Should -Be 1
        $summaries[0].targetId | Should -BeExactly 'Git.Git'
        $result.operations[0].readBack.status | Should -Be 'Verified'
    }

    It 'refuses a changed executable identity before mutation' {
        $calls = [Collections.Generic.List[string]]::new()

        {
            & $script:ScriptPath -Apply -ExecutionManifestPath $script:ValidManifest `
                -ApprovedDigest $script:ApprovedDigest -Confirm:$false `
                -AssessmentProvider { New-SyntheticAssessment -MissingTool Git } `
                -InteractiveHostProbe { [pscustomobject]@{ isInteractive = $true; reason = 'TestHost' } } `
                -NowUtc ([datetime]'2026-09-26T05:10:00Z') `
                -CommandResolver { param($name) @("C:\Approved\$name") } `
                -FileIdentityProvider { param($path) [pscustomobject]@{ path = $path; sha256 = ('f' * 64) } } `
                -NativeCommandRunner { param($f, $a) [void]$calls.Add($f) }
        } | Should -Throw '*executable identity changed*'

        $calls.Count | Should -Be 0
    }

    It 'keeps executable policy actions isolated from summary-writer mutation' {
        $calls = [Collections.Generic.List[string]]::new()

        & $script:ScriptPath -Apply -ExecutionManifestPath $script:ValidManifest `
            -ApprovedDigest $script:ApprovedDigest -Confirm:$false `
            -AssessmentProvider { New-SyntheticAssessment -MissingTool Git } `
            -InteractiveHostProbe { [pscustomobject]@{ isInteractive = $true; reason = 'TestHost' } } `
            -NowUtc ([datetime]'2026-09-26T05:10:00Z') `
            -CommandResolver { param($name) @("C:\Approved\$name") } `
            -FileIdentityProvider {
                param($path)
                [pscustomobject]@{
                    path = $path
                    sha256 = $(if ($path -like '*winget.exe') { '1' * 64 } else { '2' * 64 })
                }
            } `
            -SummaryWriter { param($rows) $rows[0].packageId = 'Synthetic.Mutated' } `
            -NativeCommandRunner {
                param($f, $a)
                [void]$calls.Add(('{0}|{1}' -f $f, ($a -join ' ')))
                [pscustomobject]@{ exitCode = 0; stdout = @('synthetic'); stderr = @() }
            } | Out-Null

        $calls[0] | Should -Match '--id Git\.Git'
        $calls[0] | Should -Not -Match 'Synthetic\.Mutated'
    }

    It 'refuses every manifest argument that differs from reviewed policy' -ForEach @(
        @{ field = 'packageId'; value = 'Synthetic.Other' }
        @{ field = 'packageSource'; value = 'unreviewed' }
        @{ field = 'scope'; value = 'user' }
        @{ field = 'requiredVersion'; value = '99.0.0' }
        @{ field = 'expectedPostcondition'; value = 'skip verification' }
    ) {
        param([string]$field, [string]$value)

        $manifest = Get-Content -Raw -LiteralPath $script:ValidManifest | ConvertFrom-Json
        $allowedAction = [ordered]@{
            action = [string]$manifest.allowedActions[0].action
            targetId = [string]$manifest.allowedActions[0].targetId
            packageSource = [string]$manifest.allowedActions[0].packageSource
            packageId = [string]$manifest.allowedActions[0].packageId
            scope = [string]$manifest.allowedActions[0].scope
            expectedPostcondition = [string]$manifest.allowedActions[0].expectedPostcondition
        }
        $allowedAction[$field] = $value
        $copy = New-RunbookExecutionManifest -RunId ([guid]$manifest.runId) -Kind $manifest.kind `
            -SourceCommit $manifest.sourceCommit -AssessmentDigest $manifest.assessmentDigest `
            -TargetStableId $manifest.target.stableId -AuthenticationContext $manifest.authentication `
            -AllowedActions @([pscustomobject]$allowedAction) -ToolVersions @{} `
            -GeneratedAtUtc ([datetime]$manifest.generatedAtUtc)
        $path = Join-Path $TestDrive "tampered-$field.json"
        Write-CanonicalJson -InputObject $copy -Path $path | Out-Null
        $calls = [Collections.Generic.List[string]]::new()

        {
            & $script:ScriptPath -Apply -ExecutionManifestPath $path -ApprovedDigest $copy.digest `
                -Confirm:$false -AssessmentProvider { New-SyntheticAssessment -MissingTool Git } `
                -InteractiveHostProbe { [pscustomobject]@{ isInteractive = $true; reason = 'TestHost' } } `
                -NowUtc ([datetime]'2026-09-26T05:10:00Z') `
                -NativeCommandRunner { param($f, $a) [void]$calls.Add($f) }
        } | Should -Throw '*arguments differ from reviewed policy*'

        $calls.Count | Should -Be 0
    }
}
