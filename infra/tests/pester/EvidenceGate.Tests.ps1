Set-StrictMode -Version Latest

Describe 'Discovery evidence gate' {
    BeforeAll {
        $script:ModuleManifestPath = Join-Path $PSScriptRoot '..\..\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1'
        $script:NowUtc = [datetime]::SpecifyKind([datetime]'2026-09-19T12:00:00', [System.DateTimeKind]::Utc)
        function script:New-ValidEvidence {
            $runId = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'
            $collectedUtc = '2026-09-19T10:15:30.0000000Z'
            $completedUtc = '2026-09-19T10:17:30.0000000Z'
            $hash = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'
            $serviceNames = @('GitHub', 'Entra', 'Azure', 'AzureDevOps', 'PowerPlatform')
            $services = [ordered]@{}
            foreach ($serviceName in $serviceNames) {
                $resourceType = switch ($serviceName) {
                    'GitHub' { 'GitHubRepository' }
                    'Entra' { 'EntraApplication' }
                    'Azure' { 'AzureSubscription' }
                    'AzureDevOps' { 'AzureDevOpsProject' }
                    'PowerPlatform' { 'PowerPlatformEnvironmentDev' }
                }

                $services[$serviceName] = [pscustomobject]@{
                    Name = $serviceName
                    RunId = $runId
                    Status = 'Found'
                    SourceApi = 'Synthetic'
                    CollectedUtc = $collectedUtc
                    ResponseSha256 = $hash
                    Resources = @(
                        [pscustomobject]@{
                            Type = $resourceType
                            Id = "$resourceType-id"
                            Name = "$resourceType name"
                            Status = 'Found'
                            EvidenceReference = [pscustomobject]@{
                                Service = $serviceName
                                SourceApi = 'Synthetic'
                                Scope = 'synthetic'
                                CollectedUtc = $collectedUtc
                                ResponseSha256 = $hash
                            }
                        }
                    )
                }
            }

            [pscustomobject]@{
                SchemaVersion = '1.0'
                ToolVersion = 'test-tool/1.0.0'
                RunId = $runId
                CollectionStartedUtc = $collectedUtc
                CollectionCompletedUtc = $completedUtc
                TenantAlias = 'caldova25156897'
                TenantId = 'e2312862-df63-440c-8bcf-007a2c52859d'
                Principal = [pscustomobject]@{
                    Type = 'User'
                    Id = 'user-synthetic-0001'
                    Upn = 'admin@Caldova25156897.onmicrosoft.com'
                }
                Services = [pscustomobject]$services
            }
        }
        Import-Module $script:ModuleManifestPath -Force
    }

    It 'accepts complete recent evidence with Found and Missing outcomes only' {
        $evidence = New-ValidEvidence
        $evidence.Services.AzureDevOps.Status = 'Missing'
        $evidence.Services.AzureDevOps.Resources = @()

        Test-DiscoveryEvidence -Evidence $evidence -NowUtc $script:NowUtc | Should -BeTrue
    }

    It 'rejects evidence older than 24 hours' {
        $evidence = New-ValidEvidence
        $evidence.CollectionStartedUtc = '2026-09-18T11:59:59.0000000Z'

        { Test-DiscoveryEvidence -Evidence $evidence -NowUtc $script:NowUtc } | Should -Throw
    }

    It 'rejects mixed service run identifiers' {
        $evidence = New-ValidEvidence
        $evidence.Services.PowerPlatform.RunId = 'ffffffff-bbbb-cccc-dddd-eeeeeeeeeeee'

        { Test-DiscoveryEvidence -Evidence $evidence -NowUtc $script:NowUtc } | Should -Throw
    }

    It 'rejects required services with unauthorized unavailable or ambiguous status' {
        foreach ($status in @('Unauthorized', 'Unavailable', 'Ambiguous')) {
            $evidence = New-ValidEvidence
            $evidence.Services.Entra.Status = $status
            if ($status -eq 'Ambiguous') {
                $evidence.Services.Entra.Resources = @(
                    [pscustomobject]@{
                        Type = 'EntraApplication'
                        Id = 'candidate-1'
                        Name = 'candidate one'
                        Status = 'Ambiguous'
                        EvidenceReference = [pscustomobject]@{
                            Service = 'Entra'
                            SourceApi = 'Synthetic'
                            Scope = 'synthetic'
                            CollectedUtc = '2026-09-19T10:15:30.0000000Z'
                            ResponseSha256 = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'
                        }
                    }
                )
            }
            else {
                $evidence.Services.Entra.Resources = @()
            }

            { Test-DiscoveryEvidence -Evidence $evidence -NowUtc $script:NowUtc } | Should -Throw
        }
    }

    It 'accepts committed baseline evidence shape when authorization freshness is skipped for ExistingContext joins' {
        $evidence = New-ValidEvidence
        $evidence.CollectionStartedUtc = '2026-08-01T10:15:30.0000000Z'
        $evidence.CollectionCompletedUtc = '2026-08-01T10:17:30.0000000Z'

        { Test-DiscoveryEvidence -Evidence $evidence -SkipAuthorizationGate } | Should -Not -Throw
    }
}