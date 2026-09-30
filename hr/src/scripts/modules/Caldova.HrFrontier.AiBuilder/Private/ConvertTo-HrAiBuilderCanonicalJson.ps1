function ConvertTo-HrAiBuilderCanonicalJson {
    [CmdletBinding()]
    [OutputType([byte[]])]
    param(
        [Parameter(Mandatory)]
        [object]$InputObject
    )

    $json = $InputObject | ConvertTo-Json -Depth 30 -Compress
    $normalized = $json.Replace("`r`n", "`n").Replace("`r", "`n") + "`n"
    return [Text.UTF8Encoding]::new($false).GetBytes($normalized)
}
