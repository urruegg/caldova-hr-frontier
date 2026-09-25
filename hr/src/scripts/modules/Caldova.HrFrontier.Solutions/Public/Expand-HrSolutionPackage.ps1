function Expand-HrSolutionPackage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ZipPath,

        [Parameter(Mandatory)]
        [string]$SolutionUniqueName,

        [Parameter(Mandatory)]
        [string]$SolutionsRoot,

        [scriptblock]$NativeCommandRunner
    )

    $resolvedZipPath = [System.IO.Path]::GetFullPath($ZipPath)
    if (-not (Test-Path -LiteralPath $resolvedZipPath -PathType Leaf)) {
        throw "Solution zip not found: $resolvedZipPath"
    }

    $resolvedSolutionsRoot = [System.IO.Path]::GetFullPath($SolutionsRoot)
    $targetFolder = Join-Path $resolvedSolutionsRoot $SolutionUniqueName

    $unpackResult = Invoke-HrNativeCommand -FilePath 'pac' -ArgumentList @(
        'solution', 'unpack',
        '--zipfile', $resolvedZipPath,
        '--folder', $targetFolder,
        '--packagetype', 'Unmanaged',
        '--allowWrite', 'true',
        '--allowDelete', 'true',
        '--clobber', 'true'
    ) -NativeCommandRunner $NativeCommandRunner

    if ($unpackResult.ExitCode -ne 0) {
        throw "pac solution unpack failed for '$SolutionUniqueName': $($unpackResult.StdErr)"
    }

    if (-not (Test-Path -LiteralPath $targetFolder -PathType Container) -or (@(Get-ChildItem -LiteralPath $targetFolder -Force)).Count -eq 0) {
        throw "pac solution unpack reported success but $targetFolder is empty."
    }

    [pscustomobject]@{
        SolutionUniqueName = $SolutionUniqueName
        Folder = $targetFolder
    }
}
