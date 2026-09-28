function Get-RunbookRelativePath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$Path
    )

    $fullRoot = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    $fullPath = [IO.Path]::GetFullPath($Path)
    if (-not (Test-RunbookPathWithin -Path $fullPath -Root $fullRoot)) {
        throw 'Path must remain within the declared root.'
    }

    if ([string]::Equals($fullRoot, $fullPath.TrimEnd('\', '/'), [StringComparison]::OrdinalIgnoreCase)) {
        return '.'
    }

    return $fullPath.Substring($fullRoot.Length).TrimStart('\', '/').Replace('\', '/')
}
