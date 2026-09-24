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

Describe 'Export-HrSolutionPackage' {
    BeforeAll {
        $script:ModuleManifestPath = Join-Path $PSScriptRoot '..\..\src\scripts\modules\Caldova.HrFrontier.Solutions\Caldova.HrFrontier.Solutions.psd1'
        $script:RealTenantManifestPath = Join-Path $PSScriptRoot '..\..\..\infra\src\config\tenants\caldova25156897.psd1'
        Import-Module $script:ModuleManifestPath -Force

        function script:New-ExportFakeRunner {
            param([System.Collections.Generic.List[object]]$Calls)

            {
                param(
                    [Parameter(Mandatory)]
                    [string]$FilePath,

                    [Parameter(Mandatory)]
                    [string[]]$ArgumentList
                )

                $Calls.Add([pscustomobject]@{ FilePath = $FilePath; ArgumentList = @($ArgumentList) }) | Out-Null
                $joined = $ArgumentList -join ' '
                if ($joined -eq 'auth list') {
                    return [pscustomobject]@{ ExitCode = 0; StdOut = "Index Active Kind Name User Cloud Type`n[1] * UNIVERSAL hr-caldova25156897-dev admin@x Public User"; StdErr = '' }
                }
                if ($joined -eq 'auth select --name hr-caldova25156897-dev') {
                    return [pscustomobject]@{ ExitCode = 0; StdOut = ''; StdErr = '' }
                }
                if ($joined -eq 'org who --environment https://hrfrontierdev.crm17.dynamics.com/') {
                    return [pscustomobject]@{ ExitCode = 0; StdOut = 'Connected'; StdErr = '' }
                }
                if ($FilePath -eq 'pac' -and $ArgumentList[0] -eq 'solution' -and $ArgumentList[1] -eq 'export') {
                    $pathIndex = [array]::IndexOf($ArgumentList, '--path') + 1
                    [System.IO.File]::WriteAllText($ArgumentList[$pathIndex], 'fake zip content')
                    return [pscustomobject]@{ ExitCode = 0; StdOut = 'Solution export succeeded.'; StdErr = '' }
                }

                [pscustomobject]@{ ExitCode = 1; StdOut = ''; StdErr = "Unmapped fake call: $joined" }
            }.GetNewClosure()
        }
    }

    It 'exports with the Dev environment explicitly, never relying on ambient org state' {
        $destination = Join-Path $TestDrive 'caldovahrfrontier.zip'
        $calls = [System.Collections.Generic.List[object]]::new()
        $runner = New-ExportFakeRunner -Calls $calls

        $result = Export-HrSolutionPackage -TenantAlias 'caldova25156897' -SolutionUniqueName 'caldovahrfrontier' -DestinationPath $destination -TenantConfigurationPath $script:RealTenantManifestPath -NativeCommandRunner $runner

        $result.EnvironmentUrl | Should -Be 'https://hrfrontierdev.crm17.dynamics.com/'
        $result.SolutionUniqueName | Should -Be 'caldovahrfrontier'
        Test-Path -LiteralPath $result.Path | Should -BeTrue

        $exportCall = $calls | Where-Object { $_.ArgumentList[0] -eq 'solution' -and $_.ArgumentList[1] -eq 'export' }
        $exportCall.ArgumentList -join ' ' | Should -Be "solution export --name caldovahrfrontier --path $destination --managed false --overwrite true --environment https://hrfrontierdev.crm17.dynamics.com/"
    }

    It 'does not expose a Stage parameter — export is always Dev-only' {
        (Get-Command Export-HrSolutionPackage).Parameters.Keys | Should -Not -Contain 'Stage'
    }

    It 'throws when pac solution export fails' {
        $destination = Join-Path $TestDrive 'failed.zip'
        $runner = {
            param([string]$FilePath, [string[]]$ArgumentList)
            $joined = $ArgumentList -join ' '
            if ($joined -eq 'auth list') { return [pscustomobject]@{ ExitCode = 0; StdOut = "Index`n[1] * UNIVERSAL hr-caldova25156897-dev admin@x Public User"; StdErr = '' } }
            if ($joined -eq 'auth select --name hr-caldova25156897-dev') { return [pscustomobject]@{ ExitCode = 0; StdOut = ''; StdErr = '' } }
            if ($joined -eq 'org who --environment https://hrfrontierdev.crm17.dynamics.com/') { return [pscustomobject]@{ ExitCode = 0; StdOut = ''; StdErr = '' } }
            [pscustomobject]@{ ExitCode = 1; StdOut = ''; StdErr = 'export failed' }
        }

        { Export-HrSolutionPackage -TenantAlias 'caldova25156897' -SolutionUniqueName 'caldovahrfrontier' -DestinationPath $destination -TenantConfigurationPath $script:RealTenantManifestPath -NativeCommandRunner $runner } |
            Should -Throw '*pac solution export failed*'
    }
}

Describe 'Expand-HrSolutionPackage' {
    BeforeAll {
        $script:ModuleManifestPath = Join-Path $PSScriptRoot '..\..\src\scripts\modules\Caldova.HrFrontier.Solutions\Caldova.HrFrontier.Solutions.psd1'
        Import-Module $script:ModuleManifestPath -Force
    }

    It 'constructs the exact expected pac solution unpack arguments and reports the target folder' {
        $zipPath = Join-Path $TestDrive 'caldovahrfrontier.zip'
        [System.IO.File]::WriteAllText($zipPath, 'fake zip content')
        $solutionsRoot = Join-Path $TestDrive 'solutions'
        $expectedFolder = Join-Path $solutionsRoot 'caldovahrfrontier'
        $calls = [System.Collections.Generic.List[object]]::new()

        $runner = {
            param([string]$FilePath, [string[]]$ArgumentList)
            $calls.Add(@($ArgumentList)) | Out-Null
            [void](New-Item -ItemType Directory -Path $expectedFolder -Force)
            [System.IO.File]::WriteAllText((Join-Path $expectedFolder 'solution.xml'), '<x/>')
            [pscustomobject]@{ ExitCode = 0; StdOut = 'Unpacked Solution.'; StdErr = '' }
        }.GetNewClosure()

        $result = Expand-HrSolutionPackage -ZipPath $zipPath -SolutionUniqueName 'caldovahrfrontier' -SolutionsRoot $solutionsRoot -NativeCommandRunner $runner

        $result.Folder | Should -Be $expectedFolder
        ($calls[0] -join ' ') | Should -Be "solution unpack --zipfile $zipPath --folder $expectedFolder --packagetype Unmanaged --allowWrite true --allowDelete true --clobber true"
    }

    It 'throws when the zip file does not exist' {
        { Expand-HrSolutionPackage -ZipPath (Join-Path $TestDrive 'missing.zip') -SolutionUniqueName 'x' -SolutionsRoot $TestDrive } |
            Should -Throw '*Solution zip not found*'
    }

    It 'throws when pac solution unpack fails' {
        $zipPath = Join-Path $TestDrive 'caldovahrfrontier2.zip'
        [System.IO.File]::WriteAllText($zipPath, 'fake zip content')
        $runner = { param([string]$FilePath, [string[]]$ArgumentList) [pscustomobject]@{ ExitCode = 1; StdOut = ''; StdErr = 'unpack failed' } }

        { Expand-HrSolutionPackage -ZipPath $zipPath -SolutionUniqueName 'caldovahrfrontier' -SolutionsRoot (Join-Path $TestDrive 'solutions2') -NativeCommandRunner $runner } |
            Should -Throw '*pac solution unpack failed*'
    }

    It 'throws when unpack reports success but the target folder is empty' {
        $zipPath = Join-Path $TestDrive 'caldovahrfrontier3.zip'
        [System.IO.File]::WriteAllText($zipPath, 'fake zip content')
        $solutionsRoot = Join-Path $TestDrive 'solutions3'
        $expectedFolder = Join-Path $solutionsRoot 'caldovahrfrontier'
        $runner = {
            param([string]$FilePath, [string[]]$ArgumentList)
            [void](New-Item -ItemType Directory -Path $expectedFolder -Force)
            [pscustomobject]@{ ExitCode = 0; StdOut = ''; StdErr = '' }
        }.GetNewClosure()

        { Expand-HrSolutionPackage -ZipPath $zipPath -SolutionUniqueName 'caldovahrfrontier' -SolutionsRoot $solutionsRoot -NativeCommandRunner $runner } |
            Should -Throw '*is empty*'
    }
}
