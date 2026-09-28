function Resolve-RunbookReportPath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [guid]$RunId,
        [string]$Path,
        [Parameter(Mandatory)] [string]$RepositoryRoot,
        [string]$StagingRoot
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        if ([string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
            throw 'LOCALAPPDATA is required when no report path is supplied.'
        }
        $Path = Join-Path $env:LOCALAPPDATA "CaldovaHrFrontier\runbook-evidence\$($RunId.ToString('D'))"
    }

    $candidate = [IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
    $repository = [IO.Path]::GetFullPath($RepositoryRoot).TrimEnd('\', '/')
    if (Test-RunbookPathWithin -Path $candidate -Root $repository) {
        throw 'The report path must be outside every Git working tree.'
    }
    if (-not [string]::IsNullOrWhiteSpace($StagingRoot) -and
        (Test-RunbookPathWithin -Path $candidate -Root $StagingRoot)) {
        throw 'The report path must be outside the staging root.'
    }

    $cursor = $candidate
    while (-not [string]::IsNullOrWhiteSpace($cursor)) {
        if (Test-Path -LiteralPath $cursor) {
            $item = Get-Item -LiteralPath $cursor -Force
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw 'The report path must not traverse a reparse point.'
            }
            if ($item.PSIsContainer -and (Test-Path -LiteralPath (Join-Path $cursor '.git'))) {
                throw 'The report path must be outside every Git working tree.'
            }
        }
        $parent = Split-Path -Parent $cursor
        if ([string]::IsNullOrWhiteSpace($parent) -or
            [string]::Equals($parent, $cursor, [StringComparison]::OrdinalIgnoreCase)) {
            break
        }
        $cursor = $parent
    }

    return $candidate
}
