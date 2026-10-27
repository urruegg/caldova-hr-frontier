Describe 'Compatibility public filesystem path semantics' {
    BeforeAll {
        $script:Repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
        $script:Entry = Join-Path $script:Repo 'infra\src\scripts\runbooks\Test-DeveloperWorkstationCompatibility.ps1'
        $script:RelativeRecord = 'infra\src\config\runbooks\workstation-compatibility.json'
        $script:RelativePolicy = 'infra\src\config\runbooks\workstation-prerequisites.json'
        function script:New-CallerContractLayout {
            param([string]$Name)
            $root = Join-Path $TestDrive $Name
            New-Item -ItemType Directory -Path (Join-Path $root 'infra\src\config\runbooks') -Force | Out-Null
            Copy-Item -LiteralPath (Join-Path $script:Repo $script:RelativeRecord) -Destination (Join-Path $root $script:RelativeRecord)
            Copy-Item -LiteralPath (Join-Path $script:Repo $script:RelativePolicy) -Destination (Join-Path $root $script:RelativePolicy)
            $root
        }
    }

    It 'reads equivalent valid <Mode> contracts from the PS location without changing either cwd' -ForEach @(
        @{ Mode = 'Relative' }
        @{ Mode = 'Absolute' }
        @{ Mode = 'Default' }
    ) {
        $root = New-CallerContractLayout $Mode
        $netCwd = [Environment]::CurrentDirectory
        $calls = [Collections.Generic.List[string]]::new()
        $parameters = @{
            CommandResolver = { param($name) $calls.Add($name); @() }.GetNewClosure()
            NativeCommandRunner = { throw 'Safe path fixture never executes a native command.' }
        }
        if ($Mode -eq 'Relative') {
            $parameters.CompatibilityPath = $script:RelativeRecord
            $parameters.PolicyPath = $script:RelativePolicy
        } elseif ($Mode -eq 'Absolute') {
            $parameters.CompatibilityPath = Join-Path $root $script:RelativeRecord
            $parameters.PolicyPath = Join-Path $root $script:RelativePolicy
        }
        Push-Location $root
        try {
            (Get-Location).ProviderPath | Should -Not -Be $netCwd
            $result = & $script:Entry @parameters
            (Get-Location).ProviderPath | Should -BeExactly $root
            [Environment]::CurrentDirectory | Should -BeExactly $netCwd
        } finally { Pop-Location }
        # A known-safe empty resolver stops after contract acceptance, without claiming readiness.
        $result.diagnostic | Should -BeExactly 'Blocked:PowerShell7:InstalledSourceIdentity'
        @($result.components).Count | Should -Be 1
        @($calls) | Should -Be @('pwsh.exe')
    }

    It 'writes an equivalent <Mode> report below the caller PS location' -ForEach @(
        @{ Mode = 'Relative' }
        @{ Mode = 'Absolute' }
    ) {
        $root = New-CallerContractLayout ('report-' + $Mode)
        $netCwd = [Environment]::CurrentDirectory
        $relativeReport = 'path-report-' + [guid]::NewGuid().ToString('N')
        $expectedReport = Join-Path $root $relativeReport
        $wrongReport = Join-Path $netCwd $relativeReport
        Test-Path -LiteralPath $wrongReport | Should -BeFalse
        $reportArgument = if ($Mode -eq 'Relative') { $relativeReport } else { $expectedReport }
        $calls = [Collections.Generic.List[string]]::new()
        $failure = $null
        Push-Location $root
        try {
            (Get-Location).ProviderPath | Should -Not -Be $netCwd
            try {
                $result = & $script:Entry -CompatibilityPath (Join-Path $root $script:RelativeRecord) `
                    -PolicyPath (Join-Path $root $script:RelativePolicy) -ReportPath $reportArgument `
                    -CommandResolver { param($name) $calls.Add($name); @() }.GetNewClosure() `
                    -NativeCommandRunner { throw 'No native execution in a path regression.' }
            } catch { $failure = $_ }
            [Environment]::CurrentDirectory | Should -BeExactly $netCwd
        } finally {
            Pop-Location
            if (Test-Path -LiteralPath $wrongReport) {
                Remove-Item -LiteralPath $wrongReport -Recurse -Force
            }
        }
        $failure | Should -BeNullOrEmpty
        $result.diagnostic | Should -BeExactly 'Blocked:PowerShell7:InstalledSourceIdentity'
        (Join-Path $expectedReport 'workstation-compatibility.json') | Should -Exist
        @($calls) | Should -Be @('pwsh.exe')
    }

    It 'rejects unsupported or ambiguous <Parameter> before callbacks' -ForEach @(
        @{ Parameter = 'CompatibilityPath'; Value = 'Env:TEMP' }
        @{ Parameter = 'PolicyPath'; Value = 'Registry::HKEY_CURRENT_USER\Software' }
        @{ Parameter = 'CompatibilityPath'; Value = 'infra\src\config\runbooks\*.json' }
        @{ Parameter = 'ReportPath'; Value = 'Env:TEMP' }
        @{ Parameter = 'ReportPath'; Value = 'reports\*' }
        @{ Parameter = 'ReportPath'; Value = 'MissingWorkstationDrive:\reports' }
        @{ Parameter = 'ReportPath'; Value = 'infra\src\config\runbooks\workstation-compatibility.json' }
    ) {
        $root = New-CallerContractLayout ($Parameter + '-' + [guid]::NewGuid().ToString('N').Substring(0, 6))
        $calls = [Collections.Generic.List[string]]::new()
        $parameters = @{
            CommandResolver = { param($name) $calls.Add('resolver'); @() }.GetNewClosure()
            NativeCommandRunner = { param($file, $arguments) $calls.Add('native'); throw 'Invalid path must fail first.' }.GetNewClosure()
        }
        $parameters[$Parameter] = $Value
        $result = $null
        $failure = $null
        Push-Location $root
        try {
            try { $result = & $script:Entry @parameters } catch { $failure = $_ }
        } finally { Pop-Location }
        $calls.Count | Should -Be 0
        if ($null -ne $result) {
            $result.status | Should -BeExactly 'Blocked'
            $result.policyAccepted | Should -BeFalse
        } else { $failure | Should -Not -BeNullOrEmpty }
    }
}
