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

Describe 'Connect-HrPowerPlatformEnvironment' {
    BeforeAll {
        $script:ModuleManifestPath = Join-Path $PSScriptRoot '..\..\src\scripts\modules\Caldova.HrFrontier.Solutions\Caldova.HrFrontier.Solutions.psd1'
        $script:RealTenantManifestPath = Join-Path $PSScriptRoot '..\..\..\infra\src\config\tenants\caldova25156897.psd1'
        Import-Module $script:ModuleManifestPath -Force

        function script:New-FakeNativeRunner {
            param(
                [Parameter(Mandatory)]
                [hashtable]$Responses,

                # Not [Parameter(Mandatory)]: PowerShell rejects an empty
                # collection at bind time for mandatory collection-typed
                # parameters, but tests always pass a freshly-created (and
                # therefore empty) List here to be populated by the runner.
                [System.Collections.Generic.List[object]]$Calls
            )

            {
                param(
                    [Parameter(Mandatory)]
                    [string]$FilePath,

                    [Parameter(Mandatory)]
                    [string[]]$ArgumentList
                )

                $Calls.Add([pscustomobject]@{ FilePath = $FilePath; ArgumentList = @($ArgumentList) }) | Out-Null
                $joined = $ArgumentList -join ' '
                foreach ($key in $Responses.Keys) {
                    if ($joined -like $key) {
                        return $Responses[$key]
                    }
                }

                [pscustomobject]@{ ExitCode = 1; StdOut = ''; StdErr = "Unmapped fake call: $joined" }
            }.GetNewClosure()
        }

        $script:ExistingProfileAuthList = @'
Index Active Kind      Name                    User                                  Cloud  Type Environment Environment Url
[1]          UNIVERSAL hr-caldova25156897-dev admin@caldova25156897.onmicrosoft.com Public User
'@

        $script:EmptyAuthList = @'
Index Active Kind      Name         User                                  Cloud  Type Environment Environment Url
[1]          UNIVERSAL otherprofile admin@other.onmicrosoft.com           Public User
'@
    }

    It 'selects an existing profile rather than creating a new one' {
        $calls = [System.Collections.Generic.List[object]]::new()
        $runner = New-FakeNativeRunner -Calls $calls -Responses @{
            'auth list' = [pscustomobject]@{ ExitCode = 0; StdOut = $script:ExistingProfileAuthList; StdErr = '' }
            'auth select --name hr-caldova25156897-dev' = [pscustomobject]@{ ExitCode = 0; StdOut = ''; StdErr = '' }
            "org who --environment https://hrfrontierdev.crm17.dynamics.com/" = [pscustomobject]@{ ExitCode = 0; StdOut = 'Connected'; StdErr = '' }
        }

        $result = Connect-HrPowerPlatformEnvironment -TenantAlias 'caldova25156897' -Stage 'Dev' -TenantConfigurationPath $script:RealTenantManifestPath -NativeCommandRunner $runner

        $result.EnvironmentUrl | Should -Be 'https://hrfrontierdev.crm17.dynamics.com/'
        $result.ProfileName | Should -Be 'hr-caldova25156897-dev'
        @($calls | Where-Object { $_.ArgumentList -join ' ' -like 'auth create*' }).Count | Should -Be 0
        @($calls | Where-Object { $_.ArgumentList -join ' ' -eq 'auth select --name hr-caldova25156897-dev' }).Count | Should -Be 1
    }

    It 'creates a new profile when none matches' {
        $calls = [System.Collections.Generic.List[object]]::new()
        $runner = New-FakeNativeRunner -Calls $calls -Responses @{
            'auth list' = [pscustomobject]@{ ExitCode = 0; StdOut = $script:EmptyAuthList; StdErr = '' }
            'auth create --name hr-caldova25156897-dev --environment https://hrfrontierdev.crm17.dynamics.com/' = [pscustomobject]@{ ExitCode = 0; StdOut = ''; StdErr = '' }
            "org who --environment https://hrfrontierdev.crm17.dynamics.com/" = [pscustomobject]@{ ExitCode = 0; StdOut = 'Connected'; StdErr = '' }
        }

        $result = Connect-HrPowerPlatformEnvironment -TenantAlias 'caldova25156897' -Stage 'Dev' -TenantConfigurationPath $script:RealTenantManifestPath -NativeCommandRunner $runner

        $result.ProfileName | Should -Be 'hr-caldova25156897-dev'
        @($calls | Where-Object { $_.ArgumentList -join ' ' -eq 'auth create --name hr-caldova25156897-dev --environment https://hrfrontierdev.crm17.dynamics.com/' }).Count | Should -Be 1
    }

    It 'throws when the computed profile name would exceed 30 characters' {
        $runner = New-FakeNativeRunner -Calls ([System.Collections.Generic.List[object]]::new()) -Responses @{}

        { Connect-HrPowerPlatformEnvironment -TenantAlias 'aterriblylongtenantaliasname' -Stage 'Dev' -TenantConfigurationPath $script:RealTenantManifestPath -NativeCommandRunner $runner } |
            Should -Throw '*exceeds the 30-character limit*'
    }

    It 'propagates failure when pac auth list fails' {
        $runner = New-FakeNativeRunner -Calls ([System.Collections.Generic.List[object]]::new()) -Responses @{
            'auth list' = [pscustomobject]@{ ExitCode = 1; StdOut = ''; StdErr = 'boom' }
        }

        { Connect-HrPowerPlatformEnvironment -TenantAlias 'caldova25156897' -Stage 'Dev' -TenantConfigurationPath $script:RealTenantManifestPath -NativeCommandRunner $runner } |
            Should -Throw '*pac auth list failed*'
    }

    It 'propagates failure when pac org who fails' {
        $calls = [System.Collections.Generic.List[object]]::new()
        $runner = New-FakeNativeRunner -Calls $calls -Responses @{
            'auth list' = [pscustomobject]@{ ExitCode = 0; StdOut = $script:ExistingProfileAuthList; StdErr = '' }
            'auth select --name hr-caldova25156897-dev' = [pscustomobject]@{ ExitCode = 0; StdOut = ''; StdErr = '' }
            "org who --environment https://hrfrontierdev.crm17.dynamics.com/" = [pscustomobject]@{ ExitCode = 1; StdOut = ''; StdErr = 'not connected' }
        }

        { Connect-HrPowerPlatformEnvironment -TenantAlias 'caldova25156897' -Stage 'Dev' -TenantConfigurationPath $script:RealTenantManifestPath -NativeCommandRunner $runner } |
            Should -Throw '*pac org who failed*'
    }
}
