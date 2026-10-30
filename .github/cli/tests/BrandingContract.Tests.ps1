Set-StrictMode -Version Latest

BeforeAll {
    $script:repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
    $script:modulePath = Join-Path $script:repositoryRoot '.github\cli\modules\BrandingContract.psm1'
    Import-Module $script:modulePath -Force
    $script:gitPath = @(
        (Get-Command git.exe -CommandType Application -ErrorAction SilentlyContinue |
            Select-Object -First 1).Source
        'C:\Program Files\Git\cmd\git.exe'
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) } |
        Select-Object -First 1
    if (-not $script:gitPath) { throw 'git.exe is required.' }

    $first = -join [char[]](71, 101, 111, 114, 103)
    $second = -join [char[]](70, 105, 115, 99, 104, 101, 114)
    $initials = $first[0] + $second[0]
    $script:forms = [ordered]@{
        L1 = $first + ' ' + $second
        L2 = $first + $second
        L3 = $initials
        L4 = $initials.ToLowerInvariant() + '-'
        L5 = $initials.ToLowerInvariant() + '_'
        L6 = $initials.ToLowerInvariant() + 'Brand'
        L7 = $initials[0] + $initials[1].ToString().ToLowerInvariant() + 'Brand'
    }

    function script:New-BrandingFixture {
        $root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        [void](New-Item -ItemType Directory -Path $root)
        & $script:gitPath -C $root init --quiet
        if ($LASTEXITCODE -ne 0) { throw 'Cannot initialize fixture repository.' }
        $root
    }

    function script:Add-FixtureText {
        param(
            [Parameter(Mandatory)][string]$Root,
            [Parameter(Mandatory)][string]$RelativePath,
            [Parameter(Mandatory)][AllowEmptyString()][string]$Content
        )
        $path = Join-Path $Root $RelativePath
        [void](New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force)
        [IO.File]::WriteAllText($path, $Content, [Text.UTF8Encoding]::new($false))
        & $script:gitPath -c core.safecrlf=false -C $Root add -- $RelativePath.Replace('\', '/')
        if ($LASTEXITCODE -ne 0) { throw "Cannot stage fixture: $RelativePath" }
    }

    function script:Add-FixtureIndexLink {
        param(
            [Parameter(Mandatory)][string]$Root,
            [Parameter(Mandatory)][string]$RelativePath
        )
        $blobPath = Join-Path $Root ([guid]::NewGuid().ToString('N'))
        [IO.File]::WriteAllText(
            $blobPath,
            'target',
            [Text.UTF8Encoding]::new($false)
        )
        $objectId = (& $script:gitPath -C $Root hash-object -w -- $blobPath).Trim()
        Remove-Item -LiteralPath $blobPath -Force
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrEmpty($objectId)) {
            throw 'Cannot create fixture link object.'
        }
        & $script:gitPath -C $Root update-index --add --cacheinfo `
            '120000' $objectId $RelativePath.Replace('\', '/')
        if ($LASTEXITCODE -ne 0) { throw "Cannot stage fixture link: $RelativePath" }
    }

    function script:Get-FixtureSha256 {
        param(
            [Parameter(Mandatory)][string]$Root,
            [Parameter(Mandatory)][string]$RelativePath
        )

        (Get-FileHash -LiteralPath (Join-Path $Root $RelativePath) -Algorithm SHA256).
            Hash.ToLowerInvariant()
    }

    function script:Add-FixtureEvidenceManifest {
        param(
            [Parameter(Mandatory)][string]$Root,
            [Parameter(Mandatory)][object[]]$Exceptions,
            [hashtable]$ExtraRootProperty
        )

        $manifest = [ordered]@{
            schemaVersion = '1.0'
            exceptions = @($Exceptions)
        }
        if ($ExtraRootProperty) {
            foreach ($entry in $ExtraRootProperty.GetEnumerator()) {
                $manifest[$entry.Key] = $entry.Value
            }
        }
        Add-FixtureText -Root $Root `
            -RelativePath '.github\cli\config\branding-evidence-exceptions.json' `
            -Content ($manifest | ConvertTo-Json -Depth 6)
    }

    function script:New-FixtureEvidenceException {
        param(
            [Parameter(Mandatory)][string]$Root,
            [Parameter(Mandatory)][string]$RelativePath,
            [Parameter(Mandatory)][string]$PatternClass,
            [int]$Count = 1,
            [string]$Sha256
        )

        if (-not $Sha256) {
            $Sha256 = Get-FixtureSha256 -Root $Root -RelativePath $RelativePath
        }
        [ordered]@{
            path = $RelativePath.Replace('\', '/')
            sha256 = $Sha256
            patternClass = $PatternClass
            count = $Count
            provenance = 'Captured by the governed model evaluation workflow.'
            rationale = 'Immutable source evidence is retained byte-for-byte.'
        }
    }

    function script:New-FixtureSourceRecord {
        param([string]$Root)
        $relative = 'sources/' + $script:forms.L4 + 'sample.txt'
        Add-FixtureText -Root $Root -RelativePath $relative -Content $script:forms.L3
        [ordered]@{
            path = $relative
            sha256 = Get-FixtureSha256 -Root $Root -RelativePath $relative
            hashBasis = 'raw'
            provenance = 'identity-intake-v1'
            pathMatches = @(
                [ordered]@{patternClass = 'L3'; count = 1}
                [ordered]@{patternClass = 'L4'; count = 1}
            )
            contentMatches = @([ordered]@{patternClass = 'L3'; count = 1})
        }
    }

    function script:Add-FixtureSourceManifest {
        param(
            [string]$Root,
            [object[]]$Sources,
            [string]$Status = 'Approved',
            [hashtable]$ExtraProperty
        )
        $manifest = [ordered]@{
            schemaVersion = '1.0'
            approvalReference = 'retained-source-2026-10-30'
            policyReference = 'docs/specs/2026-10-01-caldova-branding-migration-design.md'
            sources = @($Sources)
        }
        if ($ExtraProperty) {
            foreach ($entry in $ExtraProperty.GetEnumerator()) { $manifest[$entry.Key] = $entry.Value }
        }
        $relative = '.github/cli/config/branding-source-classifications.json'
        Add-FixtureText -Root $Root -RelativePath $relative `
            -Content (($manifest | ConvertTo-Json -Depth 10).Replace("`r`n", "`n") + "`n")
        $hash = Get-FixtureSha256 -Root $Root -RelativePath $relative
        Add-FixtureText -Root $Root -RelativePath $manifest.policyReference -Content @"
# Source classification authority
| Field | Value |
|---|---|
| **Status** | $Status |
Source classification approval: retained-source-2026-10-30
Source classification SHA-256 (UTF-8 LF): $hash
"@
    }
}

Describe 'Branding scanner behavior' -Tag 'BrandingContractUnit' {
    It 'finds every prohibited class in tracked paths and tracked text without returning matched content' {
        $root = New-BrandingFixture
        foreach ($entry in $script:forms.GetEnumerator()) {
            Add-FixtureText -Root $root `
                -RelativePath ("paths\{0}\{1}\safe.txt" -f
                    $entry.Key, $entry.Value) `
                -Content 'safe'
            Add-FixtureText -Root $root `
                -RelativePath ("text\{0}.txt" -f $entry.Key) `
                -Content ("before {0} after" -f $entry.Value)
        }
        [IO.File]::WriteAllText(
            (Join-Path $root 'untracked.txt'),
            $script:forms.L1,
            [Text.UTF8Encoding]::new($false)
        )

        $result = Get-RepositoryBrandingScan -RepositoryRoot $root

        foreach ($label in $script:forms.Keys) {
            @($result.Findings | Where-Object PatternClass -ceq $label).Count |
                Should -BeGreaterOrEqual 2
        }
        foreach ($finding in $result.Findings) {
            $finding.PSObject.Properties.Name |
                Should -Be @('Path', 'PatternClass')
        }
        $result.Findings.Path | Should -Not -Contain 'untracked.txt'
    }

    It 'scans text by bytes and strict UTF-8 rather than by an extension allowlist' {
        $root = New-BrandingFixture
        foreach ($extension in @('.md', '.ps1', '.ts', '.xyz')) {
            Add-FixtureText -Root $root `
                -RelativePath ("content\sample{0}" -f $extension) `
                -Content $script:forms.L1
        }

        $result = Get-RepositoryBrandingScan -RepositoryRoot $root

        @($result.Findings | Where-Object PatternClass -ceq 'L1').Count | Should -Be 4
        @($result.Files | Where-Object Classification -ceq 'tracked-text').Count |
            Should -Be 4
    }

    It 'classifies an empty tracked file as text' {
        $root = New-BrandingFixture
        Add-FixtureText -Root $root -RelativePath 'empty.txt' -Content ''

        $result = Get-RepositoryBrandingScan -RepositoryRoot $root

        $result.TextCount | Should -Be 1
        @($result.Files | Where-Object Path -ceq 'empty.txt').Classification |
            Should -BeExactly 'tracked-text'
        $result.Findings | Should -BeNullOrEmpty
    }

    It 'classifies a signature-proven binary explicitly and does not decode it as text' {
        $root = New-BrandingFixture
        $path = Join-Path $root 'image.bin'
        [IO.File]::WriteAllBytes(
            $path,
            [byte[]](137, 80, 78, 71, 13, 10, 26, 10, 0, 255, 1, 2)
        )
        & $script:gitPath -C $root add -- 'image.bin'

        $result = Get-RepositoryBrandingScan -RepositoryRoot $root

        $result.BinaryCount | Should -Be 1
        @($result.Files | Where-Object Path -ceq 'image.bin').Classification |
            Should -BeExactly 'tracked-binary'
        $result.Findings | Should -BeNullOrEmpty
    }

    It 'fails closed on undecodable unclassified bytes and a missing tracked file' {
        $root = New-BrandingFixture
        $bad = Join-Path $root 'bad-text.dat'
        [IO.File]::WriteAllBytes($bad, [byte[]](195, 40))
        & $script:gitPath -C $root add -- 'bad-text.dat'
        Add-FixtureText -Root $root -RelativePath 'missing.txt' -Content 'safe'
        Remove-Item -LiteralPath (Join-Path $root 'missing.txt') -Force

        $result = Get-RepositoryBrandingScan -RepositoryRoot $root

        $result.Findings |
            Where-Object { $_.Path -ceq 'bad-text.dat' } |
            Select-Object -ExpandProperty PatternClass |
            Should -Contain 'classification-error'
        $result.Findings |
            Where-Object { $_.Path -ceq 'missing.txt' } |
            Select-Object -ExpandProperty PatternClass |
            Should -Contain 'read-error'
    }

    It 'fails closed when Git enumeration cannot run' {
        $notARepository = Join-Path $TestDrive 'not-a-repository'
        [void](New-Item -ItemType Directory -Path $notARepository)

        { Get-RepositoryBrandingScan -RepositoryRoot $notARepository } |
            Should -Throw '*git-error*'
    }

    It 'blocks an index-mode link through the scanner without reading its worktree path' {
        $root = New-BrandingFixture
        Add-FixtureIndexLink -Root $root -RelativePath 'link'
        [IO.File]::WriteAllBytes(
            (Join-Path $root 'link'),
            [byte[]](195, 40)
        )

        $result = Get-RepositoryBrandingScan -RepositoryRoot $root

        $result.LinkCount | Should -Be 1
        @($result.Files | Where-Object Path -ceq 'link').Classification |
            Should -BeExactly 'tracked-link'
        @($result.Findings | Where-Object Path -ceq 'link').PatternClass |
            Should -BeExactly 'tracked-link'
    }

    It 'detects an injected reparse point on the tracked file component' {
        $root = New-BrandingFixture
        Add-FixtureText -Root $root -RelativePath 'link.txt' -Content 'safe'
        $link = Join-Path $root 'link.txt'

        InModuleScope BrandingContract -Parameters @{ Root = $root; Link = $link } {
            param($Root, $Link)
            $script:inspectedPaths = [Collections.Generic.List[string]]::new()
            Mock Get-Item {
                param($LiteralPath)
                [void]$script:inspectedPaths.Add($LiteralPath)
                [pscustomobject]@{
                    Attributes = if ($LiteralPath -ceq $Link) {
                        [IO.FileAttributes]::ReparsePoint
                    }
                    else {
                        [IO.FileAttributes]::Directory
                    }
                }
            }

            Test-BrandingReparsePointInPath `
                -Path $Link `
                -RepositoryRoot $Root |
                Should -BeTrue
            @($script:inspectedPaths) | Should -Be @($Root, $Link)
        }
    }

    It 'inspects components from the repository root toward the tracked file' {
        $root = New-BrandingFixture
        Add-FixtureText -Root $root -RelativePath 'nested\safe.txt' -Content 'safe'
        $file = Join-Path $root 'nested\safe.txt'
        $expected = @($root, (Join-Path $root 'nested'), $file)

        InModuleScope BrandingContract -Parameters @{
            Root = $root
            File = $file
            Expected = $expected
        } {
            param($Root, $File, $Expected)
            $script:inspectedPaths = [Collections.Generic.List[string]]::new()
            Mock Get-Item {
                param($LiteralPath)
                [void]$script:inspectedPaths.Add($LiteralPath)
                [pscustomobject]@{
                    Attributes = [IO.FileAttributes]::Normal
                }
            }

            Test-BrandingReparsePointInPath `
                -Path $File `
                -RepositoryRoot $Root |
                Should -BeFalse
            @($script:inspectedPaths) | Should -Be $Expected
        }
    }

    It 'blocks a regular tracked file below an ancestor directory reparse point' {
        $root = New-BrandingFixture
        Add-FixtureText -Root $root -RelativePath 'linked\safe.txt' -Content 'safe'
        $target = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        [void](New-Item -ItemType Directory -Path $target)
        [IO.File]::WriteAllBytes(
            (Join-Path $target 'safe.txt'),
            [byte[]](195, 40)
        )
        $junction = Join-Path $root 'linked'
        Remove-Item -LiteralPath $junction -Recurse -Force
        [void](New-Item -ItemType Junction -Path $junction -Target $target -ErrorAction Stop)
        if (-not ((Get-Item -LiteralPath $junction -Force).Attributes -band
            [IO.FileAttributes]::ReparsePoint)) {
            throw 'The fixture directory link is not a reparse point.'
        }

        $result = Get-RepositoryBrandingScan -RepositoryRoot $root

        $result.LinkCount | Should -Be 1
        @($result.Files | Where-Object Path -ceq 'linked/safe.txt').Classification |
            Should -BeExactly 'tracked-link'
        @($result.Findings | Where-Object Path -ceq 'linked/safe.txt').PatternClass |
            Should -BeExactly 'tracked-link'
    }

    It 'suppresses one exact hash-bound immutable evidence occurrence without disclosing matched content' -TestCases @(
        @{ PatternClass = 'L1' }
        @{ PatternClass = 'L2' }
        @{ PatternClass = 'L3' }
        @{ PatternClass = 'L4' }
        @{ PatternClass = 'L5' }
        @{ PatternClass = 'L6' }
        @{ PatternClass = 'L7' }
    ) {
        param($PatternClass)

        $root = New-BrandingFixture
        $evidencePath = 'hr\evidence\ai-builder\tenant-test\DEV\run-test\evidence.json'
        Add-FixtureText -Root $root -RelativePath $evidencePath `
            -Content ("captured {0} value" -f $script:forms[$PatternClass])
        $exception = New-FixtureEvidenceException -Root $root `
            -RelativePath $evidencePath -PatternClass $PatternClass
        Add-FixtureEvidenceManifest -Root $root -Exceptions @($exception)

        $result = Get-RepositoryBrandingScan -RepositoryRoot $root

        $result.Findings | Should -BeNullOrEmpty
        $result.ApprovedEvidenceCount | Should -Be 1
        $result.ApprovedEvidence[0].PSObject.Properties.Name |
            Should -Be @('Path', 'PatternClass', 'Sha256')
        $result.ApprovedEvidence.Path |
            Should -BeExactly $evidencePath.Replace('\', '/')
        $result.ApprovedEvidence.PatternClass | Should -BeExactly $PatternClass
        $result.ApprovedEvidence.Sha256 | Should -BeExactly $exception.sha256
        ($result | ConvertTo-Json -Depth 5) | Should -Not -Match `
            [regex]::Escape($script:forms[$PatternClass])
    }

    It 'rejects a manifest count that is not the JSON integer one' -TestCases @(
        @{ CountJson = '1.0' }
        @{ CountJson = '1e0' }
        @{ CountJson = '"1"' }
        @{ CountJson = 'true' }
        @{ CountJson = 'null' }
        @{ CountJson = '0' }
        @{ CountJson = '-1' }
        @{ CountJson = '2' }
        @{ CountJson = '4294967297' }
    ) {
        param($CountJson)

        $root = New-BrandingFixture
        $evidencePath = 'hr\evidence\ai-builder\tenant-test\DEV\run-test\evidence.json'
        Add-FixtureText -Root $root -RelativePath $evidencePath `
            -Content ("captured {0} value" -f $script:forms.L3)
        $exception = New-FixtureEvidenceException -Root $root `
            -RelativePath $evidencePath -PatternClass 'L3'
        $manifestJson = [ordered]@{
            schemaVersion = '1.0'
            exceptions = @($exception)
        } | ConvertTo-Json -Depth 6
        $manifestJson = $manifestJson -replace '"count":\s*1', (
            '"count": ' + $CountJson
        )
        Add-FixtureText -Root $root `
            -RelativePath '.github\cli\config\branding-evidence-exceptions.json' `
            -Content $manifestJson

        $result = Get-RepositoryBrandingScan -RepositoryRoot $root

        $result.ApprovedEvidenceCount | Should -Be 0
        $result.Findings.PatternClass | Should -Contain 'evidence-exception-error'
        @($result.Findings | Where-Object PatternClass -ceq 'L3').Count |
            Should -Be 1
    }

    It 'rejects a content exception when its tracked path has the same prohibited class' {
        $root = New-BrandingFixture
        $evidencePath = 'hr\evidence\ai-builder\tenant-test\DEV\run-test\{0}.json' -f
            $script:forms.L3
        Add-FixtureText -Root $root -RelativePath $evidencePath `
            -Content ("captured {0} value" -f $script:forms.L3)
        $exception = New-FixtureEvidenceException -Root $root `
            -RelativePath $evidencePath -PatternClass 'L3'
        Add-FixtureEvidenceManifest -Root $root -Exceptions @($exception)

        $result = Get-RepositoryBrandingScan -RepositoryRoot $root

        $result.ApprovedEvidenceCount | Should -Be 0
        $result.Findings.PatternClass | Should -Contain 'evidence-exception-error'
        @($result.Findings | Where-Object {
            $_.Path -ceq $evidencePath.Replace('\', '/') -and
            $_.PatternClass -ceq 'L3'
        }).Count | Should -Be 1
        ($result | ConvertTo-Json -Depth 5) | Should -Not -Match `
            [regex]::Escape("captured $($script:forms.L3) value")
    }

    It 'fails closed when immutable evidence bytes drift from the declared hash' {
        $root = New-BrandingFixture
        $evidencePath = 'hr\evidence\ai-builder\tenant-test\DEV\run-test\evidence.json'
        Add-FixtureText -Root $root -RelativePath $evidencePath `
            -Content ("captured {0} value" -f $script:forms.L3)
        $exception = New-FixtureEvidenceException -Root $root `
            -RelativePath $evidencePath -PatternClass 'L3'
        Add-FixtureEvidenceManifest -Root $root -Exceptions @($exception)
        [IO.File]::AppendAllText(
            (Join-Path $root $evidencePath),
            "`nbyte drift",
            [Text.UTF8Encoding]::new($false)
        )

        $result = Get-RepositoryBrandingScan -RepositoryRoot $root

        $result.ApprovedEvidenceCount | Should -Be 0
        $result.Findings.PatternClass | Should -Contain 'evidence-exception-error'
        @($result.Findings | Where-Object PatternClass -ceq 'L3').Count |
            Should -Be 1
    }

    It 'fails closed for a wrong declared class or count' -TestCases @(
        @{ PatternClass = 'L4'; Count = 1 }
        @{ PatternClass = 'L3'; Count = 2 }
    ) {
        param($PatternClass, $Count)

        $root = New-BrandingFixture
        $evidencePath = 'hr\evidence\ai-builder\tenant-test\DEV\run-test\evidence.json'
        Add-FixtureText -Root $root -RelativePath $evidencePath `
            -Content ("captured {0} value" -f $script:forms.L3)
        $exception = New-FixtureEvidenceException -Root $root `
            -RelativePath $evidencePath -PatternClass $PatternClass -Count $Count
        Add-FixtureEvidenceManifest -Root $root -Exceptions @($exception)

        $result = Get-RepositoryBrandingScan -RepositoryRoot $root

        $result.ApprovedEvidenceCount | Should -Be 0
        $result.Findings.PatternClass | Should -Contain 'evidence-exception-error'
        @($result.Findings | Where-Object PatternClass -ceq 'L3').Count |
            Should -Be 1
    }

    It 'rejects duplicate exception records as one invalid manifest' {
        $root = New-BrandingFixture
        $evidencePath = 'hr\evidence\ai-builder\tenant-test\DEV\run-test\evidence.json'
        Add-FixtureText -Root $root -RelativePath $evidencePath `
            -Content ("captured {0} value" -f $script:forms.L3)
        $exception = New-FixtureEvidenceException -Root $root `
            -RelativePath $evidencePath -PatternClass 'L3'
        Add-FixtureEvidenceManifest -Root $root `
            -Exceptions @($exception, $exception)

        $result = Get-RepositoryBrandingScan -RepositoryRoot $root

        $result.ApprovedEvidenceCount | Should -Be 0
        $result.Findings.PatternClass | Should -Contain 'evidence-exception-error'
        @($result.Findings | Where-Object PatternClass -ceq 'L3').Count |
            Should -Be 1
    }

    It 'rejects an exception outside the governed evidence root' {
        $root = New-BrandingFixture
        $evidencePath = 'docs\evidence.json'
        Add-FixtureText -Root $root -RelativePath $evidencePath `
            -Content ("captured {0} value" -f $script:forms.L3)
        $exception = New-FixtureEvidenceException -Root $root `
            -RelativePath $evidencePath -PatternClass 'L3'
        Add-FixtureEvidenceManifest -Root $root -Exceptions @($exception)

        $result = Get-RepositoryBrandingScan -RepositoryRoot $root

        $result.ApprovedEvidenceCount | Should -Be 0
        $result.Findings.PatternClass | Should -Contain 'evidence-exception-error'
        @($result.Findings | Where-Object PatternClass -ceq 'L3').Count |
            Should -Be 1
    }

    It 'rejects an exception path that is not a regular tracked file' {
        $root = New-BrandingFixture
        $evidencePath = 'hr\evidence\ai-builder\tenant-test\DEV\run-test\evidence.json'
        $absolutePath = Join-Path $root $evidencePath
        [void](New-Item -ItemType Directory -Path (Split-Path -Parent $absolutePath) -Force)
        [IO.File]::WriteAllText(
            $absolutePath,
            ("captured {0} value" -f $script:forms.L3),
            [Text.UTF8Encoding]::new($false)
        )
        $exception = New-FixtureEvidenceException -Root $root `
            -RelativePath $evidencePath -PatternClass 'L3'
        Add-FixtureEvidenceManifest -Root $root -Exceptions @($exception)

        $result = Get-RepositoryBrandingScan -RepositoryRoot $root

        $result.ApprovedEvidenceCount | Should -Be 0
        $result.Findings.PatternClass | Should -Contain 'evidence-exception-error'
    }

    It 'leaves an unknown immutable-evidence occurrence as a normal blocking finding' {
        $root = New-BrandingFixture
        $approvedPath = 'hr\evidence\ai-builder\tenant-test\DEV\run-test\approved.json'
        $unknownPath = 'hr\evidence\ai-builder\tenant-test\DEV\run-test\unknown.json'
        Add-FixtureText -Root $root -RelativePath $approvedPath `
            -Content ("captured {0} value" -f $script:forms.L3)
        Add-FixtureText -Root $root -RelativePath $unknownPath `
            -Content ("captured {0} value" -f $script:forms.L3)
        $exception = New-FixtureEvidenceException -Root $root `
            -RelativePath $approvedPath -PatternClass 'L3'
        Add-FixtureEvidenceManifest -Root $root -Exceptions @($exception)

        $result = Get-RepositoryBrandingScan -RepositoryRoot $root

        $result.ApprovedEvidenceCount | Should -Be 1
        @($result.Findings | Where-Object {
            $_.Path -ceq $unknownPath.Replace('\', '/') -and
            $_.PatternClass -ceq 'L3'
        }).Count | Should -Be 1
    }

    It 'rejects extra manifest properties without exposing their values' {
        $root = New-BrandingFixture
        $evidencePath = 'hr\evidence\ai-builder\tenant-test\DEV\run-test\evidence.json'
        Add-FixtureText -Root $root -RelativePath $evidencePath `
            -Content ("captured {0} value" -f $script:forms.L3)
        $exception = New-FixtureEvidenceException -Root $root `
            -RelativePath $evidencePath -PatternClass 'L3'
        Add-FixtureEvidenceManifest -Root $root -Exceptions @($exception) `
            -ExtraRootProperty @{ unexpected = 'must-not-be-returned' }

        $result = Get-RepositoryBrandingScan -RepositoryRoot $root

        $result.ApprovedEvidenceCount | Should -Be 0
        $result.Findings.PatternClass | Should -Contain 'evidence-exception-error'
        ($result | ConvertTo-Json -Depth 5) | Should -Not -Match 'must-not-be-returned'
    }
}

Describe 'Reviewed source classifications' -Tag 'BrandingContractUnit' {
    It 'admits exact reviewed path and content matches without changing evidence approvals' {
        $root = New-BrandingFixture
        $source = New-FixtureSourceRecord -Root $root
        Add-FixtureSourceManifest -Root $root -Sources @($source)

        $result = Get-RepositoryBrandingScan -RepositoryRoot $root

        $result.Findings | Should -BeNullOrEmpty
        $result.ClassifiedSourceCount | Should -Be 1
        $result.ClassifiedSources[0].Path | Should -BeExactly $source.path
        $result.ApprovedEvidenceCount | Should -Be 0
    }

    It 'keeps undeclared files blocking even inside an admitted source folder' {
        $root = New-BrandingFixture
        $source = New-FixtureSourceRecord -Root $root
        $unknown = 'sources/' + $script:forms.L4 + 'unknown.txt'
        Add-FixtureText -Root $root -RelativePath $unknown -Content $script:forms.L3
        Add-FixtureSourceManifest -Root $root -Sources @($source)

        $result = Get-RepositoryBrandingScan -RepositoryRoot $root

        $result.ClassifiedSourceCount | Should -Be 1
        @($result.Findings | Where-Object Path -CEQ $unknown).Count | Should -BeGreaterThan 0
    }

    It 'rejects invalid source records atomically: <Fault>' -TestCases @(
        @{Fault = 'hash'}
        @{Fault = 'path-count'}
        @{Fault = 'content-count'}
        @{Fault = 'class'}
        @{Fault = 'provenance'}
        @{Fault = 'basis'}
        @{Fault = 'duplicate'}
        @{Fault = 'traversal'}
        @{Fault = 'coercible-count'}
        @{Fault = 'extra-record-field'}
    ) {
        param($Fault)
        $root = New-BrandingFixture
        $source = New-FixtureSourceRecord -Root $root
        $originalPath = $source.path
        switch ($Fault) {
            'hash' { $source.sha256 = '0' * 64 }
            'path-count' { $source.pathMatches[0].count = 2 }
            'content-count' { $source.contentMatches[0].count = 2 }
            'class' { $source.contentMatches[0].patternClass = 'L9' }
            'provenance' { $source.provenance = 'unreviewed' }
            'basis' { $source.hashBasis = 'ignore' }
            'traversal' { $source.path = '../outside.txt' }
            'coercible-count' { $source.contentMatches[0].count = '1' }
            'extra-record-field' { $source['unexpected'] = 'unapproved' }
        }
        $records = if ($Fault -eq 'duplicate') { @($source, $source) } else { @($source) }
        Add-FixtureSourceManifest -Root $root -Sources $records

        $result = Get-RepositoryBrandingScan -RepositoryRoot $root

        $result.Findings.PatternClass | Should -Contain 'source-classification-error'
        $result.ClassifiedSourceCount | Should -Be 0
        @($result.Findings | Where-Object Path -CEQ $originalPath).Count |
            Should -BeGreaterThan 0
    }

    It 'rejects changed source bytes even when no new class is introduced' {
        $root = New-BrandingFixture
        $source = New-FixtureSourceRecord -Root $root
        Add-FixtureSourceManifest -Root $root -Sources @($source)
        Add-FixtureText -Root $root -RelativePath $source.path -Content ($script:forms.L3 + ' changed')

        $result = Get-RepositoryBrandingScan -RepositoryRoot $root

        $result.Findings.PatternClass | Should -Contain 'source-classification-error'
        $result.ClassifiedSourceCount | Should -Be 0
    }

    It 'requires Approved authority rather than a Draft or missing authority' -TestCases @(
        @{Status = 'Draft'}
        @{Status = 'Proposed Baseline'}
    ) {
        param($Status)
        $root = New-BrandingFixture
        $source = New-FixtureSourceRecord -Root $root
        Add-FixtureSourceManifest -Root $root -Sources @($source) -Status $Status

        $result = Get-RepositoryBrandingScan -RepositoryRoot $root

        $result.Findings.PatternClass | Should -Contain 'source-classification-error'
        $result.ClassifiedSourceCount | Should -Be 0
    }

    It 'rejects manifest edits without updating the explicit approval hash' {
        $root = New-BrandingFixture
        $source = New-FixtureSourceRecord -Root $root
        Add-FixtureSourceManifest -Root $root -Sources @($source)
        Add-Content -LiteralPath (Join-Path $root '.github/cli/config/branding-source-classifications.json') -Value ' '

        $result = Get-RepositoryBrandingScan -RepositoryRoot $root

        $result.Findings.PatternClass | Should -Contain 'source-classification-error'
        $result.ClassifiedSourceCount | Should -Be 0
    }

    It 'rejects unknown manifest metadata even if the altered registry is hash-pinned' {
        $root = New-BrandingFixture
        $source = New-FixtureSourceRecord -Root $root
        Add-FixtureSourceManifest -Root $root -Sources @($source) `
            -ExtraProperty @{unexpected = $script:forms.L3}

        $result = Get-RepositoryBrandingScan -RepositoryRoot $root

        $result.Findings.PatternClass | Should -Contain 'source-classification-error'
        $result.ClassifiedSourceCount | Should -Be 0
    }

    It 'requires a string schema version rather than a coercible numeric value' {
        $root = New-BrandingFixture
        $source = New-FixtureSourceRecord -Root $root
        Add-FixtureSourceManifest -Root $root -Sources @($source) -ExtraProperty @{schemaVersion = 1}

        $result = Get-RepositoryBrandingScan -RepositoryRoot $root

        $result.Findings.PatternClass | Should -Contain 'source-classification-error'
        $result.ClassifiedSourceCount | Should -Be 0
    }

    It 'permits only declared LF and CRLF equivalence for maintained text' {
        $root = New-BrandingFixture
        $source = New-FixtureSourceRecord -Root $root
        Add-FixtureText -Root $root -RelativePath $source.path -Content ($script:forms.L3 + "`n")
        $source.sha256 = Get-FixtureSha256 -Root $root -RelativePath $source.path
        $source.hashBasis = 'utf8-lf'
        Add-FixtureSourceManifest -Root $root -Sources @($source)
        [IO.File]::WriteAllText((Join-Path $root $source.path), ($script:forms.L3 + "`r`n"),
            [Text.UTF8Encoding]::new($false))

        $result = Get-RepositoryBrandingScan -RepositoryRoot $root

        $result.Findings | Should -BeNullOrEmpty
        $result.ClassifiedSourceCount | Should -Be 1
    }

    It 'admits exact binary source paths without pretending their payload is text' {
        $root = New-BrandingFixture
        $source = New-FixtureSourceRecord -Root $root
        [IO.File]::WriteAllBytes((Join-Path $root $source.path),
            [byte[]](0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a))
        $source.sha256 = Get-FixtureSha256 -Root $root -RelativePath $source.path
        $source.contentMatches = @()
        Add-FixtureSourceManifest -Root $root -Sources @($source)

        $result = Get-RepositoryBrandingScan -RepositoryRoot $root

        $result.Findings | Should -BeNullOrEmpty
        $result.BinaryCount | Should -Be 1
        $result.ClassifiedSourceCount | Should -Be 1
    }

    It 'does not make a declared policy optional when its registry is deleted' {
        $root = New-BrandingFixture
        $source = New-FixtureSourceRecord -Root $root
        Add-FixtureSourceManifest -Root $root -Sources @($source)
        Remove-Item -LiteralPath (Join-Path $root '.github/cli/config/branding-source-classifications.json')

        $result = Get-RepositoryBrandingScan -RepositoryRoot $root

        $result.Findings.PatternClass | Should -Contain 'source-classification-error'
        $result.Findings.PatternClass | Should -Contain 'read-error'
        $result.ClassifiedSourceCount | Should -Be 0
    }

    It 'does not approve a Draft authority because its body contains an Approved example' {
        $root = New-BrandingFixture
        $source = New-FixtureSourceRecord -Root $root
        Add-FixtureSourceManifest -Root $root -Sources @($source) -Status 'Draft'
        Add-Content -LiteralPath (Join-Path $root 'docs/specs/2026-10-01-caldova-branding-migration-design.md') `
            -Value "`n## Example`n| **Status** | Approved |"

        $result = Get-RepositoryBrandingScan -RepositoryRoot $root

        $result.Findings.PatternClass | Should -Contain 'source-classification-error'
        $result.ClassifiedSourceCount | Should -Be 0
    }

    It 'does not admit protected evidence through differently cased Windows paths' {
        $root = New-BrandingFixture
        $source = New-FixtureSourceRecord -Root $root
        $source.path = 'hr/Evidence/ai-builder/run/capture.json'
        Add-FixtureText -Root $root -RelativePath $source.path -Content $script:forms.L3
        $source.sha256 = Get-FixtureSha256 -Root $root -RelativePath $source.path
        $source.pathMatches = @()
        Add-FixtureSourceManifest -Root $root -Sources @($source)

        $result = Get-RepositoryBrandingScan -RepositoryRoot $root

        $result.Findings.PatternClass | Should -Contain 'source-classification-error'
        $result.ClassifiedSourceCount | Should -Be 0
    }

    It 'does not treat a fenced example as the authority metadata table' {
        $root = New-BrandingFixture
        $source = New-FixtureSourceRecord -Root $root
        Add-FixtureSourceManifest -Root $root -Sources @($source)
        $policy = Join-Path $root 'docs/specs/2026-10-01-caldova-branding-migration-design.md'
        $content = [IO.File]::ReadAllText($policy)
        $content = $content.Replace('| Field | Value |', '```text' + "`n| Field | Value |")
        $content = $content.Replace('| **Status** | Approved |', '| **Status** | Approved |' + "`n" + '```')
        [IO.File]::WriteAllText($policy, $content, [Text.UTF8Encoding]::new($false))

        $result = Get-RepositoryBrandingScan -RepositoryRoot $root

        $result.Findings.PatternClass | Should -Contain 'source-classification-error'
        $result.ClassifiedSourceCount | Should -Be 0
    }

    It 'protects the default evidence authority even with an alternate evidence manifest' {
        $root = New-BrandingFixture
        $source = New-FixtureSourceRecord -Root $root
        $source.path = '.github/cli/config/branding-evidence-exceptions.json'
        Add-FixtureText -Root $root -RelativePath $source.path -Content $script:forms.L3
        $source.sha256 = Get-FixtureSha256 -Root $root -RelativePath $source.path
        $source.pathMatches = @()
        Add-FixtureSourceManifest -Root $root -Sources @($source)
        Add-FixtureText -Root $root -RelativePath 'config/alternate-evidence.json' `
            -Content '{"schemaVersion":"1.0","exceptions":[]}'

        $result = Get-RepositoryBrandingScan -RepositoryRoot $root `
            -EvidenceExceptionManifestPath (Join-Path $root 'config/alternate-evidence.json')

        $result.Findings.PatternClass | Should -Contain 'source-classification-error'
        $result.ClassifiedSourceCount | Should -Be 0
    }
}

Describe 'Current repository branding' {
    It 'contains no prohibited tracked path or scannable tracked text' {
        $result = Get-RepositoryBrandingScan -RepositoryRoot $script:repositoryRoot

        $result.Findings | Sort-Object Path, PatternClass |
            Should -BeNullOrEmpty
        $result.ApprovedEvidenceCount | Should -Be 7
        @($result.ApprovedEvidence).Count | Should -Be 7
    }
}
