function Resolve-CloudNativeTool {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('az','gh','pac','git')]
        [string]$Name,

        [scriptblock]$ApplicationResolver,
        [scriptblock]$FileHashProvider,
        [scriptblock]$VersionProvider
    )

    if ($null -eq $ApplicationResolver) {
        $ApplicationResolver = {
            param($RequestedName)
            @(Get-Command -Name $RequestedName -CommandType Application -All -ErrorAction Stop)
        }
    }
    $resolved = @(& $ApplicationResolver $Name)
    $paths = [Collections.Generic.List[string]]::new()
    foreach ($application in $resolved) {
        $source = [string]$application.Source
        if ([string]::IsNullOrWhiteSpace($source) -or -not [IO.Path]::IsPathRooted($source)) {
            throw "Cloud tool '$Name' did not resolve to exactly one unique application."
        }
        $fullPath = [IO.Path]::GetFullPath($source)
        if (-not $paths.Contains($fullPath)) { $paths.Add($fullPath) }
    }
    $unique = @($paths | Sort-Object -Unique)
    if ($unique.Count -eq 0) {
        throw "Cloud tool '$Name' did not resolve to exactly one unique application."
    }
    if ($unique.Count -ne 1) {
        throw "Cloud tool '$Name' resolution is ambiguous."
    }
    $path = $unique[0]

    if ($null -eq $FileHashProvider) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "Cloud tool '$Name' did not resolve to exactly one unique application."
        }
        $item = Get-Item -LiteralPath $path -Force
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Cloud tool '$Name' must not resolve through a reparse point."
        }
        $FileHashProvider = { param($ResolvedPath) Get-FileHash -LiteralPath $ResolvedPath -Algorithm SHA256 }
    }
    $hash = [string](& $FileHashProvider $path).Hash
    if ($hash -notmatch '^[0-9a-fA-F]{64}$') {
        throw "Cloud tool '$Name' returned an invalid SHA-256."
    }

    if ($null -eq $VersionProvider) {
        $VersionProvider = {
            param($ResolvedPath, $LogicalName)
            $arguments = switch ($LogicalName) {
                'az' { @('version','--output','json') }
                'gh' { @('--version') }
                'pac' { @('help') }
                'git' { @('--version') }
            }
            $text = (& $ResolvedPath @arguments 2>$null | Out-String).Trim()
            if ([string]::IsNullOrWhiteSpace($text)) {
                throw "Cloud tool '$LogicalName' version could not be determined."
            }
            $match = [regex]::Match($text, '\d+\.\d+(?:\.\d+)?')
            if ($match.Success) { return $match.Value }
            return $text
        }
    }
    $version = [string](& $VersionProvider $path $Name)
    if ([string]::IsNullOrWhiteSpace($version)) {
        throw "Cloud tool '$Name' version could not be determined."
    }

    [pscustomobject][ordered]@{
        name = $Name
        path = $path
        version = $version
        sha256 = $hash.ToLowerInvariant()
    }
}
