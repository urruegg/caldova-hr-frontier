function Get-RepositoryExportPathIdentity {
    param([Parameter(Mandatory)][string]$Path)
    $full = [IO.Path]::GetFullPath($Path)
    if ($full -cne [IO.Path]::GetPathRoot($full)) { $full = $full.TrimEnd('\', '/') }
    Get-RunbookContentDigest -InputObject $full.ToLowerInvariant()
}

function Get-RepositoryExportAncestorIdentities {
    param([Parameter(Mandatory)][string]$Path)
    $cursor = [IO.Path]::GetFullPath($Path)
    while (-not [string]::IsNullOrWhiteSpace($cursor)) {
        Get-RepositoryExportPathIdentity -Path $cursor
        $parent = Split-Path -Parent $cursor
        if ($parent -ceq $cursor) { break }
        $cursor = $parent
    }
}

function Assert-RepositoryExportLocalPath {
    param([Parameter(Mandatory)][string]$Path)
    if (-not [IO.Path]::IsPathRooted($Path) -or $Path -notmatch '^[A-Za-z]:\\' -or
        $Path.Substring(2).Contains(':')) {
        throw 'Repository export requires an absolute local path.'
    }
    $cursor = [IO.Path]::GetFullPath($Path)
    while (-not [string]::IsNullOrWhiteSpace($cursor)) {
        if (Test-Path -LiteralPath $cursor) {
            if (((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw 'Repository export paths must not traverse a reparse point.'
            }
        }
        $parent = Split-Path -Parent $cursor
        if ($parent -ceq $cursor) { break }
        $cursor = $parent
    }
}

function Get-RepositoryExportFixedPolicy {
    param([Parameter(Mandatory)][ValidateSet('TenantReplica', 'CustomerHandover')][string]$Profile)
    [pscustomobject][ordered]@{
        version = 'tenant-replica-map-1'
        profile = $Profile
        capabilities = [ordered]@{
            ProductSource = @('hr/src/', 'hr/docs/', 'docs/', '.github/agents/', '.github/skills/', '.github/instructions/', '.github/agent-policy/', '.github/ISSUE_TEMPLATE/', '.github/issue-templates/')
            InfrastructureSource = @('infra/src/scripts/', 'infra/src/bicep/', 'infra/src/solutions/', 'infra/src/config/github/')
            GitHubValidation = @('.github/cli/')
            AzurePipeline = @('infra/src/pipelines/templates/')
            InfrastructureTests = @('infra/tests/pester/')
            HrTests = @('hr/tests/pester/')
            ReplacementRunbooks = @('infra/docs/', 'infra/src/config/runbooks/')
            Schemas = @('infra/src/config/schemas/')
            SyntheticExamples = @('infra/tests/fixtures/', 'hr/tests/fixtures/')
        }
        exactCapabilities = [ordered]@{
            ProductSource = @('README.md', 'LICENSE', 'AGENTS.md', '.gitignore', '.gitattributes', '.vscode/extensions.json', '.github/copilot-instructions.md', '.github/pull_request_template.md', '.github/dependabot.yml', 'data/README.md', 'hr/README.md')
            InfrastructureSource = @('infra/README.md')
            GitHubValidation = @('.github/workflows/validate-repository.yml', '.github/workflows/README.md')
            AzurePipeline = @('azure-pipelines.yml')
            HrTests = @('hr/tests/requirements.txt')
        }
        deniedSegments = [ordered]@{
            GitMetadata = @('.git', '.hg', '.svn')
            TenantPrivate = @('backups', 'generated-parameters', 'run-roots')
            TenantTransition = @('transition', 'transitions', 'discovery')
            Evidence = @('evidence', 'approvals', 'runs')
            ProviderOutput = @('artifacts', 'pipeline-artifacts', 'provider-output', 'provider-outputs', 'provider-response', 'provider-responses', 'deployment-output', 'deployment-outputs')
            Authentication = @('.azure', '.pac', '.credentials', '.ssh', 'authentication', 'pac-profiles')
            Publication = @('publication', '.gitmodules', '.gitconfig', '.git-credentials')
        }
        deniedFilePatterns = [ordered]@{
            TenantPrivate = '(^|/)[^/]*(\.local\.|\.bak$|\.backup$)|(^|/)generated[-.]parameters([.-][^/]*)?\.(json|xml|bicepparam)$|(^|/)\.env($|[.-])'
            TenantTransition = '\A(?!infra/src/config/schemas/(discovery|transition)\.schema\.json\z)(?:[^/]+/)*(?:(transition|discovery)([.-][^/]*)?\.(json|psd1|jsonl|xml|zip)|[^/]+[-.](transition|discovery)\.(json|psd1))\z'
            Evidence = '(^|/)(approvals|evidence)([.-][^/]*)?\.(json|jsonl|xml|zip|log)$'
            ProviderOutput = '(^|/)(provider[-.](outputs?|responses?)|deployment[-.]outputs?|pipeline[-.]artifacts)([.-][^/]*)?\.(json|jsonl|xml|zip|log)$'
            Authentication = '(^|/)(auth|authentication|pac[-.]profiles|credentials|token|tokens)(\.json|\.xml|\.dat)$|\.(pfx|p12|pem|key)$'
            Publication = '(^|/)(publish|publication|remotes|git-config|git-history|git-hooks)([.-][^/]*)?\.(json|yaml|yml|xml|config|zip)$'
        }
        stableMarkerCategories = @('StableId', 'Domain', 'Url', 'EmailSuffix', 'OtherTenantIdentifier')
        tenantTemplate = 'infra/src/config/tenants/_template.psd1'
        parameterRoot = 'infra/src/bicep/parameters/'
        tenantRoot = 'infra/src/config/tenants/'
        # Existing exact classifications may authorize tenant-neutral examples outside the standard roots.
        reviewedExampleClassifications = @('ReviewedNonPersonal', 'SyntheticFixture')
        untrackedDenial = 'IgnoredOrUntracked'
    }
}

function Get-RepositoryExportCapability {
    param([string]$Path, [object]$Manifest)
    $policy = Get-RepositoryExportFixedPolicy -Profile TenantReplica
    foreach ($entry in $policy.exactCapabilities.GetEnumerator()) {
        if ($entry.Value -ccontains $Path) { return $entry.Key }
    }
    foreach ($entry in $policy.capabilities.GetEnumerator()) {
        foreach ($prefix in $entry.Value) {
            if ($Path.StartsWith($prefix, [StringComparison]::Ordinal)) { return $entry.Key }
        }
    }
    if ($Path -ceq $policy.tenantTemplate -or $Path -ceq 'infra/src/config/tenants/template.json') { return 'SyntheticExamples' }
    if (-not $Path.Contains('/') -and @($Manifest.fileClassifications | Where-Object {
        $_.path -ceq $Path -and $policy.reviewedExampleClassifications -ccontains $_.classification
    }).Count -eq 1) { return 'SyntheticExamples' }
    return $null
}

function Get-RepositoryExportPathDenial {
    param([string]$Path, [object]$Manifest, [string]$Profile, [switch]$Directory)

    foreach ($deny in @($Manifest.deniedPaths)) {
        if ($Path.Equals($deny, [StringComparison]::OrdinalIgnoreCase) -or
            $Path.StartsWith("$deny/", [StringComparison]::OrdinalIgnoreCase)) { return 'ExactPathDenied' }
    }
    if ($Profile -ceq 'TenantReplica') {
        $policy = Get-RepositoryExportFixedPolicy -Profile $Profile
        $segments = @($Path -split '/')
        # Reviewed negative fixtures are test inputs, not tenant payload authority. History is never exempt.
        $syntheticFixture = ($Path.StartsWith('infra/tests/fixtures/', [StringComparison]::Ordinal) -or
            $Path.StartsWith('hr/tests/fixtures/', [StringComparison]::Ordinal)) -and
            @($Manifest.fileClassifications | Where-Object {
                ($_.path -ceq $Path -or ($Directory -and $_.path.StartsWith("$Path/", [StringComparison]::Ordinal))) -and
                $_.classification -ceq 'SyntheticFixture'
            }).Count -gt 0
        foreach ($entry in $policy.deniedSegments.GetEnumerator()) {
            if ($syntheticFixture -and $entry.Key -cne 'GitMetadata') { continue }
            if (@($segments | Where-Object { $entry.Value -icontains $_ }).Count -gt 0) { return $entry.Key }
        }
        if (-not $syntheticFixture) {
            foreach ($entry in $policy.deniedFilePatterns.GetEnumerator()) {
                if ($Path -imatch $entry.Value) { return $entry.Key }
            }
            if ($Path.StartsWith($policy.parameterRoot, [StringComparison]::OrdinalIgnoreCase)) { return 'TenantPrivate' }
            if ($Path.StartsWith($policy.tenantRoot, [StringComparison]::OrdinalIgnoreCase) -and
                $Path -cne $policy.tenantTemplate) {
                # Only exact reviewed neutral templates, never source-specific tenant manifests.
                $name = ($Path -split '/')[-1]
                if ($name -cnotin @('template.json', '_template.psd1') -or
                    @($Manifest.retainedTenantArtifacts | Where-Object path -CEQ $Path).Count -ne 1) { return 'TenantTransition' }
            }
            if ($Path.StartsWith('.github/workflows/', [StringComparison]::OrdinalIgnoreCase) -and
                $policy.exactCapabilities.GitHubValidation -cnotcontains $Path) { return 'Publication' }
        }
        return $null
    }
    $segments = @($Path -split '/')
    if (@($segments | Where-Object { $_ -imatch '^(\.git|\.hg|\.svn)$' }).Count -gt 0) { return 'SourceHistoryDenied' }
    if ($Profile -ceq 'CustomerHandover' -and $Path.StartsWith('.github/workflows/', [StringComparison]::OrdinalIgnoreCase)) { return 'WorkflowBoundary' }
    if (@($segments | Where-Object { $_ -imatch '^(evidence|artifacts|backups|approvals|\.azure|\.pac|\.credentials)$' }).Count -gt 0) { return 'PrivateArtifactDenied' }
    if ($Path -imatch '(^|/)[^/]*(\.local\.|\.bak$|\.backup$)' -or
        $Path -imatch '(^|/)(approvals|discovery|transition|provider[-.]?(output|response)|deployment[-.]?output|generated[-.]?parameters|authentication|pac[-.]?profiles)([./-]|$)' -or
        $Path -imatch '(^|/)(runs|run-roots|generated-parameters)/') { return 'PrivateArtifactDenied' }
    if ($Path.StartsWith('infra/src/config/tenants/', [StringComparison]::OrdinalIgnoreCase) -or
        $Path.StartsWith('infra/src/bicep/parameters/', [StringComparison]::OrdinalIgnoreCase)) {
        # Only exact reviewed synthetic templates can survive; discovery/transition payloads never can.
        $retained = @($Manifest.retainedTenantArtifacts | Where-Object { $_.path -ceq $Path })
        if ($retained.Count -ne 1 -or $Path -imatch '(transition|discovery|\.local\.)') { return 'TenantArtifactDeniedByDefault' }
    }
    return $null
}

function Get-RepositoryExportRequiredPaths {
    param([object]$Manifest)
    $paths = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($artifact in @($Manifest.retainedTenantArtifacts)) { [void]$paths.Add($artifact.path) }
    foreach ($classification in @($Manifest.fileClassifications)) {
        $path = [string]$classification.path
        $denial = Get-RepositoryExportPathDenial -Path $path -Manifest $Manifest -Profile TenantReplica
        if (($null -eq $denial -or $denial -ceq 'ExactPathDenied') -and
            $null -ne (Get-RepositoryExportCapability -Path $path -Manifest $Manifest)) { [void]$paths.Add($path) }
    }
    @($paths | Sort-Object)
}

function Get-RepositoryExportActionOrder {
    @('snapshot-source', 'stage-committed-blobs', 'apply-exact-transformations', 'validate-profile',
        'promote-destination', 'snapshot-source-post', 'validate-independent')
}

function Get-RepositoryExportManifestPolicyDigests {
    param([Parameter(Mandatory)][object]$Manifest)
    $fields = [ordered]@{
        manifestDigest = $null
        retainPolicyDigest = 'retainedTenantArtifacts'
        denyPolicyDigest = 'deniedPaths'
        markerPolicyDigest = 'residualMarkers'
        replacementPolicyDigest = 'replacements'
        residualPolicyDigest = 'residualDispositions'
        profilePolicyDigest = 'profilePolicy'
        classificationPolicyDigest = 'fileClassifications'
        binaryPolicyDigest = 'inspectableBinaries'
        syntheticPolicyDigest = 'syntheticDataPolicy'
        suitePolicyDigest = 'validationSuites'
    }
    $digests = [ordered]@{}
    foreach ($name in $fields.Keys) {
        $value = $Manifest
        if ($null -ne $fields[$name]) { $value = $Manifest.($fields[$name]) }
        $digests[$name] = Get-RunbookContentDigest -InputObject $value
    }
    $digests.fixedPolicyDigest = Get-RunbookContentDigest -InputObject (Get-RepositoryExportFixedPolicy -Profile $Manifest.profile)
    [pscustomobject]$digests
}

function Get-RepositoryExportActions {
    param([Parameter(Mandatory)][string]$DestinationStableId)
    foreach ($id in @(Get-RepositoryExportActionOrder)) {
        [pscustomobject][ordered]@{
            action = $id
            targetId = $DestinationStableId
            service = 'LocalRepositoryExport'
            method = $id
            expectedPostcondition = 'The exact assessed profile contract is satisfied without source mutation.'
        }
    }
}
