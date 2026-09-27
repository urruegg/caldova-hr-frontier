function Convert-CustomerExportBlob {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][byte[]]$OriginalBytes,
        [AllowEmptyCollection()][object[]]$Rules = @()
    )

    $normalizedPath = Test-CustomerExportRelativePath -Path $Path
    if (@($Rules).Count -eq 0) {
        return [pscustomobject]@{ bytes = $OriginalBytes; replacementLog = @() }
    }

    $logs = [Collections.Generic.List[object]]::new()
    $currentBytes = $OriginalBytes
    $formats = @($Rules | ForEach-Object { [string]$_.format } | Select-Object -Unique)
    if ($formats.Count -ne 1) {
        throw 'Customer export replacement paths must not mix formats.'
    }

    switch ($formats[0]) {
        'Json' {
            $textKind = Get-CustomerExportTextKind -Path $normalizedPath -Bytes $currentBytes
            $document = ConvertFrom-CustomerExportJson -Text $textKind.text
            foreach ($rule in @($Rules)) {
                $pointer = ConvertFrom-JsonPointer -InputObject $document -Pointer ([string]$rule.selector)
                $oldDigest = Get-RunbookContentDigest -InputObject $pointer.value
                $expectedDigest = Get-RunbookContentDigest -InputObject $rule.expectedOldValue
                if ($oldDigest -cne $expectedDigest) {
                    throw 'JSON Pointer expected-old value does not match the committed blob.'
                }
                if ($pointer.parent -is [array]) {
                    $pointer.parent[$pointer.member] = $rule.newValue
                }
                else {
                    $pointer.parent.PSObject.Properties[$pointer.member].Value = $rule.newValue
                }
                $newDigest = Get-RunbookContentDigest -InputObject $rule.newValue
                $logs.Add([pscustomobject]@{
                    ruleId = $rule.id
                    path = $normalizedPath
                    format = 'Json'
                    selector = $rule.selector
                    replacementCount = 1
                    oldValueDigest = $oldDigest
                    newValueDigest = $newDigest
                })
            }
            $canonical = ConvertTo-CanonicalJsonValue -Value $document -RemainingDepth 30
            $currentBytes = [Text.UTF8Encoding]::new($false).GetBytes(($canonical | ConvertTo-Json -Depth 30 -Compress))
        }
        'MarkdownExact' {
            $textKind = Get-CustomerExportTextKind -Path $normalizedPath -Bytes $currentBytes
            $text = [string]$textKind.text
            $hasCrLf = $text.Contains("`r`n")
            $hasBareLf = ($text -replace "`r`n", '').Contains("`n")
            if ($hasCrLf -and $hasBareLf) {
                throw 'MarkdownExact content must not mix newline styles.'
            }
            $newlineKind = if ($hasCrLf) { 'CRLF' } elseif ($hasBareLf) { 'LF' } else { 'None' }

            foreach ($rule in @($Rules)) {
                $needle = [string]$rule.expectedOldText
                $replacement = [string]$rule.newText
                $count = 0
                $offset = 0
                $positions = [Collections.Generic.List[int]]::new()
                while ($true) {
                    $index = $text.IndexOf($needle, $offset, [StringComparison]::Ordinal)
                    if ($index -lt 0) { break }
                    $positions.Add($index)
                    $count++
                    $offset = $index + $needle.Length
                }
                if ($count -ne [int]$rule.requiredCount) {
                    throw 'MarkdownExact required occurrence count was not satisfied.'
                }

                $builder = [Text.StringBuilder]::new()
                $cursor = 0
                foreach ($position in $positions) {
                    [void]$builder.Append($text.Substring($cursor, $position - $cursor))
                    [void]$builder.Append($replacement)
                    $cursor = $position + $needle.Length
                }
                [void]$builder.Append($text.Substring($cursor))
                $text = $builder.ToString()
                $logs.Add([pscustomobject]@{
                    ruleId = $rule.id
                    path = $normalizedPath
                    format = 'MarkdownExact'
                    selector = $null
                    replacementCount = $count
                    oldValueDigest = Get-RunbookContentDigest -InputObject $needle
                    newValueDigest = Get-RunbookContentDigest -InputObject $replacement
                })
            }

            if ($newlineKind -eq 'CRLF' -and ($text -replace "`r`n", '').Contains("`n")) {
                throw 'MarkdownExact replacement changed the newline style.'
            }
            if ($newlineKind -eq 'LF' -and $text.Contains("`r`n")) {
                throw 'MarkdownExact replacement changed the newline style.'
            }
            $currentBytes = [Text.UTF8Encoding]::new($false).GetBytes($text)
        }
        default {
            throw 'Customer export replacement format is not supported.'
        }
    }

    return [pscustomobject]@{
        bytes = $currentBytes
        replacementLog = @($logs)
    }
}
