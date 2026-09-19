function Test-ProhibitedData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$InputObject,

        [string]$ApprovedUpn
    )

    $json = ConvertTo-DiscoveryCompressedJson -InputObject $InputObject
    $pattern = '(?i)(access[_-]?token|refresh[_-]?token|client[_-]?secret|authorization:\s*bearer|AccountKey=|SharedAccessSignature=|-----BEGIN .*PRIVATE KEY-----|sig=|eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)'
    if ($json -match $pattern) {
        throw 'Normalized discovery evidence contains prohibited credential or token material.'
    }

    function Test-DiscoveryEmailPaths {
        param(
            [AllowNull()]
            [object]$Value,

            [AllowEmptyString()]
            [string]$Path,

            [string]$ApprovedEmail
        )

        if ($null -eq $Value) {
            return
        }

        if ($Value -is [string]) {
            $emailMatches = [regex]::Matches($Value, '(?i)\b[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}\b')
            foreach ($match in $emailMatches) {
                $isApprovedPrincipalUpn = $Path -ceq 'Principal.Upn' -and -not [string]::IsNullOrWhiteSpace($ApprovedEmail) -and $match.Value -ieq $ApprovedEmail
                if (-not $isApprovedPrincipalUpn) {
                    throw 'Normalized discovery evidence contains a prohibited email address.'
                }
            }

            return
        }

        if ($Value -is [System.Array] -or $Value -is [System.Collections.IList]) {
            $index = 0
            foreach ($item in @($Value)) {
                Test-DiscoveryEmailPaths -Value $item -Path ("{0}[{1}]" -f $Path, $index) -ApprovedEmail $ApprovedEmail
                $index++
            }

            return
        }

        if ($Value -is [System.Collections.IDictionary] -or @($Value.PSObject.Properties).Count -gt 0) {
            $entries = Get-ObjectEntryTable -InputObject $Value
            foreach ($key in $entries.Keys) {
                $childPath = if ([string]::IsNullOrWhiteSpace($Path)) { [string]$key } else { "$Path.$key" }
                Test-DiscoveryEmailPaths -Value $entries[$key] -Path $childPath -ApprovedEmail $ApprovedEmail
            }

            return
        }
    }

    Test-DiscoveryEmailPaths -Value $InputObject -Path '' -ApprovedEmail $ApprovedUpn

    $true
}