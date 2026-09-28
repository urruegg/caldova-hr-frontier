function Complete-HrAiBuilderRunManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$SolutionVersion,

        [Parameter(Mandatory)]
        [string[]]$EvidencePaths
    )

    $manifest = Read-HrAiBuilderJson -Path $Path -Description 'Run manifest'
    if ($manifest.finalized) {
        throw "Run manifest '$Path' is already finalized."
    }

    $inventoryPath = Get-HrAiBuilderInventoryPathFromManifest -ManifestPath $Path
    $inventory = Read-HrAiBuilderJson -Path $inventoryPath -Description 'Model inventory'

    $metricsPath = @($EvidencePaths | Where-Object { [IO.Path]::GetFileName($_) -ieq 'evaluation-metrics.json' })
    if ($metricsPath.Count -ne 1) {
        throw 'Complete-HrAiBuilderRunManifest requires exactly one evaluation-metrics.json evidence file.'
    }

    $metrics = Read-HrAiBuilderJson -Path $metricsPath[0] -Description 'Evaluation metrics'
    $dispositions = @{}
    foreach ($model in @($metrics.models)) {
        $dispositions[[string]$model.display_name] = [string]$model.strict_gate_disposition
    }

    $qualifiedCount = 0
    foreach ($knownModel in Get-HrAiBuilderKnownModels) {
        $record = @($inventory.models | Where-Object display_name -eq $knownModel.display_name)
        if ($record.Count -ne 1) {
            continue
        }

        $record = $record[0]
        $disposition = $dispositions[[string]$knownModel.display_name]
        if ([string]$record.lifecycle_stage -eq 'added_to_solution' -and $disposition -eq 'evaluated') {
            $qualifiedCount++
        }
    }

    $overallStatus = if ($qualifiedCount -eq 2) {
        'technically_complete'
    }
    elseif ($qualifiedCount -eq 1) {
        'partially_complete'
    }
    else {
        'blocked'
    }

    $manifest.models = @($inventory.models)
    $manifest.solution_version = $SolutionVersion
    $manifest.completed_at_utc = [datetime]::UtcNow.ToString('o')
    $manifest.overall_status = $overallStatus
    $manifest.evidence_hashes = @(
        foreach ($evidencePath in $EvidencePaths) {
            [ordered]@{
                file_name = [IO.Path]::GetFileName($evidencePath)
                path = $evidencePath
                sha256 = Get-HrAiBuilderFileSha256 -Path $evidencePath
            }
        }
    )
    $manifest.finalized = $true

    Write-HrAiBuilderJson -InputObject $manifest -Path $Path
    return Read-HrAiBuilderJson -Path $Path -Description 'Run manifest'
}
