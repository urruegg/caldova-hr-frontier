Set-StrictMode -Version Latest

Describe 'TenantReplica retain and deny' {
    BeforeAll {
        Import-Module (Join-Path $PSScriptRoot '..\..\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1') -Force
        $script:ReplicaModule = Get-Module Caldova.HrFrontier.Bootstrap
        $script:ReplicaTree = Join-Path $PSScriptRoot '..\fixtures\runbooks\repository-export\tenant-replica-tree'
        $script:ProhibitedTree = Join-Path $PSScriptRoot '..\fixtures\runbooks\repository-export\prohibited-tree'
        function New-ReplicaMapFixture {
            $root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N').Substring(0, 8))
            [void][IO.Directory]::CreateDirectory($root)
            $blobs = [Collections.Generic.Dictionary[string, byte[]]]::new([StringComparer]::Ordinal)
            $manifest = Import-RepositoryExportManifest -Path ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\src\config\runbooks\tenant-replica.sample.json'))) -ExpectedProfile TenantReplica
            $manifest.retainedTenantArtifacts = @()
            $manifest.fileClassifications = @()
            $manifest.deniedPaths = @()
            foreach ($file in Get-ChildItem $script:ReplicaTree -Recurse -File -Force) {
                $path = $file.FullName.Substring([IO.Path]::GetFullPath($script:ReplicaTree).TrimEnd('\').Length + 1).Replace('\', '/')
                $blobs[$path] = [IO.File]::ReadAllBytes($file.FullName)
                $hash = (Get-FileHash $file.FullName).Hash.ToLowerInvariant()
                if ($path -ceq 'infra/src/config/tenants/_template.psd1') {
                    $manifest.retainedTenantArtifacts += [pscustomobject]@{ path = $path; artifactKind = 'TenantManifest'; customerScope = 'Synthetic required template.' }
                }
                $manifest.fileClassifications += [pscustomobject]@{
                    path = $path; sourceBlobSha256 = $hash; expectedOutputSha256 = $hash
                    classification = $(if ($path -ceq 'infra/tests/fixtures/sample.json') { 'SyntheticFixture' } else { 'ReviewedNonPersonal' })
                    reason = 'Reviewed fabricated engineering fixture.'
                }
            }
            $manifest.residualMarkers = @()
            $manifest.sourceMarkerCatalog = @()
            $manifest.residualDispositions = @()
            [pscustomobject]@{ Root = $root; Source = (Join-Path $root 'src'); Destination = (Join-Path $root 'out'); Blobs = $blobs; Manifest = $manifest }
        }
        function Invoke-ReplicaMapAssessment {
            param($Fixture)
            $blobs = $Fixture.Blobs
            $reader = { param($git, $source, $commit, $path) $blobs[$path] }.GetNewClosure()
            $tracked = @(
                foreach ($path in $blobs.Keys) {
                    [pscustomobject]@{ path = $path; blobSha256 = (Get-FileHash -InputStream ([IO.MemoryStream]::new($blobs[$path]))).Hash.ToLowerInvariant() }
                }
            )
            $parameters = @{
                SourceRoot = $Fixture.Source; ExpectedSourceCommit = ('a' * 40); DestinationRoot = $Fixture.Destination
                Manifest = $Fixture.Manifest; ManifestDigest = (Get-RunbookContentDigest $Fixture.Manifest)
                SourceSnapshot = [pscustomobject]@{ trackedFiles = $tracked }
                ToolIdentities = [pscustomobject]@{
                    WindowsPowerShell = [pscustomobject]@{ path = 'C:\synthetic\powershell.exe' }
                    AzureCli = [pscustomobject]@{ path = 'C:\synthetic\az.exe' }
                }; MarkerCatalogProof = [pscustomobject]@{}
                GitExecutable = [pscustomobject]@{ path = 'C:\synthetic\git.exe' }; GitBlobReader = $reader
                Profile = $Fixture.Manifest.profile; Canonical = $true
            }
            & $script:ReplicaModule { param($p) Invoke-CustomerExportAssessment @p } $parameters
        }
        function Add-ReplicaMarker {
            param($Fixture, [string]$Category, [string]$Value)
            $Fixture.Manifest.residualMarkers = @([pscustomobject]@{ id = 'reviewed'; category = $Category; value = $Value; comparison = 'OrdinalIgnoreCase' })
            $Fixture.Manifest.sourceMarkerCatalog = @([pscustomobject]@{
                id = 'reviewed'; category = $Category; value = $Value; comparison = 'OrdinalIgnoreCase'
                sources = @([pscustomobject]@{ path = 'README.md'; blobSha256 = ('a' * 64); occurrenceCount = 1 })
            })
        }
        function Invoke-ReplicaMapContent {
            param($Fixture, $Assessment, [string]$Extra, [switch]$Missing)
            $stage = Join-Path $Fixture.Root ([guid]::NewGuid().ToString('N').Substring(0, 8))
            [void][IO.Directory]::CreateDirectory($stage)
            foreach ($path in $Assessment.copyFiles) {
                if ($Missing -and $path -ceq 'hr/src/m.ps1') { continue }
                $full = Join-Path $stage $path.Replace('/', '\')
                [void][IO.Directory]::CreateDirectory((Split-Path $full -Parent))
                [IO.File]::WriteAllBytes($full, $Fixture.Blobs[$path])
            }
            if ($Extra) {
                $full = Join-Path $stage $Extra.Replace('/', '\')
                [void][IO.Directory]::CreateDirectory((Split-Path $full -Parent))
                [IO.File]::WriteAllText($full, 'Synthetic extra payload')
            }
            $execution = [pscustomobject]@{ kind = 'CustomerExport'; target = [pscustomobject]@{ type = 'CustomerExport'; stableId = $Assessment.destinationStableId }; assessmentDigest = $Assessment.digest }
            # External suite execution is not retained-tree acceptance in this slice.
            Test-CustomerExportContent -StagingRoot $stage -Manifest $Fixture.Manifest -Assessment $Assessment `
                -ExecutionManifest $execution -CurrentSourceSnapshot $Assessment.sourceSnapshot `
                -ValidationRunner { param($suite) [pscustomobject]@{ suite = $suite; exitCode = 0 } }
        }
    }

    It 'retains every required engineering asset rather than silently dropping build capability' {
        $f = New-ReplicaMapFixture
        $before = Get-RunbookContentDigest @($f.Blobs.Values | ForEach-Object { [Convert]::ToBase64String($_) })
        $a = Invoke-ReplicaMapAssessment $f
        @($a.copyFiles).Count | Should -Be 19
        foreach ($required in $f.Manifest.fileClassifications) { $a.copyFiles | Should -Contain $required.path }
        (Invoke-ReplicaMapContent $f $a).status | Should -BeExactly 'Passed'
        (Get-RunbookContentDigest @($f.Blobs.Values | ForEach-Object { [Convert]::ToBase64String($_) })) | Should -BeExactly $before
        Test-Path $f.Source | Should -BeFalse
        Test-Path $f.Destination | Should -BeFalse
    }

    It 'excludes <Path> with exact <Reason> even with digest classifications and binary permission' -ForEach @(
        @{ Path = 'tenant1.local.psd1'; Reason = 'TenantPrivate' }
        @{ Path = 'tenant1.state.local.json'; Reason = 'TenantPrivate' }
        @{ Path = 'backups/state.json'; Reason = 'TenantPrivate' }
        @{ Path = 'infra/src/bicep/parameters/tenant1.json'; Reason = 'TenantPrivate' }
        @{ Path = 'approvals/approved.json'; Reason = 'Evidence' }
        @{ Path = 'evidence/sanitized.json'; Reason = 'Evidence' }
        @{ Path = 'runs/raw.json'; Reason = 'Evidence' }
        @{ Path = 'infra/src/config/tenants/tenant2.psd1'; Reason = 'TenantTransition' }
        @{ Path = 'discovery/tenant2.json'; Reason = 'TenantTransition' }
        @{ Path = 'provider-response.json'; Reason = 'ProviderOutput' }
        @{ Path = 'artifacts/pipeline.json'; Reason = 'ProviderOutput' }
        @{ Path = '.pac/profiles.json'; Reason = 'Authentication' }
        @{ Path = '.azure/context.json'; Reason = 'Authentication' }
        @{ Path = 'publication/remote.json'; Reason = 'Publication' }
    ) {
        $f = New-ReplicaMapFixture
        $bytes = [IO.File]::ReadAllBytes((Join-Path $script:ProhibitedTree $Path.Replace('/', '\')))
        $f.Blobs[$Path] = $bytes
        $hash = (Get-FileHash -InputStream ([IO.MemoryStream]::new($bytes))).Hash.ToLowerInvariant()
        $f.Manifest.fileClassifications += [pscustomobject]@{ path = $Path; sourceBlobSha256 = $hash; expectedOutputSha256 = $hash; classification = 'ReviewedNonPersonal'; reason = 'Cannot bypass a denial.' }
        $f.Manifest.inspectableBinaries = @([pscustomobject]@{ path = $Path; sha256 = $hash; reason = 'Cannot bypass a denial.' })
        $a = Invoke-ReplicaMapAssessment $f
        @($a.exclusions | Where-Object path -CEQ $Path).Count | Should -Be 1
        ($a.exclusions | Where-Object path -CEQ $Path).reason | Should -BeExactly $Reason
        $a.copyFiles | Should -Not -Contain $Path
        $f.Manifest.retainedTenantArtifacts += [pscustomobject]@{ path = $Path; artifactKind = 'ReusableCapability'; customerScope = 'Cannot bypass a denial.' }
        { Invoke-ReplicaMapAssessment $f } | Should -Throw "*retention*$Reason*"
        Test-Path $f.Destination | Should -BeFalse
    }

    It 'blocks metadata and misleading <Path> without touching real Git metadata' -ForEach @(
        @{ Path = '.git/config'; Reason = 'GitMetadata' }
        @{ Path = 'nested/.GiT/hooks/pre-push'; Reason = 'GitMetadata' }
        @{ Path = 'infra/src/scripts/.azure/context.json'; Reason = 'Authentication' }
        @{ Path = 'infra/src/scripts/APPROVALS/result.json'; Reason = 'Evidence' }
        @{ Path = 'infra/src/config/tenants/tenant2/template.psd1'; Reason = 'TenantTransition' }
        @{ Path = 'infra/src/config/tenants/_template.psd1.bak'; Reason = 'TenantPrivate' }
        @{ Path = '.github/workflows/publish.yml'; Reason = 'Publication' }
        @{ Path = 'hr/src/provider-output/result.json'; Reason = 'ProviderOutput' }
        @{ Path = 'infra/src/scripts/auth.json'; Reason = 'Authentication' }
        @{ Path = 'infra/src/scripts/session.pfx'; Reason = 'Authentication' }
        @{ Path = 'hr/src/.env'; Reason = 'TenantPrivate' }
        @{ Path = 'infra/src/scripts/tenant2-discovery.json'; Reason = 'TenantTransition' }
        @{ Path = 'infra/src/scripts/deployment-outputs.json'; Reason = 'ProviderOutput' }
        @{ Path = 'infra/src/scripts-extra/m.ps1'; Reason = 'AmbiguousArtifact' }
        @{ Path = 'infra/SRC/scripts/m.ps1'; Reason = 'AmbiguousArtifact' }
        @{ Path = 'unknown/payload.json'; Reason = 'AmbiguousArtifact' }
    ) {
        $f = New-ReplicaMapFixture
        $f.Blobs[$Path] = [Text.Encoding]::UTF8.GetBytes('{}')
        if ($Reason -ceq 'GitMetadata') {
            { Invoke-ReplicaMapAssessment $f } | Should -Throw '*GitMetadata*'
        }
        else {
            $a = Invoke-ReplicaMapAssessment $f
            ($a.exclusions | Where-Object path -CEQ $Path).reason | Should -BeExactly $Reason
        }
        Test-Path $f.Destination | Should -BeFalse
    }

    It 'requires the exact manifest-retained asset when <Case>' -ForEach @(
        @{ Case = 'missing' }, @{ Case = 'inconclusive without classification' }, @{ Case = 'denied' }
    ) {
        $f = New-ReplicaMapFixture
        switch ($Case) {
            'missing' { [void]$f.Blobs.Remove('hr/src/m.ps1') }
            'inconclusive without classification' { $f.Manifest.fileClassifications = @($f.Manifest.fileClassifications | Where-Object path -CNE 'hr/src/m.ps1') }
            'denied' { $f.Manifest.deniedPaths = @('hr/src') }
        }
        { Invoke-ReplicaMapAssessment $f } | Should -Throw '*retention*'
    }

    It 'never disposes a prohibited <Category> in retained text' -ForEach @(
        @{ Category = 'StableId'; Value = 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee' }
        @{ Category = 'Url'; Value = 'https://source.example.invalid/private' }
        @{ Category = 'Domain'; Value = 'source.example.invalid' }
        @{ Category = 'EmailSuffix'; Value = 'source.example.invalid' }
        @{ Category = 'OtherTenantIdentifier'; Value = 'synthetic-source-account' }
    ) {
        $f = New-ReplicaMapFixture
        Add-ReplicaMarker $f $Category $Value
        $f.Blobs['README.md'] = [Text.Encoding]::UTF8.GetBytes("Tenant 1 narrative and $Value")
        $f.Manifest.residualDispositions = @([pscustomobject]@{ path = 'README.md'; markerId = 'reviewed'; reason = 'Cannot waive a stable source value.' })
        { Invoke-ReplicaMapAssessment $f } | Should -Throw '*TenantStableIdentifier*'
        $r = @(Get-CustomerExportResidual -RelativePath 'README.md' -Bytes $f.Blobs['README.md'] -Markers $f.Manifest.residualMarkers -Dispositions $f.Manifest.residualDispositions -Profile TenantReplica)
        $r[0].disposition | Should -BeExactly 'Undisposed'
        $r[0].reason | Should -BeExactly 'TenantStableIdentifier'
    }

    It 'permits reviewed narrative but requires an exact transformation for a stable value' {
        $f = New-ReplicaMapFixture
        Add-ReplicaMarker $f 'CompanyName' 'Tenant 1'
        $f.Manifest.residualDispositions = @(
            [pscustomobject]@{ path = 'README.md'; markerId = 'reviewed'; reason = 'Reusable narrative, not a tenant selector.' }
            [pscustomobject]@{ path = 'infra/docs/runbooks/03-customer-handover.md'; markerId = 'reviewed'; reason = 'Reusable narrative.' }
        )
        (Invoke-ReplicaMapAssessment $f).copyFiles | Should -Contain 'README.md'
        Add-ReplicaMarker $f 'StableId' 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee'
        $f.Manifest.residualDispositions = @()
        $f.Blobs['README.md'] = [Text.Encoding]::UTF8.GetBytes('Tenant 1 aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee')
        $f.Manifest.replacements = @([pscustomobject]@{ id = 'exact'; path = 'README.md'; format = 'MarkdownExact'; expectedOldText = 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee'; newText = 'synthetic-new-id'; requiredCount = 1 })
        $sourceHash = (Get-FileHash -InputStream ([IO.MemoryStream]::new($f.Blobs['README.md']))).Hash.ToLowerInvariant()
        $expectedHash = (Get-FileHash -InputStream ([IO.MemoryStream]::new([Text.Encoding]::UTF8.GetBytes('Tenant 1 synthetic-new-id')))).Hash.ToLowerInvariant()
        ($f.Manifest.fileClassifications | Where-Object path -CEQ 'README.md').sourceBlobSha256 = $sourceHash
        ($f.Manifest.fileClassifications | Where-Object path -CEQ 'README.md').expectedOutputSha256 = $expectedHash
        (Invoke-ReplicaMapAssessment $f).fileDigests.'README.md'.expectedOutputSha256 | Should -BeExactly $expectedHash
    }

    It 'enforces actual staged <Case> independently of the retained inventory' -ForEach @(
        @{ Case = 'missing capability'; Extra = ''; Missing = $true; Reason = 'MissingFile' }
        @{ Case = 'unexpected allowed source'; Extra = 'hr/src/extra.ps1'; Missing = $false; Reason = 'UnexpectedFile' }
        @{ Case = 'private evidence'; Extra = 'evidence/sanitized.json'; Missing = $false; Reason = 'Evidence' }
        @{ Case = 'Git metadata'; Extra = '.git/config'; Missing = $false; Reason = 'GitMetadata' }
        @{ Case = 'publication'; Extra = 'publication/target.json'; Missing = $false; Reason = 'Publication' }
    ) {
        $f = New-ReplicaMapFixture
        $a = Invoke-ReplicaMapAssessment $f
        $result = Invoke-ReplicaMapContent $f $a -Extra $Extra -Missing:$Missing
        $result.status | Should -BeExactly 'Failed'
        $result.failures.category | Should -Contain $Reason
    }

    It 'retains validation only for replica and never widens the customer boundary' {
        $f = New-ReplicaMapFixture
        $f.Manifest.profile = 'CustomerHandover'
        $f.Manifest.profilePolicy.denyWorkflows = $true
        $f.Manifest.retainedTenantArtifacts = @($f.Manifest.retainedTenantArtifacts | Where-Object path -CNE '.github/workflows/validate-repository.yml')
        (Invoke-ReplicaMapAssessment $f).copyFiles | Should -Not -Contain '.github/workflows/validate-repository.yml'
    }

    It 'retains an exact reviewed negative synthetic fixture without treating its payload-shaped path as live evidence' {
        $f = New-ReplicaMapFixture
        $path = 'infra/tests/fixtures/evidence/example.json'
        $f.Blobs[$path] = [Text.Encoding]::UTF8.GetBytes('{"status":"Synthetic evidence fixture"}')
        $hash = (Get-FileHash -InputStream ([IO.MemoryStream]::new($f.Blobs[$path]))).Hash.ToLowerInvariant()
        $f.Manifest.fileClassifications += [pscustomobject]@{ path = $path; sourceBlobSha256 = $hash; expectedOutputSha256 = $hash; classification = 'SyntheticFixture'; reason = 'Reviewed tenant-neutral negative fixture.' }
        $a = Invoke-ReplicaMapAssessment $f
        $a.copyFiles | Should -Contain $path
        $content = Invoke-ReplicaMapContent $f $a
        $content.status | Should -BeExactly 'Passed' -Because ($content.failures | ConvertTo-Json -Compress)
    }

    It 'cannot promote an unknown prefix to a capability by classification or explicit retention' {
        $f = New-ReplicaMapFixture
        $path = 'infra/src/scripts-extra/private.json'
        $f.Blobs[$path] = [Text.Encoding]::UTF8.GetBytes('{}')
        $hash = (Get-FileHash -InputStream ([IO.MemoryStream]::new($f.Blobs[$path]))).Hash.ToLowerInvariant()
        $f.Manifest.fileClassifications += [pscustomobject]@{ path = $path; sourceBlobSha256 = $hash; expectedOutputSha256 = $hash; classification = 'SyntheticFixture'; reason = 'Cannot widen the capability prefixes.' }
        (Invoke-ReplicaMapAssessment $f).exclusions.reason | Should -Contain 'AmbiguousArtifact'
        $f.Manifest.retainedTenantArtifacts += [pscustomobject]@{ path = $path; artifactKind = 'TenantManifest'; customerScope = 'Cannot widen the capability prefixes.' }
        { Invoke-ReplicaMapAssessment $f } | Should -Throw '*retention*AmbiguousArtifact*'
    }

    It 'does not let a binary authorization or generic disposition waive a stable marker' {
        $f = New-ReplicaMapFixture
        $path = 'reviewed.bin'
        $value = 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee'
        $f.Blobs[$path] = [Text.Encoding]::UTF8.GetBytes(([string][char]0x1B) + $value)
        $hash = (Get-FileHash -InputStream ([IO.MemoryStream]::new($f.Blobs[$path]))).Hash.ToLowerInvariant()
        $f.Manifest.fileClassifications += [pscustomobject]@{ path = $path; sourceBlobSha256 = $hash; expectedOutputSha256 = $hash; classification = 'ReviewedNonPersonal'; reason = 'Cannot waive a source marker.' }
        $f.Manifest.inspectableBinaries = @([pscustomobject]@{ path = $path; sha256 = $hash; reason = 'Cannot waive a source marker.' })
        Add-ReplicaMarker $f StableId $value
        $f.Manifest.residualDispositions = @([pscustomobject]@{ path = $path; markerId = 'reviewed'; reason = 'Cannot waive a source marker.' })
        { Invoke-ReplicaMapAssessment $f } | Should -Throw '*TenantStableIdentifier*'
    }

    It 'rejects stable values in actual content even when an exact disposition and digest classification claim them' {
        $f = New-ReplicaMapFixture
        $a = Invoke-ReplicaMapAssessment $f
        Add-ReplicaMarker $f StableId 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee'
        $f.Blobs['README.md'] = [Text.Encoding]::UTF8.GetBytes('Tenant 1 aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee')
        $f.Manifest.residualDispositions = @([pscustomobject]@{ path = 'README.md'; markerId = 'reviewed'; reason = 'Cannot waive a stable value.' })
        $hash = (Get-FileHash -InputStream ([IO.MemoryStream]::new($f.Blobs['README.md']))).Hash.ToLowerInvariant()
        ($f.Manifest.fileClassifications | Where-Object path -CEQ 'README.md').expectedOutputSha256 = $hash
        $a.fileDigests.'README.md'.expectedOutputSha256 = $hash
        $a.manifestDigest = Get-RunbookContentDigest $f.Manifest
        (Invoke-ReplicaMapContent $f $a).failures.category | Should -Contain 'TenantStableIdentifier'
    }

    It 'rejects a stale fixed policy binding in actual content' {
        $f = New-ReplicaMapFixture
        $a = Invoke-ReplicaMapAssessment $f
        $a.fixedPolicyDigest = 'f' * 64
        (Invoke-ReplicaMapContent $f $a).failures.category | Should -Contain 'ProfilePolicyMismatch'
    }

    It 'cannot bypass explicit profile enforcement with a dictionary manifest' {
        $f = New-ReplicaMapFixture
        $a = Invoke-ReplicaMapAssessment $f
        $dictionary = [ordered]@{}
        foreach ($property in $f.Manifest.PSObject.Properties) { $dictionary[$property.Name] = $property.Value }
        $f.Manifest = $dictionary
        $a.fixedPolicyDigest = 'f' * 64
        { Invoke-ReplicaMapContent $f $a } | Should -Throw '*profile manifest*'
    }

    It 'does not reinterpret a singleton manifest array as the historical customer profile' {
        $f = New-ReplicaMapFixture
        $a = Invoke-ReplicaMapAssessment $f
        $f.Manifest = @($f.Manifest)
        { Invoke-ReplicaMapContent $f $a } | Should -Throw '*manifest*'
    }

    It 'cannot remove the explicit manifest profile after a canonical assessment' {
        $f = New-ReplicaMapFixture
        $a = Invoke-ReplicaMapAssessment $f
        $f.Manifest.PSObject.Properties.Remove('profile')
        { Invoke-ReplicaMapContent $f $a } | Should -Throw '*explicit profile*'
    }

    It 'rejects case-mismatched profile selection at the shared residual boundary' {
        $f = New-ReplicaMapFixture
        Add-ReplicaMarker $f StableId 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee'
        {
            Get-CustomerExportResidual -RelativePath 'README.md' `
                -Bytes ([Text.Encoding]::UTF8.GetBytes('aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee')) `
                -Markers $f.Manifest.residualMarkers -Profile tenantreplica
        } | Should -Throw
    }

    It 'rejects changed synthetic bytes despite an unchanged classification and staged inventory' {
        $f = New-ReplicaMapFixture
        $a = Invoke-ReplicaMapAssessment $f
        $f.Blobs['infra/tests/fixtures/sample.json'] = [Text.Encoding]::UTF8.GetBytes('{"status":"Synthetic changed output"}')
        (Invoke-ReplicaMapContent $f $a).failures.category | Should -Contain 'Digest'
    }

    It 'proves the public assessment and planner bind the map without writes or ignored-file reads' {
        $f = New-RepositoryAssessmentFixture
        $p = $f.Parameters
        $lock = [IO.File]::Open((Join-Path $f.Source 'private.local.json'), 'Open', 'ReadWrite', 'None')
        $reader = & $script:ReplicaModule { ${function:Read-CustomerExportCommitBlob} }
        $snapshotParameters = @{ RepositoryRoot = $f.Source; GitExecutable = $p.ToolIdentities.Git; NativeCommandRunner = $p.NativeCommandRunner; GitBlobReader = $reader }
        try {
            $before = Get-RunbookContentDigest (Get-CustomerExportSourceSnapshot @snapshotParameters)
            $a = Get-RepositoryExportAssessment @p
            $a.retainedFileCount | Should -Be 5
            $planParameters = @{ Assessment = $a; Manifest = $f.Manifest; RunId = 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee'; EvidenceRoot = (Join-Path $f.Root 'proof'); NowUtc = [datetime]'2026-10-25T06:00:00Z' }
            (New-RepositoryExportActionPlan @planParameters).profile | Should -BeExactly 'TenantReplica'
            $a.fixedPolicyDigest = 'f' * 64
            $unsigned = [ordered]@{}
            foreach ($property in $a.PSObject.Properties | Where-Object Name -ne 'digest') { $unsigned[$property.Name] = $property.Value }
            $a.digest = Get-RunbookContentDigest $unsigned
            { New-RepositoryExportActionPlan @planParameters } | Should -Throw '*policy digest*'
            (Get-RunbookContentDigest (Get-CustomerExportSourceSnapshot @snapshotParameters)) | Should -BeExactly $before
        }
        finally { $lock.Dispose() }
        Test-Path $p.DestinationRoot | Should -BeFalse
        Test-Path $planParameters.EvidenceRoot | Should -BeFalse
    }

    It 'rejects an unreadable untracked payload before reading its bytes' {
        $f = New-RepositoryAssessmentFixture
        $path = Join-Path $f.Source 'untracked.json'
        [IO.File]::WriteAllText($path, '{"status":"Synthetic untracked sentinel"}')
        $lock = [IO.File]::Open($path, 'Open', 'ReadWrite', 'None')
        $p = $f.Parameters
        try { { Get-RepositoryExportAssessment @p } | Should -Throw '*IgnoredOrUntracked*' }
        finally { $lock.Dispose() }
        Test-Path $p.DestinationRoot | Should -BeFalse
    }

    It 'requires reviewed account selectors discovered from committed tenant artifacts' {
        $f = New-RepositoryAssessmentFixture
        $full = Join-Path $f.Source 'infra\src\config\tenants\transition.json'
        [IO.File]::WriteAllText($full, '{"TenantAlias":"source-lab","AccountSelector":"synthetic-owner-selector"}', [Text.UTF8Encoding]::new($false))
        & $f.Git -C $f.Source add -- infra/src/config/tenants/transition.json
        if ($LASTEXITCODE -ne 0) { throw 'Synthetic account fixture could not be staged.' }
        & $f.Git -C $f.Source commit --quiet -m 'Synthetic account selector'
        if ($LASTEXITCODE -ne 0) { throw 'Synthetic account fixture could not be committed.' }
        $f.Parameters.ExpectedSourceCommit = (& $f.Git -C $f.Source rev-parse HEAD).Trim()
        $f.Manifest.sourceMarkerCatalog[1].sources[0].blobSha256 = (Get-FileHash $full).Hash.ToLowerInvariant()
        $p = $f.Parameters
        { Get-RepositoryExportAssessment @p } | Should -Throw '*unrepresented source marker*'
        Test-Path $p.DestinationRoot | Should -BeFalse
    }
}

function script:New-RepositoryAssessmentFixture {
    param([string]$Profile = 'TenantReplica')
    $root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    $source = Join-Path $root 'src'
    [void][IO.Directory]::CreateDirectory($source)
    $git = 'C:\Program Files\Git\cmd\git.exe'
    if (-not (Test-Path -LiteralPath $git -PathType Leaf)) {
        $git = (Get-Command git.exe -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
    }
    $ps = (Get-Command powershell.exe -CommandType Application | Select-Object -First 1).Source
    $files = [ordered]@{
        'README.md' = "Source Lab`n"
        '.gitignore' = "*.local.json`n.github/workflows/ignored.yml`n"
        '.github/workflows/validate-repository.yml' = "name: synthetic`n"
        'azure-pipelines.yml' = "trigger: none`n"
        'infra/src/pipelines/templates/check.yml' = "steps: []`n"
        'infra/src/config/tenants/transition.json' = '{"TenantAlias":"source-lab"}'
        'infra/evidence/private.md' = 'source-lab'
        'private.local.json' = '{"value":"synthetic-private-sentinel"}'
    }
    foreach ($path in $files.Keys) {
        $full = Join-Path $source $path.Replace('/', '\')
        [void][IO.Directory]::CreateDirectory((Split-Path -Parent $full))
        [IO.File]::WriteAllText($full, $files[$path], [Text.UTF8Encoding]::new($false))
    }
    & $git -C $source init --quiet
    & $git -C $source config user.name 'Synthetic Reviewer'
    & $git -C $source config user.email 'reviewer@example.invalid'
    & $git -C $source config core.autocrlf false
    & $git -C $source add .
    & $git -C $source commit --quiet -m 'Synthetic assessment'
    & $git -C $source remote add origin 'https://example.invalid/source'
    $commit = (& $git -C $source rev-parse HEAD).Trim()
    $readmeHash = (Get-FileHash -LiteralPath (Join-Path $source 'README.md')).Hash.ToLowerInvariant()
    $tenantHash = (Get-FileHash -LiteralPath (Join-Path $source 'infra\src\config\tenants\transition.json')).Hash.ToLowerInvariant()
    $manifest = [pscustomobject][ordered]@{
        schemaVersion = '1.0'; tenantAlias = 'source-lab'; customerScope = 'Synthetic assessment'
        retainedTenantArtifacts = @()
        replacements = @([pscustomobject]@{
            id = 'readme'; path = 'README.md'; format = 'MarkdownExact'
            expectedOldText = 'Source Lab'; newText = 'Synthetic Reviewer'; requiredCount = 1
        })
        residualMarkers = @(
            [pscustomobject]@{ id = 'company'; category = 'CompanyName'; value = 'Source Lab'; comparison = 'Ordinal' }
            [pscustomobject]@{ id = 'alias'; category = 'TenantAlias'; value = 'source-lab'; comparison = 'OrdinalIgnoreCase' }
        )
        sourceMarkerCatalog = @(
            [pscustomobject]@{
                id = 'company'; category = 'CompanyName'; value = 'Source Lab'; comparison = 'Ordinal'
                sources = @([pscustomobject]@{ path = 'README.md'; blobSha256 = $readmeHash; occurrenceCount = 1 })
            }
            [pscustomobject]@{
                id = 'alias'; category = 'TenantAlias'; value = 'source-lab'; comparison = 'OrdinalIgnoreCase'
                sources = @([pscustomobject]@{ path = 'infra/src/config/tenants/transition.json'; blobSha256 = $tenantHash; occurrenceCount = 1 })
            }
        )
        residualDispositions = @()
        syntheticDataPolicy = [pscustomobject]@{
            reservedNames = @('Synthetic Reviewer'); reservedDomains = @('example.invalid'); reservedIdPrefixes = @('synthetic-')
        }
        fileClassifications = @(
            foreach ($path in @('.gitignore', '.github/workflows/validate-repository.yml', 'azure-pipelines.yml', 'infra/src/pipelines/templates/check.yml')) {
                $hash = (Get-FileHash -LiteralPath (Join-Path $source $path.Replace('/', '\'))).Hash.ToLowerInvariant()
                [pscustomobject]@{ path = $path; sourceBlobSha256 = $hash; expectedOutputSha256 = $hash; classification = 'ReviewedNonPersonal'; reason = 'Synthetic engineering text.' }
            }
        )
        inspectableBinaries = @(); validationSuites = @('Pester', 'RepositorySafety', 'BicepBuild')
        profile = $Profile
        profilePolicy = [pscustomobject]@{
            denyWorkflows = ($Profile -ceq 'CustomerHandover'); denyEvidence = $true
            denyTenantTransitions = $true; denyPrivateState = $true; denySourceHistory = $true; denyUntrackedFiles = $true
        }
        deniedPaths = @()
    }
    $runner = {
        param($file, $arguments)
        $previous = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'Continue'
            $output = @(& $file @arguments 2>&1 | ForEach-Object { $_.ToString() })
            $code = $LASTEXITCODE
        }
        finally { $ErrorActionPreference = $previous }
        [pscustomobject]@{ exitCode = $code; stdout = ($output -join "`n"); stderr = '' }
    }
    # Expected identity is independently reviewed fixture data, not an assessment read-back.
    $identity = Get-RunbookContentDigest -InputObject @(
        "origin`thttps://example.invalid/source (fetch)"
        "origin`thttps://example.invalid/source (push)"
    )
    [pscustomobject]@{
        Source = $source; Root = $root; Git = $git; Manifest = $manifest
        Parameters = @{
            SourceRoot = $source; ExpectedSourceCommit = $commit; DestinationRoot = (Join-Path $root 'out')
            Manifest = $manifest; Profile = $Profile; RepositoryIdentity = $identity; NativeCommandRunner = $runner
            ToolIdentities = [pscustomobject]@{
                Git = [pscustomobject]@{ path = $git; sha256 = (Get-FileHash $git).Hash.ToLowerInvariant(); version = (& $git --version).Trim() }
                WindowsPowerShell = [pscustomobject]@{ path = $ps; sha256 = (Get-FileHash $ps).Hash.ToLowerInvariant(); version = '5.1' }
                AzureCli = [pscustomobject]@{ path = $ps; sha256 = (Get-FileHash $ps).Hash.ToLowerInvariant(); version = 'synthetic-unused' }
            }
        }
    }
}

Describe 'Canonical repository assessment and deterministic planning' {
    BeforeAll {
        Import-Module (Join-Path $PSScriptRoot '..\..\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1') -Force
        $script:FixtureBlobReader = & (Get-Module Caldova.HrFrontier.Bootstrap) { ${function:Read-CustomerExportCommitBlob} }
        $script:Order = @('snapshot-source', 'stage-committed-blobs', 'apply-exact-transformations', 'validate-profile', 'promote-destination', 'snapshot-source-post', 'validate-independent')
        function New-FixturePlan {
            param($Assessment, $Fixture)
            New-RepositoryExportActionPlan -Assessment $Assessment -Manifest $Fixture.Manifest `
                -RunId 'e9c21cdd-8bfc-45be-a90d-2e29c5ee4dc1' -EvidenceRoot (Join-Path $Fixture.Root 'evidence') -NowUtc ([datetime]'2026-10-25T06:00:00Z')
        }
        function Complete-FixtureCommit {
            param($Fixture)
            & $Fixture.Git -C $Fixture.Source add .
            & $Fixture.Git -C $Fixture.Source commit --quiet -m 'Synthetic case'
            $Fixture.Parameters.ExpectedSourceCommit = (& $Fixture.Git -C $Fixture.Source rev-parse HEAD).Trim()
        }
        function Add-FixtureBinary {
            param($Fixture, [byte[]]$Bytes, [switch]$AssertMarker)
            $path = 'reviewed.bin'
            $full = Join-Path $Fixture.Source $path
            [IO.File]::WriteAllBytes($full, $Bytes)
            Complete-FixtureCommit $Fixture
            $hash = (Get-FileHash -LiteralPath $full).Hash.ToLowerInvariant()
            $Fixture.Manifest.inspectableBinaries = @([pscustomobject]@{
                path = $path; sha256 = $hash; reason = 'Exact synthetic binary authorization.'
            })
            $Fixture.Manifest.fileClassifications += [pscustomobject]@{
                path = $path; sourceBlobSha256 = $hash; expectedOutputSha256 = $hash
                classification = 'ReviewedNonPersonal'; reason = 'Exact synthetic nonpersonal classification.'
            }
            if ($AssertMarker) {
                $Fixture.Manifest.sourceMarkerCatalog[1].sources += [pscustomobject]@{
                    path = $path; blobSha256 = $hash; occurrenceCount = 1
                }
            }
        }
    }

    It 'plans the same seven ordered actions using the shared signed permission set for <Profile>' -ForEach @(
        @{ Profile = 'TenantReplica' }, @{ Profile = 'CustomerHandover' }
    ) {
        $f = New-RepositoryAssessmentFixture $Profile
        $p = $f.Parameters
        $before = (& $f.Git -C $f.Source status --porcelain=v1 --ignored) -join "`n"
        $a = Get-RepositoryExportAssessment @p
        $plan = New-FixturePlan $a $f
        $a.classification | Should -BeExactly 'Create'
        $a.replacementPolicyDigest | Should -BeExactly (Get-RunbookContentDigest -InputObject $f.Manifest.replacements)
        $a.denyPolicyDigest | Should -BeExactly (Get-RunbookContentDigest -InputObject @())
        @($plan.orderedActions.action) | Should -Be $script:Order
        @($plan.executionManifest.allowedActions.action) | Should -Be @(
            'apply-exact-transformations', 'promote-destination', 'snapshot-source', 'snapshot-source-post',
            'stage-committed-blobs', 'validate-independent', 'validate-profile'
        )
        Test-RunbookExecutionManifest -Manifest $plan.executionManifest -ApprovedDigest $plan.digest `
            -CurrentSourceCommit $p.ExpectedSourceCommit -CurrentAssessmentDigest $a.digest `
            -CurrentAuthenticationContext $plan.executionManifest.authentication -AllowedActionNames $script:Order `
            -NowUtc ([datetime]'2026-10-25T06:00:00Z') | Should -BeTrue
        (New-FixturePlan (Get-RepositoryExportAssessment @p) $f).digest | Should -BeExactly $plan.digest
        Test-Path $p.DestinationRoot | Should -BeFalse
        Test-Path (Join-Path $f.Root 'evidence') | Should -BeFalse
        @((Get-ChildItem $f.Root -Force).Name | Sort-Object) | Should -Be @('src')
        ((& $f.Git -C $f.Source status --porcelain=v1 --ignored) -join "`n") | Should -BeExactly $before
        $json = $a | ConvertTo-Json -Depth 60 -Compress
        $json | Should -Not -Match 'https:|example.invalid|Source Lab|source-lab|private.local|README.md|[A-Za-z]:[\\]'
        $a.retainedFileCount | Should -Be $(if ($Profile -ceq 'TenantReplica') { 5 } else { 4 })
        $a.deniedFileCount | Should -Be $(if ($Profile -ceq 'TenantReplica') { 2 } else { 3 })
    }

    It 'rejects complete remote inventory drift: <Case>' -ForEach @(
        @{ Case = 'fetch' }, @{ Case = 'push' }, @{ Case = 'extra remote' }, @{ Case = 'extra push' }
    ) {
        $f = New-RepositoryAssessmentFixture
        switch ($Case) {
            'fetch' { & $f.Git -C $f.Source remote set-url origin https://example.invalid/changed }
            'push' { & $f.Git -C $f.Source remote set-url --push origin https://example.invalid/changed }
            'extra remote' { & $f.Git -C $f.Source remote add extra https://example.invalid/extra }
            'extra push' {
                & $f.Git -C $f.Source remote set-url --push origin https://example.invalid/source
                & $f.Git -C $f.Source remote set-url --add --push origin https://example.invalid/extra
                @(& $f.Git -C $f.Source remote -v).Count | Should -Be 3
            }
        }

        $p = $f.Parameters
        { Get-RepositoryExportAssessment @p } | Should -Throw '*identity*'
        Test-Path $p.DestinationRoot | Should -BeFalse
    }

    It 'accepts only the existing sorted-line remote normalization, including uppercase expected hex' {
        $f = New-RepositoryAssessmentFixture
        $p = $f.Parameters
        $p.RepositoryIdentity = $p.RepositoryIdentity.ToUpperInvariant()
        $native = $p.NativeCommandRunner
        $p.NativeCommandRunner = {
            param($file, $arguments)
            $result = & $native $file $arguments
            if ($arguments -contains 'remote') {
                $result.stdout = "`r`norigin`thttps://example.invalid/source (push)`r`norigin`thttps://example.invalid/source (fetch)`r`n"
            }
            $result
        }.GetNewClosure()
        (Get-RepositoryExportAssessment @p).classification | Should -BeExactly 'Create'
    }

    It 'rejects <Case> source state without repairing it' -ForEach @(
        @{ Case = 'wrong commit' }, @{ Case = 'unstaged' }, @{ Case = 'staged' }, @{ Case = 'untracked' },
        @{ Case = 'conflicted' }, @{ Case = 'sparse' }, @{ Case = 'empty sparse' }, @{ Case = 'submodule' }, @{ Case = 'symlink blob' }
    ) {
        $f = New-RepositoryAssessmentFixture
        $p = $f.Parameters
        switch ($Case) {
            'wrong commit' { $p.ExpectedSourceCommit = 'b' * 40 }
            'unstaged' { [IO.File]::AppendAllText((Join-Path $f.Source 'README.md'), 'dirty') }
            'staged' { [IO.File]::AppendAllText((Join-Path $f.Source 'README.md'), 'dirty'); & $f.Git -C $f.Source add README.md }
            'untracked' { [IO.File]::WriteAllText((Join-Path $f.Source 'new.md'), 'untracked') }
            'conflicted' {
                $blob = (& $f.Git -C $f.Source rev-parse HEAD:README.md).Trim()
                "100644 $blob 1`tREADME.md`n100644 $blob 2`tREADME.md`n100644 $blob 3`tREADME.md" | & $f.Git -C $f.Source update-index --index-info
            }
            'sparse' {
                & $f.Git -C $f.Source sparse-checkout set --no-cone '/README.md'
                if ($LASTEXITCODE -ne 0) { throw 'Synthetic sparse checkout could not be created.' }
            }
            'empty sparse' {
                & $f.Git -C $f.Source sparse-checkout init --no-cone
                '' | & $f.Git -C $f.Source sparse-checkout set --no-cone --stdin
            }
            'submodule' {
                & $f.Git -C $f.Source update-index --add --cacheinfo "160000,$($p.ExpectedSourceCommit),linked"
                & $f.Git -C $f.Source commit --quiet -m 'Synthetic gitlink'
                $p.ExpectedSourceCommit = (& $f.Git -C $f.Source rev-parse HEAD).Trim()
            }
            'symlink blob' {
                $blob = (& $f.Git -C $f.Source rev-parse HEAD:README.md).Trim()
                & $f.Git -C $f.Source update-index --add --cacheinfo "120000,$blob,linked"
                & $f.Git -C $f.Source commit --quiet -m 'Synthetic symlink'
                $p.ExpectedSourceCommit = (& $f.Git -C $f.Source rev-parse HEAD).Trim()
            }
        }
        $before = (& $f.Git -C $f.Source status --porcelain=v1) -join "`n"
        { Get-RepositoryExportAssessment @p } | Should -Throw
        ((& $f.Git -C $f.Source status --porcelain=v1) -join "`n") | Should -BeExactly $before
        Test-Path $p.DestinationRoot | Should -BeFalse
    }

    It 'refuses <Case> destinations with no staging side effect' -ForEach @(
        @{ Case = 'existing' }, @{ Case = 'inside source' }, @{ Case = 'inside another worktree' }, @{ Case = 'reparse ancestor' }
    ) {
        $f = New-RepositoryAssessmentFixture
        $p = $f.Parameters
        switch ($Case) {
            'existing' { [void][IO.Directory]::CreateDirectory($p.DestinationRoot) }
            'inside source' { $p.DestinationRoot = Join-Path $f.Source 'out' }
            'inside another worktree' {
                $other = Join-Path $f.Root 'other'
                & $f.Git -C $f.Source worktree add --quiet --detach $other
                $p.DestinationRoot = Join-Path $other 'out'
            }
            'reparse ancestor' {
                $link = Join-Path $f.Root 'link'
                [void](New-Item -ItemType Junction -Path $link -Target $f.Source)
                $p.DestinationRoot = Join-Path $link 'out'
            }
        }
        try { { Get-RepositoryExportAssessment @p } | Should -Throw }
        finally {
            if ($Case -ceq 'reparse ancestor') { [IO.Directory]::Delete($link) }
        }
        @(Get-ChildItem $f.Root -Filter '*staging*').Count | Should -Be 0
    }

    It 'validates canonical object input before reading source for <Case>' -ForEach @(
        @{ Case = 'legacy' }, @{ Case = 'unknown property' }, @{ Case = 'conflicting profile' },
        @{ Case = 'weakened policy' }, @{ Case = 'array root' }, @{ Case = 'denied conflict' }
    ) {
        $f = New-RepositoryAssessmentFixture
        $p = $f.Parameters
        switch ($Case) {
            'legacy' { $f.Manifest.PSObject.Properties.Remove('profile') }
            'unknown property' { $f.Manifest | Add-Member NoteProperty skipValidation $true }
            'conflicting profile' { $p.Profile = 'CustomerHandover' }
            'weakened policy' { $f.Manifest.profilePolicy.denyPrivateState = $false }
            'array root' { $p.Manifest = @($f.Manifest) }
            'denied conflict' { $f.Manifest.deniedPaths = @('README.md') }
        }
        $p.SourceRoot = Join-Path $f.Root 'missing-source'
        $p.NativeCommandRunner = { throw 'Source enumeration was reached before profile validation.' }
        { Get-RepositoryExportAssessment @p } | Should -Throw '*profile*'
    }

    It 'requires a canonical profile and reviewed digest at the public boundary' {
        $command = Get-Command Get-RepositoryExportAssessment
        $command.Parameters['Profile'].Attributes.Mandatory | Should -Contain $true
        $command.Parameters['RepositoryIdentity'].Attributes.Mandatory | Should -Contain $true
        $f = New-RepositoryAssessmentFixture
        $p = $f.Parameters
        $p.RepositoryIdentity = 'not-a-digest'
        { Get-RepositoryExportAssessment @p } | Should -Throw
    }

    It 'rejects explicit tenant retention that contradicts fixed transition denial before enumeration' {
        $f = New-RepositoryAssessmentFixture
        $f.Manifest.retainedTenantArtifacts = @([pscustomobject]@{
            path = 'infra/src/config/tenants/transition.json'; artifactKind = 'TenantManifest'; customerScope = 'Must not override the fixed deny policy.'
        })
        $p = $f.Parameters
        $p.NativeCommandRunner = { throw 'Enumeration must not be reached for conflicting retention.' }
        { Get-RepositoryExportAssessment @p } | Should -Throw '*profile*'
    }

    It 'rejects private coordinates masquerading as a tool version' {
        $f = New-RepositoryAssessmentFixture
        $p = $f.Parameters
        $p.ToolIdentities.Git.version = 'https://example.invalid/private-coordinate'
        { Get-RepositoryExportAssessment @p } | Should -Throw '*tool*'
    }

    It 'rejects retained bytes that are <Case>, even with a reviewed nonpersonal classification' -ForEach @(
        @{ Case = 'UTF8 BOM'; Bytes = [byte[]]@(239,187,191,65) }
        @{ Case = 'UTF16'; Bytes = [byte[]]@(255,254,65,0) }
        @{ Case = 'invalid UTF8'; Bytes = [byte[]]@(195,40) }
        @{ Case = 'binary'; Bytes = [byte[]]@(65,0,66) }
        @{ Case = 'mixed newline'; Bytes = [Text.Encoding]::UTF8.GetBytes("a`r`nb`nc") }
    ) {
        $f = New-RepositoryAssessmentFixture
        $full = Join-Path $f.Source 'ambiguous.md'
        [IO.File]::WriteAllBytes($full, $Bytes)
        Complete-FixtureCommit $f
        $hash = (Get-FileHash $full).Hash.ToLowerInvariant()
        $f.Manifest.fileClassifications += [pscustomobject]@{
            path = 'ambiguous.md'; sourceBlobSha256 = $hash; expectedOutputSha256 = $hash
            classification = 'ReviewedNonPersonal'; reason = 'Must not override encoding validation.'
        }
        $p = $f.Parameters
        { Get-RepositoryExportAssessment @p } | Should -Throw
    }

    It 'rejects an unresolved marker in <Case>' -ForEach @(
        @{ Case = 'content'; Path = 'residual.md' }
        @{ Case = 'filename'; Path = 'Source Lab.md' }
        @{ Case = 'directory'; Path = 'Source Lab/note.md' }
    ) {
        $f = New-RepositoryAssessmentFixture
        $full = Join-Path $f.Source $Path.Replace('/', '\')
        [void][IO.Directory]::CreateDirectory((Split-Path $full -Parent))
        [IO.File]::WriteAllText($full, $(if ($Case -ceq 'content') { 'Source Lab' } else { 'Synthetic Reviewer' }))
        Complete-FixtureCommit $f
        $p = $f.Parameters
        { Get-RepositoryExportAssessment @p } | Should -Throw '*residual*'
    }

    It 'rejects the digest-authorized NUL binary marker bypass for <Profile> with <Disposition> disposition' -ForEach @(
        @{ Profile = 'TenantReplica'; Disposition = 'missing' }
        @{ Profile = 'CustomerHandover'; Disposition = 'missing' }
        @{ Profile = 'TenantReplica'; Disposition = 'exact' }
        @{ Profile = 'CustomerHandover'; Disposition = 'exact' }
        @{ Profile = 'TenantReplica'; Disposition = 'mismatched' }
        @{ Profile = 'CustomerHandover'; Disposition = 'mismatched' }
    ) {
        $f = New-RepositoryAssessmentFixture $Profile
        $bytes = [Text.Encoding]::UTF8.GetBytes("source-lab`0")
        Add-FixtureBinary $f $bytes -AssertMarker
        if ($Disposition -cne 'missing') {
            $f.Manifest.residualDispositions = @([pscustomobject]@{
                path = $(if ($Disposition -ceq 'exact') { 'reviewed.bin' } else { 'README.md' })
                markerId = 'alias'; reason = 'A disposition cannot make ambiguous bytes inspectable.'
            })
        }
        $p = $f.Parameters
        # Prove the canonical intent and committed marker assertions are valid before testing refusal.
        $intentPath = Join-Path $f.Root 'reviewed-intent.json'
        [IO.File]::WriteAllText($intentPath, ($f.Manifest | ConvertTo-Json -Depth 30), [Text.UTF8Encoding]::new($false))
        Import-RepositoryExportManifest -Path $intentPath -ExpectedProfile $Profile | Out-Null
        $snapshotParameters = @{
            RepositoryRoot = $f.Source; GitExecutable = $p.ToolIdentities.Git
            NativeCommandRunner = $p.NativeCommandRunner; GitBlobReader = $script:FixtureBlobReader
        }
        $before = Get-CustomerExportSourceSnapshot @snapshotParameters
        $proof = Get-CustomerSourceMarkerCatalog -RepositoryRoot $f.Source -ExpectedSourceCommit $p.ExpectedSourceCommit `
            -TrackedFiles $before.trackedFiles -RetainedTenantArtifacts @() -SourceMarkerCatalog $f.Manifest.sourceMarkerCatalog `
            -GitExecutable $p.ToolIdentities.Git -GitBlobReader $script:FixtureBlobReader
        $proof.reviewedAssertionsVerified | Should -Be 3
        try {
            { Get-RepositoryExportAssessment @p } | Should -Throw '*residual inspection*'
        }
        finally {
            (Get-RunbookContentDigest (Get-CustomerExportSourceSnapshot @snapshotParameters)) |
                Should -BeExactly (Get-RunbookContentDigest $before)
            [IO.File]::ReadAllBytes((Join-Path $f.Source 'reviewed.bin')) | Should -Be $bytes
            Test-Path -LiteralPath $p.DestinationRoot | Should -BeFalse
            @(Get-ChildItem -LiteralPath $f.Root -Directory | Where-Object Name -ne 'src').Count | Should -Be 0
        }
    }

    It 'enforces residual dispositions independently of binary authorization for <Profile> with <Disposition> disposition' -ForEach @(
        @{ Profile = 'TenantReplica'; Disposition = 'missing' }
        @{ Profile = 'CustomerHandover'; Disposition = 'missing' }
        @{ Profile = 'TenantReplica'; Disposition = 'exact' }
        @{ Profile = 'CustomerHandover'; Disposition = 'exact' }
        @{ Profile = 'TenantReplica'; Disposition = 'mismatched' }
        @{ Profile = 'CustomerHandover'; Disposition = 'mismatched' }
    ) {
        $f = New-RepositoryAssessmentFixture $Profile
        Add-FixtureBinary $f ([Text.Encoding]::UTF8.GetBytes(([string][char]0x1B) + 'source-lab')) -AssertMarker
        if ($Disposition -cne 'missing') {
            $f.Manifest.residualDispositions = @([pscustomobject]@{
                path = $(if ($Disposition -ceq 'exact') { 'reviewed.bin' } else { 'README.md' })
                markerId = 'alias'; reason = 'Exact reviewed synthetic marker exception.'
            })
        }
        $p = $f.Parameters
        if ($Disposition -ceq 'exact') {
            $assessment = Get-RepositoryExportAssessment @p
            $assessment.classification | Should -BeExactly 'Create'
            $assessment.markerCatalogProof.reviewedAssertionsVerified | Should -Be 3
            $assessment.retainedFileCount | Should -Be $(if ($Profile -ceq 'TenantReplica') { 6 } else { 5 })
        }
        else {
            { Get-RepositoryExportAssessment @p } | Should -Throw '*unresolved residual*'
        }
        Test-Path -LiteralPath $p.DestinationRoot | Should -BeFalse
    }

    It 'preserves safe non-NUL binary exceptions only with both exact controls for <Profile> and <Control>' -ForEach @(
        @{ Profile = 'TenantReplica'; Control = 'both' }
        @{ Profile = 'CustomerHandover'; Control = 'both' }
        @{ Profile = 'TenantReplica'; Control = 'missing allowlist' }
        @{ Profile = 'CustomerHandover'; Control = 'missing allowlist' }
        @{ Profile = 'TenantReplica'; Control = 'stale allowlist' }
        @{ Profile = 'CustomerHandover'; Control = 'stale allowlist' }
        @{ Profile = 'TenantReplica'; Control = 'missing classification' }
        @{ Profile = 'CustomerHandover'; Control = 'missing classification' }
        @{ Profile = 'TenantReplica'; Control = 'stale classification' }
        @{ Profile = 'CustomerHandover'; Control = 'stale classification' }
    ) {
        $f = New-RepositoryAssessmentFixture $Profile
        Add-FixtureBinary $f ([byte[]](0x1B, 0x50, 0x4B, 0x03))
        switch ($Control) {
            'missing allowlist' { $f.Manifest.inspectableBinaries = @() }
            'stale allowlist' { $f.Manifest.inspectableBinaries[0].sha256 = 'f' * 64 }
            'missing classification' { $f.Manifest.fileClassifications = @($f.Manifest.fileClassifications | Where-Object path -cne 'reviewed.bin') }
            'stale classification' { $f.Manifest.fileClassifications[-1].expectedOutputSha256 = 'f' * 64 }
        }
        $p = $f.Parameters
        $baseCount = if ($Profile -ceq 'TenantReplica') { 5 } else { 4 }
        switch ($Control) {
            'both' { (Get-RepositoryExportAssessment @p).retainedFileCount | Should -Be ($baseCount + 1) }
            'missing classification' { (Get-RepositoryExportAssessment @p).retainedFileCount | Should -Be $baseCount }
            'stale classification' { { Get-RepositoryExportAssessment @p } | Should -Throw '*classification*' }
            default { { Get-RepositoryExportAssessment @p } | Should -Throw '*allowlisted*' }
        }
        Test-Path -LiteralPath $p.DestinationRoot | Should -BeFalse
    }

    It 'refuses encoding-ambiguous allowlisted bytes for <Profile> and <Encoding>' -ForEach @(
        @{ Profile = 'TenantReplica'; Encoding = 'NUL only' }
        @{ Profile = 'CustomerHandover'; Encoding = 'NUL only' }
        @{ Profile = 'TenantReplica'; Encoding = 'BOMless UTF16LE' }
        @{ Profile = 'CustomerHandover'; Encoding = 'BOMless UTF16BE' }
        @{ Profile = 'TenantReplica'; Encoding = 'BOMless UTF32LE' }
        @{ Profile = 'CustomerHandover'; Encoding = 'BOMless UTF32BE' }
        @{ Profile = 'TenantReplica'; Encoding = 'invalid UTF8' }
        @{ Profile = 'CustomerHandover'; Encoding = 'UTF8 BOM' }
    ) {
        $f = New-RepositoryAssessmentFixture $Profile
        $bytes = switch ($Encoding) {
            'NUL only' { [byte[]]@(0) }
            'BOMless UTF16LE' { [Text.Encoding]::Unicode.GetBytes('source-lab') }
            'BOMless UTF16BE' { [Text.Encoding]::BigEndianUnicode.GetBytes('source-lab') }
            'BOMless UTF32LE' { [Text.UTF32Encoding]::new($false, $false).GetBytes('source-lab') }
            'BOMless UTF32BE' { [Text.UTF32Encoding]::new($true, $false).GetBytes('source-lab') }
            'invalid UTF8' { [byte[]]@(0xC3, 0x28) }
            'UTF8 BOM' { [byte[]]@(0xEF, 0xBB, 0xBF, 0x41) }
        }
        Add-FixtureBinary $f ([byte[]]$bytes)
        $p = $f.Parameters
        $errorPattern = switch ($Encoding) {
            'invalid UTF8' { '*valid UTF-8*' }
            'UTF8 BOM' { '*UTF-8 without BOM*' }
            default { '*residual inspection*' }
        }
        { Get-RepositoryExportAssessment @p } | Should -Throw $errorPattern
        Test-Path -LiteralPath $p.DestinationRoot | Should -BeFalse
    }

    It 'rejects <Case> private source assertions through the canonical entry point' -ForEach @(
        @{ Case = 'unrepresented' }, @{ Case = 'unrepresented lower alias' }, @{ Case = 'unrepresented nested ID' },
        @{ Case = 'stale digest' }, @{ Case = 'wrong occurrence count' },
        @{ Case = 'replacement count mismatch' }
    ) {
        $f = New-RepositoryAssessmentFixture
        switch ($Case) {
            'unrepresented' {
                $f.Manifest.sourceMarkerCatalog = @($f.Manifest.sourceMarkerCatalog | Where-Object id -ne 'alias')
                $f.Manifest.residualMarkers = @($f.Manifest.residualMarkers | Where-Object id -ne 'alias')
            }
            'stale digest' { $f.Manifest.sourceMarkerCatalog[0].sources[0].blobSha256 = 'f' * 64 }
            'wrong occurrence count' { $f.Manifest.sourceMarkerCatalog[0].sources[0].occurrenceCount = 2 }
            'replacement count mismatch' { $f.Manifest.replacements[0].requiredCount = 2 }
        }
        if ($Case -cin @('unrepresented lower alias', 'unrepresented nested ID')) {
            $text = '{"tenantAlias":"source-lab"}'
            if ($Case -ceq 'unrepresented nested ID') { $text = '{"items":[{"subscriptionId":"11111111-1111-4111-8111-111111111111"}]}' }
            [IO.File]::WriteAllText((Join-Path $f.Source 'infra\src\config\tenants\transition.json'), $text, [Text.UTF8Encoding]::new($false))
            Complete-FixtureCommit $f
            $f.Manifest.sourceMarkerCatalog = @($f.Manifest.sourceMarkerCatalog | Where-Object id -ne 'alias')
            $f.Manifest.residualMarkers = @($f.Manifest.residualMarkers | Where-Object id -ne 'alias')
        }
        $p = $f.Parameters
        { Get-RepositoryExportAssessment @p } | Should -Throw
        Test-Path $p.DestinationRoot | Should -BeFalse
    }

    It 'binds <Case> drift to a different shared execution digest' -ForEach @(
        @{ Case = 'destination' }, @{ Case = 'retained inventory' }, @{ Case = 'deny policy' },
        @{ Case = 'marker policy' }, @{ Case = 'replacement' }, @{ Case = 'residual policy' },
        @{ Case = 'profile' }, @{ Case = 'tool path' }, @{ Case = 'tool hash' }, @{ Case = 'tool version' },
        @{ Case = 'suites' }, @{ Case = 'source snapshot' }, @{ Case = 'evidence root' },
        @{ Case = 'retain policy' }, @{ Case = 'classification policy' }, @{ Case = 'binary policy' }, @{ Case = 'synthetic policy' }
    ) {
        $f = New-RepositoryAssessmentFixture
        $p = $f.Parameters
        if ($Case -ceq 'retain policy') {
            [IO.File]::WriteAllText((Join-Path $f.Source 'infra\src\config\tenants\template.json'), '{}', [Text.UTF8Encoding]::new($false))
            Complete-FixtureCommit $f
        }
        $a = Get-RepositoryExportAssessment @p
        $before = New-FixturePlan $a $f
        switch ($Case) {
            'destination' { $p.DestinationRoot = Join-Path $f.Root 'different' }
            'retained inventory' {
                [IO.File]::WriteAllText((Join-Path $f.Source 'extra.md'), 'Synthetic Reviewer')
                Complete-FixtureCommit $f
            }
            'deny policy' { $f.Manifest.deniedPaths = @('not-present.md') }
            'marker policy' {
                $f.Manifest.residualMarkers[0].id = 'company-reviewed'
                $f.Manifest.sourceMarkerCatalog[0].id = 'company-reviewed'
            }
            'replacement' { $f.Manifest.replacements[0].newText = 'Synthetic Reviewer revised' }
            'residual policy' {
                $f.Manifest.residualDispositions = @([pscustomobject]@{ path = 'README.md'; markerId = 'company'; reason = 'Reviewed architectural narrative.' })
            }
            'profile' {
                $f.Manifest.profile = 'CustomerHandover'; $f.Manifest.profilePolicy.denyWorkflows = $true; $p.Profile = 'CustomerHandover'
            }
            'tool path' {
                $copy = Join-Path $f.Root 'powershell-copy.exe'
                Copy-Item $p.ToolIdentities.WindowsPowerShell.path $copy
                $p.ToolIdentities.WindowsPowerShell.path = $copy
            }
            'tool hash' { $p.ToolIdentities.WindowsPowerShell.sha256 = 'a' * 64 }
            'tool version' { $p.ToolIdentities.WindowsPowerShell.version = '5.1-reviewed-revision' }
            'suites' { $f.Manifest.validationSuites = @('RepositorySafety') }
            'source snapshot' { & $f.Git -C $f.Source config synthetic.assessment changed }
            'retain policy' {
                $f.Manifest.retainedTenantArtifacts = @([pscustomobject]@{ path = 'infra/src/config/tenants/template.json'; artifactKind = 'TenantManifest'; customerScope = 'Reviewed synthetic template.' })
            }
            'classification policy' { $f.Manifest.fileClassifications[0].reason = 'Updated reviewed synthetic rationale.' }
            'binary policy' { $f.Manifest.inspectableBinaries = @([pscustomobject]@{ path = 'synthetic.bin'; sha256 = 'a' * 64; reason = 'Exact synthetic exception policy.' }) }
            'synthetic policy' { $f.Manifest.syntheticDataPolicy.reservedNames += 'Synthetic Alternate' }
            'evidence root' {
                $after = New-RepositoryExportActionPlan -Assessment $a -Manifest $f.Manifest -RunId 'e9c21cdd-8bfc-45be-a90d-2e29c5ee4dc1' `
                    -EvidenceRoot (Join-Path $f.Root 'different-evidence') -NowUtc ([datetime]'2026-10-25T06:00:00Z')
            }
        }
        if ($Case -cin @('tool hash', 'suites')) {
            { Get-RepositoryExportAssessment @p } | Should -Throw
        }
        else {
            if ($Case -cne 'evidence root') { $after = New-FixturePlan (Get-RepositoryExportAssessment @p) $f }
            $after.digest | Should -Not -BeExactly $before.digest
        }
    }

    It 'refuses tampered assessed <Case> during planning' -ForEach @(
        @{ Case = 'digest' }, @{ Case = 'order' }, @{ Case = 're-signed order' }, @{ Case = 'manifest' },
        @{ Case = 're-signed replacement policy' }, @{ Case = 're-signed profile policy' }
    ) {
        $f = New-RepositoryAssessmentFixture
        $p = $f.Parameters
        $a = Get-RepositoryExportAssessment @p
        switch ($Case) {
            'digest' { $a.destinationStableId = 'tampered' }
            'order' { [array]::Reverse($a.orderedActions) }
            're-signed order' {
                [array]::Reverse($a.orderedActions)
                $unsigned = [ordered]@{}
                foreach ($property in $a.PSObject.Properties | Where-Object Name -ne 'digest') { $unsigned[$property.Name] = $property.Value }
                $a.digest = Get-RunbookContentDigest $unsigned
            }
            'manifest' { $f.Manifest.replacements[0].newText = 'Changed after assessment' }
            're-signed replacement policy' { $a.replacementPolicyDigest = 'a' * 64 }
            're-signed profile policy' { $a.profilePolicyDigest = 'a' * 64 }
        }
        if ($Case -cin @('re-signed replacement policy', 're-signed profile policy')) {
            $unsigned = [ordered]@{}
            foreach ($property in $a.PSObject.Properties | Where-Object Name -ne 'digest') { $unsigned[$property.Name] = $property.Value }
            $a.digest = Get-RunbookContentDigest $unsigned
        }
        { New-FixturePlan $a $f } | Should -Throw
    }

    It 'rejects an unapproved commit before enumerating or reading any of its blobs' {
        $f = New-RepositoryAssessmentFixture
        $p = $f.Parameters
        $p.ExpectedSourceCommit = 'b' * 40
        $native = $p.NativeCommandRunner
        $p.NativeCommandRunner = {
            param($file, $arguments)
            if ($arguments -contains 'ls-tree') { throw 'Unapproved tree was enumerated.' }
            & $native $file $arguments
        }.GetNewClosure()
        { Get-RepositoryExportAssessment @p } | Should -Throw '*source commit*'
    }

    It 'keeps ignored source values unreadable throughout assessment' {
        $f = New-RepositoryAssessmentFixture
        $p = $f.Parameters
        $ignored = Join-Path $f.Source '.github\workflows\ignored.yml'
        [IO.File]::WriteAllText($ignored, 'synthetic-private-sentinel')
        $locks = @(
            [IO.File]::Open($ignored, 'Open', 'ReadWrite', 'None')
            [IO.File]::Open((Join-Path $f.Source 'private.local.json'), 'Open', 'ReadWrite', 'None')
        )
        try {
            (Get-RepositoryExportAssessment @p).retainedFileCount | Should -Be 5
        }
        finally { foreach ($lock in $locks) { $lock.Dispose() } }
    }

    It 'enforces exact deny descendants and tracked private-artifact boundaries for <Profile>' -ForEach @(
        @{ Profile = 'TenantReplica' }, @{ Profile = 'CustomerHandover' }
    ) {
        $f = New-RepositoryAssessmentFixture $Profile
        foreach ($path in @('private.local.json', 'archive/approvals.json', 'runs/result.md', 'discovery/tenant2.json', 'custom/private.md')) {
            $full = Join-Path $f.Source $path.Replace('/', '\')
            [void][IO.Directory]::CreateDirectory((Split-Path $full -Parent))
            [IO.File]::WriteAllText($full, 'source-lab')
            & $f.Git -C $f.Source add --force -- $path
        }
        & $f.Git -C $f.Source commit --quiet -m 'Synthetic denied artifacts'
        $f.Parameters.ExpectedSourceCommit = (& $f.Git -C $f.Source rev-parse HEAD).Trim()
        $f.Manifest.deniedPaths = @('CUSTOM')
        $p = $f.Parameters
        $a = Get-RepositoryExportAssessment @p
        $a.retainedFileCount | Should -Be $(if ($Profile -ceq 'TenantReplica') { 5 } else { 4 })
        $a.deniedFileCount | Should -Be $(if ($Profile -ceq 'TenantReplica') { 7 } else { 8 })
    }

    It 'refuses reparse ancestors of the source before any Git call' {
        $f = New-RepositoryAssessmentFixture
        $link = Join-Path $f.Root 'source-link'
        [void](New-Item -ItemType Junction -Path $link -Target $f.Source)
        $p = $f.Parameters
        $p.SourceRoot = $link
        $p.NativeCommandRunner = { throw 'Git must not inspect the linked source.' }
        try { { Get-RepositoryExportAssessment @p } | Should -Throw '*reparse*' }
        finally { [IO.Directory]::Delete($link) }
    }

    It 'blocks source snapshot drift during assessment' {
        $f = New-RepositoryAssessmentFixture
        $p = $f.Parameters
        $native = $p.NativeCommandRunner
        $state = [pscustomobject]@{ snapshots = 0 }
        $p.NativeCommandRunner = {
            param($file, $arguments)
            if ($arguments -contains 'status') { $state.snapshots++ }
            $result = & $native $file $arguments
            if ($state.snapshots -eq 2 -and $arguments -contains 'remote') { $result.stdout += "`nextra`thttps://example.invalid/extra (push)" }
            $result
        }.GetNewClosure()
        { Get-RepositoryExportAssessment @p } | Should -Throw '*snapshot drifted*'
    }

    It 'rejects evidence rooted in source or destination' {
        $f = New-RepositoryAssessmentFixture
        $p = $f.Parameters
        $a = Get-RepositoryExportAssessment @p
        foreach ($root in @($f.Source, (Join-Path $f.Source 'evidence'), $p.DestinationRoot, (Join-Path $p.DestinationRoot 'evidence'))) {
            { New-RepositoryExportActionPlan -Assessment $a -Manifest $f.Manifest -RunId ([guid]::NewGuid()) -EvidenceRoot $root -NowUtc ([datetime]::UtcNow) } | Should -Throw
        }
    }
}

Describe 'Explicit repository export profile contract' {
    BeforeAll {
        $script:Root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
        $script:Module = Join-Path $script:Root 'infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1'
        $script:CustomerSample = Join-Path $script:Root 'infra\src\config\runbooks\customer-export.sample.json'
        $script:ReplicaSample = Join-Path $script:Root 'infra\src\config\runbooks\tenant-replica.sample.json'
        $script:LegacyPath = Join-Path $PSScriptRoot '..\fixtures\runbooks\customer-export.v1.valid.json'
        Import-Module $script:Module -Force

        function New-ProfileValue {
            param([string]$Profile = 'CustomerHandover')
            $value = [IO.File]::ReadAllText($script:LegacyPath) | ConvertFrom-Json
            $value | Add-Member NoteProperty profile $Profile
            $value | Add-Member NoteProperty profilePolicy ([pscustomobject][ordered]@{
                denyWorkflows = ($Profile -ceq 'CustomerHandover')
                denyEvidence = $true
                denyTenantTransitions = $true
                denyPrivateState = $true
                denySourceHistory = $true
                denyUntrackedFiles = $true
            })
            $value | Add-Member NoteProperty deniedPaths @()
            return $value
        }

        function Write-ProfileValue {
            param([object]$Value)
            $path = Join-Path $TestDrive (([guid]::NewGuid().ToString('N')) + '.json')
            [IO.File]::WriteAllText($path, ($Value | ConvertTo-Json -Depth 50), [Text.UTF8Encoding]::new($false))
            return $path
        }

        function Write-ManifestRoot {
            param([string]$ObjectJson, [string]$Shape)
            $json = switch ($Shape) {
                'empty array' { '[]' }
                'singleton array' { '[' + $ObjectJson + ']' }
                'multiple array' { '[' + $ObjectJson + ',' + $ObjectJson + ']' }
                'string' { '"synthetic-value"' }
                'number' { '1' }
                'true' { 'true' }
                'false' { 'false' }
                'null' { 'null' }
            }
            $path = Join-Path $TestDrive (([guid]::NewGuid().ToString('N')) + '.json')
            [IO.File]::WriteAllText($path, (" `t`r`n" + $json + "`r`n"), [Text.UTF8Encoding]::new($false))
            return $path
        }
    }

    It 'rejects a <Shape> root through the canonical file importer for <Profile>' -ForEach @(
        foreach ($profile in @('CustomerHandover', 'TenantReplica')) {
            foreach ($shape in @('empty array', 'singleton array', 'multiple array', 'string', 'number', 'true', 'false', 'null')) {
                @{ Profile = $profile; Shape = $shape }
            }
        }
    ) {
        $json = ConvertTo-Json -InputObject (New-ProfileValue -Profile $Profile) -Depth 50
        $path = Write-ManifestRoot -ObjectJson $json -Shape $Shape
        { Import-RepositoryExportManifest -Path $path -ExpectedProfile $Profile } | Should -Throw
    }

    It 'rejects a <Shape> root through the customer compatibility file importer for <Format>' -ForEach @(
        foreach ($format in @('legacy', 'canonical')) {
            foreach ($shape in @('empty array', 'singleton array', 'multiple array', 'string', 'number', 'true', 'false', 'null')) {
                @{ Format = $format; Shape = $shape }
            }
        }
    ) {
        $source = if ($Format -eq 'legacy') { $script:LegacyPath } else { $script:CustomerSample }
        $path = Write-ManifestRoot -ObjectJson ([IO.File]::ReadAllText($source)) -Shape $Shape
        { Import-CustomerExportManifest -Path $path } | Should -Throw
    }

    It 'rejects a <Shape> root before the legacy adapter can normalize it' -ForEach @(
        @{ Shape = 'empty array' }, @{ Shape = 'singleton array' }, @{ Shape = 'multiple array' }
        @{ Shape = 'string' }, @{ Shape = 'number' }, @{ Shape = 'true' }, @{ Shape = 'false' }, @{ Shape = 'null' }
    ) {
        $legacy = [IO.File]::ReadAllText($script:LegacyPath) | ConvertFrom-Json
        $inputValue = $null
        switch ($Shape) {
            'empty array' { $inputValue = [object[]]@() }
            'singleton array' { $inputValue = [object[]]@($legacy) }
            'multiple array' { $inputValue = [object[]]@($legacy, $legacy) }
            'string' { $inputValue = 'synthetic-value' }
            'number' { $inputValue = 1 }
            'true' { $inputValue = $true }
            'false' { $inputValue = $false }
            'null' { $inputValue = $null }
        }
        { ConvertTo-CustomerHandoverManifest -LegacyManifest $inputValue } | Should -Throw
    }

    It 'preserves literal replacement arrays in a plain object through <EntryPoint>' -ForEach @(
        @{ EntryPoint = 'adapter object' }, @{ EntryPoint = 'adapter dictionary' }
        @{ EntryPoint = 'legacy file' }, @{ EntryPoint = 'canonical file' }
    ) {
        $value = [IO.File]::ReadAllText($script:LegacyPath) | ConvertFrom-Json
        $value.replacements[0].expectedOldValue = ('{"items":[null,["synthetic-value"],[],false,1]}' | ConvertFrom-Json).items
        $value.replacements[0].newValue = '{"items":[null,"synthetic-new-value"]}' | ConvertFrom-Json
        switch ($EntryPoint) {
            'adapter object' { $manifest = ConvertTo-CustomerHandoverManifest -LegacyManifest $value }
            'adapter dictionary' {
                $dictionary = @{}
                foreach ($property in $value.PSObject.Properties) {
                    $dictionary[$property.Name] = $property.Value
                }
                $manifest = ConvertTo-CustomerHandoverManifest -LegacyManifest $dictionary
            }
            'legacy file' { $manifest = Import-CustomerExportManifest -Path (Write-ProfileValue $value) }
            'canonical file' {
                $value | Add-Member NoteProperty profile 'CustomerHandover'
                $value | Add-Member NoteProperty profilePolicy (New-ProfileValue).profilePolicy
                $value | Add-Member NoteProperty deniedPaths @()
                $manifest = Import-CustomerExportManifest -Path (Write-ProfileValue $value)
            }
        }
        $manifest.profile | Should -BeExactly 'CustomerHandover'
        (ConvertTo-Json -InputObject $manifest.replacements[0].expectedOldValue -Depth 20 -Compress) | Should -BeExactly '[null,["synthetic-value"],[],false,1]'
        (ConvertTo-Json -InputObject $manifest.replacements[0].newValue -Depth 20 -Compress) | Should -BeExactly '{"items":[null,"synthetic-new-value"]}'
    }

    It 'accepts explicit <Profile> without reading referenced source files' -ForEach @(
        @{ Profile = 'TenantReplica' }, @{ Profile = 'CustomerHandover' }
    ) {
        $path = Write-ProfileValue (New-ProfileValue -Profile $Profile)
        $beforeFiles = @(Get-ChildItem -LiteralPath $TestDrive -Recurse -File | ForEach-Object FullName)
        $manifest = Import-RepositoryExportManifest -Path $path -ExpectedProfile $Profile
        $manifest.schemaVersion | Should -BeExactly '1.0'
        $manifest.profile | Should -BeExactly $Profile
        @($manifest.replacements).Count | Should -Be 2
        @(Get-ChildItem -LiteralPath $TestDrive -Recurse -File | ForEach-Object FullName) | Should -Be $beforeFiles
    }

    It 'requires explicit ExpectedProfile at the canonical command boundary' {
        (Get-Command Import-RepositoryExportManifest).Parameters['ExpectedProfile'].Attributes.Mandatory | Should -Contain $true
    }

    It 'rejects an absent profile instead of inferring from ExpectedProfile' {
        { Import-RepositoryExportManifest -Path $script:LegacyPath -ExpectedProfile CustomerHandover } | Should -Throw '*profile*'
    }

    It 'rejects unknown or non-exact profile <Profile>' -ForEach @(
        @{ Profile = 'Other' }, @{ Profile = 'tenantreplica' }, @{ Profile = '' }
    ) {
        $path = Write-ProfileValue (New-ProfileValue -Profile $Profile)
        { Import-RepositoryExportManifest -Path $path -ExpectedProfile CustomerHandover } | Should -Throw '*profile*'
    }

    It 'rejects ExpectedProfile mismatch for <Profile>' -ForEach @(
        @{ Profile = 'TenantReplica'; Expected = 'CustomerHandover' }
        @{ Profile = 'CustomerHandover'; Expected = 'TenantReplica' }
    ) {
        $path = Write-ProfileValue (New-ProfileValue -Profile $Profile)
        { Import-RepositoryExportManifest -Path $path -ExpectedProfile $Expected } | Should -Throw '*profile*'
    }

    It 'rejects unknown properties at <Location>' -ForEach @(
        @{ Location = 'root' }, @{ Location = 'policy' }, @{ Location = 'replacement' }
    ) {
        $value = New-ProfileValue
        switch ($Location) {
            root { $value | Add-Member NoteProperty skipValidation $true }
            policy { $value.profilePolicy | Add-Member NoteProperty force $true }
            replacement { $value.replacements[0] | Add-Member NoteProperty regex $true }
        }
        $path = Write-ProfileValue $value
        { Import-RepositoryExportManifest -Path $path -ExpectedProfile CustomerHandover } | Should -Throw
    }

    It 'rejects duplicate JSON properties including escaped and nested names' -ForEach @(
        @{ Json = '{"profile":"CustomerHandover","profile":"CustomerHandover"}' }
        @{ Json = '{"profile":"CustomerHandover","profi\u006ce":"CustomerHandover"}' }
        @{ Json = '{"profilePolicy":{"denyEvidence":true,"denyEvidence":true}}' }
    ) {
        $path = Join-Path $TestDrive 'duplicate.json'
        [IO.File]::WriteAllText($path, $Json, [Text.UTF8Encoding]::new($false))
        { Import-RepositoryExportManifest -Path $path -ExpectedProfile CustomerHandover } | Should -Throw '*duplicate JSON property*'
    }

    It 'rejects duplicate IDs in <Collection>' -ForEach @(
        @{ Collection = 'replacements' }, @{ Collection = 'residualMarkers' }, @{ Collection = 'sourceMarkerCatalog' }
    ) {
        $value = New-ProfileValue
        $value.$Collection[1].id = $value.$Collection[0].id
        $path = Write-ProfileValue $value
        { Import-RepositoryExportManifest -Path $path -ExpectedProfile CustomerHandover } | Should -Throw
    }

    It 'rejects weakening <Policy> for <Profile>' -ForEach @(
        @{ Profile = 'CustomerHandover'; Policy = 'denyWorkflows' }
        @{ Profile = 'TenantReplica'; Policy = 'denyWorkflows' }
        @{ Profile = 'CustomerHandover'; Policy = 'denyEvidence' }
        @{ Profile = 'TenantReplica'; Policy = 'denyEvidence' }
        @{ Profile = 'CustomerHandover'; Policy = 'denyTenantTransitions' }
        @{ Profile = 'TenantReplica'; Policy = 'denyTenantTransitions' }
        @{ Profile = 'CustomerHandover'; Policy = 'denyPrivateState' }
        @{ Profile = 'TenantReplica'; Policy = 'denyPrivateState' }
        @{ Profile = 'CustomerHandover'; Policy = 'denySourceHistory' }
        @{ Profile = 'TenantReplica'; Policy = 'denySourceHistory' }
        @{ Profile = 'CustomerHandover'; Policy = 'denyUntrackedFiles' }
        @{ Profile = 'TenantReplica'; Policy = 'denyUntrackedFiles' }
    ) {
        $value = New-ProfileValue -Profile $Profile
        $value.profilePolicy.$Policy = -not $value.profilePolicy.$Policy
        $path = Write-ProfileValue $value
        { Import-RepositoryExportManifest -Path $path -ExpectedProfile $Profile } | Should -Throw '*policy*'
    }

    It 'rejects truthy strings instead of policy booleans' {
        $value = New-ProfileValue
        $value.profilePolicy.denyEvidence = 'true'
        $path = Write-ProfileValue $value
        { Import-RepositoryExportManifest -Path $path -ExpectedProfile CustomerHandover } | Should -Throw '*policy*'
    }

    It 'rejects a missing policy field' {
        $value = New-ProfileValue
        $value.profilePolicy.PSObject.Properties.Remove('denyEvidence')
        $path = Write-ProfileValue $value
        { Import-RepositoryExportManifest -Path $path -ExpectedProfile CustomerHandover } | Should -Throw '*policy*'
    }

    It 'rejects non-exact <Path> in <Location>' -ForEach @(
        @{ Path = 'docs/**'; Location = 'deny' }
        @{ Path = 'docs/?'; Location = 'deny' }
        @{ Path = 'docs/[abc]'; Location = 'deny' }
        @{ Path = '../README.md'; Location = 'deny' }
        @{ Path = 'C:/README.md'; Location = 'deny' }
        @{ Path = '/README.md'; Location = 'deny' }
        @{ Path = 'docs\README.md'; Location = 'deny' }
        @{ Path = 'docs//README.md'; Location = 'deny' }
        @{ Path = 'docs/README.md.'; Location = 'deny' }
        @{ Path = 'docs/README.md '; Location = 'deny' }
        @{ Path = 'docs/CON.json'; Location = 'deny' }
        @{ Path = 'docs/**.md'; Location = 'replacement' }
        @{ Path = 'infra/src/config/tenants/*.json'; Location = 'retain' }
    ) {
        $value = New-ProfileValue
        switch ($Location) {
            deny { $value.deniedPaths = @($Path) }
            replacement { $value.replacements[1].path = $Path }
            retain { $value.retainedTenantArtifacts[0].path = $Path }
        }
        $path = Write-ProfileValue $value
        { Import-RepositoryExportManifest -Path $path -ExpectedProfile CustomerHandover } | Should -Throw '*exact path*'
    }

    It 'rejects wildcard JSON selectors <Selector>' -ForEach @(
        @{ Selector = '/tenant*Alias' }, @{ Selector = '/tenant?' }, @{ Selector = '/[tenant]' }, @{ Selector = '/bad~2escape' }
    ) {
        $value = New-ProfileValue
        $value.replacements[0].selector = $Selector
        $path = Write-ProfileValue $value
        { Import-RepositoryExportManifest -Path $path -ExpectedProfile CustomerHandover } | Should -Throw '*Pointer*'
    }

    It 'rejects contradictory retained artifact and denied path <Denied>' -ForEach @(
        @{ Denied = 'infra/src/config/tenants/customer-synthetic.json' }
        @{ Denied = 'infra/src/config/tenants' }
        @{ Denied = 'INFRA/SRC/CONFIG/TENANTS' }
    ) {
        $value = New-ProfileValue
        $value.deniedPaths = @($Denied)
        $path = Write-ProfileValue $value
        { Import-RepositoryExportManifest -Path $path -ExpectedProfile CustomerHandover } | Should -Throw '*contradict*'
    }

    It 'does not confuse sibling path prefixes with contradictory rules' {
        $value = New-ProfileValue
        $value.deniedPaths = @('infra/src/config/tenants-sibling')
        $path = Write-ProfileValue $value
        (Import-RepositoryExportManifest -Path $path -ExpectedProfile CustomerHandover).deniedPaths | Should -Be @('infra/src/config/tenants-sibling')
    }

    It 'rejects case-colliding retained paths' {
        $value = New-ProfileValue
        $entry = $value.retainedTenantArtifacts[0] | ConvertTo-Json | ConvertFrom-Json
        $entry.path = $entry.path.ToUpperInvariant()
        $value.retainedTenantArtifacts += $entry
        $path = Write-ProfileValue $value
        { Import-RepositoryExportManifest -Path $path -ExpectedProfile CustomerHandover } | Should -Throw
    }

    It 'rejects case-colliding deny rules' {
        $value = New-ProfileValue
        $value.deniedPaths = @('docs/private', 'DOCS/PRIVATE')
        $path = Write-ProfileValue $value
        { Import-RepositoryExportManifest -Path $path -ExpectedProfile CustomerHandover } | Should -Throw '*unique*'
    }

    It 'rejects denied paths used by <Location>' -ForEach @(
        @{ Location = 'replacement' }, @{ Location = 'disposition' }, @{ Location = 'classification' }, @{ Location = 'binary' }
    ) {
        $value = New-ProfileValue
        switch ($Location) {
            replacement { $value.deniedPaths = @('README.md') }
            disposition { $value.deniedPaths = @('docs/specs') }
            classification { $value.deniedPaths = @('infra/tests/fixtures') }
            binary {
                $value.deniedPaths = @('assets')
                $value.inspectableBinaries = @([pscustomobject]@{ path = 'assets/synthetic.png'; sha256 = ('a' * 64); reason = 'Synthetic image.' })
            }
        }
        $path = Write-ProfileValue $value
        { Import-RepositoryExportManifest -Path $path -ExpectedProfile CustomerHandover } | Should -Throw '*contradict*'
    }

    It 'rejects ambiguous JSON shapes and coercible primitive types' -ForEach @(
        @{ Field = 'retainedTenantArtifacts'; InvalidValue = $null }
        @{ Field = 'replacements'; InvalidValue = @{} }
        @{ Field = 'tenantAlias'; InvalidValue = 123 }
        @{ Field = 'schemaVersion'; InvalidValue = 1.0 }
        @{ Field = 'deniedPaths'; InvalidValue = 'docs/private' }
    ) {
        $value = New-ProfileValue
        $value.$Field = $InvalidValue
        $path = Write-ProfileValue $value
        { Import-RepositoryExportManifest -Path $path -ExpectedProfile CustomerHandover } | Should -Throw
    }

    It 'rejects noninteger occurrence counts' {
        $value = New-ProfileValue
        $value.replacements[1].requiredCount = '2'
        $path = Write-ProfileValue $value
        { Import-RepositoryExportManifest -Path $path -ExpectedProfile CustomerHandover } | Should -Throw
    }

    It 'rejects a UTF-8 BOM' {
        $path = Join-Path $TestDrive 'bom.json'
        [IO.File]::WriteAllText($path, ((New-ProfileValue) | ConvertTo-Json -Depth 50), [Text.UTF8Encoding]::new($true))
        { Import-RepositoryExportManifest -Path $path -ExpectedProfile CustomerHandover } | Should -Throw '*UTF-8 without BOM*'
    }

    It 'rejects malformed UTF-8 bytes' {
        $path = Join-Path $TestDrive 'invalid-utf8.json'
        [IO.File]::WriteAllBytes($path, [byte[]]@(0x7B, 0xC3, 0x28, 0x7D))
        { Import-RepositoryExportManifest -Path $path -ExpectedProfile CustomerHandover } | Should -Throw '*Unable to translate bytes*'
    }

    It 'preserves valid non-ASCII UTF-8 text' {
        $value = New-ProfileValue
        $value.customerScope = 'Synthetic ' + [char]0x00E9 + ' scope'
        $path = Write-ProfileValue $value
        (Import-RepositoryExportManifest -Path $path -ExpectedProfile CustomerHandover).customerScope | Should -BeExactly $value.customerScope
    }

    It 'preserves timestamp-shaped JSON replacement values as literal strings across hosts' {
        $value = New-ProfileValue
        $value.replacements[0].expectedOldValue = '2026-01-01T00:00:00Z'
        $value.replacements[0].newValue = '2026-01-02T00:00:00Z'
        $path = Write-ProfileValue $value
        $manifest = Import-RepositoryExportManifest -Path $path -ExpectedProfile CustomerHandover
        ($manifest.replacements[0].expectedOldValue -is [string]) | Should -BeTrue
        $manifest.replacements[0].expectedOldValue | Should -BeExactly '2026-01-01T00:00:00Z'
        $manifest.replacements[0].newValue | Should -BeExactly '2026-01-02T00:00:00Z'
    }

    It 'preserves nested JSON arrays and null replacement elements without rewriting their meaning' {
        $value = New-ProfileValue
        $value.replacements[0].expectedOldValue = ('{"items":[null,["synthetic-value"],[],false,1]}' | ConvertFrom-Json).items
        $value.replacements[0].newValue = '{"items":[null,"synthetic-new-value"]}' | ConvertFrom-Json
        $path = Write-ProfileValue $value
        $manifest = Import-RepositoryExportManifest -Path $path -ExpectedProfile CustomerHandover
        (ConvertTo-Json -InputObject $manifest.replacements[0].expectedOldValue -Depth 20 -Compress) | Should -BeExactly '[null,["synthetic-value"],[],false,1]'
        ($manifest.replacements[0].newValue | ConvertTo-Json -Depth 20 -Compress) | Should -BeExactly '{"items":[null,"synthetic-new-value"]}'
    }

    It 'keeps unknown validation suite IDs blocking' {
        $value = New-ProfileValue
        $value.validationSuites = @('Invoke-CustomerCommand')
        $path = Write-ProfileValue $value
        { Import-RepositoryExportManifest -Path $path -ExpectedProfile CustomerHandover } | Should -Throw '*fixed local suite IDs*'
    }

    It 'rejects relative manifest locations before reading them' {
        { Import-RepositoryExportManifest -Path 'relative.json' -ExpectedProfile CustomerHandover } | Should -Throw '*absolute*'
    }

    It 'imports both required synthetic samples as explicitly profiled contracts' {
        (Import-RepositoryExportManifest -Path $script:CustomerSample -ExpectedProfile CustomerHandover).profile | Should -BeExactly 'CustomerHandover'
        (Import-RepositoryExportManifest -Path $script:ReplicaSample -ExpectedProfile TenantReplica).profile | Should -BeExactly 'TenantReplica'
    }

    It 'preserves empty and singleton arrays in canonical output' {
        $manifest = Import-RepositoryExportManifest -Path $script:CustomerSample -ExpectedProfile CustomerHandover
        ($manifest.inspectableBinaries -is [array]) | Should -BeTrue
        $manifest.inspectableBinaries.Count | Should -Be 0
        ($manifest.retainedTenantArtifacts -is [array]) | Should -BeTrue
        $manifest.retainedTenantArtifacts.Count | Should -Be 1
        ($manifest.sourceMarkerCatalog[0].sources -is [array]) | Should -BeTrue
        $manifest.sourceMarkerCatalog[0].sources.Count | Should -Be 1
    }

    It 'maps historical v1 input to the exact canonical customer sample without mutating input' {
        $legacy = [IO.File]::ReadAllText($script:LegacyPath) | ConvertFrom-Json
        $before = ConvertTo-TenantLifecycleCanonicalJson -InputObject $legacy
        $expected = ConvertTo-TenantLifecycleCanonicalJson -InputObject ([IO.File]::ReadAllText($script:CustomerSample) | ConvertFrom-Json)
        $first = ConvertTo-CustomerHandoverManifest -LegacyManifest $legacy
        $second = Import-CustomerExportManifest -Path $script:LegacyPath
        $first.profile | Should -BeExactly 'CustomerHandover'
        $first.profilePolicy.denyWorkflows | Should -BeTrue
        $actualBytes = [Text.UTF8Encoding]::new($false).GetBytes((ConvertTo-TenantLifecycleCanonicalJson -InputObject $first))
        [Convert]::ToBase64String($actualBytes) | Should -BeExactly ([Convert]::ToBase64String([Text.UTF8Encoding]::new($false).GetBytes($expected)))
        (ConvertTo-TenantLifecycleCanonicalJson -InputObject $second) | Should -BeExactly $expected
        (ConvertTo-TenantLifecycleCanonicalJson -InputObject (ConvertTo-CustomerHandoverManifest -LegacyManifest $legacy)) | Should -BeExactly $expected
        (ConvertTo-TenantLifecycleCanonicalJson -InputObject $legacy) | Should -BeExactly $before
    }

    It 'does not allow the legacy adapter to reinterpret a profiled manifest' {
        { ConvertTo-CustomerHandoverManifest -LegacyManifest (New-ProfileValue -Profile TenantReplica) } | Should -Throw
        { Import-CustomerExportManifest -Path $script:ReplicaSample } | Should -Throw '*profile*'
    }

    It 'does not silently drop unknown legacy fields' {
        $legacy = [IO.File]::ReadAllText($script:LegacyPath) | ConvertFrom-Json
        $legacy | Add-Member NoteProperty force $true
        { ConvertTo-CustomerHandoverManifest -LegacyManifest $legacy } | Should -Throw '*closed*'
    }

    It 'keeps the historical invalid fixture invalid through both legacy interfaces' {
        $path = Join-Path $PSScriptRoot '..\fixtures\runbooks\customer-export.invalid.json'
        { Import-CustomerExportManifest -Path $path } | Should -Throw '*exact path*'
        $legacy = [IO.File]::ReadAllText($path) | ConvertFrom-Json
        { ConvertTo-CustomerHandoverManifest -LegacyManifest $legacy } | Should -Throw '*exact path*'
    }

    It 'keeps customer workflow evidence and vendored replacement denials' -ForEach @(
        @{ Prohibited = '.github/workflows/customer.md' }
        @{ Prohibited = 'infra/evidence/customer.md' }
        @{ Prohibited = '.github/skills/vendor/README.md' }
    ) {
        $value = New-ProfileValue
        $value.replacements[1].path = $Prohibited
        $path = Write-ProfileValue $value
        { Import-RepositoryExportManifest -Path $path -ExpectedProfile CustomerHandover } | Should -Throw '*prohibited replacement path*'
    }

    It 'does not let legacy consumers silently ignore new deny rules' {
        $value = New-ProfileValue
        $value.deniedPaths = @('docs/private')
        $path = Write-ProfileValue $value
        { Import-CustomerExportManifest -Path $path } | Should -Throw '*deniedPaths*'
    }

    It 'exports both new operations from both module declarations' {
        $exports = (Test-ModuleManifest $script:Module).ExportedFunctions.Keys
        foreach ($name in @('Import-RepositoryExportManifest', 'ConvertTo-CustomerHandoverManifest')) {
            $exports | Should -Contain $name
            Get-Command $name -Module Caldova.HrFrontier.Bootstrap | Should -Not -BeNullOrEmpty
        }
    }
}
