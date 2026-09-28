Set-StrictMode -Version Latest

Describe 'Tenant naming' {
    BeforeAll {
        $script:ModuleManifestPath = Join-Path $PSScriptRoot '..\..\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1'
        Import-Module $script:ModuleManifestPath -Force
    }

    It 'generates six lowercase alphanumeric characters' {
        New-TenantSuffix | Should -Match '^[a-z0-9]{6}$'
    }

    It 'derives deterministic Azure names within resource constraints' {
        Get-TenantResourceName -NamingRoot 'cal-hr-agentic-a7k29x' -ResourceType ResourceGroup |
            Should -Be 'rg-cal-hr-agentic-a7k29x-platform'
        Get-TenantResourceName -NamingRoot 'cal-hr-agentic-a7k29x' -ResourceType LogAnalytics |
            Should -Be 'log-cal-hr-agentic-a7k29x'
        Get-TenantResourceName -NamingRoot 'cal-hr-agentic-a7k29x' -ResourceType DeploymentValidationRole |
            Should -Be 'cal-hr-agentic-a7k29x-deployment-validation'
    }

    It 'rejects invalid resource type and naming root inputs' {
        { Get-TenantResourceName -NamingRoot 'bad-root' -ResourceType ResourceGroup } | Should -Throw
        { Get-TenantResourceName -NamingRoot 'cal-hr-agentic-a7k29x' -ResourceType 'Storage' } | Should -Throw
    }

    It 'derives the exact approved Tenant 1 lowercase OIDC subject' {
        Get-GitHubOidcSubject `
            -Owner urruegg `
            -OwnerId '46865858' `
            -Repository caldova-hr-frontier `
            -RepositoryId '1371297722' `
            -TenantAlias caldova25156897 |
            Should -Be 'repo:urruegg@46865858/caldova-hr-frontier@1371297722:environment:bootstrap-caldova25156897'
    }

    It 'derives the immutable repository prefix separately from the Environment subject' {
        Get-GitHubOidcSubject `
            -Owner urruegg `
            -OwnerId '46865858' `
            -Repository caldova-hr-frontier `
            -RepositoryId '1371297722' `
            -TenantAlias caldova25156897 `
            -PrefixOnly |
            Should -Be 'repo:urruegg@46865858/caldova-hr-frontier@1371297722'
    }

    It 'preserves mixed-case owner and repository names exactly in the OIDC subject' {
        Get-GitHubOidcSubject `
            -Owner UrrUegg `
            -OwnerId '46865858' `
            -Repository Caldova-HR-Frontier `
            -RepositoryId '1371297722' `
            -TenantAlias caldova25156897 |
            Should -Be 'repo:UrrUegg@46865858/Caldova-HR-Frontier@1371297722:environment:bootstrap-caldova25156897'
    }

    It 'rejects invalid immutable OIDC subject inputs' {
        { Get-GitHubOidcSubject -Owner 'urruegg ' -OwnerId '46865858' -Repository caldova-hr-frontier -RepositoryId '1371297722' -TenantAlias caldova25156897 } | Should -Throw
        { Get-GitHubOidcSubject -Owner urruegg -OwnerId '046865858x' -Repository caldova-hr-frontier -RepositoryId '1371297722' -TenantAlias caldova25156897 } | Should -Throw
        { Get-GitHubOidcSubject -Owner urruegg -OwnerId '46865858' -Repository 'caldova-hr-frontier ' -RepositoryId '1371297722' -TenantAlias caldova25156897 } | Should -Throw
    }
}

Describe 'Tenant manifest generation' {
    BeforeAll {
        $script:ManifestScriptPath = Join-Path $PSScriptRoot '..\..\src\scripts\New-TenantManifest.ps1'
        function script:New-IsolatedTask2Harness {
            $root = Join-Path $TestDrive ([guid]::NewGuid().ToString())
            $directories = @(
                'infra\src\config\schemas',
                'infra\src\config\tenants',
                'infra\src\scripts',
                'infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Public'
            )

            foreach ($directory in $directories) {
                [void](New-Item -ItemType Directory -Path (Join-Path $root $directory) -Force)
            }

            $copies = @(
                @('infra\src\config\schemas\tenant.schema.json', 'infra\src\config\schemas\tenant.schema.json'),
                @('infra\src\config\tenants\_template.psd1', 'infra\src\config\tenants\_template.psd1'),
                @('infra\src\scripts\New-TenantManifest.ps1', 'infra\src\scripts\New-TenantManifest.ps1'),
                @('infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1', 'infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1'),
                @('infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psm1', 'infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psm1'),
                @('infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Public\Import-TenantConfiguration.ps1', 'infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Public\Import-TenantConfiguration.ps1'),
                @('infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Public\New-TenantSuffix.ps1', 'infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Public\New-TenantSuffix.ps1'),
                @('infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Public\Get-TenantResourceName.ps1', 'infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Public\Get-TenantResourceName.ps1'),
                @('infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Public\Get-GitHubOidcSubject.ps1', 'infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Public\Get-GitHubOidcSubject.ps1')
            )

            $workspaceRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
            foreach ($copy in $copies) {
                Copy-Item -LiteralPath (Join-Path $workspaceRoot $copy[0]) -Destination (Join-Path $root $copy[1]) -Force
            }

            return $root
        }
        function script:Get-CommandAstCount {
            param(
                [string]$Path,
                [string]$CommandName
            )

            $tokens = $null
            $errors = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)
            if ($errors.Count -gt 0) {
                throw "Parse failed for $Path"
            }

            @($ast.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.CommandAst] -and
                    $node.GetCommandName() -eq $CommandName
            }, $true)).Count
        }
    }
    It 'calls New-TenantSuffix exactly once and writes a validated BOM-free manifest with fixed key order' {
        Get-CommandAstCount -Path $script:ManifestScriptPath -CommandName 'New-TenantSuffix' | Should -Be 1

        $root = New-IsolatedTask2Harness
        $scriptPath = Join-Path $root 'infra\src\scripts\New-TenantManifest.ps1'
        $manifestPath = Join-Path $root 'infra\src\config\tenants\caldova25156897.psd1'

        Remove-Module Caldova.HrFrontier.Bootstrap -Force -ErrorAction SilentlyContinue
        $output = & $scriptPath -TenantAlias caldova25156897 2>&1 | Out-String

        Test-Path -LiteralPath $manifestPath | Should -BeTrue
        $bytes = [System.IO.File]::ReadAllBytes($manifestPath)
        ($bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191) | Should -BeFalse
        $output | Should -Match 'Assigned suffix:'
        $output | Should -Match 'Naming root: cal-hr-agentic-[a-z0-9]{6}'
        $output | Should -Not -Match 'admin@Caldova25156897.onmicrosoft.com'

        $content = [System.Text.Encoding]::UTF8.GetString($bytes)
        $expectedOrder = @(
            "SchemaVersion = '1.0'",
            "TenantAlias = 'caldova25156897'",
            "DisplayName = 'Caldova25156897'",
            "TenantId = 'e2312862-df63-440c-8bcf-007a2c52859d'",
            "AdminUpn = 'admin@Caldova25156897.onmicrosoft.com'",
            "SubscriptionId = 'edb45a24-408d-47c4-bbc7-685b9b3fc017'",
            "PrimaryLocation = 'switzerlandnorth'",
            "CompanyTla = 'cal'",
            "WorkloadName = 'hr-agentic'",
            'UniqueSuffix = ',
            'NamingRoot = ',
            "LifecycleState = 'DiscoveryRequired'",
            'GitHub = @{',
            'AzureDevOps = @{',
            'PowerPlatform = @{',
            'Components = @{}'
        )

        $positions = foreach ($marker in $expectedOrder) {
            $index = $content.IndexOf($marker)
            $index | Should -BeGreaterThan -1
            $index
        }
        ($positions -join ',') | Should -Be (($positions | Sort-Object) -join ',')

        $modulePath = Join-Path $root 'infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1'
        Remove-Module Caldova.HrFrontier.Bootstrap -Force -ErrorAction SilentlyContinue
        Import-Module $modulePath -Force
        $config = Import-TenantConfiguration -Path $manifestPath -ValidationStage Discovery
        @($config.Components | Get-Member -MemberType NoteProperty, Property, ScriptProperty).Count | Should -Be 0
    }

    It 'refuses to overwrite an existing manifest' {
        $root = New-IsolatedTask2Harness
        $scriptPath = Join-Path $root 'infra\src\scripts\New-TenantManifest.ps1'

        Remove-Module Caldova.HrFrontier.Bootstrap -Force -ErrorAction SilentlyContinue
        & $scriptPath -TenantAlias caldova25156897 | Out-Null

        { & $scriptPath -TenantAlias caldova25156897 | Out-Null } | Should -Throw
    }

    It 'removes invalid output when immediate validation fails' {
        $root = New-IsolatedTask2Harness
        $scriptPath = Join-Path $root 'infra\src\scripts\New-TenantManifest.ps1'
        $schemaPath = Join-Path $root 'infra\src\config\schemas\tenant.schema.json'
        $manifestPath = Join-Path $root 'infra\src\config\tenants\caldova25156897.psd1'

        $schema = Get-Content -Raw -LiteralPath $schemaPath
        $schema = $schema.Replace('"hr-agentic"', '"hr-agentic-impossible"')
        [System.IO.File]::WriteAllText($schemaPath, $schema, [System.Text.UTF8Encoding]::new($false))

        Remove-Module Caldova.HrFrontier.Bootstrap -Force -ErrorAction SilentlyContinue
        { & $scriptPath -TenantAlias caldova25156897 | Out-Null } | Should -Throw
        Test-Path -LiteralPath $manifestPath | Should -BeFalse
    }
}