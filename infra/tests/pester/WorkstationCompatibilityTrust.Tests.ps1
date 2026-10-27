Describe 'Task1 fix round trust boundaries' {
    BeforeAll {
        $script:Repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
        $script:Helper = Join-Path $script:Repo 'infra\src\scripts\runbooks\WorkstationTools.ps1'
        $script:Entry = Join-Path $script:Repo 'infra\src\scripts\runbooks\Test-DeveloperWorkstationCompatibility.ps1'
        $script:RecordPath = Join-Path $script:Repo 'infra\src\config\runbooks\workstation-compatibility.json'
        $script:PolicyPath = Join-Path $script:Repo 'infra\src\config\runbooks\workstation-prerequisites.json'
        $script:HostPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        . $script:Helper
        function script:Invoke-TrustChild {
            param([string]$Code)
            $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes(
                "`$ProgressPreference='SilentlyContinue'; `$ErrorActionPreference='Stop';" + $Code))
            $output = @(& $script:HostPath -NoLogo -NoProfile -EncodedCommand $encoded 2>&1 |
                ForEach-Object { $_.ToString() })
            if ($LASTEXITCODE -ne 0) { throw ('Isolated trust probe failed: ' + ($output -join "`n")) }
            ($output -join "`n") | ConvertFrom-Json
        }
    }

    It 'rejects malformed raw contracts before any command resolution or native callback' -ForEach @(
        @{ Mutation = 'DuplicateVersion'; Target = 'Record' }
        @{ Mutation = 'EscapedDuplicateVersion'; Target = 'Record' }
        @{ Mutation = 'CaseAliasVersion'; Target = 'Record' }
        @{ Mutation = 'RootArray'; Target = 'Record' }
        @{ Mutation = 'ScalarCapabilities'; Target = 'Record' }
        @{ Mutation = 'ScalarReferences'; Target = 'Record' }
        @{ Mutation = 'ScalarVersionArguments'; Target = 'Policy' }
        @{ Mutation = 'DuplicatePolicyVersion'; Target = 'Policy' }
        @{ Mutation = 'RootArray'; Target = 'Policy' }
    ) {
        $text = Get-Content -Raw $(if ($Target -eq 'Record') { $script:RecordPath } else { $script:PolicyPath })
        switch ($Mutation) {
            'DuplicateVersion' { $text = $text.Replace('"version": "7.6.8"', '"version":"UNREVIEWED","version":"7.6.8"') }
            'EscapedDuplicateVersion' { $text = $text.Replace('"version": "7.6.8"', '"ver\u0073ion":"UNREVIEWED","version":"7.6.8"') }
            'CaseAliasVersion' { $text = $text.Replace('"version": "7.6.8"', '"Version":"UNREVIEWED","version":"7.6.8"') }
            'RootArray' { $text = '[' + $text + ']' }
            'ScalarCapabilities' { $text = $text.Replace('["WorktreeHelp"]', '"WorktreeHelp"') }
            'ScalarReferences' { $text = $text.Replace(
                '["https://github.com/git-for-windows/git/releases/tag/v2.56.0.windows.3"]',
                '"https://github.com/git-for-windows/git/releases/tag/v2.56.0.windows.3"') }
            'ScalarVersionArguments' { $text = $text.Replace('["--version"]', '"--version"') }
            'DuplicatePolicyVersion' { $text = $text.Replace(
                '"mode": "Exact", "value": "2.56.0.windows.3"',
                '"mode":"Exact","value":"UNREVIEWED","value":"2.56.0.windows.3"') }
        }
        $path = Join-Path $TestDrive ($Target + '-' + $Mutation + '.json')
        [IO.File]::WriteAllText($path, $text, [Text.UTF8Encoding]::new($false))
        $calls = [Collections.Generic.List[string]]::new()
        $parameters = @{
            CommandResolver = { param($name) $calls.Add('resolver'); throw 'Contract must be rejected first.' }.GetNewClosure()
            NativeCommandRunner = { param($file, $arguments) $calls.Add('native'); throw 'Contract must be rejected first.' }.GetNewClosure()
        }
        if ($Target -eq 'Record') { $parameters.CompatibilityPath = $path } else { $parameters.PolicyPath = $path }
        $result = & $script:Entry @parameters
        $result.status | Should -BeExactly 'Blocked'
        $result.policyAccepted | Should -BeFalse
        $calls.Count | Should -Be 0
    }

    It 'never executes an ordinary replacement executable at an approved alias pathname' {
        $root = Join-Path $TestDrive 'alias-install'
        $alias = Join-Path $root 'Microsoft\WindowsApps\pwsh.exe'
        New-Item -ItemType Directory -Path (Split-Path $alias -Parent) -Force | Out-Null
        $marker = Join-Path $TestDrive 'alias-executed.txt'
        $source = @'
using System;
using System.IO;
public class AliasReplacement {
    public static void Main() {
        File.WriteAllText(Environment.GetEnvironmentVariable("WS_TEST_MARKER"), "executed");
        Console.WriteLine(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),
            "WindowsApps", "Microsoft.PowerShell_forged", "pwsh.exe"));
    }
}
'@
        $assembly = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($source))
        $code = @"
`$source=[Text.Encoding]::Unicode.GetString([Convert]::FromBase64String('$assembly'))
Add-Type -TypeDefinition `$source -OutputAssembly '$($alias.Replace("'", "''"))' -OutputType ConsoleApplication
`$env:LOCALAPPDATA='$($root.Replace("'", "''"))'
`$env:WS_TEST_MARKER='$($marker.Replace("'", "''"))'
. '$($script:Helper.Replace("'", "''"))'
`$rejected=`$false
try { `$null=& (New-DefaultFileIdentityProvider) '$($alias.Replace("'", "''"))' } catch { `$rejected=`$true }
[pscustomobject]@{rejected=`$rejected; marker=(Test-Path -LiteralPath '$($marker.Replace("'", "''"))')} | ConvertTo-Json -Compress
"@
        $result = Invoke-TrustChild $code
        $result.rejected | Should -BeTrue
        $result.marker | Should -BeFalse
    }

    It 'checks Store package binding before a directly resolved physical host is probed' {
        $record = Get-Content -Raw $script:RecordPath | ConvertFrom-Json
        $component = @($record.components | Where-Object id -CEQ PowerShell7)[0]
        $component.appxManifestSha256 = '0' * 64
        $physical = Join-Path $env:ProgramFiles (
            'WindowsApps\Microsoft.PowerShell_' + $component.version + '.0_x64__8wekyb3d8bbwe\pwsh.exe')
        $path = Join-Path $TestDrive 'changed-store-pin.json'
        [IO.File]::WriteAllText($path, (ConvertTo-Json -InputObject $record -Depth 20))
        $calls = [Collections.Generic.List[string]]::new()
        $result = & $script:Entry -CompatibilityPath $path -CommandResolver {
            param($name) @($physical)
        }.GetNewClosure() -NativeCommandRunner {
            param($file, $arguments) $calls.Add($file); throw 'Unproven package must not be probed.'
        }.GetNewClosure()
        $result.status | Should -BeExactly 'Blocked'
        $calls.Count | Should -Be 0
    }

    It 'ignores an unreviewed module advertised through an edition-looking search directory before import' {
        $moduleRoot = Join-Path $TestDrive 'unreviewed\WindowsPowerShell\Modules'
        $package = Join-Path $moduleRoot 'Pester\5.7.1'
        New-Item -ItemType Directory $package -Force | Out-Null
        $marker = Join-Path $TestDrive 'unreviewed-module-executed.txt'
        [IO.File]::WriteAllText((Join-Path $package 'Pester.psd1'),
            "@{RootModule='Pester.psm1';ModuleVersion='5.7.1';GUID='11111111-1111-4111-8111-111111111111'}")
        [IO.File]::WriteAllText((Join-Path $package 'Pester.psm1'),
            "[IO.File]::WriteAllText('$($marker.Replace("'", "''"))','executed')")
        $code = @"
. '$($script:Helper.Replace("'", "''"))'
`$env:PSModulePath='$($moduleRoot.Replace("'", "''"))' + ';' + (Join-Path `$PSHOME 'Modules')
`$native=& (New-DefaultNativeCommandRunner) '$($script:HostPath.Replace("'", "''"))' @('-NoLogo','-NoProfile','-Command',(Get-WorkstationHostProbeCommand))
[pscustomobject]@{marker=(Test-Path -LiteralPath '$($marker.Replace("'", "''"))')} | ConvertTo-Json -Compress
"@
        (Invoke-TrustChild $code).marker | Should -BeFalse
    }

    It 'rejects changed approved package files before any import-time marker can execute' -ForEach @(
        @{ ChangedFile = 'Pester.psm1' }
        @{ ChangedFile = 'Pester.psd1' }
    ) {
        Get-Command Invoke-WorkstationTrustedHostProbe -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $record = Get-Content -Raw $script:RecordPath | ConvertFrom-Json
        $pester = $record.components | Where-Object id -CEQ Pester
        $installation = $pester.installations | Where-Object id -CEQ CurrentUserWindowsPowerShell
        $package = Join-Path $TestDrive ('package-' + $ChangedFile)
        New-Item -ItemType Directory $package | Out-Null
        foreach ($file in $installation.files) {
            $target = Join-Path $package $file.path
            New-Item -ItemType Directory (Split-Path $target -Parent) -Force | Out-Null
            [IO.File]::WriteAllText($target, 'synthetic package payload')
        }
        $marker = Join-Path $TestDrive ('tampered-' + $ChangedFile + '.txt')
        $modulePath = Join-Path $package 'Pester.psm1'
        $markerCode = "[IO.File]::WriteAllText('$($marker.Replace("'", "''"))','executed')`r`n"
        [IO.File]::WriteAllText($modulePath, $markerCode)
        [IO.File]::WriteAllText((Join-Path $package 'Pester.psd1'),
            "@{RootModule='Pester.psm1';ModuleVersion='5.7.1';GUID='11111111-1111-4111-8111-111111111111'}")
        foreach ($file in $installation.files) {
            $file.sha256 = (Get-FileHash (Join-Path $package $file.path)).Hash.ToLowerInvariant()
        }
        [IO.File]::AppendAllText((Join-Path $package $ChangedFile), "`r`n# changed after source review")
        $data = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(
            (ConvertTo-Json -InputObject $installation -Depth 20 -Compress)))
        $code = @"
. '$($script:Helper.Replace("'", "''"))'
function Get-WorkstationPesterInstallationRoot { param(`$Id) '$($package.Replace("'", "''"))' }
`$installation=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$data')) | ConvertFrom-Json
`$rejected=`$false
try { `$null=Invoke-WorkstationTrustedHostProbe -Installation `$installation } catch { `$rejected=`$true }
[pscustomobject]@{rejected=`$rejected; marker=(Test-Path -LiteralPath '$($marker.Replace("'", "''"))')} | ConvertTo-Json -Compress
"@
        $result = Invoke-TrustChild $code
        $result.rejected | Should -BeTrue
        $result.marker | Should -BeFalse
    }

    It 'retains the shared parser ordinal default while opting into workstation case-alias rejection' {
        $module = Get-WorkstationBootstrapModule
        { & $module { Assert-TenantLifecycleJsonHasUniqueProperties -Text '{"provider":{"Name":1,"name":2}}' } } |
            Should -Not -Throw
        { & $module { Assert-TenantLifecycleJsonHasUniqueProperties -Text '{"provider":{"Name":1,"name":2}}' -RejectCaseAliases } } |
            Should -Throw
        { & $module { Assert-TenantLifecycleJsonHasUniqueProperties -Text '{"provider":{"na\u006de":1,"name":2}}' } } |
            Should -Throw
    }
}
