function Invoke-CustomerExportNativeCommand {
    param(
        [Parameter(Mandatory)][scriptblock]$Runner,
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string[]]$ArgumentList
    )

    $result = & $Runner $FilePath $ArgumentList
    if ($result -is [string]) {
        return [pscustomobject]@{ exitCode = 0; stdout = [string]$result; stderr = '' }
    }
    if ($null -eq $result) {
        return [pscustomobject]@{ exitCode = 1; stdout = ''; stderr = 'runner returned no result' }
    }
    if ($result.PSObject.Properties.Name -contains 'exitCode') {
        return [pscustomobject]@{
            exitCode = [int]$result.exitCode
            stdout = [string]$result.stdout
            stderr = [string]$result.stderr
        }
    }

    return [pscustomobject]@{ exitCode = 0; stdout = [string]$result; stderr = '' }
}

function Get-CustomerExportSha256 {
    param([Parameter(Mandatory)][byte[]]$Bytes)

    $hash = [Security.Cryptography.SHA256]::Create()
    try {
        return [BitConverter]::ToString($hash.ComputeHash($Bytes)).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $hash.Dispose()
    }
}

function Resolve-CustomerExportGitDirectory {
    param([Parameter(Mandatory)][string]$RepositoryRoot)

    $dotGitPath = Join-Path $RepositoryRoot '.git'
    if (-not (Test-Path -LiteralPath $dotGitPath)) {
        throw 'Source repository is missing .git metadata.'
    }
    $item = Get-Item -LiteralPath $dotGitPath -Force
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw 'Source repository metadata must not traverse a reparse point.'
    }
    if ($item.PSIsContainer) {
        return $item.FullName
    }

    $content = [IO.File]::ReadAllText($item.FullName).Trim()
    if ($content -notmatch '^gitdir:\s*(.+)$') {
        throw 'Source repository metadata is invalid.'
    }

    return [IO.Path]::GetFullPath((Join-Path $RepositoryRoot $Matches[1].Trim()))
}

function Get-CustomerExportSourceSnapshot {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [Parameter(Mandatory)][object]$GitExecutable,
        [Parameter(Mandatory)][scriptblock]$NativeCommandRunner,
        [Parameter(Mandatory)][scriptblock]$GitBlobReader
    )

    $repository = [IO.Path]::GetFullPath($RepositoryRoot)
    if (-not (Test-Path -LiteralPath $repository -PathType Container)) {
        throw 'Source repository root does not exist.'
    }
    if (-not [IO.Path]::IsPathRooted([string]$GitExecutable.path) -or
        [string]$GitExecutable.sha256 -notmatch '^[0-9a-f]{64}$') {
        throw 'Git executable identity is invalid.'
    }

    $git = [IO.Path]::GetFullPath([string]$GitExecutable.path)
    function Invoke-Git {
        param([string[]]$Arguments)
        Invoke-CustomerExportNativeCommand -Runner $NativeCommandRunner -FilePath $git -ArgumentList (@('-C', $repository) + $Arguments)
    }

    $status = Invoke-Git -Arguments @('status', '--porcelain=v1', '--untracked-files=all')
    if ($status.exitCode -ne 0) {
        throw 'Customer export source status could not be read.'
    }
    if (-not [string]::IsNullOrWhiteSpace($status.stdout)) {
        throw 'Customer export source must be clean.'
    }

    $head = Invoke-Git -Arguments @('rev-parse', 'HEAD')
    $commit = $head.stdout.Trim().ToLowerInvariant()
    if ($head.exitCode -ne 0 -or $commit -notmatch '^[0-9a-f]{40}$') {
        throw 'Customer export source commit could not be read.'
    }

    $topLevel = Invoke-Git -Arguments @('rev-parse', '--show-toplevel')
    if ($topLevel.exitCode -ne 0 -or
        -not [IO.Path]::IsPathRooted($topLevel.stdout.Trim()) -or
        [IO.Path]::GetFullPath($topLevel.stdout.Trim()) -cne $repository) {
        throw 'Customer export source root is not the exact Git worktree root.'
    }

    $sparse = Invoke-Git -Arguments @('sparse-checkout', 'list')
    if ($sparse.exitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($sparse.stdout)) {
        throw 'Customer export source must not use sparse checkout.'
    }

    $tree = Invoke-Git -Arguments @('ls-tree', '-r', '-z', '--full-tree', 'HEAD')
    if ($tree.exitCode -ne 0) {
        throw 'Customer export source tracked tree could not be read.'
    }

    $trackedFiles = [Collections.Generic.List[object]]::new()
    $seenPaths = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($entry in @($tree.stdout -split [char]0 | Where-Object { $_ })) {
        if ($entry -notmatch '^(?<mode>\d{6})\s+blob\s+(?<object>[0-9a-f]{40})\t(?<path>.+)$') {
            throw 'Customer export source contains an unsupported tracked tree entry.'
        }
        $mode = $Matches.mode
        if ($mode -notin @('100644', '100755')) {
            throw 'Customer export source contains an unsupported tracked tree entry.'
        }
        $path = Test-CustomerExportRelativePath -Path $Matches.path
        if (-not $seenPaths.Add($path)) {
            throw 'Customer export source contains a duplicate tracked path.'
        }
        [byte[]]$blobBytes = & $GitBlobReader $git $repository $commit $path
        if ($null -eq $blobBytes) {
            throw 'Customer export source tracked blob could not be read.'
        }
        $blobDigest = Get-CustomerExportSha256 -Bytes $blobBytes
        $trackedFiles.Add([pscustomobject][ordered]@{
            path = $path
            mode = $mode
            objectId = $Matches.object.ToLowerInvariant()
            blobSha256 = $blobDigest
        })
    }

    $refs = Invoke-Git -Arguments @('for-each-ref', '--format=%(refname)%00%(objectname)')
    if ($refs.exitCode -ne 0) {
        throw 'Customer export source refs could not be read.'
    }
    $refRecords = @(
        foreach ($entry in @($refs.stdout -split [Environment]::NewLine | Where-Object { $_ })) {
            $parts = @($entry -split [char]0)
            if ($parts.Count -lt 2) { continue }
            [pscustomobject]@{ refname = $parts[0]; objectId = $parts[1].ToLowerInvariant() }
        }
    )

    $remotes = Invoke-Git -Arguments @('remote', '-v')
    if ($remotes.exitCode -ne 0) {
        throw 'Customer export source remotes could not be read.'
    }
    $remoteLines = @($remotes.stdout -split "`r?`n" | Where-Object { $_ } | Sort-Object)

    $config = Invoke-Git -Arguments @('config', '--local', '--list', '--null')
    if ($config.exitCode -ne 0) {
        throw 'Customer export source configuration could not be read.'
    }
    $configEntries = @($config.stdout -split [char]0 | Where-Object { $_ } | Sort-Object)

    $gitDirectory = Resolve-CustomerExportGitDirectory -RepositoryRoot $repository
    $hookRecords = @()
    $hooksRoot = Join-Path $gitDirectory 'hooks'
    if (Test-Path -LiteralPath $hooksRoot -PathType Container) {
        foreach ($hook in Get-ChildItem -LiteralPath $hooksRoot -File | Sort-Object Name) {
            $hookRecords += [pscustomobject]@{
                name = $hook.Name
                sha256 = (Get-FileHash -LiteralPath $hook.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
            }
        }
    }

    $workflowRecords = @()
    $workflowRoot = Join-Path $repository '.github\workflows'
    if (Test-Path -LiteralPath $workflowRoot -PathType Container) {
        foreach ($workflow in Get-ChildItem -LiteralPath $workflowRoot -File -Recurse | Sort-Object FullName) {
            $relative = Get-RunbookRelativePath -Root $repository -Path $workflow.FullName
            $workflowRecords += [pscustomobject]@{
                path = $relative
                sha256 = (Get-FileHash -LiteralPath $workflow.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
            }
        }
    }

    $trackedArray = @($trackedFiles | Sort-Object path)
    return [pscustomobject][ordered]@{
        commit = $commit
        status = ''
        trackedFiles = $trackedArray
        trackedTreeDigest = Get-RunbookContentDigest -InputObject $trackedArray
        refsDigest = Get-RunbookContentDigest -InputObject @($refRecords | Sort-Object refname, objectId)
        remotesDigest = Get-RunbookContentDigest -InputObject $remoteLines
        configDigest = Get-RunbookContentDigest -InputObject $configEntries
        hooksDigest = Get-RunbookContentDigest -InputObject @($hookRecords)
        workflowDigest = Get-RunbookContentDigest -InputObject @($workflowRecords)
    }
}
