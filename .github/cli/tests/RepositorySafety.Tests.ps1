BeforeAll {
    $script:repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
    $script:validatorPath = Join-Path $script:repositoryRoot '.github\cli\verify-repository-safety.ps1'

    function script:New-SafetyFixture {
                param(
                        [string]$Content = 'Write-Output ''safe''',
                        [string]$WorkflowContent = @'
steps:
    - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
'@,
                        [string]$ManifestContent = @'
{
    "schemaVersion": "1.0",
    "actions": {
        "actions/checkout": {
            "sourceRef": "v7.0.1",
            "sha": "3d3c42e5aac5ba805825da76410c181273ba90b1"
        }
    }
}
'@
                )

        $root = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        $scriptRoot = Join-Path $root 'infra\src\scripts'
        $workflowRoot = Join-Path $root '.github\workflows'
                $manifestRoot = Join-Path $root 'infra\src\config\github'
        [void](New-Item -ItemType Directory -Path $scriptRoot -Force)
        [void](New-Item -ItemType Directory -Path $workflowRoot -Force)
                [void](New-Item -ItemType Directory -Path $manifestRoot -Force)
        [IO.File]::WriteAllText((Join-Path $scriptRoot 'Example.ps1'), $Content, [Text.UTF8Encoding]::new($false))
                [IO.File]::WriteAllText((Join-Path $workflowRoot 'validate.yml'), $WorkflowContent, [Text.UTF8Encoding]::new($false))
                [IO.File]::WriteAllText((Join-Path $manifestRoot 'action-pins.json'), $ManifestContent, [Text.UTF8Encoding]::new($false))
        $root
    }
}

Describe 'Core repository safety validation' {
    It 'treats PDF corpus files as binary on every Git installation' {
        $pdfPath = 'hr/docs/ideas/uc-0001-personal-master-data-completion-agent/gf-aib-fixed-template/documents/a-personalblatt/a01-CAND-2026-0411-brunner.pdf'

        $attributes = @(
            & git -C $script:repositoryRoot check-attr text diff merge -- $pdfPath
        )

        $LASTEXITCODE | Should -Be 0
        $attributes | Should -Contain "$pdfPath`: text: unset"
        $attributes | Should -Contain "$pdfPath`: diff: unset"
        $attributes | Should -Contain "$pdfPath`: merge: unset"
    }

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

    It 'accepts exact external pins and ignores repository-local actions' {
        $fixtureRoot = New-SafetyFixture -WorkflowContent @'
steps:
  - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
  - uses: ./.github/actions/local
'@

        $output = @(& $script:validatorPath -RepositoryRoot $fixtureRoot)

        $output | Should -Be @('Repository safety validation passed.')
    }

    It 'rejects <Reason>' -TestCases @(
        @{
            Reason = 'an unknown external action'
            WorkflowContent = 'steps:
  - uses: owner/unknown@1111111111111111111111111111111111111111'
            ManifestContent = '{"schemaVersion":"1.0","actions":{"actions/checkout":{"sourceRef":"v7.0.1","sha":"3d3c42e5aac5ba805825da76410c181273ba90b1"},"owner/known":{"sourceRef":"v1.0.0","sha":"2222222222222222222222222222222222222222"}}}'
            Expected = 'Unknown external action owner/unknown'
        }
        @{
            Reason = 'a mutable action reference'
            WorkflowContent = 'steps:
  - uses: actions/checkout@v7'
            ManifestContent = '{"schemaVersion":"1.0","actions":{"actions/checkout":{"sourceRef":"v7.0.1","sha":"3d3c42e5aac5ba805825da76410c181273ba90b1"}}}'
            Expected = 'must use a lowercase 40-character SHA'
        }
        @{
            Reason = 'a mismatched action SHA'
            WorkflowContent = 'steps:
  - uses: actions/checkout@1111111111111111111111111111111111111111'
            ManifestContent = '{"schemaVersion":"1.0","actions":{"actions/checkout":{"sourceRef":"v7.0.1","sha":"3d3c42e5aac5ba805825da76410c181273ba90b1"}}}'
            Expected = 'does not match reviewed SHA'
        }
        @{
            Reason = 'an unused manifest entry'
            WorkflowContent = 'steps:
  - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1'
            ManifestContent = '{"schemaVersion":"1.0","actions":{"actions/checkout":{"sourceRef":"v7.0.1","sha":"3d3c42e5aac5ba805825da76410c181273ba90b1"},"owner/unused":{"sourceRef":"v1.0.0","sha":"2222222222222222222222222222222222222222"}}}'
            Expected = 'Manifest action is unused: owner/unused'
        }
    ) {
        param([string]$WorkflowContent, [string]$ManifestContent, [string]$Expected)

        $fixtureRoot = New-SafetyFixture -WorkflowContent $WorkflowContent -ManifestContent $ManifestContent
        $output = @(& $script:validatorPath -RepositoryRoot $fixtureRoot 2>&1 | ForEach-Object { $_.ToString() })

        $LASTEXITCODE | Should -Be 1
        $output -join "`n" | Should -Match ([regex]::Escape($Expected))
    }

    It 'resolves its repository root when invoked without parameters' {
        $powershell = Get-Command powershell.exe -CommandType Application | Select-Object -First 1
        $process = Start-Process -FilePath $powershell.Source -ArgumentList @(
            '-NoProfile',
            '-ExecutionPolicy', 'Bypass',
            '-File', ('"{0}"' -f $script:validatorPath)
        ) -WorkingDirectory $TestDrive -Wait -PassThru -NoNewWindow

        $process.ExitCode | Should -Be 0
    }
}