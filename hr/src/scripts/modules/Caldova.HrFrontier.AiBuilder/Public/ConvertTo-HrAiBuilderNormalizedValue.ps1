function ConvertTo-HrAiBuilderNormalizedValue {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Value,

        [Parameter(Mandatory)]
        [ValidateSet('Text', 'Date')]
        [string]$FieldType
    )

    if ($null -eq $Value) {
        return $null
    }

    $rawValue = [string]$Value
    if ([string]::IsNullOrWhiteSpace($rawValue)) {
        return $null
    }

    switch ($FieldType) {
        'Text' {
            $normalized = $rawValue.Normalize([Text.NormalizationForm]::FormKC).Trim()
            $normalized = [regex]::Replace($normalized, '\s+', ' ')
            if ([string]::IsNullOrWhiteSpace($normalized)) {
                return $null
            }

            return $normalized
        }

        'Date' {
            $trimmed = $rawValue.Trim()
            $parsed = [datetime]::MinValue
            if (-not [datetime]::TryParseExact(
                    $trimmed,
                    'dd.MM.yyyy',
                    [System.Globalization.CultureInfo]::InvariantCulture,
                    [System.Globalization.DateTimeStyles]::None,
                    [ref]$parsed)) {
                throw "Invalid Date value '$trimmed'."
            }

            return $parsed.ToString('yyyy-MM-dd')
        }
    }
}
