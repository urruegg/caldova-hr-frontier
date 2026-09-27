function Publish-CustomerStructuredReplacementBytes {
    param(
        [Parameter(Mandatory)][string]$TargetPath,
        [Parameter(Mandatory)][byte[]]$Bytes
    )

    $parent = Split-Path -Parent $TargetPath
    $temporary = Join-Path $parent (([guid]::NewGuid().ToString('N')) + '.tmp')
    $backup = Join-Path $parent (([guid]::NewGuid().ToString('N')) + '.bak')
    try {
        [IO.File]::WriteAllBytes($temporary, [byte[]]$Bytes)
        if (Test-Path -LiteralPath $TargetPath -PathType Leaf) {
            [IO.File]::Replace($temporary, $TargetPath, $backup, $false)
            if (Test-Path -LiteralPath $backup) {
                Remove-Item -LiteralPath $backup -Force
            }
        }
        else {
            [IO.File]::Move($temporary, $TargetPath)
        }
    }
    finally {
        foreach ($path in @($temporary, $backup)) {
            if (Test-Path -LiteralPath $path) {
                Remove-Item -LiteralPath $path -Force
            }
        }
    }
}

function Invoke-CustomerStructuredReplacement {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)][string]$StagingRoot,
        [Parameter(Mandatory)][string]$Path,
        [AllowEmptyCollection()][object[]]$Rules = @()
    )

    $normalizedPath = Test-CustomerExportRelativePath -Path $Path
    $root = [IO.Path]::GetFullPath($StagingRoot)
    $target = [IO.Path]::GetFullPath((Join-Path $root $normalizedPath.Replace('/', '\')))
    if (-not (Test-RunbookPathWithin -Path $target -Root $root)) {
        throw 'Customer export replacement target must remain within staging.'
    }

    $originalBytes = [IO.File]::ReadAllBytes($target)
    $result = Convert-CustomerExportBlob -Path $normalizedPath -OriginalBytes $originalBytes -Rules $Rules
    Publish-CustomerStructuredReplacementBytes -TargetPath $target -Bytes $result.bytes

    return @($result.replacementLog)
}
