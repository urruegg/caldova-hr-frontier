function Publish-CustomerStructuredReplacementBytes {
    param(
        [Parameter(Mandatory)][string]$TargetPath,
        [Parameter(Mandatory)][byte[]]$Bytes,
        [AllowNull()][object]$FileOperations
    )

    if ($null -eq $FileOperations) {
        $FileOperations = [pscustomobject]@{
            WriteAllBytes = { param($path, [byte[]]$bytes) [IO.File]::WriteAllBytes($path, $bytes) }
            ReadAllBytes = { param($path) [IO.File]::ReadAllBytes($path) }
            Exists = { param($path) Test-Path -LiteralPath $path -PathType Leaf }
            Delete = { param($path) Remove-Item -LiteralPath $path -Force }
            Move = { param($source, $destination) [IO.File]::Move($source, $destination) }
            Replace = { param($source, $destination, $backup) [IO.File]::Replace($source, $destination, $backup, $false) }
        }
    }

    $parent = Split-Path -Parent $TargetPath
    $temporary = Join-Path $parent (([guid]::NewGuid().ToString('N')) + '.tmp')
    $backup = Join-Path $parent (([guid]::NewGuid().ToString('N')) + '.bak')
    $restoreTemporary = Join-Path $parent (([guid]::NewGuid().ToString('N')) + '.restore.tmp')
    $restoreBackup = Join-Path $parent (([guid]::NewGuid().ToString('N')) + '.restore.bak')
    $keepBackup = $false
    $restoredOriginal = $false

    try {
        & $FileOperations.WriteAllBytes $temporary ([byte[]]$Bytes)
        if (& $FileOperations.Exists $TargetPath) {
            try {
                & $FileOperations.Replace $temporary $TargetPath $backup
            }
            catch {
                if (& $FileOperations.Exists $backup) {
                    try {
                        & $FileOperations.WriteAllBytes $restoreTemporary (& $FileOperations.ReadAllBytes $backup)
                        if (& $FileOperations.Exists $TargetPath) {
                            & $FileOperations.Replace $restoreTemporary $TargetPath $restoreBackup
                        }
                        else {
                            & $FileOperations.Move $restoreTemporary $TargetPath
                        }

                        $restoredOriginal = $true
                        if (& $FileOperations.Exists $backup) {
                            & $FileOperations.Delete $backup
                        }
                        if (& $FileOperations.Exists $restoreBackup) {
                            & $FileOperations.Delete $restoreBackup
                        }
                    }
                    catch {
                        $keepBackup = $true
                        throw ("Customer export replacement publish failed. Recover from local backup path '{0}'." -f $backup)
                    }
                }

                if ($restoredOriginal) {
                    throw 'Customer export replacement publish failed after the original target bytes were restored.'
                }

                throw
            }
        }
        else {
            & $FileOperations.Move $temporary $TargetPath
        }
    }
    finally {
        foreach ($path in @($temporary, $restoreTemporary, $restoreBackup)) {
            if (& $FileOperations.Exists $path) {
                & $FileOperations.Delete $path
            }
        }

        if ((-not $keepBackup) -and (& $FileOperations.Exists $backup)) {
            & $FileOperations.Delete $backup
        }
    }
}

function Invoke-CustomerStructuredReplacement {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)][string]$StagingRoot,
        [Parameter(Mandatory)][string]$Path,
        [AllowEmptyCollection()][object[]]$Rules = @(),
        [Parameter(DontShow)]
        [AllowNull()][object]$FileOperations
    )

    $normalizedPath = Test-CustomerExportRelativePath -Path $Path
    $root = [IO.Path]::GetFullPath($StagingRoot)
    $target = [IO.Path]::GetFullPath((Join-Path $root $normalizedPath.Replace('/', '\')))
    if (-not (Test-RunbookPathWithin -Path $target -Root $root)) {
        throw 'Customer export replacement target must remain within staging.'
    }

    $originalBytes = [IO.File]::ReadAllBytes($target)
    $result = Convert-CustomerExportBlob -Path $normalizedPath -OriginalBytes $originalBytes -Rules $Rules
    Publish-CustomerStructuredReplacementBytes -TargetPath $target -Bytes $result.bytes -FileOperations $FileOperations

    return @($result.replacementLog)
}
