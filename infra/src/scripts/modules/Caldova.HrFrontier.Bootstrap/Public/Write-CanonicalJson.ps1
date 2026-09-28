function Write-CanonicalJson {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)] [object]$InputObject,
        [Parameter(Mandatory)] [string]$Path,
        [ValidateRange(2, 100)] [int]$Depth = 30,
        [switch]$Replace
    )
    process {
        $fullPath = [IO.Path]::GetFullPath($Path)
        if ((Test-Path -LiteralPath $fullPath) -and -not $Replace) {
            throw 'Canonical JSON output already exists; use -Replace only for a reviewed replacement.'
        }
        $canonical = ConvertTo-CanonicalJsonValue -Value $InputObject -RemainingDepth $Depth
        $json = ($canonical | ConvertTo-Json -Depth $Depth -Compress) + "`n"
        $directory = Split-Path -Parent $fullPath
        [IO.Directory]::CreateDirectory($directory) | Out-Null
        $temporary = Join-Path $directory (([guid]::NewGuid().ToString('N')) + '.tmp')
        try {
            [IO.File]::WriteAllText($temporary, $json, [Text.UTF8Encoding]::new($false))
            Move-Item -LiteralPath $temporary -Destination $fullPath -Force:$Replace
        }
        finally {
            if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force }
        }
        $fullPath
    }
}
