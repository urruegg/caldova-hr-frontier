Set-StrictMode -Version Latest

Describe 'Tenant private backup and restore' {
    BeforeAll {
        Import-Module (Join-Path $PSScriptRoot '..\..\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1') -Force
        . (Join-Path $PSScriptRoot '..\fixtures\runbooks\PrivateBackupTestSupport.ps1')
        $script:BackupSchema = Join-Path $PSScriptRoot '..\..\src\config\schemas\private-backup-manifest.schema.json'
        function New-BackupFixture {
            $context = Join-Path $TestDrive ([guid]::NewGuid().ToString('N').Substring(0,6))
            $parameters = @{
                IntentPath = Join-Path $context 'repo\infra\src\config\tenants\tenant1.local.psd1'
                StatePath = Join-Path $context 'repo\infra\src\config\tenants\tenant1.state.local.json'
                BackupManifestPath = Join-Path $context 'backup\manifest.json'
                RestoreRoot = Join-Path $context 'restored'
                NowUtc = [datetime]'2026-10-02T12:15:00Z'
            }
            Write-SyntheticPrivateBackupPair -IntentPath $parameters.IntentPath -StatePath $parameters.StatePath `
                -ManifestPath $parameters.BackupManifestPath -RestoreRoot $parameters.RestoreRoot
            [pscustomobject]@{ p = $parameters; context = $context }
        }
        function Set-BackupDeclaration {
            param($Fixture, [scriptblock]$Change)
            $value = Get-Content -Raw -LiteralPath $Fixture.p.BackupManifestPath | ConvertFrom-Json
            & $Change $value
            [IO.File]::WriteAllText($Fixture.p.BackupManifestPath, ($value | ConvertTo-Json -Depth 10))
        }
        function Assert-SafeBackupProjection {
            param($Value, $Fixture)
            $json = $Value | ConvertTo-Json -Depth 30
            $json | Should -Not -Match ([regex]::Escape($Fixture.context))
            $json | Should -Not -Match 'Synthetic Private Marker|example[.]invalid|synthetic123|11111111-|100001'
            $json | Should -Not -Match '(?i)digest|sha256|[0-9a-f]{64}|intentPath|restoreRoot|containerLabel'
        }
    }

    It 'exports the reader gate with no mutation-capable default' {
        $f = New-BackupFixture
        $p = $f.p
        $r = Test-TenantPrivateBackup @p
        $r.classification | Should -BeExactly 'Blocked'
        $r.reason | Should -BeExactly 'EncryptionAndAttendanceVerifierMissing'
        $r.encryptionDeclared | Should -BeTrue
        $r.encryptionVerified | Should -BeFalse
        $r.attendanceVerified | Should -BeFalse
        $r.intentEqual | Should -BeTrue
        $r.stateEqual | Should -BeTrue
        $r.bytesChecked | Should -BeTrue
        Assert-SafeBackupProjection $r $f
    }

    It 'publishes a closed manifest schema at every object boundary' {
        $s = Get-Content -Raw -LiteralPath $script:BackupSchema | ConvertFrom-Json
        $s.additionalProperties | Should -BeFalse
        $s.required | Should -Be @('schemaVersion','publicTenantKey','createdAtUtc','encryptionProvider','containerLabel','intentEntry','stateEntry','restoreTest')
        $s.properties.intentEntry.additionalProperties | Should -BeFalse
        $s.properties.stateEntry.additionalProperties | Should -BeFalse
        $s.properties.restoreTest.additionalProperties | Should -BeFalse
    }

    It 'blocks invalid <Case> declarations before opening locked private files or calling the reader' -ForEach @(
        @{Case='MissingManifest'}; @{Case='ExtraRoot'}; @{Case='ExtraEntry'}; @{Case='ExtraRestore'}
        @{Case='MissingEntry'}; @{Case='WrongTenant'}; @{Case='Plaintext'}; @{Case='NotIncluded'}
        @{Case='BooleanString'}; @{Case='VersionNumber'}; @{Case='NullEntry'}; @{Case='ArrayRoot'}
        @{Case='DuplicateRoot'}; @{Case='DuplicateEntry'}; @{Case='CaseAlias'}; @{Case='WrongCase'}; @{Case='EscapedDuplicate'}
        @{Case='TraversalEntry'}; @{Case='PathProvider'}; @{Case='Failed'}; @{Case='NotSeparate'}
        @{Case='DeclaredUnequal'}; @{Case='Stale'}; @{Case='Future'}; @{Case='ReverseTime'}
        @{Case='InvalidDate'}; @{Case='OffsetDate'}
    ) {
        $f = New-BackupFixture; $p = $f.p
        switch ($Case) {
            MissingManifest { Remove-Item -LiteralPath $p.BackupManifestPath }
            ExtraRoot { Set-BackupDeclaration $f { param($v) $v | Add-Member NoteProperty secret 'synthetic-secret' } }
            ExtraEntry { Set-BackupDeclaration $f { param($v) $v.intentEntry | Add-Member NoteProperty path 'synthetic-secret' } }
            ExtraRestore { Set-BackupDeclaration $f { param($v) $v.restoreTest | Add-Member NoteProperty attended $true } }
            MissingEntry { Set-BackupDeclaration $f { param($v) $v.PSObject.Properties.Remove('stateEntry') } }
            WrongTenant { Set-BackupDeclaration $f { param($v) $v.publicTenantKey = 'tenant2' } }
            Plaintext { Set-BackupDeclaration $f { param($v) $v.stateEntry.encrypted = $false } }
            NotIncluded { Set-BackupDeclaration $f { param($v) $v.intentEntry.included = $false } }
            BooleanString { Set-BackupDeclaration $f { param($v) $v.intentEntry.encrypted = 'true' } }
            VersionNumber { Set-BackupDeclaration $f { param($v) $v.schemaVersion = 1 } }
            NullEntry { Set-BackupDeclaration $f { param($v) $v.intentEntry = $null } }
            ArrayRoot { [IO.File]::WriteAllText($p.BackupManifestPath, '[]') }
            DuplicateRoot { $raw = [IO.File]::ReadAllText($p.BackupManifestPath); [IO.File]::WriteAllText($p.BackupManifestPath, $raw.Replace('"schemaVersion": "1.0"', '"schemaVersion": "1.0", "schemaVersion": "1.0"')) }
            DuplicateEntry { $raw = [IO.File]::ReadAllText($p.BackupManifestPath); [IO.File]::WriteAllText($p.BackupManifestPath, $raw.Replace('"encrypted": true', '"encrypted": true, "encrypted": true')) }
            CaseAlias { $raw = [IO.File]::ReadAllText($p.BackupManifestPath); [IO.File]::WriteAllText($p.BackupManifestPath, $raw.Replace('"encrypted": true', '"encrypted": true, "Encrypted": true')) }
            WrongCase { $raw = [IO.File]::ReadAllText($p.BackupManifestPath); [IO.File]::WriteAllText($p.BackupManifestPath, $raw.Replace('"encrypted"', '"Encrypted"')) }
            EscapedDuplicate { $raw = [IO.File]::ReadAllText($p.BackupManifestPath); [IO.File]::WriteAllText($p.BackupManifestPath, $raw.Replace('"encrypted": true', '"encrypted": true, "\u0065ncrypted": true')) }
            TraversalEntry { Set-BackupDeclaration $f { param($v) $v.intentEntry.logicalName = '..\intent' } }
            PathProvider { Set-BackupDeclaration $f { param($v) $v.encryptionProvider = 'C:\synthetic-private' } }
            Failed { Set-BackupDeclaration $f { param($v) $v.restoreTest.result = 'Failed' } }
            NotSeparate { Set-BackupDeclaration $f { param($v) $v.restoreTest.separateRoot = $false } }
            DeclaredUnequal { Set-BackupDeclaration $f { param($v) $v.restoreTest.stateEqual = $false } }
            Stale { Set-BackupDeclaration $f { param($v) $v.restoreTest.testedAtUtc = '2026-10-02T11:00:00Z' } }
            Future { Set-BackupDeclaration $f { param($v) $v.restoreTest.testedAtUtc = '2026-10-02T13:00:00Z' } }
            ReverseTime { Set-BackupDeclaration $f { param($v) $v.createdAtUtc = '2026-10-02T12:12:00Z' } }
            InvalidDate { Set-BackupDeclaration $f { param($v) $v.createdAtUtc = '2026-02-30T12:00:00Z' } }
            OffsetDate { Set-BackupDeclaration $f { param($v) $v.createdAtUtc = '2026-10-02T12:00:00+01:00' } }
        }
        $p.DecryptAndReadRunner = { throw 'READER-MUST-NOT-RUN synthetic-secret' }
        $lock = [IO.File]::Open($p.IntentPath, 'Open', 'ReadWrite', 'None')
        try { $r = Test-TenantPrivateBackup @p } finally { $lock.Dispose() }
        $r.classification | Should -BeExactly 'Blocked'
        $r.reason | Should -BeExactly 'BackupDeclarationInvalid'
        $r.bytesChecked | Should -BeFalse
        Assert-SafeBackupProjection $r $f
    }

    It 'rejects unsafe <Case> paths without following aliases' -ForEach @(
        @{Case='SourceRoot'}; @{Case='InsideSource'}; @{Case='InsideGit'}; @{Case='BackupRoot'}
        @{Case='MissingRestore'}; @{Case='MissingRestoredEntry'}; @{Case='Alias'}
        @{Case='SourceAlias'}; @{Case='ManifestInsideGit'}; @{Case='AlternateStream'}; @{Case='HardLinkRestore'}
    ) {
        $f = New-BackupFixture; $p = $f.p
        switch ($Case) {
            SourceRoot { $p.RestoreRoot = Split-Path $p.IntentPath }
            InsideSource { $p.RestoreRoot = Join-Path $f.context 'repo\restored' }
            InsideGit { New-Item -ItemType Directory -Path (Join-Path $p.RestoreRoot '.git') | Out-Null }
            BackupRoot { $p.RestoreRoot = Split-Path $p.BackupManifestPath }
            MissingRestore { $p.RestoreRoot = Join-Path $f.context 'missing' }
            MissingRestoredEntry { Remove-Item -LiteralPath (Join-Path $p.RestoreRoot 'state') }
            Alias {
                $alias = Join-Path $f.context 'alias'
                New-Item -ItemType Junction -Path $alias -Target $p.RestoreRoot | Out-Null
                $p.RestoreRoot = $alias
            }
            SourceAlias { $p.IntentPath = (Split-Path $p.IntentPath) + '\.\tenant1.local.psd1' }
            ManifestInsideGit { New-Item -ItemType File -Path (Join-Path (Split-Path $p.BackupManifestPath) '.git') | Out-Null }
            AlternateStream { $p.RestoreRoot += ':stream' }
            HardLinkRestore {
                $entry = Join-Path $p.RestoreRoot 'intent'
                Remove-Item -LiteralPath $entry
                New-Item -ItemType HardLink -Path $entry -Target $p.IntentPath | Out-Null
            }
        }
        try {
            $r = Test-TenantPrivateBackup @p
            $r.classification | Should -BeExactly 'Blocked'
            $r.bytesChecked | Should -BeFalse
            Assert-SafeBackupProjection $r $f
        } finally {
            if ($Case -eq 'Alias') { [IO.Directory]::Delete($alias) }
        }
    }

    It 'compares actual bytes rather than trusting <Case> reader assertions' -ForEach @(
        @{Case='Equal'}; @{Case='UnequalIntent'}; @{Case='UnequalState'}; @{Case='ForgedReader'}
        @{Case='BooleanReader'}; @{Case='ThrowingReader'}; @{Case='NoisyReader'}; @{Case='InputDrift'}
        @{Case='RestoreMutation'}; @{Case='ManifestMutation'}
        @{Case='StaleSource'}; @{Case='LockedSource'}; @{Case='LockedRestore'}; @{Case='LockedManifest'}
    ) {
        $f = New-BackupFixture; $p = $f.p
        $lock = $null
        switch ($Case) {
            UnequalIntent { [IO.File]::AppendAllText((Join-Path $p.RestoreRoot 'intent'), ' ') }
            UnequalState { [IO.File]::AppendAllText((Join-Path $p.RestoreRoot 'state'), ' ') }
            ForgedReader {
                [IO.File]::AppendAllText((Join-Path $p.RestoreRoot 'intent'), ' ')
                $source = $p.IntentPath
                $p.DecryptAndReadRunner = { param($path) if ((Split-Path -Leaf $path) -eq 'intent') { return ,([IO.File]::ReadAllBytes($source)) }; return ,([IO.File]::ReadAllBytes($path)) }.GetNewClosure()
            }
            BooleanReader { $p.DecryptAndReadRunner = { [pscustomobject]@{ intentEqual=$true; stateEqual=$true; encrypted=$true } } }
            ThrowingReader { $p.DecryptAndReadRunner = { throw 'Synthetic Private Marker secret path' } }
            NoisyReader { $p.DecryptAndReadRunner = { param($path) Write-Warning 'Synthetic Private Marker'; return ,([IO.File]::ReadAllBytes($path)) } }
            InputDrift {
                $source = $p.IntentPath
                $p.DecryptAndReadRunner = { param($path) [IO.File]::AppendAllText($source, 'drift'); return ,([IO.File]::ReadAllBytes($path)) }.GetNewClosure()
            }
            RestoreMutation { $p.DecryptAndReadRunner = { param($path) [IO.File]::AppendAllText($path, 'drift'); return ,([IO.File]::ReadAllBytes($path)) } }
            ManifestMutation {
                $manifest = $p.BackupManifestPath
                $p.DecryptAndReadRunner = { param($path) [IO.File]::AppendAllText($manifest, 'drift'); return ,([IO.File]::ReadAllBytes($path)) }.GetNewClosure()
            }
            StaleSource { [IO.File]::SetLastWriteTimeUtc($p.IntentPath, [datetime]'2026-10-02T12:11:00Z') }
            LockedSource { $lock = [IO.File]::Open($p.IntentPath, 'Open', 'ReadWrite', 'None') }
            LockedRestore { $lock = [IO.File]::Open((Join-Path $p.RestoreRoot 'state'), 'Open', 'ReadWrite', 'None') }
            LockedManifest { $lock = [IO.File]::Open($p.BackupManifestPath, 'Open', 'ReadWrite', 'None') }
        }
        try { $all = @(Test-TenantPrivateBackup @p *>&1) } finally { if ($null -ne $lock) { $lock.Dispose() } }
        $all.Count | Should -Be 1
        $r = $all[0]
        $r.classification | Should -BeExactly 'Blocked'
        if ($Case -eq 'Equal') {
            $r.intentEqual | Should -BeTrue
            $r.stateEqual | Should -BeTrue
        } else {
            ($r.intentEqual -and $r.stateEqual) | Should -BeFalse
            $r.reason | Should -Not -BeExactly 'EncryptionAndAttendanceVerifierMissing'
        }
        Assert-SafeBackupProjection $r $f
        if ($Case -in @('InputDrift','RestoreMutation','ManifestMutation')) {
            [IO.File]::ReadAllText($p.IntentPath) | Should -Not -Match 'drift'
            [IO.File]::ReadAllText((Join-Path $p.RestoreRoot 'intent')) | Should -Not -Match 'drift'
            [IO.File]::ReadAllText($p.BackupManifestPath) | Should -Not -Match 'drift'
        }
    }

    It 'reads only declared restored entries and leaves all file bytes and timestamps unchanged' {
        $f = New-BackupFixture; $p = $f.p
        $files = @($p.IntentPath, $p.StatePath, $p.BackupManifestPath, (Join-Path $p.RestoreRoot 'intent'), (Join-Path $p.RestoreRoot 'state'))
        $before = @{}
        foreach ($file in $files) { $before[$file] = @([Convert]::ToBase64String([IO.File]::ReadAllBytes($file)), [IO.File]::GetLastWriteTimeUtc($file)) }
        $seen = [Collections.Generic.List[string]]::new()
        $p.DecryptAndReadRunner = { param($path) $seen.Add($path); return ,([IO.File]::ReadAllBytes($path)) }.GetNewClosure()
        $r = Test-TenantPrivateBackup @p
        $r.intentEqual | Should -BeTrue
        $r.stateEqual | Should -BeTrue
        $seen.ToArray() | Should -Be @((Join-Path $p.RestoreRoot 'intent'), (Join-Path $p.RestoreRoot 'state'))
        foreach ($file in $files) {
            [Convert]::ToBase64String([IO.File]::ReadAllBytes($file)) | Should -BeExactly $before[$file][0]
            [IO.File]::GetLastWriteTimeUtc($file) | Should -Be $before[$file][1]
        }
    }

    It 'sanitizes nonterminating filesystem errors even when the caller uses Continue' {
        $f = New-BackupFixture; $p = $f.p
        Mock Test-Path {
            Write-Error 'Synthetic Private Marker filesystem access denied'
            $false
        } -ModuleName Caldova.HrFrontier.Bootstrap -ParameterFilter { $LiteralPath -like '*\.git' }
        $previous = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'Continue'
            $all = @(Test-TenantPrivateBackup @p *>&1)
        } finally { $ErrorActionPreference = $previous }
        $all.Count | Should -Be 1
        $all[0].classification | Should -BeExactly 'Blocked'
        Assert-SafeBackupProjection $all[0] $f
    }
}
