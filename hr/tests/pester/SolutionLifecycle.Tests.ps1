Set-StrictMode -Version Latest

Describe 'Get-HrTenantPowerPlatformUrl' {
    BeforeAll {
        $script:ModuleManifestPath = Join-Path $PSScriptRoot '..\..\src\scripts\modules\Caldova.HrFrontier.Solutions\Caldova.HrFrontier.Solutions.psd1'
        $script:RealTenantManifestPath = Join-Path $PSScriptRoot '..\..\..\infra\src\config\tenants\caldova25156897.psd1'
        Import-Module $script:ModuleManifestPath -Force

        function script:New-FixtureManifest {
            param([string]$Content)

            $path = Join-Path $TestDrive ([guid]::NewGuid().ToString() + '.psd1')
            [System.IO.File]::WriteAllText($path, $Content, [System.Text.UTF8Encoding]::new($false))
            $path
        }
    }

    It 'resolves the Dev, Test, and Prod URLs from the real Tenant 1 manifest' {
        (Get-HrTenantPowerPlatformUrl -TenantAlias 'caldova25156897' -Stage 'Dev' -TenantConfigurationPath $script:RealTenantManifestPath) |
            Should -Be 'https://hrfrontierdev.crm17.dynamics.com/'
        (Get-HrTenantPowerPlatformUrl -TenantAlias 'caldova25156897' -Stage 'Test' -TenantConfigurationPath $script:RealTenantManifestPath) |
            Should -Be 'https://hrfrontiertest.crm17.dynamics.com/'
        (Get-HrTenantPowerPlatformUrl -TenantAlias 'caldova25156897' -Stage 'Prod' -TenantConfigurationPath $script:RealTenantManifestPath) |
            Should -Be 'https://hrfrontier.crm17.dynamics.com/'
    }

    It 'resolves the default manifest path from TenantAlias when no path is given' {
        (Get-HrTenantPowerPlatformUrl -TenantAlias 'caldova25156897' -Stage 'Dev') |
            Should -Be 'https://hrfrontierdev.crm17.dynamics.com/'
    }

    It 'throws a clear error when the tenant manifest does not exist' {
        { Get-HrTenantPowerPlatformUrl -TenantAlias 'doesnotexist' -Stage 'Dev' } |
            Should -Throw '*Tenant manifest not found*'
    }

    It 'throws when the manifest has no PowerPlatform section' {
        $path = New-FixtureManifest -Content "@{ TenantAlias = 'fixturetenant' }"

        { Get-HrTenantPowerPlatformUrl -TenantAlias 'fixturetenant' -Stage 'Dev' -TenantConfigurationPath $path } |
            Should -Throw '*does not define PowerPlatform.DevUrl*'
    }

    It 'rejects an invalid TenantAlias' {
        { Get-HrTenantPowerPlatformUrl -TenantAlias 'Not-Valid!' -Stage 'Dev' } | Should -Throw
    }

    It 'rejects an invalid Stage' {
        { Get-HrTenantPowerPlatformUrl -TenantAlias 'caldova25156897' -Stage 'Staging' } | Should -Throw
    }
}
