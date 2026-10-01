function Convert-HrAiBuilderPortableLocator {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$RootPath,

        [Parameter(Mandatory)]
        [string]$Description
    )

    $resolvedRoot = [IO.Path]::GetFullPath($RootPath)
    $resolvedPath = [IO.Path]::GetFullPath($Path)
    if (-not (Test-HrAiBuilderPathWithinRoot -Path $resolvedPath -RootPath $resolvedRoot)) {
        throw "$Description '$resolvedPath' is outside the portable root '$resolvedRoot'."
    }

    $rootUri = [System.Uri]::new($resolvedRoot.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar)
    $pathUri = [System.Uri]::new($resolvedPath)
    return ([System.Uri]::UnescapeDataString($rootUri.MakeRelativeUri($pathUri).ToString()) -replace '/', '\')
}
