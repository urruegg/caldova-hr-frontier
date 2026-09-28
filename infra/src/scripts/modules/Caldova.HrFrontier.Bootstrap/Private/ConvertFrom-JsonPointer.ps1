function ConvertFrom-JsonPointer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowNull()][object]$InputObject,
        [Parameter(Mandatory)][string]$Pointer
    )

    if ([string]::IsNullOrWhiteSpace($Pointer) -or $Pointer -eq '/') {
        throw 'JSON Pointer must identify one exact value.'
    }
    if (-not $Pointer.StartsWith('/', [StringComparison]::Ordinal)) {
        throw 'JSON Pointer must start with /.'
    }

    $segments = @(
        foreach ($rawSegment in $Pointer.Substring(1).Split('/')) {
            if ($rawSegment -match '~(?![01])') {
                throw 'JSON Pointer contains an invalid escape sequence.'
            }
            $rawSegment.Replace('~1', '/').Replace('~0', '~')
        }
    )

    $current = $InputObject
    for ($index = 0; $index -lt $segments.Count - 1; $index++) {
        $segment = $segments[$index]
        if ($current -is [array]) {
            if ($segment -notmatch '^(0|[1-9][0-9]*)$') {
                throw 'JSON Pointer array indexes must be non-negative decimals.'
            }
            $current = $current[[int]$segment]
            continue
        }

        $entries = Get-ObjectEntryTable -InputObject $current
        $names = @($entries.Keys | ForEach-Object { [string]$_ })
        if ($names -notcontains $segment) {
            $matches = @($names | Where-Object { $_.Equals($segment, [StringComparison]::OrdinalIgnoreCase) })
            if ($matches.Count -ne 1) {
                throw 'JSON Pointer property is missing or ambiguous.'
            }
            $segment = $matches[0]
        }
        $current = $entries[$segment]
    }

    $finalSegment = $segments[-1]
    if ($current -is [array]) {
        if ($finalSegment -notmatch '^(0|[1-9][0-9]*)$') {
            throw 'JSON Pointer array indexes must be non-negative decimals.'
        }
        return [pscustomobject]@{
            parent = $current
            member = [int]$finalSegment
            value = $current[[int]$finalSegment]
        }
    }

    $entries = Get-ObjectEntryTable -InputObject $current
    $names = @($entries.Keys | ForEach-Object { [string]$_ })
    if ($names -notcontains $finalSegment) {
        $matches = @($names | Where-Object { $_.Equals($finalSegment, [StringComparison]::OrdinalIgnoreCase) })
        if ($matches.Count -ne 1) {
            throw 'JSON Pointer property is missing or ambiguous.'
        }
        $finalSegment = $matches[0]
    }

    return [pscustomobject]@{
        parent = $current
        member = $finalSegment
        value = $entries[$finalSegment]
    }
}
