BeforeAll {
    $script:repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
    $script:selectorPath = Join-Path $script:repositoryRoot '.github\cli\Get-MaintainedTestGroups.ps1'
    $script:requirementsPath = Join-Path $script:repositoryRoot 'infra\tests\requirements.txt'
    $script:lifecycleAllowlist = [string[]]@(
        'infra/tests/pester/RunbookContracts.Tests.ps1'
        'infra/tests/pester/RunbookDocumentation.Tests.ps1'
        'infra/tests/pester/RunbookStaticSafety.Tests.ps1'
        'infra/tests/pester/TenantLifecycleContracts.Tests.ps1'
        'infra/tests/pester/TenantLifecycleOrchestration.Tests.ps1'
    )

    function script:New-MaintainedTestFixture {
        $root = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        $relativePaths = [string[]]@(
            '.github/cli/tests/nested/RepositoryNested.Tests.ps1'
            'hr/tests/pester/nested/HrNested.Tests.ps1'
            'infra/tests/pester/nested/InfrastructureNested.Tests.ps1'
            $script:lifecycleAllowlist
        )

        foreach ($relativePath in $relativePaths) {
            $path = Join-Path $root $relativePath.Replace('/', '\')
            [void](New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force)
            [IO.File]::WriteAllText(
                $path,
                "Describe 'fixture' { It 'exists' { `$true | Should -BeTrue } }`n",
                [Text.UTF8Encoding]::new($false)
            )
        }

        $root
    }

    function script:New-FileSystemTrackedPathProvider {
        $trackedPathProvider = {
            param([string]$ProviderRoot)

            @(
                Get-ChildItem -LiteralPath $ProviderRoot -Filter '*.Tests.ps1' -File -Recurse |
                    ForEach-Object {
                        $_.FullName.Substring($ProviderRoot.TrimEnd('\').Length + 1).
                            Replace('\', '/')
                    }
            )
        }.GetNewClosure()

        $trackedPathProvider
    }

    function script:Get-SelectedGroup {
        param(
            [Parameter(Mandatory)]
            [string]$Root,

            [Parameter(Mandatory)]
            [string]$Group,

            [Parameter(Mandatory)]
            [scriptblock]$TrackedPathProvider
        )

        [string[]]@(
            & $script:selectorPath `
                -Group $Group `
                -RepositoryRoot $Root `
                -TrackedPathProvider $TrackedPathProvider
        )
    }

    function script:Assert-ExactOrdinalArray {
        param(
            [AllowEmptyCollection()]
            [string[]]$Actual,

            [AllowEmptyCollection()]
            [string[]]$Expected
        )

        $Actual.Count | Should -Be $Expected.Count
        for ($index = 0; $index -lt $Expected.Count; $index++) {
            $Actual[$index] | Should -BeExactly $Expected[$index]
        }
    }
}

Describe 'Maintained recursive test ownership' {
    It 'discovers nested Repository Infrastructure and Hr test leaves' {
        $root = New-MaintainedTestFixture
        $provider = New-FileSystemTrackedPathProvider

        $repository = Get-SelectedGroup -Root $root -Group Repository -TrackedPathProvider $provider
        $infrastructure = Get-SelectedGroup -Root $root -Group Infrastructure -TrackedPathProvider $provider
        $hr = Get-SelectedGroup -Root $root -Group Hr -TrackedPathProvider $provider

        ($repository -CContains '.github/cli/tests/nested/RepositoryNested.Tests.ps1') |
            Should -BeTrue
        ($infrastructure -CContains 'infra/tests/pester/nested/InfrastructureNested.Tests.ps1') |
            Should -BeTrue
        ($hr -CContains 'hr/tests/pester/nested/HrNested.Tests.ps1') |
            Should -BeTrue
    }

    It 'returns the exact five-file Lifecycle allowlist' {
        $root = New-MaintainedTestFixture
        $provider = New-FileSystemTrackedPathProvider

        $actual = Get-SelectedGroup -Root $root -Group Lifecycle -TrackedPathProvider $provider

        Assert-ExactOrdinalArray -Actual $actual -Expected $script:lifecycleAllowlist
    }

    It 'returns every group nonempty as normalized ordinal strings' {
        $root = New-MaintainedTestFixture
        $provider = New-FileSystemTrackedPathProvider

        foreach ($group in @('Repository', 'Infrastructure', 'Hr', 'Lifecycle')) {
            [string[]]$actual = Get-SelectedGroup `
                -Root $root `
                -Group $group `
                -TrackedPathProvider $provider
            $actual.Count | Should -BeGreaterThan 0
            foreach ($path in $actual) {
                ($path -is [string]) | Should -BeTrue
                [IO.Path]::IsPathRooted($path) | Should -BeFalse
                $path.Contains('\') | Should -BeFalse
                $path.EndsWith('.Tests.ps1', [StringComparison]::Ordinal) | Should -BeTrue
            }

            [string[]]$expected = @($actual)
            [Array]::Sort($expected, [StringComparer]::Ordinal)
            Assert-ExactOrdinalArray -Actual $actual -Expected $expected
        }
    }

    It 'rejects a missing lifecycle allowlist leaf' {
        $root = New-MaintainedTestFixture
        Remove-Item -LiteralPath (
            Join-Path $root 'infra\tests\pester\RunbookContracts.Tests.ps1'
        ) -Force
        $provider = New-FileSystemTrackedPathProvider

        {
            Get-SelectedGroup -Root $root -Group Lifecycle -TrackedPathProvider $provider
        } | Should -Throw -ExpectedMessage 'MaintainedTests.Lifecycle*'
    }

    It 'rejects a directory at an allowlisted lifecycle path' {
        $root = New-MaintainedTestFixture
        $allowlistedPath = Join-Path $root 'infra\tests\pester\RunbookContracts.Tests.ps1'
        Remove-Item -LiteralPath $allowlistedPath -Force
        [void](New-Item -ItemType Directory -Path $allowlistedPath)
        $provider = New-FileSystemTrackedPathProvider

        {
            Get-SelectedGroup -Root $root -Group Lifecycle -TrackedPathProvider $provider
        } | Should -Throw -ExpectedMessage 'MaintainedTests.Leaf*'
    }

    It 'rejects canonical case drift from the tracked-path provider' {
        $root = New-MaintainedTestFixture
        $trackedPathProvider = {
            param([string]$ProviderRoot)

            @(
                Get-ChildItem -LiteralPath $ProviderRoot -Filter '*.Tests.ps1' -File -Recurse |
                    ForEach-Object {
                        $relativePath = $_.FullName.Substring(
                            $ProviderRoot.TrimEnd('\').Length + 1
                        ).Replace('\', '/')
                        if (
                            $relativePath -ceq
                            '.github/cli/tests/nested/RepositoryNested.Tests.ps1'
                        ) {
                            '.github/cli/tests/nested/repositorynested.Tests.ps1'
                        }
                        else {
                            $relativePath
                        }
                    }
            )
        }.GetNewClosure()

        {
            Get-SelectedGroup -Root $root -Group Repository `
                -TrackedPathProvider $trackedPathProvider
        } | Should -Throw -ExpectedMessage 'MaintainedTests.Case*'
    }

    It 'rejects duplicate canonical tracked rows' {
        $root = New-MaintainedTestFixture
        $trackedPathProvider = {
            param([string]$ProviderRoot)

            [string[]]$paths = @(
                Get-ChildItem -LiteralPath $ProviderRoot -Filter '*.Tests.ps1' -File -Recurse |
                    ForEach-Object {
                        $_.FullName.Substring($ProviderRoot.TrimEnd('\').Length + 1).
                            Replace('\', '/')
                    }
            )
            @($paths + $paths[0])
        }.GetNewClosure()

        {
            Get-SelectedGroup -Root $root -Group Repository `
                -TrackedPathProvider $trackedPathProvider
        } | Should -Throw -ExpectedMessage 'MaintainedTests.TrackedInventory*'
    }

    It 'rejects an untracked maintained-root test leaf' {
        $root = New-MaintainedTestFixture
        $untrackedPath = 'hr/tests/pester/nested/Untracked.Tests.ps1'
        [IO.File]::WriteAllText(
            (Join-Path $root $untrackedPath.Replace('/', '\')),
            "Describe 'untracked' { }`n",
            [Text.UTF8Encoding]::new($false)
        )
        $trackedPathProvider = {
            param([string]$ProviderRoot)

            @(
                Get-ChildItem -LiteralPath $ProviderRoot -Filter '*.Tests.ps1' -File -Recurse |
                    ForEach-Object {
                        $_.FullName.Substring($ProviderRoot.TrimEnd('\').Length + 1).
                            Replace('\', '/')
                    } |
                    Where-Object { $_ -cne $untrackedPath }
            )
        }.GetNewClosure()

        {
            Get-SelectedGroup -Root $root -Group Hr `
                -TrackedPathProvider $trackedPathProvider
        } | Should -Throw -ExpectedMessage 'MaintainedTests.Unowned*'
    }

    It 'rejects a tracked test outside the three maintained roots' {
        $root = New-MaintainedTestFixture
        $unexpectedPath = Join-Path $root 'other\Unexpected.Tests.ps1'
        [void](New-Item -ItemType Directory -Path (Split-Path -Parent $unexpectedPath))
        [IO.File]::WriteAllText(
            $unexpectedPath,
            "Describe 'unexpected' { }`n",
            [Text.UTF8Encoding]::new($false)
        )
        $provider = New-FileSystemTrackedPathProvider

        {
            Get-SelectedGroup -Root $root -Group Repository -TrackedPathProvider $provider
        } | Should -Throw -ExpectedMessage 'MaintainedTests.Unowned*'
    }

    It 'keeps every pair of groups disjoint and their union complete' {
        $root = New-MaintainedTestFixture
        $provider = New-FileSystemTrackedPathProvider
        $groups = [ordered]@{}
        foreach ($group in @('Repository', 'Infrastructure', 'Hr', 'Lifecycle')) {
            $groups[$group] = [string[]]@(
                Get-SelectedGroup -Root $root -Group $group -TrackedPathProvider $provider
            )
        }

        $groupNames = [string[]]@($groups.Keys)
        for ($left = 0; $left -lt $groupNames.Count; $left++) {
            for ($right = $left + 1; $right -lt $groupNames.Count; $right++) {
                $intersection = @(
                    $groups[$groupNames[$left]] |
                        Where-Object { $groups[$groupNames[$right]] -CContains $_ }
                )
                $intersection.Count | Should -Be 0
            }
        }

        [string[]]$actualUnion = @($groups.Values | ForEach-Object { $_ })
        [Array]::Sort($actualUnion, [StringComparer]::Ordinal)
        [string[]]$expectedInventory = @(
            Get-ChildItem `
                -LiteralPath (
                    Join-Path $root '.github\cli\tests'
                ), (
                    Join-Path $root 'infra\tests\pester'
                ), (
                    Join-Path $root 'hr\tests\pester'
                ) `
                -Filter '*.Tests.ps1' `
                -File `
                -Recurse |
                ForEach-Object {
                    $_.FullName.Substring($root.TrimEnd('\').Length + 1).
                        Replace('\', '/')
                }
        )
        [Array]::Sort($expectedInventory, [StringComparer]::Ordinal)

        Assert-ExactOrdinalArray -Actual $actualUnion -Expected $expectedInventory
    }

    It 'returns the same exact order under en-US and tr-TR' {
        $root = New-MaintainedTestFixture
        $provider = New-FileSystemTrackedPathProvider
        $currentCulture = [Threading.Thread]::CurrentThread.CurrentCulture
        $currentUICulture = [Threading.Thread]::CurrentThread.CurrentUICulture
        try {
            $byCulture = @{}
            foreach ($cultureName in @('en-US', 'tr-TR')) {
                $culture = [Globalization.CultureInfo]::GetCultureInfo($cultureName)
                [Threading.Thread]::CurrentThread.CurrentCulture = $culture
                [Threading.Thread]::CurrentThread.CurrentUICulture = $culture
                $byCulture[$cultureName] = [ordered]@{}
                foreach ($group in @('Repository', 'Infrastructure', 'Hr', 'Lifecycle')) {
                    $byCulture[$cultureName][$group] = [string[]]@(
                        Get-SelectedGroup `
                            -Root $root `
                            -Group $group `
                            -TrackedPathProvider $provider
                    )
                }
            }
        }
        finally {
            [Threading.Thread]::CurrentThread.CurrentCulture = $currentCulture
            [Threading.Thread]::CurrentThread.CurrentUICulture = $currentUICulture
        }

        foreach ($group in @('Repository', 'Infrastructure', 'Hr', 'Lifecycle')) {
            Assert-ExactOrdinalArray `
                -Actual $byCulture['tr-TR'][$group] `
                -Expected $byCulture['en-US'][$group]
        }
    }

    It 'keeps infra/tests/requirements.txt at one exact UTF-8 line' {
        $requirementsBytes = [IO.File]::ReadAllBytes($script:requirementsPath)
        $requirementsBytes[0] | Should -Not -Be 0xEF
        [Text.UTF8Encoding]::new($false, $true).GetString($requirementsBytes).
            Replace("`r`n", "`n") |
            Should -BeExactly "jsonschema[format]==4.26.0`n"
    }
}
