BeforeAll {
    $script:repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
    $script:validatorPath = Join-Path $script:repositoryRoot '.github\cli\verify-repository-safety.ps1'

    function script:New-SafetyFixture {
        param([string]$Content = 'Write-Output ''safe''')

        $root = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        $scriptRoot = Join-Path $root 'infra\src\scripts'
        $workflowRoot = Join-Path $root '.github\workflows'
        [void](New-Item -ItemType Directory -Path $scriptRoot -Force)
        [void](New-Item -ItemType Directory -Path $workflowRoot -Force)
        [IO.File]::WriteAllText((Join-Path $scriptRoot 'Example.ps1'), $Content, [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllText((Join-Path $workflowRoot 'bootstrap-tenant.yml'), "name: safe`n", [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllText((Join-Path $workflowRoot 'discover-tenant.yml'), "name: safe`n", [Text.UTF8Encoding]::new($false))
        $root
    }
}

Describe 'Core repository safety validation' {
    It 'resolves its own repository root when invoked without -RepositoryRoot' {
        # The CI workflow step runs this script via `-File` with no
        # -RepositoryRoot argument, which exercises the parameter default
        # value in a way that `& $script:validatorPath -RepositoryRoot ...`
        # calls elsewhere in this file do not. Regression test for
        # ParameterArgumentValidationErrorEmptyStringNotAllowed on $PSScriptRoot.
        $output = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $script:validatorPath 2>&1 | ForEach-Object { $_.ToString() })

        $LASTEXITCODE | Should -Be 0
        $output | Should -Contain 'Repository safety validation passed.'
    }

    It 'accepts scripts and workflows without deployment execution or credentials' {
        $script:validatorPath | Should -Exist
        $fixtureRoot = New-SafetyFixture

        $output = @(& $script:validatorPath -RepositoryRoot $fixtureRoot)

        $output | Should -Be @('Repository safety validation passed.')
    }

    It 'rejects prohibited bootstrap content' -TestCases @(
        @{ Content = 'az deployment sub create --location switzerlandnorth' }
        @{ Content = 'New-AzSubscriptionDeployment -Location switzerlandnorth' }
        @{ Content = 'AZURE_CLIENT_SECRET=not-a-real-secret' }
        @{ Content = '--password not-a-real-password' }
    ) {
        param([string]$Content)

        $fixtureRoot = New-SafetyFixture -Content $Content
        $output = @(& $script:validatorPath -RepositoryRoot $fixtureRoot 2>&1 | ForEach-Object { $_.ToString() })

        $LASTEXITCODE | Should -Be 1
        $output -join "`n" | Should -Match 'Prohibited bootstrap command or credential pattern found'
    }

    It 'scans every repository workflow' {
        $fixtureRoot = New-SafetyFixture
        $workflowPath = Join-Path $fixtureRoot '.github\workflows\other.yml'
        [IO.File]::WriteAllText($workflowPath, 'run: command --password not-a-real-password', [Text.UTF8Encoding]::new($false))

        $output = @(& $script:validatorPath -RepositoryRoot $fixtureRoot 2>&1 | ForEach-Object { $_.ToString() })

        $LASTEXITCODE | Should -Be 1
        $output -join "`n" | Should -Match 'other\.yml'
    }
}