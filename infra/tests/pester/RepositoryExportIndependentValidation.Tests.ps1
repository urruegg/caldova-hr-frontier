Set-StrictMode -Version Latest

BeforeAll {
    $script:Repository = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
    $script:ModulePath = Join-Path $script:Repository 'infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1'
    Import-Module $script:ModulePath -Force
    $script:Git = 'C:\Program Files\Git\cmd\git.exe'
    $script:WindowsPS = Join-Path ([Environment]::SystemDirectory) 'WindowsPowerShell\v1.0\powershell.exe'
    function New-IndependentFixture {
        param([string]$Profile = 'CustomerHandover')
        $root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $source = Join-Path $root 'src'
        $destination = Join-Path $root 'out'
        $files = [ordered]@{
            'README.md' = "Source Lab`n"
            'infra/src/config/tenants/transition.json' = '{"TenantAlias":"source-lab"}'
            'infra/src/config/github/action-pins.json' = '{"schemaVersion":"1.0","actions":{"actions/checkout":{"sourceRef":"synthetic","sha":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}}}'
            'infra/src/bicep/main.bicep' = "targetScope = 'subscription'`noutput synthetic string = 'synthetic-value'`n"
            'infra/tests/pester/RunbookContracts.Tests.ps1' = "Describe 'synthetic runbook' { It 'checks the retained document' { (Get-Content -Raw README.md).Trim() | Should -BeExactly 'Synthetic Reviewer' } }"
            'infra/tests/pester/RunbookStaticSafety.Tests.ps1' = "Describe 'synthetic boundary' { It 'has no metadata' { Test-Path .git | Should -BeFalse } }"
            'hr/tests/pester/Synthetic.Tests.ps1' = "Describe 'synthetic HR' { It 'has infrastructure source' { Test-Path infra\src\bicep\main.bicep | Should -BeTrue } }"
            '.github/cli/tests/WorkflowContract.Tests.ps1' = "Describe 'synthetic static contract' { It 'has action pins' { Test-Path infra\src\config\github\action-pins.json | Should -BeTrue } }"
            '.github/workflows/validate-repository.yml' = "steps:`n  - uses: actions/checkout@aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa`n"
            'azure-pipelines.yml' = "trigger: none`n"
            'infra/src/pipelines/templates/check.yml' = "steps: []`n"
            'infra/tests/pester/PipelineContract.Tests.ps1' = "Describe 'synthetic pipeline' { It 'retains templates' { Test-Path infra\src\pipelines\templates\check.yml | Should -BeTrue } }"
        }
        $files['.github/cli/verify-repository-safety.ps1'] = [IO.File]::ReadAllText((Join-Path $script:Repository '.github\cli\verify-repository-safety.ps1'))
        $files['.github/cli/Get-HistoryFreeRepositoryInventory.ps1'] = [IO.File]::ReadAllText((Join-Path $script:Repository '.github\cli\Get-HistoryFreeRepositoryInventory.ps1'))
        foreach ($path in $files.Keys) {
            $target = Join-Path $source $path.Replace('/', '\')
            [void][IO.Directory]::CreateDirectory((Split-Path $target -Parent))
            [IO.File]::WriteAllText($target, $files[$path], [Text.UTF8Encoding]::new($false))
        }
        & $script:Git -C $source init --quiet
        if ($LASTEXITCODE -ne 0) { throw 'Synthetic init failed.' }
        foreach ($entry in @(@('user.name', 'Synthetic Reviewer'), @('user.email', 'reviewer@example.invalid'), @('core.autocrlf', 'false'))) {
            & $script:Git -C $source config @entry
            if ($LASTEXITCODE -ne 0) { throw 'Synthetic configuration failed.' }
        }
        & $script:Git -C $source add .
        if ($LASTEXITCODE -ne 0) { throw 'Synthetic staging failed.' }
        & $script:Git -C $source commit --quiet -m 'Synthetic independent validation'
        if ($LASTEXITCODE -ne 0) { throw 'Synthetic commit failed.' }
        $commit = (& $script:Git -C $source rev-parse HEAD).Trim()
        if ($LASTEXITCODE -ne 0) { throw 'Synthetic commit read failed.' }
        $hash = (Get-FileHash (Join-Path $source 'README.md')).Hash.ToLowerInvariant()
        $tenantHash = (Get-FileHash (Join-Path $source 'infra\src\config\tenants\transition.json')).Hash.ToLowerInvariant()
        $manifest = [pscustomobject]@{
            schemaVersion = '1.0'; tenantAlias = 'source-lab'; customerScope = 'Synthetic independent validation'
            profile = $Profile
            profilePolicy = [pscustomobject]@{
                denyWorkflows = ($Profile -ceq 'CustomerHandover'); denyEvidence = $true; denyTenantTransitions = $true
                denyPrivateState = $true; denySourceHistory = $true; denyUntrackedFiles = $true
            }
            deniedPaths = @(); retainedTenantArtifacts = @(); residualDispositions = @(); inspectableBinaries = @()
            replacements = @([pscustomobject]@{ id = 'title'; path = 'README.md'; format = 'MarkdownExact'; expectedOldText = 'Source Lab'; newText = 'Synthetic Reviewer'; requiredCount = 1 })
            residualMarkers = @(
                [pscustomobject]@{ id = 'company'; category = 'CompanyName'; value = 'Source Lab'; comparison = 'Ordinal' }
                [pscustomobject]@{ id = 'alias'; category = 'TenantAlias'; value = 'source-lab'; comparison = 'OrdinalIgnoreCase' }
            )
            sourceMarkerCatalog = @(
                [pscustomobject]@{ id = 'company'; category = 'CompanyName'; value = 'Source Lab'; comparison = 'Ordinal'; sources = @([pscustomobject]@{ path = 'README.md'; blobSha256 = $hash; occurrenceCount = 1 }) }
                [pscustomobject]@{ id = 'alias'; category = 'TenantAlias'; value = 'source-lab'; comparison = 'OrdinalIgnoreCase'; sources = @([pscustomobject]@{ path = 'infra/src/config/tenants/transition.json'; blobSha256 = $tenantHash; occurrenceCount = 1 }) }
            )
            syntheticDataPolicy = [pscustomobject]@{ reservedNames = @('Synthetic Reviewer'); reservedDomains = @('example.invalid'); reservedIdPrefixes = @('synthetic-') }
            fileClassifications = @(
                foreach ($path in $files.Keys | Where-Object { $_ -cne 'README.md' -and $_ -cne 'infra/src/config/tenants/transition.json' }) {
                    $digest = (Get-FileHash (Join-Path $source $path.Replace('/', '\'))).Hash.ToLowerInvariant()
                    [pscustomobject]@{ path = $path; sourceBlobSha256 = $digest; expectedOutputSha256 = $digest; classification = 'ReviewedNonPersonal'; reason = 'Reviewed fabricated local test input.' }
                }
            )
            validationSuites = @('Pester', 'RepositorySafety', 'BicepBuild')
        }
        [void][IO.Directory]::CreateDirectory($destination)
        foreach ($path in $files.Keys) {
            if ($path -ceq 'infra/src/config/tenants/transition.json' -or
                ($Profile -ceq 'CustomerHandover' -and $path.StartsWith('.github/workflows/'))) { continue }
            $target = Join-Path $destination $path.Replace('/', '\')
            [void][IO.Directory]::CreateDirectory((Split-Path $target -Parent))
            $value = if ($path -ceq 'README.md') { "Synthetic Reviewer`n" } else { $files[$path] }
            [IO.File]::WriteAllText($target, $value, [Text.UTF8Encoding]::new($false))
        }
        $tools = [pscustomobject]@{
            Git = [pscustomobject]@{ path = $script:Git; sha256 = (Get-FileHash $script:Git).Hash.ToLowerInvariant(); version = (& $script:Git --version).Trim() }
            WindowsPowerShell = [pscustomobject]@{ path = $script:WindowsPS; sha256 = (Get-FileHash $script:WindowsPS).Hash.ToLowerInvariant(); version = '5.1' }
            Bicep = [pscustomobject]@{ path = $script:WindowsPS; sha256 = (Get-FileHash $script:WindowsPS).Hash.ToLowerInvariant(); version = 'synthetic-injected-only' }
        }
        $p = @{
            SourceRoot = $source; ExpectedSourceCommit = $commit; DestinationRoot = $destination
            Manifest = $manifest; Profile = $Profile
            RepositoryIdentity = '01ba4719c80b6fe911b091a7c05124b64eeece964e09c058ef8f9805daca546b'
            ToolIdentities = $tools
            ValidationRunner = { param($id, $file, $arguments, $tree) [pscustomobject]@{ suite = $id; exitCode = 0 } }
        }
        [pscustomobject]@{ Root = $root; Source = $source; Destination = $destination; Manifest = $manifest; Parameters = $p }
    }
    function Get-IndependentResult {
        param($Fixture)
        $p = $Fixture.Parameters
        Test-RepositoryExportIndependent @p
    }
}

Describe 'Independent complete reconstruction' {
    It 'rejects a volume root before any object enumeration or drive-relative alias resolution' {
        InModuleScope Caldova.HrFrontier.Bootstrap {
            Mock Get-Item { throw 'Unsafe volume inspection was attempted.' }
            { Get-HistoryFreeRepositoryInventory -Root 'C:\' } | Should -Throw '*volume root*'
        }
    }

    It 'inspects the actual objects even when source proof is unavailable' {
        $f = New-IndependentFixture
        $f.Parameters.RepositoryIdentity = 'a' * 64
        [IO.File]::WriteAllText((Join-Path $f.Destination '.git'), 'synthetic interrupted metadata')
        $r = Get-IndependentResult $f
        $r.status | Should -BeExactly 'Failed'
        @($r.deniedFindings.category) | Should -Contain 'GitMetadata'
        $r.actualFileCount | Should -Be 13
    }

    It 'reports a missing required PowerShell tool as Blocked, not a fake pass or silent skip' {
        $f = New-IndependentFixture
        [void]$f.Parameters.Remove('ToolIdentities')
        $git = $script:Git
        $f.Parameters.CommandResolver = { param($name) if ($name -ceq 'git.exe') { $git } }.GetNewClosure()
        $r = Get-IndependentResult $f
        $r.status | Should -BeExactly 'Blocked'
        @($r.suiteResults.category) | Should -Contain 'ToolUnavailable'
        $r.sourceUnchanged | Should -BeFalse
    }

    It 'detects fresh reviewed input drift introduced by a suite: <Case>' -ForEach @(
        @{ Case = 'manifest' }, @{ Case = 'policy' }, @{ Case = 'tool' }
    ) {
        $f = New-IndependentFixture
        $caseName = $Case; $manifest = $f.Manifest
        $tool = Join-Path $f.Root 'synthetic-tool.exe'
        [IO.File]::WriteAllText($tool, 'synthetic executable identity, never executed')
        $f.Parameters.ToolIdentities.Bicep = [pscustomobject]@{ path = $tool; sha256 = (Get-FileHash $tool).Hash.ToLowerInvariant(); version = 'synthetic-injected-only' }
        $f.Parameters.ValidationRunner = {
            param($id)
            if ($id -ceq 'Pester') {
                switch ($caseName) {
                    'manifest' { $manifest.customerScope = 'Changed after review' }
                    'policy' { $manifest.profilePolicy.denyPrivateState = $false }
                    'tool' { [IO.File]::AppendAllText($tool, 'changed') }
                }
            }
            [pscustomobject]@{ suite = $id; exitCode = 0 }
        }.GetNewClosure()
        $r = Get-IndependentResult $f
        $r.status | Should -BeExactly 'Failed'
        if ($Case -cne 'tool') { @($r.deniedFindings.category) | Should -Contain 'ReviewedInputDrift' }
        else { @($r.suiteResults.status) | Should -Contain 'Failed' }
    }

    It 'blocks profile minimums omitted from fresh source and manifest: <Path>' -ForEach @(
        @{ Path = 'infra/tests/pester/RunbookContracts.Tests.ps1' }
        @{ Path = 'infra/tests/pester/RunbookStaticSafety.Tests.ps1' }
        @{ Path = '.github/cli/tests/WorkflowContract.Tests.ps1' }
        @{ Path = '.github/cli/Get-HistoryFreeRepositoryInventory.ps1' }
        @{ Path = 'hr/tests/pester/Synthetic.Tests.ps1' }
        @{ Path = 'infra/tests/pester/PipelineContract.Tests.ps1' }
    ) {
        $f = New-IndependentFixture TenantReplica
        foreach ($root in @($f.Source, $f.Destination)) {
            $full = Join-Path $root $Path.Replace('/', '\')
            Remove-Item $full
            $directory = Split-Path $full -Parent
            while ($directory -cne $root -and @(Get-ChildItem -LiteralPath $directory -Force).Count -eq 0) {
                [IO.Directory]::Delete($directory)
                $directory = Split-Path $directory -Parent
            }
        }
        & $script:Git -C $f.Source add -A
        if ($LASTEXITCODE -ne 0) { throw 'Synthetic staging failed.' }
        & $script:Git -C $f.Source commit --quiet -m 'Synthetic omitted suite minimum'
        if ($LASTEXITCODE -ne 0) { throw 'Synthetic commit failed.' }
        $f.Parameters.ExpectedSourceCommit = (& $script:Git -C $f.Source rev-parse HEAD).Trim()
        if ($LASTEXITCODE -ne 0) { throw 'Synthetic commit read failed.' }
        $f.Manifest.fileClassifications = @($f.Manifest.fileClassifications | Where-Object path -CNE $Path)
        $r = Get-IndependentResult $f
        $r.status | Should -BeExactly 'Blocked'
        @($r.suiteResults.category) | Should -Contain 'SuiteAssetsMissing'
    }

    It 'rereads committed blobs and returns all eleven required fields for <Profile>' -ForEach @(
        @{ Profile = 'TenantReplica' }, @{ Profile = 'CustomerHandover' }
    ) {
        $f = New-IndependentFixture $Profile
        $result = Get-IndependentResult $f
        $result.status | Should -BeExactly 'Passed'
        $result.profile | Should -BeExactly $Profile
        foreach ($name in @('expectedFileCount', 'actualFileCount', 'contentTreeDigest', 'unexpectedPaths', 'missingPaths', 'mismatchedPaths', 'deniedFindings', 'suiteResults', 'sourceUnchanged', 'status')) {
            $result.PSObject.Properties.Name | Should -Contain $name
        }
        $result.expectedFileCount | Should -Be $(if ($Profile -ceq 'TenantReplica') { 13 } else { 12 })
        $result.actualFileCount | Should -Be $result.expectedFileCount
        $result.contentTreeDigest | Should -Match '^[0-9a-f]{64}$'
        $result.sourceUnchanged | Should -BeTrue
        @($result.suiteResults).Count | Should -Be 3
        Test-Path (Join-Path $f.Destination '.git') | Should -BeFalse
        Test-Path (Join-Path $f.Destination 'testResults.xml') | Should -BeFalse
    }

    It 'rejects <Case> with an exact private diagnostic path' -ForEach @(
        @{ Case = 'added file'; Path = 'extra.md'; Field = 'unexpectedPaths' }
        @{ Case = 'missing file'; Path = 'README.md'; Field = 'missingPaths' }
        @{ Case = 'changed bytes'; Path = 'README.md'; Field = 'mismatchedPaths' }
        @{ Case = 'empty directory'; Path = 'empty'; Field = 'unexpectedPaths' }
        @{ Case = 'case change'; Path = 'readme.md'; Field = 'unexpectedPaths' }
        @{ Case = 'interrupted staging'; Path = '.customer-export-incomplete'; Field = 'unexpectedPaths' }
    ) {
        $f = New-IndependentFixture
        $target = Join-Path $f.Destination $Path
        switch ($Case) {
            'missing file' { [IO.File]::Delete($target) }
            'changed bytes' { [IO.File]::WriteAllText($target, "Synthetic Reviewer`r`n") }
            'empty directory' { [void][IO.Directory]::CreateDirectory($target) }
            'interrupted staging' { [void][IO.Directory]::CreateDirectory($target) }
            'case change' { Rename-Item (Join-Path $f.Destination 'README.md') 'case.tmp'; Rename-Item (Join-Path $f.Destination 'case.tmp') 'readme.md' }
            default { [IO.File]::WriteAllText($target, 'synthetic extra') }
        }
        $r = Get-IndependentResult $f
        $r.status | Should -BeExactly 'Failed'
        @($r.($Field)) | Should -Contain $Path
        @($r.suiteResults).Count | Should -Be 0
        Test-Path $target | Should -Be ($Case -cne 'missing file')
    }

    It 'rejects denied object <Path> without trusting stored metadata' -ForEach @(
        @{ Path = '.git'; Category = 'GitMetadata' }
        @{ Path = 'evidence/staged.json'; Category = 'PrivateArtifactDenied' }
        @{ Path = 'tenant1.local.json'; Category = 'PrivateArtifactDenied' }
        @{ Path = '.github/workflows/hidden.yml'; Category = 'WorkflowBoundary' }
    ) {
        $f = New-IndependentFixture
        $target = Join-Path $f.Destination $Path.Replace('/', '\')
        [void][IO.Directory]::CreateDirectory((Split-Path $target -Parent))
        [IO.File]::WriteAllText($target, '{"status":"Passed","inventory":[],"replacementLog":[]}')
        $r = Get-IndependentResult $f
        $r.status | Should -BeExactly 'Failed'
        @($r.deniedFindings.category) | Should -Contain $Category
        @($r.unexpectedPaths) | Should -Contain $Path
    }

    It 'does not accept an Apply assessment, matching fake hash, or replacement log as content proof' {
        $f = New-IndependentFixture
        [IO.File]::WriteAllText((Join-Path $f.Destination 'README.md'), "Source Lab`n")
        [IO.File]::WriteAllText((Join-Path $f.Destination 'assessment.json'), '{"status":"Passed","fileDigests":{},"replacementLog":[{"ruleId":"title"}]}')
        $r = Get-IndependentResult $f
        $r.status | Should -BeExactly 'Failed'
        @($r.mismatchedPaths) | Should -Contain 'README.md'
        @($r.deniedFindings.category) | Should -Contain 'UndisposedResidual'
        @($r.unexpectedPaths) | Should -Contain 'assessment.json'
    }

    It 'rejects unsupported staged <Case> rather than skipping inspection' -ForEach @(
        @{ Case = 'NUL'; Bytes = [byte[]]@(65, 0, 66) }
        @{ Case = 'invalid UTF8'; Bytes = [byte[]]@(255, 65) }
        @{ Case = 'BOM'; Bytes = [byte[]]@(239, 187, 191, 65) }
    ) {
        $f = New-IndependentFixture
        [IO.File]::WriteAllBytes((Join-Path $f.Destination 'README.md'), $Bytes)
        $r = Get-IndependentResult $f
        $r.status | Should -BeExactly 'Failed'
        @($r.deniedFindings.category) | Should -Contain 'UnsupportedContent'
    }

    It 'rejects real <Kind> without reading its cross-root target' -ForEach @(
        @{ Kind = 'Junction' }, @{ Kind = 'HardLink' }, @{ Kind = 'SymbolicLink' }
    ) {
        $f = New-IndependentFixture
        $outside = Join-Path $f.Root 'outside'
        [void][IO.Directory]::CreateDirectory($outside)
        $sentinel = Join-Path $outside 'sentinel.txt'
        [IO.File]::WriteAllText($sentinel, 'synthetic outside')
        $target = Join-Path $f.Destination 'linked'
        try {
            $linkTarget = if ($Kind -ceq 'Junction') { $outside } else { $sentinel }
            New-Item -ItemType $Kind -Path $target -Target $linkTarget -ErrorAction Stop | Out-Null
        }
        catch {
            if ($Kind -ceq 'SymbolicLink' -and ($_.FullyQualifiedErrorId -split ',')[0] -ceq 'NewItemSymbolicLinkElevationRequired' -and
                $_.Exception.InnerException.NativeErrorCode -eq 1314) {
                Set-ItResult -Skipped -Because 'Windows denied symbolic-link creation with exact privilege code 1314.'
                return
            }
            throw
        }
        $r = Get-IndependentResult $f
        $r.status | Should -BeExactly 'Failed'
        @($r.deniedFindings.category) | Should -Contain 'LinkedObject'
        [IO.File]::ReadAllText($sentinel) | Should -BeExactly 'synthetic outside'
    }

    It 'rejects alternate data streams on retained files' {
        $f = New-IndependentFixture
        Set-Content -LiteralPath (Join-Path $f.Destination 'README.md') -Stream 'synthetic' -Value 'not in Git'
        $r = Get-IndependentResult $f
        $r.status | Should -BeExactly 'Failed'
        @($r.deniedFindings.category) | Should -Contain 'AlternateStream'
    }

    It 'requires caller identity instead of blessing the currently observed remotes' {
        $f = New-IndependentFixture
        $f.Parameters.RepositoryIdentity = 'a' * 64
        $r = Get-IndependentResult $f
        $r.status | Should -BeExactly 'Failed'
        $r.sourceUnchanged | Should -BeFalse
        @($r.deniedFindings.category) | Should -Contain 'SourceVerificationUnavailable'
    }

    It 'cannot substitute injected blobs for actual committed source proof' {
        $f = New-IndependentFixture
        $f.Parameters.GitBlobReader = { [Text.Encoding]::UTF8.GetBytes('fabricated proof') }
        $r = Get-IndependentResult $f
        $r.status | Should -BeExactly 'Failed'
        $r.sourceUnchanged | Should -BeFalse
    }

    It 'does not turn an unavailable final source snapshot into a source-unchanged claim' {
        $f = New-IndependentFixture
        $native = & (Get-Module Caldova.HrFrontier.Bootstrap) { New-DefaultNativeCommandRunner }
        $counter = @{ value = 0 }
        $f.Parameters.NativeCommandRunner = {
            param($file, $arguments)
            if ($arguments -contains 'status') {
                $counter.value++
                if ($counter.value -gt 2) { throw 'Synthetic unavailable final source snapshot.' }
            }
            & $native $file $arguments
        }.GetNewClosure()
        $r = Get-IndependentResult $f
        $r.status | Should -BeExactly 'Failed'
        $r.sourceUnchanged | Should -BeFalse
        $r.provenance.sourceVerification | Should -BeExactly 'Unavailable'
    }

    It 'detects a clean source remotes drift in the post-suite snapshot' {
        $f = New-IndependentFixture
        $source = $f.Source; $git = $script:Git
        $f.Parameters.ValidationRunner = {
            param($id)
            if ($id -ceq 'Pester') {
                & $git -C $source remote add synthetic 'https://example.invalid/changed'
                if ($LASTEXITCODE -ne 0) { throw 'Synthetic remote drift setup failed.' }
            }
            [pscustomobject]@{ suite = $id; exitCode = 0 }
        }.GetNewClosure()
        $r = Get-IndependentResult $f
        $r.status | Should -BeExactly 'Failed'
        $r.sourceUnchanged | Should -BeFalse
        $r.provenance.sourceVerification | Should -BeExactly 'Mismatch'
    }

    It 'checks source and tree after a runner <Case>' -ForEach @(
        @{ Case = 'changes candidate' }, @{ Case = 'changes source' }, @{ Case = 'throws after tamper' }, @{ Case = 'fails' }
    ) {
        $f = New-IndependentFixture
        $destination = $f.Destination; $source = $f.Source; $caseName = $Case
        $f.Parameters.ValidationRunner = {
            param($id)
            if ($id -ceq 'Pester') {
                switch ($caseName) {
                    'changes candidate' { [IO.File]::WriteAllText((Join-Path $destination 'README.md'), 'tampered') }
                    'changes source' { [IO.File]::WriteAllText((Join-Path $source 'README.md'), 'tampered') }
                    'throws after tamper' { [IO.File]::WriteAllText((Join-Path $destination 'README.md'), 'tampered'); throw 'synthetic private diagnostic' }
                }
            }
            [pscustomobject]@{ suite = $id; exitCode = $(if ($caseName -ceq 'fails') { 1 } else { 0 }) }
        }.GetNewClosure()
        $r = Get-IndependentResult $f
        $r.status | Should -BeExactly 'Failed'
        if ($Case -ceq 'changes source') { $r.sourceUnchanged | Should -BeFalse }
        elseif ($Case -cne 'fails') { @($r.mismatchedPaths) | Should -Contain 'README.md' }
        ($r | ConvertTo-Json -Depth 30) | Should -Not -Match 'synthetic private diagnostic'
    }

    It 'reports absent Plan4 pipeline assets as a prerequisite, not a passed replica' {
        $f = New-IndependentFixture TenantReplica
        foreach ($root in @($f.Source, $f.Destination)) {
            Remove-Item (Join-Path $root 'azure-pipelines.yml')
            Remove-Item (Join-Path $root 'infra\src\pipelines') -Recurse
        }
        & $script:Git -C $f.Source add -A
        if ($LASTEXITCODE -ne 0) { throw 'Synthetic staging failed.' }
        & $script:Git -C $f.Source commit --quiet -m 'Synthetic Plan4 prerequisite'
        if ($LASTEXITCODE -ne 0) { throw 'Synthetic commit failed.' }
        $f.Parameters.ExpectedSourceCommit = (& $script:Git -C $f.Source rev-parse HEAD).Trim()
        if ($LASTEXITCODE -ne 0) { throw 'Synthetic commit read failed.' }
        $f.Manifest.fileClassifications = @($f.Manifest.fileClassifications | Where-Object { $_.path -cne 'azure-pipelines.yml' -and -not $_.path.StartsWith('infra/src/pipelines/') })
        $r = Get-IndependentResult $f
        $r.status | Should -BeExactly 'PendingPrerequisite'
        @($r.suiteResults.category) | Should -Contain 'PipelineAssetsMissing'
    }
}

Describe 'Production offline dispatch and script boundary' {
    It 'rejects independent authority intent rather than silently ignoring <Authority>' -ForEach @(
        @{ Authority = 'WhatIf' }, @{ Authority = 'Confirm' }
    ) {
        $f = New-IndependentFixture
        $intent = Join-Path $f.Root 'intent.json'
        Write-CanonicalJson $f.Manifest -Path $intent | Out-Null
        $p = @{
            Operation = 'Assess'; Independent = $true; RunId = [guid]'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee'
            EvidenceRoot = (Join-Path $f.Root 'proof'); SourceRoot = $f.Source; DestinationRoot = $f.Destination
            ExpectedSourceCommit = $f.Parameters.ExpectedSourceCommit; ManifestPath = $intent
            Profile = 'CustomerHandover'; RepositoryIdentity = $f.Parameters.RepositoryIdentity
            NativeCommandRunner = { throw 'Authority must be checked before source enumeration.' }
        }
        $p[$Authority] = $false
        { Invoke-RepositoryExportOperation @p } | Should -Throw '*Independent*'
        Test-Path $p.EvidenceRoot | Should -BeFalse
    }

    It 'actually executes Pester with failure propagation and no result files: <Case>' -ForEach @(
        @{ Case = 'passing'; Exit = 0 }
        @{ Case = 'failed test'; Exit = 1 }
        @{ Case = 'failed container'; Exit = 1 }
        @{ Case = 'zero tests'; Exit = 1 }
    ) {
        $f = New-IndependentFixture
        $test = Join-Path $f.Destination 'infra\tests\pester\RunbookContracts.Tests.ps1'
        switch ($Case) {
            'failed test' { [IO.File]::WriteAllText($test, "Describe 'synthetic' { It 'fails' { 1 | Should -Be 2 } }") }
            'failed container' { [IO.File]::WriteAllText($test, "BeforeAll { throw 'synthetic container' }; Describe 'synthetic' { It 'never passes' { 1 | Should -Be 1 } }") }
            'zero tests' { [IO.File]::WriteAllText($test, '# no tests') }
        }
        $r = & (Get-Module Caldova.HrFrontier.Bootstrap) {
            param($tree, $ps)
            $tools = [pscustomobject]@{ WindowsPowerShell = [pscustomobject]@{ path = $ps } }
            $command = Get-RepositoryExportValidationCommand -Suite Pester -ToolIdentities $tools -Root $tree -Profile CustomerHandover
            $runner = New-DefaultValidationRunner -Runner (New-DefaultNativeCommandRunner)
            & $runner Pester $command.filePath $command.arguments $tree
        } $f.Destination $script:WindowsPS
        $r.exitCode | Should -Be $Exit
        @(Get-ChildItem $f.Destination -Recurse -File | Where-Object { $_.Name -match 'testResults|coverage|nunit' }).Count | Should -Be 0
        Test-Path (Join-Path $f.Destination '.git') | Should -BeFalse
    }

    It 'runs real history-free safety rules and fails unsafe commands without creating Git metadata' {
        $f = New-IndependentFixture TenantReplica
        $safety = Join-Path $script:Repository '.github\cli\verify-repository-safety.ps1'
        & $script:WindowsPS -NoProfile -File $safety -RepositoryRoot $f.Destination -HistoryFree *> $null
        $LASTEXITCODE | Should -Be 0
        $negativeFixture = Join-Path $f.Destination 'infra\tests\fixtures\evidence\synthetic.json'
        [void][IO.Directory]::CreateDirectory((Split-Path $negativeFixture -Parent))
        [IO.File]::WriteAllText($negativeFixture, '{"id":"synthetic-example"}')
        & $script:WindowsPS -NoProfile -File $safety -RepositoryRoot $f.Destination -HistoryFree *> $null
        $LASTEXITCODE | Should -Be 0
        [void][IO.Directory]::CreateDirectory((Join-Path $f.Destination 'infra\src\scripts'))
        [IO.File]::WriteAllText((Join-Path $f.Destination 'infra\src\scripts\unsafe.ps1'), ('Set-ExecutionPolicy ' + 'Bypass'))
        & $script:WindowsPS -NoProfile -File $safety -RepositoryRoot $f.Destination -HistoryFree *> $null
        $LASTEXITCODE | Should -Be 1
        Test-Path (Join-Path $f.Destination '.git') | Should -BeFalse
    }

    It 'uses real default tools, runs mandatory suites, and explicitly blocks a missing standalone compiler' {
        $f = New-IndependentFixture TenantReplica
        [void]$f.Parameters.Remove('ToolIdentities')
        [void]$f.Parameters.Remove('ValidationRunner')
        $r = Get-IndependentResult $f
        ($r.suiteResults | Where-Object suite -CEQ 'Pester').status | Should -BeExactly 'Passed'
        ($r.suiteResults | Where-Object suite -CEQ 'RepositorySafety').status | Should -BeExactly 'Passed'
        $bicep = $r.suiteResults | Where-Object suite -CEQ 'BicepBuild'
        Write-Host ('DEFAULT OFFLINE: ' + (($r.suiteResults | ForEach-Object { $_.suite + '=' + $_.status + '/' + $_.category }) -join '; '))
        if ($r.provenance.toolIdentities.PSObject.Properties.Name -contains 'Bicep') {
            Write-Host ('ACTUAL STANDALONE BICEP: ' + $r.provenance.toolIdentities.Bicep.version + '; SHA256=' + $r.provenance.toolIdentities.Bicep.sha256)
        }
        if ($bicep.category -ceq 'ToolUnavailable') {
            $r.status | Should -BeExactly 'Blocked'
            $bicep.status | Should -BeExactly 'Blocked'
        }
        else {
            $bicep.status | Should -BeExactly 'Passed'
            $r.status | Should -BeExactly 'Passed'
        }
        Test-Path (Join-Path $f.Destination 'infra\src\bicep\main.json') | Should -BeFalse
        Test-Path (Join-Path $f.Destination '.git') | Should -BeFalse
    }

    It 'blocks only the missing compiler while running actual local Pester and safety, without a runner override' {
        $f = New-IndependentFixture TenantReplica
        [void]$f.Parameters.Remove('ToolIdentities')
        [void]$f.Parameters.Remove('ValidationRunner')
        $git = $script:Git; $ps = $script:WindowsPS
        $f.Parameters.CommandResolver = {
            param($name)
            switch -CaseSensitive ($name) {
                'git.exe' { $git }
                'powershell.exe' { $ps }
                'bicep.exe' { @() }
                default { throw 'Provider executable resolution is forbidden.' }
            }
        }.GetNewClosure()
        $r = Get-IndependentResult $f
        $r.status | Should -BeExactly 'Blocked'
        ($r.suiteResults | Where-Object suite -CEQ 'Pester').status | Should -BeExactly 'Passed'
        ($r.suiteResults | Where-Object suite -CEQ 'RepositorySafety').status | Should -BeExactly 'Passed'
        ($r.suiteResults | Where-Object suite -CEQ 'BicepBuild').category | Should -BeExactly 'ToolUnavailable'
        $r.sourceUnchanged | Should -BeTrue
    }

    It 'keeps explicit customer test omissions separate from mandatory suite acceptance' {
        $f = New-IndependentFixture
        $f.Manifest.deniedPaths = @('infra/tests', 'hr/tests', '.github/cli/tests')
        $f.Manifest.fileClassifications = @($f.Manifest.fileClassifications | Where-Object { $_.path -cnotmatch '^(infra/tests|hr/tests|\.github/cli/tests)/' })
        Remove-Item (Join-Path $f.Destination 'infra\tests'), (Join-Path $f.Destination 'hr'), (Join-Path $f.Destination '.github\cli\tests') -Recurse
        $r = Get-IndependentResult $f
        $r.status | Should -BeExactly 'Blocked'
        @($r.unexpectedPaths).Count | Should -Be 0
        @($r.missingPaths).Count | Should -Be 0
        ($r.suiteResults | Where-Object suite -CEQ 'Pester').category | Should -BeExactly 'SuiteAssetsMissing'
        Test-Path (Join-Path $f.Destination '.github\workflows') | Should -BeFalse
    }

    It 'validates an existing input through the actual CLI and writes only separate immutable allowlisted evidence' {
        $f = New-IndependentFixture TenantReplica
        $intent = Join-Path $f.Root 'intent.json'
        Write-CanonicalJson $f.Manifest -Path $intent | Out-Null
        $p = @{
            RunId = [guid]'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee'; EvidenceRoot = (Join-Path $f.Root 'proof')
            SourceRoot = $f.Source; ExpectedSourceCommit = $f.Parameters.ExpectedSourceCommit
            DestinationRoot = $f.Destination; ManifestPath = $intent
            Profile = 'TenantReplica'; RepositoryIdentity = $f.Parameters.RepositoryIdentity
        }
        $cli = Join-Path $script:Repository 'infra\src\scripts\runbooks\Test-RepositoryExport.ps1'
        $r = & $cli @p -Independent
        $r.status | Should -BeIn @('Passed', 'Blocked')
        $proof = @(Get-ChildItem $p.EvidenceRoot -Recurse -File)
        $proof.Count | Should -Be 2
        $json = ($proof | ForEach-Object { [IO.File]::ReadAllText($_.FullName) }) -join "`n"
        $json | Should -Not -Match 'Source Lab|source-lab|README.md|[A-Za-z]:\\|PassedStageResult|intentDigest|stateDigest'
        { & $cli @p -Independent } | Should -Throw '*already exists*'
        { Invoke-RepositoryExportOperation -Operation Invoke @p -Independent -Apply -Confirm:$false } | Should -Throw '*Independent*'
        { Invoke-RepositoryExportOperation -Operation Assess @p -Independent -ApprovedDigest ('a' * 64) } | Should -Throw '*Independent*'
        Test-Path (Join-Path $p.EvidenceRoot ($p.RunId.ToString() + '\stage-results\TenantReplica.json')) | Should -BeFalse
    }
}
