function Get-CustomerExportTextKind {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][byte[]]$Bytes,
        [AllowEmptyCollection()][object[]]$InspectableBinaries = @()
    )

    if ($Bytes.Length -ge 2) {
        if (($Bytes[0] -eq 0xFF -and $Bytes[1] -eq 0xFE) -or ($Bytes[0] -eq 0xFE -and $Bytes[1] -eq 0xFF)) {
            throw 'Customer export text must be UTF-8 without BOM.'
        }
    }
    if ($Bytes.Length -ge 4) {
        if (($Bytes[0] -eq 0x00 -and $Bytes[1] -eq 0x00 -and $Bytes[2] -eq 0xFE -and $Bytes[3] -eq 0xFF) -or
            ($Bytes[0] -eq 0xFF -and $Bytes[1] -eq 0xFE -and $Bytes[2] -eq 0x00 -and $Bytes[3] -eq 0x00)) {
            throw 'Customer export text must be UTF-8 without BOM.'
        }
    }
    if ($Bytes.Length -ge 3 -and $Bytes[0] -eq 0xEF -and $Bytes[1] -eq 0xBB -and $Bytes[2] -eq 0xBF) {
        throw 'Customer export text must be UTF-8 without BOM.'
    }

    try {
        $text = [Text.UTF8Encoding]::new($false, $true).GetString($Bytes)
    }
    catch {
        throw 'Customer export text must be valid UTF-8.'
    }

    $isBinary = $false
    foreach ($byte in $Bytes) {
        if ($byte -eq 0x00) {
            $isBinary = $true
            break
        }
    }
    if (-not $isBinary) {
        foreach ($character in $text.ToCharArray()) {
            $codePoint = [int][char]$character
            if (($codePoint -lt 0x20 -and $codePoint -notin @(0x09, 0x0A, 0x0D)) -or
                $codePoint -eq 0x7F) {
                $isBinary = $true
                break
            }
        }
    }
    if ($isBinary) {
        $digest = Get-CustomerExportSha256 -Bytes $Bytes
        $match = @($InspectableBinaries | Where-Object { $_.path -ceq $Path -and $_.sha256 -ceq $digest }) | Select-Object -First 1
        if ($null -eq $match) {
            throw 'Customer export binary content must be explicitly allowlisted.'
        }
        return [pscustomobject]@{ kind = 'InspectableBinary'; digest = $digest }
    }

    $containsCrLf = $text.Contains("`r`n")
    $withoutCrLf = $text.Replace("`r`n", '')
    if ($withoutCrLf.Contains("`r") -or ($containsCrLf -and $withoutCrLf.Contains("`n"))) {
        throw 'Customer export text must use one newline style only.'
    }

    return [pscustomobject]@{ kind = 'Utf8Text'; text = $text }
}
