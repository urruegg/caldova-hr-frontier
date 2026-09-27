function Get-CustomerExportResidual {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)][string]$StagingRoot,
        [Parameter(Mandatory)][object[]]$Markers,
        [AllowEmptyCollection()][object[]]$Dispositions = @(),
        [AllowEmptyCollection()][object[]]$InspectableBinaries = @()
    )

    $root = [IO.Path]::GetFullPath($StagingRoot)
    $results = [Collections.Generic.List[object]]::new()
    foreach ($item in Get-ChildItem -LiteralPath $root -Recurse -Force) {
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            continue
        }
        $relative = Get-RunbookRelativePath -Root $root -Path $item.FullName
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

        $bytes = [IO.File]::ReadAllBytes($item.FullName)
        try {
            $textKind = Get-CustomerExportTextKind -Path $relative -Bytes $bytes -InspectableBinaries $InspectableBinaries
        }
        catch {
            continue
        }
        if ([string]$textKind.kind -ne 'Utf8Text') {
            continue
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
        $disposition = @($Dispositions | Where-Object { $_.path -ceq $result.path -and $_.markerId -ceq $result.markerId }) | Select-Object -First 1
        if ($null -ne $disposition) {
            $result.disposition = 'Disposed'
            $result.reason = $disposition.reason
        }
    }

    return @($results | Sort-Object path, location, markerId)
}
