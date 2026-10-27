function Test-TenantPrivateBackup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$IntentPath,
        [Parameter(Mandatory)][string]$StatePath,
        [Parameter(Mandatory)][string]$BackupManifestPath,
        [Parameter(Mandatory)][string]$RestoreRoot,
        [scriptblock]$DecryptAndReadRunner,
        [datetime]$NowUtc = [datetime]::UtcNow
    )

    $ErrorActionPreference = 'Stop'
    $result = [pscustomobject][ordered]@{
        classification = 'Blocked'
        reason = 'BackupDeclarationInvalid'
        encryptionDeclared = $false
        encryptionVerified = $false
        attendanceVerified = $false
        operatorAttestationRequired = $true
        declarationMetadataDigest = $null
        separateRoot = $false
        bytesChecked = $false
        intentEqual = $false
        stateEqual = $false
    }
    $handles = [Collections.Generic.List[IO.FileStream]]::new()
    $failure = 'BackupDeclarationInvalid'

    function Resolve-PrivateBackupPath {
        param([string]$Path, [switch]$File, [switch]$External)
        if ([string]::IsNullOrWhiteSpace($Path) -or
            [Management.Automation.WildcardPattern]::ContainsWildcardCharacters($Path) -or
            $Path -match '[\\/]\.([\\/]|$)') { throw 'Path' }
        $provider = $null
        $drive = $null
        $full = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path, [ref]$provider, [ref]$drive)
        if ($provider.Name -cne 'FileSystem' -or $full -notmatch '^[A-Za-z]:\\' -or
            $full.Substring(2).Contains(':')) { throw 'Path' }
        $full = [IO.Path]::GetFullPath($full).TrimEnd('\')
        $item = Get-Item -LiteralPath $full -Force -ErrorAction Stop
        if (($File -and $item -isnot [IO.FileInfo]) -or
            (-not $File -and $item -isnot [IO.DirectoryInfo])) { throw 'Type' }
        if ($File -and ($null -eq $item.PSObject.Properties['LinkType'] -or
            -not [string]::IsNullOrEmpty([string]$item.LinkType))) { throw 'Alias' }
        $cursor = $full
        while ($cursor) {
            $item = Get-Item -LiteralPath $cursor -Force -ErrorAction Stop
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or
                $item.FullName.TrimEnd('\') -ine $cursor.TrimEnd('\')) { throw 'Alias' }
            if ($External -and $item -is [IO.DirectoryInfo]) {
                $gitMarker = @(Test-Path -LiteralPath (Join-Path $cursor '.git') -ErrorAction Stop 2>&1)
                if ($gitMarker.Count -ne 1 -or $gitMarker[0] -isnot [bool] -or $gitMarker[0]) { throw 'Git' }
            }
            $parent = Split-Path -Parent $cursor
            if ($parent -eq $cursor) { break }
            $cursor = $parent
        }
        $full
    }

    function Read-PrivateBackupBytes {
        param([IO.FileStream]$Stream)
        $memory = [IO.MemoryStream]::new()
        try {
            $Stream.Position = 0
            $Stream.CopyTo($memory)
            return ,($memory.ToArray())
        } finally { $memory.Dispose() }
    }

    function Test-PrivateBackupBytesEqual {
        param([byte[]]$Left, [byte[]]$Right)
        if ($Left.Length -ne $Right.Length) { return $false }
        for ($i = 0; $i -lt $Left.Length; $i++) {
            if ($Left[$i] -ne $Right[$i]) { return $false }
        }
        $true
    }

    function Read-PrivateBackupTimestamp {
        param([object]$Value)
        Assert-TenantLifecycleString -Value $Value -Pattern '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]{1,7})?Z$'
        [datetime]::Parse($Value, [Globalization.CultureInfo]::InvariantCulture,
            [Globalization.DateTimeStyles]::AdjustToUniversal -bor [Globalization.DateTimeStyles]::AssumeUniversal)
    }

    try {
        # A declaration is checked before any private content is opened.
        $manifestPath = Resolve-PrivateBackupPath $BackupManifestPath -File -External
        $manifestHandle = [IO.File]::Open($manifestPath, 'Open', 'Read', 'Read')
        $handles.Add($manifestHandle)
        $failure = 'BackupDeclarationInvalid'
        $raw = [Text.UTF8Encoding]::new($false, $true).GetString((Read-PrivateBackupBytes $manifestHandle)).TrimStart([char]0xfeff)
        Assert-TenantLifecycleJsonHasUniqueProperties -Text $raw -RejectCaseAliases
        $declaration = ConvertFrom-TenantLifecycleJson -InputObject $raw
        Assert-TenantLifecycleProperties $declaration @('schemaVersion','publicTenantKey','createdAtUtc','encryptionProvider','containerLabel','intentEntry','stateEntry','restoreTest')
        Assert-TenantLifecycleString $declaration.schemaVersion '^1\.0$'
        Assert-TenantLifecycleString $declaration.publicTenantKey '^tenant[1-9][0-9]*$'
        foreach ($label in @($declaration.encryptionProvider, $declaration.containerLabel)) {
            Assert-TenantLifecycleString $label '^[A-Za-z][A-Za-z0-9_-]{0,63}$'
        }
        Assert-TenantLifecycleCondition ($declaration.encryptionProvider -notmatch '^(Plaintext|None|Unencrypted)$')
        foreach ($name in @('intent','state')) {
            $entry = $declaration.($name + 'Entry')
            Assert-TenantLifecycleProperties $entry @('logicalName','included','encrypted')
            Assert-TenantLifecycleCondition ($entry.logicalName -is [string] -and $entry.logicalName -ceq $name)
            foreach ($flag in @('included','encrypted')) {
                Assert-TenantLifecycleCondition ($entry.$flag -is [bool] -and $entry.$flag)
            }
        }
        $restore = $declaration.restoreTest
        Assert-TenantLifecycleProperties $restore @('testedAtUtc','separateRoot','intentEqual','stateEqual','result')
        foreach ($flag in @('separateRoot','intentEqual','stateEqual')) {
            Assert-TenantLifecycleCondition ($restore.$flag -is [bool] -and $restore.$flag)
        }
        Assert-TenantLifecycleCondition ($restore.result -is [string] -and $restore.result -ceq 'Passed')
        $created = Read-PrivateBackupTimestamp $declaration.createdAtUtc
        $tested = Read-PrivateBackupTimestamp $restore.testedAtUtc
        Assert-TenantLifecycleCondition ($created -le $tested -and $tested -le $NowUtc.ToUniversalTime())
        $intentName = Split-Path -Leaf $IntentPath
        Assert-TenantLifecycleCondition ($intentName -cmatch '^(tenant[1-9][0-9]*)\.local\.psd1$')
        Assert-TenantLifecycleCondition ($declaration.publicTenantKey -ceq $Matches[1])
        $result.encryptionDeclared = $true
        $result.declarationMetadataDigest = Get-RunbookContentDigest -InputObject $declaration

        $failure = 'BackupBoundaryInvalid'
        $intent = Resolve-PrivateBackupPath $IntentPath -File
        $state = Resolve-PrivateBackupPath $StatePath -File
        $tenantDirectory = Split-Path -Parent $intent
        $repo = $tenantDirectory
        foreach ($part in @('tenants','config','src','infra')) {
            if ((Split-Path -Leaf $repo) -cne $part) { throw 'Source' }
            $repo = Split-Path -Parent $repo
        }
        if ($state -ine (Join-Path $tenantDirectory ($declaration.publicTenantKey + '.state.local.json'))) { throw 'Source' }
        $restored = Resolve-PrivateBackupPath $RestoreRoot -External
        $backupRoot = Split-Path -Parent $manifestPath
        foreach ($external in @($restored, $backupRoot)) {
            if ((Test-RunbookPathWithin $external $repo) -or (Test-RunbookPathWithin $repo $external)) { throw 'Source' }
        }
        if ((Test-RunbookPathWithin $restored $backupRoot) -or (Test-RunbookPathWithin $backupRoot $restored)) { throw 'Overlap' }
        $restoredIntent = Resolve-PrivateBackupPath (Join-Path $restored $declaration.intentEntry.logicalName) -File -External
        $restoredState = Resolve-PrivateBackupPath (Join-Path $restored $declaration.stateEntry.logicalName) -File -External
        $result.separateRoot = $true
        $failure = 'BackupInputStale'
        foreach ($path in @($intent, $state)) {
            if ([IO.File]::GetLastWriteTimeUtc($path) -gt $created) { throw 'Stale' }
        }

        $failure = 'RestoreReadFailed'
        $files = @($intent, $state, $restoredIntent, $restoredState)
        $bytes = @{}
        $timestamps = @{}
        foreach ($path in $files) {
            $handle = [IO.File]::Open($path, 'Open', 'Read', 'Read')
            $handles.Add($handle)
            $timestamps[$path] = [IO.File]::GetLastWriteTimeUtc($path)
            $bytes[$path] = Read-PrivateBackupBytes $handle
        }
        # The frozen parameter name does not authorize decryption. Readers may only
        # return existing restored bytes; independent held-handle reads bind them.
        if ($null -eq $DecryptAndReadRunner) {
            $DecryptAndReadRunner = { param($Path) return ,([IO.File]::ReadAllBytes($Path)) }
        }
        $failure = 'RestoreReaderInvalid'
        $ProgressPreference = 'SilentlyContinue'
        foreach ($path in @($restoredIntent, $restoredState)) {
            $read = @(& $DecryptAndReadRunner $path 2>&1 3>&1 4>&1 5>&1 6>&1)
            if ($read.Count -ne 1 -or $read[0] -isnot [byte[]] -or
                -not (Test-PrivateBackupBytesEqual $bytes[$path] $read[0])) { throw 'Reader' }
        }
        $failure = 'BackupInputDrift'
        foreach ($path in $files) {
            if ([IO.File]::GetLastWriteTimeUtc($path) -ne $timestamps[$path]) { throw 'Drift' }
        }
        $result.bytesChecked = $true
        $result.intentEqual = Test-PrivateBackupBytesEqual $bytes[$intent] $bytes[$restoredIntent]
        $result.stateEqual = Test-PrivateBackupBytesEqual $bytes[$state] $bytes[$restoredState]
        if ($result.intentEqual -and $result.stateEqual) {
            $result.classification = 'NoChange'
            $result.reason = 'OperatorAttestationRequired'
        } else { $result.reason = 'RestoreBytesUnequal' }
    } catch {
        $result.reason = $failure
        $result.bytesChecked = $false
        $result.intentEqual = $false
        $result.stateEqual = $false
    } finally {
        foreach ($handle in $handles) { $handle.Dispose() }
    }
    $result
}
