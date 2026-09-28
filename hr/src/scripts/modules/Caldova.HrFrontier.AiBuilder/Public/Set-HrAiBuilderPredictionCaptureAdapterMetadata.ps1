function Set-HrAiBuilderPredictionCaptureAdapterMetadata {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$PredictionCapture,

        [Parameter(Mandatory)]
        [string]$AdapterScriptPath
    )

    $resolvedAdapterScriptPath = [IO.Path]::GetFullPath($AdapterScriptPath)
    $metadataValues = [ordered]@{
        adapter_script_path = $resolvedAdapterScriptPath
        adapter_script_sha256 = Get-HrAiBuilderFileSha256 -Path $resolvedAdapterScriptPath
    }

    foreach ($property in $metadataValues.GetEnumerator()) {
        if ($PredictionCapture.PSObject.Properties.Name.Contains($property.Key)) {
            $PredictionCapture.$($property.Key) = $property.Value
        }
        else {
            $PredictionCapture | Add-Member -NotePropertyName $property.Key -NotePropertyValue $property.Value
        }
    }

    return $PredictionCapture
}
