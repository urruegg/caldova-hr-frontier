function Assert-RepositoryExportTree {
    param([Parameter(Mandatory)][string]$Root)
    Assert-RepositoryExportLocalPath -Path $Root
    $pending = [Collections.Generic.Queue[string]]::new()
    $pending.Enqueue($Root)
    while ($pending.Count -gt 0) {
        foreach ($item in Get-ChildItem -LiteralPath $pending.Dequeue() -Force) {
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw 'Repository export tree contains a reparse point.'
            }
            if ($null -ne $item.PSObject.Properties['LinkType'] -and
                -not [string]::IsNullOrWhiteSpace([string]$item.LinkType)) {
                throw 'Repository export tree contains a linked item.'
            }
            if ($item.Name -ieq '.git') { throw 'Repository export tree contains Git metadata.' }
            if ($item.PSIsContainer) { $pending.Enqueue($item.FullName) }
        }
    }
}

function Get-RepositoryExportVerifiedTreeDigest {
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][object]$Assessment)
    Assert-RepositoryExportTree -Root $Root
    $files = @(Get-ChildItem -LiteralPath $Root -Recurse -File -Force)
    if ($files.Count -ne @($Assessment.copyFiles).Count) { throw 'Repository export validation changed the inventory.' }
    $expectedFiles = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($path in $Assessment.copyFiles) { [void]$expectedFiles.Add($path) }
    foreach ($file in $files) {
        if (-not $expectedFiles.Contains((Get-RunbookRelativePath -Root $Root -Path $file.FullName))) {
            throw 'Repository export validation changed the path inventory.'
        }
    }
    $tree = [ordered]@{}
    $directories = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($path in $Assessment.copyFiles) {
        $target = Join-Path $Root $path.Replace('/', '\')
        $directory = Split-Path $target -Parent
        while ($directory -cne $Root) {
            [void]$directories.Add($directory)
            $directory = Split-Path $directory -Parent
        }
        if (-not (Test-Path -LiteralPath $target -PathType Leaf) -or
            (Get-CustomerExportFileDigest -Path $target) -cne [string]$Assessment.fileDigests.$path.expectedOutputSha256) {
            throw 'Repository export validation changed expected bytes.'
        }
        $tree[$path] = $Assessment.fileDigests.$path.expectedOutputSha256
    }
    foreach ($directory in Get-ChildItem -LiteralPath $Root -Recurse -Directory -Force) {
        if (-not $directories.Contains($directory.FullName)) { throw 'Repository export validation changed the directory inventory.' }
    }
    Get-RunbookContentDigest $tree
}

function Get-RepositoryExportVerifiedSourceSnapshot {
    param(
        [string]$SourceRoot, [object]$Git, [scriptblock]$NativeCommandRunner,
        [scriptblock]$GitBlobReader, [string]$SnapshotDigest, [hashtable]$ExecutionState
    )
    $ExecutionState.sourceVerification = 'Unavailable'
    $snapshot = Get-CustomerExportSourceSnapshot -RepositoryRoot $SourceRoot -GitExecutable $Git `
        -NativeCommandRunner $NativeCommandRunner -GitBlobReader $GitBlobReader
    if ($SnapshotDigest -cne (Get-RunbookContentDigest $snapshot)) {
        $ExecutionState.sourceVerification = 'Mismatch'
        throw 'Source snapshot changed during export; any promoted destination is unaccepted and requires human review.'
    }
    $ExecutionState.sourceVerification = 'Matched'
    $snapshot
}

function Get-RepositoryExportCopyFinalContext {
    param([Parameter(Mandatory)][hashtable]$ExecutionState, [switch]$Failed)
    $allowed = @{
        executionPhase = @('NotStarted', 'BeforeStaging', 'Staging', 'BeforePromotion', 'AfterPromotion')
        sourceVerification = @('NotChecked', 'Matched', 'Mismatch', 'Unavailable')
        destinationDisposition = @('NotCreated', 'UnacceptedRequiresReview', 'PromotedPendingIndependent')
    }
    foreach ($field in $allowed.Keys) {
        if ($ExecutionState[$field] -isnot [string] -or $ExecutionState[$field] -cnotin $allowed[$field]) {
            throw 'Repository export provenance is invalid.'
        }
    }
    if (-not $Failed -and ($ExecutionState.executionPhase -cne 'AfterPromotion' -or
        $ExecutionState.sourceVerification -cne 'Matched' -or
        $ExecutionState.destinationDisposition -cne 'PromotedPendingIndependent')) {
        throw 'Repository export completion provenance is unverified.'
    }
    $promoted = $ExecutionState.destinationDisposition -cne 'NotCreated'
    [pscustomobject]@{
        status = if ($Failed) { if ($promoted) { 'PromotedUnaccepted' } else { 'ExportFailed' } } else { 'SourceSnapshotMatched' }
        executionPhase = $ExecutionState.executionPhase
        sourceVerification = $ExecutionState.sourceVerification
        destinationDisposition = if ($Failed -and $promoted) { 'UnacceptedRequiresReview' } else { $ExecutionState.destinationDisposition }
    }
}

function Remove-RepositoryExportOwnedTree {
    param([Parameter(Mandatory)][string]$Root)
    Assert-RepositoryExportLocalPath -Path (Split-Path $Root -Parent)
    $item = Get-Item -LiteralPath $Root -Force
    if (-not $item.PSIsContainer) { [IO.File]::Delete($Root); return }
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        [IO.Directory]::Delete($Root)
        return
    }
    foreach ($child in Get-ChildItem -LiteralPath $Root -Force) {
        if ($child.PSIsContainer) {
            Remove-RepositoryExportOwnedTree -Root $child.FullName
        }
        else {
            [IO.File]::Delete($child.FullName)
        }
    }
    [IO.Directory]::Delete($Root)
}

function Invoke-RepositoryExportCopy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SourceRoot,
        [Parameter(Mandatory)][string]$ExpectedSourceCommit,
        [Parameter(Mandatory)][string]$DestinationRoot,
        [Parameter(Mandatory)][object]$Manifest,
        [Parameter(Mandatory)][object]$Assessment,
        [Parameter(Mandatory)][object]$ExecutionManifest,
        [Parameter(Mandatory)][object]$SourceSnapshot,
        [Parameter(Mandatory)][object]$ToolIdentities,
        [Parameter(Mandatory)][scriptblock]$NativeCommandRunner,
        [Parameter(Mandatory)][scriptblock]$GitBlobReader,
        [Parameter(Mandatory)][scriptblock]$ValidationRunner,
        [object]$BoundInputs,
        [hashtable]$ExecutionState = @{}
    )
    $ExecutionState.executionPhase = 'BeforeStaging'
    $ExecutionState.sourceVerification = 'NotChecked'
    $ExecutionState.destinationDisposition = 'NotCreated'
    Assert-RepositoryExportLocalPath -Path $DestinationRoot
    if (Test-Path -LiteralPath $DestinationRoot) { throw 'Repository export destination must not already exist.' }
    $parent = Split-Path -Parent ([IO.Path]::GetFullPath($DestinationRoot))
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) { throw 'Repository export destination parent must exist.' }
    $disposable = Join-Path $parent ('.customer-export-' + [guid]::NewGuid().ToString('N'))
    if (Test-Path -LiteralPath $disposable) { throw 'Disposable staging already exists.' }
    $owned = $false
    $log = [Collections.Generic.List[object]]::new()
    $git = $ToolIdentities.Git
    $snapshotDigest = Get-RunbookContentDigest -InputObject $SourceSnapshot
    try {
        if ($null -ne $BoundInputs) { Assert-RepositoryExportApplyBinding -Binding $BoundInputs }
        $current = Get-RepositoryExportVerifiedSourceSnapshot -SourceRoot $SourceRoot -Git $git `
            -NativeCommandRunner $NativeCommandRunner -GitBlobReader $GitBlobReader -SnapshotDigest $snapshotDigest -ExecutionState $ExecutionState
        [void][IO.Directory]::CreateDirectory($disposable)
        $owned = $true
        $ExecutionState.executionPhase = 'Staging'
        foreach ($path in @($Assessment.copyFiles | Sort-Object)) {
            [byte[]]$bytes = @(& $GitBlobReader $git.path $SourceRoot $ExpectedSourceCommit.ToLowerInvariant() $path)
            if ((Get-CustomerExportSha256 -Bytes $bytes) -cne [string]$Assessment.fileDigests.$path.sourceBlobSha256) {
                throw 'Repository export committed blob changed before copy.'
            }
            $target = Join-Path $disposable $path.Replace('/', '\')
            [void][IO.Directory]::CreateDirectory((Split-Path $target -Parent))
            [IO.File]::WriteAllBytes($target, $bytes)
        }
        foreach ($path in @($Assessment.copyFiles | Sort-Object)) {
            $target = Join-Path $disposable $path.Replace('/', '\')
            [byte[]]$bytes = [IO.File]::ReadAllBytes($target)
            if ((Get-CustomerExportSha256 -Bytes $bytes) -cne [string]$Assessment.fileDigests.$path.sourceBlobSha256) {
                throw 'Repository export staged committed bytes changed before transformation.'
            }
            $rules = @($Manifest.replacements | Where-Object path -CEQ $path)
            $converted = Convert-CustomerExportBlob -Path $path -OriginalBytes $bytes -Rules $rules
            if ((Get-CustomerExportSha256 -Bytes $converted.bytes) -cne [string]$Assessment.fileDigests.$path.expectedOutputSha256) {
                throw 'Repository export transformed bytes changed before copy.'
            }
            [IO.File]::WriteAllBytes($target, $converted.bytes)
            foreach ($entry in @($converted.replacementLog)) { $log.Add($entry) }
        }
        $post = Get-RepositoryExportVerifiedSourceSnapshot -SourceRoot $SourceRoot -Git $git `
            -NativeCommandRunner $NativeCommandRunner -GitBlobReader $GitBlobReader -SnapshotDigest $snapshotDigest -ExecutionState $ExecutionState
        Assert-RepositoryExportTree -Root $disposable
        $validation = Test-CustomerExportContent -StagingRoot $disposable -Manifest $Manifest -Assessment $Assessment `
            -ExecutionManifest $ExecutionManifest -CurrentSourceSnapshot $post -ReplacementLog @($log) -ValidationRunner $ValidationRunner
        if (-not $validation.publishReady) { throw 'Repository export validation failed.' }
        # A validation runner can write files: recheck the complete bytes and boundary before promotion.
        $ExecutionState.executionPhase = 'BeforePromotion'
        $treeDigest = Get-RepositoryExportVerifiedTreeDigest -Root $disposable -Assessment $Assessment
        $post = Get-RepositoryExportVerifiedSourceSnapshot -SourceRoot $SourceRoot -Git $git `
            -NativeCommandRunner $NativeCommandRunner -GitBlobReader $GitBlobReader -SnapshotDigest $snapshotDigest -ExecutionState $ExecutionState
        Assert-RepositoryExportLocalPath -Path $DestinationRoot
        if (Test-Path -LiteralPath $DestinationRoot) { throw 'Repository export destination must not already exist.' }
        if ($null -ne $BoundInputs) { Assert-RepositoryExportApplyBinding -Binding $BoundInputs }
        [IO.Directory]::Move($disposable, [IO.Path]::GetFullPath($DestinationRoot))
        $ExecutionState.executionPhase = 'AfterPromotion'
        $ExecutionState.destinationDisposition = 'UnacceptedRequiresReview'
        $final = Get-RepositoryExportVerifiedSourceSnapshot -SourceRoot $SourceRoot -Git $git `
            -NativeCommandRunner $NativeCommandRunner -GitBlobReader $GitBlobReader -SnapshotDigest $snapshotDigest -ExecutionState $ExecutionState
        $ExecutionState.destinationDisposition = 'PromotedPendingIndependent'
        [pscustomobject]@{ replacementLog = @($log); contentTreeDigest = $treeDigest }
    }
    finally {
        if ($owned -and (Test-Path -LiteralPath $disposable)) {
            Remove-RepositoryExportOwnedTree -Root $disposable
        }
    }
}
