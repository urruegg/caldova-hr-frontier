function Get-CustomerExportResidual {
    [CmdletBinding(DefaultParameterSetName = 'Tree')]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Tree')][string]$StagingRoot,
        [Parameter(Mandatory, ParameterSetName = 'Blob')][string]$RelativePath,
        [Parameter(Mandatory, ParameterSetName = 'Blob')][AllowEmptyCollection()][byte[]]$Bytes,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Markers,
        [AllowEmptyCollection()][object[]]$Dispositions = @(),
        [AllowEmptyCollection()][object[]]$InspectableBinaries = @(),
        [ValidateScript({ $_ -cin @('TenantReplica', 'CustomerHandover') })][string]$Profile
    )

    $blobMode = $PSCmdlet.ParameterSetName -ceq 'Blob'
    $root = if (-not $blobMode) { [IO.Path]::GetFullPath($StagingRoot) }
    $results = [Collections.Generic.List[object]]::new()
    $items = if ($blobMode) {
        $relative = Test-CustomerExportRelativePath -Path $RelativePath
        $segments = @($relative -split '/')
        for ($index = 0; $index -lt ($segments.Count - 1); $index++) {
            [pscustomobject]@{ Attributes = 0; PSIsContainer = $true; FullName = ($segments[0..$index] -join '/'); Name = $segments[$index] }
        }
        [pscustomobject]@{ Attributes = 0; PSIsContainer = $false; FullName = $relative; Name = $segments[-1] }
    }
    else { Get-ChildItem -LiteralPath $root -Recurse -Force }
    foreach ($item in $items) {
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            continue
        }
        $relative = if ($blobMode) { $item.FullName } else { Get-RunbookRelativePath -Root $root -Path $item.FullName }
        if ($item.PSIsContainer) {
            foreach ($segment in @($relative -split '/')) {
                foreach ($marker in @($Markers)) {
                    $comparison = if ([string]$marker.comparison -ceq 'OrdinalIgnoreCase') { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
                    if ($segment.IndexOf([string]$marker.value, $comparison) -ge 0) {
                        $results.Add([pscustomobject]@{
                            path = $relative
                            location = "DirectoryName:$segment"
                            markerId = $marker.id
                            category = $marker.category
                            disposition = 'Undisposed'
                            reason = $null
                        })
                    }
                }
            }
            continue
        }

        foreach ($marker in @($Markers)) {
            $comparison = if ([string]$marker.comparison -ceq 'OrdinalIgnoreCase') { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
            if ($item.Name.IndexOf([string]$marker.value, $comparison) -ge 0) {
                $results.Add([pscustomobject]@{
                    path = $relative
                    location = 'FileName'
                    markerId = $marker.id
                    category = $marker.category
                    disposition = 'Undisposed'
                    reason = $null
                })
            }
        }

        $contentBytes = if ($blobMode) { $Bytes } else { [IO.File]::ReadAllBytes($item.FullName) }
        $textKind = Get-CustomerExportTextKind -Path $relative -Bytes $contentBytes -InspectableBinaries $InspectableBinaries
        if ($textKind.text.IndexOf([char]0) -ge 0) {
            # NUL-bearing bytes can hide BOM-less wide text; binary authorization cannot prove its encoding.
            throw 'Customer export residual inspection does not support NUL-bearing binary content.'
        }

        $lineNumber = 1
        foreach ($line in ($textKind.text -split "`r`n|`n")) {
            foreach ($marker in @($Markers)) {
                $comparison = if ([string]$marker.comparison -ceq 'OrdinalIgnoreCase') { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
                $offset = 0
                while ($true) {
                    $index = $line.IndexOf([string]$marker.value, $offset, $comparison)
                    if ($index -lt 0) { break }
                    $results.Add([pscustomobject]@{
                        path = $relative
                        location = ('Line:{0}:Column:{1}' -f $lineNumber, ($index + 1))
                        markerId = $marker.id
                        category = $marker.category
                        disposition = 'Undisposed'
                        reason = $null
                    })
                    $offset = $index + [string]$marker.value.Length
                }
            }
            $lineNumber++
        }
    }

    foreach ($result in $results) {
        if ($Profile -ceq 'TenantReplica' -and
            (Get-RepositoryExportFixedPolicy -Profile $Profile).stableMarkerCategories -ccontains $result.category) {
            $result.reason = 'TenantStableIdentifier'
            continue
        }
        $disposition = @($Dispositions | Where-Object { $_.path -ceq $result.path -and $_.markerId -ceq $result.markerId }) | Select-Object -First 1
        if ($null -ne $disposition) {
            $result.disposition = 'Disposed'
            $result.reason = $disposition.reason
        }
    }

    return @($results | Sort-Object path, location, markerId)
}
