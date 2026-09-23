function New-TenantSuffix {
    [CmdletBinding()]
    param()

    $alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789'
    $characters = New-Object System.Collections.Generic.List[char]
    $buffer = New-Object byte[] 32
    $generator = [System.Security.Cryptography.RandomNumberGenerator]::Create()

    try {
        while ($characters.Count -lt 6) {
            $generator.GetBytes($buffer)
            foreach ($value in $buffer) {
                if ($value -ge 252) {
                    continue
                }

                [void]$characters.Add($alphabet[$value % 36])
                if ($characters.Count -eq 6) {
                    break
                }
            }
        }
    }
    finally {
        $generator.Dispose()
    }

    -join $characters
}