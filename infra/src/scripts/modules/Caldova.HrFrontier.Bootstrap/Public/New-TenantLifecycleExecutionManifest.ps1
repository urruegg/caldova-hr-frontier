function Get-TenantLifecycleExecutionManifestDigest {
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][object]$Manifest)

    $digestInput = [pscustomobject][ordered]@{
        schemaVersion = $Manifest.schemaVersion
        runId = $Manifest.runId
        generatedAtUtc = $Manifest.generatedAtUtc
        expiresAtUtc = $Manifest.expiresAtUtc
        sourceCommit = $Manifest.sourceCommit
        evidenceRoot = $Manifest.evidenceRoot
        publicTenantKey = $Manifest.publicTenantKey
        intentDigest = $Manifest.intentDigest
        stateDigest = $Manifest.stateDigest
        machine = $Manifest.machine
        operator = $Manifest.operator
        toolIdentities = @($Manifest.toolIdentities)
        providerContexts = @($Manifest.providerContexts)
        prerequisites = @($Manifest.prerequisites)
        actions = @($Manifest.actions)
    }
    return Get-RunbookContentDigest -InputObject $digestInput
}

function New-TenantLifecycleExecutionManifest {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][guid]$RunId,
        [Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{40}$')][string]$SourceCommit,
        [Parameter(Mandatory)][string]$EvidenceRoot,
        [Parameter(Mandatory)][ValidateSet('tenant1')][string]$PublicTenantKey,
        [Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{64}$')][string]$IntentDigest,
        [Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{64}$')][string]$StateDigest,
        [Parameter(Mandatory)][object]$Machine,
        [Parameter(Mandatory)][object]$Operator,
        [Parameter(Mandatory)][object[]]$ToolIdentities,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$ProviderContexts,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Prerequisites,
        [Parameter(Mandatory)][object[]]$Actions,
        [Parameter(Mandatory)][datetime]$GeneratedAtUtc,
        [Parameter(Mandatory)][datetime]$ExpiresAtUtc
    )

    if (-not [IO.Path]::IsPathRooted($EvidenceRoot)) {
        throw [IO.InvalidDataException]::new('TenantLifecycle.Manifest.EvidenceRoot')
    }

    try {
        $canonicalEvidenceRoot = [IO.Path]::GetFullPath($EvidenceRoot)
    }
    catch {
        throw [IO.InvalidDataException]::new('TenantLifecycle.Manifest.EvidenceRoot')
    }

    $generated = if ($GeneratedAtUtc.Kind -eq [DateTimeKind]::Unspecified) {
        [DateTime]::SpecifyKind($GeneratedAtUtc, [DateTimeKind]::Utc)
    }
    else {
        $GeneratedAtUtc.ToUniversalTime()
    }
    $expires = if ($ExpiresAtUtc.Kind -eq [DateTimeKind]::Unspecified) {
        [DateTime]::SpecifyKind($ExpiresAtUtc, [DateTimeKind]::Utc)
    }
    else {
        $ExpiresAtUtc.ToUniversalTime()
    }

    if ($expires -le $generated -or ($expires - $generated) -gt [TimeSpan]::FromMinutes(30)) {
        throw [IO.InvalidDataException]::new('TenantLifecycle.Manifest.Expiry')
    }

    $timestampFormat = 'yyyy-MM-ddTHH:mm:ss.fffffffZ'
    $digestInput = [pscustomobject][ordered]@{
        schemaVersion = '1.0'
        runId = $RunId.ToString().ToLowerInvariant()
        generatedAtUtc = $generated.ToString($timestampFormat, [Globalization.CultureInfo]::InvariantCulture)
        expiresAtUtc = $expires.ToString($timestampFormat, [Globalization.CultureInfo]::InvariantCulture)
        sourceCommit = $SourceCommit
        evidenceRoot = $canonicalEvidenceRoot
        publicTenantKey = $PublicTenantKey
        intentDigest = $IntentDigest
        stateDigest = $StateDigest
        machine = $Machine
        operator = $Operator
        toolIdentities = @($ToolIdentities)
        providerContexts = @($ProviderContexts)
        prerequisites = @($Prerequisites)
        actions = @($Actions)
    }
    $candidate = [pscustomobject][ordered]@{
        schemaVersion = $digestInput.schemaVersion
        runId = $digestInput.runId
        generatedAtUtc = $digestInput.generatedAtUtc
        expiresAtUtc = $digestInput.expiresAtUtc
        sourceCommit = $digestInput.sourceCommit
        evidenceRoot = $digestInput.evidenceRoot
        publicTenantKey = $digestInput.publicTenantKey
        intentDigest = $digestInput.intentDigest
        stateDigest = $digestInput.stateDigest
        machine = $digestInput.machine
        operator = $digestInput.operator
        toolIdentities = @($digestInput.toolIdentities)
        providerContexts = @($digestInput.providerContexts)
        prerequisites = @($digestInput.prerequisites)
        actions = @($digestInput.actions)
        digest = '0' * 64
    }

    Test-TenantLifecycleContract -Kind ExecutionManifest -InputObject $candidate | Out-Null

    $canonical = ConvertTo-CanonicalJsonValue -Value $digestInput -RemainingDepth 30
    $clone = ($canonical | ConvertTo-Json -Depth 30 -Compress) | ConvertFrom-Json
    $digest = Get-TenantLifecycleExecutionManifestDigest -Manifest $candidate
    $manifest = [pscustomobject][ordered]@{
        schemaVersion = $clone.schemaVersion
        runId = $clone.runId
        generatedAtUtc = $clone.generatedAtUtc
        expiresAtUtc = $clone.expiresAtUtc
        sourceCommit = $clone.sourceCommit
        evidenceRoot = $clone.evidenceRoot
        publicTenantKey = $clone.publicTenantKey
        intentDigest = $clone.intentDigest
        stateDigest = $clone.stateDigest
        machine = $clone.machine
        operator = $clone.operator
        toolIdentities = @($clone.toolIdentities)
        providerContexts = @($clone.providerContexts)
        prerequisites = @($clone.prerequisites)
        actions = @($clone.actions)
        digest = $digest
    }

    Test-TenantLifecycleContract -Kind ExecutionManifest -InputObject $manifest | Out-Null
    return $manifest
}
