function Assert-RepositoryExportToolFiles {
    param([Parameter(Mandatory)][object]$Tools)
    foreach ($tool in $Tools.PSObject.Properties) {
        Assert-RepositoryExportLocalPath -Path $tool.Value.path -AllowHardLink
        if ((Get-CustomerExportFileDigest -Path $tool.Value.path) -cne $tool.Value.sha256) { throw 'Offline tool identity drifted.' }
    }
}

function Test-RepositoryExportReconstructedTree {
    param([string]$Root, [Collections.Generic.Dictionary[string, byte[]]]$Expected, [object]$Manifest, [string]$Profile)
    $unexpected = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $missing = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $mismatched = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $denied = [Collections.Generic.List[object]]::new()
    $digest = $null
    $actualCount = 0
    try {
        $inventory = Get-HistoryFreeRepositoryInventory -Root $Root
        $actualCount = @($inventory.files).Count
        foreach ($finding in $inventory.findings) { $denied.Add($finding) }
        $files = [Collections.Generic.HashSet[string]]::new([string[]]@($inventory.files), [StringComparer]::Ordinal)
        $directories = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach ($path in $Expected.Keys) {
            if (-not $files.Contains($path)) { [void]$missing.Add($path) }
            $cursor = $path
            while ($cursor.Contains('/')) {
                $cursor = $cursor.Substring(0, $cursor.LastIndexOf('/'))
                [void]$directories.Add($cursor)
            }
        }
        foreach ($path in @($inventory.files) + @($inventory.directories)) {
            $isDirectory = @($inventory.directories) -ccontains $path
            if (($isDirectory -and -not $directories.Contains($path)) -or (-not $isDirectory -and -not $Expected.ContainsKey($path))) {
                [void]$unexpected.Add($path)
            }
            $category = Get-RepositoryExportPathDenial -Path $path -Manifest $Manifest -Profile $Profile -Directory:$isDirectory
            if ($category) { $denied.Add([pscustomobject]@{ category = $category; path = $path }) }
        }
        $tree = [ordered]@{}
        foreach ($path in $inventory.files) {
            if (@($inventory.findings | Where-Object path -CEQ $path).Count -gt 0) { continue }
            $full = Join-Path $Root $path.Replace('/', '\')
            Assert-RepositoryExportLocalPath -Path $full
            [byte[]]$bytes = [IO.File]::ReadAllBytes($full)
            $tree[$path] = Get-CustomerExportSha256 -Bytes $bytes
            if ($Expected.ContainsKey($path)) {
                $wanted = $Expected[$path]
                $equal = $bytes.Length -eq $wanted.Length
                if ($equal) {
                    for ($i = 0; $i -lt $bytes.Length; $i++) {
                        if ($bytes[$i] -ne $wanted[$i]) { $equal = $false; break }
                    }
                }
                if (-not $equal) { [void]$mismatched.Add($path) }
            }
            try {
                Get-CustomerExportTextKind -Path $path -Bytes $bytes | Out-Null
                foreach ($residual in @(Get-CustomerExportResidual -RelativePath $path -Bytes $bytes `
                    -Markers @($Manifest.residualMarkers) -Dispositions @($Manifest.residualDispositions) -Profile $Profile)) {
                    if ($residual.disposition -ceq 'Undisposed') {
                        $category = if ($residual.reason -ceq 'TenantStableIdentifier') { 'TenantStableIdentifier' } else { 'UndisposedResidual' }
                        $denied.Add([pscustomobject]@{ category = $category; path = $path })
                    }
                }
            }
            catch { $denied.Add([pscustomobject]@{ category = 'UnsupportedContent'; path = $path }) }
        }
        if (@($inventory.findings).Count -eq 0) { $digest = Get-RunbookContentDigest $tree }
    }
    catch { $denied.Add([pscustomobject]@{ category = 'ObjectInspectionUnavailable'; path = $null }) }
    [pscustomobject]@{
        actualFileCount = $actualCount; contentTreeDigest = $digest
        unexpectedPaths = @($unexpected); missingPaths = @($missing); mismatchedPaths = @($mismatched)
        deniedFindings = @($denied)
        passed = $unexpected.Count + $missing.Count + $mismatched.Count + $denied.Count -eq 0
    }
}

function Merge-RepositoryExportInspection {
    param([object]$Result, [object]$Inspection)
    $Result.actualFileCount = $Inspection.actualFileCount
    $Result.contentTreeDigest = $Inspection.contentTreeDigest
    foreach ($field in @('unexpectedPaths', 'missingPaths', 'mismatchedPaths')) {
        $paths = [Collections.Generic.HashSet[string]]::new([string[]]@($Result.$field + $Inspection.$field), [StringComparer]::Ordinal)
        [string[]]$ordered = @($paths)
        [Array]::Sort($ordered, [StringComparer]::Ordinal)
        $Result.$field = $ordered
    }
    $Result.deniedFindings = @($Result.deniedFindings) + @($Inspection.deniedFindings)
}
