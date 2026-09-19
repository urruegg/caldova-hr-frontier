function ConvertTo-DiscoveryCompressedJson {
    param(
        [AllowNull()]
        [object]$InputObject
    )

    if ($null -eq $InputObject) {
        return '{}'
    }

    if ($InputObject -is [string]) {
        return [string]$InputObject
    }

    $InputObject | ConvertTo-Json -Depth 50 -Compress
}

function ConvertTo-DiscoveryUtcString {
    param(
        [Parameter(Mandatory)]
        [datetime]$Value
    )

    $utcValue = if ($Value.Kind -eq [System.DateTimeKind]::Utc) { $Value } else { $Value.ToUniversalTime() }
    $utcValue.ToString('o')
}

function ConvertFrom-DiscoveryUtcString {
    param(
        [Parameter(Mandatory)]
        [string]$Value,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $parsed = [datetime]::MinValue
    if (-not [datetime]::TryParse($Value, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind, [ref]$parsed)) {
        throw "$Path must be a valid UTC round-trip timestamp."
    }

    if ($parsed.Kind -ne [System.DateTimeKind]::Utc -or $parsed.ToString('o') -cne $Value) {
        throw "$Path must be a canonical UTC round-trip timestamp."
    }

    $parsed
}

function Get-DiscoverySha256 {
    param(
        [AllowNull()]
        [object]$InputObject
    )

    $json = ConvertTo-DiscoveryCompressedJson -InputObject $InputObject
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    $hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
    -join ($hash | ForEach-Object { $_.ToString('x2') })
}

function Get-DiscoveryResponseBody {
    param(
        [Parameter(Mandatory)]
        [object]$Response
    )

    $entries = Get-ObjectEntryTable -InputObject $Response
    if (-not $entries.Contains('Body')) {
        return $null
    }

    $entries.Body
}

function Get-DiscoveryStatusCode {
    param(
        [Parameter(Mandatory)]
        [object]$Response
    )

    $entries = Get-ObjectEntryTable -InputObject $Response
    if (-not $entries.Contains('StatusCode')) {
        throw 'Discovery adapter responses must include StatusCode.'
    }

    [int]$entries.StatusCode
}

function Get-DiscoveryHeaders {
    param(
        [Parameter(Mandatory)]
        [object]$Response
    )

    $entries = Get-ObjectEntryTable -InputObject $Response
    if (-not $entries.Contains('Headers') -or $null -eq $entries.Headers) {
        return @{}
    }

    if ($entries.Headers -is [System.Collections.IDictionary]) {
        return $entries.Headers
    }

    Get-ObjectEntryTable -InputObject $entries.Headers
}

function Get-DiscoveryPropertyValue {
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$InputObject,

        [Parameter(Mandatory)]
        [string]$Name,

        [switch]$Required
    )

    if ($null -eq $InputObject) {
        if ($Required) {
            throw "Expected property $Name."
        }

        return $null
    }

    $entries = Get-ObjectEntryTable -InputObject $InputObject
    if ($entries.Contains($Name)) {
        return $entries[$Name]
    }

    if ($Required) {
        throw "Expected property $Name."
    }

    $null
}

function New-DiscoveryServiceResult {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Status,

        [Parameter(Mandatory)]
        [string]$SourceApi,

        [Parameter(Mandatory)]
        [datetime]$CollectedUtc,

        [AllowEmptyCollection()]
        [object[]]$Resources = @(),

        [AllowNull()]
        [object]$RawPayload = $null
    )

    [pscustomobject][ordered]@{
        Name = $Name
        Status = $Status
        SourceApi = $SourceApi
        CollectedUtc = $CollectedUtc
        Resources = @($Resources)
        RawPayload = $RawPayload
    }
}

function Get-DiscoveryRetryDelaySeconds {
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Headers,

        [Parameter(Mandatory)]
        [datetime]$NowUtc
    )

    foreach ($key in @('Retry-After', 'retry-after')) {
        if (-not $Headers.Contains($key)) {
            continue
        }

        $value = [string]$Headers[$key]
        $seconds = 0
        if ([int]::TryParse($value, [ref]$seconds)) {
            return [Math]::Max(0, $seconds)
        }

        $retryAt = [datetime]::MinValue
        if ([datetime]::TryParse($value, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AdjustToUniversal, [ref]$retryAt)) {
            $delay = [int][Math]::Ceiling(($retryAt.ToUniversalTime() - $NowUtc).TotalSeconds)
            return [Math]::Max(0, $delay)
        }
    }

    0
}

function Invoke-DiscoveryNativeCommand {
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,

        [Parameter(Mandatory)]
        [string[]]$ArgumentList
    )

    $output = & $FilePath @ArgumentList 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "$FilePath failed while executing discovery request."
    }

    $text = ($output | Out-String).Trim()
    if ([string]::IsNullOrWhiteSpace($text)) {
        return [pscustomobject]@{
            StatusCode = 404
            Headers = @{}
            Body = $null
        }
    }

    try {
        $body = $text | ConvertFrom-Json
    }
    catch {
        throw "$FilePath returned unexpected non-JSON discovery output."
    }

    [pscustomobject]@{
        StatusCode = 200
        Headers = @{}
        Body = $body
    }
}

function Invoke-BoundedRetry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$Request,

        [Parameter(Mandatory)]
        [string]$Operation,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Arguments,

        [int]$MaxAttempts = 5,

        [scriptblock]$Sleeper = {
            param($DelaySeconds)
            Start-Sleep -Seconds $DelaySeconds
        },

        [scriptblock]$Clock = {
            [datetime]::UtcNow
        }
    )

    if ($MaxAttempts -lt 1) {
        throw 'MaxAttempts must be at least one.'
    }

    $attempt = 0
    $response = $null
    do {
        $attempt++
        $response = & $Request -Operation $Operation -Arguments $Arguments
        $statusCode = Get-DiscoveryStatusCode -Response $response
        if ($statusCode -notin @(408, 429) -and ($statusCode -lt 500 -or $statusCode -gt 599)) {
            return $response
        }

        if ($attempt -ge $MaxAttempts) {
            return $response
        }

        $headers = Get-DiscoveryHeaders -Response $response
        $nowUtc = & $Clock
        $delaySeconds = Get-DiscoveryRetryDelaySeconds -Headers $headers -NowUtc $nowUtc
        if ($delaySeconds -gt 0) {
            & $Sleeper $delaySeconds
        }
    } while ($attempt -lt $MaxAttempts)

    $response
}