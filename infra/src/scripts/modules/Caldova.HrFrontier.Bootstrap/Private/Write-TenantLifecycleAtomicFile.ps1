function Write-TenantLifecycleAtomicFile {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][byte[]]$Bytes
    )

    if ([IO.File]::Exists($Path)) {
        throw [IO.IOException]::new('TenantLifecycle.Evidence.Exists')
    }

    $directory = [IO.Path]::GetDirectoryName($Path)
    $temporaryPath = Join-Path $directory (([guid]::NewGuid().ToString('N')) + '.tmp')
    $stream = $null
    try {
        $stream = [IO.FileStream]::new(
            $temporaryPath,
            [IO.FileMode]::CreateNew,
            [IO.FileAccess]::Write,
            [IO.FileShare]::None,
            4096,
            [IO.FileOptions]::WriteThrough
        )
        $stream.Write($Bytes, 0, $Bytes.Length)
        $stream.Flush($true)
        $stream.Dispose()
        $stream = $null

        if ([IO.File]::Exists($Path)) {
            throw [IO.IOException]::new('TenantLifecycle.Evidence.Exists')
        }
        [IO.File]::Move($temporaryPath, $Path)
        return $Path
    }
    finally {
        if ($null -ne $stream) {
            $stream.Dispose()
        }
        if ([IO.File]::Exists($temporaryPath)) {
            [IO.File]::Delete($temporaryPath)
        }
    }
}
