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
    if ($Bytes.Length -ge 3 -and $Bytes[0] -eq 0xEF -and $Bytes[1] -eq 0xBB -and $Bytes[2] -eq 0xBF) {
        throw 'Customer export text must be UTF-8 without BOM.'
    }

    foreach ($byte in $Bytes) {
        if ($byte -eq 0x00) {
            $digest = Get-CustomerExportSha256 -Bytes $Bytes
            $match = @($InspectableBinaries | Where-Object { $_.path -ceq $Path -and $_.sha256 -ceq $digest }) | Select-Object -First 1
            if ($null -eq $match) {
                throw 'Customer export binary content must be explicitly allowlisted.'
            }
            return [pscustomobject]@{ kind = 'InspectableBinary'; digest = $digest }
        }
    }

    $text = [Text.UTF8Encoding]::new($false, $true).GetString($Bytes)
    return [pscustomobject]@{ kind = 'Utf8Text'; text = $text }
}
