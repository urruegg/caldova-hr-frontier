Set-StrictMode -Version Latest

Describe 'Workstation prerequisite policy' {
    BeforeAll {
        $script:Repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
        $script:PolicyPath = Join-Path $script:Repo 'infra\src\config\runbooks\workstation-prerequisites.json'
        $script:SchemaPath = Join-Path $script:Repo 'infra\src\config\schemas\workstation-prerequisites.schema.json'
        $script:InvalidPath = Join-Path $script:Repo 'infra\tests\fixtures\runbooks\workstation-prerequisites.invalid.json'
        $script:Pwsh = (Get-Command pwsh.exe -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
    }

    It 'validates the reviewed policy and rejects an unknown property with the closed schema' {
        & $script:Pwsh -NoProfile -Command {
            param($policy, $schema)
            if (-not (Test-Json -Json (Get-Content -Raw $policy) -SchemaFile $schema)) { exit 1 }
        } -args $script:PolicyPath, $script:SchemaPath
        $LASTEXITCODE | Should -Be 0

        & $script:Pwsh -NoProfile -Command {
            param($fixture, $schema)
            if (Test-Json -Json (Get-Content -Raw $fixture) -SchemaFile $schema -ErrorAction SilentlyContinue) { exit 1 }
        } -args $script:InvalidPath, $script:SchemaPath
        $LASTEXITCODE | Should -Be 0

        $rootOnlyInvalid = Get-Content -Raw $script:InvalidPath | ConvertFrom-Json
        $rootOnlyInvalid.PSObject.Properties.Remove('unexpected')
        $withoutUnexpectedPath = Join-Path $TestDrive 'workstation-prerequisites.without-unexpected.json'
        [IO.File]::WriteAllText(
            $withoutUnexpectedPath,
            ($rootOnlyInvalid | ConvertTo-Json -Depth 20),
            [Text.UTF8Encoding]::new($false)
        )
        & $script:Pwsh -NoProfile -Command {
            param($fixture, $schema)
            if (-not (Test-Json -Json (Get-Content -Raw $fixture) -SchemaFile $schema -ErrorAction SilentlyContinue)) { exit 1 }
        } -args $withoutUnexpectedPath, $script:SchemaPath
        $LASTEXITCODE | Should -Be 0
    }

    It 'contains the exact reviewed tool and extension allowlists' {
        $policy = Get-Content -Raw $script:PolicyPath | ConvertFrom-Json
        @($policy.tools.id) | Should -Be @(
            'PowerShell7', 'WindowsPowerShell', 'Git', 'VisualStudioCode',
            'GitHubCli', 'AzureCli', 'AzureDeveloperCli', 'PowerPlatformCli',
            'Bicep', 'Pester', 'GitHubCopilotCli'
        )
        @($policy.azureCliExtensions.name) | Should -Be @('azure-devops')
        @($policy.vsCodeExtensions.id) | Should -Be @(
            'ms-vscode.PowerShell', 'ms-azuretools.vscode-bicep',
            'ms-azuretools.azure-dev', 'microsoft-IsvExpTools.powerplatform-vscode',
            'GitHub.copilot'
        )
    }

    It 'rejects cross-wired and arbitrary tool contracts' {
        $crossWired = Get-Content -Raw $script:PolicyPath | ConvertFrom-Json
        $crossWired.tools[0].command = 'git.exe'
        $crossWiredPath = Join-Path $TestDrive 'workstation-prerequisites.cross-wired.json'
        [IO.File]::WriteAllText(
            $crossWiredPath,
            ($crossWired | ConvertTo-Json -Depth 20),
            [Text.UTF8Encoding]::new($false)
        )
        & $script:Pwsh -NoProfile -Command {
            param($fixture, $schema)
            if (Test-Json -Json (Get-Content -Raw $fixture) -SchemaFile $schema -ErrorAction SilentlyContinue) { exit 1 }
        } -args $crossWiredPath, $script:SchemaPath
        $LASTEXITCODE | Should -Be 0

        $arbitrary = Get-Content -Raw $script:PolicyPath | ConvertFrom-Json
        $arbitrary.tools[0].id = 'ArbitraryTool'
        $arbitraryPath = Join-Path $TestDrive 'workstation-prerequisites.arbitrary.json'
        [IO.File]::WriteAllText(
            $arbitraryPath,
            ($arbitrary | ConvertTo-Json -Depth 20),
            [Text.UTF8Encoding]::new($false)
        )
        & $script:Pwsh -NoProfile -Command {
            param($fixture, $schema)
            if (Test-Json -Json (Get-Content -Raw $fixture) -SchemaFile $schema -ErrorAction SilentlyContinue) { exit 1 }
        } -args $arbitraryPath, $script:SchemaPath
        $LASTEXITCODE | Should -Be 0

        $missing = Get-Content -Raw $script:PolicyPath | ConvertFrom-Json
        $missing.tools = @($missing.tools | Select-Object -Skip 1)
        $missingPath = Join-Path $TestDrive 'workstation-prerequisites.missing-tool.json'
        [IO.File]::WriteAllText(
            $missingPath,
            ($missing | ConvertTo-Json -Depth 20),
            [Text.UTF8Encoding]::new($false)
        )
        & $script:Pwsh -NoProfile -Command {
            param($fixture, $schema)
            if (Test-Json -Json (Get-Content -Raw $fixture) -SchemaFile $schema -ErrorAction SilentlyContinue) { exit 1 }
        } -args $missingPath, $script:SchemaPath
        $LASTEXITCODE | Should -Be 0
    }

    It 'treats repository skills agents and plugins as verification-only assets' {
        $policy = Get-Content -Raw $script:PolicyPath | ConvertFrom-Json
        @($policy.repositoryAssets.installDisposition | Select-Object -Unique) |
            Should -Be @('VerifyOnly')
        ($policy.repositoryAssets | Where-Object path -eq '.github/skills').expected |
            Should -Be 'Present'
        ($policy.repositoryAssets | Where-Object path -eq '.github/agents').expected |
            Should -Be 'Present'
        ($policy.repositoryAssets | Where-Object path -eq '.github/plugins').expected |
            Should -Be 'Absent'
    }

    It 'permits only attended delegated authentication and no workload identity' {
        $policy = Get-Content -Raw $script:PolicyPath | ConvertFrom-Json
        $policy.interactiveAuthentication.executionHost | Should -Be 'InteractiveWindows11PowerShell'
        $policy.interactiveAuthentication.allowUnattendedExecution | Should -BeFalse
        $policy.interactiveAuthentication.allowOidcWorkloadIdentity | Should -BeFalse
        $policy.interactiveAuthentication.allowCredentialParameters | Should -BeFalse
        @($policy.interactiveAuthentication.methods.service) |
            Should -Be @('Azure', 'GitHub', 'AzureDevOps', 'PowerPlatform')
        ($policy | ConvertTo-Json -Depth 20) |
            Should -Not -Match '(?i)(client.?secret|personal.?access.?token|federated.?credential)'
    }
}
