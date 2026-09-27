Set-StrictMode -Version Latest

Describe 'Cloud delegated context' {
    BeforeAll {
        $script:ModulePath = Join-Path $PSScriptRoot '..\..\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1'
        Import-Module $script:ModulePath -Force
        $fixturePath = Join-Path $PSScriptRoot '..\fixtures\runbooks\cloud-contexts.json'
        $script:Fixture = Get-Content -Raw -LiteralPath $fixturePath | ConvertFrom-Json
        $script:Calls = [Collections.Generic.List[object]]::new()
        $script:Runner = {
            param([string]$FilePath, [string[]]$ArgumentList)
            $script:Calls.Add([pscustomobject]@{ FilePath = $FilePath; ArgumentList = $ArgumentList })
            $key = "$FilePath|$($ArgumentList -join ' ')"
            $entry = $script:Fixture.PSObject.Properties[$key]
            if ($null -eq $entry) { throw "Unexpected fixture command: $key" }
            $entry.Value
        }
        $script:Tenant = [pscustomobject]@{
            TenantAlias = 'synthetic'
            TenantId = '22222222-2222-2222-2222-222222222222'
            SubscriptionId = '11111111-1111-1111-1111-111111111111'
            AdminUpn = 'admin@example.invalid'
            GitHub = [pscustomobject]@{
                Owner = 'synthetic-owner'; Repository = 'synthetic-repository'; RepositoryId = '67890'
            }
            AzureDevOps = [pscustomobject]@{
                OrganizationUrl = 'https://dev.azure.com/synthetic/'; ProjectName = 'SyntheticProject'
            }
            PowerPlatform = [pscustomobject]@{
                DevUrl = 'https://synthetic-dev.crm.dynamics.com/'
                TestUrl = 'https://synthetic-test.crm.dynamics.com/'
                ProdUrl = 'https://synthetic-prod.crm.dynamics.com/'
            }
            Components = [pscustomobject]@{
                AzureDevOpsProject = [pscustomobject]@{ Mode = 'Create' }
                PowerPlatformEnvironmentDev = [pscustomobject]@{ Mode = 'Existing'; Id = 'pp-env-dev-synthetic' }
                PowerPlatformEnvironmentTest = [pscustomobject]@{ Mode = 'Existing'; Id = 'pp-env-test-synthetic' }
                PowerPlatformEnvironmentProd = [pscustomobject]@{ Mode = 'Existing'; Id = 'pp-env-prod-synthetic' }
            }
        }
        $script:Tools = [ordered]@{
            az = [pscustomobject]@{ name='az';path='C:\SyntheticTools\az.cmd';version='2.77.0';sha256=('a'*64) }
            gh = [pscustomobject]@{ name='gh';path='C:\SyntheticTools\gh.exe';version='2.80.0';sha256=('b'*64) }
            pac = [pscustomobject]@{ name='pac';path='C:\SyntheticTools\pac.exe';version='1.46.0';sha256=('c'*64) }
            git = [pscustomobject]@{ name='git';path='C:\SyntheticTools\git.exe';version='2.51.0';sha256=('d'*64) }
        }
        $script:Interactive = { [pscustomobject]@{ isInteractive = $true; platform = 'Windows 11' } }
    }

    BeforeEach { $script:Calls.Clear() }

    It 'accepts one attended delegated user and exact reviewed targets' {
        $result = Test-CloudDelegatedContext -TenantConfiguration $script:Tenant -Stages DEV `
            -ToolResolutions $script:Tools -NativeCommandRunner $script:Runner `
            -InteractiveHostProbe $script:Interactive
        $result.overallStatus | Should -BeExactly 'Verified'
        $result.azure.userType | Should -BeExactly 'user'
        $result.github.repositoryId | Should -BeExactly '67890'
        $result.azureDevOps.actingUserId | Should -BeExactly 'ado-user-synthetic'
        $result.azureDevOps.projectIntent | Should -BeExactly 'Create'
        $result.azureDevOps.exactNameMatchCount | Should -Be 0
        $result.powerPlatform[0].profileName | Should -BeExactly 'hr-synthetic-dev'
        @($script:Calls.FilePath | Where-Object { -not [IO.Path]::IsPathRooted($_) }).Count | Should -Be 0
    }

    It 'refuses before repository metadata when the GitHub login differs' {
        $runner = {
            param($FilePath,$ArgumentList)
            $key = "$FilePath|$($ArgumentList -join ' ')"
            if ($key -eq 'C:\SyntheticTools\gh.exe|api user') {
                return [pscustomobject]@{ exitCode=0;stdout='{"id":999,"login":"other"}';stderr='' }
            }
            $script:Calls.Add([pscustomobject]@{ FilePath=$FilePath;ArgumentList=$ArgumentList })
            $script:Fixture.PSObject.Properties[$key].Value
        }
        { Test-CloudDelegatedContext -TenantConfiguration $script:Tenant -Stages DEV `
            -ToolResolutions $script:Tools -NativeCommandRunner $runner `
            -InteractiveHostProbe $script:Interactive } | Should -Throw '*GitHub delegated login does not match*'
        (($script:Calls.ArgumentList | ForEach-Object { $_ -join ' ' }) -join "`n") |
            Should -Not -Match 'repos/synthetic-owner/synthetic-repository'
    }

    It 'rejects service principals, prohibited auth environment, and unattended hosts' {
        $spRunner = {
            param($FilePath,$ArgumentList)
            $key = "$FilePath|$($ArgumentList -join ' ')"
            if ($key -eq 'C:\SyntheticTools\az.cmd|account show --output json') {
                return [pscustomobject]@{ exitCode=0;stdout='{"id":"11111111-1111-1111-1111-111111111111","tenantId":"22222222-2222-2222-2222-222222222222","user":{"name":"app","type":"servicePrincipal"}}';stderr='' }
            }
            $script:Fixture.PSObject.Properties[$key].Value
        }
        { Test-CloudDelegatedContext -TenantConfiguration $script:Tenant -Stages DEV `
            -ToolResolutions $script:Tools -NativeCommandRunner $spRunner `
            -InteractiveHostProbe $script:Interactive } | Should -Throw '*delegated user*'
        $old = $env:GH_TOKEN
        try {
            $env:GH_TOKEN = 'prohibited'
            { Test-CloudDelegatedContext -TenantConfiguration $script:Tenant -Stages DEV `
                -ToolResolutions $script:Tools -NativeCommandRunner $script:Runner `
                -InteractiveHostProbe $script:Interactive } | Should -Throw '*prohibited authentication environment*'
        } finally { $env:GH_TOKEN = $old }
        { Test-CloudDelegatedContext -TenantConfiguration $script:Tenant -Stages DEV `
            -ToolResolutions $script:Tools -NativeCommandRunner $script:Runner `
            -InteractiveHostProbe { [pscustomobject]@{ isInteractive=$false;platform='Windows 11' } } } |
            Should -Throw '*interactive*'
    }

    It 'resolves exactly one absolute application and binds version and lowercase hash' {
        $result = Resolve-CloudNativeTool -Name gh `
            -ApplicationResolver { [pscustomobject]@{ Source='C:\Tools\gh.exe';Version='2.80.0' } } `
            -FileHashProvider { param($Path) [pscustomobject]@{ Hash=('A'*64) } } `
            -VersionProvider { param($Path,$Name) '2.80.0' }
        $result.path | Should -BeExactly 'C:\Tools\gh.exe'
        $result.sha256 | Should -BeExactly ('a'*64)
        { Resolve-CloudNativeTool -Name gh -ApplicationResolver { @() } } |
            Should -Throw '*exactly one unique application*'
        { Resolve-CloudNativeTool -Name gh -ApplicationResolver {
            @([pscustomobject]@{Source='C:\A\gh.exe'},[pscustomobject]@{Source='D:\B\gh.exe'})
        } } | Should -Throw '*ambiguous*'
    }
}
