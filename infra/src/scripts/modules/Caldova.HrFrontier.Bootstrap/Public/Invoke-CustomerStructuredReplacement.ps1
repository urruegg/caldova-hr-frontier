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
    $preserveBackup = $false
    $primaryFailure = $null
    $cleanupWarnings = [System.Collections.Generic.List[string]]::new()
    $cleanupWarningText = 'Customer export replacement cleanup could not remove one or more disposable local artifacts.'

    function Add-CustomerStructuredReplacementCleanupWarning {
        if (-not $cleanupWarnings.Contains($cleanupWarningText)) {
            $cleanupWarnings.Add($cleanupWarningText) | Out-Null
        }
    }

    function Remove-CustomerStructuredReplacementArtifactSafe {
        param([string]$Path)

        try {
            if (-not (& $FileOperations.Exists $Path)) {
                return
            }
            & $FileOperations.Delete $Path
        }
        catch {
            Add-CustomerStructuredReplacementCleanupWarning
        }
    }

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
                        $primaryFailure = 'Customer export replacement publish failed after the original target bytes were restored.'
                    }
                    catch {
                        if (& $FileOperations.Exists $backup) {
                            $preserveBackup = $true
                            $primaryFailure = ("Customer export replacement publish failed. Recover from local backup path '{0}'." -f $backup)
                        }
                        else {
                            $primaryFailure = 'Customer export replacement publish failed and automatic restoration did not complete.'
                        }
                    }
                }
                else {
                    $primaryFailure = $_
                }
            }
        }
        else {
            & $FileOperations.Move $temporary $TargetPath
        }
    }
    finally {
        foreach ($path in @($temporary, $restoreTemporary, $restoreBackup)) {
            Remove-CustomerStructuredReplacementArtifactSafe -Path $path
        }

        if (-not $preserveBackup) {
            Remove-CustomerStructuredReplacementArtifactSafe -Path $backup
        }
    }

    foreach ($warning in $cleanupWarnings) {
        Write-Warning -Message $warning -WarningAction Continue
    }

    if ($null -ne $primaryFailure) {
        throw $primaryFailure
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
