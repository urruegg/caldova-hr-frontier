function Resolve-HrAiBuilderEvidenceLocator {
    param(
        [Parameter(Mandatory)]
        [string]$Locator,

        [string]$RootPath,

        [Parameter(Mandatory)]
        [string]$Description
    )

    if ([string]::IsNullOrWhiteSpace($Locator)) {
        throw "$Description locator is required."
    }

    if ([IO.Path]::IsPathRooted($Locator)) {
        $resolvedAbsolutePath = [IO.Path]::GetFullPath($Locator)
        if (-not [string]::IsNullOrWhiteSpace($RootPath)) {
            $resolvedRoot = [IO.Path]::GetFullPath($RootPath)
            if (-not (Test-HrAiBuilderPathWithinRoot -Path $resolvedAbsolutePath -RootPath $resolvedRoot)) {
                throw "$Description locator '$Locator' resolves outside the allowed root '$resolvedRoot'."
            }
        }

        return $resolvedAbsolutePath
    }

    if ([string]::IsNullOrWhiteSpace($RootPath)) {
        throw "$Description locator '$Locator' requires an explicit root path."
    }

    $resolvedRootPath = [IO.Path]::GetFullPath($RootPath)
    $resolvedPath = [IO.Path]::GetFullPath((Join-Path $resolvedRootPath $Locator))
    if (-not (Test-HrAiBuilderPathWithinRoot -Path $resolvedPath -RootPath $resolvedRootPath)) {
        throw "$Description locator '$Locator' resolves outside the allowed root '$resolvedRootPath'."
    }

    return $resolvedPath
}
