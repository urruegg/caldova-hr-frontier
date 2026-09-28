function Set-HrAiBuilderModelRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RunManifestPath,

        [Parameter(Mandatory)]
        [string]$ModelInventoryPath,

        [Parameter(Mandatory)]
        [string]$ModelName,

        [string]$ModelId,

        [string]$ModelVersion,

        [Parameter(Mandatory)]
        [ValidateSet('created', 'schema_defined', 'tagged', 'trained', 'evaluated', 'published', 'added_to_solution', 'blocked')]
        [string]$LifecycleStage
    )

    $manifest = Read-HrAiBuilderJson -Path $RunManifestPath -Description 'Run manifest'
    Assert-HrAiBuilderManifestMutable -Manifest $manifest -Path $RunManifestPath
    $inventory = Read-HrAiBuilderJson -Path $ModelInventoryPath -Description 'Model inventory'

    $manifestModel = @($manifest.models | Where-Object display_name -eq $ModelName)
    $inventoryModel = @($inventory.models | Where-Object display_name -eq $ModelName)
    if ($manifestModel.Count -ne 1 -or $inventoryModel.Count -ne 1) {
        throw "Unknown model '$ModelName'."
    }

    $manifestModel = $manifestModel[0]
    $inventoryModel = $inventoryModel[0]
    $order = @(Get-HrAiBuilderLifecycleOrder)
    $currentStage = [string]$inventoryModel.lifecycle_stage
    $currentIndex = $order.IndexOf($currentStage)
    if ($currentIndex -lt 0) {
        throw "Model '$ModelName' has an unknown lifecycle stage '$currentStage'."
    }

    $allowed = $false
    if ($LifecycleStage -eq 'blocked') {
        $allowed = ($currentStage -ne 'added_to_solution' -and $currentStage -ne 'blocked')
    }
    else {
        $targetIndex = $order.IndexOf($LifecycleStage)
        $allowed = ($targetIndex -eq ($currentIndex + 1))
    }

    if (-not $allowed) {
        throw "Illegal lifecycle transition from '$currentStage' to '$LifecycleStage' for model '$ModelName'."
    }

    foreach ($model in @($manifestModel, $inventoryModel)) {
        if ($PSBoundParameters.ContainsKey('ModelId')) {
            $model.model_id = $ModelId
        }

        if ($PSBoundParameters.ContainsKey('ModelVersion')) {
            $model.version = $ModelVersion
        }

        $model.lifecycle_stage = $LifecycleStage
        $history = @($model.lifecycle_history)
        $history += [ordered]@{
            stage = $LifecycleStage
            changed_at_utc = [datetime]::UtcNow.ToString('o')
        }
        $model.lifecycle_history = @($history)
    }

    Write-HrAiBuilderJson -InputObject $manifest -Path $RunManifestPath
    Write-HrAiBuilderJson -InputObject $inventory -Path $ModelInventoryPath
    return Read-HrAiBuilderJson -Path $RunManifestPath -Description 'Run manifest'
}
