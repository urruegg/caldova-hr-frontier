function New-HrAiBuilderModelSchemaRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('PersonalMasterDataFixed', 'PersonalMasterDataGeneral')]
        [string]$ModelName,

        [Parameter(Mandatory)]
        [string]$ModelId,

        [Parameter(Mandatory)]
        [string]$ObservedModelVersion,

        [Parameter(Mandatory)]
        [string]$Operator,

        [Parameter(Mandatory)]
        [datetime]$ObservedAtUtc,

        [Parameter(Mandatory)]
        [object[]]$Fields,

        [Parameter(Mandatory)]
        [string]$SourceEvidencePath,

        [Parameter(Mandatory)]
        [string]$OutputPath
    )

    $record = [ordered]@{
        schema_version = '1.0'
        model_name = $ModelName
        model_id = $ModelId
        observed_model_version = $ObservedModelVersion
        operator = $Operator
        observed_at_utc = $ObservedAtUtc.ToUniversalTime().ToString('o')
        fields = @(
            foreach ($field in $Fields) {
                [ordered]@{
                    name = [string]$field.name
                    ai_builder_type = [string]$field.ai_builder_type
                }
            }
        )
        source_evidence_path = Convert-HrAiBuilderPortableLocator -Path $SourceEvidencePath -RootPath (Split-Path -Parent ([IO.Path]::GetFullPath($OutputPath))) -Description 'Model schema source evidence'
        source_evidence_sha256 = Get-HrAiBuilderFileSha256 -Path $SourceEvidencePath
    }

    Write-HrAiBuilderJson -InputObject $record -Path $OutputPath
    return Read-HrAiBuilderJson -Path $OutputPath -Description 'Model schema record'
}
