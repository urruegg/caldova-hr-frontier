function Test-HrAiBuilderPathWithinRoot {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$RootPath
    )

    $resolvedRoot = [IO.Path]::GetFullPath($RootPath).TrimEnd('\', '/')
    $resolvedPath = [IO.Path]::GetFullPath($Path)

    if ([string]::Equals($resolvedPath, $resolvedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }

    return $resolvedPath.StartsWith(
        $resolvedRoot + [IO.Path]::DirectorySeparatorChar,
        [System.StringComparison]::OrdinalIgnoreCase
    )
}
