Set-StrictMode -Version Latest

Describe 'Tenant configuration' {
    BeforeAll {
        $script:RepositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
        $script:ModuleManifestPath = Join-Path $PSScriptRoot '..\..\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1'
        function script:New-TestTenantConfigurationContent {
            param(
                [string]$PublicTenantKey = 'tenant1',
                [string]$UniqueSuffix = 'a7k29x',
                [string]$NamingRoot = 'cal-hr-agentic-a7k29x',
                [string]$LifecycleState = 'DiscoveryRequired',
                [string]$Components = '@{}',
                [string]$GitHubBody = @"
        @{
            Owner = 'urruegg'
            OwnerId = '46865858'
            Repository = 'caldova-hr-frontier'
            RepositoryId = '1371297722'
            EnvironmentName = 'bootstrap-caldova25156897'
        }
"@,
                [string]$AzureDevOpsBody = @"
        @{
            OrganizationUrl = 'https://dev.azure.com/caldova25156897/'
            ProjectName = 'Caldova HR Frontier'
        }
"@,
                [string]$PowerPlatformBody = @"
        @{
            DevUrl = 'https://hrfrontierdev.crm17.dynamics.com/'
            TestUrl = 'https://hrfrontiertest.crm17.dynamics.com/'
            ProdUrl = 'https://hrfrontier.crm17.dynamics.com/'
        }
"@
            )

            @"
@{
    SchemaVersion = '1.0'
    PublicTenantKey = '$PublicTenantKey'
    TenantAlias = 'caldova25156897'
    DisplayName = 'Caldova25156897'
    TenantId = 'e2312862-df63-440c-8bcf-007a2c52859d'
    AdminUpn = 'admin@Caldova25156897.onmicrosoft.com'
    SubscriptionId = 'edb45a24-408d-47c4-bbc7-685b9b3fc017'
    PrimaryLocation = 'switzerlandnorth'
    CompanyTla = 'cal'
    WorkloadName = 'hr-agentic'
    UniqueSuffix = '$UniqueSuffix'
    NamingRoot = '$NamingRoot'
    LifecycleState = '$LifecycleState'
    GitHub = $GitHubBody
    AzureDevOps = $AzureDevOpsBody
    PowerPlatform = $PowerPlatformBody
    Components = $Components
}
"@
        }
        function script:New-TestTenantConfigurationFile {
            param(
                [string]$Content
            )

            $path = Join-Path $TestDrive ([guid]::NewGuid().ToString() + '.psd1')
            [System.IO.File]::WriteAllText($path, $Content, [System.Text.UTF8Encoding]::new($false))
            return $path
        }
        $script:TenantManifestPath = New-TestTenantConfigurationFile -Content (New-TestTenantConfigurationContent `
            -LifecycleState 'IntentReviewed' `
            -Components @"
        @{
            GitHubRepository = @{ Mode = 'Existing'; Id = '1371297722' }
            EntraApplication = @{ Mode = 'Create' }
            EntraServicePrincipal = @{ Mode = 'Create' }
            EntraFederatedIdentityCredential = @{ Mode = 'Create' }
            GitHubEnvironment = @{ Mode = 'Create' }
            AzureSubscription = @{ Mode = 'Existing'; Id = 'edb45a24-408d-47c4-bbc7-685b9b3fc017' }
            AzureDevOpsProject = @{ Mode = 'Existing'; Id = 'f250378e-597d-487b-854a-fb8338962822' }
            AzureDevOpsServicePrincipalEntitlement = @{ Mode = 'Create' }
            AzureDevOpsReadersMembership = @{ Mode = 'Create' }
            PowerPlatformEnvironmentDev = @{ Mode = 'Existing'; Id = '346c2cb2-534d-e581-978f-4c293e25a146' }
            PowerPlatformEnvironmentTest = @{ Mode = 'Existing'; Id = '86fb2f33-4145-e23a-b064-5e0850aba258' }
            PowerPlatformEnvironmentProd = @{ Mode = 'Existing'; Id = 'c5d83095-c8bf-ec78-94dd-b4e62f34c85e' }
        }
"@)
        Import-Module $script:ModuleManifestPath -Force
    }

    It 'ignores only local tenant configuration files and keeps the template tracked' {
        $rules = Get-Content -LiteralPath (Join-Path $script:RepositoryRoot '.gitignore')
        $rules | Should -Contain 'infra/src/config/tenants/*.local.psd1'
        & git -C $script:RepositoryRoot check-ignore --quiet -- 'infra/src/config/tenants/tenant1.local.psd1'
        $LASTEXITCODE | Should -Be 0
        & git -C $script:RepositoryRoot ls-files --error-unmatch -- 'infra/src/config/tenants/_template.psd1' 2>$null
        $LASTEXITCODE | Should -Be 0
    }

    It 'rejects template tracked wrong-key and non-boundary paths for live use' {
        { Import-TenantConfiguration -Path (Join-Path $script:RepositoryRoot 'infra\src\config\tenants\_template.psd1') `
            -ValidationStage Discovery -ExpectedPublicTenantKey tenant1 -RequireLocalUntracked } |
            Should -Throw '*template*'
        { Import-TenantConfiguration -Path $script:TenantManifestPath `
            -ValidationStage Discovery -ExpectedPublicTenantKey tenant2 } |
            Should -Throw '*PublicTenantKey*tenant2*'
    }

    It 'requires the explicit local configuration parameter on every active command' {
        foreach ($scriptName in @(
            'Invoke-TenantDiscovery.ps1',
            'New-TenantBicepParameters.ps1',
            'Invoke-TenantBootstrap.ps1'
        )) {
            $path = Join-Path $script:RepositoryRoot "infra\src\scripts\$scriptName"
            { & $path -PublicTenantKey tenant1 } | Should -Throw '*TenantConfigurationPath*'
        }
    }

    It 'imports the protected Tenant 2 tracked manifest without a public tenant key probe' {
        $configuration = Import-TenantConfiguration `
            -Path (Join-Path $script:RepositoryRoot 'infra\src\config\tenants\caldova25668747.psd1') `
            -ValidationStage Discovery

        $configuration.TenantAlias | Should -BeExactly 'caldova25668747'
    }

    It 'requires the public tenant key only when a live boundary is requested' {
        $withoutPublicKey = (New-TestTenantConfigurationContent) `
            -replace "(?m)^\s*PublicTenantKey\s*=.*\r?\n", ''
        $path = New-TestTenantConfigurationFile -Content $withoutPublicKey

        $configuration = Import-TenantConfiguration -Path $path -ValidationStage Discovery
        $configuration.TenantAlias | Should -BeExactly 'caldova25156897'
        {
            Import-TenantConfiguration -Path $path -ValidationStage Discovery `
                -ExpectedPublicTenantKey tenant1
        } | Should -Throw '*PublicTenantKey*required*'
        {
            Import-TenantConfiguration -Path $path -ValidationStage Discovery `
                -RequireLocalUntracked
        } | Should -Throw '*ExpectedPublicTenantKey*required*'
    }

    It 'rejects uppercase public tenant keys before live script execution' {
        $uppercasePath = New-TestTenantConfigurationFile -Content (
            New-TestTenantConfigurationContent -PublicTenantKey 'Tenant1'
        )
        {
            Import-TenantConfiguration -Path $uppercasePath -ValidationStage Discovery `
                -ExpectedPublicTenantKey Tenant1
        } | Should -Throw '*case-sensitive lowercase*'

        foreach ($scriptName in @(
            'Invoke-TenantDiscovery.ps1',
            'New-TenantBicepParameters.ps1',
            'Invoke-TenantBootstrap.ps1'
        )) {
            $path = Join-Path $script:RepositoryRoot "infra\src\scripts\$scriptName"
            { & $path -PublicTenantKey Tenant1 } | Should -Throw '*case-sensitive lowercase*'
        }
    }

    It 'accepts the Tenant 1 contract and exact ALM URLs' {
        $config = Import-TenantConfiguration -Path $script:TenantManifestPath -ValidationStage Discovery -ExpectedPublicTenantKey tenant1

        $config.TenantAlias | Should -Be 'caldova25156897'
        $config.DisplayName | Should -Be 'Caldova25156897'
        $config.TenantId | Should -Be 'e2312862-df63-440c-8bcf-007a2c52859d'
        $config.AdminUpn | Should -Be 'admin@Caldova25156897.onmicrosoft.com'
        $config.SubscriptionId | Should -Be 'edb45a24-408d-47c4-bbc7-685b9b3fc017'
        $config.PrimaryLocation | Should -Be 'switzerlandnorth'
        $config.AzureDevOps.OrganizationUrl | Should -Be 'https://dev.azure.com/caldova25156897/'
        $config.AzureDevOps.ProjectName | Should -Be 'Caldova HR Frontier'
        $config.PowerPlatform.DevUrl | Should -Be 'https://hrfrontierdev.crm17.dynamics.com/'
        $config.PowerPlatform.TestUrl | Should -Be 'https://hrfrontiertest.crm17.dynamics.com/'
        $config.PowerPlatform.ProdUrl | Should -Be 'https://hrfrontier.crm17.dynamics.com/'
        $config.GitHub.Owner | Should -Be 'urruegg'
        $config.GitHub.OwnerId | Should -Be '46865858'
        $config.GitHub.Repository | Should -Be 'caldova-hr-frontier'
        $config.GitHub.RepositoryId | Should -Be '1371297722'
        $config.GitHub.EnvironmentName | Should -Be 'bootstrap-caldova25156897'
        $config.UniqueSuffix | Should -Match '^[a-z0-9]{6}$'
        $config.NamingRoot | Should -Be "cal-hr-agentic-$($config.UniqueSuffix)"
        $config.LifecycleState | Should -Be 'IntentReviewed'
        $config.Components.GitHubRepository.Mode | Should -Be 'Existing'
        $config.Components.GitHubRepository.Id | Should -Be '1371297722'
        $config.Components.EntraApplication.Mode | Should -Be 'Create'
        $config.Components.EntraServicePrincipal.Mode | Should -Be 'Create'
        $config.Components.EntraFederatedIdentityCredential.Mode | Should -Be 'Create'
        $config.Components.GitHubEnvironment.Mode | Should -Be 'Create'
        $config.Components.AzureSubscription.Mode | Should -Be 'Existing'
        $config.Components.AzureSubscription.Id | Should -Be 'edb45a24-408d-47c4-bbc7-685b9b3fc017'
        $config.Components.AzureDevOpsProject.Mode | Should -Be 'Existing'
        $config.Components.AzureDevOpsProject.Id | Should -Be 'f250378e-597d-487b-854a-fb8338962822'
        $config.Components.AzureDevOpsServicePrincipalEntitlement.Mode | Should -Be 'Create'
        $config.Components.AzureDevOpsReadersMembership.Mode | Should -Be 'Create'
        $config.Components.PowerPlatformEnvironmentDev.Mode | Should -Be 'Existing'
        $config.Components.PowerPlatformEnvironmentDev.Id | Should -Be '346c2cb2-534d-e581-978f-4c293e25a146'
        $config.Components.PowerPlatformEnvironmentTest.Mode | Should -Be 'Existing'
        $config.Components.PowerPlatformEnvironmentTest.Id | Should -Be '86fb2f33-4145-e23a-b064-5e0850aba258'
        $config.Components.PowerPlatformEnvironmentProd.Mode | Should -Be 'Existing'
        $config.Components.PowerPlatformEnvironmentProd.Id | Should -Be 'c5d83095-c8bf-ec78-94dd-b4e62f34c85e'
        @($config.Components | Get-Member -MemberType NoteProperty, Property, ScriptProperty).Count | Should -Be 12
    }

    It 'rejects executable expressions and unknown top-level keys' {
        $path = New-TestTenantConfigurationFile -Content "@{ TenantAlias = (Get-Date); Unknown = 'x' }"

        { Import-TenantConfiguration -Path $path -ExpectedPublicTenantKey tenant1 } | Should -Throw
    }

    It 'rejects unknown nested keys and component entry keys' {
        $nestedUnknown = New-TestTenantConfigurationFile -Content (New-TestTenantConfigurationContent -GitHubBody @"
        @{
            Owner = 'urruegg'
            OwnerId = '46865858'
            Repository = 'caldova-hr-frontier'
            RepositoryId = '1371297722'
            EnvironmentName = 'bootstrap-caldova25156897'
            Extra = 'nope'
        }
"@)
        { Import-TenantConfiguration -Path $nestedUnknown -ExpectedPublicTenantKey tenant1 } | Should -Throw

        $componentUnknown = New-TestTenantConfigurationFile -Content (New-TestTenantConfigurationContent -Components @"
        @{
            AzureDevOpsProject = @{
                Mode = 'Create'
                Extra = 'nope'
            }
        }
"@)
        { Import-TenantConfiguration -Path $componentUnknown -ExpectedPublicTenantKey tenant1 } | Should -Throw
    }

    It 'rejects invalid GUIDs URLs immutable ids and cross-field derivations' {
        $badTenantId = New-TestTenantConfigurationFile -Content (New-TestTenantConfigurationContent).Replace("TenantId = 'e2312862-df63-440c-8bcf-007a2c52859d'", "TenantId = 'not-a-guid'")
        { Import-TenantConfiguration -Path $badTenantId -ExpectedPublicTenantKey tenant1 } | Should -Throw

        $badUrl = New-TestTenantConfigurationFile -Content (New-TestTenantConfigurationContent -AzureDevOpsBody @"
        @{
            OrganizationUrl = 'http://dev.azure.com/caldova25156897/'
            ProjectName = 'Caldova HR Frontier'
        }
"@)
        { Import-TenantConfiguration -Path $badUrl -ExpectedPublicTenantKey tenant1 } | Should -Throw

        $badOwnerId = New-TestTenantConfigurationFile -Content (New-TestTenantConfigurationContent -GitHubBody @"
        @{
            Owner = 'urruegg'
            OwnerId = '046865858x'
            Repository = 'caldova-hr-frontier'
            RepositoryId = '1371297722'
            EnvironmentName = 'bootstrap-caldova25156897'
        }
"@)
        { Import-TenantConfiguration -Path $badOwnerId -ExpectedPublicTenantKey tenant1 } | Should -Throw

        $badEnvironment = New-TestTenantConfigurationFile -Content (New-TestTenantConfigurationContent -GitHubBody @"
        @{
            Owner = 'urruegg'
            OwnerId = '46865858'
            Repository = 'caldova-hr-frontier'
            RepositoryId = '1371297722'
            EnvironmentName = 'bootstrap-other'
        }
"@)
        { Import-TenantConfiguration -Path $badEnvironment -ExpectedPublicTenantKey tenant1 } | Should -Throw

        $badNamingRoot = New-TestTenantConfigurationFile -Content (New-TestTenantConfigurationContent -NamingRoot 'cal-hr-agentic-zzzzzz')
        { Import-TenantConfiguration -Path $badNamingRoot -ExpectedPublicTenantKey tenant1 } | Should -Throw
    }

    It 'rejects duplicate Power Platform URLs and Auto mode' {
        $duplicateUrl = New-TestTenantConfigurationFile -Content (New-TestTenantConfigurationContent -PowerPlatformBody @"
        @{
            DevUrl = 'https://hrfrontierdev.crm17.dynamics.com/'
            TestUrl = 'https://hrfrontierdev.crm17.dynamics.com/'
            ProdUrl = 'https://hrfrontier.crm17.dynamics.com/'
        }
"@)
        { Import-TenantConfiguration -Path $duplicateUrl -ExpectedPublicTenantKey tenant1 } | Should -Throw

        $autoMode = New-TestTenantConfigurationFile -Content (New-TestTenantConfigurationContent -LifecycleState 'IntentReviewed' -Components @"
        @{
            AzureDevOpsProject = @{
                Mode = 'Auto'
            }
        }
"@)
        { Import-TenantConfiguration -Path $autoMode -ValidationStage Bootstrap -ExpectedPublicTenantKey tenant1 } | Should -Throw
    }

    It 'accepts discovery state with an empty component map' {
        $path = New-TestTenantConfigurationFile -Content (New-TestTenantConfigurationContent -LifecycleState 'DiscoveryRequired' -Components '@{}')

        $config = Import-TenantConfiguration -Path $path -ValidationStage Discovery -ExpectedPublicTenantKey tenant1

        $config.LifecycleState | Should -Be 'DiscoveryRequired'
        @($config.Components | Get-Member -MemberType NoteProperty, Property, ScriptProperty).Count | Should -Be 0
    }

    It 'accepts reviewed discovery state with a non-empty reviewed component map' {
        $path = New-TestTenantConfigurationFile -Content (New-TestTenantConfigurationContent -LifecycleState 'IntentReviewed' -Components @"
        @{
            AzureDevOpsProject = @{
                Mode = 'Create'
            }
            PowerPlatformDev = @{
                Mode = 'Existing'
                Id = 'powerplatform-environment-dev'
            }
        }
"@)

        $config = Import-TenantConfiguration -Path $path -ValidationStage Discovery -ExpectedPublicTenantKey tenant1

        $config.LifecycleState | Should -Be 'IntentReviewed'
        $config.Components.AzureDevOpsProject.Mode | Should -Be 'Create'
        $config.Components.PowerPlatformDev.Id | Should -Be 'powerplatform-environment-dev'
    }

    It 'requires reviewed bootstrap state with non-empty explicit components' {
        $emptyComponents = New-TestTenantConfigurationFile -Content (New-TestTenantConfigurationContent -LifecycleState 'IntentReviewed' -Components '@{}')
        { Import-TenantConfiguration -Path $emptyComponents -ValidationStage Bootstrap -ExpectedPublicTenantKey tenant1 } | Should -Throw

        $wrongState = New-TestTenantConfigurationFile -Content (New-TestTenantConfigurationContent -LifecycleState 'DiscoveryRequired' -Components @"
        @{
            AzureDevOpsProject = @{
                Mode = 'Create'
            }
        }
"@)
        { Import-TenantConfiguration -Path $wrongState -ValidationStage Bootstrap -ExpectedPublicTenantKey tenant1 } | Should -Throw

        $validBootstrap = New-TestTenantConfigurationFile -Content (New-TestTenantConfigurationContent -LifecycleState 'IntentReviewed' -Components @"
        @{
            AzureDevOpsProject = @{
                Mode = 'Create'
            }
            PowerPlatformDev = @{
                Mode = 'Existing'
                Id = 'powerplatform-environment-dev'
            }
        }
"@)
        $config = Import-TenantConfiguration -Path $validBootstrap -ValidationStage Bootstrap -ExpectedPublicTenantKey tenant1
        $config.Components.AzureDevOpsProject.Mode | Should -Be 'Create'
        $config.Components.PowerPlatformDev.Id | Should -Be 'powerplatform-environment-dev'
    }

    It 'requires a stable id for every Existing component during bootstrap' {
        $missingId = New-TestTenantConfigurationFile -Content (New-TestTenantConfigurationContent -LifecycleState 'IntentReviewed' -Components @"
        @{
            PowerPlatformDev = @{
                Mode = 'Existing'
                Id = ' '
            }
        }
"@)

        { Import-TenantConfiguration -Path $missingId -ValidationStage Bootstrap -ExpectedPublicTenantKey tenant1 } | Should -Throw
    }

    It 'returns a recursively read-only object graph' {
        $config = Import-TenantConfiguration -Path $script:TenantManifestPath -ValidationStage Discovery -ExpectedPublicTenantKey tenant1
        $bootstrapPath = New-TestTenantConfigurationFile -Content (New-TestTenantConfigurationContent -LifecycleState 'IntentReviewed' -Components @"
        @{
            AzureDevOpsProject = @{
                Mode = 'Create'
            }
            PowerPlatformDev = @{
                Mode = 'Existing'
                Id = 'powerplatform-environment-dev'
            }
        }
"@)
        $bootstrapConfig = Import-TenantConfiguration -Path $bootstrapPath -ValidationStage Bootstrap -ExpectedPublicTenantKey tenant1

        { $config.TenantAlias = 'other' } | Should -Throw
        { $config.AzureDevOps.OrganizationUrl = 'https://example.com/' } | Should -Throw
        { $bootstrapConfig.Components.AzureDevOpsProject = $null } | Should -Throw
        { $bootstrapConfig.Components.PowerPlatformDev.Mode = 'Create' } | Should -Throw
    }
}