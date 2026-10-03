function Write-TenantLifecycleStageResult {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][string]$RunDirectory,
        [Parameter(Mandatory)][object]$StageResult
    )

    try {
        if (-not [IO.Path]::IsPathRooted($RunDirectory)) {
            throw [IO.InvalidDataException]::new()
        }
        $runRoot = [IO.Path]::GetFullPath($RunDirectory)
        $pathRoot = [IO.Path]::GetPathRoot($runRoot)
        if ($runRoot.Length -gt $pathRoot.Length) {
            $runRoot = $runRoot.TrimEnd(
                [IO.Path]::DirectorySeparatorChar,
                [IO.Path]::AltDirectorySeparatorChar
            )
        }
        Test-TenantLifecycleContract `
            -Kind StageResult `
            -InputObject $StageResult |
            Out-Null
        $json = ConvertTo-TenantLifecycleCanonicalJson `
            -InputObject $StageResult
        $bytes = [Text.UTF8Encoding]::new($false, $true).GetBytes($json)
        if (Test-TenantLifecycleEvidenceReparsePath -Path $runRoot) {
            throw [IO.InvalidDataException]::new(
                'TenantLifecycle.Evidence.ReparsePoint'
            )
        }
    }
    catch {
        if ($_.Exception.Message -ceq
            'TenantLifecycle.Evidence.ReparsePoint') {
            throw
        }
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.StageResult.Invalid'
        )
    }

    try {
        if ([IO.File]::Exists($runRoot)) {
            throw [IO.InvalidDataException]::new()
        }
        if (-not [IO.Directory]::Exists($runRoot)) {
            [IO.Directory]::CreateDirectory($runRoot) | Out-Null
        }
        $rootItem = Get-Item `
            -LiteralPath $runRoot `
            -Force `
            -ErrorAction Stop
        if (-not [bool]$rootItem.PSIsContainer) {
            throw [IO.InvalidDataException]::new()
        }
        if (($rootItem.Attributes -band
                [IO.FileAttributes]::ReparsePoint) -ne 0 -or
            (Test-TenantLifecycleEvidenceReparsePath -Path $runRoot)) {
            throw [IO.InvalidDataException]::new(
                'TenantLifecycle.Evidence.ReparsePoint'
            )
        }
    }
    catch {
        if ($_.Exception.Message -ceq
            'TenantLifecycle.Evidence.ReparsePoint') {
            throw
        }
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.StageResult.Root'
        )
    }

    $stagesDirectory = Join-Path $runRoot 'stages'
    try {
        if ([IO.File]::Exists($stagesDirectory)) {
            throw [IO.InvalidDataException]::new()
        }
        if (-not [IO.Directory]::Exists($stagesDirectory)) {
            [IO.Directory]::CreateDirectory($stagesDirectory) | Out-Null
        }
        $stagesItem = Get-Item `
            -LiteralPath $stagesDirectory `
            -Force `
            -ErrorAction Stop
        if (-not [bool]$stagesItem.PSIsContainer) {
            throw [IO.InvalidDataException]::new()
        }
        if (($stagesItem.Attributes -band
                [IO.FileAttributes]::ReparsePoint) -ne 0 -or
            (Test-TenantLifecycleEvidenceReparsePath -Path $stagesDirectory)) {
            throw [IO.InvalidDataException]::new(
                'TenantLifecycle.Evidence.ReparsePoint'
            )
        }
    }
    catch {
        if ($_.Exception.Message -ceq
            'TenantLifecycle.Evidence.ReparsePoint') {
            throw
        }
        throw [IO.InvalidDataException]::new(
            'TenantLifecycle.StageResult.Directory'
        )
    }

    $targetPath = Join-Path $stagesDirectory (
        ([string]$StageResult.stage) + '.json'
    )
    if ([IO.File]::Exists($targetPath) -or
        [IO.Directory]::Exists($targetPath)) {
        try {
            $targetItem = Get-Item `
                -LiteralPath $targetPath `
                -Force `
                -ErrorAction Stop
            if (($targetItem.Attributes -band
                    [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw [IO.InvalidDataException]::new(
                    'TenantLifecycle.Evidence.ReparsePoint'
                )
            }
        }
        catch {
            if ($_.Exception.Message -ceq
                'TenantLifecycle.Evidence.ReparsePoint') {
                throw
            }
        }
        throw [IO.IOException]::new('TenantLifecycle.Evidence.Exists')
    }

    try {
        Write-TenantLifecycleAtomicFile `
            -Path $targetPath `
            -Bytes $bytes
    }
    catch {
        if ($_.Exception.Message -ceq 'TenantLifecycle.Evidence.Exists' -or
            $_.Exception.Message -ceq
                'TenantLifecycle.Evidence.ReparsePoint') {
            throw
        }
        throw [IO.IOException]::new('TenantLifecycle.StageResult.Write')
    }
}
