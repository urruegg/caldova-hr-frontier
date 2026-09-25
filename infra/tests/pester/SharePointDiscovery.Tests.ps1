Set-StrictMode -Version Latest

Describe 'Tenant 2 SharePoint discovery' {
    BeforeAll {
        $script:RepositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
        $script:ModuleManifestPath = Join-Path $script:RepositoryRoot 'infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1'
        $script:TenantManifestPath = Join-Path $script:RepositoryRoot 'infra\src\config\tenants\caldova25668747.psd1'
        $script:TenantConfiguration = [pscustomobject]@{
            TenantAlias = 'caldova25668747'
            TenantId = '4682b8db-586c-4602-ad98-d29e4018fd5b'
            AdminUpn = 'admin@caldova25668747.onmicrosoft.com'
            SharePoint = [pscustomobject]@{
                DevUrl = 'https://caldova25668747.sharepoint.com/sites/HRFrontierDEV'
                TestUrl = 'https://caldova25668747.sharepoint.com/sites/HRFrontierTEST'
                ProdUrl = 'https://caldova25668747.sharepoint.com/sites/HRFrontier'
            }
        }
        Import-Module $script:ModuleManifestPath -Force
    }

    It 'accepts the reviewed Tenant 2 manifest and SharePoint URLs' {
        $configuration = Import-TenantConfiguration -Path $script:TenantManifestPath -ValidationStage Discovery

        $configuration.TenantAlias | Should -BeExactly 'caldova25668747'
        $configuration.DisplayName | Should -BeExactly 'Caldova25668747'
        $configuration.TenantId | Should -BeExactly '4682b8db-586c-4602-ad98-d29e4018fd5b'
        $configuration.AdminUpn | Should -BeExactly 'admin@caldova25668747.onmicrosoft.com'
        $configuration.SubscriptionId | Should -BeExactly 'c097a50e-bfe0-487f-bffe-22d7695caadd'
        $configuration.PrimaryLocation | Should -BeExactly 'switzerlandnorth'
        $configuration.AzureDevOps.OrganizationUrl | Should -BeExactly 'https://dev.azure.com/Caldova25668747/'
        $configuration.AzureDevOps.ProjectName | Should -BeExactly 'FrontierHR'
        $configuration.PowerPlatform.DevUrl | Should -BeExactly 'https://calhrfrontierdev.crm17.dynamics.com/'
        $configuration.PowerPlatform.TestUrl | Should -BeExactly 'https://calhrfrontiertest.crm17.dynamics.com/'
        $configuration.PowerPlatform.ProdUrl | Should -BeExactly 'https://calhrfrontier.crm17.dynamics.com/'
        $configuration.SharePoint.DevUrl | Should -BeExactly 'https://caldova25668747.sharepoint.com/sites/HRFrontierDEV'
        $configuration.SharePoint.TestUrl | Should -BeExactly 'https://caldova25668747.sharepoint.com/sites/HRFrontierTEST'
        $configuration.SharePoint.ProdUrl | Should -BeExactly 'https://caldova25668747.sharepoint.com/sites/HRFrontier'
        $configuration.GitHub.EnvironmentName | Should -BeExactly 'bootstrap-caldova25668747'
        $configuration.UniqueSuffix | Should -Match '^[a-z0-9]{6}$'
        $configuration.NamingRoot | Should -BeExactly "cal-hr-agentic-$($configuration.UniqueSuffix)"
        $configuration.LifecycleState | Should -BeExactly 'DiscoveryRequired'
        @($configuration.Components | Get-Member -MemberType NoteProperty, Property, ScriptProperty).Count | Should -Be 0
    }

    It 'rejects Tenant 2 SharePoint URLs outside the exact reviewed site set' {
        $content = Get-Content -Raw -LiteralPath $script:TenantManifestPath
        $alteredPath = Join-Path $TestDrive 'altered-tenant2.psd1'
        $alteredContent = $content.Replace(
            'https://caldova25668747.sharepoint.com/sites/HRFrontierDEV',
            'https://caldova25668747.sharepoint.com/sites/OtherDEV'
        )
        [System.IO.File]::WriteAllText($alteredPath, $alteredContent, [System.Text.UTF8Encoding]::new($false))

        { Import-TenantConfiguration -Path $alteredPath -ValidationStage Discovery } |
            Should -Throw '*exact reviewed Tenant 2 sites*'
    }

    It 'rejects Tenant 2 when the reviewed SharePoint block is missing' {
        $content = Get-Content -Raw -LiteralPath $script:TenantManifestPath
        $alteredPath = Join-Path $TestDrive 'tenant2-without-sharepoint.psd1'
        $alteredContent = $content -replace "(?ms)^    SharePoint = @\{\r?\n.*?^    \}\r?\n(?=    Components)", ''
        [System.IO.File]::WriteAllText($alteredPath, $alteredContent, [System.Text.UTF8Encoding]::new($false))

        { Import-TenantConfiguration -Path $alteredPath -ValidationStage Discovery } |
            Should -Throw '*requires the reviewed SharePoint sites*'
    }

    It 'generates a new Tenant 2 discovery manifest from reviewed metadata' {
        $harnessRoot = Join-Path $TestDrive 'tenant-generator'
        $scriptRoot = Join-Path $harnessRoot 'infra\src\scripts'
        $configRoot = Join-Path $harnessRoot 'infra\src\config'
        [System.IO.Directory]::CreateDirectory($scriptRoot) | Out-Null
        [System.IO.Directory]::CreateDirectory((Join-Path $configRoot 'tenants')) | Out-Null
        [System.IO.Directory]::CreateDirectory((Join-Path $configRoot 'schemas')) | Out-Null
        Copy-Item `
            -LiteralPath (Join-Path $script:RepositoryRoot 'infra\src\scripts\New-TenantManifest.ps1') `
            -Destination (Join-Path $scriptRoot 'New-TenantManifest.ps1')
        Copy-Item `
            -LiteralPath (Join-Path $script:RepositoryRoot 'infra\src\scripts\modules') `
            -Destination $scriptRoot `
            -Recurse
        Copy-Item `
            -LiteralPath (Join-Path $script:RepositoryRoot 'infra\src\config\schemas\tenant.schema.json') `
            -Destination (Join-Path $configRoot 'schemas\tenant.schema.json')

        & (Join-Path $scriptRoot 'New-TenantManifest.ps1') -TenantAlias 'caldova25668747' | Out-Null

        $generatedPath = Join-Path $configRoot 'tenants\caldova25668747.psd1'
        $generated = Import-PowerShellDataFile -LiteralPath $generatedPath
        $generated.TenantId | Should -BeExactly '4682b8db-586c-4602-ad98-d29e4018fd5b'
        $generated.AzureDevOps.ProjectName | Should -BeExactly 'FrontierHR'
        $generated.SharePoint.DevUrl | Should -BeExactly 'https://caldova25668747.sharepoint.com/sites/HRFrontierDEV'
        $generated.UniqueSuffix | Should -Match '^[a-z0-9]{6}$'
        $generated.NamingRoot | Should -BeExactly "cal-hr-agentic-$($generated.UniqueSuffix)"

        Get-Module Caldova.HrFrontier.Bootstrap | Remove-Module -Force
        Import-Module $script:ModuleManifestPath -Force
    }

    It 'normalizes exactly the reviewed DEV TEST and PROD sites' {
        $module = Get-Module Caldova.HrFrontier.Bootstrap -ErrorAction Stop
        $runId = [guid]'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'
        $collectedUtc = [datetime]::SpecifyKind([datetime]'2026-09-24T08:00:00', [System.DateTimeKind]::Utc)
        $request = {
            param($Operation, $Arguments)

            if ($Operation -cne 'SiteMetadata') {
                throw "Unexpected operation: $Operation"
            }

            $siteName = ([uri]$Arguments.WebUrl).Segments[-1].TrimEnd('/')
            [pscustomobject]@{
                StatusCode = 200
                Headers = @{}
                Body = [pscustomobject]@{
                    id = "caldova25668747.sharepoint.com,site-$($Arguments.Stage.ToLowerInvariant()),web-$($Arguments.Stage.ToLowerInvariant())"
                    displayName = $siteName
                    name = $siteName
                    webUrl = $Arguments.WebUrl
                }
            }
        }

        $service = & $module {
            param($TenantConfiguration, $RunId, $CollectedUtc, $Request)
            Get-SharePointDiscovery `
                -TenantConfiguration $TenantConfiguration `
                -RunId $RunId `
                -CollectedUtc $CollectedUtc `
                -Request $Request
        } $script:TenantConfiguration $runId $collectedUtc $request

        $service.Name | Should -BeExactly 'SharePoint'
        $service.Status | Should -BeExactly 'Found'
        $service.SourceApi | Should -BeExactly 'Microsoft Graph v1.0'
        $service.Resources.Type | Should -Be @('SharePointSiteDev', 'SharePointSiteTest', 'SharePointSiteProd')
        $service.Resources.Url | Should -Be @(
            $script:TenantConfiguration.SharePoint.DevUrl,
            $script:TenantConfiguration.SharePoint.TestUrl,
            $script:TenantConfiguration.SharePoint.ProdUrl
        )
        @($service.Resources | Where-Object Status -ceq 'Found').Count | Should -Be 3
    }

    It 'queries the exact reviewed site paths in Microsoft Graph' {
        $module = Get-Module Caldova.HrFrontier.Bootstrap -ErrorAction Stop
        $runId = [guid]'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'
        $collectedUtc = [datetime]::SpecifyKind([datetime]'2026-09-24T08:00:00', [System.DateTimeKind]::Utc)
        $graphUrls = [System.Collections.Generic.List[string]]::new()
        $request = {
            param($Operation, $Arguments)

            $graphUrls.Add([string]$Arguments.GraphUrl)
            $siteName = ([uri]$Arguments.WebUrl).Segments[-1].TrimEnd('/')
            [pscustomobject]@{
                StatusCode = 200
                Headers = @{}
                Body = [pscustomobject]@{
                    id = "caldova25668747.sharepoint.com,site-$($Arguments.Stage.ToLowerInvariant()),web-$($Arguments.Stage.ToLowerInvariant())"
                    displayName = $siteName
                    name = $siteName
                    webUrl = $Arguments.WebUrl
                }
            }
        }.GetNewClosure()

        & $module {
            param($TenantConfiguration, $RunId, $CollectedUtc, $Request)
            Get-SharePointDiscovery `
                -TenantConfiguration $TenantConfiguration `
                -RunId $RunId `
                -CollectedUtc $CollectedUtc `
                -Request $Request
        } $script:TenantConfiguration $runId $collectedUtc $request | Out-Null

        $graphUrls | Should -Be @(
            'https://graph.microsoft.com/v1.0/sites/caldova25668747.sharepoint.com:/sites/HRFrontierDEV?$select=id,displayName,name,webUrl'
            'https://graph.microsoft.com/v1.0/sites/caldova25668747.sharepoint.com:/sites/HRFrontierTEST?$select=id,displayName,name,webUrl'
            'https://graph.microsoft.com/v1.0/sites/caldova25668747.sharepoint.com:/sites/HRFrontier?$select=id,displayName,name,webUrl'
        )
    }

    It 'records SharePoint as an optional normalized discovery service' {
        $module = Get-Module Caldova.HrFrontier.Bootstrap -ErrorAction Stop
        $runId = [guid]'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'
        $collectedUtc = [datetime]::SpecifyKind([datetime]'2026-09-24T08:00:00', [System.DateTimeKind]::Utc)
        $serviceResult = [pscustomobject]@{
            Name = 'SharePoint'
            Status = 'Found'
            SourceApi = 'Microsoft Graph v1.0'
            CollectedUtc = $collectedUtc
            Resources = @(
                [pscustomobject]@{
                    Type = 'SharePointSiteDev'
                    Id = 'caldova25668747.sharepoint.com,site-dev,web-dev'
                    Name = 'HRFrontierDEV'
                    Url = $script:TenantConfiguration.SharePoint.DevUrl
                    Scope = 'site:DEV'
                    Status = 'Found'
                }
            )
            RawPayload = [pscustomobject]@{ id = 'caldova25668747.sharepoint.com,site-dev,web-dev' }
        }
        $coreResult = {
            param($Name)
            [pscustomobject]@{
                Name = $Name
                Status = 'Found'
                SourceApi = 'Synthetic API'
                CollectedUtc = $collectedUtc
                Resources = @(
                    [pscustomobject]@{
                        Type = "${Name}Resource"
                        Id = "${Name}-id"
                        Name = "${Name} name"
                        Scope = "${Name}:scope"
                        Status = 'Found'
                    }
                )
                RawPayload = [pscustomobject]@{ id = "${Name}-id" }
            }
        }
        $services = [ordered]@{}
        foreach ($name in @('GitHub', 'Entra', 'Azure', 'AzureDevOps', 'PowerPlatform')) {
            $services[$name] = & $coreResult $name
        }
        $services.SharePoint = $serviceResult
        $principal = [pscustomobject]@{
            Type = 'User'
            Id = 'tenant-admin-object-id'
            Upn = $script:TenantConfiguration.AdminUpn
        }

        $evidence = ConvertTo-DiscoveryEvidence `
            -TenantConfiguration $script:TenantConfiguration `
            -ServiceResults $services `
            -RunId $runId `
            -CollectionStartedUtc $collectedUtc `
            -CollectionCompletedUtc $collectedUtc.AddMinutes(1) `
            -Principal $principal

        $evidence.Services.SharePoint.Name | Should -BeExactly 'SharePoint'
        $evidence.Services.SharePoint.Resources[0].Type | Should -BeExactly 'SharePointSiteDev'
        { Test-DiscoveryEvidence -Evidence $evidence -NowUtc $collectedUtc.AddMinutes(1) } | Should -Not -Throw
    }
}
