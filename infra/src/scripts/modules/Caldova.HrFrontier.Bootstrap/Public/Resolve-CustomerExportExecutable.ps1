function Resolve-CustomerExportExecutable {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('git.exe', 'powershell.exe', 'az.cmd')]
        [string]$Name,

        [scriptblock]$CommandResolver,
        [scriptblock]$FileIdentityProvider
    )

    if ($null -eq $CommandResolver) {
        $CommandResolver = {
            param($RequestedName)
            @(Get-Command $RequestedName -All -CommandType Application -ErrorAction SilentlyContinue |
                ForEach-Object Source)
        }
    }
    if ($null -eq $FileIdentityProvider) {
        $FileIdentityProvider = {
            param($Path)
            if (-not [IO.Path]::IsPathRooted($Path) -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) {
                throw 'Required executable is missing.'
            }
            $item = Get-Item -LiteralPath $Path -Force
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw 'Required executable is missing.'
            }
            [pscustomobject]@{
                path = [IO.Path]::GetFullPath($Path)
                sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
            }
        }
    }

    $resolved = @(& $CommandResolver $Name)
    $identities = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($candidate in $resolved) {
        $path = [string]$candidate
        if ([string]::IsNullOrWhiteSpace($path) -or -not [IO.Path]::IsPathRooted($path)) {
            throw 'Required executable is missing.'
        }
        $identity = & $FileIdentityProvider ([IO.Path]::GetFullPath($path))
        if ($null -eq $identity -or [string]::IsNullOrWhiteSpace([string]$identity.path) -or
            [string]::IsNullOrWhiteSpace([string]$identity.sha256)) {
            throw 'Required executable is missing.'
        }

        $canonicalPath = [IO.Path]::GetFullPath([string]$identity.path)
        if (-not [IO.Path]::IsPathRooted($canonicalPath)) {
            throw 'Required executable is missing.'
        }
        $digest = [string]$identity.sha256
        if ($digest -notmatch '^[0-9a-fA-F]{64}$') {
            throw 'Required executable is missing.'
        }
        $normalized = [pscustomobject]@{
            name = $Name
            path = $canonicalPath
            sha256 = $digest.ToLowerInvariant()
        }

        if ($identities.ContainsKey($canonicalPath)) {
            if ([string]$identities[$canonicalPath].sha256 -cne $normalized.sha256) {
                throw 'Executable resolution is ambiguous.'
            }
            continue
        }

        $identities[$canonicalPath] = $normalized
    }

    if ($identities.Count -eq 0) {
        throw 'Required executable is missing.'
    }
    if ($identities.Count -ne 1) {
        throw 'Executable resolution is ambiguous.'
    }

    return @($identities.Values)[0]
}
