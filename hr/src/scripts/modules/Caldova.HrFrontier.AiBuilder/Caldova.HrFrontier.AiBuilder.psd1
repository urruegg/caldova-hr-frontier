@{
    RootModule = 'Caldova.HrFrontier.AiBuilder.psm1'
    ModuleVersion = '1.0.0'
    GUID = '6ba6c8d9-8591-4e83-b5db-797514d68ba4'
    Author = 'GitHub Copilot'
    CompanyName = 'Caldova'
    Copyright = '(c) Caldova'
    Description = 'AI Builder corpus qualification, readiness, and run-manifest helpers for the Caldova HR Frontier HR domain.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
        'Get-HrAiBuilderFieldContract',
        'New-HrAiBuilderCorpusReviewTemplate',
        'Test-HrAiBuilderCorpus',
        'New-HrAiBuilderRunManifest',
        'Set-HrAiBuilderModelRecord',
        'Complete-HrAiBuilderRunManifest',
        'New-HrAiBuilderReadinessRecord',
        'New-HrAiBuilderTestCapabilityRecord',
        'ConvertTo-HrAiBuilderNormalizedValue',
        'Measure-HrAiBuilderEvaluation',
        'New-HrAiBuilderModelSchemaRecord',
        'Set-HrAiBuilderPredictionCaptureAdapterMetadata',
        'Test-HrAiBuilderStrictGates'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
}
