function New-HrAiBuilderTestCapabilityRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RunId,

        [Parameter(Mandatory)]
        [string]$Mechanism,

        [switch]$MachineReadableValues,

        [switch]$PerFieldConfidence,

        [string]$RawExportPath,

        [string]$AdapterVersion,

        [string]$BlockedReason,

        [Parameter(Mandatory)]
        [string]$OutputPath
    )

    $isBlocked = -not [string]::IsNullOrWhiteSpace($BlockedReason)
    $isPassing = $MachineReadableValues.IsPresent -or $PerFieldConfidence.IsPresent -or
        -not [string]::IsNullOrWhiteSpace($RawExportPath) -or
        -not [string]::IsNullOrWhiteSpace($AdapterVersion)

    if ($isBlocked -and $isPassing) {
        throw 'Blocked and passing test-capability outcomes cannot be combined.'
    }

    if (-not $isBlocked -and -not $isPassing) {
        throw 'A test-capability record must be either blocked or passing.'
    }

    if ($isBlocked) {
        $result = [ordered]@{
            schema_version = '1.0'
            run_id = $RunId
            mechanism = $Mechanism
            status = 'blocked'
            machine_readable_values = $false
            per_field_confidence = $false
            blocked_reason = $BlockedReason
        }
    }
    else {
        if (-not $MachineReadableValues.IsPresent -or -not $PerFieldConfidence.IsPresent -or
            [string]::IsNullOrWhiteSpace($RawExportPath) -or
            [string]::IsNullOrWhiteSpace($AdapterVersion)) {
            throw 'A passing test-capability record requires machine-readable values, per-field confidence, a raw export path, and an adapter version.'
        }

        $result = [ordered]@{
            schema_version = '1.0'
            run_id = $RunId
            mechanism = $Mechanism
            status = 'passed'
            machine_readable_values = $true
            per_field_confidence = $true
            raw_export_path = $RawExportPath
            raw_export_sha256 = Get-HrAiBuilderFileSha256 -Path $RawExportPath
            adapter_version = $AdapterVersion
        }
    }

    Write-HrAiBuilderJson -InputObject $result -Path $OutputPath
    return Read-HrAiBuilderJson -Path $OutputPath -Description 'Model test capability record'
}
