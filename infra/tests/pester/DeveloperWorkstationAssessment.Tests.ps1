Set-StrictMode -Version Latest

Describe 'Developer workstation assessment' {
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
