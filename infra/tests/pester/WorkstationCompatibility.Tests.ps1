Describe 'Fail-closed workstation compatibility' {
    BeforeAll {
        $script:Repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
        $script:Record = Join-Path $script:Repo 'infra\src\config\runbooks\workstation-compatibility.json'
        $script:Policy = Join-Path $script:Repo 'infra\src\config\runbooks\workstation-prerequisites.json'
        $script:Helper = Join-Path $script:Repo 'infra\src\scripts\runbooks\WorkstationTools.ps1'
        $script:Entry = Join-Path $script:Repo 'infra\src\scripts\runbooks\Test-DeveloperWorkstationCompatibility.ps1'
        $script:Schema = Join-Path $script:Repo 'infra\src\config\schemas\workstation-compatibility.schema.json'
        function script:Read-CompatibilityFixture {
            param([string]$Path)
            $parameters = @{ InputObject = [IO.File]::ReadAllText($Path) }
            if ((Get-Command ConvertFrom-Json).Parameters.ContainsKey('DateKind')) { $parameters.DateKind = 'String' }
            ConvertFrom-Json @parameters
        }
    }

    It 'requires exact full vendor versions and nine reviewed components before accepting policy' {
        Test-Path -LiteralPath $script:Record | Should -BeTrue
        . $script:Helper
        $record = Read-CompatibilityFixture $script:Record
        { Assert-WorkstationCompatibilityRecord $record } | Should -Not -Throw
        @($record.components).Count | Should -Be 9
        $policy = Read-CompatibilityFixture $script:Policy
        foreach ($component in $record.components) {
            $item = if ($component.id -eq 'azure-devops') { $policy.azureCliExtensions[0] } else {
                $policy.tools | Where-Object id -CEQ $component.id
            }
            $item.versionPolicy.mode | Should -BeExactly 'Exact'
            $item.versionPolicy.value | Should -BeExactly $component.version
        }
        $record.review.kind | Should -BeExactly 'AutomatedTechnicalReview'
        $record.review.isApproval | Should -BeFalse
    }

    It 'rejects unknown record properties and non-first-party references before any native command' {
        Test-Path -LiteralPath $script:Entry | Should -BeTrue
        $record = Read-CompatibilityFixture $script:Record
        $record | Add-Member NoteProperty unexpected 'not permitted'
        $path = Join-Path $TestDrive 'invalid.json'
        $record | ConvertTo-Json -Depth 20 | Set-Content $path
        $calls = [Collections.Generic.List[string]]::new()
        $result = & $script:Entry -CompatibilityPath $path -NativeCommandRunner {
            param($file, $arguments)
            $calls.Add($file)
        }.GetNewClosure()
        $result.status | Should -BeExactly 'Blocked'
        $result.policyAccepted | Should -BeFalse
        $calls.Count | Should -Be 0
    }

    It 'accepts the complete reviewed delivery contract under the production strict host' {
        . $script:Helper
        $record = Read-CompatibilityFixture $script:Record
        $policy = Read-CompatibilityFixture $script:Policy
        {
            Set-StrictMode -Version Latest
            Assert-WorkstationDeliveryPolicy $policy $record (
                Join-Path $script:Repo 'infra\src\config\schemas\workstation-prerequisites.schema.json')
        } | Should -Not -Throw
    }

    It 'preserves quoted host probe expressions across Windows PowerShell native argument passing' {
        . $script:Helper
        $hostPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $native = Invoke-NativeCommand (New-DefaultNativeCommandRunner) $hostPath @(
            '-NoLogo', '-NoProfile', '-Command',
            '[pscustomobject]@{text="a b"; value="literal"} | ConvertTo-Json -Compress')
        $native.exitCode | Should -Be 0
        (($native.stdout -join "`n") | ConvertFrom-Json).text | Should -BeExactly 'a b'
    }

    It 'imports the unique edition-specific module rather than an inherited other-edition copy' {
        . $script:Helper
        Get-Command Get-WorkstationHostProbeCommand -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $hostPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $native = Invoke-NativeCommand (New-DefaultNativeCommandRunner) $hostPath @(
            '-NoLogo', '-NoProfile', '-Command', (Get-WorkstationHostProbeCommand))
        $native.exitCode | Should -Be 0
        $state = ($native.stdout -join "`n") | ConvertFrom-Json
        $state.pester | Should -BeExactly '5.7.1'
        $state.arch | Should -BeExactly 'X64'
        $state.windows | Should -BeTrue
    }

    It 'rejects an unproven component, partial version, source drift or unsupported architecture' -ForEach @(
        @{ Field = 'version'; Value = '7' }
        @{ Field = 'source'; Value = 'Unreviewed' }
        @{ Field = 'architecture'; Value = 'Arm64' }
        @{ Field = 'capabilities'; Value = @() }
        @{ Field = 'references'; Value = @('https://example.invalid/not-a-publisher') }
        @{ Field = 'sha256'; Value = 'unknown' }
    ) {
        Test-Path -LiteralPath $script:Helper | Should -BeTrue
        . $script:Helper
        $record = Read-CompatibilityFixture $script:Record
        $record.components[0].$Field = $Value
        { Assert-WorkstationCompatibilityRecord $record } | Should -Throw
    }

    It 'does not accept version prefixes, floating values or lost vendor suffixes' {
        Test-Path -LiteralPath $script:Helper | Should -BeTrue
        . $script:Helper
        Test-VersionPolicy '5.1.99999.1' ([pscustomobject]@{ mode = 'Exact'; value = '5.1' }) | Should -BeFalse
        Test-VersionPolicy '2.56.0.windows.3' ([pscustomobject]@{ mode = 'Exact'; value = '2.56.0' }) | Should -BeFalse
        Test-VersionPolicy '1.43.6+gc7c8d99' ([pscustomobject]@{ mode = 'Exact'; value = '1.43.6+gc7c8d99' }) | Should -BeTrue
        Get-ObservedVersion Git ([pscustomobject]@{ stdout = @('git version 2.56.0.windows.3') }) |
            Should -BeExactly '2.56.0.windows.3'
        Get-ObservedVersion PowerPlatformCli ([pscustomobject]@{ stdout = @('Microsoft PowerPlatform CLI', 'Version: 1.43.6+gc7c8d99') }) |
            Should -BeExactly '1.43.6+gc7c8d99'
        Get-ObservedVersion PowerPlatformCli ([pscustomobject]@{ stdout = @('Version: 1.43.6+gc7c8d99 (.NET 8.0.33)') }) |
            Should -BeExactly '1.43.6+gc7c8d99'
    }

    It 'rejects malformed or ambiguous version output instead of extracting any number' -ForEach @(
        @{ Id = 'Git'; Output = @('error 2.56.0') }
        @{ Id = 'Git'; Output = @('git version 2.56.0.windows.3', 'git version 2.55.0.windows.1') }
        @{ Id = 'AzureCli'; Output = @('not JSON 2.91.0') }
        @{ Id = 'PowerPlatformCli'; Output = @('Version: garbage') }
    ) {
        Test-Path -LiteralPath $script:Helper | Should -BeTrue
        . $script:Helper
        Get-ObservedVersion $Id ([pscustomobject]@{ stdout = $Output }) | Should -BeNullOrEmpty
    }

    It 'blocks multiple physical identities without probing either version' {
        Test-Path -LiteralPath $script:Entry | Should -BeTrue
        $one = Join-Path $TestDrive 'one.exe'
        $two = Join-Path $TestDrive 'two.exe'
        [IO.File]::WriteAllText($one, 'synthetic executable identity one')
        [IO.File]::WriteAllText($two, 'synthetic executable identity two')
        $result = & $script:Entry -CommandResolver {
            param($name)
            @((Join-Path $TestDrive 'one.exe'), (Join-Path $TestDrive 'two.exe'))
        } -NativeCommandRunner { throw 'No ambiguous executable may run.' }
        $result.status | Should -BeExactly 'Blocked'
        $result.policyAccepted | Should -BeFalse
    }

    It 'rejects an otherwise valid reviewed hash changed to a different full SHA-256' {
        $record = Read-CompatibilityFixture $script:Record
        $record.components[0].sha256 = '0' * 64
        $path = Join-Path $TestDrive 'hash-drift.json'
        $record | ConvertTo-Json -Depth 20 | Set-Content $path
        $result = & $script:Entry -CompatibilityPath $path -NativeCommandRunner {
            throw 'Changed executable hash must be refused before version probes.'
        }
        $result.status | Should -BeExactly 'Blocked'
        $result.policyAccepted | Should -BeFalse
    }

    It 'rejects missing or unknown principal payload pins rather than trusting a launcher hash alone' {
        . $script:Helper
        $record = Read-CompatibilityFixture $script:Record
        $azure = $record.components | Where-Object id -CEQ AzureCli
        $azure.PSObject.Properties.Remove('payloads')
        { Assert-WorkstationCompatibilityRecord $record } | Should -Throw
        $record = Read-CompatibilityFixture $script:Record
        ($record.components | Where-Object id -CEQ PowerPlatformCli).payloads[0].id = 'UnreviewedPayload'
        { Assert-WorkstationCompatibilityRecord $record } | Should -Throw
    }

    It 'rejects policy/record version disagreement without changing either input' {
        Test-Path -LiteralPath $script:Entry | Should -BeTrue
        $policy = Read-CompatibilityFixture $script:Policy
        $policy.tools[0].versionPolicy.value = '7.0.0'
        $path = Join-Path $TestDrive 'policy.json'
        $policy | ConvertTo-Json -Depth 20 | Set-Content $path
        $before = (Get-FileHash $path).Hash
        $result = & $script:Entry -PolicyPath $path -NativeCommandRunner { throw 'Must not probe.' }
        $result.status | Should -BeExactly 'Blocked'
        $result.policyAccepted | Should -BeFalse
        (Get-FileHash $path).Hash | Should -BeExactly $before
    }

    It 'refuses an automatic WinGet policy for a Store-only reviewed PowerShell host' {
        . $script:Helper
        $record = Read-CompatibilityFixture $script:Record
        $policy = Read-CompatibilityFixture $script:Policy
        $policy.tools[0].installDisposition = 'Automated'
        $policy.tools[0].install = [pscustomobject]@{
            kind = 'WinGet'; source = 'winget'; packageId = 'Microsoft.PowerShell'; scope = 'machine'
        }
        { Assert-WorkstationDeliveryPolicy $policy $record (
            Join-Path $script:Repo 'infra\src\config\schemas\workstation-prerequisites.schema.json') } | Should -Throw
    }

    It 'rejects empty source, missing payload and out-of-scope Code Apps before packing' -ForEach @(
        @{ Mutation = 'Empty' }
        @{ Mutation = 'MissingPayload' }
        @{ Mutation = 'CodeApp' }
        @{ Mutation = 'EmbeddedCodeApp' }
    ) {
        Test-Path -LiteralPath $script:Helper | Should -BeTrue
        . $script:Helper
        $root = Join-Path $TestDrive $Mutation
        New-Item -ItemType Directory -Path $root | Out-Null
        Copy-Item (Join-Path $script:Repo 'infra\tests\fixtures\workstation\*') $root -Recurse
        if ($Mutation -eq 'Empty') {
            [xml]$xml = Get-Content -Raw (Join-Path $root 'Other\Solution.xml')
            $xml.ImportExportXml.SolutionManifest.RootComponents.RemoveAll()
            $xml.Save((Join-Path $root 'Other\Solution.xml'))
        } elseif ($Mutation -eq 'MissingPayload') {
            Remove-Item (Join-Path $root 'WebResources\syn_probe.js')
        } elseif ($Mutation -eq 'EmbeddedCodeApp') {
            $path = Join-Path $root 'Other\Customizations.xml'
            [xml]$xml = Get-Content -Raw $path
            [void]$xml.DocumentElement.AppendChild($xml.CreateElement('CodeApp'))
            $xml.Save($path)
        } else {
            New-Item -ItemType Directory (Join-Path $root 'CanvasApps') | Out-Null
        }
        { Get-WorkstationComponentInventory $root } | Should -Throw
    }

    It 'requires nonzero PAC help diagnostics to match the known missing-zipfile usage contract' {
        Test-Path -LiteralPath $script:Helper | Should -BeTrue
        . $script:Helper
        Test-WorkstationPacHelp ([pscustomobject]@{
            exitCode = 1; stdout = @('Error: unknown argument', 'Usage: pac solution pack --zipfile --folder --packagetype')
        }) 'pack' | Should -BeFalse
        Test-WorkstationPacHelp ([pscustomobject]@{
            exitCode = 1; stdout = @('Error: A required argument --zipfile is missing.',
                'Usage: pac solution pack --zipfile --folder --packagetype')
        }) 'pack' | Should -BeTrue
    }

    It 'does not turn native exit zero without actual package contents into proof' {
        . $script:Helper
        $owned = Join-Path $TestDrive 'false-success'
        New-Item -ItemType Directory $owned | Out-Null
        {
            Invoke-WorkstationComponentProof 'synthetic-command' (
                Join-Path $script:Repo 'infra\tests\fixtures\workstation') $owned {
                param($file, $arguments)
                [pscustomobject]@{ exitCode = 0; stdout = @(); stderr = @() }
            }
        } | Should -Throw
    }

    It 'proves actual nonempty native pack/unpack preservation when the reviewed local PAC is installed' {
        . $script:Helper
        $pac = Join-Path $env:USERPROFILE '.dotnet\tools\pac.exe'
        if (-not (Test-Path $pac)) { Set-ItResult -Skipped -Because 'Optional native integration requires installed PAC; no installation is attempted.'; return }
        $owned = Join-Path $TestDrive 'native-proof'
        New-Item -ItemType Directory $owned | Out-Null
        $result = Invoke-WorkstationComponentProof $pac (
            Join-Path $script:Repo 'infra\tests\fixtures\workstation') $owned (New-DefaultNativeCommandRunner)
        $result.status | Should -BeExactly 'Proven'
        $result.declaredComponents | Should -Be 2
        $result.nativeOperations | Should -Be 4
        $result.payloadBytesPreserved | Should -BeTrue
    }

    It 'detects a missing payload even when the real native pack exits zero' {
        . $script:Helper
        $pac = Join-Path $env:USERPROFILE '.dotnet\tools\pac.exe'
        if (-not (Test-Path $pac)) { Set-ItResult -Skipped -Because 'Optional native integration requires installed PAC; no installation is attempted.'; return }
        $owned = Join-Path $TestDrive 'omitted-payload'
        New-Item -ItemType Directory $owned | Out-Null
        $native = New-DefaultNativeCommandRunner
        $runner = {
            param($file, $arguments)
            $result = & $native $file $arguments
            if ($arguments[1] -eq 'pack') {
                Add-Type -AssemblyName System.IO.Compression.FileSystem
                $zip = [IO.Compression.ZipFile]::Open($arguments[3], [IO.Compression.ZipArchiveMode]::Update)
                try {
                    $payload = @($zip.Entries | Where-Object { $_.FullName -match '^WebResources/syn_probejs' })[0]
                    $payload.Delete()
                } finally { $zip.Dispose() }
            }
            $result
        }.GetNewClosure()
        { Invoke-WorkstationComponentProof $pac (
            Join-Path $script:Repo 'infra\tests\fixtures\workstation') $owned $runner } | Should -Throw '*payload missing*'
    }

    It 'validates the closed compatibility schema and rejects an extra component field' {
        Test-Path -LiteralPath $script:Schema | Should -BeTrue
        $pwsh = 'pwsh.exe'
        & $pwsh -NoProfile -Command {
            param($record, $schema)
            if (-not (Test-Json -Json (Get-Content -Raw $record) -SchemaFile $schema)) { exit 1 }
        } -args $script:Record, $script:Schema
        $LASTEXITCODE | Should -Be 0
        $duplicate = Read-CompatibilityFixture $script:Record
        $duplicate.components[1].id = 'PowerShell7'
        $duplicatePath = Join-Path $TestDrive 'duplicate-component.json'
        $duplicate | ConvertTo-Json -Depth 20 | Set-Content $duplicatePath
        & $pwsh -NoProfile -Command {
            param($record, $schema)
            if (Test-Json -Json (Get-Content -Raw $record) -SchemaFile $schema -ErrorAction SilentlyContinue) { exit 1 }
        } -args $duplicatePath, $script:Schema
        $LASTEXITCODE | Should -Be 0
        $record = Read-CompatibilityFixture $script:Record
        $record.components[0] | Add-Member NoteProperty unreviewed $true
        $path = Join-Path $TestDrive 'unknown-field.json'
        $record | ConvertTo-Json -Depth 20 | Set-Content $path
        & $pwsh -NoProfile -Command {
            param($record, $schema)
            if (Test-Json -Json (Get-Content -Raw $record) -SchemaFile $schema -ErrorAction SilentlyContinue) { exit 1 }
        } -args $path, $script:Schema
        $LASTEXITCODE | Should -Be 0
    }
}
