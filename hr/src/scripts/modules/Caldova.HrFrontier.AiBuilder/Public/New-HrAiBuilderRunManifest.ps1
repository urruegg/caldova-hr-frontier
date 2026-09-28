function New-HrAiBuilderRunManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RunId,

        [Parameter(Mandatory)]
        [string]$TenantKey,

        [Parameter(Mandatory)]
        [string]$EnvironmentId,

        [Parameter(Mandatory)]
        [ValidateSet('DEV', 'TEST', 'PROD')]
        [string]$EnvironmentStage,

        [Parameter(Mandatory)]
        [string]$SolutionUniqueName,

        [Parameter(Mandatory)]
        [string]$SolutionVersion,

        [Parameter(Mandatory)]
        [string]$OperatorUpn,

        [Parameter(Mandatory)]
        [datetime]$StartedAtUtc,

        [Parameter(Mandatory)]
        [ValidatePattern('^[a-f0-9]{64}$')]
        [string]$CorpusRevision,

        [Parameter(Mandatory)]
        [ValidatePattern('^[a-f0-9]{64}$')]
        [string]$GeneratorRevision,

        [Parameter(Mandatory)]
        [string]$FieldContractVersion,

        [Parameter(Mandatory)]
        [object[]]$Models,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$CorpusResults,

        [Parameter(Mandatory)]
        [string]$OutputPath,

        [Parameter(Mandatory)]
        [string]$ModelInventoryPath
    )

    $knownModels = @(Get-HrAiBuilderKnownModels)
    $modelsByName = @{}
    foreach ($model in $Models) {
        $modelsByName[[string]$model.display_name] = $model
    }

    $corpusByKind = @{}
    foreach ($corpusResult in $CorpusResults) {
        if ($corpusResult -and $corpusResult.PSObject.Properties.Name.Contains('model_kind')) {
            $corpusByKind[[string]$corpusResult.model_kind] = $corpusResult
        }
    }

    $manifestModels = foreach ($knownModel in $knownModels) {
        $inputModel = $modelsByName[[string]$knownModel.display_name]
        $corpusResult = $corpusByKind[[string]$knownModel.model_kind]
        $documents = @()
        $groundTruthHashes = $null
        if ($corpusResult) {
            $documents = @($corpusResult.documents)
            $groundTruthHashes = $corpusResult.ground_truth_hashes
        }
        New-HrAiBuilderModelRecordState `
            -DisplayName ([string]$knownModel.display_name) `
            -ModelKind ([string]$knownModel.model_kind) `
            -Documents $documents `
            -GroundTruthHashes $groundTruthHashes
    }

    $manifest = [ordered]@{
        schema_version = '1.0'
        run_id = $RunId
        tenant_key = $TenantKey
        power_platform_environment_id = $EnvironmentId
        environment_stage = $EnvironmentStage
        solution_unique_name = $SolutionUniqueName
        solution_version = $SolutionVersion
        models = @($manifestModels)
        corpus_revision = $CorpusRevision
        generator_revision = $GeneratorRevision
        field_contract_version = $FieldContractVersion
        operator = $OperatorUpn
        started_at_utc = $StartedAtUtc.ToUniversalTime().ToString('o')
        completed_at_utc = $null
        overall_status = 'in_progress'
        evidence_hashes = @()
        finalized = $false
    }

    $inventory = [ordered]@{
        schema_version = '1.0'
        run_id = $RunId
        tenant_key = $TenantKey
        models = @(
            foreach ($model in $manifestModels) {
                [ordered]@{
                    display_name = [string]$model.display_name
                    model_kind = [string]$model.model_kind
                    model_id = ''
                    version = ''
                    lifecycle_stage = 'not_created'
                    lifecycle_history = @($model.lifecycle_history)
                }
            }
        )
    }

    Write-HrAiBuilderJson -InputObject $manifest -Path $OutputPath
    Write-HrAiBuilderJson -InputObject $inventory -Path $ModelInventoryPath
    return Read-HrAiBuilderJson -Path $OutputPath -Description 'Run manifest'
}
