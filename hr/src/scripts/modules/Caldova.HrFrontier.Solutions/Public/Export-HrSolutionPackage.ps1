function Export-HrSolutionPackage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('^[a-z0-9]+$')]
        [string]$TenantAlias,

        [Parameter(Mandatory)]
        [string]$SolutionUniqueName,

        [Parameter(Mandatory)]
        [string]$DestinationPath,

        [string]$TenantConfigurationPath,

        [scriptblock]$NativeCommandRunner
    )

    $connection = Connect-HrPowerPlatformEnvironment -TenantAlias $TenantAlias -Stage 'Dev' -TenantConfigurationPath $TenantConfigurationPath -NativeCommandRunner $NativeCommandRunner

    $resolvedDestinationPath = [System.IO.Path]::GetFullPath($DestinationPath)
    $destinationDirectory = Split-Path -Parent $resolvedDestinationPath
    if (-not [string]::IsNullOrWhiteSpace($destinationDirectory) -and -not (Test-Path -LiteralPath $destinationDirectory)) {
        [void](New-Item -ItemType Directory -Path $destinationDirectory -Force)
    }

    $exportResult = Invoke-HrNativeCommand -FilePath 'pac' -ArgumentList @(
        'solution', 'export',
        '--name', $SolutionUniqueName,
        '--path', $resolvedDestinationPath,
        '--managed', 'false',
        '--overwrite', 'true',
        '--environment', $connection.EnvironmentUrl
    ) -NativeCommandRunner $NativeCommandRunner

    if ($exportResult.ExitCode -ne 0) {
        throw "pac solution export failed for '$SolutionUniqueName': $($exportResult.StdErr)"
    }

    if (-not (Test-Path -LiteralPath $resolvedDestinationPath -PathType Leaf)) {
        throw "pac solution export reported success but no file was written to $resolvedDestinationPath."
    }

    [pscustomobject]@{
        TenantAlias = $TenantAlias
        SolutionUniqueName = $SolutionUniqueName
        Path = $resolvedDestinationPath
        EnvironmentUrl = $connection.EnvironmentUrl
    }
}
