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

    It 'classifies a staged link record as blocking rather than following its target' {
        $record = [Text.UTF8Encoding]::new($false).GetBytes(
            "120000 0123456789012345678901234567890123456789 0`tlink`0"
        )

        InModuleScope BrandingContract -Parameters @{ Bytes = $record } {
            param($Bytes)
            $entries = ConvertFrom-BrandingGitIndexBytes -Bytes $Bytes
            @($entries).Count | Should -Be 1
            $entries[0].Mode | Should -BeExactly '120000'
            $entries[0].Path | Should -BeExactly 'link'
        }
    }
}

Describe 'Current repository branding' {
    It 'contains no prohibited tracked path or scannable tracked text' {
        $result = Get-RepositoryBrandingScan -RepositoryRoot $script:repositoryRoot

        $result.Findings | Sort-Object Path, PatternClass |
            Should -BeNullOrEmpty
    }
}
