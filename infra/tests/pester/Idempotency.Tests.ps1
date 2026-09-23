Set-StrictMode -Version Latest

Describe 'Task 6 bootstrap orchestration and idempotency' {
    BeforeAll {
        $script:RepositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
        $script:BootstrapScriptPath = Join-Path $script:RepositoryRoot 'infra\src\scripts\Invoke-TenantBootstrap.ps1'
        $script:FixturePath = Join-Path $script:RepositoryRoot 'infra\tests\fixtures\what-if\allowed.json'
        $script:BootstrapRunId = '44444444-4444-4444-4444-444444444444'
        $script:ApprovedRoleAssignmentIds = @(
            '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/providers/Microsoft.Authorization/roleAssignments/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
            '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/providers/Microsoft.Authorization/roleAssignments/bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
        )

        function script:New-TenantConfigurationFile {
            $path = Join-Path $TestDrive ([guid]::NewGuid().ToString() + '.psd1')
            $content = @"
@{
    SchemaVersion = '1.0'
    TenantAlias = 'caldova25156897'
    DisplayName = 'Caldova25156897'
    TenantId = 'e2312862-df63-440c-8bcf-007a2c52859d'
    AdminUpn = 'admin@Caldova25156897.onmicrosoft.com'
    SubscriptionId = 'edb45a24-408d-47c4-bbc7-685b9b3fc017'
    PrimaryLocation = 'switzerlandnorth'
    CompanyTla = 'cal'
    WorkloadName = 'hr-agentic'
    UniqueSuffix = 'bc8rbt'
    NamingRoot = 'cal-hr-agentic-bc8rbt'
    LifecycleState = 'IntentReviewed'
    GitHub = @{
        Owner = 'urruegg'
        OwnerId = '46865858'
        Repository = 'caldova-hr-frontier'
        RepositoryId = '1371297722'
        EnvironmentName = 'bootstrap-caldova25156897'
    }
    AzureDevOps = @{
        OrganizationUrl = 'https://dev.azure.com/caldova25156897/'
        ProjectName = 'Caldova HR Frontier'
    }
    PowerPlatform = @{
        DevUrl = 'https://hrfrontierdev.crm17.dynamics.com/'
        TestUrl = 'https://hrfrontiertest.crm17.dynamics.com/'
        ProdUrl = 'https://hrfrontier.crm17.dynamics.com/'
    }
    Components = @{
        EntraServicePrincipal = @{
            Mode = 'Existing'
            Id = '55555555-5555-5555-5555-555555555555'
        }
    }
}
"@
            [System.IO.File]::WriteAllText($path, $content, [System.Text.UTF8Encoding]::new($false))
            $path
        }

        function script:New-PlaceholderFile {
            param(
                [Parameter(Mandatory)]
                [string]$Name,

                [Parameter(Mandatory)]
                [string]$Content
            )

            $path = Join-Path $TestDrive $Name
            [System.IO.File]::WriteAllText($path, $Content, [System.Text.UTF8Encoding]::new($false))
            $path
        }

                function script:New-EvidenceFile {
                    param(
                        [string]$EntraServicePrincipalId = '55555555-5555-5555-5555-555555555555',
                        [string]$CompletedUtc = ([datetime]::UtcNow.ToString('o'))
                    )

                        $hash = ('a' * 64)
                    $startedUtc = ([datetime]::Parse($CompletedUtc).ToUniversalTime().AddMinutes(-1).ToString('o'))
                        $path = Join-Path $TestDrive ([guid]::NewGuid().ToString() + '-evidence.json')
                        $content = @"
{
    "SchemaVersion": "1.0",
    "ToolVersion": "1.0.0",
    "RunId": "44444444-4444-4444-4444-444444444444",
    "CollectionStartedUtc": "$startedUtc",
    "CollectionCompletedUtc": "$CompletedUtc",
    "TenantAlias": "caldova25156897",
    "TenantId": "e2312862-df63-440c-8bcf-007a2c52859d",
    "Principal": {
        "Type": "ServicePrincipal",
        "Id": "99999999-9999-9999-9999-999999999999",
        "ClientId": "11111111-1111-1111-1111-111111111111"
    },
    "Services": {
        "GitHub": {
            "Name": "GitHub",
            "RunId": "44444444-4444-4444-4444-444444444444",
            "Status": "Missing",
            "SourceApi": "github/rest",
            "CollectedUtc": "$CompletedUtc",
            "ResponseSha256": "$hash",
            "Resources": []
        },
        "Entra": {
            "Name": "Entra",
            "RunId": "44444444-4444-4444-4444-444444444444",
            "Status": "Found",
            "SourceApi": "graph/rest",
            "CollectedUtc": "$CompletedUtc",
            "ResponseSha256": "$hash",
            "Resources": [
                {
                    "Type": "EntraServicePrincipal",
                    "Id": "$EntraServicePrincipalId",
                    "Name": "cal-hr-agentic-bc8rbt-app",
                    "Status": "Found",
                    "EvidenceReference": {
                        "Service": "Entra",
                        "SourceApi": "graph/rest",
                        "Scope": "/tenants/e2312862-df63-440c-8bcf-007a2c52859d",
                        "CollectedUtc": "$CompletedUtc",
                        "ResponseSha256": "$hash"
                    }
                }
            ]
        },
        "Azure": {
            "Name": "Azure",
            "RunId": "44444444-4444-4444-4444-444444444444",
            "Status": "Missing",
            "SourceApi": "arm/rest",
            "CollectedUtc": "$CompletedUtc",
            "ResponseSha256": "$hash",
            "Resources": []
        },
        "AzureDevOps": {
            "Name": "AzureDevOps",
            "RunId": "44444444-4444-4444-4444-444444444444",
            "Status": "Missing",
            "SourceApi": "ado/rest",
            "CollectedUtc": "$CompletedUtc",
            "ResponseSha256": "$hash",
            "Resources": []
        },
        "PowerPlatform": {
            "Name": "PowerPlatform",
            "RunId": "44444444-4444-4444-4444-444444444444",
            "Status": "Missing",
            "SourceApi": "pp/rest",
            "CollectedUtc": "$CompletedUtc",
            "ResponseSha256": "$hash",
            "Resources": []
        }
    }
}
"@
                        [System.IO.File]::WriteAllText($path, $content, [System.Text.UTF8Encoding]::new($false))
                        $path
                }

        function script:New-RoleStateFile {
            $path = Join-Path $TestDrive ([guid]::NewGuid().ToString() + '.json')
                        $content = @'
{
  "SchemaVersion": "1.0",
  "RunId": "44444444-4444-4444-4444-444444444444",
  "TenantAlias": "caldova25156897",
  "TenantId": "e2312862-df63-440c-8bcf-007a2c52859d",
  "SubscriptionId": "edb45a24-408d-47c4-bbc7-685b9b3fc017",
  "PrincipalObjectId": "55555555-5555-5555-5555-555555555555",
  "Scope": "/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017",
  "CreatedUtc": "2026-09-19T10:00:00Z",
  "Assignments": [
    {
      "Id": "/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/providers/Microsoft.Authorization/roleAssignments/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
      "RoleName": "Contributor",
      "RoleDefinitionId": "/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c",
      "PrincipalObjectId": "55555555-5555-5555-5555-555555555555",
      "Scope": "/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017",
      "CreatedUtc": "2026-09-19T10:00:00Z"
    },
    {
      "Id": "/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/providers/Microsoft.Authorization/roleAssignments/bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
      "RoleName": "Role Based Access Control Administrator",
      "RoleDefinitionId": "/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/providers/Microsoft.Authorization/roleDefinitions/f58310d9-a9f6-439a-9e8d-f62e7b41a168",
      "PrincipalObjectId": "55555555-5555-5555-5555-555555555555",
      "Scope": "/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017",
      "CreatedUtc": "2026-09-19T10:00:01Z"
    }
  ]
}
'@
                        [System.IO.File]::WriteAllText($path, $content, [System.Text.UTF8Encoding]::new($false))
            $path
        }
    }

    It 'defines the bootstrap orchestration surface before implementation' {
        Test-Path -LiteralPath $script:BootstrapScriptPath | Should -BeTrue
    }

    It 'rejects <Case> reviewed cleanup approval before post-state work' -ForEach @(
        @{
            Case = 'false confirmation'
            Confirmation = $false
            RunId = '44444444-4444-4444-4444-444444444444'
            ApprovedIds = @(
                '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/providers/Microsoft.Authorization/roleAssignments/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
                '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/providers/Microsoft.Authorization/roleAssignments/bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
            )
            ExpectedError = '*ConfirmRoleCleanup must be true*'
        },
        @{
            Case = 'stale run id'
            Confirmation = $true
            RunId = '33333333-3333-3333-3333-333333333333'
            ApprovedIds = @(
                '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/providers/Microsoft.Authorization/roleAssignments/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
                '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/providers/Microsoft.Authorization/roleAssignments/bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
            )
            ExpectedError = '*BootstrapRunId must match TemporaryRoleState.RunId*'
        },
        @{
            Case = 'unapproved assignment id'
            Confirmation = $true
            RunId = '44444444-4444-4444-4444-444444444444'
            ApprovedIds = @(
                '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/providers/Microsoft.Authorization/roleAssignments/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
                '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017/providers/Microsoft.Authorization/roleAssignments/cccccccc-cccc-cccc-cccc-cccccccccccc'
            )
            ExpectedError = '*ApprovedRoleAssignmentIds must exactly match TemporaryRoleState assignment ids*'
        }
    ) {
        param($Case, $Confirmation, $RunId, $ApprovedIds, $ExpectedError)

        $tenantConfigurationPath = New-TenantConfigurationFile
        $evidencePath = New-PlaceholderFile -Name 'approval-evidence.json' -Content '{}'
        $parameterFile = New-PlaceholderFile -Name 'approval-main.bicepparam' -Content 'using "../src/bicep/main.bicep"'
        $roleStatePath = New-RoleStateFile
        $nativeCalls = [System.Collections.Generic.List[string]]::new()
        $cleanupCalls = [System.Collections.Generic.List[string]]::new()

        {
            & $script:BootstrapScriptPath -TenantAlias 'caldova25156897' -TenantConfigurationPath $tenantConfigurationPath -EvidencePath $evidencePath -ParameterFile $parameterFile -TemporaryRoleStatePath $roleStatePath -WhatIfOnly -ConfirmRoleCleanup $Confirmation -BootstrapRunId $RunId -ApprovedRoleAssignmentIds $ApprovedIds -DiscoveryEvidenceValidator { } -IntentValidator { } -OidcContextValidator { } -RoleStateLoader { param([string]$Path) Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json } -NativeCommandRunner {
                param([string]$FilePath, [string[]]$ArgumentList)
                $nativeCalls.Add($FilePath) | Out-Null
                throw 'native runner must not be reached'
            } -CleanupRunner {
                param([object]$RoleState)
                $cleanupCalls.Add([string]$RoleState.RunId) | Out-Null
            }
        } | Should -Throw $ExpectedError

        $nativeCalls.Count | Should -Be 0
        $cleanupCalls.Count | Should -Be 0
    }

    It 'runs cleanup after <FailureStage> failure' -ForEach @(
        @{ FailureStage = 'Bicep build'; UseWhatIfOnly = $true; ExpectedError = '*simulated Bicep build failure*' },
        @{ FailureStage = 'the WhatIfOnly guard'; UseWhatIfOnly = $false; ExpectedError = '*only supports -WhatIfOnly*' },
        @{ FailureStage = 'Azure what-if'; UseWhatIfOnly = $true; ExpectedError = '*az what-if failed with exit code 17*' },
        @{ FailureStage = 'what-if payload write'; UseWhatIfOnly = $true; ExpectedError = '*Could not find a part of the path*' }
    ) {
        param($FailureStage, $UseWhatIfOnly, $ExpectedError)

        $tenantConfigurationPath = New-TenantConfigurationFile
        $evidencePath = New-PlaceholderFile -Name ("{0}-evidence.json" -f ([guid]::NewGuid()).Guid) -Content '{}'
        $parameterFile = New-PlaceholderFile -Name ("{0}-main.bicepparam" -f ([guid]::NewGuid()).Guid) -Content 'using "../src/bicep/main.bicep"'
        $roleStatePath = New-RoleStateFile
        $fixturePath = $script:FixturePath
        $cleanupCalls = [System.Collections.Generic.List[string]]::new()
        $previousRunnerTemp = $env:RUNNER_TEMP
        $runnerTempWasPresent = Test-Path Env:RUNNER_TEMP

        if ($FailureStage -eq 'what-if payload write') {
            $env:RUNNER_TEMP = New-PlaceholderFile -Name ("{0}-blocked-temp-root" -f ([guid]::NewGuid()).Guid) -Content 'not a directory'
        }

        try {
            $parameters = @{
                TenantAlias = 'caldova25156897'
                TenantConfigurationPath = $tenantConfigurationPath
                EvidencePath = $evidencePath
                ParameterFile = $parameterFile
                TemporaryRoleStatePath = $roleStatePath
                ConfirmRoleCleanup = $true
                BootstrapRunId = $script:BootstrapRunId
                ApprovedRoleAssignmentIds = $script:ApprovedRoleAssignmentIds
                DiscoveryEvidenceValidator = { }
                IntentValidator = { }
                OidcContextValidator = { }
                BicepValidator = {
                    if ($FailureStage -eq 'Bicep build') {
                        throw 'simulated Bicep build failure'
                    }
                }.GetNewClosure()
                RoleStateLoader = { param([string]$Path) Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json }
                NativeCommandRunner = {
                    param([string]$FilePath, [string[]]$ArgumentList)

                    if ($FailureStage -eq 'Azure what-if') {
                        return [pscustomobject]@{ ExitCode = 17; StdOut = ''; StdErr = 'simulated what-if failure' }
                    }

                    return [pscustomobject]@{ ExitCode = 0; StdOut = (Get-Content -Raw -LiteralPath $fixturePath); StdErr = '' }
                }.GetNewClosure()
                WhatIfBoundaryValidator = { throw 'boundary validator must not be reached' }
                CleanupRunner = { param([object]$RoleState) $cleanupCalls.Add([string]$RoleState.RunId) | Out-Null }
            }
            if ($UseWhatIfOnly) {
                $parameters.WhatIfOnly = $true
            }

            { & $script:BootstrapScriptPath @parameters } | Should -Throw $ExpectedError
            $cleanupCalls | Should -Be @($script:BootstrapRunId)
        }
        finally {
            if ($runnerTempWasPresent) {
                $env:RUNNER_TEMP = $previousRunnerTemp
            }
            else {
                Remove-Item Env:RUNNER_TEMP -ErrorAction SilentlyContinue
            }
        }
    }

    It 'runs cleanup from finally after a simulated boundary validation failure' {
        $tenantConfigurationPath = New-TenantConfigurationFile
        $evidencePath = New-PlaceholderFile -Name 'evidence.json' -Content '{}'
        $parameterFile = New-PlaceholderFile -Name 'main.bicepparam' -Content 'using "../src/bicep/main.bicep"'
        $roleStatePath = New-RoleStateFile
        $fixturePath = $script:FixturePath
        $events = [System.Collections.Generic.List[string]]::new()

        {
            & $script:BootstrapScriptPath -TenantAlias 'caldova25156897' -TenantConfigurationPath $tenantConfigurationPath -EvidencePath $evidencePath -ParameterFile $parameterFile -TemporaryRoleStatePath $roleStatePath -ConfirmRoleCleanup $true -BootstrapRunId $script:BootstrapRunId -ApprovedRoleAssignmentIds $script:ApprovedRoleAssignmentIds -WhatIfOnly -DiscoveryEvidenceValidator { $events.Add('evidence') | Out-Null } -IntentValidator { $events.Add('intent') | Out-Null } -OidcContextValidator { $events.Add('oidc') | Out-Null } -BicepValidator { $events.Add('bicep') | Out-Null } -RoleStateLoader { param([string]$Path) $events.Add('state') | Out-Null; Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json } -NativeCommandRunner {
                param([string]$FilePath, [string[]]$ArgumentList)

                $events.Add(($FilePath + ' ' + ($ArgumentList -join ' '))) | Out-Null
                @{ ExitCode = 0; StdOut = (Get-Content -Raw -LiteralPath $fixturePath); StdErr = '' }
            } -WhatIfBoundaryValidator { param([string]$Path) $events.Add('boundary') | Out-Null; throw 'boundary failed' } -CleanupRunner { param([object]$RoleState) $events.Add('cleanup') | Out-Null }
        } | Should -Throw '*boundary failed*'

        $events | Should -Contain 'cleanup'
    }

    It 'surfaces cleanup failure without hiding the original bootstrap failure' {
        $tenantConfigurationPath = New-TenantConfigurationFile
        $evidencePath = New-PlaceholderFile -Name 'evidence.json' -Content '{}'
        $parameterFile = New-PlaceholderFile -Name 'main.bicepparam' -Content 'using "../src/bicep/main.bicep"'
        $roleStatePath = New-RoleStateFile
        $fixturePath = $script:FixturePath
        {
            & $script:BootstrapScriptPath -TenantAlias 'caldova25156897' -TenantConfigurationPath $tenantConfigurationPath -EvidencePath $evidencePath -ParameterFile $parameterFile -TemporaryRoleStatePath $roleStatePath -ConfirmRoleCleanup $true -BootstrapRunId $script:BootstrapRunId -ApprovedRoleAssignmentIds $script:ApprovedRoleAssignmentIds -WhatIfOnly -DiscoveryEvidenceValidator { } -IntentValidator { } -OidcContextValidator { } -BicepValidator { } -RoleStateLoader { param([string]$Path) Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json } -NativeCommandRunner {
                param([string]$FilePath, [string[]]$ArgumentList)

                @{ ExitCode = 0; StdOut = (Get-Content -Raw -LiteralPath $fixturePath); StdErr = '' }
            } -WhatIfBoundaryValidator { param([string]$Path) throw 'boundary failed' } -CleanupRunner { param([object]$RoleState) throw 'cleanup failed' }
        } | Should -Throw '*boundary failed*cleanup failed*'
    }

    It 'constructs only the reviewed what-if command arguments in WhatIfOnly mode' {
        $tenantConfigurationPath = New-TenantConfigurationFile
        $evidencePath = New-PlaceholderFile -Name 'evidence.json' -Content '{}'
        $parameterFile = New-PlaceholderFile -Name 'main.bicepparam' -Content 'using "../src/bicep/main.bicep"'
        $roleStatePath = New-RoleStateFile
        $fixturePath = $script:FixturePath
        $expectedMainBicepPath = [System.IO.Path]::GetFullPath((Join-Path $script:RepositoryRoot 'infra\src\bicep\main.bicep'))
        $global:Task6CapturedCommand = $null

        & $script:BootstrapScriptPath -TenantAlias 'caldova25156897' -TenantConfigurationPath $tenantConfigurationPath -EvidencePath $evidencePath -ParameterFile $parameterFile -TemporaryRoleStatePath $roleStatePath -ConfirmRoleCleanup $true -BootstrapRunId $script:BootstrapRunId -ApprovedRoleAssignmentIds $script:ApprovedRoleAssignmentIds -WhatIfOnly -DiscoveryEvidenceValidator { } -IntentValidator { } -OidcContextValidator { } -BicepValidator { } -RoleStateLoader { param([string]$Path) Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json } -NativeCommandRunner {
            param([string]$FilePath, [string[]]$ArgumentList)

            $global:Task6CapturedCommand = [pscustomobject]@{
                FilePath = $FilePath
                ArgumentList = $ArgumentList
            }

            @{ ExitCode = 0; StdOut = (Get-Content -Raw -LiteralPath $fixturePath); StdErr = '' }
        } -WhatIfBoundaryValidator { param([string]$Path) } -CleanupRunner { param([object]$RoleState) }

        $global:Task6CapturedCommand.FilePath | Should -Be 'az'
        $global:Task6CapturedCommand.ArgumentList | Should -Be @(
            'deployment',
            'sub',
            'what-if',
            '--location', 'switzerlandnorth',
            '--name', 'whatif-caldova25156897-local',
            '--template-file', $expectedMainBicepPath,
            '--parameters', $parameterFile,
            '--result-format', 'FullResourcePayloads',
            '--no-pretty-print'
        )
        $global:Task6CapturedCommand.ArgumentList[8] | Should -BeExactly $expectedMainBicepPath
        $global:Task6CapturedCommand.ArgumentList | Should -Not -Contain 'create'
        Remove-Variable -Name Task6CapturedCommand -Scope Global -ErrorAction SilentlyContinue
    }

    It 'uses the default evidence validator and rejects malformed discovery evidence before native execution' {
        $tenantConfigurationPath = New-TenantConfigurationFile
        $evidencePath = New-EvidenceFile
        $evidenceContent = Get-Content -Raw -LiteralPath $evidencePath
        $evidenceContent = $evidenceContent -replace '(?ms)^\s*"SchemaVersion":\s*"1\.0",\r?\n', ''
        [System.IO.File]::WriteAllText($evidencePath, $evidenceContent, [System.Text.UTF8Encoding]::new($false))
        $parameterFile = New-PlaceholderFile -Name 'main.bicepparam' -Content 'using "../src/bicep/main.bicep"'
        $roleStatePath = New-RoleStateFile

        {
            & $script:BootstrapScriptPath -TenantAlias 'caldova25156897' -TenantConfigurationPath $tenantConfigurationPath -EvidencePath $evidencePath -ParameterFile $parameterFile -TemporaryRoleStatePath $roleStatePath -ConfirmRoleCleanup $true -BootstrapRunId $script:BootstrapRunId -ApprovedRoleAssignmentIds $script:ApprovedRoleAssignmentIds -WhatIfOnly -NativeCommandRunner {
                throw 'native runner should not be reached'
            } -CleanupRunner { throw 'cleanup should not be reached' }
        } | Should -Throw '*Evidence is missing required property SchemaVersion*'
    }

    It 'uses the default intent validator and rejects mismatched existing component evidence before native execution' {
        $tenantConfigurationPath = New-TenantConfigurationFile
        $evidencePath = New-EvidenceFile -EntraServicePrincipalId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
        $parameterFile = New-PlaceholderFile -Name 'main.bicepparam' -Content 'using "../src/bicep/main.bicep"'
        $roleStatePath = New-RoleStateFile

        {
            & $script:BootstrapScriptPath -TenantAlias 'caldova25156897' -TenantConfigurationPath $tenantConfigurationPath -EvidencePath $evidencePath -ParameterFile $parameterFile -TemporaryRoleStatePath $roleStatePath -ConfirmRoleCleanup $true -BootstrapRunId $script:BootstrapRunId -ApprovedRoleAssignmentIds $script:ApprovedRoleAssignmentIds -WhatIfOnly -NativeCommandRunner {
                throw 'native runner should not be reached'
            } -CleanupRunner { throw 'cleanup should not be reached' }
        } | Should -Throw '*exact stable Id match*'
    }

    It 'uses the default OIDC validator and rejects mismatched client id before what-if execution' {
        $tenantConfigurationPath = New-TenantConfigurationFile
        $evidencePath = New-EvidenceFile
        $parameterFile = New-PlaceholderFile -Name 'main.bicepparam' -Content 'using "../src/bicep/main.bicep"'
        $roleStatePath = New-RoleStateFile
        $env:AZURE_TENANT_ID = 'e2312862-df63-440c-8bcf-007a2c52859d'
        $env:AZURE_SUBSCRIPTION_ID = 'edb45a24-408d-47c4-bbc7-685b9b3fc017'
        $env:AZURE_CLIENT_ID = '22222222-2222-2222-2222-222222222222'

        try {
            {
                & $script:BootstrapScriptPath -TenantAlias 'caldova25156897' -TenantConfigurationPath $tenantConfigurationPath -EvidencePath $evidencePath -ParameterFile $parameterFile -TemporaryRoleStatePath $roleStatePath -ConfirmRoleCleanup $true -BootstrapRunId $script:BootstrapRunId -ApprovedRoleAssignmentIds $script:ApprovedRoleAssignmentIds -WhatIfOnly -NativeCommandRunner {
                    param([string]$FilePath, [string[]]$ArgumentList)

                    $joined = $ArgumentList -join ' '
                    if ($joined -eq 'account show --output json') {
                        return [pscustomobject]@{ ExitCode = 0; StdOut = '{"tenantId":"e2312862-df63-440c-8bcf-007a2c52859d","id":"edb45a24-408d-47c4-bbc7-685b9b3fc017","user":{"type":"servicePrincipal","name":"11111111-1111-1111-1111-111111111111"}}'; StdErr = '' }
                    }

                    throw "Unexpected native command: $FilePath $joined"
                } -CleanupRunner { throw 'cleanup should not be reached' }
            } | Should -Throw '*AZURE_CLIENT_ID*'
        }
        finally {
            Remove-Item Env:AZURE_TENANT_ID, Env:AZURE_SUBSCRIPTION_ID, Env:AZURE_CLIENT_ID -ErrorAction SilentlyContinue
        }
    }

    It 'uses the default role-state loader and rejects duplicate assignment ids before what-if execution' {
        $tenantConfigurationPath = New-TenantConfigurationFile
        $evidencePath = New-EvidenceFile
        $parameterFile = New-PlaceholderFile -Name 'main.bicepparam' -Content 'using "../src/bicep/main.bicep"'
        $roleStatePath = New-RoleStateFile
        $roleStateContent = Get-Content -Raw -LiteralPath $roleStatePath
        $roleStateContent = $roleStateContent -replace 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
        [System.IO.File]::WriteAllText($roleStatePath, $roleStateContent, [System.Text.UTF8Encoding]::new($false))
        $env:AZURE_TENANT_ID = 'e2312862-df63-440c-8bcf-007a2c52859d'
        $env:AZURE_SUBSCRIPTION_ID = 'edb45a24-408d-47c4-bbc7-685b9b3fc017'
        $env:AZURE_CLIENT_ID = '11111111-1111-1111-1111-111111111111'

        try {
            {
                & $script:BootstrapScriptPath -TenantAlias 'caldova25156897' -TenantConfigurationPath $tenantConfigurationPath -EvidencePath $evidencePath -ParameterFile $parameterFile -TemporaryRoleStatePath $roleStatePath -ConfirmRoleCleanup $true -BootstrapRunId $script:BootstrapRunId -ApprovedRoleAssignmentIds $script:ApprovedRoleAssignmentIds -WhatIfOnly -NativeCommandRunner {
                    param([string]$FilePath, [string[]]$ArgumentList)

                    $joined = $ArgumentList -join ' '
                    if ($joined -eq 'account show --output json') {
                        return [pscustomobject]@{ ExitCode = 0; StdOut = '{"tenantId":"e2312862-df63-440c-8bcf-007a2c52859d","id":"edb45a24-408d-47c4-bbc7-685b9b3fc017","user":{"type":"servicePrincipal","name":"11111111-1111-1111-1111-111111111111"}}'; StdErr = '' }
                    }

                    throw "Unexpected native command: $FilePath $joined"
                } -CleanupRunner { throw 'cleanup should not be reached' }
            } | Should -Throw '*assignment ids must be unique*'
        }
        finally {
            Remove-Item Env:AZURE_TENANT_ID, Env:AZURE_SUBSCRIPTION_ID, Env:AZURE_CLIENT_ID -ErrorAction SilentlyContinue
        }
    }

    It 'uses the default bicep validator and cleans up after a compiled principal mismatch' {
        $tenantConfigurationPath = New-TenantConfigurationFile
        $evidencePath = New-EvidenceFile
        $parameterFile = New-PlaceholderFile -Name 'main.bicepparam' -Content 'using "../src/bicep/main.bicep"'
        $roleStatePath = New-RoleStateFile
        $cleanupCalls = [System.Collections.Generic.List[string]]::new()
        $env:AZURE_TENANT_ID = 'e2312862-df63-440c-8bcf-007a2c52859d'
        $env:AZURE_SUBSCRIPTION_ID = 'edb45a24-408d-47c4-bbc7-685b9b3fc017'
        $env:AZURE_CLIENT_ID = '11111111-1111-1111-1111-111111111111'

        try {
            {
                & $script:BootstrapScriptPath -TenantAlias 'caldova25156897' -TenantConfigurationPath $tenantConfigurationPath -EvidencePath $evidencePath -ParameterFile $parameterFile -TemporaryRoleStatePath $roleStatePath -ConfirmRoleCleanup $true -BootstrapRunId $script:BootstrapRunId -ApprovedRoleAssignmentIds $script:ApprovedRoleAssignmentIds -WhatIfOnly -NativeCommandRunner {
                    param([string]$FilePath, [string[]]$ArgumentList)

                    $joined = $ArgumentList -join ' '
                    if ($joined -eq 'account show --output json') {
                        return [pscustomobject]@{ ExitCode = 0; StdOut = '{"tenantId":"e2312862-df63-440c-8bcf-007a2c52859d","id":"edb45a24-408d-47c4-bbc7-685b9b3fc017","user":{"type":"servicePrincipal","name":"11111111-1111-1111-1111-111111111111"}}'; StdErr = '' }
                    }

                    if ($joined -match '^bicep build --file .+main\.bicep --stdout$') {
                        return [pscustomobject]@{ ExitCode = 0; StdOut = '{"template":"ok"}'; StdErr = '' }
                    }

                    if ($joined -match '^bicep build-params --file .+main\.bicepparam --stdout$') {
                        $parameterDocument = [ordered]@{
                            parameters = [ordered]@{
                                tenant = [ordered]@{
                                    value = [ordered]@{
                                        tenantAlias = 'caldova25156897'
                                        location = 'switzerlandnorth'
                                        namingRoot = 'cal-hr-agentic-bc8rbt'
                                        validationPrincipalId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
                                    }
                                }
                            }
                        }
                        $payload = [ordered]@{ parametersJson = ($parameterDocument | ConvertTo-Json -Depth 10 -Compress) } | ConvertTo-Json -Depth 10 -Compress
                        return [pscustomobject]@{ ExitCode = 0; StdOut = $payload; StdErr = '' }
                    }

                    throw "Unexpected native command: $FilePath $joined"
                } -CleanupRunner { param([object]$RoleState) $cleanupCalls.Add([string]$RoleState.RunId) | Out-Null }
            } | Should -Throw '*validationPrincipalId*accepted temporary role state*'

            $cleanupCalls | Should -Be @($script:BootstrapRunId)
        }
        finally {
            Remove-Item Env:AZURE_TENANT_ID, Env:AZURE_SUBSCRIPTION_ID, Env:AZURE_CLIENT_ID -ErrorAction SilentlyContinue
        }
    }

    It 'runs the complete default orchestration path through only the low-level native runner' -Tag 'ReviewFixRound2Slice5' {
        $tenantConfigurationPath = New-TenantConfigurationFile
        $evidencePath = New-EvidenceFile -CompletedUtc ([datetime]::UtcNow.ToString('o'))
        $parameterFile = New-PlaceholderFile -Name 'default-path-main.bicepparam' -Content 'using "../src/bicep/main.bicep"'
        $roleStatePath = New-RoleStateFile
        $expectedMainBicepPath = [System.IO.Path]::GetFullPath((Join-Path $script:RepositoryRoot 'infra\src\bicep\main.bicep'))
        $expectedScope = '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017'
        $contributorId = [string]$script:ApprovedRoleAssignmentIds[0]
        $rbacAdministratorId = [string]$script:ApprovedRoleAssignmentIds[1]
        $contributorRoleDefinitionId = "$expectedScope/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c"
        $rbacAdministratorRoleDefinitionId = "$expectedScope/providers/Microsoft.Authorization/roleDefinitions/f58310d9-a9f6-439a-9e8d-f62e7b41a168"
        $assignmentPresent = @{
            $contributorId = $true
            $rbacAdministratorId = $true
        }
        $nativeCalls = [System.Collections.Generic.List[object]]::new()
        $whatIfPayload = Get-Content -Raw -LiteralPath $script:FixturePath
        $compiledTemplate = [ordered]@{
            '$schema' = 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
            contentVersion = '1.0.0.0'
            parameters = [ordered]@{}
            variables = [ordered]@{}
            resources = @()
            outputs = [ordered]@{}
        } | ConvertTo-Json -Depth 10 -Compress
        $compiledParameterDocument = [ordered]@{
            '$schema' = 'https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#'
            contentVersion = '1.0.0.0'
            parameters = [ordered]@{
                tenant = [ordered]@{
                    value = [ordered]@{
                        tenantAlias = 'caldova25156897'
                        location = 'switzerlandnorth'
                        namingRoot = 'cal-hr-agentic-bc8rbt'
                        validationPrincipalId = '55555555-5555-5555-5555-555555555555'
                    }
                }
            }
        }
        $compiledParameters = [ordered]@{
            parametersJson = ($compiledParameterDocument | ConvertTo-Json -Depth 10 -Compress)
            templateJson = $compiledTemplate
            templateSpecId = $null
        } | ConvertTo-Json -Depth 10 -Compress
        $accountPayload = [ordered]@{
            environmentName = 'AzureCloud'
            homeTenantId = 'e2312862-df63-440c-8bcf-007a2c52859d'
            id = 'edb45a24-408d-47c4-bbc7-685b9b3fc017'
            isDefault = $true
            managedByTenants = @()
            name = 'Caldova25156897'
            state = 'Enabled'
            tenantDefaultDomain = 'Caldova25156897.onmicrosoft.com'
            tenantDisplayName = 'Caldova25156897'
            tenantId = 'e2312862-df63-440c-8bcf-007a2c52859d'
            user = [ordered]@{
                name = '11111111-1111-1111-1111-111111111111'
                type = 'servicePrincipal'
            }
        } | ConvertTo-Json -Depth 10 -Compress
        $nativeRunner = {
            param(
                [string]$FilePath,
                [string[]]$ArgumentList
            )

            $nativeCalls.Add([pscustomobject]@{
                FilePath = $FilePath
                ArgumentList = @($ArgumentList)
            }) | Out-Null

            if ($FilePath -cne 'az') {
                throw "Unexpected native executable: $FilePath"
            }

            if ($ArgumentList.Count -eq 4 -and $ArgumentList[0] -ceq 'account' -and $ArgumentList[1] -ceq 'show' -and $ArgumentList[2] -ceq '--output' -and $ArgumentList[3] -ceq 'json') {
                return [pscustomobject]@{ ExitCode = 0; StdOut = $accountPayload; StdErr = '' }
            }

            if ($ArgumentList.Count -eq 5 -and $ArgumentList[0] -ceq 'bicep' -and $ArgumentList[1] -ceq 'build' -and $ArgumentList[2] -ceq '--file' -and $ArgumentList[3] -ceq $expectedMainBicepPath -and $ArgumentList[4] -ceq '--stdout') {
                return [pscustomobject]@{ ExitCode = 0; StdOut = $compiledTemplate; StdErr = '' }
            }

            if ($ArgumentList.Count -eq 5 -and $ArgumentList[0] -ceq 'bicep' -and $ArgumentList[1] -ceq 'build-params' -and $ArgumentList[2] -ceq '--file' -and $ArgumentList[3] -ceq $parameterFile -and $ArgumentList[4] -ceq '--stdout') {
                return [pscustomobject]@{ ExitCode = 0; StdOut = $compiledParameters; StdErr = '' }
            }

            if ($ArgumentList.Count -eq 14 -and $ArgumentList[0] -ceq 'deployment' -and $ArgumentList[1] -ceq 'sub' -and $ArgumentList[2] -ceq 'what-if') {
                return [pscustomobject]@{ ExitCode = 0; StdOut = $whatIfPayload; StdErr = '' }
            }

            if ($ArgumentList.Count -eq 7 -and $ArgumentList[0] -ceq 'rest' -and $ArgumentList[1] -ceq '--method' -and $ArgumentList[2] -ceq 'get' -and $ArgumentList[3] -ceq '--url' -and $ArgumentList[5] -ceq '--output' -and $ArgumentList[6] -ceq 'json') {
                $assignmentId = [string]$ArgumentList[4] -replace '\?api-version=2022-04-01$', ''
                if ($assignmentId -notin @($contributorId, $rbacAdministratorId)) {
                    throw "Unexpected role-assignment read: $assignmentId"
                }
                if (-not $assignmentPresent[$assignmentId]) {
                    $errorPayload = [ordered]@{
                        error = [ordered]@{
                            code = 'RoleAssignmentNotFound'
                            message = "The role assignment '$assignmentId' was not found."
                        }
                    } | ConvertTo-Json -Depth 10 -Compress
                    return [pscustomobject]@{
                        ExitCode = 1
                        StatusCode = 404
                        ErrorCode = 'RoleAssignmentNotFound'
                        StdOut = ''
                        StdErr = $errorPayload
                    }
                }

                $roleDefinitionId = if ($assignmentId -ceq $contributorId) {
                    $contributorRoleDefinitionId
                }
                else {
                    $rbacAdministratorRoleDefinitionId
                }
                $assignmentPayload = [ordered]@{
                    id = $assignmentId
                    name = [string]($assignmentId -split '/')[-1]
                    type = 'Microsoft.Authorization/roleAssignments'
                    properties = [ordered]@{
                        roleDefinitionId = $roleDefinitionId
                        principalId = '55555555-5555-5555-5555-555555555555'
                        principalType = 'ServicePrincipal'
                        scope = $expectedScope
                        condition = $null
                        conditionVersion = $null
                        createdOn = '2026-09-19T10:00:00Z'
                        updatedOn = '2026-09-19T10:00:00Z'
                        createdBy = '99999999-9999-9999-9999-999999999999'
                        updatedBy = '99999999-9999-9999-9999-999999999999'
                        delegatedManagedIdentityResourceId = $null
                        description = $null
                    }
                } | ConvertTo-Json -Depth 10 -Compress
                return [pscustomobject]@{ ExitCode = 0; StdOut = $assignmentPayload; StdErr = '' }
            }

            if ($ArgumentList.Count -eq 7 -and $ArgumentList[0] -ceq 'role' -and $ArgumentList[1] -ceq 'assignment' -and $ArgumentList[2] -ceq 'delete' -and $ArgumentList[3] -ceq '--ids' -and $ArgumentList[5] -ceq '--output' -and $ArgumentList[6] -ceq 'none') {
                $assignmentId = [string]$ArgumentList[4]
                if ($assignmentId -notin @($contributorId, $rbacAdministratorId)) {
                    throw "Unexpected role-assignment deletion: $assignmentId"
                }

                $assignmentPresent[$assignmentId] = $false
                return [pscustomobject]@{ ExitCode = 0; StdOut = ''; StdErr = '' }
            }

            throw "Unexpected native command: $FilePath $($ArgumentList -join ' ')"
        }

        $tenantIdWasPresent = Test-Path Env:AZURE_TENANT_ID
        $subscriptionIdWasPresent = Test-Path Env:AZURE_SUBSCRIPTION_ID
        $clientIdWasPresent = Test-Path Env:AZURE_CLIENT_ID
        $githubRunIdWasPresent = Test-Path Env:GITHUB_RUN_ID
        $runnerTempWasPresent = Test-Path Env:RUNNER_TEMP
        $previousTenantId = $env:AZURE_TENANT_ID
        $previousSubscriptionId = $env:AZURE_SUBSCRIPTION_ID
        $previousClientId = $env:AZURE_CLIENT_ID
        $previousGithubRunId = $env:GITHUB_RUN_ID
        $previousRunnerTemp = $env:RUNNER_TEMP

        try {
            $env:AZURE_TENANT_ID = 'e2312862-df63-440c-8bcf-007a2c52859d'
            $env:AZURE_SUBSCRIPTION_ID = 'edb45a24-408d-47c4-bbc7-685b9b3fc017'
            $env:AZURE_CLIENT_ID = '11111111-1111-1111-1111-111111111111'
            $env:GITHUB_RUN_ID = '987654321'
            $env:RUNNER_TEMP = $TestDrive

            $result = & $script:BootstrapScriptPath -TenantAlias 'caldova25156897' -TenantConfigurationPath $tenantConfigurationPath -EvidencePath $evidencePath -ParameterFile $parameterFile -TemporaryRoleStatePath $roleStatePath -ConfirmRoleCleanup $true -BootstrapRunId $script:BootstrapRunId -ApprovedRoleAssignmentIds $script:ApprovedRoleAssignmentIds -WhatIfOnly -NativeCommandRunner $nativeRunner

            @($result.PSObject.Properties.Name) | Should -Be @('TenantAlias', 'WhatIfOnly', 'TemporaryRoleStatePath')
            $result.TenantAlias | Should -BeExactly 'caldova25156897'
            $result.WhatIfOnly | Should -BeTrue
            $result.TemporaryRoleStatePath | Should -BeExactly $roleStatePath

            $nativeCalls.Count | Should -Be 10
            $nativeCalls[0].FilePath | Should -BeExactly 'az'
            $nativeCalls[0].ArgumentList | Should -Be @('account', 'show', '--output', 'json')
            $nativeCalls[1].ArgumentList | Should -Be @('bicep', 'build', '--file', $expectedMainBicepPath, '--stdout')
            $nativeCalls[2].ArgumentList | Should -Be @('bicep', 'build-params', '--file', $parameterFile, '--stdout')
            $nativeCalls[3].ArgumentList | Should -Be @(
                'deployment',
                'sub',
                'what-if',
                '--location', 'switzerlandnorth',
                '--name', 'whatif-caldova25156897-987654321',
                '--template-file', $expectedMainBicepPath,
                '--parameters', $parameterFile,
                '--result-format', 'FullResourcePayloads',
                '--no-pretty-print'
            )
            $nativeCalls[3].ArgumentList[8] | Should -BeExactly $expectedMainBicepPath
            $nativeCalls[4].ArgumentList | Should -Be @('rest', '--method', 'get', '--url', "${contributorId}?api-version=2022-04-01", '--output', 'json')
            $nativeCalls[5].ArgumentList | Should -Be @('role', 'assignment', 'delete', '--ids', $contributorId, '--output', 'none')
            $nativeCalls[6].ArgumentList | Should -Be @('rest', '--method', 'get', '--url', "${rbacAdministratorId}?api-version=2022-04-01", '--output', 'json')
            $nativeCalls[7].ArgumentList | Should -Be @('role', 'assignment', 'delete', '--ids', $rbacAdministratorId, '--output', 'none')
            $nativeCalls[8].ArgumentList | Should -Be $nativeCalls[4].ArgumentList
            $nativeCalls[9].ArgumentList | Should -Be $nativeCalls[6].ArgumentList

            $deleteCalls = @($nativeCalls | Where-Object { $_.ArgumentList.Count -ge 3 -and $_.ArgumentList[0] -ceq 'role' -and $_.ArgumentList[1] -ceq 'assignment' -and $_.ArgumentList[2] -ceq 'delete' })
            @($deleteCalls | ForEach-Object { [string]$_.ArgumentList[4] }) | Should -Be @($contributorId, $rbacAdministratorId)
            @($deleteCalls | Where-Object { $_.ArgumentList -contains '--assignee' -or $_.ArgumentList -contains '--assignee-object-id' -or $_.ArgumentList -contains '--role' -or $_.ArgumentList -contains '--scope' }).Count | Should -Be 0
            @($nativeCalls | Where-Object { $_.ArgumentList -contains 'create' }).Count | Should -Be 0
        }
        finally {
            if ($tenantIdWasPresent) { $env:AZURE_TENANT_ID = $previousTenantId } else { Remove-Item Env:AZURE_TENANT_ID -ErrorAction SilentlyContinue }
            if ($subscriptionIdWasPresent) { $env:AZURE_SUBSCRIPTION_ID = $previousSubscriptionId } else { Remove-Item Env:AZURE_SUBSCRIPTION_ID -ErrorAction SilentlyContinue }
            if ($clientIdWasPresent) { $env:AZURE_CLIENT_ID = $previousClientId } else { Remove-Item Env:AZURE_CLIENT_ID -ErrorAction SilentlyContinue }
            if ($githubRunIdWasPresent) { $env:GITHUB_RUN_ID = $previousGithubRunId } else { Remove-Item Env:GITHUB_RUN_ID -ErrorAction SilentlyContinue }
            if ($runnerTempWasPresent) { $env:RUNNER_TEMP = $previousRunnerTemp } else { Remove-Item Env:RUNNER_TEMP -ErrorAction SilentlyContinue }
        }
    }
}