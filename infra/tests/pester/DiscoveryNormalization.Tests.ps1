Set-StrictMode -Version Latest

Describe 'Discovery normalization' {
    BeforeAll {
        $script:RepositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
        $script:DiscoveryEntryPointPath = Join-Path $script:RepositoryRoot 'infra\src\scripts\Invoke-TenantDiscovery.ps1'
        $script:ModuleManifestPath = Join-Path $PSScriptRoot '..\..\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1'
        $script:DiscoverySchemaPath = Join-Path $PSScriptRoot '..\..\src\config\schemas\discovery.schema.json'
        $script:FixtureRoot = Join-Path $PSScriptRoot '..\fixtures\discovery'
        $script:RunId = [guid]'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'
        $script:CollectedUtc = [datetime]::SpecifyKind([datetime]'2026-09-19T10:15:30', [System.DateTimeKind]::Utc)
        $script:CompletedUtc = $script:CollectedUtc.AddMinutes(2)
        $script:Principal = [pscustomobject]@{
            Type = 'User'
            Id = 'user-synthetic-0001'
            Upn = 'admin@Caldova25156897.onmicrosoft.com'
        }
        $script:TenantConfiguration = [pscustomobject]@{
            TenantAlias = 'caldova25156897'
            NamingRoot = 'cal-hr-agentic-bc8rbt'
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
            Components = [pscustomobject]@{
                GitHubRepository = [pscustomobject]@{ Mode = 'Existing'; Id = '1371297722' }
                EntraApplication = [pscustomobject]@{ Mode = 'Existing'; Id = 'app-synthetic-11111111-1111-1111-1111-111111111111' }
                AzureSubscription = [pscustomobject]@{ Mode = 'Existing'; Id = 'subscription-synthetic-edb45a24-408d-47c4-bbc7-685b9b3fc017' }
                AzureDevOpsProject = [pscustomobject]@{ Mode = 'Existing'; Id = 'ado-project-synthetic-33333333-3333-3333-3333-333333333333' }
                PowerPlatformEnvironmentDev = [pscustomobject]@{ Mode = 'Existing'; Id = 'pp-env-synthetic-dev-44444444-4444-4444-4444-444444444444' }
            }
        }
        function script:Get-DiscoveryFixture {
            param(
                [Parameter(Mandatory)]
                [string]$Name
            )

            Get-Content -Raw -LiteralPath (Join-Path $script:FixtureRoot $Name) | ConvertFrom-Json
        }
        function script:Get-ResponseHash {
            param(
                [Parameter(Mandatory)]
                [object]$Body
            )

            $json = $Body | ConvertTo-Json -Depth 20 -Compress
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
            $hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
            -join ($hash | ForEach-Object { $_.ToString('x2') })
        }
        function script:New-BaselineEvidence {
            param(
                [string]$PowerPlatformDevId = 'pp-env-synthetic-dev-44444444-4444-4444-4444-444444444444',
                [string]$PowerPlatformTestId = 'pp-env-synthetic-test-55555555-5555-5555-5555-555555555555',
                [string]$PowerPlatformProdId = 'pp-env-synthetic-prod-66666666-6666-6666-6666-666666666666'
            )

            $runId = $script:RunId.Guid
            $collectedUtc = $script:CollectedUtc.ToString('o')
            $completedUtc = $script:CompletedUtc.ToString('o')
            $hash = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'
            $serviceNames = @('GitHub', 'Entra', 'Azure', 'AzureDevOps', 'PowerPlatform')
            $services = [ordered]@{}
            foreach ($serviceName in $serviceNames) {
                switch ($serviceName) {
                    'GitHub' {
                        $resources = @(
                            [pscustomobject]@{
                                Type = 'GitHubRepository'
                                Id = '1371297722'
                                Name = 'caldova-hr-frontier'
                                Url = 'https://github.com/urruegg/caldova-hr-frontier'
                                Scope = 'repo:urruegg/caldova-hr-frontier'
                                Status = 'Found'
                                EvidenceReference = [pscustomobject]@{ Service = 'GitHub'; SourceApi = 'GitHub REST v3'; Scope = 'repo:urruegg/caldova-hr-frontier'; CollectedUtc = $collectedUtc; ResponseSha256 = $hash }
                            }
                        )
                        $sourceApi = 'GitHub REST v3'
                    }
                    'Entra' {
                        $resources = @(
                            [pscustomobject]@{
                                Type = 'EntraApplication'
                                Id = 'app-synthetic-11111111-1111-1111-1111-111111111111'
                                Name = 'Caldova HR Frontier Bootstrap'
                                Url = 'https://graph.microsoft.com/v1.0/applications/app-synthetic-11111111-1111-1111-1111-111111111111'
                                Scope = 'tenant:e2312862-df63-440c-8bcf-007a2c52859d'
                                Status = 'Found'
                                EvidenceReference = [pscustomobject]@{ Service = 'Entra'; SourceApi = 'Microsoft Graph v1.0'; Scope = 'tenant:e2312862-df63-440c-8bcf-007a2c52859d'; CollectedUtc = $collectedUtc; ResponseSha256 = $hash }
                            }
                        )
                        $sourceApi = 'Microsoft Graph v1.0'
                    }
                    'Azure' {
                        $resources = @(
                            [pscustomobject]@{
                                Type = 'AzureSubscription'
                                Id = 'subscription-synthetic-edb45a24-408d-47c4-bbc7-685b9b3fc017'
                                Name = 'Caldova HR Frontier Platform'
                                Url = 'https://management.azure.com/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017'
                                Scope = '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017'
                                Status = 'Found'
                                EvidenceReference = [pscustomobject]@{ Service = 'Azure'; SourceApi = 'Azure Resource Graph + ARM'; Scope = '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017'; CollectedUtc = $collectedUtc; ResponseSha256 = $hash }
                            }
                        )
                        $sourceApi = 'Azure Resource Graph + ARM'
                    }
                    'AzureDevOps' {
                        $resources = @(
                            [pscustomobject]@{
                                Type = 'AzureDevOpsProject'
                                Id = 'ado-project-synthetic-33333333-3333-3333-3333-333333333333'
                                Name = 'Caldova HR Frontier'
                                Url = 'https://dev.azure.com/caldova25156897/Caldova%20HR%20Frontier'
                                Scope = 'organization:caldova25156897'
                                Status = 'Found'
                                EvidenceReference = [pscustomobject]@{ Service = 'AzureDevOps'; SourceApi = 'Azure DevOps REST 7.1'; Scope = 'organization:caldova25156897'; CollectedUtc = $collectedUtc; ResponseSha256 = $hash }
                            }
                        )
                        $sourceApi = 'Azure DevOps REST 7.1'
                    }
                    'PowerPlatform' {
                        $resources = @(
                            [pscustomobject]@{
                                Type = 'PowerPlatformEnvironmentDev'
                                Id = $PowerPlatformDevId
                                Name = 'HR Frontier Dev'
                                Url = $script:TenantConfiguration.PowerPlatform.DevUrl
                                Scope = 'environment:DEV'
                                Status = 'Found'
                                EvidenceReference = [pscustomobject]@{ Service = 'PowerPlatform'; SourceApi = 'Power Platform Admin API'; Scope = 'environment:DEV'; CollectedUtc = $collectedUtc; ResponseSha256 = $hash }
                            },
                            [pscustomobject]@{
                                Type = 'PowerPlatformEnvironmentTest'
                                Id = $PowerPlatformTestId
                                Name = 'HR Frontier Test'
                                Url = $script:TenantConfiguration.PowerPlatform.TestUrl
                                Scope = 'environment:TEST'
                                Status = 'Found'
                                EvidenceReference = [pscustomobject]@{ Service = 'PowerPlatform'; SourceApi = 'Power Platform Admin API'; Scope = 'environment:TEST'; CollectedUtc = $collectedUtc; ResponseSha256 = $hash }
                            },
                            [pscustomobject]@{
                                Type = 'PowerPlatformEnvironmentProd'
                                Id = $PowerPlatformProdId
                                Name = 'HR Frontier Prod'
                                Url = $script:TenantConfiguration.PowerPlatform.ProdUrl
                                Scope = 'environment:PROD'
                                Status = 'Found'
                                EvidenceReference = [pscustomobject]@{ Service = 'PowerPlatform'; SourceApi = 'Power Platform Admin API'; Scope = 'environment:PROD'; CollectedUtc = $collectedUtc; ResponseSha256 = $hash }
                            }
                        )
                        $sourceApi = 'Power Platform Admin API'
                    }
                }

                $services[$serviceName] = [pscustomobject]@{
                    Name = $serviceName
                    RunId = $runId
                    Status = 'Found'
                    SourceApi = $sourceApi
                    CollectedUtc = $collectedUtc
                    ResponseSha256 = $hash
                    Resources = $resources
                }
            }

            [pscustomobject]@{
                SchemaVersion = '1.0'
                ToolVersion = 'test-tool/1.0.0'
                RunId = $runId
                CollectionStartedUtc = $collectedUtc
                CollectionCompletedUtc = $completedUtc
                TenantAlias = $script:TenantConfiguration.TenantAlias
                TenantId = $script:TenantConfiguration.TenantId
                Principal = [pscustomobject]@{
                    Type = 'ServicePrincipal'
                    Id = 'bootstrap-client-id-0001'
                    ClientId = 'bootstrap-client-id-0001'
                }
                Services = [pscustomobject]$services
            }
        }
        function script:New-ProbeRecords {
            param(
                [string]$DevStatus = 'Found',
                [string]$TestStatus = 'Found',
                [string]$ProdStatus = 'Found'
            )

            @(
                [pscustomobject]@{ Stage = 'DEV'; Url = $script:TenantConfiguration.PowerPlatform.DevUrl; Status = $DevStatus; CollectedUtc = $script:CollectedUtc.ToString('o'); ActionRevision = 'probe-2026-09-19.1' },
                [pscustomobject]@{ Stage = 'TEST'; Url = $script:TenantConfiguration.PowerPlatform.TestUrl; Status = $TestStatus; CollectedUtc = $script:CollectedUtc.ToString('o'); ActionRevision = 'probe-2026-09-19.1' },
                [pscustomobject]@{ Stage = 'PROD'; Url = $script:TenantConfiguration.PowerPlatform.ProdUrl; Status = $ProdStatus; CollectedUtc = $script:CollectedUtc.ToString('o'); ActionRevision = 'probe-2026-09-19.1' }
            )
        }
        function script:Invoke-DiscoveryEntryPointIsolated {
            param(
                [scriptblock]$BeforeRun,
                [hashtable]$Environment = @{},
                [string[]]$ExtraArguments = @()
            )

            $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
            $repoRoot = Join-Path $tempRoot 'repo'
            [System.IO.Directory]::CreateDirectory($repoRoot) | Out-Null
            foreach ($relativePath in @(
                'infra\src\scripts\Invoke-TenantDiscovery.ps1',
                'infra\src\config\schemas\tenant.schema.json',
                'infra\src\config\schemas\discovery.schema.json',
                'infra\src\config\tenants\caldova25156897.psd1',
                'infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1',
                'infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psm1',
                'infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Private',
                'infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Public'
            )) {
                $sourcePath = Join-Path $script:RepositoryRoot $relativePath
                $targetPath = Join-Path $repoRoot $relativePath
                if (Test-Path -LiteralPath $sourcePath -PathType Container) {
                    Copy-Item -LiteralPath $sourcePath -Destination $targetPath -Recurse -Force
                    continue
                }

                $targetDirectory = Split-Path -Parent $targetPath
                if (-not (Test-Path -LiteralPath $targetDirectory)) {
                    [System.IO.Directory]::CreateDirectory($targetDirectory) | Out-Null
                }
                Copy-Item -LiteralPath $sourcePath -Destination $targetPath -Force
            }

            $evidenceDirectory = Join-Path $repoRoot 'infra\evidence\discovery'
            [System.IO.Directory]::CreateDirectory($evidenceDirectory) | Out-Null
            $runnerTemp = Join-Path $tempRoot 'runner-temp'
            [System.IO.Directory]::CreateDirectory($runnerTemp) | Out-Null
            $outputPath = Join-Path $runnerTemp 'discovery-output.json'
            $probePath = Join-Path $runnerTemp 'power-platform-probe.json'
            $nativeLogPath = Join-Path $runnerTemp 'native-log.json'
            $contextAccountPath = Join-Path $runnerTemp 'account.json'
            $moduleDir = Join-Path $repoRoot 'infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap'

            if ($BeforeRun) {
                & $BeforeRun $repoRoot $probePath $outputPath $nativeLogPath
            }

            $injectedSource = @"
Set-StrictMode -Version Latest
`$script:NativeCallLogPath = '$($nativeLogPath.Replace("'", "''"))'
function Invoke-DiscoveryNativeCommand {
    param(
        [Parameter(Mandatory)]
        [string]`$FilePath,
        [Parameter(Mandatory)]
        [string[]]`$ArgumentList
    )

    if (-not (Test-Path -LiteralPath `$script:NativeCallLogPath)) {
        [System.IO.File]::WriteAllText(`$script:NativeCallLogPath, '[]', [System.Text.UTF8Encoding]::new(`$false))
    }

    `$existing = Get-Content -Raw -LiteralPath `$script:NativeCallLogPath | ConvertFrom-Json
    `$entry = [pscustomobject]@{ FilePath = `$FilePath; ArgumentList = @(`$ArgumentList) }
    `$updated = @(`$existing) + @(`$entry)
    [System.IO.File]::WriteAllText(`$script:NativeCallLogPath, (`$updated | ConvertTo-Json -Depth 10 -Compress), [System.Text.UTF8Encoding]::new(`$false))

    switch (`$FilePath) {
        default {
            throw 'Unexpected native command invocation in isolated ExistingContext test.'
        }
    }
}

function Get-GitHubDiscovery {
    param([object]`$TenantConfiguration,[guid]`$RunId,[datetime]`$CollectedUtc)
    [pscustomobject]@{ Name = 'GitHub'; Status = 'Missing'; SourceApi = 'GitHub REST v3'; CollectedUtc = `$CollectedUtc; Resources = @(); RawPayload = [pscustomobject]@{ marker = 'GitHub' } }
}

function Get-EntraDiscovery {
    param([object]`$TenantConfiguration,[guid]`$RunId,[datetime]`$CollectedUtc)
    [pscustomobject]@{ Name = 'Entra'; Status = 'Missing'; SourceApi = 'Microsoft Graph v1.0'; CollectedUtc = `$CollectedUtc; Resources = @(); RawPayload = [pscustomobject]@{ marker = 'Entra' } }
}

function Get-AzureDiscovery {
    param([object]`$TenantConfiguration,[guid]`$RunId,[datetime]`$CollectedUtc)
    [pscustomobject]@{ Name = 'Azure'; Status = 'Missing'; SourceApi = 'Azure Resource Graph + ARM'; CollectedUtc = `$CollectedUtc; Resources = @(); RawPayload = [pscustomobject]@{ marker = 'Azure' } }
}

function Get-AzureDevOpsDiscovery {
    param([object]`$TenantConfiguration,[guid]`$RunId,[datetime]`$CollectedUtc)
    [pscustomobject]@{ Name = 'AzureDevOps'; Status = 'Missing'; SourceApi = 'Azure DevOps REST 7.1'; CollectedUtc = `$CollectedUtc; Resources = @(); RawPayload = [pscustomobject]@{ marker = 'AzureDevOps' } }
}
"@
            [System.IO.File]::WriteAllText((Join-Path $moduleDir 'Private\zzz-TestOverrides.ps1'), $injectedSource, [System.Text.UTF8Encoding]::new($false))

            $argumentList = @(
                '-NoProfile',
                '-ExecutionPolicy', 'Bypass',
                '-File', (Join-Path $repoRoot 'infra\src\scripts\Invoke-TenantDiscovery.ps1'),
                '-TenantAlias', 'caldova25156897',
                '-AuthenticationMode', 'ExistingContext',
                '-PowerPlatformProbePath', $probePath,
                '-ContextAccountPath', $contextAccountPath
            )
            if ($ExtraArguments -notcontains '-OutputPath') {
                $argumentList += @('-OutputPath', $outputPath)
            }
            $argumentList += $ExtraArguments

            $envBackup = @{}
            foreach ($entry in $Environment.GetEnumerator()) {
                $envBackup[$entry.Key] = [Environment]::GetEnvironmentVariable($entry.Key, 'Process')
                [Environment]::SetEnvironmentVariable($entry.Key, [string]$entry.Value, 'Process')
            }

            try {
                $stdoutFile = Join-Path $runnerTemp 'stdout.txt'
                $stderrFile = Join-Path $runnerTemp 'stderr.txt'
                $process = Start-Process -FilePath 'powershell.exe' -ArgumentList $argumentList -WorkingDirectory $repoRoot -RedirectStandardOutput $stdoutFile -RedirectStandardError $stderrFile -PassThru -Wait
                [pscustomobject]@{
                    ExitCode = $process.ExitCode
                    StdOut = if (Test-Path -LiteralPath $stdoutFile) { [System.IO.File]::ReadAllText($stdoutFile) } else { '' }
                    StdErr = if (Test-Path -LiteralPath $stderrFile) { [System.IO.File]::ReadAllText($stderrFile) } else { '' }
                    OutputPath = $outputPath
                    ProbePath = $probePath
                    BaselinePath = Join-Path $repoRoot 'infra\evidence\discovery\caldova25156897.json'
                    NativeLogPath = $nativeLogPath
                    ContextAccountPath = $contextAccountPath
                    RepositoryRoot = $repoRoot
                }
            }
            finally {
                foreach ($entry in $Environment.GetEnumerator()) {
                    [Environment]::SetEnvironmentVariable($entry.Key, $envBackup[$entry.Key], 'Process')
                }
            }
        }
        Import-Module $script:ModuleManifestPath -Force
    }

    It 'requires the closed discovery schema file' {
        Test-Path -LiteralPath $script:DiscoverySchemaPath | Should -BeTrue
    }

    It 'normalizes all five discovery services into the canonical allowlisted graph' {
        $githubFixture = Get-DiscoveryFixture -Name 'github.json'
        $entraFixture = Get-DiscoveryFixture -Name 'entra.json'
        $azureFixture = Get-DiscoveryFixture -Name 'azure.json'
        $azureDevOpsFixture = Get-DiscoveryFixture -Name 'azure-devops.json'
        $powerPlatformFixture = Get-DiscoveryFixture -Name 'power-platform.json'

        $serviceResults = InModuleScope Caldova.HrFrontier.Bootstrap -Parameters @{
            TenantConfiguration = $script:TenantConfiguration
            RunId = $script:RunId
            CollectedUtc = $script:CollectedUtc
            GitHubFixture = $githubFixture
            EntraFixture = $entraFixture
            AzureFixture = $azureFixture
            AzureDevOpsFixture = $azureDevOpsFixture
            PowerPlatformFixture = $powerPlatformFixture
        } {
            param(
                $TenantConfiguration,
                $RunId,
                $CollectedUtc,
                $GitHubFixture,
                $EntraFixture,
                $AzureFixture,
                $AzureDevOpsFixture,
                $PowerPlatformFixture
            )

            @{
                GitHub = Get-GitHubDiscovery -TenantConfiguration $TenantConfiguration -RunId $RunId -CollectedUtc $CollectedUtc -Request {
                    param($Operation, $Arguments)
                    $GitHubFixture
                }
                Entra = Get-EntraDiscovery -TenantConfiguration $TenantConfiguration -RunId $RunId -CollectedUtc $CollectedUtc -Request {
                    param($Operation, $Arguments)
                    $EntraFixture
                }
                Azure = Get-AzureDiscovery -TenantConfiguration $TenantConfiguration -RunId $RunId -CollectedUtc $CollectedUtc -Request {
                    param($Operation, $Arguments)
                    $AzureFixture
                }
                AzureDevOps = Get-AzureDevOpsDiscovery -TenantConfiguration $TenantConfiguration -RunId $RunId -CollectedUtc $CollectedUtc -Request {
                    param($Operation, $Arguments)
                    $AzureDevOpsFixture
                }
                PowerPlatform = Get-PowerPlatformDiscovery -TenantConfiguration $TenantConfiguration -RunId $RunId -CollectedUtc $CollectedUtc -AuthenticationMode Interactive -Request {
                    param($Operation, $Arguments)
                    $PowerPlatformFixture
                }
            }
        }

        $evidence = ConvertTo-DiscoveryEvidence `
            -TenantConfiguration $script:TenantConfiguration `
            -ServiceResults $serviceResults `
            -RunId $script:RunId `
            -CollectionStartedUtc $script:CollectedUtc `
            -CollectionCompletedUtc $script:CompletedUtc `
            -Principal $script:Principal `
            -ToolVersion 'test-tool/1.0.0'

        $evidence.SchemaVersion | Should -Be '1.0'
        $evidence.ToolVersion | Should -Be 'test-tool/1.0.0'
        $evidence.RunId | Should -Be $script:RunId.Guid
        $evidence.CollectionStartedUtc | Should -Be $script:CollectedUtc.ToString('o')
        $evidence.CollectionCompletedUtc | Should -Be $script:CompletedUtc.ToString('o')
        $evidence.TenantAlias | Should -Be 'caldova25156897'
        $evidence.TenantId | Should -Be 'e2312862-df63-440c-8bcf-007a2c52859d'
        $evidence.Principal.Type | Should -Be 'User'
        $evidence.Principal.Upn | Should -Be 'admin@Caldova25156897.onmicrosoft.com'

        $serviceNames = @($evidence.Services.PSObject.Properties.Name)
        $serviceNames | Should -Be @('GitHub', 'Entra', 'Azure', 'AzureDevOps', 'PowerPlatform')

        foreach ($service in $evidence.Services.PSObject.Properties) {
            $service.Value.Name | Should -Be $service.Name
            $service.Value.RunId | Should -Be $script:RunId.Guid
            $service.Value.Status | Should -Be 'Found'
            $service.Value.CollectedUtc | Should -Be $script:CollectedUtc.ToString('o')
            $service.Value.ResponseSha256 | Should -Match '^[a-f0-9]{64}$'
            if ($service.Name -ceq 'Entra') {
                $service.Value.Resources.Count | Should -Be 2
            }
            elseif ($service.Name -ceq 'PowerPlatform') {
                $service.Value.Resources.Count | Should -Be 3
            }
            else {
                $service.Value.Resources.Count | Should -Be 1
            }
            $service.Value.Resources[0].Type | Should -Match '^[A-Za-z][A-Za-z0-9]*$'
            $service.Value.Resources[0].EvidenceReference.Service | Should -Be $service.Name
            $service.Value.Resources[0].EvidenceReference.CollectedUtc | Should -Be $script:CollectedUtc.ToString('o')
            $service.Value.Resources[0].EvidenceReference.ResponseSha256 | Should -Be $service.Value.ResponseSha256
        }

        $evidence.Services.GitHub.SourceApi | Should -Be 'GitHub REST v3'
        $evidence.Services.GitHub.ResponseSha256 | Should -Be (Get-ResponseHash -Body $githubFixture.Body)
        $evidence.Services.GitHub.Resources[0].Id | Should -Be '1371297722'

        $evidence.Services.Entra.SourceApi | Should -Be 'Microsoft Graph v1.0'
        $evidence.Services.Entra.ResponseSha256 | Should -Be (Get-ResponseHash -Body $entraFixture.Body)
        $evidence.Services.Entra.Resources[0].Id | Should -Be 'app-synthetic-11111111-1111-1111-1111-111111111111'
        $evidence.Services.Entra.Resources[1].Id | Should -Be 'spn-synthetic-22222222-2222-2222-2222-222222222222'

        $evidence.Services.Azure.SourceApi | Should -Be 'Azure Resource Graph + ARM'
        $evidence.Services.Azure.ResponseSha256 | Should -Be (Get-ResponseHash -Body $azureFixture.Body)
        $evidence.Services.Azure.Resources[0].Id | Should -Be 'subscription-synthetic-edb45a24-408d-47c4-bbc7-685b9b3fc017'

        $evidence.Services.AzureDevOps.SourceApi | Should -Be 'Azure DevOps REST 7.1'
        $evidence.Services.AzureDevOps.ResponseSha256 | Should -Be (Get-ResponseHash -Body $azureDevOpsFixture.Body)
        $evidence.Services.AzureDevOps.Resources[0].Id | Should -Be 'ado-project-synthetic-33333333-3333-3333-3333-333333333333'

        $evidence.Services.PowerPlatform.SourceApi | Should -Be 'Power Platform Admin API'
        $evidence.Services.PowerPlatform.ResponseSha256 | Should -Be (Get-ResponseHash -Body $powerPlatformFixture.Body)
        $evidence.Services.PowerPlatform.Resources[0].Id | Should -Be 'pp-env-synthetic-dev-44444444-4444-4444-4444-444444444444'
        $evidence.Services.PowerPlatform.Resources[1].Id | Should -Be 'pp-env-synthetic-test-55555555-5555-5555-5555-555555555555'
        $evidence.Services.PowerPlatform.Resources[2].Id | Should -Be 'pp-env-synthetic-prod-66666666-6666-6666-6666-666666666666'
    }

    It 'retries only retryable discovery adapter failures with bounded attempts' {
        InModuleScope Caldova.HrFrontier.Bootstrap {
            $attempts = 0
            $slept = @()

            $result = Invoke-BoundedRetry -Request {
                param($Operation, $Arguments)
                $script:attempts++
                if ($script:attempts -eq 1) {
                    return [pscustomobject]@{
                        StatusCode = 429
                        Headers = @{ 'Retry-After' = '3' }
                        Body = @{ message = 'retry later' }
                    }
                }

                [pscustomobject]@{
                    StatusCode = 200
                    Headers = @{}
                    Body = @{ ok = $true }
                }
            } -Operation 'Repository' -Arguments @{ Name = 'value' } -Sleeper {
                param($DelaySeconds)
                $script:slept += $DelaySeconds
            }

            $result.StatusCode | Should -Be 200
            $script:attempts | Should -Be 2
            $script:slept | Should -Be @(3)
        }
    }

    It 'normalizes a missing GitHub API resource from the included HTTP response' {
        $result = InModuleScope Caldova.HrFrontier.Bootstrap {
            $script:CapturedGitHubArguments = @()
            $previousExitCode = $global:LASTEXITCODE
            function script:gh {
                $script:CapturedGitHubArguments = @($args)
                $global:LASTEXITCODE = 1
                @(
                    'HTTP/2.0 404 Not Found',
                    'Content-Type: application/json; charset=utf-8',
                    '',
                    '{"message":"Not Found","status":"404"}'
                )
            }

            try {
                $response = Invoke-DiscoveryNativeCommand -FilePath 'gh' -ArgumentList @('api', 'repos/urruegg/caldova-hr-frontier/environments/bootstrap-caldova25156897')
                [pscustomobject]@{
                    Response = $response
                    Arguments = @($script:CapturedGitHubArguments)
                }
            }
            finally {
                Remove-Item -Path Function:\gh -ErrorAction SilentlyContinue
                $global:LASTEXITCODE = $previousExitCode
            }
        }

        $result.Response.StatusCode | Should -Be 404
        $result.Response.Body.message | Should -Be 'Not Found'
        $result.Arguments | Should -Contain '--include'
    }

    It 'preserves Retry-After from a throttled GitHub API response' {
        $response = InModuleScope Caldova.HrFrontier.Bootstrap {
            $previousExitCode = $global:LASTEXITCODE
            function script:gh {
                $global:LASTEXITCODE = 1
                @(
                    'HTTP/2.0 429 Too Many Requests',
                    'Content-Type: application/json; charset=utf-8',
                    'Retry-After: 7',
                    '',
                    '{"message":"API rate limit exceeded","status":"429"}'
                )
            }

            try {
                Invoke-DiscoveryNativeCommand -FilePath 'gh' -ArgumentList @('api', 'repos/urruegg/caldova-hr-frontier')
            }
            finally {
                Remove-Item -Path Function:\gh -ErrorAction SilentlyContinue
                $global:LASTEXITCODE = $previousExitCode
            }
        }

        $response.StatusCode | Should -Be 429
        $response.Headers['Retry-After'] | Should -Be '7'
    }

    It 'marks GitHub discovery Missing when the bootstrap Environment does not exist' {
        $result = InModuleScope Caldova.HrFrontier.Bootstrap -Parameters @{
            TenantConfiguration = $script:TenantConfiguration
            RunId = $script:RunId
            CollectedUtc = $script:CollectedUtc
        } {
            param($TenantConfiguration, $RunId, $CollectedUtc)

            $script:CapturedCalls = @()
            $originalNativeCommand = ${function:Invoke-DiscoveryNativeCommand}
            function script:Invoke-DiscoveryNativeCommand {
                param(
                    [string]$FilePath,
                    [string[]]$ArgumentList
                )

                $script:CapturedCalls += [string]$ArgumentList[1]
                switch ([string]$ArgumentList[1]) {
                    'repos/urruegg/caldova-hr-frontier' {
                        return [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = [pscustomobject]@{ id = 1371297722; name = 'caldova-hr-frontier'; html_url = 'https://github.com/urruegg/caldova-hr-frontier'; owner = [pscustomobject]@{ id = 46865858 } } }
                    }
                    'repos/urruegg/caldova-hr-frontier/actions/oidc/customization/sub' {
                        return [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = [pscustomobject]@{ use_default = $false; use_immutable_subject = $true; sub_claim_prefix = 'repo:urruegg@46865858/caldova-hr-frontier@1371297722:environment:bootstrap-caldova25156897' } }
                    }
                    'repos/urruegg/caldova-hr-frontier/rulesets' {
                        return [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = @() }
                    }
                    'repos/urruegg/caldova-hr-frontier/environments/bootstrap-caldova25156897' {
                        return [pscustomobject]@{ StatusCode = 404; Headers = @{}; Body = [pscustomobject]@{ message = 'Not Found' } }
                    }
                    default {
                        throw "Unexpected GitHub discovery call: $($ArgumentList[1])"
                    }
                }
            }

            try {
                $bundle = Invoke-GitHubDiscoveryRequest -Operation 'DiscoveryBundle' -Arguments ([ordered]@{
                    Owner = 'urruegg'
                    Repository = 'caldova-hr-frontier'
                    EnvironmentName = 'bootstrap-caldova25156897'
                })
                $service = Get-GitHubDiscovery -TenantConfiguration $TenantConfiguration -RunId $RunId -CollectedUtc $CollectedUtc -Request {
                    param($Operation, $Arguments)
                    $bundle
                }

                [pscustomobject]@{
                    Response = $bundle
                    Service = $service
                    Calls = @($script:CapturedCalls)
                }
            }
            finally {
                Set-Item -Path Function:\script:Invoke-DiscoveryNativeCommand -Value $originalNativeCommand
            }
        }

        $result.Response.StatusCode | Should -Be 404
        $result.Service.Status | Should -Be 'Missing'
        $result.Calls | Should -Be @(
            'repos/urruegg/caldova-hr-frontier',
            'repos/urruegg/caldova-hr-frontier/actions/oidc/customization/sub',
            'repos/urruegg/caldova-hr-frontier/rulesets',
            'repos/urruegg/caldova-hr-frontier/environments/bootstrap-caldova25156897'
        )
    }

    It 'default Entra production request bundle fetches applications, service principals, and federated identity credentials' {
        $result = InModuleScope Caldova.HrFrontier.Bootstrap -Parameters @{
            TenantConfiguration = $script:TenantConfiguration
            RunId = $script:RunId
            CollectedUtc = $script:CollectedUtc
        } {
            param($TenantConfiguration, $RunId, $CollectedUtc)

            $script:CapturedCalls = @()
            function script:Invoke-DiscoveryNativeCommand {
                param(
                    [Parameter(Mandatory)]
                    [string]$FilePath,

                    [Parameter(Mandatory)]
                    [string[]]$ArgumentList
                )

                $script:CapturedCalls += [pscustomobject]@{
                    FilePath = $FilePath
                    ArgumentList = @($ArgumentList)
                }

                $urlIndex = [Array]::IndexOf($ArgumentList, '--url')
                if ($urlIndex -lt 0) {
                    throw 'Expected --url argument.'
                }

                $url = [string]$ArgumentList[$urlIndex + 1]
                switch -Wildcard ($url) {
                    'https://graph.microsoft.com/v1.0/applications*' {
                        return [pscustomobject]@{
                            StatusCode = 200
                            Headers = @{}
                            Body = [pscustomobject]@{
                                value = @(
                                    [pscustomobject]@{
                                        id = 'app-synthetic-11111111-1111-1111-1111-111111111111'
                                        appId = 'client-synthetic-11111111-1111-1111-1111-111111111111'
                                        displayName = 'Caldova HR Frontier Bootstrap'
                                    }
                                )
                            }
                        }
                    }
                    'https://graph.microsoft.com/v1.0/servicePrincipals*' {
                        return [pscustomobject]@{
                            StatusCode = 200
                            Headers = @{}
                            Body = [pscustomobject]@{
                                value = @(
                                    [pscustomobject]@{
                                        id = 'spn-synthetic-22222222-2222-2222-2222-222222222222'
                                        appId = 'client-synthetic-11111111-1111-1111-1111-111111111111'
                                        displayName = 'Caldova HR Frontier Bootstrap'
                                    }
                                )
                            }
                        }
                    }
                    'https://graph.microsoft.com/v1.0/applications/app-synthetic-11111111-1111-1111-1111-111111111111/federatedIdentityCredentials*' {
                        return [pscustomobject]@{
                            StatusCode = 200
                            Headers = @{}
                            Body = [pscustomobject]@{
                                value = @(
                                    [pscustomobject]@{
                                        id = 'fic-synthetic-77777777-7777-7777-7777-777777777777'
                                        name = 'bootstrap-caldova25156897'
                                    }
                                )
                            }
                        }
                    }
                    default {
                        throw "Unexpected Entra URL: $url"
                    }
                }
            }

            $bundle = Invoke-EntraDiscoveryRequest -Operation 'DiscoveryBundle' -Arguments @{ TenantId = [string]$TenantConfiguration.TenantId; TenantConfiguration = $TenantConfiguration }
            $service = Get-EntraDiscovery -TenantConfiguration $TenantConfiguration -RunId $RunId -CollectedUtc $CollectedUtc -Request {
                param($Operation, $Arguments)
                $bundle
            }

            [pscustomobject]@{
                Calls = @($script:CapturedCalls)
                Bundle = $bundle
                Service = $service
            }
        }

        $result.Bundle.StatusCode | Should -Be 200
        $result.Calls.Count | Should -Be 3
        $urls = @($result.Calls | ForEach-Object { $_.ArgumentList[[Array]::IndexOf($_.ArgumentList, '--url') + 1] })
        ($urls | Where-Object { $_ -like 'https://graph.microsoft.com/v1.0/applications*' }).Count | Should -Be 2
        ($urls | Where-Object { $_ -like 'https://graph.microsoft.com/v1.0/servicePrincipals*' }).Count | Should -Be 1
        $urls | Should -Contain 'https://graph.microsoft.com/v1.0/applications/app-synthetic-11111111-1111-1111-1111-111111111111/federatedIdentityCredentials'
        $result.Service.Status | Should -Be 'Found'
        $result.Service.Resources.Type | Should -Contain 'EntraFederatedIdentityCredential'
    }

    It 'default Entra production request bundle queries Graph by reviewed IDs in Existing mode' {
        $tenantConfiguration = $script:TenantConfiguration.PSObject.Copy()
        $tenantConfiguration.Components = [pscustomobject]@{
            EntraApplication = [pscustomobject]@{ Mode = 'Existing'; Id = 'app-synthetic-11111111-1111-1111-1111-111111111111' }
            EntraServicePrincipal = [pscustomobject]@{ Mode = 'Existing'; Id = 'spn-synthetic-22222222-2222-2222-2222-222222222222' }
        }

        $result = InModuleScope Caldova.HrFrontier.Bootstrap -Parameters @{
            TenantConfiguration = $tenantConfiguration
        } {
            param($TenantConfiguration)

            $script:CapturedCalls = @()
            function script:Invoke-DiscoveryNativeCommand {
                param(
                    [Parameter(Mandatory)]
                    [string]$FilePath,

                    [Parameter(Mandatory)]
                    [string[]]$ArgumentList
                )

                $script:CapturedCalls += [pscustomobject]@{
                    FilePath = $FilePath
                    ArgumentList = @($ArgumentList)
                }

                $urlIndex = [Array]::IndexOf($ArgumentList, '--url')
                if ($urlIndex -lt 0) {
                    throw 'Expected --url argument.'
                }

                $url = [string]$ArgumentList[$urlIndex + 1]
                switch ($url) {
                    'https://graph.microsoft.com/v1.0/applications/app-synthetic-11111111-1111-1111-1111-111111111111' {
                        return [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = [pscustomobject]@{ id = 'app-synthetic-11111111-1111-1111-1111-111111111111'; appId = 'client-synthetic-11111111-1111-1111-1111-111111111111'; displayName = 'Caldova HR Frontier Bootstrap' } }
                    }
                    'https://graph.microsoft.com/v1.0/servicePrincipals/spn-synthetic-22222222-2222-2222-2222-222222222222' {
                        return [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = [pscustomobject]@{ id = 'spn-synthetic-22222222-2222-2222-2222-222222222222'; appId = 'client-synthetic-11111111-1111-1111-1111-111111111111'; displayName = 'Caldova HR Frontier Bootstrap' } }
                    }
                    'https://graph.microsoft.com/v1.0/applications/app-synthetic-11111111-1111-1111-1111-111111111111/federatedIdentityCredentials' {
                        return [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = [pscustomobject]@{ value = @([pscustomobject]@{ id = 'fic-synthetic-77777777-7777-7777-7777-777777777777'; name = 'bootstrap-caldova25156897' }) } }
                    }
                    default {
                        throw "Unexpected Entra URL: $url"
                    }
                }
            }

            Invoke-EntraDiscoveryRequest -Operation 'DiscoveryBundle' -Arguments @{ TenantId = [string]$TenantConfiguration.TenantId; TenantConfiguration = $TenantConfiguration } | Out-Null
            @($script:CapturedCalls | ForEach-Object { $_.ArgumentList[[Array]::IndexOf($_.ArgumentList, '--url') + 1] })
        }

        $result | Should -Be @(
            'https://graph.microsoft.com/v1.0/applications/app-synthetic-11111111-1111-1111-1111-111111111111',
            'https://graph.microsoft.com/v1.0/servicePrincipals/spn-synthetic-22222222-2222-2222-2222-222222222222',
            'https://graph.microsoft.com/v1.0/applications/app-synthetic-11111111-1111-1111-1111-111111111111/federatedIdentityCredentials'
        )
    }

    It 'default Entra production request bundle uses the derived bootstrap display name during initial discovery' {
        $tenantConfiguration = $script:TenantConfiguration.PSObject.Copy()
        $tenantConfiguration.NamingRoot = 'cal-hr-agentic-bc8rbt'
        $tenantConfiguration.Components = [pscustomobject]@{}

        $result = InModuleScope Caldova.HrFrontier.Bootstrap -Parameters @{
            TenantConfiguration = $tenantConfiguration
        } {
            param($TenantConfiguration)

            $script:CapturedCalls = @()
            function script:Invoke-DiscoveryNativeCommand {
                param(
                    [Parameter(Mandatory)]
                    [string]$FilePath,

                    [Parameter(Mandatory)]
                    [string[]]$ArgumentList
                )

                $script:CapturedCalls += [pscustomobject]@{
                    FilePath = $FilePath
                    ArgumentList = @($ArgumentList)
                }

                [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = [pscustomobject]@{ value = @() } }
            }

            Invoke-EntraDiscoveryRequest -Operation 'DiscoveryBundle' -Arguments @{ TenantId = [string]$TenantConfiguration.TenantId; TenantConfiguration = $TenantConfiguration } | Out-Null
            @($script:CapturedCalls | ForEach-Object { $_.ArgumentList[[Array]::IndexOf($_.ArgumentList, '--url') + 1] })
        }

        $result.Count | Should -Be 1
        foreach ($url in $result) {
            $url | Should -Match "displayName%20eq%20'?cal-hr-agentic-bc8rbt-github-bootstrap'?$"
        }
    }

    It 'default Azure production request bundle fetches subscription identity, resources, role assignments, policy assignments, diagnostic settings, and provider state' {
        $result = InModuleScope Caldova.HrFrontier.Bootstrap -Parameters @{
            TenantConfiguration = $script:TenantConfiguration
            RunId = $script:RunId
            CollectedUtc = $script:CollectedUtc
        } {
            param($TenantConfiguration, $RunId, $CollectedUtc)

            $script:CapturedCalls = @()
            function script:Invoke-DiscoveryNativeCommand {
                param(
                    [Parameter(Mandatory)]
                    [string]$FilePath,

                    [Parameter(Mandatory)]
                    [string[]]$ArgumentList
                )

                $script:CapturedCalls += [pscustomobject]@{
                    FilePath = $FilePath
                    ArgumentList = @($ArgumentList)
                }

                $signature = ($ArgumentList -join ' ')
                switch -Wildcard ($signature) {
                    'account show*' {
                        return [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = [pscustomobject]@{ id = 'subscription-synthetic-edb45a24-408d-47c4-bbc7-685b9b3fc017'; name = 'Caldova HR Frontier Platform'; tenantId = $TenantConfiguration.TenantId; user = [pscustomobject]@{ type = 'servicePrincipal'; name = 'bootstrap-client-id-0001' } } }
                    }
                    'graph query*' {
                        return [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = @([pscustomobject]@{ id = '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/resourceGroups/rg-bootstrap/providers/Microsoft.ManagedIdentity/userAssignedIdentities/bootstrap'; name = 'bootstrap'; type = 'Microsoft.ManagedIdentity/userAssignedIdentities' }) }
                    }
                    'role assignment list*' {
                        return [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = @([pscustomobject]@{ id = 'role-assignment-synthetic-1'; scope = '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017'; roleDefinitionId = 'role-definition-synthetic-owner' }) }
                    }
                    'policy assignment list*' {
                        return [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = @([pscustomobject]@{ id = 'policy-assignment-synthetic-1'; name = 'bootstrap-policy' }) }
                    }
                    'monitor diagnostic-settings subscription list*' {
                        return [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = @([pscustomobject]@{ id = 'diagnostic-setting-synthetic-1'; name = 'bootstrap-diagnostics' }) }
                    }
                    'provider show*' {
                        return [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = [pscustomobject]@{ namespace = 'Microsoft.Authorization'; registrationState = 'Registered' } }
                    }
                    default {
                        throw "Unexpected Azure arguments: $signature"
                    }
                }
            }

            $bundle = Invoke-AzureDiscoveryRequest -Operation 'DiscoveryBundle' -Arguments @{ SubscriptionId = [string]$TenantConfiguration.SubscriptionId }
            $service = Get-AzureDiscovery -TenantConfiguration $TenantConfiguration -RunId $RunId -CollectedUtc $CollectedUtc -Request {
                param($Operation, $Arguments)
                $bundle
            }

            [pscustomobject]@{
                Calls = @($script:CapturedCalls)
                Bundle = $bundle
                Service = $service
            }
        }

        $result.Bundle.StatusCode | Should -Be 200
        $signatures = @($result.Calls | ForEach-Object { $_.ArgumentList -join ' ' })
        $signatures.Count | Should -Be 6
        ($signatures | Where-Object { $_ -like 'account show*' }).Count | Should -Be 1
        ($signatures | Where-Object { $_ -like 'graph query*' }).Count | Should -Be 1
        ($signatures | Where-Object { $_ -like 'role assignment list*' }).Count | Should -Be 1
        ($signatures | Where-Object { $_ -like 'policy assignment list*' }).Count | Should -Be 1
        ($signatures | Where-Object { $_ -like 'monitor diagnostic-settings subscription list*' }).Count | Should -Be 1
        ($signatures | Where-Object { $_ -like 'provider show*' }).Count | Should -Be 1
        $result.Service.Status | Should -Be 'Found'
        $result.Service.Resources.Type | Should -Contain 'AzureSubscriptionIdentity'
        $result.Service.Resources.Type | Should -Contain 'AzureRoleAssignment'
        $result.Service.Resources.Type | Should -Contain 'AzurePolicyAssignment'
        $result.Service.Resources.Type | Should -Contain 'AzureDiagnosticSetting'
        $result.Service.Resources.Type | Should -Contain 'AzureProviderState'
    }

    It 'default Azure DevOps production request bundle fetches connection data, project, repositories, service endpoints, environments, pipelines, checks, and effective permissions' {
        $result = InModuleScope Caldova.HrFrontier.Bootstrap -Parameters @{
            TenantConfiguration = $script:TenantConfiguration
            RunId = $script:RunId
            CollectedUtc = $script:CollectedUtc
        } {
            param($TenantConfiguration, $RunId, $CollectedUtc)

            $script:CapturedCalls = @()
            function script:Invoke-DiscoveryNativeCommand {
                param(
                    [Parameter(Mandatory)]
                    [string]$FilePath,

                    [Parameter(Mandatory)]
                    [string[]]$ArgumentList
                )

                $script:CapturedCalls += [pscustomobject]@{
                    FilePath = $FilePath
                    ArgumentList = @($ArgumentList)
                }

                $signature = ($ArgumentList -join ' ')
                switch -Wildcard ($signature) {
                    'devops invoke --area connectionData*' {
                        return [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = [pscustomobject]@{ authenticatedUser = [pscustomobject]@{ id = 'ado-user-synthetic' } } }
                    }
                    'devops invoke --organization* --area core --resource projects*' {
                        return [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = [pscustomobject]@{ id = 'ado-project-synthetic-33333333-3333-3333-3333-333333333333'; name = 'Caldova HR Frontier'; url = 'https://dev.azure.com/caldova25156897/Caldova%20HR%20Frontier' } }
                    }
                    'devops invoke --organization* --area git --resource repositories*' {
                        return [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = @([pscustomobject]@{ id = 'ado-repo-synthetic-1'; name = 'caldova-hr-frontier'; webUrl = 'https://dev.azure.com/caldova25156897/_git/caldova-hr-frontier' }) }
                    }
                    'devops invoke --organization* --area serviceendpoint --resource endpoints*' {
                        return [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = @([pscustomobject]@{ id = 'service-endpoint-synthetic-1'; name = 'bootstrap-subscription' }) }
                    }
                    'devops invoke --organization* --area distributedtask --resource environments*' {
                        return [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = @([pscustomobject]@{ id = 'environment-synthetic-1'; name = 'bootstrap-caldova25156897' }) }
                    }
                    'devops invoke --organization* --area pipelines --resource pipelines*' {
                        return [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = @([pscustomobject]@{ id = 'pipeline-synthetic-1'; name = 'tenant-bootstrap' }) }
                    }
                    'devops invoke --organization* --area pipelinesChecks --resource configurations*' {
                        return [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = @([pscustomobject]@{ id = 'check-synthetic-1'; name = 'required-approval' }) }
                    }
                    'devops security permission list*' {
                        return [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = @([pscustomobject]@{ id = 'permission-synthetic-1'; name = 'Project Administrators' }) }
                    }
                    default {
                        throw "Unexpected Azure DevOps arguments: $signature"
                    }
                }
            }

            $bundle = Invoke-AzureDevOpsDiscoveryRequest -Operation 'DiscoveryBundle' -Arguments @{ OrganizationUrl = [string]$TenantConfiguration.AzureDevOps.OrganizationUrl; ProjectName = [string]$TenantConfiguration.AzureDevOps.ProjectName }
            $service = Get-AzureDevOpsDiscovery -TenantConfiguration $TenantConfiguration -RunId $RunId -CollectedUtc $CollectedUtc -Request {
                param($Operation, $Arguments)
                $bundle
            }

            [pscustomobject]@{
                Calls = @($script:CapturedCalls)
                Bundle = $bundle
                Service = $service
            }
        }

        $result.Bundle.StatusCode | Should -Be 200
        $signatures = @($result.Calls | ForEach-Object { $_.ArgumentList -join ' ' })
        $signatures.Count | Should -Be 8
        ($signatures | Where-Object { $_ -like 'devops invoke --area connectionData*' }).Count | Should -Be 1
        ($signatures | Where-Object { $_ -like 'devops invoke --organization* --area core --resource projects*' }).Count | Should -Be 1
        ($signatures | Where-Object { $_ -like 'devops invoke --organization* --area git --resource repositories*' }).Count | Should -Be 1
        ($signatures | Where-Object { $_ -like 'devops invoke --organization* --area serviceendpoint --resource endpoints*' }).Count | Should -Be 1
        ($signatures | Where-Object { $_ -like 'devops invoke --organization* --area distributedtask --resource environments*' }).Count | Should -Be 1
        ($signatures | Where-Object { $_ -like 'devops invoke --organization* --area pipelines --resource pipelines*' }).Count | Should -Be 1
        ($signatures | Where-Object { $_ -like 'devops invoke --organization* --area pipelinesChecks --resource configurations*' }).Count | Should -Be 1
        ($signatures | Where-Object { $_ -like 'devops security permission list*' }).Count | Should -Be 1
        $result.Service.Status | Should -Be 'Found'
        $result.Service.Resources.Type | Should -Contain 'AzureDevOpsServiceEndpoint'
        $result.Service.Resources.Type | Should -Contain 'AzureDevOpsEnvironment'
        $result.Service.Resources.Type | Should -Contain 'AzureDevOpsCheck'
        $result.Service.Resources.Type | Should -Contain 'AzureDevOpsEffectivePermission'
    }

    It 'marks GitHub discovery ambiguous when the discovered owner id mismatches the reviewed owner id' {
        $fixture = [pscustomobject]@{
            StatusCode = 200
            Headers = @{}
            Body = [ordered]@{
                repository = [pscustomobject]@{
                    id = '1371297722'
                    name = 'caldova-hr-frontier'
                    html_url = 'https://github.com/urruegg/caldova-hr-frontier'
                    owner = [pscustomobject]@{ id = '99999999' }
                }
                oidcCustomization = [pscustomobject]@{
                    use_default = $false
                    use_immutable_subject = $true
                    sub_claim_prefix = 'repo:urruegg@46865858/caldova-hr-frontier@1371297722:environment:bootstrap-caldova25156897'
                }
                environment = [pscustomobject]@{ name = 'bootstrap-caldova25156897' }
            }
        }

        $service = InModuleScope Caldova.HrFrontier.Bootstrap -Parameters @{
            TenantConfiguration = $script:TenantConfiguration
            RunId = $script:RunId
            CollectedUtc = $script:CollectedUtc
            Fixture = $fixture
        } {
            param($TenantConfiguration, $RunId, $CollectedUtc, $Fixture)
            Get-GitHubDiscovery -TenantConfiguration $TenantConfiguration -RunId $RunId -CollectedUtc $CollectedUtc -Request {
                param($Operation, $Arguments)
                $Fixture
            }
        }

        $service.Status | Should -Be 'Ambiguous'
        $service.Resources[0].Status | Should -Be 'Ambiguous'
    }

    It 'marks GitHub discovery ambiguous when the discovered repository id mismatches the reviewed repository id' {
        $fixture = [pscustomobject]@{
            StatusCode = 200
            Headers = @{}
            Body = [ordered]@{
                repository = [pscustomobject]@{
                    id = '9999999999'
                    name = 'caldova-hr-frontier'
                    html_url = 'https://github.com/urruegg/caldova-hr-frontier'
                    owner = [pscustomobject]@{ id = '46865858' }
                }
                oidcCustomization = [pscustomobject]@{
                    use_default = $false
                    use_immutable_subject = $true
                    sub_claim_prefix = 'repo:urruegg@46865858/caldova-hr-frontier@1371297722:environment:bootstrap-caldova25156897'
                }
                environment = [pscustomobject]@{ name = 'bootstrap-caldova25156897' }
            }
        }

        $service = InModuleScope Caldova.HrFrontier.Bootstrap -Parameters @{
            TenantConfiguration = $script:TenantConfiguration
            RunId = $script:RunId
            CollectedUtc = $script:CollectedUtc
            Fixture = $fixture
        } {
            param($TenantConfiguration, $RunId, $CollectedUtc, $Fixture)
            Get-GitHubDiscovery -TenantConfiguration $TenantConfiguration -RunId $RunId -CollectedUtc $CollectedUtc -Request {
                param($Operation, $Arguments)
                $Fixture
            }
        }

        $service.Status | Should -Be 'Ambiguous'
        $service.Resources[0].Status | Should -Be 'Ambiguous'
    }

    It 'keeps GitHub discovery found only when immutable subject settings and reviewed ids exactly match' {
        $fixture = [pscustomobject]@{
            StatusCode = 200
            Headers = @{}
            Body = [ordered]@{
                repository = [pscustomobject]@{
                    id = '1371297722'
                    name = 'caldova-hr-frontier'
                    html_url = 'https://github.com/urruegg/caldova-hr-frontier'
                    owner = [pscustomobject]@{ id = '46865858' }
                }
                oidcCustomization = [pscustomobject]@{
                    use_default = $false
                    use_immutable_subject = $true
                    sub_claim_prefix = 'repo:urruegg@46865858/caldova-hr-frontier@1371297722:environment:bootstrap-caldova25156897'
                }
                environment = [pscustomobject]@{ name = 'bootstrap-caldova25156897' }
            }
        }

        $service = InModuleScope Caldova.HrFrontier.Bootstrap -Parameters @{
            TenantConfiguration = $script:TenantConfiguration
            RunId = $script:RunId
            CollectedUtc = $script:CollectedUtc
            Fixture = $fixture
        } {
            param($TenantConfiguration, $RunId, $CollectedUtc, $Fixture)
            Get-GitHubDiscovery -TenantConfiguration $TenantConfiguration -RunId $RunId -CollectedUtc $CollectedUtc -Request {
                param($Operation, $Arguments)
                $Fixture
            }
        }

        $service.Status | Should -Be 'Found'
        $service.Resources[0].Status | Should -Be 'Found'
    }

    It 'requests and normalizes the required Entra discovery surfaces' {
        $entraFixture = [pscustomobject]@{
            StatusCode = 200
            Headers = @{}
            Body = [ordered]@{
                applications = @(
                    [pscustomobject]@{
                        id = 'app-synthetic-11111111-1111-1111-1111-111111111111'
                        appId = 'client-synthetic-11111111-1111-1111-1111-111111111111'
                        displayName = 'Caldova HR Frontier Bootstrap'
                    }
                )
                servicePrincipals = @(
                    [pscustomobject]@{
                        id = 'spn-synthetic-22222222-2222-2222-2222-222222222222'
                        appId = 'client-synthetic-11111111-1111-1111-1111-111111111111'
                        displayName = 'Caldova HR Frontier Bootstrap'
                    }
                )
                federatedIdentityCredentials = @(
                    [pscustomobject]@{
                        id = 'fic-synthetic-77777777-7777-7777-7777-777777777777'
                        name = 'bootstrap-caldova25156897'
                        subject = 'repo:urruegg@46865858/caldova-hr-frontier@1371297722:environment:bootstrap-caldova25156897'
                    }
                )
            }
        }

        $result = InModuleScope Caldova.HrFrontier.Bootstrap -Parameters @{
            TenantConfiguration = $script:TenantConfiguration
            RunId = $script:RunId
            CollectedUtc = $script:CollectedUtc
            Fixture = $entraFixture
        } {
            param($TenantConfiguration, $RunId, $CollectedUtc, $Fixture)
            $script:Operations = @()
            $service = Get-EntraDiscovery -TenantConfiguration $TenantConfiguration -RunId $RunId -CollectedUtc $CollectedUtc -Request {
                param($Operation, $Arguments)
                $script:Operations += $Operation
                $Fixture
            }

            [pscustomobject]@{
                Operations = $script:Operations
                Service = $service
            }
        }

        $result.Operations | Should -Be @('DiscoveryBundle')
        $result.Service.Status | Should -Be 'Found'
        $result.Service.Resources.Type | Should -Contain 'EntraApplication'
        $result.Service.Resources.Type | Should -Contain 'EntraServicePrincipal'
        $result.Service.Resources.Type | Should -Contain 'EntraFederatedIdentityCredential'
    }

    It 'requests and normalizes the required Azure discovery surfaces' {
        $azureFixture = [pscustomobject]@{
            StatusCode = 200
            Headers = @{}
            Body = [ordered]@{
                subscription = [pscustomobject]@{
                    id = 'subscription-synthetic-edb45a24-408d-47c4-bbc7-685b9b3fc017'
                    name = 'Caldova HR Frontier Platform'
                }
                subscriptionIdentity = [pscustomobject]@{
                    tenantId = 'e2312862-df63-440c-8bcf-007a2c52859d'
                    principalId = 'subscription-principal-synthetic'
                }
                resources = @(
                    [pscustomobject]@{
                        id = '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/resourceGroups/rg-bootstrap/providers/Microsoft.ManagedIdentity/userAssignedIdentities/bootstrap'
                        name = 'bootstrap'
                        type = 'Microsoft.ManagedIdentity/userAssignedIdentities'
                    }
                )
                roleAssignments = @(
                    [pscustomobject]@{
                        id = 'role-assignment-synthetic-1'
                        scope = '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017'
                        roleDefinitionId = 'role-definition-synthetic-owner'
                    }
                )
                policyAssignments = @(
                    [pscustomobject]@{
                        id = 'policy-assignment-synthetic-1'
                        name = 'bootstrap-policy'
                    }
                )
                diagnosticSettings = @(
                    [pscustomobject]@{
                        id = 'diagnostic-setting-synthetic-1'
                        name = 'bootstrap-diagnostics'
                    }
                )
                providerState = [pscustomobject]@{
                    namespace = 'Microsoft.Authorization'
                    registrationState = 'Registered'
                }
            }
        }

        $service = InModuleScope Caldova.HrFrontier.Bootstrap -Parameters @{
            TenantConfiguration = $script:TenantConfiguration
            RunId = $script:RunId
            CollectedUtc = $script:CollectedUtc
            Fixture = $azureFixture
        } {
            param($TenantConfiguration, $RunId, $CollectedUtc, $Fixture)
            Get-AzureDiscovery -TenantConfiguration $TenantConfiguration -RunId $RunId -CollectedUtc $CollectedUtc -Request {
                param($Operation, $Arguments)
                $Fixture
            }
        }

        $service.Status | Should -Be 'Found'
        $service.Resources.Type | Should -Contain 'AzureSubscription'
        $service.Resources.Type | Should -Contain 'AzureSubscriptionIdentity'
        $service.Resources.Type | Should -Contain 'AzureResource'
        $service.Resources.Type | Should -Contain 'AzureRoleAssignment'
        $service.Resources.Type | Should -Contain 'AzurePolicyAssignment'
        $service.Resources.Type | Should -Contain 'AzureDiagnosticSetting'
        $service.Resources.Type | Should -Contain 'AzureProviderState'
    }

    It 'requests and normalizes the required Azure DevOps discovery surfaces' {
        $fixture = [pscustomobject]@{
            StatusCode = 200
            Headers = @{}
            Body = [ordered]@{
                connectionData = [pscustomobject]@{ authenticatedUser = [pscustomobject]@{ id = 'ado-user-synthetic' } }
                project = [pscustomobject]@{ id = 'ado-project-synthetic-33333333-3333-3333-3333-333333333333'; name = 'Caldova HR Frontier'; url = 'https://dev.azure.com/caldova25156897/Caldova%20HR%20Frontier' }
                repositories = @([pscustomobject]@{ id = 'ado-repo-synthetic-1'; name = 'caldova-hr-frontier'; webUrl = 'https://dev.azure.com/caldova25156897/_git/caldova-hr-frontier' })
                serviceEndpoints = @([pscustomobject]@{ id = 'service-endpoint-synthetic-1'; name = 'bootstrap-subscription' })
                environments = @([pscustomobject]@{ id = 'environment-synthetic-1'; name = 'bootstrap-caldova25156897' })
                pipelines = @([pscustomobject]@{ id = 'pipeline-synthetic-1'; name = 'tenant-bootstrap' })
                checks = @([pscustomobject]@{ id = 'check-synthetic-1'; name = 'required-approval' })
                effectivePermissions = @([pscustomobject]@{ id = 'permission-synthetic-1'; name = 'Project Administrators' })
                projectUrl = 'https://dev.azure.com/caldova25156897/Caldova%20HR%20Frontier'
            }
        }

        $service = InModuleScope Caldova.HrFrontier.Bootstrap -Parameters @{
            TenantConfiguration = $script:TenantConfiguration
            RunId = $script:RunId
            CollectedUtc = $script:CollectedUtc
            Fixture = $fixture
        } {
            param($TenantConfiguration, $RunId, $CollectedUtc, $Fixture)
            Get-AzureDevOpsDiscovery -TenantConfiguration $TenantConfiguration -RunId $RunId -CollectedUtc $CollectedUtc -Request {
                param($Operation, $Arguments)
                $Fixture
            }
        }

        $service.Status | Should -Be 'Found'
        $service.Resources.Type | Should -Contain 'AzureDevOpsProject'
        $service.Resources.Type | Should -Contain 'AzureDevOpsConnectionData'
        $service.Resources.Type | Should -Contain 'AzureDevOpsRepository'
        $service.Resources.Type | Should -Contain 'AzureDevOpsServiceEndpoint'
        $service.Resources.Type | Should -Contain 'AzureDevOpsEnvironment'
        $service.Resources.Type | Should -Contain 'AzureDevOpsPipeline'
        $service.Resources.Type | Should -Contain 'AzureDevOpsCheck'
        $service.Resources.Type | Should -Contain 'AzureDevOpsEffectivePermission'
    }

    It 'joins ExistingContext Power Platform probes to committed baseline stable ids' {
        $baselineEvidence = New-BaselineEvidence
        $probePath = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString() + '.json')
        try {
            [System.IO.File]::WriteAllText($probePath, ((New-ProbeRecords) | ConvertTo-Json -Depth 10), [System.Text.UTF8Encoding]::new($false))
            $service = InModuleScope Caldova.HrFrontier.Bootstrap -Parameters @{
                TenantConfiguration = $script:TenantConfiguration
                RunId = $script:RunId
                CollectedUtc = $script:CollectedUtc
                ProbePath = $probePath
                BaselineEvidence = $baselineEvidence
            } {
                param($TenantConfiguration, $RunId, $CollectedUtc, $ProbePath, $BaselineEvidence)
                Get-PowerPlatformDiscovery -TenantConfiguration $TenantConfiguration -RunId $RunId -CollectedUtc $CollectedUtc -AuthenticationMode ExistingContext -ProbePath $ProbePath -BaselineEvidence $BaselineEvidence -Request {
                    param($Operation, $Arguments)
                    throw 'ExistingContext probe mode must not call the Power Platform network request.'
                }
            }

            $service.Status | Should -Be 'Found'
            $service.Resources.Count | Should -Be 3
            ($service.Resources | Where-Object Type -eq 'PowerPlatformEnvironmentDev').Id | Should -Be 'pp-env-synthetic-dev-44444444-4444-4444-4444-444444444444'
            ($service.Resources | Where-Object Type -eq 'PowerPlatformEnvironmentTest').Id | Should -Be 'pp-env-synthetic-test-55555555-5555-5555-5555-555555555555'
            ($service.Resources | Where-Object Type -eq 'PowerPlatformEnvironmentProd').Id | Should -Be 'pp-env-synthetic-prod-66666666-6666-6666-6666-666666666666'
        }
        finally {
            if (Test-Path -LiteralPath $probePath) {
                Remove-Item -LiteralPath $probePath -Force
            }
        }
    }

    It 'interactive Power Platform discovery normalizes the reviewed DEV TEST and PROD environments' {
        InModuleScope Caldova.HrFrontier.Bootstrap -Parameters @{
            TenantConfiguration = $script:TenantConfiguration
            RunId = $script:RunId
            CollectedUtc = $script:CollectedUtc
        } {
            param($TenantConfiguration, $RunId, $CollectedUtc)

            $service = Get-PowerPlatformDiscovery -TenantConfiguration $TenantConfiguration -RunId $RunId -CollectedUtc $CollectedUtc -AuthenticationMode Interactive -Request {
                param($Operation, $Arguments)

                $Operation | Should -Be 'EnvironmentMetadata'
                [pscustomobject]@{
                    StatusCode = 200
                    Headers = @{}
                    Body = @(
                        [pscustomobject]@{ id = 'pp-env-synthetic-dev-44444444-4444-4444-4444-444444444444'; displayName = 'HR Frontier Dev'; environmentUrl = $TenantConfiguration.PowerPlatform.DevUrl; properties = [pscustomobject]@{ environmentSku = 'Sandbox'; state = 'Ready'; isManaged = $true } },
                        [pscustomobject]@{ id = 'pp-env-synthetic-test-55555555-5555-5555-5555-555555555555'; displayName = 'HR Frontier Test'; environmentUrl = $TenantConfiguration.PowerPlatform.TestUrl; properties = [pscustomobject]@{ environmentSku = 'Sandbox'; state = 'Ready'; isManaged = $true } },
                        [pscustomobject]@{ id = 'pp-env-synthetic-prod-66666666-6666-6666-6666-666666666666'; displayName = 'HR Frontier Prod'; environmentUrl = $TenantConfiguration.PowerPlatform.ProdUrl; properties = [pscustomobject]@{ environmentSku = 'Production'; state = 'Ready'; isManaged = $true } }
                    )
                }
            }

            $service.Status | Should -Be 'Found'
            $service.Resources.Count | Should -Be 3
            ($service.Resources | ForEach-Object Type) | Should -Be @('PowerPlatformEnvironmentDev', 'PowerPlatformEnvironmentTest', 'PowerPlatformEnvironmentProd')
            ($service.Resources | ForEach-Object Id) | Should -Be @(
                'pp-env-synthetic-dev-44444444-4444-4444-4444-444444444444',
                'pp-env-synthetic-test-55555555-5555-5555-5555-555555555555',
                'pp-env-synthetic-prod-66666666-6666-6666-6666-666666666666'
            )
        }
    }

    It 'interactive Power Platform discovery returns Missing when a reviewed environment URL is absent' {
        InModuleScope Caldova.HrFrontier.Bootstrap -Parameters @{
            TenantConfiguration = $script:TenantConfiguration
            RunId = $script:RunId
            CollectedUtc = $script:CollectedUtc
        } {
            param($TenantConfiguration, $RunId, $CollectedUtc)

            $service = Get-PowerPlatformDiscovery -TenantConfiguration $TenantConfiguration -RunId $RunId -CollectedUtc $CollectedUtc -AuthenticationMode Interactive -Request {
                param($Operation, $Arguments)

                [pscustomobject]@{
                    StatusCode = 200
                    Headers = @{}
                    Body = @(
                        [pscustomobject]@{ id = 'pp-env-synthetic-dev-44444444-4444-4444-4444-444444444444'; displayName = 'HR Frontier Dev'; environmentUrl = $TenantConfiguration.PowerPlatform.DevUrl },
                        [pscustomobject]@{ id = 'pp-env-synthetic-test-55555555-5555-5555-5555-555555555555'; displayName = 'HR Frontier Test'; environmentUrl = $TenantConfiguration.PowerPlatform.TestUrl }
                    )
                }
            }

            $service.Status | Should -Be 'Missing'
        }
    }

    It 'interactive Power Platform discovery returns Ambiguous when duplicate reviewed candidates are returned' {
        InModuleScope Caldova.HrFrontier.Bootstrap -Parameters @{
            TenantConfiguration = $script:TenantConfiguration
            RunId = $script:RunId
            CollectedUtc = $script:CollectedUtc
        } {
            param($TenantConfiguration, $RunId, $CollectedUtc)

            $service = Get-PowerPlatformDiscovery -TenantConfiguration $TenantConfiguration -RunId $RunId -CollectedUtc $CollectedUtc -AuthenticationMode Interactive -Request {
                param($Operation, $Arguments)

                [pscustomobject]@{
                    StatusCode = 200
                    Headers = @{}
                    Body = @(
                        [pscustomobject]@{ id = 'pp-env-synthetic-dev-44444444-4444-4444-4444-444444444444'; displayName = 'HR Frontier Dev'; environmentUrl = $TenantConfiguration.PowerPlatform.DevUrl },
                        [pscustomobject]@{ id = 'pp-env-synthetic-dev-duplicate'; displayName = 'HR Frontier Dev Duplicate'; environmentUrl = $TenantConfiguration.PowerPlatform.DevUrl },
                        [pscustomobject]@{ id = 'pp-env-synthetic-test-55555555-5555-5555-5555-555555555555'; displayName = 'HR Frontier Test'; environmentUrl = $TenantConfiguration.PowerPlatform.TestUrl },
                        [pscustomobject]@{ id = 'pp-env-synthetic-prod-66666666-6666-6666-6666-666666666666'; displayName = 'HR Frontier Prod'; environmentUrl = $TenantConfiguration.PowerPlatform.ProdUrl }
                    )
                }
            }

            $service.Status | Should -Be 'Ambiguous'
            (@($service.Resources | Where-Object Type -eq 'PowerPlatformEnvironmentDev')).Count | Should -Be 2
        }
    }

    It 'fails ExistingContext entry point before adapters or writes when the observed principal does not match AZURE_CLIENT_ID' {
        $result = Invoke-DiscoveryEntryPointIsolated -Environment @{
            AZURE_CLIENT_ID = 'bootstrap-client-id-expected'
            AZURE_TENANT_ID = $script:TenantConfiguration.TenantId
            AZURE_SUBSCRIPTION_ID = $script:TenantConfiguration.SubscriptionId
        } -BeforeRun {
            param($RepoRoot, $ProbePath, $OutputPath, $NativeLogPath)
            [System.IO.File]::WriteAllText($ProbePath, ((New-ProbeRecords) | ConvertTo-Json -Depth 10), [System.Text.UTF8Encoding]::new($false))
            $baseline = New-BaselineEvidence
            [System.IO.File]::WriteAllText((Join-Path $RepoRoot 'infra\evidence\discovery\caldova25156897.json'), ($baseline | ConvertTo-Json -Depth 20), [System.Text.UTF8Encoding]::new($false))
            $account = [pscustomobject]@{
                tenantId = $script:TenantConfiguration.TenantId
                id = $script:TenantConfiguration.SubscriptionId
                user = [pscustomobject]@{
                    type = 'servicePrincipal'
                    name = 'bootstrap-client-id-actual'
                }
            }
            [System.IO.File]::WriteAllText((Join-Path (Split-Path $ProbePath -Parent) 'account.json'), ($account | ConvertTo-Json -Depth 10), [System.Text.UTF8Encoding]::new($false))
        }

        $result.ExitCode | Should -Not -Be 0
        $result.StdErr | Should -Match 'AZURE_CLIENT_ID'
        (Test-Path -LiteralPath $result.OutputPath) | Should -BeFalse
    }

    It 'requires baseline evidence and a probe file for ExistingContext entry point and enforces temp-only output and overwrite refusal' {
        $missingBaseline = Invoke-DiscoveryEntryPointIsolated -Environment @{
            AZURE_CLIENT_ID = 'bootstrap-client-id-0001'
            AZURE_TENANT_ID = $script:TenantConfiguration.TenantId
            AZURE_SUBSCRIPTION_ID = $script:TenantConfiguration.SubscriptionId
        } -BeforeRun {
            param($RepoRoot, $ProbePath, $OutputPath, $NativeLogPath)
            [System.IO.File]::WriteAllText($ProbePath, ((New-ProbeRecords) | ConvertTo-Json -Depth 10), [System.Text.UTF8Encoding]::new($false))
            $account = [pscustomobject]@{
                tenantId = $script:TenantConfiguration.TenantId
                id = $script:TenantConfiguration.SubscriptionId
                user = [pscustomobject]@{
                    type = 'servicePrincipal'
                    name = 'bootstrap-client-id-0001'
                }
            }
            [System.IO.File]::WriteAllText((Join-Path (Split-Path $ProbePath -Parent) 'account.json'), ($account | ConvertTo-Json -Depth 10), [System.Text.UTF8Encoding]::new($false))
        }

        $missingBaseline.ExitCode | Should -Not -Be 0
        $missingBaseline.StdErr | Should -Match 'baseline'
        (Test-Path -LiteralPath $missingBaseline.OutputPath) | Should -BeFalse

        $unsafeOutput = Invoke-DiscoveryEntryPointIsolated -Environment @{
            AZURE_CLIENT_ID = 'bootstrap-client-id-0001'
            AZURE_TENANT_ID = $script:TenantConfiguration.TenantId
            AZURE_SUBSCRIPTION_ID = $script:TenantConfiguration.SubscriptionId
        } -ExtraArguments @('-OutputPath', (Join-Path $script:RepositoryRoot 'forbidden-output.json')) -BeforeRun {
            param($RepoRoot, $ProbePath, $OutputPath, $NativeLogPath)
            [System.IO.File]::WriteAllText($ProbePath, ((New-ProbeRecords) | ConvertTo-Json -Depth 10), [System.Text.UTF8Encoding]::new($false))
            $baseline = New-BaselineEvidence
            [System.IO.File]::WriteAllText((Join-Path $RepoRoot 'infra\evidence\discovery\caldova25156897.json'), ($baseline | ConvertTo-Json -Depth 20), [System.Text.UTF8Encoding]::new($false))
            $account = [pscustomobject]@{
                tenantId = $script:TenantConfiguration.TenantId
                id = $script:TenantConfiguration.SubscriptionId
                user = [pscustomobject]@{
                    type = 'servicePrincipal'
                    name = 'bootstrap-client-id-0001'
                }
            }
            [System.IO.File]::WriteAllText((Join-Path (Split-Path $ProbePath -Parent) 'account.json'), ($account | ConvertTo-Json -Depth 10), [System.Text.UTF8Encoding]::new($false))
        }

        $unsafeOutput.ExitCode | Should -Not -Be 0
        $unsafeOutput.StdErr | Should -Match 'temporary directory'

        $overwriteRefused = Invoke-DiscoveryEntryPointIsolated -Environment @{
            AZURE_CLIENT_ID = 'bootstrap-client-id-0001'
            AZURE_TENANT_ID = $script:TenantConfiguration.TenantId
            AZURE_SUBSCRIPTION_ID = $script:TenantConfiguration.SubscriptionId
        } -BeforeRun {
            param($RepoRoot, $ProbePath, $OutputPath, $NativeLogPath)
            [System.IO.File]::WriteAllText($ProbePath, ((New-ProbeRecords) | ConvertTo-Json -Depth 10), [System.Text.UTF8Encoding]::new($false))
            $baseline = New-BaselineEvidence
            [System.IO.File]::WriteAllText((Join-Path $RepoRoot 'infra\evidence\discovery\caldova25156897.json'), ($baseline | ConvertTo-Json -Depth 20), [System.Text.UTF8Encoding]::new($false))
            [System.IO.File]::WriteAllText($OutputPath, '{"existing":true}', [System.Text.UTF8Encoding]::new($false))
            $account = [pscustomobject]@{
                tenantId = $script:TenantConfiguration.TenantId
                id = $script:TenantConfiguration.SubscriptionId
                user = [pscustomobject]@{
                    type = 'servicePrincipal'
                    name = 'bootstrap-client-id-0001'
                }
            }
            [System.IO.File]::WriteAllText((Join-Path (Split-Path $ProbePath -Parent) 'account.json'), ($account | ConvertTo-Json -Depth 10), [System.Text.UTF8Encoding]::new($false))
        }

        $overwriteRefused.ExitCode | Should -Not -Be 0
        $overwriteRefused.StdErr | Should -Match 'already exists'

        $replaceAllowed = Invoke-DiscoveryEntryPointIsolated -Environment @{
            AZURE_CLIENT_ID = 'bootstrap-client-id-0001'
            AZURE_TENANT_ID = $script:TenantConfiguration.TenantId
            AZURE_SUBSCRIPTION_ID = $script:TenantConfiguration.SubscriptionId
        } -ExtraArguments @('-Replace') -BeforeRun {
            param($RepoRoot, $ProbePath, $OutputPath, $NativeLogPath)
            [System.IO.File]::WriteAllText($ProbePath, ((New-ProbeRecords) | ConvertTo-Json -Depth 10), [System.Text.UTF8Encoding]::new($false))
            $baseline = New-BaselineEvidence
            [System.IO.File]::WriteAllText((Join-Path $RepoRoot 'infra\evidence\discovery\caldova25156897.json'), ($baseline | ConvertTo-Json -Depth 20), [System.Text.UTF8Encoding]::new($false))
            [System.IO.File]::WriteAllText($OutputPath, '{"existing":true}', [System.Text.UTF8Encoding]::new($false))
            $account = [pscustomobject]@{
                tenantId = $script:TenantConfiguration.TenantId
                id = $script:TenantConfiguration.SubscriptionId
                user = [pscustomobject]@{
                    type = 'servicePrincipal'
                    name = 'bootstrap-client-id-0001'
                }
            }
            [System.IO.File]::WriteAllText((Join-Path (Split-Path $ProbePath -Parent) 'account.json'), ($account | ConvertTo-Json -Depth 10), [System.Text.UTF8Encoding]::new($false))
        }

        $replaceAllowed.ExitCode | Should -Be 0
        (Test-Path -LiteralPath $replaceAllowed.OutputPath) | Should -BeTrue
        if (Test-Path -LiteralPath $replaceAllowed.NativeLogPath) {
            $nativeCalls = Get-Content -Raw -LiteralPath $replaceAllowed.NativeLogPath | ConvertFrom-Json
            @($nativeCalls).Count | Should -Be 0
        }
    }

    It 'accepts the reviewed administrator UPN when Azure CLI normalizes its casing' {
        $tokens = $null
        $parseErrors = $null
        $entryPointAst = [System.Management.Automation.Language.Parser]::ParseFile($script:DiscoveryEntryPointPath, [ref]$tokens, [ref]$parseErrors)
        $parseErrors.Count | Should -Be 0
        $functionAst = $entryPointAst.Find({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq 'Get-InteractivePrincipal'
        }, $true)
        $functionAst | Should -Not -BeNullOrEmpty

        . ([scriptblock]::Create($functionAst.Extent.Text))

        $previousExitCode = $global:LASTEXITCODE
        try {
            function az {
                $global:LASTEXITCODE = 0
            }

            function Invoke-AzJson {
                param([string[]]$ArgumentList)

                [pscustomobject]@{
                    tenantId = $script:TenantConfiguration.TenantId
                    id = $script:TenantConfiguration.SubscriptionId
                    user = [pscustomobject]@{
                        type = 'user'
                        name = 'admin@caldova25156897.onmicrosoft.com'
                    }
                }
            }

            $principal = Get-InteractivePrincipal -TenantConfiguration $script:TenantConfiguration

            $principal.Type | Should -Be 'User'
            $principal.Upn | Should -Be 'admin@caldova25156897.onmicrosoft.com'
        }
        finally {
            $global:LASTEXITCODE = $previousExitCode
        }
    }
}