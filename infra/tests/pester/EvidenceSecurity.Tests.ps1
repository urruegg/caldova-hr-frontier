Set-StrictMode -Version Latest

Describe 'Discovery evidence security' {
    BeforeAll {
        $script:ModuleManifestPath = Join-Path $PSScriptRoot '..\..\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1'
        $script:FixtureRoot = Join-Path $PSScriptRoot '..\fixtures\discovery'
        $script:RunId = [guid]'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'
        $script:CollectedUtc = [datetime]::SpecifyKind([datetime]'2026-09-19T10:15:30', [System.DateTimeKind]::Utc)
        $script:CompletedUtc = $script:CollectedUtc.AddMinutes(2)
        $script:TenantConfiguration = [pscustomobject]@{
            TenantAlias = 'caldova25156897'
            TenantId = 'e2312862-df63-440c-8bcf-007a2c52859d'
            AdminUpn = 'admin@Caldova25156897.onmicrosoft.com'
            SubscriptionId = 'edb45a24-408d-47c4-bbc7-685b9b3fc017'
            GitHub = [pscustomobject]@{
                Owner = 'urruegg'
                OwnerId = '46865858'
                Repository = 'caldova-hr-frontier'
                RepositoryId = '1371297722'
                EnvironmentName = 'bootstrap-caldova25156897'
            }
            AzureDevOps = [pscustomobject]@{
                OrganizationUrl = 'https://dev.azure.com/caldova25156897/'
                ProjectName = 'Caldova HR Frontier'
            }
            PowerPlatform = [pscustomobject]@{
                DevUrl = 'https://hrfrontierdev.crm17.dynamics.com/'
                TestUrl = 'https://hrfrontiertest.crm17.dynamics.com/'
                ProdUrl = 'https://hrfrontier.crm17.dynamics.com/'
            }
        }
        $script:Principal = [pscustomobject]@{
            Type = 'User'
            Id = 'user-synthetic-0001'
            Upn = 'admin@Caldova25156897.onmicrosoft.com'
        }
        $script:ForbiddenPattern = '(?i)(access[_-]?token|refresh[_-]?token|client[_-]?secret|authorization:\s*bearer|AccountKey=|SharedAccessSignature=|-----BEGIN .*PRIVATE KEY-----|sig=)'
        function script:Get-DiscoveryFixture {
            param([string]$Name)
            Get-Content -Raw -LiteralPath (Join-Path $script:FixtureRoot $Name) | ConvertFrom-Json
        }
        Import-Module $script:ModuleManifestPath -Force
    }

    It 'strips prohibited fields and values from normalized evidence' {
        $fixtures = @{
            GitHub = Get-DiscoveryFixture -Name 'github.json'
            Entra = Get-DiscoveryFixture -Name 'entra.json'
            Azure = Get-DiscoveryFixture -Name 'azure.json'
            AzureDevOps = Get-DiscoveryFixture -Name 'azure-devops.json'
            PowerPlatform = Get-DiscoveryFixture -Name 'power-platform.json'
        }

        $serviceResults = InModuleScope Caldova.HrFrontier.Bootstrap -Parameters @{
            TenantConfiguration = $script:TenantConfiguration
            RunId = $script:RunId
            CollectedUtc = $script:CollectedUtc
            Fixtures = $fixtures
        } {
            param(
                $TenantConfiguration,
                $RunId,
                $CollectedUtc,
                $Fixtures
            )

            @{
                GitHub = Get-GitHubDiscovery -TenantConfiguration $TenantConfiguration -RunId $RunId -CollectedUtc $CollectedUtc -Request { param($Operation, $Arguments) $Fixtures.GitHub }
                Entra = Get-EntraDiscovery -TenantConfiguration $TenantConfiguration -RunId $RunId -CollectedUtc $CollectedUtc -Request { param($Operation, $Arguments) $Fixtures.Entra }
                Azure = Get-AzureDiscovery -TenantConfiguration $TenantConfiguration -RunId $RunId -CollectedUtc $CollectedUtc -Request { param($Operation, $Arguments) $Fixtures.Azure }
                AzureDevOps = Get-AzureDevOpsDiscovery -TenantConfiguration $TenantConfiguration -RunId $RunId -CollectedUtc $CollectedUtc -Request { param($Operation, $Arguments) $Fixtures.AzureDevOps }
                PowerPlatform = Get-PowerPlatformDiscovery -TenantConfiguration $TenantConfiguration -RunId $RunId -CollectedUtc $CollectedUtc -AuthenticationMode Interactive -Request { param($Operation, $Arguments) $Fixtures.PowerPlatform }
            }
        }

        $evidence = ConvertTo-DiscoveryEvidence -TenantConfiguration $script:TenantConfiguration -ServiceResults $serviceResults -RunId $script:RunId -CollectionStartedUtc $script:CollectedUtc -CollectionCompletedUtc $script:CompletedUtc -Principal $script:Principal
        $json = $evidence | ConvertTo-Json -Depth 20 -Compress

        $json | Should -Not -Match $script:ForbiddenPattern
        $json | Should -Not -Match 'outsider@example\.invalid'
        $json | Should -Match 'admin@Caldova25156897\.onmicrosoft\.com'
    }

    It 'permits the reviewed email only at the exact Principal.Upn path' {
        $evidence = [pscustomobject]@{
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
                    ResponseSha256 = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'
                    Resources = @(
                        [pscustomobject]@{
                            Type = 'GitHubRepository'
                            Id = 'repo-synthetic-1371297722'
                            Name = 'admin@Caldova25156897.onmicrosoft.com'
                            Status = 'Found'
                            EvidenceReference = [pscustomobject]@{
                                Service = 'GitHub'
                                SourceApi = 'GitHub REST v3'
                                Scope = 'repo:urruegg/caldova-hr-frontier'
                                CollectedUtc = '2026-09-19T10:15:30.0000000Z'
                                ResponseSha256 = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'
                            }
                        }
                    )
                }
            }
        }

        { Test-DiscoveryEvidence -Evidence $evidence -NowUtc ([datetime]'2026-09-19T12:00:00Z') } | Should -Throw
    }
}