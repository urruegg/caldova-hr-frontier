function ConvertFrom-HrAiBuilderEvaluationCapture {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CaptureDirectory,

        [Parameter(Mandatory)]
        [string]$RunManifestPath,

        [Parameter(Mandatory)]
        [string]$FieldContractPath,

        [Parameter(Mandatory)]
        [string]$ModelSchemaRecordPath,

        [Parameter(Mandatory)]
        [string]$ModelName,

        [Parameter(Mandatory)]
        [string]$ModelVersion,

        [Parameter(Mandatory)]
        [string]$Operator,

        [Parameter(Mandatory)]
        [string]$OutputPath,

        [string]$AdapterScriptPath
    )

    $blocked = {
        param([string[]]$Gates, [object]$Hashes)
        [pscustomobject]@{
            status = 'blocked'
            failed_gates = @($Gates | Select-Object -Unique)
            hashes = $Hashes
            output_path = $null
        }
    }

    if (Test-Path -LiteralPath $OutputPath) {
        return & $blocked @('immutable_output') ([pscustomobject]@{})
    }

    if (-not (Test-Path -LiteralPath $CaptureDirectory -PathType Container)) {
        return & $blocked @('evidence_boundary') ([pscustomobject]@{})
    }

    $captureDirectories = @()
    if (@(Get-ChildItem -LiteralPath $CaptureDirectory -Filter '*.ai-builder.raw.json' -File).Count -gt 0) {
        $captureDirectories = @((Get-Item -LiteralPath $CaptureDirectory))
    }
    else {
        $captureDirectories = @(
            Get-ChildItem -LiteralPath $CaptureDirectory -Directory |
                Where-Object { @(Get-ChildItem -LiteralPath $_.FullName -Filter '*.ai-builder.raw.json' -File).Count -gt 0 } |
                Sort-Object Name
        )
    }
    if ($captureDirectories.Count -eq 0) {
        return & $blocked @('capture_pair_provenance') ([pscustomobject]@{})
    }

    $results = @(
        foreach ($directory in $captureDirectories) {
            Test-HrAiBuilderCapturePair `
                -CaptureDirectory $directory.FullName `
                -RunManifestPath $RunManifestPath `
                -FieldContractPath $FieldContractPath `
                -ModelSchemaRecordPath $ModelSchemaRecordPath `
                -ModelName $ModelName `
                -ModelVersion $ModelVersion `
                -Operator $Operator `
                -AdapterScriptPath $AdapterScriptPath
        }
    )
    $failed = @($results | Where-Object status -ne 'passed')
    if ($failed.Count -gt 0) {
        return & $blocked @($failed.failed_gates) $failed[0].hashes
    }

    $documentNames = @($results.document.document)
    if (@($documentNames | Group-Object -CaseSensitive | Where-Object Count -gt 1).Count -gt 0) {
        return & $blocked @('exact_field_contract') $results[0].hashes
    }

    $manifest = Read-HrAiBuilderJson -Path $RunManifestPath -Description 'Run manifest'
    $adapterPath = if ($AdapterScriptPath) { [IO.Path]::GetFullPath($AdapterScriptPath) } else { $PSCommandPath }
    $capture = [ordered]@{
        schema_version = '1.0'
        run_id = [string]$manifest.run_id
        model_name = $ModelName
        model_version = $ModelVersion
        capture_mechanism = 'Power Automate Process documents'
        adapter_version = '1.0'
        adapter_contract = 'replayable-v2'
        adapter_script_path = $adapterPath
        adapter_script_sha256 = if ($AdapterScriptPath) {
            Get-HrAiBuilderFileSha256 -Path $AdapterScriptPath
        } else {
            Get-HrAiBuilderFileSha256 -Path $PSCommandPath
        }
        raw_export_format = 'ai-builder-process-documents-v1'
        operator = $Operator
        documents = @($results.document)
    }

    $outputDirectory = Split-Path -Parent $OutputPath
    if ($outputDirectory) {
        New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
    }
    [IO.File]::WriteAllBytes([IO.Path]::GetFullPath($OutputPath), (ConvertTo-HrAiBuilderCanonicalJson -InputObject $capture))

    [pscustomobject]@{
        status = 'passed'
        failed_gates = @()
        hashes = $results[0].hashes
        pair_hashes = @($results.hashes)
        output_path = [IO.Path]::GetFullPath($OutputPath)
    }
}
