function New-HrAiBuilderReadinessRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RunId,

        [Parameter(Mandatory)]
        [object[]]$Checks,

        [Parameter(Mandatory)]
        [string]$OutputPath
    )

    $knownIds = @(Get-HrAiBuilderKnownReadinessCheckIds)
    $checkIds = @($Checks | ForEach-Object { [string]$_.id })
    if (-not (Compare-HrAiBuilderSequence -Left @($checkIds | Sort-Object) -Right @($knownIds | Sort-Object))) {
        throw 'Readiness checks must contain exactly the eight known readiness gate IDs.'
    }

    foreach ($check in $Checks) {
        if ([string]$check.status -notin @('passed', 'failed', 'unknown')) {
            throw "Readiness check '$($check.id)' has invalid status '$($check.status)'."
        }

        foreach ($propertyName in 'observation', 'source', 'operator', 'observed_at_utc') {
            if (-not $check.PSObject.Properties.Name.Contains($propertyName) -or
                [string]::IsNullOrWhiteSpace([string]$check.$propertyName)) {
                throw "Readiness check '$($check.id)' must define non-empty '$propertyName'."
            }
        }
    }

    $failedGates = @(
        foreach ($check in $Checks) {
            if ([string]$check.status -ne 'passed') {
                [string]$check.id
            }
        }
    )

    $result = [ordered]@{
        schema_version = '1.0'
        run_id = $RunId
        status = if ($failedGates.Count -eq 0) { 'passed' } else { 'blocked' }
        failed_gates = @($failedGates)
        checks = @($Checks)
    }

    Write-HrAiBuilderJson -InputObject $result -Path $OutputPath
    return Read-HrAiBuilderJson -Path $OutputPath -Description 'Readiness record'
}
