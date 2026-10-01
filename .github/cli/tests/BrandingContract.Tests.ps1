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
        & $script:gitPath -C $Root add -- $RelativePath.Replace('\', '/')
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
}

Describe 'Current repository branding' {
    It 'contains no prohibited tracked path or scannable tracked text' {
        $result = Get-RepositoryBrandingScan -RepositoryRoot $script:repositoryRoot

        $result.Findings | Sort-Object Path, PatternClass |
            Should -BeNullOrEmpty
    }
}
