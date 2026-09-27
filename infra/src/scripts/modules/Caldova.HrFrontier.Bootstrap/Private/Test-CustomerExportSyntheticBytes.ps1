function Test-CustomerExportSyntheticBytes {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][byte[]]$Bytes,
        [Parameter(Mandatory)][object]$SyntheticDataPolicy
    )

    $findings = [Collections.Generic.List[object]]::new()
    try {
        $textKind = Get-CustomerExportTextKind -Path $Path -Bytes $Bytes
    }
    catch {
        return [pscustomobject]@{ status = 'Inconclusive'; findings = @([pscustomobject]@{ path = $Path; category = 'Binary'; reason = 'Unclassified binary content.' }) }
    }

    if ([string]$textKind.kind -ne 'Utf8Text') {
        return [pscustomobject]@{ status = 'Inconclusive'; findings = @([pscustomobject]@{ path = $Path; category = 'Binary'; reason = 'Inspectable binary requires reviewed classification.' }) }
    }

    $text = [string]$textKind.text
    $isJson = $Path.EndsWith('.json', [StringComparison]::OrdinalIgnoreCase)
    $isMarkdown = $Path.EndsWith('.md', [StringComparison]::OrdinalIgnoreCase)
    $reservedNames = @($SyntheticDataPolicy.reservedNames)
    $reservedDomains = @($SyntheticDataPolicy.reservedDomains)
    $reservedPrefixes = @($SyntheticDataPolicy.reservedIdPrefixes)

    function Test-ReservedDomain([string]$Value) {
        foreach ($domain in $reservedDomains) {
            if ($Value.EndsWith('@' + $domain, [StringComparison]::OrdinalIgnoreCase)) { return $true }
        }
        return $false
    }

    function Test-ReservedName([string]$Value) {
        foreach ($name in $reservedNames) {
            if ([string]::Equals($Value.Trim(), [string]$name, [StringComparison]::Ordinal)) { return $true }
        }
        return $false
    }

    function Test-ReservedIdentifier([string]$Value) {
        foreach ($prefix in $reservedPrefixes) {
            if ($Value.StartsWith([string]$prefix, [StringComparison]::OrdinalIgnoreCase)) { return $true }
        }
        return $false
    }

    if ($isJson) {
        try {
            $document = ConvertFrom-CustomerExportJson -Text $text
            $stack = [Collections.Generic.Stack[object]]::new()
            $stack.Push([pscustomobject]@{ prefix = ''; value = $document })
            while ($stack.Count -gt 0) {
                $entry = $stack.Pop()
                if ($entry.value -is [array]) {
                    foreach ($item in $entry.value) {
                        $stack.Push([pscustomobject]@{ prefix = $entry.prefix; value = $item })
                    }
                    continue
                }
                if ($entry.value -is [pscustomobject] -or $entry.value -is [hashtable]) {
                    foreach ($property in $entry.value.PSObject.Properties) {
                        $key = [string]$property.Name
                        $value = $property.Value
                        $fullKey = if ([string]::IsNullOrWhiteSpace($entry.prefix)) { $key } else { $entry.prefix + '.' + $key }
                        if ($value -is [pscustomobject] -or $value -is [hashtable] -or $value -is [array]) {
                            $stack.Push([pscustomobject]@{ prefix = $fullKey; value = $value })
                            continue
                        }
                        $scalar = [string]$value
                        if ($key -match '(?i)^(person|worker|employee|candidate|user|account|national|passport|tax|payroll).*(id|number)?$' -and -not (Test-ReservedIdentifier $scalar)) {
                            $findings.Add([pscustomobject]@{ path = $Path; category = 'Identity'; reason = $fullKey })
                        }
                        if ($key -match '(?i)(email|mail|phone|mobile|contact)') {
                            if ($scalar -match '@' -and -not (Test-ReservedDomain $scalar)) {
                                $findings.Add([pscustomobject]@{ path = $Path; category = 'Contact'; reason = $fullKey })
                            }
                            elseif ($scalar -match '(?<!\d)(\+\d[\d\s-]{6,}\d|\d{3,}[\s-]\d{2,})(?!\d)') {
                                $findings.Add([pscustomobject]@{ path = $Path; category = 'Contact'; reason = $fullKey })
                            }
                        }
                        if ($key -match '(?i)(dateofbirth|birthdate|dob|hiredate|terminationdate|startdate|enddate)$' -and $scalar -match '\b(19|20)\d{2}[-/\.]\d{2}[-/\.]\d{2}\b') {
                            $findings.Add([pscustomobject]@{ path = $Path; category = 'Date'; reason = $fullKey })
                        }
                    }
                }
            }
        }
        catch {
            return [pscustomobject]@{ status = 'Inconclusive'; findings = @([pscustomobject]@{ path = $Path; category = 'Parse'; reason = 'Structured file could not be parsed.' }) }
        }
    }
    elseif (-not $isMarkdown) {
        $findings.Add([pscustomobject]@{
            path = $Path
            category = 'UnsupportedTextFormat'
            reason = 'Unsupported UTF-8 text format requires reviewed classification.'
        })
    }

    foreach ($match in [regex]::Matches($text, '[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}', 'IgnoreCase')) {
        if (-not (Test-ReservedDomain $match.Value)) {
            $findings.Add([pscustomobject]@{ path = $Path; category = 'Contact'; reason = 'EmailAddress' })
        }
    }
    if ($text -match '(?im)^\s*(phone|mobile|contact)\s*:\s*(.+)$') {
        $findings.Add([pscustomobject]@{ path = $Path; category = 'Contact'; reason = 'PhoneLabel' })
    }
    if ($text -match '(?im)^\s*(home\s+address|address|street|city|postal|zip|country)\s*:\s*(.+)$') {
        $findings.Add([pscustomobject]@{ path = $Path; category = 'Address'; reason = 'AddressLabel' })
    }
    if ($text -match '(?im)^\s*(employee|worker|candidate|user).*(id|number)?\s*:\s*([^\r\n]+)$') {
        $value = $matches[3].Trim()
        if (-not (Test-ReservedIdentifier $value)) {
            $findings.Add([pscustomobject]@{ path = $Path; category = 'Identity'; reason = 'IdentityLabel' })
        }
    }
    if ($text -match '(?im)^\s*([A-Za-z ]*name)\s*:\s*([^\r\n]+)$') {
        $value = $matches[2].Trim()
        if (-not (Test-ReservedName $value)) {
            $findings.Add([pscustomobject]@{ path = $Path; category = 'Name'; reason = 'NameLabel' })
        }
        else {
            $findings.Add([pscustomobject]@{ path = $Path; category = 'ReviewedName'; reason = 'ReservedNameNeedsReview' })
        }
    }

    $status = 'Passed'
    if (@($findings | Where-Object { $_.category -in @('Identity', 'Contact', 'Address', 'Date') }).Count -gt 0) {
        $status = 'Failed'
    }
    elseif ($findings.Count -gt 0) {
        $status = 'Inconclusive'
    }

    return [pscustomobject]@{
        status = $status
        findings = @($findings)
    }
}
