Set-StrictMode -Version Latest

Describe 'Developer workstation assessment' {
    BeforeAll {
        $script:ScriptPath = Join-Path $PSScriptRoot '..\..\src\scripts\runbooks\Test-DeveloperWorkstation.ps1'
        $script:FixturePath = Join-Path $PSScriptRoot '..\fixtures\runbooks\native-command-results.json'
        $script:RepositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))

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
            -NowUtc ([datetime]'2026-09-26T05:00:00Z')
        $second = & $script:ScriptPath -RepositoryRoot $script:RepositoryRoot `
            -NativeCommandRunner $runner `
            -InteractiveHostProbe { [pscustomobject]@{ isInteractive = $true; reason = 'TestHost' } } `
            -NowUtc ([datetime]'2026-09-26T05:20:00Z')

        $first.runId | Should -Not -Be $second.runId
        $first.assessedAtUtc | Should -Not -Be $second.assessedAtUtc
        $first.assessmentDigest | Should -BeExactly $second.assessmentDigest
    }

    It 'refuses a non-Windows-11 platform before probing tools' {
        $calls = [Collections.Generic.List[string]]::new()

        {
            & $script:ScriptPath -RepositoryRoot $script:RepositoryRoot `
                -NativeCommandRunner { param($f, $a) [void]$calls.Add($f) } `
                -PlatformProbe { [pscustomobject]@{ productName = 'Windows 10'; build = 19045 } }
        } | Should -Throw '*Windows 11*'

        $calls.Count | Should -Be 0
    }

    It 'refuses CI OIDC remoting and every non-interactive execution host' {
        $calls = [Collections.Generic.List[string]]::new()

        {
            & $script:ScriptPath -RepositoryRoot $script:RepositoryRoot `
                -InteractiveHostProbe {
                    [pscustomobject]@{ isInteractive = $false; reason = 'CI runner' }
                } `
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
}
