function Update-RunbookProcessPath {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $segments = @(
        [Environment]::GetEnvironmentVariable('Path', 'Machine') -split ';'
        [Environment]::GetEnvironmentVariable('Path', 'User') -split ';'
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $unique = foreach ($segment in $segments) {
        $trimmed = $segment.Trim().TrimEnd('\')
        if ($seen.Add($trimmed)) { $trimmed }
    }
    $env:Path = $unique -join ';'
    $env:Path
}
