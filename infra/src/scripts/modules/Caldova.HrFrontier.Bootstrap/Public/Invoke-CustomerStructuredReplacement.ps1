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
    $temporary = Join-Path (Split-Path -Parent $target) (([guid]::NewGuid().ToString('N')) + '.tmp')
    try {
        [IO.File]::WriteAllBytes($temporary, [byte[]]$result.bytes)
        [IO.File]::Copy($temporary, $target, $true)
    }
    finally {
        if (Test-Path -LiteralPath $temporary) {
            Remove-Item -LiteralPath $temporary -Force
        }
    }

    return @($result.replacementLog)
}
