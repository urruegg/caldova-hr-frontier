Set-StrictMode -Version Latest

Describe 'Tenant intent gate' {
    BeforeAll {
        $script:ModuleManifestPath = Join-Path $PSScriptRoot '..\..\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1'
        function script:New-ValidEvidence {
            $hash = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'
            [pscustomobject]@{
                SchemaVersion = '1.0'
                ToolVersion = 'test-tool/1.0.0'
                RunId = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'
                CollectionStartedUtc = '2026-09-19T10:15:30.0000000Z'
                CollectionCompletedUtc = '2026-09-19T10:17:30.0000000Z'
                TenantAlias = 'caldova25156897'
                TenantId = 'e2312862-df63-440c-8bcf-007a2c52859d'
                Principal = [pscustomobject]@{
                    Type = 'User'
                    Id = 'user-synthetic-0001'
                    Upn = 'admin@Caldova25156897.onmicrosoft.com'
                }
                Services = [pscustomobject]@{
                    GitHub = [pscustomobject]@{
                        Name = 'GitHub'
                        RunId = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'
                        Status = 'Found'
                        SourceApi = 'GitHub REST v3'
                        CollectedUtc = '2026-09-19T10:15:30.0000000Z'
                        ResponseSha256 = $hash
                        Resources = @(
                            [pscustomobject]@{
                                Type = 'GitHubRepository'
                                Id = 'repo-synthetic-1371297722'
                                Name = 'caldova-hr-frontier'
                                Status = 'Found'
                                EvidenceReference = [pscustomobject]@{ Service = 'GitHub'; SourceApi = 'GitHub REST v3'; Scope = 'repo'; CollectedUtc = '2026-09-19T10:15:30.0000000Z'; ResponseSha256 = $hash }
                            }
                        )
                    }
                    Entra = [pscustomobject]@{
                        Name = 'Entra'
                        RunId = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'
                        Status = 'Found'
                        SourceApi = 'Microsoft Graph v1.0'
                        CollectedUtc = '2026-09-19T10:15:30.0000000Z'
                        ResponseSha256 = $hash
                        Resources = @(
                            [pscustomobject]@{
                                Type = 'EntraApplication'
                                Id = 'app-synthetic-11111111-1111-1111-1111-111111111111'
                                Name = 'Bootstrap app'
                                Status = 'Found'
                                EvidenceReference = [pscustomobject]@{ Service = 'Entra'; SourceApi = 'Microsoft Graph v1.0'; Scope = 'tenant'; CollectedUtc = '2026-09-19T10:15:30.0000000Z'; ResponseSha256 = $hash }
                            }
                        )
                    }
                    Azure = [pscustomobject]@{
                        Name = 'Azure'
                        RunId = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'
                        Status = 'Found'
                        SourceApi = 'Azure Resource Graph + ARM'
                        CollectedUtc = '2026-09-19T10:15:30.0000000Z'
                        ResponseSha256 = $hash
                        Resources = @(
                            [pscustomobject]@{
                                Type = 'AzureSubscription'
                                Id = 'subscription-synthetic-edb45a24-408d-47c4-bbc7-685b9b3fc017'
                                Name = 'Platform subscription'
                                Status = 'Found'
                                EvidenceReference = [pscustomobject]@{ Service = 'Azure'; SourceApi = 'Azure Resource Graph + ARM'; Scope = 'subscription'; CollectedUtc = '2026-09-19T10:15:30.0000000Z'; ResponseSha256 = $hash }
                            }
                        )
                    }
                    AzureDevOps = [pscustomobject]@{
                        Name = 'AzureDevOps'
                        RunId = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'
                        Status = 'Found'
                        SourceApi = 'Azure DevOps REST 7.1'
                        CollectedUtc = '2026-09-19T10:15:30.0000000Z'
                        ResponseSha256 = $hash
                        Resources = @(
                            [pscustomobject]@{
                                Type = 'AzureDevOpsProject'
                                Id = 'ado-project-synthetic-33333333-3333-3333-3333-333333333333'
                                Name = 'Caldova HR Frontier'
                                Status = 'Found'
                                EvidenceReference = [pscustomobject]@{ Service = 'AzureDevOps'; SourceApi = 'Azure DevOps REST 7.1'; Scope = 'organization'; CollectedUtc = '2026-09-19T10:15:30.0000000Z'; ResponseSha256 = $hash }
                            }
                        )
                    }
                    PowerPlatform = [pscustomobject]@{
                        Name = 'PowerPlatform'
                        RunId = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'
                        Status = 'Found'
                        SourceApi = 'Power Platform Admin API'
                        CollectedUtc = '2026-09-19T10:15:30.0000000Z'
                        ResponseSha256 = $hash
                        Resources = @(
                            [pscustomobject]@{
                                Type = 'PowerPlatformEnvironmentDev'
                                Id = 'pp-env-synthetic-dev-44444444-4444-4444-4444-444444444444'
                                Name = 'HR Frontier Dev'
                                Status = 'Found'
                                EvidenceReference = [pscustomobject]@{ Service = 'PowerPlatform'; SourceApi = 'Power Platform Admin API'; Scope = 'environment:DEV'; CollectedUtc = '2026-09-19T10:15:30.0000000Z'; ResponseSha256 = $hash }
                            }
                        )
                    }
                }
            }
        }
        function script:New-TenantConfiguration {
            [pscustomobject]@{
                Components = [pscustomobject]@{
                    GitHubRepository = [pscustomobject]@{ Mode = 'Existing'; Id = 'repo-synthetic-1371297722' }
                    EntraApplication = [pscustomobject]@{ Mode = 'Create' }
                    AzureSubscription = [pscustomobject]@{ Mode = 'Existing'; Id = 'subscription-synthetic-edb45a24-408d-47c4-bbc7-685b9b3fc017' }
                    AzureDevOpsProject = [pscustomobject]@{ Mode = 'Create' }
                    PowerPlatformEnvironmentDev = [pscustomobject]@{ Mode = 'Existing'; Id = 'pp-env-synthetic-dev-44444444-4444-4444-4444-444444444444' }
                }
            }
        }
        Import-Module $script:ModuleManifestPath -Force
    }

    It 'accepts exact stable-id matches for Existing and absence for Create' {
        $tenantConfiguration = New-TenantConfiguration
        $evidence = New-ValidEvidence
        $evidence.Services.Entra.Status = 'Missing'
        $evidence.Services.Entra.Resources = @()
        $evidence.Services.AzureDevOps.Status = 'Missing'
        $evidence.Services.AzureDevOps.Resources = @()

        Test-TenantIntent -TenantConfiguration $tenantConfiguration -Evidence $evidence | Should -BeTrue
    }

    It 'rejects Existing intent when the stable id is absent or different' {
        $tenantConfiguration = New-TenantConfiguration
        $evidence = New-ValidEvidence
        $evidence.Services.GitHub.Resources[0].Id = 'repo-synthetic-mismatch'

        { Test-TenantIntent -TenantConfiguration $tenantConfiguration -Evidence $evidence } | Should -Throw
    }

    It 'rejects Create intent when discovery finds a conflicting object' {
        $tenantConfiguration = New-TenantConfiguration
        $evidence = New-ValidEvidence

        { Test-TenantIntent -TenantConfiguration $tenantConfiguration -Evidence $evidence } | Should -Throw
    }

    It 'rejects ambiguous discovery candidates and invalid intent modes' {
        $tenantConfiguration = New-TenantConfiguration
        $tenantConfiguration.Components.AzureDevOpsProject.Mode = 'Adopt'
        $evidence = New-ValidEvidence
        $evidence.Services.AzureDevOps.Status = 'Ambiguous'
        $evidence.Services.AzureDevOps.Resources[0].Status = 'Ambiguous'

        { Test-TenantIntent -TenantConfiguration $tenantConfiguration -Evidence $evidence } | Should -Throw
    }

    It 'requires the reviewed stable ids emitted from baseline-backed Power Platform joins' {
        $tenantConfiguration = New-TenantConfiguration
        $evidence = New-ValidEvidence
        $evidence.Services.PowerPlatform.Resources[0].Id = 'pp-env-synthetic-dev-rebound'

        { Test-TenantIntent -TenantConfiguration $tenantConfiguration -Evidence $evidence } | Should -Throw
    }
}