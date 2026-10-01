function New-HrAiBuilderHoldoutConsumptionLedger {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RunManifestPath,
        [Parameter(Mandatory)][string]$ModelInventoryPath,
        [Parameter(Mandatory)][string]$CaptureCapabilityPath,
        [Parameter(Mandatory)][ValidatePattern('^[a-fA-F0-9]{64}$')][string]$CaptureCapabilitySha256,
        [Parameter(Mandatory)][string]$CaptureRootPath,
        [Parameter(Mandatory)][string]$AuthorizationSource,
        [Parameter(Mandatory)][datetime]$AuthorizedAtUtc,
        [Parameter(Mandatory)][string]$OutputPath
    )

    if (Test-Path -LiteralPath $OutputPath) {
        throw "Holdout-consumption ledger '$OutputPath' already exists."
    }

    $expectedHoldouts = @(
        [pscustomobject]@{
            document = 'a06-CAND-2026-0416-gerber.pdf'
            sha256 = '4b1110d9c394a709fbcf6dc39c3ebf20846114e4bb2f818e7dad0118e52ac5db'
        }
        [pscustomobject]@{
            document = 'b06-CAND-2026-0422-schnyder.pdf'
            sha256 = '2dd65e48932173a72cbfc0cad0f1bbe01b997e6a28eea60f5a2e8c5d2737a8b6'
        }
        [pscustomobject]@{
            document = 'c06-CAND-2026-0428-frei.pdf'
            sha256 = 'dc512e6545293d6532effc196f56322f12cc1b2a89ef3eb31c46c90b1ddcece4'
        }
        [pscustomobject]@{
            document = 'd06-CAND-2026-0434-ochsner.pdf'
            sha256 = '5ccc73225f0b12c937ea46d1f0566c5869e38f2756c73dc0b648044203fa74fa'
        }
    )

    $manifest = Read-HrAiBuilderJson -Path $RunManifestPath -Description 'Run manifest'
    $inventory = Read-HrAiBuilderJson -Path $ModelInventoryPath -Description 'Model inventory'
    $capability = Read-HrAiBuilderJson -Path $CaptureCapabilityPath -Description 'Capture capability'

    $actualCapabilitySha256 = (Get-FileHash -LiteralPath $CaptureCapabilityPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualCapabilitySha256 -cne $CaptureCapabilitySha256.ToLowerInvariant()) {
        throw 'The capture capability SHA-256 does not match the authorized hash.'
    }

    if ([string]$capability.status -cne 'passed') {
        throw 'The capture capability status must be passed.'
    }
    if ([string]$capability.decision -cne 'capture_validated') {
        throw 'The capture capability decision must be capture_validated.'
    }
    if (@($capability.failed_gates).Count -ne 0) {
        throw 'The capture capability must contain no failed gates.'
    }

    $requiredGateIds = @('AEC-G001', 'AEC-G002', 'AEC-G003', 'AEC-G004', 'AEC-G005', 'AEC-G006', 'AEC-G007')
    $actualPassedGateIds = @(
        $capability.gates |
            Where-Object { [string]$_.status -ceq 'passed' } |
            ForEach-Object { [string]$_.id }
    )
    if (-not (Compare-HrAiBuilderSequence -Left $actualPassedGateIds -Right $requiredGateIds)) {
        throw 'The capture capability must contain exactly AEC-G001 through AEC-G007 as passed gates.'
    }

    $manifestModels = @($manifest.models | Where-Object { [string]$_.display_name -ceq 'PersonalMasterDataFixed' })
    $inventoryModels = @($inventory.models | Where-Object { [string]$_.display_name -ceq 'PersonalMasterDataFixed' })
    if ($manifestModels.Count -ne 1 -or $inventoryModels.Count -ne 1) {
        throw 'Exactly one PersonalMasterDataFixed model record is required in both manifest and inventory.'
    }

    $manifestModel = $manifestModels[0]
    $inventoryModel = $inventoryModels[0]
    foreach ($model in @($manifestModel, $inventoryModel)) {
        if ([string]$model.model_id -cne '74b09a72-d1f1-4598-bc4d-3746d5c97acc' -or
            [string]$model.version -cne '1.0') {
            throw 'The fixed holdout ledger is authorized only for PersonalMasterDataFixed model 74b09a72-d1f1-4598-bc4d-3746d5c97acc version 1.0.'
        }
        if ([string]$model.lifecycle_stage -cne 'capture_validated') {
            throw 'The fixed model lifecycle stage must be capture_validated.'
        }
    }

    if ([string]$capability.run_id -cne [string]$manifest.run_id -or
        [string]$inventory.run_id -cne [string]$manifest.run_id) {
        throw 'The capability, manifest, and inventory run identities must match.'
    }
    if ([string]$capability.model.name -cne 'PersonalMasterDataFixed' -or
        [string]$capability.model.id -cne [string]$manifestModel.model_id -or
        [string]$capability.model.version -cne [string]$manifestModel.version) {
        throw 'The capture capability fixed model identity does not match the manifest.'
    }

    $actualHeldOut = @(
        $manifestModel.documents |
            Where-Object { [string]$_.assignment -ceq 'held-out' } |
            ForEach-Object {
                [pscustomobject]@{
                    document = [string]$_.document
                    sha256 = ([string]$_.sha256).ToLowerInvariant()
                }
            }
    )
    $actualHoldoutKeys = @($actualHeldOut | ForEach-Object { '{0}|{1}' -f $_.document, $_.sha256 })
    $expectedHoldoutKeys = @($expectedHoldouts | ForEach-Object { '{0}|{1}' -f $_.document, $_.sha256 })
    if (-not (Compare-HrAiBuilderSequence -Left $actualHoldoutKeys -Right $expectedHoldoutKeys)) {
        throw 'The run manifest must contain exactly the four authorized fixed holdouts with their approved hashes.'
    }

    if (Test-Path -LiteralPath $CaptureRootPath -PathType Container) {
        foreach ($pairPath in @(Get-ChildItem -LiteralPath $CaptureRootPath -Filter 'capture-pair.json' -File -Recurse)) {
            $pair = Read-HrAiBuilderJson -Path $pairPath.FullName -Description 'Capture pair'
            $pairFilename = [string]$pair.source.filename
            $pairSha256 = ([string]$pair.source.sha256).ToLowerInvariant()
            if ($expectedHoldouts.document -ccontains $pairFilename -or
                $expectedHoldouts.sha256 -ccontains $pairSha256) {
                throw "Capture pair '$($pairPath.FullName)' already references fixed holdout '$pairFilename'."
            }
        }
    }

    $ledger = [ordered]@{
        schema_version = '1.0'
        run_id = [string]$manifest.run_id
        initialized_at_utc = [datetime]::UtcNow.ToString('o')
        corpus_revision = [string]$manifest.corpus_revision
        model = [ordered]@{
            name = 'PersonalMasterDataFixed'
            id = [string]$manifestModel.model_id
            version = [string]$manifestModel.version
        }
        capture_capability = [ordered]@{
            path = [IO.Path]::GetFileName($CaptureCapabilityPath)
            sha256 = $actualCapabilitySha256
            status = 'passed'
            decision = 'capture_validated'
        }
        authorization_scope = [ordered]@{
            source = $AuthorizationSource
            authorized_at_utc = $AuthorizedAtUtc.ToUniversalTime().ToString('o')
            scope = 'exactly_once_submission_of_the_listed_fixed_holdouts_only'
            authorized_documents = @($expectedHoldouts.document)
            exactly_once_consequence = 'A submitted document can never return to unseen.'
            current_step = 'local_preparation_only'
            tenant_operation_status = 'not_performed'
            exclusions = @(
                'No upload during initialization'
                'No flow enablement or invocation during initialization'
                'No PDF content exposure during initialization'
                'No capture-directory creation during initialization'
                'No holdout state transition during initialization'
            )
        }
        holdouts = @(
            foreach ($holdout in $expectedHoldouts) {
                [ordered]@{
                    document = $holdout.document
                    sha256 = $holdout.sha256
                    state = 'unseen'
                }
            }
        )
    }

    $json = $ledger | ConvertTo-Json -Depth 12
    $utf8NoBom = [Text.UTF8Encoding]::new($false)
    $bytes = $utf8NoBom.GetBytes(($json.TrimEnd() + "`n"))
    $outputFullPath = [IO.Path]::GetFullPath($OutputPath)
    $stream = [IO.File]::Open($outputFullPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
        $stream.Write($bytes, 0, $bytes.Length)
    }
    finally {
        $stream.Dispose()
    }

    return [pscustomobject]$ledger
}
