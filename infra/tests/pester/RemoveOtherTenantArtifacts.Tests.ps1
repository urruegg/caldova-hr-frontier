Set-StrictMode -Version Latest

Describe 'Remove-OtherTenantArtifacts' {
    BeforeAll {
        $script:ScriptPath = Join-Path $PSScriptRoot '..\..\src\scripts\Remove-OtherTenantArtifacts.ps1'

        function script:New-FixtureRepository {
            $root = Join-Path $TestDrive ([guid]::NewGuid().ToString())
            New-Item -ItemType Directory -Path (Join-Path $root 'infra\src\config\tenants') -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $root 'infra\evidence\discovery') -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $root 'infra\src\bicep\params') -Force | Out-Null

            Set-Content -LiteralPath (Join-Path $root 'infra\src\config\tenants\_template.psd1') -Value '@{}'
            Set-Content -LiteralPath (Join-Path $root 'infra\src\config\tenants\tenanta.psd1') -Value "@{ TenantAlias = 'tenanta' }"
            Set-Content -LiteralPath (Join-Path $root 'infra\src\config\tenants\tenantb.psd1') -Value "@{ TenantAlias = 'tenantb' }"
            Set-Content -LiteralPath (Join-Path $root 'infra\evidence\discovery\tenanta.json') -Value '{}'
            Set-Content -LiteralPath (Join-Path $root 'infra\evidence\discovery\tenantb.json') -Value '{}'
            Set-Content -LiteralPath (Join-Path $root 'infra\src\bicep\params\tenanta.bicepparam') -Value ''
            Set-Content -LiteralPath (Join-Path $root 'infra\src\bicep\params\tenantb.bicepparam') -Value ''

            $root
        }
    }

    It 'lists every other tenant''s manifest, evidence, and Bicep parameter file without removing anything under -WhatIf' {
        $root = New-FixtureRepository

        $result = & $script:ScriptPath -TenantAliasToKeep 'tenanta' -RepositoryRootOverride $root -WhatIf

        @($result).Count | Should -Be 3
        $result | Should -Contain (Join-Path $root 'infra\src\config\tenants\tenantb.psd1')
        $result | Should -Contain (Join-Path $root 'infra\evidence\discovery\tenantb.json')
        $result | Should -Contain (Join-Path $root 'infra\src\bicep\params\tenantb.bicepparam')

        Test-Path -LiteralPath (Join-Path $root 'infra\src\config\tenants\tenantb.psd1') | Should -BeTrue
    }

    It 'never lists the kept tenant''s own files or the _template.psd1 schema file' {
        $root = New-FixtureRepository

        $result = & $script:ScriptPath -TenantAliasToKeep 'tenanta' -RepositoryRootOverride $root -WhatIf

        $result | Should -Not -Contain (Join-Path $root 'infra\src\config\tenants\tenanta.psd1')
        $result | Should -Not -Contain (Join-Path $root 'infra\src\config\tenants\_template.psd1')
        $result | Should -Not -Contain (Join-Path $root 'infra\evidence\discovery\tenanta.json')
    }

    It 'removes only the other tenant''s files when not run with -WhatIf' {
        $root = New-FixtureRepository

        & $script:ScriptPath -TenantAliasToKeep 'tenanta' -RepositoryRootOverride $root -Confirm:$false

        Test-Path -LiteralPath (Join-Path $root 'infra\src\config\tenants\tenantb.psd1') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $root 'infra\evidence\discovery\tenantb.json') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $root 'infra\src\bicep\params\tenantb.bicepparam') | Should -BeFalse

        Test-Path -LiteralPath (Join-Path $root 'infra\src\config\tenants\tenanta.psd1') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $root 'infra\src\config\tenants\_template.psd1') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $root 'infra\evidence\discovery\tenanta.json') | Should -BeTrue
    }

    It 'returns an empty result and removes nothing when only the kept tenant''s files exist' {
        $root = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path (Join-Path $root 'infra\src\config\tenants') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $root 'infra\src\config\tenants\tenanta.psd1') -Value "@{ TenantAlias = 'tenanta' }"

        $result = & $script:ScriptPath -TenantAliasToKeep 'tenanta' -RepositoryRootOverride $root -Confirm:$false

        @($result).Count | Should -Be 0
    }

    It 'rejects a tenant alias containing characters outside the reviewed pattern' {
        $root = New-FixtureRepository

        { & $script:ScriptPath -TenantAliasToKeep 'Tenant-A!' -RepositoryRootOverride $root -WhatIf } | Should -Throw
    }

    It 'keeps the matching tenant''s own files and removes only the other tenant''s when the kept alias is uppercase or mixed-case' {
        $root = New-FixtureRepository

        $result = & $script:ScriptPath -TenantAliasToKeep 'TenantA' -RepositoryRootOverride $root -Confirm:$false

        @($result).Count | Should -Be 3
        $result | Should -Contain (Join-Path $root 'infra\src\config\tenants\tenantb.psd1')
        $result | Should -Contain (Join-Path $root 'infra\evidence\discovery\tenantb.json')
        $result | Should -Contain (Join-Path $root 'infra\src\bicep\params\tenantb.bicepparam')

        Test-Path -LiteralPath (Join-Path $root 'infra\src\config\tenants\tenanta.psd1') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $root 'infra\evidence\discovery\tenanta.json') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $root 'infra\src\bicep\params\tenanta.bicepparam') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $root 'infra\src\config\tenants\_template.psd1') | Should -BeTrue
    }

    It 'throws instead of silently removing everything when the kept alias matches no tenant manifest' {
        $root = New-FixtureRepository

        { & $script:ScriptPath -TenantAliasToKeep 'tenantz' -RepositoryRootOverride $root -Confirm:$false } | Should -Throw

        Test-Path -LiteralPath (Join-Path $root 'infra\src\config\tenants\tenanta.psd1') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $root 'infra\src\config\tenants\tenantb.psd1') | Should -BeTrue
    }

    It 'resolves a relative -RepositoryRootOverride against the caller''s current PowerShell location, not an unrelated working directory' {
        $root = New-FixtureRepository
        $unrelatedDirectory = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $unrelatedDirectory -Force | Out-Null

        Push-Location $root
        try {
            $result = & $script:ScriptPath -TenantAliasToKeep 'tenanta' -RepositoryRootOverride '.' -WhatIf
        }
        finally {
            Pop-Location
        }

        @($result).Count | Should -Be 3
        $result | Should -Contain (Join-Path $root 'infra\src\config\tenants\tenantb.psd1')
    }
}
