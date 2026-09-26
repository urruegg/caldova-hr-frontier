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
