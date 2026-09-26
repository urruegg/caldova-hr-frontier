function Get-RunbookContentDigest {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)] [object]$InputObject,
        [ValidateRange(2, 100)] [int]$Depth = 30
    )
    process {
        $canonical = ConvertTo-CanonicalJsonValue -Value $InputObject -RemainingDepth $Depth
        $json = ($canonical | ConvertTo-Json -Depth $Depth -Compress) + "`n"
        $bytes = [Text.UTF8Encoding]::new($false).GetBytes($json)
        $hash = [Security.Cryptography.SHA256]::Create()
        try {
            return [BitConverter]::ToString($hash.ComputeHash($bytes)).Replace('-', '').ToLowerInvariant()
        }
        finally {
            $hash.Dispose()
        }
    }
}
