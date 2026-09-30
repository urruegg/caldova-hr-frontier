Set-StrictMode -Version Latest

Describe 'Discovery evidence security' {
    BeforeAll {
        $script:ModuleManifestPath = Join-Path $PSScriptRoot '..\..\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1'
        $script:FixtureRoot = Join-Path $PSScriptRoot '..\fixtures\discovery'
        $script:RunId = [guid]'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'
        $script:CollectedUtc = [datetime]::SpecifyKind([datetime]'2026-09-19T10:15:30', [System.DateTimeKind]::Utc)
        $script:CompletedUtc = $script:CollectedUtc.AddMinutes(2)
        $script:TenantConfiguration = [pscustomobject]@{
            TenantAlias = 'fixturetenant42'
            TenantId = '22222222-2222-2222-2222-222222222222'
            AdminUpn = 'operator@fixture.example'
            SubscriptionId = '11111111-1111-1111-1111-111111111111'
            GitHub = [pscustomobject]@{
                Owner = 'urruegg'
                OwnerId = '46865858'
                Repository = 'caldova-hr-frontier'
                RepositoryId = '1371297722'
                EnvironmentName = 'bootstrap-fixturetenant42'
            }
            AzureDevOps = [pscustomobject]@{
                OrganizationUrl = 'https://dev.azure.com/synthetic/'
                ProjectName = 'Synthetic HR Frontier'
            }
            PowerPlatform = [pscustomobject]@{
                DevUrl = 'https://fixture-dev.example.test/'
                TestUrl = 'https://fixture-test.example.test/'
                ProdUrl = 'https://fixture-prod.example.test/'
            }
        }
        $script:Principal = [pscustomobject]@{
            Type = 'User'
            Id = 'user-synthetic-0001'
            Upn = 'operator@fixture.example'
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
        $json | Should -Match 'operator@fixture\.example'
    }

    It 'permits the reviewed email only at the exact Principal.Upn path' {
        $evidence = [pscustomobject]@{
            SchemaVersion = '1.0'
            ToolVersion = 'test-tool/1.0.0'
            RunId = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'
            CollectionStartedUtc = '2026-09-19T10:15:30.0000000Z'
            CollectionCompletedUtc = '2026-09-19T10:17:30.0000000Z'
            TenantAlias = 'fixturetenant42'
            TenantId = '22222222-2222-2222-2222-222222222222'
            Principal = [pscustomobject]@{
                Type = 'User'
                Id = 'user-synthetic-0001'
                Upn = 'operator@fixture.example'
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
                            Name = 'operator@fixture.example'
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