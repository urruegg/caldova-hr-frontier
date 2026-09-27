function Test-CustomerExportRelativePath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path) -or
        $Path -match '\\' -or
        $Path -match '^[A-Za-z]:' -or
        $Path -match '^//|^\\\\') {
        throw 'Customer export paths must be exact repository-relative forward-slash paths.'
    }

    $segments = @($Path -split '/')
    if (@($segments | Where-Object { [string]::IsNullOrWhiteSpace($_) -or $_ -in @('.', '..') }).Count -gt 0) {
        throw 'Customer export paths must be exact repository-relative forward-slash paths.'
    }

    foreach ($segment in $segments) {
        if ([string]::Equals($segment, '.git', [StringComparison]::OrdinalIgnoreCase) -or
            $segment.IndexOfAny([char[]]@('*', '?', '[', ']')) -ge 0 -or
            $segment.IndexOfAny([IO.Path]::GetInvalidFileNameChars()) -ge 0) {
            throw 'Customer export paths must be exact repository-relative forward-slash paths.'
        }
    }

    return ($segments -join '/')
}
