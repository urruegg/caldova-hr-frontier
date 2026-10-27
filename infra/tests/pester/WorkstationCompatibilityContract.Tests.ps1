Describe 'Canonical workstation compatibility producer contract' {
    BeforeAll {
        $script:Repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
        $script:RecordPath = Join-Path $script:Repo 'infra\src\config\runbooks\workstation-compatibility.json'
        $script:SchemaPath = Join-Path $script:Repo 'infra\src\config\schemas\workstation-compatibility.schema.json'
        $script:Entry = Join-Path $script:Repo 'infra\src\scripts\runbooks\Test-DeveloperWorkstationCompatibility.ps1'
        . (Join-Path $script:Repo 'infra\src\scripts\runbooks\WorkstationTools.ps1')
        function script:Read-CanonicalFixture {
            $parameters = @{ InputObject = [IO.File]::ReadAllText($script:RecordPath) }
            if ((Get-Command ConvertFrom-Json).Parameters.ContainsKey('DateKind')) { $parameters.DateKind = 'String' }
            ConvertFrom-Json @parameters
        }
        function script:Set-CanonicalFixtureDigest {
            param([object]$Record)
            $projection = [ordered]@{}
            foreach ($property in $Record.PSObject.Properties) {
                if ($property.Name -cne 'digest') { $projection[$property.Name] = $property.Value }
            }
            $digest = & (Get-WorkstationBootstrapModule) {
                param($value) Get-RunbookContentDigest -InputObject $value
            } ([pscustomobject]$projection)
            $Record | Add-Member NoteProperty digest $digest -Force
        }
    }

    It 'publishes exactly the planned five root fields and eight component fields' {
        $record = Read-CanonicalFixture
        ($record.PSObject.Properties.Name | Sort-Object) -join '|' |
            Should -BeExactly 'components|digest|reviewedAtUtc|reviewedByRole|schemaVersion'
        foreach ($component in $record.components) {
            ($component.PSObject.Properties.Name | Sort-Object) -join '|' |
                Should -BeExactly 'architecture|capabilityChecks|exactVersions|firstPartyReferences|host|id|installationSource|versionCommand'
            ($component.exactVersions -is [array]) | Should -BeTrue
            $component.exactVersions.Count | Should -Be 1
            $component.host.platform | Should -BeExactly 'Windows'
            $component.host.readinessScope | Should -BeExactly 'ToolCompatibilityOnly'
        }
        $record.reviewedByRole | Should -BeExactly 'AutomatedTechnicalReview: GitHub Copilot'
    }

    It 'stores the shared canonical digest excluding only its own digest field' {
        $record = Read-CanonicalFixture
        $record.PSObject.Properties.Name | Should -Contain 'digest'
        $expected = $record.digest
        Set-CanonicalFixtureDigest $record
        $record.digest | Should -BeExactly $expected
        $record.digest | Should -Match '^[0-9a-f]{64}$'
        { Assert-WorkstationCompatibilityRecord $record } | Should -Not -Throw
    }

    It 'validates the canonical producer schema and rejects the former public format' {
        $record = Read-CanonicalFixture
        $record.PSObject.Properties.Name | Should -Contain 'digest'
        $path = Join-Path $TestDrive 'legacy.json'
        $legacy = [pscustomobject]@{
            '$schema' = '../schemas/workstation-compatibility.schema.json'
            schemaVersion = '1.0'
            review = [pscustomobject]@{
                kind = 'AutomatedTechnicalReview'; reviewer = 'GitHub Copilot'
                reviewedAtUtc = $record.reviewedAtUtc; isApproval = $false; scope = 'Local compatibility'
            }
            components = $record.components
        }
        [IO.File]::WriteAllText($path, (ConvertTo-Json -InputObject $legacy -Depth 30))
        & pwsh.exe -NoProfile -Command {
            param($valid, $invalid, $schema)
            if (-not (Test-Json -Json ([IO.File]::ReadAllText($valid)) -SchemaFile $schema)) { exit 1 }
            if (Test-Json -Json ([IO.File]::ReadAllText($invalid)) -SchemaFile $schema -ErrorAction SilentlyContinue) { exit 2 }
        } -args $script:RecordPath, $path, $script:SchemaPath
        $LASTEXITCODE | Should -Be 0
    }

    It 'rejects missing/mismatched digest, tamper and invalid canonical types before callbacks' -ForEach @(
        @{ Mutation = 'MissingDigest' }
        @{ Mutation = 'WrongDigest' }
        @{ Mutation = 'TamperedWithoutDigest' }
        @{ Mutation = 'UnknownRoot' }
        @{ Mutation = 'UnknownComponent' }
        @{ Mutation = 'ScalarVersions' }
        @{ Mutation = 'MultipleVersions' }
        @{ Mutation = 'ScalarCapabilities' }
        @{ Mutation = 'ScalarReferences' }
        @{ Mutation = 'WrongHost' }
        @{ Mutation = 'ArbitraryCommand' }
        @{ Mutation = 'UnsupportedSource' }
        @{ Mutation = 'InvalidPayloadPin' }
        @{ Mutation = 'FormerFormat' }
    ) {
        $record = Read-CanonicalFixture
        switch ($Mutation) {
            'MissingDigest' { $record.PSObject.Properties.Remove('digest') }
            'WrongDigest' { $record | Add-Member NoteProperty digest ('0' * 64) -Force }
            'TamperedWithoutDigest' { $record.components[0].architecture = 'Arm64' }
            'UnknownRoot' { $record | Add-Member NoteProperty unreviewed $true; Set-CanonicalFixtureDigest $record }
            'UnknownComponent' { $record.components[0] | Add-Member NoteProperty unreviewed $true; Set-CanonicalFixtureDigest $record }
            'ScalarVersions' { $record.components[0] | Add-Member NoteProperty exactVersions '7.6.8' -Force; Set-CanonicalFixtureDigest $record }
            'MultipleVersions' { $record.components[0] | Add-Member NoteProperty exactVersions @('7.6.8', '7.6.7') -Force; Set-CanonicalFixtureDigest $record }
            'ScalarCapabilities' { $record.components[2] | Add-Member NoteProperty capabilityChecks 'WorktreeHelp' -Force; Set-CanonicalFixtureDigest $record }
            'ScalarReferences' { $record.components[2] | Add-Member NoteProperty firstPartyReferences 'https://github.com/git-for-windows/git/releases/tag/v2.56.0.windows.3' -Force; Set-CanonicalFixtureDigest $record }
            'WrongHost' { $record.components[0] | Add-Member NoteProperty host ([pscustomobject]@{
                platform = 'Linux'; minimumBuild = 22000; readinessScope = 'ToolCompatibilityOnly'
            }) -Force; Set-CanonicalFixtureDigest $record }
            'ArbitraryCommand' { $record.components[2] | Add-Member NoteProperty versionCommand ([pscustomobject]@{
                command = 'powershell.exe'; probe = 'UnreviewedScript'
            }) -Force; Set-CanonicalFixtureDigest $record }
            'UnsupportedSource' { $record.components[2].installationSource.kind = 'Unreviewed'; Set-CanonicalFixtureDigest $record }
            'InvalidPayloadPin' {
                $record.components[8].installationSource.installations[0].files[0].sha256 = 'unproven'
                Set-CanonicalFixtureDigest $record
            }
            'FormerFormat' {
                if ($record.PSObject.Properties.Name -contains 'digest') {
                    $record = [pscustomobject]@{
                        '$schema' = '../schemas/workstation-compatibility.schema.json'
                        schemaVersion = '1.0'
                        review = [pscustomobject]@{
                            kind = 'AutomatedTechnicalReview'; reviewer = 'GitHub Copilot'
                            reviewedAtUtc = $record.reviewedAtUtc; isApproval = $false; scope = 'Local compatibility'
                        }
                        components = $record.components
                    }
                }
            }
        }
        $path = Join-Path $TestDrive ($Mutation + '.json')
        [IO.File]::WriteAllText($path, (ConvertTo-Json -InputObject $record -Depth 30))
        $calls = [Collections.Generic.List[string]]::new()
        $result = & $script:Entry -CompatibilityPath $path -CommandResolver {
            param($name) $calls.Add('resolver'); throw 'Contract must be checked before resolution.'
        }.GetNewClosure() -NativeCommandRunner {
            param($file, $arguments) $calls.Add('native'); throw 'Contract must be checked before execution.'
        }.GetNewClosure()
        $result.status | Should -BeExactly 'Blocked'
        $result.policyAccepted | Should -BeFalse
        $calls.Count | Should -Be 0
    }
}
