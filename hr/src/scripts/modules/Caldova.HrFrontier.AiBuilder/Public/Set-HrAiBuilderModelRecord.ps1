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
        [ValidateSet('created', 'schema_defined', 'tagged', 'trained', 'evaluation_published', 'capture_validated', 'evaluated', 'approved_for_solution', 'added_to_solution', 'blocked')]
        [string]$LifecycleStage,

        [Parameter()]
        [switch]$ResumeBlockedEvaluation,

        [Parameter()]
        [string]$ResumeEvidencePath
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
    if ($currentStage -ne 'blocked' -and $currentIndex -lt 0) {
        throw "Model '$ModelName' has an unknown lifecycle stage '$currentStage'."
    }

    if (-not $ResumeBlockedEvaluation -and $PSBoundParameters.ContainsKey('ResumeEvidencePath')) {
        throw 'ResumeEvidencePath requires -ResumeBlockedEvaluation.'
    }

    $allowed = $false
    if ($LifecycleStage -eq 'blocked') {
        $allowed = ($currentStage -ne 'added_to_solution' -and $currentStage -ne 'blocked')
    }
    elseif ($ResumeBlockedEvaluation) {
        if ($LifecycleStage -ne 'evaluation_published') {
            throw 'ResumeBlockedEvaluation only supports the blocked to evaluation_published transition.'
        }

        if (-not $PSBoundParameters.ContainsKey('ResumeEvidencePath') -or [string]::IsNullOrWhiteSpace($ResumeEvidencePath)) {
            throw 'ResumeBlockedEvaluation requires ResumeEvidencePath.'
        }

        if ([string]$manifest.run_id -ne 't2-dev-20260925-001' -or
            [string]$ModelName -ne 'PersonalMasterDataFixed' -or
            [string]$inventoryModel.version -ne '1.0') {
            throw "ResumeBlockedEvaluation only supports PersonalMasterDataFixed version 1.0 for run 't2-dev-20260925-001'."
        }

        if (-not $PSBoundParameters.ContainsKey('ModelVersion') -or
            [string]::IsNullOrWhiteSpace($ModelVersion) -or
            [string]$ModelVersion -ne [string]$inventoryModel.version) {
            throw "ResumeBlockedEvaluation requires ModelVersion '$([string]$inventoryModel.version)' to match the recorded model version before writing."
        }

        $history = @($inventoryModel.lifecycle_history)
        if ($currentStage -ne 'blocked' -or $history.Count -lt 2) {
            throw "ResumeBlockedEvaluation requires model '$ModelName' to be blocked immediately after training."
        }

        $lastTwoStages = @($history[-2].stage, $history[-1].stage)
        if ($lastTwoStages[0] -ne 'trained' -or $lastTwoStages[1] -ne 'blocked') {
            throw "ResumeBlockedEvaluation requires model '$ModelName' to be blocked immediately after training."
        }

        $resumeHashBefore = Get-HrAiBuilderFileSha256 -Path $ResumeEvidencePath
        $resumeEvidence = Read-HrAiBuilderJson -Path $ResumeEvidencePath -Description 'Resume blocked evaluation evidence'
        if ([string]$resumeEvidence.status -ne 'blocked') {
            throw "Resume blocked evaluation evidence '$ResumeEvidencePath' must retain blocked status."
        }

        if ([string]$resumeEvidence.run_id -ne [string]$manifest.run_id) {
            throw "Resume blocked evaluation evidence '$ResumeEvidencePath' must reference run '$([string]$manifest.run_id)'."
        }

        if ([string]::IsNullOrWhiteSpace([string]$resumeEvidence.blocked_reason)) {
            throw "Resume blocked evaluation evidence '$ResumeEvidencePath' must retain its blocked_reason."
        }

        $resumeHashAfter = Get-HrAiBuilderFileSha256 -Path $ResumeEvidencePath
        if ($resumeHashBefore -ne $resumeHashAfter) {
            throw "Resume blocked evaluation evidence '$ResumeEvidencePath' changed during verification."
        }

        $allowed = $true
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
